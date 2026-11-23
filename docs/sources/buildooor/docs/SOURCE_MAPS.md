# Source maps

When a script fails while a transaction is built, buildooor tells where it failed in the
script's source: file, line, column, and the function calls that were open.

## Setup

Compilers write a source map next to the compiled script; Pebble writes `out/out.flat.map`
next to `out/out.flat` (the `sourceMap` option, on by default). Pass the maps to the builder:

```ts
import { TxBuilder } from "@harmoniclabs/buildooor";

const txBuilder = new TxBuilder( protocolParameters, genesisInfos, {
    sourceMaps: [
        readFileSync( "escrow/out/out.flat.map", "utf8" ),   // JSON text
        vestingMap                                          // or parsed
    ]
});

// or later
txBuilder.addSourceMap( otherMap );
```

A map matches its script whether or not parameters were applied to it (the map describes the
script as compiled; buildooor finds it under the applied parameters), so a parameterized
contract needs one map however it is instantiated. An invalid map is rejected when it is given.

## What you get

Without `onScriptInvalid`, a failing script throws; the error gains the location:

```text
script '0d5b...' consumed with Spend redeemer and index '0'
failed at src/index.pebble:42:9
    assert tx.signedBy( seller ) else "missing seller signature";
    ^^^^^^
    at refund (src/index.pebble:42:9)
    at spend (src/index.pebble:12:5)

called with data arguments:
...
```

The failing line is shown when the map includes the sources (Pebble: `sourceMapContent: true`).

With callbacks, the location comes as a trailing argument, `undefined` when no map matches:

```ts
txBuilder.buildSync( args, {
    onScriptInvalid: ( rdmr, logs, callArgs, tx, failure ) => {
        console.log( failure?.location );   // { source, line, column, endLine, endColumn }
        console.log( failure?.stack );      // [ { functionName, location }, ... ], innermost first
    }
});
```

`onScriptResult` receives it as its last argument for failed scripts, and each result of
`validatePhaseTwoVerbose` has a `failure` field.

### Scripts compiled without their traces

Pebble's `removeTraces` (on in its production options) compiles a script without its `trace`
statements and `assert`/`fail` messages, and keeps them in the source map. A failing script with
such a map gets its traces back: the error's `script execution logs` and the `logs` passed to
`onScriptInvalid` are what the script compiled with its traces would have logged, in order
(`assert ... else "missing seller signature"` prints its message again). Successful scripts are
not evaluated again, so their logs stay those of the script itself.

## Saving failed evaluations, to debug them

With `saveFailedEvaluations`, every script that fails is saved, so a debugger can run it again,
statement by statement, forwards and backwards:

```ts
const txBuilder = new TxBuilder( protocolParameters, genesisInfos, {
    sourceMaps: [ readFileSync( "out/out.flat.map", "utf8" ) ],
    saveFailedEvaluations: "./failed",   // a directory (Node.js), or a function given each one
});
```

The thrown error names the file:

```text
script '470f…' consumed with Spend redeemer and index '0'
failed at src/index.pebble:50:13
    at TwoPartyEscrow (src/index.pebble:50:13)
evaluation saved to ./failed/spend-0-470f22571c405a0a.json (replay it: pebble debug --eval ./failed/spend-0-470f22571c405a0a.json)
```

Files are named `<purpose>-<redeemer index>-<script hash, 16 digits>.json`, so running the same
failing build again replaces them. Each holds the script as the transaction carries it, its
arguments, the cost model and the budget (`@harmoniclabs/plutus-machine`'s saved evaluation
format), and the location when a map matched. From the Pebble project the script comes from:

```sh
pebble debug --eval ./failed/spend-0-470f22571c405a0a.json
```

prints the evaluation statement by statement, with the variables' values; in VS Code, a `pebble`
launch configuration with `"evaluation"` steps through it. A function instead of a directory
receives each evaluation as JSON (`SavedEvaluationJson`), for browsers or custom storage.
Saving never changes the build: the error is thrown as before.

## Cost

Nothing when a script succeeds, and nothing without source maps. A failing script with a
matching map is evaluated a second time, on a separate machine with the same cost model and
budget, to follow it; the builder's own evaluation, fees and execution units are unchanged.

The map format is `@harmoniclabs/plutus-machine`'s (version 1); any compiler can emit it.
