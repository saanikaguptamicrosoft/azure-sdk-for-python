# TypeSpec migration — service-centric issue mapping

## Context

This document inverts the per-issue view in [typespec_deltas_service_review.md](./typespec_deltas_service_review.md) (Deltas 1–5) and [typespec_generation_issues_service_review.md](./typespec_generation_issues_service_review.md) (TSP 1–4) into a per-service view. A single Delta or TSP can affect multiple service owners (e.g. TSP 4 on `2025-01-01-preview` covers Workspace Features, Workspace Endpoints, and Inference Groups in one compile-errors log), so each row below is **one decision** for **one service team**. Where a single Delta/TSP produces decisions for multiple services, it is split across multiple rows.

## Service teams to engage — TSP issues

These are the decisions that **require service-team input** to unblock the TypeSpec migration (compile failures or generator defects that drop SDK-visible types). See [typespec_generation_issues_service_review.md](./typespec_generation_issues_service_review.md) for full evidence.

| Service area | TSPs | Affected API versions | Ticket to Service team |
|---|---|---|---|
| [Compute](#compute) | [TSP 3](./typespec_generation_issues_service_review.md#issue-3--converter-emits-empty--body-on-computeresourcetsp-orphan-pruning-the-compute-hierarchy) | 2023-08-01-preview, 2024-01-01-preview | https://portal.microsofticm.com/imp/v5/incidents/details/816303994/summary |
| [Workspace Endpoints / Deployments](#workspace-endpoints--deployments) | [TSP 4](./typespec_generation_issues_service_review.md#issue-4--2025-01-01-preview-sibling-interface-route-conflict-duplicate-operation) (#2, #3, #4) | 2025-01-01-preview | |
| [Inference Groups](#inference-groups) | [TSP 4](./typespec_generation_issues_service_review.md#issue-4--2025-01-01-preview-sibling-interface-route-conflict-duplicate-operation) (#5) | 2025-01-01-preview | |
| [Workspace Features](#workspace-features) | [TSP 4](./typespec_generation_issues_service_review.md#issue-4--2025-01-01-preview-sibling-interface-route-conflict-duplicate-operation) (#1) | 2025-01-01-preview | |
| [Workspace Assets / Asset Reference (MFE dataplane)](#workspace-assets--asset-reference-mfe-dataplane) | [TSP 1](./typespec_generation_issues_service_review.md#issue-1--2021-10-01-dataplanepreview-assetreferencebasereferencetype-discriminator-collision) | 2021-10-01-dataplanepreview | |
| [Data Import / Data Assets](#data-import--data-assets) | [TSP 2](./typespec_generation_issues_service_review.md#issue-2--2023-04-01-preview--2023-06-01-preview--2024-04-01-preview-dataversionbasepropertiesdatatype-discriminator-collision) | 2023-04-01-preview, 2023-06-01-preview, 2024-04-01-preview | |

**7 TSP-blocking decisions across 6 service areas.**

## Deltas — service mapping (reference only)

The deltas below are spec-vs-local-swagger drift the SDK currently relies on. They do **not** block the TypeSpec migration on their own — for each one, the SDK can absorb the regen by adjusting the entity layer (the local back-port is the workaround). Listed here for completeness; the migration does not need to wait on the service team to resolve them. See [typespec_deltas_service_review.md](./typespec_deltas_service_review.md) for full evidence.

| Service area | Deltas | Affected API versions |
|---|---|---|
| [Workspace Connections / Credentials](#workspace-connections--credentials) | [Delta 1](./typespec_deltas_service_review.md#delta-1--2022-01-01-preview-workspace-connection-auth-credentials), [Delta 5](./typespec_deltas_service_review.md#delta-5--2024-04-01-preview-accountkeyauthtypeworkspaceconnectionpropertiescredentials-shape-disagreement) | 2022-01-01-preview, 2024-04-01-preview |
| [Registry](#registry) | [Delta 2](./typespec_deltas_service_review.md#delta-2--2022-10-01-preview-registry-user-supplied-storage--acr), [Delta 3](./typespec_deltas_service_review.md#delta-3--2022-10-01-preview-registrymanagedresourcegrouptags) | 2022-10-01-preview |
| [Workspace Endpoints / Deployments](#workspace-endpoints--deployments) | [Delta 4](./typespec_deltas_service_review.md#delta-4--2024-04-01-preview-azure-openai-endpoint-deployment) | 2024-04-01-preview |

**5 deltas across 3 service areas.**

## Per-service detail

### Compute

| Source | API versions | Schema / field / route | Ask of service | Owner |
|---|---|---|---|---|
| [TSP 3](./typespec_generation_issues_service_review.md#issue-3--converter-emits-empty--body-on-computeresourcetsp-orphan-pruning-the-compute-hierarchy) | 2023-08-01-preview, 2024-01-01-preview | `ComputeResource` converter `FIXME` / empty `<{}>` body → `Compute` discriminated union + ~25 subtype models pruned (`ComputeInstance*`, `AssignedUser`, `PersonalComputeInstanceSettings`, `ComputeInstanceDataMount`, etc.) | Per version: confirm ARM envelope template (`TrackedResourceWithOptionalLocation<ComputeResourceSchema>` vs `ProxyResource<Compute>` vs other), whether `location` / `tags` / `sku` live on the envelope, and which identity mixin applies | TBD |

### Workspace Endpoints / Deployments

| Source | API versions | Schema / field / route | Ask of service | Owner |
|---|---|---|---|---|
| [Delta 4](./typespec_deltas_service_review.md#delta-4--2024-04-01-preview-azure-openai-endpoint-deployment) | 2024-04-01-preview | `OpenAIEndpointDeploymentResourceProperties` (discriminator subtype `"Azure.OpenAI"` of `EndpointDeploymentResourceProperties`) entirely missing upstream | Re-add the empty-body subtype (matches `2024-01` / `2024-07`) or confirm intentional removal and tell us what to use instead | TBD |
| [TSP 4 (#2)](./typespec_generation_issues_service_review.md#issue-4--2025-01-01-preview-sibling-interface-route-conflict-duplicate-operation) | 2025-01-01-preview | `GET /workspaces/{ws}/endpoints/{endpointName}` — `InferenceEndpoint.get` vs `EndpointResourcePropertiesBasicResource.get` | Disambiguate (`@sharedRoute` if same wire endpoint multiplexed on body, or restructure one onto a distinct sub-route) — both must survive in generated client | TBD |
| [TSP 4 (#3)](./typespec_generation_issues_service_review.md#issue-4--2025-01-01-preview-sibling-interface-route-conflict-duplicate-operation) | 2025-01-01-preview | `PUT /workspaces/{ws}/endpoints/{endpointName}` — `InferenceEndpoint.createOrUpdate` vs `EndpointResourcePropertiesBasicResource.createOrUpdate` | Same as above | TBD |
| [TSP 4 (#4)](./typespec_generation_issues_service_review.md#issue-4--2025-01-01-preview-sibling-interface-route-conflict-duplicate-operation) | 2025-01-01-preview | `GET /workspaces/{ws}/endpoints` — `InferenceEndpoint.list` vs `EndpointResourcePropertiesBasicResource.list` | Same as above | TBD |

### Inference Groups

| Source | API versions | Schema / field / route | Ask of service | Owner |
|---|---|---|---|---|
| [TSP 4 (#5)](./typespec_generation_issues_service_review.md#issue-4--2025-01-01-preview-sibling-interface-route-conflict-duplicate-operation) | 2025-01-01-preview | `POST /workspaces/{ws}/groups/{groupName}/getStatus` — `InferenceGroup.getStatus` vs `InferenceGroup.getDeltaModelsStatusAsync` | Disambiguate (`@sharedRoute` or distinct sub-route); both must survive | TBD |

### Workspace Features

| Source | API versions | Schema / field / route | Ask of service | Owner |
|---|---|---|---|---|
| [TSP 4 (#1)](./typespec_generation_issues_service_review.md#issue-4--2025-01-01-preview-sibling-interface-route-conflict-duplicate-operation) | 2025-01-01-preview | `GET /workspaces/{ws}/features` — `Workspace.list` (Workspace.tsp:135) vs `Feature.list` (Feature.tsp:37) | Disambiguate (`@sharedRoute` or distinct sub-route); both must survive | TBD |

### Workspace Connections / Credentials

| Source | API versions | Schema / field / route | Ask of service | Owner |
|---|---|---|---|---|
| [Delta 1](./typespec_deltas_service_review.md#delta-1--2022-01-01-preview-workspace-connection-auth-credentials) | 2022-01-01-preview | `Credentials` base + 5 subtypes (`ManagedIdentity`, `PersonalAccessToken`, `ServicePrincipal`, `SharedAccessSignature`, `UsernamePassword`) entirely missing upstream | Add to upstream swagger, or confirm the SDK should drop this code path | TBD |
| [Delta 5](./typespec_deltas_service_review.md#delta-5--2024-04-01-preview-accountkeyauthtypeworkspaceconnectionpropertiescredentials-shape-disagreement) | 2024-04-01-preview | `AccountKeyAuthTypeWorkspaceConnectionProperties.credentials` shape disagreement — local: `WorkspaceConnectionSharedAccessSignature{sas}`, upstream: `WorkspaceConnectionAccountKey{key}` | Confirm on-the-wire field name (`sas` or `key`) and align spec to the truth | TBD |

### Registry

| Source | API versions | Schema / field / route | Ask of service | Owner |
|---|---|---|---|---|
| [Delta 2](./typespec_deltas_service_review.md#delta-2--2022-10-01-preview-registry-user-supplied-storage--acr) | 2022-10-01-preview | `UserCreatedAcrAccount`, `UserCreatedStorageAccount` types + parent fields `AcrDetails.userCreatedAcrAccount`, `StorageAccountDetails.userCreatedStorageAccount` entirely missing upstream | Add 2 types + 2 parent properties, or confirm the BYO ACR / Storage path should be removed from SDK on this version | TBD |
| [Delta 3](./typespec_deltas_service_review.md#delta-3--2022-10-01-preview-registrymanagedresourcegrouptags) | 2022-10-01-preview | `Registry.managedResourceGroupTags` field present locally and actively written by SDK, missing upstream | Add to upstream `Registry` / `RegistryProperties`, or confirm the SDK should stop forwarding user tags to the managed resource group | TBD |

### Workspace Assets / Asset Reference (MFE dataplane)

| Source | API versions | Schema / field / route | Ask of service | Owner |
|---|---|---|---|---|
| [TSP 1](./typespec_generation_issues_service_review.md#issue-1--2021-10-01-dataplanepreview-assetreferencebasereferencetype-discriminator-collision) | 2021-10-01-dataplanepreview | `AssetReferenceBase.referenceType` discriminator collision — value `"Id"` shared by `IdAssetReference` and `ResourceManagementAssetReference` (`x-ms-client-name: ResourceManagementAssetReferenceDetails`) | Rename one side's discriminator value (suggested: `"ResourceManagementId"` on `ResourceManagementAssetReference`) and update the service to accept the new on-the-wire value | TBD |

### Data Import / Data Assets

| Source | API versions | Schema / field / route | Ask of service | Owner |
|---|---|---|---|---|
| [TSP 2](./typespec_generation_issues_service_review.md#issue-2--2023-04-01-preview--2023-06-01-preview--2024-04-01-preview-dataversionbasepropertiesdatatype-discriminator-collision) | 2023-04-01-preview, 2023-06-01-preview, 2024-04-01-preview | `DataVersionBaseProperties.dataType` discriminator collision — value `"uri_folder"` shared by `UriFolderDataVersion` and `DataImport`; companion types `DataImportSource`, `DatabaseSource`, `FileSystemSource`, `ImportDataAction` blocked by the same collision | Rename `DataImport`'s discriminator value (suggested: `"data_import"`) across all 3 versions and update the service to accept the new on-the-wire value | TBD |
