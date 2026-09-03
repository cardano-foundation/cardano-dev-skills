use aiken/merkle_patricia_forestry.{Proof} as mpf

/// A KYC proof is a short-lived Ed25519 signature from a trusted issuer
/// attesting that a specific user is KYC'd for a specific security token on a
/// specific network, valid until a specific moment.
///
/// Payload layout (exactly 67 bytes, big-endian ordering where applicable):
///
///     Bytes  0 – 27  : user_pkh          (28)  — binds proof to a specific sender
///     Byte      28   : user_kyc_tier     (1)   — 0x00 invalid; 0x01 User;
///                                                0x02 Institutional; 0x03 vLEI
///     Bytes 29 – 36  : valid_until_ms    (8)   — POSIX ms, big-endian
///     Bytes 37 – 64  : security_policy_id(28)  — binds to a specific token
///     Byte      65   : network_id        (1)   — 0x00 preview; 0x01 preprod;
///                                                0x02 mainnet; 0x03 yaci
///     Byte      66   : credential_type   (1)   — 0x00 VerificationKey; 0x01 Script
///
/// `credential_type` was APPENDED (byte 66) rather than inserted, so every
/// pre-existing offset is unchanged and only `payload_length` moved 66 → 67.
///
/// Why it must be in the SIGNED payload rather than checked alongside it: a
/// 28-byte hash does not say whether its owner is a verification key or a
/// script, and the CIP-113 base layer treats those as genuinely different
/// owners — `programmable_logic/owner.ak` authorises a `VerificationKey` owner
/// by signature and a `Script` owner by withdraw-0. Without this byte an
/// attestation issued for a key credential is equally valid for a script
/// credential sharing its hash, and the holder register cannot tell the two
/// apart — a `registerführende Stelle` identification defect.
///
/// Signature: 64-byte raw Ed25519 over the payload.
/// Issuer vkey: 32-byte raw Ed25519 vkey — directly indexes
///   `GlobalStateDatum.trusted_entity_vkeys`.
pub type AttestationProof {
  payload: ByteArray,
  signature: ByteArray,
  issuer_vkey: ByteArray,
}

pub type MembershipProof {
  pkh: ByteArray,
  valid_until_ms: Int,
  mpf_proof: Proof,
}

pub type KycProof {
  Attestation { kyc_proof: AttestationProof }
  Membership { membership_proof: MembershipProof }
}

pub const payload_length: Int = 67

pub const signature_length: Int = 64

pub const issuer_vkey_length: Int = 32

// Byte offsets within the payload
pub const offset_user_pkh: Int = 0

pub const offset_user_kyc_tier: Int = 28

pub const offset_valid_until_ms: Int = 29

pub const offset_security_policy_id: Int = 37

pub const offset_network_id: Int = 65

/// Appended after `network_id`; see the payload layout above.
pub const offset_credential_type: Int = 66

// Field widths
pub const width_user_pkh: Int = 28

pub const width_valid_until_ms: Int = 8

pub const width_security_policy_id: Int = 28

/// Credential discriminators. These are the ONLY two Cardano credential
/// constructors, and the mapping is fixed by `utils.credential_type_byte`.
/// Off-chain attestors and the MPF tree builder MUST use the same mapping.
pub const credential_type_key: Int = 0x0

pub const credential_type_script: Int = 0x1

// Tier values (for documentation — validator only checks != 0x00 in v1)
pub const tier_invalid: Int = 0x0

pub const tier_user: Int = 0x1

pub const tier_institutional: Int = 0x2

pub const tier_vlei: Int = 0x3
