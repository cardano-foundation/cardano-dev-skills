# Handle a New Governance Action Type

:::note
Line references on this page point to commit `6522bd4` of the `develop` branch. Line numbers may have moved in newer commits.
:::

## Overview

This document describes the process of adding a new governance action type. The steps below cover the frontend's create form. A new type also has to be known to the data contract, every chain-data provider, the backend, the frontend's display and voting rules, and the proposal discussion forum. [Beyond the create form](#beyond-the-create-form) lists those places.

## Prerequisites

Every governance action should follow the [CIP-100](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0100) and [CIP-108](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0108) standards.

Person to contact: @mesudip

## Packages

The create form is in `govtool/frontend`. The rest of the change spans `govtool/govtool-data-providers`, `govtool/govtool-provider-dbsync`, `govtool/govtool-provider-koios`, `govtool/govtool-provider-blockfrost`, `govtool/govtool-provider-fixture`, `govtool/govtool-backend`, the forum UI in `govtool/frontend/src/pdf-ui` and its backend in `govtool/govtool-pdf-backend`.

## Steps

### Type declarations

1. Add new `GovernanceActionType` enum property to [`govtool/frontend/src/types/governanceAction.ts`](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/types/governanceAction.ts#L4).
2. If the governance action requires a new field component - add it to the [`GovernanceActionField`](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/types/governanceAction.ts#L14) enum.
3. Create a new governance action field schema. Every governance action schema should extend from the [SharedGovernanceActionFieldSchema](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/types/governanceAction.ts#L31).
4. Add the new governance action schema below the [SharedGovernanceActionFieldSchema](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/types/governanceAction.ts#L31).
5. Add a new governance action schema to the union type of [GovernanceActionFieldSchemas](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/types/governanceAction.ts#L70).
6. Add the new type to the [GovernanceActionFields](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/types/governanceAction.ts#L78) record, and to the matching type casts in `CreateGovernanceActionForm.tsx`. The record lists its types explicitly, so the compiler does not require it: a missed type compiles, shows up as a choice in the form, and crashes on the form's fields step.
7. Add a builder for the new type in `CardanoProvider` ([`context/wallet.tsx`](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/context/wallet.tsx)) and wire it into [`useCreateGovernanceActionForm.ts`](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/hooks/forms/useCreateGovernanceActionForm.ts).
8. Update this page (`docs/docs/developers/operations/handle-new-governance-action-type.md`) with all the new declarations provided (eg.: line numbers, new types configurations).

### Fields declaration

1. Add new governance action field declaration to the [GOVERNANCE_ACTION_FIELDS](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/consts/governanceAction/fields.ts#L98) object.

### Custom validations

If a field needs custom validation, add a validator function under `src/utils/` (for example [`numberValidation`](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/utils/numberValidation.ts#L9)), export it from `src/utils/index.ts`, and reference it in the field's `rules.validate` in [`consts/governanceAction/fields.ts`](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/consts/governanceAction/fields.ts).

### Constants & Fields definitions

[GovernanceActionFieldSchemas](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/types/governanceAction.ts#L70) - includes all the governance action field schemas which are:

- component - the component which should be used to render the field (currently supporting are: 'Input', 'TextArea' and array of both of them).
- labelI18nKey - the i18n key for the field label.
- placeholderI18nKey - the i18n key for the field placeholder.
- tipI18nKey - the i18n key for the field tip.
- rules - the array of validation rules for the field [check rules property in react-hook-form](https://www.react-hook-form.com/api/usecontroller/controller/#:~:text=cleared%20value%20instead.-,rules,-Object).

[SharedGovernanceActionFieldSchema](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/types/governanceAction.ts#L31) - includes all the shared fields for the governance action - each field is of type [FieldSchema](https://github.com/IntersectMBO/govtool/blob/6522bd43ee52c5de9fe5f9ab0fb14f56858ff0ef/govtool/frontend/src/types/governanceAction.ts#L19) which corresponds to [CIP-108](https://github.com/cardano-foundation/CIPs/pull/632).

### How this works

Every governance action field is a part of the governance action schema.
The schema is used to render appropriate fields in a [form](https://github.com/IntersectMBO/govtool/blob/develop/govtool/frontend/src/components/organisms/CreateGovernanceActionSteps/CreateGovernanceActionForm.tsx).
Logic behind validation and hashing is also based on the schema and is handled in the [useCreateGovernanceActionForm](https://github.com/IntersectMBO/govtool/blob/develop/govtool/frontend/src/hooks/forms/useCreateGovernanceActionForm.ts).

Defining the new Governance action type in [Type declarations](#type-declarations) will allow the application to handle the new governance action type.

Defining the new Governance action field in [Fields declaration](#fields-declaration) will allow the application to render the new governance action field.

They both are used in the [CreateGovernanceActionForm](https://github.com/IntersectMBO/govtool/blob/develop/govtool/frontend/src/components/organisms/CreateGovernanceActionSteps/CreateGovernanceActionForm.tsx) component.

### Testing

After defining a new governance action type and field, it is important to test the new governance action type and field in the [CreateGovernanceActionForm](https://github.com/IntersectMBO/govtool/blob/develop/govtool/frontend/src/components/organisms/CreateGovernanceActionSteps/CreateGovernanceActionForm.tsx) component.

On the application it is approachable under `/create_governance_action` route.

## Beyond the create form

Paths are relative to the repository root on `develop`. A step marked *silent* compiles and passes the unit tests when it is missed, so check each one by hand.

### Data contract (`govtool/govtool-data-providers`)

1. `GovActionType` and `GovActionBody` in `src/chain-data/governance/proposals.ts`.
2. `GovActionLineage` in `src/chain-data/refs.ts`, if the type has its own lineage, and the thresholds in `src/chain-data/network.ts`, if it has its own threshold parameter.
3. `SPEC.md`, §5.2 Proposals.
4. The `bodies` array in `test/conformance.ts` (*silent*).

Rebuild the contract before touching a provider (see `govtool/AGENTS.md`, "Build order").

### Chain-data providers

Each provider maps the type in both directions. The compiler catches the exhaustive half and misses the rest.

- db-sync (`govtool/govtool-provider-dbsync/src/governance`): `DB_TO_TYPE` in `proposals/body.ts` and the `ACTION_TYPES` maps in `dreps/map.ts` and `pools.ts` throw for an unknown type, so every list that contains the new action, and every DRep or pool vote on it, answers 500. Also `TYPE_TO_DB` and `decodeBody` in `proposals/body.ts`, `LINEAGE_DB_TYPES` (*silent*), the thresholds in `proposals/aggregates.ts`, and the string comparisons and SQL literals in `proposals/aggregates.ts`, `proposals.ts`, `dreps/`, `pools.ts` and `committee/` (*silent*).
- Koios (`govtool/govtool-provider-koios/src`): the union in `rows.ts`, both maps and the switch in `governance/proposals/body.ts`, its lineage list and the lineage lists in `governance/committee.ts` (*silent*), the InfoAction bootstrap rule in `governance/dreps.ts`, and `governance/proposals/aggregates.ts`.
- Blockfrost (`govtool/govtool-provider-blockfrost/src/governance`): `proposals/body.ts` (snake_case names), its lineage list and `committee.ts` (*silent*), the `TYPES` list in `proposals.ts` (*silent*; without it, filtering by the type is rejected as invalid input), the hard-fork and InfoAction bootstrap rules in `dreps/votes.ts`, and `proposals/aggregates.ts`.
- Fixture: `govtool/govtool-provider-fixture/src/chain-data.ts`, and `scripts/capture.mjs`, which records an unknown type as `InfoAction` (*silent*).

A type with its own threshold parameter also needs it in each provider's `src/network.ts`, in the backend's `epoch/epoch.service.ts` and `epoch/epoch.type.ts` (the legacy `/epoch/params` shape, pinned by `test/legacy-shape.spec.ts`; *silent*), and in the frontend's `models/api.ts`, `models/wallet.ts` and `consts/index.ts`.

After changing a mapper, run `npm run verify` and the provider's live script against a real source.

### Backend (`govtool/govtool-backend/src`)

1. `governanceActionTypes` in `proposal/proposal.type.ts`: the legacy wire names, which also validate the type filters on `/proposal/list`, the DRep votes route and `/governance-actions`.
2. `LEGACY_TYPE` in `proposal/proposal.service.ts`, and `LINEAGE_OF` there (*silent*: it falls back to the hard-fork lineage, so `/proposal/enacted-details` returns the wrong previous action).
3. `governance-actions/governance-actions.mapping.ts`. The value must also be in the wire list, or the filter never matches (*silent*).
4. `common/legacy-description.ts`, plus a `test/legacy-shape.spec.ts` case for the new description shape.

### Frontend display and voting (`govtool/frontend/src`)

- `utils/getGovActionVotingThresholdKey.ts`.
- `consts/governanceAction/filters.ts` and `consts/governanceActionHistory.ts`, the two filter lists (*silent*). The history list's `dataTestId`s are used by Playwright.
- `context/featureFlag.tsx`: which voter groups vote on the type and which totals show, in bootstrap and full governance (*silent*).
- `components/organisms/GovernanceActionVoting.tsx`, `components/organisms/GovernanceActionDetailsCardData.tsx`, `components/organisms/GovernanceActionHistoryDetails.tsx` and `components/molecules/VotesSubmitted.tsx` (*silent*).
- `i18n/locales/en.json`: the type label, tooltips, errors and history filter labels.

### Proposal discussion forum

- `govtool/frontend/src/pdf-ui/components/SubmissionGovernanceAction/Steps/InformationStorageStep.jsx` picks the wallet builder by forum type id in an `if` chain with no `else`, so an unknown type submits nothing (*silent*). The ids come from `govtool/govtool-pdf-backend/src/seed/lookups.data.ts`.
- The forum also branches on the type id in `components/CreationGoveranceAction/Step2.jsx`, `Step3.jsx` and `HardForkManager.jsx`, `components/CreateGovernanceActionDialog/index.jsx`, `components/EditProposalDialog/index.jsx` and `pages/ProposedGovernanceActions/SingleGovernanceAction/index.jsx` (all under `govtool/frontend/src/pdf-ui`). The ids and names in `lookups.data.ts` also feed Playwright test ids.
- `govtool/frontend/src/pdf-ui/lib/api.js` asks for the previous hard fork by type name (`getHardForkData`) through the forum backend's proxy. The proxy allows only listed paths but forwards any query string, so a new type name needs no proxy change.
- The forum backend (`govtool/govtool-pdf-backend`) rejects a proposal whose type id is not seeded, so add the type to `src/seed/lookups.data.ts`. A type with its own fields also needs parsing and validation in `src/proposals/proposal-input.ts`, which branches on the type ids, persistence in `proposals.service.ts`, serialization in `proposal-item.ts` and `proposal.resources.ts`, a model and migration in `prisma/schema.prisma`, its populate paths in `proposal.allowlists.ts`, and `SPEC.md`; without them the fields are not stored.

### Tests and tools that list every type

`tests/govtool-backend/test_cases/test_contract_core.py`, `tests/govtool-frontend/playwright/lib/helpers/featureFlag.ts` (a copy of the `featureFlag.tsx` rules), the four type enums in `tests/govtool-frontend/playwright/lib/types.ts`, `proposalTypes` in `tests/load-testing/src/test/java/org/cardano/govtool/feeders/PageVisits.java`, `DEVNET_SEED_ACTIONS` in `tests/devnet/.env.devnet` and its mapping in `tests/devnet/seed.sh` (adaup's devnet smoke `--actions` must support the type), `gov-action-loader/backend/app/transaction.py`, the builder list in `docs/docs/developers/governance-action-submission.md`, and the user pages under `docs/docs/cardano-govtool/using-govtool/governance-actions/`.
