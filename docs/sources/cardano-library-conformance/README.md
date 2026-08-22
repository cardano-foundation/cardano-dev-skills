# Cardano library conformance

This repository provides pinned, executable interface and behavioral
conformance checks for Cardano libraries. Conformance is organized by
capability domain: each new Cardano developer skill contributes a new domain,
with its own evidence, examples, and cross-library validation, while the
repository keeps one root Nix flake as the unified gate.

At a hard fork, the heavy cardano-ledger/cardano-api reference checks move
first and define the new era's target behavior. Floating runs across the other
surfaces then show, cell by cell and PR by PR, which libraries have caught up:
a falsifiable era-readiness dashboard when the ecosystem needs it most.

## Domains

| Domain | Capability | Evidence |
|---|---|---|
| [`balance-fixpoint`](balance-fixpoint/README.md) | Bounded transaction balancing when outputs or redeemers depend on the candidate transaction | 30 light interface checks, one documentation-drift check, four light worked-example checks, two runtime cross-validations, and three heavy Haskell checks |

The first domain retains its original check names for compatibility. Future
domains should prefix check names with their domain when ambiguity is possible.

## Run the conformance gate

```sh
nix flake check
```

The default gate is intentionally light. Build the upstream unit suite and the
two GHC 9.12.3 examples separately:

```sh
nix build --accept-flake-config .#heavy-checks
```

The flake declares the IOG binary cache. For a machine-wide equivalent:

```nix
extra-substituters = https://cache.iog.io
extra-trusted-public-keys = hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=
```

`flake.lock` fixes all upstream sources. See each domain README for its claim
map, falsification protocol, floating-drift commands, and known limits.
