# Waystone — working instructions

Standing context for any coding session in this repo. Keep it short; the detail lives in the documents it points to.

---

## Read in this order

1. **`docs/design-foundations.md`** — why the design is what it is. Lineage from Cardinal Quest 2, Dark Souls and Hades, what is deliberately *refused* from each, the frozen-time and determinism commitments, and a record of rejected directions. Read before making design decisions, not before making code changes.
2. **`WAYSTONE_MIGRATION_HANDOFF.md`** — operational context: implementation baseline, file map, survey format, build and install procedure. Written originally as a partial brief between conversations, so treat it as operational rather than as a complete design record. It has been reconciled against the documents below, but assume it is thinner than it looks.
3. **`docs/combat-loop-diagnosis.md`**, **`docs/attack-capture-design.md`**, **`docs/attack-capture-implementation.md`** — the current work. Authoritative on combat-loop matters where they overlap the handoff.
4. **`docs/combat-character-framework.md`** — detailed combat and character rules.
5. **`docs/design-brief.md`**, **`docs/expedition-encounter-redesign.md`** — slice promise and the deferred encounter plan.
6. **`docs/elemental-casters.md`** — the agreed, unimplemented design for the four elemental casters, the Elementalist subclass, and the shared systems they need. Read before touching any caster, projectile elevation, burn or frost.

`README.md` carries implemented-version history and the current version number. It is long; read it last.

**On a first session, or after a long gap, read all of the above before starting work** — and report any contradictions or stale claims you find between them. They were written at different times, by different hands, and some describe superseded behaviour. Surfacing the drift is part of the orientation, not a distraction from it. On a returning session, read what the task actually touches.

---

## Current priority

The combat loop, and nothing else. More enemies, classes, biomes, campaign content or encounter density all wait until moving, attacking, defending and surviving pressure are satisfying in a small room.

Milestone order is fixed by dependency: **A** (combo continuation follows live input) → **B** (post-hit hyperarmor) → **C** (attack capture, plus the Wait rework) → **D** (Sweeping Cut) → **E** (melee enemy differentiation) → **F** (re-survey and tune the kernel, including the Recovery-versus-Stamina comparison) → **G** (encounter grammar, and only then the enemies the surveys have shown to be missing). **A through E are implemented as of `0.2.33`.** E ran to four slices: E1 roles (`0.2.27`), E2 anchors anchor (`0.2.31`), E3 mass and felt damage (`0.2.32`), E4 the roster (`0.2.33`). The `0.2.33` survey ran, and `0.2.34` shipped the six fixes it asked for.

**What that survey proved, and it is the thing to act on.** Rooms carrying non-melee pressure scored **3.50 mean fun** and **3.50 want-again**; the four pure-melee rooms scored **1.50 and 1.00 — unanimous**. Those four are pre-existing recipes drawing on the pre-existing roster, and *nothing in E2, E3 or E4 moved them by a point*. Melee-only rooms are no longer an enemy problem; they are a composition problem. That is **G1**, and it is next.

### The agreed order

1. **G1 — encounter grammar.** Each enemy declares the axis it pressures; the generator composes rooms whose axes conflict. Not a hardcoded list of good pairs — that is the same mistake as the recipe table it replaces. Author the taxonomy with the axes the elemental casters will occupy even though nothing fills them yet, the way `movement_denial` existed before the Earth Caster arrived to fill it. **Retire the Hexer** in this pass, since otherwise a benched enemy needs an axis declared for it.
2. **Survey.** The falsification test for G1 — and the first run in which a poorly rated room means a bad *room*. This de-confounds every survey that follows, which is most of why G1 comes before the caster work rather than after it.
3. **Shared systems** — projectile elevation and friendly fire, the burn and frost meters, the barrier list. Cheap to get wrong and everything downstream depends on them. See `docs/elemental-casters.md` §2.
4. **Earth's wall**, since that caster already exists and `sunder` shipped in `0.2.33`.
5. **Fire and Ice**, as *replacements* rather than additions. Both casters exist and currently have one close AoE and one ranged AoE each — four abilities, two verbs.
6. **Air** — the one genuinely new enemy kind in the programme.
7. **The Elementalist**, and the **Stamina → Energy rename** with it. The rename's cost is the historical record and is identical whenever it lands, so it ships beside the class that motivates it rather than as speculative churn.

### Still owed, outside that line

- **F is not finished.** The retune happened in `0.2.34`, but the **Recovery-versus-Stamina comparison has still never been run** — the whole reason for fixing Stamina was to compare it fairly against the cooldown model. Keeping one resource bar for casters (no mana) means this comparison covers them too.
- **G2 leftovers:** Werewolf and Warden as real bosses. Both exist as kinds; neither has boss behaviour. Still gated on a demonstrated gap.
- **The Chanter and the Ox have never been played.** Neither appeared in the `0.2.33` run — `chanted_line` needs tier 6 and the run ended at tier 5.
- **Renderer validation of A–D** — all of it verified headless only.
- **An Acrobat survey run** — every survey so far has been Warrior.

New enemy kinds belong to G2 and are gated on a gap being demonstrated rather than anticipated — the Ox jumped that gate in `0.2.25`; the E4 roster passed it on the ranged-pressure measurement, except the Duellist, which was approved as a deliberate exception. The elemental programme passes it on the `0.2.33` measurement above, with the caveat that Fire and Ice are repairs to existing content rather than additions.

The slicing lives in `WAYSTONE_MIGRATION_HANDOFF.md`; the caster design lives in `docs/elemental-casters.md`.

---

## Finishing a code change

Building, committing and installing are part of finishing a change, not separate steps to be requested afterwards:

1. run the relevant tests in `tests/` covering the changed system;
2. keep version metadata in sync across `README.md` and `export_presets.cfg`, including Android `versionCode`;
3. build **both** platforms — `build-all.ps1`, not a single target, so Windows and Android never drift;
4. commit to GitHub;
5. install to the Pixel Fold if it is connected, and verify the installed package version on-device rather than trusting a successful export.

If the Fold is not connected, still build and commit, and say the install was skipped for that reason.

---

## Working agreements

**Do not write code until it is approved.** Design discussion is never authorization to change source. Present a plan, wait for a decision. This rule exists because it was violated before and cost real money.

**Challenge rather than agree.** Push back on proposals that conflict with the design pillars — including mine. Say when an idea is provisional, implemented, rejected, or unresolved. Agreement that isn't earned is worse than useless here.

**Verify documents against code.** Any document in this repo can be stale or wrong, including the ones above. When a document and the source disagree, the source is the fact — investigate rather than silently picking whichever is easier. Several errors in the attack-capture spec were found exactly this way.

**Explain the gist in plain language first, then the technical detail.** Keep the equations, tables, file references and derived numbers — the depth is wanted. Just don't make the idea something I have to reverse-engineer out of it.

**Preserve uncommitted work.** A dirty worktree is mine. Inspect it; never reset, discard or overwrite.

---

## Traps

- **Current behaviour is not automatically intended behaviour.** A passing regression can faithfully preserve the wrong prototype direction. Review test intent against the latest design decision before preserving it — `run_state_test.gd:262` passes only because every combo is seeded as held, not because it exercises a held input.
- **A green suite is not a passing suite.** Test files `assert()` inside functions called from `_init()`, then `print(...)` and `quit(0)` unconditionally. A failed assertion prints `SCRIPT ERROR`, aborts only that function, and still exits `0`. Worse, a file that asserts *directly* in `_init()` — `combat_survey_test.gd` does — aborts before reaching its own `quit(0)` and hangs forever instead of failing. Use `run-tests.ps1`, which scans for `Assertion failed` and applies a per-file timeout; never trust the exit code alone.
- **`run_state_test.gd` fails on `test_clean_opening_hit_preserves_a_defensive_choice`** as of `0.2.11`. The bandit strafes ~58 units laterally during the player's opening swing and leaves the 49° arc, so the strike misses entirely and its counter lands. This is the v0.2.8 interception-lane behaviour meeting a test written before it — a pursuit/contact question for Milestone E, not a post-hit-agency one. Do not "fix" it by weakening the assertion.
- **Choose the combat rule profile explicitly in tests.** A `RunState` instantiated without setup defaults to Recovery. Pass `"recovery"` or `"stamina"` so a passing test means what its name claims.
- **Enemy locomotion runs on alternate ticks.** `_update_enemies(dt, _simulation_tick_index % 2 == 0)` means anything gated on `update_locomotion` needs a `× 2.0` step to hit its authored speed. `dodge_strike` is missing it and travels at half speed.
- **No content-first escape.** More enemies or rooms multiply a weak loop rather than repair it.
- **No health-only difficulty, no invisible combat math, no input-dexterity creep.** Difficulty comes from action selection, composition, terrain, partial information and resources.
- **Local checkout only.** Do not assume an older OneDrive tree is authoritative, and do not move the source into a synchronized cloud folder to reach tools.

---

## Verification

Headless tests establish simulation behaviour, not visual truth. Validate contact, recovery animation, safe areas and readability in a real Windows renderer and on the Pixel Fold, which needs both orientations and its reported safe display area.

Use the next survey as a falsification test for a change, not as a demonstration that it must have worked.
