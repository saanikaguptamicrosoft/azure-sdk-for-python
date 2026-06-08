# TypeSpec Generation Status

Row numbers `1-15` correspond to the table in [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md) for cross-referencing.

**Scope:** TSPs are generated locally under `docs/generated-tsp/` from swaggers mirrored at `docs/swagger-remote/` (REMOTE/ARM) and `docs/swagger-local/` (LOCAL/data-plane). Nothing in `azure-rest-api-specs` is touched yet — clean TSP folders will be copy-pasted upstream once they compile with zero errors.

**Mechanical converter quirks already fixed in-place:** `@identifiers` decorator on non-array props (removed), `` `package` `` keyword escaping, missing `;` on `@@doc` augment lines and `back-compatible.tsp` `@@clientName` / `@@clientLocation` lines, `any` / `AnyObject` → `unknown`, `import` keyword escape.

| # | Version | Status | Errors / Notes |
|---:|---|---|---|
| 1 | `2020-09-01-dataplanepreview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 2 | `2021-10-01-dataplanepreview` | 🟠 Fix-known, wire-affecting | 2 errors — `invalid-discriminator-value: "Id"` collision: `ResourceManagementAssetReferenceDetails` and `IdAssetReference` both declare `referenceType: "Id"` on `AssetReferenceBase`. Mechanical rename of one sibling's discriminator (e.g. `"Id"` → `"ResourceManagementId"`) makes the TSP compile cleanly (verified: 0 errors / 32 warnings). **However**, the discriminator value is on the wire, so the rename can't be applied unilaterally — needs service-team confirmation that the resource-management import variant is OK to rename (or, more likely, that it should be dropped entirely as it appears to be a back-port). |
| 3 | `2022-01-01-preview` | 🟦 Delta — awaiting Fareed | TSP compiles 0 errors. SDK consumes local-only `WorkspaceConnectionPropertiesV2` + 7 auth subclasses + 5 credential POCOs via `entities/_credentials.py`. Needs service-team decision on whether to back-port these into the TSP or refactor SDK onto a newer version's connection types. |
| 4 | `2022-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 5 | `2022-10-01-preview` | 🟦 Delta — awaiting Fareed | TSP compiles 0 errors. SDK consumes local-only `UserCreatedAcrAccount` + `UserCreatedStorageAccount` (back-ported into registries.json). Needs service-team decision on whether to upstream these into the TSP. |
| 6 | `2022-12-01-preview` | 🟦 Blocked on 5th | To be converged into 5th API version |
| 7 | `2023-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 8 | `2023-04-01-preview` | 🔴 Blocked — architectural | Surface compile shows 2 errors (`uri_folder` discriminator dup); **after applying the validated mechanical fix** (drop `DataImport` cluster — 6 blocks), 2 NEW errors of class `@typespec/http/duplicate-operation` surface: `Workspace.list` features op vs `Feature.list` at `GET /workspaces/{ws}/features`. Same architectural family as row 15. Awaiting same service-team decision (`@sharedRoute`, sub-route restructure, or upstream swagger fix). |
| 9 | `2023-06-01-preview` | 🔴 Blocked — architectural | Same as row 8 after mechanical `DataImport` drop: 2× `duplicate-operation` (`Workspace.list` features vs `Feature.list`). |
| 10 | `2023-08-01-preview` | 🔴 Blocked — architectural | Surface 3 errors (`uri_folder` ×2 + `PatchModel = unknown`); **after fixes** (drop `DataImport`, set `PatchModel = {}` — `void` only works on `LegacyOperations<>.CustomPatchAsync`, NOT standalone `ArmCustomPatchAsync`), 2× `duplicate-operation` surface, same as rows 8/9. |
| 11 | `2024-01-01-preview` | 🔴 Blocked — architectural | Surface 13 errors (`uri_folder` ×2 + `PatchModel` + 10× `ActionAsyncBase` in 5 ops files); **after fixes** (`DataImport` drop, `PatchModel = {}`, regex-rewrite `.ActionAsyncBase<` → `.ActionAsync<` and strip the `BaseParameters = …DefaultBaseParameters<…>` template arg across 5 files), 8 `duplicate-operation` errors surface: above + `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` on `/endpoints/{name}` (GET, PUT) and `/endpoints` (GET). Same blocker as row 15. |
| 12 | `2024-04-01-preview` | 🔴 Blocked — architectural + 🟦 Delta | Surface ≈13 errors (same mix as row 11). After row 11 mechanical fixes, same `duplicate-operation` set as row 11 AND the SDK-delta blocker remains: `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` (REMOTE has them in v2024-01 and v2024-07 but dropped in v2024-04 only). Two independent blockers — service team + Fareed. |
| 13 | `2024-07-01-preview` | ⬜ Merged |  |
| 14 | `2024-10-01-preview` | ⬜ Merged | |
| 15 | `2025-01-01-preview` | 🔴 Blocked — architectural | 12 errors — 10× `@typespec/http/duplicate-operation` (5 unique URL+verb collisions between siblings: e.g. `Feature` vs `Workspace`'s `/features`; `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` `/endpoints/{name}`; `InferenceGroup` `getStatus` vs `getDeltaModelsStatusAsync` on same `/getStatus`) + 2× `missing-paging-items` (`InferenceGroup.listDeltaModelsAsync`, `RaiBlocklistPropertiesBasicResource.addBulk` — missing `@pageItems` on paged response). Genuine swagger-design ambiguity, not a converter artefact: needs service-team call on `@sharedRoute`, sub-route restructure (as in Kashif's GA TSP), or upstream swagger fix. Also tracked upstream in PR https://github.com/Azure/azure-rest-api-specs/pull/43779 (branch `saanika/tsp`). |

**Legend:** ✅ unblocked — 0 compile errors, ready to copy upstream · 🟠 fix-known-but-wire-affecting — mechanical fix is verified but changes serialized wire contract, needs service-team approval · 🔴 architectural blocker — `@typespec/http/duplicate-operation` errors that surface AFTER mechanical fixes, requiring service-team route restructure / `@sharedRoute` / swagger fix · 🟦 SDK-consumed delta — needs Fareed/service-team decision before TSP can be finalized · ⬜ merged (Bucket A drop via import switch, or TSP already upstream in `main.tsp` via `@versioned` enum) · **Blocked on Nth** — merge candidate but blocked pending row N's resolution.

**⚠️ Process correction (Jun 9, 2026):** Earlier revisions of this doc classified rows 8/9/10/11 as ✅ Unblocked based on surface compile-error counts. That was wrong — **fixing the surface errors uncovers deeper `duplicate-operation` errors of the same architectural family as row 15**. The current classification reflects compile output AFTER applying every validated mechanical fix.

**Reproduce a single version:**
```pwsh
& 'C:\workspace\azure-rest-api-specs\node_modules\.bin\tsp.cmd' compile 'docs\generated-tsp\<folder>\main.tsp' --no-emit
```

Per-version error logs: `docs/generated-tsp/<folder>/_compile-errors.log`. Migration delta analysis: [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md). Overall tracker: [typespec_migration_status.md](typespec_migration_status.md).

## Mitigation Summary

After applying every validated mechanical fix, the rows still requiring external input are:

- **2** — service team: validate the `Id` discriminator rename (or confirm `ResourceManagementAssetReferenceDetails` should be dropped entirely as a back-port artifact).
- **3, 5, 12** — Fareed: SDK-delta decisions.
- **8, 9, 10, 11, 12, 15** — service team: same `@typespec/http/duplicate-operation` architectural family (route choices: `@sharedRoute` decorator, sub-route restructure as in Kashif's GA TSP, or upstream swagger fix).

| Row(s) | Failure class | Mechanical fix | After fix |
|---|---|---|---|
| 2 | Discriminator collision — `"Id"` on `AssetReferenceBase` | Rename one sibling's discriminator (verified: `"Id"` → `"ResourceManagementId"` compiles clean) | ⚠️ Wire change — needs service-team approval |
| 8, 9 | Discriminator collision — `"uri_folder"` on `DataVersionBaseProperties` (`DataImport` vs `UriFolderDataVersion`) | Drop `DataImport` cluster (6 blocks: `union DataImportSourceType`, `model DataImport`, `model DataImportSource`, `model DatabaseSource`, `model FileSystemSource`, `model ImportDataAction`) — matches Kashif's GA TSP omission | 🔴 2× `duplicate-operation` surface (`Workspace.list` features vs `Feature.list`) — same blocker as row 15 |
| 10 | Above + `ArmCustomPatchAsync<…, PatchModel = unknown>` rejected | Above + `PatchModel = {}` (Kashif's `PatchModel = void` only works on the alias-based `LegacyOperations<>.CustomPatchAsync` template, NOT standalone `ArmCustomPatchAsync`) | Same as rows 8/9 |
| 11 | Above + 10× phantom `Azure.ResourceManager.Foundations.ActionAsyncBase` refs in 5 versioned-ops files | Above + regex-rewrite `.ActionAsyncBase<` → `.ActionAsync<` and strip `, BaseParameters = Azure.ResourceManager.Foundations.DefaultBaseParameters<…>` across `Code/Component/DataVersionBase/Environment/Model` Version.tsp | 🔴 8× `duplicate-operation` surface (above + `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` on `/endpoints/{name}` GET+PUT and `/endpoints` GET) — same blocker as row 15 |
| 12 | Above + SDK-consumed delta | Row 11 mechanical fixes apply | 🔴 architectural + 🟦 SDK delta |
| 15 | Duplicate routes + missing `@pageItems` | None mechanical | 🔴 Architectural: service-team call required |

**Validated fix recipes (preserved for re-application once the architectural decision lands):**
- `DataImport` cluster removal: brace-balanced block remover, walks backward to absorb `#suppress` / `@discriminator` / JSDoc, walks forward with brace-balance.
- `ActionAsyncBase → ActionAsync`: regex replace `.ActionAsyncBase<` → `.ActionAsync<` + strip `BaseParameters = …DefaultBaseParameters<…>` template arg from 5 ops files.
- `PatchModel = {}`: empty model literal is the only standalone-`ArmCustomPatchAsync`-compatible form (the proper Kashif-aligned alternative is to refactor to alias-based `LegacyOperations<>` pattern, which is a much larger structural rewrite).
