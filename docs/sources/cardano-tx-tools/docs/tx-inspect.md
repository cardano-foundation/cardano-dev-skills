# tx-inspect

Render one Conway transaction as a structured, human-readable
report. Reads the CBOR (or `cardano-cli` JSON envelope), decodes
it through the ledger, and walks the same `OpenValue` substrate
`tx-diff` uses to lay out one side of a diff. Optional
[rewriting-rules YAML](rewriting-rules.md) drives two stages
on top of the verbatim render: **collapse** repeated structural
shapes into named buckets, then **rename** payment addresses and
script hashes to address-book names. Both stages are optional
and independent; either, both, or neither may appear in the
rules file.

```text
Usage: tx-inspect [--render tree|paths] [--tree-art ascii|unicode]
                  [--rules FILE]
                  [--n2c-socket-path SOCKET --network-magic N]
                  [--web2-url URL [--web2-api-key-file PATH]]
                  [--links cardanoscan
                       [--network mainnet|preprod|preview]]
                  TX
```

```asciinema-player
{
  "file": "assets/asciinema/tx-inspect.cast",
  "idle_time_limit": 2,
  "theme": "monokai",
  "poster": "npt:0:3"
}
```

## Input

`tx-inspect` takes one required positional argument: `TX`, the
path to a file holding the Conway transaction. The content type
is auto-detected (hex CBOR, raw CBOR, or a `cardano-cli` JSON
text envelope) — the same decoder `tx-diff` and `tx-validate`
use.

## Rules

`--rules PATH` loads a [rewriting-rules YAML](rewriting-rules.md)
document — the same grammar `tx-diff --collapse-rules` consumes.
Both `collapse:` and `rename:` are optional; a missing or empty
section means "no rules for that stage". An empty `{}` document
renders the transaction verbatim.

The engine enforces stage order — collapse runs first, rename
runs after on the leaves that collapse has surfaced —
independently of the order rules appear in the YAML file.

## Resolver

Without resolver flags, body inputs render as unresolved txin
references. With either of the two resolver back-ends, inputs
render with their resolved address + value:

- `--n2c-socket-path SOCKET` — query a local `cardano-node` over
  Node-to-Client.
- `--web2-url URL` (optionally with `--web2-api-key-file PATH`)
  — query a Blockfrost-compatible HTTP endpoint.

This is the same resolver chain `tx-diff` exposes; pick whichever
back-end you already have wired.

## Examples

### Verbatim render — no rules, no resolver

```bash
tx-inspect path/to/tx.cbor.hex
```

The output is the same structural tree `tx-diff` would render
for one side of a diff, with raw hashes inline.

### Collapse-only

A rules file with only collapse entries names a repeated output
shape so each instance renders as a single bucket exposing only
its per-instance variable slots. Raw hashes inside the exposed
slots remain verbatim.

```bash
tx-inspect path/to/tx.cbor.hex --rules path/to/collapse.yaml
```

### Rename-only

```yaml
# rename-only.yaml
version: 1
rename:
  - kind: address
    key: addr1q9treasury...
    name: "amaru-treasury"
  - kind: script
    key: 9c2e7e15a4c1b2...
    name: "amaru.swap.v1"
```

```bash
tx-inspect path/to/tx.cbor.hex --rules rename-only.yaml
```

The structural shape is unchanged (no collapse), but every leaf
identifier matched by a `RenameRule` appears under its book
name. Unknown identifiers render verbatim.

### Amaru treasury swap — collapse + rename

The checked-in `rules/amaru-treasury.yaml` covers both stages
for the Amaru treasury swap fixtures:

```bash
tx-inspect path/to/amaru-swap-tx.cbor.hex \
    --rules rules/amaru-treasury.yaml \
    --n2c-socket-path /run/cardano-node/node.socket
```

Each swap output appears collapsed into the named `SwapOrder`
shape, with the counterparty, asset, and script slots showing
their address-book names instead of raw hashes.

### Shared substrate — same rules file feeds `tx-diff`

The exact same YAML feeds `tx-diff`:

```bash
tx-diff swap-1.cbor.hex swap-2.cbor.hex \
    --collapse-rules rules/amaru-treasury.yaml
```

The flag spelling differs (`tx-diff` keeps the older
`--collapse-rules` name for backwards compatibility — see
[tx-diff](tx-diff.md)), but the file format and the
collapse + rename semantics are identical. The shared substrate
is the loader, `applyRewriteRules`, and the per-leaf renderer —
not byte-identical CLI output, because `tx-diff` emits diff
format and `tx-inspect` emits a single-side render. See
[rewriting-rules grammar — Cross-tool semantics](rewriting-rules.md#cross-tool-semantics).

## Cardanoscan links

`--links cardanoscan` annotates every Cardanoscan-classifiable
leaf in the rendered tree with its
[Cardanoscan](https://cardanoscan.io) URL. The annotation lands
as a trailing ` [https://...]` after the leaf value, so a
transaction-input row reads

```text
{"txId":"abcdef...","index":7} [https://cardanoscan.io/transaction/abcdef...]
```

and a payment-address row reads

```text
addr1q... [https://cardanoscan.io/address/addr1q...]
```

The flag is **opt-in**; without it the rendered output is
byte-identical to the pre-#88 behaviour, and existing goldens
continue to pass unchanged.

### Network

`--network mainnet|preprod|preview` selects the host
(`cardanoscan.io`, `preprod.cardanoscan.io`,
`preview.cardanoscan.io`). The default is `mainnet` — the
dominant treasury-work case. Unsupported values produce a
parser error (exit code 2).

`--network` is only consulted when `--links cardanoscan` is set;
passing it without `--links` is accepted but has no effect.

### Rename + link interaction

When a leaf is also renamed by a `rename:` rule, the rename
controls the displayed identifier and the link still resolves
against the **original** on-chain leaf:

```text
amaru.swap-order [https://cardanoscan.io/address/addr1q...]
```

Renames are presentation; links are ground truth.

### Linker scope (this slice)

The S2 slice classifies the leaves that map directly to a single
substrate atom:

| Leaf                     | Cardanoscan path                  |
|--------------------------|------------------------------------|
| Body transaction input   | `/transaction/<producer-hash>`     |
| `txInId` references      | `/transaction/<producer-hash>`     |
| Output / witness address | `/address/<bech32>`                |

Other leaf classes (stake addresses, policy ids, asset
fingerprints) are exported by the library
(`Cardano.Tx.Diff.Scan.cardanoscanUrl`) and the URL shape is
pinned for every variant, but the **renderer's classifier** does
not yet emit them — adding them is additive and ships in a
follow-up.

### Non-goals

- **Terminal hyperlinks** (OSC 8). The bracketed-URL form works
  in any text-aware renderer (logs, terminals without OSC 8,
  GitHub diffs, `less`, …) and is the safer default.
- **Output-index highlighting** on transaction-input URLs. The
  link points at the producing transaction page; opening the
  specific output via `#ix=…` is out of scope.
- **Other explorers** (`cexplorer.io`, …). The library exposes
  the extension point (`type LeafLinker`) but only the
  Cardanoscan linker ships in this slice.

## `--version`, `--help`, no-update env var

```bash
tx-inspect --version          # → "tx-inspect <semver>", exit 0
tx-inspect --help             # → usage on stdout, exit 0
TX_INSPECT_NO_UPDATE_CHECK=1 tx-inspect ...    # suppress upgrade banner
```

These match the per-exe pattern shipped by the four pre-existing
CLIs.

## Render hygiene — empty `TxOut` fields are suppressed

`tx-inspect` always renders with `humanHideEmpty = True`. For each
transaction output (resolved or not), fields that would otherwise
emit noise are dropped before the tree is printed:

- `datum: cbor: (0 bytes)` — emitted when the output has `NoDatum`
  (pure ADA wallet UTxO). Suppressed.
- `referenceScript: null` — emitted when the output has no
  reference script attached. Suppressed.

Outputs / inputs that DO have a datum or a reference script render
their content normally. The diff renderer (`tx-diff`) keeps the
opposite default (`humanHideEmpty = False`) so diff outputs continue
to show "datum changed from null to X" cases — both renderers share
the same projection and primitives, but each picks the empty-leaf
policy that matches its use case.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success. Rendered to stdout. |
| `1` | Input error (file not found, CBOR decode failure, malformed `--rules` YAML, ...). Diagnostic on stderr. |
| `2` | CLI flag error (e.g. missing required positional). |

The renderer itself never raises a runtime error on an unknown
identifier — rename is best-effort, never a failure.

## Library

The render core is shared with `tx-diff` and exposed under
`Cardano.Tx.*`:

| Module                       | Role                                                  |
|------------------------------|-------------------------------------------------------|
| `Cardano.Tx.Diff`            | `RewriteRules`, `applyRewriteRules`, the per-leaf renderer |
| `Cardano.Tx.Rewrite`         | `parseRewriteRulesYaml` — the unified loader          |

The executable entry point lives in `app/tx-inspect/Main.hs` and
is a thin wrapper over the library: it parses flags, loads the
rules file, drives the resolver chain, and prints the rendered
output.

## See also

- [rewriting-rules grammar](rewriting-rules.md) — the on-disk
  YAML language both `tx-inspect --rules` and
  `tx-diff --collapse-rules` consume.
- [tx-diff](tx-diff.md) — the shared-substrate diff tool.
