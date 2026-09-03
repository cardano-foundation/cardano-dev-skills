This document provides a step-by-step example of how to work with [`demo-acceptor`](https://github.com/intersectmbo/cardano-node/blob/master/cardano-tracer/demo/acceptor.hs).

## What is it?

As you know, `trace-forward` library provides a new mini-protocol for working with `DataPoint`s. And `demo-acceptor` is a small application allowing to ask for arbitrary `DataPoint`. This application is mostly for demonstration/testing if the node provides a particular `DataPoint` or not. If so - its value will be printed out to stdout once per second.

## `cardano-node`: configuration

Since `DataPoint`s are provided by the new tracing infrastructure, please make sure it's enabled in the node's configuration. Open the configuration file and set `UseTraceDispatcher` to `true`. Also, make sure that `TraceOptionForwarder` section contains valid values, for example:

```
"TraceOptionForwarder": {
    "address": {"filePath": "/tmp/forwarder.sock"},
    "mode" : "Initiator",
    "queueSize" : 1000,
    "verbosity" : "Maximum"
}
```

## `demo-acceptor`: building

Since `demo-acceptor` is a part of `cardano-tracer` project, run this command in order to build it:

```
$ cabal build cardano-tracer
```

Also, you can build it directly:

```
$ cabal build exe:demo-acceptor
```

As a result, `demo-acceptor` will be built.

## `demo-acceptor`: running

Now you can run `demo-acceptor` (it is assumed that you are in the directory with `demo-acceptor` in it):

```
$ ./demo-acceptor /tmp/forwarder.sock Responder NodeInfo
```

where:

1. `/tmp/forwarder.sock` is the path to the local socket. Please make sure it equals the path in `TraceOptionForwarder.address.filePath` from the node's configuration.
2. `Responder` is a network mode for `demo-acceptor`. Currently, it's `Responder`, so `TraceOptionForwarder.mode` from the node's configuration must be `Initiator`.
3. `NodeInfo` is the name of `DataPoint` we want to ask.

## Examples of `DataPoint`s

After you ran `demo-acceptor` and `cardano-node`, you will see such output for `NodeInfo`:

```
DataPoint, name: NodeInfo, raw value: {"niName":"nixos","niCommit":"36bbbae36026dc8dc370b598b061f67ed97008b9","niStartTime":"2022-03-15T18:11:14.412855063Z","niVersion":"1.33.0","niSystemStartTime":"2017-09-23T21:44:51Z","niProtocol":"Byron; Shelley"}
...
``` 

And this is an example of output for `NodeState`:

```
DataPoint, name: NodeState, raw value: {"contents":{"tag":"StartedOpeningImmutableDB"},"tag":"NodeOpeningDbs"}
DataPoint, name: NodeState, raw value: {"contents":{"tag":"StartedOpeningVolatileDB"},"tag":"NodeOpeningDbs"}
DataPoint, name: NodeState, raw value: {"contents":"InitChainStartedSelection","tag":"NodeInitChainSelection"}
DataPoint, name: NodeState, raw value: {"contents":"InitChainSelected","tag":"NodeInitChainSelection"}
DataPoint, name: NodeState, raw value: {"contents":"InitChainSelected","tag":"NodeInitChainSelection"}
DataPoint, name: NodeState, raw value: {"contents":[26,20668,0],"tag":"NodeAddBlock"}
DataPoint, name: NodeState, raw value: {"contents":[26,21014,0],"tag":"NodeAddBlock"}
...
```

As you can see, `demo-acceptor` is displaying received `DataPoint` as a raw `ByteString`. This was made for simplicity: in this case, `demo-acceptor` shouldn't know an actual Haskell type of `DapaPoint`, so it can ask for _any_ `DataPoint` provided by `cardano-node`.