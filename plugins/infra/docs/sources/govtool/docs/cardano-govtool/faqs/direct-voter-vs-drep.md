---
description: What is the difference?
---

# Direct Voter vs DRep

Direct voters are a concept that GovTool adds on top of the on-chain DRep mechanism. Direct Voters are not explicitly supported by the protocol but are instead an abstraction over the on-chain DReps.

Like DReps a Direct Voter is someone that can vote on any Governance Action with their own Voting Power. They do not wish to campaign for delegations from others or be shown via the DRep Directory.

GovTool considers (on-chain) DReps who do not wish to attach metadata to their DRep as Direct voters. The rationale being, those who wish to vote but not represent others are unlikely to want to attach metadata to their registration. They do not wish to be a 'representative'.

Other tools likely show Direct Voters as DReps, as on-chain they are.

The idea of a direct voter came out of user tests for GovTool, where calling everyone who just wants to vote a 'delegated representative' caused much confusion. Direct voter concept aims to reduce the potential for this confusion.
