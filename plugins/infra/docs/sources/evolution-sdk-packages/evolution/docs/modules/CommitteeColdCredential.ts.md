---
title: CommitteeColdCredential.ts
nav_order: 38
parent: Modules
---

## CommitteeColdCredential overview

Committee Cold Credential module - provides an alias for Credential specialized for committee cold key usage.

In Cardano, committee_cold_credential = credential, representing the same credential structure
but used specifically for committee cold keys in governance.

Implements CIP-129 bech32 encoding with "cc_cold" prefix.

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [encoding](#encoding)
  - [toBech32](#tobech32)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [parsing](#parsing)
  - [fromBech32](#frombech32)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [transformations](#transformations)
  - [FromBech32](#frombech32-1)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)
- [utils](#utils)
  - [CommitteeColdCredential](#committeecoldcredential)

---

# encoding

## toBech32

Encode Committee Cold Credential to Bech32 string (CIP-129 format).

**Signature**

```ts
export declare const toBech32: (a: KeyHash.KeyHash | ScriptHash.ScriptHash, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

## toBytes

Encode Committee Cold Credential to CIP-129 bytes.

**Signature**

```ts
export declare const toBytes: (a: KeyHash.KeyHash | ScriptHash.ScriptHash, overrideOptions?: ParseOptions) => any
```

Added in v2.0.0

## toHex

Encode Committee Cold Credential to hex string.

**Signature**

```ts
export declare const toHex: (a: KeyHash.KeyHash | ScriptHash.ScriptHash, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# parsing

## fromBech32

Parse Committee Cold Credential from Bech32 string (CIP-129 format).

**Signature**

```ts
export declare const fromBech32: (i: string, overrideOptions?: ParseOptions) => KeyHash.KeyHash | ScriptHash.ScriptHash
```

Added in v2.0.0

## fromBytes

Parse Committee Cold Credential from CIP-129 bytes.

**Signature**

```ts
export declare const fromBytes: (i: any, overrideOptions?: ParseOptions) => KeyHash.KeyHash | ScriptHash.ScriptHash
```

Added in v2.0.0

## fromHex

Parse Committee Cold Credential from hex string.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => KeyHash.KeyHash | ScriptHash.ScriptHash
```

Added in v2.0.0

# transformations

## FromBech32

Transform from Bech32 string to Committee Cold Credential following CIP-129.
Bech32 prefix: "cc_cold" for both KeyHash and ScriptHash

**Signature**

```ts
export declare const FromBech32: Schema.transformOrFail<
  typeof Schema.String,
  Schema.SchemaClass<KeyHash.KeyHash | ScriptHash.ScriptHash, KeyHash.KeyHash | ScriptHash.ScriptHash, never>,
  never
>
```

Added in v2.0.0

## FromBytes

Transform from CIP-129 bytes (29 bytes) to Committee Cold Credential.
Format: [header_byte(1)][credential_bytes(28)]
Header byte for cc_cold:

- 0x1C = KeyHash (bits: 0001 1100 = key type 0x01, cred type 0x0C)
- 0x1D = ScriptHash (bits: 0001 1101 = key type 0x01, cred type 0x0D)

**Signature**

```ts
export declare const FromBytes: Schema.transformOrFail<
  typeof Schema.Uint8ArrayFromSelf,
  Schema.SchemaClass<KeyHash.KeyHash | ScriptHash.ScriptHash, KeyHash.KeyHash | ScriptHash.ScriptHash, never>,
  never
>
```

Added in v2.0.0

## FromHex

Transform from hex string to Committee Cold Credential.

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.SchemaClass<KeyHash.KeyHash | ScriptHash.ScriptHash, KeyHash.KeyHash | ScriptHash.ScriptHash, never>,
    never
  >
>
```

Added in v2.0.0

# utils

## CommitteeColdCredential

**Signature**

```ts
export declare const CommitteeColdCredential: typeof Credential
```
