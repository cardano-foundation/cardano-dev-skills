//// This module implements a homomorphic hash function and its aggregation based on the BLS12-381 curve.
////
//// The hash function maps arbitrary-length messages to points on the elliptic curve,
//// and it uses the homomorphic property of the curve to ensure that the output hash is additive.
////
//// The hash function can be used to aggregate multiple messages or data items in a way that preserves
//// the homomorphic property of the hash function.
////
//// The module provides two main functions: [homomorphic_hash](#homomorphic_hash) and [aggregate_hashes](#aggregate_hashes).
////
//// 1. The [homomorphic_hash](#homomorphic_hash) function takes a byte array `message` as input and returns a byte array `hash` as output.
////    The function uses a custom domain separation tag (DST) to ensure that the output hash is unique and non-repeating
////    for different inputs and contexts.
////
//// 2. The [aggregate_hashes](#aggregate_hashes) function takes a list of byte arrays `hashes` as input and returns a byte array `hash` as output.
////    The function uses the BLS12-381 curve to aggregate the input hashes in a way that preserves the homomorphic property of the hash function.
////    This function can be used to aggregate multiple messages or data items while preserving the homomorphic property.
////
//// > Note that the output of the hash function is a compressed byte array of length 48, representing the x-coordinate of the group element in compressed form.

use aiken/builtin.{bls12_381_g1_compress, bls12_381_g1_hash_to_group}
use bls/pairing.{aggregate_g1}

/// This function takes an arbitrary length byte array `message` as input, and it returns a byte array `hash` as output.
/// 
/// The function uses the BLS12-381 curve to map the input message to a point on the elliptic curve,
/// and it uses the homomorphic property of the curve to ensure that the output hash is additive.
///
/// The function can be used to aggregate multiple messages or data items in a way that preserves the
/// homomorphic property of the hash function. 
///
/// ```rust
/// let msg = #"example message"
/// let hash = homomorphic_hash(msg)
/// ```
///
/// > Note: The custom DST (domain separation tag) ensures that the hash function is 
/// deterministic and produces the same output for the same input message.
pub fn homomorphic_hash(message: ByteArray, dst: ByteArray) -> ByteArray {
  // Hash the message to the group using the custom DST
  let hashed_message = bls12_381_g1_hash_to_group(message, dst)

  // Compress the resulting group element to obtain the hash
  bls12_381_g1_compress(hashed_message)
}

/// This function aggregates a list of hashes into a single hash using the homomorphic property 
/// of the hash function. 
/// This is useful for combining multiple hashes into a single representative hash,
/// which can be used to verify the integrity of a series of messages or state transitions.
///
/// ```aiken
///
/// let h1 = homomorphic_hash("message1")
/// let h2 = homomorphic_hash("message2")
/// let h3 = homomorphic_hash("message3")
///
/// let ah12  = aggregate_hashes([h1, h2])
/// let ah123 = aggregate_hashes([h1, h2, h3])
/// let ah3_12 = aggregate_hashes([h3, ah12])
///
/// ah123 == ah3_12
/// ```
///
/// > Note: The function uses `bls12_381_g1_add` to add the group elements and `bls12_381_g1_compress` to compress the final result.
pub fn aggregate_hashes(hashes: List<ByteArray>) -> ByteArray {
  aggregate_g1(hashes)
}
