param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:APPDATA = Join-Path $project '.local'
foreach ($test in @('res://tests/test_habitat.gd', 'res://tests/test_simulation.gd', 'res://tests/test_integration.gd', 'res://tests/test_acceptance.gd', 'res://tests/test_release_audit.gd')) {
    $log = Join-Path $project ('test-results/' + [IO.Path]::GetFileNameWithoutExtension($test) + '.log')
    & $Godot --headless --path $project --log-file $log --script $test
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
    if ((Get-Content -LiteralPath $log -Raw) -match 'SCRIPT ERROR:|\bParse Error:') { throw "Godot script error: $test" }
}
