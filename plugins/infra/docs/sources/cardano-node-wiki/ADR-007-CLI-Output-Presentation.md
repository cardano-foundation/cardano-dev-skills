# Status

✅ Adopted 2024-11-29 

# Context

In order to allow easy composability of the command line interface (CLI) programs, the output data can be sent to standard output (*stdout*) or standard error (*stderr*) streams.
In Unix CLI tools, output conventions typically dictate that:

* **stdout** is used for regular output from a command. It typically includes the main results or data that the command is designed to produce. For example, the contents of a file when using `cat`, or the list of files in a directory when using `ls`.

* **stderr** is used for error messages and diagnostic information. Any warnings, errors, or debug information that is not part of the main output of the tool will usually be sent to stderr. For example, an error message indicating that a file does not exist when using `cat`.

These conventions help users and scripts to easily differentiate between normal output and error messages, enabling more effective error handling and output redirection.

This also aligns with [UNIX philosophy][bell-journal] (from *The Bell System Technical Journal*):
>Expect the output of every program to become the input to another, as yet unknown, program.
>Don't clutter output with extraneous information.
>Avoid stringently columnar or binary input formats.
>Don't insist on interactive input.

# Decision

`cardano-cli` should output its results to `stdout` and any diagnostic messages to `stderr`.

# Consequences

Some of `cardano-cli` commands are not following this principle.
This will require updating them to make things consistent across all the commands.

# References

1. [Unix Philosophy - Wikipedia][unix-philosophy]
1. [UNIX Time-Sharing System - The Bell System Technical Journal][bell-journal]

[unix-philosophy]: https://en.wikipedia.org/wiki/Unix_philosophy
[bell-journal]: https://archive.org/details/bstj57-6-1899/mode/2up

# Related ADRs

- [ADR-005](ADR-005-cardano-testnet-node-configuration-file) introduces a new CLI command that should follow these output conventions.
- [ADR-008](ADR-008-Use-RIO-in-cardano‐cli) addresses error handling and rendering in `cardano-cli`.

