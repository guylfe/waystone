# Phone world interaction and floor-boundary repair

Owner: Gameplay engineering. Bounded candidate based on `0e65cdfae5b662a9a8951a8ff082ff54c639a7e1`, prepared 2026-11-01. Dr. Stone owns integration, independent review and delivery. Guy owns experience and feel acceptance. This candidate does not change the installed game, build identity, schema, character sheet, Boar tuning or bow commitment rules.

The opening scope statement above describes the frozen `1660a84` repair ancestor.
Its isolated Character successor is recorded in [the menu/input owner](menu-input-correction.md#isolated-character-mobile-successor--1-november-2026). The cumulative successor below retains that Character work and makes the specified spatial/shop/combat corrections.

## Cumulative phone correction — 1 November 2026

Baseline: immutable `e35ffd851c79037deda485eba4dcbd7cf67d3ac3`, retaining parent
`1660a84`. Status: isolated source/headless candidate; combined independent review,
exports, installation, publication and physical-device verification remain open,
owned by Dr. Stone. No live source, build, save or user data is replaced here.

**R1, valid tangent departure:** the analyst's unchanged curved-U root ScreenTouch
probe starts at `(1028.4,800)` beside the radius-150 circle at `(900,800)`, using
the actual player ground radius 21.6. Both projections consume .133333 seconds and
stay still on e35, whereas the baseline moves to `(993.7332,800)`. The successor
matches that inward movement. Tangency is now a departing initial contact rather
than a new collision when motion points inward. Only the initial contact root is
ignored; a subsequent hit on the same edge still stops travel. Arc endpoint tests
use the same linear tolerance before classifying an inward tangent as overlap.
Legacy short inward recovery remains bounded; outward/deeper overlap, later void
crossing, internal seams, actor radii and ordered projectile contacts remain gated.
The radius-200 counterexample and the original inset controls are retained unchanged.

**R2, existing shop refresh owner:** the old exclusive AcceptDialog is hidden and
releases exclusivity before its replacement opens, then remains queued for deletion.
Purchase/training callbacks capture a weak owner and reject a hidden, replaced or
freed owner; deliberate fresh purchases remain valid while stock remains. The
identical independent shop probe reports the exclusive-child error on e35 and no
such error on the successor. Routed purchase/repeat/Back/world-input checks and a
separately labelled stale-callback supplement verify payment, stock, goods and
save/reload. This repairs a baseline-matched defect; it does not identify Guy's
exact late-run merchant/supply refusal.

**Boar pounce, initial lead tune:** selected actions now travel at **640** world
units per enemy-local second and stop tracking at **0.45** of the existing .70
wind-up. `BOAR_POUNCE_ENGAGEMENT_TRAVEL=288` preserves acquisition independently
of launched speed: minimum 88 and existing LOS/contact allowances, maximum 378
for the ordinary radius-42 Boar/player-30 fixture. Startup .70, active end 1.50,
duration 1.95, cooldown 2.40, damage 25, shoulders/contact bonus 22, armor and
interruption are unchanged. Hound and Ox tempo/speeds are unchanged. The body
facing and existing directional pose use the frozen action bearing after lock.

Actual selected actions are tested using public wait/movement and ordinary
main-root touch/drag/release, standard loadouts and both rule profiles. Simulated
choice delays and open/narrow geometry/ally/defense/interruption controls are
labelled fixtures. The lead's earlier parameter-mutating open-arena study is
directional evidence, not a normal-input or feel verdict; this implementation does
not change acquisition to the faster body's larger travel allowance. Source/test
results do not settle whether the tune feels fair or threatening on a phone.

**Additional Commit Shot:** [the character framework](combat-character-framework.md#152a-isolated-additional-commit-shot--1-november-2026)
owns the new select-then-target full-draw commitment and +25% damage, with one
ordinary full-shot payment. [The input owner](controller-controls.md#isolated-additional-commit-shot--1-november-2026)
records touch/G/Tab/Enter/LB+A mapping and the bounded captured F/Bow release
correction. Ordinary charging, Take Aim, both arts, earned rank/preload benefits,
interruption, physical-neutral safety and menu/suspend policy remain controls.

The external combined handoff owns exact immutable SHA/tree, unchanged-probe hashes,
paired observations, all log scans and measured desktop costs. Known defensive-choice
and banner/version failures are retained separately; exit 0 alone is not acceptance.
The existing telemetry suite's three slow-Boar retreat expectations are explicitly
superseded by this specified tune: close straight retreat and a delayed committed
strike at 220 may be caught; early distant retreat and early sideways answers remain
controls. Hound expectations are unchanged. The exact ten-prompt count now allows
the additional eligible Commit Shot entry while retaining all ten ordinary prompts.
Golden gameplay fixtures remain unchanged: inactive optional Bow flags canonicalize
to their historical absent/false default, while active benefits/consumption and an
active committed shot participate in the semantic fingerprint. A positive-control
test verifies that an earned benefit changes that fingerprint.
Presentation-frame copy implementation/ownership and prior Character controls remain
unchanged. Headless timing is not phone GPU/thermal/frame-rate evidence. Exact wall-lag,
late-run refusal and attack-reset symptoms remain unresolved. No raw/wireless Android
or host-window route is used. Eventual Android work requires the USB Phone Harness.

Retained `phone_baseline_probe`, `phone_boundary_probe` and six `independent_*`
probes are copied byte-for-byte from the analyst's authorized 1660 review artifacts.
Their original baseline/SHA headers intentionally remain; execution receipts and
probe hashes identify the actual tested checkout. Engineering reruns of those
instruments are not a new independent review. The external handoff retains the
original paths, exact hashes and unmodified before observations.

## Requirements and observed failures

Design Foundations requires clear interactables, consequential actions, shared spatial rules and faithful contact. Guy reports supplies refusing nearby collection, merchant access trouble, shots crossing concave map void and phone slowdown around Earth walls. His exact supply location/seed is unknown.

The retained main-scene headless touch fixtures demonstrate two independent pickup defects: collection chooses the first eligible nearby item after checking a different tapped item; overlapping hit targets choose the last array entry even when the tap is exactly on the closer marker. A compressed isometric fixture has a near marker at offset `(20,20)` and an out-of-reach marker at `(95,95)`: projected separation 48.686 versus hit radius 49.336, while the latter is 134.350 world units away. The baseline wrongly says move closer. These are constructed reproductions of source defects, not a claim to have recreated Guy's run.

Generated exploratory supplies at `(650,3450)` collect successfully on the baseline across seeds 73, 717 and 99117, all three biomes and both projections. Merchant context interaction also remains usable at safe generated merchants. Tapping the merchant marker itself has no baseline handler and falls through to movement. The new route opens that same finite-stock shop, preserving its transactions and the context action.

After an ordinary purchase, isometric goods can overlap the merchant's tap area: 47.175 projected units of separation versus a 49.336 pickup hit radius in the model. Pickup and merchant routing therefore compare screen distance before choosing a handler. An exact merchant tap reopens trading and leaves the goods; an exact goods tap collects that item. The existing pickup priority remains for indistinguishable equal-distance ties.

Projectiles only check rectangular extent and endpoint walls in the baseline. A swept step can leave a concave floor union, re-enter it and hit a body beyond the void. Full projectile radius, curved boundaries and high arcing shots are covered by the correction. Large movement steps, vault, Advance, Windstep and Gale also require continuous floor checks; endpoint occupancy remains in force.

## Source ownership and behavior

- `scripts/core/floor_boundary.gd` derives the exposed line/arc boundary of each layer's rectangle/circle/capsule floor union. It splits primitive intersections and removes covered internal seams. Swept discs use analytic contact times with edges and arc endpoints; they do not march by timestep or accept a later re-entered endpoint. Spatial buckets bound warm queries. Derived boundaries are rebuilt with the shape index at map installation, outside the first action. Floating-point seam probes use a 0.001-world-unit outward offset.
- `scripts/core/run_state.gd` owns floor collision and collection by stable pickup ID. Shots clip their swept segment to the first floor, world, wall, low-barrier or range boundary before ordering body contacts by swept-circle entry time. A body before the obstruction can be hit; a body beyond it cannot. Piercing shots resolve eligible preceding bodies in order and still expire at the edge. Firebombs land on the valid side. Existing faction/misdirection and low-obstacle elevation policies remain. Movement retains the existing 0.72-radius actor ground footprint and ordinary endpoint/body/barrier rules. It checks the straight displacement actually returned to presentation, so individually safe axis probes cannot display a diagonal cut across void. Short inward recovery from a legacy cardinal-probe footprint remains possible while the center is continuously swept; outward movement cannot deepen that overlap.
- `scripts/presentation/game_board.gd` chooses the closest discovered, camera-visible pickup marker using the renderer's discovery predicate, resolves its ID against current state, and requests that exact collection. Undiscovered objects cannot intercept its tap area. It routes discovered merchant-marker taps to the existing shop. The lower TAKE label now uses the same 112-unit reach as collection, instead of advertising TAKE up to 145 units away. Specific refusal messages distinguish missing item, readiness, pending replacement, layer, distance, guards, hostile hazards, projectiles and enemy threat.
- `scripts/core/expedition_economy.gd` centralizes the existing safety predicate's refusal text. Merchant distance remains strictly less than 150; pickup reach remains at most 112. Equipping now validates the pickup's layer as collection already does. Currency, finite stock, guarded rewards, full-belt replacement and save policy remain owned by the existing transaction code.
- `scripts/presentation/presentation_frame.gd` caches immutable schema descriptor selections per frame and copies nested values directly into frame storage once. The prior intermediate projection and second deep copy are removed. Captured and blended values retain their schema, defaults and independent mutable ownership.

## Reproduction and checks

Run under Godot 4.7 headless with APPDATA and LOCALAPPDATA redirected to an isolated `.runtime` folder. Never use a personal save. The external `run_headless.py` records the command, isolated data path, return code and all engine/script errors; a zero process exit alone is insufficient.

| Test | Evidence |
|---|---|
| `phone_world_repair_test.gd` | Main-scene routed touch with discovered fixture cells; selected ID/overlap/stale snapshot/hidden marker; merchant marker and threat denial; normal/large swept floor crossings, source IDs, arcing height, first-body order and connected seams. Final counts are recorded externally; the initial baseline failed 16 of 19 cases. |
| `generated_supply_route_test.gd` | 54 checks over generated data with explicit fixture positioning: 18 supply successes, 18 context successes, 18 marker-shop cases. Baseline fails only the 18 marker-shop cases. No earned journey or real-device input is claimed. |
| `merchant_overlap_input_test.gd` | Eight routed-input checks for ordinary purchased ground goods beside the merchant in both projections. The first candidate fails two isometric reopen/preservation checks; final routing corrects them. |
| `generated_floor_shot_test.gd` | Actual seed-717 Expedition floor/walls from `(650,3450)` to `(1400,2650)`; endpoints are valid, the segment crosses void, and interior-wall line of sight is clear. Baseline shots survive the gap at normal and one-second timesteps; the candidate stops both. Actors are removed and a shot injected to isolate geometry; no earned play is claimed. |
| `phone_repair_guards_test.gd` | Safety/distance/layer guards, exactly-once collection, full belt and displaced stacks, equipment layer, atomic stock/currency/item persistence; piercing/player/firebomb ordering, airborne low-barrier exception and movement paths. |
| `floor_boundary_geometry_test.gd` | Analytic expected circle/capsule/rect contact, a half-unit gap and exposed versus internal seams. Deterministic random union sweeps are compared with a separate dense perimeter oracle. |
| `actor_floor_path_test.gd` | A large-step concave case where both separate axis paths are on floor but the returned diagonal crosses void. Three baseline failures cover player, enemy and vault; successor blocks all three. |
| `presentation_copy_parity_test.gd` | Previous two-stage projection parity for all six entity kinds, nested independence, absent/default cleanup, previous/following frame isolation and blend weights. 44 checks pass on baseline and successor. |
| `phone_cpu_profile.gd` | Three generated populated biomes, seed 717, no wall/enemy wall/player wall; generation, raise, cold tick, warm tick, barrier update, presentation capture and full action costs. Direct scenario positioning/casting and extra HP are explicit fixtures. |
| `presentation_cpu_profile.gd` | Identical frozen populated source for no/enemy/player wall. Records cold and 200 warm capture/blend samples plus data hashes, separating projection cost from changing simulation. |

The external evidence ledger records the final frozen revision, raw logs, full regression outcome and before/after timings. New cases deliberately preserve baseline failures. Historical and unsuccessful harness runs are retained and separately labeled; only error-free final runs support acceptance.

Two pre-existing motion/steering tests spawned shots at `(150,150)` and `(100,100)`, outside the generated floor. Their origins are moved onto the authored starting clearing, keeping their displacement and unsteered-heading assertions. The same adjusted fixtures retain only the already documented defensive-choice failure on the baseline. The baseline structure audit separately has five unchanged version/banner failures; they are not suppressed or added to the expected-failure ledger by this repair.

Broader diagnostics retain two baseline failures in `world_generation_test.gd` (legacy terrain-boundary expectation and route reachability). The four ordinary-policy seed-42 playthrough drivers also lose on both baseline and candidate, with different outcomes for three characters. These are not accepted journeys or balance evidence. No combat tuning is introduced to make an automated driver win; independent journey and human play acceptance remain open.

## Phone follow-up owned by the lead

Use the final integrated Android artifact with its SHA/build identity recorded, on Guy's Pixel Fold in both folded and unfolded sizes. Keep his data intact; diagnostic fixtures must have a separate save identity or run in memory. Record Android/device version, display size, refresh rate, battery/thermal state and camera projection. Repeat at least five cold entries and a 60-second warm sample for each matched populated biome and wall variant. Include wall raise, lowered segments near enemies, re-rise with player clearance, struck gaps and expiry, ordinary movement/casting and actual touch collection/trading. Capture CPU simulation, presentation capture/blend, draw CPU, GPU/frame time, p50/p95/p99, allocation/GC, dropped realtime and touch-to-visible-response latency. Match actor/effect counts and camera location across variants.

Headless desktop timings cannot establish GPU cost, phone frame rate, thermal behavior, touch latency, readability or Guy's acceptance. The exact late-run refusal and the original attack-reset symptom remain unresolved. No export, installation or publication is part of this first candidate.
