"""Oracle transaction builder leveraging comprehensive validation utilities."""

import logging
from copy import deepcopy
from dataclasses import dataclass

from pycardano import (
    Address,
    Asset,
    AssetName,
    ExtendedSigningKey,
    MultiAsset,
    PaymentSigningKey,
    Redeemer,
    ScriptHash,
    Transaction,
    TransactionOutput,
    UTxO,
    VerificationKeyHash,
)

from charli3_offchain_core.blockchain.transactions import (
    TransactionManager,
    ValidityWindow,
)
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.base import (
    PosixTime,
)
from charli3_offchain_core.models.oracle_datums import (
    AggState,
    NoDatum,
    Nodes,
    PriceData,
    RewardAccountDatum,
    RewardAccountVariant,
)
from charli3_offchain_core.models.oracle_redeemers import (
    AggregateMessage,
    OdvAggregate,
    OdvAggregateMsg,
)
from charli3_offchain_core.oracle.exceptions import (
    TransactionError,
)
from charli3_offchain_core.oracle.utils import (
    calc_methods,
    common,
    rewards,
    state_checks,
)

logger = logging.getLogger(__name__)


@dataclass
class OdvResult:
    """Result of ODV transaction."""

    transaction: Transaction
    account_output: TransactionOutput
    agg_state_output: TransactionOutput
    sorted_required_signers: list[VerificationKeyHash]


class OracleTransactionBuilder:
    """Builder for Oracle transactions with comprehensive validation."""

    def __init__(
        self,
        tx_manager: TransactionManager,
        script_address: Address,
        policy_id: ScriptHash,
        ref_script_config: ReferenceScriptConfig,
        reward_token_hash: ScriptHash | None = None,
        reward_token_name: AssetName | None = None,
    ) -> None:
        """Initialize transaction builder.

        Args:
            tx_manager: Transaction manager
            script_address: Script address
            policy_id: Policy ID for tokens
        """
        self.tx_manager = tx_manager
        self.script_address = script_address
        self.policy_id = policy_id
        self.ref_script_config = ref_script_config
        self.reward_token_hash = reward_token_hash
        self.reward_token_name = reward_token_name
        self.network_config = self.tx_manager.chain_query.config.network_config

    async def build_odv_tx(
        self,
        message: AggregateMessage,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        change_address: Address | None = None,
        validity_window: ValidityWindow | None = None,
    ) -> OdvResult:
        """Build ODV aggregation transaction with comprehensive validation.

        Args:
            message: Aggregate message to validate
            signing_key: Signing key for transaction
            change_address: Optional change address
            validity_window: Optional validity window

        Returns:
            OdvResult containing transaction and outputs

        Raises:
            ValidationError: If validation fails
            TransactionError: If transaction building fails
        """
        try:
            # Get UTxOs and settings first
            utxos = await common.get_script_utxos(self.script_address, self.tx_manager)

            settings_datum, settings_utxo = (
                state_checks.get_oracle_settings_by_policy_id(utxos, self.policy_id)
            )

            print("\n=== COMPARING NODES ===")
            print("On-chain nodes:")
            for node_vkh in settings_datum.nodes.node_map:
                print(
                    f"  {node_vkh.to_primitive().hex()} ({len(node_vkh.payload)} bytes)"
                )

            print("\nYour message nodes (in order they will be sent):")
            for i, vkh in enumerate(message.node_feeds_sorted_by_feed.keys(), 1):
                feed_value = message.node_feeds_sorted_by_feed[vkh]
                print(f"  {i}. {vkh.to_primitive().hex()} (feed={feed_value})")
            script_utxo = await common.get_reference_script_utxo(
                self.tx_manager.chain_query,
                self.ref_script_config,
                self.script_address,
            )

            reference_inputs = {settings_utxo}

            # Calculate the transaction time window and current time ONCE
            if validity_window is None:
                validity_window = self.tx_manager.calculate_validity_window(
                    settings_datum.time_uncertainty_aggregation
                )
            else:
                window_length = (
                    validity_window.validity_end - validity_window.validity_start
                )
                if window_length > settings_datum.time_uncertainty_aggregation:
                    raise ValueError(
                        f"Incorrect validity window length: {window_length} > {settings_datum.time_uncertainty_aggregation}"
                    )
                if window_length <= 0:
                    raise ValueError(
                        f"Incorrect validity window length: {window_length}"
                    )

            validity_start, validity_end, current_time = [
                validity_window.validity_start,
                validity_window.validity_end,
                validity_window.current_time,
            ]

            validity_start_slot, validity_end_slot = self._validity_window_to_slot(
                validity_start, validity_end
            )

            account, agg_state = state_checks.find_account_pair(
                utxos, self.policy_id, current_time
            )

            # Don't re-sort! message.node_feeds_sorted_by_feed is already correctly
            # sorted by (feed_value, VKH) from build_aggregate_message
            sorted_feeds = message.node_feeds_sorted_by_feed

            logger.debug(
                "Using %d node feeds in correct (feed, VKH) order", len(sorted_feeds)
            )

            # Calculate median using sorted feeds
            feeds = list(sorted_feeds.values())
            node_count = len(sorted_feeds)
            median_value = calc_methods.median(feeds, node_count)

            # Update fees according to the rate feed
            reward_prices = deepcopy(settings_datum.fee_info.reward_prices)
            if settings_datum.fee_info.rate_nft != NoDatum():
                oracle_fee_rate_utxo = common.get_fee_rate_reference_utxo(
                    self.tx_manager.chain_query, settings_datum.fee_info.rate_nft
                )
                if oracle_fee_rate_utxo.output.datum is None:
                    raise ValueError(
                        "Oracle fee rate datum is None. "
                        "A valid fee rate datum is required to scale rewards."
                    )

                standard_datum: AggState = oracle_fee_rate_utxo.output.datum
                reference_inputs.add(oracle_fee_rate_utxo)
                rewards.scale_rewards_by_rate(
                    reward_prices,
                    standard_datum,
                )

            # Calculate minimum fee
            minimum_fee = rewards.calculate_min_fee_amount(reward_prices, node_count)

            # Create outputs using helper methods
            account_output = self._create_reward_account_output(
                account=account,
                sorted_node_feeds=sorted_feeds,
                node_reward_price=reward_prices.node_fee,
                iqr_fence_multiplier=settings_datum.iqr_fence_multiplier,
                median_divergency_factor=settings_datum.median_divergency_factor,
                allowed_nodes=settings_datum.nodes,
                minimum_fee=minimum_fee,
                last_update_time=current_time,
            )

            agg_state_output = self._create_agg_state_output(
                agg_state=agg_state,
                median_value=median_value,
                current_time=current_time,
                liveness_period=settings_datum.aggregation_liveness_period,
            )

            account_redeemer = Redeemer(OdvAggregate.create_sorted(sorted_feeds))
            aggstate_redeemer = Redeemer(OdvAggregateMsg())

            # Log redeemer for debugging
            try:
                logger.debug(
                    "Account redeemer CBOR: %s", account_redeemer.to_cbor().hex()[:200]
                )
            except Exception as e:
                logger.warning("Failed to dump redeemer CBOR: %s", e)

            required_signers = sorted(sorted_feeds.keys(), key=lambda vkh: vkh.payload)
            tx = await self.tx_manager.build_script_tx(
                script_inputs=[
                    (account, account_redeemer, script_utxo),
                    (agg_state, aggstate_redeemer, script_utxo),
                ],
                script_outputs=[account_output, agg_state_output],
                reference_inputs=reference_inputs,
                required_signers=required_signers,
                change_address=change_address,
                signing_key=signing_key,
                validity_start=validity_start_slot,
                validity_end=validity_end_slot,
            )

            return OdvResult(
                tx,
                account_output,
                agg_state_output,
                sorted_required_signers=required_signers,
            )

        except Exception as e:
            raise TransactionError(f"Failed to build ODV transaction: {e}") from e

    def _create_reward_account_output(
        self,
        account: UTxO,
        sorted_node_feeds: dict[VerificationKeyHash, int],
        node_reward_price: int,
        iqr_fence_multiplier: int,
        median_divergency_factor: int,
        allowed_nodes: Nodes,
        minimum_fee: int,
        last_update_time: PosixTime,
    ) -> TransactionOutput:
        account_output = deepcopy(account.output)
        self._add_reward_to_output(account_output, minimum_fee)

        # Ensure in_distribution is sorted by VKH in ascending order
        raw_in_distribution = account_output.datum.datum.nodes_to_rewards
        in_distribution = dict(
            sorted(raw_in_distribution.items(), key=lambda x: x[0].payload)
        )

        message = AggregateMessage(node_feeds_sorted_by_feed=sorted_node_feeds)

        out_nodes_to_rewards = rewards.calculate_reward_distribution(
            message,
            iqr_fence_multiplier,
            median_divergency_factor,
            in_distribution,
            node_reward_price,
            allowed_nodes.as_mapping(),
        )

        return self._create_final_output(
            account_output,
            out_nodes_to_rewards,
            last_update_time,
        )

    def _add_reward_to_output(
        self, transport_output: TransactionOutput, minimum_fee: int
    ) -> None:
        """
        Add fees to the transport output based on reward token configuration.

        Args:
            transport_output: The output to add fees to
            minimum_fee: The fee amount to add
        """
        if not (self.reward_token_hash or self.reward_token_name):
            transport_output.amount.coin += minimum_fee
            return

        self._add_token_fees(transport_output, minimum_fee)

    def _add_token_fees(
        self, transport_output: TransactionOutput, minimum_fee: int
    ) -> None:
        """
        Add token-based fees to the output.

        Args:
            transport_output: The output to add token fees to
            minimum_fee: The fee amount to add
        """
        token_hash = self.reward_token_hash
        token_name = self.reward_token_name

        if (
            token_hash in transport_output.amount.multi_asset
            and token_name in transport_output.amount.multi_asset[token_hash]
        ):
            transport_output.amount.multi_asset[token_hash][token_name] += minimum_fee
        else:
            fee_asset = MultiAsset({token_hash: Asset({token_name: minimum_fee})})
            transport_output.amount.multi_asset += fee_asset

    def _create_final_output(
        self,
        account_output: TransactionOutput,
        nodes_to_rewards: dict[VerificationKeyHash, int],
        last_update_time: PosixTime,
    ) -> TransactionOutput:
        """
        Create the final transaction output with all necessary data.

        Args:
            account_output: The processed account output
            nodes_to_rewards: Mapping of nodes to their rewards
            last_update_time: Last update timestamp

        Returns:
            TransactionOutput: The final transaction output
        """
        return TransactionOutput(
            address=self.script_address,
            amount=account_output.amount,
            datum=RewardAccountVariant(
                RewardAccountDatum.sort_account(nodes_to_rewards, last_update_time)
            ),
        )

    def _create_agg_state_output(
        self,
        agg_state: UTxO,
        median_value: int,
        current_time: int,
        liveness_period: int,
    ) -> TransactionOutput:
        """Helper method to create agg state output with consistent timestamp."""
        return TransactionOutput(
            address=self.script_address,
            amount=agg_state.output.amount,
            datum=AggState(
                price_data=PriceData.set_price_map(
                    median_value, current_time, current_time + liveness_period
                )
            ),
        )

    def _validity_window_to_slot(
        self, validity_start: int, validity_end: int
    ) -> tuple[int, int]:
        """Convert validity window to slot numbers."""
        validity_start_slot = self.network_config.posix_to_slot(validity_start)
        validity_end_slot = self.network_config.posix_to_slot(validity_end)
        return validity_start_slot, validity_end_slot
