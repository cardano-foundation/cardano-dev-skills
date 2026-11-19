# Update Committee or Threshold or term limits

### Changes to the members of the constitutional committee and/or to its signature threshold and/or terms

This action will have one or more of these data objects:

* The set of verification key hash digests (members to be removed)
  * Members can be removed either singly or in multiples.
* A map of verification key hash digests to epoch numbers (new members and their term limit)
  * New members can be added along with their term ending epoch dates
* A fraction (new threshold)
  * The threshold for passing an Action can be changed

:::note
The thresholds on this page are the example values from CIP-1694. The thresholds that actually apply are protocol parameters that can be changed by governance; GovTool reads them from the current epoch parameters and shows the applicable threshold on each Governance Action's detail page.
:::

To pass, this Action requires:

#### Normal state of Constitution:

<table><thead><tr><th width="278">Constitutional Committee</th><th width="218">DReps</th><th>SPOs</th></tr></thead><tbody><tr><td>Doesn't Vote</td><td>67%</td><td>51%</td></tr></tbody></table>

#### Constitution in state of No Conficence

<table><thead><tr><th width="278">Constitutional Committee</th><th width="218">DReps</th><th>SPOs</th></tr></thead><tbody><tr><td>Doesn't Vote</td><td>60%</td><td>51%</td></tr></tbody></table>

These values could be changed via a new Government Action. To see the current values at any time, you can view [https://cardanoscan.io/protocolparams](https://cardanoscan.io/protocolparams).
