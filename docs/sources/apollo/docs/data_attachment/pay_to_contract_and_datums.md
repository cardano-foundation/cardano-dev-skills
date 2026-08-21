# Pay-to-Contract and Datums

This page documents the Apollo APIs for **paying to a contract address** and attaching **Plutus datums** (datum hash or inline): `PayToContract`, `PayToContractWithDatumHash`, `PayToContractAsHash`, `AddDatum`, and `AttachDatum`. Implementation: [`apollo.go`](../../apollo.go), [`convenience.go`](../../convenience.go), [`models.go`](../../models.go).

## Purpose and method signatures

### PayToContract

Creates a payment to a smart contract address with an **inline** Plutus datum.

```go
func (a *Apollo) PayToContract(
    addr common.Address,
    datum *common.Datum,
    lovelace int64,
    units ...Unit,
) *Apollo
```

| Parameter  | Description                                         |
| ---------- | --------------------------------------------------- |
| `addr`     | Recipient contract address                          |
| `datum`    | Plutus datum (inline); can be `nil` for no datum    |
| `lovelace` | Amount in lovelace                                  |
| `units`    | Optional native asset units                         |

### PayToContractWithDatumHash

Creates a contract payment using a **datum hash**. The datum is CBOR-encoded, hashed (Blake2b-256), and the hash is placed in the output. The full datum is added to the transaction witness set.

```go
func (a *Apollo) PayToContractWithDatumHash(
    addr common.Address,
    datum *common.Datum,
    lovelace int64,
    units ...Unit,
) (*Apollo, error)
```

### PayToContractAsHash

Creates a contract payment using a **pre-computed** datum hash. The datum is **not** added to the transaction witness set.

```go
func (a *Apollo) PayToContractAsHash(
    addr common.Address,
    datumHash []byte,
    lovelace int64,
    units ...Unit,
) *Apollo
```

### AddDatum

Appends a datum to the transaction's witness set. Called automatically by `PayToContractWithDatumHash` when `datum != nil`; use explicitly when multiple outputs share the same datum.

```go
func (a *Apollo) AddDatum(datum *common.Datum) *Apollo
```

### AttachDatum

Alias for `AddDatum`: appends a datum to the transaction's witness set (e.g. for redeemers or auxiliary outputs).

```go
func (a *Apollo) AttachDatum(datum *common.Datum) *Apollo
```

## Inputs and constraints

- Apollo works with `*common.Datum`. Its Plutus data value is provided by
  `github.com/blinklabs-io/plutigo/data`; gouroboros does not export a
  `common.PlutusData` type. For CLI-style file or JSON value input, read and
  decode it in your application, then pass the resulting datum to the builder.
- `PayToContractAsHash`: you supply the hash bytes; the ledger may need the full datum elsewhere (e.g. another output or previous tx) if the contract expects it.

## Behavior details

- **PayToContract**: Always creates an output with an **inline datum**. If `datum` is `nil`, no datum is attached.
- **PayToContractWithDatumHash**: Computes `Blake2b256Hash(cbor.Encode(datum))`, stores the hash in the output, and calls `AddDatum(datum)` to add it to the witness set.
- **PayToContractAsHash**: Stores the pre-computed hash in the output without adding any datum to the witness set.
- **Post-Alonzo output**: Outputs with inline datums or reference scripts are built as post-Alonzo format.

## Cardano CLI equivalence (10.14.0.0)

| CLI flag / behavior                                   | Apollo equivalent                                                                              |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `--tx-out-datum-hash HASH`                            | `PayToContractAsHash(addr, hashBytes, amount)` or `PayToContractWithDatumHash(addr, &datum, amount)` |
| `--tx-out-datum-hash-cbor-file` / `-file` / `-value`  | Read/parse to `common.Datum`, then `PayToContractWithDatumHash(addr, &datum, amount)`          |
| `--tx-out-datum-embed-`* / `--tx-out-inline-datum-`*  | Same loading, then `PayToContract(addr, &datum, amount)`                                       |
| Datum in witness set (multiple outputs)               | `AddDatum(&datum)` or `AttachDatum(&datum)`                                                    |

**Parity:** Full; file/JSON/CBOR handling is the application's responsibility.

## Examples

### Inline datum (default in v2)

**Apollo:**

```go
import "github.com/blinklabs-io/gouroboros/ledger/common"

contractAddr, err := common.NewAddress("addr1qy99jvml...")
if err != nil {
    panic(err)
}
datum := common.Datum{} // your Plutus data
apollob = apollob.
    SetChangeAddress(changeAddr).
    AddLoadedUTxOs(utxos...).
    PayToContract(contractAddr, &datum, 1_000_000)
tx, err := apollob.Complete()
```

**Cardano CLI:**

```bash
cardano-cli transaction build \
    --tx-out "$CONTRACT_ADDRESS+1000000" \
    --tx-out-inline-datum-value "$JSON_DATUM" \
    ...
```

### Datum hash (output stores hash, datum in witness set)

**Apollo:**

```go
apollob, err = apollob.PayToContractWithDatumHash(contractAddr, &datum, 1_000_000)
```

**Cardano CLI:**

```bash
cardano-cli transaction build \
    --tx-out "$CONTRACT_ADDRESS+1000000" \
    --tx-out-datum-hash "$DATUM_HASH" \
    ...
```

### Pre-computed datum hash (no datum in witness set)

**Apollo:**

```go
hashBytes := []byte{...} // 32-byte Blake2b-256 hash
apollob = apollob.PayToContractAsHash(contractAddr, hashBytes, 1_000_000)
```

### Attach datum to transaction (witness set only)

**Apollo:**

```go
apollob = apollob.AttachDatum(&datum) // or AddDatum(&datum)
```

`PayToContractWithDatumHash(addr, &datum, amount)` already calls `AddDatum` internally.

## Caveats and validation

- `PayToContractAsHash` does not add the datum to the witness set; ensure the datum is available elsewhere if the contract requires it.
- All types come from `github.com/blinklabs-io/gouroboros/ledger/common`.
