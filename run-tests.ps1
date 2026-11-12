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
    [int] $TimeoutSeconds = 180,
    # How long a run that has already printed a failure may produce nothing further before
    # it is treated as hung. Generous enough that a slow test mid-work is never cut off,
    # short enough that a dead run costs seconds instead of the whole timeout.
    [int] $QuiescenceSeconds = 12
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
    'combat_readout_test',
    'duellist_draw_test',
    'combat_dock_test',
    'mage_drawer_routing_test',
    'combat_dock_density_test',
    'decision_commit_test',
    'decision_commit_input_test',
    'execution_playback_test',
    'stride_commitment_test',
    'stride_input_test',
    'hud_target_stability_test',
    'feedback_target_input_test',
    'commit_shot_test',
    'bow_ownership_checkpoint_test',
    'commit_hud_input_test',
    'commit_shot_input_test',
    'commit_shot_help_input_test',
    'commit_shot_layout_probe',
    'bow_release_input_probe',
    'boar_pounce_test',
    'boar_pounce_input_test',
    'shop_refresh_input_test',
    'phone_world_repair_test',
    'generated_supply_route_test',
    'merchant_overlap_input_test',
    'generated_floor_shot_test',
    'phone_repair_guards_test',
    'floor_boundary_geometry_test',
    'actor_floor_path_test',
    'presentation_copy_parity_test',
    'feedback_root_layout_test',
    'menu_density_layout_test',
    'character_mobile_test',
    'character_spatial_input_test',
    'character_information_test',
    'character_transaction_test',
    'menu_journey_test',
    'survey_pause_input_test',
    'survey_integration_test',
    'expedition_lifecycle_test',
    'expedition_systems_test',
    'expedition_edge_cases_test',
    'expedition_boss_responses_test',
    'run_state_test',
    'combo_continuation_test',
    'post_hit_agency_test',
    'strike_commitment_test',
    'attack_capture_test',
    'wait_granularity_test',
    'sweeping_cut_test',
    'defense_input_test',
    'controller_input_test',
    'capture_telemetry_test',
    'charge_ally_collision_test',
    'knife_identity_test',
	'werewolf_boss_test',
    'energy_test',
    'warrior_character_test',
    'rogue_characters_test',
    'mage_elementalist_test',
	'golden_run_test',
	'structure_audit_test',
    'combat_survey_test',
    'combat_survey_ui_test',
    'isometric_pose_test',
    'weapon_geometry_test',
    'strike_diagnostic_smoke'
)

if ($All) {
    # RefCounted policy helpers are not executable SceneTree test entrypoints.
    $Selected = Get-ChildItem (Join-Path $ProjectRoot 'tests\*.gd') | Where-Object { $_.BaseName -ne 'expedition_action_planner' } | ForEach-Object { $_.BaseName } | Sort-Object
} elseif ($Tests) {
    $Selected = $Tests | ForEach-Object { $_ -replace '\.gd$', '' -replace '^tests[\\/]', '' }
} else {
    $Selected = $HeadlessSuite
}

$Failed = @()
$Missing = @()
$ExpectedSeen = @()
$UnexpectedlyPassing = @()
$ExpectedFailuresPath = Join-Path $ProjectRoot 'tests\expected_failures.json'
$ExpectedFailures = if (Test-Path $ExpectedFailuresPath) { Get-Content $ExpectedFailuresPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }

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
    # Output goes to a file rather than being buffered until the process exits, so a hung
    # run can be watched while it hangs. A file that asserts directly in _init()/_initialize()
    # aborts before its own quit(0) and the process then never exits at all -- the failure is
    # printed within a second and the runner used to sit out the whole timeout to see it.
    $resultFolder = Join-Path $ProjectRoot '.runtime\test-results'
    New-Item -ItemType Directory -Force -Path $resultFolder | Out-Null
    $log = Join-Path $resultFolder "$name.log"
    $process = Start-Process -FilePath $Godot -WorkingDirectory $ProjectRoot -ArgumentList @('--headless', '--path', '.', '--script', "tests/$name.gd", '--log-file', "`"$log`"") -WindowStyle Hidden -PassThru

    # Killing on the first sign of failure would truncate a file that keeps running other
    # tests after one of them fails, and the ledger needs every distinct failure to judge
    # whether they are all documented. So the rule is quiescence: a run that has already
    # failed and has produced nothing further for a while is hung, and there is nothing left
    # to wait for.
    # The routed mobile matrix covers 24 purchases plus cold/root/density/detail cases.
    # Keep an explicit caller timeout authoritative; only its default budget differs.
    $suiteTimeoutSeconds = if ($name -eq 'character_mobile_test' -and -not $PSBoundParameters.ContainsKey('TimeoutSeconds')) { 900 } else { $TimeoutSeconds }
    $deadline = (Get-Date).AddSeconds($suiteTimeoutSeconds)
    $lastSize = -1
    $idleSince = Get-Date
    $hungAfterFailure = $false
    while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 400
        $size = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }
        if ($size -ne $lastSize) {
            $lastSize = $size
            $idleSince = Get-Date
            continue
        }
        if ($size -le 0) { continue }
        if (((Get-Date) - $idleSince).TotalSeconds -lt $QuiescenceSeconds) { continue }
        $sofar = Get-Content -Path $log -Raw -ErrorAction SilentlyContinue
        if ($sofar -match 'Assertion failed|SCRIPT ERROR|FAILED:') {
            $hungAfterFailure = $true
            break
        }
    }

    $timedOut = $false
    if (-not $process.HasExited) {
        # Never terminate another test, editor, or live play session.
        Stop-Process -Id $process.Id -Force
        $timedOut = -not $hungAfterFailure
        $code = -1
    } else {
        $process.WaitForExit()
        $code = $process.ExitCode
    }
    $output = if (Test-Path $log) { (Get-Content -Path $log -Raw -ErrorAction SilentlyContinue) } else { '' }
    if ($null -eq $output) { $output = '' }
    $process.Dispose()

    # Two reporting conventions exist in tests/. Files that assert() surface
    # "Assertion failed"; files that collect into a failures array surface "FAILED:"
    # and exit non-zero. Only the first was ever counted, so every check()-style file
    # reported PASS no matter what it found -- which hid two real failures in
    # capture_telemetry_test, the file carrying most of the milestone coverage.
    # Distinct failures, not raw matches. Godot writes each error to both streams and the
    # two are merged here, so one failed assertion produced four matches -- "SCRIPT ERROR"
    # and "Assertion failed" on the same line, twice over. The ledger compared that inflated
    # number against an authored count, never agreed, and so classified both documented
    # failures as ordinary FAIL: the mechanism built to tell expected from regression was
    # inert from the day it landed.
    #
    # A failure is identified by what it says, deduplicated: the `at:` line naming the test
    # function for an assert()-style file, or the `FAILED:` line for a check()-style one.
    # Not anchored to the start of a line: a job captures stderr as an error record, so
    # Godot's own output arrives prefixed with the executable name. PowerShell's error
    # furniture (`+ CategoryInfo`, `+ FullyQualifiedErrorId`) is dropped first because it
    # echoes an elided copy of the same message and would read as a second, different one.
    $cleanOutput = ($output -split "`r?`n" | Where-Object { $_ -notmatch '^\s*\+ ' }) -join "`n"
    $failureLines = @(
        @([regex]::Matches($cleanOutput, 'FAILED:\s*([^
]+)') | ForEach-Object { 'FAILED: ' + $_.Groups[1].Value.Trim() }) +
        @([regex]::Matches($cleanOutput, 'at:\s*([A-Za-z_0-9]+ \(res://tests/[^)]+\))') | ForEach-Object { 'at: ' + $_.Groups[1].Value.Trim() })
    ) | Sort-Object -Unique
    # Runtime errors in production scripts may return exit zero and have no
    # res://tests location. Keep the exact expected-test ledger, but count every
    # other engine error instead of calling that run clean.
    $engineErrors = @([regex]::Matches($cleanOutput, '(?m)(?:SCRIPT )?ERROR:\s*([^\r\n]+)\r?\n\s*at:\s*([^\r\n]+)') | ForEach-Object {
        if ($_.Groups[2].Value -notmatch 'res://tests/') {
            'ENGINE ERROR: ' + $_.Groups[1].Value.Trim() + ' at: ' + $_.Groups[2].Value.Trim()
        }
    })
    $failureLines = @($failureLines + $engineErrors) | Sort-Object -Unique
    $problems = $failureLines.Count
    $ok = (-not $timedOut) -and ($problems -eq 0) -and ($code -eq 0)
    $expectedProperty = $ExpectedFailures.PSObject.Properties[$name]
    $expected = if ($null -ne $expectedProperty) { $expectedProperty.Value } else { $null }
    # Every distinct failure must be the documented one. No count to keep in step -- a file
    # is allowed to fail for exactly one recorded reason, and a second, different failure
    # breaks the run however many times it prints.
    $unexpectedLines = @()
    if ($null -ne $expected) {
        $unexpectedLines = @($failureLines | Where-Object { $_ -notmatch [regex]::Escape([string]$expected.match) })
    }
    $matchesExpected = (-not $ok) -and (-not $timedOut) -and ($null -ne $expected) -and ($problems -gt 0) -and ($unexpectedLines.Count -eq 0)

    if ($matchesExpected) {
        $ExpectedSeen += $name
        Write-Host ("{0,-34} EXPECTED FAIL  {1}" -f $name, [string]$expected.match) -ForegroundColor Yellow
    } elseif ($ok -and $null -ne $expected) {
        $UnexpectedlyPassing += $name
        Write-Host ("{0,-34} XPASS  review and remove its expected-failure ledger entry" -f $name) -ForegroundColor Yellow
    } elseif ($ok) {
        Write-Host ("{0,-34} PASS" -f $name) -ForegroundColor Green
    } elseif ($hungAfterFailure) {
        $Failed += $name
        Write-Host ("{0,-34} FAIL (hung after failing)  it aborted before its own quit()" -f $name) -ForegroundColor Red
        $failureLines | Select-Object -First 6 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    } elseif ($timedOut) {
        $Failed += $name
        Write-Host ("{0,-34} HANG  no exit within {1}s and nothing failed -- a genuinely slow or stuck run" -f $name, $TimeoutSeconds) -ForegroundColor Red
    } else {
        $Failed += $name
        Write-Host ("{0,-34} FAIL  exit={1} failures={2}" -f $name, $code, $problems) -ForegroundColor Red
        if ($unexpectedLines.Count -gt 0) {
            Write-Host ("    not covered by the expected-failure ledger:") -ForegroundColor Red
            $unexpectedLines | Select-Object -First 6 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        }
        $output -split "`r?`n" |
            Where-Object { $_ -match 'Assertion failed|SCRIPT ERROR|FAILED:|\.gd:\d+' } |
            Select-Object -First 12 |
            ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
}

Write-Host ''
if ($Missing) { Write-Host ("Missing: {0}" -f ($Missing -join ', ')) -ForegroundColor Yellow }
if ($UnexpectedlyPassing) {
    Write-Host ("UNEXPECTED PASS ({0}): {1}" -f $UnexpectedlyPassing.Count, ($UnexpectedlyPassing -join ', ')) -ForegroundColor Red
    exit 1
}
if ($Missing) { exit 1 }
if ($Failed) {
    Write-Host ("FAILED ({0}): {1}" -f $Failed.Count, ($Failed -join ', ')) -ForegroundColor Red
    exit 1
}
Write-Host ("Completed {0} test files: {1} passed; {2} documented expected failures; no new failures." -f $Selected.Count, ($Selected.Count - $ExpectedSeen.Count), $ExpectedSeen.Count) -ForegroundColor Green
exit 0
