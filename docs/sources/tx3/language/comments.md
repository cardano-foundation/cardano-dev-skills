---
title: Comments
sidebar:
    order: 10
---

Tx3 has three kinds of comments: regular line comments, block comments, and doc-comments. The first two are stripped during parsing and have no effect beyond letting you annotate the source. Doc-comments are different — they are preserved and surfaced by downstream tooling (the registry UI, generated bindings, etc.).

## Line and block comments

```tx3
// A line comment runs to the end of the line.

/*
   A block comment runs until the matching */.
   Block comments do not nest, so the first */ closes them.
*/
```

Use these for notes to other authors. They never make it past the parser.

## Doc-comments

A *doc-comment* begins with `///` and runs to the end of the line. Place one (or several consecutive ones) immediately before a declaration to document it:

```tx3
/// The user who initiates the transaction.
party User;

env {
    /// The Cardano network magic identifier.
    network: Int,
}

/// Transfer lovelace from the user to the treasury.
/// Fees are deducted from the user's input UTxO.
tx pay(
    /// Amount to transfer, in lovelace.
    quantity: Int,
) {
    // ...
}
```

Doc-comments may attach to:

- a `party` declaration,
- an `env` field,
- a `tx` declaration, and
- a parameter inside a `tx` parameter list.

Multiple consecutive `///` lines are concatenated into a single docstring, in source order, joined with line breaks. A single leading space after the `///` is stripped from each line, so `/// foo` and `///foo` both yield `foo`.

A `///` line in any other position is a syntax error. If you want a free-floating comment that the parser ignores, use `//`.

## Where doc-comments show up

The compiler carries doc-comments through to the published [TII artefact](/advanced/tii): party docstrings become `Party.description`, transaction docstrings become `Transaction.description`, and env-field and tx-parameter docstrings become the `description` of the corresponding JSON Schema property. From there, the registry surfaces them in the protocol detail page and codegen frontends can embed them in generated bindings.

If you want a description to appear next to a name in the registry UI or in your generated SDK, write it as a `///` doc-comment in the source.
