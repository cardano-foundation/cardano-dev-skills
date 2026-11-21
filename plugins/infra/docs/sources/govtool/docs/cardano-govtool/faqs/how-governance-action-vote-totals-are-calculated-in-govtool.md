# How Governance Action Vote Totals are Calculated in GovTool

GovTool aims to show vote total values which help the user gauge likelihood of ratification of an action. Vote totals are computed for live Governance Actions (not yet ratified, enacted, expired or dropped).

The raw totals come from GovTool's backend, which reads them from its data provider (by default, SQL queries on DB-Sync). The percentages and "Not Voted" values are then calculated in the GovTool frontend.

If the data provider cannot give a vote total for an action, GovTool shows that total as unavailable instead of as zero votes.

## DRep Vote Total Equation

### Intro definitions

* Active DRep stake = all the voting power of DReps within the active state&#x20;
  * This does not include retired DReps, or DReps that have been inactive for longer than the `drepActivity` protocol parameter (no vote or registration/update within that many epochs)
* Total Active Stake = Active DRep stake + auto no confidence stake − DRep Abstain votes cast on this action
  * Auto-abstain stake is never included, as it is not part of the ratification equation
  * Explicit Abstain votes on the action are removed as well, for the same reason

### For a governance action

#### :thought\_balloon: Abstain Total&#x20;

* Total voting power of DRep Abstain votes + auto-abstain stake
  * The DRep Abstain votes come from the SQL query; the auto-abstain stake is added by the frontend
  * No percentage is shown for Abstain

#### :white\_check\_mark: Yes Total

* IF governance action type != 'NoConfidence'&#x20;
  * Total of voting power of DReps Yes votes&#x20;
* IF governance action type == 'NoConfidence'
  * Total of voting power of DReps Yes votes + auto no confidence stake

#### :white\_check\_mark: Yes Percentage

* (Yes Total / Total Active Stake) x 100

#### :x: No Total

* IF governance action type != 'NoConfidence'
  * Total of voting power of DReps No votes + auto no confidence stake
* IF governance action type == 'NoConfidence'
  * Total of voting power of DReps No votes

#### :x: No Percentage

* (No Total / Total Active Stake) x 100

#### :ballot\_box: Not Voted Total (remainder of Total Active Stake)

* Total Active Stake − Yes Total − No Total
  * Yes Total and No Total already include the auto no confidence stake, so it is not counted again as "Not Voted"

#### :ballot\_box:  Not Voted Percentage (remainder of Total Active Stake Percentage)

* 100 − Yes Percentage − No Percentage

## DRep Vote Total Implementation

GovTool's backend (`govtool/govtool-backend`) reads chain data through a data provider. On a db-sync deployment, the [db-sync provider's vote totals query](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-provider-dbsync/src/governance/proposals/aggregates.ts#L94-L126) pulls the vote totals for each governance action. The denominator comes from a [separate stake distribution query](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-provider-dbsync/src/network.ts#L294-L337), which the [backend turns into the total stake controlled by DReps](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-backend/src/network/network.service.ts#L43-L67), and the percentages are calculated in the [frontend](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/frontend/src/components/molecules/VotesSubmitted.tsx#L98-L126).

* GovTool takes DRep voting power from [`drep_distr` table of DB-Sync](https://github.com/IntersectMBO/cardano-db-sync/blob/master/doc/schema.md#drep_distr) for the registered DReps and the "predefined voting option DReps", this data is only updated once per epoch.
* GovTool takes the newest vote from DReps for that governance action, and leaves out a vote if the DRep retired after casting it, even if the DRep registered again later.
* In the provider code
  * [Takes the newest vote of each voter on the governance action](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-provider-dbsync/src/governance/proposals/aggregates.ts#L87-L92)
  * [Leaves out votes made invalid by the DRep's retirement](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-provider-dbsync/src/governance/proposals/aggregates.ts#L80-L85)
  * [Sums the Yes, No and Abstain votes of DReps active in the tally epoch](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-provider-dbsync/src/governance/proposals/aggregates.ts#L103-L112)
  * [Gets the active DRep stake and the voting power of the predefined no confidence DRep](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-provider-dbsync/src/governance/proposals/aggregates.ts#L113-L120)
  * [Counts the predefined no confidence stake as Yes on a Motion of No Confidence and as No on every other action](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-provider-dbsync/src/governance/proposals/aggregates.ts#L286-L299)
  * [Calculates the active DRep stake and the predefined always abstain and no confidence stake for the denominator](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-provider-dbsync/src/network.ts#L300-L309)
* In the backend, the [total stake controlled by DReps is the active DRep stake plus the auto no confidence stake](https://github.com/IntersectMBO/govtool/blob/5bad69ac9d891133b58c680ad58f0de755554d9c/govtool/govtool-backend/src/network/network.service.ts#L52-L60)

:::note
Until September 2026 these totals came from SQL files in the Haskell backend (`govtool/backend/sql`), which has since been removed. See the [last version of `list-proposals.sql`](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/backend/sql/list-proposals.sql) for reference.
:::

### Example

* So we have some DRep John Doe, who voted `yes` on X governance action
* John Doe has 100k Voting power coming from his own stake and all delegators (we are taking that value directly from db-sync (no calculations on GovTool side))
* We have another DRep - Andre, who has 200k Voting power!
* Andre also likes the governance action and votes `yes`
* As a result - we display the sum of their voting powers, so it would be 300k for `yes` votes
* Important note - John Doe and Andre can change their votes

## SPO Vote Totals

* SPO totals use the latest vote per pool, weighted by `pool_stat.voting_power` for the current epoch.
* Percentages are divided by the total pool stake (`pool_stat.stake`) for the current epoch.
* Unlike DReps, no auto-abstain or auto no confidence adjustment is applied, and Abstain votes are not removed from the denominator.
* Not Voted value = total pool stake − Yes − No − Abstain; Not Voted Percentage = 100 − Yes Percentage − No Percentage.

## Constitutional Committee Vote Totals

* CC totals are a count of each committee member's latest vote (one member, one vote).
* Percentages are divided by the number of committee members.

## Thresholds

* The DRep and SPO thresholds shown are the voting-threshold protocol parameters that apply to the Governance Action type, read from the current epoch parameters.
* The CC threshold shown is the committee quorum (numerator/denominator). No CC threshold is shown for Info actions.

## Which totals are shown

With full governance (protocol version 10 and later):

* DRep totals are always shown.
* SPO totals are not shown for New Constitution, Treasury Withdrawal, and Protocol Parameter Changes that don't touch security-group parameters, since SPOs don't vote on these.
* CC totals are not shown for Motion of No Confidence and Update Committee actions, since the CC doesn't vote on these.
