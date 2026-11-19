## Unable to build on ARM64

When building `cardano-node` on `arm64`, the following error may occur:

```
[ 9 of 14] Compiling Cardano.Logging.Tracer.Standard ( src/Cardano/Logging/Tracer/Standard.hs, /src/cardano-node/dist-newstyle/build/aarch64-linux/ghc-8.10.4/trace-dispatcher-1.29.0/build/Cardano/Logging/Tracer/Standard.o, /src/cardano-node/dist-newstyle/build/aarch64-linux/ghc-8.10.4/trace-dispatcher-1.29.0/build/Cardano/Logging/Tracer/Standard.dyn_o )
src/Cardano/Logging/Tracer/Standard.hs:9:1: error: [-Wdeprecations, -Werror=deprecations]
    Module `Control.Concurrent.Chan.Unagi.Bounded':
      This library is unlikely to perform well on architectures without a fetch-and-add instruction
  |
9 | import           Control.Concurrent.Chan.Unagi.Bounded
  | ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
src/Cardano/Logging/Tracer/Standard.hs:73:26: error: [-Wdeprecations, -Werror=deprecations]
    In the use of `newChan'
    (imported from Control.Concurrent.Chan.Unagi.Bounded):
    "This library is unlikely to perform well on architectures without a fetch-and-add instruction"
   |
73 |     (inChan, outChan) <- newChan 2048
   |                          ^^^^^^^
```

When this happens ensure the `cabal.project.local` file exists in the `cardano-node` project root directory and contains the following lines:

```
package trace-dispatcher
  ghc-options: -Wwarn
```

## `cabal` is unable to find `libsodium` via `pkg-config` on MacOS

When the following error occurs:

```
Warning: Requested index-state 2022-10-19T00:00:00Z is newer than
'cardano-haskell-packages'! Falling back to older state
(2022-10-17T00:00:00Z).
Resolving dependencies...
Error: cabal: Could not resolve dependencies:
[__0] trying: cardano-api-1.36.0 (user goal)
[__1] next goal: cardano-crypto-class (dependency of cardano-api)
[__1] rejecting: cardano-crypto-class-2.0.0.1 (constraint from project config
/Users/jky/wrk/iohk/cardano-node/cabal.project requires <2.0.0.1)
[__1] rejecting: cardano-crypto-class-2.0.0 (conflict: pkg-config package
libsodium-any, not found in the pkg-config database)
[__1] fail (backjumping, conflict set: cardano-api, cardano-crypto-class)
After searching the rest of the dependency tree exhaustively, these were the
goals I've had most trouble fulfilling: cardano-api, cardano-crypto-class
```

It is possible that `libsodium` is installed correctly, but some other unrelated brew installed package has a corrupt `pc` file.

See https://github.com/haskell/cabal/issues/8494#issuecomment-1273802608 for details.  The offending `pc` file will need to be patched or its package uninstalled.

## Delegated stake is not earning rewards

There are a number of reasons you may not be earning rewards.  Check for the following things to ensure the testnet is set up properly:

* `d` parameter above zero: Check protocol parameters
* Pool makes blocks: There's a forge adopted metric on prometheus exporter built-in to node. One could also check logs.
* Pool meets pledge: This can be checked via `ledgerState.nesES.esLState._delegationState._pstate._pParams.<POOL_ID>._poolPledege` in the ledger dump. To get the owners' stake (to see if they meet the pledge, get the key hashes from `ledgerState.nesES.esLState._delegationState._pstate._pParams.<POOL_ID>._poolOwners`. Then maybe use the CLI to get the stake associated with each owner, and sum them.
* Rho above zero: check protocol parameters
* Reserves above zero (total supply > sum of all utxo).  Check for `ledgerState.nesES.esAccountState._reserves` in the ledger state.

## Missing blocks

This section was taken from the [private IOG wiki](https://input-output.atlassian.net/wiki/spaces/QA/pages/2368897711/Debug+missing+blocks).

### How do you know that your pool did not produce a block when it was selected as a Slot Leader?

* `cardano_node_metrics_Forge_forge_about_to_lead_int - cardano_node_metrics_Forge_node_not_leader_int  != 0`

* `cardano_node_metrics_Forge_could_not_forge_int!= 0`

* you see a block scheduled for your pool (using a leader scheduler based on your vrf key - like cncli tool) but the pool does not create it and none of the above metrics are updated (like the pool did not know that it had a block assigned)

  * check the submitted vrf keys in the pool registration certificate

  * check the cold.counter was correctly increased based on the previous one 

    * in this case, you can increase/generate the counter multiple times in order to make sure the current counter is higher than the previous one that created the last block

    * if the submitted cold.counter is lower than the previous one that created a block, you should see the below error in logs:

```
Invalid block aa98999f126e90cdcf441db2ac818fe14c196efbf3e74b2fd07f0f91ddb281ba at slot 21351198: ExtValidationErrorHeader (HeaderProtocol
Error (HardForkValidationErrFromEra S (S (S (Z (WrapValidationErr {unwrapValidationErr = ChainTransitionError [OverlayFailure (OcertFailure (CounterTooSmallOCERT 12 0))]}))))))

fromList [("val",Object (fromList [("kind",String "TraceForgedInvalidBlock"),("reason",Object (fromList [("error",Object (fromList [("err
or",Object (fromList [("failures",Array [Object (fromList [("currentKESCounter",String "0"),("error",String "The operational certificate's last KES counter is greater than the current
 KES counter."),("kind",String "CounterTooSmallOCert"),("lastKESCounter",String "12")])]),("kind",String "ChainTransitionError")])),("kind",String "HeaderProtocolError")])),("kind",St
ring "ValidationError")])),("slot",Number 2.1351198e7)])),("credentials",String "Cardano")]
```

### What to look for:

* check the Producer logs - here we should see if the node tried to create any block

* check the Relay’s logs - here we should see if the relays propagated the block

* the Pledge is respected (you can check it in adapools.org)

  * if the pledge is not respected, the pool will create blocks but it will not receive rewards

* the KES keys are still valid 

* the actual cold.counter value is higher than the last counter number that created the last block

* the CPU and RAM levels

* the producer being in sync with the relays around the time of the slot/block

* check that a block was created by any other pool in the expected slot_number (on https://adapools.org/blocks) → if a block was adopted by the blockchain in the expected slot_number, but it was created by a different pool, that means that there was a slot battle (more pools selected as leaders for that slot) and other pool owned

* check the logs of the 3 nodes around the time of the expected slot_no

  * check if there are any mentions of CannotForge 

### Useful debug commands

* check that you are using the correct `cold.vkey` file → this should return the pool ID 

```
cardano-cli stake-pool id  \
    --cold-verification-key-file cold.vkey
```

* check the Kes and Cold vkeys used inside the `pool_operational.cert`

  * top bytes is `kes.vkey`

  * bottom bytes is `cold.vkey`

  * the first int is counter, the second int is kes period

```
cardano-cli text-view decode-cbor \
    --in-file pool_operational.cert
```

* check the VRF keys

```
cardano-cli node key-hash-VRF \
    --verification-key-file vrf.vkey
```

```
cardano-cli key verification-key \
    --signing-key-file vrf.skey \
    --verification-key-file vrf.vkey
```

* check the KES keys

```
cardano-cli key verification-key \
    --signing-key-file kes.skey \
    --verification-key-file /dev/stdout
```

* check the on-chain version number of the cold.counter 

```
cardano-cli query protocol-state --mainnet|jq ".csProtocol[0].\"$(cardano-cli stake-pool id --cold-verification-key-file node1-cold.vkey --output-format hex)\""
```

```
cardano-cli query protocol-state --mainnet | \
  jq ”.csProtocol[0].\”$(cat stakepoolid.txt)\””
```

### Open questions:

#### how to find, at the node level, the slots the node was elected to lead and what the node did during those slots?

leadership schedule per epoch will be added to the node CLI

#### how to find the keys used in the pool registration certificate?

* the above commands might provide some help
* we requested to have the key details printed on logs when starting the node

#### how to find the actual cold.counter value (and make sure you increment it correctly when renewing the KES)

check the above example 

#### what is the value of the node performance - get this value directly from the node (CLI or logs)?

a node should in theory be able to calculate its actual performance based on slots it was assigned to be able to compare that to the performance reported by the ledger for the ranking

