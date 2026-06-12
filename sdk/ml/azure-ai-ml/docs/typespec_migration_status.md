# TypeSpec Migration — Status Tracker

| # | API version | Status | PR link | Comment | Test links |
|---|---|---|---|---|---|
| 1 | 2020-09-01-dataplanepreview | ⚪ In PR | https://github.com/Azure/azure-sdk-for-python/pull/47392 | TSP added: https://github.com/Azure/azure-rest-api-specs/pull/43817 but pushed to new branch: azure-ai-ml/legacy-api-versions/typespec | https://github.com/Azure/azureml-examples/pull/4024 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 2 | 2021-10-01-dataplanepreview | 🔴 Blocked | — | **TSP generation issue.** Discriminator Collision. ||
| 3 | 2022-01-01-preview | 🔴 Blocked | — | **Delta issue.**  ||
| 4 | 2022-02-01-preview | ⚪ In PR | https://github.com/Azure/azure-sdk-for-python/pull/47392 | TSP added: https://github.com/Azure/azure-rest-api-specs/pull/43817 but pushed to new branch: azure-ai-ml/legacy-api-versions/typespec |https://github.com/Azure/azureml-examples/pull/4024 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 5 | 2022-10-01-preview | 🔴 Blocked | — | **Delta issue.** ||
| 6 | 2022-12-01-preview | 🔴 Blocked | — | Convergence into row 5 (v2022-10) — blocked on row 5 ||
| 7 | 2023-02-01-preview | ⚪ In PR | https://github.com/Azure/azure-sdk-for-python/pull/47392 | TSP added: https://github.com/Azure/azure-rest-api-specs/pull/43817 but pushed to new branch: azure-ai-ml/legacy-api-versions/typespec | https://github.com/Azure/azureml-examples/pull/4024 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 8 | 2023-04-01-preview | 🔴 Blocked | — | **TSP generation issue.** Discriminator Collision. ||
| 9 | 2023-06-01-preview | 🔴 Blocked | — | **TSP generation issue.** Discriminator Collision. ||
| 10 | 2023-08-01-preview | 🔴 Blocked | — | **TSP generation issue.** Converter emits // FIXME: ComputeResource has no properties property + empty <{}> body on ComputeResource.tsp ||
| 11 | 2024-01-01-preview | 🔴 Blocked | — | **TSP generation issue.** Converter emits // FIXME: ComputeResource has no properties property + empty <{}> body on ComputeResource.tsp ||
| 12 | 2024-04-01-preview | 🔴 Blocked | — | **Delta issue + TSP generation issue.** Discriminator Collision. ||
| 13 | 2024-07-01-preview | ⬜ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47349 | Converged into 2024-10-01-preview |https://github.com/Azure/azureml-examples/pull/3997 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 14 | 2024-10-01-preview | ⬜ Merged | https://github.com/Azure/azure-sdk-for-python/pull/47349 | TSP was present | https://github.com/Azure/azureml-examples/pull/3997 (refer [main](https://github.com/Azure/azureml-examples/pull/3995))|
| 15 | 2025-01-01-preview | 🔴 Blocked | — | Found a way around TSP generation issues ||
