# Release testing

CI already proves that every generated project builds, passes its tests, and runs on a devnet (see [Tested combinations](../user-guide/tools.md#tested-combinations)). It can't judge what a person sees in a terminal. This page is the manual checklist that covers that gap: the interactive setup, error messages, and output formatting.

Run it once per release candidate, before the final version is tagged. It takes about 20 minutes. Anyone can run it, including people outside the team: every case lists its exact steps and the expected result.

## How a run works

1. Open a **Release QA** issue from the [issue templates](https://github.com/input-output-hk/cardano-init/issues/new/choose). Fill in the version and your environment.
2. Work through the cases below in order. Tick each case in the issue as it passes.
3. When a case fails, leave it unticked. Add a comment that names the case ID (for example `RT-03`) and attach the terminal output or a screenshot.
4. Close the issue when every case passes, or when each failure is either fixed or accepted by a maintainer. A closed issue is the sign-off that [RELEASING.md](https://github.com/input-output-hk/cardano-init/blob/main/RELEASING.md) requires before the final tag.

A case passes only when everything under *Expect* holds. If you're unsure, treat it as a failure and describe what you saw.

## Before you start

Use a real terminal, 80 columns wide, and an empty scratch directory outside any git repository. Turn off the update check, so a notice about a newer release doesn't interfere with the output:

```bash
mkdir -p ~/cardano-init-qa && cd ~/cardano-init-qa
export CARDANO_INIT_NO_UPDATE_CHECK=1
```

## Cases

### RT-01 · Install the release candidate

Install the version under test from its GitHub Release, as a user would. Don't use `cargo run`. Replace `vX.Y.Z-rc.N` with the tag.

```bash
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/input-output-hk/cardano-init/releases/download/vX.Y.Z-rc.N/cardano-init-installer.sh | sh
cardano-init --version
```

On Windows, use `cardano-init-installer.ps1` from the same release with `irm … | iex`.

**Expect:** the installer finishes without errors, and `--version` prints `cardano-init X.Y.Z-rc.N`.

### RT-02 · Interactive setup, normal path

Run `cardano-init`. Choose **Aiken** for on-chain and **MeshJS** for off-chain, and skip the other roles. At **Project name**, first enter `my app` (with a space), then accept the default. Accept the defaults for Nix and `spec/`, and confirm **Generate project?**.

**Expect:**

- Each role prompt starts with a preselected `(skip)` entry, and each tool has a one-line description.
- `my app` is rejected with an inline message, and the prompt asks again.
- The summary box lists Aiken, MeshJS, network `preview`, and spec `yes`, and its right border lines up.
- `my-protocol/` is created, followed by next steps that mention `just build`.
- Nothing wraps badly or overlaps at 80 columns.

### RT-03 · Interactive setup, edge cases

Run `cardano-init` again and follow these steps:

1. Choose **Aiken** for on-chain and **Tx3** for off-chain.
2. At infrastructure, press Space on **Kupo** and **Ogmios**, press Space on Ogmios again to deselect it, then press Enter.
3. At devnet, select **Yaci DevKit**, then choose `(skip)`.
4. At formal methods, choose **Blaster**.
5. Press Enter at **Include this experimental tool anyway?**, then accept the defaults up to **Generate project?** and answer **No**.

**Expect:**

- Yaci DevKit shows `✗ unavailable` with a reason. Selecting it prints a warning and repeats the prompt.
- The experimental warning names Tx3 and Blaster. The confirmation defaults to No, and both are then dropped.
- The summary box lists only Aiken and Kupo.
- Answering No writes nothing and exits with code `0` (`echo $?`).

### RT-04 · Ctrl-C

Run `cardano-init` and press Ctrl-C at the first prompt.

**Expect:** the CLI exits right away, with no panic or stack trace. The cursor is visible, and the terminal works normally.

### RT-05 · Error messages

Run each command and check its exit code with `echo $?`.

| Command | Error | Exit |
|---------|-------|:----:|
| `cardano-init --on-chain aiken` | `name_required` | 2 |
| `cardano-init --name x --on-chain nope` | `unknown_tool` | 2 |
| `cardano-init --name x --on-chain meshjs` | `tool_role_mismatch` | 2 |
| `cardano-init --name x --formal-methods blaster` | `experimental_not_allowed` | 2 |
| `cardano-init --name x --off-chain blaze --infra dolos` | `incompatible_tools` | 2 |
| `cardano-init --name my-protocol --on-chain aiken` | `dir_exists` | 1 |

**Expect:**

- Every command shows a highlighted `ERR (<code>)` label with the code from the table, and a one-sentence message.
- Wrapped lines stay aligned.
- Any command suggested in a help box works when you copy and run it.
- The exit codes match the table.

### RT-06 · `add` and `remove`

```bash
cd my-protocol
cardano-init add --devnet yaci --dry-run
cardano-init remove --off-chain
touch stray && cardano-init add --devnet yaci
cd ..
```

**Expect:**

- The dry run shows a plan and writes nothing.
- `remove` deletes `off-chain/` and points you to `git diff`.
- The last command fails with `ERR (worktree_dirty)` and suggests `--force`.

### RT-07 · Output formatting

```bash
cardano-init list
cardano-init table
cardano-init list | head -5
NO_COLOR=1 cardano-init table
```

**Expect:**

- `list` and `table` are readable in your terminal's theme. Columns line up, and links aren't cut off.
- `head` exits cleanly, with no `Broken pipe` error and no raw escape codes.
- With `NO_COLOR` set, the output has no colour.

### RT-08 · `doctor`

```bash
cd my-protocol
cardano-init doctor
env PATH=/usr/bin:/bin "$(command -v cardano-init)" doctor
cd ..
```

The second command hides most of your tools by shrinking `PATH`.

**Expect:** the first run shows a status for each component. In the second run, the hidden tools are marked missing, each with an install command for your OS.

## Maintaining this checklist

- Keep it short. Add a case only for something a person has to look at; if a test can check it, write the test instead.
- Case IDs are permanent. A retired ID isn't reused, so results can be compared across releases.
- The **Release QA** issue form (`.github/ISSUE_TEMPLATE/release-qa.yml`) lists the same case IDs. Update both in the same pull request.
