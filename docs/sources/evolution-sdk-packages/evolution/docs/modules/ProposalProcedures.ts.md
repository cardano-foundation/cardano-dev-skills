---
title: ProposalProcedures.ts
nav_order: 106
parent: Modules
---

## ProposalProcedures overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [helpers](#helpers)
  - [single](#single)
- [model](#model)
  - [ProposalProcedures (class)](#proposalprocedures-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
- [schemas](#schemas)
  - [CDDLSchema](#cddlschema)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORHex](#fromcborhex-1)
  - [FromCDDL](#fromcddl)

---

# arbitrary

## arbitrary

FastCheck arbitrary for ProposalProcedures.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<ProposalProcedures>
```

Added in v2.0.0

# encoding

## toCBORBytes

Encode ProposalProcedures to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (data: ProposalProcedures, options?: CBOR.CodecOptions) => any
```

Added in v2.0.0

## toCBORHex

Encode ProposalProcedures to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (data: ProposalProcedures, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# helpers

## single

Create ProposalProcedures for a single proposal.

Convenience function for the common case of submitting one governance action.

**Signature**

```ts
export declare const single: (
  deposit: Coin.Coin,
  rewardAccount: RewardAccount.RewardAccount,
  governanceAction: GovernanceAction.GovernanceAction,
  anchor: Anchor.Anchor | null
) => ProposalProcedures
```

Added in v2.0.0

# model

## ProposalProcedures (class)

ProposalProcedures based on Conway CDDL specification.

```
CDDL: proposal_procedures = nonempty_set<proposal_procedure>
```

**Signature**

```ts
export declare class ProposalProcedures
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

# parsing

## fromCBORBytes

Parse ProposalProcedures from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => ProposalProcedures
```

Added in v2.0.0

## fromCBORHex

Parse ProposalProcedures from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => ProposalProcedures
```

Added in v2.0.0

# schemas

## CDDLSchema

CDDL schema for ProposalProcedures that produces CBOR-compatible types.

**Signature**

```ts
export declare const CDDLSchema: Schema.Array$<
  Schema.Tuple<
    [
      typeof Schema.BigIntFromSelf,
      typeof Schema.Uint8ArrayFromSelf,
      Schema.SchemaClass<
        | readonly [0n, readonly [any, bigint] | null, ReadonlyMap<bigint, CBOR.CBOR>, any]
        | readonly [1n, readonly [any, bigint] | null, readonly [bigint, bigint]]
        | readonly [2n, ReadonlyMap<any, bigint>, any]
        | readonly [3n, readonly [any, bigint] | null]
        | readonly [
            4n,
            readonly [any, bigint] | null,
            (
              | readonly (readonly [0n | 1n, any])[]
              | { readonly _tag: "Tag"; readonly tag: 258; readonly value: readonly (readonly [0n | 1n, any])[] }
            ),
            ReadonlyMap<readonly [0n | 1n, any], bigint>,
            { readonly _tag: "Tag"; readonly tag: 30; readonly value: readonly [bigint, bigint] }
          ]
        | readonly [5n, readonly [any, bigint] | null, readonly [readonly [string, any], any]]
        | readonly [6n],
        | readonly [0n, readonly [any, bigint] | null, ReadonlyMap<bigint, CBOR.CBOR>, any]
        | readonly [1n, readonly [any, bigint] | null, readonly [bigint, bigint]]
        | readonly [2n, ReadonlyMap<any, bigint>, any]
        | readonly [3n, readonly [any, bigint] | null]
        | readonly [
            4n,
            readonly [any, bigint] | null,
            (
              | readonly (readonly [0n | 1n, any])[]
              | { readonly _tag: "Tag"; readonly tag: 258; readonly value: readonly (readonly [0n | 1n, any])[] }
            ),
            ReadonlyMap<readonly [0n | 1n, any], bigint>,
            { readonly _tag: "Tag"; readonly tag: 30; readonly value: readonly [bigint, bigint] }
          ]
        | readonly [5n, readonly [any, bigint] | null, readonly [readonly [string, any], any]]
        | readonly [6n],
        never
      >,
      Schema.NullOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
    ]
  >
>
```

Added in v2.0.0

## FromCBORBytes

CBOR bytes transformation schema for ProposalProcedures.

**Signature**

```ts
export declare const FromCBORBytes: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
    never
  >,
  Schema.transformOrFail<
    Schema.Array$<
      Schema.Tuple<
        [
          typeof Schema.BigIntFromSelf,
          typeof Schema.Uint8ArrayFromSelf,
          Schema.SchemaClass<
            | readonly [0n, readonly [any, bigint] | null, ReadonlyMap<bigint, CBOR.CBOR>, any]
            | readonly [1n, readonly [any, bigint] | null, readonly [bigint, bigint]]
            | readonly [2n, ReadonlyMap<any, bigint>, any]
            | readonly [3n, readonly [any, bigint] | null]
            | readonly [
                4n,
                readonly [any, bigint] | null,
                (
                  | readonly (readonly [0n | 1n, any])[]
                  | { readonly _tag: "Tag"; readonly tag: 258; readonly value: readonly (readonly [0n | 1n, any])[] }
                ),
                ReadonlyMap<readonly [0n | 1n, any], bigint>,
                { readonly _tag: "Tag"; readonly tag: 30; readonly value: readonly [bigint, bigint] }
              ]
            | readonly [5n, readonly [any, bigint] | null, readonly [readonly [string, any], any]]
            | readonly [6n],
            | readonly [0n, readonly [any, bigint] | null, ReadonlyMap<bigint, CBOR.CBOR>, any]
            | readonly [1n, readonly [any, bigint] | null, readonly [bigint, bigint]]
            | readonly [2n, ReadonlyMap<any, bigint>, any]
            | readonly [3n, readonly [any, bigint] | null]
            | readonly [
                4n,
                readonly [any, bigint] | null,
                (
                  | readonly (readonly [0n | 1n, any])[]
                  | { readonly _tag: "Tag"; readonly tag: 258; readonly value: readonly (readonly [0n | 1n, any])[] }
                ),
                ReadonlyMap<readonly [0n | 1n, any], bigint>,
                { readonly _tag: "Tag"; readonly tag: 30; readonly value: readonly [bigint, bigint] }
              ]
            | readonly [5n, readonly [any, bigint] | null, readonly [readonly [string, any], any]]
            | readonly [6n],
            never
          >,
          Schema.NullOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
        ]
      >
    >,
    Schema.SchemaClass<ProposalProcedures, ProposalProcedures, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for ProposalProcedures.

**Signature**

```ts
export declare const FromCBORHex: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transform<
    Schema.transformOrFail<
      typeof Schema.Uint8ArrayFromSelf,
      Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
      never
    >,
    Schema.transformOrFail<
      Schema.Array$<
        Schema.Tuple<
          [
            typeof Schema.BigIntFromSelf,
            typeof Schema.Uint8ArrayFromSelf,
            Schema.SchemaClass<
              | readonly [0n, readonly [any, bigint] | null, ReadonlyMap<bigint, CBOR.CBOR>, any]
              | readonly [1n, readonly [any, bigint] | null, readonly [bigint, bigint]]
              | readonly [2n, ReadonlyMap<any, bigint>, any]
              | readonly [3n, readonly [any, bigint] | null]
              | readonly [
                  4n,
                  readonly [any, bigint] | null,
                  (
                    | readonly (readonly [0n | 1n, any])[]
                    | { readonly _tag: "Tag"; readonly tag: 258; readonly value: readonly (readonly [0n | 1n, any])[] }
                  ),
                  ReadonlyMap<readonly [0n | 1n, any], bigint>,
                  { readonly _tag: "Tag"; readonly tag: 30; readonly value: readonly [bigint, bigint] }
                ]
              | readonly [5n, readonly [any, bigint] | null, readonly [readonly [string, any], any]]
              | readonly [6n],
              | readonly [0n, readonly [any, bigint] | null, ReadonlyMap<bigint, CBOR.CBOR>, any]
              | readonly [1n, readonly [any, bigint] | null, readonly [bigint, bigint]]
              | readonly [2n, ReadonlyMap<any, bigint>, any]
              | readonly [3n, readonly [any, bigint] | null]
              | readonly [
                  4n,
                  readonly [any, bigint] | null,
                  (
                    | readonly (readonly [0n | 1n, any])[]
                    | { readonly _tag: "Tag"; readonly tag: 258; readonly value: readonly (readonly [0n | 1n, any])[] }
                  ),
                  ReadonlyMap<readonly [0n | 1n, any], bigint>,
                  { readonly _tag: "Tag"; readonly tag: 30; readonly value: readonly [bigint, bigint] }
                ]
              | readonly [5n, readonly [any, bigint] | null, readonly [readonly [string, any], any]]
              | readonly [6n],
              never
            >,
            Schema.NullOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
          ]
        >
      >,
      Schema.SchemaClass<ProposalProcedures, ProposalProcedures, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL transformation schema for ProposalProcedures.

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.Array$<
    Schema.Tuple<
      [
        typeof Schema.BigIntFromSelf,
        typeof Schema.Uint8ArrayFromSelf,
        Schema.SchemaClass<
          | readonly [0n, readonly [any, bigint] | null, ReadonlyMap<bigint, CBOR.CBOR>, any]
          | readonly [1n, readonly [any, bigint] | null, readonly [bigint, bigint]]
          | readonly [2n, ReadonlyMap<any, bigint>, any]
          | readonly [3n, readonly [any, bigint] | null]
          | readonly [
              4n,
              readonly [any, bigint] | null,
              (
                | readonly (readonly [0n | 1n, any])[]
                | { readonly _tag: "Tag"; readonly tag: 258; readonly value: readonly (readonly [0n | 1n, any])[] }
              ),
              ReadonlyMap<readonly [0n | 1n, any], bigint>,
              { readonly _tag: "Tag"; readonly tag: 30; readonly value: readonly [bigint, bigint] }
            ]
          | readonly [5n, readonly [any, bigint] | null, readonly [readonly [string, any], any]]
          | readonly [6n],
          | readonly [0n, readonly [any, bigint] | null, ReadonlyMap<bigint, CBOR.CBOR>, any]
          | readonly [1n, readonly [any, bigint] | null, readonly [bigint, bigint]]
          | readonly [2n, ReadonlyMap<any, bigint>, any]
          | readonly [3n, readonly [any, bigint] | null]
          | readonly [
              4n,
              readonly [any, bigint] | null,
              (
                | readonly (readonly [0n | 1n, any])[]
                | { readonly _tag: "Tag"; readonly tag: 258; readonly value: readonly (readonly [0n | 1n, any])[] }
              ),
              ReadonlyMap<readonly [0n | 1n, any], bigint>,
              { readonly _tag: "Tag"; readonly tag: 30; readonly value: readonly [bigint, bigint] }
            ]
          | readonly [5n, readonly [any, bigint] | null, readonly [readonly [string, any], any]]
          | readonly [6n],
          never
        >,
        Schema.NullOr<Schema.Tuple2<typeof Schema.String, typeof Schema.Uint8ArrayFromSelf>>
      ]
    >
  >,
  Schema.SchemaClass<ProposalProcedures, ProposalProcedures, never>,
  never
>
```

Added in v2.0.0
