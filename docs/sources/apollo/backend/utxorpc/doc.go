// Package utxorpc implements the Apollo chain backend on top of the UTxO RPC
// protocol. It prefers the utxorpc.v1beta services and falls back to v1alpha
// for servers that expose only the older ones.
package utxorpc
