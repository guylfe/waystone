# Waystone — development scope

**Status:** planning reference, organized 2026-10-19 from the scope and future-content material previously held in Design Foundations. Release-specific facts below use the published `0.3.3` baseline. Relocating a proposal does not approve its implementation or assign it a release.

[Current state](current-state.md) owns the live implementation boundary and work order. [Design Foundations](design-foundations.md) describes the game. This document owns production scope, future content concepts, and unresolved development questions.

## Platform and production

Waystone is developed in Godot for Android and Windows, with both platforms considered throughout development. The Pixel Fold is the test device for orientation changes, foldable aspect ratios, and camera-cutout safe areas. Production is solo development with AI assistance.

Publishing remains a possibility. Final art, lore production, audio, monetization, online services, and store integration are outside the current production scope. Assets, names, characters, maps, and code are original; comparative research supplies design lessons.

The intended equipment and supply systems remain compact. A large inventory, crafting, hunger, and durability are outside the agreed scope.

## Mode scale and staging

| Mode or stage | Target | Status at the published baseline |
|---|---|---|
| **Expedition** | Three biomes forming one mountain ascent; six main and two optional encounters per biome; three solo bosses; single-use post-boss restoration. | Implemented `0.3.0` prototype, retained in `0.3.3`. Mechanical checks passed; human journey/balance acceptance remains open. [Contract and evidence](expedition-0.3.0-implementation.md). |
| **Regional Campaign** | 60–120 minutes, 2–4 Waystones, 1–2 layered regions, several bidirectional shortcuts, and one major boss. | Proposed proof of concept; not started. |
| **Short Campaign** | 3–6 hours to first completion, in one interconnected procedural world per playthrough. | Proposed validation stage before a full Campaign; not started. |
| **Full Campaign** | Dark Souls / Hollow Knight-scale exploration, curated macro-geography with procedural local variation, NPCs, knowledge-based gates, and possible multiple endings. | Long-term ambition. |
| **Endless** | Indefinite chained segments, escalating pressure, and periodic secure points. | Not started. |

Expedition's three-biome, three-boss rhythm and restorative transitions are part of its design. Encounter counts, roster sizes, rewards, and tuning values belong to the bounded prototype contract and remain subject to play evidence.

## Character and weapon concepts

The implemented roster and player weapon frames are listed in [Current state](current-state.md#what-exists-now). Detailed track counts, gating schedules, category-switch proficiency, and level-up rules belong to the [combat and character framework](combat-character-framework.md).

The broader weapon ambition includes Sword, Hand Axe, Zweihander, Spear, Twin Knives, Bow, Impact, and Staff. Gauntlets, Flail, Whip, and Scythe are deferred concepts.

Designed profiles with no approved build order:

- **Rogue · Cutthroat:** extended twin-knife sequences, a Laceration-versus-Poison build fork, Stealth, and unaware-attack damage.
- **Warrior · Guardian:** a large one-handed sword and shield, held directional Block, posture-based guard-breaking, high Resolve, and hyperarmor.
- **Warrior · Berserker:** dual axes, Endure-based defense, low-health aggression, and a Blood healing economy that scales with proximity to death.

Artificer (Apothecary / Tinkerer), Martial Artist, Phalanx, and Wanderer remain further concepts. Wanderer's draft construction and achievement-expanded option pool are specified in the [framework](combat-character-framework.md#119-wanderer).

**Mage · Illusionist concept — Anchor:** place a mark and later return to it instantly. The skill is in choosing a useful location before its value is known. Its naming and presentation still need to distinguish a personal movement ability from the world's Waystones. This is a reserved concept, not a scheduled addition.

## Future system work

- **Reward and discovery grammar:** guarded caches, teachers, skill-teaching sites, shops, secrets, and rare events that make rewards visible opportunities in the world.
- **Mature pack generation:** develop tactical purpose, aggro relationships, terrain fit, reinforcement and retreat behavior, reward relationships, entry directions, and journey-aware constraints beyond the current bounded generator.
- **Information as a resource:** bring stealth, Awareness, noise, vision, hidden passages, and partial map knowledge into a coherent exploration and combat system. Its uses include Rogue and Sharpshooter play, secrets, traps, and Campaign memory.
- **Exceptional consumables:** escape and return, area denial, concealment, displacement, sleep and frenzy, anti-status, terrain manipulation, and a one-use time reversal that prevents an Expedition death. These remain concepts beyond the currently implemented supply set.
- **Campaign systems:** Waystone anchoring, death memory, shortcut validation, finite progression, Campaign-specific Adopted Track and secondary-loadout rules, delayed fast travel unlocked by a fragment, and a return consumable that sacrifices unanchored gains. See [Campaign design](campaign-design.md).
- **Endless:** its own escalation, restoration economy, and long-tail growth model.

Potential enemy additions should answer a demonstrated decision gap. An information/stealth ambusher is one possible role to investigate; the remaining role space is not an approved content queue. Current rosters and the bounded Expedition roster are owned by [Current state](current-state.md) and the [Expedition implementation contract](expedition-0.3.0-implementation.md).

## Deferred mechanics

Parry is designed but unimplemented. Player movesets beyond Sword, Knife, Bow, and Staff, Faith and its dependent magic school, expanded loot/equipment beyond the bounded Expedition implementation, and asynchronous single-player echoes remain future work. Echoes could use bloodstain or ghost-message analogues, potentially derived from survey death data.

## Open questions

- Campaign regeneration policy, including Stable, Fractured, and Hybrid candidates; see the unresolved policy choices in [Campaign design](campaign-design.md#memory-and-death).
- Campaign level cap, Adopted Track catch-up, and secondary-loadout progression.
- Degree of probabilistic enemy action selection appropriate to Waystone's combat.
- Long-term Recovery-versus-Energy economy, to be compared under a matched boss-pressure setup.
- Any remaining enemy role justified by current combat and journey evidence.
- Why the player carries a fragment, and whether the proposed narrative and fragment powers work in play; see [Narrative design](narrative-design.md).

The operational work order remains in [Current state](current-state.md#current-work-order). These questions carry no implied schedule or implementation approval.
