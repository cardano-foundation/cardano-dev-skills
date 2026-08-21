### **2.3. Network Parameters**

The overall goals when managing the Cardano Blockchain network
parameters are to:

1.  Match the available Cardano Blockchain Layer 1 network capacity to
    current or future traffic demands, including payment transactions,
    layer 1 DApps, sidechain management and governance needs

2.  Balance traffic demands for different user groups, including payment
    transactions, minters of Fungible/Non-Fungible Tokens, Plutus
    scripts, DeFi developers, Stake Pool Operators and voting
    transactions

#### **Triggers for Change**

Changes to network parameters may be triggered by:

1.  Measured changes in traffic demands over a 2-epoch period (10 days)

2.  Anticipated changes in traffic demands

3.  Cardano Community requests

#### **Counter-indicators**

Changes may need to be reversed and/or should not be enacted in the
event of:

-   Excessive block propagation delays

-   Stake pools being unable to handle traffic volume

-   Scripts being unable to complete execution

#### **Core Metrics**

All decisions on parameter changes should be informed by:

-   Block propagation delay profile

-   Traffic volume (block size over time)

-   Script volume (size of scripts and execution units)

-   Script execution cost benchmarks

-   Block propagation delay/diffusion benchmarks

Detailed benchmarking results are required to confirm the effect of any
changes on mainnet performance or behavior prior to enactment. The
effects of different transaction mixes must be analyzed, including
normal transactions, Plutus scripts, and governance actions.

##### **GUARDRAILS**

NETWORK-01 (x - "should") No individual network parameter should
change more than once per two epochs

NETWORK-02 (x - "should") Only one network parameter should be changed
per epoch unless they are directly correlated, e.g., per-transaction and
per-block memory unit limits

#### **Changes to Specific Network Parameters**

#### **Block Size (maxBlockBodySize)**

The maximum size of a block, in bytes.

##### **GUARDRAILS**

MBBS-01 (y) *maxBlockBodySize* must not exceed 122,880 bytes (120KB)

MBBS-02 (y) *maxBlockBodySize* must not be lower than 24,576 bytes
(24KB)

MBBS-03a (x - exceptional circumstances) *maxBlockBodySize* must not
be decreased, other than in exceptional circumstances where there are
potential problems with security, performance, functionality or
long-term sustainability

MBBS-04 (~ - no access to existing parameter values) *maxBlockBodySize*
must be large enough to include at least one transaction (that is,
*maxBlockBodySize* must be at least *maxTxSize*)

MBBS-05 (x - "should") *maxBlockBodySize* should be changed by at most
10,240 bytes (10KB) per epoch (5 days), and preferably by 8,192 bytes
(8KB) or less per epoch

MBBS-06 (x - "should") The block size should not induce an additional
Transmission Control Protocol (TCP) round trip. Any increase beyond this
must be backed by performance analysis, simulation and benchmarking

MBBS-07 (x - "unquantifiable") The impact of any change to
*maxBlockBodySize* must be confirmed by detailed benchmarking/simulation
and not exceed the requirements of the block diffusion/propagation time
budgets, as described below. Any increase to *maxBlockBodySize* must
also consider future requirements for Plutus script execution
(*maxBlockExecutionUnits[steps]*) against the total block diffusion
target of 3s with 95% block propagation within 5s. The limit on maximum
block size may be increased in the future if this is supported by
benchmarking and monitoring results

#### **Transaction Size (maxTxSize)**

The maximum size of a transaction, in bytes.

##### **GUARDRAILS**

MTS-01 (y) *maxTxSize* must not exceed 32,768 bytes (32KB)

MTS-02 (y) *maxTxSize* must not be negative

MTS-03 (~ - no access to existing parameter values) *maxTxSize* must
not be decreased

MTS-04 (~ - no access to existing parameter values) *maxTxSize* must
not exceed *maxBlockBodySize*

MTS-05 (x - "should") *maxTxSize* should not be increased by more than
2,560 bytes (2.5KB) in any epoch, and preferably should be increased by
2,048 bytes (2KB) or less per epoch

MTS-06 (x - "should") *maxTxSize* should not exceed 1/4 of the block
size

#### **Memory Unit Limits (maxBlockExecutionUnits[memory], maxTxExecutionUnits[memory])**

The limit on the maximum number of memory units that can be used by
Plutus scripts, either per-transaction or per-block.

##### **GUARDRAILS**

MTEU-M-01 (y) *maxTxExecutionUnits[memory]* must not exceed 40,000,000
units

MTEU-M-02 (y) *maxTxExecutionUnits[memory]* must not be negative

MTEU-M-03 (~ - no access to existing parameter values)
*maxTxExecutionUnits[memory]* must not be decreased

MTEU-M-04 (x - "should") *maxTxExecutionUnits[memory]* should not be
increased by more than 2,500,000 units in any epoch

MBEU-M-01 (y) *maxBlockExecutionUnits[memory]* must not exceed
120,000,000 units

MBEU-M-02 (y) *maxBlockExecutionUnits[memory]* must not be negative

MBEU-M-03 (x - "should") *maxBlockExecutionUnits[memory]* should not
be changed (increased or decreased) by more than 10,000,000 units in ANY
epoch

MBEU-M-04a (x - "unquantifiable") The impact of any change to
*maxBlockExecutionUnits[memory]* must be confirmed by detailed
benchmarking/simulation and not exceed the requirements of the block
diffusion/propagation time budgets, as also impacted by
*maxBlockExecutionUnits[steps]* and *maxBlockBodySize*. Any increase
must also consider previously agreed future requirements for the total
block size (*maxBlockBodySize*) measured against the total block
diffusion target of 3s with 95% block propagation within 5s. Future
Plutus performance improvements may allow the per-block memory limit to
be increased, but must be balanced against the overall diffusion limits
as specified in the previous sentence, and future requirements

MEU-M-01 (~ - no access to existing parameter values)
*maxBlockExecutionUnits[memory]* must not be less than
*maxTxExecutionUnits[memory]*

#### **CPU Unit Limits (maxBlockExecutionUnits[steps], maxTxExecutionUnits[steps])**

The limit on the maximum number of CPU steps that can be used by Plutus
scripts, either per transaction or per-block.

##### **GUARDRAILS**

MTEU-S-01 (y) *maxTxExecutionUnits[steps]* must not exceed
15,000,000,000 (15Bn) units

MTEU-S-02 (y) *maxTxExecutionUnits[steps]* must not be negative

MTEU-S-03 (~ - no access to existing parameter values)
*maxTxExecutionUnits[steps]* must not be decreased

MTEU-S-04 (x - "should") *maxTxExecutionUnits[steps]* should not be
increased by more than 500,000,000 (500M) units in any epoch (5 days)

MBEU-S-01 (y) *maxBlockExecutionUnits[steps]* must not exceed
40,000,000,000 (40Bn) units

MBEU-S-02 (y) *maxBlockExecutionUnits[steps]* must not be negative

MBEU-S-03 (x - "should") *maxBlockExecutionUnits[steps]* should not
be changed (increased or decreased) by more than 2,000,000,000 (2Bn)
units in any epoch (5 days)

MBEU-S-04a (x - "unquantifiable") The impact of the change to
*maxBlockExecutionUnits[steps]* must be confirmed by detailed
benchmarking/simulation and not exceed the requirements of the block
diffusion/propagation time budgets, as also impacted by
*maxBlockExecutionUnits[memory]* and *maxBlockBodySize*. Any increase
must also consider previously identified future requirements for the
total block size (*maxBlockBodySize*) measured against the total block
diffusion target of 3s with 95% block propagation within 5s. Future
Plutus performance improvements may allow the per-block step limit to be
increased, but must be balanced against the overall diffusion limits as
specified in the previous sentence, and future requirements

MEU-S-01 (~ - no access to existing parameter values)
*maxBlockExecutionUnits[steps]* must not be less than
*maxTxExecutionUnits[steps]*

#### **Block Header Size (maxBlockHeaderSize)**

The size of the block header.

##### **GUARDRAILS**

MBHS-01 (y) *maxBlockHeaderSize* must not exceed 5,000 bytes

MBHS-02 (y) *maxBlockHeaderSize* must not be negative

MBHS-03 (x - largest valid header is subject to change)
*maxBlockHeaderSize* must be large enough for the largest valid header

MBHS-04 (x - "should") *maxBlockHeaderSize* should only normally be
increased if the protocol changes

MBHS-05 (x - "should") *maxBlockHeaderSize* should be within TCP's
initial congestion window (3 or 10 MTUs)
