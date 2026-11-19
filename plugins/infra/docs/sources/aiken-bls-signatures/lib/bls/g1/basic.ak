//// Basic BLS signing mode
////
//// Basic BLS aggregation is vulnerable to rogue-key attacks if the public
//// keys participating in aggregation were not previously verified using a
//// proof-of-possession (PoP) registration procedure.
////
//// This mode should only be used when:
////   - all public keys are trusted, or
////   - keys were validated with PoP at registration time.
////
//// If keys are untrusted or dynamic, prefer Augmented (Aug) or PoP modes.
////
//// > [!IMPORTANT]
//// > Using Basic mode with unverified or untrusted keys can compromise
//// > the security of aggregated signatures.

use bls/api.{Message, PrivateKey, PublicKey, Signature}
use bls/g1/core
use bls/utils

/// Convert a private key to its corresponding public key.
pub fn sk_to_pk(sk: PrivateKey) -> PublicKey {
  core.sk_to_pk(sk)
}

/// Create a Basic-mode BLS signature.
/// Signs the raw message without public-key augmentation.
pub fn sign(sk: PrivateKey, message: Message) -> Signature {
  core.core_sign(sk, message, api.Basic)
}

/// Verify a Basic-mode BLS signature.
pub fn verify(pk: PrivateKey, message: Message, sig: Signature) -> Bool {
  core.core_verify(pk, message, sig, api.Basic)
}

/// Aggregate multiple signatures into a single signature.
/// All signatures must be generated in Basic mode.
pub fn aggregate(sigs: List<Signature>) -> Signature {
  core.aggregate(sigs)
}

/// Verify an aggregated signature for Basic BLS mode, enforcing that
/// all messages are distinct.
///
/// SECURITY NOTE:
/// Basic BLS aggregation is vulnerable to rogue-key attacks if duplicate
/// messages are allowed. This function ensures safety by checking that
/// each message is unique before performing the aggregation verification.
///
/// Use this function when aggregating arbitrary or untrusted public keys
/// to prevent potential forgery attacks.
pub fn aggregate_verify(
  pks: List<PrivateKey>,
  messages: List<Message>,
  sig: Signature,
) -> Bool {
  if !utils.all_unique(messages) {
    False
  } else {
    core.core_aggregate_verify(pks, messages, sig, api.Basic)
  }
}
