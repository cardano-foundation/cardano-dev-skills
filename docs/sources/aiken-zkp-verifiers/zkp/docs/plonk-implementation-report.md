# PLONK Verifier - Implementation Report

- **Module:** `zkp/lib/plonk/{preinputs,proofs,raw_affine,verifier}.ak`
- **Status:** Functional, tested, unaudited
- **Test results:**
  - `aiken check` 12/12 in `tests/plonk_tests`, 9/9 in `tests/plonk_props`, plus 15/15 in the closely-related `tests/point_tests` and 4/4 in `tests/point_props` (part of 89/89 across the package)
  - `aiken fmt` clean
  - `aiken build` succeeds

## 1. Overview

This module implements a PLONK zk-SNARK verifier over the BLS12-381 curve, as one of three zero-knowledge proof systems in this repository's `zkp` package for Cardano smart contracts (Aiken, targeting Plutus V3). Given a universal-but-still-trusted verification key, a proof, and a list of public inputs, it checks the standard PLONK gate/permutation/quotient identity via a batched KZG opening, using a Keccak-256 Fiat–Shamir transcript matching the `snarkjs`-style compressed-commitment variant of the protocol.

Like `lib/groth`, this module implements **verification only** - PLONK's universal SRS still requires a trusted setup, and generating a proof requires a full circuit compiler and witness computation this codebase does not reimplement, consistent with this package's own design notes (`docs/step-by-step.md`).

This is the most structurally complex of the three modules in this package, spread across five files rather than one, because the verification key and proof each need to flow in through more than one representation before reaching the actual pairing check.

## 2. Position within the `zkp` package

| Module | Proof system | Setup | Core primitive |
|---|---|---|---|
| `lib/groth` | Groth16 | Trusted, circuit-specific | Pairings (`bls12_381_miller_loop`, `bls12_381_final_verify`) |
| `lib/plonk` | PLONK | Universal, trusted | Kate (KZG) commitments, permutation argument |
| `lib/bullet` | Bulletproofs | Public, trustless | Discrete-log / Pedersen commitments, no pairings |
| `lib/common` | — | — | Shared field/point scaffolding, superseded in this module (see §4) |

PLONK's universal SRS (reusable across circuits, unlike Groth16's circuit-specific one) is the reason this module exists alongside `groth`: it trades a one-time-per-circuit ceremony for a one-time-ever ceremony, at the cost of a larger, more expensive verification equation - the most expensive of this package's three verifiers per call (§7).

## 3. Architecture

**Files and roles**

- `preinputs.ak` - `PlonkPreInputs` (compressed-bytes verification key) and `PreparedPlonkPreInputs` (decompressed, with the evaluation-domain data filled in); `plonk_prepare_preinputs` converts one to the other.
- `proofs.ak` - `PlonkProof` (compressed-bytes proof, `Int` evaluations) and `PreparedPlonkProof` (decompressed, `Scalar` evaluations, plus a derived `lagrange_inverses` hint); `plonk_prepare_proof` converts one to the other.
- `raw_affine.ak` - an alternate front door that accepts a verification key/proof expressed in this package's own affine point types rather than raw compressed bytes, and routes them into the same `PreparedPlonkPreInputs`/`PlonkProof` pipeline (see §5).
- `verifier.ak` - `verify_plonk`, the actual pairing-and-permutation check.

**Key types**

```
PlonkPreInputs         { power, k1, k2, q_m, q_l, q_r, q_o, q_c, s_sig1, s_sig2, s_sig3, x2 }   // compressed bytes + coset scalars
PreparedPlonkPreInputs { n, generator, generators, n_public, ...same fields decompressed to G1Element/G2Element }
PlonkProof             { commitment_a/b/c/z, t_low/mid/high, w_omega, w_omega_zeta, a_eval, ... }  // compressed bytes + Int evals
PreparedPlonkProof     { ...same, decompressed, plus lagrange_inverses: List<Scalar> }
```

`power` is `log2` of the evaluation-domain size (`n = 2^power`); `generators` holds `ω^0 .. ω^(k-1)` with `k = max(1, n_public)`, one per public input and never fewer than one, since the permutation check always uses `L_1`; `k1`/`k2` are the coset generators separating the three permutation copies; `x2` is the SRS's `[x]_2` G2 element the pairing check is anchored to.

**Entry points**

- `plonk_prepare_preinputs` / `plonk_prepare_proof` - decompress and derive the working forms from the compressed-bytes types.
- `prepare_affine_vkey` / `prepare_affine_proof` (`raw_affine.ak`) - convenience conversions from this package's own point representation.
- `verify_plonk(preinputs, pub_inputs, proof) -> Bool` - the verifier; the only function a validator needs.

## 4. Protocol walkthrough

**Transcript.** `verify_plonk` re-serializes every preinput and proof commitment to its compressed byte form (`g1.compress`) and re-derives the full Fiat–Shamir transcript with `keccak_256`, in the same order and grouping a matching off-chain prover would have used: `beta` over all selector/permutation/public-input/wire-commitment bytes, `gamma = keccak256(beta)`, `alpha` additionally over `commitment_z`, `zeta` additionally over the quotient commitments, `v` additionally over all six scalar evaluations, and `u` over the two opening-proof commitments. Nothing about this transcript is trusted from the prover; every challenge is recomputed independently from committed values already fixed earlier in the same transcript.

**Public-input checks.** Before anything else, `verify_plonk` requires exactly `n_public` inputs, each in `[0, r)` (`check_public_inputs` in `common/inputs.ak`, shared with Groth16), and a non-empty Lagrange inverse list; otherwise it returns `False`. The Lagrange check then requires exactly one inverse per generator, counting them in the same walk that checks each inverse, so a surplus or missing inverse also returns `False`. Without these checks an input could be hashed into the transcript yet left out of the constraint: an extra input has no Lagrange term, and an inverse list that is too short pairs some input with nothing. The range check matters because `scalar.from_int` reduces mod `r` in both the maths and the transcript, so `x` and `x + r` would otherwise produce identical challenges and verify with the same proof.

**Public-input evaluation.** For each public input position `i`, the verifier needs `L_i(zeta)`, the Lagrange basis polynomial evaluated at the challenge point, whose closed form is `L_i(zeta) = (zeta^n - 1)·ω^i / (n·(zeta - ω^i))`. Computing that division on-chain via modular exponentiation (Fermat's little theorem, `a^(p-2)`) is expensive - roughly 254 scalar multiplications per public input. Instead, `PreparedPlonkProof.lagrange_inverses` carries the *already-computed* inverses as an untrusted, prover-supplied hint (computed off-chain once, in `plonk_prepare_proof`, via exactly that exponentiation), and `verify_plonk` checks each one with a single cheap multiplication: `inv · (n·(zeta - ω^i)) == 1`. This is the same class of optimization as Bulletproofs' disclosed-vector approach documented in this package's other report: replace an expensive on-chain computation with a cheap on-chain check of an off-chain-computed value.

**Linearization and batching.** The verifier computes the PLONK linearization polynomial `r(zeta)` (folding in the public-input evaluation, the permutation grand-product argument via `alpha`/`beta`/`gamma`, and the quotient polynomial split into low/mid/high parts), then batches every polynomial commitment the identity depends on - the three gate-selector commitments scaled by witness evaluations, the permutation commitment `Z`, the third permutation-sigma commitment, and the quotient commitments - into a single combined commitment via the `v` challenge, following the standard batched-KZG technique that collapses what would otherwise be several separate opening checks into two.

**Pairing check.** Two Miller loops are computed: one pairs the combined opening-proof commitments (`w_omega + u·w_omega_zeta`) against `x2` (the SRS point), the other pairs a combination of `zeta`-scaled and `u·zeta·ω`-scaled opening commitments plus the batched polynomial/evaluation difference against the G2 generator. `final_exponentiation` on the two combined results is the actual KZG-opening acceptance check.

**Final acceptance.** After the public-input checks, `verify_plonk` returns `final_verification && lagrange_check` - both the batched-KZG pairing check *and* the independent verification of every Lagrange-inverse hint must hold. Neither alone is sufficient: the pairing check alone would trust unverified Lagrange inverses (letting a prover misstate the public-input polynomial evaluation), and the Lagrange check alone says nothing about the constraint system itself.

## 5. Design differentiation and notable implementation choices

**An affine front door with no group arithmetic.** `raw_affine.ak` accepts a verification key/proof in affine `G1Affine`/`G2Affine` form (from `common/blst_affine.ak`) and compresses it with `g1_affine_compress`/`g2_affine_compress`. Compression keeps `x` and only the sign of `y`, so `g1_affine_compress` first checks the point (`g1_affine_valid`): each coordinate must be exactly 48 bytes and below `p`, and `y² = x³ + 4` must hold, so every G1 point has exactly one affine form ([#15](https://github.com/ADAOcommunity/zk/issues/15)). It fails otherwise. Then it sets the header flag bits on the `x` bytes. `g2_affine_compress` does the same with `g2_affine_valid`, which checks the four Fp components the same way and `y² = x³ + 4(1 + u)` in Fp2. The output goes to the native `g1.decompress`/`g2.decompress` builtins inside `plonk_prepare_preinputs`/`plonk_prepare_proof`, which validate curve and subgroup membership, so this path doesn't depend on `common.ak`'s hand-rolled field arithmetic. Integrations can use it or pass compressed bytes directly.

**Transcript derivation happens twice, deliberately.** `plonk_prepare_proof` (in `proofs.ak`) independently recomputes `beta`, `gamma`, `alpha`, and `zeta` - the same challenges `verify_plonk` will later recompute a second time from scratch - purely to derive the `lagrange_inverses` hint at prepare-time. This is not redundant from a soundness standpoint: `verify_plonk` cannot trust `zeta` (or any other challenge) as supplied by whatever prepared the proof, since a party controlling that value could otherwise choose a favorable challenge. Recomputing the full transcript inside `verify_plonk` itself is what makes the challenges binding; the earlier computation in `plonk_prepare_proof` only exists to produce the (also independently re-checked) Lagrange-inverse hint before the proof is placed in a datum or redeemer.

**Batched KZG rather than one pairing per polynomial.** A naive implementation of PLONK's verification equation would check each committed polynomial's opening separately - on the order of 7-9 individual pairings. This module follows the standard batching technique (via the `v` and `u` challenges) that folds all of them into exactly two Miller loops and one final exponentiation, which is the difference between an unusably expensive verifier and one that fits a single Cardano transaction (§7).

**A bare `Bool`, matching the rest of the package.** As with `groth` and `bullet`, `verify_plonk` returns `Bool` rather than a typed error, for the same reason: a Plutus validator ultimately reduces to accept/reject.

## 6. Security argument

PLONK's soundness rests on three layers this module is responsible for enforcing together, none of which is sufficient alone: the gate constraints bind `(a, b, c)` to values satisfying the circuit's arithmetic at every domain point; the copy-permutation argument (via `alpha`, `beta`, `gamma`, and the grand-product commitment `Z`) binds those same wire values to a consistent single execution trace across gates; and the batched KZG opening binds every polynomial evaluation the verifier trusts (the constraint identity, the permutation argument, the quotient split) to the actual committed polynomials, under the standard KZG discrete-log assumption over the SRS. All of this is checked at one random point `zeta`, via a Schwartz–Zippel argument: a prover who did not honestly satisfy the constraint and permutation identities as full polynomials would need the identity to coincidentally hold at a point they could not have predicted before committing.

The three things this module's `verify_plonk` asserts - that the public inputs and the inverse list have the lengths the key fixes, with every input in `[0, r)`; `final_verification` (the batched pairing check); and `lagrange_check` (every Lagrange-inverse hint is a genuine field inverse) - are, together, the complete on-chain expression of that argument. The first is what ties each input the validator sees to exactly one term of the public-input polynomial. As with Groth16, this module does not and cannot verify that the SRS's toxic waste was destroyed; that is a precondition of whichever ceremony produced `x2`, entirely out of scope for on-chain code.

## 7. Testing and verification

Twelve tests in `tests/plonk_tests.ak` exercise this module directly, against a single external test-vector pair (`n_public = 2`, `power = 3`, i.e. an 8-point evaluation domain) presumably produced by an external PLONK toolchain (the code's own transcript ordering explicitly targets "snarkjs's keccak256-compressed transcript variant"), since - as with Groth16 - this codebase implements no PLONK prover or setup of its own:

| Test | Verifies |
|---|---|
| `test_vkey_g1_compression` / `test_vkey_g2_compression` | Every vkey point compresses without error |
| `test_preinputs_creation` / `test_plonk_prepare_preinputs` | `PlonkPreInputs` construction and preparation succeed |
| `test_prepare_vkey_function` / `test_prepare_affine_proof_function` | The `raw_affine.ak` convenience wrappers succeed |
| `test_generator_value` / `test_power_calculation` / `test_generator_list_creation` | The evaluation-domain scalars (`ω`, `2^power`, `ω^i` list) are computed correctly |
| `test_plonk_verification_with_affine_points` | A genuine proof against the fixture verification key verifies |
| `test_plonk_verification_rejects_tampered_proof` | Mutating `a_eval` by 1 is rejected (`test ... fail`) |
| `test_plonk_verification_rejects_wrong_pub_inputs` | Substituting a different public-input list is rejected (`test ... fail`) |

`tests/point_tests.ak` (15 further tests, also part of the package's 82) directly exercises `common/blst_affine.ak`'s compression and curve-membership helpers against this same fixture's proof and verification-key points, closing the loop on the affine front door described in §5. Three of them cover `g2_affine_valid` ([#15](https://github.com/ADAOcommunity/zk/issues/15)), using the standard G2 generator since recovering random G2 points from their compressed bytes would need an Fp2 square root: the generator, its negation and the fixture's `x2` are valid and the first two compress to the builtin's bytes; a changed `y` component, a component at or above `p`, a flag bit already set, and an extra leading zero byte are rejected; and compressing a wrong `y` fails.

`tests/plonk_props.ak` adds property-based tests (using `aiken-lang/fuzz`, 100 random cases each). `prop_*` tests state behaviour that must hold for any input. Its properties: changing any public input to another value in `[0, r)` is rejected; changing any of the six evaluation scalars is rejected; an input shifted by `k · r` in either direction is rejected ([#12](https://github.com/ADAOcommunity/zk/issues/12)); extra inputs are rejected ([#13](https://github.com/ADAOcommunity/zk/issues/13)); and an inverse list one too long or one too short is rejected ([#14](https://github.com/ADAOcommunity/zk/issues/14)). Unit tests there cover too few inputs, a key whose `n_public` doesn't match the inputs, an empty inverse list, and the generator count for `n_public` of 0, 1, 2 and 5 ([#19](https://github.com/ADAOcommunity/zk/issues/19)). The extra- and missing-input tests can't show the forgery [#13](https://github.com/ADAOcommunity/zk/issues/13) describes: an honest proof already fails with the wrong number of inputs, because the transcript changes, so they pass with or without the count check, and showing the forgery needs a modified prover. The `n_public` test guards the check instead: it keeps a valid proof, inputs and generators and sets the key's `n_public` to 1 and then 3, and only the count check reads that field. The other new tests were each checked against the unfixed code, where they fail. `tests/point_props.ak` checks that `g1_affine_compress` produces exactly the builtin's encoding for random points, and that `g1_affine_valid` rejects a different `y` on the same side of `(p - 1) / 2`, a coordinate at or above `p` (including an `x` with a flag bit already set), and a coordinate with an extra leading zero byte ([#15](https://github.com/ADAOcommunity/zk/issues/15)); a unit test checks that compressing a point with the wrong `y` fails. Each was checked by removing the matching part of the check, where it fails.

`test_plonk_verification_with_affine_points`, which prepares the key and proof as well as verifying, measures approximately 4.97M memory units and 8.11B CPU units - by far the most expensive single call among this package's three verifiers (compare Groth16's ~89.6K mem / 2.80B cpu and Bulletproofs' range proof at ~5.2M mem / 14.2B cpu at `n=8`), and leaves markedly less headroom against Cardano's per-transaction budget than either. Cost scales with `n_public`: each additional public input adds both a Lagrange-inverse check and a term in the public-input polynomial evaluation; only the 2-public-input fixture has been measured. The G1 point check adds about 11K memory and 4.6M CPU per finite point, or 161K memory and 68M CPU for the fixture's 15 (six in the key and nine in the proof; the key's `q_r` and `q_c` are the point at infinity, which isn't checked), and the G2 check on the key's `x2` about 31K memory and 16M CPU.

## 8. Known limitations and roadmap

- **No trusted-setup tooling.** This module consumes `x2` (and the rest of the verification key) but has no way to generate or attest to a universal SRS; that must come from an external ceremony (e.g. Perpetual Powers of Tau plus a circuit-specific phase 2) this package neither runs nor audits.
- **No on-chain prover, by design (§5).** Proof generation, circuit compilation, and preprocessing are all out of scope; a production integration needs its own off-chain PLONK toolchain feeding this verifier.
- **Only `n_public = 2` has a real proof to test against.** The `n_public = 0` path (one generator for `L_1`, no input terms) is covered only by the generator-count test.
- **Execution-unit cost is only measured at `n_public = 2`.** This is the most expensive verifier in the package per call already; larger public-input counts should be benchmarked before use in a real deployment.
- **No on-chain entry point yet.** Like the other two modules in this package, how a validator obtains and trusts a given verification key/proof pair (datum/redeemer wiring) is separate, follow-on work.
- **No cross-implementation interoperability testing beyond one fixture.** The transcript and batching scheme are documented as matching a `snarkjs`-style variant, but only one externally-produced proof has been used to validate that against this implementation; broader test vectors are future work.
- **No external cryptographic audit.** As with the rest of this package, internal design review only; not a substitute for a formal audit before mainnet or high-value use.

## 9. Conclusion

This module delivers a functional PLONK verifier built on native BLS12-381 pairing and decompression builtins, using the standard batched-KZG technique to keep a verification equation that would otherwise require many separate pairings down to two Miller loops and one final exponentiation. Its two-hint design (Lagrange inverses computed off-chain, checked cheaply on-chain) and its affine front door are documented, deliberate engineering choices; the clearest remaining gaps are the ones every verifier-only module in this package shares - no owned trusted setup, no owned prover, and no external audit.
