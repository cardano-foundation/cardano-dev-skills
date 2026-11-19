# Tracer-sidecar

Processes structured node logs from cardano-tracer into Antithesis assertions.

## Role

The tracer-sidecar tails JSON log files written by the tracer and generates Antithesis SDK assertions:

- **Sometimes assertions**: chain fork switching, peer status changes, per-node activity
- **Always assertions**: no critical-severity log entries
- **Chain points**: records `AddedToCurrentChain` events to track chain convergence

When a node adds a block to its current chain, the sidecar logs it as:
```
p1.example added <block_hash>@<slot> to current chain
```

## Image

`ghcr.io/cardano-foundation/cardano-node-antithesis/tracer-sidecar:<commit>`

Built from `components/tracer-sidecar/` (Haskell).

## Configuration

Environment variables:
- `POOLS`: Number of block-producing pools (used for per-node activity assertions)
- `CHAINPOINT_FILEPATH`: Path to write chain point observations

## Source

See `components/tracer-sidecar/src/` for the Haskell implementation:
- `App.hs`: File tailing and JSONL parsing
- `Cardano/Antithesis/LogMessage.hs`: Node log message parsing
- `Cardano/Antithesis/Sidecar.hs`: Assertion logic
- `Cardano/Antithesis/Sdk.hs`: Antithesis SDK bindings
