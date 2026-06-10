# TypeSpec Generation Status

| # | Version | Status | Notes |
|---:|---|---|---|
| 1 | `2020-09-01-dataplanepreview` | ✅ Unblocked | 0 errors. |
| 2 | `2021-10-01-dataplanepreview` | 🔴 Blocked | → Issue 1. SDK constructs `ResourceManagementAssetReferenceDetails` (`entities/_assets/workspace_asset_reference.py`). |
| 3 | `2022-01-01-preview` | 🔴 Blocked | → Delta 1. TSP compiles 0 errors; SDK consumes local-only connection/credential types. |
| 4 | `2022-02-01-preview` | ✅ Unblocked | 0 errors. |
| 5 | `2022-10-01-preview` | 🔴 Blocked | → Delta 2, Delta 4. TSP compiles 0 errors; SDK consumes local-only `UserCreatedAcrAccount`/`UserCreatedStorageAccount` (Delta 2) and writes local-only `Registry.managedResourceGroupTags` (Delta 4). |
| 6 | `2022-12-01-preview` | 🔴 Blocked | Converges into v2022-10; blocked on row 5. |
| 7 | `2023-02-01-preview` | ✅ Unblocked | 0 errors. |
| 8 | `2023-04-01-preview` | 🔴 Blocked | → Issue 2. SDK imports `ImportDataAction` (`entities/_data_import/schedule.py:9`). |
| 9 | `2023-06-01-preview` | 🔴 Blocked | → Issue 2. SDK imports `DataImport`/`DatabaseSource`/`FileSystemSource` (`entities/_data_import/data_import.py:9-11`). |
| 10 | `2023-08-01-preview` | 🔴 Blocked | → Issue 4. SDK imports `ComputeInstance`/`ComputeInstanceProperties`/`ComputeInstanceSshSettings` (`entities/_compute/compute_instance.py:13-16`). |
| 11 | `2024-01-01-preview` | 🔴 Blocked | → Issue 4. SDK imports `ComputeInstanceDataMount` (`operations/_data_operations.py:29`, `operations/_datastore_operations.py:15`). |
| 12 | `2024-04-01-preview` | 🔴 Blocked | → Delta 3, Delta 5. Mechanical TSP-gen fixes known; plus `AccountKeyAuthTypeWorkspaceConnectionProperties.credentials` shape disagreement (LOCAL `WorkspaceConnectionSharedAccessSignature{sas}` vs upstream `WorkspaceConnectionAccountKey{key}` — Delta 5). |
| 13 | `2024-07-01-preview` | ⬜ Merged | |
| 14 | `2024-10-01-preview` | ⬜ Merged | |
| 15 | `2025-01-01-preview` | 🔴 Blocked | → Issue 3. 12 errors (10× `duplicate-operation` is the real blocker). |

## TSP generation issues — upstream fix proposals

| # | Issue | Rows | Possible upstream fix |
|---:|---|---|---|
| 1 | Discriminator collision on `AssetReferenceBase.referenceType` — value `"Id"` shared by `IdAssetReference` and `ResourceManagementAssetReferenceDetails`. | 2 | Rename `ResourceManagementAssetReferenceDetails.referenceType` upstream + service accepts new value. Alternative: drop `ResourceManagementAssetReferenceDetails` if it's a dead back-port and refactor SDK off it. |
| 2 | Discriminator collision on `DataVersionBaseProperties.dataType` — value `"uri_folder"` shared by `UriFolderDataVersion` and the `DataImport` cluster (`DataImport`/`DataImportSource`/`DatabaseSource`/`FileSystemSource`/`ImportDataAction`). | 8, 9, 12 | Rename the `DataImport`-cluster discriminator value upstream so both branches survive. Alternative: drop the cluster from v2023-04 / v2023-06 and refactor SDK onto v2023-08 / v2024-01. |
| 3 | 10× `@typespec/http/duplicate-operation` — 5 unique URL+verb collisions between sibling interfaces (`Feature` vs `Workspaces` on `/features`; `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` on `/endpoints/{name}`; `InferenceGroup.getStatus` vs `.getDeltaModelsStatusAsync` on `/getStatus`; etc.). | 15 | Decorate with `@sharedRoute` or restructure the offending interfaces so each `(path, verb)` pair is unique. |
| 4 | Converter emits `<{}>` empty body on `ComputeResource` (`is Azure.ResourceManager.Legacy.TrackedResourceWithOptionalLocation<{}>` + `// FIXME: ComputeResource has no properties property`). The `Compute` discriminator + all subtypes (`AmlCompute`, `ComputeInstance`, `PersonalComputeInstanceSettings`, `AssignedUser`, `ComputeInstanceSshSettings`, `ComputeSchedules*`, …) are defined in `models.tsp` but ORPHANED — the python emitter prunes them (137 missing exports in v2023-08 regen: 659 vs 796). Defect present in all 11 versioned `ComputeResource.tsp` files; only blocks rows whose SDK consumers import pruned `Compute*` symbols. | 10, 11 | Wire `Compute` onto `ComputeResource` in spec. The exact template arg (`TrackedResourceWithOptionalLocation<ComputeResourceSchema>` likely matches preview swagger `allOf: [Resource, ComputeResourceSchema]` semantics; alternatives possible), envelope props (`location`/`tags`/`sku`), and identity mixin all require service-team confirmation per version — preview/legacy wire contracts may differ from GA. |

## Delta issues

| # | Issue | Rows |
|---:|---|---|
| 1 | SDK constructs `WorkspaceConnectionPropertiesV2` + 7 auth subclasses + 5 credential POCOs (`entities/_credentials.py`, `entities/_workspace/connections/workspace_connection.py`) — local-only back-port. | 3 |
| 2 | SDK constructs `UserCreatedAcrAccount` + `UserCreatedStorageAccount` (`entities/_registry/registry_support_classes.py:19`, `entities/_registry/util.py:8`) — back-ported into local `registries.json`. | 5 |
| 3 | SDK uses `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` (`entities/_autogen_entities/models/_patch.py:26-27`) — present in v2024-01/v2024-07 swagger but dropped from v2024-04 only (looks like an unintentional regression). | 12 |
| 4 | SDK writes `Registry.managedResourceGroupTags` (`entities/_registry/registry.py:230`) — field present locally and forwarded to the service, missing in upstream `Registry` / `RegistryProperties`. | 5 |
| 5 | SDK builds `AccountKeyAuthTypeWorkspaceConnectionProperties` using `RestWorkspaceConnectionSharedAccessSignature(sas=self.account_key)` (`entities/_credentials.py:145`) — LOCAL declares `credentials: WorkspaceConnectionSharedAccessSignature{sas}`, upstream declares `credentials: WorkspaceConnectionAccountKey{key}`. SDK currently sends user's account key in a `sas` field. | 12 |
