use aiken/collection/dict.{has_key}
// Tests for blacklist spending validator
// The blacklist_spend validator ensures that blacklist node UTxOs can only be spent
// when the blacklist minting policy is also executed in the same transaction.

use cardano/assets.{PolicyId, Value, to_dict}

fn has_policy(mint_value: Value, policy_cs: PolicyId) -> Bool {
  to_dict(mint_value) |> has_key(policy_cs)
}

// Test that has_policy returns true when policy is in mint
test test_has_policy_returns_true() {
  let policy_cs = #"aabbccdd"
  let mint_value = assets.from_asset(policy_cs, "some_token", 1)

  has_policy(mint_value, policy_cs)
}

// Test that has_policy returns false when policy is not in mint
test test_has_policy_returns_false() {
  let policy_cs = #"aabbccdd"
  let different_cs = #"deadbeef"
  let mint_value = assets.from_asset(different_cs, "some_token", 1)

  !has_policy(mint_value, policy_cs)
}

// Test that has_policy returns false when mint is empty
test test_has_policy_returns_false_for_empty_mint() {
  let policy_cs = #"aabbccdd"
  let mint_value = assets.zero

  !has_policy(mint_value, policy_cs)
}
