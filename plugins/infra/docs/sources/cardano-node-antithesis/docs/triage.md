# Triaging Antithesis reports

Antithesis delivers test-run results as HTML pages behind single-use signed URLs (PASETO v2.public in the querystring) and notifies the requester via email. There is **no public REST API, no MCP server, and no webhook-in**; outbound webhooks only trigger runs, they do not return results.

This page documents the state of the art for pulling findings out of a run — in particular for AI coding agents that need to dig into assertion failures without a UI.

## What exists upstream

- **`antithesis-skills`** — [github.com/antithesishq/antithesis-skills](https://github.com/antithesishq/antithesis-skills), announced at [antithesis.com/blog/2026/agent_skills](https://antithesis.com/blog/2026/agent_skills/). A collection of Claude-style agent skills. The relevant one for us is **`antithesis-triage`**: look up runs, check status, investigate failed assertions, view metadata, download logs, inspect findings.
- **`snouty`** — [github.com/antithesishq/snouty](https://github.com/antithesishq/snouty), their Rust CLI. Commands: `launch`, `validate`, `debug`, `docs`, `update`. Launches runs and searches docs; does **not** fetch reports.
- **`agent-browser`** — [github.com/vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser), a headless-browser wrapper used by `antithesis-triage` to render the signed report page and feed the DOM to the agent.
- **Outbound webhook** — [antithesis.com/docs/webhook](https://antithesis.com/docs/webhook/), only for launching runs.
- **GitHub Action** — [antithesis-trigger-action](https://github.com/antithesishq/antithesis-trigger-action), fire-and-forget.

## How it fits the moog flow

The Cardano testnet runs are launched via [moog](https://github.com/cardano-foundation/moog), which submits a test-request on-chain and the agent delivers the report URL back via the requester's wallet. Decrypt with:

```bash
moog facts test-runs --whose cfhal --no-pretty \
  | jq -c '.[] | select(.value.phase == "finished") | {commit: .key.commitId[:8], outcome: .value.outcome, url: .value.url}'
```

(Run as `being_requester` — the report URL is encrypted for the requester identity and auto-decrypted by `moog facts`.)

The resulting URL is what `antithesis-triage` consumes.

## Prerequisites

`antithesis-triage` requires three tools installed locally:

```bash
# snouty
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/antithesishq/snouty/releases/latest/download/snouty-installer.sh | sh

# agent-browser (>= v0.23.4)
npm install -g agent-browser
agent-browser install   # downloads Chrome for Testing

# jq
# https://jqlang.org/download/
```

### NixOS note

`agent-browser install` downloads a Chrome binary that depends on system libraries (`libglib-2.0`, `libnspr4`, etc.) missing from a NixOS host. The simplest workaround: install chromium via nix and connect `agent-browser` to it via CDP instead of letting it auto-launch.

```bash
nix profile add nixpkgs#chromium

# Start headless chromium with remote debugging
chromium --headless --disable-gpu --no-sandbox \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-agent &

# Point agent-browser at it
agent-browser connect 9222 --session triage
agent-browser open "$URL" --session triage
agent-browser get text body --session triage
```

See `scripts/agent-browser-nixos.sh` for a wrapper.

## Using the skill from Claude Code

The skill is packaged at `/code/llm-settings/shared/skills/antithesis-triage/` and auto-discovered in Claude Code. Invoke with a report URL or tenant name:

```
/antithesis-triage
```

When prompted, paste the decrypted Antithesis URL from `moog facts test-runs` or set `ANTITHESIS_TENANT=cardano` in the shell.

The skill walks through the report, extracts failing Sometimes/Always assertions and bug findings, and can download logs for a specific run.

## Multi-run overview

If you don't yet know which run to triage and want a digest of the
last N hours across the repo's recent runs, see
[Multi-run overview](overview.md). That tool lives at
[`tools/antithesis-overview/`](https://github.com/cardano-foundation/cardano-node-antithesis/tree/main/tools/antithesis-overview)
and publishes a clickable Markdown table as a GitHub gist.

## Searching indexed stdout

Triage covers the report (assertion findings, bug listings). For the
complementary task — searching the **indexed stdout** of every
container in a run (e.g. "did the log-tailer sidecar emit anything
during run X?") — see [Querying the Logs Explorer](query-logs.md).
That tool lives at [`tools/query-logs/`](https://github.com/cardano-foundation/cardano-node-antithesis/tree/main/tools/query-logs)
and drives a headless chromium against Logs Explorer.

## What is not available

- **No structured JSON report export.** Only the in-container SDK log (`ANTITHESIS_SDK_LOCAL_OUTPUT`) is structured; the triage report itself is HTML behind PASETO.
- **No MCP server.** Not in the Antithesis org, not in docs, not in the skills blog post.
- **No inbound webhook.** Results arrive by email to the requester; nothing is pushed to an HTTP endpoint.

If a programmatic path opens up in the future, the Antithesis skills repo changelog is the place to watch — they flagged "parse triage reports" as a planned skill expansion.
