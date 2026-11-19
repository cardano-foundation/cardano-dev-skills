# CardanoLedgerApi - Formal Cardano Ledger API for Lean4

[![Lean Version](https://img.shields.io/badge/Lean-v4.24.0-blue.svg)](https://github.com/leanprover/lean4)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Contributions Welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg)](CONTRIBUTING.md)

CardanoLedgerApi provides a formal Lean4 model of the Cardano Ledger API — the script context types and ledger rules used by Plutus smart contracts (V1, V2, V3). Combined with [Blaster](https://github.com/input-output-hk/Lean-blaster), it enables automated formal verification of Cardano validators directly from their compiled UPLC bytecode.

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Adding as a dependency](#adding-as-a-dependency)
- [How to use?](#how-to-use)
  - [Importing a UPLC validator](#importing-a-uplc-validator)
  - [Preparing the validator for verification](#preparing-the-validator-for-verification)
  - [Writing and verifying properties](#writing-and-verifying-properties)
- [Features](#features)
  - [Supported Ledger API Versions](#supported-ledger-api-versions)
  - [Ledger Rules](#ledger-rules)
  - [IsData Encoding](#isdata-encoding)
- [Examples](#examples)
  - [HelloWorld](#helloworld)
  - [UnlockPIN](#unlockpin)
  - [SellNFT](#sellnft)
  - [ParamFeed](#paramfeed)
  - [Functions: Fibonacci](#functions-fibonacci)
- [General Description](#general-description)
  - [API Versions and Types](#api-versions-and-types)
  - [Ledger Rules as Decidable Predicates](#ledger-rules-as-decidable-predicates)
  - [IsData Class](#isdata-class)
- [Contributing](#contributing)
  - [Ways to Contribute](#ways-to-contribute)


## Installation

### Prerequisites

CardanoLedgerApi requires:

- **Lean4** v4.24.0 (or compatible version)
- **Blaster** (for property verification) — see [Lean-blaster](https://github.com/input-output-hk/Lean-blaster)
- **PlutusCoreBlaster** — see [PlutusCoreBlaster](https://github.com/input-output-hk/PlutusCoreBlaster)

### Adding as a dependency

Add the following to your `lakefile.lean`:

```lean4
require «CardanoLedgerApi» from git
  "https://github.com/input-output-hk/CardanoLedgerApiBlaster" @ "main"
```

Or in `lakefile.toml`:

```toml
[[require]]
name = "CardanoLedgerApi"
git = "https://github.com/input-output-hk/CardanoLedgerApiBlaster"
rev = "main"
```

## How to use?

### Importing a UPLC validator

Use the `#import_uplc` command to load a compiled Plutus script from a `.flat` file:

```lean4
import PlutusCore.UPLC
import CardanoLedgerApi.V2

#import_uplc myValidator PlutusV2 single_cbor_hex "path/to/my_validator.flat"
```

### Preparing the validator for verification

Use `#prep_uplc` to apply the validator to a set of inputs and produce a symbolic representation for formal reasoning:

```lean4
open CardanoLedgerApi.V2 (spendingInputs)

#prep_uplc appliedMyValidator myValidator spendingInputs 10000
```

The third argument is the input constructor (e.g., `spendingInputs`, `mintingInputs`) and the fourth is the evaluation fuel bound.

### Writing and verifying properties

Once the validator is prepared, write properties about its behaviour and discharge them with `blaster`:

```lean4
import Blaster
open CardanoLedgerApi.V2

-- Theorem: validator succeeds iff the redeemer has the expected shape
theorem successful_iff_expected_redeemer :
  ∀ (input : SpendingInput),
    validSpendingContext input →
    (isSuccessful (appliedMyValidator.prop input) ↔ isExpectedRedeemer input) := by blaster

-- Use #blaster to assert a property is falsified (i.e., find a counterexample)
#blaster (gen-cex: 0) (solve-result: 1) [cannot_unlock_validator]
```

The `validSpendingContext` predicate encodes the Cardano ledger rules, constraining the `ScriptContext` to only well-formed transaction contexts.

## Features

### Supported Ledger API Versions

| Version | Module | Script Purposes |
|---------|--------|-----------------|
| V1 | `CardanoLedgerApi.V1` | Spending, Minting, Rewarding, Certifying |
| V2 | `CardanoLedgerApi.V2` | Spending, Minting, Rewarding, Certifying |
| V3 | `CardanoLedgerApi.V3` | Spending, Minting, Rewarding, Certifying, Voting, Proposing |

Each version exposes the same core interface (`SpendingInput`, `MintingInput`, `ScriptContext`, `TxInfo`, etc.) with version-specific extensions (e.g., `txInfoReferenceInputs` in V2/V3, governance fields in V3).

### Ledger Rules

The library encodes the Cardano ledger rules as decidable boolean predicates. These constrain the `ScriptContext` seen by a validator to only contexts that the ledger would actually produce:

- `validSpendingContext` — ledger rules for a V1 spending script context
- `validMintingContext` — ledger rules for a minting script context
- `validRewardingContext` — ledger rules for a rewarding script context
- `validCertifyingContext` — ledger rules for a certifying script context

Each predicate enforces:
1. Valid script purpose (e.g., spending input exists and has a datum hash in the witness map)
2. Valid transaction inputs (sorted by `TxOutRef`, positive Ada values)
3. Valid transaction outputs (script outputs have datum hashes)
4. Valid fee (non-zero Ada only)
5. Valid minted value (sorted currency symbols and token names)
6. Sorted withdrawals, signatories, and datum map
7. Transaction balance (`inputs + mint = outputs + fee`)

### IsData Encoding

The library provides an `IsData` typeclass for bidirectional conversion between Lean4 types and the Plutus `Data` type. Instances are provided for all ledger API types, and user-defined datum/redeemer structures can implement it:

```lean4
structure SellDatum where
  seller : Address
  price  : Integer

instance : IsData SellDatum where
  toData x := mkDataConstr 0 [IsData.toData x.seller, IsData.toData x.price]
  fromData
  | Data.Constr 0 [r_addr, Data.I p] =>
      match IsData.fromData r_addr with
      | some addr => some ⟨addr, p⟩
      | none => none
  | _ => none
```

## Examples

Examples are provided in the `Tests` folder.

### HelloWorld

`Tests/Scripts/HelloWorld` — a simple password-check validator. The redeemer must be the bytestring `"Hello CTF!"` and the datum must be void.

```lean4
/-- helloWorld successful ↔ expected redeemer ∧ datum is void -/
theorem successful_iff_valid_redeemer_and_void_datum :
  ∀ (input : SpendingInput),
    validSpendingContext input →
    (isSuccessful (appliedHelloWorld.prop input) ↔ isExpectedRedeemer input ∧ isVoidDatum input) := by blaster
```

The example also uses `#blaster (solve-result: 1)` to confirm that the validator is breakable (i.e., there exists a valid input that unlocks it).

### UnlockPIN

`Tests/Scripts/UnlockPIN` — a PIN-based validator where the redeemer must match a specific integer. Demonstrates the same pattern as HelloWorld but with an integer PIN instead of a bytestring password.

```lean4
/-- unlockPIN successful ↔ expected redeemer ∧ datum is void -/
theorem successful_iff_valid_pin_and_void_datum :
  ∀ (input : SpendingInput),
    validSpendingContext input →
    (isSuccessful (appliedUnlockPIN.prop input) ↔ isExpectedRedeemer input ∧ isVoidDatum input) := by blaster
```

### SellNFT

`Tests/Scripts/SellNFT` — an NFT sale validator. The datum encodes seller address and price; the script succeeds only when the seller is paid the correct amount.

```lean4
/-- sellNFT successful → spending purpose ∧ seller is paid with expected Ada -/
theorem sell_nft_successful_imp_seller_is_paid :
  ∀ (input : SpendingInput),
     validSpendingContext input →
     isSuccessful (appliedSellNFT.prop input) →
     (isSpendingPurpose input.ctx ∧ sellerIsPaid input) := by blaster

/-- seller is not paid → sell nft errors -/
theorem seller_not_paid_sell_nft_error :
  ∀ (input : SpendingInput),
     validSpendingContext input →
     ¬ sellerIsPaid input →
     isUnsuccessful (appliedSellNFT.prop input) := by blaster
```

This example also demonstrates vulnerability discovery: `#blaster (solve-result: 1)` finds a counterexample showing that SellNFT is vulnerable to a multi-satisfaction attack.

### ParamFeed

`Tests/Scripts/ParamFeed` — a parameterised oracle price feed validator (V3). The script takes three `Data` parameters; the theorem proves that successful execution implies the parameters satisfy a matching condition.

```lean4
theorem successful_imp_valid_params :
  ∀ (params1 params2 params3 : Data) (ctx : ScriptContext),
     isSuccessful (appliedParamFeed.prop params1 params2 params3 ctx) →
     isMatchingOraclePriceParams params1 params2 params3 := by blaster
```

### Functions: Fibonacci

`Tests/Functions/Fibonacci` — property verification of pure UPLC functions, independent of the ledger API. Proves the Fibonacci recurrence relation and equivalence between two implementations.

```lean4
-- ∀ (n : Integer), n > 1 → Fibonacci n = Fibonacci (n - 1) + Fibonacci (n - 2)
theorem fibonacci_sum :
  ∀ (n r1 r2 r3 : Integer), n > 1 →
    (fromFrameToInt $ compiledSeungheonOhSize.prop n) = some r1 →
    (fromFrameToInt $ compiledSeungheonOhSize.prop (n - 1)) = some r2 →
    (fromFrameToInt $ compiledSeungheonOhSize.prop (n - 2)) = some r3 →
    r1 = r2 + r3 := by blaster

-- Equivalence between two Fibonacci implementations
theorem fibonacci_equiv :
  ∀ (n : Integer),
    (fromFrameToInt $ compiledNaiveRecursion.prop n) = (fromFrameToInt $ compiledSeungheonOhSize.prop n) := by blaster
```

## General Description

### API Versions and Types

The library mirrors the Cardano Plutus ledger API across three versions. Each version lives under its own namespace (`CardanoLedgerApi.V1`, `CardanoLedgerApi.V2`, `CardanoLedgerApi.V3`) and re-exports the relevant types:

- **Address, Credential** — payment and staking credentials
- **Value** — multi-asset token bundles
- **TxOut, TxInInfo** — transaction outputs and inputs
- **TxInfo** — the full pending transaction view
- **ScriptPurpose, ScriptContext** — the validator's execution context
- **SpendingInput, MintingInput, ...** — typed wrappers that bundle datum/redeemer/context

V2 extends V1 with reference inputs and inline datums. V3 extends V2 with governance types (`TxCert`, `Voter`, `ProposalProcedure`, etc.) and additional script purposes.

### Ledger Rules as Decidable Predicates

A key design goal of CardanoLedgerApi is to encode the Cardano ledger rules as Lean4 decidable predicates. This is essential for formal verification: by asserting `validSpendingContext input` as a hypothesis, the SMT backend (Blaster) is constrained to only explore transaction contexts that the ledger would accept, producing meaningful and sound results.

The predicates are fully documented inline with the formal ledger specification they implement, including the exact invariants being checked (sortedness, value validity, balance, etc.).

### IsData Class

The `IsData` class, defined in `CardanoLedgerApi/IsData/Class.lean`, provides the bridge between Lean4 types and the Plutus `Data` type used on-chain. All ledger types come with `IsData` instances, and the library provides helpers (`mkDataConstr`, `toTerm`) for building instances for user-defined types.

## Contributing

We welcome all contributions! Whether it's bug reports, feature requests, documentation improvements, or code contributions, your help is appreciated.

### Ways to Contribute

- Report bugs and issues
- Suggest new features or improvements
- Add support for additional Cardano ledger rule versions
- Contribute new validator examples
- Improve documentation

**Maintained by:**
- [Jean-Frédéric Etienne](https://github.com/etiennejf)
- [Romain Soulat](https://github.com/RSoulatIOHK)
- [Mark Petruska](https://github.com/mpetruska)

**Questions?** Feel free to [open an issue](https://github.com/input-output-hk/CardanoLedgerApiBlaster/issues) or reach out to the maintainers.
