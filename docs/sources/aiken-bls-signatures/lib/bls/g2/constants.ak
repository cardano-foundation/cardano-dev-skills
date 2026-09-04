pub const dst_basic = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_NUL_"

pub const dst_aug = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_AUG_"

pub const dst_pop = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_"

/// Size of a compressed BLS public key in bytes.
/// Public keys are points on G2 compressed to 96 bytes.
pub const pubkey_len = 96

/// Size of a compressed BLS signature in bytes.
/// Signatures are points on G1 compressed to 48 bytes.
pub const signature_len = 48
