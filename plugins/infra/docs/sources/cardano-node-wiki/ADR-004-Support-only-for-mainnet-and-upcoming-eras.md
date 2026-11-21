# Status

✅ Adopted  2023-07-22

# Context

## Background
 
In the cardano blockchain, available functionality is determined by the era (more precisely the protocol version).
To capture this we defined the following types<sup>1, 2</sup>:
```haskell
data ShelleyBasedEra era where
  ShelleyBasedEraShelley :: ShelleyBasedEra ShelleyEra
  ShelleyBasedEraAllegra :: ShelleyBasedEra AllegraEra
  ShelleyBasedEraMary :: ShelleyBasedEra MaryEra
  ShelleyBasedEraAlonzo :: ShelleyBasedEra AlonzoEra
  ShelleyBasedEraBabbage :: ShelleyBasedEra BabbageEra
  ShelleyBasedEraConway :: ShelleyBasedEra ConwayEra

data CardanoEra era where
  ByronEra :: CardanoEra ByronEra
  ShelleyEra :: CardanoEra ShelleyEra
  AllegraEra :: CardanoEra AllegraEra
  MaryEra :: CardanoEra MaryEra
  AlonzoEra :: CardanoEra AlonzoEra
  BabbageEra :: CardanoEra BabbageEra
  ConwayEra :: CardanoEra ConwayEra

```
Early on the idea was to parameterize functions on the era so they can have the era specific behaviour but also to capture this idea of backwards compatibility.
In the Shelley era days, there was an (incorrect) assumption that later eras would be backwards compatible with previous eras, especially where transactions were concerned.
This would have allowed users to in theory never update their `cardano-cli` version however this is not the case as hardforks introduce backwards incompatible changes (see Conway breaking changes as an example).

The other justification for enumerating the eras like this was to allow QA to perform testing across all eras.
However, the only test QA performs across the eras are hardforks.
Therefore we don't need to expose all the era specific functionality for each era, rather we need to maintain the ability to submit hardfork update proposals across the eras i.e Byron -> latest era. 

Users consuming `cardano-api` are only interested in functionality relevant to mainnet and the upcoming era if they want to experiment with new features on a testnet.
Therefore rather than maintaining a potentially never ending enumeration of eras, I propose to maintain only the era on mainnet and the upcoming era that will be hardforked to in the future.

## Code 

```haskell
data ConwayEra

data BabbageEra 

-- Let's us constrain the era possibilities to mainnet's era
-- and a potential upcoming era
type family LedgerEra era = (r :: Type) | r -> era where
  LedgerEra BabbageEra = Ledger.Babbage
  LedgerEra ConwayEra = Ledger.Conway

-- Allows us to gradually change the api without breaking things.
-- This will eventually be removed.
type family ExperimentalEraToApiEra era = (r :: Type) | r -> era where
  ExperimentalEraToApiEra BabbageEra = Api.BabbageEra
  ExperimentalEraToApiEra ConwayEra = Api.ConwayEra


data Era era where
  -- | Deprecated era, Do not use.
  BabbageEra :: Era BabbageEra
  -- | The era currently active on Cardano's mainnet.
  ConwayEra :: Era ConwayEra


-- | Type class interface for the 'Era' type.
class UseEra era where
  useEra :: Era era

instance UseEra BabbageEra where
  useEra = BabbageEra

instance UseEra ConwayEra where
  useEra = ConwayEra
```

### Deprecation of an era

The following is an example of how a user would consume the api and how a user would see a deprecation of an era

```haskell

newtype UnsignedTx era
  = UnsignedTx (Ledger.Tx (LedgerEra era))
 
makeUnsignedTx
  :: Ledger.EraCrypto (LedgerEra era) ~ L.StandardCrypto
  => L.AlonzoEraTx (LedgerEra era)
  => L.BabbageEraTxBody (LedgerEra era)
  => ShelleyLedgerEra (ExperimentalEraToApiEra era) ~ LedgerEra era
  => Era era
  -> TxBodyContent BuildTx (ExperimentalEraToApiEra era)
  -> Either UnsignedTxError (UnsignedTx era)
makeUnsignedTx era bc = ...


testBabbageUnsignedTx :: Either UnsignedTxError (UnsignedTx BabbageEra)
testBabbageUnsignedTx = makeUnsignedTx BabbageEra $ defaultTxBodyContent ShelleyBasedEraBabbage

testConwayUnsignedTx :: Either UnsignedTxError (UnsignedTx ConwayEra)
testConwayUnsignedTx = makeUnsignedTx ConwayEra $ defaultTxBodyContent ShelleyBasedEraConway
```

In the current state of affairs both `testBabbageUnsignedTx` and `testConwayUnsignedTx` type check without issue.
However let's update the types to show how a deprecation (or a successful hardfork to the upcoming era) will show up in a user's code.

Changes:
```haskell
-- this deprecation pragma deprecates both the type `BabbageEra` and the `BabbageEra` constructor
{-# DEPRECATED BabbageEra "We are currently in the Conway era. Please update your type Signature to ConwayEra" #-}
data BabbageEra
...
...
data Era era where
  -- | Previous era, do not use.
  BabbageEra :: Era BabbageEra
  -- | The era currently active on Cardano's mainnet.
  ConwayEra ::  Era ConwayEra

class UseEra era where
  useEra :: Era era

instance TypeError ('Text "UseEra BabbageEra: Deprecated. Update to ConwayEra") => UseEra BabbageEra where
  useEra = error "unreachable"

instance UseEra ConwayEra where
  useEra = ConwayEra
```

Type error:
```
In the use of type constructor or class ‘BabbageEra’
(imported from Cardano.Api.Experimental.Eras, but defined in Cardano.Api.Protocol.AvailableEras):
Deprecated: "We are currently in the Conway era. Please update your type Signature to ConwayEra"
```

This deprecation will happen only after the hardfork has been successful.
There should be no need for consumers of the api to need the prior era's specific functionality.
If users for some reason want this, we can direct them to use the ledger's api directly.

The next stage after deprecation period, should be **removal of the deprecated constructor**.
The deprecation period should be long enough to give enough time for `cardano-api` consumers to update their codebase to the post-hardfork era.

## Downsides

`cardano-api` users will be limited up to only two eras exposed from `cardano-api`.
This will force them to keep up-to-date their code after the hardfork. 
This may turn out to be a disruptive process, but necessary to make the code using `cardano-api` healthy.

# Approach

The new api should be created adjacant to the existing one.
We then slowly replace the use of the existing api in cardano-api, eventually deprecating the "old" api. 

# Decision

The ADR gets adopted in `cardano-api` and `cardano-cli`. There may be minor tweaks as it is rolled out in `cardano-cli`.

# Consequences

- Less boiler plate in cardano-api and in users' codebases 
- Clearer defined boundaries as to new functionality being introduced due to a new era
- Lower maintenance overhead 
- The need for an era agnostic api with respect to update proposals (these change on the Babbage/Conway boundary)

# References
- 1: [ShelleyBasedEra](https://github.com/IntersectMBO/cardano-api/blob/873397bfe0436c224c593f456a3bc237ee0af0c8/cardano-api/internal/Cardano/Api/Eon/ShelleyBasedEra.hs#L123)
- 2: [CardanoEra](https://github.com/IntersectMBO/cardano-api/blob/873397bfe0436c224c593f456a3bc237ee0af0c8/cardano-api/internal/Cardano/Api/Eras/Core.hs#L256)

# Related ADRs

- [ADR-001](ADR-001-Default-eras-for-CLI-commands) — defines how CLI commands default to an era.
- [ADR-009](ADR-009-cardano-api-exports-convention) — defines the `Cardano.Api.Experimental` and `Cardano.Api.Compatible` module structure.
- [ADR-010](ADR-010-cardano-api-script-witness-api) — the script witness API is parameterized by these eras.
- [ADR-015](ADR-015-Cardano-API-WASM-library-for-browser) — the WASM API exposes only the eras defined here.
- [ADR-016](ADR-016-cardano-api-new-txbodycontent) — the new `TxBodyContent` targets only the eras defined here (Conway+).
