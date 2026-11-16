// Package ouroboros implements the Apollo chain backend on top of a
// cardano-node's node-to-client mini-protocols, reached over the node's local
// UNIX socket or a TCP socket that exposes it. Ledger queries use
// LocalStateQuery and submissions use LocalTxSubmission, through gouroboros.
//
// The node offers no script lookup by hash, so the context does not report
// CapabilityScriptCbor. It offers no script evaluator either, so EvaluateTx
// runs scripts in-process with backend/localeval.
package ouroboros
