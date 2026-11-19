# Status

📜 Proposed 2024-09-10

# Context

There is no way to check a node configuration file for basic sanity issues. This is a problem for people running testnets, because they will only discover _after having started their testnet_ that something is wrong (because the node will refuse to start). And starting a testnet is a costly operation, meaning the failures will only happen after tenth of seconds; causing the feedback loop to be slow.

# Decision

## Add a new command in the CLI

Introduce a new command in `cardano-cli` that takes a node configuration file as parameter and performs sanity checks:

1. The configuration file can be loaded.
2. Paths of genesis files are specified.
3. Hashes of genesis files are specified and are correct.

## Alternatives considered

### Provide a fixup option

We considered having a flag that would make `check-node-configuration`:

1. Fill the hashes of genesis files if missing
2. Fix the hashes of genesis files if present but wrong

However, in the end, we favored having a pure command (i.e. a command that doesn't modify things) so we ruled such a fixup flag.

### Have `create-testnet-data` create the node configuration file

We considered having `create-testnet-data` create a default node configuration file, and populating it with the paths and hashes of genesis files. This could have been nice to users, but it is complicated to implement, because most of the types for the node configuration file live in `cardano-node`, as for example the `NodeConfiguration` type which lives in [cardano-node/src/Cardano/Node/Configuration/POM.hs](https://github.com/IntersectMBO/cardano-node/blob/ef5f0a9ed52d969b3753c96955add25b9e08f02d/cardano-node/src/Cardano/Node/Configuration/POM.hs#L87). The `NodeConfig` type which we have in `cardano-api` (see [cardano-api/internal/Cardano/Api/LedgerState.hs](https://github.com/IntersectMBO/cardano-api/blob/4dde2e65c496f989f079354f407e7617563f4bc7/cardano-api/internal/Cardano/Api/LedgerState.hs#L1048)) for the node configuration file is not general enough to create a full-fledged node configuration file.

However, moving the `NodeConfiguration` type and its accompanying types to `cardano-api` is a large endeavor, which was not given priority yet. It is a large endeavor for two reasons: `NodeConfiguration` has many fields of different types and it is quite different from `NodeConfig`. `NodeConfig` contains the bare minimum needed for API specific operations: it is mostly concerned with genesis files and their hashes.

# Consequences

This will allow users of testnets to check their node configuration file before starting their testnet, and so they will catch errors earlier and faster.

# Related ADRs

- [ADR-007](ADR-007-CLI-Output-Presentation) — CLI output conventions (stdout vs stderr) apply to this command.
