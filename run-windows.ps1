$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Executable = Join-Path $ProjectRoot 'builds\windows\Waystone.exe'
if (-not (Test-Path $Executable)) { & (Join-Path $ProjectRoot 'build-windows.ps1') }
Start-Process -FilePath $Executable -WorkingDirectory (Split-Path -Parent $Executable)
