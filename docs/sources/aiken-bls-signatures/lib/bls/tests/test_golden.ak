//// 
//// Golden tests
//// 
//// Test vectors downloaded from [BLS12-381 Github repository](https://github.com/AntelopeIO/bls12-381/blob/6b718d127a2b6095593a85622b4e3f85c3fbbcf6/test/test_vectors.inc#L1)
////

use aiken/collection/list.{at}
use aiken/fuzz.{int_between}
use aiken/primitive/string.{to_bytearray}
use bls/api.{Basic}
use bls/g1/core.{core_sign, core_verify, sk_to_pk}
use bls/tests/data/g1_vectors as tv

test golden_sk_to_pk(n via int_between(0, 102)) {
  expect Some(pk) = at(tv.pubs(), n)
  expect Some(sk) = at(tv.privs(), n)

  let pkt1 = sk_to_pk(sk)
  pkt1 == pk
}

test golden_sign(n via int_between(0, 102)) {
  expect Some(sk) = at(tv.privs(), n)
  expect Some(msg) = at(tv.msgs(), n)
  expect Some(sig) = at(tv.sigs(), n)

  let sigt1 = core_sign(sk, to_bytearray(msg), Basic)
  sigt1 == sig
}

test golden_verify(n via int_between(0, 102)) {
  expect Some(pk) = at(tv.pubs(), n)
  expect Some(msg) = at(tv.msgs(), n)
  expect Some(sig) = at(tv.sigs(), n)

  core_verify(pk, to_bytearray(msg), sig, Basic)
}
