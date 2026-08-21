### **9. List of Protocol Parameter Groups**

The protocol parameters are grouped by type, allowing different
thresholds to be set for each group.

The network parameter group consists of:

-   *maximum block body size* (*maxBlockBodySize*)

-   *maximum transaction size* (*maxTxSize*)

-   *maximum block header size* (*maxBlockHeaderSize*)

-   *maximum size of a serialized asset value* (*maxValueSize*)

-   *maximum script execution units in a single transaction*
    (maxTxExecutionUnits[steps])

-   *maximum script execution units in a single block*
    (*maxBlockExecutionUnits[steps]*)

-   *maximum number of collateral inputs* (*maxCollateralInputs*)

The economic parameter group consists of:

-   *minimum fee coefficient* (*txFeePerByte*)

-   *minimum fee constant* (*txFeeFixed*)

-   *minimum fee per byte for reference scripts*
    (*minFeeRefScriptCoinsPerByte*)

-   *delegation key lovelace deposit* (*stakeAddressDeposit*)

-   *pool registration lovelace deposit* (*stakePoolDeposit*)

-   *monetary expansion* (*monetaryExpansion*)

-   *treasury expansion* (*treasuryCut*)

-   *minimum fixed rewards cut for pools* (*minPoolCost*)

-   *minimum lovelace deposit per byte of serialized UTxO*
    (*coinsPerUTxOByte*)

-   *prices of Plutus execution units*
    (*executionUnitPrices[priceSteps/priceMemory]*)

The technical/security parameter group consists of:

-   *pool pledge influence* (*poolPledgeInfluence*)

-   *pool retirement maximum epoch* (*poolRetireMaxEpoch*)

-   *desired number of pools* (*stakePoolTargetNum*)

-   *Plutus execution cost models* (*costModels*)

-   *proportion of collateral needed for scripts*
    (*collateralPercentage*)

The governance parameter group consists of:

-   *governance voting thresholds* (*dRepVotingThresholds[...],
    poolVotingThresholds[...]*)

-   *governance action maximum lifetime in epochs* (*govActionLifetime*)

-   *governance action deposit* (*govDeposit*)

-   *DRep deposit amount* (*dRepDeposit*)

-   *DRep activity period in epochs* (*dRepActivity*)

-   *minimal Constitutional Committee size* (*committeeMinSize*)

-   *maximum term length (in epochs) for the Constitutional Committee
    members* (*committeeMaxTermLength*)
