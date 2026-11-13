param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$env:APPDATA = Join-Path $project '.local'
foreach ($test in @('res://tests/test_simulation.gd', 'res://tests/test_integration.gd')) {
    & $Godot --headless --path $project --log-file (Join-Path $project 'test-results/test.log') --script $test
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
}
