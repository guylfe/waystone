# Code structure audit

**Status:** Proposal. Nothing here is implemented.

**Recorded:** 2026-08-31, after `0.2.73`.

**Scope:** Where the source repeats itself, what that has already cost, and what to unify. Every proposal must leave gameplay identical — this is about how the rules are written, never about what they are.

---

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
