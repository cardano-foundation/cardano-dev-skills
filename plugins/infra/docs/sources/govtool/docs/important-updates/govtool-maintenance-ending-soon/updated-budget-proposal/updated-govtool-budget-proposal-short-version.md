---
description: This is a short and concise version of a longer more detailed version
---

# Updated Govtool Budget Proposal - short version

:::info Historical (2025)
This page documents GovTool's 2025 funding and maintenance discussion and is kept for reference. Timelines and statements on this page reflect that period, not the current state of GovTool.
:::

:::danger
**FULL DETAILED PROPOSAL**

👉🏻 You can read, comment and provide feedback on the full detailed proposal [here](https://docs.google.com/document/d/15L7uA2PWeOBuQCnoGg0ZB35acvxreJ2QCMAkt9X8o1E/edit?tab=t.4qjaum32z5qp) 👈
:::

:::info
You can listen to the key details of this proposal in [this podcast](https://drive.google.com/file/d/1HVtw7qYNDUNp577Rz2rTM8JxacvXZMD3/view?usp=sharing)
:::

## What are the key differences with the original proposal

* More detailed breakdown of costs
* More options to progress maintenance and development with a stronger community-led open-source strategy and a tiered approach
* Flexibility to fund just repo maintenance or active development and maintenance of individual pillars
* More data on usage so far, and direct access to analytics

## Why is Govtool needed and what happens if it’s not maintained

Cardano’s governance framework gives the community real power over the network’s evolution, but power without access is meaningless. Most Ada holders aren’t developers with in-depth knowledge of all the wrinkles of the governance design. Without a shared, accessible interface, participation becomes limited, fragmented, or dependent on private platforms.

GovTool solves this by providing a unified, open-source platform that lets anyone submit proposals, vote, delegate, and view results, no CLI or technical setup required. It supports Preview, Preprod, and Mainnet, ensuring users can safely learn and engage at every step.

If GovTool isn’t maintained:

* Users will need to rely on fragmented or commercial tools, undermining transparency and inclusiveness.
* Essential governance functionality could stall or degrade as the protocol evolves.
* Builders and projects that rely on GovTool’s APIs would lose critical infrastructure, slowing innovation.
* Governance could become harder to access and more exclusive, the opposite of what Cardano stands for.

GovTool is not just a UI, it’s a public digital infrastructure that safeguards decentralized governance as a right, not a privilege.

## What value has Govtool provided so far?

GovTool has been foundational in enabling and scaling Cardano’s on-chain governance, delivering real-world functionality, infrastructure, and participation at a level no other tool currently matches:

* It has enabled Thousands of DRep registration, delegations, and thousands of on-chain votes—all through a clear, accessible interface that abstracts protocol complexity.
* Supported governance across SanchoNet, Preview, Preprod, and Mainnet, allowing users to learn and test safely before making real decisions.
* Underpins the entire governance cycle: from discussion and proposal submission, to registration, delegation, voting, and reviewing final outcomes—in one consistent, guided user experience.
* Powers a growing ecosystem of third-party tools and dashboards through its free, open APIs, used by platforms like[ 1694.io](https://1694.io),[ CardanoBudget.com](https://cardanobudget.com),[ Tempo.vote](https://tempo.vote), and more.
* Built and maintained by a distributed community team (including DQuadrant, Byron Network, Lido Nation, Bloxico, and others), with full transparency and community direction via the Governance Tools Working Group.
* It supported shaping the governance experience since before CIP-1694 was approved.&#x20;
* It supported the ecosystem to go through the bootstrapping phase, enabling the community to test governance, register as DReps and delegate.&#x20;
* It enabled the whole community to enact the first community-led hard-fork and gave everyone easy access to full governance, also allowing easy participation in the approval of the first Cardano Constitution.
* Its modular architecture (Voting, Delegation, Proposals, Outcomes, and Budget Pillars) enables independent improvements and scaling, reducing maintenance complexity.
* Provides end-to-end testing with Autonomous Agents, ensuring governance flows are reliable, scalable, and regression-tested with every protocol or feature update.
* Offers transparent Matomo-based usage analytics, allowing the community to see how the tool is used and where engagement is growing.
* Supports open-source design patterns and documentation, making it easier for new contributors and builders to adopt or fork components.
* Acts as a reference implementation for governance workflows, enabling faster ecosystem-wide learning.
* Includes unique governance UX features such as DRep directories, real-time voting status, rationale submission, and visibility into Constitutional Committee activity and voting thresholds.
* Facilitates liquid democracy by enabling users to switch delegations easily and understand DRep behavior over time, supporting informed governance.
* Plays a strategic role in education and onboarding—many first-time voters, delegators, and proposers have used GovTool to explore and participate in governance without technical expertise.
* Enables pre-governance engagement, such as discussion threads, moderation tools, and eventually polling, making social consensus more transparent before on-chain actions are submitted. This enabled the first Cardano budget to gather alignment and support.

In short, GovTool is more than a tool—it is a collaborative foundation for participatory governance in Cardano. It reduces technical friction, improves transparency, empowers builders, and reflects the principles of decentralization in both architecture and governance.

## Proposal costs

The revised budget addresses community feedback with a modular, transparent structure that allows flexibility while ensuring core sustainability.

### Level 1 – Foundational ($330K / ₳412.5K)

(2.25 FTEs in total + hosting costs)

Covers minimum operational costs:

* Infrastructure maintenance, hosting, CI/CD, and security. (0.25 FTE)
* Core maintenance team (1 FTE QA and 1 FTE full-stack developer, split across 4 contributors to avoid downtime).
* Ensures GovTool stays online, secure, and functional, but without guaranteed new features.

### Level 2 – Incentivised Participation ($530K / ₳662.5K)

* All in Level 1
* **₳150,000** to be allocated organically via direct contribution on the repos
* **₳100,000** to be allocated to other open source governance tools that provide new and better ways to participate in Cardano Governance leveraging (and where possible expanding) Govtool code or Govtool APIs

Enables open contribution:

* Introduces ada-based bounties for meaningful contributions.
* Allows external sponsorship of specific roadmap features.
* Supports GovTool’s organic, community-led development.

### Level 3 – Pillar Development & Active Maintenance ($920K / ₳1.15M)

(level 1 costs + level 2 costs + active development and maintenance costs of the pillars // the costs varies depending on which and how many pillars are selected)

Accelerates growth and guarantees monthly updates:

* Funds full-time development per functional pillar:
  * Proposals Pillar (0.75 FTE)
  * Delegation Pillar (1 FTE)
  * Voting Pillar (1.25 FTE)
  * Outcomes Pillar (0.75 FTE)
  * Budget Discussions Pillar (0.5 FTE)
* Adds dedicated end-to-end testing (1 FTE) to ensure reliability.
* Modular: each pillar can be funded individually or as a full suite.

Any unused funds will be returned to the Cardano Treasury, and the project will continue to be steered through the Governance Tools Working Group, maintaining open contribution pathways for new teams and community members.

## Why the Updated GovTool Proposal Costs Less

* Original maintenance costs per each pillar were reviewed based on community and DRep feedback and then reduced
* The costs of research and development for new features, which were budgeted separately in the original budget proposal, have been incorporated into the active maintenance costs in the revised proposal
* A new tiered budget was introduced bringing a more balanced approach, where in particular the foundational tier brings savings by embracing fully the common open source project support

\

