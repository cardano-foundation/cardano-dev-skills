//// Augmented (Aug) signing mode + Proof-of-Possession (PoP) helpers
////
//// In Augmented mode the signed message is:
//// ```
////     H(pk || message)
//// ```
//// where the signer’s public key is prepended to the message before hashing.
//// This binds the public key to the signature and protects aggregation from
//// rogue-key attacks, allowing safe use even when keys are not PoP-verified.
////
//// PoP helpers are included for key-registration workflows, enabling a
//// participant to prove ownership of the private key corresponding to a
//// registered public key.

use bls/api.{Message, PrivateKey, PublicKey, Signature}
use bls/g1/core

/// Convert a private key to its corresponding public key.
pub fn sk_to_pk(sk: PrivateKey) -> PublicKey {
  core.sk_to_pk(sk)
}

/// Create an Augmented BLS signature.
/// The public key is appended to the message before signing.
pub fn sign(sk: PrivateKey, message: Message) -> Signature {
  core.core_sign(sk, message, api.Pop)
}

/// Verify an Augmented BLS signature.
pub fn verify(pk: PrivateKey, message: Message, sig: Signature) -> Bool {
  core.core_verify(pk, message, sig, api.Pop)
}

/// Used at key-registration time to ensure a participant actually controls the
/// private key corresponding to the registered public key.
/// Generate Proof-of-Possession for a public key.
pub fn pop_prove(sk: ByteArray) -> ByteArray {
  let pk = sk_to_pk(sk)
  core.core_sign(sk, pk, api.Pop)
}

/// Verify a Proof-of-Possession signature.
pub fn pop_verify(pk: ByteArray, pop_sig: ByteArray) -> Bool {
  core.core_verify(pk, pk, pop_sig, api.Pop)
}

/// Aggregate multiple signatures into one aggregated signature.
pub fn aggregate(sigs: List<ByteArray>) -> Signature {
  core.aggregate(sigs)
}

/// Verify aggregated signatures using PoP-validated keys.
///
/// > [!IMPORTANT]
/// > Security Note:
/// > This verification assumes that all public keys participating in aggregation
/// > were previously validated using PoP during registration. If keys are not
/// > PoP-verified, use Augmented aggregation verification instead.
pub fn aggregate_verify(
  pks: List<PrivateKey>,
  messages: List<Message>,
  sig: Signature,
) -> Bool {
  core.core_aggregate_verify(pks, messages, sig, api.Pop)
}
