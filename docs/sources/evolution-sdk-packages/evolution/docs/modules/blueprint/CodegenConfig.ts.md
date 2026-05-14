---
title: blueprint/CodegenConfig.ts
nav_order: 18
parent: Modules
---

## CodegenConfig overview

Code generation configuration

Added in v2.0.0

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [CodegenConfig (interface)](#codegenconfig-interface)
  - [DEFAULT_CODEGEN_CONFIG](#default_codegen_config)
  - [EmptyConstructorStyle (type alias)](#emptyconstructorstyle-type-alias)
  - [FieldNamingConfig (interface)](#fieldnamingconfig-interface)
  - [ModuleStrategy (type alias)](#modulestrategy-type-alias)
  - [OptionStyle (type alias)](#optionstyle-type-alias)
  - [UnionStyle (type alias)](#unionstyle-type-alias)
  - [createCodegenConfig](#createcodegenconfig)

---

# utils

## CodegenConfig (interface)

Code generation configuration

**Signature**

````ts
export interface CodegenConfig {
  /**
   * How to generate Option<T> types
   * @default "NullOr"
   */
  optionStyle: OptionStyle

  /**
   * How to generate union types with named constructors
   * @default "Variant"
   */
  unionStyle: UnionStyle

  /**
   * Custom field names for Variant constructors when Blueprint has unnamed fields
   * Map from "TypeTitle.ConstructorTitle" to array of field names
   * Example:
   * ```
   * { "Credential.VerificationKey": ["hash"], "Credential.Script": ["hash"] }
   * ```
   */
  variantFieldNames?: Record<string, Array<string>>

  /**
   * How to generate empty constructors
   * @default "Literal"
   */
  emptyConstructorStyle: EmptyConstructorStyle

  /**
   * Field naming configuration
   */
  fieldNaming: FieldNamingConfig

  /**
   * Whether to include index in TSchema constructors
   * @default false
   */
  includeIndex: boolean

  /**
   * Module organization strategy
   * - "flat": Current behavior (CardanoAddressCredential)
   * - "namespaced": Nested namespaces (Cardano.Address.Credential)
   * @default "flat"
   */
  moduleStrategy: ModuleStrategy

  /**
   * Whether to use relative references within same namespace
   * Only applies when moduleStrategy is "namespaced"
   * @default true
   */
  useRelativeRefs: boolean

  /**
   * Explicit import lines for Data, TSchema, and Schema modules
   * e.g. data: 'import { Data } from "@evolution-sdk/evolution/Data"'
   */
  imports: {
    data: string
    tschema: string
    /** Import line for Effect Schema. Used when cyclic types require `Schema.suspend`. */
    schema: string
  }

  /**
   * Indentation to use in generated code
   * @default "  " (2 spaces)
   */
  indent: string
}
````

## DEFAULT_CODEGEN_CONFIG

Default code generation configuration

**Signature**

```ts
export declare const DEFAULT_CODEGEN_CONFIG: CodegenConfig
```

## EmptyConstructorStyle (type alias)

Configuration for how to generate empty constructors

**Signature**

```ts
export type EmptyConstructorStyle =
  | "Literal" // TSchema.Literal("Unit" as const)
  | "Struct"
```

## FieldNamingConfig (interface)

Configuration for field naming in constructors without explicit field names

**Signature**

```ts
export interface FieldNamingConfig {
  /**
   * Name to use for single unnamed field
   * @default "value"
   */
  singleFieldName: string

  /**
   * Pattern to use for multiple unnamed fields
   * @default "field{index}" where {index} is replaced with field number
   */
  multiFieldPattern: string
}
```

## ModuleStrategy (type alias)

Module organization strategy

**Signature**

```ts
export type ModuleStrategy =
  | "flat" // Current: CardanoAddressCredential
  | "namespaced"
```

## OptionStyle (type alias)

Configuration for how to generate optional types `(Option<T>)`

**Signature**

```ts
export type OptionStyle =
  | "NullOr" // TSchema.NullOr(T)
  | "UndefinedOr" // TSchema.UndefinedOr(T)
  | "Union"
```

## UnionStyle (type alias)

Configuration for how to generate union types with named constructors

**Signature**

```ts
export type UnionStyle =
  | "Variant" // TSchema.Variant({ Tag1: { ... }, Tag2: { ... } }) — compact sugar
  | "Struct" // TSchema.Union(TSchema.Struct({ Tag1: TSchema.Struct({...}) }), ...) — verbose, same encoding as Variant
  | "TaggedStruct"
```

## createCodegenConfig

Create a custom codegen configuration by merging with defaults

**Signature**

```ts
export declare function createCodegenConfig(config: Partial<CodegenConfig> = {}): CodegenConfig
```
