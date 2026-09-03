//// @hidden
//// Tests for G1 message augmentation implementation

use bls/g1/aug as aug
use bls/tests/utils

/// Augmented mode prevents rogue-key attacks because each participant signs:
/// -   `H(pk || message)`
///
/// Meaning the public key is cryptographically bound to the signature.
///
/// Even if an attacker constructs a rogue public key, the forged aggregation
/// fails because the attacker cannot produce signatures corresponding to the
/// honest participants' `(pk || message)` inputs.
test g1_aug_rogue_key_attack_fails() {
  // Verification must fail because Aug binds pk into the message
  // Check lib/bls/utils.ak for the rogue key construction method.
  !aug.aggregate_verify(
    [utils.pk1, utils.pk2, utils.rogue_pk],
    [utils.message, utils.message, utils.message],
    utils.sig_fake,
  )
}

/// Basic successful aggregation in AUG mode
test g1_aug_aggregate_three_party_success() {
  let sk1 = utils.sk1
  let sk2 = utils.sk2
  let sk3 = utils.sk3

  let pk1 = utils.pk1
  let pk2 = utils.pk2
  let pk3 = utils.pk3

  let message = utils.message

  let sig1 = aug.sign(sk1, message)
  let sig2 = aug.sign(sk2, message)
  let sig3 = aug.sign(sk3, message)

  let sig_aggr = aug.aggregate([sig1, sig2, sig3])

  expect
    aug.aggregate_verify([pk1, pk2, pk3], [message, message, message], sig_aggr)
}

/// Aggregation must fail if messages differ
/// Even though AUG binds pk into hash, each message must still match.
test g1_aug_aggregate_distinct_messages_fails() fail {
  let msg1 = utils.message
  let msg2 = utils.other_message

  let sig1 = aug.sign(utils.sk1, msg1)
  let sig2 = aug.sign(utils.sk2, msg2)

  let sig_aggr = aug.aggregate([sig1, sig2])

  aug.aggregate_verify([utils.pk1, utils.pk2], [msg1, msg1], sig_aggr)
}

/// Rogue key substitution must fail even with valid signatures
test g1_aug_rogue_key_substitution_fails() {
  let message = utils.message

  let sig1 = aug.sign(utils.sk1, message)
  let sig2 = aug.sign(utils.sk2, message)

  let sig_aggr = aug.aggregate([sig1, sig2])

  // attacker swaps pk2 with rogue_pk
  !aug.aggregate_verify(
    [utils.pk1, utils.rogue_pk],
    [message, message],
    sig_aggr,
  )
}

/// Duplicate public key must not validate unless signatures match multiplicity
test g1_aug_duplicate_public_key_fails() {
  let message = utils.message

  let sig1 = aug.sign(utils.sk1, message)

  let sig_aggr = aug.aggregate([sig1])

  // same pk listed twice but only one signature aggregated
  !aug.aggregate_verify([utils.pk1, utils.pk1], [message, message], sig_aggr)
}

/// Subset aggregation works correctly
test g1_aug_subset_aggregate_success() {
  let message = utils.message

  let sig1 = aug.sign(utils.sk1, message)
  let sig3 = aug.sign(utils.sk3, message)

  let sig_aggr = aug.aggregate([sig1, sig3])

  expect
    aug.aggregate_verify([utils.pk1, utils.pk3], [message, message], sig_aggr)
}

/// Aggregate of single signature must equal normal verification
test g1_g2_aug_single_equals_normal_verify_success() {
  let message = utils.message

  let sig = aug.sign(utils.sk1, message)

  let sig_aggr = aug.aggregate([sig])

  expect aug.aggregate_verify([utils.pk1], [message], sig_aggr)
}
