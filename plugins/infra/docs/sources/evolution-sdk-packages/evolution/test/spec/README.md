# spec

Write validators in the `validators` folder, and supporting functions in the `lib` folder using `.ak` as a file extension.

```aiken
validator my_first_validator {
  spend(_datum: Option<Data>, _redeemer: Data, _output_reference: Data, _context: Data) {
    True
  }
}
```

## Building

```sh
aiken build
```

## Configuring

**aiken.toml**
```toml
[config.default]
network_id = 41
```

Or, alternatively, write conditional environment modules under `env`.

## Testing

You can write tests in any module using the `test` keyword. For example:

```aiken
use config

test foo() {
  config.network_id + 1 == 42
}
```

To run all tests, simply do:

```sh
aiken check
```

To run only tests matching the string `foo`, do:

```sh
aiken check -m foo
```

### CBOR Encoding Tests

The `lib/cbor_encoding_spec.ak` file contains comprehensive tests to document Aiken's CBOR encoding behavior. These tests verify the exact CBOR hex output for various PlutusData types:

- **Primitives**: Int, ByteArray, Bool
- **Lists**: Empty, single-item, multi-item, nested, mixed types
- **Tuples**: Pairs, triples, nested structures
- **Lists of tuples**: Empty, single-entry, multi-entry
- **Pairs (maps)**: Empty, single-entry
- **Options**: Some/None with constructor tags
- **Custom Types**: Multi-constructor types with fields
- **Edge Cases**: Deeply nested structures, large values

Run these tests to verify encoding compatibility:

```sh
aiken check -m cbor_encoding
```

The test output shows the actual CBOR hex values Aiken produces, which helps maintain compatibility between the Aiken compiler and TypeScript CBOR encoder in the Evolution SDK.

## Documentation

If you're writing a library, you might want to generate an HTML documentation for it.

Use:

```sh
aiken docs
```

## Resources

Find more on the [Aiken's user manual](https://aiken-lang.org).
