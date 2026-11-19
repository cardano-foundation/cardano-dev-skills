# ADR-000: Documenting Architecture Decisions

# Status

✅ Adopted 2022-12-17

# Context

In agile projects, architecture decisions are made incrementally rather than up front.
Large documentation is rarely read or maintained, so small, modular documents are preferable.

One of the hardest things to track during a project's life is the motivation behind certain decisions.
Without understanding the rationale, newcomers either blindly accept decisions (risking stagnation) or blindly change them (risking unintended damage).
It's better to avoid both.

# Decision

We will keep a collection of records for "architecturally significant" decisions: those that affect the structure, non-functional characteristics, dependencies, interfaces, or construction techniques.
Each record describes a set of forces and a single decision in response to those forces.

We will keep ADRs in the project wiki under https://github.com/input-output-hk/cardano-node-wiki/wiki/Architecture-Decision-Records using Markdown.
ADRs will be numbered sequentially and monotonically.
Numbers will not be reused.
If a decision is reversed, we will keep the old one around, but mark it as superseded.

Each ADR will use the following format:

- **Title** - A short noun phrase. For example, "ADR-001: Deployment on Ruby on Rails 3.0.10".
- **Status** - One of: "Proposed" 📜, "Adopted" ✅, "Rejected" ❌, "Deprecated" 🗑️, or "Superseded" ⬆️ (with a reference to its replacement).
- **Context** - The forces at play (technological, political, social, project local), described in value-neutral language.
- **Decision** - Our response to these forces, stated in full sentences with active voice. "We will ..."
- **Alternatives Considered** - Other options that were evaluated and the reasons they were not chosen.
- **Consequences** - The resulting context after applying the decision, including positive, negative, and neutral consequences.
- **References** - Links to relevant research, documentation, RFCs, or prior ADRs that informed the decision.
- **Authors** - Who proposed and approved the decision.

We should aim to keep each ADR concise.
Each ADR should be written as a conversation with a future developer, using full sentences organized into paragraphs.

# Alternatives Considered

We considered not documenting decisions at all, relying on tribal knowledge and code comments.
This fails as team composition changes and institutional memory is lost.
We also considered using a traditional architecture document, but large documents are rarely kept up to date or read.

# Consequences

The consequences of one ADR are very likely to become the context for subsequent ADRs.
Developers and project stakeholders can see the ADRs even as team composition changes over time, making the motivation behind previous decisions visible for everyone, present and future.

# References

- Michael Nygard, [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

# Authors

- John Ky (initial version)
- Mateusz Galazyn (trimmed down and added new sections)
