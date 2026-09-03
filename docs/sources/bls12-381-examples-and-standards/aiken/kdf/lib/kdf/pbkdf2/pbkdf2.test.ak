use aiken/fuzz
use aiken/primitive/bytearray
use kdf/kdf.{HashAlgo, Sha256}
use kdf/pbkdf2/pbkdf2

// -------------------------------------------------------------------
// Property-based tests
// -------------------------------------------------------------------

/// PBKDF2 must always produce an output of exactly `dk_len` bytes.
test prop_output_length(
  args via fuzz.tuple4(
    fuzz.bytearray_between(1, 32),
    fuzz.bytearray_between(1, 16),
    fuzz.int_between(1, 3),
    fuzz.int_between(1, 64),
  ),
) {
  let (password, salt, count, dk_len) = args
  let out = pbkdf2.kdf(Sha256, password, salt, count, dk_len)
  bytearray.length(out) == dk_len
}

/// PBKDF2 must be deterministic: same inputs always yield the same output.
test prop_determinism(
  args via fuzz.tuple4(
    fuzz.bytearray_between(1, 32),
    fuzz.bytearray_between(1, 16),
    fuzz.int_between(1, 3),
    fuzz.int_between(1, 64),
  ),
) {
  let (password, salt, count, dk_len) = args
  let out1 = pbkdf2.kdf(Sha256, password, salt, count, dk_len)
  let out2 = pbkdf2.kdf(Sha256, password, salt, count, dk_len)
  out1 == out2
}

// -------------------------------------------------------------------
// Unit tests (RFC 6070 analogs with SHA-256)
// -------------------------------------------------------------------

test sha256_1_block_1_iter() {
  pbkdf2.kdf(Sha256, "password", "salt", 1, 32) == #"4ade8a4c5397bdb867dbb7e253b4d4562388cdbf599713aaecd87fa7f3202044"
}

test sha256_1_block_2_iter() {
  pbkdf2.kdf(Sha256, "password", "salt", 2, 32) == #"eb81bb537eb16b0b73d0ad1ed9fb8727a6138a8c7c4b69496028e39d2ea0375a"
}

test sha256_1_block_4096_iter() {
  pbkdf2.kdf(Sha256, "password", "salt", 4096, 32) == #"8ab288ebdb68a28109ad3d26acaa83d6bd2a093b9382b08abb8db10203870500"
}

test sha256_truncated_last_block() {
  pbkdf2.kdf(Sha256, "password", "salt", 1, 16) == #"4ade8a4c5397bdb867dbb7e253b4d456"
}

test sha256_2_blocks() {
  pbkdf2.kdf(Sha256, "password", "salt", 1, 64) == #"4ade8a4c5397bdb867dbb7e253b4d4562388cdbf599713aaecd87fa7f32020444a3ba78bfe77a3e4ff33a7e6c4d4bfe254fc3723e188831bf61d14584f98a9b3"
}

test sha256_long_password_salt_4096() {
  pbkdf2.kdf(
    Sha256,
    "passwordPASSWORD",
    "saltSALTsaltSALTsalt",
    4096,
    24,
  ) == #"d2bb3abaee88a46a300fc76618eb2a2c25f094741096be73"
}

// -------------------------------------------------------------------
// Embedded NUL bytes (analogous to RFC 6070 test case 6)
// -------------------------------------------------------------------

test sha256_with_nul_bytes() {
  // password = "pass\0word", salt = "sa\0lt", c = 4096, dkLen = 16
  pbkdf2.kdf(
    Sha256,
    #"7061737300776f7264",
    #"7361006c74",
    4096,
    16,
  ) == #"d0736fb3fd9805265599b751ceea11c5"
}
