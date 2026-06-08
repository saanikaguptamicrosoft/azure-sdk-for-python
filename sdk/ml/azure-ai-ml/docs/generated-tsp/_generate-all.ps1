$ErrorActionPreference = 'Continue'

$outBase = 'C:\workspace\azure-sdk-for-python\sdk\ml\azure-ai-ml\docs\generated-tsp'
$remote = 'C:\workspace\azure-sdk-for-python\sdk\ml\azure-ai-ml\docs\swagger-remote\resource-manager'
$local = 'C:\workspace\azure-sdk-for-python\sdk\ml\azure-ai-ml\docs\swagger-local\machinelearningservices\resource-manager'
$summary = "$outBase\_summary.txt"
"" | Out-File $summary -Encoding utf8

$versions = @(
    @{ Version = '2022_01_01_preview'; Tag = 'package-2022-01-01-preview'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2022_02_01_preview'; Tag = 'package-2022-02-01-preview'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2022_10_01_preview'; Tag = 'package-preview-2022-10'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2022_12_01_preview'; Tag = 'package-preview-2022-12'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2023_02_01_preview'; Tag = 'package-preview-2023-02'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2023_04_01_preview'; Tag = 'package-preview-2023-04'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2023_06_01_preview'; Tag = 'package-preview-2023-06'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2023_08_01_preview'; Tag = 'package-preview-2023-08'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2024_01_01_preview'; Tag = 'package-preview-2024-01'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2024_04_01_preview'; Tag = 'package-preview-2024-04'; Cwd = $remote; Prefix = 'MachineLearningServices.Management' },
    @{ Version = '2020_09_01_dataplanepreview'; Tag = 'v2020-09-01-dataplanepreview'; Cwd = $local; Prefix = 'MFE.Dataplane' },
    @{ Version = '2021_10_01_dataplanepreview'; Tag = 'v2021-10-01-dataplanepreview'; Cwd = $local; Prefix = 'MFE.Dataplane' }
)

foreach ($v in $versions) {
    $folderName = "$($v.Prefix).v$($v.Version)"
    $out = "$outBase\$folderName"
    Write-Host "==== $($v.Version) ====" -ForegroundColor Cyan

    if (Test-Path $out) { Remove-Item -Recurse -Force $out }

    Push-Location $v.Cwd
    try {
        $convertLog = autorest --openapi-to-typespec --use=@autorest/openapi-to-typespec --isFullCompatible --isArm --output-folder=$out --tag=$($v.Tag) .\readme.md 2>&1 | Out-String
    } finally {
        Pop-Location
    }

    if (-not (Test-Path "$out\main.tsp")) {
        "$($v.Version): CONVERT FAILED" | Tee-Object -FilePath $summary -Append
        $convertLog | Set-Content "$outBase\_convert-error-$($v.Version).log" -Encoding utf8
        continue
    }

    $fileCount = (Get-ChildItem $out -Recurse -File | Measure-Object).Count
    $compileLog = npx tsp compile $out --no-emit 2>&1 | Out-String
    $compileLog | Set-Content "$out\_compile-errors.log" -Encoding utf8

    if ($compileLog -match 'Found (\d+) error') {
        $line = "$($v.Version): $fileCount files, $($matches[1]) compile errors"
    } elseif ($compileLog -match 'no errors') {
        $line = "$($v.Version): $fileCount files, compile OK"
    } else {
        $line = "$($v.Version): $fileCount files, compile status unknown"
    }
    $line | Tee-Object -FilePath $summary -Append
}

Write-Host ""
Write-Host "=========== SUMMARY ===========" -ForegroundColor Green
Get-Content $summary
