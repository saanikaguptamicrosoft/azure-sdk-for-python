# TypeSpec Generation Status

Row numbers `1-15` correspond to the table in [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md) for cross-referencing.

**Scope:** TSPs are generated locally under `docs/generated-tsp/` from swaggers mirrored at `docs/swagger-remote/` (REMOTE/ARM) and `docs/swagger-local/` (LOCAL/data-plane). Nothing in `azure-rest-api-specs` is touched yet — clean TSP folders will be copy-pasted upstream once they compile with zero errors.

**Mechanical converter quirks already fixed in-place:** `@identifiers` decorator on non-array props (removed), `` `package` `` keyword escaping, missing `;` on `@@doc` augment lines and `back-compatible.tsp` `@@clientName` / `@@clientLocation` lines, `any` / `AnyObject` → `unknown`, `import` keyword escape.

| # | Version | Status | Errors / Notes |
|---:|---|---|---|
| 1 | `2020-09-01-dataplanepreview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 2 | `2021-10-01-dataplanepreview` | 🔴 Blocked | **Delta issue + TSP generation issue.** Discriminator collision — `AssetReferenceBase.referenceType="Id"` is shared by `ResourceManagementAssetReferenceDetails` and `IdAssetReference`. Only mechanical fix is to rename one sibling's value `"Id"` → `"ResourceManagementId"` (TSP would compile 0 errors / 32 warnings). BUT SDK actively constructs `ResourceManagementAssetReferenceDetails` in `entities/_assets/workspace_asset_reference.py:10-11,67-73` and sends it on the wire — the rename would make the generated client emit `referenceType: "ResourceManagementId"` while the live service still expects `"Id"`. **Candidate TSP NOT shipped to `saanika/tsp_generare`** (would block PR merge without enabling SDK migration). Ship-blocked until service team accepts the new discriminator value OR `ResourceManagementAssetReferenceDetails` is dropped entirely as a back-port artifact. |
| 3 | `2022-01-01-preview` | 🔴 Blocked | **Delta issue.** TSP compiles 0 errors. SDK consumes local-only `WorkspaceConnectionPropertiesV2` + 7 auth subclasses + 5 credential POCOs via `entities/_credentials.py`. Needs decision on whether to back-port these into the TSP or refactor SDK onto a newer version's connection types. |
| 4 | `2022-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 5 | `2022-10-01-preview` | 🔴 Blocked | **Delta issue.** TSP compiles 0 errors. SDK consumes local-only `UserCreatedAcrAccount` + `UserCreatedStorageAccount` (back-ported into registries.json). Needs decision on whether to upstream these into the TSP. |
| 6 | `2022-12-01-preview` | 🔴 Blocked | Blocked on row 5 — converges into v2022-10. |
| 7 | `2023-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 8 | `2023-04-01-preview` | 🔴 Blocked | **Delta issue.** TSP compiles clean ONLY after dropping the `DataImport` cluster (`union DataImportSourceType` + `model DataImport` / `DataImportSource` / `DatabaseSource` / `FileSystemSource` / `ImportDataAction` — the only mechanical fix for the `uri_folder` discriminator collision under `DataVersionBaseProperties`). BUT SDK imports `ImportDataAction` from `v2023_04_01_preview.models` in `entities/_data_import/schedule.py:9` → the generated client would not have the symbol, breaking SDK at import time. **Candidate TSP NOT shipped to `saanika/tsp_generare`.** Same blocker pattern as row 2 and row 9: mechanical fix is wire/import-incompatible with active SDK code. |
| 9 | `2023-06-01-preview` | 🔴 Blocked | **Delta issue.** Same `DataImport`-cluster removal as row 8, BUT SDK imports `DataImport`, `DatabaseSource`, `FileSystemSource` from `v2023_06_01_preview.models` in `entities/_data_import/data_import.py:9-11` (constructs `DataImport`/`DatabaseSource`/`FileSystemSource` and uses them in `_to_rest_object` / `_from_rest_object`). Generated client would not have any of these symbols. **Candidate TSP NOT shipped to `saanika/tsp_generare`.** Resolution requires service-team decision: either upstream-rename one of the `uri_folder` discriminator siblings, OR refactor SDK to construct `DataImport` from a newer API version. |
| 10 | `2023-08-01-preview` | ✅ Unblocked | TSP shipped to `saanika/tsp_generare`. Fixes: row 8/9 `DataImport`-cluster removal + dropped back-compat `Workspaces.workspaceFeaturesList` op + `PatchModel = {}` on `InferenceEndpoint` (standalone `ArmCustomPatchAsync` rejects `void`). Compiles 0 errors. Grep-verified that production SDK imports NEITHER the `DataImport` family NOR the workspace-features op from `v2023_08_01_preview`. **Wire-affecting (back-compat alias op removed) — callout in PR description.** |
| 11 | `2024-01-01-preview` | ✅ Unblocked | TSP shipped to `saanika/tsp_generare`. Fixes: row 10 fix-set + (a) `ActionAsyncBase`→`ActionAsync` rewrite across 5 versioned ops files (`Code/Component/DataVersionBase/Environment/Model` Version.tsp) with the `BaseParameters = …DefaultBaseParameters<…>` template arg stripped; (b) dropped colliding ops `get`/`createOrUpdate`/`list` from `EndpointResourcePropertiesBasicResources` interface (operationIds `Endpoint_Get`/`Endpoint_CreateOrUpdate`/`Endpoint_List`) in favour of dedicated `InferenceEndpoints` interface. Unique ops (`listKeys`/`getModels`/`regenerateKeys`) preserved. Compiles 0 errors. Grep-verified that production SDK imports NONE of the dropped items from `v2024_01_01_preview`. **Multiple wire-affecting changes — callout in PR description.** |
| 12 | `2024-04-01-preview` | 🔴 Blocked | **Delta issue + TSP generation issue.** TSP-gen mechanical fixes are now all known (apply row 11 fix-set). Remaining blocker is the SDK-consumed delta: `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` (REMOTE has them in v2024-01 and v2024-07 but dropped in v2024-04 only). |
| 13 | `2024-07-01-preview` | ⬜ Merged |  |
| 14 | `2024-10-01-preview` | ⬜ Merged | |
| 15 | `2025-01-01-preview` | 🔴 Blocked | **TSP generation issue.** 12 errors — 10× `@typespec/http/duplicate-operation` (5 unique URL+verb collisions between siblings: e.g. `Feature` vs `Workspace`'s `/features`; `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` `/endpoints/{name}`; `InferenceGroup` `getStatus` vs `getDeltaModelsStatusAsync` on same `/getStatus`) + 2× `missing-paging-items` (`InferenceGroup.listDeltaModelsAsync`, `RaiBlocklistPropertiesBasicResource.addBulk` — missing `@pageItems` on paged response). Genuine swagger-design ambiguity, not a converter artefact: needs service-team call on `@sharedRoute`, sub-route restructure (as in Kashif's GA TSP), or upstream swagger fix. Also tracked upstream in PR https://github.com/Azure/azure-rest-api-specs/pull/43779 (branch `saanika/tsp`). |

**Status legend:** ✅ Unblocked — 0 compile errors AND SDK can consume the generated client (no dropped op/model is used by production SDK code) · 🔴 Blocked — either a **delta issue** (SDK uses types not in the standard TSP) or a **TSP generation issue** (TSP cannot be made wire-correct mechanically), often both · ⬜ Merged — TSP already upstream in `main.tsp` via `@versioned` enum, or Bucket A drop via import switch.

**Verification rule (this PR):** A row is **Unblocked** only when BOTH (a) the TSP compiles to 0 errors AND (b) grep proves production SDK code (`azure/ai/ml/**/*.py` outside `_restclient/`) imports NONE of the models/ops/properties dropped or renamed by the TSP fixes. Surface compile counts are NOT sufficient — must verify SDK consumption for every wire-affecting change.

**Spec-repo policy:** Candidate TSPs for Blocked rows are NOT shipped to `saanika/tsp_generare` (`azure-rest-api-specs` PR). A TSP that can't drive the SDK migration would only block PR merge without value. Local candidates remain in `docs/generated-tsp/` as evidence of attempted mechanical fixes.

**⚠️ Process corrections:**
- *(Jun 9, 2026)* Rows 8 and 9 were briefly classified as ✅ Unblocked based on surface compile counts (0 errors after `DataImport`-cluster removal). Reclassified to 🔴 Blocked after SDK grep showed `ImportDataAction` is imported from v2023-04 and `DataImport`/`DatabaseSource`/`FileSystemSource` from v2023-06 — dropping these models breaks SDK at import time. Same blocker pattern as row 2.
- *(Jun 9, 2026)* Row 2 was also briefly classified as ✅ Unblocked. Reverted after grep showed SDK actively constructs the affected model — the discriminator rename breaks the wire.
- *(Jun 9, 2026)* Candidate TSPs for rows 2, 3, 5, 8, 9 dropped from `saanika/tsp_generare` (spec repo commit `f6ef4ce44b`). Rows 1, 4, 7, 10, 11 remain (TSPs SDK can actually consume).

**Reproduce a single version:**
```pwsh
& 'C:\workspace\azure-rest-api-specs\node_modules\.bin\tsp.cmd' compile 'docs\generated-tsp\<folder>\main.tsp' --no-emit
```

Per-version error logs: `docs/generated-tsp/<folder>/_compile-errors.log`. Migration delta analysis: [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md). Overall tracker: [typespec_migration_status.md](typespec_migration_status.md).

## Mitigation Summary

Rows requiring external input:

- **Delta issue (SDK consumes types not in standard TSP):** rows 2, 3, 5, 8, 9, 12.
- **TSP generation issue (TSP can't be made wire-correct mechanically):** row 2, row 12, row 15.
- **Convergence:** row 6 → row 5.

**TSPs shipped to `saanika/tsp_generare`** (spec repo PR-ready, all SDK-consumable, all 0 errors):
- Row 1 (v2020-09-dp), Row 4 (v2022-02), Row 7 (v2023-02) — mechanical-only fixes (`@identifiers` deletes / `` `package` `` keyword escape), no wire impact.
- Row 10 (v2023-08), Row 11 (v2024-01) — dropped back-compat ops (`WorkspaceFeatures_List`; for row 11 also `Endpoint_Get`/`_CreateOrUpdate`/`_List`) + dropped `DataImport` cluster + `PatchModel = {}` + (row 11 only) `ActionAsyncBase`→`ActionAsync`. Grep-verified that production SDK imports none of the dropped items from these specific versions.

**Candidate TSPs NOT shipped to `saanika/tsp_generare`** (would block PR merge without enabling SDK migration; local copies remain under `docs/generated-tsp/` as evidence of attempted mechanical fixes):
- Row 2 (v2021-10-dp), Row 3 (v2022-01), Row 5 (v2022-10), Row 8 (v2023-04), Row 9 (v2023-06).

**Grep evidence per dropped item:**
- `Workspaces.workspaceFeaturesList` op: zero call sites in production SDK — only restclient internals reference it.
- `EndpointResourcePropertiesBasicResource` ops: zero production references (the `inference_endpoint` matches in `_autogen_entities/models/_patch.py` are unrelated `ServerlessInferenceEndpoint` property access).
- `DataImport` cluster: imported from v2023-04 (`ImportDataAction`) and v2023-06 (`DataImport`/`DatabaseSource`/`FileSystemSource`) only — those versions stay Blocked. NOT imported from v2023-08 or v2024-01.
- `ResourceManagementAssetReferenceDetails`: actively constructed in `entities/_assets/workspace_asset_reference.py:10-11,67-73`.
- `WorkspaceConnectionPropertiesV2BasicResource` + auth/credential subclasses: imported in `entities/_credentials.py` + `entities/_workspace/connections/workspace_connection.py`.
- `UserCreatedAcrAccount`/`UserCreatedStorageAccount`: imported in `entities/_registry/registry_support_classes.py:19` + `entities/_registry/util.py:8`.
- `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource`: imported in `entities/_autogen_entities/models/_patch.py:26-27` from v2024-04 specifically.

| Row(s) | Failure class | Mechanical fix | SDK consumes dropped/renamed item? | Status | In spec repo? |
|---|---|---|---|---|---|
| 1 | None (no errors) | n/a | No | ✅ Unblocked | Yes |
| 2 | Discriminator collision — `"Id"` on `AssetReferenceBase` | Rename `ResourceManagementAssetReferenceDetails.referenceType` value `"Id"` → `"ResourceManagementId"` | **YES** — `workspace_asset_reference.py` constructs the model | 🔴 Blocked | No |
| 3 | (TSP compiles clean) | n/a — delta only | **YES** — `entities/_credentials.py` + `workspace_connection.py` | 🔴 Blocked | No |
| 4 | Converter quirks only | `@identifiers` deletes | No | ✅ Unblocked | Yes |
| 5 | (TSP compiles clean) | n/a — delta only | **YES** — `entities/_registry/*.py` | 🔴 Blocked | No |
| 7 | Converter quirks only | `@identifiers` + `` `package` `` escape | No | ✅ Unblocked | Yes |
| 8 | Discriminator collision — `"uri_folder"` (`DataImport` vs `UriFolderDataVersion`) + duplicate-route on `/features` | Drop `DataImport` cluster + drop back-compat `WorkspaceFeatures_List` op | **YES** — `entities/_data_import/schedule.py` imports `ImportDataAction` from v2023-04 | 🔴 Blocked | No |
| 9 | Same as row 8 | Same as row 8 | **YES** — `entities/_data_import/data_import.py` imports `DataImport`/`DatabaseSource`/`FileSystemSource` from v2023-06 | 🔴 Blocked | No |
| 10 | Above + `ArmCustomPatchAsync<…, PatchModel = unknown>` rejected | Above + `PatchModel = {}` | No (from v2023-08 specifically) | ✅ Unblocked | Yes |
| 11 | Above + 10× phantom `ActionAsyncBase` refs in 5 ops files + duplicate-route on `/endpoints` | Above + `.ActionAsyncBase<` → `.ActionAsync<` (strip `BaseParameters = …`) across 5 files + drop colliding `Endpoint_Get`/`_CreateOrUpdate`/`_List` from `EndpointResourcePropertiesBasicResources` (preserve `listKeys`/`getModels`/`regenerateKeys`) | No (from v2024-01 specifically) | ✅ Unblocked | Yes |
| 12 | Row 11 fix-set + SDK-consumed delta | Row 11 fix-set | **YES** — `_patch.py` imports `OpenAIEndpointDeploymentResourceProperties`/`EndpointDeploymentResourcePropertiesBasicResource` from v2024-04 | 🔴 Blocked | No |
| 15 | Duplicate routes + missing `@pageItems` | None mechanical | n/a | 🔴 Blocked | Tracked in upstream PR #43779 only |

**Validated fix recipes (preserved — may be re-applied if service-team accepts the wire-affecting drops):**
- `DataImport` cluster removal: brace-balanced block remover; walks backward to absorb `#suppress`/`@discriminator`/JSDoc, walks forward with brace-balance.
- `ActionAsyncBase → ActionAsync`: regex replace `.ActionAsyncBase<` → `.ActionAsync<` + strip `BaseParameters = …DefaultBaseParameters<…>` template arg from 5 ops files.
- `PatchModel = {}`: empty model literal is the only standalone-`ArmCustomPatchAsync`-compatible form.
- `Remove-OperationByMarker` (in `_fix-recipes.ps1`): drops an op identified by its `@operationId("X_Y")` decorator anchor, absorbing all preceding decorators/JSDoc and tracking `<{([` depth so inner `;` don't trigger.
- `Remove-AugmentBlocksReferencing`: removes multi-line `@@xxx(...)` augment-decorator blocks whose argument text matches a regex — used to clean orphan `@@clientName`/`@@clientLocation`/`@@doc` augments left behind after dropping an op.
