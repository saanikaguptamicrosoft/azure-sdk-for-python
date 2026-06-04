# TypeSpec Migration — Status Tracker

Per-version migration status for `azure-ai-ml`. Versions and scope decisions come from [typespec_migration_per_version_analysis.md](typespec_migration_per_version_analysis.md).

**Status legend**
- `Not started` — no work begun
- `Blocked` — needs service-team input (Fareed) on local-vs-remote swagger delta
- `Ready` — TSP can be generated from upstream; SDK migration not yet started
- `In PR` — PR open, awaiting review / pipeline
- `Merged - test pending` — PR merged; downstream test pass not yet verified
- `Merged` — PR merged and tests green

| # | API version | Status | PR link | Comment |
|---|---|---|---|---|
| 1 | 2020-09-01-dataplanepreview | Not started | — | TSP required |
| 2 | 2021-10-01-dataplanepreview | Not started | — | TSP required |
| 3 | 2022-01-01-preview | Not Started | — | TSP required and delta changes exist |
| 4 | 2022-02-01-preview | Not Started | — | TSP required |
| 5 | 2022-10-01-preview | Not Started | — | TSP required and delta changes exist |
| 6 | 2022-12-01-preview | Not Started | — | Converge into v2022-10-01-preview |
| 7 | 2023-02-01-preview | Not Started | — | TSP required |
| 8 | 2023-04-01-preview | Not Started | — | TSP required |
| 9 | 2023-06-01-preview | Not Started | — | TSP required |
| 10 | 2023-08-01-preview | Not Started | — | TSP required |
| 11 | 2024-01-01-preview | Not Started | — | TSP required |
| 12 | 2024-04-01-preview | Not Started | — | TSP required and delta changes exist |
| 13 | 2024-07-01-preview | Check 14 | https://github.com/Azure/azure-sdk-for-python/pull/47349 | Converged into 2024-10-01-preview |
| 14 | 2024-10-01-preview | In PR, testing pending | https://github.com/Azure/azure-sdk-for-python/pull/47349 | TSP was present |
| 15 | 2025-01-01-preview | Not Started | — | TSP required |
