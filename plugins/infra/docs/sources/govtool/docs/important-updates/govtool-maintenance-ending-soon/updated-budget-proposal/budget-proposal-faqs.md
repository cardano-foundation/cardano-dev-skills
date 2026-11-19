---
description: We will add here any question raised
---

# Budget Proposal FAQs

:::info Historical (2025)
This page documents GovTool's 2025 funding and maintenance discussion and is kept for reference. Timelines and statements on this page reflect that period, not the current state of GovTool.
:::

<details>

<summary>The cost seem high for a fully open source tool available also for community to build upon</summary>

Building an open source tools correctly does actually require more effort, especially if it's done in a decentralised way (and so is less cost-efficient than a privately owned close-source tool), because:

a. Every new feature of bug fix needs to be correctly documented and verified via different levels of quality assurance testing. This requires more time, infra-resources, and people, then just developing and deploying.\
This is needed however to make sure the tool works (especially when so many other tools depend on it) and also to allow anyone to use the open source code (keeping detailed documentation updated).

b. Also, Govtool is made of separate application, then rendered in one experience, covering the end-to-end governance process. This makes it easier for anyone to re-use and expand each application code, and make the experience more reliable by distributing and decentralising the development, so reducing risks of one builder failing and the whole Govtool going down. This however increases complexity in the development process.

c. Even more, on top of decentralised development, also the direction is decentralised, coming directly from Cardano community, channeled via the Governance tools working group, this makes of course the process longer then a close-source, privately owned mono-repo tool, built by one team with a centralised decision making point.

</details>

<details>

<summary>Will the ~$1M ($920k) be a fixed cost over the years or will it taper down?</summary>

The strategy described in the budget proposal is defined for these costs to gradually reduce over time by:

a. Expanding the pool of contributor (especially individuals) via the better and better documentation, easier paths to contribute and re-use the code (using platform like Andamio which make it easy to get rewarded), all of this also supported by the level 2 incentives (₳250k)

b. Govtool has supported Cardano community getting into full governance, enabling DRep registrations during bootstrapping phase, supporting Chang and Plomin Hard Fork ratification, and more generally providing ready solutions for other tools to interact with Cardano's Governance.\
These meant that for the past 20+ months the effort has been to add new features that were gradually coming to governance. Over the next 12 months, alongside adding improvements, refactoring will be conducted (and has already started) to make running these set of tools more efficient.

</details>

<details>

<summary>The element of "public good" and scrutiny on costs</summary>

To safeguard Cardano’s democratic legitimacy, as Cardano community, we must maintain a reliable, neutral, open-source governance set of tools, fully community-owned, non-commercial, and free to access, built as public good.&#x20;

The element of public good is mentioned because Govtool is not owned by any company and it's not built for commercial reasons. It simply has been there to support Cardano's governance since before CIP1694 was approved to act as that minimum foundational option to always keep governance participation fair.&#x20;

So, this needs more scrutiny on costs, not less, because this is everyone's tool, proposed to be funded with Cardano's treasury.&#x20;

There is always more that can be done towards that. In the proposal there is detailed description of how the money will be allocated and why, down to the individual hosting cluster. Even more, historic costs for the past 20+ months have been documented [https://tinyurl.com/4xv3vb9x](https://t.co/OFa0QnCidd)

</details>

<details>

<summary>What's included in the $5000 per month for hosting</summary>

Govtool is not just one tool, it is made of multiple applications, and the development of each of the follows common standards for reliability and quality assurance. Furthermore, Govtool provides access not only to Cardano governance on mainnet, but also on Preview and PreProd, giving more opportunities to ada holders, and dApps that rely on Govtool APIs, to test governance.

The $5000 is estimated based on an avg of the current monthly costs which cover the enviroments listed below and more.

GovTool:

* Dev environment
  * Voting and Delegation pillars dev
  * Proposal and/Budget discussion pillars dev
  * Outcomes pillar dev

- QA environment
  * Voting and Delegation pillars qa
  * Proposal and Budget discussion pillars qa
  * Outcomes pillar qa

* Preview environment (preview.gov.tools)
  * Voting and Delegation pillars preview
  * Proposal and Budget discussion pillars preview
  * Outcomes pillar preview
  * Preview instance of DB-sync

- PreProd (pre-prod.gov.tools)
  * Voting and Delegation pillars preprod
  * Proposal and Budget discussion pillars preprod&#x20;
  * Outcomes pillar preprod
  * PreProd instance of DB-sync

* Mainnet (gov.tools)
  * Voting and Delegation pillars mainnet
  * Proposal and Budget discussion pillars mainnet
  * Outcomes pillar mainnet
  * Mainnet instance of DB-sync

- CC Portal (constitution.gov.tools)
  * Mainnet

Fully detailed cost breakdown is available at the following [link](https://docs.google.com/spreadsheets/d/1RwuE1JRRwNp_-M8h5KXpyOJyS0-SVXi9k5YxvGCx_Zo/edit?gid=256167646#gid=256167646).

</details>

<details>

<summary>FTE requirements for each pillars, and complexity of the application</summary>

As mentioned above, Govtool is made of 5 separate complex application. It's development follows rigorous standards. Most of these application have created governance standards for tooling figuring out hard challenges from scratch (when on-chain governance was just a CIP). \
\
However, the most important element here is what is Govtool. As mentioned in this reply [https://tinyurl.com/2z437vpd](https://t.co/VInkne3Fq2) : Govtool is not just the user interface you see, over 90% of the effort is allocated in the open-source backend. This BackEnd is what powers a lot of the other governance tools (you can see some examples in this part of the proposal [https://tinyurl.com/58jdd3ne](https://t.co/Op7XhTJm7N))

</details>

<details>

<summary>Who is currently developing Cardano Govtool?</summary>

Who is currently developing Cardano Govtool? Cardano Govtool is NOT built by Intersect developers. Intersect had (and still has) a facilitation role in the process, first of all via the Governance tools working group (which is an Intersect working group) and with dedicated staff supporting alignment between builders.&#x20;

Govtool is developed by Community Builders such as[@LidoNation](https://x.com/LidoNation) [@Juno\_stakepool](https://x.com/Juno_stakepool) [@bynetio](https://x.com/bynetio) [@We\_Deliver\_IT](https://x.com/We_Deliver_IT) (who also submitted the info action) and by individual contributors

</details>

<details>

<summary>Is Govtool just the front end experience we see on gov.tools?</summary>

Govtool largest value is in its backend, available via open APIs&#x20;

Govtool is not just the user interface you see, over 90% of the effort is allocated in the open-source backend. This is made of 5 separate application (structured in this way to keep them reusable by other builders and reduce downtime), these are built following the best development standard (to ensure again uptime and reliability).&#x20;

And most importantly, this BackEnd is what powers a lot of the other governance tools (you can see some examples in this part of the proposal [https://tinyurl.com/58jdd3ne](https://t.co/Op7XhTJm7N))

</details>

<details>

<summary>why an open source tool is less cost-efficient than a close-source one?</summary>

[https://x.com/cardano\_govtool/status/1941099474408935772](https://x.com/cardano_govtool/status/1941099474408935772)

True decentralise open-source development is less cost-efficient than a centralised closed-source one

To safeguard Cardano’s democratic legitimacy, as Cardano community, we must maintain a reliable, neutral, open-source governance set of tools, fully community-owned, non-commercial, and free to access, built as public good.

Of course being this fully community-led and owned, and being built in the open in a decentralised way, makes it less cost-efficient, but it's necessary to meet the goal above. For reference, if Govtool was one application, closed-sourced, owned and built by one company, potentially it can be actively maintained by 4 engineers.

At the moment, Govtool is one of the only (in some cases the only) open-source community owned governance tool for Cardano. Without it community participation in governance relies on the will of closed-sourced privately owned tools (most of which need Govtool APIs to work).

\--

High standards for open-source development and access to multiple networks

Contributing to the cost and complexity are the rigorous standards Govtool development follows.

With dedicated development and quality assurance environments for each application, overall end-to-end automated testing and 3 production environments, one for each network (preview, pre-prod and mainnet), Govtool has the highest standards of development and engineering right now.\
This ensures also community access to these test neworks, allowing easier onboarding in Governance.



</details>

<details>

<summary>why does Govtool need funding if there are no protocol changes?</summary>



* Govtool is not just dependent on Cardano's protocol changes (although when they happen you need to make sure to have resources to update and test all changes). It relies on different libraries so like any other tool, to remain operational requires a minimum effort this is described mostly in the level 1 of the proposal.
* Also Govtool being community owned needs to support latest standards defined by Cardano community in CIPs.
* Even more outside of the the new features or improvements requested by the community, there are adjustments needed as governance is in its early stages still and keeps evolving.

So, in relation to effort and funding:

* To keep the tools running at least the funding of level 1 described in the proposal is needed.
* To support key updates to keep it relevant to the ever evolving Cardano governance, and so keep an foundational tool for participation, level 2 or level 3 are funding needed, depending on the speed of development the community expects. (If community feels Cardano's governance can remain easy to participate to, open and fair, only relying on privately owned tools, then no level of the proposal should be funded.)

</details>

<details>

<summary>what's in the roadmap</summary>

[https://x.com/cardano\_govtool/status/1940814666482983085](https://x.com/cardano_govtool/status/1940814666482983085)

You can see key planned (as well as delivered) initiatives here [https://tinyurl.com/4275j7w4](https://t.co/msEkcwvj5i). Important also to note that Govtool roadmap is directly defined by the Cardano community, so subject to change and evolution, so the best place to check what's coming next is the community backlog [https://tinyurl.com/dt84eyek](https://t.co/zbmLzWicEV) and the community discussion (recently started to make it easier to define direction) [https://tinyurl.com/34fs6nz3](https://t.co/KX5OroIeX1)

</details>

<details>

<summary>how will the incentives be distirbuted</summary>

As mentioned in the proposal the incentives of level 2 (₳ 250k) will be allocated via platforms like Andamio following existing open-source bounty processes, where a task is defined and if completed, and then approved and merged, the reward can be paid (in this case it will be done on-chain).\
All this is directed by the community via the Governance tools working group

</details>

<details>

<summary>the hosting costs seem high</summary>

[https://x.com/cardano\_govtool/status/1940814666482983085](https://x.com/cardano_govtool/status/1940814666482983085)

High level there are costs of 0.25 FTE to manage that process (highly complex) and costs to run Dev, QA environments for each of the applications (5) and Preview, PreProd and Mainnet production environments (Keeping Govtool one of the few places where users can interact easily with governance also on preview and preprod). The full breakdown of the devOps costs can be found in the proposal with details down to the individual AWS service, you can check here [https://tinyurl.com/5c69eczn](https://t.co/Myu25O6jP6) and here [https://tinyurl.com/ms4yfxjk](https://t.co/sps9uY4B3J)

</details>

<details>

<summary>if this Budget info action is approved how will funds delivery be tracked</summary>

[https://x.com/cardano\_govtool/status/1941106529857368094](https://x.com/cardano_govtool/status/1941106529857368094)

The Cardano Govtool budget proposal, if approved and then funded via the treasury action, will be handled via the smart contract framework Intersect will use for the 39 treasury actions that will soon be submitted on-chain.&#x20;

The community incentives will be distributed transparently on-chain with platforms like Andamio.&#x20;

Even more, along side that on-chain transparency, Govtool development is open and transparent for everyone to check and contribute to:&#x20;

* Govtool open repos [https://docs.gov.tools/participate-in-development/governance-tools-repositories](https://t.co/wvOshTC1EW)&#x20;
* Govtool discussion [https://github.com/IntersectMBO/govtool/discussions](https://t.co/C1N9Dcu8QK)&#x20;
* Govtool open backlog [https://github.com/orgs/IntersectMBO/projects/34](https://t.co/YyGPSFjBgM)

</details>

<details>

<summary>How will the Level 2 incentives be allocated and what can the community expect from those?</summary>

[https://x.com/cardano\_govtool/status/1944833643429368055](https://x.com/cardano_govtool/status/1944833643429368055)

The incentives in Level 2 are divided in 2 parts.

The first part is ₳150k. This has been proposed to incentivise more contribution to the Govtool development, especially from individuals, with the goal to make Govtool stronger and more resilient as an open-source project.\
How will it be allocated: As mentioned in the proposal, these incentives will be allocated via platforms like Andamio, following existing open-source bounty processes, where a task is defined and if completed, and then approved and merged, the reward can be paid (in this case it will be done on-chain). All this is directed by the community via the Governance tools working group. Prioritisation of task will still remain consistent to the overall process that uses the open backlog and open discussions. (this model will also open a process for sponsored features)

The second part is ₳100k. This has been expanded during the open consultation period when the budget proposal got refined. Govtool has been acting as a foundational tool for governance participation for end users as well as key infrastructure for other tools.\
The proposal behind these incentives is to encourage the creation of other tools that can provide new and better ways to participate in governance using Govtool APIs or open-source code.\
How will it be allocated: These provides new ways for the end-user to interact with governance while brining new developers to the open-source project and improving the code itself.\
In this case there will be either defined requirements that have already been requested and prioritised by the community, in this case, like above, a task will be opened and if completed a reward will be paid, OR there could be a proposal set forward by a developer, which will then be prioritised (as above) and if completed will get rewarded.

So in short, for both proposed incentives, there is the common step of collecting community input about the needs, if the need has support, it will be refined and become a task (more specifically a github issue) and then that task will be 'advertised' on platforms like Andamio (probably Andamio itself) where anyone can pick them up, and if successfully completed, get rewarded, tracking the all process transparently on-chain.

</details>

<details>

<summary>Why do we need Proposal discusson pillar and what's next for the budget proposal pillar?</summary>

[https://x.com/cardano\_govtool/status/1944833643429368055](https://x.com/cardano_govtool/status/1944833643429368055)

Whilst all pillars cover an important part of the governance process, some pillars have definitely more importance in the process than others, that is also why they have more or less resources budgeted for.

Delegation, Voting and Outcomes definitely do cover the bulk of the participation on-chain and they are critical.

Proposal discussion pillar (which might need actually a better name) is the pillar where anyone can draft a governance action in a fully guided process, discuss and get feedback (as the name suggests) and, more importantly, if the proposer is ready, it allows to submit the governance action directly to chain with checked metadata (so probably one of the safest and easiest option for anyone to submit their governance actions on-chain). This pillar, paired with co-proposing options to split the deposit cost, will further lower the barriers to participate in governance.\
Outside of these, also in the preview and preprod environments, we see heavy use of this pillar to test governance actions metadata as well as an easy way to get feedback on a governance action proposal before investing 100k deposit.

The Budget proposal pillar has enabled the first budget process to progress this year. However, being the reflection of an interim process (also developed to support community needs in 9 business days) it will need refactoring. The goal there will be to facilitate and push forward the draft CIP to create a common standard for pre-governance polling, so that they are fully handled on-chain in a common way, allowing every tool to build an experience for the end-user to participate while submitting the votes to the same source of truth.

</details>
