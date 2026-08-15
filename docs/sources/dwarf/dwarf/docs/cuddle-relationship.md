# DWARF ↔ cuddle: relationship and integration

**For:** the Amaru / Cardano Foundation team · **Date:** 2026-07-19
**Context:** the team pointed to [`input-output-hk/cuddle`](https://github.com/input-output-hk/cuddle)
(CDDL tooling) as a Haskell-side project on a path complementary to DWARF's fuzzing, and asked us
to relate the two. This documents the relationship, the concrete value, an honest scope boundary,
and a phased integration.

## TL;DR

cuddle and DWARF are **two halves of the same coin**. cuddle generates **spec-valid CBOR** from
CDDL; DWARF **corrupts inputs adversarially and asserts oracle/differential properties**. The
natural join: **cuddle supplies the valid CBOR that a DWARF campaign needs *before* the fuzz/attack
step**, and the valid seeds the fuzzer mutates. We recommend a **shallow integration now**
(cuddle-generated seeds/scaffolding, from the official CDDL) and a **deeper one later** (retire
DWARF's hand-written CBOR shapes). The boundary to hold: cuddle covers **structural** validity, not
**semantic/consensus** validity — the latter stays DWARF-native.

## What cuddle is

cuddle is a Haskell library **and CLI** for CDDL (Concise Data Definition Language — the schema
language Cardano uses to define the shape of its CBOR data). Its CLI can:

- **format** and **validate** CDDL files,
- **generate random CBOR terms matching a CDDL production**, and
- **test compliance** of a CBOR file against a CDDL spec.

It also ships **Huddle**, a Haskell DSL for authoring CDDL — which is how much of Cardano's CDDL is
now written. cuddle does **not** bundle the Cardano CDDL specs themselves; those live in
cardano-ledger / the ouroboros-network spec.

## What DWARF does today (and why cuddle is relevant)

DWARF's structured CBOR fuzzer feeds on a **hand-written shape grammar**. Each Cardano structure is
transcribed by hand into a JSON descriptor, e.g.:

```json
{"type": "array", "elements": [
  {"type": "uint", "max": 100000},
  {"type": "bytes", "length": 32}, ...]}
```

- `generate_cbor(shape, rng)` turns that descriptor into a well-formed CBOR value.
- **5 structures** are modelled by hand — block-header, block, tx-body, certificate,
  auxiliary-data — duplicated across Amaru + cardano-node targets (**10 scenarios**).
- Seed corpora are small, hand-collected sets (typically 1–7 files per mini-protocol).
- There is **no CDDL in the DWARF repo.**

In other words, DWARF re-implemented a **narrow subset of CDDL** (`type: array/map/uint/bytes/tag`)
and a **narrow subset of cuddle** (`generate_cbor`). cuddle is the general, maintained, spec-exact
version of exactly that.

## The relationship, mapped to a campaign's lifecycle

A DWARF scenario runs **setup → load → faults/fuzz → assertions**. Only the *fault* step is
malformed; everything around it must be **valid** so the target reaches the code path under test.

| Lifecycle step | Who provides it | cuddle's role |
|---|---|---|
| **setup / load** — valid scaffolding (a valid handshake + preceding mini-protocol messages, a valid block/tx to serve or submit) | valid CBOR | **cuddle** generates it from CDDL |
| **fuzz seeds** — the valid base the mutator starts from | valid CBOR | **cuddle** generates them from CDDL |
| **faults / mutation** — corrupt one field, break an invariant, mangle bytes | DWARF | DWARF's mutation engine (byte-level + structured) |
| **assertions / oracles** — differential + pass conditions | DWARF | DWARF's oracles |

So: **cuddle = the valid-input supplier; DWARF = the corruption and the oracle.**

## The value (why this is worth doing)

1. **Retires hand-maintained work.** The 10 hand-transcribed shapes + `generate_cbor` are replaced
   by "point cuddle at the official CDDL."
2. **Eliminates spec drift (the biggest long-term win).** Hand-written shapes silently rot as
   Cardano evolves (new eras, new certificate / governance types). CDDL is the authoritative,
   ledger-team-maintained spec; regenerating from it keeps DWARF's seeds and scaffolding in lockstep
   with the real protocol.
3. **Expands coverage for free.** DWARF hand-models 5 structures; Cardano's CDDL defines dozens
   (every tx field, all certificate types, governance actions, Plutus data) — plus the
   **ouroboros-network mini-protocol messages** are CDDL-defined too (e.g. chainsync
   `msgRollForward = [2, header, tip]`). cuddle can generate valid instances of all of them with no
   per-shape hand-work, versus today's 1–7 hand-collected seeds.

## The scope boundary (what cuddle does *not* cover)

cuddle gives **structural** validity — right fields, right types, decodes cleanly. It does **not**
give **semantic/consensus** validity. Holding this line keeps expectations honest on both sides:

- **Semantic / consensus validity.** VRF proofs, signatures, stake, hash-chaining, leader election —
  i.e. DWARF's entire consensus-differential programme (false-leadership, genesis density,
  chain-selection). CDDL says "well-formed," never "consensus-valid." Where scaffolding must pass
  consensus checks (our forged chains), cuddle supplies the *envelope* but the crypto fields still
  need real signing (db-synthesizer + keys). **Stays DWARF-native.**
- **Protocol sequencing / state machine.** CDDL defines each message's shape, not the valid
  order / agency / timing of the conversation. Out-of-order / wrong-state protocol fuzzing is
  **DWARF-native**.
- **Cross-field consistency invariants.** "body-hash = hash(body)", "length field = actual length".
  CDDL's control operators (`.size`, `.cbor`) can't express derived/hash equality — and those
  consistency bugs are prime targets. cuddle gives a valid base; targeting the invariant is DWARF's.
- **Non-CBOR surfaces.** Genesis/config **JSON**, network/mux bytes, resource/timing, state-lifecycle
  — cuddle is CBOR-only.
- **Coverage-guided "interesting" inputs.** cuddle emits uniformly-random valid CBOR; it improves
  the **seed**, not the **search**. AFL++'s mutation + coverage feedback still finds the bugs.

## Integration plan

**Phase 1 — shallow (DONE / prototyped, 2026-07-19).** An offline step runs cuddle's CLI against the
Cardano CDDL to generate valid CBOR into DWARF's `--seed-dir` corpora. No change to DWARF's mutation
engine or scenario format — just better, broader, spec-synced seeds and scaffolding.
- **Built** `cuddle 1.8.1.1` (GHC 9.6.7) and ran it against the cardano-ledger **Conway** CDDL.
- **Verified** it emits structurally-real Cardano CBOR for all 5 DWARF shapes — e.g. `header` →
  `array[2] [header_body(array[10]), kes_sig(bytes[448])]`, `block` → `array[5]`,
  `transaction_body` → `map`, `certificate` → `array[10]` — each decoding fully and reproducibly by
  seed (definite-length via `--no-twiddle`).
- **Delivered** `dwarf/scripts/gen_cuddle_seeds.py` (the generator) and a starter corpus in
  `dwarf/corpora/cuddle-generated/` (16 valid + 4 negative seeds per shape, with `manifest.json`).
- **Wired in (task #40):** the valid seeds are copied into the coverage-guided AFL++/cargo-fuzz
  corpora those fuzzers actually consume (non-destructive) — `block-header` 3→19 / 1→17, `tx-body`
  3→19 / 1→17, `block` 4→20. Re-runnable via `gen_cuddle_seeds.py --wire-only`.
- **Per-era: proven** era-agnostic (Conway + Babbage both generate valid block/header/tx).
- **Still open:** mini-protocol message seeds (the ouroboros-network CDDL is multi-module/generic and
  not cuddle-consumable standalone — wrap the ledger seeds in the message envelope as a follow-on);
  seeding the lightweight random-bytes `cbor_fuzz_target` primitive (a separate primitive change);
  and the deep integration (retire the hand-written shapes), scheduled for end of contract.

**Phase 2 — deep (later, toward end of contract).** Have DWARF's structured fuzzer derive its shape
directly from CDDL instead of the hand-written JSON, retiring `generate_cbor` and the 10 hand-written
shapes. This makes the CDDL the single source of truth for structure.

**Practical notes.** cuddle is Haskell with a CLI, so the integration is an **offline seed/scaffold
generation step**, not a runtime dependency of the fuzzer. It needs the Cardano CDDL as input
(from cardano-ledger / the network spec). Verify the current cuddle CLI invocation and CDDL
availability when wiring Phase 1.

## Bottom line

cuddle is a genuine fit and a real time-saver, because DWARF already hand-built a narrower version
of it. Adopt cuddle as DWARF's **valid-CBOR source** for seeds and campaign scaffolding; keep
everything semantic, sequential, cross-field, and non-CBOR as DWARF-native. Each side keeps its own
engine; the shared, spec-derived valid CBOR is the common ground — which also matches the team's
stated goal of shared test data between the Haskell and Rust efforts.
