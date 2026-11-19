# Status
✅ Adopted 2025-02-10

# Required Reading

- [ReaderT design pattern](https://tech.fpcomplete.com/blog/2017/06/readert-design-pattern/).
- [RIO](https://tech.fpcomplete.com/haskell/library/rio/)

# Context
In `cardano-cli` we are using `ExceptT someError IO someResult` pattern 292 times in function types in our codebase for different error types.

![image](https://github.com/user-attachments/assets/f405dfca-7d75-404c-b291-3d5140fc8093)

The vast majority of these errors are not used to recover, they are propagated and reported to the user.
```haskell
main :: IO ()
main = toplevelExceptionHandler $ do
  envCli <- getEnvCli
  co <- Opt.customExecParser pref (opts envCli)
  orDie (docToText . renderClientCommandError) $ runClientCommand co
  
...

runClientCommand :: ClientCommand -> ExceptT ClientCommandErrors IO ()
runClientCommand = \case
  AnyEraCommand cmds ->
    firstExceptT (CmdError (renderAnyEraCommand cmds)) $ runAnyEraCommand cmds
  AddressCommand cmds ->
    firstExceptT AddressCmdError $ runAddressCmds cmds
  NodeCommands cmds ->
    runNodeCmds cmds
      & firstExceptT NodeCmdError
  ByronCommand cmds ->
    firstExceptT ByronClientError $ runByronClientCommand cmds
  CompatibleCommands cmd ->
    firstExceptT (BackwardCompatibleError (renderAnyCompatibleCommand cmd)) $
      runAnyCompatibleCommand cmd
...
```
- As a result we have a lot of errors wrapped in errors which makes the code unwieldly and difficult to compose with other code blocks. See image below of incidences of poor composability where we use `firstExceptT` (and sometimes `first`) to wrap errors in other errors.

![image](https://github.com/user-attachments/assets/6a50e8f2-9140-4b7e-afa5-ff778d696742)
 
- The ExceptT IO is a known anti-pattern for these reasons and others as per:
  - https://github.com/haskell-effectful/effectful/blob/master/transformers.md
  - https://tech.fpcomplete.com/blog/2016/11/exceptions-best-practices-haskell/


# Proposed Solution

I propose to replace  `ExceptT someError IO a` with [RIO env a](https://hackage.haskell.org/package/rio-0.1.22.0/docs/RIO.html#t:RIO).


### Example 

Below is how `cardano-cli` is currently structured. `ExceptT` with errors wrapping errors. However the errors ultimately end up being rendered at the top level to the user.

```haskell

-- TOP LEVEL -- 

data ExampleClientCommand = ClientCommandTransactions ClientCommandTransactions

data ExampleClientCommandErrors
  = CmdError CmdError
-- | ByronClientError ByronClientCmdError
-- | AddressCmdError AddressCmdError
-- ...
data CmdError
  = ExampleTransactionCmdError ExampleTransactionCmdError
-- | AddressCommand AnyEraCommand
-- | ByronCommand AddressCmds
-- ...

topLevelRunCommand :: ExampleClientCommand -> ExceptT ExampleClientCommandErrors IO ()
topLevelRunCommand (ClientCommandTransactions txsCmd) =
  firstExceptT (CmdError . ExampleTransactionCmdError) $ runClientCommandTransactions txsCmd

-- SUB LEVEL --

data ClientCommandTransactions = DummyClientCommandToRun

data ExampleTransactionCmdError
  = TransactionWriteFileError !(FileError ())

runClientCommandTransactions
  :: ()
  => ClientCommandTransactions
  -> ExceptT ExampleTransactionCmdError IO ()
runClientCommandTransactions DummyClientCommandToRun =
  ...
  left $
    TransactionWriteFileError $
      FileError "dummy.file" ()
``` 

Proposed change:

```haskell
data ClientCommandTransactions = DummyClientCommandToRun

data ExampleClientCommand = ClientCommandTransactions ClientCommandTransactions

topLevelRunCommand :: ExampleClientCommand -> RIO () ()
topLevelRunCommand (ClientCommandTransactions txsCmd) =
  runClientCommandTransactions txsCmd

runClientCommandTransactions
  :: HasCallStack
  => ClientCommandTransactions
  -> RIO () ()
runClientCommandTransactions DummyClientCommandToRun =
  ...
  throwIO $
    CustomCliException $
      FileError "dummy.file" ()
```

We have eliminated `data ExampleClientCommandErrors` and `data CmdError` and improved the composability of our code.

### Pros 
- Additional [logging functionality](https://hackage.haskell.org/package/rio-0.1.22.0/docs/RIO.html#g:5)
- Explicit environment dependencies e.g `logError :: HasLogFunc env => Text -> RIO env ()`
- Better composability i.e no more errors that wrap errors (see above).

### Cons
- `RIO` is hardcoded to IO so we cannot add additional transformer layers e.g `RIO Env (StateT Int IO) a`
- Implicit error flow. Errors are thrown via GHC exceptions in `IO`. See exception handling below.

## Exception handling

### Exception type
```haskell
data CustomCliException where
  CustomCliException
    :: (Show error, Typeable error, Error error, HasCallStack)
    => error -> CustomCliException

deriving instance Show CustomCliException

instance Exception CustomCliException where
  displayException (CustomCliException e) =
    unlines
      [ show (prettyError e)
      , prettyCallStack callStack
      ]

throwCliError :: MonadIO m => CustomCliException -> m a
throwCliError = throwIO
```

The purpose of `CustomCliException` is to represent explicitly thrown, structured errors that are meaningful to our application. 

### Exception Handling Mechanism: Pros & Cons

#### Pros

1. **Unified Exception Type**

- Simplifies Top-Level Handling: All errors are caught as `CustomCliException`.
- Consistent Reporting: Ensures all errors are formatted uniformly via `prettyError`.

2. **CallStack Inclusion**

- Embeds CallStack to trace error origins, aiding debugging.

3. **Polymorphic Error Support**

- Flexibility: Wraps any error type so long as the required instances exist.

#### Cons
1. **Type Erasure**

- Loss of Specificity: Existential quantification erases concrete error types, preventing pattern-matching on specific errors. That may make specific error recovery logic harder to implement.

# Decision
- Error handling: All errors will be converted to exceptions that will be caught by a single exception handler at the top level.
- Top level monad: [RIO](https://hackage.haskell.org/package/rio-0.1.22.0/docs/RIO.html#t:RIO).
- We agree not to catch `CustomCliException` except in the top-level handler. If the need for catching an exception arises, we locally use an `Either` or `ExceptT` pattern instead.
- `CustomCliException` should only be thrown within the `RIO` monad. Pure code is still not allowed to throw exceptions.

# Consequences
- This should dramatically improve our code's composability and remove many unnecessary error types. 
- Readability concerning what errors can be thrown will be negatively impacted. However, `ExceptT` already lies about what exceptions can be thrown because it is not limited to the error type stated in `ExceptT`'s type signature. In other words, `IO` can implicitly throw other `Exception`s. 
- Initially, this will be adopted under the "compatible" group of commands so `cardano-cli` will have a design split temporarily. Once we are happy with the result we will propagate to the rest of `cardano-cli`

# Related ADRs

- [ADR-007](ADR-007-CLI-Output-Presentation) defines CLI output stream conventions (stdout vs stderr).
- [ADR-011](ADR-011-Better-call-stacks-of-io-exceptions) extends this ADR with better call stacks for IO exceptions.
