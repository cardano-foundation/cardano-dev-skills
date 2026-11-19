---
title: Environment
sidebar:
    order: 1
---

A Tx3 protocol almost always depends on values that are not known when the protocol is written: the policy id of an on-chain script, the UTxO that hosts a reference script, an oracle's stake address. Hard-coding those values would tie the protocol to a single deployment.

The `env` block declares those external inputs by name and type so the rest of the protocol can use them as ordinary identifiers, and so the toolchain can supply them per profile (devnet, preview, preprod, mainnet) at build time.

## Declaring an env block

An `env` block is a top-level declaration that lists name/type pairs:

```tx3
env {
    field_a: Int,
    field_b: Bytes,
    field_c: Bool,
    field_d: List<Bytes>,
}
```

Rules:

- A program has at most one `env` block.
- It must contain at least one field.
- Fields can use any of the built-in or user-defined types — primitives, `Bytes`, `UtxoRef`, `List<T>`, records, etc.

## Using env values

Env fields are in scope everywhere outside type definitions: in parties, policies, asset declarations, and every clause of every `tx` block. You use them like any other identifier:

```tx3
env {
    mint_script: UtxoRef,
    mint_policy: Bytes,
}

party Minter;

tx mint_from_env(
    quantity: Int
) {
    reference myscript {
        ref: mint_script,
    }

    mint {
        amount: AnyAsset(mint_policy, "ABC", 1),
        redeemer: (),
    }

    input source {
        from: Minter,
        min_amount: fees,
    }

    output {
        to: Minter,
        amount: AnyAsset(mint_policy, "ABC", 1),
    }
}
```

Here `mint_script` and `mint_policy` are typed env values; the parser checks that `mint_script` has type `UtxoRef` wherever a `UtxoRef` is required, and that `mint_policy` has type `Bytes` wherever a policy id is expected.

## Documenting env fields

Prefix any field with a `///` doc-comment to describe what value belongs there. The description follows the field through to the registry UI and generated bindings, which helps integrators fill in profiles correctly:

```tx3
env {
    /// Cardano network magic identifier.
    network: Int,

    /// UTxO that hosts the minting script's reference output.
    mint_script: UtxoRef,
}
```

See [Comments](./comments) for the full rules.

## How env values get supplied

The Tx3 language only declares the shape of the environment. The concrete values are supplied by the toolchain — typically by `trix` from a profile-specific env file. See the project guide for how to wire env values per network.
