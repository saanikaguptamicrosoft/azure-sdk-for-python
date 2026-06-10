# TypeSpec migration — deltas for service team review

## Context

Delta refers to difference between local swagger copy in azure-ai-ml vs upstream swagger spec in Azure/azure-rest-api-specs.

We checked deltas at two levels:

1. **Entirely missing types** — types the SDK imports that have no definition at all in the upstream spec.
2. **Field-level drift** — types that exist in both local and upstream but whose field set / shape differs in a way the SDK relies on.

For each delta we need one of two answers from the service team:

- **Add the type / field to the upstream spec** — preferred when the feature is real and supported; we then regenerate and the SDK keeps working unchanged.
- **Remove the feature from the SDK** — when the type / field was never officially part of the API contract.

---

## Summary

| # | API version | What's missing / different in upstream | Count | Owning SDK file |
|---:|---|---|---:|---|
| 1 | `2022-01-01-preview` | `ManagedIdentity`, `PersonalAccessToken`, `ServicePrincipal`, `SharedAccessSignature`, `UsernamePassword` (and their base `Credentials`) — entirely missing | 6 types | [entities/_credentials.py](../azure/ai/ml/entities/_credentials.py) |
| 2 | `2022-10-01-preview` | `UserCreatedAcrAccount`, `UserCreatedStorageAccount` — entirely missing; plus parent properties `AcrDetails.userCreatedAcrAccount` and `StorageAccountDetails.userCreatedStorageAccount` also missing | 2 types + 2 fields | [entities/_registry/registry_support_classes.py](../azure/ai/ml/entities/_registry/registry_support_classes.py), [entities/_registry/util.py](../azure/ai/ml/entities/_registry/util.py) |
| 3 | `2022-10-01-preview` | `Registry.managedResourceGroupTags` — field present locally and actively written by SDK, missing in upstream | 1 field | [entities/_registry/registry.py](../azure/ai/ml/entities/_registry/registry.py) |
| 4 | `2024-04-01-preview` | `OpenAIEndpointDeploymentResourceProperties` — entirely missing | 1 type | [entities/_autogen_entities/models/_patch.py](../azure/ai/ml/entities/_autogen_entities/models/_patch.py) |
| 5 | `2024-04-01-preview` | `AccountKeyAuthTypeWorkspaceConnectionProperties.credentials` — disagrees with upstream on credential type (local uses `WorkspaceConnectionSharedAccessSignature{sas}`, upstream uses `WorkspaceConnectionAccountKey{key}`) | 1 field | [entities/_credentials.py](../azure/ai/ml/entities/_credentials.py) |

**Total: 9 entirely-missing types (including the shared `Credentials` base) + 4 field-level disagreements across 3 versions.** Full schema-by-schema definitions in the [appendix](#appendix--full-schemas).

---

## Delta 1 — `2022-01-01-preview` workspace-connection auth credentials

`entities/_credentials.py` builds workspace-connection credential payloads using these five types. They all inherit from a shared base `Credentials` (also missing upstream). The SDK takes user input like `ServicePrincipalConfiguration(client_id=..., client_secret=..., tenant_id=...)`, constructs the matching rest type, and sends it as the `properties.credentials` field of a Workspace Connection create/update request.

> **Question for service team:** Are these five credential types (and their `Credentials` base) intended to be part of the `2022-01-01-preview` Workspace Connections contract? If yes, please add them to the upstream swagger. If no, we will refactor `_credentials.py` to drop this code path.

Field-level schemas: see [appendix](#delta-1-schemas).

---

## Delta 2 — `2022-10-01-preview` registry user-supplied storage / ACR

`entities/_registry/registry_support_classes.py` and `entities/_registry/util.py` use these two types so a user can create an ML Registry that points at an **existing** ACR or Storage Account they own (rather than have Azure create new ones). The SDK wraps the user-supplied ARM resource ID in `UserCreatedAcrAccount(arm_resource_id=ArmResourceId(resource_id=...))` (or the storage equivalent) and attaches it to the registry create request.

> **Question for service team:** Are `UserCreatedAcrAccount` and `UserCreatedStorageAccount` intended to be part of the `2022-10-01-preview` ML Registries contract? If yes, please add them to the upstream swagger. If no, we will remove the "bring your own ACR / storage" path from the SDK for this version.

Field-level schemas: see [appendix](#delta-2-schemas).

---

## Delta 3 — `2022-10-01-preview` `Registry.managedResourceGroupTags`

The local copy of `Registry` (aka `RegistryProperties`) has a `managedResourceGroupTags` property:

```json
"managedResourceGroupTags": {
  "description": "Tags to be applied to the managed resource group associated with this registry.",
  "type": "object",
  "additionalProperties": { "type": "string", "x-nullable": true }
}
```

The upstream `Registry` has every other field but is missing this one.

The SDK actively writes this field at [entities/_registry/registry.py:230](../azure/ai/ml/entities/_registry/registry.py#L230):

```python
managed_resource_group_tags=self.tags
```

Users who set `tags=...` on a `Registry` expect those tags to flow through to the managed resource group; without this field upstream, the property would be silently dropped from the request after we regenerate.

> **Question for service team:** Is `Registry.managedResourceGroupTags` an intentional part of the `2022-10-01-preview` contract? If yes, please add it to the upstream `Registry` (a.k.a. `RegistryProperties`) definition. If no, we will remove `managed_resource_group_tags=self.tags` from `_registry/registry.py` and stop forwarding user tags to the managed resource group on this version.

Field-level schemas: see [appendix](#delta-3-schemas).

---

## Delta 4 — `2024-04-01-preview` Azure OpenAI endpoint deployment

`entities/_autogen_entities/models/_patch.py` uses `OpenAIEndpointDeploymentResourceProperties` to deserialize and construct Azure OpenAI deployments under a workspace endpoint. The type is the `properties` shape returned when an endpoint deployment carries `properties.type == "Azure.OpenAI"`.

The companion `EndpointDeploymentResourcePropertiesBasicResource` (the ARM envelope) **is** present in the upstream `2024-04-01-preview` spec — only the `OpenAIEndpointDeploymentResourceProperties` subtype is missing.

The same subtype **is** present in the upstream swaggers for `2024-01-01-preview` and `2024-07-01-preview`. Its absence from `2024-04-01-preview` only looks like an unintentional regression.

> **Question for service team:** Was the removal of `OpenAIEndpointDeploymentResourceProperties` from `2024-04-01-preview` intentional? If it was a regression, please add it back so it matches `2024-01` and `2024-07`. If intentional, please advise what the SDK should use on `2024-04` instead.

Field-level schemas: see [appendix](#delta-4-schemas).

---

## Delta 5 — `2024-04-01-preview` `AccountKeyAuthTypeWorkspaceConnectionProperties.credentials` shape disagreement

`AccountKeyAuthTypeWorkspaceConnectionProperties` is the discriminator subtype of `WorkspaceConnectionPropertiesV2` used when a workspace connection uses `authType == "AccountKey"`. Local and upstream disagree on the type of its `credentials` field:

| Source | `credentials.$ref` | Field shape |
|---|---|---|
| **Local** | `WorkspaceConnectionSharedAccessSignature` | `{ "sas": string }` |
| **Upstream** | `WorkspaceConnectionAccountKey` | `{ "key": string, "x-ms-secret": true }` |

The SDK (`entities/_credentials.py`) builds the request using the local shape — `RestWorkspaceConnectionSharedAccessSignature(sas=self.account_key)` — i.e. it puts the user's account key into a field called `sas`. Upstream expects it in a field called `key`.

This means one of two things is true:

- **The local back-port is wrong** — the SDK is currently sending `{ "credentials": { "sas": "<account_key>" } }` for an AccountKey auth, and the service is presumably reading the value out of the wrong field name (or silently dropping it). If we regenerate against upstream the SDK will switch to the correct `key` field but `_credentials.py` will need to be updated to match (`RestWorkspaceConnectionAccountKey(key=self.account_key)`).
- **The upstream is wrong** — the service actually reads `sas`, and the upstream's `WorkspaceConnectionAccountKey{key}` shape is dead code.

> **Question for service team:** What is the on-the-wire field name the service reads for AccountKey-auth workspace connections on `2024-04-01-preview`: `sas` or `key`? Whichever is correct, please align the spec to it. If `key` is correct (most likely), we will update the SDK to use `WorkspaceConnectionAccountKey` after regen.

Field-level schemas: see [appendix](#delta-5-schemas).

---

## Appendix — full schemas

The schemas below are extracted verbatim from the SDK's local swagger copy (`docs/swagger-local/.../<version>/<file>.json`). They show exactly what the SDK assumes the wire shape is. Sorted by type name for easy lookup.

### Delta 1 schemas

All schemas below live in `2022-01-01-preview/machineLearningServices.json`.

#### `Credentials` (base)

The polymorphism root for the five subtypes that follow. Empty itself; subtypes use `allOf: [Credentials]` to inherit from it.

```json
{
  "type": "object",
  "additionalProperties": false
}
```

#### `ManagedIdentity`

```json
{
  "type": "object",
  "allOf": [
    { "$ref": "#/definitions/Credentials" }
  ],
  "properties": {
    "resourceId": { "type": "string" },
    "clientId":   { "type": "string" }
  },
  "additionalProperties": false
}
```

Carries `resourceId` (ARM ID of a user-assigned managed identity) and `clientId` (the identity's client ID).

#### `PersonalAccessToken`

```json
{
  "type": "object",
  "allOf": [
    { "$ref": "#/definitions/Credentials" }
  ],
  "properties": {
    "pat": { "type": "string" }
  },
  "additionalProperties": false
}
```

Carries `pat` (the raw personal access token, e.g. for GitHub / Azure DevOps connections).

#### `ServicePrincipal`

```json
{
  "type": "object",
  "allOf": [
    { "$ref": "#/definitions/Credentials" }
  ],
  "properties": {
    "clientId":     { "type": "string" },
    "clientSecret": { "type": "string" },
    "tenantId":     { "type": "string" }
  }
}
```

Carries the three fields needed to authenticate as a service principal.

#### `SharedAccessSignature`

```json
{
  "type": "object",
  "allOf": [
    { "$ref": "#/definitions/Credentials" }
  ],
  "properties": {
    "sas": { "type": "string" }
  },
  "additionalProperties": false
}
```

Carries `sas` (a SAS token string).

#### `UsernamePassword`

```json
{
  "type": "object",
  "allOf": [
    { "$ref": "#/definitions/Credentials" }
  ],
  "properties": {
    "username": { "type": "string" },
    "password": { "type": "string" }
  },
  "additionalProperties": false
}
```

---

### Delta 2 schemas

Both schemas below live in `2022-10-01-preview/registries.json`. They reference `ArmResourceId`, which already exists in the upstream `2022-10-01-preview` spec and is shown here for completeness.

#### `UserCreatedAcrAccount`

```json
{
  "type": "object",
  "properties": {
    "armResourceId": {
      "description": "ARM ResourceId of a resource",
      "$ref": "#/definitions/ArmResourceId",
      "x-nullable": true
    }
  },
  "additionalProperties": false
}
```

#### `UserCreatedStorageAccount`

```json
{
  "type": "object",
  "properties": {
    "armResourceId": {
      "description": "ARM ResourceId of a resource",
      "$ref": "#/definitions/ArmResourceId",
      "x-nullable": true
    }
  },
  "additionalProperties": false
}
```

#### `ArmResourceId` (referenced, already upstream)

```json
{
  "description": "ARM ResourceId of a resource",
  "type": "object",
  "properties": {
    "resourceId": {
      "description": "Arm ResourceId is in the format '/subscriptions/{SubscriptionId}/resourceGroups/{ResourceGroupName}/providers/Microsoft.Storage/storageAccounts/{StorageAccountName}' or '/subscriptions/{SubscriptionId}/resourceGroups/{ResourceGroupName}/providers/Microsoft.ContainerRegistry/registries/{AcrName}'",
      "type": "string",
      "x-nullable": true
    }
  },
  "additionalProperties": false
}
```

---

### Delta 3 schemas

Lives in `2022-10-01-preview/registries.json`. The full local `Registry` (a.k.a. `RegistryProperties`) — the missing field is `managedResourceGroupTags`.

#### `Registry` (local) — missing `managedResourceGroupTags` upstream

```json
{
  "description": "Details of the Registry",
  "type": "object",
  "allOf": [
    { "$ref": "#/definitions/ResourceBase" }
  ],
  "properties": {
    "publicNetworkAccess":           { "type": "string", "x-nullable": true },
    "discoveryUrl":                  { "type": "string", "x-nullable": true },
    "intellectualPropertyPublisher": { "type": "string", "x-nullable": true },
    "managedResourceGroup": {
      "description": "Managed resource group created for the registry",
      "$ref": "#/definitions/ArmResourceId",
      "x-nullable": true
    },
    "mlFlowRegistryUri":             { "type": "string", "x-nullable": true },
    "privateLinkCount":              { "format": "int32", "type": "integer" },
    "regionDetails": {
      "type": "array",
      "items": { "$ref": "#/definitions/RegistryRegionArmDetails" },
      "x-ms-identifiers": [],
      "x-nullable": true
    },
    "managedResourceGroupTags": {
      "description": "Tags to be applied to the managed resource group associated with this registry.",
      "type": "object",
      "additionalProperties": { "type": "string", "x-nullable": true }
    }
  },
  "x-ms-client-name": "RegistryProperties",
  "additionalProperties": false
}
```

All properties except the last one (`managedResourceGroupTags`) are already in the upstream copy. The minimal fix is to add the one property to upstream `Registry` / `RegistryProperties`.

Also note (covered by Delta 2): the parent containers `AcrDetails` and `StorageAccountDetails` in this same version are missing the `userCreatedAcrAccount` and `userCreatedStorageAccount` properties respectively — both required by the Delta 2 fix. When adding the `UserCreated*` types upstream, please also add these properties to their parent containers.

---

### Delta 4 schemas

Lives in `2024-04-01-preview/workspaceRP.json`.

#### `OpenAIEndpointDeploymentResourceProperties`

```json
{
  "type": "object",
  "allOf": [
    { "$ref": "#/definitions/CognitiveServiceEndpointDeploymentResourceProperties" },
    { "$ref": "#/definitions/EndpointDeploymentResourceProperties" }
  ],
  "x-ms-discriminator-value": "Azure.OpenAI"
}
```

This is a discriminator subtype of `EndpointDeploymentResourceProperties` (which is present upstream). The discriminator field on the parent is matched against `"Azure.OpenAI"` to select this subtype. It also re-uses the field set from `CognitiveServiceEndpointDeploymentResourceProperties` (also present upstream) via `allOf` — so the subtype itself adds no new fields, only a new discriminator value plus the inherited fields from the two parents.

The minimal fix is to re-add this empty-body subtype with `x-ms-discriminator-value: "Azure.OpenAI"` to the `2024-04-01-preview` swagger. Both parent types are already in the spec, so no other changes are needed.

---

### Delta 5 schemas

All schemas below live in `2024-04-01-preview/workspaceRP.json`.

#### `AccountKeyAuthTypeWorkspaceConnectionProperties` — local

```json
{
  "type": "object",
  "x-ms-discriminator-value": "AccountKey",
  "allOf": [ { "$ref": "#/definitions/WorkspaceConnectionPropertiesV2" } ],
  "properties": {
    "credentials": { "$ref": "#/definitions/WorkspaceConnectionSharedAccessSignature" }
  }
}
```

#### `AccountKeyAuthTypeWorkspaceConnectionProperties` — upstream

```json
{
  "type": "object",
  "x-ms-discriminator-value": "AccountKey",
  "allOf": [ { "$ref": "#/definitions/WorkspaceConnectionPropertiesV2" } ],
  "properties": {
    "credentials": { "$ref": "#/definitions/WorkspaceConnectionAccountKey" }
  }
}
```

#### `WorkspaceConnectionSharedAccessSignature` (local — what SDK currently sends)

```json
{
  "type": "object",
  "properties": {
    "sas": { "type": "string" }
  }
}
```

#### `WorkspaceConnectionAccountKey` (upstream — what upstream expects)

```json
{
  "type": "object",
  "properties": {
    "key": { "type": "string", "x-ms-secret": true }
  }
}
```

The fix is whichever of the two is the truth on the wire. If the service reads `key` (most likely), the upstream is already correct and the SDK needs to update `_credentials.py` to use `WorkspaceConnectionAccountKey(key=...)` post-regen. If the service reads `sas`, the upstream's `WorkspaceConnectionAccountKey` is dead code and the local back-port is the source of truth.
