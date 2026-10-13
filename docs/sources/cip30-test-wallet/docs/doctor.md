# doctor

`npx cip30-test-wallet doctor <url>` checks a deployed dApp for the traps that keep Cardano wallets from injecting.

## Static run

One `fetch`, redirects followed, the final URL is what gets judged. Only `http:` and `https:` URLs are accepted. The fetch carries a `user-agent` naming this tool (Node's own fetch sends none, and bot walls often treat that as a challenge) and times out after `--timeout <ms>` (default 15000), which is reported as a run error, not a finding.

| Check | Finding | Severity |
|---|---|---|
| Not https and not a loopback host | `no-secure-context` | error |
| The response status is outside 200 to 299 | `http-status` | error |
| The response content type does not contain `text/html` | `not-html` | warning |
| No enforced policy | `no-enforced-csp` | info |
| Only a report-only policy | `report-only-csp` | info |
| Enforced `script-src` (or `default-src` as fallback) without `'unsafe-eval'` | `eval-blocked` | warning |
| Enforced policy that does not govern scripts | `eval-unrestricted` | info |
| `'unsafe-inline'` next to a hash or nonce | `inline-hash-conflict` | info |

Every `Content-Security-Policy` header, every comma-separated policy inside one header, and every `<meta http-equiv>` counts. Several enforced policies combine as an intersection. `script-src-elem` and `script-src-attr` never affect the eval verdict. A directive name that repeats inside one policy keeps only its first occurrence, and `'unsafe-eval'` and `'unsafe-inline'` are matched case-insensitively, both per CSP3.

`http-status` and `not-html` exist because a non-2xx status or a non-HTML body usually means the analysis below describes a challenge page, an error page, or a redirect target, not the dApp. Fetch a URL you already know answers with the real page if you see either.

`eval-blocked` describes the conflict and names the wallets it is confirmed for. It never tells you to add `'unsafe-eval'`. Allowing eval weakens the policy, keeping it excludes the mobile in-app browsers that inject through eval, confirmed for Eternl iOS. VESPR iOS injects past the policy and is not affected. That is your decision.

## Deep run

`--deep` starts a browser (`--browser chromium|firefox|webkit`, default chromium, needs `@playwright/test` and its browsers) and loads the page twice. `--settle <ms>` (default 1500) bounds how long the second load waits after loading (and after `--click`, when given) before the probes are read, or, with `--expect <selector>`, how long it waits for that selector to become visible, whichever is longer than `--inject-after <ms> + 500`.

The first load observes. An accessor on `window.cardano` records when the page first reads it and how often, and a listener records the page's own `securitypolicyviolation` events. Nothing is injected. If the page ends up on a different URL than the static fetch judged (a redirect the static fetch's cookie-less request did not take, a client-side navigation), `deep-url-differs` names it, the measurements describe the page the browser actually loaded.

The second load probes. The eval probe is appended to the response of the first first-party script without an `integrity` attribute, so it runs under the page's real policy. It is skipped, with a reason, when the policy pins scripts by hash, when every first-party script carries an `integrity` attribute, when there is no external first-party script, or when the route interception never matched a request. A probe that runs but raises something other than a CSP violation is reported as `eval-probe-error` instead of folded into the blocked or allowed verdict. The test wallet is injected (`--inject-after <ms>` delays it, the report names the millisecond it actually ran at), `--click <selector>` runs a user action in both loads (a failed click is reported as `click-failed` and does not abort the run, whatever was already observed still stands), and `--expect <selector>` names the element that appears once the dApp detected a wallet.

| Observation | Finding | Severity |
|---|---|---|
| No read of `window.cardano` in the scenario | `no-cip30-access` | info |
| Exactly one read, no retry | `single-scan` | warning |
| Eval probe skipped | `eval-probe-skipped` | info |
| Eval probe raised an unexpected error | `eval-probe-error` | info |
| Probe result differs from the policy verdict | `eval-verdict-mismatch` | warning |
| `--click` did not complete within its timeout | `click-failed` | warning |
| Injected wallet missing from `window.cardano` | `injection-failed` | error |
| `--expect` not visible within the settle window | `wallet-not-detected` | warning |
| The browser ended up on a different URL than the static fetch | `deep-url-differs` | info |

Wording is deliberately careful. "No access observed during the executed scenario" is not "this page does not use CIP-30", the page may read `window.cardano` after a click. "Read once" is not "a late wallet is never found", only `--inject-after` with `--expect` proves that. The injection row in the human output reads "wallet injected at `<ms>` ms, present in window.cardano, `<n>` page read(s) after that", the count only includes reads after the wallet actually installed, not the install's own reads. `wallet-not-detected` names both the millisecond the wallet was injected and the millisecond window `--expect` was given to appear, so a report that a wallet was "not detected" always says exactly what was measured and in what window, never that the page cannot detect a wallet in general.

## Output and exit codes

Human readable by default: the page, its content security policy (one directive per line), the deep run measurements when `--deep` ran, the findings sorted from error to info, run errors, and a closing result line with the exit code. `--json` prints the full report. Exit 0 means no finding above info, 1 means at least one warning or error, 2 means the run itself failed (URL unreachable, timed out, browser missing).

## What doctor cannot see

A policy that JavaScript inserts as a `<meta>` tag after the parser already ran scripts above it is invisible to doctor: a meta policy only governs what the parser processes after that tag, and doctor reads whatever meta tags are in the response body, not ones added later. A service worker that answers the page's own requests with a different response than the server sent is invisible too, doctor only sees what the network handed back. The static fetch carries no cookies, so a session-aware app can send it somewhere other than where a real signed-in browser would end up, when the deep run's browser lands somewhere else, `deep-url-differs` says so. The injected wallet is the project's public default test wallet, built from a published test mnemonic, it never holds funds and is safe to see in a trace.

## Limits

The injected wallet is the default test wallet, it never signs anything during a doctor run. The deep run cannot reproduce a mobile in-app browser, it measures the page under a desktop engine. WebKit is the engine behind the Eternl iOS in-app browser, which is why `--browser webkit` is worth running for a page destined for that browser, but the eval probe itself is engine-independent, it reports what actually happened under whichever engine ran it, not a WebKit-specific measurement.
