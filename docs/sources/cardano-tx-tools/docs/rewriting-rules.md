# rewriting-rules YAML grammar

The on-disk YAML language that drives the two-stage rewriting
pipeline shared by [`tx-inspect`](tx-inspect.md) and
[`tx-diff`](tx-diff.md). One document; two independent stages
(`collapse:` and `rename:`); engine-enforced stage order
(collapse first, rename second).

The same loader (`parseRewriteRulesYaml`) consumes the file from
both tools. Every collapse-only YAML file that pre-dates the
unified grammar parses unchanged — the `rename:` key is strictly
additive.

## Document shape

```yaml
version: 1                          # optional, integer, defaults to 1
views:                              # optional
  raw: show | hide                  # optional, defaults to show
collapse:                           # optional, defaults to []
  - <CollapseRule>
  - ...
rename:                             # optional, defaults to []
  - <RenameRule>
  - ...
```

- **Top-level shape**: a single YAML object.
- **Unknown keys**: ignored (forward-compatible with future stages).
- **Key order**: irrelevant. `collapse:` may appear before or
  after `rename:` — output is identical because stage order is
  engine-enforced, not document-order-driven.
- **Required keys**: none. An empty `{}` document parses to "no
  rules" and the renderer falls back to verbatim output.
- **Versioning**: only `version: 1` is accepted; any other value
  is a parse error.

## `CollapseRule`

```yaml
- name: "SwapOrder"
  at: body.outputs
  match:
    required:
      - coin
      - datum.constructor
```

- **`name`**: a non-empty UTF-8 string. The bucket label that
  appears in the rendered output in place of the collapsed
  shape.
- **`at`**: a `DiffPath` selector identifying the structural
  site whose children are candidates for collapsing (commonly
  `body.outputs`, `body.inputs`, witnesses, etc.).
- **`match.required`**: a list of `DiffPath` selectors relative
  to each candidate. Every required path must be present for
  the candidate to be considered an instance of this shape. The
  required leaves are surfaced in the rendered bucket as the
  per-instance variable slots; everything else in the
  candidate is folded into the named shape and hidden.

See [Pattern — keep payment addresses out of `required:`](#pattern-keep-payment-addresses-out-of-required) below for an
important interaction between `required:` and the rename layer.

## `RenameRule`

Each entry is one of two variants discriminated by `kind:`. New
kinds will be added in follow-up tickets (see
[Not in this version](#not-in-this-version)).

### `kind: address`

```yaml
- kind: address
  key: addr1q9...           # bech32 address (mainnet or testnet)
  match: payment            # OPTIONAL — "full" | "payment", default "payment"
  name: "treasury-party"
```

- **`key`**: a valid bech32 address string. Both mainnet
  (`addr1...`) and testnet (`addr_test1...`) prefixes are
  accepted; the loader does **not** enforce a particular network
  — a rule may match in either context (the rule author is
  responsible for using the right address for the target
  network).
- **`match: payment`** (default): the loader extracts the
  payment credential from the bech32 at parse time and matches
  against the payment credential of every address site in the
  rendered transaction. The stake credential of the rendered
  address is ignored. One rule covers every stake variant of the
  same payment script.
- **`match: full`**: the loader parses the full bech32 and
  matches the entire `Addr` value (payment + stake credentials
  together). Different stake variants of the same payment
  script need different rules.
- **`name`**: a non-empty UTF-8 string. Rendered in place of the
  bech32 wherever the rule matches.

### `kind: script`

```yaml
- kind: script
  key: 9c2e7e15a4c1b2...     # 56 hex chars (Cardano script hash, 28 bytes)
  name: "amaru.swap.v1"
```

- **`key`**: 56 hex characters representing a Cardano script
  hash (28 bytes). Lowercase or uppercase accepted; the loader
  canonicalises to lowercase for matching.
- **`match:` is IGNORED for script rules** (it is still parsed
  and validated, for predictable error messages, but never
  consulted — 28 bytes have no sub-structure to vary over).
- **`name`**: a non-empty UTF-8 string.

## Match semantics

For every leaf identifier in the rendered transaction:

- **Payment-bearing field** (`body.inputs.*.resolved.address`,
  `body.outputs.*.address`, withdrawal addresses, certificate
  addresses):
  - For each address rename rule whose target matches (per
    `MatchFull` or `MatchPayment`), render the rule's `name:`
    in place of the bech32.
  - Multiple matching rules: **first occurrence in the YAML
    file wins**.
  - No matching rule: render the bech32 verbatim.
- **Script-hash field** (body, witness set, reference scripts):
  - For each script rename rule whose `key:` equals the
    rendered hash, render the rule's `name:`.
  - No matching rule: render the hash verbatim.

Substitution is **best-effort**: an unmatched identifier is
never an error and never causes the surrounding structural
element to be omitted.

## Parse errors

The loader returns `Left <error>` for any of:

- YAML decode failure (malformed YAML).
- `version:` present but not `1`.
- A `RenameRule` entry whose `kind:` is neither `"address"` nor
  `"script"`.
- A `kind: address` rule whose `key:` does not parse as bech32.
- A `kind: script` rule whose `key:` is not 56 hex characters.
- A rule whose `name:` is empty or missing.
- An address rule whose `match:` is present but is not `"full"`
  or `"payment"`.

Conversely, the loader is forgiving on:

- Missing `version:` (defaults to `1`).
- Missing `views:` (defaults to `raw: show`).
- Missing `collapse:` or `rename:` (each defaults to `[]`).
- Unknown top-level keys (ignored).
- Address rules where `match:` is missing (defaults to
  `payment`).
- Address rules where `match:` is present on a `kind: script`
  rule — parsed and validated for error-message predictability,
  then discarded.

## Cross-tool consumers

Both tools consume the same file format through the same loader:

| Tool | Flag | Notes |
|---|---|---|
| [`tx-inspect`](tx-inspect.md) | `--rules FILE` | Both stages take effect on the single-side render. |
| [`tx-diff`](tx-diff.md) | `--collapse-rules FILE` | Flag spelling preserved for backwards compatibility — see [tx-diff](tx-diff.md). Both stages take effect inside each side of the diff. |

The flag-naming asymmetry is a deliberate backwards-compat
decision: existing `tx-diff --collapse-rules` invocations
continue to work unchanged, and a legacy collapse-only YAML
file parses to the same `RewriteRules` value with an empty
`rename:` section, producing byte-identical output to the
pre-rename behaviour.

## Cross-tool semantics

The "shared substrate" claim is at the **loader +
`applyRewriteRules` + per-leaf renderer** level. Concretely:

- Both tools call the same `parseRewriteRulesYaml`.
- Both tools call the same `applyRewriteRules` on the same
  `OpenValue` substrate.
- Each leaf is rendered through the same `renderJsonValue`
  function.

What the shared substrate is **not**: byte-identical CLI
output. That is structurally impossible — `tx-diff` emits diff
format (per-key differences keyed by ledger identity, both
sides interleaved), while `tx-inspect` emits a single-side
render. The substrate guarantees that for every leaf
`tx-inspect` renders, the corresponding side of a `tx-diff`
render produces the same leaf bytes.

## Pattern — keep payment addresses out of `required:`

A `collapse:` rule whose `required:` list includes a
payment-address path (e.g. `address`) renders the address from
the pre-extracted JSON path the collapse engine snapshots,
**not** through the `ConwayAddressValue` path the rename layer
consumes. The practical effect: rename rules for that address
will not fire at the collapsed site.

The fix is to leave payment-address paths in the per-instance
remainder (un-pinned), not in the `required:` list. The
checked-in `rules/amaru-treasury.yaml` follows this pattern:

```yaml
collapse:
  - name: "SwapOrder"
    at: body.outputs
    match:
      required:
        - coin                 # OK — coin is a numeric leaf
        - datum.constructor    # OK — datum constructor index is a leaf
        # address: NOT listed here — leaving it out lets the rename
        # layer substitute the address-book name at render time.
```

## Not in this version

- **Datum-embedded identifiers** are NOT renamed. The rename
  layer walks payment-address sites and script-hash sites in
  the body / witnesses / reference scripts; identifiers
  embedded inside Plutus datum constructors render verbatim
  even if a matching rule exists. This is an axis-of-scope
  decision (`OpenValue` exclusion); datum-embedded rename is
  a separate axis from the identifier-family follow-ups below.
- **More identifier families** are tracked as one ticket per
  family, each adding a new `kind:` value:
  - [#34](https://github.com/lambdasistemi/cardano-tx-tools/issues/34) — `kind: stake` (stake addresses)
  - [#35](https://github.com/lambdasistemi/cardano-tx-tools/issues/35) — `kind: pool` (pool IDs)
  - [#36](https://github.com/lambdasistemi/cardano-tx-tools/issues/36) — `kind: drep` (DRep IDs)
  - [#37](https://github.com/lambdasistemi/cardano-tx-tools/issues/37) — `kind: asset-policy` (policy IDs)
  - [#38](https://github.com/lambdasistemi/cardano-tx-tools/issues/38) — `kind: asset-name` (asset names within a policy)
- **Datum-embedded identifier rename** — tracked separately as
  [#39](https://github.com/lambdasistemi/cardano-tx-tools/issues/39),
  which proposes reusing the address/script rename index for
  28-byte `OpenBytes` leaves inside `OpenValue` datum subtrees
  (security motivation: a malicious tx hiding identifiers in
  datums can defeat review unless the renderer matches the same
  index everywhere).
- **Collapse-engine ergonomics** —
  [#40](https://github.com/lambdasistemi/cardano-tx-tools/issues/40)
  proposes (a) nested collapse rules (`nested:` on a `CollapseRule`,
  child paths relative to each matched item) so recurring nested
  patterns like the per-output committee list can be collapsed
  without writing one rule per parent index, and (b) a `raw: omit`
  view mode that suppresses the per-item rendering when the bucket
  is the entire desired view. Today, `raw: hide` only prunes the
  leaves the rule covered; per-item subtrees still render.

Each follow-up is additive: the grammar's `kind:` discriminator
gains a new value, the loader gains one parser case, and the
existing rules continue to behave unchanged.

## Worked example — `rules/amaru-treasury.yaml`

The checked-in rules file for the Amaru treasury swap fixtures
exercises both stages:

```yaml
version: 1
views:
  raw: hide

# Stage 1 — collapse: name the Amaru treasury swap-order output shape so
# each pair of swap outputs renders as a single "SwapOrder" bucket
# exposing only its per-output address, coin, and datum-constructor
# variable slots. Treasury-leftover and user-payment outputs do not
# carry a datum constructor, so they remain rendered verbatim.
collapse:
  - name: "SwapOrder"
    at: body.outputs
    match:
      required:
        - coin
        - datum.constructor

# Stage 2 — rename: substitute every Amaru-treasury identifier appearing
# in the two checked-in swap fixtures with its address-book name.
#
# Stake-key default `match: payment` covers every stake variant of the
# same payment script — one rule reaches both the swap-order address
# (payment = swap.v2, stake = treasury) and the treasury-leftover
# address (payment = treasury, stake = treasury).
rename:
  # Plutus script hashes (the witness-set + reference-script sites
  # render scripts by their 28-byte hash).
  - kind: script
    key: fa6a58bbe2d0ff05534431c8e2f0ef2cbdc1602a8456e4b13c8f3077
    name: amaru.swap.v2
  - kind: script
    key: 32201dc1e82708364c6c42a53f89f675314bb9ad5da2734aa10baa0d
    name: amaru-treasury.network_compliance
  # Swap-order address — payment credential is the swap.v2 script,
  # stake credential is the treasury script. `match: payment` matches
  # every stake variant; `match: full` would also work here because the
  # two fixtures share the same stake credential.
  - kind: address
    key: addr1x8ax5k9mutg07p2ngscu3chsauktmstq92z9de938j8nqaejyqwur6p8pqmycmzz55lcnan4x99mnt2a5fe54ggt4gxst7gy3n
    match: payment
    name: amaru.swap-order
  # Treasury self-address — payment + stake credential both the
  # network_compliance treasury script.
  - kind: address
    key: addr1xyezq8wpaqnssdjvd3p220uf7e6nzjae44w6yu625y965rfjyqwur6p8pqmycmzz55lcnan4x99mnt2a5fe54ggt4gxs8thzgk
    match: payment
    name: amaru-treasury.network_compliance.account
  # The recipient (user) payment address. Both fixtures send change
  # outputs back to this address (the operator running the swap).
  - kind: address
    key: addr1qx9aqvsf6gne2640jec828s25gzhk5wp2day8u24kf8mrs2v0zyuvk80fay35dx008p45ts0u6cdrv9g2maetq8jm8psznjcrz
    match: payment
    name: user.recipient
  # The Amaru network wallet — the publicly-known operator wallet
  # used for fuel + collateral in the swap-wizard's tx-build path.
  - kind: address
    key: addr1q802wxt6cg6aw0nl0vdzfxavu65rxu3yzhvgayw7chfxymduzkt66uw9t5kspx5jwjecx80dz4g33htknafhdhkvzd5st4f9xu
    match: payment
    name: amaru.network-wallet
```

Annotations:

- `views.raw: hide` suppresses the verbatim render of the
  collapsed `body.outputs` site — only the named `SwapOrder`
  bucket and its variable slots are emitted.
- The `coin` + `datum.constructor` required pair is what
  distinguishes a swap output from a treasury-leftover or
  user-payment output (the latter two have no datum
  constructor, so they fall out of the collapse).
- Every `kind: address` rule uses `match: payment` (the
  default) so a single rule reaches all stake variants of the
  same payment script.
- The script-hash rules cover the `amaru.swap.v2` and
  `amaru-treasury.network_compliance` Plutus scripts wherever
  they appear in the witness set or as reference scripts.
