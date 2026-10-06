---
title: Glossary
description: Short, plain-English definitions of the zero-knowledge, cryptography and Cardano terms used throughout the ZeroJ docs.
sidebar:
  order: 6
---

Quick definitions of the terms you'll meet in these docs, in alphabetical order. Each entry links
to the page that explains the idea properly.

## A–B

**Arithmetic circuit.** A computation expressed as additions and multiplications over a finite
field, written as a list of constraints. It's what "circuit" means in ZK; there are no wires or
gates in the electronic sense. See [Circuits, constraints & witnesses](/learn/circuits-and-witnesses/).

**BBS.** A signature scheme where an issuer signs a list of attributes and the holder later proves
possession of the signature while revealing only chosen attributes. ZeroJ implements IRTF CFRG
draft-10. See [Groth16, PlonK & BBS](/learn/proof-systems/) and [BBS credentials](/guides/credentials/bbs/).

**Blinding.** Randomness mixed into a proof or commitment so it reveals nothing about the secret.
ZeroJ's Groth16 prover always blinds proofs, so two proofs of the same statement look unrelated.
In commitments, a random salt stops low-entropy values like an age from being guessed.
See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

**BLS12-381.** The pairing-friendly elliptic curve ZeroJ uses by default, and the only one Cardano
can verify on-chain, through Plutus V3 builtins. See [Groth16, PlonK & BBS](/learn/proof-systems/).

**BN254.** Another pairing-friendly curve, popular on Ethereum. It isn't a Cardano curve. ZeroJ's
BN254 code is legacy and disabled by default (`-Dzeroj.allowLegacyBn254=true`).
See [Groth16, PlonK & BBS](/learn/proof-systems/).

## C

**CIP-0381.** The Cardano Improvement Proposal that added BLS12-381 curve operations and pairings
to Plutus. It's what makes on-chain proof verification affordable.
See [ZK on Cardano](/learn/zk-on-cardano/).

**Circuit.** The rules a proof is about: a fixed set of constraints over public and secret inputs.
In ZeroJ you write circuits in Java, usually as a class annotated with `@ZKCircuit`.
See [Circuits, constraints & witnesses](/learn/circuits-and-witnesses/).

**Commitment.** A value that binds you to a secret without revealing it, like a sealed envelope.
In circuits it's often a hash such as Poseidon(value, salt). You can later prove statements about
the committed value. See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

**Completeness.** The guarantee that an honest prover with a true statement always convinces the
verifier. See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

**Constraint.** One equation in a circuit. In R1CS, each constraint has the form A × B = C, where
A, B, and C are sums of wires times constants.
See [Circuits, constraints & witnesses](/learn/circuits-and-witnesses/).

**CRS / SRS.** Common (or structured) reference string: public parameters produced by a trusted
setup and used by both prover and verifier. The powers of tau are an SRS.
See [Trusted setup, explained](/learn/trusted-setup/).

**Curve point (G1, G2).** An element of one of the elliptic-curve groups used by pairing-based
proofs. On BLS12-381, a compressed G1 point is 48 bytes and a G2 point is 96 bytes. A Groth16
proof is two G1 points and one G2 point. See [Groth16, PlonK & BBS](/learn/proof-systems/).

## D–F

**Datum.** Data attached to a UTxO locked at a script address. ZeroJ's reusable on-chain verifier
reads the public inputs from it. See [ZK on Cardano](/learn/zk-on-cardano/).

**eUTxO.** Cardano's extended unspent-transaction-output model: funds and state live in outputs
that validators guard, with a datum, a redeemer, and a ScriptContext.
See [ZK on Cardano](/learn/zk-on-cardano/).

**Field element.** A whole number modulo a large prime. For BLS12-381 the circuit field's prime,
`r`, is 255 bits. Field arithmetic wraps around and has no negatives or fractions.
See [Circuits, constraints & witnesses](/learn/circuits-and-witnesses/).

**Fiat–Shamir.** A technique that makes an interactive proof non-interactive by deriving the
verifier's challenges from a hash of the transcript. PlonK and BBS use it, so their transcript
encoding is security-critical. See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

## G–K

**Gadget.** A reusable piece of circuit, such as a Poseidon hash, a Merkle membership check, or a
comparator. ZeroJ's gadgets live in `zeroj-circuit-lib`. See [Gadgets](/guides/circuits/gadgets/).

**Groth16.** The zk-SNARK ZeroJ uses by default: 192-byte proofs on BLS12-381, the cheapest
verification, and a trusted setup per circuit. See [Groth16, PlonK & BBS](/learn/proof-systems/).

**JuLC.** A compiler that turns Java code into Plutus V3 validators for Cardano. ZeroJ's on-chain
verifiers are written with it. See [ZK on Cardano](/learn/zk-on-cardano/).

**KZG.** The Kate–Zaverucha–Goldberg polynomial commitment scheme. It lets a prover commit to a
polynomial and later prove its value at a point. PlonK uses it with a universal SRS.
See [Groth16, PlonK & BBS](/learn/proof-systems/).

## M–N

**Merkle tree.** A tree of hashes whose single root commits to an entire list. A Merkle proof shows
an item is in the list using one sibling hash per level. In a circuit, the item and its path can
stay secret while only the root is public. See [Private allowlist](/tutorials/private-allowlist/).

**MPC ceremony.** A multi-party trusted setup where each participant mixes in secret randomness
and destroys it. The resulting keys are safe as long as at least one participant was honest.
See [Trusted setup, explained](/learn/trusted-setup/).

**Nullifier.** A public value derived from a secret and a scope, for example
Poseidon(secret, electionId). It's the same every time the same secret is used in the same scope,
so a validator can reject repeats without learning the secret. See [ZK on Cardano](/learn/zk-on-cardano/).

## P

**Pairing.** A special function that maps a G1 point and a G2 point to a third group, such that
e(aP, bQ) = e(P, Q)ᵃᵇ. It lets a verifier check multiplication relationships between hidden
values. Groth16, PlonK, and BBS verification all rely on pairings.
See [Groth16, PlonK & BBS](/learn/proof-systems/).

**PlonK.** A zk-SNARK with a universal trusted setup, based on KZG commitments. In ZeroJ it's
**experimental**, off-chain and on-chain. See [Groth16, PlonK & BBS](/learn/proof-systems/).

**Poseidon.** A hash function designed to be cheap inside circuits, needing far fewer constraints
than SHA-256. For Cardano circuits, always pass explicit BLS12-381 parameters:
`PoseidonParamsBLS12_381T3.INSTANCE`. See [Gadgets](/guides/circuits/gadgets/).

**Powers of tau.** The universal phase-1 setup output: curve points built from powers of a secret
τ. It's stored in a `.ptau` file and reusable by every circuit up to its size.
See [Trusted setup, explained](/learn/trusted-setup/).

**Proof.** The short object a prover sends to convince a verifier. A Groth16 proof on BLS12-381 is
192 bytes. See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

**Proof envelope.** ZeroJ's container for a proof together with its proof system, curve, circuit
ID, public inputs, and a verification-key reference (`ZkProofEnvelope`).
See [Off-chain verification](/guides/verifying/off-chain/).

**Proving key.** The key a prover uses to create proofs for one circuit. It isn't secret, but it
must come from a trustworthy setup. For very large circuits it can be many gigabytes, so ZeroJ can
`mmap` it from disk. See [Trusted setup, explained](/learn/trusted-setup/).

**Public input.** A value both prover and verifier see, such as a threshold, a Merkle root, or a
hash. On-chain, public inputs are visible to everyone.
See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

## R

**R1CS.** Rank-1 constraint system: the circuit format Groth16 uses, where every constraint is
(linear combination) × (linear combination) = (linear combination).
See [Circuits, constraints & witnesses](/learn/circuits-and-witnesses/).

**Range check.** Constraints proving a value fits in N bits, usually by decomposing it into
boolean bits. Without range checks, field wrap-around lets cheaters pass comparisons. In ZeroJ,
`@UInt(bits = N)` adds them. See [Circuits, constraints & witnesses](/learn/circuits-and-witnesses/).

**Redeemer.** Data supplied by the transaction that spends a script UTxO. In ZK validators it
carries the proof. See [ZK on Cardano](/learn/zk-on-cardano/).

## S

**ScriptContext.** The validator's view of the whole transaction: inputs, outputs, signatures,
validity range, and more. Binding proofs to it is what prevents replay and theft.
See [ZK on Cardano](/learn/zk-on-cardano/).

**Secret input (private input).** A value only the prover knows. It's part of the witness and
never leaves the prover. ZeroJ marks these with `@Secret`.
See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

**Selective disclosure.** Revealing some attributes of a signed credential while proving the rest
are validly signed but hidden. BBS provides it natively.
See [Selective disclosure](/use-cases/selective-disclosure/).

**SNARK.** Succinct Non-interactive ARgument of Knowledge: a short proof, checked quickly, sent in
one message, showing the prover knows a valid witness. A zk-SNARK is also zero-knowledge.
See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

**snarkjs / circom.** A widely used JavaScript proving toolkit and its companion circuit language.
ZeroJ imports their `.ptau`, `.zkey`, and `.r1cs` artifacts and exports snarkjs-compatible JSON.
See [Bring circom & snarkjs circuits](/tutorials/snarkjs-interop/).

**Soundness.** The guarantee that a false statement can't be proven, except with negligible
probability. Under-constrained circuits and leaked toxic waste both break it.
See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

## T–U

**Toxic waste.** The secret randomness used in a trusted setup. Anyone who keeps it can forge
proofs. See [Trusted setup, explained](/learn/trusted-setup/).

**Trusted setup.** The one-time generation of proving and verification keys from secret
randomness. ZeroJ's in-process setup is development-only and needs
`-Dzeroj.allowInsecureTrustedSetup=true`; production keys come from an MPC ceremony.
See [Trusted setup, explained](/learn/trusted-setup/).

**Under-constrained circuit.** A circuit missing a constraint its author intended, so a cheater can
choose values that satisfy the remaining equations and produce a valid proof of a false statement.
This is the most common serious ZK bug. See [Circuits, constraints & witnesses](/learn/circuits-and-witnesses/).

**UTxO.** An unspent transaction output: value, and optionally a datum, sitting at an address
until a transaction spends it. On Cardano, funds and application state live in UTxOs.
See [ZK on Cardano](/learn/zk-on-cardano/).

## V–Z

**Validator.** A Plutus script that decides whether a transaction may spend a UTxO locked at its
address. ZeroJ ships reusable verifier validators and a library for writing your own.
See [ZK on Cardano](/learn/zk-on-cardano/).

**Verification key.** The small public key used to check proofs for one circuit. For Groth16 on
BLS12-381 with one public input it's 432 bytes compressed. On Cardano it's baked into the
validator as script parameters. See [Trusted setup, explained](/learn/trusted-setup/).

**Wire.** A variable in a circuit. The witness gives every wire a value; wire 0 is always the
constant 1. See [Circuits, constraints & witnesses](/learn/circuits-and-witnesses/).

**Witness.** Every wire value in a circuit for one proof: public inputs, secret inputs, and all
intermediate values. It contains your secrets and never leaves the prover.
See [Circuits, constraints & witnesses](/learn/circuits-and-witnesses/).

**Zero-knowledge.** The guarantee that a proof reveals nothing beyond the truth of the statement.
See [Zero-knowledge in plain English](/learn/zero-knowledge-basics/).

**`.zkey` / `.ptau`.** snarkjs file formats. A `.ptau` holds powers of tau (phase 1); a `.zkey`
holds one circuit's proving and verification keys after phase 2, including its ceremony history.
See [Trusted setup, explained](/learn/trusted-setup/).
