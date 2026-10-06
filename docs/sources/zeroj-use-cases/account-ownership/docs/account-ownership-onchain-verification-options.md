# Account-Ownership Proofs On-Chain: Replay Protection, Nullifiers & Safe Refund Design

*Design report — generic wallet-hack refund use case — trusted operator "ABC".*
*Analysis only; no code changed. Reviews the contract and lays out options to use the proof safely
(with detailed steps, pros/cons, and a recommendation).*

> **Update — decision taken & implemented.** Since this analysis, **Option C (recipient binding as a
> circuit public input)** was chosen and shipped: the circuit takes the recipient's payment key hash
> as a second public input — both the pkh and the recipient are **packed** into one field element
> each, so **2 public inputs (~2.8×10⁹ CPU steps, ~0.45 ADA on-chain)** — `account`/`role`/`index`
> are all secret, and the on-chain validator **verifies the proof and enforces the payout goes to the
> bound recipient for the datum's amount**. This report is kept as the **decision record** — the
> sections below are the threat model and the options weighed to get there; the pkh-only "starting
> point" they describe has since been superseded. For the **current** circuit, prove, and validator
> flow see [`verification-and-validator-flow.md`](verification-and-validator-flow.md).

---

## 1. Executive summary

The account-ownership circuit produces a zero-knowledge proof that **the holder of a wallet's root
seed derives, via the full CIP-1852 path, to a given address's payment key hash (pkh)**. For the
wallet refund this is exactly the right primitive: the attacker drained funds using *leaf* signing
keys, but (by assumption) does **not** hold the *root seed*, so only the genuine owner can produce
this proof.

The problem is not *generating* the proof — that works and is validated. The problem is **using it
safely**. As designed, the proof is a **bearer credential**: its only public input is the pkh, so it
attests "someone who knows the seed behind pkh X made a proof" and **nothing about who submits it or
where a refund should go**. Anyone who copies the proof from the mempool can submit their own
transaction with it.

**The single most important property to add is *recipient binding*** — the guarantee that a refund
for pkh X can only go to the address the genuine prover chose. A nullifier (anti-double-spend) is
necessary but **not sufficient on its own** — without recipient binding a front-runner claims first
*and* locks the real owner out.

**Recommendation (short version):** for a coordinated refund run by ABC, use
**Option A — off-chain verification + coordinated disbursement** as the primary path (no circuit
change, no mempool exposure, simplest and safest), backed by **per-account refund-voucher UTxOs**
(the UTxO *is* the nullifier — double-claim is impossible under the eUTxO model). Offer the existing
on-chain verification as an optional user self-check. If a **trustless, fully on-chain** claim is
required, use **Option B — commit-reveal** (binds the recipient without a circuit change) or invest
in **Option C — recipient binding as a circuit public input** (the cryptographic gold standard, but
requires a new trusted setup). *(Option C is what was ultimately built — see the banner above.)*

---

## 2. Starting point (before recipient binding)

*This section is the pkh-only baseline the analysis started from. Recipient binding (Option C) has
since been implemented — see the banner and the flow doc; the specifics below are historical.*

### 2.1 The circuit's public interface (baseline)
- **Public input:** the payment key hash only. The derivation path was already a secret witness, so
  the proof did not reveal which address index it is. *(The implemented design adds a second public
  input — the recipient — makes `account` secret too, and packs both hashes into one field element
  each; see the flow doc.)*
- **The proof reveals nothing about the seed** (zero-knowledge). It is therefore **safe to publish**;
  the pkh is already public (it is the address). There is no privacy loss in putting a proof on-chain
  — the risk is purely **authorization / binding**, not confidentiality.

### 2.2 `OwnershipProofValidator` (in the account-ownership CLI) — demo scope
```
datum    = [pkh_0 … pkh_27]            // the circuit's public inputs, in order
redeemer = Groth16Proof(piA, piB, piC)
validate = Groth16BLS12381Lib.verify(datum, piA, piB, piC, vkAlpha, vkBeta, vkGamma, vkDelta, vkIc)
```
It checks **only** that the proof verifies against the pkh. It does **not** inspect the
`ScriptContext`: it does not bind the signer, the outputs/recipient, a nullifier, or any
authorization field. *(This has since been done: the validator now takes `datum = (pkh,
refundAmount)` and `redeemer = (proof, recipient)`, verifies the proof for `[pkh, recipient]`, and
inspects the `ScriptContext` to enforce that an output pays the bound recipient at least
`refundAmount`. See the flow doc.)*

### 2.3 The current on-chain "verification" flow (CLI `verify --onchain`)
A **self-check**, not a refund: a funding/admin account **locks** a gate UTxO at the validator
address, then immediately **spends** it, supplying the proof as the redeemer. If the spend succeeds,
the proof verified on-chain (~0.45 ADA with the packed design, one lock + one unlock tx). The
self-check exists to prove the on-chain verifier accepts the proof; the implemented validator also
enforces the payout to the recipient (§2.2 note).

### 2.4 The binding pattern that already exists: `Groth16BLS12381TxOutRefBindingVerifier`
This production-oriented example binds the statement to the spend by requiring the proof's **first
public input** to equal `blake2b_256(spentTxId ‖ outputIndex) mod Fr`. It is the template for "bind
the proof to context via a public input." **Crucially, it only works if the circuit *has* such a
public input.** Our ownership circuit's only public input is the pkh, so **we cannot use this pattern
without changing the circuit** (Option C).

### 2.5 The core constraint that shapes every option
> The proof commits only to the pkh. To bind a refund to a specific recipient, the recipient must be
> fixed by **either (a) a new circuit public input** (Option C — needs re-setup) **or (b) something
> outside the proof** the attacker cannot alter: a consumed commitment UTxO (Option B), an
> authenticated off-chain submission (Option A), or a coordinator signature (Option E).

---

## 3. Threat model (wallet refund)

Let **R** be the real owner of drained account with address pkh **X**; **R** wants a refund to a
fresh address **A_R**. Let **H** be the attacker, who watches the mempool.

| # | Threat | Enabled when | Consequence |
|---|---|---|---|
| T1 | **Front-run / redirect** | recipient is in the redeemer (not bound to the proof) | H copies the proof from the mempool, submits their own tx with recipient `A_H` → refund to attacker |
| T2 | **Replay / double-claim** | no nullifier / voucher not single-use | X's refund claimed more than once |
| T3 | **Lock-out via nullifier-only** | nullifier present but no recipient binding | H claims first to `A_H`; nullifier(X) burned → R can never claim |
| T4 | **Claim for a non-affected account** | no allow-list of hacked pkhs | anyone proves ownership of *their own* account and drains the treasury |
| T5 | **Fee starvation** | claimant must pay fees, but their account was drained | genuine owners cannot afford the claim tx |
| T6 | **Hacker also holds the seed** | the breach exposed root seeds, not just leaf keys | ownership proof cannot distinguish H from R (out of scope for ZK alone — see §7) |

T1/T3 are the dangerous ones and both reduce to **missing recipient binding**. T2 is solved by a
nullifier or single-use voucher. T4–T6 are refund-program design (§7).

---

## 4. Options

Each option is scored on: **circuit change?**, **trust model**, **replay/front-run safety**, **UX**.

### Option A — Off-chain verification + coordinated disbursement (backend)
**Idea:** ABC is already the trusted coordinator of the refund. Users submit `{proof,
public-inputs, desired recipient A_R}` over an **authenticated channel** (signed web form / KYC
portal / support ticket). ABC verifies the proof **off-chain** with the pure-Java verifier we
already ship (`OffchainVerifier` / `Groth16BLS12381PureJavaVerifier`, ~0.2 s), checks pkh X is in the
affected set, marks X claimed, and pays A_R from the treasury.

**Steps**
1. Publish the key bundle (or its VK) so users can `prove` locally (the app already does this).
2. User proves locally → uploads `proof.json` + `public-inputs.json` + chosen recipient to the portal.
3. Backend runs `Flows.verifyOffChain`-equivalent (pure Java) + allow-list + per-pkh "already
   claimed" check (a database, or the on-chain voucher in §6).
4. Backend disburses the refund to A_R (single treasury tx, or batched).

**Pros**
- **No circuit change**, uses the verifier we already have.
- **No mempool exposure** of the proof → **T1/T3 impossible** (front-running needs a public proof).
- Simplest UX for victims (no ADA needed to claim → solves **T5**).
- ABC can layer KYC / manual review for edge cases (**T6**).

**Cons**
- **Centralized / trust-ABC** for disbursement and for honestly recording claims.
- Not "trustless on-chain"; requires a backend + treasury operations.

**When to choose:** a coordinated, one-time, operator-run refund (exactly this scenario). This is the
lowest-risk way to *use the proof we already produce*.

---

### Option B — Commit-reveal on-chain (trustless, no circuit change)
**Idea:** bind the recipient with a **commitment UTxO** instead of the proof. Two phases:
- **Commit:** the claimant posts `commitment = blake2b(pkh ‖ A_R ‖ salt)` on-chain (cheap; no proof,
  no recipient revealed). This creates a commit UTxO owned by the claim script.
- **Reveal:** the claimant spends *that* commit UTxO, revealing `{proof, A_R, salt}`. The validator
  checks (i) `blake2b(pkh ‖ A_R ‖ salt) == commitment`, (ii) the Groth16 proof verifies for pkh, and
  (iii) the tx pays the refund to **A_R**.

Why it resists front-running: the recipient A_R is fixed **at commit time**, before any proof is
public. When the reveal appears in the mempool, an attacker can copy it, but (a) the reveal must
consume the **specific commit UTxO** (eUTxO: only one tx can), and (b) even a copied reveal still
carries the committed `A_R` (changing it breaks the hash). So the funds go to A_R regardless of who
lands the tx.

**Steps**
1. Deploy a commit-reveal claim validator holding per-account refund vouchers (§6).
2. User: commit tx (hash only) → wait N blocks → reveal tx (proof + recipient + salt) spending both
   the commit UTxO and the voucher.
3. Validator enforces hash match + proof + payout to A_R + voucher consumption.

**Pros**
- **Trustless & fully on-chain**; **no circuit change**.
- Binds the recipient (**T1/T3 solved**); voucher consumption solves **T2**.

**Cons**
- **Two transactions** and a wait between them (worse UX; more fees).
- The claimant still needs some ADA for the two txs (**T5** — mitigate by sponsoring, or fund the
  commit from the voucher).
- More validator logic to audit; front-running of the *commit* is harmless (it reveals nothing) but
  the design must ensure a griefer cannot pre-commit someone else's `(pkh, A_R)` — bind the commit to
  the committer (e.g., require the commit be signed by / paid from A_R) so only A_R can reveal.

**When to choose:** a trustless on-chain claim is a hard requirement and re-doing the trusted setup
is undesirable.

---

### Option C — Recipient binding as a circuit public input (cryptographic gold standard)
**Idea:** add a public input `msg` to the circuit (e.g., `msg = recipient pkh`, or
`blake2b(recipient ‖ deadline ‖ nonce)`). The prover commits to their recipient *inside the proof*.
The on-chain validator checks the proof's `msg` public input equals the tx's actual payout recipient
(exactly the `TxOutRefBindingVerifier` pattern, generalized from tx-ref to recipient).

**Steps**
1. Extend `OwnershipProof`: add `@Public msg` (the circuit already has the `@Public pkh`; this adds a
   second public input). role/index stay secret.
2. Re-run the trusted setup / ceremony → **new VK, new fingerprint, new key bundle** (the whole ADR
   arc supports this; the tooling is there).
3. Update the validator to check `publicInputs = [pkh…, msg…]` and enforce `msg == payoutRecipient`.

**Pros**
- **Cryptographically sound**, single transaction, no commit/reveal dance.
- A copied proof is worthless to an attacker: they cannot change `msg` (invalidates the proof) and
  cannot re-prove (no seed). **T1/T3 solved at the proof level.**

**Cons**
- **Requires a new trusted setup** (a fresh multi-party ceremony for production) and re-publishing
  keys — the biggest operational cost. Everyone who already has keys must re-key.
- Slightly higher on-chain cost (a few more public inputs; still O(n), small).
- The recipient (or its hash) becomes public in the proof — acceptable (it is the payout address).

**When to choose:** the ideal end-state if you are willing to (re)run the ceremony; also the cleanest
if account-ownership proofs will be reused for many on-chain actions beyond this one refund.

---

### Option D — Nullifier registry (anti-double-spend; **complement**, not a standalone)
**Idea:** ensure each account claims **once**. Two flavors:
- **pkh-as-nullifier (no circuit change):** the pkh is unique per address; record claimed pkhs. Best
  realized as **per-account voucher UTxOs** (§6) — the consumed UTxO is the nullifier, no registry
  contention.
- **PRF nullifier (circuit change):** `nullifier = PRF_rootkey(domain)` exposed as a public input —
  unlinkable to pkh and **per-account** (prevents a user with many drained addresses from claiming a
  per-account refund once per address). Needs Option C's re-setup.

**Pros:** solves **T2**; per-account PRF nullifier also prevents cross-address multi-claim.
**Cons:** **does nothing for T1/T3 on its own** — and a naïve nullifier *without* recipient binding
**enables T3** (attacker claims first, real owner locked out). **Only deploy a nullifier together
with A, B, or C.**

---

### Option E — Hybrid: off-chain authorization + on-chain settlement (coordinator co-sign)
**Idea:** the user submits `{proof, A_R}` off-chain; ABC verifies and returns a **co-signature**
over `(pkh, A_R, deadline)`. The on-chain claim validator requires **both** the ownership proof
**and** ABC's signature over the recipient, and pays A_R.

**Pros:** recipient binding via the coordinator sig (no circuit change); the proof never hits the
mempool unbound; auditable on-chain settlement; ABC can gate the allow-list.
**Cons:** still trusts ABC to co-sign honestly (but ABC cannot redirect funds — the sig binds
A_R, and it cannot forge the proof); an online signing service is required.
**When to choose:** you want the operational simplicity of A but with **on-chain, auditable
settlement** and a nullifier enforced by the ledger.

---

## 5. Side-by-side

| Option | Circuit change | Trust | Front-run (T1/T3) | Double-claim (T2) | Claimant needs ADA | UX |
|---|---|---|---|---|---|---|
| **A** Off-chain disbursement | none | ABC (full) | ✅ safe (no public proof) | via DB/voucher | ❌ no | ★ simplest |
| **B** Commit-reveal | none | trustless | ✅ safe | ✅ voucher | ⚠ some (2 tx) | ★★★ (2-phase) |
| **C** Circuit-bound recipient | **new setup** | trustless | ✅ safe (proof-level) | + Option D | ⚠ yes (1 tx) | ★★ |
| **D** Nullifier only | optional | — | ❌ **unsafe alone** | ✅ | — | — |
| **E** Coordinator co-sign | none | ABC (sign only) | ✅ safe | ✅ ledger | ⚠ yes | ★★ |

---

## 6. The clean nullifier on Cardano: per-account refund vouchers

Rather than a contended global nullifier registry (a single thread-token/accumulator UTxO that
serializes every claim), pre-materialize the refund set:

- ABC creates **one voucher UTxO per affected account** at the claim script, `datum = (pkh,
  amount, deadline)`, holding (or entitled to) that account's refund.
- A claim **spends that account's voucher**. Under the eUTxO model a UTxO can be consumed **exactly
  once**, so the voucher *is* the nullifier — **T2 is solved with zero extra machinery and no
  contention** (claims for different accounts are fully parallel).
- The allow-list (**T4**) is intrinsic: only pkhs that have a voucher can claim, and only for their
  datum-fixed amount.

Combine the voucher (T2/T4) with recipient binding from A, B, C, or E (T1/T3) for a complete design.

---

## 7. Considerations for full automatic on-chain verification

- **Fees when the account is drained (T5):** the genuine owner may have no ADA. Options: ABC
  sponsors fees (submit-service / batching), fund the claim from the voucher itself, or a metered
  faucet gated by a valid proof. The CLI already separates the *funding* account from the *proven*
  account — reuse that split.
- **Allow-list / amounts (T4):** encode the affected set as a **Merkle root** (validator parameter or
  reference input) with leaves `(pkh, amount)`; the claim carries a Merkle membership proof. Or use
  per-account vouchers (§6), which make the allow-list implicit.
- **Time-bounding:** put a `deadline` in the voucher datum and enforce it via the tx validity
  interval; unclaimed vouchers return to the treasury after expiry.
- **Griefing/DoS:** invalid proofs simply fail and cost the submitter fees (self-limiting). The only
  *profitable* attack is T1/T3 front-running, which recipient binding removes.
- **Privacy:** the proof is zero-knowledge and the pkh is already public → **publishing proofs leaks
  nothing new**. (With Option C the recipient becomes public — that is the payout address, expected.)
- **On-chain cost/scale:** Groth16 BLS12-381 verify uses the Plutus V3 pairing builtins; cost is
  O(#public inputs). The shipped design **packs** the pkh and recipient into one field element each —
  **2 public inputs, ~2.8×10⁹ CPU steps (~0.45 ADA)**. (A byte-per-input encoding would be 56 inputs /
  ~13.4×10⁹ steps and exceed the per-tx limit — hence the packing; see the flow doc §7.) Verify effort
  is independent of the 19M-constraint circuit size.
- **Upgradeability & emergency exit:** the validator is immutable once deployed. Include an
  ABC-multisig administrative path (e.g., sweep unclaimed vouchers after the deadline) and get the
  validator audited before mainnet.
- **The leaf-vs-root assumption (T6):** this whole scheme assumes the attacker holds *leaf* keys but
  not the *root seed*. If the breach exposed seeds/root keys, the ZK proof **cannot** distinguish the
  attacker from the owner (both know the root). In that case, ownership proof alone is insufficient
  and must be augmented with an out-of-band factor: prior-registered recovery key, KYC/identity,
  time-of-registration (proof generated before a cut-off), or social recovery. **State this
  assumption explicitly in the refund terms.**
- **Per-account vs per-address refunds:** with role/index secret, a proof attests one pkh. If refunds
  are per *account*, either (a) restrict to one canonical address per account, or (b) use a **PRF
  per-account nullifier** (Option C/D) so a user cannot claim once per drained address.

---

## 8. Recommendation (and what was chosen)

> **What shipped: Option C** — recipient binding as a circuit public input (packed to 2 inputs), with
> the validator verifying the proof and enforcing the payout to the bound recipient. The analysis
> below weighed all the options; **A** was recommended for a purely operator-run refund, but **C** was
> chosen because it makes the claim a single, trustless transaction and the ownership proof reusable
> for any future on-chain action. Per-account vouchers (§6) remain the nullifier of choice. The
> original recommendation is kept below for the reasoning.

**Primary (as recommended for an operator-run refund): Option A + §6 vouchers.**
ABC is the refund operator, so lean into that: users prove **locally** (the desktop app / CLI
already does this), submit `{proof, recipient}` through an **authenticated ABC portal**, the
backend **verifies off-chain** with the pure-Java verifier we already have, and disburses from
**per-account voucher UTxOs** (intrinsic nullifier, intrinsic allow-list). This needs **no circuit
change**, keeps the proof **off the public mempool** (front-running is impossible), and lets ABC
apply KYC/manual review for the T6 edge cases. Keep the existing `verify --onchain` as an **optional
self-check** so a user can independently confirm their proof is on-chain-valid.

**If a trustless, fully on-chain claim is mandatory:** **Option B (commit-reveal) + §6 vouchers** —
binds the recipient with no new ceremony, at the cost of a two-phase UX. Bind the commit to the
committer so only the intended recipient can reveal.

**Strategic end-state (if you will re-run the ceremony anyway):** **Option C (recipient as a circuit
public input) + PRF per-account nullifier.** This is the cryptographically cleanest, single-tx,
fully-trustless design, and it makes account-ownership proofs reusable for *any* future on-chain
action — not just this refund. The whole setup/prove/verify toolchain already supports re-keying;
the only real cost is a production multi-party ceremony.

**Do not** deploy a bare nullifier (Option D) without one of A/B/C/E — it makes front-running strictly
worse (T3).

### Concrete changes implied for the current contract — status
1. ✅ **Done** — the validator inspects `ScriptContext` and enforces **payout to the bound recipient**
   for the datum's amount. Deliberately **no deadline** (kept deadline-free so funds are never
   time-locked); **voucher consumption** is the intended per-account nullifier (§6).
2. ✅ **Done** — recipient binding via a **circuit public input** (Option C).
3. ⬜ **Pending** — the affected-account allow-list (per-account vouchers, §6, is the plan).
4. ✅ Unchanged — `Groth16BLS12381Lib.verify` is used as-is; only the **surrounding authorization**
   changed.

---

*Prepared from the code as it was before recipient binding: `OwnershipProofValidator` (then demo,
pkh-only), `Groth16BLS12381TxOutRefBindingVerifier` (the public-input binding template that inspired
Option C), and `Groth16BLS12381Lib.verify`. The implemented design — recipient bound as a second
public input, both hashes packed to 2 public inputs, validator enforcing the payout — is documented
in [`verification-and-validator-flow.md`](verification-and-validator-flow.md).*
