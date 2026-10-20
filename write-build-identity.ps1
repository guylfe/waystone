$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$revision = (& git -C $ProjectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify build source.' }
$dirty = @(& git -C $ProjectRoot status --porcelain)
if ($dirty.Count -ne 0) { throw 'Commit the review candidate before stamping platform builds.' }
$exports = Get-Content -LiteralPath (Join-Path $ProjectRoot 'export_presets.cfg') -Raw
$version = [regex]::Match($exports,'version/name="([^"]+)"').Groups[1].Value
$androidCode = [int][regex]::Match($exports,'version/code=(\d+)').Groups[1].Value
$identity = [ordered]@{
    source = $revision
    tree = (& git -C $ProjectRoot rev-parse 'HEAD^{tree}').Trim()
    version = $version
    android_version_code = $androidCode
    build = ('survey-' + $version + '-' + $revision.Substring(0,12))
    accepted_experiment_source = '060cb8e0a47f1c54e542a9860f44ebda683b94de'
}
[IO.File]::WriteAllText((Join-Path $ProjectRoot 'build-identity.json'), ($identity | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
$identity
