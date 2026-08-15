# DWARF Scenario DSL Reference (spec v1)

A **scenario** is a single file written in YAML (YAML Ain’t Markup Language, a human-readable data format) — an instance of DWARF's **domain-specific language (DSL)** for describing tests. It describes one repeatable experiment against a Cardano node: it declares *what to run against* (target + runtime), *what to do* (an ordered list of primitives), and *what must be true afterwards* (assertions). The golden rule: **a scenario is data; primitives are code.** A scenario can only *reference* primitives that are already registered in `primitives/registry.json` — pasted YAML can never introduce new behaviour. That registry boundary is the framework's safety guarantee. (Scenarios may equivalently be written in JSON (JavaScript Object Notation), since JSON is a subset of YAML.)

> This file is generated from `spec/v1/schema.json` and `primitives/registry.json`. Do not hand-edit; run `scripts/gen_reference.py` after schema/registry changes.


## The scenario lifecycle

When you run a scenario, the runner executes six kinds of primitive in a fixed order. Two of them (**faults** and **probes**) run *concurrently with* the load phase rather than after it:

- **setup** — ordered. Prepare the world (install a version, compose a devnet, warm it to tip). Any failure aborts the run **before** load.
- **load** — ordered. The actual workload/strategy under test (fuzz a decoder, pressure a mini-protocol, force an epoch boundary…). The first load primitive's duration (or the scenario `duration`) bounds the run.
- **faults** — run *concurrently with load*. Degrade the environment while load runs (delay/drop a port, freeze a node, byzantine proxy).
- **probes** — sampled *concurrently with load*. Each streams a time series to `probes/<primitive>.ndjson` (newline-delimited JSON) in the run bundle.
- **assertions** — evaluated *after* load completes. Each records its value, the data points used, and pass/fail. These decide the scenario's overall verdict.
- **teardown** — ordered. Cleanup; runs **regardless of pass/fail**. Failures are logged but never change the verdict.

So the serial spine is **setup → load → assertions → teardown**, with **faults** and **probes** layered over the load phase. `seed` seeds every primitive's random-number generator (RNG) so a run replays deterministically.


## Top-level fields

`target` requires `implementation` (`cardano-node` | `amaru`) and `version` (`any`, or a semver/branch/commit). Unknown top-level keys are rejected (`additionalProperties: false`). Required fields: `id`, `runtime`, `spec_version`, `target`, `title`.

| field | type | required | meaning |
|---|---|---|---|
| `spec_version` | `—` | **yes** | Spec major version. `v1` validates against this schema. |
| `id` | `string` | **yes** | Globally-unique scenario id. Lowercase kebab-case; stable across renames (primary key). |
| `title` | `string` | **yes** | Human-readable one-line title shown in dashboards/reports. |
| `authors` | `array` | no | Optional author handles. |
| `tags` | `array` | no | Free-form tags for indexing/filtering (e.g. `ser-deser`, `networking`, `abuse`). |
| `related_milestones` | `array` | no | Optional milestone labels this scenario supports (e.g. `M2`). |
| `m1_trace` | `object` | no | Traceability back to Milestone-1 artifacts (threat_ids / gap_ids / architecture_ids / risk_candidate_ids). |
| `evidence_intent` | `string` enum: `candidate`, `regression`, `finding-validation`, `risk-support` | no | How the run's evidence is intended to be used. Does not promote a finding by itself. |
| `promotion_blockers` | `array` | no | Gates that must close before this scenario can support a promoted finding. |
| `testcase_candidate` | `object` | no | Optional: auto-ingest the completed run as a testcase lifecycle record. |
| `target` | `object` | **yes** | Which implementation is under test. Runner refuses if a referenced primitive doesn't support it. |
| `runtime` | `string` enum: `library`, `single-node`, `devnet` | **yes** | Execution tier (see below). Runner refuses a primitive whose runtimes exclude this value. |
| `profile` | `string/null` | no | Devnet profile id. **Required when `runtime: devnet`, forbidden otherwise.** |
| `substrate` | `object` | no | Inline devnet composition (nodes + topology + launch mode). Devnet scenarios use this instead of / alongside a `profile` id. See the substrate section below. |
| `duration` | `string` | no | Wall-clock cap on the load phase. Units `s`/`m`/`h` (e.g. `30s`, `10m`, `2h`). |
| `seed` | `integer/string` | no | Integer or `0x…` hex seeding every primitive's RNG. Omitted → runner generates and records one. Required for deterministic replay. |
| `setup` | `array` | no | Ordered setup primitive refs. Failure aborts before load. |
| `load` | `array` | no | Ordered load primitive refs (the workload). |
| `faults` | `array` | no | Fault primitives run concurrently with load. |
| `probes` | `array` | no | Probe primitives sampled concurrently with load. |
| `assertions` | `array` | no | Assertion primitives evaluated after load; decide pass/fail. |
| `teardown` | `array` | no | Ordered teardown refs; always run; never change the verdict. |
| `phases` | `array` | no | Optional phased execution — an ordered list of phases, each carrying its own setup/load/faults/probes/assertions/teardown, instead of declaring them once at top level. |
| `invariants` | `array/object` | no | Optional declarative invariants attached to the scenario (runner-interpreted). |
| `iterations` | `integer` | no | Trial count when the scenario contains FUZZ slots (default 100). Each iteration becomes a child bundle. |
| `shrink` | `boolean` | no | When true (default), a failing FUZZ iteration is minimised toward smaller inputs. |


## Runtime tiers

| runtime | what it spins up | use for |
|---|---|---|
| `library` | nothing — drives a library/binary harness (shim) directly | fast, deterministic parser/decoder fuzzing (no node, no docker) |
| `single-node` | one node process | behaviour that needs a live node but not a network |
| `devnet` | a multi-node devnet via a `profile` (docker / host / multi-host) | consensus, mini-protocol, epoch and fault scenarios across a real topology |


## The FUZZ mechanism

Any primitive parameter can be replaced by the bare string `"FUZZ"` (the runner infers a generator from the primitive's declared parameter type) or the long-form `{"fuzz": {…}}` object. When any FUZZ slot is present the whole scenario is repeated `iterations` times (default 100), each iteration a child bundle; `shrink` (default true) minimises any failing input. Supported generator `type`s: `int`, `bytes`, `string`, `bool`, `choice`, `weighted_choice` (with `min`/`max`/`values`/`weights`).

> The FUZZ slot mechanism (parameter-level) is distinct from the Concise Binary Object Representation (CBOR) **shape grammar** below (which is the parameter *of* the `cbor_fuzz_structured` primitive).


## The CBOR shape grammar

`cbor_fuzz_structured` takes a `shape` — a recursive tree that names a well-formed CBOR value by its structure while leaving leaf contents random. The generator walks the tree and emits real CBOR bytes; the `mutation_rate` then corrupts inner fields. This reaches deep decoder paths a blind random-bytes fuzzer rarely hits. Node types:

| type | fields | emits |
|---|---|---|
| `uint` | `max` (default 0xffffffff) | random unsigned int in [0,max] (major type 0) |
| `bytes` | `length` (int, or `{min,max}`) | random byte string (major type 2) |
| `text` | `length` (int, or `{min,max}`) | random ASCII (American Standard Code for Information Interchange) text string (major type 3) |
| `bool` | — | random true/false (0xf5/0xf4) |
| `null` | — | CBOR null (0xf6) |
| `array` | `elements` (list of shapes) | definite array; header len = len(elements), then each element |
| `map` | `entries` (list of `[key, shape]`; key = int or string) | definite map; each entry emits key then value shape |
| `tag` | `tag` (int), `inner` (shape) | semantic tag wrapping the encoding of `inner` (major type 6) |
| `any` | — | terminal wildcard: a short random uint in [0,100] |

Annotated example — a Conway-style certificate skeleton (array of a discriminator + a nested [kind, 28-byte hash]):

```jsonc
{
  "type": "array",                       // CBOR array of 2 (major type 4)
  "elements": [
    {"type": "uint", "max": 18},         // cert discriminator 0..18
    {"type": "array", "elements": [
      {"type": "uint", "max": 1},        // credential kind 0..1
      {"type": "bytes", "length": 28}    // blake2b-224 key/script hash
    ]}
  ]
}
```

This generates bytes like `82 12 82 01 58 1c <28 random bytes>` — a structurally-valid certificate with randomised leaves that the mutation pass then perturbs.


## Two worked examples


### Library-tier CBOR fuzz (no node)

```jsonc
{
  "spec_version": "v1",
  "id": "cardano-node-cbor-tx-body-fuzz",
  "title": "Library-tier CBOR fuzz of cardano-node tx-body parser",
  "target": {"implementation": "cardano-node", "version": "any"},
  "runtime": "library",
  "seed": "0xCAFE0001",
  "load": [
    {"primitive": "cbor_fuzz_target", "target_id": "cardano-node-cbor-decode-tx-body",
     "manifests_dir": "dwarf/targets/manifests", "iterations": 10000,
     "min_bytes": 1, "max_bytes": 4096, "per_input_timeout_seconds": 2}
  ],
  "probes":     [{"primitive": "parser_exit_status"}],
  "assertions": [{"primitive": "parse_succeeds_or_clean_error"}],
  "teardown":   []
}
```

Reads as: feed 10,000 random 1–4096-byte inputs to the tx-body decoder shim; record each outcome; **pass iff none crashed** (every input parsed cleanly or was cleanly rejected).


### Devnet-tier compound scenario (multi-node)

A `devnet` scenario adds a `substrate` block (nodes + topology) and a `profile`, then sequences runtime primitives — e.g. skew a node's clock, force an epoch boundary, roll the stake snapshot, recompute the leadership schedule — and asserts the epoch-boundary invariants held. Setup composes the substrate; teardown tears it down; assertions like `epoch_boundary_timing_within_bounds` and `reward_calculation_boundary_invariant` decide the verdict.


## The substrate block — inline devnet composition

A `devnet` scenario declares the network under test inline via a `substrate` block (an alternative to naming a `profile`). It lists the nodes, their roles, and the peer topology.

| substrate field | meaning |
|---|---|
| `network` | Base network/config the devnet derives from (e.g. `preview`). |
| `nodes[]` | The nodes — each with `id`, `impl` (`cardano-node`/`amaru`), `version`, `role`, optional `host`. |
| `topology.edges[]` | Directed peer edges `{from, to}` between node ids. |
| `compose_mode` | How nodes launch: `host` (native tmux) · `docker` (compose) · `multi-host` (SSH fan-out). |
| `host_strategy` · `hosts` | Multi-host placement (which box each node runs on). |

Node **roles** the runner recognises:

| role | behaviour |
|---|---|
| `honest` | Plays by the rules — the baseline. |
| `adversary` | A node the scenario drives adversarially (e.g. serves a private fork). |
| `byzantine` | A node whose traffic is mutated/corrupted via a byzantine proxy. |
| `sybil` | A cheap identity used in eclipse / Sybil topologies. |
| `submitter` | Drives local-tx-submission load. |
| `observer` | Watches only — used to read tips/telemetry without participating. |

```jsonc
"substrate": {
  "network": "preview",
  "nodes": [
    {"id": "node1", "impl": "cardano-node", "version": "10.7.1", "role": "honest"},
    {"id": "adv1",  "impl": "cardano-node", "version": "10.7.1", "role": "adversary"}
  ],
  "topology": {"edges": [
    {"from": "adv1", "to": "node1"}, {"from": "node1", "to": "adv1"}
  ]}
}
```


### Phased scenarios

Instead of one flat `setup`/`load`/`assertions` list, a scenario may use a `phases` array — an ordered list of phases, each carrying its own primitive lists. Useful when a run has distinct stages (baseline → fault → remediation → recheck). Primitives inside phases are validated the same way.


## How to write & run your own

- Copy the closest example from `dwarf/scenarios/` and change `id`, `title`, and the `load` list.
- Pick a `runtime`: `library` for parser/decoder work, `devnet` for anything involving a live network.
- Reference only primitives from the **Primitives Reference** (the runner rejects unknown names). Match each primitive's declared `runtimes` and `supports`.
- Add `assertions` — these are your oracle; without them a run can't fail. See the assertion catalog for the exact pass condition of each.
- Set a `seed` for reproducibility. Add `iterations` if you use FUZZ slots.
- Run: `cardano-profile scenario run dwarf/scenarios/<your>.yaml`. Results land in a forensic bundle under `dwarf/runs/<run-id>/`.
