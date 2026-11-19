❗️ The node is made available for early integration, QA & DevOps activities. Further security, performance and general testing is required across all components ahead of a test and mainet launch ❗️ 

# Independent Node Cluster Capabilities 📦 



## Iteration #2 Capabilities (Current) - Made available mid July 2019 ✔️

In addition to iteration #1:

**Consensus**
* Chain state storage implementation & integration
  * The implementation of Ouroboros chain validation and chain selection
  * All storage components integrated: immutable, volatile, ledger state
  * Chain state implemented on top of the storage components
  * Effecient APIs for use by the network protocol handlers (iterators for block fetch, readers for chain sync)
* Improved mempool implementation
  * API that matches what the tx submission protocol handler needs
  * Structure that enables trace points for tracking mempool size and TPS throughput
  * But not final integration of the node-to-node tx submission protocol

**Network**
* Integration of DNS based peer discovery & connection management
* Local client template, to use as a basis for writing node clients
* Node to client protocol complete

**Logging**
* Tracepoint updates (ongoing activity during QA & DevOps testing)

⚠️ **Iteration #2 Limitations** ⚠️  

There are a few limitations to keep in mind due to the fact that certain things have not yet been integrated.

**Mainnet validation** We have previously demonstrated mainnet validation for the ledger rules, but have not yet demonstrated that for the PBFT consensus rules. While the PBFT rules are integrated, there are some remaining parts to complete to be able to validate mainnet. In particular while the support for EBBs (epoch boundary blocks) is nearly complete, it has not yet been tested against mainnet. Therefore it is not currently possible with the node at this stage to sync with mainnet. We anticipate that this will be completed in time for the next demo.

**Byron (Old -> New) Proxy protocols**
The existing Byron proxy does not yet use exactly the same network protocol as the node itself. It uses chain syncing with whole blocks, whereas the node uses chain syncing with headers and spearate block fetch. The proxy is being updated to use the final chain DB that has recently been completed in the consensus layer (previously it used the immutable storage component directly). Once it uses the full chain DB then it will be straightforward for it to implement the same chain sync and block fetch protocols. This will enable a node to connect to a proxy transparently, as if it were any other node. We expect this will take another week or two to complete. This will then enable us to demonstrate live syncing with mainnet.

**Transaction relay** The node to node transaction submission protocol has not yet been integrated. This means that while it is possible to submit transactions locally to a block producing node, it is not yet possible to submit them to one node and have them forwarded to other nodes. The code here has seen substantial improvements
and we now anticipate that this will be integrated in time for the next demo.

## Iteration #3 Capabilities - Due mid-late July 2019 🔨 

**Consensus & Network**
* Old -> New Proxy updated to use the ChainDB and final node-to-node protocols
* Full mainnet syncing and validation
* Node to node transaction relaying

***
_Previous iteration content for completeness_

## Iteration #1 Capabilities - Made available mid June 2019 ✔️ 
* Node that communicate using TCP across different machines
* In memory storage for chain  
* Establish independent cluster using PBFT
    * Some limitations due to lack of connection management integration 
* Full network stack (exclusions listed further down)
    * Node to node:
        * Chain sync
        * Block fetch
        * Block fetch logic
    * Node to client:
        * Chain sync
        * Transaction submission to mempool
* Create blocks and distribute using PBFT Consensus algorithm 
* Validate blocks and transactions with blocks using final Byron compatible Ledger rules 
* Submit transactions local to block producing nodes
* Mock transactions that are elaborated into real transactions 
* Initial node shell integration 
* Consensus as a feature 
* Configuration 
* Logging and Monitoring 
    * Command line arguments parser 
    * Prometheus interface (EKG / monitoring metrics )
    * Mempool Tx level logging (transactions in Mempool)
    * Tx submission logging


⚠️ **Iteration #1 Limitations** ⚠️  

There are a few limitations to keep in mind due to the fact that certain things have not yet been integrated.

**Storage** The real storage system has not yet been integrated. The node now is using the mock storage implementation. The consequence of this is that the chain storage is in-memory and not on disk. So this limits the size of the chain that can be tested, and the chain is not persistent on restart. So this precludes syncing with mainnet. The full storage subsystem uses the same API as the mock one so the integration is expected to be straightforward, and it is expected to be integrated for the next demo.

**Connection management** The network connection management subsystem has not yet been integrated. The node is currently using very simplistic static connection logic: it will establish the requested connections on startup but not re-establish connections on failure. The consequence is that any peer disconnecting causes an exception that will shut down the node. The full connection management subsystem is currently in testing and it is expected to be integrated for the next demo.

**Mainnet validation** We have previously demonstrated mainnet validation for the ledger rules, but have not yet demonstrated that for the PBFT consensus rules. While the PBFT rules are integrated, there are some remaining parts to complete to be able to validate mainnet. In particular the support for EBBs (epoch boundary blocks). Therefore it is not currently possible with the node at this stage to sync with mainnet. We anticipate that this will be completed in time for the next demo.

**Local clients** The node to client protocol has been integrated but the chain sync part does not yet have a example client. This will be needed for wallet integration. This is a relatively small addition and so we expect to have a chain sync client template available for the next demo.

**Transaction relay** The node to node transaction submission protocol has not yet been integrated. This means that while it is possible to submit transactions locally to a block producing node, it is not yet possible to submit them to one node and have them forwarded to other nodes. The code for this component is mostly complete, including tests, so we anticipate that this will be integrated in time for the next demo.