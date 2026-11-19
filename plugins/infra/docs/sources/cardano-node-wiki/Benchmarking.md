This page describes the complete benchmarking procedure.

## Bench Deployer Access

First of all, please make sure you have access to the `bench-deployer` host by typing this command on your computer:

```
$ ssh bench
```

You will be logged in as `dev@bench-deployer`.

## `cardano-ops` Repository

Also, please make sure you have access to [cardano-ops](https://github.com/input-output-hk/cardano-ops) repository. You need it to be able to push into the `bench-master` branch, which is used for benchmarking deployments.

## Working on Bench Deployer: Main Rules

Now log in to `bench-deployer` server using `ssh bench` command.

**IMPORTANT**: Please remember that all actions on `bench-deployer` server must always be performed inside the dedicated `screen` session. So first of all, run `screen -x` command to join that session.

There are important `screen`-windows we need:

1. `bench-0` - for running benchmarks on **small** clusters.
2. `bench-1` - for running benchmarks on **big** (real-world) clusters.
3. `bench-2` - for running benchmarks on **small** clusters.
4. `workbench-1` - for running **analyzing** of benchmarks results.

To move between `screen`-windows, use following key combinations: `(Ctrl+A)+P` (to the right) or `(Ctrl+A)+N` (to the left).

**IMPORTANT**: do not use `exit` command in the `screen`-window! Instead, just close your terminal window, to keep `screen`-window working.

By default, when you switch to some `screen`-window, you are in `nix-shell`. If you exited from it, it's possible to go back inside `nix-shell` using `nsh` command.

## Benchmarking: 3 steps

From the most general point of view, the task of benchmarking task can be decomposed into 3 big steps:

1. Preparing the profile for the benchmark.
2. Running the benchmark on the cluster.
3. Analyzing benchmark results.

## Defining new benchmarking profiles

Each benchmark is completely specified by a **profile** -- which is a set of parameters that specify all of its particular details.

To see a list of profiles available on the `bench-0` cluster, switch to `screen`-window `bench-0` and run the following command:

```
$ b ps   ## Short-hand for `bench list-profiles`
```

The command `b` stands for "benchmark", it's the basic entry point for benchmarking orchestration.

You will see the list of long names, for example:

```
--( 2022-03-10T10:29:41+00:00:  ps
--( NIXOPS_DEPLOYMENT:  bench-0 (inherited)
                                                                                      smoke: 
                                                                                smoke-epoch: 
                                                                          smoke-dense-large: 
                                                                           smoke-large-1000: 
                                                                           smoke-large-5000: 
 k2-5ep-360kTx-4000kU-1000kD-64kbs-10MUTx-10BStTx-50MUBk-40BStBk-always-succeeds-spending-0: Plutus return-success
             k2-5ep-7.5kTx-4000kU-1000kD-64kbs-10MUTx-10BStTx-50MUBk-40BStBk-1i-1o-sum-3304: Plutus, 1e10-cpu
            k2-5ep-0.08kTx-4000kU-1000kD-64kbs-10MUTx-10BStTx-50MUBk-40BStBk-1i-1o-sum-3304: Plutus, 1e10-cpu smoke
             k2-5ep-7.5kTx-4000kU-1000kD-64kbs-10MUTx-10BStTx-50MUBk-40BStBk-1i-1o-sum-1144: Plutus, 1e7-mem
                k2-5ep-0.1kTx-4000kU-1000kD-64kbs-10MUTx-10BStTx-50MUBk-40BStBk-1i-1o--null: Plutus, auto-mode-smoke-test
                 k2-7ep-14kTx-4000kU-1000kD-64kbs-10MUTx-10BStTx-50MUBk-40BStBk-1i-1o--null: Plutus, baseline
                 k2-7ep-14kTx-4000kU-1000kD-73kbs-11MUTx-10BStTx-50MUBk-40BStBk-1i-1o--null: Plutus, bump 1, Dec 2 2021
                 k2-7ep-14kTx-4000kU-1000kD-73kbs-12MUTx-10BStTx-50MUBk-40BStBk-1i-1o--null: Plutus, bump 2, 2022
                                                          k2-5ep-360kTx-7000kU-1250kD-80kbs: regression, March 2022 data set sizes
                                                          k2-5ep-360kTx-4000kU-1000kD-64kbs: regression, October 2021 data set sizes
                                      k2-5ep-360kTx-4000kU-1000kD-64kbs-RTS--H4G-M6553M-c70: rtsflags: batch1, best CPU/mem
                                          k2-5ep-360kTx-4000kU-1000kD-64kbs-RTS--H4G-M6553M: rtsflags: batch1, better mem, costlier CPU
                                                 k2-5ep-360kTx-4000kU-1000kD-64kbs-RTS--A4m: rtsflags: cache fitting
                                              k2-5ep-360kTx-4000kU-1000kD-64kbs-RTS--A4m-N4: rtsflags: cache fitting + higher parallelism
                                                 k2-5ep-360kTx-4000kU-1000kD-64kbs-RTS--A1m: rtsflags: cache fitting extreme
                                              k2-5ep-360kTx-4000kU-1000kD-64kbs-RTS--A1m-N4: rtsflags: cache fitting extreme + parallelism
                                                 k2-5ep-360kTx-4000kU-1000kD-64kbs-RTS--A2m: rtsflags: cache fitting hard
                                              k2-5ep-360kTx-4000kU-1000kD-64kbs-RTS--A2m-N4: rtsflags: cache fitting hard + parallelism
                                  k2-5ep-360kTx-4000kU-1000kD-64kbs-RTS--C0-A32m-n1m-AL512M: rtsflags: suggestion from PR 3399
```

These long names are the names of available profiles. For example, `k2-5ep-360kTx-7000kU-1250kD-80kbs` is the name of profile, and `regression, March 2022 data set sizes` is its description.

Now clone `cardano-ops` repository, go to it, switch to `bench-master` branch and find `bench/profile-definitions.jq` file. This file describes existing profiles. Find `utxo_delegators_density_profiles` function with this `desc` inside:

```
{ desc: "regression, March 2022 data set sizes"
, genesis: { utxo:           7000000
           , delegators:     1250000
           , max_block_size: 80000
           }
}
```

As you can see, here we specify a profile that can be used on `bench-deployer` server.

All the numbers are described below.

## Benchmarking Profiles

The name of each profile is generated automatically and contains profile's main parameters. For example, compare the name `k2-5ep-360kTx-7000kU-1250kD-80kbs` with its description in `bench/profile-definitions.jq` file:

```
{ desc: "regression, March 2022 data set sizes"
, genesis: { utxo:           7000000
           , delegators:     1250000
           , max_block_size: 80000
           }
}
```

Here you can see the following numbers that are specific for this profile:

1. `7000kU` means that `utxo` is `7000000`,
2. `1250kD` means that `delegators` is `1250000`,
3. `80kbs` means that `max_block_size` is `80000` bytes.

Other numbers in profile's name are default ones. For example, `5ep` means that tx generator will work during `5` epochs, and `360kTx` means that tx generator will generate `360k` transactions.

### Profile Groups

As you can see, there are 3 big groups of profiles:

1. with word `regression` - default profiles,
2. with word `rtsflags` - like default profiles, but with specific RTS flags,
3. with word `Plutus` - profiles with smart contracts.

## Benchmark Run

Suppose you want to run a benchmark using a profile from our example, `k2-5ep-360kTx-7000kU-1250kD-80kbs`. Go to `bench-deployer` server, switch to `bench-0` window and run the command:

```
$ git log
```

Make sure you are on the commit of `bench-master` branch you want to use, and the branch has a clean status.

After that, run the command:

```
$ b reinit
```

And then, you are ready to run a benchmark:

```
$ b p training origin/master k2-5ep-360kTx-7000kU-1250kD-80kbs
```

Here you can see the following arguments:

1. `p` means "profile", so we want to run a benchmark with particular profile.
2. `training` is a batch name we use to describe this benchmark.
3. `origin/master` is a commit spec for `cardano-node` repository, here we want to take the latest commit from the `master` branch. It's possible to use a commit hash as well.
4. `k2-5ep-360kTx-7000kU-1250kD-80kbs` is a profile name.

The benchmark will be launched. The following line shows the current profile:

```
--( benchmarking profile:  k2-5ep-360kTx-7000kU-1250kD-80kbs, batch training, node baa9b5e59c5d448d475f94cc88a31a5857c2bda5 (origin/master)
```

If the genesis for this profile does not exist yet, you will see this line:

```
--( generating genesis due to miss:  k2-d1-1250kD-7000kU-84cb500 @ ../geneses/k2-d1-1250kD-7000kU-84cb500
```

But if the corresponding genesis already exists, the line will differ:

```
--( genesis cache hit:  k2-d1-1250kD-7000kU-84cb500
```

Then, you will see the following lines:

```
--( deploying profile k2-5ep-360kTx-7000kU-1250kD-80kbs
--(   era:           alonzo
--(   topology:      dense
--(   node:          baa9b5e59c5d448d475f94cc88a31a5857c2bda5 / origin/master
--(   ops:           9c42c56104742c591bb5f2867efaa6b61d03dc58 / bench-master  (modified)
--(   generator:     {"add_tx_size":100,"init_cooldown":45,"inputs_per_tx":2,"outputs_per_tx":2,"tx_fee":1000000,"tps":9,"era":"alonzo","tx_count":360000}
--(   genesis:       {.......}
--(   node:          {"rts_flags_override":[]}
--( hosts to deploy:  4 total:  explorer node-0 node-1 node-2
--( that's deployable in one go -- blasting ahead
``` 

These lines describe deploying details. As you see, this small cluster has 4 hosts, including `explorer` node where tx generator is working.

### Benchmark Finish

After some time, you will see the following lines:

```
--( Mon 07 Mar 2022 07:14:44 PM UTC, termination condition satisfied, stopping cluster.
--( run directory:  /home/dev/bench-0/runs/...
...
```

It means that benchmarking is finished and the cluster is stopped. The run directory is the path with all the data relative to this run: cluster params, genesis, configs, nodes' logs, etc. 

## Benchmark Analyze: Run

After the benchmark is finished, you want to analyze its results. To do it, switch to `workbench-1` window and use the command `wb`. This is an example:

```
$ wb --cls a --filters size-full std 2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs
```

where:

1. `--cls` means "clear screen",
2. `a` means "analyse",
3. `--filters size-full` means "filter full blocks",
4. `2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs` is full id of benchmark: `TIMESTAMP.BATCH.COMMIT.PROFILENAME`.

You will see something like this:

```
...
processing ../bench-1/runs/2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs/analysis/logs-node-0.flt.json
processing ../bench-1/runs/2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs/analysis/logs-node-10.flt.json
processing ../bench-1/runs/2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs/analysis/logs-node-11.flt.json
processing ../bench-1/runs/2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs/analysis/logs-node-12.flt.json
processing ../bench-1/runs/2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs/analysis/logs-node-13.flt.json
...
```

And finally:

```
...
{ "pretty-timeline": "../bench-1/runs/2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs/analysis/block-propagation.txt" }
...
{ "pretty-timeline": "../bench-1/runs/2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs/analysis/logs-node-1.timeline.txt"  }
...
```

## Benchmark Analyze: Results

After `wb` is finished, you can find the `analysis` directory in `run directory`. For example, `~/bench-1/runs/2022-03-07-04.05.160222.cc1e.k51-5ep-360kTx-4000kU-1000kD-64kbs/analysis`.

This directory contains two files you need:

1. `logs-node-1.timeline.txt`
2. `block-propagation.txt`

These files contain [CDF](https://en.wikipedia.org/wiki/Cumulative_distribution_function) data which can be used to form the results like these ones:

```
|                       | 1.34.0-rc3 | ledger-bump |    Δ |  Δ% |
|-----------------------+------------+-------------+------+-----|
| Avg process CPU usage |         39 |          46 |    7 |  15 |
| Avg RTS GC CPU usage  |         24 |          29 |    5 |  17 |
| Avg RTS Mut CPU usage |         16 |          17 |    1 |   6 |
| Avg RSS               |       5120 |        4850 | -270 |  -6 |
| Avg RTS heap          |       5090 |        4820 | -270 |  -6 |
| Avg RTS GC live bytes |       2095 |        1820 | -275 | -15 |
|-----------------------+------------+-------------+------+-----|
#+TBLFM: $4=$3-$2::$5=round(100*$4/$3)
```

```
|                                   | 1.34.0-rc3 | ledger-bump |  Δ |  Δ% |
|-----------------------------------+------------+-------------+----+-----|
| average leadership check Δt       |         41 |          49 |  8 |  20 |
| average leadership check duration |          5 |          20 | 15 | 300 |
| average forge time                |         68 |         113 | 45 |  66 |
| average adoption time             |         65 |          58 | -7 | -11 |
| average time to announce          |          1 |           1 |  0 |   0 |
| average time to start sending     |         27 |          36 |  9 |  33 |
|-----------------------------------+------------+-------------+----+-----|
|                                   |        207 |         277 | 70 |  34 |
#+TBLFM: @>$2=vsum(@I..@II)::@>$3=vsum(@I..@II)::$4=$3-$2::$5=round(100*$4/$2)
```

```
|                               | 1.34.0-rc3 | ledger-bump |   Δ | Δ% |
|-------------------------------+------------+-------------+-----+----|
| average first time to notice  |        496 |         618 | 122 | 25 |
|-------------------------------+------------+-------------+-----+----|
| average time to request       |         12 |          18 |   6 | 50 |
| average time to fetch         |        370 |         358 | -12 | -3 |
| average adoption time         |         63 |          67 |   4 |  6 |
| average time to announce      |          1 |           1 |   0 |  0 |
| average time to start sending |        137 |         131 |  -6 | -4 |
|-------------------------------+------------+-------------+-----+----|
|                               |        583 |         575 |  -8 | -1 |
#+TBLFM: @>$2=vsum(@II..@III)::@>$3=vsum(@II..@III)::$4=$3-$2::$5=round(100*$4/$2)
```

```
 %tile   0.50  0.80  0.90  0.92  0.94  0.96  0.98  1.00
1.34.0-rc3---------------------------------------------
  0.5    0.8   1.1   1.16  1.17  1.18  1.19  1.21  1.25
  0.9    1.43  1.92  2.14  2.18  2.25  2.3   2.38  2.65
  1.0   36.16 40.89 44.57 50.96 50.96 51.22 57.57 70.26
  avg   0.965 1.380 1.491 1.529 1.574 1.618 1.698 1.965
1.34.0-rc3---------------------------------------------
  0.5    0.71  1.08  1.13  1.14  1.15  1.16  1.17  1.2
  0.9    1.3   1.69  1.91  1.98  2.04  2.12  2.2   2.51
  1.0   43.56 57.03 62.97 63.36 66.21 66.63 69.57 79.51
  avg   0.935 1.356 1.455 1.484 1.511 1.547 1.587 1.770
lehins/ledger-bump-------------------------------------
  0.5    0.83  1.13  1.18  1.19  1.19  1.2   1.22  1.26
  0.9    1.46  1.87  2.11  2.15  2.23  2.34  2.44  2.75
  1.0   55.75 71.94 83.88 84.51 84.89 87.69 92.82 99.08
  avg   1.051 1.489 1.645 1.681 1.720 1.766 1.835 2.055
```

## Benchmark Analyze: Examples

There are real-life examples of benchmarking results.

### `block-propagation.txt`

```
                --- Forger event Δt: ---                --- Peer event Δt: ---               Slot-rel. Δt to adoption centile:          Size   
 %tile  Checkd Leadin Forge  Adopt  Announ Sendin Notic Reque Fetch Adopt Annou Send  0.50  0.80  0.90  0.92  0.94  0.96  0.98  1.00    bytes  
  0.0     0      0      0    0.02   -0.02    0    0.02   0     0     0   -7.46   0    0.05  0.05  0.05  0.05  0.05  0.05  0.05  0.05     63359
 0.01     0      0      0    0.02     0      0    0.06   0    0.01  0.01   0     0    0.19  0.24  0.26  0.26  0.27  0.27  0.27  0.31     63369
 0.05     0      0    0.03   0.02     0      0    0.09   0    0.01  0.02   0    0.01  0.49  0.87  0.9   0.91  0.92  0.93  0.93  0.97     63373
  0.1     0      0    0.03   0.02     0      0    0.12   0    0.02  0.02   0    0.01  0.5   0.88  0.92  0.93  0.94  0.95  0.96  0.99     63377
  0.2     0      0    0.03   0.02     0    0.01   0.17   0    0.03  0.02   0    0.01  0.52  0.9   0.95  0.96  0.97  0.98  0.99  1.03     63381
  0.3     0      0    0.03   0.03     0    0.01   0.22   0    0.05  0.02   0    0.02  0.53  1.05  1.09  1.1   1.11  1.12  1.12  1.16     63383
  0.4     0      0    0.03   0.03     0    0.01   0.26   0    0.21  0.03   0    0.02  0.55  1.07  1.11  1.12  1.13  1.14  1.15  1.18     63385
  0.5     0      0    0.03   0.03     0    0.01   0.3    0    0.28  0.03   0    0.03  0.75  1.08  1.13  1.14  1.14  1.16  1.17  1.2      63389
  0.6     0      0    0.04   0.03     0    0.02   0.34   0    0.5   0.03   0    0.04  0.89  1.1   1.15  1.16  1.16  1.17  1.19  1.23     63391
  0.7     0      0    0.05   0.04     0    0.02   0.39   0    0.6   0.03   0    0.07  0.92  1.18  1.26  1.29  1.31  1.33  1.36  1.54     63393
 0.75     0      0    0.06   0.04     0    0.03   0.45   0    0.61  0.04   0    0.1   0.93  1.28  1.37  1.4   1.43  1.46  1.52  1.89     63395
  0.8     0      0    0.06   0.05     0    0.03   0.55  0.01  0.65  0.04   0    0.12  1.06  1.39  1.51  1.57  1.62  1.69  1.79  2.09     63395
 0.85     0      0    0.07   0.05     0    0.03   0.73  0.01  0.73  0.05   0    0.2   1.16  1.54  1.72  1.76  1.82  1.9   1.98  2.28     63397
 0.875  0.01     0    0.08   0.06     0    0.04   0.88  0.01  0.75  0.05   0    0.21  1.24  1.63  1.82  1.9   1.94  2.02  2.1   2.38     63399
  0.9   0.01     0    0.08   0.06     0    0.04   1.04  0.01  0.76  0.06   0    0.23  1.34  1.74  1.94  1.97  2.06  2.13  2.21  2.47     63399
 0.925  0.06     0    0.09   0.06     0    0.05   1.21  0.01  0.77  0.06   0    0.26  1.46  1.88  2.06  2.1   2.18  2.24  2.32  2.57     63401
 0.95   0.42     0     0.1   0.07     0    0.05   1.4   0.01  0.8   0.07  0.01  0.28  1.66  2.07  2.23  2.27  2.32  2.41  2.48  2.75     63403
 0.97   0.62   0.01   0.11   0.08     0    0.06   1.62  0.01  0.82  0.07  0.01  0.34  1.9   2.28  2.41  2.45  2.48  2.53  2.61  3.05     63405
 0.98   0.77   0.01   0.15   0.09   0.01   0.07   1.8   0.01  1.07  0.08  0.01  0.5   2.06  2.4   2.58  2.59  2.66  2.74  2.85  3.39     63407
 0.99   0.87   0.01   1.08   0.53   0.01    0.1   2.18  0.02  1.38  0.48  0.01  1.06  2.34  2.68  2.85  3.02  3.09  3.24  3.85  4.59     63409
 0.995  0.92   0.01   1.34    1.6   0.02   0.22   3.01  0.03  1.56  1.29  0.02  1.32  6.79  6.79 12.36 12.43 16.78 16.84 16.95 18.91     63413
 0.997  0.93   0.02   3.37   2.84   0.02   1.06  11.84  0.08  1.67  4.05  0.02  1.59 18.61 19.71 22.74 22.84 22.92 23.34 23.46  23.8     63415
 0.998  0.94   0.67   3.72   3.07   0.03   2.09  17.65  2.52  1.74  4.25  0.02  2.09 18.69  22.4  23.2  23.3 23.42 23.43  23.6 27.02     63415
 0.999  0.98    2.3   3.83   4.84   0.03   2.31  25.06  4.06  1.83  6.04  0.03  4.92 35.16  41.9 47.48 47.48 50.64 50.64 51.51 60.11     63415
0.9995  0.99   2.38   3.87   5.13   0.04   2.92  30.52  5.7   1.9   7.85  0.04 11.78 38.28 48.22   54   54.1  54.9 57.51  61.5 74.23     63417
0.9997  0.99   2.38   3.87   5.13   0.04   2.92  35.97  6.69  1.96  8.97  0.09 17.66 38.28 48.22   54   54.1  54.9 57.51  61.5 74.23     63417
0.9998  0.99   2.38   3.87   5.13   0.04   2.92  38.01  7.54  2.04 10.01  0.51 25.23 38.28 48.22   54   54.1  54.9 57.51  61.5 74.23     63417
0.9999  0.99   2.38   3.87   5.13   0.04   2.92  38.97 10.27  2.57 13.07  1.1  31.42 38.28 48.22   54   54.1  54.9 57.51  61.5 74.23     63417
  1.0   0.99   2.53   3.93   6.16   0.06   2.92   51.3 14.09  7.5  31.39  2.96 57.79 38.69 49.65 55.43  57.4 61.08  61.3 68.26 84.76     63419
```

Let's explore how to extract some valuable data from it.

```
            --- Peer event Δt: --- 
 %tile  ... Reque Fetch Adopt Annou Send    
  0.0         0    0     0    -7.46   0    
  ... 
  0.5   ...   0    0.28  0.03   0    0.03 
  ...
0.9999  ... 10.27  2.57 13.07  1.1  31.42
```

The percentile in the left column shows the distribution. Here you can see that 50% of blocks were sent to all peers in 30 ms, but in the worst cases it took 31.42 s. And 50% of block adoption took 30 ms, but in the worst cases it took 13.07 s. 

```
                --- Forger event Δt: ---                   
 %tile  Checkd Leadin Forge  Adopt  Announ Sendin    
  0.0     0      0      0    0.02   -0.02    0        
  ...   
  0.5     0      0    0.03   0.03     0    0.01   
  ... 
0.9999  0.99   2.38   3.87   5.13   0.04   2.92   
```

Here you can see that 50% of block forging took 30 ms, but in the worst cases it took 3.83 s.

### `logs-node-1.timeline.txt`

```
        Miss   ---- Δt ----   Block Dens  CPU GC  MUT GC flt  Memory usage, MB  AllocCPU85% spans
 %tile ratio Check Lead  Forge gap   ity   %   %   %  Maj Min  RSS  Heap  Live   MB    All  EBnd 
  0.0   0.0   0     0    0.03    0 0.017   0   0   0   0   0  4332  4298  1333     0     0   148
 0.01   0.0   0     0    0.03    0 0.024   0   0   0   0   0  4332  4298  1341     0     0   148
 0.05   0.0   0     0    0.03    1 0.028   0   0   0   0   0  4332  4298  1380     0     9   148
  0.1   0.0   0     0    0.03    2 0.031   0   0   0   0   0  4526  4493  1411     0    10   148
  0.2   0.0   0     0    0.03    4 0.035   0   0   0   0   0  4858  4825  1557     0    11   148
  0.3   0.0   0     0    0.03    7 0.039   1   0   1   0   0  4886  4853  1836     0    11   148
  0.4   0.0   0     0    0.03   10 0.043   1   0   1   0   0  4887  4853  1943     0    12   148
  0.5   0.0   0     0    0.04   14 0.047   1   0   1   0   0  4915  4882  1957     0    12   174
  0.6   0.0   0     0    0.04   19 0.051   2   0   2   0   1  4915  4882  2228    31    13   174
  0.7   0.0   0     0    0.07   25 0.057 100  38  14   0   7  5390  5358  2519   240    14   174
 0.75   0.0   0     0    0.07   29 0.060 100  49  22   0  21  5391  5358  2649   668    14   174
  0.8   0.0   0     0    0.07   34 0.064 101  57  39   0  37  5391  5358  2660  1148    14   174
 0.85   0.0   0     0    0.08   39 0.068 101  63  45   0  46  5391  5358  2669  1378    15   174
 0.875  0.0  0.01   0    0.08   43 0.072 101  79  50   0  49  5391  5358  2672  1468    15   174
  0.9   0.0  0.01   0    0.09   48 0.076 101  83  54   0  55  5391  5358  2676  1872    15   174
 0.925  0.0  0.13   0    0.09   54 0.081 102  87  62   1  61  5391  5358  2683  2170    15   174
 0.95   0.0  0.39   0    0.1    63 0.088 105  91  66   1  68  5391  5358  2702  2561    15   174
 0.97   0.0  0.61  0.01  0.1    77Here you can see that 60% of the time GC wasn't performed at all but 0.1% of the time 100% of CPU time was spent for GC actions.
 0.093 117  93  76   1  73  5391  5358  2718  2795    15   174
 0.98   0.0  0.73  0.01  0.1    88 0.097 125  94  85   1  78  5391  5358  2724  2973    16   174
 0.99   1.0  0.85  0.01  0.1   106 0.105 137  96  98   1  81  5391  5358  2747  3080    16   174
 0.995  1.0  0.91  1.81  0.1   124 0.112 150  98 111   1  84  5391  5358  2794  3139    18   174
 0.997  1.0  0.94  2.2   0.1   145  0.12 157  98 120   1  85  5391  5358  2847  3168    33   174
 0.998  1.0  0.96  2.34  0.1   158 0.121 163  99 125   1  86  5391  5358  2904  3192    83   174
 0.999  1.0  0.97  3.02  0.1   171  0.15 169 100 137   1  87  5391  5358  2966  3225   147   174
0.9995  1.0  0.98  3.45  0.1   187 0.155 177 100 154   1  87  5391  5358  2990  3246   173   174
0.9997  1.0  0.99  3.57  0.1   195 0.155 182 100 161   1  88  5391  5358  3025  3260   173   174
0.9998  1.0  0.99  3.64  0.1   199 0.155 185 100 173   1  88  5391  5358  3046  3266   173   174
0.9999  1.0  0.99  4.35  0.1   203 0.155 187 100 175   1  89  5391  5358  3096  3273   173   174
  1.0   1.0   1    6.48  1.11  207 0.155 188 100 178   1  91  5391  5358  3400  3338   211   212
  avg  0.01 0.041 0.013 0.080 20.9 0.051 37. 22. 15. 0.0 13. 5016. 4983. 2087. 468.1 12.62 178.0
```

Let's explore how to extract some valuable data from it.

```
        ...  CPU ...
 %tile  ...   %  
  0.0   ...   0   
  ...   
  0.6   ...   2    
  0.7   ... 100
  ...   
```

The percentile in the left column shows the distribution. Here you can see that 60% of the time only 2% CPU was used.

```
        ...  GC ...
 %tile  ...   %  
  0.0   ...   0   
  ...     
  0.6   ...   0
  0.7   ...  38
  ...
 0.999  ... 100
  ...
```

Here you can see that 60% of the time GC wasn't performed at all but 0.1% of the time 100% of CPU time was spent for GC actions.

```
 %tile  ...  Block ...
              gap     
  0.0   ...     0   
  ...     
  0.5   ...    14
  ...
 0.9999 ...   203
  ...
```

Here you can see that 50% of the time block gap was 14 seconds or less, but in the worst cases, there were no blocks during 203 s.

## Benchmark Analyze: Release

Usually, during the preparation of the node's release, we want to benchmark it. Final results should be placed in the following tables.

**Resource Usage**

```
|                       | 1.34.0-rc3 | 5f8d |    Δ |   Δ% | 
|-----------------------+------------+------+------+------|
| Avg process CPU usage |         39 |   44 |    5 |   12 |  
| Avg RTS GC CPU usage  |         24 |   28 |    4 |   17 |   
| Avg RTS Mut CPU usage |         16 |   16 |    0 |    0 |   
| Avg RSS               |       5120 | 5135 |   15 |  0.3 | 
| Avg RTS heap          |       5090 | 5060 |  -30 | -0.6 | 
| Avg RTS GC live bytes |       2095 | 1688 | -407 |  -19 | 
|-----------------------+------------+------+------+------|
```

**Forger (all times in milliseconds)**

```
|                                   | 1.34.0-rc3 | 5f8d |   Δ |  Δ% | 
|-----------------------------------+------------+------+-----+-----|
| average leadership check Δt       |         41 |   54 |  13 |  32 |   
| average leadership check duration |          5 |   22 |  17 | 340 |   
| average forge time                |         68 |  137 |  69 | 101 |  
| average adoption time             |         65 |   75 |  10 |  15 |   
| average time to announce          |          1 |    2 |   1 |  50 |   
| average time to start sending     |         27 |   36 |   9 |  33 |   
|-----------------------------------+------------+------+-----+-----|
|                                   |        207 |  326 | 119 |     | 
```
 
**Peers (all times in milliseconds)**

```
|                               | 1.34.0-rc3 | 5f8d |   Δ |   Δ% |  
|-------------------------------+------------+------+-----+------|
| average first time to notice  |        496 |  671 | 175 |   35 | 
|-------------------------------+------------+------+-----+------|
| average time to request       |         12 |   25 |  13 |  108 |   
| average time to fetch         |        370 |  360 | -10 |   -3 |   
| average adoption time         |         63 |   85 |  22 |   35 |   
| average time to announce      |          1 |    0 |  -1 | -100 |    
| average time to start sending |        137 |  122 | -15 |  -11 | 
|-------------------------------+------------+------+-----+------|
|                               |        583 |  592 |   9 |      |
```

**Slot-rel. Δt to adoption centile**

```
 %tile   0.50  0.80  0.90  0.92  0.94  0.96  0.98  1.00
1.34.0-rc3---------------------------------------------
  0.5    0.8   1.1   1.16  1.17  1.18  1.19  1.21  1.25
  0.9    1.43  1.92  2.14  2.18  2.25  2.3   2.38  2.65
  1.0   36.16 40.89 44.57 50.96 50.96 51.22 57.57 70.26
  avg   0.965 1.380 1.491 1.529 1.574 1.618 1.698 1.965
1.34.0-rc3---------------------------------------------
  0.5    0.71  1.08  1.13  1.14  1.15  1.16  1.17  1.2
  0.9    1.3   1.69  1.91  1.98  2.04  2.12  2.2   2.51
  1.0   43.56 57.03 62.97 63.36 66.21 66.63 69.57 79.51
  avg   0.935 1.356 1.455 1.484 1.511 1.547 1.587 1.770
5f8d---------------------------------------------------
  0.5    0.88  1.17  1.22  1.23  1.24  1.25  1.27  1.32   
  0.9    1.74  2.19  2.39  2.46  2.52  2.6   2.68  2.95    
  1.0   53.92 68.52  78.8 83.35 86.06  88.6 99.83 103.2
  avg   1.132 1.579 1.705 1.746 1.795 1.840 1.920 2.161  
```

Here `1.34.0-rc3` is a (pre)release we want to compare with, and `5f8d` is the node's commit we want to benchmark. The essence of the release benchmarking is always a comparison: we want to compare some new node's code with some old node's code.

So:

1. Data for **Resource Usage** should be taken from `logs-node-1.timeline.txt`.
2. Data for **Forger** should be taken from `block-propagation.txt`, from `Forger event Δt -> Checkd Leadin Forge Adopt Announ Sendin`.
3. Data for **Peers** should be taken from `block-propagation.txt`, from `Peer event Δt -> Reque Fetch Adopt Annou Send`.