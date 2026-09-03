use bls/api
use bls/g1/aug as aug_bls
use bls/g1/basic as basic_bls
use bls/g1/core as core_bls
use bls/g1/pop as pop_bls
use bls/core.{key_gen}
use bls/tests/utils.{construct_rogue_key}

use bls_extra/core as bls_extra_core

test two_party_signature_aggregation_with_two_msgs_basic_bls () {

  let (sk1, pk1, _pk2, _sk2,  sk3, pk3) = get_three_party_keys()

  // if each message is unique then the 'aggregate_signatures' with 'aggregate_verify'
  // is safe, public key aggregation only works for one participant
  let message1 = "Hello, Aiken from party 1!"
  let message3 = "Hello, Aiken from party 3!"

  let sig1 = basic_bls.sign(sk1, message1)
  let sig3 = basic_bls.sign(sk3, message3)

  //basic checks
  let sig1_aggr = basic_bls.aggregate([sig1])
  let pk1_aggr = bls_extra_core.aggregate_publickeys([pk1])
  let pubkey1_aggr_sig1_predicate = bls_extra_core.aggregate_publickey_verify(pk1_aggr, [message1], sig1, api.Basic)
  let pubkey1_aggr_sig1_aggr_predicate = bls_extra_core.aggregate_publickey_verify(pk1_aggr, [message1], sig1_aggr, api.Basic)

  let sig13_aggr = basic_bls.aggregate([sig1, sig3])
  let pk13_aggr = bls_extra_core.aggregate_publickeys([pk1, pk3])
  let pubkey13_aggr_sig13_predicate = basic_bls.aggregate_verify([pk1, pk3], [message1, message3], sig13_aggr)  
  let pubkey13_aggr_sig13_aggr_fail_predicate = bls_extra_core.aggregate_publickey_verify(pk13_aggr, [message1, message3], sig13_aggr, api.Basic)

  pubkey1_aggr_sig1_predicate &&
  pubkey1_aggr_sig1_aggr_predicate &&
  pubkey13_aggr_sig13_predicate &&
  !pubkey13_aggr_sig13_aggr_fail_predicate
}

test two_party_signature_aggregation_with_one_msg_basic_bls () {

  let (sk1, pk1, _pk2, _sk2,  sk3, pk3) = get_three_party_keys()

  // the same message then the 'aggregate_signatures' with 'aggregate_verify'
  // is not safe (hence it fails here), but public aggregation works 
  let message = "Hello, Aiken from party!"

  let sig1 = basic_bls.sign(sk1, message)
  let sig3 = basic_bls.sign(sk3, message)

  //basic checks
  let sig1_aggr = basic_bls.aggregate([sig1])
  let pk1_aggr = bls_extra_core.aggregate_publickeys([pk1])
  let pubkey1_aggr_sig1_predicate = bls_extra_core.aggregate_publickey_verify(pk1_aggr, [message], sig1, api.Basic)
  let pubkey1_aggr_sig1_aggr_predicate = bls_extra_core.aggregate_publickey_verify(pk1_aggr, [message], sig1_aggr, api.Basic)

  let sig13_aggr = basic_bls.aggregate([sig1, sig3])
  let pk13_aggr = bls_extra_core.aggregate_publickeys([pk1, pk3])
  let pubkey13_aggr_sig13_fail_predicate = basic_bls.aggregate_verify([pk1, pk3], [message, message], sig13_aggr)
  let pubkey13_aggr_sig13_aggr_predicate = bls_extra_core.aggregate_publickey_verify(pk13_aggr, [message], sig13_aggr, api.Basic)

  pubkey1_aggr_sig1_predicate &&
  pubkey1_aggr_sig1_aggr_predicate &&
  !pubkey13_aggr_sig13_fail_predicate &&
  pubkey13_aggr_sig13_aggr_predicate
}

test two_party_signature_aggregation_with_one_msg_aug_bls () {

  let (sk1, pk1, _pk2, _sk2,  sk3, pk3) = get_three_party_keys()

  // the same message then the 'aggregate_signatures' with 'aggregate_verify'
  // is safe here and public aggregation works 
  let message = "Hello, Aiken from party!"

  let sig1 = aug_bls.sign(sk1, message)
  let sig3 = aug_bls.sign(sk3, message)

  //basic checks
  let sig1_aggr = aug_bls.aggregate([sig1])
  let pk1_aggr = bls_extra_core.aggregate_publickeys([pk1])
  let pubkey1_aggr_sig1_predicate = bls_extra_core.aggregate_publickey_verify(pk1_aggr, [message], sig1, api.Aug)
  let pubkey1_aggr_sig1_aggr_predicate = bls_extra_core.aggregate_publickey_verify(pk1_aggr, [message], sig1_aggr, api.Aug)

  let sig13_aggr = aug_bls.aggregate([sig1, sig3])
  let pk13_aggr = bls_extra_core.aggregate_publickeys([pk1, pk3])
  let pubkey13_aggr_sig13_predicate = aug_bls.aggregate_verify([pk1, pk3], [message, message], sig13_aggr)
  // This cannot work because Aug mode with multiple signers requires individual pks for verification.
  // aggregate_publickey_verify uses pk_agg for hash (H(pk_agg || msg)), but signatures are over H(pk_i || msg).
  // These are only equal if pk1 = pk3. Mathematically: e(pk1+pk3, H((pk1+pk3)||msg)) != e(pk1, H(pk1||msg)) * e(pk3, H(pk3||msg))
  let pubkey13_aggr_sig13_aggr_predicate = bls_extra_core.aggregate_publickey_verify(pk13_aggr, [message], sig13_aggr, api.Aug)

  pubkey1_aggr_sig1_predicate &&
  pubkey1_aggr_sig1_aggr_predicate &&
  pubkey13_aggr_sig13_predicate &&
  !pubkey13_aggr_sig13_aggr_predicate
}

test three_party_signature_aggregation_with_one_msg_pop_bls () {

  let (sk1, pk1, sk2, pk2, sk3, pk3) = get_three_party_keys()

  // at registration
  let pop1 = pop_bls.pop_prove(sk1)
  let pop2 = pop_bls.pop_prove(sk2)
  let pop3 = pop_bls.pop_prove(sk3)

  expect pop_bls.pop_verify(pk1, pop1)
  expect pop_bls.pop_verify(pk2, pop2)
  expect pop_bls.pop_verify(pk3, pop3)

  let message ="Hello, Aiken from all parties!"

  // now we are sure sks are corresposding to respective pks
  let sig1 = pop_bls.sign(sk1, message)
  let sig2 = pop_bls.sign(sk2, message)
  let sig3 = pop_bls.sign(sk3, message)

  let sig_aggr = pop_bls.aggregate([sig1, sig2, sig3])
  let pk_aggr = bls_extra_core.aggregate_publickeys([pk1, pk2, pk3])

  let full_aggr_predicate = pop_bls.aggregate_verify([pk1,pk2,pk3], [message,message,message], sig_aggr)
  // For PoP mode, aggregate_publickey_verify with multiple signers cannot work.
  // aggregate_publickey_verify uses pk_agg for hash (H(pk_agg || msg)), but signatures are over H(pk_i || msg).
  // These are only equal if pk1 = pk2 = pk3. Mathematically: e(pk1+pk2+pk3, H((pk1+pk2+pk3)||msg)) != e(pk1, H(pk1||msg)) * e(pk2, H(pk2||msg)) * e(pk3, H(pk3||msg))
  // PoP requires individual pks for verification.
  let pk_aggr_sig_aggr_predicate = bls_extra_core.aggregate_publickey_verify(pk_aggr, [message, message, message], sig_aggr, api.Pop)

  full_aggr_predicate &&
  !pk_aggr_sig_aggr_predicate
}



test three_party_rogue_publickey_signature_aggregation_basic_bls () {

  let (_sk1, pk1, _sk2, pk2, sk3, pk3) = get_three_party_keys()
  
  // one creates rogue_pk
  let rogue_pk3 = construct_rogue_key(pk1, pk2, pk3)

  let message = "Hello, Aiken from party!"

  // Although all parties can produce signatures
  // let _sig1 = basic_bls.sign(sk1, message)
  // let _sig2 = basic_bls.sign(sk2, message)
  let sig3 = basic_bls.sign(sk3, message)

  // only sig3 is needed to verify! sig1 and sig2 could be omitted
  let sigs_aggr_predicate = core_bls.core_aggregate_verify([pk1,pk2,rogue_pk3], [message,message,message], sig3, api.Basic)

  // basic bls impl has now detection of if not all msgs are distinct
  let sigs_aggr_predicate_fails = basic_bls.aggregate_verify([pk1,pk2,rogue_pk3], [message,message,message], sig3)

  // the same detection is present when public key aggregation is used
  let pk_aggr = bls_extra_core.aggregate_publickeys([pk1,pk2,rogue_pk3])
  let pubkeys_aggr_predicate_fails = bls_extra_core.aggregate_publickey_verify(pk_aggr, [message,message,message], sig3, api.Basic)

  sigs_aggr_predicate &&
  !sigs_aggr_predicate_fails &&
  !pubkeys_aggr_predicate_fails
}

fn get_three_party_keys() -> (api.PrivateKey, api.PublicKey, api.PrivateKey, api.PublicKey, api.PrivateKey, api.PublicKey) {
  // party1
  let secret1 = #"ed69a93f0cf8c9836be3b67c7eeff416612d45ba39a5c099d48fa668bf558c9a"
  let sk1 = key_gen(secret1, "")  
  let pk1 = basic_bls.sk_to_pk(sk1)

  // party2
  let secret2 = #"ed69a93f0cf8c9836be3b67c7eeff416612d45ba39a5c099d48fa668bf558c9b"
  let sk2 = key_gen(secret2, "")    
  let pk2 = basic_bls.sk_to_pk(sk2)

  // party3
  let secret3 = #"ed69a93f0cf8c9836be3b67c7eeff416612d45ba39a5c099d48fa668bf558c9c"
  let sk3 = key_gen(secret3, "")    
  let pk3 = basic_bls.sk_to_pk(sk3)

  (sk1, pk1, sk2, pk2, sk3, pk3)
}