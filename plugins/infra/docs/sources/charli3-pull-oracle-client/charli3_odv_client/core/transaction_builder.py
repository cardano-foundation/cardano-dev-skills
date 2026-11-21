"""Oracle transaction builder."""

import logging
from copy import deepcopy
from dataclasses import dataclass
from typing import Dict, List

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

from charli3_odv_client.blockchain.transactions import (
    TransactionManager,
    ValidityWindow,
)
from charli3_odv_client.config.reference_script import ReferenceScriptConfig
from charli3_odv_client.models.base import PosixTime
from charli3_odv_client.models.datums import (
    AggState,
    NoDatum,
    Nodes,
    PriceData,
    RewardAccountDatum,
    RewardAccountVariant,
)
from charli3_odv_client.models.redeemers import (
    OdvAggregate,
    OdvAggregateMsg,
    AggregateMessage,
)
from charli3_odv_client.exceptions import (
    OracleTransactionError,
)
from charli3_odv_client.utils.oracle import (
    utxo_filters,
    chain_operations,
    reward_calculations,
    state_validation,
)
from charli3_odv_client.core.aggregation import build_aggregate_message
from charli3_odv_client.utils.math import median

from charli3_odv_client.models.message import SignedOracleNodeMessage

logger = logging.getLogger(__name__)


@dataclass
class OdvResult:
    """Result of ODV transaction."""

    transaction: Transaction
    account_output: TransactionOutput
    agg_state_output: TransactionOutput
    sorted_required_signers: List[VerificationKeyHash]
    aggregate_message: AggregateMessage
    median_value: int


class ODVTransactionBuilder:
    """Builder for Oracle transactions."""

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
            tx_manager: Transaction manager for blockchain interactions
            script_address: Oracle script address
            policy_id: Policy ID for oracle NFTs
            ref_script_config: Reference script configuration
            reward_token_hash: Optional reward token policy hash
            reward_token_name: Optional reward token name
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
        node_messages: dict[str, SignedOracleNodeMessage],
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        change_address: Address | None = None,
        validity_window: ValidityWindow | None = None,
    ) -> OdvResult:
        """Build ODV aggregation transaction.

        Args:
            node_messages: List of signed node messages
            signing_key: Signing key for transaction
            change_address: Optional change address
            validity_window: Optional validity window

        Returns:
            OdvResult containing transaction and outputs

        Raises:
            OracleTransactionError: If transaction building fails
        """
        try:
            # Get UTxOs and settings
            utxos = await chain_operations.get_script_utxos(
                self.script_address, self.tx_manager
            )

            settings_datum, settings_utxo = (
                state_validation.get_oracle_settings_by_policy_id(utxos, self.policy_id)
            )

            script_utxo = await chain_operations.get_reference_script_utxo(
                self.tx_manager.chain_query,
                self.ref_script_config,
                self.script_address,
            )
            reference_inputs = {settings_utxo}

            # Build aggregate message from node messages
            message = build_aggregate_message(list(node_messages.values()))

            # Calculate validity window
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
                        f"Incorrect validity window length: {window_length} > "
                        f"{settings_datum.time_uncertainty_aggregation}"
                    )
                if window_length <= 0:
                    raise ValueError(
                        f"Incorrect validity window length: {window_length}"
                    )

            validity_start = validity_window.validity_start
            validity_end = validity_window.validity_end
            current_time = validity_window.current_time

            validity_start_slot, validity_end_slot = self._validity_window_to_slot(
                validity_start, validity_end
            )

            account, agg_state = utxo_filters.find_account_pair(
                utxos, self.policy_id, current_time
            )

            sorted_feeds = message.node_feeds_sorted_by_feed

            feeds = list(sorted_feeds.values())
            node_count = len(sorted_feeds)
            median_value = median(feeds, node_count)

            reward_prices = deepcopy(settings_datum.fee_info.reward_prices)
            if settings_datum.fee_info.rate_nft != NoDatum():
                oracle_fee_rate_utxo = chain_operations.get_fee_rate_reference_utxo(
                    self.tx_manager.chain_query, settings_datum.fee_info.rate_nft
                )
                if oracle_fee_rate_utxo.output.datum is None:
                    raise ValueError(
                        "Oracle fee rate datum is None. "
                        "A valid fee rate datum is required to scale rewards."
                    )

                standard_datum: AggState = oracle_fee_rate_utxo.output.datum
                reference_inputs.add(oracle_fee_rate_utxo)
                reward_calculations.scale_rewards_by_rate(reward_prices, standard_datum)

            # Calculate minimum fee
            minimum_fee = reward_calculations.calculate_min_fee_amount(
                reward_prices, node_count
            )

            # Create outputs
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

            # Create redeemers
            account_redeemer = Redeemer(OdvAggregate.create_sorted(sorted_feeds))
            aggstate_redeemer = Redeemer(OdvAggregateMsg())

            # Build transaction
            tx = await self.tx_manager.build_script_tx(
                script_inputs=[
                    (account, account_redeemer, script_utxo),
                    (agg_state, aggstate_redeemer, script_utxo),
                ],
                script_outputs=[account_output, agg_state_output],
                reference_inputs=reference_inputs,
                required_signers=list(sorted_feeds.keys()),
                change_address=change_address,
                signing_key=signing_key,
                validity_start=validity_start_slot,
                validity_end=validity_end_slot,
            )

            return OdvResult(
                transaction=tx,
                account_output=account_output,
                agg_state_output=agg_state_output,
                sorted_required_signers=list(sorted_feeds.keys()),
                aggregate_message=message,
                median_value=median_value,
            )

        except Exception as e:
            raise OracleTransactionError(f"Failed to build ODV transaction: {e}") from e

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

        raw_in_distribution = account_output.datum.datum.nodes_to_rewards
        in_distribution = dict(
            sorted(raw_in_distribution.items(), key=lambda x: x[0].payload)
        )

        message = AggregateMessage(node_feeds_sorted_by_feed=sorted_node_feeds)

        out_nodes_to_rewards = reward_calculations.calculate_reward_distribution(
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
        nodes_to_rewards: Dict[VerificationKeyHash, int],
        last_update_time: PosixTime,
    ) -> TransactionOutput:
        """Create the final transaction output with all necessary data.

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
        """Create agg state output with consistent timestamp.

        Args:
            agg_state: Current agg state UTxO
            median_value: Calculated median value
            current_time: Current timestamp
            liveness_period: Liveness period for price data

        Returns:
            TransactionOutput for the agg state
        """
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
        """Convert validity window to slot numbers.

        Args:
            validity_start: Validity start time (POSIX milliseconds)
            validity_end: Validity end time (POSIX milliseconds)

        Returns:
            Tuple of (start_slot, end_slot)
        """
        validity_start_slot = self.network_config.posix_to_slot(validity_start)
        validity_end_slot = self.network_config.posix_to_slot(validity_end)
        return validity_start_slot, validity_end_slot
