use aiken/primitive/bytearray
use kdf/kdf.{Keccak256}
use kdf/hkdf/hkdf

test keccak256_basic() {
  bytearray.length(hkdf.kdf(Keccak256, "salt", "ikm", "info", 32)) == 32
}

test keccak256_2_blocks() {
  bytearray.length(hkdf.kdf(Keccak256, "salt", "ikm", "info", 64)) == 64
}

test keccak256_truncated() {
  bytearray.length(hkdf.kdf(Keccak256, "salt", "ikm", "info", 16)) == 16
}

test keccak256_long_inputs() {
  bytearray.length(
    hkdf.kdf(Keccak256, "saltSALTsaltSALTsalt", "passwordPASSWORD", "infoINFOinfoINFO", 32),
  ) == 32
}

test keccak256_deterministic() {
  let out1 = hkdf.kdf(Keccak256, "salt", "ikm", "info", 32)
  let out2 = hkdf.kdf(Keccak256, "salt", "ikm", "info", 32)
  out1 == out2
}
