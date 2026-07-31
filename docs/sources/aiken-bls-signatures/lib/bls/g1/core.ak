//// This module implements the RFC "minimal-pubkey-size" variant scheme where:
//// public keys are elements of G1 and signatures are elements of G2.
////
//// Implementations that use signature aggregation SHOULD prefer this
//// configuration, because the total size of
//// (pk_1, ..., pk_n, signature) is dominated by the public keys,
//// even for relatively small values of n.

use aiken/builtin.{
  bls12_381_final_verify, bls12_381_g1_compress, bls12_381_g1_scalar_mul,
  bls12_381_g1_uncompress, bls12_381_g2_compress, bls12_381_g2_hash_to_group,
  bls12_381_g2_scalar_mul, bls12_381_g2_uncompress,
  bls12_381_mul_miller_loop_result,
}
use aiken/collection/list
use aiken/crypto/bls12_381/g1
use aiken/crypto/bls12_381/g2
use aiken/crypto/bls12_381/scalar.{field_prime}
use bls/api.{Aug, Basic, BlsMode, Pop, PrivateKey, PublicKey, Signature}
use bls/g1/constants
use bls/g2/constants as g2_constants
use bls/pairing.{aggregate_g2, group_pairing}
use bls/utils.{foldl2, sk_to_scalar}

/// Internal DST selection
fn select_dst(mode: BlsMode) -> ByteArray {
  when mode is {
    Basic -> g2_constants.dst_basic
    Aug -> g2_constants.dst_aug
    Pop -> g2_constants.dst_pop
  }
}

/// Derive a public key corresponding to the provided secret key.
///
/// The public key is computed as scalar multiplication of the generator
/// point by the secret scalar.
///
/// ```aiken
/// let public = sk_to_pk(secret)
/// ```
pub fn sk_to_pk(secret: PrivateKey) -> PublicKey {
  bls12_381_g1_scalar_mul(sk_to_scalar(secret), g1.generator)
    |> bls12_381_g1_compress
}

fn subgroup_check_g1(point: G1Element) -> Bool {
  // TODO: Use Scott's or Bowe19 https://datatracker.ietf.org/doc/html/draft-irtf-cfrg-bls-signature-02#ref-Bowe19
  // r * P == 0, where r is the prime order of the subgroup
  let r_p = bls12_381_g1_scalar_mul(field_prime, point)
  builtin.bls12_381_g1_equal(r_p, g1.zero)
}

fn subgroup_check_g2(point: G2Element) -> Bool {
  let r_p = bls12_381_g2_scalar_mul(field_prime, point)
  builtin.bls12_381_g2_equal(r_p, g2.zero)
}

/// Validate a public key ensuring it is a correctly encoded point that:
/// - lies on the curve,
/// - is in the correct subgroup, and
/// - is not the identity (infinity) point.
///
/// Returns `True` when the public key is valid and `False` otherwise.
///
/// > [!IMPORTANT]
/// > This function MUST be called before accepting externally supplied
/// > public keys (e.g. registration, aggregation, or verification inputs)
/// > to prevent subgroup or invalid-curve attacks.
///
/// ```aiken
/// key_validate(valid_pk) == True
/// key_validate(invalid_pk) == False
/// ```
pub fn key_validate(public: PublicKey) -> G1Element {
  // 1. Check that the public key is a valid compressed point and decompress it.
  let xp = bls12_381_g1_uncompress(public)

  // 1. xP = pubkey_to_point(PK)
  // 2. If xP is INVALID, fail
  // 3. If pubkey_subgroup_check(xP) is INVALID, fail
  // Ensure the public key is not the identity point, which would allow trivial forgeries.
  if xp != g1.zero && subgroup_check_g1(xp) {
    xp
  } else {
    fail
  }
}

/// Generate a deterministic signature over a message using the provided
/// secret key.
///
/// The signature is produced by hashing the message to a curve point and
/// multiplying the resulting point by the secret scalar.
///
/// ```aiken
/// let sig = core_sign(secret, message, mode)
/// ```
pub fn core_sign(
  secret: PrivateKey,
  message: ByteArray,
  mode: BlsMode,
) -> Signature {
  // q = hash_to_point(message)
  // r = sk * q
  // sig = point_to_signature(r)
  bls12_381_g2_hash_to_group(message, select_dst(mode))
    |> bls12_381_g2_scalar_mul(sk_to_scalar(secret), _)
    |> bls12_381_g2_compress
}

/// Verify a signature against a public key and message.
///
/// Returns `True` if the signature is valid for the given public key and
/// message, and `False` otherwise.
///
/// ```aiken
/// verify(public_key, message, signature, mode) == True
/// ```
pub fn core_verify(
  public_key: PublicKey,
  message: ByteArray,
  signature: Signature,
  mode: BlsMode,
) -> Bool {
  let p = key_validate(public_key)

  // 1. Convert signature to a point.
  let s = bls12_381_g2_uncompress(signature)
  expect subgroup_check_g2(s)

  // 2. Hash the message to a point.
  let q = bls12_381_g2_hash_to_group(message, select_dst(mode))

  // Check if the pairing of the public key and hashed message is equal to the pairing of the generator and signature.
  let c1 = group_pairing(p, q)
  let c2 = group_pairing(g1.generator, s)
  bls12_381_final_verify(c1, c2)
}

/// Aggregate multiple signatures into a single signature value.
///
/// The resulting signature represents the group addition of all input
/// signatures and can later be verified using aggregate verification.
///
/// > [!IMPORTANT]
/// > All input signatures MUST be valid signatures produced over the
/// > corresponding public keys and messages.
///
/// ```aiken
/// let agg = aggregate([sig1, sig2, sig3])
/// ```
pub fn aggregate(signatures: List<Signature>) -> Signature {
  aggregate_g2(signatures)
}

/// Verify an aggregated signature over multiple public keys and messages.
///
/// Returns `True` if the aggregated signature is valid for the provided
/// `(public_key_i, message_i)` pairs, and `False` otherwise.
///
/// > [!IMPORTANT]
/// > The lists of public keys and messages MUST be the same length and
/// > correspond element-wise.
///
/// ```aiken
/// aggregate_verify([pk1, pk2], [msg1, msg2], agg_sig) == True
/// ```
pub fn core_aggregate_verify(
  pks: List<PublicKey>,
  messages: List<ByteArray>,
  signature: Signature,
  mode: BlsMode,
) -> Bool {
  expect list.length(pks) == list.length(messages)
  expect [pk, ..xs] = pks
  expect [msg, ..ys] = messages
  expect builtin.length_of_bytearray(signature) == constants.signature_len

  let p = key_validate(pk)

  let q = bls12_381_g2_hash_to_group(msg, select_dst(mode))
  let ml = group_pairing(p, q)
  let c1 =
    foldl2(
      xs,
      ys,
      ml,
      fn(pk, message, miller_loop) {
        expect builtin.length_of_bytearray(pk) == constants.pubkey_len
        let p = key_validate(pk)
        let q = bls12_381_g2_hash_to_group(message, select_dst(mode))
        let pq = group_pairing(p, q)
        bls12_381_mul_miller_loop_result(pq, miller_loop)
      },
    )

  let s = bls12_381_g2_uncompress(signature)
  expect subgroup_check_g2(s)

  let c2 = group_pairing(g1.generator, s)

  bls12_381_final_verify(c1, c2)
}
