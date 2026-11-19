---
title: plutus/Address.ts
nav_order: 88
parent: Modules
---

## Address overview

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [Address](#address)
  - [Address (type alias)](#address-type-alias)
  - [Codec](#codec)

---

# utils

## Address

Plutus Address - Contains payment credential and optional stake credential

**Signature**

```ts
export declare const Address: TSchema.Struct<{
  payment_credential: TSchema.Union<
    readonly (
      | TSchema.Struct<{ readonly VerificationKey: TSchema.Struct<{ readonly hash: TSchema.ByteArray }> }>
      | TSchema.Struct<{ readonly Script: TSchema.Struct<{ readonly hash: TSchema.ByteArray }> }>
    )[]
  >
  stake_credential: TSchema.UndefineOr<
    TSchema.Union<
      readonly (
        | TSchema.Struct<{
            readonly Pointer: TSchema.Struct<{
              readonly slot_number: TSchema.Integer
              readonly transaction_index: TSchema.Integer
              readonly certificate_index: TSchema.Integer
            }>
          }>
        | TSchema.Struct<{
            readonly Inline: TSchema.Struct<{
              readonly credential: TSchema.Union<
                readonly (
                  | TSchema.Struct<{ readonly VerificationKey: TSchema.Struct<{ readonly hash: TSchema.ByteArray }> }>
                  | TSchema.Struct<{ readonly Script: TSchema.Struct<{ readonly hash: TSchema.ByteArray }> }>
                )[]
              >
            }>
          }>
      )[]
    >
  >
}>
```

## Address (type alias)

**Signature**

```ts
export type Address = typeof Address.Type
```

## Codec

**Signature**

```ts
export declare const Codec: {
  toData: (
    a: {
      readonly payment_credential:
        | { readonly VerificationKey: { readonly hash: Uint8Array } }
        | { readonly Script: { readonly hash: Uint8Array } }
      readonly stake_credential:
        | {
            readonly Pointer: {
              readonly slot_number: bigint
              readonly transaction_index: bigint
              readonly certificate_index: bigint
            }
          }
        | {
            readonly Inline: {
              readonly credential:
                | { readonly VerificationKey: { readonly hash: Uint8Array } }
                | { readonly Script: { readonly hash: Uint8Array } }
            }
          }
        | undefined
    },
    overrideOptions?: ParseOptions
  ) => Data.Constr
  fromData: (
    i: Data.Constr,
    overrideOptions?: ParseOptions
  ) => {
    readonly payment_credential:
      | { readonly VerificationKey: { readonly hash: Uint8Array } }
      | { readonly Script: { readonly hash: Uint8Array } }
    readonly stake_credential:
      | {
          readonly Pointer: {
            readonly slot_number: bigint
            readonly transaction_index: bigint
            readonly certificate_index: bigint
          }
        }
      | {
          readonly Inline: {
            readonly credential:
              | { readonly VerificationKey: { readonly hash: Uint8Array } }
              | { readonly Script: { readonly hash: Uint8Array } }
          }
        }
      | undefined
  }
  toCBORHex: (
    a: {
      readonly payment_credential:
        | { readonly VerificationKey: { readonly hash: Uint8Array } }
        | { readonly Script: { readonly hash: Uint8Array } }
      readonly stake_credential:
        | {
            readonly Pointer: {
              readonly slot_number: bigint
              readonly transaction_index: bigint
              readonly certificate_index: bigint
            }
          }
        | {
            readonly Inline: {
              readonly credential:
                | { readonly VerificationKey: { readonly hash: Uint8Array } }
                | { readonly Script: { readonly hash: Uint8Array } }
            }
          }
        | undefined
    },
    overrideOptions?: ParseOptions
  ) => string
  toCBORBytes: (
    a: {
      readonly payment_credential:
        | { readonly VerificationKey: { readonly hash: Uint8Array } }
        | { readonly Script: { readonly hash: Uint8Array } }
      readonly stake_credential:
        | {
            readonly Pointer: {
              readonly slot_number: bigint
              readonly transaction_index: bigint
              readonly certificate_index: bigint
            }
          }
        | {
            readonly Inline: {
              readonly credential:
                | { readonly VerificationKey: { readonly hash: Uint8Array } }
                | { readonly Script: { readonly hash: Uint8Array } }
            }
          }
        | undefined
    },
    overrideOptions?: ParseOptions
  ) => any
  fromCBORHex: (
    i: string,
    overrideOptions?: ParseOptions
  ) => {
    readonly payment_credential:
      | { readonly VerificationKey: { readonly hash: Uint8Array } }
      | { readonly Script: { readonly hash: Uint8Array } }
    readonly stake_credential:
      | {
          readonly Pointer: {
            readonly slot_number: bigint
            readonly transaction_index: bigint
            readonly certificate_index: bigint
          }
        }
      | {
          readonly Inline: {
            readonly credential:
              | { readonly VerificationKey: { readonly hash: Uint8Array } }
              | { readonly Script: { readonly hash: Uint8Array } }
          }
        }
      | undefined
  }
  fromCBORBytes: (
    i: any,
    overrideOptions?: ParseOptions
  ) => {
    readonly payment_credential:
      | { readonly VerificationKey: { readonly hash: Uint8Array } }
      | { readonly Script: { readonly hash: Uint8Array } }
    readonly stake_credential:
      | {
          readonly Pointer: {
            readonly slot_number: bigint
            readonly transaction_index: bigint
            readonly certificate_index: bigint
          }
        }
      | {
          readonly Inline: {
            readonly credential:
              | { readonly VerificationKey: { readonly hash: Uint8Array } }
              | { readonly Script: { readonly hash: Uint8Array } }
          }
        }
      | undefined
  }
}
```
