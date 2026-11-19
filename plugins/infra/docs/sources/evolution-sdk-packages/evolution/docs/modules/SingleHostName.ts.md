---
title: SingleHostName.ts
nav_order: 162
parent: Modules
---

## SingleHostName overview

---

<h2 class="text-delta">Table of contents</h2>

- [constructors](#constructors)
  - [withPort](#withport)
  - [withoutPort](#withoutport)
- [encoding](#encoding)
  - [toCBORBytes](#tocborbytes)
  - [toCBORHex](#tocborhex)
- [generators](#generators)
  - [generator](#generator)
- [model](#model)
  - [SingleHostName (class)](#singlehostname-class)
    - [toJSON (method)](#tojson-method)
    - [toString (method)](#tostring-method)
    - [[Inspectable.NodeInspectSymbol] (method)](#inspectablenodeinspectsymbol-method)
    - [[Equal.symbol] (method)](#equalsymbol-method)
    - [[Hash.symbol] (method)](#hashsymbol-method)
    - [toCBORBytes (method)](#tocborbytes-method)
    - [toCBORHex (method)](#tocborhex-method)
    - [[Symbol.for("nodejs.util.inspect.custom")] (method)](#symbolfornodejsutilinspectcustom-method)
- [parsing](#parsing)
  - [fromCBORBytes](#fromcborbytes)
  - [fromCBORHex](#fromcborhex)
- [predicates](#predicates)
  - [hasPort](#hasport)
- [schemas](#schemas)
  - [FromBytes](#frombytes)
  - [FromCDDL](#fromcddl)
  - [FromHex](#fromhex)
- [testing](#testing)
  - [arbitrary](#arbitrary)
- [transformation](#transformation)
  - [getDnsName](#getdnsname)
  - [getPort](#getport)

---

# constructors

## withPort

Create a SingleHostName with a port.

**Signature**

```ts
export declare const withPort: (port: Port.Port, dnsName: DnsName.DnsName) => SingleHostName
```

Added in v2.0.0

## withoutPort

Create a SingleHostName without a port.

**Signature**

```ts
export declare const withoutPort: (dnsName: DnsName.DnsName) => SingleHostName
```

Added in v2.0.0

# encoding

## toCBORBytes

Convert a SingleHostName to CBOR bytes.

**Signature**

```ts
export declare const toCBORBytes: (data: SingleHostName, options?: CBOR.CodecOptions) => any
```

Added in v2.0.0

## toCBORHex

Convert a SingleHostName to CBOR hex string.

**Signature**

```ts
export declare const toCBORHex: (data: SingleHostName, options?: CBOR.CodecOptions) => string
```

Added in v2.0.0

# generators

## generator

Generate a random SingleHostName.

**Signature**

```ts
export declare const generator: FastCheck.Arbitrary<SingleHostName>
```

Added in v2.0.0

# model

## SingleHostName (class)

Schema for SingleHostName representing a network host with DNS name.
single_host_name = (1, port/ nil, dns_name)

Used for A or AAAA DNS records.

**Signature**

```ts
export declare class SingleHostName
```

Added in v2.0.0

### toJSON (method)

Convert to JSON-serializable format.
Relies on Option's built-in toJSON() for port serialization.
Converts bigint port values to strings for JSON compatibility.

**Signature**

```ts
toJSON()
```

Added in v2.0.0

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

### toCBORBytes (method)

Convert to CBOR bytes.

**Signature**

```ts
toCBORBytes(): Uint8Array
```

Added in v2.0.0

### toCBORHex (method)

Convert to CBOR hex string.

**Signature**

```ts
toCBORHex(): string
```

Added in v2.0.0

### [Symbol.for("nodejs.util.inspect.custom")] (method)

**Signature**

```ts
;[Symbol.for("nodejs.util.inspect.custom")]()
```

# parsing

## fromCBORBytes

Parse a SingleHostName from CBOR bytes.

**Signature**

```ts
export declare const fromCBORBytes: (bytes: Uint8Array, options?: CBOR.CodecOptions) => SingleHostName
```

Added in v2.0.0

## fromCBORHex

Parse a SingleHostName from CBOR hex string.

**Signature**

```ts
export declare const fromCBORHex: (hex: string, options?: CBOR.CodecOptions) => SingleHostName
```

Added in v2.0.0

# predicates

## hasPort

Check if the host name has a port.

**Signature**

```ts
export declare const hasPort: (hostName: SingleHostName) => boolean
```

Added in v2.0.0

# schemas

## FromBytes

CBOR bytes transformation schema for SingleHostName.

**Signature**

```ts
export declare const FromBytes: (
  options?: CBOR.CodecOptions
) => Schema.transform<
  Schema.transformOrFail<
    typeof Schema.Uint8ArrayFromSelf,
    Schema.declare<CBOR.CBOR, CBOR.CBOR, readonly [], never>,
    never
  >,
  Schema.transformOrFail<
    Schema.Tuple<[Schema.Literal<[1n]>, Schema.NullOr<typeof Schema.BigIntFromSelf>, typeof Schema.String]>,
    Schema.SchemaClass<SingleHostName, SingleHostName, never>,
    never
  >
>
```

Added in v2.0.0

## FromCDDL

CDDL schema for SingleHostName.
single_host_name = (1, port / nil, dns_name)

**Signature**

```ts
export declare const FromCDDL: Schema.transformOrFail<
  Schema.Tuple<[Schema.Literal<[1n]>, Schema.NullOr<typeof Schema.BigIntFromSelf>, typeof Schema.String]>,
  Schema.SchemaClass<SingleHostName, SingleHostName, never>,
  never
>
```

Added in v2.0.0

## FromHex

CBOR hex transformation schema for SingleHostName.

**Signature**

```ts
export declare const FromHex: (
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
      Schema.Tuple<[Schema.Literal<[1n]>, Schema.NullOr<typeof Schema.BigIntFromSelf>, typeof Schema.String]>,
      Schema.SchemaClass<SingleHostName, SingleHostName, never>,
      never
    >
  >
>
```

Added in v2.0.0

# testing

## arbitrary

FastCheck arbitrary for SingleHostName instances.
Alias to `generator` for consistency with other modules.

**Signature**

```ts
export declare const arbitrary: FastCheck.Arbitrary<SingleHostName>
```

Added in v2.0.0

# transformation

## getDnsName

Get the DNS name from a SingleHostName.

**Signature**

```ts
export declare const getDnsName: (hostName: SingleHostName) => DnsName.DnsName
```

Added in v2.0.0

## getPort

Get the port from a SingleHostName, if it exists.

**Signature**

```ts
export declare const getPort: (hostName: SingleHostName) => Port.Port | undefined
```

Added in v2.0.0
