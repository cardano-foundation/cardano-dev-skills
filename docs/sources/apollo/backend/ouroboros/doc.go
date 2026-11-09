// Package ouroboros implements the Apollo chain backend on top of a
// cardano-node's node-to-client mini-protocols, reached over the node's local
// UNIX socket or a TCP socket that exposes it. Ledger queries use
// LocalStateQuery and submissions use LocalTxSubmission, through gouroboros.
//
// The node offers no script lookup by hash and no script evaluator, so the
// context reports neither CapabilityScriptCbor nor CapabilityEvaluateTx.
package ouroboros
