# Overview

This document describes the process of adding a new governance action type to the frontend application.

## Prerequisites

Every governance action should follow the [CIP-100](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0100) and [CIP-108](https://github.com/cardano-foundation/CIPs/pull/632) (currently on a PR stage) standards.

Person to contact: @mesudip

## Package

All the related changes are to be made under the `govtool/frontend` directory.

## Steps

### Type declarations

1. Add new `GovernanceActionType` enum property to the `govtool/frontend/src/types/governanceAction.ts:4`.
2. If the governance action requires a new field - add it to the `govtool/frontend/src/types/governanceAction.ts:8`.
3. Create a new governance action field schema. Every governance action schema should extend from the [SharedGovernanceActionFieldSchema](govtool/frontend/src/types/governanceAction.ts:25).
4. Add a new governance action schema to the below the [SharedGovernanceActionFieldSchema](govtool/frontend/src/types/governanceAction.ts:25).
5. Add a new governance action schema to the union type of [GovernanceActionFieldSchemas](govtool/frontend/src/types/governanceAction.ts:40).
6. Update the `docs/oprations/HANDLE_NEW_GOVERNANCE_ACTION_TYPE.md` with all the new declarations provided (eg.: line numbers, new types configurations).

### Fields declaration

1. Add new governance action field declaration to the [GOVERNANCE_ACTION_FIELDS](govtool/frontend/src/constants/governanceActionFields.ts:88) object.

### Custom validations

If the field require some custom validation, add a new validation function to the [Validations](govtool/frontend/src/utils/govActionValidations/index.ts:4) object.

### Constants & Fields definitions

[GovernanceActionFieldSchemas](govtool/frontend/src/types/governanceAction.ts:40) - includes all the governance action field schemas which are:

- component - the component which should be used to render the field (currently supporting are: 'Input', 'TextArea' and array of both of them).
- labelI18nKey - the i18n key for the field label.
- placeholderI18nKey - the i18n key for the field placeholder.
- tipI18nKey - the i18n key for the field tip.
- rules - the array of validation rules for the field [check rules property in react-hook-form](https://www.react-hook-form.com/api/usecontroller/controller/#:~:text=cleared%20value%20instead.-,rules,-Object).

[SharedGovernanceActionFieldSchema](govtool/frontend/src/types/governanceAction.ts:25) - includes all the shared fields for the governance action - each field is of type [FieldSchema](govtool/frontend/src/types/governanceAction.ts:14) which corresponds to [CIP-108](https://github.com/cardano-foundation/CIPs/pull/632).

### How this works

Every governance action field is a part of the governance action schema.
The schema is used to render appropriate fields in a [form](govtool/frontend/src/components/organisms/CreateGovernanceActionSteps/CreateGovernanceActionForm.tsx).
Logic behind validation and hashing is also based on the schema and is handled in the [useCreateGovernanceActionForm](govtool/frontend/src/hooks/forms/useCreateGovernanceActionForm.ts).

Defining the new Governance action type in [Type declarations](#type-declarations) will allow the application to handle the new governance action type.

Defining the new Governance action field in [Fields declaration](#fields-declaration) will allow the application to render the new governance action field.

They both are used in the [CreateGovernanceActionForm](govtool/frontend/src/components/organisms/CreateGovernanceActionSteps/CreateGovernanceActionForm.tsx) component.

### Testing

After defining a new governance action type and field, it is important to test the new governance action type and field in the [CreateGovernanceActionForm](govtool/frontend/src/components/organisms/CreateGovernanceActionSteps/CreateGovernanceActionForm.tsx) component.

On the application it is approachable under `/create_governance_action` route.
