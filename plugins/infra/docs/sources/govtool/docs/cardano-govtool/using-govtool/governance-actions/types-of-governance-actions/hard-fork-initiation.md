# Hard Fork Initiation

### A non-backward compatible upgrade of the network, which requires a prior software upgrade

This action will have:

* The new protocol version (major and minor)
* Optionally, the ID of the previous Hard Fork Initiation Governance Action

:::note
The thresholds on this page are the example values from CIP-1694. The thresholds that actually apply are protocol parameters that can be changed by governance; GovTool reads them from the current epoch parameters and shows the applicable threshold on each Governance Action's detail page.
:::

To pass, this Action requires:

<table><thead><tr><th width="278">Constitutional Committee</th><th width="218">DReps</th><th>SPOs</th></tr></thead><tbody><tr><td>Pass</td><td>60%</td><td>51%</td></tr></tbody></table>

These values could be changed via a new Government Action. To see the current values at any time, you can view [https://cardanoscan.io/protocolparams](https://cardanoscan.io/protocolparams).

Note:

There are many varying definitions of the term "hard fork" in the blockchain industry. Hard forks typically refer to non-backwards compatible updates of a network. In Cardano, we formalise the definition slightly more by calling any upgrade that would lead to _more blocks_ being validated a "hard fork" and force nodes to comply with the new protocol version, effectively obsoleting nodes that are unable to handle the upgrade.
