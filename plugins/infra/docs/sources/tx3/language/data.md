---
title: Data Expressions
sidebar:
    order: 5
---

Data expressions are the right-hand sides of Tx3: the values you build for datums, redeemers, amounts, slot bounds, metadata, and anywhere else the language asks for "some value of type X." This page is a reference for the syntactic ingredients — literals, operators, constructors, property access, and a handful of built-in functions — that you assemble into those values.

## Literals

```tx3
// Integer literals — type Int
123
-456
0

// Boolean literals — type Bool
true
false

// String literals — type Bytes
"hello"
"world"

// Hex literals — type Bytes
0xDEADBEEF
0x1234

// Unit literal — type ()
()

// UTxO-reference literal — type UtxoRef
0xABCDEF1234#0
```

Two things to notice:

- A string literal is just a convenient way to write bytes. Both `"hello"` and `0x68656C6C6F` produce a `Bytes` value; there is no separate string type.
- A `UtxoRef` literal is written as a hex transaction hash, a `#`, and an output index. The parser treats it as a single token.

## Operators

The operator surface is small.

| Form              | Meaning                                                                                 |
| ----------------- | --------------------------------------------------------------------------------------- |
| `expr.identifier` | Property access. Available on records, variant struct cases, `AnyAsset`, and `UtxoRef`. |
| `expr[expr]`      | Indexing. For a `List<T>` the index is any `Int` expression; for a `Tuple<...>` the index must be an integer literal in range, and the result type is that position's type. |
| `!expr`           | Arithmetic negation. Applies to `Int`.                                                  |
| `a * b`           | Multiplication. `Int * Int` multiplies integers; `AnyAsset * Int` (and `Int * AnyAsset`) scales asset quantities. |
| `a / b`           | Integer division, truncating toward zero (`7 / 2` is `3`). `Int / Int` divides integers; `AnyAsset / Int` divides each asset quantity. Does not commute (`Int / AnyAsset` is invalid). Dividing by `0` is an error. |
| `a + b`           | Addition. `Int + Int` adds integers; `AnyAsset + AnyAsset` aggregates asset values.     |
| `a - b`           | Subtraction. Same shapes as `+`.                                                        |

Precedence, from tightest to loosest:

1. Postfix `.` and `[…]`.
2. Prefix `!`.
3. Infix `*` and `/`.
4. Infix `+` and `-`.

Parentheses override precedence. There are no comparison, logical, modulo, or ternary operators in this version of the language.

> **`/` and comments:** `//` starts a line comment and `/*` starts a block comment, so write division with a single slash (`a / b`). The token sequence `a//b` is parsed as `a` followed by a comment, not as division.

## Constructors

### Records and variants

A record value is built by naming the type and giving each field:

```tx3
type State {
    counter: Int,
    owner: Bytes,
}

State {
    counter: 0,
    owner: 0xDEADBEEF,
}
```

A variant value names the type, the case, and (for struct cases) the fields:

```tx3
type Result {
    Ok { value: Int },
    Err,
}

Result::Ok { value: 42 }
Result::Err { }
```

### Spread

Inside a record or variant constructor you can copy fields from another value with `...base` and override only the ones you care about. The spread must be the last entry:

```tx3
type MyRecord {
    field1: Int,
    field2: Bytes,
    field4: List<Int>,
    field5: Map<Int, Bytes>,
}

MyRecord {
    field1: quantity,
    field4: [1, 2, 3, source.field1],
    field5: {1: "Value1", 2: "Value2",},
    ...source
}
```

Fields written explicitly take precedence; remaining fields are taken from `source`.

### Lists, maps, and tuples

```tx3
[1, 2, 3]            // List<Int>
[]                   // empty list — type from context

{1: "Value1", 2: "Value2"}   // Map<Int, Bytes>

(1, 0xFF)            // Tuple<Int, Bytes>
(1, 0xFF, true)      // Tuple<Int, Bytes, Bool>
```

A `Map` literal must contain at least one entry; the first entry fixes the key and value types.

A tuple literal is two or more comma-separated expressions in parentheses, and its element types are taken positionally. `(e)` is grouping (not a one-tuple) and `()` is the unit value. Read an element back with a literal index — `pair[0]`, `pair[1]` — exactly like list indexing. See [Tuples](./types#tuples).

## Property access

Records and variant struct cases expose their named fields. `AnyAsset` and `UtxoRef` expose a fixed set of built-in properties:

| Expression          | Result type | Meaning                                  |
| ------------------- | ----------- | ---------------------------------------- |
| `asset.policy`      | `Bytes`     | Policy id of an `AnyAsset` value.        |
| `asset.asset_name`  | `Bytes`     | Asset name of an `AnyAsset` value.       |
| `asset.amount`      | `Int`       | Quantity of an `AnyAsset` value.         |
| `utxo.tx_hash`      | `Bytes`     | Transaction hash of a `UtxoRef` value.   |
| `utxo.output_index` | `Int`       | Output index of a `UtxoRef` value.       |

Accessing a property that does not exist on the value's static type is a compile error.

## Built-in functions

These functions are always in scope. They use the same call syntax as [user-defined functions](./functions), and share the same namespace.

| Call                      | Returns    | Notes                                                                                  |
| ------------------------- | ---------- | -------------------------------------------------------------------------------------- |
| `min_utxo(output_name)`   | `AnyAsset` | Minimum Ada the named output needs to satisfy the chain's min-UTxO rule.               |
| `tip_slot()`              | `Int`      | The chain tip slot at resolution time.                                                 |
| `slot_to_time(slot)`      | `Int`      | Converts a slot number to a POSIX time.                                                |
| `time_to_slot(time)`      | `Int`      | Converts a POSIX time to a slot number.                                                |
| `concat(a, b)`            | same as `a`| Concatenates two `Bytes` values or two `List<T>` values; both arguments must have the same type. |
| `AnyAsset(policy, name, n)` | `AnyAsset` | Builds an `AnyAsset` triple from a `(Bytes, Bytes, Int)`.                             |

Worked example using `min_utxo`:

```tx3
party Sender;
party Receiver;

tx transfer_min(
    quantity: Int
) {
    input source {
        from: Sender,
        min_amount: fees + min_utxo(minimal_utxo) + min_utxo(change),
    }

    output minimal_utxo {
        to: Receiver,
        amount: min_utxo(minimal_utxo),
    }

    output change {
      to: Sender,
      amount: source - fees - min_utxo(minimal_utxo),
    }
}
```

And using the time and slot helpers:

```tx3
party Sender;

type TimestampDatum {
    current_slot: Int,
    expiry_slot: Int,
}

tx create_timestamp_tx(deadline: Int) {
    input source {
        from: Sender,
        min_amount: Ada(2000000),
    }

    output timestamp_output {
        to: Sender,
        amount: source - fees,
        datum: TimestampDatum {
            current_slot: slot_to_time(tip_slot()),
            expiry_slot: time_to_slot(deadline),
        },
    }
}
```

## Built-in identifiers inside `tx` bodies

Two identifiers are pre-bound inside every `tx` body:

- `Ada` — the chain's primary asset. It is used as a constructor: `Ada(quantity)` produces an `AnyAsset`.
- `fees` — an `AnyAsset` value representing the transaction's fee. The resolver fills in its concrete amount; you simply add or subtract it where balancing requires.

```tx3
output {
    to: Sender,
    amount: source - Ada(quantity) - fees,
}
```

Outside `tx` bodies these identifiers are not in scope.

## Reading values off inputs and references

An `input` or `reference` block introduces a named value into the tx's scope. You can use that name in two ways:

- As an asset value, in `+` / `-` arithmetic — `source - Ada(quantity) - fees`.
- As a typed datum, via property access — if the block declared `datum_is: MyRecord`, then `source.field` reads a field of that record.

```tx3
type MyRecord {
    counter: Int,
    other_field: Bytes,
}

party MyParty;

tx increase_counter() {
    input source {
        from: MyParty,
        min_amount: fees,
        datum_is: MyRecord,
    }

    output {
        to: MyParty,
        amount: source - fees,
        datum: MyRecord {
            counter: source.counter + 1,
            other_field: source.other_field,
        },
    }
}
```
