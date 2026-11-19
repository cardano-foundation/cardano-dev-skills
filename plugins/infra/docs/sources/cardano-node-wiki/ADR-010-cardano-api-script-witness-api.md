# Status

✅ Adopted 2025-03-13

# Context

The current script witness api (and by extention the witness api) has been long overdue for a refactor. The main objectives for the introduction of the new witness api are as follows:
- Use as much as possible (within reason) `cardano-ledger` types directly. This reduces the maintenance burden and allows us to leverage `cardano-ledger` type classes.
- Treat simple script witnesses separately from plutus script witnesses. This is a QOL improvement that makes the code more easily understandable and nicer to work with.
- Use `cardano-ledger`'s `PlutusRunnable` type in order to leverage it's serialization instances that check the validity of the plutus script at the point of disk read. 
- The new api needs to be compatible with the old api

# Decision

## Summary

Currently we have several functions that generate indicies in order to construct the redeemer pointer map. For example:

```haskell

indexTxWithdrawals
  :: TxWithdrawals BuildTx era
  -> [(ScriptWitnessIndex, StakeAddress, L.Coin, Witness WitCtxStake era)]
indexTxWithdrawals TxWithdrawalsNone = []
indexTxWithdrawals (TxWithdrawals _ withdrawals) =
  [ (ScriptWitnessIndexWithdrawal ix, addr, coin, witness)
  | (ix, (addr, coin, BuildTxWith witness)) <- zip [0 ..] (orderStakeAddrs withdrawals)
  ]

...

indexTxMintValue
  :: TxMintValue build era
  -> [ ( ScriptWitnessIndex
       , PolicyId
       , AssetName
       , Quantity
       , BuildTxWith build (ScriptWitness WitCtxMint era)
       )
     ]
indexTxMintValue TxMintNone = []
indexTxMintValue (TxMintValue _ policiesWithAssets) =
  [ (ScriptWitnessIndexMint ix, policyId', assetName', quantity, witness)
  | (ix, (policyId', assets)) <- zip [0 ..] $ toList policiesWithAssets
  , (assetName', quantity, witness) <- assets
  ]

...

indexTxIns
  :: TxIns BuildTx era
  -> [(ScriptWitnessIndex, TxIn, Witness WitCtxTxIn era)]
indexTxIns txins =
  [ (ScriptWitnessIndexTxIn ix, txIn, witness)
  | (ix, (txIn, BuildTxWith witness)) <- zip [0 ..] $ orderTxIns txins
  ]

...etc

```

There is a repeating pattern here that basically has something that is _witnessable_ (tx input, mint value, certificate, etc) accompanied by its index and the corresponding witness. Therefore the following types are introduced to capture this pattern:

```haskell
data Witnessable thing era where
  WitTxIn :: L.AlonzoEraScript era => TxIn -> Witnessable TxIn era
  WitTxCert :: L.AlonzoEraScript era => Cert -> Witnessable Cert era
  WitMint :: L.AlonzoEraScript era => Mint -> Witnessable Mint era
  WitWithdrawal
    :: L.AlonzoEraScript era => Withdrawal -> Witnessable Withdrawal era
  WitVote
    :: L.ConwayEraScript era
    => Voter -> Witnessable Voter era
  WitProposal :: L.ConwayEraScript era => Proposal -> Witnessable Proposal era


type Mint = (PolicyId, AssetName, Quantity)

type Withdrawal = (StakeAddress, L.Coin)

type Cert = (AnyCertificate, StakeCredential)

type Voter = Api.AnyVoter

type Proposal = Api.AnyProposal


data AnyWitness era where
  AnyKeyWitness :: AnyWitness era
  AnySimpleScriptWitness :: SimpleScriptOrReferenceInput era -> AnyWitness era
  AnyPlutusScriptWitness :: PlutusScriptWitness lang purpose era -> AnyWitness era
```

NB: See `class GetPlutusScriptPurpose` to understand the purpose of the ledger constraints in `Witnessable thing era` constructor.

And the upshot is once we have `[(Witnessable thing era, AnyWitness era)]` these can be uniformly treated to construct the redeemer pointer map (`Redeemers era`):

```haskell

data TxScriptWitnessRequirements era
  = TxScriptWitnessRequirements
      (Set L.Language)
      [L.Script era]
      (L.TxDats era)
      (L.Redeemers era) -- Redeemer pointer map

getTxScriptWitnessesRequirements
  :: AlonzoEraOnwards era
  -> [(Witnessable witnessable (ShelleyLedgerEra era), AnyWitness (ShelleyLedgerEra era))]
  -> TxScriptWitnessRequirements (ShelleyLedgerEra era)
getTxScriptWitnessesRequirements eon wits =
  mconcat $ map (getTxScriptWitnessRequirements eon) wits
```

## New `IndexedPlutusScriptWitness` types

We are only concerned with the index of something that is plutus script witnessed. Therefore we introduce `IndexedPlutusScriptWitness`:

```haskell
data IndexedPlutusScriptWitness witnessable (lang :: L.Language) (purpose :: PlutusScriptPurpose) era where
  IndexedPlutusScriptWitness
    :: Witnessable witnessable era
    -> (L.PlutusPurpose L.AsIx era)
    -> (PlutusScriptWitness lang purpose era)
    -> IndexedPlutusScriptWitness witnessable lang purpose era
```

We do away with `cardano-api`'s `ScriptWitnessIndex` and directly use `cardano-ledger`'s `PlutusPurpose AsIx era` which is essentially the same thing. 
The benefit here is we get to use ledger type classes to produce the index of the plutus script witness thing we are interested in:

```haskell
class GetPlutusScriptPurpose era where
  toPlutusScriptPurpose
    :: Word32
    -> Witnessable thing era
    -> L.PlutusPurpose L.AsIx era

instance GetPlutusScriptPurpose era where
  toPlutusScriptPurpose index WitTxIn{} = L.mkSpendingPurpose (L.AsIx index)
  toPlutusScriptPurpose index WitWithdrawal{} = L.mkRewardingPurpose (L.AsIx index)
  toPlutusScriptPurpose index WitMint{} = L.mkMintingPurpose (L.AsIx index)
  toPlutusScriptPurpose index WitTxCert{} = L.mkCertifyingPurpose (L.AsIx index)
  toPlutusScriptPurpose index WitVote{} = L.mkVotingPurpose (L.AsIx index)
  toPlutusScriptPurpose index WitProposal{} = L.mkProposingPurpose (L.AsIx index)
```

The ledger constraints in the `Witnessable thing era` data constructors allow us to directly construct the script witness index (`PlutusPurpose AsIx era`) with the  `toPlutusScriptPurpose` class method. We no longer have to use the old api's `ScriptWitnessIndex` which is eventually converted into a `PlutusPurpose AsIx era`. This approach is more direct.

This ultimately allows us to collapse all of the different index calculation functions into a single function:

```haskell
createIndexedPlutusScriptWitness
  :: Word32
  -> Witnessable witnessable era
  -> PlutusScriptWitness lang purpose era
  -> IndexedPlutusScriptWitness witnessable lang purpose era
createIndexedPlutusScriptWitness index witnessable =
  IndexedPlutusScriptWitness witnessable (toPlutusScriptPurpose index witnessable)

createIndexedPlutusScriptWitnesses
  :: [(Witnessable witnessable era, AnyWitness era)]
  -> [AnyIndexedPlutusScriptWitness era]
createIndexedPlutusScriptWitnesses witnessableThings =
  [ AnyIndexedPlutusScriptWitness $ createIndexedPlutusScriptWitness index thing sWit
  | (index, (thing, AnyPlutusScriptWitness sWit)) <- zip [0 ..] $ enforceOrdering witnessableThings
  ]
 where
  enforceOrdering = List.sortBy (compareWitnesses `on` fst)

compareWitnesses :: Witnessable thing era -> Witnessable thing era -> Ordering
compareWitnesses a b =
  case (a, b) of
    (WitTxIn txinA, WitTxIn txinB) -> compare txinA txinB
    (WitTxCert{}, WitTxCert{}) -> LT -- Certificates in the ledger are in an `OSet` therefore we preserve the order.
    (WitMint mintA, WitMint mintB) -> compare mintA mintB
    (WitWithdrawal (stakeAddrA, _), WitWithdrawal (stakeAddrB, _)) -> compare stakeAddrA stakeAddrB
    (WitVote voterA, WitVote voterB) -> compare voterA voterB
    (WitProposal propA, WitProposal propB) -> compare propA propB

```

## New `PlutusScriptInEra` type 


```haskell 
data PlutusScriptInEra (lang :: L.Language) era where
  PlutusScriptInEra :: PlutusRunnable lang -> PlutusScriptInEra lang era
```

Why PlutusRunnable? Mainly for deserialization benefits. The deserialization of this type looks at the major protocol version and the script language to determine if indeed the script is runnable. This is the decode CBOR instance in `cardano-ledger`: 

```haskell
instance PlutusLanguage l => DecCBOR (PlutusRunnable l) where
  decCBOR = do
    plutus <- decCBOR
    pv <- getDecoderVersion
    either (fail . show) pure $ decodePlutusRunnable pv plutus
```
`decodePlutusRunnable` eventually calls a deserialization function in the `plutus` repo which will fail if 
the plutus script version you are using is not available in a given era. 

A ficticious example: The plutus team introduces PlutusV4. This plutus script version can only be used in the era after Conway (Conway + 1).
However a user tries to use a PlutusV4 script in Conway. Because we use `PlutusRunnable` to represent our plutus scripts we would get a deserialization error.
If we stuck with `ShortByteString` to represent plutus scripts, the error would only occur at transaction submission or when using `transaction build`. 
This is a small QOL improvement as now if your script deserializes at least you know it's valid for a particular era.


## New `PlutusScriptDatum` type 

```haskell
data PlutusScriptDatum (lang :: L.Language) (purpose :: PlutusScriptPurpose) where
  SpendingScriptDatum
    :: PlutusScriptDatumF lang SpendingScript -> PlutusScriptDatum lang SpendingScript
  InlineDatum :: PlutusScriptDatum lang purpose
  NoScriptDatum
    :: PlutusScriptDatum lang purpose

data NoScriptDatum = NoScriptDatumAllowed deriving Show

-- | The PlutusScriptDatum type family is used to determine if a script datum is allowed
-- for a given plutus script purpose and version. This change was proposed in CIP-69
-- https://github.com/cardano-foundation/CIPs/tree/master/CIP-0069
type family PlutusScriptDatumF (lang :: L.Language) (purpose :: PlutusScriptPurpose) where
  PlutusScriptDatumF L.PlutusV1 SpendingScript = HashableScriptData
  PlutusScriptDatumF L.PlutusV2 SpendingScript = HashableScriptData
  PlutusScriptDatumF L.PlutusV3 SpendingScript = Maybe HashableScriptData -- CIP-69
  PlutusScriptDatumF L.PlutusV1 MintingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV2 MintingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV3 MintingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV1 WithdrawingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV2 WithdrawingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV3 WithdrawingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV1 CertifyingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV2 CertifyingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV3 CertifyingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV1 ProposingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV2 ProposingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV3 ProposingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV1 VotingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV2 VotingScript = NoScriptDatum
  PlutusScriptDatumF L.PlutusV3 VotingScript = NoScriptDatum

```
The `PlutusScriptDatum` GADT and `PlutusScriptDatumF` type family are defined to simply capture CIP-69 i.e spending script datums are optional in PlutusV3.

## New `SimpleScript` type

```haskell
data SimpleScript era where
  SimpleScript :: Ledger.NativeScript era -> SimpleScript era
```
A wrapper around ledger's `NativeScript` type. We opt for this type because it restricts the allowable scripts to simple scripts.

## Misc 

Future work would include creating a `TxBodyContents` successor that will use `[(Witnessable witnessable era, AnyWitness era)]` directly. 

# Consequences

Acceptance of this ADR will: 
- Improve the clarity of the witness and script apis
- Make clearer the relationship between the redeemer pointers and the script witnesses
- Allow us to use the new api "under the hood" of the old api reducing the maintenance burden of maintaining the old vs new api.

# Related ADRs

- [ADR-004](ADR-004-Support-only-for-mainnet-and-upcoming-eras) defines the available eras that parameterize the witness API.
- [ADR-009](ADR-009-cardano-api-exports-convention) — new witness types should be exported following those module conventions.
- [ADR-014](ADR-014-Total-conversion-functions-conventions) conversions between `cardano-api` and `cardano-ledger` types should use `Inject`/`Convert`.
- [ADR-016](ADR-016-cardano-api-new-txbodycontent) — the new `TxBodyContent` integrates directly with the witness types defined here.
