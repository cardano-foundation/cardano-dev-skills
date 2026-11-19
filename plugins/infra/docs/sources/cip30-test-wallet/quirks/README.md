# Quirk catalogue

Every switch in the wallet has a note here with where it was observed, when, what breaks in a dApp because of it, and its lifecycle status: `reported` (sent in, not reproduced) or `confirmed` (reproduced against a current wallet version). Every quirk is off until a test switches it on.

No switch without a note. A quirk nobody can trace is the stale wallet profile this project exists to avoid.

| Switch | Status | Note |
|---|---|---|
| walletOptions.networkId (an option, not a quirks entry) | confirmed | [network-id.md](network-id.md) |
| `lateInjection: ms` | confirmed | [late-injection.md](late-injection.md) |
| `answersEveryKey` | confirmed | [answers-every-key.md](answers-every-key.md) |
| `enableRejected` | confirmed | [enable-rejected.md](enable-rejected.md) |
| `signRejected` | confirmed | [sign-rejected.md](sign-rejected.md) |
| `signHangs` | confirmed | [sign-hangs.md](sign-hangs.md) |
| `signDataRejected` | confirmed | [sign-data-rejected.md](sign-data-rejected.md) |
| `submitFails` | reported | [submit-fails.md](submit-fails.md) |
| `noCip95` | confirmed | [no-cip95.md](no-cip95.md) |
| `cip95NamespaceMissing` | reported | [cip95-namespace-missing.md](cip95-namespace-missing.md) |
| `cip95SignData` | reported | [cip95-sign-data.md](cip95-sign-data.md) |
| `coseAddress` | reported | [cose-address.md](cose-address.md) |
| `noCollateral` | confirmed | [no-collateral.md](no-collateral.md) |
| walletOptions.utxos[].scriptRef (an option, not a quirks entry) | reported | [utxo-with-script-ref.md](utxo-with-script-ref.md) |
| walletOptions.utxos[].datumHash (an option, not a quirks entry, crash unconfirmed) | reported | [utxo-with-datum-hash.md](utxo-with-datum-hash.md) |

Found one we do not have? Open an issue with wallet name, version and platform, the CIP-30 method, what the spec expects, what the wallet does, and a minimal reproduction. Never include keys, mnemonics or funded addresses.
