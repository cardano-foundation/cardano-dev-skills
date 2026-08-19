# Amaru crashes on restart when its chain store is ahead of its ledger store (`RollbackPointInFuture` → "Consensus died")

**Component:** `amaru` ledger / consensus — restart recovery across the chain-store ↔ ledger-store split
(`crates/amaru-ledger/src/state.rs:939-966` `rollback_to`; error `BackwardError::RollbackPointInFuture`
at `state.rs:1291`; fatal exit at `crates/amaru/src/bin/amaru/cmd/node/run.rs:436` "Consensus died").
**Type:** Deterministic node crash on restart — liveness / robustness (a running node that is restarted
crash-loops until an operator manually intervenes). **Not** a consensus-safety issue.
**Status:** **Confirmed** — reproduced live on the `cardano_amaru_dwarf` mixed devnet; root cause read
from Amaru source. **Still present in `v10.11.20260807`** (the error path and the raising condition are
unchanged; 807 adds only a *manual* remediation command — see below).
**Found by:** DWARF mixed-net operations — an honest Amaru relay, synced to the live cardano chain, was
restarted (`docker restart`) and died on startup instead of resuming.
**Date:** 2026-08-11
**Version observed:** Amaru `10.11.0` (lambdasistemi `pr-60` bootstrap image), testnet_42, k=5. Source
verified against `v10.11.20260807`.

---

## Summary

An Amaru relay that is **synced and running** dies on the next **restart** with:

```
WARN  amaru_consensus::stages::validate_block: failed to validate the new block
      tip=1244.14708606c6ca56b93ba5ec71bc6ba7f10ba37798fad13d75817b12a822e9477a
      err=BlockValidationError: attempted roll back in the future:
        rollback point = 8961.9c4b5fe438b8abd923572da94894e5f71dca84b8439e162610a644573262f9d3,
        volatile tip   = 8870.581b9ed8c305a44a2624c06f9bb3ad7b421f638af4b1673edf44ba5208fe5612,
        immutable_tip  = 8870.581b9ed8c305a44a2624c06f9bb3ad7b421f638af4b1673edf44ba5208fe5612
ERROR amaru::cmd::node::run: Consensus died, this should not happen! Please report this incl. preceding logs to the Amaru team.
```

The node then restarts (`restart: always`), replays to the same point, and dies again — a **crash loop**.
The only recovery observed was to **wipe the Amaru state and re-bootstrap** (or, per 807, run the new
manual `amaru node rollback`).

## Root cause (from source)

Amaru keeps the **chain store** (headers/blocks) and the **ledger store** (applied state, with an
`immutable_tip` and a bounded `volatile` window) as **separate** databases (the four-store split noted in
the state-lifecycle differential, `dwarf/docs/…state-lifecycle…`). On an **unclean stop**, the chain store
can persist a tip that is **ahead of** the ledger store's persisted tip.

On restart, chain-sync tries to reconcile and instructs the ledger to move to the chain tip. In
`crates/amaru-ledger/src/state.rs` `rollback_to`:

```rust
let volatile_tip = self.volatile_tip().map(|t| t.point()).unwrap_or(immutable_tip);
...
} else if *to > volatile_tip {
    Err(BackwardError::in_the_future(*to, volatile_tip, immutable_tip))   // <-- here
}
```

Because the requested point (`8961`) is **greater** than the ledger's `volatile_tip` (`8870`), the ledger
raises `RollbackPointInFuture`. The enum's own doc comment says these *"should be impossible if chain-sync
messages … are all passed to the ledger"* — i.e. the invariant assumes chain store and ledger never
diverge, which an unclean shutdown violates. The error propagates, the consensus stage terminates, and
`run.rs` reports **"Consensus died"** and exits. There is **no reconciliation / truncate-to-consistent path**
for chain-store-ahead-of-ledger on this code path.

## Still present in `v10.11.20260807` — manual-only remediation

The raising condition (`state.rs` `rollback_to`) and the fatal `run.rs` path are **unchanged** in
`v10.11.20260807`. What 807 **adds** is a *manual operator* tool (commit `a6fd4da06`, 2026-08-05):

```
amaru node rollback   # "Roll the chain store back to the ledger's immutable tip. Does not modify the ledger database."
```

That command realigns exactly the divergence behind this crash (chain store ahead of ledger) — strong
evidence the failure mode is **known** — but it must be run **by hand** after the node has already
crash-looped. **The node still does not self-heal on restart.**

**Tested — and the manual remediation does not help stores from the current client bootstrap tooling.**
Running `amaru node rollback --network testnet_42 --immutable-tip` (807 binary) against the divergent
store fails the same way `amaru node run` does:

```
ERROR amaru::cli: error description=Incompatible chain DB versions: found 3, expected 5.
      Pass `--migrate-chain-db` (or set AMARU_MIGRATE_CHAIN_DB=true) ...
```

The `rollback` subcommand **requires a chain-DB v5 store and does not honor `AMARU_MIGRATE_CHAIN_DB`**.
Stores bootstrapped by the client's `lambdasistemi`/pr-60 tooling are chain-DB **v3**, and 807's `run`
migration to v5 also fails on them (opcert seq numbers incomplete). So on these transitional stores
**neither `run` nor `rollback` works** — the only recovery is a **full re-bootstrap**. `amaru node
rollback` recovers only **807-native (v5) deployments**.

## Contrast with cardano-node

cardano-node keeps a **self-contained ledger state** and, on startup, **replays from the newest snapshot,
falling back to genesis**, truncating to a consistent point — so it is operational immediately after any
restart with no manual step. Amaru's split stores + assert-on-inconsistency is the differential (same
family as the state-lifecycle finding).

## Live reproduction

1. Stand up the `cardano_amaru_dwarf` mixed devnet (3 Haskell producers + Amaru relays), let an Amaru
   relay sync the honest cardano chain to the live tip.
2. `docker restart amaru-relay-1` (or any unclean stop while the volatile window is non-empty).
3. On restart the node emits the `attempted roll back in the future` / `Consensus died` pair and
   crash-loops (observed `restarts` climbing, `9` within ~1 min).
4. Recovery: wipe `a1-state` + re-bootstrap (or `amaru node rollback`).

Observed tips at the crash: chain/peer rollback point `8961`, ledger `volatile_tip = immutable_tip = 8870`
— the ledger persisted ~91 slots behind the chain store.

## Related observation (separate issue, same session)

The same relay also exhibited a **live-sync stall** — now root-caused separately: after catching up it
stops adopting blocks (CPU ~0%, no panic) following a peer `Connection reset by peer (os error 104)`; the
consumer re-connects but does not resume block delivery. Written up in
`finding-amaru-consumer-sync-stall.md` (likely upstream #736). Distinct from this restart crash, but the
two compound: a stalled node that is then restarted hits the `RollbackPointInFuture` crash.

## Suggested remediation

On startup, if the chain store is **ahead of** the ledger's immutable/volatile tip, **automatically** roll
the chain store back to the ledger's immutable tip (what `amaru node rollback` does by hand) and resume —
rather than surfacing `RollbackPointInFuture` as a fatal "Consensus died". A restart should never require
manual intervention or a full re-bootstrap.

## Open

1. Root-cause the co-occurring **live-sync hang** at slot 8961 / epoch 70→71 (silent stall, no panic).
2. Confirm whether `amaru node rollback` fully recovers a crash-looped node in place (not yet exercised).
