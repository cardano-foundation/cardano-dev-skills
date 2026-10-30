# Dijkstra transactions

Apollo keeps Conway as the default target era. Select Dijkstra before adding
transaction operations:

```go
builder, err := apollo.New(chainContext).
    SetTargetEra(apollo.EraDijkstra).
    AddPayment(payment).
    Complete()
if err != nil {
    return err
}
tx := builder.GetDijkstraTx()
```

Dijkstra builds require protocol major version 12 or newer, read from the
provider's protocol parameters (Blockfrost `protocol_major_ver`, Ogmios
`version.major`, UTxO RPC `protocol_version.major`). `GetTx()` retains
its Conway type and returns nil for Dijkstra builds. Use `GetDijkstraTx()` for
the Dijkstra transaction and `GetTxCbor()` for its encoded three-component
envelope. `Sign`, fee estimation, evaluation requests, and `Submit` use the
selected transaction encoding.

The builder currently supports direct account deposits, current and starting
account balance intervals, Dijkstra proposal procedures, guards, and Plutus V4
scripts.

## Plutus V4

The Dijkstra ledger accepts Plutus V4 scripts only as reference scripts.
Publish a V4 script with `PayToAddressWithReferenceScript` and consume it with
`AddReferenceInput`; `AttachScript` rejects a V4 script with
`ErrPlutusV4WitnessScript` in a Dijkstra build and `ErrPlutusV4RequiresDijkstra`
in a Conway build. A V4 script can lock spent UTxOs (`CollectFrom`) and guard
the transaction (`AddGuard`). The script integrity hash uses the provider's
`PlutusV4` cost model (Ogmios `plutus:v4`, Blockfrost `PlutusV4`, UTxO RPC
`plutus_v4`).

## Withdrawals and governance

`AddWithdrawal` accepts any amount up to the account balance (CIP-159 partial
withdrawals) and does not require the account to delegate to a DRep (CIP-181).
`AddDijkstraProposal` takes a `dijkstra.DijkstraProposalProcedure`, whose
`DijkstraParameterChangeGovAction` can update parameters introduced by the
era, such as the CIP-50 `MaxPledgeLeverage`. Proposal deposits are included in
coin selection.

## Signing loaded transactions

`LoadTxCbor` decodes a Conway or Dijkstra transaction, rejecting malformed
input and trailing bytes. Signing a loaded transaction keeps its original body
bytes, so the witness signs the existing transaction hash, and `GetTxCbor`
returns the transaction with the new witness.

## Guards

Dijkstra replaces required signers (body field 14) with guards: credentials
that must authorise the transaction. `AddRequiredSigner` still works and adds
a key-hash guard. `AddGuard` adds a key-hash or script credential:

```go
builder = builder.
    AttachScript(guardScript).
    AddGuard(scriptCredential, &redeemer, nil) // nil ExUnits: evaluate
```

A key-hash guard takes no redeemer and adds a signature to the fee estimate.
A Plutus guard script takes a redeemer and runs under the guarding purpose
(redeemer tag 6); pass nil for a native-script guard. Supply the script with
`AttachScript` or a reference input. Guards are encoded after required
signers in the order they are added, without duplicates, and a guarding
redeemer's index is its credential's position in that list.

`AddRequiredTopLevelGuard` fills body field 24, which asserts that the
transaction's guards include a credential. The credential must also be added
with `AddGuard` or `AddRequiredSigner`; `Complete` reports an error otherwise.
A key-hash or native-script entry takes a nil datum and a Plutus entry
requires one.

Guarding redeemers need an evaluator that reports the guarding purpose.
Ogmios and Blockfrost parse it; UTxO RPC has no guarding purpose, so
`Complete` fails with a missing guarding-redeemer budget unless execution
units are supplied and estimation is disabled.

## Reference-script fees

Dijkstra makes the reference-script tier stride and multiplier protocol
parameters instead of Conway's fixed 25,600-byte stride and 1.2 multiplier.
A Dijkstra build that consumes reference scripts therefore requires the
provider to report both values (`MinFeeReferenceScriptsRange` and
`MinFeeReferenceScriptsMultiplierRational`); `Complete` returns an error
rather than pricing the transaction against Conway's constants. Ogmios reports
them through `minFeeReferenceScripts`; Blockfrost and UTxO RPC currently do
not, so Dijkstra builds that use reference scripts fail clearly on those
providers. When the provider reports `MaximumReferenceScriptsSize`, a
Dijkstra build that exceeds it is rejected before submission. Conway builds
keep the fixed Conway defaults.

## Not yet implemented

Nested transactions (CIP-118) are out of scope. Native-asset withdrawals and
whitelist-adjustment certificates are not implemented: gouroboros v0.213.7,
Apollo's canonical ledger dependency, has no wire types for either, and Apollo
does not define its own Dijkstra encodings.

See [transaction construction](../../apollo.go) and the
[Dijkstra transaction tests](../../dijkstra_tx_test.go) for the current API
and executable examples.
