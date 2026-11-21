# Status

✅ Adopted  2022-12-17

# Context

The Cardano block chain can be hard forked through multiple eras throughout its existence.  CLI commands may behave differently between eras depending on what the current era is and what era the user runs the command in.

The era to be used for a CLI command can be optional in which case the command may connect to the node to find out what the current era is and choose an era appropriately.

For these cases, the question arises what the default era should be for the CLI command.

Moreover there is the question of how the default era should change over time, particularly in relation to a hard fork: whether the default era should change in the release before or after the hard fork happens.

There is even scope to adopt a different strategy between query and transaction commands or even between different transaction commands.

For example we can create a transaction in two different ways using the CLI - using `transaction build` and `transaction build-raw` commands.  The `transaction build` command is "magical" in that it tries to be user friendly by inferring transaction parameters wherever it can so the user doesn't have to, while the `transaction build-raw` is for more experienced users because it provides no inference and leaves it up to the user to supply all the necessary transaction parameters.

Would it make sense for "magical" commands like the `transaction build` command to try to be more helpful and use the current era as the default?  That would _seem_ to be in the spirit of the command.

Historically we changed the default transactions era in the first release after the hard fork in order to give the tool/dapp developers the possibility to update the default transaction era in their code after the hard fork - otherwise their tools would stop working after the hard fork.

Care needs to be taken to avoid making a CLI release that does not work by default by defaulting to using an era that is not yet active. So that's why we have historically only updated the default era in the release after the hard fork, not the release before.

This way, third party tools that use the CLI would not stop working after the hard fork, they would continue to create and submit transactions in the older format, for the older era. Historically we always made that backwards compatibility work. It just meant that CLI users would not get the new features for the new era without explicitly using the right era flag - until the following release changed the default.

Moreover, it is often the case that CLI commands in the release that crossed the hard fork may not yet be updated to work in the new era.  If we adopted policy of using the current era for our CLI commands, even "magical" commands that try to infer as much as possible, we risk possibility of the command breaking after the hard fork.

The decision should as much as possible take into account the following considerations:

* CLI behaviour should not suddenly change after a hard fork in a way that can break third party tools and user expectations.
* Historical precedent so as to avoid surprising SPOs and in a new release.
* Simplicity and consistency.
* Behaviour that just works where it makes sense.

# Decision

All era-sensitive CLI commands should have a default era and the default era should be consistent across all commands.

A given release should use the current era up until the latest era supported by the Mainnet blockchain as at the point of release as the default era.

For example, given the hard fork from Alonzo to Babbage:

* The release immediately before the hard fork will set the default era to be the current era up to the Alonzo era only.  The Babbage era will not be used unless it is explicitly specified.

* The release after the hard fork will use the current era up until Babbage era.

# Consequences

* CLI commands that for a given release had worked prior to a hard fork would continue to work after a hard fork.
* Users will not be surprised by changes in behaviour after the hard fork.
* Third party tools will continue to work after the hard fork.
* Users will not be surprised by difference in behaviour between different commands.
* Users will not necessarily be using the current era by default.
* Users will be using a most practical current era by default on Mainnet and other networks that may not be on the same era as Mainnet.
* Users will need to explicitly specify the current era after a hard fork and before the release immediately following the hard fork if that's what they really want and at their own risk.

# Related ADRs

- [ADR-004](ADR-004-Support-only-for-mainnet-and-upcoming-eras) limits the eras exposed by `cardano-api` to mainnet and upcoming only.
- [ADR-012](ADR-012-standardise-CLI-multiple-choice-flags-construction) standardises how CLI choice flags (including era flags) should be constructed.
