# How to submit a Governance Action using GovTool

## Prerequisites

- Follow the steps of setting up the [GovTool Frontend](../govtool/frontend/README.md).
- Provide any backend that provides the Epoch params (for the wallet connection), can be the current [GovTool Backend](../govtool/govtool-backend/README.md).
- Have a wallet with the 50k of ADA to pay for the transaction and fee.

## Development guide

### Prerequisites

For creating the Governance Action, you need to consume 2 utility methods provided by `GovernanceActionProvided` (documented later within this document), and 3 exported from `CardanoProvider` wallet actions (2 for the 2 types of supported by GovTool Governance Actions and 1 for Signing and Submitting the transaction)

### Types

```typescript
import {
  VotingProposalBuilder,
  Costmdls,
  DrepVotingThresholds,
  ExUnitPrices,
  UnitInterval,
  ExUnits,
  PoolVotingThresholds,
} from "@emurgo/cardano-serialization-lib-nodejs";

interface GovernanceAction {
  title: string;
  abstract: string;
  motivation: string;
  rationale: string;
  references: [{ label: string; uri: string }];
}

type VotingAnchor = {
  url: string;
  hash: string;
}

type InfoProps = VotingAnchor;

type TreasuryProps {
  withdrawals: { receivingAddress: string; amount: string }[];
} & VotingAnchor;

type ProtocolParamsUpdate = {
  adaPerUtxo: string;
  collateralPercentage: number;
  committeeTermLimit: number;
  costModels: Costmdls;
  drepDeposit: string;
  drepInactivityPeriod: number;
  drepVotingThresholds: DrepVotingThresholds;
  executionCosts: ExUnitPrices;
  expansionRate: UnitInterval;
  governanceActionDeposit: string;
  governanceActionValidityPeriod: number;
  keyDeposit: string;
  maxBlockBodySize: number;
  maxBlockExUnits: ExUnits;
  maxBlockHeaderSize: number;
  maxCollateralInputs: number;
  maxEpoch: number;
  maxTxExUnits: ExUnits;
  maxTxSize: number;
  maxValueSize: number;
  minCommitteeSize: number;
  minPoolCost: string;
  minFeeA: string;
  minFeeB: string;
  nOpt: number;
  poolDeposit: string;
  poolPledgeInfluence: UnitInterval;
  poolVotingThresholds: PoolVotingThresholds;
  refScriptCoinsPerByte: UnitInterval;
  treasuryGrowthRate: UnitInterval;
};

type ProtocolParameterChangeProps {
  prevGovernanceActionHash: string;
  prevGovernanceActionIndex: number;
  protocolParamsUpdate: Partial<ProtocolParamsUpdate>;
} & VotingAnchor;

type HardForkInitiationProps = {
  prevGovernanceActionHash: string;
  prevGovernanceActionIndex: number;
  major: number;
  minor: number;
} & VotingAnchor;

type NewConstitutionProps = {
  prevGovernanceActionHash: string;
  prevGovernanceActionIndex: number;
  constitutionUrl: string;
  constitutionHash: string;
  scriptHash: string;
} & VotingAnchor;

type UpdateCommitteeProps = {
  prevGovernanceActionHash?: string;
  prevGovernanceActionIndex?: number;
  quorumThreshold: QuorumThreshold;
  newCommittee?: CommitteeToAdd[];
  removeCommittee?: string[];
} & VotingAnchor;

type CommitteeToAdd = {
  expiryEpoch: number;
  committee: string;
};

type QuorumThreshold = {
  numerator: number;
  denominator: number;
};

const createGovernanceActionJsonLD: (
  governanceAction: GovernanceAction
) => NodeObject;

const createHash: (jsonLd: NodeObject) => string;

const buildNewInfoGovernanceAction: (
  infoProps: InfoProps
) => Promise<VotingProposalBuilder | undefined>;

const buildTreasuryGovernanceAction: (
  treasuryProps: TreasuryProps
) => Promise<VotingProposalBuilder | undefined>;

const buildProtocolParameterChangeGovernanceAction: (
  protocolParameterChangeProps: ProtocolParameterChangeProps
) => Promise<VotingProposalBuilder | undefined>;

const buildHardForkGovernanceAction: (
  hardForkInitiationProps: HardForkInitiationProps
) => Promise<VotingProposalBuilder | undefined>;

const buildNewConstitutionGovernanceAction: (
  newConstitutionProps: NewConstitutionProps
) => Promise<VotingProposalBuilder | undefined>;

const buildUpdateCommitteeGovernanceAction: (
  updateCommitteeProps: UpdateCommitteeProps
) => Promise<VotingProposalBuilder | undefined>;

const buildSignSubmitConwayCertTx: (params: {
  govActionBuilder: VotingProposalBuilder;
  type: "createGovAction";
}) => Promise<void>;
```

### Step 1: Create the Governance Action metadata object

Create the Governance Action object with the fields specified by [CIP-108](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0108), which are:

- title
- abstract
- motivation
- rationale
- references

(For the detailed documentation of the fields and their types, please refer to the [CIP-108](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0108))

### Step 2: Create the Governance Action JSON-LD

Using the `GovernanceActionProvider` provider, use the `createGovernanceActionJsonLd` method to create the JSON-LD object for the Governance Action.

Example:

```typescript
// When used within a GovernanceActionProvider
const { createGovernanceActionJsonLD } = useCreateGovernanceAction();

const jsonLd = createGovernanceActionJsonLD(governanceAction);
```

Type of the `jsonLd` object is `NodeObject` provided from the `jsonld` package by digitalbazaar ([ref](https://github.com/digitalbazaar/jsonld.js)).

### Step 3: Create the Governance Action Hash of the JSON-LD

Using the `GovernanceActionProvider` provider, use the `createGovernanceActionHash` method to create the hash of the JSON-LD object.

Example:

```typescript
// When used within a GovernanceActionProvider
const { createHash } = useCreateGovernanceAction();

const hash = createHash(jsonLd);
```

Type of the `hash` object is `string` (blake2b-256).

### Step 4: Validate the Governance Action hash and metadata

Validate the Governance Action hash and metadata using any backend that provides the Governance Action validation of the metadata against the provided hash.

### Step 5: Sign and Submit the Governance Action

Using the `CardanoProvider` provider, use the `buildSignSubmitConwayCertTx` method to sign and submit the Governance Action, and either the `buildNewInfoGovernanceAction` or `buildTreasuryGovernanceAction` method to build the transaction based on the Governance action type.

Example:

```typescript
// When used within a CardanoProvider
const {
  buildSignSubmitConwayCertTx,
  buildNewInfoGovernanceAction,
  buildProtocolParameterChangeGovernanceAction,
  buildHardForkGovernanceAction,
  buildTreasuryGovernanceAction,
  buildNewConstitutionGovernanceAction,
  buildUpdateCommitteeGovernanceAction,
  buildNoConfidenceGovernanceAction,
} = useCardano();

// Info Governance Action
let govActionBuilder = await buildNewInfoGovernanceAction({ hash, url });

// And for the other type of governance actions:

govActionBuilder = await buildNoConfidenceGovernanceAction({ hash, url });

// hash of the generated Governance Action metadata, url of the metadata, amount of the transaction, receiving address is the stake key address
govActionBuilder = await buildTreasuryGovernanceAction({
  hash,
  url,
  withdrawals: [{ amount, receivingAddress }],
});

// hash of the previous Governance Action, index of the previous Governance Action, url of the metadata, hash of the metadata, and the updated protocol parameters
govActionBuilder = await buildProtocolParameterChangeGovernanceAction({
  prevGovernanceActionHash,
  prevGovernanceActionIndex,
  url,
  hash,
  protocolParamsUpdate,
});

// hash of the previous Governance Action, index of the previous Governance Action, url of the metadata, hash of the metadata, and the major and minor numbers of the hard fork initiation
govActionBuilder = await buildHardForkGovernanceAction({
  prevGovernanceActionHash,
  prevGovernanceActionIndex,
  url,
  hash,
  major,
  minor,
});

// hash of the previous Governance Action, index of the previous Governance Action, url of the metadata, hash of the metadata, and the constitution script hash
govActionBuilder = await buildNewConstitutionGovernanceAction({
  prevGovernanceActionHash,
  prevGovernanceActionIndex,
  constitutionUrl,
  constitutionHash,
  scriptHash,
});

// hash of the previous Governance Action, index of the previous Governance Action, url of the metadata, hash of the metadata, and the quorum threshold and the new committee members
govActionBuilder = await buildUpdateCommitteeGovernanceAction({
  prevGovernanceActionHash,
  prevGovernanceActionIndex,
  quorumThreshold,
  newCommittee,
  removeCommittee,
});

// sign and submit the transaction
await buildSignSubmitConwayCertTx({
  govActionBuilder,
  type: "createGovAction",
});
```

### Step 6: Verify the Governance Action

`buildSignSubmitConwayCertTx` logs the transaction CBOR making it able to be tracked on the transactions tools such as cexplorer.

## Additional steps for using the GovTool metadata validation on the imported Pillar component

```tsx
enum MetadataValidationStatus {
  URL_NOT_FOUND = "URL_NOT_FOUND",
  INVALID_JSONLD = "INVALID_JSONLD",
  INVALID_HASH = "INVALID_HASH",
  INCORRECT_FORMAT = "INCORRECT_FORMAT",
  EXCEEDS_LIMIT = "EXCEEDS_LIMIT",
  URL_BLOCKED = "URL_BLOCKED",
  INTERNAL_ERROR = "INTERNAL_ERROR",
}
// Using the props passed to the component
type Props = {
  validateMetadata: ({
    url,
    hash,
    standard,
  }: {
    url: string;
    hash: string;
    standard: "CIP108";
  }) => Promise<{
    metadata?: any;
    status?: MetadataValidationStatus;
    valid: boolean;
    // Fields at fault: errors with INCORRECT_FORMAT, or warnings alone on a
    // valid document (e.g. a CIP-108 title over 80 characters).
    issues?: {
      field: string;
      rule: "required" | "maxLength";
      severity: "error" | "warning";
      limit?: number;
      actual?: number;
    }[];
  }>;
};

import React, { Suspense } from "react";

const SomeImportedPillar: React.FC<Props> = React.lazy(
  () => import("path/to/SomeImportedPillar")
);

const SomeWrapperComponent = () => {
  const { validateMetadata } = useValidateMutation();

  return (
    <Suspense fallback={<div>I am lazy loading...</div>}>
      <SomeImportedPillar validateMetadata={validateMetadata} />
    </Suspense>
  );
};
```
