# TypeSpec Migration — Status Tracker

Per-version migration status for `azure-ai-ml`. Versions and scope decisions come from [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md).

**Status legend**

| # | API version | Status | PR link | Comment | Test links |
|---|---|---|---|---|---|
| 1 | 2020-09-01-dataplanepreview | Not Started ⚪ | — | TSP required ||
| 2 | 2021-10-01-dataplanepreview | Blocked ❌ | — | TSP-gen mechanical fix known (`Id` discriminator rename verified clean) but changes wire-protocol discriminator value — needs service-team approval; see [typespec_generation_status.md](typespec_generation_status.md) row 2 ||
| 3 | 2022-01-01-preview | Blocked ❌ | — | TSP required and delta changes exist, need Fareed's inputs ||
| 4 | 2022-02-01-preview | Not Started ⚪ | — | TSP required ||
| 5 | 2022-10-01-preview | Blocked ❌ | — | TSP required and delta changes exist, need Fareed's inputs ||
| 6 | 2022-12-01-preview | Blocked ❌ | — | Converge into v2022-10-01-preview ||
| 7 | 2023-02-01-preview | Not Started ⚪ | — | TSP required ||
| 8 | 2023-04-01-preview | Blocked ❌ | — | TSP-gen architectural — mechanical `DataImport` drop exposes `Workspace.list` vs `Feature.list` `duplicate-operation` (same family as row 15); see [typespec_generation_status.md](typespec_generation_status.md) row 8 ||
| 9 | 2023-06-01-preview | Blocked ❌ | — | TSP-gen architectural — same `duplicate-operation` after mechanical fix as row 8 (same family as row 15); see [typespec_generation_status.md](typespec_generation_status.md) row 9 ||
| 10 | 2023-08-01-preview | Blocked ❌ | — | TSP-gen architectural — same `duplicate-operation` after mechanical fix as row 8 (also needs `PatchModel = {}` workaround — `void` rejected by standalone `ArmCustomPatchAsync`); see [typespec_generation_status.md](typespec_generation_status.md) row 10 ||
| 11 | 2024-01-01-preview | Blocked ❌ | — | TSP-gen architectural — mechanical `DataImport` drop + `PatchModel = {}` + `ActionAsyncBase→ActionAsync` rewrite exposes 8 `duplicate-operation` errors (row 8 set + `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` on `/endpoints`); see [typespec_generation_status.md](typespec_generation_status.md) row 11 ||
| 12 | 2024-04-01-preview | Blocked ❌ | — | TSP-gen architectural (same `duplicate-operation` set as row 11) AND SDK-consumed delta — needs both service-team and Fareed's inputs; see [typespec_generation_status.md](typespec_generation_status.md) row 12 ||
| 13 | 2024-07-01-preview | Merged ✅ | https://github.com/Azure/azure-sdk-for-python/pull/47349 | Converged into 2024-10-01-preview ||
| 14 | 2024-10-01-preview | Merged ✅ | https://github.com/Azure/azure-sdk-for-python/pull/47349 | TSP was present |https://github.com/Azure/azureml-examples/pull/3997 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 15 | 2025-01-01-preview | Blocked ❌ | — | TSP-gen architectural (duplicate routes + missing paging items, needs service-team); see [typespec_generation_status.md](typespec_generation_status.md) row 15 ||
