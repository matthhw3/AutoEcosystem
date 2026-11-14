param([Parameter(Mandatory = $true)][string]$Godot)
$ErrorActionPreference = 'Stop'

# Only explicit project sources are copied. No recursive deletion or external download.
$project = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$bundle = [IO.Path]::GetFullPath((Join-Path $project 'builds\Windows'))
$expected = $project.TrimEnd('\') + '\builds\Windows'
if ($bundle -ne $expected) { throw 'Build output must be workspace/builds/Windows.' }
$engineSource = (Resolve-Path -LiteralPath $Godot).Path
if ($engineSource -match '_console\.exe$') {
    # Godot's small console wrapper requires its sibling engine executable.
    $engineSource = $engineSource -replace '_console\.exe$', '.exe'
}
if (!(Test-Path -LiteralPath $engineSource -PathType Leaf)) { throw 'Godot engine executable is missing.' }
if ([IO.Path]::GetExtension($engineSource) -ne '.exe') { throw 'Provide a Windows Godot executable.' }

foreach ($directory in @('builds', 'builds\Windows', 'builds\Windows\game')) {
    $path = Join-Path $project $directory
    if (Test-Path -LiteralPath $path) {
        if ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Build directory cannot be a symbolic link or junction: $directory"
        }
    } else { New-Item -ItemType Directory -Path $path | Out-Null }
}

$selected = @('project.godot')
foreach ($directory in @('scenes', 'scripts')) {
    $sourceDirectory = Join-Path $project $directory
    $items = Get-ChildItem -LiteralPath $sourceDirectory -Recurse -Force
    foreach ($item in $items) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Project sources cannot contain symbolic links.' }
        if (!$item.PSIsContainer -and $item.Name -match '\.(gd|gd\.uid|tscn|tres)$') {
            $selected += $item.FullName.Substring($project.Length + 1)
        }
    }
}
$manifestPaths = @()
foreach ($relative in ($selected | Sort-Object)) {
    $destination = Join-Path $bundle ('game\' + $relative)
    $parent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $project $relative) -Destination $destination -Force
    $manifestPaths += ('game/' + ($relative -replace '\\', '/'))
}
foreach ($document in @('README.md', 'HOW_IT_WORKS.md', 'ASSET_LICENSES.md', 'ROADMAP.md')) {
    if (Test-Path -LiteralPath (Join-Path $project $document) -PathType Leaf) {
        Copy-Item -LiteralPath (Join-Path $project $document) -Destination (Join-Path $bundle $document) -Force
        $manifestPaths += $document
    }
}
$engine = Join-Path $bundle 'Godot.exe'
Copy-Item -LiteralPath $engineSource -Destination $engine -Force
$manifestPaths += 'Godot.exe'
@'
@echo off
start "North American Ecosystem" /D "%~dp0" "%~dp0Godot.exe" --path "%~dp0game" %*
'@ | Set-Content -LiteralPath (Join-Path $bundle 'Play.cmd') -Encoding Ascii
$manifestPaths += 'Play.cmd'
@'
NORTH AMERICAN ECOSYSTEM - WINDOWS PORTABLE BUILD

Double-click Play.cmd. Keep Godot.exe and the game folder together.
No installation, account, internet connection, or external services are needed.
The simulation starts paused. Use Start or Step to advance it.
Right mouse + WASD flies; Q/E lowers/raises; Shift flies faster.
Select an animal through the roster or click it, then use Follow or Focus.
Pause and normal close save locally. Load always restores a paused simulation.
Save location: %APPDATA%\Godot\app_userdata\North American Ecosystem\ecosystem.save

GODOT_LICENSE.txt and GODOT_THIRD_PARTY.json contain notices for the bundled
Godot engine and its components. They do not grant a license to this project's
original source or assets. No project software license has been selected.
MANIFEST.json records SHA-256 hashes of the selected distribution files.
'@ | Set-Content -LiteralPath (Join-Path $bundle 'START_HERE.txt') -Encoding Ascii
$manifestPaths += 'START_HERE.txt'

# Keep build-validation settings and logs outside the distributable folder.
$validation = Join-Path $project 'tools\local\portable-validation'
New-Item -ItemType Directory -Path $validation -Force | Out-Null
$originalAppData = $env:APPDATA
$originalLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $validation 'appdata'
    $env:LOCALAPPDATA = Join-Path $validation 'localappdata'
    & $engine --headless --path $project --log-file (Join-Path $validation 'notices.log') --script 'res://tools/export_notices.gd' -- ('--output=' + $bundle) | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Engine notice generation failed.' }
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalAppData
}
$manifestPaths += @('GODOT_LICENSE.txt', 'GODOT_THIRD_PARTY.json')
$records = foreach ($relative in ($manifestPaths | Sort-Object)) {
    $file = Get-Item -LiteralPath (Join-Path $bundle $relative)
    [ordered]@{ path = $relative; bytes = $file.Length; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
}
[ordered]@{ format_version = 1; files = @($records) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $bundle 'MANIFEST.json') -Encoding UTF8
Write-Output "Portable build ready: $bundle\Play.cmd"
Write-Output 'Distribution files are listed in MANIFEST.json; no saves, credentials, Git data, or tests were selected.'
