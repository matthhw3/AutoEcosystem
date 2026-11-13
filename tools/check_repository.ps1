param([switch]$Staged)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$gitArgs = @('-c', ('safe.directory=' + ($project -replace '\\','/')), '-C', $project)
$files = & git @gitArgs ls-files
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect tracked files.' }
$problems = @()
foreach ($file in $files) {
    $path = Join-Path $project $file
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $item = Get-Item -LiteralPath $path
    if ($item.Length -gt 10MB) { $problems += "Large asset needs LFS review: $file" }
    if ($file -match '(^|/)(\.env($|\.)|credentials|id_rsa|id_ed25519)|\.(pem|pfx|key)$') { $problems += "Sensitive filename: $file" }
    if ($item.Length -lt 2MB) {
        $content = Get-Content -LiteralPath $path -Raw
        # Concatenated markers prevent this scanner from matching its own patterns.
        $markers = @('gh'+'p_[A-Za-z0-9]{30,}', 'github_'+'pat_[A-Za-z0-9_]{30,}', 'AKIA'+'[A-Z0-9]{16}', '-----BEGIN '+'(RSA |OPENSSH |EC )?PRIVATE KEY-----', 'sk-'+'[A-Za-z0-9]{32,}')
        foreach ($marker in $markers) { if ($content -cmatch $marker) { $problems += "Possible credential: $file" } }
    }
}
$metadata = & git @gitArgs log --format='%an <%ae>%n%cn <%ce>%n%B'
if (($metadata -join "`n") -match '(?im)Co-authored-by:|\[bot\]|^.*<(codex|claude|.*bot)@') { $problems += 'Prohibited attribution in commit metadata.' }
$history = (& git @gitArgs log --all -p --format=) -join "`n"
foreach ($marker in $markers) {
    if ($history -cmatch $marker) { $problems += 'Possible credential in committed history; inspect locally before publishing.' }
}
# Inspect blobs in history too: removing a large or sensitive file from HEAD does not remove it from a push.
$objects = & git @gitArgs rev-list --objects --all
$blobs = $objects | & git @gitArgs cat-file '--batch-check=%(objecttype) %(objectsize) %(rest)'
foreach ($blob in $blobs) {
    if ($blob -match '^blob (\d+) (.+)$') {
        if ([long]$Matches[1] -gt 10MB) { $problems += ('Large historical asset needs LFS review: ' + $Matches[2]) }
        if ($Matches[2] -match '(^|/)(\.env($|\.)|credentials|id_rsa|id_ed25519)|\.(pem|pfx|key)$') { $problems += ('Sensitive historical filename: ' + $Matches[2]) }
    }
}
if ($Staged) { & git @gitArgs diff --cached --check } else { & git @gitArgs diff --check }
if ($LASTEXITCODE -ne 0) { $problems += 'Diff whitespace errors.' }
if ($problems.Count) { $problems | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output ('Repository scan passed: ' + $files.Count + ' tracked files. Manual review for personal information and asset licenses is still required.')
