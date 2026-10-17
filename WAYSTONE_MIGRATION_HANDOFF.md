# Waystone migration and development handoff

**Updated:** 2026-10-17
**Release baseline:** `0.3.0` (`versionCode 300`, save schema `38`, expedition generator `1`, Combat Survey generator `3`, presentation `17`, Survey format `36`). Read `docs/current-state.md` and `docs/expedition-0.3.0-implementation.md` for current scope and verification limits.
**Authoritative checkout for current work:** `C:\Users\Trans\Documents\Codex\2026-07-12\if-2\waystone`  
**Purpose:** Give a new conversation, developer, or coding agent enough design, implementation, testing, and playtest context to continue Waystone without reconstructing the project from chat history.

This is an operational handoff, not a replacement for the detailed design documents. It records the current priorities and the latest decisions that supersede older prototype behavior. When this file, an older changelog entry, and the current code disagree, treat the disagreement as something to investigate rather than silently choosing whichever is easiest to implement.

> **Current-state addendum:** Read `docs/current-state.md` for the concise current boundary and
> documentation-maintenance contract. Much of the implementation narrative below deliberately preserves the
> `0.2.10` combat-loop diagnosis that motivated later work; it is historical evidence, not a current
> code inventory. For current implementation ownership read `CLAUDE.md`, then the implementation
> closeout at the end of `docs/code-structure-audit.md`, and finally `README.md` for release history.
> Releases `0.2.79`–`0.2.81` completed the approved measurement/presentation spine, catalogued
> perception correction and symmetric projectile-misdirection rule. Their full 19-file headless
> suite passed with one documented expected failure. The 2026-09-03 follow-up repeated that suite,
> inspected 19 real-renderer audit frames, built and verified both packages, and installed/read back
> `0.2.81` (`versionCode 281`) on the Pixel Fold over wireless ADB. That earlier Fold check found existing
> portrait and full-width landscape layout defects; its inner/unfolded display was not exercised.
> Two standard Elementalist runs were completed on `0.2.81`. They showed that the cheap, broad
> staff was carrying the opening game while Lightning Bolt was too weak and exposed, revealed a
> missing Lightning presentation contract, lethal spell kills that failed to alert surviving
> enemies, overlapping melee bodies that could deadlock movement, and interruption/walk-only
> telemetry that could misattribute causes. `0.2.82` is the focused response: expensive spells with
> compounding Intelligence discounts above baseline 5, a faster 13-damage Lightning Bolt, a
> 56-Energy staff sequence, simultaneous level-3 Main Class/Subclass access, strict collision with a
> narrow deterministic depenetration exception, and corrected presentation/awareness/telemetry
> ownership. Subsequent releases completed Mage/Warrior tuning and the first four boss-plan stages.
> `0.2.92` added Boss Lab, `0.2.93` added stable support relationships and lean exact-roster
> encounters, `0.2.94` differentiated Knife approach, and `0.2.95` rebuilt the solo Werewolf.
> That was the 0.2.95 work order. The October 17 approval supersedes it with a new,
> standalone three-biome expedition. Warden and Werewolf pack comparison are deferred.

### 0.3.0 closeout — October 17, 2026

The approved ascent is implemented and both platforms are built. All four characters
completed legal seed-42 journeys through three bosses and three one-use Waystones,
using earned resources and both adopted disciplines across the runs. The 100-seed
validator checks 300 maps. The default suite has 26 passing files and one documented
pre-existing Bandit failure, with no new accepted regression. Perfect-information test
players establish mechanical feasibility, not human fairness.

The final APK is installed and reads back as `0.3.0` / `300` on the Pixel Fold.
Physical portrait touch, map, frozen time, suspension and cold save/resume were checked;
the prior inactive save was restored exactly. Inner-display play, sustained combat
performance and human acceptance remain open. Artifact hashes, run evidence and repeat
commands are in `docs/expedition-0.3.0-implementation.md`.

## Executive migration brief

Waystone is an Android-first, PC-compatible tactical fantasy roguelike. Its defining rhythm is **deliberation followed by commitment**: time is frozen while the player is ready, then the player and world advance together while a chosen movement, attack, defense, skill, or item action resolves. Combat should be immediately readable and physically deterministic, yet generate difficult spatial and resource decisions from a reusable set of actors, weapons, conditions, terrain, and encounter rules.

At the `0.2.10` baseline, the combat loop was judged unacceptable. The Warrior · Vanguard survey was described as easy, repetitive, and unfun. Four failures then dominated:

1. ordinary movement still lets the player escape and herd melee enemies, so Dodge is usually optional;
2. Sweeping Cut is a universal, low-risk answer to grouped enemies;
3. the new held-combo implementation sometimes produces phantom continuation strikes without new player intent;
4. overlapping enemy attacks can repeatedly interrupt the player without leaving a usable response opportunity.

That diagnosis motivated the shipped input, capture, Energy, enemy, and encounter work; it is **not** a verdict on the current build. The current next step is human play of the implemented three-biome expedition. See `docs/current-state.md` for the live order.

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

A forward-directed, permadeath run. The approved 0.3.0 prototype is one mountain ascent
through Briarwild Foothills, the above-ground Cinderworks and Stormglass Summit. Each
standalone map has six main and two optional encounters, genuine quiet/preparation
space and its own new solo boss. Ordinary exploration has no room-clear locks.
Departing explicitly abandons the old map and its unused rewards forever. A defeated
boss unlocks one single-use restoration Waystone; it refills the original five-charge
pouch but not finite Rations, respawns nothing and is not a checkpoint. The final
Waystone and victory exit are separate. Seven-region/no-Waystone proposals are history,
not additional requirements for this prototype.

### Endless

Escalating survival and scoring. It can provide the repeatable combat laboratory and may eventually support a diminishing long-tail growth sink, but it should not dictate Campaign progression.

### Campaign

A finite, procedural, interconnected world organized around Waystones, recognizable geography, layers, and bidirectional shortcuts. Major geography remains stable during a campaign while bounded micro-arrangements may change after death.

Campaign world simulation uses discrete 2D layers. Collision, combat, awareness, line of sight, projectiles, hazards, navigation, shadows, and discovery normally operate only within the same layer. Stairs, ladders, lifts, tunnels, or portals create explicit bidirectional edges between layers. Do not replace this with continuous vertical physics.

The opening Campaign region is a friendly forest with several Waystones, natural geography, a local return toward the second Waystone, and a later underground ruin route that returns toward the first. A shortcut is meaningful only if the player has prior context for its near side, reaches the far side after real progress, materially shortens return travel, and recognizes its endpoints.

### Combat Survey

An endless, deterministic room laboratory rather than a shipping mode. It isolates encounter composition, geometry, character build, combat rules, and player feedback so changes can be compared before being propagated to Expedition or Campaign.

## 4. Historical implementation baseline at the original handoff

When this handoff was first written, the source identified itself as `0.2.10` with Android `versionCode 210`, survey generator version `3`, presentation version `7`, and report format `10`. The current baseline is recorded at the top of this file; the details in this section describe the earlier state that motivated the combat work.

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

## 6. Combat rules retained from the repair programme

These are the enduring rules or shipped outcomes, not a new implementation queue. The current profiles are Recovery and Energy; old Stamina-profile numbers in the historical diagnosis above are not live values.

1. **Physical attack commitment is shared.** Startup, contact, combo links, and terminal recovery do not change just because the resource profile changes.
2. **Non-attack abilities retain cooldown control where authored.** Removing an attack cooldown does not imply removing Rally, Advance, Stealth, Take Aim, or other non-attack cooldowns.
3. **Energy is the active resource profile.** Physical costs use their authored values with `ENERGY_COST_SCALE = 1.0`; spell costs are owned separately by spell rules and Intelligence. Recovery is the comparison profile. The old `STAMINA_COST_SCALE = 0.65` and Sweeping Cut exemption were `0.2.18` tuning, not current instructions. Exhaustion preserves a degraded defensive option rather than removing all agency.
4. **Walking's effectiveness depends on when it is used.** Early movement should often escape; late movement should often fail, leaving Dodge and other defenses meaningful. The old stationary-startup melee diagnosis was answered by authored attack travel and commitment distance. See `docs/attack-capture-implementation.md` for that shipped work.
5. **Travel and combat pace may differ.** Faster out-of-combat traversal is preferable to preserving excessive combat speed for convenience. Note this is now a secondary lever, not the primary fix.
6. **Short chained walking steps, not long committed strides.** A tap commits one short fixed step; a hold chains steps, and steering changes the next step rather than curving the current one. Walking has no Energy price and remains a first-class positioning/defensive tool. Do not turn those small steps into long quasi-Dodges, engagement slow fields, or extra turn restrictions without new evidence.
7. **No ordinary-movement perfect-dodge reward.** Clean-evasion benefits belong to authored defensive techniques such as Dodge or Vault.
8. **Sweeping Cut is rebuilt, not cosmetically nerfed.** It becomes the expensive immediate finisher described above.
9. **Continuation is sampled at the link, never banked.** A genuinely live input continues a sequence for as long as it is held; an input that has ended, or was never held at all, must not continue it. Held state may complete a sequence — that is the intended grammar — but only while the player is actually still holding.
10. **A hit must leave actionable control.** Post-hit non-interruption protection extends beyond recovery just enough to permit a response.

The Warrior · Vanguard has Dodge in its Defense slot. `Blocks: 0` and `Endures: 0` in its survey reports are generic-schema fields, not evidence that the player ignored available defensive buttons.

## 7. Historical implementation strategy and retained regression criteria

The original repair sequence below is preserved to explain causality and keep useful regression scenarios. It does not supersede the current Warden/Boss Lab work order.

### 7.1 Repair dependencies in the right order

The repair sequence fixed input integrity and post-hit agency before interpreting balance, then changed the movement/Dodge relationship before tuning encounter density. Sweeping Cut and melee differentiation followed the corrected movement baseline.

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

Tests that instantiate `RunState` without setup may default to Recovery. Always choose Recovery or Energy explicitly in combat tests so a passing test means what its name claims; `stamina` is a legacy alias.

### 7.6 Validate on real presentation targets

Headless tests establish simulation behavior, not visual truth. Validate contact, recovery animation, safe areas, controls, and readability in a real Windows renderer and on the connected Android device. The Pixel Fold requires both orientations and its reported safe display area.

## 8. Historical combat-repair roadmap

The early A–G roadmap has been closed or superseded. It is retained here as a
status record, **not** the current dependency order. Its detailed proposals and
reasons remain in the dated release history, `docs/combat-loop-diagnosis.md`,
`docs/attack-capture-implementation.md`, and
`docs/survey-archive-findings.md`. Follow `docs/current-state.md` for current work.

| Earlier milestone | Disposition at 0.2.95 |
|---|---|
| A — trustworthy input | Shipped: combo continuation follows live input. |
| B — post-hit agency | Shipped: protected response opportunity after a hit. |
| C — attack capture | Shipped: authored enemy attack travel and commitment distance; ordinary movement remains useful but timing-sensitive. |
| D — Sweeping Cut | Rebuilt and subsequently tuned under the Energy economy. |
| E — melee differentiation | Role/behaviour work and later enemy-specific revisions shipped; current kind contracts live in the catalogs and encounter design documents. |
| F — combat comparison | Old Recovery-versus-Stamina sequencing superseded. The agreed matched **Recovery versus Energy** comparison waits until boss pressure and a narrow journey slice are credible. |
| G — encounter grammar | Role-aware recipes, formations, exact-roster experiments, and lean encounters shipped. The mature journey generator and integration slice remain future work. |

Two early G proposals must **not** be revived as rules. First, a room does not
have to contain two conflicting demands, and a composition need not be barred
from recurring while its answer feels familiar. The user found a two-Archer,
low-melee-pressure room fun, and a familiar room is not a solved room. Pacing,
geometry, arrival state, and specific play evidence should decide repetition.
Second, the old Earth Caster/Duellist/Chanter candidate list and the claim that
the Ox had never been surveyed are historical; those kinds have shipped and the
Ox has since been surveyed and tuned.

The later boss/encounter programme superseded A–G's ordering. Its Updates 1–4
shipped through 0.2.95. The October 17 approval now places the three-biome 0.3.0
expedition ahead of Warden, Werewolf pack comparison and Recovery-versus-Energy.
Those legacy investigations remain deferred. Energy is the new expedition profile;
Recovery stays in comparison modes and legacy saves.

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
- combat rules (`Recovery` or `Energy`).

The generator is intended to give different characters and combat-rule profiles the same seeded room definitions so mechanics can be compared without silently changing the encounter. Preserve the entire header when sharing a report.

`Encounter` refreshes health, Energy, potions, conditions, and readiness between rooms. `Attrition` carries health, potions, and build progression through the run and permits survey level-ups when enough XP is held. Both are endless until death or manual end.

### 9.2 Per-room flow

After a victory, death, or manual final room, the game freezes and creates the objective room record. The player then supplies:

- Difficulty (`1–5`);
- Fun (`1–5`);
- Tactical interest (`1–5`);
- Want a room like this again (`1–5`);
- multi-select diagnostic tags;
- optional free-text notes.

If a room was too brief or otherwise impossible to judge, subjective feedback can be skipped while retaining objective telemetry. This is preferable to inventing ratings.

### 9.3 What current format 35 records

The run header records identity and compatibility data: versions, seeds, profile, combat rules, character, timestamps, end reason, and room count.

Each room records five broad groups:

1. **Encounter definition:** room seed, outcome, threat tier/band, pacing phase, recipe/family, cost, ranged pressure, arena, formation, enemies, roles, and current build.
2. **Attrition and performance:** entry/exit health, Energy, potions, combat time, damage dealt/received, hits, potion use, and death source.
3. **Resource/commitment behavior:** Energy spending, regeneration and overdraw, exhaustion and affordability exposure, combo/recovery timing, Dodge forms, action usage, and threat context.
4. **Presentation/contact evidence:** active view, view switches, empty melee contacts, and per-strike diagnostics including technique phase, result, targets, authored footprint, nearest enemy position, clearance, overlap, occlusion, enemy action, actor coordinates, facing, and weapon endpoints.
5. **Subjective response:** ratings, tags, and notes.

Boss Lab uses the same report authority but adds boss/setup identity, action and phase counts, visibility-at-commit, damage sources, posture/control evidence, and its own difficulty/fun/fairness/retry ratings. The current exporter in `scripts/core/survey_report.gd` is authoritative for exact fields; this summary is not a frozen schema.

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

Building, committing, pushing, and installing are part of finishing an approved numbered version,
not separate steps to be requested afterwards. Approval of the version authorizes its normal GitHub
release push and Fold deployment. For every approved numbered version:

1. run the relevant tests from `tests/` that cover the changed system;
2. keep version metadata in sync across `README.md` and `export_presets.cfg`, including the Android `versionCode`;
3. build both platforms;
4. create the release commit and push it to GitHub;
5. install it to the Pixel Fold and verify the installed package/version by read-back.

If the Fold is unavailable, still build both platforms, commit and push, but report the release as
awaiting device installation rather than complete. Only an explicitly unnumbered experiment or
local-only checkpoint may narrow this workflow. Preserve any pre-existing uncommitted work in the
worktree; it belongs to the user.

### Pixel Fold installation

To install a completed version:

1. verify the source version and Android version code in both `README.md` and `export_presets.cfg`;
2. run the relevant tests and build the Android debug APK;
3. use ADB to verify that the intended Fold is connected and authorized;
4. install with replacement (`adb install -r builds\android\waystone-debug.apk`);
5. read the installed package `com.waystone.prototype` back from the device and verify its version rather than treating a successful export as a successful installation;
6. report build, install, package, version, and device verification separately.

Installation is a deployment step after implementation and verification, not evidence that the design change works.

### Latest verified package boundary (`0.2.95`, 2026-09-20)

- The full 23-file headless suite passed with the single documented expected failure in
  `run_state_test/test_clean_opening_hit_preserves_a_defensive_choice`.
- Boss Lab is an isolated, repeatable mode (`0.2.92`); Shield/Chanter relationships and four
  lean exact-roster introductions shipped in `0.2.93`; Knife's stable flank promise shipped in
  `0.2.94`; the solo Werewolf's Hunting Leap, Double Rake, Bounding Rake, phase transition,
  collision, and deferred posture-break rules shipped in `0.2.95`.
- The renderer audit was regenerated and inspected, both Windows and Android packages were built,
  and Android package metadata and the installed Pixel Fold package read back as
  `com.waystone.prototype`, version name `0.2.95`, version code `295`.
- Save schema remains `37`; generator is `3`; presentation version is `16`; Combat Survey format
  is `35`.

### Previous verified package boundary (`0.2.91`, 2026-09-11)

- All 21 default test files pass, with the single documented expected failure in
  `run_state_test/test_clean_opening_hit_preserves_a_defensive_choice`.
- The real-renderer milestone audit regenerated its 13 frames. The larger Battle Flow pips and
  decay bar were inspected at the Fold's portrait aspect ratio, and the Ox's wind-up and committed
  charge remained visually legible.
- `0.2.91` gives the Ox a posture-governed control identity: ordinary weapon contacts no longer
  flinch it, a committed Gore ignores even forced hit reactions, and posture break, death, or solid
  terrain can still stop it. Battle Flow now remains active for `15` seconds after a qualifying
  contact or Advance refresh, up from `10`, with larger HUD pips and decay feedback.
- Combat Survey format `32` records Battle Flow gain, refresh, peak and loss causes; enemy reaction,
  posture-break and crash control; controlled time by enemy kind; and Ox Gore commitments, launches,
  pre-launch interruptions, and terrain crashes. Presentation version is `13`; save schema remains
  `37` because no persisted structure changed.
- Windows SHA-256:
  `7E0F8F035127A3ABADECCB7913D4B59212B5832705C0D2EEE7305474A1FD9691`;
  file and product version both read back as `0.2.91`.
- Android SHA-256:
  `76DFDEA9443EDED995A66E28C1B32ECCDEA7A383EC8B8EC767732054809A4E2E`;
  package metadata reads `com.waystone.prototype`, version name `0.2.91`, version code `291`.
- Fold installation remains pending. ADB reported no connected device and discovered no wireless
  debugging service on 2026-09-11, so a live pairing endpoint is required. The verified package and
  device deployment remain separate claims.

### Previous verified package boundary (`0.2.85`, 2026-09-05)

- All 19 default test files pass, with the single documented expected failure in
  `run_state_test/test_clean_opening_hit_preserves_a_defensive_choice`.
- The real-renderer milestone audit now includes an eleventh frame for Warrior/Vanguard. Rally's
  active aura and cancel control, four Battle Flow pips and their decay bar, and remaining action
  poise were visually inspected together at the Fold's portrait aspect ratio.
- `0.2.85` replaces the old Warrior/Vanguard tracks with sustained Rally, Resolve-derived action
  poise, Battle Flow, target-bound Advance, Method of Force and Constitution choices, Power
  Through, and Unbreakable. It also fixes authored enemy melee posture being dropped during action
  construction and carries authored posture through hostile projectile and hazard impacts.
- Save schema `37` retires active pre-overhaul Warrior runs with an explicit new-run notice because
  their ranks and permanent grants have no faithful mapping; other classes migrate normally.
  Combat Survey format `30` adds Rally, poise, Power Through, and Unbreakable measurements.
- Windows SHA-256:
  `7C297FA5DBF081541B5D1866A32B3C4E6A717477B12239C4D44124669BA8DF8C`;
  file and product version both read back as `0.2.85`.
- Android SHA-256:
  `C86CA6CEA759BEB96DA8C9D26AB4826011BCE931FBE61C7DB45472FB3B458283`;
  package metadata reads `com.waystone.prototype`, version name `0.2.85`, version code `285`,
  and APK signature v2/v3 verification passes.
- Fold installation remains pending. No authorized device was visible, mDNS discovered no wireless
  service, and the previously paired endpoint `10.0.0.3:36133` rejected the connection. The APK is
  verified independently of deployment and needs a fresh wireless-debugging endpoint if the Fold's
  port has changed.

### Previous verified package boundary (`0.2.84`, 2026-09-05)

- All 19 default test files pass, with the single documented expected failure in
  `run_state_test/test_clean_opening_hit_preserves_a_defensive_choice`.
- The real-renderer caster audit regenerated ten frames. Lightning is visible, the spellbook
  reports its new opening cost of `56`, and the streamed/frozen state cues remain intact.
- `0.2.84` replaces Steadier Cast with Studious, moves the Mage through Studious, Faster Cast,
  Learned, full-action Mobile Casting and Circle Mastery, and replaces the former flat discount
  and hard floor with the `9% / 6% / 3%` Intelligence bands. Save schema `36` grants an existing
  Mage rank I the new `+1` Intelligence exactly once.
- Windows SHA-256:
  `FF5798490FFCB051D0A2890D69FC7852A7363D03C310F5F637BC101A881AD5A9`;
  file and product version both read back as `0.2.84`.
- Android SHA-256:
  `AC2AA3C3B18C9413D8291054CCC266A13AA729084FD146F834F917EA19C76F06`;
  package metadata reads `com.waystone.prototype`, version name `0.2.84`, version code `284`,
  and APK signature v2/v3 verification passes.
- Fold installation remains pending. No authorized device was visible, and the previously supplied
  wireless endpoint `10.0.0.3:36133` rejected the connection. Treat the verified packages and the
  uncompleted device deployment as separate claims.

### Previous verified package boundary (`0.2.83`, 2026-09-04)

- All 19 default test files passed, with the single documented expected failure in
  `run_state_test/test_clean_opening_hit_preserves_a_defensive_choice`.
- `0.2.83` corrects the Vanguard Driving Impact description to match the implemented `10 -> 15`
  Advance damage, normalizes the projectile elevation-profile default to `flat`, and pins the
  already-correct Advance, Drawing Cut and Twin Fang Energy costs in regression tests.
- Windows SHA-256:
  `A0690348F4CC1DAB10BDD80FB00ABED18EF225BA5277AAF3326BBC919147CC1B`;
  file and product version both read back as `0.2.83`.
- Android SHA-256:
  `21A12D1C874F64CE867B657E53160CBFB114001988284107C8E6F04963C789E1`;
  package metadata reads `com.waystone.prototype`, version name `0.2.83`, version code `283`,
  and APK signature v2/v3 verification passes.
- `0.2.83` installation is pending: the Fold was not discoverable through ADB on 2026-09-04 and
  its previous wireless-debugging endpoint no longer accepted a connection. Package verification
  and device deployment remain separate claims; this approved release is not operationally closed
  until installation and installed-version read-back succeed.

### Earlier verified Fold installation (`0.2.81`, 2026-09-03)

- The caster and milestone renderer audits produced and received visual inspection of 19 frames;
  the new burn, frost, chant and misdirection cues were present in frozen and streamed state.
- Windows SHA-256:
  `A9017190C7574ACD09127D92CC3D02959FD680574AA8B6D52852AA88E4F2F293`.
- Android SHA-256:
  `C07DDEAE85B7C2E79B3920769586AD351C1215408331B7BBE11CF318C921434B`.
- Wireless install and package read-back succeeded on Pixel Fold serial `37031FDHS000C6`:
  `com.waystone.prototype`, version name `0.2.81`, version code `281`.
- Outer-display portrait and landscape were inspected and auto-rotation was restored. Portrait
  compresses the wide combat UI severely; landscape retains fixed-width background/header regions
  that do not fill the display. The inner/unfolded display remains unverified.
- This closes the `0.2.81` package and installed-version verification. The standard-profile
  Elementalist baseline was subsequently played twice and informed `0.2.82`; the layout findings
  still need a decision, and the revised Elementalist economy needs its own follow-up survey.

## 11. Source-of-truth map

- `WAYSTONE_MIGRATION_HANDOFF.md` — current operational priorities, latest decisions, roadmap, survey interpretation, and handoff procedure.
- `README.md` — implemented-version history, controls, local run/build instructions, and current version number.
- `docs/design-foundations.md` — the reasoning behind the design: lineage from Cardinal Quest 2, Dark Souls, and Hades, what is deliberately refused from each, the frozen-time and determinism commitments, mode architecture, world philosophy, the narrative layer, and a record of rejected directions. Read before making design decisions.
- `docs/battle-design-bible.md` — consolidated enemy, attack, encounter and boss principles, with an explicit credence and decision-status ledger plus recorded disagreements with the Dark Souls-derived enemy specification. Use it to prevent provisional suggestions from becoming silent rules.
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
- **No attack/non-attack cooldown conflation:** Physical attacks use authored commitment/recovery and, in Energy mode, resource cost. Authored non-attack abilities may still use cooldowns.
- **Literal costs with separate owners:** `ENERGY_COST_SCALE` remains `1.0`; physical action prices
  are authored as what the player pays. Spell prices bypass that lever and are modified only by
  spell-specific rules such as Intelligence and Circle. Do not use a global physical multiplier to
  solve a spell-economy problem.
- **Intelligence buys efficiency, not power:** baseline `5` pays full authored spell cost; points
  `6`–`10`, `11`–`15`, and `16+` multiply remaining cost by `0.91`, `0.94`, and `0.97` respectively.
  The thresholds are soft caps, not a stat ceiling or cost floor. Values below baseline receive no
  surcharge, and damage, magnitude, geometry and cast timing remain properties of the spell.
- **Casting movement does not weaken commitment:** Mobile Casting changes locomotion inside the
  full spell action. It does not return readiness during recovery, pause world time, retarget the
  committed spell, or express itself by applying the unrelated Exhausted condition.
- **No mode-topology conflation:** Expedition is a forward run; Campaign is a persistent interconnected graph around Waystones and shortcuts.
- **No false roadmap certainty:** Section 8 is a historical record, not the current order. Follow `docs/current-state.md`; assign version numbers and dates only when explicitly decided.

## 13. Open design and tuning questions

The following remain intentionally unresolved:

- Warden's final action timing, posture openings, phase sequence, and presentation;
- whether Boss Lab reports and ratings are sufficient to distinguish design difficulty from instrument defects;
- whether Werewolf is better as the validated solo remix or with the separately enabled Hound pack;
- whether the literal physical and spell costs create the intended competition across a sustained boss fight;
- the matched Recovery-versus-Energy result under the same boss setup;
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
5. Follow the current work order in `docs/current-state.md` unless the user explicitly reprioritizes.
6. For implementation, update code, focused regressions, survey telemetry, owning design docs,
   `docs/current-state.md`, README/version metadata, and exports together when applicable.
7. Validate simulation headlessly and presentation on a real renderer.
8. For every approved numbered version, build both platforms, create and push the release commit,
   install it to the Fold, and verify the installed package/version on the actual device. Treat
   approval of the numbered version as authorization for this normal release workflow.
9. Use the next survey as a falsification test for the change, not a demonstration that it must have worked.
