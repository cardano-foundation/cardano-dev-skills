# Status

📜 Proposed 2025-04-14

# Context

The `cardano-cli` has grown to support many commands, each exposing a variety of options and flags. Over time, the way flags are specified has become inconsistent.

Examples of inconsistency include:

## Multiple conventions for how flags are specified

Sometimes we make see the switch with argument form `--output-format text` and sometimes
the simple switch form `--output-text`.

## Multiple default values for a choice

Having more than one default is confusing and complicated.  For example it is possible to have
both `--output-text` and `--output-json` to be the defaults for the same command depending on
how the command is used.

## Actual default behaviour is determined by another flag.

When there is more than one default, another flag decides which selection out of possible choices
is the default.  For example `--output-file` when unspecified would make the default `--output-text`
but when specified would make the default `--output-json`

## Default behaviour determination is determined by the run command

When the command data structure is fully constructed and passed to the run command, it is not
fully known what choice is to be made if it was unspecified.  Instead it is left to the run
command to decide.  This can lead to inconsistency between CLI documentation and what is
implemented in the run command.

## We have multiple types for choices

That are similar and differ only in name or are plus/minus some constructors:

```haskell
data OutputFormatJsonOrText
  = OutputFormatJson
  | OutputFormatText
  deriving (Eq, Show)

data AllOutputFormats
  = FormatJson
  | FormatText
  | FormatCbor
  deriving Show

data ViewOutputFormat
  = ViewOutputFormatJson
  | ViewOutputFormatYaml
  deriving Show

data FriendlyFormat = FriendlyJson | FriendlyYaml
```

## Inconsistent ordering of choices

As we use multiple parsers for similar kinds of things it is possible for the ordering to
be inconsistent.

## Example

```haskell
data QueryUTxOCmdArgs = QueryUTxOCmdArgs
  { ...
  , format :: Maybe AllOutputFormats -- 
  , mOutFile :: !(Maybe (File () Out))
  }
  deriving (Generic, Show)

pQueryUTxOCmd :: ShelleyBasedEra era -> EnvCli -> Parser (QueryCmds era)
pQueryUTxOCmd era envCli =
  fmap QueryUTxOCmd $
    QueryUTxOCmdArgs
      <$> pQueryCommons era envCli
      <*> pQueryUTxOFilter
      <*> ( optional $ -- absence of explicit choice means default by which one?
              asum -- choice of output format includes two defaults, inconsistent ordering
                [ pFormatCbor "utxo"
                , pFormatTextDefault "utxo" -- default 1
                , pFormatJsonDefault "utxo" -- default 2 
                ]
          )
      <*> pMaybeOutputFile  -- The default is determined whether the output-file is specified,
                            -- but this is non-obvious and we still don't know the default.

runQueryUTxOCmd
  :: ()
  => Cmd.QueryUTxOCmdArgs
  -> ExceptT QueryCmdError IO ()
runQueryUTxOCmd
  ( Cmd.QueryUTxOCmdArgs
      { ...
      , Cmd.format
      , Cmd.mOutFile
      }
    ) = do
    join $
      lift
        ( executeLocalStateQueryExpr nodeConnInfo target $ runExceptT $ do
            ...

            pure $ do
              writeFilteredUTxOs sbe format mOutFile utxo -- code to decide the default is embedded in here
                                                          -- far away from the CLI specification which makes
                                                          -- bugs non-obvious
        )
        & onLeft (left . QueryCmdAcquireFailure)
        & onLeft left
```

# Decision

We will adopt a standardized approach for CLI flag specification:

## Where possible, always use the simple switch form

This means the flag should be of the form `--output-text` instead of `--output-format text`.  Temporary support for backwards
compatibility should be considered when migrating to the new style.

## Do not allow more than one default

There should be no more than one default and it should be fixed and visible from the help.

The ability to do this in a clean and less error prone way is shown by the following points.

## Where the choice options are not fixed, use Vary

We may have for example the following options:

* `FormatCbor`
* `FormatJson`
* `FormatText`
* `FormatYaml`

But different commands may only allow some subset of them and different commands use different
subsets.

In this case, do not define a sum type like this:

```haskell
data Format = FormatCbor | FormatJson | FormatText | FormatYaml
```

Instead define separate types for each:

```haskell
data FormatCbor = FormatCbor deriving (Eq, Show)
data FormatJson = FormatJson deriving (Eq, Show)
data FormatText = FormatText deriving (Eq, Show)
```

Then use the `Vary` type to choose the options you want to include for any given command.

For example:

```haskell
data QueryUTxOCmdArgs = QueryUTxOCmdArgs
  { ...
  , format :: Vary [FormatCbor, FormatJson, FormatText]
  }
```

## When using Vary, keep the options in alphabetical order

This will ensure that the help text presented to the user has consistent ordering.

## Define flags as values of `Flag a`, not `Parser a`

Using `Flag a` provides a cleaner way to specify the default.

```haskell
flagFormatCbor :: FormatCbor :| fs => Flag (Vary fs)
flagFormatCbor = mkFlag "output-cbor" "BASE16 CBOR" FormatCbor

flagFormatJson :: FormatJson :| fs => Flag (Vary fs)
flagFormatJson = mkFlag "output-json" "JSON" FormatJson

flagFormatText :: FormatText :| fs => Flag (Vary fs)
flagFormatText = mkFlag "output-text" "TEXT" FormatText
```

## Construct CLI parsers for choices using parserFromFormatFlags

```haskell
pQueryUTxOCmd :: ShelleyBasedEra era -> EnvCli -> Parser (QueryCmds era)
pQueryUTxOCmd era envCli =
  fmap QueryUTxOCmd $
    QueryUTxOCmdArgs
      <$> ...
      <*> parserFromFormatFlags
        "utxo query output"
        [ flagFormatCbor
        , flagFormatJson
        , flagFormatText
        ]
```

## When there is a default, use `setDefault` combinator to specify it

The `setDefault` combinator modifies a flag to be the default.

```haskell
pQueryUTxOCmd :: ShelleyBasedEra era -> EnvCli -> Parser (QueryCmds era)
pQueryUTxOCmd era envCli =
  fmap QueryUTxOCmd $
    QueryUTxOCmdArgs
      <$> ...
      <*> parserFromFormatFlags
        "utxo query output"
        [ flagFormatCbor
        , flagFormatJson & setDefault -- this is the default
        , flagFormatText
        ]
```

# Consequences

### ✅ Positive

* *Declarative defaults*: Defaults are visible in the CLI parser, not buried in runtime logic.
* *Consistent user experience*: CLI behavior and help messages are aligned across commands.
* *Reduced duplication*: The `Vary` mechanism allows composable subsets of choices.
* *Easier testing and documentation*: Defaults are discoverable without running the command.
* *Fewer bugs*: Centralized handling makes incorrect or conflicting defaults less likely.

### ⚠️ Negative

* *Migration effort*: Existing commands must be updated to the new `Vary` + `Flag` approach.
* *Learning curve*: Contributors will need to understand how `Flag`, `Vary`, and `setDefault` work.
* *Breaking changes*: Some commands may behave differently after adopting this change.

# Related ADRs

- [ADR-001](ADR-001-Default-eras-for-CLI-commands) — era flags are an example of the choice flags standardised here.
- [ADR-006](ADR-006-Using-optparse-applicative-main-repository) (rejected) — the `optparse-applicative` fork used by `cardano-cli`.
- [ADR-013](ADR-013-Metavars-must-follow-screaming-snake-case) — defines metavar naming conventions that apply to flags defined here.
