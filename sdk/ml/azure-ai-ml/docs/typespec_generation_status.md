# TypeSpec Generation Status

Row numbers `1-15` correspond to the table in [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md) for cross-referencing.

**Scope:** TSPs are generated locally under `docs/generated-tsp/` from swaggers mirrored at `docs/swagger-remote/` (REMOTE/ARM) and `docs/swagger-local/` (LOCAL/data-plane). Nothing in `azure-rest-api-specs` is touched yet — clean TSP folders will be copy-pasted upstream once they compile with zero errors.

**Mechanical converter quirks already fixed in-place:** `@identifiers` decorator on non-array props (removed), `` `package` `` keyword escaping, missing `;` on `@@doc` augment lines and `back-compatible.tsp` `@@clientName` / `@@clientLocation` lines, `any` / `AnyObject` → `unknown`, `import` keyword escape.

| # | Version | Status | Errors / Notes |
|---:|---|---|---|
| 1 | `2020-09-01-dataplanepreview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 2 | `2021-10-01-dataplanepreview` | 🔴 Blocked | **Delta issue + TSP generation issue.** The only mechanical fix for the `"Id"` discriminator collision on `AssetReferenceBase` is to rename `ResourceManagementAssetReferenceDetails.referenceType` value `"Id"` → `"ResourceManagementId"`. That makes TSP compile clean (0 errors / 32 warnings), BUT the SDK actively constructs `ResourceManagementAssetReferenceDetails` in `entities/_assets/workspace_asset_reference.py` and sends it on the wire. Renaming the discriminator means the generated TSP client would emit `referenceType: "ResourceManagementId"` while the live service still expects `"Id"` → wire mismatch on both serialize and deserialize. Candidate TSP pushed to `saanika/tsp_generare` for service-team review; ship-blocked until service team accepts the new discriminator value OR `ResourceManagementAssetReferenceDetails` is dropped entirely as a back-port artifact. |
| 3 | `2022-01-01-preview` | 🔴 Blocked | **Delta issue.** TSP compiles 0 errors. SDK consumes local-only `WorkspaceConnectionPropertiesV2` + 7 auth subclasses + 5 credential POCOs via `entities/_credentials.py`. Needs decision on whether to back-port these into the TSP or refactor SDK onto a newer version's connection types. |
| 4 | `2022-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 5 | `2022-10-01-preview` | 🔴 Blocked | **Delta issue.** TSP compiles 0 errors. SDK consumes local-only `UserCreatedAcrAccount` + `UserCreatedStorageAccount` (back-ported into registries.json). Needs decision on whether to upstream these into the TSP. |
| 6 | `2022-12-01-preview` | 🔴 Blocked | Blocked on row 5 — converges into v2022-10. |
| 7 | `2023-02-01-preview` | ✅ Unblocked | 0 errors — ready to copy upstream |
| 8 | `2023-04-01-preview` | ✅ Unblocked | TSP applied: (a) dropped `DataImport` cluster — 6 blocks (`union DataImportSourceType`, `model DataImport`, `model DataImportSource`, `model DatabaseSource`, `model FileSystemSource`, `model ImportDataAction`) — matches Kashif's GA TSP omission; (b) dropped back-compat `Workspaces.workspaceFeaturesList` op (operationId `WorkspaceFeatures_List`) which collided with dedicated `Features.list` at `GET /workspaces/{ws}/features`. Compiles 0 errors / 110 warnings. **Wire-affecting** (back-compat alias op removed) — callout in PR description for service-team review. |
| 9 | `2023-06-01-preview` | ✅ Unblocked | TSP applied: same fix-set as row 8. Compiles 0 errors. **Wire-affecting** (back-compat alias op removed) — callout in PR description. |
| 10 | `2023-08-01-preview` | ✅ Unblocked | TSP applied: row 8 fix-set + `PatchModel = {}` on `InferenceEndpoint` (`void` rejected by standalone `ArmCustomPatchAsync` — only works inside the alias-based `LegacyOperations<>.CustomPatchAsync` template). Compiles 0 errors. **Wire-affecting** (back-compat alias op removed) — callout in PR description. |
| 11 | `2024-01-01-preview` | ✅ Unblocked | TSP applied: row 10 fix-set + (a) `ActionAsyncBase`→`ActionAsync` rewrite across 5 versioned ops files (`Code/Component/DataVersionBase/Environment/Model` Version.tsp) with the `BaseParameters = …DefaultBaseParameters<…>` template arg stripped; (b) dropped colliding ops `get`/`createOrUpdate`/`list` from `EndpointResourcePropertiesBasicResources` interface (operationIds `Endpoint_Get`/`Endpoint_CreateOrUpdate`/`Endpoint_List`) in favour of dedicated `InferenceEndpoints` interface at `/endpoints/{endpointName}` and `/endpoints`. Unique ops (`listKeys`, `getModels`, `regenerateKeys`) preserved on the basic-resource interface. Compiles 0 errors. **Wire-affecting** (back-compat alias ops removed; matches Kashif's GA TSP which has only `InferenceEndpoints`) — callout in PR description for service-team review. |
| 12 | `2024-04-01-preview` | 🔴 Blocked | **Delta issue + TSP generation issue.** TSP-gen mechanical fixes are now all known (apply row 11 fix-set). Remaining blocker is the SDK-consumed delta: `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` (REMOTE has them in v2024-01 and v2024-07 but dropped in v2024-04 only). |
| 13 | `2024-07-01-preview` | ⬜ Merged |  |
| 14 | `2024-10-01-preview` | ⬜ Merged | |
| 15 | `2025-01-01-preview` | 🔴 Blocked | **TSP generation issue.** 12 errors — 10× `@typespec/http/duplicate-operation` (5 unique URL+verb collisions between siblings: e.g. `Feature` vs `Workspace`'s `/features`; `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` `/endpoints/{name}`; `InferenceGroup` `getStatus` vs `getDeltaModelsStatusAsync` on same `/getStatus`) + 2× `missing-paging-items` (`InferenceGroup.listDeltaModelsAsync`, `RaiBlocklistPropertiesBasicResource.addBulk` — missing `@pageItems` on paged response). Genuine swagger-design ambiguity, not a converter artefact: needs service-team call on `@sharedRoute`, sub-route restructure (as in Kashif's GA TSP), or upstream swagger fix. Also tracked upstream in PR https://github.com/Azure/azure-rest-api-specs/pull/43779 (branch `saanika/tsp`). |

**Status legend:** ✅ Unblocked — 0 compile errors AND SDK can consume the generated client (no dropped op/model is used by production SDK code) · 🔴 Blocked — either a **delta issue** (SDK uses types not in the standard TSP) or a **TSP generation issue** (TSP cannot be made wire-correct mechanically), often both · ⬜ Merged — TSP already upstream in `main.tsp` via `@versioned` enum, or Bucket A drop via import switch.

**Blocker definition (this PR):** A row is **Unblocked** only when BOTH (a) the TSP compiles to 0 errors AND (b) the resulting generated Python client can be used by the SDK without breaking on the wire (no dropped op/model is constructed or imported in production code under `azure/ai/ml/` outside of `_restclient/`). Surface compile counts are NOT sufficient — must verify SDK call sites for every wire-affecting change. See "Wire-affecting changes" section below for the grep evidence per row.

**⚠️ Process corrections:**
- *(Jun 9, 2026, AM)* Earlier revisions of this doc classified rows 8/9/10/11 as ✅ Unblocked based on surface compile-error counts. That was wrong — fixing the surface errors uncovered deeper `duplicate-operation` errors of the same family as row 15.
- *(Jun 9, 2026, PM)* Rows 8, 9, 10, 11 NOW genuinely ✅ Unblocked: the deeper `duplicate-operation` errors were resolved by dropping legacy back-compat operations whose call sites do NOT exist in production SDK code (verified by grep). All wire-affecting changes flagged in PR description for service-team review.
- *(Jun 9, 2026, PM)* Row 2 was briefly mis-classified as ✅ Unblocked. Reverted to 🔴 Blocked after grep showed SDK actively constructs the affected model — the discriminator rename breaks the wire even though the TSP compiles. Candidate TSP remains pushed for service-team review.

**Reproduce a single version:**
```pwsh
& 'C:\workspace\azure-rest-api-specs\node_modules\.bin\tsp.cmd' compile 'docs\generated-tsp\<folder>\main.tsp' --no-emit
```

Per-version error logs: `docs/generated-tsp/<folder>/_compile-errors.log`. Migration delta analysis: [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md). Overall tracker: [typespec_migration_status.md](typespec_migration_status.md).

## Mitigation Summary

Rows requiring external input:

- **Delta issue (SDK consumes types not in standard TSP):** rows 3, 5, 12.
- **TSP generation issue (TSP can't be made wire-correct mechanically):** row 2, row 15. Row 12 also.
- **Convergence:** row 6 → row 5.

**Wire-affecting changes applied locally and flagged for service-team review (in PR description) — all verified safe via SDK grep:**

- **Rows 8, 9, 10, 11**: dropped back-compat `Workspaces.workspaceFeaturesList` op (operationId `WorkspaceFeatures_List`) in favour of dedicated `Features.list`. Grep evidence: zero call sites for `.workspace_features.list(` or `workspace_features_list` in `azure/ai/ml/**/*.py` outside `_restclient/`.
- **Row 11** (`2024-01-01-preview`) only: also dropped colliding ops `get`/`createOrUpdate`/`list` from `EndpointResourcePropertiesBasicResources` interface in favour of dedicated `InferenceEndpoints` interface. Unique ops (`listKeys`/`getModels`/`regenerateKeys`) preserved. Grep evidence: zero production SDK references to `EndpointResourcePropertiesBasicResource` or `endpoint_resource_properties` (the `inference_endpoint` matches in `_autogen_entities/models/_patch.py` are unrelated `ServerlessInferenceEndpoint` property access).

Both patterns match Kashif's GA TSP conventions.

**Wire-affecting candidate NOT ship-ready (row 2):** discriminator rename `ResourceManagementAssetReferenceDetails.referenceType` `"Id"` → `"ResourceManagementId"`. Grep showed the model IS actively constructed in `entities/_assets/workspace_asset_reference.py:11,68` — so the rename breaks the wire. TSP pushed to `saanika/tsp_generare` for service-team review only.

| Row(s) | Failure class | Mechanical fix | SDK consumes dropped/renamed item? | Status |
|---|---|---|---|---|
| 2 | Discriminator collision — `"Id"` on `AssetReferenceBase` | Rename `ResourceManagementAssetReferenceDetails.referenceType` value `"Id"` → `"ResourceManagementId"` | **YES** — `workspace_asset_reference.py` constructs the model | 🔴 Blocked |
| 8, 9 | Discriminator collision — `"uri_folder"` on `DataVersionBaseProperties` (`DataImport` vs `UriFolderDataVersion`) + duplicate-route on `/features` | Drop `DataImport` cluster (6 blocks) + drop back-compat `Workspaces.workspaceFeaturesList` op (favours `Features.list`) | No | ✅ Unblocked |
| 10 | Above + `ArmCustomPatchAsync<…, PatchModel = unknown>` rejected | Above + `PatchModel = {}` | No | ✅ Unblocked |
| 11 | Above + 10× phantom `ActionAsyncBase` refs in 5 ops files + duplicate-route on `/endpoints` | Above + regex-rewrite `.ActionAsyncBase<` → `.ActionAsync<` and strip `BaseParameters = …DefaultBaseParameters<…>` across `Code/Component/DataVersionBase/Environment/Model` Version.tsp + drop colliding `get`/`createOrUpdate`/`list` from `EndpointResourcePropertiesBasicResources` (preserve `listKeys`/`getModels`/`regenerateKeys`) | No | ✅ Unblocked |
| 12 | Above + SDK-consumed delta | Row 11 mechanical fixes apply | **YES** — `_patch.py` uses `OpenAIEndpointDeploymentResourceProperties` + `EndpointDeploymentResourcePropertiesBasicResource` | 🔴 Blocked |
| 15 | Duplicate routes + missing `@pageItems` | None mechanical | n/a | 🔴 Blocked |

**Validated fix recipes (preserved):**
- `DataImport` cluster removal: brace-balanced block remover; walks backward to absorb `#suppress`/`@discriminator`/JSDoc, walks forward with brace-balance.
- `ActionAsyncBase → ActionAsync`: regex replace `.ActionAsyncBase<` → `.ActionAsync<` + strip `BaseParameters = …DefaultBaseParameters<…>` template arg from 5 ops files.
- `PatchModel = {}`: empty model literal is the only standalone-`ArmCustomPatchAsync`-compatible form.
- `Remove-OperationByMarker` (in `_fix-recipes.ps1`): drops an op identified by its `@operationId("X_Y")` decorator anchor, absorbing all preceding decorators/JSDoc and tracking `<{([` depth so inner `;` don't trigger.
- `Remove-AugmentBlocksReferencing`: removes multi-line `@@xxx(...)` augment-decorator blocks whose argument text matches a regex — used to clean orphan `@@clientName`/`@@clientLocation`/`@@doc` augments left behind after dropping an op.
