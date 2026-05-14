---
title: PrivateKey.ts
nav_order: 104
parent: Modules
---

## PrivateKey overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [bip32](#bip32)
  - [~~derive~~](#derive)
- [bip39](#bip39)
  - [~~fromMnemonic~~](#frommnemonic)
  - [generateMnemonic](#generatemnemonic)
  - [validateMnemonic](#validatemnemonic)
- [cardano](#cardano)
  - [~~CardanoPath~~](#cardanopath)
  - [fromMnemonicCardano](#frommnemoniccardano)
- [cryptography](#cryptography)
  - [sign](#sign)
  - [toPublicKey](#topublickey)
- [effect](#effect)
  - [Either (namespace)](#either-namespace)
- [encoding](#encoding)
  - [toBech32](#tobech32)
  - [toBytes](#tobytes)
  - [toHex](#tohex)
- [errors](#errors)
  - [PrivateKeyError (class)](#privatekeyerror-class)
    - [\_tag (property)](#_tag-property)
- [generators](#generators)
  - [generate](#generate)
  - [generateExtended](#generateextended)
- [parsing](#parsing)
  - [fromBech32](#frombech32)
  - [fromBytes](#frombytes)
  - [fromHex](#fromhex)
- [schemas](#schemas)
  - [PrivateKey (class)](#privatekey-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [utils](#utils)
  - [FromBech32](#frombech32-1)
  - [FromBytes](#frombytes-1)
  - [FromHex](#fromhex-1)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random PrivateKey instances.
Generates 32-byte private keys.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<PrivateKey>
```

Added in v2.0.0

# bip32

## ~~derive~~

Derive a child private key using BIP32 path (sync version that throws PrivateKeyError).

**WARNING**: This uses secp256k1 BIP32 derivation (`@scure/bip32`), NOT Cardano's
BIP32-Ed25519. For Cardano key derivation, use `fromMnemonicCardano` instead.

**Signature**

```ts
export declare const derive: (privateKey: PrivateKey, path: string) => PrivateKey
```

Added in v2.0.0

# bip39

## ~~fromMnemonic~~

Create a PrivateKey from a mnemonic phrase (sync version that throws PrivateKeyError).

**WARNING**: This uses secp256k1 BIP32 derivation (`@scure/bip32`), NOT Cardano's
BIP32-Ed25519. For Cardano key derivation, use `fromMnemonicCardano` instead.

**Signature**

```ts
export declare const fromMnemonic: (mnemonic: string, password?: string) => PrivateKey
```

Added in v2.0.0

## generateMnemonic

Generate a new mnemonic phrase using BIP39.

**Signature**

```ts
export declare const generateMnemonic: (strength?: 128 | 160 | 192 | 224 | 256) => string
```

Added in v2.0.0

## validateMnemonic

Validate a mnemonic phrase using BIP39.

**Signature**

```ts
export declare const validateMnemonic: (mnemonic: string) => boolean
```

Added in v2.0.0

# cardano

## ~~CardanoPath~~

Cardano BIP44 derivation path utilities.

**WARNING**: These paths are only useful with BIP32-Ed25519 derivation
(`Bip32PrivateKey`). Using them with `derive` (which uses secp256k1 BIP32)
will produce incorrect keys. Use `fromMnemonicCardano` or
`Bip32PrivateKey.CardanoPath` instead.

**Signature**

```ts
export declare const CardanoPath: {
  create: (account?: number, role?: 0 | 2, index?: number) => string
  payment: (account?: number, index?: number) => string
  stake: (account?: number, index?: number) => string
}
```

Added in v2.0.0

## fromMnemonicCardano

Derive a Cardano payment or stake key from a mnemonic using BIP32-Ed25519.

This is the correct way to derive Cardano keys from a mnemonic. It uses the
Icarus/V2 BIP32-Ed25519 derivation scheme, matching CML and cardano-cli behavior.

**Signature**

```ts
export declare const fromMnemonicCardano: (
  mnemonic: string,
  options?: { account?: number; role?: 0 | 2; index?: number; password?: string }
) => PrivateKey
```

**Example**

```ts
import * as PrivateKey from "@evolution-sdk/evolution/PrivateKey"

const mnemonic = PrivateKey.generateMnemonic()

// Payment key (default: account 0, index 0)
const paymentKey = PrivateKey.fromMnemonicCardano(mnemonic)

// Stake key
const stakeKey = PrivateKey.fromMnemonicCardano(mnemonic, { role: 2 })

// Custom account/index
const key = PrivateKey.fromMnemonicCardano(mnemonic, { account: 1, index: 3 })
```

Added in v2.0.0

# cryptography

## sign

Sign a message using Ed25519 (sync version that throws PrivateKeyError).
All errors are normalized to PrivateKeyError with contextual information.
For extended keys (64 bytes), uses CML-compatible Ed25519-BIP32 signing.
For normal keys (32 bytes), uses standard Ed25519 signing.

**Signature**

```ts
export declare const sign: (privateKey: PrivateKey, message: Uint8Array) => Ed25519Signature.Ed25519Signature
```

Added in v2.0.0

## toPublicKey

Derive the public key (VKey) from a private key.
Compatible with CML privateKey.to_public().

**Signature**

```ts
export declare const toPublicKey: (privateKey: PrivateKey) => VKey.VKey
```

Added in v2.0.0

# effect

## Either (namespace)

Effect-based error handling variants for functions that can fail.

Added in v2.0.0

# encoding

## toBech32

Convert a PrivateKey to a Bech32 string.
Automatically selects the appropriate prefix based on key length:

- 32 bytes → ed25519_sk1... (normal key)
- 64 bytes → ed25519e_sk1... (extended key)
  Compatible with CML.PrivateKey.to_bech32().

**Signature**

```ts
export declare const toBech32: (a: PrivateKey, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

## toBytes

Convert a PrivateKey to raw bytes.

**Signature**

```ts
export declare const toBytes: (a: PrivateKey, overrideOptions?: ParseOptions) => Uint8Array
```

Added in v2.0.0

## toHex

Convert a PrivateKey to a hex string.

**Signature**

```ts
export declare const toHex: (a: PrivateKey, overrideOptions?: ParseOptions) => string
```

Added in v2.0.0

# errors

## PrivateKeyError (class)

Error class for PrivateKey operations

**Signature**

```ts
export declare class PrivateKeyError {
  constructor(message: string)
}
```

Added in v2.0.0

### \_tag (property)

**Signature**

```ts
readonly _tag: "PrivateKeyError"
```

# generators

## generate

Generate a random 32-byte Ed25519 private key.
Compatible with CML.PrivateKey.generate_ed25519().

**Signature**

```ts
export declare const generate: () => Uint8Array
```

Added in v2.0.0

## generateExtended

Generate a random 64-byte extended Ed25519 private key.
Compatible with CML.PrivateKey.generate_ed25519extended().

**Signature**

```ts
export declare const generateExtended: () => Uint8Array
```

Added in v2.0.0

# parsing

## fromBech32

Parse a PrivateKey from a Bech32 string.
Supports both extended (ed25519e_sk1...) and normal (ed25519_sk1...) formats.
Compatible with CML.PrivateKey.from_bech32().

**Signature**

```ts
export declare const fromBech32: (i: string, overrideOptions?: ParseOptions) => PrivateKey
```

Added in v2.0.0

## fromBytes

Parse a PrivateKey from raw bytes.
Supports both 32-byte and 64-byte private keys.

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => PrivateKey
```

Added in v2.0.0

## fromHex

Parse a PrivateKey from a hex string.
Supports both 32-byte (64 chars) and 64-byte (128 chars) hex strings.

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => PrivateKey
```

Added in v2.0.0

# schemas

## PrivateKey (class)

Schema for PrivateKey representing an Ed25519 private key.
Supports both standard 32-byte and CIP-0003 extended 64-byte formats.
Follows the Conway-era CDDL specification with CIP-0003 compatibility.

**Signature**

```ts
export declare class PrivateKey
```

Added in v2.0.0

### toJSON (method)

**Signature**

```ts
toJSON()
```

### toString (method)

**Signature**

```ts
toString(): string
```

### [Inspectable.NodeInspectSymbol] (method)

**Signature**

```ts
[Inspectable.NodeInspectSymbol](): unknown
```

### [Equal.symbol] (method)

**Signature**

```ts
[Equal.symbol](that: unknown): boolean
```

### [Hash.symbol] (method)

**Signature**

```ts
[Hash.symbol](): number
```

# utils

## FromBech32

**Signature**

```ts
export declare const FromBech32: Schema.transformOrFail<
  typeof Schema.String,
  Schema.SchemaClass<PrivateKey, PrivateKey, never>,
  never
>
```

## FromBytes

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  Schema.SchemaClass<Uint8Array, Uint8Array, never>,
  Schema.SchemaClass<PrivateKey, PrivateKey, never>
>
```

## FromHex

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transform<Schema.SchemaClass<Uint8Array, Uint8Array, never>, Schema.SchemaClass<PrivateKey, PrivateKey, never>>
>
```
