---
title: Functions
sidebar:
    order: 6
---

A function is a named, reusable piece of a [data expression](./data). When the same calculation shows up in several places — or when a sub-expression is complex enough to deserve a name — you can factor it into an `fn` and call it wherever a value is expected.

Functions are a source-level convenience: they are *inlined* by the compiler, so a call leaves no trace in the resolved transaction. They add naming and reuse, not new runtime behaviour. They are pure, non-recursive, and cannot touch transaction state (inputs, outputs, `fees`, and the like).

## Declaring a function

```tx3
fn double(x: Int) -> Int {
    x + x
}
```

A function declaration has a name, a parenthesised parameter list, a return type after `->`, and a body in braces. Every parameter is typed, and the return type is explicit — there is no inference.

Identifier rules match the rest of the language: a function name starts with a letter and contains letters, digits, and underscores, and must be unique across the program's top-level declarations (including the built-in functions below).

## Function body

A body is an optional sequence of `let`-bindings followed by a single result expression. The result is the value the function returns; its type must match the declared return type.

```tx3
fn discounted(base: Int, off: Int) -> Int {
    let net = base - off;
    let doubled = net + net;
    doubled
}
```

Each `let` names the value of a data expression and is visible to the bindings that follow it and to the result. A body is itself just a data expression, so the usual operators (`+`, `-`, property access, indexing) and constructors are available — but transaction blocks, control flow, and recursion are not.

Functions can return records (or any other type), and can call other functions:

```tx3
type PoolState {
    pair_a: Int,
    pair_b: Int,
}

fn make_pool(a: Int, b: Int) -> PoolState {
    PoolState {
        pair_a: a,
        pair_b: b,
    }
}

fn adjust_pool(pool: PoolState, delta_a: Int, delta_b: Int) -> PoolState {
    PoolState {
        pair_a: pool.pair_a + delta_a,
        pair_b: pool.pair_b - delta_b,
    }
}
```

## Calling a function

Call a function with the same syntax as the [built-in functions](./data#built-in-functions): the name followed by parenthesised arguments. A call is valid anywhere a data expression is — output amounts, datums, locals, and so on.

```tx3
party Sender;
party Receiver;

tx use_double(amount: Int) {
    input source {
        from: Sender,
        min_amount: Ada(amount),
    }
    output {
        to: Receiver,
        amount: Ada(double(amount)),
    }
}
```

The number of arguments must match the parameters, and each argument's type must match the corresponding parameter's type.

## Functions and the built-ins

The built-in helpers `min_utxo`, `tip_slot`, `slot_to_time`, and `time_to_slot` are functions too — they share the same call syntax and namespace, and you cannot define an `fn` that reuses one of their names. The difference is that the built-ins are evaluated by the resolver (using chain state), whereas user-defined functions are inlined away at compile time. See [Data Expressions](./data#built-in-functions) for their signatures.

## Restrictions

- Functions are top-level only; they cannot be nested.
- Functions must not be recursive, directly or through a cycle of calls — inlining would not terminate.
- A function body cannot reference a transaction's inputs, outputs, references, locals, or `fees`; it only sees its own parameters and `let`-bindings, plus program-level names (parties, policies, assets, types).
