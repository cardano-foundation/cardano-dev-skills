//// @hidden
//// Tests for G2 proof of possession implementation
////
//// Rogue attack works because the attacker can freely choose a derived public key.
//// PoP forces every registered key to prove:
//// - `that I know the private key for THIS exact public key.`
////
//// The attacker cannot produce a PoP for the forged rogue_pk, so the key never enters
//// the aggregation set. The user must ensure that only the registered public keys are
//// used.

use aiken/collection/list
use bls/g1/pop as pop
use bls/tests/utils.{
  message, other_message, pk1, pk2, pk3, rogue_pk, sk1, sk2, sk3,
}

// Registered PoPs
const pop1 = pop.pop_prove(utils.sk1)

const pop2 = pop.pop_prove(utils.sk2)

const pop3 = pop.pop_prove(utils.sk3)

/// Valid registered pops
test g1_pop_valid_pop_verify_success() {
  // Honest registered PoPs
  expect pop.pop_verify(pk1, pop1)
  expect pop.pop_verify(pk2, pop2)
  expect pop.pop_verify(pk3, pop3)
}

/// Invalid PoP must always reject key registration
test g1_pop_invalid_pop_verify_fails() {
  // PoP verification fails → registration must be rejected somewhere in the code.
  // Check lib/bls/ak for the rogue key construction method.
  expect False = pop.pop_verify(rogue_pk, pop1)

  // attacker tries to attach PoP1 to pk2
  expect False = pop.pop_verify(pk2, pop1)
}

test g1_pop_aggregate_three_party_success() {
  expect pop.pop_verify(pk1, pop1)
  expect pop.pop_verify(pk2, pop2)
  expect pop.pop_verify(pk3, pop3)

  // now we are sure sks are corresposding to respective pks
  let sig1 = pop.sign(sk1, message)
  let sig2 = pop.sign(sk2, message)
  let sig3 = pop.sign(sk3, message)

  let sig_aggr = pop.aggregate([sig1, sig2, sig3])

  let messages = list.repeat(message, 3)
  // full signature aggregation works even for same messages, 
  // because valid pks have already verified.
  expect pop.aggregate_verify([pk1, pk2, pk3], messages, sig_aggr)
}

/// Aggregation must fail if one PoP was never verified (unregistered key)
test g1_pop_unregistered_key_fails() {
  let pop1 = pop.pop_prove(sk1)
  let pop2 = pop.pop_prove(sk2)

  // register only pk1
  expect pop.pop_verify(pk1, pop1)
  expect pop.pop_verify(pk2, pop2)

  let sig1 = pop.sign(sk1, message)
  let sig2 = pop.sign(sk2, message)

  let sig_aggr = pop.aggregate([sig1, sig2])

  // pk2 is replaced with rogue_pk (simulating non registration)
  !pop.aggregate_verify([pk1, rogue_pk], [message, message], sig_aggr)
}

/// Aggregation must fail if messages differ
test g1_pop_without_distinct_message_protection_fails() {
  let pop1 = pop.pop_prove(sk1)
  let pop2 = pop.pop_prove(sk2)

  expect pop.pop_verify(pk1, pop1)
  expect pop.pop_verify(pk2, pop2)

  let sig1 = pop.sign(sk1, message)
  let sig2 = pop.sign(sk2, other_message)

  let sig_aggr = pop.aggregate([sig1, sig2])

  let wrong_msgs = list.repeat(message, 2)

  // wrong message order causes failure
  !pop.aggregate_verify([pk1, pk2], wrong_msgs, sig_aggr)
}

/// Subset aggregation remains valid (partial participation)
test g1_pop_subset_aggregate_success() {
  expect pop.pop_verify(pk1, pop1)
  expect pop.pop_verify(pk2, pop2)
  expect pop.pop_verify(pk3, pop3)

  let message = message

  let sig1 = pop.sign(sk1, message)
  let sig3 = pop.sign(sk3, message)

  let sig_aggr = pop.aggregate([sig1, sig3])

  expect pop.aggregate_verify([pk1, pk3], [message, message], sig_aggr)
}
