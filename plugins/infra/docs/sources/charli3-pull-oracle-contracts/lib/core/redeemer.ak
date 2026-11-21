use core/datum.{AggregateMessage}

/// Types of actions for Oracle NFTs (protocol tokens)
/// * MintToken  - Oracle start: one time mint for CoreSettings and RewardAccount; any number of mints for RewardTransport and AggState
/// * ScaleToken - Scale RewardTransport and AggState UTxOs: any number of mints/burns for RewardTransport and AggState
/// * BurnToken  - Oracle remove: all tokens are burned
pub type MintingRedeemer {
  MintToken
  ScaleToken
  BurnToken
}

/// Types of actions for Oracle smart contract
/// * OdvAggregate - user sends on demand validation request together with oracle nodes message collected off-chain
/// * NodeCollect - oracle node collects rewards
/// * PlatformCollect - oracle platform collects rewards
/// * ManageSettings - oracle platform updates configuration or lifecycle:
///   - UpdateSettings changes consensus, timing or fee settings
///   - AddNodes adds new operators
///   - DelNodes removes operators
///   - PauseOracle starts pause period so nodes can finalise pending rewards
///   - ResumeOracle cancels pause, resuming normal operation
///   - RemoveOracle destroys the remaining oracle state after pause window elapses
/// * ScaleDown - oracle platform burns RewardTransport and AggState NFTs, destroying corresponding UTxOs
/// * DismissRewards - oracle platform turns RewardTransport UTxOs with pending rewards calculations into NoRewards
pub type SettingsRedeemer {
  UpdateSettings
  AddNodes
  DelNodes
  PauseOracle
  ResumeOracle
  RemoveOracle
}

pub type OracleRedeemer {
  OdvAggregate(AggregateMessage)
  OdvAggregateMsg
  RedeemRewards { collector: RewardRedeemer, corresponding_out_ix: Int }
  ManageSettings(SettingsRedeemer)
  ScaleDown
  DismissRewards
}

/// Distinguishes between different redeemer types who can collect oracle fees.
/// See RedeemRewards constructor, which also points to corresponding output index.
pub type RewardRedeemer {
  NodeCollect
  PlatformCollect
}
