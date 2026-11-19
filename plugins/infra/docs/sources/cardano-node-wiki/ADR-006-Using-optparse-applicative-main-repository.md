# Status

 ❌ Rejected 2025-11-06

# Context

In 2021, we (the API and CLI team) wanted to improve the pretty printing of `optparse-applicative`,
so that it aligns most flags vertically. E.g. we wanted this behavior:

```
Usage: cardano-cli transaction build-raw
            [ --byron-era
            | --shelley-era
            | --allegra-era
            | --mary-era
            | --alonzo-era
            ]
            ( --tx-in TX-IN
              [ --tx-in-script-file FILE
                [ (--tx-in-datum-file FILE | --tx-in-datum-value JSON VALUE)
                  ( --tx-in-redeemer-file FILE
                  | --tx-in-redeemer-value JSON VALUE
                  )
                  --tx-in-execution-units (INT, INT)
                ]
              ]
            )
            [--tx-in-collateral TX-IN]
```

instead of the default - less readable - behavior:

```
Usage: cardano-cli transaction build-raw [--byron-era | --shelley-era |
                                           --allegra-era | --mary-era |
                                           --alonzo-era] (--tx-in TX-IN
                                         [--tx-in-script-file FILE
                                           [
                                             (--tx-in-datum-file FILE |
                                               --tx-in-datum-value JSON VALUE)
                                             (--tx-in-redeemer-file FILE |
                                               --tx-in-redeemer-value JSON VALUE)
                                             --tx-in-execution-units (INT, INT)]])
                                         [--tx-in-collateral TX-IN]
```

Sadly the [PR we proposed](https://github.com/pcapriotti/optparse-applicative/pull/428#issuecomment-1559041183) to do that was never merged by the maintainer. Which is why we did our own fork: [input-output-hk/optparse-applicative](https://github.com/input-output-hk/optparse-applicative) and depended on this fork in [cardano-cli](https://github.com/IntersectMBO/cardano-cli/blob/ca494098df110dfcc23f14ef6635ec1b062baddf/cardano-cli/cardano-cli.cabal#L245).

However, since 2021, `optparse-applicative`'s main repository [continued to evolve](https://github.com/pcapriotti/optparse-applicative/tags) and so our fork became out of date, adding to maintenance burden if we wanted to keep up.

# Decision

We want to get rid of our fork of `optparse-applicative`. Luckily, ideas from our initial PR were integrated into `optparse-applicative`'s main repo in 2023 (as mentioned [here](https://github.com/pcapriotti/optparse-applicative/pull/428#issuecomment-1559041183)), so we can now get better looking formatting of `--help` files nearly out of the box.

We did [a PR](https://github.com/pcapriotti/optparse-applicative/pull/494) to `optparse-applicative` with the tweak we need. This PR is way smaller than our PR from 2021 and so we are hopeful it will be accepted.

## Update 2025-11-05

After [our PR to `optparse-applicative`](https://github.com/pcapriotti/optparse-applicative/pull/494) got merged, [`cardano-cli`'s PR](https://github.com/IntersectMBO/cardano-cli/pull/899) got revisited.
The changes in the rendered help are still detrimental to the help text readability, therefore the PR was closed, and the attempt to abandon the fork postponed.

# Consequences

~~We have `cardano-cli` depend on [pcapriotti/optparse-applicative](https://github.com/pcapriotti/optparse-applicative) instead of [input-output-hk/optparse-applicative](https://github.com/input-output-hk/optparse-applicative), when [our PR](https://github.com/pcapriotti/optparse-applicative/pull/494) to `optparse-applicative` is merged and released.~~

# References

* [Our 2021 PR](https://github.com/pcapriotti/optparse-applicative/pull/428) to `optparse-applicative`'s main repo.
* [Our fork](https://github.com/input-output-hk/optparse-applicative) of optparse-applicative.
* [Our 2024 PR](https://github.com/pcapriotti/optparse-applicative/pull/494) to `optparse-applicative`'s main repo.

# Related ADRs

- [ADR-003](ADR-003-Dependencies-version-constraints-in-cabal-file) — the fork is a concrete example of fork dependency constraints discussed there.
- [ADR-012](ADR-012-standardise-CLI-multiple-choice-flags-construction) standardises CLI flag construction, which relies on the fork this ADR attempted to replace.
- [ADR-013](ADR-013-Metavars-must-follow-screaming-snake-case) defines metavar naming conventions for the help text produced by the fork.
