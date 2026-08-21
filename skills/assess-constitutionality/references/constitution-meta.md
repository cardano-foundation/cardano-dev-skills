# Bundled Constitution Version

The constitutional text in this directory is a snapshot of the Cardano Constitution
as enacted on-chain. Every assessment produced by this skill must state these values
so a reader can tell exactly which text the reasoning rests on.

| Field | Value |
|---|---|
| Anchor URI | `ipfs://bafkreieyuknozbtewyurfqoagvplvykadn6a4u6wglupavdz46bbsnnl6e` |
| Anchor hash | `b368bdad83c727bbfe86425575233fb914eb76d05d89497f7790cf007fd95f52` |
| Ratified epoch | 608 |
| Enacted epoch | 609 |
| Snapshot taken | 2026-05-22 |

## Why this matters

The Constitution is amendable through `NewConstitution` governance actions. If one has
been enacted since the snapshot date above, this corpus is superseded and any finding
derived from it may be wrong. This skill cannot check that itself, so it never claims
the corpus is current. It states the version and hands the reader the check.

## Verifying currency

This skill does not make network calls. Ask the user to run the check and paste the
result back, or point them at it so they can confirm independently:

```sh
curl -s "https://api.koios.rest/api/v1/proposal_list?select=proposal_type,ratified_epoch,enacted_epoch,proposal_description" \
  | jq '[.[] | select(.proposal_type == "NewConstitution" and .enacted_epoch != null)]
        | max_by(.enacted_epoch)
        | {enacted_epoch, proposal_description}'
```

Interpreting the result:

- **`enacted_epoch` is 609** — the bundled corpus is current. Proceed normally.
- **`enacted_epoch` is greater than 609** — a newer Constitution is in force. The corpus is
  stale. Say so plainly, stop, and do not issue findings from superseded text. Refreshing
  the corpus is a repo maintenance task, not something to work around mid-assessment.
- **Check not run, or the command failed** — proceed, but stamp the report
  `Constitution currency: unverified` alongside the version table. Never silently assume
  currency.

An `enacted_epoch` below 609 should not occur; if it does, treat the discrepancy itself as
the finding and stop.
