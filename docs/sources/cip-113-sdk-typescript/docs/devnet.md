# Local devnet (Yaci DevKit)

How to run the devnet-backed tests, and the traps that cost real time getting there.

## Running

```bash
setsid nohup npx --yes @bloxbean/yaci-devkit up --enable-yaci-store --tail false \
  >/tmp/yaci.log 2>&1 </dev/null &                                     # node, store, ogmios
setsid nohup bash ~/.yaci-cli/local-clusters/default/kupo.sh \
  >/tmp/kupo.log 2>&1 </dev/null &                                     # Kupo — see below
npm run test:devnet
```

`npm test` is offline and never touches the network. `npm run test:devnet` requires a devnet
and **fails loudly** when there isn't one — there is deliberately no skip path (see below).

| port | service |
|---|---|
| 10000 | yaci-cli **admin API** |
| 8080 | **yaci-store** (Blockfrost-compatible REST) |
| 3001 | cardano-node |
| 1337 | Ogmios |
| 1442 | Kupo |
| 8090 | cardano-submit-api |

Ports are not configurable — `cluster-info.json` is regenerated on every `up`.

## Traps

**⛔ A PORT CONFLICT KILLS THE DEVNET SILENTLY — no error, no exit, nothing in any log.**
MEASURED 2026-09-07. `up` printed nothing, kept running, and started NOTHING: `~/.yaci-cli/pids/`
stayed empty, no node/ogmios/store process ever appeared, and `~/.yaci-cli/components/store/logs/`
was untouched (its newest entry was a week old). From the outside this is indistinguishable from a
slow boot, and waiting longer never resolves it.

The cause was `cardano-node` failing to bind **port 3001**, which the devkit hardcodes in
`node/node.sh` (`--port 3001`) and in `cluster-info.json`. On this machine 3001 was held by an
unrelated **Next.js dev server**. Because nothing in the devkit surfaces that, the failure looks
like the devnet is merely taking its time.

**Two misleading signals will confirm the wrong theory if you let them.** `:10000` answered (the
admin API is up, it just serves 404 on unknown routes — see "A green admin API proves nothing"
below), and `:3001` answered 200 — but that was the *foreign* process, not the node. A responding
port is evidence a port is BOUND, never evidence the right service bound it.

⇒ **How to get the real error in one command** — run the node script directly, FROM ITS OWN
DIRECTORY, since it uses relative paths and fails with a misleading
`YamlException: configuration.yaml not found` from anywhere else:

```bash
cd ~/.yaci-cli/local-clusters/default/node && timeout 25 bash node.sh 2>&1 | tail -5
# cardano-node: DiffusionError Network.Socket.bind: resource busy (Address in use)
```

Check the port before starting, since the check costs nothing and the diagnosis costs ten minutes:

```bash
ss -ltnp | grep -E ":(3001|8080|1337|1442|10000|8090)\b"
```

⚠ And whatever holds the port may not be yours. Here it was another project's dev server, running
for days. **Do not kill a process to free a devnet port without checking what it is** — the devnet
is disposable and the thing in its way may not be.

**Some documentation has 10000 and 8080 swapped.** Verified on this machine: `yaci-cli` serves
the admin API on **10000**, `yaci-store` is on **8080**.

**`yaci-devkit up --help` KILLS THE RUNNING DEVNET.** It is not an inert help flag — the wrapper
kills existing yaci-cli processes *before* parsing arguments. It then leaves an orphan holding
port 10000, which makes the next `up` fail with `BindException: Address already in use`. Do not
run `--help` against a devnet you care about.

**`yaci-devkit`'s exit code cannot be trusted — IN BOTH DIRECTIONS.** The npx wrapper exits **0**
while the underlying yaci-cli exits 1, so a CI step that only checks the exit code will report a
green devnet that never started. **And the same masking hides the opposite event: it cannot tell you
the devnet was KILLED.** MEASURED 2026-09-10 — a `timeout` firing on a running devnet should surface
as **124** and came back as **0**. One masking, two questions, and this page only ever asked the
first one. Health-check the services, not the exit code, and not only at startup.

> ⚑ **A trap you have written down is not a trap you have internalised.** The engineer who hit the
> kill-side of this masking had read and quoted the start-side of it, from this very page, three
> hours earlier. Writing a hazard down buys you nothing at the moment you are inside it; only a
> mechanism that fails loudly does — which is why the entries here prescribe commands rather than
> vigilance.

**⛔ `--tail false` DOES NOT DAEMONIZE — and this is the biggest trap on the page.** It stops the
wrapper *streaming logs*; it does **not** detach anything. Every component stays a CHILD of the
invoking process, so the whole devnet dies when that process goes away: a `timeout` wrapper firing,
the launching shell exiting, a CI step ending, an agent session being torn down. **And none of
those announce themselves**, because the exit status is masked by the entry above.

MEASURED 2026-09-10: a launch wrapped in `timeout 300` was killed at five minutes; five of six
ports vanished and the chain stalled. The kill reported **exit code 0**. The one component that
survived was **Kupo — precisely because it had been started detached**, which is why this document
used to read the hazard as a Kupo quirk. It is not: Kupo was the exception, not the special case.

⇒ **Detach the CORE the same way you detach Kupo**, as the Running block does:

```bash
setsid nohup npx --yes @bloxbean/yaci-devkit up --enable-yaci-store --tail false \
  >/tmp/yaci.log 2>&1 </dev/null &
```

**Never wrap `up` in `timeout`.** A timeout on a process that owns the devnet is a scheduled
outage, not a safety net.

### ⚑ A liveness check taken INSIDE the lifetime of the process that owns the thing proves only that both are alive right now

The general form of the trap above, and it outlives this tool. Ports were checked; a slot delta was
checked — both are the right instruments, and both were correct at the moment they ran. Neither
asked **whether what had just been started would outlive the checking**, and the answer was no: the
prover was the owner. A verification that shares a fate with its subject cannot report on that fate.

⇒ Prove it the way it will actually be used: check **from a process that did not start it**, or
after the starter has exited. On this machine, "the devnet is up" is only meaningful once the shell
that ran `up` is gone — before that you have measured a coincidence.

**Every subcommand binds port 10000, including `down`.** So `down` fails with a BindException
while a devnet is running — the thing it exists to stop. Recovery is to kill the processes
directly (`~/.yaci-cli/...` paths and the `yaci-devkit-linux-x64/yaci-cli` binary), then start
fresh. Beware `pkill -f yaci` in an interactive shell: the pattern matches the shell's own
command line and kills the shell.

**`--enable-kupomios` does not start Kupo.** It did nothing on a first run because the binary
had never been downloaded, and it still did not start Kupo after `-c node ogmios kupo yaci-store`
fetched it. What works is running DevKit's own script directly:
`bash ~/.yaci-cli/local-clusters/default/kupo.sh`.

**A green admin API proves nothing.** The cluster inherited on this machine answered `:10000`
normally for weeks while `:8080` hung indefinitely — and the previous holder's devnet test suite
silently *skipped* the whole time, which reads like passing at a glance. If the store hangs,
reset the cluster; that fixes it:

```bash
curl -X POST http://localhost:10000/local-cluster/api/admin/devnet/reset
```

This is why the harness checks admin, store, Kupo **and** Ogmios independently, and why devnet
tests have no skip path: a run either happened or it errored.

## SDK wiring: use Kupmios, not Blockfrost

Yaci Store exposes a Blockfrost-compatible REST API, and it does not work with this SDK.
Evolution's `BlockfrostUTxO` schema requires `tx_index` and `block`; Yaci Store returns neither
(it sends `epoch`, `block_number`, `block_time`). Every `getUtxos` therefore fails schema
validation, surfacing only as `Blockfrost getUtxos failed` with no cause attached.

Evolution offers no custom-provider hook — `withBlockfrost`, `withKoios`, `withKupmios`,
`withMaestro` are the entire set — so **Kupmios is the only workable devnet wiring**, and Kupo
is mandatory rather than optional.

**`getUtxos` needs the `Address` OBJECT, not a bech32 string.** Kupmios checks
`instanceof Address` and otherwise reads `.hash`, so passing a string silently builds the URL
`/matches/undefined/*?unspent` and the call fails as an opaque `Kupmios getUtxos failed`:

```js
const addressObj = await client.address();        // correct
await client.getUtxos(addressObj);

await client.getUtxos(EvoAddress.toBech32(addressObj));   // WRONG — fails opaquely
```

## Shared chain, exclusive lifecycle

**Use it freely. You do not need to claim it.** It is a testnet: multiple projects can put
transactions on the same ledger simultaneously, each deploying its own scripts and funding as
many of its own wallets as it likes. That is what a shared devnet is for.

**⛔ LIFECYCLE IS NOT YOURS TO RUN (ruled by Giovanni, 2026-09-10).** The devnet is
INFRASTRUCTURE owned by the DevOps role (Steward), not by whichever project session happens to
need it. It stays **shared for USE** — deploy scripts, fund wallets, submit transactions freely,
never ask. It is **exclusive for LIFECYCLE**: `up`, `down`, reset, `--help`, and starting or
stopping Kupo belong to Steward alone, and a session that needs one **asks the Machine Owner,
who dispatches Steward**. Do not run it yourself and do not brief Steward directly.
*Why the rule changed: the previous convention — "the session that needs it starts it" — left the
devnet DOWN for a day and a half with a slice staged behind it, because the session that needed it
was the one role not permitted to start it.*

**Coordinate before anything destructive** — `up`, `down`, reset, or `--help` (which kills it,
see above). Those are the operations that are genuinely exclusive, because the machine has
exactly one cluster: a single `~/.yaci-cli` with one `local-clusters/default` and one node
socket, so remapping ports would not isolate two lifecycles. Restarts should be rare; ordinary
use needs no coordination at all.

Two reasons a restart is expensive beyond the coordination:

- **Kupo does not come back.** It is started manually (see above) and nothing restarts it — no
  systemd unit, no cron entry, no container; all three checked 2026-09-10.
  ⚑ **HALF OF THIS WAS SELF-INFLICTED, and this document taught it.** Until 2026-09-10 the two
  start snippets here used a bare `&`, which ties Kupo to the launching shell: the shell exits,
  the process group is torn down, Kupo dies. It was read as "the DevKit does not restart Kupo"
  for weeks. **Always start it detached** — `setsid nohup … >/tmp/kupo.log 2>&1 </dev/null &` —
  and do not simplify that back to `&` when copying it somewhere new; the flags ARE the fix, not
  ceremony. (Found by the DevOps role, 2026-09-10.)
- **A reset wipes everyone's state**, including any suite mid-run.
- **It does not survive its launcher, let alone a reboot** — see `--tail false` above; the common
  case is not a reboot but a shell or session ending. Assume it is gone rather than
  assume it is there: run the health checks first, and if it is down, ask (see the ownership rule
  above). ⚠ **Memory is the binding constraint, not disk** — measured 2026-09-10, ~5.0 GB
  available of 29.3 GB, because this machine also runs the ryzen k8s cluster.

The distinction matters and is easy to get backwards: a single-instance *lifecycle* constraint
is not single-tenancy of the *chain*. Treating it as the latter serialises work that never
needed serialising.


## Why the devnet suite runs with `--test-concurrency=1`

`node --test` runs test FILES concurrently, in separate processes. Every devnet test here
derives the SAME wallet from the same mnemonic, so two files bootstrapping at once select
the same UTxOs and the loser's transaction is rejected with:

```
code 3117 — "The transaction contains unknown UTxO references as inputs. This can happen
if the inputs you're trying to spend have already been spent"
```

That error names the symptom (a missing UTxO) and not the cause (another test process
spent it), so it reads as a bug in the transaction being built. It is not. Either serialise
the suite — which is what `--test-concurrency=1` does — or give each file its own wallet.

Serialising is the right default here: the devnet is itself a shared resource, the
protocol bootstrap is not idempotent, and a concurrency bug that only appears when two
files happen to overlap is worse than a slower suite.

## Traps met while making the devnet suite green (2026-08-25)

**The faucet does not clamp to what it can afford.** Each genesis account holds 10,000 ADA. The
bootstrap asked for 500,000 and got HTTP 500 with an empty `statusText`; the only useful content
was in the response BODY (`{"status":false,"message":"Topup failed"}`), which the harness was
discarding. It now logs the body on every non-2xx — an error without it reads as "the service is
broken" when it means "your request was rejected".

**Three unrelated causes all surface as code 3117**, *"unknown UTxO references as inputs"* — an
error that names a UTxO and reads as a malformed transaction, when the builder faithfully used what
the provider reported:

1. **Concurrent test files.** `node --test` runs files in separate processes and every devnet test
   derives the same wallet, so two files bootstrapping at once select the same UTxOs. Hence
   `--test-concurrency=1`.
2. **Accumulated state.** After many bootstraps, submissions start failing. `curl -X POST
   .../admin/devnet/reset` clears it; bootstrap going green immediately afterwards confirms the
   diagnosis rather than assuming it.
3. **Indexer lag.** Kupo and yaci-store trail the node, so right after a confirmed transaction
   `getUtxos` still returns spent inputs. `bootstrapProtocol` waits for two consecutive identical
   wallet views — a single read cannot tell a settled view from a stale one.

**Settle on the way OUT as well as the way in.** Waiting for a settled view only at the bootstrap's
entry made its own failure disappear and moved it into `register` and `upgrade`, which build
immediately after the bootstrap returns. A fixture owes its caller a settled world on exit.

**Kupo survived the reset performed on 2026-08-25**, but the warning above still stands — it has not
always. Check `:1442` after any reset and restart it with
`bash ~/.yaci-cli/local-clusters/default/kupo.sh` if it is gone.

## What the devnet suite actually proves

`npm run test:devnet` — **16 tests** — covers, on chain: a protocol bootstrap in five transactions
(one no longer fits the 16 kB limit, and alpha.3 added the dispatcher's reference script and stake
registration); the deployed state read BACK and checked field by field; a `dummy` token registered,
minted and transferred with the balance delta asserted on **both** sides; the full freeze-and-seize
lifecycle including seize and burn; an in-place upgrade proven as a before/after delta; two upgrade
rails proven to be refused by `protocol_params` itself (Ogmios 3010) rather than by client-side
validation; and CIP-171 records recomputed to deployed hashes on two transactions.

⛔ **This suite is the only thing that has ever proven the alpha.3 migration works.** It found three
defects that survived every offline slice with `npm test` green: the harness loading the *wrong
blueprint version* for the whole migration, an `assertDeploymentScripts` check asserting a
payment-vs-stake relationship that does not exist (hidden by a fixture that used one value for both
fields), and the dispatcher's withdrawal being wired with neither its script witness nor its
registered stake credential. **None of the three was visible without a chain.**

It does **not** prove anything about mainnet or preprod parameters, and it is deliberately not run
in CI — there is no devnet there.

## Kupo does not survive a long suite

Observed three times on 2026-08-25/26: `:1442` goes away mid-run while every other port stays up.
There is no partial-failure mode — the harness's precondition check fails loudly and every
remaining test reports `hookFailed`, which is correct behaviour and looks alarming.

**If several consecutive tests fail with `No usable Yaci devnet` and only Kupo is named, restart it
and re-run before investigating anything else:**

```bash
setsid nohup bash ~/.yaci-cli/local-clusters/default/kupo.sh >/tmp/kupo.log 2>&1 </dev/null &
```

The failures are not a regression in whatever you changed last, and the timing invites believing
they are — they arrive immediately after an edit, at the tests furthest from it.

## ⚠ Kupo must be RESTARTED after a devnet reset — an open port is not a healthy index

A reset rewinds the chain. Kupo keeps serving the index it already has, and **its port stays open
the whole time**, so an "is it up?" check passes while it describes a chain that no longer exists.
Everything built against that view is rejected with code 3117.

MEASURED: a reset followed by a port check (open → skipped the restart) produced seven failures
across unrelated tests, including ones whose code had not been touched. The port answering is
exactly the kind of clean, plausible reading an instrument gives when it cannot see the thing you
are asking it about.

**Restart it unconditionally after a reset** — and note the two traps below.

### ⛔ AND `/health` CANNOT TELL YOU — it returns 200 on a Kupo whose database has been DELETED

The trap above says an open port is not a healthy index. **This is one layer deeper: a 200-returning
health endpoint is not a healthy index either**, and every check this page previously prescribed was
satisfied by a completely broken Kupo.

MEASURED 2026-09-10, and it cost a whole slice dispatch. A reset recreated
`~/.yaci-cli/local-clusters/default/` and **deleted `kupo_db/`** while Kupo kept running. Kupo held
its SQLite files open on **deleted inodes**, went on consuming from Ogmios once a second, and
reported `connection_status 1.0` with `most_recent_checkpoint` equal to the node tip — while every
query returned 500:

```
/health      → 200          ← what we were all checking
/matches     → 500          ← what the SDK actually calls
/checkpoints → 500
```
```
SQLite3 returned ErrorCan'tOpen while attempting to perform open2
  "file:/home/giovanni/.yaci-cli/local-clusters/default/kupo_db/kupo.sqlite3":
  unable to open database file
```

`/health` is green because it reports the **Ogmios socket and an in-memory checkpoint** — both
genuinely alive. It never touches the database. So it answers a question nobody was asking.

**⇒ Health-check `/matches`, never `/health`.** It is the endpoint `Kupmios.getUtxos` calls, so it
cannot be green while the SDK is broken:

```bash
curl -sf http://localhost:1442/matches >/dev/null && echo kupo-ok
```

### ⚠ AND A THIRD STATE, BETWEEN DEAD AND HEALTHY: answering, correct, and BEHIND

`/matches` returning 200 proves the index is **open**. It does not prove the index is **current**.
A freshly restarted Kupo answers immediately and then re-indexes from the origin, so for the first
stretch of its life every query it serves is correct about a chain that has moved on.

That state is the worst of the three to debug, because the failures it produces are **code 3117
"unknown UTxO references as inputs"** — indistinguishable from a genuine bug in the transaction you
just built, and identical to the indexer-lag entry further down this page. Dead Kupo fails loudly;
split-brain Kupo fails on every query; *trailing* Kupo fails on exactly the inputs you created most
recently, which is to say the ones your test just made.

**⇒ Before depending on a Kupo you did not watch start, compare its checkpoint to the node tip:**

```bash
curl -sf http://localhost:1442/health | grep kupo_most_recent_checkpoint   # e.g. 1570
curl -sf -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"queryNetwork/tip","id":null}' \
  http://localhost:1337 | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["slot"])'
```

Equal means current. This is the one question `/health` answers well — note the irony, and note that
it is only trustworthy **alongside** the `/matches` check above, never instead of it: a split-brain
Kupo also reports a checkpoint equal to the tip, because it is still consuming from Ogmios happily.
**Two checks, two different failures, neither sufficient alone.**

Diagnose the state in one command — deleted inodes are the signature:

```bash
ls -l /proc/$(pgrep -x kupo)/fd | grep deleted      # kupo.sqlite3 (deleted), -wal, -shm
ps -o pid,lstart,comm -p $(pgrep -f 'kupo|yaci-cli|ogmios|yaci-store')   # which reset orphaned it
```

A Kupo started minutes BEFORE the other five components is the fingerprint: it survived a reset it
should have died with.

⚠ **And note what made this quiet: process survival is orthogonal to service health.** Kupo's
`setsid` detachment — the hardening two sections above — is precisely what let it outlive the reset
that destroyed its data. A crashed Kupo would have been caught by the port check. **Detaching was
still right; the lesson is that liveness and correctness need separate instruments**, because the
fix for one made the other's failure silent.

```bash
curl -X POST http://localhost:10000/local-cluster/api/admin/devnet/reset
setsid nohup bash ~/.yaci-cli/local-clusters/default/kupo.sh >/tmp/kupo.log 2>&1 </dev/null &
```

### ⛔ `pkill -f kupo` kills the shell that runs it

The same trap this document already records for `pkill -f yaci`: the pattern matches the killing
command's own command line. MEASURED — a `pkill -f kupo && restart` chain terminated itself with
exit 144, leaving Kupo down and the rest of the command unexecuted. Start Kupo with `setsid` and
detached stdin so it survives, and prefer killing by PID.
