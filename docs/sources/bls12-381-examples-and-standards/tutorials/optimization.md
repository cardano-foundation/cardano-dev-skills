# Groth16 from first principles — Installment 2: Optimizations and the trusted-setup ceremony

> **Installment 2 of 5.** In [Installment 1](zkp-from-first-principles.md) we built the entire Groth16 pipeline from first principles: R1CS → QAP → trusted setup → proof → pairing check, walking a tiny 5-constraint `SumOfProducts` circuit through 16 printable binaries. That article deliberately used the *dev* ceremony — fixed, deterministic scalars (`τ=6, α=5, β=7, γ=11, δ=13`) — so that every intermediate value is reproducible.
>
> What it did *not* cover in depth is the **ceremony itself**: why the scalars must be secret and random, how a malicious `τ` turns the proof system into a forgery factory, and how a production trusted-setup ceremony generates those scalars so that nobody ever learns them. That explanation lived awkwardly inside Installment 1 — decoupled from the `groth16-prover` pipeline it was walking through, because the ceremony code actually lives in a separate CLI (`clis/trusted-setup`). We relocated it here, where it belongs: Installment 2 is the *production* installment, and the trusted setup is the first production concern we must get right before we can talk about FFT, MSM, and other optimizations.
>
> The rest of this installment — the engineering optimizations (FFT, Pippenger MSM, sparse matrices, on-the-fly witness accumulation), the survey of competing proof systems (PLONK, Bulletproofs++, STARKs), and the zkVM detour — will be filled in as we go. This document is the ceremony foundation for that work.

---

## Table of Contents

- [Why the scalars must be secret and random](#why-the-scalars-must-be-secret-and-random)
- [The forgery attack if τ is known](#the-forgery-attack-if-τ-is-known)
- [Why randomness matters](#why-randomness-matters)
- [The ceremony intuition: 1-of-N trust](#the-ceremony-intuition-1-of-n-trust)
- [Dev ceremony vs. production ceremony](#dev-ceremony-vs-production-ceremony)
- [The scalars and who must not know them](#the-scalars-and-who-must-not-know-them)
- [The ceremony in our repository](#the-ceremony-in-our-repository)
- [What's next in this installment](#whats-next-in-this-installment)

---

## Why the scalars must be secret and random

The five scalars `τ, α, β, γ, δ` are the *cryptographic heart* of Groth16. If any party knows them, the entire proof system collapses. This is not an exaggeration — it is a mathematical theorem. Let us see why.

> **Recap from Installment 1.** The prover evaluates polynomials at a single secret point `τ` "in the exponent": proof element `A` encodes `l(τ) + α`, element `B` encodes `r(τ) + β`, and element `C` locks the witness to the circuit through `α`, `β`, `γ`, `δ`. The verifier never sees `τ` — it only sees the curve points `τⁱ·G1`, `τⁱ·G2` produced by the ceremony. The entire protocol rests on `τ` (and its friends) staying secret forever.

### The forgery attack if τ is known

Suppose an attacker learns `τ = 6`. They can now compute `T(τ) = 720` directly. They can pick *any* fake witness they want — say, `a = 100, b = 100, c = 100, d = 100, e = 100, f = 100, g = 100, h = 100` — which gives intermediates `p1 = 10000, p2 = 10000, p3 = 10000, p4 = 10000, p5 = 10000, p6 = 10000`. This witness does not need to satisfy the R1CS constraints in the polynomial sense; the attacker can simply compute `l(τ), r(τ), o(τ)` and then *choose* `h(τ)` to make the equation balance:

```
h(τ) = (l(τ)·r(τ) − o(τ)) / T(τ)
```

Because the attacker knows `τ`, they can compute this quotient even when the witness is garbage. They then build proof elements `A, B, C` using the *legitimate* SRS points (which are public) and their chosen `h(τ)`. The verifier's pairing check will pass — because the equation is algebraically satisfied at `τ` — even though the witness violates the actual circuit constraints at every other point.

In other words, **knowledge of `τ` lets the attacker "cheat" the single-point check without ever satisfying the multiplicative constraints.** The same logic applies to `α, β, γ, δ`: if any of them are known, the attacker can separate the public and private parts of the proof arbitrarily, forging a valid-looking proof for any statement.

### Why randomness matters

You might ask: why not just hard-code `τ = 42` and publish it? Everyone would know it, but at least the system would be transparent.

The problem is **precomputation attacks.** If `τ` is predictable, an attacker with enough resources could compute `τ^i · G1` and `τ^i · G2` for astronomically large `i` *before* the SRS is even published. They could then break the discrete logarithm problem in the exponent using pre-computed tables. Randomness ensures that no one can prepare for the setup in advance.

Moreover, `α, β, γ, δ` must be *independent* random values. If `α = β`, the proof element `C` loses its binding to the left input, and an attacker can swap `l(τ)` and `r(τ)` without detection. If `γ = δ`, the public and private input commitments collapse into one, destroying the zero-knowledge property.

### The ceremony intuition: 1-of-N trust

Groth16 solves this with a **trusted setup ceremony**: multiple participants jointly generate the scalars, each contributing their own randomness. The security guarantee is simple and powerful:

> **As long as at least one participant was honest and truly destroyed their randomness, the final `τ` remains unknown forever.**

Even if every other participant colluded and shared their secrets, they cannot reconstruct `τ` without the missing contribution. This is why the ceremony needs many independent participants — the probability that *everyone* is dishonest and keeps a backup decreases as the participant count grows.

### Dev ceremony vs. production ceremony

Our repository uses two different approaches for two different purposes:

| Purpose | Scalars | Security | Why we use it |
|---------|---------|----------|---------------|
| **Learning & debugging** (`ceremony-dev`) | Fixed small primes (`τ=6, α=5, ...`) | **None** — anyone can forge | Every value is printable and reproducible. You can add a `println!` and see exactly what the code does. |
| **Production** | Large random field elements, generated in a ceremony | Secure if at least one ceremony participant was honest | The scalars are never assembled in one place. Only the curve points `τ^i·G1`, `τ^i·G2`, etc. are published. |

The dev ceremony is completely insecure for production — anyone who reads the source code knows `τ` and can forge proofs. But it is invaluable for learning, which is why Installment 1 uses it at every step. The production ceremony is what makes Groth16 safe for real-world deployments.

> **The bottom line.** Groth16's speed and compactness come from a *single* secret evaluation point `τ`. That point must remain secret forever, or the proof system becomes a forgery factory. The trusted setup ceremony is the mechanism that creates `τ`, embeds it into curve points, and then destroys it — provided at least one participant was honest. This is the fundamental trade-off of Groth16: you get the smallest and fastest proofs in cryptography, but you must trust the ceremony once.

---

## The scalars and who must not know them

All five scalars must be unknown to every party after the ceremony — the prover, the verifier, and any third party. The ceremony is run by a dedicated group of **organizers** who are independent of both the prover and the verifier: they generate the scalars jointly, embed them into curve points (the SRS), and then destroy the raw scalars. The prover and verifier never participate in the ceremony and never see the raw scalars — they interact only with the curve points. The prover uses the full SRS (power tables + proving key), and the verifier uses only a small subset (the verifying key). This is why the setup is "trusted": the security guarantee is that at least one organizer honestly destroyed their contribution, making it impossible to reconstruct any of the five scalars.

| Parameter | Value (dev) | Role | Risk if leaked |
|-----------|-------------|------|----------------|
| `τ` (tau)   | 6   | Secret evaluation point — encodes the SRS power tables `τⁱ·G1`, `τⁱ·G2` | Attacker computes `h(τ)` for any fake witness, forging proofs for false statements |
| `α` (alpha) | 5   | Binds proof element `A` to proof element `C` — prevents the prover from decoupling the left and right witness polynomials | Attacker can swap `l(τ)` and `r(τ)` without detection, breaking the binding between proof elements |
| `β` (beta)  | 7   | Binds proof element `B` to proof element `C` — ties the right witness polynomial into the same commitment as the quotient | Same as `α`: attacker can separate `B` from `C`, breaking soundness |
| `γ` (gamma) | 11  | Denominator for **public-input** CRS elements — separates the public-input commitment `V` from the private-input part of `C` | Public and private input commitments collapse; attacker can forge proofs by manipulating the public-input split |
| `δ` (delta) | 13  | Denominator for **private-input** CRS elements — ensures the prover cannot tamper with the private-input commitment in `C` without `δ`'s knowledge | Attacker can fabricate the private-input part of `C`, forging proofs without a valid witness |

Note the *dev* values in the table are deterministic and public — that is exactly why the dev ceremony is unsafe for production. In production the same five roles are filled by large random field elements. For the 5-constraint `SumOfProducts` circuit, `τ = 6` is required because the constraint points are `{0, 1, 2, 3, 4}` — using `τ = 3` or `τ = 4` would make `T(τ) = 0` and break the proof.

> **The CRS vs. the SRS.** The SRS is the *power table* (`τ^i·G1`, `τ^i·G2`) — it lets the prover evaluate arbitrary polynomials at `τ`. The CRS *fixed points* are the *anchor points* (`α·G1`, `β·G2`, `γ·G2`, `δ·G2`) — they encode the mixed scalars that tie the proof to the specific circuit. In a production trusted setup, the SRS is universal (can be reused for many circuits), while the CRS fixed points are circuit-specific because they depend on `α`, `β`, `γ`, `δ`.

---

## The ceremony in our repository

The trusted-setup ceremony lives in the standalone [`clis/trusted-setup`](https://github.com/cardano-foundation/bls/blob/main/clis/trusted-setup/) crate (the `trusted_setup` library plus the `trusted-setup` CLI). Proof generation, verification, and verifying-key export live in the separate `groth16` CLI (`clis/groth16`). This split is deliberate: the ceremony is a one-time, circuit-lifecycle operation, while proving/verifying is what happens at runtime. The crate exposes the ceremony core as a reusable library with the modules `r1cs`, `qap`, `engine`, `ceremony`, `phase2`, `ptau`, `circom_adapter`, `prover`, and `cmd`; the `groth16-prover` library re-exports these modules.

### `ceremony-dev` — the single-party dev ceremony

```bash
cd clis/trusted-setup
cargo build --release

trusted-setup ceremony-dev \
  --circuit circuit.r1cs \
  --proving-key circuit.pk \
  --verifying-key circuit.vk
```

A single-party ceremony that generates fixed local scalars deterministically (for debugging) or local randomness (for benchmarking), evaluates the QAP polynomials, and writes a `FullProvingKey` (group elements only — no scalars survive). It is fast (milliseconds) and insecure — which is exactly what Installment 1 needed for reproducible printouts, and what CI needs for cheap roundtrips.

Two flags matter when we move to production-sized circuits:

- `--sparse` — use the sparse constraint representation (Implementation 6). Avoids dense matrix allocation for large circuits (e.g. Blake2b-224, Ed25519).
- `--h-scalar` — use h-query scalar compression (Implementation 7). Stores a single scalar `delta_inv * T(tau)` instead of the full `h_query` G1 vector, cutting proving-key size and eliminating the h MSM.

```bash
trusted-setup ceremony-dev \
  --circuit circuit.r1cs \
  --proving-key circuit.pk \
  --verifying-key circuit.vk \
  --sparse \
  --h-scalar
```

### `phase2` — the production MPC ceremony

The production ceremony is a **multi-party Phase-2 ceremony** that reuses a publicly verified Phase-1 SRS (e.g. the **Perpetual Powers of Tau**). Each participant contributes randomness locally; the coordinator is just a passive file host. The workflow is split into four subcommands:

| Subcommand | Purpose |
|------------|---------|
| `new` | Create initial accumulator from `.ptau` SRS + `.r1cs` |
| `contribute` | Add your randomness contribution |
| `verify` | Check all contributions are valid |
| `finalize` | Convert accumulator to `.pk` / `.vk` |

The full workflow:

```bash
# 1. Initialize from universal SRS
trusted-setup phase2 new \
  --circuit circuit.r1cs \
  --srs universal.ptau \
  --zkey circuit_0000.zkey

# 2. Participants contribute sequentially (each independently, in turn)
trusted-setup phase2 contribute \
  --zkey-in circuit_0000.zkey \
  --zkey-out circuit_0001.zkey \
  --name "Alice"

trusted-setup phase2 contribute \
  --zkey-in circuit_0001.zkey \
  --zkey-out circuit_final.zkey \
  --name "Bob"

# 3. Verify the accumulator
trusted-setup phase2 verify --zkey circuit_final.zkey

# 4. Finalize to .pk / .vk
trusted-setup phase2 finalize \
  --zkey circuit_final.zkey \
  --proving-key circuit.pk \
  --verifying-key circuit.vk
```

**Why this is secure.** The power table `τⁱ·G1`, `τⁱ·G2` is a Phase-1 (universal) artifact produced by a public ceremony such as PPoT, where `τ` cannot be reconstructed as long as one contributor was honest. Phase 2 then *locks* that universal SRS to a specific circuit's QAP. The scalars never exist in one place at one time: each `contribute` step re-randomizes the accumulator under the previous participant's randomness, and `verify` checks that each contribution was valid without learning any secret. If the finalize production uses random scalars and every raw scalar is destroyed, the 1-of-N guarantee from [The ceremony intuition](#the-ceremony-intuition-1-of-n-trust) holds.

The `.pk` / `.vk` files produced by `ceremony-dev` or `phase2 finalize` are consumed by the `groth16` CLI (`prove` / `verify` / `export-vk`) and by the on-chain Aiken verifiers; both key formats are auto-detected on load (`FullProvingKey` uses the fast MSM prover path; the deprecated legacy `ProvingKey`, from the old `ceremony` command, falls back to the scalar-based prover path).

> **The legacy `ceremony` command is deprecated.** It produces a `ProvingKey` that contains scalar toxic waste — unsuitable for production. Use `ceremony-dev` for dev/testing and `phase2` for production.

---

## What's next in this installment

This document is the ceremony foundation for Installment 2. The rest of the article — to be expanded — replaces each bottleneck of the dense-monomial prover with a production technique, all cross-checked against the pipeline of [Installment 1](zkp-from-first-principles.md):

| Bottleneck | First-principles fix (Installment 1) | Production fix (this installment) |
|------------|--------------------------------------|-----------------------------------|
| Polynomial ops are O(n²) | Dense coefficient vectors | FFT over roots of unity |
| Proof assembly is O(n) scalar muls | One-by-one multiplication | Pippenger multi-scalar multiplication |
| Matrices explode memory | Dense `Vec<Vec<Fr>>` | Native sparse constraint representation |
| Trusted setup is single-party | Deterministic dev scalars | Multi-party MPC ceremony on PPoT — **covered above** |
| QAP materialises all polynomials | `build_qap()` returns every `u_i(x)` | On-the-fly witness-polynomial accumulation |

Beyond Groth16, we will survey the landscape: **PLONK** (universal trusted setup, custom gates), **Bulletproofs / Bulletproofs++** (no trusted setup at all), **STARKs / JOLT** (transparent, post-quantum), and **VM approaches (RISC Zero, zkVMs)** that prove arbitrary program execution without hand-writing circuits — folding the former zkVM installment into this one. From here, Installment 3 proves Cardano key ownership, Installment 4 applies the full stack to selective disclosure, and Installment 5 surveys quantum-resistant (lattice-based) systems that will one day replace the pairing-based assumption this whole series is built on.