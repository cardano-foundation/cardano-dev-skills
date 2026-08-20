# Verified fixpoint gap matrix

States mean: `SUPPORTED` is native to the surface; `EXPRESSIBLE-WITH-EFFORT`
requires caller-owned composition or a bounded rebuild loop; `NO-HOOK` means the
inspected balancing surface exposes no hook for that pattern; `NOT-APPLICABLE`
means the API is deliberately a raw assembler rather than a balancing surface;
`NOT-PROBED` means no evidence was obtained. Raw probe evidence is in the
adjacent handoff files.

| Pattern | Cardano Tx Tools (`7bfe95b`) | Evolution SDK (`@evolution-sdk/evolution` `0.5.12`) | `cardano-cli transaction build` (`11.0.0.0`) | `cardano-api` auto-balance (`10.19.1.0`) |
|---|---|---|---|---|
| P1 ordinary fee/change fixpoint | **SUPPORTED** — unit check passed; `balanceTx` has a bounded loop and `FeeNotConverged`. | **SUPPORTED** — `build()` exposes selection, change, fee, balance, and evaluation phases. | **SUPPORTED** — `transaction build` accepts fixed outputs plus a change address and produces an automatically balanced body. | **SUPPORTED** — `makeTransactionBodyAutoBalance` evaluates, fees, and balances a fixed `TxBodyContent`. |
| P2 fee-dependent outputs | **SUPPORTED** — `balanceFeeLoop` accepts `Coin -> ... TxOut` and iterates it. | **EXPRESSIBLE-WITH-EFFORT** — `payToAddress` takes fixed assets, but post-build `estimateFee()` plus fresh independent `build()` calls permit an outer loop. | **NO-HOOK** — `--tx-out ADDRESS VALUE` is fixed; the flags expose no recomputation callback. | **EXPRESSIBLE-WITH-EFFORT** — the input body is fixed and the balanced result is inspectable, so reconstruct `TxBodyContent` and call again. |
| P3 final-transaction observation hook | **SUPPORTED** — `Peek (ConwayTx -> Convergence a)` observes candidates and signals `Iterate`/`Ok`. | **NO-HOOK** — `toTransaction()` is only on the completed result; internal `PhaseContext` is not a public observation/re-entry callback. | **NO-HOOK** — `--out-file` writes the completed body; no callback or re-entry flag exists. | **NO-HOOK** — the signature accepts fixed content and returns `BalancedTxBody`; it has no candidate callback. |
| P4 recursive redeemer/min-UTxO value | **SUPPORTED** — passing MinUtxoSpec proves `payTo -> peek observeTxOutCoin -> spendScript`; full `build` closes fee/ExUnits recursion. | **EXPRESSIBLE-WITH-EFFORT** — redeemer callbacks see only indexed inputs; inspect the built tx and reconstruct in an outer loop for final-output values. | **NO-HOOK** — redeemer values/files are fixed command inputs and cannot read the body being built. | **EXPRESSIBLE-WITH-EFFORT** — provide a recomputed fixed redeemer in a fresh `TxBodyContent` on each bounded outer iteration. |

| Pattern | Cardano Serialization Lib (`17.0.0`) | Pallas txbuilder (`1.1.1`) | cardano-client-lib (`0.8.0-pre5`) | Scalus (`1.0.0`) |
|---|---|---|---|---|
| P1 ordinary fee/change fixpoint | **SUPPORTED** — `add_change_if_needed` computes fee and change after fixed body fields are supplied. | **NOT-APPLICABLE** — `build_conway_raw` explicitly performs no balancing or fee/ExUnits calculation. | **SUPPORTED** — `balanceTx` composes fee calculation and change adjustment. | **SUPPORTED** — `complete` and bounded `balanceFeeAndChangeWithTokens` select inputs, calculate fee, and adjust change. |
| P2 fee-dependent outputs | **EXPRESSIBLE-WITH-EFFORT** — mutable `set_fee`, `min_fee`, and `build` permit an external bounded rebuild loop, but no output callback exists. | **NOT-APPLICABLE** — raw construction requires the caller to provide the whole balancing algorithm. | **SUPPORTED** — `feeCalculator(..., UpdateOutputFunction)` passes the fee and mutable output list to application code. | **SUPPORTED** — the internal balance loop invokes `DiffHandler(Value, Transaction)` for every fee-bearing candidate. |
| P3 final-transaction observation hook | **NO-HOOK** — `build` returns a body/transaction but no during-balance observation or re-entry callback exists. | **NOT-APPLICABLE** — no balancing loop exists to observe or re-enter. | **SUPPORTED** — any composable `TxBuilder` lambda receives the assembled mutable `Transaction` and context. | **SUPPORTED** — `DiffHandler` receives the candidate `Transaction` inside the bounded balance loop and returns the next candidate. |
| P4 recursive redeemer/min-UTxO value | **EXPRESSIBLE-WITH-EFFORT** — rebuild after inspecting `build_tx`, replacing the fixed redeemer/output and fee on each bounded pass. | **NOT-APPLICABLE** — fixed raw redeemers and outputs are inputs to an assembler, not a recursive builder. | **EXPRESSIBLE-WITH-EFFORT** — compose a transaction-transforming lambda with explicit bounded rebalance passes; no convergence abstraction was found. | **EXPRESSIBLE-WITH-EFFORT** — delayed redeemers run before min-UTxO/fee balancing; recompute through a custom `DiffHandler` during its bounded loop. |

Counts: **SUPPORTED 14**, **EXPRESSIBLE-WITH-EFFORT 8**, **NO-HOOK 6**,
**NOT-APPLICABLE 4**, **NOT-PROBED 0** (32 cells total).

Cardano Tx Tools E2E checks were skipped because they require a live node; its
pure unit check, including BuildSpec and MinUtxoSpec, completed successfully.
Evolution P1 was established by installed API inspection because the release did
not include a provider-free payment fixture suitable for a small runtime probe.
