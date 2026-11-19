use aiken/collection/dict.{Dict}
use aiken/collection/list
use aiken/option.{is_some}
use cardano/assets.{AssetName, PolicyId, Value}
use cardano/transaction.{Input, Output}

pub fn auth_by_nft(
  nft: PolicyId,
  tx_inputs: List<Input>,
  tx_outputs: List<Output>,
) -> Bool {
  trace @"T5"

  let has_nft =
    fn(value: Value) -> Bool {
      value |> assets.to_dict |> dict.get(nft) |> is_some
    }
  let get_nft =
    fn(value: Value) -> Dict<AssetName, Int> {
      expect Some(tokens) = value |> assets.to_dict |> dict.get(nft)
      tokens
    }

  expect Some(input) =
    list.find(tx_inputs, fn(i: Input) { i.output.value |> has_nft })
  expect Some(output) =
    list.find(tx_outputs, fn(o: Output) { o.value |> has_nft })

  let must_pay_nft_back = input.output.address == output.address
  let must_pay_back_same_tokens =
    get_nft(input.output.value) == get_nft(output.value)

  must_pay_nft_back && must_pay_back_same_tokens
}
