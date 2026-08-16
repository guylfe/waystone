# Attack capture — implementation specification

**Target baseline:** `0.2.10`
**Design source:** `docs/attack-capture-design.md` (framework and derived values), `docs/combat-loop-diagnosis.md` (why)
**Status:** specification. Review before implementing; do not treat as approved code.

---

## In plain terms

Enemies currently plant their feet when they attack and never step toward you, so walking away always works no matter how late you react. This document says exactly how to make them step forward as they swing, and how to prove it worked.

Three things need to change in the code: enemy melee attacks gain a forward-travel value, enemies commit to attacking at a more consistent distance, and a new test file locks the intended behaviour in place. There is also one pre-existing bug to fix along the way, described in §3.

The same update reworks the Wait button (§10), which today has the same defect in miniature: at half a second it is so coarse that pacing back and forth is a better way to spend a small amount of time than the action built for spending time. It gets a much shorter minimum, matched to a movement step, and hold-to-continue. It is deliberately unassisted — Wait is movement without the repositioning, and it carries movement's risks as well as its grammar. It belongs in this update because a cheap Wait only becomes a real decision once standing still is genuinely dangerous.

---

## 1. Prerequisites

Milestone A, then Milestone B, then this. Neither is in the source as of `0.2.10`.

**A — per-input combo authorisation.** First because it is cheaper, touches disjoint code, and phantom strikes corrupt the action counts everything downstream is measured against. Note `run_state_test.gd:262` actively asserts the broken behaviour — `continue_held` persists and is re-read at every link without being consumed (`run_state.gd:3377`). That test encodes the defect and must be rewritten, not preserved.

**B — post-hit hyperarmor.** Second, and non-negotiable before capture. This change makes enemy melee connect for the first time; without a guaranteed response window after being hit, the first playtest will read as unfair stunlock and the natural but wrong conclusion will be that the capture values are too high.

A and B are reasonably shipped as two commits under one version bump.

---

## 2. Data schema

Two new authored fields on melee action dictionaries:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `advance_distance` | float | `0.0` | Total world units the attacker travels during the attack |
| `advance_end` | float | `0.0` | Action-local time at which translation stops. `0.0` disables translation entirely |

Instantaneous speed is derived, not authored: `advance_distance / advance_end`. Authoring a distance rather than a speed is deliberate — the design parameter `f` yields a distance, and deriving speed keeps the two in sync if a startup duration is later retuned.

For **arc** attacks, `advance_end` must be strictly less than `startup`, so the attacker plants before the damaging window. This is what keeps the lunge readable rather than magnetic. The recommended value is `0.60 × startup`, matching the existing `dodge_strike` shape where travel ends at `0.30` and contact lands at `0.42`.

For **thrust** and **smash** attacks the plant rule does not apply, and `advance_end` may extend into the active window — see §5. Their weapon geometry is still extending while the attack is live, so an attacker driving forward through it is coherent rather than magnetic. The plant rule exists to protect arc readability, and arcs are the only geometry whose footprint is fixed from the first active frame.

### `_melee_action` signature

```gdscript
func _melee_action(duration: float, startup: float, active_end: float, reach: float,
        damage: int, direction: Vector2, technique_id: String = "diagonal_cut",
        action_kind: String = "melee", advance_distance: float = 0.0,
        advance_end: float = 0.0) -> Dictionary:
```

Set `result["advance_distance"]` and `result["advance_end"]` alongside the existing fields. Defaults of `0.0` mean all ~18 existing call sites keep their current behaviour until explicitly given values, so the change can be rolled out one enemy at a time.

Note `_shorten_recovery()` only applies to `action_kind` of `"attack"` and `"sweep"`, so enemy `"melee"` durations are untouched and `advance_end` stays valid. If player attacks are ever given translation, that interaction needs revisiting — `advance_end` is action-local and a shortened duration would shift it.

---

## 3. Fix the existing `dodge_strike` translation bug first

`_update_enemies` is called as `_update_enemies(dt, _simulation_tick_index % 2 == 0)`. Locomotion therefore runs on **alternate ticks only** — 60 Hz inside a 120 Hz simulation. `_advance_enemy_locomotion` compensates explicitly:

```gdscript
_advance_enemy_locomotion(enemy, action, speed * enemy_dt * 2.0, enemy_dt * 2.0)
```

`dodge_strike` is gated on the same `update_locomotion` flag but **does not** apply the `× 2.0`:

```gdscript
elif kind == "dodge_strike":
    if update_locomotion and elapsed <= float(action.get("dodge_end", 0.30)):
        enemy["pos"] = _move_actor(..., Vector2(action["direction"]) * float(action.get("speed", 390.0)) * enemy_dt, ...)
```

So it travels at **half its authored speed** — the Bandit closes ~59 units, not the ~117 its `390 × 0.30` implies. `charge` and `pounce_combo` are not gated at all and are therefore correct.

Fix by adding `* 2.0`, and treat the result as a real behaviour change: the Bandit's dodge-strike capture doubles, so re-check it against the §5 table rather than assuming it still fits. Do this as a separate commit from the new translation work so the two effects stay separable in survey data.

**This is also the trap the new code must avoid.** Any translation added under an `update_locomotion` gate needs the `× 2.0`, or it silently runs at half speed and every derived value in §5 will be wrong by a factor of two.

---

## 4. The `melee` branch

The melee branch is an inline `elif` inside the action loop in `_update_enemies` (`run_state.gd:4030–4159`); there is no separate `_advance_enemy_action` function. Current form, a single `elif` with the timing condition inline:

```gdscript
elif kind == "melee" and elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]) and not bool(action["hit_done"]):
    _resolve_enemy_melee_tick(enemy, elapsed)
```

Replace with:

```gdscript
elif kind == "melee":
    var advance_end := float(action.get("advance_end", 0.0))
    if update_locomotion and advance_end > 0.0 and elapsed <= advance_end:
        # Locomotion runs on alternate simulation ticks, so the step is doubled
        # to keep authored world speed correct. See _update_enemies' caller.
        var advance_speed := float(action.get("advance_distance", 0.0)) / advance_end
        var step := Vector2(action["direction"]) * advance_speed * enemy_dt * 2.0
        enemy["pos"] = _move_actor(Vector2(enemy["pos"]), step, float(enemy["radius"]), int(enemy["id"]))
    if elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]) and not bool(action["hit_done"]):
        _resolve_enemy_melee_tick(enemy, elapsed)
```

Constraints this must preserve:

- **Direction stays locked.** `action["direction"]` is set at commitment and must not be recomputed. The lunge travels along the committed vector; it does not steer toward the player. Do not touch `enemy["facing"]` here.
- **`_move_actor` handles collision.** A lunge into a wall or another actor closes less ground. That is intended — terrain protects the player — but verify no overlap or stall results.
- **Presentation.** The block above `melee` sets `enemy["is_moving"] = false` for every kind outside `["move", "evade"]`. A lunging enemy that reads as static will look wrong in isometric. Setting `is_moving` / `last_motion` during the advance window is a presentation decision worth making deliberately rather than inheriting.

---

## 5. Authored values

### The envelope is not always `reach + 30`

An earlier revision of this table assumed a fixed hit envelope of `reach + PLAYER_RADIUS` for every attack. That is true only for **arc** geometry, which occupies its entire sector from the first active frame (`attack_geometry.gd:60–73`). The other two motions extend over time:

- **Thrust** — a segment extending from `0.42 × reach` at the start of the active window to `1.0 × reach` at its end (`attack_geometry.gd:74–80`).
- **Smash** — a circle whose centre travels from `0.40 × reach` to `0.76 × reach`, with radius `0.55 × thickness`. It never reaches full `reach` at all (`attack_geometry.gd:90–97`).

So the binding moment — the instant at which the player is hardest pressed — is not always attack start. Compare the envelope's growth rate against player speed:

```
ext_rate = (extension_span × reach) / (active_end − startup)

ext_rate > v  →  envelope outruns the retreating player  →  binding at active_end
ext_rate < v  →  player outruns the envelope             →  binding at startup
```

**Compute this rather than hardcoding it.** All three thrusts currently sit just above the Warrior's 260 (281, 294, 277 u/s), so they bind at `active_end` — but the margin is thin, and a later change to player speed could flip them.

The general form, replacing the simpler equation in §2 of the design document:

```
F  =  v · (T_bind − f · T_startup)  −  (E_bind − g₀)
```

For arcs this reduces to the original, since `T_bind = T_startup` and `E_bind = reach + 30`.

### Values

Derived at `v = 260` (Warrior). `f_rad` is the authored intent; everything else follows.

| Enemy · attack | Motion | `startup` | `T_bind` | `E_bind` | `advance_distance` | `f_rad` | `f_lat` |
|---|---|---|---|---|---|---|---|
| Blade · diagonal cut | arc | 0.52 | 0.52 | 142 | 58 | 0.50 | 0.66 |
| Knife · quick cut | arc | 0.32 | 0.32 | 110 | 44 | 0.45 | 0.69 |
| Bandit · quick cut | arc | 0.36 | 0.36 | 112 | 51 | 0.45 | 0.74 |
| Shield · diagonal cut | arc | 0.62 | 0.62 | 152 | 32 | 0.60 | 0.66 |
| Polearm · reverse cut | arc | 0.54 | 0.54 | 156 | 19 | 0.55 | 0.69 |
| Captain · quick cut | arc | 0.30 | 0.30 | 136 | 13 | 0.40 | 0.54 |
| Knight · heavy cleave | arc | 1.08 | 1.08 | 224 | 87 | 0.55 | 0.42 |
| **Polearm · thrust** | thrust | 0.90 | 1.35 | 248 | **239** | 0.35 | 0.84 |
| **Captain · thrust** | thrust | 0.44 | 0.72 | 172 | **141** | 0.40 | 0.67 |
| **Knight · thrust** | thrust | 0.94 | 1.46 | 278 | **244** | 0.45 | 0.84 |
| **Brute · forward smash** | smash | 1.02 | 1.02 | 125 | **123** | 0.65 | 0.65 |

The seven arc rows are unchanged and can be authored directly. **The four bolded rows are provisional and should be authored from measurement, not from this table.** Their derived distances are large — 123 to 244 units — and sensitive to `f`, because a thrust spends up to 0.52s of active window during which the player keeps retreating, and the Brute's smash begins with an effective envelope 30 units *smaller* than its trigger distance. Implement the corrected model, measure the actual critical response time with `test_authored_f_is_honoured`, then tune `f` until the measured value matches intent. Expect those four to need the most iteration.

For `advance_end` on the bolded rows, deliver the distance across the whole startup-plus-active window rather than the arc plant rule: roughly 177 u/s for the Polearm thrust, 196 for the Captain, 167 for the Knight, and 202 for the Brute. Only the total matters to the arithmetic — the binding condition at `T_bind` depends on total displacement, not its delivery curve — so the window is purely a readability choice.

Boar and Werewolf use `charge` / `pounce_combo`, which already translate; leave them alone in this pass. Hound's pounce is one of only two attacks that currently work and is the natural control group — do not modify it, and use its hit rate to sanity-check everything else.

**Author `f`, derive the rest.** When telemetry says an attack is too harsh or too soft, change `f` and recompute. Do not hand-edit `advance_distance`; that severs the link between the number and its meaning and returns the system to untraceable feel-tuning.

---

## 6. Commit distance

`f` is only a controlled quantity if `g₀` — the gap at commitment — is controlled. It currently is not. Attacks fire on the first evaluation inside a threshold, and with `ENEMY_STEER_INTERVAL` at `0.14s` a Blade closing at 230 u/s can commit anywhere across a **32-unit spread**. The same attack will feel forgiving or brutal depending on where the steering tick landed.

### Attack selection must precede approach

An earlier revision of this section said "add `preferred_strike_distance` per attack and make the approach target it," which is circular: the approach has to choose a target distance before it knows which attack it will use, and three enemies have two melee attacks at different ranges — Polearm (112 / 218), Captain (102 / 172), Knight (185 / 252). The branches are ordered shortest-first, so the near attack wins whenever the enemy is inside its threshold. Target the Polearm's 112 and the thrust only ever fires opportunistically while closing; target 218 and the enemy never closes at all.

Resolve it by making selection explicit and prior:

1. **Select an intended attack** when the enemy has no current action and the player is a valid target — weighted by role, range band, cooldowns and context. Store it on the enemy.
2. **Approach that attack's `preferred_strike_distance`**, not the player's position. `_enemy_move_action(enemy, _pursuit_target(enemy), ...)` should target a point at that distance along the vector from player to enemy.
3. **Commit when inside a tight band**, roughly `preferred ± 12`, rather than on first entry to a broad threshold.
4. **Re-select** only on material change — the intended attack coming off or going on cooldown, the player leaving the band substantially, losing line of sight, or the enemy being interrupted.

For the thirteen single-melee-attack enemies this is a no-op. For the three with a choice it makes the decision deliberate and readable: a Polearm visibly settles at thrust range and commits, or visibly closes to reverse-cut range. That is better behaviour than the current reactive threshold crossing, independently of capture.

This also satisfies the handoff's §7.4 principle that enemy profiles own approach and attack selection, rather than those emerging from branch ordering.

A cheaper partial fallback exists — shortening the steer interval inside ~1.5× strike distance narrows the spread without restructuring approach — but it does not resolve the two-attack ambiguity at all, and leaves `f` uncontrolled for exactly the long-range attacks whose values are least certain. Prefer the selection-first version.

Set each attack's `preferred_strike_distance` to its current trigger threshold as a starting point, so §5's derived values remain valid.

**Resolve this before starting Milestone C.** §9 names uncontrolled `g₀` as the failure mode that degrades the whole framework into hand-tuned numbers with extra steps; this is that failure mode's most likely entry point.

---

## 7. Tests

New file `tests/attack_capture_test.gd`, following the existing convention (`extends SceneTree`, test functions invoked from `_init()`, a `fresh_state()` helper, `advance_streamed_action_tick()` to step, `print(...)` then `quit(0)`). Model on `tests/stamina_test.gd`.

A shared harness is needed: place one enemy at an exact distance with walls cleared, force it to commit a named attack, then drive the player with a scripted response beginning at a given fraction of startup, and report whether contact occurred.

| Test | Assertion |
|---|---|
| `test_walk_safe_window_holds` | Blade at preferred distance, retreat from `t = 0.3·T_s` → **miss** |
| `test_walk_fails_when_late` | Same, retreat from `t = 0.7·T_s` → **hit** |
| `test_dodge_covers_the_late_window` | Same setup, Dodge at `t = 0.7·T_s` → **evaded** |
| `test_early_dodge_escapes_by_distance` | Dodge at `t = 0` → miss, and player is *not* in i-frames at contact time |
| `test_spear_punishes_retreat` | Polearm thrust: radial retreat from `t = 0.5·T_s` → **hit**; lateral from same → **miss** |
| `test_cleave_punishes_circling` | Knight cleave: lateral from `t = 0.5·T_s` → **hit**; radial from same → **miss** |
| `test_authored_f_is_honoured` | For each attack in §5, bisect the critical response time; assert within ±10% of `f · T_s` |
| `test_commit_distance_band` | 100 seeded approaches; `g₀` at commitment within ±12 units of `preferred_strike_distance` |
| `test_translation_stops_before_contact` | Enemy position constant from `advance_end` through `active_end` |
| `test_walls_bound_the_lunge` | Wall in the lunge path → reduced closure, no actor overlap, no stall |
| `test_dodge_strike_speed_matches_authored` | Bandit dodge-strike covers `speed × dodge_end` within tolerance (regression for §3) |

`test_authored_f_is_honoured` is the important one. It converts the design intent from a comment into an executable contract, and it is what makes future retuning safe.

### Expect existing tests to fail

`run_state_test.gd`, `warrior_character_test.gd` and `rogue_characters_test.gd` contain combat assertions that may encode the current, broken behaviour — attacks missing where they should now land. **Review each failure individually against the design intent before updating it.** The handoff document's own guidance applies here: a passing regression can faithfully preserve the wrong prototype direction.

Tests that instantiate `RunState` without explicit setup default to Recovery rules. Choose `"recovery"` or `"stamina"` explicitly in every combat test so a passing test means what its name claims.

---

## 8. Versioning and telemetry

- **Save version:** enemy action dictionaries are read with `.get(key, default)` throughout, so old saves deserialise safely without a bump. Confirm against the enemy serialise/deserialise path rather than assuming.
- **Report format:** if capture telemetry is added to survey output (recommended — `f_observed`, the response time as a fraction of startup, is the direct measurement of whether this worked), bump `REPORT_FORMAT` and update `survey_report.gd` in the same change.
- **Version metadata:** keep `README.md` and `export_presets.cfg` in sync, including Android `versionCode`.

---

## 9. Out of scope for this change

Do not touch, in this pass:

- player movement speed, `MOVE_RANGE`, or stride/decision granularity
- stamina costs, regeneration rates, or exhaustion timing
- Sweeping Cut — it is rebuilt later, against the corrected baseline
- enemy startup durations or telegraph lengths
- startup tracking / rotation — the lateral axis is not what is broken, and moving two variables at once makes the result uninterpretable

Two small cleanups belong with this work because they are incoherences rather than balance:

- remove `_try_clean_evade_from_movement()` (guardrail 7 — ordinary movement should not earn clean-evade credit, and it is about to earn it constantly)
- drop `"hit_reaction"` and `"stagger"` from `STAMINA_REGEN_ACTIONS`, and reset `player_stamina_regen_delay` when the player takes damage

The Wait rework in §10 also ships in this update. It is a separate change, but it depends on capture for its balance and should not be shipped alone.

---

## 10. Wait rework

### The problem

`request_wait(duration: float = 0.50, ...)` clamps to `[0.1, 1.0]`. At 0.5 world-seconds, Wait is roughly four movement steps long.

**The default parameter is dead code — do not change it and expect anything to happen.** All three call sites pass `0.50` explicitly: `game_board.gd:920` (the held repeat), `:1238` (the press) and `:1890` (the keyboard path). An earlier revision of this section said "the floor is near-correct and the default is what is wrong," which would have produced a no-op change.

**Hold-to-continue also already exists**, at `game_board.gd:918–920`, re-issuing `request_wait` while `wait_pointer_held and pointer_down`. The grammar is built. What is missing is only the duration, and one guard described below.

The consequence is the same shape as the walking defect: Wait is dominated by its own workaround. A player who wants to pass a small amount of time is better off pacing back and forth — two steps cost 0.26s and yield position, one Wait costs 0.5s and yields nothing. The action intended for spending time is the worst available way to spend time.

### Minimum duration — derived, not chosen

Set the minimum to **one movement step**: `MOVE_RANGE / player_move_speed`.

- Warrior: `34 / 260` = **0.131s**
- Acrobat, Sharpshooter: `34 / 300` = **0.113s**

Deriving rather than hardcoding guarantees that waiting in place is never coarser than pacing in place, and it survives later retuning: if player combat speed is revisited in a later phase, a movement step lengthens and Wait tracks it automatically. A fixed constant would silently drift finer than movement and reintroduce the asymmetry in reverse.

**Implement it in the simulation layer, not at the call sites.** Add `wait_unit_duration()` to `RunState`, returning `MOVE_RANGE / player_move_speed`, and make `request_wait`'s parameter a sentinel that resolves to it when unset. Then drop the `0.50` literals at `game_board.gd:920`, `:1238` and `:1890`. This keeps the derivation next to `player_move_speed`, which lives in `RunState`, rather than duplicating a simulation constant across three presentation call sites where it would drift.

Lower the clamp floor to about `0.05` so the derivation, not the clamp, determines the value. Personal tempo already scales action duration, so faster characters get finer granularity in both Wait and movement without special handling.

### Hold to continue

Mirror the movement grammar exactly: tap commits one unit; holding chains units, each a discrete commitment; releasing finishes the current unit and returns to frozen time.

**No auto-break, no event guardrails, no assistance of any kind.** Wait is movement without the repositioning, and it gets movement's rules exactly — including movement's risks. Holding it is a deliberate choice to surrender world time under whatever pressure the player is under, and judging when to release is the skill the action exists to test.

Three reasons this is right, recorded because the opposite was proposed and rejected:

- **Symmetry.** Held movement has no auto-break. A guardrail on Wait alone would make standing still *safer* than repositioning, which inverts the risk relationship — standing still is the more dangerous choice, especially once capture lands.
- **The accessibility rule does not apply.** `docs/design-foundations.md` §3 guarantees that *releasing* input produces a safe thinking state — the player cannot die because they stopped touching the game. Holding is input: an active, ongoing choice to advance time. The rule protects the absence of input, not its presence.
- **A precise option already exists.** Tapping commits exactly one unit and returns to frozen time, with full information and no time pressure. Hold is opt-in coarseness that trades precision for convenience, exactly as it does for movement. A player who wants frame-by-frame control taps; a player who wants bulk time holds and accepts the consequences.

Being hit will end a wait chain through the existing interruption system, since a hit reaction replaces the current action. That is ordinary shared behaviour, not a Wait-specific rule — do not add a special case for it, and do not suppress it either.

### The context-action collision is on the repeat, not the press

`request_wait` delegates to `request_context_action()` whenever `interaction_label()` is not `"WAIT"` — the same button becomes REST, TAKE, and shortcut interactions.

The press is **already guarded**: `game_board.gd:1236` sets `wait_pointer_held` only when `state.interaction_label() == "WAIT"`. An earlier revision of this section put the fix there, which would have changed nothing.

The actual hole is a **label change mid-chain**. Line 920 re-issues `request_wait` on every repeat without re-checking the label, so if the label flips while the player is holding — a killed enemy dropping a pickup within range, or drifting into Waystone range — the next repeat delegates and fires TAKE or REST unintentionally. Guard the repeat at 919–920, not the press.

### Why this ships with capture

A cheap, granular Wait is only meaningful because capture makes standing still dangerous. Today a stationary player is in no more danger than a moving one, so a finer Wait would simply be another free action. Once attacks advance and land, a stationary target is the one thing every attack can reliably hit, and Wait becomes a real risk/reward decision — spend world time to recover, and accept that anything which commits will connect. That risk is the point, and it is why the action carries no protections.

Note Wait remains in `STAMINA_REGEN_ACTIONS`, and should. It complements walking-based regeneration rather than replacing it; making Wait the primary regeneration route was explicitly rejected as making the game's pace too slow.

### Tests

Add to `tests/attack_capture_test.gd` or a small companion file:

| Test | Assertion |
|---|---|
| `test_wait_minimum_matches_movement_step` | `wait_unit_duration()` equals `MOVE_RANGE / player_move_speed` for each loadout, and an unset `request_wait` resolves to it |
| `test_held_wait_chains_units` | Holding across N unit durations advances world time by ≈N units, with a decision point at each boundary |
| `test_held_wait_has_no_event_guardrails` | An enemy committing a reaching attack mid-chain does **not** end the chain; only release or an ordinary interruption does |
| `test_held_wait_ends_on_hit_reaction` | Being hit mid-chain ends it via the shared interruption path, with no Wait-specific handling |
| `test_wait_and_move_share_granularity` | One Wait unit and one movement step advance world time by the same amount for a given loadout |
| `test_hold_does_not_repeat_context_action` | A label change mid-chain — a pickup appearing in range while held — ends the chain rather than firing TAKE |

Also rewrite the existing `test_held_wait_repeats_until_release` (`run_state_test.gd:996`). It asserts only `simulation_time > start_time + 0.75` after 24 held frames, which still passes at 0.131s units while no longer testing anything meaningful. Assert the **unit count**, not a floor.

---

## 11. Verification before calling it done

1. Run `tests/attack_capture_test.gd`, plus `run_state_test.gd`, `stamina_test.gd`, `warrior_character_test.gd`, `rogue_characters_test.gd`, `combat_survey_test.gd`.
2. Verify a real rendered encounter — headless proves simulation, not readability. The lunge must look like a committed step, not a slide.
3. Build both platforms via `build-all.ps1`.
4. Commit to GitHub.
5. Install to the Pixel Fold if connected and verify the installed package version on-device.

Expect the first survey after this to feel too hard. That is the correct direction of error and should not trigger a rollback — tune `f` upward per attack from evidence.
