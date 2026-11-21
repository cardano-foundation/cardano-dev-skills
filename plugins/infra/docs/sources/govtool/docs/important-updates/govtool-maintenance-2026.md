---
description: >-
  GovTool is actively maintained. Since September 2026 the Sireto team has
  day-to-day operational ownership of GovTool. Read what this means and what the
  team is working on next.
---

# GovTool Maintenance in 2026

:::tip GovTool is actively maintained
Since September 2026, the **Sireto team** has taken over day-to-day operational ownership of Cardano GovTool. GovTool stays open source and community-driven, and [gov.tools](https://gov.tools) continues to run as usual.
:::

## Who maintains GovTool

GovTool is maintained by the Sireto team:

* [@mesudip](https://github.com/mesudip)
* [@kusssal](https://github.com/kusssal)
* [@sireto-sandip](https://github.com/sireto-sandip)

They look after the GovTool code, releases and the hosted instances, and they review issues and pull requests in the [GovTool repository](https://github.com/IntersectMBO/govtool).

GovTool exists thanks to everyone who has contributed so far: the builder teams who developed and maintained it until now, and everyone who wrote or reviewed code, tested releases, reported bugs or shared feedback on the user experience.

## What this means for you

* **Nothing changes in how you use GovTool.** You can keep delegating, voting, registering as a DRep and proposing Governance Actions on [gov.tools](https://gov.tools).
* **GovTool stays open source**, under the Apache 2.0 license.
* **Support works the same way.** Use the "Feedback" button in GovTool, or see [Support](../cardano-govtool/support.md) and [How to submit a bug](../bugs-or-feature-suggestions/how-to-submit-a-bug.md).

## What the team is working on

The maintainers have shared the direction they want to take GovTool in. The plans are open for discussion, and some of them are already in progress.

### Easier to run and contribute to

* **One repository for everything.** Some parts of GovTool, such as the Proposal and Outcomes pillars, lived in separate repositories. They are being brought into the main GovTool repository, so the project is easier to follow and to contribute to. The Outcomes pillar is already part of GovTool (its UI is in the frontend and its API is served by the backend), the Proposal Discussion UI is in the frontend source, and a new Proposal Discussion backend is in the repository. Moving this documentation into the GovTool repository is part of the same work.
* **A simple local setup.** Running the full GovTool stack on your own machine should be a short, documented process. The whole stack can now run on frozen mainnet data with a single Docker Compose command, with no db-sync or Cardano node. See [Run GovTool Locally](../cardano-govtool/run-govtool-locally/README.md).
* **A TypeScript backend.** The Haskell backend has been replaced with a TypeScript (NestJS) backend (`govtool/govtool-backend`), so that more people can work across the whole codebase. The Haskell backend has been removed from the repository ([#4246](https://github.com/IntersectMBO/govtool/pull/4246)).
* **Smoother contributions.** Clearer setup instructions, better documentation and faster reviews.
* **A cleaner issue backlog.** Outdated or already-resolved issues will be closed, so that the open issues reflect the work that is actually left to do.

### Lighter infrastructure

Running GovTool has meant running your own Cardano node and cardano-db-sync instance. That is a lot to ask of a contributor, and a lot to operate. Where mature community-run projects and providers already offer this data reliably, GovTool will build on them and work with their teams instead of duplicating the effort.

The first step is in the repository: the backend now reads chain data through a provider layer, with db-sync, Koios and Blockfrost providers. db-sync remains the default, Koios is a supported alternative that needs no database of your own, and the Blockfrost provider is experimental.

### Better connected to the ecosystem

* **Closer integration with community projects.** Many teams are building tools for Cardano governance. GovTool should work together with them rather than on its own.
* **A governance digest.** A regular summary of what is happening in Cardano governance (active Governance Actions, votes and outcomes) that you can subscribe to, so you can follow along without watching the chain yourself.

The overall goal: make GovTool the best open-source governance tool on Cardano, and keep it open.

## Get involved

The maintainers want to shape these plans together with the community. If you have views on any of them, especially the move to a TypeScript backend, now is the best time to share them:

* Join the discussion on [GitHub issue #4216](https://github.com/IntersectMBO/govtool/issues/4216).
* Open an [issue](https://github.com/IntersectMBO/govtool/issues) or a [pull request](https://github.com/IntersectMBO/govtool/pulls), or start a thread in [GitHub Discussions](https://github.com/IntersectMBO/govtool/discussions).
* See [How to participate](../participate-in-development/how-to-participate.md) for more ways to contribute.

## Earlier updates

For the 2025 funding discussion and the history that led here, see [GovTool Maintenance Ending Soon (2025)](./govtool-maintenance-ending-soon/README.md).
