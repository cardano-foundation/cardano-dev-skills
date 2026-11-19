# Governance Actions

Governance Actions are the core elements that make up governance on the blockchain. Anyone that has ADA in a wallet can propose a Governance Action. To submit a Governance Action, the submitter pays a refundable deposit, set by the protocol parameter `govActionDeposit` (currently 100,000 Ada). The deposit is returned to the submitter's reward address when the Governance Action is enacted or expires.

### Every governance action will include the following:

* a deposit amount (recorded since the amount of the deposit is an updatable protocol parameter)
* a reward address to receive the deposit when it is repaid
* an anchor for any metadata that is needed to justify the action
* a hash digest value to prevent collisions with competing actions of the same type (as described earlier)

Governance Actions are covered in depth in [CIP-1694](https://github.com/cardano-foundation/CIPs/blob/master/CIP-1694/README.md), which is the main defining document for governance on Cardano. You can read about the entirety of Cardano Governance in this document.&#x20;

### To Submit a Governance Action on GovTool, you will need to:

1. Connect a wallet ([compatible-wallets.md](../getting-started/compatible-wallets.md "mention")) to GovTool that holds enough Ada to cover the deposit (currently 100,000 Ada) plus a few extra Ada for transaction fees
2. Create a "Proposal" for the Governance Action ([propose-a-governance-action.md](./propose-a-governance-action.md "mention")). Your Proposal stays in the Proposal (discussion) stage until you submit it. This is a forum for discussion and refinement, and is provided by GovTool to help users socialise and refine their proposed Actions if they so choose.
3. When you feel your Proposal is ready for a vote, click the "Submit as Governance Action" button.
4. Store the generated metadata file for your Governance Action yourself ([storing-information-offline.md](../storing-information-offline.md "mention")), paste its URL into GovTool, and sign the transaction that pays the deposit. The deposit is refunded when the Action is enacted or expires.

