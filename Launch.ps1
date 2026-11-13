param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
if (!$Godot) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if ($installed) { $Godot = $installed.Source }
    else {
        $candidates = Get-ChildItem (Join-Path $env:USERPROFILE 'Downloads') -Filter 'Godot*_win64.exe' -Recurse -File -ErrorAction SilentlyContinue | Where-Object Name -NotMatch 'console'
        if ($candidates) { $Godot = ($candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
    }
}
if (!(Test-Path -LiteralPath $Godot)) { throw 'Godot not found. Pass -Godot with your Godot executable path, or open project.godot in Godot.' }
Start-Process -FilePath $Godot -ArgumentList @('--path', ('"' + $PSScriptRoot + '"')) -WindowStyle Normal
