---
title: blueprint/Codegen.ts
nav_order: 17
parent: Modules
---

## Codegen overview

---

<h2 class="text-delta">Table of contents</h2>

- [utils](#utils)
  - [generateTypeScript](#generatetypescript)

---

# utils

## generateTypeScript

Generate TypeScript code with TSchema from a Blueprint

**Signature**

```ts
export declare function generateTypeScript(
  blueprint: BlueprintTypes.PlutusBlueprint,
  config: CodegenConfig = DEFAULT_CODEGEN_CONFIG
): string
```
