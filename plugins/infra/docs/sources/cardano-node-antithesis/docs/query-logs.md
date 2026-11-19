# Querying the Logs Explorer

Complement to [Triaging Antithesis reports](triage.md). The triage
flow uses `antithesis-triage` to parse a single test-run's **HTML
report** (assertion findings, bug listings). This page covers the
companion task: searching the **indexed stdout** of every container
in a run — i.e. driving the Antithesis Logs Explorer `/search` page
from a script.

The tool lives at [`tools/query-logs/`](https://github.com/cardano-foundation/cardano-node-antithesis/tree/main/tools/query-logs)
in this repo. Its [README](https://github.com/cardano-foundation/cardano-node-antithesis/blob/main/tools/query-logs/README.md)
is the detailed reference; this page summarises the shape of the
problem and when to reach for it.

!!! warning "Workaround, not a supported API"
    Antithesis does not currently publish a programmatic interface for
    their Logs Explorer. `tools/query-logs/` is a reverse-engineered
    CLI: it drives a real chromium over CDP, injects an SSO cookie,
    and scrapes the rendered DOM. Everything it does is observable
    from a logged-in browser session — nothing is privileged. The day
    Antithesis ship an API this tool should be deleted.

## When to use query-logs vs triage

| Question | Tool |
|---|---|
| "Why did this assertion fail?" | `antithesis-triage` — parses the report HTML |
| "Did the log-tailer sidecar emit anything during run X?" | `tools/query-logs/` — searches indexed stdout |
| "How many `sev:Warning` events came from source=p1?" | `tools/query-logs/` |
| "What was the value of `k` right before the bug was armed?" | `tools/query-logs/` with a `regex` matcher |
| "Was the run Completed, and what's its `session_id`?" | `tools/query-logs/scripts/pangolin-runs.bb --session-ids` |

## Fast path

Once the cookie is in `$ANTITHESIS_COOKIE_FILE`:

```bash
tools/query-logs/scripts/query.bb --latest '"sev":"Warning"' --source log-tailer
```

Produces a structured summary: total match count, breakdown by source,
by `(source, ns, sev)`, and the first 10 distinct rendered rows.

## Cookie intake

Two paths depending on where you're running:

- **Headed host** — `scripts/login.bb` opens a chromium window, waits
  for you to complete Google SSO, and pulls the cookie out over CDP.
- **Headless host** (CI, remote VM) — `scripts/set-cookie.sh` accepts
  either a bare PASETO or a whole `Copy as cURL` blob from your
  laptop's DevTools Network tab. It greps the cookie out itself.

Both paths are silent: only nickname, expiry, and a `root=302 follow=200`
sanity code are ever printed. The cookie value never hits scrollback.

## What Antithesis actually indexes

**Container stdout only.** If a log stream lives inside a docker
volume (for example the cardano-tracer `ForMachine` stream) it is
**not** captured by Antithesis. The workaround is the
[log-tailer sidecar](components/sidecar.md): it tails the JSON files
to its own stdout under `source=log-tailer`, making them searchable.
See also [references/indexed-sources.md](https://github.com/cardano-foundation/cardano-node-antithesis/blob/main/tools/query-logs/references/indexed-sources.md)
in the tool folder.

## Finding a run

```bash
tools/query-logs/scripts/pangolin-runs.bb --session-ids        # time + session_id table
tools/query-logs/scripts/pangolin-runs.bb --latest-completed   # single session_id
tools/query-logs/scripts/pangolin-runs.bb --by-commit <sha>    # JSONL, filtered
```

The `session_id` used by Logs Explorer is **not** the `testRunId`
moog exposes; it's `value.session_id` from a pangolin run record, of
the form `<hex32>-<major>-<minor>`.

## Failure modes

See [references/driver-troubleshooting.md](https://github.com/cardano-foundation/cardano-node-antithesis/blob/main/tools/query-logs/references/driver-troubleshooting.md).
Common traps: stale cookie (`root=302 follow=302`), the play-icon
button staying disabled, synthetic `OTIS` session ids from webhook
aggregator runs, and the SPA silently rejecting collapsed multi-clause
query JSON.
