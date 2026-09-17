$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ProjectRoot 'build-windows.ps1')
& (Join-Path $ProjectRoot 'build-android.ps1')
