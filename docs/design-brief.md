# Waystone — vertical-slice design brief

**Status:** high-level promise and world target, reviewed 2026-09-22 against `0.2.95`.
The combat/survey slice is implemented; the Campaign and mature Expedition geometry
below remain design targets. `docs/current-state.md` owns the current work order.

## Promise

An Android-first, PC-compatible tactical fantasy roguelike that is immediately understandable, rewards mastery, and creates surprising builds from a small reusable ruleset. The initial experience is “a compact run, but more”; the longer-term campaign uses the same controls and combat inside an interconnected procedural world. Simulation and content remain shared across platforms, while touch and desktop input prompts adapt at presentation time.

## Design pillars

1. **One simple input, one legible commitment.** The current grammar is tap/hold/drag
   across movement, attacks, defense, abilities, and items. It must remain elegant enough
   for one-handed play without pretending every action is one swipe or one discrete turn.
2. **Depth through reuse.** Classes share verbs, statuses, equipment properties, enemy rules, and resources. Their identity comes from combining and transforming those pieces.
3. **Power grows mainly within a run.** External progression unlocks classes, options, challenges, cosmetics, and world possibilities—not an obligatory stat grind.
4. **The world folds back on itself.** Shortcuts create relief, recognition, and “I know where I am” moments. The campaign repeatedly reconnects dangerous outward routes to safe anchors.
5. **Readable before spectacular.** Threats, movement, targets, cooldowns, and interactables remain clear on phones, tablets, and foldables in either orientation.

## Modes

- **Expedition:** short, default-permadeath run.
- **Endless:** escalating procedural survival with score milestones.
- **Campaign:** long procedural interconnected world; checkpoint recovery by default, optional permadeath.
- **Custom:** lower-priority rule modifiers and seed controls.

## Designed world-foundation slice

- Expedition remains a forward-directed, permadeath run without Waystones or campaign return loops.
- Campaign begins in a large Friendly Forest containing several Waystones and naturally reconnecting routes.
- A local shortcut opens back toward the second Waystone after the long Elder Trail. In the Friendly Forest it is a compact path blocked by dense woods, concealed from the near side, and deliberately cleared from the far side; its blocked state must force the longer route. A third Waystone anchors the later forest before the Sunken Ruin.
- A late Sunken Ruin descends into a separate 2D underground layer, emerges near the first Waystone, and opens a second bidirectional shortcut from its far side. The sealed gate is visible from the opening side before the player can reach its far-side interaction.
- Discrete layer identity scopes combat, collision, awareness, projectiles, hazards, shadows, map discovery, and traversal; stairs and ladders explicitly connect layers without continuous vertical physics.
- The full map supports an arbitrary number of discovered layers through paged layer controls. The translucent gameplay overlay always shows the current layer and never captures layer-switching input.
- Area presentation is data-driven, beginning with light-green forest ground and a darker ruin-depths palette.
- Swipe and tap input, keyboard fallback, and responsive portrait/landscape layout remain shared by every mode.

## Designed geometry track

- Expedition is a seven-slot route recipe. Every slot carries a global difficulty position while its locale profile controls organic geography, landmarks, enemy roles, and presentation.
- A single-biome expedition uses all seven progression profiles of that biome; a mixed expedition may use different locale profiles at each slot while preserving the same global escalation.
- Each part is a substantial region with several internal encounter spaces and side routes, not one room or clearing.
- Campaign uses a separate interconnected topology with layer-scoped collision, navigation, awareness, map memory, Waystones, and far-side shortcuts.
- Both modes share one active-region lifecycle. Expedition streams the current route segment and immediate neighbors; Campaign streams the current region plus nearby or directly connected same-layer regions. Global definitions and persistent enemy records stay lightweight, while simulation, collision, navigation, rendering, and timelines consume the active subset.
- Presentation never owns game time. Committed actions advance incrementally through the authoritative fixed-step simulation, with rendering interpolating the latest states rather than replaying a precomputed future. Combat contact and timing remain 120 Hz; scalable subsystems such as ordinary enemy locomotion, strategic decision scheduling, navigation fields, and camera queries may update less often without changing attack geometry.
- Block rooms and generic bridge corridors are no longer the world representation. Broad capsules, overlapping clearings, natural boundaries, and explicit traversal anchors form the current procedural foundation.
- Friendly Forest progression profiles have distinct spatial grammars: open glades, brook crossings, old-road detours, a radial elder grove, braided root paths, forest-ruin courts, and a broad heartwood boss approach. Semantic zones drive encounter placement and expose stable sockets for later loot and events.

## Achievement philosophy

Achievements are plentiful but organized into visible families: discovery, mastery, class craft, unusual solutions, campaign world knowledge, challenge feats, and long-tail milestones. Some unlock content; most commemorate play or reveal new goals. Hidden achievements should reward delightful experimentation rather than arbitrary obscurity.

## Explicit non-goals for the first slice

- Final art, lore, monetization, online services, procedural campaign generation, and store integration.
- Reuse of Cardinal Quest 2 source code, names, characters, maps, audio, or art.
- Large inventory, crafting, hunger, durability, or other complexity that obscures the tactical core.

