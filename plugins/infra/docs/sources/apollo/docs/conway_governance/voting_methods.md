# Voting Methods

This page documents how to **cast votes** on governance actions: `AddVote`. Implementation: [`apollo.go`](../../apollo.go) (`AddVote`), `github.com/blinklabs-io/gouroboros/ledger/common` and `github.com/blinklabs-io/gouroboros/ledger/conway` (`Voter`, `GovActionId`, `VotingProcedure`, `VotingProcedures`).

A vote is a tuple of **(voter, action ID, procedure)**. A single transaction can carry many votes from many voters on many actions; Apollo groups votes by voter and deduplicates per (voter, action) pair automatically.

## Types

### `common.Voter`

```go
const (
    VoterTypeConstitutionalCommitteeHotKeyHash    uint8 = 0
    VoterTypeConstitutionalCommitteeHotScriptHash uint8 = 1
    VoterTypeDRepKeyHash                          uint8 = 2
    VoterTypeDRepScriptHash                       uint8 = 3
    VoterTypeStakingPoolKeyHash                   uint8 = 4
)

type Voter struct {
    Type uint8
    Hash [28]byte
}
```

The role identifies *who* is voting; the hash is the credential. Constitutional committee members vote with their authorized **hot** credential (see [committee_methods.md](committee_methods.md)).

### `common.GovActionId`

```go
type GovActionId struct {
    TransactionId [32]byte
    GovActionIdx  uint32
}
```

A governance action is identified by the transaction that proposed it plus the index of the proposal within that transaction's proposals array.

### `common.VotingProcedure`

```go
const (
    GovVoteNo      uint8 = 0
    GovVoteYes     uint8 = 1
    GovVoteAbstain uint8 = 2
)

type VotingProcedure struct {
    Vote   uint8
    Anchor *common.GovAnchor  // optional rationale document
}
```

The optional anchor lets a voter publish a written rationale for their vote. Pass `nil` to vote without a rationale.

## Method signature

```go
func (a *Apollo) AddVote(
    voter common.Voter,
    actionId common.GovActionId,
    procedure common.VotingProcedure,
) *Apollo
```

Append-only; chainable. Internally calls `VotingProcedures.Add()` which:

- **Groups by voter**: votes from the same `Voter` (same role + same hash) are collected under one map entry.
- **Deduplicates per action**: calling `AddVote` again with the same voter and the same action **replaces** the previous procedure rather than adding a duplicate. This makes the call idempotent and lets you change your mind before sending the transaction.

## Behavior details

- The CBOR field on `TransactionBody` is map 19 (`{voter => {action_id => procedure}}`); see CIP-1694.
- Voting carries no deposit — only the standard transaction fee.
- The voter's credential must witness the transaction (key witness for `*KeyHash` roles, script witness for `*Script` roles, pool key for `StakePoolOperator`).

## Inputs and constraints

- `voter.Hash` must be exactly 28 bytes.
- `actionId.TransactionId` must be exactly 32 bytes.
- `procedure.Anchor.DataHash` (when present) must be 32 bytes.

## Cardano CLI equivalence (10.14.0.0)

| CLI | Apollo |
|-----|--------|
| `conway governance vote create` | `AddVote(voter, actionId, procedure)` |

Note: cardano-cli emits a single vote file; Apollo equivalently allows multiple `AddVote` calls before `Complete()` to bundle many votes into one transaction.

## Examples

### Single DRep vote

**Apollo:**

```go
import "github.com/blinklabs-io/gouroboros/ledger/common"

voter := common.Voter{
    Type: common.VoterTypeDRepKeyHash,
    Hash: drepKeyHash,
}

actionId := common.GovActionId{
    TransactionId: proposalTxHash,
    GovActionIdx:  0,
}

procedure := common.VotingProcedure{
    Vote:   common.GovVoteYes,
    Anchor: nil,
}

apollob = apollob.
    AddVote(voter, actionId, procedure).
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
cardano-cli conway governance vote create \
  --yes \
  --drep-verification-key-file drep.vkey \
  --governance-action-tx-id <hex> \
  --governance-action-index 0 \
  --out-file vote.cert

cardano-cli conway transaction build --vote-file vote.cert ...
```

### Voting Yes/No/Abstain on multiple actions in one transaction

The same voter can vote on several different actions:

```go
apollob = apollob.
    AddVote(voter, action1, common.VotingProcedure{Vote: common.GovVoteYes}).
    AddVote(voter, action2, common.VotingProcedure{Vote: common.GovVoteNo}).
    AddVote(voter, action3, common.VotingProcedure{Vote: common.GovVoteAbstain}).
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

All three votes are stored under the single voter entry in the transaction's voting procedures map.

### Vote with a rationale anchor

```go
import "github.com/blinklabs-io/gouroboros/ledger/common"

procedure := common.VotingProcedure{
    Vote: common.GovVoteNo,
    Anchor: &common.GovAnchor{
        Url:      "https://example.com/vote-rationale.json",
        DataHash: rationaleDocHash,
    },
}

apollob = apollob.
    AddVote(voter, actionId, procedure).
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

### Constitutional committee member voting with hot key

```go
voter := common.Voter{
    Type: common.VoterTypeConstitutionalCommitteeHotKeyHash,
    Hash: ccHotKeyHash,
}

apollob = apollob.
    AddVote(voter, actionId, common.VotingProcedure{
        Vote: common.GovVoteYes,
    }).
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

Use the **hot** key hash here — the cold key authorized this hot key via `AuthorizeCommitteeHotKey`.

### Stake pool operator voting

SPOs vote on no-confidence, hard fork, and a few other action types. The hash is the pool's cold key hash:

```go
voter := common.Voter{
    Type: common.VoterTypeStakingPoolKeyHash,
    Hash: poolColdKeyHash,
}

apollob = apollob.
    AddVote(voter, actionId, common.VotingProcedure{
        Vote: common.GovVoteYes,
    }).
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

### Changing your vote before sending

`AddVote` deduplicates per (voter, action). The last call wins for any given pair:

```go
apollob = apollob.
    AddVote(voter, actionId, common.VotingProcedure{Vote: common.GovVoteYes}).
    AddVote(voter, actionId, common.VotingProcedure{Vote: common.GovVoteNo})
// The transaction sends only one vote: VoteNo.
```

## Evidence

- **Builder behavior verified by tests**:
  - `TestAddVote` ([`governance_test.go`](../../governance_test.go)) — single vote with empty hashes; voting procedures map populated, vote value preserved.
  - `TestAddMultipleVotes` ([`governance_test.go`](../../governance_test.go)) — same voter on two different actions grouped under one voter entry.
  - `TestVotingAndProposalFieldsNilByDefault` ([`governance_test.go`](../../governance_test.go)) — voting procedures are `nil` until `AddVote` is called.
- **Voting procedure data structures verified by tests**:
  - `TestVoterRoundTrip`, `TestGovActionIdRoundTrip`, `TestVotingProcedureRoundTrip`, `TestVotingProceduresRoundTrip` ([`governance_test.go`](../../governance_test.go)).
  - `TestVotingProceduresAdd` — append a new voter and a second vote for an existing voter.
  - `TestVotingProceduresAddReplacesDuplicateAction` — confirms (voter, action) deduplication.
  - `TestVotingProceduresMarshalCBORCanonicalOrder` — outer and inner map keys emitted in canonical CBOR order, required for deterministic transaction hashing.
  - `TestVotingProcedures_Empty` — empty voting procedures encodes/decodes correctly.

## Caveats and validation

- **Witness requirement**: every distinct `Voter` adds a witness requirement to the transaction. Forgetting to sign with the matching key (or include the matching script witness) will cause the node to reject the transaction.
- **Role/hash type must match**: a `DRepKeyHash` voter with a script-hash payload, or a `ConstitutionalCommitteeScript` with a key-hash payload, will be rejected on submission.
- **Per-action role restrictions** apply at the ledger level (e.g. SPOs cannot vote on parameter changes affecting only DReps). Apollo does not check these — see CIP-1694 for the role/action matrix.
- **Action must exist** at submission time. If the referenced governance action has already been ratified, expired, or never existed, the node will reject the vote.
- **Canonical CBOR ordering** of the outer voter map and inner action map is enforced by Apollo's marshaler — required so two parties building the same vote bundle produce the same transaction hash.
- Validate on preview/preprod first.
