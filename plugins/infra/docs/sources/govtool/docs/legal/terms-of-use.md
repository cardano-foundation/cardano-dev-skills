---
description: The terms that apply when you use Cardano GovTool, its documentation and its APIs.
---

# Terms of Use

**Last updated: 5 October 2026**

These Terms of Use ("**Terms**") govern your use of Cardano GovTool ("**GovTool**"), including:

* the web application at [gov.tools](https://gov.tools) and its test instances (for example [preview.gov.tools](https://preview.gov.tools)),
* the features embedded in GovTool, such as Proposals, Budget Proposals and Outcomes,
* this documentation site ([docs.gov.tools](https://docs.gov.tools)), and
* the public GovTool APIs

(together, the "**Services**"). The Services were initially developed by IntersectMBO. Since September 1st 2026, they are operationally owned and made available by Sireto BV ("**Sireto**", "**we**", "**us**").

By using the Services, you agree to these Terms and to our [Privacy Policy](./privacy-policy.md). If you don't agree, please don't use the Services.

## 1. What GovTool is (and isn't)

GovTool is an open-source interface that helps ada holders take part in Cardano on-chain governance as described in [CIP-1694](https://github.com/cardano-foundation/CIPs/blob/master/CIP-1694/README.md). With GovTool you can view Governance Actions, delegate your Voting Power, register as a DRep or Direct Voter, vote, propose Governance Actions, and discuss proposals.

* **GovTool is non-custodial.** It is not a wallet. We never hold your ada, and we never have access to your seed phrase or private keys. You interact with the blockchain through your own wallet, and nothing happens without your signature.
* **GovTool is an interface, not the blockchain.** Governance rules, thresholds, deposits and outcomes are determined by the Cardano protocol and its participants, not by GovTool. The information GovTool shows (for example vote totals, Voting Power and DRep information) is derived from blockchain data and from third-party metadata. It may be delayed, incomplete or inaccurate.
* **GovTool does not give advice.** Nothing in the Services is financial, investment, legal or tax advice. GovTool does not endorse any DRep, proposal, Governance Action or vote. Information published by DReps, proposers and other users is their own, and GovTool does not verify it unless it says so explicitly.
* **GovTool is community software.** GovTool and its pillars are built and maintained by community builder teams, with direction from the Cardano community through Intersect's committees and working groups.

## 2. Eligibility

You may use the Services only if you have reached the age of majority where you live (and in any case you are at least 18), and you are legally allowed to use them. You may not use the Services if you are subject to sanctions, or where your use would break applicable laws.

## 3. Your wallet and your transactions

* **You are responsible for your wallet**, including keeping your seed phrase and private keys safe. We will never ask for them. Anyone who does is not us.
* **Review before you sign.** Transactions you sign, such as delegating, registering, voting, retiring or submitting a Governance Action, are final and **cannot be reversed** by GovTool or by Sireto.
* **Fees and deposits.** Transactions require network fees. Some actions require deposits set by protocol parameters (for example the DRep deposit, stake key deposit and Governance Action deposit). These are paid to and refunded by the Cardano protocol according to its rules, not by Sireto. GovTool shows the expected amounts, but you are responsible for checking them in your wallet before signing.
* **Test networks.** Test instances (such as preview.gov.tools) use test networks. Test ada has no value, and test instances may be reset, changed or taken offline at any time.
* **Wallet compatibility.** GovTool works with wallets that support [CIP-95](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0095). Wallets are third-party software, and we are not responsible for how they work.

## 4. Public and permanent information

Governance activity on Cardano is public. Delegations, votes, DRep registrations and Governance Actions are recorded **permanently** on the blockchain and can be seen by anyone. Metadata you publish at a URL, content you choose to pin to IPFS, and content you post in Proposals and Budget Proposals are public too. Don't publish anything you're not comfortable being public forever. Some content, such as content on the blockchain or IPFS, cannot be deleted by anyone.

## 5. Your content

"**Your Content**" means anything you create or publish through the Services, such as DRep information, Governance Action and proposal texts, Budget Proposals, comments, poll votes, vote rationales and your Display Name.

* **You own Your Content.** You give Sireto and the teams operating GovTool a worldwide, non-exclusive, royalty-free, perpetual license to host, store, reproduce, display and distribute Your Content as needed to operate, show and improve the Services, including through GovTool's public APIs. For content you publish on-chain or on IPFS, this also covers displaying it as part of the public governance record.
* **You are responsible for Your Content.** You confirm that you have the rights to publish it, that it is accurate to the best of your knowledge, and that it doesn't break the law or anyone else's rights.
* **Your Display Name cannot be changed** once it is set, and it is shown publicly next to your activity.
* **Moderation.** We may hide, remove or refuse to display off-chain content in the Services (for example comments, proposals, or DRep information shown in the DRep Directory) that breaks these Terms or the law, or that is reported and found to be abusive. We cannot remove content from the blockchain or from IPFS.

## 6. Acceptable use

When using the Services, you agree not to:

* impersonate any person, DRep, organization or Governance Action author, or misrepresent your identity or affiliation,
* publish content that is unlawful, defamatory, harassing, hateful, sexually explicit, or that infringes others' rights,
* publish links to malware or phishing sites, or try to obtain other users' seed phrases, keys or funds,
* manipulate discussions, polls, likes or reports, for example by using multiple accounts to create a false impression of support,
* spam, or use the Services for unsolicited advertising,
* attack, probe or disrupt the Services, for example with excessive automated requests, attempts to bypass security, or metadata URLs designed to attack GovTool's servers or other systems,
* use the Services to break any applicable law or sanctions.

We may suspend or restrict access to the off-chain parts of the Services (such as Proposals and Budget Proposals) if you break these rules.

## 7. APIs

GovTool's APIs are public and are mainly designed for GovTool itself. Builders may use them, but:

* the APIs may change or be withdrawn without notice, unless a specific API commitment says otherwise (see [Govtool APIs](../participate-in-development/govtool-apis/README.md)),
* you must use them fairly, and must not overload them. We may rate-limit or block excessive use,
* you must follow these Terms and the law when you use or republish data obtained through the APIs, including other users' public content.

## 8. Open source and intellectual property

GovTool's source code is open source under the [Apache License 2.0](https://github.com/IntersectMBO/govtool/blob/develop/LICENSE). Your use of the code is governed by that license. These Terms govern your use of the hosted Services.

The GovTool and Sireto names, logos and branding may not be used in a way that suggests endorsement by, or affiliation with, GovTool or Sireto, without permission. Anyone may run their own instance of the open-source code, but it must not be presented as the official GovTool.

## 9. Third-party services and links

The Services interact with, embed or link to third-party services, such as wallets, IPFS and IPFS gateways, community governance tools, block explorers, and embedded content in the documentation. We don't control these services and are not responsible for them. Their own terms and privacy policies apply.

## 10. Changes and availability

GovTool is under active development. We may add, change or remove features, instances or APIs, and we may suspend the Services for maintenance, security or other reasons, at any time and without liability. We don't guarantee that the Services will be available, uninterrupted or error-free. Because governance activity happens on the Cardano blockchain, you can always also use other tools, including the command line or other community tools, to take part in governance.

## 11. Disclaimers

The Services are provided "**as is**" and "**as available**", without warranties of any kind, express or implied, including warranties of merchantability, fitness for a particular purpose, accuracy and non-infringement. In particular, we don't warrant that information shown in the Services (including vote totals, thresholds, Voting Power, DRep information or third-party metadata) is accurate, complete or up to date. We are not responsible for the behavior of wallets, the Cardano network, IPFS, or third-party services.

## 12. Limitation of liability

To the maximum extent permitted by law, Sireto, the teams that build and operate GovTool, and their respective affiliates, officers, employees and contributors will not be liable for any indirect, incidental, special, consequential or punitive damages, or for any loss of funds, digital assets, profits, data or goodwill, arising from or related to your use of the Services. This includes losses from transactions you sign, wallet or network failures, or reliance on information shown in the Services. Our total liability for any claim related to the Services is limited to one hundred US dollars (USD 100). Some jurisdictions don't allow certain limitations, so some of these may not apply to you.

## 13. Indemnification

You agree to indemnify and hold harmless Sireto and the teams that build and operate GovTool from claims, damages and expenses (including reasonable legal fees) arising from Your Content, your use of the Services, or your breach of these Terms or of the law.

## 14. Governing law and disputes

These Terms are governed by the laws of the Netherlands, without regard to conflict-of-law rules.

Before starting any formal proceedings, you agree to first try to resolve any dispute informally by contacting us at [legal@gov.tools](mailto:legal@gov.tools).

If a dispute cannot be resolved informally, it will be submitted to the competent courts of the Netherlands. To the extent permitted by applicable law, the courts of the Netherlands shall have exclusive jurisdiction.

If you are a consumer, this section does not affect any mandatory rights or protections you may have under the laws applicable to you, including any right to bring proceedings before another court where required by applicable consumer protection law.

## 15. Changes to these Terms

We may update these Terms from time to time. We will change the "Last updated" date above and, for material changes, give notice in GovTool or on this site. If you keep using the Services after changes take effect, you accept the updated Terms. The history of this page is public in the [GovTool repository](https://github.com/IntersectMBO/govtool/commits/develop/docs/docs/legal/terms-of-use.md).

## 16. General

If any part of these Terms is found unenforceable, the rest remains in effect. Our failure to enforce a provision is not a waiver. These Terms, together with the Privacy Policy, are the entire agreement between you and us about the Services. Sections 4, 5, 8 and 11 to 16 survive the end of your use of the Services.

## 17. Contact

Sireto BV, Zwolle, The Netherlands. Email: [legal@gov.tools](mailto:legal@gov.tools).

To report a security vulnerability, please follow the [GovTool security policy](https://github.com/IntersectMBO/govtool/blob/develop/SECURITY.md).
