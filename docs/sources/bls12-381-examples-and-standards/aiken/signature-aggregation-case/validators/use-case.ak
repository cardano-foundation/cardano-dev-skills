use bls/api
use bls/g1/aug as aug_bls
use bls/g1/basic as basic_bls
use bls/g1/core as core_bls
use bls/core.{key_gen}
use bls/g1/pop as pop_bls
use bls/tests/utils.{construct_rogue_key}

test test_basic_bls () {
  let secret = #"ed69a93f0cf8c9836be3b67c7eeff416612d45ba39a5c099d48fa668bf558c9c"
  let sk = key_gen(secret, "")
  let pk = basic_bls.sk_to_pk(sk)
  
  let message = "Hello, Aiken!"

  let signature = basic_bls.sign(sk, message)

  basic_bls.verify(pk, message, signature)
}

test three_party_signature_aggregation_basic_bls () {

  let (sk1, pk1, sk2, pk2, sk3, pk3) = get_three_party_keys()

  // if each message is unique then the 'aggregate_signatures' with 'aggregate_verify'
  // is safe, but if this condition is not satisfied then it is not
  // as demonstrated in 'three_party_unsafe_signature_aggregation_bls'
  let message1 = "Hello, Aiken from party 1!"
  let message2 = "Hello, Aiken from party 2!"
  let message3 = "Hello, Aiken from party 3!"

  let sig1 = basic_bls.sign(sk1, message1)
  let sig2 = basic_bls.sign(sk2, message2)
  let sig3 = basic_bls.sign(sk3, message3)

  let sig_aggr = basic_bls.aggregate([sig1, sig2, sig3])

  // full signature aggregation
  let full_aggr_predicate = basic_bls.aggregate_verify([pk1,pk2,pk3], [message1,message2,message3], sig_aggr)

  // partial signature aggregation
  let sig13_aggr = basic_bls.aggregate([sig1, sig3])  
  full_aggr_predicate &&
  basic_bls.aggregate_verify([pk1,pk3], [message1,message3], sig13_aggr)
}

test three_party_rogue_signature_aggregation_basic_bls () {

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

  sigs_aggr_predicate &&
  !sigs_aggr_predicate_fails
}

test three_party_almost_safe_augmented_signature_aggregation_bls () {

  let (sk1, pk1, sk2, pk2, sk3, pk3) = get_three_party_keys()

  let message = "Hello, Aiken from all parties!"

  let sig1 = aug_bls.sign(sk1, message)
  let sig2 = aug_bls.sign(sk2, message)
  let sig3 = aug_bls.sign(sk3, message)

  let sig_aggr = aug_bls.aggregate([sig1, sig2, sig3])

  let rogue_pk3 = construct_rogue_key(pk1, pk2, pk3)

  // sig3 is not anymore enough to verify!
  let rogue_aggr_predicate_fails = aug_bls.aggregate_verify([pk1,pk2,rogue_pk3], [message,message,message], sig3)

  // full signature aggregation works
  let full_aggr_predicate = aug_bls.aggregate_verify([pk1,pk2,pk3], [message,message,message], sig_aggr)

  // partial signature aggregation works also
  let sig13_aggr = aug_bls.aggregate([sig1, sig3])
  let partial_aggr_predicate = aug_bls.aggregate_verify([pk1,pk3], [message,message], sig13_aggr)  

  // sig3 is still enough to verify when in public key aggregation case
  //let pk_aggr = aug_bls.aggregate([pk1,pk2,rogue_pk3])  
  //let rogue_aggr_pks_predicate_pass = aug_bls.aggregate_verify([pk_aggr], [message,message,message], sig3)

  !rogue_aggr_predicate_fails &&
  full_aggr_predicate &&
  partial_aggr_predicate
  //rogue_aggr_pks_predicate_pass
}

test three_party_safe_pop_signature_aggregation_bls () {
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

  // full signature aggregation SHOULD work but is not TO_DO
  let full_aggr_predicate = pop_bls.aggregate_verify([pk1,pk2,pk3], [message,message,message], sig_aggr)

  full_aggr_predicate 
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