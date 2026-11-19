# Bootstrapping phase

:::note Historical
The bootstrapping phase ended when Cardano moved to protocol version 10 (the Plomin hard fork). All Governance Action types can now be proposed and voted on. GovTool only shows the bootstrapping banner and restrictions described below on a network that is still running protocol version 9.
:::

### What is the bootstrapping phase?

The technical bootstrapping phase is a temporary state of governance as described in [CIP-1694 Bootstrapping Phase](https://github.com/cardano-foundation/CIPs/blob/master/CIP-1694/README.md#bootstrapping-phase). Within this state only a limited set of governance features are enabled by the network.

### What are the implications of bootstrapping on GovTool?

#### Ada Holders

* Are able to register as DReps/ direct voters
* Are able to delegate to DReps
* Are **ONLY** able to propose  and submit Info actions via GovTool

#### DReps/Direct Voters

* DReps are able to register.
* Voting is restricted to Info Actions **ONLY**.

#### All Users

* The ONLY types of governance actions viewable on-chain are
  * Info Actions
  * Hard Fork Initiations
  * Parameter changes
