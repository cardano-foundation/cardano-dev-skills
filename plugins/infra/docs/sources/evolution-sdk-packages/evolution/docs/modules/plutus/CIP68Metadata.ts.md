---
title: plutus/CIP68Metadata.ts
nav_order: 89
parent: Modules
---

## CIP68Metadata overview

CIP-68 Datum Metadata Standard for NFTs and tokens

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [CIP68Datum](#cip68datum)
  - [CIP68Datum (type alias)](#cip68datum-type-alias)
  - [Codec](#codec)
  - [FT_TOKEN_LABEL](#ft_token_label)
  - [NFT_TOKEN_LABEL](#nft_token_label)
  - [REFERENCE_TOKEN_LABEL](#reference_token_label)
  - [RFT_TOKEN_LABEL](#rft_token_label)

---

# utils

## CIP68Datum

CIP-68 Datum Structure

datum = Constr(0, [metadata, version, extra])

- metadata: Arbitrary PlutusData - structure varies by token class:
  - 222 (NFT): Map with name, image, description, files (CIP-25 structure)
  - 333 (FT): Map with name, description, ticker, url, decimals, logo
  - 444 (RFT): Map combining NFT + FT fields plus decimals
- version: 1, 2, or 3 depending on token class
- extra: Custom plutus data (minimum Unit/Void)

**Signature**

```ts
export declare const CIP68Datum: TSchema.Struct<{
  metadata: Schema.SchemaClass<Data.Data, Data.Data, never>
  version: TSchema.Integer
  extra: TSchema.Array<Schema.SchemaClass<Data.Data, Data.Data, never>>
}>
```

## CIP68Datum (type alias)

**Signature**

```ts
export type CIP68Datum = typeof CIP68Datum.Type
```

## Codec

**Signature**

```ts
export declare const Codec: {
  toData: (
    a: { readonly version: bigint; readonly metadata: Data.Data; readonly extra: readonly Data.Data[] },
    overrideOptions?: ParseOptions
  ) => Data.Constr
  fromData: (
    i: Data.Constr,
    overrideOptions?: ParseOptions
  ) => { readonly version: bigint; readonly metadata: Data.Data; readonly extra: readonly Data.Data[] }
  toCBORHex: (
    a: { readonly version: bigint; readonly metadata: Data.Data; readonly extra: readonly Data.Data[] },
    overrideOptions?: ParseOptions
  ) => string
  toCBORBytes: (
    a: { readonly version: bigint; readonly metadata: Data.Data; readonly extra: readonly Data.Data[] },
    overrideOptions?: ParseOptions
  ) => any
  fromCBORHex: (
    i: string,
    overrideOptions?: ParseOptions
  ) => { readonly version: bigint; readonly metadata: Data.Data; readonly extra: readonly Data.Data[] }
  fromCBORBytes: (
    i: any,
    overrideOptions?: ParseOptions
  ) => { readonly version: bigint; readonly metadata: Data.Data; readonly extra: readonly Data.Data[] }
}
```

## FT_TOKEN_LABEL

CIP-68 FT (Fungible Token) Label (333 in hex)

**Signature**

```ts
export declare const FT_TOKEN_LABEL: 333
```

## NFT_TOKEN_LABEL

CIP-68 NFT Token Label (222 in hex)

**Signature**

```ts
export declare const NFT_TOKEN_LABEL: 222
```

## REFERENCE_TOKEN_LABEL

CIP-68 Reference Token Label (100 in hex)

**Signature**

```ts
export declare const REFERENCE_TOKEN_LABEL: 100
```

## RFT_TOKEN_LABEL

CIP-68 RFT (Rich Fungible Token) Label (444 in hex)

**Signature**

```ts
export declare const RFT_TOKEN_LABEL: 444
```
