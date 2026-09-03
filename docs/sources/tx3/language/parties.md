---
title: Parties
sidebar:
    order: 2
---

A party is a named placeholder for an on-chain address. Protocols are written in terms of parties (`Sender`, `Beneficiary`, `Treasury`) rather than raw addresses so that the same code can run against many deployments and so that the role each address plays is visible at a glance.

## Declaring a party

```tx3
party Sender;
party Receiver;
party Treasury;
```

A party declaration introduces a typed identifier into the program scope. The concrete address is supplied at resolution time — it is not part of the source.

Identifier rules: a party name starts with a letter and contains letters, digits, and underscores. Names must be unique across the program's top-level declarations.

## Where a party can be used

Parties are address-like values. They are accepted wherever a recipient or controlling credential is expected:

- as the `from` of an `input`,
- as the `to` of an `output` or `cardano::publish`,
- inside a `signers` block,
- as the `from` of a `cardano::withdrawal`,
- as the `stake` of a stake or vote delegation certificate,
- as the `drep` of a vote delegation certificate,
- as the `pool` of a stake delegation certificate.

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

## Documenting a party

Prefix a party declaration with a `///` doc-comment to describe its role. The description is carried through to the registry UI and generated bindings:

```tx3
/// The user initiating the transaction.
party Sender;

/// Protocol treasury — receives fees and dust.
party Treasury;
```

See [Comments](./comments) for the full rules.

## Parties vs. policies

When the address that controls a UTxO is itself a script, declare it as a [`policy`](./policies) rather than a party. A `party` is the right tool for an actor whose address you don't yet know; a `policy` is the right tool for a script whose hash or witness you do.
