# Proof systems and on-chain SNARK verification

The SNARK half of `explain-zk`: what a proof guarantees, which proof system to pick, the working
Groth16 verifier shape, the circuit-to-Aiken pipeline, and the costs. The signature / VRF / KDF /
BBS+ half lives in `bls-primitives.md`.

## What a proof actually claims

A zk-SNARK encodes a statement as an **arithmetic circuit** — equations over a finite field. The
prover holds a private **witness** (the secret), the circuit takes some **public inputs** (values
both sides see), and the proof asserts: *I know a witness that satisfies this circuit for these
public inputs.*

Three guarantees: **completeness** (an honest prover with a valid witness always convinces the
verifier), **soundness** (a prover without one cannot, beyond negligible probability), and
**zero-knowledge** (the verifier learns nothing beyond the truth of the statement).

The consequence that matters most in review: **the proof only proves what the circuit constrains.**
A circuit that checks `a * b * c == n` proves you know three factors of `n`, not three *prime*
factors. Every property an application claims must appear as a constraint.

## Choosing a proof system

| System | Proof size | Trusted setup | How it reaches Cardano |
|---|---|---|---|
| **Groth16** | Smallest (~200 bytes: two G1, one G2) | Per circuit | Circom or gnark circuits; Groth16 verifier in Aiken |
| **PLONK** | ~0.5 KB | Universal, reusable across circuits | Circom via a snarkjs adaptation; Plutus/Aiken verifiers |
| **Halo2 (KZG)** | Circuit-dependent | Universal | Verifier generated from a Rust circuit; also the Midnight proof system |
| **Sigma protocol** (e.g. Schnorr) | A few group elements | None | Implemented directly on the BLS12-381 builtins |

Two contrasts to internalise. Groth16 gives the smallest proof and cheapest verification but needs a
fresh setup per circuit; PLONK and Halo2 pay a little more per proof for a setup you run once. And
not everything needs a circuit: a **sigma protocol** proves knowledge of a discrete logarithm ("I
know the secret behind this public point") with no circuit and no ceremony. If that is all the
application needs, it is the lighter tool.

## The Groth16 verifier shape

A Groth16 verification key and proof are just compressed curve points. This is the structure used by
the compiled `zk-password` example the main skill imports:

```aiken
pub type VerificationKey {
  alpha: ByteArray,        // G1, 48 bytes
  beta: ByteArray,         // G2, 96 bytes
  gamma: ByteArray,        // G2
  delta: ByteArray,        // G2
  ic: List<ByteArray>,     // G1 points; ic[0] is the constant term,
}                          // ic[i+1] pairs with public_input[i]

pub type Proof {
  pi_a: ByteArray,         // G1
  pi_b: ByteArray,         // G2
  pi_c: ByteArray,         // G1
}
```

`groth16_verify(vk, proof, public_inputs)` decompresses the points, folds the public inputs into a
single commitment `vk_x = ic[0] + Σ public_input[i] · ic[i+1]`, and checks the pairing equation

```
e(pi_a, pi_b) == e(alpha, beta) · e(vk_x, gamma) · e(pi_c, delta)
```

with `bls12_381_miller_loop`, `bls12_381_mul_miller_loop_result`, and a single
`bls12_381_final_verify`. Circuit size does not affect this cost — the proof is the same three points
whether the circuit has five constraints or five million. What grows the cost is the **number of
public inputs**, so keep them few and commit bulky data with a single hash.

## The circuit-to-Aiken pipeline

The validator is the last step of a longer path. The canonical first circuit — proving you know a
password whose Poseidon hash equals a public commitment — is one constraint:

```circom
template PasswordLock() {
    signal input hash;   // public: Poseidon(pwd)
    signal input pwd;    // private: never leaves the prover's device
    component h = Poseidon(1);
    h.inputs[0] <== pwd;
    hash === h.out;      // the whole statement
}
component main {public [hash]} = PasswordLock();
```

The end-to-end steps:

1. Write the circuit in Circom (compile with `--prime bls12381`; the default targets a different
   curve) or in gnark.
2. Run the trusted setup to produce the proving key and the verification key.
3. Generate the proof off-chain from the witness and public inputs, in the browser or on a backend.
4. Compress the verification key and proof to Cardano's compressed-point format.
5. The Aiken validator verifies the proof as its spending condition.

For the whole path worked end to end — circuit to Aiken verifier, with the password example — the
`ZK-from-zero-on-Cardano` eBook is the most complete written walkthrough. Generic verifier
implementations are in the ZK/BLS ecosystem map.

## The builtins and the CIPs

- The BLS12-381 builtins require **Plutus V3** (CIP-0381): group operations, the pairing
  (`miller_loop`, `mul_miller_loop_result`, `final_verify`), compression, and hash-to-group, backed by
  the audited `blst` library. These are what make pairing-based SNARK verification possible on Cardano.
- Later builtins made it cheaper: CIP-0133 added multi-scalar-multiplication (the operation that
  dominates PLONK and Halo2 verification), and CIP-0109 added `expModInteger` for modular field
  arithmetic.

## Cost, as measured snapshots

Cost figures move with the protocol and the implementation; treat them as snapshots, not guarantees.
A Groth16 verification has been measured at roughly a fifth to a quarter of one script's CPU budget
(~2.1 billion CPU units in one measurement); a full PLONK verification around a third. Each public
input adds meaningful cost, with about a hundred as a practical ceiling.

## Sharp edges in depth

- **Trusted setup is a real ceremony.** Groth16 and PLONK setups produce toxic waste: whoever holds
  the setup randomness can forge proofs. A multi-party ceremony fixes this — the result is secure if
  *any one* participant was honest. Phase 1 ("powers of tau") is circuit-independent and reusable;
  Groth16's phase 2 must be redone per circuit. A single-party setup is fine for a demo and unsafe
  for a real deployment.
- **Use circuit-friendly hashes, on the right curve.** SHA-256 or Blake2b inside a circuit costs tens
  of thousands of constraints; **Poseidon** and **MiMC** are built for circuits. Standard Poseidon
  parameters are generated for other curves — if you hash over BLS12-381 in-circuit, generate matching
  parameters or the in-circuit hash will never equal the one your off-chain code computed.
- **A proof on-chain is public and replayable.** Bind every proof to its context by committing a
  nonce, the spending transaction, or a session key into the public inputs.
- **Whoever runs the prover sees the witness.** Browser proving keeps the secret on the user's device;
  outsourcing to a server is a trust assumption — name it if you make it.

## Where to go deeper

- Bundled: `docs/sources/developer-portal/developers/curriculum/smart-contracts/advanced/zero-knowledge.md`
  — the full catalog of verifiers, toolkits, and shipped applications.
- Toolchains and libraries: see the ZK/BLS section of `suggest-tooling/references/ecosystem-map.md`.
- The CIPs: CIP-0381 (pairing builtins), CIP-0133 (multi-scalar multiplication), CIP-0109 (modular
  exponentiation) under `docs/sources/cips/`.
