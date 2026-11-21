# Status

✅ Adopted 2022-12-17

# Context

In a project, it is desirable to have a standard module structure so that a developer can easily navigate the code base and know when they write new code they know where to put the code so that other people can find it.

At IOG, we do not yet have an organisation-level standard for organising modules.  Short of having an organisation-level standard, it is worthwhile for `cardano-node` code to formally define the module structure for its code.

## Status quo

Different people have different ideas for how modules should be structured.

Across IOG projects excluding `cardano-node`, we have the following:

* `cardano-crypto-wrapper`
  * `test-suite test`
    * `Test.Cardano.Crypto.Gen`
* `cardano-crypto-test`
  * `library`
    * `Test.Cardano.Crypto.Gen`
* `byron-spec-ledger`
  * `library`
    * `Hedgehog.Gen.Double`
    * `Byron.Spec.Ledger.Core.Generators`
* `cardano-ledger-byron`
  * `test-suite cardano-ledger-byron-test`
    * `Test.Cardano.Chain.Block.Gen`
* `cardano-ledger-byron-test`
  * `library`
    * `Test.Cardano.Chain.Block.Gen`
* `cardano-ledger-shelley-test`
  * `library`
    * `Test.Cardano.Ledger.Shelley.Generator.Block`
    * `Test.Cardano.Ledger.Shelley.Serialisation.Generators`
  * `benchmark mainbench`
    * `Cardano.Ledger.Shelley.Bench.Gen`
* `cardano-prelude-test`
  * `library`
    * `Test.Cardano.Prelude.Gen`
* `ouroboros-consensus-byron-test`
  * `library`
    * `Test.Consensus.Byron.Generators`
* `plutus-chain-index-core`
  * `test-suite plutus-chain-index-test`
    * `Generators`
* `plutus-example`
  * `test-suite plutus-example-test`
    * `Test.PlutusExample.Gen`
* `plutus-core`
  * `library plutus-core-testlib`
    * `PlutusCore.Generators`
    * `PlutusCore.Generators.AST`
  * `benchmark cost-model-budgeting-bench`
    * `Generators`
* `small-steps-test`
  * library`
    * `Control.State.Transition.Generator`
    * `Control.State.Transition.Trace.Generator.QuickCheck`

Within `cardano-node`, we have the following:

* `cardano-api`
  * `library gen`
    * `Gen.Cardano.Api`
    * `Gen.Cardano.Api.Metadata`
    * `Gen.Hedgehog.Roundtrip.Bech32`
* `cardano-node`
  * `test-suite cardano-node-test`
    * `Test.Cardano.Node.Gen`

These can be summarised into the following conventions:

* `Generators`
* `Gen.[Path]`
* `Gen.Hedgehog.[Path]`
* `Hedgehog.Gen.[Path]`
* `[Path].Generator`
* `[Path].Generators.[SubPath]`
* `[Path].Generators`
* `[Path].Generator.[Concern]`
* `[Path].Gen`
* `Test.[Path].Gen`
* `Test.[Path].Generators`
* `Test.[Path].Generator.[SubPath]`

In the above `Path` and `SubPath` refer to some qualified module names or some prefix/suffix that the generator is associated with.  `Concern` is something like `QuickCheck`.

The status quo can lead the developer to confusion in the following ways:

1. Sometimes the same module name has been used multiple times in different places.  For example `Test.Cardano.Chain.Block.Gen` and `Test.Cardano.Crypto.Gen` are examples of modules declared multiple times in different packages.
2. `Gen`, `Generators`, `Generator` are all variations of the same thing, so it is not clear which word should be used in a new module or which should be imported.
3. It's what the components of the module name should be and in what order.  For example sometimes `Test`, `Hedgehog`, `Gen` or `[Path]` is the root.  Sometimes `Gen`, `Generator`, `Generators` have been found in prefix, infix and suffix positions.
4. It is unclear given the module name whether the module is local to a test-suite, executable or benchmark component or if it is in a shared library.
5. It is unclear whether a module is production code or non-production code (for example test)

## Original motivation for `cardano-node` convention

`cardano-node` currently uses the `Gen.[Path]` convention to identify modules that are exported from a library and `Test.[Path].Gen` for modules that are local to a non-production component.

This allows for non-library components to define additional generators for itself that are not meant to be in a library without introducing a name conflict.

It also makes it clear which modules are exported from a library and which are not.

To distinguish between production and non-production code the convention uses between `Cardano.[Path]` for production code and `[Prefix].Cardano.Path` for non-production code for example `Test.Cardano.[Path]` and `Gen.Cardano.[Path]`.  The distinction also prevents name collision between local and non-local modules.

The `Test` prefix was avoided for generators exported from a library because that gives the impression that may be false at some point in the future.  This is because generators may be used by a tool as well and not just tests.  For example a tool to generate random transactions.

## Considerations

### Generators as a library & production readiness

Our generator code is already a library being exported as a library-component with the name `cardano-api:gen`.

It is being used within the project as a library by `cardano-api` and `cardano-cli` test-suites.

It is also being within the organisation as a library by `plutus-apps`, also for testing only.

Not adding the `Test` prefix might imply that the code is for production purposes.  As a team we may want to consider whether we even want to support generators as production ready.

We definitely are not ready commit more resources to making generators production ready and as such we need to somehow signal that our generators are provided as-is.

Moreover we will often want to take shortcuts both for resource constraint reasons and because the generator may be written with particular kinds of testing in mind.  As a result the generators may be intentionally or unintentionally non-representative.

On the other hand its worthwhile to signal that our generators can be improved and that we accept organisation-level and community contributions since accepting such contributions would improve the quality of our testing.

### Generator types

We currently only write `hedgehog` generators.

Other kinds of generators exist as well, for example [QuickCheck](https://hackage.haskell.org/package/QuickCheck-2.14.2/docs/Test-QuickCheck-Gen.html).

Perhaps it is worth being clear our generators are in-fact `hedgehog` generators.

## Reasons to exclude

* `Generators` - invites conflict between projects
* `Gen.[Path]` - might imply production readiness
* `Gen.Hedgehog.[Path]` - might wrongly imply they belong to the hedgehog project
* `Hedgehog.Gen.[Path]` - might wrongly imply they belong to the hedgehog project
* `Hedgehog.[Path].Gen` - might wrongly imply they belong to the hedgehog project
* `[Path].Generator` -- too verbose
* `[Path].Generators` -- too verbose
* `[Path].Gen` - might imply production readiness
* `Test.[Path].Gen` - might imply the generator is test-only; could conflict with when we want to define test-specific generators.
* `Test.[Path].Generators` - too verbose; might imply the generator is test-only; could conflict with when we want to define test-specific generators.

# Decision

**This section is a placeholder for the teams actual decision pending team discussion.**

Use the following convention:

* `Test.Gen.[Path]`: modules that are exported from a library
* `Test.[Path].Gen`: modules that are local to a test component
* `Bench.[Path].Gen`: modules that are local to a benchmark component
* `[Path].Gen`: modules that are local to production component

# Consequences

* This ADR serves as documentation for the current `cardano-node` convention to ensure continued consistency within the project eliminating any confusion within the project.  `node` and external developers alike can easily familiarise themselves with this convention.
* Motivations for this convention are clear.
* There remains no standardisation across the IOG organisation which can continue to lead to cross project confusions.
* Whilst standardisation remains a worthwhile cause, we don't second guess what an organisation level standard might look like and avoiding having to refactor yet again.

# Related ADRs

- [ADR-009](ADR-009-cardano-api-exports-convention) — defines top-level module conventions for `cardano-api`; generator modules complement those conventions.