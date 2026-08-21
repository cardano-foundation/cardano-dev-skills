### **2.5. Governance Parameters**

The overall goals when managing the governance parameters are to:

1.  Ensure governance stability

2.  Maintain a representative form of governance

#### **Triggers for Change**

Changes to governance parameters may be triggered by:

1.  Cardano Community requests

2.  Regulatory requirements

3.  Unexpected or unwanted governance outcomes

4.  Entering a state of no confidence

#### **Counter-indicators**

Changes may need to be reversed and/or should not be enacted in the
event of:

-   Unexpected effects on governance

-   Excessive Layer 1 load due to on-chain voting or excessive numbers
    of governance actions

#### **Core Metrics**

All decisions on parameter changes should be informed by:

-   Governance participation levels

-   Governance behaviors and patterns

-   Regulatory considerations

-   Confidence in the governance system

-   The effectiveness of the governance system in managing necessary
    change

#### **Changes to Specific Governance Parameters**

#### **Deposit for Governance Actions (govDeposit)**

The deposit that is charged when submitting a governance action.

-   Helps to limit the number of actions that are submitted

##### **GUARDRAILS**

GD-01 (y) *govDeposit* must not be negative

GD-02 (y) *govDeposit* must not be lower than 1,000,000 (1 ada)

GD-03a (y) *govDeposit* must not exceed 10,000,000,000,000 (10 million
ada)

GD-04 (x - "should") *govDeposit* should be adjusted in line with fiat
changes

#### **Deposit for DReps (dRepDeposit)**

The deposit that is charged when registering a DRep.

-   Helps to limit the number of active DReps

##### **GUARDRAILS**

DRD-01 (y) *dRepDeposit* must not be negative

DRD-02 (y) *dRepDeposit* must not be lower than 1,000,000 (1 ada)

DRD-03 (y) *dRepDeposit* must not exceed 100,000,000,000 (100,000 ada)

DRD-04 (x - "should") *dRepDeposit* should be adjusted in line with
fiat changes

#### **DRep Activity Period (dRepActivity)**

The period (as a whole number of epochs) after which a DRep is
considered to be inactive for vote calculation purposes, if they do not
vote on any proposal.

##### **GUARDRAILS**

DRA-01 (y) *dRepActivity* must not be lower than 13 epochs (65 days)

DRA-02 (y) *dRepActivity* must not exceed 37 epochs (185 days)

DRA-03 (y) *dRepActivity* must not be negative

DRA-04 (~ - no access to existing parameter values) *dRepActivity* must
be greater than *govActionLifetime*

DRA-05 (x - "should") *dRepActivity* should be calculated in human
terms (60 days, etc.)

#### **DRep and SPO Governance Action Thresholds (dRepVotingThresholds[...],poolVotingThresholds[...])**

Thresholds on the active voting stake that is required to ratify a
specific type of governance action by either DReps or SPOs.

-   Ensures legitimacy of the action

The threshold parameters are listed below:

*dRepVotingThresholds*:

-   *dvtCommitteeNoConfidence*

-   *dvtCommitteeNormal*

-   *dvtHardForkInitiation*

-   *dvtMotionNoConfidence*

-   *dvtPPEconomicGroup*

-   *dvtPPGovGroup*

-   *dvtPPNetworkGroup*

-   *dvtPPTechnicalGroup*

-   *dvtTreasuryWithdrawal*

-   *dvtUpdateToConstitution*

*poolVotingThresholds*:

-   *pvtCommitteeNoConfidence*

-   *pvtCommitteeNormal*

-   *pvtHardForkInitiation*

-   *pvtMotionNoConfidence*

-   *pvtPPSecurityGroup*

##### **GUARDRAILS**

VT-GEN-01 (y) All thresholds must be greater than 50% and less than or
equal to 100%

VT-GEN-02a (y) Economic, network and technical/security parameter
thresholds must be in the range 51%-75%

VT-GEN-03 (y) Governance parameter thresholds must be in the range
75%-90%

VT-HF-01 (y) "Hard Fork Initiation" action thresholds must be in the
range 51%-80%

VT-CON-01 (y) "New Constitution" action thresholds must be in the range
65%-90%

VT-CC-01 (y) "Update Committee" action thresholds must be in the range
51%-90%

VT-NC-01 (y) "No Confidence" action thresholds must be in the range
51%-75%

#### **Governance Action Lifetime (govActionLifetime)**

The period after which a governance action will expire if it is not
enacted - as a whole number of epochs

##### **GUARDRAILS**

GAL-01 (y) *govActionLifetime* must not be lower than 1 epoch (5 days)

GAL-03 (x - "should") *govActionLifetime* should not be lower than 2
epochs (10 days)

GAL-02 (y) *govActionLifetime* must not exceed 15 epochs (75 days)

GAL-04 (x - "should") *govActionLifetime* should be calibrated in
human terms (e.g., 30 days, two weeks), to allow sufficient time for voting
etc. to take place

GAL-05 (~ - no access to existing parameter values) *govActionLifetime*
must be less than *dRepActivity*

#### **Maximum Constitutional Committee Term (committeeMaxTermLength)**

The limit on the maximum term length that a committee member may serve

##### **GUARDRAILS**

CMTL-01a (y) *committeeMaxTermLength* must not be zero

CMTL-02a (y) *committeeMaxTermLength* must not be negative

CMTL-03a (y) *committeeMaxTermLength* must not be lower than 18 epochs
(90 days, or approximately 3 months)

CMTL-04a (y) *committeeMaxTermLength* must not exceed 293 epochs
(approximately 4 years)

CMTL-05a (x - "should") *committeeMaxTermLength* should not exceed 220
epochs (approximately 3 years)

#### **The minimum size of the Constitutional Committee (committeeMinSize)**

The least number of members that can be included in a Constitutional
Committee following a governance action to change the Constitutional
Committee.

##### **GUARDRAILS**

CMS-01 (y) *committeeMinSize* must not be negative

CMS-02 (y) *committeeMinSize* must not be lower than 3

CMS-03 (y) *committeeMinSize* must not exceed 10
