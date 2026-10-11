---
title: Gadget library
description: The circuit building blocks in zeroj-circuit-lib (hashes, Merkle proofs, ranges, Jubjub, and Cardano key derivation), with status and cost.
sidebar:
  order: 3
---

A *gadget* is a reusable piece of circuit: a hash, a Merkle path check, a comparison. ZeroJ's
gadgets live in `zeroj-circuit-lib`. Reusing them saves you from re-deriving constraint systems
that already have tests, but each one has a field it works in, a cost, and a maturity status.
This page catalogs them and ends with rules for choosing gadgets for Cardano.

```groovy
implementation 'org.zeroj:zeroj-circuit-lib'   // version from zeroj-bom-core
```

## Three API flavors

Most gadgets come in up to three shapes, one per [authoring style](/guides/circuits/circuit-dsl/#which-layer-should-you-use):

| Flavor | Package | Example | Used from |
|--------|---------|---------|-----------|
| `Zk*` adapters | `org.zeroj.circuit.lib.zk` | `ZkPoseidon.hash(zk, params, a, b)` | Annotated circuits |
| `Signal*` helpers | `org.zeroj.circuit.lib` | `SignalPoseidon.hash(c, params, a, b)` | `CircuitSpec` / `defineSignals` |
| `CircuitAPI` gadgets | `org.zeroj.circuit.lib` | `Poseidon.hash(api, params, a, b)` | Inline `define(api -> ...)` |

The `Zk*` adapters delegate to the same underlying gadgets and reject values that belong to a
different circuit.

## Hashing: Poseidon

Poseidon is the hash to use inside Cardano circuits. It's designed for arithmetic circuits: a
two-input hash compiles to roughly 240 R1CS constraints on BLS12-381 with the current compiler,
while bit-oriented hashes such as SHA-512 cost around a hundred thousand per block.

**Always pass BLS12-381 parameters explicitly.** The no-parameter overloads use BN254 constants
for backward compatibility. If you mix them with a BLS12-381 compile, `CircuitBuilder` refuses to
compile, but the explicit form keeps the intent obvious.

```java
// Two inputs (in-circuit)
ZkField h = ZkPoseidon.hash(zk, PoseidonParamsBLS12_381T3.INSTANCE, left, right);

// N inputs, folded pairwise (in-circuit)
ZkField c = ZkPoseidonN.hash(zk, PoseidonParamsBLS12_381T3.INSTANCE, owner, assetId, nonce);

// The same values off-circuit, for commitments and expected public inputs
BigInteger h2 = PoseidonHash.hash(PoseidonParamsBLS12_381T3.INSTANCE, a, b);
BigInteger c2 = PoseidonHash.hashN(PoseidonParamsBLS12_381T3.INSTANCE, owner, asset, nonce);
```

`PoseidonN` / `ZkPoseidonN` is a left fold of the two-input hash, not a wider Poseidon
permutation, so its outputs differ from a native `t = N + 1` Poseidon. `ZkPoseidonN` has no
no-parameter overload at all. `PoseidonHash` is host-side code: it computes values, it doesn't
constrain anything.

**MiMC is BN254-only.** `MiMC`, `SignalMiMC`, `ZkMiMC` and `MiMCSponge` require the BN254 field
and refuse to compile for BLS12-381. Treat them as legacy, off-chain gadgets.

## Merkle membership

`ZkMerkle` proves that a leaf sits under a public root. For Cardano, use the
params-aware Poseidon helpers:

```java
@ZKCircuit(name = "allowlist", nameTemplate = "allowlist-d{depth}")
public class Allowlist {
    public Allowlist(@CircuitParam("depth") int depth) {
    }

    @Prove
    ZkBool prove(ZkContext zk,
                 @Secret ZkField leaf,
                 @Public ZkField root,
                 @Secret @FixedSize(param = "depth") ZkArray<ZkField> siblings,
                 @Secret @FixedSize(param = "depth") ZkArray<ZkBool> pathBits) {
        return ZkMerkle.isMemberPoseidon(zk, PoseidonParamsBLS12_381T3.INSTANCE,
                leaf, root, siblings, pathBits);
    }
}
```

`isMemberPoseidon` returns a `ZkBool`, `verifyPoseidon` asserts directly, and
`computeRootPoseidon` returns the root for further use. Path bits are constrained boolean:
bit `0` means the current node is the left child (`hash(current, sibling)`), and `1` means it's
the right child (`hash(sibling, current)`). Build the matching root off-circuit with the same
convention:

```java
BigInteger current = leaf;
for (int i = 0; i < siblings.size(); i++) {
    current = pathBits.get(i).signum() == 0
            ? PoseidonHash.hash(PoseidonParamsBLS12_381T3.INSTANCE, current, siblings.get(i))
            : PoseidonHash.hash(PoseidonParamsBLS12_381T3.INSTANCE, siblings.get(i), current);
}
```

`ZkMerkle.HashType.MIMC` and the enum `HashType.POSEIDON` path are BN254-oriented conveniences.
Avoid them for Cardano. For large, updatable state (millions of entries, inclusion and
non-inclusion, updates), see the experimental Poseidon MPF/JMT modules in
[Authenticated state](/guides/credentials/authenticated-state/).

## Comparisons and ranges

For annotated circuits, `ZkUInt` is the comparator: `@UInt(bits = N)` adds the range check, and
`lt`, `lte`, `gt`, `gte`, and `inRange(lo, hi)` compare. At the Signal level, use
`SignalComparators` (`lessThan`, `lessOrEqual`, `greaterThan`, `greaterOrEqual`, `inRange`,
`min`, `max`), or `Comparators` for raw `Variable`s.

```java
Signal ok = SignalComparators.greaterOrEqual(c, balance, threshold, 64);
c.assertEqual(ok, c.constant(1));
```

A comparison over `n` bits range-checks **both** operands to `n` bits, and rejects a constant
operand that doesn't fit when the circuit is defined. Widths must stay below 253 bits. Size `n`
to the real domain of your values; an oversized width costs constraints, and an undersized one
makes honest witnesses fail.

## Bits, selection and aliasing

| Need | Use |
|------|-----|
| Decompose or recompose bits | `SignalBinary.num2Bits` / `bits2Num`, `Binary.*`; `ZkBits` for fixed bit-vector inputs |
| Bitwise logic | `SignalBinary.bitAnd/bitOr/bitXor`, `rotateLeft` (a free re-indexing) |
| Choose between values | `ZkBool.select(a, b)`; `Mux.mux1`, `Mux.mux2` |
| Dynamic array lookup | `Mux.arrayAccess(api, array, index)` or `SignalBuilder.arrayAccess` (cost grows with length) |
| Canonical field representation | `AliasCheck.check(c, value, nBits)`, a decomposition that proves `value < 2^nBits` |

## Jubjub, Pedersen and EdDSA

Jubjub is an elliptic curve defined over the BLS12-381 scalar field, so its arithmetic is cheap
inside BLS12-381 circuits. These gadgets require `CurveId.BLS12_381`. Their in-circuit
verification side is marked ready pending external review; the off-circuit secret operations
have tighter restrictions (see the status table).

**Bind every prover-supplied point.** `ZkJubjubPoint.witnessAffine(zk, u, v)` asserts the curve
equation and fixes the extended coordinates (5 constraints). Without it, a prover can inject an
off-curve point such as `(1, 1)`. Neither `witnessAffine` nor `assertWellFormed()` proves
prime-order subgroup membership; that is a separate, much more expensive check.

**Pedersen commitments.** `ZkPedersen.commit(zk, value, blinding)` commits two `ZkUInt`
scalars and returns a `ZkJubjubPoint`, and `verifyOpening(...)` checks an opening. Both scalars
are constrained to canonical values below the subgroup order. The value keeps its declared
width, which is also its range proof. The blinding must be declared at exactly 252 bits and
must not be a public input or a constant, because a narrower blinding can be brute-forced from
the public commitment. Sample it with `PedersenCommitment.randomBlinding(SecureRandom)`. A
complete commitment with both coordinates bound as public inputs costs 2,410 constraints for a
64-bit value and 4,042 for a 252-bit value. A value narrower than 252 bits is canonical by its own
range, so only full-width values pay for the comparator. The profile is specified in
`docs/specs/pedersen-jubjub-v1.md`.

**Commitments the circuit did not compute.** `ZkPedersenCommitment` is a typed commitment
that records where a point came from. Use `ZkPedersenCommitment.commit(...)` for commitments
you open in the circuit. To bind one someone else published, commit to its opening and call
`assertAffineEquals` with the published `(u, v)`. An *unopened* commitment comes in through one
of two named constructors:

- `witnessInSubgroup(zk, u, v)` proves prime-order subgroup membership in-circuit (about 5,550
  constraints).
- `fromVerifierCheckedPublic(zk, u, v)` requires public or constant coordinates, and leaves the
  subgroup check to the verifier. The verifier runs `PedersenCommitment.decode(bytes)` before
  accepting the proof. An on-chain verifier cannot do that for Jubjub, so on-chain consumers use
  the first constructor.

**Homomorphic sums only hold mod `l`.** With valid openings,
`C(l − 1, 17) + C(1, 23) = C(0, 40)`: two commitments that "add up" to a commitment to zero.
Never read a commitment sum as conservation of money on its own. Use
`ZkPedersen.assertBalanced`, which checks at circuit-definition time that neither side can
reach `l`, then asserts the integer relation on the committed values:

```java
var in1 = ZkPedersenCommitment.commit(zk, amount1, blinding1);   // 64-bit amounts,
var in2 = ZkPedersenCommitment.commit(zk, amount2, blinding2);   // 252-bit blindings
var out = ZkPedersenCommitment.commit(zk, amountOut, blindingOut);
in1.assertAffineEquals(zk, in1U, in1V);                          // the existing commitments
in2.assertAffineEquals(zk, in2U, in2V);                          // being spent (public)
out.assertAffineEquals(zk, outU, outV);                          // the new one (public)
ZkPedersen.assertBalanced(zk,
        List.of(ZkPedersen.Term.of(in1), ZkPedersen.Term.of(in2)),
        List.of(ZkPedersen.Term.of(out), ZkPedersen.Term.amount(fee))); // fee: public 32-bit
```

Bind every commitment in the relation to the public statement, as above. An input commitment
that is not bound to anything public lets the prover choose its amount freely, and the balance
then proves nothing about the coins being spent. The bound is computed from declared widths,
`Σ coefficient·(2^width − 1)` on each side, and must stay below `l` (about `2^251.9`). Committing
252-bit amounts and balancing them is refused.

**Committing to several values at once.** `pedersen-jubjub-vector-v1` commits to up to 16
values in one point, using bases derived with Zcash's Sapling group hash. A vector commitment
does **not** record what its indices mean or how many there are: `C([a], r)` equals
`C([a, 0], r)`. So the meaning lives in a `PedersenVectorSchema` (an id, a version, and a label
and bit width per index), and every proof binds the schema's digest as a public input:

```java
var schema = PedersenVectorSchema.of("acme.balance", 1,
        List.of(new Entry("amount", 64), new Entry("asset", 32)));
var binding = ZkPedersenVector.bindSchema(zk, schema, schemaDigest);   // public input
var c = ZkPedersenVector.commit(zk, binding, List.of(amount, asset), blinding);
c.assertAffineEquals(zk, u, v);
```

The verifier checks the public `schemaDigest` against the digest it expects for that
verification key, using `PedersenSchemaRegistry`, never a value supplied with the proof. A
commitment you receive from someone else is only meaningful together with an authenticated
issuance record that binds its exact bytes to its schema digest. Anyone who knows an opening can
produce a valid proof for the same point under another schema of the same shape, so a valid
proof alone proves nothing about the original schema. Without such a record, reject the
commitment. A 16-value commitment costs 8,261 constraints; see
`docs/benchmarks/pedersen-vector-2026-10-03.md` for proving times.

**EdDSA-Jubjub verification** comes in two named entry points, because whether the public key
needs an in-circuit subgroup check depends on your protocol:

| Entry point | Use when | Approx. constraints |
|-------------|----------|--------------------|
| `ZkEdDSAJubjub.verifyStrict(...)` | The public key is secret or chosen by the prover | ~14,500 |
| `ZkEdDSAJubjub.verifyWithRegisteredKey(...)` | The public key is a public input or constant (the DSL enforces this) | ~8,962 |

Both reject small-order keys, including the identity. With `verifyWithRegisteredKey`, binding
the public key to a subgroup-checked registry entry is your verifier's job. Both also need two
reduction witnesses, computed off-circuit with
`ZkEdDSAJubjub.witnessComputeKReduction(signature.r(), publicKey, message)`:

```java
@Prove
void prove(ZkContext zk,
           @Public ZkField pkU, @Public ZkField pkV, @Public ZkField msg,
           @Public ZkField rU, @Public ZkField rV,
           @Public @UInt(bits = 252) ZkUInt s,
           @Secret @UInt(bits = 252) ZkUInt kModL,
           @Secret @UInt(bits = 4) ZkUInt kQuotient) {
    ZkEdDSAJubjub.verifyWithRegisteredKey(zk, pkU, pkV, msg, rU, rV, s, kModL, kQuotient);
}
```

:::danger[Off-circuit signing and commitment generation]
`EdDSAJubjub.sign` and `PedersenCommitment.commit` run secret-dependent, variable-time Java
`BigInteger` arithmetic. They are approved only for local, offline, or isolated use, not for
value-bearing issuance on shared or network-reachable machines. The in-circuit gadgets are not
affected. The normative scheme is
[jubjub-eddsa-v1](https://github.com/bloxbean/zeroj/blob/main/docs/specs/jubjub-eddsa-v1.md).
:::

## Encryption: ElGamal and threshold keys

`elgamal-jubjub-v1` is exponential ("lifted") ElGamal on Jubjub. A message `m` becomes
`A = [k]·G`, `B = [m]·G + [k]·PK`. Ciphertexts under one key add up to an encryption of the sum,
so you can total encrypted votes, bids or survey answers and decrypt only the total. The profile
is specified in `docs/specs/elgamal-jubjub-v1.md` (ADR-0052). It is **experimental**.

**Proving a ciphertext is well formed.** The circuit side proves that a public ciphertext
encrypts an in-range message under a key:

```java
@Prove
void prove(ZkContext zk,
           @Public ZkField keyU, @Public ZkField keyV,
           @Public ZkField aU, @Public ZkField aV, @Public ZkField bU, @Public ZkField bV,
           @Secret @UInt(bits = 1) ZkUInt vote,
           @Secret @UInt(bits = 252) ZkUInt randomness) {
    var key = ZkElGamalPublicKey.fromVerifierFixedPublic(zk, keyU, keyV);
    ZkElGamal.encrypt(zk, vote, randomness, key).assertAffineEquals(zk, aU, aV, bU, bV);
}
```

- The message width is 1 to 64 bits. A wider declaration is refused, because at 252 bits the
  witness `m = l` would alias `m = 0`.
- The randomness must be exactly 252 bits and never public. One decomposition drives both
  scalar multiplications.
- A key enters either as public coordinates the verifier fixes
  (`fromVerifierFixedPublic`; the verifier checks subgroup membership), or as a witness proved
  in the subgroup (`witnessInSubgroup`). Both refuse the identity key.

Cost: 6,558 constraints at width 1, and 6,938 at width 64.

**Trustee proofs.** `ZkElGamal.assertDiscreteLogEquality(zk, x, X…, P…, D…)` proves
`P = [x]·G` and `D = [x]·X` (6,546 constraints). All six coordinates must be public inputs, so
the prover never chooses the base. One circuit serves both trustee proofs:
- a proof of possession of a key share, with `X = G` and `D = P`;
- a correct decryption share, with `X` the ciphertext handle.

**The host side keeps sums honest.** On the host, use the safe layer in
`org.zeroj.circuit.lib.jubjub`:
- an `ElGamalCiphertext` carries its key context and an established plaintext bound;
- `add` and `scale` refuse to mix keys or to let the bound reach `l`;
- `decrypt` needs a verified share from every trustee (`VerifiedDecryptionShare`).

A ciphertext from someone else enters only through `ElGamal.admit`, with a verifier that checks
its encryption proof against the statement the library builds:

```java
ElGamalCiphertext ballot = ElGamal.admit(RawElGamalCiphertext.decode(bytes), election, 1,
        statement -> verifyGroth16(proof, statement.publicInputs()));
ElGamalCiphertext total = ElGamalCiphertext.sum(admittedBallots);
long yes = ElGamal.decrypt(total, verifiedShares, total.bound().longValueExact());
```

Decryption recovers `m` with a bounded baby-step giant-step search, so keep the decrypted total
small (default reach about `2^43`). It fails closed instead of returning a wrong value.

**Threshold keys.** With `elgamal-jubjub-threshold-v1` (ADR-0053), any `t + 1` of `n` trustees
can decrypt, and up to `t` can be lost or malicious. The trustees run a distributed key
generation, New-DKG of Gennaro et al., with `DkgParticipant`. No single party ever holds the
key, provided the transport delivers the private shares on time. A late share can make an honest
dealer publish it, so timely delivery is a secrecy requirement, not only a liveness one.
- Your application supplies the transport: a broadcast board with agreement and round
  deadlines. For the private shares it can supply its own channels, or use ZeroJ's encrypted
  delivery over the same board (below).
- A third party accepts the result with `ThresholdKeyContext.admit`, which requires
  authenticated messages, closed rounds, and confirmations from at least `t + 1` trustees.
- Ballots and sums are unchanged. Decryption takes any `t + 1` verified shares.

**Encrypted share delivery over the board.** `dkg-share-delivery-hpke-v1` (ADR-0054,
experimental) removes the private channels. It encrypts each share with HPKE (RFC 9180 Base
mode; X25519, HKDF-SHA256, ChaCha20-Poly1305) to the recipient's key for this attempt, and the
dealer posts the envelope on the board. Delivery becomes visible, and trustees need not be
online together. The key generation, its transcript and admission are unchanged.

```java
// Round 0: a fresh key per attempt, announced under the roster key.
DkgShareDeliveryKeys keys = DkgShareDeliveryKeys.generate(config, myId, random);
post(keys.announcement());
DkgKeyDirectory directory = DkgKeyDirectory.fromRound0(config, finalRound0Window, verifier);

// Round 1: start (instead of participant.start()); post the envelopes, and the COMMITMENTS only
// once the envelopes are final.
DkgShareDelivery.SealedDealing dealing = DkgShareDelivery.start(participant, directory, keys, random);
postAndAwaitFinality(dealing.envelopes());
post(dealing.broadcasts());

// Close round 1 behind the barrier, with the complete final window. This also destroys the keys.
List<DkgMessage> complaints = DkgShareDelivery.closeRound1(participant, directory, keys, finalRound1Window, verifier);
// Rounds 2–7 continue with participant.receiveBroadcast / closeRound as before.
```

These rules are what keep the shares secret. They are not optional:
- **Barrier.** Close round 1 only through `closeRound1`, with the window *after* its cutoff and
  finality. The library can't check that: a snapshot taken before finality can miss envelopes,
  and processing late is exactly the failure the barrier prevents. Round 1's window opens when
  round 0's closes, so a threshold message posted during round 0 is early and doesn't count. A participant started with `DkgShareDelivery.start` refuses the plain `closeRound()`
  at round 1, so it cannot complain about a share it never processed. If `closeRound1` throws
  anything other than an abort (your verifier, or a crypto-provider fault), the participant
  stays at round 1 with its keys; retry with the same window, or call `keys.destroy()` if you
  give up the attempt. The retry must pass exactly the same posts in the same order: any other
  window is refused with `IllegalArgumentException`. This check proves only that the retry
  repeats the first call. It does not prove the window is final or complete. Your verifier must return `false`, not throw, for posts it does not
  accept. If `start` throws after the participant started, post nothing for it in round 1.
- **Commitments last.** Post `COMMITMENTS` only after every envelope is final within the round-1
  window, or post them all atomically. If the envelopes cannot make the cutoff, post nothing:
  the dealer is then disqualified and its contribution is excluded from the key. Honest
  trustees don't complain about it; a corrupted trustee still can, and receives only its own
  share in the public answer.
- **T1.** If your own announcement is missing from the final round-0 window, or the directory holds
  a different key for you, `start` throws `OWN_KEY_ANNOUNCEMENT_MISSING` and aborts the participant.
  Post nothing more for this attempt.
- **Keys.** Generate fresh keys per attempt; they are separate from the roster key. Ciphertexts on
  a public board are kept forever, and a leaked key opens what was sent to it. A few leaked keys,
  together with corrupted trustees, can expose the joint key.

The construction rests on a stated assumption: that encryption can replace the private channels
of the GJKR07 proof. That assumption, and the delivery argument, await external review. See the
spec `docs/specs/dkg-share-delivery-hpke-v1.md`.

**Confidential notes: delivering openings on-chain.** A note's amount lives in a
`pedersen-jubjub-v1` commitment, and its holder needs the opening `(v, r)` to spend it.
`confidential-note-jubjub-v1` (ADR-0055, experimental) delivers that opening on-chain, in the note
itself, to each of its readers: the owner, and any auditors the application requires. It uses
Zcash Sapling's key agreement on Jubjub, its BLAKE2b-256 KDF (with ZeroJ's personalization) and
ChaCha20-Poly1305, with a fresh ephemeral key per reader. Recipients and auditors recover every
note from chain data alone.

```java
// Sender: one delivery per reader, in the application's order (owner first, then auditors).
NoteOpening opening = NoteOpening.random(amount, random);
JubjubPoint c = opening.commitment();                      // goes in the note's datum
List<byte[]> deliveries = ConfidentialNotes.seal(opening, List.of(ownerKey, auditorKey), random);

// Reader: open only your own position; check the owner credential yourself.
NoteScanner scanner = NoteScanner.of(viewingKey);          // runs an AEAD self-test once
Optional<NoteOpening> mine = scanner.open(deliveries.get(0), datumU, datumV);
```

These rules are not optional:
- **Accept only what opens.** `open` returns an opening only after it recomputes `[v]·G + [r]·H`
  and compares it with the note's commitment. Everything else, from a wrong key to a tampered byte,
  is the same "not mine" result. A crypto-provider fault throws instead: retry later, never treat
  it as "not mine".
- **Check the owner yourself.** The profile does not know your owner credential. Count a note as
  yours only if its owner field is yours and it sits at your application's address with its token;
  otherwise a copied commitment and delivery in someone else's output would look like yours.
- **Report unopenable owned notes.** `scan` lists owned notes that do not open. That is value you
  own but cannot spend, and evidence of a misbehaving sender; show it to the user.
- **Keys.** Generate viewing keys with `NoteViewingKey.generate`; never reuse an ElGamal, EdDSA,
  spending or Zcash key. Register auditor keys with their possession proof, once. Ciphertexts on
  chain are kept forever: a leaked viewing key opens every note ever delivered to it.
- **Scan in your own process.** Decryption multiplies attacker-chosen points by your viewing key
  with variable-time arithmetic. Never run it as a shared or network-facing service.

Without a proof, a validator can check only that each required reader has a delivery of the right
length, not that it decrypts. ADR-0055's D3a closes that for the **amount** an auditor needs: the
transfer's Groth16 proof also encrypts each created note's amount to the auditor's
`elgamal-jubjub-v1` key in two 32-bit limbs. It measured within the per-transaction budget in a test-only
reference validator (73.4% of the step limit for a two-output transfer with one auditor, 55.2% for
a redeem, 47.3% with the hash-compressed layout); your application measures its own complete
transaction. It covers notes created by proof-enforced transitions only; issued notes rest on the
issuer.

:::caution[Offline trustee and encryption operations]
Key generation, encryption, decryption shares and the DKG handle secrets with variable-time
Java `BigInteger` arithmetic, through the blinded best-effort schedule used for Pedersen.
Run them offline or in an isolated process. The in-circuit relations are not affected. "Decrypt
once, after a deadline" is your application's rule: decrypting running totals lets anyone
recover individual messages by differencing.
:::

## Real-world crypto: Cardano key derivation

These gadgets reproduce standard wallet primitives *inside* a circuit, so a proof can show "I know
the root key behind this Cardano address" without revealing it. They're bit-oriented and
independent of the circuit field, so they run on BLS12-381 Groth16, but they are **large**.

| Gadget | Adapter | What it's for | Measured size |
|--------|---------|---------------|---------------|
| BLAKE2b (RFC 7693) | `ZkBlake2b.hash224` / `hash256` / `hash` | Cardano key hashes (blake2b-224) | 76,832 constraints per block |
| SHA-512 (FIPS 180-4) | `ZkSha512.hash` | Building block for HMAC and BIP32 | ~109,000 constraints per block |
| HMAC-SHA512 (RFC 2104) | `ZkHmacSha512.hmac` | BIP32-Ed25519 child derivation | ~454,000 constraints at the BIP32 input shape |
| GF(2²⁵⁵−19) field, Ed25519 points | `Fe25519`, `Ed25519Point` (no `Zk*` adapter) | Non-native Ed25519 arithmetic, fixed-base scalar multiplication | Building blocks |
| BIP32-Ed25519 | `Bip32Ed25519` (no `Zk*` adapter) | Hardened and soft child-key derivation, Icarus style | Building block |
| CIP-1852 derivation | `ZkCip1852.paymentKeyHash`, `leafKeyHash` | Root key → `m/1852'/1815'/account'/role/index` → 28-byte payment key hash | On the order of 19 million constraints for the full path |

Sizes are ZeroJ's own measurements from the gadget design work
([ADR-0027](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0027-real-world-crypto-gadgets-sha512-hmac-blake2b-ed25519.md),
[ADR-0028](https://github.com/bloxbean/zeroj/blob/main/docs/adr/0028-dsl-optimization-and-hint-soundness.md))
and may change as the gadgets are optimized. `ZkCip1852.paymentKeyHash` has overloads that take
the account, role, and index as Java constants or as `ZkBytes` circuit inputs; with all three as
inputs, one circuit and one setup cover every address of a root key. A proof of this size needs
the large-circuit proving path in [Performance & large circuits](/guides/proving/performance/).
See [Account recovery](/use-cases/account-recovery/) for the application built on it.

## Status at a glance

"Ready" below means what the library documents: the gadget can be used in a circuit compiled for
BLS12-381, proved with Groth16, and checked by ZeroJ's reusable Plutus V3 verifier. It is not a
claim of audit, and a reusable verifier checks only the math, not your application's
authorization or replay rules.

| Gadget | Field | Cardano status (from the library's table) |
|--------|-------|-------------------------------------------|
| Field arithmetic, `ZkBool`, `ZkUInt`, arrays and matrices | Any | Ready on BLS12-381 Groth16 |
| `ZkBits`, `ZkBytes` | Any | Ready for binding and equality |
| Binary decomposition, comparators, selection | Any | Ready on BLS12-381 Groth16 |
| Poseidon T3, folded Poseidon N | BN254 default; BLS12-381 with explicit params | Ready with `PoseidonParamsBLS12_381T3.INSTANCE` |
| Merkle membership | Hash-dependent | Ready with the params-aware Poseidon helpers |
| MiMC, MiMC sponge | BN254 only | Not Cardano-ready |
| Jubjub point arithmetic | BLS12-381 only | Ready for algebraic and public-data use, pending external review |
| Pedersen commitment (in-circuit) | BLS12-381 only | Ready, pending external review |
| Pedersen commitment (off-circuit generation) | Jubjub | Offline or isolated use only |
| EdDSA-Jubjub | BLS12-381 only | Verification ready pending external review; legacy signing offline only |
| ElGamal encryption and trustee proofs (in-circuit) | BLS12-381 only | Experimental |
| ElGamal host API, threshold key generation | Jubjub | Experimental; secret operations offline or isolated only |
| Encrypted DKG share delivery (`dkg-share-delivery-hpke-v1`) | X25519 HPKE | Experimental; Assumption A1 and the delivery contract await external review |
| Confidential notes (`confidential-note-jubjub-v1`) | Jubjub | Experimental; secret operations offline or isolated only; assumptions A1–A3 await external review |
| BLAKE2b, CIP-1852 derivation | Field-agnostic | Ready on BLS12-381 Groth16 |
| SHA-512, HMAC-SHA512, BIP32-Ed25519 | Field-agnostic | Ready as building blocks |
| Poseidon MPF/JMT authenticated state | BLS12-381 Poseidon profile | Experimental (separate modules) |

The authoritative, detailed table is in the
[`zeroj-circuit-lib` README](https://github.com/bloxbean/zeroj/blob/main/zeroj-circuit-lib/README.md#gadget-status).

## Choosing a gadget for Cardano

1. **Compile for `CurveId.BLS12_381` and prove with Groth16.** That is the verified on-chain path.
2. **Hash with Poseidon and explicit `PoseidonParamsBLS12_381T3.INSTANCE`.** Never MiMC, never the
   no-parameter overloads.
3. **Use `ZkMerkle.*Poseidon(...)` for membership.** The `HashType` enum paths are BN254-oriented.
4. **Use `ZkUInt` for every quantity,** with the tightest honest width.
5. **Bind every witness-supplied curve point** with `witnessAffine`, and pick the EdDSA entry
   point that matches who controls the key.
6. **Reach for SHA-512, HMAC, BLAKE2b, or Ed25519 only when a protocol demands them.** They cost
   orders of magnitude more than Poseidon.
7. **Match off-circuit and in-circuit hashing exactly.** Same parameters, same argument order,
   same path-bit convention, or honest proofs will fail.

## Next steps

- [Test your circuits for soundness](/guides/circuits/testing-circuits/)
- [Private allowlist with a Merkle tree](/tutorials/private-allowlist/)
- [Prove with Groth16](/guides/proving/groth16/)
