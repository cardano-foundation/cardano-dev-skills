---
title: Scope
description: What belongs in this repo — the two-part source test and the skill bar.
---

This repo teaches **building on Cardano**. It is a generic knowledge base for
AI coding agents and developers.

The repo has two layers with different rules:

- **Sources** (`registry/sources.yaml` → `docs/sources/`) are mirrored
  upstream documentation: the project's own words, vetted for relevance and
  maintenance, kept current by the weekly refresh.
- **Skills** (`skills/`) are authored by this repo's maintainers:
  task-oriented behavioral guidance. Skills are never project-specific —
  projects are documented as sources and taught through task skills.

## Source scope: the two-part test

A source qualifies only if it passes **both** gates:

1. **Cardano-native.** The project's on-chain footprint is on Cardano —
   contracts deployed there, or specs/standards targeting it. Multichain
   projects qualify only if Cardano is a first-class supported chain, and
   only the Cardano-relevant part of their docs is mirrored (use
   `glob_patterns`). We don't list AI platforms operating on other chains,
   or oracles that don't operate on Cardano — however established they are.
2. **Developer-integration surface.** The docs must document something a
   developer building on Cardano integrates with or builds on: contracts,
   APIs, SDKs, protocol specs, a runnable node or service. An
   *integration-first* project (an oracle, a payment protocol, an indexer)
   qualifies even though it is a branded, for-profit product — its business
   only exists if developers integrate it, so its docs are developer
   material. An end-product user manual (how to swap on a DEX frontend, how
   to browse an NFT marketplace site) does not qualify; the same project's
   protocol or contract specs can qualify even when its end-product docs
   don't.

Always out of scope regardless: closed-source content; marketing-only
material.

In-scope examples: SDKs, frameworks, validator libraries, design patterns,
language tooling; infrastructure (nodes, indexers, chain providers);
protocol and standard specs (CIPs, ledger specs); reference implementations
of *patterns*; generic dApp categories (DEX, lending, NFT marketplace,
oracle consumer, governance tool).

## Skill scope

Skills are this repo's editorial voice and are held to a **stricter bar
than sources**:

- **No project-specific or brand-named skills, ever.** Skills map to
  developer workflows — `query-chain`, not the name of a chain provider.
  This is stricter than the source rules on purpose: a skill is behavioral
  instruction an agent follows (tool use, workflow steps, decision
  criteria), so a harmful or stale skill can do more damage than a harmful
  doc. Vendor-maintained skills copied here inevitably drift from their
  canonical home. Vendors who maintain their own installable skill should
  document it in their own docs — once those docs are a registered source,
  agents and users discover the skill there, always via the refreshed
  pointer.
- **A skill that teaches integrating with a specific project requires that
  project to be a registered source.** Spec-level detail (endpoints,
  request bodies, datum schemas) belongs in `docs/sources/`, where the
  weekly refresh keeps it current; a skill's `references/` directory is for
  behavioral guidance, not pasted specs.
- Teach categories generically (*"how to write a vesting validator"*), not
  product mechanics (*"how to use Product X's deposit endpoint"*).
- A skill is a neutral community contribution. No branded promotion, no
  grant/treasury context, no proposal framing.

If you're unsure, open a discussion before writing code.
