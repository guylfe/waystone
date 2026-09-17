$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FallbackTools = Join-Path $env:USERPROFILE 'Documents\Games\waystone\tools'
$ProjectTools = Join-Path $ProjectRoot 'tools'
$GodotCandidates = @(
    (Join-Path $ProjectTools 'godot\Godot_v4.7-stable_win64_console.exe'),
    (Join-Path $ProjectRoot '.tools\Godot_v4.7-stable_win64_console.exe'),
    (Join-Path $FallbackTools 'godot\Godot_v4.7-stable_win64_console.exe')
)
$Godot = $GodotCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Godot) { throw 'Godot 4.7 console executable was not found.' }

$env:APPDATA = Join-Path $ProjectRoot '.runtime\Roaming'
$env:LOCALAPPDATA = Join-Path $ProjectRoot '.runtime\Local'
$TemplateDirectory = Join-Path $env:APPDATA 'Godot\export_templates\4.7.stable'
$DebugTemplate = Join-Path $TemplateDirectory 'windows_debug_x86_64.exe'
$ReleaseTemplate = Join-Path $TemplateDirectory 'windows_release_x86_64.exe'
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA, $TemplateDirectory | Out-Null

if (-not (Test-Path $DebugTemplate) -or -not (Test-Path $ReleaseTemplate)) {
    $ArchiveCandidates = @(
        (Join-Path $ProjectTools 'downloads\Godot_v4.7-stable_export_templates.tpz'),
        (Join-Path $FallbackTools 'downloads\Godot_v4.7-stable_export_templates.tpz')
    )
    $Archive = $ArchiveCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $Archive) { throw 'Godot 4.7 export templates archive was not found.' }
    $Stage = Join-Path $ProjectRoot '.runtime\windows-template-stage'
    New-Item -ItemType Directory -Force -Path $Stage | Out-Null
    & tar -xf $Archive -C $Stage templates/windows_debug_x86_64.exe templates/windows_release_x86_64.exe
    if ($LASTEXITCODE -ne 0) { throw "Windows template extraction failed with exit code $LASTEXITCODE" }
    Copy-Item -LiteralPath (Join-Path $Stage 'templates\windows_debug_x86_64.exe') -Destination $DebugTemplate -Force
    Copy-Item -LiteralPath (Join-Path $Stage 'templates\windows_release_x86_64.exe') -Destination $ReleaseTemplate -Force
}

$Output = Join-Path $ProjectRoot 'builds\windows\Waystone.exe'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Output) | Out-Null
& $Godot --headless --path $ProjectRoot --export-debug 'Windows Desktop' $Output
if ($LASTEXITCODE -ne 0) { throw "Godot Windows export failed with exit code $LASTEXITCODE" }
Get-Item -LiteralPath $Output
