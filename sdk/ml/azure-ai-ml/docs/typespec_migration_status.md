# TypeSpec Migration — Status Tracker

Per-version migration status for `azure-ai-ml`. Versions and scope decisions come from [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md).

**Status legend:** ✅ Unblocked · 🔴 Blocked · ⬜ Merged · ⚪ Not Started

A row is **Blocked** only when the TSP cannot be used to generate a client the SDK can actually consume. Two blocker classes are called out in the Comment column: **delta issue** (SDK depends on types not present in the standard TSP — needs service-team / Fareed input) and **TSP generation issue** (TSP cannot be made wire-correct mechanically — needs service-team / Kashif input). A row can have both.

| # | API version | Status | PR link | Comment | Test links |
|---|---|---|---|---|---|
| 1 | 2020-09-01-dataplanepreview | ⚪ Not Started | — | TSP required ||
| 2 | 2021-10-01-dataplanepreview | 🔴 Blocked | — | **Delta issue + TSP generation issue.** SDK actively constructs `ResourceManagementAssetReferenceDetails` in `entities/_assets/workspace_asset_reference.py`. The only mechanical TSP fix (discriminator value rename `"Id"` → `"ResourceManagementId"` on the conflicting sibling) is wire-affecting, so the generated client would emit a different `referenceType` than the live service accepts. Candidate TSP pushed to `saanika/tsp_generare` for service-team review; see [typespec_generation_status.md](typespec_generation_status.md) row 2. ||
| 3 | 2022-01-01-preview | 🔴 Blocked | — | **Delta issue.** SDK consumes local-only `WorkspaceConnectionPropertiesV2` + 7 auth subclasses + 5 credential POCOs via `entities/_credentials.py`. Standard TSP doesn't expose these; needs decision to back-port them or refactor SDK onto a newer connection type ||
| 4 | 2022-02-01-preview | ⚪ Not Started | — | TSP required ||
| 5 | 2022-10-01-preview | 🔴 Blocked | — | **Delta issue.** SDK consumes local-only `UserCreatedAcrAccount` + `UserCreatedStorageAccount` back-ported into registries.json. Standard TSP doesn't expose them ||
| 6 | 2022-12-01-preview | 🔴 Blocked | — | Convergence into row 5 (v2022-10) — blocked on row 5 ||
| 7 | 2023-02-01-preview | ⚪ Not Started | — | TSP required ||
| 8 | 2023-04-01-preview | ✅ Unblocked | — | TSP applied: dropped `DataImport` cluster + dropped back-compat `Workspaces.workspaceFeaturesList` op (operationId `WorkspaceFeatures_List`) in favour of dedicated `Features.list`. SDK has no call sites for the dropped op (verified by grep). **Wire-affecting (back-compat op removed) — flagged in PR description for service-team review.** ||
| 9 | 2023-06-01-preview | ✅ Unblocked | — | TSP applied: same fix-set as row 8. SDK has no call sites for the dropped op. **Wire-affecting — flagged in PR description.** ||
| 10 | 2023-08-01-preview | ✅ Unblocked | — | TSP applied: row 8 fix-set + `PatchModel = {}` on `InferenceEndpoint` (standalone `ArmCustomPatchAsync` rejects `void`). **Wire-affecting — flagged in PR description.** ||
| 11 | 2024-01-01-preview | ✅ Unblocked | — | TSP applied: row 10 fix-set + `ActionAsyncBase`→`ActionAsync` rewrite (5 ops files) + dropped colliding `get`/`createOrUpdate`/`list` ops from `EndpointResourcePropertiesBasicResources` interface (operationIds `Endpoint_Get`/`Endpoint_CreateOrUpdate`/`Endpoint_List`) in favour of dedicated `InferenceEndpoints` interface at `/endpoints`. Unique ops (`listKeys`/`getModels`/`regenerateKeys`) preserved. SDK has no call sites for any dropped op (verified by grep). **Multiple wire-affecting changes — flagged in PR description.** ||
| 12 | 2024-04-01-preview | 🔴 Blocked | — | **Delta issue + TSP generation issue.** TSP-gen fixes are now known (apply row 11 fix-set). Remaining delta: SDK consumes `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` (REMOTE has them in v2024-01 and v2024-07 but dropped in v2024-04 only). See [typespec_generation_status.md](typespec_generation_status.md) row 12 ||
| 13 | 2024-07-01-preview | ⬜ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47349 | Converged into 2024-10-01-preview ||
| 14 | 2024-10-01-preview | ⬜ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47349 | TSP was present |https://github.com/Azure/azureml-examples/pull/3997 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 15 | 2025-01-01-preview | 🔴 Blocked | — | **TSP generation issue.** 10× `@typespec/http/duplicate-operation` (5 unique URL+verb collisions) + 2× `missing-paging-items`. Genuine swagger-design ambiguity, not a converter artefact; needs service-team call on `@sharedRoute`, sub-route restructure (as in Kashif's GA TSP), or upstream swagger fix. Also tracked upstream in PR https://github.com/Azure/azure-rest-api-specs/pull/43779. See [typespec_generation_status.md](typespec_generation_status.md) row 15 ||
