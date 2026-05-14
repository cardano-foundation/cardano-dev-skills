---
title: plutus/Credential.ts
nav_order: 90
parent: Modules
---

## Credential overview

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [Credential](#credential)
  - [Credential (type alias)](#credential-type-alias)
  - [CredentialCodec](#credentialcodec)
  - [PaymentCredential](#paymentcredential)
  - [PaymentCredential (type alias)](#paymentcredential-type-alias)
  - [PaymentCredentialCodec](#paymentcredentialcodec)
  - [ScriptHash](#scripthash)
  - [ScriptHash (type alias)](#scripthash-type-alias)
  - [ScriptHashCodec](#scripthashcodec)
  - [StakeCredential](#stakecredential)
  - [StakeCredential (type alias)](#stakecredential-type-alias)
  - [StakeCredentialCodec](#stakecredentialcodec)
  - [VerificationKeyHash](#verificationkeyhash)
  - [VerificationKeyHash (type alias)](#verificationkeyhash-type-alias)
  - [VerificationKeyHashCodec](#verificationkeyhashcodec)

---

# utils

## Credential

Credential - Either a verification key hash or script hash

**Signature**

```ts
export declare const Credential: TSchema.Union<
  readonly (
    | TSchema.Struct<{ readonly VerificationKey: TSchema.Struct<{ readonly hash: TSchema.ByteArray }> }>
    | TSchema.Struct<{ readonly Script: TSchema.Struct<{ readonly hash: TSchema.ByteArray }> }>
  )[]
>
```

## Credential (type alias)

**Signature**

```ts
export type Credential = typeof Credential.Type
```

## CredentialCodec

**Signature**

```ts
export declare const CredentialCodec: {
  toData: (
    a: { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } },
    overrideOptions?: ParseOptions
  ) => Data.Constr
  fromData: (
    i: Data.Constr,
    overrideOptions?: ParseOptions
  ) => { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } }
  toCBORHex: (
    a: { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } },
    overrideOptions?: ParseOptions
  ) => string
  toCBORBytes: (
    a: { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } },
    overrideOptions?: ParseOptions
  ) => any
  fromCBORHex: (
    i: string,
    overrideOptions?: ParseOptions
  ) => { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } }
  fromCBORBytes: (
    i: any,
    overrideOptions?: ParseOptions
  ) => { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } }
}
```

## PaymentCredential

Payment Credential - Used for payment addresses

**Signature**

```ts
export declare const PaymentCredential: TSchema.Union<
  readonly (
    | TSchema.Struct<{ readonly VerificationKey: TSchema.Struct<{ readonly hash: TSchema.ByteArray }> }>
    | TSchema.Struct<{ readonly Script: TSchema.Struct<{ readonly hash: TSchema.ByteArray }> }>
  )[]
>
```

## PaymentCredential (type alias)

**Signature**

```ts
export type PaymentCredential = typeof PaymentCredential.Type
```

## PaymentCredentialCodec

**Signature**

```ts
export declare const PaymentCredentialCodec: {
  toData: (
    a: { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } },
    overrideOptions?: ParseOptions
  ) => Data.Constr
  fromData: (
    i: Data.Constr,
    overrideOptions?: ParseOptions
  ) => { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } }
  toCBORHex: (
    a: { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } },
    overrideOptions?: ParseOptions
  ) => string
  toCBORBytes: (
    a: { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } },
    overrideOptions?: ParseOptions
  ) => any
  fromCBORHex: (
    i: string,
    overrideOptions?: ParseOptions
  ) => { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } }
  fromCBORBytes: (
    i: any,
    overrideOptions?: ParseOptions
  ) => { readonly VerificationKey: { readonly hash: Uint8Array } } | { readonly Script: { readonly hash: Uint8Array } }
}
```

## ScriptHash

Script Hash (28 bytes)

**Signature**

```ts
export declare const ScriptHash: TSchema.ByteArray
```

## ScriptHash (type alias)

**Signature**

```ts
export type ScriptHash = typeof ScriptHash.Type
```

## ScriptHashCodec

**Signature**

```ts
export declare const ScriptHashCodec: {
  toData: (a: Uint8Array, overrideOptions?: ParseOptions) => Uint8Array
  fromData: (i: Uint8Array, overrideOptions?: ParseOptions) => Uint8Array
  toCBORHex: (a: Uint8Array, overrideOptions?: ParseOptions) => string
  toCBORBytes: (a: Uint8Array, overrideOptions?: ParseOptions) => any
  fromCBORHex: (i: string, overrideOptions?: ParseOptions) => Uint8Array
  fromCBORBytes: (i: any, overrideOptions?: ParseOptions) => Uint8Array
}
```

## StakeCredential

Stake Credential - Either inline credential or pointer

**Signature**

```ts
export declare const StakeCredential: TSchema.Union<
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
```

## StakeCredential (type alias)

**Signature**

```ts
export type StakeCredential = typeof StakeCredential.Type
```

## StakeCredentialCodec

**Signature**

```ts
export declare const StakeCredentialCodec: {
  toData: (
    a:
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
        },
    overrideOptions?: ParseOptions
  ) => Data.Constr
  fromData: (
    i: Data.Constr,
    overrideOptions?: ParseOptions
  ) =>
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
  toCBORHex: (
    a:
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
        },
    overrideOptions?: ParseOptions
  ) => string
  toCBORBytes: (
    a:
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
        },
    overrideOptions?: ParseOptions
  ) => any
  fromCBORHex: (
    i: string,
    overrideOptions?: ParseOptions
  ) =>
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
  fromCBORBytes: (
    i: any,
    overrideOptions?: ParseOptions
  ) =>
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
}
```

## VerificationKeyHash

Verification Key Hash (28 bytes)

**Signature**

```ts
export declare const VerificationKeyHash: TSchema.ByteArray
```

## VerificationKeyHash (type alias)

**Signature**

```ts
export type VerificationKeyHash = typeof VerificationKeyHash.Type
```

## VerificationKeyHashCodec

**Signature**

```ts
export declare const VerificationKeyHashCodec: {
  toData: (a: Uint8Array, overrideOptions?: ParseOptions) => Uint8Array
  fromData: (i: Uint8Array, overrideOptions?: ParseOptions) => Uint8Array
  toCBORHex: (a: Uint8Array, overrideOptions?: ParseOptions) => string
  toCBORBytes: (a: Uint8Array, overrideOptions?: ParseOptions) => any
  fromCBORHex: (i: string, overrideOptions?: ParseOptions) => Uint8Array
  fromCBORBytes: (i: any, overrideOptions?: ParseOptions) => Uint8Array
}
```
