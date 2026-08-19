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

Survey the available stack rather than assuming one interface:

- **High-level auto-balancing:** Prefer it when requested outputs are
  fee-independent. SDKs normally perform coin selection, change creation, fee
  calculation, and any required retries internally. Evolution SDK documents an
  explicit balance/evaluation/fee cycle and a ten-attempt limit in
  `${CLAUDE_SKILL_DIR}/../../docs/sources/evolution-sdk/architecture/script-evaluation.mdx`.
- **Ledger-level estimation:** `cardano-ledger`'s `estimateMinFeeTx` measures a
  candidate transaction and pads it with the requested number of dummy VKey
  witnesses. The caller still owns candidate construction, witness-count
  assumptions, iteration, and final validation. When resolved UTxOs are
  available, prefer the more accurate `calcMinFeeTx`, or
  `calcMinFeeTxNativeScriptWits` for native-script witnesses, so the ledger can
  derive witness requirements instead of trusting a supplied count.
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
an engineering expectation, not permission to omit the bound. With the
reference-input set fixed, the tiered reference-script charge is constant across
these iterations, so it does not weaken that contraction argument.

### Step 4: Recognize the pattern in real implementations

Compare implementations by which part of the cycle they expose. The bundled
[Cardano Tx Tools overview](../../docs/sources/cardano-tx-tools/README.md)
documents separate build, balance, evaluate, and phase-1 validation modules.
The upstream source details mentioned below are **not bundled here**; verify
them in a current upstream checkout before relying on identifiers or types.

1. **Ordinary fee/change fixpoint.** Evolution SDK documents iterative base-fee
   calculation followed by balance. Cardano API's auto-balance design likewise
   documents a multi-step strategy that estimates with maximum values and then
   recalculates; `cardano-cli transaction build` exposes that style as an
   automatically balanced interface. These keep the loop behind a high-level
   API. In the current Cardano Tx Tools upstream repository, the balance module
   instead makes the loop visible: it starts from zero fee, raises the retained
   fee monotonically, and stops at a bounded stable candidate. Its witness count
   is estimated from inputs and required signers and can under-count a
   native-script multisig, so callers must validate the result.

2. **Fee-dependent outputs.** Evolution SDK's documented
   balance/evaluation/fee cycle rebuilds after validators observe a changed
   transaction. A custom builder must add the application-specific step:
   recompute outputs from the current fee before each assembly. The current
   Cardano Tx Tools upstream balance module exposes such an output-producing
   callback, directly modeling fee-dependent refunds. This capability is not
   asserted by its bundled README, so check the current source before adopting
   that API.

3. **Final-transaction observations.** High-level auto-balancers generally hide
   their loop; when they provide no final-transaction observation hook, place a
   bounded loop around the builder. The current Cardano Tx Tools upstream build
   module has a first-class provisional-versus-stable observation instruction
   and reinterprets the program over successive candidates. Treat those names
   and types as upstream details, not as bundled API documentation.

4. **Recursive redeemer/min-UTxO value.** Evolution SDK documents CBOR-accurate
   min-UTxO calculation during output/change construction. The current Cardano
   Tx Tools upstream test suite goes further: under its non-balancing `draft`
   path, a test pins the min-UTxO → final-output observation → redeemer leg by
   checking that the redeemer carries the compensated output coin. Its full
   `build` path, not that test, closes the outer fee and execution-unit loop.

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
- [Evolution SDK transaction flow](../../docs/sources/evolution-sdk/architecture/transaction-flow.mdx)
- [Evolution SDK min-UTxO output sizing](../../docs/sources/evolution-sdk/architecture/unfrack-optimization.mdx)
- [cardano-cli automatically balanced build](../../docs/sources/cardano-node-wiki/reference/cardano-node-cli-reference.md)
- [Cardano API auto-balance strategy](../../docs/sources/cardano-node-wiki/ADR-016-cardano-api-new-txbodycontent.md)
- [Conway reference-script fee decision](../../docs/sources/cardano-ledger/adr/2024-08-14_009-refscripts-fee-change.md)
- [Shared Cardano development principles](../shared/PRINCIPLES.md)
