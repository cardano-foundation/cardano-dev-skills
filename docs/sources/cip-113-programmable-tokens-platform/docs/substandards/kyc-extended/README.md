# KYC Extended — How it works

A short, non-technical walk-through of the **extended KYC** substandard.

---

## What problem does this solve?

[Basic KYC](../kyc/) checks **senders**. Extended KYC adds the missing half:

> The recipient must also be on a list of verified wallets, otherwise the
> transfer is rejected.

This matches use cases such as travel-rule compliance, RWA tokens with
investor allowlists, or stablecoins restricted to a known counterparty set.

The extension is **purely additive**: every basic-KYC mechanism still applies
unchanged on the sender side.

---

## The participants

- **Issuer** — same as basic KYC.
- **Trusted entities** — same as basic KYC; sign sender certificates.
- **The "allowlist"** — a list of wallets the issuer accepts as valid
  recipients for this token. Maintained by the issuer's backend; anchored on
  chain by a single 32-byte fingerprint.
- **Sender** — needs a sender certificate, exactly as in basic KYC.
- **Receiver** — must be on the allowlist before any transfer to them will
  go through.

---

## The allowlist explained

Maintaining the full allowlist on chain would be expensive and slow.
Instead, the issuer's backend keeps the full list off chain as a
**Merkle Patricia Forestry tree** (think: cryptographic index) and publishes
just its **root fingerprint** on chain. Any change to the list — adding,
removing, or expiring a member — produces a different fingerprint.

When a sender wants to transfer to a recipient, the wallet asks the backend
for a small "inclusion proof" that the recipient is in the tree. The contract
checks that proof against the on-chain fingerprint. If the proof reconstructs
the same fingerprint, the recipient is verified; if not, the transfer fails.

> Implementation: the off-chain tree is in
> [`MpfTreeService.java`](../../../src/programmable-tokens-offchain-java/src/main/java/org/cardanofoundation/cip113/service/MpfTreeService.java).
> The on-chain check is in
> [`kyc_extended_transfer.ak`](../../../src/substandards/kyc-extended/validators/kyc_extended_transfer.ak)
> (`validate_membership` function).

---

## The lifecycle
![Flow diagram](./kyc-extended-flow.png)

### 1. Issuer registers the token

Same as basic KYC, but the on-chain global state has one extra field — the
allowlist's current fingerprint. Initially the fingerprint is the
"empty tree" value (32 zero bytes), meaning nobody is in the allowlist yet.

### 2. A user verifies themselves

A prospective recipient (or the sender themselves) visits the
`/verify/{policyId}` page and goes through the same KYC flow as basic KYC.
When they finish, two things happen automatically:

1. They receive a sender certificate (just like basic KYC), so they can also
   spend this token.
2. The backend adds their wallet to the off-chain allowlist tree.

> Implementation: the verify page is
> [`app/verify/[policyId]/page.tsx`](../../../src/programmable-tokens-frontend/app/verify/[policyId]/page.tsx).
> The auto-add happens in
> [`KeriService.autoUpsertMpfMember`](../../../src/programmable-tokens-offchain-java/src/main/java/org/cardanofoundation/cip113/service/KeriService.java).

### 3. The new fingerprint goes on chain

Adding a member changes the tree's fingerprint, but the change isn't
immediately on chain. A small **autonomous publisher** running inside the
backend wakes up periodically (default: every ~30 seconds), notices the
change, and submits a transaction that updates the on-chain fingerprint with
the issuer's admin key.

The user can use the token as a recipient as soon as the publisher's
transaction is confirmed on chain — typically within a minute.

While waiting, the verify page shows a "Verification submitted, waiting for
on-chain publication…" message and refreshes itself automatically. Sending
to a not-yet-published recipient is blocked client-side, because such a
transfer would be rejected by the chain anyway.

> Implementation: the publisher is
> [`MpfRootSyncJob.java`](../../../src/programmable-tokens-offchain-java/src/main/java/org/cardanofoundation/cip113/scheduling/MpfRootSyncJob.java).
> Its design notes (no-op gating, confirmation polling, submission cooldown)
> are in the file's class-level comment.

### 4. Sender attempts a transfer

The sender's wallet pulls together:
- a sender certificate (same as basic KYC), **and**
- an inclusion proof for the recipient.

It builds the transaction and asks the wallet to sign. The on-chain
validator then verifies, in one go:

1. Every basic-KYC check on the sender (entity is trusted, signature
   verifies, names this sender, certificate not expired, not paused).
2. The recipient is in the allowlist (the inclusion proof matches the
   on-chain fingerprint).
3. The recipient's allowlist entry has not expired.

If anything fails, the chain rejects the transfer.

> Implementation: the wallet-side bundling is in
> [`KycExtendedSubstandardHandler.buildTransferTransaction`](../../../src/programmable-tokens-offchain-java/src/main/java/org/cardanofoundation/cip113/service/substandard/KycExtendedSubstandardHandler.java).
> The on-chain checks are in the `transfer` validator in
> [`kyc_extended_transfer.ak`](../../../src/substandards/kyc-extended/validators/kyc_extended_transfer.ak).

---

## A couple of subtleties worth knowing

### "I'm sending to myself — why no recipient check?"

If you're sending to your own wallet (e.g. moving tokens between addresses),
the contract recognises this and skips the recipient check. Your own
certificate as the sender is enough to authorise it.

### "Why two fingerprints in the API response?"

The inclusion-proof endpoint returns two fingerprints alongside the proof:
the **local** one (what the backend currently knows) and the **on-chain** one
(what the chain currently shows). They normally match. If they differ, it
means the backend has accepted a member but hasn't yet finished publishing
the change on chain. Surfaces that build transactions block in that case;
the verify page shows a "publication pending" notice.

### "What about removing someone from the allowlist?"

The current implementation expires members automatically (each entry has a
TTL — default 30 days) and prunes them on the next publisher tick. A
dedicated revoke-now endpoint is on the roadmap; for today, the issuer can
shorten an entry's TTL by re-adding it with an earlier expiry.

---

## What this substandard does **not** do

- It does **not** restrict *amounts* by recipient — once a recipient is in
  the allowlist they can receive any quantity.
- It does **not** check the recipient's identity at transfer time; the check
  is "are they in the allowlist", not "are they who they say they are".
  Identity verification happens once, when the recipient first joins.
- It does **not** support multiple separate allowlists per token (e.g.
  per-jurisdiction). One token = one allowlist. Issuers needing
  jurisdictional separation should issue separate token policies.

---

## Operational footnotes (for issuers)

- **The publisher needs an online signing key.** The autonomous publisher
  signs root-update transactions automatically, so the admin's signing key
  is loaded at backend startup. That key has full admin authority on the
  global state — keep it on a hardened host.
- **Members expire silently.** A member whose TTL has passed will be pruned
  on the next publisher tick; their next transfer attempt will be blocked
  with an "expired" notice that points them back to the verify page.
- **Re-registration after a contract rebuild.** If the on-chain validator
  bytecode changes (e.g. you rebuild from updated Aiken sources), tokens
  registered with the older bytecode will stop working until re-registered.
  See [`kyc-processes.md`](../../../kyc-processes.md) for the recovery
  procedure.
