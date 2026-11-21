use kdf/kdf.{HashAlgo, Blake2b_256}
use kdf/pbkdf2/pbkdf2

test blake2b256_1_block_1_iter() {
  pbkdf2.kdf(Blake2b_256, "password", "salt", 1, 32) == #"5fe183b1c8689788d54f24394f35a09792ef1a52610e13a5cfb35ec623f58f4c"
}

test blake2b256_1_block_2_iter() {
  pbkdf2.kdf(Blake2b_256, "password", "salt", 2, 32) == #"4ccce844cf42ef521491a9fc015ac5fe228037f2164dc1a427d352969a315655"
}

test blake2b256_1_block_4096_iter() {
  pbkdf2.kdf(Blake2b_256, "password", "salt", 4096, 32) == #"700ee3be64b2d122fca6f91dd16d7d9850ee68757d0d03f7f380f64bc9c8081f"
}

test blake2b256_truncated_last_block() {
  pbkdf2.kdf(Blake2b_256, "password", "salt", 1, 16) == #"5fe183b1c8689788d54f24394f35a097"
}

test blake2b256_2_blocks() {
  pbkdf2.kdf(Blake2b_256, "password", "salt", 1, 64) == #"5fe183b1c8689788d54f24394f35a09792ef1a52610e13a5cfb35ec623f58f4c5db2916d73633cc6686d8e35b0d84429c25cd15089c0ec84f1394ebb5438f6f0"
}

test blake2b256_long_password_salt_4096() {
  pbkdf2.kdf(
    Blake2b_256,
    "passwordPASSWORD",
    "saltSALTsaltSALTsalt",
    4096,
    24,
  ) == #"97a32ed29d4b40de9bec6ab6e64cb61c0e4b362ceecd4b0c"
}
