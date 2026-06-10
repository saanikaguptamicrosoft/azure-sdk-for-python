# TypeSpec generation — issues for service team review

## Context

TSP-generation issue refers to a failure that surfaces when we run the swagger→TypeSpec converter (or `tsp compile`) on a per-version `MachineLearningServices.Management.vYYYY_MM_DD_preview/` folder and the result is either (a) a TSP that does not compile, or (b) a TSP that compiles but is incomplete — emitting a Python client that drops symbols the SDK imports.

We classify them into two levels:

1. **Compile-time errors** — TSP rejects the generated source. Either a discriminator value collides between sibling subtypes, or sibling interfaces register the same `(URL, verb)` pair.
2. **Silent generator defects** — TSP compiles, but the converter could not faithfully reproduce a swagger construct (an `allOf` mixin, in our case), leaving downstream models orphaned. The python emitter then prunes them, so the regenerated client is missing types the SDK imports — caught only by comparing `len(<tsp>.models.__all__)` against `len(<autorest>.models.__all__)`.

**Migration goal.** Every preview / legacy API version the SDK currently consumes from autorest must be regeneratable from TSP with an **equivalent client surface** — same operations, same models, same wire contract. Skipping a version or dropping a feature is not on the table: the SDK already ships the surface to customers, and the migration's success criterion is that customer-visible behavior is byte-for-byte preserved.

That means **every issue below has to be fixed on the spec side**. The service team's only decision per issue is which of the available spec-side fix patterns to apply (rename a discriminator value, restructure an interface, add a `@pageItems` annotation, wire a body type, etc.). The SDK side then absorbs the regen with zero entity-layer changes.

---

## Summary

| # | Issue | Affected API versions | What breaks | Owning SDK file |
|---:|---|---|---|---|
| 1 | Discriminator collision on `AssetReferenceBase.referenceType` — value `"Id"` shared by `IdAssetReference` and `ResourceManagementAssetReferenceDetails` | `2021-10-01-dataplanepreview` | TSP compile fails; SDK consumes `ResourceManagementAssetReferenceDetails` from this version | [entities/_assets/workspace_asset_reference.py](../azure/ai/ml/entities/_assets/workspace_asset_reference.py) |
| 2 | Discriminator collision on `DataVersionBaseProperties.dataType` — value `"uri_folder"` shared by `UriFolderDataVersion` and the `DataImport` cluster (`DataImport` / `DataImportSource` / `DatabaseSource` / `FileSystemSource` / `ImportDataAction`) | `2023-04-01-preview`, `2023-06-01-preview`, `2024-04-01-preview` | TSP compile fails; SDK consumes one or more types from the `DataImport` cluster on each affected version | [entities/_data_import/data_import.py](../azure/ai/ml/entities/_data_import/data_import.py), [entities/_data_import/schedule.py](../azure/ai/ml/entities/_data_import/schedule.py) |
| 3 | Converter emits `// FIXME: ComputeResource has no properties property` + empty `<{}>` body on `ComputeResource.tsp`; the `Compute` discriminated union and ~137 subtype models become orphans and the python emitter prunes them | All 11 versioned `ComputeResource.tsp` files (`2022-01` … `2025-01`); SDK only breaks on versions whose consumers import pruned `Compute*` symbols — currently `2023-08-01-preview` and `2024-01-01-preview` | TSP compiles but regenerated client is missing `ComputeInstance`, `ComputeInstanceProperties`, `ComputeInstanceSshSettings`, `ComputeInstanceDataMount`, `AssignedUser`, `PersonalComputeInstanceSettings` and the rest of the Compute family → `ImportError` at SDK module load | [entities/_compute/compute_instance.py](../azure/ai/ml/entities/_compute/compute_instance.py), [operations/_data_operations.py](../azure/ai/ml/operations/_data_operations.py), [operations/_datastore_operations.py](../azure/ai/ml/operations/_datastore_operations.py) |
| 4 | 10× `@typespec/http/duplicate-operation` (5 unique `(path, verb)` collisions) + 2× `missing-paging-items` | `2025-01-01-preview` | TSP compile fails — 12 errors | [operations/_capability_hosts_operations.py](../azure/ai/ml/operations/_capability_hosts_operations.py), [entities/_job/command_job.py](../azure/ai/ml/entities/_job/command_job.py), [entities/_builders/command.py](../azure/ai/ml/entities/_builders/command.py) |

**Total: 4 distinct TSP-generation issues blocking 5 API versions** (`2021-10-01-dataplanepreview`, `2023-04-01-preview`, `2023-06-01-preview`, `2023-08-01-preview`, `2024-01-01-preview`, `2024-04-01-preview`, `2025-01-01-preview` — `2024-04-01-preview` is also blocked on a separate delta, see [typespec_deltas_service_review.md](typespec_deltas_service_review.md) Delta 4 + Delta 5). Full schema / TSP / error definitions in the [appendix](#appendix--full-evidence).

---

## Issue 1 — `2021-10-01-dataplanepreview` `AssetReferenceBase.referenceType` discriminator collision

`mfe.json` defines an `AssetReferenceBase` polymorphic family with `discriminator: "referenceType"` and an enum `ReferenceType` with values `Id` / `DataPath` / `OutputPath`. Two subtypes both pick `x-ms-discriminator-value: "Id"`:

- `IdAssetReference` (uses the standard "look up an asset by ARM resource ID" shape — `{ assetId: string }`).
- `ResourceManagementAssetReference` (re-exported with `x-ms-client-name: "ResourceManagementAssetReferenceDetails"` — the SDK-visible name). Carries `{ sourceAssetId, destinationName, destinationVersion }` and is used to drive a "copy an asset into the registry" import flow.

The autorest converter / TSP compiler rejects this — two subtypes cannot register the same discriminator value on the same base. The SDK actively constructs `ResourceManagementAssetReferenceDetails` in [entities/_assets/workspace_asset_reference.py](../azure/ai/ml/entities/_assets/workspace_asset_reference.py) on this exact API version, so both subtypes must survive the regen.

The only mechanical fix on the spec side is to rename one of the two subtypes' discriminator values (e.g. `"Id"` → `"ResourceManagementId"` on `ResourceManagementAssetReference`). Because the discriminator value is part of the on-the-wire JSON body, this is a **wire-affecting change** — the service must accept the new value.

> **Question for service team:** Please rename one of the two `x-ms-discriminator-value: "Id"` claimants to a unique value (suggested: `"ResourceManagementId"` on `ResourceManagementAssetReference`, since `IdAssetReference` is the more widely-used / generic subtype) and update the service to accept the new on-the-wire value. If a different rename is preferred (different side, different new value, or a fully different disambiguation strategy), please confirm so we can mirror it on the SDK side and regen.

Field-level schemas + the colliding discriminator excerpt: see [appendix](#issue-1-schemas).

---

## Issue 2 — `2023-04-01-preview` / `2023-06-01-preview` / `2024-04-01-preview` `DataVersionBaseProperties.dataType` discriminator collision

`mfe.json` defines a `DataVersionBase` polymorphic family with `discriminator: "dataType"` (client name `DataVersionBaseProperties`). The expected subtypes are `UriFolderDataVersion`, `UriFileDataVersion`, `MLTableData`, etc., keyed by the relevant `dataType` value.

A `DataImport` family has been overlaid onto the same parent — `DataImport`, `DataImportSource` (+ subtypes `DatabaseSource`, `FileSystemSource`), and the matching `ImportDataAction` schedule wrapper — and **`DataImport` was given `x-ms-discriminator-value: "uri_folder"`** (the same value as the existing `UriFolderDataVersion` subtype).

Two subtypes on the same discriminator base picking the same value → TSP rejects the model. Affected versions are those whose `mfe.json` carries both the `UriFolderDataVersion` definition and the `DataImport` overlay: `2023-04-01-preview`, `2023-06-01-preview`, `2024-04-01-preview`.

The SDK actively imports types from the `DataImport` cluster on every blocked version, so both branches of the discriminator must survive the regen:
- `2023-04-01-preview`: [entities/_data_import/schedule.py:9](../azure/ai/ml/entities/_data_import/schedule.py#L9) imports `ImportDataAction`.
- `2023-06-01-preview`: [entities/_data_import/data_import.py:9-11](../azure/ai/ml/entities/_data_import/data_import.py#L9-L11) imports `DataImport`, `DatabaseSource`, `FileSystemSource`.
- `2024-04-01-preview`: same surface as above via the workspace-connection / OpenAI code paths.

The mechanical fix on the spec side is to rename the `DataImport` family's discriminator value upstream so both branches survive (e.g. `"uri_folder"` → `"data_import"`). Like Issue 1, that is on-the-wire — the service must accept the new value.

> **Question for service team:** Please assign a unique `dataType` discriminator value to `DataImport` (suggested: `"data_import"`) on all three affected API versions and update the service to read the new on-the-wire value. If a different new value (or a fully different disambiguation strategy) is preferred, please confirm so we can mirror it on the SDK side and regen.

Field-level schemas + the colliding discriminator excerpts: see [appendix](#issue-2-schemas).

---

## Issue 3 — Converter emits empty `<{}>` body on every versioned `ComputeResource.tsp`, orphan-pruning the `Compute` hierarchy

This is the highest-impact issue, blocks two SDK migrations end-to-end (`2023-08-01-preview` and `2024-01-01-preview`), and is the one that motivated a full audit of the generator output rather than just the swagger.

**What the converter did.** Swagger defines `ComputeResource` as:

```jsonc
"ComputeResource": {
  "type": "object",
  "allOf": [
    { "$ref": "...common-types/.../v3/types.json#/definitions/Resource" },
    { "$ref": "#/definitions/ComputeResourceSchema" }
  ],
  "properties": {
    "identity": { "$ref": ".../ManagedServiceIdentity" },
    "location": { "type": "string" },
    "tags":     { "type": "object", "additionalProperties": { "type": "string" } },
    "sku":      { "$ref": ".../Sku" }
  }
}
```

`ComputeResourceSchema` (the second `allOf` mixin) carries one property: `properties: Compute` — i.e. it is what wires the `Compute` discriminated union (`AmlCompute` / `ComputeInstance` / `Kubernetes` / `VirtualMachine` / `HDInsight` / `Databricks` / …) onto the ARM envelope.

The converter could not fold that mixin into a TypeSpec `Azure.ResourceManager.Legacy.TrackedResourceWithOptionalLocation<T>` template parameter — the slot for the body type — so it left the slot empty and dropped a `// FIXME` comment. The result, verbatim from every one of the 11 generated `ComputeResource.tsp` files (versions `2022-01` through `2025-01`):

```typespec
// FIXME: ComputeResource has no properties property
@parentResource(Workspace)
model ComputeResource
  is Azure.ResourceManager.Legacy.TrackedResourceWithOptionalLocation<{}> {
  ...ResourceNameParameter<...>;
  ...Azure.ResourceManager.ManagedServiceIdentityProperty;
  ...Azure.ResourceManager.ResourceSkuProperty;
}
```

**The empirical fallout.** The `Compute` discriminated union and ~25 subtype models still exist in `models.tsp` — they were just never referenced from any operation or resource. The python emitter prunes orphan models from `__init__.py` exports:

| Generated client | `len(models.__all__)` |
|---|---:|
| `v2023_08_01_preview_tsp.models` (TSP) | 659 |
| `v2023_08_01_preview.models` (autorest) | 796 |
| **Δ (pruned by the orphan-prune)** | **137** |

The 137 missing exports are almost entirely the `Compute` family + `SsoSetting` + `ResourceId` + `PaginatedComputeResourcesList`.

**Which SDK migrations break.** The TSP defect is present on every versioned `ComputeResource.tsp`, but a version is **only blocked** if the SDK imports one of the pruned `Compute*` symbols from that specific version. Empirically verified:

| Version | Pruned imports SDK relies on | Status |
|---|---|---|
| `2023-08-01-preview` | `ComputeInstance`, `ComputeInstanceProperties`, `ComputeInstanceSshSettings`, `PersonalComputeInstanceSettings`, `AssignedUser` — all imported in [entities/_compute/compute_instance.py:13-16](../azure/ai/ml/entities/_compute/compute_instance.py#L13-L16) | **Blocked** |
| `2024-01-01-preview` | `ComputeInstanceDataMount` (field on `ComputeInstanceProperties`) — imported in [operations/_data_operations.py:29](../azure/ai/ml/operations/_data_operations.py#L29) and [operations/_datastore_operations.py:15](../azure/ai/ml/operations/_datastore_operations.py#L15) | **Blocked** |
| `2022-02`, `2023-02`, `2024-04`, `2025-01` | None — SDK imports from these versions don't touch the `Compute*` graph | Defect present but no-op |

**A precedent that works.** The GA, hand-authored `MachineLearningServices.Management/ComputeResource.tsp` ([Azure/azure-rest-api-specs main branch](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/machinelearningservices/MachineLearningServices.Management/ComputeResource.tsp)) wires `Compute` correctly by passing it as the body type and suppressing the legacy-hierarchy lint warnings:

```typespec
#suppress "@azure-tools/typespec-azure-core/no-legacy-usage" "Required for backward compatibility"
#suppress "@azure-tools/typespec-client-generator-core/legacy-hierarchy-building-conflict" "Required for SDK backward compatibility"
@parentResource(Workspace)
model ComputeResource is Azure.ResourceManager.ProxyResource<Compute> {
  ...ResourceNameParameter<...>;
  location?: string;
  tags?: Record<string> | null;
  sku?: Azure.ResourceManager.Foundations.Sku | null;
  ...Azure.ResourceManager.ManagedServiceIdentityProperty;
}
```

When the body type is non-empty and references `Compute`, the discriminator graph is reachable, the python emitter keeps it, and the resulting client exports the full Compute family. Kashif's GA TSP was verified to produce a complete client.

**Why we can't just back-apply the GA template.** The GA model uses `Azure.ResourceManager.ProxyResource<Compute>`. Our 11 preview / legacy versions were converted from a swagger that uses `Azure.ResourceManager.Legacy.TrackedResourceWithOptionalLocation` (the legacy ARM template), with `location` / `tags` / `sku` re-declared as envelope properties and `ManagedServiceIdentityProperty` as the identity mixin. The on-the-wire ARM envelope for these older versions may legitimately differ from GA — preview / legacy versions are frozen snapshots — so a unilateral switch to the GA template risks a wire change we can't validate.

The mechanically-reusable bits from the GA TSP that can be applied regardless of the eventual envelope template choice are the two `#suppress` directives on the `ComputeResource` model declaration:

```typespec
#suppress "@azure-tools/typespec-azure-core/no-legacy-usage" "..."
#suppress "@azure-tools/typespec-client-generator-core/legacy-hierarchy-building-conflict" "..."
```

> **Question for service team:** For each affected preview / legacy API version (`2022-01` through `2025-01` — at minimum the two that block SDK migration today, `2023-08` and `2024-01`), please confirm the correct ARM envelope wiring so we can replace the converter's `<{}>` placeholder with a body type that re-attaches the `Compute` discriminated union. Specifically: (a) which TypeSpec template (`TrackedResourceWithOptionalLocation<ComputeResourceSchema>` to match the existing swagger semantics? `ProxyResource<Compute>` like GA? something else?), (b) whether `location` / `tags` / `sku` belong on the envelope for THAT version, and (c) which identity mixin applies (`ManagedServiceIdentityProperty`, the legacy variant, or none). Once those decisions are confirmed per version, the regenerated python client picks the Compute hierarchy back up automatically and the SDK migration unblocks with zero entity-layer changes.

Full TSP / swagger excerpts: see [appendix](#issue-3-evidence).

---

## Issue 4 — `2025-01-01-preview` 10× `duplicate-operation` + 2× `missing-paging-items`

`tsp compile` on the v2025-01 folder fails with **12 errors** (verbatim from `_compile-errors.log` in `docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/`):

- **10× `@typespec/http/duplicate-operation`** — 5 unique `(URL, verb)` pairs where two sibling interfaces each register an operation:
  1. `GET /subscriptions/{}/resourceGroups/{}/providers/Microsoft.MachineLearningServices/workspaces/{}/features` — `Workspace.list` (Workspace.tsp:135) vs `Feature.list` (Feature.tsp:37).
  2. `GET .../workspaces/{}/endpoints/{endpointName}` — `InferenceEndpoint.get` (InferenceEndpoint.tsp:40) vs `EndpointResourcePropertiesBasicResource.get` (EndpointResourcePropertiesBasicResource.tsp:33).
  3. `PUT .../workspaces/{}/endpoints/{endpointName}` — `InferenceEndpoint.createOrUpdate` (InferenceEndpoint.tsp:45) vs `EndpointResourcePropertiesBasicResource.createOrUpdate` (EndpointResourcePropertiesBasicResource.tsp:41).
  4. `GET .../workspaces/{}/endpoints` — `InferenceEndpoint.list` (InferenceEndpoint.tsp:68) vs `EndpointResourcePropertiesBasicResource.list` (EndpointResourcePropertiesBasicResource.tsp:55).
  5. `POST .../workspaces/{}/groups/{groupName}/getStatus` — `InferenceGroup.getStatus` (InferenceGroup.tsp:142) vs `InferenceGroup.getDeltaModelsStatusAsync` (InferenceGroup.tsp:111).

- **2× `@typespec/http/missing-paging-items`** — paged operations whose return type is missing the `@pageItems` annotation:
  1. `InferenceGroup.tsp:122 listDeltaModelsAsync` (`ArmResourceActionSync<...>`).
  2. `RaiBlocklistPropertiesBasicResource.tsp:93 addBulk` (`ArmResourceActionAsync<...>`).

The duplicate-operation errors are **not converter artefacts** — they reflect genuine swagger-design ambiguity where two sibling resource interfaces both claim the same `(path, verb)` pair. They will not go away by re-running the converter; the spec itself needs to disambiguate the routes. The paging errors are similar — `@pageItems` is a TypeSpec-side annotation that has to be added to the offending operations' return types.

Mechanical fix options on the spec side (for the duplicate-operation cases): decorate both operations in each colliding pair with `@sharedRoute` (when both genuinely service the same endpoint and the implementation multiplexes on the request body — both TSP-side operations survive and both still emit into the client), or restructure the offending interfaces so each `(path, verb)` pair is unique by giving one side a distinct sub-route (the pattern Kashif's GA TSP uses — both operations survive on distinct wire paths). For the paging cases: annotate the return type with `@pageItems` on the appropriate array property.

Note that both patterns preserve **both** colliding operations in the generated client — neither side disappears. Removing a TSP-side declaration would shrink the client surface vs. autorest and break the lossless-migration goal.

The same disambiguation surface is tracked upstream in spec PR [#43779](https://github.com/Azure/azure-rest-api-specs/pull/43779).

The SDK actively imports from `v2025-01-01-preview` — `CapabilityHost` (and related types from `_models_py3`) used by [operations/_capability_hosts_operations.py](../azure/ai/ml/operations/_capability_hosts_operations.py), and the **latest** `CommandJob` + `JobBase` used by [entities/_builders/command.py](../azure/ai/ml/entities/_builders/command.py), [entities/_job/command_job.py](../azure/ai/ml/entities/_job/command_job.py), [entities/_job/to_rest_functions.py](../azure/ai/ml/entities/_job/to_rest_functions.py). None of these consumers depend on the colliding endpoints / features / groups operations directly, but the regenerated client must still export the full v2025-01 surface (the autorest-generated client does today) for downstream re-export to remain lossless.

> **Question for service team:** For each of the 5 colliding `(path, verb)` pairs above, please pick a disambiguation strategy that keeps **both** operations in the generated client: either (a) annotate both with `@sharedRoute` if they are genuinely the same wire endpoint multiplexed on the request body, or (b) restructure one side onto a distinct sub-route (the GA-TSP pattern). And for the 2 paging operations, please confirm which array property on the return type is the paged item — we will then add the `@pageItems` annotation.

Full error log excerpt: see [appendix](#issue-4-evidence).

---

## Appendix — full evidence

The schemas / TSP files / compile-error logs below are extracted verbatim from the SDK's local swagger copy (`docs/swagger-local/...`) and from the converter-generated TSP folders (`docs/generated-tsp/...`). Sorted by issue number for easy lookup.

### Issue 1 schemas

All schemas below live in `docs/swagger-local/.../preview/2021-10-01-dataplanepreview/mfe.json`.

#### `AssetReferenceBase` (the polymorphic root)

```json
"AssetReferenceBase": {
  "description": "Base definition for asset references.",
  "required": [ "referenceType" ],
  "type": "object",
  "properties": {
    "referenceType": {
      "description": "Specifies the type of asset reference.",
      "$ref": "#/definitions/ReferenceType"
    }
  },
  "discriminator": "referenceType"
}
```

#### `ReferenceType` (the discriminator enum)

```json
"ReferenceType": {
  "description": "Enum to determine which reference method to use for an asset.",
  "enum": [ "Id", "DataPath", "OutputPath" ],
  "type": "string",
  "x-ms-enum": { "name": "ReferenceType", "modelAsString": true }
}
```

#### `IdAssetReference` (first claimant of `"Id"`)

```json
"IdAssetReference": {
  "description": "Reference to an asset via its ARM resource ID.",
  "required": [ "assetId" ],
  "type": "object",
  "allOf": [ { "$ref": "#/definitions/AssetReferenceBase" } ],
  "properties": {
    "assetId": { "type": "string", "pattern": "[a-zA-Z0-9_]" }
  },
  "x-ms-discriminator-value": "Id"
}
```

#### `ResourceManagementAssetReference` (second claimant of `"Id"` — the collision)

```json
"ResourceManagementAssetReference": {
  "description": "Resource Management asset reference.",
  "required": [ "sourceAssetId" ],
  "type": "object",
  "allOf": [ { "$ref": "#/definitions/AssetReferenceBase" } ],
  "properties": {
    "destinationName":    { "type": "string", "x-nullable": true },
    "destinationVersion": { "type": "string", "x-nullable": true },
    "sourceAssetId":      { "type": "string" }
  },
  "x-ms-discriminator-value": "Id",
  "x-ms-client-name": "ResourceManagementAssetReferenceDetails"
}
```

Both subtypes set `x-ms-discriminator-value: "Id"`. The minimal upstream fix is to give `ResourceManagementAssetReference` a unique value (e.g. `"ResourceManagementId"`) — and have the service accept the new on-the-wire value.

---

### Issue 2 schemas

All schemas below live in `docs/swagger-local/.../preview/2023-06-01-preview/mfe.json` (the v2023-04 and v2024-04 copies of `mfe.json` carry the same collision; v2023-06 is shown as the representative).

#### `DataVersionBase` (the polymorphic root, `x-ms-client-name: "DataVersionBaseProperties"`)

```json
"DataVersionBase": {
  "type": "object",
  "allOf": [ { "$ref": "#/definitions/AssetBase" } ],
  "required": [ "dataType", "dataUri" ],
  "properties": {
    "dataType":  { "$ref": "#/definitions/DataType" },
    "dataUri":   { "type": "string", "minLength": 1, "pattern": "[a-zA-Z0-9_]" },
    "intellectualProperty": { "$ref": "#/definitions/IntellectualProperty", "x-nullable": true },
    "stage":     { "type": "string", "x-nullable": true }
  },
  "discriminator": "dataType",
  "x-ms-client-name": "DataVersionBaseProperties"
}
```

#### `UriFolderDataVersion` (first claimant of `"uri_folder"`)

```json
"UriFolderDataVersion": {
  "description": "uri-folder data version entity",
  "type": "object",
  "allOf": [ { "$ref": "#/definitions/DataVersionBase" } ],
  "x-ms-discriminator-value": "uri_folder"
}
```

#### `DataImport` (second claimant of `"uri_folder"` — the collision)

```json
"DataImport": {
  "type": "object",
  "allOf": [ { "$ref": "#/definitions/DataVersionBase" } ],
  "properties": {
    "assetName": { "type": "string", "x-nullable": true },
    "source":    { "$ref": "#/definitions/DataImportSource", "x-nullable": true }
  },
  "x-ms-discriminator-value": "uri_folder"
}
```

#### Companion types pulled in with `DataImport`

`DataImportSource` is its own polymorphic root (`discriminator: "sourceType"`, enum `DataImportSourceType` with values `database` / `file_system`) and is referenced from `DataImport`. `DatabaseSource` and `FileSystemSource` are its subtypes (discriminator values `"database"` and `"file_system"` — internally consistent within the `DataImportSource` family, no collision). The SDK imports all three.

```json
"DataImportSource": {
  "required": [ "sourceType" ],
  "type": "object",
  "properties": {
    "connection": { "type": "string", "x-nullable": true },
    "sourceType": { "$ref": "#/definitions/DataImportSourceType" }
  },
  "discriminator": "sourceType"
}
```

```json
"DatabaseSource": {
  "type": "object",
  "allOf": [ { "$ref": "#/definitions/DataImportSource" } ],
  "properties": {
    "query":                 { "type": "string", "x-nullable": true },
    "storedProcedure":       { "type": "string", "x-nullable": true },
    "storedProcedureParams": { "type": "array", "items": { "type": "object", "additionalProperties": { "type": "string" } } }
  }
}
```

```json
"FileSystemSource": {
  "type": "object",
  "allOf": [ { "$ref": "#/definitions/DataImportSource" } ],
  "properties": {
    "path": { "type": "string", "x-nullable": true }
  },
  "x-ms-discriminator-value": "file_system"
}
```

The minimal upstream fix is to give `DataImport` a unique discriminator value (e.g. `"data_import"`) on `DataVersionBaseProperties.dataType`, and have the service accept the new on-the-wire value.

---

### Issue 3 evidence

#### Swagger source — `ComputeResource` from `docs/swagger-local/.../preview/2023-08-01-preview/machineLearningServices.json` (representative; every preview version has the same shape)

```json
"ComputeResource": {
  "type": "object",
  "description": "Machine Learning compute object wrapped into ARM resource envelope.",
  "allOf": [
    { "$ref": "...common-types/.../v3/types.json#/definitions/Resource" },
    { "$ref": "#/definitions/ComputeResourceSchema" }
  ],
  "properties": {
    "identity": { "$ref": ".../ManagedServiceIdentity" },
    "location": { "type": "string" },
    "tags":     { "type": "object", "additionalProperties": { "type": "string" }, "x-nullable": true },
    "sku":      { "$ref": ".../Sku", "x-nullable": true }
  }
}
```

#### Swagger source — `ComputeResourceSchema` (the mixin the converter dropped)

```json
"ComputeResourceSchema": {
  "type": "object",
  "properties": {
    "properties": {
      "description": "Compute properties",
      "$ref": "#/definitions/Compute"
    }
  }
}
```

`Compute` is a discriminated union (`discriminator: "computeType"`) with subtypes `AmlCompute`, `ComputeInstance`, `Kubernetes`, `VirtualMachine`, `HDInsight`, `Databricks`, `DataLakeAnalytics`, `SynapseSpark`, `DataFactory`, `AKS` plus all their nested support models. None of them are reachable from any operation once `ComputeResource` is emitted with an empty body.

#### Converter output — `docs/generated-tsp/MachineLearningServices.Management.v2023_08_01_preview/ComputeResource.tsp` lines 14-22 (verbatim)

```typespec
// FIXME: ComputeResource has no properties property
/**
 * Machine Learning compute object wrapped into ARM resource envelope.
 */
@parentResource(Workspace)
model ComputeResource
  is Azure.ResourceManager.Legacy.TrackedResourceWithOptionalLocation<{}> {
  ...ResourceNameParameter<
    Resource = ComputeResource,
    KeyName = "computeName",
    SegmentName = "computes",
    NamePattern = "^[a-zA-Z](?![a-zA-Z0-9-]*-\\d+$)[a-zA-Z0-9\\-]{2,23}$"
  >;
  ...Azure.ResourceManager.ManagedServiceIdentityProperty;
  ...Azure.ResourceManager.ResourceSkuProperty;
}
```

The `<{}>` is the empty-body template parameter. The same `FIXME` comment appears at line 14 of every one of the 11 versioned `ComputeResource.tsp` files (verified by `Select-String -Path docs/generated-tsp/**/ComputeResource.tsp -Pattern "FIXME: ComputeResource"` returning 11 matches).

#### Reference — GA, hand-authored `MachineLearningServices.Management/ComputeResource.tsp` (the working pattern)

```typespec
#suppress "@azure-tools/typespec-azure-core/no-legacy-usage" "Required for backward compatibility"
#suppress "@azure-tools/typespec-client-generator-core/legacy-hierarchy-building-conflict" "Required for SDK backward compatibility"
@parentResource(Workspace)
model ComputeResource is Azure.ResourceManager.ProxyResource<Compute> {
  ...ResourceNameParameter<
    Resource = ComputeResource,
    KeyName = "computeName",
    SegmentName = "computes",
    NamePattern = "^[a-zA-Z](?![a-zA-Z0-9-]*-\\d+$)[a-zA-Z0-9\\-]{2,23}$"
  >;

  #suppress "@azure-tools/typespec-azure-resource-manager/arm-resource-invalid-envelope-property" "Existing API includes additional envelope properties"
  #suppress "@azure-tools/typespec-azure-core/no-nullable" "Existing API contract allows null values"
  location?: string;

  #suppress "@azure-tools/typespec-azure-resource-manager/arm-resource-invalid-envelope-property" "Existing API includes additional envelope properties"
  #suppress "@azure-tools/typespec-azure-core/no-nullable" "Existing API contract allows null values"
  tags?: Record<string> | null;

  #suppress "@azure-tools/typespec-azure-resource-manager/arm-resource-invalid-envelope-property" "Existing API includes additional envelope properties"
  #suppress "@azure-tools/typespec-azure-core/no-nullable" "Existing API contract allows null values"
  sku?: Azure.ResourceManager.Foundations.Sku | null;

  ...Azure.ResourceManager.ManagedServiceIdentityProperty;
}
```

Two things distinguish this from the converter output:
1. The body type is `Compute` (not `{}`), which re-attaches the discriminated union to a reachable operation graph.
2. The two `#suppress` directives at the top of the model declaration tell the resource-manager linter that the legacy-hierarchy pattern is intentional. These directives are **mechanically reusable** across every per-version TSP regardless of which ARM-envelope template the service team ultimately picks.

#### Empirical orphan-prune verification (one-liner)

```pwsh
python -c "
import azure.ai.ml._restclient.v2023_08_01_preview_tsp.models as t
import azure.ai.ml._restclient.v2023_08_01_preview.models as a
print('TSP:', len(t.__all__), 'autorest:', len(a.__all__), 'missing:', len(set(a.__all__) - set(t.__all__)))
"
# → TSP: 659  autorest: 796  missing: 137
```

The 137 missing exports are almost entirely `Compute` family members plus a handful of related types (`SsoSetting`, `ResourceId`, `PaginatedComputeResourcesList`).

---

### Issue 4 evidence

The 12 errors below are the full verbatim contents of `docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/_compile-errors.log` (formatting normalized for readability):

```
docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/InferenceGroup.tsp:122:3 - error missing-paging-items: Paged operation 'listDeltaModelsAsync' return type must have a property annotated with @pageItems.
  > 122 |   listDeltaModelsAsync is ArmResourceActionSync<

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/RaiBlocklistPropertiesBasicResource.tsp:93:3 - error missing-paging-items: Paged operation 'addBulk' return type must have a property annotated with @pageItems.
  >  93 |   addBulk is ArmResourceActionAsync<

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/Workspace.tsp:135:3 - error @typespec/http/duplicate-operation: Duplicate operation "list" routed at "get /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/features".
  > 135 |   list is ArmResourceActionSync<

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/Feature.tsp:37:3 - error @typespec/http/duplicate-operation: Duplicate operation "list" routed at "get /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/features".
  >  37 |   list is ArmResourceListByParent<

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/InferenceEndpoint.tsp:40:3 - error @typespec/http/duplicate-operation: Duplicate operation "get" routed at "get /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/endpoints/{endpointName}".
  >  40 |   get is ArmResourceRead<InferenceEndpoint>;

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/EndpointResourcePropertiesBasicResource.tsp:33:3 - error @typespec/http/duplicate-operation: Duplicate operation "get" routed at "get /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/endpoints/{endpointName}".
  >  33 |   get is ArmResourceRead<EndpointResourcePropertiesBasicResource>;

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/InferenceEndpoint.tsp:45:3 - error @typespec/http/duplicate-operation: Duplicate operation "createOrUpdate" routed at "put /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/endpoints/{endpointName}".
  >  45 |   createOrUpdate is ArmResourceCreateOrReplaceAsync<InferenceEndpoint>;

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/EndpointResourcePropertiesBasicResource.tsp:41:3 - error @typespec/http/duplicate-operation: Duplicate operation "createOrUpdate" routed at "put /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/endpoints/{endpointName}".
  >  41 |   createOrUpdate is ArmResourceCreateOrReplaceAsync<

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/InferenceEndpoint.tsp:68:3 - error @typespec/http/duplicate-operation: Duplicate operation "list" routed at "get /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/endpoints".
  >  68 |   list is ArmResourceListByParent<

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/EndpointResourcePropertiesBasicResource.tsp:55:3 - error @typespec/http/duplicate-operation: Duplicate operation "list" routed at "get /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/endpoints".
  >  55 |   list is ArmResourceListByParent<

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/InferenceGroup.tsp:111:3 - error @typespec/http/duplicate-operation: Duplicate operation "getDeltaModelsStatusAsync" routed at "post /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/groups/{groupName}/getStatus".
  > 111 |   getDeltaModelsStatusAsync is ArmResourceActionSync<

docs/generated-tsp/MachineLearningServices.Management.v2025_01_01_preview/InferenceGroup.tsp:142:3 - error @typespec/http/duplicate-operation: Duplicate operation "getStatus" routed at "post /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}/groups/{groupName}/getStatus".
  > 142 |   getStatus is ArmResourceActionSync<

Found 12 errors.
```
