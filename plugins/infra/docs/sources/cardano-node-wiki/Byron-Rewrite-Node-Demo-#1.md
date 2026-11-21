[_Demo run internally 21st June 2019 and recorded for public 28th June 2019_]

# Background
This demo is the first demo of a cluster of independent Cardano nodes in the Shelley era, first release - Byron Re-write.

This is a full integration of the three core components, Networking, Ledger, and Consensus, and the auxiliary components of Logging, Monitoring, and Benchmarking, and the Node Shell.

Independence of nodes is enabled by updates in the networking code that allow the nodes to communicate via TCP. We could run this demo across multiple machines by modifying the topology of the network, however we’re currently limited to local transaction submission. The Consensus layer has added a real mempool containing generalised transactions, i.e. transactions , delegation certificates, or update proposals and votes. We will be able to show submission of these at a later date, but for now we will only be submitting transactions. The Ledger code is mostly the same in terms of functionality as the previous demo of the Consensus Layer.

There are still some features of the node missing that will be included over the coming weeks. For a comprehensive overview of the current capabilities and limitations, see the [this page](https://github.com/input-output-hk/cardano-node-wiki/wiki/Cardano-Haskell-Node-Capabilities).

# What are we looking at?
- We will set up three core nodes, which will be communicating with each other using the full network stack.
- These nodes will then start producing blocks when they are elected leader; leadership election is part of the particular choice of consensus algorithm (BFT or Praos).
- We then submit some transactions to these nodes to be included in the blockchain.
- We will then see that the nodes adopt each other’s blocks and that transactions that we submit will be included.
- Some of these transactions will be invalid and we will see the resulting error from the validation.
- We will see logging from various parts of the system, including the validation code, the mempool, transaction submission, and various other parts of consensus.

# What does this show?
This shows multiple nodes can run independently and communicate with each other using the full network stack. It shows transaction submission with a real mempool implementation, using the real PBFT ledger. This is the result of our early integration plan, that means we can hand this minimum viable node to DevOps and QA early in the process.

# Next steps
The next steps across the various parts of the node include:
- Completing the storage layer
- Adding EBBs into the Ledger integration to enable syncing with mainnet
- Adding remote transaction submission to the network layer
- Starting integration with the Wallet Backend
- Improving test coverage and infrastructure across the whole system

# Running the demo yourself

In the root of the `cardano-node` repo, setup the demo using:

```stack build```

```nix-shell```

```tmux new-session -s Demo```

```./scripts/demo.sh```

This will leave you with four `tmux` panes, three for the nodes and one to submit transactions.

Submit the transaction with too large value and watch it fail:

```./scripts/submit-tx.sh -n 0 --real-pbft --address a --amount 4000000000 --txin abababab --txix 0```

Submit the transaction with good value and watch it pass:

```./scripts/submit-tx.sh -n 0 --real-pbft --address a --amount 4000 --txin abababab --txix 0```

Submit the same transaction and it should fail:

```./scripts/submit-tx.sh -n 0 --real-pbft --address a --amount 4000 --txin abababab --txix 0```