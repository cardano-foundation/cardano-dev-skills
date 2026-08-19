# Forensic Bundle Format

Every Dwarf run produces one self-contained directory under `dwarf/runs/<run-id>/` and is exportable as a single `.tar.gz` under `dwarf/bundles/`. Same format across all runtimes (`library`, `single-node`, `devnet`) and all primitive families. This document defines that format.

Status: format is specified here and implemented in Slice 2. This document is the contract.

## Run ID

Format: `YYYYMMDDTHHMMSSZ-<short-hash>`.

The short hash is derived from `sha256(scenario_yaml_bytes || resolved_profile_json_bytes || env_json_bytes || seed_bytes)[:8]`. Identical inputs always produce the same prefix; collisions across distinct inputs are vanishingly rare. The timestamp prefix gives chronological sort order.

## Directory layout

```
dwarf/runs/<run-id>/
  manifest.json          # canonical run identity and pointers (see below)
  scenario.yaml          # exact scenario file used, byte-for-byte
  resolved-profile.json  # devnet profile after defaults+overrides+env-substitution; null for non-devnet runs
  env.json               # captured environment (kernel, OS, Python, Docker, host fingerprint, clock)
  inputs/                # every input handed to the system under test (corpus files, generated payloads, tx blobs)
  outputs/               # everything the system under test produced (stdout, stderr, log files, snapshots)
    afl/                 # preserved AFL++ campaign artifacts when the run uses the AFL helper
      summary.json       # campaign artifact index and counts
      default/           # copied AFL default corpus/crash/hang tree plus fuzzer_stats
  log.ndjson             # append-only structured event log; one JSON event per line
  events/                # normalized event views derived from log.ndjson
    observer.ndjson      # framework/observer-side events
    target-hooks.ndjson  # raw target-side hook events emitted directly by Dwarf-owned helpers
    target.ndjson        # target/harness-side events
  metrics/               # normalized telemetry captured for the run
    summary.json         # pointers and counts for telemetry artifacts
    host/
      load.ndjson        # host load samples
    process/
      self.ndjson        # runner/collector process samples for this slice
    runtime/             # reserved for target/runtime counters and hooks
  probes/                # one ndjson per probe; raw time-series points
    <probe-name>.ndjson
  assertions.json        # one entry per assertion: evaluated value, data points used, pass/fail
  chain.json             # this run's hash chain entry (see below)
```

## Substrate-emitted output directories

The following output directories are the stable substrate-side directories emitted by the current composed-substrate surface. Not every run has all of them.

| Directory | Producer | Typical files | Notes |
| --- | --- | --- | --- |
| `outputs/substrate-compose/` | `runtime_compose_substrate` | `compose-report.json`; `hosts/<host-id>/compose-report.json` in multi-host mode | Canonical substrate creation record. |
| `outputs/multi-node-observation/` | `runtime_multi_node_observation` | `observation-summary.json`; `correlated-timeline.json`; `per-node/<node-id>/tip-state.json`; `connection-state.json`; `resource-profile.json`; `syscall-trace.json` | Unified node-observation surface for composed substrates. |
| `outputs/substrate-teardown/` | `runtime_teardown_substrate` | `teardown-report.json` | Canonical teardown record. |
| `outputs/chain-verify/` | `runtime_bundle_chain_verify` | `chain-verify-report.json` | Provenance-chain verification artifact. |
| `outputs/attestation/` | `runtime_bundle_attestation` | `attestation.json` | Signed provenance statement for a bundle. |
| `outputs/bundle-summary/` | `runtime_bundle_summary_compose` | `summary.json`; `summary.md`; `summary.html` | Cross-bundle roll-up view. |
| `outputs/coverage-report/` | `runtime_coverage_report` | `coverage-summary.json`; `coverage.html`; `coverage.md`; `coverage-report-file-level.json`; `coverage-file-level.md`; `merged-libfuzzer.profdata` when present | Coverage reporting surface. |
| `outputs/static-analysis-<tool>/` | static-analysis primitives | `stdout.log`; `stderr.log`; `findings.json` | Tool-specific analysis results. |
| `outputs/crash-triage/` | `runtime_crash_triage` | `result.json`; `triage-report.json`; `triage-report.md`; grouped trace artifacts | Crash dedupe and sanitizer triage surface. |
| `outputs/corpus-health/` | `runtime_corpus_health_report` | `corpus-health-report.json`; `corpus-health-report.md`; `corpus-health-report.html` | Historical AFL++ health timeseries. |

Primitive-specific directories may emit additional `result.json`, `stdout.log`, or helper artifacts under their own output path. Those are not globally reserved names; the directories above are the currently stable substrate-oriented ones.

## manifest.json

Single JSON object. Written once at run end. Contents:

- `run_id` — string, the `<YYYYMMDDTHHMMSSZ-shortHash>` identifier.
- `framework` — object with `version` (semver of the dwarf framework) and `commit` (git commit of the framework at run time).
- `scenario` — object with `id`, `spec_version`, `path` (relative to repo root), and `sha256` of the scenario file as written into the bundle.
- `target` — object with `implementation` (`cardano-node` | `amaru`), `version_declared` (the `target.version` field from the scenario), `version_resolved` (the actual version that ran, e.g. a commit hash or binary digest), and `binary_sha256` (digest of the deployed binary or library).
- `runtime` — string, one of `library` | `single-node` | `devnet`.
- `profile` — object or null. If devnet: `id` and `sha256` of `resolved-profile.json`. Else null.
- `env_sha256` — sha256 of `env.json`.
- `seed` — integer or hex string used for all RNGs.
- `started_at` / `ended_at` — UTC ISO 8601 timestamps.
- `exit_status` — overall: `pass` | `fail` | `error` | `aborted`.
- `assertion_summary` — object with `total`, `pass`, `fail`.
- `actor` — string identifying who or what initiated the run. v1: `shared:dwarf` (the single shared token). Later: per-user identity.
- `signature` — reserved for v1.1; absent in v1.
- `telemetry` — object describing normalized telemetry artifacts for the run:
  - `observer_event_log` — path to `events/observer.ndjson`
  - `target_event_hook_log` — path to `events/target-hooks.ndjson`
  - `target_event_log` — path to `events/target.ndjson`
  - `metrics_summary_path` — path to `metrics/summary.json`
  - `observer_event_count` / `target_event_count` — counts written from the normalized event split plus merged target hooks
  - `target_hook_event_count` — count of raw target-side hook events
  - collector-specific summary keys such as `sample_interval_seconds`, `host_load_samples`, and `process_samples`
- `resource_snapshot` — object capturing a cheap before/after resource picture of the system under test. Two data points per run, not a time series. Time-series probes are a separate concern handled by `probe` primitives. Fields:
  - `wall_time_seconds` — float, end minus start.
  - `process_rss` — object with `start_bytes`, `end_bytes`, `delta_bytes` for the system-under-test process. For library-runtime runs this is the harness process; for single-node and devnet runs this is the node process. Null if the process could not be measured (e.g. exited too quickly).
  - `data_dir_disk` — object with `path`, `start_bytes`, `end_bytes`, `delta_bytes` for the node's data directory. Null for library-runtime runs.
  - `host_load` — optional object with 1-minute system load average at start and end, when available cheaply. Null otherwise.

The manifest is hashed (sha256 over canonical JSON) and that hash becomes `manifest_hash` in the chain entry.

## JSON artifact shapes

This section lists the current high-value JSON artifact contracts. These are the shapes other tools should consume.

### `manifest.json`

Top-level shape:

- `run_id`
- `framework`
- `scenario`
- `target`
- `runtime`
- `profile`
- `env_sha256`
- `seed`
- `started_at`
- `ended_at`
- `exit_status`
- `assertion_summary`
- `actor`
- `resource_snapshot`
- `telemetry`

The current implementation writes this shape in [forensic.py](dwarf/profile_manager/forensic.py).

### `assertions.json`

Current shape is an array of objects:

- `primitive`
- `params`
- `evaluated_value`
- `data_points_used`
- `result`
- optional `note`

This file is always written, even when the array is empty.

### `chain.json`

Current shape:

- `run_id`
- `manifest_hash`
- `prev_hash`
- `timestamp`

The chain entry is the canonical tamper-evidence link for the run.

### `outputs/substrate-compose/compose-report.json`

Current substrate-compose shape includes the following stable keys:

- `compose_mode`
- `runtime_metadata_path`
- `bundle_runtime_metadata_path`
- `runtime_root`
- `compose_project`
- `network`
- `network_magic`
- `node_count`
- `nodes`
- `healthy`

In multi-host mode it additionally includes:

- `multi_host`
- `host_count`
- `host_strategy`
- `hosts`

In Docker mode, each node record may also include:

- `container_name`
- `container_id`
- `container_network`
- `container_ip`
- `container_listen_address`
- `container_socket_path`
- `container_peer_addresses`
- `image_ref`

### `outputs/multi-node-observation/observation-summary.json`

Current shape:

- `runtime_metadata_path`
- `node_ids`
- `observation_window_seconds`
- `sample_interval_seconds`
- `observation_primitives`
- `network_magic`
- `per_node`
- `summary`

`per_node.<node-id>` contains stable identity fields:

- `node_id`
- `implementation`
- `version`
- `port`
- `socket_path`

and zero or more requested observation payloads:

- `tip_state`
- `connection_state`
- `resource_profile`
- `syscall_trace`

### `outputs/multi-node-observation/correlated-timeline.json`

Current shape is a correlation-oriented object derived from the per-node observation set. It is not append-only. It is regenerated from the current per-node records and is intended as the unified timeline input for bundle timeline and summary views.

### `outputs/substrate-teardown/teardown-report.json`

Current single-host shape:

- `runtime_metadata_path`
- `compose_mode` when Docker-backed
- `compose_project` when Docker-backed
- `runtime_root`
- `stopped_count`
- `remaining_sessions`
- `remaining_session_names`
- `nodes`

Current multi-host shape additionally includes:

- `multi_host`
- `hosts`

### `outputs/chain-verify/chain-verify-report.json`

Current shape:

- `target_run_id`
- `chain_length`
- `chain_verdict`
- `steps`

Each step carries the bundle id and verification verdict for one hop in the replay/attestation ancestry.

## log.ndjson

Append-only during the run. One JSON object per line, each with at minimum:

- `ts` — UTC ISO 8601 with millisecond precision.
- `phase` — `setup` | `load` | `fault` | `probe` | `assertion` | `teardown` | `framework`.
- `primitive` — name of the primitive emitting this event, or `framework` for runner events.
- `level` — `debug` | `info` | `warn` | `error`.
- `event` — short event name (e.g. `started`, `completed`, `input_emitted`, `assertion_pass`).
- `payload` — primitive-specific structured data.

The runner appends to `log.ndjson` synchronously; primitives emit events through a logger interface defined in Slice 2. Events are not edited or removed after writing.

## Event classes

The event log is intentionally open-ended at the payload level, but the current event names fall into a small set of operational classes.

### Framework lifecycle

- `phase_started`
- `phase_completed`
- `run_started`
- `run_completed`

### Primitive lifecycle

- `started`
- `completed`
- `sequence_started`
- `transition`
- `iteration`

### Fault and load application

- `fault_planned`
- `fault_applied`
- `fault_removed`
- `fault_check_completed`

### Observation and telemetry

- `probe_sample`
- target-specific runtime result events such as:
  - `preview_upstream_drop_result`
  - `preview_parity_baseline_result`
  - `live_implementation_baseline_result`

### Assertion results

- assertion evaluation records are normalized into `assertions.json`; helper events may still log intermediate assertion-related events during execution

The stable contract is the five common event fields (`ts`, `phase`, `primitive`, `level`, `event`) plus a structured `payload`. Consumers should not key off a fixed global event enumeration.

## events/observer.ndjson, events/target-hooks.ndjson, and events/target.ndjson

These are normalized views and raw hook artifacts materialized at run seal time.

- `observer.ndjson` contains framework/observer-side events for the current slice. In practice, that means `phase=framework` or `primitive=framework`.
- `target-hooks.ndjson` contains raw target-side events emitted directly by Dwarf-owned helper scripts and harness binaries through the telemetry hook contract.
- `target.ndjson` contains all non-framework events emitted by primitives and harness logic, merged with `target-hooks.ndjson`.

`log.ndjson` remains the append-only source log. The normalized event files are convenience views for later dashboard, diff, and analysis work.

## Shell-load telemetry hook contract

`load_shell_command` exports the following environment variables to child processes when the run handle has a bundle directory:

- `ADA2_DWARF_RUN_DIR`
- `ADA2_DWARF_EVENTS_DIR`
- `ADA2_DWARF_METRICS_DIR`
- `ADA2_DWARF_RUNTIME_METRICS_DIR`
- `ADA2_DWARF_TARGET_EVENT_LOG`

Dwarf-owned helper scripts should emit broad structured telemetry through this contract rather than inventing run-local output paths. The current helper module is `dwarf/scripts/runtime_telemetry.py`.

## metrics/summary.json

This file is the index for normalized telemetry written during the run. For the current slice it records:

- paths to the normalized event files;
- counts of observer, merged target, and raw target-hook events;
- observer sampling configuration;
- counts of host-load and process samples.

Future slices should extend this file rather than inventing parallel top-level indexes.

## AFL campaign artifact preservation

When a run uses a testcase-producing fuzzer helper, the helper exports a self-contained artifact view into the run bundle under `outputs/<producer>/`. For `producer=afl`, the canonical path remains `outputs/afl/`; for `producer=cargo-fuzz`, the canonical path is `outputs/cargo-fuzz/`.

- `outputs/afl/summary.json` records:
  - the source AFL output directory
  - whether `fuzzer_stats` existed
  - `queue_count`, `crash_count`, and `hang_count`
  - per-file `relative_path`, `size_bytes`, and `sha256` for the copied queue/crash/hang files
- `outputs/afl/triage.json` records:
  - `queue_testcase_count` excluding AFL `.state/` bookkeeping files
  - `queue_coverage_case_count` for queue entries whose filenames include `+cov`
  - `interesting_case_count`
  - a bounded `interesting_cases` list containing crashes, hangs, and the first coverage-increase queue cases with parsed filename metadata
- `outputs/afl/default/fuzzer_stats` preserves the raw AFL stats file
- `outputs/afl/default/queue`, `outputs/afl/default/crashes`, and `outputs/afl/default/hangs` preserve the copied AFL output tree that existed when the run completed

The corresponding runtime metrics are also emitted to `metrics/runtime/`:

- `queue_count.ndjson`
- `crash_count.ndjson`
- `hang_count.ndjson`
- `queue_testcase_count.ndjson`
- `queue_coverage_case_count.ndjson`
- `interesting_case_count.ndjson`
- plus the existing stats-derived metrics such as `execs_done`, `execs_per_sec`, `corpus_count`, `saved_crashes`, `saved_hangs`, and `cycles_done`

## Testcase lifecycle artifacts

The AFL helper now writes normalized testcase lifecycle records on top of raw artifact preservation and first-pass triage.

- `outputs/<producer>/testcases.ndjson` stores bundle-local testcase records for the current run
- `outputs/<producer>/replay-queue.ndjson` stores bundle-local replay work items derived from pending testcase records
- `outputs/<producer>/compare-queue.ndjson` stores bundle-local compare work items derived from pending testcase records
- `outputs/<producer>/buckets.ndjson` stores bundle-local testcase bucket summaries
- framework state stores reusable testcase records under:
  - `state/testcases/index.ndjson`
  - `state/testcases/<case-id>.json`
- `state/testcases/replay-queue.ndjson`
- `state/testcases/compare-queue.ndjson`

Each testcase record currently includes:

- stable `case_id`
- `source_run_id`
- `producer`
- `classification`
- `triage_reason`
- `target_implementation`
- `source_artifact_path`
- `sha256`
- `size_bytes`
- `metadata`
- `replay_targets`
- `replay_harness`
- `minimization_state`
- `replay_state`
- `compare_state`
- `bucket_signature`
- `bucket_id`

This is a framework-level lifecycle layer, not yet a full replay or minimization engine. The intent is that future AFL-backed and non-AFL discovery paths can emit the same testcase record shape so Dwarf can drive minimization, replay, and differential comparison from one durable store.

The lifecycle layer also persists testcase bucket summaries under `state/testcases/buckets.ndjson`. These started as source-signature buckets and now evolve with replay and compare outcomes.

Bucket signatures are now `version=v2` and include both:

- `source_signature`
- `replay_outcome`
- `replay_behavior_signatures`
- `replay_resource_signatures`
- `compare_outcome`
- `compare_run_outcomes`
- `compare_behavior_signatures`
- `compare_resource_signatures`

That means testcase buckets can now move as replay and compare evidence accumulates. A testcase is no longer grouped only by source metadata such as producer and triage reason; it is also grouped by what the saved case actually did under replay and differential comparison.

The lifecycle layer now also supports:

- exact-input testcase replay through `cardano-profile testcase replay <case-id> --target <impl>`
- exact-input cross-implementation replay through `cardano-profile testcase compare <case-id>`
- testcase minimization through `cardano-profile testcase minimize <case-id> --target <impl> --manifests-dir <dir>`
- runtime/devnet issue ingestion through `cardano-profile testcase ingest-run <run-id> --classification <name> --triage-reason <name>`
- replay-queue execution through `cardano-profile testcase replay-queue run ...`
- compare-queue execution through `cardano-profile testcase compare-queue run ...`
- testcase-state backfill and normalization through `cardano-profile testcase repair-state`

These paths do not invent a second execution engine. They stage the saved testcase bytes, generate a temporary library-tier scenario using `cbor_replay_target`, and execute through the canonical `scenario run` / `compare` paths.

`testcase ingest-run` is the first non-AFL ingress path. It creates a lifecycle case directly from an existing canonical run bundle, using bundle-derived behavior/resource summaries and scenario metadata even when there is no byte-level replay artifact. These ingested cases are intentionally non-replayable until a target-specific reproducer exists, but they enter the same bucket and issue-family model as AFL-derived records.

Scenarios can also declare `testcase_candidate` metadata directly. When present, the canonical `scenario run` path automatically ingests the completed run into testcase lifecycle state using that metadata. This is the preferred path for runtime/devnet anomaly families because it removes the extra operator step and keeps the lifecycle record tied to the scenario definition itself.

Replay-queue execution updates `state/testcases/replay-queue.ndjson` in place, adding:

- `replay_run_id`
- `exit_status`
- `behavior_summary`
- `resource_summary`
- `state=complete`

and the corresponding per-case lifecycle record gains appended `replay_results`.

Compare-queue execution updates `state/testcases/compare-queue.ndjson` in place, adding:

- `agreed`
- `comparison_path`
- `runs`
- `run_outcomes`
- `behavior_summaries`
- `resource_summaries`
- `state=complete`

Behavior summaries are derived from the canonical run bundle and currently normalize:

- `exit_status`
- assertion pass/fail counts
- target `outcome_counts`
- target `outcome_detail_counts`
- `target_event_count`
- `target_hook_event_count`
- per-primitive `primitive_counts`
- `probe_sample_count`
- a stable `signature`

Resource summaries are also derived from the canonical run bundle and currently normalize:

- `wall_time_seconds`
- `peak_rss_bytes`
- `peak_fd_count`
- `peak_socket_count`
- `host_sample_count`
- `process_sample_count`
- `runtime_metric_series_count`
- `runtime_metric_sample_count`
- `runtime_metric_names`
- `observer_event_count`
- `target_event_count`
- a stable resource `signature`

Replay and compare completion now also refresh:

- `bucket_signature`
- `bucket_id`
- `state/testcases/buckets.ndjson`

`testcase repair-state` exists so older lifecycle records do not need to wait for a replay or compare event to get current metadata. It rewrites legacy testcase files to the current bucket signature version and rebuilds the shared index and bucket summary files.

Minimization now has two backend classes:

- `oracle-ddmin` — the canonical Dwarf-native backend and the default CLI path
- `afl-tmin` — an optional AFL-specific backend when that toolchain path is reliable

`oracle-ddmin` is framework-first: it reuses the replay target manifest, computes a baseline oracle signature, and reduces the testcase while preserving that signature. The framework state records both successful and failed minimization attempts. On `the Linux target host`, the current Amaru `afl-tmin` path can produce the minimized output file but still does not exit cleanly, so production use should prefer the default `oracle-ddmin` backend.

## probes/<probe-name>.ndjson

One file per registered probe in the scenario. Append-only during the run. One JSON object per sample, each with:

- `ts` — UTC ISO 8601 with millisecond precision.
- `value` — sample value (number, object, or string depending on the probe).
- `meta` — optional probe-specific context (e.g. node id, pid).

Time-series captured raw, not as summaries. Any chart or aggregate in the dashboard or a report is re-derivable from these files.

## assertions.json

Array of objects, one per assertion in the scenario, in the order assertions were declared. Each entry:

- `primitive` — assertion primitive name.
- `params` — the assertion's parameters from the scenario.
- `evaluated_value` — the value the assertion compared against its threshold.
- `data_points_used` — pointer (file + line range) into one or more probe ndjsons identifying the data points the assertion looked at, or an explicit list if the data set is small.
- `result` — `pass` | `fail`.
- `note` — optional human-readable remark.

## chain.json

This run's chain entry. Single JSON object:

- `run_id` — string.
- `manifest_hash` — sha256 hex of the canonical-form `manifest.json`.
- `prev_hash` — sha256 hex of the previous chain entry's full JSON, or the literal string `"genesis"` for the first entry ever written.
- `timestamp` — UTC ISO 8601, written when the chain entry is sealed.
- `signature` — reserved for v1.1; absent in v1.

The same JSON is appended to `dwarf/state/chain-head.json` (atomic rename) so the global chain head always points at the latest entry. Walking the chain backward from the head reconstructs every run that has ever been recorded.

## Manifest hash chain semantics

The chain semantics are intentionally narrow:

1. Canonicalize `manifest.json` with sorted keys and stable JSON encoding.
2. Compute `manifest_hash = sha256(canonical_manifest_bytes)`.
3. Read the previous chain head entry, if any.
4. Compute `prev_hash = sha256(canonical_previous_chain_entry)` or the literal string `genesis` if no prior head exists.
5. Write the new `chain.json`.
6. Atomically replace `state/chain-head.json` with the new chain entry.

`runtime_bundle_chain_verify` uses the same semantics at bundle-analysis time:

- recompute the target bundle's `manifest_hash`
- compare it against the bundle's `chain.json`
- walk the ancestry chain backward by matching `prev_hash` against a canonicalized earlier chain entry

This is a manifest-chain, not a Merkle tree over all output files. Output integrity is indirectly anchored through the scenario, assertion, and artifact references recorded in the manifest and the bundle-local artifacts that the workflow treats as canonical.

## Bundle export

`dwarf/bundles/<run-id>.tar.gz` is a gzipped tar of the full `dwarf/runs/<run-id>/` directory. The tarball's own sha256 is recorded in the corresponding chain entry (added in Slice 2 implementation). Re-tarring the same run directory will produce a different sha256 (timestamps in tar headers); the chain entry references the bundle that was written at run-seal time, so re-tarring after the fact is detectable.

## Verification

`cardano-profile verify <run-id|bundle-path>` (Slice 2) does the following:

1. Re-hash the canonical `manifest.json`.
2. Compare against the corresponding chain entry's `manifest_hash`.
3. Walk the chain back from the run's entry to genesis, recomputing each `prev_hash` as it goes.
4. Report any mismatch with the offending file and the expected vs. actual hash.

## Replay

`cardano-profile replay <run-id|bundle-path>` (Slice 11) does the following:

1. Read `manifest.json`, `scenario.yaml`, `resolved-profile.json`, `env.json`, and the recorded `seed`.
2. Re-deploy (or re-instantiate the harness) using the resolved profile and target version.
3. Re-run the scenario with the recorded seed, producing a *new* bundle with its own run id.
4. Emit `replay-comparison.md` diffing assertion outcomes between original and replay.

Replay runs are first-class entries in the chain. Their manifest's `replays` field (added in v1.1) will point back to the original.

## Replay determinism guarantees

Dwarf does not claim that every file in a replayed bundle is byte-identical to the original. The current honest contract is narrower.

### Intended to be reproducible byte-for-byte

- `scenario.yaml`
- deterministic input payloads generated from the recorded seed
- library-tier result artifacts whose payload is a pure function of the input bytes and target behavior
- comparison-oriented artifacts such as canonical manifest hashes when the scenario metadata is unchanged

### Expected to vary across runs

- `run_id`
- `started_at` / `ended_at`
- `chain.json.timestamp`
- any artifact that embeds wall-clock time, runtime root, container id, pid, port assignment, or run-local output paths
- append-only logs where timestamps are part of the record
- observation artifacts that include sampled time windows or live runtime telemetry

### Replay interpretation

The correct replay question is therefore:

- did the replay preserve the same semantic outcomes and bounded artifact class?

not:

- did every emitted file remain byte-identical regardless of runtime context?

The replay determinism evidence memo should be treated as the operational supplement to this section whenever a concrete bundle family is being audited.
