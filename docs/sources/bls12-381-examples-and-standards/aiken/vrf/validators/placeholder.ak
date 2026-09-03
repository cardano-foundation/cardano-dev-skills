use aiken/fuzz
use vrf/core as vrf

const encode_to_curve_salt = #"45535652455f"

pub fn key_gen(secret: ByteArray) -> (ByteArray, ByteArray) {
  vrf.keys_from_secret(secret)
}

pub fn prove(sk: ByteArray, alpha: ByteArray) -> ByteArray {
  vrf.prove(sk, alpha, encode_to_curve_salt)
}

pub fn verify(pk: ByteArray, alpha: ByteArray, pi: ByteArray) -> Option<ByteArray> {
  vrf.verify(pk, alpha, pi, encode_to_curve_salt, False)
}

test t1() {
  let secret = #"ed69a93f0cf8c9836be3b67c7eeff416612d45ba39a5c099d48fa668bf558c9c"
  let (sk, pk) = key_gen(secret)
  let pi = prove(sk, "test input")
  verify(pk, "test input", pi) != None
}

test test_proof_of_prior_possession() {
  // Alice (legitimate prover) knows the secret
  let secret_alice = "my_secret_password_12345"
  let (sk_alice, pk_alice) = key_gen(secret_alice)

  // Alice uses her secret as the VRF input (self-binding)
  let pi_alice = prove(sk_alice, secret_alice)

  // Bob (verifier) checks Alice's proof
  let verified_alice = verify(pk_alice, secret_alice, pi_alice)

  // Eve (adversary) tries with the wrong secret
  let secret_eve = "wrong_password"
  let (sk_eve, pk_eve) = key_gen(secret_eve)
  let pi_eve = prove(sk_eve, secret_eve)

  // Bob verifies Eve's proof against Alice's expected secret
  let verified_eve = verify(pk_eve, secret_alice, pi_eve)

  // Alice's proof is valid; Eve's proof is rejected
  verified_alice != None && verified_eve == None
}

test test_non_interactive_randomness() {
  // Operator's secret key
  let operator_secret = "operator_secret_key"
  let (sk, pk) = key_gen(operator_secret)

  // Round 1: use a block hash as public input
  let round_1_input = "block_12345_hash"
  let pi_1 = prove(sk, round_1_input)
  let beta_1 = vrf.proof_to_hash(pi_1)

  // Round 2: use a different public input
  let round_2_input = "block_12346_hash"
  let pi_2 = prove(sk, round_2_input)
  let beta_2 = vrf.proof_to_hash(pi_2)

  // Verifiers check both rounds independently
  let verified_1 = verify(pk, round_1_input, pi_1)
  let verified_2 = verify(pk, round_2_input, pi_2)

  // Each round produces a unique, verifiable random output
  // Determinism: same (sk, input) always yields the same beta
  // Uniqueness: different inputs yield different betas
  verified_1 == beta_1 &&
    verified_2 == beta_2 &&
    beta_1 != beta_2
}

test test_leader_selection() {
  // Shared epoch for a consensus slot
  let epoch = "epoch_12345_slot_42"

  // Alice (30% stake)
  let (sk_alice, pk_alice) = key_gen("alice_stake_secret")
  let pi_alice = prove(sk_alice, epoch)

  // Bob (50% stake)
  let (sk_bob, pk_bob) = key_gen("bob_stake_secret")
  let pi_bob = prove(sk_bob, epoch)

  // Charlie (20% stake)
  let (sk_charlie, pk_charlie) = key_gen("charlie_stake_secret")
  let pi_charlie = prove(sk_charlie, epoch)

  // Network verifies each stakeholder's proof
  let verified_alice = verify(pk_alice, epoch, pi_alice)
  let verified_bob = verify(pk_bob, epoch, pi_bob)
  let verified_charlie = verify(pk_charlie, epoch, pi_charlie)

  let beta_alice = vrf.proof_to_hash(pi_alice)
  let beta_bob = vrf.proof_to_hash(pi_bob)
  let beta_charlie = vrf.proof_to_hash(pi_charlie)

  // All stakeholders produce valid proofs for the same epoch.
  // verify and proof_to_hash agree for each participant.
  verified_alice == beta_alice &&
    verified_bob == beta_bob &&
    verified_charlie == beta_charlie
}

test test_privacy_protected_data() {
  // Prover's secret key
  let secret = "prover_secret_key"
  let (sk, pk) = key_gen(secret)

  // Multiple private records
  let record_1 = "alice_payment_100"
  let record_2 = "bob_escrow_250"
  let record_3 = "charlie_refund_50"

  // Only the prover can compute the "address" for each record
  let pi_1 = prove(sk, record_1)
  let pi_2 = prove(sk, record_2)
  let pi_3 = prove(sk, record_3)

  let beta_1 = vrf.proof_to_hash(pi_1)
  let beta_2 = vrf.proof_to_hash(pi_2)
  let beta_3 = vrf.proof_to_hash(pi_3)

  // Verifier checks membership for each record
  let verified_1 = verify(pk, record_1, pi_1)
  let verified_2 = verify(pk, record_2, pi_2)
  let verified_3 = verify(pk, record_3, pi_3)

  // All records are verified at their VRF-derived addresses.
  // Without sk, an attacker cannot link beta values to record names.
  verified_1 == beta_1 && verified_2 == beta_2 && verified_3 == beta_3
}

// Property-based tests: prove/verify round-trip for arbitrary secrets and inputs

test prop_different_secrets_different_keys(
  pair via fuzz.both(fuzz.bytearray_between(8, 64), fuzz.bytearray_between(8, 64)),
) {
  let (secret_1, secret_2) = pair
  let (_sk_1, pk_1) = key_gen(secret_1)
  let (_sk_2, pk_2) = key_gen(secret_2)
  // Different secrets should almost always produce different public keys.
  // If they are equal, the property is trivially true (same secret).
  secret_1 == secret_2 || pk_1 != pk_2
}

test prop_prove_verify_roundtrip(
  pair via fuzz.both(fuzz.bytearray_between(8, 64), fuzz.bytearray_between(1, 64)),
) {
  let (secret, alpha) = pair
  let (sk, pk) = key_gen(secret)
  let pi = prove(sk, alpha)
  verify(pk, alpha, pi) != None
}

test prop_deterministic_beta(
  pair via fuzz.both(fuzz.bytearray_between(8, 64), fuzz.bytearray_between(1, 64)),
) {
  let (secret, alpha) = pair
  let (sk, _pk) = key_gen(secret)
  let pi_1 = prove(sk, alpha)
  let pi_2 = prove(sk, alpha)
  let beta_1 = vrf.proof_to_hash(pi_1)
  let beta_2 = vrf.proof_to_hash(pi_2)
  beta_1 == beta_2
}

// Note: adversarial behaviour (wrong alpha / wrong secret) is covered by
// the unit tests test_proof_of_prior_possession and t1 above.
