[_Demo run internally 12th July 2019_]

# Background
This demo is the second demo of a cluster of independent Cardano nodes in the Shelley era, first release - Byron Re-write.

The previous demo showed the full integration of all the major components. This demo focuses on the consensus chain state functionality. Whereas the previous demo used the mock implementation of this functionality, this time we are using the full implementation. The full implementation uses the on-disk storage components (immutable, volatile and ledger), and provides efficient, concurrent, implementations of the chain state API.

There are still some features of the node missing that will be included over the coming weeks. For a comprehensive overview of the current capabilities and limitations, see the [this page](https://github.com/input-output-hk/cardano-node-wiki/wiki/Cardano-Haskell-Node-Capabilities).

# What are we looking at?

* We will set up three core nodes, which will run the PBFT consensus algorithm and communicate with each other using the full network stack.
* These nodes will then start producing blocks when they are elected leader (which is round-robin in PBFT).
* We will see from the log output that the nodes agree on their latest chain tip hash (with short delays).
* We will shut down and restart a node and see that it resumes from the point where it was shut down, and synchronises with the other nodes.
* We will corrupt part of the storage of one node by deleting its "volatile chain storage". We will see that the node terminates. When it is restarted we see that it recovers from an earlier point (the tip of the "immutable chain storage") and then see that it synchronises with the other nodes.
* We will then submit some transactions to these nodes to be included in the blockchain, and see that they get included into blocks and all nodes continue to agree on the latest chain tip.

# What does this show?
This shows that we are able to use the proper implementation of the Ouroboros chain validation and chain selection, with on-disk block storage. This is designed to be efficient and resistant to asymmetric resource consumption and other denial of service attacks. It also demonstrates the integration of all the on-disk storage components, which are designed to be robust to hard shutdowns and filesystem corruption (silent or otherwise).

This builds on the previous demo so it also shows that multiple nodes can run independently and communicate with each other using the full network stack. It shows transaction submission with a real mempool implementation, using the real PBFT ledger.

The addition of the on-disk storage means we can now set up a long-running staging cluster, since we are no longer using the mock in-memory storage (which was not intended to scale).

# Next steps
The next steps across the various parts of the node include:
- Completing EBB support in the ledger/consensus integration, and testing validating against mainnet epochs
- Updating the Byron proxy to use the full node's chain storage subsystem, and to work transparently with nodes by using exactly the same protocol bundle.
- Completing integration and testing of node-to-node transaction relay in the consensus layer
- Starting integration with the Wallet Backend
- Improving test coverage and infrastructure across the whole system

# Running the demo yourself

Check out the `demo` branch in this repository:

```git checkout demo```

Build it using stack, cabal new-build, or nix (see the the README for specific instructions):

```stack build```

Open a terminal, navigate to the root of this repository, and start the demo script like so:

```tmux new-session -s Demo```

```./scripts/demo.sh```

This will leave you with four `tmux` panes, three for the nodes and one to submit transactions.

To submit a transaction, navigate to the fourth pane and press enter.

To kill a node, navigate to the node's respective pane, and press <kbd>CTRL-C</kbd>. Restart it by using <kbd>Up</kbd> to navigate to the command that started the node.

To remove the volatile storage of a node, e.g., node 0, execute:

```rm -rf db-0```