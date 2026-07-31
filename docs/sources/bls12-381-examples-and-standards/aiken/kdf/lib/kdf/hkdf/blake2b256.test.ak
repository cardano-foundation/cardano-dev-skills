use aiken/primitive/bytearray
use kdf/kdf.{Blake2b_256}
use kdf/hkdf/hkdf

test blake2b256_basic() {
  bytearray.length(hkdf.kdf(Blake2b_256, "salt", "ikm", "info", 32)) == 32
}

test blake2b256_2_blocks() {
  bytearray.length(hkdf.kdf(Blake2b_256, "salt", "ikm", "info", 64)) == 64
}

test blake2b256_truncated() {
  bytearray.length(hkdf.kdf(Blake2b_256, "salt", "ikm", "info", 16)) == 16
}

test blake2b256_long_inputs() {
  bytearray.length(
    hkdf.kdf(Blake2b_256, "saltSALTsaltSALTsalt", "passwordPASSWORD", "infoINFOinfoINFO", 32),
  ) == 32
}

test blake2b256_deterministic() {
  let out1 = hkdf.kdf(Blake2b_256, "salt", "ikm", "info", 32)
  let out2 = hkdf.kdf(Blake2b_256, "salt", "ikm", "info", 32)
  out1 == out2
}
