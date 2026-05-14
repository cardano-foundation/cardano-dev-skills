---
title: Port.ts
nav_order: 102
parent: Modules
---

## Port overview

---

<h2 class="text-delta">Table of contents</h2>

- [arbitrary](#arbitrary)
  - [arbitrary](#arbitrary-1)
- [model](#model)
  - [Port (type alias)](#port-type-alias)
- [predicates](#predicates)
  - [is](#is)
  - [isDynamic](#isdynamic)
  - [isRegistered](#isregistered)
  - [isWellKnown](#iswellknown)
- [schemas](#schemas)
  - [PortSchema](#portschema)

---

# arbitrary

## arbitrary

Generate a random Port.

**Signature**

```ts
export declare const arbitrary: Arbitrary<bigint>
```

Added in v2.0.0

# model

## Port (type alias)

Type alias for Port representing network port numbers.
Valid range is 0-65535 as per standard TCP/UDP port specification.

**Signature**

```ts
export type Port = typeof PortSchema.Type
```

Added in v2.0.0

# predicates

## is

Check if a value is a valid Port.

**Signature**

```ts
export declare const is: (value: unknown) => value is Port
```

Added in v2.0.0

## isDynamic

Check if a port is a dynamic/private port (49152-65535).

**Signature**

```ts
export declare const isDynamic: (port: Port) => boolean
```

Added in v2.0.0

## isRegistered

Check if a port is a registered port (1024-49151).

**Signature**

```ts
export declare const isRegistered: (port: Port) => boolean
```

Added in v2.0.0

## isWellKnown

Check if a port is a well-known port (0-1023).

**Signature**

```ts
export declare const isWellKnown: (port: Port) => boolean
```

Added in v2.0.0

# schemas

## PortSchema

Schema for validating port numbers (0-65535).

**Signature**

```ts
export declare const PortSchema: Schema.refine<bigint, typeof Schema.BigInt>
```

Added in v2.0.0
