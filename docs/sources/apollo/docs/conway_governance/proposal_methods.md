# Proposal Methods

This page documents how to **submit governance action proposals**: `AddProposal`, plus the seven `GovAction` types. Implementation: [`apollo.go`](../../apollo.go) (`AddProposal`), `github.com/blinklabs-io/gouroboros/ledger/common` and `github.com/blinklabs-io/gouroboros/ledger/conway` (`ProposalProcedure`, `GovAction`, all action types).

A **proposal** bundles a deposit, a return address for the deposit refund, the action being proposed, and an anchor pointing to the rationale. A single transaction can carry multiple proposals; each one independently locks its deposit until the action is ratified, expired, or dropped (at which point the deposit is returned to the reward account).

## Method signature

```go
func (a *Apollo) AddProposal(
    proposal conway.ConwayProposalProcedure,
) *Apollo
```

Append-only; chainable. The proposal is appended to `TransactionBody` field 20 (`ProposalProcedures`). `Complete()` adds each `proposal.PPDeposit` to the required input balance.

## ProposalProcedure

```go
type ConwayProposalProcedure struct {
    PPDeposit       uint64
    PPRewardAccount common.Address
    PPGovAction     conway.ConwayGovAction
    PPAnchor        common.GovAnchor
}
```

`PPRewardAccount` is the reward account that receives the deposit refund when the action concludes, regardless of outcome.

## The seven GovAction types

All seven implement the `common.GovAction` interface and are wrapped in `conway.ConwayGovAction`. They map 1:1 to `cardano-cli conway governance action create-*` commands.

| Type | Kind | Purpose |
|---|---|---|
| `common.InfoGovAction` | 6 | Non-binding informational proposal — captures community sentiment with no on-chain effect |
| `common.NoConfidenceGovAction` | 3 | Replace the current constitutional committee with a "no confidence" state |
| `common.HardForkInitiationGovAction` | 1 | Move the network to a new major protocol version |
| `conway.ConwayParameterChangeGovAction` | 0 | Update one or more protocol parameters |
| `common.TreasuryWithdrawalGovAction` | 2 | Withdraw funds from the treasury to one or more reward accounts |
| `common.UpdateCommitteeGovAction` | 4 | Add and/or remove constitutional committee members and adjust quorum |
| `common.NewConstitutionGovAction` | 5 | Replace the on-chain constitution (anchor + optional guardrails script hash) |

Most actions take an optional `ActionId *common.GovActionId` linking to the most recent ratified action of the same type (or `nil` if none). `common.TreasuryWithdrawalGovAction` does not have an action ID; it has an optional `PolicyHash []byte` field. Action IDs form a linear "lineage" enforced by the ledger to prevent stale proposals from overwriting newer ones.

### `InfoGovAction`

```go
type InfoGovAction struct {
    Type uint
}
```

No fields. Use it to put a question or position to the governance bodies for a non-binding vote.

### `NoConfidenceGovAction`

```go
type NoConfidenceGovAction struct {
    Type     uint
    ActionId *common.GovActionId
}
```

### `HardForkInitiationGovAction`

```go
type HardForkInitiationGovAction struct {
    Type     uint
    ActionId *common.GovActionId
    ProtocolVersion struct {
        cbor.StructAsArray
        Major uint
        Minor uint
    }
}
```

### `ConwayParameterChangeGovAction`

```go
type ConwayParameterChangeGovAction struct {
    Type        uint
    ActionId    *common.GovActionId
    ParamUpdate conway.ConwayProtocolParameterUpdate
    PolicyHash  []byte
}
```

`ParamUpdate` is a `conway.ConwayProtocolParameterUpdate` struct with pointer fields such as `MinFeeA *uint`, `MinFeeB *uint`, `GovActionDeposit *uint64`, and `MinFeeRefScriptCostPerByte *cbor.Rat`. Set only the fields that should change.

### `TreasuryWithdrawalGovAction`

```go
type TreasuryWithdrawalGovAction struct {
    Type        uint
    Withdrawals map[*common.Address]uint64
    PolicyHash  []byte
}
```

### `UpdateCommitteeGovAction`

```go
type UpdateCommitteeGovAction struct {
    Type        uint
    ActionId    *common.GovActionId
    Credentials []common.Credential
    CredEpochs  map[*common.Credential]uint
    Quorum      cbor.Rat
}
```

`Credentials` contains removed members. `CredEpochs` maps added members to their expiry epochs.

### `NewConstitutionGovAction`

```go
type NewConstitutionGovAction struct {
    Type     uint
    ActionId *common.GovActionId
    Constitution struct {
        cbor.StructAsArray
        Anchor     common.GovAnchor
        ScriptHash []byte
    }
}
```

## Inputs and constraints

- `PPDeposit` must equal the protocol-parameter `govActionDeposit` (typically 100,000 ADA on mainnet).
- `PPRewardAccount` must correspond to a registered stake key — refunds are credited there.
- `PPAnchor.DataHash` must be 32 bytes.
- For action types with an `ActionId`: pass `nil` for the first action of that type, or the `GovActionId` of the most recently ratified action of the same type otherwise.

## Cardano CLI equivalence (10.14.0.0)

| CLI | Apollo |
|-----|--------|
| `conway governance action create-info` | `AddProposal(...)` with `common.InfoGovAction{}` |
| `conway governance action create-no-confidence` | `AddProposal(...)` with `common.NoConfidenceGovAction{...}` |
| `conway governance action create-hardfork` | `AddProposal(...)` with `common.HardForkInitiationGovAction{...}` |
| `conway governance action create-protocol-parameters-update` | `AddProposal(...)` with `conway.ConwayParameterChangeGovAction{...}` |
| `conway governance action create-treasury-withdrawal` | `AddProposal(...)` with `common.TreasuryWithdrawalGovAction{...}` |
| `conway governance action update-committee` | `AddProposal(...)` with `common.UpdateCommitteeGovAction{...}` |
| `conway governance action create-constitution` | `AddProposal(...)` with `common.NewConstitutionGovAction{...}` |

## Examples

### Info proposal

**Apollo:**

```go
import (
    "github.com/blinklabs-io/gouroboros/ledger/common"
    "github.com/blinklabs-io/gouroboros/ledger/conway"
)

proposal := conway.ConwayProposalProcedure{
    PPDeposit:       100_000_000_000,
    PPRewardAccount: rewardAccount,
    PPGovAction: conway.ConwayGovAction{
        Type:   uint(common.GovActionTypeInfo),
        Action: &common.InfoGovAction{Type: uint(common.GovActionTypeInfo)},
    },
    PPAnchor: common.GovAnchor{
        Url:      "https://example.com/info.json",
        DataHash: docHash,
    },
}

apollob = apollob.
    AddProposal(proposal).
    AddLoadedUTxOs(utxos...)
apollob, err = apollob.AddInputAddressFromBech32(myAddr)
if err != nil {
    panic(err)
}
apollob, err = apollob.PayToAddressBech32(myAddr, 10_000_000)
if err != nil {
    panic(err)
}
apollob, err = apollob.Complete()
```

**Cardano CLI:**

```bash
cardano-cli conway governance action create-info \
  --mainnet \
  --governance-action-deposit 100000000000 \
  --deposit-return-stake-verification-key-file stake.vkey \
  --anchor-url https://example.com/info.json \
  --anchor-data-hash <hex-hash> \
  --out-file info.action

cardano-cli conway transaction build --proposal-file info.action ...
```

### Hard fork initiation

```go
proposal := conway.ConwayProposalProcedure{
    PPDeposit:       100_000_000_000,
    PPRewardAccount: rewardAccount,
    PPGovAction: conway.ConwayGovAction{
        Type: uint(common.GovActionTypeHardForkInitiation),
        Action: &common.HardForkInitiationGovAction{
            Type:     uint(common.GovActionTypeHardForkInitiation),
            ActionId: prevHardForkId,  // or nil for the first one
            ProtocolVersion: struct {
                cbor.StructAsArray
                Major uint
                Minor uint
            }{
                Major: 11,
                Minor: 0,
            },
        },
    },
    PPAnchor: common.GovAnchor{
        Url:      "https://example.com/hardfork.json",
        DataHash: docHash,
    },
}

apollob, err = apollob.AddProposal(proposal). /* ... */ Complete()
```

### Protocol parameter change

```go
minFeeA := uint(50)
minFeeB := uint(180_000)

proposal := conway.ConwayProposalProcedure{
    PPDeposit:       100_000_000_000,
    PPRewardAccount: rewardAccount,
    PPGovAction: conway.ConwayGovAction{
        Type: uint(common.GovActionTypeParameterChange),
        Action: &conway.ConwayParameterChangeGovAction{
            Type:     uint(common.GovActionTypeParameterChange),
            ActionId: nil,
            ParamUpdate: conway.ConwayProtocolParameterUpdate{
                MinFeeA: &minFeeA,
                MinFeeB: &minFeeB,
            },
        },
    },
    PPAnchor: common.GovAnchor{
        Url:      "https://example.com/pparams.json",
        DataHash: docHash,
    },
}

apollob, err = apollob.AddProposal(proposal). /* ... */ Complete()
```

### Treasury withdrawal

```go
recipient1 := recipient1Address
recipient2 := recipient2Address

proposal := conway.ConwayProposalProcedure{
    PPDeposit:       100_000_000_000,
    PPRewardAccount: rewardAccount,
    PPGovAction: conway.ConwayGovAction{
        Type: uint(common.GovActionTypeTreasuryWithdrawal),
        Action: &common.TreasuryWithdrawalGovAction{
            Type: uint(common.GovActionTypeTreasuryWithdrawal),
            Withdrawals: map[*common.Address]uint64{
                &recipient1: 50_000_000_000,
                &recipient2: 25_000_000_000,
            },
            PolicyHash: nil,
        },
    },
    PPAnchor: common.GovAnchor{
        Url:      "https://example.com/treasury-wd.json",
        DataHash: docHash,
    },
}

apollob, err = apollob.AddProposal(proposal). /* ... */ Complete()
```

### Update committee

```go
oldMember := common.Credential{
    CredType:   common.CredentialTypeAddrKeyHash,
    Credential: existingMemberHash,
}
newMember := common.Credential{
    CredType:   common.CredentialTypeAddrKeyHash,
    Credential: ccColdKeyHash,
}
quorum := cbor.Rat{Rat: big.NewRat(2, 3)}

proposal := conway.ConwayProposalProcedure{
    PPDeposit:       100_000_000_000,
    PPRewardAccount: rewardAccount,
    PPGovAction: conway.ConwayGovAction{
        Type: uint(common.GovActionTypeUpdateCommittee),
        Action: &common.UpdateCommitteeGovAction{
            Type:        uint(common.GovActionTypeUpdateCommittee),
            ActionId:    prevCommitteeUpdateId,  // or nil for the first one
            Credentials: []common.Credential{oldMember},
            CredEpochs: map[*common.Credential]uint{
                &newMember: 600,
            },
            Quorum: quorum,
        },
    },
    PPAnchor: common.GovAnchor{
        Url:      "https://example.com/committee.json",
        DataHash: docHash,
    },
}

apollob, err = apollob.AddProposal(proposal). /* ... */ Complete()
```

### New constitution

```go
proposal := conway.ConwayProposalProcedure{
    PPDeposit:       100_000_000_000,
    PPRewardAccount: rewardAccount,
    PPGovAction: conway.ConwayGovAction{
        Type: uint(common.GovActionTypeNewConstitution),
        Action: &common.NewConstitutionGovAction{
            Type:     uint(common.GovActionTypeNewConstitution),
            ActionId: prevConstitutionId,  // or nil for the first one
            Constitution: struct {
                cbor.StructAsArray
                Anchor     common.GovAnchor
                ScriptHash []byte
            }{
                Anchor: common.GovAnchor{
                    Url:      "https://example.com/constitution.txt",
                    DataHash: constitutionHash,
                },
                ScriptHash: guardrailsScriptHash,  // nil for no guardrails
            },
        },
    },
    PPAnchor: common.GovAnchor{
        Url:      "https://example.com/proposal.json",
        DataHash: proposalDocHash,
    },
}

apollob, err = apollob.AddProposal(proposal). /* ... */ Complete()
```

### No confidence

```go
proposal := conway.ConwayProposalProcedure{
    PPDeposit:       100_000_000_000,
    PPRewardAccount: rewardAccount,
    PPGovAction: conway.ConwayGovAction{
        Type: uint(common.GovActionTypeNoConfidence),
        Action: &common.NoConfidenceGovAction{
            Type:     uint(common.GovActionTypeNoConfidence),
            ActionId: prevNoConfidenceId,  // or nil for the first one
        },
    },
    PPAnchor: common.GovAnchor{
        Url:      "https://example.com/no-confidence.json",
        DataHash: docHash,
    },
}

apollob, err = apollob.AddProposal(proposal). /* ... */ Complete()
```

### Multiple proposals in one transaction

```go
apollob = apollob.
    AddProposal(infoProposal).
    AddProposal(parameterChangeProposal).
    AddLoadedUTxOs(utxos...)
apollob, err = apollob.AddInputAddressFromBech32(myAddr)
if err != nil {
    panic(err)
}
apollob, err = apollob.PayToAddressBech32(myAddr, 10_000_000)
if err != nil {
    panic(err)
}
apollob, err = apollob.Complete()
```

`Complete()` adds the **sum** of both deposits to the required input balance.

## Evidence

- **Builder behavior verified by tests**:
  - `TestAddProposal` ([`governance_test.go`](../../governance_test.go)) — single info proposal; `ProposalProcedures` populated, deposit preserved.
  - `TestAddMultipleProposals` — two proposals in one transaction; both deposits preserved in order.
  - `TestVotingAndProposalFieldsNilByDefault` — `ProposalProcedures` is `nil` until `AddProposal` is called.

## Caveats and validation

- **`PPDeposit` must match `govActionDeposit`** at submission time. Apollo does not query the protocol parameters — pass the value applicable to your target network.
- **Anchor URL is *not* dereferenced** by Apollo or the node — only the on-chain hash is verified.
- `PPRewardAccount` must be a registered stake address; the refund will be credited there even years later when the action concludes.
- For `ConwayParameterChangeGovAction`, set only valid fields in `ConwayProtocolParameterUpdate` for the current era. The node rejects invalid updates.
- For `UpdateCommitteeGovAction` and `TreasuryWithdrawalGovAction`, the totals (added/removed members, withdrawn coin) must satisfy ledger constraints — e.g. cannot withdraw more than the current treasury value, cannot reduce committee below threshold.
- **`ActionId` discipline**: most action types require linking to the most recently ratified action of the same kind. An out-of-date `ActionId` causes the node to reject the proposal. Query the chain for the current head before constructing a proposal.
- Validate on preview/preprod first — these networks have lower deposits and faster epochs to make iteration practical.
