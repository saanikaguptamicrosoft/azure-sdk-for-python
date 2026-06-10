# TypeSpec migration — deltas for service team review

## Context

As part of migrating `azure-ai-ml` from autorest to TypeSpec, we generated TypeSpec for the existing ML preview API versions. For three of them, the SDK consumes types that the TypeSpec output does not produce — because those types are missing from the **upstream service spec** at `Azure/azure-rest-api-specs`. They exist only in the locally-modified copy of the swagger that lives in this SDK repo (`docs/swagger-local/`). When the TypeSpec compiles, it emits an OpenAPI matching the upstream spec, so these types disappear from the generated rest client and the SDK fails to build.

For each delta we need one of two answers from the service team:

- **Add the type(s) to the upstream spec** — preferred when the feature is real and supported; we then regenerate and the SDK keeps working unchanged.
- **Remove the feature from the SDK** — when the type was never officially part of the API contract.

---

## Summary

| API version | Types consumed by SDK but missing upstream | Count | Owning SDK file |
|---|---|---:|---|
| `2022-01-01-preview` | `ManagedIdentity`, `PersonalAccessToken`, `ServicePrincipal`, `SharedAccessSignature`, `UsernamePassword` (and their base `Credentials`) | 5 (+1 base) | [entities/_credentials.py](../azure/ai/ml/entities/_credentials.py) |
| `2022-10-01-preview` | `UserCreatedAcrAccount`, `UserCreatedStorageAccount` | 2 | [entities/_registry/registry_support_classes.py](../azure/ai/ml/entities/_registry/registry_support_classes.py), [entities/_registry/util.py](../azure/ai/ml/entities/_registry/util.py) |
| `2024-04-01-preview` | `OpenAIEndpointDeploymentResourceProperties` | 1 | [entities/_autogen_entities/models/_patch.py](../azure/ai/ml/entities/_autogen_entities/models/_patch.py) |

**Total: 8 types across 3 versions.** Full schema-by-schema definitions in the [appendix](#appendix--full-schemas).

### Note on `2022-12-01-preview`

This version is being deprecated and its single consumer ([entities/_compute/aml_compute.py](../azure/ai/ml/entities/_compute/aml_compute.py)) will be re-routed to `2022-10-01-preview`. The six types it imports — `AmlCompute`, `AmlComputeProperties`, `ComputeResource`, `ResourceId`, `ScaleSettings`, `UserAccountCredentials` — all exist in upstream `2022-10-01-preview`. **The redirect adds zero new types to the `2022-10` delta above.** No service team action is needed for `2022-12-01-preview`.

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

## Delta 3 — `2024-04-01-preview` Azure OpenAI endpoint deployment

`entities/_autogen_entities/models/_patch.py` uses `OpenAIEndpointDeploymentResourceProperties` to deserialize and construct Azure OpenAI deployments under a workspace endpoint. The type is the `properties` shape returned when an endpoint deployment carries `properties.type == "Azure.OpenAI"`.

The companion `EndpointDeploymentResourcePropertiesBasicResource` (the ARM envelope) **is** present in the upstream `2024-04-01-preview` spec — only the `OpenAIEndpointDeploymentResourceProperties` subtype is missing.

The same subtype **is** present in the upstream swaggers for `2024-01-01-preview` and `2024-07-01-preview`. Its absence from `2024-04-01-preview` only looks like an unintentional regression.

> **Question for service team:** Was the removal of `OpenAIEndpointDeploymentResourceProperties` from `2024-04-01-preview` intentional? If it was a regression, please add it back so it matches `2024-01` and `2024-07`. If intentional, please advise what the SDK should use on `2024-04` instead.

Field-level schemas: see [appendix](#delta-3-schemas).

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
