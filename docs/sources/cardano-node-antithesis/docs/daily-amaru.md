# Daily Amaru walking skeleton

The daily controller is a deliberately thin, supervised path from bare
`pragma-org/amaru` `refs/heads/main` to one exact `cardano_amaru` test request.
It runs on one fixed UTC cron. Pull requests and manual dispatches execute the
same state machine through the deterministic fake transport and cannot call
the real launcher.

## Scheduled runner contract

The scheduled job provisions every non-shell command the controller and
transport can reach: `ripgrep` and `nix` on top of the stock image. The
controller checks the commands it needs to reach the transport at all using
shell builtins, then has the transport preflight the full census — both before
the UTC day is claimed. A missing command is a precondition failure, not a setup
exception: exit non-zero at `stage=runner-preflight` with
`error=missing-command-<name>`. A preflight reporting nothing or an unparsable
success is `error=malformed-dependency-evidence`. Each transport operation
declares only the commands it uses, so publishing a failure receipt never
depends on the command whose absence it reports.

## Runner allocation boundary

`runner` values exist only after GitHub has allocated a runner for a job.
GitHub evaluates a job's own `env:` mapping *before* that allocation, so
`${{ runner.temp }}` written there is not merely empty — it is rejected, and
the whole workflow file produces zero jobs. Nothing else in CI observes that:
a run with no jobs has no failing job to report, so every other required
context stays green while the schedule silently never ran.

The scheduled job therefore binds `DAILY_AMARU_STATE_DIR` and
`DAILY_AMARU_RECEIPT` on the step that uses them, not on the job. The values
are unchanged — `$RUNNER_TEMP/daily-amaru` and its `receipt` child — and the
receipt upload keeps its own step-scoped `${{ runner.temp }}` lookup.

## Bootstrap App identity

Production mints a short-lived token from a dedicated GitHub App, named by
repository variable `DAILY_AMARU_APP_ID` and secret
`DAILY_AMARU_APP_PRIVATE_KEY`, scoped to owner `lambdasistemi`, repository
`amaru-bootstrap` alone, and exactly five permissions: actions read, checks
read, contents write, pull requests write, metadata read.

That token authorizes the bootstrap boundary only. Same-repository work — issue
receipts, consumer repin, check observation, launch — uses the workflow's own
repository token, granted exactly the permissions those operations declare. The
two are never interchangeable, and neither the private key nor the minted token
is printed, persisted, exported through `$GITHUB_ENV`, committed, or passed as a
command-line argument; the token is a step-scoped environment binding only.

If an input or the mint step is unavailable, the mint is allowed to fail and the
controller still runs with an empty identity, exiting non-zero at
`stage=identity` with `error=missing-credentials-<name>` before any bootstrap,
image, repin, integration, or launch effect.

Every receipt is written locally before external publication is requested, and
the scheduled job uploads that file on every outcome, so a broken precondition
leaves the day, stage, `outcome=FAILED`, and a specific error behind even when
the transport cannot publish its issue receipt.

## Operator setup gate

Creating the App, installing it on `lambdasistemi/amaru-bootstrap`, approving
its permissions, and placing the variable and secret are operator actions
outside this repository. Until they are done the scheduled run is expected to
fail at `stage=identity`; that is the contract working, not a regression. No
secret value is recorded anywhere in this repository.

## Decision and durable guards

The GitHub transport first claims the UTC day in issue #210, resolves exactly
one 40-character SHA from the bare upstream ref, and compares it with the last
successful SHA in the receipt stream. An equal SHA records `UNCHANGED` without
mutation or launch. A changed SHA must claim a no-retry attempt marker before
any cross-repository mutation. Duplicate days, attempted SHAs, malformed or
ambiguous observations, and every failed stage retain an honest `FAILED`
receipt.

## Supervised changed path

The provisional transport:

1. proposes only the stock Amaru lock update in
   `lambdasistemi/amaru-bootstrap`;
2. waits for named checks on that exact candidate and resolves its full SHA
   image tag to a lowercase registry digest;
3. atomically repins every discovered `cardano_amaru` producer reference;
4. requires the named workflow/job results on the exact consumer head and
   retains the positive, non-zero output from
   `scripts/check-amaru-producer-image-refs.sh`;
5. waits for lane-supervised guarded integration and verifies the merge is
   exact current `main`—the transport has no generated-PR self-merge command;
6. invokes `cardano-node.yaml` once with `test=cardano_amaru`, `duration=1`,
   and `no-faults=false`, then waits for the run result before recording the
   upstream SHA as successful.

There is no automatic retry. A failed partial receipt stays failed; it is not
translated to `UNCHANGED`, launch success, or a findings verdict.

## Replacement owners

The production source marks each provisional mechanism once with its owner:
`amaru-bootstrap#75` replaces the crude stock-pin handoff,
`cardano-node-antithesis#208` supplies complete exact-revision preflight,
`cardano-node-antithesis#207` supplies guarded unattended integration and
correlation, and `cardano-node-antithesis#206` supplies complete property
receipts and a missing-day alarm.

## Local proof

Run the deterministic controller suite without credentials or network access:

```console
tests/test-daily-amaru.sh
```

It exercises changed, unchanged, malformed observations, exact-head check
failures, non-vacuous #202 evidence, duplicate/no-retry guards, failure
ordering, receipt honesty, and the counted zero-real-launch invariant.

It also reproduces the 2026-08-02 and 2026-08-03 missing-`rg` incidents against
the real transport in a hermetic seeded PATH, checks the App scope, credential
non-persistence, and the token grant/use seam, counts the effects both broken
preconditions reach, and checks that CI executably calls this suite while the
schedule calls the controller. Every instrument carries controls proving it can
fail.

Validate every tracked workflow in the repository, which is the same command
the merge-required `Check code quality` context runs:

```console
nix develop --quiet -c just check-workflows
```

It enumerates every tracked `.github/workflows/*.yaml` and `*.yml` file, prints
the census and its count, refuses an empty census, and validates the expression
contexts with the `flake.lock`-pinned actionlint. Baselines in
`.github/actionlint.yaml` are path-specific and quote the exact pre-existing
diagnostic they accept; none of them can suppress the `runner`-at-job-level
class.

Run the complete local gate — workflow validation, shell analysis, formatting,
and both focused proofs, none of which need Docker, network, or credentials —
with:

```console
nix develop --quiet -c just ci
```
