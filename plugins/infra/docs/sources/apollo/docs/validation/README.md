# Validation and pitfalls

These are behaviours that still compile after a v1 → v2 import-path change.
They are also the first things to read if a transaction is rejected on submit.
The [changelog](https://github.com/Salvionied/apollo/blob/master/CHANGELOG.md)
has the full narrative; this page is the operator-facing list.

## Addresses

Use `apollo.ParseAddress` for user-supplied text. `common.NewAddress` retries a
failed bech32 decode as base58. Every character of a mainnet `addr1...` string
is legal base58, so a single mistyped character used to decode to a **different
recipient** without error (thousands of single-character corruptions were
accepted).

`ParseAddress` requires:

- Non-Byron addresses re-encode to the same text (canonical bech32, matching
  HRP, valid checksum). All-uppercase bech32 is still accepted.
- Byron addresses only when the input does **not** carry a bech32 address
  prefix (`addr1`, `addr_test1`, `stake1`, `stake_test1`).
- Payload length exact for the address type (no trailing extra-data bytes).
- Network id `0` or `1` only.

Staking helpers (`RegisterStake`, `DelegateStake`, `DelegateVote`, and the
string forms) share `ParseAddress` via `resolveCredential`.

## Networks

`Complete()` fails if the wallet, change, input, or payment addresses are not
all on the context network. The error names the offending address and both IDs.
A context `NetworkId()` outside `{0, 1}` is also rejected.

There is no `constants.MAINNET` / `TESTNET` enum. Those numbered mainnet as
`0`. Pass `1` (mainnet) or `0` (testnets).
`constants.BlockfrostBaseUrlTestnet` is gone; use Preview or Preprod.

## Datums and hashes

Hash datums with `apollo.DatumHash` / `apollo.DatumWireCbor`, not
`common.Datum.Hash` on a value you built in Go: that hashes stored CBOR, which
is empty until bytes are pinned, so you get the hash of the empty string.

A datum whose stored CBOR does not survive its own re-encoding is rejected
(named stored-bytes hash vs wire-bytes hash) rather than locking funds under a
hash no other tool can match. Accept the canonical form with `SetCbor(nil)`, or
reference a foreign hash without the datum through `PayToContractAsHash`.

`AddDatum` pins wire bytes the same way. Witness (non-inline) datums plus a
script use a script-data hash preimage that includes the tag-258 set prefix the
witness set actually writes; empty witness datums are omitted from the preimage
(required for mint-only transactions).

## Burns vs mints

`GetBurns()` returns **absolute** burned quantities (what inputs must cover).
`GetMints()` still returns the signed mint value, negatives included. v1
`GetBurns()` was identical to `GetMints()`.

`Value.Add` / `Value.Sub` error on uint64 overflow instead of wrapping.

## Fees, collateral, selection

See [fees and collateral](../fees_and_collateral/README.md) and
[coin selection](../coin_selection/README.md). Short version:

- Reference-script fees are part of the minimum fee; missing per-byte price is
  an error.
- One UTxO may be both spend and collateral.
- Empty input sets are avoided when withdrawals/mints/refunds cover the target.
- `max_val_size` is enforced per output.

## Backends

- **Ogmios:** lovelace parameters as `{"ada":{"lovelace":N}}` (v6.1+) are
  decoded; the old zero-fee bug is gone. See [Ogmios](../backends/ogmios.md).
- **UTxO RPC:** no additional-UTxO evaluation; Apollo will not pass them.
  Protocol is `v1beta` with v1alpha fallback. See [UTxO RPC](../backends/utxorpc.md).
- **Blockfrost:** evaluate-path and `UtxoByRef` TxHash fixes; see
  [Blockfrost](../backends/blockfrost.md).

Check [capabilities](../backends/capabilities.md) before chaining transactions
off unconfirmed outputs.
