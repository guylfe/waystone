# Waystone — working instructions

Standing context for any coding session in this repo. Keep it short; the detail lives in the documents it points to.

---

## Read in this order

1. **`docs/current-state.md`** — the current implementation boundary, next work, document-status map, and documentation-maintenance contract. Read first after any gap.
2. **`docs/design-foundations.md`** — why the design is what it is. Lineage from Cardinal Quest 2, Dark Souls and Hades, what is deliberately *refused* from each, the frozen-time and determinism commitments, and a record of rejected directions. Read before making design decisions, not before making code changes.
3. **`docs/battle-design-bible.md`** — the consolidated enemy, attack, encounter and boss design standard. Every claim is marked by credence and decision status; use it to distinguish settled rules from working defaults and proposals, and read its explicit disagreements before importing genre conventions.
4. **`WAYSTONE_MIGRATION_HANDOFF.md`** — operational context: implementation baseline, file map, survey format, build and install procedure. Written originally as a partial brief between conversations, so treat it as operational rather than as a complete design record.
5. **`docs/combat-loop-diagnosis.md`**, **`docs/attack-capture-design.md`**, **`docs/attack-capture-implementation.md`** — historical diagnosis and the design/implementation record for the shipped attack-capture work. Do not treat their `0.2.10` baseline or pre-implementation instructions as current behaviour.
6. **`docs/combat-character-framework.md`** — detailed combat and character rules.
7. **`docs/design-brief.md`**, **`docs/expedition-encounter-redesign.md`** — slice promise and the deferred encounter plan.
8. **`docs/survey-archive-findings.md`** — historical analysis of 297 rated rooms and the shipped G1 response. Read before proposing anything about encounter generation.
9. **`docs/elemental-casters.md`** — the implemented four-caster and Elementalist design record. Read before touching any caster, projectile elevation, burn, frost, barriers, or elemental spell.

10. **`docs/code-structure-audit.md`** — how the source is organised and why. Read before adding a field, a kind, an ability, a counter, or a rule about who may affect whom. The modules it produced are where authored facts live: `combat_catalog.gd` (kinds), `ability_catalog.gd` (spells and enemy abilities), `state_field_schema.gd` (fields and their audiences), `survey_counter_catalog.gd` (measurements), `save_migrations.gd`, `runtime_schema.gd` and `determinism_snapshot.gd`.

11. **`docs/warrior-vanguard-redesign.md`** — the implemented Warrior/Vanguard redesign and its later Battle Flow revisions. Read before touching Rally, Battle Flow, Advance, poise, or either track.

`README.md` carries implemented-version history and the current version number. It is long; read it last.

**On a first session, or after a long gap, read all of the above before starting work** — and report any contradictions or stale claims you find between them. They were written at different times, by different hands, and some describe superseded behaviour. Surfacing the drift is part of the orientation, not a distraction from it. On a returning session, read what the task actually touches.

---

## Current priority

The explicitly approved three-biome expedition is implemented as `0.3.0`; its four
legal character runs, builds and Fold installation are verified in
`docs/expedition-0.3.0-implementation.md`. Next obtain human journey/boss feedback,
inner-display checks and sustained device performance evidence, then propose bounded
changes from those results. Automated wins are not human balance acceptance.
The October 17 approval supersedes the earlier Warden-first content gate for this
experiment, not the requirement for trustworthy combat or honest test reporting.
Other foundation-audit proposals and mature Campaign work remain outside this scope.

### What is already built

`0.3.0` adds the three-biome mountain ascent, six ordinary enemy kinds, three solo
bosses, finite healing/economy, equipment and the midpoint Trapper/Sapper adoption.
It also repairs current-commitment measurement, imposed-reaction clock ownership and
defensive-response attribution. The implementation ledger owns the content and test
closeout; older milestone and boss-plan sequences below remain historical/deferred.

The milestone letters **A** (combo continuation follows live input) through **E** (melee enemy differentiation) shipped by `0.2.33`, and **G1** — encounter grammar, guaranteeing non-melee presence and composing deliberate pure-melee experiment rooms — shipped in `0.2.35`. The Hexer was retired in the same pass. Surveys through `0.2.44` were G1's follow-through.

The **elemental caster programme** then ran to completion: friendly fire and projectile elevation (`0.2.47`), the burn and frost meters (`0.2.54`), barriers and Earth's wall (`0.2.55`), Fire (`0.2.56`), Ice (`0.2.57`), Air (`0.2.58`), staves for every caster (`0.2.59`), and the **Mage · Elementalist** with the Stamina → Energy rename (`0.2.61`–`0.2.62`). `0.2.75` began the source-ownership restructure; `0.2.79`–`0.2.81` completed the measurement/presentation spine, made catalogued vision authoritative, and replaced bespoke projectile lane logic with the symmetric authored `misdirected` rule. Two standard Elementalist surveys then drove `0.2.82`: expensive spell openings, stronger/faster Lightning, a costlier staff, simultaneous level-3 Main Class/Subclass access, overlap recovery, lethal-hit awareness, and truthful response telemetry. `0.2.84` followed the next surveys with a three-band Intelligence efficiency curve and a revised Mage track. `0.2.85` replaced the old Warrior and Vanguard tracks with sustained Rally, Resolve-derived action poise, Battle Flow, a target-bound Advance, two real track choices, and explicit combat telemetry. Follow-up releases corrected previously unscaled enemy attacks (`0.2.86`), made Battle Flow sequence-based and fixed the room-clear handover (`0.2.87`–`0.2.89`), differentiated Hound and Boar ally collisions (`0.2.90`), and gave the Ox posture-governed control while extending Battle Flow to 15 seconds and measuring both systems (`0.2.91`). See `docs/code-structure-audit.md` and `docs/warrior-vanguard-redesign.md`.

Two long-owed items are also closed: the Acrobat has been surveyed (`0.2.38`, `0.2.44`), and the Chanter and the Ox have both now been seen in play — the Ox in the `0.2.77` renderer pass, which was itself the first look at milestones A through D outside a headless test.

### Earlier work order — deferred, not completed

The following sequence is retained for later work. It does not override the approved
0.3.0 contract or make the existing Werewolf/Warden part of its three new bosses.

1. **Warden solo redesign.** Boss Lab, support/encounter introductions, Knife differentiation, and the Werewolf solo redesign shipped in `0.2.92`–`0.2.95`. Implement the Warden's three-move spatial vocabulary, phase sequence, and explicit posture policy as Update 5 of `docs/enemy-encounter-boss-revised-design.md`.
2. **Survey the boss instrument and both bosses.** Treat the first play as a falsification test of the lab and its reporting, not merely of balance. Tune only the owner isolated by evidence.
3. **Comparison and narrow journey integration.** Compare the Werewolf solo remix with its separately enabled pack condition, then embed only validated definitions into a small Expedition/Campaign slice with explicit arrival resources.
4. **The Recovery-versus-Energy comparison.** Run a matched-seed pair after the boss pressure test is credible; do not reopen the resource model from unrelated room results.

### Standing design decisions

- **A late read is punished.** Reading an attack too late must fail; *how* late is a tuning question to be answered by measurement, not by argument. Recorded 2026-09-01. The Boar's late-sidestep case is the first place this bites.
- **New enemy kinds remain gated on a demonstrated gap or explicit content approval.** The Ox jumped that gate in `0.2.25`; the Duellist was approved as a deliberate exception. The six ordinary kinds and three bosses in the approved `0.3.0` expedition are a bounded content programme, not permission for unrelated roster expansion.

### On the milestone letters, which have stopped tracking the work

A through G were built to answer the combat loop and nothing else, and **G1 was the last of them.** G2 was written as "the smallest number of new enemies the surveys have shown to be missing", and **E4 already spent most of it** — the Javelineer, Earth Caster, Chanter and Duellist were G2 content pulled forward on a demonstrated ranged-pressure gap. Boss work is now tracked by the six-update plan rather than the obsolete milestone letters.

The caster programme was therefore **not** G2, and labelling it so would have been convenient rather than true: it was one new enemy kind, two rewrites, eight abilities, three shared systems and a player subclass. Calling that "the smallest number of new enemies" would have quietly blurred the gate the *No content-first escape* trap exists to hold. It is recorded as its own programme, with the gate crossed as a decision: the `0.2.33` measurement demonstrated the gap, and Fire and Ice were repairs to existing content rather than additions.

The slicing lives in `WAYSTONE_MIGRATION_HANDOFF.md`; the caster design lives in `docs/elemental-casters.md`.

---

## Finishing a code change

Unless the approved task explicitly narrows the release boundary, finishing a release includes:

1. run the relevant tests in `tests/` covering the changed system;
2. update the owning design/operational documentation in the same change; a task is not complete while the docs describe the previous behaviour, status, or priority;
3. keep version metadata in sync across `README.md`, `docs/current-state.md`, `WAYSTONE_MIGRATION_HANDOFF.md`, and `export_presets.cfg`, including Android `versionCode`;
4. build **both** platforms — `build-all.ps1`, not a single target, so Windows and Android never drift;
5. commit every approved numbered version and push that release commit to GitHub; approval of the
   numbered version is also authorization for its normal release push;
6. install every approved numbered version to the Pixel Fold, and verify the installed package
   version on-device rather than trusting a successful export.

If the Fold is unavailable, still build, commit and push, but report the release as awaiting device
installation rather than complete. A task that explicitly requests an unnumbered experiment or
local-only checkpoint may narrow this rule; an ordinary approved version may not silently omit it.

---

## Writing code here

`0.2.75` restructured the source around one idea: **a fact is authored once, and everything that needs it reads it from there.** The audit that produced it is `docs/code-structure-audit.md`, and it is worth reading before any change that adds a field, a kind, an ability, a counter or a rule about who may affect whom.

That structure only holds if new code uses it. The default instinct — add a small dictionary right where it is needed — is what produced every one of the bugs the audit catalogues, and it will do so again.

**Before adding anything, ask where it already lives.**

| Adding | It belongs in | Never |
|---|---|---|
| An enemy kind, or any per-kind fact | `combat_catalog.gd` — `ARCHETYPES`, including its `presentation` block | a new `{"ox": …, "blade": …}` literal anywhere else |
| A spell or an enemy ability | `ability_catalog.gd` — cost, targeting, reach, timing, resolver, phase text, colour | timing in `run_state` and phase text in `game_board`, separately |
| A field the renderer, a save or a snapshot needs | `state_field_schema.gd`, with its audiences | one writer at a time |
| A survey measurement | `survey_counter_catalog.gd` — one descriptor carries scope, differencing and format | a variable plus four plumbing sites |
| A cooldown | a slot through `begin_cooldown()` | a new scalar and a parallel `_max` |
| An ability that costs while it is held | **the Stealth model** — a per-second Energy drain plus a cancel control on the skills row | a fixed duration with a cooldown, which makes "use it on cooldown" the only policy |
| A question about whether something may stand somewhere | `_can_occupy()` / `_teleport_allowed()` | `_inside_world` and `_point_in_wall` combined by hand |
| A rule about who an effect may touch | `_faction_of()` / `_opposes()` / `actor_view()` | `if actor_id == 0` |
| A save field that older saves lack | a step in `save_migrations.gd` | a `.get()` default that quietly hides both an old field and a forgotten new one |
| A projectile, hazard, barrier or effect field | the world-object descriptors in `state_field_schema.gd`, with authored defaults and audiences | a presentation-only fallback or a second per-kind field list |
| A collision exception after launch | an explicit world-state property such as `misdirected`, resolved through faction | a shooter-specific pre-check pretending to guarantee all future geometry |

### The optimized ownership contract

The audit's later passes sharpened “author once” into a stronger rule. Use all of it:

1. **A boundary is canonical only when every producer enters through it and every consumer reads through it.** A helper with a universal name is not proof of universal ownership. Search both sides before calling a refactor complete.
2. **Validation is bidirectional.** Every declared active kind needs a producer and consumer in the correct namespace, and every produced semantic kind must be registered. A validator that checks only declarations can preserve dead content; one that checks only producers can preserve undocumented behavior.
3. **Describe fields before copying them.** If state crosses save, determinism, frozen presentation or streamed presentation, add one descriptor with its audiences, authored default, copy policy and interpolation policy. Do not patch two projections and rely on convention to keep them synchronized.
4. **Runtime-authored data and disk saves have different failure contracts.** Invalid authored-now data fails loudly in tests/build validation. Old saves migrate completely and validate atomically, or are refused whole with a useful message; never silently salvage individual records into a deceptively valid run.
5. **Rules about sides are symmetric unless the design explicitly says otherwise.** Player ID zero is an identity, not a faction policy. Projectiles demonstrate the intended shape: ordinary shots ignore their source side; an authored `misdirected` state makes that side eligible, including the source itself.
6. **Do not encode a future guarantee in an earlier AI decision.** Commitment checks cannot guarantee release-time or flight-time geometry. Put lasting permissions on the committed object and let the authoritative resolver evaluate actual contact.
7. **One behavior has one contract owner.** Focused tests own the mechanic; integration and golden tests own boundaries and whole-state preservation. Avoid duplicating the same internal timing assertion in several files.
8. **Separate structural, presentation and gameplay changes.** A refactor should preserve golden hashes. A perception or presentation correction may change player decisions even if simulation hashes stay fixed. A gameplay experiment gets its own version and evaluation so its result remains attributable.
9. **Profile before optimizing a merely suspected cost.** Correctness work may proceed from demonstrated ownership drift; performance work such as presentation-ID scan removal waits for measurements on the target device.

When auditing new code, ask two questions explicitly:

- For each fact this feature carries, how many places must agree, and what mechanism makes them agree?
- What shapes can the audit method not see — inline duplication, cross-named twins, live-state fallbacks, or producers outside the registry?

**The four mistakes that cost the most, so they are recognisable when they recur.**

*One fact, several writers.* A field added to one snapshot and not another is invisible: no error, no warning, and the failure surfaces as behaviour. The Earth Wall was in the world, blocking, and absent from the picture the renderer draws — six versions to find, because probes read a different writer than the game does.

*The renderer keyed on a name the simulation had moved on from.* A cone drawn as a circle, a caster drawing a bow it does not carry, a cone renderer belonging to a hazard nothing spawned any more. Where presentation must branch, branch on a **property** the thing carries — `half_angle` says cone — rather than on its name, and put the authored strings in the catalog so there is only one of them.

*A rule written for the only case that existed.* Barriers blocked "the player" because only enemies could raise one. When the Elementalist learned to, the player's own wall blocked the player and let enemies through. If a rule is about a side, say side; if it is about ownership, say ownership.

*Permissive defaults hiding authoring errors.* An unregistered enemy kind used to ship as a working Blade. Authored IDs now fail loudly, and they should stay that way. Reserve `.get()` defaults for genuinely optional runtime values and old saves.

**A passive is introduced by a node, never granted silently.** A passive that is simply on from level 1 is a rule the player has to be told about out of band, and if nothing tells them it is invisible combat math with extra steps. Make it the first node of the track that owns it, so the player meets it on a screen that explains it, at a moment when they are paying attention. Building Force is the case that proved it: authored, working, and forgotten by its own designer because nothing ever announced it. The corollary is that an introduced passive still has to be *observable* while it runs — introduction and visibility are two requirements, not one.

**The Stealth model, named once so it can be referenced.** An ability described as using it pays Energy *per second while active* and is *cancellable from the skills row*. Both halves are the point: the drain makes duration a live decision rather than a timer, and the cancel is what lets the player make it. A fixed duration on a cooldown has exactly one optimal policy — press it whenever it is up — which is not a decision. Stealth is the reference implementation (`STEALTH_DRAIN_PER_SECOND`, spent unscaled through `_spend_energy(charge, false)`).

**Two habits worth keeping.**

Prefer deriving a number over authoring it twice. Gale's launch speed is computed from the distance it should travel, so the tuned figure stays the tuned figure and only the delivery changed. A cooldown is derived from what an ability spends. Where two numbers must agree, compute one from the other.

One behaviour, one contract test. Two files asserting the same mechanic is how an assertion came to describe superseded behaviour while sitting in a suite that was already red. Integration tests assert their own boundary, not another file's internal timing.

**When the structure genuinely does not fit**, say so and change the structure rather than working around it. A bespoke solution beside a universal one is worse than either.

---

## Working agreements

**Do not write code until it is approved.** Design discussion is never authorization to change source. Present a plan, wait for a decision. This rule exists because it was violated before and cost real money.

**Challenge rather than agree.** Push back on proposals that conflict with the design pillars — including mine. Say when an idea is provisional, implemented, rejected, or unresolved. Agreement that isn't earned is worse than useless here.

**Verify documents against code.** Any document in this repo can be stale or wrong, including the ones above. When a document and the source disagree, the source is the fact — investigate rather than silently picking whichever is easier. Several errors in the attack-capture spec were found exactly this way.

**Explain the gist in plain language first, then the technical detail.** Keep the equations, tables, file references and derived numbers — the depth is wanted. Just don't make the idea something I have to reverse-engineer out of it.

**Preserve uncommitted work.** A dirty worktree is mine. Inspect it; never reset, discard or overwrite.

---

## Traps

- **Current behaviour is not automatically intended behaviour.** A passing regression can faithfully preserve the wrong prototype direction. Review test intent against the latest design decision before preserving it. The old combo regression once passed because every combo was seeded as held; the current test explicitly starts from a live hold, so do not revive that historical shortcut.
- **`run-tests.ps1` only counted `Assertion failed` and `SCRIPT ERROR` until `0.2.35`.** Test files that collect into a `failures` array print `FAILED:` and exit non-zero instead, and every one of them reported PASS no matter what it found. That hid real failures in five files, including the one carrying most of the milestone coverage. The runner now counts `FAILED:` and honours the exit code — but the lesson stands: when adding a test file, check that the runner can actually see it fail.
- **A late read is punished, and the Boar was the case that proved it.** Answered in `0.2.78`: reading an attack at the instant its wind-up ends must fail. The charge line is wider than the body that runs it, which is what a charge is. *How* late a read may be and still work is a tuning question the surveys own; that a late one is punished at all is settled.
- **A failing test that hangs now costs seconds, not the whole timeout.** Files that `assert()` directly inside `_init()`/`_initialize()` abort before their own `quit(0)`, so the process never exits and the failure presents as a hang. `run-tests.ps1` streams output to a file and watches it: a run that has already printed a failure and then goes quiet is hung, and it is killed and reported with its assertion line. Do not chase one of these with repeated full-suite runs — the runner names the line.
- **A bare Godot exit code is not a suite verdict.** Some test scripts can print an assertion or script error yet return zero, and a direct `_init()` assertion can prevent normal shutdown. The current `run-tests.ps1` checks output markers and exit codes and terminates a failed file that goes quiet; use its result, and verify any new test can be detected failing. This is a regression hazard, not a claim that the current runner ignores failures.
- **`run_state_test.gd` fails on `test_clean_opening_hit_preserves_a_defensive_choice`** as of `0.2.11`. The bandit strafes ~58 units laterally during the player's opening swing and leaves the 49° arc, so the strike misses entirely and its counter lands. This is the v0.2.8 interception-lane behaviour meeting a test written before it — a pursuit/contact question for Milestone E, not a post-hit-agency one. Do not "fix" it by weakening the assertion.
- **Choose the combat rule profile explicitly in tests.** A `RunState` instantiated without setup defaults to Recovery. Pass `"recovery"` or `"energy"` so a passing test means what its name claims; `"stamina"` is accepted only as a legacy alias.
- **Enemy locomotion runs on alternate ticks.** `_update_enemies(dt, _simulation_tick_index % 2 == 0)` means anything gated on `update_locomotion` needs a `× 2.0` step to hit its authored speed. The `dodge_strike` correction is already present; preserve it when changing enemy movement.
- **No content-first escape.** More enemies or rooms multiply a weak loop rather than repair it.
- **A familiar room is not a solved room.** Waystone is a continuous spatial simulation, not a tactics puzzle. There is no discrete move list to memorise, the instance is never recreated, and §6 withholds the numbers that would let deliberation become arithmetic. Knowledge of *enemies* accumulates permanently; solutions to *rooms* do not. Any reasoning that starts "the player already knows the answer, so this beat is empty" is starting from a false premise — discard the argument, not the beat. This mistake has been made repeatedly; see `docs/design-foundations.md` §4.5.
- **No health-only difficulty, no invisible combat math, no input-dexterity creep.** Difficulty comes from action selection, composition, terrain, partial information and resources.
- **Local checkout only.** Do not assume an older OneDrive tree is authoritative, and do not move the source into a synchronized cloud folder to reach tools.

---

## Verification

Use the narrowest test that can fail for the changed contract, then widen verification in proportion to what changed:

1. focused behavioral, schema, migration and determinism tests;
2. the full default `run-tests.ps1` suite, accepting only the exact documented expected failures;
3. repeated golden runs when projection, timing, RNG, save or world-object state changes;
4. renderer-dependent visual audits, with the generated frames actually inspected, for presentation work;
5. Windows and Android builds for a release package;
6. Pixel Fold checks in both orientations when controls, safe areas, rendering or Android behavior changes;
7. a real Combat Survey or playthrough when the claim is about feel, readability, tactics or balance.

Headless tests establish simulation behaviour, not visual truth. A green full suite does **not** justify saying “nothing broke”; state exactly which layers were verified and which were not. Validate contact, recovery animation, safe areas and readability in a real Windows renderer and on the Pixel Fold, which needs both orientations and its reported safe display area.

Use the next survey as a falsification test for a change, not as a demonstration that it must have worked.
