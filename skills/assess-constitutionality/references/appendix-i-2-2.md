### **2.2. Economic Parameters**

The overall goals when managing economic parameters are to:

1.  Enable long-term economic sustainability for the Cardano Blockchain;

2.  Ensure that stake pools are adequately rewarded for maintaining the
    Cardano Blockchain;

3.  Ensure that ada owners are adequately rewarded for using stake in
    constructive ways, including when delegating ada for block
    production; and

4.  Balance economic incentives for different Cardano Blockchain
    ecosystem stakeholders, including but not limited to Stake Pool
    Operators, ada owners, DeFi users, infrastructure users,
    developers (e.g. DApps) and financial intermediaries (e.g.
    exchanges)

#### **Triggers for Change**

1.  Significant changes in the fiat value of ada resulting in potential
    problems with security, performance, functionality, or long-term
    sustainability

2.  Changes in transaction volumes or types

3.  Community requests or suggestions

4.  Emergency situations that require changes to economic parameters

#### **Counter-indicators**

Changes to the economic parameters should not be made in isolation. They
need to account for:

-   External economic factors

-   Network security concerns

#### **Core Metrics**

-   Fiat value of ada resulting in potential problems with security,
    performance, functionality, or long-term sustainability

-   Transaction volumes and types

-   Number and health of stake pools

-   External economic factors

#### **Changes to Specific Economic Parameters**

Transaction fee per byte (txFeePerByte) and fixed transaction fee
(txFeeFixed)

Defines the cost for basic transactions in lovelace:

*fee(tx) = txFeeFixed + txFeePerByte x nBytes(tx)*

##### **GUARDRAILS**

TFPB-01 (y) *txFeePerByte* must not be lower than 30 (0.000030 ada) This
protects against low-cost denial of service attacks

TFPB-02 (y) *txFeePerByte* must not exceed 1,000 (0.001 ada) This
ensures that transactions can be paid for

TFPB-03 (y) *txFeePerByte* must not be negative

TFF-01 (y) *txFeeFixed* must not be lower than 100,000 (0.1 ada) This
protects against low-cost denial of service attacks

TFF-02 (y) *txFeeFixed* must not exceed 10,000,000 (10 ada) This ensures
that transactions can be paid for

TFF-03 (y) *txFeeFixed* must not be negative

TFGEN-01 (x - "should") To maintain a consistent level of protection
against denial-of-service attacks, *txFeeFixed* and *txFeePerByte*
should be adjusted whenever Plutus Execution prices are adjusted
(executionUnitPrices[steps/memory])

TFGEN-02 (x - "unquantifiable") Any changes to *txFeeFixed* or
*txFeePerByte* must consider the implications of reducing the cost of a
denial-of-service attack or increasing the maximum transaction fee so
that it becomes impossible to construct a transaction.

#### **UTxO cost per byte (utxoCostPerByte)**

Defines the deposit (in lovelace) that is charged for each byte of
storage that is held in a UTxO. This deposit is returned when the UTxO
is no longer active.

-   Sets a minimum threshold on ada that is held within a single UTxO

-   Provides protection against low-cost denial of service attack on
    UTxO storage. DoS protection decreases in line with the free node
    memory (proportional to UTxO growth)

-   Helps reduce long-term storage costs for node users by providing an
    incentive to return UTxOs when no longer needed, or to merge
    UTxOs.

##### **GUARDRAILS**

UCPB-01 (y) *utxoCostPerByte* must not be lower than 3,000 (0.003 ada)

UCPB-02 (y) *utxoCostPerByte* must not exceed 6,500 (0.0065 ada)

UCPB-03 (y) *utxoCostPerByte* must not be zero

UCPB-04 (y) *utxoCostPerByte* must not be negative

UCPB-05a (x - "should") Changes should account for

1.  The acceptable cost of attack

2.  The acceptable time for an attack

3.  The acceptable memory configuration for full node users

4.  The sizes of UTxOs and

5.  The current total node memory usage

#### **Stake address deposit (stakeAddressDeposit)**

Ensures that stake addresses are retired when no longer needed

-   Helps reduce long-term storage costs

-   Helps limit CPU and memory costs in the ledger

The rationale for the deposit is to incentivize that scarce memory
resources are returned when they are no longer required. Reducing the
number of active stake addresses also reduces processing and memory
costs at the epoch boundary when calculating stake snapshots.

##### **GUARDRAILS**

SAD-01 (y) *stakeAddressDeposit* must not be lower than 1,000,000 (1
ada)

SAD-02 (y) *stakeAddressDeposit* must not exceed 5,000,000 (5 ada)

SAD-03 (y) *stakeAddressDeposit* must not be negative

#### **Stake pool deposit (stakePoolDeposit)**

Ensures that stake pools are retired by the stake pool operator when no
longer needed by them

-   Helps reduce long-term storage costs

The rationale for the deposit is to incentivize that scarce memory
resources are returned when they are no longer required. Rewards and
stake snapshot calculations are also impacted by the number of active
stake pools.

##### **GUARDRAILS**

SPD-01 (y) *stakePoolDeposit* must not be lower than 250,000,000 (250
ada)

SPD-02 (y) *stakePoolDeposit* must not exceed 500,000,000 (500 ada)

SPD-03 (y) *stakePoolDeposit* must not be negative

#### **Minimum Pool Cost (minPoolCost)**

Part of the rewards mechanism

-   The minimum pool cost is transferred to the pool rewards address
    before any delegator rewards are paid

##### **GUARDRAILS**

MPC-01 (y) *minPoolCost* must not be negative

MPC-02 (y) *minPoolCost* must not exceed 500,000,000 (500 ada)

MPC-03 (x - "should") *minPoolCost* should be set in line with the
economic cost for operating a pool

#### **Treasury Cut (treasuryCut)**

Part of the rewards mechanism

-   The treasury cut portion of the monetary expansion is transferred to
    the treasury before any pool rewards are paid

-   Can be set in the range 0.0-1.0 (0%-100%)

##### **GUARDRAILS**

TC-01 (y) *treasuryCut* must not be lower than 0.1 (10%)

TC-02 (y) *treasuryCut* must not exceed 0.3 (30%)

TC-03 (y) *treasuryCut* must not be negative

TC-04 (y) *treasuryCut* must not exceed 1.0 (100%)

TC-05 (~ - no access to change history) *treasuryCut* must not be
changed more than once in any 36 epoch period (approximately 6 months)

#### **Monetary Expansion Rate (monetaryExpansion)**

Part of the rewards mechanism

-   The monetary expansion controls the amount of reserves that is used
    for rewards each epoch

Governs the long-term sustainability of the Cardano Blockchain

-   The reserves are gradually depleted until no rewards are supplied

##### **GUARDRAILS**

ME-01 (y) *monetaryExpansion* must not exceed 0.005

ME-02 (y) *monetaryExpansion* must not be lower than 0.001

ME-03 (y) *monetaryExpansion* must not be negative

ME-04 (x - "should") *monetaryExpansion* should not be varied by more
than +/- 10% in any 73-epoch period (approximately 12 months)

ME-05 (x - "should") *monetaryExpansion* should not be changed more
than once in any 36-epoch period (approximately 6 months)

#### **Plutus Script Execution Prices (executionUnitPrices[priceSteps/priceMemory])**

Define the fees for executing Plutus scripts

Gives an economic return for Plutus script execution

Provides security against low-cost DoS attacks

##### **GUARDRAILS**

EIUP-PS-01 (y) *executionUnitPrices[priceSteps]* must not exceed 2,000
/ 10,000,000

EIUP-PS-02 (y) *executionUnitPrices[priceSteps]* must not be lower
than 500 / 10,000,000

EIUP-PM-01 (y) *executionUnitPrices[priceMemory]* must not exceed
2,000 / 10,000

EIUP-PM-02 (y) *executionUnitPrices[priceMemory]* must not be lower
than 400 / 10,000

EIUP-GEN-01 (x - "similar to") The execution prices must be set so
that

1.  the cost of executing a transaction with maximum CPU steps is
    similar to the cost of a maximum sized non-script transaction and

2.  the cost of executing a transaction with maximum memory units is
    similar to the cost of a maximum sized non-script transaction

EIUP-GEN-02 (x - "should") The execution prices should be adjusted
whenever transaction fees are adjusted (*txFeeFixed/txFeePerByte*). The
goal is to ensure that the processing delay is similar for "full"
transactions, regardless of their type.

-   This helps ensure that the requirements on block
    diffusion/propagation times are met.

#### **Transaction fee per byte for a reference script (minFeeRefScriptCoinsPerByte)**

Defines the cost for using Plutus reference scripts in lovelace

##### **GUARDRAILS**

MFRS-01 (y) *minFeeRefScriptCoinsPerByte* must not exceed 1,000 (0.001
ada)

-   This ensures that transactions can be paid for

MFRS-02 (y) *minFeeRefScriptCoinsPerByte* must not be negative

MFRS-03 (x - "should") To maintain a consistent level of protection
against denial-of-service attacks, *minFeeRefScriptCoinsPerByte* should
be adjusted whenever Plutus Execution prices are adjusted
(*executionUnitPrices[steps/memory]*) and whenever *txFeeFixed* is
adjusted

MFRS-04 (x - "unquantifiable") Any changes to
*minFeeRefScriptCoinsPerByte* must consider the implications of reducing
the cost of a denial-of-service attack or increasing the maximum
transaction fee
