# cardano-init: Roadmap

**Status:** Draft · **Last updated:** 2026-06-03 · **Owner:** Robertino Martinez

> Sequencing and milestones. The *why/for whom* is in [PRD.md](./PRD.md); the *how* in [ARCHITECTURE.md](./ARCHITECTURE.md) and [TECH_SPEC.md](./TECH_SPEC.md). This roadmap is anchored on two external **Developer Experience Initiative (DX)** milestones tied to delivery; scope may shift after the DX.02 community/key-player review (that review exists precisely to pressure-test the specs before the RC).

## Milestones at a glance


| Phase | Milestone | Date | Outcome |
|-------|-----------|------|---------|
| **0** | **DX.02**: Specs + POC | **31 Aug 2026** | A working, could-be-final tool showing **all five roles**, with specs/architecture/integration strategy, shown to the community + key players for feedback. |
| **1** | **DX.05**: RC ready | **30 Nov 2026** | Public **Release Candidate**: reduced-stack CLI that builds green, **docs**, a dependency **install** command (nice-to-have), hardened CI/CD + tests. |
| **2** | Post-RC / GA | TBD (post-Nov) | Stabilize RC → GA, widen the stack, promote auto-install to supported. |
| **3** | Later | Unscheduled | Plugin hooks, min-version checks, community-driven scope. |

Deliverables below are tracked as checklists (`[ ]` = not yet done).

---

## Phase 0: DX.02 · Specs + POC (31 Aug 2026)

**Milestone acceptance (verbatim):** *"A clear plan on how we'll implement this tool with a POC. Repository with defined scope, specs, architecture, plugin/project integration strategy, and POC."*

**Intent (beyond the letter):** the POC should be **good enough to pass as the final product**, not a throwaway. It's what we put in front of key players, so it must *work*. Breadth of the tooling story matters here: **all five roles are present and generating.**

### Deliverables

**Specs & strategy**:
- [ ] `docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/TECH_SPEC.md`, `docs/ADDING_A_TOOL.md`.
- [ ] **Plugin/project integration strategy** = the interface contract (§4 TECH_SPEC) + the data-driven registry + the deps/installer model. This *is* the "how a tool plugs in" story the milestone asks for; make sure it reads as such.

**The tool: all five roles present, four building green, formal-methods experimental:**
- [ ] **On-chain:** Aiken; make the template genuinely `build`+`test` green (blueprint at canonical path).
- [ ] **Off-chain:** MeshJS + Tx3; both generate and build.
- [x] **Infrastructure:** filled via `cardano-up` — **Kupo, Ogmios, Dolos, Tx Submit API, Cardano Node, Cardano Node API, and Dingo** ship as selectable providers that aggregate into a single `infra/` component (one cardano-up context per project). Adding further providers is pure data (a registry TOML, no template). Uses `cardano-up`'s released `--context` flag (blinklabs-io#294). Yaci DevKit remains in the **devnet** role (it is a dev/test kit, never deployed).
- [ ] **Devnet:** Yaci DevKit (local devnet — its `dev` starts a Blockfrost-compatible devnet and writes the standard `.env` connection vars, so off-chain connects to it automatically; `test` runs an integration smoke test).
- [x] **Formal-methods:** experimental; visible in the registry/UI as "experimental"; Blaster is a WIP upstream tool *and* its integration isn't build-green yet (made real at DX.05). Registry `experimental` flag (per-tool, §3.2.1 — covers unstable-upstream and/or not-build-green) surfaced across `list`/`--help`, interactive, and one-shot, and **gated** behind `--allow-experimental` / an interactive confirm so it can't be scaffolded unknowingly; `list`/component JSON carry it for agents.

**Feature surface:**
- [ ] Interactive CLI and one-shot CLI (polish; deterministic output).
- [x] `list` subcommand + global `--format human|json` presenter + machine-readable error codes (agent surface, PRD FR-13/14/15).
- [x] **`cardano-init doctor`** standalone command + check-and-advise during scaffolding (deps/installer graph, `registry/deps.toml`). *(Pulled earlier than the docs' original deferral.)*
- [ ] `--dry-run`, optional Nix flake.
- [ ] Determinism canonicalization (planner) + snapshot tests + contract-compliance tests per template.

### Success criteria

- Repo presents defined scope, specs, architecture, and the integration strategy (above).
- `cardano-init` generates projects for **all five roles** (four build-green, formal-methods experimental).
- The feature surface above is demoable end-to-end and stable enough to show key players.

### Cut-line (if behind in August)

**Protect the all-five-roles; relax build-green under pressure.** Keep every role visible and generating plus the feature surface demoable. If time is short, the harder templates (possibly Tx3) may ship as **"generates but not yet fully green,"** with SM-1 completion moved to DX.05. **Floor that never slips:** Aiken (on-chain) and MeshJS (off-chain) build green, and the project generates for every role.

---

## Phase 1: DX.05 · RC ready (30 Nov 2026)

**Milestone acceptance (verbatim):** *"First Release Candidate for the tool, with the website and docs, has been published. Users can already use this tool to create new Cardano projects with reduced tech stack options."* 

- Repo beta deemed good enough to be an RC; 
- Website with documentation, publicly accessible. 
- CLI works with reduced stack already implemented but **ready to be expanded**, with expected **non-critical** defects.

### Deliverables

**Stack: widen each role + finish build-green:**
- [ ] **A couple more tools per role** (exact picks chosen from community feedback).
- [ ] Finish **SM-1 (build+test green)** for everything shipped, including any DX.02 relaxations.
- [ ] **Formal-methods made real** (build-green), promoted from experimental.

**Docs (publicly accessible):**
- [ ] **Docs site:** Comprehensive documentation about usage for end users. It could be hosted on a dedicated website, or part of Cardano's Developer Portal.

**Dependency install command (nice-to-have, attempted):**
- [ ] `cardano-init` dependency **install** (auto-install): runs the doctor's resolved plan with consent, across the installer graph (incl. bootstrapping `aikup`/`cardano-up`, etc.). Officially nice-to-have; **first thing cut** if it threatens the RC date.

**Editing an existing project (#26):**
- [x] `cardano-init add`/`remove`: reconstruct the current selection by detection, diff at the component-directory level, re-wire the shared files, write under a git-clean safety net. Never rewrites user code in a kept component. Reuses the init compat/experimental gates. New projects are git-initialized with an initial commit so the safety net works immediately. See TECH_SPEC §15 (PRD FR-25).

**Engineering hardening:**
- [ ] **CI/CD pipeline** improvements: per-tool build smoke tests (toolchains or Nix), snapshot/determinism gates, contract-compliance gates, release artifacts.
- [ ] **Scheduled maintenance smoke run** (weekly cron): re-runs the per-tool build+test matrix to catch generated projects breaking from a hardfork / upstream release / dependency bitrot *between* commits, opening a tracking issue on failure. Distinct from PR gates (ARCHITECTURE §10).
- [ ] Version-update check (pre-generation notice, §10 TECH_SPEC).

### Success criteria

- Public repo at RC quality (non-critical defects acceptable).
- Public docs site reachable.
- CLI creates working projects across the reduced stack, **expandable** (adding a tool is data + template per ADDING_A_TOOL).

### Cut order (if behind in November)

1. Dependency **auto-install** command (explicitly nice-to-have).
2. The *extra* (second/third) tools per role → ship the DX.02 set, expand post-RC.
Never cut: the DX.02 build-green stack reaching full SM-1, and public docs.

---

## Phase 2: Post-RC / GA (TBD, post-Nov 2026)

Direction (unscheduled; shaped by RC feedback):
- Stabilize RC → **1.0 GA** (defect burndown, version/tagging scheme finalized).
- **Widen the stack** further: more tools across all roles, deeper coverage.
- Promote **auto-install** from nice-to-have to a supported path; **cardano-up self-install** when absent.

## Phase 3: Later (unscheduled)

- **Plugin/lifecycle hooks** for tools (e.g. post-scaffold actions), reserved by the architecture, not yet needed.
- **Min-version constraints** in the doctor (version detection, not just presence).
- New roles, if a real need emerges (a deliberate code change, ARCHITECTURE §3.1).

---

## Critical path & risks

- **Per-tool build-green is the long pole.** Every shipped tool must actually compile and
  pass tests (SM-1): that's real, per-tool integration work (toolchains, the blueprint/env
  wiring). New templates (**Tx3**, **Yaci DevKit**) and making the existing prototypes
  genuinely green are the bulk of DX.02 effort.
- **The doctor graph is new surface.** `registry/deps.toml` + the installer table + the
  recursive resolver + `cardano-init doctor` is net-new for DX.02; the auto-install command
  (DX.05) builds on it.
- **Formal-methods tooling is thin**: hence experimental at DX.02; the DX.05 "make it real"
  item carries the most uncertainty and may stay experimental.
- **Spec churn after DX.02 is expected and healthy.** The key-player review may change scope;
  Phase 1 picks (the extra per-role tools, formal-methods approach) are deliberately left to
  be informed by that feedback.
- **Dates are fixed (payment-linked); scope flexes.** The cut-lines above are the agreed
  release valves so the milestones land.
