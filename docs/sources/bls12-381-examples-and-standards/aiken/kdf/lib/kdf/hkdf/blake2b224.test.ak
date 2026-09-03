use aiken/primitive/bytearray
use kdf/kdf.{Blake2b_224}
use kdf/hkdf/hkdf

test blake2b224_basic() {
  bytearray.length(hkdf.kdf(Blake2b_224, "salt", "ikm", "info", 28)) == 28
}

test blake2b224_2_blocks() {
  bytearray.length(hkdf.kdf(Blake2b_224, "salt", "ikm", "info", 56)) == 56
}

test blake2b224_truncated() {
  bytearray.length(hkdf.kdf(Blake2b_224, "salt", "ikm", "info", 16)) == 16
}

test blake2b224_long_inputs() {
  bytearray.length(
    hkdf.kdf(Blake2b_224, "saltSALTsaltSALTsalt", "passwordPASSWORD", "infoINFOinfoINFO", 28),
  ) == 28
}

test blake2b224_deterministic() {
  let out1 = hkdf.kdf(Blake2b_224, "salt", "ikm", "info", 28)
  let out2 = hkdf.kdf(Blake2b_224, "salt", "ikm", "info", 28)
  out1 == out2
}
