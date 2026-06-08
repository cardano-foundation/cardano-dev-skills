"""Dismiss Reward builder"""

import logging
from copy import deepcopy
from dataclasses import dataclass, replace

import click
from pycardano import (
    Address,
    AssetName,
    MultiAsset,
    NativeScript,
    Network,
    Redeemer,
    ScriptHash,
    TransactionOutput,
    UTxO,
    Value,
    VerificationKeyHash,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.network import NetworkConfig
from charli3_offchain_core.cli.base import LoadedKeys
from charli3_offchain_core.cli.config.formatting import (
    print_information,
    print_progress,
    print_status,
    print_title,
)
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.base import PosixTimeDiff
from charli3_offchain_core.models.oracle_datums import (
    NoDatum,
    RewardAccountDatum,
    RewardAccountVariant,
    SomeAsset,
)
from charli3_offchain_core.models.oracle_redeemers import (
    DismissRewards,
)
from charli3_offchain_core.oracle.exceptions import (
    DismissRewardCancelledError,
    NoExpiredTransportsYetError,
    NoPendingTransportsFoundError,
    NoRewardsAvailableError,
)
from charli3_offchain_core.oracle.rewards.base import BaseBuilder, RewardTxResult
from charli3_offchain_core.oracle.utils import asset_checks
from charli3_offchain_core.oracle.utils.common import (
    get_reference_script_utxo,
)
from charli3_offchain_core.oracle.utils.state_checks import (
    convert_cbor_to_reward_accounts,
    filter_reward_accounts,
    get_oracle_settings_by_policy_id,
)

logger = logging.getLogger(__name__)


@dataclass
class ValidityWindow:
    """Represents the validity window for a transaction."""

    start: int
    end: int
    current_time: int


class DismissRewardsBuilder(BaseBuilder):
    FEE_BUFFER = 10_000

    async def build_tx(
        self,
        platform_utxo: UTxO,
        platform_script: NativeScript,
        policy_hash: ScriptHash,
        script_address: Address,
        contract_utxos: list[UTxO],
        ref_script_config: ReferenceScriptConfig,
        reward_token: NoDatum | SomeAsset,
        loaded_key: LoadedKeys,
        network: Network,
        reward_dismission_period_length: int,
        max_inputs: int,
        required_signers: list[VerificationKeyHash] | None = None,
    ) -> RewardTxResult:
        try:

            # Input Core Settings UTxO
            in_core_datum, in_core_utxo = get_oracle_settings_by_policy_id(
                contract_utxos, policy_hash
            )

            # Contract Script
            script_utxo = await get_reference_script_utxo(
                self.tx_manager.chain_query,
                ref_script_config,
                script_address,
            )

            # validity window
            validity_window = self._calculate_validity_window(
                in_core_datum.time_uncertainty_platform
            )

            # Conversion
            start_slot, end_slot = validity_window_to_slot(
                self.tx_manager.chain_query.config.network_config,
                validity_window.start,
                validity_window.end,
            )
            # Find reward accounts and calculate accumulated rewards
            eligible_reward_accounts, platform_reward = self.find_reward_accounts(
                max_inputs,
                contract_utxos,
                policy_hash,
                validity_window,
                reward_dismission_period_length,
            )

            # Create empty reward account outputs
            empty_reward_accounts = create_empty_reward_accounts(
                eligible_reward_accounts,
                in_core_datum.utxo_size_safety_buffer,
                reward_token,
            )

            # Check if rewards are worth collecting
            # If too small for ADA, skip creating platform reward output
            create_reward_output = True
            if (
                isinstance(reward_token, NoDatum)
                and platform_reward < self.MIN_UTXO_VALUE
            ):
                logger.info(
                    f"Platform reward ({platform_reward:_} lovelace) is too small for a UTxO, will go to change"
                )
                create_reward_output = False

            # Get withdrawal address if we're creating an output
            if create_reward_output:
                requested_address = await confirm_withdrawal_amount_and_address(
                    loaded_key,
                    reward_token,
                    platform_reward,
                    network,
                    len(empty_reward_accounts),
                )

                # Create withdrawal output UTxO
                out_platform_reward = self.platform_operator_output(
                    requested_address,
                    reward_token,
                    platform_reward,
                )
            else:
                out_platform_reward = None

            # Build transaction
            reward_account_inputs = [
                (account, Redeemer(DismissRewards()), script_utxo)
                for account in eligible_reward_accounts
            ]

            platform_auth = (platform_utxo, None, platform_script)

            # Build outputs list
            script_outputs = [
                *empty_reward_accounts,
                platform_utxo.output,
            ]
            if out_platform_reward:
                script_outputs.append(out_platform_reward)

            logger.info(
                f"Building transaction with {len(empty_reward_accounts)} empty reward account outputs"
            )
            logger.info(f"Empty reward accounts: {empty_reward_accounts}")
            logger.info(f"Script outputs count: {len(script_outputs)}")

            tx = await self.tx_manager.build_script_tx(
                script_inputs=[*reward_account_inputs, platform_auth],
                script_outputs=script_outputs,
                reference_inputs=[in_core_utxo],
                change_address=loaded_key.address,
                signing_key=loaded_key.payment_sk,
                validity_start=start_slot,
                validity_end=end_slot,
                required_signers=required_signers,
                fee_buffer=self.FEE_BUFFER,
            )

            return RewardTxResult(transaction=tx)

        except NoRewardsAvailableError as e:
            logging.error("No rewards available error")
            return RewardTxResult(exception_type=e)

        except NoPendingTransportsFoundError as e:
            logging.error("No pending transports found")
            return RewardTxResult(exception_type=e)

        except DismissRewardCancelledError as e:
            logging.error("Dismiss Reward cancelled")
            return RewardTxResult(exception_type=e)

        except NoExpiredTransportsYetError as e:
            logging.error("No expired transports yet")
            return RewardTxResult(exception_type=e)

    def _calculate_validity_window(
        self,
        time_uncertainty_platform: PosixTimeDiff,
    ) -> ValidityWindow:
        """Calculate the validity window for transactions."""
        start, end, current = calculate_validity_window(
            self.tx_manager.chain_query,
            time_uncertainty_platform,
        )

        return ValidityWindow(start=start, end=end, current_time=current)

    def _must_be_after_dismissing_period(
        self,
        reward_accounts: list[UTxO],
        validity_window: ValidityWindow,
        reward_dismissal_period_length: int,
    ) -> list[UTxO]:
        """
        Filter reward accounts that have exceeded the reward dismissal period.

        Args:
            reward_accounts: List of reward account UTxO objects to filter
            validity_window: Transaction validation information
            reward_dismissal_period_length: Length of the dismissal period

        Returns:
            List of reward account UTxO objects that have exceeded the dismissal period
        """
        eligible_accounts = []
        start_slot = validity_window.start

        if start_slot is None:
            raise ValueError("start_slot is None")

        for account in reward_accounts:
            account_datum = account.output.datum

            if not isinstance(account_datum, RewardAccountVariant):
                continue

            if not isinstance(account_datum.datum, RewardAccountDatum):
                continue

            # Last update time from the reward account
            last_update_time = account_datum.datum.last_update_time

            # Dismissal start
            expiration_time = last_update_time + reward_dismissal_period_length

            logger.info(f"Last update time: {last_update_time}")
            logger.info(f"Expiration time: {expiration_time}")
            logger.info(f"Start tx validation: {start_slot}")
            # Check if the dismissal period has passed and the validity start transaction can begin.
            if expiration_time <= start_slot:
                logger.info("Account is eligible for dismissal")
                eligible_accounts.append(account)
            else:
                logger.info(
                    f"Account NOT eligible - expiration_time {expiration_time} > start_slot {start_slot}"
                )

        logger.info(
            f"Total eligible accounts after time validation: {len(eligible_accounts)}"
        )
        return eligible_accounts

    def find_reward_accounts(
        self,
        max_inputs: int,
        input_utxos: list[UTxO],
        policy_id: ScriptHash,
        validity_window: ValidityWindow,
        reward_dismission_period_length: int,
    ) -> tuple[list[UTxO], int]:
        """Find reward account UTxOs that are eligible for dismissal.

        Args:
            max_inputs: Maximum number of reward accounts to process
            input_utxos: All available UTxOs
            policy_id: Policy ID for filtering C3RA tokens
            validity_window: Transaction validity window
            reward_dismission_period_length: Period after which rewards can be dismissed

        Returns:
            Tuple of (eligible reward accounts, total rewards amount)
        """
        # Filter by C3RA token
        c3ra_utxos = asset_checks.filter_utxos_by_token_name(
            input_utxos, policy_id, "C3RA"
        )
        logger.info(f"Found {len(c3ra_utxos)} UTxOs with C3RA token")

        # Convert CBOR to reward account objects
        converted_utxos = convert_cbor_to_reward_accounts(c3ra_utxos)
        logger.info(
            f"Converted {len(converted_utxos)} UTxOs from CBOR to RewardAccountVariant"
        )

        # Filter for reward accounts
        reward_account_utxos = filter_reward_accounts(converted_utxos)[:max_inputs]
        logger.info(f"Found {len(reward_account_utxos)} reward account UTxOs")

        # Debug: print first reward account if available
        if reward_account_utxos:
            first_account = reward_account_utxos[0]
            logger.info(f"First reward account UTxO: {first_account.input}")
            logger.info(f"First reward account datum: {first_account.output.datum}")

        if not reward_account_utxos:
            raise NoPendingTransportsFoundError("No reward account UTxOs found")

        # Filter accounts that have passed the dismissing period
        validated_reward_accounts = self._must_be_after_dismissing_period(
            reward_account_utxos,
            validity_window,
            reward_dismission_period_length,
        )
        if not validated_reward_accounts:
            raise NoExpiredTransportsYetError(
                "No expired reward account UTxOs found\n"
                f"Total reward account UTxOs: {len(reward_account_utxos)}\n"
            )

        # Filter out accounts with no rewards (empty nodes_to_rewards)
        accounts_with_rewards = [
            account
            for account in validated_reward_accounts
            if sum(account.output.datum.datum.nodes_to_rewards.values()) > 0
        ]

        logger.info(
            f"Accounts with rewards: {len(accounts_with_rewards)} out of {len(validated_reward_accounts)}"
        )

        if not accounts_with_rewards:
            raise NoRewardsAvailableError(
                "All eligible reward accounts are empty (no rewards to dismiss)"
            )

        # Calculate total rewards across all nodes in all accounts
        total_claimable_rewards = sum(
            sum(account.output.datum.datum.nodes_to_rewards.values())
            for account in accounts_with_rewards
        )
        return accounts_with_rewards, total_claimable_rewards

    def platform_operator_output(
        self,
        address: Address,
        reward_token: SomeAsset | NoDatum,
        platform_reward: int,
    ) -> TransactionOutput:
        """Creates a transaction output for a node operator.

        Args:
            address: The address of the platform operator
            reward_token: The reward token (SomeAsset) or NoDatum if ADA.
            platform_reward: The amount of the reward.

        Returns:
            A TransactionOutput object.

        """

        if isinstance(reward_token, NoDatum):
            if platform_reward < self.MIN_UTXO_VALUE:
                raise NoRewardsAvailableError(
                    f"The ADA amount is too small {platform_reward:_}"
                )
            value = Value(coin=platform_reward)
        elif isinstance(reward_token, SomeAsset):
            payment_asset = MultiAsset.from_primitive(
                {
                    reward_token.asset.policy_id: {
                        reward_token.asset.name: platform_reward
                    }
                }
            )
            value = Value(coin=self.MIN_UTXO_VALUE, multi_asset=payment_asset)

        return TransactionOutput(address=address, amount=value)


def create_empty_reward_accounts(
    reward_accounts: list[UTxO],
    safety_buffer: int,
    reward_token: NoDatum | SomeAsset,
) -> list[TransactionOutput]:
    """Create empty reward account outputs from a list of reward account UTxOs.

    Args:
        reward_accounts: List of reward account UTxOs to empty
        safety_buffer: Minimum ADA to keep in the UTxO
        reward_token: Type of reward token (ADA or custom asset)

    Returns:
        List of transaction outputs with empty reward accounts
    """
    empty_accounts = [
        create_empty_reward_account(account, safety_buffer, reward_token)
        for account in reward_accounts
    ]
    return empty_accounts


def create_empty_reward_account(
    reward_account: UTxO, safety_buffer: int, reward_token: NoDatum | SomeAsset
) -> TransactionOutput:
    """Create empty reward account output.

    Args:
        reward_account: The reward account UTxO to empty
        safety_buffer: Minimum ADA to keep in the UTxO
        reward_token: Type of reward token (ADA or custom asset)

    Returns:
        TransactionOutput with empty RewardAccountDatum
    """
    modified_utxo = deepcopy(reward_account)

    # Remove reward tokens from the output
    if isinstance(reward_token, SomeAsset):
        policy_id_bytes = reward_token.asset.policy_id
        policy_id = ScriptHash.from_primitive(policy_id_bytes.hex())

        asset_name_bytes = reward_token.asset.name
        asset_name = AssetName(asset_name_bytes)

        # Set reward token quantity to 0 (if it exists)
        if policy_id in modified_utxo.output.amount.multi_asset:
            if asset_name in modified_utxo.output.amount.multi_asset[policy_id]:
                modified_utxo.output.amount.multi_asset[policy_id][asset_name] = 0
        # If there are no reward tokens, that's fine - the account is already empty
    elif isinstance(reward_token, NoDatum):
        # Set ADA to just the safety buffer
        modified_utxo.output.amount.coin = safety_buffer

    # Return output with empty reward account datum
    return replace(
        modified_utxo.output,
        datum=RewardAccountVariant(datum=RewardAccountDatum.empty()),
        datum_hash=None,
    )


def calculate_validity_window(
    chain_query: ChainQuery, time_absolute_uncertainty: int
) -> tuple[int, int, int]:
    """Calculate transaction validity window and current time."""
    validity_start = chain_query.get_current_posix_chain_time_ms()
    validity_end = validity_start + time_absolute_uncertainty
    current_time = (validity_end + validity_start) // 2
    return validity_start, validity_end, current_time


def validity_window_to_slot(
    network_config: NetworkConfig | None, validity_start: int, validity_end: int
) -> tuple[int, int]:
    """Convert validity window to slot numbers."""
    validity_start_slot = network_config.posix_to_slot(validity_start)
    validity_end_slot = network_config.posix_to_slot(validity_end)
    return validity_start_slot, validity_end_slot


async def confirm_withdrawal_amount_and_address(
    loaded_key: LoadedKeys,
    reward_token: SomeAsset | NoDatum,
    platform_reward: int,
    network: Network,
    total_accounts: int,
) -> Address:
    """
    Prompts the user to confirm or change an address for reward withdrawal.

    Args:
        loaded_key: User's wallet keys
        reward_token: Type of reward token (ADA or custom asset)
        platform_reward: Total reward amount to withdraw
        network: Cardano network (mainnet/testnet)
        total_accounts: Number of reward accounts to process

    Returns:
        Address where rewards will be sent
    """
    print_progress("Loading wallet configuration...")

    symbol = "₳ (lovelace)" if isinstance(reward_token, NoDatum) else "C3 (Charli3)"

    print_status(
        "Verification Key Hash associated with user's wallet",
        message=f"{loaded_key.payment_vk.hash()}",
    )

    print_information(f"Total Accumulated Rewards: {platform_reward:_} {symbol}")
    print_information(f"Total Reward Accounts to process: {total_accounts}")

    print_title(
        "Select a withdrawal address (derived from your mnemonic configuration):"
    )

    enterprise_addr = Address(
        payment_part=loaded_key.payment_vk.hash(), network=network
    )

    click.secho("1. Base Address:", fg="blue")
    print(loaded_key.address)
    click.secho("2. Enterprise Address", fg="blue")
    print(enterprise_addr)
    click.secho("3. Enter a new address", fg="blue")
    click.secho("q. Quit", fg="blue")

    while True:  # Loop until valid choice is made
        choice = click.prompt(
            "Enter your choice (1-3, q):",
            type=click.Choice(["1", "2", "3", "q"]),  # Add 'q' to choices
            default="1",  # Default to the base address
        )

        if choice == "q":
            click.echo("Exiting.")
            raise DismissRewardCancelledError()
        elif choice == "1":
            return loaded_key.address
        elif choice == "2":
            return enterprise_addr
        else:  # choice == "3"
            while True:  # Keep prompting until a valid address is entered
                new_address_str = click.prompt(
                    "Please enter a new address (or 'q' to quit)"
                )
                if new_address_str.lower() == "q":
                    click.echo("Exiting.")
                    raise DismissRewardCancelledError()
                try:
                    new_address = Address.from_primitive(new_address_str)
                    return new_address
                except Exception as e:
                    click.echo(
                        f"Invalid Cardano address format: {e}. Please try again."
                    )
