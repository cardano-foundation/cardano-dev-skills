# Aiken & Cardano Glossary

## Ada

**Definition:** The native protocol currency of Cardano. The primary asset in all transaction values. Indivisible unit is the Lovelace (1 Ada = 1,000,000 Lovelace).

**Context:** Every UTxO must contain a minimum amount of Ada. Ada is used for transaction fees and stake delegation.

**Related:** Lovelace, value, asset, stake

## Address

**Definition:** A structured identifier composed of a header (type + network), payment credentials (spending conditions), and optional delegation credentials (staking control). Encoded in bech32 or base16.

**Context:** Cardano-specific. Determines who can spend a UTxO and how stake is delegated.

**Related:** payment credentials, delegation credentials, script hash, verification key hash

## `aiken build`

**Definition:** CLI command that compiles an Aiken project and generates the Plutus blueprint (`plutus.json`). Strips traces by default.

**Context:** Primary build command. Use `--trace-level verbose` to keep traces in production builds.

**Related:** aiken check, Plutus blueprint, trace level

## `aiken check`

**Definition:** CLI command that type-checks a project and runs all tests. Preserves traces by default.

**Context:** Primary development command. Displays memory/CPU execution units per test.

**Related:** aiken build, test, trace

## `aiken docs`

**Definition:** CLI command that generates HTML documentation from types, type annotations, and documentation comments (`///`).

**Context:** Library authors should use this to produce API documentation.

**Related:** documentation comment, module, pub

## `aiken.toml`

**Definition:** The project configuration file at the root of an Aiken project. Contains metadata (name, version, license), dependencies, repository info, workspace configuration, and environment-specific config values.

**Context:** Managed by `aiken packages` for dependencies. Root pattern for the LSP.

**Related:** project structure, dependencies, config, workspace

## `aikup`

**Definition:** A cross-platform utility for downloading and managing Aiken compiler versions. The recommended installation method.

**Context:** Running `aikup` alone installs the latest version. Supports version pinning.

**Related:** installation, aiken

## Alonzo era

**Definition:** The era that introduced Plutus smart contracts (V1) to Cardano, enabling on-chain script execution.

**Related:** Plutus Core, script, smart contract

## Alternative patterns

**Definition:** Using the pipe symbol `|` in pattern matching to handle multiple patterns with the same logic. Patterns must introduce the same identifiers with the same types.

**Context:** Reduces code duplication across similar branches.

**Example:**
```aiken
when user is {
  LoggedInAsAdmin { username } | LoggedIn { username } -> username
  Guest -> "Guest"
}
```

**Related:** pattern matching, when/is

## `and` / `or`

**Definition:** Block-style keywords for composing boolean expressions with clear visual grouping. `and { ... }` requires all expressions to be True; `or { ... }` requires at least one.

**Context:** Boolean composition syntax. More readable than `&&`/`||` chains, especially with 4+ conditions.

**Example:**
```aiken
or {
  and {
    condition_1,
    condition_2,
  },
  condition_3,
}
```

**Related:** Bool, &&, ||, validator

## Anonymous function

**Definition:** An unnamed function defined inline using `fn(args) { body }` syntax. Assigned to variables via `let`. Cannot be recursive.

**Context:** Used for one-off transformations, especially with `list.map`, `list.filter`, etc.

**Example:**
```aiken
let add = fn(x, y) { x + y }
add(1, 2)  // 3
```

**Related:** first-class function, function capturing, lambda

## Babbage era

**Definition:** The era that introduced Plutus V2 with reference inputs, inline datums, and reference scripts.

**Related:** Plutus V2, inline datum, reference input

## `<-` (Backpassing)

**Definition**: Syntax for functions that take a callback as last argument. Allows writing callback-based code in a flat, linear style by assigning the callback result to a binding.

**Context**: Advanced function syntax. Sugar for passing anonymous callback functions. Particularly useful for writing fuzzers.

**Example**:

```aiken
fn cubed(n) {
  let total <- apply_function_twice(n)
  total * n
}
// Equivalent to: apply_function_twice(n, fn(total) { total * n })
  ```

**Related**: pipe operator, anonymous function, function capturing

## Base16 / Hex encoding

**Definition:** Hexadecimal representation of binary data. Each byte is two hex characters. Used extensively for hashes, policy IDs, and addresses.

**Context:** Aiken supports hex-encoded ByteArray literals with `#"..."` syntax.

**Example:**
```aiken
#"666f6f" == "foo"
```

**Related:** ByteArray, bech32, hash digest

## Bech32

**Definition:** A human-readable encoding format with custom prefix and error-detection, for short binary data. Used extensively in Cardano, in particular for addresses which starts with `addr...` or `addr_test...`.

**Context:** The standard way to display hashes, keys, addresses and a variety of short (<64 bytes) binary data. Command-line tool available at `input-output-hk/bech32`.

**Related:** address, base16, encoding

## `bench`

**Definition:** Keyword for defining benchmarks that measure execution costs (memory and CPU) across increasing input sizes. Uses a `Sampler` function via the `via` keyword.

**Context:** Benchmarking keyword. Run with `aiken bench`. Builds on the fuzzer framework.

**Example:**
```aiken
bench bytearray_length(bytes: ByteArray via sample_bytearray) {
  bytearray.length(bytes)
}
```

**Related:** Sampler, Fuzzer, test, aiken bench

## Blake2b

**Definition:** The primary hashing algorithm used throughout Cardano. Used with different output sizes: Blake2b_256 (32 bytes) for general digests and Blake2b_224 (28 bytes) for credentials and policy IDs.

**Context:** Understanding hash sizes helps with type annotations like `Hash<Blake2b_224, VerificationKey>`.

**Related:** hash digest, cryptography, credential

## Block (syntax)

**Definition:** A sequence of expressions enclosed in curly braces `{ }` that evaluates to the value of its last expression. Used to group operations and introduce local bindings.

**Context:** The body of functions, `when/is` branches, and `if/else` are all blocks.

**Example:**
```aiken
let celsius = { fahrenheit - 32 } * 5 / 9
```

**Related:** expression, let, scope

## Block (data)

**Definition:** A container batching multiple transactions together. Contains a header (producer info, timestamps, hashes) and a body (ordered sequence of transactions). Blocks form a chain by referencing the previous block's header hash.

**Context:** One block every ~20 seconds on average on Cardano. Block producers are elected by the Ouroboros consensus protocol.

**Related:** transaction, chain, hash digest, slot, epoch

## Bool

**Definition:** Boolean type with two values: `True` and `False`. Supports operators `==`, `&&` (AND), `||` (OR), `!` (NOT), and `?` (trace-if-false).

**Context:** Fundamental type. All validators ultimately produce a Bool. `&&` and `||` are short-circuit (right-associative).

**Example:**
```aiken
let is_valid: Bool = True
let result = is_valid && (amount > 0)
```

**Related:** and/or, predicate, validator, ? operator

## Byron address

**Definition:** A deprecated legacy address format from before the Shelley era (e.g., `Ae2tdPwUPEYz6...`). Forbidden in transactions containing Plutus scripts.

**Context:** You may encounter them in legacy systems but should never use them in new development.

**Related:** Shelley address, address, era

## Byron era

**Definition:** The original Cardano era with legacy address formats and no smart contract support. Byron addresses are now deprecated and forbidden in Plutus transactions.

**Related:** Byron address, Shelley era

## ByteArray

**Definition:** A sequence of bytes. Aiken supports three literal notations: byte array (`#[10, 255]`), UTF-8 string (`"foo"`), and hex-encoded string (`#"666f6f"`).

**Context:** The workhorse type for identifiers, hashes, policy IDs, and on-chain data. Note: double-quoted strings without `@` prefix are ByteArrays, not text strings.

**Example:**
```aiken
let hash: ByteArray = #"abcd1234"
let name: ByteArray = "Hello"
let bytes: ByteArray = #[0xff, 0x42]
```

**Related:** String, hash digest, hex encoding

## CBOR

**Definition:** Concise Binary Object Representation — a structured binary format used pervasively in Cardano for serialisation. Think of it as binary JSON.

**Context:** Transactions, datums, redeemers, and scripts are all CBOR-encoded on-chain.

**Related:** CDDL, CBOR diagnostic, serialisation, Data

## CBOR diagnostic

**Definition:** A human-readable, JSON-like notation for CBOR data defined in [RFC 8949](https://www.rfc-editor.org/rfc/rfc8949). Used for debugging runtime values via `cbor.diagnostic()`. Custom types are represented using tags (121 for first constructor, 122 for second, etc.).

**Context:** Debugging tool. Custom type fields appear as list elements within a tagged value.

**Example:**
```aiken
cbor.diagnostic(Some(42)) == @"121([_ 42])"
cbor.diagnostic(None)     == @"122([])"
```

**Related:** CBOR, trace, troubleshooting, constructor, tag

## CDDL

**Definition:** Concise Data Definition Language — a specification meta-language for describing CBOR data structures. The Cardano ledger maintains CDDL specifications for all on-chain objects.

**Context:** The source of truth for how transactions, blocks, and other structures are serialised.

**Related:** CBOR, serialisation, specification

## Certificate

**Definition:** A credential-related document published via transactions: stake registration, delegation to a pool, pool registration, etc. Publishing is controlled by the `publish` script purpose.

**Context:** Target type for the `publish` handler.

**Related:** publish, delegation, stake pool

## Compile-time

**Definition:** Operations performed by the Aiken compiler before the program runs. Constants are evaluated at compile-time and inlined. Type checking also occurs at compile-time.

**Context:** Aiken's static type system catches type errors at compile-time, not runtime.

**Related:** const, type inference, static typing, inlining

## Conditional module

**Definition:** An Aiken module that can be swapped based on the build environment. Files follow the naming pattern `{module}.{env}.ak` and are selected with `--env`.

**Context:** Useful for mainnet/testnet differences without code changes.

**Related:** environment, config, aiken build

## Config module

**Definition:** A virtual module generated from `[config]` sections in `aiken.toml`. Provides typed constants derived from TOML configuration values, accessible via `use config`.

**Context:** Supports integers, booleans, strings, lists, tuples, and hex-encoded byte arrays.

**Example:**
```toml
[config.default]
price = 1000000

[config.default.owner]
bytes = "0000111122223333"
encoding = "hex"
```
```aiken
use config
fn main() { config.price }
```

**Related:** aiken.toml, conditional module, environment

## `const`

**Definition:** Keyword for defining module-level constants. Constants are fully evaluated at compile-time and inlined by the compiler wherever they are referenced.

**Context:** Module-level keyword. Can hold almost any Aiken expression. Constants cannot reference other constants defined after them.

**Example:**
```aiken
const start_year = 2101
const seasons = ["Summer", "Autumn", "Winter", "Spring"]
```

**Related:** let, compile-time, inlining

## Constructor

**Definition:** A named function that creates a value of a custom type. Types can have one constructor (records) or multiple constructors (enums/ADTs). Constructors are used in both creation and pattern matching.

**Context:** Constructors define the possible shapes of a type. In CBOR, they're tagged starting from 121 for the first constructor.

**Example:**
```aiken
type User {
  LoggedIn { username: ByteArray }
  Guest
}
let user = LoggedIn { username: "alice" }
```

**Related:** type, pattern matching, enum, record, CBOR tag

## Conway era

**Definition:** The current era introducing on-chain governance (Voltaire), Plutus V3, and new script purposes (vote, propose).

**Related:** governance, vote, propose, Plutus V3, constitution

## Data

**Definition:** An opaque compound type that can represent any possible user-defined serialisable type. Acts as a wildcard type for polymorphic operations. Any custom type can be cast to `Data`, and `expect` can downcast from `Data`.

**Context:** Essential for validator boundaries where datum and redeemer types are generic. Several builtins only work with `Data`.

**Example:**
```aiken
const anything: Data = 42
const also_data: Data = [True, False]

fn downcast(data: Data) -> RGB {
  expect d: RGB = data
  d
}
```

**Related:** expect, serialisation, CBOR, custom type

## Datum

**Definition:** A data payload attached to a UTxO when it is created. Represents the contract's state or configuration. Provided to `spend` validators during execution.

**Context:** Cardano-specific. Set when locking value at a script address. Only spend-purpose scripts receive a datum. Always `Option<T>` in Aiken handlers because you can't force senders to include one.

**Example:**
```aiken
pub type VestingDatum {
  beneficiary: VerificationKeyHash,
  deadline: Int,
}
```

**Related:** redeemer, script, eUTxO, spend, Option

## Delegation credentials

**Definition:** Optional part of an address that controls stake delegation and reward withdrawal. Like payment credentials, can be a verification key hash or script hash.

**Context:** Controls which stake pool receives delegation and how rewards are withdrawn.

**Related:** address, stake, withdrawal, credential, stake pool

## Destructuring

**Definition:** Extracting fields from a value by mirroring its construction syntax on the left side of an assignment. Works on records, tuples, lists, and custom types.

**Context:** Syntactic convenience for accessing inner values without dot notation.

**Example:**
```aiken
let Dog { name, cuteness, age } = dog
let (x, y) = point
let [head, ..tail] = list
```

**Related:** pattern matching, record, spread operator

## Deterministic

**Definition:** A computation whose output is entirely determined by its inputs with no randomness or external state. Cardano smart contracts are deterministic — given the same transaction, execution always produces the same result.

**Context:** Enables off-chain transaction evaluation before submission to the network.

**Related:** pure function, predicate, eUTxO, validity interval

## Documentation comment

**Definition:** Comments starting with `///` (triple slash) placed before definitions to generate HTML documentation. Supports Markdown, MathJax and Github-style admonitions (e.g. `[!NOTE] ...`). Module-level documentation uses `////` (quadruple slash).

**Context:** Processed by `aiken docs` to generate API documentation.

**Example:**
```aiken
/// Timeout, in number of **seconds**.
const timeout: Int = 60
```

**Related:** aiken docs, module, pub

## Double satisfaction

**Definition:** A vulnerability where one output payment satisfies multiple validator executions in the same transaction. Occurs when validators check payments without ensuring input-output uniqueness.

**Context:** Solved by tagging outputs with the input's OutputReference as inline datum.

**Related:** tagged outputs, validator, security

## `else` (fallback handler)

**Definition:** Special handler in a `validator` block that serves as a catch-all for unhandled script purposes. Takes a single `ScriptContext` argument. Defaults to `fail` when not explicitly defined.

**Context:** Validator keyword. Used when a validator doesn't need to handle all six purposes.

**Example:**
```aiken
validator my_script {
  mint(redeemer: Data, policy_id: PolicyId, self: Transaction) { todo }
  else(_ctx: ScriptContext) {
    fail @"unsupported purpose"
  }
}
```

**Related:** validator, handler, purpose, ScriptContext

## Enum

**Definition:** A custom type with multiple constructors, each representing a distinct variant. Constructors can have fields (like algebraic data types) or be fieldless.

**Context:** Used for redeemer actions, state machines, and any situation with distinct cases.

**Example:**
```aiken
pub type Action {
  Minting
  Burning
}
```

**Related:** constructor, pattern matching, algebraic data type

## Environment

**Definition:** A named build configuration (e.g., `default`, `mainnet`, `testnet`) selected at build time with `--env`. Drives conditional module selection and config value resolution.

**Context:** `aiken build --env mainnet` selects mainnet-specific modules and config values.

**Related:** config module, conditional module, aiken.toml

## Epoch

**Definition:** A fixed time period in Cardano (currently 5 days) during which stake delegation is active. Rewards are calculated and distributed at epoch boundaries.

**Context:** Stake snapshots, pool performance, and reward distribution all operate on epoch cycles.

**Related:** slot, stake pool, reward, delegation

## eUTxO (Extended UTxO)

**Definition:** Cardano's extension of the UTxO model that adds datums (state attached to outputs) and redeemers (user arguments at spend time), enabling smart contract logic while preserving determinism.

**Context:** The "extended" part is what makes smart contracts possible on Cardano. Scripts act as parameterized predicates.

**Related:** UTxO, datum, redeemer, script, deterministic

## `expect`

**Definition:** Keyword for non-exhaustive pattern matching that halts (fails) if the pattern doesn't match. Also used for boolean assertions — `expect condition` halts if false.

**Context:** Error handling keyword. Essential for unwrapping `Option` datums in validators. Generates automatic traces in verbose mode.

**Example:**
```aiken
expect Some(datum) = optional_datum
expect sum >= 0
```

**Related:** fail, pattern matching, trace, Option

## Expression

**Definition:** Any piece of code that evaluates to a value. In Aiken, everything is an expression — there are no statements. `if/else`, `when/is`, and blocks all return values.

**Context:** Core FP principle. Functions return the value of their last expression; no `return` keyword.

**Related:** block, functional programming, pure function

## `fail` (keyword)

**Definition:** Keyword that immediately halts validator execution, causing the validator to reject the transaction. Can include an optional message. Does not produce a compilation warning (unlike `todo`).

**Context:** Error handling keyword. Used when a code path should always reject.

**Example:**
```aiken
fn expect_some_value(opt: Option<a>) -> a {
  when opt is {
    Some(a) -> a
    None -> fail @"Expected a value but got None"
  }
}
```

**Related:** expect, todo, validator, predicate

## `fail` (annotation)

**Definition:** A test modifier annotation for tests and property-based tests that expects the test to always fail.

**Context:** Handy to write negative test scenarios from functions that fail and do not return a result. Aiken doesn't have support for exceptions and catching them.

**Related:** fail, property-based test, test

## `fail once`

**Definition:** A test modifier for property-based tests that expects the property to fail at least once. Succeeds at the first failed evaluation; fails if all 100 evaluations pass.

**Context:** Tests non-properties — verifies that certain inputs cause failures.

**Related:** fail, property-based test, test

## Finality

**Definition:** The point at which a transaction becomes immutable and permanent on the blockchain. Distinct from latency (time to first appear in a block). Depends on the proportion of adversarial stake.

**Context:** Recommended wait: ~100-150 blocks (30-50 min) for sensitive transactions; a few blocks for small payments.

**Related:** latency, block, Ouroboros, settlement

## First-class function

**Definition:** Functions that can be assigned to variables, passed as arguments, and returned from other functions — treated like any other value.

**Context:** Aiken functions are first-class, with one exception: they cannot be part of a data-type definition.

**Example:**
```aiken
fn twice(f: fn(t) -> t, x: t) -> t {
  f(f(x))
}
```

**Related:** anonymous function, function capturing, higher-order function

## `fn`

**Definition:** Keyword used to define named or anonymous functions in Aiken. Functions are first-class values that implicitly return their last expression.

**Context:** Core language keyword. All logic in Aiken is expressed through functions. Functions are private by default.

**Example:**
```aiken
fn add(x: Int, y: Int) -> Int {
  x + y
}
```

**Related:** pub, let, validator, anonymous function

## Forwarding validation

**Definition:** A pattern where a simple spending validator delegates logic to a withdrawal script that runs once per transaction. Reduces costs by avoiding redundant execution across multiple inputs.

**Context:** Exploits the fact that withdrawing 0 Lovelace is valid. Used in production dApps for budget optimization.

**Related:** withdrawal, spend, optimization, validator

## Function capturing

**Definition:** Shorthand for creating a new function by partially applying an existing function using `_` as a placeholder for the missing argument.

**Context:** Often used with the pipe operator to create transformation pipelines.

**Example:**
```aiken
fn add(x, y) { x + y }
let add_one = add(1, _)
add_one(2)  // 3
```

**Related:** pipe operator, anonymous function, partial application

## Fuzzer

**Definition:** An interface type for building pseudo-random value generators. Used in property-based tests to generate test inputs. Composed using primitives from `aiken/fuzz`.

**Context:** Testing type. Defined as `Fuzzer<a>` and introduced in test arguments with the `via` keyword.

**Example:**
```aiken
use aiken/fuzz

test prop_positive(n via fuzz.int()) {
  n * n >= 0
}
```

**Related:** property-based test, PRNG, Sampler, via, shrinking

## G1Element / G2Element / MillerLoopResult

**Definition:** Types specific to BLS12-381 cryptographic primitives. Used as operands and return values for pairing-based cryptography builtin functions.

**Context:** Advanced cryptography. Defined in CIP-0381. Used for zero-knowledge proofs and advanced signature schemes.

**Related:** cryptography, builtin, CIP-0381

## Generic type

**Definition:** A type parameterised by one or more type variables, allowing it to work with any concrete type. Denoted with lowercase type parameters in angle brackets.

**Context:** Used extensively in stdlib (List\<a\>, Option\<a\>, etc.) and for reusable data structures.

**Example:**
```aiken
type Box<inner_type> {
  inner: inner_type,
}
let int_box: Box<Int> = Box(42)
```

**Related:** type, Option, List, type parameter

## Genesis configuration

**Definition:** The initial state of the blockchain, defining the starting set of UTxOs. Provides the "first outputs" from which all subsequent transactions flow.

**Context:** Solves the chicken-and-egg problem of inputs needing previous outputs.

**Related:** UTxO, blockchain, initial state

## Governance

**Definition:** On-chain decision-making mechanisms introduced in the Conway era. Includes voting on proposals by delegate representatives, controlled by the `vote` and `propose` script purposes.

**Context:** The constitution guardrails script (propose purpose) can reject proposals programmatically.

**Related:** vote, propose, Conway era, constitution, DRep

## Hash digest

**Definition:** A fixed-size output produced by a cryptographic hash function. Used as tamper-proof identifiers for blocks, transactions, scripts, and keys. Cardano primarily uses Blake2b.

**Context:** Transaction IDs, policy IDs, credential hashes are all hash digests. 32 bytes for most things; 28 bytes for credentials.

**Related:** Blake2b, policy ID, address, cryptography

## `if/else`

**Definition:** Conditional expression that evaluates a boolean condition and returns one of two branches. Unlike imperative languages, `if` in Aiken is an expression that returns a value.

**Context:** Control flow keyword. Every branch must return a value of the same type.

**Example:**
```aiken
fn abs(x: Int) -> Int {
  if x < 0 { -x } else { x }
}
```

**Related:** when/is, Bool, expression

## Immutable / Immutability

**Definition:** The property that once a value is created, it cannot be changed. All values in Aiken are immutable. New values are created through transformation, not mutation.

**Context:** Fundamental FP principle. Prepending to a list creates a new list without changing the original.

**Related:** let, functional programming, pure function

## Inlining

**Definition:** The compiler optimization of replacing references to identifiers with their actual values in the generated code. All `const` values in Aiken are inlined.

**Context:** Makes constants zero-cost at runtime — they're replaced with their literal values. Sometimes used as an optimisation heuristic for short functions.

**Related:** const, compile-time, optimization

## Input

**Definition:** A reference to a previous UTxO, identified by the transaction hash that created it and the position of the output within that transaction. Spending an input destroys the referenced UTxO.

**Context:** Inputs are what make each UTxO spendable only once. The combination of transaction ID + output index is unique.

**Related:** UTxO, output, OutputReference, transaction

## Int

**Definition:** Arbitrary-sized integer type with no underflow or overflow. Supports decimal, binary (`0b`), octal (`0o`), and hexadecimal (`0x`) literals, plus `_` separators.

**Context:** The only number type in Aiken. Covers all numeric needs including Lovelace values.

**Example:**
```aiken
let amount = 1_000_000
let flags = 0b00001111
let hex_val = 0xFF
```

**Related:** ByteArray, arithmetic operators

## Labeled arguments

**Definition:** Function arguments that can be passed by label instead of position. Defined by giving argument names in the function signature.

**Context:** Improves readability for functions with many parameters. Labels can be overridden in the function body.

**Example:**
```aiken
fn replace(self: String, pattern: String, replacement: String) { ... }
replace(pattern: @",", replacement: @" ", self: @"A,B,C")
```

**Related:** fn, named arguments

## Labelling

**Definition:** A mechanism in property-based tests to track which paths are explored during random testing. Uses `fuzz.label()` to tag executions; distribution is shown in the test report.

**Context:** Useful for verifying fuzzer correctness and ensuring adequate path coverage.

**Related:** property-based testing, Fuzzer, fuzz.label

## Language Server Protocol (LSP)

**Definition:** A protocol for editor intelligence features (completion, diagnostics, go-to-definition). Aiken's CLI includes a built-in LSP server, invoked with `aiken lsp`.

**Context:** Configure with root pattern `aiken.toml` and filetype `.ak`.

**Related:** editor integration, aikup, auto-completion

## Language tag / Discriminator byte

**Definition:** A prefix byte added to scripts before hashing to distinguish script languages. Native = `0x00`, Plutus V1 = `0x01`, V2 = `0x02`, V3 = `0x03`.

**Context:** Explains why hashing a raw script gives a different result than the actual policy ID.

**Related:** policy ID, script hash, hash digest

## `let`

**Definition:** Keyword for declaring local variable bindings. Values assigned to let-bindings are immutable, but new bindings can shadow previous ones.

**Context:** Core language keyword. Cannot be used at the top level of a module — use `const` for module-level values.

**Example:**
```aiken
let x = 1
let y = x
let x = 2  // shadows previous x
// y + x == 3
```

**Related:** const, shadowing, immutable

## List

**Definition:** Ordered collection of values where all elements must be the same type. Implemented as a linked list. Prepending (`[x, ..rest]`) is fast; appending is slow.

**Context:** One of the most common data structures in Aiken. Used for transaction inputs, outputs, signatories, etc.

**Example:**
```aiken
let numbers: List<Int> = [1, 2, 3, 4]
let extended = [0, ..numbers]  // [0, 1, 2, 3, 4]
```

**Related:** Pair, Pairs, pattern matching, linked list

## Lovelace

**Definition:** The smallest indivisible unit of Ada. 1 Ada = 1,000,000 Lovelace. Named after Ada Lovelace.

**Context:** On-chain values are always expressed in Lovelace, not Ada.

**Related:** Ada, value, Int

## Minting policy

**Definition:** A script that controls the creation (minting) and destruction (burning) of user-defined assets. The policy's hash becomes the PolicyId for those assets.

**Context:** Cardano-specific. Validators with a `mint` handler. One-shot minting policies ensure uniqueness.

**Related:** PolicyId, mint, burn, NFT, one-shot minting

## Multivalidator

**Definition:** A single `validator` block in Aiken containing handlers for multiple purposes (e.g., both `mint` and `spend`). All handlers share the same script hash.

**Context:** Useful when minting and spending logic need to reference the same script hash (e.g., State Thread Tokens).

**Related:** validator, handler, purpose, script hash

## Native script

**Definition:** A pre-Plutus minimalistic scripting language with 6 constructors: key, all-of, any-of, n-of-m, after, before. Still exists and is useful for multisig addresses.

**Context:** Also called "phase-1 scripts." Simpler but less expressive than Plutus scripts.

**Related:** multisig, script, phase-1 validation

## Never

**Definition:** Type with a single constructor of the same name. Identical to `None` in serialisation. Used for `Option` values that can only ever be `None`.

**Context:** Exists due to historical ledger bugs requiring backward compatibility.

**Example:**
```aiken
let some: Data = None
let never: Data = Never
some == never  // True
```

**Related:** Option, None, backward compatibility

## NFT (Non-Fungible Token)

**Definition:** A unique, non-divisible token — exactly 1 unit exists with a unique asset name under a given policy. Created using one-shot minting policies to guarantee uniqueness.

**Context:** Enforced by making the minting policy unrepeatable (consuming a specific UTxO).

**Related:** minting policy, one-shot minting, PolicyId, asset

## One-shot minting policy

**Definition:** A minting policy parameterised with an `OutputReference` that requires the corresponding UTxO to be consumed. Since UTxOs can only be spent once, this guarantees the policy validates at most once.

**Context:** The standard pattern for creating NFTs and unique tokens on Cardano.

**Related:** minting policy, OutputReference, NFT, validator parameters

## `opaque`

**Definition:** Modifier for `pub type` that exports the type but hides its internal constructors and fields from external modules. External code can use the type but cannot construct or destructure it directly.

**Context:** Module encapsulation keyword. Used to enforce invariants by controlling type access. Makes the type non-serialisable.

**Example:**
```aiken
pub opaque type Counter {
  inner: Int,
}
```

**Related:** type, pub, module, encapsulation, data

## Option

**Definition:** Generic type with two constructors: `Some(a)` for present values and `None` for absent values. Built into the prelude; no import needed.

**Context:** Fundamental pattern for functions that may not produce a result. Spend handlers always receive `Option<Datum>`.

**Example:**
```aiken
fn get_head(xs: List<a>) -> Option<a> {
  when xs is {
    [] -> None
    [head, ..] -> Some(head)
  }
}
```

**Related:** None, Some, Never, expect, when/is

## Ordering

**Definition:** Type with three constructors: `Less`, `Equal`, `Greater`. Used when comparing two values of the same type. The stdlib provides `compare` functions for various types.

**Context:** Utility type for comparison operations.

**Related:** bytearray.compare, equality

## Ouroboros

**Definition:** The family of proof-of-stake consensus algorithms used by Cardano. The current variant is Ouroboros Praos. Determines block production and settlement finality.

**Context:** Defines the relationship between stake delegation and block production probability.

**Related:** stake pool, epoch, slot, finality, Ada

## Output

**Definition:** An object in a transaction that describes a value (quantity of assets), an address (spending conditions), and optionally a datum (data payload) and a script reference. Outputs become UTxOs once the transaction is confirmed.

**Context:** New outputs are created by transactions. They "appear" on the wall as new post-it notes.

**Related:** UTxO, input, address, value, datum

## OutputReference

**Definition:** A unique identifier for a UTxO, composed of a transaction ID (hash) and an output index (position). Used as the target type for `spend` handlers.

**Context:** Guarantees uniqueness — essential for one-shot minting policies. Type: `OutputReference { transaction_id: ByteArray, output_index: Int }`.

**Related:** input, UTxO, one-shot minting, spend

## Pair

**Definition:** A specific type for two values of potentially different types: `Pair<a, b>`. Distinct from 2-tuples because `List<Pair<a, b>>` serialises as a CBOR map (not an array of arrays). Elements accessed with `.1st` and `.2nd`.

**Context:** Used in Cardano ledger types internally. Only use Pair when you specifically need CBOR map serialisation; otherwise prefer 2-tuples.

**Example:**
```aiken
let foo = Pair(14, "aiken")
foo.1st == 14
```

**Related:** Tuple, Pairs, CBOR, serialisation

## Pairs

**Definition:** Type alias for `List<Pair<a, b>>` — an associative list. Serialises as a CBOR map.

**Context:** Common in script contexts. The stdlib provides a dedicated module of helpers for associative lists.

**Related:** Pair, List, dict, CBOR map

## Pattern matching

**Definition:** A mechanism for inspecting the shape of a value and extracting its components. Uses `when/is` for multi-branch matching and `expect` for single-pattern assertions.

**Context:** Core Aiken idiom. The compiler enforces exhaustiveness — every possible pattern must be handled.

**Related:** when/is, expect, destructuring, wildcard, constructor

## Payment credentials

**Definition:** The part of an address that defines the spending conditions. Takes one of two forms: a verification key hash (signature required) or a script hash (validator must not error).

**Context:** Script addresses use a script hash, enabling arbitrary validation logic.

**Related:** address, verification key, script hash, credential

## Phase-1 validation

**Definition:** Structural checks performed by the ledger before script execution. Includes verifying input references, minimum fees, validity intervals, and required signatures.

**Context:** If phase-1 fails, no scripts run and no fees are charged. Phase-2 is script execution.

**Related:** phase-2 validation, validity interval, transaction

## Phase-2 validation

**Definition:** The execution of on-chain scripts (validators). Occurs after phase-1 passes. No scripts in a transaction shall error for the transaction to be valid.

**Context:** If phase-2 fails, collateral is consumed but no state changes occur.

**Related:** phase-1 validation, validator, script, collateral

## `|>` (Pipe operator)

**Definition:** Operator that chains function calls by passing the result of the left expression as the first argument to the right function. Improves readability of sequential transformations.

**Context:** Functional programming idiom. Used extensively in Aiken for data transformation pipelines. Encourages the definition of functions with their main argument put first (like a `self` reference).

**Example:**
```aiken
fn transform(x) {
  x
  |> add(_, 3)
  |> multiply(_, 2)
}
```

**Related:** function capturing, backpassing, functional programming

## Plutus blueprint

**Definition:** A CIP-0057 compliant JSON file (`plutus.json`) generated by `aiken build`. Contains compiled UPLC code, hash digests for address calculation, and schema definitions for datums/redeemers.

**Context:** Framework-agnostic interoperability format. Automatically generated from Aiken type definitions.

**Related:** aiken build, UPLC, CIP-0057, validator, hash digest

## Plutus Core

**Definition:** The formal name for the on-chain smart contract language of Cardano. "Plutus" in the wild refers to Plutus Core (the VM language), PlutusTx (the Haskell framework), or the Plutus Platform broadly.

**Context:** Aiken is one of several languages that compile to (Untyped) Plutus Core.

**Related:** UPLC, PlutusTx, virtual machine, Aiken

## PlutusTx

**Definition:** A Haskell framework that uses a GHC compiler plugin to transform Haskell code into UPLC. Often confused with "Plutus" generically. Now also known as 'Plinth'.

**Context:** Uses Haskell tooling (GHC) but is not actually Haskell at runtime — it compiles to UPLC.

**Related:** Plutus Core, UPLC, Aiken, Haskell

## PolicyId

**Definition:** The hash digest of a minting policy script. Identifies a particular set of user-defined assets. Used as the target type for `mint` handlers.

**Context:** Same as the script hash since minting policies are scripts. 28 bytes long.

**Related:** mint, script hash, asset, token, NFT

## Predicate

**Definition:** A function that returns a boolean value (True or False). Validators are predicates — they determine whether a transaction operation is permitted.

**Context:** Fundamental concept for Cardano smart contracts. All validator handlers are predicates.

**Related:** validator, Bool, deterministic

## Prelude

**Definition:** The built-in module automatically available to all Aiken projects without import. Contains core types (`Bool`, `Option`, `Ordering`, `Void`, `Data`, `Never`) and fundamental constructors.

**Context:** Published at `aiken-lang/prelude` with HTML documentation.

**Related:** stdlib, module, built-in

## PRNG

**Definition:** Pseudo-Random Number Generator. An opaque type used internally by the property-based testing framework to produce random test values.

**Context:** Internal type, though available in the prelude. Users typically interact with it indirectly through the `Fuzzer` interface.

**Related:** Fuzzer, property-based test, aiken/fuzz

## Property-based testing

**Definition:** A testing methodology that generates random inputs to check general properties rather than specific cases. Aiken's integrated framework includes automatic shrinking to find minimal counterexamples.

**Context:** First-class citizen in Aiken. Uses `Fuzzer` via the `via` keyword.

**Related:** Fuzzer, shrinking, test, via, aiken/fuzz

## `pub`

**Definition:** Keyword that makes a function, type, or constant publicly accessible outside its defining module. Without `pub`, definitions are private by default.

**Context:** Module system keyword. Required for any definition you want to export for use by other modules.

**Example:**
```aiken
pub fn public_function(x: Int) -> Int {
  x * 2
}

pub type Action {
  Minting
  Burning
}
```

**Related:** fn, module, use, type

## Pure function

**Definition:** A function whose output depends only on its inputs with no side effects. All functions in Aiken, and in particular validators, are pure functions. For validators: given the same transaction, they always produce the same result.

**Context:** Core FP concept. Ensures deterministic execution of smart contracts.

**Related:** deterministic, predicate, validator, expression

## Receipt pattern

**Definition:** A minting pattern that creates a unique token whose asset name is derived from the first input's `OutputReference` (via `blake2b_256` of its CBOR serialisation). Ensures one receipt per transaction.

**Context:** Alternative to one-shot minting for per-transaction uniqueness rather than global uniqueness.

**Related:** one-shot minting, blake2b, cbor.serialise

## Record

**Definition:** A custom type with a single constructor and named fields. Fields are accessed using dot notation.

**Context:** Used for structuring datum types, configuration, and any typed data with named fields.

**Example:**
```aiken
type Dog {
  name: ByteArray,
  cuteness: Int,
  age: Int,
}
let d = Dog { name: "Bob", cuteness: 100, age: 3 }
d.name  // "Bob"
```

**Related:** constructor, destructuring, type, custom type

## Recursion

**Definition:** A function calling itself to solve problems by breaking them into smaller subproblems. The primary looping mechanism in Aiken since there are no `for`/`while` loops.

**Context:** Essential for iterating over lists, trees, and any repeated computation. Anonymous functions cannot be recursive.

**Example:**
```aiken
fn factorial(n: Int) -> Int {
  if n <= 1 { 1 } else { n * factorial(n - 1) }
}
```

**Related:** list, functional programming, tail recursion

## Redeemer

**Definition:** A piece of data provided in a transaction for any script execution. Acts as the user's argument or action instruction to the validator. Unlike datums, redeemers are provided at spend time, not creation time.

**Context:** Cardano-specific. Every handler receives a redeemer. Each handler can define its own redeemer type.

**Example:**
```aiken
pub type SpendAction {
  Claim
  Cancel
}
```

**Related:** datum, script, eUTxO, validator, handler

## Sampler

**Definition:** A function type `fn(Int) -> Fuzzer<a>` used for benchmarks. Takes a size parameter and returns a fuzzer, allowing input complexity to grow with each benchmark iteration.

**Context:** Benchmarking type. Introduced with `via` in `bench` definitions.

**Related:** Fuzzer, bench, via

## Script

**Definition:** On-chain code that defines validation logic as a predicate function. Must return True for the guarded operation to be permitted. Also called a "validator."

**Context:** Scripts are provided as witnesses in transactions along with any required datums and redeemers. Scripts are fully deterministic.

**Related:** validator, predicate, witness, purpose, Plutus Core

## Script purpose

**Definition:** The reason a script is being executed. Cardano has six purposes: `mint`, `spend`, `withdraw`, `publish`, `vote`, `propose`. Passed to the script alongside the transaction and redeemer.

**Context:** Only `spend` receives a datum. Each purpose has a different target type.

**Related:** handler, validator, mint, spend, withdraw, publish, vote, propose

## ScriptContext

**Definition:** The full execution context provided to a validator, containing the transaction, the script purpose, and purpose-specific data. In Aiken, handlers destructure this automatically.

**Context:** The fallback `else` handler receives the raw ScriptContext. Standard handlers receive pre-extracted components.

**Related:** Transaction, purpose, handler, validator

## Serialisation

**Definition:** The process of converting a structured value into a binary (e.g. CBOR) representation for on-chain storage or network transmission. The reverse is deserialisation. Also known as 'marshalling'.

**Context:** Aiken types are all `Data` at validator boundaries, which serialises to CBOR. Multiple valid serialisations can exist for the same logical value.

**Related:** CBOR, Data, deserialisation, blueprint

## Shadowing

**Definition:** Re-using an already declared identifier (e.g. introduced via `let` or function arguments) for a new value making the original inaccessible (shadowed) in the current scope. The original value is not changed.

**Context:** Common in functional programming. Different from mutation — the original binding still exists; it's just no longer reachable by name.

**Related:** let, immutable

## Shelley era

**Definition:** The era that introduced the current address format, stake delegation, and decentralised block production.

**Related:** address, delegation, stake pool, Byron era

## Shrinking

**Definition:** The process of automatically simplifying a counterexample found during property-based testing to the smallest input that still fails. Integrated into Aiken's framework — no manual shrink definitions needed.

**Context:** E.g., if `[-2, 441, 7863]` fails, the framework may shrink it to `[-1]`.

**Related:** property-based testing, Fuzzer, counterexample

## Slot

**Definition:** The smallest time unit in Cardano's consensus protocol. Each slot is 1 second and may or may not contain a block.

**Context:** Block production is probabilistic — not every slot produces a block (~20 seconds average between blocks).

**Related:** block, epoch, validity interval

## Spread operator (`..`)

**Definition:** Used in patterns to indicate that remaining fields or list elements are ignored. Can be named in list patterns to capture the tail.

**Context:** Useful when you only need a subset of fields from a record or the head of a list.

**Example:**
```aiken
let Dog { name, .. } = dog
let [head, ..tail] = my_list
```

**Related:** destructuring, wildcard, list

## Stake pool

**Definition:** A registered entity on Cardano that participates in block production via the Ouroboros consensus protocol. Delegators assign their stake to pools in exchange for a share of rewards.

**Context:** Stake delegation is controlled by delegation credentials in addresses.

**Related:** delegation credentials, stake, reward, epoch

## Standard library (stdlib)

**Definition:** Aiken's community-maintained library of useful functions and data structures (`aiken-lang/stdlib`). Covers lists, dicts, math, crypto, transaction types, assets, addresses, and more.

**Context:** Automatically added by `aiken new`. A great reference for well-written Aiken code.

**Related:** prelude, aiken/fuzz, dependency, aiken.toml

## State Thread Token (STT)

**Definition:** An NFT used to track mutable state across transactions. The token is always forwarded to a new output with an updated datum, creating a "thread" of state changes.

**Context:** Common pattern for counters, registries, and any on-chain state machine.

**Related:** NFT, one-shot minting, datum, multivalidator

## String

**Definition:** UTF-8 text type, prefixed with `@`. Used exclusively for tracing and debugging — not for on-chain data or validator interfaces.

**Context:** Narrow use case. Comes with a limited set of primitives. For on-chain data, always use ByteArray instead.

**Example:**
```aiken
let greeting: String = @"Hello, Aiken!"
trace @"Debug message"
```

**Related:** ByteArray, trace, UTF-8

## Tagged outputs

**Definition:** Outputs marked with a unique identifier (typically the input's `OutputReference` as inline datum) to prevent double satisfaction. Each validator execution can only "claim" outputs with its own tag.

**Context:** Solution to the double satisfaction vulnerability.

**Related:** double satisfaction, OutputReference, inline datum

## `test`

**Definition:** Keyword for defining unit tests. Tests are named functions with no arguments that return Bool or Void. They execute on the same virtual machine as on-chain contracts.

**Context:** Testing keyword. Run with `aiken check`. Tests also serve as benchmarks by reporting memory/CPU execution units.

**Example:**
```aiken
test simple_addition() {
  let result = 2 + 3
  result == 5
}
```

**Related:** property-based test, fuzzer, bench, aiken check

## `todo`

**Definition:** Keyword that halts execution like `fail` but additionally produces a compilation warning. Used as a placeholder during development for unfinished logic.

**Context:** Development keyword. Reminds you of incomplete code paths. Also provides the expected type of the placeholder in the error message so can be used to debug complex types.

**Example:**
```aiken
fn favourite_number() -> Int {
  todo @"Implement this later"
}
```

**Related:** fail, expect

## `trace`

**Definition:** Keyword for logging debug messages during validator execution. Variadic — accepts a label and any number of serialisable values. Traces are collected by the virtual machine and displayed during testing or simulation.

**Context:** Debugging keyword. Removed by default on `aiken build`; kept by default on `aiken check`.

**Example:**
```aiken
fn is_even(n: Int) -> Bool {
  trace @"checking": n
  n % 2 == 0
}
```

**Related:** ? operator, troubleshooting, CBOR diagnostic, trace level

## Trace level

**Definition:** A build/check option controlling trace output: `silent` (no traces), `compact` (labels only), or `verbose` (full traces with values).

**Context:** Traces increase code size and change the validator hash. Use `silent` for production.

**Related:** trace, ? operator, aiken build, aiken check

## `?` (Trace-if-false operator)

**Definition:** Postfix operator appended to any boolean expression that generates a trace only when the expression evaluates to `False`. Useful for debugging conjunctions/disjunctions of conditions.

**Context:** Debugging operator. Affected by `--trace-level` options.

**Example:**
```aiken
must_say_hello? && must_be_signed?
// If must_be_signed is False, traces: "must_be_signed ? False"
```

**Related:** trace, validator, and/or

## Transaction

**Definition:** The fundamental primitive for changing blockchain state. Contains inputs (references to existing UTxOs), outputs (new UTxOs to create), and additional fields like minting, certificates, withdrawals, and validity intervals. Must be atomic — all-or-nothing.

**Context:** The last argument of every validator handler is a `Transaction`. Provides the full execution context.

**Related:** UTxO, input, output, validator, block

## Tuple

**Definition:** Fixed-size grouping of values where each element can have a different type. Elements accessed with ordinal syntax (`.1st`, `.2nd`, `.3rd`, `.4th`). Discouraged for more than 3 elements — use records instead.

**Context:** Quick anonymous data grouping. Serialises to CBOR array.

**Example:**
```aiken
let point: (Int, Int) = (14, 42)
let x = point.1st  // 14
```

**Related:** Pair, record, custom type

## `type`

**Definition:** Keyword for defining custom data types including records, enums, and generic algebraic data types. Also used for type aliases.

**Context:** Core language keyword. Custom types are the primary way to structure datums, redeemers, and contract state.

**Example:**
```aiken
type RGB {
  red: Int,
  green: Int,
  blue: Int,
}

pub type Action {
  Minting
  Burning
}

type Point = (Int, Int)
```

**Related:** constructor, record, enum, generic, alias

## Type alias

**Definition:** A new name for an existing type expression. Does not create a new type — just a shorthand.

**Context:** Improves readability for complex type combinations.

**Example:**
```aiken
type CartesianCoordinates = (Int, Int)
type VerificationKeyHash = Hash<Blake2b_224, VerificationKey>
```

**Related:** type, generic

## Type annotation

**Definition:** Explicit declaration of a value's or function's type. While optional due to type inference, annotations serve as documentation and catch errors early.

**Context:** Best practice for function signatures and public APIs.

**Example:**
```aiken
fn add(x: Int, y: Int) -> Int { x + y }
const name: ByteArray = "Aiken"
```

**Related:** type inference, fn, const

## Type inference

**Definition:** The compiler's ability to determine types automatically without explicit annotations. Aiken can infer all types, making annotations optional (but recommended for documentation).

**Context:** Aiken has complete type inference. Annotated and unannotated code is equally safe.

**Example:**
```aiken
fn add_inferred(a, b) { a + b }  // compiler infers Int -> Int -> Int
```

**Related:** type annotation, static typing, generic

## Untyped Plutus Core (UPLC)

**Definition:** The low-level lambda-calculus-based language that is actually executed by Cardano's virtual machine. All smart contract languages compile to UPLC. Has 7 primitive types and built-in functions.

**Context:** Aiken compiles to UPLC. Understanding UPLC helps with troubleshooting and optimization.

**Related:** Plutus Core, virtual machine, compile, aiken build

## `use`

**Definition:** Keyword for importing modules, types, and functions into the current scope. Supports qualified, unqualified, and aliased imports.

**Context:** Module system keyword. Used at the top of files to bring external definitions into scope.

**Example:**
```aiken
use aiken/collection/list
use aiken/collection/list.{at}
use aiken/collection/list as my_list
```

**Related:** module, pub, import

## UTxO (Unspent Transaction Output)

**Definition:** An output from a previous transaction that has not yet been consumed (spent). UTxOs are the fundamental units of state on Cardano — the blockchain state is the set of all existing UTxOs.

**Context:** Think of UTxOs as post-it notes on a wall. Each has a value and an address. Spending a UTxO destroys it and creates new ones. Each can only be spent once.

**Related:** eUTxO, input, output, transaction, address

## `validator`

**Definition:** Keyword that defines a named block containing one or more handler functions corresponding to Cardano script purposes. Validators are the entry points for on-chain smart contract logic.

**Context:** Core Aiken keyword for smart contracts. Validators are predicates — they return True (allow) or False/fail (reject).

**Example:**
```aiken
validator hello_world {
  spend(datum: Option<MyDatum>, redeemer: MyRedeemer, _ref: OutputReference, self: Transaction) {
    todo @"logic here"
  }
  else(_) { fail }
}
```

**Related:** handler, purpose, datum, redeemer, Transaction

## Validity interval

**Definition:** An optional time window (lower and/or upper bound) on a transaction, checked during phase-1 validation. Scripts can assume the transaction is within this interval, enabling time-dependent logic without breaking determinism.

**Context:** Introduces time into deterministic scripts. Can be as narrow as one second.

**Related:** phase-1 validation, deterministic, slot, POSIXTime

## Value

**Definition:** The quantity of assets held in a UTxO. Includes Ada and optionally user-defined tokens, each identified by a PolicyId and asset name.

**Context:** Transactions must balance — total value in must equal total value out (plus fees).

**Related:** Ada, asset, PolicyId, output

## `via`

**Definition:** Keyword used in property-based tests and benchmarks to introduce a `Fuzzer` or `Sampler` for generating random test inputs.

**Context:** Testing annotation keyword. Directly associates a generator with a test argument.

**Example:**
```aiken
test prop_commutative((a, b) via fuzz.both(fuzz.int(), fuzz.int())) {
  a + b == b + a
}
```

**Related:** Fuzzer, Sampler, property-based test, bench

## Virtual machine

**Definition:** The execution environment that interprets UPLC code on-chain. Implemented in Haskell in the main Cardano node and in Rust by Aiken.

**Context:** Both implementations execute the same UPLC programs identically. Aiken's tests run on the same VM.

**Related:** UPLC, Plutus Core, deterministic

## Void

**Definition:** Type representing the nullary constructor — the absence of value. Denoted `Void` as both type and constructor. Equivalent to a zero-element tuple.

**Context:** Rarely needed directly since everything in Aiken is a typed expression. Occasionally used as a return type.

**Related:** Never, Option, expression

## `when/is`

**Definition:** Pattern matching expression that inspects a value and executes different branches based on its shape. Must be exhaustive — all possible constructors must be handled.

**Context:** Core control flow keyword. The primary mechanism for branching logic in Aiken.

**Example:**
```aiken
fn describe(opt: Option<Int>) -> String {
  when opt is {
    Some(value) -> @"Has a value"
    None -> @"Empty"
  }
}
```

**Related:** pattern matching, wildcard, destructuring, constructor

## Wildcard

**Definition:** A pattern denoted `_` (or any identifier starting with `_`) that matches any value without binding it to a name. Used in pattern matching when a value is not needed.

**Context:** Use sparingly — explicit patterns are preferred because wildcards hide new constructors added later.

**Example:**
```aiken
when user is {
  LoggedIn { username } -> username
  _ -> "Guest"  // catches everything else
}
```

**Related:** pattern matching, when/is, spread operator

## Withdrawal

**Definition:** A transaction field that moves accumulated staking rewards from a reward account to UTxOs. Sets the account balance to zero and adds the value as virtual input.

**Context:** Can be controlled by a script (withdraw purpose). Withdrawing 0 Lovelace is valid — exploited by the forwarding validation pattern.

**Related:** reward, stake, withdraw purpose, forwarding validation

## Witness

**Definition:** Proof provided alongside a transaction to satisfy spending or validation conditions. Includes digital signatures, scripts, datums, and redeemers.

**Context:** When spending from a script address, the entire script must be provided as a witness.

**Related:** signature, script, datum, redeemer, transaction

## Workspace

**Definition:** Support for monorepos via the `members` field in `aiken.toml`. Allows multiple Aiken sub-projects under a single root, with glob support.

**Context:** Early feature with caveats: no local path dependencies, redundant dependency fetching, limited LSP support.

**Related:** aiken.toml, project structure
