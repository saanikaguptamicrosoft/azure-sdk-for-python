# Reusable fix recipes for the historical preview TSPs (line-level).

function Remove-Block {
    param([string]$Content, [string]$AnchorPrefix)
    $lines = $Content -split "`n"

    $anchorIdx = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $t = $lines[$i].TrimEnd("`r").TrimStart()
        if ($t.StartsWith($AnchorPrefix + ' ') -or $t.StartsWith($AnchorPrefix + '<') -or $t -eq $AnchorPrefix) {
            $anchorIdx = $i
            break
        }
    }
    if ($anchorIdx -lt 0) { return @{ Content = $Content; Removed = $false } }

    $start = $anchorIdx
    for ($i = $anchorIdx - 1; $i -ge 0; $i--) {
        $t = $lines[$i].TrimEnd("`r").Trim()
        if ($t -eq '' -or $t.StartsWith('#suppress') -or $t.StartsWith('@') -or $t.StartsWith('//') -or $t.StartsWith('/*') -or $t.StartsWith('*') -or $t.EndsWith('*/')) {
            $start = $i
        } else { break }
    }

    $depth = 0
    $inBlock = $false
    $endLine = $anchorIdx
    for ($i = $anchorIdx; $i -lt $lines.Length; $i++) {
        foreach ($ch in $lines[$i].ToCharArray()) {
            if ($ch -eq '{') { $depth++; $inBlock = $true }
            elseif ($ch -eq '}') { $depth-- }
        }
        if ($inBlock -and $depth -eq 0) { $endLine = $i; break }
    }

    $newLines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $start; $i++) { $newLines.Add($lines[$i]) }
    for ($i = $endLine + 1; $i -lt $lines.Length; $i++) { $newLines.Add($lines[$i]) }
    return @{ Content = ($newLines -join "`n"); Removed = $true }
}

function Fix-DataImport {
    param([string]$ModelsPath)
    $c = [System.IO.File]::ReadAllText($ModelsPath)
    $blocks = @(
        'union DataImportSourceType',
        'model DataImport',
        'model DataImportSource',
        'model DatabaseSource',
        'model FileSystemSource',
        'model ImportDataAction'
    )
    $removed = 0
    foreach ($b in $blocks) {
        $r = Remove-Block -Content $c -AnchorPrefix $b
        if ($r.Removed) {
            $c = $r.Content
            $removed++
        }
    }
    [System.IO.File]::WriteAllText($ModelsPath, $c)
    return $removed
}

function Remove-Operation {
    # Remove an `<opName> is ...;` operation declaration (incl. preceding #suppress / @decorators / JSDoc).
    param([string]$FilePath, [string]$OperationName)
    if (-not (Test-Path $FilePath)) { return $false }
    $c = [System.IO.File]::ReadAllText($FilePath)
    $lines = $c -split "`n"

    $anchorIdx = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $t = $lines[$i].TrimEnd("`r").TrimStart()
        if ($t -match "^$([regex]::Escape($OperationName))\s+is\b") {
            $anchorIdx = $i
            break
        }
    }
    if ($anchorIdx -lt 0) { return $false }

    # Walk back to absorb decorators / JSDoc / blank lines
    $start = $anchorIdx
    for ($i = $anchorIdx - 1; $i -ge 0; $i--) {
        $t = $lines[$i].TrimEnd("`r").Trim()
        if ($t -eq '' -or $t.StartsWith('#suppress') -or $t.StartsWith('@') -or $t.StartsWith('//') -or $t.StartsWith('/*') -or $t.StartsWith('*') -or $t.EndsWith('*/')) {
            $start = $i
        } else { break }
    }

    # Walk forward to terminating ';' (track angle-bracket depth so we don't stop on inner ';')
    $depth = 0
    $endLine = $anchorIdx
    $found = $false
    for ($i = $anchorIdx; $i -lt $lines.Length; $i++) {
        foreach ($ch in $lines[$i].ToCharArray()) {
            if ($ch -eq '<' -or $ch -eq '{' -or $ch -eq '(' -or $ch -eq '[') { $depth++ }
            elseif ($ch -eq '>' -or $ch -eq '}' -or $ch -eq ')' -or $ch -eq ']') { $depth-- }
            elseif ($ch -eq ';' -and $depth -eq 0) { $found = $true; break }
        }
        if ($found) { $endLine = $i; break }
    }
    if (-not $found) { return $false }

    $newLines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $start; $i++) { $newLines.Add($lines[$i]) }
    for ($i = $endLine + 1; $i -lt $lines.Length; $i++) { $newLines.Add($lines[$i]) }
    [System.IO.File]::WriteAllText($FilePath, ($newLines -join "`n"))
    return $true
}

function Remove-OperationByMarker {
    # Remove an operation declaration by a unique marker line that appears within the
    # op's leading decorators/JSDoc block (e.g. an @operationId decorator).
    # Walks backward from the marker to absorb prior decorators/JSDoc/blank lines, then
    # walks forward from the marker past the op signature to its terminating ';'.
    param([string]$FilePath, [string]$Marker)
    if (-not (Test-Path $FilePath)) { return $false }
    $c = [System.IO.File]::ReadAllText($FilePath)
    $lines = $c -split "`n"

    $markerIdx = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match [regex]::Escape($Marker)) {
            $markerIdx = $i
            break
        }
    }
    if ($markerIdx -lt 0) { return $false }

    # Walk back to absorb decorators / JSDoc / blank lines
    $start = $markerIdx
    for ($i = $markerIdx - 1; $i -ge 0; $i--) {
        $t = $lines[$i].TrimEnd("`r").Trim()
        if ($t -eq '' -or $t.StartsWith('#suppress') -or $t.StartsWith('@') -or $t.StartsWith('//') -or $t.StartsWith('/*') -or $t.StartsWith('*') -or $t.EndsWith('*/')) {
            $start = $i
        } else { break }
    }

    # Walk forward past op signature to terminating ';' (skip lines that are still decorators)
    $depth = 0
    $endLine = $markerIdx
    $found = $false
    $sawSignature = $false
    for ($i = $markerIdx; $i -lt $lines.Length; $i++) {
        $t = $lines[$i].TrimEnd("`r").Trim()
        if (-not $sawSignature -and ($t.StartsWith('@') -or $t.StartsWith('#suppress') -or $t.StartsWith('//') -or $t.StartsWith('/*') -or $t.StartsWith('*') -or $t.EndsWith('*/') -or $t -eq '')) {
            continue
        }
        $sawSignature = $true
        foreach ($ch in $lines[$i].ToCharArray()) {
            if ($ch -eq '<' -or $ch -eq '{' -or $ch -eq '(' -or $ch -eq '[') { $depth++ }
            elseif ($ch -eq '>' -or $ch -eq '}' -or $ch -eq ')' -or $ch -eq ']') { $depth-- }
            elseif ($ch -eq ';' -and $depth -eq 0) { $found = $true; break }
        }
        if ($found) { $endLine = $i; break }
    }
    if (-not $found) { return $false }

    $newLines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $start; $i++) { $newLines.Add($lines[$i]) }
    for ($i = $endLine + 1; $i -lt $lines.Length; $i++) { $newLines.Add($lines[$i]) }
    [System.IO.File]::WriteAllText($FilePath, ($newLines -join "`n"))
    return $true
}

function Remove-AugmentBlocksReferencing {
    # Remove any `@@xxx(...)` augment-decorator block (possibly multi-line) whose argument
    # text contains a reference matching the supplied regex pattern.
    param([string]$FilePath, [string]$Pattern)
    if (-not (Test-Path $FilePath)) { return 0 }
    $text = [System.IO.File]::ReadAllText($FilePath)
    $rx = [regex]'(?m)^@@\w+\s*\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)\s*;?\s*\r?\n?'
    $count = 0
    $newText = $rx.Replace($text, {
        param($m)
        if ($m.Value -match $Pattern) {
            return ''
        }
        return $m.Value
    })
    $count = ($rx.Matches($text) | Where-Object { $_.Value -match $Pattern }).Count
    [System.IO.File]::WriteAllText($FilePath, $newText)
    return $count
}

function Remove-LinesMatching {
    param([string]$FilePath, [string]$Pattern)
    if (-not (Test-Path $FilePath)) { return 0 }
    $lines = [System.IO.File]::ReadAllText($FilePath) -split "`n"
    $kept = $lines | Where-Object { $_ -notmatch $Pattern }
    [System.IO.File]::WriteAllText($FilePath, ($kept -join "`n"))
    return ($lines.Count - $kept.Count)
}

function Fix-PatchModel {
    param([string]$InferenceEndpointPath)
    if (-not (Test-Path $InferenceEndpointPath)) { return $false }
    $c = [System.IO.File]::ReadAllText($InferenceEndpointPath)
    $orig = $c
    $c = $c.Replace('PatchModel = unknown', 'PatchModel = {}')
    [System.IO.File]::WriteAllText($InferenceEndpointPath, $c)
    return ($c -ne $orig)
}

function Fix-ActionAsync {
    param([string]$VersionFolder)
    $files = 'CodeVersion.tsp','ComponentVersion.tsp','DataVersionBase.tsp','EnvironmentVersion.tsp','ModelVersion.tsp'
    $count = 0
    foreach ($f in $files) {
        $p = Join-Path $VersionFolder $f
        if (-not (Test-Path $p)) { continue }
        $c = [System.IO.File]::ReadAllText($p)
        $orig = $c
        $c = $c.Replace('.ActionAsyncBase<', '.ActionAsync<')
        $c = [regex]::Replace($c, ',\s*BaseParameters\s*=\s*Azure\.ResourceManager\.Foundations\.DefaultBaseParameters<[^>]+>', '')
        if ($c -ne $orig) {
            [System.IO.File]::WriteAllText($p, $c)
            $count++
        }
    }
    return $count
}

function Invoke-TspCompile {
    param([string]$VersionFolder)
    $tsp = 'C:\workspace\azure-rest-api-specs\node_modules\.bin\tsp.cmd'
    $main = Join-Path $VersionFolder 'main.tsp'
    $out = & $tsp compile $main --no-emit 2>&1 | Out-String
    $err = if ($out -match 'Found (\d+) error') { [int]$matches[1] } else { 0 }
    return [PSCustomObject]@{ Errors = $err; Output = $out }
}
