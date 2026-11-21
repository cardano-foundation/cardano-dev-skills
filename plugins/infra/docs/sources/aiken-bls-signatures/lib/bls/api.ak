/// Size of a BLS private key in bytes.
/// A private key is a 32-byte scalar modulo the curve order.
pub const privkey_len = 32

/// BLS signature mode determining how messages are prepared for
/// signing and verification:
/// - `Basic`: Standard BLS.
/// - `Aug`: Message augmented with the public key.
/// - `Pop`: Proof-of-Possession mode.
pub type BlsMode {
  Basic
  Aug
  Pop
}

pub type PrivateKey =
  ByteArray

pub type PublicKey =
  ByteArray

pub type Signature =
  ByteArray

pub type Message =
  ByteArray
