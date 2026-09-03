# Proving Cardano Address Ownership via ZKP

> **Companion article to [Zero Knowledge Proof from first principles](zkp-from-first-principles.md).**
>
> This walkthrough applies the dense first-principles Groth16 pipeline to a production-grade circuit: proving ownership of a Cardano payment key without revealing the private key. It uses the `cardano-address` CLI for real key derivation (CIP-1852 / BIP32-Ed25519) and includes automated positive/negative security tests.
>
> **Prerequisites:** You should have read Installment 1 or be familiar with Groth16 basics (R1CS, QAP, trusted setup, proof generation, pairing verification). All commands assume you are in the [`cardano-foundation/bls`](https://github.com/cardano-foundation/bls) repository.

---

## Table of Contents

- [What it proves](#what-it-proves)
- [Assumptions](#assumptions)
- [Step-by-step key derivation with cardano-address](#step-by-step-key-derivation-with-cardano-address)
- [Generate the circuit witness input](#generate-the-circuit-witness-input)
- [Full Groth16 pipeline](#full-groth16-pipeline)
- [Nova step-chain variant](#nova-step-chain-variant)
- [Security test: positive and negative cases](#security-test-positive-and-negative-cases)

---

## What it proves

A Cardano wallet address is derived from a **mnemonic phrase** → **root key** → **payment key** via the standard CIP-1852 / BIP32-Ed25519 hierarchy. The payment signing key (`pay.xsk`) is an extended Ed25519 key, and the payment verification key (`pay.vk`) is the corresponding 32-byte compressed public key.

The `CardanoEd25519Ownership` circuit (~1.97M constraints) proves:

> **I know the private scalar `sk` such that `PublicKey = [sk]·G` on Curve25519.**

The public input is the 256-bit compressed public key `A`. The private witness is the 255-bit clamped scalar `sk` plus the decompressed point `PointA` in extended coordinates. The verifier checks — via the Groth16 pairing equation — that the scalar multiplication and point compression constraints are satisfied, without ever learning `sk`.

---

## Assumptions

This walkthrough assumes two tools are installed:

| Tool | How to get it | Why we need it |
|------|---------------|----------------|
| `cardano-address` | [IntersectMBO/cardano-addresses releases](https://github.com/IntersectMBO/cardano-addresses/releases) | Derives real Cardano keys from a mnemonic (CIP-1852) |
| `bech32` (CLI) | [IntersectMBO/bech32 releases](https://github.com/IntersectMBO/bech32/releases) | Decode bech32 key files into hex for the Python helper |

The `groth16` CLI (`clis/groth16`) and the `trusted-setup` CLI (`clis/trusted-setup`) are already built (e.g. `cargo build --release` in each), and `snarkjs` is assumed to be in `PATH`. The trusted-setup ceremony lives in the standalone `trusted-setup` CLI; the `groth16` CLI covers only prove/verify/export-vk.

---

## Step-by-step key derivation with cardano-address

The `cardano-address` CLI implements the exact derivation path used by Daedalus, Yoroi, and Lace. We follow it step by step so the resulting keys are **mainnet-compatible**.

```bash
cd circom/CardanoKeyOwnership

# (a) Generate a 15-word recovery phrase
cardano-address recovery-phrase generate --size 15 > phrase.prv

# (b) Derive the extended root signing key from the mnemonic
cardano-address key from-recovery-phrase Shelley < phrase.prv > root.xsk

# (c) Derive the payment signing key (standard path: 1852H/1815H/0H/0/0)
cardano-address key child 1852H/1815H/0H/0/0 < root.xsk > pay.xsk

# (d) Extract the public payment key without chain code
cardano-address key public --without-chain-code < pay.xsk > pay.vk
```

**What each file contains:**

| File | Format | Bytes | Contents |
|------|--------|-------|----------|
| `phrase.prv` | 15 BIP-39 words | — | Recovery phrase (keep secret) |
| `root.xsk` | bech32 (`root_xsk…`) | 96 | Extended root signing key |
| `pay.xsk` | bech32 (`addr_xsk…`) | 96 | Extended payment signing key. First 32 bytes = `kL`, the clamped Ed25519 scalar. |
| `pay.vk` | bech32 (`addr_vk…`) | 32 | Compressed Ed25519 public key (no chain code) |

> **Key insight for (c) and (d).** In Cardano's BIP32-Ed25519 implementation, the first 32 bytes of `pay.xsk` (`kL`) are **already clamped** — bits 0–2 are cleared, bit 254 is cleared, and bit 253 is set. This scalar is exactly what the circuit needs as the private witness `sk[255]`. The public key in `pay.vk` is the standard 32-byte Ed25519 compressed point. No extra SHA-512 or clamping logic is required beyond reading the bytes.

---

## Generate the circuit witness input

A Python helper (`gen_cardano_address_input.py`) decodes the bech32 files and converts the keys into the bit/chunk format the Circom circuit expects:

```bash
python3 gen_cardano_address_input.py --xsk pay.xsk --vk pay.vk -o input.json
```

This script does four things:
1. **Decodes bech32** — uses the `bech32` library to turn `addr_xsk…` and `addr_vk…` into raw byte strings.
2. **Extracts the scalar** — reads the first 32 bytes of `pay.xsk` (`kL`) and applies idempotent Ed25519 clamping (clear bottom 3 bits, clear top bit, set second-top bit).
3. **Decompresses the public key** — uses the Ed25519 point-decompression formula (`x² = (y²−1)/(dy²+1)`, square-root, sign-bit correction) to recover extended coordinates `[X, Y, Z, T]` modulo `p = 2²⁵⁵ − 19`.
4. **Chunks and bitifies** — splits each coordinate into 3 chunks of 85 bits (the limb size used by the Circom `ScalarMul` template), and converts the scalar and public key into little-endian bit arrays.

The output `input.json` contains:
- `A[256]`: compressed public key bits
- `sk[255]`: clamped scalar bits
- `PointA[4][3]`: decompressed point in 85-bit chunks

> **Why `--without-chain-code`?** The chain code (last 32 bytes of an extended key) is only needed for deriving child keys. The ownership circuit only cares about the public key point itself. Omitting the chain code keeps `pay.vk` at exactly 32 bytes — the standard Ed25519 public key size — which simplifies decoding and avoids confusion.

---

## Full Groth16 pipeline

With `input.json` in hand, the rest of the pipeline is identical to the `SumOfProducts` walkthrough from the first-principles article, except the circuit is ~1.97M constraints and **must use the sparse prover** (dense matrices would require ~15 TB RAM).

```bash
# 1. Generate the witness
snarkjs wtns calculate \
  cardano_ed25519_ownership_js/cardano_ed25519_ownership.wasm \
  input.json \
  witness_ownership.wtns

# 2. Dev ceremony (sparse — mandatory for this circuit size)
cd ../../clis/groth16
../../clis/trusted-setup/target/release/trusted-setup ceremony-dev --sparse \
  --circuit ../../circom/CardanoKeyOwnership/cardano_ed25519_ownership.r1cs \
  --proving-key /tmp/cardano_ownership.pk \
  --verifying-key /tmp/cardano_ownership.vk

# 3. Prove
cargo run --release -- prove --sparse \
  --circuit ../../circom/CardanoKeyOwnership/cardano_ed25519_ownership.r1cs \
  --witness ../../circom/CardanoKeyOwnership/witness_ownership.wtns \
  --proving-key /tmp/cardano_ownership.pk \
  --out /tmp/cardano_ownership_proof.bin

# 4. Verify
cargo run --release -- verify \
  --proof /tmp/cardano_ownership_proof.bin \
  --public /tmp/cardano_ownership_proof.pub \
  --verifying-key /tmp/cardano_ownership.vk
# → Verification result: VALID
```

**Expected timings** (16-core AMD Ryzen 9 7950X, 64 GiB RAM):

| Step | Time | Memory |
|------|------|--------|
| Sparse dev ceremony | ~5 min | ~2.5 GiB |
| Prove | ~1.7 min | ~2.5 GiB |
| Verify | ~2 s | negligible |

---

## Nova step-chain variant

The same ownership statement can also be proven with **Nova IVC**: [`cardano_ed25519_ownership_nova.circom`](../circom/CardanoKeyOwnership/cardano_ed25519_ownership_nova.circom) decomposes the base-point scalar multiplication into **255 identical steps** of 7,724 constraints each, and the standalone [`nova` CLI](../clis/nova/) (`nova params / ceremony / fold / verify`) proves them incrementally, binding the state chain with a BLAKE2b512 transcript. Each step is a standard Groth16 proof over the same BLS12-381 stack, so no new cryptographic machinery is involved.

Compared with the monolithic flow above, the ceremony drops from ~8 min to ~3 s and the proving key from 1.2 GB to 5 MB, with per-step memory instead of the ~4.5 GiB peak. The trade-off is that the step chain is inherently sequential and `nova verify` is still O(N) — it re-checks every step proof. The constant-size Relaxed-R1CS folding + compression SNARK (O(1) bundle, one pairing check) is the roadmap item tracked in the [`nova-prover`](../nova-prover/) crate.

The full step-by-step flow — building the CLI, compiling the step circuit, the iterative step-witness generation that makes the chain invariant hold by construction, and the `nova params / ceremony / fold / verify` run with expected output — is in [`circom/CardanoKeyOwnership/README.md`](../circom/CardanoKeyOwnership/README.md) §End-to-end flow — Nova step-chain, together with a pre-Nova vs Nova benchmark table.

---

## Security test: positive and negative cases

Groth16's soundness guarantee means **no one can forge a proof for a public key they do not own**. We verify this empirically with two tests included in the repository.

**Test A — Positive (happy path):** Alice proves she owns her own key.
1. Alice generates a mnemonic, derives `pay.xsk` and `pay.vk`, builds `input.json`.
2. `snarkjs wtns calculate` produces a valid witness because `ScalarMul(Alice_sk, G) == Alice_PointA` and `PointCompress(Alice_PointA) == Alice_A`.
3. The prover generates a proof. The verifier checks it against Alice's public key. Result: `VALID`.

**Test B — Negative (forgery attempt):** Bob tries to prove he owns Alice's key.
1. Bob has his own `bob_pay.xsk` but sees Alice's `alice_pay.vk` on-chain.
2. Bob builds a "forged" input using **Bob's scalar + Alice's public key**.
3. `snarkjs wtns calculate` **fails** with `Assert Failed` because the circuit constraint `PointCompress(PointA) == A` is violated: `ScalarMul(Bob_sk, G)` produces Bob's public key, not Alice's.
4. Even if Bob bypassed witness generation, the Groth16 prover would detect the unsatisfied R1CS constraints and reject the proof. And even if a proof were produced, the verifier's pairing check would fail because the public-input commitment `V` is bound to Alice's key, not Bob's.

The repository includes a shell script that automates both tests end-to-end:

```bash
cd circom/CardanoKeyOwnership
./test_cardano_address_e2e.sh
```

This script:
- Generates two independent mnemonics (Alice and Bob)
- Derives payment keys for both
- Runs the full ceremony → prove → verify pipeline for Alice
- Attempts the forgery with Bob's scalar + Alice's public key
- Confirms the forgery is rejected at the witness-generation stage
- Verifies Bob's own proof separately to show each proof is bound to its key

The test takes ~7–9 minutes (two ceremonies + two proofs) and serves as a living security regression test for the ownership circuit.
