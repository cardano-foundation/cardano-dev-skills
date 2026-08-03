# Daily Amaru walking skeleton

The daily controller is a deliberately thin, supervised path from bare
`pragma-org/amaru` `refs/heads/main` to one exact `cardano_amaru` test request.
It runs on one fixed UTC cron. Pull requests and manual dispatches execute the
same state machine through the deterministic fake transport and cannot call
the real launcher.

## Decision and durable guards

The GitHub transport first claims the UTC day in issue #210, resolves exactly
one 40-character SHA from the bare upstream ref, and compares it with the last
successful SHA in the receipt stream. An equal SHA records `UNCHANGED` without
mutation or launch. A changed SHA must claim a no-retry attempt marker before
any cross-repository mutation. Duplicate days, attempted SHAs, malformed or
ambiguous observations, and every failed stage retain an honest `FAILED`
receipt.

Production requires `DAILY_AMARU_CROSS_REPO_TOKEN`, injected as both
`DAILY_AMARU_IDENTITY` and `GH_TOKEN`. The repository neither creates nor
defaults that credential. Without it, the controller fails before the
bootstrap proposal, image publication, consumer repin, integration, or launch.

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
