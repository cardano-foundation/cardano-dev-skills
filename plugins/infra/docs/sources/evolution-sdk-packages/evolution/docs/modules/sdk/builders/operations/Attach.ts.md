---
title: sdk/builders/operations/Attach.ts
nav_order: 121
parent: Modules
---

## Attach overview

---

<h2 class="text-delta">Table of contents</h2>

- [operations](#operations)
  - [attachScriptToState](#attachscripttostate)

---

# operations

## attachScriptToState

Attaches a script to the transaction by storing it in the builder state.
The script is indexed by its hash for efficient lookup during transaction assembly.

This is an internal helper used by the public attachScript() method.
Scripts must be attached before being referenced by transaction inputs or minting policies.

**Signature**

```ts
export declare const attachScriptToState: (script: ScriptCore.Script) => Effect.Effect<void, never, TxContext>
```

Added in v2.0.0
