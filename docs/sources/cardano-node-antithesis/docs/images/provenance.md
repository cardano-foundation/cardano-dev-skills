# Nix image timestamps and provenance

Maintained component images (`adversary`, `asteria-game`,
`asteria-stub`, `sidecar`, `tracer-sidecar`, `tx-generator`) stamp
OCI `created` from **source time**, never from packaging wall-clock.

## Policy

`created` is the flake source revision time: Nix `self.lastModifiedDate`
(the git committer time of the producing revision) reformatted to RFC
3339 UTC (`YYYY-MM-DDTHH:MM:SSZ`). The same value is copied to
`org.opencontainers.image.created`.

The other OCI labels are:

| label | value |
|---|---|
| `org.opencontainers.image.revision` | full commit SHA, with `-dirty` when the producing tree was dirty |
| `org.opencontainers.image.source` | `https://github.com/cardano-foundation/cardano-node-antithesis` |
| `org.opencontainers.image.version` | short revision (existing image tag), `-dirty` when dirty |

Wall-clock (`builtins.currentTime`, `created = "now"`) is not an input
to any image closure. Identical sources therefore yield identical
bytes and the same store path. A rebuild from cache keeps the original
source date; it does not mint a new identity. Consecutive builds print
`reuse=true`.

A flake source with no `rev`/`dirtyRev` fails closed in
`components/image-meta/meta.nix`. There is no unpublished `dev` image.

Freshness for Antithesis is earned by a new source revision (new
commit → new source time → new digest → new tag), never by rebuilding
or retagging old bytes.

Dirty worktrees: `git status --porcelain --untracked-files=no` non-empty
means labels use `${HEAD}-dirty` and the short tag with `-dirty`.
Publication checks out the exact commit (clean).

The computation lives in one helper, `components/image-meta/meta.nix`,
consumed as `path:../image-meta` (`flake = false`) from each component
flake.

## Operator build and publish

Commands below assume the **repository root** as the working directory
unless a `cd` is shown.

Build a component image (example: asteria-stub):

```bash
out=$(cd components/asteria-stub && nix build .#docker-image --print-out-paths)
```

`$out` is the tarball store path. Inspect it from the repository root,
without a daemon. On a dirty tree append `-dirty` to the revision:

```bash
rev=$(git rev-parse HEAD)
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  rev="${rev}-dirty"
fi
created=$(date -u -d "$(git log -1 --format=%cI)" +%Y-%m-%dT%H:%M:%SZ)
tag=$(tar -xzOf "$out" manifest.json | jq -r '.[0].RepoTags[0]' | sed 's/.*://')
./scripts/check-image-provenance.sh \
  --image "$out" \
  --expected-revision "$rev" \
  --expected-created "$created" \
  --expected-source "https://github.com/cardano-foundation/cardano-node-antithesis" \
  --expected-version "$tag"
```

Hosted publication is `.github/workflows/publish-images.yaml`. The
daemon-free job runs `just check-image-provenance` (focused proof plus
representative tarball inspection). The existing publisher still skips
digest-only compose pins and entries whose short and full commit tags
already exist in the registry. A corrected source produces a new tag
the consumer can select. Do not retag old bytes. Updating compose pins
to those new tags happens after publication (residual R-001).

Local CI from the repository root:

```bash
nix develop --quiet -c just ci
```

## Residual Antithesis boundary

The MOOG-built config image is a separate artifact with a separate
owner. This harness does not stamp or rebuild it.

Intentionally old compose pins stay old until the consumer file is
updated to a new commit tag (R-001).

The live Antithesis "Recent software version provided" warning is not
resolved by this change alone. It requires a subsequent test run that
consumes the corrected artifacts. This page does not claim that live
resolution.
