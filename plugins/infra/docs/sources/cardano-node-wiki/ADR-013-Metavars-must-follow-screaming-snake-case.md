# Status

📜 Proposed 2025-05-05

# Context

For the purpose of this ADR, we use the word "metavariable" (or "metavar" for short) to refer to the symbols that are used in the help or manual pages of a command and represent a value or expression that should be passed as an argument to the command.

For example, in the usage notice of the `date` command:

```
usage: date [-jnRu] [-I[date|hours|minutes|seconds|ns]] [-f input_fmt]
            [ -z output_zone ] [-r filename|seconds] [-v[+|-]val[y|m|w|d|H|M|S]]
            [[[[mm]dd]HH]MM[[cc]yy][.SS] | new_date] [+output_fmt]
```

The symbols `input_fmt`, `output_zone`, and `filename` are all metavariables. They are not meant to be written literally, but to be replaced with an actual value.

The help of `cardano-cli` uses metavariables extensively, and the `optparse-applicative` library that `cardano-cli` uses allows us to specify names for metavars by using [the metavar combinator](https://hackage.haskell.org/package/optparse-applicative-0.18.1.0/docs/Options-Applicative-Builder.html#v:metavar).

As described in the `optparse-applicative` documentation, metavariables have no effect on the actual parser and serve only to specify the symbolic name for an argument to be displayed in the help text.

Having naming conventions for symbols is good practice and a standard in programming. This is especially true if the symbols are to be displayed to users, as is the case of metavariables.

# Proposal

Let's use the screaming snake case format for metavariables. See [the article on snake case](https://en.wikipedia.org/wiki/Snake_case) from Wikipedia.

Screaming snake case uses all uppercase letters and underscores ("_") to separate words instead of spaces.

For example:
- A metavariable representing the path to the node socket could be named: `NODE_SOCKET_PATH`
- A metavariable representing the POSIX time for an event could be named: `POSIX_TIME`
- Acronyms should remain as they are, so a metavariable for an unspent transaction output could be named: `UTXO`

In particular, dashes should not be used to separate words: `TX-IN` would not be considered valid screaming snake case.

# Rationale

We justify our choice of screaming snake case over other alternatives and explain why adopting a naming convention is important.

## Why have a naming convention at all?

Naming conventions are standard in programming and considered good practice for several reasons, including:

- Readability and clarity. It is easier and faster to mentally "parse" text if it follows patterns.
- Consistency. It is less likely that we will use slightly different names to represent the same thing.
- Easier maintenance. Having a specific format for a type of symbol makes it easier to restrict a search to only that type of symbol and to find all occurrences.
- No need to decide each time. It simplifies the task of deciding on names, since there is no need to decide on the format.

We already have naming conventions for variable and function names, and for other identifiers. Some conventions are already enforced by tools like `hlint`, but the formatting of metavariables is currently not enforced because they are not a native construct of Haskell.

## Why screaming snake case?

Screaming snake case is not standard for metavariables across Unix tools, but it is easily distinguishable from the long flag names which are typically written in snake case (lower case). Furthermore, flag names are written side by side with metavariables so it is important that they are easily distinguishable, especially because flag names are meant to be written literally and metavariables are just placeholders. Screaming snake case is also widely used for names of constants in several programming languages.

Additionally, screaming snake case is already a _de facto_ standard within `cardano-cli` and `cardano-node`.

# Conclusion

In this Architecture Decision Record (ADR), we establish the policy of adopting the screaming snake case format for metavariables. We will apply this standard consistently across our codebase to enhance clarity, readability, consistency, and maintainability.

# Related ADRs

- [ADR-006](ADR-006-Using-optparse-applicative-main-repository) (rejected) — help text formatting, which displays metavars, is produced using our `optparse-applicative` fork.
- [ADR-012](ADR-012-standardise-CLI-multiple-choice-flags-construction) — defines flag construction conventions; flags defined there should use metavar names following this ADR.
