# TypeSpec Migration — Status Tracker

| # | API version | Status | PR link | Comment | Test links |
|---|---|---|---|---|---|
| 1 | 2020-09-01-dataplanepreview | 🔴 Blocked | https://github.com/Azure/azure-sdk-for-python/pull/47392 | TSP added: https://github.com/Azure/azure-rest-api-specs/pull/43817 but pushed to new branch: azure-ai-ml/legacy-api-versions/typespec | https://github.com/Azure/azureml-examples/pull/4024 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 2 | 2021-10-01-dataplanepreview | 🔴 Blocked | — | **TSP generation issue.** Discriminator Collision. Ticket to service team: https://portal.microsofticm.com/imp/v5/incidents/details/816320580/summary ||
| 3 | 2022-01-01-preview | 🔴 Blocked | — | **Delta issue.**  ||
| 4 | 2022-02-01-preview | 🔴 Blocked | https://github.com/Azure/azure-sdk-for-python/pull/47392 | TSP added: https://github.com/Azure/azure-rest-api-specs/pull/43817 but pushed to new branch: azure-ai-ml/legacy-api-versions/typespec |https://github.com/Azure/azureml-examples/pull/4024 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 5 | 2022-10-01-preview | 🔴 Blocked | — | **Delta issue.** ||
| 6 | 2022-12-01-preview | 🔴 Blocked | — | Convergence into row 5 (v2022-10) — blocked on row 5 ||
| 7 | 2023-02-01-preview | 🔴 Blocked | https://github.com/Azure/azure-sdk-for-python/pull/47392 | TSP added: https://github.com/Azure/azure-rest-api-specs/pull/43817 but pushed to new branch: azure-ai-ml/legacy-api-versions/typespec | https://github.com/Azure/azureml-examples/pull/4024 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 8 | 2023-04-01-preview | 🔴 Blocked | — | **TSP generation issue.** Discriminator Collision. Ticket to service team: https://portal.microsofticm.com/imp/v5/incidents/details/816320580/summary ||
| 9 | 2023-06-01-preview | 🔴 Blocked | — | **TSP generation issue.** Discriminator Collision. Ticket to service team: https://portal.microsofticm.com/imp/v5/incidents/details/816320580/summary ||
| 10 | 2023-08-01-preview | 🔴 Blocked | — | **TSP generation issue.** Converter emits // FIXME: ComputeResource has no properties property + empty <{}> body on ComputeResource.tsp - ticket to service team: https://portal.microsofticm.com/imp/v5/incidents/details/816303994/summary ||
| 11 | 2024-01-01-preview | 🔴 Blocked | — | **TSP generation issue.** Converter emits // FIXME: ComputeResource has no properties property + empty <{}> body on ComputeResource.tsp - ticket to service team: https://portal.microsofticm.com/imp/v5/incidents/details/816303994/summary||
| 12 | 2024-04-01-preview | 🔴 Blocked | — | **Delta issue + TSP generation issue.** Discriminator Collision. ||
| 13 | 2024-07-01-preview | ⬜ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47349 | Converged into 2024-10-01-preview |https://github.com/Azure/azureml-examples/pull/3997 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 14 | 2024-10-01-preview | ⬜ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47349 | TSP was present in main | https://github.com/Azure/azureml-examples/pull/3997 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 15 | 2025-01-01-preview | 🔴 Blocked | — | Found a way around TSP generation issues. TSP generated. ||

**Note:**
- Delta and PR validation issues should no longer matter if we can maintain the typespec in another branch referring: [discussion](https://teams.microsoft.com/l/message/19:906c1efbbec54dc8949ac736633e6bdf@thread.skype/1781239436850?tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47&groupId=3e17dcb0-4257-4a30-b843-77f47f1d4121&parentMessageId=1781116135657&teamName=Azure%20SDK&channelName=TypeSpec%20Discussion&createdTime=1781239436850)
  - If above approach is approved, the TSP will be found in new branch `azure-ai-ml/legacy-api-versions/typespec` here: https://github.com/Azure/azure-rest-api-specs/tree/azure-ai-ml/legacy-api-versions/typespec/specification/machinelearningservices/MachineLearningServices.V2025_01_01_Preview.Management
