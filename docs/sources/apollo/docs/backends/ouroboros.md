# Ouroboros (node-to-client)

`backend/ouroboros` talks to a `cardano-node` directly over the
node-to-client mini-protocols, with no intermediate service. Use the node's
local socket, or a TCP socket that exposes it.

```go
import "github.com/Salvionied/apollo/v2/backend/ouroboros"

ctx, err := ouroboros.NewOuroborosChainContext(ouroboros.Config{
    Network:      "unix",                        // or "tcp"
    Address:      "/run/cardano/node.socket",    // or "host:port"
    NetworkMagic: 764824073,                     // mainnet; 1 preprod, 2 preview
    NetworkId:    1,
})
if err != nil {
    return err
}
defer ctx.Close()
```

`Network`, `Address` and `NetworkMagic` are required. The constructor
performs no I/O; the first query opens the connection.

## Capabilities

The context reports every capability except `CapabilityScriptCbor`,
`CapabilityEvaluateTx` and `CapabilityEvaluateTxAdditionalUtxos`. The node has
no query for a script by hash and no script evaluator, so `ScriptCbor` and
`EvaluateTx` return errors matching `backend.ErrUnsupported`. Building a
transaction with Plutus scripts needs execution units from elsewhere.

| Method | Node-to-client source |
|--------|-----------------------|
| `ProtocolParams` | LocalStateQuery current protocol parameters |
| `GenesisParams` | LocalStateQuery Shelley genesis configuration |
| `CurrentEpoch` | LocalStateQuery epoch number |
| `Tip` | LocalStateQuery chain point |
| `Utxos` | LocalStateQuery UTxO by address |
| `UtxoByRef` | LocalStateQuery UTxO by transaction input |
| `SubmitTx` | LocalTxSubmission, in the node's current era |
| `MaxTxFee` | computed from the protocol parameters |

## Behaviour worth knowing

- **One operation at a time.** The context holds one connection and runs one
  operation on it at a time. Each query acquires the node's current ledger
  state and releases it afterwards, so every call reads the tip as of its own
  start.
- **Reconnects.** The connection is opened by the first query and replaced
  after any failure, including the node closing it. A node restart costs only
  the operations in flight at the time. `Close` drops the connection; the
  context reconnects on its next query.
- **Cancellation.** The `...Context` methods close the connection when their
  context ends, which is how a blocked query is abandoned. The next call
  reconnects. A call still waiting for its turn behind another operation
  returns as soon as its context ends and leaves the connection alone.
- **Timeouts.** `DialTimeout` (default 10 seconds) bounds opening the socket
  and `HandshakeTimeout` (default 10 seconds) bounds the node-to-client
  handshake after it, which has no timeout of its own. `SubmitTimeout`
  (default 30 seconds) bounds waiting for the node's answer to a submission.
- **Failures.** A call that fails because the connection broke reports the
  connection's own error, such as a query timeout, after the mini-protocol's
  "protocol is shutting down".
- **Address queries are slow on mainnet.** The node answers `Utxos` by
  scanning its UTxO set, which can take tens of seconds. `QueryTimeout`
  (default 3 minutes) bounds each query; the muxer's own read timeout is
  disabled so a long answer is not cut off.
- **Address query limits.** Results with more than 100,000 UTxOs are
  rejected after the node answers, before converting or sorting the result.
  The gouroboros protocol reader also retains its default 16 MiB message
  limit. An oversized query returns an error rather than a partial result.
- **Protocol parameters** must come from the Conway era or later. Conway's
  reference-script size limit (200 KiB per transaction) is a ledger constant
  and is filled in; Dijkstra's reference-script limit, tier size and
  multiplier come from the node.
- **Genesis.** The slot length must be a whole number of seconds, because
  `GenesisParameters.SlotLength` holds seconds.
- **Submission.** `SubmitTx` returns the transaction id computed from the
  body as submitted. A rejection wraps
  `localtxsubmission.TransactionRejectedError`, whose `Reason` decodes the
  ledger's error; the connection stays open after a rejection. If the node
  accepts the transaction but releasing the ledger state afterwards fails,
  `SubmitTx` still returns the id and the connection is replaced.
