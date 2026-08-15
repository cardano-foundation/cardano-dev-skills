# Serialization/Deserialization Analysis (Milestone 2)

Date: 2026-04-28

This document satisfies the Milestone 2 (M2) deliverable “Serialization/deserialization analysis for transactions and blocks” from [contract-milestones-tasklist.md](user/milestones/contract-milestones-tasklist.md). It is an audit of the Cardano codec surface against current Dwarf fuzzing, differential, and substrate-scenario coverage.

## Scope and method

This pass audits the codec surface that matters for Cardano node interoperability and hostile-input handling:

- block and transaction envelopes
- mini-protocol message codecs
- ledger-crossing types that are serialized over node interfaces or reused inside envelopes
- era-specific variants where current code or canonical specs split materially

The audit draws from four source classes:

1. canonical Concise Binary Object Representation (CBOR) / Concise Data Definition Language (CDDL) references, primarily the Ouroboros protocol CDDL wrappers and the `pallas-primitives` era definitions;
2. Amaru implementation pointers in `codebases/amaru/`;
3. Haskell reference pointers in extracted `ouroboros-network` sources and adjacent `cardano-node` review notes;
4. current Dwarf evidence: library fuzz scenarios, cargo-fuzz / AFL smoke bundles, differential scenarios, and remotely proven substrate scenarios.

Scope limits:

- Plutus phase-2 script-validation asymmetry is outside the codec inventory below and is tracked separately from the M2 serialization/deserialization surface.
- Structured library fuzz bundles currently do not export AFL-style `bitmap_cvg` / `execs_done`; those rows are recorded honestly as “structured fuzz only; no campaign bitmap exposed.”

## Coverage signal legend

- **AFL campaign signal**: `bitmap_cvg` and `execs_done` taken from `outputs/aflpp/default/fuzzer_stats` in the latest campaign/smoke bundle.
- **Structured fuzz only**: scenario exists and ran, but no comparable AFL campaign metric is emitted in the bundle surface.
- **Differential yes / partial / no**:
  - `yes`: a differential harness or explicit parity scenario exists.
  - `partial`: both implementations are fuzzed or compared adjacently, but not by a codec-specific differential harness.
  - `no`: no current differential path.

## Remotely proven codec quick wins

Three end-to-end substrate scenarios were added and remotely proven on `the Linux target host` for codec-adjacent rejection behavior:

| Scenario | Run id | Assertions | Evidence |
| --- | --- | --- | --- |
| `runtime-substrate-serdes-blockfetch-invalid-block-cbor-example-smoke` | `20260428T064357Z-223bf4d2` | `all_nodes_responsive`, `blockfetch_invalid_block_rejected` | `invalid_block_rejected=true` via mutated BlockFetch payload |
| `runtime-substrate-serdes-txsubmission-unexpected-body-example-smoke` | `20260428T064422Z-af3bdbf1` | `all_nodes_responsive`, `txsubmission_unexpected_body_rejected` | `unexpected_body_rejected=true`, `rejection_reason=NotInFlight` |
| `runtime-substrate-serdes-malformed-input-differential-example-smoke` | `20260428T064446Z-efbb7670` | `all_nodes_responsive`, `malformed_input_parity_preserved` | `observed_divergence=false`, `parity_match=true` |

These are not substitutes for parser fuzzing. They prove that codec-path faults already reachable on the current primitive surface are exercised end to end against a composed substrate and rejected gracefully.

## Codec inventory

### Block / transaction / ledger-envelope codecs

| Codec row | Canonical spec source | Amaru pointer | Haskell pointer | Current Dwarf coverage | Coverage signal | Differential | Gap / next step |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Block envelope (Conway block + header + body) | `codebases/pallas/pallas-primitives/src/conway/defs.cddl:8-18`, `:71-140` | `crates/amaru-kernel/src/cardano/block.rs:23,119`; `block_header.rs:27,150` | `cardano-ledger` block types plus `ouroboros-network` BlockFetch codec at `.../BlockFetch/Codec.hs:72-120` | `amaru-cbor-block-fuzz`, `amaru-cbor-block-fuzz-structured`, cargo-fuzz block target, differential block fuzz cargo-stage1/2, remotely proven `runtime-substrate-serdes-blockfetch-invalid-block-cbor-example-smoke` | AFL campaign: block smoke `20260427T112231Z-0f80e888`, `bitmap_cvg=12.41%`, `execs_done=861189` | partial | Coverage exists but is block-level. Header/body subcomponents still inherit block-level evidence rather than dedicated differential harnesses. |
| Block header | `conway/defs.cddl:71-84` | `block_header.rs:27,150` | `ouroboros-network` ChainSync header path at `.../ChainSync/Codec.hs:73-120` | `amaru-cbor-block-header-fuzz`, `amaru-cbor-block-header-fuzz-structured`, cardano-node analogs | structured fuzz only (`20260419T085020Z-62fb941b`) | no | Proposed medium next step: `amaru-cardano-differential-cbor-block-header-fuzz` harness. |
| Transaction body (Conway) | `conway/defs.cddl:119-140` | `transaction_body.rs:37,188` | `cardano-ledger` tx-body decoders; wire entry also appears in `TxSubmission2` codec at `.../TxSubmission2/Codec.hs:88-120` | `amaru-cbor-tx-body-fuzz`, `amaru-cbor-tx-body-fuzz-structured`, cardano-node analogs | structured fuzz only (`20260419T101155Z-fdfe2897`) | no | Medium gap: dedicated differential tx-body harness. |
| Witness set | `conway/defs.cddl:683+` | `witness_set.rs:39` | `cardano-ledger` witness-set decoders | no dedicated Dwarf harness found | n/a | no | Proposed medium harness target: `amaru-cbor-witness-set-fuzz` plus cardano-node peer harness. |
| Auxiliary data | `conway/defs.cddl:739+` | `auxiliary_data.rs:19,93,122,130,142` | `cardano-ledger` auxiliary-data decoders | `amaru-cbor-auxiliary-data-fuzz`, `...-structured`, cardano-node analogs | structured fuzz only (`20260419T072156Z-8b7bf69f`) | no | Harness exists; no current differential comparator. |
| Certificates | `conway/defs.cddl:28-46` | `certificate.rs:15` (re-export to Conway `Certificate`) | `cardano-ledger` certificate decoders | `amaru-cbor-certificate-fuzz`, `...-structured`, cardano-node analogs | structured fuzz only (`20260419T072219Z-b1803798`) | no | Harness exists; still no differential comparator. |
| Governance actions | `conway/defs.cddl:564+` | `governance_action.rs:15` (re-export to Conway `GovAction`) | `cardano-ledger` Conway governance decoders | no dedicated Dwarf harness found | n/a | no | Proposed medium harness target: `amaru-cbor-governance-action-fuzz`. |
| Protocol parameters | `conway/defs.cddl:582+` | `protocol_parameters.rs:32,185,371,409` | `cardano-ledger` protocol-parameter decoders | no dedicated Dwarf harness found | n/a | no | Proposed medium harness target: `amaru-cbor-protocol-parameters-fuzz`. |
| Era summary | `Conway` era-summary exposure is not directly in the above CDDL files; node-facing encoding comes through LSQ result types | `era_summary.rs:22,100` | LocalStateQuery codec at `.../LocalStateQuery/Codec.hs:10+` plus ledger-era query types | substrate-era LSQ extraction exists; no dedicated fuzz harness | n/a | partial | Small-to-medium gap: LSQ era-summary shape rejection shim plus dedicated decoder harness if byte-level fuzzing is desired. |
| Transaction outputs / UTxO crossed inside tx body | `conway/defs.cddl:151-154`; `babbage/defs.cddl:228-233` | `transaction_body.rs` output fields; memoized output support in kernel | `cardano-ledger` tx-output decoders | indirect via tx-body fuzz only | structured fuzz only via tx-body bundles | no | Covered only indirectly; large step if split out into standalone UTxO/output harnesses. |

Era note:

- Current structured Dwarf scenarios are Conway-leaning for transaction/body/block shapes.
- Babbage and Alonzo variants are present in the canonical `pallas-primitives` CDDL files and the Haskell ledger stack, but Dwarf does not yet expose a per-era scenario matrix for every ledger codec row.
- Byron / Shelley / Allegra / Mary remain mostly represented through reference implementation compatibility and full-node integration paths rather than dedicated era-specific parser harnesses.

### Mini-protocol codecs

| Codec row | Canonical spec source | Amaru pointer | Haskell pointer | Current Dwarf coverage | Coverage signal | Differential | Gap / next step |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Handshake | `.../Handshake/Codec.hs:47-120` | `crates/amaru-protocols/src/handshake/messages.rs:22,86` | `.../Handshake/Codec.hs:9-120` | `amaru-mini-protocol-handshake-fuzz`, cardano-node analog, cargo-stage fuzz variants | AFL campaign: handshake smoke `20260427T084119Z-60a4e032`, `bitmap_cvg=38.79%`, `execs_done=2422921` | partial | Missing composed-substrate handshake/version-pressure shim for deeper end-to-end fault injection. |
| ChainSync | `.../ChainSync/Codec/CDDL.hs:28-37`; implementation `.../ChainSync/Codec.hs:73-120` | `chainsync/messages.rs:23,134,185` | `.../ChainSync/Codec.hs:73-120` | mini-protocol fuzz, cargo-stage fuzz, remotely proven RR-001/002/003/035 scenarios | AFL campaign: `20260427T084322Z-3684ac69`, `bitmap_cvg=39.10%`, `execs_done=2440443` | partial | Good current coverage; no codec-specific differential harness yet. |
| BlockFetch | `.../BlockFetch/Codec/CDDL.hs:25-32`; implementation `.../BlockFetch/Codec.hs:72-120` | `blockfetch/messages.rs:18,80` | `.../BlockFetch/Codec.hs:72-120` | mini-protocol fuzz, cargo-stage fuzz, remotely proven RR-004/005/006/007/008 scenarios, new ser/deser wrapper proof | AFL campaign: `20260427T084220Z-97b63fa5`, `bitmap_cvg=34.23%`, `execs_done=2556434` | partial | Strongest current codec-path substrate proof in this family. |
| TxSubmission2 / TxSubmission | `.../TxSubmission2/Codec/CDDL.hs:11-18`; implementation `.../TxSubmission2/Codec.hs:88-120` | `tx_submission/messages.rs:25,141,221` | `.../TxSubmission2/Codec.hs:88-120` | mini-protocol fuzz, cargo-stage fuzz, remotely proven RR-009/010/011/012 scenarios, new ser/deser wrapper proof | AFL campaign: `20260427T084613Z-2f152f42`, `bitmap_cvg=40.68%`, `execs_done=2174997` | partial | Good codec-pressure coverage; local node-to-client TxSubmission still lacks shape-rejection shim. |
| KeepAlive | `.../KeepAlive/Codec.hs:9+` | `keepalive/messages.rs:18,64,70,111` | `.../KeepAlive/Codec.hs:9+` | `amaru-mini-protocol-keep-alive-fuzz`, cardano-node analog, keepalive failure cascade substrate scenario | library fuzz only, no current AFL campaign bundle surfaced in this audit | partial | New scenario stub authored: `runtime-substrate-serdes-keepalive-cookie-mismatch-example-smoke`; blocked on `runtime_keepalive_cookie_mismatch` shim. |
| PeerSharing | `api/lib/Ouroboros/Network/PeerSelection/PeerSharing/Codec.hs:22-65`; protocol implementation pointer `protocols/lib/Ouroboros/Network/Protocol/PeerSharing/Codec.hs` | `peersharing` target/manifests and protocol decoders in Amaru target corpus | reference implementation coverage currently tracked through parallel cardano-node fuzz scenarios and the extracted `PeerSharing` codec modules | `amaru-mini-protocol-peersharing-fuzz`, cardano-node analog | library fuzz only, no current AFL campaign bundle surfaced in this audit | partial | New scenario stub authored: `runtime-substrate-serdes-peersharing-shape-rejection-example-smoke`; blocked on `runtime_peersharing_shape_rejection`. |
| LocalStateQuery | `.../LocalStateQuery/Codec/CDDL.hs:48-55`; implementation `.../LocalStateQuery/Codec.hs:10+` | no dedicated Amaru substrate shim in current surface; LSQ extraction exists on the cardano-node side | `.../LocalStateQuery/Codec.hs:10+` | no dedicated fuzz harness; existing LSQ extraction and local-query stress scenarios are adjacent, not shape-rejection tests | n/a | no | New scenario stub authored: `runtime-substrate-serdes-localstatequery-shape-rejection-example-smoke`; blocked on `runtime_localstatequery_shape_rejection`. |
| LocalTxSubmission | `.../LocalTxSubmission/Codec/CDDL.hs:11-18`; implementation `.../LocalTxSubmission/Codec.hs:12+` | no dedicated current Amaru substrate shim | `.../LocalTxSubmission/Codec.hs:12+` | no dedicated fuzz harness; local-submit stress exists but is not a codec-shape test | n/a | no | New scenario stub authored: `runtime-substrate-serdes-localtxsubmission-shape-rejection-example-smoke`; blocked on `runtime_localtxsubmission_shape_rejection`. |
| LocalTxMonitor | `.../LocalTxMonitor/Codec/CDDL.hs:12-19`; implementation `.../LocalTxMonitor/Codec.hs:12+` | no dedicated current Amaru substrate shim | `.../LocalTxMonitor/Codec.hs:12+` | no dedicated fuzz harness found | n/a | no | New scenario stub authored: `runtime-substrate-serdes-localtxmonitor-shape-rejection-example-smoke`; blocked on `runtime_localtxmonitor_shape_rejection`. |

## Gap surfacing

### Authored scenario stubs that now name the missing substrate shims

These scenarios validate locally and make the next substrate work concrete without widening the primitive surface in this lane:

| Scenario stub | Missing primitive | Why it exists now | Cost |
| --- | --- | --- | --- |
| `runtime-substrate-serdes-keepalive-cookie-mismatch-example-smoke` | `runtime_keepalive_cookie_mismatch` | exercise malformed KeepAlive cookie / response framing against live substrate | small |
| `runtime-substrate-serdes-peersharing-shape-rejection-example-smoke` | `runtime_peersharing_shape_rejection` | prove malformed PeerSharing payload rejection without peer-set collapse | medium |
| `runtime-substrate-serdes-localstatequery-shape-rejection-example-smoke` | `runtime_localstatequery_shape_rejection` | exercise malformed local query request handling | medium |
| `runtime-substrate-serdes-localtxsubmission-shape-rejection-example-smoke` | `runtime_localtxsubmission_shape_rejection` | exercise malformed local tx submission request handling | medium |
| `runtime-substrate-serdes-localtxmonitor-shape-rejection-example-smoke` | `runtime_localtxmonitor_shape_rejection` | exercise malformed local tx monitor request handling | medium |

### Proposed new harness targets

These are not scenario-shim gaps. They are new harness gaps where Dwarf currently lacks direct parser fuzz coverage:

| Proposed harness target | Codec surface | Cost | Reason |
| --- | --- | --- | --- |
| `amaru-cbor-witness-set-fuzz` | transaction witness set | medium | witnesses are currently covered only indirectly through broader tx or block shapes |
| `amaru-cbor-governance-action-fuzz` | Conway governance actions | medium | governance payloads are re-exported but not fuzzed directly |
| `amaru-cbor-protocol-parameters-fuzz` | protocol parameter updates | medium | protocol-parameter maps are consensus-critical and structurally rich |
| `amaru-cbor-era-summary-fuzz` | era summary encoding / decoding | medium | era summary currently appears only through LSQ extraction paths |
| `amaru-cardano-differential-cbor-block-header-fuzz` | block header | medium | header parser exists on both sides but no differential comparator is present |
| `amaru-cardano-differential-cbor-tx-body-fuzz` | tx body | medium | tx-body fuzz exists on both sides but is not compared by a dedicated differential harness |

## Assessment

Current state of the codec surface:

- **Strongest coverage today**
  - ChainSync, BlockFetch, and TxSubmission message codecs.
  - Block-level CBOR and malformed-input differential paths.
  - End-to-end rejection behavior for three codec-adjacent substrate cases now remotely proven.
- **Moderate coverage today**
  - Handshake, KeepAlive, PeerSharing, and the structured transaction/block parsers where standalone fuzz exists but differential or substrate rejection coverage is incomplete.
- **Weakest coverage today**
  - Local node-to-client codec shapes (`LocalStateQuery`, `LocalTxSubmission`, `LocalTxMonitor`).
  - Witness sets, governance actions, protocol parameters, and era summaries as direct fuzz targets.

The remaining gaps are explicit and bounded:

- **small**: one new substrate shim on top of an already-validated scenario shape;
- **medium**: a new mini-protocol shape-rejection shim or a new dedicated harness target;
- **large**: a new per-era matrix or deeper ledger / Plutus-specific semantic surface.

## Deliverable close-out

This M2 artifact now provides:

1. a per-codec inventory with spec and implementation pointers;
2. honest mapping from each codec row to current Dwarf fuzz / differential / substrate coverage;
3. concrete next steps for every uncovered codec row;
4. first end-to-end ser/deser substrate executions on `the Linux target host` for currently authorable cases.

It does **not** claim that every codec listed above has a dedicated deep differential harness today. It does claim that the current surface is now inventoried, evidenced, and narrowed into specific next-step scenarios or harness targets.
