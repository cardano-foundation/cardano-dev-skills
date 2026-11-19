[_Demo run internally 1st August 2019_]

# Background
This demo is the third demo of a cluster of independent Cardano nodes in the Shelley era, first release - Byron Re-write.

The previous demo showed the use of the full consensus implementation: on-disk storage, Ouroboros chain validation  and chain selection. It showed it in the context of a small cluster started from genesis.

This demo focuses on mainnet compatibility. In this demo we will show our new node synchronising with and validating mainnet. This demonstrates that the node works with the scale of data from mainnet, and the real configuration rather than demo configuration.

We will also demonstrate the Byron network proxy. This is a component that understands both the old Byron network protocols and the new Shelley node network protocols and allows the two to exchange data. In this demo we will show that it can download blocks from Byron mainnet relays nodes and allow Shelley nodes to download blocks from it. In future demos we will show information flowing in the opposite direction, both blocks and transactions.

There are still some features of the node missing that will be included over the coming weeks. For a comprehensive overview of the current capabilities and limitations, see the [this page](https://github.com/input-output-hk/cardano-node-wiki/wiki/Cardano-Haskell-Node-Capabilities).

# What are we looking at?

* We will set up a single Byron proxy and a single Shelley node
* The Byron proxy is configured to connect to the existing mainnet relays and synchronise the blockchain into its local storage
* The Shelley node is configured to connect to the Byron proxy and synchronise the blockchain
* We will see the Shelley node running the full Ouroboros consensus algorithm, including chain validation.
* We will see the Byron proxy downloading and validating the chain, but it has to trust its peers because it does not run full Ouroboros consensus algorithm -- it is not a full node.

# What does this show?
This shows that we are able to handle the details of the existing mainnet chain format (including EBBs!) and network protocols and succesfully synchronise with and validate the existing mainnet. Validating the real mainnet epochs (chain level and ledger level) is an important part of the validation of the new implementation of the Byron rules.

The demonstration shows both the old and new network protocols can be used in the same system, though in separate components so the new node is not burdened with the compatibility. It shows that nodes can use the proxy completely transparently: the nodes do not need to know that the peer they are talking to is a proxy and not another full node. This is important for easy of configuration and deployment.

# Next steps
The next steps across the various parts of the node include:
- Completing the Byron proxy to support data flows in the other direction: sending blocks and transactions from new nodes to old nodes.
- Continuing integration with the Wallet Backend
- Improving test coverage and infrastructure across the whole system
- Profiling and optimising the node for improved performance and memory use
- Improving the command line tools
- Integrating more trace points to enable system level benchmarks

# Running the demo yourself

## The proxy

Get a checkout of the `cardano-byron-proxy` git repository:
```
git clone https://github.com/input-output-hk/cardano-byron-proxy.git
cd cardano-byron-proxy
git checkout avieth/chaindb
```
Build it using cabal new-build, stack, or nix (see the the README for specific instructions):
```
cabal new-build
```
Create a `topology.yaml` file:
```
wallet:
  relays: [[{ host: relays.cardano-mainnet.iohk.io }]]
```
Copy the `mainnet-genesis.json` from the `cardano-sl` repo into the local directory

Now run the proxy:
```
cabal new-run -- cardano-byron-proxy \
  --database-path db-byron-proxy-demo-server \
  --index-path index-byron-proxy-demo-server \
  --configuration-file ../cardano-sl/lib/configuration.yaml \
  --configuration-key mainnet_full \ 
  --server-host 127.0.0.1 \
  --server-port 7777 \
  --topology ./topology.yaml
```
The proxy should connect to one of the mainnet relays and start to download blocks.

## The node

Check out the `master` branch if this (`cardano-node`) repository
```
git checkout master
git pull
```
If necessary, the exact commit used for the demo was `14da4ddb6e5528c909b44c2ca7d48cfd18244bcb`.

Build the `cardano-node` using cabal new-build,stack, or nix (see the the README for specific instructions):
```
cabal new-build
```
Now run the node, configured to point to the proxy:
```
scripts/mainnet-proxy-follower.sh
```
The node should connect to the local proxy and start to synchronise blocks.