# Benchmarking Hacking

## Basics

### Building a node

Clone the GitHub repo:

```console
$ git clone https://github.com/intersectmbo/cardano-node/
...
...
$ cd cardano-node
```

To inspect the repo the command ```nix flake show``` doesn't work due to a known
nix bug with ```import-from-derivation```:

```console
$ nix flake show
git+file:///home/fmaste/Workspace/GitHub/intersectmbo/cardano-node?ref=master&rev=2df4e4130685f27ad5d9d732b1df266b921c585f
├───apps
│   ├───x86_64-darwin
trace: To make project.plan-nix for cardano-node a fixed-output derivation but not materialized, set `plan-sha256` to the output of the 'calculateMaterializedSha' script in 'passthru'.
trace: To materialize project.plan-nix for cardano-node entirely, pass a writable path as the `materialized` argument and run the 'updateMaterialized' script in 'passthru'.
error: cannot build '/nix/store/hr1pq6y67nasklk1iw5ifxx3rizy1w8m-nix-tools-plan-to-nix-pkgs.drv' during evaluation because the option 'allow-import-from-derivation' is disabled
(use '--show-trace' to show detailed location information)
```

(Eelco hates ```import-from-derivation```, so it's a bug or a feature?)

To see all the buildable outputs, enter a Nix read–eval–print loop and load
the default ```flake.nix``` file to look at what's buildable as defined by the
```outputs.packages.x86_64-linux``` record. Or better look at the name of its
keys only with ```builtins.attrNames outputs.packages.x86_64-linux```:

```console
$ nix repl
...
...
:lf .
...
...
outputs.packages.x86_64-linux
...
...
builtins.attrNames outputs.packages.x86_64-linux
[ "all-profiles-json" "alonzo-purple/node" "alonzo-purple/submit-api" "bech32" "benchmarks/cardano-tracer/cardano-tracer-bench" "benchmarks/trace-dispatcher/trace-dispatcher-bench" "benchmarks/tx-generator/tx-generator-bench" "cabalProjectRegenerate" "cardano-cli" "cardano-node" "cardano-node-chairman" "cardano-ping" "cardano-submit-api" "cardano-testnet" "cardano-topology" "cardano-tracer" "chain-sync-client-with-ledger-state" "checkCabalProject" "checks/cardano-api/cardano-api-test" "checks/cardano-cli/cardano-cli-golden" "checks/cardano-cli/cardano-cli-test" "checks/cardano-node-chairman/chairman-tests" "checks/cardano-node/cardano-node-test" "checks/cardano-submit-api/unit" "checks/cardano-testnet/cardano-testnet-tests" "checks/cardano-tracer/cardano-tracer-test" "checks/hlint" "checks/nixosTests/cardanoNodeEdge" "checks/trace-dispatcher/trace-dispatcher-test" "checks/trace-forward/test" "checks/trace-resources/trace-resources-test" "checks/tx-generator/tx-generator-test" "db-analyser" "db-converter" "demo-acceptor" "demo-forwarder" "dockerImage/node" "dockerImage/node/load" "dockerImage/submit-api" "dockerImage/submit-api/load" "dockerImages/push" "ledger-state" "locli" "mainnet/node" "mainnet/submit-api" "marlowe-pioneers/node" "marlowe-pioneers/submit-api" "membenches" "p2p/node" "p2p/submit-api" "plutus-example" "scan-blocks" "scan-blocks-pipelined" "shelley_qa/node" "shelley_qa/submit-api" "sre/node" "sre/submit-api" "staging/node" "staging/submit-api" "stake-credential-history" "testnet/node" "testnet/submit-api" "tests/cardano-api/cardano-api-test" "tests/cardano-cli/cardano-cli-golden" "tests/cardano-cli/cardano-cli-test" "tests/cardano-node-chairman/chairman-tests" "tests/cardano-node/cardano-node-test" "tests/cardano-submit-api/unit" "tests/cardano-testnet/cardano-testnet-tests" "tests/cardano-tracer/cardano-tracer-test" "tests/trace-dispatcher/trace-dispatcher-test" "tests/trace-forward/test" "tests/trace-resources/trace-resources-test" "tests/tx-generator/tx-generator-test" "trace-dispatcher-examples" "tx-generator" ]
```

Exit the repl to build the node. Flake syntax is needed, the ```.#``` prefix:

```console
nix build .#mainnet/node
$ ls result/bin/
cardano-node-mainnet
```

### Start a cluster for local benchmarking

Inside the same folder, enter a ```nix-shell```. If it's the first time, be
prepared to load GBs of data and maybe for this to take 1 or 2 hours:

```console
$ nix-shell
...
...
copying path '/nix/store/9j0ncywa4vfmz250cgjqjshkbvlqdw2j-chain-part-000' from 'https://hydra.iohk.io'...
copying path '/nix/store/j1np1pwhkf6yg8d713vz4lsxhxl21jcs-chain-part-001' from 'https://hydra.iohk.io'...
copying path '/nix/store/pl83sp0ns00ml1l647vjjiwm6vanpjn9-chain-part-002' from 'https://hydra.iohk.io'...
copying path '/nix/store/vdmn9x2jza40b3gr1570qs2fg7rn4szb-chain-part-003' from 'https://hydra.iohk.io'...
copying path '/nix/store/zvq07cpmssm97d75llyp6z89089ffak6-chain-part-004' from 'https://hydra.iohk.io'...
copying path '/nix/store/15fh9wwghpzi9zzrwpnyj24l0sb6r9lg-chain-part-005' from 'https://hydra.iohk.io'...
copying path '/nix/store/nrm9abyinmk4lbxj0fw4bh2hvh1a2bf3-chain-part-006' from 'https://hydra.iohk.io'...
copying path '/nix/store/yi9ndzdlpmp6s5cw2xzla71lwq5awvsf-chain-part-007' from 'https://hydra.iohk.io'...
copying path '/nix/store/ql0dasymy1ja1j2avzz0f8i01w1dq7r6-chain-part-008' from 'https://hydra.iohk.io'...
copying path '/nix/store/iqn631jjqx5h7rhv7dmp9hhishbxb4xx-chain-part-009' from 'https://hydra.iohk.io'...
copying path '/nix/store/940kz5zrj1776mg146kmfijhw8dh577s-chain-part-010' from 'https://hydra.iohk.io'...
copying path '/nix/store/qkg15wlwrz5aqf9xcslrssly5lyqci3g-chain-part-011' from 'https://hydra.iohk.io'...
copying path '/nix/store/gxy58jsac72w0rnx52ld1b1qxyl5iwf2-chain-part-012' from 'https://hydra.iohk.io'...
copying path '/nix/store/2ynd4xwcap7dm1mvj5mn3pdbihf2gch8-chain-part-013' from 'https://hydra.iohk.io'...
copying path '/nix/store/3q0hzxn0cjqgc4nqxxdq96rlhqqpd9fr-chain-part-014' from 'https://hydra.iohk.io'...
copying path '/nix/store/1ikiypqcdw1mivn515bn8a80fw7k2vk8-chain-part-015' from 'https://hydra.iohk.io'...
copying path '/nix/store/268n3rcbj59ci96mhcia4snd38zar26s-chain-part-016' from 'https://hydra.iohk.io'...
copying path '/nix/store/6cdm8azmr7qv7vswwj4bm0jmh0n0yd11-chain-part-017' from 'https://hydra.iohk.io'...
copying path '/nix/store/dp6vhdf3vd0hhwlm918d6fb2y4m3w6h8-chain-part-018' from 'https://hydra.iohk.io'...
...
...
nix-shell top-level shellHook:  withHoogle=1 profileName=default-bage workbenchDevMode=
workbench shellHook:  workbenchDevMode= useCabalRun=1
workbench:  cabal-inside-nix-shell mode enabled, calling cardano-* via cabal run (instead of using Nix store)

  Commands:
    * nix flake lock --update-input <iohkNix|haskellNix> - update nix build input
    * cardano-cli - used for key generation and other operations tasks
    * wb - cluster workbench
    * start-cluster - start a local development cluster
    * stop-cluster - stop a local development cluster
    * restart-cluster - restart the last cluster run (in 'run/current')
                        (WARNING: logs & node DB will be wiped clean)
```

Inside the nix-shell with GNU make the requirements for the selected benchmark are created:

```console
$ make ci-test
...
...
$ start-cluster
...
...
```

You can use tab autocompletion to look for make targets.

`start-cluster` does:
```console
wb-wrapped start --batch-name plain --profile-name default-bage --profile /nix/store/f4f1cmvri35x0ynzh9zih4d6v32mcc5y-workbench-profile-output-default-bage --cache-dir /home/fmaste/.cache/cardano-workbench --base-port 30000 --cabal
```

And starts multiple cardano nodes as:
```console
/home/fmaste/Workspace/GitHub/intersectmbo/cardano-node/dist-newstyle/build/x86_64-linux/ghc-8.10.7/cardano-node-1.33.0/x/cardano-node/build/cardano-node/cardano-node +RTS -sghc-rts-report.txt -RTS run --config config.json --database-path run/current/node-5/db-testnet --topology topology.json --host-addr 127.0.0.1 --port 30005 --socket-path node.socket --tracer-socket-path-connect ../tracer/tracer.socket --shelley-vrf-key ../genesis/node-keys/node-vrf5.skey --shelley-kes-key ../genesis/node-keys/node-kes5.skey --shelley-operational-certificate ../genesis/node-keys/node5.opcert --shutdown-on-slot-synced 300 +RTS -N2 -I0 -A16m -qg -qb --disable-delayed-os-memory-return -RTS
```

## Infrastructure and code hierarchy

[[/images/workbench-dependencies.png|Workbench Nix dependency graph]]

We're currently not using docker or OCI at all, we're using plain regular
***NixOS services*** for the benchmarking infrastructure:

### Services

- [nix/nixos/cardano-node.service](https://github.com/intersectmbo/cardano-node/blob/master/nix/nixos/cardano-node-service.nix)
- [nix/nixos/cardano-tracer.service](https://github.com/intersectmbo/cardano-node/blob/master/nix/nixos/cardano-tracer-service.nix)
- [nix/nixos/tx-generator.service](https://github.com/intersectmbo/cardano-node/blob/master/nix/nixos/tx-generator-service.nix)

This services are used for running on three contexts:
1. AWS
2. local
3. CI

\* CI is intended to be exactly like local but wrapped into Nix derivations.

Looking at the code you can see how it does 1 (AWS) and 2 (local).

### Workbench

Workbench (Links are to master branch but there's a workbench-master branch):
1. [Top-level wb script](https://github.com/intersectmbo/cardano-node/blob/master/nix/workbench/wb)
   1. First thought: Why this scripts starts with ```#!/usr/bin/env bash```,
      shouldn't it be a ```/nix/store/sdfsjdlhflsdhflsdkjh```?
2. [Profile computation (profile.sh)](https://github.com/intersectmbo/cardano-node/blob/master/nix/workbench/profile/profile.sh)
3. [Run allocation & starting](https://github.com/intersectmbo/cardano-node/blob/master/nix/workbench/run.sh)
4. [Run scenarios](https://github.com/intersectmbo/cardano-node/blob/master/nix/workbench/scenario.sh)

### About profile computation

Profiles define everything benchmark runs:
- topology
- genesis (protocol parameters and data set sizes)
- workload (tx generation)
- scenario

> From those fundamentals, follow the service configs (```cardano-node```,
> ```cardano-tracer```, ```tx-generator```)
> All of that is an output of profile computation

Configuration generation does heavy use of [jq](https://stedolan.github.io/jq/) and [yq](https://mikefarah.gitbook.io/yq/).

#### ```profiles.json```

[```workbench/default.nix```](https://github.com/intersectmbo/cardano-node/blob/master/nix/workbench/default.nix) has the Nix derivation that calls the profile builder:
```
...
## materialise-profile :: ProfileNix -> BackendProfile -> Profile
materialise-profile      = import ./profile.nix  { inherit pkgs lib; };
...
profile = materialise-profile
  { inherit profileNix workbench;
    backendProfile = backend.materialise-profile { inherit profileNix; };
  };
```
and [```workbench/profile.nix```](https://github.com/intersectmbo/cardano-node/blob/master/nix/workbench/profile/profile.nix) does at the end:
```
''
mkdir $out
cp ${profileNix.JSON}    $out/profile.json
cp ${backendProfile}/*   $out
cp $nodeServicesPath     $out/node-services.json
cp $generatorServicePath $out/generator-service.json
cp $tracerServicePath    $out/tracer-service.json
wb profile node-specs $out/profile.json > $out/node-specs.json
''
```
after importing [```workbench/default.nix```](https://github.com/intersectmbo/cardano-node/blob/master/nix/workbench/default.nix).

The only thing ```wb``` needs is the profile outputs as they are created by [```workbench/profiles/default.nix```](https://github.com/intersectmbo/cardano-node/blob/master/nix/workbench/default.nix).

### Modes

There are two modes
- workbenchDevMode = true: ```./nix/workbench/shell.nix``` defines the ```wb``` script.
- workbenchDevMode = false: Here ```wb``` comes from the nix store.

### Membench

Membench is currently disabled. It was used to run a single benchmark that did:
1. Take a prepared ImmutableDB
2. Take a prepared snapshot, near but not exactly at the end of that ImmutableDB
3. Sart the node with this -- so it loads the snapshot, and then replays the portion of ImmutableDB after the point of snapshot
4. Exit after reaching the end of ImmutableDB
5. ..and record all process stats for the entire node run

Membench runs with not workbench involvement at all.

## Others

### Building docker stuff

```console
$ nix build .#dockerImage/node
$ ls -la result
lrwxrwxrwx 1 fmaste fmaste 76 Jun  3 13:16 result -> /nix/store/mlm3sca8knf7hkl424rp22j8qj61m3hz-docker-image-cardano-node.tar.gz
```

```console
$ nix build .#dockerImage/node/load
$ ls -la result
lrwxrwxrwx 1 fmaste fmaste 61 Jun  3 13:38 result -> /nix/store/93y90jvl14xav2jy0mc492sga0fwkzrn-load-docker-image
```

```console

```

### Building benchmark stuff

```console
nix build .#benchmarks/cardano-tracer/cardano-tracer-bench
$ ls result/bin
cardano-tracer-bench
$ ls result/share/doc/x86_64-linux-ghc-8.10.7/cardano-tracer-0.1.0/
LICENSE
```

```console
$ nix build .#benchmarks/trace-dispatcher/trace-dispatcher-bench
$ ls result/bin/
trace-dispatcher-bench
```

```console
$ nix build .#benchmarks/tx-generator/tx-generator-bench
$ ls result/bin/
tx-generator-bench
$ ls result/share/doc/x86_64-linux-ghc-8.10.7/tx-generator-2.2/
LICENSE  NOTICE
$ ls result/share/x86_64-linux-ghc-8.10.7/tx-generator-2.2/data/
protocol-parameters.json
``

```console
$ cat result/share/x86_64-linux-ghc-8.10.7/tx-generator-2.2/data/protocol-parameters.json
{
    "txFeePerByte": 44,
    "minUTxOValue": null,
    "decentralization": 0,
    "utxoCostPerWord": 34482,
    "stakePoolDeposit": 500000000,
    "poolRetireMaxEpoch": 18,
    "extraPraosEntropy": null,
    "collateralPercentage": 150,
    "stakePoolTargetNum": 500,
    "maxBlockBodySize": 65536,
    "minPoolCost": 340000000,
    "maxTxSize": 16384,
    "treasuryCut": 0.2,
    "maxBlockExecutionUnits": {
        "memory": 50000000,
        "steps": 40000000000
    },
    "maxCollateralInputs": 3,
    "maxValueSize": 5000,
    "maxBlockHeaderSize": 1100,
    "maxTxExecutionUnits": {
        "memory": 10000000,
        "steps": 10000000000
    },
    "costModels": {
        "PlutusScriptV1": {
            "cekConstCost-exBudgetMemory": 100,
            "unBData-cpu-arguments": 150000,
            "divideInteger-memory-arguments-minimum": 1,
            "nullList-cpu-arguments": 150000,
            "cekDelayCost-exBudgetMemory": 100,
            "appendByteString-cpu-arguments-slope": 621,
            "sha2_256-memory-arguments": 4,
            "multiplyInteger-cpu-arguments-intercept": 61516,
            "iData-cpu-arguments": 150000,
            "equalsString-cpu-arguments-intercept": 150000,
            "trace-cpu-arguments": 150000,
            "lessThanEqualsByteString-cpu-arguments-intercept": 103599,
            "encodeUtf8-cpu-arguments-slope": 1000,
            "equalsString-cpu-arguments-constant": 1000,
            "blake2b-cpu-arguments-slope": 29175,
            "consByteString-memory-arguments-intercept": 0,
            "headList-cpu-arguments": 150000,
            "listData-cpu-arguments": 150000,
            "divideInteger-cpu-arguments-model-arguments-slope": 118,
            "divideInteger-memory-arguments-slope": 1,
            "bData-cpu-arguments": 150000,
            "chooseData-memory-arguments": 32,
            "cekBuiltinCost-exBudgetCPU": 29773,
            "mkNilData-memory-arguments": 32,
            "equalsInteger-cpu-arguments-intercept": 136542,
            "lengthOfByteString-cpu-arguments": 150000,
            "subtractInteger-cpu-arguments-slope": 0,
            "unIData-cpu-arguments": 150000,
            "sliceByteString-cpu-arguments-slope": 5000,
            "unMapData-cpu-arguments": 150000,
            "modInteger-cpu-arguments-model-arguments-slope": 118,
            "lessThanInteger-cpu-arguments-intercept": 179690,
            "appendString-memory-arguments-intercept": 0,
            "mkCons-cpu-arguments": 150000,
            "sha3_256-cpu-arguments-slope": 82363,
            "ifThenElse-cpu-arguments": 1,
            "mkNilPairData-cpu-arguments": 150000,
            "constrData-memory-arguments": 32,
            "lessThanEqualsInteger-cpu-arguments-intercept": 145276,
            "addInteger-memory-arguments-slope": 1,
            "chooseList-memory-arguments": 32,
            "equalsData-memory-arguments": 1,
            "decodeUtf8-cpu-arguments-intercept": 150000,
            "bData-memory-arguments": 32,
            "lessThanByteString-cpu-arguments-slope": 248,
            "listData-memory-arguments": 32,
            "consByteString-cpu-arguments-intercept": 150000,
            "headList-memory-arguments": 32,
            "subtractInteger-memory-arguments-slope": 1,
            "appendByteString-memory-arguments-intercept": 0,
            "unIData-memory-arguments": 32,
            "remainderInteger-memory-arguments-minimum": 1,
            "lengthOfByteString-memory-arguments": 4,
            "encodeUtf8-memory-arguments-intercept": 0,
            "cekStartupCost-exBudgetCPU": 100,
            "remainderInteger-memory-arguments-slope": 1,
            "multiplyInteger-memory-arguments-intercept": 0,
            "cekForceCost-exBudgetCPU": 29773,
            "unListData-memory-arguments": 32,
            "sha2_256-cpu-arguments-slope": 29175,
            "indexByteString-memory-arguments": 1,
            "equalsInteger-memory-arguments": 1,
            "remainderInteger-cpu-arguments-model-arguments-slope": 118,
            "cekVarCost-exBudgetCPU": 29773,
            "lessThanEqualsInteger-cpu-arguments-slope": 1366,
            "addInteger-memory-arguments-intercept": 1,
            "sndPair-cpu-arguments": 150000,
            "lessThanInteger-memory-arguments": 1,
            "cekLamCost-exBudgetCPU": 29773,
            "chooseUnit-cpu-arguments": 150000,
            "decodeUtf8-cpu-arguments-slope": 1000,
            "fstPair-cpu-arguments": 150000,
            "quotientInteger-memory-arguments-minimum": 1,
            "lessThanEqualsInteger-memory-arguments": 1,
            "chooseUnit-memory-arguments": 32,
            "fstPair-memory-arguments": 32,
            "quotientInteger-cpu-arguments-constant": 148000,
            "mapData-cpu-arguments": 150000,
            "unConstrData-cpu-arguments": 150000,
            "mkPairData-cpu-arguments": 150000,
            "sndPair-memory-arguments": 32,
            "decodeUtf8-memory-arguments-slope": 8,
            "equalsData-cpu-arguments-intercept": 150000,
            "addInteger-cpu-arguments-intercept": 197209,
            "modInteger-memory-arguments-intercept": 0,
            "cekStartupCost-exBudgetMemory": 100,
            "divideInteger-cpu-arguments-model-arguments-intercept": 425507,
            "divideInteger-memory-arguments-intercept": 0,
            "cekVarCost-exBudgetMemory": 100,
            "consByteString-memory-arguments-slope": 1,
            "cekForceCost-exBudgetMemory": 100,
            "unListData-cpu-arguments": 150000,
            "subtractInteger-cpu-arguments-intercept": 197209,
            "indexByteString-cpu-arguments": 150000,
            "equalsInteger-cpu-arguments-slope": 1326,
            "lessThanByteString-memory-arguments": 1,
            "blake2b-cpu-arguments-intercept": 2477736,
            "encodeUtf8-cpu-arguments-intercept": 150000,
            "multiplyInteger-cpu-arguments-slope": 11218,
            "tailList-cpu-arguments": 150000,
            "appendByteString-cpu-arguments-intercept": 396231,
            "equalsString-cpu-arguments-slope": 1000,
            "lessThanEqualsByteString-cpu-arguments-slope": 248,
            "remainderInteger-cpu-arguments-constant": 148000,
            "chooseList-cpu-arguments": 150000,
            "equalsByteString-memory-arguments": 1,
            "constrData-cpu-arguments": 150000,
            "cekApplyCost-exBudgetCPU": 29773,
            "equalsData-cpu-arguments-slope": 10000,
            "decodeUtf8-memory-arguments-intercept": 0,
            "modInteger-memory-arguments-slope": 1,
            "addInteger-cpu-arguments-slope": 0,
            "appendString-cpu-arguments-intercept": 150000,
            "quotientInteger-cpu-arguments-model-arguments-slope": 118,
            "unMapData-memory-arguments": 32,
            "cekApplyCost-exBudgetMemory": 100,
            "quotientInteger-memory-arguments-slope": 1,
            "mkNilPairData-memory-arguments": 32,
            "ifThenElse-memory-arguments": 1,
            "equalsByteString-cpu-arguments-slope": 247,
            "sliceByteString-memory-arguments-slope": 1,
            "sha3_256-memory-arguments": 4,
            "mkCons-memory-arguments": 32,
            "verifySignature-cpu-arguments-intercept": 3345831,
            "cekBuiltinCost-exBudgetMemory": 100,
            "remainderInteger-memory-arguments-intercept": 0,
            "lessThanEqualsByteString-memory-arguments": 1,
            "mkNilData-cpu-arguments": 150000,
            "equalsString-memory-arguments": 1,
            "chooseData-cpu-arguments": 150000,
            "remainderInteger-cpu-arguments-model-arguments-intercept": 425507,
            "tailList-memory-arguments": 32,
            "sha2_256-cpu-arguments-intercept": 2477736,
            "multiplyInteger-memory-arguments-slope": 1,
            "iData-memory-arguments": 32,
            "divideInteger-cpu-arguments-constant": 148000,
            "cekDelayCost-exBudgetCPU": 29773,
            "encodeUtf8-memory-arguments-slope": 8,
            "subtractInteger-memory-arguments-intercept": 1,
            "nullList-memory-arguments": 32,
            "lessThanByteString-cpu-arguments-intercept": 103599,
            "appendByteString-memory-arguments-slope": 1,
            "blake2b-memory-arguments": 4,
            "unBData-memory-arguments": 32,
            "cekConstCost-exBudgetCPU": 29773,
            "consByteString-cpu-arguments-slope": 1000,
            "trace-memory-arguments": 32,
            "quotientInteger-memory-arguments-intercept": 0,
            "mapData-memory-arguments": 32,
            "verifySignature-cpu-arguments-slope": 1,
            "quotientInteger-cpu-arguments-model-arguments-intercept": 425507,
            "modInteger-cpu-arguments-constant": 148000,
            "appendString-cpu-arguments-slope": 1000,
            "unConstrData-memory-arguments": 32,
            "mkPairData-memory-arguments": 32,
            "equalsByteString-cpu-arguments-constant": 150000,
            "equalsByteString-cpu-arguments-intercept": 112536,
            "sliceByteString-memory-arguments-intercept": 0,
            "lessThanInteger-cpu-arguments-slope": 497,
            "verifySignature-memory-arguments": 1,
            "cekLamCost-exBudgetMemory": 100,
            "sliceByteString-cpu-arguments-intercept": 150000,
            "modInteger-cpu-arguments-model-arguments-intercept": 425507,
            "modInteger-memory-arguments-minimum": 1,
            "appendString-memory-arguments-slope": 1,
            "sha3_256-cpu-arguments-intercept": 0
        }
    },
    "protocolVersion": {
        "minor": 0,
        "major": 5
    },
    "txFeeFixed": 155381,
    "stakeAddressDeposit": 2000000,
    "monetaryExpansion": 3.0e-3,
    "poolPledgeInfluence": 0.3,
    "executionUnitPrices": {
        "priceSteps": 7.21e-5,
        "priceMemory": 5.77e-2
    }
}
```
