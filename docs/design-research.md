# Waystone — design research

**Status:** comparative notes and historical evidence, relocated from Design Foundations on 2026-10-19. Measurements retain their original versions. External-game figures are the previously recorded research, not newly verified reference data. Current Waystone behavior is owned by source and [Current state](current-state.md).

[Design Foundations](design-foundations.md#inspirations) states what the inspirations contribute. This appendix preserves the supporting analysis and calibration details. Survey procedures and sample guidance belong to the [development handoff](../WAYSTONE_MIGRATION_HANDOFF.md#9-how-combat-survey-reports-work).

## Cardinal Quest 2 run structure

The original project investigation examined the APK data tables `plot.txt`, `plotpacks.txt`, `mobpacks.txt`, and `towerpacks.txt`. It recorded:

- Three acts of 7, 8, and 9 floors, with each floor owning its generator, tileset, enemy pool, loot table, and shop probability.
- Two-stage weighted encounter selection: an archetype followed by a formation. Floors combine many independently selected small formations.
- Enemy weights changing gradually across the run.
- A difficulty waveform of pressure, relief, disruption, and climax.
- An endless Tower structure of 20-floor tiers, divided into five four-floor blocks, each ending in a boss, with three enemy families roughly corresponding to the acts.
- 169 Steam achievements, including functional unlocks and commemorative goals.
- Routes and exits discovered through exploration.

The design application is an encounter grammar that gains variety through selection, formation, and pacing. Map size and roster size are separate variables.

## Action economy and class identity

The CQ2 comparison identified several useful relationships:

- Speed changes action economy. In Waystone, personal tempo accelerates voluntary actions; imposed reactions and condition durations have their own clocks.
- A compact set of actions gains depth through when and where each is used.
- Upgrades reshape a functioning starting skill set.
- Class identity is present from the first encounter.
- Limited capacity makes acquisitions compete with existing choices.
- XP, equipment, and consumables serve distinct purposes.
- Finite supplies create push-your-luck decisions within an Expedition biome.

These relationships are specified for Waystone in the [combat and character framework](combat-character-framework.md).

## Commitment and combat resources

The FromSoftware comparison separates five systems:

| System | Question it answers |
|---|---|
| **Recovery** | When may I choose again? |
| **Stamina** | How much more can I do before yielding initiative? |
| **Hitstun** | What is my immediate reaction to one impact? |
| **Poise / hyperarmor** | Does this committed action survive the impact? |
| **Posture / stance** | Has accumulated pressure earned a punish opening? |

The recorded design conclusion uses recovery as the primary commitment lever and a resource budget as a secondary limit on bursts of action. The long-term Recovery-versus-Energy question remains open for matched testing in Waystone.

Historical calibration notes:

- Dark Souls: approximately 100–160 stamina and 45 per second regeneration.
- Bloodborne: 100–160 stamina; a Saw Cleaver five-hit combo costs a full bar; dodge costs 10.
- Elden Ring: 96–142 stamina, approximately 45 per second regeneration, dodge 12, and heavy attacks 30–66. Recorded enemy stance values were approximately 15–65 for ordinary enemies and 80–120 for bosses, with regeneration of approximately 13 per second after a tier-scaled delay.

These figures are research references, not Waystone tuning targets. Souls' checkpoint comparison also treats rest, refill, leveling, enemy respawn, and death recovery as an interacting loop; [Campaign design](campaign-design.md) owns Waystone's proposed version.

## Attack anatomy and the commitment horizon

The comparison of Hollow Knight, Dead Cells, Hyper Light Drifter, Death's Door, Blasphemous, Salt and Sanctuary, Tunic, and related games recorded two useful patterns:

- Player attack: startup → brief active contact → recovery, with authored continuation where appropriate.
- Enemy attack: wind-up → commitment point → fast impact → recovery, with direction locking at commitment and recovery providing a punish opportunity.

The resulting **commitment horizon** rule is that a threat must be readable when the player commits if it can become unavoidable before the next decision. In detailed implementation terms, an enemy that was not visibly threatening at commitment should not both begin and land an unavoidable attack before that decision point.

The [attack-capture design](attack-capture-design.md), [implementation record](attack-capture-implementation.md), and [battle design bible](battle-design-bible.md) own the associated mechanics and evaluation.

## Six costs of an action

An action can spend **time**, **space**, **resources**, **initiative**, **information**, and **future options**. This is a diagnostic frame for comparing two tools that appear to solve the same problem.

For example, when a defensive technique sees little use, compare its full costs with those of ordinary movement. The historical [combat-loop diagnosis](combat-loop-diagnosis.md) investigates that relationship for its recorded source version.

## Composition evidence

The historical surveys support testing encounters that combine competing demands: waiting versus urgency, circling versus exposed ground, or watching a front-facing attack versus a flanking threat.

- In the `0.2.20` survey, rooms 4, 8, 10, and 11, which included ranged or area-denial pressure, scored 3/5 for fun and tactical interest; melee-only rooms scored 1–2.
- In `0.2.18`, Boar/Hound/Knife appeared three times. The first appearance scored 3/5 for fun; the second and third scored 1/5 across all axes, in different arenas and under different recipe labels. Repetition in a grading session can reduce the interest of assessment itself. These ratings do not isolate how the same recipe would feel during a real journey.
- The former foundations summary recorded a working cap of two simultaneous ranged-pressure enemies. This is a tested content heuristic from that period, not a permanent mode-wide limit.

The larger [297-room archive analysis](survey-archive-findings.md) retains its own versions, findings, and limitations. Survey comparisons can isolate encounter composition; conclusions about pacing also need a continuous journey with approach, scouting, arrival resources, and player-selected risks.

## Historical caster comparison

Before `0.2.57`, Fire Caster had served as a reference for distinctive readable pressure, while the old Ice cone could begin and connect within an already committed player action. Frost Lance and Cold Front replaced that cone in `0.2.57`. That observation describes the earlier abilities. The [elemental caster record](elemental-casters.md), source, and later play evidence describe their replacements.
