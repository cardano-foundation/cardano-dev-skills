---
title: Address.ts
nav_order: 1
parent: Modules
---

## Address overview

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [Arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [Functions](#functions)
  - [fromBech32](#frombech32)
  - [fromSeed](#fromseed)
- [Model](#model)
  - [AddressDetails (interface)](#addressdetails-interface)
- [Schema](#schema)
  - [Address (class)](#address-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [Transformations](#transformations)
  - [FromBech32](#frombech32-1)
  - [FromBytes](#frombytes)
  - [FromHex](#fromhex)
- [Utils](#utils)
  - [getAddressDetails](#getaddressdetails)
  - [getNetworkId](#getnetworkid)
  - [getPaymentCredential](#getpaymentcredential)
  - [getStakingCredential](#getstakingcredential)
  - [hasStakingCredential](#hasstakingcredential)
  - [isEnterprise](#isenterprise)
- [predicates](#predicates)
  - [isScript](#isscript)
- [utils](#utils-1)
  - [fromBytes](#frombytes-1)
  - [fromHex](#fromhex-1)
  - [toBech32](#tobech32)
  - [toBytes](#tobytes)
  - [toHex](#tohex)

---

# Arbitrary

## arbitrary

FastCheck arbitrary generator for testing

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<Address>
```

Added in v2.0.0

# Functions

## fromBech32

Sync functions using Schema utilities

**Signature**

```ts
export declare const fromBech32: (i: string, overrideOptions?: ParseOptions) => Address
```

Added in v2.0.0

## fromSeed

Derive an address from a BIP-39 seed phrase.

Pure, synchronous key derivation — no network access or running cluster required.
Useful for generating addresses before a devnet cluster starts (e.g. for genesis funding).

**Signature**

```ts
export declare const fromSeed: (
  seed: string,
  options?: { password?: string; addressType?: "Base" | "Enterprise"; accountIndex?: number; networkId?: number }
) => Address
```

**Example**

```typescript
import * as Address from "@evolution-sdk/evolution/Address"

const address = Address.fromSeed(
  "test test test test test test test test test test test test test test test test test test test test test test test sauce",
  {
    accountIndex: 0,
    networkId: 0 // 0 = testnet, 1 = mainnet
  }
)
const hex = Address.toHex(address)
```

Added in v2.1.0

# Model

## AddressDetails (interface)

Address details with both structured and serialized formats

**Signature**

```ts
export interface AddressDetails {
  readonly type: "Base" | "Enterprise"
  readonly networkId: NetworkId.NetworkId
  readonly address: {
    readonly bech32: string
    readonly hex: string
  }
  readonly paymentCredential: Credential.Credential
  readonly stakingCredential?: Credential.Credential
}
```

Added in v2.0.0

# Schema

## Address (class)

**Signature**

```ts
export declare class Address
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

# Transformations

## FromBech32

Transform from Bech32 string to AddressStructure

**Signature**

```ts
export declare const FromBech32: Schema.transformOrFail<
  typeof Schema.String,
  Schema.SchemaClass<Address, Address, never>,
  never
>
```

Added in v2.0.0

## FromBytes

Transform from bytes to AddressStructure
Handles both BaseAddress (57 bytes) and EnterpriseAddress (29 bytes)

**Signature**

```ts
export declare const FromBytes: Schema.transformOrFail<
  Schema.Union<[Schema.SchemaClass<Uint8Array, Uint8Array, never>, Schema.SchemaClass<Uint8Array, Uint8Array, never>]>,
  Schema.SchemaClass<Address, Address, never>,
  never
>
```

Added in v2.0.0

## FromHex

Transform from hex string to AddressStructure

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transformOrFail<
    Schema.Union<
      [Schema.SchemaClass<Uint8Array, Uint8Array, never>, Schema.SchemaClass<Uint8Array, Uint8Array, never>]
    >,
    Schema.SchemaClass<Address, Address, never>,
    never
  >
>
```

Added in v2.0.0

# Utils

## getAddressDetails

Parse address from bech32 or hex string and extract all details
Returns undefined if the address cannot be parsed

Supports:

- Base addresses (payment + staking credentials)
- Enterprise addresses (payment credential only)

**Signature**

```ts
export declare const getAddressDetails: (address: string) => AddressDetails | undefined
```

**Example**

```typescript
import * as Address from "@evolution-sdk/evolution/Address"

const details = Address.getAddressDetails("addr_test1qp...")
if (details) {
  console.log(details.type) // "Base" | "Enterprise"
  console.log(details.networkId) // 0 | 1
  console.log(details.paymentCredential)
  console.log(details.stakingCredential) // present for Base addresses
}
```

Added in v2.0.0

## getNetworkId

Get network ID from AddressStructure

**Signature**

```ts
export declare const getNetworkId: (address: Address) => NetworkId.NetworkId
```

Added in v2.0.0

## getPaymentCredential

Extract payment credential from address string
Returns undefined if the address cannot be parsed

**Signature**

```ts
export declare const getPaymentCredential: (address: string) => Credential.Credential | undefined
```

Added in v2.0.0

## getStakingCredential

Extract staking credential from address string
Returns undefined if the address has no staking credential or cannot be parsed

**Signature**

```ts
export declare const getStakingCredential: (address: string) => Credential.Credential | undefined
```

Added in v2.0.0

## hasStakingCredential

Check if AddressStructure has staking credential (BaseAddress-like)

**Signature**

```ts
export declare const hasStakingCredential: (address: Address) => boolean
```

Added in v2.0.0

## isEnterprise

Check if AddressStructure is enterprise-like (no staking credential)

**Signature**

```ts
export declare const isEnterprise: (address: Address) => boolean
```

Added in v2.0.0

# predicates

## isScript

Check if address has a script payment credential.

**Signature**

```ts
export declare const isScript: (address: Address) => boolean
```

Added in v2.0.0

# utils

## fromBytes

**Signature**

```ts
export declare const fromBytes: (i: Uint8Array, overrideOptions?: ParseOptions) => Address
```

## fromHex

**Signature**

```ts
export declare const fromHex: (i: string, overrideOptions?: ParseOptions) => Address
```

## toBech32

**Signature**

```ts
export declare const toBech32: (a: Address, overrideOptions?: ParseOptions) => string
```

## toBytes

**Signature**

```ts
export declare const toBytes: (a: Address, overrideOptions?: ParseOptions) => Uint8Array
```

## toHex

**Signature**

```ts
export declare const toHex: (a: Address, overrideOptions?: ParseOptions) => string
```
