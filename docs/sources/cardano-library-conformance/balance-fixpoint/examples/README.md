# Worked outer-loop examples

Use a bounded caller-owned loop when an output depends on the eventual fee and the
library cannot observe and rewrite that output during its own balancing pass:

1. Pin protocol parameters and the synthetic input set for every pass.
2. Start from a fee guess, derive the fee-dependent output, and allocate a fresh builder.
3. Build the candidate, inspect its required fee, and repeat with that fee as the next guess.
4. Stop only when the fee is unchanged; fail with a distinct non-convergence error at the bound.
5. After convergence, validate fee sufficiency and value conservation.

Together these examples cover all four capability classes: ordinary balancing
(P1), fee-dependent outputs (P2), candidate observation/re-entry (P3), and
candidate-derived redeemer or min-UTxO data (P4). Haskell examples live in the
separate heavy tier; `nix flake check` remains the fast default gate.

Each page below contains the complete source for its stack, including the
reusable bounded function and the example entry point that calls it:

- [Cardano Tx Tools](tx-tools.md)
- [cardano-api](cardano-api.md)
- [Cardano Serialization Lib](csl.md)
- [Evolution SDK](evolution.md)
- [cardano-client-lib](ccl.md)
- [Scalus](scalus.md)

## Cardano Tx Tools

[`tx-tools/Main.hs`](https://github.com/lambdasistemi/cardano-lib-conformance/blob/init/balance-fixpoint/examples/tx-tools/Main.hs) is a standalone offline GHC 9.12.3
program with synthetic protocol parameters and UTxO references. It runs the
native `balanceFeeLoop` fee-dependent refund hook, then uses `draft`, `peek`,
and `Convergence` to observe the final output coin and encode it into a spending
redeemer. It asserts bounded convergence and conservation and prints the pass
counts, complementing the P2, P3, and P4 source-evidence cells.

## cardano-api 10.19.1.0

[`cardano-api/Main.hs`](https://github.com/lambdasistemi/cardano-lib-conformance/blob/init/balance-fixpoint/examples/cardano-api/Main.hs) rebuilds fresh `TxBodyContent`
around `makeTransactionBodyAutoBalance` in an eight-pass caller-owned loop. The
recipient output depends on the previously observed fee; each real candidate
uses a synthetic UTxO and protocol-parameter fixture and is checked for value
conservation. This is the worked external-loop counterpart to cardano-api P2–P4.

Both are built with the upstream unit check as one heavy target:

```sh
nix build --accept-flake-config .#heavy-checks
```

## CSL 17.0.0

[`csl/outer_loop.rs`](csl/outer_loop.rs) is a complete offline Rust program. It
uses CSL's `TransactionBuilder`, `set_fee`, `min_fee`, and `build_tx` against a
fixed protocol-parameter fixture and synthetic UTxO. The runtime check also
proves that a one-pass broken variant is rejected. This complements CSL matrix
cells P2–P4, where the primitives exist but the candidate callback does not.

```sh
nix build .#checks.x86_64-linux.example-csl-outer-loop
```

## Evolution SDK 0.5.12

[`evolution/outer-loop.ts`](evolution/outer-loop.ts) expresses the same loop with
the public `makeTxBuilder`, `collectFrom`, `payToAddress`, `build`, `estimateFee`,
and `toTransaction` surface. The check typechecks it with `tsc` against the
pinned npm tarball; it does not execute because the release's Effect/runtime
dependency tree is not included in this evidence bundle. It complements P2–P4:
fresh builds and candidate inspection exist, while the evaluator returns only
execution units.

```sh
nix build .#checks.x86_64-linux.example-evolution-outer-loop
```

## cardano-client-lib 0.7.2

[`ccl/OuterLoop.java`](ccl/OuterLoop.java) composes
`feeCalculator(..., UpdateOutputFunction)` with `balanceTx`, places that native
hook inside a caller-owned eight-pass loop, and runs entirely offline from
fixed-output Maven jars. Every pass serializes a real CCL transaction, so the
fee guess is based on the candidate's actual byte length. The program rejects a
one-pass loop and checks fee observation and value conservation. This
complements P2–P4 and makes the caller-owned bound explicit outside CCL's
internal adjustment retries.

```sh
nix build .#checks.x86_64-linux.example-ccl-native-hook
```

## Scalus 1.0.0

[`scalus/OuterLoop.scala`](scalus/OuterLoop.scala) supplies a typed `DiffHandler`
and a caller-owned bound around a fresh-candidate transform. It records the
ordering constraint that delayed datum/redeemer builders run before min-UTxO
and balancing. The check is compile-only: the published ledger POM has eight
direct runtime dependencies plus enough transitive artifacts to exceed the
ten-jar direct-pinning cutoff. This complements Scalus P2–P4.

```sh
nix build .#checks.x86_64-linux.example-scalus-diffhandler
```

Mesh was dropped at the bottom of the timebox priority list. Its static P1–P4
checks remain unchanged; there is no worked Mesh example in this slice.
