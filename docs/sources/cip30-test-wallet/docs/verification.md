# Verification

The first two tables record the checks the signing core and the browser injection were first built on. The sections after them follow the features added since.

## Signing core

| # | Criterion | Test | Result |
|---|---|---|---|
| 1 | Body slice and Blake2b-256 match Evolution byte for byte | `test/tx-hash.test.ts` | pass |
| 2 | Witness set accepted by Evolution, signature verifies | `test/witness.test.ts` | pass |
| 3 | Mnemonic restore matches CSL, Evolution and the documented vector, signatures byte identical | `test/keys.test.ts`, `test/derive.test.ts` | pass |
| 4 | Evolution merges our witness set without losing foreign witnesses, and a party that already signed counts as coverage | `test/witness.test.ts`, `test/sign-tx.test.ts` | pass |
| 5 | Supported forms only: own key signs, uncovered foreign key refuses, unknown inputs raise a harness diagnosis. Script inputs, script credentials and guardrail scripts raised one too until 0.7.0, which signs them, see [Scripts](#scripts). | `test/sign-tx.test.ts`, `test/sign-tx-governance.test.ts` | pass |
| 6 | submitTx returns the transaction id Evolution computes | `test/submit.test.ts` | pass |

The bundle check (`npm run bundle:check`) confirms on every change that the core and the page bundle contain no Node code, no WASM and no externals. These checks showed that the signing core works without WASM, the CIP-30 surface is built on it.

## Browser and CSP

| # | Criterion | Chromium | Firefox | WebKit |
|---|---|---|---|---|
| 1 | Page-native eval blocked under strict CSP, allowed under permissive | pass | pass | pass |
| 2a | addInitScript eval probe agrees with page-native verdict | bypass (strict) | bypass (strict) | pass |
| 2b | page.evaluate eval probe agrees with page-native verdict | bypass (strict) | bypass (strict) | bypass (strict) |
| 2c | securitypolicyviolation observable from an init script | pass | pass | pass |
| 2d | Probe appended to the first-party script via response interception agrees with page-native verdict | pass | pass | pass |
| 3 | The injected test wallet visible and usable under strict CSP (`fixture.spec.ts`, `acceptance.spec.ts`) | pass | pass | pass |
| 4 | Late injection (800 ms) missed without retry, found with retry (`doctor.spec.ts`, `acceptance.spec.ts`) | pass | pass | pass |

Consequence for `doctor --deep`: row 2a is dropped as a probe path, it bypasses the strict CSP in Chromium and Firefox and would report `ok` where the page itself is blocked. Row 2b is dropped as a probe path too, it bypasses the strict CSP in all three engines. Row 2c stays, but only as an observation of the page's own `securitypolicyviolation` events, not as an injected probe. Once the route-appended probe (2d) is active, the violation observer also sees the eval probe's own violation, attributed to the site's own script file, so violation observation and the eval probe must run on separate loads or be filtered by the appended offset, they are not independent evidence in one run. Row 2d becomes the eval probe path, appending the probe to a first-party script through response interception runs it under the page's real CSP and agrees with the page-native verdict everywhere, with the limitation that the probe needs an external first-party script that is not hash-pinned in the policy and carries no SRI `integrity` attribute. On a hash-pinned CSP or an SRI-protected script, appending breaks the page's own script entirely (verified in all three engines), so doctor must detect both cases first and fall back to the static verdict with an explicit reason. Inline-only pages give no verdict at all. Verified to work with `script-src 'self'`, a nonce-only policy and a gzipped response.

Consequence for the fixture: the fixture does not reproduce the CSP trap (row 3), that remains the doctor's job. In the other direction, WebKit does enforce CSP on init-script code (row 2a), so a fixture bundle that contains `eval` or `new Function`, from the core or a dependency, is blocked in WebKit under a strict policy while it keeps working in Chromium and Firefox. The bundle check rejects both.

## Values and collateral

UTxOs with native assets, datum hash, inline datum and reference script encode like Lace, coin-only UTxOs stay byte identical. Asset values and a token spend built with Evolution are checked against CSL in `test/utxo-values.test.ts` and `test/values-oracle.test.ts`.

## Scripts

Script hashes match CSL for native scripts and Plutus V1 to V3, from the witness set and from reference scripts. A native script is hashed over the bytes it arrived in, like the ledger. Native scripts are evaluated after the ledger's evalTimelock, with its boundaries. Plutus spends with collateral, native multisig with a co-signer, native mint, a reference script, script withdrawals and a guardrail proposal, built by Evolution and CSL, are signed and verified with CSL in `test/scripts.test.ts`, `test/tx-scripts.test.ts`, `test/sign-tx-scripts.test.ts` and `test/scripts-oracle.test.ts`. A native mint is signed in the page in Chromium, Firefox and WebKit (`test-browser/scripts.spec.ts`).

## Ledger in Node

A submitted transaction spends its inputs and creates its outputs after the ledger's UTXO rule, a phase 2 invalid one spends only its collateral and creates the collateral return at the index after the outputs. Stake registration follows certificates 0, 7, 11, 12, 13 and 1, 8. `test/tx-outputs.test.ts`, `test/ledger-state.test.ts`, `test/ledger-binding.test.ts`, `test/init-script-ledger.test.ts`, and in three engines `test-browser/ledger.spec.ts`, including a second transaction across a reload and an origin change.

## Ledger checks

With the ledger checks a submit is refused under the rule names of a released Conway node on protocol 11, after the rules in cardano-ledger at `f9fd3acf`, with every failure collected as the node collects them. The minimum fee matches CSL including the script and reference script parts, counted over the ledger's size, one byte less than CSL's. An Evolution-built payment and a Plutus spend with collateral pass with the preprod parameters, a refused transaction changes nothing, and stake registration in the ledger and in the certificate state agree after every submit. `test/ledger-checks.test.ts`, `test/protocol-params.test.ts`, `test/ledger-options.test.ts`, `test/tx-facts.test.ts`, `test/value-math.test.ts`, `test/failure-format.test.ts`, `test/cert-state.test.ts`, `test/utxo-rules.test.ts`, `test/witness-rules.test.ts` and `test/check-transaction.test.ts`, and in three engines `test-browser/ledger-checks.spec.ts`, where a refusal reaches the page as a plain `{ code: 2, info }`.

## Plutus scripts under the ledger checks

With the ledger checks the wallet checks datums, redeemers, the script data hash and whether the ledger can build the context of every script after the rules in cardano-ledger at `f9fd3acf`, and runs every Plutus script the transaction needs in Node. A Plutus V1 context the ledger cannot build next to a failing V3 script is refused for either script order and either `is_valid`, before any script runs. Redeemer indices follow the ledger's order, also for withdrawals and votes, where it differs from the order of the CBOR bytes. A V3 spend through a reference script, a V2 spend with an inline datum, a mint under a V2 and a V3 policy, a script withdrawal next to a key withdrawal, a script DRep vote next to a key DRep vote and two spends with V2 and V3 pass both phases, each script run at the index of its redeemer. The script data hash equals the one Evolution writes into the body and the one CSL computes. For the test scripts in `test/fixtures/plutus/`, compiled with aiken, the ExUnits the wallet computes equal those of aiken's own evaluator, except for a V3 script that does not return unit, which only the wallet refuses, as CIP-117 requires. An Evolution-built spend from a script that accepts passes, a declared budget below what the script needs and a failing script with `is_valid` true are refused with `ValidationTagMismatch`, and a failing script with `is_valid` false passes and spends only its collateral. `test/cert-state.test.ts`, `test/check-transaction.test.ts`, `test/errors.test.ts`, `test/evaluator-isolation.test.ts`, `test/evaluator-lazy.test.ts`, `test/failure-format.test.ts`, `test/ledger-binding.test.ts`, `test/ledger-checks.test.ts`, `test/ledger-options.test.ts`, `test/page-bundle.test.ts`, `test/phase-two-purposes.test.ts`, `test/phase-two-unavailable.test.ts`, `test/phase-two.test.ts`, `test/plutus-fixtures.test.ts`, `test/plutus-purposes.test.ts`, `test/plutus-rules.test.ts`, `test/protocol-params.test.ts`, `test/recipes-doc.test.ts`, `test/script-integrity.test.ts`, `test/slot-config.test.ts`, `test/tx-plutus-facts.test.ts` and `test/witness-rules.test.ts`, and in three engines `test-browser/ledger-checks.spec.ts`, where a spend signed in the page passes and a failing script reaches the page as a plain `{ code: 2, info }`.

## Chain mode

The Ogmios and Koios clients read recorded answers of both providers, Ogmios 6 and 7 and the public Koios preprod instance. The pending overlay, the mainnet lock and the binding to the page are checked without a network in `test/chain-ledger.test.ts`, `test/chain-binding.test.ts`, `test/chain-wiring.test.ts`, `test/chain-json.test.ts`, `test/attach-chain.test.ts`, `test/mainnet-lock.test.ts`, `test/ogmios.test.ts`, `test/ogmios-errors.test.ts` and `test/koios.test.ts`. Against a devnet on protocol 11 with cardano-node 11.0.1 and Ogmios 7.0.0, payments, stake registration, Plutus spends and refusals run through the wallet in `test-devnet/`, and `test-devnet/node-names.test.ts` checks that the rule names the ledger checks write are those the node prints. In three engines, on every push to main and in Chromium on pull requests, `test-browser/chain.spec.ts` pays from chain UTxOs on the demo dApp and checks the balance before and after the block.
