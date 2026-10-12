# Reusable KYC — BBS Selective Disclosure

Prove only the parts of a KYC credential a service needs — **reveal a subset of signed attributes,
hide the rest** — so a user does KYC **once** and reuses it everywhere, with an optional **one-time,
on-chain gated claim** on Cardano.

Built on [ZeroJ](https://github.com/bloxbean/zeroj) `zeroj-bbs` (CFRG BBS draft-10, BLS12-381).
Design: [ADR-0003](../docs/adr/0003-reusable-kyc-bbs-selective-disclosure.md).

> **Demo / testnet only.** BBS here is verification-grade (an IRTF draft, not yet an RFC), and the
> keys are development keys. Do not use for real identity data or value-bearing flows.

---

## The idea

A **KYC provider** verifies a user once and signs a credential with **BBS**:

```
givenName · dob · country · kycLevel · docHash      ← 5 attributes, signed as one credential
```

The **holder** stores it, and for each **verifier** presents only what's asked — e.g. a DeFi app
needs `kycLevel = verified` and `country`, nothing else:

```
Issuer (KYC provider)         Holder (wallet)                Verifier (DeFi app)
 BBS sign {5 attributes} ────▶ derivePresentation(reveal =  ─▶ verifyPresentation()  (off-chain ✓)
                                {kycLevel, country})            + policy check
                                                                → gate a one-time claim on-chain
```

BBS proves the issuer signed **all** the attributes while revealing only the chosen ones — no
per-verifier circuit, no trusted setup, and different presentations are unlinkable. This is the
canonical W3C Verifiable Credentials / mobile-ID selective-disclosure primitive.

**Why not the `selective-disclosure` usecase?** That one proves *computed predicates* (`age ≥ 21`,
Merkle country membership) with Groth16 circuits — great when you must compute over a hidden value,
but each predicate is a bespoke circuit + trusted setup. This usecase is the complementary
*reveal-a-subset* half. (Predicates over a BBS-disclosed value can be added later as a small Groth16
range proof — the hybrid; see the ADR.)

---

## Components

| Piece | Class | Role |
|---|---|---|
| Issuer | `service/IssuerService` | BBS keygen + sign a `KycCredential` under a schema/issuer header |
| Holder | `service/HolderService` | store the signed credential; `present(revealAttributes, challenge)` |
| Verifier | `service/VerifierService` | `newChallenge` + `verifyFresh` (BBS + single-use) + `satisfies` (policy) |
| Schema | `credential/KycSchema` | the ordered attribute list (index = BBS message index) |
| On-chain | Julc `BbsKycClaimValidator` | native Plutus V3 BBS `ProofVerify` + policy + payout |

---

## Status

- ✅ **Off-chain end-to-end** — issue → present (reveal subset) → verify + policy.
  (`ReusableKycOffchainE2ETest`.)
- ✅ **Native on-chain BBS verification (Julc / Plutus V3)** — `BbsProofVerify` reproduces BBS
  `ProofVerify` (hash-to-scalar, T1/T2, pairing) on-chain, differential-tested in the Julc VM against
  the off-chain reference on a **real presentation**, and measured at **~2.44×10⁹ CPU / 0.18M mem**
  (well within Cardano's per-tx limits, ~0.4 ADA). The gadgets and their differential tests live in
  ZeroJ's `zeroj-onchain-julc` module (`bbs.lib` — `BbsHashToScalarVmTest`, `BbsProofVerifyVmTest`);
  this repo's `BbsKycClaimVmTest` covers the full claim validator built on them.
- ✅ **On-chain claim, live on Yaci DevKit** — `BbsKycClaimValidator` locks a voucher carrying the
  claim policy and releases it only when the holder's BBS presentation **verifies on the ledger**,
  discloses exactly the required attributes, is bound to *this* voucher, and pays the voucher's
  recipient. Spending the voucher once is the nullifier. (`BbsKycClaimVmTest` — accept + underpay /
  wrong-payee / policy-mismatch / tampered-header / another-voucher's-presentation rejects;
  `ReusableKycYaciE2ETest` — a real lock + claim on a node.)
- ✅ **Web UI + `demo.sh` + Docker** — `./demo.sh reusable-kyc --run` (port 8092): issue → pick which
  attributes to reveal → verify off-chain → claim on-chain.

## Run the demo

With a local [Yaci DevKit](https://github.com/bloxbean/yaci-devkit) running, from the repo root:

```bash
./demo.sh reusable-kyc          # build + start the app, open the UI (http://localhost:8092)
./demo.sh reusable-kyc --run    # ...and run the happy path: issue → present → claim on-chain
./demo.sh reusable-kyc --stop   # stop it
```

The UI walks the three steps: **issue** a credential, **choose which attributes to reveal** (watch the
rest stay hidden), and **claim on-chain** — the claim panel shows the tx hash once the ledger has
verified the BBS proof.

## Or run just the tests

```bash
cd reusable-kyc
./gradlew test        # off-chain flow + the on-chain validator in the Julc VM (no node needed)
```

The test shows a holder revealing only `kycLevel` and `country` while `givenName`, `dob`, and
`docHash` stay private, and a verifier checking the BBS proof + a policy (`kycLevel=verified`,
`country ∈ allowed`). It also shows a presentation failing under a different issuer's key.

### Run the on-chain claim against Yaci DevKit

Start a local [Yaci DevKit](https://github.com/bloxbean/yaci-devkit) (API on `:8080`, faucet on
`:10000`), then:

```bash
./gradlew test --tests '*ReusableKycYaciE2ETest' -Dkyc.e2e=true
```

It issues a credential, presents only `country`+`kycLevel`, locks a voucher at the claim validator,
and spends it with the presentation — **the ledger verifies the BBS proof natively** (~2.47×10⁹ CPU,
well within the per-tx budget) and the refund is paid to the recipient. The test prints the validator
address and the claim tx hash.

> **ExUnits note:** the service evaluates the claim transaction with the local Julc VM by default.
> It adds a 25% safety margin (and at least 50,000 memory units) to absorb the small cost-model drift
> previously observed between Julc and the ledger. Pass `evaluateLocally=false` to
> `OnChainKycClaimService` to delegate evaluation to the backend/node instead.

---

## User guide (the flow in code)

```java
// 1. Issuer: verify the subject once (out of band), then sign the credential.
var issuer = new IssuerService(keyMaterial, "kyc-provider-1");
var credential = issuer.issue(new KycCredential(
        "Alice Example", "1990-05-01", "USA", "verified", docHashHex));
// issuer.publicKey() is published so any verifier can check presentations.

// 2. Verifier: issue a fresh, single-use challenge. The VERIFIER picks this, never the holder.
var verifier = new VerifierService();
byte[] challenge = verifier.newChallenge();          // 32 CSPRNG bytes

// 3. Holder: reveal only what the verifier needs, bound to that challenge.
var holder = new HolderService(credential);
var presentation = holder.present(List.of("kycLevel", "country"), challenge);

// 4. Verifier: cryptographic check (+ freshness) + policy check.
boolean ok = verifier.verifyFresh(issuer.publicKey(), presentation)
        && verifier.satisfies(presentation,
               Map.of("kycLevel", "verified"),
               Map.of("country", Set.of("USA", "GBR", "DEU")));
```

`present(...)` requires **strictly ascending** revealed indexes (handled for you).

### Why the challenge matters

A BBS presentation stays valid forever, so nothing about the proof alone stops someone who captured
it from re-sending it. The `presentationHeader` is what makes a presentation single-use — and it only
works if **the party relying on it chooses it**:

- **Off-chain** — the verifier issues 32 random bytes and accepts each one exactly once
  (`verifyFresh` consumes the challenge). A replay is bound to a spent challenge, so it's rejected.
  A holder-supplied nonce (a timestamp, say) would be worthless: a replayer would just replay it too.
- **On-chain** — nothing is supplied at all. The header is **derived**:
  `blake2b_256(voucherTxId ‖ I2OSP(index,8) ‖ recipientPkh)`, and the validator recomputes it from the
  voucher it's spending. That's unique per claim for free (a UTxO is spendable once), so a
  presentation made for one voucher can't be lifted onto another — no nonce registry needed.
