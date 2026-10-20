# Local combat coherence lab

20 October 2026. Experimental local branch from `0fb5694fda7f6018b03f4aeed2a3c8533759ec52`. This unnumbered experiment implements Dr. Stone's resolved combat contract. Production remains 0.3.3. Guy's acceptance of feel remains open.

The entry scene is `scenes/combat_coherence_lab.tscn`. `scripts/experiments/combat_lab_catalog.gd` owns variant IDs, payoff, exact seed42 fixtures, profile setup, manifest and supplemental authoritative digest. Normal Sword phases remain authored once in RunState. GameBoard, actor constructors, contact, navigation, incoming hits and Expedition executors remain shared.

| Variant | Local rules |
|---|---|
| A | Existing combat/input rules in the fixed harness |
| B | Frozen normal Sword junctions |
| C | B plus prepaid, one-use Commit |
| G | C, moving only F2 Archer to (1810,1060) |
| E | C, truncating only Briarhook ordinary approach at existing engage distance with LOS |

Normal Sword freezes before the complete 120 Hz tick that would cross the next link. Continue accepts one token; release clears automatic continuation without revoking that token. Holding chooses the same tokens. Recover locks the current exit. Move/Dodge at the junction captures one request and pays recovery first, then revalidates it. A forced replacement discards the request. Readiness stays false throughout the junction and recovery. One combo identity and spent action poise persist across cuts.

Commit is armed while ready, then confirmed on a living visible hostile target in normal melee range. Invalid targeting and insufficient resources preserve world state and arm. Successful targeting prepays actual modified phase costs (base 36 Energy), grants no overdraft and marks subsequent phases paid. Only final-cut base damage gains 10 before normal modifiers/Defense. Full irrevocable remaining time includes all paid cuts and recovery; flinch, posture-break floors and Shield/Polearm reads use the separate current-cut horizon. Existing heavy/protected exceptions and the older ordinary `melee` active-contact exception remain.

Commit survives release and voluntary defensive requests; real hits, posture breaks, sleep, parry and death retain their existing replacement authority. No refund, rearm, chase or automatic resume is added. Neutral input is required afterward. Explicit focus/menu suspension closes normal actions at a legal boundary and serves recovery, or finishes Commit through the normal executor and its consequences. Fresh/retry lab sessions do not load or save normal runs or archive Survey results. The launcher isolates APPDATA/LOCALAPPDATA per variant; this project additionally uses the distinct `WaystoneCombatLab` user directory. Each playable retry writes only an experiment entry manifest there.

Controls: Commit K/LT or button; T/RS click selects an eligible visible enemy in normal launch range with LOS; Enter/RT confirms armed targeting or continues a junction. Tapping an enemy continues using existing facing. Continue works without a surviving original target. J/LS click recovers at a junction. Existing movement and Dodge inputs pay recovery before acting. The touch Defense button selects a direction for the queued Dodge. LB retains its shortcuts. Compare/Retry and Escape suspend; Resume requires neutral input. The native GameBoard handles ordinary Knife, Bow, Staff, spell and ability paths.

Fixtures include F1 tell, F1-D natural approach, separately labelled F1-P flank diagnosis; F2 exact camp seats/cover; F3 cleave, F3-T thrust, F3-N natural selection, F3-P recovery; F3-K/KP protection/recovery; and F0 native generated seed42 Expedition entry. F0 preserves the real first-site record and starts at the ordinary entrance, with no diagnostic teleport. Full and declared 60% HP/35% Energy profiles are selectable. The sweep profile earns Swordsmanship rank one through the level-two upgrade transaction. Scouting copies shift the player 340 west and retain natural perception. Distant F0 actors have unassessed loaded-geometry occupancy until their regions load.

Verification entrypoints:

```powershell
.\run-tests.ps1
.\run-tests.ps1 combat_lab_contract_test combat_lab_input_test -TimeoutSeconds 600
.\run-tests.ps1 combat_lab_policy_trace -TimeoutSeconds 600
.\run-tests.ps1 combat_lab_replay_test -TimeoutSeconds 600
```

The lab digest includes full action and enemy state, tick parity, RNG, resources, conditions and world objects; historical control goldens are unchanged. Tests compare semantic input choices separately from live hold/token flags. The runner now rejects runtime errors in production scripts even when Godot exits zero. A deliberately failing, subsequently removed probe established this detection; its source and logs remain in `.runtime` evidence.

Measured results and exact artifact hashes belong in the accompanying handoff and `.runtime` evidence, not in production balance claims. Headless direct input dispatch at desktop and narrow viewports is synthetic engine evidence. No real renderer, physical touch/controller, Windows export, device install or human play acceptance is implied.


## Review corrections (20 October 2026)

This independent local candidate starts from preserved implementation commit
`6359abba3331a4989c0e29cb951df1b790b2f993`. C remains default; G/E remain
comparisons, with no tuning, production version, save-schema change or adoption.

Normal Sword pips distinguish completed/current/optional cuts even while held;
only actual prepaid future cuts get a gold square. Startup displays cut one
before the executor's initial phase-index update. Experiment-off pip and phase
presentation is preserved. The shared world-header drawing hook preserves its
normal implementation; the lab overrides it to reserve gauges outside telegraphs.

The fixed action panel derives Ready, Armed, running Normal/Commit, frozen
junction, Recovering -> Move/Dodge, Interrupted and Neutral-required from current
authoritative state. Whole obligation and current-cut control debt remain separate.
Rejected starts show actual resource/range reasons. Recovery queues show a captured
screen-projected bearing and refuse replacement. Interruption event text survives
the final consequence until a meaningful new choice. Details expose experiment
IDs, current-cut debt, facing, finite poise and inspected enemy traits.

K/T/Enter/J and LT/RS click/RT/LS click remain. Target cycling now uses the same
pure eligibility helper as armed launch: living, hostile, current layer, visible,
LOS and normal attack range. Confirmation remains fresh and explicit. The blue
arrow is actual sequence facing; the gold dashed arrow is armed target bearing or
the panel-labelled after-recovery direction. The ordinary contact resolver and
current enemy resistance badges share the existing predicates; no resistance,
flinch, damage or posture policy is changed. Legacy active-contact melee, heavy
bodies, protected phases and non-refreshing ordinary reactions remain.

New primary buttons, Dodge and landscape belt slots are at least 48 logical
units, with fixed positions across action states. The lab reserves its panel and
gauges; its old duplicate Attack circle and world header are suppressed. Projection
scales to the remaining board rectangle without changing world/contact geometry.
Resize cancels stale gestures without starting an action. Compare/Retry includes
projection selection; V/M/C preserve projection/map/character keyboard access.

`tests/combat_lab_review_test.gd` checks changed presentation/input semantics and
layout at 1280x800, 960x600, 720x480, 720x1280 and 390x844 in both projections.
With `-- --capture`, it requires a real renderer and saves scripted state captures
under `.runtime/review-captures`. Incoming-hit captures use actual resolution;
fixtures with a P suffix remain injected recovery diagnoses. Captures and synthetic
input do not establish physical hardware behavior or human acceptance. The handoff
records exact checks, inspected frames and the background-launch route.

## Historical presentation repair: 118060a (20 October 2026)

An isolated revision based on reviewed `f31046b2910b6af485be5cdeb90a4b0635cabf72`
attempted D1–D3. Independent re-check retained the geometry/D3 result but found
raw touch swipes inert and crowded F2 markers unreadable. The following paragraph
records that superseded implementation. Details and Compare shared an 82-unit scrollable information
slot above the fixed action controls. The title remains visible; opening either
temporarily replaces instruction/feedback in that slot. Full inspected traits,
diagnostics and all selectors remain reachable by scrolling. Closing restores
guidance. Header height is recomputed from compact authored slots, and native
orientation always uses the full safe display. Portrait abilities stay in their
bottom row. Simulation/world geometry is unchanged.

The lab suppresses redundant actor phase captions through a presentation hook;
normal-game caption placement is preserved. Enemy phase and resistance facts
occupy a separate two-line strip above the world, using the existing phase and
resistance predicates. Full names and stable fixture-local numbers match keys inside
actor silhouettes, leaving facing arrows, pips and contact tells free of long
captions. The strip reserves up to three fixture roster rows independent of
action/visibility changes. This costs 38 logical units per row of world-view
height; it is a bounded F1–F3 experiment presentation, not an offscreen-threat
or full F0 camera solution. Human motion readability of the hierarchy remains open.

Resume retains its fresh-neutral requirement. Only obsolete suspension/neutral
gate messages are retired on neutral; interruption and refusal messages persist.
No combat timing, costs, damage, armor, target eligibility, captured exit bearing,
optional/Commit pip rules or variant selection changes are included. C remains
default; G/E remain independent comparisons.

`combat_lab_presentation_test.gd` runs repeated details/Compare/Resume, actual
synthetic key hold/release, scroll reachability, viewport containment, 48-unit
controls, full enemy text widths and portrait/landscape rotation at the five
review sizes in both projections. `-- --capture` requires real rendering and
saves pixels in `.runtime/presentation-captures`, with separate headless/render
JSON reports. The identical harness fails on the preserved reviewed candidate.
The accompanying repair handoff owns exact logs, before/after captures, hashes,
inspection records and focused input/replay results. No physical input, native
window delivery, export/install or Guy acceptance is established.

## Touch and battlefield repair from 118060a (20 October 2026)

Status: historical `495ddd` candidate. Independent review passed its inspection,
world/marker and D3 boundaries, but rejected combined information overflow. The
next section owns the repaired live summary. This section supersedes the earlier
inspection/roster/key layout. All combat timing, costs,
damage, conditions, collision, AI, paid pips, optional pips and captured queue
direction retain their existing owners. C remains default; G/E are independent.

The fixed upper information slot is 110 units high. Its authored 36/18-unit
label minima underestimated the actual font heights (47/43 for wrapped text;
20 per enemy row), causing the independently reproduced D2 failure. Each enemy
line includes the stable key, full name, current phase and concise
resistance wording from the same shared predicates. Full traits, current phase,
resistance, diagnostics, controls and last event remain in Review details.
Repeated tutorial text and the native travelling-area splash are removed from
the battlefield. There is no separate 114-unit enemy strip. No projection or
world/contact geometry policy is changed; the existing projection uses the
recovered area. Relevant visible F1–F3 enemies remain listed regardless of target.
Off-view status is explicit; full F0/offscreen-threat completeness is unclaimed.

| C/F2 default viewport | Previous world height | Repaired world height | Lead floor |
|---|---:|---:|---:|
| 720x480, both projections | 106 | 200 | 200 |
| 390x844, both projections | about 164.47 | about 254.47 | 250 |

Details and Compare exclusively replace that information slot. Their 64x48
Previous/Next buttons are visible only during inspection. Content supports wheel,
mouse drag and raw ScreenTouch/ScreenDrag scrolling with global mouse-from-touch
emulation still disabled. Pointer identity is captured until release/cancel,
including after close, resize and leaving the panel. A local GUI tap translation
activates the same controls once; a swipe cannot activate a field or underlying
combat button. Closing cancels adapter gestures and retains an input release gate
for held inspection keys/buttons/axes. Normal controls retain their bindings.

Controller Start opens Compare at a GUI focus target; D-pad traverses the visible
inspection fields, pages and utility controls. A advances a labelled cycling
field or uses a button; B closes. Review details is reachable through that focus
loop. All six selectors, Scouting and Start fresh have whole 48-unit targets;
cycling avoids small native-popup choices. Selection is staged until explicit
Start fresh, apart from the projection preview. Inspection navigation does not
advance the authoritative world or spend resources. Compare preserves the existing
legal suspension/drain contract; opening it during a commitment can finish that
obligation before navigation begins. Resume retains the existing neutral gate and
retires only obsolete gate messages, preserving refusal/interruption feedback.

Numeric actor keys are captured at fixture creation and survive earlier-actor
removal and visibility changes. Placement considers the whole visible cluster,
body/facing bounds and current action reach. Outlined 16px numbers have no opaque
backing; separated positions lead to the sampled native pose/reaction body edge.
This is a bounded F1–F3 hierarchy, not an all-roster label-layout guarantee. The
raw initial and Wait1/2/3 C/F2 frames use ordinary requests without injected
positions/actions; their full authoritative states match 118060a exactly at
0.0, 0.5, 1.5 and 2.0 simulation seconds.

`combat_lab_touch_battlefield_test.gd` dispatches raw GUI touch, drag and joypad
events, records before/after authoritative digests, exercises each Compare field
and explicit reset, controller paging to the final details line, multi-pointer
close/resize/cancel, held trigger release, all five sizes in both projections,
natural contact and queued Dodge presentation. The unchanged independent reviewer
probes are included with provenance in the delivery handoff. The original
presentation/input/contract checks and selected exact policy replays remain
separate evidence. Captured pixels, logs, traces, inspected-frame list, patch and
hash inventory accompany the candidate. Automated and rendered engineering checks
do not establish independent acceptance, physical touch/controller behavior,
native-window delivery, motion/latency, export/install or Guy's play judgment.

## Combined live information repair from 495ddd (20 October 2026)

The existing 110-unit slot and fixed action coordinates remain. Labels now use
their actual shaped font minimums without authored 36/18-unit height reservations.
At the installed font metrics a 15px instruction line is 22 units, a 14px event
line is 20, and three 14px enemy rows total 60: 102 units together. The retained
20px title fits its existing 30-unit slot. Empty event/enemy labels reserve no
blank row. Fonts, targets, projection/camera policy and combat owners are unchanged.

The immediate summary is derived from the same authoritative action. Normal
shows phase, current cut plus exit debt and optional future cuts; Commit shows
phase, whole remaining obligation and locked cuts. Armed Commit shows exact cost,
three cuts, no refund and interruptibility. A selected actor's stable key stays
in the title even when refusal replaces target-selection guidance. Junctions show
owed debt and captured sequence facing. Queued Move/Dodge shows remaining debt,
inactive status, projected captured exit direction and the locked queue. Both
interruption and neutral-required states retain their event consequences.

Only redundant event wording is omitted from the live view: initial configuration
already available in Details, armed targeting invitation, running Commit's repeated
lock statement, and the current recovery queue's repeated name. A meaningful
refusal replaces the invitation. Other relevant event text remains in its own
complete line, with concise equivalent wording for known long reasons. No semantic
notice is cleared by presentation. Details keeps the current original event and
full wording of distinct events observed by the panel since Start fresh. This
history is session-local UI data, reset with the fixture; it changes no save schema.

`combat_lab_information_test.gd` runs unchanged on the preserved control and repair.
It checks actual Label line heights/counts, visible lines, no trim/skip/clip, full
single-line glyph width, allocation containment, all sibling/action boundaries,
three complete enemy rows, original type sizes, 48-unit controls and world floors
after deferred layout settles and after content changes. It covers 292 panels at
1280x800, 960x600, 720x480, 720x1280 and 390x844 in both projections, including
A/B/G/E comparison wording at both small boundaries. The old headless control has
450 allocation/action-boundary failures; the real-renderer candidate has zero
failures in 37,482 checks. All 292 authoritative digests match across candidates.
Assertion totals differ because the check iterates actual visible labels, shaped
line counts and captured images rather than a fixed number of authored slots.
The final harness adds explicit essential-fact assertions (obligation, cost,
refund, target, inactive queue, direction, interruption and neutral). It passes
38,110 headless checks; the control still has only the same 450 layout failures.
The supplemental render launch was refused before process creation because
Windows could not guarantee background focus. No foreground retry occurred.
The completed final-source renderer report is retained separately from the
strengthened headless report; all 292 panels match exactly in every recorded
field except image path, including text, font/line metrics, bounds and digest.
The exact executed render harness and the added-assertion difference accompany
the package. This distinguishes rendered evidence from the later headless checks.

The raw K/Enter no-target case uses routed input. Normal startup/active/follow-
through, both junctions, Recover, captured Move/Dodge and duplicate queue feedback
use ordinary F2 APIs and native ticks with the original three actors. Commit uses
three ordinary short rightward steps to reach a legal target. Two explicitly
labelled diagnostics use the real resolver: an incoming hit tests interrupted
queues/Commit; a cost-minus-one Energy fixture tests resource refusal. No actor
positions/actions are injected to make these paths pass. Earlier test setup
failures (a long move clamped to one step; low-arrival Energy regenerating enough
to afford Commit) are preserved in development logs and corrected in the final test.

The unchanged executed independent boundary probe is included with provenance in
the handoff. Its exact refusal/normal/queued-Dodge reproductions fail on `495ddd`
and pass on the repair in headless and real-renderer runs. Full raw viewports and
native-scale panel crops cover both small sizes and projections. Engineering
pixel inspection confirms complete, separated current summaries/events/enemy rows.
The unchanged routed touch/controller suite and independent recheck pass again
on the final renderer, retaining Details reach, access/isolation, D3 and restoration.
Natural initial/Wait1/2/3 digests and static keys are preserved. The handoff owns
paths, log/result hashes, inspected-image inventory and exact revision. Independent
acceptance, physical/native input, motion, F0/offscreen completeness, sustained
performance and Guy's acceptance of feel remain open. No export/install or
production publication is part of this repair.
