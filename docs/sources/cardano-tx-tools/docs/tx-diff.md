# tx-diff

Structural diff between two Conway transactions. Reads each
transaction as CBOR hex (or a `cardano-cli` JSON envelope), decodes
it through the ledger, and reports the differences keyed by ledger
identity — input `TxIn`, output address + asset, vkey-witness key
hash, redeemer purpose + index — not by byte offset. Plutus datums
and redeemers are decoded against an optional blueprint schema.

```text
Usage: tx-diff [--render tree|paths] [--tree-art ascii|unicode]
               [--collapse-rules FILE] [--blueprint FILE ...]
               [--resolve-n2c SOCKET --network-magic N]
               [--resolve-web2 URL [--web2-api-key-file PATH]]
               TX_A TX_B
```

## Examples

Plain diff between two unsigned tx CBOR hex files:

```bash
tx-diff a.cbor.hex b.cbor.hex
```

Same, but decode datums and redeemers against a Plutus blueprint
and resolve referenced inputs from a running node via N2C:

```bash
tx-diff \
  --blueprint plutus.json \
  --resolve-n2c "$CARDANO_NODE_SOCKET_PATH" \
  --network-magic 1 \
  a.cbor.hex b.cbor.hex
```

Resolve inputs from a Blockfrost-style HTTP endpoint instead of
N2C:

```bash
tx-diff \
  --resolve-web2 https://cardano-preprod.blockfrost.io/api/v0 \
  --web2-api-key-file ~/.blockfrost/preprod.key \
  a.cbor.hex b.cbor.hex
```

## Rewriting rules

`--collapse-rules FILE` consumes the unified
[rewriting-rules YAML](rewriting-rules.md) — the same grammar
[`tx-inspect --rules`](tx-inspect.md) consumes. The flag name
is preserved for backwards compatibility (every existing
collapse-only YAML file keeps working unchanged), but the
semantics have widened: a `rename:` section in the file now
takes effect inside each side of the diff renderer, so payment
addresses and script hashes can appear under their
address-book names on both sides.

```bash
tx-diff --collapse-rules rules/amaru-treasury.yaml \
    swap-1.cbor.hex swap-2.cbor.hex
```

See [rewriting-rules grammar](rewriting-rules.md) for the
full document shape, the `collapse:` / `rename:` sections, and
the cross-tool semantics.
