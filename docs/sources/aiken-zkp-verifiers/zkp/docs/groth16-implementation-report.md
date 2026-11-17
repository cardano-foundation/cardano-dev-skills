# Groth16 Verifier - Implementation Report

- **Module:** `zkp/lib/groth/groth.ak`
- **Status:** Functional, tested, unaudited
- **Test results:**
  - `aiken check` 3/3 in `tests/groth_tests`, plus 6/6 property and known-issue tests in `tests/groth_props` (part of 64/64 across the package)
  - `aiken fmt` clean
  - `aiken build` succeeds

## 1. Overview

This module implements a Groth16 zk-SNARK verifier over the BLS12-381 curve, as one of three zero-knowledge proof systems in this repository's `zkp` package for Cardano smart contracts (Aiken, targeting Plutus V3). Given a circuit-specific verification key and a proof `(A, B, C)`, it checks the canonical Groth16 pairing equation against a list of public inputs, without the validator ever seeing the witness.

Unlike this package's `bullet` module, `groth` implements **verification only**. Groth16 needs a circuit-specific trusted setup and a full R1CS/QAP witness computation to produce a proof; this codebase does not implement a prover or a setup ceremony for either, consistent with this package's own design notes (`docs/step-by-step.md`), which state plainly that proof generation and setup are assumed to happen off-chain. Everything in this module exists to answer one question on-chain: is this proof, for this verification key and these public inputs, valid?

This report covers the implementation as it stands: what was built, how it works, where it departs from a naive port of the mathematics, and what remains before it is production- or audit-ready.

## 2. Position within the `zkp` package

| Module | Proof system | Setup | Core primitive |
|---|---|---|---|
| `lib/groth` | Groth16 | Trusted, circuit-specific | Pairings (`bls12_381_miller_loop`, `bls12_381_final_verify`) |
| `lib/plonk` | PLONK | Universal, trusted | Kate commitments, permutation argument |
| `lib/bullet` | Bulletproofs | Public, trustless | Discrete-log / Pedersen commitments, no pairings |
| `lib/common` | — | — | Shared field/point scaffolding, superseded in this module (see §4) |

Groth16 sits at the opposite end of the setup-trust spectrum from Bulletproofs: it requires the smallest, cheapest verifier of the three (four pairings, no polynomial commitments, no vector openings) at the cost of a per-circuit trusted ceremony that must be run and attested to outside this codebase.

## 3. Architecture

**Types**

```
CompressedVK    { alpha, beta, gamma, delta, vkIC }   // all ByteArray
CompressedProof { a, b, c }                            // all ByteArray
VerifierKey     { alpha: G1Element, beta/gamma/delta: G2Element, vkIC: List<G1Element> }
Proof           { a: G1Element, b: G2Element, c: G1Element }
```

The `Compressed*` types are the wire/datum format: standard 48-byte (G1) and 96-byte (G2) BLS12-381 compressed point encodings, suitable for storing directly in a redeemer or datum as plain `ByteArray`. `VerifierKey`/`Proof` are the decompressed, native-`G1Element`/`G2Element` working form the pairing check operates on.

**Entry points**

- `uncompress_vk(CompressedVK) -> VerifierKey`, `uncompress_proof(CompressedProof) -> Proof` - decode the wire format via native decompression.
- `verify(vk, proof, inputs) -> Bool` - the core verifier, operating on already-decompressed types.
- `verify_compressed(vk, proof, inputs) -> Bool` - convenience wrapper that decompresses then calls `verify`; the function a validator is expected to call.
- `pairing_check(...) -> Bool` and `derive(...) -> G1Element` - the two building blocks `verify` composes.

## 4. Protocol walkthrough

**Decompression.** `uncompress_vk`/`uncompress_proof` call `bls12_381_g1_uncompress`/`bls12_381_g2_uncompress` directly - the native Plutus builtins - for every point. This is a deliberate departure from `lib/common/common.ak`, which contains its own hand-rolled `g1_compress`/`g1_decompress` pair built from manual modular arithmetic (`mod_inv`, a Tonelli-Shanks `mod_sqrt`, and a `miller_loop`/`final_exponentiation` pair that are explicitly placeholder stand-ins, by their own comments, for real `Fp12` arithmetic). `groth.ak` does not use any of it. Every point this module handles is validated as a genuine, in-subgroup curve point by the native builtin at decompression time, not by this package's own field simulation.

**Public-input combination.** `derive` folds the verification key's `vkIC` vector against the public inputs: `K = vkIC[0] + Σ inputs[i] · vkIC[i+1]`. It recurses on both lists in lockstep, terminating when `vkIC` is exhausted. If `vkIC` still has entries once `inputs` runs out, it hits an explicit `fail` - a guard against silently under-supplying public inputs. Note the asymmetric case: if `inputs` has *more* entries than `vkIC - 1` needs, the extra ones are never consumed and are silently ignored, since recursion stops as soon as `vkIC` is empty. This is safe (it cannot forge acceptance of a wrong statement, since the ignored inputs don't appear in the pairing at all) but is a latent inconsistency worth closing before this is exposed to arbitrary caller-supplied input lists (see §8).

**Pairing check.** `verify` calls `pairing_check(A, B, C, delta, alpha, beta, K, gamma)`, which computes four Miller loops - `e(A,B)`, `e(alpha,beta)`, `e(K,gamma)`, `e(C,delta)` - combines the latter three with `bls12_381_mul_miller_loop_result`, and finishes with a single `bls12_381_final_verify(e(A,B), combined)`. This checks the canonical Groth16 equation `e(A,B) = e(alpha,beta) · e(C,delta) · e(K,gamma)` using the ledger-native pairing builtins throughout - there is no custom `Fp12` code anywhere in this path, unlike `common.ak`'s placeholder pairing functions.

## 5. Design differentiation from a naive port and from `common.ak`

**Verifier-only, by design, not by omission.** This module has no `generate_proof` and no setup routine. That is the correct shape for Groth16 in this context: the trusted setup is a circuit-specific ceremony that must be run once, off-chain, by parties independent of this codebase, and the proof itself requires a full R1CS/QAP witness computation this package does not and should not reimplement. Contrast this with `lib/bullet`, which owns both prover and verifier because Bulletproofs' public-parameter model makes that safe to do in one place; Groth16's trust model makes the equivalent choice here unsafe, so it isn't made.

**Native decompression instead of `common.ak`'s field simulation.** As in §4, every group element in this module is validated by the audited native builtin at the point it enters the system, rather than by this package's own coordinate-wise modular arithmetic. This is the same departure documented in the Bulletproofs report for the `bullet` module, applied identically here: `common.ak` is retained in the package for reference/legacy reasons but is not part of the trusted path this verifier relies on.

**Tested against externally-generated fixtures, not self-generated proofs.** Because Groth16's setup and proving are out of scope for this codebase, the three tests in `lib/tests/groth_tests.ak` verify fixed, externally-produced `(VK, proof, public_inputs)` triples rather than round-tripping a proof this package generated itself. This is the inverse of the Bulletproofs module's testing posture (§7 of the Bulletproofs report), where prover and verifier are co-tested in-language; here, the verifier is the only thing this codebase owns, so the fixtures stand in for a circuit and ceremony this codebase cannot itself produce.

**A bare `Bool`, matching the rest of the package.** `verify`/`verify_compressed` return `Bool`, not a typed `Result`, for the same reason given in the Bulletproofs report: a Plutus validator ultimately reduces to accept/reject, and a bespoke error taxonomy per proof system isn't warranted.

## 6. Security argument

Soundness rests entirely on two facts holding simultaneously: the trusted setup's toxic waste (`tau`, and the per-circuit secret values it implies) was genuinely destroyed, and the four-pairing equation checked by `pairing_check` is exactly the Groth16 verification equation - no more, no less. This module does not, and cannot, verify the first fact; it is a precondition supplied by whichever ceremony produced the `VerifierKey` this module is given, and is entirely out of scope for on-chain code. What this module is responsible for, and what its tests exercise, is the second fact: that a proof failing to satisfy the true relation is rejected (§7's `groth_verify_fail_1`, where `A` and `C` are swapped relative to a valid proof) and that a genuine proof is accepted (`groth_verify_pass_1`/`_2`, against two different public-input sets on the same verification key).

Because decompression goes through the native builtins, every `G1Element`/`G2Element` this module operates on is guaranteed by the ledger itself to be a valid, in-subgroup curve point - the small-subgroup and invalid-curve attack classes that a hand-rolled decompression routine would need to defend against explicitly are handled upstream, before this module's own logic ever runs.

## 7. Testing and verification

Three unit tests in `tests/groth_tests.ak` exercise this module against external fixtures:

| Test | Verifies |
|---|---|
| `groth_verify_pass_1` | A genuine proof against a 2-public-input circuit verifies |
| `groth_verify_fail_1` | A proof with `A` and `C` swapped is rejected (`test ... fail`) |
| `groth_verify_pass_2` | A second genuine proof, different public inputs, same verification key, verifies |

`tests/groth_props.ak` adds property-based tests (using `aiken-lang/fuzz`, 100 random cases each). `prop_*` tests state behaviour that must hold for any input. `known_issue_*` tests pin a filed bug: they pass while the bug exists and fail once it's fixed, at which point they're replaced by the property named in their comment. Its properties: changing any public input to another value in `[0, r)` is rejected; replacing any of `A`, `B` or `C` with an unrelated valid curve point is rejected; and too few public inputs fail. Its known-issue tests cover [#11](https://github.com/ADAOcommunity/zk/issues/11) (extra inputs) and [#12](https://github.com/ADAOcommunity/zk/issues/12) (inputs not range-checked).

All three unit tests measure identically: ~66.9K memory units and ~2.79B CPU units per `verify_compressed` call - comfortably inside Cardano's per-transaction execution budget, and the cheapest of this package's three verifiers by a wide margin, as expected given Groth16's constant-size, pairing-only verification equation.

## 8. Known limitations and roadmap

- **No trusted-setup tooling.** This module consumes a `VerifierKey` but has no way to generate or attest to one; that must come from an external, circuit-specific ceremony this package neither runs nor audits.
- **No on-chain prover, by design (§5).** Proof generation is out of scope; a production integration needs its own off-chain Groth16 prover (e.g. `snarkjs`, `arkworks`, or a `gnark` toolchain) feeding this verifier.
- **Public inputs aren't fully validated.** Too few public inputs traps, but extra inputs beyond `vkIC` are ignored ([#11](https://github.com/ADAOcommunity/zk/issues/11)), and inputs aren't checked to lie in `[0, r)`, so `x` and `x + r` verify with the same proof ([#12](https://github.com/ADAOcommunity/zk/issues/12)). A validator that reads inputs by position or value can be given values the proof doesn't bind. Both are pinned by `known_issue_*` tests in `tests/groth_props.ak`.
- **Only two verification-key shapes have been exercised in tests**, both with `n_public = 2`. Larger `vkIC` vectors (more public inputs) are structurally supported by `derive`'s recursion but are unbenchmarked for execution-unit cost.
- **No on-chain entry point yet.** Like the other two modules in this package, how a validator obtains and trusts a given `VerifierKey`/proof pair (datum/redeemer wiring) is separate, follow-on work.
- **No external cryptographic audit.** As with the rest of this package, internal design review only; not a substitute for a formal audit before mainnet or high-value use.

## 9. Conclusion

This module delivers a functional, correctly-rejecting Groth16 verifier built entirely on native BLS12-381 pairing and decompression builtins, deliberately scoped to verification alone. Its narrow scope is itself a design decision: Groth16's trusted-setup and full-witness-computation requirements are two significant pieces of infrastructure this package correctly declines to reimplement, in favor of a small, cheap, auditable verifier that composes with whatever external toolchain a deployment already trusts to produce proofs and keys.
