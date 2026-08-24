# Plan: Move `azure-ai-ml` off unsupported preview API versions

> **Status:** Draft for review. Author: Saanika. Reviewers: Kashif Khan (SDK/TSP patterns), William Baumann + Anthony Karloff (Machine Learning service).
> Execution is intended to be picked up by the vendor team once this plan is approved.

---

## 1. Background

`azure-ai-ml` (Python SDK, package `azure-ai-ml`) currently sends requests to the Machine Learning service using several **preview** API versions that are more than 18 months old. In an email thread on 6/15–6/17/2026 ("Missing service Typespecs"), William Baumann (ML service side) confirmed:

- None of these preview API versions are currently supported by the service team.
- The service team will not fund adding TypeSpec definitions for them.
- These API versions could be removed by the service at any time, without notice.
- Anthony Karloff inherits follow-ups on the service side.

A Kusto snapshot from William (7/7/2026, `AwesomeRequests`, `x-ms-user-agent starts with "azure-ai-ml"`, last 1 day) shows the scale of the exposure — approximately **20 million requests per day** currently going to preview API versions. The top three alone:

| API version | Requests / day |
| --- | ---: |
| `2024-01-01-preview` | 8,731,670 |
| `2023-08-01-preview` | 5,936,403 |
| `2023-04-01-preview` | 2,366,701 |

If the service removes any of these, every SDK customer using the affected feature breaks. This plan describes how we get off preview API versions in a controlled way.

---

## 2. Goal

Every request the SDK sends to the Machine Learning service must use a **currently supported GA API version** — no dependency on preview API versions, and no code that hand-builds request payloads to work around missing schema.

---

## 3. Non-goals

- We are **not** changing anything about how `azure-ai-ml` talks to Azure services other than the Machine Learning service.
- We are **not** regenerating the shared TypeSpec-generated client `arm_ml_service` as part of this project (that is separate maintenance).
- We are **not** changing any customer-visible SDK method signatures unless a service-team decision forces us to. If it does, PM sign-off is required first.

---

## 4. Scope

There are two categories of places to fix. Both are inside `sdk/ml/azure-ai-ml/azure/ai/ml/`.

> **Quick glossary before we dive in.**
> - *Control-plane* = requests to `https://management.azure.com/...` that manage Azure resources (create a workspace, list jobs, etc.). One shared client for `azure-ai-ml`: `arm_ml_service`.
> - *Data-plane* = requests to a workspace-specific endpoint (`https://<region>.api.azureml.ms/...`) that operate on data inside a workspace (upload a dataset, read run history, etc.). There are several separate clients for these, one per data-plane surface.
> - Both planes have their own API version strings. Both are in scope if the version is a preview and belongs to the Machine Learning service.

### Category A — Requests currently sent with a preview API version query string

The SDK has a shared client called `arm_ml_service` (a TypeSpec-generated Python client) whose default API version is `2025-12-01` (GA). In several places we override that default and send a preview API version instead. The override is a single line that looks like this:

```python
ServiceClient042023Preview = partial(MachineLearningServicesMgmtClient, api_version="2023-04-01-preview")
```

All such overrides live in `azure/ai/ml/_ml_client.py`. There are **10 preview overrides** on this client today. On top of that there are **2 separate data-plane clients whose own default is already a preview API version**, and **1 explicit preview override in an operation file**. See the [full list in the Appendix](#appendix-preview-surfaces-inventory) — **13 surfaces total**.

### Category B — Requests where the SDK hand-builds the payload

In some entities, the SDK doesn't use the generated model classes to build the request body — instead it constructs a plain Python dictionary or overrides individual JSON fields on a generated model using `obj["camelCaseFieldName"] = value`. This was done during the earlier TypeSpec migration whenever the current GA schema (`2025-12-01`) did not contain a field or operation that a preview API version had. The custom code preserves the preview wire shape even though the generated client wouldn't produce it.

Known examples from prior work: monitoring signals and thresholds, `ModelPerformance` / `GenerationSafetyQuality` / `GenerationTokenStatistics` / `MonitoringDataSegment` / `MonitoringWorkspaceConnection`, `SsoSetting`, `UserCreatedAcrAccount` and `UserCreatedStorageAccount`, `HDFS` datastore type, `RegistryProperties.managedResourceGroupTags`, and several mixed-tree children under deployment settings.

This is **not a proven-complete list**. The vendor team will need to run the grep described in Section 6 to find them all.

### Out of scope

- The 4 non-preview GA overrides in `_ml_client.py` (`2022-05-01`, `2022-10-01`, `2023-04-01`, `2023-10-01`). These are on supported API versions and get 24-month deprecation notice under Azure's API version policy — they are not the fire.
- The semantic-versioned data-plane clients: `dataset_dataplane` (`1.5.0`), `model_dataplane` (`1.0.0`), `runhistory` (`v1.0`), `registry_discovery` (`v1.0`). These do not use the ARM date-based preview convention and appear to be under a different lifecycle. **Tentatively** out of scope — see Investigation Item 2 in Section 10; if William confirms they are also on a limited-support clock, they move into scope.
- Preview API version strings that target OTHER Azure services (`Microsoft.Resources` deployment validation at `entities/_validation/remote.py:133`, and `Microsoft.Resources` generic resource lookups in `_utils/azure_resource_utils.py` and `operations/_virtual_cluster_operations.py`). Different service, different owner.

---

## 5. Target end-state and phased progression

**Target end-state:** every request in `azure-ai-ml` uses the current supported GA API version of the Machine Learning service (today `2025-12-01` for `arm_ml_service`; equivalent latest-GA for each data-plane client). No custom-built request payloads. No preview API version overrides.

Getting there realistically requires waiting on service-team work. We should expect three stable states along the way:

**State 0 — today.** SDK depends on unsupported preview API versions. Some fields/operations have no equivalent in the current GA schema.

**State 1 — intermediate.** For each field/operation missing from the current GA schema, the service team adds it to a **new preview API version** (this is the normal Azure convention; graduating straight to GA is rare on a first ask). The SDK moves off the unsupported preview versions and onto the new preview version, which is still within its 18-month support window at the time of the move. Overrides are still in `_ml_client.py`, but they now point at API versions the service actively supports.

**State 2 — final.** The service team graduates the feature into a new GA API version. TypeSpec regenerates. The SDK drops every override, removes all Category B custom code, and uses the generated model classes normally.

A GA API version is frozen once shipped, so missing features can't be added to `2025-12-01` retroactively — the service always ships a new API version for anything new. That means the "current supported GA" the SDK targets will move forward on its own as TypeSpec regens land.

---

## 6. Playbook (step-by-step for execution)

This section is the actual work. It is written for a vendor engineer with limited SDK context; every step names the exact command or file to look at.

### Step 1 — Confirm the inventory

Run this from the repo root to see the current list of API versions overridden in `_ml_client.py`:

```powershell
git grep -nE "api_version=\"20[0-9]{2}-[0-9]{2}-[0-9]{2}(-preview)?\"" sdk/ml/azure-ai-ml/azure/ai/ml/_ml_client.py
```

Cross-check against the [Appendix](#appendix-preview-surfaces-inventory) below. Report any drift (new preview override added since this plan was written, or an existing one removed).

### Step 2 — Find every place a preview API version is passed as a query string outside `_ml_client.py`

```powershell
git grep -nE "api_version=\"20[0-9]{2}-[0-9]{2}-[0-9]{2}-preview\"" sdk/ml/azure-ai-ml/azure/ai/ml
```

For each hit, confirm the target service is `Microsoft.MachineLearningServices` — grep upward in the file for `MachineLearningServicesMgmtClient`, `AzureAiAssetsClient`, or one of the data-plane clients. If the target is a different service (for example `azure.mgmt.resource.ResourceManagementClient`), that hit is out of scope; log it and move on.

### Step 3 — Find hand-built request payloads (Category B)

Two patterns to search for:

**Pattern B-1: wire-key overrides on a generated model.** These look like `<some_object>["camelCaseName"] = <value>` inside methods named `_to_rest_object`. Command:

```powershell
git grep -nE '\["[a-z][a-zA-Z0-9]+"\]\s*=' sdk/ml/azure-ai-ml/azure/ai/ml/entities
```

Filter the results to hits inside `_to_rest_object` methods or private helpers those methods call.

**Pattern B-2: `_to_rest_object` returning a plain dict.** Some methods return a `dict(...)` or `{...}` literal instead of a rest model. Command (PowerShell):

```powershell
Get-ChildItem sdk/ml/azure-ai-ml/azure/ai/ml/entities -Recurse -Filter *.py |
  Select-String -Pattern "def _to_rest_object" -Context 0,8 |
  Where-Object { $_.Context.PostContext -match "return \{|return dict\(" } |
  ForEach-Object { "{0}:{1}" -f $_.Path, $_.LineNumber }
```

Combine both lists into a working inventory of Category B hits.

### Step 4 — For each hit (Category A or B), identify what the wire actually contains

For a Category A hit, the wire body is whatever the generated model at that call site produces — the same as it would be under the default GA API version. Only the `?api-version=…` query string is different.

For a Category B hit, the wire body is whatever the hand-built dict emits. Copy each field name (including nested paths).

Then compare against `2025-12-01`. The canonical schema for `2025-12-01` lives in the TypeSpec source at `specification/machinelearningservices/MachineLearningServices.Management/` in [`Azure/azure-rest-api-specs`](https://github.com/Azure/azure-rest-api-specs). To find the exact commit the SDK is currently pinned to, read `sdk/ml/azure-ai-ml/azure/ai/ml/_restclient/arm_ml_service/tsp-location.yaml` at execution time — it may have moved forward since this plan was written. A field-by-field comparison against the operation's model in that TypeSpec source answers whether the current GA schema already covers this hit.

For each hit, produce one of three verdicts:

- **Green — safe to remove now.** Every field the SDK sends under this hit is present in the `2025-12-01` schema with the same name and semantics. No service-team work needed.
- **Amber — small additive gap.** One or two fields the SDK sends are not in `2025-12-01` but are additive (the service already accepts them at the preview API version). Service team just needs to add them to the next GA revision.
- **Red — significant gap.** An operation is missing entirely, a field has a different name/shape, or the semantics differ. Bigger service-team ask; may need a design conversation.

### Step 5 — Handle the Green hits

For each Green hit, in a separate PR:

1. Remove the override from `_ml_client.py` (Category A) or replace the hand-built dict with the generated model (Category B).
2. Update all consumers to use the default client / generated model.
3. Verify the request bytes on the wire are still what the service expects. Options:
   - Preferred: re-record the affected end-to-end tests against a live workspace and compare recordings. Recording infrastructure lives in `tests/**/e2etests/`; ask Kashif or the ML SDK team for the correct playback/live workflow.
   - Alternative: build the same entity on `main` and on the branch, serialize both to the wire (`json.dumps(entity._to_rest_object(), cls=SdkJSONEncoder, exclude_readonly=True)` for arm hybrid models), diff the JSON. This is an offline check — good for a quick sanity read, but does not catch response-side differences.
4. Add a one-line entry to `sdk/ml/azure-ai-ml/CHANGELOG.md` under the current unreleased section, in the "Other Changes" group. Example wording: *"Migrated <feature area> off the `<api-version>` preview API version onto the current GA."*
5. **One PR per hit** so reviewers can inspect changes independently and revert cleanly if a regression appears.

### Step 6 — Handle the Amber and Red hits

For each Amber and Red hit, do **not** change any code yet. Add a row to the gap-collation document (Section 7 below). Once we have the full list, we send it to the ML service team as a single ask.

Once the service team publishes a new API version containing the requested fields/operations:

- If they publish to a new **preview** version (the more likely first response), update the override in `_ml_client.py` to that new preview version. Keep the row in the gap-collation doc marked as "waiting for GA."
- If they publish to a new **GA** version, wait for the next TypeSpec regeneration of `arm_ml_service` to pick it up, then run Step 5 on the affected hits and remove them from the tracker.

---

## 7. Gap-collation document format

Send one row per Amber or Red hit to the ML service team, in a Markdown file we own in this repo (working title: `sdk/ml/azure-ai-ml/docs/preview-to-ga-gaps.md`, to be created during Step 4). Suggested columns:

| Field | Description |
| --- | --- |
| SDK feature area | e.g. "Feature Store", "AutoML NLP jobs", "Monitoring signals" |
| Current preview API version | e.g. `2023-08-01-preview` |
| SDK file where the dependency lives | `azure/ai/ml/entities/…/foo.py:L120` |
| Operation ID | The REST operation identifier, e.g. `Jobs_CreateOrUpdate` |
| Missing field or operation | Exact name, plus one-line description of what it does |
| Current wire example (JSON snippet) | What the SDK sends today under the preview API version |
| Kusto usage | Requests per day for this API version, from the shared query |
| Requested action | "Add field `X` to next GA rev of `Operation_Y`" or similar |

Keep the file in the repo so the vendor team, ML SDK team, and service team all track the same view.

---

## 8. Guardrails

- **One hit per PR.** Never bundle two hits in the same PR — makes revert impossible.
- **No changes to non-preview API version usage.** The 4 non-preview GA overrides in `_ml_client.py:93-96` and the semantic-versioned data-plane clients are out of scope.
- **No customer-visible API changes** unless PM signs off. Migrating a preview override to GA should be invisible to SDK users if the service accepts the same body.
- **Every PR gets a CHANGELOG entry.** No unreleased section may be empty on a PR under this project.
- **Do not regenerate `arm_ml_service` as part of this work.** That's a separate maintenance task with its own risks.

---

## 9. Open questions for reviewers

1. **Wire-verification methodology.** Section 6 Step 5 lists two options (re-recording live tests vs. offline JSON diff). Should the vendor team be told to do **both** for every hit, or only one? Re-recording requires live subscription access — is that available to the vendor team?
2. **State 1 acceptance policy.** If the service team commits to adding a missing field only in a new preview API version (not GA), is that acceptable as an intermediate stable state, or do we hold Category B / override removal until GA lands?
3. **Category B removal timing.** When the service ships a missing field in a new API version, should the SDK's custom-JSON code be removed immediately (once the regen lands), or kept behind an API-version guard until the old preview versions are formally retired by the service?
4. **Gap-collation ownership.** Who owns the gap-collation doc after Step 4 — the ML SDK team, the vendor team, or a joint tracker with the service team? What format does the service team prefer for a batch ask like this?

---

## 10. Investigation items (not blockers)

- **Kusto shows `2024-07-01-preview` at 843,016 requests / day**, but a code search of `azure-ai-ml` does not find any place that sends this API version string. The prior TypeSpec migration converged `2024-07` into `2024-10`. The traffic source needs tracking down — possibilities include an upstream package that hasn't picked up the latest `azure-ai-ml` release, a hand-rolled request path missed in the audit, or a code path we didn't grep.
- **Semantic-versioned data-plane clients** (`dataset_dataplane 1.5.0`, `model_dataplane 1.0.0`, `runhistory v1.0`, `registry_discovery v1.0`). Confirm with William whether these are subject to the same 18-month preview clock, a different lifecycle, or genuinely long-lived. Adjust scope if any of them are effectively preview.

---

## Appendix — preview surfaces inventory

Verified against code on `main` at commit `3f504a1e15` (Aug 24 2026). Kusto requests-per-day column is from William's 7/7/2026 snapshot; refresh before starting execution.

### Category A1 — control-plane overrides on `arm_ml_service`

Location: `azure/ai/ml/_ml_client.py`

| Line | Override name | API version | Kusto req/day |
| ---: | --- | --- | ---: |
| 97 | `ServiceClient022022Preview` | `2022-02-01-preview` | 1,490,498 |
| 98 | `ServiceClient102022Preview` | `2022-10-01-preview` | 13,869 |
| 99 | `ServiceClient022023Preview` | `2023-02-01-preview` | 8,829 |
| 100 | `ServiceClient042023Preview` | `2023-04-01-preview` | 2,366,701 |
| 101 | `ServiceClient062023Preview` | `2023-06-01-preview` | 170,584 |
| 102 | `ServiceClient082023Preview` | `2023-08-01-preview` | 5,936,403 |
| 103 | `ServiceClient012025Preview` | `2025-01-01-preview` | 536,787 |
| 104 | `ServiceClient102024PreviewTsp` | `2024-10-01-preview` | 1,090,085 |
| 108 | `ServiceClient042024PreviewArm` | `2024-04-01-preview` | not in top-visible rows of the snapshot |
| 112 | `ServiceClient012024PreviewArm` | `2024-01-01-preview` | 8,731,670 |

> Note on Kusto scope: the `AwesomeRequests` query covers ML control-plane traffic only (requests to `management.azure.com/.../Microsoft.MachineLearningServices/...`). Data-plane traffic (Category A2 and A3) is served by a different endpoint and would not appear in this table, so its absence there is expected, not evidence of no usage. The vendor team should ask William for the equivalent data-plane query when execution starts.

### Category A2 — data-plane clients whose default is a preview API version

| File | Default API version |
| --- | --- |
| `azure/ai/ml/_restclient/workspace_dataplane/_configuration.py` | `2023-06-01-preview` |
| `azure/ai/ml/_restclient/azure_ai_assets_v2024_04_01/azureaiassetsv20240401/_configuration.py` | `2026-05-01-preview` |

### Category A3 — explicit preview override in an operation file

| File:Line | API version |
| --- | --- |
| `azure/ai/ml/operations/_index_operations.py:120` | `2024-04-01-preview` (on `AzureAiAssetsClient042024`) |

### Category B — hand-built request payloads

Not enumerated here — the list is not proven complete. Vendor team to produce during Step 3 of the playbook and record in the gap-collation document.
