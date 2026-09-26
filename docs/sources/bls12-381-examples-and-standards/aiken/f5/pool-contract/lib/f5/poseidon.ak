use f5/constants.{field_prime, mds, round_constants}

// ---------------------------------------------------------------------------
// Poseidon BLS12-381 (t=3, alpha=5, RF=8, RP=57).
//
// Faithful port of `poseidon_bls12_381/0` in
// circom/PoseidonMerkle/helpers_py/poseidon_merkle.py and the matching Circom
// template in circom/PrivacyPool (initial state [0, in0, in1], 65 rounds,
// rounds 0..3 and 61..64 full, remainder partial on the first element).
//
// Round constants and MDS matrix are generated in constants.ak from the same
// Python helper, so on-chain hashes are value-identical to the off-chain pool
// simulation and to the circuit the Groth16 proofs commit to.
//
// All arithmetic is the BLS12-381 scalar field arithmetic on Int (mod P).
// ---------------------------------------------------------------------------

/// Pow 5 S-box: x -> x^5 (mod P), matching the circuit's S-box.
fn sbox5(x: Int) -> Int {
  let x2 = x * x % field_prime
  let x4 = x2 * x2 % field_prime
  x4 * x % field_prime
}

/// Full round: apply the S-box to every state element.
fn full_sbox(s0: Int, s1: Int, s2: Int) -> (Int, Int, Int) {
  let a0 = sbox5(s0)
  let a1 = sbox5(s1)
  let a2 = sbox5(s2)
  (a0, a1, a2)
}

/// Partial round: apply the S-box only to the first element.
fn partial_sbox(s0: Int, s1: Int, s2: Int) -> (Int, Int, Int) {
  (sbox5(s0), s1, s2)
}

/// MDS mix: new = M * state (mod P).
fn mds_mix(s0: Int, s1: Int, s2: Int) -> (Int, Int, Int) {
  when mds is {
    [[m00, m01, m02], [m10, m11, m12], [m20, m21, m22]] -> {
      let t0 = m00 * s0 + m01 * s1 + m02 * s2
      let t1 = m10 * s0 + m11 * s1 + m12 * s2
      let t2 = m20 * s0 + m21 * s1 + m22 * s2
      (t0 % field_prime, t1 % field_prime, t2 % field_prime)
    }
    _ -> fail @"MDS matrix malformed"
  }
}

/// Iterate the 65 rounds over the flattened round constants.
fn rounds(
  rcs: List<Int>,
  r: Int,
  s0: Int,
  s1: Int,
  s2: Int,
) -> Int {
  when rcs is {
    [c0, c1, c2, ..rest] -> {
      // AddRoundConstants.
      let s0 = s0 + c0 % field_prime
      let s1 = s1 + c1 % field_prime
      let s2 = s2 + c2 % field_prime

      // S-box: full for r in 0..3 or 61..64, partial otherwise.
      let (s0, s1, s2) =
        if r < 4 || r >= 61 {
          full_sbox(s0, s1, s2)
        } else {
          partial_sbox(s0, s1, s2)
        }

      // MDS mix.
      let (s0, s1, s2) = mds_mix(s0, s1, s2)
      rounds(rest, r + 1, s0, s1, s2)
    }
    _ -> s0
  }
}

/// PoseidonBLS12_381(in0, in1) with initial state [0, in0, in1].
///
/// Inputs are reduced mod P; the output is the first state element after 65
/// rounds. This is the compression function of the pool's Merkle tree exactly
/// as the off-chain simulation and the privacy_pool circuit use it.
pub fn hash(in0: Int, in1: Int) -> Int {
  let s0 = 0 % field_prime
  let s1 = in0 % field_prime
  let s2 = in1 % field_prime
  rounds(round_constants, 0, s0, s1, s2)
}

// ---------------------------------------------------------------------------
// Tests — golden values computed by helpers_py/poseidon_merkle.py.
// ---------------------------------------------------------------------------

test poseidon_hashes_zero_zero() {
  hash(0, 0)
    == 39704413365395714732902920194612999065094381874203236779011164022408220537174
}

test poseidon_hashes_one_two() {
  hash(1, 2)
    == 18456658763349757341014058622209659766100673761449600566550821987295786346378
}

test poseidon_reduces_inputs_mod_p() {
  // hash(P+1, P+2) == hash(1, 2) because inputs are reduced mod P.
  hash(field_prime + 1, field_prime + 2) == hash(1, 2)
}

test poseidon_is_not_additive() {
  // Sanity: Poseidon is a permutation, not a linear map.
  hash(1, 2) != hash(1, 3)
}