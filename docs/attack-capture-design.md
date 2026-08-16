# Waystone — plan to fix the walking problem

**Baseline:** source at `0.2.10`.
**Companion documents:** `docs/combat-loop-diagnosis.md` (why), `docs/attack-capture-implementation.md` (how, at code level).
**Status:** proposal. Nothing here is implemented, and none of it should be until reviewed.

---

## In plain terms

The fix is one sentence: **enemies step forward as they swing.**

Everything else follows from it. Once an enemy closes the gap during its windup, walking away only saves the player if they start early enough. React on the first read and you are clear; dither and the step-in eats the escape, and now a Dodge, a Block, or hitting first is required. *When* the player reacts becomes the whole question, which is exactly what is missing today.

The step-in distances are not guessed. Each attack authors one number — `f`, the fraction of its windup during which walking still works — and the distance is derived from it. So the thing being tuned is design intent in plain language ("a Brute's overhead should be walkable for the first two-thirds of its swing") rather than a physics constant nobody can interpret. When playtesting says an attack is unfair, `f` moves and the derived values follow.

A useful consequence falls out for free. There are two ways to escape an attack — back away, or go around it. Stepping forward ruins backing away but makes going around *easier*, because the enemy ends up closer and its arc is quicker to clear. Turning to track the player does the reverse. Mixing those two differently per attack gives each enemy its own correct answer: never back away from a spear, never try to circle a wide cleave. Those identities emerge from weapon shapes already in the code rather than being designed one by one.

What this does not do: slow the player down, make movement chunky or committed, remove stamina regeneration from walking, or require a Dodge for every attack. Walking stays free and stays a real defensive tool. It becomes the correct tool for the first half of most attacks instead of the answer to all of them.

---

## 1. What we are actually fixing

Not "walking is too strong." The defect is that **walking's effectiveness is not a function of when you use it.** Right now, a player who reacts to a telegraph on its very last frame gets exactly the same result as one who read it at commit: the attack misses. Ordinary movement is a flat, unconditional answer.

The target — taken directly from your own success condition — is that walking's effectiveness should decay across the telegraph:

| When the player commits to walking away | Desired outcome |
|---|---|
| Early in the windup, from decent position | Usually escapes. Walking is rewarded. |
| Mid-windup | Depends on attack geometry, chosen direction, distance, enemy |
| Late, or from bad position | Usually fails. Dodge / Block / Endure / interruption become the answer. |

That is a *timing curve*, not a speed value. Nothing in the current plan produces a timing curve, which is why speed tuning has felt unsatisfying: it moves the whole curve up or down uniformly instead of giving it a shape.

Everything below is built to produce that curve explicitly, as authored data, with one tuning parameter per attack that means exactly what the design intends.

---

## 2. The framework

### 2.1 The radial equation

At the moment an enemy commits an attack, let:

- `g₀` — gap between actors at commitment
- `T_s` — authored startup duration
- `E` — hit envelope = `reach + PLAYER_RADIUS`
- `F` — total forward translation the attacker performs during startup *(currently 0 for every ordinary melee attack — this is the defect)*
- `v` — player walk speed
- `t_r` — the moment within the startup at which the player commits to retreating

The attack connects when the player has not opened enough distance:

```
v · (T_s − t_r)  ≤  E − g₀ + F
```

Rearranged, there is a **critical response time**:

```
t*  =  T_s − (E − g₀ + F) / v
```

Commit to walking before `t*` and you escape. After `t*` you do not. That is the timing curve, and it falls straight out of the existing simulation — no new mechanic is required, only a non-zero `F`.

**One correction to this form.** `E` is constant only for **arc** attacks, which occupy their whole sector from the first active frame. Thrusts extend from `0.42 × reach` to full reach across the active window, and smashes travel from `0.40` to `0.76 × reach` with a fixed head radius. For those the envelope grows while the player retreats, so the binding moment is not necessarily attack start. The general form replaces `T_s` and `E` with the values at the binding moment:

```
F  =  v · (T_bind − f · T_startup)  −  (E_bind − g₀)
```

where the binding moment is `active_end` if the envelope's growth rate exceeds `v`, and `startup` otherwise. `f` keeps its meaning throughout — a fraction of the readable telegraph. `docs/attack-capture-implementation.md` §5 carries the derivation and the per-attack values.

### 2.2 The tuning parameter

Express `t*` as a fraction of the telegraph:

```
f  =  t* / T_s        "the fraction of this attack's windup during which walking still saves you"
```

**`f` is the parameter you author.** `F` is derived from it:

```
F  =  v · T_s · (1 − f)  −  (E − g₀)
```

This matters more than it looks. It means you never hand-tune eleven forward-travel values against feel. You state a design intention per attack — *"a Brute's overhead should be walkable for the first two-thirds of its windup"* — and the number follows. When telemetry says an attack is too harsh, you adjust `f`, which is legible, rather than `F`, which is not. It also survives changes to walk speed, reach, or startup: re-derive and the intent is preserved.

A useful property falls out for free: since `f` rises with `v`, a faster character automatically gets a longer walk-safe window against the same attack. The Speed attribute becomes meaningful in combat with no special-casing, and the Sharpshooter (300 vs the Warrior's 260) keeps a real spacing advantage without a bespoke rule.

### 2.3 The angular equation

Retreat is only one axis. Lateral movement escapes by leaving the attack's arc:

```
f_lat  =  1 − (α · g) / (v · T_s)
```

where `α` is the arc half-width in radians and `g` is the gap at contact (`g₀ − F`).

This is the second, independent dial — and critically, **`f` and `f_lat` move in opposite directions under the two available levers:**

- **Forward translation** shortens the gap, which *raises* `f_lat` (a closer enemy is easier to walk around) while *lowering* `f`. Translation punishes retreat and rewards circling.
- **Startup tracking** (rotating toward the player before the lock point) lowers `f_lat` while leaving `f` untouched. Tracking punishes circling and leaves retreat intact.

So the two levers are not two halves of one fix. They are the two axes of a design space, and an attack's position in that space *is* its identity. This is what produces "different attacks have different correct spatial answers" without authoring a bespoke behaviour per enemy.

---

## 3. Derived starting values

Computed at `v = 260` (Warrior), using each attack's existing startup, reach, trigger distance, and arc from `run_state.gd` / `attack_geometry.gd`. `f_rad` is the authored intent; `F` and `f_lat` are derived.

| Attack | Motion | `T_bind` | `E_bind` | `g₀` | **`f_rad`** | `F` | `f_lat` |
|---|---|---|---|---|---|---|---|
| Blade — diagonal cut | arc | 0.52 | 142 | 132 | **0.50** | 58 | 0.66 |
| Knife — quick cut | arc | 0.32 | 110 | 108 | **0.45** | 44 | 0.69 |
| Bandit — quick cut | arc | 0.36 | 112 | 112 | **0.45** | 51 | 0.74 |
| Shield — diagonal cut | arc | 0.62 | 152 | 120 | **0.60** | 32 | 0.66 |
| Polearm — reverse cut | arc | 0.54 | 156 | 112 | **0.55** | 19 | 0.69 |
| Captain — quick cut | arc | 0.30 | 136 | 102 | **0.40** | 13 | 0.54 |
| Knight — heavy cleave | arc | 1.08 | 224 | 185 | **0.55** | 87 | 0.42 |
| *Polearm — thrust* | thrust | 1.35 | 248 | 218 | **0.35** | *239* | 0.84 |
| *Captain — thrust* | thrust | 0.72 | 172 | 172 | **0.40** | *141* | 0.67 |
| *Knight — thrust* | thrust | 1.46 | 278 | 252 | **0.45** | *244* | 0.84 |
| *Brute — forward smash* | smash | 1.02 | 125 | 155 | **0.65** | *123* | 0.65 |

For arcs, translation is delivered over the first 60% of startup, leaving a plant window before contact — matching the existing `dodge_strike` shape, where travel ends at 0.30 and contact lands at 0.42. Every arc lunge sits at or below the enemy's own pursuit speed.

The four italicised rows are **provisional**. Their geometry extends during the active window, so their distances are larger and far more sensitive to `f`; the plant rule does not apply to them either, since their weapon is still extending while the attack is live. Author them from measurement rather than from this table.

### The identities this produces

The spread is not designed enemy-by-enemy — it emerges from geometry that already exists in the codebase:

- **Polearm thrust** — `f_rad` 0.35, `f_lat` 0.84. Retreat is nearly useless; sidestepping is generous. *"Never back away from a spear."* Worth noting the mechanism is not only the lunge: a thrust's point already extends at ~281 u/s against the Warrior's 260, so it outruns a retreating player on its own. You cannot win a footrace against the tip, but you can step out of a narrow segment. The identity was reached first through translation and then found to be half-built into the geometry already.
- **Knight heavy cleave** — `f_rad` 0.55, `f_lat` 0.42. The only attack where lateral is harder than radial, purely because its arc is already 190°. *"Back off, don't try to circle it."*
- **Brute smash** — 0.65 on both. A circular footprint has no angular escape, so it is pure distance, and the long windup makes it the most forgiving thing in the game. *"Just recognise it and leave."* Its head only ever travels to `0.76 × reach`, so its true envelope is ~30 units *smaller* than its trigger distance — it currently commits from outside its own effective range.
- **Captain quick cut** — 0.40 / 0.54, the tightest pair in the roster. *"This one needs a real defensive action."*
- **Blade** — 0.50 / 0.66. The balanced baseline both answers work against if read early.

That is five genuinely different spatial problems out of one authored number per attack.

---

## 4. Does the player have an answer?

A fix that makes walking fail is worthless unless something else succeeds. Checking basic Dodge (150 units of displacement, i-frames 0.08–0.32 of a 0.56s action) against the Blade at `F = 58`:

| Player commits Dodge at | Mechanism | Result |
|---|---|---|
| t = 0.00 | Displacement — 150 units out, enemy closes 58, ends at 224 vs 142 envelope | Escapes |
| t = 0.25 | i-frames cover 0.33–0.57, contact at 0.52 | Evades |
| t = 0.44 | i-frames cover 0.52–0.76, contact at 0.52 | Evades, just |
| t > 0.44 | i-frames start after contact, displacement negligible | Hit |

There is no dead zone. Early dodges work by distance, late dodges work by invulnerability, and they overlap. The failure window is the last ~15% of the telegraph, which is fair and is exactly where post-hit hyperarmor should catch the player.

Mapping the full picture for the Blade:

- **first 50%** — walking works
- **50% → 85%** — walking fails, Dodge works *(this band is the defensive technique's reason to exist; it does not exist today)*
- **last 15%** — nothing works; you are hit, and Milestone B guarantees you still get to act afterwards

This also revises a recommendation from the diagnosis document: **basic Dodge does not need a numerical buff.** It was never weak — it was unnecessary. Once attacks can land, its existing numbers do the job. I'd hold that change rather than stack two variables.

---

## 5. Implementation phases

Ordered by dependency, not by size. Each phase should be independently testable.

### Phase 0 — Instrumentation and incoherences *(no behaviour change to combat)*

1. Attack-response telemetry as specified in your experiment plan — the record per hostile attack with classified resolution. Add two fields the plan doesn't include: **closest approach between attack geometry and the player during active frames** (tells you *by how much* attacks miss, which is what tunes `f`), and **`f_observed`** — the actual response time as a fraction of startup, which is the direct measurement of the curve in §1.
2. Report `walk_only_escape_rate` broken down by **arena template** as well as by enemy. Nearly free, and it is the only way to learn whether terrain is doing part of this job already.
3. Remove `_try_clean_evade_from_movement()` (guardrail #7 — ordinary movement should not earn clean-evade credit, and it is about to earn it constantly).
4. Drop `"hit_reaction"` and `"stagger"` from `STAMINA_REGEN_ACTIONS`, matching posture's existing behaviour at `run_state.gd:3024`.
5. Reset `player_stamina_regen_delay` when the player takes damage.
6. Milestone A (combo continuation follows live input) — independent of everything here, cheap, and it must land before any telemetry is trusted, since phantom strikes corrupt action counts.

### Phase 1 — Post-hit agency *(Milestone B, unchanged)*

Non-refreshing post-hit hyperarmor through the reaction and ~0.3–0.4s beyond control return.

**This must precede Phase 2.** Phase 2 makes attacks land for the first time; without a guaranteed response window, the first playtest of working melee will read as unfair stunlock and you will wrongly conclude the capture values are too high.

### Phase 2 — Attack capture

1. Add two authored fields to melee attack definitions: `advance_distance` (`F`) and `advance_end` (fraction of startup over which it is delivered, default 0.60). Implement in the `melee` branch of the action loop inside `_update_enemies` (`run_state.gd:4030–4159`) using `_move_actor`, mirroring the existing `dodge_strike` translation path.
2. Add `preferred_strike_distance` per attack and tighten commitment: enemies currently fire at the first evaluation inside a threshold, so `g₀` varies by up to `0.14 × pursuit_speed` (32 units for a Blade). Approach should target the preferred distance and commit within a tight band around it. **Without this, `f` is not a controlled quantity** — the same attack will be forgiving or brutal depending on where the steering tick happened to land.
3. Ship the §3 table as starting values.
4. Leave tracking at zero for this phase. Translation is the whole radial fix; adding rotation simultaneously means two variables moving at once, and the lateral dimension is not the thing that is broken.
5. Rework Wait in the same update — minimum duration reduced from `0.50s` to one movement step, plus hold-to-continue, with no event guardrails. Wait currently suffers the same defect in miniature: it is so coarse that pacing back and forth is a better way to spend a small amount of time than the action designed for it. It is deliberately unassisted, because Wait is movement without the repositioning and takes movement's rules and risks exactly; a guardrail on Wait alone would make standing still safer than moving, which inverts the risk relationship. It ships here rather than separately because a cheap Wait only becomes a real decision once standing still carries risk, which is exactly what capture creates. Specified in `docs/attack-capture-implementation.md` §10.

### Phase 3 — Measure and shape

Run surveys. Compare `f_observed` distributions against authored `f`. Tune **`f`, never `F`.** Then, only where the data shows lateral escape is trivially dominant, introduce startup tracking to pull specific attacks' `f_lat` down.

### Phase 4 — Re-evaluate the deferred levers

With capture working, revisit in this order:

- **Geometry** — likely still needed, and the arena breakdown from Phase 0 will say how much. This is the mechanism Souls leans on hardest and Waystone's survey arenas most systematically remove.
- **Stride granularity** — see §7; probably a fine-tuning knob rather than a fix.
- **Walk speed** — probably unnecessary, and if used, around 200–215 rather than 165–180. Job A (you cannot leave an engagement entirely) is only mildly broken; Job B (staying in a threatened space punishes you) is what Phase 2 addresses.

### Phase 5 — Sweeping Cut

Rebuild as the immediate finisher (117° arc, ~56 stamina, full terminal recovery, no cooldown) **against the corrected baseline**. Part of its current dominance is that free walking herds enemies into a 160° cone; once capture makes that herding cost something, the same sweep is worth less. Tuning it against today's behaviour risks over-nerfing it.

---

## 6. Test contract

These encode the design intent directly and run headless, so most of this is falsifiable without a survey.

| Test | Assertion |
|---|---|
| Walk-safe window | Blade at preferred distance, player retreats from `t = 0.3·T_s` → **miss** |
| Walk-fail window | Same, retreat from `t = 0.7·T_s` → **hit** |
| Dodge covers the gap | Same setup, Dodge at `t = 0.7·T_s` → **evaded** |
| Early dodge | Dodge at `t = 0` → **escapes by displacement**, not by i-frames |
| Spear identity | Polearm thrust: radial retreat from `t = 0.5·T_s` → **hit**; lateral from same → **miss** |
| Cleave identity | Knight cleave: lateral from `t = 0.5·T_s` → **hit**; radial from same → **miss** |
| `f` is honoured | For each attack, measured critical response time within ±10% of `f · T_s` |
| Commitment band | `g₀` at attack start within ±12 units of `preferred_strike_distance` across 100 seeded approaches |
| Translation stops | Attacker position constant from `advance_end` through the active window |
| Terrain blocks lunges | Attacker with a wall behind the player advances less, and no actor overlap results |
| Crowd agency | Three enemies landing hits in sequence → player still gets one executable action between each |

The `f`-honoured test is the important one: it makes the design intent an executable contract rather than a comment.

---

## 7. Why not the other levers first

**Stride commitment.** Worth quantifying rather than debating. Lengthening a stride from 0.131s to 0.20s raises the player's expected reaction lag by ~0.035s, which at 260 u/s is about **9 units** of displacement. The Blade fix needs 58. Stride granularity is roughly a *sixth* as powerful as translation on the radial axis, and its real effect is elsewhere: it reduces the number of *course corrections* during a telegraph (4 down to ~2.6 for a Blade), which matters for circling and for navigating around other enemies, not for straight retreat. It is a lateral-axis tool, like tracking. Test it in Phase 4, and when you do, decouple the two things your experiment plan merges: **keep steering instant and continuous, and change only how often frozen time returns.** A 0.2s latency on direction change will read as broken on touch and will produce a false negative.

**Walk speed.** Cannot produce a timing curve — it scales the whole curve uniformly. The arithmetic in the diagnosis document shows the speed at which current attacks begin connecting is 19–134 u/s depending on enemy, so any speed low enough to fix melee by itself would be a different and much slower game. It also degrades traversal and breaks the Sharpshooter, and `f` already rewards fast characters automatically.

**Shorter telegraphs.** Correctly deferred in your plan. Once `f` is explicit, telegraph length becomes a readability question rather than a balance one — and the right way to set it is your own proposed heuristic of *meaningful decisions allowed* (fast ≈ 1–2, heavy ≈ 3–4), which is now directly computable as `T_s / stride_duration`.

---

## 8. What this deliberately does not change

Movement stays free, continuously steerable, and stamina-regenerating. There is no walk/run split, no committed stride, no engagement slow field, no turn-rate restriction, no ordinary-movement clean-evade reward, and no reduction in decision frequency. Guardrail #6 is respected: the simpler model is being tried first, and it is being tried on the enemy side, where the arithmetic says the defect actually is.

Walking remains a legitimate defensive tool — it is now the *correct* tool for the first half of most telegraphs, and `f` is the explicit statement of how much of each one it covers.

---

## 9. Risks

**Crowds become genuinely dangerous, quickly.** Five enemies that can all land attacks is a different game from five that cannot. Phase 1 is the mitigation, and encounter sizes may need to come down before they go back up. Expect the first post-Phase-2 survey to feel too hard; that is the correct direction of error and should not trigger an immediate rollback.

**`g₀` control is load-bearing and easy to under-implement.** If step 2.2 is skipped or done loosely, `f` becomes noise and the whole framework degrades into hand-tuned numbers with extra steps.

**Lunges may read as magnetic.** The mitigation is that translation stops before contact and the strike resolves from a planted position — the enemy visibly steps in, then commits. If it still reads badly, shift `advance_end` earlier rather than reducing `F`, so the plant window grows.

**Wall and actor collision during lunges.** `_move_actor` should handle this, but a blocked lunge means less closure and a softer attack. That is a feature — terrain protects you — provided it does not produce overlap or stalling.

**The model assumes a full-speed radial retreat from the decision point.** Real players move diagonally, hesitate, and get blocked. Expect measured `f_observed` to be more forgiving than authored `f`, and correct against data rather than re-deriving from theory.

---

## 10. Open questions I could not close from the source

- Knight's `g₀` values are read from trigger thresholds (185 / 252) but its approach uses `_heavy_intercept_target()`, which may deliver it to a different effective distance.
- Whether Recovery mode shares this defect. All arithmetic here is Stamina mode; `_melee_action` carries a comment about a previous divergence in enemy recovery between profiles, so it should be confirmed rather than assumed.
- Whether `_charge_can_contact()`'s gating makes Hound pounces rarer than intended — the Hound is one of only two enemies whose attacks currently work, so its hit rate is a useful control against which to calibrate everything above.
