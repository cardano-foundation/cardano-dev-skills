# ADR-0003: Reusable-KYC — BBS selective disclosure with on-chain verification

- **Status:** Accepted — implementation in progress on `feat/reusable-kyc-bbs`
- **Date:** 2026-07-15
- **Related:** account-ownership (ADR-0001/0002), `selective-disclosure` usecase (Groth16-predicate),
  zeroj `zeroj-bbs` (CFRG BBS draft-10), zeroj `zeroj-onchain-julc`.

## Context & problem

Users repeatedly re-do KYC for every service. We want a **reusable credential**: a trusted issuer
verifies a user **once** and signs a credential; the user then proves the parts a given service needs
— **revealing only a subset of the signed attributes** — to many services, without re-verification
and without over-sharing.

Generic scenario (no named companies): a **KYC provider** signs
`{givenName, dob, country, kycLevel, docHash}`. A **DeFi app** only needs to know
`kycLevel = verified` and `country ∈ allowed`; it must **not** learn the name, DOB, or document hash.
The same credential should also satisfy other verifiers (an exchange, an age-gated dApp) from the
one issuance, and a claim should be usable **on-chain** on Cardano (e.g. to unlock a pool or mint an
access token), **once**.

The existing `selective-disclosure` usecase already does the **predicate** flavour with Groth16
circuits (in-circuit EdDSA-Jubjub signature + `age≥21`, Merkle country membership), verified on-chain.
That is the right tool for *computed predicates*, but every predicate is a bespoke circuit with its
own trusted setup. It does **not** demonstrate the canonical **"reveal a subset of signed
attributes"** primitive that W3C Verifiable Credentials and mobile driver's licences (mDL/ISO 18013-5)
are built on.

## Decision

Build a new **`reusable-kyc`** usecase around **BBS** (`zeroj-bbs`, CFRG draft-10), demonstrating
selective *reveal* of issuer-signed attributes, and **verify the presentation on-chain** with a
native Julc Plutus V3 validator.

### Why BBS (and not another circuit)

| | BBS (this usecase) | Groth16 circuit (`selective-disclosure`) |
|---|---|---|
| Reveal a subset of signed attributes | ✅ native (`derivePresentation`) | ⚠ heavy |
| Computed predicates (age≥18, ranges) | ❌ needs extra ZK | ✅ native |
| Per-credential trusted setup / bespoke circuit | ✅ none | ❌ required |
| Unlinkable multi-show | ✅ | ⚠ per-circuit |

BBS is the low-friction "credential wallet" primitive: **one issuance, many presentations, no circuit
per verifier, no trusted setup.** It is complementary to — not a replacement for — the predicate
circuits. Predicates over a BBS-disclosed value can be added later as a small Groth16 range proof
(the hybrid), which is the natural bridge back to `selective-disclosure`.

### Roles & flow

```
Issuer (KYC provider)         Holder (wallet / UI)              Verifier (DeFi dApp)
 BBS KeyGen                     stores full credential          ◀─ challenge (32 random bytes)
 Sign {5 attributes} ─────────▶ derivePresentation(reveal =  ───▶ verifyPresentation()   off-chain ✓
       header = issuer/schema     {kycLevel, country},              + challenge is fresh
       + validity                 presentationHeader =              then GATE the claim
                                  the verifier's challenge)         on-chain (below)
```

- **Issuer** — `BbsService.keyPair` + `sign(messages, header)`. `header` binds the schema + a validity
  epoch; the issuer publishes its **public key (G2)** and the credential **schema** (attribute order).
- **Holder** — stores the full credential + signature; for each verifier, calls
  `derivePresentation(pk, sig, messages, header, presentationHeader, revealedIndexes)`.
- **Verifier** — `verifyPresentation` (off-chain, sub-second) and/or the on-chain validator.

#### Presentation binding (what makes a presentation single-use)

A BBS presentation stays cryptographically valid forever, so **freshness has to come from the
`presentationHeader`** — and the party who relies on it must be the party who chooses it. Two
contexts, two mechanisms:

| Context | `presentationHeader` | Why it can't be replayed |
|---|---|---|
| Off-chain verifier | 32 CSPRNG bytes the **verifier** issues (`VerifierService.newChallenge`) | The verifier accepts each challenge exactly once (`verifyFresh` consumes it); a captured presentation is bound to a spent challenge |
| On-chain claim | `blake2b_256(voucherTxId ‖ I2OSP(index,8) ‖ recipientPkh)` — derived, not chosen | The validator **recomputes** it from the voucher it is spending; the voucher is spendable once (eUTxO = nullifier), so the header is unique per claim by construction |

The on-chain side deliberately has **no random nonce and no nullifier registry**: a chain-side
challenge would need to be stored and invalidated (an extra round-trip + state), whereas the voucher
ref is already unique, already unforgeable, and already single-use. The claimer cannot pick it, and a
presentation made for one voucher fails on another (`BbsKycClaimVmTest.presentation_bound_to_another_voucher_fails`).

> A holder-chosen nonce (e.g. a timestamp) would be worth nothing: an attacker replaying a captured
> presentation would simply replay its nonce too. This is why the demo does a
> `POST /api/kyc/challenge` → `present` → `verify` handshake rather than letting the caller supply one.

### On-chain verification (the target)

Julc already exposes the full BLS12-381 builtin toolkit (`bls12_381_G1/G2_add/neg/scalarMul/
multiScalarMul/hashToGroup/compress/uncompress`, `millerLoop`, `mulMlResult`, `finalVerify`), and the
off-chain BBS `ProofVerify` already exists in `zeroj-bbs` (`CfrgBbsCore`). So the on-chain verifier is
a **port of tested Java to Julc**, not new cryptography.

**Design — native Julc `BbsProofVerifyValidator`:**

- **Validator params (baked at deploy, like a Groth16 VK):** the issuer **public key `W` (G2)**, the
  ciphersuite **generators `Q_1, H_1..H_L` (G1[])**, and the message count `L`. Generators are
  deterministic (ciphersuite + count), so precomputing them off-chain **avoids on-chain hash-to-curve**
  — the single biggest cost saver.
- **Datum:** the claim policy — required disclosed values (e.g. `kycLevel = verified`,
  `country ∈ {…}` as a small set or Merkle root) and the claim `recipient`/amount; plus the issuer key
  id / validity epoch.
- **Redeemer:** the BBS `proof`, the **disclosed messages + their indexes**, and the
  `presentationHeader`.
- **Validator checks:**
  1. Recompute the **expected `presentationHeader`** from the voucher being spent + the datum's
     recipient, and require the redeemer's to equal it — see *Presentation binding* above.
  2. Recompute `domain` and the Fiat–Shamir `challenge` on-chain (`expand_message_xmd` over
     `sha2_256` + reduce mod `r`) and verify it matches the proof's challenge — this binds the proof
     to the disclosed messages and the claim context.
  3. Recompute the proof relation via `bls12_381_G1_multiScalarMul` over the generators + responses.
  4. Pairing check `e(Abar, W) · e(Bbar, −BP2) == 1` via `millerLoop` + `mulMlResult` +
     `finalVerify`.
  5. Enforce the **policy** (disclosed values satisfy the datum) and **payout/gate** (output pays the
     `recipient`). Spending the voucher UTxO **is** the nullifier — no separate registry, since the
     eUTxO model already allows it exactly once (same intrinsic-nullifier pattern as account-ownership).

**Fallback (documented, not the goal):** if native on-chain `ProofVerify` proves over the per-tx
ExUnits budget for realistic `L`, fall back to **coordinator-gated** settlement — the verifier service
checks the presentation off-chain and co-signs `(disclosed attrs, recipient, nullifier)`; the
validator checks the co-signature + nullifier. This still gives an on-chain, auditable, one-time claim
and is guaranteed to fit the budget. We will **measure** the native verifier's ExUnits (as we did for
account-ownership) before committing.

### Module & demo.sh integration

`reusable-kyc/` is a Spring Boot usecase like the others: an **Issuer** step, a **Holder UI** (choose
which attributes to reveal), a **Verifier**, and the **on-chain claim** against **Yaci DevKit**. It
gets a `demo.sh reusable-kyc [--run]` entry, a compose service + port, a `data/` setup, a row in the
root README's demos table, and a usecase README + user guide.

## Consequences

- Adds the first BBS-based usecase; exercises `zeroj-bbs`, which has no demo today.
- If the native Julc verifier lands, it is **reusable** and a candidate to promote into
  `zeroj-onchain-julc` (a `BbsBLS12381Verifier` alongside the Groth16/PlonK ones) — tracked as a
  follow-up zeroj issue.
- Establishes the reveal-subset half of the selective-disclosure story next to the predicate half.

## Risks / open questions

- **On-chain `hash_to_scalar` byte-exactness** — the challenge recomputation must match
  `CfrgBbsCore` exactly (`expand_message_xmd(SHA-256)`, `I2OSP`, `map_to_scalar` ordering). This was
  the highest implementation risk. **✅ Resolved:** `BbsHashToScalar` (Julc, using `sha2_256` +
  `xorByteString` + `sliceByteString` + `byteStringToInteger`) is **differential-tested in the Julc
  VM** against the off-chain `CfrgBbsCore.hashToScalar` and matches byte-for-byte (empty, short, and
  multi-block messages) — see `BbsHashToScalarVmTest` (now in ZeroJ's `zeroj-onchain-julc`; see
  stage 6). The remaining `ProofVerify` steps (serialize
  via `bls12_381_G1_compress` + `I2OSP`, T1/T2 via G1 `scalarMul`/`add`, the pairing via `millerLoop`
  + `finalVerify`) are mechanical and lower-risk.
- **ExUnits budget** — **✅ Resolved:** the full on-chain `ProofVerify` (5-attribute credential,
  disclose 2) measures **~2.44×10⁹ CPU / ~0.18M mem** in the Julc VM (originally
  `ReusableKycOnchainVmTest`, now `BbsProofVerifyVmTest` in `zeroj-onchain-julc`; see stage 6),
  well within the ~10×10⁹ / 14M per-tx limits (~0.4 ADA). **Native on-chain verification is viable;
  the coordinator-gated fallback is not needed.**
- **ExUnits evaluation uses local Julc with padding by default.** The local Julc VM's raw cost model
  under-estimates the ledger's by a few thousand steps on a script this large (observed: node
  reported `cpu: -3339`, `mem: -30` overspend for locally-estimated
  `steps=2,460,210,557`). `OnChainKycClaimService` therefore adds a 25% safety margin, with at least
  50,000 memory units, before building the transaction. Backends with an evaluation endpoint remain
  available by constructing the service with `evaluateLocally=false`.
- **Presentation freshness** — a BBS presentation is valid forever, so replay protection rests
  entirely on the `presentationHeader`. **✅ Resolved:** the verifier issues a 32-byte CSPRNG,
  single-use challenge off-chain, and the on-chain header is *derived* from the voucher ref +
  recipient rather than supplied. See *Presentation binding*;
  tests: `ReusableKycOffchainE2ETest.a_captured_presentation_cannot_be_replayed`,
  `BbsKycClaimVmTest.presentation_bound_to_another_voucher_fails`.
- **BBS is verification-grade, not audited** (draft, not RFC); usecase is testnet/demo only — state it
  in the guide.
- **Predicates** (age≥18 without revealing DOB) are out of scope for v1 (BBS reveals whole
  attributes); note the Groth16-range-proof hybrid as the follow-up.

## Alternatives considered

- **Extend `selective-disclosure` with a BBS flavour** — rejected for v1: a separate `reusable-kyc`
  tells the distinct reveal-subset story cleanly without entangling the predicate demo.
- **BBS verified inside a Groth16 circuit, Groth16 verified on-chain** — rejected: verifying BBS
  pairings *in-circuit* is prohibitively large.
- **Off-chain only (no Cardano step)** — rejected: the on-chain, one-time, gated claim is the point of
  doing this on ZeroJ/Cardano.

## Staged plan

1. **ADR** (this doc). ✅
2. **Off-chain E2E** — issuer/holder/verifier BBS: issue → present(reveal subset) → verify. ✅
   (`ReusableKycOffchainE2ETest`.)
3. **On-chain** — Julc `BbsProofVerify` (port + differential-test in the Julc VM) → on-chain service
   (lock/unlock) → **Yaci DevKit E2E**; measure ExUnits; fall back to coordinator-gated if over.
   - 3a. `hash_to_scalar` primitive ported + VM-differential-tested. ✅ (`BbsHashToScalarVmTest` —
     moved to `zeroj-onchain-julc` in stage 6.)
   - 3b. Full `BbsProofVerify` (serialize + T1/T2 + challenge + pairing), VM-tested against a real
     presentation; **~2.44×10⁹ CPU / 0.18M mem**. ✅ (`ReusableKycOnchainVmTest` — moved to
     `zeroj-onchain-julc` as `BbsProofVerifyVmTest` in stage 6.) Unrolled for the
     fixed reusable-KYC disclosure (reveal `country`/`kycLevel` of 5); arbitrary disclosures are a
     follow-up.
   - 3c. Claim validator (BBS verify + policy + payout + nullifier) + lock/unlock service + **live
     Yaci DevKit E2E**. ✅ (`BbsKycClaimVmTest` — accept + 5 reject paths; `ReusableKycYaciE2ETest` —
     voucher locked and claimed on a real node, BBS proof verified **by the ledger**, refund paid.)
4. **UI + demo.sh + docker + README/user guide.** ✅ (`./demo.sh reusable-kyc --run`, port 8092.)
5. **Presentation binding hardening** — verifier-issued single-use challenge off-chain; voucher-derived
   header on-chain. ✅ (Claim validator now **~2.47×10⁹ CPU / 0.25M mem**, still well inside the budget;
   re-verified on Yaci DevKit.)
6. **Gadgets promoted to ZeroJ** — the reusable on-chain pieces moved out of this usecase into the
   library: `BbsHashToScalar` + `BbsProofVerify` (`@OnchainLibrary`) now live in `zeroj-onchain-julc`
   (`…onchain.julc.bbs.lib`), and the off-chain params/redeemer codec is `BbsToCardano` in `zeroj-bbs`
   (`…bbs.cardano`). Their VM differential tests moved with them (`BbsHashToScalarVmTest`,
   `BbsProofVerifyVmTest`). This repo keeps only the app-specific policy validator
   (`BbsKycClaimValidator`, composing the library gadget) and its `BbsKycClaimVmTest`. Verified
   byte-exact: identical script hash and ExUnits before/after, plus a fresh live Yaci DevKit claim. ✅
