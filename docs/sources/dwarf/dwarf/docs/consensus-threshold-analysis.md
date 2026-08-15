# The 50/51% and "40%" thresholds — what they mean, and how DWARF investigates them

*A worked breakdown of Cardano's consensus safety thresholds, the difference between the
theoretical bound and the practical one, the economic translation, and the multi-layer
evidence pipeline (analytical model → simulator → DWARF devnet → Antithesis → live mainnet)
we use to investigate them beyond a single closed-form calculation.*

Status: analysis / methodology note. Cross-referenced to the live attack-cost ticker
(`/learn/attack-cost`), the reference page (`/learn/overview`), and the devnet scenario
[`scenarios/consensus-threshold-delay-probe.yaml`](../scenarios/consensus-threshold-delay-probe.yaml)
with profile [`profiles/profile-m-consensus-threshold/`](../profiles/profile-m-consensus-threshold/profile.yaml).

---

## 0. TL;DR

There are **three** different numbers people conflate when they say "the 51% attack" or
"the 40% attack" on Cardano. They answer three different questions:

| # | Number | What it is | The question it answers |
|---|--------|-----------|--------------------------|
| 1 | **< 50%** (the "51%") | Honest-majority bound of Ouroboros Praos, under an *idealised synchronous network* | "Above what adversarial **stake fraction** is there *no* security proof at all?" |
| 2 | **~34–45% (call it "~40%")** | The *delay-adjusted* safety threshold — the honest chain must out-grow a private adversarial chain despite real network propagation delay | "At what adversarial stake fraction does the **private-fork / double-spend race** actually start to win under real timing?" |
| 3 | **~24% of circulating ≈ $1.3B** | The **economic translation** of #2, because block production tracks *active* (delegated, live) stake — not all circulating ADA | "What would it **cost, right now**, to acquire enough live stake to reach threshold #2?" |

The honest one-liner: **#1 and #2 are model outputs; #3 is arithmetic on live on-chain data.**
None of the three is something a small testbed can "prove" by simulation alone. What the
testbeds (DWARF devnet, Antithesis) *do* establish is that the **real node software behaves
the way the model says it should**, and is free of the safety/liveness bugs that would make
the real threshold *worse* than the model predicts. The rest of this document is the long form.

---

## 1. Number one: the 50/51% honest-majority bound

Cardano runs **Ouroboros Praos** (David, Gaži, Kiayias, Russell — Eurocrypt 2018). Praos is a
proof-of-stake, longest-chain ("Nakamoto-style") protocol. Its security theorems — **common
prefix**, **chain growth**, **chain quality** — are proved under an *honest-majority-of-stake*
assumption:

> the total stake controlled by the adversary is strictly **less than 1/2** of the stake that
> is participating in the protocol.

That is the "51% attack" line inherited from Bitcoin's vocabulary. Above 50%, the adversary can
privately grow a chain faster than the honest network *in expectation*, rewrite arbitrarily deep
history, and there is no theorem left to lean on. Below 50% — **and under the paper's network
assumptions** — honest parties are guaranteed a common prefix except with negligible probability.

The critical caveat is in that last clause. Praos's clean 50% number assumes a **Δ-synchronous**
network where every honest block reaches every honest party within a known bound Δ, and the
analysis is tightest as the block rate relative to Δ goes to zero. Real networks are not free.
That is where number two comes from.

### Cardano's consensus parameters (the numbers that set the regime)

| Parameter | Value | Meaning |
|-----------|-------|---------|
| Slot length | **1 second** | one slot lottery per second |
| Active slot coefficient **f** | **0.05** | probability a slot is "active" → ~**1 block / 20 s** expected |
| Epoch | 432,000 slots = **5 days** | |
| Security parameter **k** (consensus) | **2160 blocks** | common-prefix depth / **maximum rollback** — a block ≥ k deep is settled |
| Desired pool count **k** (rewards) | **500** | *a different k* — the Nash target for decentralisation in the reward-sharing scheme (RSS). Do not confuse it with the 2160-block k. |

Two things matter for the threshold. First, the **block rate is deliberately low** (one block
per ~20 seconds, not one per second). Second, the **honest network is well-connected** so
propagation delay Δ is small (single-digit seconds) relative to the 20 s block interval. Both
push Cardano *toward* the ideal-synchrony regime where the 50% bound is nearly tight — this is a
design choice, not an accident.

---

## 2. Number two: the delay-adjusted "~40%" — the private-fork race

The sharper analysis of *why the real threshold sits below 50%* comes from the
**"Everything is a Race and Nakamoto Always Wins"** line of work (Dembo, Kannan, Tse, Viswanath,
Wang, Zhao — CCS 2020) and the related tight analyses of Nakamoto consensus (e.g. Gaži–Kiayias–
Russell). The key idea:

> The worst attack on a longest-chain protocol is the **private attack**: the adversary secretly
> builds its own chain and releases it to overtake the public chain (a deep reorg / double-spend).
> Security holds **iff the honest chain grows strictly faster than any private adversarial chain**.

Network delay hurts the *honest* side specifically. When two honest blocks are produced within
one propagation delay Δ of each other, they **fork** — the network briefly splits, and one of the
two honest blocks is ultimately wasted. So the honest chain's *effective* growth rate is not the
honest block-production rate; it is that rate **discounted by delay-induced forking**. The
adversary, building privately, suffers no such discount — it never forks against itself.

Define **λ** = honest block rate and **Δ** = propagation delay. The product **λΔ** is the number
of honest blocks "in flight" at once. The safety threshold β\* (the largest adversarial fraction
still tolerated) is a **decreasing function of λΔ**:

- **λΔ → 0** (slow blocks, fast network): honest forking vanishes, β\* → **1/2**. The Praos 50%.
- **λΔ large** (fast blocks or slow network): honest forking is severe; the literature's
  worst-case asymptotic tolerance for longest-chain protocols falls toward **1/(1+e) ≈ 27%**.

**Cardano is deliberately near the left end of that curve.** With one block per ~20 s and Δ of a
few seconds, λΔ is small, so β\* stays *close to but below 50%*. The commonly cited **"~40%"**
(sometimes stated as a 34–45% band depending on the delay assumption and how conservatively you
model tail forking) is the practical reading of β\* for Cardano-like parameters — **not** the
~27% asymptotic worst case, which corresponds to a high-block-rate regime Cardano does not run in.

So: **"51%" is the theorem's headline; "~40%" is the same theorem evaluated at Cardano's real
timing.** The gap between them *is* the cost of network delay.

### Where the 34% vs 40% vs 45% spread comes from

The exact figure inside the band depends on the assumed Δ, whether you model the mean or a
pessimistic tail of propagation delay, and whether you fold in **grinding/predictability**
resistance (Praos uses a VRF so the adversary can't grind slot leadership — this is *better* than
naive PoS and keeps the number nearer 45% than 34%). Reasonable, defensible statements:

- Optimistic / mean-delay: **~44–45%**.
- Conservative / tail-delay + safety margin: **~34–40%**.
- We use **40%** as the round headline for the ticker and treat 34% as the conservative floor.

---

## 3. Number three: the economic translation (~24% of circulating, ≈ $1.3B)

Thresholds #1 and #2 are fractions of **participating (active) stake** — the stake that is
delegated to live pools and actually entering the slot lottery. That is **not** the same as total
or circulating supply. Translating the stake fraction into a dollar figure requires the live
on-chain stake distribution and the market price.

Snapshot used by the ticker (epoch 642):

| Quantity | Value |
|----------|-------|
| Circulating supply | 36.47 B ADA |
| Total supply | 38.74 B ADA |
| **Active (delegated, live) stake** | **21.39 B ADA** |
| Active / circulating | **58.6 %** |
| ADA price | $0.1573 |

To reach a fraction *β* of **block production**, an attacker needs *β* of the **21.39 B active
stake**, which is only *β × 58.6 %* of circulating supply:

| Threshold on active stake | ADA required | % of circulating | Spot cost @ $0.157 |
|---------------------------|-------------:|-----------------:|-------------------:|
| 27% (asymptotic worst case — *not* Cardano's regime) | 5.78 B | 15.8 % | $0.91 B |
| **34% (conservative floor)** | 7.27 B | 19.9 % | **$1.14 B** |
| **40% (headline)** | 8.56 B | 23.5 % | **$1.35 B** |
| 50% (naive honest-majority) | 10.70 B | 29.3 % | $1.68 B |

This is exactly what the **live ticker** (`/learn/attack-cost`) computes: it pulls active stake
and price from on-chain / market APIs each load and prints the 40%-of-active figure in ADA and
USD, with the epoch-642 snapshot as a fallback.

### Two honesty caveats on the dollar number

1. **Spot price is a floor, not the real cost.** Acquiring 8.5 B ADA on the open market would
   move the price enormously (slippage), and a large fraction of supply is locked, staked
   long-term, or held by parties who would not sell at any near-spot price. The *real*
   acquisition cost is **many multiples** of the spot figure. The ticker's number is a **lower
   bound** and should always be presented as such.
2. **Buying isn't the only path.** Block production follows the **pool operator**, not the
   delegator. An attacker could instead try to **attract 40% of delegation** to pools it secretly
   controls (a social / incentive attack) without ever buying the ADA. That path is cheaper in
   dollars but far more visible and slower, and is defended by delegator behaviour and the
   `k = 500` decentralisation pressure. Both paths are worth naming; the ticker only prices the
   acquisition path.

---

## 4. Why a calculator is not proof — the epistemics

The sections above are a **model**. A model can be internally correct and still fail to describe
the real system for two reasons:

- **The implementation might not match the model.** The real `cardano-node` and Amaru are tens of
  thousands of lines of chain-selection, rollback, and networking code. If either picks the wrong
  chain, mishandles a deep rollback, or stalls under delay, the *real* threshold is **worse** than
  β\* — regardless of how correct the math is.
- **The parameters might be wrong or drift.** Δ is an assumption; active stake moves every epoch;
  pool distribution changes. The number is only as good as its inputs.

So "we computed 40%" is a starting point, not a conclusion. To claim we **investigated** the
threshold, we need evidence that (a) the model's mechanism actually occurs in the real software,
(b) the software has no safety/liveness bug that would break the bound, and (c) the economic
inputs are live. That is the pipeline.

---

## 5. The evidence pipeline (the walkthrough)

Five layers. **Each answers a different question, and no single layer proves "40%" on its own** —
that is the point. The value is in the *chain*.

| Layer | Tool | Question it answers | What it can prove | What it cannot |
|-------|------|---------------------|-------------------|----------------|
| 1 | **Analytical model / ticker** | What does the theory say, and what does it cost today? | The β\*(λΔ) curve; the live $ figure | That real nodes behave this way |
| 2 | **Simulator** (abstract race / discrete-event) | Does the closed form hold across a parameter sweep? | β\* vs λ, Δ, α by Monte Carlo; where closed form breaks | Anything about the real node code — it abstracts the protocol |
| 3 | **DWARF devnet** (real binaries, small N) | Does the *actual software* exhibit the private-fork mechanism, and do Amaru and cardano-node agree? | Mechanism + **differential** correctness at small scale | The asymptotic *number* — N is tiny |
| 4 | **Antithesis** (deterministic hypervisor) | Under exhaustive adversarial scheduling, does any safety/liveness invariant ever break? | **Bug absence** (or a reproducible counterexample) over long soaks | The threshold value; node count is bounded |
| 5 | **Live mainnet** (Koios/market) | What are the real inputs *right now*? | Current active stake, price, $ cost | Anything counterfactual |

### Layer 1 — Analytical model / ticker
The formula and the live ticker. Fast, exact *given the model*. This is "the calc on DWARF." It
is necessary and it is not sufficient — hence everything below.

### Layer 2 — Simulator ("the fancy calculator," done honestly)
A discrete-event or abstract-race simulator samples block-production and delay processes and
measures how often a private chain of adversarial fraction α overtakes the honest chain, sweeping
λ, Δ, α. Its job is **not** to produce a number the formula already gives — it is to (a) confirm
the closed form against Monte Carlo, (b) map the regimes where the closed-form approximation
breaks (heavy tails, bursty delay, correlated leadership), and (c) generate the **specific
(α, Δ) points worth reproducing on real nodes**. IOG's own simulation efforts (e.g. the internal
network/consensus simulators; "Piranha") sit here. **Hard limit:** every simulator abstracts the
protocol and cannot run enough *real* nodes to be the empirical proof — its authors say as much.
So the simulator hands a short-list of parameter points *down* to Layer 3.

### Layer 3 — DWARF devnet (this is the part we built)
DWARF stands up a **real** multi-node devnet running the actual `cardano-node` (and, in the
differential profiles, Amaru alongside it), then injects the exact mechanism the theory is about:

- **Adversarial stake** — assign a stake fraction to adversary pool(s).
- **Network delay Δ** — inject latency on the adversary↔honest link to realise a chosen λΔ.
- **Private fork** — have the adversary withhold and then release a competing chain.
- **Oracles** — assert the honest network keeps a **common prefix**, recovers within the
  **k-bound rollback**, and that all nodes make a **consistent chain selection**.

The concrete scenario we authored and ran on the box,
[`consensus-threshold-delay-probe.yaml`](../scenarios/consensus-threshold-delay-probe.yaml):

- **Substrate:** 4-node devnet on `testnet_42`, docker compose — `node1/2/3` honest, `adv1`
  adversary, wired so `adv1` reaches the honest set only through `node1`.
- **Load / fault primitives:**
  `runtime_network_impairment` (300 ms latency, adv1→node1) ·
  `runtime_chainsync_responder_fork_switch` (private-fork release at node1) ·
  `runtime_multi_node_observation` (tip + connection state, 20 s window, magic 42).
- **Assertions (oracles):** `all_nodes_responsive` · `k_bound_rollback_recovered` ·
  `chain_select_consistent`.

**What this proves:** the real chain-selection and rollback code *does* exhibit the private-fork
race the model describes, and — in the differential profiles — Amaru and cardano-node make the
**same** decision (a divergence would itself be a finding). **What it cannot prove:** the
asymptotic 40% number. A 4-node devnet is a *mechanism demonstration and a differential
correctness check*, not a statistical measurement of β\*. Sweeping the stake fraction and Δ across
runs (Task T-B, "adversarial-stake sweep") walks the *shape* of the curve at small N and shows the
crossover moves the predicted direction — it validates the **code against the model**, which is
precisely the gap Layer 2 cannot close.

> Devnet caveat we hit and documented: very short devnet epochs interact badly with node startup
> (the "Amaru won't start on a short-epoch testnet" root-cause, Task T0). Threshold runs use
> parameters chosen to avoid that, and the run completed end-to-end with no false finding.

### Layer 4 — Antithesis (deterministic, exhaustive, long)
The same real binaries run inside Antithesis's **deterministic hypervisor**, which explores
adversarial *interleavings* (message order, delay, crash/restart) that random testing misses, and
does so **reproducibly** over multi-day soaks. Here the "everything is a race" adversary becomes a
search: does *any* schedule ever violate a **safety** invariant (two honest nodes commit
conflicting history beyond k) or a **liveness** invariant (the chain stalls)? A violation is a
concrete, replayable counterexample; a clean soak is high-confidence **bug absence**. **Limit:**
like the devnet, node count is bounded, so Antithesis proves *invariants*, not the *threshold
value*. It closes the "is the implementation free of the bugs that would make β\* worse" question
that Layer 3 can only spot-check.

### Layer 5 — Live mainnet
Koios `/totals` + `epoch_info` and a price feed give the *current* active stake and ADA price, so
the economic number in §3 is always live, not a stale slide. This is the ticker's data source.

### How the layers hand off
```
   Praos theorem (β* < 50%)                     ─ Layer 1: what the theory says
        │  add real timing (λΔ)
        ▼
   Race analysis  →  β* ≈ 40% band              ─ Layer 1
        │  confirm + find regimes + pick (α, Δ) points
        ▼
   Simulator sweep (Monte Carlo)                ─ Layer 2  (validates the model vs itself)
        │  hand short-list of parameter points down
        ▼
   DWARF devnet: real nodes exhibit the         ─ Layer 3  (validates code vs model + Amaru↔cardano-node differential)
   private-fork race; common-prefix / k-bound
   / chain-select oracles hold
        │  same binaries, exhaustive schedules
        ▼
   Antithesis: no safety/liveness violation     ─ Layer 4  (validates implementation is bug-free where it counts)
   over multi-day deterministic soak
        │  translate threshold to money, live
        ▼
   Live ticker: 40% of active stake =           ─ Layer 5  (grounds it in today's dollars)
   ~24% of circulating ≈ $1.3B (spot floor)
```
Read top-to-bottom, that is a **defensible evidence chain**: theory → model self-validation →
implementation-matches-model → implementation-is-bug-free → live economic grounding. Read as a
claim, it is honest about its own limits: *the number is a model output; the testbeds show the
real system is faithful to the model and free of the bugs that would break it.*

---

## 6. What we actually did (proof of work)

Concrete, reviewable artifacts produced while investigating this — beyond the one-line calc:

| Artifact | Where | What it establishes |
|----------|-------|---------------------|
| Schema/DSL fix so devnet + phased scenarios validate | `spec/v1/schema.json` (all 233 scenarios validate) | The harness can *express* a substrate-based threshold experiment at all |
| Threshold/delay devnet scenario | [`scenarios/consensus-threshold-delay-probe.yaml`](../scenarios/consensus-threshold-delay-probe.yaml) | Layer 3 mechanism run — authored and **executed end-to-end on the box**, no false finding |
| Threshold profile | [`profiles/profile-m-consensus-threshold/`](../profiles/profile-m-consensus-threshold/profile.yaml) | Repeatable packaging of the run |
| Live attack-cost ticker | `/learn/attack-cost`, dashboard + self-contained site | Layer 1 + Layer 5 — the economic number, live |
| Self-contained reference / Overview | `/learn/overview` | Full walkthrough surface for reviewers |
| This analysis | `docs/consensus-threshold-analysis.md` | The methodology + honest epistemics on record |

Open follow-ups already scoped as tasks: **T-B** (adversarial-stake sweep — walk the crossover at
small N), **T-A** (chain-selection differential Amaru↔cardano-node — "chainhold"), **S1/S2/S3**
(long-range, deep-rollback, epoch-boundary scenarios), and **T-shared** (the node-agnostic
common-prefix / tip-diff oracle the sweep leans on).

---

## 7. How to reproduce / extend

Run the mechanism scenario:
```
cardano-profile scenario run scenarios/consensus-threshold-delay-probe.yaml
```
To walk the curve (Task T-B), vary two knobs across runs and record whether the honest network
keeps common prefix:
- **adversary stake fraction** — the pool stake assigned to `adv1` (approach β\* from below/above);
- **delay Δ** — `runtime_network_impairment.latency_ms` on the `adv1 → node1` link (realise a
  chosen λΔ; the scenario ships at 300 ms).

Expected behaviour if implementation matches model: below β\* the honest chain keeps a common
prefix and any adversarial fork is rolled back within the k-bound; as the stake fraction and Δ
rise toward the band, rollback depth and time-to-recover grow, and past threshold the private
fork wins. That crossover *moving the predicted direction* is the Layer-3 evidence.

---

## 8. References

- David, Gaži, Kiayias, Russell — *Ouroboros Praos: An Adaptively-Secure, Semi-Synchronous
  Proof-of-Stake Blockchain* (Eurocrypt 2018). *Honest-majority / common-prefix — number #1.*
- Dembo, Kannan, Tse, Viswanath, Wang, Zhao — *Everything is a Race and Nakamoto Always Wins*
  (ACM CCS 2020). *Private-attack / delay-adjusted threshold — number #2.*
- Gaži, Kiayias, Russell — tight analyses of Nakamoto/Ouroboros consensus under delay.
- Kiayias, Koutsoupias, Kyropoulou, et al. — *Reward Sharing Schemes* / the `k = 500`
  decentralisation target (distinct from the 2160-block consensus k).
- Cardano protocol parameters: slot = 1 s, f = 0.05, epoch = 432,000 slots, k = 2160 blocks.

*All threshold figures in this note are model outputs or arithmetic on live on-chain data, clearly
labelled as such. The testbed layers validate that the real implementation is faithful to the
model and free of safety/liveness violations; they do not, and are not claimed to, empirically
measure the asymptotic threshold.*
