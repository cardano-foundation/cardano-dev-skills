use aiken/collection/list
use aiken/crypto
use aiken/crypto/bitwise.{State}
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/scalar.{Scalar}
use aiken/primitive/bytearray

/// Prepended to every generator derivation and transcript hash so this
/// protocol's challenges/generators can never collide with another
/// proof system's, even if both happened to hash the same raw bytes.
const protocol_id: ByteArray = "adao-zkp/bulletproofs-range-proof/v1"

/// Range proofs wider than this are refused: `n` drives O(n) recursion
/// (bit decomposition, vector commitments, scalar products) both here and
/// in `verify`, so an unbounded `n` is an unbounded compute-cost knob.
const max_n: Int = 64

/// Generators for n-bit range proofs. The type is opaque, so the only way to
/// get a key is `setup`: one can't be decoded from a redeemer, datum or other
/// `Data`, or built from chosen points. `verify` trusts every generator in the
/// key, and a prover who chose them (`h = k * g`, say) could open a commitment
/// to any value. Hashing the key into the transcript wouldn't stop that, since
/// such a prover knows the relations before any challenge is drawn.
pub opaque type BulletproofVerificationKey {
  g: G1Element,
  h: G1Element,
  u: G1Element,
  g_vec: List<G1Element>,
  h_vec: List<G1Element>,
  g_sum: G1Element,
  h_sum: G1Element,
  n: Int,
}

pub type BulletproofProof {
  a: G1Element,
  s: G1Element,
  t1: G1Element,
  t2: G1Element,
  tau_x: State<Scalar>,
  mu: State<Scalar>,
  l_vec: List<State<Scalar>>,
  r_vec: List<State<Scalar>>,
}

/// A `BulletproofProof` as plain data, so it can come from a redeemer or datum.
/// `BulletproofProof` itself can't: its scalars are `State<Scalar>`, which is
/// opaque, so Aiken won't decode one from `Data`. Here each point is a 48-byte
/// compressed G1 encoding and each scalar an `Int` in `[0, r)`, where `r` is the
/// order of the scalar field. `uncompress_proof` turns it into a proof for
/// `verify`.
pub type CompressedBulletproofProof {
  a: ByteArray,
  s: ByteArray,
  t1: ByteArray,
  t2: ByteArray,
  tau_x: Int,
  mu: Int,
  l_vec: List<Int>,
  r_vec: List<Int>,
}

pub type ProofBlinding {
  alpha: State<Scalar>,
  rho: State<Scalar>,
  tau1: State<Scalar>,
  tau2: State<Scalar>,
  s_l: List<State<Scalar>>,
  s_r: List<State<Scalar>>,
}

/// Derive a deterministic, nothing-up-my-sleeve set of generators for an
/// n-bit range proof. A validator must fix `n` itself, not read it from the
/// transaction, or the prover chooses the range. Calling `setup` in the
/// validator costs about 2B CPU at n = 8. A module constant
/// (`const vk = bullet.setup(8)`) is evaluated at compile time instead, but
/// makes the script far larger; the implementation report has the figures.
pub fn setup(n: Int) -> BulletproofVerificationKey {
  if n <= 0 || n > max_n {
    fail @"n must be between 1 and max_n"
  } else {
    let g = g1.generator
    let h = g1.hash_to_group("h", bytearray.concat(protocol_id, "/base"))
    let u = g1.hash_to_group("u", bytearray.concat(protocol_id, "/base"))
    let indices = list.range(0, n - 1)
    let g_vec =
      list.map(
        indices,
        fn(i) {
          g1.hash_to_group(
            bytearray.from_int_big_endian(i, 4),
            bytearray.concat(protocol_id, "/g_vec"),
          )
        },
      )
    let h_vec =
      list.map(
        indices,
        fn(i) {
          g1.hash_to_group(
            bytearray.from_int_big_endian(i, 4),
            bytearray.concat(protocol_id, "/h_vec"),
          )
        },
      )
    let g_sum = list.foldl(g_vec, g1.zero, g1.add)
    let h_sum = list.foldl(h_vec, g1.zero, g1.add)
    BulletproofVerificationKey { g, h, u, g_vec, h_vec, g_sum, h_sum, n }
  }
}

/// Public Pedersen commitment to a hidden value: V = g^value * h^gamma.
///
/// Fails unless `0 <= value < r`, the order of the scalar field. Exponents
/// are taken mod `r`, so without this check `value + k * r` (a negative
/// amount included) would give the same point as `value`, and a range proof
/// for `value` would verify against it.
pub fn commit_value(
  vk: BulletproofVerificationKey,
  value: Int,
  gamma: State<Scalar>,
) -> G1Element {
  if value < 0 || value >= scalar.field_prime {
    fail @"value must be in [0, r)"
  } else {
    g1.add(g1.scale(vk.g, scalar.from_int(value)), g1.scale(vk.h, gamma))
  }
}

/// Generate a range proof that `value` lies in `[0, 2^vk.n)` given a Pedersen
/// commitment blinding `gamma`. Aiken has no RNG, so all blinding factors used
/// internally must be supplied explicitly by the caller.
pub fn generate_proof(
  vk: BulletproofVerificationKey,
  value: Int,
  gamma: State<Scalar>,
  blinding: ProofBlinding,
) -> BulletproofProof {
  if value < 0 || value >= pow2(vk.n) {
    fail @"value out of range"
  } else {
    generate_proof_unchecked(vk, value, gamma, blinding)
  }
}

fn generate_proof_unchecked(
  vk: BulletproofVerificationKey,
  value: Int,
  gamma: State<Scalar>,
  blinding: ProofBlinding,
) -> BulletproofProof {
  if list.length(blinding.s_l) != vk.n || list.length(blinding.s_r) != vk.n {
    fail @"blinding vector length mismatch"
  } else {
    let bits = bits_of(value, vk.n)
    let a_l = list.map(bits, scalar_from_bit)
    let a_r = list.map(a_l, fn(ai) { scalar.sub(ai, scalar.from_int(1)) })

    let v_commit = commit_value(vk, value, gamma)

    let a_point =
      g1.add(
        g1.scale(vk.h, blinding.alpha),
        g1.add(vector_commit(a_l, vk.g_vec), vector_commit(a_r, vk.h_vec)),
      )
    let s_point =
      g1.add(
        g1.scale(vk.h, blinding.rho),
        g1.add(
          vector_commit(blinding.s_l, vk.g_vec),
          vector_commit(blinding.s_r, vk.h_vec),
        ),
      )

    let state1 =
      transcript_absorb2(transcript_init(vk, v_commit), a_point, s_point)
    let y = hash_to_scalar(bytearray.concat(state1, "y"))
    let z = hash_to_scalar(bytearray.concat(state1, "z"))

    let two = scalar.add(scalar.from_int(1), scalar.from_int(1))
    let z2 = scalar.mul(z, z)
    let y_pow = powers_of(y, vk.n)
    let two_pow = powers_of(two, vk.n)

    let l0 = list.map(a_l, fn(ai) { scalar.sub(ai, z) })
    let l1 = blinding.s_l
    let r0 =
      list.map3(
        a_r,
        y_pow,
        two_pow,
        fn(ari, yi, ti) {
          scalar.add(scalar.mul(yi, scalar.add(ari, z)), scalar.mul(z2, ti))
        },
      )
    let r1 = list.map2(y_pow, blinding.s_r, scalar.mul)

    let t1_coef =
      scalar.add(scalar_inner_product(l0, r1), scalar_inner_product(l1, r0))
    let t2_coef = scalar_inner_product(l1, r1)

    let t1_point =
      g1.add(g1.scale(vk.g, t1_coef), g1.scale(vk.h, blinding.tau1))
    let t2_point =
      g1.add(g1.scale(vk.g, t2_coef), g1.scale(vk.h, blinding.tau2))

    let state2 = transcript_absorb2(state1, t1_point, t2_point)
    let x = hash_to_scalar(bytearray.concat(state2, "x"))

    let l_vec =
      list.map2(l0, l1, fn(l0i, l1i) { scalar.add(l0i, scalar.mul(x, l1i)) })
    let r_vec =
      list.map2(r0, r1, fn(r0i, r1i) { scalar.add(r0i, scalar.mul(x, r1i)) })

    let tau_x =
      scalar.add(
        scalar.mul(z2, gamma),
        scalar.add(
          scalar.mul(blinding.tau1, x),
          scalar.mul(blinding.tau2, scalar.mul(x, x)),
        ),
      )
    let mu = scalar.add(blinding.alpha, scalar.mul(blinding.rho, x))

    BulletproofProof {
      a: a_point,
      s: s_point,
      t1: t1_point,
      t2: t2_point,
      tau_x,
      mu,
      l_vec,
      r_vec,
    }
  }
}

/// Named helper (not an inline lambda) — a bare bit (0/1) is always a valid
/// field element, so this cannot fail in practice.
fn scalar_from_bit(b: Int) -> State<Scalar> {
  let s = scalar.from_int(b)
  s
}

/// Blinding factors from a seed, for the tests below only. Anyone who knows
/// the seed can read the committed value back from the proof's `l_vec`, so a
/// real prover must supply fresh random blinding to `generate_proof`.
fn derive_blinding(seed: ByteArray, n: Int) -> ProofBlinding {
  let alpha = hash_to_scalar(bytearray.concat(seed, "alpha"))
  let rho = hash_to_scalar(bytearray.concat(seed, "rho"))
  let tau1 = hash_to_scalar(bytearray.concat(seed, "tau1"))
  let tau2 = hash_to_scalar(bytearray.concat(seed, "tau2"))
  let indices = list.range(0, n - 1)
  let s_l =
    list.map(
      indices,
      fn(i) {
        hash_to_scalar(
          bytearray.concat(
            seed,
            bytearray.concat("s_l", bytearray.from_int_big_endian(i, 4)),
          ),
        )
      },
    )
  let s_r =
    list.map(
      indices,
      fn(i) {
        hash_to_scalar(
          bytearray.concat(
            seed,
            bytearray.concat("s_r", bytearray.from_int_big_endian(i, 4)),
          ),
        )
      },
    )
  ProofBlinding { alpha, rho, tau1, tau2, s_l, s_r }
}

/// Verify a range proof against a public Pedersen commitment. Never takes the
/// hidden value or its blinding factor. `vk` can only come from `setup`; see
/// `BulletproofVerificationKey`.
pub fn verify(
  vk: BulletproofVerificationKey,
  v_commit: G1Element,
  proof: BulletproofProof,
) -> Bool {
  if vk.n <= 0 || vk.n > max_n {
    False
  } else if list.length(proof.l_vec) != vk.n || list.length(proof.r_vec) != vk.n {
    False
  } else {
    let state1 =
      transcript_absorb2(transcript_init(vk, v_commit), proof.a, proof.s)
    let y = hash_to_scalar(bytearray.concat(state1, "y"))
    let z = hash_to_scalar(bytearray.concat(state1, "z"))
    let state2 = transcript_absorb2(state1, proof.t1, proof.t2)
    let x = hash_to_scalar(bytearray.concat(state2, "x"))

    when scalar.recip(y) is {
      None -> False
      Some(y_inv) -> {
        let two = scalar.add(scalar.from_int(1), scalar.from_int(1))
        let y_pow = powers_of(y, vk.n)
        let two_pow = powers_of(two, vk.n)
        let sum_y = scalar_sum(y_pow)
        let sum_2 = scalar_sum(two_pow)

        let z2 = scalar.mul(z, z)
        let z3 = scalar.mul(z2, z)
        let delta =
          scalar.sub(
            scalar.mul(scalar.sub(z, z2), sum_y),
            scalar.mul(z3, sum_2),
          )

        let t_hat = scalar_inner_product(proof.l_vec, proof.r_vec)

        let lhs1 = g1.add(g1.scale(vk.g, t_hat), g1.scale(vk.h, proof.tau_x))
        let rhs1 =
          g1.add(
            g1.scale(v_commit, z2),
            g1.add(
              g1.scale(vk.g, delta),
              g1.add(
                g1.scale(proof.t1, x),
                g1.scale(proof.t2, scalar.mul(x, x)),
              ),
            ),
          )
        let check1 = g1.equal(lhs1, rhs1)

        let y_inv_pow = powers_of(y_inv, vk.n)
        let h_prime =
          list.map2(
            vk.h_vec,
            y_inv_pow,
            fn(h_i, yi_inv) { g1.scale(h_i, yi_inv) },
          )
        let r_adj =
          list.map2(
            proof.r_vec,
            two_pow,
            fn(ri, ti) { scalar.sub(ri, scalar.mul(z2, ti)) },
          )

        let g_l_commit = vector_commit(proof.l_vec, vk.g_vec)
        let h_r_commit = vector_commit(r_adj, h_prime)

        let lhs2 = g1.add(proof.a, g1.scale(proof.s, x))
        let rhs2 =
          g1.add(
            g1.scale(vk.h, proof.mu),
            g1.add(
              g_l_commit,
              g1.add(h_r_commit, g1.scale(g1.sub(vk.g_sum, vk.h_sum), z)),
            ),
          )
        let check2 = g1.equal(lhs2, rhs2)

        check1 && check2
      }
    }
  }
}

/// Decode a proof taken from a redeemer or datum.
///
/// Fails unless every point is a valid compressed G1 point in the prime-order
/// subgroup (`g1.decompress` checks this) and every scalar lies in `[0, r)`.
/// Scalars are used mod `r`, so without the range check `x + r` or `x - r`
/// would decode to the same scalar as `x`, and one proof would have many
/// encodings that all verify. The Groth16 and PLONK public inputs are checked
/// the same way. Vector lengths are left to `verify`, which returns `False`
/// unless `l_vec` and `r_vec` each have `n` entries.
///
/// It fails rather than returning `None`, like `commit_value` and the Groth16
/// and PLONK proof decoders. A bad point can't be reported any other way:
/// `g1.decompress` is a builtin that fails on one. In a validator, a failed
/// decode fails the transaction, as a `False` from `verify` would.
pub fn uncompress_proof(proof: CompressedBulletproofProof) -> BulletproofProof {
  BulletproofProof {
    a: g1.decompress(proof.a),
    s: g1.decompress(proof.s),
    t1: g1.decompress(proof.t1),
    t2: g1.decompress(proof.t2),
    tau_x: scalar_in_field(proof.tau_x),
    mu: scalar_in_field(proof.mu),
    l_vec: list.map(proof.l_vec, scalar_in_field),
    r_vec: list.map(proof.r_vec, scalar_in_field),
  }
}

/// Encode a proof as plain data for a redeemer or datum; `uncompress_proof`
/// reverses it.
pub fn compress_proof(proof: BulletproofProof) -> CompressedBulletproofProof {
  CompressedBulletproofProof {
    a: g1.compress(proof.a),
    s: g1.compress(proof.s),
    t1: g1.compress(proof.t1),
    t2: g1.compress(proof.t2),
    tau_x: scalar.to_int(proof.tau_x),
    mu: scalar.to_int(proof.mu),
    l_vec: list.map(proof.l_vec, scalar.to_int),
    r_vec: list.map(proof.r_vec, scalar.to_int),
  }
}

fn scalar_in_field(x: Int) -> State<Scalar> {
  if x < 0 || x >= scalar.field_prime {
    fail @"scalar must be in [0, r)"
  } else {
    scalar.from_int(x)
  }
}

/// `u` is intentionally included even though the current two-check verifier
/// does not use it. Binding `u` into every transcript hash ties the challenges
/// to the full protocol identity — a future IPA phase that activates `u` will
/// derive consistent challenges without a breaking change to transcript format.
fn transcript_init(
  vk: BulletproofVerificationKey,
  v_commit: G1Element,
) -> ByteArray {
  crypto.blake2b_256(
    bytearray.concat(
      protocol_id,
      bytearray.concat(
        g1.compress(vk.g),
        bytearray.concat(
          g1.compress(vk.h),
          bytearray.concat(
            g1.compress(vk.u),
            bytearray.concat(
              bytearray.from_int_big_endian(vk.n, 4),
              g1.compress(v_commit),
            ),
          ),
        ),
      ),
    ),
  )
}

fn transcript_absorb2(
  state: ByteArray,
  p1: G1Element,
  p2: G1Element,
) -> ByteArray {
  crypto.blake2b_256(
    bytearray.concat(state, bytearray.concat(g1.compress(p1), g1.compress(p2))),
  )
}

/// Hash-and-increment into the scalar field. A single blake2b_256 digest
/// interpreted as a big-endian integer lands outside `field_prime` (~45% of
/// 2^256) about 55% of the time, so a single-shot hash-to-scalar traps
/// unacceptably often; retry with an incrementing counter instead.
fn hash_to_scalar(seed: ByteArray) -> State<Scalar> {
  hash_to_scalar_loop(seed, 0)
}

fn hash_to_scalar_loop(seed: ByteArray, counter: Int) -> State<Scalar> {
  let digest =
    crypto.blake2b_256(
      bytearray.concat(seed, bytearray.from_int_big_endian(counter, 4)),
    )
  let n = bytearray.to_int_big_endian(digest)
  if n < scalar.field_prime {
    scalar.from_int(n)
  } else {
    hash_to_scalar_loop(seed, counter + 1)
  }
}

/// `scalar.scale(base, i)` is exponentiation (`base^i`), not i*base — it
/// produces [1, base, base^2, ...] as required by the Bulletproofs protocol.
fn powers_of(base: State<Scalar>, count: Int) -> List<State<Scalar>> {
  list.map(list.range(0, count - 1), fn(i) { scalar.scale(base, i) })
}

fn scalar_sum(vec: List<State<Scalar>>) -> State<Scalar> {
  list.foldl(vec, scalar.from_int(0), scalar.add)
}

fn scalar_inner_product(
  l: List<State<Scalar>>,
  r: List<State<Scalar>>,
) -> State<Scalar> {
  when (l, r) is {
    ([], []) -> scalar.from_int(0)
    ([x, ..xs], [y, ..ys]) ->
      scalar.add(scalar.mul(x, y), scalar_inner_product(xs, ys))
    (_, _) -> fail @"vector length mismatch"
  }
}

fn vector_commit(
  scalars: List<State<Scalar>>,
  points: List<G1Element>,
) -> G1Element {
  when (scalars, points) is {
    ([], []) -> g1.zero
    ([s, ..ss], [p, ..ps]) -> g1.add(g1.scale(p, s), vector_commit(ss, ps))
    (_, _) -> fail @"vector length mismatch"
  }
}

fn bits_of(value: Int, remaining: Int) -> List<Int> {
  if remaining == 0 {
    []
  } else {
    [value % 2, ..bits_of(value / 2, remaining - 1)]
  }
}

fn pow2(n: Int) -> Int {
  if n <= 0 {
    1
  } else {
    2 * pow2(n - 1)
  }
}

test setup_smoke() {
  let vk = setup(8)
  and {
    list.length(vk.g_vec) == 8,
    list.length(vk.h_vec) == 8,
    !g1.equal(vk.g_sum, g1.zero),
    !g1.equal(vk.h_sum, g1.zero),
  }
}

test range_proof_valid() {
  let vk = setup(8)
  let gamma = scalar.from_int(12345)
  let value = 200
  let proof = generate_proof(vk, value, gamma, derive_blinding("seed-1", vk.n))
  let v_commit = commit_value(vk, value, gamma)
  verify(vk, v_commit, proof)
}

test range_proof_valid_zero() {
  let vk = setup(8)
  let gamma = scalar.from_int(777)
  let value = 0
  let proof = generate_proof(vk, value, gamma, derive_blinding("seed-2", vk.n))
  let v_commit = commit_value(vk, value, gamma)
  verify(vk, v_commit, proof)
}

test range_proof_valid_max() {
  let vk = setup(8)
  let gamma = scalar.from_int(9999)
  let value = 255
  let proof = generate_proof(vk, value, gamma, derive_blinding("seed-3", vk.n))
  let v_commit = commit_value(vk, value, gamma)
  verify(vk, v_commit, proof)
}

test range_proof_fails_wrong_commitment() {
  let vk = setup(8)
  let gamma = scalar.from_int(12345)
  let value = 200
  let proof = generate_proof(vk, value, gamma, derive_blinding("seed-4", vk.n))
  let wrong_commit = commit_value(vk, value + 1, gamma)
  !verify(vk, wrong_commit, proof)
}

test range_proof_fails_tampered_tau_x() {
  let vk = setup(8)
  let gamma = scalar.from_int(12345)
  let value = 200
  let proof = generate_proof(vk, value, gamma, derive_blinding("seed-5", vk.n))
  let v_commit = commit_value(vk, value, gamma)
  let tampered =
    BulletproofProof {
      ..proof,
      tau_x: scalar.add(proof.tau_x, scalar.from_int(1)),
    }
  !verify(vk, v_commit, tampered)
}

test range_proof_fails_tampered_l_vec() {
  let vk = setup(8)
  let gamma = scalar.from_int(12345)
  let value = 200
  let proof = generate_proof(vk, value, gamma, derive_blinding("seed-6", vk.n))
  let v_commit = commit_value(vk, value, gamma)
  expect [first, ..rest] = proof.l_vec
  let tampered =
    BulletproofProof {
      ..proof,
      l_vec: [scalar.add(first, scalar.from_int(1)), ..rest],
    }
  !verify(vk, v_commit, tampered)
}

test range_proof_fails_wrong_vector_length() {
  let vk = setup(8)
  let gamma = scalar.from_int(12345)
  let value = 200
  let proof = generate_proof(vk, value, gamma, derive_blinding("seed-7", vk.n))
  let v_commit = commit_value(vk, value, gamma)
  expect [_, ..rest] = proof.l_vec
  let tampered = BulletproofProof { ..proof, l_vec: rest }
  !verify(vk, v_commit, tampered)
}

test commit_value_rejects_r() fail {
  let vk = setup(8)
  let gamma = scalar.from_int(12345)
  commit_value(vk, scalar.field_prime, gamma) == commit_value(vk, 0, gamma)
}

test commit_value_rejects_negative() fail {
  let vk = setup(8)
  let gamma = scalar.from_int(12345)
  commit_value(vk, -1, gamma) == commit_value(vk, scalar.field_prime - 1, gamma)
}

test commit_value_accepts_field_boundary() {
  let vk = setup(8)
  let gamma = scalar.from_int(12345)
  g1.equal(
    commit_value(vk, scalar.field_prime - 1, gamma),
    g1.sub(commit_value(vk, 0, gamma), vk.g),
  )
}

test generate_proof_rejects_out_of_range() fail {
  let vk = setup(8)
  let gamma = scalar.from_int(1)
  let blinding = derive_blinding("seed-8", vk.n)
  let proof = generate_proof(vk, 256, gamma, blinding)
  list.length(proof.l_vec) == vk.n
}

test range_proof_fails_out_of_range_bypassing_guard() {
  let vk = setup(8)
  let gamma = scalar.from_int(555)
  let value = 256
  let blinding = derive_blinding("seed-9", vk.n)
  let proof = generate_proof_unchecked(vk, value, gamma, blinding)
  let v_commit = commit_value(vk, value, gamma)
  !verify(vk, v_commit, proof)
}

/// A valid proof's commitment and plain-data encoding, for the tests below.
fn compressed_fixture() -> (
  BulletproofVerificationKey,
  G1Element,
  CompressedBulletproofProof,
) {
  let vk = setup(8)
  let gamma = scalar.from_int(12345)
  let value = 200
  let proof = generate_proof(vk, value, gamma, derive_blinding("seed-10", vk.n))
  (vk, commit_value(vk, value, gamma), compress_proof(proof))
}

test compressed_proof_round_trip() {
  let (vk, v_commit, compressed) = compressed_fixture()
  let proof = uncompress_proof(compressed)
  and {
    verify(vk, v_commit, proof),
    compress_proof(proof) == compressed,
  }
}

test uncompress_proof_rejects_tau_x_plus_r() fail {
  let (vk, v_commit, compressed) = compressed_fixture()
  let shifted =
    CompressedBulletproofProof {
      ..compressed,
      tau_x: compressed.tau_x + scalar.field_prime,
    }
  verify(vk, v_commit, uncompress_proof(shifted))
}

test uncompress_proof_rejects_negative_l_vec_entry() fail {
  let (vk, v_commit, compressed) = compressed_fixture()
  expect [first, ..rest] = compressed.l_vec
  let shifted =
    CompressedBulletproofProof {
      ..compressed,
      l_vec: [first - scalar.field_prime, ..rest],
    }
  verify(vk, v_commit, uncompress_proof(shifted))
}

/// x = 1 is not the x-coordinate of any point on the curve.
test uncompress_proof_rejects_point_off_curve() fail {
  let (_, _, compressed) = compressed_fixture()
  let off_curve =
    #"800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001"
  let bad = CompressedBulletproofProof { ..compressed, t2: off_curve }
  g1.compress(uncompress_proof(bad).t2) == off_curve
}
