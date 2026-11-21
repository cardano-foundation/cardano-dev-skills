# Govtool Builder monthly responsibilities

:::info Historical (2025)
This page documents GovTool's 2025 funding and maintenance discussion and is kept for reference. Timelines and statements on this page reflect that period, not the current state of GovTool.
:::

## For Builders handling one of the pillars

As one of the Govtool maintainers, the Builder shall carry out all the duties that are commonly connected to this role in an open source project, for projects supported by Intersect this will evolve and be refined by the Intersect Open Source Committee, they include but are not limited to:

* Reviewing and merging pull requests
* Keeping relevant documentation updated
* Participating in governance tools WG sessions
* Triaging github issues raised related to their repos and pillars
* Support **their assigned Govtool Pillar** (bugs - both tech and design, adjustments - both tech and design, preview, preprod and mainnet updates)
  * Review and validation of internal and user submitted bugs
  * Fixing bugs based on the Customers triage process (Bugs related to features out for beta testing will be categorized as: Bugs from previous SoW, Bugs related to new issues)
* Connect with other maintainers of Govtool to maintain, support, and evolve Govtool as a whole, including the Govtool wrapper
* Make their repos accessible by also supporting individual contributors or other organizations in contributing to any stage of software development
* Contribute, support and foster distribution of duties and decentralization of operations and development of Govtool
* Update Govtool pillars they are responsible for to accommodate changes coming from external components that include, but aren't limited to:
  * Other pillars
  * DBSync
  * Node
  * Standards as defined in CIPs
* Make sure Govtool pillars they are responsible for fully work on desktop, tablet and mobile (web-responsive)
* Make sure Govtool pillars they are responsible for are fully working for and on mainnet
  * Support for other test networks before mainnet (including anything related to support multinetwork)
* Make sure their Govtool pillar is ready to support initiatives related to sponsoring Cardano 1694 adoption. These include, but aren't limited to:
  * Events
  * Campaigns
  * Anything that might be useful to increase adoption
* Make sure pillars are functional and can be communicated and openly used at any public event

***

### Acceptance Criteria:

* Relevant documentation in the pillar respective repo is up to date
* Team regularly triages bugs and is participating in the bug triage sessions
* Relevant and agreed bugs and improvements are fixed and deployed
* Connection with other maintainers is kept on a regular basis
* Repo documentation for proposal discussion is improved and contributed to sufficiently
* Code in the pillar is up to date with the latest changes in the external components that include but aren't limited to:
  * Other pillars
  * DBSync
  * Node
  * Standards as defined in CIPs
* GovTool is fully working and operational without P0 and P1 issues
* Key representatives of the supplier’s team (maintainer) join and actively participate in the Intersect community open working group (as of now, governance tools working group) and work to improve its processes

## For builder handling end-to-end testing

The Builder shall provide and carry out the following:

* Develop and improve DApp level tests for GovTool on Preview, PreProd and Mainnet

### Acceptance Criteria

* Develop and execute DApp level tests for GovTool
* Potential additional services or tests are identified and documented
* Tests should include, but aren't limited to, the following:
  * Integration testing
  * System (end to end) testing
  * Performance testing
    * Load testing
    * Stress testing
    * Scalability testing
  * Security testing
    * Penetration testing
  * Regression testing
  * Smoke testing
  * Sanity testing
  * API testing
* Testing should have several forms
  * Automation testing
  * Manual testing
  * Continuous Testing: Integrating testing into the CI/CD pipeline
