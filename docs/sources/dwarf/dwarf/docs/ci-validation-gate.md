# DWARF CI validation gate

A wallet-free, infra-free GitHub Action that validates the DWARF scenario corpus and the
Antithesis bundles on every push / PR. It **does not run** scenarios, fuzzers, a devnet, or any
Antithesis job — those need a self-hosted runner or a wallet-gated moog run (tracked separately as
"full scenario runs"). This gate just proves the definitions are well-formed **before** anyone
spends a real run on a broken one.

## What it checks

| Check | What it proves | Cost |
|---|---|---|
| **Schema** | every `dwarf/scenarios/*.yaml` validates against `dwarf/spec/v1/schema.json` | ms |
| **Semantic** | every scenario's referenced primitives exist in `dwarf/primitives/registry.json` (`scenario validate --semantic`) | seconds |
| **Antithesis** | every profile renders into a well-formed Antithesis bundle **offline** — no docker daemon, no registry push | seconds |

Current corpus status: **229 scenarios — 0 schema failures, 0 semantic failures, 76 warnings; 13
Antithesis profiles render cleanly.** The gate passes today; it exists to catch the next
regression (e.g. a scenario referencing an unregistered primitive — exactly the class of bug that
slipped in during an earlier reclassification).

## Files

- `.github/workflows/dwarf-validate.yml` — the workflow (push / pull_request / manual).
- `dwarf/scripts/validate_scenarios.py` — the gate logic (also runnable locally).

## Run it locally

```bash
python3 -m pip install jsonschema
python3 dwarf/scripts/validate_scenarios.py            # non-strict: warnings allowed
python3 dwarf/scripts/validate_scenarios.py --strict   # warnings are failures
python3 dwarf/scripts/validate_scenarios.py --json      # machine-readable summary
python3 dwarf/scripts/validate_scenarios.py --report out.json   # write summary to a file
```

Exit code `0` = pass, `1` = fail. In `--strict` mode, semantic warnings also fail.

## Why it's only validation (not runs)

- Antithesis runs go through **moog**, which is **approved-wallet-only** — a CI runner can't
  authenticate, so it can't trigger a real Antithesis run.
- The real differential scenarios need **docker multi-node meshes** or **AFL++ with built target
  binaries** — too heavy for a stock GitHub-hosted runner.

Actually running scenarios in CI (a light docker scenario on a hosted runner, fuzz scenarios with
prebuilt targets, and the multi-node mesh scenarios on a **self-hosted runner**) is the planned
next step, built on top of this gate.

## Note: CLI entrypoint

`dwarf/profile_manager/cli.py` gained a standard `if __name__ == "__main__": raise SystemExit(main())`
guard so `python -m profile_manager.cli …` actually runs (previously it imported and silently
no-op'd, exit 0). The gate relies on this.
