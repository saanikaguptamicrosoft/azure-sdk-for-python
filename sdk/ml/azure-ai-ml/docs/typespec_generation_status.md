# TypeSpec Generation Status

Row numbers `1-15` correspond to the table in [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md) for cross-referencing.

**Scope:** TSPs are generated locally under `docs/generated-tsp/` from swaggers mirrored at `docs/swagger-remote/` (REMOTE/ARM) and `docs/swagger-local/` (LOCAL/data-plane). Nothing in `azure-rest-api-specs` is touched yet — clean TSP folders will be copy-pasted upstream once they compile with zero errors.

**Mechanical converter quirks already fixed in-place:** `@identifiers` decorator on non-array props (removed), `` `package` `` keyword escaping, missing `;` on `@@doc` augment lines and `back-compatible.tsp` `@@clientName` / `@@clientLocation` lines, `any` / `AnyObject` → `unknown`, `import` keyword escape.

| # | Version | Status | Errors / Notes |
|---:|---|---|---|
| 1 | `2020-09-01-dataplanepreview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 2 | `2021-10-01-dataplanepreview` | 🟡 Blocked | 2 errors — `invalid-discriminator-value: "Id"` collision in `models.tsp` (two siblings of a discriminated union declare the same `Id` discriminator value). Same shape as the `uri_folder` issue below. |
| 3 | `2022-01-01-preview` | 🟦 Delta — awaiting Fareed | TSP compiles 0 errors. SDK consumes local-only `WorkspaceConnectionPropertiesV2` + 7 auth subclasses + 5 credential POCOs via `entities/_credentials.py`. Needs service-team decision on whether to back-port these into the TSP or refactor SDK onto a newer version's connection types. |
| 4 | `2022-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 5 | `2022-10-01-preview` | 🟦 Delta — awaiting Fareed | TSP compiles 0 errors. SDK consumes local-only `UserCreatedAcrAccount` + `UserCreatedStorageAccount` (back-ported into registries.json). Needs service-team decision on whether to upstream these into the TSP. |
| 6 | `2022-12-01-preview` | Blocked on 5th | To be converged into 5th API version |
| 7 | `2023-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 8 | `2023-04-01-preview` | 🟡 Blocked | 2 errors — `invalid-discriminator-value: "uri_folder"` collision. Two siblings of `DataVersionBaseProperties` declare the same `dataType: "uri_folder"`: `DataImport` and `UriFolderDataVersion`. Real swagger-side issue. Options for Kashif: (a) upstream swagger rename one discriminator, (b) TSP-level discriminator override, (c) omit `DataImport` from this older TSP if not SDK-imported. |
| 9 | `2023-06-01-preview` | 🟡 Blocked | 2 errors — same `uri_folder` discriminator collision as row 8. |
| 10 | `2023-08-01-preview` | 🟡 Blocked | 3 errors — `uri_folder` (×2, same as row 8) + 1× `ArmCustomPatchAsync<InferenceEndpoint, PatchModel = unknown>` rejected because the template requires a `Model`, not `unknown`. The converter dropped the patch-body model. Needs Kashif's input on correct TSP idiom (e.g. `PatchModel = {}`, an inline patch model, or different template variant). |
| 11 | `2024-01-01-preview` | 🟠 Blocked | 13 errors — `uri_folder` (×2) + `PatchModel` (×1) + 10× `invalid-ref: Interface doesn't have member ActionAsyncBase` and `Cannot resolve 'parameters' in node OperationStatement` across 5 versioned-ops files (`CodeVersion.tsp`, `ComponentVersion.tsp`, `DataVersionBase.tsp`, `EnvironmentVersion.tsp`, `ModelVersion.tsp`). Converter emitted references to `Azure.ResourceManager.Foundations` members that no longer exist. Needs Kashif's input on the correct TSP idiom (likely `ArmResourceActionAsync<...>` with reworked operation references). |
| 12 | `2024-04-01-preview` | 🟦 Delta — awaiting Fareed | TSP compiles 13 errors (same mix as row 11). SDK also consumes local-only `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` in `entities/_autogen_entities/models/_patch.py` (REMOTE has them in v2024-01 and v2024-07 but dropped in v2024-04 only). Needs service-team decision on whether to back-port into TSP or refactor SDK onto v2024-07. |
| 13 | `2024-07-01-preview` | ⬜ Merged |  |
| 14 | `2024-10-01-preview` | ⬜ Merged | |
| 15 | `2025-01-01-preview` | 🔴 Blocked — architectural | 12 errors — 10× `@typespec/http/duplicate-operation` (5 unique URL+verb collisions between siblings: e.g. `Feature` vs `Workspace`s `/features`; `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` `/endpoints/{name}`; `InferenceGroup` `getStatus` vs `getDeltaModelsStatusAsync` on same `/getStatus`) + 2× `missing-paging-items` (`InferenceGroup.listDeltaModelsAsync`, `RaiBlocklistPropertiesBasicResource.addBulk` — missing `@pageItems` on paged response). Awaiting service-team decision (`@sharedRoute`, sub-route restructure as in Kashif's GA TSP, or upstream swagger fix). Source of truth: PR https://github.com/Azure/azure-rest-api-specs/pull/43779 (branch `saanika/tsp`); mirrored here for one-stop view. |

**Legend:** ✅ unblocked, ready to copy upstream · 🟡 single real swagger-side issue, tractable, needs Kashif's call · 🟠 swagger fixes + missing TSP template idiom, needs Kashif's call · 🔴 architectural blocker awaiting service-team input · 🟦 SDK-consumed delta — needs Fareed/service-team decision before TSP can be finalized · ⬜ merged (Bucket A drop via import switch, or TSP already upstream in `main.tsp` via `@versioned` enum) · **Blocked on Nth** — merge candidate but blocked pending row N's resolution.

**Reproduce a single version:**
```pwsh
& 'C:\workspace\azure-rest-api-specs\node_modules\.bin\tsp.cmd' compile 'docs\generated-tsp\<folder>\main.tsp' --no-emit
```

Per-version error logs: `docs/generated-tsp/<folder>/_compile-errors.log`. Migration delta analysis: [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md). Overall tracker: [typespec_migration_status.md](typespec_migration_status.md).
