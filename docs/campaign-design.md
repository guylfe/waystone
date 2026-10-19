# Waystone — Campaign design

**Status:** detailed design target, not an implementation claim. Organized 2026-10-19 from the Campaign material in Design Foundations. Regeneration and anchoring details below remain unresolved. [Current state](current-state.md) owns implementation and work order; [Development scope](development-scope.md#mode-scale-and-staging) owns proposed Campaign stages.

## Geography and traversal

Campaign geography uses discrete stacked 2D layers in a shared coordinate space. Collision, combat, awareness, line of sight, projectiles, hazards, navigation, and discovery operate within a layer. Stairs, ladders, lifts, and tunnels form explicit bidirectional connections between layers.

Layers use approximate biome-level coordinates and elevation. Precise alignment is useful where the player can perceive it: a bridge above an earlier path, or a ladder connecting floors of one building. This supports recognizable geography without requiring exact global alignment.

Major geography and landmarks should be stable enough to learn across a campaign. The outstanding question is how much unanchored local geography can change on death; the candidate policies are recorded below.

## Shortcuts and gates

A meaningful shortcut has:

- a near side the player already knows;
- a far side reached after substantial progress;
- a material reduction in return travel;
- recognizable endpoints;
- permanent bidirectional travel once its opening is secured under the anchoring policy.

Shortcuts open from the far side. Their reward is freedom to travel, recognition, and relief after a dangerous outward journey.

Access develops through danger, knowledge and Awareness, far-side shortcuts, and a small number of major fragment gates. A midgame milestone may open several divergent routes at once, leaving the order to the player.

## Waystones and progression

Waystones restore the shared Rejuvenation Potion pouch, heal the player, and respawn ordinary enemies. They anchor progress and provide the return point after death. Campaign leveling and major retraining take place at Waystones or appropriate safe sites.

Campaign progression is finite and authored. Its level cap should follow the intended purchases and be reached near the end of a thorough playthrough. The exact cap, Adopted Track catch-up, and secondary-loadout progression remain open.

Proposed later tools include fast travel unlocked by a fragment, a second loadout, and a return consumable that sacrifices unanchored gains. Character and proficiency rules remain owned by the [combat and character framework](combat-character-framework.md).

## Memory and death

The proposed memory system distinguishes:

| Memory | Content |
|---|---|
| **Anchored** | Reliable Waystones, major topology, layers, landmarks, boss outcomes, and secured shortcuts. |
| **Trace** | Approximate direction, danger, and path knowledge. |
| **Volatile** | Exact patrols, minor loot, and small obstacles that may change. |

On death, a proposed **Shadow** holds unspent XP and not-yet-integrated skills at the death location. Map knowledge, loot, currency, and shortcut knowledge remain outside that recovery object.

Regeneration has three independent axes: geography, encounters, and loot. The recorded candidate presets are:

- **Stable:** geography remains fixed.
- **Fractured:** unanchored geography can regenerate.
- **Hybrid:** landmarks remain fixed while selected regions can regenerate.

Hybrid was a preference under discussion, not a ratified default. Per-biome volatility is a proposed way to express the character of a place.

Two policy conflicts in the earlier material still require a decision before implementation:

1. The general fixed-geography description and the Fractured/Hybrid candidates imply different limits on changes after death. Stable major geography is the common intent; local regeneration limits remain open.
2. The shortcut description promises a lasting opened route, while the memory proposal requires visiting a Waystone to secure an opening before death. The moment when an opened shortcut becomes persistent needs an explicit rule.

These are preserved as open design choices, not resolved by reorganizing the documentation.

## Friendly Forest reference

The proposed opening region is a large, natural Friendly Forest with several Waystones and routes that reconnect. A local shortcut returns toward the second Waystone after substantial outward progress. A later ruin descends into another layer and eventually reconnects near the first Waystone.

The legacy Friendly Forest expedition provides a reference vocabulary for terrain and introductions:

| Stage | Spatial identity and introduction |
|---|---|
| Sunlit Verge | Open meadow; Boars. |
| Brookwood | Brook and fords; Hounds. |
| Old Forest Road | Road spine and overgrown detour; Bandits. |
| Elder Grove | Radial stone circle; casters. |
| Rootbound Woods | Braided root routes; Bandits with Archers. |
| Forest Ruins | Courts and cloisters; Two-Handed Knights. |
| Heartwood Approach | Ceremonial final approach; historical Werewolf encounter with two Hounds. |

This is legacy geography and possible Campaign reference material. The current Expedition is the three-biome mountain ascent described in its [implementation contract](expedition-0.3.0-implementation.md).

The earlier [vertical-slice brief](design-brief.md) retains further proposed Friendly Forest geometry. [Journey design principles](journey-design-principles.md#7-campaign-application) owns Campaign pacing, route choice, and Waystone-centered outward arcs.
