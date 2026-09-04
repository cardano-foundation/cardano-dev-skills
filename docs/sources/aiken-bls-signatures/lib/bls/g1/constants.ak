////
//// BLS12-381 Constnants used in the implementation.
//// ```
//// u = -0xd201000000010000 =−2^63−2^62−2^60−2^57−2^48−2^16 , with a hamming weight of 6
//// q = (z - 1)^2(z^4 - z^2 + 1) / 3 + z = 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab
//// r = z^4 - z^2 + 1 = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001 = 52435875175126190479447740508185965837690552500527637822603658699938581184513
////
//// k = 12
//// ```
//// Where:
////   - `u`: low-hamming weight.
////   - `q`: field generator a 381-bit prime the field Fq generated.
////   - `r`: prime order, the size (255-bits) of the pairing-friendly subgroups.
////   - `k`: embedding degree of 12.
////

pub const dst_basic = "BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_"

pub const dst_aug = "BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_AUG_"

pub const dst_pop = "BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_POP_"

/// Size of a compressed BLS public key in bytes.
/// Public keys are points on G1 compressed to 48 bytes.
pub const pubkey_len = 48

/// Size of a compressed BLS signature in bytes.
/// Signatures are points on G2 compressed to 96 bytes.
pub const signature_len = 96
