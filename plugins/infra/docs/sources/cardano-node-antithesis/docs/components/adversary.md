# Adversary

A node-to-node downstream client that connects to a randomly-chosen
node in the cluster, asks for a chain sync from a randomly-chosen
intersection point, pulls a bounded number of headers, and disconnects.
The Antithesis composer fires it repeatedly under fault injection so
nodes see concurrent connection churn while their chain is being
rolled back, paused, or partitioned.

## Shape

The component ships:

- a single Haskell binary `cardano-adversary` (built from
  [`components/adversary/`][adv-comp]),
- a sleep-forever Docker image that bakes the binary plus its driver
  scripts under `/opt/antithesis/test/v1/chain-sync-client/`,
- a single composer driver `parallel_driver_flap.sh`.

The container itself does **no work** — it is a host the Antithesis
composer `docker exec`s into per tick. Everything stateful is
ephemeral inside the per-tick process; nothing lives across ticks.

```
                           +--------------------------------+
                           |   adversary container          |
                           |   (sleep -f /dev/null)         |
                           |                                |
   Antithesis composer --->|   /opt/antithesis/test/v1/     |
   docker exec per tick    |     chain-sync-client/         |
                           |       parallel_driver_flap.sh  |
                           |   /bin/cardano-adversary       |
                           |                                |
                           +--------------------------------+
                                       |
                                       | initiator-only
                                       | NodeToNodeV_14
                                       v
                           +--------------------------------+
                           |  one of:                       |
                           |    p1, p2, p3 (producers)      |
                           |    relay1, relay2 (relays)     |
                           |  picked uniformly from --seed  |
                           +--------------------------------+
```

## What one tick does

1. The composer dispatches `parallel_driver_flap.sh` inside the
   adversary container.
2. The shell reads a 64-bit seed from `antithesis_random` (or
   `/dev/urandom` outside the Antithesis runtime) and execs
   `cardano-adversary` with the seed and the candidate target list.
3. The binary splits the seed, picks **one** target host uniformly
   from `--target-host` and **one** chain point uniformly from
   `--chain-points-file`.
4. It opens a single initiator-only N2N session against that host,
   sends `MsgFindIntersect [point]`, then loops `MsgRequestNext`
   until `--limit` headers are received or the producer's tip is
   reached.
5. It disconnects and exits 0.

Antithesis's chaos can SIGKILL the container at any point; `restart:
always` brings it back, and the next tick's exec is independent.
Mid-tick connection drops to nodes are an expected byproduct of
fault injection — they are not a bug in the adversary.

## What it exercises

- Each node's mux + connection-management code under churning
  initiator-only N2N peers.
- The intersection-finding logic, with both well-known and
  rolled-back points.
- ChainSync server state machine on every node — producers and
  relays alike speak the same protocol.

## What it does not exercise

- Block-fetch, tx-submission, keep-alive, or handshake mini-protocols
  (each is a candidate for its own future archetype, not yet
  implemented).
- Upstream-peer (server) behaviour — the adversary never serves a
  chain. That requires a topology change tracked separately
  (see [#91][issue-91]).
- Mid-protocol misbehaviour (malformed messages, stalled requests,
  out-of-order responses). Today the loop only sends well-formed
  requests.

## CLI

```text
Usage: cardano-adversary --network-magic INT (--target-host HOST)
                         [--target-port PORT] --chain-points-file PATH
                         --seed HEX-OR-DEC [-l|--limit N]
```

| Flag | Default | Meaning |
|---|---|---|
| `--network-magic INT` | (required) | Network magic of the target cluster (e.g. 42). |
| `--target-host HOST` | (required, repeatable) | One candidate target. Pass multiple times; one is picked uniformly per invocation. |
| `--target-port PORT` | `3001` | N2N port on every `--target-host`. |
| `--chain-points-file PATH` | (required) | Path to a `tracer-sidecar` chainpoints file. One `<hash>@<slot>` per line, plus the implicit `origin` point. |
| `--seed HEX-OR-DEC` | (required) | PRNG seed driving both target-host and chain-point pick. Source from `$(antithesis_random)` in the driver. |
| `--limit N` | `100` | Stop after syncing N headers. |

The seed routes both random choices, so when Antithesis seeds the
driver shell deterministically, the entire run is replayable.

## Composer driver

Single driver: [`components/adversary/composer/chain-sync-client/parallel_driver_flap.sh`][driver].

```bash
SEED=$(antithesis_random 2>/dev/null \
    || od -An -tx8 -N8 /dev/urandom | tr -d ' \n')

exec cardano-adversary \
    --network-magic 42 \
    --target-host p1.example \
    --target-host p2.example \
    --target-host p3.example \
    --target-host relay1.example \
    --target-host relay2.example \
    --target-port 3001 \
    --chain-points-file /tracer/chainPoints.log \
    --seed "0x${SEED}" \
    --limit 100
```

Targeting policy is in this file, not in the binary or some default
buried in Haskell. To restrict an experiment to producers only,
delete the two `relay*.example` lines. To attack only one node,
delete the others. The list lives next to the network magic and the
port — one place describes the attack target.

## Wiring on `cardano_node_adversary`

The adversary runs as its own service in
[`testnets/cardano_node_adversary/docker-compose.yaml`][compose]:

```yaml
adversary:
  image: ghcr.io/cardano-foundation/cardano-node-antithesis/adversary:69f49c5
  hostname: adversary.example
  volumes:
    - tracer:/tracer:ro       # tracer-sidecar writes chainPoints.log here
  depends_on:
    tracer-sidecar:
      condition: service_started
    configurator:
      condition: service_completed_successfully
  restart: always
```

No `command:` override — the image's `EntryPoint` is `tail -f
/dev/null`. No socket volume. No shared state with anyone else. The
only mount is `tracer:/tracer:ro` so the binary can read
`/tracer/chainPoints.log`.

## Build the image

The image is published by the
[`publish-images`][publish-images] workflow on every PR-to-main and
push-to-main, scoped to whatever tag the consuming compose pins. The
script is content-addressed: only tags that are not already in GHCR
get rebuilt.

Local build for development:

```bash
cd components/adversary
nix build .#docker-image
docker load < ./result
```

## Local test loop

Bring up the testnet, then exec the driver inside the adversary
container:

```bash
INTERNAL_NETWORK=true scripts/smoke-test.sh cardano_node_adversary 600
```

The smoke-test:

1. Starts the compose project.
2. Pings p1/p2/p3 via `cardano-cli ping`.
3. Runs the sidecar's `convergence/eventually_converged.sh`.
4. Execs `parallel_driver_flap.sh` inside the adversary container
   once; the binary should pick a target, sync 100 headers, and
   exit 0.

A green run logs:

```
OK: p1 — host: 127.0.0.1:3001, …
OK: p2 — host: 127.0.0.1:3001, …
OK: p3 — host: 127.0.0.1:3001, …
Checking sidecar convergence command…
Probing adversary driver…
cardano-adversary: target=relay2.example point=origin limit=100 seed=…
cardano-adversary: completed; reached At (Block {blockPointSlot = SlotNo 38, …})
OK: adversary driver
PASS: all 3 nodes responding
```

## Source layout

```
components/adversary/
├── adversary.cabal
├── app/Main.hs                          — CLI parsing (optparse-applicative),
│                                          seeded random pick of host + point,
│                                          single adversaryApplication call
├── src/Adversary.hs                     — chain-point parser, pickOne helper
├── src/Adversary/Application.hs         — chain-sync state machine,
│                                          adversaryApplication
├── src/Adversary/ChainSync/
│   ├── Codec.hs                         — codec for Header/Point/Tip
│   └── Connection.hs                    — connectToNode + Ouroboros wiring
├── composer/chain-sync-client/
│   └── parallel_driver_flap.sh
├── nix/
│   ├── project.nix                      — haskell.nix project
│   └── docker-image.nix                 — sleep-forever image with binary +
│                                          baked driver scripts
├── test/AdversarySpec.hs                — chain-point + pickOne unit tests
├── flake.nix
└── Dockerfile
```

## Why a CLI per tick (and not a daemon)

A previous iteration shipped a long-running daemon (NDJSON over a
UNIX socket, one request per tick, lifted into
[`lambdasistemi/cardano-node-clients`][cnc]). Diagnosis after a
regression on `cardano_node_master` showed three structural problems:

1. **Two schedulers behind one socket.** The Antithesis composer is
   itself a scheduler; the daemon's accept loop was a second. Neither
   was observable from the other.
2. **Targeting bias was emergent.** `cycle peerNames` × the driver's
   `NCONNS=1` default funnelled 100 % of attacks at p1; the other
   producers and the relays were never touched. p1 fell behind, the
   convergence sidecar reported `tips_divergent`, the cluster looked
   broken on every run.
3. **Lifecycle complexity for no benefit.** The adversary is
   *stateless per tick* — every `chain_sync_flap` request opened
   fresh sockets, ran to completion, and threw the chain TVar away.
   Nothing was carried across ticks. A daemon adds a chaos target, a
   second restart loop, and an `IOException`-on-SIGTERM class, while
   sharing nothing useful between requests.

The current CLI-per-tick model:

- has *one* scheduler — the Antithesis composer;
- writes the targeting policy in the driver shell, where it is
  visible to anyone listing the directory;
- spawns one short-lived process per tick; mid-tick chaos kill is
  indistinguishable from clean tick exit.

The full diagnosis (logs, evidence, regression timeline) is in the
PR that did the redesign: [#110][pr-110]. The companion deletion in
the daemon's home repo: [`cardano-node-clients` PR #122][pr-122].

## See also

- [Adversary roadmap](adversary-roadmap.md) — what's next: more
  archetypes, each as its own CLI under this component.
- [#91][issue-91] — Tier 3 epic: adversary as N2N **server**
  (Byzantine upstream peer). Different testnet variant; not part of
  this component yet.
- [Network spec PDF][Netspec] — chain-sync mini-protocol on p. 21.
- [ouroboros-network][Ouroboros] — the upstream library we depend on.
- Other projects by [HAL][HAL]
- Other projects by the [Cardano Foundation][CF]
- About [Cardano][Cardano]



[adv-comp]: https://github.com/cardano-foundation/cardano-node-antithesis/tree/main/components/adversary
[driver]: https://github.com/cardano-foundation/cardano-node-antithesis/blob/main/components/adversary/composer/chain-sync-client/parallel_driver_flap.sh
[compose]: https://github.com/cardano-foundation/cardano-node-antithesis/blob/main/testnets/cardano_node_adversary/docker-compose.yaml
[publish-images]: https://github.com/cardano-foundation/cardano-node-antithesis/blob/main/.github/workflows/publish-images.yaml
[pr-110]: https://github.com/cardano-foundation/cardano-node-antithesis/pull/110
[pr-122]: https://github.com/lambdasistemi/cardano-node-clients/pull/122
[cnc]: https://github.com/lambdasistemi/cardano-node-clients
[issue-91]: https://github.com/cardano-foundation/cardano-node-antithesis/issues/91
[Ouroboros]: https://github.com/IntersectMBO/ouroboros-network
[Netspec]: https://ouroboros-network.cardano.intersectmbo.org/pdfs/network-spec/network-spec.pdf
[HAL]: https://github.com/cardano-foundation/hal
[CF]: https://github.com/cardano-foundation
[Cardano]: https://cardano.org/
