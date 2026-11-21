# Creating Cardano testnets

In [Shelley genesis](shelley-genesis.md) we discussed how to manually create a Shelley blockchain
and how to create a testnet semi-automatically using the `cardano-cli genesis create` command. That explainer
did not cover the steps needed to create a testnet that starts in the Byron era and is updated to the latest
era. This process requires a fair amount of manual work: converting genesis and delegate keys from Byron to
Shelley, creating genesis files, handling file hashing, manually updating the configuration file, etc.

Creating a testnet that starts in Byron and can transition to Shelley and later eras is possible with the
`cardano-cli genesis create-cardano` command. Note that on mainnet, we need to use the manual method
described in [Shelley genesis](shelley-genesis.md).

The `create-cardano` command automatically generates the Byron, Shelley and Alonzo genesis files, including
the needed genesis keys, delegate keys, and UTXO keys. This command also handles all the hashing and
generates the configuration file for the node.

The `create-cardano` command also requires us to provide template files for the node configuration file,
Byron genesis, Shelley genesis and Alonzo genesis. These template files contain the parameters needed for
the testnet, all eras, and the configuration file for the nodes. You can find template files in the
[iohk-nix repository](https://github.com/input-output-hk/iohk-nix/tree/master/cardano-lib/testnet-template)
and adjust them to your needs.

By calling help for `create-cardano`, you will see the needed parameters:

```bash
$ cardano-cli genesis create-cardano

--genesis-dir DIR        The genesis directory containing the genesis template
                         and required genesis/delegation/spending keys.
--gen-genesis-keys INT   The number of genesis keys to make [default is 3].
--gen-utxo-keys INT      The number of UTXO keys to create [default is 0].
--start-time UTC-TIME    The genesis start time in YYYY-MM-DDThh:mm:ssZ
                         format. If unspecified, will be the current time +30
                         seconds.
--supply LOVELACE        The initial coin supply in lovelace which will be
                         evenly distributed across initial, non-delegating
                         stake holders.
--security-param INT     Security parameter for the genesis file [default is 108].
--slot-length INT        Slot length (ms) parameter for genesis file [default
                         is 1000].
--slot-coefficient RATIONAL
                         Slot coefficient for the genesis file [default is .05].
--mainnet                Use the mainnet magic ID.
--testnet-magic NATURAL  Specify a testnet magic ID.
--byron-template FILEPATH
                         JSON file with genesis defaults for each Byron.
--shelley-template FILEPATH
                         JSON file with genesis defaults for each Shelley.
--alonzo-template FILEPATH
                         JSON file with genesis defaults for each Alonzo.
--node-config-template FILEPATH
                         The node config template

```

There are also a few things to consider:

* The _maximum supply_ is hardcoded to 45 billion ada (like on mainnet). The amount in `--supply` is distributed evenly across initial UTXO keys. The difference between 45 billion and `--supply` will be available on the _Reserves_ when updating to the Shelley era.

* `--slot-length`, `--security-param` and `--slot-coefficient` together determine the epoch length on the resulting network. Byron epochs last _10k_ slots, and Shelley epochs last _10k/f_ slots. Where _k_ is the security parameter and _f_ is the slot coefficient.

### Example

For a network with three genesis keys, three delegate nodes, two non-delegated UTXO keys with five billion each and 10 minutes epochs, run:

```bash
$ cardano-cli genesis create-cardano \
--genesis-dir cluster \
--gen-genesis-keys 3 \
--gen-utxo-keys 2 \
--supply 10000000000000000 \
--security-param 300 \
--slot-length 100 \
--slot-coefficient 5/100 \
--testnet-magic 42 \
--byron-template byron.json \
--shelley-template shelley.json \
--alonzo-template alonzo.json \
--node-config-template config.json
```

This creates the following:

* The 'cluster' directory
* Byron, Shelley and Alonzo genesis files
* The node configuration file
* Three Byron era genesis keys
* Three Shelley era genesis keys (converted from Byron keys)
* Three delegate Byron keys
* Three delegation certificates
* Three operational certificates and operational certificate counters
* Three cold, KES, and VRF keys
* Two Byron era non-delegated UTXO keys
* Two Shelley era UTXO keys (converted from Byron keys)

```bash
$ tree cluster/
cluster/
├── alonzo-genesis.json
├── byron-genesis.json
├── delegate-keys
│   ├── byron.000.cert.json
│   ├── byron.000.key
│   ├── byron.001.cert.json
│   ├── byron.001.key
│   ├── byron.002.cert.json
│   ├── byron.002.key
│   ├── shelley.000.counter.json
│   ├── shelley.000.kes.skey
│   ├── shelley.000.kes.vkey
│   ├── shelley.000.opcert.json
│   ├── shelley.000.skey
│   ├── shelley.000.vkey
│   ├── shelley.000.vrf.skey
│   ├── shelley.000.vrf.vkey
│   ├── shelley.001.counter.json
│   ├── shelley.001.kes.skey
│   ├── shelley.001.kes.vkey
│   ├── shelley.001.opcert.json
│   ├── shelley.001.skey
│   ├── shelley.001.vkey
│   ├── shelley.001.vrf.skey
│   ├── shelley.001.vrf.vkey
│   ├── shelley.002.counter.json
│   ├── shelley.002.kes.skey
│   ├── shelley.002.kes.vkey
│   ├── shelley.002.opcert.json
│   ├── shelley.002.skey
│   ├── shelley.002.vkey
│   ├── shelley.002.vrf.skey
│   └── shelley.002.vrf.vkey
├── genesis-keys
│   ├── byron.000.key
│   ├── byron.001.key
│   ├── byron.002.key
│   ├── shelley.000.skey
│   ├── shelley.000.vkey
│   ├── shelley.001.skey
│   ├── shelley.001.vkey
│   ├── shelley.002.skey
│   └── shelley.002.vkey
├── node-config.json
├── shelley-genesis.json
└── utxo-keys
   ├── byron.000.key
   ├── byron.001.key
   ├── shelley.000.skey
   ├── shelley.000.vkey
   ├── shelley.001.skey
   └── shelley.001.vkey

4 directories, 53 files
```

Starting the cluster requires topology files for each of the nodes. For example:

```JSON
{
   "Producers": [
     {
       "addr": "127.0.0.1",
       "port": 3001,
       "valency": 1
     },
     {
       "addr": "127.0.0.1",
       "port": 3002,
       "valency": 1
     }
   ]
 }
```
Note: For details about topology files please refer to [Configuring a node](configuring-a-node-using-yaml.md).


Then, run the nodes with block production keys, for example:

```bash
$ cardano-node run \
--config node-config.json \
--topology topology.json \
--database-path db \
--socket-path node.socket \
--port 3000 \
--delegation-certificate delegate-keys/byron.000.cert.json \
--signing-key delegate-keys/byron.000.key
```

Updating the testnet to later eras can be done using update proposals, please refer to [Cardano governance](./cardano-governance.md) to learn how to do it.
