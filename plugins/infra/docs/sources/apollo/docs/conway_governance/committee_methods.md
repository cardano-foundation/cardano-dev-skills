# Constitutional Committee Methods

This page documents constitutional committee certificate methods: `AuthorizeCommitteeHotKey`, `ResignCommitteeColdKey`. Implementation: [`apollo.go`](../../apollo.go), `github.com/blinklabs-io/gouroboros/ledger/common` (`AuthCommitteeHotCert`, `ResignCommitteeColdCert`). Certificate CBOR: [`governance_test.go`](../../governance_test.go).

The Constitutional Committee uses a **cold/hot key** separation for security. The cold key is the long-lived identity established when the committee member is approved by governance (via an `UpdateCommittee` action — see [proposal_methods.md](proposal_methods.md)). The hot key is short-lived and authorized to actively cast votes on the member's behalf, so the cold key can be kept offline.

## Method signatures

```go
func (a *Apollo) AuthorizeCommitteeHotKey(
    cold common.Credential,
    hot common.Credential,
) *Apollo

func (a *Apollo) ResignCommitteeColdKey(
    cold common.Credential,
    anchor *common.GovAnchor,
) *Apollo
```

Both methods append a certificate to the builder's certificate list and return the builder for chaining.

## Behavior details

- **`AuthorizeCommitteeHotKey`** emits an `AuthCommitteeHotCert` (kind 14) linking the cold credential to a freshly chosen hot credential. Calling it again with a new hot credential effectively rotates: the previous hot key is no longer authorized.
- **`ResignCommitteeColdKey`** emits a `ResignCommitteeColdCert` (kind 15). The optional `anchor` lets the resigning member point to an off-chain document explaining why they are stepping down. Pass `nil` to resign without metadata.
- Neither certificate carries a deposit.

## Inputs and constraints

- `cold.Credential` and `hot.Credential` must each be exactly 28 bytes.
- `CredType` is `0` for key-hash credentials, `1` for script-hash credentials. Script committee members must be witnessed by the script.
- The cold key must sign `AuthorizeCommitteeHotKey` and `ResignCommitteeColdKey` (or the corresponding script must be witnessed).

## Cardano CLI equivalence (10.14.0.0)

| CLI | Apollo |
|-----|--------|
| `conway governance committee hot-key-authorization-certificate` | `AuthorizeCommitteeHotKey(cold, hot)` |
| `conway governance committee cold-key-resignation-certificate` | `ResignCommitteeColdKey(cold, anchor)` |

## Examples

### Authorize a hot key

**Apollo:**

```go
import "github.com/blinklabs-io/gouroboros/ledger/common"

cold := common.Credential{
    CredType:   common.CredentialTypeAddrKeyHash,
    Credential: ccColdKeyHash,
}
hot := common.Credential{
    CredType:   common.CredentialTypeAddrKeyHash,
    Credential: ccHotKeyHash,
}

apollob = apollob.
    AuthorizeCommitteeHotKey(cold, hot).
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
cardano-cli conway governance committee create-hot-key-authorization-certificate \
  --cold-verification-key-file cc-cold.vkey \
  --hot-verification-key-file cc-hot.vkey \
  --out-file cc-hot-auth.cert
```

### Resign with an explanation anchor

**Apollo:**

```go
apollob = apollob.
    ResignCommitteeColdKey(cold, &common.GovAnchor{
        Url:      "https://example.com/resignation.json",
        DataHash: resignDocHash,
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

### Resign without an anchor

```go
apollob = apollob.
    ResignCommitteeColdKey(cold, nil).
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
cardano-cli conway governance committee create-cold-key-resignation-certificate \
  --cold-verification-key-file cc-cold.vkey \
  --out-file cc-resign.cert
```

## Evidence

- **Builder behavior verified by tests**:
  - `TestAuthorizeCommitteeHotKey` ([`governance_test.go`](../../governance_test.go)) — kind 14 emitted; both cold and hot credentials preserved.
  - `TestResignCommitteeColdKey`, `TestResignCommitteeColdKeyNoAnchor` ([`governance_test.go`](../../governance_test.go)) — kind 15 emitted; anchor optional.
- **CBOR serialization round-trips**:
  - `TestAuthCommitteeHotCertRoundTrip` ([`governance_test.go`](../../governance_test.go)).
  - `TestResignCommitteeColdCertAnchorsRoundTrip` — anchor present and absent.

## Caveats and validation

- The cold key must already correspond to a member of the active constitutional committee — Apollo does not check this, but the node will reject the certificate otherwise.
- A new hot-key authorization **revokes the previous one** for the same cold key. There is only ever one active hot key per committee member.
- Resignation is final from the chain's perspective — it cannot be undone by a subsequent certificate. Re-joining requires a new `UpdateCommittee` governance action.
- Validate on preview/preprod first.
