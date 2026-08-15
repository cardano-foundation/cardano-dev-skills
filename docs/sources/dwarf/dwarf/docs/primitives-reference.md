# DWARF Primitives Reference

The complete catalogue of the **204** primitives a scenario can reference — every *strategy* (what a scenario can do) and every *oracle* (what it can assert). Generated from `primitives/registry.json`; purposes/pass-conditions are curated. A scenario may only reference names listed here. Many primitives operate on CBOR (Concise Binary Object Representation), Cardano's binary wire and ledger encoding. The **Antithesis** column marks the primitives the DWARF&rarr;Antithesis generator can carry onto the Antithesis backend (CBOR-only by design &mdash; `cbor_fuzz_*` strategies, the `runtime_aflpp_campaign` coverage surface, and the assertions mapped to native SDK checks); everything else runs on the local backend only.

> Coverage: 204/204 primitives carry a curated description (100%). Any without one is still listed with its registry metadata. Regenerate with `scripts/gen_reference.py`.

> **Every primitive here is fully implemented** (no stubs). The **verified** column is *evidence of exercise*, not an implementation claim: `full` = exercised by a full scenario, `smoke` = exercised by an example / smoke scenario; `cn` = cardano-node, `amaru` = Amaru. So `smoke · cn` means "implemented, and exercised at smoke depth on cardano-node" — not "half-built." Note on targets: the registry declares cardano-node + Amaru support broadly, but Amaru is currently *verified* only on the CBOR-decode surfaces and a mixed-substrate baseline (19 primitives); elsewhere it is implemented but not yet exercised against Amaru. Computed from `scenarios/` at build time.

Every primitive lists which **runtimes** it works in (`library` / `single-node` / `devnet`) and its **verified** status &mdash; the depth and target it has actually been exercised against (see the legend below). Common plumbing params (`timeout_seconds`, `output_dir`, `runtime_metadata_path`, `helper_script`) are omitted from the notes below; see each primitive's `params_schema` for the full list.


## Load primitives — strategies (118)

What a scenario *does*. These run in the `load` phase.


### Adversarial peer / responder (shim)

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `shim_peer_invalid_cbor` | Adversarial peer that sends invalid CBOR frames to a target node. | dev | full · cn | — |
| `shim_peer_malformed_blockfetch` | Adversarial peer that sends malformed BlockFetch messages. | dev | full · cn | — |
| `shim_peer_malformed_handshake` | Adversarial peer that sends a malformed protocol handshake. | dev | full · cn | — |
| `shim_peer_malformed_txsubmission` | Adversarial peer that sends malformed TxSubmission messages. | dev | full · cn | — |
| `shim_peer_raw_bytes` | Adversarial peer that sends an arbitrary raw hex payload to a target node. | dev | full · cn | — |
| `shim_responder_stale_blockfetch` | Hostile responder that serves stale BlockFetch data to a syncing node. | dev | full · cn | — |


### BlockFetch pressure & faults

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_blockfetch_continuity_failure` | Serve a BlockFetch stream with a continuity gap to test rejection. | dev | smoke · cn | — |
| `runtime_blockfetch_delay_success` | Delay BlockFetch responses but still eventually succeed (tolerance test). | dev | full · cn | — |
| `runtime_blockfetch_delay_timeout` | Delay BlockFetch past the timeout threshold to force a timeout. | dev | full · cn | — |
| `runtime_blockfetch_drop_isolated_peer` | Drop BlockFetch traffic from an isolated peer (peer-isolation handling). | dev | full · cn | — |
| `runtime_blockfetch_drop_timeout` | Drop BlockFetch responses entirely to trigger a timeout. | dev | full · cn | — |
| `runtime_blockfetch_invalid_block_cbor` | Serve a block with invalid CBOR over BlockFetch to test rejection. | dev | smoke · cn | — |
| `runtime_blockfetch_invalid_range` | Request an invalid BlockFetch range to test rejection. | dev | smoke · cn | — |
| `runtime_blockfetch_range_mismatch` | Serve a BlockFetch response whose range mismatches the request. | dev | smoke · cn | — |
| `runtime_blockfetch_range_pressure` | Apply sustained BlockFetch range-request pressure to probe resource bounds. | dev | smoke · cn | — |


### CBOR fuzzing

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `cbor_edge_cases` | Feed a curated list of hand-crafted CBOR edge-case byte strings at a decode target and classify each. | lib | full · cn+amaru | — |
| `cbor_fuzz_structured` | Shape-aware CBOR fuzzing: generate a structurally-valid CBOR value from a shape tree, mutate inner bytes, feed to a decode target. | lib | full · cn+amaru | ✓ |
| `cbor_fuzz_target` | Blind random-bytes CBOR fuzzing of a decode target within a byte-length range. | lib | full · cn+amaru | ✓ |


### ChainSync faults

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_chainsync_nonincrementing_height` | Serve a ChainSync header with non-incrementing height to test rejection. | dev | smoke · cn | — |
| `runtime_chainsync_nonmonotonic_slot` | Serve a ChainSync header with a non-monotonic slot to test rejection. | dev | smoke · cn | — |
| `runtime_chainsync_parent_discontinuity` | Serve a ChainSync header with a parent-hash discontinuity to test rejection. | dev | smoke · cn | — |
| `runtime_chainsync_responder_fork_switch` | Drive a ChainSync responder fork-switch (rollback then forward) and observe follower behaviour. | dev | full · cn | — |


### Client-driven load (multi-peer / burst)

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_client_blockfetch_burst` | Drive a burst of BlockFetch requests from a client to stress the responder. | dev | full · cn | — |
| `runtime_client_blockfetch_multi_peer` | Drive BlockFetch from multiple simultaneous client peers. | dev | full · cn | — |
| `runtime_client_chainsync_burst` | Drive a burst of ChainSync requests from a client. | dev | full · cn | — |
| `runtime_client_chainsync_multi_peer` | Drive ChainSync from multiple simultaneous client peers. | dev | full · cn | — |


### Copied-state / restart recovery profiles

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_profile_copied_state_chainsync_divergence` | Start from copied state and observe ChainSync-specific divergence. | dev | full · cn | — |
| `runtime_profile_copied_state_divergence` | Start a node from copied state and observe general chain divergence. | dev | full · cn | — |
| `runtime_profile_copied_state_postremediation_blockfetch` | Check BlockFetch behaviour after remediating a copied-state node. | dev | full · cn | — |
| `runtime_profile_copied_state_recovery` | Verify recovery of a node started from copied state. | dev | full · cn | — |
| `runtime_profile_restart_postrecovery_blockfetch` | Check BlockFetch behaviour after a restart-recovery. | dev | full · cn | — |
| `runtime_profile_restart_recovery` | Restart a node and verify recovery (profile flow). | dev | full · cn | — |


### Epoch / era / hard-fork control

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_force_epoch_boundary` | Force the chain to an epoch-boundary slot to exercise the transition. | dev | smoke · cn | — |
| `runtime_force_hf_boundary` | Force the chain to a hard-fork boundary slot to exercise the transition. | dev | smoke · cn | — |
| `runtime_force_rollback` | Force a rollback of a chosen depth to test recovery. | dev | smoke · cn | — |
| `runtime_genesis_mode_simulate` | Force a node into Genesis-mode sync and watch for peer-set capture. | dev | smoke · cn | — |
| `runtime_recompute_leadership_schedule` | Recompute the leadership schedule and check determinism. | dev | smoke · cn | — |
| `runtime_simulate_era_transition` | Simulate an era transition over a slot window. | dev | smoke · cn | — |
| `runtime_simulate_peer_set_capture` | Simulate a peer-set capture / eclipse attempt. | dev | smoke · cn | — |
| `runtime_simulate_stake_snapshot_update` | Simulate a stake-snapshot rollover at an epoch boundary. | dev | smoke · cn | — |
| `runtime_trigger_rupd_pulse` | Trigger a reward-update (RUPD) pulse to exercise reward accounting. | dev | smoke · cn | — |


### Forensics / evidence bundle

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_bundle_attestation` | Produce a signed attestation for a result bundle. | dev·lib | smoke · cn | — |
| `runtime_bundle_chain` | Build/append a chained (hash-linked) evidence bundle with a stated reason. | dev | full · cn | — |
| `runtime_bundle_chain_verify` | Verify the integrity of a bundle chain for a target run. | lib | smoke · cn | — |
| `runtime_bundle_dedupe` | Deduplicate bundle entries for a target run. | dev | full · cn | — |
| `runtime_bundle_diff` | Diff two runs' bundles over specified relative paths. | lib·sin·dev | full · cn | — |
| `runtime_bundle_export` | Export a run's bundle (optionally signed). | dev | full · cn | — |
| `runtime_bundle_export_sarif` | Export a run's findings as a Static Analysis Results Interchange Format (SARIF) v2.1.0 report. | lib·sin·dev | smoke · cn | — |
| `runtime_bundle_promote` | Promote a run's bundle to a higher tier with a stated reason. | dev | full · cn | — |
| `runtime_bundle_sign` | Cryptographically sign a run's bundle. | dev | full · cn | — |
| `runtime_bundle_summary_compose` | Compose a combined summary across multiple bundles. | lib | smoke · cn | — |
| `runtime_bundle_timeline` | Build a chronological timeline across bundles, with optional filters. | lib | smoke · cn | — |
| `runtime_bundle_triage` | Triage a run's bundle, recording a reason and actor. | dev | full · cn | — |
| `runtime_forensic_snapshot` | Package selected run artifacts into a forensic snapshot archive. | lib | smoke · cn | — |


### Generated-node fault checks

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_generated_node_freeze_check` | Verify a blocked node freezes while healthy peers keep progressing. | dev | full · cn | — |
| `runtime_generated_node_port_drop_check` | Verify the effect of dropping a node's port while healthy peers continue. | dev | full · cn | — |
| `runtime_generated_node_recovery_check` | Verify a recovered node reaches a required phase alongside healthy peers. | dev | full · cn | — |


### Generic execution

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `load_shell_command` | Run an arbitrary host shell command as a load/setup step and assert its exit code. | lib·sin·dev | full · cn | — |


### Network / resource / protocol faults

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_bandwidth_throttle` | Throttle a node's bandwidth to probe sync behaviour under a slow link. | dev | smoke · cn | — |
| `runtime_blocking_work_starvation` | Inject blocking work to probe runtime-liveness starvation bounds. | dev | smoke · cn | — |
| `runtime_bootstrap_topology_concentration` | Probe bootstrap-topology concentration vs the honest-diversity floor. | dev | smoke · cn | — |
| `runtime_chain_switch_inject` | Inject a chain switch and observe honest-node convergence to the new tip. | dev | smoke · cn | — |
| `runtime_duplex_promotion_pressure` | Apply duplex-promotion pressure to test the hard slot limit. | dev | smoke · cn | — |
| `runtime_handshake_version_negotiation_pressure` | Pressure handshake version negotiation to probe downgrade handling. | dev | smoke · cn | — |
| `runtime_inject_hot_warm_churn` | Inject hot/warm peer churn to probe governor churn bounds. | dev | smoke · cn | — |
| `runtime_keepalive_failure_cascade` | Force a cascade of KeepAlive failures to probe the disconnect/recovery budget. | dev | smoke · cn | — |
| `runtime_local_query_stress` | Stress LocalStateQuery to probe query amplification / central-processing-unit (CPU) ceiling. | dev | smoke · cn | — |
| `runtime_local_submit_stress` | Stress LocalTxSubmission to probe availability and queue limits. | dev | smoke · cn | — |
| `runtime_localtxmonitor_fault` | Inject a LocalTxMonitor fault against the mempool-inspection protocol. | dev | smoke · cn | — |
| `runtime_malformed_input_differential` | Feed malformed input to Amaru and cardano-node and compare handling (differential). | dev | smoke · cn | — |
| `runtime_mempool_relay_pressure` | Apply mempool-relay pressure to probe budget and memory ceiling. | dev | smoke · cn | — |
| `runtime_mux_ingress_overrun` | Overrun a mux bearer's ingress to test per-bearer scoping. | dev | smoke · cn | — |
| `runtime_network_impairment` | Impair the link between two nodes (latency/jitter/loss/partition). | dev | full · cn | — |
| `runtime_overlay_slot_forging` | Attempt overlay-slot forging to test rejection of the forged block. | dev | smoke · cn | — |
| `runtime_partition_rejoin` | Partition then rejoin nodes to test convergence/recovery. | dev | full · cn | — |
| `runtime_peersharing_fault` | Inject a PeerSharing fault (adversarial address exchange). | dev | smoke · cn | — |
| `runtime_perturb_ledger_peer_weights` | Perturb ledger-peer stake weights to probe peer-selection stability. | dev | smoke · cn | — |
| `runtime_slow_loris_chainsync` | Slow-loris (byte-drip) a ChainSync connection to hold resources. | dev | smoke · cn | — |
| `runtime_substitute_big_ledger_peers` | Substitute the big-ledger-peer set to probe Sybil/quorum resistance. | dev | smoke · cn | — |
| `runtime_time_skew` | Skew a node's clock (libfaketime) for a duration to test time sensitivity. | dev | smoke · cn | — |
| `runtime_tracer_capture` | Capture structured tracer output (cardano-tracer FileMode JSON / Prometheus) from the observed nodes over a window as evidence. | dev | full · cn | — |
| `runtime_validation_path_differential` | Compare validation-path behaviour across implementations (differential). | dev | smoke · cn | — |


### Node lifecycle

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_kill_node` | Kill a node process (ungraceful) to test peer/recovery behaviour. | dev | smoke · cn | — |
| `runtime_restart_node` | Restart a node and verify it recovers to a healthy synced state. | dev | smoke · cn | — |


### Observability / capture / baselines

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_connection_state` | Snapshot a node's network connection state. | dev | full · cn | — |
| `runtime_container_runtime_inspect` | Inspect the container runtime/state of the substrate (hardening evidence). | dev | smoke · cn+amaru | — |
| `runtime_haskell_gc_capture` | Capture Haskell garbage-collection / run-time-system (GC/RTS) stats from a cardano-node target. | dev | full · cn | — |
| `runtime_live_implementation_baseline` | Capture a live-implementation baseline for a scenario across the runtime. | dev | full · cn | — |
| `runtime_multi_node_observation` | Observe multiple nodes over a window, running a set of observation primitives. | dev·lib | full · cn+amaru | — |
| `runtime_observability_log_baseline` | Capture a baseline of node logging output. | dev | full · cn | — |
| `runtime_observability_trace_settings_baseline` | Capture a baseline of node tracing/trace-settings config. | dev | full · cn | — |
| `runtime_pcap_capture` | Capture network packets — packet capture (pcap) — during a workload. | dev | full · cn | — |
| `runtime_resource_profile` | Sample a node's resource usage over time. | dev | full · cn | — |
| `runtime_syscall_trace` | Trace syscalls of a target node during a workload. | dev | full · cn | — |


### Preview-network upstream fault & parity

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_preview_parity_baseline` | Baseline parity between Amaru and cardano-node roots on the preview network. | dev | full · cn | — |
| `runtime_preview_upstream_delay` | Inject upstream delay/jitter on preview, then recover, checking parity. | dev | full · cn | — |
| `runtime_preview_upstream_drop` | Drop upstream preview traffic for a window, then recover. | dev | full · cn | — |
| `runtime_preview_upstream_loss` | Apply packet loss to upstream preview traffic, then recover. | dev | full · cn | — |
| `runtime_preview_upstream_reset` | Reset the upstream preview connection, then recover. | dev | full · cn | — |


### Setup / extraction utilities

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_cardano_lsq_extract` | Extract ledger state via a Local State Query over a node socket. | sin·dev | full · cn | — |
| `runtime_credential_ceremony` | Run a credential/key ceremony to generate pool credentials for a testnet. | lib·dev | smoke · cn | — |


### State snapshot / checkpoint

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_snapshot_capture` | Capture a node's on-disk state snapshot. | dev | smoke · cn | — |
| `runtime_snapshot_corrupt` | Corrupt a captured snapshot (zero/truncate/flip) to test detection. | dev | smoke · cn | — |
| `runtime_snapshot_restore` | Restore a snapshot and recover node health. | dev | smoke · cn | — |
| `runtime_substrate_checkpoint` | Take a consistent checkpoint of the whole substrate. | dev | smoke · cn | — |
| `runtime_substrate_resume` | Resume the substrate from a checkpoint. | dev | smoke · cn | — |


### Targeted probes

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_bootstrap_assumption_probe` | Probe that bootstrap assumptions stay explicit and downgrade-free. | dev | smoke · cn | — |
| `runtime_disk_full_probe` | Fill disk toward a limit to probe disk-full handling. | dev | smoke · cn | — |
| `runtime_mempool_failure_probe` | Probe that a mempool failure stays contained. | dev | smoke · cn | — |
| `runtime_panic_path_probe` | Feed a crash-candidate input and check the node stays on a contained non-panic path. | dev | smoke · cn | — |
| `runtime_parser_bounds_probe` | Probe that parser bounds are enforced before unbounded work. | dev | smoke · cn | — |
| `runtime_plutus_phase2_differential_observation` | Observe phase-2 Plutus admission on both implementations for equivalence. | dev | smoke · cn | — |
| `runtime_plutus_phase2_submit_probe` | Submit a Plutus phase-2 tx with is-valid / ex-units overrides to probe validation. | dev | smoke · cn | — |
| `runtime_praos_header_assertion_probe` | Serve an invalid Praos header and check it is rejected. | dev | smoke · cn | — |
| `runtime_runtime_starvation_probe` | Probe runtime-liveness starvation under blocking work. | dev | smoke · cn | — |


### TxSubmission pressure

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_txsubmission_batch_pressure` | Push an oversize TxSubmission body batch past the negotiated limit. | dev | smoke · cn | — |
| `runtime_txsubmission_unexpected_body` | Send an unrequested TxSubmission body to test rejection. | dev | smoke · cn | — |
| `runtime_txsubmission_window_pressure` | Push the TxSubmission txid inflight window past its negotiated bound. | dev | smoke · cn | — |


## Assertion primitives — oracles (75)

What a scenario *proves*. Each is evaluated after load; the **pass condition** is the expected outcome. Thresholds shown are the tunable params.


### Byzantine / fault containment

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `byzantine_cardano_node_recorded_clean` | PASS iff the byzantine cardano-node fault run records >= min_completed clean events. | dev | smoke · cn+amaru | — |
| `byzantine_isolation_observed` | PASS iff complete isolation is observed between honest and byzantine nodes. | dev·lib | smoke · cn | — |
| `container_runtime_hardening_observed` | PASS iff captured `docker inspect` artifacts prove hardening on every required container. | dev·lib | smoke · cn+amaru | — |
| `panic_path_contained` | PASS iff a crash-triggering input stays on a contained non-panic path and the node stays up. | dev·lib | smoke · cn | — |
| `quorum_holds_despite_byzantine` | PASS iff a real byzantine event occurs and honest quorum tip-convergence holds throughout observation. | dev·lib | smoke · cn+amaru | — |
| `runtime_starvation_bounded` | PASS iff blocking work preserves runtime liveness without starvation. | dev·lib | smoke · cn | — |


### Consensus / ledger / era

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `big_ledger_peer_quorum_intact` | PASS iff the observed big-ledger-peer subset still contains >= the required expected top peers. | dev·lib | smoke · cn | — |
| `bootstrap_assumptions_safe` | PASS iff bootstrap assumptions remain explicit and downgrade-free. | dev·lib | smoke · cn | — |
| `chain_select_consistent` | Assert that every observed node agrees on the selected chain tip — a single-implementation Common-Prefix consistency oracle. | dev·lib | full · cn | — |
| `chain_select_differential` | Cross-implementation Common-Prefix oracle: assert the reference node group (cardano-node) and the target group (Amaru) select the same canonical chain tip. A disagreement is a consensus divergence. | dev·lib | full · cn+amaru | — |
| `chain_switch_consistent` | PASS iff all observed honest nodes reach the injected chain-switch tip. | dev·lib | smoke · cn | — |
| `epoch_boundary_timing_within_bounds` | PASS iff the epoch boundary occurs within the configured slot window. | dev·lib | smoke · cn | — |
| `hf_boundary_rule_consistent` | PASS iff all observed nodes apply one protocol version at the hard-fork boundary. | dev·lib | smoke · cn | — |
| `k_bound_rollback_recovered` | PASS iff a within-k rollback recovers consistently, with observed slot transitions. | dev·lib | full · cn | — |
| `leadership_schedule_recomputes_clean` | PASS iff leadership-schedule recomputation matches deterministically. | dev·lib | smoke · cn | — |
| `ledger_peer_stake_weight_preserved` | PASS iff observed ledger-peer stake weighting stays within the allowed delta. | dev·lib | smoke · cn | — |
| `mode_switch_genesis_observed` | PASS iff the genesis-mode transition reaches caught-up mode without peer-set capture. | dev·lib | smoke · cn | — |
| `overlay_slot_forging_rejected` | PASS iff an overlay-slot forging attempt is rejected and the forged block is not adopted. | dev·lib | smoke · cn | — |
| `praos_header_assertion_rejected` | PASS iff an invalid Praos header is rejected at the assertion boundary. | dev·lib | smoke · cn | — |
| `reward_calculation_boundary_invariant` | PASS iff reward-calculation invariants hold across the epoch boundary. | dev·lib | smoke · cn | — |
| `stake_snapshot_freeze_consistent` | PASS iff the stake snapshot remains byte-stable across the freeze window. | dev·lib | smoke · cn | — |
| `tip_convergence_clean` | PASS iff all observed nodes converge to one tip group within tolerance before the deadline. | dev·lib | smoke · cn | — |
| `topology_bootstrap_diversity_preserved` | PASS iff bootstrap topology preserves the minimum honest-peer diversity floor. | dev·lib | smoke · cn | — |
| `transition_window_validated` | PASS iff pre/post-hard-fork (HF) submissions validate under the matching rule windows. | dev·lib | smoke · cn | — |


### Forensics / snapshot / bundle

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `bundle_attestation_signature_valid` | PASS iff a verified bundle attestation (valid signature) is present. | dev·lib | smoke · cn | — |
| `bundle_chain_verify_clean` | PASS iff the bundle hash-chain verifies as all-linked. | lib | smoke · cn | — |
| `bundle_diff_completed_clean` | PASS iff the bundle diff emits a non-empty result on an ok run. | lib·sin·dev | full · cn | — |
| `bundle_sarif_export_valid` | PASS iff the SARIF export is schema-valid. | lib·sin·dev | smoke · cn | — |
| `bundle_summary_compose_completed_clean` | PASS iff the composed summary bundle is non-empty (>= min_completed). | lib | smoke · cn | — |
| `bundle_timeline_emitted_clean` | PASS iff the bundle timeline emits >= 1 signature record. | lib | smoke · cn | — |
| `credential_ceremony_recorded_clean` | PASS iff the credential ceremony records >= min_completed clean events and >= min_keys_generated keys. | lib·dev | smoke · cn | — |
| `forensic_snapshot_emitted_clean` | PASS iff the forensic snapshot bundle is non-empty (>= min_completed). | lib | smoke · cn | — |
| `snapshot_captured_clean` | PASS iff snapshot capture emits a non-empty snapshot and the node restarts cleanly. | dev | smoke · cn | — |
| `snapshot_corruption_detected` | PASS iff snapshot corruption yields a changed snapshot digest (corruption is detected). | dev | smoke · cn | — |
| `snapshot_restore_succeeded` | PASS iff snapshot restore restarts the target node and recovers health. | dev | smoke · cn | — |
| `substrate_checkpoint_recorded_clean` | PASS iff the substrate checkpoint is non-empty and the substrate restarts cleanly. | dev | smoke · cn | — |
| `substrate_resume_succeeded` | PASS iff resume restores the checkpoint and recovers substrate health. | dev | smoke · cn | — |


### Mini-protocol & local inter-process-communication (IPC) behaviour

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `blockfetch_continuity_failure_rejected` | PASS iff a BlockFetch continuity failure is rejected before downstream state advances. | dev·lib | smoke · cn | — |
| `blockfetch_invalid_block_rejected` | PASS iff an invalid BlockFetch block payload is rejected. | dev·lib | smoke · cn | — |
| `blockfetch_invalid_range_rejected` | PASS iff an invalid BlockFetch range is rejected without serving any blocks. | dev·lib | smoke · cn | — |
| `blockfetch_range_pressure_bounded` | PASS iff BlockFetch range pressure stays within resource bounds and >= min blocks/range-requests are observed. | dev·lib | smoke · cn | — |
| `blockfetch_response_range_strict` | PASS iff a mismatched BlockFetch response range is strictly rejected. | dev·lib | smoke · cn | — |
| `chainsync_height_monotonicity_enforced` | PASS iff a non-incrementing ChainSync height is rejected cleanly. | dev·lib | smoke · cn | — |
| `chainsync_parent_discontinuity_rejected` | PASS iff a parent-hash discontinuity is rejected before the candidate chain advances. | dev·lib | smoke · cn | — |
| `chainsync_responder_rollback_then_forward_clean` | PASS iff a producer fork-switch yields clean rollback-then-forward follower behaviour, meeting minimum observed counts. | dev·lib | smoke · cn | — |
| `chainsync_slot_monotonicity_enforced` | PASS iff a non-monotonic ChainSync slot is rejected cleanly. | dev·lib | smoke · cn | — |
| `duplex_promotion_slot_limit_enforced` | PASS iff duplex promotion pressure respects the configured hard slot limit. | dev·lib | smoke · cn | — |
| `keepalive_failure_budget_bounded` | PASS iff keepalive failures stay within the configured retry budget. | dev·lib | smoke · cn | — |
| `local_query_amplification_bounded` | PASS iff local-query amplification stays below the configured CPU ceiling. | dev·lib | smoke · cn | — |
| `local_submit_availability_preserved` | PASS iff local-submit stress preserves node availability and queue limits. | dev·lib | smoke · cn | — |
| `mempool_failure_contained` | PASS iff a mempool failure stays contained without loss of any node. | dev·lib | smoke · cn | — |
| `mempool_relay_pressure_bounded` | PASS iff mempool-relay pressure stays inside the configured budget and peak memory <= ceiling. | dev·lib | smoke · cn | — |
| `mux_ingress_overrun_scoped` | PASS iff a mux ingress overrun is scoped to the offending bearer only. | dev·lib | smoke · cn | — |
| `peer_connectivity_observed` | PASS iff all expected honest-honest peer edges are observed within the timeout. | dev·lib | smoke · cn+amaru | — |
| `peer_eviction_within_seconds` | PASS iff honest nodes evict byzantine peers within the allowed time window. | dev·lib | smoke · cn | — |
| `reconnection_clean` | PASS iff the reconnected node rejoins and matches the honest-quorum tip with real reconnect telemetry. | dev·lib | smoke · cn | — |
| `txsubmission_batch_enforced` | PASS iff the negotiated tx-body batch limit rejects an oversize batch cleanly. | dev·lib | smoke · cn | — |
| `txsubmission_unexpected_body_rejected` | PASS iff an unexpected TxSubmission body is rejected with a stated reason. | dev·lib | smoke · cn | — |
| `txsubmission_window_enforced` | PASS iff the negotiated txid window rejects overflow cleanly after enough txids/messages are observed. | dev·lib | smoke · cn | — |


### Node health / quorum

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `all_nodes_responsive` | PASS iff every observed node is responsive. | dev·lib | full · cn+amaru | — |
| `all_nodes_started_clean` | PASS iff the compose report has >= min_node_count nodes and >= min_completed clean start events. | dev | smoke · cn+amaru | — |
| `honest_peer_set_uncompromised` | PASS iff each honest node retains >= minimum_honest_peers honest peers without capture. | dev·lib | smoke · cn | — |
| `honest_quorum_preserved` | PASS iff the honest-node quorum fraction >= minimum_fraction on an ok run. | dev·lib | smoke · cn | — |
| `hot_warm_churn_within_bounds` | PASS iff observed hot/warm peer churn <= maximum_events_per_hour. | dev·lib | smoke · cn | — |
| `load_events_are_ok` | PASS iff >= min_event_count outcome-bearing load events are present and none are non-ok. | lib·sin·dev | full · cn | — |
| `substrate_quorum_observed` | PASS iff a quorum (>= minimum_fraction) of nodes agrees on one real, non-zero tip group. | dev·lib | smoke · cn | — |


### Parser / CBOR / input correctness

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `malformed_input_parity_preserved` | PASS iff malformed-input handling matches the reference implementation (no divergence). | dev·lib | smoke · cn | — |
| `parse_succeeds_or_clean_error` | PASS iff no parse outcome is a crash (every input is `ok` or `clean_error`) over >= min_outcomes_count inputs. | lib | full · cn+amaru | ✓ |
| `parser_bounds_enforced` | PASS iff parser/deserialization bounds are enforced before any unbounded work. | dev·lib | smoke · cn | — |
| `roundtrip_equals_original` | PASS iff every `ok` parse re-encodes to bytes identical to the input, over >= min_inputs_parsed inputs. | lib | full · cn+amaru | ✓ |
| `validation_path_parity_preserved` | PASS iff the validation path preserves reference parity with zero mismatched steps. | dev·lib | smoke · cn | — |


### Plutus phase-2 validation

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `plutus_phase2_differential_equivalent` | PASS iff Amaru and cardano-node agree on phase-2 Plutus admission behaviour. | dev·lib | smoke · cn | — |
| `plutus_phase2_donotintervene_retry_clean` | PASS iff DoNotIntervene retry behaviour stays within the configured budget. | dev·lib | smoke · cn | — |
| `plutus_phase2_exunits_overrun_rejected` | PASS iff a phase-2 ExUnits overrun is rejected on mempool admission. | dev·lib | smoke · cn | — |
| `plutus_phase2_isvalid_mismatch_rejected` | PASS iff a phase-2 IsValid mismatch is rejected with ValidationTagMismatch. | dev·lib | smoke · cn | — |


## Setup primitives (4)

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_attach_topology` | Attach to an already-running external topology (e.g. the upstream cardano_amaru mesh) as the runtime substrate, instead of provisioning a fresh one. | dev | full · cn | — |
| `runtime_compose_substrate` | Bring up the docker-compose substrate and wait for health. | dev | full · cn+amaru | — |
| `runtime_install_version` | Install/pin a specific node/implementation version into the runtime. | dev | full · cn+amaru | — |
| `runtime_substrate_tip_warmup` | Warm a freshly-composed substrate until nodes reach a minimum tip/slot. | dev | full · cn+amaru | — |


## Probe primitives (1)

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `parser_exit_status` | Per-input probe: record each iteration's outcome to probes/parser_exit_status.ndjson (newline-delimited JavaScript Object Notation). | lib | full · cn+amaru | ✓ |


## Fault primitives (5)

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `fault_local_port_delay` | Inject bounded loopback latency scoped to one local listener port (host tc netem). | dev | full · cn | — |
| `fault_local_port_drop` | Drop loopback traffic to one target port for the load duration (host iptables). | dev | full · cn | — |
| `fault_node_freeze` | Freeze (SIGSTOP) a target node for a window, then resume. | dev | full · cn | — |
| `runtime_byzantine_cardano_node` | Run a byzantine cardano-node proxy that mutates/downgrades protocol traffic. | dev | smoke · cn+amaru | — |
| `runtime_network_partition` | Partition a node from the runtime network for a window (disconnect it from the docker network), then reconnect and settle — a runtime fault that exercises fork and recovery behaviour. | dev | full · cn | — |


## Teardown primitives (1)

| primitive | purpose / pass-condition | runtimes | verified | Antithesis |
|---|---|---|---|---|
| `runtime_teardown_substrate` | Tear down the substrate and record the outcome (runs regardless of pass/fail). | dev | full · cn+amaru | — |
