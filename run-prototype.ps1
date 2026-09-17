$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FallbackTools = Join-Path $env:USERPROFILE 'Documents\Games\waystone\tools'
$GodotCandidates = @(
    (Join-Path $ProjectRoot 'tools\godot\Godot_v4.7-stable_win64.exe'),
    (Join-Path $ProjectRoot '.tools\Godot_v4.7-stable_win64.exe'),
    (Join-Path $FallbackTools 'godot\Godot_v4.7-stable_win64.exe')
)
$Godot = $GodotCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Godot) { throw 'Godot 4.7 was not found in tools, .tools, or the local fallback toolchain.' }
$env:APPDATA = Join-Path $ProjectRoot '.runtime\Roaming'
$env:LOCALAPPDATA = Join-Path $ProjectRoot '.runtime\Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
& $Godot --path $ProjectRoot

