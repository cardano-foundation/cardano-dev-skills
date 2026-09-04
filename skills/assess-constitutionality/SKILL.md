---
name: assess-constitutionality
description: >-
  Assesses whether a Cardano governance action complies with the Constitution, for live
  on-chain actions and unsubmitted drafts alike. Produces a provision-by-provision findings
  report against the mirrored constitutional text. Triggers: "is this governance action
  constitutional", "assess constitutionality", "constitutional review", "check this proposal
  against the Constitution", "will this treasury withdrawal pass CC review", "review my
  governance action draft", "constitutional defects".
allowed-tools: Read Grep Glob
disallowed-tools: WebFetch WebSearch Bash Edit
---

<!-- Constitutional text: ${CLAUDE_SKILL_DIR}/../../docs/sources/cardano-constitution/ (see references/constitution-index.md) -->
<!-- Koios API spec: ${CLAUDE_SKILL_DIR}/../../docs/sources/koios/specs/results/koiosapi-mainnet.yaml -->

# Assess Constitutionality of a Governance Action

Work through a Cardano governance action provision by provision against the Constitution and
produce a findings report. Works on a live on-chain action or an unsubmitted draft.

This is an analytical skill, not an authority. It produces an assessment a reader can check
and disagree with, not a ruling. The Constitutional Committee rules; this skill helps someone
reason carefully before that happens, or understand it afterwards.

## When to use

- Someone asks whether a governance action complies with the Constitution
- A proposer wants to know if a draft will survive Constitutional Committee review
- A DRep is deciding how to vote and wants the constitutional question separated from the
  policy question
- A CC member or observer wants a structured first pass before writing their own analysis
- Someone needs to know which constitutional provisions a given action type even engages

## When NOT to use

- Explaining how CIP-1694 governance works mechanically, what a DRep is, or how voting
  thresholds operate — use `governance-guide`
- Deciding whether a proposal is a *good idea*. Constitutionality is not merit, and this skill
  actively refuses to conflate them
- Drafting a Constitutional Committee rationale for publication. Assessment is the input to
  that, not the artifact itself
- Querying chain data as an end in itself — use `query-chain`
- Anything requiring the skill to fetch data. It cannot. It tells the user what to run

## Key principles

1. **Constitutionality is not merit.** A wasteful, badly scoped, or unpopular proposal can be
   perfectly constitutional. A valuable and popular one can violate a provision. Every finding
   must trace to specific constitutional text. Everything else goes to open questions.

2. **Never state a finding the evidence does not support.** Findings have three states:
   Satisfied, Violated, Not-yet-verifiable. The third is a real answer and is used often,
   especially for drafts. Guessing at an on-chain fact is the primary failure mode here.

3. **Silence is not a pass.** A provision that was never examined appears in the findings table
   marked Not-yet-verifiable. Omitting it would let a reader mistake unexamined for satisfied.

4. **Always declare the basis.** Every report states which Constitution version it reasoned
   from and whether that version was confirmed current. The Constitution is amendable, and a
   confident finding drawn from superseded text is worse than no finding.

5. **Attribute interpretations.** Several provisions are genuinely ambiguous. Where the
   analysis depends on a reading rather than the plain text, say so and say what the competing
   reading would produce. Never present an interpretation as the Constitution's own words.

6. **Depth is uneven, so signal it.** Treasury withdrawals and parameter changes carry detailed
   procedure below. Other action types get correct routing and a general standards walk. Say
   which one the reader is getting rather than sounding equally confident about both.

- See [shared/PRINCIPLES.md](../shared/PRINCIPLES.md) for cross-cutting safety guidelines

## Workflow

### Step 1: Establish the subject and its stage

Determine what is being assessed and whether it is live or draft, because that decides which
provisions can be settled at all.

| Input | How to handle |
|---|---|
| Local draft file | Read it directly |
| Pasted proposal text | Assess as given; note that there is no verifiable source |
| URL | This skill cannot fetch. Ask the user to retrieve it and supply the content |
| Live action ID | Ask the user to run the lookups in `references/onchain-verification.md` and paste the results |

For a live action, do the text-based analysis first on whatever is available, then request the
on-chain data needed to close the remaining provisions. Do not stall the whole assessment
waiting for a paste.

Record the source in the report. "Pasted into conversation" is materially weaker provenance
than a verified on-chain record, and the reader should be able to see that.

### Step 2: Check the Constitution's currency

Read `references/constitution-meta.md`. Surface the mirrored version and give the user the
verification command.

Then act on the result:

- **Confirmed current** — proceed, and stamp the version in the report.
- **A newer Constitution is enacted** — stop. Report the text as superseded and do not issue
  findings from it. This is the one condition that blocks the assessment outright.
- **Not checked, or the check failed** — proceed, and stamp `Currency: unverified` in the
  report's Basis table with a sentence explaining what that means.

Never let this step pass silently. The reader must always know which text the findings rest on.

### Step 3: Identify the action type and route to provisions

Read `references/constitution-index.md`, then read **only** the line ranges the action
engages (the index maps each reference below to its range in the mirrored constitutional
text). Never load the whole document; it is large and most of it is irrelevant to any given
action.

| Action type | Sections to read | Depth |
|---|---|---|
| TreasuryWithdrawals | Article II.6, Article II.7, Appendix I.3 | Detailed, see Step 4 |
| ParameterChange | Article II.6, Article II.5, Appendix I.2, Appendix I.2.1 (always), plus the category subsection for each changed parameter | Detailed, see Step 5 |
| InfoAction | Article II.6, Appendix I.8, plus any Article I tenet the action engages | General |
| HardForkInitiation | Article II.6, Appendix I.4 | General |
| NewConstitution | Article II.6, Article I and its sections, Appendix I.6 | General |
| NewCommittee / UpdateCommittee | Article II.6, Article III and its sections, Appendix I.5 | General |
| NoConfidence | Article II.6, Article III.3, Appendix I.7 | General |

Article II.6 governance action standards apply to every type. Start there in all cases.

For the **General** rows, say so in the report: the analysis walks Article II.6 and the
applicable guardrails, and does not carry the accumulated per-provision procedure that treasury
withdrawals do. A reader deciding something consequential should treat it as a starting point.

Read `references/interpretive-positions.md` before writing any finding on Articles II.6.1,
II.7.1, II.7.2, II.7.4, II.7.5, or II.7.6. Those are the provisions where a plain reading most
often goes wrong.

### Step 4: Treasury withdrawals, provision by provision

Walk these in order. Each gets a findings row.

- **II.6.1, format and immutability.** Standardized legible format behind an immutable anchor.
  Establish whether the specific link can change before asserting a violation; see the
  interpretive position.
- **II.7.1, terms of the withdrawal.** Purpose, total ada amount, recipient, general scope.
  Deferred operational detail is not automatically a defect where an administrator holds pause
  and refund authority.
- **II.7.2, prior treasury receipts.** Disclosure in any form satisfies this. Silence is a
  reportable gap, not by itself dispositive.
- **II.7.3.** Read the section and apply it to the facts.
- **II.7.4, audit allocation.** Two prongs, both required: periodic independent financial
  audits, and implementation of oversight metrics. Read the full exploded budget before
  concluding an allocation is absent.
- **II.7.5, administrator.** Must exist at the moment of withdrawal. Check both agreement
  channels in `references/onchain-verification.md` before concluding none exists.
- **II.7.6, destination.** Three prongs, reported separately: separate auditable account, no
  stake pool delegation, delegation to the predefined `drep_always_abstain` option.
- **Net Change Limit.** One sentence affirming the withdrawal fits the limit in force. Never
  hardcode a figure; the limit is set by an Info action and changes. It becomes a finding only
  if actually exceeded.

For a draft, II.7.5 and II.7.6 are ordinarily Not-yet-verifiable, because there is no
transaction and no destination account yet. Say that plainly and put both on the verification
checklist. Do not accept a stated intention to use a particular custody pattern as satisfaction
of the provision.

### Step 5: Parameter changes, both guardrail tracks

**First, enumerate the parameters from the on-chain action, not from the prose.** The
authoritative list is the parameter map in the action's `proposal_description`, per section 1a
of `references/onchain-verification.md`. A proposal's narrative is a claim about what it
changes, and it is checked against that map, never substituted for it. An action can restate a
parameter at its current value, or touch a parameter the abstract does not mention, while
stating in terms that nothing else is changed. Both are common and neither is necessarily
improper, but a parameter absent from your list is a parameter you never assessed.

Until the map is supplied, the parameter list itself is Not-yet-verifiable. Say so, assess the
parameters the text does disclose, and put the map on the verification checklist.

Then, for each parameter in the map: two independent tracks, and most parameters appear in
both. Walking only one is the standard error.

**Track 1, the category subsection.** One of Appendix I.2.2 Economic, I.2.3 Network, I.2.4
Technical/Security, or I.2.5 Governance. Gives the per-parameter checkable limits. Cite each
guardrail by its identifier.

**Track 2, Appendix I.2.1 critical protocol parameters.** Read this for *every* parameter
change, without exception. It defines two sets with different consequences:

| Set | Triggers | Requirement |
|---|---|---|
| Critical to blockchain operation | PARAM-03a, PARAM-04a | SPO vote above 50% of active block-production stake; 90-day off-chain notice |
| Critical to the governance system | PARAM-05a, PARAM-06a | DRep yes vote above 50% of active voting stake; 90-day off-chain notice |

A parameter that looks like a "governance parameter" and appears in I.2.5 is very often *also*
in the I.2.1 critical list. Finding it in the category subsection is not a reason to stop.

Confirm in every case: PARAM-01 (the parameter is named in the Guardrails), the category
limits, the applicable critical-parameter track, and the reversion plan under Appendix I.2.6.

**Grading the reversion plan.** Appendix I.2.6 requires a plan containing two elements, and they
carry different weight. Grade them separately rather than as one pass or fail; see the
interpretive position on Appendix I.2.6 before writing the finding.

| Missing | Grade |
|---|---|
| Which parameters revert, and to what values | **Defect.** Without it there is no plan |
| Network recovery on disastrous failure, or the monitoring commitment | **Open question**, unless the escalation below applies |

Escalate the second row to a defect only when the change carries real propagation or
availability risk that the proposal has not addressed. Benchmarking supplied under MBEU-M-04a,
or a parameter that cannot affect block production at all, discharges that concern. A network
parameter changed with no benchmarking and no monitoring commitment does not.

Partial reversibility is not a defect. Appendix I.2.6 states in terms that not all changes can
be reverted, so a proposal that discloses the limits of its own revert path is complying, not
failing. Treat that disclosure as a point in its favour.

When a parameter is governance-critical only, state explicitly that PARAM-03a and PARAM-04a are
not engaged and no SPO vote is required. Showing that both tracks were considered is part of
the finding.

### Step 6: Write the report

Follow `references/report-template.md`. Write to `assessment-<slug>.md` in the working
directory, then give a short summary in conversation. Writing the file is not pre-approved, so
expect a permission prompt; if the user declines, deliver the full report in conversation
instead rather than silently shortening it.

Before writing the disposition, check the analysis against three failure modes:

- **A policy objection wearing constitutional clothes.** If a finding cannot be traced to
  quoted constitutional text, it belongs in open questions.
- **An assumption promoted to a fact.** Every Satisfied row on an on-chain provision must point
  at data the user actually supplied.
- **An interpretation stated as text.** Every reliance on `interpretive-positions.md` is
  attributed, with the competing reading noted where it would change the outcome.
- **A hedge where the floor is met.** If a provision states a requirement and the action meets it,
  the provision is Satisfied, however thin the arrangement. Recording it as contested because the
  structure is weak is a declined answer, not a careful one. See the floor principle in
  `interpretive-positions.md`, including its two limits. Move the structural concern to open
  questions at full strength and let the reader weigh it.

The disposition uses assessment language: "no constitutional defects identified", or
"constitutional defects identified under Article II.7.5", or "assessment incomplete" with the
unsettled provisions named.

The predicted verdict is one clearly labelled line, bound by two rules: it never appears
without the findings table above it, and its confidence is **low** whenever any provision is
Not-yet-verifiable. Never quote it on its own in conversation.

### Step 7: Close the loop for drafts

End every draft assessment with the verification checklist: what must be true on-chain at
submission, and how to establish each item. That checklist is the main deliverable for a
proposer, because it converts an unverifiable provision into a concrete pre-submission task.

## Independence

Apply identical scrutiny regardless of who the proposer is. Institutional standing, ecosystem
prominence, and prior successful proposals are not evidence of compliance. A well-known
organization named as administrator still needs its agreement established through one of the
two channels.

Equally, do not manufacture defects to appear rigorous. "No constitutional defects identified"
is a legitimate and common outcome, and an assessment that never reaches it is not being
careful, it is being useless.

## References

- [`references/constitution-index.md`](references/constitution-index.md) — routing table into the mirrored constitutional text
- [`references/constitution-meta.md`](references/constitution-meta.md) — mirrored version, and how to verify currency
- [`references/interpretive-positions.md`](references/interpretive-positions.md) — readings of ambiguous provisions, with reasoning
- [`references/onchain-verification.md`](references/onchain-verification.md) — commands for the user to run, and what each settles
- [`references/report-template.md`](references/report-template.md) — report structure and output rules
- See [shared/PRINCIPLES.md](../shared/PRINCIPLES.md) for safety guidelines
