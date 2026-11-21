# Status

📜 Proposed 2026-02-23

# Context

The experimental API's transaction construction relied on the legacy `TxBodyContent build era` type from the old API. This type was designed with an elaborate system of eon-indexed wrapper types and phantom type parameters that, while principled, created significant accidental complexity. The main issues were:

- Every field was wrapped in a cardano-api-specific type (e.g., `TxFee era`, `TxValidityLowerBound era`, `TxMetadataInEra era`) that carried era proofs but added a translation layer between the user and the ledger.
- The `build` phantom type parameter (`BuildTx` / `ViewTx`) threaded through the entire type, adding boilerplate for a distinction that is unnecessary because we deserialize transactions to the underlying ledger Tx type.
- Conway-specific governance fields used `Maybe (Featured ConwayEraOnwards era ...)` wrappers, adding further nesting.
- Fields used "presence" constructors (e.g., `TxInsCollateralNone | TxInsCollateral AlonzoEraOnwards era [TxIn]`) instead of idiomatic Haskell `Maybe` / `[]`.
- The type was parameterized by a cardano-api era, not the ledger era, requiring conversion at transaction build time.

The experimental API (ADR-010) introduced a new witness hierarchy (`AnyWitness`, `PlutusScriptWitness`, `Witnessable`) that works directly with ledger types. However, the transaction body was still the legacy type, meaning much of the simplification was lost at the point of transaction construction.

The objectives for a new `TxBodyContent` are:

- Use ledger types directly where possible, reducing the maintenance burden and conversion overhead.
- Eliminate the `build` phantom type parameter.
- Replace eon-indexed wrapper types with `Maybe`, `[]`, and bare ledger types.
- Index the type by the ledger era, not the cardano-api era, for direct compatibility with ledger functions.
- Provide setter functions for pipeline-style construction without a lens dependency.
- Integrate with the witness API from ADR-010 using `AnyWitness` directly in the type.

# Decision

## New `TxBodyContent` type

We replace the legacy `TxBodyContent build era` (parameterized by a `build` phantom and a cardano-api era) with a new type parameterized by a single ledger era:

```haskell
data TxBodyContent era
  = TxBodyContent
  { txIns :: [(TxIn, AnyWitness era)]
  , txInsCollateral :: [TxIn]
  , txInsReference :: TxInsReference era
  , txOuts :: [TxOut era]
  , txTotalCollateral :: Maybe TxTotalCollateral
  , txReturnCollateral :: Maybe (TxReturnCollateral era)
  , txFee :: L.Coin
  , txValidityLowerBound :: Maybe L.SlotNo
  , txValidityUpperBound :: Maybe L.SlotNo
  , txMetadata :: TxMetadata
  , txAuxScripts :: [SimpleScript era]
  , txExtraKeyWits :: TxExtraKeyWitnesses
  , txProtocolParams :: Maybe (L.PParams era)
  , txWithdrawals :: TxWithdrawals era
  , txCertificates :: TxCertificates era
  , txMintValue :: TxMintValue era
  , txScriptValidity :: ScriptValidity
  , txProposalProcedures :: Maybe (TxProposalProcedures era)
  , txVotingProcedures :: Maybe (TxVotingProcedures era)
  , txCurrentTreasuryValue :: Maybe L.Coin
  , txTreasuryDonation :: Maybe L.Coin
  , txSupplementalDatums :: Map L.DataHash (L.Data era)
  }
```

For comparison, the old type:

```haskell
data TxBodyContent build era
  = TxBodyContent
  { txIns :: TxIns build era
  , txInsCollateral :: TxInsCollateral era
  , txInsReference :: TxInsReference build era
  , txOuts :: [TxOut CtxTx era]
  , txTotalCollateral :: TxTotalCollateral era
  , txReturnCollateral :: TxReturnCollateral CtxTx era
  , txFee :: TxFee era
  , txValidityLowerBound :: TxValidityLowerBound era
  , txValidityUpperBound :: TxValidityUpperBound era
  , txMetadata :: TxMetadataInEra era
  , txAuxScripts :: TxAuxScripts era
  , txExtraKeyWits :: TxExtraKeyWitnesses era
  , txProtocolParams :: BuildTxWith build (Maybe (LedgerProtocolParameters era))
  , txWithdrawals :: TxWithdrawals build era
  , txCertificates :: TxCertificates build era
  , txUpdateProposal :: TxUpdateProposal era
  , txMintValue :: TxMintValue build era
  , txScriptValidity :: TxScriptValidity era
  , txProposalProcedures :: Maybe (Featured ConwayEraOnwards era (TxProposalProcedures build era))
  , txVotingProcedures :: Maybe (Featured ConwayEraOnwards era (TxVotingProcedures build era))
  , txCurrentTreasuryValue :: Maybe (Featured ConwayEraOnwards era (Maybe L.Coin))
  , txTreasuryDonation :: Maybe (Featured ConwayEraOnwards era L.Coin)
  }
```

The key design differences are summarized below.

### Elimination of the `build` type parameter

The `build` / `BuildTxWith` phantom type pattern is removed. Witnesses are now embedded directly in the data: `txIns :: [(TxIn, AnyWitness era)]` instead of `TxIns build era`. This removes the type-level distinction between "building" and "viewing" a transaction body, which eliminates significant boilerplate at the cost of less static safety for view contexts.

### Direct use of ledger types

Fields that previously had cardano-api wrapper types now use ledger types directly:

- `txFee :: L.Coin` instead of `TxFee era`
- `txValidityLowerBound :: Maybe L.SlotNo` instead of `TxValidityLowerBound era`
- `txValidityUpperBound :: Maybe L.SlotNo` instead of `TxValidityUpperBound era`
- `txProtocolParams :: Maybe (L.PParams era)` instead of `BuildTxWith build (Maybe (LedgerProtocolParameters era))`
- `txCurrentTreasuryValue :: Maybe L.Coin` instead of `Maybe (Featured ConwayEraOnwards era (Maybe L.Coin))`
- `txTreasuryDonation :: Maybe L.Coin` instead of `Maybe (Featured ConwayEraOnwards era L.Coin)`

### Presence/absence via `Maybe` and `[]`

Wrapper types with "None" constructors that carried eon proofs are replaced with idiomatic Haskell:

- `txInsCollateral :: [TxIn]` (empty list = none)
- `txTotalCollateral :: Maybe TxTotalCollateral` (`Nothing` = none)
- `txReturnCollateral :: Maybe (TxReturnCollateral era)` (`Nothing` = none)

### Removal of `txUpdateProposal`

The `txUpdateProposal` field is removed entirely. This was a pre-Conway governance mechanism that is obsolete. The experimental API targets Conway and later eras only (see [ADR-004](https://github.com/input-output-hk/cardano-node-wiki/blob/main/docs/ADR-004-Support-only-for-mainnet-and-upcoming-eras.md)). For era compatibility functionality, see the [`Cardano.Api.Compatible.Tx`](https://github.com/IntersectMBO/cardano-api/blob/main/cardano-api/src/Cardano/Api/Compatible/Tx.hs) module.

### Removal of `Featured` and eon wrappers for governance fields

Governance fields (`txProposalProcedures`, `txVotingProcedures`, `txCurrentTreasuryValue`, `txTreasuryDonation`) use plain `Maybe` instead of `Maybe (Featured ConwayEraOnwards era ...)`. Since the experimental API only supports Conway+, the eon proof is unnecessary.

## New `TxOut` type

```haskell
data TxOut era where
  TxOut :: L.EraTxOut era => L.TxOut era -> TxOut era
```

The new `TxOut` is a thin wrapper around the ledger's `L.TxOut era`. The old API had its own `TxOut ctx era` type with separate address, value, datum, and reference script fields that needed conversion to ledger types at transaction construction time.

## Setter function pattern

We provide setter functions for pipeline-style construction:

```haskell
setTxFee :: L.Coin -> TxBodyContent era -> TxBodyContent era
setTxFee v txBodyContent = txBodyContent{txFee = v}
```

Users construct transactions by composing setters on `defaultTxBodyContent`:

```haskell
defaultTxBodyContent
  & setTxIns inputs
  & setTxOuts outputs
  & setTxFee fee
  & setTxCertificates certs
  & setTxWithdrawals withdrawals
```

## Integration with [ADR-010](https://github.com/input-output-hk/cardano-node-wiki/blob/main/docs/ADR-010-cardano-api-script-witness-api.md) witness types

The new `TxBodyContent` directly uses the witness types from ADR-010:

- `txIns :: [(TxIn, AnyWitness era)]`
- `TxWithdrawals` contains `[(StakeAddress, L.Coin, AnyWitness era)]`
- `TxMintValue` uses `AnyScriptWitness era` (a variant without `AnyKeyWitnessPlaceholder`, since minting always requires a script)
- `TxCertificates` uses `OMap (Certificate era) (Maybe (StakeCredential, AnyWitness era))`

The `Witnessable` GADT and `createIndexedPlutusScriptWitnesses` from ADR-010 are used directly to construct the redeemer pointer map from the new type's fields.

## New `UnsignedTx` type

```haskell
data UnsignedTx era
  = L.EraTx era => UnsignedTx (Ledger.Tx era)
```

The output of `makeUnsignedTx` is a ledger transaction that lacks only key witnesses. The `EraTx` constraint is carried existentially in the constructor. A `ToApiEra` type family maps ledger eras back to cardano-api eras for serialization infrastructure compatibility.

## Fee estimation

A new `estimateBalancedTxBody` and `makeTransactionBodyAutoBalance` are provided that operate on the new `TxBodyContent (LedgerEra era)` directly. The balancing algorithm follows the same multi-step strategy as the old API (estimate fee with max values, then recalculate) but with less type-level gymnastics.

# Consequences

Acceptance of this ADR will:

- Dramatically simplify the transaction construction API surface, making it easier for downstream consumers to build transactions.
- Reduce the number of wrapper types and conversion functions that must be maintained.
- Align the experimental API more closely with the ledger, making it easier to adopt new ledger features.
- Complete the integration with the witness API from ADR-010, providing a cohesive experimental transaction API.
- Remove compile-time era gating for fields that are only relevant in certain eras. Since the experimental API only supports Conway and Dijkstra, this is acceptable. If the experimental API is ever back-ported to earlier eras, this would need to be revisited.

# Related ADRs

- [ADR-004](ADR-004-Support-only-for-mainnet-and-upcoming-eras) — the new `TxBodyContent` targets Conway+ only, following the era policy defined there.
- [ADR-010](ADR-010-cardano-api-script-witness-api) — the witness types (`AnyWitness`, `Witnessable`, etc.) are used directly in the new `TxBodyContent`.
