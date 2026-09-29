/// F5 privacy pool — on-chain spend validator.
///
/// Each pool lives in a single UTxO whose datum is a [`f5/pool.PoolDatum`]:
/// the current Merkle root, the next empty insertion index, the set of spent
/// nullifier hashes and the accumulated fees.  A spend carries a **batch** of
/// escapes as its redeemer; the validator
///
/// 1. verifies every Groth16 proof with `f5/pool.check_batch` (the batched
///    multi-pairing check),
/// 2. requires a continuation output that re-carries the *exact* new datum
///    (computed by the transition) as an inline datum, and
/// 3. applies `f5/pool.value_rule`: the pool's lovelace are preserved in full.
///
/// The Groth16 verification key and tree depth are baked in as validator
/// parameters at deployment.  The Merkle-root transition is enforced inside
/// the Groth16 circuit, so this validator never recomputes a Poseidon hash.
use aiken/collection/list.{any}
use cardano/assets
use cardano/transaction.{
  InlineDatum,
  Output,
  OutputReference,
  Transaction,
  find_input,
}
use f5/groth16_batch.{VerificationKey}
use f5/pool.{Escapo, PoolDatum, check_batch, value_rule}

validator f5_pool(vk: VerificationKey, depth: Int) {
  spend(
    datum: Option<PoolDatum>,
    redeemer: List<Escapo>,
    own_utxo: OutputReference,
    tx: Transaction,
  ) {
    when datum is {
      None -> False
      Some(pool_datum) -> {
        when check_batch(vk, depth, pool_datum, redeemer) is {
          None -> False
          Some(new_datum) -> {
            when find_input(tx.inputs, own_utxo) is {
              None -> False
              Some(pool_input) -> {
                let pool_in_lovelace = assets.lovelace_of(pool_input.output.value)
                pool_continues(pool_in_lovelace, new_datum, tx.outputs)
              }
            }
          }
        }
      }
    }
  }
}

/// Some output must carry exactly the new pool datum as an inline datum and
/// preserve the pool's lovelace.
fn pool_continues(pool_in_lovelace: Int, new_datum: PoolDatum, outputs: List<Output>) -> Bool {
  any(
    outputs,
    fn(out) {
      when out.datum is {
        InlineDatum(raw) ->
          if raw is PoolDatum {
            raw == new_datum && value_rule(pool_in_lovelace, assets.lovelace_of(out.value))
          } else {
            False
          }
        _ -> False
      }
    },
  )
}