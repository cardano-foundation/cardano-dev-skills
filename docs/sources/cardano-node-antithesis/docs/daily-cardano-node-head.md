# Cardano Node HEAD candidate

The HEAD candidate path answers one operator question: does the
**latest `cardano-node` `master` HEAD executable** run as a Docker cluster in
this repository's `cardano_node_master` testnet, with every producer and relay
on that one image? One controller, `scripts/daily-cardano-node-head.sh`, runs
the path; every external effect (upstream observation, image build,
publication, revision proof, Compose) lives in one transport,
`scripts/daily-cardano-node-head-github.sh`. No real Antithesis submission is
made anywhere in this path — the submission boundary is always fake.

## The candidate identity

One candidate is four agreeing identities:

1. the resolved upstream `master` SHA (40 hex), observed exactly once per run
   against `https://github.com/IntersectMBO/cardano-node.git`;
2. the published image reference `<repository>:<sha>@sha256:<digest>`, where
   the tag is the resolved SHA and the digest is read back from the registry;
3. the `git revision` reported by `cardano-node --version` executed **inside
   the published image**;
4. the image of every producer and relay in the rendered Compose model,
   verified on the Compose-resolved model, not on file text.

## Running it locally

```sh
just head-candidate-local
```

starts a throwaway registry (`registry:2` on `localhost:5000`), builds the
exact-rev upstream Nix `dockerImage/node`, publishes it as
`localhost:5000/cardano-node-head:<sha>`, proves the revision, renders the
`cardano_node_master` model into the state directory with every producer and
relay set to the candidate, validates the model through Compose, and writes
the receipt. The state directory defaults to
`${RUNNER_TEMP:-/tmp}/daily-cardano-node-head`; set
`HEAD_CANDIDATE_STATE_DIR` to place it elsewhere. The image repository is
`HEAD_CANDIDATE_IMAGE_REPOSITORY` (the hosted run publishes to GHCR).

The rendered cluster can then be started and proven with
`scripts/head-candidate-cluster.sh <rendered-model>`. The command derives a
throwaway execution copy of the rendered model — container names and the
fixed network name removed, its own compose project — so it coexists with
any other cluster on a shared Docker daemon; the copy is never the receipt's
`rendered_model` and is deleted with the cluster. It waits for every producer
and relay to answer a `cardano-cli ping`, samples the chain tip twice to show
blocks advancing, records the image of each node container, and tears the
cluster down.

## The manual recovery entrypoint (hosted)

The workflow **Cardano Node HEAD candidate**
(`.github/workflows/daily-cardano-node-head.yaml`) is dispatched by hand from
the Actions tab on the default branch. It runs the same controller with the
real transport against GHCR (`ghcr.io/cardano-foundation/cardano-node-antithesis/cardano-node-head`)
using the run's own token, performs the fake submission, and uploads the
receipt as a run artifact. There is no schedule and no automatic trigger of
the production candidate path; pull requests run only the hermetic candidate
suites.

Because the tag is the full upstream SHA, re-running the workflow is
idempotent for an unchanged `master`.

## Fail-closed stops

Two preflight rejections exit non-zero with a stderr token before any
receipt exists: an unsupported mode (`unsupported mode: …`) and a
non-executable transport (`transport is not executable: …`). Every later
stop is a durable receipt record with `outcome=FAILED`, the failing stage,
and a stable error token; no later stage runs after a stop.

| Stage | Stops when | Error token |
|---|---|---|
| `resolve-upstream` | the observation command fails | `observation-command-failed` |
| `resolve-upstream` | zero or multiple observation rows | `observation-count-<n>` |
| `resolve-upstream` | origin or ref differs, or the SHA is not 40-hex | `wrong-origin`, `wrong-ref`, `malformed-sha`, `malformed-observation` |
| `publish-candidate` | the exact-rev build, load, tag, or push fails | `publish-failed` |
| `publish-candidate` | the reference is not `repo:40hex@sha256:64hex` or the tag differs from the resolved SHA | `malformed-candidate-form`, `multi-line-candidate`, `tag-sha-mismatch` |
| `prove-revision` | the container cannot run or reports no parsable revision | `revision-absent`, `unparsable-revision`, `multi-line-revision` |
| `prove-revision` | the reported revision differs from the resolved SHA | `revision-mismatch` |
| `render-topology` | rendering fails or the model escapes the state dir | `render-failed`, `model-outside-state-dir`, `multi-line-model-path` |
| `verify-topology` | the census is empty, a node service is missing or duplicated, or any image differs from the candidate | `zero-topology-census`, `missing-node-service-<name>`, `census-count-<n>`, `image-mismatch`, `stale-topology-override`, `malformed-topology-row`, `empty-service`, `empty-image`, `whitespace-image` |
| `validate-compose` | Compose rejects the rendered model | `compose-failed` |
| `submit-candidate` | the fake submission fails or is malformed | `submission-failed`, `multi-line-submission`, `malformed-submission` |

The transport adds its own fail-closed stops with named stderr tokens before
the controller ever sees a value: a registry digest read-back that is not
`sha256:<64 hex>` (`registry digest read-back is malformed`), an image output
without exactly one tarball (`expected exactly one image tarball`), a
containerized `cardano-node` without a `git revision` line (`reported no git
revision`), and a rendered model that still references an upstream node image
(`still references an upstream node image`).

## Receipt fields

The receipt is an append-only file of `CandidateReceiptV1` records, one
`key=value` line per field, one record per stage, blank-line separated:

| Field | Present when |
|---|---|
| `schema` | always — literal `CandidateReceiptV1` |
| `stage`, `outcome`, `mode` | always |
| `error` | `outcome=FAILED` records only |
| `upstream_origin`, `upstream_ref` | always |
| `upstream_sha` | from `resolve-upstream` on |
| `candidate_ref` | from `publish-candidate` on |
| `binary_revision` | from `prove-revision` on |
| `rendered_model` | from `render-topology` on |
| `topology_services`, `topology_image` | from `verify-topology` on |
| `submission` | from `submit-candidate` on |

A successful run ends with the `submit-candidate` record, `outcome=PREPARED`,
carrying all four agreeing identities. Credentials never appear in a receipt,
log, or document: the hosted run binds its registry token as step-level
environment and feeds it to `docker login` on stdin, and the controller,
transport and receipt never see a credential value.
