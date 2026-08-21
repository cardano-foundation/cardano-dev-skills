### **2.4. Technical/Security Parameters**

The overall goals when managing the technical/security parameters are:

1.  Ensure the security of the Cardano Blockchain network in terms of
    decentralization and protection against adversarial actions

2.  Enable changes to the Plutus language

#### **Triggers for Change**

1.  Changes in the number of active SPOs

2.  Changes to the Plutus language

3.  Security threats

4.  Cardano Community requests

#### **Counter-indicators**

-   Economic concerns, e.g. when changing the number of stake pools

#### **Core Metrics**

-   Number of stake pools

-   Level of decentralization

#### **Changes to Specific Technical/Security Parameters**

#### **Target Number of Stake Pools (stakePoolTargetNum)**

Sets the target number of stake pools

-   The expected number of stake pools when the network is in the
    equilibrium state

-   Primarily a security parameter, ensuring decentralization by stake
    pool division/replication

-   Has an economic effect as well as a security effect - economic
    advice based on analysis is also required when changing this
    parameter

-   Large changes in this parameter will trigger mass redelegation
    events

##### **GUARDRAILS**

SPTN-01 (y) *stakePoolTargetNum* must not be lower than 250

SPTN-02 (y) *stakePoolTargetNum* must not exceed 2,000

SPTN-03 (y) *stakePoolTargetNum* must not be negative

SPTN-04 (y) *stakePoolTargetNum* must not be zero

#### **Pledge Influence Factor (poolPledgeInfluence)**

Enables the pledge protection mechanism

Provides protection against Sybil attack

-   Higher values reward pools that have more pledge and penalize pools
    that have less pledge

Has an economic effect as well as technical effect - economic advice
based on analysis is also required

##### **GUARDRAILS**

PPI-01 (y) *poolPledgeInfluence* must not be lower than 0.1

PPI-02 (y) *poolPledgeInfluence* must not exceed 1.0

PPI-03 (y) *poolPledgeInfluence* must not be negative

PPI-04 (x - "should") *poolPledgeInfluence* should not vary by more
than +/- 10% in any 18-epoch period (approximately 3 months)

#### **Pool Retirement Window (poolRetireMaxEpoch)**

Defines the maximum number of epochs notice that a pool can give when
planning to retire

##### **GUARDRAILS**

PRME-01 (y) *poolRetireMaxEpoch* must not be negative

PRME-02 (x - "should") *poolRetireMaxEpoch* should not be lower than 1

#### **Collateral Percentage (collateralPercentage)**

Defines how much collateral must be provided when executing a Plutus
script as a percentage of the normal execution cost

-   Collateral is additional to fee payments

-   If a script fails to execute, then the collateral is lost

-   The collateral is never lost if a script executes successfully

Provides security against low-cost attacks by making it more expensive
rather than less expensive to execute failed scripts

##### **GUARDRAILS**

CP-01 (y) *collateralPercentage* must not be lower than 100

CP-02 (y) *collateralPercentage* must not exceed 200

CP-03 (y) *collateralPercentage* must not be negative

CP-04 (y) *collateralPercentage* must not be zero

#### **Maximum number of collateral inputs (maxCollateralInputs)**

Defines the maximum number of inputs that can be used for collateral
when executing a Plutus script

##### **GUARDRAILS**

MCI-01 (y) *maxCollateralInputs* must not be lower than 1

#### **Maximum Value Size (maxValueSize)**

The limit on the serialized size of the Value in each output.

##### **GUARDRAILS**

MVS-01 (y) *maxValueSize* must not exceed 12,288 bytes (12KB)

MVS-02 (y) *maxValueSize* must not be negative

MVS-03 (~ - no access to existing parameter values) *maxValueSize* must
be less than *maxTxSize*

MVS-04 (~ - no access to existing parameter values) *maxValueSize* must
not be reduced

MVS-05 (x - sensible output is subject to interpretation)
*maxValueSize* must be large enough to allow sensible outputs (e.g. any
existing on-chain output or anticipated outputs that could be produced
by new ledger rules)

#### **Plutus Cost Models (costModels)**

Define the base costs for each Plutus primitive in terms of CPU and
memory units

A different cost model is required for each Plutus version. Each cost
model comprises many distinct cost model values. Cost models are defined
for each Plutus language version. A new language version may introduce
additional cost model values or remove existing cost model values.

##### **GUARDRAILS**

PCM-01 (x - "unquantifiable") *Cost model* values must be set by
benchmarking on a reference architecture

PCM-02 (x - primitives and language versions aren't introduced in
transactions) The *cost model* must be updated if new primitives are
introduced or a new Plutus language version is added

PCM-03a (~ - no access to *Plutus cost model* parameters) *Cost model*
values should not normally be negative. Negative values must be
justified against the underlying cost model for the associated
primitives

PCM-04 (~ - no access to *Plutus cost model* parameters) A *cost model*
must be supplied for each Plutus language version that the protocol
supports
