# KYC — How it works

A short, non-technical walk-through of the **basic KYC** module.

![Flow diagram](./kyc-flow.png)

---

## What problem does this solve?

When an issuer mints a token under regulatory obligations, they often need a
guarantee that **whoever spends the token has been identified**. Basic KYC
adds exactly that one rule:

> Every transfer must carry a fresh, signed certificate proving that the
> sender has been verified.

Receivers are not checked. The receiver-side check is the job of the
[kyc-extended](../kyc-extended/) module.

---

## The participants

- **Issuer** — the company minting the token. Decides who is trusted to
  perform KYC checks on their behalf.
- **Trusted entity** — a regulated KYC provider (e.g. an identity verifier,
  a vLEI issuer). The issuer publishes the entity's signing key on chain so
  the contract can recognise its signatures.
- **Sender** — the wallet trying to spend the token. Must obtain a
  certificate from a trusted entity before the spend will succeed.
- **Receiver** — the wallet receiving the token. No KYC required for basic
  KYC.

---

## The lifecycle

### 1. Issuer registers the token

When the issuer creates the token, they also create a small piece of on-chain
state called the **global state UTxO**. It holds:

- a list of **trusted KYC entities** (their signing keys),
- a flag to pause all transfers in an emergency,
- a cap on how many tokens may still be minted,
- arbitrary compliance metadata (left to the issuer's legal team).

The issuer can update each of these later with their admin key.

> Implementation: [`KycModuleHandler.buildGlobalStateInitTransaction`](../../../src/programmable-tokens-offchain-java/src/main/java/org/cardanofoundation/cip113/service/module/KycModuleHandler.java)
> creates this initial state.

### 2. Sender goes through KYC

Before the sender can spend, they go through a normal identity-verification
flow with one of the trusted entities. This happens **off chain** — the
sender shows their documents, the entity does its checks.

When verification succeeds, the entity signs a tiny "certificate" containing:
- who the sender is (their wallet identity, 28 bytes),
- a role byte the issuer is free to use,
- an expiry date.

The certificate is short-lived — typically 30 days. After it expires the
sender has to re-verify.

> Implementation: the certificate format is defined in the
> [transfer validator](../../../src/modules/kyc/validators/kyc_transfer.ak)
> as `KycProof`. The frontend flow that walks the user through verification
> lives in [`KycVerificationFlow.tsx`](../../../src/programmable-tokens-frontend/components/transfer/KycVerificationFlow.tsx).

### 3. Sender attempts a transfer

When the sender hits "Send", the wallet attaches the signed certificate to
the transaction. The on-chain validator then checks, for every spending
input the sender controls:

1. Is the signing entity in the issuer's trusted list?
2. Does the signature on the certificate verify?
3. Does the certificate name **this sender** (not someone else)?
4. Is the certificate still valid (the transaction's deadline must be on or
   before the certificate's expiry)?
5. Is the issuer not currently pausing all transfers?

If all five hold, the transfer goes through. If any one fails, the chain
rejects the transaction.

> Implementation: the on-chain check is `validate_kyc_proof` in
> [`kyc_transfer.ak`](../../../src/modules/kyc/validators/kyc_transfer.ak)
> (60-line function). The wallet-side bundling lives in
> [`KycModuleHandler.buildTransferTransaction`](../../../src/programmable-tokens-offchain-java/src/main/java/org/cardanofoundation/cip113/service/module/KycModuleHandler.java).

### 4. The certificate is cached

Once obtained, the sender's certificate is cached client-side until it
expires, so subsequent transfers within the validity window don't re-trigger
the full KYC flow. The cache is **bound to the wallet** — switching wallets
in the same browser does not surface another wallet's certificate.

> Implementation: [`kyc-cookie.ts`](../../../src/programmable-tokens-frontend/lib/utils/kyc-cookie.ts).

---

## Day-to-day operations

Once the token is live, the issuer can:

- **Add or remove trusted entities** — e.g. onboarding a new KYC provider,
  rotating a compromised signing key. Single admin-signed transaction.
- **Pause transfers** — emergency brake; while set, every transfer fails.
- **Update the mintable cap** — change how many more tokens may be minted.
- **Change compliance metadata** — opaque to the contract; useful for
  off-chain auditors.

> Implementation: each of these is a separate "spend action" on the global
> state UTxO. They live in `KycModuleHandler.build…Transaction` methods
> in the same file as the registration.

---

## What this module does **not** do

- It does **not** check who receives the token. The receiver could be
  anyone.
- It does **not** revoke certificates retroactively. A leaked certificate
  remains valid until it expires (so issuers should keep the validity window
  short and rotate keys on suspected compromise).
- It does **not** care about the role byte in the certificate — issuers can
  use it for off-chain analytics but the contract treats it as opaque.

If you need the receiver to be checked too, see [kyc-extended](../kyc-extended/).
