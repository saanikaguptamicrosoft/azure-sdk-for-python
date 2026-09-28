# Plan: Move `azure-ai-ml` off unsupported preview API versions

> Direction reviewed and approved by Kashif Khan (Azure Python SDK core team).

## 1. Background

The previous AutoRest-to-TypeSpec migration changed how the SDK's REST clients are generated. It did **not** graduate the service APIs from preview to GA: a TypeSpec-generated client can still call a preview API version.

The SDK uses both the ARM management client (`arm_ml_service`) and separate Machine Learning data-plane clients. The ARM migrations consolidated versioned clients into `arm_ml_service` while preserving API-version overrides. Some data-plane clients were already TypeSpec-generated but still used preview API versions.

William Baumann confirmed that the old Machine Learning preview versions discussed in June 2026 are no longer supported. His July 2026 Kusto snapshot showed approximately 20 million requests per day to preview versions, demonstrating an active customer dependency. That control-plane snapshot does not establish the support status of each data-plane version.

This project addresses service API supportability, not another AutoRest-to-TypeSpec conversion. Existing GA versions remain out of scope, as William confirmed on August 27, 2026.

## 2. Goal

Remove dependencies on unsupported Machine Learning preview API versions. Each affected operation should use a supported GA API version, or a currently supported preview when a needed feature has not yet graduated to GA.

## 3. Non-goals

- Not changing how the SDK talks to Azure services other than the Machine Learning service.
- Not expected to reduce SDK size meaningfully. The main size reduction happened when the previous TypeSpec migration consolidated per-version REST clients.
- No customer-visible SDK API changes without PM sign-off. If service graduation forces any, a major version bump follows per Kashif's guidance.

## 4. Scope

**The inventory covers both ARM and Machine Learning data-plane preview API usage**, inside `sdk/ml/azure-ai-ml/azure/ai/ml/`. Data-plane clients have their own API versions and TypeSpec projects; they do not use the ARM client's GA version.

**Category A - preview API-version settings.** The initial inventory contains **13 code locations**, grouped below. This is a count of settings, not 13 distinct API versions or 13 unconverted clients.

| Service area | Preview usage | Locations | GA comparison target |
| --- | --- | ---: | --- |
| ARM management (`arm_ml_service`) | Preview overrides in `_ml_client.py` | 10 | The ARM GA contract, currently `2025-12-01` in this client |
| Workspace data plane (`workspace_dataplane`) | Client default: `2023-06-01-preview` | 1 | That service's GA contract, if available |
| Azure AI Assets data plane (`azure_ai_assets_v2024_04_01`) | Client default: `2026-05-01-preview`; index operation override: `2024-04-01-preview` | 2 | That service's GA contract, if available |

The two data-plane clients belong in the inventory even though they are already TypeSpec-generated. A preview label alone does not establish that a version is unsupported; in particular, the newer Assets preview must not be treated as one of the old ARM previews. Record a supported interim version where GA does not yet cover the feature. The full version list and source locations are in the appendix.

**Category B - compatibility code for preview-only payloads.** Identify hand-built dictionaries or individual JSON-field overrides that preserve features missing from the target GA schema. These may occur in entity `_to_rest_object()` methods or related helpers. Replace them with generated model fields once the service contract includes the feature. Not every raw dictionary is such a workaround; classify each use before changing it.

**Historical context:** [Pratibha's original migration plan](https://github.com/PratibhaShrivastav18/azure-sdk-for-python/blob/shrivastavp/typespec-migration-plan/sdk/ml/azure-ai-ml/docs/typespec_migration_plan.md) lists the old AutoRest clients and the separate data-plane TypeSpec projects. [Saanika's TypeSpec migration status](https://github.com/saanikaguptamicrosoft/azure-sdk-for-python/blob/saanika/typespec-migration-analysis/sdk/ml/azure-ai-ml/docs/typespec_migration_status.md) and [supporting analysis](https://github.com/saanikaguptamicrosoft/azure-sdk-for-python/tree/saanika/typespec-migration-analysis/sdk/ml/azure-ai-ml/docs) document the subsequent migration. Their historical client counts are not the count of preview API-version settings remaining today; use the appendix as the starting inventory and refresh it before execution.

**Out of scope:** Non-preview API-version usage, including the ARM overrides `2022-05-01`, `2022-10-01`, `2023-04-01`, and `2023-10-01`. William confirmed that these existing GA versions remain supported; a future sunset would follow a typically three-year deprecation process. That confirmation does not need to be requested again.

## 5. Approach

Re-scan the codebase to refresh the Category A inventory and identify Category B compatibility code. Use William's existing confirmation for the old ARM previews and GA versions. For data-plane entries, record the service's supported target separately; do not infer its lifecycle from the ARM version policy.

1. For each affected operation, compare the requests, responses, and features used today with its service's GA contract: `2025-12-01` for the current ARM client, or the corresponding data-plane GA contract if one exists. Where GA covers the behavior, update the API-version setting and use generated model fields in place of the related compatibility code, regenerating the client if needed. Validate before removing the old path.
2. Where GA is missing a required field or operation, or no GA contract exists, collate one request per affected service team for the missing coverage and a supported migration target. This is a feature-gap discussion, not a repeat of the already-settled ARM support-status confirmation.
3. If the service ships the required coverage in a supported preview first, regenerate the affected client as needed and move those operations to that version. Keep unrelated GA operations on their existing versions; changing a shared client's default must not silently move them to preview.
4. When the feature graduates to GA, regenerate as needed, update the affected API-version settings, replace any remaining related compatibility code, and validate customer-visible behavior. Update test recordings to reflect the verified service behavior, not just the new version string.

## 6. Invariants

- **SDK code stays TypeSpec-aligned.** No custom JSON is added to work around missing schema. When regeneration makes the previously missing fields available, manually update the affected handwritten code to use the generated models and remove the corresponding workaround.
- No changes to non-preview API-version usage.
- Every PR under this project adds an entry to `sdk/ml/azure-ai-ml/CHANGELOG.md` in the current unreleased section.
- Any customer-visible SDK API change requires PM sign-off and a major version bump.

## 7. Validation

Validate each affected operation against the existing SDK behavior, using the test areas from the previous migration ([PR #47787](https://github.com/Azure/azure-sdk-for-python/pull/47787) provides an example). Run suites in CI or the designated test environment.

- Unit tests under `tests/<area>/unittests/`, including response conversion, public attributes, enum values, and affected control flow.
- Serialization smoke tests under `tests/smoke_serialization/` to check request payloads. Request serialization alone does not prove user-experience compatibility.
- End-to-end tests under `tests/<area>/e2etests/`, re-recorded against the chosen service version. Review request and response differences rather than assuming only the API-version query string changes.
- Notebook sample runs in `azureml-examples`, compared against a recorded pre-change SDK baseline.

## Appendix - Category A inventory

This initial inventory was verified against `main` at commit `3f504a1e15` (August 24, 2026). Refresh the locations and versions before execution; line numbers below refer to that snapshot. The three groups total **10 ARM overrides + 2 data-plane defaults + 1 data-plane operation override = 13 locations**. Identical version strings on different services do not denote the same contract.

### ARM management: 10 overrides

All are in `azure/ai/ml/_ml_client.py` and select a preview API version on `arm_ml_service` instead of its default.

| Snapshot line | API version | Kusto requests / day |
| ---: | --- | ---: |
| 97 | `2022-02-01-preview` | 1,490,498 |
| 98 | `2022-10-01-preview` | 13,869 |
| 99 | `2023-02-01-preview` | 8,829 |
| 100 | `2023-04-01-preview` | 2,366,701 |
| 101 | `2023-06-01-preview` | 170,584 |
| 102 | `2023-08-01-preview` | 5,936,403 |
| 103 | `2025-01-01-preview` | 536,787 |
| 104 | `2024-10-01-preview` | 1,090,085 |
| 108 | `2024-04-01-preview` | Not in snapshot |
| 112 | `2024-01-01-preview` | 8,731,670 |

### Data plane: 2 client defaults

| Client configuration | Default API version |
| --- | --- |
| `azure/ai/ml/_restclient/workspace_dataplane/_configuration.py` | `2023-06-01-preview` |
| `azure/ai/ml/_restclient/azure_ai_assets_v2024_04_01/azureaiassetsv20240401/_configuration.py` | `2026-05-01-preview` |

The Assets directory name is not its default API version; read the configuration rather than inferring the version from the folder name.

### Data plane: 1 operation override

| Source location | Client | API version |
| --- | --- | --- |
| `azure/ai/ml/operations/_index_operations.py:120` | Azure AI Assets | `2024-04-01-preview` |

### Usage snapshot

The counts above are from William's July 2026 snapshot. Kusto's `AwesomeRequests` table covers Machine Learning control-plane traffic, not the separate data-plane clients. Request volume shows usage, not a version's support status.

To refresh control-plane counts, run this query in the Vienna cluster (`viennausc.kusto.windows.net`, `Vienna` database):

```kql
AwesomeRequests
| where timestamp > ago(1d)
| where customDimensions ["x-ms-user-agent"] startswith "azure-ai-ml"
| parse url with * "api-version=" apiVersion
| extend apiVersion = tostring(split(apiVersion, "&", 0))
| summarize count() by apiVersion
| order by count_ desc
```

## Links discussed in KT

- [AutoRest-to-TypeSpec migration status](https://github.com/saanikaguptamicrosoft/azure-sdk-for-python/blob/saanika/typespec-migration-analysis/sdk/ml/azure-ai-ml/docs/typespec_migration_status.md)
- [KT recording](https://microsoftapc-my.sharepoint.com/personal/mohlnu_microsoft_com/_layouts/15/stream.aspx?id=%2Fpersonal%2Fmohlnu%5Fmicrosoft%5Fcom%2FDocuments%2FRecordings%2FKnowledge%20cafe%2D20260630%5F150633%2DMeeting%20Recording%2Emp4&referrer=StreamWebApp%2EWeb&referrerScenario=AddressBarCopied%2Eview%2E0f8885f4%2D69b5%2D43d7%2Db5b2%2D7f58ef944548&share=cQqMvuQABpibR6rwJ%2D96zC08EgUCMK66pTvJYNOACNmFNeQaZQ)
- [ARM client configuration](https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/ml/azure-ai-ml/azure/ai/ml/_restclient/arm_ml_service/_configuration.py#L36)
- [Client API-version selection](https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/ml/azure-ai-ml/azure/ai/ml/_ml_client.py#L108)
- [Management TypeSpec project](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/machinelearningservices/MachineLearningServices.Management)
- [ARM TypeSpec source configuration](https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/ml/azure-ai-ml/azure/ai/ml/_restclient/arm_ml_service/tsp-location.yaml)
- [Management TypeSpec entry point](https://github.com/Azure/azure-rest-api-specs/blob/main/specification/machinelearningservices/MachineLearningServices.Management/main.tsp)
- [Generating clients from TypeSpec](https://azure.github.io/typespec-azure/docs/howtos/generate-with-tsp-client/intro_tsp_client/)
