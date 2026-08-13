---
title: Cardano-specific Features
sidebar:
  label: Cardano
  order: 9
---

Most of the Tx3 language is chain-agnostic, but some transaction features are specific to one chain. On Cardano those features live under the `cardano::` namespace: stake operations, witnesses for script-using actions, reference-script publishing, treasury donations, and so on.

A compiler that does not target Cardano is allowed to reject these blocks with a clear diagnostic.

## `cardano::withdrawal` — claim staking rewards

```tx3
cardano::withdrawal {
    from: <address-like>,    // required — stake credential
    amount: <Int>,           // required — lovelace
    redeemer: <expr>,        // optional — for script credentials
}
```

The `from` field is the stake credential (a party, a policy, or any address-like expression). `amount` is a lovelace value of type `Int`. The redeemer is only meaningful when the stake credential is a script.

```tx3
party Sender;

tx withdraw_rewards() {
    cardano::withdrawal {
        from: Sender,
        amount: 0,
        redeemer: (),
    }
}
```

A transaction may contain more than one `cardano::withdrawal` block.

## `cardano::plutus_witness` — attach a Plutus script

```tx3
cardano::plutus_witness {
    version: <Int>,          // Plutus language version (1, 2, 3, ...)
    script: <Bytes>,         // serialized script bytes
}
```

Both fields are optional, but the block must include at least one. The resolver pairs the witness with whichever input, mint, certificate, or withdrawal needs it.

```tx3
party Minter;

tx mint_from_plutus(
    quantity: Int
) {
    locals {
       new_token: AnyAsset(0xbd3ae991b5aafccafe5ca70758bd36a9b2f872f57f6d3a1ffa0eb777, "ABC", quantity),
    }

    input source {
        from: Minter,
        min_amount: fees,
    }

    collateral {
        from: Minter,
        min_amount: fees,
    }

    mint {
        amount: new_token,
        redeemer: (),
    }

    output {
        to: Minter,
        amount: source + new_token - fees,
    }

    cardano::plutus_witness {
        version: 3,
        script: 0x5101010023259800a518a4d136564004ae69,
    }
}
```

## `cardano::native_witness` — attach a native script

```tx3
cardano::native_witness {
    script: <Bytes>,    // required — serialized native script bytes
}
```

Used for multi-sig and other native-script credentials.

```tx3
party Minter;

tx mint_from_native_script(
    quantity: Int
) {
    locals {
       new_token: AnyAsset(0xbd3ae991b5aafccafe5ca70758bd36a9b2f872f57f6d3a1ffa0eb777, "ABC", quantity),
    }

    input source {
        from: Minter,
        min_amount: fees,
    }

    collateral {
        from: Minter,
        min_amount: fees,
    }

    mint {
        amount: new_token,
    }

    output {
        to: Minter,
        amount: source + new_token - fees,
    }

    cardano::native_witness {
        script: 0x820181820400,
    }
}
```

## `cardano::treasury_donation` — pay into the treasury

```tx3
cardano::treasury_donation {
    coin: <Int>,    // required — lovelace donated
}
```

A single field, a single lovelace amount. The resolver attaches the donation to the transaction.

```tx3
cardano::treasury_donation {
    coin: 500,
}
```

## `cardano::stake_delegation_certificate`

```tx3
cardano::stake_delegation_certificate {
    pool: <address-like>,    // required — pool id
    stake: <address-like>,   // required — stake credential
}
```

Delegates a stake credential to a pool. Both fields are required.

## `cardano::vote_delegation_certificate`

```tx3
cardano::vote_delegation_certificate {
    drep: <address-like>,    // required — DRep
    stake: <address-like>,   // required — stake credential
}
```

Delegates a stake credential's voting power to a DRep.

```tx3
cardano::vote_delegation_certificate {
    drep: 0x12345678,
    stake: 0x87654321,
}
```

## `cardano::publish` — publish a reference script

```tx3
cardano::publish <name>? {
    to: <address-like>,      // required — recipient
    amount: <AnyAsset>,      // optional — value attached
    datum: <expr>,           // optional — datum attached
    version: <Int>,          // optional — Plutus version, omit for native
    script: <Bytes>,         // required — script bytes to publish
}
```

A `cardano::publish` block produces a transaction output that carries a reference script. It is in addition to any regular `output` blocks — `publish` does not replace them.

```tx3
party Sender;
party Receiver;

tx publish_plutus(
    quantity: Int
) {
    input source {
        from: Sender,
        min_amount: Ada(quantity),
    }

    cardano::publish {
        to: Receiver,
        amount: Ada(quantity),
        version: 3,
        script: 0x5101010023259800a518a4d136564004ae69,
    }

    output {
        to: Sender,
        amount: source - Ada(quantity) - fees,
    }
}
```

For a native script, use `version: 0`:

```tx3
cardano::publish {
    to: Receiver,
    amount: Ada(quantity),
    version: 0,
    script: 0x820181820400,
}
```
