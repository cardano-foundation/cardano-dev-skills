use kdf/kdf.{Blake2b_224}
use kdf/pbkdf2/pbkdf2

test blake2b224_1_block_1_iter() {
  pbkdf2.kdf(Blake2b_224, "password", "salt", 1, 28) == #"5a7f5e128155e47faad6c032b9e5bef245a8988e3de18db7f96a3b1b"
}

test blake2b224_1_block_2_iter() {
  pbkdf2.kdf(Blake2b_224, "password", "salt", 2, 28) == #"dfceaacb2c4d99d815c6798d92554447bc2bc65d96a12496fa7f0613"
}

test blake2b224_1_block_4096_iter() {
  pbkdf2.kdf(Blake2b_224, "password", "salt", 4096, 28) == #"77990a48fbf55d19a882c6ab13d91c6483156de4f79d1ef10b6f5ced"
}

test blake2b224_truncated_last_block() {
  pbkdf2.kdf(Blake2b_224, "password", "salt", 1, 16) == #"5a7f5e128155e47faad6c032b9e5bef2"
}

test blake2b224_2_blocks() {
  pbkdf2.kdf(Blake2b_224, "password", "salt", 1, 56) == #"5a7f5e128155e47faad6c032b9e5bef245a8988e3de18db7f96a3b1b2d8f56db56caaa2f4f87ec82d5ee2abd488cc310483df9fda7519fd0"
}

test blake2b224_long_password_salt_4096() {
  pbkdf2.kdf(
    Blake2b_224,
    "passwordPASSWORD",
    "saltSALTsaltSALTsalt",
    4096,
    24,
  ) == #"5f5c5c24995b9d39708703bce95e572556cb5c3c0b1d458b"
}
