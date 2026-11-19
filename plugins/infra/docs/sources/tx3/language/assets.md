---
title: Assets
sidebar:
    order: 7
---

A UTxO carries value: a bag of `(policy, asset_name, amount)` triples. Tx3 surfaces this with the `AnyAsset` type and a small set of conveniences that make it easy to talk about quantities of specific assets without writing the policy and asset name out at every use.

## The implicit `Ada` asset

`Ada` is always in scope inside `tx` bodies. You use it as a constructor — apply it to an amount to get an `AnyAsset`:

```tx3
Ada(1000000)   // 1 ADA expressed in lovelace
Ada(500000)    // 0.5 ADA
```

`Ada` is the only asset name the language bakes in; everything else is declared.

## Declaring a named asset

If your protocol mentions a specific asset class repeatedly, give it a name with an `asset` declaration:

```tx3
asset StaticAsset = 0xABCDEF1234."MYTOKEN";
```

The right-hand side is a policy expression, a dot, and an asset-name expression — both must have type `Bytes`. Once declared, the name can be used as a constructor like `Ada`:

```tx3
StaticAsset(100)
```

Asset declarations live at the top level, alongside `party`, `policy`, and `type`.

## Ad-hoc assets with `AnyAsset(...)`

When the policy or asset name is only known at runtime — for example because it comes from a parameter, an env value, or another input's datum — use the built-in `AnyAsset` constructor function:

```tx3
AnyAsset(policy, asset_name, quantity)
```

It takes a `Bytes` policy, a `Bytes` asset name, and an `Int` amount, and returns an `AnyAsset` value.

```tx3
party Minter;

tx mint_from_local(
    mint_policy: Bytes,
    quantity: Int
) {
    locals {
        token: AnyAsset(mint_policy, "ABC", quantity),
    }

    mint {
        amount: token,
        redeemer: (),
    }

    input source {
        from: Minter,
        min_amount: fees,
    }

    output {
        to: Minter,
        amount: token - fees,
    }
}
```

## Adding and subtracting

`AnyAsset` values combine with `+` and `-`:

```tx3
Ada(1000000) + StaticAsset(50)
source + token - fees
```

Conceptually each operand is a bag of `(policy, asset_name, amount)` entries; addition merges and sums the amounts for matching entries, and subtraction takes the difference. There is no separate "multi-asset" type — bundles are just `AnyAsset` values that happen to carry more than one entry.

The value attached to an input or reference participates in the same arithmetic: `source - Ada(quantity) - fees` makes sense because `source` is an asset value.

## Scaling

Multiplying an `AnyAsset` by an `Int` scales every entry's amount. The `Int` may be on either side, and `*` binds tighter than `+` and `-`:

```tx3
StaticAsset(50) * quantity
Ada(2000000) + StaticAsset(1) * count
```

Dividing an `AnyAsset` by an `Int` scales every entry's amount down by integer division (truncating toward zero — remainders are dropped). The divisor must be on the right (`AnyAsset / Int`), and `/` shares precedence with `*`:

```tx3
total_pot / participants
```

## Reading asset components

An `AnyAsset` exposes three properties:

| Expression          | Type    | Meaning              |
| ------------------- | ------- | -------------------- |
| `asset.policy`      | `Bytes` | The asset class's policy id. |
| `asset.asset_name`  | `Bytes` | The asset name.      |
| `asset.amount`      | `Int`   | The quantity.        |

These are useful when forwarding details into datums:

```tx3
party Sender;
party Receiver;

type TokenBundle {
    token_id: Bytes,
    token_name: Bytes,
    amount: Int,
}

tx send_token(policy: Bytes, asset_name: Bytes, quantity: Int) {
    input source {
        from: Sender,
        min_amount: AnyAsset(policy, asset_name, quantity),
    }

    output {
        to: Receiver,
        amount: AnyAsset(policy, asset_name, quantity),
        datum: TokenBundle {
            token_id: policy,
            token_name: asset_name,
            amount: quantity,
        },
    }

    output {
        to: Sender,
        amount: source - AnyAsset(policy, asset_name, quantity) - fees,
    }
}
```

## Common positions

Asset values appear in a few specific positions:

- `input { min_amount: ... }` — a lower bound on the value the resolver must find on the input.
- `output { amount: ... }` — the exact value attached to a new output.
- `mint { amount: ... }` / `burn { amount: ... }` — the assets minted or burnt by the transaction.

For the full surface of `tx` body blocks see [Transactions](./txs).
