"""Reward transaction builder. """

import logging
from copy import deepcopy
from dataclasses import replace

import click
from pycardano import (
    Address,
    AssetName,
    MultiAsset,
    Network,
    PaymentSigningKey,
    Redeemer,
    ScriptHash,
    TransactionOutput,
    UTxO,
    Value,
    VerificationKeyHash,
)

from charli3_offchain_core.blockchain.chain_query import ChainQuery
from charli3_offchain_core.blockchain.exceptions import CollateralError
from charli3_offchain_core.cli.base import LoadedKeys
from charli3_offchain_core.cli.config.formatting import (
    CliColor,
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
    RewardAccountVariant,
    SomeAsset,
)
from charli3_offchain_core.models.oracle_redeemers import (
    NodeCollect,
    RedeemRewards,
)
from charli3_offchain_core.oracle.exceptions import (
    ADABalanceNotFoundError,
    CollectingNodesError,
    NodeCollectCancelled,
    NodeNotRegisteredError,
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


class NodeCollectBuilder(BaseBuilder):
    FEE_BUFFER = 10_000
    EXTRA_COLLATERAL = 10_000_000

    async def build_tx(
        self,
        policy_hash: ScriptHash,
        script_address: Address,
        contract_utxos: list[UTxO],
        ref_script_config: ReferenceScriptConfig,
        reward_token: NoDatum | SomeAsset,
        loaded_key: LoadedKeys,
        network: Network,
        max_inputs: int = 10,
        required_signers: list[VerificationKeyHash] | None = None,
        payment_key: tuple[PaymentSigningKey, Address] | None = None,
    ) -> RewardTxResult:
        try:
            # Determine which key pays for tx (fees/collateral) and receives change
            if payment_key:
                tx_signing_key = payment_key[0]
                tx_change_address = payment_key[1]
            else:
                tx_signing_key = loaded_key.payment_sk
                tx_change_address = loaded_key.address

            # Derive feed_vkh from loaded_key
            feed_vkh = loaded_key.payment_vk.hash()

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

            # Find reward account UTxOs for this feed_vkh
            reward_accounts = self.find_reward_accounts(
                contract_utxos, policy_hash, feed_vkh, max_inputs
            )

            if not reward_accounts:
                raise NoRewardsAvailableError(
                    f"No reward account UTxOs found for feed_vkh: {feed_vkh}"
                )

            logger.info(
                f"Found {len(reward_accounts)} reward account(s) to collect from"
            )

            # Calculate node rewards from each account and create outputs
            total_node_reward = 0
            reward_account_outputs = []
            reward_account_inputs = []

            for idx, reward_account in enumerate(reward_accounts):
                reward_datum = reward_account.output.datum.datum

                # Calculate node reward and create modified output
                out_reward_utxo, node_reward_amount = self.modified_reward_utxo(
                    reward_account,
                    reward_datum,
                    feed_vkh,
                    in_core_datum,
                    reward_token,
                )

                total_node_reward += node_reward_amount
                reward_account_outputs.append(out_reward_utxo.output)

                # Create redeemer with corresponding_out_ix pointing to output index
                redeemer = Redeemer(
                    RedeemRewards(collector=NodeCollect(), corresponding_out_ix=idx)
                )
                reward_account_inputs.append((reward_account, redeemer, script_utxo))

                logger.info(
                    f"Account #{idx}: Node reward = {node_reward_amount:_}, corresponding_out_ix = {idx}"
                )

            logger.info(f"Total node reward: {total_node_reward:_}")

            # Get withdrawal address
            # Note: We pass tx_signing_key/tx_change_address for collateral check
            requested_address = await confirm_withdrawal_amount_and_address(
                loaded_key,
                reward_token,
                total_node_reward,
                self.EXTRA_COLLATERAL,
                self.chain_query,
                network=network,
                total_accounts=len(reward_accounts),
                signing_key=tx_signing_key,
                address=tx_change_address,
            )

            # Create combined node reward output
            out_operator_reward = self.node_operator_output(
                requested_address,
                reward_token,
                total_node_reward,
            )

            # Build outputs: [reward_out_1, reward_out_2, ..., combined_node_reward]
            script_outputs = [
                *reward_account_outputs,
                out_operator_reward,
            ]

            logger.info(
                f"Building transaction with {len(reward_account_inputs)} reward account inputs"
            )
            logger.info(
                f"Output order: {len(reward_account_outputs)} reward accounts, 1 combined node reward"
            )

            # Debug logging
            logger.info(f"required_signers: {required_signers}")
            logger.info(f"reward_account_inputs length: {len(reward_account_inputs)}")
            logger.info(f"script_outputs length: {len(script_outputs)}")

            # Build transaction
            tx = await self.tx_manager.build_script_tx(
                script_inputs=reward_account_inputs,
                script_outputs=script_outputs,
                reference_inputs=[in_core_utxo],
                required_signers=required_signers,
                change_address=tx_change_address,
                signing_key=tx_signing_key,
                external_collateral=self.EXTRA_COLLATERAL,
            )
            return RewardTxResult(
                transaction=tx,
                reward_utxo=(
                    reward_account_outputs[0] if reward_account_outputs else None
                ),
            )

        except CollectingNodesError as e:
            logger.info("Collecting nodes error")
            return RewardTxResult(exception_type=e)

        except NodeCollectCancelled as e:
            logger.info("Node collect cancelled")
            return RewardTxResult(exception_type=e)

        except NodeNotRegisteredError as e:
            logger.error("Node not registered error")
            return RewardTxResult(exception_type=e)

        except NoRewardsAvailableError as e:
            logging.error("No rewards available error")
            return RewardTxResult(exception_type=e)

        except (ADABalanceNotFoundError, CollateralError) as e:
            logging.error("ADA balance not found error")
            return RewardTxResult(exception_type=e)

    def find_reward_accounts(
        self,
        contract_utxos: list[UTxO],
        policy_id: ScriptHash,
        feed_vkh: VerificationKeyHash,
        max_inputs: int,
    ) -> list[UTxO]:
        """Find reward account UTxOs where the feed_vkh has rewards to collect.

        Args:
            contract_utxos: All available UTxOs
            policy_id: Policy ID for filtering C3RA tokens
            feed_vkh: Feed verification key hash to filter by
            max_inputs: Maximum number of reward accounts to process

        Returns:
            List of reward account UTxOs where feed_vkh has rewards > 0
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

        # Filter for accounts where feed_vkh has rewards > 0
        accounts_with_rewards = []
        for account in reward_account_utxos:
            datum = account.output.datum.datum
            if feed_vkh in datum.nodes_to_rewards:
                reward_amount = datum.nodes_to_rewards[feed_vkh]
                if reward_amount > 0:
                    accounts_with_rewards.append(account)

        logger.info(
            f"Found {len(accounts_with_rewards)} reward accounts where feed_vkh has rewards"
        )

        return accounts_with_rewards[:max_inputs]

    def modified_reward_utxo(
        self,
        in_reward_utxo: UTxO,
        in_reward_datum: RewardAccountDatum,
        feed_vkh: VerificationKeyHash,
        settings: OracleSettingsDatum,
        reward_token: NoDatum | SomeAsset,
    ) -> tuple[UTxO, int]:
        """Modify reward account UTxO by removing rewards for the given feed_vkh.

        Args:
            in_reward_utxo: Input reward account UTxO
            in_reward_datum: Input reward account datum
            feed_vkh: Feed verification key hash to collect rewards for
            settings: Oracle settings datum
            reward_token: Reward token type (ADA or custom asset)

        Returns:
            Tuple of (modified UTxO, reward amount collected)
        """
        nodes_to_rewards = in_reward_datum.nodes_to_rewards

        # Check if feed_vkh exists in rewards dict
        if feed_vkh not in nodes_to_rewards:
            raise NodeNotRegisteredError(str(feed_vkh))

        registered_reward = nodes_to_rewards[feed_vkh]

        if registered_reward <= 0:
            raise NoRewardsAvailableError(str(feed_vkh))

        # Create new rewards dict with this node's reward completely removed
        new_rewards = {k: v for k, v in nodes_to_rewards.items() if k != feed_vkh}
        modified_datum = RewardAccountDatum(
            nodes_to_rewards=new_rewards,
            last_update_time=in_reward_datum.last_update_time,
        )

        if isinstance(reward_token, NoDatum):
            return self.ada_payment_token_withdrawal(
                in_reward_utxo,
                registered_reward,
                modified_datum,
                settings.utxo_size_safety_buffer,
            )

        return self.custom_payment_token_withdrawal(
            in_reward_utxo,
            reward_token,
            registered_reward,
            modified_datum,
        )

    def ada_payment_token_withdrawal(
        self,
        in_reward_utxo: UTxO,
        registered_reward: int,
        modified_datum: RewardAccountDatum,
        safety_buffer: int,
    ) -> tuple[UTxO, int]:

        modified_utxo = deepcopy(in_reward_utxo)

        lovelace_amount = modified_utxo.output.amount.coin

        logger.info(f"Reward balance: {lovelace_amount:_}")
        logger.info(f"Node reward amount: {registered_reward:_}")
        logger.info(f"Safety buffer: {safety_buffer:_}")

        if lovelace_amount < registered_reward + safety_buffer:
            raise CollectingNodesError("Insufficient rewards available for withdrawal.")

        modified_utxo.output.amount.coin -= registered_reward
        modified_utxo = replace(
            modified_utxo,
            output=replace(
                modified_utxo.output,
                datum=RewardAccountVariant(datum=modified_datum),
                datum_hash=None,
            ),
        )

        return modified_utxo, registered_reward

    def custom_payment_token_withdrawal(
        self,
        in_reward_utxo: UTxO,
        reward_token: SomeAsset,
        registered_reward: int,
        modified_datum: RewardAccountDatum,
    ) -> tuple[UTxO, int]:

        modified_utxo = deepcopy(in_reward_utxo)

        asset_name_bytes = reward_token.asset.name
        policy_id_bytes = reward_token.asset.policy_id

        asset_name = AssetName(asset_name_bytes)
        policy_hash = ScriptHash.from_primitive(policy_id_bytes.hex())

        token_balance = modified_utxo.output.amount.multi_asset.get(
            policy_hash, {}
        ).get(asset_name, 0)

        logger.info(f"Reward balance: {token_balance:_}")
        logger.info(f"Node reward amount: {registered_reward:_}")

        if token_balance < registered_reward:
            raise CollectingNodesError("Insufficient rewards available for withdrawal.")

        modified_utxo.output.amount.multi_asset[policy_hash][
            asset_name
        ] -= registered_reward

        modified_utxo = replace(
            modified_utxo,
            output=replace(
                modified_utxo.output,
                datum=RewardAccountVariant(datum=modified_datum),
                datum_hash=None,
            ),
        )

        return modified_utxo, registered_reward

    def node_operator_output(
        self,
        address: Address,
        reward_token: SomeAsset | NoDatum,
        node_reward: int,
    ) -> TransactionOutput:
        """Creates a transaction output for a node operator.

        Args:
            address: The address of the node operator.
            reward_token: The reward token (SomeAsset) or NoDatum if ADA.
            node_reward: The amount of the reward.

        Returns:
            A TransactionOutput object.

        """

        if isinstance(reward_token, NoDatum):
            if node_reward < self.MIN_UTXO_VALUE:
                raise NoRewardsAvailableError(
                    f"The ADA amount is too small {node_reward:_}"
                )
            value = Value(coin=node_reward)
        elif isinstance(reward_token, SomeAsset):
            payment_asset = MultiAsset.from_primitive(
                {reward_token.asset.policy_id: {reward_token.asset.name: node_reward}}
            )
            value = Value(coin=self.MIN_UTXO_VALUE, multi_asset=payment_asset)

        return TransactionOutput(address=address, amount=value)


async def confirm_withdrawal_amount_and_address(
    loaded_key: LoadedKeys,
    reward_token: SomeAsset | NoDatum,
    node_reward: int,
    extra_collateral: int,
    chain_query: ChainQuery,
    network: Network,
    total_accounts: int = 1,
    signing_key: PaymentSigningKey | None = None,
    address: Address | None = None,
) -> Address:
    """


    Prompts the user to confirm or change an address.


    """

    print_progress("Loading wallet configuration...")

    # Use provided keys or default to loaded_key

    actual_signing_key = signing_key if signing_key else loaded_key.payment_sk

    actual_address = address if address else loaded_key.address

    collateral_ada = extra_collateral / 1_000_000

    user_message = (
        f"You need {collateral_ada} ADA in a UTxO to claim rewards.\n"
        f"If you lack it, we'll create a {collateral_ada} ADA collateral UTxO\n"
        "from your existing funds. This is automatic.\n"
        "This collateral is used to cover the transaction fees\n"
        "when you withdraw your rewards.\n"
    )

    if not click.confirm(click.style(user_message, fg=CliColor.WARNING, bold=True)):

        raise NodeCollectCancelled()

    collateral_utxo = await chain_query.get_or_create_collateral(
        actual_address, actual_signing_key, extra_collateral
    )

    if collateral_utxo is None:

        raise ADABalanceNotFoundError("No collateral UTXO found")

    symbol = "₳ (lovelace)" if isinstance(reward_token, NoDatum) else "C3 (Charli3)"

    print_status(
        "Verififcaion Key Hash associated with user's wallet",
        message=f"{loaded_key.payment_vk.hash()}",
    )

    print_information(f"Total Accumulated Rewards: {node_reward:_} {symbol}")

    print_information(f"Reward Accounts to process: {total_accounts}")

    return _select_withdrawal_address(loaded_key, network, address)


def _select_withdrawal_address(
    loaded_key: LoadedKeys,
    network: Network,
    withdrawal_wallet_address: Address | None,
) -> Address:
    """Handle user interaction for selecting withdrawal address."""

    print_title(
        "Select a withdrawal address (derived from your mnemonic configuration):"
    )

    enterprise_addr = Address(
        payment_part=loaded_key.payment_vk.hash(), network=network
    )

    options = ["1", "2", "3", "q"]

    click.secho("1. Base Address:", fg="blue")

    print(loaded_key.address)

    click.secho("2. Enterprise Address:", fg="blue")

    print(enterprise_addr)

    if withdrawal_wallet_address and withdrawal_wallet_address != loaded_key.address:

        options = ["1", "2", "3", "4", "q"]

        click.secho("3. Withdrawal Wallet Address (from config):", fg="blue")

        print(withdrawal_wallet_address)

        click.secho("4. Enter a new address", fg="blue")

    else:

        click.secho("3. Enter a new address", fg="blue")

    click.secho("q. Quit", fg="blue")

    while True:

        choice = click.prompt(
            f"Enter your choice ({options[0]}-{options[-2]}, q):",
            type=click.Choice(options),
            default="3" if len(options) == 5 else "1",
        )

        if choice == "q":

            click.echo("Exiting.")

            raise NodeCollectCancelled()

        if choice == "1":

            return loaded_key.address

        if choice == "2":

            return enterprise_addr

        if choice == "3" and len(options) == 5:

            return withdrawal_wallet_address

        # Handle manual address entry (Choice 3 in standard menu, 4 in extended)

        while True:

            new_address_str = click.prompt(
                "Please enter a new address (or 'q' to quit)"
            )

            if new_address_str.lower() == "q":

                click.echo("Exiting.")

                raise NodeCollectCancelled()

            try:

                return Address.from_primitive(new_address_str)

            except Exception as e:

                click.echo(f"Invalid Cardano address format: {e}. Please try again.")
