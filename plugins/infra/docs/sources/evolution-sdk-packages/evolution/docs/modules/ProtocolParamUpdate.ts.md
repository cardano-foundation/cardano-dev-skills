---
title: ProtocolParamUpdate.ts
nav_order: 107
parent: Modules
---

## ProtocolParamUpdate overview

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [CDDLSchema](#cddlschema)
  - [CDDLSchema (type alias)](#cddlschema-type-alias)
  - [DRepVotingThresholds (class)](#drepvotingthresholds-class)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
  - [ExUnitPrices (class)](#exunitprices-class)
    - [[Equal.symbol] (method)](#equalsymbol-method-1)
    - [[Hash.symbol] (method)](#hashsymbol-method-1)
  - [ExUnitPricesCDDL](#exunitpricescddl)
  - [ExUnits (class)](#exunits-class)
    - [[Equal.symbol] (method)](#equalsymbol-method-2)
    - [[Hash.symbol] (method)](#hashsymbol-method-2)
  - [ExUnitsCDDL](#exunitscddl)
  - [FromCBORBytes](#fromcborbytes)
  - [FromCBORHex](#fromcborhex)
  - [FromCDDL](#fromcddl)
  - [PoolVotingThresholds (class)](#poolvotingthresholds-class)
    - [[Equal.symbol] (method)](#equalsymbol-method-3)
    - [[Hash.symbol] (method)](#hashsymbol-method-3)
  - [PoolVotingThresholdsCDDL](#poolvotingthresholdscddl)
  - [ProtocolParamUpdate (class)](#protocolparamupdate-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method-4)
    - [[Hash.symbol] (method)](#hashsymbol-method-4)
  - [arbitrary](#arbitrary)
  - [fromCBOR](#fromcbor)
  - [fromCBORBytes](#fromcborbytes-1)
  - [fromCBORHex](#fromcborhex-1)
  - [toCBOR](#tocbor)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)

---

# utils

## CDDLSchema

ProtocolParamUpdate CDDL record with optional fields keyed by indexes.
Mirrors Conway CDDL `protocol_param_update`.

**Signature**

```ts
export declare const CDDLSchema: Schema.MapFromSelf<
  typeof Schema.BigIntFromSelf,
  Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>
>
```

## CDDLSchema (type alias)

**Signature**

```ts
export type CDDLSchema = typeof CDDLSchema.Type
```

## DRepVotingThresholds (class)

drep_voting_thresholds (domain) = [10 unit_intervals]

**Signature**

```ts
export declare class DRepVotingThresholds
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

## ExUnitPrices (class)

ex_unit_prices (domain) = [mem_price : NonnegativeInterval, step_price : NonnegativeInterval]

**Signature**

```ts
export declare class ExUnitPrices
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

## ExUnitPricesCDDL

**Signature**

```ts
export declare const ExUnitPricesCDDL: Schema.Tuple2<
  typeof NonnegativeInterval.NonnegativeInterval,
  typeof NonnegativeInterval.NonnegativeInterval
>
```

## ExUnits (class)

ex_units = [mem : uint, steps : uint]

**Signature**

```ts
export declare class ExUnits
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

## ExUnitsCDDL

**Signature**

```ts
export declare const ExUnitsCDDL: Schema.Tuple2<
  Schema.refine<bigint, typeof Schema.BigInt>,
  Schema.refine<bigint, typeof Schema.BigInt>
>
```

## FromCBORBytes

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
    Schema.MapFromSelf<typeof Schema.BigIntFromSelf, Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>>,
    Schema.SchemaClass<ProtocolParamUpdate, ProtocolParamUpdate, never>,
    never
  >
>
```

## FromCBORHex

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
      Schema.MapFromSelf<typeof Schema.BigIntFromSelf, Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>>,
      Schema.SchemaClass<ProtocolParamUpdate, ProtocolParamUpdate, never>,
      never
    >
  >
>
```

## FromCDDL

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.MapFromSelf<typeof Schema.BigIntFromSelf, Schema.Schema<CBOR.CBOR, CBOR.CBOR, never>>,
  Schema.SchemaClass<ProtocolParamUpdate, ProtocolParamUpdate, never>,
  never
>
```

## PoolVotingThresholds (class)

pool_voting_thresholds (domain) = [u,u,u,u,u] (5 unit_intervals)

**Signature**

```ts
export declare class PoolVotingThresholds
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

## PoolVotingThresholdsCDDL

**Signature**

```ts
export declare const PoolVotingThresholdsCDDL: Schema.Tuple<
  [
    typeof UnitInterval.UnitInterval,
    typeof UnitInterval.UnitInterval,
    typeof UnitInterval.UnitInterval,
    typeof UnitInterval.UnitInterval,
    typeof UnitInterval.UnitInterval
  ]
>
```

## ProtocolParamUpdate (class)

Convenience domain class mirroring the same structure.

**Signature**

```ts
export declare class ProtocolParamUpdate
```

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

## arbitrary

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<ProtocolParamUpdate>
```

## fromCBOR

**Signature**

```ts
export declare const fromCBOR: (bytes: Uint8Array, options?: CBOR.CodecOptions) => ProtocolParamUpdate
```

## fromCBORBytes

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => ProtocolParamUpdate
```

## fromCBORHex

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => ProtocolParamUpdate
```

## toCBOR

**Signature**

```ts
export declare const toCBOR: (data: ProtocolParamUpdate, options?: CBOR.CodecOptions) => any
```

## toCBORBytes

**Signature**

```ts
export declare const toCBORBytes: (data: ProtocolParamUpdate, options?: CBOR.CodecOptions) => any
```

## toCBORHex

**Signature**

```ts
export declare const toCBORHex: (data: ProtocolParamUpdate, options?: CBOR.CodecOptions) => string
```
