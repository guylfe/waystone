# Waystone current state

**Reviewed:** 2026-09-23
**Source baseline:** `0.2.95` (`versionCode 295`, save schema `37`, generator `3`, presentation `16`, Combat Survey format `35`)  
**Authority:** current source and tests define implemented behaviour; this file is the concise operational map. `README.md` remains the release history and the other design documents retain rationale, evidence, rejected alternatives, and future targets.

## What exists now

- Four playable profiles: **Warrior · Vanguard**, **Rogue · Acrobat**, **Rogue · Sharpshooter**, and **Mage · Elementalist**.
- Four working weapon frames in player use: Sword, Knife, Bow, and Staff.
- The shared combat kernel includes committed actions, attack capture, Energy and Recovery rule profiles, exhaustion, Dodge, posture, Resolve-derived action poise, conditions, projectile elevation and misdirection, barriers, deterministic save/snapshot support, and survey attribution.
- Fire, Ice, Earth, and Air casters and all eight elemental abilities are implemented. The Elementalist can inherit one spell from each element; Intelligence reduces spell cost through the implemented soft-cap curve without increasing spell damage.
- The Warrior/Vanguard redesign is live: sustained Rally, Battle Flow, Advance, Resolve-derived action poise, Power Through, and Unbreakable. Battle Flow is sequence-based and currently decays after 15 seconds.
- The encounter layer has role-aware recipes, deliberate formations, guaranteed non-melee pressure in ordinary mixed generation, exact-roster experiments, and Combat Survey `Encounter` and `Attrition` profiles. This is a testing/encounter grammar, not yet the final Expedition journey generator.
- Ordinary walking is a chain of short committed steps: a hold repeats them and steering affects the next step. It remains a free tactical defense, but is not steerable within a step. The Ice Caster's old cone complaint predates Frost Lance and Cold Front and is not a standing verdict on current Ice.
- Boss Lab is implemented as a repeatable, isolated evaluation mode. The current Werewolf solo redesign is live with Hunting Leap, Double Rake, and Bounding Rake; its pack form remains disabled for comparison. Warden still uses provisional behaviour and is the next boss-design implementation target.

## Current work order

1. Implement and verify the **Warden solo redesign**: Gate Cleave, Driving Thrust, Ground Slam, Gate Sequence, phase presentation, and its explicit posture policy.
2. Play and survey the Boss Lab as an instrument as well as the bosses. Tune only the owner isolated by evidence.
3. Compare the Werewolf solo remix with its optional pack condition, then choose what belongs in production encounters.
4. Integrate only validated boss and encounter definitions into a small Expedition/Campaign slice with explicit arrival resources.
5. Run the matched **Recovery versus Energy** comparison after the boss pressure test is credible.
6. Return to the mature Expedition journey rebuild and Campaign topology only after the combat/boss gate provides usable evidence.

No future item has a release number or date until it is explicitly approved.

## Document authority and status

| Document | Use now |
|---|---|
| `docs/current-state.md` | Current implementation boundary and next work. Update with every material change. |
| `docs/design-foundations.md` | Enduring design intent, constraints, refusals, and long-term scope. |
| `docs/battle-design-bible.md` | Credence-rated enemy, encounter, and boss principles. |
| `docs/combat-character-framework.md` | Shared actor, combat, character, and progression design. Implemented facts must still be checked against source. |
| `docs/elemental-casters.md`, `docs/warrior-vanguard-redesign.md` | Implemented programme records plus retained design history. |
| `docs/enemy-encounter-boss-revised-design.md` | Active six-update boss/encounter plan: Updates 1–4 shipped; Update 5 is next; Update 6 waits for evidence. |
| `docs/expedition-design-principles.md`, `docs/journey-design-principles.md`, `docs/expedition-encounter-redesign.md` | Future-mode design targets. They do not describe the current generator as complete. |
| `docs/combat-loop-diagnosis.md`, `docs/attack-capture-design.md`, `docs/attack-capture-implementation.md`, `docs/survey-archive-findings.md` | Historical evidence and shipped design records. Their old baselines are intentional, not current instructions. |
| `docs/code-structure-audit.md` | Architecture record. The accepted first restructuring programme shipped; deeper proposals remain proposals until separately approved. |
| `WAYSTONE_MIGRATION_HANDOFF.md` | Detailed operational history, testing, building, and device handoff. |

## Documentation maintenance contract

Documentation is part of the implementation boundary, not optional cleanup.

1. Every material code change must update the document that owns the changed rule, system, or plan in the **same change**.
2. Every numbered release must update `README.md`, version metadata, this file, and any affected operational baseline in `WAYSTONE_MIGRATION_HANDOFF.md`.
3. When a proposal ships, changes, or is rejected, label its status explicitly. Preserve useful history, but never leave a historical proposal worded as current work.
4. Values duplicated for explanation must name their source owner. The catalogs, schemas, migrations, and current source remain authoritative over prose.
5. New documents must state their baseline, status, and relationship to existing authority. Prefer updating an owner over creating a competing source of truth.
6. Verification reports must distinguish simulation tests, renderer inspection, builds, installation, and play evidence. None substitutes for another.
7. A code task is not complete while its documentation describes the previous behaviour or priority.

## Repository boundary

The live development branch is `main`. `archive/main-pre-0.2` is historical. Do not resume work from removed checkpoint branches or an older synchronized checkout. Inspect the remote and the current version before publishing.
