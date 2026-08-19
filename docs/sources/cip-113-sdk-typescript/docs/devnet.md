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

## Exclusive resource

The machine has exactly one devnet. Everything lives under a single `~/.yaci-cli` with one
`local-clusters/default` and one node socket, so remapping ports would **not** isolate two
users — the contention is the cluster directory, not the ports. It is arbitrated on the machine
board; request and release it there rather than discovering the collision.
