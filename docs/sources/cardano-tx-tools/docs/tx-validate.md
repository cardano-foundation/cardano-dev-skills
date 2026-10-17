# tx-validate

Conway Phase-1 pre-flight for unsigned transactions. Opens a
Node-to-Client session against a local `cardano-node`, queries the
protocol parameters and the tip slot, resolves the tx's UTxO via
the same N2C resolver `tx-diff` uses, and runs the ledger's
`Mempool.applyTx` rule against the body. The verdict is either a
one-line human summary or a JSON envelope; the exit code is the
contract pipelines act on.

```text
Usage: tx-validate --input PATH | - --n2c-socket-path PATH [--network-magic WORD32]
                   [--output human|json] [--version]
```

```asciinema-player
{
  "file": "assets/asciinema/tx-validate.cast",
  "idle_time_limit": 2,
  "theme": "monokai",
  "poster": "npt:0:3"
}
```

The cast above demonstrates the help surface and the
structural-failure exit path. A happy-path verdict recording is
tracked in
[lambdasistemi/cardano-tx-tools#69](https://github.com/lambdasistemi/cardano-tx-tools/issues/69).

## Exit codes

| Code | Meaning |
|------|---------|
| `0`  | structurally clean (only witness-completeness failures, expected on an unsigned tx) |
| `1`  | structural failure (integrity hash mismatch, fee too small, missing collateral, …) |
| `≥2` | configuration / decode / resolver / N2C handshake error (the verdict is **not** printed) |

## Examples

Validate an unsigned tx against a local mainnet node:

```bash
tx-validate \
  --input unsigned.cbor.hex \
  --n2c-socket-path "$CARDANO_NODE_SOCKET_PATH"
# structurally clean: 2 witness-completeness failures filtered
```

JSON envelope for machine-readable pipelines:

```bash
tx-validate \
  --input unsigned.cbor.hex \
  --n2c-socket-path "$CARDANO_NODE_SOCKET_PATH" \
  --output json
```

```json
{
  "status": "structurally_clean",
  "exit_code": 0,
  "structural_failures": [],
  "witness_completeness_count": 2,
  "pparams_source": "n2c",
  "slot_source": "n2c",
  "utxo_sources": { "59e10ca5…#0": "n2c", "59e10ca5…#2": "n2c", "f5f1bdfa…#0": "n2c" }
}
```

Preprod (or any testnet) — pass the right network magic:

```bash
tx-validate \
  --input unsigned.cbor.hex \
  --n2c-socket-path /run/cardano-preprod.socket \
  --network-magic 1
```

Pipeline integration — gate signing on the exit code:

```bash
tx-validate --input "$tx" --n2c-socket-path "$CARDANO_NODE_SOCKET_PATH"
case $? in
  0) tx-sign --network mainnet witness --tx "$tx" ... ;;
  1) echo "Phase-1 rejected; do not sign"; exit 1 ;;
  *) echo "tx-validate config / resolver error: $?"; exit $? ;;
esac
```

## Library

The pure pieces live in `Cardano.Tx.Validate.*`:

| Module                              | Role                                                |
|-------------------------------------|-----------------------------------------------------|
| `Cardano.Tx.Validate.validatePhase1`| `Mempool.applyTx` wrapper; pure verdict generator   |
| `Cardano.Tx.Validate.isWitnessCompletenessFailure` | Filter for the noise constructors any unsigned tx trips |
| `Cardano.Tx.Validate.Cli`           | `optparse-applicative` parser + verdict renderers (human + JSON) used by the executable |

The N2C session driver lives in `app/tx-validate/Main.hs` and is
intentionally not part of the library surface (constitution I —
the main library is one-way dependent on `cardano-node-clients`).

## Update banner

After every invocation the executable polls the GitHub Releases
API (rate-limited via an on-disk cache; 1-hour intervals) and
prints a one-line banner to stderr if the installed version is
behind the latest release. Silence it for one shell with
`TX_VALIDATE_NO_UPDATE_CHECK=1`; the banner never affects the
process exit code.

## Blockfrost path

Driving the session via Blockfrost instead of a local node is
deferred to
[#21](https://github.com/lambdasistemi/cardano-tx-tools/issues/21);
the blocker is decoding Blockfrost's `/epochs/latest/parameters`
schema into `PParams ConwayEra`.
