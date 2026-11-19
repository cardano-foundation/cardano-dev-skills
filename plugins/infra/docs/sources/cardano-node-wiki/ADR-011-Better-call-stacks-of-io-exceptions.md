# Status

✅ Adopted 2025-03-11

# Context

This ADR enriches exceptions thrown from `IO` functions with call stacks up to the function usage site.

## The problem
This ADR extends [ADR-008](ADR-008-Use-RIO-in-cardano‐cli).

The goal of this ADR is to provide better call stacks in `IO` exceptions.
The problem with exceptions thrown from IO monad is that they do not carry call stack from where they were thrown.
This is not very convenient when for example doing multiple file access or network operations in a row.
You won't know which one has thrown an exception: you will have only a vague exception message without many details, for example:
```
Network.Socket.recvBuf: resource vanished (Connection reset by peer)
```

## Solution

The currently used type alias adds call stacks to the functions:
```haskell
type CIO e a = HasCallStack => RIO e a
```
We can make sure that `IO` exceptions thrown in `IO` actions are captured and rethrown with a helper `runIO` function, meant to be used instead of `liftIO`:

```haskell
import UnliftIO.Exceptions (catchAny, throwIO)

runIO :: IO a -> CIO a
runIO m = withFrozenCallStack $ catchAny (liftIO m) (throwIO . mkE)
 where
  mkE :: SomeException -> IoeWrapper
  mkE e = withFrozenCallStack $ IoeWrapper e

-- | An exception wrapper type, adding a call stack to it
data IoeWrapper = HasCallStack => IoeWrapper SomeException

deriving instance Show IoeWrapper

instance Exception IoeWrapper where
  displayException (IoeWrapper (SomeException e)) =
    constructorName <> ": " <> displayException e <> "\n" <> prettyCallStack callStack
   where
    constructorName =  tyConName . typeRepTyCon $ typeOf e
```
The provided `runIO` wraps synchronous exceptions into `IoeWrapper`, which adds additional information about call stack.

The resulting call stack will contain entries up to the point where `runIO` was called.
This means that in the following code:
```haskell
foo :: CIO e ()
foo = do
  someFunction
  runIO $ do
    someOtherFunction
    someExceptionThrowingFunction
```
the exception thrown from `someExceptionThrowingFunction` and wrapped using `runIO` will only point to the place where `runIO` was called.

# Decision

The ADR gets adopted in `cardano-api` and `cardano-cli`.

Performance impact of the changes needs to be investigated.
`cardano-cli` does not perform any expensive operations and it is a short-lived process, so the performance impact there is not that significant.
However, in case of `cardano-api` the performance impact has to be investigated further, with the emphasis on the following areas:

* Transaction construction/fee balancing
* Serialization
* Key generation
* Queries

This means that `HasCallStack` constraint should not be blindly put everywhere but only in places where it can aid debugging significantly.

# Consequences

1. More detailed call stacks when interacting with IO.

1. **A need for manual step when writing new code**.
  Developers would have to remember to use `runIO` instead of `liftIO`.

1. **Performance impact**.
  Including `HasCallStack` has [some small performance penalty][hascallstack-perf-penalty], so it may affect loops executed many times inside `CIO e`.


[hascallstack-perf-penalty]: https://stackoverflow.com/questions/57471398/how-does-hascallstack-influence-the-performance-of-a-normal-branch-in-haskell

# Related ADRs

- [ADR-008](ADR-008-Use-RIO-in-cardano‐cli) — this ADR extends ADR-008's `RIO` adoption with better call stacks for IO exceptions.

[modeline]: # ( vim: set spell spelllang=en: )
