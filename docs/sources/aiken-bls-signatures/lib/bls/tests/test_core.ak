use aiken/builtin
use bls/core.{key_gen}
use bls/g1/core as g1

/// Test vector from algorand's reference implementation:
/// https://github.com/algorand/bls_sigs_ref/blob/b499fdc44b303e681dd9f5dd8f889398da708b59/rust-impl/src/test.rs#L27
///
test core_key_gen() {
  let message = "hello world (it's a secret!)"

  let sk = key_gen(message, "")

  //let sk_bytes = bytearray.from_int_big_endian(sk, 32)
  let expected =
    #"0e0db52716a4a2377628c92366acec81817115ccf9b77ad7d8aa1dc5c40d91d4"
  sk == expected
}

const private_key =
  #"000000000000000000000000000000000000000000000000000000000000002a"

test key_validate_success() {
  // Valid case: public key derived from private key 42
  let valid_pubkey = g1.sk_to_pk(private_key)

  //let p = 
  expect _p = g1.key_validate(valid_pubkey)
}

test key_validate_invalid_pubkey_fail() fail {
  // Invalid case: 48 bytes of 0x11
  let invalid_pubkey = builtin.replicate_byte(48, 0x11)
  expect _p = g1.key_validate(invalid_pubkey)
}
