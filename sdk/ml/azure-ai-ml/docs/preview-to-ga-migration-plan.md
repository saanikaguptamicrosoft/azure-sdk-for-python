# Plan: Move `azure-ai-ml` off unsupported preview API versions

> Direction reviewed and approved by Kashif Khan (Azure Python SDK core team).

## 1. Background

`azure-ai-ml` currently sends requests to the Machine Learning service using several preview API versions that are more than 18 months old. Per an email thread with William Baumann (June 2026), the service team no longer supports these versions and they can be removed at any time.

Kusto snapshot from William (July 2026) shows approximately 20 million requests per day going to these preview API versions — a real production dependency. If the service removes any of them, every SDK customer using the affected feature breaks.

## 2. Goal

Every request `azure-ai-ml` sends to the Machine Learning service uses a currently supported GA API version.

## 3. Non-goals

- Not changing how the SDK talks to Azure services other than the Machine Learning service.
- Not expected to reduce SDK size meaningfully. The big size drop happened in the previous TypeSpec migration when per-version rest-client folders were consolidated. This project is a supportability play, not a size play.
- No customer-visible SDK API changes without PM sign-off. If service graduation forces any, a major version bump follows per Kashif's guidance.

## 4. Scope

Two categories of places to fix, both inside `sdk/ml/azure-ai-ml/azure/ai/ml/`:

**Category A — preview API version passed as a query string.** Places where the SDK overrides the default API version (`2025-12-01` GA on `arm_ml_service`) to send a preview version instead. 13 places today: 10 in `azure/ai/ml/_ml_client.py`, 2 data-plane clients whose own default is a preview version, and 1 explicit override inside an operation file. Full list in the appendix.

**Category B — hand-built request payloads.** Places where an entity's `_to_rest_object()` method builds a raw dictionary or overrides individual JSON fields on a generated model, instead of using generated model classes. Done in the previous TypeSpec migration to preserve preview-only fields that don't exist in the current GA schema. Not enumerated here — needs identification during execution.

**Out of scope:**

- Non-preview API version overrides in `_ml_client.py` (`2022-05-01`, `2022-10-01`, `2023-04-01`, `2023-10-01`). These are on supported GA versions.
- Semantic-versioned data-plane clients (`dataset_dataplane`, `model_dataplane`, `runhistory`, `registry_discovery`) — different lifecycle, tentatively out of scope pending confirmation with William.
- Preview API version strings targeting other Azure services (`Microsoft.Resources`).

## 5. Approach

1. For each surface, check whether the current supported GA API version (`2025-12-01`, or the latest GA of the affected data-plane TypeSpec) already covers the wire. If yes, drop the preview override — no service-team work needed.
2. For gaps, collate a single ask per affected service team requesting the missing fields or operations be added in their next API version.
3. Service most likely ships to a new preview version first. When it lands, regenerate the SDK's TypeSpec-generated client from that new preview and drop the previously-existing overrides — the SDK's default now becomes the new preview.
4. When the service graduates the feature into a new GA, regenerate the TypeSpec-generated client from that GA version. Assuming the service carries the fields forward from preview into GA, this should work with no additional SDK changes.

## 6. Invariants

- **SDK code stays TypeSpec-aligned.** Custom JSON payloads (Category B) are only acceptable as a short-lived bridge between service adding a schema and the SDK regenerating from the new TypeSpec. Never as a permanent workaround.
- No changes to non-preview API version usage.
- Every PR under this project adds an entry to `sdk/ml/azure-ai-ml/CHANGELOG.md` in the current unreleased section.
- Any customer-visible SDK API change requires PM sign-off and a major version bump.

## 7. Validation

Every surface change should be validated against the same test surfaces we used in the previous `arm_ml_service` migration ([PR #47787](https://github.com/Azure/azure-sdk-for-python/pull/47787) has a worked example):

- Unit tests under `tests/<area>/unittests/`.
- Serialization smoke tests under `tests/smoke_serialization/` (guard against silent wire drift on entity `_to_rest_object()` methods).
- End-to-end recorded tests under `tests/<area>/e2etests/`. Recordings need updating for each affected surface because the API version query string changes; request and response bodies should otherwise be unchanged, so recording updates are typically mechanical.
- Notebook sample runs in the `azureml-examples` repository, compared against a `main`-branch baseline.

## Appendix — Category A surfaces

Verified against `main` at commit `3f504a1e15` (Aug 24 2026). Kusto counts are from William's July 2026 snapshot.

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
