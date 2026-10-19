# Waystone — design foundations

Waystone is an Android-first, PC-compatible tactical fantasy roguelike. **Time stops while you think, and runs while you act.** Simple inputs give the player control over consequential actions in a continuous physical world. Mastery grows through spatial judgment, knowledge, commitment, and adaptation.

This document describes the game's identity and intended experience. [Current state](current-state.md) describes what is implemented; the documents at the end specify individual systems and development plans.

## The player experience

The player explores a dangerous world, learns its creatures, and develops a character whose particular strengths shape the journey. Each encounter asks them to read the situation, choose an action, and live through its consequences. Success makes both the character and the player's understanding more valuable.

Waystone is immediately understandable and rewards long mastery. Its controls support comfortable one-handed touch play and adapt to desktop input. Threats, targets, movement, resources, and interactables remain clear across phone, foldable, and desktop layouts.

## Inspirations

### Cardinal Quest 2 — runs and character growth

Cardinal Quest 2 inspires compact, replayable adventures assembled from small authored pieces, bounded randomness, distinctive classes, consumables, progression, and rewards. A run becomes compelling as the player assembles a particular temporary character and becomes reluctant to lose it.

Its economy of actions and limited carrying capacity give individual choices weight. Classes gain depth by recombining a compact vocabulary of abilities and effects. Achievements and discoveries open further ways to play.

### Dark Souls — commitment and place

Dark Souls inspires consequential actions, recovery, spacing, and weapons distinguished by their movesets. Offense, defense, and repositioning compete for time, initiative, and resources.

It also inspires Campaign's interconnected world: dangerous outward journeys, consequential checkpoints, and shortcuts discovered from the far side. The emotional reference is the elevator down to Firelink — recognizing that a long journey has brought you back to familiar safety, with a new understanding of the world.

### Hades — readability and Expedition rhythm

Hades inspires clear attack shapes, differentiated telegraphs, strong silhouettes, isometric presentation, and enemy roles that become interesting in combination. Animation and collision together communicate what an attack does.

Hades also inspires Expedition's structure: **three biomes, three bosses, and a resource refresh between biomes**. Each biome develops its own encounter language, builds toward its boss, and resolves into a restorative pause before the next stage of the ascent.

## Time and commitment

Whenever the player is ready to choose, the world is frozen. They can inspect the situation and deliberate for as long as they need. Committing to an action advances the whole world through that action's startup, active phase, and recovery. Enemies, projectiles, and hazards continue moving during this interval.

Actions have continuous spatial consequences. Position, facing, reach, attack arcs, and the moment of commitment all matter. The player predicts how the scene will change while the chosen action unfolds.

Input windows are generous. A continued input deliberately advances time; releasing input lets the current commitment finish and returns the player to a safe thinking state when ready. Ordinary movement is a chain of short committed steps, with each next step taking the player's chosen direction.

## Physical combat and information

Visible weapon contact determines hits, and ordinary damage follows fixed values and explicit modifiers. Attack animation and collision describe the same action. The visual attack is the player's reliable guide to its reach, shape, and effect.

Players read attacks through preparation, commitment, impact, and recovery. Enemy preparation gives them information with which to choose; recovery creates an opportunity to act. An unavoidable threat during a player's commitment must have been readable when that commitment began.

Inspection describes useful qualities such as speed, reach, stability, and vulnerability during recovery. The player combines that information with spatial judgment. Enemy behavior, awareness, noise, patrols, terrain, and procedural variation create changing situations in which to apply what they have learned.

## Characters and progression

Players and enemies share the same foundations: attributes, action phases, posture, conditions, perception, damage, and spatial rules. A character's identity comes from the way its weapons, defenses, temperament, class, and abilities combine and transform these systems.

Each starting character already has a complete play style. Upgrades deepen that identity and introduce meaningful ways to specialize. The player sees concrete upgrades and their consequences before committing to choices that last for the run. Equipment and limited consumable capacity add further tradeoffs.

Most power develops within a run. Lasting progression opens classes, options, challenges, cosmetics, and world possibilities. Achievements give the player new directions to explore: demonstrate a class's strengths, discover a connection, try an unusual solution, or meet a demanding condition. Their families make these possibilities legible, and hidden achievements reward experimentation.

## Encounters and difficulty

An encounter becomes interesting when it presents competing demands. A shield encourages the player to go around; an archer makes exposed ground dangerous. An enemy that rewards patience can combine with another whose influence grows over time. The player must find a response that accounts for the whole situation.

Ordinary enemies have understandable behaviors and workable individual answers. Compositions, terrain, entry direction, partial information, and arrival resources change the cost of those answers. Difficulty develops through new techniques, combinations, elite properties, and changes to the rules of a situation.

## Journey and modes

A journey alternates pressure, relief, discovery, preparation, disruption, and climax. Quiet exploration and recovery give the player time to recognize their progress and anticipate what comes next. Optional routes and rewards let them choose how much additional risk to take.

The modes share combat, characters, enemies, equipment, conditions, and world content. Each gives those systems a distinct structure and rules for persistence.

| Mode | Journey | Progress and restoration |
|---|---|---|
| **Expedition** | A forward journey through three biomes, each culminating in a boss. Exploration and branching routes unfold within each biome. | A temporary build, finite supplies, and permadeath. Single-use post-boss restoration refreshes resources; leaving a biome commits the player to the next stage. |
| **Campaign** | An interconnected world organized around Waystones, exploration, and return journeys. | Persistent character growth and Waystone anchoring. Rest restores supplies and ordinary enemies; death returns the player to a Waystone. |
| **Endless** | Chained segments with escalating pressure. | Run-long growth and periodic restoration at increasing opportunity cost, continuing until death. |

## Campaign and a sense of place

Campaign geography consists of connected 2D layers. Stairs, ladders, lifts, and tunnels link places the player can learn and recognize. Stable major geography, landmarks, and Waystones support an accumulating mental map.

A meaningful shortcut connects familiar places after real progress and materially improves travel. The player opens it from the far side and gains a lasting route in both directions. Recognition, relief, and increased freedom are part of its reward.

Danger, knowledge, discovery, and major milestones give routes their accessibility. Exploration gradually reveals how places relate, and the player chooses how to approach the opportunities they uncover.

## Detailed documentation

| Subject | Document |
|---|---|
| Implementation, verification status, and next work | [Current state](current-state.md) |
| Production scope, future content, and open questions | [Development scope](development-scope.md) |
| Combat, character tracks, and progression rules | [Combat and character framework](combat-character-framework.md) |
| Enemy, encounter, and boss design | [Battle design bible](battle-design-bible.md) |
| Expedition structure and content principles | [Expedition design principles](expedition-design-principles.md) |
| Pacing across a complete journey | [Journey design principles](journey-design-principles.md) |
| Campaign topology, persistence, and progression | [Campaign design](campaign-design.md) |
| Fiction, characters, and fragment powers | [Narrative design](narrative-design.md) |
| Comparative research and historical combat evidence | [Design research](design-research.md) |
| Survey procedure, performance budgets, and validation | [Development handoff](../WAYSTONE_MIGRATION_HANDOFF.md#9-how-combat-survey-reports-work) |
