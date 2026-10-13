# Releasing

`cardano-init` ships prebuilt binaries via [`dist`](https://axodotdev.github.io/cargo-dist)
(cargo-dist). Releases are **tag-driven**: pushing a `vX.Y.Z` tag triggers
`.github/workflows/release.yml`, which builds every target, generates installers, and **creates
the GitHub Release** with the binaries attached.

## Config lives in `dist-workspace.toml`

That file is the source of truth — the workflow is a compiled artifact of it:

- `targets` — the 5 platforms we build (x86_64/aarch64 Linux, x86_64/aarch64 macOS, x86_64 Windows).
- `installers` — `shell` + `powershell` one-line install scripts.
- `cargo-dist-version` — pins the exact `dist` version CI uses. **Keep it equal to the `dist`
  version you run locally**, or `dist generate --check` will fail in CI.

**Never hand-edit `.github/workflows/release.yml`.** To change the pipeline, edit
`dist-workspace.toml` and re-run `dist generate` (see below). CI enforces this with
`dist generate --check`.

## Cutting a release

1. Bump `version` in `Cargo.toml` (SemVer).
2. Commit the bump on a branch and merge it to `main` as usual.
3. Tag and push from `main`:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```
4. `release.yml` runs: builds all 5 targets, then creates the GitHub Release with the archives,
   installer scripts, and checksums attached. The release body is auto-generated (install +
   download sections) — there is no hand-maintained changelog.

A version with a prerelease suffix (e.g. `v0.2.0-rc.1`) is automatically marked as a
**prerelease** on GitHub.

## Testing before you tag

Nothing here requires a push:

```bash
dist plan               # what artifacts would be produced (resolves all targets)
dist generate --check   # confirms release.yml matches dist-workspace.toml (the CI gate)
dist build --artifacts=local --target <your-host-triple>   # real compile + archive locally
```

To exercise the **full build matrix in CI without publishing**, set `pr-run-mode = "upload"` in
`dist-workspace.toml`, `dist generate`, and open a PR — CI compiles all 5 targets and attaches
them to the *workflow run* (no tag, no Release). For a live end-to-end dry run, push a prerelease
tag to a **fork** and delete it afterward.

## Regenerating the workflow

After any change to `dist-workspace.toml` (or when bumping the pinned `dist` version):

```bash
dist init      # optional: interactive config update; also runs generate
dist generate  # re-render .github/workflows/release.yml from config
```

Install a specific `dist` locally with `cargo install cargo-dist --version <X> --locked`.

## Deferred distribution channels

Homebrew, npm, and crates.io publishing are intentionally **off** pending credentials. The exact
switches are documented in the comment block in `dist-workspace.toml`:

- **Homebrew** — add `"homebrew"` to `installers` + a `tap` repo (needs a tap repo + token).
- **npm** — add `"npm"` to `installers` + `npm-scope` (needs an `NPM_TOKEN` secret).
- **crates.io** — add `publish-jobs = ["cargo"]` (needs a `CARGO_REGISTRY_TOKEN` secret).

Re-run `dist generate` after enabling any of them.
