// Package localeval evaluates a transaction's Plutus scripts in-process
// instead of asking a chain backend to do it.
//
// Evaluate needs no chain access at all: the caller supplies the transaction,
// every UTxO it spends or references, the protocol parameters and a
// SlotConfig. It runs each redeemer's script against the protocol's maximum
// transaction execution units and reports the units each one consumed, which
// is what remote evaluators such as Ogmios and Blockfrost return.
//
// LocalEvalChainContext wraps any backend.ChainContext and answers EvaluateTx
// with Evaluate, resolving UTxOs from the caller's additional UTxOs first and
// the wrapped context's UtxoByRef second. It gives backends with no evaluation
// endpoint, such as a node-to-client connection or a fixed context, the
// EvaluateTx and EvaluateTxAdditionalUtxos capabilities.
//
// The evaluator is gouroboros's ledger implementation built on plutigo. It
// handles Conway transactions and the top level of Dijkstra transactions.
package localeval
