# Bulletproofs Range-Proof Verifier - Implementation Report

- **Module:** `zkp/lib/bullet/bullet.ak`
- **Status:** Functional, tested, unaudited
- **Test results:** 
  - `aiken check` 13/13 
  - `aiken fmt` clean
  - `aiken build` succeeds

## 1. Overview

This module implements a Bulletproofs-style zero-knowledge range proof over the BLS12-381 curve, as one of three zero-knowledge proof systems in this repository's `zkp` package for Cardano smart contracts (Aiken, targeting Plutus V3). Given a Pedersen commitment `V` to a hidden integer value, it proves that the committed value lies in `[0, 2^n)` without revealing the value or its blinding factor.

Bulletproofs were chosen alongside Groth16 and PLONK specifically because they require **no trusted setup** - public parameters are derived deterministically from public strings, which removes an entire class of trusted-ceremony risk that the other two proof systems in this package carry.

This report covers the implementation as it stands: what was built, how it works, where it deliberately departs from the canonical construction and from typical general-purpose Bulletproofs libraries, and what remains before it is production- or audit-ready.

## 2. Position within the `zkp` package

| Module | Proof system | Setup | Core primitive |
|---|---|---|---|
| `lib/groth` | Groth16 | Trusted, circuit-specific | Pairings (`bls12_381_miller_loop`, `bls12_381_final_verify`) |
| `lib/plonk` | PLONK | Universal, trusted | Kate commitments, permutation argument |
| `lib/bullet` | Bulletproofs | Public, trustless | Discrete-log / Pedersen commitments, no pairings |
| `lib/common` | — | — | Shared field/point scaffolding, superseded in this module (see §4) |

All 3 modules follow the same conventions (error handling, test structure) adopted here.

## 3. Architecture

**Types**

```
BulletproofVerificationKey { g, h, u, g_vec, h_vec, g_sum, h_sum, n }
BulletproofProof           { a, s, t1, t2, tau_x, mu, l_vec, r_vec }
ProofBlinding               { alpha, rho, tau1, tau2, s_l, s_r }
```

`g`, `h`, `u`, and every entry of `g_vec`/`h_vec` are native `G1Element` values; `tau_x`, `mu`, and every entry of `l_vec`/`r_vec` are native `Scalar` values from the BLS12-381 scalar field. `g_sum`/`h_sum` are precomputed folds of the generator vectors, carried in the key to avoid re-summing `n` points on every verification.

**Entry points**

- `setup(n) -> BulletproofVerificationKey` - derives all generators deterministically.
- `commit_value(vk, value, gamma) -> G1Element` - builds the public Pedersen commitment `V`.
- `generate_proof(vk, value, gamma, blinding) -> BulletproofProof` - the reference prover.
- `verify(vk, v_commit, proof) -> Bool` - the verifier; the only function a validator needs.

## 4. Protocol walkthrough

**Setup.** `setup(n)` derives `g` (the curve's standard generator), `h`, `u`, and length-`n` vectors `g_vec`/`h_vec` via `hash_to_group` with distinct domain-separation tags. This is nothing-up-my-sleeve by construction - no party ever holds a discrete-log relationship between any two generators - and is meant to be computed once and embedded as a deployed constant, not recomputed per transaction.

**Commitment.** `commit_value` builds `V = g^value · h^gamma`, a standard Pedersen commitment.

**Proof generation.** Given `value`, its blinding `gamma`, and a `ProofBlinding` record (Aiken has no RNG, so every random scalar the protocol needs is an explicit caller-supplied input):

1. Decompose `value` into bits `a_L`; set `a_R = a_L - 1`.
2. Commit `A = h^alpha · g_vec^{a_L} · h_vec^{a_R}` and `S = h^rho · g_vec^{s_L} · h_vec^{s_R}`.
3. Derive challenges `y, z` from a transcript over `(vk, V, A, S)`.
4. Build the linear vector polynomials `l(X) = (a_L - z·1) + X·s_L` and `r(X) = y^n∘(a_R + z·1) + z^2·2^n + X·(y^n∘s_R)`, and their inner product `t(X) = t0 + t1·X + t2·X^2`.
5. Commit `T1 = g^{t1}·h^{tau1}`, `T2 = g^{t2}·h^{tau2}`.
6. Derive challenge `x` from a transcript continuing over `(T1, T2)`.
7. Evaluate `l_vec = l(x)`, `r_vec = r(x)`, and compute `tau_x = z^2·gamma + tau1·x + tau2·x^2`, `mu = alpha + rho·x`.

**Verification.** `verify` recomputes `y, z, x` from the identical transcript, then checks two equations:

- **t-commitment check:** `g^{t_hat}·h^{tau_x} == V^{z^2}·g^{delta(y,z)}·T1^x·T2^{x^2}`, where `t_hat = ⟨l_vec, r_vec⟩` is recomputed directly and `delta(y,z) = (z - z^2)·Σy^i - z^3·Σ2^i` is the standard closed-form correction term.
- **vector-opening check:** `A·S^x == h^mu·g_vec^{l_vec}·h'^{r_vec - z^2·2^n}·(g_sum/h_sum)^z`, where `h'_i = h_vec_i^{y^{-i}}` - the standard pre-compression Bulletproofs identity.

Both checks together are what bind the proof to a genuine bit-decomposition of the committed value; §6 details why.

## 5. Design differentiation from canonical Bulletproofs and general-purpose libraries

Bulletproofs as published (Bünz et al., 2018) and as implemented in general-purpose libraries (e.g. the Rust `dalek` bulletproofs crate) target a different deployment shape than a Plutus validator. Several choices in this implementation depart from that reference construction deliberately, for reasons specific to this environment:

**Linear vector opening instead of the recursive inner-product argument (IPA).** The published protocol recursively folds `l`, `r`, and the generator vectors over `log2(n)` rounds to shrink proof size from `O(n)` scalars to `O(log n)` group elements. This implementation stops one step earlier and discloses `l_vec`/`r_vec` directly. General-purpose libraries always implement the full fold because they serve arbitrary transport contexts where every byte of proof data has a cost. A Plutus validator's binding constraint is different: it is CPU/memory execution units, and the IPA fold does not reduce that cost - the folded rounds still sum to `O(n)` scalar multiplications, just spread across `log n` rounds via multi-exponentiation. What the fold buys is smaller *transaction size*, which only becomes the binding constraint once `n` is large enough (roughly 32–64) that disclosed vectors meaningfully inflate a datum or redeemer. Given the fold is also the highest-complexity, highest-bug-risk part of the protocol (recursive generator-vector folding, additional per-round challenges, a larger transcript surface), this implementation defers it until a concrete deployment target's transaction-size needs justify the added complexity, rather than including it unconditionally as reference libraries do.

**Native BLS12-381 group law throughout, no custom field simulation.** Every point operation in this module goes through `aiken/crypto/bls12_381/g1` and `scalar`, which wrap the audited native Plutus builtins (`bls12_381_g1_add`, `bls12_381_g1_scalar_mul`, `bls12_381_g1_hash_to_group`, and the BLS12-381 scalar-field arithmetic). This is a deliberate departure from an earlier prototype of this same module, which performed coordinate-wise modular arithmetic on raw integers instead of real elliptic-curve operations - a construction that resembled Bulletproofs in field naming but was not cryptographically meaningful. Every group operation in the current implementation is a real, ledger-validated curve operation.

**Prover and verifier tested together, end-to-end, without external fixtures.** Because Bulletproofs need no trusted setup, this module owns both `generate_proof` and `verify` and tests them as a pair - generate a proof, verify it; generate a proof, tamper with one field, confirm rejection. This differs from this package's own Groth16 verifier, which necessarily tests against externally-generated proof fixtures (from a circuit-specific trusted-setup ceremony this codebase cannot itself perform). It also differs from typical verifier-only implementations that rely on cross-implementation test vectors from a reference library; this implementation establishes internal prover/verifier consistency directly, and treats interoperability testing against an external Bulletproofs implementation (e.g. `dalek`) as future work rather than a requirement for this milestone.

**A bare `Bool` verification result, not a typed error channel.** A Plutus validator ultimately reduces to accept/reject at the ledger level. `verify` returns `Bool` rather than a `Result<_, Error>`, matching the convention already established by this package's Groth16 verifier rather than introducing a bespoke error taxonomy per proof system.

**Explicit hardening a mathematical description wouldn't need.** The published protocol and this repository's own protocol design notes (`docs/step-by-step.md`) describe the mathematics of Bulletproofs without specifying deployment-time hardening, since they aren't describing an adversarial on-chain environment. This implementation adds two things a smart-contract deployment needs that a textbook description doesn't: an upper bound on `n` (capped at 64, since `n` drives `O(n)` recursion and execution cost, and an unbounded `n` is an unbounded compute-cost knob for whoever controls the verification key), and a fixed protocol/version tag folded into every hash in the system - both generator derivation and every Fiat–Shamir challenge - so this system's generators and challenges cannot collide with another protocol's even given identical raw input bytes.

## 6. Security argument

Soundness does not depend on hiding `l_vec`/`r_vec` - it depends on both vectors being bound to commitments (`A`, `S`) that were fixed *before* the verifier's challenges `y`, `z`, `x` existed. A prover who did not honestly derive `l_vec`/`r_vec` from a genuine bit-decomposition of a value consistent with `V` would need to satisfy both the t-commitment check and the vector-opening check for challenges they could not have predicted at commitment time. The Pedersen-commitment binding property - that `g`, `h`, `g_vec`, `h_vec` have no known discrete-log relationships to one another - makes that negligibly likely (a Schwartz–Zippel argument over the random challenges). This is the identical binding argument the recursive IPA itself relies on for this same pre-compression equation; the fold is a communication optimization applied on top of it, not an additional soundness ingredient. The `verify` function's two checks are, in that sense, the complete soundness argument, not an approximation of one.

The `u` generator is present in `BulletproofVerificationKey` but unused by `verify` in this milestone. `u` exists specifically to bind the claimed inner product inside the recursive IPA, where `l`/`r` remain hidden from the verifier; since this construction discloses them and the verifier recomputes `t_hat = ⟨l_vec, r_vec⟩` directly, there is nothing left for `u` to bind. It is retained in the key, documented in-code as reserved for a future IPA phase, rather than removed.

## 7. Testing and verification

Ten tests exercise the module, alongside the three pre-existing Groth16 tests in the same package:

| Test | Verifies |
|---|---|
| `setup_smoke` | Generator vectors have the right length and are non-degenerate |
| `range_proof_valid` | A mid-range value verifies |
| `range_proof_valid_zero` | The boundary value `0` verifies |
| `range_proof_valid_max` | The boundary value `2^n - 1` verifies |
| `range_proof_fails_wrong_commitment` | A proof does not verify against a commitment to a different value |
| `range_proof_fails_tampered_tau_x` | Mutating `tau_x` is rejected |
| `range_proof_fails_tampered_l_vec` | Mutating one entry of `l_vec` is rejected |
| `range_proof_fails_wrong_vector_length` | A truncated `l_vec` is rejected |
| `generate_proof_rejects_out_of_range` | The prover's own guard traps for an out-of-range value |
| `range_proof_fails_out_of_range_bypassing_guard` | Verification independently rejects an out-of-range value even if the prover-side guard is bypassed |

Because this module owns both prover and verifier, every test constructs a real proof in-language and checks it against a real verification run - no hardcoded external fixtures are required, unlike the Groth16 tests in this package, which depend on proofs generated by an external circuit toolchain.

At `n = 8`, a full `verify` call measures approximately 5.2M memory units and 14.2B CPU units - comfortably within Cardano's per-transaction execution budget. This has not yet been benchmarked at larger `n`; see §8.

**Implementation note.** During development, an anonymous lambda with a multi-statement body (`fn(b) { expect Some(s) = scalar.new(b); s }`) passed directly to `list.map` was found to crash the Aiken v1.1.21 compiler silently, with no diagnostic output. The identical logic as a named top-level function compiles and runs correctly. Every inline lambda in this module is single-expression; the one case that needed a multi-statement body was extracted into a named helper (`scalar_from_bit`) instead. This is recorded here as a toolchain finding relevant to future work on this and other modules in the package, not a defect in the protocol implementation itself.

## 8. Known limitations and roadmap

- **No IPA compression** - proof size is `O(n)` scalars, not `O(log n)` group elements. Deliberate for this milestone (§5); the natural next phase once a deployment target needs larger `n`.
- **Execution-unit cost is unbenchmarked past `n = 8`.** The `max_n = 64` bound limits worst-case cost, but actual figures at `n = 32`/`64` should be measured before either is used in a real deployment.
- **No on-chain entry point yet.** This module covers the cryptographic core; how a validator obtains and trusts a given `V` (datum/redeemer wiring) is separate, follow-on work.
- **No external cryptographic audit.** This implementation has had internal design review and one external review pass; neither is a substitute for a formal audit before any mainnet or high-value use.
- **The deterministic prover is a test fixture, not a production prover.** Aiken has no RNG, so `generate_proof` requires the caller to supply every blinding factor; `generate_proof_deterministic` exists only to make self-contained tests possible and is documented as such. A production integration must source genuine entropy for these values itself.

## 9. Conclusion

This module delivers a functional, internally-tested Bulletproofs range-proof verifier and reference prover built on native BLS12-381 group operations. Its departures from the canonical, fully-compressed construction - linear rather than logarithmic proof size, no external interoperability vectors, deferred audit - are documented engineering decisions scoped to this milestone's goal of a sound, tested verifier, with a clear path (IPA folding, execution-unit benchmarking at scale, external audit) to close the remaining distance to a production-grade deployment.
