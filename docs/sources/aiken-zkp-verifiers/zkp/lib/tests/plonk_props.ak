//// Property-based tests for the PLONK verifier, on the affine fixture valid
//// for `[63, 7]` (`tests/plonk_tests`). See `tests/groth_props` for what the
//// `prop_*` and `known_issue_*` prefixes mean.

use aiken/collection/list
use aiken/crypto/bls12_381/scalar.{field_prime}
use aiken/fuzz
use plonk/proofs.{PreparedPlonkProof, plonk_prepare_proof}
use plonk/raw_affine.{AffineProof, prepare_affine_proof, prepare_affine_vkey}
use plonk/verifier.{verify_plonk}
use tests/groth_props.{nonzero_scalar, update_at}
use tests/plonk_tests.{
  test_plonk_proof_affine, test_plonk_pub_inputs, test_plonk_vkey_affine,
}

/// Prepare and verify, the way an on-chain caller would.
pub fn plonk_verifies(proof: AffineProof, pub_inputs: List<Int>) -> Bool {
  let preinputs = prepare_affine_vkey(test_plonk_vkey_affine)
  let prepared =
    plonk_prepare_proof(preinputs, pub_inputs, prepare_affine_proof(proof))
  verify_plonk(preinputs: preinputs, pub_inputs: pub_inputs, proof: prepared)
}

/// Add `delta` (mod r) to one of the six evaluation scalars.
fn tamper_eval(proof: AffineProof, which: Int, delta: Int) -> AffineProof {
  let bump =
    fn(x) { ( x + delta ) % field_prime }
  when which is {
    0 -> AffineProof { ..proof, a_eval: bump(proof.a_eval) }
    1 -> AffineProof { ..proof, b_eval: bump(proof.b_eval) }
    2 -> AffineProof { ..proof, c_eval: bump(proof.c_eval) }
    3 -> AffineProof { ..proof, s_sig1_p: bump(proof.s_sig1_p) }
    4 -> AffineProof { ..proof, s_sig2_p: bump(proof.s_sig2_p) }
    _ -> AffineProof { ..proof, z_omega: bump(proof.z_omega) }
  }
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

/// Moving any public input to a different value in `[0, r)` must break the
/// proof.
test prop_plonk_rejects_changed_input(
  (index, delta) via fuzz.tuple(fuzz.int_between(0, 1), nonzero_scalar()),
) {
  let inputs =
    update_at(
      test_plonk_pub_inputs,
      index,
      fn(x) { ( x + delta ) % field_prime },
    )
  !plonk_verifies(test_plonk_proof_affine, inputs)
}

/// Changing any evaluation scalar in the proof must break it.
test prop_plonk_rejects_tampered_evaluation(
  (which, delta) via fuzz.tuple(fuzz.int_between(0, 5), nonzero_scalar()),
) {
  !plonk_verifies(
    tamper_eval(test_plonk_proof_affine, which, delta),
    test_plonk_pub_inputs,
  )
}

// ---------------------------------------------------------------------------
// Known issues
// ---------------------------------------------------------------------------

/// ADAOcommunity/zk#12: an input of `x + k * r` verifies like `x`.
/// Once fixed, replace with `prop_plonk_rejects_input_out_of_field` (the same
/// call must fail).
test known_issue_12_plonk_input_not_range_checked(
  (index, k) via fuzz.tuple(fuzz.int_between(0, 1), fuzz.int_between(1, 1000)),
) {
  let inputs =
    update_at(test_plonk_pub_inputs, index, fn(x) { x + k * field_prime })
  plonk_verifies(test_plonk_proof_affine, inputs)
}

/// ADAOcommunity/zk#14: nothing checks the inverse list's length. Dropping the
/// last inverse (the one for the surplus generator, #19) still verifies.
/// Dropping one that belongs to a public input makes verification fail, because
/// each inverse also weights its input in the public-input polynomial; that
/// input is then hashed into the transcript but left out of the constraint, the
/// same gap as #13. Once fixed, replace with
/// `plonk_rejects_short_inverse_list` (the same call must fail).
test known_issue_14_plonk_inverse_list_length_unchecked() {
  let preinputs = prepare_affine_vkey(test_plonk_vkey_affine)
  let prepared =
    plonk_prepare_proof(
      preinputs,
      test_plonk_pub_inputs,
      prepare_affine_proof(test_plonk_proof_affine),
    )
  let short =
    PreparedPlonkProof {
      ..prepared,
      lagrange_inverses: list.take(
        prepared.lagrange_inverses,
        list.length(test_plonk_pub_inputs),
      ),
    }
  and {
    list.length(short.lagrange_inverses) < list.length(preinputs.generators),
    verify_plonk(
      preinputs: preinputs,
      pub_inputs: test_plonk_pub_inputs,
      proof: short,
    ),
  }
}
