# Code structure audit

**Status:** Implemented in `0.2.75`. The two live defects remain recorded as the `0.2.74` prelude; all accepted structural work below is now in source and covered by focused contracts.

**Recorded:** 2026-08-31 after `0.2.73`. Second audit and decisions added 2026-09-01.

**Scope:** Where the source repeats itself, what that has already cost, and what to unify. Every proposal must leave gameplay identical — this is about how the rules are written, never about what they are.

**How to read this file.** Three audits and a decision layer. If you are picking this up fresh, read *Decisions and execution order* first — it is the plan for the first two. Then read **Third audit — a boundary is not a representation** at the end: it is the newest, it is not yet planned or executed, and it explains why the second audit's own instruments could not see the class of defect it describes.

---

# Decisions and execution order

## Before starting: standing context

- **Do not write code until the change is approved.** Present a plan and wait. This is a project rule and it exists because it was violated before at real cost.
- **Gameplay must not change.** Every item here is about how rules are expressed, never what they are. If a change makes something play differently, it is out of scope and needs raising as a design question instead.
- **Two test failures are documented and expected**, and must not be "fixed" by weakening them:
  - `run_state_test.gd` — `test_clean_opening_hit_preserves_a_defensive_choice`. The bandit strafes out of the arc; a pursuit question, not a post-hit one.
  - `capture_telemetry_test.gd` — `a late sidestep at mid range must fail`. The Boar misses by 9.6 of a 72-unit contact width; an open tuning question.
  - These live in `tests/expected_failures.json`. A green `run-tests.ps1` run reports both as `EXPECTED FAIL`; an extra failure in either file is a regression, and an unexpected pass is surfaced as `XPASS` for contract review.
  - The ledger matches on **reason, not count**. A file may fail for exactly the one documented cause; every distinct failure it reports must name that cause, however many times the engine prints it. The original `problemCount` field compared an inflated match tally against an authored number, never agreed, and left the mechanism inert from the day it landed — verified fixed by injecting a second failure and confirming the run goes red.
- **Beware the already-red file.** Three times in one session a stale or broken assertion hid inside a file that was already failing for one of the two reasons above, and reported nothing new. When touching a system, run its test file alone and read the assertion line numbers, not the summary.

## Already fixed — do not redo

Both were found by the second audit and shipped in `0.2.74`.

- **A test broken by `0.2.73`.** `run_state_test` asserted Gale displaces bodies on the frame it lands, which the impulse change falsified. Gale's displacement contract now belongs solely to `mage_elementalist_test`; `run_state_test` asserts only that the wind takes hold of the right bodies.
- **Duplicate phase readouts.** `frost_lance` and `fire_breath` each had two branches in the phase-text chain, the second unreachable. `0.2.66` added the first pair while claiming these abilities had none; the originals were the better writing and the additions are gone.

## Verified findings

Everything below was checked against the source before being accepted. File and line references were current at `0.2.74`.

| Claim | Verified |
|---|---|
| Three independent snapshot writers; ~157 keys duplicated across two literals | yes |
| `PresentationFrame` never captured `barriers` — the six-version invisible wall | yes |
| ~13 edit sites to add one enemy kind, across three files | yes |
| Five identical `_begin_*_cooldown` helpers with parallel `_max` scalars | yes |
| `_inside_world` ×7, `_point_in_wall` ×4, `_actor_footprint_on_floor` ×5, combined by hand | yes |
| `CombatCatalog.role()` silently returns `frontline`; `archetype()` silently returns Blade | yes |
| `_blend_flat_array` pairs items by array index, so one expiry mis-pairs the rest | yes |
| Duplicate `frost_lance` / `fire_breath` phase branches, second unreachable | yes — fixed in `0.2.74` |
| Contradictory Gale assertions across two test files | yes — fixed in `0.2.74` |
| Some player spells reuse enemy spawners, others build projectile dictionaries inline | yes, and worse than stated — see below |

**On that last one.** `mage_elementalist_test` contains the comment *"Each spell resolves through the same spawner its enemy version calls"*, and it is false: `fireball` and `frost_lance` construct their projectiles inline in `_resolve_player_spell` while `fire_breath` and `cold_front` call the shared spawners. The comment describes an intention, not the code. Fixing the inconsistency is part of C1; deleting or correcting the claim is not optional either way.

## What is accepted

**Accepted as written:** original items 1–4 and 6; Sol 5.6's C1, C2, C3, C6, and the refinements on catalog fallbacks, cooldown slot constants, survey counter descriptors, and golden-run hashing.

**Accepted with amendment:**

- **C2 is promoted to the front of the queue**, ahead of the harness. Validators are cheaper than a harness, cannot change behaviour, and catch a class of error the harness cannot see at all — a kind that is never registered currently ships as a working Blade rather than as an error. This is the one change to Sol 5.6's ordering.
- **Original item 5 (factions) is subsumed into C4.** Allegiance alone does not unify how damage, conditions, posture and impulse are applied; the shared actor boundary is the real work and the faction test is one part of it.
- **C5 (save migrations) is accepted but deferred** to the end. It is real, and it is the least urgent: saves are currently loaded by a version whitelist that already refuses anything unrecognised, so the failure mode is a refused load rather than a corrupted run.

**Declined for now:**

- **C7, one source for the version number.** Real, but `ship.py` already synchronises the four sites and the failure mode is a wrong number in a changelog rather than a bug in the game. Revisit if it ever drifts in practice.
- **The structured occupancy query returning a blocking reason**, in favour of the simpler predicate, *until a second caller actually needs the reason*. The criticism is correct in principle — a boolean that accretes flags is a smell — but so is a query object with one consumer. Build the predicate; promote it the moment placement or telemetry genuinely wants to know *what* blocked.
- **Splitting `run_state.gd`.** Both audits agree. Ownership boundaries first; files shrink along them afterwards or not at all.

## The order to do them in

1. **Resolve contradictory test contracts** and record the expected-failure ledger. One canonical contract test per behaviour; integration suites assert their boundary, not another file's internal timing. *(Partly done in `0.2.74` for Gale — the rest of the suite still needs the sweep.)*
2. **Catalog and runtime schema validators.** No behaviour change. Remove the silent Blade/frontline fallbacks for authored IDs, and add cross-catalog checks: every encounter kind has an archetype, role, attributes and an AI branch; every melee plan names a real technique; every progression choice names an implemented ability; every action and hazard kind has an executor and presentation metadata.
3. **The golden-run harness**, with named checkpoints rather than one opaque hash. Hash a canonical authoritative projection — sorted keys, RNG state included, caches and presentation excluded, stable float handling — so a failure says *what* diverged.
4. **Canonical ability/action/effect definitions** (C1), including folding the inline player projectile construction into the shared spawners.
5. **The occupancy predicate** and central actor mutation methods owning IDs, buckets and cache invalidation.
6. **Per-kind facts into the validated catalog**, including the renderer's colour, name, speed, reach and trait strings.
7. **Survey counter descriptors and cooldown slots**, both behind stable constants rather than bare strings.
8. **Stable IDs for dynamic presentation entities**, blending by ID, and one time authority per frame. This also repays the debt knowingly taken in `0.2.72`, where barriers and the Circle were moved to live state to stop them being invisible — correct at the time, and it does mean objects drawn together can represent different moments.
9. **Save migrations and audience-flagged schemas** (C5).
10. **The shared actor/effect boundary and factions** (C4 plus original item 5), last because it is the change most likely to look like it should alter gameplay.

## Implementation record — `0.2.75`

All accepted items above are implemented. The ownership points are:

- `determinism_snapshot.gd` and `golden_run_test.gd` for named semantic checkpoints;
- `combat_catalog.gd`, `ability_catalog.gd`, `runtime_schema.gd`, and `structure_audit_test.gd` for canonical facts and fail-fast registration/schema checks;
- `_can_occupy`, actor repository methods, `actor_view`, `_faction_of`, and `_opposes` in `run_state.gd` for spatial and actor/effect boundaries;
- `survey_counter_catalog.gd` and cooldown slot constants/accessors for registry-driven plumbing;
- stable `presentation_id` values plus ID-based blending in `presentation_frame.gd`, with barriers and the Circle taken from the same frame as other dynamic objects;
- `state_field_schema.gd` for explicit snapshot/presentation/save audiences;
- `save_migrations.gd` for sequential schema normalization before hydration;
- `tests/expected_failures.json` and the runner's exact-signature handling for the temporary failure ledger.

The declined items remain declined: no single version source was introduced, occupancy remains a boolean predicate until a caller needs blocking reasons, and `run_state.gd` was not mechanically split.

Steps 1 and 2 change no behaviour and should be verifiable by the existing suite alone. Nothing from step 4 onward should be attempted before step 3 exists.

---

# The original audit

**Author:** Opus 5, recorded 2026-08-31 after `0.2.73`. Kept as written; the decision layer above supersedes it where they differ.

## Why now

The Elementalist took eleven versions to ship and roughly half of those were spent on defects that were structural rather than particular. The invisible Earth Wall alone consumed six: it was not a drawing bug, a duration bug, a placement bug or a timing bug, though it was diagnosed as each of those in turn. It was a field that existed in one snapshot writer and not in another.

That is the pattern worth attacking. Individually each of these bugs looks like carelessness; together they are the same shape appearing wherever the same idea is written more than once.

---

## 1. Three parallel snapshot writers *(highest value)*

The simulation is copied out to other systems in three unrelated places:

| Writer | Consumer | Notes |
|---|---|---|
| `snapshot(lightweight)` | probes, tests, some board paths | two near-identical literals, ~157 keys duplicated between them |
| `PresentationFrame.capture()` + `blend()` | **the renderer, during every streamed action** | pooled and interpolated; `blend` carries only keys it names |
| `_build_save_payload()` / `load_run()` | saves | third independent list |

Adding a field means remembering up to four lists. Forgetting one is silent — no error, no warning, and the failure surfaces as behaviour rather than as a crash.

**This is what the invisible wall was.** `barriers` was added to `snapshot()` in `0.2.65` and never to `PresentationFrame`. Because a probe sets `visual` from `snapshot()`, every capture I took drew the wall correctly while the game never could. The probe and the game were reading different pictures, so no amount of probing could reproduce it.

**Proposal.** Declare the presentation surface once — a list of field descriptors, each naming the source, whether it interpolates, and whether it is pooled — and have all three writers walk that list. A new field is then one line, and it is impossible for one consumer to be missing what another has.

**Risk:** medium. **Value:** removes an entire bug class that has already cost more than any other.

---

## 2. Per-kind data scattered across two files

Adding one enemy kind currently means editing, at minimum:

- `combat_catalog.gd` — `ARCHETYPES`, and `MELEE_ATTACK_PLANS` if it swings
- `run_state.gd` — health table, posture base, survey cost, personal tempo, move speed, threat weight, and a branch in `_choose_enemy_action`
- `game_board.gd` — colour, display name, speed word, reach word, trait sentence, and any pose or phase branches

Roughly thirteen places, each a literal dictionary keyed by kind, each defaulting silently when a kind is missing. The Air Caster took five of these; two were found only because a test happened to touch them.

**Proposal.** The catalog already exists to be the home for per-kind facts. Move the numeric tables into `ARCHETYPES` as ordinary fields, and give each archetype a `presentation` block for the renderer's strings and colour. `run_state` and `game_board` then read the archetype instead of consulting private tables. Adding a kind becomes one entry plus a decision branch — and the decision branch is genuinely per-kind behaviour, so it should stay.

**Risk:** low, mechanical, and easy to verify field by field. **Value:** high, and it compounds with every future enemy.

---

## 3. Five identical cooldown helpers

`_begin_skill_cooldown`, `_begin_advance_cooldown`, `_begin_main_ability_cooldown`, `_begin_subclass_cooldown` and `_begin_spell_cooldown` are the same two lines over different variable pairs, each with a parallel `_max` companion, each separately ticked down, saved, and read by the HUD.

**Proposal.** One `cooldowns: Dictionary` of `{slot: {remaining, maximum}}` with `begin_cooldown(slot, seconds)`. Ticking, saving and HUD reads become loops. The HUD's long conditional chain choosing which cooldown to draw for which loadout collapses into a slot lookup.

**Risk:** low. **Value:** moderate, and it removes the reason the HUD has per-loadout conditionals at all.

---

## 4. Movement gates re-derived per ability

`_inside_world` appears seven times, `_point_in_wall` four, `_actor_footprint_on_floor` five, each combined by hand at the call site. Windstep checked world and walls and barriers but not the floor, which is exactly how an Air Caster threw itself off the map — the arena is a disc inside a much larger world, so leaving the arena still counts as being inside it.

`0.2.72` unified that one path into `_teleport_allowed` and the bug disappeared. The same shape remains in spawn settling, charges, pounces and crowding.

**Proposal.** One predicate — `_can_occupy(position, radius, actor_id, ignore_bodies)` — used by `_move_actor`, by every direct position write, and by placement. Abilities stop deciding what "somewhere valid" means.

**Risk:** low. **Value:** high; this is the fix that has already proved itself once.

---

## 5. Player-versus-not, where the rule is actually about sides

Barriers blocked "the player" because only enemies could raise one when the rule was written. When the Elementalist learned to raise walls, the player's own wall blocked the player and let enemies through — the rule exactly inverted. `0.2.72` fixed it with an ownership test.

The same assumption is still load-bearing elsewhere: `_position_blocked_with_context` branches on `actor_id == 0` in three places, hazards resolve against the player alone with a special case bolted on for player-cast zones, and the crowding push is player-only.

**Proposal.** A single notion of side — `_faction_of(actor_id)` and `_opposes(a, b)` — consulted by barriers, hazards, pushes and displacement. The player becomes one actor among several rather than a branch. This is the change most likely to *look* like it should alter gameplay, so it wants the determinism harness below before it is attempted.

**Risk:** medium-high. **Value:** high, and it is a prerequisite for allied actors ever existing.

---

## 6. Survey counters are five-place plumbing

A new counter must be declared, reset per run, captured into the room-entry baseline, differenced into the room record, and printed. Miss the baseline and every room reports the run's running total — which is what happened to four counters at once, caught only because a room with zero seconds of combat reported six friendly-fire hits.

**Proposal.** Declare counters once as `{name: default}`. Reset, baseline, difference and report all iterate that. Adding a measurement becomes one line and one report string.

**Risk:** low. **Value:** moderate — but it protects the instrument the whole project steers by, which argues for doing it early.

---

## 7. `run_state.gd` is 10,011 lines

This is the enabler for everything above: at that size nobody, human or otherwise, holds the whole file, and the cheapest way to add anything is another local table.

I would **not** split it yet. A split is the riskiest change on this list and the least valuable per unit of risk, and the six items above remove most of the pressure that makes the size painful. Revisit once they are done.

---

## The thing to build first

Every proposal here promises identical gameplay, and that promise needs a test rather than a claim.

The simulation is already deterministic: same seed, same inputs, same outcome. So a **golden-run harness** — drive a fixed seed through a scripted sequence of actions, hash the resulting simulation state, and compare against a recorded baseline — turns "gameplay is unchanged" into something the suite can check. It would also have caught several of the bugs above on its own.

Build that first, then take the items in this order: **4 → 2 → 6 → 3 → 1 → 5**. Cheapest and safest first, the two structural ones last, and nothing attempted without the harness in place.

---

# Sol 5.6 Independent Audit — Suggestions for Opus Evaluation

> **Authorship and status:** Everything from this heading onward is the Sol 5.6 independent audit, appended after the original audit and kept as written. It was offered as suggestions to evaluate; that evaluation has since happened, and *Decisions and execution order* at the top of this file records what was accepted, amended and declined, along with which claims were verified against the source. Where this section and that one differ, the decision layer is current.

The original audit identifies the right underlying failure mode: one concept is represented independently in several places, and omissions fail silently. The following additions cover places where that same problem exists outside the six examples above, plus refinements intended to keep the proposed universal systems from becoming new collections of loosely checked strings and flags.

## C1. Abilities, actions and effects lack a canonical definition

The enemy catalog is only one half of the authoring problem. A spell or ability is currently declared separately in progression data, Energy cost, label, targeting category, request timing, resolution, enemy decision-making, action classification, telegraph drawing, phase text and tests.

There is direct evidence of drift:

- The Fire Caster's shot was renamed from `firebolt` to `fireball`, while the renderer retained the old name and drew the caster using a bow. The corrective comment is in `game_board.gd` around the enemy-action drawing branch.
- `_action_phase_text` contains two `frost_lance` branches and two `fire_breath` branches. The later pair is unreachable, so the file contains two authored descriptions of each phase but only one can ever appear.
- Player and enemy versions of some elemental spells share spawners, while others independently construct similar projectile dictionaries despite the nearby claim that the enemy spawners are the shared implementation.
- `PLAYER_ATTACK_ACTION_KINDS`, `ENEMY_ATTACK_ACTION_KINDS` and `ENERGY_REGEN_ACTIONS` are additional registration sites that a new action can silently omit.

**Sol 5.6 proposal for Opus to evaluate.** Add a canonical ability definition keyed by a stable ID. It should own the authored facts shared across callers: cost, target mode, range, timing, action/effect type, classification, and presentation metadata such as telegraph shape, colour and phase labels. Explicit player/enemy delivery overrides can remain where their behavior is intentionally different. Enemy AI should still decide *when* and *why* to use an ability; the definition should say *what the ability is*.

This should not become a general-purpose spell scripting language. The useful boundary is centralized authored facts and a checked schema, not replacing all behavior with data.

**Risk:** medium. **Value:** very high; this is the largest remaining example of the bug class the original audit targets.

---

## C2. Runtime dictionaries need constructors, schemas and fail-fast validation

Actions, hazards, projectiles, barriers, effects and actors are raw dictionaries whose contracts are distributed among their producers and consumers. Optional `.get()` defaults make them tolerant at runtime, but also let missing or misspelled fields select plausible, incorrect behavior.

`_update_hazards` demonstrates the hidden protocol. Ownership and resolution depend on combinations of `friendly`, `source_id`, `kind`, `triggered`, timing fields and geometry-specific fields. The renderer also uses structural clues such as the presence of `half_angle` to decide whether a hazard is a cone. Those can be useful representations, but nothing currently verifies that every producer supplies the required combination.

The same problem exists in the catalogs. `CombatCatalog.role()` silently treats an unknown kind as `frontline`, and `CombatCatalog.archetype()` silently substitutes the Blade archetype. A missing registration therefore produces a convincing enemy rather than an authoring error.

**Sol 5.6 proposal for Opus to evaluate.** Keep dictionaries if they remain the most practical Godot representation, but construct them through named helpers and validate their schemas in tests or development startup. Add cross-catalog validation proving that:

- every encounter enemy has an archetype, role, required attributes and an AI implementation;
- every authored melee plan refers to a real attack technique;
- every progression choice refers to an implemented ability;
- every spell has cost, targeting, timing, execution and presentation definitions;
- every action and hazard kind has the required executor and presentation metadata;
- required fields exist with the expected types.

Unknown authored IDs should fail loudly. Permissive defaults should be reserved for genuinely optional runtime fields and old-save migration.

**Risk:** low for validation, medium for introducing constructors incrementally. **Value:** very high because it makes all subsequent catalog work safer.

---

## C3. Dynamic presentation objects need stable identities and one time authority

The snapshot proposal above addresses omitted fields, but there is a second presentation problem. `PresentationFrame` matches enemies by ID, while `_blend_flat_array` matches projectiles, hazards, effects and pickups by array index. If an item expires, spawns, or changes order between frames, one object can interpolate toward an unrelated object.

There is also more than one dynamic render-time authority. Most moving state comes from the interpolated presentation frame, but the Circle and barriers are read directly from live simulation state because barriers were absent from `PresentationFrame`. That repaired their invisibility, but objects drawn together can now represent different simulation moments.

**Sol 5.6 proposal for Opus to evaluate.** Give every dynamic presentation entity a stable ID and blend collections by ID. A new or removed entity should appear or disappear rather than cross-blending with its former array neighbour. Establish an explicit boundary:

- immutable geography may come from a static world view;
- every dynamic datum visible in a frame comes from that frame;
- consumers do not silently fall back from the frame to newer live state.

**Risk:** medium. **Value:** high; it prevents visual-only failures that probes and simulation tests may not reveal.

---

## C4. Factions do not by themselves unify actor behavior

The faction proposal above is necessary, but `_faction_of()` and `_opposes()` would still leave parallel implementations for player and enemy condition buildup, damage, posture, interruption, displacement, Gale velocity and projectile ownership. The player would be faction-aware without yet being handled as an actor by the systems that apply effects.

Enemy collection mutation also has a hidden maintenance contract. Tests that append or replace enemies repeatedly call `_invalidate_active_enemy_cache()` and sometimes `_build_enemy_spatial_index()` themselves. One Air Caster test explicitly explains that `_nearby_enemies` does not force a rebuild. Any production path that changes membership or position without maintaining the same caches can query stale actors.

**Sol 5.6 proposal for Opus to evaluate.** Introduce a bounded shared actor interface or adapter used by damage, conditions, posture and impulse resolution. It should expose actor ID, position, radius, faction and the operations those systems need without requiring an immediate merge of the player scalars and enemy dictionaries.

Central actor-repository methods such as `add_actor`, `remove_actor` and `set_actor_position` should own stable IDs, spatial buckets and cache invalidation. A complete player/enemy storage rewrite is not required to gain these benefits and would be considerably riskier.

**Risk:** medium-high if attempted wholesale; medium if introduced one resolution boundary at a time. **Value:** high, particularly before allies, summons or more faction-neutral effects are added.

---

## C5. Save compatibility needs an explicit migration pipeline

Save/load participates in the duplicated-field problem, but it is not the same surface as presentation. Presentation contains interpolated and derived visible state. A save contains authoritative internal state and migration history while deliberately omitting deterministically reconstructed geography. Having all writers literally walk one undifferentiated list could persist transient data or expose hidden state to rendering.

`load_run()` currently accepts a list of old versions, assigns current fields directly with defaults, and performs special cases inside the hydration sequence. As the schema grows, a default can conceal both a legitimate old field and an accidentally forgotten current field.

**Sol 5.6 proposal for Opus to evaluate.** Either give a shared field registry explicit audience flags (`snapshot`, `presentation`, `save`) or maintain separate checked schemas derived from common descriptors. Normalize old payloads through sequential migrations from version N to N+1, validate the resulting current payload, and only then hydrate the run. Each migration should have a focused compatibility test.

**Risk:** medium. **Value:** high over the lifetime of the project; it separates compatibility policy from ordinary state restoration.

---

## C6. Tests need one owner for each behavioral contract

The current suite contains a concrete example of superseded behavior surviving in a second test. `run_state_test.gd` expects `_resolve_gale()` to move light bodies immediately. `mage_elementalist_test.gd` tests the current design: Gale imparts velocity at impact and bodies move over later simulation ticks. Those assertions cannot both describe the same contract.

The full suite also currently retains the previously known clean-opening and late-sidestep failures. A golden baseline recorded while behavioral expectations are contradictory would canonize uncertainty rather than protect behavior.

**Sol 5.6 proposal for Opus to evaluate.** Assign each behavior one canonical contract test. Broader integration suites should test their boundary or outcome instead of duplicating internal timing semantics. When a mechanic intentionally changes, audit and remove or revise assertions that describe its superseded form. Establish a green baseline, or an explicit temporary expected-failure ledger, before recording golden runs.

**Risk:** low. **Value:** high because structural refactors are only as safe as the contract they preserve.

---

## C7. Current version metadata still has several sources

The current game version is repeated in `run_state.gd`, the README heading and release text, Android export metadata, and Windows file/product metadata. Project instructions require these values to remain synchronized manually. This is a small instance of the same multi-site fact problem.

**Sol 5.6 proposal for Opus to evaluate.** Establish one machine-readable current-version source and make export/build validation consume or check it. Human-authored release history should remain human-authored; only the current version fields need generation or a consistency test.

**Risk:** low. **Value:** modest, but the implementation is cheap and removes routine release drift.

---

## Sol 5.6 refinements to the original six proposals

These are proposed amendments for Opus to consider, not objections to the original direction.

### Snapshot writers

Use audience-specific schemas or explicit audience flags rather than making save and presentation literally identical. Required-field contract tests should prove that each consumer receives its declared surface. Presentation interpolation and save migration remain distinct policies.

### Per-kind catalog data

Moving the fields is only half the protection. Remove silent Blade/frontline fallbacks for authored IDs and run a complete catalog integrity validator. Optional presentation text may have a harmless display fallback; simulation identity should not.

### Cooldowns

Use stable slot constants and accessors around the proposed dictionary. Otherwise named scalar variables become stringly typed keys that can still be misspelled in saves or the HUD. The registry should also describe which UI slot an ability occupies and which clocks or rules advance it.

### Occupancy

A single boolean with `ignore_bodies` is likely to grow additional bespoke flags. Placement, endpoint movement, swept movement, Vault, Windstep, Gale and intentional body crossing need different policies. Prefer a pure structured query returning a blocking reason and blocking object or actor ID. Telemetry can consume the result without the spatial query itself mutating survey counters.

### Factions

Pair factions with the shared actor/effect boundary proposed in C4. Allegiance answers who may affect whom; it does not by itself universalize how damage, conditions, posture and impulses are applied.

### Survey counters

The registry needs more than `{name: default}` because counters include scalars, arrays and dictionaries, and some are cumulative while others are room deltas. A descriptor should state scope, default factory, aggregation/difference policy and report formatting. The plumbing can then be generated without forcing unlike measurements into one arithmetic rule.

### Golden-run harness

Hash a canonical authoritative projection rather than a raw Dictionary or presentation snapshot. Sort keys, include RNG and dynamic authoritative state, exclude caches and performance/presentation data, and define stable float handling. Record named checkpoints or semantic component hashes as well as the final hash so a failure identifies what diverged instead of returning only one opaque mismatch.

---

## Sol 5.6 proposed ordering for Opus to evaluate

This ordering is offered for comparison with the original **4 → 2 → 6 → 3 → 1 → 5** sequence. It is not approved or scheduled.

1. Resolve contradictory tests and explicitly account for any temporary expected failures.
2. Build the canonical, checkpointed deterministic harness.
3. Add catalog and runtime-schema validators without changing gameplay.
4. Establish the canonical ability/action/effect definitions.
5. Introduce the structured occupancy query and central actor mutation methods.
6. Move the remaining per-kind facts into the validated enemy catalog.
7. Universalize survey descriptors and cooldown slots.
8. Give dynamic presentation entities stable IDs and enforce a single dynamic frame authority.
9. Introduce sequential save migrations and checked save/presentation audiences.
10. Expand faction handling through the shared actor/effect-resolution boundary.

As in the original audit, mechanically splitting `run_state.gd` should not be the first move. These changes should create real ownership boundaries first; files can then shrink along those boundaries instead of becoming several smaller modules with the same hidden coupling.

---

# Third audit — a boundary is not a representation

**Recorded:** 2026-09-02, against `0.2.78`. Prompted by a Chanter legibility bug that turned out to be structural rather than cosmetic.

**Note on scope:** this audits the structure `0.2.75` shipped, three versions after it landed and with every accepted item of the first two audits in source. That is the point of it. These are not defects the refactor left undone — they are defects it passed over while looking directly at them, which is why the *why it was missed* section below matters more than the findings list.

## The bug that started it

Chant marks — haste, bulwark, ward, each with an authored colour and a distinct shape so the colour is never load-bearing — have never once been drawn. `_draw_chant_marks()` is correct and is called correctly. It reads `enemy.get("chants", {})` from the dictionary the renderer was handed, and that dictionary is built by `_enemy_presentation()`, a hand-written list of seventeen keys. `chants` is not one of them, so the function returns on its first line, every frame, in every room, since it shipped.

Enemy `conditions` — burn and frost — are missing from the same list, and have no drawing code at all. The Elementalist's entire payload is invisible on the target it is applied to.

## The root, which is one line

`_actor_storage()` is the function whose stated job is *give me this actor's state* (`run_state.gd:3472`):

```gdscript
func _actor_storage(actor: Variant) -> Dictionary:
	if actor is Dictionary: return Dictionary(actor)
	var actor_id := int(actor)
	return {} if actor_id == 0 else _enemy_by_id(actor_id)
```

**For the player it returns nothing.** Enemy state is a dictionary; player state is thirty-two `var player_*` scalars on `RunState`. There is no shared representation, so every actor-generic function in the boundary is a translation layer, and each one has to branch:

| function | player branch | enemy branch |
|---|---|---|
| `_change_actor_hp` | `player_hp` clamped inline | `storage["hp"]` |
| `_apply_actor_posture_damage` | `player_posture` **and** `player_posture_recovery_delay` inline | delegates to `_apply_posture_damage` |
| `_set_actor_impulse` | `player_gale_velocity` | `storage["gale_velocity"]` |
| `_apply_actor_condition_buildup` | `apply_player_condition_buildup` | `apply_enemy_condition_buildup` |
| `actor_view` | seven fields assembled by hand | seven fields read from storage |
| `_faction_of` | literal `"player"` | `storage["faction"]` |

Note the asymmetry in the posture row: the player's recovery delay is authored *inside the boundary function* and the enemy's is not, so the two already differ in more than storage.

The condition row is the one that broke. It is a **dispatcher**, not a generalisation — one name over two complete implementations, one of which grew accessors, a fraction, a meter and a renderer while the other grew none of those things. It is also, literally, the line `CLAUDE.md` forbids:

> A rule about who an effect may touch → `_faction_of()` / `_opposes()` / `actor_view()` — **never `if actor_id == 0`**

## Why the second audit did not find it

The second audit was thorough, and it was executed in full: `0.2.75` genuinely built the catalogs, the schema, the cooldown slots, the occupancy predicate and the actor boundary. It found the invisible Earth Wall by exactly this kind of reasoning. So the interesting question is not whether it was careless — it was not — but why a pass explicitly hunting duplicated state walked past a dispatcher over two condition systems.

Three reasons, and all three are reusable.

**1. It unified the verbs and left the nouns split.** `_change_actor_hp(actor, -damage)` reads as finished from every call site. So does `_apply_actor_condition_buildup(actor, id, amount)`. An audit that greps for *duplicated call sites* finds nothing, because there is exactly one call site. The duplication is behind the door, and the door looks shut.

The distinguishing question is not *"is there one entry point?"* but **"is there one representation?"** A boundary over an unshared representation is a place duplication is guaranteed to accumulate, because every new per-actor fact costs a new branch in a new `_x_actor_y()`. Conditions is what that looks like after a few rounds.

**2. The schema's scope stops at the top level.** `state_field_schema.gd` contains **zero** occurrences of the string "enemy". It governs top-level `RunState` scalars — which is precisely why `barriers` was found and fixed in that pass, and precisely why the per-enemy projection was not looked at. The instrument built to prevent field-drop bugs cannot see the nested case.

**3. Tests assert behaviour, and both implementations behaved.** Nothing was wrong with either condition system on its own. The defect is an *absence* — one of them never acquired a presentation. No assertion fails on an absence nobody wrote.

## The three shapes, stated generally

**Shape A — a boundary over an unshared representation.** One actor-generic function name; two storages behind it. Recognisable by a branch on identity (`actor_id == 0`) inside something whose signature promises not to care.

**Shape B — a hand-listed projection.** A dictionary literal that enumerates fields for a consumer. Adding a field elsewhere does not add it here, and the failure is silent: no error, no warning, just something absent from the picture.

**Shape C — a capability expressed as an identity.** A rule gated on `kind == "shield"` rather than on a property the archetype carries. Correct until a second kind needs the same capability, then quietly wrong.

## Findings

### Shape A — boundaries over split state

| # | Where | What |
|---|---|---|
| A1 | `_actor_storage` `run_state.gd:3472` | Returns `{}` for the player. **The root of every row below.** Giving the player a storage dictionary of the enemy's shape collapses the whole boundary into field access. |
| A2 | `_apply_actor_condition_buildup:3509` → `apply_player_condition_buildup:5196` / `apply_enemy_condition_buildup:5225` | Dispatcher over two implementations. Enemy conditions have no accessor, no fraction helper, no renderer. |
| A3 | `_apply_actor_posture_damage:3512` | Player branch also owns `player_posture_recovery_delay`; the enemy branch has no equivalent. The two posture models have already diverged. |
| A4 | `_player_personal_tempo:2618` / `_enemy_personal_tempo:2960` | The same concept, twice, for the two actor types. |
| A5 | `_set_actor_impulse:3519` | `player_gale_velocity` vs `storage["gale_velocity"]` — one concept, two storages, which is what A1 forces. |

### Shape B — hand-listed projections

| # | Where | What |
|---|---|---|
| B1 | `_enemy_presentation:9645` (17 keys) vs `PresentationFrame._copy_enemy` (13 keys) | **Two independent hand-written enemy projections that must agree, and already do not.** The streamed path is missing `revealed_to_player`, `revealed_elapsed`, `attributes`, `weapon_frame`, `equipped_weapon_art`. None are read by the renderer today, so this is latent — but the moment one is, it will work in frozen time and fail during movement, which is the exact Earth Wall signature and the hardest shape to catch. |
| B2 | `PresentationFrame.blend()` | `capture()` gets its scalars from the schema; `blend()` hand-lists the same keys in three literal arrays. A field added to the schema is captured and then dropped during blending. **The bug the schema was built to prevent, surviving in the sibling function.** |
| B3 | `chants`, `conditions` | Missing from both enemy projections. B1 and B2 are why fixing one of them would not have been enough. |

The fix for all three is the same: a per-enemy field schema alongside the top-level one, with both projections and `blend` generated from it rather than transcribed.

### Shape C — capabilities written as names

Eleven rules in `run_state.gd` gate on an enemy's name rather than on a property:

| Capability | Gated on | Sites |
|---|---|---|
| Blocks incoming from the front | `kind == "shield"` | `6105` |
| Parry and riposte | `kind == "duellist"` | `6128`, `6138` |
| Ambush / opens unrevealed / `dodge_strike` | `kind == "bandit"` | `2496`, `2975`, `5837`, `6166`, `6843`, `6851`, `7712` |
| Fires a firebolt rather than an arrow | `kind == "fire_caster"` | `8080` |

`combat_catalog.gd` **already has the home for these** — a `properties` block, currently carrying `armor`, `fire`, `ice`, `mass`, `offhand` and `vision_range`. `mass` is the model to copy: `PUSHABLE_MASS` is one line deciding what can be shoved, and no rule anywhere asks whether something is an Ox. Every row above should become a property.

The Shieldbearer is the live case. `_enemy_blocks_incoming` is otherwise an exemplary generalisation — its comment records being widened from melee-only after a survey found a screen that did not screen arrows — but it still opens with `if kind != "shield": return false`, so a Knight cannot raise a guard and neither can either unbuilt boss.

`game_board.gd` carries **85** `kind == "…"` branches. Many are legitimate — drawing a silhouette *is* identity — but this is the file where CLAUDE.md already records "a cone drawn as a circle, a caster drawing a bow it does not carry", and the count is worth a pass of its own rather than a line in this table.

### Shape C, second instance — a rule wired to one caller

`_archer_has_clear_lane()` (`7545`) refuses a shot with an ally on the firing line. It is called from **exactly one place**: the archer's branch at `7215`. The Javelineer does not check. Neither does any caster.

The projectile loop then justifies its friend-blind collision rule *by* that check (`run_state.gd:8447`):

> "This is safe because `_archer_has_clear_lane()` already refuses a shot with an ally on the firing line — archers aim around their own people — so friendly fire happens only when something changes AFTER commitment: a shot is bent, or a body walks into the line."

**The source states an invariant that is true for one enemy kind and false for every other.** This is Shape C at its most expensive: not a missing feature, but a documented guarantee the code does not provide, being used to justify a second rule.

Two changes make the comment true: give every shooter the check, and evaluate it at **release** rather than at decision — the archer's own 0.60s wind-up is ample time for a Boar to walk into a lane that was clear when it committed.

### Adjacent finding — spawn settling has no body term

`_survey_settle_spawn()` (`1740`) resolves each body against obstacles, the player and the arena rim, **with no term for other bodies**. Both of its rules collapse toward common points: anything near an obstacle is pushed to `centre + away × (size × 0.72 + 90)`, and anything inside 360 of the player is pushed out to exactly 360. Three bodies shoved off one central obstacle land on one arc at one radius.

This is why enemies arrive huddled in arenas like `central_cover` regardless of the formation chosen — the formation authors the spacing and the settler destroys it. Its neighbour already admits the failure mode: *"a formation whose seats all need pulling in arrives squashed against the edge."* It needs a separation pass against already-placed bodies.

## What this changes about how to audit

The second audit asked *"where does the source repeat itself?"* and found real duplication. This one came from a rendering bug and landed on a representation problem three layers down.

The question that would have found it:

> **For each fact an actor can carry, how many places must agree, and is there a mechanism that makes them agree — or only a convention that they should?**

By that test: HP is fine (one boundary, two shallow branches). Conditions were not. The enemy projection is not, twice over. The firing-lane rule is not, and says so in a comment.
