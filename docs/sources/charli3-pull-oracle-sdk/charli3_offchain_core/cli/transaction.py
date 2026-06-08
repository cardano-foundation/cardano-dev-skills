"""Common transaction CLI commands for signing and submitting transactions."""

import json
import logging
from collections.abc import Callable
from pathlib import Path
from typing import Any

import click
from pycardano import Transaction

from charli3_offchain_core.cli.config.formatting import (
    print_hash_info,
    print_status,
)
from charli3_offchain_core.cli.config.network import NetworkConfig
from charli3_offchain_core.cli.config.utils import async_command

from ..blockchain.transactions import TransactionManager
from ..constants.status import ProcessStatus
from .base import create_chain_query
from .config.keys import KeyManager

logger = logging.getLogger(__name__)


def _canonicalize_ordered_sets(tx: Transaction) -> None:
    """Sort the transaction body's set-typed fields into a deterministic order.

    PyCardano (through at least v0.19) loses the ordering of Conway-era CBOR sets
    when deserializing: cbor2 decodes a set tag (258) into a Python ``set``, and
    ``OrderedSet.from_primitive`` then does ``list(value)`` whose order is
    randomized per process via PYTHONHASHSEED. The transaction body hash is what
    every signer signs, so an unstable body serialization makes signatures
    produced in separate processes (sign-tx, submit-tx) invalid. Sorting each set
    canonically makes the body hash identical in every process. Set ordering on
    the wire is irrelevant to the ledger (it re-sorts inputs itself), so this is
    purely a serialization-determinism fix and changes nothing else.
    """
    body = tx.transaction_body
    for field in ("inputs", "reference_inputs", "collateral", "required_signers"):
        collection = getattr(body, field, None)
        if collection is None or len(collection) < 2:
            continue
        items = sorted(collection, key=lambda element: element.to_cbor())
        if hasattr(collection, "_use_tag"):  # pycardano OrderedSet / NonEmptyOrderedSet
            setattr(body, field, type(collection)(items, use_tag=collection._use_tag))
        else:
            setattr(body, field, items)


class TransactionProcessor:
    """Common transaction processing functionality."""

    @staticmethod
    async def submit_tx(
        config: Path,
        tx_file: Path,
        success_callback: Callable[[Transaction, dict], None] | None = None,
        status_success_value: Any = None,
    ) -> None:
        """Submit a fully signed transaction."""
        try:

            network_config = NetworkConfig.from_yaml(config)
            network_config.validate()

            chain_query = create_chain_query(network_config)
            tx_manager = TransactionManager(chain_query)

            with tx_file.open() as f:
                data = json.load(f)

            if len(data.get("signed_by", [])) < data.get("threshold", 1):
                raise click.ClickException(
                    "Transaction does not have enough signatures to meet threshold"
                )

            tx = Transaction.from_cbor(data["transaction"])
            _canonicalize_ordered_sets(tx)
            await tx_manager.sign_and_submit(tx, [])

            if ProcessStatus.TRANSACTION_CONFIRMED == status_success_value:
                if success_callback:
                    success_callback(tx, data)
                else:
                    print_status("Transaction", "Submitted successfully", success=True)
                    print_hash_info("Transaction ID", tx.id)
            else:
                raise click.ClickException(
                    "Transaction submission failed due to insufficient signatures or network issues"
                )

        except click.Abort:
            click.echo("Process aborted by the user.")
        except Exception as e:
            logger.error("Failed to submit transaction", exc_info=e)
            raise click.ClickException(str(e)) from e

    @staticmethod
    async def sign_tx(
        config: Path,
        tx_file: Path,
        status_signed_value: Any,
    ) -> None:
        """Sign a transaction and update the file."""
        try:

            network_config = NetworkConfig.from_yaml(config)
            network_config.validate()

            chain_query = create_chain_query(network_config)
            tx_manager = TransactionManager(chain_query)

            payment_sk, payment_vk, _, _ = KeyManager.load_from_config(
                network_config.wallet
            )

            with tx_file.open() as f:
                data = json.load(f)

            signer_id = payment_vk.payload.hex()
            if signer_id in data.get("signed_by", []):
                raise click.ClickException("Transaction already signed by this key")

            if len(data.get("signed_by", [])) >= data.get("threshold", 1):
                raise click.ClickException(
                    "Transaction already has required number of signatures"
                )

            transaction = Transaction.from_cbor(data["transaction"])
            _canonicalize_ordered_sets(transaction)

            tx_manager.sign_tx(transaction, payment_sk)

            if ProcessStatus.TRANSACTION_SIGNED == status_signed_value:
                data["transaction"] = transaction.to_cbor_hex()
                data["signed_by"].append(signer_id)

                with tx_file.open("w") as f:
                    json.dump(data, f)

                print_status("Transaction", "Signed successfully", success=True)
                print_hash_info("Signer", signer_id)
                print_hash_info(
                    "Signatures", f"{len(data['signed_by'])}/{data['threshold']}"
                )

                if len(data["signed_by"]) >= data["threshold"]:
                    print_hash_info(
                        "Reminder",
                        "Transaction has all required signatures and is ready for submission",
                    )
            else:
                raise click.ClickException(
                    "Transaction signing failed due to invalid key or network issues"
                )

        except click.Abort:
            click.echo("Process aborted by the user.")
        except Exception as e:
            logger.error("Failed to sign transaction", exc_info=e)
            raise click.ClickException(str(e)) from e


def create_sign_tx_command(
    status_signed_value: Any,
) -> click.Command:
    """Create a sign transaction command."""

    @click.command(name="sign-tx")
    @click.option(
        "--config",
        type=click.Path(exists=True, path_type=Path),
        required=True,
        help="Path to configuration YAML",
    )
    @click.option(
        "--tx-file",
        type=click.Path(exists=True, path_type=Path),
        required=True,
        help="Path to transaction JSON file to sign",
    )
    @async_command
    async def sign_tx(config: Path, tx_file: Path) -> None:
        """Sign a transaction and update the file."""
        await TransactionProcessor.sign_tx(
            config=config, tx_file=tx_file, status_signed_value=status_signed_value
        )

    return sign_tx


def create_submit_tx_command(
    status_success_value: Any,
    success_callback: Callable[[Transaction, dict], None] | None = None,
) -> click.Command:
    """Create a submit transaction command."""

    @click.command(name="submit-tx")
    @click.option(
        "--config",
        type=click.Path(exists=True, path_type=Path),
        required=True,
        help="Path to configuration YAML",
    )
    @click.option(
        "--tx-file",
        type=click.Path(exists=True, path_type=Path),
        required=True,
        help="Path to signed transaction JSON file",
    )
    @async_command
    async def submit_tx(config: Path, tx_file: Path) -> None:
        """Submit a fully signed transaction."""
        await TransactionProcessor.submit_tx(
            config=config,
            tx_file=tx_file,
            success_callback=success_callback,
            status_success_value=status_success_value,
        )

    return submit_tx
