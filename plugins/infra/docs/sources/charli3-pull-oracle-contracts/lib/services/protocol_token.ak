use aiken/collection/list
use aiken/crypto.{ScriptHash}
use cardano/address
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{Input, Output, find_script_outputs}
use ext/cardano/value.{Asset}

/// Find own protocol NFT inside the value we are spending.
/// Note that it's not required to check_own_protocol_token in tx inputs
/// because it's already been checked for each output.
pub fn find_own_protocol_policy_id(
  input_value: Value,
  nft_name: AssetName,
) -> PolicyId {
  trace @"T3"

  expect [(policy_id, _name, 1)] =
    input_value
      |> assets.flatten
      |> list.filter(
          fn(t) {
            let (_, name, _) = t
            nft_name == name
          },
        )

  policy_id
}

/// Find own protocol NFT inside transaction inputs.
/// Note that it's not required to check_own_protocol_token in tx inputs
/// because it's already been checked for each output.
pub fn find_script_inputs_by_token(
  tx_inputs: List<Input>,
  script_hash: ScriptHash,
  protocol_token: Asset,
) -> List<Input> {
  let has_nft =
    fn(value: Value) -> Bool {
      value
        |> assets.flatten
        |> list.has((protocol_token.policy_id, protocol_token.name, 1))
    }

  list.filter(
    tx_inputs,
    fn(i) {
      i.output.address == address.from_script(script_hash) && has_nft(
        i.output.value,
      )
    },
  )
}

/// Find own protocol NFT inside transaction outputs
pub fn find_script_outputs_by_token(
  tx_outputs: List<Output>,
  script_hash: ScriptHash,
  protocol_token: Asset,
) -> List<Output> {
  find_script_outputs(tx_outputs, script_hash)
    |> list.filter(fn(o) { check_own_protocol_token(o.value, protocol_token) })
}

/// Find own protocol NFT inside transaction outputs allowing asset
pub fn find_script_outputs_by_token_allowing_asset(
  tx_outputs: List<Output>,
  script_hash: ScriptHash,
  allowed_asset: PolicyId,
  protocol_token: Asset,
) -> List<Output> {
  find_script_outputs(tx_outputs, script_hash)
    |> list.filter(
        fn(o) {
          check_own_protocol_token_allowing_asset(
            o.value,
            allowed_asset,
            protocol_token,
          )
        },
      )
}

/// Returns true if protocol NFT was found and it's the only asset except lovelace
pub fn check_own_protocol_token(
  output_value: Value,
  protocol_token: Asset,
) -> Bool {
  let tokens =
    output_value
      |> assets.without_lovelace
      |> assets.flatten

  tokens == [(protocol_token.policy_id, protocol_token.name, 1)]
}

/// Returns true if protocol NFT was found and it's the only asset except lovelace and one allowed
pub fn check_own_protocol_token_allowing_asset(
  output_value: Value,
  allowed_asset: PolicyId,
  protocol_token: Asset,
) -> Bool {
  let tokens =
    output_value
      |> assets.without_lovelace
      |> assets.flatten
      |> list.filter(
          fn(triple) {
            let (policy_id, _, _) = triple
            policy_id != allowed_asset
          },
        )

  tokens == [(protocol_token.policy_id, protocol_token.name, 1)]
}
