# Multi-run overview

Complement to [Triaging Antithesis reports](triage.md) and
[Querying the Logs Explorer](query-logs.md). Those tools work on a
single test-run at a time. This page covers the **morning-triage
entry point**: turning the
[cardano.antithesis.com](https://cardano.antithesis.com/) runs page
into a clickable digest of the last N hours of runs for a given
repo.

The tool lives at
[`tools/antithesis-overview/`](https://github.com/cardano-foundation/cardano-node-antithesis/tree/main/tools/antithesis-overview)
in this repo. Its
[README](https://github.com/cardano-foundation/cardano-node-antithesis/blob/main/tools/antithesis-overview/README.md)
is the detailed reference; this page summarises shape and when to
reach for it.

!!! warning "Workaround, not a supported API"
    Antithesis does not currently publish a programmatic interface
    for the runs index page. `tools/antithesis-overview/` is a
    reverse-engineered Claude Code skill: it drives a real chromium
    over CDP via the playwright MCP, scrapes rendered DOM, and
    publishes the digest as a GitHub gist. Everything it does is
    observable from a logged-in browser session — nothing is
    privileged. The day Antithesis ship a runs API this skill
    should be deleted.

## When to use overview vs. triage vs. query-logs

| Question | Tool |
|---|---|
| "What's going on in Antithesis for repo X over the last 48h?" | **`antithesis-overview`** (this page) |
| "Why did this single assertion fail?" | [`antithesis-triage`](triage.md) |
| "How many `sev:Warning` events came from source=p1 in run X?" | [`tools/query-logs/`](query-logs.md) |

## Fast path

```
/antithesis-overview --repo cardano-foundation/cardano-node-antithesis --hours-back 48
```

Free-form arguments work too:

```
/antithesis-overview last 48h, focus on cardano-node-antithesis
```

The skill prints a single GitHub gist URL. Open it in a browser to
read the digest with every link clickable.

## Why a gist instead of terminal output

Antithesis report URLs are 300–400 chars including the PASETO auth
token, and break click-through in every terminal markdown renderer
we've tried. Even short URLs like GitHub commit links wrap
unpredictably inside table cells. Publishing the digest as a
`gh gist --secret` and printing only the gist URL keeps the terminal
clean and lets GitHub render the markdown server-side, where every
link clicks.

## Caveats

- **PASETO tokens leak in gist content.** A secret gist is unlisted,
  but anyone with the gist URL can read the embedded report URLs
  for the token's ~9h lifetime. Don't post gist URLs to public
  channels.
- **The "Elapsed" column is misleading.** The runs page's "duration"
  is started→completed elapsed time (queue + execution +
  post-processing). The actual run wall-clock comes from the
  report's metadata. The skill labels the column "Elapsed" with a
  footnote.
- **SSO cookies expire after ~9 hours.** Get a fresh one from a
  logged-in browser when the skill returns 403.

## Setup

See the [tool README](https://github.com/cardano-foundation/cardano-node-antithesis/blob/main/tools/antithesis-overview/README.md#install-project-local)
for installation. The short version: symlink
`tools/antithesis-overview/` into `~/.claude/skills/` and the skill
becomes discoverable in Claude Code.

## Future work

A scriptable CLI replacement is tracked in
[#97](https://github.com/cardano-foundation/cardano-node-antithesis/issues/97).
When that lands, this skill should defer to it for runs-listing and
only use the browser for report-level drill-downs.
