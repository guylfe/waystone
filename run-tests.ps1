<#
.SYNOPSIS
    Runs Waystone's headless test suite and fails the run when any test fails.

.DESCRIPTION
    Test files `assert()` inside functions called from `_init()`, then `print(...)`
    and `quit(0)` unconditionally. A failed assertion prints SCRIPT ERROR, aborts
    only the function it is in, and still exits 0 -- so a green exit code is not
    evidence that the suite passed. This script scans each run's output for
    assertion failures and script errors, and exits 1 if any file reports one.

    Render-dependent smoke tests are excluded by default: they capture real frames
    and cannot pass under --headless. Run those against a real renderer, per
    WAYSTONE_MIGRATION_HANDOFF.md section 7.6.

.PARAMETER Tests
    Test names to run, with or without the .gd suffix. Defaults to the headless
    suite below.

.PARAMETER All
    Run every tests/*.gd file, including slow performance suites and the
    render-dependent smokes that are expected to fail headless.

.EXAMPLE
    .\run-tests.ps1
    .\run-tests.ps1 combo_continuation_test run_state_test
    .\run-tests.ps1 -All
#>
param(
    # Position 0 is claimed explicitly. Without it the int parameter below becomes
    # the first positional one and a test name binds to it as a timeout.
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $Tests,
    [switch] $All,
    [int] $TimeoutSeconds = 180
)

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

# Verified to run clean under --headless. Keep this list in sync when adding tests.
$HeadlessSuite = @(
    'run_state_test',
    'combo_continuation_test',
    'post_hit_agency_test',
    'strike_commitment_test',
    'attack_capture_test',
    'wait_granularity_test',
    'sweeping_cut_test',
    'defense_input_test',
    'capture_telemetry_test',
    'energy_test',
    'warrior_character_test',
    'rogue_characters_test',
    'combat_survey_test',
    'combat_survey_ui_test',
    'weapon_geometry_test',
    'strike_diagnostic_smoke'
)

if ($All) {
    $Selected = Get-ChildItem (Join-Path $ProjectRoot 'tests\*.gd') | ForEach-Object { $_.BaseName } | Sort-Object
} elseif ($Tests) {
    $Selected = $Tests | ForEach-Object { $_ -replace '\.gd$', '' -replace '^tests[\\/]', '' }
} else {
    $Selected = $HeadlessSuite
}

$Failed = @()
$Missing = @()

foreach ($name in $Selected) {
    $path = Join-Path $ProjectRoot "tests\$name.gd"
    if (-not (Test-Path $path)) {
        $Missing += $name
        Write-Host ("{0,-34} MISSING" -f $name) -ForegroundColor Yellow
        continue
    }

    # Run under a timeout. Test files that assert directly inside _init() abort
    # before reaching their own quit(0) when an assertion fails, so the process
    # never exits -- a failure presents as an indefinite hang rather than a
    # failure. Without this the runner would block forever on a red test.
    $job = Start-Job -ScriptBlock {
        param($godot, $root, $file)
        $text = & $godot --headless --path $root --script $file 2>&1 | Out-String
        [pscustomobject]@{ Output = $text; Code = $LASTEXITCODE }
    } -ArgumentList $Godot, $ProjectRoot, "tests/$name.gd"

    if (Wait-Job $job -Timeout $TimeoutSeconds) {
        $result = Receive-Job $job
        $output = ($result | ForEach-Object { $_.Output }) -join "`n"
        $code = ($result | ForEach-Object { $_.Code } | Select-Object -Last 1)
        if ($null -eq $code) { $code = 0 }
        $timedOut = $false
    } else {
        Stop-Job $job
        $output = ''
        $code = -1
        $timedOut = $true
        Get-Process Godot_v4.7-stable_win64 -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    Remove-Job $job -Force

    # Two reporting conventions exist in tests/. Files that assert() surface
    # "Assertion failed"; files that collect into a failures array surface "FAILED:"
    # and exit non-zero. Only the first was ever counted, so every check()-style file
    # reported PASS no matter what it found -- which hid two real failures in
    # capture_telemetry_test, the file carrying most of the milestone coverage.
    $problems = ([regex]::Matches($output, 'Assertion failed|SCRIPT ERROR|FAILED:')).Count
    $ok = (-not $timedOut) -and ($problems -eq 0) -and ($code -eq 0)

    if ($ok) {
        Write-Host ("{0,-34} PASS" -f $name) -ForegroundColor Green
    } elseif ($timedOut) {
        $Failed += $name
        Write-Host ("{0,-34} HANG  no exit within {1}s -- likely a failed assert inside _init()" -f $name, $TimeoutSeconds) -ForegroundColor Red
    } else {
        $Failed += $name
        Write-Host ("{0,-34} FAIL  exit={1} problems={2}" -f $name, $code, $problems) -ForegroundColor Red
        $output -split "`r?`n" |
            Where-Object { $_ -match 'Assertion failed|SCRIPT ERROR|FAILED:|\.gd:\d+' } |
            Select-Object -First 12 |
            ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
}

Write-Host ''
if ($Missing) { Write-Host ("Missing: {0}" -f ($Missing -join ', ')) -ForegroundColor Yellow }
if ($Failed) {
    Write-Host ("FAILED ({0}): {1}" -f $Failed.Count, ($Failed -join ', ')) -ForegroundColor Red
    exit 1
}
Write-Host ("All {0} test files passed." -f $Selected.Count) -ForegroundColor Green
exit 0
