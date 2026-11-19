use aiken/collection/list
use bls/hash.{expand_message_xmd, hkdf_expand, hkdf_extract}
use bls/tests/data/hkdf_vectors.{hkdf_expand_vectors, hkdf_extract_vectors}
use bls/tests/data/xmd_vectors.{dst, xmd_sha256_vectors}

test golden_hkdf_expand_vectors() {
  list.all(
    hkdf_expand_vectors,
    fn((prk, ikm, length, expected)) {
      let result = hkdf_expand(prk, ikm, length)
      result == expected
    },
  )
}

test golden_hkdf_extract_vectors() {
  list.all(
    hkdf_extract_vectors,
    fn((salt, ikm, expected)) {
      let result = hkdf_extract(salt, ikm)
      result == expected
    },
  )
}

test golden_test_expand_message_xmd_sha256_vectors() {
  //msg, len_in_bytes, uniform_bytes)
  list.all(
    xmd_sha256_vectors,
    fn((msg, len, expected)) {
      let result = expand_message_xmd(msg, dst, len)
      result == expected
    },
  )
}
