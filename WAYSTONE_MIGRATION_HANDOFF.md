# Waystone migration and development handoff

**Updated:** 2026-08-14  
**Current source baseline:** `0.2.10` (`versionCode 210`, Combat Survey format `10`)  
**Authoritative checkout for current work:** `C:\Users\Trans\Documents\Codex\2026-07-12\if-2\waystone`  
**Purpose:** Give a new conversation, developer, or coding agent enough design, implementation, testing, and playtest context to continue Waystone without reconstructing the project from chat history.

This is an operational handoff, not a replacement for the detailed design documents. It records the current priorities and the latest decisions that supersede older prototype behavior. When this file, an older changelog entry, and the current code disagree, treat the disagreement as something to investigate rather than silently choosing whichever is easiest to implement.

## Executive migration brief

Waystone is an Android-first, PC-compatible tactical fantasy roguelike. Its defining rhythm is **deliberation followed by commitment**: time is frozen while the player is ready, then the player and world advance together while a chosen movement, attack, defense, skill, or item action resolves. Combat should be immediately readable and physically deterministic, yet generate difficult spatial and resource decisions from a reusable set of actors, weapons, conditions, terrain, and encounter rules.

The project already has most of the ingredients for good combat, but the current combat loop is not acceptable. The latest `0.2.10` Warrior · Vanguard survey was overwhelmingly described as easy, repetitive, and unfun. Four related failures dominate:

1. ordinary movement still lets the player escape and herd melee enemies, so Dodge is usually optional;
2. Sweeping Cut is a universal, low-risk answer to grouped enemies;
3. the new held-combo implementation sometimes produces phantom continuation strikes without new player intent;
4. overlapping enemy attacks can repeatedly interrupt the player without leaving a usable response opportunity.

Combat-loop repair is the immediate project priority. More enemies, classes, biomes, campaign content, progression breadth, and encounter density should wait until moving, attacking, defending, and surviving pressure are satisfying in a small room.

## 1. Overarching goal

Build a tactical roguelike that is easy to control on a phone but supports long-term mastery through spatial judgment, action choice, commitment, and adaptation rather than rapid execution or opaque probability.

The intended player experience is:

- pause at a meaningful decision point because the simulation freezes when the player is ready;
- read enemy commitments, space, terrain, resources, and available tools;
- choose one understandable action;
- watch that action and the world resolve on one authoritative timeline;
- experience consequences that are deterministic enough to learn from;
- assemble a distinctive build during a compact run;
- encounter varied tactical stories from a small, reusable ruleset;
- eventually use the same combat language in a short Expedition, escalating Endless play, and a finite interconnected Campaign.

Waystone should feel deliberate without feeling inert, readable without being shallow, and challenging without relying on arbitrary misses, inflated health, or input-dexterity tests.

## 2. Enduring design pillars

### 2.1 Deliberation, then commitment

- Time freezes whenever the player is ready and has not committed an action.
- Startup, contact, movement, and recovery advance world time once an action begins.
- The cost of an action includes the opportunity it gives enemies, not only damage, stamina, or cooldown.
- Input windows should be generous enough for mobile and accessibility. The game tests decisions, not narrow button timing.

### 2.2 Deterministic physical combat

- Visible world-space weapon contact determines ordinary melee hits.
- Ordinary damage is fixed after explicit modifiers; do not add hit rolls or damage ranges to manufacture uncertainty.
- Attack rendering and collision must sample the same geometry and the same timeline.
- Randomness may select a contextually valid enemy action or encounter composition, but an action becomes deterministic once committed.

### 2.3 Depth through shared rules

- Players and enemies use the same actor attributes, action phases, posture, conditions, perception, damage events, and spatial rules.
- Character identity comes from combining and transforming shared verbs, not from isolated bespoke minigames.
- Starting characters must already possess a complete play loop. Upgrades develop that loop; they must not be required to make the character functional.

### 2.4 Mobile clarity first

- Touch controls must remain comfortable on phones and foldables, with keyboard/controller equivalents preserving identical simulation rules.
- Threats, health, stamina, posture, actions, recovery, cooldowns, targets, and interactables must remain readable.
- Android safe-area information is authoritative for the gameplay frame and HUD. The background may remain edge-to-edge, but camera cutouts and system insets may not cover health or controls.

### 2.5 Runs create most of the power growth

- Expedition and Endless builds develop primarily during the run.
- External progression should unlock possibilities, characters, challenges, achievements, cosmetics, and world variation rather than impose an obligatory permanent stat grind.
- Campaign progression is finite and authored. Its eventual cap should derive from intended purchases and arrive near the end of a normal campaign.

### 2.6 Candid, evidence-led iteration

- Treat survey criticism as evidence about systems, not a request for the smallest numerical patch.
- Challenge proposals that conflict with the pillars, including proposals from either the user or an implementer.
- State when an idea is provisional, implemented, rejected, or still unresolved.
- Do not turn exploratory discussion into a promised version number or schedule.

## 3. Modes and world structure

### Expedition

A short, forward-directed, default-permadeath run. It does not use Campaign Waystones or Campaign-style return loops. Its mature form should be a seven-part mini-adventure with several independently varied encounters, discoveries, rewards, optional dangers, and deliberate pressure/relief pacing inside each locale.

### Endless

Escalating survival and scoring. It can provide the repeatable combat laboratory and may eventually support a diminishing long-tail growth sink, but it should not dictate Campaign progression.

### Campaign

A finite, procedural, interconnected world organized around Waystones, recognizable geography, layers, and bidirectional shortcuts. Major geography remains stable during a campaign while bounded micro-arrangements may change after death.

Campaign world simulation uses discrete 2D layers. Collision, combat, awareness, line of sight, projectiles, hazards, navigation, shadows, and discovery normally operate only within the same layer. Stairs, ladders, lifts, tunnels, or portals create explicit bidirectional edges between layers. Do not replace this with continuous vertical physics.

The opening Campaign region is a friendly forest with several Waystones, natural geography, a local return toward the second Waystone, and a later underground ruin route that returns toward the first. A shortcut is meaningful only if the player has prior context for its near side, reaches the far side after real progress, materially shortens return travel, and recognizes its endpoints.

### Combat Survey

An endless, deterministic room laboratory rather than a shipping mode. It isolates encounter composition, geometry, character build, combat rules, and player feedback so changes can be compared before being propagated to Expedition or Campaign.

## 4. Current implementation baseline

The current source identifies itself as `0.2.10` with Android `versionCode 210`, survey generator version `3`, presentation version `7`, and report format `10`.

Implemented foundations include:

- Godot project with Android and Windows exports;
- isometric default presentation and mechanically identical top-down diagnostic view;
- authoritative 120 Hz combat contact and timing with presentation interpolation;
- streamed world regions and layer-scoped simulation;
- Warrior · Vanguard, Rogue · Acrobat, and Rogue · Sharpshooter;
- shared attributes, posture, deterministic damage events, conditions, perception, weapons, defenses, skills, progression tracks, and consumables;
- Expedition, Campaign Lab, and Combat Survey scaffolding;
- Recovery and Stamina combat-rule profiles;
- safe-area-aware HUD and gameplay aspect ratio for camera cutouts, including the Pixel Fold;
- reproducible Combat Survey generation, per-room feedback, internal archives, clipboard/share support, and Android text export;
- substantial headless regression coverage plus visual smoke tests.

Current `0.2.10` attack behavior is close to the target behavior but not identical to it. Sword and Knife phases have authored link points during recovery, and the implementation samples `continue_held` at each link rather than consuming it — which is the intended grammar described in §5.3. The defect is narrower: `request_combo()` seeds that state `true` unconditionally, so a sequence continues even when no input is live. A quick enemy tap consequently commits the whole sequence, because the tap path runs inside pointer release and never clears the flag. That is the source of the phantom combos.

Current Warrior movement speed is `260` world units per second versus a general player baseline of `300`. Current baseline Dodge speed is `560`. Sweeping Cut currently costs `34` stamina, uses a `158`-unit broad `160°` sector before upgrades, and starts a shared `4.2`-world-second skill cooldown. Those values describe the broken baseline; they are not protected balance targets.

## 5. Current combat-loop challenge

### 5.1 Movement invalidates defense

The problem is not merely that one movement constant is slightly high. The relationship among player travel, enemy pursuit, enemy attack tracking, attack forward travel, recovery, and collision lets ordinary steering preserve or recreate safety after engagement. The player can strafe, curve around a melee group, cause enemies to stack, and leave many threatened spaces without Dodge.

Consequences:

- Dodge becomes a nice-to-have instead of the Warrior's only equipped evasive skill;
- melee groups collapse into one herding problem regardless of their nominal roles;
- stamina regenerates while the player is already escaping, so overexertion is often harmless;
- broad attacks become even stronger because movement cheaply gathers targets;
- encounter count raises duration more reliably than tactical complexity.

The target is simple even if the implementation is systemic: **walking should succeed when the player reads a telegraph early and fail when they react late**, leaving Dodge and the other defensive techniques as the answer in the late window. Ordinary movement still serves approach, fine positioning, terrain use, and early avoidance of slow commitments.

The paragraph above lists player travel first among the contributing relationships. Source analysis since has established that **attack forward travel is the dominant term and player speed a distant secondary** — ordinary melee currently has none, and triggers at roughly its own maximum reach, so it cannot hit a moving player at any plausible speed. Read `docs/combat-loop-diagnosis.md` before acting on this section.

### 5.2 Sweeping Cut erases crowd decisions

Sweeping Cut currently combines too much reach, coverage, multi-target stopping power, low enough stamina cost, and manageable commitment. Adding or restoring a cooldown did not solve its underlying dominance. Its current identity allows the same strafe-and-sweep answer to solve melee rooms across threat tiers.

The approved redesign direction is to make it an immediate version of the Sword combo's third strike:

- similar geometry, damage, and posture language to the turning-slash finisher;
- usable without first committing the opening and returning cuts;
- substantially higher stamina cost for bypassing that setup;
- complete visible terminal recovery;
- governed as a physical attack by commitment, recovery, and Stamina rather than by an attack cooldown;
- shared physical timing in Recovery and Stamina modes, with the resource model remaining the modes' difference.

Exact cost and timing require playtesting. A cost in roughly the low-to-mid 50s is a starting experiment, not a settled value. The goal is not to preserve Sweeping Cut's current arc and compensate with a bigger number.

### 5.3 Phantom combo continuation

The desired input grammar has already been conceptually solved and should be restored directly:

- the initial qualifying touch/press commits the first strike;
- at each authored link point the sequence **samples whether a qualifying input is still live**; if it is, the combo flows into the next wind-up and skips the unused terminal recovery;
- releasing ends the sequence after the current strike completes;
- a single sustained hold may therefore produce one, two, or all three Sword strikes — and up to six with Twin Knives — depending purely on how long it is held. This is continuation by duration, not by repeated input;
- a renewed touch before the link restores a live input and resumes the sequence;
- the sampled state must reflect *actual* live input. A sequence begun by an input that is not held — a quick tap, a released key — must not sample as held;
- if no live input is present at the link, terminal recovery locks in and later input cannot reopen that combo;
- running out of Stamina may prevent the next continuation, but an already committed and paid-for strike completes normally.

This is deliberately not a consumed one-shot authorization. **Hold duration is a legitimate input dimension**, not a dexterity test: the link points are generously spaced, so lifting a finger between swings is a comfortable decision rather than a reaction check. The §12 guardrail forbids *reflex* demands — narrow cancel windows, pinpoint release timing — not timing as such. Requiring a fresh press per strike would trade a continuous, comfortable grammar for a repetitive one and buy no tactical depth for it.

This preserves deliberate combos without creating a dexterity game or automatically completing a sequence. Do not invent a narrow late-cancel window or a universal delayed-strike mechanic. The previously discussed optional slightly delayed Sword strike was explicitly dropped because its benefit did not justify the execution burden.

### 5.4 Crowd pressure can remove the response window

The problem reported as “stunlock” is not primarily repeated resetting of one reaction timer. Several attacks can arrive with timing that makes the next interruption unavoidable as control returns. The player must always receive a genuine chance to choose and execute a response after being hit.

The current preferred direction is temporary post-hit hyperarmor:

- taking a direct hit starts protection that covers the hit reaction and extends slightly beyond return of control;
- further hits may still deal health/posture damage, but cannot interrupt a new response during that protection;
- the protection does not refresh itself when those further hits land;
- it is long enough to begin a Dodge or another deliberate response, not long enough to enable a free offensive sequence;
- its exact post-control tail is provisional; approximately `0.3–0.4` world seconds is a sensible first test;
- telemetry should distinguish damage taken under this protection from interruptions prevented by it.

This is not blanket invulnerability, enemy freezing, or permanent crowd immunity. It guarantees agency, not safety.

### 5.5 Contact diagnostics still expose anomalies

The report can show misses that felt visually incorrect and occasional strike records with `none nearby` plus zeroed player/enemy/weapon coordinates. These may include target death/removal or probe-finalization edge cases, but they are not trustworthy evidence of correct contact. Fix report integrity alongside any actual collision defect so physical contact can be evaluated from reliable data.

## 6. Settled direction for the next combat revision

These rules apply across Recovery and Stamina modes unless explicitly stated otherwise:

1. **Physical attack commitment is shared.** Startup, contact, combo links, and terminal recovery do not change just because the resource profile changes.
2. **Non-attack abilities retain cooldown control where authored.** Removing an attack cooldown does not imply removing Rally, Advance, Stealth, Take Aim, or other non-attack cooldowns.
3. **Stamina remains the Stamina profile's resource.** It pays for physical attacks and exhaustion. Recovery mode retains its non-Stamina budgeting rules. Since `0.2.17` the model is: authored costs scaled by `STAMINA_COST_SCALE` (0.65 as of `0.2.18`, recalibrated after the first survey found exhaustion 5x too rare), continuous regeneration at 28/s with no delay on spending, and a 0.5s suppression only when hit. **Sweeping Cut is exempt from the scale** and costs its authored 56 outright; price parity with the sword combo could not restrain it, because an action that refills faster than its time advantage decays wins at any parity price. Emptying the bar exhausts you for 1.2s — attacks lock and walking drops to 45% (117 u/s), which is below the capture escape threshold of the fast enemies and above the slow ones. **Dodge is the one physical action exhaustion does not remove**, per rule 9's agency floor: it degrades to 90 units and 0.16s of i-frames, and pays in debt — the bar empties and the exhaustion clock restarts flat, never escalating.
4. **Walking's effectiveness must depend on when it is used.** Reacting to a telegraph early should usually succeed; reacting late should usually fail, leaving Dodge and the other defensive techniques as the answer. This supersedes the earlier framing of this rule, which asked for a player/pursuit speed relationship instead. `docs/combat-loop-diagnosis.md` establishes from the source that ordinary enemy melee cannot hit a moving player at any plausible speed, because attacks trigger at roughly their own maximum reach and then stand still through startup — so no player speed produces the required behavior. The mechanism is authored forward travel on enemy attacks; see `docs/attack-capture-design.md`.
5. **Travel and combat pace may differ.** Faster out-of-combat traversal is preferable to preserving excessive combat speed for convenience. Note this is now a secondary lever, not the primary fix.
6. **No committed-stride replacement.** Do not turn ordinary movement into a sequence of quasi-Dodges, engagement slow fields, or turn restrictions unless the simpler model later proves insufficient. Ordinary movement stays free, continuously steerable, and stamina-regenerating.
7. **No ordinary-movement perfect-dodge reward.** Clean-evasion benefits belong to authored defensive techniques such as Dodge or Vault.
8. **Sweeping Cut is rebuilt, not cosmetically nerfed.** It becomes the expensive immediate finisher described above.
9. **Continuation is sampled at the link, never banked.** A genuinely live input continues a sequence for as long as it is held; an input that has ended, or was never held at all, must not continue it. Held state may complete a sequence — that is the intended grammar — but only while the player is actually still holding.
10. **A hit must leave actionable control.** Post-hit non-interruption protection extends beyond recovery just enough to permit a response.

The Warrior · Vanguard has Dodge in its Defense slot. `Blocks: 0` and `Endures: 0` in its survey reports are generic-schema fields, not evidence that the player ignored available defensive buttons.

## 7. Implementation strategy

### 7.1 Repair dependencies in the right order

Fix input integrity and post-hit agency before interpreting balance. Then change the movement/Dodge relationship before tuning encounter density. Rebuild Sweeping Cut against the corrected movement baseline. Differentiate melee enemies only after the player has a functioning defensive loop.

Otherwise one broken system hides another: an overpowered sweep masks movement danger, excessive movement masks stamina exposure, and phantom attacks corrupt action-usage and exhaustion data.

### 7.2 Change relationships, not isolated constants

Movement acceptance depends on comparative outcomes:

- Can a player who is already inside a Blade's credible threat leave by walking?
- Can a Hound or Knife establish pressure without teleporting or unavoidable tracking?
- Does a deliberate Dodge create separation that walking cannot?
- Can early movement still avoid a slow telegraph when started before commitment?
- Does out-of-combat traversal remain tolerable?

Those scenarios remain the right acceptance tests. The variables are attack forward travel, commit distance, enemy pursuit and interception, attack tracking, recovery, arena geometry, and player combat speed — **in roughly that order of leverage**, which is the correction that source analysis produced.

The earlier `165–180` player-speed band is withdrawn as a starting hypothesis. Working back from the code, the speed at which current attacks begin connecting is 19–134 units per second depending on enemy, so no speed in that band changes the outcome, and any speed low enough to fix melee unaided would be a substantially slower game that also breaks the Sharpshooter's spacing loop. Player speed is a late lever; if it is used at all, roughly `200–215` is the range that makes walking lose to the slowest common melee pursuer without degrading traversal.

### 7.3 Preserve one authoritative simulation

- Keep combat contact/timing at the authoritative fixed step.
- Presentation interpolates state; it does not predict or replay a separate future.
- Use the same world-space geometry in isometric and top-down views.
- Keep seeds and rules independent of presentation.

### 7.4 Encode behavior as data where it multiplies value

- Weapon phases own startup, contact, link, recovery, geometry, damage, posture, and resource costs.
- Enemy profiles own pursuit, approach, attack selection, stability, and role-specific constraints.
- Encounter recipes own compatible roles, geometry, pacing, formation, budgets, and exclusions.
- Avoid loadout-specific conditionals when a shared capability or authored profile expresses the rule.

### 7.5 Build focused regression scenarios

Every combat change should have small deterministic tests before a long survey:

- one tap produces exactly one Sword strike;
- a hold released between two links produces exactly the strikes its live window covered;
- an input that was never held cannot continue a sequence;
- a sustained hold completes the sequence, and releasing stops it within one strike;
- a continuation before the link skips recovery, while input after terminal lock cannot reopen it;
- a hit reaction ends with a protected response opportunity;
- additional hits during protection damage but do not interrupt or refresh protection;
- walking fails to escape an established representative melee threat;
- Dodge succeeds in the same setup;
- Sweeping Cut matches intended finisher geometry and pays the intended commitment/cost;
- strike diagnostics never serialize missing geometry as a believable combat sample.

Tests that instantiate `RunState` without setup may default to Recovery. Always choose Recovery or Stamina explicitly in combat tests so a passing test means what its name claims.

### 7.6 Validate on real presentation targets

Headless tests establish simulation behavior, not visual truth. Validate contact, recovery animation, safe areas, controls, and readability in a real Windows renderer and on the connected Android device. The Pixel Fold requires both orientations and its reported safe display area.

## 8. Planned roadmap

This is the current dependency order, not a promise of release numbers or dates.

### Milestone A — Restore trustworthy player input

Make combo continuation faithfully reflect live input. The link-point sampling in `_update_player_combo` is already the intended grammar and should be preserved; the work is removing the unconditional seeding in `request_combo()` that grants continuation to every sequence regardless of input, ensuring every input path clears the state on release, and adding touch plus keyboard regression coverage.

**Exit criteria:** A quick tap produces exactly one strike; a sustained hold produces as many strikes as its live window covers links, and stops within one strike of release; no continuation ever occurs without a live input behind it; combo links still feel generous rather than timing-sensitive.

### Milestone B — Guarantee post-hit agency

Implement non-refreshing post-hit hyperarmor through reaction and briefly beyond control return. Add visible/diagnostic state and crowd timing tests.

**Exit criteria:** A player who survives a hit always receives at least one executable response choice; subsequent pressure remains damaging but cannot chain unavoidable interruptions.

### Milestone C — Attack capture

Give enemy melee attacks authored forward travel during startup, derived per attack from a stated walk-safe fraction of the telegraph, and control the distance at which enemies commit so that fraction is a real quantity rather than a side effect of the steering interval. Remove the ordinary-movement clean-evasion reward. See `docs/attack-capture-implementation.md`.

Player movement speed, decision granularity and arena geometry are held back as later levers, to be reconsidered only once capture is working and measured. They are not part of this milestone.

**Exit criteria:** Reacting early to a telegraph usually escapes by walking; reacting late usually does not, and Dodge does; different attacks demand different spatial answers rather than one universal retreat; walking remains free, smooth and useful for positioning; combat does not become sticky, jittery, or input-limited.

### Milestone D — Rebuild Sweeping Cut

Replace the oversized universal sweep with an expensive immediate turning-slash finisher, including full terminal recovery and shared physical timing. Remove its attack cooldown; preserve cooldowns for non-attack abilities.

**Exit criteria:** Sweeping Cut is a meaningful commitment that can answer a well-read crowd but cannot be cycled as the dominant basic attack; the normal combo remains worthwhile because it earns the finisher more efficiently.

### Milestone E — Differentiate melee enemy decisions

Give Boar, Hound, Knife, Bandit, Blade, Polearm, and command units substantially different spatial demands rather than speed/damage variations on the same chase. Use roles, startup, tracking, stability, recovery, coordination, and terrain interaction to create different answers.

**Exit criteria:** A player can name the required response to each role; changing a melee composition changes priorities and positioning; enemies do not collapse into a single herd for broad damage.

### Milestone F — Re-survey and tune the combat kernel

Run short seeded A/B surveys across both combat profiles after the preceding systems are stable. Compare equivalent recipes and geometry before changing generator weights.

**Exit criteria:** Dodge is used because situations demand it; Stamina/exhaustion create real decisions; fun and tactical-interest ratings improve without a corresponding rise in unfair/unclear-contact reports; no dominant universal tactic replaces strafe-and-sweep.

### Milestone G — Validate encounter grammar

Only after the combat kernel passes, use survey evidence to author and weight encounter archetypes, exclusions, formation rules, pacing, and role gaps. Add the smallest number of enemies needed to fill demonstrated language gaps.

**Exit criteria:** Two seeds create meaningfully different tactical stories from the same biome and roster; pressure and relief are deliberate; geometry and composition both matter.

### Later product roadmap

After the combat gate:

- expand and audit the Warrior/Rogue roster, then design the next main class;
- mature equipment, consumables, rewards, discoveries, achievements, and unlocks so identity is not concentrated in skill buttons;
- rebuild the Friendly Forest Expedition around validated nested encounters and pacing;
- apply the shared encounter kernel to Campaign-specific persistent topology and return routes;
- complete Campaign Waystone, death-memory, shortcut, finite-level, Adopted Track, and secondary-loadout systems;
- extend locales/biomes only on the validated world and encounter grammar;
- tune Endless as its own escalation and long-tail system;
- perform Android/Windows performance, accessibility, save migration, and release packaging work at every stable milestone.

## 9. How Combat Survey reports work

### 9.1 Run setup and reproducibility

Combat Survey generates deterministic rooms from:

- game version;
- report format;
- run seed;
- survey generator version;
- presentation version;
- room number;
- selected character;
- resource profile (`Encounter` or `Attrition`);
- combat rules (`Recovery` or `Stamina`).

The generator is intended to give different characters and combat-rule profiles the same seeded room definitions so mechanics can be compared without silently changing the encounter. Preserve the entire header when sharing a report.

`Encounter` refreshes health, stamina, potions, conditions, and readiness between rooms. `Attrition` carries health, potions, and build progression through the run and permits survey level-ups when enough XP is held. Both are endless until death or manual end.

### 9.2 Per-room flow

After a victory, death, or manual final room, the game freezes and creates the objective room record. The player then supplies:

- Difficulty (`1–5`);
- Fun (`1–5`);
- Tactical interest (`1–5`);
- Want a room like this again (`1–5`);
- multi-select diagnostic tags;
- optional free-text notes.

If a room was too brief or otherwise impossible to judge, subjective feedback can be skipped while retaining objective telemetry. This is preferable to inventing ratings.

### 9.3 What format 10 records

The run header records identity and compatibility data: versions, seeds, profile, combat rules, character, timestamps, end reason, and room count.

Each room records five broad groups:

1. **Encounter definition:** room seed, outcome, threat tier/band, pacing phase, recipe/family, cost, ranged pressure, arena, formation, enemies, roles, and current build.
2. **Attrition and performance:** entry/exit health, stamina, potions, combat time, damage dealt/received, hits, potion use, and death source.
3. **Resource/commitment behavior:** stamina spend/depletion/overdraw/regeneration, regeneration delay/active time, exhaustion lockouts and exposure, damage taken while exhausted and slowed, desperate Dodge count and longest chain, actions refused for Stamina and time spent unable to afford a basic attack, threat context (alerted count, nearest, committed attacks pending) at both ends of every lockout, blocked combo continuations, terminal combo recoveries and recovery exposure, direct attack-control uses, Dodge form/recovery exposure, and action counts.
4. **Presentation/contact evidence:** active view, view switches, empty melee contacts, and per-strike diagnostics including technique phase, result, targets, authored footprint, nearest enemy position, clearance, overlap, occlusion, enemy action, actor coordinates, facing, and weapon endpoints.
5. **Subjective response:** ratings, tags, and notes.

The `Blocks` and `Endures` counters exist because the report schema supports characters that equip those defenses. Interpret them against the build line. Do not infer that a Warrior · Vanguard failed to use unavailable skills.

### 9.4 Report lifecycle and export

- The active survey session autosaves internally as `combat-survey-current.json`.
- Completed runs are archived internally, newest first, with at most 100 runs retained.
- A UTF-8 text report is also written inside the app's survey-report directory.
- The report screen can copy, share, or save the current report.
- On Android, direct export publishes to `Downloads/Waystone`; a failed export copies the full report to the clipboard and displays the failure.
- The archive can export all retained reports in one combined text file.

The practical handoff workflow is to export or copy the complete text and paste it into the development conversation without editing away headers, rooms, strike diagnostics, ratings, tags, or notes.

### 9.5 How reports should be analyzed

- Start with repeated qualitative complaints, then test whether telemetry supports the proposed cause.
- Compare matching generator/presentation versions and seeded rooms when attributing a change to combat rules or a build.
- Separate composition, geometry, player mechanics, and presentation/contact failures.
- Do not optimize only for average ratings. Deliberate spikes, relief rooms, and unusual situations are valuable when fair and legible.
- Do not treat a victory as proof of fun, difficulty, or correctness.
- Do not treat high stamina spending as meaningful pressure if movement still creates free safety.
- Read notes alongside `Empty melee contacts` and strike diagnostics when contact feels wrong.
- Treat `none nearby`/zero-coordinate probe records as a report-integrity warning until explained.
- Convert successful patterns into reusable encounter archetypes and failed patterns into exclusions; do not copy one room verbatim.

## 10. Validation, build, and installation handoff

### Relevant checks

At minimum, combat work should run the focused tests that cover the changed system and the broader state/survey suites:

- `tests/run_state_test.gd`
- `tests/stamina_test.gd`
- `tests/warrior_character_test.gd`
- `tests/combat_survey_test.gd`
- `tests/strike_diagnostic_smoke.gd`
- `tests/attack_button_visual_smoke.gd`
- `tests/safe_area_visual_smoke.gd`
- relevant render/performance smoke tests when presentation or crowd simulation changes.

Also verify a real rendered encounter. Dummy/headless rendering is not visual proof.

### Builds

- `build-android.ps1` produces `builds\android\waystone-debug.apk`.
- `build-windows.ps1` produces `builds\windows\Waystone.exe`.
- `build-all.ps1` exports both.
- `run-prototype.ps1` runs the project in Godot.
- `run-windows.ps1` builds the Windows executable if needed and launches it.

The scripts discover ignored local tool directories and an existing local Waystone toolchain. Do not move the source back into a synchronized cloud folder merely to reach those tools.

**Every code change ships to both platforms.** Use `build-all.ps1` rather than exporting a single target, so Windows and Android never drift apart in version or behavior.

### Completing a code change

Building, committing, and installing are part of finishing a code change, not separate steps to be requested afterwards. For every code change:

1. run the relevant tests from `tests/` that cover the changed system;
2. keep version metadata in sync across `README.md` and `export_presets.cfg`, including the Android `versionCode`;
3. build both platforms;
4. commit the change to GitHub;
5. install to the Pixel Fold if it is connected.

If the Fold is not connected, still build both platforms and commit, and say that the install was skipped for that reason. Preserve any pre-existing uncommitted work in the worktree; it belongs to the user.

### Pixel Fold installation

To install a completed version:

1. verify the source version and Android version code in both `README.md` and `export_presets.cfg`;
2. run the relevant tests and build the Android debug APK;
3. use ADB to verify that the intended Fold is connected and authorized;
4. install with replacement (`adb install -r builds\android\waystone-debug.apk`);
5. read the installed package `com.waystone.prototype` back from the device and verify its version rather than treating a successful export as a successful installation;
6. report build, install, package, version, and device verification separately.

Installation is a deployment step after implementation and verification, not evidence that the design change works.

## 11. Source-of-truth map

- `WAYSTONE_MIGRATION_HANDOFF.md` — current operational priorities, latest decisions, roadmap, survey interpretation, and handoff procedure.
- `README.md` — implemented-version history, controls, local run/build instructions, and current version number.
- `docs/design-foundations.md` — the reasoning behind the design: lineage from Cardinal Quest 2, Dark Souls, and Hades, what is deliberately refused from each, the frozen-time and determinism commitments, mode architecture, world philosophy, the narrative layer, and a record of rejected directions. Read before making design decisions.
- `docs/design-brief.md` — concise enduring product promise, modes, world foundation, and design pillars.
- `docs/combat-character-framework.md` — detailed shared combat/character architecture and concrete Rogue specifications. It is an authoritative design target where not superseded by later playtesting, but exact balance values are provisional.
- `docs/expedition-encounter-redesign.md` — deferred data-driven encounter/Expedition plan. It explicitly depends on successful Combat Survey analysis.
- `docs/combat-loop-diagnosis.md` — source-grounded analysis of why the `0.2.10` combat loop fails. Establishes that ordinary enemy melee cannot hit a moving player at any plausible speed, which supersedes the movement-speed framing in §5.1 and §7.2 above.
- `docs/attack-capture-design.md` — the resulting design: enemy attacks advance during startup, with per-attack forward travel derived from an authored walk-safe fraction. Read with the diagnosis.
- `docs/attack-capture-implementation.md` — code-level specification for the above: data schema, the `melee` branch change, commit-distance control, authored values, and the test contract.
- `scripts/core/run_state.gd` — authoritative simulation and current combat behavior.
- `scripts/core/combat_catalog.gd` — actor, weapon, ability, and progression definitions.
- `scripts/core/attack_geometry.gd` — authored attack footprint definitions.
- `scripts/core/survey_report.gd` — report schema, persistence, archive, and text serialization.
- `scripts/presentation/game_board.gd` — input classification, HUD/layout, report UI/export, and presentation behavior.
- `tests/` — executable behavioral contract. Tests may encode a regression, as the current held-combo tests do; test intent must be reviewed against the latest design decision before preservation.

## 12. Important guardrails and known traps

- **Local versus cloud:** Current work is in the local checkout named at the top. Do not assume an older OneDrive Games tree is authoritative. Cloud synchronization has previously complicated file discovery and performance.
- **Dirty worktree:** Existing uncommitted changes belong to the user. Inspect and preserve them; do not reset, discard, or overwrite unrelated work.
- **Current behavior is not automatically intended behavior:** A changelog and passing regression can faithfully preserve the wrong prototype direction.
- **No content-first escape:** More enemies or rooms will multiply a weak loop rather than repair it.
- **No health-only difficulty:** Difficulty should use action selection, compositions, terrain, partial information, resources, elite properties, and rule changes.
- **No invisible combat math:** Do not hide an apparent physical hit behind a random miss chance.
- **No input dexterity creep:** Generous continuation decisions are compatible with commitment; narrow cancel timing is not the present goal. This forbids *reflex and pinpoint accuracy*, not timing as such. Hold duration is a legitimate input dimension wherever the windows are generous enough that releasing between commitments is comfortable — that is a decision, not a reaction check.
- **No universal button assumptions:** A character equips one Defense. Generic telemetry fields do not mean every character can Dodge, Block, and Endure simultaneously.
- **No attack/non-attack cooldown conflation:** Physical attacks use authored commitment/recovery and, in Stamina mode, resource cost. Authored non-attack abilities may still use cooldowns.
- **No mode-topology conflation:** Expedition is a forward run; Campaign is a persistent interconnected graph around Waystones and shortcuts.
- **No false roadmap certainty:** Milestones above are an order of operations. Assign version numbers and dates only when explicitly decided.

## 13. Open design and tuning questions

The following remain intentionally unresolved:

- final player combat movement speeds and out-of-combat travel rule;
- exact pursuit, attack tracking, and forward-travel values for each melee role;
- exact post-control duration and feedback for post-hit hyperarmor;
- exact Sweeping Cut stamina cost, recovery, damage, and posture after adopting finisher geometry;
- whether an already committed combo continuation may overdraw Stamina under every profile edge case;
- final Stamina costs, regeneration tuning, exhaustion threshold, and possible future Dodge cost;
- experienced-player difficulty structure and degree of probabilistic enemy action selection;
- which melee roles need redesign before adding any new enemy;
- Campaign level cap, extra Temperament purchases, Adopted Track catch-up, and secondary-loadout progression;
- exact Campaign death micro-arrangements and the long-tail Endless growth model.

Resolve these through focused prototypes and surveys. Do not fill them in from genre convention alone.

## 14. Handoff checklist for the next conversation

1. Confirm the current working directory is the local checkout at the top of this file.
2. Read this file, then the relevant detailed design/code files from the source-of-truth map.
3. Inspect `git status` and preserve all user changes.
4. Confirm the current version before describing implemented behavior.
5. Keep the immediate task within the combat-loop milestones unless the user explicitly reprioritizes.
6. For implementation, update code, focused regressions, survey telemetry, README/version metadata, and exports together when applicable.
7. Validate simulation headlessly and presentation on a real renderer.
8. Build both platforms and commit to GitHub as part of every code change; install to the Fold when it is connected, then verify the installed package/version on the actual device.
9. Use the next survey as a falsification test for the change, not a demonstration that it must have worked.

