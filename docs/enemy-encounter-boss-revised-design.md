# Waystone Enemy, Encounter, and Boss Design — Implementation Revision

**Author:** Sol 5.6 independent revision
**Date:** 2026-09-14
**Inspected baseline:** 0.2.91, commit `af40685`
**Status:** Design proposal. This is not implementation approval and does not assign release numbers.

## Purpose

This document turns the broader ideas in [Enemy, Encounter, and First-Boss Design Package](enemy-encounter-boss-design.md) into the smallest coherent changes I would actually build. It reflects the current code, recent surveys, the [battle design bible](battle-design-bible.md), and the project's repeated experience that plausible complexity often fails to improve play.

The governing idea is simple:

> An enemy is distinct when recognizing it changes the player's next decision.

Different statistics, art, or attack names can support that distinction, but none establishes it. A new behavior earns its place only when an existing enemy does not already create the intended decision and the added state remains understandable during play.

## What I would keep, change, and postpone

| Area | Decision | Confidence |
| --- | --- | --- |
| Existing enemy repertoire | Preserve most attacks. Improve relationships and readability first. | High |
| Blade | Clarify its direct press and existing advancing cut. Add no new move initially. | High |
| Knife | Clarify the existing flank approach first. Add only a small committed close if needed. | Medium-high |
| Shield | Give authored encounters a stable protected ally. | High |
| Chanter | Communicate the buff it actually chose and its recipient. | High |
| Brute and Knight | Use simpler introductions and clearer tells before changing mechanics. | High |
| Encounter generation | Add a few exact-roster variants. Preserve the general generator. | High |
| Werewolf | Rebuild its existing pursuit vocabulary into legible committed actions. | Medium-high |
| Warden | Build a grounded boss around cleave, thrust, slam, and earned openings. | Medium-high |
| Boss Lab | Begin with repeatable fights and reliable reports. Expand when a concrete question requires it. | High |
| Werewolf with Hounds | Keep as a later comparison after the solo boss works. | Medium |
| Automated response search and pressure scoring | Postpone. They are not needed to make the first useful tests. | High |

The broad design document remains useful as a catalog of possibilities and failure cases. This revision determines what deserves the first implementation.

## Shared combat rules

### Commitment and information

An enemy chooses an action before its tell begins and carries that choice through the commitment. The tell communicates the action family, damaging direction or area, and whether a sequence continues after its first strike.

Enemy selection may use visible positions, facing, terrain, line of sight, phase, and visible actions. It must not inspect the player's Energy, future input, hidden cooldowns, or exact remaining recovery to choose the one attack the player cannot answer.

The game may punish late recognition and earlier positional mistakes. It should not introduce the decisive branch after the player has already committed to an answer that only that branch defeats.

### Openings

Normal attack recovery and posture-break openings are different:

- Normal recovery is part of the attack's authored risk. It starts when the attack or sequence actually finishes.
- A posture break is earned through accumulated posture damage. Hits during that opening do not refresh it indefinitely.
- The posture opening must last through the player's current commitment and then leave at least the established 0.72 seconds of world time. A longer boss-specific minimum can be tested only if players repeatedly earn openings they cannot use.
- Health damage always remains useful. Neither first boss requires posture damage to win.

Boss control begins with the least exceptional policy that works. Ordinary hits deal damage without repeatedly flinching a boss. Existing high-impact effects and posture damage keep their normal meanings. Each boss receives only the exceptions its moving or multi-hit actions require.

### Timing and geometry

Boss timings below are reference-world starting values for an unmodified boss. They must be converted once to the existing action clock and then remain subject to personal tempo and frost.

Movement and contact come from the same authored geometry. A move does not gain extra tracking, speed, or distance because it selected a target it cannot reach. A locked attack that misses should miss.

Presentation receives the action and phase selected by the simulation. It must not reconstruct gameplay state independently from elapsed time.

## Regular enemies

### Blade: preserve the direct attacker

Blade already has the needed foundation: it approaches directly and its diagonal cut advances 58 units. Its identity should be the enemy that makes the space directly in front of the player unsafe.

The first change is presentational and behavioral cleanup:

- Use an upright, direct approach rather than a flanking silhouette.
- Prepare the weapon on the side from which the existing diagonal cut will arrive.
- Preserve the chosen approach line long enough to read as pressure, while still using normal collision replanning when blocked.
- Display a clear finish and recovery after the advancing cut.

Do not add another lunge, armor, or a second attack in this slice. If Blade and Knife still feel interchangeable after both are readable, the evidence would then justify another mechanic.

### Knife: make the existing flank legible

Knife already receives flank lanes from shared pursuit behavior. Its first problem is communication, not the absence of flanking.

The first implementation should add a flank-preparation state within the existing approach:

- When pursuing a valid side lane, Knife lowers its posture and visibly points its weapons along that lane.
- It holds the chosen side unless terrain, collision, or a major target displacement invalidates it.
- When it reaches normal attack range, it uses the existing quick cut and existing timing.
- If it cannot establish a usable side for roughly 1.0 world second, it resumes normal direct pursuit. It does not stand still waiting for a perfect opportunity.

This creates a readable distinction: Blade presses the front while Knife asks whether the player is watching the side.

Only if this remains tactically indistinct should Knife gain a separate committed close. That experiment would add a short visible forward preparation of approximately 0.35–0.45 world seconds before the existing quick cut. The direction would lock when the close begins. It would replace part of the approach rather than add a 0.60-second wait followed by the complete old startup.

Knife must remain viable alone. It must not repeatedly retreat, become invulnerable while staging, or wait for the exact moment the player's recovery guarantees a hit.

### Shield: protect a real ally

Shield works best when the player can understand what it is screening. An authored screen encounter should assign one ward by stable entity ID at creation.

- Shield seeks a navigable point between that ward and the player.
- Candidate center spacing between Shield and ward is 140–220 units, adjusted for body sizes and terrain.
- Displacement is allowed to separate them and create a real opening.
- Shield does not snap back, teleport the ward, or select a different distant ward every decision tick.
- When the ward dies or becomes unreachable for a sustained interval, Shield uses its existing fallback frontliner behavior.

The presentation should make its body orientation and chosen ward readable. A short introduction cue can help, but the persistent evidence should be how Shield positions itself.

### Chanter: announce the actual support effect

Chanter already chooses between bulwark, haste, and ward. Give each choice a distinct preparation pose, shape, and sound, and show the intended recipients while the chant is still interruptible. Applied effects must use the same identity that was announced.

The first two authored tests should deliberately encourage different choices:

- Chanter + Brute + Blade for heavy support.
- Chanter + Blade + Knife for faster pressure.

The report records the effect actually selected. No healing, summoning, or extra attack is needed.

### Brute, Knight, and the chargers

Brute keeps its forward smash. Its preparation and displayed footprint should make lateral movement look and function like the answer. It does not need a radial attack that duplicates the Warden.

Knight keeps its long advancing thrust and heavy cleave. Test it first with one Archer so players can learn the distinction without the current Ice Caster and Bandit adding unrelated pressure.

Hound, Boar, and Ox retain their 0.2.91 behavior while these changes are evaluated. Hound vaulting, Boar shoving, and Ox commitment need evidence from the current build before another revision. Reports should distinguish terrain collisions, ally collisions, posture effects, and player interruption.

## First encounter variants

The first implementation needs four exact-roster variants, not the entire proposed catalog. Exact means the generator does not add bodies to satisfy its normal minimum.

| Variant | Roster | Intended decision |
| --- | --- | --- |
| `crossfire_light` | Archer ×2 | Choose which firing line to cross and which Archer to close first. |
| `screened_shot` | Shield + Archer | Change angle or displace Shield to reach its ward. |
| `pinch_and_escape` | Boar + Archer | Avoid or solve a developing pin around a short optional passage. |
| `knight_introduction` | Knight + Archer | Learn thrust versus cleave while one ranged line creates urgency. |

These variants test observations already supported by play: lean ranged groups can be enjoyable, a screen needs a defined relationship, and creating space from a developing pin can produce an excellent Vanguard moment.

`pinch_and_escape` must remain valid for every class. Vanguard may solve a developed pin with Dodge and Advance. Other classes can avoid entering it, leave before both exits close, interrupt an approach, or use their own movement and control tools. The arena must not spawn the player already sealed between threats.

Starting placement candidates:

- Crossfire lines diverge by roughly 50–100 degrees from the entry reference and the Archers begin at least 180 units apart.
- A screen pair starts on connected ground without overlap, at the Shield–ward spacing above.
- A static passage is at least the player's current diameter plus 20 units. Dynamic bodies can still narrow it during play.
- Cover breaks one important line from useful positions without automatically disabling both ranged enemies for the entire fight.

Try a bounded number of valid placement candidates, then use a named fallback formation for the same roster. If neither works in that arena, exclude the variant from that arena and record why. Do not add filler or remove a required enemy silently.

The remaining variants in the broad document become a backlog. Promote one when these four expose a concrete unanswered question.

## Minimal Boss Lab

The first Boss Lab should make current and revised bosses easy to retry and compare. It needs:

1. Explicit Werewolf or Warden selection, arena, supported real build preset, combat rules, and seed.
2. Full reset to the displayed starting HP, Energy, and normal potion count on every retry.
3. Retry same setup, change setup, and leave actions.
4. No Campaign progress, Expedition progress, XP, or persistent resource mutation.
5. A post-attempt screen containing difficulty, fun, fairness, desire to retry, and one optional free-text note.
6. A report containing boss actions begun, completed, interrupted and missed; damage sources; posture events and openings; phase transitions; player resources; deaths; and the exact experimental variant.

The mode must be registered explicitly rather than falling through to Expedition behavior. Retry must restore a versioned initial snapshot and seeded RNG state.

The first version does not need phase practice, imported journey arrival states, automated safe-response searches, or a large family of targeted questions. Those features should be added when a real test cannot be answered without them.

Instrumentation distinguishes action, contact, interruption, and damage. A single action may have several contacts, but it completes once. Interruption has one primary cause. Visibility is recorded when the tell begins and when the player commits, because visibility only at impact cannot establish fairness.

## Werewolf

### Identity

Werewolf pursues escape. Its leap forces the player to leave a committed line; its claws punish staying close without reading the complete sequence; its recovery rewards surviving the commitment rather than interrupting every startup.

Keep the current 210 HP and 14 posture capacity for the first mechanics test. Change health only in a separately identified tuning pass.

### Phase one repertoire

| Move | Starting timeline | Behavior |
| --- | --- | --- |
| **Hunting Leap** | 0.52 startup; up to 0.70 flight; 0.90 recovery after landing or range expiry | Lock direction at launch; travel cap 350; speed cap 500; one impact for 20 damage and 3 posture. |
| **Double Rake** | First contact 0.46–0.62; second contact 0.84–1.00; action ends 1.68 | Both strikes use the announced initial bearing; reach 148; each deals 12 damage and 3 posture. |

These values are intentionally closer to the current aggressive boss than the broad proposal. The current leap begins after roughly 0.32 world seconds and the first current claw after roughly 0.21. The candidates provide materially more notice without turning every attack into a long stationary windup.

The leap's crouch communicates its direction. It may face the player during the crouch, then locks at launch and does not steer in flight. Recovery begins at the actual landing or travel end.

Werewolf may make one short visible lateral stalk between attacks, moving at most 160 units over 0.50 world seconds. The stalk has no invulnerability. If an attack is not reachable, ordinary navigation continues instead of cycling decorative evades.

### Phase two candidate

At 55% HP, queue the phase transition until the current action, recovery, and any earned posture opening finish. Use a 1.0-world-second non-damaging posture change. Damage can still kill the boss before the transition.

Phase two adds **Bounding Rake**:

- 0.68 world seconds of visibly different preparation.
- Up to 0.60 seconds of locked flight with a 300-unit travel cap.
- One landing impact for 16 damage and 3 posture.
- A declared follow-up claw begins 0.36 seconds after actual landing, remains active for 0.16, and then leaves 1.0 second of recovery.
- Terrain collision cancels the claw and creates a 1.1-second crash recovery.

The longer preparation must visibly announce the follow-up before the player commits. It cannot look like Hunting Leap and reveal the claw only after landing.

### Collision and control

Werewolf's moving attacks should use the same charging movement and collision authority as other launched attacks. It can vault friendly Hounds while airborne but cannot pass through terrain, become untargetable, or repair a blocked landing by overlapping another actor. Each leap damages a target once.

Ordinary hits damage Werewolf without routine flinch. A posture break during grounded startup, grounded recovery, or stalking interrupts immediately. A posture break earned in flight is latched and executes at landing. A break earned during one claw contact executes immediately after that contact and cancels the next claw. Additional hits cannot postpone the break.

If ordinary play repeatedly prevents Werewolf from launching through full posture breaks, first examine posture damage and its reset cycle. Do not silently make the boss immune or repeatedly hold its posture just above zero.

### Pack experiment

The two-Hound form is a separate Boss Lab variant after the solo fight is readable. At the phase threshold, a howl announces two finite Hounds entering from visible legal positions. The variant keeps Hunting Leap and Double Rake and does not add Bounding Rake. It slows leap-family cadence while either Hound lives. Hounds do not respawn.

This comparison asks whether the expedition boss is better as a learned solo remix or as a pack leader. Do not combine both until one of them has independently earned its complexity.

## Warden

### Identity

Warden controls the ground in front of it. The player distinguishes a broad cleave, a narrow advancing thrust, and a radial slam, then uses the corresponding angle or recovery. Posture provides an earned alternative opening without becoming mandatory.

Keep the current 130 HP, armor 1, and posture capacity 18 for the mechanics test. If the fight ends before the player can learn its repertoire, test 180 HP as a separate HP-only condition.

### Phase one repertoire

| Move | Starting timeline | Behavior |
| --- | --- | --- |
| **Gate Cleave** | 0.95 startup; active to 1.13; action ends 2.20 | Broad forward sector near the current 194 reach; damage 20, posture 6; punish from the side or after recovery. |
| **Driving Thrust** | 0.72 startup; active to 0.94; action ends 1.95 | Narrow thrust near 230 reach; damage 20, posture 5; derive advance from capture geometry and lock the line. |
| **Ground Slam** | 1.08 startup; active to 1.26; action ends 2.48 | Radial footprint, starting radius 185; damage 22, posture 6; no persistent hazard or tracking drift. |

These values preserve Warden's deliberate character while avoiding a universal slowdown. The three preparations need different silhouettes: weapon to the side, centered forward, and raised vertically.

Selection uses valid geometry. Thrust serves the longer line, cleave the closer front, and slam close radial pressure. If no attack can reach, Warden advances through ordinary navigation. It does not use a second charge layer underneath the thrust.

### Phase two candidate

At 50% HP, queue a 1.0-second grip change under the same transition rules as Werewolf. Phase two adds **Gate Sequence**, announced from its first frame:

- Gate Cleave uses its normal first contact.
- A centered thrust begins at 1.78 and is active through 2.00.
- Recovery ends at 3.10.
- Both directions lock when the sequence begins in the initial implementation.

The phase-two silhouette must clearly differ from plain cleave. If that cannot be communicated on the Fold, phase-two cleaves should always become sequences so there is no visually ambiguous branch.

### Control

Ordinary hits damage Warden without routine flinch. Existing qualifying high-impact effects may interrupt grounded startup. Posture breaks execute immediately during approach, startup, and recovery. A break earned during the active contact window executes at its end. In Gate Sequence it cancels the remaining thrust. Further hits do not postpone the opening.

Track how often posture cancels startup. If the Warden consistently fails to act, adjust the specific posture economy or defer a startup break to the pre-contact boundary in a named experiment. Do not fall back to permanent mass-based posture holding, because that erases an earned result.

Start in an open arena. Test peripheral pillars only as a second condition after the three moves read correctly.

## Implementation segments

The design can be approved as a whole while implementation remains divided into six attributable updates.

### Update 1 — Testing foundation

Add exact-roster support and the minimal Boss Lab using the existing bosses. Give measurement access to both survey modes through the shared counter/reporting boundary. Add setup identity, seeded retry, mode isolation, and the compact rating screen.

**Exit condition:** the same setup can be replayed without changing persistent progress, and reported actions, contacts, damage, interruption causes, and resources reconcile.

### Update 2 — Support relationships and introductions

Implement Shield's stable ward, Chanter's actual buff tells, Blade/Brute/Knight presentation cleanup, and the four initial encounter variants.

**Exit condition:** exact rosters remain exact; no initial overlaps occur; ward and buff relationships are visible; existing encounters outside the named variants retain their composition rules.

### Update 3 — Knife differentiation

Implement readable flank preparation and stable side pursuit. Keep quick-cut timing unchanged. Add the short committed close only if the first version remains indistinct; if it is included in the same numbered update, protect it with an independently selectable experiment flag and report identity.

**Exit condition:** Knife stays active when alone, does not oscillate or wait indefinitely, and asks a visibly different positioning question from Blade.

### Update 4 — Werewolf solo

Unify moving contact and collision, implement phase/control state, then add Hunting Leap, Double Rake, Bounding Rake, and their presentation. Keep the pack variant disabled.

**Exit condition:** deterministic contact and save/retry behavior pass; the two leap tells remain distinguishable on the Fold; landing and crash openings are usable; posture events cannot disappear or postpone themselves.

### Update 5 — Warden solo

Implement Gate Cleave, Driving Thrust, Ground Slam, Gate Sequence, phase presentation, and the explicit posture policy using the shared boss state from Update 4.

**Exit condition:** each attack asks a different spatial answer; health-only and posture-oriented builds can both make progress; the Warden acts often enough to express its repertoire.

### Update 6 — Comparison and journey integration

Add the Werewolf pack variant and only the additional encounter cards needed to answer questions exposed by Updates 2–5. Compare solo remix against pack leadership. Embed selected encounters and bosses into a small Campaign and Expedition slice with explicit arrival resources.

**Exit condition:** production placement uses the same validated definitions as the lab; the run can distinguish boss design difficulty from arrival attrition; no survey-only reset behavior leaks into the journey.

Updates 1–5 can be implemented consecutively under one approval without requiring a subjective survey between each release. Each still receives its own version, focused tests, full regression suite, builds, commit, push, and Fold installation. Update 6 waits for play evidence because it chooses what enters the journey.

Within the boss updates, use internal commits for shared mechanics, phase-one repertoire, phase-two behavior, and presentation. These checkpoints support review and regression without turning every checkpoint into a public version.

## Architecture and verification

Use the existing canonical owners:

- `combat_catalog.gd` for enemy facts and melee technique definitions.
- `ability_catalog.gd` for enemy abilities, presentation identity, lifecycle, and execution descriptors.
- `run_state.gd` for simulation through existing action, movement, damage, posture, and effect boundaries.
- `state_field_schema.gd` and `runtime_schema.gd` for fields that cross projection, save, snapshot, or rendering boundaries.
- `survey_counter_catalog.gd` for measurements.
- `mode_rules.gd` for the explicit Boss Lab mode.
- `save_migrations.gd` and deterministic snapshots for compatible persisted state.
- `game_board.gd` for presentation driven by declared simulation state.

Boss phase, sequence segment, designated ward, and pending posture break need explicit defaults and lifecycle ownership if implemented. Their renderer fields need stable IDs and declared interpolation policies. Existing in-flight boss saves must either finish under preserved old semantics or fail with an explicit compatibility message; never reinterpret an airborne old attack halfway through loading.

Focused behavioral tests should cover freeze, selection locking, contact count, terrain and ally collision, phase thresholds, pending posture break, death precedence, retry identity, mode isolation, and exact-roster fallback. Run the full suite after each update. Presentation changes require real renderer inspection and Fold checks in both orientations.

Headless verification can establish deterministic behavior and reporting. It cannot establish whether Knife's approach or a boss sequence is readable, whether timing feels satisfying, or whether an encounter belongs in the journey. Those remain playtest questions.

## Decisions embodied in this revision

This revision recommends implementing the minimal foundation, support relationships, four lean encounter variants, readable Knife behavior, and solo versions of both bosses. It recommends more moderate boss windups than the broad proposal and a smaller initial Boss Lab.

It leaves boss health, final timing, the Knife close, Werewolf's pack form, pillar arenas, the larger encounter backlog, and journey frequency open to evidence.

It rejects global combat-economy changes for local enemy problems, hidden resource-aware enemy choices, universal attack tokens, mandatory posture kills, permanent boss interruption immunity, automatic anti-repeat logic, and a numerical encounter-quality score presented as established truth.
