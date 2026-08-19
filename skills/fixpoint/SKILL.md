---
name: fixpoint
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
   bytes, execution units, and correctly padded witness count.
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

Cardano's minimum fee is a linear function of serialized transaction size, but
the final size is not available at the start of construction:

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

Survey the available stack rather than assuming one interface:

- **High-level auto-balancing:** Prefer it when requested outputs are
  fee-independent. SDKs normally perform coin selection, change creation, fee
  calculation, and any required retries internally. Evolution SDK documents an
  explicit balance/evaluation/fee cycle and a ten-attempt limit in
  `${CLAUDE_SKILL_DIR}/../../docs/sources/evolution-sdk/architecture/script-evaluation.mdx`.
- **Ledger-level estimation:** `cardano-ledger`'s `estimateMinFeeTx` measures a
  candidate transaction and pads it with the requested number of dummy VKey
  witnesses. The caller still owns candidate construction, witness-count
  assumptions, iteration, and final validation.
- **Explicit fixpoint:** Use a visible loop or a `Peek`/`Convergence`-style
  builder when a validator equation, datum, or redeemer depends on the final
  transaction. This exposes the recursive value to application code and makes
  failure to converge reportable.

The registered Cardano Tx Tools source describes its `Cardano.Tx.Build`,
`Cardano.Tx.Balance`, `Cardano.Tx.Evaluate`, and phase-1 validation surfaces in
`${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-tx-tools/README.md`.

### Step 3: Iterate over complete candidates

Use this general algorithm, adapting the stable-state comparison to the stack:

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

Convergence is usually fast because a fee delta changes only a few CBOR bytes.
Multiplying those bytes by the protocol's fee-per-byte coefficient produces a
much smaller next delta: locally the update behaves like a contraction. This is
an engineering expectation, not permission to omit the bound.

### Step 4: Recognize the Cardano Tx Tools examples

Use these examples as patterns, not as a requirement to adopt that library:

1. **Ordinary fee/change fixpoint — `Cardano.Tx.Balance.balanceTx`.**
   `src-tx-build/Cardano/Tx/Balance.hs` constructs the full candidate for the
   current fee, including change and collateral fields, calls
   `estimateMinFeeTx`, and retries from zero until the estimate no longer
   exceeds the retained fee. It assumes the correct key-witness count and
   reference-script bytes and returns `FeeNotConverged` after a bounded loop.

2. **Fee-dependent outputs — `balanceFeeLoop`.** The same module accepts
   `mkOutputs :: Coin -> Either String (StrictSeq TxOut)`. Each round computes
   outputs from the current fee, installs both outputs and fee into a complete
   template, re-estimates, and retries. This directly models conservation rules
   such as fee-dependent refunds without pretending outputs are fixed.

3. **Final-transaction observations — `Peek` and `Convergence`.**
   `src-tx-build/Cardano/Tx/Build.hs` defines
   `Peek :: (ConwayTx -> Convergence a) -> TxInstr q e a`, with
   `Iterate a` meaning "use this provisional value and run again" and `Ok a`
   meaning the observation is stable. The builder reinterprets the program over
   successive candidates, making a value read from the final transaction a
   first-class dependency rather than an out-of-band callback.

4. **Recursive redeemer/min-UTxO value.** In
   `test/Cardano/Tx/Build/MinUtxoSpec.hs`, `payTo` creates a token-bearing output,
   `peek (observeTxOutCoin ix)` reads its post-compensation coin, and
   `spendScript` places that coin in a redeemer. The test checks that the final
   redeemer equals the coin in the final output. This covers the full cycle:
   min-UTxO changes the output, the observation changes the redeemer, and the
   redeemer participates in the transaction whose final shape is observed.

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

- [Cardano Tx Tools overview](../../docs/sources/cardano-tx-tools/README.md)
- [Evolution SDK script evaluation cycle](../../docs/sources/evolution-sdk/architecture/script-evaluation.mdx)
- [Shared Cardano development principles](../shared/PRINCIPLES.md)
