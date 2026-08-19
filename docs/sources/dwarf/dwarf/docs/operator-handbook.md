# Dwarf Operator Handbook

For people who install and run Dwarf locally to test, fuzz, and security-test Cardano implementations. Non-expert friendly.

## What Dwarf is, in one paragraph

Dwarf is a local framework that runs reproducible, tamper-evident tests against Cardano node implementations (cardano-node and Amaru). Every run produces a self-contained evidence bundle — what code was tested, what inputs were used, what happened, and how to redo it — and links into a hash chain so nothing can be quietly edited after the fact. The goal is that any result Dwarf produces can be re-run by anyone, anywhere, and verified to match.

## What you need before installing

- **Always**: Python 3.12+, git.
- **For library-tier scenarios** (parser fuzzing, cross-impl compare): Rust toolchain (`rustup`) for Amaru shims; GHC 9.6+ + cabal + CHaP for cardano-node shims; the codebases checked out under `codebases/amaru/` and `codebases/cardano-node/`. macOS Homebrew users also need `libsodium`, `secp256k1`, and `libblst` (build from `https://github.com/supranational/blst` if not packaged).
- **For devnet-tier scenarios**: a Linux host (we use `the Linux target host`) with Docker + the `dwarf/cardano-node` image built (`make -C dwarf/targets cardano-node-install`). For fault-injection scenarios, also `gaiaadm/pumba:latest`.

Run `cardano-profile prereq-check` at any point to see what's missing on the deployment host.

## Installing

```bash
# In the package root:
bash delivery/tests/test_delivery_contract.sh
```

No pip install is required for the shipped dashboard image. The CLI entrypoint
inside the framework tree is `./dwarf/cardano-profile`.

## The end-to-end loop, in plain English

The framework's primary loop is: pick a scenario → run it → look at the bundle.

### 1. Pick a scenario

Browse `dwarf/scenarios/` or open the dashboard's Operate views. Each scenario
is a YAML file describing one test: which parser or runtime probe to drive, what
kind of inputs to use, and what to assert. The retained M2 catalog covers
Conway-era CBOR parsers and mini-protocol decoders for Amaru and cardano-node,
plus first-execution runtime examples.

### 2. Run it

**From the dashboard** — open the dashboard (`./dwarf/cardano-profile dashboard serve`), navigate to **Scenarios**, click **Run** on whichever scenario you picked. Live output streams into the panel below the table; when it finishes the run appears on the **Tests & Evidence** page in the Recent Runs table.

**From the CLI** — `./dwarf/cardano-profile scenario run dwarf/scenarios/<scenario-id>.yaml`. Same forensic bundle is produced.

### 3. Look at the bundle

Click the run id in Recent Runs to open the inspector at
`/operate/runs/<run-id>`. The page explains what was tested, what passed or
failed, and exposes the full manifest, assertions, log tail, probe series, and
chain entry. Every bundle gets an automatic **Tamper check** verifying the
bundle hash has not changed since it was sealed.

## Reading evidence bundles

Every run writes to `dwarf/runs/<run-id>/` (or `ADA2_DWARF_RUNS_DIR` if set):

- `manifest.json` — canonical record of the run (scenario id, target, runtime, exit status, start/end timestamps, actor, resource snapshot).
- `scenario.yaml` — exact scenario file that ran, byte-for-byte.
- `resolved-profile.json` — devnet profile contents, or `null` for library-tier.
- `env.json` — captured environment (Python, OS, host, clock).
- `log.ndjson` — append-only structured event log, one JSON event per line.
- `probes/<name>.ndjson` — time-series probe samples.
- `outputs/{stdout.log, stderr.log, exit_status.txt, command.txt}` — what the remote command produced (legacy CLI flows).
- `assertions.json` — assertion outcomes.
- `chain.json` — this run's hash-chain entry linking it to the previous run.
- `cross-impl-comparison.md` — only present on the second run of a `compare` pair; the diff report.

The chain head lives at `dwarf/state/chain-head.json` and is updated atomically after each run.

Override the default directories with `ADA2_DWARF_RUNS_DIR`, `ADA2_DWARF_STATE_DIR`, `ADA2_DWARF_BUNDLES_DIR`.

## Comparing implementations

The compare flow runs the same scenario against both Amaru and cardano-node using the same RNG seed (so identical byte sequences are fed to each), then diffs the outcomes.

**From the dashboard** — open `/compare`, click **Run compare** next to a scenario. Two bundles are produced; the cardano-node-side bundle gets a `cross-impl-comparison.md` reporting AGREED or DIVERGED. Both bundles show the comparison card in their inspector page.

**From the CLI** — `./dwarf/cardano-profile compare dwarf/scenarios/<scenario-id>.yaml`. Exits 0 on AGREED, 1 on DIVERGED.

## Verifying that nothing has been tampered with

```bash
./dwarf/cardano-profile verify <run-id>
```

`verify` re-hashes the bundle's `manifest.json`, compares it to the `manifest_hash` recorded in the chain entry, then walks the chain back to genesis, recomputing each entry's `prev_hash`. Any edit — to a manifest, an earlier chain entry, or anything in between — breaks the chain and `verify` reports the exact file and the hash mismatch. Exit 0 on success; non-zero on any mismatch.

## Re-running a past test (replay)

```bash
./dwarf/cardano-profile replay <run-id>
```

Reads the original bundle's `scenario.yaml` and recorded seed, executes a fresh run with identical inputs against the current environment, writes a new bundle, and emits a `replay-comparison.md` diffing assertion outcomes between the original and the replay.

## Authoring your own scenario

Authoring guide: `dwarf/spec/v1/README.md`. Two complete worked examples live
in `dwarf/spec/v1/schema.yaml`. Pick the lowest runtime tier that does the job:

- `library` — no node, no devnet. Used for parser/decoder/serialization fuzzing.
- `single-node` — one node process, no devnet. Mini-protocol, single-node resource probes.
- `devnet` — full multi-node devnet. Consensus, peer selection, cross-node behaviour.

## What Basic vs Advanced views show

Toggle in the header. Persists per-browser.

- **Basic**: plain-English summaries, one primary action per card. No SSH commands, no exit codes, no JSON.
- **Advanced**: same data plus the underlying CLI command, exit codes, raw payloads, full log/probe tables.

Default is Basic. The same `/api/status` payload feeds both — switching modes is purely a CSS toggle.

## Token gate

Every mutating endpoint (`POST /api/scenario/run`, `/compare`, `/paste`, `/promote`, `/api/deploy`, `/api/remove`, `/api/fuzz/run`, `/api/test/smoke/run`) requires a token query parameter. Default token is `dwarf`. Override at startup:

```bash
./dwarf/cardano-profile dashboard serve --token <your-token>
```

Or set `ADA2_DWARF_TOKEN`. The dashboard page reads `?token=...` from its own URL; to use a non-default token, open the dashboard at `http://host:8787/?token=<your-token>`. Read-only routes don't require a token.

## Showing remote bundles

If you run the framework on multiple hosts (e.g. dashboard on macOS but bundles produced on the Linux target host), set `ADA2_DWARF_REMOTE_SOURCES`:

```bash
ADA2_DWARF_REMOTE_SOURCES="target-host=ssh://user@host/opt/dwarf/evidence-runs" \
  ./dwarf/cardano-profile dashboard serve
```

Recent Runs table merges local + remote entries with a Source column. Multiple sources are comma-separated. SSH key auth must be set up between the two hosts.

## A complete walkthrough (non-expert)

1. Start the dashboard: `./dwarf/cardano-profile dashboard serve`
2. Open `http://127.0.0.1:8787/` in a browser.
3. Read the "What is this?" card. Click **Scenarios**.
4. Pick `amaru-cbor-tx-body-fuzz` (or any other). Click **Run**.
5. Watch the live log in the panel below the table — should take a few seconds for 100 iterations.
6. Click **Tests & Evidence** in the nav. Your run is at the top of Recent Runs.
7. Click the run id. The inspector tells you in plain English: "*Of 100 inputs, 0 parsed cleanly and 100 were rejected as invalid — no crashes or panics.*" Plus a green Tamper check badge.
8. Click **Compare** in the nav. Click **Run compare** next to the same scenario.
9. After it finishes, two new runs appear in Recent Runs. Click into the cardano-node-side one. The inspector now also shows a "Cross-impl comparison: AGREED" card.
10. Click **Download evidence bundle** to grab the `.tar.gz`. Hand it to anyone — they can `cardano-profile verify <run-id>` to confirm it hasn't been altered, or `cardano-profile replay <run-id>` to re-run the exact test on their machine.

That's the entire loop. The framework's value is that step 10 is meaningful — every test produces evidence anyone can independently reproduce and verify.

## Scope

This V3 package presents the deployed Dwarf framework, M2
serialization/deserialization scenarios and target catalog, profiles, first
execution outputs, and preserved example bundles.
