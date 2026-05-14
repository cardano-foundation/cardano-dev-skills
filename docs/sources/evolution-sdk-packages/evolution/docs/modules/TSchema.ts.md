---
title: TSchema.ts
nav_order: 178
parent: Modules
---

## TSchema overview

---

<h2 class="text-delta">Table of contents</h2>

- [combinators](#combinators)
  - [equivalence](#equivalence)
- [constructors](#constructors)
  - [TaggedStruct](#taggedstruct)
  - [Variant](#variant)
- [schemas](#schemas)
  - [ByteArray](#bytearray)
  - [Integer](#integer)
  - [PlutusData](#plutusdata)
- [utils](#utils)
  - [Array](#array)
  - [Array (interface)](#array-interface)
  - [Boolean](#boolean)
  - [Boolean (interface)](#boolean-interface)
  - [ByteArray (interface)](#bytearray-interface)
  - [Integer (interface)](#integer-interface)
  - [Literal](#literal)
  - [Literal (interface)](#literal-interface)
  - [LiteralOptions (interface)](#literaloptions-interface)
  - [Map](#map)
  - [Map (interface)](#map-interface)
  - [NullOr](#nullor)
  - [NullOr (interface)](#nullor-interface)
  - [PlutusData (interface)](#plutusdata-interface)
  - [Struct](#struct)
  - [Struct (interface)](#struct-interface)
  - [StructOptions (interface)](#structoptions-interface)
  - [Tuple](#tuple)
  - [Tuple (interface)](#tuple-interface)
  - [UndefineOr (interface)](#undefineor-interface)
  - [UndefinedOr](#undefinedor)
  - [Union](#union)
  - [Union (interface)](#union-interface)
  - [compose](#compose)
  - [filter](#filter)
  - [is](#is)

---

# combinators

## equivalence

Creates an equivalence function for a schema that can compare two values for equality.

This leverages Effect Schema's built-in equivalence generation, which creates
optimized equality checks based on the schema structure.

**Signature**

```ts
export declare const equivalence: <A, I, R>(schema: Schema.Schema<A, I, R>) => Equivalence<A>
```

Added in v2.0.0

# constructors

## TaggedStruct

Creates a tagged struct - a shortcut for creating a Struct with a Literal tag field.

This is a convenience helper that makes it easy to create structs with discriminator fields,
commonly used in discriminated unions.

**Signature**

```ts
export declare const TaggedStruct: <
  TagValue extends string,
  Fields extends Schema.Struct.Fields,
  TagField extends string = "_tag"
>(
  tagValue: TagValue,
  fields: Fields,
  options?: StructOptions & { tagField?: TagField }
) => Struct<{ [K in TagField]: Literal<[TagValue]> } & Fields>
```

Added in v2.0.0

## Variant

Creates a variant (tagged union) schema for Aiken-style enum types.

This is a convenience helper that creates properly discriminated TypeScript types
while maintaining single-level CBOR encoding compatible with Aiken.

**Signature**

```ts
export declare const Variant: <const Variants extends Record<PropertyKey, Schema.Struct.Fields>>(
  variants: Variants
) => Union<ReadonlyArray<{ [K in keyof Variants]: Struct<{ readonly [P in K]: Struct<Variants[K]> }> }[keyof Variants]>>
```

Added in v2.0.0

# schemas

## ByteArray

ByteArray schema for PlutusData - runtime Uint8Array, encoded as hex string.

**Signature**

```ts
export declare const ByteArray: ByteArray
```

Added in v2.0.0

## Integer

Integer schema that represents Data.Int for PlutusData.
This enables withSchema compatibility by using the Data type schema directly.

**Signature**

```ts
export declare const Integer: Integer
```

Added in v2.0.0

## PlutusData

Opaque PlutusData schema for use inside TSchema combinators.
Represents an arbitrary PlutusData value that passes through encoding unchanged.

Use this when a field can hold any PlutusData without a specific schema.

**Signature**

```ts
export declare const PlutusData: PlutusData
```

Added in v2.0.0

# utils

## Array

Creates a schema for arrays - just passes through to Schema.Array directly

**Signature**

```ts
export declare const Array: <S extends Schema.Schema.Any>(items: S) => Array<S>
```

Added in v1.0.0

## Array (interface)

**Signature**

```ts
export interface Array<S extends Schema.Schema.Any> extends Schema.Array$<S> {}
```

## Boolean

Schema for boolean values using Plutus Data Constructor

- False with index 0
- True with index 1

**Signature**

```ts
export declare const Boolean: Boolean
```

Added in v2.0.0

## Boolean (interface)

**Signature**

```ts
export interface Boolean
  extends Schema.transform<Schema.SchemaClass<Data.Constr, Data.Constr, never>, typeof Schema.Boolean> {}
```

## ByteArray (interface)

**Signature**

```ts
export interface ByteArray extends Schema.Schema<Uint8Array, Uint8Array, never> {}
```

## Integer (interface)

**Signature**

```ts
export interface Integer extends Schema.SchemaClass<bigint, bigint, never> {}
```

## Literal

Creates a schema for literal types with Plutus Data Constructor transformation

**Signature**

```ts
export declare const Literal: {
  <Literals extends NonEmptyReadonlyArray<Exclude<SchemaAST.LiteralValue, null | bigint>>>(
    ...self: Literals
  ): Literal<Literals>
  <Literals extends NonEmptyReadonlyArray<Exclude<SchemaAST.LiteralValue, null | bigint>>>(
    ...args: [...Literals, LiteralOptions]
  ): Literal<Literals>
}
```

Added in v2.0.0

## Literal (interface)

**Signature**

```ts
export interface Literal<Literals extends NonEmptyReadonlyArray<SchemaAST.LiteralValue>>
  extends Schema.transform<Schema.SchemaClass<Data.Constr, Data.Constr, never>, Schema.Literal<[...Literals]>> {}
```

## LiteralOptions (interface)

Options for Literal schema

**Signature**

```ts
export interface LiteralOptions {
  /**
   * Custom Constr index for this literal (default: auto-incremented from 0)
   * Useful when matching Plutus contract constructor indices
   */
  index?: number
  /**
   * When used in a Union, controls whether this Literal should be "flattened" (unwrapped).
   * - true: Encodes as Constr(index, []) directly
   * - false: Encodes as Constr(unionPos, [Constr(index, [])]) (nested)
   *
   * Default: true when index is specified, false otherwise
   */
  flatInUnion?: boolean
}
```

## Map

Creates a schema for maps with Plutus Map type annotation
Maps are represented as a list of constructor pairs, where each pair
is a constructor with index 0 and fields [key, value]

**Signature**

```ts
export declare const Map: <K extends Schema.Schema.Any, V extends Schema.Schema.Any>(key: K, value: V) => Map<K, V>
```

Added in v1.0.0

## Map (interface)

**Signature**

```ts
export interface Map<K extends Schema.Schema.Any, V extends Schema.Schema.Any>
  extends Schema.transform<
    Schema.SchemaClass<globalThis.Map<Data.Data, Data.Data>, globalThis.Map<Data.Data, Data.Data>, never>,
    Schema.MapFromSelf<K, V>
  > {}
```

## NullOr

Creates a schema for nullable types that transforms to/from Plutus Data Constructor
Represents optional values as:

- Just(value) with index 0
- Nothing with index 1

**Signature**

```ts
export declare const NullOr: <S extends Schema.Schema.All>(self: S) => NullOr<S>
```

Added in v2.0.0

## NullOr (interface)

**Signature**

```ts
export interface NullOr<S extends Schema.Schema.All>
  extends Schema.transform<Schema.SchemaClass<Data.Constr, Data.Constr, never>, Schema.NullOr<S>> {}
```

## PlutusData (interface)

**Signature**

```ts
export interface PlutusData extends Schema.Schema<Data.Data, Data.Data, never> {}
```

## Struct

Creates a schema for struct types using Plutus Data Constructor
Objects are represented as a constructor with index (default 0) and fields as an array

**Signature**

```ts
export declare const Struct: <Fields extends Schema.Struct.Fields>(
  fields: Fields,
  options?: StructOptions
) => Struct<Fields>
```

Added in v2.0.0

## Struct (interface)

**Signature**

```ts
export interface Struct<Fields extends Schema.Struct.Fields>
  extends Schema.transform<Schema.SchemaClass<Data.Constr, Data.Constr, never>, Schema.Struct<Fields>> {}
```

## StructOptions (interface)

Options for Struct schema

**Signature**

```ts
export interface StructOptions {
  /**
   * Custom Constr index for this struct (default: 0)
   * Useful when creating union variants with specific indices
   */
  index?: number
  /**
   * When used in a Union, controls whether this Struct should be "flattened" (unwrapped).
   * - true: Encodes as Constr(index, [fields]) directly
   * - false: Encodes as Constr(unionPos, [Constr(index, [fields])]) (nested)
   *
   * Default: true when index is specified, false otherwise
   */
  flatInUnion?: boolean
  /**
   * When used as a field in a parent Struct, controls whether this Struct's fields
   * should be spread (merged) into the parent's field array.
   * - true: Inner Struct fields are merged directly into parent
   * - false: Inner Struct is kept as a nested Constr
   *
   * Default: false
   *
   * Note: This only applies when the Struct is a field value, not when used in Union.
   */
  flatFields?: boolean
  /**
   * Name of a field to treat as a discriminant tag (e.g., "_tag", "type").
   *
   * Auto-detection: Fields named "_tag", "type", "kind", or "variant" containing
   * Literal values are automatically stripped from CBOR encoding and injected during decoding.
   *
   * This option allows you to:
   * - Explicitly specify a custom tag field name
   * - Disable auto-detection with `tagField: false`
   *
   * Default: auto-detect from KNOWN_TAG_FIELDS
   */
  tagField?: string | false
}
```

## Tuple

Creates a schema for tuple types - just passes through to Schema.Tuple directly

**Signature**

```ts
export declare const Tuple: <Elements extends Schema.TupleType.Elements>(element: [...Elements]) => Tuple<Elements>
```

Added in v2.0.0

## Tuple (interface)

**Signature**

```ts
export interface Tuple<Elements extends Schema.TupleType.Elements> extends Schema.Tuple<Elements> {}
```

## UndefineOr (interface)

**Signature**

```ts
export interface UndefineOr<S extends Schema.Schema.Any>
  extends Schema.transform<Schema.SchemaClass<Data.Constr, Data.Constr, never>, Schema.UndefinedOr<S>> {}
```

## UndefinedOr

Creates a schema for undefined types that transforms to/from Plutus Data Constructor
Represents optional values as:

- Just(value) with index 0
- Nothing with index 1

**Signature**

```ts
export declare const UndefinedOr: <S extends Schema.Schema.Any>(self: S) => UndefineOr<S>
```

Added in v2.0.0

## Union

Creates a schema for union types using Plutus Data Constructor
Unions are represented as a constructor with index 0, 1, 2... and fields as an array

Members marked with flat: true will be encoded directly using their index
instead of being wrapped in an additional Constr layer.

**Signature**

```ts
export declare const Union: <Members extends ReadonlyArray<Schema.Schema.Any>>(...members: Members) => Union<Members>
```

Added in v2.0.0

## Union (interface)

**Signature**

```ts
export interface Union<Members extends ReadonlyArray<Schema.Schema.Any>>
  extends Schema.transformOrFail<
    Schema.SchemaClass<Data.Constr, Data.Constr, never>,
    Schema.SchemaClass<Schema.Schema.Type<Members[number]>, Schema.Schema.Type<Members[number]>, never>,
    never
  > {}
```

## compose

**Signature**

```ts
export declare const compose: {
  <To extends Schema.Schema.Any, From extends Schema.Schema.Any, C extends Schema.Schema.Type<From>>(
    to: To & Schema.Schema<Schema.Schema.Type<To>, C, Schema.Schema.Context<To>>
  ): (from: From) => Schema.transform<From, To>
  <To extends Schema.Schema.Any>(
    to: To
  ): <From extends Schema.Schema.Any, B extends Schema.Schema.Encoded<To>>(
    from: From & Schema.Schema<B, Schema.Schema.Encoded<From>, Schema.Schema.Context<From>>
  ) => Schema.transform<From, To>
  <To extends Schema.Schema.Any>(
    to: To,
    options?: { readonly strict: true }
  ): <From extends Schema.Schema.Any>(
    from: From & Schema.Schema<Schema.Schema.Encoded<To>, Schema.Schema.Encoded<From>, Schema.Schema.Context<From>>
  ) => Schema.transform<From, To>
  <To extends Schema.Schema.Any>(
    to: To,
    options: { readonly strict: false }
  ): <From extends Schema.Schema.Any>(from: From) => Schema.transform<From, To>
  <From extends Schema.Schema.Any, To extends Schema.Schema.Any, C extends Schema.Schema.Type<From>>(
    from: From,
    to: To & Schema.Schema<Schema.Schema.Type<To>, C, Schema.Schema.Context<To>>
  ): Schema.transform<From, To>
  <From extends Schema.Schema.Any, B extends Schema.Schema.Encoded<To>, To extends Schema.Schema.Any>(
    from: From & Schema.Schema<B, Schema.Schema.Encoded<From>, Schema.Schema.Context<From>>,
    to: To
  ): Schema.transform<From, To>
  <From extends Schema.Schema.Any, To extends Schema.Schema.Any>(
    from: From & Schema.Schema<Schema.Schema.Encoded<To>, Schema.Schema.Encoded<From>, Schema.Schema.Context<From>>,
    to: To,
    options?: { readonly strict: true }
  ): Schema.transform<From, To>
  <From extends Schema.Schema.Any, To extends Schema.Schema.Any>(
    from: From,
    to: To,
    options: { readonly strict: false }
  ): Schema.transform<From, To>
}
```

## filter

**Signature**

```ts
export declare const filter: typeof Schema.filter
```

## is

**Signature**

```ts
export declare const is: <A, I, R>(
  schema: Schema.Schema<A, I, R>,
  options?: SchemaAST.ParseOptions
) => (u: unknown, overrideOptions?: SchemaAST.ParseOptions | number) => u is A
```
