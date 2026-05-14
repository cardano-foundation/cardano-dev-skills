---
title: ByronAddress.ts
nav_order: 22
parent: Modules
---

## ByronAddress overview

---

<h2 class="text-delta">Table of contents</h2>

- [schemas](#schemas)
  - [ByronAddress (class)](#byronaddress-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
  - [BytesSchema](#bytesschema)
  - [FromHex](#fromhex)

---

# schemas

## ByronAddress (class)

Byron legacy address format

**Signature**

```ts
export declare class ByronAddress
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

## BytesSchema

Schema for encoding/decoding Byron addresses as bytes.

**Signature**

```ts
export declare const BytesSchema: Schema.transformOrFail<typeof Schema.Uint8ArrayFromSelf, typeof ByronAddress, never>
```

Added in v2.0.0

## FromHex

Schema for encoding/decoding Byron addresses as hex strings.

**Signature**

```ts
export declare const FromHex: Schema.transform<
  Schema.Schema<Uint8Array, string, never>,
  Schema.transformOrFail<typeof Schema.Uint8ArrayFromSelf, typeof ByronAddress, never>
>
```

Added in v2.0.0
