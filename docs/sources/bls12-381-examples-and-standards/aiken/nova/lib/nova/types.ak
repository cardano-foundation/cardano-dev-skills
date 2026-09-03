/// Final folded NIFS instance from Nova IVC.
///
/// `x` is the IVC state (public inputs/outputs of the step circuit).
/// `u` is the slack scalar from the relaxed R1CS.
/// `w_commit` is the Pedersen commitment to the folded witness (compressed G1).
/// `e_commit` is the Pedersen commitment to the error vector (compressed G1).
pub type FinalInstance {
  x: List<Int>,
  u: Int,
  w_commit: ByteArray,
  e_commit: ByteArray,
}

/// Nova IVC circuit parameters.
pub type CircuitParams {
  n_wires: Int,
  n_constraints: Int,
  n_pub_out: Int,
  n_pub_in: Int,
}

/// A slim sumcheck compression proof (Implementation 10, slim variant).
///
/// Contains the folded NIFS instance, sumcheck round polynomials, Fiat-Shamir
/// challenges, and commitment hashes. The HashPC opening proofs are stripped
/// (verified off-chain as an audit trail).
pub type SlimProof {
  circuit_params: CircuitParams,
  final_instance: FinalInstance,
  /// Sumcheck round polynomials: `polys[i] = [f(0), f(1) - f(0)]`.
  sumcheck_polys: List<List<Int>>,
  /// `claims[0]` = initial claimed sum; `claims[1..=num_rounds]` = evaluations
  /// at each round's random challenge.
  sumcheck_claims: List<Int>,
  /// Fiat-Shamir challenges derived by the verifier during sumcheck.
  r_challenges: List<Int>,
  /// The final claimed product evaluation at the random point `r`.
  /// Must equal 0 for a valid proof.
  claimed_product_at_r: Int,
  /// BLAKE2b-256 hash of the committed witness Z (for off-chain audit).
  w_commit_hash: ByteArray,
  /// BLAKE2b-256 hash of the committed error E (for off-chain audit).
  e_commit_hash: ByteArray,
}

/// The on-chain policy of a selective-disclosure Predicate gate.
///
/// These are the scheme-constant public inputs that a valid predicate proof
/// must commit to (the public state carried in `final_instance.x[0..3]`):
///   x[0] = issuer_pk_u, x[1] = issuer_pk_v, x[2] = current_year,
///   x[3] = country_root, x[4] = eligible (= 1).
/// A gate script binds these via the datum, so one reusable script serves many
/// issuers / country sets / epochs without recompiling.
pub type PredicatePolicy {
  issuer_pk_u: Int,
  issuer_pk_v: Int,
  current_year: Int,
  country_root: Int,
}
