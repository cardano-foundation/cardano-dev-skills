# Architecture

## Description
- Charli3 ODV multisig oracle exposes three on-chain components written in Aiken:
  - `oracle_nfts` is the minting policy that controls the lifecycle of oracle protocol NFTs (`C3CS`, `C3RA`, `C3AS`) per pair. It ensures minting can only happen with the authorised configuration, enforces scaling constraints, and verifies platform authorisation via a platform NFT.
  - `oracle_manager` is the main spending validator parameterised by `OracleConfiguration`. It manages aggregation, reward accounting, configuration governance, scaling, pause/resume, and full teardown of an oracle instance. The script derives the NFT policy id from its inputs and uses helper checks (`core/checks.ak`) to keep state transitions safe.
- Supporting libraries (`lib/core/*`, `lib/services/*`, `lib/ext/*`) provide consensus algorithms (median, IQR filtering), NFT-based authorisation, protocol token utilities, time handling, and validation helpers for preserving value, enforcing multisig, and managing reward distributions.

## Inputs
**oracle_nfts / MintToken.** Consumes the bootstrap reference UTxO from `NftsConfiguration.utxo_ref`, the platform-auth UTxO carrying the platform NFT, and mints one `C3CS` plus positive counts of `C3RA` and `C3AS` tokens; also requires the newly created core settings output to be guarded by `oracle_manager`.

**oracle_nfts / ScaleToken.** Consumes the platform NFT input and either reference `OracleSettings` (when minting) or the script UTxOs whose NFTs are being burned; positive scaling reads the latest settings via reference inputs to confirm the oracle is not paused, while negative scaling spends matching reward/aggstate script inputs.

**oracle_nfts / BurnToken.** Consumes all remaining protocol NFT-bearing script UTxOs together with the platform NFT input so the policy can observe that no outputs recreate those assets.

**oracle_manager / OdvAggregateMsg.** Spends a single `AggState` UTxO and requires the reward account script input to accompany the transaction via `spends_one_account_utxo_for_aggregation`, while referencing the core settings datum to check expiry.

**oracle_manager / OdvAggregate.** Spends one `RewardAccount` UTxO, references the `OracleSettings` UTxO, and expects the aggregation message redeemer plus multisig signers; optional oracle fee rate NFT may appear in reference inputs for price conversion.

**oracle_manager / RedeemRewards.** Spends a `RewardAccount` UTxO; when `PlatformCollect` the platform NFT input must appear, and when `NodeCollect` the node’s verification key hash must be among `extra_signatories`; also references `OracleSettings` for fee and buffer parameters.

**oracle_manager / ManageSettings.** Spends the `OracleSettings` UTxO alongside the platform NFT input. For `UpdateSettings`, `AddNodes`, and `DelNodes` the transaction recreates the settings output (optionally referencing rate NFTs). `PauseOracle` and `ResumeOracle` rely on validity bounds to derive current time while keeping other state untouched. `RemoveOracle` consumes the final settings UTxO once the enforced pause window has elapsed.

**oracle_manager / ScaleDown.** Spends either a `RewardAccount` UTxO (after rewards are cleared or dismissal window elapsed) or an `AggState` UTxO (once expired), always with the platform NFT input and in coordination with `oracle_nfts / ScaleToken` burning the corresponding NFTs.

**oracle_manager / DismissRewards.** Spends one or more `RewardAccount` UTxOs collectively (the validator counts them via redeemers), references `OracleSettings`, and requires the platform NFT input plus a validity interval showing the dismissal window has passed.

**oracle_manager / RemoveOracle.** Spends the sole `OracleSettings` UTxO once the pause period has elapsed, consumes the platform NFT input, and relies on the validity interval to prove the removal deadline; other NFT-bearing UTxOs are expected to have been burned already.

## Outputs
**oracle_nfts / MintToken.** Produces exactly one `OracleSettings` output carrying the `C3CS` NFT with the initial `OracleSettingsDatum`, plus the requested number of empty `RewardAccount` outputs each holding a `C3RA` NFT and empty `AggState` outputs each holding a `C3AS` NFT compliant with `utxo_size_safety_buffer`.

**oracle_nfts / ScaleToken.** Produces additional reward or aggstate script outputs when minting (keeping them empty) or suppresses them entirely when burning so that the NFT count drops; the core settings NFT is never recreated.

**oracle_nfts / BurnToken.** Produces no outputs containing protocol NFTs, signalling full teardown of the oracle instance.

**oracle_manager / OdvAggregateMsg.** Recreates a single `AggState` output with the same NFT and refreshed `PriceData`, leaving the reward account untouched apart from ensuring it participated in the transaction.

**oracle_manager / OdvAggregate.** Emits an updated `RewardAccount` output with adjusted `nodes_to_rewards`, a new `AggState` output containing the computed median, timestamps, and expiry, and any fee-paying outputs required by the configured fee asset.

**oracle_manager / RedeemRewards.** Re-issues the `RewardAccount` output with decremented balances, pays the collector at `corresponding_out_ix` (either node or platform) while respecting `utxo_size_safety_buffer`, and if platform collects, confirms the platform NFT returns to the same address.

**oracle_manager / ManageSettings.** Produces a single `OracleSettings` output with updated datum content for `UpdateSettings`, `AddNodes`, and `DelNodes`. `PauseOracle` recreates the settings datum with `pause_period_started_at` set to the derived time, `ResumeOracle` clears it, and `RemoveOracle` recreates no settings output (the NFT is burned alongside other state).

**oracle_manager / ScaleDown.** When acting on reward accounts, emits no new reward account outputs (NFTs are burned by the minting policy); when acting on aggstate, no `AggState` output is recreated, shrinking the live set of oracle data UTxOs.

**oracle_manager / DismissRewards.** Produces the same number of `RewardAccount` outputs as were consumed, each reset to zero rewards and sized according to `utxo_size_safety_buffer`, so they can later be scaled down.

**oracle_manager / RemoveOracle.** Produces no oracle script outputs, completing the teardown once the pause period has elapsed and all NFTs have been removed.

## Datums
- **`OracleDatum` (`lib/core/datum.ak`)**
  - `AggState(PriceData)` stores an `AggregateMessage` result as a `PriceData` map: index 0 price, 1 creation time, 2 expiration.
  - `OracleSettings(OracleSettingsDatum)` is the mutable state governing nodes, fee config, timing bounds, pause status, and safety buffers.
  - `RewardAccount(RewardAccountDatum)` tracks per-node pending rewards (`nodes_to_rewards`) and the last update timestamp.
- **`OracleSettingsDatum`**
  - Maintains sorted node list (`Nodes`), multisig threshold, fee info (`FeeConfig` with optional rate NFT and reward price schedule), aggregation/pause timing windows, IQR parameters, and `utxo_size_safety_buffer`.
- **`RewardAccountDatum`**
  - Holds ordered `Pairs<FeedVkh, Int>` for node rewards and a `PosixTime` `last_update_time`.
- **`PriceData` / `AggregateMessage`**
  - `PriceData` wraps shared, extended, or generic price maps; helper functions read price/time fields. `AggregateMessage` is a sorted mapping of node feed VKHs to reported oracle feeds.
- **`NftsConfiguration` & `OracleConfiguration`**
  - Immutable parameters supplied to `oracle_nfts` and `oracle_manager`. `NftsConfiguration` ties policy IDs to the oracle script and required reference UTxO. `OracleConfiguration` embeds platform NFT policy, pause/dismiss periods, optional fee asset, and other governance constants.

## Redeemers
- **`MintingRedeemer` (`oracle_nfts`)**
  - `MintToken`: bootstrap mint for core settings plus reward/aggstate NFTs.
  - `ScaleToken`: symmetric mint/burn path to adjust reward/aggstate UTxO counts while keeping settings NFT untouched.
  - `BurnToken`: final burn path, used via validator-driven teardown.
- **`OracleRedeemer` (`oracle_manager`)**
  - `OdvAggregate(AggregateMessage)`: performs on-demand aggregation using node feeds, validates median/IQR consensus, updates reward account balances, and records price data.
  - `OdvAggregateMsg`: lightweight aggstate refresh that enforces expiration and conservation without touching rewards.
  - `RedeemRewards { collector: RewardRedeemer, corresponding_out_ix }`: enables node (`NodeCollect`) or platform (`PlatformCollect`) withdrawals, selecting the corresponding payout output.
  - `ManageSettings(SettingsRedeemer)`: unified governance entry point covering `UpdateSettings`, `AddNodes`, `DelNodes`, `PauseOracle`, `ResumeOracle`, and `RemoveOracle`.
  - `ScaleDown`: burns reward/aggstate NFTs when buffers are empty or dismissal periods have elapsed.
  - `DismissRewards`: zeroes reward transport UTxOs after the dismissal period while mint policy handles NFT burning.
- **`RewardRedeemer`**
  - Distinguishes reward collectors inside `RedeemRewards`: `NodeCollect` expects the node signature; `PlatformCollect` requires platform NFT authorisation.
- **`SettingsRedeemer`**
  - Tagged union referenced by `ManageSettings` covering all platform actions (configuration updates, node list adjustments, pausing, resuming, and removal).
