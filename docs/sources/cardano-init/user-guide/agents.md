# For coding agents

`cardano-init` can be run completely by an LLM agent.

- **JSON output.** Every command accepts `--json` and prints one JSON object. Errors carry a stable `code` and a `context` that says how to fix them. `cardano-init list --json` returns every role and tool.
- **No prompts.** One-shot mode (`--name …`) never prompts, so an agent can create a project in one call. `--json` also turns prompts off: if required input is missing, the command returns an error.

## Generated `AGENTS.md`

Every project includes an `AGENTS.md`, and a `CLAUDE.md` that imports it. It is written for the tools you selected and contains:

- the project layout;
- the interface contract and the rules it sets;
- the `just` commands to build, test, and clean;
- links to the official documentation of each tool;
- the [cardano-dev-skills](https://github.com/cardano-foundation/cardano-dev-skills) most useful for that stack.

cardano-dev-skills is a Cardano Foundation skill set for agents. It teaches how to write validators, build transactions, and debug on-chain failures. `cardano-init` creates the project, and the generated `AGENTS.md` points the agent to the skills it needs.

## A typical agent flow

```bash
# 1. Discover what's available
cardano-init list --json

# 2. Scaffold in one call
cardano-init --json --name my-protocol --on-chain aiken --off-chain meshjs --devnet yaci

# 3. Check toolchains from inside the project
cd my-protocol && cardano-init doctor --json

# 4. Build and test
just test
```

## JSON envelope

A `--json` response has one of two shapes:

```json
{ "schema_version": 1, "ok": true,  "data":  { } }
{ "schema_version": 1, "ok": false, "error": { "code": "<stable>", "message": "<human>", "context": { } } }
```

`message` is for humans and can change between versions. `code` and the `context` keys are stable. The exit code gives the category: `0` success, `1` runtime error, `2` usage error (see [Exit codes](commands.md#exit-codes)).

## Error codes

| `code` | Exit | `context` | Meaning |
|--------|------|-----------|---------|
| `name_required` | 2 | `{}` | A creation flag was given without `--name`. |
| `invalid_project_name` | 2 | `{ name, reason }` | The name has characters outside `[A-Za-z0-9_-]` or starts with `.`. |
| `unknown_tool` | 2 | `{ tool_id, role, valid_tools }` | No tool with that id for the role. |
| `tool_role_mismatch` | 2 | `{ tool_id, role, valid_roles }` | The tool exists but doesn't fill that role. |
| `fullstack_conflict` | 2 | `{}` | `--fullstack` combined with `--on-chain` / `--off-chain`. |
| `fullstack_unsupported` | 2 | `{ tool_id, valid_tools }` | The tool has no fullstack template. |
| `no_roles_selected` | 2 | `{}` | No role flag was given. |
| `experimental_not_allowed` | 2 | `{ tools, remedy }` | An experimental tool was selected without `--allow-experimental`. |
| `incompatible_tools` | 2 | `{ tools, reason, compatible_providers, compatible_off_chain, remedy }` | The off-chain tool can't reach any selected provider. |
| `project_unrecognized` | 2 | `{ dirs }` | `add` / `remove` couldn't identify a component directory. |
| `slot_occupied` | 2 | `{ role, dir }` | A target directory exists and isn't the recognized component. |
| `nothing_to_change` | 2 | `{}` | The requested `add` / `remove` is a no-op. |
| `dir_exists` | 1 | `{ path }` | The project directory already exists and isn't empty. |
| `worktree_dirty` | 1 | `{ path }` | Uncommitted changes (or not a git repository) and no `--force`. |
| `registry_load` | 1 | `{ file?, detail }` | The embedded registry failed to load. |
| `scaffold_error` | 1 | `{ path?, detail }` | A template asset, render, or I/O failure. |
