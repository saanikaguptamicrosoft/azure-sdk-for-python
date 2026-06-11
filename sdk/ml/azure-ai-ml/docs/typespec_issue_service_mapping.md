# TypeSpec issue to service mapping

## Delta issues

| Kind | # | API version(s) | Schemas / fields involved | Service area (best guess) | Owner |
|---|---:|---|---|---|---|
| Delta | 1 | 2022-01-01-preview | `Credentials`, `ManagedIdentity`, `PersonalAccessToken`, `ServicePrincipal`, `SharedAccessSignature`, `UsernamePassword` | Workspace Connections / Credentials (models) | TBD |
| Delta | 2 | 2022-10-01-preview | `UserCreatedAcrAccount`, `UserCreatedStorageAccount`, `AcrDetails.userCreatedAcrAccount`, `StorageAccountDetails.userCreatedStorageAccount` | Registry (BYO ACR / Storage) | TBD |
| Delta | 3 | 2022-10-01-preview | `Registry.managedResourceGroupTags` | Registry | TBD |
| Delta | 4 | 2024-04-01-preview | `OpenAIEndpointDeploymentResourceProperties` | Workspace Endpoints / Deployments (MAAP/OpenAI) | TBD |
| Delta | 5 | 2024-04-01-preview | `AccountKeyAuthTypeWorkspaceConnectionProperties.credentials` (`WorkspaceConnectionSharedAccessSignature` vs `WorkspaceConnectionAccountKey`) | Workspace Connections / Credentials | TBD |

## TSP generation issues

| Kind | # | API version(s) | Schemas / routes involved | Service area (best guess) | Owner |
|---|---:|---|---|---|---|
| TSG | 1 | 2021-10-01-dataplanepreview | `AssetReferenceBase.referenceType` collision: `IdAssetReference` vs `ResourceManagementAssetReferenceDetails` | Workspace Assets / Asset Reference models (MFE dataplane) | TBD |
| TSG | 2 | 2023-04-01-preview, 2023-06-01-preview, 2024-04-01-preview | `DataVersionBaseProperties.dataType` collision: `UriFolderDataVersion` vs `DataImport`; companion: `DataImportSource`, `DatabaseSource`, `FileSystemSource`, `ImportDataAction` | Data Import / Data Assets models | TBD |
| TSG | 3 | 2023-08-01-preview, 2024-01-01-preview | `ComputeResource` converter `FIXME` / empty body; orphaned compute family (`ComputeInstance*`, `AssignedUser`, `ComputeInstanceDataMount`, etc.) | Compute | TBD |
| TSG | 4 | 2025-01-01-preview | Duplicate operations on workspace endpoints: `/workspaces/{ws}/features`, `/workspaces/{ws}/endpoints/{endpointName}`, `/workspaces/{ws}/endpoints`, `/workspaces/{ws}/groups/{groupName}/getStatus` | Workspace Features + Endpoints + Inference Groups | TBD |
