Hello all, this page will be used to keep a static status of the Byron Re-Write node. 

This supports the [Haskell Node Capabilities](https://github.com/input-output-hk/cardano-node-wiki/wiki/Cardano-Haskell-Node-Capabilities "Byron Haskell Node Capabilities") page.

The work below is that specifically required to make the node _**public test and main net ready**_.



📅 _As of 12/07/2019_


***

****Node Implementation**** 🛠 Tasks - remaining development team effort

**Consensus**
* Extend the mempool:
   * Track transaction sizes
   * Expire older transactions
   * In addition to transactions, support delegation and update payloads
* Chain Sync Client optimisations:
    * Track block sizes
    * Pipelining
    * Disconnect from nodes with invalid blocks

**Networking**
- Old -> New Proxy updated to use the ChainDB and final node-to-node protocols
- Node to node transaction relaying
***

****OS Platform Config**** 🌳  Tasks - remaining development team effort

**Windows**
* Cannot interrupt blocking network I/O ops on Windows in the standard network package. We will likely need to bind the few socket operations we need directly, with "interruptable" FFI calls, and use them in our MuxBearer abstraction.
* Need to complete Windows named pipe library and use it for local connections (API similar to Unix domain sockets)
* Windows bugs 🐞  

***

****Monitoring & Benchmarking**** 🔎📝  Tasks remaining

* Transaction generator to run system benchmarks
* Benchmarking and monitoring of cardano-node ;”live-view”  
* Capture mempool metrics and chain metrics  
* Support teams for implementing logging, benchmarking, monitoring - wallet BE, consensus, networking, ledger, devops

***
****Test Infrastructure**** 🏗  Tasks remaining

* Valid Chain Generators
* Invalid Chain Generators

***

**Testing** ⚡️ 🐛   Major test coverage remaining  

**Consensus**
* Protocol testing: do we reach consensus in the following cases (some are overlapping)
  * A node joins the network at a later point in time
  * A node disconnects and rejoins the network
  * There is a (temporary) network partition
  * There are delays in the network
  * Different network topologies
  * A node encounters corruption and restarts with a truncated chain
  * There is an explicit adversary
  * A node produces a few (or many) invalid blocks
  * A block doesn't match its header
  * There are multiple slot leaders or none at all
* Test what happens when there is a shortage of file handles. Additionally, we should make sure we don't leak file handles and what happens when a handle fails to close.

**Networking**
* Timeouts for mini-protocols 
* Managing full duplex connections, termination / suspension of one side of the connection 
* Assign sensible byte limits for each of the mini-protocols
* Fix issues in subscription management
* Extend subscription management to be able to track positive and negative reputation information (Delta-Q,detect mini-protocol failures and misbehaviours).

**System level testing**
* A small network of Shelley nodes
* A small network of Shelley nodes on mixed architectures (RasberyPi, GNU/Linux, Windows, MacOs)
* A small network of Shelley and Byron nodes deployed with a Byron-Proxy

***
****DevOps**** 🔧  Tasks - tooling activity 

* CLI Tools 
   * `genesis-tool` (a slight misnomer) -- generates genesis, migrates and pretty-prints secrets
   * Update proposal and vote submission