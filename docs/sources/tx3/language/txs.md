---
title: Transactions
sidebar:
    order: 8
---

A `tx` declares a transaction *template*: a parameterised description of a transaction that the toolchain resolves into a concrete, balanced, ready-to-submit transaction at the moment of use. The body of a `tx` is a collection of blocks — inputs, outputs, mints, witnesses, metadata, and so on — that together describe what the transaction must contain.

This page walks through each block, when to reach for it, and the rules the parser enforces on it.

## Shape of a tx declaration

```tx3
tx <name>(param1: Type1, param2: Type2) {
    // body blocks, in any order
}
```

The parameter list may be empty. Inside the body you can place any combination of the blocks described below, in any order. Names of inputs, outputs, references, locals, and parameters share a single flat scope, so an output declared near the bottom of the body can be referenced from a `min_amount` near the top.

```tx3
party Sender;
party Receiver;

tx transfer(
    quantity: Int
) {
    input source {
        from: Sender,
        min_amount: Ada(quantity),
    }

    output {
        to: Receiver,
        amount: Ada(quantity),
    }

    output {
        to: Sender,
        amount: source - Ada(quantity) - fees,
    }
}
```

Two identifiers are pre-bound inside every `tx` body: `Ada` (the chain's primary asset, used as a constructor) and `fees` (the resolved transaction fee, an `AnyAsset` value).

## Documenting a tx and its parameters

Prefix the `tx` keyword — or any parameter inside the parameter list — with a `///` doc-comment to describe what the transaction does and what each parameter means. The descriptions are surfaced in the registry UI and in generated bindings:

```tx3
/// Transfer lovelace from the sender to the receiver.
/// Any change is returned to the sender.
tx transfer(
    /// Amount to transfer, in lovelace.
    quantity: Int,
) {
    // ...
}
```

Multiple consecutive `///` lines are joined with line breaks. See [Comments](./comments) for the full rules.

## `input` — a UTxO to consume

```tx3
input <name> {
    from: <address-like>,    // controller of the UTxO
    ref: <UtxoRef>,          // a specific UTxO
    datum_is: <Type>,        // expected datum type
    min_amount: <AnyAsset>,  // lower bound on value
    redeemer: <expr>,        // redeemer for a script input
}
```

Every field is optional individually, but the block must give the resolver *something* to find a UTxO with: at least one of `from` or `ref` must be present.

- `from` is a [party](./parties) or [policy](./policies), or any address-like expression. It constrains *who* controls the UTxO. If `from` is a policy that carries a `ref`, that reference-script UTxO is added to the transaction's reference inputs automatically.
- `ref` pins the input to one specific UTxO.
- `datum_is` declares the expected datum type so that property access on the input name (`source.field`) is typed.
- `min_amount` is a lower bound — the resolver may find a UTxO with more value than required.
- `redeemer` is the data passed to the validator if the input sits at a script address. It can be anything; `()` is fine when the validator does not look at it.

The input's `<name>` puts a value into tx scope. That value can be used both as an asset bag (in `+` / `-` arithmetic) and, if `datum_is` was set, as a typed datum.

A worked example with `datum_is` and a script input:

```tx3
party Owner;
party Beneficiary;

policy TimeLock = 0x6b9c456aa650cb808a9ab54326e039d5235ed69f069c9664a8fe5b69;

tx unlock(
    locked_utxo: UtxoRef
) {
    input gas {
        from: Beneficiary,
        min_amount: fees,
    }

    input locked {
        from: TimeLock,
        ref: locked_utxo,
        redeemer: (),
    }

    collateral {
        from: Beneficiary,
        min_amount: fees,
    }

    output target {
        to: Beneficiary,
        amount: gas + locked - fees,
    }
}
```

### `input*` — many inputs

Putting a `*` after the keyword marks the block as *many*: the resolver may match zero or more UTxOs satisfying the predicates, and the resulting value is summed. Inside the tx the name still refers to a single value — you do not have to know up front how many UTxOs the resolver will pick:

```tx3
input* pieces {
    from: Sender,
    min_amount: fees,
}
```

## `output` — a UTxO to produce

```tx3
output <name>? {
    to: <address-like>,      // recipient — required
    amount: <AnyAsset>,      // value attached — required
    datum: <expr>,           // optional datum
}
```

Both `to` and `amount` are required. The output name is optional; give one if you want to refer to the output from elsewhere (`min_utxo(name)` is the common case).

```tx3
output target {
    to: Receiver,
    amount: Ada(quantity),
}
```

### `output?` — optional outputs

Putting a `?` after the keyword marks the output as *optional*: if its computed amount turns out to be zero during balancing, the resolver may omit it entirely. An optional output may not carry a `datum` field — the parser rejects that combination.

## `reference` — read a UTxO without consuming it

A reference block names a UTxO that should be visible to the transaction but not spent.

```tx3
reference <name> {
    ref: <UtxoRef>,
    datum_is: <Type>,    // optional, enables typed datum access
}
```

`ref` is required. If `datum_is` is present, the reference's datum can be read via property access on the name.

A `reference` block is also how you attach a **reference script** explicitly — point `ref` at the UTxO that carries the script when you are not using a [ref-backed policy](./policies) (for example, spending from a plain address whose validator's script lives at a known UTxO). When a ref-backed policy *is* used, its reference input is added for you and a separate block is unnecessary. Reference inputs are deduplicated, so an explicit block that names the same UTxO as a policy ref is harmless.

```tx3
party Receiver;

type OracleDatum {
    value: Int,
}

tx consume_oracle(oracle_utxo: UtxoRef) {
    reference oracle_data {
        ref: oracle_utxo,
        datum_is: OracleDatum,
    }

    output {
        to: Receiver,
        amount: Ada(0),
        datum: OracleDatum {
            value: oracle_data.value,
        },
    }
}
```

## `mint` and `burn`

`mint` and `burn` blocks declare assets the transaction itself creates or destroys.

```tx3
mint {
    amount: <AnyAsset>,    // required
    redeemer: <expr>,      // optional
}

burn {
    amount: <AnyAsset>,
    redeemer: <expr>,
}
```

`amount` is required; `redeemer` is optional and only meaningful when the minting policy is a script. Both blocks may appear multiple times in the same transaction. If the minted or burned asset's policy carries a `ref`, that reference-script UTxO is added to the transaction's reference inputs automatically.

```tx3
mint {
    amount: StaticAsset(100),
    redeemer: (),
}

burn {
    amount: StaticAsset(50),
    redeemer: (),
}
```

## `validity` — slot bounds

```tx3
validity {
    since_slot: <Int>,    // both fields optional
    until_slot: <Int>,
}
```

Both fields are optional; the resolver translates them into the chain's validity interval. Use `tip_slot()` as a convenient lower bound:

```tx3
validity {
    since_slot: tip_slot(),
    until_slot: validUntil,
}
```

At most one `validity` block per transaction.

## `signers` — required signatures

```tx3
signers {
    <address-like>,
    <address-like>,
}
```

Each entry is an address-like expression — a party, a policy, a hex bytes literal, or any expression of type `Address`.

```tx3
signers {
    MyParty,
    0x0F5B22E57FEEB5B4FD1D501B007A427C56A76884D4978FAFEF979D9C,
}
```

## `metadata` — auxiliary key/value pairs

```tx3
metadata {
    <Int>: <expr>,
    <Int>: <expr>,
}
```

Each entry's key must have type `Int`. Values can be any expression. String and hex literal values must be at most 64 bytes long; values that are not literals are not size-checked at compile time but must still respect the chain's limit at resolution time.

```tx3
metadata {
    1: metadata,
    2: "Additional Metadata",
}
```

A metadata block must contain at least one entry.

## `locals` — named sub-expressions

When the same expression appears in several places, lift it into `locals` and refer to it by name.

```tx3
locals {
    new_token: AnyAsset(0xbd3ae991b5aafccafe5ca70758bd36a9b2f872f57f6d3a1ffa0eb777, "ABC", quantity),
}
```

Local names share the flat tx scope, so they must not collide with parameters, input names, output names, or reference names. A `locals` block must have at least one assignment.

## `collateral` — script-execution collateral

For chains that require collateral on script transactions, declare it at the top level of the `tx`:

```tx3
collateral {
    from: <address-like>,     // optional
    min_amount: <AnyAsset>,   // optional
    ref: <UtxoRef>,           // optional
}
```

The block carries no identifier — collateral is consumed by the chain, not referenced by other blocks.

```tx3
collateral {
    from: Beneficiary,
    min_amount: fees,
}
```

The collateral block is chain-dependent: compilers targeting chains that have no notion of collateral may warn or reject it.

## Chain-specific blocks

Constructs that only make sense on a particular chain live under a chain namespace. Cardano-specific blocks are prefixed with `cardano::` — for example `cardano::withdrawal`, `cardano::plutus_witness`, `cardano::publish`. See [Cardano features](./cardano) for the full list.

## Putting it together

A tx that exercises most of the surface above:

```tx3
env {
    field_a: Int,
}

party MyParty;

type MyRecord {
    field1: Int,
    field2: Bytes,
    field3: Bytes,
    field4: List<Int>,
    field5: Map<Int, Bytes>,
}

type MyVariant {
    Case1 {
        field1: Int,
        field2: Bytes,
        field3: Int,
    },
    Case2,
}

asset StaticAsset = 0xABCDEF1234."MYTOKEN";

tx my_tx(
    quantity: Int,
    validUntil: Int,
    metadata: Bytes,
) {
    input source {
        from: MyParty,
        datum_is: MyRecord,
        min_amount: Ada(quantity) + min_utxo(named_output),
        redeemer: MyVariant::Case1 {
            field1: field_a,
            field2: 0xAFAFAF,
            field3: quantity,
        },
    }

    mint {
        amount: StaticAsset(100),
        redeemer: (),
    }

    burn {
        amount: StaticAsset(50),
        redeemer: (),
    }

    collateral {
        ref: 0xABCDEF#1,
    }

    reference ref_block {
        ref: 0xABCDEF#2,
    }

    output named_output {
        to: MyParty,
        datum: MyRecord {
            field1: quantity,
            field2: (54 + 10) - (8 + 2),
            field4: [1, 2, 3, source.field1],
            field5: {1: "Value1", 2: "Value2",},
            ...source
        },
        amount: AnyAsset(source.field3, source.field2, source.field1) + Ada(40) + min_utxo(named_output),
    }

    signers {
        MyParty,
        0x0F5B22E57FEEB5B4FD1D501B007A427C56A76884D4978FAFEF979D9C,
    }

    validity {
        since_slot: tip_slot(),
        until_slot: validUntil,
    }

    metadata {
        1: metadata,
        2: "Additional Metadata",
    }

    locals {
        local_var: concat("Lang", "Tour"),
    }
}
```
