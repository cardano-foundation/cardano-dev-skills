---
title: ScriptRef.ts
nav_order: 117
parent: Modules
---

## ScriptRef overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [encoding](#encoding)
  - [toBytes](#tobytes)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
  - [toHex](#tohex)
- [parsing](#parsing)
  - [fromBytes](#frombytes)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
  - [fromHex](#fromhex)
- [schemas](#schemas)
  - [FromBytes](#frombytes-1)
  - [FromCBORBytes](#fromcborbytes-1)
  - [FromCBORHex](#fromcborhex-1)
  - [FromCDDL](#fromcddl)
  - [FromHex](#fromhex-1)
  - [ScriptRef (class)](#scriptref-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
- [utils](#utils)
  - [CDDLSchema](#cddlschema)

---

# arbitrary

## arbitrary

FastCheck arbitrary for generating random ScriptRef instances.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<ScriptRef>
```

Added in v2.0.0

# encoding

## toBytes

Encode ScriptRef to bytes.

**Signature**

```ts
export declare const toBytes: (data: ScriptRef) => any
```

Added in v2.0.0

## toCBORBytes

Encode ScriptRef to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (data: ScriptRef, options?: CBOR.CodecOptions) => any
```

Added in v2.0.0

## toCBORHex

Encode ScriptRef to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (data: ScriptRef, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

## toHex

Encode ScriptRef to hex string.

**Signature**

```ts
export declare const toHex: (data: ScriptRef) => string
```

Added in v2.0.0

# parsing

## fromBytes

Parse ScriptRef from bytes.

**Signature**

```ts
export declare const fromBytes: (bytes: Uint8Array) => ScriptRef
```

Added in v2.0.0

## fromCBORBytes

Parse ScriptRef from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => ScriptRef
```

Added in v2.0.0

## fromCBORHex

Parse ScriptRef from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => ScriptRef
```

Added in v2.0.0

## fromHex

Parse ScriptRef from hex string.

**Signature**

```ts
export declare const fromHex: (hex: string) => ScriptRef
```

Added in v2.0.0

# schemas

## FromBytes

Schema for transforming from bytes to ScriptRef.

**Signature**

```ts
export declare const FromBytes: Schema.transform<
  typeof Schema.Uint8ArrayFromSelf,
  Schema.SchemaClass<ScriptRef, ScriptRef, never>
>
```

Added in v2.0.0

## FromCBORBytes

/\*\*
CBOR bytes transformation schema for ScriptRef.

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
    Schema.TaggedStruct<"Tag", { tag: Schema.Literal<[24]>; value: typeof Schema.Uint8ArrayFromSelf }>,
    Schema.SchemaClass<ScriptRef, ScriptRef, never>,
    never
  >
>
```

Added in v2.0.0

## FromCBORHex

CBOR hex transformation schema for ScriptRef.

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
      Schema.TaggedStruct<"Tag", { tag: Schema.Literal<[24]>; value: typeof Schema.Uint8ArrayFromSelf }>,
      Schema.SchemaClass<ScriptRef, ScriptRef, never>,
      never
    >
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for ScriptRef following the Conway specification.

```
script_ref = #6.24(bytes .cbor script)
```

This transforms between CBOR tag 24 structure and ScriptRef model.

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.TaggedStruct<"Tag", { tag: Schema.Literal<[24]>; value: typeof Schema.Uint8ArrayFromSelf }>,
  Schema.SchemaClass<ScriptRef, ScriptRef, never>,
  never
>
```

Added in v2.0.0

## FromHex

Schema for transforming from hex to ScriptRef.

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transform<typeof Schema.Uint8ArrayFromSelf, Schema.SchemaClass<ScriptRef, ScriptRef, never>>
>
```

Added in v2.0.0

## ScriptRef (class)

Schema for ScriptRef representing a reference to a script in a transaction output.

```
CDDL: script_ref = #6.24(bytes .cbor script)
```

This represents the CBOR-encoded script bytes.
The script_ref uses CBOR tag 24 to indicate it contains CBOR-encoded script data.

**Signature**

```ts
export declare class ScriptRef
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

## CDDLSchema

**Signature**

```ts
export declare const CDDLSchema: Schema.TaggedStruct<
  "Tag",
  { tag: Schema.Literal<[24]>; value: typeof Schema.Uint8ArrayFromSelf }
>
```
