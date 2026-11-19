use aiken/builtin.{
  bls12_381_final_verify, bls12_381_g1_uncompress, bls12_381_g2_hash_to_group, 
  bls12_381_g2_uncompress, bls12_381_mul_miller_loop_result 
}
use aiken/collection/list.{foldl}
use aiken/crypto/bls12_381/g1
use bls/api.{Aug, Basic, BlsMode, Pop, PublicKey}
use bls/g2/constants.{dst_aug, dst_basic, dst_pop}
use bls/pairing.{aggregate_g1, group_pairing}
use bls/utils.{all_unique}


pub type PublicKeyAggregated =
  ByteArray
  
/// Aggregates multiple BLS public keys into a single public key.
/// Uses the **aggregate_g1** function to iteratively uncompress and add the public keys,
/// and then compresses the resulting aggregated public key.
/// The aggregation is in the context of G1 group.
///
/// Arguments:
/// * publickeys: List<PublicKey> - A list of BLS public keys to be aggregated.
///
/// Returns:
/// PublicKeyAggregated - The compressed aggregated BLS public key.
///
/// ```aiken
/// let agg_pk = aggregate_publickeys([pk1, pk2, pk3])
/// ```
pub fn aggregate_publickeys(publickeys: List<PublicKey>) -> PublicKeyAggregated {
  aggregate_g1(publickeys)
}

/// Verify an aggregated signature using a pre-aggregated public key.
///
/// This verifies that the aggregate signature is valid for all messages,
/// using the pre-aggregated public key.
///
/// For Basic mode: duplicates messages are rejected
/// For Aug mode: duplicate messages are allowed (but only works with single signer)
/// Meaning the method is working, in multi-party context, only in Basic BLS mode. 
///
/// ```aiken
/// let agg_pk = aggregate_publickeys([pk1, pk2, pk3])
/// let result = aggregate_publickey_verify(agg_pk, [message, message, message], agg_sig, Basic)
/// ```
pub fn aggregate_publickey_verify(
  pk_agg: PublicKeyAggregated,
  messages: List<ByteArray>,
  sig: ByteArray,
  mode: BlsMode,
) -> Bool {
  internal_aggregate_verify_with_aggregated_pk(pk_agg, messages, sig, mode)
}

fn internal_aggregate_verify_with_aggregated_pk(
  pk_agg: PublicKeyAggregated,
  messages: List<ByteArray>,
  signature: ByteArray,
  mode: BlsMode,
) -> Bool {
  if mode == Basic && !all_unique(messages) {
    False
  } else {
    expect [msg, ..msgs_rest] = messages
    let p = bls12_381_g1_uncompress(pk_agg)

    let q = hash_for_mode(pk_agg, msg, mode)
    let ml = group_pairing(p, q)
    let c1 =
      foldl(
        msgs_rest,
        ml,
        fn(message, miller_loop) {
          let q = hash_for_mode(pk_agg, message, mode)
          let pq = group_pairing(p, q)
          bls12_381_mul_miller_loop_result(pq, miller_loop)
        },
      )

    let s = bls12_381_g2_uncompress(signature)
    let c2 = group_pairing(g1.generator, s)

    bls12_381_final_verify(c1, c2)
  }
}

fn hash_for_mode(pk: ByteArray, message: ByteArray, mode: BlsMode) -> G2Element {
  when mode is {
    Basic -> bls12_381_g2_hash_to_group(message, dst_basic)
    Aug -> bls12_381_g2_hash_to_group(builtin.append_bytearray(pk, message), dst_aug)
    Pop -> bls12_381_g2_hash_to_group(builtin.append_bytearray(pk, message), dst_pop)
  }
}
