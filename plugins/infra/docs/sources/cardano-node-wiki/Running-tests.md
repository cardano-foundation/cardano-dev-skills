Assuming you can already build `cardano-node`, running all the tests is as simple as:

```bash
cabal test all --enable-tests
```

Many of tests are automatically run in CI in PRs.
For an exact list of which tests are run,
please see the "Run tests" step in [haskell.yml](https://github.com/intersectmbo/cardano-node/blob/master/.github/workflows/haskell.yml) Github
Actions workflow file.

# Types of tests

The `cardano-node` repository hosts multiple packages, each with their respective tests.
The tests fall into the following categories:

* Golden tests
* Property tests
* Integration tests

## Golden tests
These are tests which perform some action that produces a file and tests if those files contain the expected contents.

To be a golden test, a copy of the expected output must be checked into `git` as a file.
Such a file is called the golden file.
Tests that do not do a golden file are not golden tests.

It is recommended that the `diffVsGoldenFile` function be used to perform the comparison:

```haskell
diffVsGoldenFile
  :: HasCallStack
  => (MonadIO m, MonadTest m)
  => String   -- ^ Actual content
  -> FilePath -- ^ Reference file
  -> m ()
diffVsGoldenFile actualContent referenceFile = ...
```

This function will compare the `actualContent` with the contents of the `referenceFile`.
If the file does not exist or the contents differ, then the test fails.

There are two circumstances where is convenient to have the golden files created automatically.

* When writing tests for the first time
* When an intended breaking change occurs

To do this defined the `CREATE_GOLDEN_FILES=1` environment variable before running the test.
For example:

```bash
CREATE_GOLDEN_FILES=1 cabal test ...
```

This will only create the golden file if it doesn't already exist.
For the case where you are intentionally introducing a breaking change, delete the existing golden file so that it can be regenerated.

## Property tests

We use [`hedgehog`](https://github.com/hedgehogqa/haskell-hedgehog) for property tests.

These tests typically are defined in functions starting with the prefix `prop_` and have the type `Property`.

## Integration tests

We use [`hedgehog`](https://github.com/hedgehogqa/haskell-hedgehog) and [`hedgehog-extras`](https://github.com/input-output-hk/hedgehog-extras) for integration tests.

The advantage of using `hedgehog` for this purpose is that `hedgehog` provides reports that annotate source code with additional information about the running of the test up to and including the failure.
The annotations can be for things like:

* Values used during the test
* Command line arguments used to run processes
* `stdout` and `stderr` of processes that have been run

A walkthrough of the leadership-schedule integration test can be found in this PR: https://github.com/intersectmbo/cardano-node/pull/5082

# Tips & tricks

## Limiting the scope of executed tests

We're using [`tasty`](https://hackage.haskell.org/package/tasty) as a testing framework in most places.
You can use `TASTY_PATTERN` shell variable to limit the tests which get executed like that:
```bash
TASTY_PATTERN='/golden view alonzo signed yaml/' cabal test cardano-cli
```
In this example, test case name is derived from `hprop_golden_view_alonzo_signed_yaml` name by [`tasty-discover`](https://hackage.haskell.org/package/tasty-discover) plugin.
