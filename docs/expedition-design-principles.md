# Waystone — Expedition design principles

**Status:** enduring design target, reviewed 2026-09-22. The combat kernel, survey
instrument, initial encounter grammar, formations, and exact-roster experiments exist;
the mature seven-region Expedition described here does not. Its rebuild remains deferred
until boss and narrow journey validation. See `docs/current-state.md`.

## Purpose

This is the single reference for the principles behind an effective Waystone Expedition. It consolidates the accepted reasoning currently spread across `design-foundations.md`, `design-brief.md`, `combat-character-framework.md`, and `expedition-encounter-redesign.md`.

It describes the intended experience and the rules by which future Expedition content should be judged. It is not a fixed content table, a generator specification, or permission to implement the deferred Expedition rebuild before the combat and encounter grammar have been validated.

---

## 1. The expedition fantasy

An Expedition is a short, forward-directed, default-permadeath journey through seven substantial regions and roughly 25–30 consequential tactical situations, ending in a boss. It has branches and discoveries, but no Campaign Waystones, checkpoint loop, or campaign-style return topology.

The player should feel that they are:

- discovering a dangerous route rather than advancing through a visible list of rooms;
- assembling a particular temporary character whose loss would matter;
- deciding how much health, healing, Energy/recovery capacity, consumables, and unbanked opportunity to risk before the run ends;
- learning a changing tactical language made from enemies, terrain, formations, rewards, and incomplete information;
- passing through a journey with pressure, relief, disruption, abundance, scarcity, and climax rather than a smooth rise in numbers.

The run succeeds when the player remembers its tactical story: the guarded cache they risked, the formation that forced an unusual answer, the route they discovered, the resource decision they regretted, and the build that became uniquely theirs.

---

## 2. What transfers from other games

### Cardinal Quest 2: the run grammar

Waystone takes:

- compact, replayable expeditions assembled from many small randomised pieces;
- high decision density without high interface or inventory complexity;
- temporary-build formation and the reluctance to lose a successful character;
- bounded randomness inside authored structures;
- class asymmetry built from a compact shared vocabulary;
- limited capacity and genuine tradeoffs;
- distinct roles for XP, loot, consumables, and rewards;
- progression cadence, reward rhythm, achievements, and unlocks;
- push-your-luck attrition;
- nested encounter selection, gradual roster mutation, discovered routes, and a non-monotonic difficulty waveform.

Waystone does not take CQ2's hit rolls or combat mathematics. The run grammar transfers; the resolution model does not.

### Dark Souls: commitment and consequence

Waystone takes committed actions, spacing, distinctive movesets, resource tension, and the emotional value of a dangerous journey. For Expedition, the important transfer is consequence: a decision spends time, space, initiative, information, resources, or future options and cannot simply be taken back.

Dark Souls' interconnected checkpoint world belongs primarily to Campaign. Expedition deliberately omits Waystones and campaign return loops so that attrition and permadeath retain their point.

Waystone does not take reflex-dependent combat, tight input windows, animation-cancel technique, or continuous 3D topology.

### Hades: legibility and role combinations

Waystone takes readable attack shapes, differentiated telegraphs, strong silhouettes, faithful contact, and enemies whose roles become more interesting in combination.

It does not take Hades' dash-cancel combat loop or its sequence of disconnected authored chambers. Expedition must remain a continuous procedural journey in which approach, scouting, escalation, and the condition in which the player arrives all matter.

### Other comparative lessons

- Frozen time removes much execution variance, so the game needs renewable strategic uncertainty: bounded behavioural variation, terrain, partial information, builds, techniques, compositions, resources, and rule changes.
- Difficulty should grow through new questions and combinations, not mainly through health and damage inflation.
- An ordinary enemy should be understandable and answerable alone. Difficulty belongs primarily in the encounter, where multiple individually fair answers become expensive or incompatible.

---

## 3. The core principles

### 3.1 Form a build worth losing

An Expedition is not compelling merely because it contains combat. The player must progressively assemble a distinct temporary character.

- Starting characters already possess a complete play loop.
- Upgrades transform and develop existing verbs rather than merely adding buttons.
- A successful Expedition should normally let the player complete at least one chosen track around level 9–10.
- Equipment, weapons, consumables, teachers, and discoveries should contribute to identity rather than concentrating all differentiation in skill buttons.
- External progression primarily unlocks possibilities; it should not replace the drama of run-local growth with permanent stat accumulation.
- Achievements should direct experimentation by unlocking routes, classes, variants, and challenges through acts that teach their fantasy. They are not merely a passive trophy list.

When a run feels flat, ask first whether a meaningful build is forming.

### 3.2 Optimise for consequential decisions, not quantity

Map size, enemy count, biome count, and route length are not measures of richness. The relevant measure is the density of situations that alter tactics, resources, route knowledge, build direction, or risk.

A large area with one roster spread across it can feel thinner than a smaller area containing several distinct premises. Travel should support anticipation, scouting, discovery, and commitment; it should not routinely separate the player from the next meaningful decision.

### 3.3 Use nested, authored randomness

Generation should work in layers:

1. **Route and locale role** — determine the chapter's purpose in the run's pacing.
2. **Encounter archetype** — choose a tactical premise suited to biome, progression, geometry, and run state.
3. **Composition variant** — choose a coherent weighted group within that premise.
4. **Formation and placement** — fit it to a clearing, crossroads, overlook, concealment, pursuit route, guarded cache, side path, or other spatial context.
5. **Reward and discovery context** — decide what the situation protects, threatens, reveals, or diverts the player toward.

Randomness should vary a readable grammar, not assemble independent bags of enemies. Authored guarantees remain appropriate for introductions, tutorials, bosses, and narrative set pieces.

Weights, eligibility ranges, repetition limits, recent-history penalties, anti-drought rules, and explicit exclusions should keep that randomness bounded. The player need not predict the result, but the generator should never lose control of its possibility space.

### 3.4 Make the locale a mini-adventure

Each of the seven parts is a substantial region with its own spatial identity, not one arena and not one encounter. As a starting target, a mature locale may contain:

- 3–5 independently rolled encounter groups;
- 1–3 meaningful discoveries or resource opportunities;
- occasional optional danger guarding a worthwhile reward;
- a readable beginning and conclusion;
- an elite, teacher, merchant, event, respite, or other non-routine beat when appropriate.

These are testing ranges, not quotas. A sparse, ominous locale can be valuable when placed deliberately.

### 3.5 Compose conflicts, not piles

Enemy groups should present coherent tactical problems. Pair roles whose correct answers conflict:

- an enemy that rewards patience with one that compounds if ignored;
- an enemy that must be flanked with ranged pressure that punishes crossing open ground;
- an enemy that makes bearing important with flankers that divide attention;
- an enemy that forces movement with another that punishes careless movement.

More melee bodies are not automatically more interesting. Each added actor should change priorities, positioning, timing, or resource use rather than merely lengthening cleanup.

Geometry is part of the composition. The same group can be excellent in a clearing and miserable in a choke point. Entry direction, sightlines, cover, concealment, retreat space, hazards, and escape routes belong in the encounter definition.

A mature pack definition should also carry its tactical purpose, aggro relationships, starting awareness, reinforcement and retreat behaviour, reward relationship, allowed entry directions, and failure constraints. An encounter is partly defined by how it wakes, communicates, pursues, and disengages—not only by which actors it contains.

### 3.6 Pace with a waveform

Difficulty should not rise smoothly from weak to strong. A run needs contrast. Locale and encounter roles may include:

- **Opening:** establish the current enemy and terrain language safely.
- **Development:** recombine understood pieces in new formations.
- **Resource tension:** place something valuable behind danger or uncertainty.
- **Disruption:** introduce a new enemy, geometry rule, or unusual premise.
- **Gauntlet:** link several situations with limited relief.
- **Relief or uncertainty:** lower immediate density while increasing exploration, anticipation, or recovery.
- **Boss approach:** deliberately prepare for and frame the boss.

The exact sequence may vary by seed, but it must obey authored pacing constraints. Rare spikes, relief encounters, abundance, and unusual situations should not be averaged away merely because the middle is easier to balance.

### 3.7 Let routes be discovered

Threats must be readable; the correct route need not be. Expedition should not draw an automatic main path through each region.

- Branches may rejoin, but the overall run remains forward-directed.
- Side routes should offer meaningful risk, reward, information, or build consequences.
- Valuable discoveries should often appear as visible environmental promises: guarded caches, teachers, shops, secrets, and rare events.
- Nearby off-route pickups should read as worthwhile discoveries rather than being moved onto the mandatory path merely to guarantee supply.
- Area transitions should communicate progress and commitment without turning exploration into route-following.

### 3.8 Preserve attrition and push-your-luck tension

Expedition has no Waystones. Permadeath ends the run, progression lasts for the run, and healing begins as a fixed supply with generator-controlled resupply that must be found.

Health, healing, Energy/recovery capacity, consumables, positioning, and future opportunities should produce cumulative decisions across the route. A resource meter is not meaningful merely because it is frequently spent; it matters only if preserving, spending, or recovering it changes risk.

Attrition should create difficult choices without reducing the expedition to an inevitable downward spiral. Relief and resupply are part of the waveform, while checkpoints would erase the mode's defining tension.

### 3.9 Preserve a continuous journey

Combat Survey rooms are a coverage instrument, not a model of the finished run. Isolated arenas cannot measure:

- approach and scouting;
- accidental escalation or linked encounters;
- arriving already injured or depleted;
- the opportunity cost of detours;
- anticipation created by travel and geography;
- the way a previous decision changes the next fight.

Use the Survey to compare combat premises, compositions, geometry, and rules under controlled conditions. Then re-embed successful patterns in a large continuous Expedition slice before accepting them as expedition design. If a result works in an isolated room but fails in the route, the route has the final word.

### 3.10 Let content multiply the grammar

New enemies and biomes are valuable when they create several new relationships with existing content. They should fill demonstrated gaps in the encounter language rather than merely add another health-and-damage profile.

Early enemies should remain useful as support after later enemies enter the pool. The roster should mutate gradually in weight instead of hard-switching between tiers. New enemies should first appear in controlled situations before entering free recombination.

Do not use more content as an escape from a weak combat loop or an unvalidated generator.

### 3.11 Put uncertainty in learnable systems

Visible physical contact and ordinary damage remain deterministic. Expedition uncertainty should instead come from contextually sensible enemy choices, detection, stealth, noise, patrols, formations, reinforcement, terrain, rewards, and generation.

Information is therefore a prospective resource rather than merely presentation. Awareness, sightlines, sound, concealment, hidden passages, partial map knowledge, and last-known positions should eventually form one shared language serving combat, exploration, secrets, traps, and character identity.

The player should learn tendencies and make judgments, not solve exact arithmetic. Normal play communicates qualitative properties rather than exposing precise timings, distances, and posture values that unlimited thinking time could turn into a calculation exercise.

---

## 4. Scale and structure

The current mature target is:

- seven substantial locales;
- roughly 25–30 consequential tactical situations across the full route;
- one boss;
- several internal encounter spaces and side routes per locale;
- one distinct spatial grammar and progression role for each locale;
- bounded repetition, with enough recurrence for recognition but enough recombination for different tactical stories.

The route is a seven-slot progression recipe. Each slot has a global difficulty and pacing position, while the locale occupying it supplies geography, landmarks, enemy roles, and presentation. A single-biome Expedition can use all seven progression profiles of that biome; a mixed Expedition can combine Forest, Bridge, Town, Castle, Dungeon, and later locale sets while preserving the same global escalation. The sequence of locales can therefore tell a geographic story without hardwiring difficulty to one biome order.

The Friendly Forest is the reference structure: seven authored regional identities progressing from Sunlit Verge through Brookwood, Old Forest Road, Elder Grove, Rootbound Woods, Forest Ruins, and Heartwood Approach. Their exact content can evolve, but the principle remains that each stage has recognisable geography, encounter language, and enemy introductions rather than functioning as a cosmetic skin over the same room generator.

---

## 5. Authoring and validation rules

### Build from evidence

Before finalising encounter tables:

1. Group reviewed situations by composition, roles, formation, terrain, density, approach, and retreat space.
2. Identify patterns that are fun, tense, legible, and varied without being unfair.
3. Separate geometry effects from roster effects.
4. Record failure modes such as unavoidable overlap, obstruction, excessive pursuit, coverless crossfire, harmless kiting, repetitive cleanup, and encounters solved after the opening exchange.
5. Convert successful patterns into archetypes with several variants rather than copying individual rooms.
6. Turn poor patterns into exclusions and safety constraints.
7. Retest the resulting grammar, then test it again inside a continuous expedition.

The Survey should not optimise every encounter toward the same safe average. Its ordering, repetition, and threat curve are properties of the instrument, not evidence for the final run's pacing.

### Separate rules from current content

The encounter grammar should define roles, budgets, compatibility, formations, terrain relationships, repetition constraints, and fairness exclusions. Particular enemy lists and weights remain tunable content.

Expedition and Campaign may share this encounter kernel, but they must not share the same macro-generator. Expedition composes a paced forward run. Campaign populates a stable interconnected graph with Waystones, return paths, persistent deaths, and repeated traversal.

---

## 6. Failure modes to reject

An Expedition is going wrong when:

- one roster is smeared across an entire locale;
- seeds change placement but not the tactical story;
- travel regularly exceeds the density of decisions;
- difficulty is a smooth numerical ramp;
- encounters are random enemy bags without a premise;
- adding bodies produces longer cleanup rather than conflicting demands;
- the route is so signposted that exploration becomes automatic;
- rewards, discoveries, and build changes are too sparse for attachment to form;
- resource use is high but ordinary safety remains free;
- survey-room success is mistaken for expedition pacing success;
- more enemies, biomes, or length are added before the combat and encounter grammar work;
- Expedition quietly acquires Campaign checkpoints or return loops;
- the game relies mainly on inflated health, damage, or input dexterity for difficulty.

---

## 7. Success criteria

The expedition design is working when:

- two seeds using the same biome and roster produce meaningfully different tactical stories;
- the player can describe several distinct situations from one locale;
- a recognisable temporary build forms during the run and its possible loss matters;
- exploration changes resources, route knowledge, build decisions, or combat context;
- pressure and relief vary intentionally;
- enemies remain fair alone while combinations create difficult priorities;
- terrain and approach materially change how a composition plays;
- combat remains substantial without becoming a procession;
- early enemies continue to gain new meaning in later combinations;
- discoveries and side routes create temptation rather than chores;
- the route feels continuous even though its local situations are generated;
- the player reaches the boss with a history, not merely a larger collection of stats.

---

## 8. Current dependency

The Expedition rebuild remains downstream of the combat kernel and encounter validation. The intended order is:

1. make movement, attacks, defenses, enemy pressure, and survival satisfying in a small room;
2. use the Combat Survey to establish a reliable body of encounter evidence;
3. extract a reusable grammar and the smallest demonstrated roster additions;
4. rebuild the Friendly Forest as a continuous expedition using that grammar;
5. tune pacing, density, repetition, rewards, and route length in complete runs;
6. build later biomes from the validated system.

This dependency is part of the design principle: multiplying unproven content makes the underlying problem larger, not better.

---

## 9. Open questions

### Do enemies move before you find them?

**Unresolved, and it needs an answer before the expedition layer is built on top of the
combat loop.** Today a survey room is static: bodies are placed when the room is
generated and stand there until the player crosses a sightline or makes a noise. That is
defensible for a combat instrument, where the arrangement *is* the experiment and drift
would make formations unmeasurable. It is not obviously right for an expedition, where a
place the player has not reached yet is supposed to feel inhabited rather than staged.

The question is really three:

1. **Do they move at all before discovery** — patrol routes, idle drift, or nothing?
2. **If they move, does the authored arrangement survive it?** `0.2.41` made placement an
   authored thing precisely so that composition could be attributed to a formation. A
   patrol that has wandered by the time the player arrives destroys that attribution, so
   an expedition that moves its enemies needs a different evaluation instrument than the
   Combat Survey.
3. **Does the player's approach change what they find** — does arriving late, loudly, or
   from another direction meet a different arrangement?

Raised while fixing stealth in `0.2.44`, where the answer decides whether "the enemy goes
to your last known position" is a full behaviour or only the visible half of one.

## Source documents

This consolidation is derived from the existing accepted project record:

- `docs/design-foundations.md` §§1–4, 6–7, 9–10, and 13;
- `docs/expedition-encounter-redesign.md`;
- `docs/design-brief.md` §§1–3;
- `docs/combat-character-framework.md` §§6, 10, and 13;
- `WAYSTONE_MIGRATION_HANDOFF.md` §§1–3, 8–10, and 13.

Where this document conflicts with a later explicit design decision, the later decision wins and this consolidation should be updated.
