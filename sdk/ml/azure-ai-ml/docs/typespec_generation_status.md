# TypeSpec Generation Status

Row numbers `1-15` correspond to the table in [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md) for cross-referencing.

**Scope:** TSPs are generated locally under `docs/generated-tsp/` from swaggers mirrored at `docs/swagger-remote/` (REMOTE/ARM) and `docs/swagger-local/` (LOCAL/data-plane). Nothing in `azure-rest-api-specs` is touched yet — clean TSP folders will be copy-pasted upstream once they compile with zero errors.

**Mechanical converter quirks already fixed in-place:** `@identifiers` decorator on non-array props (removed), `` `package` `` keyword escaping, missing `;` on `@@doc` augment lines and `back-compatible.tsp` `@@clientName` / `@@clientLocation` lines, `any` / `AnyObject` → `unknown`, `import` keyword escape.

| # | Version | Status | Errors / Notes |
|---:|---|---|---|
| 1 | `2020-09-01-dataplanepreview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 2 | `2021-10-01-dataplanepreview` | ✅ Unblocked | 2 errors — `invalid-discriminator-value: "Id"` collision: `ResourceManagementAssetReferenceDetails` and `IdAssetReference` both declare `referenceType: "Id"` on `AssetReferenceBase`. Same shape as the `uri_folder` issue below; no GA TSP to cross-reference (data-plane preview), but mechanical drop/rename of one sibling resolves it. |
| 3 | `2022-01-01-preview` | 🟦 Delta — awaiting Fareed | TSP compiles 0 errors. SDK consumes local-only `WorkspaceConnectionPropertiesV2` + 7 auth subclasses + 5 credential POCOs via `entities/_credentials.py`. Needs service-team decision on whether to back-port these into the TSP or refactor SDK onto a newer version's connection types. |
| 4 | `2022-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 5 | `2022-10-01-preview` | 🟦 Delta — awaiting Fareed | TSP compiles 0 errors. SDK consumes local-only `UserCreatedAcrAccount` + `UserCreatedStorageAccount` (back-ported into registries.json). Needs service-team decision on whether to upstream these into the TSP. |
| 6 | `2022-12-01-preview` | 🟦 Blocked on 5th | To be converged into 5th API version |
| 7 | `2023-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 8 | `2023-04-01-preview` | ✅ Unblocked | 2 errors — `invalid-discriminator-value: "uri_folder"` collision (`DataImport` vs `UriFolderDataVersion`). **Fix pattern from Kashif's GA TSP** (`MachineLearningServices.Management/models.tsp`): GA omits `DataImport` entirely from `DataVersionBaseProperties` siblings. Apply same drop. |
| 9 | `2023-06-01-preview` | ✅ Unblocked | 2 errors — same `uri_folder` collision as row 8; same drop-`DataImport` fix from Kashif's GA TSP. |
| 10 | `2023-08-01-preview` | ✅ Unblocked | 3 errors — `uri_folder` (×2, same as row 8) + 1× `ArmCustomPatchAsync<InferenceEndpoint, PatchModel = unknown>`. **Fixes from Kashif's GA TSP:** (a) drop `DataImport`; (b) replace `PatchModel = unknown` with `PatchModel = void` plus `@patch(#{ implicitOptionality: false })` and a `patch-envelope` suppress (matches GA `InferenceEndpoint.tsp` line 126). |
| 11 | `2024-01-01-preview` | ✅ Unblocked | 13 errors — `uri_folder` (×2) + `PatchModel` (×1) + 10× phantom `Azure.ResourceManager.Foundations.ActionAsyncBase` refs across 5 versioned-ops files (`CodeVersion.tsp`, `ComponentVersion.tsp`, `DataVersionBase.tsp`, `EnvironmentVersion.tsp`, `ModelVersion.tsp`). **Fixes:** (a) drop `DataImport` (row 8 pattern); (b) `PatchModel = void` (row 10 pattern); (c) rewrite the 5 ops files using `alias XOps = Azure.ResourceManager.Legacy.LegacyOperations<...>` + standard `XOps.ActionAsync<>` / `ActionSync<>` calls — pattern lifted from Kashif's preview TSP `MachineLearningServices.Management.v2025_01_01_preview` (already covers all 5 files; adapt the operation list to this preview's swagger). |
| 12 | `2024-04-01-preview` | 🟦 Delta — awaiting Fareed | TSP compiles 13 errors (same mix as row 11 — all unblockable via row 11 fixes). The blocking item is the SDK delta: SDK consumes local-only `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` in `entities/_autogen_entities/models/_patch.py` (REMOTE has them in v2024-01 and v2024-07 but dropped in v2024-04 only). Needs service-team decision on whether to back-port into TSP or refactor SDK onto v2024-07. |
| 13 | `2024-07-01-preview` | ⬜ Merged |  |
| 14 | `2024-10-01-preview` | ⬜ Merged | |
| 15 | `2025-01-01-preview` | 🔴 Blocked — architectural | 12 errors — 10× `@typespec/http/duplicate-operation` (5 unique URL+verb collisions between siblings: e.g. `Feature` vs `Workspace`'s `/features`; `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` `/endpoints/{name}`; `InferenceGroup` `getStatus` vs `getDeltaModelsStatusAsync` on same `/getStatus`) + 2× `missing-paging-items` (`InferenceGroup.listDeltaModelsAsync`, `RaiBlocklistPropertiesBasicResource.addBulk` — missing `@pageItems` on paged response). Genuine swagger-design ambiguity, not a converter artefact: needs service-team call on `@sharedRoute`, sub-route restructure (as in Kashif's GA TSP), or upstream swagger fix. Also tracked upstream in PR https://github.com/Azure/azure-rest-api-specs/pull/43779 (branch `saanika/tsp`). |

**Legend:** ✅ unblocked — either 0 errors, or errors with a fix pattern already derived from Kashif's GA TSP (`MachineLearningServices.Management`) / preview TSP (`MachineLearningServices.Management.v2025_01_01_preview`), needing no external input · 🔴 architectural blocker awaiting service-team input · 🟦 SDK-consumed delta — needs Fareed/service-team decision before TSP can be finalized · ⬜ merged (Bucket A drop via import switch, or TSP already upstream in `main.tsp` via `@versioned` enum) · **Blocked on Nth** — merge candidate but blocked pending row N's resolution.

**Reproduce a single version:**
```pwsh
& 'C:\workspace\azure-rest-api-specs\node_modules\.bin\tsp.cmd' compile 'docs\generated-tsp\<folder>\main.tsp' --no-emit
```

Per-version error logs: `docs/generated-tsp/<folder>/_compile-errors.log`. Migration delta analysis: [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md). Overall tracker: [typespec_migration_status.md](typespec_migration_status.md).

## Mitigation Summary

Aggregated fix plan for the non-clean rows. After applying these fixes, the only rows still requiring external input are **3, 5, 6, 12** (Fareed — SDK delta decisions) and **15** (service team — route architecture).

| Row(s) | Failure class | Unblocked? | Fix pattern (validated against Kashif's TSP) |
|---|---|---|---|
| 2 | Discriminator collision — `Id` (`AssetReferenceBase`) | ✅ Yes (judgment) | Rename one sibling's `Id` discriminator value. No GA cross-reference (DP preview), but mechanically same shape as `uri_folder` fix. |
| 8, 9 | Discriminator collision — `uri_folder` (`DataVersionBaseProperties`) | ✅ Yes | Drop `DataImport` from siblings — matches GA `MachineLearningServices.Management/models.tsp`. |
| 10 | Above + `PatchModel = unknown` | ✅ Yes | Above + replace `PatchModel = unknown` with `PatchModel = void` plus `@patch(#{ implicitOptionality: false })` and `patch-envelope` suppress — matches GA `InferenceEndpoint.tsp`. |
| 11 | Above + 10× phantom `ActionAsyncBase` refs in 5 versioned-ops files | ✅ Yes (larger effort) | Above + rewrite the 5 ops files using `alias XOps = Azure.ResourceManager.Legacy.LegacyOperations<...>` + standard `XOps.ActionAsync<>` / `ActionSync<>` calls — pattern lifted from Kashif's preview TSP `MachineLearningServices.Management.v2025_01_01_preview` (already covers all 5 files; adapt operation list to each older swagger). |
| 15 | Duplicate routes + missing `@pageItems` | ❌ No | Architectural: needs service-team call on `@sharedRoute` vs sub-route restructure (Kashif's GA TSP approach) vs upstream swagger fix. |
