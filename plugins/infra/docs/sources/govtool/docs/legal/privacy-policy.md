---
description: How GovTool handles personal and technical data when you use gov.tools, its documentation and its APIs.
---

# Privacy Policy

**Last updated: 5 October 2026**

This Privacy Policy explains what data is processed when you use Cardano GovTool, and how. GovTool is an open-source, non-custodial application for taking part in Cardano on-chain governance. GovTool was initially developed by IntersectMBO. Since September 1st 2026, GovTool is operationally owned and made available by Sireto BV ("**Sireto**", "**we**", "**us**").

This policy applies to:

* the GovTool web application at [gov.tools](https://gov.tools) and its test instances (for example [preview.gov.tools](https://preview.gov.tools)),
* the features embedded in GovTool, including Proposals, Budget Proposals and Outcomes,
* this documentation site ([docs.gov.tools](https://docs.gov.tools)), and
* the public GovTool APIs.

It does not apply to your wallet, the Cardano blockchain itself, IPFS, or third-party community tools that use GovTool's APIs or are linked from GovTool. Those have their own terms and privacy policies.

## The short version

* GovTool is **non-custodial**. We never ask for, receive or store your seed phrase or private keys. Transactions are built in your browser and signed by your own wallet.
* You don't need an account to view governance data, delegate, register as a DRep or Direct Voter, or vote. Your wallet is your identity.
* Almost everything you do in governance is recorded on the **public Cardano blockchain**, where it is visible to everyone and **cannot be changed or deleted**, by us or anyone else.
* Some off-chain information you choose to publish (such as DRep metadata, proposals, comments, or vote rationales pinned to IPFS) is also public.
* We use privacy-conscious analytics, error monitoring and a support chat to run and improve GovTool. We do not sell your data and we do not show ads.

## Data we process

### 1. Public blockchain data

GovTool reads public data from the Cardano blockchain (through a [cardano-db-sync](https://github.com/IntersectMBO/cardano-db-sync) database) to show you governance information. This includes addresses, stake keys, DRep IDs, delegations, votes, DRep registrations, Governance Actions, and the metadata anchors (URL and hash) attached to them.

When you use GovTool to delegate, register as a DRep or Direct Voter, vote, or submit a Governance Action, you create a transaction that is **permanently recorded on the public blockchain**. Anyone can see it, and it cannot be removed or modified.

### 2. Data read from your wallet

When you connect a wallet, GovTool uses the standard Cardano wallet interfaces ([CIP-30](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0030) and [CIP-95](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0095)) to read, in your browser:

* the network your wallet is connected to,
* your addresses (change, used, unused and reward addresses) and UTxOs,
* your public stake keys (registered and unregistered), and
* your public DRep key, from which your DRep ID is derived.

These are public identifiers, not secrets. GovTool uses them to build transactions for you to sign, and sends your stake key or DRep ID to the GovTool backend to look up your Voting Power, delegation and registration status. GovTool never has access to your private keys, and it cannot move your funds without your signature in your wallet.

### 3. Information you choose to publish

* **DRep information** ([CIP-119](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0119)): the name, objectives, motivations, qualifications, image, links, identity references and payment address you enter when registering or updating as a DRep. GovTool packages this into a file in your browser. **You** host that file at a public URL of your choice, and only the URL and hash are recorded on-chain. The information is public and is shown in the DRep Directory (unless you tick "Do Not List").
* **Governance Action metadata** ([CIP-108](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0108)): the title, abstract, motivation, rationale and references of a Governance Action. You host this file yourself, and it is public.
* **Vote rationale** ("Provide context about your vote"): if you choose "Download and store yourself", you host the file. If you choose "GovTool pins data to IPFS", the text you enter is uploaded by GovTool to the public IPFS network through our pinning provider (Pinata). **Content on IPFS is public and may be impossible to delete**, because other IPFS nodes can keep copies.

When you submit a URL (for example for DRep metadata), GovTool's servers download the content from that URL to check that it matches the hash. The website hosting your file will see a request from GovTool's servers, not from you.

### 4. Proposals and Budget Proposals

The Proposals and Budget Proposals features let you discuss ideas before they go on-chain. To use them:

* **Verification by wallet signature.** You "Verify your identity" by signing a message with your wallet (no transaction, no fee). We store an account linked to your wallet's stake credential. A login token is kept in your browser's session storage, and a session cookie is set to keep you signed in.
* **Display Name.** You choose a public Display Name. It is shown next to your activity and **cannot be changed** once set. You don't need to give an email address or real name.
* **Public content.** Proposals, drafts you submit, comments, likes and dislikes, poll votes and reports are linked to your account. Submitted proposals, comments and poll results are public. DReps who verify their DRep key are shown with a DRep tag, their DRep name and DRep ID.
* **Budget Proposals.** A Budget Proposal asks whether it is submitted on behalf of an individual, a company or another group, and then for details such as the company or group name, company domain, country of incorporation, key information identifying the group, a public proposal champion, and the contact details you choose to share (for example an email address or social media handles). **All of this is displayed publicly** with the proposal, and the form asks you to agree to that before you submit. Budget Proposals made with an earlier version of the form may also hold private contact details of the beneficiary and the submission lead (full name, email address, country of residence and nationality). Those details are **not displayed publicly** and are available only to authorized administrators of the budget process, who may use them to contact you about your proposal.

### 5. Support chat

The **Feedback** button in GovTool opens a support chat (Chatwoot). We receive whatever you choose to write or attach, together with basic technical information such as your browser and the page you were on. Please don't share your seed phrase, private keys or other sensitive information in the chat. We will never ask for them.

### 6. Usage analytics

To understand how GovTool is used and to improve it, we use **Umami** on instances where it is enabled. It records page views without cookies. Requests are sent through GovTool's own servers.

We use analytics data in aggregate. We don't use it to identify you or for advertising.

### 7. Error monitoring and session replay

We use **Sentry** to detect and fix errors and performance problems in the GovTool app and its services. When an error occurs, or for a sample of sessions, Sentry receives technical information such as error details, the page and actions that led to the error, browser and device information, and which wallet extension was used. For a sample of sessions (and for sessions in which an error occurs), Sentry records a **session replay**: a reconstruction of what happened on the page. Replays are configured to mask text and input fields by default. Server-side error reports may include request details such as the requested URL, request headers and the IP address of the request.

### 8. Server logs

Like most websites, GovTool's servers automatically log requests. Logs include your IP address, the date and time, the requested URL, the referring page and your browser's user agent. Because many GovTool API URLs contain public identifiers (for example a stake key or DRep ID), logs may link those identifiers to an IP address. We use logs to operate and secure the service.

### 9. Third-party content

* GovTool loads its font from **Google Fonts**, so your browser connects to Google's servers, which receive your IP address.
* GovTool loads images and files stored on IPFS (for example DRep images) through an **IPFS gateway**, which receives your IP address.
* Some documentation pages embed videos or files from **Loom** and **Google Drive**. When you view those pages, those services receive your IP address and may set their own cookies.

## Cookies and browser storage

GovTool itself does not use cookies to track you across other websites. The following cookies and browser storage are used:

| Name / type | Set by | Purpose |
| --- | --- | --- |
| Chat cookies | Chatwoot | Keeping your support conversation |
| `refreshToken` cookie (httpOnly) | Proposals / Budget Proposals | Keeping you signed in after wallet verification |
| `wallet_data_name`, `wallet_data_stake_key` (local storage) | GovTool | Remembering which wallet and stake key you connected |
| `pending_transaction_*` (local storage) | GovTool | Tracking the status of transactions you submitted |
| Cached network data (local storage), e.g. `protocol_params`, `network_info`, `network_metrics`, `network_total_stake` | GovTool | Faster loading of network information |
| Display preferences (local storage), e.g. banner state, governance action history filters and sort order | GovTool | Remembering your settings |
| `pdfUserJwt` (session storage) | Proposals / Budget Proposals | Your login token for the current session |
| Scroll position and DRep Directory sort seed (session storage) | GovTool | Navigation in the current session |
| Theme preference (local storage) | This documentation site | Remembering light/dark mode |

Local and session storage stay in your browser and are not sent to us automatically. You can clear cookies and browser storage at any time in your browser settings. You can disconnect your wallet in GovTool, and you can block analytics with your browser's privacy settings or a content blocker. GovTool will keep working.

## Why we process data (legal bases)

Where the EU or UK General Data Protection Regulation (GDPR) applies, we rely on the following legal bases:

* **Providing the service** you request, for example showing your Voting Power, building your transactions, or hosting your proposals and comments (performance of a contract, Art. 6(1)(b) GDPR, or our legitimate interest in operating GovTool, Art. 6(1)(f)).
* **Security, error detection and service improvement**, including server logs, error monitoring and aggregate analytics (legitimate interests, Art. 6(1)(f)).
* **Support**: answering your chat messages (performance of a contract or legitimate interests; where you give optional details, your consent, Art. 6(1)(a)).
* **Budget process administration**: using the details in Budget Proposals, including private contact details from earlier versions of the form, to run the budget process and contact you about your proposal (performance of a contract or legitimate interests).
* **Legal obligations**, where we must keep or disclose data by law (Art. 6(1)(c)).

## Who we share data with

We do not sell your personal data and we do not share it for advertising. We share data only:

* with **service providers** who help us run GovTool, under agreements that protect your data. These include hosting and infrastructure providers, Sentry (error monitoring), Pinata (IPFS pinning, only for content you choose to pin), the support chat provider, and an email delivery provider (for Budget Proposal communications),
* with **community builder teams** who develop and maintain GovTool and its pillars, where they need access to operate, secure or fix the service,
* when **required by law**, or to protect the rights, safety and security of our users, Sireto or the public, and
* as part of a reorganization of Sireto, subject to this policy.

Public data (blockchain data, published metadata, public proposals and comments, IPFS content) can be viewed, copied and reused by anyone, including other tools that use GovTool's public APIs.

## International transfers

GovTool is operated by teams and service providers in several countries. Your data may be processed outside your country, including outside the European Economic Area and the UK. Where required, we rely on appropriate safeguards such as the European Commission's standard contractual clauses.

## How long we keep data

* **Blockchain data and IPFS content** are permanent and outside our control.
* **Proposals, comments, poll votes and your Display Name** are kept for as long as the Proposals and Budget Proposals features are operated, because they form part of a public discussion record.
* **Private Budget Proposal contact details** from earlier versions of the form are kept for as long as needed for the budget process and related legal and accounting obligations.
* **Support conversations, server logs, analytics and error monitoring data** are kept only as long as needed for their purpose, after which they are deleted or anonymized.
* **Browser storage** stays on your device until you clear it.

## Security

We use technical and organizational measures to protect data, including encrypted connections (HTTPS), access controls and security reviews of the open-source code. No online service is completely secure. Always check that you are on the genuine GovTool site, and review every transaction in your wallet before you sign it.

To report a security vulnerability, please follow the [GovTool security policy](https://github.com/IntersectMBO/govtool/blob/develop/SECURITY.md).

## Your rights

Depending on where you live, you may have the right to:

* access the personal data we hold about you,
* have inaccurate data corrected,
* have your data deleted,
* object to or restrict certain processing,
* receive your data in a portable format, and
* withdraw consent where we rely on it.

If you are a California resident, you may request access to or deletion of your personal information, and you have the right to opt out of its sale (we do not sell personal information). We will not discriminate against you for exercising your rights.

**Limitations.** We cannot change or delete data recorded on the Cardano blockchain or copied across IPFS, because no one controls those networks. For public discussion content, we may remove or anonymize content linked to your account instead of deleting it, where needed to keep discussion threads understandable.

To exercise your rights, contact us using the details below. We may need to verify that you control the relevant wallet, for example by asking you to sign a message. You also have the right to lodge a complaint with your local data protection authority.

## Children

GovTool is not intended for anyone under 18, and we do not knowingly collect personal data from children. If you believe a child has given us personal data, please contact us and we will delete it.

## Changes to this policy

We may update this policy when GovTool changes, for example when we add or remove an integration. We will change the "Last updated" date above and, for significant changes, give notice in GovTool or on this site. The history of this page is public in the [GovTool repository](https://github.com/IntersectMBO/govtool/commits/develop/docs/docs/legal/privacy-policy.md).

## Contact

For privacy questions or to exercise your rights, contact Sireto at [dataprotection@gov.tools](mailto:dataprotection@gov.tools).

For GovTool bugs or feature requests, see [How to submit a bug](../bugs-or-feature-suggestions/how-to-submit-a-bug.md).
