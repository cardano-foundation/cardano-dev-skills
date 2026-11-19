use cardano/transaction.{Transaction, OutputReference}
use nova/types.{CircuitParams, FinalInstance, PredicatePolicy, SlimProof}
use nova/verifier.{verify_predicate_gate}

/// Selective-disclosure Predicate Gate.
///
/// A **reusable** spending validator: one address serves many gates because the
/// gate's policy (issuer pku/pkv, approved-country Merkle root, current_year)
/// is carried in the **datum**, not baked into the script.
///
/// Datum:    `Option<(CircuitParams, PredicatePolicy)>` — the expected step
///           circuit shape and the gate's policy constants.
/// Redeemer: `SlimProof` — the Nova slim (sumcheck) proof.
///
/// The validator succeeds iff the sumcheck proof is sound *and* it commits to
/// the circuit params *and* its public state equals
///   [issuer_pk_u, issuer_pk_v, current_year, country_root, eligible=1].
/// The credential fields (dob_year, country, signature, Merkle path) are hidden
/// inside the folded witness, so only *eligibility* is revealed on-chain.
validator predicate_gate {
  spend(
    datum: Option<(CircuitParams, PredicatePolicy)>,
    redeemer: SlimProof,
    _utxo: OutputReference,
    _self: Transaction,
  ) {
    when datum is {
      Some((params, policy)) -> verify_predicate_gate(redeemer, params, policy)
      None -> False
    }
  }
}

// ── Tests ──────────────────────────────────────────────────────────────────

/// Composite Predicate step-circuit shape (depth 2, stateless chain).
fn test_params() -> CircuitParams {
  CircuitParams { n_wires: 10463, n_constraints: 10461, n_pub_out: 5, n_pub_in: 5 }
}

fn policy() -> PredicatePolicy {
  PredicatePolicy {
    issuer_pk_u: 8624976883358443217689591740025020453161646046357019163238469549099359937631,
    issuer_pk_v: 34281186074026239166420402151535040043368197729731220730774434008950987285361,
    current_year: 2026,
    country_root: 16218807974226780999455818520759585013751930075124224204562176671238406323855,
  }
}

/// A valid one-round sumcheck proof whose public state commits to the policy
/// and an arbitrary `eligible` flag (i.e. `x == [issuer_u, issuer_v, year, root, eligible, ...]`).
fn valid_proof_for(p: PredicatePolicy, year: Int, eligible: Int) -> SlimProof {
  SlimProof {
    circuit_params: test_params(),
    final_instance: FinalInstance {
      x: [
        p.issuer_pk_u, p.issuer_pk_v, year, p.country_root, eligible,
        p.issuer_pk_u, p.issuer_pk_v, year, p.country_root, eligible,
      ],
      u: 1,
      w_commit: #"",
      e_commit: #"",
    },
    sumcheck_polys: [[0, 0]],
    sumcheck_claims: [0, 0],
    r_challenges: [0],
    claimed_product_at_r: 0,
    w_commit_hash: #"",
    e_commit_hash: #"",
  }
}

test gate_accepts_eligible_proof_for_policy() {
  let p = policy()
  verify_predicate_gate(valid_proof_for(p, 2026, 1), test_params(), p)
}

test gate_rejects_ineligible_proof() {
  let p = policy()
  !verify_predicate_gate(valid_proof_for(p, 2026, 0), test_params(), p)
}

test gate_rejects_wrong_year() {
  let p = policy()
  !verify_predicate_gate(valid_proof_for(p, 2025, 1), test_params(), p)
}

test gate_rejects_wrong_issuer_u() {
  let p = policy()
  let p2 = PredicatePolicy {
    issuer_pk_u: p.issuer_pk_u + 1,
    issuer_pk_v: p.issuer_pk_v,
    current_year: p.current_year,
    country_root: p.country_root,
  }
  !verify_predicate_gate(valid_proof_for(p, 2026, 1), test_params(), p2)
}

test gate_rejects_wrong_root() {
  let p = policy()
  let p2 = PredicatePolicy {
    issuer_pk_u: p.issuer_pk_u,
    issuer_pk_v: p.issuer_pk_v,
    current_year: p.current_year,
    country_root: p.country_root + 1,
  }
  !verify_predicate_gate(valid_proof_for(p, 2026, 1), test_params(), p2)
}

test gate_rejects_wrong_circuit_params() {
  let p = policy()
  let bad_params = CircuitParams { n_wires: 1, n_constraints: 1, n_pub_out: 1, n_pub_in: 1 }
  !verify_predicate_gate(valid_proof_for(p, 2026, 1), bad_params, p)
}
