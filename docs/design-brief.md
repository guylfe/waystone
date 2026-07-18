# Waystone — vertical-slice design brief

## Promise

An Android-first tactical fantasy roguelike that is immediately understandable, rewards mastery, and creates surprising builds from a small reusable ruleset. The initial experience is “a compact run, but more”; the longer-term campaign uses the same controls and combat inside an interconnected procedural world.

## Design pillars

1. **One gesture, one turn.** Swipes move or attack; taps select adjacent actions and abilities. The default interaction remains elegant enough for one-handed play.
2. **Depth through reuse.** Classes share verbs, statuses, equipment properties, enemy rules, and resources. Their identity comes from combining and transforming those pieces.
3. **Power grows mainly within a run.** External progression unlocks classes, options, challenges, cosmetics, and world possibilities—not an obligatory stat grind.
4. **The world folds back on itself.** Shortcuts create relief, recognition, and “I know where I am” moments. The campaign repeatedly reconnects dangerous outward routes to safe anchors.
5. **Readable before spectacular.** Threats, movement, targets, cooldowns, and interactables remain clear on phones, tablets, and foldables in either orientation.

## Modes

- **Expedition:** short, default-permadeath run.
- **Endless:** escalating procedural survival with score milestones.
- **Campaign:** long procedural interconnected world; checkpoint recovery by default, optional permadeath.
- **Custom:** lower-priority rule modifiers and seed controls.

## Current world-foundation slice

- Expedition remains a forward-directed, permadeath run without Waystones or campaign return loops.
- Campaign begins in a large Friendly Forest containing several Waystones and naturally reconnecting routes.
- A local shortcut opens back toward the second Waystone after further progress.
- A late Sunken Ruin descends into a separate 2D underground layer, emerges near the first Waystone, and opens a second bidirectional shortcut from its far side.
- Discrete layer identity scopes combat, collision, awareness, projectiles, hazards, shadows, map discovery, and traversal; stairs and ladders explicitly connect layers without continuous vertical physics.
- Area presentation is data-driven, beginning with light-green forest ground and a darker ruin-depths palette.
- Swipe and tap input, keyboard fallback, and responsive portrait/landscape layout remain shared by every mode.

## Immediate geometry track

- `0.0.18`: replace rectangular room boundaries with a continuous-region representation and one semi-curated Friendly Forest using irregular clearings, broad trails, natural boundaries, and landmark-shaped junctions.
- `0.0.19`: make that representation generative through curated spatial grammars and topology templates, while preserving generous mandatory passages, Waystone relationships, and shortcut guarantees.
- Block rooms and straight bridge-like corridors are scaffolding for topology tests, not the intended campaign geography or a content-production format.

## Achievement philosophy

Achievements are plentiful but organized into visible families: discovery, mastery, class craft, unusual solutions, campaign world knowledge, challenge feats, and long-tail milestones. Some unlock content; most commemorate play or reveal new goals. Hidden achievements should reward delightful experimentation rather than arbitrary obscurity.

## Explicit non-goals for the first slice

- Final art, lore, monetization, online services, procedural campaign generation, and store integration.
- Reuse of Cardinal Quest 2 source code, names, characters, maps, audio, or art.
- Large inventory, crafting, hunger, durability, or other complexity that obscures the tactical core.

