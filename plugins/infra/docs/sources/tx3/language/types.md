---
title: Types
sidebar:
    order: 4
---

Every value in Tx3 has a static type. Types let the compiler check that datums, redeemers, and parameters fit together before the transaction is ever resolved, and they tell the codegen frontends how to (de)serialize values across the language boundary.

This page is a tour of the type system: the built-in types, the compound types, and the user-defined types you build on top of them. For the literals and operators that produce values of these types, see [Data expressions](./data).

## Built-in primitive types

| Type       | What it holds                                                                  |
| ---------- | ------------------------------------------------------------------------------ |
| `Int`      | A signed integer.                                                              |
| `Bool`     | `true` or `false`.                                                             |
| `Bytes`    | A finite-length byte string. String literals (`"abc"`) and hex literals (`0xDEADBEEF`) both produce values of type `Bytes`. |
| `Address`  | A chain address. The on-wire representation is defined by the target chain.    |
| `UtxoRef`  | A reference to a specific UTxO — a `(tx_hash, output_index)` pair.             |
| `AnyAsset` | A `(policy, asset_name, amount)` triple representing some quantity of one asset class. |

There is no separate `String` type: text and arbitrary bytes share the `Bytes` type and are distinguished only by the literal you use to write them.

The unit type is spelled `()`. It is mostly used as a no-op redeemer where a value is syntactically required but its content is irrelevant:

```tx3
mint {
    amount: MyToken(100),
    redeemer: (),
}
```

## Compound types

### Lists

`List<T>` is a homogeneous list of `T`. Element type is inferred from the first element or from the surrounding context.

```tx3
type Data {
    numbers: List<Int>,
}
```

### Maps

`Map<K, V>` is a key-value mapping with key type `K` and value type `V`. In this version of the language every `Map` literal must contain at least one entry; key and value types are inferred from that first entry.

```tx3
type Datum {
  A: Map<Int, Int>,
}
```

### Tuples

`Tuple<T1, T2, ...>` is a fixed-arity, positionally-typed group of values. Unlike a `List`, each position can have a different type; unlike a record, the positions are unnamed. A tuple always has **two or more** elements.

```tx3
type Datum {
    pair: Tuple<Int, Bytes>,
    triple: Tuple<Int, Bytes, Bool>,
}
```

You build a tuple by writing two or more comma-separated expressions in parentheses; the element types are taken positionally:

```tx3
(42, 0xDEADBEEF)         // Tuple<Int, Bytes>
(quantity, name, true)   // Tuple<Int, Bytes, Bool>
```

`(e)` (a single parenthesized expression) is just grouping, and `()` is the unit value — neither is a tuple, which is why tuples start at two elements.

Read an element back by **positional index**, using the same bracket syntax as a list:

```tx3
pair[0]   // the Int
pair[1]   // the Bytes
```

The index must be an integer literal within range — a tuple cannot be indexed by a runtime value, since each position may have a different type, and an out-of-range index is a compile error.

## User-defined types

User-defined types are introduced with the `type` keyword. There are three shapes.

### Records

A record has a fixed set of named fields:

```tx3
type State {
    lock_until: Int,
    owner: Bytes,
    beneficiary: Bytes,
}
```

You construct a record with `TypeName { field: expr, ... }`:

```tx3
State {
    lock_until: 1234567890,
    owner: 0xDEADBEEF,
    beneficiary: 0x12345678,
}
```

Field access uses dot notation: `state.lock_until`.

### Variants

A variant type is a tagged union with one or more cases. Each case is one of three shapes:

```tx3
type MyVariant {
    Case1 {
        field1: Int,
        field2: Bytes,
        field3: Int,
    },
    Case2,
}
```

- **Struct case** (`Case1` above) — has named fields, like a record case.
- **Unit case** (`Case2` above) — carries no payload.
- **Tuple case** — declared as `Case(T1, T2)`; accepted by the grammar but not constructable in this version of the language.

You construct a variant by naming the type, the case, and (for struct cases) the fields:

```tx3
MyVariant::Case1 {
    field1: 7,
    field2: 0xAFAFAF,
    field3: 42,
}

MyVariant::Case2 { }
```

Each case name must be unique within its variant.

### Type aliases

A type alias gives an existing type a second name. Aliases are transparent: an alias and the type it points to are interchangeable everywhere.

```tx3
type AssetName = Bytes;
type PolicyId = Bytes;
type Amount = Int;

type TokenId = PolicyId;        // alias chains are allowed
type TokenName = AssetName;
type Balance = Amount;

type Asset {
    token_id: TokenId,
    token_name: TokenName,
    amount: Balance,
}

type TokenBundle = Asset;
```

Cyclic aliases (`type A = B; type B = A;`) are rejected.

## Type equivalence

Two types are equivalent if they are the same primitive, the same `List<T>` (with equivalent `T`), the same `Map<K, V>` (with equivalent `K` and `V`), the same `Tuple<...>` (same arity, with each position's type equivalent), or refer to the same user-defined type after alias chasing. Tuple equivalence is structural and order- and arity-sensitive: `Tuple<Int, Bytes>` and `Tuple<Bytes, Int>` are different types, and neither equals `Tuple<Int, Bytes, Bool>`.

There are no implicit conversions. `Int` does not silently turn into `Bytes`, and `Bytes` does not silently turn into `Address`, `UtxoRef`, or `AnyAsset`. Where a position expects a specific type, the expression must already have that type.
