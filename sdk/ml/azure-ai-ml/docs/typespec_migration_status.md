# TypeSpec Migration — Status Tracker

Per-version migration status for `azure-ai-ml`. Versions and scope decisions come from [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md).

**Status legend**

| # | API version | Status | PR link | Comment | Test links |
|---|---|---|---|---|---|
| 1 | 2020-09-01-dataplanepreview | Not Started ⚪ | — | TSP required ||
| 2 | 2021-10-01-dataplanepreview | Unblocked ✅ | — | TSP applied: `ResourceManagementAssetReferenceDetails.referenceType` discriminator value renamed `"Id"` → `"ResourceManagementId"` to disambiguate from `IdAssetReference.referenceType="Id"`. **Wire-affecting — flagged in PR description for service-team review.** ||
| 3 | 2022-01-01-preview | Blocked ❌ | — | TSP required and delta changes exist, need Fareed's inputs ||
| 4 | 2022-02-01-preview | Not Started ⚪ | — | TSP required ||
| 5 | 2022-10-01-preview | Blocked ❌ | — | TSP required and delta changes exist, need Fareed's inputs ||
| 6 | 2022-12-01-preview | Blocked ❌ | — | Converge into v2022-10-01-preview ||
| 7 | 2023-02-01-preview | Not Started ⚪ | — | TSP required ||
| 8 | 2023-04-01-preview | Unblocked ✅ | — | TSP applied: dropped `DataImport` cluster + dropped back-compat `Workspaces.workspaceFeaturesList` op (operationId `WorkspaceFeatures_List`) in favour of dedicated `Features.list` op. **Wire-affecting (back-compat op removed) — flagged in PR description.** ||
| 9 | 2023-06-01-preview | Unblocked ✅ | — | TSP applied: same fix-set as row 8 (DataImport drop + `WorkspaceFeatures_List` op drop). **Wire-affecting (back-compat op removed) — flagged in PR description.** ||
| 10 | 2023-08-01-preview | Unblocked ✅ | — | TSP applied: row 8 fix-set + `PatchModel = {}` on `InferenceEndpoint` (standalone `ArmCustomPatchAsync` rejects `void`). **Wire-affecting (back-compat op removed) — flagged in PR description.** ||
| 11 | 2024-01-01-preview | Unblocked ✅ | — | TSP applied: row 10 fix-set + `ActionAsyncBase`→`ActionAsync` rewrite (5 ops files) + dropped colliding `get`/`createOrUpdate`/`list` ops from `EndpointResourcePropertiesBasicResources` interface (`Endpoint_Get`/`Endpoint_CreateOrUpdate`/`Endpoint_List`) in favour of dedicated `InferenceEndpoints` interface at `/endpoints`. Unique ops (`listKeys`/`getModels`/`regenerateKeys`) preserved. **Multiple wire-affecting changes — flagged in PR description.** ||
| 12 | 2024-04-01-preview | Blocked ❌ | — | TSP-gen architectural fixes are now known (apply row 11 set) BUT an SDK-consumed delta remains: `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` (REMOTE has them in v2024-01 and v2024-07 but dropped in v2024-04 only). Needs Fareed's input on SDK-side; see [typespec_generation_status.md](typespec_generation_status.md) row 12 ||
| 13 | 2024-07-01-preview | Merged ✅ | https://github.com/Azure/azure-sdk-for-python/pull/47349 | Converged into 2024-10-01-preview ||
| 14 | 2024-10-01-preview | Merged ✅ | https://github.com/Azure/azure-sdk-for-python/pull/47349 | TSP was present |https://github.com/Azure/azureml-examples/pull/3997 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 15 | 2025-01-01-preview | Blocked ❌ | — | TSP-gen architectural (duplicate routes + missing paging items, needs service-team); see [typespec_generation_status.md](typespec_generation_status.md) row 15 ||
