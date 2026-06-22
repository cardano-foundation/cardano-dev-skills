---
title: Why this exists
description: Training data on Cardano drifts fast. This plugin gives agents authoritative, current, project-bundled context.
---

Training data on Cardano drifts fast. The ecosystem moves faster than any
model's pre-training cut-off can keep up with, and the rate of breaking
changes in user-facing surfaces is high.

Concrete examples:

- **Conway era governance.** CIP-1694 changed the role of stake pool
  operators, introduced DReps and a constitutional committee, and added
  on-chain treasury withdrawals. Any agent answering *"how do I register a
  DRep?"* from training data alone will produce code that either doesn't
  exist yet or uses interfaces that have changed.
- **Aiken syntax.** Aiken pre-1.0 made multiple breaking changes —
  `validator` block shape, `Pair<k, v>` introduction, opaque vs transparent
  types, the `ScriptContext` purpose tag. Snippets that worked six months
  ago no longer compile.
- **Off-chain SDK churn.** Mesh SDK v2 reorganised the package layout.
  Lucid Evolution forked into Evolution SDK after the original was
  abandoned. cardano-client-lib renamed core transaction-building APIs.
  An agent confidently producing v1 code against a v2 project is worse
  than no help at all.
- **CIP shifts.** New ratified CIPs replace earlier ones (e.g. CIP-68
  reference tokens succeeding CIP-25 metadata for many use cases). An
  agent that doesn't know which one is current will pick the wrong one.

An AI agent answering *"how do I write a vesting validator in Aiken?"*
from training data alone gets it wrong more often than right.

## What we do about it

This plugin ships:

- **Authoritative bundled docs** from 55 active Cardano projects,
  auto-refreshed weekly from upstream. The agent reads from a known-current
  snapshot, not a year-old memory.
- **Behavioural skills** that encode common workflows: scaffolding,
  writing validators, building transactions, governance, optimisation,
  debugging. Skills aren't reference dumps — they're workflow guides that
  tell the agent *what to do* and *when*, then point at the bundled docs
  for *how*.
- **Hooks that auto-consult bundled context** before the agent reaches for
  training data or the web.

End result: the agent answers from current, project-authoritative sources
instead of memorised snapshots. The fix isn't "make the model smarter" —
it's "give it the right context, every time".

## What we don't do

We don't teach how specific deployed products work. Branded dApps have
their own sites and their own incentives to keep those sites current.
This repo teaches the generic building blocks — SDKs, frameworks,
validator libraries, design patterns, language tooling, infrastructure,
protocol specs.

If a user needs product-specific integration help, their agent can search
the web. If they want to *build* a DEX, a lending protocol, an NFT
marketplace, or a governance tool — that's what this is for.
