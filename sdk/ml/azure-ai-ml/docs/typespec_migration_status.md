# TypeSpec Migration — Status Tracker

| # | API version | Status | PR link | Comment | Test links |
|---|---|---|---|---|---|
| 1 | 2020-09-01-dataplanepreview | To-do | - | ||
| 2 | 2021-10-01-dataplanepreview | To-do | — |  ||
| 3 | 2022-01-01-preview | ✅ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47554 | Re-used existing client by passing API version as an arg, and for missing models passed json directly | https://github.com/Azure/azureml-examples/pull/4045 (refer [main](https://github.com/Azure/azureml-examples/pull/4042)) |
| 4 | 2022-02-01-preview | ✅ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47554 | Re-used existing client by passing API version as an arg, and for missing models passed json directly | https://github.com/Azure/azureml-examples/pull/4045 (refer [main](https://github.com/Azure/azureml-examples/pull/4042))|
| 5 | 2022-10-01-preview | To-do | — |  ||
| 6 | 2022-12-01-preview | To-do | — | Convergence into row 5 (v2022-10) ||
| 7 | 2023-02-01-preview | To-do | - |  | |
| 8 | 2023-04-01-preview | To-do | — |  ||
| 9 | 2023-06-01-preview | To-do | — |  ||
| 10 | 2023-08-01-preview | To-do | — |  ||
| 11 | 2024-01-01-preview | To-do | — | ||
| 12 | 2024-04-01-preview | To-do | — |  ||
| 13 | 2024-07-01-preview | ✅ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47554 | Converged into 2024-10-01-preview | https://github.com/Azure/azureml-examples/pull/4045 (refer [main](https://github.com/Azure/azureml-examples/pull/4042)) |
| 14 | 2024-10-01-preview | ✅ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47554 | Re-used existing client by passing API version as an arg, and for missing models passed json directly | https://github.com/Azure/azureml-examples/pull/4045 (refer [main](https://github.com/Azure/azureml-examples/pull/4042)) |
| 15 | 2025-01-01-preview | ✅ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47554 | Re-used existing client by passing API version as an arg, and for missing models passed json directly | https://github.com/Azure/azureml-examples/pull/4045 (refer [main](https://github.com/Azure/azureml-examples/pull/4042)) |

**Note:**
- Delta and PR validation issues should no longer matter if we can maintain the typespec in another branch referring: [discussion](https://teams.microsoft.com/l/message/19:906c1efbbec54dc8949ac736633e6bdf@thread.skype/1781239436850?tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47&groupId=3e17dcb0-4257-4a30-b843-77f47f1d4121&parentMessageId=1781116135657&teamName=Azure%20SDK&channelName=TypeSpec%20Discussion&createdTime=1781239436850)
  - If above approach is approved, the TSP will be found in new branch `azure-ai-ml/legacy-api-versions/typespec` here: https://github.com/Azure/azure-rest-api-specs/tree/azure-ai-ml/legacy-api-versions/typespec/specification/machinelearningservices/MachineLearningServices.V2025_01_01_Preview.Management
