# Waystone — Expedition encounter redesign brief

## Status and timing

This is a deferred redesign brief, not an instruction to immediately replace the current Expedition generator. Reviewed 2026-09-22 against `0.2.95`.

The first evidence gate is complete: `docs/survey-archive-findings.md` analysed 297 rooms,
G1 shipped role-aware recipes and non-melee guarantees in `0.2.35`, and `0.2.93`
added four lean exact-roster teaching encounters. These are foundations, not the final
Expedition rebuild. Boss validation and narrow journey integration now come before final
pack tables, progression weights, or content quotas.

Work that can happen before the survey is complete is limited to data capture, technical scaffolding, and documenting candidate roles. Do not prematurely lock final pack tables, progression weights, or content quotas.

## Diagnosis

The present Expedition has seven large progression areas, but each area largely uses one predetermined roster distributed across its sockets. Seeds substantially vary placement and geography, but do not yet produce enough distinct local combat premises.

Cardinal Quest 2 derives much of its run richness from nested generation. A floor contains several separately generated tactical groups, discoveries, rewards, and exploration decisions. The important target for Waystone is not CQ2's raw enemy count; Waystone combat is slower, more spatial, and more mechanically involved. The target is a comparable density of consequential and independently varied moments.

The current Expedition can therefore feel thin despite containing many enemies because:

- one broad roster is smeared across a large area instead of becoming several deliberately composed local situations;
- composition changes little between seeds;
- travel frequently exceeds the density of combat, discovery, resource, and route decisions;
- the run has limited reward, event, and build-changing content;
- difficulty rises too smoothly instead of using pressure, relief, abundance, disruption, and set-piece beats;
- seamless area boundaries do not yet provide a strong sense of completing one chapter and entering another.

## Target encounter grammar

Treat each Expedition locale as a mini-adventure, not as one encounter. A mature seven-part route should normally contain roughly 25–30 local tactical situations without blindly copying CQ2's much higher enemy count.

Generation should be nested:

1. **Route and locale role** — establish the current chapter's pacing purpose, such as opening, development, resource tension, disruption, gauntlet, relief, or boss approach.
2. **Encounter archetype** — select a tactical premise appropriate to the biome, progression position, geometry, and current run state.
3. **Composition variant** — choose a weighted group composition within that premise.
4. **Formation and placement** — place the group using spatial constraints such as clearing, crossroads, overlook, concealment, narrow pursuit route, guarded cache, or optional side path.
5. **Reward and discovery context** — decide whether the situation protects, threatens, reveals, or diverts the player toward something meaningful.

Each locale should eventually offer approximately:

- 3–5 independently rolled encounter groups;
- 1–3 meaningful discoveries or resource opportunities;
- occasional optional danger guarding a worthwhile side-route reward;
- a readable beginning and conclusion;
- a chance, where appropriate, for an elite, teacher, merchant, special event, respite, or other non-routine beat.

These are starting targets for testing, not quotas that every locale must meet. Deliberate variation is essential: a sparse and ominous locale can be as valuable as a dense gauntlet when it occurs at the right point.

## Data-driven encounter definitions

Replace exact per-part enemy lists with weighted availability and threat budgets while retaining authored guarantees for introductions, tutorials, bosses, and narrative set pieces.

An encounter archetype should be able to specify:

- eligible biome and progression ranges;
- pacing and tactical tags;
- required and optional enemy roles;
- weighted composition variants;
- minimum and maximum threat budgets;
- compatible spatial sockets and terrain conditions;
- preferred engagement distances and formation rules;
- optional reward, hazard, event, or side-route relationship;
- repetition limits, recent-history penalties, and anti-drought rules;
- entry-direction and escape-space requirements;
- exclusions for combinations that are technically legal but unpleasant in play.

The system should create coherent groups rather than independent bags of random enemies. Early enemies should remain usable as support after later enemies enter the pool, and new enemies should initially appear in controlled situations before being freely recombined.

## Playtest-driven authoring workflow

Analyze the Endless encounter reviews before finalizing Friendly Forest generation.

1. Group reviewed rooms by enemy composition, enemy roles, formation, terrain, density, approach direction, and available retreat space.
2. Identify structures that score well for fun and challenge without producing unfairness or confusion.
3. Separate composition effects from geometry effects; the same roster may be enjoyable in a clearing and miserable in a choke point.
4. Identify memorable failure modes: unavoidable overlap, crowd obstruction, excessive pursuit, ranged crossfire without cover, harmless kiting, repetitive cleanup, and encounters that become trivial after the opening exchange.
5. Convert successful patterns into candidate encounter archetypes with several variants rather than copying individual reviewed rooms verbatim.
6. Use poorly rated encounters to define exclusions and safety constraints.
7. Run the resulting grammar through the survey again and compare its distribution and ratings with the original random rooms.

The survey dataset should guide both what is generated and how often. It should not be treated as a request to average every encounter into the safest possible middle; rare spikes, relief encounters, and unusual compositions remain valuable when deliberately placed.

## Enemy-roster dependency

The current Friendly Forest roster already covers enough broad functions to prototype the grammar: animal pressure, agile pursuit, quick melee, ranged pressure, area control, projectile magic, heavy frontline resistance, and a boss encounter.

Therefore, adding many enemies is **not** a prerequisite for testing the system. Doing so first would risk creating more content for an encounter generator whose underlying selection language has not been validated.

However, the existing roster will probably not sustain the finished Forest across many expeditions. After an initial body of survey reviews, assess role gaps rather than targeting an arbitrary enemy count. Likely gaps worth testing include:

- a support or coordination role that changes how existing enemies should be prioritized;
- a trapper or terrain-manipulation role that makes space itself tactically relevant;
- an ambusher or concealment-oriented role that uses the awareness and stealth systems;
- a low-threat group or swarm role that changes target selection without becoming cleanup;
- additional forest-native identities so the early biome does not rely too heavily on progressively stronger human squads.

Add only the smallest number of enemies needed to fill demonstrated encounter-language gaps. Prefer enemies that create several new combinations with the existing roster over enemies that are merely another damage-and-health profile.

## Expedition pacing

Do not solve thinness by merely adding more biomes, doubling the route length, or matching CQ2's enemy totals. First increase the number and variety of decision-bearing situations inside the existing route.

Use a non-monotonic pacing waveform. Possible locale roles include:

- **Opening:** safely establishes the current biome's enemy and terrain language.
- **Development:** recombines understood pieces in new formations.
- **Resource tension:** offers valuable discoveries through dangerous or uncertain approaches.
- **Disruption:** introduces a new enemy, geometry rule, or unusual premise.
- **Gauntlet:** links several encounters with limited relief.
- **Relief or uncertainty:** lowers immediate density while emphasizing exploration, anticipation, or recovery.
- **Boss approach:** uses a small number of deliberate combinations to prepare for and frame the boss.

The precise sequence need not be identical in every run, but it must obey authored pacing constraints. Area transitions should communicate progression and commitment without making the main route so explicit that exploration becomes automatic.

## Campaign reuse

The encounter grammar should be shared by Expedition and Campaign, but the macro-generator and persistence rules must remain mode-specific.

Shared components can include:

- encounter archetypes and composition variants;
- threat budgets and enemy-role relationships;
- formation and terrain compatibility;
- fairness constraints and exclusions;
- biome identity and progression-sensitive availability;
- reward-guarding and side-route relationships.

Campaign applies those components differently:

- topology is interconnected, layered, and organized around Waystones and bidirectional shortcuts rather than a forward seven-part route;
- encounter purpose depends on whether a location is a first approach, return path, shortcut threshold, optional branch, traversal junction, boss approach, or route between Waystones;
- encounters must respect persistent enemy deaths, resting respawns, unlocked paths, map knowledge, timeline rules, and repeated traversal;
- a generated region should remain stable for the relevant timeline instead of visibly rerolling whenever it streams back into memory;
- return routes should not repeatedly force full-strength Expedition-style encounters unless repopulation is an intentional consequence of resting or timeline change;
- entry direction matters because Campaign spaces may be approached from several connected regions;
- encounter density must leave room for exploration, recognition, NPCs, secrets, and navigational discovery.

In short: Expedition uses the grammar to compose a paced run; Campaign uses it to populate a persistent world graph. Sharing the encounter kernel supports the “use all the buffalo” goal, but sharing the entire sequencing algorithm would damage both modes.

## Recommended implementation order

1. **Complete:** analyse the survey archive and extract initial archetypes and failure constraints.
2. **Complete foundation:** implement role-aware recipes, composition constraints, formations, and exact-roster experiments.
3. Validate the Boss Lab, Werewolf, Warden, and the lean teaching encounters in play.
4. Compare only the variants exposed by that evidence, including arrival-resource context.
5. Extend the data-driven encounter kernel where the current recipe system lacks journey needs.
6. Rebuild Friendly Forest around independently rolled local encounters, discoveries, and a non-monotonic pacing plan.
7. Re-test complete Expeditions and tune repetition limits, weights, density, and route length.
8. Reuse the validated encounter kernel in Campaign with Campaign-specific topology, persistence, and repopulation rules; build later biomes from the same grammar.

## Success criteria

The redesign succeeds when:

- two seeds produce meaningfully different tactical stories even when they use the same biome and enemy roster;
- the player can remember and describe several distinct encounters from one locale;
- exploration regularly changes resources, route knowledge, build decisions, or combat context;
- total combat remains substantial without becoming an exhausting procession;
- pressure and relief vary intentionally across the run;
- repeated Campaign traversal remains coherent and does not feel like rooms are being arbitrarily rerolled;
- new enemy types and biomes multiply the grammar's possibilities instead of merely extending a fixed sequence.
