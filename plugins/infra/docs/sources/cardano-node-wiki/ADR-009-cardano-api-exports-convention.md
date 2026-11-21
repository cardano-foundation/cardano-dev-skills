# Status

✅ Adopted 2025-02-21

# Context

The current module structure of `cardano-api` is very ad-hoc.
It is not clearly defined where modules should be placed and how to be exported.
This ADR aims to standardise this process.

# Decision

## Top level exports

Each top level export should export distinct symbols.
This may depend on the case, for example: `Cardano.Api.Byron` symbols which are still in use in current eras, can be reexported through `Cardano.Api`.

* `Cardano.Api` - everything domain related for the currently used and upcoming eras

* `Cardano.Api.<F>`, where `<F>` represents a feature.
  An aggregate module providing one of core `cardano-api` functionalities.
  The name has to be a singular noun.
  The purpose of this export is to provide users a more granular control of imports if they don't want to import a catch-all `Cardano.Api` module.
  For example:

    * `Cardano.Api.Address`
    * `Cardano.Api.Block`
    * `Cardano.Api.Certificate`
    * `Cardano.Api.Eon`
    * `Cardano.Api.Genesis`
    * `Cardano.Api.Governance`
    * `Cardano.Api.IPC`
    * `Cardano.Api.Key`
    * `Cardano.Api.LedgerState`
    * `Cardano.Api.Query`
    * `Cardano.Api.Serialisation`
    * `Cardano.Api.Tx`

  The following rules apply:

  1. The modules should not be very granular, only related to a particular feature set.
     For example

     * `Cardano.Api.Governance.Actions.ProposalProcedure` should not be a top level export and should be exported through `Cardano.Api.Governance`.
     * `Cardano.Api.LedgerEvents` should not be a top level export and should be exported through `Cardano.Api.LedgerState`.

  1. The module should be reexported through `Cardano.Api`.
    This makes using `cardano-api` easier, by not forcing users to decide what to import, and allowing them to just simply write `import Cardano.Api`.

* `Cardano.Api.Byron` - everything for the obsoleted Byron era

* `Cardano.Api.Compatible` - everything for the older eras.
  The purpose of this module to provide a limited backwards compatibility for eras not in use on Cardano mainnet.
  This is meant only for supporting of tests which hardfork through eras.

  For both `Cardano.Api.Byron` and `Cardano.Api.Compatible` the following rules apply:

  1. Any symbol from previous era, not in use in current era, should be exported through the respective module for older eras.
  2. Any symbol from previous era and still in use in the current era, should be exported through `Cardano.Api` and additionally through `Cardano.Api.(Byron|Compatible)`.

* `Cardano.Api.Experimental` - a transient module for implementing new not yet stabilised APIs.
  Not meant to be used by `cardan-api` users directly.

* `Cardano.Api.<U>` utility module, where `<U>` represents a utilities set.
  For example `Cardano.Api.Pretty`, `Cardano.Api.Monad.Error`.

  * Reexports from upstream libraries like consensus, network or ledger, also fall into this category e.g. `Cardano.Api.Ledger`.

  * Modules which are exposing general purpose classes and functions should go also into a separate module, and they don't need to be reexported through `Cardano.Api`.
    For example `Cardano.Api.Tx.UTxO` - a wrapper type, with functions common to maps which would clash with other map data structures.
    A good example of this pattern from Hackage is [`Data.Aeson.KeyMap`](https://hackage.haskell.org/package/aeson-2.2.3.0/docs/Data-Aeson-KeyMap.html).

  In principle, those should not be reexported from `Cardano.Api`, because they would pollute symbol namespace, and are not required for using `cardano-api` core features but can be useful for the advanced users.
    In certain situations, parts of those modules can be reexported from `Cardano.Api`, to provide more seamless experience of using the main `Cardano.Api` module.

## Deeper level exports

Any other modules not meant to be a top level export, should be placed inside `Cardano.Api.Internal` or `Cardano.Api.<X>.Internal` and be reexported through a suitable top level module.
In general internal modules shouldn't be exposed in cabal package, but it may be necessary for using them from other components in `cardano-api`, like tests.
This however depends on the specific use case.
`Internal` in the module name should indicate that the module isn't really meant to be used directly, and users can expect more frequent breakage when relying on it.

* `Cardano.Api.<X>.Internal` or `Cardano.Api.Internal.<X>` or should contain everything related to the domain `<X>`.
  * If `Cardano.Api.<X>` is a top level export, internal functions should go to `Cardano.Api.<X>.Internal` (e.g. `Cardano.Api.Address.Internal`), otherwise
  * if there's no `Cardano.Api.<X>` top level export, internal functions should go to `Cardano.Api.Internal.<X>` (e.g. `Cardano.Api.Internal.Orphans`).

  A good example from Hackage how to nest `Internal` modules is [`text`](https://github.com/haskell/text/blob/master/src/Data/Text/Internal/Builder/RealFloat/Functions.hs) package.

# Consequences

Acceptance of ADR will require rename of almost all cardano-api modules which will be a breaking change.

# Related ADRs

- [ADR-002](ADR-002-Module-structure-for-generators) defines generator module conventions (`Test.Gen.[Path]`, etc.).
- [ADR-004](ADR-004-Support-only-for-mainnet-and-upcoming-eras) defines the eras exposed through `Cardano.Api.Experimental` and `Cardano.Api.Compatible`.
- [ADR-010](ADR-010-cardano-api-script-witness-api) introduces new types that should be exported following these conventions.
- [ADR-014](ADR-014-Total-conversion-functions-conventions) placement of `Inject`/`Convert` instances should follow the module conventions defined here.

