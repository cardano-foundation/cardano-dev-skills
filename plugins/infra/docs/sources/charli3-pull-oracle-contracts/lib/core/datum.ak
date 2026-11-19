use aiken/collection/pairs
use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken/option
use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference}
use ext/aiken/math/rational.{Percent, Permille}
use ext/aiken/time.{PosixTime, PosixTimeDiff}
use ext/cardano/value.{Asset}

pub type OracleFeed =
  Int

pub type NodeFeed =
  Int

/// A mapping structure that stores key-value pairs.
/// It is used to store price-related data in the PriceData structure.
pub type PriceMap =
  Pairs<Int, Int>

/// The main data structure representing price-related information.
/// It can contain shared, extended, or generic data.
pub type PriceData {
  SharedData
  ExtendedData
  GenericData { price_map: PriceMap }
}

/// Retrieves a price-related value from the PriceData structure using an index.
pub fn get_price_data(price_data: PriceData, index: Int) -> Option<Int> {
  expect GenericData { price_map } = price_data
  pairs.get_first(price_map, index)
}

/// Creates a PriceData object with price, creation time, and expiration time.
pub fn create_price_data(
  price: Int,
  time_creation: Int,
  time_expiration,
) -> PriceData {
  GenericData(
    [Pair(0, price), Pair(1, time_creation), Pair(2, time_expiration)],
  )
}

/// There are four types of oracle utxos:
/// 0. AggState - each AggState utxo is complementary to RewardTransport, it contains the oracle feed value,
///    that will be referenced by a user of a DApp.
/// 1. OracleSettings - one for each oracle,
///    acts as single point of truth for oracle settings and node list.
/// 2. RewardAccount - one for each oracle,
///    acts as single point of truth for reward distribution.
/// 3. RewardTransport - many for each oracle, with possibility of scaling their number on demand,
///    users perform ODV aggregation with those by providing node feeds list constructed off-chain.
pub type OracleDatum {
  AggState(PriceData)
  OracleSettings(OracleSettingsDatum)
  RewardAccount(RewardAccountDatum)
}

/// Immutable NFT settings for oracle usage.
/// Rationale for immutability:
/// * utxo_ref - Ensures a unique policy ID for each oracle's NFT, preventing conflicts.
/// * oracle_conf - Associates the NFT with a fixed oracle configuration, ensuring consistency.
/// * oracle_script_hash - Links the NFT to a specific oracle script, maintaining a secure relationship.
pub type NftsConfiguration {
  /// A reference to the UTXO, guaranteeing a unique policy ID for the oracle's NFTs.
  utxo_ref: OutputReference,
  /// Defines parameters that the oracle will adhere to when using this validator.
  oracle_conf: OracleConfiguration,
  /// The hash of the oracle script ensuring a verifiable relationship between
  oracle_script_hash: ScriptHash,
}

/// Immutable oracle settings.
/// Rationale for immutability:
/// * platform_auth_nft - oracle deployment corresponds to one unchanging "platform"
/// * pause_period_length - oracle nodes will be sure that platform won't update this to a make very short interval
/// * reward_dismissing_period_length - oracle nodes will be sure that platform won't update this to a make very short interval
/// * fee_token - oracle nodes will be sure that platform won't update reward currency
pub type OracleConfiguration {
  /// platform is authorized by providing its input with specific NFT inside the transaction
  platform_auth_nft: PolicyId,
  /// pause period is when oracle can no longer do aggregations, but rewards can still be calculated
  pause_period_length: PosixTimeDiff,
  /// after this period rewards can be dismissed with DismissRewards redeemer
  reward_dismissing_period_length: PosixTimeDiff,
  /// oracle fees are paid using this asset, if it's None then ada is used
  fee_token: Option<Asset>,
}

/// Node id mapped to the corresponding node feed
/// WARNING AggregateMessage mapping should be sorted ascendingly by NodeFeed, to use it with aikens dict.from_ascending_pairs
pub type AggregateMessage =
  Pairs<FeedVkh, NodeFeed>

/// Mutable oracle settings
pub type OracleSettingsDatum {
  /// list of oracle nodes, node id is its FeedVkh
  nodes: Nodes,
  /// distinct node signatures number that passes multisig check
  required_node_signatures_count: Int,
  /// configuration of oracle fees
  fee_info: FeeConfig,
  /// aggregation is considered live, i.e. usable by dapps during this period
  aggregation_liveness_period: PosixTimeDiff,
  /// max tx validity interval length for odv-aggregation tx
  time_uncertainty_aggregation: PosixTimeDiff,
  /// max tx validity interval length for platform governance txs
  time_uncertainty_platform: PosixTimeDiff,
  /// see interquartile range (IQR) and Tukey fences methods for outlier detection,
  /// recommended value for this parameter is 150 (i.e. 1.5) or 170 in case of normal distribution
  iqr_fence_multiplier: Percent,
  /// in case IQR is not applicable (equals zero) or number of nodes is less than iqr_applicability_threshold,
  /// median is multiplied by this factor to then produce a fence for filtering out outliers;
  /// recommended value for this parameter is 25 (i.e. 2.5%) for stablecoins and 300 (30%) for everything else
  median_divergency_factor: Permille,
  /// this value is always larger than zero,
  /// should be equal to a minimum ada amount held at maximum expected oracle utxo size
  utxo_size_safety_buffer: Int,
  /// if oracle is in pause state, then this field will have a certain timestamp value
  pause_period_started_at: Option<PosixTime>,
}

/// Reward distribution datum
pub type RewardAccountDatum {
  /// Maps oracle node feed verification keys to their reward amounts.
  /// Each entry represents an individual node's accumulated rewards that can be claimed.
  /// WARNING nodes_to_rewards mapping should be sorted ascendingly by FeedVkh, to use it with aikens dict.from_ascending_pairs
  nodes_to_rewards: Pairs<FeedVkh, Int>,
  /// The last time when rewards were distributed or UTxO was spent/updated
  last_update_time: PosixTime,
}

/// WARNING nodes list should be sorted ascendingly by FeedVkh
pub type Nodes =
  List<FeedVkh>

pub type FeedVkh =
  VerificationKeyHash

pub type FeeConfig {
  rate_nft: Option<Asset>,
  reward_prices: RewardPrices,
}

pub type RewardPrices {
  node_fee: Int,
  platform_fee: Int,
}

pub fn is_oracle_paused(settings: OracleSettingsDatum) -> Bool {
  option.is_some(settings.pause_period_started_at)
}
