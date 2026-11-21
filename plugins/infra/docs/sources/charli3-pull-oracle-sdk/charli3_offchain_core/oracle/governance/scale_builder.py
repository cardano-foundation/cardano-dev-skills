"""Oracle scaling transaction builder for managing ODV capacity."""

import logging
from dataclasses import dataclass

from pycardano import (
    Address,
    ExtendedSigningKey,
    MultiAsset,
    NativeScript,
    PaymentSigningKey,
    Redeemer,
    ScriptHash,
    Transaction,
    TransactionOutput,
    UTxO,
    Value,
    VerificationKeyHash,
)

from charli3_offchain_core.blockchain.transactions import TransactionManager
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.oracle_datums import (
    AggState,
    PriceData,
    RewardAccountDatum,
    RewardAccountVariant,
)
from charli3_offchain_core.models.oracle_redeemers import (
    Scale,
    ScaleDown,
)
from charli3_offchain_core.oracle.exceptions import (
    ScalingError,
    StateValidationError,
)
from charli3_offchain_core.oracle.utils.asset_checks import (
    filter_utxos_by_token_name,
)
from charli3_offchain_core.oracle.utils.common import get_reference_script_utxo
from charli3_offchain_core.oracle.utils.state_checks import (
    convert_cbor_to_reward_accounts,
    filter_valid_agg_states,
    get_oracle_settings_by_policy_id,
)

logger = logging.getLogger(__name__)


@dataclass
class ScaleUpResult:
    """Result of scale up transaction."""

    transaction: Transaction
    new_reward_account_outputs: list[TransactionOutput]
    new_agg_state_outputs: list[TransactionOutput]


@dataclass
class ScaleDownResult:
    """Result of scale down transaction."""

    transaction: Transaction
    removed_reward_account_utxos: list[UTxO]
    removed_agg_state_utxos: list[UTxO]


class OracleScaleBuilder:
    """Builder for scaling ODV capacity up or down."""

    MIN_UTXO_VALUE = 2_000_000

    def __init__(
        self,
        tx_manager: TransactionManager,
        script_address: Address,
        policy_id: ScriptHash,
        ref_script_config: ReferenceScriptConfig,
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
        self.network_config = self.tx_manager.chain_query.config.network_config
        self._standard_min_ada = self.MIN_UTXO_VALUE

    async def build_scale_up_tx(
        self,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        utxos: list[UTxO],
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        reward_account_count: int = 0,
        aggstate_count: int = 0,
        required_signers: list[VerificationKeyHash] | None = None,
        reward_account_name: str = "C3RA",
        aggstate_name: str = "C3AS",
    ) -> ScaleUpResult:
        """Build transaction to increase ODV capacity by creating new RewardAccount and/or AggState UTxOs.

        Args:
            platform_utxo: Platform authentication UTxO
            platform_script: Platform script
            utxos: All script UTxOs
            change_address: Address for change
            signing_key: Signing key
            reward_account_count: Number of RewardAccount UTxOs to create (default 0)
            aggstate_count: Number of AggState UTxOs to create (default 0)
            required_signers: Optional required signers
            reward_account_name: Token name for reward accounts (default "C3RA")
            aggstate_name: Token name for agg states (default "C3AS")

        Returns:
            ScaleUpResult with transaction and created outputs
        """
        try:
            if reward_account_count == 0 and aggstate_count == 0:
                raise ValueError(
                    "At least one of reward_account_count or aggstate_count must be greater than 0"
                )

            script_utxo = await get_reference_script_utxo(
                self.tx_manager.chain_query,
                self.ref_script_config,
                self.script_address,
            )
            if not script_utxo:
                raise ValueError("Reference script UTxO not found")

            # Get standard min ADA from core settings
            _, settings_utxo = get_oracle_settings_by_policy_id(utxos, self.policy_id)
            self._standard_min_ada = settings_utxo.output.amount.coin
            logger.info(
                "Using standard min ADA amount: %s lovelace", self._standard_min_ada
            )
            logger.info(
                "Creating %d RewardAccount and %d AggState UTxOs",
                reward_account_count,
                aggstate_count,
            )

            # Create new empty RewardAccount outputs
            new_reward_account_outputs = [
                TransactionOutput(
                    address=self.script_address,
                    amount=Value(
                        coin=self._standard_min_ada,
                        multi_asset=MultiAsset.from_primitive(
                            {self.policy_id.payload: {reward_account_name.encode(): 1}}
                        ),
                    ),
                    datum=RewardAccountVariant(datum=RewardAccountDatum.empty()),
                )
                for _ in range(reward_account_count)
            ]

            # Create new empty AggState outputs
            new_agg_state_outputs = [
                TransactionOutput(
                    address=self.script_address,
                    amount=Value(
                        coin=self._standard_min_ada,
                        multi_asset=MultiAsset.from_primitive(
                            {self.policy_id.payload: {aggstate_name.encode(): 1}}
                        ),
                    ),
                    datum=AggState(price_data=PriceData.empty()),
                )
                for _ in range(aggstate_count)
            ]

            # Get minting script
            nft_minting_script = await self.tx_manager.chain_query.get_plutus_script(
                self.policy_id
            )

            # Build mint map with only non-zero amounts
            mint_map = {}
            if reward_account_count > 0:
                mint_map[reward_account_name.encode()] = reward_account_count
            if aggstate_count > 0:
                mint_map[aggstate_name.encode()] = aggstate_count

            mint = MultiAsset.from_primitive({self.policy_id.payload: mint_map})

            # Build transaction using TransactionManager
            tx = await self.tx_manager.build_script_tx(
                script_inputs=[
                    (platform_utxo, None, platform_script),
                ],
                script_outputs=[
                    *new_reward_account_outputs,
                    *new_agg_state_outputs,
                    platform_utxo.output,
                ],
                reference_inputs={settings_utxo},
                mint=mint,
                mint_redeemer=Redeemer(Scale()),
                mint_script=nft_minting_script,
                required_signers=required_signers,
                change_address=change_address,
                signing_key=signing_key,
            )

            return ScaleUpResult(
                transaction=tx,
                new_reward_account_outputs=new_reward_account_outputs,
                new_agg_state_outputs=new_agg_state_outputs,
            )

        except Exception as e:
            raise ScalingError(f"Failed to build scale up transaction: {e}") from e

    async def build_scale_down_tx(  # noqa: C901
        self,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        utxos: list[UTxO],
        change_address: Address,
        signing_key: PaymentSigningKey | ExtendedSigningKey,
        reward_account_count: int = 0,
        aggstate_count: int = 0,
        required_signers: list[VerificationKeyHash] | None = None,
    ) -> ScaleDownResult:
        """Build transaction to decrease ODV capacity by removing RewardAccount and/or AggState UTxOs.

        Args:
            platform_utxo: Platform authentication UTxO
            platform_script: Platform script
            utxos: All script UTxOs
            change_address: Address for change
            signing_key: Signing key
            reward_account_count: Number of empty RewardAccount UTxOs to remove (default 0)
            aggstate_count: Number of empty/expired AggState UTxOs to remove (default 0)
            required_signers: Optional required signers

        Returns:
            ScaleDownResult with transaction and removed UTxOs
        """
        try:
            if reward_account_count == 0 and aggstate_count == 0:
                raise ValueError(
                    "At least one of reward_account_count or aggstate_count must be greater than 0"
                )

            # Log initial parameters
            logger.info(
                "Starting scale down transaction build for %d RewardAccount(s) and %d AggState(s)",
                reward_account_count,
                aggstate_count,
            )

            script_utxo = await get_reference_script_utxo(
                self.tx_manager.chain_query,
                self.ref_script_config,
                self.script_address,
            )
            if not script_utxo:
                logger.error("Reference script UTxO not found")
                raise ValueError("Reference script UTxO not found")

            # Find and log UTxOs to remove
            reward_account_utxos = filter_utxos_by_token_name(
                utxos, self.policy_id, "C3RA"
            )
            aggstate_utxos = filter_utxos_by_token_name(utxos, self.policy_id, "C3AS")

            logger.info(
                "Found UTxOs - Total RewardAccounts: %d, Total AggStates: %d",
                len(reward_account_utxos),
                len(aggstate_utxos),
            )

            # Convert CBOR to RewardAccountDatum objects and get empty reward accounts
            all_reward_accounts = convert_cbor_to_reward_accounts(reward_account_utxos)
            empty_reward_accounts = [
                utxo
                for utxo in all_reward_accounts
                if utxo.output.datum.datum.length == 0
            ]
            logger.info(
                "Empty RewardAccount UTxOs found: %d (need %d)",
                len(empty_reward_accounts),
                reward_account_count,
            )

            # Get current time for filtering expired agg states
            current_time = self.tx_manager.chain_query.get_current_posix_chain_time_ms()

            # Get expired/empty agg states with detailed logging
            expired_and_empty_agg_states = filter_valid_agg_states(
                aggstate_utxos, current_time
            )
            logger.info(
                "Valid AggState UTxOs found: %d (need %d)",
                len(expired_and_empty_agg_states),
                aggstate_count,
            )

            # Validate we have enough UTxOs to remove
            if (
                reward_account_count > 0
                and len(empty_reward_accounts) < reward_account_count
            ):
                error_msg = (
                    f"Insufficient empty RewardAccount UTxOs for scaling down. "
                    f"Found {len(empty_reward_accounts)} empty reward accounts, "
                    f"need {reward_account_count}"
                )
                logger.error(error_msg)
                raise StateValidationError(error_msg)

            if (
                aggstate_count > 0
                and len(expired_and_empty_agg_states) < aggstate_count
            ):
                error_msg = (
                    f"Insufficient empty/expired AggState UTxOs for scaling down. "
                    f"Found {len(expired_and_empty_agg_states)} valid agg states, "
                    f"need {aggstate_count}"
                )
                logger.error(error_msg)
                raise StateValidationError(error_msg)

            # Select the specific UTxOs to use
            selected_reward_accounts = (
                empty_reward_accounts[:reward_account_count]
                if reward_account_count > 0
                else []
            )
            selected_agg_states = (
                expired_and_empty_agg_states[:aggstate_count]
                if aggstate_count > 0
                else []
            )

            # Log RewardAccount UTxO details
            for i, utxo in enumerate(selected_reward_accounts):
                logger.info(
                    "RewardAccount UTxO %d: TxId=%s#%d (empty)",
                    i + 1,
                    utxo.input.transaction_id,
                    utxo.input.index,
                )

            # Log AggState UTxO details
            for i, utxo in enumerate(selected_agg_states):
                datum = utxo.output.datum
                if isinstance(datum, AggState):
                    if datum.price_data.is_empty:
                        state_type = "Empty"
                        expiry = None
                    else:
                        state_type = "Expired"
                        expiry = datum.price_data.get_expiration_time

                    logger.info(
                        "AggState UTxO %d: TxId=%s#%d, Type=%s, Expiry=%s",
                        i + 1,
                        utxo.input.transaction_id,
                        utxo.input.index,
                        state_type,
                        expiry,
                    )

            # Get minting script for burning
            nft_minting_script = await self.tx_manager.chain_query.get_plutus_script(
                self.policy_id
            )

            # Build burn map with only non-zero amounts (negative for burning)
            mint_map = {}
            if reward_account_count > 0:
                mint_map[b"C3RA"] = -reward_account_count
            if aggstate_count > 0:
                mint_map[b"C3AS"] = -aggstate_count

            mint = MultiAsset.from_primitive({self.policy_id.payload: mint_map})

            # Prepare script inputs
            script_inputs = [
                (utxo, Redeemer(ScaleDown()), script_utxo)
                for utxo in (selected_reward_accounts + selected_agg_states)
            ]

            # Build transaction using TransactionManager
            tx = await self.tx_manager.build_script_tx(
                script_inputs=[(platform_utxo, None, platform_script), *script_inputs],
                script_outputs=[platform_utxo.output],
                mint=mint,
                mint_redeemer=Redeemer(Scale()),
                mint_script=nft_minting_script,
                required_signers=required_signers,
                change_address=change_address,
                signing_key=signing_key,
            )

            return ScaleDownResult(
                transaction=tx,
                removed_reward_account_utxos=selected_reward_accounts,
                removed_agg_state_utxos=selected_agg_states,
            )

        except Exception as e:
            raise ScalingError(f"Failed to build scale down transaction: {e}") from e
