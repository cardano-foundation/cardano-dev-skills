---
name: balance-fixpoint
description: >-
  Compute recursive values while building Cardano transactions. Use when
  "fee depends on the size", there is a "circular dependency in balancing",
  a "redeemer needs the final output value", the task mentions a "fixpoint",
  or a "balance loop does not converge".
allowed-tools: Read Grep Glob
disallowed-tools: WebFetch WebSearch
---

<!-- Documentation lookup path: ${CLAUDE_SKILL_DIR}/../../docs/sources/ -->

# Fixpoint Transaction Construction

Explain and implement bounded iteration when a Cardano transaction contains a
value that cannot be known until the transaction itself has been assembled.
Treat convergence as a construction technique, not as proof that the resulting
transaction is ledger-valid.

## When to use

- A fee estimate changes the transaction size or the change output.
- Raising an output to min-UTxO changes that output's encoded size.
- A validator ties refunds or other output values to the final fee.
- A datum or redeemer must contain a fee, output value, index, or other value
  read from the balanced transaction.
- Script execution units, witnesses, fees, and change must stabilize together.

## When NOT to use

- For ordinary payments whose SDK already balances fee-independent outputs,
  use its auto-balancing API and the `build-transaction` skill.
- For a transaction that is already stable but fails submission, use
  `debug-transaction`; first identify the actual phase-1 or phase-2 failure.
- Do not add a loop to hide inconsistent value accounting. If no candidate can
  satisfy the equations, return a typed construction error.

## Key principles

1. **Build the real candidate before measuring it.** Fee estimation must see
   the fee field, outputs, change, redeemers, scripts, metadata, reference-script
   bytes, execution units, and a justified witness count.
2. **Make recursive dependencies explicit.** Write down which value depends on
   which part of the final transaction before choosing the loop boundary.
3. **Use monotone or contractive updates where possible.** Retain the greatest
   fee seen, or otherwise detect repeated states, so an encoding-width boundary
   cannot cause silent oscillation.
4. **Bound every loop.** Return a non-convergence error with the last states;
   never spin until a transaction happens to settle.
5. **Validate after convergence.** Run ledger phase-1 checks against resolved
   UTxOs and current protocol parameters. Convergence alone establishes only
   that the chosen state stopped changing.
6. See [shared principles](../shared/PRINCIPLES.md) for cross-cutting safety
   guidance.

## Why the transaction is recursive

Cardano's minimum fee is linear in serialized body size (`a * size + b`) plus
Conway's tiered reference-script charge. That charge prices total reference
script bytes in 25 KiB tiers, escalating each tier by 1.2 from
`minFeeRefScriptCostPerByte`. See the bundled
[ledger decision](../../docs/sources/cardano-ledger/adr/2024-08-14_009-refscripts-fee-change.md).
The final body size is not available at the start of construction:

- Writing the fee can change the CBOR integer width.
- Subtracting the fee from change can change the change output's encoding.
- Adding or altering a change output changes transaction size and therefore fee.
- Witnesses and redeemers contribute to size; changing a redeemer to contain a
  final value can change the witness set that determines the fee.

Min-UTxO has the same shape. `coinsPerUTxOByte` makes the required coin depend
on the encoded output size. Topping up the output can cross a CBOR width boundary,
slightly increasing the size and therefore the required coin again.

Application rules can add another cycle. A validator may require an equation
such as:

```text
sum(refunds) = sum(inputs) - fee - N * tip
```

Here the output values depend on the fee while the fee depends on the encoded
outputs. In the deepest case, a datum or redeemer reads a value produced after
balancing; changing that payload changes the witness bytes, fee, change, and
possibly the value read by the payload.

## Workflow

### Step 1: Draw the dependency cycle

List each recursively computed value and its inputs. Distinguish:

- ordinary fee/change recursion;
- output-local min-UTxO recursion;
- validator equations whose outputs depend on fee;
- values read from the assembled transaction by a datum or redeemer;
- execution units that change after the balanced body changes.

Use the smallest loop that encloses the complete cycle. An output-local
min-UTxO loop need not rebuild an otherwise independent transaction, while a
redeemer that observes a balanced output usually requires reassembling the full
candidate.

### Step 2: Choose the construction surface

Match the loop boundary to what the API actually exposes:

- **Fixed outputs:** use high-level auto-balancing for ordinary payments. Do not
  replace a bounded built-in fee/change loop with application code.
- **Fee-dependent outputs:** require a callback that receives the candidate fee
  and returns replacement outputs. If the API accepts only fixed outputs, build,
  read the fee, recompute outputs, create a fresh builder/body, and repeat within
  your own bound.
- **Final-transaction-dependent data:** require a candidate-transaction callback
  whose result participates in another balance pass. A transaction accessor that
  exists only after completion is not such a hook; use it in an outer bounded
  build → inspect → reconstruct loop.
- **Raw assemblers:** if the API does not balance, own input selection, min-UTxO,
  evaluation, fee/change iteration, witness assumptions, and validation outside
  it. Do not classify serialization success as balancing success.
- **Ledger-level estimation** (`cardano-ledger-core` `1.17.0.0`, `a9e78ae`):
  `estimateMinFeeTx` measures a candidate and pads it with dummy VKey
  witnesses. The caller still owns candidate construction, witness-count
  assumptions, iteration, and final validation. When resolved UTxOs are
  available, prefer the more accurate `calcMinFeeTx`, or
  `calcMinFeeTxNativeScriptWits` for native-script witnesses, so the ledger can
  derive witness requirements instead of trusting a supplied count.
  The reference-implementation Haskell surfaces (`cardano-ledger` and `cardano-api`) deliver new eras
  and hard-fork features first; choose them when era currency outweighs their heavy toolchain cost.

### Step 3: Iterate over complete candidates

Use this general algorithm — illustrative pseudocode, not executable code —
adapting the stable-state comparison to the stack:

```text
state := initial conservative estimates
seen  := empty set

for iteration in 1 .. maxIterations:
    outputs   := computeOutputs(state.fee, state.observedValues)
    candidate := assembleFullTransaction(outputs, state)
    candidate := evaluateAndPatchRedeemers(candidate)
    nextFee   := estimateFeeFromRealSize(candidate, paddedWitnessCount)
    nextObs   := observeRecursiveValues(candidate)
    next      := conservativeUpdate(state, nextFee, nextObs)

    if phaseRelevantState(next) == phaseRelevantState(state):
        return phase1Validate(candidate)
    if phaseRelevantState(next) in seen:
        return NonConvergentCycle(seen, next)

    add next to seen
    state := next

return IterationLimit(lastStates)
```

Rebuild rather than append. In particular, do not add a fresh change output on
each pass. Make insufficient funds, rejected output equations, oscillation, and
iteration exhaustion distinct errors.
If the library re-runs randomized coin selection on every pass, pin and reuse the inputs chosen
on the first pass; otherwise the candidate keeps changing shape and the convergence test never fires.

Convergence is usually fast because a fee delta changes only a few CBOR bytes.
Multiplying those bytes by the protocol's fee-per-byte coefficient produces a
much smaller next delta: locally the update behaves like a contraction. This is
an engineering expectation, not permission to omit the bound. With the input and
reference-input sets fixed, the tiered reference-script charge is constant
across these iterations, so it does not weaken that contraction argument.

### Step 4: Apply the verified API branch

Use the bundled [gap matrix](../../docs/sources/cardano-library-conformance/balance-fixpoint/static/gap-matrix.md)
and its [Mesh extension](../../docs/sources/cardano-library-conformance/balance-fixpoint/static/gap-matrix-mesh.md)
to select a capability branch. Versions and commits live in those conformance
pages and are re-checked by their runnable evidence.

- For native in-loop hooks, keep recursion inside the builder and preserve its
  bound. See the worked pages for [Cardano Tx Tools](../../docs/sources/cardano-library-conformance/balance-fixpoint/examples/tx-tools.md),
  [cardano-client-lib](../../docs/sources/cardano-library-conformance/balance-fixpoint/examples/ccl.md),
  and [Scalus](../../docs/sources/cardano-library-conformance/balance-fixpoint/examples/scalus.md).
- For fixed-body or post-build access, own a bounded fresh-builder loop: inspect
  the candidate, recompute dependent outputs or redeemers, and reconstruct. See
  [Evolution SDK](../../docs/sources/cardano-library-conformance/balance-fixpoint/examples/evolution.md),
  [CSL](../../docs/sources/cardano-library-conformance/balance-fixpoint/examples/csl.md),
  and [cardano-api](../../docs/sources/cardano-library-conformance/balance-fixpoint/examples/cardano-api.md).
  Mesh follows this branch but has no worked example in the current conformance
  slice.
- If only fixed command inputs exist, stabilize recursive values in another
  construction layer before invoking the command.
- If the API is a raw assembler, own selection, evaluation, fee/change,
  witnesses, and validation outside it.

### Step 5: Validate the stable transaction

After the loop reports stability:

1. Reassemble once from the retained stable state if the loop's candidate was
   measured before the last update.
2. Confirm value conservation, min-UTxO, fee sufficiency, maximum size,
   collateral arithmetic, validity interval, and required witnesses using
   ledger phase-1 validation.
3. For scripts, evaluate phase 2 against the same final body and execution
   units; if patching execution units changes size or fee, return to the outer
   loop.
4. Report the number of iterations and final recursive values for diagnosis.

If validation changes any measured input, the state was not actually final.
Iterate again within the same bound or return a structured failure.

## References

- [Balance-fixpoint capability matrix](../../docs/sources/cardano-library-conformance/balance-fixpoint/static/gap-matrix.md)
- [Mesh capability extension](../../docs/sources/cardano-library-conformance/balance-fixpoint/static/gap-matrix-mesh.md)
- [Worked conformance examples](../../docs/sources/cardano-library-conformance/balance-fixpoint/examples/README.md)
- [Cardano Tx Tools overview](../../docs/sources/cardano-tx-tools/README.md)
- [Evolution SDK script evaluation cycle](../../docs/sources/evolution-sdk/architecture/script-evaluation.mdx)
- [Evolution SDK transaction flow](../../docs/sources/evolution-sdk/architecture/transaction-flow.mdx)
- [Evolution SDK min-UTxO output sizing](../../docs/sources/evolution-sdk/architecture/unfrack-optimization.mdx)
- [cardano-cli automatically balanced build](../../docs/sources/cardano-node-wiki/reference/cardano-node-cli-reference.md)
- [Cardano API auto-balance strategy](../../docs/sources/cardano-node-wiki/ADR-016-cardano-api-new-txbodycontent.md)
- [Conway reference-script fee decision](../../docs/sources/cardano-ledger/adr/2024-08-14_009-refscripts-fee-change.md)
- [Shared Cardano development principles](../shared/PRINCIPLES.md)
