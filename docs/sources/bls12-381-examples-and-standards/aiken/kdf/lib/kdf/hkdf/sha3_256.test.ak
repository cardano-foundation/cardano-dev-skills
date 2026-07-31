use aiken/primitive/bytearray
use kdf/kdf.{Sha3_256}
use kdf/hkdf/hkdf

test sha3_256_basic() {
  bytearray.length(hkdf.kdf(Sha3_256, "salt", "ikm", "info", 32)) == 32
}

test sha3_256_2_blocks() {
  bytearray.length(hkdf.kdf(Sha3_256, "salt", "ikm", "info", 64)) == 64
}

test sha3_256_truncated() {
  bytearray.length(hkdf.kdf(Sha3_256, "salt", "ikm", "info", 16)) == 16
}

test sha3_256_long_inputs() {
  bytearray.length(
    hkdf.kdf(Sha3_256, "saltSALTsaltSALTsalt", "passwordPASSWORD", "infoINFOinfoINFO", 32),
  ) == 32
}

test sha3_256_deterministic() {
  let out1 = hkdf.kdf(Sha3_256, "salt", "ikm", "info", 32)
  let out2 = hkdf.kdf(Sha3_256, "salt", "ikm", "info", 32)
  out1 == out2
}
