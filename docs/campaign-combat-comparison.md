# Regional Campaign combat comparison

The 0.3.12 comparison uses Waystone 0.3.11 as its baseline. Its runtime lives in
[CampaignState](../scripts/campaign/campaign_state.gd). The
[player reference](campaign-player-reference.md) and
[enemy reference](campaign-enemy-reference.md) give the source rows, conversions
and estimates. [Regional Campaign](campaign-regions.md) owns geography and
progression.

## Runtime

Slow and Fast replace neutral walking, light strikes, Combo, and standard dodge
in regional Campaign. The Warrior uses a greatsword, both Rogues use daggers,
and the Mage uses a straight sword for these attacks. Each class keeps its
attributes, advancement, Weapon Arts, and other abilities. Waystone damage,
posture, and Energy costs remain in effect. An exhausted player uses the shared
desperate dodge.

A press of Attack commits the opening strike and its complete recovery. Combo
pays for the whole phrase up front and follows each weapon's sourced continuation
interval until the last strike finishes its recovery. Each strike gets its own
contact window and set of targets already hit. An enemy interrupt can end the
phrase during a commitment.

The simulation advances at 120 ticks per world second. The existing board plays
those seconds at 1.25×. Reference action clocks account for that playback and
the actor's neutral tempo. Frost, exhaustion, and terrain still apply through
shared rules. As in Default, deliberation advances neither actor's clock.

Forward travel follows the original measured or estimated landmarks at contact,
continuation, and free movement. The simulation interpolates between those
landmarks and checks terrain, walls, and bodies. The weapon reach starts at
the actor's current origin. Rendering and collision use the same active window
and per-strike pose. Roll movement is likewise capped at the specified distance
on clear ground, and its invulnerability ends on the first vulnerable tick.

## Encounters and persistence

The Ridge Stairs retain the Polearm at (2650, 540) in all three styles. Windbreak
retains the same two seats and terrain. Default pairs a Shield and a Knife.
Slow pairs a Shield and a Blade. Fast pairs a Blade and a Knife. Fast Knives use
the existing flank approach, while the Slow profile closes directly. Shields
continue guarding allies.

Selected infantry open with their profile's timed attack. A follow-up tests
range and line of sight once at the sourced link, then uses the authored
probability and begins a fresh wind-up. The shared simulation handles collision,
interruption, defense and damage. The shared Campaign seed, regional layout,
guardians and gates apply to all styles.

The Campaign save records the active style with the seed and actor phases.
Version 1 saves that lack the style open as Default. Slow and Fast use a
version 2 regional payload. Unknown styles use the protected-save path.

## Evidence

Redirect `APPDATA` and `LOCALAPPDATA` to disposable folders under
`.runtime/campaign-verification/` and run Godot 4.7 from the project directory.

```text
godot --headless --path . --fixed-fps 120 --script tests/campaign_combat_comparison_test.gd -- input
```

The `input` argument includes normal Campaign scene tests for held and repeated
presses through keyboard, mouse, touch, and controller events.

The simulation probe exercises all four loadouts in each comparison style,
including strikes landing through shared geometry, complete combo commitments,
movement and roll distances, and the frozen clock. It also walks into the
authored Ridge Stairs encounter in all three styles, tests Fast Blade's in-range
follow-up and a retreat that breaks it, and checks legacy save loading and
stable encounter seats. Renderer and physical controller tests require a
separate pass. Guy's playtest determines acceptance.


## Same-encounter comparison

A scripted Warrior in each style entered the same Ridge Stairs encounter on seed 131137, moved toward the resident Polearm, then chose a response at the first frozen melee telegraph. Values below cover the chosen action until the player could decide again. Elapsed time excludes deliberation. These results were reproduced using the exported Windows game data.

| Style | Attack commitment | Combo commitment | Combo damage dealt / received | Retreat roll commitment |
| --- | ---: | ---: | ---: | ---: |
| Default Waystone | 0.79 s | 1.98 s | 40 / 0 | 0.45 s |
| Slow | 1.43 s | 2.37 s | 20 / 0 | 1.10 s |
| Fast | 1.40 s | 5.00 s | 40 / 12 | 0.73 s |

One Attack dealt 10 damage with no damage received during the commitment in all three runs. At this opening, Default rewarded a full chain, Slow exchanged two committed hits before the next decision, and Fast punished the longer chain even though its greatsword reached contact earlier. All three retreat rolls avoided damage during the roll. A single sideways step ended with the opponent still in its melee action. These are reproducible outcomes from one opponent, approach and seed, rather than a win-rate or human-play estimate.
