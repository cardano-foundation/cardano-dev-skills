//// @hidden
//// Utility helpers and shared constants for BLS aggregation tests.
////
//// This module defines reusable keys, messages, and helper functions used
//// across rogue-key and aggregation verification tests. In particular, it
//// provides a deterministic rogue-key construction method that simulates an
//// attacker attempting to forge participation in a multi-party aggregation.

use aiken/builtin
use aiken/crypto/bls12_381/scalar.{field_prime}
use aiken/primitive/bytearray
use bls/g1/basic as bls

/// Common message used in aggregation tests.
pub const message = "Message to sign"

pub const other_message = "Other message to sign"

pub const another_message = "Another message to sign"

// ------------------------------------------------------------
// Honest participants
// ------------------------------------------------------------

/// Private keys for two honest participants.
pub const zero_sk = bytearray.from_int_big_endian(0, 32)

pub const prime_order_sk = bytearray.from_int_big_endian(field_prime, 32)

pub const sk1 = bytearray.from_int_big_endian(1, 32)

pub const sk2 = bytearray.from_int_big_endian(2, 32)

pub const sk3 = bytearray.from_int_big_endian(2, 32)

/// Corresponding public keys.
pub const pk1 = bls.sk_to_pk(sk1)

pub const pk2 = bls.sk_to_pk(sk2)

pub const pk3 = bls.sk_to_pk(sk3)

// ------------------------------------------------------------
// Attacker key material
// ------------------------------------------------------------

/// Independent attacker private key.
pub const sk_fake = bytearray.from_int_big_endian(999, 32)

/// Attacker public key derived normally from the private key.
pub const pk_fake = bls.sk_to_pk(sk_fake)

/// Rogue public key constructed to manipulate aggregated verification.
pub const rogue_pk = construct_rogue_key(pk1, pk2, pk_fake)

// ------------------------------------------------------------
// Attacker signature
// ------------------------------------------------------------

/// Signature produced only by the attacker.
/// Honest participants do not sign in rogue-key attack scenarios.
pub const sig_fake = bls.sign(sk_fake, message)

/// Construct a rogue public key for aggregation-attack simulations.
///
/// The attacker creates a malicious public key that offsets the honest
/// participants' keys:
///
///     rogue_pk = pk_fake - (pk1 + pk2)
///
/// After aggregation:
///
///     pk1 + pk2 + rogue_pk = pk_fake
///
/// This allows the attacker to produce a single valid signature under
/// `pk_fake` that appears to verify as if all participants contributed,
/// unless mitigations such as PoP, augmented signing, or distinct-message
/// enforcement are applied.
pub fn construct_rogue_key(
  pk1: ByteArray,
  pk2: ByteArray,
  pk_fake: ByteArray,
) -> ByteArray {
  let p1 = builtin.bls12_381_g1_uncompress(pk1)
  let p2 = builtin.bls12_381_g1_uncompress(pk2)
  let pf = builtin.bls12_381_g1_uncompress(pk_fake)

  let sum12 = builtin.bls12_381_g1_add(p1, p2)
  let neg_sum12 = builtin.bls12_381_g1_neg(sum12)

  let rogue_point = builtin.bls12_381_g1_add(pf, neg_sum12)
  builtin.bls12_381_g1_compress(rogue_point)
}
