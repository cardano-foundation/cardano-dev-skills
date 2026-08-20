# Mesh SDK fixpoint gap column

Probe: `@meshsdk/core` `1.9.1`. Raw installed-API evidence is in
`mesh-sdk.txt`. States use the definitions from probe-1's gap matrix.

| Pattern | Mesh SDK (`@meshsdk/core` `1.9.1`) |
|---|---|
| P1 ordinary fee/change fixpoint | **SUPPORTED** — `complete()` sanitizes outputs, selects inputs, evaluates redeemers, and updates fee/change before returning CBOR. |
| P2 fee-dependent outputs | **EXPRESSIBLE-WITH-EFFORT** — `txOut` takes fixed assets, but completed `meshTxBuilderBody.fee`/CBOR can drive a fresh-builder outer loop. |
| P3 final-transaction observation hook | **NO-HOOK** — internal selection callbacks are not application hooks; the public API returns CBOR only after completion. |
| P4 recursive redeemer/min-UTxO value | **EXPRESSIBLE-WITH-EFFORT** — redeemer methods take fixed data; inspect the completed body, recompute, and reconstruct within an external bound. |

Updated totals across nine surfaces (36 cells): **SUPPORTED 15**,
**EXPRESSIBLE-WITH-EFFORT 10**, **NO-HOOK 7**, **NOT-APPLICABLE 4**,
**NOT-PROBED 0**.
