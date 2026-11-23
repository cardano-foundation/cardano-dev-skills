# Ecosystem: aikup, cardano-up, and friends

`cardano-init` creates a project, and later [adds, replaces, or removes components](generated-project.md#changing-the-stack-later) when you ask it to. It does not manage the toolchains themselves. Tools such as [`aikup`](https://github.com/aiken-lang/aikup) and [`cardano-up`](https://github.com/blinklabs-io/cardano-up) install and update the toolchains and services that the project uses. The two kinds of tool work together:

- `cardano-init` decides which tools the project uses and how they connect.
- `aikup`, `cardano-up`, and similar installers install and manage those tools.

They meet in the [`doctor`](commands.md#doctor) command. When a toolchain is missing, `doctor` tells you which installer to use, for example `aikup` for Aiken and `cardano-up` for the infrastructure role. When a toolchain is older than a template needs, `doctor` prints the upgrade command.

`cardano-init` does not:

- install, pin, or upgrade tool versions (`doctor` only tells you how);
- manage dependencies after the project is generated;
- migrate existing projects.

There is no `cardano-init update` command.
