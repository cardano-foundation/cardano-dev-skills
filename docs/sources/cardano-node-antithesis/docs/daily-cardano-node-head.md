# Cardano Node HEAD candidate

The HEAD candidate path answers one operator question: does the
**latest `cardano-node` `master` HEAD executable** run as a Docker cluster in
this repository's `cardano_node_master` testnet, with every producer and relay
on that one image? One controller, `scripts/daily-cardano-node-head.sh`, runs
the path; every external effect (upstream observation, image build,
publication, revision proof, Compose) lives in one transport,
`scripts/daily-cardano-node-head-github.sh`. The candidate path is also the
preparation stage of the daily run below; on its own (the manual mode) no real
Antithesis submission is made anywhere — the submission boundary is fake.

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

## The hosted entrypoints

The workflow **Cardano Node HEAD candidate**
(`.github/workflows/daily-cardano-node-head.yaml`) covers three hosted
entrypoints:

- **schedule** — once per UTC day at 02:23, the production daily run below;
- **workflow_dispatch → production** — the manual recovery entrypoint for the
  same production daily run (see *Recovery* below);
- **workflow_dispatch with no inputs** — the #215 manual candidate preparation
  with the fake submission, unchanged.

The hosted runs use the real transport against GHCR
(`ghcr.io/cardano-foundation/cardano-node-antithesis/cardano-node-head`)
using the run's own token, and upload the receipt as a run artifact. Pull
requests run only the hermetic candidate suites.

Because the tag is the full upstream SHA, re-running the manual candidate
preparation is idempotent for an unchanged `master`.

## The daily run

Every UTC day the scheduled job runs the same controller in `daily` mode.
Before any transport call the controller derives the UTC day (a malformed
override is rejected as `invalid UTC day: …`) and pins the run base — the
exact commit the workflow started from, from `HEAD_CANDIDATE_RUN_BASE` or
`GITHUB_SHA` (an unresolvable base is rejected as `unresolved run base: …`).
After the unchanged #215 candidate stages end at `submit-candidate PREPARED`,
the daily stages run:

1. **prepare-consumer** — the rendered all-HEAD topology is committed as its
   own testnet directory `testnets/cardano_node_head/` **on the exact run-base
   commit itself**: that SHA is fetched and checked out directly, so a
   `main` that moved mid-run (the normal case on an active repository)
   changes nothing. A run base that can no longer be fetched — history
   rewritten away — fails closed with `run base is unfetchable`. The
   mixed-version `cardano_node_master` profile is untouched.
2. **construct-request** — the exact dispatch identity (workflow file, claim
   tag, testnet directory, duration, fault setting) is validated and recorded
   before anything is submitted. A request that cannot be constructed stops
   here and does **not** burn the day.
3. **claim-day** — the UTC day is claimed by creating
   `refs/tags/daily-cardano-node-head/<YYYY-MM-DD>` at the consumer commit
   with a creation-only push. Creation succeeds at most once: a duplicate,
   concurrent or after-failure invocation is refused (`day-already-claimed`)
   before any MOOG contact, and the tag is never re-pointed.
4. **submit-run** — the existing `cardano-node.yaml` MOOG workflow is
   dispatched at the claim tag with `test=cardano_node_head`, `duration=3`,
   `no-faults=false`, and a unique correlation marker carried into the run
   title (`correlation=<marker>`); the transport then selects the run whose
   display title equals `cardano_node_head [<marker>]` exactly — one real
   three-hour, fault-injected run, never a neighbouring one.
5. **await-run** — the dispatched run is watched and its `moog-correlation`
   artifact read back; the terminal record correlates the MOOG test id,
   report URL and outcome with every candidate identity.

**No retry, and this is the exact order in which an attempt is spent.** The
controller takes the **day claim** (the create-once day tag) before any MOOG
contact; the dispatched MOOG run then reads the **MOOG census** before
constructing its request. The one-attempt-per-day guarantee covers the
scheduled, recovery and validation paths through the HEAD workflow — all of
them pass the controller's day claim — plus workflow re-runs (the MOOG submit
step refuses a non-first attempt for the HEAD testnet with
`daily-head-rerun-refused`) and a second sequential dispatch of the MOOG
workflow (the census refusal `daily-head-already-submitted`; an unreadable
census is refused outright with `daily-head-census-unreadable`). Which ref
exists after each day-claim outcome:

| Guard | Outcome | Ref state afterwards |
|---|---|---|
| day claim | created | the day tag exists; the day is spent |
| day claim | already existed | nothing new; the day was already spent by the invocation that created it |
| day claim | push error | this run did not confirm creation — check `git ls-remote` before retrying; a concurrent winner is reported as `day-already-claimed`, and otherwise the day is unspent and a recovery dispatch may retry |

A push that git reports as *up-to-date* (an identical existing tag) creates
nothing and is treated as *already existed*. A **direct manual dispatch** of
`cardano-node.yaml` for the HEAD directory — including two dispatched at the
same moment — is an operator action outside this guarantee, exactly as it is
for Daily Amaru and the release-matrix testnets. The next UTC day starts
fresh.

### Validation mode (one hour)

`workflow_dispatch → validation` runs the same path with `duration=1` under
`refs/tags/daily-cardano-node-head/validation/<YYYY-MM-DD>` — a claim
namespace that cannot consume a production day claim, and a consumer commit
whose message carries the validation mode and the UTC day, so a validation
consumer SHA can never coincide with a production one. It requires
explicit operator authorization at run time (it is never scheduled) and
exists for the repository-required pre-merge validation of this path.

## Recovery

When a scheduled daily run fails, the receipt artifact names the stage that
stopped it (see *Receipt lookup* below). Recovery is manual, and follows the
ref-state table above:

- a failure **before the claim** (candidate stages, prepare-consumer,
  construct-request — a moved main is *not* one of them, the consumer is
  built on the exact run-base commit) can be retried the same day by
  dispatching the workflow with the **production** input — the day is still
  unclaimed;
- a **claim push error** left no ref this run could confirm: check
  `git ls-remote origin refs/tags/daily-cardano-node-head/<YYYY-MM-DD>` — if
  a concurrent invocation won it the receipt already says `day-already-claimed`,
  otherwise the day is unspent and the re-dispatch retries the claim;
- a failure **after the claim was created** (dispatch, await) leaves the day
  consumed by design; the same-day re-dispatch stops at `claim-day` with
  `day-already-claimed`. Fix forward and let the next UTC day's schedule run
  it;
- the #215 manual preparation (no inputs) remains available for isolating
  candidate-stage breakage without any submission boundary.

## Fail-closed stops

Preflight rejections exit non-zero with a stderr token before any
receipt exists: an unsupported mode (`unsupported mode: …`), a
non-executable transport (`transport is not executable: …`), an invalid UTC
day (`invalid UTC day: …`) and an unresolvable run base (`unresolved run
base: …`) — the latter two in the daily modes only. Every later
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
| `prepare-consumer` | the consumer commit cannot be created or is malformed | `consumer-failed`, `multi-line-consumer`, `malformed-consumer-sha`, plus the transport's `run base is unfetchable`, `run base checkout diverged` and `invalid run base` |
| `construct-request` | the dispatch identity cannot be constructed | `malformed-repository` |
| `claim-day` | the day is already claimed, the push fails, or the verdict is malformed | `day-already-claimed`, `claim-failed`, `malformed-claim-verdict` |
| `submit-run` | the dispatch is rejected or its run cannot be identified | `dispatch-failed`, `correlation marker is absent or unusable`, `dispatched run was not identifiable`, `dispatched run selection is ambiguous`, `multi-line-run-url`, `malformed-run-url` |
| `await-run` | the run cannot be awaited or its correlation is unusable | `await-failed`, `multi-line-correlation`, `malformed-correlation`, `run-not-terminal`, `outcome-nonterminal`, `malformed-report-url`, `malformed-moog-id` |

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
| `submission` | the `submit-candidate` record only in daily/validation modes; from `submit-candidate` on in manual/test modes |
| `day`, `claim_ref`, `duration`, `faults`, `consumer_repository`, `run_base` | daily and validation modes, always |
| `consumer_sha` | from `prepare-consumer` on (daily modes) |
| `request` | from `construct-request` on (daily modes) |
| `workflow_run` | from `submit-run` on (daily modes) |
| `moog_test_id`, `report_url`, `terminal_outcome` | the terminal `await-run` record only; `report_url` carries scheme, host and path — its query string (the signed auth capability) is stripped and never recorded anywhere |

A successful manual run ends with the `submit-candidate` record,
`outcome=PREPARED`, carrying all four agreeing identities. A successful daily
run ends with the `await-run` record, `outcome=TERMINAL`, correlating the UTC
day, upstream SHA, image tag and digest, consumer repository and commit,
workflow run URL, MOOG test id, report URL and terminal outcome
(`success` or `failure`) — a terminal test failure is still an honest terminal
run. Credentials never appear in a receipt,
log, or document: the hosted runs bind every token as step-level
environment and feed it to `docker login` on stdin, and the controller,
transport and receipt never see a credential value.

### Receipt lookup

Each hosted run uploads its receipt as the run artifact
`daily-cardano-node-head-receipt-<run id>` (the *Cardano Node HEAD candidate*
workflow, Actions tab). The dispatched MOOG run publishes its own
`moog-correlation` artifact (`test_run_id`, `phase`, `outcome`, `report_url`)
from the *Antithesis on cardano-node testnet* workflow, and the consumer
commit for a day is `refs/tags/daily-cardano-node-head/<YYYY-MM-DD>` in this
repository — three views of one correlated attempt. Whether a MOOG request
was constructed for a given consumer commit is visible in the MOOG census
itself (`moog facts test-runs`); a census refusal means no request was
constructed by that dispatch. Check the day tag with `git ls-remote` before
any manual action.
