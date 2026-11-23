//// Property-based tests for the PLONK verifier, on the affine fixture valid
//// for `[63, 7]` (`tests/plonk_tests`). See `tests/groth_props` for what the
//// `prop_*` and `known_issue_*` prefixes mean.

use aiken/collection/list
use aiken/crypto/bls12_381/scalar.{field_prime}
use aiken/fuzz
use plonk/preinputs.{PreparedPlonkPreInputs}
use plonk/proofs.{PreparedPlonkProof, plonk_prepare_proof}
use plonk/raw_affine.{
  AffineProof, AffineVerificationKey, prepare_affine_proof, prepare_affine_vkey,
}
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

/// ADAOcommunity/zk#12: an input of `x + k * r` or `x - k * r` is rejected,
/// although `scalar.from_int` maps it to the same scalar as `x`, in both the
/// maths and the transcript.
test prop_plonk_rejects_input_out_of_field(
  (index, k, below) via fuzz.tuple3(
    fuzz.int_between(0, 1),
    fuzz.int_between(1, 1000),
    fuzz.bool(),
  ),
) {
  let shift =
    if below {
      -k * field_prime
    } else {
      k * field_prime
    }
  let inputs = update_at(test_plonk_pub_inputs, index, fn(x) { x + shift })
  !plonk_verifies(test_plonk_proof_affine, inputs)
}

/// ADAOcommunity/zk#13: more inputs than `n_public` are rejected. An honest
/// proof would fail anyway, because the extra values change the transcript, so
/// this passes with or without the count check; `plonk_rejects_n_public_mismatch`
/// is the test that guards it. Showing the forgery the issue describes needs a
/// modified prover.
test prop_plonk_rejects_extra_inputs(
  extra via fuzz.list_between(nonzero_scalar(), 1, 5),
) {
  !plonk_verifies(
    test_plonk_proof_affine,
    list.concat(test_plonk_pub_inputs, extra),
  )
}

/// ADAOcommunity/zk#13: fewer inputs than `n_public` are rejected. As with the
/// test above, an honest proof fails here anyway, with or without the check.
test plonk_rejects_missing_input() {
  and {
    !plonk_verifies(test_plonk_proof_affine, [63]),
    !plonk_verifies(test_plonk_proof_affine, []),
  }
}

/// ADAOcommunity/zk#13: a key whose `n_public` differs from the number of
/// inputs is rejected, while the generators, inputs and proof stay valid. Only
/// the count check reads `n_public`, so this fails if that check is removed.
test plonk_rejects_n_public_mismatch() {
  let preinputs = prepare_affine_vkey(test_plonk_vkey_affine)
  let prepared =
    plonk_prepare_proof(
      preinputs,
      test_plonk_pub_inputs,
      prepare_affine_proof(test_plonk_proof_affine),
    )
  let verifies_with =
    fn(n) {
      verify_plonk(
        preinputs: PreparedPlonkPreInputs { ..preinputs, n_public: n },
        pub_inputs: test_plonk_pub_inputs,
        proof: prepared,
      )
    }
  and {
    verifies_with(test_plonk_vkey_affine.n_public),
    !verifies_with(1),
    !verifies_with(3),
  }
}

/// ADAOcommunity/zk#14: the proof must carry exactly one Lagrange inverse per
/// generator. Appending a junk inverse used to verify, since the check paired
/// the lists with `map2` and ignored the surplus; dropping one is rejected too.
test prop_plonk_rejects_wrong_inverse_count(
  (append, extra) via fuzz.tuple(fuzz.bool(), nonzero_scalar()),
) {
  let preinputs = prepare_affine_vkey(test_plonk_vkey_affine)
  let prepared =
    plonk_prepare_proof(
      preinputs,
      test_plonk_pub_inputs,
      prepare_affine_proof(test_plonk_proof_affine),
    )
  let inverses =
    if append {
      list.concat(prepared.lagrange_inverses, [scalar.from_int(extra)])
    } else {
      list.drop(prepared.lagrange_inverses, 1)
    }
  !verify_plonk(
    preinputs: preinputs,
    pub_inputs: test_plonk_pub_inputs,
    proof: PreparedPlonkProof { ..prepared, lagrange_inverses: inverses },
  )
}

/// ADAOcommunity/zk#14: an empty inverse list returns `False` rather than an
/// error, although the verifier would otherwise fail taking the first Lagrange
/// term.
test plonk_rejects_empty_inverse_list() {
  let preinputs = prepare_affine_vkey(test_plonk_vkey_affine)
  let prepared =
    plonk_prepare_proof(
      preinputs,
      test_plonk_pub_inputs,
      prepare_affine_proof(test_plonk_proof_affine),
    )
  !verify_plonk(
    preinputs: preinputs,
    pub_inputs: test_plonk_pub_inputs,
    proof: PreparedPlonkProof { ..prepared, lagrange_inverses: [] },
  )
}

/// ADAOcommunity/zk#19: one generator per public input, and never fewer than
/// one, since the permutation check always uses the first Lagrange term.
test plonk_generators_match_n_public() {
  let count =
    fn(n) {
      list.length(
        prepare_affine_vkey(
          AffineVerificationKey { ..test_plonk_vkey_affine, n_public: n },
        ).generators,
      )
    }
  and {
    count(test_plonk_vkey_affine.n_public) == test_plonk_vkey_affine.n_public,
    count(0) == 1,
    count(1) == 1,
    count(5) == 5,
  }
}
