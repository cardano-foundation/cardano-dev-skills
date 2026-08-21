# Assessment Report Template

Write to `assessment-<slug>.md` in the working directory. Keep the section order below;
readers and reviewers rely on it.

Omit a section only when it would be empty, with one exception: the findings table is never
omitted and never abbreviated, because a missing row is indistinguishable from a passed one.

---

```markdown
# Constitutional Assessment: <title>

## Subject

| | |
|---|---|
| Action type | <TreasuryWithdrawals / ParameterChange / …> |
| Stage | Live action / Draft |
| Identifier | <gov_action1… or "not yet submitted"> |
| Source | <file path, URL as supplied by the user, or "pasted into conversation"> |
| Assessed | <date> |

## Basis

| | |
|---|---|
| Constitution | enacted epoch 609, anchor hash `b368bd…` |
| Currency | Confirmed current / Unverified |
| On-chain record | Supplied and assessed / Not supplied / Not applicable (draft) |

<If currency is unverified, one sentence: the assessment rests on the snapshot above and a
newer Constitution may have been enacted since.>

## Findings

| Provision | State | Basis |
|---|---|---|
| Article II.6.1 | Satisfied | <what establishes it> |
| Article II.7.4 | Violated | <the specific failure> |
| Article II.7.6 | Not yet verifiable | <what is missing and why> |

## Analysis

<One subsection per provision that is Violated or Not-yet-verifiable, and per provision whose
satisfaction was not obvious. Quote the operative language, apply it to the facts, state the
conclusion. Where the outcome turns on a reading from interpretive-positions.md, attribute it
and state what the competing reading would produce.>

<Satisfied provisions that were straightforward need one line each in the table and no
subsection. Do not pad.>

## Open questions

<Matters a voter may reasonably weigh that are not constitutional defects: scope, bundling,
conditionality, value for money. Labelled clearly as not constitutional findings.>

## Disposition

<Assessment language. "No constitutional defects identified." / "Constitutional defects
identified under Article II.7.5." / "Assessment incomplete: II.7.5 and II.7.6 could not be
settled without the on-chain record.">

**Predicted verdict:** <A Constitutional Committee applying this analysis would likely find
the action Constitutional / Unconstitutional.> <Confidence: high / moderate / low, with the
reason.>

## Verification checklist

<Drafts, and live actions with unsupplied on-chain data. Each item states what must be true
and how to establish it. See onchain-verification.md.>

- [ ] Withdrawal destination is a separate account, not delegated to any stake pool, and
      delegated to the predefined `drep_always_abstain` option (II.7.6)
- [ ] Administrator has publicly agreed, via transaction witness or verified CIP-100 author
      signature (II.7.5)
- [ ] Anchor is immutable and its content hashes to the on-chain `meta_hash` (II.6.1)
- [ ] Withdrawal fits within the Net Change Limit currently in force
```

---

## Rules for the predicted verdict

The predicted verdict is the line most likely to be quoted in isolation and the line most
likely to be wrong. Constrain it:

- It never appears without the findings table above it in the same document. Never state it
  alone in conversation.
- Confidence is **low** whenever any provision is Not-yet-verifiable. Name which ones.
- It is a prediction about how a committee would rule, not a ruling. Never write that an
  action "is unconstitutional"; write that defects were identified under a named provision.
- When the prediction turns on an interpretive position, say so and give the alternative.

## Rules for the findings table

- Every engaged provision gets a row. A provision examined and found satisfied is a row; a
  provision never examined is a row marked Not-yet-verifiable.
- Three states only: Satisfied, Violated, Not yet verifiable. No "probably", no "likely
  satisfied". If it is uncertain, it is Not-yet-verifiable and the Basis column says what
  would settle it.
- The Basis column cites what establishes the state: a quoted term from the proposal, a field
  from a supplied on-chain record, or the specific absence relied on.
