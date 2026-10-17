# Waystone current state

**Reviewed:** 2026-10-18 (illustrated PC controller interface)
**Release baseline:** `0.3.2` (`versionCode 302`, save schema `38`, Combat Survey generator `3`, expedition generator `1`, presentation `19`, Combat Survey format `36`). Human play acceptance remains open; see the controller ledger for verification.
**Authority:** current source and tests define implemented behaviour; this file is the concise operational map. `README.md` remains the release history and the other design documents retain rationale, evidence, rejected alternatives, and future targets.

## What exists now

- Four playable profiles: **Warrior · Vanguard**, **Rogue · Acrobat**, **Rogue · Sharpshooter**, and **Mage · Elementalist**.
- Four working weapon frames in player use: Sword, Knife, Bow, and Staff.
- Native Xbox-style PC controls provide direct movement/aim/actions, ability and utility selection, focused menu navigation and disconnect/focus safeguards. Connecting a controller displays colored button images and contextual action descriptions immediately; Menu includes an illustrated controller guide. Combat balance and save/generation identities are unchanged. See [controller controls](controller-controls.md) for bindings and verification limits.
- The shared combat kernel includes committed actions, attack capture, Energy and Recovery rule profiles, exhaustion, Dodge, posture, Resolve-derived action poise, conditions, projectile elevation and misdirection, barriers, deterministic save/snapshot support, and survey attribution.
- Fire, Ice, Earth, and Air casters and all eight elemental abilities are implemented. The Elementalist can inherit one spell from each element; Intelligence reduces spell cost through the implemented soft-cap curve without increasing spell damage.
- The Warrior/Vanguard redesign is live: sustained Rally, Battle Flow, Advance, Resolve-derived action poise, Power Through, and Unbreakable. Battle Flow is sequence-based and currently decays after 15 seconds.
- The Combat Survey layer has role-aware recipes, deliberate formations, guaranteed non-melee pressure in ordinary mixed generation, exact-roster experiments, and `Encounter` and `Attrition` profiles. Its generator remains separate from the three-biome Expedition generator.
- Ordinary walking is a chain of short committed steps: a hold repeats them and steering affects the next step. It remains a free tactical defense, but is not steerable within a step. The Ice Caster's old cone complaint predates Frost Lance and Cold Front and is not a standing verdict on current Ice.
- Boss Lab is implemented as a repeatable, isolated evaluation mode. The Werewolf solo redesign is live with Hunting Leap, Double Rake, and Bounding Rake; its pack form remains disabled for comparison. Warden remains provisional. Both legacy bosses are excluded from the new expedition.
- The implemented expedition is a continuous mountain ascent through Briarwild Foothills, the above-ground Cinderworks and Stormglass Summit, with irreversible biome departures, three new solo bosses, one-use restoration, finite healing/economy, equipment and the midpoint adopted-track Exchange. See the implementation ledger for verification limits.
- The 0.3.0 expedition verification covered 100 seeds / 300 maps, legal full-run victories for all four characters and both disciplines. Its APK passed Fold portrait input, frozen time and cold save/resume checks. The 0.3.1 regression suite has 27 passing files plus the documented pre-existing Bandit failure; controller render checks and XInput hardware detection pass. See the controller ledger for build/install status. Physical-controller play feel, Fold inner-display play and sustained combat performance remain unverified.

## Current work order

The approved expedition includes only the necessary actual-commitment timing,
imposed-reaction clock ownership and defensive-response measurement repairs.
Other foundation-audit proposals, including Strength, broader condition rules and
Recovery Rally, remain proposals rather than implied authorization for a rewrite.

The October 17 approval supersedes the Warden-first content gate for this experiment:

1. Play the [0.3.0 expedition prototype](expedition-0.3.0-implementation.md) and collect human journey/boss feedback. Automated feasibility does not establish fun, fairness or readable teaching.
2. Check the Fold's inner display and sustained combat performance; report these separately from the already-passed portrait/suspension smoke tests.
3. Propose narrow tuning or repairs from that evidence before expanding the content programme. Roster counts, rewards and boss statistics remain test values.
4. Revisit Warden, the Werewolf pack comparison, Campaign integration and Recovery versus Energy only as subsequent agreed work; none was implemented by adding the new expedition bosses.

## Document authority and status

| Document | Use now |
|---|---|
| `docs/current-state.md` | Current implementation boundary and next work. Update with every material change. |
| `docs/design-foundations.md` | Enduring design intent, constraints, refusals, and long-term scope. |
| `docs/battle-design-bible.md` | Credence-rated enemy, encounter, and boss principles. |
| `docs/combat-character-framework.md` | Shared actor, combat, character, and progression design. Implemented facts must still be checked against source. |
| `docs/controller-controls.md` | Implemented native PC bindings, input-safety contracts and verification ledger. |
| `docs/elemental-casters.md`, `docs/warrior-vanguard-redesign.md` | Implemented programme records plus retained design history. |
| `docs/enemy-encounter-boss-revised-design.md` | Earlier six-update plan: Updates 1–4 shipped; Updates 5–6 deferred by the approved new expedition. |
| `docs/expedition-0.3.0-implementation.md` | Approved three-biome contract, ownership, implementation and verification ledger. |
| `docs/expedition-design-principles.md`, `docs/journey-design-principles.md`, `docs/expedition-encounter-redesign.md` | Enduring pacing principles and historical design rationale; obsolete seven-region/no-Waystone counts are not current requirements. |
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
