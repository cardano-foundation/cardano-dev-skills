# Local devnet (Yaci DevKit)

How to run the devnet-backed tests, and the traps that cost real time getting there.

## Running

```bash
npx --yes @bloxbean/yaci-devkit up --enable-yaci-store --tail false   # node, store, ogmios
bash ~/.yaci-cli/local-clusters/default/kupo.sh &                      # Kupo — see below
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

**Some documentation has 10000 and 8080 swapped.** Verified on this machine: `yaci-cli` serves
the admin API on **10000**, `yaci-store` is on **8080**.

**`yaci-devkit up --help` KILLS THE RUNNING DEVNET.** It is not an inert help flag — the wrapper
kills existing yaci-cli processes *before* parsing arguments. It then leaves an orphan holding
port 10000, which makes the next `up` fail with `BindException: Address already in use`. Do not
run `--help` against a devnet you care about.

**`yaci-devkit`'s exit code cannot be trusted.** The npx wrapper exits **0** while the underlying
yaci-cli exits 1. A CI step that only checks the exit code will report a green devnet that never
started. Health-check the ports instead.

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

**Coordinate before anything destructive** — `up`, `down`, reset, or `--help` (which kills it,
see above). Those are the operations that are genuinely exclusive, because the machine has
exactly one cluster: a single `~/.yaci-cli` with one `local-clusters/default` and one node
socket, so remapping ports would not isolate two lifecycles. Restarts should be rare; ordinary
use needs no coordination at all.

Two reasons a restart is expensive beyond the coordination:

- **Kupo does not come back.** It is started manually (see above) and nothing restarts it.
- **A reset wipes everyone's state**, including any suite mid-run.

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

`npm run test:devnet` — 11 tests — covers, on chain: a protocol bootstrap in three transactions
(one no longer fits the 16 kB limit); the deployed state read BACK and checked field by field; a
`dummy` token registered, minted and transferred with the balance delta asserted on **both** sides;
an in-place upgrade proven as a before/after delta; and three upgrade rails proven to be refused by
`coordination_spend` itself (Ogmios 3010) rather than by client-side validation.

It does **not** prove anything about mainnet or preprod parameters, and it is deliberately not run
in CI — there is no devnet there.

## Kupo does not survive a long suite

Observed three times on 2026-08-25/26: `:1442` goes away mid-run while every other port stays up.
There is no partial-failure mode — the harness's precondition check fails loudly and every
remaining test reports `hookFailed`, which is correct behaviour and looks alarming.

**If several consecutive tests fail with `No usable Yaci devnet` and only Kupo is named, restart it
and re-run before investigating anything else:**

```bash
bash ~/.yaci-cli/local-clusters/default/kupo.sh &
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

**Restart it unconditionally after a reset** — and note the second trap below.

```bash
curl -X POST http://localhost:10000/local-cluster/api/admin/devnet/reset
setsid nohup bash ~/.yaci-cli/local-clusters/default/kupo.sh >/tmp/kupo.log 2>&1 </dev/null &
```

### ⛔ `pkill -f kupo` kills the shell that runs it

The same trap this document already records for `pkill -f yaci`: the pattern matches the killing
command's own command line. MEASURED — a `pkill -f kupo && restart` chain terminated itself with
exit 144, leaving Kupo down and the rest of the command unexecuted. Start Kupo with `setsid` and
detached stdin so it survives, and prefer killing by PID.
