# What is a Governance Action?

#### Note: This content is taken directly from [CIP-1694](https://www.1694.io/)

We define seven different types of **governance actions**. A governance action is an on-chain event that is triggered by a transaction and has a deadline after which it cannot be enacted.

* An action is said to be **ratified** when it gathers enough votes in its favor (through the rules and parameters that are detailed below).
* An action that fails to be ratified before its deadline is said to have **expired**.
* An action that has been ratified is said to be **enacted** once it has been activated on the network.

| Action                                                        | Description                                                                                                              |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| 1. Motion of no-confidence                                    | A motion to create a _state of no-confidence_ in the current constitutional committee                                    |
| 2. New constitutional committee and/or threshold and/or terms | Changes to the members of the constitutional committee and/or to its signature threshold and/or terms                    |
| 3. Update to the Constitution or proposal policy              | A modification to the Constitution or proposal policy, recorded as on-chain hashes                                       |
| 4. Hard-Fork Initiation                                      | Triggers a non-backwards compatible upgrade of the network; requires a prior software upgrade                            |
| 5. Protocol Parameter Changes                                 | Any change to **one or more** updatable protocol parameters, excluding changes to major protocol versions ("hard forks") |
| 6. Treasury Withdrawals                                       | Withdrawals from the treasury                                                                                            |
| 7. Info                                                       | An action that has no effect on-chain, other than an on-chain record                                                     |

**Any Ada holder** can submit a governance action to the chain. They must provide a deposit of `govActionDeposit` Lovelace, which will be returned when the action is finalized (whether it is **ratified** or has **expired**). The deposit amount will be added to the _deposit pot_, similar to stake key deposits. It will also be counted towards the stake of the reward address it will be paid back to, to not reduce the submitter's voting power to vote on their own (and competing) actions.

If a proposal policy is present, the transaction must include that policy in the witness set either directly, or via reference inputs, and any other requirements that the proposal policy makes must be satisfied.

Note that a motion of no-confidence is an extreme measure that enables Ada holders to revoke the power that has been granted to the current constitutional committee.
