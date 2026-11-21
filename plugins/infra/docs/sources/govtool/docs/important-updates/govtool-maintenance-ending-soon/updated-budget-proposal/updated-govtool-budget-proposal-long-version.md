---
description: >-
  Cardano’s open-source tool for the community to contribute to governance:
  Cardano Govtool
---

# Updated Govtool Budget Proposal - long version

:::info Historical (2025)
This page documents GovTool's 2025 funding and maintenance discussion and is kept for reference. Timelines and statements on this page reflect that period, not the current state of GovTool.
:::

:::info
you can read the short version [here](./updated-govtool-budget-proposal-short-version.md) or you can listen to the key details of this proposal in [this podcast](https://drive.google.com/file/d/1HVtw7qYNDUNp577Rz2rTM8JxacvXZMD3/view?usp=sharing)
:::

Budget category: Governance Support

## Problem Statements and Proposal Benefits

### Problem Statement

With the implementation of[ CIP-1694](https://www.1694.io/en) and the dawn of the[ Voltaire era](https://roadmap.cardano.org/en/voltaire/), the community now has the power to shape the network’s future through on-chain governance. <mark style="background-color:green;">**But power without access is meaningless**</mark>. **For on-chain governance to be effective, it requires&#x20;**_**participation**_. To enable and facilitate meaningful participation, a simple and consolidated user experience is key to allow Ada holders, new and existing, to get informed, onboarded, delegate to DReps (or become DReps), discuss and create new governance actions, see/vote on governance actions,and see outcomes of the whole process.

For the **public good**, it is also key for the Cardano community to own and maintain **a set of basic tools that will always be, open-source, non-commercialized and available/accessible to foster this participation** and so to keep decision making in Cardano ecosystem matters as fair, transparent and open as possible.

Without an open-source solution, we risk the productization of participation. If the core governance tools become driven by profit, access and influence could become inequitable and shaped by those that can afford to maintain or fund development, without community input. This effectively undermines the ideals of decentralized governance. Based upon these unique risks, an open-source,  community owned alternative must always exist. This ensures every ada holder has equal opportunity to participate.

In this context, reliable and neutral governance tooling is not just helpful, it is essential. The community must have full confidence that the tools they rely on to participate in governance will always be available, open, and free from bias. Conversely, **a closed-source voting application, controlled by a single group or enterprise, introduces risk as participants cannot independently verify its integrity or fairness**. Without trusted, non-commercial, and unaffiliated tooling, decentralized governance loses its foundation.&#x20;



Just as in any democratic system, <mark style="background-color:green;">**if the infrastructure of participation is compromised, so too is the legitimacy of its outcomes**</mark>.

#### **What happens if Cardano GovTool is not maintained?**

**The absence of GovTool**, or a similar set of tools, **would make effective and collaborative governance dramatically harder, riskier, and less inclusive**. There is a chance of drastic reduction of participation and transparency, potentially caused by the privatization of governance tooling..

Here’s what would be lost or degraded:

* **Barrier to participation in Governance would be higher**: Without GovTool (or a set of tools like GovTool), most actions needed to participate in governance (registering as a DRep, voting, proposing, etc.) would require use of the CLI, other technical tools, or any privately owned tool (that still needs funding). This would exclude the majority of Ada holders, particularly non-technical users who rely on the Web UI.
* **Fragmentation and Inconsistency**: Governance is complex by nature, other tools may try to fill the gap, but the experience of inconsistency and fragmentation will become inevitable. It is a well known and tested and proven axiom of product design that simpler, integrated products make for greater participation. Fragmentation of this experience will reduce participation in real terms, making Governance an expert-only area. This is not in the spirit of Cardano, nor does it reflect the ideals of the Voltaire area. It is effectively a type of ‘voter suppression’. No single experience currently supports:
  * All governance action types
  * All Cardano networks (Preview, Preprod, Mainnet)
  * Full open-source contribution with test coverage and analytics
  * A unified experience combining discussion, submission, delegation, voting, and results
  * Free to use OpenAPIs
* **Loss of Governance On-Ramps**: Without Preview and Preprod support, there would be no safe testing ground for new DReps or proposers to learn and build confidence before acting on Mainnet.&#x20;
* **Broken  Ecosystem Integrations**: Projects that currently build on GovTool APIs or plan to, would lose their base infrastructure. This would stall innovation and delay community-driven tooling efforts.
* **Reduced Transparency and Trust**: Other governance tools may be closed-source, lack visible roadmaps, or provide limited insight into their inner workings. GovTool's public analytics, code, backlog, and docs are a benchmark for accountability. Losing that would damage trust in governance tooling.
* **Missed Opportunity for Decentralization**: GovTool is already moving toward a community-led bounty-based model. If abandoned, the Cardano community would miss the chance to create a sustainable, decentralized tooling system—and fall back into centralized or underfunded governance interfaces.

In short, without Cardano GovTool, governance could become less transparent, less accessible, and more centralized.  Preserving and improving Cardano GovTool is not just a maintenance task, it is a commitment to participative, inclusive, and decentralized governance for all Ada holders.

### Proposal Benefit

Cardano GovTool, a set of open-source, community-owned governance tools, has been providing this support for open participation since before CIP-1694 was approved in 2023.

#### **What did Cardano Govtool enable so far?**

* It first fostered **adoption of wallet upgrading to the new governance standards** (CIP-95/CIP-105) with its first beta version
* It acted as a **reference implementation for** what **Cardano governance tools** could look like
* It fostered **testing and usage of SanchoNet**, with the SanchoNet GovTool (used by over 30k+ unique users), which helped iteration to get to the **bootstrapping phase of Cardano’s governance**. It allowed community practice and familiarise with governance by submitting and voting on governance actions, registering and delegating to DReps, and **informed improvements before mainnet launch**.\
  During this time, the governance tools working group, and the teams and individuals building Govtool became a focal group for other builders to connect.
* Since the Chang upgrade, **it opened participation during the bootstrapping phase of Governance**, helping grow the DRep pool and the total ada delegated to DReps, as well as making governance clear and visible to the community, also **allowing the first-ever community-led hardfork** to be decided transparently on-chain.\
  As on-chain governance matured, GovTool expanded to support all types of Governance Actions. Initially, simpler proposal types like Info Actions (non-binding information proposals) and Treasury Withdrawals were enabled for submission via the UI. These were chosen first due to their relative simplicity and broad utility. By late 2024, GovTool could render all proposal types for voting, meaning DReps could view and vote on protocol parameter changes, constitutional amendments, etc., even if submission of some complex types was pending.\
  During this time, the first set of tools that used Govtool backend APIs started to appear, providing new and different ways for the community to interact with governance.
* Since the Plomin upgrade, it has been the key benchmark reference for Cardano Governance for the community, being at the forefront in solving new hard challenges, creating reference implementations, and setting standards, allowing other community tools to provide extended value via their interfaces. The Cardano Plomin upgrade fully enabled CIP-1694 on mainnet, including on-chain governance action submission for all types of governance action. This was a turning point: “full governance” was now live on mainnet, and **GovTool reached a key milestone of allowing users to experience end-to-end on-chain governance on both testnet and mainnet through a user-friendly interface**. By this time GovTool had versions 1.0.24+ with significant enhancements like support for CIP-1694 identifiers, treasury withdrawals, improved Ada formatting, and better voting power calculations.

#### **What governance steps does Cardano Govtool support?**

Outside of playing a crucial ecosystem role by keeping governance open and fair, Cardano GovTool does cover the full Cardano Governance process:

1. It **allows anyone to submit a proposal, discuss it, improve it** with community feedback, and **submit it as a Governance Action in an easy guided process**
2. It **allows Ada holders to register as DReps**, or as Direct Voters (a role introduced by GovTool to increase participation), via a step by step guided process, also allowing DReps to share their profile and campaign. Furthermore, it also allows DReps to retire when needed
3. It **allows Ada holders to view, review and compare all DReps** (tagging them appropriately if active, inactive or retired), **allocating and changing delegation** to them easily, **enabling true liquid democracy**
4. It allows DReps, and Direct Voters, to **review and vote on governance actions**, encouraging them to submit a rationale for their vote
5. It **allows anyone to review the outcomes of the governance actions** that have been submitted on-chain and easily understand the outcome and why that was the decision reached
6. Via the Constitutional committee Portal it allows anyone to **see and search the Cardano Constitution in an accessible format**, to **compare different versions and track changes to the Constitution**, as well as view Constitutional Committee members, their votes, and rationale.

#### **What other value does GovTool provide?**

In addition to its governance features and collaborative development model, GovTool offers unmatched infrastructure capabilities and openness that make it a foundational pillar of Cardano’s on-chain governance ecosystem.

Here’s what sets Cardano GovTool apart:

* **Multi-Network Support**: GovTool is the only governance tool that supports Cardano’s Preview, Preprod, and Mainnet networks. This tri-network support is critical not just for developers, but for inclusive governance participation:
  * Preview and Preprod allow anyone to practice governance, register as a DRep, delegate, vote, or submit proposals, without risking real ada.
  * These testnets are not “simulations” only; they are also active protocol testbeds where Governance Actions such as protocol parameter changes can be submitted and executed, making them essential for refining governance flows before Mainnet deployment.
  * To ensure reliability and quality GovTool operates as a multi-environment system spanning development, QA, and live networks across all governance pillars (Voting & Delegation, Proposal Discussion Forum/Budget Proposals, and Outcomes). Each pillar is deployed and maintained separately on Dev, QA, Preview, Preprod, and Mainnet, enabling continuous development, testing, and public use.&#x20;
* **Open APIs for All Builders**: GovTool exposes fully open, well-documented APIs for accessing governance metadata, proposals, voting data, and more. These APIs are free to use and are already powering multiple third-party tools across the ecosystem. This enables:
  * Builders to create specialized experiences, dashboards, or governance assistants on top of GovTool’s backend.
  * Ecosystem diversity by reducing dependency on centralized infrastructure.
  * A plug-and-play model for wallets, explorers, and other apps to add governance features effortlessly.
* **Inclusive User Interface and Contribution Model**:
  * For non-technical users, GovTool offers a clean, Web2-like interface that abstracts blockchain complexity and empowers anyone to participate in governance.
  * For builders and contributors, GovTool is:
    * Fully open source, with the public GitHub repositories.
    * Extensively documented, including API specs, contribution guides, and governance context.
    * Equipped with publicly available test suites for transparency and validation.
    * Backed by a fully open development backlog, allowing the community to propose, discuss, and prioritize features together.
* **Transparent and Accountable Operations**:
  * Matomo-based usage analytics are published openly, so the community can see exactly how GovTool is being used, by whom, when, and where.
  * GovTool is possibly the only Cardano governance tool using Autonomous Test Agents that test Governance actions according to CIP-1694, helping ensure higher reliability, regression testing, and performance under load.
    * The idea by one of the development teams was to create an automated testing tool (not available on Cardano) to be able to test at scale, reduce testnet time leading to timely delivery of GovTool on mainnet. This tool known as Autonomous Agent Testing is available as open source for the developer community as a result of the GovTool project and Catalyst funding for this idea.
* **Full Governance Action Support (On the Way)**: While many tools visualize governance, GovTool is on track to become the only app that enables submission of all Governance Action types directly from the interface. Some of this is already live via backend, and full UI support is being actively developed.

**GovTool’s architecture and transparency model create a unique value proposition**: it is not just a tool to use, it is an infrastructure layer that invites the entire community to build, extend, audit, and improve how Cardano governs itself.

**Cardano Govtool has been and remains&#x20;**<mark style="background-color:green;">**the only fully open-source**</mark>**,&#x20;**<mark style="background-color:green;">**fully community-owned set of tools**</mark>**&#x20;to support the governing of Cardano without a commercial agenda**. Via community feedback and direct decision making via the open Governance Tools working group, it keeps evolving and improving, incubates opportunities for the whole ecosystem to participate and/or build on top of it. It provides access to a variety of API endpoints that do the heavy lifting for many new governance tools to exist and provide different ways to participate in governance.

A set of truly community-owned tools to participate in the Government of our ecosystem, such as Cardano Govtool, is a critical and pivotal component of Cardano, **ensuring that regardless of individual tools' decisions and support, Cardano’s governance will always be transparent and easy to access**, encouraging fair and distributed governance.

In short, Cardano Govtool is like a public square where the Cardano community joins effort in defining and improving their experience for a simpler, more open and transparent government, where hard challenges get solved with the shared expertise of our ecosystem and where consolidated effort enables smaller individual contributors to multiply the value provided to the whole community.

Furthermore, this joint effort removes the heavy lifting, **allowing many more individual tools to emerge, via APIs access to a complex and rich backend**.&#x20;

***

## Please explain how your proposal supports the Product Roadmap.

This proposal provides direct-to-users tools that allow decision-making in Cardano to progress by fostering higher participation and transparency. This includes fostering and opening participation to key decisions related, but not limited to, key parameters, roadmaps, budgets, new or updates to the constitution, and more.

***

## If possible provide evidence of wider community endorsement for this proposal?

Cardano GovTool has quickly become the hub for Cardano governance activity. **The Cardano community has been using and taking value from the applications that make up Cardano Govtool since before CIP-1694 was approved**.

* **Over 30k unique users have used, tested, and provided feedback over the beta testing in SanchoNet GovTool**, which created a path to full governance.
* **Hundreds of ideas and feedback have been submitted** via the open backlog stored in GitHub, showing participation in the evolution of the tool and ownership of it by the Cardano community.
* The governance tools working group, which as of now has met more than 65 times, has become the focal point and trusted source of info for multiple builders in the governance space, which connect weekly to provide feedback and direction to Govtool and align on common standards.

Since full governance came live with Plomin upgrade in September 2024, the <mark style="background-color:green;">**Cardano Govtool has had over 48k+ visits**</mark>, <mark style="background-color:green;">**over 76k+ page views in 170 countries**</mark> (with the highest usage in the USA, followed United Kingdom, Japan, Canada and Germany, and then Australia, Netherlands, Vietnam, Switzerland, Spain and many more). Check open analytics at [https://analytics.gov.tools/](https://analytics.gov.tools/) .&#x20;

* It supported the **thousands of DReps registrations and delegations** (equivalent to millions of ADA)
* **Thousands of votes** have been cast through GovTool’s interface&#x20;
* It hosts **hundreds of proposal** between the preview, preprod and mainnet instance
* It has enabled ada holders to experience governance on testnet, with proposals, governance actions, DReps and delegations on [preview.gov.tools](http://preview.gov) and [pre-prod.gov.tools](http://pre-prod.gov)  \
  Importantly, the platform’s openness has enabled many community contributors to get involved: the governance working group reviews user feedback weekly, the GovTool GitHub repository and backlog are public, and improvements always originate from community direction.



**Govtool’s open APIs have enabled multiple community builders** to provide value, such as:

* [2025 Cardano Budget Reconciliation](https://2025budget.intersectmbo.org/) - Ekklesia - Adam Dean, Mad Orkestra
* [Cardano Budget](https://cardanobudget.com/) - Tony | Thanh
* [1694.io](http://1694.io/) - Darlington Wleh (Lido Nation)
* [Tempo.vote](https://tempo.vote/) - Binh Mal
* [Governance Space](https://governancespace.com/en-us) - Otavio Lima
* [Cardano Budget Analytics](https://budget.cardano.africa/) - Dan Baruka
* [1694.tools](https://1694-tools.vercel.app/) - Unpopular El



Furthermore, Cardano GovTool’s fast support has enabled the Cardano community to have this Budget Proposal submission process available in record time (less than 10 working days), keeping it still open for integration via OpenAPIs.


The distributed model, which connects multiple applications in one cohesive experience, allows multiple builders and many individual participants to develop and evolve Govtool’s applications in parallel, as well as allowing anyone to take any part of GovTool as a reference implementation. This has encouraged wide positive support and participation so far.

We believe the participation, usage, and value leveraged by other tools shows clear support to continue this effort, making it more and more structured, more and more efficient, and lean as we progress.

***

## Proposal Details

### Proposal Description

This proposal aims to **push Cardano GovTool to be truly and organically maintained by individuals in the Cardano Community**, simplifying the bootstrapping model.

The Cardano GovTool has been bootstrapped by community builders, with facilitation from Intersect, to get us to full Cardano governance and ensure open and transparent participation in it.

<mark style="background-color:green;">Cardano GovTool was always meant to be</mark> <mark style="background-color:green;"></mark><mark style="background-color:green;">**organically maintained by many community contributors**</mark>. The first steps towards that have been there from the start, by making it fully open source and having community test while building. Then all the steps of governance have been divided in different applications, to reduce dependencies and increase tool resilience, as well as giving more opportunities for Govtool backend to be used. Via an open grant process it has been maintained so far by 5 community builders, shaping the foundations, as well as growing and refining documentation to allow individual contributions.\
Furthermore, a working group has been active for over 1 year, collating community feedback and providing direction, becoming also the connection point of all the builders working on governance tools.&#x20;

These give now the foundation to push Cardano GovTool a step further, reducing the need for active regular development, making that useful but not mandatory, and expanding focus on increasing organic individual contribution.&#x20;

**Cardano Govtool is currently made of five independent pillars**:

* **Voting** Pillar&#x20;
* **Delegation** Pillar
* **Proposal Discussion** Pillar&#x20;
* **Outcomes** Pillar
* **Budget Discussions** Pillar

To support these pillars, there is an overall QA for end-to-end automated testing and DevOps to manage hosting and deployments of the 3 versions (preview GovTool, pre-prod Govtool and mainnet GovTool)

**This proposal offers different levels of funding**. <mark style="background-color:green;">**All the options are community led and operated**</mark>. Every level will increase speed as well as feature improvements. These levels can be added on top of each other (level 1 can be actioned alone, to have level 2 you need level 1 as foundation, to have level 3 some or all elements of level 1 and 2 are needed). Additionally, to support decentralized development and streamline contribution workflows, we will partner with platforms like Andamio or similar to structure and distribute tasks transparently across the community.

These are the 3 different levels and what they include:

<details>

<summary><strong>Level 1</strong> - Foundational Basic Maintenance</summary>

This level secures the ongoing functionality of Cardano GovTool as public digital infrastructure, akin to projects like Node.js or Next.js, where a core team stewards development and ensures continuity. It covers the bare minimum required to keep Cardano GovTool operational and secure, enabling the community to build on a stable foundation. It includes:

1. **Hosting costs, infrastructure maintenance, CI-CD, security,** and minimum maintenance of this (_0.25 FTE_). It includes the following environments:
   1. GovTool
      1. Dev environment
         * Voting and Delegation pillars dev
         * Proposal and/Budget discussion pillars dev
         * Outcomes pillar dev
      2. QA environment
         * Voting and Delegation pillars qa
         * Proposal and Budget discussion pillars qa
         * Outcomes pillar qa
      3. Preview environment (preview.gov.tools)
         * Voting and Delegation pillars preview
         * Proposal and Budget discussion pillars preview
         * Outcomes pillar preview
         * Preview instance of DB-sync
      4. PreProd (pre-prod.gov.tools)
         * Voting and Delegation pillars preprod
         * Proposal and Budget discussion pillars preprod&#x20;
         * Outcomes pillar preprod
         * PreProd instance of DB-sync
      5. Mainnet (gov.tools)
         * Voting and Delegation pillars mainnet
         * Proposal and Budget discussion pillars mainnet
         * Outcomes pillar mainnet
         * Mainnet instance of DB-sync
   2. CC Portal (constitution.gov.tools)
      1. Mainnet
2. **Repo maintainer** (_1 FTE QA and 1 FTE full stack engineer, split between 4 people to reduce downtime_)&#x20;
   1. Code reviews
   2. Ensure security
   3. CI-CD
   4. Ensure overall consistency and cohesiveness
   5. Urgent bug fixes
   6. Testing

This level **does not compensate for feature development**, but ensures that the system stays available, stable, and secure for ongoing use and experimentation.

</details>

<details>

<summary><strong>Level 2</strong> - Incentivised participation</summary>

Level 2 **introduces flexible incentives to reward meaningful community contributions**. \
This enables timely resolution of critical issues, improvements that go beyond the foundational scope and increase of individual contributors. \
Also it **provides incentives for other open source governance tools** that provide new and better ways to participate in Cardano Governance leveraging (and where possible expanding) Govtool code or Govtool APIs. This model acknowledges and supports the hybrid nature of open source: a core team drives stability and strategic direction, while a broader community contributes enhancements, both needing resources to thrive. Incentives include:

* Direct compensation in ADA for accepted contributions

- Preferential access to premium features (e.g., extended API usage)

* Private sponsorship: external parties can expedite roadmap items by funding them directly

</details>

<details>

<summary><strong>Level 3</strong> - Pillar active development and maintenance</summary>

This is the level to which currently Govtool has been maintained. \
\
This level **ensures active monthly maintenance of the pillars, this means guaranteed and quicker bug fixes and feature development**. This could be decided pillar by pillar depending on community direction. \
This level includes active end-to-end and automated testing. \
The active development and maintenance will be awarded as contracts directly by the community to contributors they deem as reliable. \
\
Pillars that can be added to this are:

1. Proposals Pillar (0.75 FTE)
2. Delegation Pillar (1 FTE)
3. Voting Pillar (1.25 FTE)
4. Outcomes Pillar (0.75 FTE)
5. Budget discussion Pillar (0.5 FTE)



If this more comprehensive level is fully funded, the resources mentioned in the ‘Foundational level’ will not be needed (they might be needed if only some of the pillars have dedicated active development and maintenance, unless the builders there can spread the effort).

</details>

The governance body made of community members that will collate and document the direction for this open source project is currently the **Governance Tools working group**, but it can evolve based on the community wider direction.

***

## Please list any key dependencies (if any) for this proposal?

The delivery and progress of Cardano GovTool are dependent on the overall support and participation from the community, making sure everyone has ownership of the tools to participate in their government. On the development side, the applications that make up Govtool are dependent on different libraries. These dependencies will be managed directly by the repo maintainers.

***

## How will this proposal be maintained and supported after initial development?

Cardano Govtool has already passed the hardest part, its first implementation (creating standards and processes from scratch), and it’s now running with a decentralised open source model with multiple maintainers who keep the whole experience up and running as well as adding and improving existing features.

***

## Key Proposal Deliverable(s) and Definition of Done: What tangible milestones or outcomes are to be delivered and what will the community ultimately receive?

Some key items already delivered in 2025 and in the roadmap include:

<details>

<summary>Already delivered in 2025</summary>

* Supporting discussion and submission of New Constitution and No Confidence governance actions
* Supporting ada handle resolution
* Support for DRep images
* Support for CIP-129 DRep IDs
* Support for metadata hosted on IPFS
* Support for searching by DRep metadata
* Support for PreProd network
* Support for local specific denomination of figures
* Support for mathematical styling within governance action metadata
* Support for displaying constitutional committee ratification thresholds and not voted totals
* Support for redirecting users to outcomes pillar from expired governance action links
* Launch of outcomes pillar
* Improved performance of DRep directory and Live voting

</details>

<details>

<summary>Planned</summary>

* Expansion of the outcomes pillars to show transparently the full governance process, from early discussions, through voting, and to outcomes (either enacted decisions or rejected actions)
* Improvement of the integration of the Constitutional Committee's votes and rationale
* Expansion of DRep history (including voting history) to make it easier to leverage liquid democracy by selecting and updating delegation, as well as DRep favouring
* Support to create group DReps, allowing a better distribution of power
* Support to have group proposers discuss proposals and submit on-chain actions, lowering the barriers to submitting governance actions
* Adding moderation to the proposal discussion pillar
* Adding pre-governance polling to support in a transparent and decentralized manner the social processes that happen before governance actions are submitted (this includes, for example, the CC elections and the budget proposals)
* Improve code documentation to expand the pool of individual contributors, helping reduce the costs of development and maintenance, and creating rewarding opportunities for everyone in the Cardano community, as well as simplifying the leveraging of open source code to create new governance applications that improve and refine further the experience
* Expand further open APIs to allow many individual builders in Cardano to create tools to participate in governance
* Expand support to make it easy to discuss and submit all types of governance actions
* Integrate with CoSponsor for crowdfunding of the deposit needed to submit governance action on chain
* Integrate with SyncAI tool to introduce more natural language interaction with Cardano governance and elevating possibilities for integration for diverse community tooling
* More proposals and ideas collected from the community can be found:
  * In the open backlog [https://github.com/orgs/IntersectMBO/projects/34](https://github.com/orgs/IntersectMBO/projects/34)
  * In the open discussions [https://github.com/IntersectMBO/govtool/discussions](https://github.com/IntersectMBO/govtool/discussions)&#x20;

</details>

***

## Resourcing & Duration Estimates

This Proposal aims to **fund support for Cardano GovTool for 12 months**.

Depending on the level of funding chosen by the community the amount of resources allocated will vary. The resources indicated below will be provided by community builders.&#x20;

1. Level 1 - Foundational Basic Maintenance
   1. **Infrastructure maintenance** _0.25 FTE_
   2. **Repo maintainer** _1 FTE QA_ and _1 FTE full stack engineer_
2. Level 2 - Incentivised participation\
   This will provide exponentially more **individual contributors** and so resources&#x20;
3. Level 3 - Pillar active development and maintenance\
   End-to-end and automated testings _1 FTE_ (if this level is chosen, the 1 FTE mentioned in the foundational level can either be removed or added to this effort)
   1. **Proposals Pillar** _0.75 FTE_
   2. **Delegation Pillar** _1 FTE_
   3. **Voting Pillar** _1.25 FTE_
   4. **Outcomes Pillar** _0.75 FTE_
   5. **Budget discussion Pillar** _0.5 FTE_



The governance body made of community members that will collate and document the direction for this open source project is currently the Governance Tools Working. This group is made of volunteers which add to the count of resources.

***

## Previous experience

The **Cardano GovTool has been the benchmark governance tool since the emergence of on-chain governance**, the **builders currently working on it have&#x20;**<mark style="background-color:green;">**defined from scratch technical and user experience standards**</mark>**&#x20;currently used by other governance tools**. The process is facilitated with the support of IntersectMBO, its committees, and working groups.

The ongoing development and maintenance of GovTool requires a reliable and capable team. While current contributors, such as[ DQuadrant](https://dquadrant.com/),[ Byron Network](https://byron.network),[ WeDeliver](https://we-deliver.io),[ Lido Nation](https://www.lidonation.com/en), and[ Bloxico](https://bloxico.com/), have demonstrated long-standing commitment and technical expertise in the Cardano ecosystem, future funding rounds should remain open to other qualified teams as well.

**Any team with the skills, transparency, and alignment with GovTool’s open-source mission is encouraged to participate in maintaining and advancing the project**. This ensures community choice, fosters innovation, and reduces long-term dependency on a fixed set of contributors.

***

## Costing

### Ada Amount

**₳1,150,000**

### Amount in preferred currency

₳1,150,000 (**$920,000** - _USD to ADA Conversion Rate: 0.8_) for 12 months

### Cost breakdown

The **funds requested cover 12 months of maintenance and improvement** for **5 applications** that make up GovTool. Because **GovTool remains community-owned**, funds will continue to be allocated via an open and transparent grant process, and also the iterations of the different applications that make up GovTool will be subject to pivoting steered directly by the Cardano Community feedback and needs.

**This will be the first time these sets of tools, made as public good, will request funds to continue running**. So in this first instance the existing builders, which have invested effort and have the deepest expertise and knowledge to run them, will be requesting funds directly for the next 12 months. During this first 12 months more builders and individual contributors will be onboarded via incentivised bounties, giving more options for future maintainers.

The commitment is to be efficient with funding, so **any budget remaining at the end of the 12 months will be returned to the Cardano Treasury**.


The budget cost breakdown is as follows:

<details>

<summary><strong>Level 1</strong> - Foundational Basic maintenance: $330,000 for 12 months</summary>

Level 1 cost breakdown:

1. Hosting costs, infrastructure maintenance, CI-CD, security, and minimum maintenance of this (0.25 FTE) → **$90,000**
   1. $5,000 per month for hosting costs (full cost breakdown available in the following [spreadsheet](https://docs.google.com/spreadsheets/d/1RwuE1JRRwNp_-M8h5KXpyOJyS0-SVXi9k5YxvGCx_Zo/edit?gid=256167646#gid=256167646)) including Dev, QA environments for the dev each of the pillars and Preview, PreProd and Mainnet production environments&#x20;
   2. $30,000 for 12 months infrastructure maintenance
2. Repo maintainer (1 FTE QA and 1 FTE full stack engineer, split between 4 people to reduce downtime)  → **$240,000**
   1. Code reviews
   2. Ensure security
   3. CI-CD
   4. Ensure overall consistency and cohesiveness
   5. Urgent bug fixes
   6. Testing

</details>

<details>

<summary><strong>Level 2</strong> - Incentivised participation: $530,000 for 12 months (<em>Level 1 + ₳250k at 0.8</em>)</summary>

Level 2 cost breakdown:

* All in Level 1&#x20;

- **₳150,000** to be allocated organically via direct contribution on the repos

* **₳100,000** to be allocated to other open source governance tools that provide new and better ways to participate in Cardano Governance leveraging (and where possible expanding) Govtool code or Govtool APIs

</details>

<details>

<summary><strong>Level 3</strong> - Pillar active development and maintenance level: $920,000 for 12 months (<em>Level 1 + Level 2 + $630k</em>)</summary>

Level 3 cost breakdown:

1. All in Level 1
2. All in Level 2
3. Options:
   1. Active development and maintenance of all pillars:\
      Level 1 and 2 ($290k) + Overall end-to-end testing ($120k) + All the pillars (Proposals $90k + Delegation $120k + Voting $150k + Outcomes $90k + Budget discussion $60k)  → **$920,000** for 12 months (these removes the need of repo maintainers so the $240k cost is absorbed)
   2. Only one or a combination of different pillars:\
      (Any pillar combination is possible)
      1. Level 1 and 2 ($530k) + Overall end-to-end testing ($120k) + Proposals pillar ($90k) → **$740,000** for 12 months\

         <sup>_Proposals Pillar  - rendered as part of Govtool experience (0.75FTE - $90,000)_</sup>\ <sup>_This covers the costs of software engineers, QA engineers, and DevOps support for the environments related to this application. They are responsible for maintaining the application, making sure it's always operational, they need to support and make easier external contribution as well as add new features defined in the community roadmap_</sup>\


      2. Level 1 and 2 ($530k) + Overall end-to-end testing ($120k) + Delegation Pillar ($120k) → **$770,000** for 12 months\

         <sup>_Delegation Pillar  - rendered as part of Govtool experience (1 FTE - $120,000)_</sup>\ <sup>_This covers the costs of software engineers, QA engineers, and DevOps support for the environments related to this application. This application connects directly to the chain, requiring engineers with more niche skills. They are responsible for maintaining the application, making sure it's always operational, they need to support and make easier external contribution as well as add new features defined in the community roadmap_</sup>\


      3. Level 1 and 2 ($530k) + Overall end-to-end testing ($120k) + Voting Pillar ($150k) → **$800,000** for 12 months\

         <sup>_Voting Pillar - rendered as part of Govtool experience (1.25FTE - $150,000)_</sup>\ <sup>_This covers the costs of software engineers, QA engineers, and DevOps support for the environments related to this application. This application connects directly to the chain, requiring engineers with more niche skills. They are responsible for maintaining the application, making sure it's always operational, they need to support and make easier external contribution as well as add new features defined in the community roadmap_</sup>\


      4. Level 1 and 2 ($530k)+ Overall end-to-end testing ($120k) + Outcomes Pillar ($90k) → **$740,000** for 12 months\

         <sup>_Outcomes Pillar - rendered as part of Govtool experience (0.75 FTE - $90,000)_</sup>\ <sup>_This covers the costs of software engineers, QA engineers, and DevOps support for the environments related to this application. This application connects directly to the chain, requiring engineers with more niche skills. They are responsible for maintaining the application, making sure it's always operational, they need to support and make easier external contribution as well as add new features defined in the community roadmap_</sup>\


      5. Level 1 and 2 ($530k)+ Overall end-to-end testing ($120k) + Budget discussion Pillar ($60k) → **$710,000** for 12 months\

         <sup>_Budget discussion Pillar - rendered as part of Govtool experience (0.5 FTE - $60,000)_</sup>\ <sup>_This covers the costs of software engineers, QA engineers, and DevOps support for the environments related to this application. They are responsible for maintaining the application, making sure it's always operational, they need to support and make easier external contribution as well as add new features defined in the community roadmap_</sup>

</details>



***

## Further information

* [Cardano GovTool mainnet instance](https://gov.tools)
* [Preview instance](https://preview.gov.tools)
* [PreProd instance](https://pre-prod.gov.tools)
* [Constitutional Committee Portal](https://constitution.gov.tools)
* [Open Backlog](https://github.com/IntersectMBO/govtool/)
* [Open GovTool repository (voting and delegation)](https://github.com/IntersectMBO/govtool/)
* [Proposal Pillar repository](https://github.com/IntersectMBO/govtool-proposal-pillar)
* [Outcomes Pillar repository](https://github.com/IntersectMBO/govtool-outcomes-pillar)
* [GovTool Test Reports](https://intersectmbo.github.io/govtool-test-reports/)
* [GovTool open app analytics](https://analytics.gov.tools/)
* [Open Constitutional Committee Portal Repository](https://github.com/IntersectMBO/cc-portal)
* [GovTool Docs](https://docs.gov.tools)
* [GovTool Proposal Pillar API docs](https://be.pdf.gov.tools/api-docs/)
* [GovTool Outcomes Pillar API docs](https://be.outcomes.gov.tools/)
* [GovTool Voting and Delegation Pillar API docs](https://be.gov.tools/swagger-ui/#/)
* [Cardano Govtool X Account](https://x.com/cardano_govtool)
* [GovTool - a breakdown of the costs so far](https://docs.gov.tools/important-updates/govtool-maintenance-ending-soon/govtool-a-breakdown-of-the-costs-so-far)

\

