# Flat conformance suite

One of two parallel conformance suites in this repo. Each fixture is a single `fixture.json` inside its own directory; the harness in `tests/conformance_flat.rs` deserializes it, decodes the flat bytes via the consensus-critical flat decoders, and then either evaluates and compares against the expected output + budget, or, for negatives checks, that the rejection lands at the declared layer (`decode` or `eval`).

The sibling `../textual/` suite holds the upstream Plutus textual fixtures verbatim and is run by `tests/conformance.rs` through the `syn` parser. The textual suite is the canonical conformance signal; this flat suite exercises the on-chain decode path.

Most fixtures here originated from [IntersectMBO/plutus](https://github.com/IntersectMBO/plutus)'s textual conformance suite (`plutus-conformance/test-cases/uplc/evaluation/`), converted to flat via the reference `uplc` CLI. There's no automated sync, so the flat suite isn't guaranteed to match upstream byte-for-byte.

## fixture.json schema

```json
// happy path
{
  "input": "<hex flat bytes>",
  "expected": {
    "kind": "ok",
    "output": "<hex flat bytes of evaluator's output, re-encoded>",
    "budget": { "cpu": <i64>, "mem": <i64> }
  }
}

// negative pinned to a layer
{
  "input": "<hex>",
  "expected": { "kind": "error", "layer": "decode" | "eval" }
}

// negative, either layer is acceptable
{
  "input": "<hex>",
  "expected": { "kind": "error" }
}
```

## Hand-crafted negatives

Fifteen fixtures don't come from the upstream textual suite. The corresponding textual program is one Plutus's parser rejects outright (free de Bruijn index, BLS literal, constr tag wider than `Word64`, malformed `Value`, etc.), so the reference CLI can't produce flat bytes for it. The hex strings here are hand-crafted to pin specific decoder paths.

| Path | Pins |
|---|---|
| `negative/case/v100/case-error-v100/` | CASE term inside a `1.0.0` program: decoder must version-gate |
| `negative/constr/v100/constr-empty-v100/` | CONSTR term inside a `1.0.0` program: decoder must version-gate |
| `negative/constr/tag-overflow/tag-2pow64/` | constr tag of `2^64`: `decoder::word` silently wraps |
| `negative/var/free/free-debruijn-1/` | free de Bruijn index: decode accepts, eval rejects |
| `negative/bls/g1-element/g1-const/` | BLS constant type tag: no flat wire representation for raw curve points |
| `term/case/case-07/`, `term/constr/constr-{06,07,09,10}/`, `term/var/` | per-fixture mirrors of textual files Plutus's parser rejects outright |
| `builtin/constant/value/key-too-long-{1,2}/` | 33-byte currency/token key: decoder's >32 length check rejects |
| `builtin/constant/value/{overflow,underflow}/` | quantity outside `i128` range: `check_quantity_range` rejects |

## Upstream fixtures covered only by the textual suite

~169 textual fixtures from the upstream Plutus suite have no flat counterpart here, but they still run as part of `../textual/`. They fall into two groups:

**BLS in the program (143).** Most are valid programs that pass `(con bls12_381_G[12]_element 0x…)` to a BLS builtin. The flat wire format has no representation for raw curve points. In practice, G1/G2 values arrive as a bytestring fed to `bls12_381_G[12]_uncompress` at runtime. Plutus's decoder rejects the BLS constant tag uniformly, `negative/bls/g1-element/g1-const/` covers the whole class on the flat side.

**Textual-only failure modes (26).** `(con bool Maybe)`, `(con integer 0.5)`, `(con (list bool) [5])`, `(constr -5 …)`, `(con value [("CURRENCY", …)])`, and others. The parser rejects on grammar or type grounds, but no malformed byte sequence in flat targets the same failure: bool is one bit, integers are LEB128, list/pair elements decode by the declared type tag with no per-value check, constr tags are unsigned LEB128, Value entries are length-prefixed bytestrings with no string-vs-bytestring distinction.
