---
title: cose/SignData.ts
nav_order: 46
parent: Modules
---

## SignData overview

High-level CIP-30 wallet API for message signing and verification.

Implements the DataSignature format used by Cardano wallets.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [API](#api)
  - [signData](#signdata)
  - [verifyData](#verifydata)
- [Types](#types)
  - [SignedMessage (type alias)](#signedmessage-type-alias)

---

# API

## signData

Sign data with a private key using COSE_Sign1.

Implements CIP-30 `api.signData()` specification. Creates a COSE_Sign1 structure with:

- Protected headers: algorithm (EdDSA), address
- Unprotected headers: hashed (false)
- Payload: NOT pre-hashed
- Returns CBOR-encoded COSE_Sign1 and COSE_Key

**Signature**

```ts
export declare const signData: (
  addressHex: string,
  payload: Payload,
  privateKey: PrivateKey.PrivateKey
) => SignedMessage
```

Added in v2.0.0

## verifyData

Verify a COSE_Sign1 signed message.

Validates CIP-30 signatures by verifying:

- Payload matches signed data
- Address matches protected headers
- Algorithm is EdDSA
- Public key hash matches provided key hash
- Ed25519 signature is cryptographically valid

**Signature**

```ts
export declare const verifyData: (
  addressHex: string,
  keyHash: string,
  payload: Payload,
  signedMessage: SignedMessage
) => boolean
```

Added in v2.0.0

# Types

## SignedMessage (type alias)

Signed message result (CIP-30 DataSignature format).

Contains CBOR-encoded COSE_Sign1 (signature) and COSE_Key (public key).

**Signature**

```ts
export type SignedMessage = {
  readonly signature: Uint8Array
  readonly key: Uint8Array
}
```

Added in v2.0.0
