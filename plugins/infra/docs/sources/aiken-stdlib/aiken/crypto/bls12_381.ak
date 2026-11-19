pub type DomainSeparationTag =
  ByteArray

/// Domain separation tag for the basic BLS scheme, as defined in:
/// <https://www.ietf.org/archive/id/draft-irtf-cfrg-bls-signature-05.html#name-basic>
pub const domain_separation_tag_nul: DomainSeparationTag =
  "BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_NUL_"

/// Domain separation tag for the BLS scheme with message augmentation, as defined in:
/// <https://www.ietf.org/archive/id/draft-irtf-cfrg-bls-signature-05.html#name-message-augmentation-2>
pub const domain_separation_tag_aug: DomainSeparationTag =
  "BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_AUG_"

/// Domain separation tag for the BLS scheme with proof of possession, as defined in:
/// <https://www.ietf.org/archive/id/draft-irtf-cfrg-bls-signature-05.html#name-proof-of-possession-2>
pub const domain_separation_tag_pop: DomainSeparationTag =
  "BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_POP_"

/// Size (in bytes) of a compressed BLS12-381 public key.
pub const public_key_size = 48

/// Size (in bytes) of a compressed BLS12-381 signature.
pub const signature_size = 96
