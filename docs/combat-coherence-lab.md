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

## Focused presentation repair (20 October 2026)

An isolated revision based on reviewed `f31046b2910b6af485be5cdeb90a4b0635cabf72`
repairs D1–D3. Details and Compare now share an 82-unit scrollable information
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
