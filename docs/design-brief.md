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

## Vertical slice

- One original pathfinder class.
- Four shared verbs: move/melee, aimed shot, evasive step, placed snare.
- Three enemy roles: pursuer, cautious ranged threat, area-denial guardian.
- One compact two-chamber ruin with a long route, lever, locked shortcut, and restorative waystone.
- One build choice that modifies an existing verb instead of adding another button.
- Swipe and tap input, keyboard fallback, responsive portrait/landscape layout.
- Code-drawn clean-modern placeholder presentation with chunky silhouettes and limited color language.

## Achievement philosophy

Achievements are plentiful but organized into visible families: discovery, mastery, class craft, unusual solutions, campaign world knowledge, challenge feats, and long-tail milestones. Some unlock content; most commemorate play or reveal new goals. Hidden achievements should reward delightful experimentation rather than arbitrary obscurity.

## Explicit non-goals for the first slice

- Final art, lore, monetization, online services, procedural campaign generation, and store integration.
- Reuse of Cardinal Quest 2 source code, names, characters, maps, audio, or art.
- Large inventory, crafting, hunger, durability, or other complexity that obscures the tactical core.

