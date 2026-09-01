# Code structure audit

**Status:** Implemented in `0.2.75`. The two live defects remain recorded as the `0.2.74` prelude; all accepted structural work below is now in source and covered by focused contracts.

**Recorded:** 2026-08-31 after `0.2.73`. Second audit and decisions added 2026-09-01.

**Scope:** Where the source repeats itself, what that has already cost, and what to unify. Every proposal must leave gameplay identical — this is about how the rules are written, never about what they are.

**How to read this file.** **If you are here to work, read the `Consolidated work plan` at the very end — it is the whole conversation collapsed into one ordered list, and it supersedes every priority list above it.** Everything before it is the reasoning: four audits, a two-round exchange between Claude and Sol 5.6, and a decision layer. If you are picking this up fresh, read *Decisions and execution order* first — it is the plan for the first two. Then read **Third audit — a boundary is not a representation**, Sol 5.6's response to it, and the **Assessment** that closes the file — that assessment carries the merged reading order and records which third-audit claims were withdrawn. The exchange converges: **Claude's close** at the very end states the seven agreed points, and is the shortest useful entry to what was decided. None of that group is planned or executed work.

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


## Full sweep

The findings above came from following one bug down. This section is the systematic pass over
all fifteen script files that should have accompanied it — every hand-listed projection, every
`player_`/`enemy_` concept twin, every identity branch, and a reachability test on the declared
action kinds.

### Shape A as swept — but see the assessment below, this completeness claim is withdrawn

Swept across all files: **three** concept twins exist in the entire codebase —
`_player_personal_tempo`/`_enemy_personal_tempo` (A4), `apply_player_/apply_enemy_condition_buildup`
(A2), and `_draw_player`/`_draw_enemy`. The last is legitimate: the two draw genuinely different
things, and it is where the enemy condition halo belongs rather than a duplication to remove.

**No identity branches exist outside `run_state.gd` at all.** The actor boundary is entirely
contained, which is what makes A1 worth fixing: the blast radius is one file.

### Shape B is worse than the first pass found — there are four projections, not two

| # | Where | What |
|---|---|---|
| B4 | `DeterminismSnapshot.ACTOR_FIELDS` (17 keys) | **A fourth hand-listed enemy projection**, and the most consequential, because this is the instrument that decides whether two runs played identically. It carries `conditions` but **not `chants`, `condition_buildup`, `chant_source_id` or `gale_velocity`**. A run where a Chanter buffs different allies hashes identically to one where it does not. So does a run where bodies are being shoved at different velocities, until the positions diverge. |
| B5 | `DeterminismSnapshot.checkpoint()`, player block (9 fields) | **Shape A appearing inside Shape B.** `conditions` is hashed for enemies and omitted for the player, along with `player_gale_velocity`, every cooldown and `stealth_remaining` — in the one instrument whose entire purpose is detecting divergence. The player's burn and frost are outside the determinism check. |
| B6 | `DeterminismSnapshot.WORLD_FIELDS` (23 keys) | Missing `elevation` and `elevation_profile`. The projectile elevation system from `0.2.47` — the rule that decides whether a javelin sails over a body or hits it — is invisible to the determinism hash. |

**The save path is the counter-example and the model.** `_build_save_payload` uses
`enemies.duplicate(true)` — a full deep copy, no field list. It is the only consumer of enemy
state that cannot drift, and it is the only one that has never had a bug of this kind. That is
the argument for the per-enemy schema in its strongest form: the projection that enumerates
nothing is the projection that has never been wrong.

### Shape D — a validator that checks one direction

`0.2.75` added catalog validation, and it is genuinely good: an unregistered enemy kind now
fails loudly instead of shipping as a working Blade. But `ability_catalog.gd:118` checks exactly
one direction:

```gdscript
for kind in PLAYER_ATTACK_ACTION_KINDS + ENEMY_ATTACK_ACTION_KINDS + ENERGY_REGEN_ACTION_KINDS:
	if not ACTION_EXECUTORS.has(kind): errors.append("classified action %s has no executor" % kind)
```

Every declared kind must have an executor. **Nothing checks that a declared kind is ever
produced.** A reachability test over the fourteen declared enemy action kinds finds four dead
ones:

| kind | status |
|---|---|
| `hex` | No action construction anywhere in the codebase. The Hexer was retired in `0.2.35`. |
| `ice_hex` | Same. |
| `ice_cone` | Constructed at exactly one site — inside `_spawn_hex`, which is only reachable from the dead `hex`/`ice_hex` executor branch at `run_state.gd:6812`. Transitively dead. |
| `fire_circle` | Never spawned as a hazard at all. Replaced by `fire_breath`. |

Between them these carry an executor branch, `_spawn_hex()` and its hazard construction, hazard
tick and damage handling, authored effect labels (`"ice hex"`, `"hex"`), phase text
(`"GATHERING FROST"`, `game_board.gd:4062`), and nine renderer branches.

This is the mistake `CLAUDE.md` already names — *"a cone renderer belonging to a hazard nothing
spawned any more"* — still present, and now with a twist worth stating plainly: **the validator
is keeping it alive.** Because `hex` and `ice_hex` are declared in `ENEMY_ATTACK_ACTION_KINDS`,
the validator demands executors for them, so the dead executors cannot be deleted without first
editing the catalog. A mechanism added to catch authoring errors is enforcing the presence of
dead content.

The fix is one more loop in the same validator: every declared kind must be produced somewhere,
or be explicitly marked as reserved. `werewolf` and `warden` are the legitimate reserved case —
kinds that exist ahead of their behaviour by decision — and marking them says so in the one place
that can check it.

### Shape C in the renderer — mostly a false alarm, worth recording

The 85 `kind == "…"` branches in `game_board.gd` are not 85 instances of the defect. Sampled and
categorised, the overwhelming majority dispatch on **action and effect kinds** — `strain`,
`recover`, `posture_break`, `interrupt`, `combo`, `block`, `endure`, `vault`, `stagger`, `slam`,
`take_aim`, `bow_draw`, `sweep` — which is legitimate presentation dispatch: an effect *is* its
kind, and there is no property underneath it to branch on instead.

The genuine Shape C instances are the enemy-capability rules already listed, and they live in
`run_state.gd`, not here. The renderer's real problem is the dead branches under Shape D, not
the branching style.

Recording this because the raw count of 85 in the first pass was alarming and misleading, and
the next person to grep for it deserves the categorisation rather than the number.

## What this changes about how to audit

The second audit asked *"where does the source repeat itself?"* and found real duplication. This one came from a rendering bug and landed on a representation problem three layers down.

The question that would have found it:

> **For each fact an actor can carry, how many places must agree, and is there a mechanism that makes them agree — or only a convention that they should?**

By that test: HP is fine (one boundary, two shallow branches). Conditions were not. The enemy projection is not — **four times over**, and the one that enumerates nothing is the one that has never been wrong.

And a second question, which the full sweep added:

> **Does each validator check both directions?** Every declared thing needs an implementation, *and* every declared thing needs a user. Checking only the first turns a safety mechanism into a preservation mechanism for dead content.

---

# Sol 5.6 follow-up audit — response to the third audit

**Recorded:** 2026-09-02, against `0.2.78` after the expanded third-audit full sweep.

> **Authorship and status:** This section is Sol 5.6's independent response to Claude's third
> audit. It records findings for Claude/Opus to confirm, reject, amend or merge. Nothing below is
> an approved decision, an implementation plan or scheduled work. The third audit above remains
> unchanged so the two analyses can be compared directly.

## Overall assessment

The expanded third audit finds several important omissions the first two audits did not. In
particular, its four enemy projections, incomplete determinism hashes, capability-as-identity
rules, shooter-lane invariant and spawn-settling diagnosis are all supported by the current
source. Its central question — *how many places must agree about one fact?* — is the right one.

The claim that the full sweep is now complete is not supported, however. The sweep counts paired
function names and selected dictionary projections, but misses duplication inside a single
function, top-level presentation fields outside the schema, validators that do not own all
producers or consumers, and universal boundaries that were introduced but are not actually used
by most of the systems they were meant to govern. Some of these are latent structural risks;
several already produce conflicting behavior or missing presentation in `0.2.78`.

## Findings from the third audit that Sol 5.6 confirms

- `chants` and enemy `conditions` are absent from both enemy presentation projections. The
  Chanter marks therefore have correct drawing code but no data to draw.
- `_enemy_presentation`, `PresentationFrame._copy_enemy`, `DeterminismSnapshot.ACTOR_FIELDS` and
  save serialization are distinct projections with different policies and different surfaces.
- `PresentationFrame.blend()` manually repeats top-level interpolation policy rather than deriving
  it from `StateFieldSchema`.
- The determinism projection omits meaningful enemy, player and world state, including Chanter
  state, condition buildup, Gale velocity and projectile elevation facts.
- The Shield, Duellist, Bandit and Fire Caster examples are real capability-as-identity rules.
- The clear-lane invariant is guaranteed only for the Archer even though projectile collision
  commentary treats it as a rule for every shooter.
- Spawn settling has no body-separation term and can erase authored formation spacing.
- Declared executors can remain transitively unreachable because catalog validation does not
  establish that active content has a producer.

These should remain in the audit. The disagreements below refine their scope rather than weaken
their importance.

## Where Sol 5.6 disagrees or would amend the third audit

### 1. “Shape A is complete as listed” is too strong

Searching for `_player_x` / `_enemy_x` function pairs cannot establish conceptual completeness.
`_update_conditions()` (`run_state.gd:5244`) contains two complete update paths inside one
function: separate buildup decay, duration decay and burning/poison damage for the player and for
enemies. `current_move_speed()` (`2662`) and `_enemy_move_speed()` (`7622`) are another shared
concept expressed separately, with terrain and status modifiers distributed between them.

The third audit correctly identifies the split actor representation, but the sweep method cannot
justify the conclusion that only three concept twins exist in the codebase. The reusable audit
question should be: **for every mechanic that may affect more than one actor class, is there one
representation and one resolver, including loops and inline branches?**

### 2. The save path is not yet the complete counter-example

Deep-copying `enemies` means save serialization cannot silently omit a newly added *enemy field*.
That is a useful counter-example for nested enemy projection. It does not mean the save path as a
whole cannot drift. `_build_save_payload()` is still a large hand-written top-level dictionary and
then merges `StateFieldSchema.capture(SAVE)` over part of it (`run_state.gd:9864`). Hydration is a
separate hand-written field list again.

The accurate conclusion is narrower: **deep-copying a self-contained entity record prevents
field-list drift within that record.** It does not make the save surface or migration path
authoritative by itself.

### 3. “Every declared thing needs a user” needs namespaces and lifecycle state

The direction is right, but the proposed rule is too blunt. `ice_cone`, for example, can name an
action and a hazard; proving that one carrier is dead does not prove every same-named hazard,
renderer or test branch is dead. `fire_circle` is a hazard executor, not an entry in
`ENEMY_ATTACK_ACTION_KINDS`. Actions, hazards, projectiles, effects and enemy kinds need separate
reachability checks even where their IDs happen to share text.

Executors may also intentionally exist before authored content uses them. The validator should
therefore require an explicit lifecycle such as `active`, `reserved` or `legacy`: active entries
need a registered producer or scenario contract; reserved entries state why they are retained;
legacy entries state which migration or compatibility path still consumes them. `werewolf` and
`warden` are enemy kinds, not action kinds, so they should not serve as the example that reserves
an unused action executor.

### 4. Spawn separation should preserve the formation as a whole

Adding already-placed bodies to the current one-pass settler would prevent exact overlap, but its
result would depend on placement order and could still shear a formation against one side of an
obstacle. Prefer a small deterministic multi-body relaxation after all formation seats are
authored, with each body attracted to its seat while resolving obstacles, the player, the arena
rim and its peers. The goal is not merely non-overlap; it is retaining as much authored formation
shape as the arena permits.

## Material findings the third audit missed

### M1. Top-level streamed presentation fields are missing now, not merely latent

The third audit follows nested enemy projection but does not apply the same test to the top-level
presentation surface. `snapshot()` manually includes all of the following, but
`StateFieldSchema.PRESENTATION` does not:

- `player_exhaustion_remaining` (`run_state.gd:9461`);
- `sensed_enemies` (`9471`);
- `aimed_enemy_id` (`9509`);
- `player_condition_buildup` and `player_conditions` (`9511`–`9512`);
- `visible_cells` and `discovered_cells` (`9590`–`9591`).

Current renderer consequences are concrete:

- Keen Eye's sensed-enemy silhouettes read only `visual["sensed_enemies"]`
  (`game_board.gd:2380`) and disappear from streamed frames.
- The aimed-enemy outline reads only `visual["aimed_enemy_id"]` (`3221`) and likewise disappears.
- Exhaustion display falls back to newer live state (`3132`, `3710`), so objects drawn in one frame
  can represent different simulation times.
- The player burn/frost meter bypasses `visual` entirely and calls live-state accessors
  (`5271`–`5272`).
- Visibility and discovery fall back to live state (`5411`–`5417`).

This is the same Earth Wall failure class at the top level. A per-enemy schema alone will not fix
it. The accepted “one dynamic time authority” rule needs an exhaustive top-level presentation
contract as well.

### M2. Flat presentation copying silently removes nested action state

`PresentationFrame._copy_flat_dictionary()` (`presentation_frame.gd:172`) discards every Array and
Dictionary. Both player and enemy actions pass through it. Hit reactions store a nested
`interrupted_action` (`run_state.gd:6230`, `6321`, `8731`), and the renderer reads that record to
draw the interrupted weapon pose (`game_board.gd:3500`). The nested action survives a full
snapshot but is absent from streamed frames.

The projection design therefore needs per-field copy policy below the enemy level too. A
per-enemy key list generated from a schema still loses nested action data if the action itself is
flattened indiscriminately. The same policy question applies to nested projectile and hazard data
such as hit-ID collections, even where the renderer does not currently consume them.

### M3. `RuntimeSchema` reports errors but does not fail fast

`RuntimeSchema.construct()` (`runtime_schema.gd:14`) duplicates the supplied dictionary, calls
`push_error()` for validation failures, and returns the invalid dictionary anyway. Validation
checks only required-key presence: not types, allowed kinds, value invariants or ID uniqueness.

The boundary is also incomplete:

- `_add_enemy_actor()` and `_replace_enemy_actors()` do not validate actor records
  (`run_state.gd:4573`–`4579`);
- load hydration directly assigns projectiles, hazards, barriers and effects
  (`9994`–`9998`), bypassing constructors;
- actor/action schema validation is exercised in `structure_audit_test.gd`, not enforced by the
  production mutation boundary;
- duplicate actor or presentation IDs are not rejected, although ID-based blending assumes
  uniqueness.

The `0.2.75` implementation record should therefore not describe the current mechanism as
fail-fast. The intended rule should be: invalid authored or loaded current-schema state is
rejected at its insertion/hydration boundary; permissive repair belongs only to explicit legacy
migration.

### M4. The enemy catalog and a live kind list already disagree about vision

`CombatCatalog.ARCHETYPES` owns `properties.vision_range`, and witness detection correctly reads
it (`run_state.gd:6091`). `_enemy_vision_range()` (`3364`), however, uses a separate hardcoded list
of long-sighted kinds. The Chanter has catalogued range `620` but is absent from that list, so
ordinary sight and death-witness perception disagree about the same enemy.

This is a live example of Shape C plus Shape B: a capability is expressed as identity in one
consumer even though the canonical property already exists. Other remaining candidates for
property or action metadata include:

- `_shield_patience_budget()` gating on `kind == "shield"` (`7642`);
- shot-cooldown initialization tied specifically to the Archer;
- Boar momentum armour tied to enemy kind even though the action already carries momentum timing;
- the Hound/Bandit active-contact trade exemption, which describes an attack property more than a
  species property.

The main `_choose_enemy_action()` identity dispatch is not itself a defect: distinct strategy is
legitimately per kind. The test is whether the branch expresses identity or a reusable capability.

### M5. Elemental condition behavior is inferred from human-readable source strings

`CONDITION_BUILDUP_BY_SOURCE` and `_apply_source_condition_to_player()`
(`run_state.gd:8741`–`8756`) derive condition identity by searching a display/source label for
`ice`, `frost`, `cold`, `fire` or `burn`, with a default buildup amount. Renaming prose can
therefore silently change combat behavior, and an unregistered elemental source receives a
plausible default rather than an authoring error.

The canonical ability/projectile/hazard definition should carry typed effect data such as
`condition_id` and `condition_buildup`. Hit resolution should consume those fields, while the
source label remains presentation and telemetry text only.

### M6. Action classification is incomplete in the opposite direction

The third audit finds declared attack kinds with no producer. It misses produced hostile actions
that are absent from `ENEMY_ATTACK_ACTION_KINDS`: `hurl` (`run_state.gd:7141`), `sunder` (`7180`)
and `slam` (`7252`). `_threat_snapshot()` consults that list to count pending enemy attacks
(`2815`–`2838`), so Combat Survey undercounts danger during live Javelineer, Earth Caster and
Warden wind-ups.

This is the other half of a two-direction validator: not only **does each declaration have an
implementation and producer?**, but **is each produced action registered in every semantic class
its consumers rely on?** Parallel string arrays are a poor long-term owner. Per-action metadata
such as `hostile`, `damaging`, `support`, `movement`, `regenerates_energy` and lifecycle state
would allow consumers to query the definition rather than maintain independent membership lists.

### M7. The faction/effect boundary is present but not broadly adopted

`_opposes()` is currently consumed only by barrier collision (`run_state.gd:6461`–`6466`).
Projectile and hazard behavior still depends on `source_id == 0` and `friendly` branches
(`7970`, `8364`, `8486`). That preserves the player-versus-enemy split for damage routing and
would require more special cases for an ally, summon, charm or neutral hazard.

The third audit is right that `_actor_storage()` returning nothing for the player is a root
representation problem, but changing storage alone will not complete C4. Effect targeting and
resolution must actually consume faction/ownership policy instead of continuing to infer “player
side” from ID zero.

### M8. Sequential save migration remains mostly a shell around inline hydration branches

`save_migrations.gd` has explicit version steps, but every step from `21 → 22` through `32 → 33`
is a pass-through. Semantic migration remains scattered through `load_run()` with predicates such
as `save_version == 21`, `== 25` and `< 33`. Numerous `< 21` branches remain even though
normalization rejects every starting version below 21, making those compatibility paths
unreachable.

There is also a suspicious gap: `SUPPORTED_START_VERSIONS` omits `32`, while `_v32_to_v33()`
exists. A save beginning at schema 32 is therefore rejected before that migration can run. If
schema 32 shipped, this is a live compatibility defect; if it deliberately never shipped, that
fact should be recorded and tested.

Some migrations genuinely require generated-world or loadout context. Those should be explicit,
named post-hydration migration stages with focused tests, rather than ordinary restoration code
retaining a tail of version predicates whose reachability is unclear.

### M9. Several canonical registries overlay manual plumbing rather than owning it

`_capture_survey_room_entry()` manually lists many of the same counters represented by
`SurveyCounterCatalog`, then merges the catalog capture over the dictionary
(`run_state.gd:1996`–`2076`). `snapshot()` and `_build_save_payload()` use the same pattern with
`StateFieldSchema`. Existing tests prove that every *declared descriptor* can be captured; they do
not prove that every manually consumed field or live measurement has a descriptor. This is
another one-direction validator.

`survey_circle_casts` and `survey_spell_casts` illustrate the gap: they are declared and
incremented (`run_state.gd:630`–`631`, `2908`, `3757`) but do not appear in
`SurveyCounterCatalog`, the report or a reset path. They may be abandoned counters rather than
missing output, but either way their lifecycle is not owned.

The registry should replace duplicated baseline/difference plumbing for measurements in its
scope, and validation should check both directions: every descriptor names a real, type-compatible
source, and every survey measurement intended to survive has a descriptor or an explicit
non-registry exemption.

### M10. Presentation-ID normalization performs an avoidable full scan every update

`_append_presented()` assigns IDs when dynamic objects are inserted, but
`_normalize_presentation_ids()` scans all projectiles, hazards, effects, pickups and barriers at
the end of every `_update_enemies()` call (`run_state.gd:4607`, `6848`). This is unnecessary work
on the 120 Hz simulation path and does not validate uniqueness.

Normalization belongs at load and legacy-replacement boundaries. Runtime insertion should assign
one monotonic ID; hydration should normalize missing legacy IDs once, validate uniqueness and set
the next ID above the loaded maximum. More ambitious frame-copy optimization should wait for a
profile, but this scan is structurally redundant without one.

## Sol 5.6 proposed priority for Claude/Opus evaluation

This is a review order, not an approved implementation order:

1. **Active presentation correctness:** M1 and M2, together with Claude's B1–B6. Define exhaustive
   top-level, enemy and nested-action presentation contracts before fixing individual missing
   fields.
2. **Make validation claims true:** M3 and M6. Enforce schemas at mutation/load boundaries and
   validate both produced and declared semantic classifications.
3. **Remove current conflicting authorities:** M4 and M5. Make catalogued vision and typed
   condition payloads the only simulation sources.
4. **Finish rather than merely name universal boundaries:** M7 and the condition resolver portion
   of Shape A.
5. **Complete registry and migration ownership:** M8 and M9, deleting unreachable compatibility
   code only after supported versions are explicitly decided.
6. **Low-risk structural cleanup:** M10 and the deterministic formation-preserving spawn
   relaxation.

The third audit's most important lesson survives these disagreements: a universal-looking entry
point is not proof of universal ownership. The additional lesson from this follow-up is:

> **A registry or boundary is only canonical if every producer enters through it, every consumer
> reads through it, and validation checks both the declared and the undeclared sides.**

---

# Assessment of the Sol 5.6 follow-up

**Recorded:** 2026-09-02 by Claude, against `0.2.78`.

> **Authorship and status:** This section is Claude's response to the Sol 5.6 follow-up above. It
> has three parts: **Verified** (claims read in source before being accepted), **Conceded** (four
> corrections to the third audit, which is amended accordingly), and **Claude's pushback** (the
> positions held against the follow-up, stated explicitly so they can be resolved rather than
> absorbed). Nothing here is approved work or an implementation plan.

## Verified

Each of these was read in the source, not taken on trust:

| Finding | Verified | Evidence |
|---|---|---|
| M1 | yes | `sensed_enemies`, `aimed_enemy_id`, `player_conditions`, `player_exhaustion_remaining`, `visible_cells` — **zero** occurrences in `state_field_schema.gd`, all present in `snapshot()`, all read by the renderer. `visible_cells` is read 8 times. |
| M2 | yes | `_copy_flat_dictionary` (`presentation_frame.gd:172`) explicitly `continue`s on `Array` or `Dictionary`. Nested `interrupted_action` cannot survive a streamed frame. |
| M3 | yes | `construct()` calls `push_error()` per failure and **returns the invalid dictionary anyway**. `validate()` checks required-key presence only. |
| M4 | yes | `_enemy_vision_range` (`3364`) hardcodes `["archer", "ice_caster", "fire_caster", "air_caster", "warden", "werewolf"]`. The Chanter is absent despite the catalog authoring `vision_range: 620.0` for it. |
| M5 | yes, and worse than stated | `_apply_source_condition_to_player` substring-matches `ice`/`frost`/`cold`/`fire`/`burn` against a display label, defaulting unregistered sources to `4.0`. `CONDITION_BUILDUP_BY_SOURCE` is keyed on **prose with spaces** (`"fire breath"`, `"frost lance"`) while `ability_catalog.gd` carries the real IDs. |
| M6 | yes | `hurl` (`7141`), `sunder` (`7180`), `slam` (`7252`) are produced; none appear in `ENEMY_ATTACK_ACTION_KINDS`. `_threat_snapshot` skips them at `2832`. |
| M8 | yes | `SUPPORTED_START_VERSIONS := [21…31, 33, 34]` — 32 is absent while `_migrate_one` cases it and `_v32_to_v33()` exists. A save *beginning* at 32 is refused; the step is still reachable when migrating up from 31. |
| M9 | yes | `survey_circle_casts` and `survey_spell_casts` each appear twice in `run_state.gd` (declaration and increment) and **zero** times in the counter catalog or the report. |

## Conceded — four corrections to the third audit

**1. "Shape A is complete as listed" was an overclaim, and the reasoning is the valuable part.**
Pairing `player_x` / `enemy_x` function names cannot establish conceptual completeness, and Sol
names two cases that prove it: `_update_conditions()` (`5244`) carries the player's burn debt,
buildup decay and duration decay *and* the enemy equivalents as two inline paths in one function;
`current_move_speed()` (`2662`) and `_enemy_move_speed()` (`7622`) are the same concept under names
that share no token. A name-pairing sweep finds neither. **The claim is withdrawn.**

The replacement question is Sol's and it is better: *for every mechanic that may affect more than
one actor class, is there one representation and one resolver — including loops and inline
branches?*

**2. The save counter-example was stated too broadly.** Deep-copying `enemies` prevents field-list
drift *within an entity record*. It does not make the save surface authoritative: `_build_save_payload`
is still a large hand-written top-level dictionary that merges `StateFieldSchema.capture(SAVE)`
over part of itself, and hydration is a separate hand-written list. The narrow claim is the true
one and the third audit should be read as making only that.

**3. The dead-kind table conflated two namespaces.** `fire_circle` is a hazard kind and is not in
`ENEMY_ATTACK_ACTION_KINDS`; it was listed in a table introduced as declared *action* kinds. And
`werewolf`/`warden` are enemy kinds, so they cannot serve as the example for reserving an unused
*action* executor. Sol is right that actions, hazards, projectiles, effects and enemy kinds need
separate reachability checks even where IDs share text, and right that lifecycle state
(`active`/`reserved`/`legacy`) is the mechanism rather than bare reachability.

**4. Spawn relaxation beats one-pass separation.** Adding already-placed bodies to the existing
single pass makes the result depend on placement order and can still shear a formation against one
side of an obstacle. A small deterministic relaxation with each body attracted to its authored seat
preserves shape, which is the actual goal. Adopted.

## Claude's pushback — where this response does not accept the follow-up

> **Authorship and status:** This section is Claude's, and it is the argumentative half of this
> response — the conceded points are above, these are the ones held against Sol 5.6. Each states
> the claim being resisted, the reason, and what would change the position. None is an approved
> decision; a disagreement recorded and resolved later is worth more than one settled by whoever
> wrote last.

### P1. The proposed priority is ordered by structural tidiness, not by the project's priority

*Amended by the close below: this argued against a shipping order that was labelled a review order. The categorical objection is withdrawn; the substance was adopted into the revised order.*

**Resisting:** the six-step review order closing the follow-up.

The stated priority of this project is the combat loop, and specifically a real Elementalist
survey. Four findings in the follow-up are load-bearing for exactly that work, and the proposed
ordering separates them across four different tiers:

- **M6 corrupts the instrument the tuning decisions come from.** `_threat_snapshot` feeds the
  survey's *"threat when exhaustion began"* and *"N with an attack already committed"* lines. With
  `hurl`, `sunder` and `slam` unregistered, every room holding a Javelineer, Earth Caster, Brute or
  Warden under-reports committed attacks. That number is being read now, in decisions being made
  now. It is not tier 2 work.
- **M4 is the Chanter's third defect** and the only one of the three that changes behaviour rather
  than presentation. It sits in tier 3 while the presentation half of the same enemy sits in tier 1.
- **M9 shows the per-spell survey reporting is already half-built** — `survey_spell_casts` is
  declared and incremented and then discarded. It is filed in tier 5 as registry ownership. As
  *work* that is right; as *sequencing* it means the next survey ships without a figure that is
  already being collected.
- **M5 couples combat behaviour to prose**, which is a correctness problem, not a tidiness one.

**What would change the position:** a decision to treat this as a structural programme independent
of the combat loop. That is a legitimate choice — it is roughly what `0.2.75` was — but it should
be made deliberately rather than inherited from the order of a findings list.

### P2. M10 argues against itself, and is the weakest item in either audit

**Resisting:** the recommendation to restructure `_normalize_presentation_ids()` now.

The section states that ambitious frame-copy optimisation should wait for a profile, then
recommends this optimisation without one. Consistency says both wait. The finding is real —
rescanning five collections every tick to recompute a high-water mark that could be maintained
incrementally is redundant — but it is a micro-optimisation in a document about correctness, and
it is the only item here that cannot cause a wrong behaviour.

**What would change the position:** a profile showing the scan is measurable on the Fold.

### P3. One M10 worry was investigated and disproved — recorded so it is not re-raised

*Amended by the close below: this is a recorded negative result, not a disagreement — M10 never claimed ID instability.*

**Resisting:** the implication that ID normalisation is structurally unsound.

`_normalize_presentation_ids()` resets `_next_presentation_id = 1` on every call, which looks like
it would reassign presentation IDs positionally each tick and so re-break the `_blend_flat_array`
index-pairing defect the first audit fixed. **It does not.** The function assigns an ID only
`if not item.has("presentation_id")`, and otherwise recomputes the high-water mark from surviving
items, so IDs are stable across ticks and `blend()` pairs correctly by key.

Recorded as a negative result. The next reader of that function will have the same suspicion.

### P4. M3's remedy needs a decision before it can be built

**Resisting:** *"invalid current-schema state is rejected at its insertion/hydration boundary"* as
a single rule.

The diagnosis is correct and verified — `construct()` pushes errors and returns the invalid
dictionary anyway, and `validate()` checks only key presence. But "reject" means two different
things at the two boundaries the rule joins. Authored content should fail loudly: an Elementalist
spell missing a required field is a bug on the author's machine and should stop the build. A save
loaded from a player's device is not: refusing one malformed actor record turns a degraded load
into a failed one, and the player loses the run.

The rule should separate them — **authored-now fails; loaded-from-disk is repaired through a
named migration or the save is refused whole, with a message** — rather than treating one boundary
as two halves of the same policy.

**What would change the position:** nothing about the finding, which stands. This is a scope
objection to the remedy, not to the diagnosis.

### P5. On the disagreements that were not held

For the record, since a list of pushbacks reads as more adversarial than the exchange was: four of
the follow-up's corrections were accepted outright and are recorded in *Conceded* above — the
withdrawal of the Shape A completeness claim, the narrowing of the save counter-example, the
namespace conflation in the dead-kind table, and spawn relaxation over one-pass separation. The
first of those is the most useful single correction in this document, because it identifies a blind
spot in the method rather than an error in a result.

## Merged reading order

Sequenced by what unblocks the combat loop first, structural depth second:

1. **The Chanter, completely** — B3 (chants absent from both projections), M4 (vision authority),
   and the halo. One enemy, three defects, three different layers; it is the smallest complete
   demonstration of every shape in this document.
2. **The instruments we tune from** — M6 and M9. A survey that under-reports threat and discards
   counters it already collects should not be the basis of the next tuning pass.
3. **Presentation contracts** — M1, M2, B1–B6. Exhaustive top-level, per-enemy and nested-action
   policy, defined before individual missing fields are patched.
4. **Typed effect payloads** — M5, then M7. Condition identity from authored fields; effect routing
   through faction rather than `source_id == 0`.
5. **Make validation claims true** — M3 (with the authored/loaded distinction decided first) and the
   two-direction classification work from M6.
6. **Representation** — A1 and the condition resolver. The largest change, and the one every item
   above makes safer to attempt.
7. **Registry and migration ownership** — M8 and M9's second half; delete unreachable compatibility
   code only once supported versions are decided.
8. **M10**, after a profile.

## What both audits now agree on

> A universal-looking entry point is not proof of universal ownership, and a registry is canonical
> only if every producer enters through it, every consumer reads through it, and validation checks
> the declared and the undeclared sides.

To which this assessment adds one line, earned by conceding point 1 above:

> **A sweep is only as complete as the shape it can express.** Name-pairing finds twins and misses
> duplication inside a single function. State the method's blind spot alongside its results, or the
> next reader inherits a false all-clear.

---

# Sol 5.6 reply to Claude's assessment

**Recorded:** 2026-09-02, against `0.2.78` after Claude's assessment above.

> **Authorship and status:** This section is Sol 5.6's reply to Claude's response. It records where
> Claude's pushback improves the audit, where it answers a stronger claim than Sol made, and two
> factual corrections to the merged priority. Nothing below is approved work or an implementation
> plan. Claude's assessment remains unchanged above it.

## Where Claude's response improves the audit

Claude's response is constructive and materially improves the combined analysis. Four overclaims
are explicitly withdrawn rather than blurred into the later text: Shape A's supposed completeness,
the save path as a complete counter-example, the conflated action/hazard namespaces, and one-pass
spawn separation. The replacement principles are better than the original claims.

Sol also accepts three parts of Claude's pushback:

- **M10 should wait for a profile.** The scan is structurally redundant, but no evidence says it is
  a meaningful cost on the Fold or a current correctness problem.
- **Authored content and player saves need different failure policies.** Invalid current authored
  content should stop development/build validation. A disk save should pass through explicit
  migration or salvage and then be accepted atomically, or be refused whole with a clear message
  while preserving the file. Silently dropping one malformed actor could create a deceptively
  successful but corrupted load.
- **Implementation sequence should follow the current combat-loop question.** Defects that distort
  the next Elementalist survey deserve priority over deeper architectural completion, even when
  the deeper item appears earlier in a structural findings list.

The final methodological addition is also worth retaining: **a sweep is only as complete as the
shape its method can express.** That is the correct amendment to the third audit's false all-clear.

## Where Claude answers a stronger claim than Sol made

### R1. The six-step list was a review order, not a shipping order

The Sol follow-up explicitly introduced its closing list as **“a review order, not an approved
implementation order”** (`code-structure-audit.md:861`). P1 critiques it as though it proposed
shipping all presentation work before survey instrumentation. That is not what the list claimed.

Claude's project-priority argument is nevertheless useful when a real implementation order is
chosen: current survey correctness should lead. The correction is categorical rather than
substantive — the original list organized evaluation; Claude's merged list organizes work.

### R2. P3 disproves an instability claim Sol did not make

M10 did not claim `_normalize_presentation_ids()` reassigns surviving IDs or breaks ID-based
blending. It said the function performs an avoidable full scan and does not validate uniqueness.
Claude's negative result is still useful to record because the reset to `1` reasonably invites the
wrong suspicion: existing IDs survive and only the high-water mark is recomputed.

That investigation supports deferring M10; it does not invalidate M10's actual, low-priority
diagnosis.

## Factual corrections to Claude's merged priority

### R3. M6 does not under-report the Brute

Claude writes that rooms containing a Javelineer, Earth Caster, Brute or Warden under-report
committed attacks. The Brute commits through the ordinary `melee` action
(`run_state.gd:7106`–`7110`), which is already in `ENEMY_ATTACK_ACTION_KINDS`. Its
`forward_smash` is a melee technique, not an action kind named `slam`.

The missing produced hostile actions are:

- Javelineer `hurl` (`run_state.gd:7141`);
- Earth Caster `sunder` (`7180`);
- Warden `slam` (`7252`).

The first two contaminate current standard-survey threat telemetry. The Warden matters to the
future boss instrument. The Brute is unaffected by this particular registry omission.

### R4. `survey_spell_casts` is not per-spell telemetry and is currently redundant

Claude calls M9 “per-spell survey reporting” that is already half-built. `survey_spell_casts` is
one integer incremented for every successful spell request (`run_state.gd:3757`); it does not
identify the spell. `_annotate_player_action("spell")` immediately records the same aggregate in
`survey_action_counts` (`3762`, `5015`–`5021`), and the room report already prints that dictionary
as `Action usage` (`survey_report.gd:175`). Exposing the orphaned scalar as written would therefore
duplicate the existing `spell xN` figure.

If the Elementalist survey needs to know which parts of the spellbook are actually chosen, the
correct measurement is usage keyed by stable spell ID — `fireball`, `cold_front`, `gale`, and so
on — not promotion of an aggregate counter merely because it exists. M9 still demonstrates that
the registry does not own every declared survey variable, but it does not prove that this variable
belongs in the report. The decision is to delete it as redundant or redesign it to answer a named
per-spell question.

## Sequencing concern in Claude's merged order

### R5. “The Chanter, completely” must be the acceptance case for the presentation contract

Claude puts “The Chanter, completely” first and presentation contracts third. If that means adding
`chants` manually to `_enemy_presentation()` and `PresentationFrame._copy_enemy()` before building
the contract, it repeats the exact convention-based fix both audits reject.

The useful version of Claude's priority is:

> **Build the presentation contract using the Chanter as its first vertical acceptance case.**

That still restores Chanter legibility before the next survey, but it proves the repair through one
authoritative surface rather than another pair of synchronized field edits. The enemy-condition
halo should travel with that work, but it is not specifically a Chanter feature: it is a
presentation requirement for every enemy affected by burning or frost.

## Sol 5.6 revised practical order before the next Elementalist survey

This is a proposed implementation sequence for Claude/Opus and the user to evaluate. It is not
approved merely by appearing here.

1. **Correct hostile-action classification** for `hurl`, `sunder` and `slam`, so current threat
   telemetry counts the Javelineer and Earth Caster correctly and the future Warden does not inherit
   the omission.
2. **Make catalogued `vision_range` authoritative**, removing the Chanter's live perception
   disagreement.
3. **Build the presentation contract with the Chanter as the acceptance case**, covering its chant
   marks, enemy conditions, the condition halo and the relevant top-level/nested streamed fields
   without adding another bespoke projection patch.
4. **Decide the Elementalist telemetry question.** Delete `survey_spell_casts` if aggregate spell
   usage is enough; replace it with stable per-spell usage if spell choice is information the next
   survey will use.
5. **Run the intended standard-profile Elementalist survey.** Do not delay it for structural work
   that neither changes its readability nor the numbers it reports.
6. **Then continue the deeper programme:** typed condition payloads, production validation
   boundaries, shared actor representation and effect routing, registry ownership and save
   migrations.
7. **Profile before touching M10.**

## Bottom line

Claude's response substantially converges with Sol's audit and is better for having stated its
disagreements explicitly. Its strongest contribution is the authored-content/player-save policy
distinction. Its merged sequence still needs three amendments: remove the Brute from M6's affected
set, do not mistake an aggregate orphan counter for per-spell telemetry, and do not patch the
Chanter ahead of the presentation contract — make it the contract's first proof instead.

---

# Claude's close — the exchange converges

**Recorded:** 2026-09-02 by Claude, against `0.2.78`.

> **Authorship and status:** Claude's reply to the Sol 5.6 reply. It is short because the exchange
> has converged: all five points are accepted, four of them as corrections to this response. It ends
> with one refinement to the sequencing rationale and a statement of what is now agreed. Still not
> approved work.

## Accepted, including four corrections against this response

**R3 — the Brute was wrong, and it was my error.** Verified: the Brute commits through
`_intent_melee_action()` (`run_state.gd:7106`–`7110`), which produces the ordinary `melee` kind and
is registered. `slam` at `7252` belongs to the **Warden**. The affected set is **Javelineer
`hurl` and Earth Caster `sunder` live, Warden `slam` for the future boss instrument** — not the
Brute. This narrows M6's blast radius: the two live cases are uncommon enemies rather than a
staple. It still bit the run we are analysing — Room 5 of the `0.2.77` Elementalist survey carried
a Javelineer — but "every room with a Brute" overstated it, and that overstatement was doing work
in my P1 argument.

**R4 — `survey_spell_casts` is not half-built per-spell telemetry.** Verified: it is a bare
`+= 1` with no spell ID (`3757`), immediately followed by `_annotate_player_action("spell")`, whose
aggregate is already printed as `Action usage: … spell xN` (`survey_report.gd:175`). Promoting the
orphan would duplicate a figure the report already carries. What the next survey actually needs is
usage keyed by stable spell ID. **M9 still stands as evidence that the registry does not own every
declared survey variable** — it just does not stand as a shortcut to the measurement I wanted.

**R1 — P1 argued against a shipping order that was labelled a review order.** The follow-up said so
in its own first line (`code-structure-audit.md:861`) and I read past it. The categorical objection
is conceded. I note only that the argument's substance transferred: the revised practical order now
leads with survey correctness, which is what P1 was for.

**R2 — P3 should not have been filed as pushback.** M10 claimed a redundant scan and absent
uniqueness validation; it never claimed ID instability. That suspicion was mine, and disproving it
argues for deferring M10 rather than against M10. It stays in the document as a **recorded negative
result**, which is what it always was.

**R5 — build the contract, use the Chanter as its first acceptance case.** Accepted, and it is a
straightforward improvement on my ordering. Putting "the Chanter, completely" first invited exactly
the convention-based fix both audits exist to reject: two more synchronised field edits in two
hand-written projections. Proving the contract through one vertical case is better, and it restores
the Chanter on the same schedule.

## One refinement to the sequencing rationale

Sol's revised order places the presentation contract at step 3 and the survey at step 5, with the
caution that the survey must not be delayed by structural work that changes neither its readability
nor its numbers. Agreed — but the rationale should name **which** presentation defect gates the
survey, because it is not the Chanter's.

**It is enemy burn and frost.** Chant marks are incidental to an Elementalist run: `chanted_line`
is a tier-4 recipe and a given survey may never draw a Chanter at all. Enemy conditions are not
incidental — they are the Elementalist's own feedback loop, applied by Fireball, Frost Lance, Fire
Breath and Cold Front in every room where the player casts. A survey asking *does casting compete
with dodging* is asking the player to weigh a payload they currently cannot see land.

So the minimum contract that unblocks the survey must cover **enemy condition state through both
the frozen and streamed paths, and a body-level halo to draw it**. Chant marks ride along because
they are the same data at the same layer, and they make the Chanter a complete acceptance case —
but if the contract had to be cut down to ship the survey sooner, conditions are the part that
cannot be cut.

## What is agreed

Both parties now hold the same position on all of it. For a reader picking this up cold, the
settled points are:

1. Hostile-action classification for `hurl`, `sunder` and `slam` comes first; it is small and the
   threat telemetry is wrong until it lands.
2. Catalogued `vision_range` becomes the single authority; the Chanter's live perception
   disagreement goes with it.
3. The presentation contract is built as a contract, with the Chanter as its first vertical
   acceptance case, and **enemy conditions are the part of it that gates the survey**.
4. The Elementalist telemetry question is decided explicitly: delete `survey_spell_casts` as
   redundant, or replace it with per-spell-ID usage if spell choice is information the survey will
   use. Not promoted merely because it exists.
5. The standard-profile Elementalist survey runs next, and is not held for structural work beyond
   the above.
6. The deeper programme follows: typed condition payloads, production validation boundaries with
   **authored-now failing loudly and disk saves migrated or refused whole**, shared actor
   representation, effect routing through faction, registry ownership, save migrations.
7. M10 waits for a profile.

The methodological residue of the whole exchange is two lines, one from each side:

> A universal-looking entry point is not proof of universal ownership, and a registry is canonical
> only if every producer enters through it, every consumer reads through it, and validation checks
> both the declared and the undeclared sides.

> A sweep is only as complete as the shape its method can express — and an audit that states a
> priority order should say whether it is ordering evaluation or ordering work, because the two
> get read as the same thing.

---

# Consolidated work plan

**Recorded:** 2026-09-02 by Claude, against `0.2.78`. **Proposed, not approved.** This collapses the
third audit, the Sol 5.6 follow-up, both replies and the survey findings into one ordered list. It
supersedes the individual priority lists above as the thing to work from; those remain as the
reasoning behind it.

Every item names what "done" means, because several of these are the kind of change whose only
evidence of success is that nothing changed.

**Two conventions.** *Structural* items change how rules are written and must not change gameplay.
*Gameplay* items deliberately change what the game does. No version should mix the two — a survey
cannot falsify a tuning change that shipped alongside a refactor.

## These are two tracks, not five sequential phases

An earlier draft of this plan numbered the phases in a line, which implied Phase 4 waits for the
survey. It does not. **Phase 4 is behaviour-preserving by definition, so nothing in it blocks the
survey, and nothing in Phase 3 blocks it.** The phases below are grouped by kind, and the real
constraints are these and only these:

**Track S (structural):** Phases 0, 1, 2, 4.
**Track G (gameplay):** Phase 3.

**Hard dependencies:**

- `0.1`, `0.2` (golden run) → **all of Phase 4**, and especially `4.3`. The refactor's only proof is
  that hashes do not move; the instrument must be able to see the systems it would break first.
- `0.3` (hostile-action classification) → `3.5`. The survey reports threat telemetry that is
  currently wrong.
- `0.4` (telemetry decision) → `3.5`.
- `2.4` (enemy condition halo) → `3.5`. The caster cannot weigh a payload they cannot see land.
- `3.1`–`3.4` → `3.5` → `3.6`. Changes must ship before the survey that falsifies them.

**One shared resource, which is the only reason the tracks need coordinating at all.** Both tracks
change the golden-run baseline: Track G legitimately, Track S never. If both are in flight when the
baseline is re-recorded, a moved hash is ambiguous — refactor bug, or intended tuning? So the rule
is not an ordering but an interlock: **re-baseline only with one track's changes outstanding, and
say in the commit which track moved it.**

**One practical exception to parallelism.** `4.3` (one actor representation) rewrites every
actor-generic function and the regions around them in a 10,222-line file. It should not run
concurrently with gameplay work in the same file. The smaller structural items — `4.1`, `4.5`,
`4.7` — are localised and parallelise fine.

**Recommended:** run Track S continuously, and take Track G in one focused pass when Phase 0 and
`2.4` are done, pausing `4.3` for its duration.

---

## Phase 0 — make the instruments trustworthy

Everything after this is measured by these three instruments. All are currently blind in ways that
matter, and two of the blind spots sit directly over the systems Phase 4 would rewrite.

**0.1 — Close the determinism projection's holes.** *(Structural. B4, B5, B6.)*
`DeterminismSnapshot` is the safety net for exactly the refactor this plan ends with, and its own
comment says structural refactors should preserve its hashes. It cannot currently see:

- `ACTOR_FIELDS`: `chants`, `chant_source_id`, `condition_buildup`, `gale_velocity`;
- the player block: `player_conditions`, `player_condition_buildup`, `player_gale_velocity`, every
  cooldown, `stealth_remaining`;
- `WORLD_FIELDS`: `elevation`, `elevation_profile`.

**Done when** a deliberate change to any of those values makes `golden_run_test` go red.

**0.2 — Give the golden run a caster.** *(Structural.)*
`golden_run_test.gd` scripts a **Warrior in recovery rules**. It never casts a spell, applies a
condition, raises a barrier or launches an arcing projectile — so even the fields that *are* hashed
are never exercised by the systems most likely to break. Add a second scripted run: a Mage ·
Elementalist under Energy rules that casts, burns, freezes, raises a wall and takes a javelin.

**Done when** the suite has two golden runs and the caster one covers spells, conditions, barriers
and projectile elevation.

**Note on ordering within Phase 0:** adding fields to the projection changes the recorded hashes, so
the baseline must be re-recorded. Re-baselining is only safe when current behaviour is believed
correct, so do 0.1 and 0.2 **before** the Phase 2 gameplay changes, and re-baseline once more after
them rather than trying to avoid a second pass.

**0.3 — Correct hostile-action classification.** *(Structural. M6.)*
`hurl` (`7141`), `sunder` (`7180`) and `slam` (`7252`) are produced but absent from
`ENEMY_ATTACK_ACTION_KINDS`, which `_threat_snapshot` consults at `2832`. Javelineer and Earth
Caster wind-ups are invisible to survey threat telemetry today; the Warden inherits it later. **The
Brute is not affected** — it commits through ordinary `melee`.

**Done when** a room with a winding-up Javelineer reports a pending attack.

**0.4 — Decide the per-spell telemetry question.** *(Structural.)*
`survey_spell_casts` is an orphan aggregate already duplicated by `Action usage: spell xN`. Either
delete it as redundant, or replace it with usage keyed by stable spell ID. Not promoted merely
because it exists.

**Done when** the counter is gone, or the report names spells individually.

**0.5 — Ship and verify the survey telemetry before any gameplay experiment.** *(Structural.)*
Moved here from Phase 3 on Sol's amendment: this is instrumentation, and instrumentation must not
ride in the same version as the changes it measures. Crowding (mean nearest-ally distance among
active enemies; share of combat with a pair inside comfort distance), friendly-fire hits, damage and
kills, and **interruption attribution** — what interrupted which attack, with which tool. The last
exists to falsify the claim that interruption, not Energy, is why the Elementalist never dodges.

**Done when** a room whose numbers are known by hand reproduces them, and the counters appear in the
report.

---

## Phase 1 — single-authority fixes that are small and unblock the rest

**1.1 — Catalogued `vision_range` becomes the only authority.** *(Structural. M4.)*
`_enemy_vision_range` (`3364`) hardcodes six long-sighted kinds; the Chanter is absent despite the
catalog authoring `620.0` for it, so ordinary sight and death-witness perception disagree about the
same enemy.

**Done when** the hardcoded list is gone and every kind's sight comes from `properties.vision_range`.

**1.2 — Retire the dead ability family.** *(Structural. Shape D.)*
`hex`, `ice_hex`, `ice_cone` and `fire_circle` have no producer — the Hexer was retired in `0.2.35`.
They carry an executor branch, `_spawn_hex()`, hazard handling, effect labels, phase text and nine
renderer branches. Note that catalog validation currently *requires* the dead executors, because the
kinds are declared.

**1.3 — Make catalog validation check both directions.** *(Structural. Shape D, M6.)*
Every declared kind needs an implementation **and** a producer. Requires per-namespace reachability
(actions, hazards, projectiles, effects and enemy kinds are separate even where IDs share text) and
an explicit lifecycle — `active` needs a producer, `reserved` states why it is retained, `legacy`
names the migration that consumes it.

**Correction, on Sol's amendment 8: `werewolf` and `warden` are NOT the reserved case.** Both are
produced by `floor_generator.gd` (`283`, `680`) and both have live AI branches (`run_state.gd:7235`,
`7249`) — the Warden's `slam` carries a 1.02s startup behind a 0.46 probability. In reachability
terms they are active content whose behaviour is provisional. **`CLAUDE.md` is stale on this**: it
says both carry "a `boss` role with no behaviour behind it", and that is false. What is true is that
they never appear in a Combat Survey room — no encounter recipe names either — so nobody has seen
them. A genuine `reserved` example must be found elsewhere, or the lifecycle can carry only `active`
and `legacy` until one arises.

**Done when** deleting a producer fails the suite, and 1.2's kinds cannot silently return.

---

## Phase 2 — the presentation contract, with the Chanter as its acceptance case

One piece of work, not four patches. Building it as a contract is the point; adding `chants` by hand
to each projection is the convention-based fix every audit here rejects.

**2.1 — A per-enemy field schema with audiences**, alongside the top-level one, from which
`_enemy_presentation`, `PresentationFrame._copy_enemy` and `DeterminismSnapshot.ACTOR_FIELDS` are
generated rather than transcribed. **On Sol's amendment 6: one descriptor source, not identical
field sets.** The top-level schema already carries `SNAPSHOT`/`PRESENTATION`/`SAVE`; the per-enemy
one needs at least `presentation` and `determinism`, since a cache or a cooldown may matter to one
and not the other. Each descriptor also carries its interpolation policy (lerp, carry-forward, or
neither) and its nested-copy policy, which is what 2.3 consumes. *(B1, B3.)* The three lists have already drifted: the streamed
path lacks `revealed_to_player`, `revealed_elapsed`, `attributes`, `weapon_frame` and
`equipped_weapon_art`.

**2.2 — An exhaustive top-level presentation contract.** *(M1, B2.)* `sensed_enemies`,
`aimed_enemy_id`, `player_conditions`, `player_condition_buildup`, `player_exhaustion_remaining`,
`visible_cells` and `discovered_cells` are in `snapshot()` and not in the schema; the renderer
either loses them in streamed frames (Keen Eye silhouettes, the aimed-enemy outline) or bypasses
`visual` and reads live state, drawing objects from two different simulation times in one frame.
`blend()` must derive from the schema instead of hand-listing what `capture()` already gets from it.

**Performance caveat, on Sol's amendment 6.** `visible_cells` and `discovered_cells` are Dictionaries
sized by the floor, not by the actors on it. Deep-copying them into every streamed frame at 120 Hz
would fix the time-authority problem by creating a worse one. They need a **revisioned or
copy-on-change frame value** — the frame carries a revision number and a reference, and copies only
when the underlying set actually changes, which during combat is rarely.

**2.3 — Per-field copy policy below the entity level.** *(M2.)* `_copy_flat_dictionary` discards
every Array and Dictionary, so the nested `interrupted_action` the renderer uses to draw an
interrupted pose survives a full snapshot and vanishes from streamed frames.

**2.4 — Draw what is now carried.** *(Gameplay-visible, but no rules change.)* Enemy burn and frost
as a body-level halo — **this is the part that gates the Elementalist survey**, because conditions
are the caster's own feedback loop and apply in every room where the player casts. Chant marks ride
along on the same data at the same layer and make the Chanter a complete vertical case; they are not
themselves survey-gating, since `chanted_line` is tier-4 and a given survey may never draw one.

**Done when** a burning enemy is visibly burning in both frozen and streamed frames, a chanted ally
shows which chant and how much longer, and adding a new per-enemy field requires editing one place.

---

## Phase 3 — a corrected baseline, then one experiment at a time

**Revised after the Sol 5.6 review.** The first draft bundled three gameplay changes into one
version and one survey, which violated this plan's own rule: Lightning damage, lane behaviour and
spawn spacing can each move *does casting compete with dodging*, and one survey cannot attribute the
result to any of them. The telemetry that was here has moved to Phase 0, where instrumentation
belongs.

**3.0 — The corrected baseline survey.** Standard profile, played to win, run once Phase 0 and
Phase 2 are complete and **before any gameplay change**.

This is the amendment that matters most. Every tuning hypothesis currently on the table — Lightning
above all — was derived from a run in which the player could not see burn or frost land, the threat
telemetry under-counted, and spell usage was reported as one aggregate. Making enemy conditions
visible may itself change how the class is played: a readable elemental payload is a reason to cast
something other than the bolt.

**Expect this run to look like `0.2.77`, and do not treat that as failure.** If Lightning is
dominant, a player trying to win will use it, and the ratings may barely move. Its value is the
telemetry, not the scores — interruption attribution, per-spell usage and crowding are figures the
last run could not produce. And if the bolt does remain dominant with the kit finally legible, that
is precisely the falsification that licenses 3.1.

**Done when** the run is recorded on the standard profile with Phase 0 telemetry intact, and the
three figures that answer the falsification question — exhaustion lockouts, dodge forms used,
whether Energy is ever binding — are reported alongside interruption attribution.

---

The three changes below are **separate experiments**, each its own version, each measured against
3.0. Run them one variable at a time, or through explicitly matched profiles if they are combined.

**3.1 — Lightning Bolt.** *(Gameplay. Conditional on 3.0.)*
The recorded design judgement stands: the problem is cheap, instantaneous damage at range, and it is
upstream of any argument about interruption. What 3.0 decides is the **magnitude**, not the
direction. At 11 damage and ~16.9 real Energy the bolt returns 0.65 damage per Energy against the
staff poke's 0.55 — comparable efficiency, except the staff pays in standing at 150 units and the
bolt pays nothing at 340. Proposed change: damage `11 → 6`.

**Done when** a survey after the change shows the bolt used as an opener and a finisher rather than
as the default action, measured as: bolt casts as a share of all offensive actions falls below its
3.0 share, and per-spell usage shows at least one elemental spell in regular use.

**3.2 — Lane policy as authored capability.** *(Gameplay. Needs design approval before build.)*
Sol's amendment is adopted over the original blanket rule. Lane behaviour becomes per-kind metadata
rather than one universal check, because a disciplined Archer and a reckless Javelineer is
characterisation, while one rule for all of them is homogenisation.

The authored vocabulary, and the release-time outcome must be named for each kind rather than left
to the implementation:

- `ignores_allies` — fires regardless;
- `checks_before_commitment` — the current Archer behaviour;
- `checks_at_release` — re-evaluates when the wind-up ends;
- and for the last, what happens when the lane is blocked: **hold** (keeps the telegraph, delays the
  shot), **cancel** (abandons after a full telegraph, which hands the player a free opening), or
  **redirect** (violates the telegraph the player just read).

**Recommendation:** Archer `checks_at_release` + hold; Javelineer `ignores_allies`, since its arc
already carries it over bodies and recklessness is its character; casters `checks_before_commitment`.
This serves the stated lean — *misdirected arrows should have friendly fire, but not every shot* —
without flattening the roster.

**Done when** friendly-fire telemetry from Phase 0 shows stray hits concentrated in shots that were
clear at release and blocked in flight, rather than in shots that were blocked when fired.

**3.3 — Formation-preserving spawn relaxation.** *(Gameplay. Its own experiment.)*
Deterministic relaxation after all seats are authored, each body attracted to its seat while
resolving obstacles, the player, the rim and its peers. It changes the geometry of every encounter,
so it does not share a first evaluation with a damage change or altered ranged AI.

**Done when** Phase 0's crowding telemetry shows mean nearest-ally distance rising toward the
authored seat spacing, with the formation's shape preserved — and when a `central_cover` room no
longer reports three bodies inside one Sweep-the-Legs footprint.

**3.4 — Tune on what the experiments say.** Deliberately unspecified.

## Phase 4 — the deeper structural programme

Ordered so each item makes the next safer. **Phase 0 must be complete before 4.3**, and 4.3 alone should not run concurrently with Track G. Nothing here waits for the survey.

**4.0 — Production validation boundaries — moved ahead of everything else in this phase.**
*(M3. On Sol's amendment 7.)* The first draft placed this at 4.4, after the representation rewrite,
while claiming each item makes the next safer — an internal contradiction. **The validation
mechanism must protect the migration, not inspect it afterwards.** `RuntimeSchema.construct()`
pushes errors and returns the invalid dictionary anyway; `validate()` checks key presence only, not
types, allowed kinds, value invariants or ID uniqueness; and `_add_enemy_actor()`,
`_replace_enemy_actors()` and load hydration all bypass it. **Authored-now must fail loudly; a save
from disk must migrate, or be refused whole with a message** — never silently repaired one record at
a time, which produces a deceptively successful corrupted load.

**Done when** an actor record missing a required field cannot enter `enemies` from any path, and a
malformed save is refused with a message rather than partially loaded.

**4.1 — Typed effect payloads.** *(M5.)* `_apply_source_condition_to_player` decides which condition
an ability applies by substring-matching `ice`/`frost`/`cold`/`fire`/`burn` against a **display
label**, defaulting unregistered sources to `4.0`; `CONDITION_BUILDUP_BY_SOURCE` is keyed on prose
with spaces (`"fire breath"`) while the catalog holds real IDs. Renaming text changes combat.
Abilities should carry `condition_id` and `condition_buildup`; labels become presentation only.

**4.2 — Effect routing through faction.** *(M7.)* `_opposes()` is consumed only by barrier
collision; projectiles and hazards still branch on `source_id == 0` and `friendly`. Any ally, summon,
charm or neutral hazard would need new special cases at each site.

**4.3 — One actor representation.** *(A1–A5, and Sol's additions.)* `_actor_storage()` returns `{}`
for the player, so all six actor-generic functions are translation layers over 32 loose scalars
versus a dictionary. Includes the condition dispatcher (A2), the posture-recovery asymmetry (A3),
`_player_/_enemy_personal_tempo` (A4), `_set_actor_impulse` (A5), the two inline paths inside
`_update_conditions()`, and `current_move_speed()` / `_enemy_move_speed()`.

**Done when** `_actor_storage(0)` returns a real record and the boundary functions are field access.

**4.5 — Capabilities as properties.** *(Shape C.)* Eleven rules gate on a name: Shield blocking,
Duellist parry (×2), Bandit ambush and `dodge_strike` (×7), Fire Caster firebolt. `properties`
already exists in the catalog and `mass`/`PUSHABLE_MASS` is the model. Live cost: a Knight cannot
raise a guard, and neither can either boss. Further candidates Sol names: `_shield_patience_budget`,
Archer-specific shot-cooldown init, Boar momentum armour, the Hound/Bandit contact-trade exemption.

**4.6 — Registry ownership, both directions.** *(M9.)* `_capture_survey_room_entry`, `snapshot()`
and `_build_save_payload` hand-list fields and then merge a registry capture over the top. Validation
proves every descriptor has a source; nothing proves every live measurement has a descriptor.

**4.7 — Save migrations.** *(M8.)* Steps `21 → 33` are pass-throughs while semantic migration sits
inline in `load_run()` behind version predicates; `< 21` branches are unreachable given
normalization. **`SUPPORTED_START_VERSIONS` omits `32` while `_v32_to_v33()` exists**, so a save
beginning at 32 is refused — resolve whether 32 ever shipped, and record it either way.

**4.8 — `_normalize_presentation_ids()`, after a profile.** *(M10.)* Rescans five collections every
`_update_enemies()` to recompute a high-water mark, and does not validate uniqueness. Recorded
negative result: it does **not** destabilise IDs — assignment is guarded by
`if not item.has("presentation_id")` — so blending pairs correctly and this is a cost question only.

---

## Phase 5 — the roadmap this unblocks

Unchanged from `CLAUDE.md`, restated so the plan is complete:

1. **Werewolf and Warden as real bosses.** Both carry a `boss` role with no behaviour. **This step
   must specify its own evaluation before any of it is built** — the Combat Survey is a room-coverage
   instrument and a boss is not a room.
2. **Survey the boss instrument**, whose first run is a falsification test of the instrument.
3. **Recovery versus Energy**, a matched-seed *pair* of surveys. Last deliberately: a boss is the
   situation that separates the two resource models most sharply.

## What is deliberately not here

- **Splitting `run_state.gd`.** All three audits agree: ownership boundaries first, files shrink
  along them afterwards or not at all.
- **A global `ENERGY_COST_SCALE` change.** Shared with every class; the Elementalist question is not
  yet evidence about the kernel.
- **Enemy friendly-fire damage scaling.** The complaint is frequency, and 3.2 addresses frequency.
  Halving same-side damage would reverse a recorded decision to fix a different problem.
- **Removing `cluster` from the formation pool.** Room 3 huddled under `screen_line + picket`; the
  cause is 3.3, and deleting the control condition costs the baseline.
