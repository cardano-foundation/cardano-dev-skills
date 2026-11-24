# Installation

`cardano-init` is a single binary with no runtime dependencies.

## Run without installing

Using `npx`:

```bash
npx cardano-init help
```

Using Nix:

```bash
nix run github:input-output-hk/cardano-init -- help
```

## Install script

Linux and macOS (x86_64 and arm64):

```bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/input-output-hk/cardano-init/releases/latest/download/cardano-init-installer.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/input-output-hk/cardano-init/releases/latest/download/cardano-init-installer.ps1 | iex
```

To install a specific version, or to download the binary yourself, use the [Releases page](https://github.com/input-output-hk/cardano-init/releases).

## Nix (flake)

```bash
# Install the CLI into your profile
nix profile add github:input-output-hk/cardano-init

# Or run it once, without installing
nix run github:input-output-hk/cardano-init -- help
```

## Cargo

You need a recent Rust toolchain that supports the 2024 edition.

```bash
# From the published repository
cargo install --git https://github.com/input-output-hk/cardano-init

# Or from a local clone
cargo install --path .
```

## Verify

```bash
cardano-init --version
```

The projects `cardano-init` generates need [`just`](https://just.systems) and the toolchain of each tool you select (Aiken, Node.js, a JVM, Docker, …). You can install these after you generate a project: run [`cardano-init doctor`](commands.md#doctor) inside it to see what is missing and how to install it.
