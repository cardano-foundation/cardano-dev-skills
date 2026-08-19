# Final Network-Compliance State

This section is the state-reconstruction proof.

Given a valid initial condition and a complete txid boundary, the final
network_compliance UTxO set must be computable from graph topology:
outputs at the address minus outputs later consumed by loaded
transactions.

The live UTxO snapshot is not used to compute the graph answer. It is
used as an independent end-boundary check.

## What Must Hold

The graph-derived terminal set must match the live terminal set at the
chosen block and slot boundary. If it does not, one of these inputs is
wrong:

- the opening state,
- the selected txid set,
- the emitted graph,
- the state query.

## Query Roles

- [Query 14 - Network compliance terminal state](14-network-compliance-terminal-state.md)
  computes the terminal UTxOs from graph topology only.
- [Query 15 - Network compliance live diff](15-network-compliance-live-diff.md)
  performs the row-level diff against the live snapshot.
- [Query 16 - Network compliance live summary](16-network-compliance-live-summary.md)
  checks the aggregate ADA and USDM gaps.
- [Query 11 - Terminal USDM summary](11-terminal-usdm-summary.md)
  isolates the USDM-carrying terminal UTxOs.
- [Query 20 - Terminal USDM provenance](20-terminal-usdm-provenance.md)
  explains where the remaining USDM came from.

```mermaid
flowchart LR
  lattice[85-tx graph]
  terminal[Graph terminal UTxOs]
  live[Live UTxO snapshot]
  diff[Row and summary diff]
  provenance[Terminal USDM provenance]

  lattice --> terminal
  terminal --> diff
  live --> diff
  terminal --> provenance
```
