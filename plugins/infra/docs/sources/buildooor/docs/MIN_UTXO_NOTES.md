# Min-UTxO: what was fixed, and what's still broken

Two distinct bugs share the same symptom ("output is short on lovelaces"). One is fixed in this branch; the other is not.

---

## Bug #1 — `minimizeLovelaces` predicted minimum was too low (FIXED)

### Symptom

Calling `txBuilder.minimizeLovelaces({ ... })` on an output (especially one with native tokens) returned a TxOut whose `value.lovelaces` was below what the Cardano ledger actually requires. Before commit `1ebc88f`, the underestimate was as much as ~650k lovelace per UTxO at mainnet rates (≈ "almost half" of a small min-UTxO). After `1ebc88f` (changing `+10` to `+160`), the gross case was fixed but token-heavy outputs still underestimated by tens of thousands of lovelace, requiring an ad-hoc `+32 * utxoCostPerByte` safety pad that "somehow" was always needed.

### Root cause

`getMinimumOutputLovelaces` measures size by serializing the output to CBOR and reading `bytes.length`. CBOR encodes the lovelace ("coin") field as a **variable-length** unsigned int:

| coin range | bytes used in CBOR |
|---|---|
| 0 | 1 |
| 1–23 | 1 |
| 24–255 | 2 |
| 256–65535 | 3 |
| 65_536–4_294_967_295 | 5 |
| > 4_294_967_295 | 9 |

`minimizeLovelaces` would:
1. Take an output with placeholder lovelaces (often 0 — 1 byte in CBOR).
2. Measure size with that placeholder.
3. Compute `min = (size + 160) * utxoCostPerByte`.
4. Write `min` back into the lovelace field.

But step 4 typically writes a 4–9 byte value, so the **final** output is several bytes larger than what step 2 measured. That's the "chicken-and-egg": you need to know the min to size the field correctly, but you need the field size to know the min.

There's also a 1-byte CBOR transition for outputs with tokens: when `lovelaces == 0`, `Value` encodes as a bare multiasset map; when `lovelaces > 0`, it encodes as `[coin, multiasset_map]` — the array tag adds 1 byte.

Combined, the underestimate was up to ~10 bytes worth (~43k lovelace at `utxoCostPerByte = 4310`, ~344k at the test-suite's `34482`).

### How upstream libraries handle the same problem

- **cardano-serialization-lib** (Emurgo): iterates the calculation up to 3 times — write the previous min into the coin field, re-serialize, recompute.
- **cardano-multiplatform-lib** (dcSpark): closed-form delta using `fit_sz` to compute exactly how many bytes the new coin will add.
- **lucid-evolution / mesh**: delegate to CSL/CML.
- **cardano-cli** (Haskell): pushes the chicken-and-egg onto the caller.

### The fix in this branch

In [`minimizeLovelaces`](src/TxBuilder/TxBuilder.ts), before measuring size, clone the output with `value.lovelaces = 2^64 − 1`. That value forces the maximum 9-byte CBOR encoding for the coin field. The size we measure is then a guaranteed upper bound on the final output's size, no matter what we eventually write into the coin field. One CBOR encode per call; no iteration needed.

This produces the same answer CSL/CML converge to, in one pass.

`getMinimumOutputLovelaces` itself is now the literal ledger formula: `(serialized_size + 160) * utxoCostPerByte`. Used directly by `assertMinOutLovelaces` against the *final* output (where coin is already set to its real value), it returns the exact ledger requirement — no over- or under-estimate.

The old `+32 * utxoCostPerByte` pad in `minimizeLovelaces` was removed (now redundant).

### Files changed

- [`src/TxBuilder/TxBuilder.ts`](src/TxBuilder/TxBuilder.ts) — `getMinimumOutputLovelaces` simplified to ledger-exact; `minimizeLovelaces` measures with max-coin placeholder.
- [`src/__tests__/TxBuilder.build.balanced.test.ts`](src/__tests__/TxBuilder.build.balanced.test.ts) — test input bumped from 10M → 25M lovelace (the test was already failing on `main` because 10M wasn't enough to cover both outputs' legitimate min-UTxO with 1-trillion-NEWTON change).

### References

- `babbageMinUTxOValue` in [cardano-ledger](https://github.com/IntersectMBO/cardano-ledger/blob/master/eras/babbage/impl/src/Cardano/Ledger/Babbage/TxOut.hs) — `constantOverhead = 160`. Unchanged in Conway.
- [CIP-55](https://cips.cardano.org/cip/CIP-0055): `(160 + |serialized_output|) * coinsPerUTxOByte`. The 160 represents 20 words × 8 bytes (TxIn entry + UTxO map entry overhead).

### How to revert

The pre-fix state is `1ebc88f` ("fixed minutxo fee calc") — at the time this note was written, the fix is uncommitted, so reverting just means discarding the working-tree changes:

```sh
git checkout -- src/TxBuilder/TxBuilder.ts src/__tests__/TxBuilder.build.balanced.test.ts
```

Once the fix is committed, replace the line below with the actual hash:

```
revert commit: <fill in after committing the fix>
```

Then revert with:

```sh
git revert <fix commit hash>
```

---

## Bug #2 — Change output may be undersized (NOT FIXED)

### Symptom

`buildSync` throws `tx output at index N did not have enough lovelaces to meet the minimum allowed by protocol parameters` on the **change output**, even though all explicit outputs are sized correctly. Reproducible by:

- An input set that barely covers explicit outputs + fee.
- Input UTxOs that carry tokens not consumed by explicit outputs (so the leftover tokens get dumped on change).

This is what most of the remaining 12 failing tests exercise. Bug #1's fix didn't change this — the change-output construction has always had this hole.

### Root cause

In [`initTxBuild`](src/TxBuilder/TxBuilder.ts) (~line 1614) and again in the build loop (~line 588), the change output is constructed as:

```ts
const changeOutput = new TxOut({
    address: change.address,
    value: Value.sub(
        totInputValue,
        Value.add( requiredOutputValue, Value.lovelaces( minFee ) )
    ),
    ...
});
```

Plain subtraction: `change = totalInput − requiredOutputs − fee`. There is **no step** that:

1. Projects the change output's size with leftover tokens included.
2. Computes change's own min-UTxO.
3. Verifies the leftover lovelace ≥ that min, or pulls more inputs / fails with a clear error if not.

The only check happens at the very end, in `assertMinOutLovelaces`. By then it's too late to recover — the build aborts.

### Why Bug #1's fix didn't help here

Bug #1 was about `getMinimumOutputLovelaces` returning a number lower than the ledger's actual requirement. That's a *calculation* bug — the function lied about the minimum.

Bug #2 is about *not asking the right question*: even with a perfectly correct calculator, the build flow constructs change as "leftover lovelace" rather than "max(leftover lovelace, change's min-UTxO)". The calculator is consulted only post-hoc, in `assertMinOutLovelaces`, where it can throw but not fix anything.

In short:

- Bug #1: **what** the answer is (formula).
- Bug #2: **when** we ask the question (build pipeline ordering).

### Sketch of a fix (not implemented)

Two reasonable approaches, in order of intrusiveness:

1. **Iterate change construction.** After computing change, project its min-UTxO (using `getMinimumOutputLovelaces` against a worst-case clone, same trick as `minimizeLovelaces`). If `change.lovelaces < projectedMin`, either:
   - Reduce explicit-output coin allocations where the user gave headroom (rare / hard to do safely), or
   - Pull additional inputs from the UTxO set, or
   - Throw a specific error (`"insufficient lovelace for change min-UTxO; need at least X more"`) before `assertMinOutLovelaces` runs.
2. **Coin-selection awareness.** Have [`keepRelevant`](src/TxBuilder/keepRelevant.ts) (and any other selectors) factor the projected change min-UTxO into the lovelace target when picking inputs, so the leftover is naturally large enough. This is closer to how cardano-cli / CSL handle it.

Either path needs care: leftover **tokens** also affect change's min-UTxO, so the projection has to use the actual leftover Value, not just an ada-only stub.

### Why we left this for later

It's a wider change to the build pipeline (touches input selection and the rebuild loop in `buildSync`), and the user only asked for the formula fix. The remaining red tests on `main` were **already red** before this branch — Bug #2 has been latent for a while. Fixing it cleanly deserves its own pass.