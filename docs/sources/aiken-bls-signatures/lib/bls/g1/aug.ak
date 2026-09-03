//// Augmented (Aug) BLS signing mode
////
//// In augmented mode the signed message is:
////
////     H(pk || message)
////
//// The signer’s public key is prepended to the message before hashing,
//// binding the public key to the signature and mitigating rogue-key
//// attacks, allowing safe aggregation even when public keys are not
//// proof-of-possession (PoP) verified.

use aiken/builtin
use aiken/collection/list
use bls/api.{Message, PrivateKey, PublicKey, Signature}
use bls/g1/core

/// Convert a private key to its corresponding public key.
pub fn sk_to_pk(sk: PrivateKey) -> PublicKey {
  core.sk_to_pk(sk)
}

/// Create an Augmented BLS signature.
/// The public key is concatenated with the message before signing.
pub fn sign(sk: PrivateKey, message: Message) -> Signature {
  let pk = sk_to_pk(sk)
  core.core_sign(sk, builtin.append_bytearray(pk, message), api.Aug)
}

/// Verify an Augmented BLS signature.
pub fn verify(pk: PrivateKey, message: Message, sig: Signature) -> Bool {
  core.core_verify(pk, builtin.append_bytearray(pk, message), sig, api.Aug)
}

/// Aggregate multiple signatures into a single aggregated signature.
pub fn aggregate(sigs: List<Signature>) -> Signature {
  core.aggregate(sigs)
}

/// Verify aggregated Augmented signatures.
///
/// For Aug mode, each signer signs (pk || message), therefore during aggregate
/// verification we must construct the same concatenated inputs for each signer
/// before calling the core verification routine.
pub fn aggregate_verify(
  pks: List<PrivateKey>,
  messages: List<Message>,
  sig: Signature,
) -> Bool {
  // Create list of (pk || message) values used during signing
  let concatenated = list.map2(pks, messages, builtin.append_bytearray)
  core.core_aggregate_verify(pks, concatenated, sig, api.Aug)
}
