# TypeSpec Generation Status

Row numbers `1-15` correspond to the table in [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md) for cross-referencing.

**Scope:** TSPs are generated locally under `docs/generated-tsp/` from swaggers mirrored at `docs/swagger-remote/` (REMOTE/ARM) and `docs/swagger-local/` (LOCAL/data-plane). Nothing in `azure-rest-api-specs` is touched yet — clean TSP folders will be copy-pasted upstream once they compile with zero errors.

**Mechanical converter quirks already fixed in-place:** `@identifiers` decorator on non-array props (removed), `` `package` `` keyword escaping, missing `;` on `@@doc` augment lines and `back-compatible.tsp` `@@clientName` / `@@clientLocation` lines, `any` / `AnyObject` → `unknown`, `import` keyword escape.

| # | Version | Status | Errors / Notes |
|---:|---|---|---|
| 1 | `2020-09-01-dataplanepreview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 2 | `2021-10-01-dataplanepreview` | ✅ Unblocked | TSP applied: discriminator collision (`AssetReferenceBase.referenceType="Id"` shared by `ResourceManagementAssetReferenceDetails` and `IdAssetReference`) resolved by renaming `ResourceManagementAssetReferenceDetails.referenceType` value `"Id"` → `"ResourceManagementId"`. Compiles 0 errors / 32 warnings. **Wire-affecting** — callout in PR description for service-team review; alternative is to drop `ResourceManagementAssetReferenceDetails` entirely as a back-port artifact. |
| 3 | `2022-01-01-preview` | � Blocked — Fareed | TSP compiles 0 errors. SDK consumes local-only `WorkspaceConnectionPropertiesV2` + 7 auth subclasses + 5 credential POCOs via `entities/_credentials.py`. Needs service-team decision on whether to back-port these into the TSP or refactor SDK onto a newer version's connection types. |
| 4 | `2022-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 5 | `2022-10-01-preview` | � Blocked — Fareed | TSP compiles 0 errors. SDK consumes local-only `UserCreatedAcrAccount` + `UserCreatedStorageAccount` (back-ported into registries.json). Needs service-team decision on whether to upstream these into the TSP. |
| 6 | `2022-12-01-preview` | � Blocked on 5th | To be converged into 5th API version |
| 7 | `2023-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 8 | `2023-04-01-preview` | ✅ Unblocked | TSP applied: (a) dropped `DataImport` cluster — 6 blocks (`union DataImportSourceType`, `model DataImport`, `model DataImportSource`, `model DatabaseSource`, `model FileSystemSource`, `model ImportDataAction`) — matches Kashif's GA TSP omission; (b) dropped back-compat `Workspaces.workspaceFeaturesList` op (operationId `WorkspaceFeatures_List`) which collided with dedicated `Features.list` at `GET /workspaces/{ws}/features`. Compiles 0 errors / 110 warnings. **Wire-affecting** (back-compat alias op removed) — callout in PR description for service-team review. |
| 9 | `2023-06-01-preview` | ✅ Unblocked | TSP applied: same fix-set as row 8. Compiles 0 errors. **Wire-affecting** (back-compat alias op removed) — callout in PR description. |
| 10 | `2023-08-01-preview` | ✅ Unblocked | TSP applied: row 8 fix-set + `PatchModel = {}` on `InferenceEndpoint` (`void` rejected by standalone `ArmCustomPatchAsync` — only works inside the alias-based `LegacyOperations<>.CustomPatchAsync` template). Compiles 0 errors. **Wire-affecting** (back-compat alias op removed) — callout in PR description. |
| 11 | `2024-01-01-preview` | ✅ Unblocked | TSP applied: row 10 fix-set + (a) `ActionAsyncBase`→`ActionAsync` rewrite across 5 versioned ops files (`Code/Component/DataVersionBase/Environment/Model` Version.tsp) with the `BaseParameters = …DefaultBaseParameters<…>` template arg stripped; (b) dropped colliding ops `get`/`createOrUpdate`/`list` from `EndpointResourcePropertiesBasicResources` interface (operationIds `Endpoint_Get`/`Endpoint_CreateOrUpdate`/`Endpoint_List`) in favour of dedicated `InferenceEndpoints` interface at `/endpoints/{endpointName}` and `/endpoints`. Unique ops (`listKeys`, `getModels`, `regenerateKeys`) preserved on the basic-resource interface. Compiles 0 errors. **Wire-affecting** (back-compat alias ops removed; matches Kashif's GA TSP which has only `InferenceEndpoints`) — callout in PR description for service-team review. |
| 12 | `2024-04-01-preview` | 🔴 Blocked — Fareed | TSP-gen mechanical/architectural fixes are now all known (apply row 11 fix-set). Remaining blocker is the SDK-consumed delta: `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` (REMOTE has them in v2024-01 and v2024-07 but dropped in v2024-04 only). Needs Fareed's decision on SDK side. |
| 13 | `2024-07-01-preview` | ⬜ Merged |  |
| 14 | `2024-10-01-preview` | ⬜ Merged | |
| 15 | `2025-01-01-preview` | 🔴 Blocked — architectural | 12 errors — 10× `@typespec/http/duplicate-operation` (5 unique URL+verb collisions between siblings: e.g. `Feature` vs `Workspace`'s `/features`; `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` `/endpoints/{name}`; `InferenceGroup` `getStatus` vs `getDeltaModelsStatusAsync` on same `/getStatus`) + 2× `missing-paging-items` (`InferenceGroup.listDeltaModelsAsync`, `RaiBlocklistPropertiesBasicResource.addBulk` — missing `@pageItems` on paged response). Genuine swagger-design ambiguity, not a converter artefact: needs service-team call on `@sharedRoute`, sub-route restructure (as in Kashif's GA TSP), or upstream swagger fix. Also tracked upstream in PR https://github.com/Azure/azure-rest-api-specs/pull/43779 (branch `saanika/tsp`). |

**Legend:** ✅ unblocked — 0 compile errors, copied upstream to `azure-rest-api-specs` branch `saanika/tsp_generare` · 🔴 Blocked — needs service-team or Fareed input (architectural duplicate-route, wire-protocol-affecting discriminator rename, or SDK-consumed delta) · ⬜ merged (Bucket A drop via import switch, or TSP already upstream in `main.tsp` via `@versioned` enum) · **Blocked on Nth** — merge candidate but blocked pending row N's resolution.

**⚠️ Process correction (Jun 9, 2026):** Earlier revisions of this doc classified rows 8/9/10/11 as ✅ Unblocked based on surface compile-error counts. That was wrong — **fixing the surface errors uncovered deeper `duplicate-operation` errors of the same architectural family as row 15**.

**Update (this PR):** Rows 2, 8, 9, 10, 11 are now reclassified ✅ Unblocked. The deeper `duplicate-operation` errors were resolved by dropping legacy back-compat operations (and one wire-protocol-affecting discriminator rename on row 2) that collide with dedicated, modern interfaces (`Features.list`, `InferenceEndpoints`). These omissions match Kashif's GA TSP conventions. All wire-affecting changes are flagged in the PR description for explicit service-team review.

**Reproduce a single version:**
```pwsh
& 'C:\workspace\azure-rest-api-specs\node_modules\.bin\tsp.cmd' compile 'docs\generated-tsp\<folder>\main.tsp' --no-emit
```

Per-version error logs: `docs/generated-tsp/<folder>/_compile-errors.log`. Migration delta analysis: [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md). Overall tracker: [typespec_migration_status.md](typespec_migration_status.md).

## Mitigation Summary

After applying every validated mechanical fix, the rows still requiring external input are:

- **3, 5, 12** — Fareed: SDK-delta decisions.
- **15** — service team: `@typespec/http/duplicate-operation` family + 2× `missing-paging-items` (genuine swagger-design ambiguity, not a converter artefact: `@sharedRoute`, sub-route restructure, or upstream swagger fix).

**Wire-affecting changes applied locally and flagged for service-team review (in PR description):**

- **Row 2** (`2021-10-01-dataplanepreview`): `ResourceManagementAssetReferenceDetails.referenceType` discriminator value renamed `"Id"` → `"ResourceManagementId"`.
- **Rows 8, 9, 10, 11**: dropped back-compat `Workspaces.workspaceFeaturesList` op (operationId `WorkspaceFeatures_List`) in favour of dedicated `Features.list`.
- **Row 11** (`2024-01-01-preview`) only: also dropped colliding ops `get`/`createOrUpdate`/`list` from `EndpointResourcePropertiesBasicResources` interface (operationIds `Endpoint_Get`/`Endpoint_CreateOrUpdate`/`Endpoint_List`) in favour of dedicated `InferenceEndpoints` interface. Unique ops (`listKeys`/`getModels`/`regenerateKeys`) preserved on the basic-resource interface.

All three patterns match Kashif's GA TSP conventions.

| Row(s) | Failure class | Mechanical fix | After fix |
|---|---|---|---|
| 2 | Discriminator collision — `"Id"` on `AssetReferenceBase` | Rename one sibling's discriminator (`"Id"` → `"ResourceManagementId"`) | ✅ Unblocked (wire change — flagged in PR) |
| 8, 9 | Discriminator collision — `"uri_folder"` on `DataVersionBaseProperties` (`DataImport` vs `UriFolderDataVersion`) | Drop `DataImport` cluster (6 blocks) + drop back-compat `Workspaces.workspaceFeaturesList` op (favours `Features.list`) | ✅ Unblocked (back-compat op removed — flagged in PR) |
| 10 | Above + `ArmCustomPatchAsync<…, PatchModel = unknown>` rejected | Above + `PatchModel = {}` (`void` only works on alias-based `LegacyOperations<>.CustomPatchAsync`, NOT standalone `ArmCustomPatchAsync`) | ✅ Unblocked (same callout as rows 8/9) |
| 11 | Above + 10× phantom `ActionAsyncBase` refs in 5 ops files + `/endpoints` collision | Above + regex-rewrite `.ActionAsyncBase<` → `.ActionAsync<` and strip `BaseParameters = …DefaultBaseParameters<…>` across `Code/Component/DataVersionBase/Environment/Model` Version.tsp + drop colliding `get`/`createOrUpdate`/`list` from `EndpointResourcePropertiesBasicResources` (preserve `listKeys`/`getModels`/`regenerateKeys`) | ✅ Unblocked (back-compat ops removed — flagged in PR) |
| 12 | Above + SDK-consumed delta | Row 11 mechanical fixes apply | 🔴 Blocked — Fareed (SDK delta) |
| 15 | Duplicate routes + missing `@pageItems` | None mechanical | 🔴 Blocked — architectural, service-team call required |

**Validated fix recipes (preserved for re-application once the architectural decision lands):**
- `DataImport` cluster removal: brace-balanced block remover, walks backward to absorb `#suppress` / `@discriminator` / JSDoc, walks forward with brace-balance.
- `ActionAsyncBase → ActionAsync`: regex replace `.ActionAsyncBase<` → `.ActionAsync<` + strip `BaseParameters = …DefaultBaseParameters<…>` template arg from 5 ops files.
- `PatchModel = {}`: empty model literal is the only standalone-`ArmCustomPatchAsync`-compatible form (the proper Kashif-aligned alternative is to refactor to alias-based `LegacyOperations<>` pattern, which is a much larger structural rewrite).
