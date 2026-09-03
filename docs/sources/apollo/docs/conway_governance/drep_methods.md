# DRep Methods

This page documents the **DRep lifecycle** certificates: `RegisterDRep`, `RetireDRep`, `UpdateDRep`. Implementation: [`apollo.go`](../../apollo.go), `github.com/blinklabs-io/gouroboros/ledger/common` (`RegistrationDrepCertificate`, `DeregistrationDrepCertificate`, `UpdateDrepCertificate`). Certificate CBOR: [`governance_test.go`](../../governance_test.go).

A **DRep** (Delegated Representative) is an on-chain identity that other stakers can delegate their voting power to. DReps vote on governance actions on behalf of their delegators. The lifecycle is managed explicitly through three certificates: registration (kind 16), retirement (kind 17), and update (kind 18).

## Types

### `common.Credential`

```go
type Credential struct {
    CredType   uint          // 0 = key hash, 1 = script hash
    Credential Blake2b224    // 28-byte hash payload
}
```

Identifies the DRep by its key hash or script hash.

### `common.GovAnchor`

```go
type GovAnchor struct {
    Url      string
    DataHash [32]byte
}
```

Anchors point to off-chain metadata describing the DRep (name, contact, manifesto, etc.) and let voters verify the document hasn't changed. The anchor is optional on `RegisterDRep` and `UpdateDRep`, and on `ResignCommitteeColdKey` it is the only metadata channel.

## Method signatures

```go
func (a *Apollo) RegisterDRep(
    credential common.Credential,
    coin int64,
    anchor *common.GovAnchor,
) *Apollo

func (a *Apollo) RetireDRep(
    credential common.Credential,
    coin int64,
) *Apollo

func (a *Apollo) UpdateDRep(
    credential common.Credential,
    anchor *common.GovAnchor,
) *Apollo
```

All three methods append a certificate to the builder's certificate list and return the builder for chaining.

## Behavior details

- **Deposit handling**: `RegisterDRep` takes the DRep deposit defined by the current Conway protocol parameters (`drepDeposit`, typically 500 ADA). `Complete()` adds `RegistrationDrepCertificate.Amount` to the required input amount automatically. `RetireDRep` refunds `DeregistrationDrepCertificate.Amount` — pass the same amount that was originally deposited.
- **Anchor optionality**: Pass `nil` for `anchor` to register or update a DRep without metadata. CBOR encodes the absent anchor as `null`.
- **No replay protection in builder**: Apollo does not check whether a DRep is already registered or retired. The node will reject the transaction if the certificate is invalid in the current ledger state.

## Inputs and constraints

- `credential.Credential` must be exactly 28 bytes.
- `coin` for `RegisterDRep` must match the protocol-parameter `drepDeposit`. `coin` for `RetireDRep` must match the deposit originally paid at registration.
- `anchor.DataHash` must be 32 bytes (Blake2b-256).
- The transaction must include witnesses for the DRep credential (key witness for `CredType: 0`, script witness for `CredType: 1`).

## Cardano CLI equivalence (10.14.0.0)

| CLI | Apollo |
|-----|--------|
| `conway governance drep registration-certificate` | `RegisterDRep(cred, coin, anchor)` |
| `conway governance drep retirement-certificate` | `RetireDRep(cred, coin)` |
| `conway governance drep update-certificate` | `UpdateDRep(cred, anchor)` |

## Examples

### Register a DRep with metadata anchor

**Apollo:**

```go
import "github.com/blinklabs-io/gouroboros/ledger/common"

drepCred := common.Credential{
    CredType:   common.CredentialTypeAddrKeyHash,
    Credential: drepKeyHash,
}

apollob = apollob.
    RegisterDRep(drepCred, 500_000_000, &common.GovAnchor{
        Url:      "https://example.com/drep.json",
        DataHash: drepDocHash,
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

**Cardano CLI:**

```bash
cardano-cli conway governance drep registration-certificate \
  --drep-verification-key-file drep.vkey \
  --key-reg-deposit-amt 500000000 \
  --drep-metadata-url https://example.com/drep.json \
  --drep-metadata-hash <hex-hash> \
  --out-file drep-reg.cert

cardano-cli conway transaction build --certificate-file drep-reg.cert ...
```

### Register without metadata

```go
apollob = apollob.
    RegisterDRep(drepCred, 500_000_000, nil).
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

### Update a DRep's anchor

**Apollo:**

```go
apollob = apollob.
    UpdateDRep(drepCred, &common.GovAnchor{
        Url:      "https://example.com/drep-v2.json",
        DataHash: newDocHash,
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

To **remove** the anchor entirely, pass `nil`:

```go
apollob = apollob.
    UpdateDRep(drepCred, nil).
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

### Retire a DRep

**Apollo:**

```go
apollob = apollob.
    RetireDRep(drepCred, 500_000_000).  // Refund the original deposit
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
cardano-cli conway governance drep retirement-certificate \
  --drep-verification-key-file drep.vkey \
  --deposit-amt 500000000 \
  --out-file drep-retire.cert
```

## Evidence

- **Builder behavior verified by tests**:
  - `TestRegisterDRep`, `TestRegisterDRepNoAnchor` ([`governance_test.go`](../../governance_test.go)) — kind 16 emitted, credential preserved, anchor optional.
  - `TestRetireDRep` ([`governance_test.go`](../../governance_test.go)) — kind 17 emitted, credential preserved.
  - `TestUpdateDRep`, `TestUpdateDRepNoAnchor` ([`governance_test.go`](../../governance_test.go)) — kind 18 emitted, anchor optional.
- **CBOR serialization round-trips**:
  - `TestRegDRepCertAnchorsRoundTrip` ([`governance_test.go`](../../governance_test.go)) — anchor present and absent.
  - `TestUnregDRepCertRoundTrip` — retirement cert round-trip.
  - `TestUpdateDRepCertAnchorsRoundTrip` — update cert with and without anchor.
  - `TestDrepVariants` — DRep code variants (key hash, script hash, always-abstain, always-no-confidence).

## Caveats and validation

- **Deposit must equal the protocol parameter** at the time of registration. Submitting a `RegistrationDrepCertificate` with the wrong `Amount` will be rejected by the node.
- **Anchor URL is *not* dereferenced** by Apollo or the node. The node only verifies that the on-chain hash matches what was supplied — it never fetches the URL. Hosting and content integrity are your responsibility.
- The DRep credential must sign the transaction (or its script must be witnessed for script DReps).
- Validate on preview/preprod first — Conway parameters and deposit amounts vary across networks.
