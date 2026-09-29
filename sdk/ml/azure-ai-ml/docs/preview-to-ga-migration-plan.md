# Plan: Move `azure-ai-ml` off unsupported preview API versions

> Direction reviewed and approved by Kashif Khan (Azure Python SDK core team).

## 1. Background

`azure-ai-ml` currently sends requests to the Machine Learning service using several preview API versions that are more than 18 months old. Per an email thread with William Baumann (June 2026), the service team no longer supports these versions by choice.

Kusto snapshot from William (July 2026) shows approximately 20 million requests per day going to these preview API versions — a real production dependency. If the service removes any of them, every SDK customer using the affected feature breaks.

Note: Guarantee of preview APIs is 6 months - 1 year. While GA versions persist indefinitely. If service team wants to sunset a GA version, it typically takes a 3-year deprecation process.

## 2. Goal

`azure-ai-ml` no longer sends requests to unsupported preview API versions of the Machine Learning service. Every request uses either the current GA API version, or a currently supported preview when a needed feature has not yet been graduated to GA.

## 3. Non-goals

- Not changing how the SDK talks to Azure services other than the Machine Learning service.
- Not expected to reduce SDK size meaningfully. The big size drop happened in the previous TypeSpec migration when per-version rest-client folders were consolidated. This project is a supportability play, not a size play.
- No customer-visible SDK API changes without PM sign-off. If service graduation forces any, a major version bump follows per Kashif's guidance.

## 4. Scope

Preview API versions for both ARM and Dataplane Projects are in scope.
- For ARM preview API versions, refer: [link](https://github.com/saanikaguptamicrosoft/azure-sdk-for-python/blob/saanika/typespec-migration-analysis/sdk/ml/azure-ai-ml/docs/typespec_migration_status.md)
- For Dataplane preview API versions refer: [link](https://github.com/PratibhaShrivastav18/azure-sdk-for-python/blob/shrivastavp/typespec-migration-plan/sdk/ml/azure-ai-ml/docs/typespec_migration_plan.md#phase-1-typespec-spec-authoring-azure-rest-api-specs-repo)

Two categories of places to fix, both inside `sdk/ml/azure-ai-ml/azure/ai/ml/`:

**Category A — preview API version passed as a query string.** Places where the SDK overrides the default API version (`2025-12-01` GA on `arm_ml_service` is default) to send a preview version instead.

**Category B — hand-built request payloads.** Places where an entity's `_to_rest_object()` method builds a raw dictionary or overrides individual JSON fields on a generated model, instead of using generated model classes. Done in the previous TypeSpec migration to preserve preview-only fields that don't exist in the current GA schema.

**Out of scope:**

- Non-preview API version overrides in `_ml_client.py` (`2022-05-01`, `2022-10-01`, `2023-04-01`, `2023-10-01`). These are on supported GA versions. William Baumann confirmed (Aug 27 2026) that old GA versions persist indefinitely; a sunset would follow a typical 3-year deprecation process.

## 5. Approach

Before starting, confirm the actual scope of preview API version usage per the appendix note — re-scan the codebase.

1. For each surface, check whether the current GA schema (`2025-12-01` for `arm_ml_service`, or the latest GA of the affected data-plane TypeSpec) covers the wire the SDK sends today. If yes, this is not a gap — the preview override can be dropped, and any related custom JSON removed at the next TypeSpec regen. If no, this is a gap — proceed to step 2.
2. For gaps, collate a single ask per affected service team requesting the missing fields or operations be added in their next API version.
3. Service most likely ships to a new preview version first. When it lands, regenerate the SDK's TypeSpec-generated client from that new preview and drop the previously-existing overrides — the SDK's default now becomes the new preview.
4. When the service graduates the feature into a new GA, regenerate the TypeSpec-generated client from that GA version. Assuming the service carries the fields forward from preview into GA, the only SDK-side work should be updating the affected end-to-end test recordings for the new API version query string.

## 6. Invariants

- **SDK code stays TypeSpec-aligned.** No custom JSON is added to work around missing schema. When a TypeSpec regen makes the previously-missing fields available in the generated model classes, we manually update the affected entity files to use them and delete the custom JSON.
- No changes to non-preview API version usage.
- Every PR under this project adds an entry to `sdk/ml/azure-ai-ml/CHANGELOG.md` in the current unreleased section.
- Any customer-visible SDK API change requires PM sign-off and a major version bump.

## 7. Validation

Every surface change should be validated against the same test surfaces we used in the previous `arm_ml_service` migration ([PR #47787](https://github.com/Azure/azure-sdk-for-python/pull/47787) has a worked example):

- Unit tests under `tests/<area>/unittests/`.
- Serialization smoke tests under `tests/smoke_serialization/` (guard against silent wire drift on entity `_to_rest_object()` methods).
- End-to-end recorded tests under `tests/<area>/e2etests/`. Recordings need updating for each affected surface because the API version query string changes; request and response bodies should otherwise be unchanged, so recording updates are typically mechanical.
- Notebook sample runs in the `azureml-examples` repository, compared against a `main`-branch baseline.
- Scenario tests

## Appendix — Category A surfaces

This list came from a quick scan of the codebase to help with initial effort estimation — not a definitive scope. Before starting execution, the task owner should:

- Re-scan the codebase to confirm the list is exhaustive (no preview API version usage missed).
- Cross-reference the deeper analysis docs for the historical picture: [Saanika's TypeSpec-migration analysis docs](https://github.com/saanikaguptamicrosoft/azure-sdk-for-python/tree/saanika/typespec-migration-analysis/sdk/ml/azure-ai-ml/docs) and Pratibha's [typespec_migration_plan.md](https://github.com/PratibhaShrivastav18/azure-sdk-for-python/blob/shrivastavp/typespec-migration-plan/sdk/ml/azure-ai-ml/docs/typespec_migration_plan.md).

Verified against `main` at commit `3f504a1e15` (Aug 24 2026). Kusto counts below are from William's July 2026 snapshot. To pull current numbers, run this query in the Vienna cluster (`viennausc.kusto.windows.net`, `Vienna` database):

```kql
AwesomeRequests
| where timestamp > ago(1d)
| where customDimensions ["x-ms-user-agent"] startswith "azure-ai-ml"
| parse url with * "api-version=" apiVersion
| extend apiVersion = tostring(split(apiVersion, "&", 0))
| summarize count() by apiVersion
| order by count_ desc
```

**In `azure/ai/ml/_ml_client.py`:**

| Line | API version | Kusto requests / day |
| ---: | --- | ---: |
| 97 | `2022-02-01-preview` | 1,490,498 |
| 98 | `2022-10-01-preview` | 13,869 |
| 99 | `2023-02-01-preview` | 8,829 |
| 100 | `2023-04-01-preview` | 2,366,701 |
| 101 | `2023-06-01-preview` | 170,584 |
| 102 | `2023-08-01-preview` | 5,936,403 |
| 103 | `2025-01-01-preview` | 536,787 |
| 104 | `2024-10-01-preview` | 1,090,085 |
| 108 | `2024-04-01-preview` | — |
| 112 | `2024-01-01-preview` | 8,731,670 |

**Data-plane clients with a preview default:**

| File | Default API version |
| --- | --- |
| `azure/ai/ml/_restclient/workspace_dataplane/_configuration.py` | `2023-06-01-preview` |
| `azure/ai/ml/_restclient/azure_ai_assets_v2024_04_01/azureaiassetsv20240401/_configuration.py` | `2026-05-01-preview` |

**Explicit override in an operation file:**

| File:line | API version |
| --- | --- |
| `azure/ai/ml/operations/_index_operations.py:120` | `2024-04-01-preview` |

Kusto's `AwesomeRequests` table covers Machine Learning control-plane traffic only, so data-plane numbers do not appear there.

## Links discussed in KT
- [Autorest to Typespec Migration docs](https://github.com/saanikaguptamicrosoft/azure-sdk-for-python/blob/saanika/typespec-migration-analysis/sdk/ml/azure-ai-ml/docs/typespec_migration_status.md)
  - [KT](https://microsoftapc-my.sharepoint.com/personal/mohlnu_microsoft_com/_layouts/15/stream.aspx?id=%2Fpersonal%2Fmohlnu%5Fmicrosoft%5Fcom%2FDocuments%2FRecordings%2FKnowledge%20cafe%2D20260630%5F150633%2DMeeting%20Recording%2Emp4&referrer=StreamWebApp%2EWeb&referrerScenario=AddressBarCopied%2Eview%2E0f8885f4%2D69b5%2D43d7%2Db5b2%2D7f58ef944548&share=cQqMvuQABpibR6rwJ%2D96zC08EgUCMK66pTvJYNOACNmFNeQaZQ) ([ppt](https://microsoftapc-my.sharepoint.com/:p:/g/personal/saanikagupta_microsoft_com/cQoFHONdikh4S5Vpj_3qCBuJEgUCXnfLfbOcxcrtzEg6X6IgOw))
- Code walkthrough
  - [Default API version setting example](https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/ml/azure-ai-ml/azure/ai/ml/_restclient/arm_ml_service/_configuration.py#L36)
  - [Overriding default API version example](https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/ml/azure-ai-ml/azure/ai/ml/_ml_client.py#L108)
  - [ARM Typespec folder](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/machinelearningservices/MachineLearningServices.Management)
  - [Typespec folder location defined in client](https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/ml/azure-ai-ml/azure/ai/ml/_restclient/arm_ml_service/tsp-location.yaml)
  - [API versions supported by Typespec project](https://github.com/Azure/azure-rest-api-specs/blob/b98dacf48388cade75dfa307cdb7fe64dcab0a2f/specification/machinelearningservices/MachineLearningServices.Management/main.tsp#L126)
- [TSP to client generation docs](https://azure.github.io/typespec-azure/docs/howtos/generate-with-tsp-client/intro_tsp_client/)
