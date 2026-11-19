# Status

- ✅ Adopted 2025-06-09

# Context

In `cardano-api` we have multiple functions for performing conversions on values from one type to another, for example:

```haskell
fromShelleyDeltaLovelace :: L.DeltaCoin -> Lovelace -- 'from' at the beginning
lovelaceToQuantity :: Lovelace -> Quantity -- 'to' in the middle
toAlonzoScriptLanguage :: AnyPlutusScriptVersion -> Plutus.Language -- 'to' at the beginning
convReferenceInputs :: TxInsReference build era -> Set Ledger.TxIn -- 'conv' at the beginning
```

There are multiple naming conventions for the conversion functions which makes them hard to locate.
Some conversion functions with lengthy names, are not very convenient to use.

# Decision

## Type classes

For total functions, which are simply converting a value from one type to another, we can use type classes [`Inject` (from `cardano-ledger`)](https://cardano-ledger.cardano.intersectmbo.org/cardano-ledger-core/Cardano-Ledger-BaseTypes.html#t:Inject) & [`Convert`](https://cardano-api.cardano.intersectmbo.org/cardano-api/Cardano-Api-Era.html#t:Convert):
```haskell
class Inject t s where
  inject :: t -> s

class Convert (f :: a -> Type) (g :: a -> Type) where
  convert :: forall a. f a -> g a
```

The use of those conversion functions should be limited to **internal use only**.
The library should still export conversion functions with explicit type names for better readability.
An exception to this would be a set of types which are all convertible to each other, like `Eon`s.
Writing $N \times N$ conversion functions for $N$ types would be cumbersome, so using `inject`/`convert` instead is justified here.

Inject instances should be placed near the definition of one of the types, to make them more discoverable and avoid orphaned instances.

>[!NOTE]
>The difference between `Inject` and `Convert` class is that `Convert` is better typed for types with `Type -> Type` kind.
>In other words, when writing `instance Inject (Foo a) (Bar a)` the GHC's typechecker needs some help to understand the code using `inject`:
>```haskell
>let x = inject @_ @(Bar Bool) $ Foo True
>```
>That is not needed for `convert`.

### Injection law

The `Inject` and `Convert` classes are meant to be used for trivial conversions only and not for more complex types like polymorphic collections (e.g. `[a] -> Set a` which loses ordering).
The `inject` and `convert` implementations should both be injective:
```math
\forall_{x,x' \in X} \ \ inject(x) = inject(x') \implies x = x'
```

This effectively means that any hashing functions or field accessors for constructors losing information (e.g. `foo (Foo _ a) = a`) should not be implemented as `Inject`/`Convert` instances.

## Explicit conversion functions

For explicit conversion functions, the following naming convention should follow:

```haskell
fooToBar :: Foo -> Bar
```

>[!IMPORTANT]
>Conversion functions should be placed near the conversion target type definition if possible.

### Qualified imports

If the module exporting conversion functions is meant to be imported qualified, and provides functions for operating on a single data type, a shorter name with `from` or `to` prefix is allowed.

#### `from`-prefixed functions

For defining conversion functions, **using `from`-prefixed functions should be preferred**.
The `from...` function should be placed nearby the `Foo` definition.

```haskell
module Data.Foo where

import Data.Bar (Bar)

data Foo = Foo

fromBar :: Bar -> Foo
```

where the usage would look like:
```haskell
import Data.Foo qualified as Foo

Foo.fromBar bar
```

#### `to`-prefixed functions

When it's not possible to define `from`-prefixed functions in the location of the target type, it's permitted to use `to`-prefixed function.

```haskell
module Data.Foo where

import Data.Baz (Baz)
data Foo = Foo

toBaz :: Foo -> Baz
```

# Consequences

## Advantages
- An uniform API for total conversions
- A list of `Inject` instances lists all available conversions for the type
- Less maintenance burden with regards to the naming conventions of the conversion functions

## Disadvantages
- It may be a bit less obvious how to discover available conversions, because one would have to browse the type's `Inject` instances to find the conversion functions they are looking for - instead of looking for exported functions.


# Related ADRs

- [ADR-009](ADR-009-cardano-api-exports-convention) — defines module conventions; instance placement ("near the definition of one of the types") should follow those conventions.
- [ADR-010](ADR-010-cardano-api-script-witness-api) — the script witness API converts extensively between `cardano-api` and `cardano-ledger` types; these conversions should use `Inject`/`Convert`.
- [ADR-015](ADR-015-Cardano-API-WASM-library-for-browser) — the `ToJSVal`/`FromJSVal` type class pattern is analogous to the `Inject`/`Convert` pattern defined here.

[modeline]: # ( vim: set spell spelllang=en: )
