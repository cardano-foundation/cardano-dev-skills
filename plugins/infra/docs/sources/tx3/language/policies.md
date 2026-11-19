---
title: Policies
sidebar:
    order: 3
---

A policy declares a piece of on-chain validation logic — most often a Plutus or native script. Once declared, a policy can be used wherever a script credential is expected: as the controller of an input UTxO, as the target of an output, or as the credential being delegated, withdrawn from, or witnessed.

## Two forms of declaration

### Short form: known hash

When you already know the policy's on-chain hash (for example, because the script has been compiled and pinned), bind that hash directly:

```tx3
policy TimeLock = 0x6b9c456aa650cb808a9ab54326e039d5235ed69f069c9664a8fe5b69;
```

The right-hand side is a hex byte string — the same byte format used elsewhere in the language.

### Constructor form: hash, script, ref

When you need to attach more than just the hash — for example because the transaction will carry the script inline, or read it from a reference UTxO — use the constructor form:

```tx3
policy FullyDefinedPolicy {
    hash: 0xABCDEF1234,
    script: 0xABCDEF1234,
    ref: 0xABCDEF1234,
}
```

All three fields are optional, but at least one must be present:

| Field    | Meaning                                                   |
| -------- | --------------------------------------------------------- |
| `hash`   | The policy's script hash.                                 |
| `script` | The serialized script bytes, to be attached inline.       |
| `ref`    | The UTxO where the script lives as a reference script.    |

The exact way `script` and `ref` are interpreted is chain-specific — see [Cardano features](./cardano) for the witness and reference-script blocks that consume them.

When a policy carries a `ref`, that UTxO is attached automatically — see [Pairing a policy with a witness](#pairing-a-policy-with-a-witness) below.

## Using a policy

A policy identifier is address-like, just like a party. It can appear anywhere a party can:

```tx3
party Owner;
party Beneficiary;

policy TimeLock = 0x6b9c456aa650cb808a9ab54326e039d5235ed69f069c9664a8fe5b69;

type State {
  lock_until: Int,
  owner: Bytes,
  beneficiary: Bytes,
}

tx lock(
    quantity: Int,
    until: Int
) {
    input source {
        from: Owner,
        min_amount: Ada(quantity),
    }

    output target {
        to: TimeLock,
        amount: Ada(quantity),
        datum: State {
            lock_until: until,
            owner: Owner,
            beneficiary: Beneficiary,
        },
    }

    output {
        to: Owner,
        amount: source - Ada(quantity) - fees,
    }
}
```

`Owner` is a party (the user who will lock funds), `TimeLock` is a policy (the script that will hold them). Both appear in the same positions.

## Pairing a policy with a witness

When the policy is a script that must run in the transaction (for example a Plutus minting policy or a script spend), the chain needs the script itself, not just its hash. There are two ways to supply it, and which one you use depends on how the policy was declared.

### Reference scripts (the `ref` field) — automatic

If the policy declares a `ref`, the script already lives on-chain at that UTxO. Whenever you use such a policy in a position that requires its script — as the `from` of an input, or as the policy of a `mint` / `burn` — Tx3 automatically adds that `ref` UTxO to the transaction's reference inputs. You do **not** need a separate `reference` block for it; the same `ref` used by several inputs or blocks is attached only once.

```tx3
policy Vault {
    hash: 0x6b9c456aa650cb808a9ab54326e039d5235ed69f069c9664a8fe5b69,
    ref:  0xANCHORTXHASH#0,
}

tx withdraw(quantity: Int) {
    input locked {
        from: Vault,            // Vault's `ref` UTxO is added as a reference input
        min_amount: Ada(quantity),
        redeemer: (),
    }

    output {
        to: Vault,
        amount: locked - Ada(quantity) - fees,
    }
}
```

A policy declared by hash only contributes no reference input — there is nothing to point at.

### Inline scripts — explicit

If the script is not published on-chain, it must be carried inline. The policy declaration alone is not enough; attach the bytes with one of the `cardano::*_witness` blocks. See [Cardano features](./cardano).
