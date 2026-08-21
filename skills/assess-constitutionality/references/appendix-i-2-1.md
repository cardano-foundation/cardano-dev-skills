### **2.1. Critical Protocol Parameters**

The below protocol parameters are critical from a security point of
view.

#### **Parameters that are Critical to the Operation of the Blockchain**

-   *maximum block body size* (*maxBlockBodySize*)

-   *maximum transaction size* (*maxTxSize*)

-   *maximum block header size* (*maxBlockHeaderSize*)

-   *maximum size of a serialized asset value* (*maxValueSize*)

-   *maximum script execution/memory units in a single block*
    (*maxBlockExecutionUnits[steps/memory]*)

-   *minimum fee coefficient* (*txFeePerByte*)

-   *minimum fee constant* (*txFeeFixed*)

-   *minimum fee per byte for reference scripts*
    (*minFeeRefScriptCoinsPerByte*)

-   *minimum lovelace deposit per byte of serialized UTxO*
    (*utxoCostPerByte*)

-   *governance action deposit* (*govDeposit*)

##### **GUARDRAILS**

PARAM-03a (y) A parameter that is critical to the operation of the
blockchain requires an SPO vote in addition to a DRep vote: SPOs must say
"yes" with a collective support of more than 50% of all active block
production stake. This is enforced by the Guardrails on the stake pool
voting threshold.

PARAM-04a (x) At least 90 days should normally pass between the
publication of an off-chain proposal to change a parameter that is
critical to the operation of the blockchain and the submission of the
corresponding on-chain governance action. This Guardrail may be relaxed
in the event of a Severity 1 or Severity 2 network issue following
careful technical discussion and evaluation.

#### **Parameters that are Critical to the Governance System**

-   *delegation key lovelace deposit* (*stakeAddressDeposit*)

-   *pool registration lovelace deposit* (*stakePoolDeposit*)

-   *minimum fixed rewards cut for pools* (*minPoolCost*)

-   *DRep deposit amount* (*dRepDeposit*)

-   *minimal Constitutional Committee size* (*committeeMinSize*)

-   *maximum term length (in epochs) for the Constitutional Committee
    members* (*committeeMaxTermLength*)

##### **GUARDRAILS**

PARAM-05a (y) DReps must vote "yes" with a collective support of more
than 50% of all active voting stake. This is enforced by the Guardrails
on the DRep voting thresholds.

PARAM-06a (x) At least 90 days should normally pass between the
publication of an off-chain proposal to change a parameter that is
critical to the governance system and the submission of the
corresponding on-chain governance action. This Guardrail may be relaxed
in the event of a Severity 1 or Severity 2 network issue following
careful technical discussion and evaluation.
