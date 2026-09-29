# Provenance: CIP-171 and blueprint pins

Two related questions this package answers, and several it deliberately does not.

## What ships, and what does not

| | ships in the npm package | where it lives |
|---|---|---|
| CIP-171 **encoder** — build, chunk, decode a record | **yes** | `src/core/cip171.ts`, re-exported from the root |
| Parameterisation **recorder** — capture what was applied to what | **yes** | optional callback on `createStandardScripts` / `createFESScripts` |
| **Emission** — attaching a record to a real transaction | **no** | `test/harness/`, excluded from the tarball |
| **Deployment** of a protocol instance | **no** | `test/harness/`, and see the constitution |

> **The package cannot publish a CIP-171 record.** It can build one — including from a bundled
> blueprint's pin, via `buildCip171RecordFromPin` (see below). Publishing is the
> deploying system's job — the record's content (this repo, this commit, this compiler, *these*
> parameters) only exists at deploy time. `DeploymentParams` is an input to this SDK.

## Building a record

```ts
import { buildCip171Metadatum, cip171Param, CompilerType } from "@easy1staking/cip113-sdk-ts";

const events = [];
const scripts = createStandardScripts(blueprint, (e) => events.push(e));
// ... parameterise as usual; `events` now holds every (rawScriptHash, params) pair

const chunks = buildCip171Metadatum({
  compilerType: CompilerType.AIKEN,
  sourceUrl, commitHash, sourcePath,
  compilerVersion: blueprint.preamble.compiler.version,   // ← see below
  env: "",                                                 // "" = built without --env
  scripts: events.map((e) => ({
    rawScriptHash: e.rawScriptHash,
    params: e.params.map(cip171Param),
  })),
});
// attach `chunks` at metadata label 1984
```

**Derive the record from the recorder, never transcribe it.** The map is keyed by the
**unapplied** script hash and its values are in **application order** — both are properties of
the parameterisation call and of nothing else. A hand-maintained second list agrees with the
deployment right up until it doesn't, and the disagreement surfaces only as a hash that verifies
to nothing.

## Three things that will bite

**1. `compilerVersion` comes from the artefact, never from your machine.** Read
`blueprint.preamble.compiler.version`. Aiken is typically installed machine-globally, and the
blueprints in this repo were built by **four different versions** — `v1.1.23+8949565` (standard
v0.5.0-alpha.3 and v0.5.0-alpha.2), `v1.1.21+42babe5` (freeze-and-seize, dummy v0.2.0, standard
v0.3.0), `v1.1.19+e525483` (dummy v0.1.0). A record naming your local toolchain is a false provenance
claim, and it fails *worse* than an absent one: the verifier rebuilds with the wrong compiler and
reports the resulting hash mismatch as **your** defect.

**2. Six fields, not five.** Constructor 0 (Aiken) carries
`[sourceUrl, commitHash, sourcePath, compilerVersion, env, parameters]`. The **merged** CIP-0171
text documents five and omits `env`; the six-field layout is the amendment (PR #1252, open at time
of writing) and it is what the reference implementation's parser requires. A five-field record is
**discarded silently** — no error, no rejection, no registry entry. This encoder emits six.

**3. `parameters` values are bytestring-wrapped.** The published CDDL says
`parameter_list = [ * plutus_data ]` and is wrong; each element is a bytestring whose *contents*
are the parameter's CBOR. Use `cip171Param`. Emitting inline `PlutusData` is not rejected — the
registry reads `.bytes` on each element, gets nothing, and stores a record whose parameters have
silently vanished while the record itself still parses.

## Building one from a bundled pin — a convenience, and its limits

`buildCip171RecordFromPin(blueprint, pin, scripts)` assembles a record from a blueprint shipped in
this package and its `UPSTREAM_PIN.json`. Import both through the `./blueprints/*` export path.
It reads no files and works in a browser.

It exists because a backend that serves a blueprint over an API typically **strips the
`preamble`**, so a consumer holding that blueprint has no compiler version — and the repo and
commit were never served at all.

> ⚠ **THIS IS A CONVENIENCE, NOT THE ARCHITECTURALLY CORRECT HOME.** This package's pin describes
> **what it bundled**. A deploying system must describe **what it deploys**. Those coincide only
> while the two artefacts agree, and a CIP-171 record is a permanent public claim. A deployer that
> serves its own provenance — commit, path and the `preamble.compiler` it already holds — is
> strictly more correct, and should prefer that.

**Do not copy the repo/commit/compiler triple into your own code instead.** A second copy drifts
silently: the day this package ships a new blueprint, the copied triple still encodes, still
publishes, and still *verifies* — against the wrong source.

The helper refuses rather than guesses. It requires the pin to be `VERIFIED`, to name a full
40-character commit, and to agree with the blueprint on title, compiler and validator count — and
then, because those catch a wrong pin but not a differently-compiled artefact sharing a preamble,
**every recorded script must exist in the blueprint the pin describes**. A script parameterised
from elsewhere is refused, because a record naming this commit beside that hash would verify
against source that never produced it.

⛔ **What it cannot check:** that the commit is still *reachable* upstream. That needs the network,
and a `provenance` field is a claim while reachability is a fact — a squash-merge can orphan a
commit that was reachable when the pin was written. Assert it separately before publishing.

## Verifying a record you built

**"It submitted" is not evidence.** Acceptance has three levels and only the third is acceptance:

1. the transaction submitted — consistent with success *and* total failure
2. a lookup by tx hash returns 200 — proves **ingestion only**; `PENDING` and `REJECTED` rows
   both return 200
3. **`status == "VERIFIED"`, and every covered script is `COMPLETE` or `NONE_REQUIRED` — never
   `PARTIAL` — with a `finalHash` matching the deployed hash**

The per-script half is load-bearing, not belt-and-braces: a record can report `VERIFIED` while a
script inside it has no final hash and proves nothing.

Offline, the strongest check is **recomputation**: parameterise the raw script with the recorded
arguments, hash it, and compare against the hash actually deployed. See
`test/devnet/cip171-provenance.test.ts`.

**The comparison needs two operands, and one of them must not come from this package.**
`ParameterizationEvent` carries both hashes so the check is buildable at all:

| field | what it is | role |
|---|---|---|
| `rawScriptHash` | blake2b-224 of the **unapplied** code | the CIP-171 map **key** |
| `appliedScriptHash` | blake2b-224 **after** `params` were applied | the hash that gets deployed |

Recompute from `rawScriptHash` + `params`, then compare against `appliedScriptHash` — and
compare *that* against a hash you obtained **independently**: `DeploymentParams`, the chain, an
explorer. Comparing your recomputation only to your own recomputation runs, passes, and proves
nothing; it is the same vacuous shape as a record that reports `VERIFIED` with a `PARTIAL`
script inside it.

Two traps in this pair:

- **They are one field apart and read alike.** Keying a record on `appliedScriptHash` produces a
  record no verifier can match, because verifiers rebuild from source and therefore only ever
  hold the *unapplied* hash.
- **The recorder fires per parameterisation, not per distinct script**, and `createFESScripts`
  runs inside the plugin's `init()`. A second `init` appends a second full set — 8 events, still
  4 distinct scripts. **Dedupe by `rawScriptHash` before counting**; a coverage guard pinned
  against the raw event count refuses a correct record on the second mount.

## Where a record may live

CIP-0171 associates a record with a script **by script hash, not by transaction** — verifiers
scan for label 1984, rebuild from source, and match against on-chain script hashes. A record may
therefore be published **later, by anyone, in any transaction**. This repo uses both shapes:

- **attached** to the bootstrap transaction, for a core deployment — one artefact to inspect
- **standalone**, in its own metadata-only transaction, for substandard registration, where the
  transaction is built by SDK API rather than by the deployer

Neither is more valid than the other.

## Blueprint provenance pins

Every directory under `blueprints/` carries an `UPSTREAM_PIN.json` beside its `plutus.json`,
recording the upstream repo, the **commit** (never a tag — the upstream repo publishes none), the
compiler required to reproduce it, and a `provenance` field:

| value | meaning |
|---|---|
| `VERIFIED` | reproduced byte-identically from the named commit |
| `UNVERIFIED` | not reproducible today — the named commit is unreachable, or reproduction has not been done |
| `UNKNOWN` | provenance was never established |

**Current state of shipped blueprints:**

| blueprint | provenance |
|---|---|
| `standard/v0.0.1` | **VERIFIED** (2026-09-24) — **the SDK's current target**, and upstream's first mainnet release candidate. Rebuilt from `6b75ba3286b4692ca23059ff51285db357fb09c6` with Aiken v1.1.23+8949565 in a throwaway clone, upstream's own copy deleted first so it could not be mistaken for the output; sha256 `b6c8cb0…`, 164112 bytes, byte-identical. ⚑ **IT IS A RELABEL OF `0.5.0-alpha.5`**: all 34 validators' `compiledCode`, `definitions` and validator metadata are identical, and `preamble.version` is the only difference in the file — so every derived script hash is unchanged and an alpha.5 deployment needs no redeployment (`test/relabel-0.0.1.test.mjs`). **Pinned to the COMMIT, not the tag:** `v0.0.1` is an annotated tag (`03399d06…`) whose target is `6b75ba32…`; a tag can be moved or re-cut, a commit cannot. ⚠ **DIRECTORY-NAME HAZARD:** upstream RESTARTED its version series, so `v0.0.1` sorts BEFORE `v0.3.0` and `v0.5.0-alpha.*` here while being NEWER than all of them — do not read the directory listing as a timeline. ⚠ **Which clone:** reproduced from `workspace/cip113-programmable-tokens-onchain`, as for alpha.5. |
| `standard/v0.5.0-alpha.5` | **VERIFIED** (2026-09-23) — superseded as the target by `v0.0.1`, which is byte-identical to it; retained because alpha.5 instances are deployed and their credentials are unchanged. Rebuilt from `b83a041eaa053625c502f8ee64b607a787cf5f79` with Aiken v1.1.23+8949565 in a throwaway clone, upstream's own copy deleted first so it could not be mistaken for the output; sha256 `ca53475…`, 164120 bytes, byte-identical. ⛔ **THE COMMIT IS NOT ON `main`.** It is the head of the PR branch `feat/verify-upgrade-authority-at-deployment`, co-reachable as `refs/pull/143/head` — verified by `git ls-remote` on the day of vendoring, when `main` stood at `c3d04b9`. A squash-merge orphans a branch head the instant it lands, which has bitten this repo twice; the pull ref is what keeps the artefact fetchable afterwards. ⚑ The SCOPE NOTE that qualified alpha.2/3/4 is GONE at this commit, and its absence is the news: `aiken.toml` now pins `aiken-lang/fuzz` to the tag `v2.2.0` rather than the branch `main`, so both dependencies are immutable refs. ⚠ **Which clone:** reproduced from `workspace/cip113-programmable-tokens-onchain`. The checkout whose path reads like "the dependency", `workspace/deps/cip113-programmable-tokens`, sits at `018415de` and cannot produce this tree. |
| `standard/v0.5.0-alpha.4` | **VERIFIED** (2026-09-11) — rebuilt from `7e8a63198c5b240135f1aa2f043ce5d7c046b2c4` with Aiken v1.1.23+8949565 in a throwaway copy, upstream's own copy deleted first so it could not be mistaken for the output; sha256 `5ff5d6d…`, 164444 bytes, byte-identical. This supersedes the earlier alpha.4 pin at `d37ca8d`: compiled validator bytes are identical, while #135 renamed blueprint metadata and #136 added tests. ⚠ Its reproducibility claim is SCOPED: `aiken.toml` pins `aiken-lang/fuzz` to mutable `main`; fuzz is referenced only from `test` and `bench` definitions and the generators serving them, and `aiken build` emits neither. |
| `standard/v0.5.0-alpha.3` | **VERIFIED** (2026-09-07) — retained for alpha.3 instances; their 0.8.x source line was never published and must be built from git. Rebuilt from `f14b3594e1d6d3ae9e8511b99d39f17dfd4a3b65` with Aiken v1.1.23+8949565 in a throwaway clone, upstream's own copy deleted first so it could not be mistaken for the output; sha256 byte-identical. ⚠ Its reproducibility claim is SCOPED: `aiken.toml` pins `aiken-lang/fuzz` to mutable `main`; fuzz is referenced only from `test` and `bench` definitions and the generators serving them, and `aiken build` emits neither. |
| `standard/v0.5.0-alpha.2` | **VERIFIED** — retained, NOT superseded: a live preview instance runs it (`deployments/preview/alpha2.json`). Deleting it would orphan a running deployment |
| `substandards/freeze-and-seize/v0.1.0` | **VERIFIED** |
| `standard/v0.3.0` | `UNVERIFIED` — **not recoverable by pushing**: its pin names *no commit at all*, because the artefact matches no commit in upstream's history. A legacy blueprint; `src/` does not load it |
| `substandards/dummy/v0.2.0` | **VERIFIED** (2026-08-27) — rebuilt from `e63fa0a` with Aiken v1.1.21; sha256 byte-identical |
| `substandards/dummy/v0.1.0` | `UNKNOWN` — **PERMANENT**: `upstream.repo` and `upstream.commit` are both null; the source project was never recorded anywhere in this repo, so there is no origin to recover and no push or rebuild can manufacture one |

> **Do not emit a CIP-171 record for a blueprint that is not `VERIFIED`.** A record is a
> permanent, public claim that named scripts came from a named commit; if nobody can fetch that
> commit, the claim cannot be checked and should not be made. Unlike a file, a metadatum cannot
> be deleted. The record builder in this repo's harness refuses non-`VERIFIED` blueprints for
> exactly this reason.
