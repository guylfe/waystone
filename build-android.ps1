$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Godot = Join-Path $ProjectRoot 'tools\godot\Godot_v4.7-stable_win64_console.exe'
$env:APPDATA = Join-Path $ProjectRoot '.runtime\Roaming'
$env:LOCALAPPDATA = Join-Path $ProjectRoot '.runtime\Local'
$env:JAVA_HOME = Join-Path $ProjectRoot 'tools\jdk\jdk-17.0.19+10'
$env:ANDROID_HOME = Join-Path $ProjectRoot 'tools\android-sdk'
$Output = Join-Path $ProjectRoot 'builds\android\waystone-debug.apk'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Output), $env:APPDATA, $env:LOCALAPPDATA | Out-Null
& $Godot --headless --path $ProjectRoot --export-debug 'Android Debug' $Output
if ($LASTEXITCODE -ne 0) { throw "Godot Android export failed with exit code $LASTEXITCODE" }
Get-Item -LiteralPath $Output

