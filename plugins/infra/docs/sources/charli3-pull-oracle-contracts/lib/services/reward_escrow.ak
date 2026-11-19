use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Address}
use cardano/assets.{PolicyId}
use ext/aiken/time.{PosixTime}

/// Information on escrow script user and owner
pub type RewardEscrowDatum {
  /// policy ID - an authorization NFT minting script hash
  reward_issuer_nft: PolicyId,
  /// issuer will receive locked utxo ada fee to this address
  reward_issuer_address: Address,
  /// user vkh that signs tx claiming the rewards
  reward_receiver: VerificationKeyHash,
  /// reward issuer can return unclaimed rewards after this moment in time
  escrow_expiration_timestamp: PosixTime,
}

/// Types of actions for Reward Escrow smart contract
pub type RewardEscrowRedeemer {
  /// User - in this context oracle node, redeems escrowed rewards
  ReceiveReward
  /// Reward issuer - in this context oracle platform, returns unclaimed rewards
  ReturnToIssuer
}
