use nova/types.{CircuitParams, PredicatePolicy, SlimProof}
use aiken/crypto
use aiken/collection/list
use aiken/primitive/bytearray

/// BLS12-381 scalar field prime (r), the modulus of the circuit's Fr.
pub const field_prime =
  52435875175126190479447740508185965837690552500527637822603658699938581184513

/// Verify a slim sumcheck compression proof.
///
/// Accepts pre-computed Fiat-Shamir challenges (r_challenges) as part of the
/// proof. The hash-based derivation of challenges is verified off-chain.
/// On-chain, we verify the algebraic sumcheck properties.
pub fn verify_slim(proof: SlimProof) -> Bool {
  let n_rounds = length(proof.sumcheck_polys)
  let n_claims = length(proof.sumcheck_claims)
  n_claims == n_rounds + 1
    && verify_rounds(proof.sumcheck_polys, proof.sumcheck_claims, n_rounds, proof.r_challenges)
    && proof.claimed_product_at_r == tail_last(proof.sumcheck_claims)
}

/// Verify all sumcheck rounds using pre-computed challenges.
fn verify_rounds(
  polys: List<List<Int>>,
  claims: List<Int>,
  n_rounds: Int,
  r_challenges: List<Int>,
) -> Bool {
  when claims is {
    [initial_sum, ..] ->
      do_verify_rounds(polys, claims, 0, n_rounds, initial_sum, r_challenges)
    [] -> False
  }
}

/// Tail-recursive round verification.
fn do_verify_rounds(
  polys: List<List<Int>>,
  claims: List<Int>,
  round: Int,
  n_rounds: Int,
  current_sum: Int,
  r_challenges: List<Int>,
) -> Bool {
  if round >= n_rounds {
    True
  } else {
    when polys is {
      [poly, ..rest_polys] ->
        when poly is {
          [f0, delta] ->
            if f0 + f0 + delta != current_sum {
              False
            } else {
              let ri = get_at(round, r_challenges)
              let next_sum = f0 + delta * ri
              do_verify_rounds(rest_polys, claims, round + 1, n_rounds, next_sum, r_challenges)
            }
          _ -> False
        }
      _ -> False
    }
  }
}

fn get_at(idx: Int, xs: List<a>) -> a {
  when xs is {
    [] -> fail @"get_at: index out of bounds"
    [x, ..rest] ->
      if idx == 0 {
        x
      } else {
        get_at(idx - 1, rest)
      }
  }
}

fn tail_last(xs: List<a>) -> a {
  when xs is {
    [x] -> x
    [_, ..rest] -> tail_last(rest)
    _ -> fail @"tail_last: empty list"
  }
}

fn length(xs: List<a>) -> Int {
  do_length(xs, 0)
}

fn do_length(xs: List<a>, acc: Int) -> Int {
  when xs is {
    [] -> acc
    [_, ..rest] -> do_length(rest, acc + 1)
  }
}

/// ---------------------------------------------------------------------------
/// On-chain Fiat-Shamir sumcheck verification
///
/// Unlike `verify_slim` above, this re-derives the sumcheck challenges from the
/// transcript (BLAKE2b-256 of claims + polynomials, mod r) rather than trusting
/// the `r_challenges` supplied in the proof. Without re-derivation, an attacker
/// could trivially forge a passing `SlimProof` by choosing the challenges, so a
/// gate script MUST use this path.
/// ---------------------------------------------------------------------------

/// Serialize field elements to concatenated 32-byte LE byte arrays.
fn serialize_list(xs: List<Int>, acc: ByteArray) -> ByteArray {
  when xs is {
    [] -> acc
    [x, ..rest] ->
      serialize_list(rest, bytearray.concat(acc, bytearray.from_int_little_endian(x, 32)))
  }
}

/// Derive a Fiat-Shamir challenge from claims and polynomial coefficients.
/// Uses BLAKE2b-256 + mod r, matching the Rust prover's `challenge_from_hash`.
fn derive_challenge(claims: List<Int>, poly: List<Int>) -> Int {
  let acc = serialize_list(claims, #"")
  let acc2 = serialize_list(poly, acc)
  let raw = bytearray.to_int_little_endian(crypto.blake2b_256(acc2))
  raw % field_prime
}

/// Take the first n elements of a list.
fn take_prefix(xs: List<a>, n: Int) -> List<a> {
  do_take_prefix(xs, n, [])
}

fn do_take_prefix(xs: List<a>, n: Int, acc: List<a>) -> List<a> {
  if n <= 0 {
    list.reverse(acc)
  } else {
    when xs is {
      [] -> list.reverse(acc)
      [x, ..rest] -> do_take_prefix(rest, n - 1, [x, ..acc])
    }
  }
}

/// Verify a slim sumcheck proof, re-deriving Fiat-Shamir challenges on-chain.
pub fn verify_slim_fs(proof: SlimProof) -> Bool {
  let n_rounds = length(proof.sumcheck_polys)
  let n_claims = length(proof.sumcheck_claims)
  n_claims == n_rounds + 1
    && do_verify_rounds_fs(proof.sumcheck_polys, proof.sumcheck_claims, 0, n_rounds)
    && proof.claimed_product_at_r == tail_last(proof.sumcheck_claims)
}

fn do_verify_rounds_fs(
  polys: List<List<Int>>,
  claims: List<Int>,
  round: Int,
  n_rounds: Int,
) -> Bool {
  if round >= n_rounds {
    True
  } else {
    when polys is {
      [poly, ..rest_polys] ->
        when poly is {
          [f0, delta] -> {
            let current_sum = get_at(round, claims)
            if f0 + f0 + delta != current_sum {
              False
            } else {
              let hash_input = take_prefix(claims, round + 1)
              let ri = derive_challenge(hash_input, poly)
              let next_claim = get_at(round + 1, claims)
              let next_sum = f0 + delta * ri
              next_sum == next_claim
                && do_verify_rounds_fs(rest_polys, claims, round + 1, n_rounds)
            }
          }
          _ -> False
        }
      _ -> False
    }
  }
}

/// ---------------------------------------------------------------------------
/// Selective-disclosure Predicate gate
///
/// A reusable gate validator helper. It succeeds iff:
///   1. the Nova slim sumcheck proof is sound (`verify_slim_fs`), and
///   2. the step circuit params match `expected_params`, and
///   3. the proof's public state commits to the gate policy and eligibility:
///        x[0] = issuer_pk_u, x[1] = issuer_pk_v, x[2] = current_year,
///        x[3] = country_root, x[4] = eligible (= 1).
/// The credential fields (dob_year, country, signature, Merkle path) never
/// appear in `x` — they are hidden inside the folded witness — so the gate
/// reveals only that *some* eligible holder produced this proof.
/// ---------------------------------------------------------------------------

pub fn verify_predicate_gate(
  proof: SlimProof,
  expected_params: CircuitParams,
  policy: PredicatePolicy,
) -> Bool {
  verify_slim_fs(proof)
    && proof.circuit_params == expected_params
    && predicate_state_matches(proof.final_instance.x, policy)
}

fn predicate_state_matches(x: List<Int>, policy: PredicatePolicy) -> Bool {
  get_at(0, x) == policy.issuer_pk_u
    && get_at(1, x) == policy.issuer_pk_v
    && get_at(2, x) == policy.current_year
    && get_at(3, x) == policy.country_root
    && get_at(4, x) == 1
}
