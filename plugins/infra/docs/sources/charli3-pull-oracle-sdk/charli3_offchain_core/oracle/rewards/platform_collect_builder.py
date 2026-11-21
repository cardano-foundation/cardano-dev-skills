"""Platform transaction builder. """

import logging
from copy import deepcopy
from dataclasses import replace

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

from charli3_offchain_core.blockchain.exceptions import CollateralError
from charli3_offchain_core.cli.base import LoadedKeys
from charli3_offchain_core.cli.config.formatting import (
    print_information,
    print_progress,
    print_status,
    print_title,
)
from charli3_offchain_core.cli.config.reference_script import ReferenceScriptConfig
from charli3_offchain_core.models.oracle_datums import (
    NoDatum,
    OracleSettingsDatum,
    RewardAccountDatum,
    SomeAsset,
)
from charli3_offchain_core.models.oracle_redeemers import (
    PlatformCollect,
    RedeemRewards,
)
from charli3_offchain_core.oracle.exceptions import (
    CollectingPlatformError,
    NoRewardsAvailableError,
    PlatformCollectCancelled,
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


class PlatformCollectBuilder(BaseBuilder):
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

            # Find reward account UTxOs
            reward_accounts = self.find_reward_accounts(
                contract_utxos, policy_hash, max_inputs, in_core_datum, reward_token
            )

            if not reward_accounts:
                raise NoRewardsAvailableError("No reward account UTxOs found")

            logger.info(
                f"Found {len(reward_accounts)} reward account(s) to collect from"
            )

            # Calculate platform rewards from each account and create outputs
            total_platform_reward = 0
            reward_account_outputs = []
            reward_account_inputs = []

            for idx, reward_account in enumerate(reward_accounts):
                reward_datum = reward_account.output.datum.datum

                # Calculate platform reward and create modified output
                out_reward_utxo, platform_amount = self.modified_reward_utxo(
                    reward_account,
                    reward_datum,
                    in_core_datum,
                    reward_token,
                )

                total_platform_reward += platform_amount
                reward_account_outputs.append(out_reward_utxo.output)

                # Create redeemer with corresponding_out_ix pointing to output index
                redeemer = Redeemer(
                    RedeemRewards(collector=PlatformCollect(), corresponding_out_ix=idx)
                )
                reward_account_inputs.append((reward_account, redeemer, script_utxo))

                logger.info(
                    f"Account #{idx}: Platform reward = {platform_amount:_}, corresponding_out_ix = {idx}"
                )

            logger.info(f"Total platform reward: {total_platform_reward:_}")

            # Get withdrawal address
            requested_address = await confirm_withdrawal_amount_and_address(
                loaded_key,
                reward_token,
                total_platform_reward,
                network,
                len(reward_accounts),
            )

            # Create combined platform fee output
            out_platform_reward = self.platform_operator_output(
                requested_address,
                reward_token,
                total_platform_reward,
            )

            # Platform auth input
            platform_auth = (platform_utxo, None, platform_script)

            # Build outputs: [reward_out_1, reward_out_2, ..., platform_nft, combined_fee]
            script_outputs = [
                *reward_account_outputs,
                platform_utxo.output,
                out_platform_reward,
            ]

            logger.info(
                f"Building transaction with {len(reward_account_inputs)} reward account inputs"
            )
            logger.info(
                f"Output order: {len(reward_account_outputs)} reward accounts, 1 platform NFT, 1 platform fee"
            )

            # Build transaction
            tx = await self.tx_manager.build_script_tx(
                script_inputs=[*reward_account_inputs, platform_auth],
                script_outputs=script_outputs,
                reference_inputs=[in_core_utxo],
                required_signers=required_signers,
                change_address=loaded_key.address,
                signing_key=loaded_key.payment_sk,
                fee_buffer=self.FEE_BUFFER,
            )
            return RewardTxResult(
                transaction=tx,
                reward_utxo=(
                    reward_account_outputs[0] if reward_account_outputs else None
                ),
            )

        except CollectingPlatformError as e:
            logging.error("No rewards available error")
            return RewardTxResult(exception_type=e)

        except NoRewardsAvailableError as e:
            logging.error("No rewards available error")
            return RewardTxResult(exception_type=e)

        except PlatformCollectCancelled as e:
            logger.info("Platform collect cancelled")
            return RewardTxResult(exception_type=e)

        except CollateralError as e:
            logging.error("ADA balance not found error")
            return RewardTxResult(exception_type=e)

    def find_reward_accounts(
        self,
        contract_utxos: list[UTxO],
        policy_id: ScriptHash,
        max_inputs: int,
        settings: OracleSettingsDatum,
        reward_token: NoDatum | SomeAsset,
    ) -> list[UTxO]:
        """Find reward account UTxOs with platform fees to collect.

        Args:
            contract_utxos: All available UTxOs
            policy_id: Policy ID for filtering C3RA tokens
            max_inputs: Maximum number of reward accounts to process
            settings: Oracle settings datum for safety buffer
            reward_token: Reward token type (ADA or custom asset)

        Returns:
            List of reward account UTxOs with platform fees
        """
        # Filter by C3RA token
        c3ra_utxos = asset_checks.filter_utxos_by_token_name(
            contract_utxos, policy_id, "C3RA"
        )
        logger.info(f"Found {len(c3ra_utxos)} UTxOs with C3RA token")

        # Convert CBOR to reward account objects
        converted_utxos = convert_cbor_to_reward_accounts(c3ra_utxos)
        logger.info(
            f"Converted {len(converted_utxos)} UTxOs from CBOR to RewardAccountVariant"
        )

        # Filter for reward accounts
        reward_account_utxos = filter_reward_accounts(converted_utxos)
        logger.info(f"Found {len(reward_account_utxos)} reward account UTxOs")

        # Filter out accounts with no platform rewards available
        accounts_with_platform_fees = []
        for account in reward_account_utxos:
            if self._has_platform_rewards(account, settings, reward_token):
                accounts_with_platform_fees.append(account)

        logger.info(
            f"Found {len(accounts_with_platform_fees)} accounts with platform fees to collect"
        )

        return accounts_with_platform_fees[:max_inputs]

    def _has_platform_rewards(
        self,
        reward_account: UTxO,
        settings: OracleSettingsDatum,
        reward_token: NoDatum | SomeAsset,
    ) -> bool:
        """Check if a reward account has platform rewards available to collect.

        Args:
            reward_account: The reward account UTxO to check
            settings: Oracle settings datum for safety buffer
            reward_token: Reward token type (ADA or custom asset)

        Returns:
            True if platform rewards are available, False otherwise
        """
        reward_datum = reward_account.output.datum.datum
        node_rewards = sum(reward_datum.nodes_to_rewards.values())

        if isinstance(reward_token, NoDatum):
            # ADA case: check if there's ADA above node_rewards + safety_buffer
            lovelace_amount = reward_account.output.amount.coin
            allocated_amount = node_rewards + settings.utxo_size_safety_buffer
            platform_amount = lovelace_amount - allocated_amount
            return platform_amount > 0
        else:
            # Custom token case: check if there's token balance above node_rewards
            asset_name = AssetName(reward_token.asset.name)
            policy_hash = ScriptHash.from_primitive(reward_token.asset.policy_id.hex())

            token_balance = reward_account.output.amount.multi_asset.get(
                policy_hash, {}
            ).get(asset_name, 0)

            platform_amount = token_balance - node_rewards
            return platform_amount > 0

    def modified_reward_utxo(
        self,
        in_reward_utxo: UTxO,
        in_reward_datum: RewardAccountDatum,
        settings: OracleSettingsDatum,
        reward_token: NoDatum | SomeAsset,
    ) -> tuple[UTxO, int]:

        if isinstance(reward_token, NoDatum):
            return self.ada_payment_token_withdrawal(
                in_reward_utxo, in_reward_datum, settings.utxo_size_safety_buffer
            )

        return self.custom_payment_token_withdrawal(
            in_reward_utxo,
            in_reward_datum,
            reward_token,
        )

    def ada_payment_token_withdrawal(
        self,
        in_reward_utxo: UTxO,
        in_reward_datum: RewardAccountDatum,
        safety_buffer: int,
    ) -> tuple[UTxO, int]:

        modified_utxo = deepcopy(in_reward_utxo)

        lovelace_amount = modified_utxo.output.amount.coin
        node_rewards = sum(in_reward_datum.nodes_to_rewards.values())

        allocated_amount = node_rewards + safety_buffer
        platform_amount = lovelace_amount - allocated_amount

        logger.info(f"Lovelace amount: {lovelace_amount:_}")
        logger.info(f"Node rewards amount: {node_rewards}")
        logger.info(f"Platform reward amount: {platform_amount:_} ")
        logger.info(f"Safety buffer: {safety_buffer:_}")

        if platform_amount <= 0:
            raise CollectingPlatformError(
                "Insufficient rewards available for withdrawal."
            )

        modified_utxo.output.amount.coin -= platform_amount
        modified_utxo = replace(
            modified_utxo,
            output=replace(
                modified_utxo.output,
                datum_hash=None,
            ),
        )

        return modified_utxo, platform_amount

    def custom_payment_token_withdrawal(
        self,
        in_reward_utxo: UTxO,
        in_reward_datum: RewardAccountDatum,
        reward_token: SomeAsset,
    ) -> tuple[UTxO, int]:

        modified_utxo = deepcopy(in_reward_utxo)

        asset_name_bytes = reward_token.asset.name
        policy_id_bytes = reward_token.asset.policy_id

        asset_name = AssetName(asset_name_bytes)
        policy_hash = ScriptHash.from_primitive(policy_id_bytes.hex())

        token_balance = modified_utxo.output.amount.multi_asset.get(
            policy_hash, {}
        ).get(asset_name, 0)

        node_rewards = sum(in_reward_datum.nodes_to_rewards.values())
        platform_amount = token_balance - node_rewards

        logger.info(f"Reward balance: {token_balance:_}")
        logger.info(f"Node rewards amount: {node_rewards:_}")
        logger.info(f"Platform reward amount: {platform_amount:_}")

        if platform_amount <= 0:
            raise CollectingPlatformError(
                "Insufficient rewards available for withdrawal."
            )

        modified_utxo.output.amount.multi_asset[policy_hash][
            asset_name
        ] -= platform_amount

        modified_utxo = replace(
            modified_utxo,
            output=replace(
                modified_utxo.output,
                datum_hash=None,
            ),
        )

        return modified_utxo, platform_amount

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


async def confirm_withdrawal_amount_and_address(
    loaded_key: LoadedKeys,
    reward_token: SomeAsset | NoDatum,
    platform_reward: int,
    network: Network,
    total_accounts: int = 1,
) -> Address:
    """
    Prompts the user to confirm or change an address for platform reward withdrawal.

    Args:
        loaded_key: User's wallet keys
        reward_token: Type of reward token (ADA or custom asset)
        platform_reward: Total platform reward amount
        network: Cardano network (mainnet/testnet)
        total_accounts: Number of reward accounts being processed

    Returns:
        Address where rewards will be sent
    """
    print_progress("Loading wallet configuration...")

    symbol = "₳ (lovelace)" if isinstance(reward_token, NoDatum) else "C3 (Charli3)"

    print_status(
        "Verification Key Hash associated with user's wallet",
        message=f"{loaded_key.payment_vk.hash()}",
    )

    print_information(f"Total Platform Rewards: {platform_reward:_} {symbol}")
    print_information(f"Reward Accounts to process: {total_accounts}")

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
            raise PlatformCollectCancelled()
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
                    raise PlatformCollectCancelled()
                try:
                    new_address = Address.from_primitive(new_address_str)
                    return new_address
                except Exception as e:
                    click.echo(
                        f"Invalid Cardano address format: {e}. Please try again."
                    )
