use cardano/transaction.{Transaction, OutputReference}
use nova/types.{CircuitParams, FinalInstance, SlimProof}
use nova/verifier.{verify_slim, verify_slim_fs}

/// Plutus V3 spending validator: verifies a Nova slim sumcheck proof with
/// on-chain Fiat-Shamir challenge re-derivation.
///
/// Datum:    `Option<CircuitParams>` — the expected step-circuit dimensions.
/// Redeemer: `SlimProof` — the folded+compressed Nova proof.
///
/// The validator succeeds iff the datum declares the circuit params and the
/// sumcheck protocol accepts the proof (challenges re-derived on-chain from
/// the transcript, so attacker-supplied `r_challenges` cannot be forged).
validator nova_slim_verify {
  spend(datum: Option<CircuitParams>, redeemer: SlimProof, _utxo: OutputReference, _self: Transaction) {
    when datum is {
      Some(params) -> redeemer.circuit_params == params && verify_slim_fs(redeemer)
      None -> False
    }
  }
}

// ── Tests ──────────────────────────────────────────────────────────────────

test test_fs_single_round_zero() {
  let proof = SlimProof {
    circuit_params: CircuitParams { n_wires: 4, n_constraints: 2, n_pub_out: 1, n_pub_in: 1 },
    final_instance: FinalInstance { x: [0], u: 1, w_commit: #"", e_commit: #"" },
    sumcheck_polys: [[0, 0]],
    sumcheck_claims: [0, 0],
    r_challenges: [0],
    claimed_product_at_r: 0,
    w_commit_hash: #"",
    e_commit_hash: #"",
  }
  verify_slim_fs(proof)
}

test test_fs_two_rounds_zero() {
  let proof = SlimProof {
    circuit_params: CircuitParams { n_wires: 8, n_constraints: 4, n_pub_out: 1, n_pub_in: 1 },
    final_instance: FinalInstance { x: [0], u: 1, w_commit: #"", e_commit: #"" },
    sumcheck_polys: [[0, 0], [0, 0]],
    sumcheck_claims: [0, 0, 0],
    r_challenges: [0, 0],
    claimed_product_at_r: 0,
    w_commit_hash: #"",
    e_commit_hash: #"",
  }
  verify_slim_fs(proof)
}

test test_fs_nonzero_poly() {
  // Exercises the sumcheck round equation with non-zero coefficients on the
  // pre-computed-challenge path (`verify_slim`): poly f(x) = 3 + 7x, so the
  // boolean-hypercube sum is f(0) + f(1) = 3 + 10 = 13, and with r_challenge
  // ri = 0 the next claim is f(0) = 3.
  let proof = SlimProof {
    circuit_params: CircuitParams { n_wires: 4, n_constraints: 2, n_pub_out: 1, n_pub_in: 1 },
    final_instance: FinalInstance { x: [0], u: 1, w_commit: #"", e_commit: #"" },
    sumcheck_polys: [[3, 7]],
    sumcheck_claims: [13, 3],
    r_challenges: [0],
    claimed_product_at_r: 3,
    w_commit_hash: #"",
    e_commit_hash: #"",
  }
  verify_slim(proof)
}

test test_fs_wrong_initial_sum() {
  let proof = SlimProof {
    circuit_params: CircuitParams { n_wires: 4, n_constraints: 2, n_pub_out: 1, n_pub_in: 1 },
    final_instance: FinalInstance { x: [0], u: 1, w_commit: #"", e_commit: #"" },
    sumcheck_polys: [[0, 0]],
    sumcheck_claims: [1, 0],
    r_challenges: [0],
    claimed_product_at_r: 0,
    w_commit_hash: #"",
    e_commit_hash: #"",
  }
  verify_slim_fs(proof) == False
}

test test_fs_wrong_final_claim() {
  let proof = SlimProof {
    circuit_params: CircuitParams { n_wires: 4, n_constraints: 2, n_pub_out: 1, n_pub_in: 1 },
    final_instance: FinalInstance { x: [0], u: 1, w_commit: #"", e_commit: #"" },
    sumcheck_polys: [[0, 0]],
    sumcheck_claims: [0, 1],
    r_challenges: [0],
    claimed_product_at_r: 0,
    w_commit_hash: #"",
    e_commit_hash: #"",
  }
  verify_slim_fs(proof) == False
}

test test_fs_mismatched_counts() {
  let proof = SlimProof {
    circuit_params: CircuitParams { n_wires: 4, n_constraints: 2, n_pub_out: 1, n_pub_in: 1 },
    final_instance: FinalInstance { x: [0], u: 1, w_commit: #"", e_commit: #"" },
    sumcheck_polys: [[0, 0]],
    sumcheck_claims: [0],
    r_challenges: [0],
    claimed_product_at_r: 0,
    w_commit_hash: #"",
    e_commit_hash: #"",
  }
  verify_slim_fs(proof) == False
}

test test_fs_cko_real_values() {
  let proof = SlimProof {
    circuit_params: CircuitParams {
      n_wires: 7658,
      n_constraints: 7724,
      n_pub_out: 24,
      n_pub_in: 24,
    },
    final_instance: FinalInstance {
      x: [0, 0, 0, 0],
      u: 1,
      w_commit: #"",
      e_commit: #"",
    },
    sumcheck_polys: [[0, 0], [0, 0]],
    sumcheck_claims: [0, 0, 0],
    r_challenges: [0, 0],
    claimed_product_at_r: 0,
    w_commit_hash: #"",
    e_commit_hash: #"",
  }
  verify_slim_fs(proof)
}
