# Combat Survey experimental behavior

20 October 2026. 0.3.4 integration candidate; Android 304, save schema 39,
Survey format 37. The accepted internal combat source is
`060cb8e0a47f1c54e542a9860f44ebda683b94de`. The main game is the player-facing
entry. The original isolated package remains preserved. This candidate awaits
independent integration review before the authorized GitHub/local publication.
Human combat feel, physical controls and device play are separate evidence.

## Archive layout correction — 21 October 2026

The independent lifecycle/persistence/provenance review of `962ee4a` passed
231 checks and its exported-binary identity probe. Independent presentation
review reproduced invisible archive rows and portrait detail overflow. The
isolated correction retains 0.3.4 / Android 304 and awaits focused independent
archive recheck before the already-authorized normal-local/GitHub update.

`game_board.gd` now gives the complete archive one outer ScrollContainer:
header, up to twelve stored records, export/copy and close share its content.
Rows wrap their full seed, room count, character and timestamp without ellipsis,
and have a 48-unit minimum height. Archive entry/detail reset to the safe layout;
the detail summary and saved-report summary wrap, including long seeds.
`controller_glyphs.gd` owns shared menu hints: glyph/word pairs stay together
in a horizontal flow that adds rows at narrow widths. Existing labels, glyph
sizes, input callbacks, report storage/export/share/copy and back owners remain.

`tests/survey_archive_layout_test.gd` requires isolated `.runtime` user data.
It creates twelve real completed/archived Survey records with explicit automated
notes, then tests 0/1/6/12-record subsets at 390x844, 720x480, 960x600,
720x1280 and 1280x800, with controller hints shown and hidden. The saved-report
View Archive action is tapped through viewport input. First/final records are
revealed with touch drags and tapped; D-pad navigation and A select visible
focused rows and return from details. It intersects every clipping ancestor,
checks the safe viewport itself, preserves exact record/report bytes, and resizes
an open detail without replacing the selection. `-- --capture` saves real GPU
pixels and structured controls/labels; headless geometry alone is insufficient.
The same test with `--baseline` demonstrates the six-record original failure.

Focused regressions cover Survey setup/ratings/notes/retry, report/archive and
controller menus because hints are shared. The task handoff owns final clean
revision, exact rendered runs/captures and rebuilt Windows/APK identities. The
original candidate and normal checkout remain preserved. Synthetic input and
saved renderer pixels do not establish physical device/controller play or feel.

## Entry and choices

Run `scenes/main.tscn` or the Windows/APK build. Choose **Dev → Survey**.
The Survey selection screen exposes behavior, encounter, preset arrival/approach,
character, Energy/Recovery, Encounter/Attrition, seed and custom-roster composition.
The existing custom/exact-roster composer remains the roster owner. Play selected
Survey starts the attempt. Scroll or use keyboard/controller focus to reach fields.
Fields and new actions are at least 48 logical units; native overlays support touch
taps and captured swipes, keyboard focus and controller navigation.

Existing combat is the initial default. Paused Sword cuts (B) and Paused Sword +
Commit (C) are explicitly experimental. G changes only F2's Archer seat; choosing
G selects F2, and leaving F2 returns the behavior to C. E changes only the accepted
Briarhook approach boundary. G and E remain comparison choices. Non-Sword primary
actions keep their ordinary implementation. Behavior is independent of resource
rules. No Expedition, Campaign, Boss Lab or old saved run silently opts in.

Ordinary encounters preserve the existing generator, seed, custom/exact roster,
entry HP/build and repeat/next policy. Preset arrival and scouting fields apply to
named presets; choosing Ordinary clears them. Named presets replace the custom
roster, use seed42 and retain the accepted factory's exact initial actors/layout.
They are one rated attempt, followed by a report with **Retry same preset** or
return to setup. Low arrival is an explicit 60% HP / 35% Energy diagnostic. Sweep
uses the real level-two upgrade transaction. Scouting shifts 340 west and uses
natural awareness. These conditions are labelled on entry/feedback and in records.

All eleven original fixtures remain: F1 authored tell, F1-D natural approach,
F1-P injected flank recovery; F2 mixed camp; F3 cleave, F3-T thrust, F3-N natural
selection, F3-P injected recovery; F3-K protected tell, F3-KP injected recovery;
F0's native seed42 Expedition first-biome geometry/initial population. F0 retains
the original recorded setup, including sites beyond the first observation. It is
a Survey snapshot without Expedition progression/rewards; End Survey explicitly
after the intended first-site observation. Its distant/offscreen coverage remains
bounded. This is no claim of a full Expedition journey or complete offscreen view.

## Play, readout and handover

The accepted RunState combat executor is shared. Normal Sword pauses before the
next complete simulation tick crossing a link. Tap selects one cut; holding selects
the same tokens. Continue accepts one token. Recover serves the current cut's exit.
Move or Dodge captures one exit request, pays recovery first, then revalidates it.
Actual forced replacement clears that request. Commit arms, then explicitly
confirms a living visible hostile in normal melee range, prepays the accepted
phase costs, locks all cuts/recovery and adds the accepted final-cut payoff.
No refund/chase/automatic rearm is added. Actual interruption rules remain shared.

Buttons and K / LT arm Commit; T / right-stick click cycles eligible targets;
Enter / RT confirms or continues; J / left-stick click recovers. Touch can tap
a target or use the directional Dodge choice. Primary attack/ability/item controls
remain. Start / Esc opens the Survey menu: projection, character, map, End Survey
and save; Resume requires fresh neutral input. Details scrolls without advancing
the world. An open menu pays existing obligations through the normal executor.
The menu never starts an unrated replacement attempt.

The fixed live panel separates optional cuts from paid locked cuts, whole obligation
from current-cut debt, captured direction, refusals/interruption and neutral release.
Up to three priority visible enemy reads show selected target first, then nearest
actors, with phase, resistance and explicit off-view status. Stable keys match
battlefield markers. A line that cannot fit its full name retains the key and
complete phase/resistance; **All N enemies & full details** supplies every visible
actor's full name/facts. The population is never truncated to three in simulation,
recording or details. Undiscovered actors are not revealed by this UI. Large
crowds/offscreen threats still require human motion/readability evaluation.

Survey's existing completion/death/manual-end and ratings handlers own handover.
A last kill waits for all owed player cuts/recovery and any captured exit before
feedback. Manual end first closes the action through the accepted suspension
executor. Death is terminal. Generated/custom repeated rooms use the existing
next-room path, with cleared arming and fresh neutral input. Ratings/tag/notes
submission, skip, archive, view, copy, Downloads export and share remain the normal
Survey workflow. Feedback stacks rating rows at narrow sizes; feedback, reports
and archives scroll within the safe viewport and preserve values across resize.

## Persistence and provenance owners

`scripts/core/survey_experiment.gd` owns selection validation, labels, immutable
session/room metadata and entry manifests. `combat_lab_catalog.gd.configure` is the
single author of named initial states. `run_state.gd` owns Survey lifecycle and
shared combat. `survey_game_board.gd` integrates setup/native overlays, roster
presentation and release gates using `combat_lab_board.gd`'s shared experimental
controls/readout and native `game_board.gd` behavior elsewhere. There is no second
combat resolver or report store. Existing counter descriptors remain authoritative.

Sessions/rooms record experiment ID/version, behavior/scenario, diagnostic/natural
provenance, seed, resource rules, profile/loadout/build, accepted source, immutable
entry manifest/digest, and source/build identity. The manifest includes initial
actor dictionaries, geometry, RNG/tick, resources and generated site records.
Ordinary room manifests identify `survey_encounter` or `survey_attrition` resources;
the disabled preset-arrival selector never claims that an Attrition carryover is full.
`build-all.ps1` writes ignored `build-identity.json` only from a clean committed tree
and embeds the same identity in both exports; external build hashes avoid a circular
self-hash. Development runs without it identify themselves as unmanifested.

StateFieldSchema owns save fields. SaveMigrations 38→39 explicitly assigns no
experiment to old runs. Experimental saves retain action/debt, enemy phases,
projectiles/hazards, parity, RNG, condition fractions and identity counters. Resume
disarms targeting and requires neutral input. Unknown experimental contracts are
refused atomically. Non-Survey/old saves retain their established hydration rules.
SurveyReport format 37 adds provenance without rewriting historical report_text;
new records use the existing current/archive/internal report files and export.

## Reproduction and verification boundary

`tests/survey_integration_test.gd` exercises the main entry/real setup, controller
and touch selection, generated/custom rooms, both resource rules, all preset entry
comparisons, manual end/death/victory, actual submitted ratings/notes, next, archive,
legacy records, export readback, exact action/actor resume, and owed final-kill
consequences. Artificial answers are explicitly marked AUTOMATED INTEGRATION TEST.
Run with isolated APPDATA/LOCALAPPDATA under `.runtime`; it refuses other storage.
`-- --capture` requires a real renderer and records actual pixels at the five
accepted sizes/both combat projections, including labelled crowded diagnostics.

The task handoff carries exact revision, logs, result JSON, inspected images,
Windows/APK metadata/hashes and the safe local publication plan. Source checks,
synthetic input, rendered inspection, exports, device installation and human play
must remain distinct. The pre-existing Bandit expected failure stays in its ledger.
The old internal scene remains available for regression with isolated user data;
its no-op feedback/save is not the delivered Survey route.

The explicit debug-only `-- --survey-smoke` entry runs the exported main scene's
real Survey setup/preset/ratings/archive/save flow, writes `survey-export-smoke.json`
in user data and exits. It refuses user data outside `.runtime`; all notes say
AUTOMATED EXPORTED BUILD SMOKE. Ordinary launches never enter this probe. The UI
custom composer retains its original six-slot limit; eight-actor RunState rooms
and repositioned crowds in automated evidence are explicit stress diagnostics.
F0 always retains its native entrance; the earlier harness's unused F0 Scouting
flag is now explicitly unavailable rather than claiming a shift that never occurred.
