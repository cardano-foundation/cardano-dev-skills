# cardano-tx-generator

Long-running daemon that drives a configurable mix of Conway
transactions against a node for soak / fuzz testing. Speaks
node-to-client (N2C) over two sockets: a `--relay-socket` for
transaction submission and a `--control-socket` for chain-follower
queries. Master state — wallets, in-flight tx tracking, persisted
snapshot — lives under `--state-dir`.

```text
Usage: cardano-tx-generator \
  --relay-socket PATH \
  --control-socket PATH \
  --state-dir DIR \
  --master-seed-file PATH \
  --faucet-skey-file PATH \
  --network-magic INT \
  [--byron-epoch-slots INT] \
  [--await-timeout-seconds INT] \
  [--ready-threshold-slots INT] \
  [--security-param-k INT] \
  [--db-path DIR] \
  [--reconnect-initial-ms INT] \
  [--reconnect-max-ms INT] \
  [--reconnect-reset-threshold-ms INT] \
  [--node-ready-timeout-ms INT]
```

## Examples

Run against a local preprod node:

```bash
cardano-tx-generator \
  --relay-socket /run/cardano/preprod/node.socket \
  --control-socket /run/cardano/preprod/node.socket \
  --state-dir ./generator-state \
  --master-seed-file ./master.seed \
  --faucet-skey-file ./faucet.skey \
  --network-magic 1
```

Run against a Yaci-DevKit local devnet, faster reconnect for a
shorter feedback loop:

```bash
cardano-tx-generator \
  --relay-socket /tmp/yaci-store/node.socket \
  --control-socket /tmp/yaci-store/node.socket \
  --state-dir /tmp/gen-state \
  --master-seed-file ./devnet/master.seed \
  --faucet-skey-file ./devnet/faucet.skey \
  --network-magic 42 \
  --reconnect-initial-ms 200 \
  --reconnect-max-ms 5000 \
  --node-ready-timeout-ms 10000
```

## Library

The generator engine is exposed as a sub-library
(`cardano-tx-tools:tx-generator-lib`), with these entry points
under `Cardano.Tx.Generator.*`:

| Module                            | Role                                              |
|-----------------------------------|---------------------------------------------------|
| `Cardano.Tx.Generator.Daemon`     | Top-level supervisor; `main` is a thin wrapper    |
| `Cardano.Tx.Generator.Server`     | Submission loop, in-flight tracking, retries      |
| `Cardano.Tx.Generator.Build`      | Tx builder for the generator's wallet set         |
| `Cardano.Tx.Generator.Selection`  | Coin selection from the generator-owned UTxO set  |
| `Cardano.Tx.Generator.Population` | Wallet population (master-seed → N wallets)       |
| `Cardano.Tx.Generator.Fanout`     | Periodic fanout to keep the UTxO set healthy      |
| `Cardano.Tx.Generator.Persist`    | On-disk state (`--state-dir`)                     |
| `Cardano.Tx.Generator.Snapshot`   | Periodic snapshot for crash recovery              |
| `Cardano.Tx.Generator.Types`      | Shared types                                      |

A Docker image is published from `nix/docker-image.nix` and
includes the daemon binary plus a CA bundle.
