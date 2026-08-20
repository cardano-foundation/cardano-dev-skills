# Roadmap

Where this repository is going. Each goal states the outcome, not a
schedule. Tracking status is stated honestly: only one goal currently has
a tracking issue, the rest are recorded intent.

## Tier-2 behavioral conformance: devnet submission

Today the examples converge offline and the `crossval-*` checks re-derive
the applicable ledger rules from the produced bytes. Tier 2 submits each
example's converged transaction to a devnet and asserts node acceptance,
riding the existing lambdasistemi devnet harness rather than growing a new
one. Acceptance by a real node is the strongest available behavioral
evidence for the balance-fixpoint claims.

*Tracked:* [lambdasistemi/cardano-lib-conformance#2](https://github.com/lambdasistemi/cardano-lib-conformance/issues/2)

## Examples as reusable functions

Each worked example becomes a self-contained, copy-paste-complete function
plus its test, with the code inlined into a per-stack page rather than only
linked as a source file. The target consumer is mechanical: a bundling
fetcher pulling documentation into a corpus, and any agent whose only tool
is `grep`, must be able to reach a complete working loop from the page text
alone.

*Implemented:* all six worked stacks now expose a bounded reusable function,
inline their complete source on a per-stack page, and share a light drift check
that compares each page with its real source file.

## Registration as a cardano-dev-skills documentation source

Once the repository stabilizes, register it as a documentation source for
`cardano-dev-skills`. The balance-transaction-at-fixpoint skill then cites these pages
from the bundled corpus and slims its own version pins, since the pins and
their evidence live here and are re-checked by the gate.

*Status:* intent, no tracking issue.

## Scalus example upgrade to runtime

`example-scalus-diffhandler` is compile-only: the published ledger POM has
eight direct runtime dependencies plus enough transitive artifacts to
exceed the ten-jar direct-pinning cutoff used in this bundle. The goal is a
runtime example that emits CBOR like the CSL and cardano-client-lib ones,
so the cross-validation tier applies to Scalus too.

*Status:* recorded as planned work in the domain README; no separate issue.

## Hard-fork instrument

At each era transition the repository becomes an era-readiness instrument.
The order is fixed: bump the heavy reference-implementation tier first,
then floating-run the remaining surfaces. The published result is a lag
view — which surfaces already carry the new era's capability shape and
which do not. Library cells flip by PR, with a check as proof; nothing
flips on assertion alone.

*Status:* intent, no tracking issue.

## New domains

Each new Cardano developer skill contributes a conformance domain, with its
own evidence, examples, and cross-library validation, under the same root
Nix flake gate. `balance-fixpoint` is domain #1; it retains its original
check names for compatibility, and future domains prefix their check names
with the domain when ambiguity is possible.

*Status:* intent, no tracking issue.
