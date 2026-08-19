# tx-sign

Offline signing for unsigned Conway transactions. Stores one
payment signing key inside an age-encrypted vault, then unlocks it
in memory to emit one detached vkey witness. The cleartext key
never touches disk; the passphrase is read from an inherited file
descriptor or a no-echo TTY prompt, never from `argv`.

```text
Usage: tx-sign --network NAME COMMAND

  --network NAME            mainnet | preprod | preview | devnet

Available commands:
  vault create              Import one Cardano payment signing key
                            into an age-encrypted vault
  witness                   Create a detached vkey witness for an
                            unsigned Conway transaction
```

## Examples

Import a signing key from a `cardano-cli` `.skey` JSON envelope
with the passphrase on file descriptor 0:

```bash
tx-sign --network preprod vault create \
  --signing-key-stdin \
  --label core_development \
  --out core.vault.age \
  --vault-passphrase-fd 0 \
  <core.skey
```

Emit one detached witness for an unsigned tx CBOR hex file:

```bash
tx-sign --network preprod witness \
  --tx unsigned.cbor.hex \
  --vault core.vault.age \
  --identity core_development \
  --out core.witness.hex \
  --vault-passphrase-fd 0
```

Attach the witness with `cardano-cli`:

```bash
cardano-cli conway transaction assemble \
  --tx-body-file unsigned.cbor.hex \
  --witness-file core.witness.hex \
  --out-file signed.tx.json
```

## Library

The signing primitives live under `Cardano.Tx.Sign.*`:

| Module                                | Role                                                  |
|---------------------------------------|-------------------------------------------------------|
| `Cardano.Tx.Sign.Vault.Age`           | age-scrypt encrypt / decrypt boundary                 |
| `Cardano.Tx.Sign.Vault`               | In-memory v1 vault schema                             |
| `Cardano.Tx.Sign.Witness`             | Detached vkey witness creation                        |
| `Cardano.Tx.Sign.AttachWitness`       | Merge a `Set (WitVKey Witness)` into an unsigned tx   |
| `Cardano.Tx.Sign.Cli.*`               | `optparse-applicative` parsers + runners              |

Accepted signing-key material: a `cardano-cli` `.skey` JSON
envelope or a `cardano-addresses` `addr_xsk` bech32 string.
