---
title: Unit.ts
nav_order: 180
parent: Modules
---

## Unit overview

---

<h2 class="text-delta">Table of contents</h2>

- [conversions](#conversions)
  - [fromUnit](#fromunit)
  - [toUnit](#tounit)
- [model](#model)
  - [Unit (type alias)](#unit-type-alias)
  - [UnitDetails (interface)](#unitdetails-interface)
- [predicates](#predicates)
  - [isLovelace](#islovelace)
- [schemas](#schemas)
  - [UnitSchema](#unitschema)

---

# conversions

## fromUnit

Parse a Unit string into its components.
Extracts policy ID, asset name, and CIP-67 label if present.

**Signature**

```ts
export declare const fromUnit: (unit: Unit) => UnitDetails
```

Added in v2.0.0

## toUnit

Construct a Unit string from components.
Combines policy ID, optional CIP-67 label, and asset name.

**Signature**

```ts
export declare const toUnit: (
  policyId: PolicyId.PolicyId,
  name?: AssetName.AssetName | string | null,
  label?: number | null
) => Unit
```

Added in v2.0.0

# model

## Unit (type alias)

Unit represents the concatenation of PolicyId and AssetName as a single hex string.
Format: policyId (56 chars) + assetName (0-64 chars)
Special case: "lovelace" represents ADA

**Signature**

```ts
export type Unit = string
```

Added in v2.0.0

## UnitDetails (interface)

Result of parsing a Unit string.

**Signature**

```ts
export interface UnitDetails {
  policyId: PolicyId.PolicyId
  assetName: AssetName.AssetName | null
  name: AssetName.AssetName | null
  label: number | null
}
```

Added in v2.0.0

# predicates

## isLovelace

Check if a value is the special "lovelace" unit.

**Signature**

```ts
export declare const isLovelace: (unit: Unit) => boolean
```

Added in v2.0.0

# schemas

## UnitSchema

Schema for validating Unit strings.

**Signature**

```ts
export declare const UnitSchema: Schema.refine<string, typeof Schema.String>
```

Added in v2.0.0
