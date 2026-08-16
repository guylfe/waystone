# Waystone — design foundations

**Purpose:** the enduring context for Waystone — what it is, how big it intends to be, what it borrows and refuses from other games, what has been settled, and what is still planned. This is the *why and what* document. `docs/combat-character-framework.md` specifies combat and character rules in detail; `WAYSTONE_MIGRATION_HANDOFF.md` carries operational priorities and procedure; `README.md` carries implemented-version history.

**Provenance and status:** reconstructed from the full design conversation that produced the project, cross-checked against the `0.2.10` source. Where this document and the code disagree, the code is the fact and this document is the intent — investigate the gap rather than silently picking one. Sections marked *(designed, not built)* have no implementation and have not been revisited since they were settled.

**Relationship to `docs/design-brief.md`:** that file predates this one and overlaps it. Its Promise, Achievement philosophy and Non-goals sections remain accurate. Its "One gesture, one turn" pillar describes a superseded input model — the current grammar is tap/hold/drag with committed actions, not one swipe per turn — and its "Current world-foundation slice" and "Current geometry track" sections describe a specific slice rather than enduring intent. Prefer this document where they conflict.

---

## In plain terms

Waystone is a phone-first tactical roguelike built on one idea: **time stops while you think, and runs while you act.** That single decision is what lets a game with the depth of Dark Souls work with one thumb on a touchscreen — it replaces reflexes with foresight. Almost every other rule in the project exists to protect that idea or to exploit it.

The game draws on three sources. From **Cardinal Quest 2** it takes the shape of a run: short, replayable, built from small randomised pieces, where you assemble a temporary character you become reluctant to lose. From **Dark Souls** it takes commitment and place: attacks you cannot take back, and a world that folds back on itself so that opening a shortcut feels like relief. From **Hades** it takes readable enemy attacks and the isometric presentation.

It also refuses specific things from each of them, and the refusals matter more than the borrowings — they are what stop the project drifting into a different genre one reasonable-sounding suggestion at a time.

---

## 1. What Waystone is

An Android-first, PC-compatible tactical fantasy roguelike, built in Godot, aimed at being immediately understandable and rewarding long mastery — through spatial judgment, action choice, commitment, and adaptation rather than execution speed or hidden probability.

The working definition of its combat identity, arrived at late in the design conversation after several attempts:

> A knowledge-driven action RPG in which the player can deliberate indefinitely, but every committed action has continuous physical consequences.

And the corresponding statement of what an input means:

> Every input is simple, but every action is a commitment that advances a legible world.

---

## 2. Scope

### Platform and production

Android-first, developed in tandem with Windows from early on — specifically so that later systems cannot silently assume touch-only input. The test device is a Pixel Fold, which sets the bar for orientation-agnostic layout, foldable aspect ratios and camera-cutout safe areas. Solo development with AI assistance. Publishing is a possibility, not a commitment, and no monetisation, online service or store integration work has been scoped.

### Intended size of each mode

| Mode | Target | Status |
|---|---|---|
| **Expedition** | Seven substantial regions, roughly 25–30 consequential encounters, one boss. Each region is a locale with several internal encounter spaces and side routes, not a single arena — explicitly "CQ2-scale per part." | Built, being rebuilt after the combat gate |
| **Regional Campaign** | 60–120 minutes. 2–4 Waystones, 1–2 layered regions, several bidirectional shortcuts, one major boss. A proof of concept, not a product. | Proposed, not started |
| **Short Campaign** | 3–6 hours to first completion. One interconnected procedural world per playthrough. The crucial validation step before any full campaign. | Not started |
| **Full Campaign** | Dark Souls / Hollow Knight-scale exploration: curated macro-geography with procedural local variation, NPCs, knowledge-based gates, possible multiple endings. | Long-term |
| **Endless** | Indefinite chained segments with escalating pressure and periodic secure points. | Not started |

### Content ambition

Eight initial weapon frames — Sword, Hand Axe, Zweihander, Spear, Twin Knives, Bow, Impact, Staff — with Gauntlets, Flail, Whip and Scythe deferred. Three characters exist (Warrior · Vanguard, Rogue · Acrobat, Rogue · Sharpshooter) against a much larger designed roster; see §13.

### Hard budgets

These come from measurement, not preference, and they constrain encounter design directly:

- **Enemy counts:** 5–12 visible enemies is normal, 15–25 an exceptional swarm, and roughly 30 the ceiling for simultaneously active nearby actors. Total regional population may be far larger provided most stay dormant. Measured on desktop, 30 active enemies cost ~8.5ms average frame; a 50-enemy stress case ran ~22ms average, over budget.
- **Survey sample sizes:** roughly 30 rooms before the data teaches anything, ~100 for a first encounter grammar, 130–150 for real confidence, with 10–15% deliberate near-exact repeats so encounter quality can be separated from player variance.

### Non-goals

No large inventory, crafting, hunger or durability. No final art, lore, audio, monetisation, online services or store integration in the current phase. No reuse of Cardinal Quest 2's code, art, audio, names, maps or characters — original equivalents only.

---

## 3. Lineage

The three influences are not blended. Each contributes specific things and is explicitly refused on others.

### 3.1 Cardinal Quest 2 — the run

**Taken:** run and expedition structure; decision density; class asymmetry; bounded randomness; consumables; progression cadence; achievements and unlocks; reward rhythm; the "use the whole buffalo" philosophy where classes recombine a compact shared set of verbs rather than each owning bespoke systems.

The most important borrowing is a diagnosis rather than a mechanic. CQ2 runs become compelling because **the player assembles a particular temporary character and becomes reluctant to lose it.** Everything about loot, progression pacing and permadeath serves that, and when a Waystone run feels flat the first question should be whether a build is forming at all.

**Refused:** CQ2's combat mathematics. Waystone's contact is deterministic, so hit rolls and to-hit probability have nothing to attach to. Only the run grammar transfers, not the resolution model. Also refused: the complexity level of *Pixel Dungeon* — sprawling skill trees, inventory management, hunger, durability, crafting. Simple to pick up, hard to master.

### 3.2 Dark Souls — commitment and place

**Taken:** committed actions with real recovery; spacing as the core spatial skill; weapon identity expressed through moveset rather than stat inflation; checkpoints with consequences (Waystones); dangerous outward journeys that reconnect; far-side shortcuts; a world stable enough to become a memory machine; the tension between spending resources on offense and holding them for defense.

The named target feel, from the outset: **the elevator down to Firelink** — the moment a long dangerous route is revealed to have been curling back toward safety the whole time. The design goal is to produce that repeatedly, and it is why the campaign is an interconnected graph rather than a sequence.

**Refused:** real-time reflex combat, tight parry windows, input buffering, animation-cancel technique. These solve a problem Waystone does not have — Souls needs input buffers because the player must commit under time pressure, and Waystone's freeze structure removes that pressure entirely. Also refused: continuous 3D topology. Waystone is 2D with discrete layers.

Souls' checkpoint loop is worth understanding as one system rather than a feature list: bonfire, Estus refill, leveling, enemy respawn and bloodstain recovery interlock. Adopting any one of them in isolation tends not to work.

### 3.3 Hades — legibility

**Taken:** enemy-role combinations; attack-shape readability; isometric presentation technique.

The key lesson, arrived at after asking why Hades reads so well in isometric despite the projection making exact geometry hard: it does not expose precise hitboxes. It relies on faithful animation, generous collision resolution at borderlines, strong silhouettes, and differentiated telegraphs. Hence the working principle: **the visual attack is the promise; collision should fulfil that promise.** Collision is tuned to match what looks like it hit, rather than treated as ground truth the player must decode.

**Refused:** Hades as a primary reference. Its real-time dash-cancel loop would pull Waystone toward an action game. Waystone is also harder than Hades in two respects — commitment is more punishing, with no dash-cancel escape from a misjudgment, and its geography is procedural rather than authored chambers, so clearance and occlusion rules must be stricter.

### 3.4 Considered and rejected wholesale

- **Into the Breach** — exact enemy-intent telegraphs and puzzle-perfect forecasting. Rejected explicitly: Waystone is a streamlined traditional roguelike with behavioural tendencies and statistical uncertainty, not a solvable tactics puzzle. No permanent threat overlays.
- **Sekiro** — posture-only combat where both sides accrue toward a win condition. It works because Sekiro's entire loop is a continuous attack/deflect exchange; Waystone is multi-weapon, multi-enemy and non-reflex, so it does not transfer.
- **Slay the Spire** — an early random three-choice upgrade modal was built and later removed entirely. Progression happens inside the character sheet, not in a card draft.

---

## 4. Comparative analyses

Findings from studying other games' systems directly. Kept because they are the reasoning behind several current rules, and because re-deriving them costs more than reading them.

### 4.1 Cardinal Quest 2's actual structure

Established by decompiling the APK and reading its data tables (`plot.txt`, `plotpacks.txt`, `mobpacks.txt`, `towerpacks.txt`):

- Three acts of 7, 8 and 9 floors. Each floor owns its generator, tileset, enemy pool, loot table and shop probability.
- Encounters are selected in **two weighted stages** — first an encounter archetype, then a specific formation within it. A floor is assembled from many small independently-rolled formations, not one large fixed roster.
- The enemy roster **mutates gradually in weight** across a run rather than hard-switching between tiers.
- Difficulty is a **waveform** — pressure, relief, disruption, climax — not a monotonic ramp.
- Its endless "Tower" mode is 20-floor tiers in five 4-floor blocks, each ending in a boss, with three enemy families roughly mapping to the three acts.
- 169 Steam achievements, distinguishing functional unlocks from commemorative ones.

The conclusion that matters: **CQ2's richness comes from its encounter grammar, not from map size or enemy count.** This is the model for Waystone's own encounter work, and it is why more content is not the answer to a flat run.

### 4.2 How FromSoftware games actually decompose

The most useful finding of the whole comparative pass, because it corrected a wrong assumption: FromSoft never uses stamina *instead of* recovery. It layers **five independent systems**, and conflating any two of them produces a double penalty that reads as unfair:

| System | Question it answers |
|---|---|
| **Recovery** | When may I choose again? Weapon-specific. The primary commitment system. |
| **Stamina** | How much more may I choose to do before yielding initiative? |
| **Hitstun** | What is my immediate reaction to one impact? |
| **Poise / hyperarmor** | Does my *current committed action* survive being hit? Action-specific, not a permanent trait. |
| **Posture / stance** | Has cumulative pressure earned a punish opening? |

**Recovery is the primary balancing lever; stamina is a lighter secondary burst budget.** Waystone learned this the expensive way, having first shipped a stamina model that duplicated recovery's job.

Reference values, useful for calibration rather than copying:

- Dark Souls: ~100–160 stamina, ~45/sec regeneration.
- Bloodborne: 100–160; a Saw Cleaver five-hit combo costs exactly the full bar; dodge costs 10.
- Elden Ring: 96–142 stamina, ~45/sec regen, dodge 12, heavy attacks 30–66. Enemy stance ~15–65 for ordinary enemies and 80–120 for bosses, regenerating ~13/sec after a tier-scaled delay.

### 4.3 Attack anatomy across 2D action games

Surveying Hollow Knight, Dead Cells, Hyper Light Drifter, Death's Door, Blasphemous, Salt and Sanctuary, Tunic and others produced a consistent shape:

- Player attacks decompose as **startup → brief active contact → recovery**, with an optional cancel or continuation. The active window should be *short*; a long damaging window is what makes an attack feel like a lawnmower.
- Enemy attacks need **wind-up → commitment point → fast impact → recovery**, where direction locks at the commitment point and the recovery is a real punish window.

From this came the **commitment horizon** fairness rule: an enemy that was not already visibly threatening when the player committed should not be able to begin *and* land an unavoidable attack before the player's next decision point.

### 4.4 The six costs of an action

A frame for asking why a defensive option is or is not being used. Any action can charge: **time**, **space**, **resource**, **initiative** (how soon you may reconsider), **information**, and **future options**.

Waystone's recurring failure has been ordinary movement paying almost none of them — which is exactly why Dodge went unused and why `docs/combat-loop-diagnosis.md` reads the way it does. When a tool is ignored, check which of the six its alternative is failing to charge.

### 4.5 The solvability risk

Dead Cells and its peers get replayability partly from **execution variance** — you can fail a run you understand perfectly. Frozen time removes that entirely: Waystone tests knowledge, and knowledge accumulates permanently.

So Waystone needs more **renewable strategic uncertainty** than either CQ2 or a typical action roguelike: bounded probabilistic enemy action selection, terrain variation, partial information, genuine build diversity, and difficulty that escalates by introducing new enemy *techniques and combinations* — the Boss Cells / tiered-difficulty model — rather than by inflating numbers.

This is the strongest long-term argument for the information-as-a-resource system in §13.

---

## 5. The frozen-time premise

Time is completely frozen whenever the player is ready and has not committed. On commitment, the world simulates that action's full duration — startup, active, recovery — at 120 Hz, with continuous positions, real collision shapes and swept attack geometry. Enemies and projectiles advance during that window, and the simulation can freeze mid-enemy-action or mid-flight.

This exists to make a commitment-based combat game playable with one thumb. It substitutes **prediction for reaction**: the player is tested on reading geometry and choosing, never on execution speed.

Three consequences follow, and they are constraints rather than preferences:

**Input windows must stay generous.** The game tests decisions, not narrow button timing. This is why combo continuation is a decision sampled at strike transitions rather than a frame-perfect cancel, and why parry is designed as prediction rather than reaction.

**Releasing input must always produce a safe thinking state.** *The player cannot die because they stopped touching the game.* This was locked as non-negotiable and it constrains even the endgame — see §12, where boss powers that act during stopped time are explicitly bounded so they can never land a damaging hit while the player is frozen.

Note the rule protects the *absence* of input, not its presence. Holding an input is an active, ongoing choice to advance time, and carries whatever risk that entails — which is why held movement and held Wait have no protective guardrails.

**Ordinary movement is a first-class defensive tool, not a loophole.** It is free, continuously steerable, and regenerates stamina. The design problem is never to take that away but to make its effectiveness depend on *when* it is used. See `docs/attack-capture-design.md`.

---

## 6. Determinism

If the displayed weapon crosses an enemy, it hits. Ordinary damage is fixed after explicit modifiers. There are no hit rolls, no universal miss chance, and no damage ranges added to manufacture tension. Attack rendering and collision sample the same geometry on the same timeline.

Where uncertainty is allowed to live: enemy action selection among contextually sensible options once telegraphed; detection, stealth and noise; patrol and formation variation; generation; reinforcement. Never in whether a visible hit connects.

Miss chance exists only as a deliberate, named property — Stealth, blindness, a specific evasion skill — not as background arithmetic.

A related rule on information: exact action durations, posture values and distances are never exposed in normal play. Inspection speaks qualitatively ("Speed: Slow. Reach: Long. Stability: High. Vulnerable during recovery."). This is deliberate anti-optimisation design — with exact numbers and unlimited thinking time, every encounter could be arithmetic rather than judgment.

---

## 7. Share the rules and content; specialize the journey

One simulation, one content set, three journeys. Enemies, weapons, classes, tracks, items, biomes, conditions and encounters are shared. **Only the persistence rules differ** — what survives death, rest and transition.

| | Expedition | Campaign | Endless |
|---|---|---|---|
| Topology | forward-only, branches rejoin, no return loops | interconnected graph around Waystones | chained escalating segments |
| Death | permadeath ends the run | return to last Waystone | ends the run |
| Healing | fixed starting supply, resupply must be found | full restock at each Waystone | periodic, at rising cost |
| Progression | lasts the run only | persists, anchored at Waystones | long-tail growth |

Expedition's healing model is Bloodborne-shaped and Campaign's is Dark Souls-shaped, but they are **one implementation**: "a Waystone restores your anchored pouch to capacity." Expedition simply has no Waystones. That is the pattern to reach for generally — express a mode difference as an absent feature rather than a parallel system.

A fourth mode, **Combat Survey**, is a developer instrument rather than a shipping mode: a deterministic, seeded, room-by-room laboratory with per-room ratings and telemetry export. From roughly v0.1.2 onward it has been the arbiter of combat decisions, and combat changes are expected to cite it.

---

## 8. The interconnected world

Campaign geography is **discrete stacked 2D layers** in a shared coordinate space. Collision, combat, awareness, line of sight, projectiles, hazards, navigation and discovery operate within a layer; stairs, ladders, lifts and tunnels create explicit bidirectional edges between them. There is no continuous vertical physics, and adding some would not make the game more Souls-like — it would break the simulation model.

Layer alignment is **loosely anchored**: biome-level approximate coordinates and elevation, not room-level exact anchoring. Exact alignment is reserved for local, player-observable payoffs — a bridge over a path you walked earlier, a ladder joining two floors of one building. Exact global anchoring was considered and rejected as expensive for a benefit the player cannot perceive.

**Shortcuts** are the point of the campaign, and a graph edge is not a shortcut. One qualifies only if the player had prior context for its near side, reaches the far side after real progress, it materially shortens return travel, and both endpoints are recognisable. Shortcuts open from the far side and are **permanently bidirectional** once opened — one-way returns were explicitly rejected as exchanging one inconvenience for another rather than granting freedom.

**Gates** should be soft before hard: danger-gated routes first, then knowledge and Awareness gates, then far-side shortcut gates, then a small number of major fragment gates, and very few arbitrary keys. The Lordvessel shape is the model — a single midgame unlock opening several divergent routes at once, with the player choosing order.

Campaign world geography is generated **once per campaign** and then stays stable. It is not rerolled on death; a learnable world is worth more than endless novelty.

### Death, memory and the Shadow *(designed, not built)*

Campaign memory has three tiers. **Anchored** truths — Waystones, major topology, layers, landmarks, boss outcomes, opened shortcuts — are always reliable. **Trace** memory is approximate: rough direction, vague danger. **Volatile** detail — exact patrols, minor loot, small obstacles — may change.

On death, unspent XP and not-yet-integrated skills are left behind as a **Shadow** at the death location. The Shadow holds only those; it explicitly does *not* hold map knowledge, loot, currency or shortcut knowledge. That exclusion was reasoned out rather than assumed: recovering map memory into regenerated geography is incoherent — you would "discover" rooms you never walked through. Shortcuts persist only if anchored at a Waystone before dying.

Regeneration is three independent axes — geography, encounters, loot — with named presets: **Stable** (geography frozen, most Souls-like), **Fractured** (unanchored geography rerolls), **Hybrid** (landmarks fixed, selected regions regenerate). Hybrid is the standing instinct and per-biome volatility is intended as worldbuilding rather than a global switch. This was never formally ratified.

---

## 9. Character architecture

Players and enemies are the same kind of actor, sharing attributes, action phases, posture, conditions, perception, damage events and spatial rules. Identity comes from combining and transforming shared verbs, never from bespoke minigames.

A character is **five tracks plus a sixth acquired later**: Weapon, Defense, Temperament, Main Class, Subclass, and an Adopted discipline unlocked mid-run through a diegetic teaching site. In the current source the Warrior's track order is `swordsmanship / evasion / steadfast / warrior / vanguard / adopted`.

The governing principle, arrived at after two failed attempts at uniformity, is **shared cadence, independently authored tracks.** A shared cadence grid determines *when* a track may gate; each track chooses which slots it uses, and its length and content are authored on merit. Attempts to make every track a uniform four or five nodes were tried in both directions and rejected — tracks must be free to be themselves.

One hard universal rule: **every Weapon track has exactly five ranks**, because switching weapon category grants proficiency at `highest existing − 1` and that requires consistent rank counts.

Choices are permanent for the run. Level-up offers the actual next upgrade directly — usually three options, sometimes four or five — never a track-selection meta-screen, because choosing a track before seeing its contents is not a real choice.

**Starting characters must already possess a complete play loop.** Upgrades develop it; they are never required to make a character functional.

---

## 10. Progression philosophy

Power grows mainly **within** a run. External progression unlocks possibilities — classes, options, challenges, achievements, cosmetics, world variation — rather than imposing a stat grind. A focused player should be able to max one chosen track in a successful Expedition, around character level 9–10.

Achievements are a **play-direction system**, not a trophy list: unlock a subclass by proving its fantasy, unlock a route by discovering its counterpart in another mode, unlock a challenge by beating a boss under a condition. They are organised into visible families — discovery, mastery, class craft, unusual solutions, world knowledge, challenge feats, long-tail milestones — and hidden ones should reward delightful experimentation rather than obscurity. They are also the intended unlock mechanism for the **Wanderer**, a class built from forced one-of-several draft choices across weapon, defense and discipline, whose option pool widens through achievements. That is what gives achievements mechanical teeth.

Campaign progression is finite and authored, with a level cap derived from intended purchases and reached near the end of a thorough campaign. Endless may differ — it has no authored ending, so a diminishing long-tail sink is acceptable there and nowhere else.

---

## 11. What creates difficulty

Difficulty comes from action selection, composition, terrain, partial information, resource pressure, elite properties and rule changes.

Not from inflated health, not from hidden math, not from arbitrary misses, and not from input-dexterity tests. Escalation should introduce new enemy *techniques and combinations*, not larger numbers.

The strongest empirical finding from Combat Survey to date: **an encounter becomes interesting when it forces the player to manage two competing problems at once.** Threat is not a function of enemy count. Homogeneous melee groups are weak at any size; a three-enemy mixed group beats a six-enemy uniform one.

Enemy roles in current use: frontline, flanker, ranged pressure, area denial, anchor. A cap of two simultaneous ranged-pressure enemies has held up in testing.

---

## 12. Narrative *(designed, not built; not revisited since)*

The fiction exists to make the mechanics diegetic rather than unexplained conveniences.

Someone trying to keep themselves or a loved one alive **broke the Waystone**. The original stone did not create time-freeze — it anchored time into one stable history. Breaking it scattered fragments among several people. Ordinary creatures freeze completely; the player carries a small fragment, which is why they remain conscious in stopped time and retain memory through resets.

That character is the **final boss**, and is also a vendor present throughout the game — the only NPC who subtly moves while time is stopped. Not scripted: a mechanically real tell that escalates from eyes following you, to a shifted hand, to a caught movement, to dropping the pretence entirely.

Fragment authority is tiered. Major bosses get **Counterstop**: after the player commits to an attack and it becomes readable, the bearer may freeze everyone including itself, choose a reaction, and resume alongside the committed attack. This mirrors the player's own power — gaining a decision after seeing committed information — rather than granting free movement, which was the first proposal and was judged too strong. The final bearer can briefly stop the player's body and take one bounded stolen action, but **can never land a damaging hit while the player is frozen**; control returns with unlimited thinking time before anything becomes active. By the finale the player's collected fragments contest that authority to roughly parity.

This is where §5's non-negotiable accessibility rule does its real work: even the final boss cannot punish a player for putting the phone down.

---

## 13. Content still designed but unbuilt

### Class roster

Built: **Warrior · Vanguard** (Sword, Rally, Advance), **Rogue · Acrobat** (Knife, Stealth, Vault), **Rogue · Sharpshooter** (Bow, Stealth, Take Aim).

Designed, in intended build order:

- **Rogue · Cutthroat** — extended twin-knife sequences, a Laceration-versus-Poison build fork, heavy interaction with Stealth and unaware-attack damage.
- **Warrior · Guardian** — large one-handed sword and shield, held directional Block, posture-based guard-breaking, high Resolve and hyperarmor.
- **Warrior · Berserker** — dual axes, Endure-based defense, low-health aggression incentives, and a Blood drop-healing economy scaling with proximity to death.

After a full six-build audit, a **third main class**, with Mage suggested specifically because its Grimoire ability-palette is the hardest stress test of the shared architecture. Further concepts exist at sketch level only: Artificer (Apothecary / Tinkerer), Martial Artist, Phalanx, and the Wanderer draft class.

### Enemy roles to fill

Only after survey data demonstrates the gap: a coordinator or support enemy that changes target priority, a trapper or terrain-controller, a stealth-using ambusher, a low-threat screening unit, and at least one more forest-native non-human. Deliberately *not* a generic swarm — existing groups already collapse into multi-target cleanup.

Among current enemies, the Fire Caster is the standing positive reference — distinctive pressure with readable counterplay — and the Ice Caster the standing problem, its cone able to begin and connect inside an already-committed player action.

### Friendly Forest — the reference expedition

Seven authored stages, each with its own spatial grammar and enemy introduction: Sunlit Verge (open meadow, Boars), Brookwood (brook and fords, Hounds), Old Forest Road (road spine versus overgrown detour, Bandits), Elder Grove (radial stone circle, casters), Rootbound Woods (braided root routes, Bandits with Archers), Forest Ruins (courts and cloisters, Two-Handed Knights), Heartwood Approach (ceremonial final approach, Werewolf boss with two Hounds).

Campaign reuses these same regional identities arranged in an interconnected Waystone topology rather than a linear seven.

### Systems still to build

- **Reward and discovery grammar.** Items should often be visible promises in the environment rather than incidental drops: guarded caches, teachers and skill-teaching sites, shops, secrets, rare events.
- **Pack generation** replacing independent enemy-list generation. A pack definition should carry tactical purpose, roles, aggro relationships, starting awareness, formation, terrain fit, reinforcement and retreat behaviour, reward relationship, entry directions and failure constraints.
- **Information as a resource** — a unifying system across stealth, Awareness, noise, vision, hidden passages and partial map knowledge. Flagged as the strongest candidate to become one of Waystone's defining systems, because it serves Rogue, Sharpshooter, exploration, secrets, traps and Campaign memory simultaneously, and because it is a renewable source of the uncertainty §4.5 says a deterministic game needs.
- **Exceptional consumables** beyond healing: escape and return, area denial, concealment, enemy displacement, sleep and frenzy, anti-status, terrain manipulation, and a one-use time reversal that prevents an Expedition death.
- **Campaign systems:** Waystone anchoring, death memory, shortcut validation, finite level cap, the Adopted track, secondary loadout, delayed fast travel unlocked by a fragment rather than available from the start, and a Homeward-Bone-style return consumable that sacrifices unanchored gains.
- **Endless** as its own escalation and long-tail model.

### Deferred mechanics

Parry (designed, unimplemented). Movesets for every weapon beyond Sword and Knife. Intelligence, Faith and the magic school that depends on them. The full loot and equipment system. Single-player asynchronous "echoes" — bloodstain and ghost-message analogues, possibly derived from survey death data.

---

## 14. Rejected directions

Kept because these were argued out once and should not be re-argued without new evidence.

| Rejected | Why |
|---|---|
| Pure tile/grid turn combat | Superseded by committed-action combat at high spatial and temporal resolution |
| Exact enemy-intent telegraphs, threat overlays | Turns a roguelike into a solvable tactics puzzle |
| Random three-choice upgrade modal | Progression belongs in the character sheet |
| Universal miss chance / to-hit rolls | Contradicts deterministic visible contact |
| Exposed exact timings and distances | Lets every encounter be solved arithmetically |
| One-way return shortcuts | A shortcut must grant freedom, not trade inconveniences |
| Exact global layer coordinate anchoring | Large generator cost, no perceivable player benefit |
| Committed-stride movement | Turns ordinary movement into a second dodge; the simpler pursuit model must be shown insufficient first |
| Clean-evade credit for ordinary movement | Evasion rewards belong to authored defensive techniques |
| Guardrails on held Wait or held movement | The accessibility rule protects releasing input, not holding it; assistance on one and not the other inverts the risk relationship |
| Sekiro-style posture-only combat | Depends on a continuous duel loop Waystone does not have |
| Souls-style input buffering | Solves a time-pressure problem frozen time already removes |
| Stamina as a substitute for recovery | FromSoft layers five independent systems; conflating two produces a double penalty (§4.2) |
| A separate "weapon familiarity" resource | Unneeded complexity; solved instead by gating Weapon Arts |
| An abstract mid-run relic/build-discovery layer | Loot, weapons and consumables already are the differentiation system |
| Main-hand/off-hand inventory slots | A weapon category is one complete configuration; shields are weapon metadata |
| Uniform node counts across all tracks | Tried in both directions; tracks must be authored on merit |
| Track-selection meta-screen at level-up | Choosing a track before seeing its contents is not a choice |
| Time-suspending "temporal" weapons | Muddies the consistent action-time rules everything else depends on |
| CQ2-style per-subclass starting variants | The Wanderer draft class absorbs that replay-variety role |
| Large inventory, crafting, hunger, durability | Obscures the tactical core |
| Reuse of any CQ2 code, art, audio, names or maps | Original equivalents only |

---

## 15. Standing open questions

- Campaign regeneration default — Stable, Fractured or Hybrid — never ratified.
- Campaign level cap, Adopted-track catch-up size, secondary-loadout progression.
- Why the player carries a fragment; deliberately deferred until the campaign's characters and ending exist.
- The degree of probabilistic enemy action selection that keeps a deterministic system from being solved (§4.5).
- Final stamina costs, regeneration tuning and exhaustion threshold; whether Dodge should ever cost stamina.
- Which melee roles need redesign before any new enemy is added.
- Whether the narrative layer in §12 survives contact with implementation. It has not been revisited since it was designed and nothing depends on it yet.

---

## 16. How to use this document

Read it before making a design decision, not before making a code change. If a proposal contradicts §3's refusals, §5's constraints or §6's determinism, that is a strong signal to stop — those are the load-bearing commitments, and each was reached by argument rather than assumption.

If something here is wrong or has been superseded, fix it here rather than working around it. A design document that quietly drifts out of date is what produced the need for this one.
