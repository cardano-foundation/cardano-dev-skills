use groth16/verifier as groth16

/// Convenience wrapper that verifies the hard-coded proof with the
/// hard-coded public inputs and hard-coded verification key.
pub fn verify_hardcoded() -> Bool {
  let proof = groth16.hardcoded_proof()
  let vk = groth16.hardcoded_verification_key()
  groth16.verify(proof, [1, 48], vk)
}

// ---------------------------------------------------------------------------
// End-to-end validator-level tests
// ---------------------------------------------------------------------------

test validator_accepts_valid_proof() {
  verify_hardcoded()
}

test validator_rejects_wrong_public_input() {
  let proof = groth16.hardcoded_proof()
  let vk = groth16.hardcoded_verification_key()
  !groth16.verify(proof, [1, 47], vk)
}

test validator_rejects_tampered_a() {
  let proof = groth16.hardcoded_proof()
  let vk = groth16.hardcoded_verification_key()
  // Replace A with the G1 generator: valid point, wrong proof.
  let bad = groth16.Proof {
    a: #"97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb",
    b: proof.b,
    c: proof.c,
  }
  !groth16.verify(bad, [1, 48], vk)
}

test validator_rejects_tampered_b() {
  let proof = groth16.hardcoded_proof()
  let vk = groth16.hardcoded_verification_key()
  // Replace B with the G2 generator: valid point, wrong proof.
  let bad = groth16.Proof {
    a: proof.a,
    b: #"93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8",
    c: proof.c,
  }
  !groth16.verify(bad, [1, 48], vk)
}

test validator_rejects_tampered_c() {
  let proof = groth16.hardcoded_proof()
  let vk = groth16.hardcoded_verification_key()
  // Replace C with the G1 generator: valid point, wrong proof.
  let bad = groth16.Proof {
    a: proof.a,
    b: proof.b,
    c: #"97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb",
  }
  !groth16.verify(bad, [1, 48], vk)
}
