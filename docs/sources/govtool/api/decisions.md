# Decisions

Decisions made by the user about the GovTool data-layer spec, recorded verbatim
in substance, with what each one means for implementation and what else follows
from it.

Append-only. Newest section at the bottom. Every entry is dated and numbered so
a later entry can amend an earlier one by number rather than by editing it.

---

## D1 — Protocol parameters are a typed subset, not a raw row

**Date:** 2026-09-21
**Said:** "Typed subset."
**Context:** `/epoch/params` currently returns a raw `cardano-db-sync`
`epoch_param` row — 60 snake_case columns including `block_id`,
`cost_model_id`, `extra_entropy`.

### What it means for implementation

- `ProtocolParams` becomes a named, camelCase, provider-neutral type in
  `@govtool/data-providers/chain-data`.
- db-sync bookkeeping columns (`id`, `block_id`, `cost_model_id`,
  `extra_entropy`, `nonce`) are **not** in the contract. They are row identity,
  not protocol parameters.
- The db-sync provider must now **map** rather than pass through. This is new
  work in `govtool-provider-dbsync` that did not exist before.
- The GovTool backend must translate the contract shape back to the legacy
  snake_case wire shape, or the frontend must migrate. That is a separate
  decision — see OPEN-1.

### What follows from it

- `/epoch/params` was the **only** route whose response body was
  provider-shaped. After D1 there is no provider-shaped body left in the
  contract. The "swappable provider" claim becomes true rather than nearly true.
- Any field a provider cannot compute is `undefined` under the existing rule
  (`undefined` = provider structurally cannot serve; `null` = known absent on
  chain). Subsetting does not change that rule.

---

## D2 — Contract types are a minimum shape; providers may return more

**Date:** 2026-09-21
**Said:** "When implementing interface we say that the function returns a class
that extends the interface so the provider is allowed to add as many more
fields."

### What it means for implementation

- Every entity in the contract is a **floor, not a ceiling**. A provider that
  has more data may return it.
- Mechanism is **structural typing via interface extension**, not runtime
  classes:

  ```ts
  // contract
  export interface ProtocolParams { epoch: EpochNo; /* … */ }

  // provider
  export interface KoiosProtocolParams extends ProtocolParams {
    readonly koiosExtendedField: string;
  }
  export class KoiosNetworkApi implements NetworkApi {
    getProtocolParams(): Promise<Envelope<KoiosProtocolParams>> { /* … */ }
  }
  ```

- This compiles today with no contract change: TypeScript method return types
  are **covariant**, so a provider may declare a more specific return type while
  consumers written against `NetworkApi` see only `ProtocolParams`.
- Use `interface … extends`, not `class … extends`. The contract package is
  types-only with zero runtime dependencies, and these values arrive as parsed
  JSON or SQL rows — plain objects. Making them class instances would add
  construction the wire does not have and buy nothing.
- Providers **export** their extended interface so a consumer that deliberately
  couples to one provider can name the type.

### What follows from it

- **The hazard this creates, and the rule that contains it.** Types hide extra
  fields; `JSON.stringify` does not. If the backend forwards a provider object
  straight to the browser, provider-specific fields reach the frontend at
  runtime even though no type admits them — and the frontend can start
  depending on a db-sync-only field. That is exactly the coupling D1 removes.
  **Rule: the GovTool backend serializes only contract fields on any response
  the frontend reads.** Extensions are for provider-aware code, not for the
  browser.
- Extension and optionality are different mechanisms and compose cleanly:
  optional (`?`) = "the contract knows this field, this provider may lack it";
  extension = "the contract does not know this field, this provider has it".
- This makes subsetting (D1) safe rather than lossy. Cutting a field from the
  contract no longer destroys it — a provider that has it can still expose it.
  D1 and D2 are one decision in two halves.
- A provider must never **narrow**: it cannot drop a required contract field or
  retype one. Extension is additive only. TypeScript enforces this.

---

## F1 — Correction of record: the frontend reads every governance threshold

**Date:** 2026-09-21
**Status:** finding, not a decision. Supersedes a number stated earlier in the
conversation.

Earlier the frontend was measured as reading **11 of 60** `epoch_param` fields.
That count was wrong. It was produced by grepping `epochParams.<field>` and so
missed **dynamic indexing**.

`src/utils/getGovActionVotingThresholdKey.ts` maps
`(governance action type, voter type) → threshold key` and the caller then reads
`protocolParams[key]`. The keys are the governance thresholds:

```
dvt_committee_normal          dvt_committee_no_confidence
dvt_hard_fork_initiation      dvt_motion_no_confidence
dvt_p_p_economic_group        dvt_p_p_gov_group
dvt_p_p_network_group         dvt_p_p_technical_group
dvt_treasury_withdrawal       dvt_update_to_constitution
pvt_committee_normal          pvt_motion_no_confidence
pvt_hard_fork_initiation      pvtpp_security_group
```

### What follows from it

- The thresholds are **not optional extras**. They are load-bearing: every
  governance action detail screen renders a threshold bar from them.
- They belong in `ProtocolParams`, which is where the ledger puts them.
- Do not attempt to subset the threshold set. A missing key is a blank
  threshold bar on whichever action type maps to it.
- **Method note for the rest of this spec work:** a static-property grep
  undercounts. Check for dynamic indexing (`obj[key]`) before claiming a field
  is unused. Any future "the frontend only uses N of M" claim in this effort
  must be verified the same way before it drives a cut.

---

## D3 — This spec is for PROVIDERS serving the GovTool backend

**Date:** 2026-09-21
**Said:** "note that the spec is for the backend, not frontend. This spec is to
be followed by all the providers that want to give the governance api to the
govtool backend. so the backend itself should use camelcase."

### What it means for implementation

- **Audience is a provider implementer**, not a frontend developer. The spec's
  job is to tell someone building a new governance data source exactly what to
  serve so the GovTool backend can consume it.
- **camelCase throughout the contract and the backend.** No snake_case anywhere
  in the contract surface.
- Whatever the backend serves the *browser* is the backend's own business and
  **out of scope for this spec**. The legacy snake_case wire shape is a backend
  translation concern, documented where the backend is documented.
- OPEN-1 is therefore closed: the question "does the frontend migrate?" is not
  this spec's question.

### What follows from it

- Frontend usage evidence changes role. It is evidence about **what data must
  exist and be correct**, never about what the contract should be *shaped* like.
  "The frontend reads 2 of 4 totals" is an argument about priority, not an
  argument for a two-field type.
- The spec should be readable by someone who has never seen GovTool's frontend
  and does not have the repo open. It must define terms (DRep, governance
  action, tally, stake basis) rather than assume them.
- A conformance suite a third party can run against their own implementation
  becomes the natural acceptance test. "Does it satisfy the spec" has to be
  answerable without access to GovTool internals.
- **Incomplete sentence in the source message** ("We are") — nothing inferred
  from it. Flagged for the user to finish if it carried a further instruction.

---

## D4 — Governance thresholds are exact ratios, not floats

**Date:** 2026-09-21
**Said:** "Ratio {numerator, denominator}"
**Context:** Recommendation was `number`, on the grounds that all three known
sources serve IEEE-754 doubles. User chose exact. Decision stands.

### What it means for implementation

- `dvt*` / `pvt*` threshold fields are typed
  `Ratio = { numerator: number; denominator: number }`, matching the ledger's
  `UnitInterval`.
- **This is now a provider obligation, and it is real work.** The current Koios
  mapper explicitly refuses this conversion — `network.mapper.ts` says the
  values "arrive as IEEE-754 doubles (`0.67`, `0.51`)" and that reconstructing
  a ratio "would be a guess that a UI would then render as fact". Under D4 that
  refusal is no longer available.
- The spec must therefore say **how** a provider gets an exact ratio:
  1. **Preferred** — read it from a source that carries the rational directly
     (ledger `gov-state` / `cardano-cli` style output). No reconstruction, no
     caveat.
  2. **Permitted fallback** — reconstruct from the float by bounded-denominator
     rational approximation (continued fractions / Stern–Brocot, denominator
     cap in the low thousands). Real governance thresholds are rationals with
     small denominators (51/100, 67/100, 75/100), so this recovers the true
     value for every realistic setting.
  3. A provider using the fallback **declares a `precisionLoss` caveat**. The
     value is exact-looking; the provenance is not.
- Providers must not invent a denominator per value (e.g. `0.67 → 67/100` by
  string formatting). The algorithm has to be specified in the spec so two
  providers reconstructing the same float agree.

### What follows from it

- `Ratio` becomes load-bearing rather than decorative, so it needs stated rules:
  is it required normalized (gcd-reduced)? Is `denominator: 0` illegal?
  Equality comparison across providers depends on both.
- This raises the bar for a new provider. Worth stating plainly in the spec's
  conformance section rather than letting an implementer discover it.

---

## D5 — Pillar 1 scope

**Date:** 2026-09-21
**Said:** "get protocol params must be implemented by providers. epoch is
optional. get treasury looks useful." Selected: `getTreasury`,
`getProtocolParams({ epoch })`. Not selected: `listEpochs` / `listBlocks`.

### What it means for implementation

| Route | Status |
|---|---|
| `getNetworkInfo` | **required** |
| `getProtocolParams()` | **required** — every provider must serve it |
| `getProtocolParams({ epoch })` | **optional** — past-epoch lookup may be refused |
| `getTreasury` | **optional** — kept; only Koios serves it today |
| `getStakeDistribution` | see OPEN-3a |
| `listEpochs` / `listBlocks` | **cut** — nothing uses them, nothing planned does |

- `getProtocolParams` being required means it is a **non-optional method** on
  `NetworkApi`. A source that cannot serve protocol parameters is not a GovTool
  provider.
- The `epoch` argument being optional is a *capability*, not a separate method:
  same method, and a provider may throw `CAPABILITY_UNSUPPORTED` when an epoch
  is supplied. This needs a name in the capability table.

### What follows from it

- Cutting `listEpochs` / `listBlocks` sets a precedent worth naming in the
  spec: **GovTool is not a block explorer.** Chain data is in scope only where
  a governance decision depends on it. This is the test to apply to every
  later pillar.

---

## F2 — What the four governance stake totals are for

**Date:** 2026-09-21
**Status:** finding, answering the user's question "What are the other 2 values
in stake distribution, are they any useful?"

`StakeDistribution` carries six fields, not four:

| Field | Meaning |
|---|---|
| `totalActiveStake` | epoch-boundary snapshot. **The only valid tally denominator.** |
| `totalLiveStake` | current total, moves within the epoch. Never a tally denominator. |
| `totalStakeControlledByDReps` | delegated to registered DReps. Frontend reads this. |
| `totalStakeControlledBySPOs` | delegated to pools. Frontend reads this. |
| `alwaysAbstainVotingPower` | delegated to the predefined *always abstain* target. |
| `alwaysNoConfidenceVotingPower` | delegated to the predefined *always no confidence* target. |

**The last two are tally arithmetic, not decoration.** Under Conway, stake
delegated to `alwaysAbstain` is excluded from the denominator when DRep
thresholds are evaluated, and `alwaysNoConfidence` stake acts as a standing No.
A percentage computed without them is not the number the ledger decides by.

- The frontend not reading them is consistent with its current tally bars being
  indicative rather than authoritative.
- If the Governance Outcomes pillar is to explain *why* an action passed or
  failed, both become required.
- **To verify before implementing tally math:** the exact treatment of
  `alwaysNoConfidence` (believed: votes No on all actions, Yes on
  no-confidence motions) should be confirmed against the Conway ledger spec,
  not taken from this document.
- Keep `totalActiveStake` and `totalLiveStake` separate. Collapsing them
  invites using the wrong denominator.

---

## Open questions

- **OPEN-1** — ~~legacy wire shape~~ **CLOSED by D3.** Out of scope; the spec
  is for providers, the browser shape is a backend concern.
- **OPEN-2** — ~~threshold typing~~ **CLOSED by D4.** `Ratio`.
- **OPEN-3** — ~~pillar 1 scope~~ **CLOSED by D5**, except:
- **OPEN-3a** — `getStakeDistribution`: which of the six fields are required
  and which optional? Bears on whether Blockfrost can ever run GovTool, since
  it has only `totalActiveStake`.
- **OPEN-4** — `Ratio` rules: gcd-normalized or not? Is the
  bounded-denominator reconstruction algorithm specified normatively, and with
  what denominator cap? (Raised by D4.)

---

## D6 — Required-ness follows the displayed computation

**Date:** 2026-09-21
**Said:** "live is always optional. alwaysAbstainVotingPower /
alwaysNoConfidenceVotingPower they are useful and keep them optional. note that
we need to show the threshold in the voting, how much have not voted, how much
voted yes and no abstain etc. for that we need the totals. The field that is
required to calculate it must be required. others are optional. But we may make
the voting progress/stats itself optional for certain providers if blockfrost
can't support them."

### The rule

**A field is required when a displayed computation cannot be done without it.
Everything else is optional. And the computation itself may be an optional
capability that a provider declines as a whole.**

This is the general test for the rest of the spec, not a statement about
`StakeDistribution` alone. Apply it per pillar.

### What it means for `StakeDistribution`

| Field | Status |
|---|---|
| `totalActiveStake` | required — the only valid tally denominator |
| `totalLiveStake` | **always optional** (explicit) |
| `totalStakeControlledByDReps` | optional |
| `totalStakeControlledBySPOs` | optional |
| `alwaysAbstainVotingPower` | optional — "useful, keep optional" (explicit) |
| `alwaysNoConfidenceVotingPower` | optional — "useful, keep optional" (explicit) |

### F3 — Why that is consistent, which was not obvious

The per-action voting breakdown does **not** read `StakeDistribution`. It reads
`RoleTally`, which already carries its own denominator:

```ts
interface RoleTally {
  role: VoterRole;
  stake?: Record<VoteChoice, Lovelace>;   // yes / no / abstain
  notVotedStake?: Lovelace;
  totalEligibleStake?: Lovelace;          // the denominator, active basis
  threshold?: Ratio;
  passing?: boolean;
}
```

So the two concerns separate cleanly:

- **`StakeDistribution`** = network-wide dashboard totals. Nothing computes a
  threshold bar from it. Hence: mostly optional, as decided.
- **`RoleTally`** = the per-action math. **This is where D6 bites.** Under the
  rule, `stake`, `notVotedStake`, `totalEligibleStake` and `threshold` are the
  fields a threshold bar cannot be drawn without — so they are required *when
  the tally is served at all*.

### What follows from it

- **Two-level conformance.** A capability may be declined wholesale, but not
  served half-filled. "Serve the voting stats, or declare that you do not —
  do not serve a tally with no denominator." This is a stronger and simpler
  rule than per-field optionality, and it is what makes a degraded provider
  detectable instead of silently wrong.
- `RoleTally`'s fields are all optional in the current contract. Under D6 that
  is wrong and must change: they become required within an optional unit.
- Blockfrost is the test case. It can serve tallies as head-counts but not as
  stake. Under D6 it declines the stats capability rather than serving a
  count-shaped tally that a UI renders with an ada sign.
- Open: what is the **unit** that gets declined — the whole `getTallies` route,
  the `tallies` expand on a proposal, or a named "voting stats" feature? See
  OPEN-5.

---

## Process note — no form widgets

**Date:** 2026-09-21
**Said:** "Pls just ask me questions and end the conversation. I'll type in
detail. I hate this fill-in form you are showing via tool."

Ask questions in prose and stop. Do not use the multiple-choice question tool
for spec decisions in this effort.

---

## Open questions (updated)

- **OPEN-3a** — ~~stake distribution~~ **CLOSED by D6.**
- **OPEN-4** — `Ratio` rules. Proposed and awaiting veto: gcd-normalized,
  `denominator: 0` illegal, exact-from-source preferred, bounded-denominator
  reconstruction (cap ~1000) permitted with a `precisionLoss` caveat.
- **OPEN-5** — What unit does a provider decline when it cannot serve voting
  stats: the `getTallies` route, the `tallies` expand, or a named capability?
- **OPEN-6** — Unfinished sentence in the D3 source message ("We are").

---

# Pillar 2 — Proposals / governance actions

## D7 — The typed body is required for all seven action types

**Said:** "We need typed body for all the types of proposals."

- `GovAction.body` becomes **required**, not optional, and the discriminated
  union must cover all seven: `ParameterChange`, `HardForkInitiation`,
  `TreasuryWithdrawals`, `NoConfidence`, `UpdateCommittee`, `NewConstitution`,
  `InfoAction`.
- **`rawBody?: unknown` is dropped from the contract.** It is provider-shaped
  by definition, and D1 removed the last provider-shaped body. A provider that
  wants to expose its own rendering adds it as an extension field under D2.
- Consequence: "I can serve the proposal but cannot say what it proposes" stops
  being a conformant position. A source that cannot decode the action
  description cannot serve proposals at all.
- This is the strictest requirement in the spec so far. It should be stated
  plainly in the conformance section, because it is the one most likely to
  block a new provider.

## D8 — Lifecycle is returned and must be filterable at the provider

**Said:** "lifecycle can be infered, but needs to be filterable directly by the
interface provider so they may as well return it."

- `lifecycle` / `status` is **returned on the entity** even though a consumer
  could infer it from the epoch stamps.
- More important: the **`status` filter is a required query parameter**, applied
  by the provider. A provider must not accept `status` and ignore it, and must
  not require the consumer to fetch everything and filter in memory.
- Rationale as given: if the provider has to support filtering by it anyway,
  returning it is free.
- This makes `status` the first parameter the spec requires to be *honoured*
  rather than merely accepted. The `ignored` failure mode (accepted and
  silently not applied) is non-conformant here.

## D9 — `proposedBy` is removed; `depositReturnAddress` stays

**Said:** "depositReturnAddress is useful, but there is no proposedBy in the
transaction field."

- Correct, and confirmed in the code: the Koios mapper does
  `proposedBy: row.return_address` — **the same value as
  `depositReturnAddress`**. One field wearing two names.
- The Conway `proposal_procedure` is `[deposit, reward_account, gov_action,
  anchor]`. There is no proposer identity on chain. The reward account is the
  closest thing, and it is already `depositReturnAddress`.
- **Remove `proposedBy`.** Keep `depositReturnAddress`. Keep `deposit`.
- Lesson worth carrying: a field that a provider fills by aliasing another
  field is a contract bug, not a feature. Worth grepping for others.

## D10 — Chain data serves the anchor, never the resolved document

**Said:** "we do need the offchain anchor and dataHash. the offchain_data is not
required. that is to be handled by our separate metadata service."

- `GovAction` carries **`anchor: Anchor`** (`{ url, dataHash }`) — both on-chain
  values, both required.
- **`metadata: MetadataProjection<GovActionMetadataBody>` is removed** from the
  chain-data entity. Resolution, hash verification, CIP validation and caching
  belong to the metadata service.
- Clean swap: `Anchor` already exists as a type.
- This hardens an existing principle into a structural fact. The old rule was
  "the Chain Data API never fetches a url" — but it still carried the *result*
  of a fetch, so a provider that resolved metadata itself (Koios does) leaked
  across the boundary. After D10 there is nothing to leak into.
- Applies to **every** anchored entity, not just proposals: DReps (CIP-119),
  votes (CIP-100), the constitution. Same treatment, same reason.
- A provider that happens to resolve metadata may still expose it as an
  extension under D2 — it just is not the contract's business.

## D11 — Voter context: required per-action, optional in bulk

**Said:** "for myvote, we might need to provide optional support to attach drep
id to the query so that the response contains the action of the current
connected wallet on the proposal… I want it as flag so that if provider doesn't
support adding extra interaction done by the drep_id, we can simply not show the
voted by me/not_voted tab at all in the ui. (note that vote status of specific
governance action is required) which means we can bruteforce this with multiple
api calls but we want the provider to do it efficiently or declare that this
can't be done." / "provider should declare to support the voter context on the
interface if it doesn't, i already said what we do."

Two tiers, and the split is the whole point:

| | Requirement |
|---|---|
| **Vote status for one voter on one action** | **REQUIRED.** Brute-forceable one call at a time, so no provider has an excuse. |
| **Voter context on a LIST query** (annotate/filter a page by voter) | **OPTIONAL, declared.** This is the efficiency claim. |

- A provider that declines the list-level capability makes GovTool **hide the
  "voted by me / not voted" tabs entirely** — not fall back to N+1 calls, not
  show an empty tab.
- So the capability flag is not advisory. It drives whether a UI control exists.
- The declared unit is "voter context on the proposal list". It must be
  declarable independently of the tally capability (D6) — a provider may have
  one and not the other.

## D12 — `protocolParamsAtSubmission` is optional, with a three-tier fallback

**Said:** "protocolParamsAtSubmission is also optional for protocol param
change, as we have another api to fetch it. the provider may decide to send it
together, or ignore it, in that case, we will use the another api
getProtocaolParams(epoch), but if that is also not supported, we simply show
what they want to change to."

Degradation ladder, to be stated normatively in the spec:

1. Provider embeds `protocolParamsAtSubmission` → full before/after diff.
2. Provider omits it, but supports `getProtocolParams({ epoch })` (optional per
   D5) → consumer fetches and builds the diff itself.
3. Neither → **show only the proposed values.** Not an error, not an empty
   state; a legitimate degraded rendering.

- Confirms the D6 pattern: an optional capability with a *specified* degraded
  behaviour, rather than an optional field that leaves the consumer guessing.
- **Unresolved:** `protocolParamsAtEnactment` was not mentioned. It serves a
  different purpose (what the params became, for historical outcomes) and the
  ladder above does not obviously cover it. See OPEN-7.

## D13 — Sorting: two mandatory, the vote-derived ones declared

**Said:** "sorting will be declared by the provider mandatory are newest,oldest
(soon to expire already comes from newest so I am not sure on that. most yes
votes and highest partitions are optional provider may declare"

- **Mandatory:** `newest`, `oldest`.
- **Optional, provider-declared:** `mostYesVotes`, `highestParticipation`.
  Both require the tally to order by, so a provider that declines the stats
  capability (D6) cannot offer them. The two capabilities are linked.
- **`soonestToExpire` — undecided**, user unsure. See F4 for the fact needed.

## F4 — Is `soonestToExpire` the same ordering as `oldest`?

**Almost, but not identically, and the exception is real.**

`expiryEpoch = submissionEpoch + govActionLifetime`. If `govActionLifetime` is
the same for every action in the set, then ordering by expiry is exactly
ordering by submission, and `soonestToExpire` ≡ `oldest`.

But `govActionLifetime` is a **protocol parameter**, changeable by an enacted
`ParameterChange`. Once it changes, actions submitted before and after the
change carry different lifetimes, and the two orderings diverge: a newer action
with a shorter lifetime can expire before an older one with a longer lifetime.

So:

- On a set submitted entirely within one lifetime regime — the normal case —
  the two sorts are interchangeable.
- Across a lifetime change, they are not, and `oldest` would show a misleading
  "expiring soon" order.
- The divergence is rare, silent, and appears exactly on the screen where
  urgency matters.

**Recommendation:** keep `soonestToExpire` as a distinct mandatory sort. It is
cheap for a provider that has `expiryEpoch` (it is an ORDER BY on a column the
entity already carries), and aliasing it to `oldest` bakes in an assumption
that a governance action can invalidate. Awaiting the user's call.

---

## Open questions (updated)

- **OPEN-4** — `Ratio` rules: gcd-normalized, `denominator: 0` illegal,
  exact-from-source preferred, bounded reconstruction (cap ~1000) with a
  `precisionLoss` caveat. Proposed, awaiting veto.
- **OPEN-5** — What unit is declined when voting stats are unsupported: the
  `getTallies` route, the `tallies` expand, or a named capability?
- **OPEN-6** — Unfinished sentence in the D3 source message ("We are").
- **OPEN-7** — `protocolParamsAtEnactment`: keep, drop, or fold into D12?
- **OPEN-8** — `RoleTally` stake vs head-count. DReps and SPOs are decided by
  stake, the committee by head-count. Does `RoleTally` carry both (as now), or
  does the role determine which is meaningful and the other is absent?
- **OPEN-9** — Route surface: do `getTallies` (per-action, when tallies ride
  inline on `get`), `listActivity` (lifecycle feed — no provider serves it
  fully), `listByTx`, and `getEnacted` each earn a place?
- **OPEN-10** — `soonestToExpire`: distinct mandatory sort, or aliased to
  `oldest`? See F4.

---

## D14 — Both protocol-param snapshots are optional (amends D12, closes OPEN-7)

**Said:** "at enactment they become the value they set… since the protocol
params may change during the period of voting, that view may change so even
params at submission may not be that useful if provider gives us filtering by
epoch. so i think the useful data may be params before_proposal, whichever is
the last param, but for expired, it becomes weird. so i think we can make both
optional and provider may chose to return or not return it."

- **`protocolParamsAtEnactment` is derivable, not independent data.** For a
  `ParameterChange`, the enacted params are the previous params plus the delta
  in the body. A consumer holding the body and the prior params can compute it.
  Asking a provider for it was a bad question.
- **`protocolParamsAtSubmission` is weaker than it looks.** Protocol parameters
  can change *during* the voting period, so the params at submission are not
  necessarily the params the action will be judged against. It is one snapshot
  of a moving value, not the authoritative one.
- The genuinely useful thing would be **"the params in force immediately before
  this action takes effect"** — but for an action that **expired** or was
  **dropped**, that moment never happens, so the field is ill-defined for two
  of the five lifecycle states.
- **Decision: both fields optional.** A provider may return either, both or
  neither. The D12 degradation ladder still applies when neither is present:
  fall back to `getProtocolParams({ epoch })`, and failing that show only the
  proposed values.
- Design note this exposes: a field whose meaning depends on lifecycle state is
  a smell. If a "params before effect" field is ever added, it must be `null`
  for `expired` and `dropped` by definition, not merely absent.

## D15 — "Tally" is renamed "vote aggregate"

**Said:** "ok for tally we use the term vote aggregate."

- `RoleTally` → `VoteAggregate` (or `RoleVoteAggregate`), `getTallies` →
  `getVoteAggregates`, `expand: 'tallies'` → `expand: 'voteAggregates'`.
- Rename is spec-wide and includes prose, capability names and caveat text.

## D16 — A vote aggregate declares its representation: percent | stake | count

**Said:** "Provider declare supported percent | stake | count, documenting that
stake is prefered with the totals of the stake at that time. so we show what is
available we might need to allow provider to return the totals during that
time."

- A provider **declares which representations it can express**: `percent`,
  `stake`, `count`. Not mutually exclusive — a provider may support several.
- **`stake` is the preferred representation** and the spec says so explicitly.
  It is what the ledger decides by for DReps and SPOs.
- `percent` is its own representation, not a derived convenience: a source may
  publish only percentages with no absolute figures behind them.
- **The totals must be the totals at that time**, not current totals. A vote
  aggregate carries the denominator as it stood for that action, so a
  percentage is reproducible after the fact. Using today's total stake as the
  denominator for a concluded action silently produces a different number than
  the one the ledger used.
- The consumer renders whatever is available. A UI must switch on the declared
  representation, never assume stake — rendering a `count` with an ada prefix
  is the exact failure D6 exists to prevent.
- This supersedes the old `RoleTally` shape, which carried `stake?` and `count?`
  side by side with no statement of which was meaningful.

## D17 — `listByTx` is cut

**Said:** "no need of this api nobody uses this."

Removed from the contract.

## D18 — `getEnacted` is compulsory, and it is a transaction-construction API

**Said:** "getEnacted(type), is also maybe useful, but it should come more as the
chain param. as prev gov action. This is important api (when we are construing
transaction ourself) Because the transactions requires the prev_gov_action_id
(some types don't need it. for the proposal types that require it, they must
implement it), but we can make it optional, and that will mean we can't submit
the proposals from the provider. (so just make it compoulsary)"

- **Compulsory.** A provider must serve it.
- **Reframed: this is not a display feature.** It exists because constructing a
  governance action transaction requires `prevGovActionId` — the id of the last
  enacted action in the same lineage. Without it GovTool cannot submit
  proposals at all, which is why "optional" was rejected.
- The old framing ("the currently enacted action of a type, for what is in
  force now") undersold it. The frontend never calling the existing route is
  therefore not evidence against it — transaction building moved client-side
  over CIP-30/95 and needs exactly this value.

### F5 — It is keyed by lineage, not by action type

Conway groups governance actions into **purposes**, and `prevGovActionId` is per
purpose, not per type:

| Purpose | Action types in the lineage | Needs `prevGovActionId` |
|---|---|---|
| `PParamUpdate` | `ParameterChange` | yes |
| `HardFork` | `HardForkInitiation` | yes |
| `Committee` | `UpdateCommittee` **and** `NoConfidence` | yes |
| `Constitution` | `NewConstitution` | yes |
| — | `TreasuryWithdrawals` | **no** |
| — | `InfoAction` | **no** |

Consequences for the signature:

- **`UpdateCommittee` and `NoConfidence` share one lineage.** Asking for the
  enacted head of either must return the same answer — the last enacted
  committee-affecting action, whichever of the two types it was. A naive
  per-type implementation returns the wrong id here, and the resulting
  transaction is rejected by the ledger.
- Five of seven types need it; `TreasuryWithdrawals` and `InfoAction` do not.
  The method should either be keyed by purpose, or accept a type and resolve
  the purpose internally — but the spec must state the lineage mapping so two
  providers cannot disagree.
- Returning `null` is legitimate and means "no action of this lineage has ever
  been enacted", which is the genesis case and must be distinguishable from
  "provider could not tell".
- **To verify against the Conway ledger spec before implementation:** the exact
  purpose grouping above, in particular that `NoConfidence` and
  `UpdateCommittee` share the `Committee` lineage.

## D19 — Status filtering is opt-in and declared (amends D8)

**Said:** "the status filter. order is required, filter by status is not
compulsary but opt-in. but provider should say whether or not it supports it."

**This amends D8**, which had made the `status` filter required and
provider-honoured.

- **Sorting is required.** Ordering is not negotiable.
- **Filtering by status is optional**, and the provider **must declare** whether
  it supports it.
- The `lifecycle` / `status` value itself is still **returned on the entity**
  (D8 unchanged on that point) — so a consumer can always filter in memory if
  the provider declines to.
- The `ignored` failure mode remains non-conformant: a provider that does not
  support the filter must **declare it and reject it**, never accept it and
  silently return unfiltered results.
- Practical effect: db-sync, whose proposal list is live-only by construction,
  stays conformant by declaring it supports only `status: ['live']` — an
  honest restriction rather than a silent one.

---

## Open questions (updated)

- **OPEN-4** — `Ratio` rules: gcd-normalized, `denominator: 0` illegal,
  exact-from-source preferred, bounded reconstruction (cap ~1000) with a
  `precisionLoss` caveat. Proposed, still awaiting veto.
- **OPEN-5** — What unit is declined when vote aggregates are unsupported: the
  `getVoteAggregates` route, the `voteAggregates` expand, or a named
  capability? (D16 partly answers *what* is declared — representations — but
  not the unit of declination.)
- **OPEN-6** — Unfinished sentence in the D3 source message ("We are").
- **OPEN-10** — `soonestToExpire`: distinct mandatory sort, or aliased to
  `oldest`? See F4. Still unanswered.
- **OPEN-11** — `listActivity` (the lifecycle feed: submitted → voted →
  ratified → enacted). Not yet ruled on. No provider serves it fully.
- **OPEN-12** — Does `getVoteAggregates(id)` exist as its own route, given
  aggregates already ride inline on `get` via an expand?
- **OPEN-7** — CLOSED by D14.
- **OPEN-8** — CLOSED by D16.
- **OPEN-9** — partly closed: `listByTx` cut (D17), `getEnacted` compulsory
  (D18). `listActivity` → OPEN-11, `getTallies` → OPEN-12.

---

## D20 — `soonestToExpire` is optional and distinct (amends D13, closes OPEN-10)

**Said:** "soontoexpire is optional it is distinct yes. not alias of oldest"

Final sort table for proposals:

| Sort key | Status |
|---|---|
| `newest` | **mandatory** |
| `oldest` | **mandatory** |
| `soonestToExpire` | **optional**, provider-declared |
| `mostYesVotes` | **optional**, provider-declared |
| `highestParticipation` | **optional**, provider-declared |

- Recommendation had been "mandatory and distinct". User took the distinctness
  and made it optional. Decision stands; no further argument.
- **It is a separate ordering, not a synonym.** Per F4, `expiryEpoch =
  submissionEpoch + govActionLifetime`, and `govActionLifetime` is a changeable
  protocol parameter, so across a lifetime change the two orderings diverge.

### The inference that matters for consumers

Because it is **both optional and genuinely distinct**, a consumer must not
substitute `oldest` when `soonestToExpire` is unavailable:

- **Never relabel.** Showing `oldest` results under a "Soonest to expire" label
  is the failure mode this decision creates. It is silently wrong exactly when
  urgency is the reason the user chose that sort.
- The generic capability fallback ("use the first still-offered option") is safe
  only if the UI shows which sort is actually active. If a provider declines
  `soonestToExpire`, the correct behaviour is to **hide that menu item**, the
  same as any other declined option value.
- `mostYesVotes` and `highestParticipation` remain linked to the vote-aggregate
  capability (D16): a provider that cannot express aggregates cannot order by
  them.

---

## Open questions (updated)

- **OPEN-4** — `Ratio` rules: gcd-normalized, `denominator: 0` illegal,
  exact-from-source preferred, bounded reconstruction (cap ~1000) with a
  `precisionLoss` caveat. Proposed, awaiting accept/veto.
- **OPEN-5** — Unit of declination when a provider supports no vote-aggregate
  representation: the route, the expand, or a named capability? Must be
  declinable independently of D11 voter context.
- **OPEN-6** — Unfinished sentence in the D3 source message ("We are").
- **OPEN-11** — `listActivity` (lifecycle feed). Keep or cut?
- **OPEN-12** — Does `getVoteAggregates(id)` exist as its own route, given
  aggregates ride inline on `get` via an expand?
- **OPEN-10** — CLOSED by D20.

---

## D21 — `Ratio` is two integers; denominator 0 illegal (closes OPEN-4)

**Said:** "denominator 0 is illegal ofcourse. we just keep 2 ints and use those
numerator and denumerator."

- `Ratio = { numerator: number; denominator: number }`, both integers.
  `denominator: 0` is illegal — a provider must never emit it, a consumer may
  reject it.
- **No normalization requirement.** The user's "just keep 2 ints" is taken at
  face value: a provider is not obliged to reduce to lowest terms.

### Consequence, and the rule that handles it

Without required normalization, `67/100` and `134/200` are the same value but
different objects. Deep-equality comparison — in conformance tests, in
cross-provider diffs — would call them unequal.

**Rule: compare ratios by cross-multiplication**
(`a.numerator * b.denominator === b.numerator * a.denominator`), never by
structural equality. This removes the need for a normalization mandate
entirely. Stated here so the conformance suite does not quietly assume reduced
form.

### Still unspecified: float → Ratio reconstruction

D4 requires exact ratios; all three known sources serve IEEE-754 doubles. If
the spec does not fix the conversion, two providers reading the same `0.67`
can emit different ratios. **Proposed, awaiting veto:** prefer the rational
straight from a source that carries it; otherwise bounded-denominator
continued-fraction approximation with the denominator capped at 1000, and
declare a `precisionLoss` caveat. Real thresholds are small rationals
(51/100, 67/100, 75/100), so the cap is generous.

## D22 — `listActivity` is optional (closes OPEN-11)

**Said:** "this is something that may be required in proposal details page. Make
it optional."

- Kept in the contract, declared optional. Its consumer is the proposal detail
  page, not the list.

## D23 — How a capability is declined (closes OPEN-5, OPEN-12)

**Said:** "declination means that the implementation it returns or the spec it
says will have it null or not set. if it is a filter the filters: string[] will
not have it if it sort : sort-[asc,\"desc\", ...] will not have it for non-list
type capability the spec will use boolean"

**This is the general capability model for the whole spec.** There is no
separate declaration vocabulary — capability is expressed in the shape of the
declaration itself:

| Capability kind | Declared as | Declined by |
|---|---|---|
| A set of option values (filters, sorts, representations, search modes) | `string[]` of supported values | the value is **absent from the array** |
| A yes/no facility (voter context, an optional route, an optional field group) | `boolean` | `false` |

- An **empty array** is therefore a complete refusal of that control, and is
  meaningful: `sorts: []` means "offers no ordering at all", not "unset".
- **`null` / not-set is equivalent to declined.** A provider that omits a key
  has declined it. This keeps a new provider honest by default — it under-claims
  until it says otherwise.
- Applies to the vote-aggregate question: a provider declares
  `voteAggregate: ('percent' | 'stake' | 'count')[]`, and **`[]` is how it
  declines aggregates entirely**. No separate route-level or expand-level
  switch is needed — which answers OPEN-5 and OPEN-12 together.
- Independence falls out for free: `voterContext: boolean` and
  `voteAggregate: []` are separate keys, so D11 voter context is declinable
  independently of D16 aggregates, as required.
- Consequence for the reader: there is exactly one question to ask of any
  capability — "is the value in the array / is the boolean true". No causes, no
  tiers, no derivation.

## D24 — OPEN-6 closed

**Said:** "we are not something necessary i added it and decided it no useful
info so dropped mid sentence."

Nothing was lost. Closed.

---

## Open questions (updated)

- **OPEN-13** — float → `Ratio` reconstruction algorithm. Proposed in D21,
  awaiting veto.
- OPEN-4, 5, 6, 7, 8, 9, 10, 11, 12 — all CLOSED.

---

# Pillar 3 — DReps

## D25 — CIP-129 is the only identifier form the contract speaks

**Said:** "identity -> cip29. It is the task of the backend to then decide to
support reading others or displaying, but the provider must return/receive
standard values."

- **The contract's identifier form is CIP-129**, on input and on output.
- A provider **receives** CIP-129 and **returns** CIP-129. It is not required to
  accept CIP-105, raw hex, `drep_script1…`, or uppercase variants.
- **Normalization is the backend's job.** Whatever a user types, the backend
  converts to CIP-129 before calling a provider, and converts back for display.
- A provider whose underlying source stores another form (db-sync stores
  CIP-105 views and raw hex) converts internally, in both directions. That is
  provider work, not contract surface.

### What this fixes

The current db-sync search matches a lowercase raw-hex credential or a CIP-105
`drep1…` view by **string comparison**. Three id forms therefore return an
empty page for a DRep that demonstrably exists: a CIP-129 id, a
`drep_script1…` script DRep id, and uppercase hex. D25 removes the class of bug
rather than patching the query: there is exactly one form on the wire, so there
is nothing to mismatch.

### The trap this creates, which must be written into the spec

**CIP-105 and CIP-129 DRep ids share the `drep1` bech32 prefix but are
different payloads** — CIP-129 prepends a header byte encoding the credential
type. A provider cannot tell them apart by prefix and must **decode** to
distinguish. A provider that accepts "anything starting with `drep1`" will
silently mis-resolve CIP-105 input. The spec must say: decode and validate the
header, reject a non-CIP-129 identifier rather than guessing.

### Consequences to confirm

- **CIP-129 covers more than DReps** — governance action ids
  (`gov_action1…`), and committee hot/cold credentials. The decision most
  likely generalizes to every governance identifier in the contract. See
  OPEN-14.
- **`isScriptBased` may become redundant.** CIP-129's header byte encodes
  whether the credential is a key or a script, so a consumer holding a valid
  CIP-129 id can derive it. Keep as a convenience field, or drop? See OPEN-15.
- The entity currently carries **two** id fields (`drepId` and `view`). Under
  D25 there is one form, so the second should go unless it serves a purpose
  the backend cannot reconstruct. See OPEN-16.

## D26 — "Sole voter" becomes "anonymous voter", defined by the absence of an anchor

**Said:** "Sole Voter -> We might need to change it to Anonymous voter the one
that doesn't have any anchor/url"

**Status: proposed by the user with "might need" — recorded, confirmation
requested.**

- Rename `directVoter` / "SoleVoter" → **`anonymousVoter`**.
- **Redefined by observation, not intent.** The old "sole voter" meant a stake
  key registered to vote only for itself — an inference about *purpose*. The
  new definition is: **a DRep that registered with no anchor**, i.e. no
  metadata url and no data hash. That is a fact on chain.
- This is a better definition for a provider spec: db-sync currently derives
  the kind from "the deposit sign and whether a non-deregistering anchor
  exists", which is inference layered on inference. The new rule is a null
  check.

### The consequence that needs a decision

If `anonymousVoter` ⟺ `anchor === null`, then **`kind` is fully derivable from
the anchor field** and carries no information of its own.

- Argument to **drop** `kind`: it is a computed restatement, and D9 established
  that a field a provider fills by aliasing another field is a contract bug.
- Argument to **keep** `kind`: the directory **filters** by it, and a provider
  filtering server-side needs a filter key. A filter over "anchor is null" is
  awkward to express as a filter name.

Recommendation: keep `kind` **as a filter key only**, and state in the spec that
it is derived — a provider must not report `kind: 'drep'` for a DRep with no
anchor, or vice versa. See OPEN-17.

---

## Open questions (updated)

- **OPEN-13** — float → `Ratio` reconstruction algorithm. Proposed in D21.
- **OPEN-14** — Does D25 (CIP-129) generalize to governance action ids and
  committee credentials, i.e. every governance identifier in the contract?
- **OPEN-15** — Keep `isScriptBased`, or drop it as derivable from the CIP-129
  header byte?
- **OPEN-16** — The entity carries both `drepId` and `view`. Drop one?
- **OPEN-17** — Confirm D26, and decide whether `kind` survives as a filter key
  or is dropped as derivable from `anchor === null`.
- **Carried from the DRep question set, unanswered:** status
  (`active`/`inactive`/`retired` — `inactive` is a computation, not a
  certificate fact); voting power basis (active vs live); delegators (count vs
  list vs timeline); activity stats and the undefined trailing window;
  mandatory sorts; search modes.

---

## D27 — CIP-129 generalizes to every governance identifier (closes OPEN-14)

**Said:** "cip129 generalizes to everything govactions and credentials."

- Every governance identifier in the contract is CIP-129: DRep ids, governance
  action ids, and committee hot/cold credentials.
- The decode-and-validate rule from D25 applies to all of them, not just DReps.
- Practical note: governance action ids have a second textual form in wide use
  (`txHash#index`). The spec must say which is canonical on the wire — CIP-129
  — and that `txHash#index` is a display/backend concern like CIP-105.

## D28 — `isScript` is optional and derivable (closes OPEN-15)

**Said:** "isScript is optional if null we decode the bech32."

- Field kept, **optional**. When absent, a consumer decodes the CIP-129 header
  byte, which encodes key-vs-script.
- A provider that has it cheaply supplies it; one that does not omits it. Never
  guessed.

## D29 — `view` is dropped (closes OPEN-16)

**Said:** "drepId is only required view is no more required."

- One identifier field: `drepId`, CIP-129. `view` is removed from the contract.
- Any other rendering (CIP-105, hex, shortened) is a backend/display concern.

## D30 — `kind` survives as an optional filter only (closes OPEN-17 in part)

**Said:** "kind is optional filter provider may decide or not decide to provide.
But it is not a necessary. I don't think we use it anywhere but will be useful
to allow providers to support the filter."

- `kind` is **not a required entity field**. It exists as an **optional filter
  capability** a provider may declare under D23 (`filters: string[]`).
- Rationale accepted as given: not currently used in the product, but cheap to
  allow a provider to offer.
- **The D26 rename ("sole voter" → "anonymous voter", defined as
  `anchor === null`) is still unconfirmed.** D30 decides the *mechanism*
  (optional filter), not the *name or definition*. See OPEN-17.

## D31 — Voting power: active required, live declared

**Said:** "voting power -> active is required (Live) is declared optionally."

- `votingPower` on the **`active` basis** (the epoch snapshot the ledger counts)
  is **required**.
- `liveVotingPower` is **optional and declared** under D23 (boolean).
- Confirms the existing rule that active is the only valid tally denominator
  and live must never be substituted for it.

## D32 — Delegators: fully optional, with a required shape when present

**Said:** "delegators -> fully optional and when provided must give (stake
address, and active_voting_power) optionally date delegated, live voting power
or last_drep (drep_id from which the user switched)."

- The delegator listing is **fully optional** (declared boolean).
- **When a provider serves it, these are required per row:**
  - `stakeAddress`
  - `activeVotingPower`
- **Optional per row:**
  - `delegatedAt` (date/epoch of delegation)
  - `liveVotingPower`
  - `previousDRepId` — "the drep_id from which the user switched"
- This is D6 again: the capability may be declined wholesale, but not served
  half-filled. A delegator row without voting power is not conformant.
- `previousDRepId` is notable: it is a **partial delegation-history signal**
  without requiring a full join/leave timeline, which no known source has. It
  answers "who did they leave" without answering "when did everyone move".

## D33 — DRep vote listing

**Said:** "Votes -> Also comes in next section but drep vote listing can be
supported which will contain the anchor, vote govaction id and details
optionally can have gov action title or abstract in the listing itself. (There
should also maybe be a way to return the ones not voted optionally)"

Per row, when the listing is served:

- **Required:** the vote choice, the governance action id (CIP-129 per D27),
  the vote's own **anchor** (the CIP-100 rationale anchor), and the vote
  details.
- **Optional:** governance action **title or abstract**, denormalized into the
  listing row.
- **Optional, separate:** a way to list the actions the DRep did **not** vote
  on. This pairs with the `x/y` activity stat in D34 — the denominator made
  enumerable.

**Conflict with D10 — flagged, not resolved.** Title and abstract are fields of
the resolved CIP-108 metadata document. D10 established that chain data serves
the anchor and never the resolved document, with metadata resolution owned by a
separate service. Denormalizing title/abstract into a vote listing crosses that
line. See OPEN-18.

## D34 — Activity stats: x/y since registration (closes the window question)

**Said:** "yes they can declare activity field. if they don't support it then we
just disable that view in the frontend" / "Activity stats -> votes cast x/y
since the drep registered. (optional ofcourse)"

- The stat is **votes cast out of votable actions**, i.e. `x / y`.
- **The window is fixed by the spec: since the DRep registered.** Not a
  rolling window, not provider-chosen.
- **Optional**, declared. A provider that declines it causes the frontend to
  disable that view outright.

### F6 — This makes db-sync's current implementation non-conformant

db-sync computes `votesCast` from a **trailing 365 days**
(`block.time >= now() - INTERVAL 1 year`). Under D34 the window is "since
registration". These are different numbers for any DRep registered more than a
year ago, and `activity` is also a **sort key** — so two providers with
different windows produce different orderings of the same directory from the
same chain.

Fixing the window in the spec is what makes the sort meaningful. db-sync's
statement must change, or db-sync must decline the capability.

**Implementation cost to note:** the denominator `y` — votable actions during
the DRep's registration — is a join between the registration period and the
governance action set. It is not a column anywhere. This is real work for every
provider, and is the reason the stat is optional.

## D35 — Registration and update history

**Said:** "We can additionally have the update_history of the drep. One thing
important is the last update details and registration details so that those
dates can be shown. registration details is optional, but last registered tx
and metadata is compulsary."

- **Required on the entity:**
  - the **latest registration transaction** (so its date can be shown)
  - the **metadata anchor** (url + dataHash, per D10)
- **Optional:**
  - full **registration details** / history
  - **update history** — the sequence of DRep registration updates
- Purpose as stated is display of dates: "last update details and registration
  details so that those dates can be shown". So the required latest-registration
  reference must carry enough to render a date — a bare tx hash with no
  timestamp does not satisfy the intent.
- Open: does "last update" mean the most recent registration-or-update
  certificate (one field), or are last-registration and last-update two
  separate required fields? See OPEN-19.

---

## Open questions (updated)

- **OPEN-13** — float → `Ratio` reconstruction algorithm. Proposed in D21.
- **OPEN-17** — Confirm or drop the D26 rename: "sole voter" → "anonymous
  voter", defined as `anchor === null`. D30 settled the mechanism, not the name.
- **OPEN-18** — **D10 vs D33.** May a chain-data provider denormalize
  governance action title/abstract into a vote listing, when D10 says chain
  data serves anchors and never resolved metadata?
- **OPEN-19** — "last update details and registration details": one field or
  two? And must the required latest-registration reference carry a timestamp,
  not just a tx hash?
- OPEN-14, 15, 16 — CLOSED by D27, D28, D29.

---

## D36 — Vote-listing denormalization is a narrow, documented exception (closes OPEN-18)

**Said:** "D33 is a nice to have extra govaction id, title and abstract and the
type (type and id is comulsary) title and abstract is optional I think we can
drop abstract and just have the title. Document it as narrow exception that may
be implemented to make frontend renderer fast."

Per row in a DRep vote listing:

| Field | Status |
|---|---|
| governance action **id** (CIP-129) | **required** |
| governance action **type** | **required** |
| governance action **title** | **optional** |
| abstract | **dropped** |

- The vote's own choice, details and CIP-100 anchor remain required (D33).
- **`title` is an explicit, narrow exception to D10.** It is resolved CIP-108
  metadata appearing inside a chain-data response. The exception exists for one
  reason — letting the frontend render a listing without N metadata lookups —
  and must be documented as such in the spec, so it is not read as licence to
  embed resolved metadata generally.
- Dropping `abstract` keeps the exception as small as possible: one short
  display string, not a document.
- **The exception does not generalize.** Everywhere else, chain data serves
  `{ url, dataHash }` and the metadata service resolves it.

## D37 — "Sole voter" is renamed "anonymous", designated by the anchor (closes OPEN-17)

**Said:** "yes we are renaming the solevoter to anonymous with anchor used for
the designation. note that anaonymous dreps shouldn't be shown in search unless
directly id is typed."

- **Confirmed:** `directVoter` / "SoleVoter" → **anonymous**. The designation is
  **the absence of an anchor**, not an inference from deposit sign or intent.
- Combined with D30: `kind` is not a required entity field; it survives as an
  **optional filter** a provider may declare.

### New rule — anonymous DReps are excluded from search

**An anonymous DRep must not appear in search results unless its id is typed
directly.** Exact-id lookup returns it; other search modes must not.

**F7 — this is self-enforcing for text modes, but not for all of them.**

An anonymous DRep has no anchor → no metadata document → no name, no bio. So a
`substring` or `freeText` search over metadata **cannot match it anyway**; the
rule is automatically satisfied there and costs a provider nothing.

Where it does bite: **`adaHandle`**. An ada handle resolves through the stake
address, not through metadata, so an anonymous DRep *can* be reached by handle
lookup. A provider implementing `adaHandle` search must exclude anonymous DReps
explicitly, or it violates the rule.

This also means the rule is not merely a UI convention — it is a provider
obligation on at least one search mode, and belongs in the spec rather than in
the frontend.

## D38 — Registration and update: both, with a required date (closes OPEN-19)

**Said:** "yes most last registration and most registration update certificate
is the thing I wanted to see. Timestamp instead of just tx hash the slot and
epoch details are good to have make date required for now."

- **Two required references**, not one:
  - the **latest registration** certificate
  - the **latest registration-update** certificate
- Each carries a **required date**. A bare tx hash does not satisfy this — the
  stated purpose is showing dates.
- **`slot` and `epoch` are "good to have"** → optional alongside the date.
- Full registration history / update history remain **optional** (D35).

## D39 — `Ratio` rendering, and reconstruction deprioritized (closes OPEN-13)

**Said:** "frontend always receives ratio. and rendering will simply truncate to
2 digits or show x out of 6 fraction."

- The consumer always receives a `Ratio` and renders it either truncated to two
  decimal places or as an `x/y` fraction. No consumer-side ratio arithmetic
  beyond that.
- **Practical effect on the unresolved reconstruction question:** because
  display truncates to two digits, two providers reconstructing `0.67`
  differently (`67/100` vs a longer approximation) render **identically**. The
  precision of the float→ratio conversion is therefore invisible in the UI, and
  the question is deprioritized rather than answered.
- **The one place it could still bite:** a `passing` determination where a vote
  aggregate sits exactly on the threshold boundary. Comparison must be by
  cross-multiplication (D21), and a provider reconstructing a threshold
  imprecisely could flip that boolean. Low likelihood; worth a sentence in the
  spec rather than an algorithm mandate.

## D40 — Search: four modes, `exactId` mandatory

**Said:** "exact search should have exactId, substring, freeText, adaHandle exat
id is mandatory no? what question is this?" / "but the provider may say that
they only support exactid that is fine."

| Mode | Status |
|---|---|
| `exactId` | **mandatory** |
| `substring` | optional, declared |
| `freeText` | optional, declared |
| `adaHandle` | optional, declared |

- Declared as an array under D23: `search: ('exactId' | 'substring' | 'freeText'
  | 'adaHandle')[]`. `exactId` must always be present.
- **`substring` and `freeText` are now distinct modes**, which they were not
  before. They have different index requirements: substring is a literal match
  on a name; free text is tokenized and ranked. A provider may support one and
  not the other.

### D41 — Search may belong to a separate provider

**Said:** "Note that this should be on a governance indexer because this search
is going to be expensive without good text index, and it may be declared as a
separate provider. but lets say that this requires text indices."

- Text search over DRep metadata **requires a text index**. A chain-data source
  that is a per-entity HTTP API, or a SQL database without such an index, cannot
  serve it at reasonable cost.
- **The spec should therefore say that search may be backed by a separate
  provider — a governance indexer — rather than by the chain-data provider.**
- This is the first place the architecture admits a **second provider kind**.
  Implications to work through:
  - Does `ChainDataApiV1` keep a search method that a chain-data provider may
    decline, with a separate search provider filling it? Or does search move
    out of the chain-data contract entirely, into its own interface?
  - A search index over metadata is downstream of the **metadata service**
    (which resolves and validates documents), not of chain data — which is
    consistent with D10 and argues for search being its own component.
  - The composition is then: chain data + metadata + pinning + **search**.
- Recorded as a direction, not yet a settled structure. See OPEN-20.

---

## Open questions (updated)

- **OPEN-20** — Is search its own component/provider alongside chain-data,
  metadata and pinning? Or a declinable capability on the chain-data contract
  that some other implementation can back? (Raised by D41.)
- OPEN-13, 17, 18, 19 — CLOSED by D39, D37, D36, D38.

---

## D42 — DRep update history is a metadata-change feed

**Said:** "in update history we need the dreps' changes in metadata, so it will
have timestamps (blocks epoch slots etc optinally) and the anchor details and
sort option asc | desc."

The update history answers **"what did this DRep say about itself, and when did
it change"**. Per row:

| Field | Status |
|---|---|
| **anchor** (url + dataHash) | **required** — this is the point of the feed |
| **date/timestamp** | **required** (consistent with D38) |
| block, epoch, slot | optional |

- Sort: **`asc` | `desc`**, on time.
- Remains **optional** as a capability (D35), but when served it has this
  required shape — D6 again.
- Note it is specifically a **metadata**-change feed, not a general
  registration-certificate feed. Each row is an anchor as of a moment. A
  consumer wanting the document itself resolves each anchor through the
  metadata service (D10).

## D43 — Not-voted actions live in the vote listing, filtered (closes the OPEN "not voted" item)

**Said:** "when listing the drep activity, we can include the not-voted in the
voting activity list itself and it can be filtered out. Similarly in the
activity once registered we can say that drep has participated in x out of y new
proposals that were active since the drep registered."

- **No separate "not voted" endpoint.** The DRep vote listing contains rows for
  both voted and not-voted governance actions, and a **filter** selects between
  them.
- This makes the D34 activity stat structurally coherent: **`y` is the length of
  the unfiltered listing**, `x` the length filtered to voted. The headline
  number and the list that explains it come from one source and cannot disagree.
- Refines D34's denominator: **`y` = new proposals that were active since the
  DRep registered.** Not all proposals ever; not a rolling window.
- A not-voted row has no vote choice and no CIP-100 anchor. The row shape must
  therefore make those nullable/absent for not-voted entries — the listing is a
  union of two row kinds, discriminated by whether a vote exists.

## D44 — DRep sorting: all optional, default random, `status` is a filter

**Said:** "sorting of drep -> voting power, registration date, activity, random
(status is a filter) yes shuffle is to make sure that govtool doesnt show same
dreps each time. activity is optional here and depends on provider. not
supporting any is also fine. but default should be random sort each time."

| Key | Status |
|---|---|
| `votingPower` | optional, declared |
| `registrationDate` | optional, declared |
| `activity` | optional, declared — and gated on the D34 activity capability |
| `random` | the **default** ordering |
| ~~`status`~~ | **not a sort — it is a filter** |

- **A provider supporting no sorts at all is conformant.** This is unlike
  proposals (D13/D20), where `newest` and `oldest` are mandatory. Recorded as
  deliberate.
- **The default ordering is random**, and the stated purpose is fairness: the
  DRep directory must not show the same DReps first every time, i.e. it must not
  become a rich-list by default.

### F8 — Random default plus paging requires a seed, and the spec must say so

A re-randomised shuffle per request **breaks paging**: page 2 of a freshly
shuffled list can repeat entries from page 1 and omit others entirely. The
shuffle must be **deterministic given a seed**, with the seed stable for the
duration of a paging session and different between sessions ("random each
time").

So the spec needs one of:

- a **seed carried in the query** (`sort: 'random', seed: <n>`), or
- a **seed embedded in the cursor**, established on the first page.

db-sync's existing implementation already does this via a `seededHash`, so the
requirement is proven rather than theoretical.

**Who shuffles when the provider cannot?** Since "not supporting any sort is
fine" but the default is random, the ordering must come from somewhere. The
consumer — GovTool's backend — already reads the whole DRep directory into a
cached snapshot and sorts in memory, so it can supply the default. The spec
should state that random ordering **may be supplied by the consumer** when the
provider declines it, and that a provider offering `random` must accept a seed.

## D45 — Search moves to a separate `DRepIndexProvider` (closes OPEN-20)

**Said:** "searching is something that can be implemented separately by
DrepIndexProvider and optional for our chain data provider."

- **Search is a separate provider kind.** Named by the user
  **`DRepIndexProvider`**.
- **Optional for the chain-data provider.** A chain-data provider may implement
  search, but is not required to; the capability can be satisfied by a different
  implementation entirely.
- Confirms D41's direction and the reasoning behind it: text search needs a real
  text index, which a per-entity HTTP API or an unindexed SQL source cannot
  provide at reasonable cost.
- `exactId` remains mandatory **on the chain-data provider** (D40) — that is a
  direct credential lookup, not a text search, and needs no index.

### Open consequence — is the index DRep-only?

The name says DRep. But **proposal search exists too**: the governance action
list supports free-text search over CIP-108 title and abstract, and GovTool's
backend implements it today by scanning its in-memory snapshot. If the index is
DRep-only, proposal search stays a consumer concern; if it is general, the
component is a *governance* index over all anchored entities. See OPEN-21.

Architectural note carried from D41: a text index over metadata is downstream of
the **metadata service** (which resolves and validates the documents), not of
chain data. That remains the argument for search being its own component rather
than a chain-data capability.

---

## Open questions (updated)

- **OPEN-21** — Is the search index DRep-only (`DRepIndexProvider`) or general
  over all anchored entities (proposals too)? Proposal free-text search exists
  today and has the same index requirement.
- **OPEN-22** — Random-sort seeding: seed in the query, or seed in the cursor?
  (Raised by F8. Needs an answer before the paging contract is written.)
- OPEN-20 — CLOSED by D45.

---

## D46 — Random sort is unpaginated (closes OPEN-22)

**Said:** "For random sorting, we don't support pagination."

- **`sort: 'random'` and pagination are mutually exclusive.** A random-ordered
  read is not paged.
- This dissolves the F8 seeding problem entirely: there is no page 2, so there
  is no cross-page stability to preserve, so **no seed is needed**. The simplest
  possible resolution.
- A provider must therefore **reject** a random-sorted request that also carries
  a cursor or offset, rather than silently ignoring one of them.
- **Needs one clarification:** what does a random read return — the whole set,
  or a capped set? See OPEN-23. Given GovTool's backend already reads the entire
  DRep directory into a snapshot, "the whole set" is the natural reading, but a
  provider with a hard row cap must be able to say so.

## D47 — The index provider covers DReps *and* proposals (closes OPEN-21)

**Said:** "yeh the index provider can have the drepindex provider and the
proposals both."

- The search index is **general over governance entities**, not DRep-specific.
  It covers DRep search and governance-action search.
- The spec's top-level components therefore become: **chain data + metadata +
  pinning + index**.

## D48 — Search interfaces must be independently implementable

**Said:** "but we need add that somewhere when implementing an indexer that
supports both, indexer won't want to then implement all the other drep
interfaces, but only search. idea is then the DrepData provider also can't
declare proving both drep and proposal index. it was there just to reuse in 2
place, if typescript allows not needing it then it is fine."

The requirement, stated plainly:

- An **indexer** that implements search must **not** be obliged to implement
  `DRepsApi`, `ProposalsApi` or anything else in the chain-data contract.
- A **chain-data provider** must **not** be obliged to implement search, and
  must not be forced to claim both DRep and proposal search if it implements
  only one.
- The two search surfaces exist as a pair only because the same code may serve
  both — that is a reuse convenience, not a coupling.

### TypeScript allows exactly this, with no inheritance

Small standalone interfaces, composed through optional members — the same
mechanism D23 already uses for declination:

```ts
export interface DRepSearchApi {
  searchDReps(q: DRepSearchQuery): Promise<PagedEnvelope<DRep>>;
}

export interface ProposalSearchApi {
  searchProposals(q: ProposalSearchQuery): Promise<PagedEnvelope<GovAction>>;
}

/** Either half, or both. An implementer supplies what it has. */
export interface GovernanceIndexV1 {
  dreps?: DRepSearchApi;
  proposals?: ProposalSearchApi;
}
```

- A dedicated indexer implements `GovernanceIndexV1` and nothing else.
- A chain-data provider that also indexes may implement `GovernanceIndexV1`
  **in addition to** `ChainDataApiV1`. The two are unrelated types; nothing
  forces one to imply the other.
- An implementer with only DRep search supplies `{ dreps }` and omits
  `proposals` — declined by absence, exactly as D23 specifies.
- **No base class, no `extends`, no shared abstract type.** The "reuse in two
  places" the user describes is satisfied by the two interfaces being separately
  nameable and separately optional. Confirmed: TypeScript does not need the
  grouping the user was working around.

## D49 — Votes are never independently addressable

**Said:** "the votes will always be tied to drep and proposals."

- **There is no standalone votes namespace.** No cross-cutting vote feed, no
  lookup of a vote by its own transaction hash.
- A vote is reachable **only** through its DRep (`dreps.listVotes`) or its
  governance action (`proposals.listVotes`).
- **`VotesApi` is removed from the contract.**

### F9 — This matches what providers already do

`votes.list` and `votes.get` are refused by **two of the three** existing
providers:

- **db-sync** — `get-votes.sql` is keyed on a DRep credential, so there is no
  cross-cutting feed and no lookup by vote transaction.
- **Blockfrost** — indexes votes per proposal and per DRep, with no
  cross-cutting feed and no route from a vote's transaction hash.
- **Koios** — serves it, and notes it cannot number voting procedures within a
  transaction, so `(txHash, index)` addressing was already unreliable.

D49 removes a surface that only one source could serve and that even that source
could not address precisely. The "Votes" pillar collapses into DReps and
Proposals; there is nothing left to decide separately.

---

## Open questions (updated)

- **OPEN-23** — Does a random-sorted read return the whole set, or may a
  provider cap it? If capped, how is the cap declared given there is no cursor?
- OPEN-21, OPEN-22 — CLOSED by D47, D46.

---

## D50 — Random reads take a `limit`, default 20 (closes OPEN-23, refines D46)

**Said:** "we let the govtool cap it provider just may have to return based on
limit passed. the limit is by default 20"

- A random-sorted read is **limited, not paged**. `limit` still applies;
  `cursor` and `offset` do not.
- **Default `limit` is 20** when the caller supplies none.
- GovTool (the consumer) decides the cap; the provider simply honours the limit
  it is given.
- A provider must still **reject** a random-sorted request carrying a cursor or
  offset (D46), rather than silently ignoring it.
- Refines the D46 wording: "unpaginated" means *no cursor semantics*, not
  *returns everything*.

This is a coherent shape for the directory landing view — a fair sample of 20
DReps, different each visit, with no paging through a shuffled list.

---

# Pillar 4 — Accounts (the connected wallet)

Presented for decision. Nothing settled yet.

## What the entity carries today

| Field | Notes |
|---|---|
| `stakeAddress`, `stakeKeyHash` | identity |
| `isRegistered` | stake key registration state |
| `isScriptBased` | script vs key |
| `balance` | `StakeBalance` |
| `votingPower` | expand-gated; the wallet's own power |
| `delegation` | current governance delegation — target, tx, since |
| `poolDelegation` | current pool delegation |
| `latestRegistration` / `latestDeregistration` | stake certificates |
| `drep` | set when this stake key is itself registered as a DRep |
| `adaHandles` | handle names resolved to this account |
| `providerId` | provider-native opaque id, "compatibility only" |

Delegation target is `DRepTarget`: either a DRep credential, or one of the
predefined options `alwaysAbstain` / `alwaysNoConfidence`.

## What the frontend reads today

Three calls: `accounts.get`, `accounts.getDelegation`, `accounts.getVotingPower`.
From the delegation it reads essentially **`dRepView`** — which under D29 no
longer exists, so this becomes `drepId` in CIP-129 form.

The frontend's own `Account` type is `{ id, view, isRegistered, isScriptBased }`
— note `id: number`, a db-sync row id, and `view`. Both are provider-shaped
leaks of the same family D1 and D29 removed elsewhere.

## Provider reality

- `accounts.get` and `getDelegation` — all three serve them.
- `getVotingPower` — **Blockfrost cannot**: it reports voting power per DRep,
  never per stake account. db-sync serves it but the statement reads
  `utxo_view`, which is absent on some deployments and shipped once as a silent
  0 ada for every connected wallet.
- `listDelegationHistory` / `listStakeEvents` — db-sync has no statement for
  either.

## D51 — A provider identifies itself with a free-form id, a name and an optional inline icon

**Said:** "provider will have to express a random id and name, and base64
image/png icon inlined also optional"

- A provider declares **its own identity**, for attribution and display:

| Field | Status |
|---|---|
| `id` | **required**, free-form string chosen by the provider |
| `name` | **required**, human-readable |
| `icon` | **optional**, a base64-inlined PNG |

- "Random id" is read as **arbitrary / provider-chosen**, not drawn from a fixed
  list. This replaces the current
  `ProviderId = 'dbsync' | 'koios' | 'blockfrost' | 'kupo' | string`, whose
  enumerated members are a closed list pretending to be open.
- The icon is **inlined**, not a URL — so displaying provider attribution needs
  no second fetch and no external host.

### Ambiguity flagged, not resolved

The question this answered was about `Account.providerId` — a **per-entity
opaque row identifier** ("provider-native opaque identifier, for compatibility
only"), which is a different thing from provider self-identity. The same name
was doing two jobs.

- **D51 covers provider identity.** Settled.
- **`Account.providerId` (and `TxRef.providerId`) is still unresolved.** It is a
  provider-shaped value carried through the contract, of the same family that D1
  removed from protocol params and D29 removed from DRep ids. See OPEN-24.

## D52 — The predefined delegation targets are not DReps

**Said:** "alwaysAbstain and alwaysNoConfidence they are not dreps, only useful
metric to show the status of governance somewhere."

- `alwaysAbstain` and `alwaysNoConfidence` must **never be modelled as DRep
  entities**. They have no credential, no anchor, no registration, no metadata.
- They remain valid **delegation targets** — a user really can delegate to
  them, and the wallet must show that state — so the delegation target stays a
  discriminated union distinguishing *delegated to DRep X* from *delegated to a
  predefined target* from *not delegated*.
- Their **aggregate voting power is a governance metric**, which is already
  where the contract puts it: `alwaysAbstainVotingPower` and
  `alwaysNoConfidenceVotingPower` on `StakeDistribution` (F2, D6).
- So the two appear in exactly two places and nowhere else: as a delegation
  target on an account, and as a stake total on the network. Never in a DRep
  list, never with a DRep shape.

## D53 — `drep` stays on the account

**Said:** "drep on a stake key is possible, we need to detect that. but what is
the issue with it? i don't think it is any issue on the specification."

- **Kept.** When a stake key is itself registered as a DRep, the account carries
  it.
- The concern raised was payload size on a hot read, not correctness. Accepted
  as not a specification problem. It may still be `expand`-gated as an
  implementation choice.
- No recursion risk: `DRep` does not contain an `Account`.

## D54 — `balance` is optional, and the breakdown is the point

**Said:** "balance -> it is optional data that providers can provide. yeh wallet
show balances, but they often ignore the locked rewards and other things that we
can show properly if we have the api."

- **Optional**, declared.
- The justification is not "wallets lack the number" but "wallets show the
  **wrong** number" — they miss reward balances that nonetheless count toward
  voting power.

### F10 — The existing `StakeBalance` already encodes this insight

```ts
interface StakeBalance {
  total: Lovelace;
  utxo?: Lovelace;
  rewards?: Lovelace;      // staking rewards from pool delegation
  rewardsRest?: Lovelace;  // deposit refunds, treasury/reserve payouts, MIR
}
```

The existing comment on `rewardsRest` states exactly the user's case: these are
"withdrawable and stake-counting like `rewards`, but invisible in most wallet
UIs, so it is the usual explanation for **voting power exceeding an account's
apparent balance**."

So the breakdown is the deliverable, not the total. A provider serving only
`total` gives the consumer nothing a CIP-30 wallet could not already supply.
Worth stating in the spec: **if you serve `balance`, serve the components** —
D6's "decline wholesale or serve completely" applied here.

## D55 — Delegation history is in scope for the connected wallet

**Said:** "delegation history is a nice thing for a connected wallet, lets add it
to spec."

- `listDelegationHistory` is **in the spec**, scoped to the connected wallet's
  own account.
- db-sync has no statement for it today (its current-delegation read is
  `LIMIT 1` over the newest `delegation_vote` row), so this is new provider work
  or a declined capability.
- Presumed optional-declared unless stated otherwise; the phrasing "nice thing"
  does not read as mandatory. See OPEN-25.

## D56 — Ada handles leave the chain-data contract

**Said:** "ada handle is totally optional. it should belong either to
govtool-backend or indexer"

- **`adaHandles` is removed from the chain-data contract** — from `Account` and
  from `DRep`.
- Handle resolution is a third-party token standard with its own index. It
  belongs to the **GovTool backend** or the **index component** (D45/D47), not
  to a chain-data provider.
- Consequence for D40: the `adaHandle` **search mode** likewise belongs to the
  index component, not to chain data. This strengthens D45 — the chain-data
  provider's mandatory `exactId` is a credential lookup, and every other search
  mode is somebody else's job.
- Consequence for D37/F7: the concern that an anonymous DRep could be reached by
  handle lookup now applies to the **index**, not to a chain-data provider.

---

## Open questions (updated)

- **OPEN-24** — `Account.providerId` / `TxRef.providerId`: a per-entity
  provider-native opaque id carried "for compatibility only". Keep or drop?
  Distinct from D51's provider self-identity.
- **OPEN-25** — Is `listDelegationHistory` optional-declared or required?
- **OPEN-26** — **Unanswered:** is per-account **voting power** in scope, and at
  what obligation level? Blockfrost structurally cannot serve it; db-sync's
  statement reads `utxo_view`, absent on some deployments, and once shipped a
  silent 0 ada for every connected wallet. It is the most failure-prone read in
  the contract and the one whose wrong answer is least detectable.

## D57 — Per-account voting power is optional (closes OPEN-26)

**Said:** "that is optional"

- `accounts.getVotingPower` is **optional, declared**.
- Recognises that Blockfrost structurally cannot serve it (power is reported per
  DRep, never per stake account) and that db-sync's statement depends on
  `utxo_view`, absent on some deployments.

### F11 — "Optional" must mean hidden, never zero

This read has already shipped a silent **0 ada for every connected wallet** on a
db-sync instance without `utxo_view`: no error, no warning, a wrong number on
the exact screen where a user decides whether to delegate.

GovTool's backend currently **catches every failure and returns 0**, because
`/ada-holder/get-voting-power` has always answered 0 rather than erroring. If
that behaviour survives alongside D57, optionality achieves nothing — a declined
capability and a broken deployment both render as "you have 0 voting power".

**The D34 pattern applies:** a declined capability means the consumer **disables
the view**. The spec should state that a provider which cannot serve voting
power must declare it and refuse, never return a zero, and that a consumer must
distinguish *declined* from *zero*.

## D58 — `listDelegationHistory` is optional (closes OPEN-25)

**Said:** "optional"

Optional, declared. db-sync has no statement for it today, so it is new provider
work or a declined capability.

## D59 — `providerId` is removed from the contract (closes OPEN-24)

**Said:** "what is this nonsense I don't understand where we are using it."

**Traced. It exists for exactly one purpose: carrying a db-sync integer primary
key through the contract so the GovTool backend can emit `id: number` in its
legacy JSON.**

Evidence:

| Site | Code |
|---|---|
| db-sync account mapper | `providerId: String(row.id)` |
| db-sync proposal mapper | `submittedTx: { txHash, providerId: String(row.tx_id) }` |
| backend account service | `id: Number(data.providerId)` |
| backend proposal service | `private toLegacyRowId(providerId: string \| undefined)` |
| frontend `Account` type | `{ id: number, view, isRegistered, isScriptBased }` |

- Koios and Blockfrost have no such identifier, so the field is absent on **two
  of three** providers; the backend already falls back
  (`action.providerId ?? action.id`).
- Under **D3**, GovTool's legacy browser wire format is a backend concern and
  out of this spec's scope.
- Under **D1** and **D29**, a provider-native value carried through the contract
  "for compatibility" is precisely the leak being removed.

**Decision: remove `providerId` from `Account`, `TxRef` and `GovActionRef`.** If
the backend needs a numeric legacy id it derives or drops one itself.

### F12 — What remains required on an `Account`

With voting power (D57), balance (D54), delegation history (D58) and ada handles
(D56) all optional, and `providerId` removed, the required core is:

```ts
interface Account {
  stakeAddress: Bech32;
  stakeKeyHash: Hex;
  isRegistered: boolean;
  isScriptBased: boolean;   // cf. D28 — may be derivable
  // everything else optional / declared
}
```

Plus the current governance delegation, which no decision has yet made optional
and which is the one thing GovTool cannot function without on this pillar — it
is what the dashboard's delegation card reads. **Confirm it is required.** See
OPEN-27.

---

## Open questions (updated)

- **OPEN-27** — Is `accounts.getDelegation` (the wallet's current governance
  delegation) required? Every provider serves it today, and it is the only
  account read GovTool genuinely depends on.
- OPEN-24, 25, 26 — CLOSED by D59, D58, D57.

## D60 — The spec states obligations; it does not defend against implementations that lie (amends F11)

**Said:** "the implementation has to be better and properly say whether it is
supported or not we are not here to think about if a implementation would
advertise and fail to deliver, that is for the implementor"

**Scoping principle for the whole spec, not just voting power.**

- The spec defines **what a provider must do**. It does **not** add defensive
  language designed to protect a consumer from a provider that declares a
  capability and then fails to honour it.
- A provider that advertises support and delivers garbage has an
  **implementation bug**. That is the implementor's responsibility, not a
  spec-shaped problem.

### What this removes, and what it keeps

**Removed from scope:** consumer-side defensive requirements — "the consumer
must distinguish declined from zero", "the consumer must validate that a served
field is plausible", and similar. F11's prescription for GovTool's backend is
withdrawn from the spec.

**Still in scope, because it is an obligation *on the provider*:**

- **Declare accurately.** A provider must not claim a capability it cannot serve.
- **Refuse rather than fabricate.** A provider that cannot compute a value
  raises a capability refusal; it does not return `0`, `null`-as-zero, or any
  other placeholder that reads as data.

Those two remain normative. Everything beyond them is implementation quality.

### Consistency check against D3

This is not merely acceptable, it follows from **D3**. GovTool's backend
returning `0` on a failed voting-power read is *backend* behaviour toward the
*browser* — explicitly out of this spec's scope. The fix belongs in the backend,
and the spec was the wrong place to put it.

### Consequence

The **conformance suite** becomes the enforcement mechanism, not spec prose. A
spec that states obligations plainly, plus a suite a third party can run against
their own implementation, is the whole compliance story. The spec does not
narrate failure modes it cannot prevent.

## D59a — `providerId` removal reaffirmed

**Said:** "that may be useful at data layer, but definitely unnecessary for
frontend. I think we can drop it from every place. We don't need provider id."

Confirms D59. Removed from `Account`, `TxRef` and `GovActionRef` — every
occurrence, not merely the frontend-facing ones.

---

# Pillar 5 — Committee, constitution, SPOs, transactions

Presented for decision. Nothing settled.

## Committee

```ts
interface CommitteeMember {
  coldCredential: Credential;
  hotCredential: Credential | null;   // null until the member authorises a hot key
  termStartEpoch: EpochNo | null;
  termExpiryEpoch: EpochNo | null;
  hasResigned: boolean;
}
interface Committee {
  members: CommitteeMember[];
  quorum: Ratio;
  enactedBy: GovActionRef | null;     // the action that last set this membership
}
```

Provider reality: **only Koios serves the committee at all.** db-sync counts
members and reads the quorum for the dashboard but never returns membership;
Blockfrost has no committee resource (`/governance/committee` → 400).

## Constitution

```ts
interface Constitution {
  anchor: Anchor;
  guardrailsScriptHash: Hex | null;
  enactedBy: GovActionRef | null;
  enactedAt: EpochStamp | null;
  document: MetadataProjection<ConstitutionBody> | null;   // <- D10 conflict
}
```

**`document` is a resolved metadata projection inside a chain-data entity —
exactly what D10 removed from proposals and DReps.** It should become
anchor-only unless the D36 narrow-exception reasoning applies.

Provider reality: only Koios. db-sync never reads the `constitution` table; the
legacy frontend fetched the document from IPFS directly.

## SPOs as voters

```ts
interface SpoVoter {
  poolId: Bech32;              // note: not CIP-129 — pools predate it
  ticker?: string;
  name?: string;
  liveStake?: Lovelace;
  activeStake?: Lovelace;
  pledge?: Lovelace;
  votingPower: VotingPower | null;
}
```

Provider reality: only Koios. db-sync reads `pool_stat` only to weight an SPO
tally; nothing reads `pool_hash`. Blockfrost's `/pools/{id}` times out.

`ticker` and `name` come from **pool metadata**, which is a different off-chain
document standard from CIP-100/108/119 — another D10 question.

## Transactions

```ts
interface TransactionState {
  txHash: Hex;
  status: TxStatus;
  confirmations?: number;
  includedAt?: EpochStamp;
  effects?: TxGovernanceEffect[];      // classified governance effects
  votingProcedures?: unknown[] | null; // untyped fallback  <- provider-shaped
}
```

Sole purpose: post-submission confirmation polling — the user submits a vote or
a registration and the UI waits. Provider reality: db-sync and Koios serve it;
Blockfrost's `/txs/{hash}` answers 500 on the verified deployment.

`votingProcedures?: unknown[]` is provider-shaped and of the same family D1 and
D59 removed.

## D61 — Constitution is required; it is an anchor, not a document

**Said:** "constution is offlien data. The constution hash and the ancoor
provide link to the markdown of th econstution."

- `Constitution` carries **`anchor` (url + dataHash)** and nothing resolved.
  **`document: MetadataProjection<ConstitutionBody>` is removed** — the D10
  conflict is closed the same way as proposals and DReps.
- The anchor points at the constitution markdown; the metadata service fetches
  it.
- **The constitution is required** of a chain-data provider (contrast D62).
- `guardrailsScriptHash`, `enactedBy` and `enactedAt` are on-chain facts and
  stay.

## D62 — Committee membership is on-chain ids; committee *info* is a separate optional provider

**Said:** "committee is just id in the chain, we need committee info provider,
that can give extra details of the committee members. The committee info is
optional but constution is not." / "those are cryptographic identity but the
real identity comes from the offchain information. I am not sure where it sits
but provider can optionally give this data."

- What the chain has is **credentials** — cold and hot. That is the whole of the
  on-chain committee identity.
- **Human identity of a committee member is off-chain** and is served by a
  separate, **optional** **committee info provider**.
- **Committee info is optional; the constitution is not.**

### F13 — Why committee info cannot be part of the metadata service

Every other off-chain document in this spec is **anchored**: the chain carries a
`{ url, dataHash }` pointing at it. DRep metadata (CIP-119), governance action
metadata (CIP-108), vote rationales (CIP-100) and the constitution all work this
way, which is what makes a single metadata service possible — it resolves
anchors.

**A committee member has no anchor.** An `UpdateCommittee` action names cold
credentials and nothing else; there is no on-chain pointer to a document
describing who they are. So committee info cannot be "resolve the anchor" — it
must come from a **curated source**, which is a different kind of thing and is
why it needs its own provider.

This also explains the asymmetry the user noticed but was unsure about
("I am not sure where it sits"): SPO details *are* anchored — by the pool
registration certificate's metadata url and hash — so they can flow through the
metadata service. Committee member identity cannot.

## D63 — SPO details come from the metadata service, not the chain-data provider

**Said:** "Yeh the constution text and spo details are all coming from offchain
metadata service. the provider doesn't need to send the resolved data only the
hash and anchor url"

- `SpoVoter.ticker` and `SpoVoter.name` are **removed** from the chain-data
  entity. They are pool metadata, anchored by the pool registration certificate.
- The chain-data provider serves the **anchor (url + hash)** only.
- Applies the D10 rule to the last entity that was still violating it. **After
  D61 and D63 there is no resolved metadata anywhere in chain data**, with the
  single documented exception of the governance-action `title` in a vote listing
  (D36).

## D64 — Identifiers use the current standard bech32 form per entity type (amends D27)

**Said:** "yeh i menat pool1 the bech32 representation i meant to say that the
representation should be the latest standard bech32 format whichever cip or spec
it is."

**D27 said "CIP-129 for everything". That was too broad.** The rule is:

> Every identifier uses **the current standard bech32 representation for that
> entity type**, whichever CIP or specification defines it.

| Entity | Form |
|---|---|
| DRep credential | CIP-129 |
| Governance action id | CIP-129 |
| Committee hot / cold credential | CIP-129 |
| Stake pool id | `pool1…` bech32 (predates CIP-129) |
| Stake address | `stake1…` bech32 |

- The intent behind D25/D27 is unchanged: **one canonical textual form on the
  wire**, decoded and validated rather than string-matched, with any other
  rendering being a backend/display concern.
- The spec must name the form per entity type rather than citing a single CIP,
  and should say it tracks the current standard as those evolve.

## D65 — Transaction status: the minimum is "is it on chain"

**Said:** "the minimum is (whether or not the tx is in the chain)"

- `transactions.get` returns **whether the transaction is on chain**. That is
  the required surface.
- **`votingProcedures?: unknown[]` is dropped** — provider-shaped, of the same
  family as `providerId` (D59) and the raw `epoch_param` row (D1).
- `effects` (classified governance effects) was not endorsed; treated as **not
  required**. Recorded as dropped from the required surface pending objection.

## D66 — Transaction monitoring is a separate, fully optional service

**Said:** "we can add a optional transaction monitoring service that will report
the tx is in mempool or confirmed or no of confirmation up to 5 confirmations
but fully optional. the polling of the tx already handles it."

- A **transaction monitoring service**, distinct from chain data and **fully
  optional**:
  - transaction is **in mempool**
  - transaction is **confirmed**
  - **number of confirmations, up to 5**
- Rationale as given: plain polling of `transactions.get` already covers the
  basic need, so this is an enhancement, not a dependency.
- Mempool visibility is the part chain data structurally cannot provide — a
  transaction in the mempool is not on chain yet, so no ledger-derived source
  can see it. That is what justifies a separate component rather than a
  capability flag.

---

## F14 — The architecture the decisions have converged on

Not a decision; an observation from D45, D47, D62 and D66. The spec is settling
into **a small required core plus optional satellites**:

| Component | Status | Serves |
|---|---|---|
| **Chain data** | required | everything derivable from the ledger |
| **Metadata service** | required | resolves anchors → documents (CIP-100/108/119, constitution, pool metadata) |
| **Pinning service** | optional | the author write path |
| **Index provider** | optional | DRep and proposal search (D45, D47) |
| **Committee info provider** | optional | human identity of committee members (D62) |
| **Transaction monitoring** | optional | mempool and confirmation depth (D66) |

Three properties worth stating in the spec:

1. **The core stays small.** Every enrichment that needs an index, a curated
   list, or visibility the ledger does not have became its own optional
   component rather than an optional field on chain data.
2. **The split is principled, not arbitrary.** A component exists where the
   *source of truth* differs — ledger, anchored document, curated list,
   mempool — not where the data is merely inconvenient.
3. **Optional means the product degrades, not breaks.** Each satellite maps to
   a named UI surface that disappears when it is absent (D34's pattern).

See OPEN-28.

---

## Open questions (updated)

- **OPEN-27** — Is `accounts.getDelegation` required? (Still unanswered.)
- **OPEN-28** — Confirm the six-component architecture in F14, and whether
  committee info and the index are genuinely separate components or one
  "governance enrichment" provider.
- **OPEN-29** — Is base committee **membership** (cold/hot credentials, quorum,
  terms) required of a chain-data provider, or optional? D62 settled that
  member *info* is optional and the constitution is required, but not the
  on-chain membership itself. Only Koios serves it today.
- **OPEN-30** — Are SPOs as voters required at all? After D63 strips ticker and
  name, `SpoVoter` is a pool id, stakes and voting power. Only Koios serves it.

## D67 — The six-component architecture is confirmed (closes OPEN-28)

**Said:** "The pillars are good."

F14's structure stands: **chain data** and **metadata service** required;
**pinning**, **index**, **committee info** and **transaction monitoring**
optional. Committee info and the index remain separate components — different
sources of truth (a curated list vs a text index).

## D68 — On-chain committee membership is required (closes OPEN-29)

**Said:** "the committee details cold/hot credentials and quorum and terms are
ofcourse required. I said the extra metadata and the identity information is
optional and provided by the committee info provider"

**Required** of a chain-data provider:

- cold credential, hot credential
- quorum
- term start / term expiry
- (resignation state follows from the same certificates)

**Optional**, via the committee info provider (D62): human identity, names,
descriptions, any off-chain enrichment.

The line is clean: **the chain-data provider serves what the ledger records; the
committee info provider serves who those credentials belong to.**

## D69 — SPO details required; vote aggregates required; individual votes optional

**Said:** "yes pool details and also the aggregate of vote is required, but
individual votes are optional only the aggregate vote on gov-action is required"

| Surface | Status |
|---|---|
| SPO / pool details (`SpoVoter` minus ticker and name, per D63) | **required** |
| **Vote aggregate on a governance action** | **required** |
| Individual vote listing ("who voted on this") | **optional** |

### This amends D6 and D16

**D6** contemplated making "the voting progress/stats itself optional for
certain providers if blockfrost can't support them". **D69 makes the aggregate
required instead.**

The two reconcile through D16: the aggregate is **required**, but its
**representation is declared** — `percent | stake | count`. Blockfrost, which
reports tallies as head-counts rather than stake, is conformant by declaring
`count`. The escape hatch D6 reserved turns out not to be needed, because the
representation declaration already absorbs the difference.

What remains from D16 unchanged:

- `stake` is the preferred representation and the spec says so.
- The denominator must be the total **at that time**, not the current total.
- A declared representation must be served completely — the D6 rule that a
  capability is declined wholesale or served fully still holds for the
  *representation*, even though the aggregate itself is no longer declinable.

`voteAggregate: []` is therefore **no longer a legal declaration**. A provider
must express at least one representation.

## D70 — `accounts.getDelegation` is required; delegation history covers pool and DRep (closes OPEN-27)

**Said:** "ofcourse we need that and i said that it would be nice to even
optionally support pool/drep delegation history api for an account"

- **`accounts.getDelegation` is required.** It is the wallet's current
  governance delegation and the one account read GovTool cannot function
  without.
- **Delegation history (D55, D58) covers both pool and DRep delegation**, not
  governance delegation alone, and remains **optional**.

---

## F15 — Conformance consequence: the spec is now above what two of three providers can do

Stated factually, not as an objection. With **constitution** (D61), **committee
membership** (D68), **SPO details** (D69), **typed bodies for all seven action
types** (D7) and **`getEnacted`** (D18) all required:

| Requirement | db-sync | Koios | Blockfrost |
|---|:---:|:---:|:---:|
| Constitution (anchor) | ✗ never reads the `constitution` table | ✓ | ✗ no constitution resource (400) |
| Committee membership | ✗ counts members, never returns them | ✓ | ✗ no committee resource (400) |
| SPO / pool details | ✗ reads `pool_stat` only for tallies | ✓ | ✗ `/pools/{id}` times out (504) |
| Vote aggregate (any representation) | ✓ inline | ✓ | ✓ as `count` |

**Only Koios is conformant today.** db-sync fails three requirements because the
frozen legacy SQL has no statement for them — closable with new statements,
since db-sync the database holds all three. **Blockfrost fails three
structurally**: it has no committee or constitution resource at all, so no
amount of provider work makes it conformant against that API.

This is a legitimate outcome — the spec describes the target, not the current
state — but it should be explicit in the conformance section rather than
discovered by an implementer. It also means the "four providers planned"
framing (db-sync, Koios, Blockfrost, Kupo) needs revisiting: Blockfrost is now a
partial source that would need a companion component, not a standalone
chain-data provider.

---

## Open questions (updated)

- **OPEN-31** — Does Blockfrost remain a target chain-data provider given F15,
  or is it reclassified (partial source, or paired with another component)?
- OPEN-27, 28, 29, 30 — CLOSED by D70, D67, D68, D69.

## D71 — Constitution and committee are both compulsory; the constitution is derivable

**Said:** "why can't we just see latest enacted constution update gov action and
get the anchorurl/hash from it? for committree membership it is not the same
because each action is additioin/deletion, so requires the membership from fresh
(including the one from genesis) … we mark both as compulsary in the spec thats
all"

Both **compulsory**. But they are compulsory for different reasons, and the
difference determines how a provider satisfies each.

### The constitution is a replacement — derivable from already-required data

```ts
| { type: 'NewConstitution'; anchor: Anchor; guardrailsScriptHash?: Hex | null }
```

The anchor is **in the action body**. Since typed bodies for all seven types are
required (**D7**) and `getEnacted` is compulsory (**D18**), a provider obtains
the current constitution by:

> `getEnacted(Constitution lineage)` → read `body.anchor`

**No dedicated constitution resource is needed.** Each `NewConstitution` action
replaces the previous constitution outright, so the latest enacted one fully
determines the current state.

### The committee is a delta — it requires replay

```ts
| { type: 'UpdateCommittee';
    added:   { coldCredential; isScriptBased; termExpiryEpoch }[];
    removed: { coldCredential; isScriptBased }[];
    quorum:  Ratio }
```

Current membership **cannot** be read off the latest action. It requires
assembling state from genesis:

1. the **genesis committee**,
2. every enacted `UpdateCommittee` applied in order as add/remove deltas,
3. any enacted `NoConfidence`, which removes the committee entirely,
4. **`AuthCommitteeHotCert`** certificates — where hot credentials come from,
5. **`ResignCommitteeColdCert`** certificates — resignations,
6. **term expiry** evaluated against the current epoch.

Points 4 and 5 are **certificates, not governance actions**, so this is not even
"replay the action history" — it spans two different ledger record types. That
is why the committee is genuine ledger state and the constitution is not.

## F16 — Correction to F15

**F15 claimed db-sync and Blockfrost cannot serve the constitution because
neither has a constitution resource. That was wrong** — it reasoned from the
absence of a dedicated table/endpoint without checking whether the value was
derivable from data the spec already requires. It is.

Revised conformance picture:

| Requirement | db-sync | Koios | Blockfrost |
|---|:---:|:---:|:---:|
| Constitution | ✓ derivable via `getEnacted` + `NewConstitution` body | ✓ | ✓ derivable, same route |
| Committee membership | ✗ frozen SQL lacks it; db-sync *the database* has Conway committee tables | ✓ | **?** unverified — needs enacted `UpdateCommittee` history **and** hot-auth / resignation certificates |
| SPO / pool details | ✗ frozen SQL reads `pool_stat` only for tallies | ✓ | ✗ `/pools/{id}` times out (504) |
| Vote aggregate | ✓ | ✓ | ✓ as `count` |

So the constitution is **not** a differentiator between providers. The real
gaps are committee membership and pool details.

**Marked unverified rather than asserted:** whether Blockfrost exposes
`AuthCommitteeHotCert` and `ResignCommitteeColdCert` records is unknown. Without
them it cannot reconstruct committee membership regardless of proposal coverage.
This needs checking against the live instance before any conformance claim is
made about Blockfrost.

### Method note

F15 asserted a capability gap from the absence of a dedicated endpoint. The
correct test is **whether the value is derivable from data the spec already
requires**. Apply that test before recording any further conformance claim —
the same error would otherwise repeat for anything else the spec makes
derivable.

---

## Open questions (updated)

- **OPEN-31** — Blockfrost's status as a chain-data provider. Now narrower than
  F15 suggested: the open items are committee membership (unverified) and pool
  details (`/pools/{id}` times out), not the constitution.

# Pillar 6 — Governance metrics

## D72 — Global vote totals are removed

**Said:** "totalDRepVotes, totalSpoVotes, totalCcVotes — what are these, are
these on gov action or global total, global total is unuseful data. remove that"

Answer: they are **global** totals — every DRep vote ever cast, across all
actions. **Removed.** Per-action vote counts live on the vote aggregate (D69),
which is where the number is meaningful.

## D73 — The metrics/network split is by kind, not by convenience

**Said:** "for duplicates we can separate them in metrics or network, metrics are
usually aggregates of things or other computed stuffs but the network is some
network set param or protocol param etc lets distinguish it like that for
de-duplication."

The de-duplication rule:

| Belongs in **network** | Belongs in **metrics** |
|---|---|
| network state and protocol/ledger parameters | aggregates and computed counts |

Applied to the current duplicates:

| Field | Goes to | Why |
|---|---|---|
| `treasury` | **network** | network state, already `network.getTreasury` (D5) |
| `totalDRepDistribution` | **network** | a stake total, already on `StakeDistribution` (F2) |
| `committee.quorum` | **committee entity** | a governance parameter, already required (D68) |
| `committee.size` | **dropped** | derivable from required committee membership (D68) |

## D74 — The metrics route is kept

**Said:** "we keep the metrics route as they might have useful things for
dashboard later."

Kept, despite the frontend currently reading nothing from it that is not
available elsewhere. It is where future dashboard aggregates land.

## D75 — Capability declaration: the interface carries availability, a spec JSON carries options

**Said:** "I meant was that a provider has a spec json which we can directly read
in addition to the interface functions it does duplicate few things like if
already non-null function or field in the implementation directly means that it
is available, but for options like supported sorts and stuffs, we read that spec
field. but we directly check the interface function to mark a feature as
available or not."

**This refines D23 and is the final capability model.**

| Question | Answered by |
|---|---|
| **Is this feature available?** | **The interface.** A non-null method or field means available. No declaration. |
| **Which option values are honoured?** (sorts, filters, search modes, vote-aggregate representations, whether an optional argument like `epoch` is accepted) | **The provider's spec JSON.** |

- **There are no availability booleans in the spec JSON.** D23's "boolean for a
  yes/no facility" is replaced by checking whether the member exists — the
  optional-member model from D2. The interface *is* the boolean.
- The spec JSON carries **only** what structure cannot express: the accepted
  values of arguments. A method's existence cannot tell you which of five sort
  keys it honours, nor whether it accepts an `epoch` argument.
- Consequence: `get` + `getAvailable` on `MetricsApi` collapse. One method, plus
  a declared array of the counters this provider serves. `Partial<T>` as an
  escape hatch is no longer needed — the declaration says which fields come back.
- Consequence: optional **arguments** (like `epoch`) must be declared in the
  spec JSON, because argument acceptance is not structurally visible.

## D76 — Which counters, and at what obligation

**Said:** "uniqueDelegators/total delegation are cosmetic,
totalActiveDreps/TotalInactive, totalRegistered are very useful and make it
optional. We might need to declare the koios as not supporting them."

| Counter | Status |
|---|---|
| `totalRegisteredDReps` | **optional**, "very useful" |
| `totalActiveDReps` | **optional**, "very useful" |
| `totalInactiveDReps` | **optional**, "very useful" |
| `uniqueDelegators` | **cosmetic** — optional, candidate for removal |
| `totalDelegations` | **cosmetic** — optional, candidate for removal |
| `totalGovernanceActions`, `totalLiveGovernanceActions` | not ruled on — see OPEN-32 |
| `totalDRepVotes`, `totalSpoVotes`, `totalCcVotes` | **removed** (D72) |
| `totalActiveCip119CompliantDReps` | **moved out** (D79) |
| `totalRegisteredDirectVoters` | renamed per D37 → count of **anonymous** DReps; not ruled on |

**Every counter is optional.** No metric is required of a chain-data provider.
Koios will declare it does not support the three "very useful" ones, since each
needs a walk over every DRep.

## D77 — Active/inactive is a ledger fact, not a derivation

**Said:** "why would 2 providers read them differently? I don't understand."

**The concern was overstated, and the answer makes a better rule.**

In Conway the ledger tracks DRep activity explicitly: `DRepState` carries an
**`expiry` epoch**, bumped forward by `drepActivity` whenever the DRep votes or
re-registers. A DRep is inactive when `currentEpoch > expiry`. It is **ledger
state, not a computation** — so two providers reading it correctly *do* agree.

Divergence is possible only for a provider that **derives** activity from vote
history (e.g. "voted within the last N epochs") instead of reading the expiry.
That is the failure mode, and it is narrow.

**Spec rule that follows:** active/inactive must be read from the ledger's DRep
expiry. A provider must not reconstruct it from vote timestamps. This also fixes
`DRepActivity.inactiveFromEpoch` — that field *is* the ledger's expiry and
should say so.

(Distinct from D34's `x/y` participation stat, which genuinely is a computation
over a window, and which D34 fixed as "since the DRep registered".)

## D78 — Epoch support is optional and declared

**Said:** "i said that the spec defines whether or not it support epoch. epoch
support is optional."

- Asking metrics for a **past epoch** is optional.
- Declared in the provider's **spec JSON**, per D75 — argument acceptance is not
  structurally visible from the interface.

## D79 — CIP-119 compliance belongs to the metadata service

**Said:** "totalActiveCip119CompliantDReps do we use this though? anywhere in
frontend, if yes, this is a data for indexer or metadata service, or maybe both.
but that service will then need to have the chaindata to verify that" /
"cip119 is handled by the metadata service. the indexer also uses the
metadataservice to pull information"

- **Verified: the frontend does not use it.** `totalActiveCIP119CompliantDReps`
  appears **only in the type definition** (`src/models/api.ts:111`) and is read
  nowhere. The other CIP-119 references are the metadata *standard* used to
  validate an individual DRep document — unrelated.
- **CIP-119 compliance is the metadata service's concern.** It is a property of
  a resolved document, which after D10 chain data never holds.
- **The index provider consumes the metadata service.** This is the first
  declared dependency *between* components.

### F17 — The counter needs two components, which is why it has no single home

"Active **and** CIP-119 compliant" spans both: **active** is chain data (D77,
the ledger's DRep expiry) and **CIP-119 compliant** is metadata. Neither service
can compute it alone — exactly the user's observation that "that service will
then need to have the chaindata to verify that".

Since nothing reads it, the cheapest resolution is to **drop the counter** and
let it be reintroduced by whichever component ends up holding both inputs — in
practice the index, which D79 already makes a consumer of the metadata service.

### F18 — Component dependency graph, so far

```
chain data  ──────────────┐
                          ├──> index provider
metadata service ─────────┘
        ^
        └── resolves anchors emitted by chain data
```

- **metadata service** depends on chain data only for anchors.
- **index provider** depends on **both**.
- **committee info**, **pinning**, **transaction monitoring** stand alone.

---

## Open questions (updated)

- **OPEN-32** — `totalGovernanceActions` and `totalLiveGovernanceActions`: keep
  as optional counters, or drop? They are the cheapest metrics in the set
  (a count over the action table) and nothing reads them.
- **OPEN-33** — Drop `uniqueDelegators` and `totalDelegations` outright, or keep
  as optional-cosmetic?
- **OPEN-34** — Drop `totalActiveCip119CompliantDReps` entirely (F17), or assign
  it to the index provider?

## D80 — Action counters dropped; a list's `total` already answers them (closes OPEN-32)

**Said:** "those are useful for the governance action page at least the total
live gov actions (already comes from the api with the pagination detail so where
should we show that) lets drop it if somebody requests that later we can add it
to metrics (maybe for dashboards)."

- **`totalGovernanceActions` and `totalLiveGovernanceActions` are dropped.**
- Reason: the count already arrives with the **paged list** —
  `Page<T>.total` on `proposals.list({ status: ['live'] })` *is*
  `totalLiveGovernanceActions`. A separate counter restates it.
- Reinstatable later for a dashboard if something actually needs it.

### F19 — The general rule this establishes

> **Do not add an aggregate counter for anything a filtered list's `total`
> already answers.**

Any "how many X match filter Y" is available from `list(Y).total` at no extra
cost and with no risk of the two disagreeing. A metrics counter is only
warranted when the number is **not** the size of a list a consumer can ask for —
e.g. a count over delegators of every DRep, which no single list returns.

This is D9's anti-duplication rule applied to aggregates, and it is what
justifies most of the removals in this pillar.

## D81 — Delegation counters dropped (closes OPEN-33)

**Said:** "2 is drop"

`uniqueDelegators` and `totalDelegations` are **removed**. Called cosmetic; not
read anywhere.

## D82 — CIP-119 compliance counter dropped (closes OPEN-34)

**Said:** "3 drop it"

`totalActiveCip119CompliantDReps` is **removed** — unread, and computable by no
single component (F17).

---

## F20 — What `GovernanceMetrics` reduces to

From sixteen fields to three or four, all optional:

```ts
interface GovernanceMetrics {
  epoch?: EpochNo;                 // optional; epoch argument declared per D78
  totalRegisteredDReps?: number;
  totalActiveDReps?: number;       // from the ledger's DRep expiry (D77)
  totalInactiveDReps?: number;     // likewise
  // count of anonymous DReps — not yet ruled on, see OPEN-35
}
```

**Removed or relocated:**

| Field | Outcome |
|---|---|
| `uniqueDelegators`, `totalDelegations` | dropped (D81) |
| `totalGovernanceActions`, `totalLiveGovernanceActions` | dropped — `Page.total` (D80) |
| `totalDRepVotes`, `totalSpoVotes`, `totalCcVotes` | dropped — global totals (D72) |
| `totalActiveCip119CompliantDReps` | dropped (D82) |
| `totalDRepDistribution` | → **network** `StakeDistribution` (D73) |
| `treasury` | → **network** `getTreasury` (D73) |
| `committee.quorum` | → **committee** entity, required (D73, D68) |
| `committee.size` | dropped — derivable from committee membership (D73) |

Observations for the spec:

- **What survives is exclusively DRep counters.** The route named "governance
  metrics" now contains only DRep aggregates. Either it is renamed, or D74's
  intent stands — it is the landing place for future dashboard aggregates and
  the name anticipates that.
- **Every counter is optional**, so a conformant provider may serve an empty
  metrics record. That is deliberate: no dashboard tile is load-bearing.
- The three survivors are exactly the ones Koios cannot compute without walking
  every DRep, so in practice Koios serves none of them and the route is empty
  there.

---

# Chain data is complete

All six chain-data pillars are decided:

| Pillar | Outcome |
|---|---|
| Network & chain | typed `ProtocolParams` (D1), epochs/blocks cut (D5), treasury optional |
| Proposals | typed bodies required for all 7 (D7), `getEnacted` compulsory (D18), vote aggregate required (D69) |
| DReps | CIP-129 identity (D25), anonymous designation (D37), activity `x/y` since registration (D34) |
| Accounts | thin required core; delegation required (D70), everything else optional |
| Committee / constitution / SPO / transactions | constitution derivable (D71), committee is ledger state (D71), SPO details required (D69), tx minimum is "on chain" (D65) |
| Governance metrics | reduced to optional DRep counters (F20) |

**Votes** never became a pillar — D49 collapsed it into DReps and Proposals.

---

## Open questions (updated)

- **OPEN-35** — Does a count of **anonymous** DReps (formerly
  `totalRegisteredDirectVoters`, D37) survive in metrics, or drop with the rest?
- **OPEN-31** — Blockfrost's status, pending verification of whether it exposes
  committee hot-auth and resignation certificates.
- OPEN-32, 33, 34 — CLOSED by D80, D81, D82.

## D83 — DRep counters move onto the DRep namespace (closes OPEN-35, amends D74)

**Said:** "push into dreps?: {totalRegistered, totalActive, totalInactive,
anonymous?} so that if drep metric is to be given the provider will just give
all except for that anonymous."

```ts
interface DRepCounts {
  totalRegistered: number;
  totalActive: number;     // from the ledger's DRep expiry (D77)
  totalInactive: number;   // likewise
  anonymous?: number;      // DReps with no anchor (D37)
}
```

- Lives on the **DRep namespace**, not on a separate metrics route.
- **All-or-nothing for the first three.** If a provider serves DRep counts at
  all, it serves `totalRegistered`, `totalActive` and `totalInactive`. This is
  the D6 rule — decline wholesale or serve completely.
- **`anonymous` is the single optional member** inside an otherwise complete
  object.

### F21 — This empties the metrics route entirely

Tracking where every original `GovernanceMetrics` field went:

| Destination | Fields |
|---|---|
| **network** | `treasury`, `totalDRepDistribution` |
| **committee** | `quorum` |
| **dreps** | `totalRegistered`, `totalActive`, `totalInactive`, `anonymous` |
| **dropped** | the other nine (D72, D80, D81, D82, D73) |

**Nothing is left.** `GovernanceMetrics` and `MetricsApi` have no members.

This **amends D74**, which kept the route as a landing place for future
dashboard aggregates. With every field relocated, keeping an empty route is
carrying a name rather than a capability. See OPEN-36.

It also vindicates D73's rule: once "aggregates vs network state" was applied
honestly, almost everything turned out to belong to an entity that already
owned it.

---

# Component — Metadata service

## D84 — Two reads, content-addressed, with a permanent content cache

**Said:** "we need a way to getMetadata(hash:text,url?) if not found, and url is
provided, fetch is from the url and cached permanently for the resulting hash.
(errors are recorded and cached for certain duration). and we also need
getCipMetadata(cipnumber, hash, url?) to also validate it."

```ts
interface MetadataServiceV1 {
  getMetadata(hash: Hex, url?: string): Promise<MetadataResult>;
  getCipMetadata(cip: number, hash: Hex, url?: string): Promise<CipMetadataResult>;
  refresh(hash: Hex, url: string): Promise<MetadataResult>;   // D86
}
```

- **`getMetadata(hash, url?)`** — look up by hash. If absent and a `url` is
  supplied, fetch it.
- **`getCipMetadata(cip, hash, url?)`** — the same, plus validation against the
  named CIP. The CIP is a **number** (100, 108, 119), not an enum — new
  standards need no contract change.
- **Content is cached permanently**, keyed by hash. Correct because the hash
  *is* the content identity: if the hash matches, the bytes can never change,
  so the cache can never go stale. This is the property that makes the whole
  service cheap.
- **Errors are cached for a bounded duration**, not permanently — a failure is
  a statement about the network at a moment, not about the content.

### F22 — "Cached permanently for the resulting hash" — the precise flow

The wording matters and should be spelled out normatively:

1. Caller asks for hash **H**, supplying url **U**.
2. Cache miss on **H**.
3. Fetch **U**, obtaining bytes **B**.
4. Compute **H′ = hash(B)**.
5. **Cache B permanently under H′** — it is valid content for H′ whatever the
   caller asked for.
6. If **H′ ≠ H**, return `HASH_MISMATCH`.

So a hash mismatch still **populates the cache**, under the hash that was
actually served. The fetch is not wasted, and a later request for H′ is a hit.
This also means the service accumulates a record of what a url *actually*
served versus what the chain claimed — useful for diagnosing a publisher who
changed a document after anchoring it.

## D85 — Failure codes

**Said:** "on failures or invalid metadata, we have the proper code like
EXCEEDS_LIMIT, JSON_PARSE_ERROR, HASH_MISMATCH, FETCH_ERROR (the fetch related
errors like dns lookup failure or ip resolved but timeout or connection refused
etc should be in the message so that it is distinguishable and informative)."

| Code | Meaning |
|---|---|
| `EXCEEDS_LIMIT` | the document is larger than the service will accept |
| `JSON_PARSE_ERROR` | retrieved, but not parseable |
| `HASH_MISMATCH` | retrieved and parsed, but the hash does not match (F22) |
| `FETCH_ERROR` | could not retrieve |

- **`FETCH_ERROR` carries its detail in the message**, not in further codes:
  DNS lookup failure, resolved-but-timeout, connection refused, TLS failure.
  The user's requirement is that these be "distinguishable and informative",
  so the message is structured enough to tell them apart — deliberately *not*
  a code explosion.
- The set is a **closed union** so a consumer can switch on it exhaustively.

## D86 — A cache-busting endpoint

**Said:** "WE NEED A cache buster endpoint, that users may call for a metadata
with hash and url to retry/check if issue is solved."

- Takes a **hash and a url**, forces a re-fetch, bypassing the cached error.
- User-facing: someone who fixed their metadata hosting can verify the fix
  without waiting for an error cache to expire.
- Only meaningful against **cached errors**. A permanently cached success can
  never be wrong (F22), so there is nothing to bust.

---

# Component — Index provider

## D87 — A search index over governance entities

**Said:** "search index on the available data. This will take gov action, drep or
pools etc and make them searchable with term query and additional filters
depending on what we are searching."

- Entities: **governance actions, DReps, pools** — **pools are newly in scope**;
  D45/D47 had only DReps and proposals.
- Shape: a **term query** plus **entity-specific filters** — the filters differ
  per entity, because what you can narrow a DRep search by is not what you can
  narrow an action search by.
- Consumes chain data **and** the metadata service (D79, F18): the searchable
  text lives in resolved documents.

---

# Component — Pinning service

## D88 — Four operations

**Said:** "pinningservice is just pin_data(buffer) and get_data_cid(buffer) and
unpin() and fetch(cid) the constructor may require the authentication params."

```ts
interface PinningServiceV1 {
  pinData(data: Buffer): Promise<Cid>;
  getDataCid(data: Buffer): Promise<Cid>;   // compute only, no pin
  unpin(cid: Cid): Promise<void>;
  fetch(cid: Cid): Promise<Buffer>;
}
```

- **`getDataCid`** computes the CID **without pinning** — so an author can
  obtain the hash to put on chain before, or without, committing to storage.
- Authentication is a **constructor concern**, not part of the method surface.
- Much smaller than the existing `PinningServiceV1`, which carries pin records,
  statuses, failure reasons, policies and backend health. See OPEN-37.

---

# Component — Transaction monitoring

## D89 — Callback-based, for user-submitted transactions

**Said:** "transaction monitoring is simply add(tx_hash,callback()) and just
calls that function to update and notify back to the websocket or internal
provider. simply there for user submitted transaction monitoring and giving them
link to an explorer."

```ts
interface TransactionMonitorV1 {
  add(txHash: Hex, callback: (update: TxUpdate) => void): void;
}
```

- **Push, not pull.** The only interface in the whole spec that is
  callback-driven; everything else is request/response. The callback feeds a
  websocket or an internal listener.
- Scope: **user-submitted transactions only** — the ones GovTool itself just
  helped construct. Not a general transaction watcher.
- Also supplies an **explorer link** for the transaction.
- Reports mempool presence, confirmation, and confirmation depth up to 5 (D66).

---

## Open questions (updated)

- **OPEN-36** — `GovernanceMetrics` / `MetricsApi` are now empty (F21). Delete
  the route, or keep an empty namespace as a future landing place (D74)?
- **OPEN-37** — Does the existing rich `PinningServiceV1` (pin records, pin
  status, failure reasons, policy, backend health) collapse to D88's four
  methods, or does D88 describe only the core and the rest survives?
- **OPEN-38** — `getCipMetadata` validates against a CIP. What code does a
  *validation* failure return? D85's four codes cover retrieval, parsing and
  hashing, but not "parsed fine, violates CIP-119".
- **OPEN-39** — Is the cache-buster rate-limited or authenticated? An open
  endpoint that forces outbound fetches is a request-amplification vector.
- **OPEN-40** — Does the index consume pool metadata through the metadata
  service too, given pools are now indexed (D87) and their details are anchored
  by the pool registration certificate (D63)?

## D90 — The metrics route is deleted (closes OPEN-36, amends D74)

**Said:** "do we need it somewhere in ui at the present? otherwise delete."

**Verified: no.** The frontend reads exactly two fields from metrics —
`quorumNumerator` and `quorumDenominator` — and after D68/D73 the quorum is a
required field on the **committee entity**. The *data* is still needed; **this
route** is not.

`GovernanceMetrics` and `MetricsApi` are **removed from the contract**. This
reverses D74. Everything they carried now lives on the entity that owns it
(F21), and a future dashboard aggregate can be added to whichever entity owns
it then — or reintroduce the route at that point.

## D91 — `SCHEMA_INVALID` joins the metadata failure codes (closes OPEN-38)

**Said:** "SCHEMA_INVALID and message with field and reason for which it was
invalidated."

| Code | Meaning |
|---|---|
| `EXCEEDS_LIMIT` | larger than the service accepts |
| `FETCH_ERROR` | could not retrieve (detail in message) |
| `JSON_PARSE_ERROR` | retrieved, not parseable |
| `HASH_MISMATCH` | parsed, hash does not match (F22) |
| **`SCHEMA_INVALID`** | **parsed and hash-correct, but violates the named CIP** |

- `SCHEMA_INVALID` is what `getCipMetadata` exists to detect — the case the
  other four cannot express.
- **The message carries the field and the reason** it failed validation. Same
  pattern as `FETCH_ERROR`: one code, structured detail in the message, rather
  than a code per failure mode.
- The five codes form a natural pipeline — retrieve → size → parse → hash →
  validate — and each code names the stage that failed.

## D92 — Pinning keeps failure reasons and health, and gains an owner

**Said:** "we need failure reasons. (we can add scope of supporting owner of the
pin (the drep id or stake or whatever) that will drastically help on quota and
usage monitoring and blocking excessive use. and yeh health is a good idea."

D88's four methods are the **core**, not the whole service. Retained and added:

| Element | Status |
|---|---|
| `pinData`, `getDataCid`, `unpin`, `fetch` | core (D88) |
| **failure reasons** | **retained** |
| **backend health** | **retained** |
| **pin owner** | **new** — a DRep id, stake address, or other identity |
| pin records / pin status | not ruled on — see OPEN-41 |

### Why the owner matters

Owner-scoping is the enabler for **quota, usage monitoring, and blocking
excessive use**. Without it the pinning service cannot attribute a pin to
anyone, so it can only rate-limit in aggregate — which throttles everyone when
one author abuses it.

Two notes for the spec:

- The owner is a **public chain identity** (DRep id, stake address), so
  recording it raises no new privacy exposure beyond what is already on chain.
  It does mean the pinning service knows who pinned what, which is the point.
- The owner should be **supplied by the caller** (the backend knows the
  connected wallet), not inferred by the pinning service, which has no way to
  authenticate it.

## D93 — Authentication and rate limiting are the backend's, not the provider's (closes OPEN-39)

**Said:** "Backend will decide authentication on that not the provider. we are
not making backend remember, it is a spec for interfaces to be used in backend."

- Authentication, authorization and rate limiting for the cache-buster — and
  every other endpoint — are **backend concerns** and **out of scope for this
  spec**.
- Reaffirms **D3** (the spec is the provider↔backend interface) and **D60** (the
  spec states obligations; it does not design around misuse).
- The spec may *note* that an operation is expensive or amplifying, so a backend
  author knows to protect it. It does not prescribe the protection.

## D94 — The index reads pool metadata through the metadata service (closes OPEN-40)

**Said:** "yeh metadata service for the win."

- Pool metadata — anchored by the pool registration certificate (D63) — is
  resolved by the **metadata service**, the same path as DRep (CIP-119),
  governance action (CIP-108) and vote (CIP-100) documents.
- The index consumes it from there (D79, F18). One resolution path for every
  anchored document in the system, with no special case for pools.
- Confirms the metadata service as the single resolver: **chain data emits
  anchors, the metadata service resolves them, the index searches the results.**

---

## Open questions (updated)

- **OPEN-31** — Blockfrost's status as a chain-data provider, pending
  verification of committee hot-auth and resignation certificate availability.
- **OPEN-41** — Do pin *records* and pin *status*
  (`pinning`/`pinned`/`failed`/`unpinned`) survive in the pinning service, or
  do failure reasons and health suffice?
- **OPEN-42** — The **committee info provider** (D62) has been named but never
  specified. What is its interface?

## D95 — Pinning is async-blocking; there is no pin status (closes OPEN-41)

**Said:** "pinning... is a weird status what are you talking about? the pin
should be async method that blocks until the pin is complete."

- `pinData(buffer)` is an **async method that resolves when the pin is
  complete**. It does not return a handle to poll.
- **`PinStatus` (`pinning` / `pinned` / `failed` / `unpinned`) is removed.** With
  a blocking call there is no intermediate state to observe: it resolves with
  the CID, or it rejects with a failure reason (D92).
- Pin *records* likewise are not part of the read surface. What survives from
  the old rich service is exactly what D92 named: **failure reasons**, **backend
  health**, and the new **pin owner**.
- This removes an entire state machine from the contract. The author's flow is
  linear: call `pinData`, get a CID, anchor it on chain.

---

## F23 — Blockfrost mainnet validated: the failures were blockfrost-ryo, not Blockfrost

**Date:** 2026-09-22. Probed the hosted Blockfrost mainnet API directly at the
user's request. **This overturns most of F15 and part of F16.**

| Endpoint | blockfrost-ryo (previously recorded) | **Blockfrost mainnet (measured)** |
|---|---|---|
| `/governance/committee` | 400 "Invalid path" — no resource | **200** — full committee |
| `/pools/{id}` | 504 timeout | **200 in 0.75 s** |
| `/network` (treasury, reserves) | 500 | **200** — treasury and reserves present |
| `/txs/{hash}` | 500 on every hash | **200** |
| `/governance/constitution` | 400 | **400 — genuinely absent** |
| `/governance/committee/{cc_cold_id}` | — | **400 — no per-member detail route** |

### The committee response

```json
{
  "gov_action_id": "gov_action1w2w64uhelz0cg2np7m37hal905tdd7jpzm3fcyc3g7qvkwgfppgqqfsggt5",
  "is_dissolved": false,
  "quorum": { "numerator": 2, "denominator": 3 },
  "members": [
    { "cc_cold_id": "cc_cold1zg90nyz…", "cc_cold_hex": "0af99047…", "cc_cold_has_script": false,
      "cc_hot_id":  "cc_hot1q2ccqmm…",  "cc_hot_hex":  "b1806f7a…", "cc_hot_has_script":  false,
      "status": "authorized", "expiration_epoch": 799 }
  ]
}
```

**This is exactly what D68 requires** — cold credential, hot credential, quorum,
term expiry, and authorisation status — served in one call.

### Revised conformance picture

| Requirement | db-sync | Koios | Blockfrost |
|---|:---:|:---:|:---:|
| Constitution | ✓ derivable (D71) | ✓ | ✓ derivable (D71) |
| Committee membership | ✗ frozen SQL | ✓ | **✓ measured** |
| SPO / pool details | ✗ frozen SQL | ✓ | **✓ measured** |
| Treasury | ✗ frozen SQL | ✓ | **✓ measured** |
| Transaction lookup | ✓ | ✓ | **✓ measured** |
| Vote aggregate | ✓ | ✓ | ✓ as `count` |

**Only db-sync is non-conformant, and only because of the frozen-SQL rule.**
Blockfrost is a viable chain-data provider. OPEN-31 is closed in its favour.

### Method note — twice now

F15 asserted Blockfrost could not serve the committee, the constitution or pool
details. **All three were wrong**, from two different mistakes:

1. **F16's error** — inferring a gap from a missing endpoint without asking
   whether the value was derivable (the constitution).
2. **This error** — treating findings from one *deployment* (`blockfrost-ryo`,
   self-hosted) as properties of the *API*. The earlier note that a deployment
   fault "must never be baked into a compile-time constant" was recorded in the
   old capability model and then violated in the analysis.

**Rule for the conformance section: a capability claim must name the deployment
it was measured against, and a fault on one instance is never a property of the
provider.**

## F24 — Threshold representation, measured

On Blockfrost mainnet `/epochs/latest/parameters`:

```
dvt_committee_normal        0.67      <- float
dvt_p_p_gov_group           0.75      <- float
pvt_committee_normal        0.51      <- float
```

but on `/governance/committee`:

```
quorum   { "numerator": 2, "denominator": 3 }    <- exact ratio
```

**The asymmetry is informative.** `2/3` cannot be written as a terminating
decimal, so Blockfrost preserves its structure. `0.67` and `0.51` can, so they
ship as floats — but the ledger value behind them is still the rational
`67/100`, `51/100`.

Consequences for **D4** (thresholds are `Ratio`) and **D21**:

- Exact rationals **do** exist in at least one source, so D4 is not asking for
  something no provider can supply.
- The bounded-denominator reconstruction proposed in D21 recovers both cases:
  `0.67 → 67/100` directly, and `0.6666666666666666 → 2/3` exactly via
  continued fractions well within a denominator cap of 1000.
- So the D21 fallback is **validated, not merely plausible**.

Two incidental observations for the `ProtocolParams` mapping (D1):

- Blockfrost returns deposits, epoch counts and sizes as **strings**
  (`"500000000"`, `"146"`, `"6"`), not numbers. A provider must parse.
- Both `pvt_p_p_security_group` and `pvtpp_security_group` are present with the
  same value — Blockfrost carries two spellings of one parameter. A mapper must
  pick one and not double-count.

---

## Open questions (updated)

- **OPEN-42** — The committee info provider's interface. Research agent
  dispatched; pending.
- **OPEN-43** — Given F23, does the **frozen-SQL rule** for db-sync yield? It is
  now the sole cause of the sole non-conformant provider, and db-sync the
  database holds all three missing values.
- OPEN-31, OPEN-41 — CLOSED by F23, D95.

## D96 — The frozen-SQL rule is lifted (closes OPEN-43)

**Said:** "We will modify the sql to get the data we want. current queries won't
be a limitation."

- The db-sync provider's **17 byte-identical legacy SQL files are no longer
  frozen.** New statements may be written, existing ones changed.
- This was one of the two load-bearing rules of the original design. It is gone.

### What it unblocks

Every db-sync gap recorded in this document was caused by the frozen rule, not
by missing data — db-sync the database holds all of it:

| Requirement | Previously blocked by |
|---|---|
| Committee membership | no statement; the Conway committee tables exist |
| SPO / pool details | `pool_stat` read only to weight tallies |
| Treasury | no statement reads `ada_pots` |
| Epoch / block listings | no statement (though D5 cut these anyway) |
| Delegation history (D55, D58) | `get-current-delegation.sql` is `LIMIT 1` |
| DRep registration / update history (D42) | both statements collapse to the newest row |
| DRep delegator list (D32) | nothing reads `delegation_vote` by DRep |
| Per-action vote listing (D69, optional) | `get-votes.sql` keyed on a DRep credential |
| **DRep activity window (D34)** | the statement computes a trailing 365 days, where D34 requires "since registration" |

The last one was a **conformance failure**, not merely a gap: F6 recorded that
db-sync's trailing-365-day `votesCast` produces a different ordering from the
same chain than the spec requires. D96 is what makes fixing it possible.

### What it costs

The rule existed to guarantee behavioural identity with the Haskell backend by
construction — byte-identical SQL cannot drift. **That guarantee is now gone**
and must be replaced by verification:

- Compatibility with the Haskell backend becomes a matter of **tests**, not of
  textual identity.
- The `diff -r` check against `backend-ts/sql` stops being meaningful and should
  be removed rather than left to rot.
- Any statement that is changed needs a test pinning the behaviour the legacy
  one had, where that behaviour is still wanted.

### Conformance outcome

With D96 and F23 together, **all three providers can be conformant**:

| Provider | Status |
|---|---|
| **db-sync** | conformant once new statements are written; the data is all present |
| **Koios** | conformant today |
| **Blockfrost** | conformant today (F23), except the constitution, which is derivable (D71) |

No provider is structurally excluded by the spec. That is a better place to
write it from than the picture in F15.

---

# Component — Committee info provider

## F25 — Research findings: cold credential is the identity

Investigated 2026-09-22 by a dispatched research agent. Findings, with the
evidence level marked, because much of the platform survey could not be
completed.

### The identity question — answered, well evidenced

**The cold credential is the durable identity. The hot credential is a
revocable capability.**

| Evidence | Source |
|---|---|
| `cc_cold_id` / `cc_cold_hex` **required** on every member; `cc_hot_id` / `cc_hot_hex` **nullable**, present only when `status: authorized` | Blockfrost OpenAPI schema |
| Querying votes **by cold credential aggregates across hot-key rotations** | Blockfrost `/governance/committee/{cc_id}/votes` docs |
| Same pattern — `cc_cold_hex` unconditional, `cc_hot_hex` `anyOf [string, null]` | Koios `committee_info` schema |
| Cold identifies the seat and is long-lived; hot is rotatable. A compromised hot key is re-authorised; a compromised **cold** key can only resign | CIP-1694 / credential-manager docs |

Corroborated independently by the live probe in F23, where every member carried
a cold id and `status: "authorized"`.

### F26 — A real defect this exposes in the current contract

```ts
export interface VoterRef {
  /** CIP-129 bech32 (`drep1…`, `cc_hot1…`, `pool1…`). Canonical id used in URLs. */
  id: Bech32;
}
```

**`VoterRef.id` uses the HOT credential as the canonical id for committee
members.** Hot-key rotation is a routine, expected operation — so under the
current contract a member's canonical id **changes when they rotate**, breaking
every URL and every stored reference to them.

The Koios provider already compensates: `getMember(id)` matches against cold id,
hot id, or either raw hex, so lookups survive the choice. That is a workaround
for a contract that picked the wrong key.

**Fix: `VoterRef.id` for a committee member is the COLD credential.** The hot
credential is a separate field, nullable, because it is absent until authorised
and changes over the seat's life.

Also flagged: `VoterRef.cip105Id` should be **dropped**. D29 removed `view` and
D64 fixed one canonical form per entity type, with any other rendering being a
backend/display concern. `cip105Id` is the same leak under a different name.

### No registry, no standard — verified absent

- **No public registry, GitHub JSON repo, or CIP-backed schema** for committee
  member identity was found.
- **CIP-129** encodes credential identifiers only — explicitly not an identity
  spec. **CIP-136** is vote-rationale metadata. **There is no CIP-119 analogue
  for committee members**, and CIP-1694 deliberately omits identity
  verification, leaving it to community discretion.
- The only confirmed curated source is **Intersect publishing its own council
  representatives' names on its own site** — one seat's occupants, not the
  committee, and not a reusable schema.
- Neither Koios nor Blockfrost carries a name, organisation, avatar, country or
  contact field. **They are chain-state mirrors only**, which is precisely why
  D62 required a separate provider.

### What could NOT be verified — stated plainly

The platform survey largely failed on access, so "how existing platforms do it"
is **not** answered:

- **gov.tools** Constitutional Committee Portal — domain unreachable.
- **Cardanoscan** — blocked by a bot challenge.
- **cexplorer.io** — rendered blank headless.
- **adastat.net** — no committee-member page located.
- **1694.io / tempo.vote** — no matching committee display found.
- Whether anyone curates identity for the **non-Intersect seats**.
- Whether an **open CIP PR or issue** proposes committee identity metadata —
  only merged, numbered CIPs were checked.

The API and CIP layer *is* well evidenced, and that is the layer this decision
actually rests on. The UI survey would have been corroboration, not the basis.

### Proposed interface

Keyed on cold, every descriptive field optional, because no source is
authoritative and there is no anchor to enforce a MUST against:

```ts
interface CommitteeInfoProviderV1 {
  getMemberInfo(coldCredentialId: Bech32): Promise<CommitteeMemberInfo | null>;
}

interface CommitteeMemberInfo {
  coldCredentialId: Bech32;   // required — the only stable join key
  name?: string;
  organisation?: string;
  avatarUrl?: string;
  country?: string;
  bio?: string;
  contactLinks?: { label: string; url: string }[];
  source?: string;            // provenance: "intersect" | "self-submitted" | "curated"
  lastUpdatedAt?: Timestamp;
}
```

- `null` means "no curated record", which is the normal case and not an error.
- A consumer resolves hot → cold through the on-chain committee read first, then
  looks up identity by cold id — so identity **survives hot-key rotation**.
- `source` is worth keeping: with no authoritative registry, provenance is the
  only thing letting a consumer judge how much to trust a name.

---

## Open questions (updated)

- **OPEN-44** — Confirm the committee info interface above, and whether
  `avatarUrl` should instead be an inlined image, as D51 chose for provider
  icons.
- **OPEN-45** — Confirm the F26 fix: `VoterRef.id` = cold credential for
  committee members, hot as a separate nullable field, and `cip105Id` dropped.

## D97 — Committee member images are URLs, not inlined (closes OPEN-44 in part)

**Said:** "for committee members we will prefer image url. Provider is a
software thing. committee member is not."

- `CommitteeMemberInfo.avatarUrl` stays a **URL**.
- **Deliberately different from D51**, where a provider's icon is an inlined
  base64 PNG. The distinction is the subject, not the mechanism:

| | Provider icon (D51) | Committee member avatar (D97) |
|---|---|---|
| Subject | a piece of software | a person |
| Count | a handful, fixed | one per seat, changes with the committee |
| Size | small, icon-scale | photo-scale |
| Why | attribution must render with no second fetch | a portrait is worth a fetch |

The rest of the proposed `CommitteeInfoProviderV1` interface (F25) is otherwise
unamended and awaits confirmation.

## D98 — The cold key is an optional denormalized field on a vote's voter reference

**Said:** "ahh interesting so like we are allowing a govaction title to be passed
in the vote list, we keep cold_key as optional field for now. (now whether or
not the cold key is valid is something else altogether). the providers should
prefer to resolve the cold_key say that in docs but it will be kept optional."

### The two contexts, resolved differently

| Context | Cold | Hot |
|---|---|---|
| **Committee entity** (the seat) | **required** — it *is* the seat | nullable — absent until authorised |
| **A vote's voter reference** | **optional** — a denormalization the provider may fill | present — it is what the transaction carries |

A vote's on-chain voter field for a committee member is the **hot** credential.
Resolving it to the cold credential is a join the provider may or may not have
performed, so the contract cannot demand it.

- **Providers SHOULD resolve and supply the cold key.** This is a documented
  preference, stated in the spec, not an obligation.
- **Validity of a resolved cold key is a separate concern** and explicitly not
  this field's problem.

### F27 — Exactly the D36 pattern, and worth naming as one

The user drew the parallel themselves: this is the same shape as the governance
action **title** in a vote listing (D36).

| | D36 — action title | D98 — cold key |
|---|---|---|
| What it is | a denormalized field the provider may fill | same |
| What it saves | N metadata lookups to render a listing | N hot→cold lookups to attribute votes |
| Obligation | optional, documented as preferred | optional, documented as preferred |
| Fallback when absent | resolve through the metadata service | resolve through the committee lookup |

**This is now a recurring pattern and the spec should name it once** rather than
justify it twice: *an optional denormalized field, supplied as a performance
convenience, with a documented resolution path when it is absent.* Naming it
also bounds it — each instance is a deliberate, listed exception, not licence to
denormalize anything.

### The fallback path still has to exist

An optional inline field only works if there is a reliable way to get the value
when it is missing. That is `getCommitteeMemberByHotKey`, from the user's own
proposal in the preceding message. Recorded as intended; see OPEN-46.

**And it must resolve historically.** Hot keys rotate by design. A vote cast
under hot key `H1`, by a member who has since rotated to `H2`, must still
resolve to the same cold credential. A lookup that searches only *currently
authorised* hot keys leaves every vote cast under a retired key unattributable,
and silently splits a member's voting history at each rotation.

This is what Blockfrost's documentation describes when it says querying by cold
credential "aggregates across hot-key rotations" — the authorisation history is
tracked to make that work.

**A naive implementation against current membership passes every test until the
first rotation**, which is why the spec must state the requirement rather than
leave it to be discovered.

---

## Open questions (updated)

- **OPEN-45** — Drop `VoterRef.cip105Id`? (D29 removed `view`; D64 fixed one
  canonical form per entity type, other renderings being a backend concern.
  This is the same leak renamed.) Still unanswered.
- **OPEN-46** — Confirm `getCommitteeMemberByHotKey(hotId)` on the committee
  interface, resolving against the **full history** of hot-key authorisations.
- **OPEN-44** — Confirm the rest of `CommitteeInfoProviderV1` (F25), now that
  D97 has settled `avatarUrl`.

## D99 — One bech32 id per entity; `cip105Id` dropped (closes OPEN-45)

**Said:** "if we have another id we don't need extra cip105 id or things like
that only one bech32id for the latest cip recommendation."

- **`VoterRef.cip105Id` is removed.**
- The rule, stated generally: **one bech32 identifier per entity, in the latest
  CIP-recommended form.** No legacy alternates travel in the contract.
- Consistent with D29 (`view` dropped), D59 (`providerId` dropped) and D64 (one
  canonical form per entity type). Every alternate rendering is a backend or
  display concern.

## D100 — No hot→cold lookup; unresolved means the UI hides voter info (amends D98)

**Said:** "yeh it is just something i thought would be useful (lets drop it) if
provider cannot resolve cold key we are done. ui won't show the voter info that
is simpler assertion"

- **`getCommitteeMemberByHotKey` is dropped.** It is not in the contract.
- If a provider does not supply the cold key on a vote's voter reference, the
  consumer **does not show voter information for that vote**. No fallback, no
  N+1 resolution.
- Rationale as given: a simpler assertion. The same degrade-don't-substitute
  pattern as D34 (capability absent → disable the view) and D20 (declined sort →
  hide the menu item).

### F28 — This qualifies F27: the pattern has two variants

F27 named the recurring shape as "an optional denormalized field with a
documented resolution path when absent". D100 shows the second half is **not**
universal:

| | D36 — action title | D98/D100 — cold key |
|---|---|---|
| Optional denormalized field | yes | yes |
| Documented preference to supply it | yes | yes |
| **Fallback when absent** | **yes** — resolve via the metadata service | **no** — the UI hides voter info |

So the pattern is: **an optional denormalized field, supplied as a performance
convenience.** Whether a fallback exists is decided per field, and where none
exists the consumer degrades the surface rather than working around it.

## D101 — `CommitteeInfoProviderV1` confirmed (closes OPEN-44)

**Said:** "yeh correct"

```ts
interface CommitteeInfoProviderV1 {
  getMemberInfo(coldCredentialId: Bech32): Promise<CommitteeMemberInfo | null>;
}

interface CommitteeMemberInfo {
  coldCredentialId: Bech32;   // required — the only stable join key
  name?: string;
  organisation?: string;
  avatarUrl?: string;         // a URL, per D97
  country?: string;
  bio?: string;
  contactLinks?: { label: string; url: string }[];
  source?: string;            // provenance
  lastUpdatedAt?: Timestamp;
}
```

`null` means "no curated record" — the normal case, not an error.

---

# All decisions are closed

**101 decisions, 28 findings.** Every open question is resolved:

| Area | Outcome |
|---|---|
| Network & chain | typed `ProtocolParams`; epochs/blocks cut; treasury optional |
| Proposals | typed bodies for all 7; `getEnacted` compulsory by lineage; vote aggregate required |
| DReps | CIP-129 identity; anonymous by anchor absence; activity `x/y` since registration |
| Accounts | thin required core; delegation required |
| Committee / constitution / SPO / tx | committee membership required; constitution derivable; tx minimum is "on chain" |
| Governance metrics | route deleted; counters moved onto DReps |
| Metadata service | two reads plus a cache-buster; five failure codes; permanent content cache |
| Index provider | governance actions, DReps, pools; consumes chain data and metadata |
| Committee info | optional, keyed on cold credential |
| Pinning | four methods; owner, failure reasons, health |
| Transaction monitoring | optional, callback-based |
| Capability model | interface for availability, spec JSON for option values |
| Conformance | all three providers viable; frozen-SQL rule lifted |

Ready to write the specification.

---

# Corrections to the written spec

## D102 — Lovelace is an integer string

**Said:** "no it is a integer string"

The spec said "decimal string", which is ambiguous — it reads as permitting a
decimal point. **Lovelace is an integer**: 1 ada = 1,000,000 lovelace, and the
value is base-10 digits with no point and no unit suffix.

Corrected wording: *"base-10 digits, no decimal point, no units. Never a number:
ada totals exceed what a 64-bit float represents exactly, so a numeric type
silently loses precision at the top of the range."*

## D103 — The absence distinction is kept, but de-JavaScripted

**Said:** "audit this, is it necessary, because it now restricts the language for
which the spec is written to javascript only."

**Audit outcome: the distinction is necessary; the vocabulary was not.**

### It is necessary

| Field | Present-but-empty | Omitted |
|---|---|---|
| `retiredAt` | never retired — the DRep is active | provider did not join retirement data |
| `delegation` | delegates to nobody | provider does not serve delegation |
| `previousAction` | genesis — nothing precedes it | not joined on this read |

Conflating them yields a **wrong** answer rather than a vague one. "You are not
delegated" and "we cannot tell whether you are delegated" are different screens.
The information earns its place.

### The vocabulary was JavaScript-only, and is now gone

`null` vs `undefined` is a JS/TS distinction. **JSON has no `undefined`** — the
two states on the wire are *a key present with an explicit null* and *a key
omitted entirely*. That maps cleanly onto every target:

| Context | "known to be none" | "provider does not supply it" |
|---|---|---|
| JSON | key present, value `null` | key absent |
| Typed language | nullable field | optional field |
| OpenAPI | `nullable: true` | not in `required` |

The spec now states it that way and names no language.

### It was already structural

A `?` field in the TypeScript *is* "the provider may omit this". So the rule
describes what the interface already encodes rather than layering a convention
on top — which is consistent with D75 (the interface answers availability).

## D104 — `cursor` is optional

**Said:** "cursor -> is optional for pages"

- **`limit` is the only paging parameter every provider honours.**
- **`cursor` and `offset` are both optional and declared.** A provider offers
  cursor paging, offset paging, both, or neither.
- An unsupported one is **rejected** with `INVALID_INPUT`, never ignored.
- Consequence made explicit in the spec: following `nextCursor` to read a whole
  collection only works against a provider that declared cursor support. A
  consumer that needs the full set must check the declaration first.

### Open consequence

With both optional, a provider may support **neither**, in which case only the
first `limit` rows are reachable and there is no way to page further. Is that
conformant — i.e. is a single-page provider acceptable — or must a provider
support at least one of cursor or offset? See OPEN-47.

---

## Open questions

- **OPEN-47** — May a provider decline **both** `cursor` and `offset`, making
  only the first page reachable? Or is at least one required?

## D105 — Paging is `(page, size)` with a required `total` (supersedes D104, D46, D50)

**Said:** "pagination will have (size,page) compulsary that is always sufficient
and page starts from 1. The returned data will tell the total items available so
we always know how many more pages we will have."

```ts
interface PageRequest { page: number; /* 1-based */  size: number; }
interface Page<T>     { elements: T[]; total: number; }
```

- **`page` and `size` are compulsory** — every provider supports them.
- **`page` starts at 1**, not 0.
- **`total` is required** on every paged response: the count across the whole
  result set, so a consumer always knows how many pages remain.
- **Cursors and opaque continuation tokens are removed entirely.** So is
  `offset`. D104's "cursor and offset are both optional and declared" is
  superseded — there is now one model and no declaration to make.

### What this changes from earlier decisions

| Earlier | Now |
|---|---|
| D104: `cursor` and `offset` optional, declared | **one model, no declaration** |
| `total` optional — "only when the provider can count cheaply" | **required** |
| D46/D50: random is "limited, not paged", `limit` default 20 | random takes `size`, and `page` > 1 is rejected |
| "an omitted `limit` is not a promise of everything" | no longer arises — `size` is compulsory |
| OPEN-47: may a provider decline both cursor and offset? | **moot** — closed |

### Consequences to state in the spec

1. **`total` being required is a real obligation.** A provider must be able to
   count the *filtered* set, not just return a page. For SQL that is a second
   query; for a paginated HTTP source it is a header or envelope field. A source
   that genuinely cannot count cannot serve that listing. This is a stricter
   requirement than the old optional `total`.

2. **Offset-style paging is not stable under mutation.** If the underlying set
   changes between two page reads, a row can be seen twice or missed. A cursor
   avoids this; `(page, size)` does not. Accepted, because governance data
   changes slowly relative to a user paging a list — but it should be stated
   rather than discovered.

3. **This matches Blockfrost natively.** Blockfrost's API already pages with
   `?page=&count=`, so the model is proven against at least one real source
   rather than invented. Koios pages by offset/limit and db-sync by
   `LIMIT/OFFSET`; both convert with `offset = (page - 1) * size`.

4. **It strengthens D80/F19.** The rule "do not add an aggregate counter for
   anything a filtered list's `total` already answers" now holds universally,
   because `total` is always present. Previously the rule had a hole whenever a
   provider omitted `total`.

---

## Open questions

- None. OPEN-47 is moot under D105.

## D106 — `total` is optional but strongly recommended (amends D105)

**Said:** "lets make total item count not compulsary but highly recommended."

```ts
interface Page<T> { elements: T[]; total?: number; }
```

- `total` is **optional**, and the spec states it as **strongly recommended**.
- `page` and `size` remain compulsory; only the response count softens.

### The consequence that had to be specified

With `total` gone, a consumer has no way to know how many pages remain. The only
remaining end-of-collection signal is a **short page** — fewer than `size` rows
— or an empty one.

**That imposes a new obligation on the provider:** it must not return a short
page for any other reason. Returning fewer rows than asked for — because of an
internal cap, a filter applied after fetching, or a partial failure — is now
indistinguishable from "this is the last page", and would make a consumer stop
reading early with no error.

So the softening moves an obligation rather than removing one: previously a
provider had to be able to count, now it must guarantee full-size pages until
the last.

### What it costs

- A **numbered paginator cannot be drawn** without `total`; the UI falls back to
  next/previous.
- A consumer reading a whole collection cannot size the job in advance.
- **D80/F19's rule reopens a hole.** "Do not add an aggregate counter for
  anything a filtered list's `total` already answers" was universal under D105;
  it now holds only for providers that supply `total`. The rule still stands as
  guidance — the answer to a missing `total` is to supply it, not to add a
  counter beside it.

---

# Audit response — 2026-09-23

An external conformance audit (`docs/api/decisions-audit.md`, 189 lines)
checked D1–D106 against `SPEC.md` and `src/`. Verdict: `SPEC.md` tracks the
decisions closely; **`src/` does not** — roughly half the decisions are
unimplemented or contradicted there, including three whole components with no
file at all. The audit is accurate apart from one error (below).

## D107 — Stake pools are indexed

**Said:** "Lets add stake pool too optional indexing (just so that we may show
historical voting history of a stake pool). If this requires update other parts
of the spec this has to be done"

```ts
interface GovernanceIndexV1 {
  dreps?: DRepSearchApi;
  proposals?: ProposalSearchApi;
  pools?: PoolSearchApi;      // new
}
```

- Resolves a self-contradiction in `SPEC.md`: D87's prose said the index covers
  pools, the shown interface did not.
- **The "other parts" this required**, per the user's instruction: §5.5 now
  states that **a pool's own voting history is optional** — consistent with D69
  (individual vote listings optional, only the per-action aggregate required) —
  and cross-links it to §7. The two halves are distinct and both needed: chain
  data serves one pool's votes; the index makes pools findable at all.

## D108 — Search takes a term, not a mode (closes the D40 gap)

**Said:** "caller just uses the search with whatever the provider gives, caller
doesn't care, but we need to know what it supports, so placeholder can say what
type of search is supported."

- **The caller passes one term and does not name a mode.** It sends what the
  user typed; the provider applies whatever it supports. `src/`'s existing
  `search?: string` was right; what was missing was the declaration.
- **The declared mode list drives the UI's affordance, not the query.** It is
  what lets a consumer label the box honestly — "Search by DRep ID" versus
  "Search by name or ID".
- The failure this prevents: a user types a name into a box that only matches
  credentials and gets silence, with nothing to indicate the search was never
  capable of that.
- `exactId` remains required; `substring`, `freeText`, `adaHandle` are declared
  and generally belong to the index provider.

## D109 — The tie-break rule is inverted

`SPEC.md` said: *"where this document and the types disagree, the types win and
this document is a bug."* That was correct when the types were the source of
truth. After 106 decisions it is **backwards** — the types are stale and the
spec is the decided state. The audit had to work around it explicitly.

Now reads: **"This document is the decided state. Where `src/` disagrees with
it, `src/` has not caught up yet — that is a backlog item, not a correction."**

## Spec gaps closed

Four decisions were made but never written into `SPEC.md`. All now present:

| Decision | Where it landed |
|---|---|
| **D51** provider self-identity (`id`, `name`, optional inlined `icon`) | §4, new "Identifying yourself" |
| **D11** voter context — required per action, optional on a listing | §5.2 |
| **D98** optional cold key on a vote's voter reference | §5.5 |
| **D87/D107** pools in the index | §7 |

## F29 — One audit finding is wrong

The audit's systemic issue 5 states *"`SPEC.md` §4 doesn't state either rule
explicitly"* about capability declination. **It does** — §4 reads: *"Option sets
are arrays; a value absent from the array is not supported, and `[]` is a
complete refusal of that control."*

The **code** half of that finding is correct: `capabilities.ts:14-17` says
*"Declaration is BY EXCEPTION. A provider lists only what it cannot do; anything
unlisted works"* — the opposite of D23, and written before D23 and D75 existed.
That file is stale, not in dispute.

## Standing backlog — decided, not yet in `src/`

No further decisions needed on any of these; each was settled and the code has
not caught up. In the audit's priority order:

1. Strip resolved metadata from chain data (D10/D36) — `GovAction.metadata`,
   `DRep.metadata`, `Constitution.document`, `VoteRecord.rationale`, and
   `VotedGovAction.proposal` embedding a whole `GovAction`.
2. Migrate paging to `page`/`size`/`total?` (D105/D106) — touches every paged
   method.
3. Delete `metrics.ts`; move counters to `DRepCounts` on the DRep namespace (D83).
4. Reconcile metadata and pinning service surfaces to §6 and §9.
5. Field sweep: `providerId`, `adaHandles`, `cip105Id`, `SpoVoter.ticker`/`name`,
   `votingProcedures`, `rawBody`, `ProtocolParams.raw`, `DRepKind` rename,
   `DRepSort`'s stray `'status'`, `listByTx`, `listEpochs`/`listBlocks`,
   `VotesApi`.
6. Update `capabilities.ts` to the D23/D75 model.
7. Build or explicitly defer the three unimplemented components (index,
   committee info, transaction monitoring) — **the one open decision**.

---

# Implementation — 2026-09-23

## Contract reconciled to the spec

Every audit finding closed. `src/` verified clean: `providerId`, `cip105Id`,
`adaHandles`, `rawBody`, `proposedBy`, `votingProcedures`, `MetricsApi`,
`GovernanceMetrics`, `RoleTally`, `getTallies`, `listByTx`, `listEpochs`,
`listBlocks`, `VotesApi`, `directVoter`, `MetadataProjection`, `PinStatus`,
`nextCursor`, `offset` — all gone. `page`/`size`/`total?`, `GovActionLineage`,
`VoteAggregate`, `DRepCounts`, `anonymous`, `coldCredential`,
`ProviderIdentity`, `GovernanceIndexV1`, `CommitteeInfoProviderV1`,
`TransactionMonitorV1`, `SCHEMA_INVALID`, `getDataCid`, `ratioEquals` — all
present. `npm run verify` green.

**One judgement call taken, flagged for review:** `surveys.ts` (CIP-179 survey
definitions) was **deleted**. The spec never mentions surveys — they existed in
the old contract but never came up in the fresh pass. If they are still wanted,
they need a decision and a spec section.

## D110 — A frozen-mainnet fixture provider

**Said:** "we need to create an instance with frozen data with dreps, govaction
proposals there, user balances, expired proposals, votes on them blah blah. That
implementation will give us instant way to test the integration with backend and
also frontend test without having to call any remote api, direct local
development (inmemory indexed searches etc)"

`govtool-provider-fixture` — 729 lines of source over a 569 KB dataset captured
from mainnet. Implements **all six components**.

**The load-bearing design decision: mapping happens at CAPTURE time.** What
lands in `data/*.json` is already in contract shapes, so the provider is a pure
reader and a shape bug fails when the fixture is captured rather than when it is
read.

Dataset: 30 DReps (15 active / 7 inactive / 8 retired, 12 anonymous), 60
proposals (3 live / 29 expired / 28 enacted, five action types), ~1,000 votes
across 12 proposals, 10 pools, the real 7-member committee, 17 real accounts.

### F30 — The capture validated D21's ratio reconstruction against real data

D21 proposed bounded-denominator continued fractions with a cap of 1000 and D39
deprioritised it as invisible in the UI. The capture had to implement it, and it
behaves exactly as predicted:

```
0.67  -> 67/100      0.51 -> 51/100      0.75 -> 3/4
0.666666666666  -> 2/3            {numerator:2,denominator:3} -> passed through
```

Also confirmed F24's asymmetry in the wild: Blockfrost serves the committee
quorum as an exact `{2,3}` (no terminating decimal) and the dvt/pvt thresholds
as floats. The converter takes an existing rational as-is and reconstructs only
when given a float.

### F31 — The fixture is conformant but incomplete, which is the point

It declares less than it could, and each declination exercises a spec path:

- **`voteAggregate: ['count']`** — it holds voting power for the DReps it
  captured, not for every voter on an action, so a stake-weighted total would be
  assembled from partial data. It counts heads and says so. A consumer that
  renders an ada prefix is wrong and this catches it.
- **`search: ['exactId']`** on chain data — free text belongs to the index,
  which holds the resolved documents. A name searched through chain data
  correctly returns nothing, and the test asserts that.
- **no `protocolParams.epoch`** — one frozen epoch, so a past-epoch read is
  genuinely unavailable and is refused rather than faked.

### F32 — Two real bugs the tests caught

1. **Synchronous throws from Promise-returning methods.** Eight methods used
   `throw notFound(...)` inside a non-`async` arrow returning `Promise<T>`, so a
   caller doing `api.get(id).catch(...)` would have taken an uncaught
   synchronous exception. All converted to `async`. This is a hazard for every
   provider implementation, and belongs in the spec's conformance notes.

2. **`unref()` on the transaction-monitor timer** let a short-lived caller exit
   before any update arrived. Removed — the interval clears itself after the
   fifth confirmation, so it cannot hold a process open anyway.

---

## Open questions

- **OPEN-48** — Do CIP-179 surveys return to the contract, or stay deleted?
- **OPEN-49** — Should the synchronous-throw hazard (F32) be written into
  SPEC.md §11 as a conformance note?

---

# Metadata service — 2026-09-24

## D111 — Validation is a shared pure module; the service caches verdicts

**Said:** "you are misunderstanding validation with fetching. lets make a shared
validation module/ utility that simply validates. we use it both on frontend and
backend. Then we update the metadata service to cache validations too."

**Correction accepted.** The prior reasoning conflated two things:

| | Needs | Runs where |
|---|---|---|
| **Retrieval** | network, CORS-exempt origin, SSRF guard, IPFS gateways | server only |
| **Validation** | a parsed document | anywhere |

The CORS argument was about *retrieval* and does not constrain *validation* at
all. Validation is a pure function and has no reason to live on one side.

### The shared package

```ts
export const RULES_VERSION: string;
export function detectStandard(document: unknown): number | undefined;
export function validate(document: unknown, cip: number): ValidationResult;

export type ValidationResult =
  | { valid: true;  standard: number }
  | { valid: false; standard: number; issues: ValidationIssue[] };

export interface ValidationIssue { field: string; reason: string }
```

No network, no filesystem, no framework. Consumed by the metadata service (at
ingest), the frontend (authoring-time and for documents it already holds), and
the backend (rendering error states without a request).

`issues` is a **list** rather than one error, so an authoring form shows every
problem at once instead of one per submit.

### Verdicts cache exactly like content

**Keyed `(hash, cip, RULES_VERSION)`, cached permanently** — for the same reason
content is: validation is a pure function of bytes that cannot change under a
hash, so the verdict cannot change either.

`RULES_VERSION` is in the key because it is the only thing that *can* change. A
tightened CIP rule makes every prior verdict stale; bumping the version
invalidates them with no migration, and old rows remain readable as a record of
what counted as valid at the time.

### Distribution is the real constraint

Two repositories consume it — `govtool` and `drep-id/metadata` — so it must be
**published, not path-linked**. Vendoring into both is precisely what the shared
module exists to prevent: the rules are small (CIP-119 is one required field,
CIP-108 is four plus two length caps), so divergence would be silent, and **a
frontend that accepts a document the service later rejects is the worst outcome
available**.

## F33 — The merge removes an N+1 that exists today

Six frontend display components call `validateMetadata` per card inside a
`useEffect` — `DRepCard`, `DRepDetailsCard`, `GovernanceActionCard`,
`GovernanceVotedOnCard`, `DashboardGovernanceActionDetails`,
`DelegateDashboardCard`.

A twenty-DRep directory is **twenty round trips**, each asking the server to
re-fetch and re-validate a document it may already hold. Validation is happening
at **display** time when it should happen at **ingest** time.

After D111 the verdict is computed once, cached beside the content, and travels
with the entity. Those effects are deleted rather than rewritten.

## F34 — `canonizeJSON` is dead code in `metadata-validation`

Exported from `utils/index.ts`, called from nowhere. Both services hash **raw
response bytes** with blake2b-256, so they already agree and there is nothing to
reconcile in the merge.

Worth recording because JSON-LD canonization is the thing one would *expect* to
be the hard part — CIP-100 arguably hashes the canonized form. It is not
implemented. If canonical hashing is ever required that is a deliberate future
change, not a merge conflict.

## F35 — `drep-id/metadata` has no SSRF protection

It fetches any url a caller supplies, including `http://localhost`,
`http://169.254.169.254` (cloud instance metadata) and private ranges.
`govtool/metadata-validation` blocks all of these with a guard applied at **DNS
resolution time** rather than on the hostname string — so a public hostname that
resolves to a private address is still blocked.

**This is the single most valuable thing the merge carries over, and it is a
security fix rather than a feature.** It should land first regardless of the
rest of the plan.

## D112 — The hash is authoritative, the url is a hint; a mismatch is a short-lived error (amends D84, F22)

**Date:** 2026-09-24
**Said:** "hash mismatched shouldn't be cached longer the ?url=xyz means
following. once we have a content for a hash and a url, it needs no url, as
hash is fully authoritative and we can permanently cache it, but in case of
hash mismatch, it might be temporary, the url may change it's content, we
can't just assume that url will return the same content forever."

F22 said a mismatch "populates the cache" and stopped there. That is true of the
*content* and silent about the *mismatch*. The two are different facts with
different lifetimes:

| Fact | Keyed by | Lifetime | Why |
|---|---|---|---|
| bytes **B** hash to **H′** | **H′** | permanent | a hash names its bytes forever |
| url **U** served **H′** when asked for **H** | **(U, H)** | bounded, same as any error | **U** is mutable; its publisher can fix it |

### What it means for implementation

- **A lookup by hash never consults the url.** Once content for **H** is cached,
  `getMetadata(H, U)` returns it whatever **U** is, and no fetch happens. The url
  is used only on a miss, as a place to fetch from.
- **Content is never looked up by url.** A url that once served **H′** says
  nothing about what it serves now, so a cached row for **U** under **H′** must
  never answer a request for **H**.
- **`HASH_MISMATCH` is cached like `FETCH_ERROR`**: under **(U, H)**, for the
  bounded error duration, carrying **H′** as `servedHash`. After expiry, or on
  `refresh`, **U** is fetched again. If the publisher has since put the right
  document there, that fetch succeeds.
- **`refresh` and `Cache-Control: invalidate` bypass only cached errors**, a
  mismatch included. They never re-fetch cached content: it cannot be stale.
- The content cache stores the **exact bytes served**, not a re-serialization of
  the parsed document. Otherwise the stored bytes stop hashing to their key.

### F36 — `drep-id/metadata` was serving content under the wrong hash

Before this change, on a miss for **H** the service fell back to the newest
successful row for **U** and returned it with a `200`, whatever that row's hash
was. A url that had served **H′** once answered every later request for **H**
with **H′**'s document, as if it were valid. D112's second bullet is the rule
that forbids it; the fallback is removed.

Two smaller defects went with it. A mismatch returned `400` and cached nothing.
And successful content was stored as `JSON.stringify` of the JSON5-parsed
document, so any document with comments, trailing commas or non-canonical
whitespace was cached as bytes that no longer hashed to its key.

### Landed in `drep-id/metadata`, 2026-09-24

- The five D85 codes replace `INVALID_METADATA_JSON` and
  `METADATA_FETCH_FAILED`, with fixed statuses: `FETCH_ERROR` 502 (504 on
  timeout), `EXCEEDS_LIMIT` 413, `JSON_PARSE_ERROR` 422, `HASH_MISMATCH` 409,
  `SCHEMA_INVALID` 422.
- An invalid `hashAlgorithm` field reports `SCHEMA_INVALID`. It is a CIP-100
  rule running on the plain resolve path; it moves under `?cip=` with the rest
  of validation (D111).
- The `metadata` table gains nullable `code` and `servedHash` columns. Old error
  rows have no requested hash, so they are never replayed, and they expired
  within a minute of being written anyway.

---

# Metadata failure visibility — 2026-09-24

## F37 — A retry is useless when the cause is invisible

D86 gives publishers a cache-buster, so someone who fixed their hosting can
check the fix. Nobody can use it well today:

- **No user-facing retry exists.** `drep-id/metadata` supports only a
  `Cache-Control: invalidate` request header. The refresh endpoint (spec §3
  item 8) is not built. The frontend has no retry control, and
  `govtool-backend` caches nothing, so reloading the page is already a retry.
- **The cause is thrown away before it reaches the user.** The service returns
  a specific message: an upstream 404, a refused connection, a timeout, a body
  over 2048 KB, and on a mismatch both hashes. The frontend reduces every
  failure to one of three fixed labels, so an oversized file, a 404 and a dead
  host look the same.
- **No failure carries any of the served content.** The contract's
  `MetadataFailure` has no field for it. The service keeps served bytes on
  parse and schema error rows but never returns them, and it discards an
  oversized body. `govtool-backend` caps at 1 MB and reports oversize as
  `URL_NOT_FOUND`, so even the category is wrong there.

A publisher is handed a button to verify a fix and no way to learn what to fix.

## Open questions

- **OPEN-50** — Does a failure carry a sample of what the url served?
  *Recommended:* yes, as an optional `sample` on `MetadataFailure`, stored on
  the error row so a replayed error shows the same sample.
- **OPEN-51** — What is the sample's shape and size?
  *Recommended:* the first 4 KB as UTF-8 text with invalid bytes replaced, plus
  `contentType`, `httpStatus`, `receivedBytes` and `truncated`. For
  `EXCEEDS_LIMIT`, `receivedBytes` is a lower bound, because reading stops at
  the cap.
- **OPEN-52** — Which failures carry a sample?
  *Recommended:* every failure where a response arrived: `FETCH_ERROR` from a
  non-200 status, `EXCEEDS_LIMIT`, `JSON_PARSE_ERROR` and `SCHEMA_INVALID`.
  Not DNS, refusal, TLS or timeout, where nothing arrived. Not
  `HASH_MISMATCH`: the whole document is already cached under `servedHash`
  and can be read by that hash.
- **OPEN-53** — Do samples wait for the SSRF guard (F35)?
  *Recommended:* yes, as a hard ordering. Today the service fetches internal
  addresses and only reports that they failed. Returning a sample would let
  anyone read those responses, such as a cloud instance-metadata endpoint.
- **OPEN-54** — What does the frontend show on a failure, and to whom?
  *Recommended:* keep the friendly label and add a collapsed details panel with
  the code, message, upstream status, both hashes on a mismatch, and the
  sample. The sample is shown as escaped plain text, never rendered as HTML or
  links. Every viewer sees it, not only the owner: the url is public, so the
  panel reveals nothing a visitor could not fetch.
- **OPEN-55** — Where does retry appear?
  *Recommended:* on the details-page error box for DReps and governance
  actions, not on list cards. It calls the refresh endpoint through the
  backend, and the box re-renders with the new result, success or a new
  failure with its sample.
- **OPEN-56** — Is `drep-id/metadata` reachable directly from browsers, or only
  through `govtool-backend`? D93 puts rate limiting in the backend, but the
  service is public at metadata.drep.id, so its refresh bypasses that.
  *Recommended:* the service enforces its own floor of one refetch per
  (url, hash) per 10 seconds; inside that window refresh replays the cached
  result. The backend may add stricter limits on top.
- **OPEN-57** — What is the one size limit?
  The service caps at 2 MB and `govtool-backend` at 1 MB.
  *Recommended:* 2 MB in the service is the limit. The backend stops fetching
  documents itself once the service is wired in (spec §5 step 4), and until
  then reports oversize as its own oversize status, not `URL_NOT_FOUND`.
- **OPEN-58** — Does the error cache stay at one minute?
  *Recommended:* yes. With refresh available, a publisher is never stuck
  waiting, and a short window keeps a fixed url from looking broken.

## D113 — A failure links to a fetch report; it carries no inline sample (closes OPEN-50)

**Date:** 2026-09-24
**Said:** "no but there should be extra url to view what the error was, when it
was fetched what was result, what ip was tried, etc.. and the sample of the
result within the byte limit. (in case of validation error we need to actually
highlight the parts of it and show exact position. This has to be the work of
frontend, but we need to provide enough data."

- `MetadataFailure` stays small: code, short message, hashes, time. It gains one
  reference to a **fetch report**, a separate resource reached through its own
  url.
- The report is the investigation view: when the fetch ran, what was resolved,
  which IPs were tried, what each attempt did, what came back, and the body.
- **Positions are data, highlighting is the frontend's.** Every content failure
  carries exact source positions (byte offset, line, column, and a start–end
  range) so the frontend can highlight the offending text. A parse failure
  points at the character where parsing stopped. A CIP validation failure points
  at the value, or at the object missing a required field.

### What it means for implementation

- The validator in the shared package (D111) needs a **position-aware parser**.
  `ValidationIssue` gains a source range beside `field`. JSON5, which the
  service parses today, gives no positions, so the parser choice is part of the
  work.
- The fetch pipeline records every step, not only the outcome. The DNS step
  that records resolved addresses is the same step the SSRF guard runs in
  (F35), so both land in one place.

## D114 — The report carries the full body, up to the fetch limit (closes OPEN-51)

**Said:** "we return the full content governed by the fetch limit set in the
backend (note that the shortening is for messages, but for investigation, full
data may also be useful)"

- **Messages are short. Reports are complete.** The report returns every byte
  received, up to the fetch limit (D120). Past the limit it returns the first
  limit's worth and says it was cut, with the bytes received so far.
- For `HASH_MISMATCH`, the served document is already cached permanently under
  `servedHash` (D112), so the report references it and does not store it twice.

## D115 — Every failure has a report, including the ones that never connected (closes OPEN-52)

**Said:** "all types including not-fetched. the not-fetched ones should carry the
dns resolution, ips tried, the timeout or connection refused every details of
different network error types. We show the error types NETWORK, INVALID_CONTENT
or a correct json with invalidated by the cip validator"

- A failure that never produced a response still has a full report: the DNS
  answer or DNS error, each IP tried, and for each one the exact outcome. That
  means refused, reset, unreachable, timeout (and at which stage: connect, TLS,
  first byte, body), or a TLS error with its code.
- **Three display categories** group the five codes (D85), which stay as they
  are for exhaustive switching:

| Category | Meaning | Codes |
|---|---|---|
| `NETWORK` | nothing usable came back | `FETCH_ERROR` |
| `INVALID_CONTENT` | something came back, but it is not the anchored document | `EXCEEDS_LIMIT`, `JSON_PARSE_ERROR`, `HASH_MISMATCH` |
| `SCHEMA_INVALID` | the right document, valid JSON, rejected by the CIP validator | `SCHEMA_INVALID` |

The placement of `EXCEEDS_LIMIT` and `HASH_MISMATCH` is an inference, and the
third category's name reuses its code. See OPEN-60.

## D116 — Diagnostic detail is not secret (answers part of OPEN-53)

**Said:** "user has to know the details required for debugging, note that they
can see the curl and use local cli tools to fetch them too, url is not some
hidden thing"

- Nothing in a fetch report is hidden from the user: addresses, errors, headers,
  body. The url is public and anyone can fetch it themselves.
- This settles transparency. It does **not** settle whether the service may
  connect to internal addresses at all; that is the rest of OPEN-53, restated
  below.

## D117 — Who sees failure detail (closes OPEN-54)

**Said:** "Frontend shows errors to 1 -> users who are registering/creating
proposals, or the proposers who have already submitted, but now they are not
seeing it. (the data will be in details page)"

Two audiences:

1. **Authors, before submitting.** Someone registering as a DRep or creating a
   governance action sees the report while checking their document's url in the
   form.
2. **Publishers, after submitting.** A DRep or proposer whose document is
   anchored on chain but no longer shows. The report lives on the **details
   page** of the DRep or governance action.

## D118 — Where retry appears (closes OPEN-55)

**Said:** "retry will be for connected drep and gov-action details page."

- On the **DRep details page when the connected wallet is that DRep**, and on
  the **governance action details page**.
- Retry re-fetches past a cached failure (D86) and replaces the report with the
  new one.
- Who may retry on a governance action page is not stated. See OPEN-61.

## D119 — The metadata service is private; the backend exposes only what is needed (closes OPEN-56, amends D86)

**Said:** "metadata service has to be accessible via backend which guards to only
the required endpoints and not letting users know about the cache parameters."

- In a GovTool deployment the service is **not publicly reachable**. Only
  `govtool-backend` calls it.
- The backend exposes the minimum: resolve an anchor, read a fetch report,
  retry. Nothing else passes through.
- **Cache mechanics are not user-facing.** No `Cache-Control: invalidate`, no
  TTLs, no refresh semantics on the public surface. The user sees "retry" and a
  result.
- Consistent with D93: rate limiting of retry is the backend's. It amends D86,
  where the cache-buster was something "users may call": they now call the
  backend's retry, which calls it.

## D120 — One 2 MB fetch limit, set in code config (closes OPEN-57)

**Said:** "lets use 2mb for both, but configurable somewhere in a config.ts or
something like that not .env"

- 2 MB in the metadata service and in `govtool-backend`.
- A named constant in a `config.ts` in each, not an environment variable.
  Changing it is a code change, reviewed and versioned.
- `govtool-backend`'s current 1 MB cap, reported as `URL_NOT_FOUND`, is replaced.

## D121 — The error cache stays at one minute (closes OPEN-58)

**Said:** "Error cache should stay one minute."

The one-minute window governs **replay only**: how long a failure is returned
without a new fetch. A report must outlive it, because a publisher may look days
later (D117). See OPEN-59.

## F38 — What the SSRF guard is, and why D116 does not remove it

SSRF, server-side request forgery, is making a server fetch something on your
behalf that **you cannot reach but it can**. `curl` on a user's laptop reaches
the public internet. The metadata service's host also reaches its own private
network. Its database is at `172.31.0.5`. Cloud hosts also answer at
`169.254.169.254` with instance credentials.

An anchor url is attacker-chosen, and anyone can put one on chain or type one
into a form. With D114, a url like `http://169.254.169.254/...` would come back
as a full report **with the body**. Today's blind fetch would become a complete
read of internal services.

The guard refuses to connect when an address resolves to loopback, private,
link-local or other non-public ranges. **It does not hide anything.** Under D116
the report shows exactly what happened, for example "resolved to 10.0.0.5,
refused: private range". Transparency and the guard do not conflict: the guard
decides what the service will connect to, and the report tells the user what it
did.

## Open questions

- **OPEN-53** (restated) — Does the service refuse to connect to non-public
  addresses, and report the refusal in full?
  *Recommended:* yes. Without it, D114 lets anyone read internal responses
  through a report (F38).
- **OPEN-59** — How long are fetch reports kept?
  *Recommended:* keep the latest report per (url, hash) with no expiry,
  replaced on each new fetch. Storage is bounded by the number of distinct
  failing anchors, at most 2 MB each.
- **OPEN-60** — Is the category mapping in D115 right? The questions are
  whether `EXCEEDS_LIMIT` and `HASH_MISMATCH` are `INVALID_CONTENT`, and
  whether the third category is named `SCHEMA_INVALID`.
  *Recommended:* as tabled in D115.
- **OPEN-61** — On a governance action details page, who may retry: anyone, or
  only the connected wallet that submitted it?
  *Recommended:* anyone, rate-limited by the backend. A stale failure hurts
  every reader, and retry exposes nothing new.

## D122 — The service connects only to public addresses (closes OPEN-53)

**Date:** 2026-09-24
**Said:** "yes -> all non-public address including the block reserved for
internet provider level subnet like the one used by tailscale."

The guard is an **allowlist, not a denylist**: the service connects only to
globally routable public unicast addresses. Everything else is refused before a
connection opens, and the refusal is reported in full (D116, F38).

Refused ranges include, at minimum:

| Range | What it is |
|---|---|
| `0.0.0.0/8`, `::/128` | unspecified |
| `127.0.0.0/8`, `::1/128` | loopback |
| `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` | private networks |
| **`100.64.0.0/10`** | **shared address space, RFC 6598: carrier-grade NAT, and Tailscale's IPv4 addresses** |
| `169.254.0.0/16`, `fe80::/10` | link-local, including cloud instance metadata at `169.254.169.254` |
| **`fc00::/7`** | **unique local IPv6, including Tailscale's `fd7a:115c:a1e0::/48`** |
| `192.0.0.0/24`, `198.18.0.0/15` | protocol assignments, benchmarking |
| `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`, `2001:db8::/32` | documentation |
| `224.0.0.0/4`, `ff00::/8` | multicast |
| `240.0.0.0/4`, `255.255.255.255/32` | reserved, broadcast |
| `::ffff:0:0/96`, `64:ff9b::/96`, `2002::/16` | IPv6 forms embedding an IPv4 address; checked against the embedded IPv4 |

### What it means for implementation

- **Checked on the resolved address, not the hostname**, for every address DNS
  returns (F35).
- **The connection uses the address that was checked.** Resolving again at
  connect time would let a hostname answer "public" to the check and "private"
  to the connection (DNS rebinding).
- **Every redirect hop is checked again.** A public url that redirects to
  `http://10.0.0.5` is refused at that hop, and the report shows the chain.
- `govtool/metadata-validation`'s guard rejects any range that is not
  `unicast` in `ipaddr.js`. That already blocks `carrierGradeNat` and
  `uniqueLocal`, so it is the right shape to port. The table above is the
  normative list it must cover.

## D123 — Fetch reports are kept forever (closes OPEN-59)

**Said:** "well forever"

- **No report is ever deleted.** Each fetch adds a report; a retry adds history
  and replaces nothing. The latest report per (url, hash) is the default view,
  and older ones remain readable.
- **Bodies are stored by the hash of their bytes**, so a url that keeps serving
  the same broken response stores its body once however often it is retried.
  Growth is bounded by distinct bodies received, each at most the 2 MB limit
  (D120), not by the number of retries.
- The one-minute error cache (D121) still governs **replay only**.

## D124 — The failure categories are confirmed (closes OPEN-60)

**Said:** "yeh looks awesome."

D115's table stands: `NETWORK` is `FETCH_ERROR`; `INVALID_CONTENT` is
`EXCEEDS_LIMIT`, `JSON_PARSE_ERROR` and `HASH_MISMATCH`; `SCHEMA_INVALID` is
`SCHEMA_INVALID`.

## D125 — Anyone may retry, once a minute, with a countdown (closes OPEN-61)

**Said:** "yeh anyone with ratelimiting (like opts say you can retry again in 1
minute with timer if it fails and user re-clicks it."

- **Anyone viewing** the governance action details page may retry. So may the
  connected DRep on their own details page (D118).
- **The limit is per anchor, (url, hash), not per viewer**: at most one real
  fetch per minute, whoever clicks. Everyone sees the same result. The window
  matches the error cache (D121), so a retry inside it would only replay the
  cached failure anyway.
- **A click inside the window fetches nothing.** The backend answers with the
  seconds remaining, and the frontend shows "you can retry again in N seconds"
  with a live countdown, then re-enables the button.
- The seconds remaining is a rate-limit fact, not a cache parameter, so it is
  consistent with D119. The backend may add per-client limits on top (D93).

All metadata-visibility open questions (OPEN-50 to OPEN-61) are now closed.

# Implementation — 2026-09-24

## Landed: fetch reports, the address guard, retry (D113–D125)

**Contract** (`govtool-data-providers/src/metadata/index.ts`, SPEC.md §6):
`MetadataFailure` gains `category` and `reportId`; `METADATA_FAILURE_CATEGORY`
maps codes to categories; `MetadataReport` and its parts describe a report;
`refresh` returns a `MetadataRefreshOutcome`; `getReport` and `listReports` are
new. The fixture provider implements them offline.

**`drep-id/metadata`**:
- The address guard (D122) is an allowlist over every resolved address and every
  redirect hop. Each socket is pinned to the address that was checked.
  IPv4-mapped IPv6 is judged by its IPv4; NAT64 and 6to4 are refused outright,
  which is stricter than D122 requires.
- Every failure records a report: DNS answers or error, each address tried with
  outcome, error code, timeout stage and timings, redirects, response status
  and headers, and the body up to 2 MB. Bodies are stored once per distinct hash;
  a mismatch body is read from the content cache (D114, D123).
- Parse errors carry the parser's position; the `hashAlgorithm` schema issue
  carries the range of the offending value. Positions for CIP validation follow
  when `?cip=` lands; the locator is in place.
- `POST /api/metadata/{hash}/refresh` enforces one real fetch per (url, hash)
  per minute and returns `retryAfterSeconds` with a `Retry-After` header.
  `Cache-Control: invalidate` obeys the same window.
- Limits are constants in `src/config.ts` (D120).
- The old fetcher, which had no guard, is deleted, including an unused second
  fetch path that also had none.

**`govtool-metadata-http`** (new): the client implementing `MetadataServiceV1`
over the service's routes.

**`govtool-backend`**: the `METADATA` token from `VVA_METADATASERVICEURL`; the four
public routes of spec §2.8, answering 503 when unconfigured and a generic 502 on
a service fault; unknown query and body fields are rejected, so no cache
parameter can pass through (D119). The legacy validator's cap is 2 MB from
`src/metadata/config.ts`, and oversize reports `EXCEEDS_LIMIT` (D120).

### F39 — Two bugs the tests caught

- **A timed-out attempt was rewritten as a reset.** Destroying the request after
  a timeout raises `ECONNRESET`, and the error handler overwrote the settled
  attempt. The report would have told a publisher their server reset the
  connection when it had in fact stalled.
- **Relative redirects were never resolved.** The old fetcher passed the
  `Location` header through as-is, so `Location: /doc.json` failed. Each hop now
  resolves it against the current url.

### F40 — IPFS gateways are picked at random, with no fallback

Verified end to end against a mainnet anchor: the chosen gateway redirected to
another that answered `403`, and the report showed the whole chain. §1 of the
spec credited the service with "five gateways with fallback"; it has five
gateways and picks one. Trying the next gateway on failure is not yet decided.

---

# IPFS retrieval — 2026-09-24

## F41 — Four of the service's five IPFS gateways are dead

Interplanetary Shipyard retired the public gateways on **2026-09-21**, and stops
all IPFS operations on **2026-09-30**, including `delegated-ipfs.dev` and the
public bootstrap nodes. Their guidance for backend clients is to run a
dedicated node or gateway (Kubo, Rainbow, Someguy).

Probed live on 2026-09-24 with real mainnet anchor CIDs, each response checked
against the anchor's blake2b hash:

| Configured gateway | Answer |
|---|---|
| `ipfs.io` | `429`, `sunset` and `retry-after: 900` headers |
| `dweb.link` | `429`, same |
| `w3s.link` | `301` to `dweb.link` |
| `nftstorage.link` | `302` to `ipfs.io` |
| `gateway.pinata.cloud` | `200`, hash verified, about 6 s |

The service picks one of the five at random with no fallback (F40), so **about
four resolves in five fail today** for every IPFS-hosted document.

**Governance actions are hit hardest.** Of 158 mainnet governance action
anchors, 129 are `ipfs://` and 15 more are gateway urls. Of 511 DRep anchors, 2
are `ipfs://` and 136 are gateway urls, 110 of them one QuickNode gateway, which
served all six sampled.

A sample of 12 governance action CIDs across gateways that still work:

| Gateway | Verified | Median |
|---|---|---|
| `ipfs.blockfrost.dev` | 12/12 | 0.9 s |
| `c-ipfs-gw.nmkr.io` | 12/12 | 1.4 s |
| `ipfs.filebase.io` | 9/12, rest timed out | 1.0 s |
| `gateway.pinata.cloud` | 12/12 | 5.7 s |
| `ipfs.aleph.cloud` | 11/12 | 7.3 s |

Tried in order with failover, those five resolve all 12. None has published
terms for backend traffic that were checked; `ipfs.blockfrost.dev` answered
without a key.

**Three facts shape the fix.**

- **Any gateway is safe to use.** Every anchor is verified against its blake2b
  hash, so a gateway can fail or lie but cannot make the service accept wrong
  content. A wrong answer is a `HASH_MISMATCH`, and the next gateway can be
  tried.
- **A gateway matters only for the first fetch.** Content is cached permanently
  by hash (D84, D112), so once a document resolves, no later outage affects it.
- **Gateway urls on chain are frozen.** An anchor that names `ipfs.io` or a
  `*.ipfs.dweb.link` subdomain will name it forever. Today only `ipfs.io` path
  urls are rewritten; any other gateway url is fetched as written.

## Open questions

- **OPEN-62** — Replace the random pick with ordered failover: a primary, then
  secondaries in order?
  *Recommended:* yes. Move to the next gateway on anything short of a verified
  document: a network error, a timeout, any non-`200`, a hash mismatch, or a
  parse error, since a gateway can answer an error page with `200`. Use a short
  per-gateway timeout of about 15 s instead of today's 300 s.
- **OPEN-63** — Skip a gateway that says it is unavailable?
  *Recommended:* yes. After a `429` or `503`, skip that gateway for its
  `Retry-After`, or 15 minutes without one. A dead primary then costs nothing
  per request.
- **OPEN-64** — What is the default order?
  *Recommended:* `ipfs.blockfrost.dev`, `c-ipfs-gw.nmkr.io`, `ipfs.filebase.io`,
  `gateway.pinata.cloud`. Drop `ipfs.io`, `dweb.link`, `w3s.link` and
  `nftstorage.link`. Check each operator's terms before depending on it.
- **OPEN-65** — Where does the list live?
  *Recommended:* the defaults in `config.ts`, like the other limits (D120),
  plus one optional environment setting for an operator's own primary gateway.
  An operator gateway may need an access token, and a token is a secret.
- **OPEN-66** — Is every gateway url treated as IPFS?
  *Recommended:* yes. Take the CID from any `/ipfs/<cid>` path or
  `<cid>.ipfs.<host>` subdomain, try the anchor's own host first, then the
  list. The anchor's host may be the only one holding the pin, as with the
  QuickNode gateway.
- **OPEN-67** — How does a report show several gateways?
  *Recommended:* one entry per gateway tried, each with its own hops and
  outcome. That adds a field to `MetadataReport`.
- **OPEN-68** — Does GovTool run its own IPFS retrieval node?
  *Recommended:* yes, as the durable fix after failover lands: a Kubo or
  Rainbow node as the primary, with public gateways as secondaries. It needs
  its own peer routing, because the public bootstrap nodes and
  `delegated-ipfs.dev` stop on 2026-09-30.

## F42 — The CID decides who is wrong; a verified document ends the search (amends OPEN-62)

**Raised by the user:** a CID is itself a content hash, so if a gateway sends
the correct file there is no reason to fail over.

Correct, and it changes the failover rule in OPEN-62. Two hashes answer two
different questions:

| Check | Question | When it fails |
|---|---|---|
| **CID** | Did the gateway send the content at this CID? | the **gateway** is wrong: try the next one |
| **Anchor hash** | Is the content at this CID the anchored document? | the **publisher** is wrong: every gateway would send the same bytes, so stop with `HASH_MISMATCH` |

**The CID does not hash the file bytes; it hashes the IPFS block.** For a CIDv1
with the `raw` codec (`bafkre…`) the block is the file. For a `dag-pb` CID
(`Qm…`, `bafybe…`) the block wraps the bytes in a UnixFS envelope. So
verification uses the trustless response format:
`Accept: application/vnd.ipld.raw` returns the block, `sha256(block)` is
checked against the CID, and a `dag-pb` block is unwrapped to its bytes.

Probed on 2026-09-24 with the same 12 mainnet governance action CIDs: every
gateway tried serves raw blocks, and the blocks verify.

| Gateway | Block matches CID | Unwrapped bytes match anchor |
|---|---|---|
| `ipfs.blockfrost.dev` | 12/12 | 12/12 |
| `c-ipfs-gw.nmkr.io` | 12/12 | 12/12 |
| `ipfs.filebase.io` | 12/12 | 12/12 |
| `gateway.pinata.cloud` | 12/12 | 12/12 |
| `ipfs.aleph.cloud` | 12/12 | 12/12 |
| QuickNode gateway | 11/12, one error | 11/12 |
| `trustless-gateway.link` | 10/12, two errors | 10/12 |

Nine of the 12 were `raw`-codec CIDs; all 12 were single blocks.

### The amended rule

1. Ask the gateway for the raw block of the CID.
2. **The block does not verify, or the gateway fails** (timeout, non-`200`,
   format not supported): move to the next gateway.
3. **The block verifies:** the bytes are the CID's content, and the search is
   over. Check them against the anchor hash: a match is success, a mismatch is a
   final `HASH_MISMATCH`. Parse and schema errors are final too, since they
   describe the same bytes.

A gateway can then never cause a false `HASH_MISMATCH` or parse error, and a
`HASH_MISMATCH` on an IPFS anchor means exactly one thing: the file at this CID
is not the document that was anchored.

### Cases the sample did not cover

- **Multi-block files**, over the chunk size of usually 256 KiB, and **paths
  inside a directory CID** (`ipfs://<cid>/doc.json`) need the CAR format
  (`application/vnd.ipld.car`), where every block is verified the same way.
  Governance documents are small, so this is the rare case, but it must be
  handled rather than assumed away.
- **A gateway that cannot serve raw blocks** can still be used as a last resort
  with a plain request. Its bytes are then unverified against the CID, so an
  anchor mismatch from it is not final, and the next gateway is tried.
- CIDs using a hash other than sha2-256 are unverifiable here and fall back the
  same way.

## D126 — IPFS gateways are trusted; no CID verification (supersedes F42's rule, amends OPEN-62)

**Date:** 2026-09-24
**Said:** "Lets just forget this ipfs cid verification thingy, lets just assume
the gateways to be honest and move on."

- The service makes a plain request to a gateway and does not check the
  response against the CID. No raw blocks, no unwrapping, no CAR format.
- **A gateway that answers is taken at its word.** So F42's conclusion still
  holds without the check: once a gateway returns a document, the search is
  over. A mismatch with the anchor hash is a final `HASH_MISMATCH`, and parse
  and schema errors are final too.
- **Failover is only for gateway failures:** a network error, a timeout, or a
  non-`200` answer. This replaces the failover conditions recommended in
  OPEN-62, which also moved on on a hash mismatch or parse error.
- "Large files" and paths inside a directory CID need no special handling: a
  plain gateway request returns the whole file.
- The anchor hash is still checked, as for every document (D84). A dishonest
  gateway can cause a false `HASH_MISMATCH`, but it still cannot make the
  service accept wrong content.

Measured before the decision, for the record: of the 129 `ipfs://` governance
action anchors on mainnet, every document that came back was a single block,
at most 77 KB.

## D127 — An optional primary gateway; otherwise a random order (closes OPEN-62, OPEN-65)

**Date:** 2026-09-24
**Said:** "add a config variable optional primaryGateway if set then this is
fallover, if not set it is random ok one."

- **`IPFS_PRIMARY_GATEWAY`**, an optional environment setting. When set, the
  primary is tried first and the configured list follows in order. It is where
  GovTool's own node goes (D131).
- **When unset, the list is tried in a random order**, so load spreads across
  gateways.
- **Implementation reading, to confirm:** without a primary the service still
  fails over through the rest of the list in that random order. It does not
  stop after one random gateway, because a single random pick with no failover
  is what failed four times in five (F41).
- The list itself is code, in `config.ts` (D120). The primary is environment
  because it names a deployment's own gateway. `IPFS_GATEWAYS`, the old
  environment override, is removed; production never set it.

## D128 — A gateway that answers 429 or 503 is blacklisted for 3 minutes (closes OPEN-63)

**Said:** "yes for 3 mins blacklist it"

A fixed 3 minutes, whatever `Retry-After` says. Other failures, such as a
timeout, a 500 or a refused connection, move on without blacklisting. Blacklisted
gateways are skipped silently and named in the failure message. When every
gateway is blacklisted the fetch fails at once. The blacklist is in memory, per
process.

## D129 — The default gateway order (closes OPEN-64)

**Said:** "Ok keep your default order."

`ipfs.blockfrost.dev`, `c-ipfs-gw.nmkr.io`, `ipfs.filebase.io`,
`gateway.pinata.cloud`. The retired `ipfs.io`, `dweb.link`, `w3s.link` and
`nftstorage.link` are gone.

## D130 — Any IPFS url goes through our gateways (closes OPEN-66)

**Said:** "no if it is ipfs, extract cid and use our own ipfs fetch logic."

- `ipfs://<cid>`, `ipns://<name>`, `https://<any host>/ipfs/<cid>` and
  `https://<cid>.ipfs.<any host>` all yield the CID and any path. **The host an
  anchor names is never contacted.**
- `/ipfs/` counts only at the start of the path, and the id must be a valid CID,
  so an ordinary url that merely contains `/ipfs/` is fetched as written.
- This moves the 110 DRep anchors on one QuickNode gateway (F41) onto our
  gateways. A live sample of 6 resolved.

## D131 — GovTool runs its own IPFS node (closes OPEN-68)

**Said:** "yeh that is very advisable."

A Kubo or Rainbow node in the deployment, set as `IPFS_PRIMARY_GATEWAY`, with
the public list behind it. It needs its own peer routing, because the public
bootstrap nodes and `delegated-ipfs.dev` stop on 2026-09-30. Operations work,
not yet done.

## OPEN-67, restated — what "report" meant

The **fetch report** of D113: the page a failure links to, listing DNS answers,
each address tried, redirects, the response and the body. The question was how
that one page shows a fetch that tried several gateways.

*Implemented for now:* every gateway tried appears in the one report as
consecutive hops, in the order tried. A hop with no `redirectTo` followed by
another hop means the service moved on to the next gateway. No contract field
changed, and the frontend view already lists hops. Confirm, or ask for a
visible per-gateway grouping.

### Landed with D127–D130

`drep-id/metadata`: `src/helpers/ipfs.ts` parses every IPFS url form, orders and
blacklists gateways; `fetchAndRecord` fails over and records every hop. The
per-gateway idle timeout is 15 s, down from 300 s. 103 tests pass. Live on
2026-09-24 with no primary set: 8 of 8 `ipfs://` governance actions, 6 of 6
QuickNode DRep urls and 2 of 2 retired `ipfs.io` urls resolved.

---

# Release — 2026-09-24

## D132 — Tagged releases on GitHub-hosted runners: the image to GHCR, the rules to npm

**Date:** 2026-09-24
**Said:** "on push to tag we build on the github's own runner, and publish image
to ghcr. Then we push to @cardanoapi/governance-metadata project for using the
library for self verification. in the frontend exporting modules for validating
different cips"

- **The service image.** A `v*` tag on `drep-id/metadata` runs the test suite
  against a Postgres service container on a GitHub-hosted runner, then builds
  and pushes `ghcr.io/drep-id/metadata`, tagged with the version, `major.minor`
  and the commit. The existing deploy-on-`master` workflow is unchanged.
- **The shared validation package of D111 is `@cardanoapi/governance-metadata`.**
  Entry points per CIP: `/cip100`, `/cip108`, `/cip119`, plus `/hash` for the
  anchor hash, so the frontend verifies documents itself and imports only the
  standard it needs. Isomorphic, ESM and CommonJS.
- **Published from its own public repository, `cardanoapi/governance-metadata`,**
  with npm trusted publishing on a `v*` tag. Two npm constraints decide this:
  trusted publishing works only on GitHub-hosted runners, and provenance is
  generated only for public repositories. `drep-id/metadata` is private.
  *Implementation reading, to confirm:* a separate repo, rather than a folder in
  the service repo.
- A published package is also the only way the frontend can depend on shared
  code, since CI builds `govtool/frontend` on its own.

## F43 — The two existing validators disagreed on CIP-108 limits

`govtool/metadata-validation` allowed a title of 84 characters and an abstract
of 3000. `govtool-backend` allowed 80 and 2500. The CIP-108 text says "Limited
to 80 characters" and "Limited to 2500 characters". **The package follows the
CIP: 80 and 2500.** This is the silent divergence D111 predicted, found before
the package existed.

CIP-119 also sets limits: `givenName` 80, `objectives`, `motivations` and
`qualifications` 1000 each. Neither existing validator enforces them; the
frontend's registration form does, at authoring time. The package does not
enforce them yet, so no existing DRep document starts failing on upgrade.

## Open questions

- **OPEN-69** — Does the package enforce the CIP-119 length limits?
  *Recommended:* yes, in a later rules version, after checking how many mainnet
  DRep documents would start failing.

## D133 — The old providers are reference only; new ones are built on the current contract

**Date:** 2026-09-24
**Said:** "those providers are there for reference, move them to -archive postfix
folder and implement new ones based on the new provider. Lets start with the
dbsync based and complete it"

- `govtool-provider-dbsync`, `-koios` and `-blockfrost` are now
  `govtool-provider-dbsync-archive`, `-koios-archive` and
  `-blockfrost-archive`. They are not built, not depended on, and not
  maintained. They were written against an earlier contract and had 190, 219
  and 178 type errors against the current one.
- New providers are written against the current contract, db-sync first and to
  completion, with the archive as a source of queries and mappings.
- `govtool-backend` no longer depends on the three and its Dockerfile no longer
  builds them. The backend already refused them at startup.

## F44 — The backend typechecked only against stale provider builds

`govtool-backend` compiled and passed its tests locally because it resolved its
providers to their `dist` output from 2026-09-21, not their source. Built from
source in Docker, the image failed on the first provider. CLAUDE.md warned of
this trap; it was sprung anyway. **A package's checks prove nothing about its
dependencies unless those were rebuilt first.**

`govtool-pinning-pinata` had the same problem, and the backend does import it. It
is ported to the current `PinningServiceV1`: `pinData` keeps the legacy upload
request byte for byte; `getDataCid` computes the raw-block CID locally, checked
against five mainnet governance-action CIDs; `fetch` reads through Pinata's own
gateway; `unpin` refuses, since Pinata deletes by its file id, not by CID.

# db-sync provider — 2026-09-24

## F45 — The new db-sync provider is complete against the current contract

`govtool/govtool-provider-dbsync` implements `ChainDataApiV1` over db-sync 13.x.
Every required method, and every optional one db-sync can answer correctly. It
passes `npm run verify` with 114 unit tests, and live scripts per area run
against preview db-sync (tip epoch 1430).

Omitted, because db-sync cannot compute them correctly and the contract forbids
placeholders: `DRepsApi.listDelegators` (per-delegator active stake is not
stored), live voting power for DReps and pools, the network's live stake, the
DRep `activity` sort, and `Account.balance` (withdrawals are not split between
staking and non-staking rewards).

Declared: DRep sorts `votingPower`, `registrationDate`, `random`; filters
`status`, `kind`; search `exactId`. Proposal sorts `newest`, `oldest`,
`soonestToExpire`, `mostYesVotes`, `highestParticipation`; filters `type`,
`status`; vote aggregates `stake` and `count`; optional arguments
`protocolParams.epoch` and `proposals.voterContextOnList`.

**Cross-checked against Koios preview.** Protocol parameters, all fifteen
thresholds, treasury, stake totals, accounts, committee membership, quorum and
pools matched. Where they differ, db-sync followed the ledger and Koios did not:

- **Pools registered and retired in the same transaction** (29) are retired to
  the ledger; Koios lists them as registered.
- **A silent pool's default vote.** On a hard fork a non-voting pool counts as
  No; on a NoConfidence action a pool delegated to always-no-confidence counts
  as Yes. Koios counts both by delegation alone.
- **Pool eligibility at the tally epoch** follows the registration active at
  that epoch; Koios uses the pool's latest update.
- **Expired committee members** are outside the denominator; Koios counts them.

### F46 — Four bugs found only against the live database

- **Timestamps shifted by the host's time zone.** db-sync stores UTC in columns
  without a zone, and `pg` parses those as local time. Every timestamp was off
  by the host's offset until the pool parsed them as UTC.
- **Delegator counts.** "Delegation after the latest registration" is wrong
  before protocol 10, when a delegation could precede the registration in the
  same transaction. The rule is now the newest delegation with no DRep
  retirement or stake deregistration after it: 299 of the top 300 DReps match
  Koios, and the one that differs matches the ledger's own distribution.
- **Committee removals of the wrong credential type.** An enacted action on
  preview removed five members as key hashes while the members were scripts,
  so the ledger removed nothing. A key and a script with the same hash are
  different members.
- **Two slow query plans** walked the block table back from the tip and scanned
  every transaction; both were rewritten.

### F47 — The backend forwards legacy identifiers to a provider that rejects them

The frontend sends a raw hex DRep hash from the wallet and `txHash#index` for
proposals. The backend passed both straight to the provider. A conforming
provider rejects them, so the connected-DRep flow and proposal detail pages fail
on db-sync; on the fixture the proposal page answered 404. `hashRaw` on
`/drep/voting-power-list` also carried the CIP-129 id where the legacy API has
the hex hash. The legacy wire format belongs in the backend, so the backend is
being given the conversion.

### F48 — Fixture pool voting power may be one epoch off

The fixture stores Blockfrost's `active_stake` as a pool's voting power. db-sync
and Koios both put the governance snapshot one epoch later than active stake.
Worth checking in the fixture's capture mapping.

### Missing db-sync indexes at mainnet scale

db-sync 13.x has no index for several of these reads, all fast on preview:
`delegation_vote (addr_id)` and `(drep_hash_id, addr_id)`,
`voting_procedure (drep_voter)` and `(pool_voter)`,
`drep_registration (drep_hash_id)`, `pool_stat (epoch_no, pool_hash_id)`.

## Open questions

- **OPEN-70** — Status of a DRep with no delegators. db-sync stores the ledger's
  expiry only for DReps that hold stake, which leaves 5,961 of 8,984 registered
  preview DReps without one. Status is required and has no `unknown` value, so
  the provider currently infers it for these DReps alone from the last
  certificate or vote plus `drepActivity`, and omits `expiryEpoch`. That
  reconstructs activity, which Context.md forbids.
  *Options:* keep the narrow inference, add an `unknown` status to the
  contract, or read the expiry from another source.
- **OPEN-71** — Which expiry is the ledger's effective one? db-sync's stored
  expiry is 11 epochs lower than Koios for older DReps. Koios likely adds
  dormant epochs, the epochs with no live proposals that the ledger credits to
  every DRep later. If so, the stored value lags and could mark an active DRep
  inactive. Status agreed in every sampled case so far.
- **OPEN-72** — Is a DRep that lapsed but voted or re-registered during a tally
  epoch active for that tally? Koios says yes; the provider uses db-sync's
  stored expiry. Seven actions differ by 13 to 229 billion lovelace.
- **OPEN-73** — Four contract gaps the provider had to resolve on its own:
  `VoteRecord` has no field naming the action, so a pool's vote history cannot
  say what it voted on (served as an extra field for now); `count` aggregates
  cover the committee only; InfoAction's threshold is served as the unreachable
  1/1; a dissolved committee reports the dissolved committee's quorum with no
  members.
- **OPEN-74** — Should GovTool ship the missing indexes above as a script for
  db-sync operators?
  *Recommended:* yes, as an optional SQL file beside the provider, since db-sync
  tolerates extra indexes.

## F49 — The legacy identifier conversion landed, and two more stale-build traps

`govtool-backend/src/common/legacy-ids.ts` converts what the frontend sends
into the contract's forms before calling a provider, and renders legacy forms
on the way out: a raw hex DRep hash (key id first, script id on NOT_FOUND),
CIP-105, `txHash#index`, and 58-hex reward addresses. It fixed
`/proposal/get` on both providers, the connected-DRep routes and `/drep/list`
search on db-sync. 213 backend tests pass, and every identifier route answered
200 live on preview db-sync and on the fixture.

**The provider's public types leaked `@types/pg`.** `PgDbOptions` extended
`pg`'s `PoolConfig`, a dev dependency. The Docker build prunes dev dependencies
after each package, so the backend could not resolve the type there, while a
local build could. The provider now declares its own connection options. Same
rule as F44: a local build proves nothing about a pruned one.

**Left over:**
- `/proposal/get` always returns `vote: null`. The legacy API returned the
  DRep's own vote on the proposal, and the frontend reads it.
- The fixture lists the two predefined delegation targets as DReps with ids
  `drep_always_abstain` and `drep_always_no_confidence`, which are not CIP-129.
  The backend now drops those rows from `/drep/list`; the fixture is unchanged.
- The frontend's delegation model names its fields `dRepHash` and `dRepView`,
  while both backends send `drepHash` and `drepView`.
- On the fixture, `/ada-holder/get-voting-power` answers 0 even for an existing
  account, because the route returns 0 on any failure.

## D134 — Backend settings use a GOVTOOL_ prefix with words separated

**Date:** 2026-09-24
**Said:** "we need to migrate all that to GOVTOOL_ and why did you decide on
CHAINDATAPROVIDER INSTEAD OF CHAIN_DATA_PROVIDER?"

`govtool-backend`'s environment settings inherited `backend-ts`'s `VVA_` prefix
and its squashed names, which came from upper-casing config keys
(`dbSyncConfig.host` → `VVA_DBSYNCCONFIG_HOST`). New settings had copied the
pattern. All are renamed, with no fallback to the old names, since the backend
is not deployed anywhere:

`GOVTOOL_HOST`, `GOVTOOL_PORT`, `GOVTOOL_CHAIN_DATA_PROVIDER`,
`GOVTOOL_DBSYNC_HOST`, `_PORT`, `_DATABASE`, `_USER`, `_PASSWORD`, `_NETWORK`,
`GOVTOOL_KOIOS_NETWORK`, `_TOKEN`, `_BASE_URL`, `GOVTOOL_BLOCKFROST_BASE_URL`,
`_PROJECT_ID`, `GOVTOOL_PINATA_API_JWT`, `GOVTOOL_METADATA_SERVICE_URL`,
`GOVTOOL_CACHE_DURATION_SECONDS`, `GOVTOOL_DREP_LIST_CACHE_DURATION_SECONDS`,
`GOVTOOL_CACHE_MAX_ENTRIES`, `GOVTOOL_SENTRY_DSN`, `GOVTOOL_SENTRY_ENV`.

The Haskell backend's `VVA_NETWORK` is untouched. The metadata service keeps
`DATABASE_URL`, `PORT` and `IPFS_PRIMARY_GATEWAY`, which drep.id's deployment
shares. Earlier entries in this file keep the old names as written at the time.

## F50 — The integration suite against the new backends

`tests/govtool-backend` against `govtool-backend` on db-sync preview: 10
failures became 6 after four backend fixes (bare stake key hashes accepted,
`/epoch/params` back in the legacy snake_case shape, proposal dates derived from
the epoch when a provider gives only the epoch, enacted-details audited). None
of the remaining six is fixable in the backend without inventing data: two are
a suite bug (`dRepId` built, `drepId` read), one needs a Kuber API key, and
three assert db-sync row ids that D1 removed from the contract.

## D135 — The old providers live in govtool/_legacy; Blockfrost targets the hosted API

**Date:** 2026-09-24
**Said:** "move the old ones to _legacy (they are very useful for research). And
implement new one to support our provider structure. based on spec."

- `govtool-provider-{dbsync,koios,blockfrost}-archive` moved to
  `govtool/_legacy/govtool-provider-{dbsync,koios,blockfrost}`. Still not built
  and not depended on.
- New `govtool-provider-koios` and `govtool-provider-blockfrost` are built on
  the current contract, mirroring `govtool-provider-dbsync`.
- Blockfrost is built and live-verified against hosted Blockfrost 6.8.0, not
  blockfrost-ryo 3.1.1. Hosted serves `/governance/committee`, `/network`,
  `/txs`, DRep votes with their proposal id and a hydrated DRep directory, so
  the committee, treasury, transaction status and DRep voting record are no
  longer gaps. No constitution endpoint: it is derived from
  `getEnacted('constitution')`.
- Blockfrost vote aggregates are served for live proposals only: stake for
  DReps and pools, count for the committee. A concluded action's tally cannot
  be rebuilt at its tally epoch, so it has none, rather than numbers that
  drift.
- Blockfrost's cost is per backend snapshot, not per user. A full proposal
  snapshot is about 210 requests (1 detail read per proposal, plus about 50 for
  tallies). The backend refresh interval decides whether it fits a plan: about
  900k requests a day at 20 s, about 30k a day at 10 min.

## D136 — ProtocolParams carries every protocol parameter; genesis parameters are optional (closes OPEN-75)

**Date:** 2026-09-25
**Said:** "we need to add it to decisions and spec, it was missed. we want the
protocol params and genesis-params (optionally) in the spec."

- `ProtocolParams` now carries every protocol parameter the current ledger
  era holds, all required. That adds block and header size, execution limits,
  collateral, execution prices, cost models, the reference-script fee, and the
  pool and monetary parameters (`eMax`, `nOpt`, `a0`, `rho`, `tau`,
  `minPoolCost`). Rationals are `Ratio`s, and cost models are one integer array
  per Plutus language.
- **Why required:** the subset broke real flows. The frontend wallet reads
  `cost_model.costs` from `/epoch/params` to compute the script data hash, so
  without cost models every Plutus-script transaction is rejected on chain.
  That includes proposing a treasury withdrawal or a parameter change (the
  guardrails script). A parameter-change screen also shows the current value
  of whichever parameter an action changes. db-sync, Koios and Blockfrost all
  expose the full set, so requiring it costs no provider anything.
- **Not carried:** source bookkeeping (`id`, `block_id`, `cost_model_id`, the
  epoch `nonce`), and parameters the ledger no longer has (`decentralisation`,
  `extra_entropy`, `min_utxo_value`). The legacy `/epoch/params` keeps those
  keys, as null.
- **New, optional:** `network.getGenesisParams()`, the Shelley genesis
  constants (network magic, system start, epoch and slot length, active slot
  coefficient, security parameter, KES, update quorum, max supply). Koios and
  Blockfrost serve it; db-sync does not store the genesis file, so it omits the
  method.
- Found by `tests/govtool-backend::test_get_epoch_param` on db-sync preview,
  where `/epoch/params` sent 25 fields as null.
- **Closes OPEN-77 too.** The frontend reads a proposal's `protocolParams` in
  snake_case, as db-sync's `param_proposal` row. It diffs it key by key
  against `/epoch/params`, and it tests `!== null`, so an absent key reads as
  a change: every parameter change was being flagged security-relevant. The
  backend now maps the contract's `changes` back to that row, with every column
  present and null where unchanged, through the same column mapper as
  `/epoch/params`. `epoch_no` is null there, because it is not a parameter and
  the diff view does not filter it out. Checked against the Haskell backend on
  preview: identical keys and values on every live parameter change.

## Open questions

- **OPEN-75** — *Closed by D136.* Protocol parameters the contract does not carry. `ProtocolParams`
  has no cost models, and the frontend reads `cost_model.costs` from
  `/epoch/params` to compute the script data hash, so script-based transactions
  break without them. Ten more real parameters are outside the subset: block and
  transaction size and execution limits, collateral, `decentralisation`,
  `influence`, `max_epoch`, `max_bh_size`.
  *Recommended:* add cost models, since a displayed or submitted computation
  needs them; add the others only if something reads them.
- **OPEN-76** — What epoch does `lifecycle.expires` name? The fixture gives
  submission epoch + `govActionLifetime`; db-sync gives one more, which is what
  the legacy API and the suite expect. SPEC.md does not say.
  *Recommended:* the last epoch in which the action can still be voted on, and
  fix whichever provider disagrees.
- **OPEN-77** — *Closed 2026-09-25, see D136.* Parameter-change bodies reach the frontend in the contract's
  camelCase, while its threshold lookup expects the legacy snake_case keys.
  *Recommended:* the backend maps them back in the legacy route, like
  `/epoch/params`.

## D137 — Local tests may switch off the private-address guard (amends D122)

**Date:** 2026-09-25
**Said:** "that would make our test local, for metadata service or component i
want to have that private ipblocking thing off during test. So that I can run
the test in peace"

- Both guards get an opt-in switch, off unless set to exactly `true`:
  `METADATA_ALLOW_PRIVATE_ADDRESSES` in govtool-metadata-service
  (`src/helpers/addressGuard.ts`) and `GOVTOOL_METADATA_ALLOW_PRIVATE_URLS` in
  govtool-backend (`config.service.ts`, passed to `fetchMetadataText`). With it
  on, loopback, private and other non-public addresses are connectable.
  Protocol and URL-credential checks still apply in the backend.
- Either service logs a warning at startup when the switch is on.
- **Amends D122**, which kept the only escape hatch in code so that no
  deployment could set it. That still holds for every deployment: the switch is
  for local end-to-end runs, where the test metadata bucket
  (`tests/test-metadata-api`) lives on loopback. Never set it in a deployment.
- **Why:** the Playwright suite uploads DRep and vote metadata to a bucket and
  registers the URL. Against the shared bucket the run depended on
  `metadata-govtool.cardanoapi.io`, which split-horizon DNS on the office
  network resolves to a private address, so every registration failed with
  URL_BLOCKED. A local bucket needs loopback, which the guard refuses by design.

## F51 — Five legacy-shape regressions the Playwright suite found, and their fixes

The frontend suite against govtool-backend on db-sync preview (2026-09-25) found
five places where `govtool-backend` differed from the Haskell backend. Each was
diffed against preview.gov.tools/api and now matches it:

- `/proposal/list` and `/drep/getVotes` ignored the bracketed `type[]` the
  frontend sends (axios percent-encodes it); the controllers read it again, as
  backend-ts did.
- `/proposal/list` returned every action; it now lists `live` ones only, as the
  legacy list did. The snapshot still holds every action, because vote history
  needs the ended ones; the status travels beside each legacy row.
- `/ada-holder/get-current-delegation` sent `drepHash`/`drepView`; the legacy
  keys are `dRepHash`/`dRepView` (inherited from backend-ts).
- `/drep/info` reported every registration as a DRep. The legacy split is back:
  an anchor makes a DRep, no anchor makes a direct ("sole") voter. The "was"
  flags read the latest registration certificate, the only one the contract
  keeps, so a credential's earlier registrations are not seen.
- `/transaction/status` sends an empty `votingProcedure`, and the frontend waited
  on it to confirm a vote. **Not reopened in the contract**: D49 keeps votes
  unaddressable by transaction and D65 dropped `votingProcedures`. The frontend
  instead treats a confirmed vote transaction as confirmed, which is equivalent
  (a transaction on chain has cast its votes) and unchanged against Haskell. The
  same change keeps polling until the expected state appears or the 3-minute
  expiry fires; before, polling stopped at confirmation and "in progress" could
  stay up for good.

## D138 — Rebuild the proposal discussion forum (PDF) backend in NestJS

**Date:** 2026-09-26
**Said:** "I need you to autonomously build it from scratch using a typescript
nest.js backend. Use libcardano for the crypto. Use prisma for
database access/modification, use postgres for storage." Then: update the
frontend to use it, remove the `@intersect.mbo/pdf-ui` package and make it
local in the frontend.

- New package `govtool/govtool-pdf-backend` (NestJS 11, Prisma 6, Postgres 16),
  replacing the Strapi backend of IntersectMBO/govtool-proposal-pillar. Its
  `docker-compose.yml` runs Postgres and the backend with
  `docker compose up -d`; migrations apply on start.
- The wire surface is the Strapi **v4** REST envelope and query syntax, limited
  to what pdf-ui sends. Strapi's package.json says 5.47, but the controllers
  and pdf-ui are v4-shaped and pdf-ui never sends `Strapi-Response-Format: v4`,
  so v4 is what the frontend actually needs. No Strapi admin panel, GraphQL, or
  generic content-type API.
- Where the Strapi code is unsafe, the rebuild deliberately differs, and the
  spec lists each difference: the proxy is not an open relay, login checks
  that the signed payload is the issued challenge and consumes it, ownership
  is enforced on every write, counters and owner fields are server-set, and
  user private fields are never returned.
- Crypto (CIP-8/CIP-30 `signData` verification, key-hash and address checks)
  goes through `libcardano`.
- The spec is `govtool/govtool-pdf-backend/SPEC.md`; the investigation it rests
  on is summarised there, not copied.

## D139 — pdf-ui source lives in the frontend

**Date:** 2026-09-26
**Said:** "remove the old-pdf-ui package and make it locally in the frontend."

- `govtool/frontend/src/pdf-ui/` holds the 1.0.18-beta source as plain JS/JSX
  (not converted to TS); `ProposalDiscussion.tsx` lazy-loads `@/pdf-ui/App`,
  typed by `src/pdf-ui/App.d.ts`. The `@intersect.mbo/pdf-ui` dependency, its
  type shim and the `pdfUiFonts` Vite plugin are gone.
- The vendored code runs on the frontend's own versions (date-fns 2,
  react-markdown 9, cardano-serialization-lib 14); nothing it used changed
  between those majors.
- `src/pdf-ui` is outside lint (`--ext ts,tsx`) and type checking (`checkJs`
  off). Converting it is separate work.

## D140 — PDF backend spec choices not forced by the Strapi source

**Date:** 2026-09-26
**Context:** writing `govtool/govtool-pdf-backend/SPEC.md` (D138). These were
judgement calls; the spec's §13 deviation index (Δ1–Δ45) lists every place the
rebuild differs from Strapi.

- Login binds the key hash and the signed payload (it must equal the issued
  challenge, which is consumed on the first attempt). It does not bind the
  COSE `address` header: the Playwright wallet (`SimpleCip30Wallet`) puts the
  base address there when asked to sign with a reward address.
- Stake or DRep login is chosen by identifier form (58-hex e0/e1 reward
  address vs 56-hex DRep hash). Access JWT 1h, refresh 7d in an httpOnly
  cookie holding a JWT with its own secret, SameSite=Lax by default.
- A bad token on a public route reads as anonymous; missing auth 403, bad
  token 401, foreign row 403.
- Users are exposed to others only as `{id, govtool_username}`; report hashes,
  e-mail and contact information never leave the server. Unknown query keys,
  paths and populates are a 400, except no-op paths pdf-ui sends.
- Seeds come from the Playwright enums in enum order; hard fork is id 6,
  id 5 unseeded. One like/dislike per user, one budget-poll vote per DRep;
  polls close but never reopen.
- Budget discussion delete removes the whole version chain; submitted ones
  are locked. `POST /api/proxy` needs login, GET only, 10 s, 5 MiB, public
  addresses unless `PDF_ALLOW_PRIVATE_URLS=true`.
- Dropped: e-mail, the report endpoint, `old_ver`, the protocol-version filter
  on action types.
- e2e runs on a `pdf_test` database and refuses any database not ending in
  `_test`; `npm run seed:demo` provides the existing rows Playwright expects.

## F52 — Playwright pdf run against govtool-pdf-backend: no backend defects, ten elsewhere

**Date:** 2026-09-26
**Context:** first run of the pdf specs (7, 8, 11, 12, 6I–6L) against the
rebuilt backend (D138) and the vendored pdf-ui (D139), preview network,
HD wallets pinned with `HD_RUN_ID`. Failed tests were re-run once serially;
passing tests were not re-run. Every backend response in the failing traces
was correct. Defects, by owner:

- **D1, test suite.** Fresh HD wallets have no pdf username, so pdf-ui's
  username modal blocks the fixtures and most logged-in specs; the setup
  projects that set usernames went in 438a62e3. For the run, users with
  `govtool_username` were pre-inserted for the pinned wallets (environment,
  not code or tests).
- **D2, pdf-ui / wallet context.** Sign-in reads `wallet.stakeKey` after
  checking only `address` (`pdf-ui/lib/helpers.js:93`,
  `UserValidation.jsx:68`); GovTool sets the address first
  (`context/wallet.tsx:424` vs `:472`), so pdf-ui sends
  `challenge?identifier=undefined` (400) and never signs in. Worse under
  parallel workers; the HD wallet's Blockfrost-backed stake-key calls widen
  the gap. 9 tests.
- **D3, test vs pdf-ui.** 7E_1–4 expect `add-link-button` hidden after 7
  links; pdf-ui always renders it (unchanged upstream).
- **D4, test vs pdf-ui.** 7M_2 expects `amount-0-content` "929"; the UI
  shows "₳ 929".
- **D5, environment.** pdf-ui's `URL_REGEX` (`lib/utils.js:7`) rejects URLs
  with a port, so the local bucket `http://127.0.0.1:3001/...` is an invalid
  constitution URL. 4 tests.
- **D6, pdf-ui.** On reload, the stale-session check compares
  `jwt.stakeKey` with a not-yet-set `wallet.stakeKey` and clears the session
  (`helpers.js:28-34`). 12H, 12J.
- **D7, test suite.** The page wallet proxy (`lib/wallet/pageWallet.ts`) has
  no CIP-30 `getBalance`; pdf-ui then reads the balance as 0. 7O passes only
  because of this.
- **D8, pdf-ui.** GA submission is gated on a hard-coded 100000.18 ADA
  (`SingleGovernanceAction/index.jsx:650`, `:1179`) instead of
  `epochParams.gov_action_deposit` (1000 ADA on preview); the .ga tests fund
  deposit + 22 ADA, so all of 7H/7J/7K/7P stay blocked after D7.
- **D9, pdf-ui.** Wallet info is copied once at sign-in; a slow
  `/drep/info` arrives after it, so `verify-drep-link` never appears (11K).
- **D10, test suite.** 7J_1's afterEach throws `undefined.goto` when its
  beforeEach failed.

Results: anonymous desktop smoke 21/21; pdf projects 53 of 79 passed (40 in
parallel, 13 more serially), 26 failing on D2–D10; 6I–6L 4/4; mobile pdf specs
24/25 (6M footer links, unrelated to pdf).

## D141 — IPFS for isolated test environments goes to the test metadata service

**Date:** 2026-09-27

- `govtool-pinning-test` (`@govtool/pinning-test`) implements `PinningServiceV1`
  over `tests/test-metadata-api`, selected by `GOVTOOL_PINNING_PROVIDER=test`
  with `GOVTOOL_TEST_PINNING_URL`. Default stays `pinata`; an unknown name or a
  non-http(s) url is refused at startup.
- CIDs are CIDv1, raw codec, sha2-256, base32 (`bafkrei…`): what Pinata's v3
  upload returns for single-block content and what `govtool-pinning-pinata`
  already computes in `getDataCid`. Computed with node:crypto, no dependency;
  the client checks the service's answer against its own. Above one 256 KiB
  block a real node would assign a dag-pb root; the test service keeps the raw
  CID up to its 512 KiB cap, which nothing in GovTool can observe.
- `tests/test-metadata-api` serves `POST|PUT /ipfs`, `GET|DELETE /ipfs/<cid>`
  and `GET /ipfs` (health). `GET` accepts only `bafkrei` CIDs so a request can
  never name a path outside the store. It is the gateway for every reader:
  frontend `VITE_IPFS_GATEWAY=<url>/ipfs`, metadata service
  `IPFS_PRIMARY_GATEWAY=<url>` plus the new `IPFS_GATEWAYS=<url>` (replaces the
  public list) and `METADATA_ALLOW_PRIVATE_ADDRESSES=true`, metadata-validation
  `IPFS_GATEWAY=<url>/ipfs`, db-sync `"ipfs_gateway": ["<url>/ipfs"]` in its
  config file (13.7.2.1; default `https://ipfs.io/ipfs`).
- The frontend's three hard-coded `https://ipfs.io/ipfs` uses now read
  `VITE_IPFS_GATEWAY` with that as the fallback. A CIP-179 `ipfs://` anchor may
  now be fetched over http when the configured gateway is http; any other
  anchor must still be https.

## D142 — A custom devnet is a db-sync network, dated from its genesis file

**Date:** 2026-09-27

- `GOVTOOL_DBSYNC_NETWORK` (and `GOVTOOL_BLOCKFROST_NETWORK`) accept `devnet`:
  any local testnet, network id 0, `stake_test` prefixes. The contract's
  `NetworkId` already allowed a custom name, and both providers treat every
  name but `mainnet` as a testnet, so nothing else switches on the name.
- db-sync's `meta.network_name` comes from db-sync's own `NetworkName`, which
  a devnet harness chooses. For a non-public network the db-sync provider
  accepts any name except `mainnet`, `preprod` and `preview` (so a devnet
  backend pointed at a public database still refuses);
  `GOVTOOL_DBSYNC_NETWORK_NAME` (provider option `dbNetworkName`) pins it.
- The epoch schedule is not hard-coded and not configured as numbers: a devnet
  regenerates its genesis every run and slots can be 0.2 s. The db-sync
  provider gains `network.getGenesisParams()`, present only when given
  `shelleyGenesisPath` (`GOVTOOL_DBSYNC_SHELLEY_GENESIS_PATH`), the Shelley
  genesis db-sync itself was started with. It is read on each call and
  refused (`INTERNAL`) when its `systemStart` is not `meta.start_time`, which
  is how a file left over from an earlier run shows. Deriving the schedule from
  db-sync alone was rejected: `meta.start_time` gives the start, but the slot
  and epoch lengths would have to be inferred from block times.
- The backend keeps the three public schedules as constants (mainnet began in
  Byron, so its Shelley genesis alone would misdate it) and asks
  `getGenesisParams` for any other network, in milliseconds, rounded
  (300 × 0.2 s is 60.00000000000001 s in a double). A failed read leaves
  epoch-only stamps undated (`expiryDate: null`) rather than failing the
  route. Any provider with genesis parameters (Koios, Blockfrost) gets the
  same behaviour on a custom network.

## D143 — The outcomes UI is served by govtool-backend, through the contract

**Date:** 2026-09-27

- `@intersect.mbo/govtool-outcomes-pillar-ui` calls seven routes on
  `VITE_OUTCOMES_API_URL`: `GET /governance-actions` (`search`, `filters`,
  `sort`, `page`, `limit`), `GET /governance-actions/:txHash?index=`,
  `GET /governance-actions/metadata?url=&hash=`,
  `GET /governance-actions/proposal/:txHash`, `GET /misc/network/metrics?epoch=`,
  `GET /misc/epoch/params?epoch=` and `POST /misc/verify-signature`.
  Neither `backend` nor `backend-ts` on develop serves them; an unmerged
  branch (`cardanoapi/outcomes-merge`, 2026-09-25) adds them to `backend-ts`
  over new SQL under `/outcomes`. govtool-backend serves them under the same
  `/outcomes` prefix, so `VITE_OUTCOMES_API_URL=<backend>/outcomes`, built from
  the contract instead of SQL.
- Contract additions, all optional: `getStakeDistribution({ epoch })` and
  `getCommittee({ epoch })`, declared `stakeDistribution.epoch` and
  `committee.epoch`, and `StakeDistribution.spoAlwaysAbstainVotingPower` /
  `spoAlwaysNoConfidenceVotingPower` (pool voting power whose reward account
  delegates to a predefined DRep: the protocol-10 default SPO vote). The
  db-sync provider implements all four; fixture, Koios and Blockfrost do not
  yet, so on them `/outcomes/misc/network/metrics` is a 501 (they lack the SPO
  fields, and the fixture the DRep breakdown too) and a past epoch is a 501
  rather than current figures.
- Rows come from the proposal snapshot the `/proposal` routes already keep.
  Deliberate differences from the branch: `id` is the CIP-129 action id (no
  provider has db-sync row ids); list `yes_votes`/`no_votes`/`abstain_votes`
  are the DRep tally (stake, or count where the provider only counts) rather
  than a count of vote rows of every role, which nothing renders and only the
  `highestYesVotes` sort read; `description` uses one shape in list and detail
  (the branch's list had a null committee threshold and bare hash strings);
  a ParameterChange `description.data` carries contract parameter names (the
  UI renders `proposal_params`); dates are `toISOString()` UTC, and
  `status_times` are epoch starts from the schedule (D142), not db-sync's
  first-block times; the active-DRep total excludes inactive DReps, as the
  ledger's denominator does; `/misc/epoch/params` answers the flat
  `epoch_param` row the UI reads (the branch wrapped it in `{ epoch_param }`,
  which the UI cannot read).
- Title, abstract, motivation, rationale and `json_metadata` are resolved
  through the metadata service when `GOVTOOL_METADATA_SERVICE_URL` is set, and
  null otherwise; the UI then calls `…/metadata`, which is the backend's
  existing CIP-108 validation.
- `…/proposal/:txHash` asks `GOVTOOL_PDF_API_URL` (the pdf API, e.g.
  `http://pdf-backend:1337/api`) for
  `filters[prop_submission_tx_hash][$eq]`, and answers `{ data: item | null }`;
  503 unset. The branch fetched `/proposals/<txHash>`, an id route. The hash
  is validated as 64-hex before the request; no redirects, 10 s, 1 MB.
- `verify-signature` fetches through the backend's guarded metadata fetch (the
  branch used a bare `fetch` of a caller-supplied URL), canonicalises with
  `jsonld` URDNA2015 under a document loader that refuses every remote
  context, and verifies `ed25519` and `CIP-0008` witnesses with node:crypto
  and a minimal CBOR codec, so the backend takes one new dependency (`jsonld`)
  rather than the branch's four.

## D144 — pdf-ui reads GovTool state and uses GovTool's design system

**Date:** 2026-09-28
**Said:** "fix that on the frontend, and to make the design style same with govtool. with a proper plan and
investigation and then implementation"

- The plan is `docs/pdf-ui/plan.md`; the investigations behind it are beside it.
- State: the host passes `walletStatus` (`disconnected | connecting | ready`); pdf-ui derives wallet, user, DRep and
  epoch state live from props instead of copying them, with one session-sync effect and one refresh loop. Fixes D2,
  D6, D9.
- Design: pdf-ui drops its own theme for GovTool's (via a temporary compatibility layer), GovTool tokens,
  breakpoints, icons and atoms/molecules; screens are laid out on their closest GovTool counterparts.
- Kept: every testid, every asserted string, the API calls, the session format and the routes. TypeScript
  conversion and i18n are follow-ups.

## F53 — pdf-ui alignment: 76/79 pdf tests, D2/D6/D9 fixed, three known failures left

**Date:** 2026-09-28
**Context:** D144 implemented as `docs/pdf-ui/plan.md` P1–P6; one full pdf run on a build of the final tree.

- pdf projects 76/79 (from 53), 6I–6L + 6P 5/5, mobile pdf 21/21. The acceptance list for the state fix
  (7D_3, 7I_1, 7I_4, 7M_1, 8G, 12D_3, 12F_5, 12H, 12J, 11K) is green.
- Left: 7H_3 (D13, local constitution URL unreachable from the pdf backend container), 7H_4 (D11, #3917),
  7P (D14). The last two also fail in CI #491.
- pdf-ui keeps a thin theme over GovTool's (`ThemeProviderWrapper/theme.js`): only MuiCard and a scoped
  MuiTextField pill for the MUI Cards and the selects/getByLabel fields that stay MUI. The plan's "delete the
  wrapper" step became this, because those components remain.
- GovTool shared code touched: TextArea/Input atoms and Field.TextArea/Input forward `onBlur`, Field.TextArea
  gains `errorDataTestId`; vitest forks capped at 2 locally, 4 in CI (`vite.config.ts`).
- Report: `tests/govtool-frontend/playwright/reports/pdf-ui-alignment-2026-09-28.md`.

## D145 — Outcomes signature checks match the outcomes service; remote `@context` resolved through the guarded fetch

**Date:** 2026-09-28
**Said:** "We need to support the @context with url … for now we let support @context like outcomes";
"signature verification -> lets make it as strict as it does in the outcomes"; "keep our hash check".
**Amends:** D143 (verify-signature refused every remote context).

- Compared against `IntersectMBO/govtool-outcomes-pillar` main `6a267ba`. cardanoapi's `outcomes-merge`
  branch is the same SQL, copied into backend-ts.
- `POST /outcomes/misc/verify-signature` resolves a remote JSON-LD `@context` as the outcomes service did.
  It is fetched through the backend's guarded metadata fetch (SSRF guard, size and time limits, ipfs:// via the
  gateway), at most 8 per document, and cached by url. The long-term policy is #4255 (sub-issue of #4225):
  where it lives, allowlist or guarded fetch, limits, cache TTL, and pinning a context against later change.
- CIP-0008 checks are the outcomes service's: the COSE_Key must be an OKP / EdDSA / Ed25519 map
  (a raw 32-byte vkey is still accepted), and the protected header must carry alg -8 and `address`.
  The unprotected header must be a map.
- `GET /outcomes/governance-actions/metadata` returns the document's `authors` in `data`, as the outcomes
  service did; the UI falls back to it when `json_metadata` is null, which it is with no metadata service
  configured. The legacy `/metadata/validate` route is unchanged.
- Kept as is: raw-byte hash checking (the outcomes service also accepted re-serialised and canonical-form
  hashes), and CIP-108 as the only standard on this route (outcomes are governance actions; the outcomes
  service's CIP-119 detection came from shared DRep validation code).
- Undecided: the DRep stake denominator (ours counts active DReps only; the outcomes service counted every
  DRep's latest stake) and the committee member count.

## D146 — Outcomes `prev_gov_action_index` is a decimal string

**Date:** 2026-09-28
**Amends:** D143.

- `GET /outcomes/governance-actions/:txHash` answers `prev_gov_action_index` as a string (`"0"`), or null,
  as the outcomes service did. The UI links the previous action only when the field is truthy, so the
  number 0 hid the link for every action whose previous action was at index 0.
- No other outcomes number is truthiness-tested where 0 can occur: the status epochs and committee term
  epochs it tests are never 0 on a Conway network, and `index` goes through `toString(16)` first.
- Search and list rows read titles and abstracts from a per-(hash, url) cache in the backend (resolved
  24 h, unresolved 5 min, 4096 entries), warmed after each snapshot refresh; results are unchanged.

## D147 — `enacted-details` answers every lineage; pdf-ui names the previous action

**Date:** 2026-09-29

- `GET /proposal/enacted-details?type=` resolves `NewConstitution` to the constitution lineage and
  `NoConfidence` and `NewCommittee` to the committee lineage, as it already did `ParameterChange` and
  `HardForkInitiation`. The Haskell backend answered the hard-fork lineage for any other type, which is
  the wrong previous action for every one of them; its only caller asked for `HardForkInitiation`.
  `TreasuryWithdrawals`, `InfoAction`, a missing type and any unknown value keep the hard-fork answer,
  so those responses are unchanged. Only the table's own keys count: `type` is an unvalidated query value.
- GovTool passes pdf-ui a `getEnactedProposalDetails(type)` prop on its own API client (D144's host-owned
  pattern), rather than pdf-ui calling through the pdf backend's `/api/proxy`. pdf-ui calls it when it
  submits an Updates to the Constitution or a Motion of No Confidence and names the result as the
  previous action; null means none is named. The index travels as a string, because the wallet builders
  skip a falsy index.
- The wallet's no-confidence builder takes the previous action (`NoConfidenceAction.new_with_action_id`);
  it built without one, which the ledger rejects once any committee action is enacted.
- pdf-ui converts withdrawal amounts to lovelace on the digits (`adaToLovelace`): `prop_amount * 1e6`
  gave fractional strings for about 2% of two-decimal amounts (1.005 → 1004999.9999999999), which the
  serialisation library refuses. Its submit `catch` no longer throws on an `Error` (#3949).

## D148 — A decision never references another file

**Date:** 2026-09-29
**Said:** "decisions file should never reference another file"

- Every entry stands on its own: it states the fact, number, reason and outcome itself. It never points to a
  plan, report, audit, spec section, other document or source path in place of saying it; those move or are
  deleted, and this file is append-only, so a pointer rots while the entry cannot be fixed.
- Earlier entries that point elsewhere are read on their own text; the pointer carries nothing. Three targets
  are already gone: the pdf-ui plan and investigations (D144, F53), the 2026-09-28 pdf-ui alignment report
  (F53) and the 2026-09-23 external audit (the audit response). What they decided or measured is in those
  entries' bullets.

## D149 — The outcomes UI lives in the frontend, on GovTool's components

**Date:** 2026-09-29
**Said:** "merge into the repository … frontend … we dont have to make new folder for it simply merge in the
existing frontend code"; where a component exists in both, "Reuse govtool's".
**Amends:** D143 (the UI was the `@intersect.mbo/govtool-outcomes-pillar-ui` package).

- Source: the outcomes pillar's UI at `919164c`: v1.5.11, the version the frontend pinned, plus two later
  fixes (terminal-status dates by status, #4150, and a dependency vulnerability fix). The dependency, its
  module declaration and its Sentry version tag are removed. Unlike pdf-ui (D139) the code has no folder of
  its own: it sits in the frontend's existing models, services, query hooks, constants, utilities,
  molecules, organisms and the outcomes page, named `Outcome*`.
- GovTool's own code replaces the pillar's copies of it: contexts (wallet, modal, snackbar, i18next and
  the shared QueryClient instead of the pillar's), theme, Typography, Button, Tooltip, CopyButton, Share,
  Breadcrumbs, DataMissingInfoBox, GovernanceActionCardHeader/-Element, the diff view, supporting links,
  the constitution and treasury elements, ada formatting, CIP-129 helpers, threshold keys and the PPU
  groups. Those gained only optional props and test ids (card header `dataTestId`, breadcrumb
  `isMetadataLoading`, `metadata-error-*`, `parameter-changes-labels`, `parameters-diff-value`).
- Kept from the pillar, rebuilt on GovTool atoms: the list card, dates box, status chips, filters, sort
  and search bar (URL state and localStorage keys unchanged), committee and hard-fork tabs, authors with
  witness verification, and the vote sections and outcome indicators. GovTool's DataActionsBar and
  committee tab were not reused: their test ids and behaviour differ from what the outcomes suite asserts.
- Unchanged for the outcomes suite: every test id, asserted string, route, request path and query
  parameter order. Requests go through their own axios client, `OutcomesAPI`, on `VITE_OUTCOMES_API_URL`,
  with the pillar's fallback hosts when unset, and without `API`'s redirect to the error page on a 500.
- Strings moved into the English locale under `outcome` and `outcomesList`. The pillar registered its bundle
  over GovTool's, so on `/outcomes` it overwrote `proposalDiscussion.title` ("Proposals" became "Discussion
  forum") and `learnMore`; its own values now live under `outcome.proposalDiscussion`.
- Fixed on the way: a CIP-129 search or link with index ≥ 10 was sent as hex (`#a`); it is now decimal.
  The search box no longer rewrites the URL every 300 ms.
- Kept as the pillar computed it, though GovTool's helper differs: SPOs on a ParameterChange that
  touches a network-group parameter use `pvtpp_security_group`; `getGovActionVotingThresholdKey` never
  answers SPOs there (its branch for it is unreachable).
- `/my/votes_and_favorites` still renders nothing of substance (the pillar showed a placeholder).

## D150 — SPOs on a ParameterChange use the security group threshold

**Date:** 2026-09-29
**Amends:** D149 (the outcomes page kept its own SPO rule).

- `getGovActionVotingThresholdKey` returned early for every voter but DReps on a ParameterChange, so its
  `pvtpp_security_group` branch never ran and SPOs had no threshold (the bar fell back to "> 50%").
- SPOs now get `pvtpp_security_group` whenever the action changes any parameter in
  `SECURITY_RELEVANT_PARAMS_MAP`, whichever DRep group it belongs to, as the ledger's security group
  cuts across the network, economic and governance groups. That is the same set both vote displays
  already use to decide whether SPOs vote at all. No security parameter: no SPO threshold.
- The outcomes pillar's rule (network group only, and not when an economic or governance parameter came
  first) is dropped with the local copy of it; it missed e.g. `txFeePerByte` and `govActionDeposit`.
- The live action page (`VotesSubmitted`) now shows the SPO threshold on such actions too.
- DRep keys are unchanged (the first group that matches, not the highest of the groups touched).

## D151 — govtool-backend is the only backend

**Date:** 2026-09-30
**Amends:** the open question of whether govtool-backend replaces backend-ts or folds into it.

- govtool-backend replaces both the Haskell backend and backend-ts, which are removed. It is what CI builds,
  checks and publishes under the existing backend image name, and what the deployment compose runs. The
  swarm test stack still builds the removed Haskell backend and is switched separately.
- The fixes made to backend-ts after the fork are carried over rather than lost with it: CIP-100-only,
  rate-limited anonymous uploads with no Pinata detail in errors; a DRep's vote on a proposal and the
  voted-on actions left out of its proposal list; blank CIP-108 titles and abstracts rejected; every 5xx
  logged and sent to Sentry; a clean stop on SIGTERM; one cache bound per namespace; and a failed voting
  power lookup that still answers 0 but is no longer cached.
- The image differs from the Haskell one in one way a deployment sees: the db-sync connection and network
  come only from environment variables, never from the config file.
- The outcomes API is served by this backend, so no deployment runs the separate outcomes service.

## D152 — Submission checks the url, with the full diagnosis; reads take the hash cache

**Date:** 2026-10-02
**Amends:** D112 (the url is a hint) for `POST /metadata/validate` at submission time.

- D112 is right for reads: content under a hash is authoritative, whatever url asked for it. At
  submission the url itself goes on chain, so a cached hash says nothing about whether the url serves
  it. Through the service, a url that serves nothing passed as `valid: true` once the hash was known.
  The removed metadata-validation service always fetched the url, so this only surfaced once the
  frontend validated through the backend.
- `POST /metadata/validate` takes an optional `verifyUrl: true`. The frontend sets it on every
  submission: DRep registration and edit, vote rationale, governance action creation, and the proposal
  discussion's submission step. Cards and details pages leave it unset and keep the cache.
- A submission failure gets the same full diagnosis as a read (D113–D117), not just a status. The
  metadata service gains `verify(hash, url)`, `POST /api/metadata/{hash}/verify?url=`: one real fetch
  whatever the cache holds, through the same guards and IPFS gateways, content cached on success and a
  fetch report kept on failure. The validate response carries that `reportId`, read or submission, and
  the submission error modals show the report itself (hops, addresses, response, body, served hash)
  rather than looking the anchor up, whose cached answer can disagree with what the url just served.
- `verify` is not windowed like `refresh` (D125): the person submitting needs this fetch, now. The
  backend limits it instead, per client and per instance; over the limit, or without a service that
  verifies, the backend fetches the url itself under the same guards (no private addresses, no
  redirects, size cap, 10 s) and checks the hash, with a status but no report.
- Validation waits at most 15 s for the metadata service, then falls back to the local fetch (10 s), so
  the whole request answers inside the frontend's 30 s timeout. The service is not cancelled; it
  finishes and records for the next read.
- A request that fails outright (timeout, network, 5xx) reaches the frontend as `INTERNAL_ERROR` with
  the request's own error text, shown in the same place as a report, so no card is left validating
  forever and the author still sees why.

## D153 — One convention for automatic votes; an unknown tally is null

**Date:** 2026-10-02
**Amends:** the outcomes UI's own arithmetic (D149) and the legacy `/proposal` and outcomes vote fields.
**Issue:** [#4260](https://github.com/IntersectMBO/govtool/issues/4260)

- Every provider reports an action's vote aggregates with the automatic votes already in them: the
  always-no-confidence DRep stake as yes on a NoConfidence action and as no on every other, and each
  pool's passive always-no-confidence and always-abstain stake the same way (pools not after a hard
  fork, and every silent pool as abstain before protocol 10). The DRep always-abstain stake is the one
  automatic figure left out of the action's abstain, because it sits outside the DRep denominator.
- The consumer adds nothing else. The outcomes page added the always-no-confidence stake to the DRep
  yes or no and the pools' passive stake to their yes, no and abstain a second time, so a 50% result
  read as 66.7% or 83.3% and the pass indicator could flip. It now adds only the DRep always-abstain
  stake to the DRep abstain.
- `/network/total-stake`'s `totalStakeControlledByDReps` is active DRep stake plus the
  always-no-confidence stake again, as the Haskell backend reported it: the live-action page divides
  DRep yes and no, which include that stake, by it. The contract's field of the same name stays the
  active stake; the backend adds the two at its edge. The outcomes route already did.
  The page's DRep "not voted" figure is that total less the abstain, yes and no figures as given; it
  no longer takes the always-no-confidence stake back out of yes or no first, which counted it as
  not voted.
- A tally figure the data source does not have is `null` on both the legacy `/proposal` routes and the
  outcomes routes, never 0, which reads as "nobody voted": the provider serves no aggregates for the
  action (Blockfrost on a concluded one), or a role's aggregate is a `percent`. A role left out of
  aggregates the provider does serve does not vote on the action and stays 0, as the Haskell backend's
  cast-vote counts were. Sorting by yes votes puts unknown totals last.
- The frontend shows a group whose figures are null as unavailable, with no pass or fail indicator.
- Not changed here: the Koios provider leaves the committee aggregate out of a concluded action rather
  than guess its denominator, which this rule reads as "does not vote" and so reports as 0.

## D154 — `/proposal` details and authors take the Haskell shapes again

**Date:** 2026-10-02
**Amends:** the legacy `/proposal` mapping, which sent the contract's typed body as `details` and left
`json` and `authors` empty.
**Issue:** [#4261](https://github.com/IntersectMBO/govtool/issues/4261)

- `details` is db-sync's `description` reshaped by type, as the Haskell backend's `list-proposals.sql`
  did and the frontend's detail tabs read it: a treasury withdrawal as `[{receivingAddress, amount}]`, a
  hard fork as `{major, minor}`, a committee change as `{tag, members, membersToBeRemoved, threshold}`
  with each added member's current term from the committee in force, a constitution as
  `{anchor, script}`, and `{data: …}` for the rest. The outcomes route already built these for its
  `description`; the one function now serves both.
- The current committee is read once per proposal snapshot, and only when an UpdateCommittee needs it.
  If it cannot be read, a member's current term is null, as for a member not yet on the committee.
- `json` and `authors` come from the anchored document, resolved through the metadata service with the
  four CIP-108 strings: `json` is the whole document, and `authors` lists each CIP-100 author as
  `{name, publicKey, signature, witnessAlgorithm}`, as the Haskell backend read them from
  `off_chain_vote_data`. The frontend shows the authors and verifies their signatures from these.
- The same enrichment applies to every route that sends a proposal: `/proposal/list`, `/proposal/get`
  and a DRep's vote history (`/drep/getVotes`), whose rows the details page opens as they are, without
  reading the proposal again.
- Unchanged: `/proposal/enacted-details` still sends the typed body as `description`. The Haskell
  backend sent db-sync's raw column there, and nothing reads it.

## D155 — Search matches DRep names and action text again, from the metadata service

**Date:** 2026-10-02
**Amends:** the `/drep/list` and `/proposal/list` search, which matched ids only once document text left
chain data (D40, D45, D87 left free text to an index provider; none was wired).
**Issue:** [#4262](https://github.com/IntersectMBO/govtool/issues/4262)

- The Haskell backend searched DReps by exact id or `given_name ILIKE`, and actions by id or by title,
  abstract, motivation and rationale `ILIKE`. The new backend matched ids only on every provider: a name
  went to the provider's `exactId` search, and action text was filtered while it was still null, before
  the page's documents were resolved.
- No provider indexes document text, so the backend matches it itself, over its whole snapshot, with
  the text read through the metadata service and kept per (hash, url) in the same stale-while-revalidate
  cache the outcomes search uses, now in `src/metadata/text-cache.ts`.
- Actions: a search reads every candidate's four strings before filtering and paging. It waits at most
  5 s in all for text it has not cached, then matches what the cache holds; the fetches carry on and fill
  it for the next search. So a search's time does not grow with the number of documents, which matters
  for a DRep's whole vote history. The warmer fills the cache for live actions after each refresh.
- A term that can only be an action id (a `gov_action1…` id, or eight or more hex digits with an
  optional `#index`) is matched against ids alone and reads no document.
- DReps: a term that is not a DRep id is a name, matched case-insensitively as a substring over the whole
  directory. A directory holds thousands of DReps, more than a search can resolve on demand, so it
  matches the names already cached and never fetches. The cache warmer resolves every DRep's name after
  each snapshot refresh; until its first run completes after a start, a DRep whose name is not cached
  yet is not found. The DRep vote history's action search gets the same action text match.
- Without a metadata service there is no document text, and search matches ids only, as before. The
  declared `drepDirectory.search` options are unchanged: the backend already claimed free text, and now
  honours it.

## D156 — Outcomes is always enabled as part of GovTool

**Date:** 2026-10-02
**Said:** "So it should always be enabled."
**Amends:** D143 (provider limitations prevented the whole Outcomes section from being enabled).

- Outcomes is GovTool's own frontend and backend. Its public and wallet-connected routes, navigation,
  and links from submitted proposals are always available; there is no environment enable/disable flag.
- Outcomes requests default to the configured GovTool backend with `/outcomes` appended. An explicit
  API URL override remains supported; an unset override never selects an external Outcomes service.
- Provider limitations belong to the affected data and calculations within Outcomes. They do not
  disable the entire section. When required voting metrics or protocol parameters cannot be loaded,
  the page retains the action's recorded status and shows an unavailable-data message instead of
  computing pass/fail indicators from missing values.

## D157 — Remove the obsolete votesLastYear field and retain optional activity sorting

**Date:** 2026-10-02
**Said:** "Remove the obsolete field; keep capability-aware activity sorting".

- DRep directory responses no longer include `votesLastYear`. Its name implied a trailing year, while
  the underlying participation count covers governance actions voted on since registration.
- The backend retains the provider's activity data internally for Voting Activity sorting. It never
  serializes that internal count under the obsolete name or replaces it with another response field.
- Activity sorting is offered only when the configured provider declares directory activity support.
  A direct request for unsupported activity sorting, or a supported declaration with missing directory
  activity data, is refused explicitly instead of treating unknown counts as zero or ranking all rows
  equally. The frontend selects an available fallback when its persisted Activity choice is unsupported.

## D158 — Outcomes displays action-specific aggregates independently per voter group

**Date:** 2026-10-02
**Said:** "lets do that" — consume the available proposal aggregates, display each supported group
independently, and validate live and concluded actions against Koios and db-sync.
**Amends:** D143 (Outcomes recalculated votes from a complete network-metrics response) and D156
(a missing metric prevented all voting calculations from rendering).

- The Outcomes detail response includes `vote_aggregates`, containing only the contract's per-role
  representation, yes/no/abstain/not-voted figures, eligible total, threshold ratio and optional passing
  decision. Strings preserve exact quantities; provider extensions are not serialized.
- The voting panel consumes those aggregates directly. It never recomputes automatic votes from
  network totals or substitutes present-day stake or committee membership into a historical tally.
- Each applicable voter group renders independently. An absent aggregate means the provider does not
  support that group's complete breakdown; the UI says so directly and displays no invented totals or
  pass/fail result. Groups that do not vote on the action have a separate inapplicability message.
- The supported table displays only the breakdown the aggregate actually supplies. Automatic and
  explicit vote subcategories are not separately reported when the contract does not supply them.
- Passing uses the provider decision when supplied, otherwise exact cross-multiplication against its
  threshold, with no majority fallback for a zero threshold. A zero non-abstaining denominator is a
  zero ratio, as in the ledger: it passes only a zero threshold. InfoAction never receives a pass/fail
  indicator.
- The recorded lifecycle status remains visible regardless of which voting groups are supported.
  Other detail tabs request protocol parameters independently; no voting panel or detail tab requires
  the complete network-metrics endpoint.

## D159 — Koios omits historical SPO default-vote aggregates it cannot reproduce

**Date:** 2026-10-02
**Evidence:** A live comparison on preview at epoch 1438 found identical DRep tallies for an enacted
committee update ratified in epoch 1369, but different SPO no/abstain/not-voted values. Eligible SPO
stake and explicit yes stake matched. Koios's proposal summary resolves pool reward accounts through
its current pool-info cache, whereas the db-sync tally uses registrations effective at the tally epoch.

- Until historical pool reward-account registrations can be reproduced, the Koios adapter omits SPO
  aggregates for past protocol-10 tallies that use reward-account default votes. It retains supported
  DRep aggregates and the Outcomes UI identifies the absent SPO breakdown explicitly (D158).
- Historical hard-fork tallies remain supported because silent pools count as not-voted regardless of
  reward delegation. Historical bootstrap tallies remain supported because silent pools abstain.
- Current-epoch SPO tallies remain supported. This restriction does not imply that Koios lacks all pool
  voting data; it prevents current registration state from being substituted into historical defaults.

## D160 — DRep retirement invalidates a prior vote, even after re-registration

**Date:** 2026-10-02
**Evidence:** The preview live comparison at epoch 1438 found a 4,994,351,707-lovelace DRep Yes vote
counted by db-sync and excluded by Koios. The DRep retired after that vote and later re-registered.
The latest registration alone therefore cannot establish that its old vote is still valid.

- The db-sync aggregate excludes a DRep vote when a retirement certificate follows it and precedes
  the tally epoch's transaction cutoff. A later registration does not reinstate that earlier vote.
- Retirement after the tally cutoff does not rewrite a historical result. A fresh vote after
  re-registration remains eligible under the existing activity and stake rules.
- This aligns the db-sync aggregate with Koios's retirement rule without changing the eligible total
  or silently converting a supported vote into an unavailable aggregate.

## D161 — Committee aggregates carry the minimum-size approval veto

**Date:** 2026-10-02
**Evidence:** The ledger's `votingCommitteeThresholdInternal` refuses committee approval when
active membership is below `committeeMinSize`, except during bootstrap. A quorum ratio alone
cannot reproduce that decision, even with unanimous yes votes or a zero quorum.
Source: [Conway governance rule](https://github.com/IntersectMBO/cardano-ledger/blob/master/eras/conway/impl/src/Cardano/Ledger/Conway/Governance/Internal.hs#L441-L459).
**Amends:** D158 (deriving passing from an aggregate's ratio alone).

- db-sync and current-epoch Koios committee aggregates retain their complete vote breakdown and
  quorum, and supply the existing optional `passing: false` when eligible membership is below
  the tally epoch's minimum size outside bootstrap.
- Meeting the minimum does not itself mean passing; the existing exact quorum comparison applies.
  Bootstrap bypasses this size gate, and InfoAction still has no pass/fail indicator.
- The Outcomes frontend already honours provider decisions. No additional protocol-parameter
  request or network-wide metric is needed to display the veto.


## D162 — Governance actions use the GovTool backend and action history naming

**Date:** 2026-10-02

**Amends:** D143 and D156 (separate action-history API namespace and optional URL override),
D149 and D158 (the legacy Outcomes terminology in frontend source and browser checks).

- There is one GovTool backend. Governance action records are served at
  `/governance-actions`, with supporting epoch, network and author-verification routes
  under `/misc`. They are not a separate service or a separately enabled feature.
- The frontend uses `VITE_BASE_URL` for these requests. The separate API URL override
  and the `/outcomes` backend prefix are removed; no compatibility alias is retained.
  Existing response fields and exact per-role aggregates are unchanged.
- The view of completed actions is called Governance action history, under
  `/governance_actions/history`; detail links append the action's `txHash#index`.
  The existing lifecycle filters, including live actions, remain available.
- Backend classes, frontend source, browser helpers and test commands use governance
  action names. Historical decision records and source attribution retain their original names.
- Governance-action browser regression checks share the existing frontend browser CI
  job with CIP-179, including dependency and Chromium installation. Browser-only edits
  do not run frontend unit tests, lint or type checking; frontend source changes do.

## D163 — Committee hot credentials do not identify seats

**Date:** 2026-10-02
**Amends:** D161 (minimum-size calculation in the Koios implementation).
**Evidence:** The ledger walks cold committee credentials and looks up each member's authorised
hot credential when tallying. Multiple cold members can therefore use the same hot vote.
Source: [Conway committee tally](https://github.com/IntersectMBO/cardano-ledger/blob/master/eras/conway/impl/src/Cardano/Ledger/Conway/Rules/Ratify.hs#L131-L158).

- Koios current-epoch committee aggregates retain the eligible cold-to-hot mapping. Each
  cold member contributes one seat and receives its hot credential's latest vote, including
  abstentions; a member whose hot credential has not voted contributes to not-voted.
- The minimum-size veto counts eligible cold members, rather than distinct hot credentials.
  db-sync already counts cold members and needs no change. Historical Koios committee
  aggregates remain unavailable because current authorisations cannot reconstruct them.

## D164 — CIP-179 surveys return as an optional chain-data namespace (closes OPEN-48)

**Date:** 2026-10-02
**Amends:** the contract reconciliation that deleted `surveys.ts` ("one judgement call, flagged for
review"), and OPEN-48.
**Issue:** [#4263](https://github.com/IntersectMBO/govtool/issues/4263)

- Surveys return. The frontend's CIP-179 v5 workflow was enabled by default while every survey lookup
  answered 501, so an author who linked a survey could not create the action. The workflow is
  GovTool's, it existed before, and all three live providers can serve it.
- `ChainDataApiV1.surveys?: SurveysApi` with `getDefinition(txHash)`, SPEC.md §5.6. Optional: an absent
  namespace means the provider cannot, as for every other optional member (§4). The answer is the
  transaction's whole label-17 metadata as a singleton CBOR map `{17: payload}`, never rebuilt from
  JSON, which loses byte strings, integer keys and precision. Missing transaction or label is `null`;
  a transaction whose bytes the source does not hold is `PROVIDER_UNAVAILABLE`; corrupt data is
  `INTERNAL`. Equivalence across providers is on the decoded value, not the bytes.
- db-sync reads `tx_metadata.bytes`, which is already that map. Koios reads `/tx_cbor` (its
  `/tx_metadata` is decoded JSON only); it needs a Koios instance that retains transaction CBOR. A
  bounded reader finds the body and auxiliary data without decoding them, the body must hash to the
  requested transaction and the auxiliary data to the body's `auxiliary_data_hash`, and only the
  auxiliary data, nested at most 64 deep, is decoded with `@emurgo/cardano-serialization-lib-nodejs`
  14.1.2 to extract label 17. CSL decodes recursively in wasm: one value nested a few thousand deep
  anywhere in a transaction, including an inline datum inside tag 24, overflows its stack and breaks
  every later call in the process, and the route is public.
  Blockfrost reads `/txs/{hash}/metadata/cbor` (`metadata`, not the deprecated `cbor_metadata`) and
  normalizes an inner value into the map with the same library. The fixture serves two synthetic
  definitions, one single and one batched.
- `GET /survey/definition/:txId/:index` keeps its body and its 400 and 404 answers. It returns the
  whole batch for any index 0–65535; the frontend selects and validates the definition (version,
  expiry against the action, eligibility, answers). Reads are cached for 60 seconds per transaction,
  shared between concurrent requests and never cached on failure. The HTTP cache policy drops from a
  year, immutable, to `public, max-age=60`, since a rollback can undo the publishing transaction;
  errors are `no-store`.
- `/system/features` gains `survey.linkedVoting`, unavailable (`noSource`) when the provider has no
  `surveys` namespace. The frontend enables CIP-179 only when `VITE_IS_CIP179_ENABLED` allows it (on
  unless set to `false`) and the feature is available; while the feature set is loading or failed it
  fails open, as for every feature. `VITE_IS_CIP179_ENABLED=false` is the emergency switch.
- A linked survey reaches the frontend only through the hash-verified CIP-108 document in a
  proposal's `json` (D154): a document that fails its hash check supplies no link.
- Release gate, not satisfied by automated tests: each provider against a real network, the same
  real survey transactions (including a batch of two or more definitions) decoding to the same value
  on all three, and a public response submitted with a vote on preview. A Koios instance without CBOR
  retention, or a Blockfrost endpoint without the route, keeps that deployment's gate closed.
