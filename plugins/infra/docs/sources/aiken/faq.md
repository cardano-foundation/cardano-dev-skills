# Aiken Language — Frequently Asked Questions

---

## Q1: What is Aiken?

**Answer:** Aiken is a modern, purely functional programming language designed specifically for writing smart contracts (validators) on the Cardano blockchain. It compiles down to Untyped Plutus Core (UPLC), which is the low-level interpreted code executed by Cardano's virtual machine. Despite sometimes being mistaken for Rust, Aiken is its own language — its compiler simply happens to be written in Rust.

**Key Points:**
- Purpose: Smart contracts (validators) for Cardano
- Paradigm: Purely functional, statically typed with type inference
- Syntax: Rust-inspired but not Rust
- Compiles to: Untyped Plutus Core (UPLC)
- Not: A general-purpose language; not Haskell; not PlutusTx

**Example:**
```aiken
validator hello_world {
  spend(datum: Option<MyDatum>, redeemer: MyRedeemer, _own_ref: OutputReference, self: Transaction) {
    todo @"validator logic goes here"
  }
}
```

**Related:** [Installation](#q3-how-do-i-install-aiken) | [First Validator](#q10-how-do-i-write-my-first-validator)

---

## Q2: How is Aiken different from Plutus (PlutusTx)?

**Answer:** Aiken and PlutusTx both compile to Untyped Plutus Core (UPLC), but they differ significantly in approach. PlutusTx is an embedded Haskell framework that uses a GHC plugin to transform Haskell's intermediate representation into UPLC. Aiken, by contrast, is a standalone language with its own compiler, syntax, and tooling — built from the ground up for the Cardano smart contract use case.

**Key Points:**
- Aiken is a standalone language with a purpose-built compiler; PlutusTx is a Haskell framework/plugin
- Aiken has Rust-inspired syntax; PlutusTx uses Haskell syntax
- Aiken includes integrated testing, benchmarks, and a language server out of the box
- Aiken aims for simplicity — no higher-kinded types or typeclasses (at present)
- Both compile to the same UPLC target, so on-chain they are equivalent in capability
- Cardano does **not** run Haskell on-chain — it runs UPLC regardless of source language

**Related:** [Ecosystem Overview](#q35-what-other-languages-can-i-use-for-cardano-smart-contracts)

---

## Q3: How do I install Aiken?

**Answer:** The recommended way to install Aiken is through `aikup`, a cross-platform utility for downloading and managing multiple Aiken versions. Once `aikup` is installed, simply running `aikup` installs the latest version. You can also install specific versions by providing a version number.

**Key Points:**
- `aikup` is the primary installation method
- Supports npm, Homebrew, and direct URL install
- Works on Linux, macOS, and Windows

**Example:**
```bash
# Via npm
npm install -g @aiken-lang/aikup

# Via Homebrew
brew install aiken-lang/tap/aikup

# Via URL (Linux & macOS)
curl --proto '=https' --tlsv1.2 -LsSf https://install.aiken-lang.org | sh

# Via URL (Windows)
powershell -c "irm https://windows.aiken-lang.org | iex"

# Then install Aiken
aikup
```

**Related:** [Editor Setup](#q4-which-editors-support-aiken) | [Creating a Project](#q5-how-do-i-create-a-new-aiken-project)

---

## Q4: Which editors support Aiken?

**Answer:** Aiken has editor plugins providing syntax highlighting and indentation rules for all major editors. It also ships with a built-in Language Server Protocol (LSP) implementation for advanced features like code completion and diagnostics.

**Key Points:**
- **Zed:** `aiken-lang/zed-aiken`
- **VSCode:** `aiken-lang/vscode-aiken`
- **Vim/Neovim:** `aiken-lang/editor-integration-nvim`
- **Emacs:** `aiken-lang/aiken-mode`
- **JetBrains:** `MedusaLabs-cardano/intellij_aiken`
- LSP command: `aiken lsp` (hidden from CLI help)
- Root pattern: `aiken.toml`
- File type: `.ak`

**Related:** [Installation](#q3-how-do-i-install-aiken) | [Auto-completion](#q3-how-do-i-install-aiken)

---

## Q5: How do I create a new Aiken project?

**Answer:** Use the `aiken new` command followed by an `{organisation}/{repository}` name. This scaffolds a project with the standard folder structure, configuration file, and a placeholder validator.

**Key Points:**
- Command: `aiken new foo/bar`
- Creates `aiken.toml`, `lib/`, `validators/`, and `README.md`
- The standard library is automatically added as a dependency
- Library code goes in `lib/`; validators go in `validators/`

**Example:**
```bash
aiken new aiken-lang/hello-world
cd hello-world
```

Resulting structure:
```
.
├── README.md
├── aiken.toml
├── lib
│   └── hello-world
└── validators
```

**Related:** [Project Structure](#q6-what-is-the-project-structure-of-an-aiken-project) | [Compiling](#q7-how-do-i-compile-an-aiken-project)

---

## Q6: What is the project structure of an Aiken project?

**Answer:** Aiken projects split source code into two categories: library code (in `lib/`) and application code, i.e. on-chain validators (in `validators/`). The project root contains an `aiken.toml` configuration file. After compilation, a Plutus blueprint (`plutus.json`) is generated containing compiled validator code and hash digests.

**Key Points:**
- `lib/` — Reusable library modules
- `validators/` — On-chain validator source files (`.ak`)
- `env/` — Environment-specific code that can be conditionally included  
- `aiken.toml` — Project metadata, dependencies, and configuration
- `plutus.json` — Generated Plutus blueprint (CIP-0057) after build
- `build/` — Build artifacts and fetched dependencies

**Example (`aiken.toml`):**
```toml
name = "foo/bar"
version = "1.0.0"
licence = "Apache-2.0"
description = "A next-level DeFi platform"

[[dependencies]]
source = "github"
name = "aiken-lang/stdlib"
version = "main"
```

**Related:** [Creating a Project](#q5-how-do-i-create-a-new-aiken-project) | [Compiling](#q7-how-do-i-compile-an-aiken-project)

---

## Q7: How do I compile an Aiken project?

**Answer:** Use `aiken build` to compile your project, which generates the Plutus blueprint (`plutus.json`). Use `aiken check` to type-check and run tests without producing a full build. For library projects, `aiken docs` generates HTML documentation from types, annotations, and comments.

**Key Points:**
- `aiken build` — Full compile, generates `plutus.json`
- `aiken check` — Type-check + run tests only
- `aiken bench` — Type-check + run benchmarks only
- `aiken docs` — Generate HTML documentation
- `aiken blueprint` — Generate addresses, apply parameters, convert formats
- Traces are removed by default on `aiken build` (use `--trace-level verbose` to keep them)
- Traces are kept by default on `aiken check`

**Related:** [Testing](#q17-how-do-i-test-validators-in-aiken) | [Troubleshooting](#q24-how-do-i-debug-and-troubleshoot-validators)

---

## Q8: What is the eUTxO model?

**Answer:** The Extended Unspent Transaction Output (eUTxO) model is Cardano's transaction model. In this model, transactions consume existing UTxOs (inputs) and produce new UTxOs (outputs). Each output has a value (assets) and an address (spending conditions). The "extended" part adds datums and redeemers, enabling stateful smart contract logic while maintaining full determinism.

**Key Points:**
- A UTxO (Unspent Transaction Output) has a value and an address
- Inputs reference previous outputs; spent outputs are destroyed
- Transactions are atomic: all-or-nothing
- The eUTxO extension adds datums (state/config attached to outputs) and redeemers (user arguments provided at spending time)
- Scripts (validators) are akin to deterministic predicates — conceptually, they return True or False
- The initial state comes from the genesis configuration

**Related:** [Datums & Redeemers](#q9-what-are-datums-and-redeemers) | [Addresses](#q12-how-do-cardano-addresses-work)

---

## Q9: What are datums and redeemers?

**Answer:** Datums and redeemers are the two key data components in the eUTxO model that enable smart contract logic. A datum is a data payload attached to an output when it is created — think of it as the contract's state or configuration. A redeemer is a piece of data provided in a transaction when attempting to spend an output — think of it as the user's argument or action. Together with the script (validator), they form a parameterized predicate function.

**Key Points:**
- **Datum** = Function parameters; set when output is created; attached to the UTxO
- **Redeemer** = Function argument; provided when spending the output
- **Script/Validator** = The function itself; defines the validation logic
- Only `spend` purpose scripts have access to a datum
- The datum is always `Option<T>` in spend handlers since you can't prevent someone from sending assets without a datum
- Together, they make scripts fully deterministic — execution depends only on the transaction context

**Example:**
```aiken
pub type Datum {
  owner: VerificationKeyHash,
}

pub type Redeemer {
  msg: ByteArray,
}

validator hello_world {
  spend(datum: Option<Datum>, redeemer: Redeemer, _own_ref: OutputReference, self: Transaction) {
    expect Some(Datum { owner }) = datum
    let must_say_hello = redeemer.msg == "Hello, World!"
    let must_be_signed = list.has(self.extra_signatories, owner)
    must_say_hello && must_be_signed
  }
}
```

**Related:** [eUTxO Model](#q8-what-is-the-eutxo-model) | [Validators](#q10-how-do-i-write-my-first-validator)

---

## Q10: How do I write my first validator?

**Answer:** Validators are defined using the `validator` keyword and contain one or more handler functions corresponding to script purposes (mint, spend, withdraw, publish, vote, propose). Each handler is a predicate that must return True to authorize the operation. The "Hello, World!" tutorial walks through creating a basic spend validator.

**Key Points:**
- Use the `validator` keyword with a name
- Define handlers matching Cardano's script purposes
- Handlers return `Bool` — `True` authorizes, `False` (or `fail`) rejects
- `spend` handlers take 4 arguments: optional datum, redeemer, output reference, and transaction
- Other handlers take 3 arguments: redeemer, target (purpose-dependent), and transaction
- A fallback `else` handler catches unhandled purposes

**Example:**
```aiken
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{OutputReference, Transaction}

pub type Datum {
  owner: VerificationKeyHash,
}

pub type Redeemer {
  msg: ByteArray,
}

validator hello_world {
  spend(datum: Option<Datum>, redeemer: Redeemer, _own_ref: OutputReference, self: Transaction) {
    expect Some(Datum { owner }) = datum
    let must_say_hello = redeemer.msg == "Hello, World!"
    let must_be_signed = list.has(self.extra_signatories, owner)
    must_say_hello && must_be_signed
  }
  else(_ctx) {
    fail
  }
}
```

**Related:** [Datums & Redeemers](#q9-what-are-datums-and-redeemers) | [Testing](#q17-how-do-i-test-validators-in-aiken)

---

## Q11: What are the six validator purposes in Aiken?

**Answer:** Aiken supports all six Cardano script purposes, each controlling a different type of on-chain operation. Each purpose determines the target argument type passed to the handler.

**Key Points:**
- **`mint`** — Controls minting/burning of user-defined assets. Target: `PolicyId`
- **`spend`** — Controls spending of transaction outputs. Target: `OutputReference`. Only purpose with access to a datum.
- **`withdraw`** — Controls withdrawal of staking rewards. Target: `Credential`
- **`publish`** — Controls publication of delegation certificates. Target: `Certificate`
- **`vote`** — Validates governance votes from script delegate representatives. Target: `Voter`
- **`propose`** — Constitution guardrails; validates governance proposals. Target: `ProposalProcedure`. Only one such script can exist in the entire ledger.

**Example:**
```aiken
validator my_script {
  mint(redeemer: MyRedeemer, policy_id: PolicyId, self: Transaction) { todo }
  spend(datum: Option<MyDatum>, redeemer: MyRedeemer, utxo: OutputReference, self: Transaction) { todo }
  withdraw(redeemer: MyRedeemer, account: Credential, self: Transaction) { todo }
  publish(redeemer: MyRedeemer, certificate: Certificate, self: Transaction) { todo }
  vote(redeemer: MyRedeemer, voter: Voter, self: Transaction) { todo }
  propose(redeemer: MyRedeemer, proposal: ProposalProcedure, self: Transaction) { todo }
}
```

**Related:** [Validators](#q10-how-do-i-write-my-first-validator) | [Parameters](#q13-how-do-validator-parameters-work)

---

## Q12: How do Cardano addresses work?

**Answer:** A Cardano address is made of 2 or 3 parts: a header (describes address type and network), payment credentials (spending conditions), and optional delegation credentials (staking control). Credentials can be either a verification key hash (for signature-based spending) or a script hash (for script-based validation).

**Key Points:**
- **Header** — Defines address type and network discriminant (mainnet vs. testnet)
- **Payment credentials** — Controls spending; either a verification key hash or script hash
- **Delegation credentials** — Optional; controls stake delegation and reward withdrawal
- Script addresses use a script hash as payment credentials, enabling arbitrary validation logic
- Addresses are typically encoded in bech32 or base16 (hex) format
- Byron (legacy) addresses are deprecated and forbidden in Plutus script transactions

**Related:** [eUTxO Model](#q8-what-is-the-eutxo-model) | [Scripts & Datums](#q9-what-are-datums-and-redeemers)

---

## Q13: How do validator parameters work?

**Answer:** Validators can take parameters, which are configuration values that become embedded in the compiled validator code. Once provided, parameters are part of the on-chain script and affect its hash and address. Parameters must be supplied before any address can be calculated.

**Key Points:**
- Defined in parentheses after the validator name
- Accessible to all handlers within the validator
- Must be serialisable (non-opaque) data types
- Common use: parameterizing with a UTxO reference for one-shot minting policies
- Parameters are applied using the `aiken blueprint` command group

**Example:**
```aiken
use aiken/collection/list
use cardano/assets.{PolicyId}
use cardano/transaction.{Transaction, OutputReference}

validator my_script(utxo_ref: OutputReference) {
  mint(redeemer: Data, policy_id: PolicyId, self: Transaction) {
    expect list.any(
      self.inputs,
      fn(input) { input.output_reference == utxo_ref }
    )
    todo @"rest of the logic goes here"
  }
}
```

**Related:** [Validators](#q10-how-do-i-write-my-first-validator) | [One-Shot Minting](#q26-what-is-a-one-shot-minting-policy)

---

## Q14: What are Aiken's primitive types?

**Answer:** Aiken has 6 primitive types that can be written as literals: `Bool`, `Int`, `ByteArray`, `String`, `Data`, and `Void`. It also provides built-in compound types: `List`, `Tuple`, `Pair`, and `Option`.

**Key Points:**
- **Bool** — `True` or `False`. Supports `&&`, `||`, `!`, `==`, `?` operators
- **Int** — Arbitrary-sized integers (no overflow). Supports `_` separators, binary (`0b`), octal (`0o`), hex (`0x`)
- **ByteArray** — Array of bytes. Three notations: byte array (`#[10, 255]`), UTF-8 string (`"foo"`), hex string (`#"666f6f"`)
- **String** — UTF-8 text prefixed with `@` (e.g., `@"Hello"`). Used only for tracing/debugging
- **Data** — Opaque type representing any serialisable value; a wildcard type
- **Void** — Nullary constructor representing absence of value
- **Option\<a\>** — `Some(a)` or `None`; built-in for optional values
- **List\<a\>** — Ordered, homogeneous collection
- **Pair\<a, b\>** — Two-element pair, serialises as CBOR map entries

**Example:**
```aiken
const my_int: Int = 1_000_000
const my_bool: Bool = True
const my_bytes: ByteArray = "Hello"
const my_hex: ByteArray = #"666f6f"
const my_string: String = @"Hello, Aiken!"
const my_list: List<Int> = [1, 2, 3]
const my_tuple: (Int, ByteArray) = (1, "one")
```

**Related:** [Custom Types](#q15-how-do-i-define-custom-types) | [Variables & Constants](#q16-how-do-variables-and-constants-work)

---

## Q15: How do I define custom types?

**Answer:** Custom types in Aiken are defined using the `type` keyword. They can be records (with named fields), enums (multiple constructors), or generic algebraic data types. Custom types are the primary way to structure data for datums, redeemers, and internal logic.

**Key Points:**
- Records have named fields and a single constructor
- Enums have multiple constructors (with or without fields)
- Generics are supported with type parameters
- Types can be aliased with `type Alias = ExistingType`
- All custom types are serialisable to `Data` and can be pattern-matched
- `pub` makes types available outside the module
- Fields can be updated with spread syntax: `MyType { ..record, field: new_value }`

**Example:**
```aiken
// Record type
type RGB {
  red: Int,
  green: Int,
  blue: Int,
}

// Enum type
pub type Action {
  Minting
  Burning
}

// Generic type
pub type Option<a> {
  None
  Some(a)
}

// Type alias
type CartesianCoordinates = (Int, Int)

// Updating fields
fn set_red_255(rgb: RGB) {
  RGB { ..rgb, red: 255 }
}
```

**Related:** [Primitive Types](#q14-what-are-aikens-primitive-types) | [Pattern Matching](#q20-how-does-pattern-matching-work-in-aiken)

---

## Q16: How do variables and constants work?

**Answer:** Aiken uses `let` bindings for variables and `const` for module-level constants. All values are immutable — there is no mutable state. New bindings can shadow previous bindings. Constants are fully evaluated at compile-time and inlined by the compiler.

**Key Points:**
- `let` — Local variable binding; immutable; can shadow previous bindings
- `const` — Module-level constant; inlined at compile-time; can reference other constants (defined earlier)
- No top-level `let` bindings — use `const` for module-level values
- Constants can hold almost any Aiken expression
- Type annotations are optional but recommended for documentation

**Example:**
```aiken
// Constants
const start_year = 2101
const summer = "Summer"
const seasons = [summer, "Autumn", "Winter", "Spring"]

// Variables
let x = 1
let y = x
let x = 2  // shadows previous x
// y + x == 3
```

**Related:** [Functions](#q19-how-do-functions-work-in-aiken) | [Primitive Types](#q14-what-are-aikens-primitive-types)

---

## Q17: How do I test validators in Aiken?

**Answer:** Aiken has first-class support for unit tests and property-based tests, built directly into the language. Tests are defined using the `test` keyword, are run with `aiken check`, and execute on the same virtual machine as on-chain code. Tests also display memory and CPU execution units, making them useful for benchmarking.

**Key Points:**
- Unit tests: functions with no arguments returning `Bool`; use the `test` keyword
- Property-based tests: take a fuzzer argument via the `via` keyword
- Run tests with `aiken check`
- Tests collect traces for debugging
- Automatic diffing on test failures shows what went wrong
- Test failures using `fail` keyword test expected-failure paths
- Filter tests with `-m` flag: `aiken check -m "module_name"`
- Tests run on the same virtual machine as production validators

**Example:**
```aiken
// Unit test
test simple_addition() {
  let result = 2 + 3
  result == 5
}

// Property-based test
use aiken/fuzz

test prop_commutative((a, b) via fuzz.both(fuzz.int(), fuzz.int())) {
  a + b == b + a
}

// Expected failure test
test must_fail() fail {
  expect Some(result) = math.sqrt(-42)
  result == -1
}
```

**Related:** [Property-Based Testing](#q18-what-is-property-based-testing-in-aiken) | [Troubleshooting](#q24-how-do-i-debug-and-troubleshoot-validators)

---

## Q18: What is property-based testing in Aiken?

**Answer:** Property-based testing is a first-class feature in Aiken that generates random test inputs to check general properties rather than specific cases. It includes integrated shrinking, which automatically simplifies counterexamples to smaller failing inputs. Fuzzers are introduced using the `via` keyword and the `aiken/fuzz` library provides composable fuzzer primitives.

**Key Points:**
- Uses the `via` keyword to attach a `Fuzzer<a>` to test arguments
- Automatic shrinking finds minimal counterexamples
- The `aiken/fuzz` library provides primitives: `fuzz.int()`, `fuzz.bool()`, `fuzz.list()`, `fuzz.bytearray()`, etc.
- Fuzzers compose: `fuzz.list(fuzz.int())` generates random lists of integers
- Labelling with `fuzz.label()` shows distribution of test paths
- `fail once` — property expected to fail at least once across all runs
- Default: 100 random samples per property

**Example:**
```aiken
use aiken/fuzz

test prop_is_non_negative(n: Int via fuzz.int()) {
  n >= 0
}

test prop_list(xs: List<Int> via fuzz.list(fuzz.int())) {
  todo
}

// Custom fuzzer
fn my_fuzzer() -> Fuzzer<List<Int>> {
  fuzz.list(fuzz.int())
}

test prop_custom(xs via my_fuzzer()) {
  todo
}
```

**Related:** [Testing](#q17-how-do-i-test-validators-in-aiken) | [Benchmarks](#q25-how-do-benchmarks-work-in-aiken)

---

## Q19: How do functions work in Aiken?

**Answer:** Functions in Aiken are defined with the `fn` keyword, are first-class values, and implicitly return their last expression (no `return` keyword). They support labeled arguments, type inference, anonymous definitions, partial application (function capturing), and the pipe operator for chaining.

**Key Points:**
- Named functions: `fn name(args) -> ReturnType { body }`
- Private by default; use `pub` to export
- Anonymous functions: `let add = fn(x, y) { x + y }`
- Labeled arguments: can be called by name in any order
- Function capturing: `add(1, _)` creates a new function
- Pipe operator: `x |> f |> g` chains function calls
- Backpassing: `let result <- callback_fn(x)` syntax for callback-heavy code
- No recursive anonymous functions — use top-level definitions for recursion

**Example:**
```aiken
fn add(x: Int, y: Int) -> Int {
  x + y
}

pub fn public_function(x: Int) -> Int {
  x * 2
}

// Pipe operator
fn transform(x) {
  x
  |> add(_, 3)
  |> add(_, 6)
}

// Function capturing
fn run() {
  let add_one = add(1, _)
  add_one(2) // 3
}
```

**Related:** [Variables & Constants](#q16-how-do-variables-and-constants-work) | [Control Flow](#q20-how-does-pattern-matching-work-in-aiken)

---

## Q20: How does pattern matching work in Aiken?

**Answer:** Aiken uses `when/is` expressions for pattern matching, similar to `match` in Rust or `case` in Haskell. Pattern matching is exhaustive — the compiler checks that all cases are covered. You can destructure custom types, lists, tuples, and more directly in patterns.

**Key Points:**
- `when value is { pattern -> result }` for multi-case matching
- Patterns can destructure lists: `[]`, `[x]`, `[x, y, ..]`
- Patterns can destructure custom types by constructor
- Wildcard `_` matches anything
- Must be exhaustive — compiler enforces coverage of all cases
- `expect` is used for non-exhaustive matching (fails if pattern doesn't match)

**Example:**
```aiken
fn describe_list(list: List<Int>) -> String {
  when list is {
    [] -> @"The list is empty"
    [x] -> @"The list has one element"
    [x, y, ..] -> @"The list has multiple elements"
  }
}

fn unwrap_option(opt: Option<Int>) -> Int {
  when opt is {
    Some(a) -> a
    None -> fail @"Expected Some but got None"
  }
}
```

**Related:** [Custom Types](#q15-how-do-i-define-custom-types) | [Error Handling](#q21-how-do-i-handle-errors-in-aiken)

---

## Q21: How do I deal with errors in Aiken?

**Answer:** Aiken provides several mechanisms for error handling: `fail` to immediately halt execution, `todo` as a placeholder that warns on compilation, `expect` for non-exhaustive pattern matching that halts if the pattern doesn't match, and the `?` operator for trace-if-false debugging. Since validators are predicates, "errors" generally mean the validator returns `False` or halts.

**Key Points:**
- `fail` — Halts execution immediately (no compilation warning). Can include a message: `fail @"reason"`
- `todo` — Like `fail` but produces a compilation warning as a reminder. Use during development
- `expect` — Pattern match that halts if the pattern doesn't match. E.g., `expect Some(x) = optional_value`
- `expect` with `Bool` — `expect sum >= 0` halts if the condition is false
- `?` operator — Trace-if-false; appended to boolean expressions for debugging: `must_be_signed?`
- Soft casting with `if/is` — Non-halting type check: `if value is SomeType { ... } else { ... }`

**Example:**
```aiken
// expect halts if pattern doesn't match
expect Some(datum) = optional_datum

// fail with message
fn expect_some_value(opt: Option<a>) -> a {
  when opt is {
    Some(a) -> a
    None -> fail @"Expected a value but got None"
  }
}

// todo as placeholder
fn favourite_number() -> Int {
  todo @"Implement this later"
}

// ? operator for debugging
must_say_hello? && must_be_signed?
```

**Related:** [Troubleshooting](#q24-how-do-i-debug-and-troubleshoot-validators) | [Testing Failures](#q17-how-do-i-test-validators-in-aiken)

---

## Q22: How do modules and imports work?

**Answer:** Aiken programs are organized into modules — bundles of functions and types with their own namespaces. Modules correspond to `.ak` files and can export types and values using `pub`. Imports use the `use` keyword, supporting both qualified and unqualified imports.

**Key Points:**
- Each `.ak` file is a module; namespace derived from file path
- `pub` exports functions and types
- Qualified import: `use aiken/collection/list` then call `list.at(...)`
- Unqualified import: `use aiken/collection/list.{at}` then call `at(...)`
- Custom import names: `use aiken/collection/list as my_list`
- Opaque types: `pub opaque type` hides internal representation
- Module documentation: `////` (quadruple slash) at the top of a file
- Validators can be imported into test modules only

**Example:**
```aiken
// Qualified import
use aiken/collection/list

fn use_imports() {
  let numbers = [1, 2, 3, 4, 5]
  list.at(numbers, 2) // 3
}

// Unqualified import
use aiken/collection/list.{at}

fn use_unqualified() {
  at([1, 2, 3], 2) // 3
}
```

**Related:** [Project Structure](#q6-what-is-the-project-structure-of-an-aiken-project) | [Standard Library](#q23-what-is-the-aiken-standard-library)

---

## Q23: What is the Aiken standard library?

**Answer:** Aiken provides two foundational packages: the **prelude** and the **standard library (stdlib)**. The prelude is automatically available in all projects with essential types and functions. The stdlib is a separate dependency that provides a rich collection of data structures, utilities, and well-tested code for common smart contract operations.

**Key Points:**
- **Prelude** (`aiken-lang/prelude`) — Available by default; includes core types like `Option`, `Bool`, `Ordering`, `Void`, `Data`, `Never`, and `Fuzzer`
- **Standard Library** (`aiken-lang/stdlib`) — Added as a dependency; includes modules for lists, dicts, math, crypto, transaction types, assets, addresses, and more
- The stdlib is a great reference for well-written Aiken code
- `aiken new` automatically adds the stdlib as a dependency
- Both are published with HTML documentation

**Related:** [Modules & Imports](#q22-how-do-modules-and-imports-work) | [Creating a Project](#q5-how-do-i-create-a-new-aiken-project)

---

## Q24: How do I debug and troubleshoot validators?

**Answer:** Aiken provides three main debugging tools: the `trace` keyword for logging messages, `expect` traces for automatic assertion logging, and the `?` (trace-if-false) operator for tracking which boolean conditions fail. Additionally, CBOR diagnostic notation helps inspect runtime values.

**Key Points:**
- **`trace`** — Variadic keyword; traces any serialisable value: `trace @"label": value1, value2`
- **`?` operator** — Postfix; traces expression only if it evaluates to `False`: `must_be_signed?`
- **`expect` traces** — Auto-generated traces on `expect` failures when using `--trace-level verbose`
- **CBOR diagnostic** — `cbor.diagnostic(value)` produces human-readable representation of any serialisable value
- **Trace levels**: `silent` (no traces), `compact` (labels only), `verbose` (full traces)
- `aiken build` removes traces by default; `aiken check` keeps them by default
- Traces change the validator hash — so production validators should strip them
- `aiken tx simulate` also captures traces

**Example:**
```aiken
// Manual trace
trace @"redeemer": string.from_bytearray(redeemer.msg)

// Trace-if-false operator
must_say_hello? && must_be_signed?

// CBOR diagnostic
use aiken/cbor
test my_datum_check() {
  let datum = MyDatum { foo: 42, bar: "Hello" }
  cbor.diagnostic(datum) == @"121([42, h'48656c6c6f'])"
}
```

**Related:** [Error Handling](#q21-how-do-i-handle-errors-in-aiken) | [Testing](#q17-how-do-i-test-validators-in-aiken)

---

## Q25: How do benchmarks work in Aiken?

**Answer:** Aiken has built-in benchmarking using the `bench` keyword. Benchmarks measure execution costs (memory and CPU units) across increasing input sizes using `Sampler` functions. A `Sampler` is a function that takes a size parameter and returns a `Fuzzer`, allowing you to define how inputs grow.

**Key Points:**
- Use `bench` keyword with a `Sampler` argument via the `via` keyword
- A `Sampler<a>` = `fn(Int) -> Fuzzer<a>`
- Size grows linearly from 0 to `--max-size` (default 30)
- Run with `aiken bench`; outputs terminal plots or JSON (`aiken bench > benchmarks.json`)
- Filter benchmarks: `aiken bench -m "my_module"`
- Build on top of the `aiken/fuzz` package

**Example:**
```aiken
use aiken/fuzz
use aiken/primitive/bytearray

fn sample_bytearray(size: Int) -> Fuzzer<ByteArray> {
  fuzz.bytearray_between(size * 128, size * 128)
}

bench bytearray_length(bytes: ByteArray via sample_bytearray) {
  bytearray.length(bytes)
}
```

**Related:** [Testing](#q17-how-do-i-test-validators-in-aiken) | [Property-Based Testing](#q18-what-is-property-based-testing-in-aiken)

---

## Q26: What is a one-shot minting policy?

**Answer:** A one-shot minting policy is a design pattern that ensures a minting validator can only execute once. It works by parameterizing the validator with a specific `OutputReference` and then verifying that the corresponding UTxO is consumed in the transaction. Since UTxOs can only be spent once by definition, this guarantees the policy validates at most once — perfect for creating unique NFTs.

**Key Points:**
- Parameterize with `OutputReference` (transaction ID + output index)
- Check that the referenced UTxO is in the transaction's inputs
- Enforce that exactly 1 token is minted
- The `OutputReference` is unique (hash of transaction + index), ensuring one-time execution
- Commonly used for NFT creation

**Example:**
```aiken
use aiken/collection/dict
use aiken/collection/list
use cardano/transaction.{OutputReference, Transaction}
use cardano/assets.{PolicyId}

pub type Action {
  Minting
  Burning
}

validator one_shot(utxo_ref: OutputReference) {
  mint(redeemer: Action, policy_id: PolicyId, self: Transaction) {
    expect [Pair(_asset_name, quantity)] = self.mint
      |> assets.tokens(policy_id)
      |> dict.to_pairs()

    let is_output_consumed =
      list.any(inputs, fn(input) { input.output_reference == utxo_ref })

    when redeemer is {
      Minting -> is_output_consumed? && (quantity == 1)?
      Burning -> (quantity == -1)?
    }
  }
}
```

**Related:** [Validator Parameters](#q13-how-do-validator-parameters-work) | [Design Patterns](#q27-what-is-the-double-satisfaction-problem)

---

## Q27: What is the double satisfaction problem?

**Answer:** Double satisfaction is a vulnerability in the eUTxO model where a single output payment can satisfy multiple validator executions in the same transaction. This happens when a validator checks that "at least X amount is paid to address Y" without ensuring each input has a unique corresponding output. An attacker can pay once and unlock multiple UTxOs at the same price or less.

**Key Points:**
- Occurs when multiple UTxOs are locked with similar spending conditions
- The validator code runs independently for each input being spent
- Without uniqueness, one payment output can satisfy all validator executions
- **Solution: Tagged Outputs** — Tag each output with a unique value derived from the input's `OutputReference`
- Use `if/is` (soft casting) rather than `expect` when checking output datums to avoid rejecting unrelated outputs

**Example (vulnerable):**
```aiken
// BAD: This validator can be satisfied multiple times with one payment
let user_outputs = list.filter(self.outputs, fn(output) { output.address == beneficiary })
let value_paid = list.foldl(user_outputs, assets.zero, fn(output, total) { merge(output.value, total) })
(lovelace_of(value_paid) >= datum.price)?
```

**Fix:** Tag outputs with the input's `OutputReference` as inline datum, ensuring each input maps to a unique output.

**Related:** [One-Shot Minting](#q26-what-is-a-one-shot-minting-policy) | [State Thread Tokens](#q28-what-are-state-thread-tokens)

---

## Q28: What are State Thread Tokens (STT)?

**Answer:** State Thread Tokens are a design pattern for maintaining mutable state across transactions. An NFT (created via a one-shot minting policy) is attached to a UTxO carrying a datum that represents the current state. Each transaction that uses the STT must forward it to a new output with an updated datum, ensuring the state is carried forward and can't be spoofed.

**Key Points:**
- Uses a unique NFT to identify the "state carrier" UTxO
- The NFT is typically minted via a one-shot policy to guarantee uniqueness
- A multivalidator handles both minting (initialization) and spending (state transitions)
- Each transaction must forward the NFT to an output with an updated datum
- The policy ID of the minting handler equals the script hash of the spending handler (same validator)
- Common pattern for counters, registries, and other stateful contracts

**Related:** [One-Shot Minting](#q26-what-is-a-one-shot-minting-policy) | [Double Satisfaction](#q27-what-is-the-double-satisfaction-problem)

---

## Q29: What is forwarding validation?

**Answer:** Forwarding validation is an optimization pattern where a simple spending validator delegates ("forwards") its actual validation logic to a withdrawal script. Instead of running complex logic once per input, a lightweight spending script just checks that a specific withdrawal is present in the transaction. The withdrawal script then runs only once for all inputs, dramatically reducing execution costs.

**Key Points:**
- Exploits the fact that withdrawing 0 lovelace is always valid
- The spending validator checks for a specific withdrawal in the transaction
- The withdrawal script contains the actual validation logic and runs once
- Reduces overhead from running the same logic multiple times (one per input)
- Used in production by many dApps for execution budget optimization
- Validators have access to the entire transaction context regardless of purpose

**Related:** [State Thread Tokens](#q28-what-are-state-thread-tokens) | [Validator Purposes](#q11-what-are-the-six-validator-purposes-in-aiken)

---

## Q30: How does the `and`/`or` syntax work?

**Answer:** Aiken provides `and` and `or` keywords as a more readable alternative to `&&` and `||` chains. They use a block syntax with comma-separated boolean expressions, making the grouping and precedence immediately obvious — especially useful when validators combine many conditions.

**Key Points:**
- `and { expr1, expr2, expr3 }` — All must be `True` (equivalent to `&&` chain)
- `or { expr1, expr2, expr3 }` — At least one must be `True` (equivalent to `||` chain)
- Can be nested: `or { and { a, b }, c, d }`
- Most beneficial with 4+ conditions
- `&&` and `||` are still available as short-circuit operators

**Example:**
```aiken
// Using and/or keywords
fn my_validation_logic() -> Bool {
  or {
    and {
      should_satisfy_condition_1,
      should_satisfy_condition_2,
    },
    should_satisfy_condition_3,
    should_satisfy_condition_4,
  }
}

// Equivalent with operators
fn same_logic() -> Bool {
  (should_satisfy_condition_1 && should_satisfy_condition_2)
    || should_satisfy_condition_3
    || should_satisfy_condition_4
}
```

**Related:** [Control Flow](#q20-how-does-pattern-matching-work-in-aiken) | [Validators](#q10-how-do-i-write-my-first-validator)

---

## Q31: What is the Plutus blueprint (`plutus.json`)?

**Answer:** The Plutus blueprint is a CIP-0057 compliant JSON file generated by `aiken build` that describes your on-chain contract's binary interface. It contains compiled validator code, hash digests for address generation, and schema definitions for datums and redeemers — all derived from your Aiken type definitions and documentation comments.

**Key Points:**
- Generated at `plutus.json` in the project root by `aiken build`
- Contains compiled UPLC code for each validator
- Includes hash digests for calculating on-chain addresses
- Schema definitions for datums and redeemers (auto-generated from types)
- Framework-agnostic format for interoperability between tools
- Use `aiken blueprint` command group to generate addresses, apply parameters, and convert formats

**Related:** [Compiling](#q7-how-do-i-compile-an-aiken-project) | [Validator Parameters](#q13-how-do-validator-parameters-work)

---

## Q32: How do validity intervals work in Cardano?

**Answer:** Validity intervals provide a way to introduce time into Cardano's deterministic smart contracts. A transaction can specify an optional lower bound (valid after) and upper bound (valid before), which are checked during phase-1 validation. Since the interval is verified before script execution, validators can safely assume the transaction falls within the specified time window.

**Key Points:**
- Checked during phase-1 (structural) validation, before scripts run
- Scripts can read the interval and use it as a trusted time reference
- Store a deadline as datum; check the transaction's lower bound exceeds it
- Intervals can be as narrow as one second
- Blocks are produced every ~20 seconds on average
- Very narrow intervals increase the risk of missing a block
- This preserves determinism — the interval is agreed upon upfront, not queried at runtime

**Related:** [eUTxO Model](#q8-what-is-the-eutxo-model) | [Troubleshooting](#q24-how-do-i-debug-and-troubleshoot-validators)

---

## Q33: What is conditional configuration in Aiken?

**Answer:** Aiken supports conditional modules and configuration values through environments. This allows you to swap between different configurations (e.g., mainnet vs. testnet) without changing code. Configuration is defined in `aiken.toml` under `[config]` sections and accessed via a special `config` module.

**Key Points:**
- Define configurations in `aiken.toml` under `[config.default]`, `[config.mainnet]`, etc.
- Access via `use config` module in Aiken code
- Select environment at build time: `aiken build --env mainnet`
- Supports integers, booleans, strings, lists, tuples, and hex-encoded byte arrays
- Conditional modules can replace entire `.ak` files based on environment
- Environment modules follow the pattern `{module}.{env}.ak`

**Example (`aiken.toml`):**
```toml
[config.default]
price = 1000000
is_mainnet = true
network = "mainnet"

[config.default.owner]
bytes = "0000111122223333"
encoding = "hex"
```

```aiken
use config

fn main() {
  if config.is_mainnet {
    config.price * 2
  } else {
    config.price
  }
}
```

**Related:** [Project Structure](#q6-what-is-the-project-structure-of-an-aiken-project) | [Compiling](#q7-how-do-i-compile-an-aiken-project)

---

## Q34: What is Untyped Plutus Core (UPLC)?

**Answer:** Untyped Plutus Core (UPLC) is the low-level language that is actually executed by Cardano's virtual machine. All smart contract languages (Aiken, PlutusTx, Helios, etc.) compile down to UPLC. It's a minimal lambda-calculus-based language with 7 primitive types and a set of built-in functions. Aiken provides tools to inspect, evaluate, format, and convert UPLC programs.

**Key Points:**
- 7 primitive types: unit, bool, integer, bytestring, string, pair, list
- Encoded in binary format on-chain; human-readable textual form for debugging
- Aiken CLI tools: `aiken uplc eval`, `aiken uplc fmt`, `aiken uplc flat`/`aiken uplc unflat`
- Variables/functions are replaced by compact indices after compilation
- All types are erased but implicitly enforced — type mismatches cause runtime errors
- Aiken has a fully working UPLC virtual machine written in Rust

**Related:** [Aiken vs Plutus](#q2-how-is-aiken-different-from-plutus-plutustx) | [CBOR Diagnostic](#q24-how-do-i-debug-and-troubleshoot-validators)

---

## Q35: What other languages can I use for Cardano smart contracts?

**Answer:** Several languages compile to UPLC for Cardano smart contracts, ranging from standalone languages to embedded DSLs. The main alternatives to Aiken are OpShin (Python), Helios (new language in JavaScript), Plutarch (Haskell eDSL), plu-ts (TypeScript eDSL), and Scalus (Scala).

**Key Points:**
- **Aiken** — New language; Rust-inspired syntax; standalone compiler in Rust; purely functional with static typing
- **OpShin** — Write in restricted Python3; uses normal Python tooling; implements its own type system
- **Helios** — New language; compiler is a single JavaScript file; purely functional with limited type inference
- **Plutarch** — Haskell eDSL; full access to Haskell's type system (typeclasses, HKTs); no Template Haskell
- **plu-ts** — TypeScript eDSL; implements its own type checking at JS runtime
- **Scalus** — Scala-based; works on JVM and JavaScript; includes UPLC tooling and macros
- All compile to the same UPLC target — choose based on your preferred ecosystem and needs

**Off-chain SDKs (for building transactions):**
| Language | SDK |
|----------|-----|
| JavaScript/TypeScript | Lucid, Mesh.js |
| Python | PyCardano |
| Rust | Pallas |
| Haskell | Cardano API |
| Java/Scala | Bloxbean |
| C# | CardanoSharp |

**Related:** [What is Aiken](#q1-what-is-aiken) | [Aiken vs Plutus](#q2-how-is-aiken-different-from-plutus-plutustx)

---


