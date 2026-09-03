use aiken/fuzz
use aiken/primitive/bytearray
use kdf/keys.{gen_keys_hkdf, gen_keys_pbkdf2, pk_from_sk_bls12_381}

// -------------------------------------------------------------------
// PBKDF2 property tests
// -------------------------------------------------------------------

/// `gen_keys_pbkdf2` must be deterministic: same inputs always
/// produce the same key pair.
test prop_pbkdf2_deterministic(
  args via fuzz.both(
    fuzz.bytearray_between(1, 32),
    fuzz.bytearray_between(1, 32),
  ),
) {
  let (salt, ikm) = args
  let (sk1, pk1) = gen_keys_pbkdf2(salt, ikm)
  let (sk2, pk2) = gen_keys_pbkdf2(salt, ikm)
  sk1 == sk2 && pk1 == pk2
}

/// `gen_keys_pbkdf2` must produce a 32-byte private key and a
/// 48-byte compressed public key.
test prop_pbkdf2_key_lengths(
  args via fuzz.both(
    fuzz.bytearray_between(1, 32),
    fuzz.bytearray_between(1, 32),
  ),
) {
  let (salt, ikm) = args
  let (sk, pk) = gen_keys_pbkdf2(salt, ikm)
  bytearray.length(sk) == 32 && bytearray.length(pk) == 48
}

/// The public key returned by `gen_keys_pbkdf2` must match the public
/// key derived independently from the returned secret key.
test prop_pbkdf2_pk_consistent_with_sk(
  args via fuzz.both(
    fuzz.bytearray_between(1, 32),
    fuzz.bytearray_between(1, 32),
  ),
) {
  let (salt, ikm) = args
  let (sk, pk) = gen_keys_pbkdf2(salt, ikm)
  pk == pk_from_sk_bls12_381(sk)
}

// -------------------------------------------------------------------
// HKDF property tests
// -------------------------------------------------------------------

/// `gen_keys_hkdf` must be deterministic: same inputs always
/// produce the same key pair.
test prop_hkdf_deterministic(
  args via fuzz.both(
    fuzz.bytearray_between(1, 32),
    fuzz.bytearray_between(1, 32),
  ),
) {
  let (salt, ikm) = args
  let (sk1, pk1) = gen_keys_hkdf(salt, ikm)
  let (sk2, pk2) = gen_keys_hkdf(salt, ikm)
  sk1 == sk2 && pk1 == pk2
}

/// `gen_keys_hkdf` must produce a 32-byte private key and a
/// 48-byte compressed public key.
test prop_hkdf_key_lengths(
  args via fuzz.both(
    fuzz.bytearray_between(1, 32),
    fuzz.bytearray_between(1, 32),
  ),
) {
  let (salt, ikm) = args
  let (sk, pk) = gen_keys_hkdf(salt, ikm)
  bytearray.length(sk) == 32 && bytearray.length(pk) == 48
}

/// The public key returned by `gen_keys_hkdf` must match the public
/// key derived independently from the returned secret key.
test prop_hkdf_pk_consistent_with_sk(
  args via fuzz.both(
    fuzz.bytearray_between(1, 32),
    fuzz.bytearray_between(1, 32),
  ),
) {
  let (salt, ikm) = args
  let (sk, pk) = gen_keys_hkdf(salt, ikm)
  pk == pk_from_sk_bls12_381(sk)
}

// -------------------------------------------------------------------
// Unit tests (sanity checks with known inputs)
// -------------------------------------------------------------------

/// A simple sanity check for `gen_keys_pbkdf2`.
test gen_keys_pbkdf2_sanity() {
  let (sk, pk) = gen_keys_pbkdf2("salt", "ikm")
  bytearray.length(sk) == 32 && bytearray.length(pk) == 48
}

/// A simple sanity check for `gen_keys_hkdf`.
test gen_keys_hkdf_sanity() {
  let (sk, pk) = gen_keys_hkdf("salt", "ikm")
  bytearray.length(sk) == 32 && bytearray.length(pk) == 48
}
