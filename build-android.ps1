$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$FallbackTools = Join-Path $env:USERPROFILE 'Documents\Games\waystone\tools'
$ProjectTools = Join-Path $ProjectRoot 'tools'
$ToolRoot = if (Test-Path (Join-Path $ProjectTools 'android-sdk')) { $ProjectTools } elseif (Test-Path (Join-Path $FallbackTools 'android-sdk')) { $FallbackTools } else { $ProjectTools }
$GodotCandidates = @(
    (Join-Path $ProjectTools 'godot\Godot_v4.7-stable_win64_console.exe'),
    (Join-Path $ProjectRoot '.tools\Godot_v4.7-stable_win64_console.exe'),
    (Join-Path $FallbackTools 'godot\Godot_v4.7-stable_win64_console.exe')
)
$Godot = $GodotCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Godot) { throw 'Godot 4.7 console executable was not found in tools, .tools, or the local fallback toolchain.' }
$env:APPDATA = Join-Path $ProjectRoot '.runtime\Roaming'
$env:LOCALAPPDATA = Join-Path $ProjectRoot '.runtime\Local'
$env:JAVA_HOME = Join-Path $ToolRoot 'jdk\jdk-17.0.19+10'
$env:ANDROID_HOME = Join-Path $ToolRoot 'android-sdk'
$Output = Join-Path $ProjectRoot 'builds\android\waystone-debug.apk'
$CompatibleDebugKey = Join-Path $ToolRoot 'godot\editor_data\keystores\debug.keystore'
$RuntimeDebugKey = Join-Path $env:APPDATA 'Godot\keystores\debug.keystore'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Output), $env:APPDATA, $env:LOCALAPPDATA, (Split-Path -Parent $RuntimeDebugKey) | Out-Null
if (Test-Path $CompatibleDebugKey) {
    Copy-Item -LiteralPath $CompatibleDebugKey -Destination $RuntimeDebugKey -Force
}
& $Godot --headless --path $ProjectRoot --export-debug 'Android Debug' $Output
if ($LASTEXITCODE -ne 0) { throw "Godot Android export failed with exit code $LASTEXITCODE" }
Get-Item -LiteralPath $Output

