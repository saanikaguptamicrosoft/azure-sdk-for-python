# TypeSpec Generation Status

**Scope:** 13 ML preview API versions, generated locally under `docs/generated-tsp/` from swaggers mirrored at `docs/swagger-remote/` (REMOTE/ARM) and `docs/swagger-local/` (LOCAL/data-plane). Nothing in `azure-rest-api-specs` is touched yet — clean TSP folders will be copy-pasted upstream once they compile with zero errors.

**Mechanical converter quirks already fixed in-place:** `@identifiers` decorator on non-array props (removed), `` `package` `` keyword escaping, missing `;` on `@@doc` augment lines and `back-compatible.tsp` `@@clientName` / `@@clientLocation` lines, `any` / `AnyObject` → `unknown`, `import` keyword escape.

| Version | Source | Errors | Blocker / Action |
|---|---|---:|---|
| `2020-09-01-dataplanepreview` | LOCAL | **0** | ✅ Clean — ready to copy upstream |
| `2022-01-01-preview` *(excluded delta)* | REMOTE | **0** | ✅ Clean |
| `2022-02-01-preview` | REMOTE | **0** | ✅ Clean — ready to copy upstream |
| `2022-10-01-preview` *(excluded delta)* | REMOTE | **0** | ✅ Clean |
| `2022-12-01-preview` | REMOTE | **0** | ✅ Clean — ready to copy upstream |
| `2023-02-01-preview` | REMOTE | **0** | ✅ Clean — ready to copy upstream |
| `2023-04-01-preview` | REMOTE | 2 | 🟡 Swagger: `uri_folder` discriminator collision — `DataImport` and `UriFolderDataVersion` both declare `dataType: "uri_folder"` under `DataVersionBaseProperties` |
| `2023-06-01-preview` | REMOTE | 2 | 🟡 Same — `uri_folder` discriminator collision |
| `2023-08-01-preview` | REMOTE | 3 | 🟡 `uri_folder` (×2) + `ArmCustomPatchAsync<PatchModel = unknown>` rejected — template requires a `Model`; swagger lookup needed for the patch body |
| `2021-10-01-dataplanepreview` | LOCAL | 2 | 🟡 Swagger: `Id` discriminator collision (same shape as `uri_folder`) |
| `2024-01-01-preview` | REMOTE | 13 | 🟠 `uri_folder` (×2) + `PatchModel` (×1) + 10× `ActionAsyncBase` / `parameters` ref-resolution across 5 versioned-ops files — converter referenced `Azure.ResourceManager.Foundations` members that no longer exist; correct TSP idiom needs to be confirmed |
| `2024-04-01-preview` *(excluded delta)* | REMOTE | 13 | 🟠 Same error mix as `2024-01` |
| `2025-01-01-preview` *(pilot)* | REMOTE | 12 | 🔴 Architectural — 10× `@typespec/http/duplicate-operation` (5 unique URL+verb collisions: e.g. `Feature` vs `Workspace`s `/features`; `InferenceEndpoint` vs `EndpointResourcePropertiesBasicResource` `/endpoints/{name}`) + 2× `missing-paging-items`. Awaiting service-team decision (`@sharedRoute`, sub-route restructure as in Kashif's GA TSP, or upstream swagger fix). Source of truth: PR https://github.com/Azure/azure-rest-api-specs/pull/43779 (branch `saanika/tsp`); mirrored here for one-stop view. |

**Legend:** ✅ ready to copy upstream · 🟡 single real swagger-side issue, tractable · 🟠 swagger fixes + missing TSP template idiom · 🔴 architectural blocker awaiting service-team input.

**Remaining error classes (cannot be auto-fixed — require investigation / service-team input):**
1. `invalid-discriminator-value` — same swagger discriminator value used by two siblings (`uri_folder`, `Id`). Options: rename upstream, TSP-level discriminator override, or omit one model if not SDK-imported.
2. `ArmCustomPatchAsync<..., PatchModel = ...>` constraint — needs the actual patch-body model from the source swagger.
3. `Interface doesn't have member ActionAsyncBase` / `Cannot resolve 'parameters'` — converter emitted references to `Azure.ResourceManager.Foundations` API surface that has been removed. Correct replacement is likely `ArmResourceActionAsync<...>` with reworked operation references, but should be verified before applying broadly.
4. **Pilot only:** `@typespec/http/duplicate-operation` and `missing-paging-items` — architectural; resolved upstream by Kashif's GA TSP via sub-route restructure.

**Reproduce:**
```pwsh
& 'C:\workspace\azure-rest-api-specs\node_modules\.bin\tsp.cmd' compile 'docs\generated-tsp\<folder>\main.tsp' --no-emit
```

Per-version error logs live at `docs/generated-tsp/<folder>/_compile-errors.log`. Migration delta analysis: `docs/typespec_migration_per_version_analysis.md`. Overall tracker: `docs/typespec_migration_status.md`. Agent gotchas: `/memories/repo/typespec-migration-context.md` and `/memories/repo/tsp-migration-notes.md`.
