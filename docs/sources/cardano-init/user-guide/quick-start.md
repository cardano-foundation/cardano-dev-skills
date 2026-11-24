# Quick start

## 1. Create a project

Run the command with no arguments to start the interactive setup. It asks for a project name and a tool for each role:

```bash
cardano-init
```

If you already know which tools you want, use **one-shot mode**. Passing `--name` makes the command run without any prompts:

```bash
cardano-init --name my-protocol --on-chain aiken --off-chain meshjs --devnet yaci
```

Select only the roles you need. One role is enough:

```bash
cardano-init --name my-validators --on-chain aiken
```

To see the tools available for each role:

```bash
cardano-init list          # detailed list
cardano-init table         # compact matrix, with tool ids
```

## 2. Check your dependencies

Each tool needs its own toolchain. Run the dependency doctor from inside the generated project:

```bash
cd my-protocol
cardano-init doctor
```

It finds the components in the project, checks which toolchains are installed and recent enough, and prints the install command for each one that is missing and the upgrade command for each one that is too old. Add `--links` to also see the editor extensions and community channels for your stack.

## 3. Build and test

`cardano-init` also runs `git init` and makes an initial commit (when `git` is installed and the project is not inside another repository), so you can review every later change with `git diff`.

Every generated project uses [`just`](https://just.systems):

```bash
just build   # build every component (on-chain first, so the blueprint exists)
just test    # build, then run every component's tests
just clean   # remove build artifacts
```

`just test` passes on a new project, because every stack includes a worked gift-card example. Change the protocol as you need and run `just test` often.

## 4. Run a local chain (optional)

If you selected a devnet or an infrastructure provider, start it from its own component:

```bash
just -f devnet/Justfile dev   # for example, start Yaci DevKit
just -f infra/Justfile dev    # for example, start Kupo and Ogmios with cardano-up
```

Both write their connection details into the project's `.env`. The off-chain component reads them from there.

## More examples

```bash
# Show what would be generated, without writing anything
cardano-init --name my-protocol --on-chain aiken --dry-run

# Fullstack: one tool for both on-chain and off-chain, as a single protocol/ component
cardano-init --name my-protocol --fullstack scalus

# Short flags
cardano-init -n my-protocol -p scalus -d yaci

# Also generate a Nix flake for the project's dependencies
cardano-init --name my-protocol --on-chain aiken --off-chain meshjs --nix

# Later, from inside the project: add or replace a tool, or remove one
cardano-init add --on-chain plinth
cardano-init remove --devnet
```

The [Command reference](commands.md) lists every flag.
