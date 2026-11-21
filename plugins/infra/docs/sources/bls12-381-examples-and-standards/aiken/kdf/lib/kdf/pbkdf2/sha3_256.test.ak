use kdf/kdf.{HashAlgo, Sha3_256}
use kdf/pbkdf2/pbkdf2

test sha3_256_1_block_1_iter() {
  pbkdf2.kdf(Sha3_256, "password", "salt", 1, 32) == #"914adf4b349944a0c6a902aedbeee4862529c931e71fe830dda07c68d353e2b0"
}

test sha3_256_1_block_2_iter() {
  pbkdf2.kdf(Sha3_256, "password", "salt", 2, 32) == #"eb693a9fe3bf5468f942151671e34a48644b1cb929b7c1cc9cc35cbf803f408c"
}

test sha3_256_1_block_4096_iter() {
  pbkdf2.kdf(Sha3_256, "password", "salt", 4096, 32) == #"cee4cbfcf01bcf495b4cb725063867e88c3cee09589ddd346abdaf92c8fcd0b0"
}

test sha3_256_truncated_last_block() {
  pbkdf2.kdf(Sha3_256, "password", "salt", 1, 16) == #"914adf4b349944a0c6a902aedbeee486"
}

test sha3_256_2_blocks() {
  pbkdf2.kdf(Sha3_256, "password", "salt", 1, 64) == #"914adf4b349944a0c6a902aedbeee4862529c931e71fe830dda07c68d353e2b0ccbb236cf5aa02c45957f7e350305936053e5d563d599fd12cbdf652e3426010"
}

test sha3_256_long_password_salt_4096() {
  pbkdf2.kdf(
    Sha3_256,
    "passwordPASSWORD",
    "saltSALTsaltSALTsalt",
    4096,
    24,
  ) == #"cac1bf8d39a9707c1a3dd4770d4870ca178f34e98266cdfa"
}
