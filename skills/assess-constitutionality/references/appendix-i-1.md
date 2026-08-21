### **1. Introduction**

To implement Cardano Blockchain on-chain governance, it is necessary to
establish sensible Guardrails that will enable the Cardano Blockchain to
continue to operate in a secure and sustainable way.

This Appendix sets forth Guardrails that must be applied to Cardano
Blockchain on-chain governance actions, including changes to the
protocol parameters and limits on treasury withdrawals. These Guardrails
cover both essential, intrinsic limits on settings, and recommendations
that are based on experience, research, measurement, and governance
objectives.

These Guardrails are designed to avoid both unexpected and foreseeable
problems with the operation of the Cardano Blockchain. They are intended
to guide the choice of sensible parameter settings and avoid potential
problems with security, performance, functionality, or long-term
sustainability. As described below, some of these Guardrails are
automatable and will be enforced via an on-chain Guardrails Script or
built-in ledger rules.

These Guardrails apply only to the Cardano Blockchain Layer 1 mainnet
environment. They are not intended to apply to test environments or to
other blockchains that use Cardano Blockchain software.

Not all parameters for the Cardano Blockchain can be considered
independently. Some parameters interact with other settings in an
intrinsic way. Where known, these interactions are addressed in this
Appendix.

While the Guardrails in this Appendix presently reflect the current
state of technical insight, this Appendix should be treated as a living
document. Implementation improvements, new simulations or performance
evaluation results for the Cardano Blockchain may allow some of the
restrictions contained in these Guardrails to be relaxed or tightened in
due course.

Additional Guardrails may also be needed where, for example, new
protocol parameters are introduced or existing ones are removed.

#### **Amending, Adding or Deprecating Guardrails**

The Guardrails set forth in this Appendix may be amended from time to
time pursuant to an on-chain governance action that satisfies the
applicable voting threshold as set forth in this Appendix. Any such
amendment to any Guardrails shall require and be deemed to be an
amendment to the Constitution itself, including any new Guardrails. Each
Guardrail has a unique label. If the text of a Guardrail is amended, the
existing Guardrail will be deprecated and a new label will be used in
this Appendix. Similarly, if a Guardrail is deprecated, its label will
never be reused in the future. In all cases, the Guardrails that apply
to a governance action will be those in force at the time that the
governance action is submitted on-chain, regardless of any later
amendments.

#### **Terminology and Guidance**

This section provides supplementary definitions and interpretive
guidance for terms used throughout this Constitution and the Guardrails
Appendix.

Cardano Blockchain. The decentralized, public, peer-to-peer,
proof-of-stake distributed ledger system, designed to securely record,
verify, and synchronize transactions and data across the network while
enabling the execution of smart contracts and decentralized
applications. This system, powered by ada, is the longest chain of
blocks with sufficient confirmations to be considered finalized starting
from block Hash
5f20df933584822601f9e3f8c024eb5eb252fe8cefb24d1317dc3d432e940ebb, as
forged on 2017-09-23 21:44:51 UTC on the Cardano Network.

Block. A container of data produced by a Stake Pool that includes, at
minimum, a header. Block production and block forging are used
interchangeably.

Protocol. The algorithms, rules, and procedures that govern the exchange
of information on the Cardano Blockchain.

Protocol Parameters. Protocol settings that define how the Cardano
Blockchain functions; modifiable through applicable governance
processes.

Slot. The smallest denomination of time nested within an Epoch.

Epoch. A Protocol-determined interval characterized by a fixed number of
Slots. Each Slot's duration and sequence are governed by the
blockchain's consensus mechanisms and are associated with a universal
timestamp defined in UTC. It is used for operations including governance
voting, Block production leadership determination, rewards calculation,
and Hard Forks.

lovelace. The smallest unit of value for the native cryptocurrency of
the Cardano Blockchain, utilized for the network's security and
governance. It is distinguished from other native tokens by its lack of
a policy ID and policy name.

ada. A superunit of lovelace, with 1 ada equal to 1,000,000 lovelace.

Delegator. A private key holder that delegates stake to a Stake Pool for
block production and network security, to a DRep for participation in
on-chain governance, or both. In doing so, the delegator contributes to
the operation and governance of the Cardano Blockchain.

Active Block Production Stake. The cumulative amount of stake, measured
in lovelace, that is actively delegated to Stake Pools and utilized for
block forging during the current Epoch. This amount is determined by a
snapshot of stake distribution taken at the beginning of the previous
Epoch, ensuring that it accurately represents the effective stake
available for securing and maintaining the Cardano Blockchain through
block forging.

On-chain. A classification for actions, transactions, or governance
activities that are executed, recorded, or implemented directly on the
Cardano Blockchain. These actions, transactions, or governance
activities are permanently validated and stored through the blockchain's
consensus mechanism, ensuring their immutability and transparency.

Off-Chain. A classification for activities, proposals, or governance
decisions that are either not yet implemented on the Cardano Blockchain,
or not intended to be directly recorded on the blockchain. These may
include discussions, proposals, or agreements that exist outside the
blockchain and do not involve direct consensus or on-chain validation.

Governance Action. An on-chain proposal enabling participation in
shaping the future of the Cardano Blockchain Ecosystem through voting
transactions.

Hard Fork. A Protocol upgrade for the Cardano Blockchain that results in
a new Protocol version and necessitates coordinated adoption by network
participants.

Guardrails. A set of restrictions on Governance Actions to prevent
undesirable outcomes and assist voters in deciding whether the proposed
action complies with the Cardano Blockchain Ecosystem Constitution. Some
guardrails are enforced using the Guardrails Script or ledger rules to
prevent submission of the action, while others necessitate further
adjudication to determine if they violate the Constitution in ways the
Guardrails Script or ledger cannot check. Guardrails may be either
mandatory ("must"/"must not") or advisory ("should"/"should not"). The
latter allows for interpretive flexibility where necessary.

Guardrails Script. A smart contract script that checks specific proposed
Governance Actions, "Hard Fork Initiation" and "Parameter Update"
actions, against automatically checkable Guardrails. The check is applied
when the Governance Action is proposed on-chain.

Motion of no confidence governance action ("No Confidence" action). A
motion to create a state of no confidence in the current constitutional
committee.

Update committee and/or threshold and/or terms governance action
("Update Committee" action). Changes to the members of the
Constitutional Committee and/or to its signature threshold and/or terms.

New Constitution or Guardrails Script governance action ("New
Constitution" action). A modification to the Constitution or Guardrails
Script, recorded as on-chain hashes.

Hard Fork Initiation governance action ("Hard Fork Initiation" action).
Triggers a non-backwards compatible upgrade of the network; requires a
prior software upgrade.

Protocol Parameter Changes governance action ("Parameter Changes" action
or "Parameter Update" action). Any change to one or more updatable
protocol parameters, excluding changes to major protocol versions
("hard forks").

Treasury Withdrawals governance action ("Treasury Withdrawals" action).
Withdrawals from the treasury.

Info action ("Info" action). An action that has no effect on-chain,
other than an on-chain record.

Cardano Blockchain Treasury, Cardano Treasury, or Treasury. A supply of
ada controlled by the Protocol of the Cardano Blockchain; collected from
transaction fees, reserves, and other designated sources. Withdrawals
from this supply of ada are subject to the processes and restrictions
set forth in the Cardano Blockchain Ecosystem Constitution.

Cardano Blockchain Ecosystem. The collective ecosystem comprising the
Cardano Blockchain, the Cardano Community, and the tooling and
infrastructure utilized by the Cardano Community to support the Cardano
Blockchain in alignment with the shared principles and objectives set
forth in the Cardano Blockchain Ecosystem Constitution.

Expected. A reasonable presumption that the identified action, although
not mandatory, will occur.

Should/Should not. Where this Appendix says that a value "should not"
be set below or above some value, this means that the Guardrail is a
recommendation or guideline, and the specific value could be open to
discussion or alteration by a suitably expert group recognized by the
Cardano Community in light of experience with the Cardano Blockchain
governance system or the operation of the Cardano Blockchain.

Must/Must not. Where this Appendix says that a value "must" or "must
not" be set below or above some value, this means that the Guardrail is
a requirement that will be enforced by Cardano Blockchain ledger rules,
types or other built-in mechanisms where possible, and that if not
followed could cause a protocol failure, security breach or other
undesirable outcome.

Benchmarking. Benchmarking refers to careful system level performance
evaluation that is designed to show *a priori* that, for example, 95% of
blocks will be diffused across a global network of Cardano Blockchain
nodes within the required 5s time interval in all cases. This may
require construction of specific test workflows and execution on a large
test network of Cardano Blockchain nodes, simulating a global Cardano
Blockchain network.

Performance analysis. Performance analysis refers to projecting
theoretical performance, empirical benchmarking or simulation results to
predict actual system behavior. For example, performance results
obtained from tests in a controlled test environment (such as a
collection of data centers with known networking properties) may be
extrapolated to inform likely performance behavior in a real Cardano
Blockchain network environment.

Simulation. Simulation refers to synthetic execution that is designed to
inform performance/functionality decisions in a repeatable way. For
example, the IOSim Cardano Blockchain module allows the operation of the
networking stack to be simulated in a controlled and repeatable way,
allowing issues to be detected before code deployment.

Performance Monitoring. Performance monitoring involves measuring the
actual behavior of the Cardano Blockchain network, for example, by using
timing probes to evaluate round-trip times, or test blocks to assess
overall network health. It complements benchmarking and performance
analysis by providing information about actual system behavior that
cannot be obtained using simulated workloads or theoretical analysis.

Reverting Changes. Where performance monitoring shows that actual
network behavior following a change is inconsistent with the performance
requirements for the Cardano Blockchain, then the change must be
reverted to its previous state if that is possible. For example, if the
block size is increased from 100KB to 120KB and 95% of blocks are no
longer diffused within 5s, then a change must be made to revert the
block size to 100KB. If this is not possible, then one or more
alternative changes must be made that will ensure that the performance
requirements are met.

Severity Levels. Issues that affect the Cardano Blockchain network are
classified by severity level, where:

-   Severity 1 is a critical incident or issue with very high impact to
    the security, performance, functionality or sustainability of the
    Cardano Blockchain network

-   Severity 2 is a major incident or issue with significant impact to
    the security, performance, functionality or sustainability of the
    Cardano Blockchain network

-   Severity 3 is a minor incident or issue with low impact to the
    security, performance, functionality or sustainability of the
    Cardano Blockchain network

Future Performance Requirements. Planned development such as new
mechanisms for out of memory storage may impact block diffusion or other
times. When changing parameters, it is necessary to consider these
future performance requirements as well as the current operation of the
Cardano Blockchain. Until development is complete, the requirements will
be conservative but may then be relaxed to account for actual timing
behavior.

#### **Automated Checking ("Guardrails Script")**

A script hash is associated with the Constitution hash when a New
Constitution or Guardrails Script governance action is enacted. It acts
as an additional safeguard to the ledger rules and types, filtering
non-compliant governance actions.

The Guardrails Script only affects two types of governance actions:

-   "Parameter Update" actions, and

-   "Treasury Withdrawals" action.

The Guardrails Script is executed when either of these types of
governance action is submitted on-chain. This avoids scenarios where,
for example, an erroneous script could prevent the Cardano Blockchain
from ever enacting a Hard Fork action, resulting in deadlock. There are
three different situations that apply to Guardrail Script usage.

Symbol and Explanation

-   (y) The Guardrail Script can be used to enforce the Guardrail

-   (x) The Guardrail Script cannot be used to enforce the Guardrail

-   (~ - reason) The Guardrail Script cannot be used to enforce the
    Guardrail for the reason given, but future ledger changes could
    enable this.

Guardrails may overlap: in this case, the most restrictive set of
Guardrails will apply.

Where a parameter is not explicitly listed in this document, then the
Guardrail Script must not permit any changes to the parameter.

Conversely, where a parameter is explicitly listed in this document but
no checkable Guardrails are specified, the Guardrail Script must not
impose any constraints on changes to the parameter.
