---
title: plutus/Value.ts
nav_order: 92
parent: Modules
---

## Value overview

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [AssetName](#assetname)
  - [AssetName (type alias)](#assetname-type-alias)
  - [AssetNameCodec](#assetnamecodec)
  - [AssetsMap](#assetsmap)
  - [AssetsMap (type alias)](#assetsmap-type-alias)
  - [Codec](#codec)
  - [Lovelace](#lovelace)
  - [Lovelace (type alias)](#lovelace-type-alias)
  - [LovelaceCodec](#lovelacecodec)
  - [PolicyId](#policyid)
  - [PolicyId (type alias)](#policyid-type-alias)
  - [PolicyIdCodec](#policyidcodec)
  - [Value](#value)
  - [Value (type alias)](#value-type-alias)

---

# utils

## AssetName

Asset Name - Token name within a policy

**Signature**

```ts
export declare const AssetName: TSchema.ByteArray
```

## AssetName (type alias)

**Signature**

```ts
export type AssetName = typeof AssetName.Type
```

## AssetNameCodec

**Signature**

```ts
export declare const AssetNameCodec: {
  toData: (a: Uint8Array, overrideOptions?: ParseOptions) => Uint8Array
  fromData: (i: Uint8Array, overrideOptions?: ParseOptions) => Uint8Array
  toCBORHex: (a: Uint8Array, overrideOptions?: ParseOptions) => string
  toCBORBytes: (a: Uint8Array, overrideOptions?: ParseOptions) => any
  fromCBORHex: (i: string, overrideOptions?: ParseOptions) => Uint8Array
  fromCBORBytes: (i: any, overrideOptions?: ParseOptions) => Uint8Array
}
```

## AssetsMap

Assets Map - Map of AssetName to quantity

**Signature**

```ts
export declare const AssetsMap: TSchema.Map<TSchema.ByteArray, TSchema.Integer>
```

## AssetsMap (type alias)

**Signature**

```ts
export type AssetsMap = typeof AssetsMap.Type
```

## Codec

**Signature**

```ts
export declare const Codec: {
  toData: (a: Map<Uint8Array, Map<Uint8Array, bigint>>, overrideOptions?: ParseOptions) => Map<Data.Data, Data.Data>
  fromData: (i: Map<Data.Data, Data.Data>, overrideOptions?: ParseOptions) => Map<Uint8Array, Map<Uint8Array, bigint>>
  toCBORHex: (a: Map<Uint8Array, Map<Uint8Array, bigint>>, overrideOptions?: ParseOptions) => string
  toCBORBytes: (a: Map<Uint8Array, Map<Uint8Array, bigint>>, overrideOptions?: ParseOptions) => any
  fromCBORHex: (i: string, overrideOptions?: ParseOptions) => Map<Uint8Array, Map<Uint8Array, bigint>>
  fromCBORBytes: (i: any, overrideOptions?: ParseOptions) => Map<Uint8Array, Map<Uint8Array, bigint>>
}
```

## Lovelace

Lovelace - ADA in lovelace (1 ADA = 1,000,000 lovelace)

**Signature**

```ts
export declare const Lovelace: TSchema.Integer
```

## Lovelace (type alias)

**Signature**

```ts
export type Lovelace = typeof Lovelace.Type
```

## LovelaceCodec

**Signature**

```ts
export declare const LovelaceCodec: {
  toData: (a: bigint, overrideOptions?: ParseOptions) => bigint
  fromData: (i: bigint, overrideOptions?: ParseOptions) => bigint
  toCBORHex: (a: bigint, overrideOptions?: ParseOptions) => string
  toCBORBytes: (a: bigint, overrideOptions?: ParseOptions) => any
  fromCBORHex: (i: string, overrideOptions?: ParseOptions) => bigint
  fromCBORBytes: (i: any, overrideOptions?: ParseOptions) => bigint
}
```

## PolicyId

Policy ID (28 bytes script hash)

**Signature**

```ts
export declare const PolicyId: TSchema.ByteArray
```

## PolicyId (type alias)

**Signature**

```ts
export type PolicyId = typeof PolicyId.Type
```

## PolicyIdCodec

**Signature**

```ts
export declare const PolicyIdCodec: {
  toData: (a: Uint8Array, overrideOptions?: ParseOptions) => Uint8Array
  fromData: (i: Uint8Array, overrideOptions?: ParseOptions) => Uint8Array
  toCBORHex: (a: Uint8Array, overrideOptions?: ParseOptions) => string
  toCBORBytes: (a: Uint8Array, overrideOptions?: ParseOptions) => any
  fromCBORHex: (i: string, overrideOptions?: ParseOptions) => Uint8Array
  fromCBORBytes: (i: any, overrideOptions?: ParseOptions) => Uint8Array
}
```

## Value

Value - Map of PolicyId to AssetsMap
Represents multi-asset value including native tokens

**Signature**

```ts
export declare const Value: TSchema.Map<TSchema.ByteArray, TSchema.Map<TSchema.ByteArray, TSchema.Integer>>
```

## Value (type alias)

**Signature**

```ts
export type Value = typeof Value.Type
```
