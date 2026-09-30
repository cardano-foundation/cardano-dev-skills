# Verification

The two tables below record the milestone 1 and 1b spikes the package is built on. The numbers are those of the spike runs, the current suite is larger.

## Milestone 1 exit criteria

| # | Criterion | Test | Result |
|---|---|---|---|
| 1 | Body slice and Blake2b-256 match Evolution byte for byte | `test/tx-hash.test.ts` | pass |
| 2 | Witness set accepted by Evolution, signature verifies | `test/witness.test.ts` | pass |
| 3 | Mnemonic restore matches CSL, Evolution and the documented vector, signatures byte identical | `test/keys.test.ts`, `test/derive.test.ts` | pass |
| 4 | Evolution merges our witness set without losing foreign witnesses, and a party that already signed counts as coverage | `test/witness.test.ts`, `test/sign-tx.test.ts` | pass |
| 5 | Supported forms only: own key signs, uncovered foreign key refuses, script inputs, script credentials, guardrail scripts and unknown inputs raise a harness diagnosis | `test/sign-tx.test.ts`, `test/sign-tx-governance.test.ts` | pass |
| 6 | submitTx returns the transaction id Evolution computes | `test/submit.test.ts` | pass |

Typecheck (`npm run typecheck`): pass, no errors. All 52 tests pass.

Bundle check: sign-tx.js 91.8 KB, ledger.js 22.5 KB, addresses.js 12.3 KB (no Node, no WASM, no externals).

Decision: the WASM-free core is viable. Milestone 2 builds the CIP-30 surface on it.

## Milestone 1b exit criteria (browser and CSP)

| # | Criterion | Chromium | Firefox | WebKit |
|---|---|---|---|---|
| 1 | Page-native eval blocked under strict CSP, allowed under permissive | pass | pass | pass |
| 2a | addInitScript eval probe agrees with page-native verdict | bypass (strict) | bypass (strict) | pass |
| 2b | page.evaluate eval probe agrees with page-native verdict | bypass (strict) | bypass (strict) | bypass (strict) |
| 2c | securitypolicyviolation observable from an init script | pass | pass | pass |
| 2d | Probe appended to the first-party script via response interception agrees with page-native verdict | pass | pass | pass |
| 3 | Injected stub wallet visible and usable under strict CSP | pass | pass | pass |
| 4 | Late injection (800 ms) missed without retry, found with retry | pass | pass | pass |

Consequence for `doctor --deep`: row 2a is dropped as a probe path, it bypasses the strict CSP in Chromium and Firefox and would report `ok` where the page itself is blocked. Row 2b is dropped as a probe path too, it bypasses the strict CSP in all three engines. Row 2c stays, but only as an observation of the page's own `securitypolicyviolation` events, not as an injected probe. Once the route-appended probe (2d) is active, the violation observer also sees the eval probe's own violation, attributed to the site's own script file, so violation observation and the eval probe must run on separate loads or be filtered by the appended offset, they are not independent evidence in one run. Row 2d becomes the eval probe path, appending the probe to a first-party script through response interception runs it under the page's real CSP and agrees with the page-native verdict everywhere, with the limitation that the probe needs an external first-party script that is not hash-pinned in the policy and carries no SRI `integrity` attribute. On a hash-pinned CSP or an SRI-protected script, appending breaks the page's own script entirely (verified in all three engines), so doctor must detect both cases first and fall back to the static verdict with an explicit reason. Inline-only pages give no verdict at all. Verified to work with `script-src 'self'`, a nonce-only policy and a gzipped response.

Consequence for the fixture: the fixture does not reproduce the CSP trap (row 3), that remains the doctor's job. In the other direction, WebKit does enforce CSP on init-script code (row 2a), so a fixture bundle that contains `eval` or `new Function`, from the core or a dependency, is blocked in WebKit under a strict policy while it keeps working in Chromium and Firefox. The bundle check rejects both.

## Milestone 5: values and collateral

UTxOs with native assets, datum hash, inline datum and reference script encode like Lace, coin-only UTxOs stay byte identical. Asset values and a token spend built with Evolution are checked against CSL in `test/utxo-values.test.ts` and `test/values-oracle.test.ts`.
