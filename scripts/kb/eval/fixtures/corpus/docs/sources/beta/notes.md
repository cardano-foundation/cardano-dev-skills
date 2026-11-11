# Harbor design notes

Background notes for people who maintain Harbor.

## Release process

Releases are cut from the main branch after the checklist is complete.

## Install via package manager

On Linux distributions the harbor package can be installed with the system package manager.

## Architecture

Harbor stores messages in partitions and replicates each partition to two peers.

## Partitions

A queue maps to a fixed number of partitions chosen at creation time.

## Replication

A write is acknowledged once two replicas have stored it.

## Leader election

Each partition elects a leader using a lease that expires after ten seconds.

## Failure modes

A lost leader is replaced after its lease expires; messages are not lost.

## Storage format

Messages are appended to segment files and compacted in the background.

## Compaction

Compaction removes acknowledged messages and rewrites live ones.

## Retention

Unacknowledged messages are kept for four days before they expire.

## Clock assumptions

Lease logic assumes clock drift stays below one second between nodes.

## Design history

The first prototype used a single node with a write ahead log.

## Rejected ideas

Exactly once delivery was rejected because of its coordination cost.

## Benchmarks

A three node cluster sustains about twenty thousand messages per second.

## Test strategy

Unit tests cover the partition logic and soak tests exercise failure injection.

## Fuzzing

A fuzzer feeds malformed frames to the network layer on every commit.

## Documentation style

Pages use short sections with one idea each and runnable examples.

## Glossary

A segment is a file of appended messages; a lease is a timed leadership claim.

## Open questions

Cross region replication and per message delay are still undecided.

## Contributors

The project is maintained by volunteers and welcomes small focused changes.

## License

Harbor is released under a permissive open source license.
