# Waystone Prototype

Current prototype version: `0.0.17`. Android version codes increase independently so newer APKs can always upgrade older installations.

An original Android-first committed-action roguelike prototype inspired by the low-friction, high-mastery design philosophy of classic mobile roguelikes.

## Current controls

- Tap or quick-swipe: take a short, roughly 0.1-second movement pulse.
- Swipe and hold: continue moving in that direction; release to freeze time.
- Tap an enemy (or swipe onto it): commit to the equipped weapon's attack technique.
- Tap an empty reachable position: move precisely toward it.
- Choose Duelist, Guardian, or Reaver from the loadout tabs; changing identity restarts the expedition.
- Tap the context-sensitive Defense button: Dodge and Block then take a direction, while Endure activates immediately.
- As the prototype Duelist, tap Sweep and choose a direction to commit to a wide posture-breaking cut.
- Hold an enemy while time is frozen for qualitative action, speed, reach, stability, and role information.
- Tap ISO or TOP while time is frozen to switch presentation without changing simulation state.
- Tap Potion to heal, Wait to surrender 0.5 seconds, or Reset to restart.
- Tap after death or press `R`: restart the expedition.

The first expedition uses continuous positions, world-space weapon hitboxes, physical projectiles, persistent hazards, and a 120 Hz fixed-step simulation. Time is frozen whenever the player is ready. Locomotion is granular and interruptible, while strikes and skills commit through startup, active, and recovery phases.

The seeded expedition is now a forward-directed floor: a seven-area main path plus an optional high-risk branch, with no Waystone or return shortcut. Campaign Lab uses the same rooms and encounters but adds a halfway shortcut that opens back to its starting Waystone only from the far side. Fog of war remembers explored terrain, while enemy sight, sound, suspicion, and alert states determine when combat begins. The Map button switches between full-screen and translucent discovered-area views.

The active world seed is shown on the map and can be copied, while the pre-run screen accepts an optional seed for repeatable expeditions. Required passages use deliberately wide doors and corridors, and room dressing preserves a generous direct route between every connected entrance. The translucent map is non-modal: movement, combat, and HUD controls remain usable behind it, with only its Close button capturing input.

The prototype now runs under two explicit rule sets and traversal graphs. Expedition preserves its permadeath, forward-directed floor and exit-earned upgrades. Campaign Lab begins its own larger Friendly Forest region with three Waystones, broad light-green clearings, two independently remembered bidirectional shortcuts, and an underground ruin layer reached through explicit stairs and a return ladder. Combat remains 2D: actors, projectiles, hazards, shadows, and interactions carry a discrete layer identity, while traversal links move between otherwise separate 2D spaces.

The Campaign route first reaches the Moss Waystone, then eventually opens a local root-gate return to it. Near the region's end, the Sunken Ruin descends into buried halls and emerges into a forgotten grove beside the Dawn Waystone, where a second shortcut can be opened from its far side. The map automatically frames the current layer and labels it independently; area and layer palettes are data-driven so later biomes can advertise their identity through ground color.

Shortcut activation now sits directly against the accessible face of each locked gate and has a visible gold interaction marker; the closed gate cannot be unlocked through its wrong side. Normal play renders only camera-adjacent terrain, walls, actors, hazards, landmarks, and effects, while the map retains full discovered-area presentation. Action playback uses lightweight snapshots that omit the growing discovered-world and static-layout payload. The player uses a cyan silhouette with a dark separation halo, white keyline, and facing point so every biome palette preserves contrast.

Campaign Lab now makes provisional life explicit: integrated and at-risk XP occupy separate portions of the XP bar, the Shadow is marked and gently guides nearby recovery, and death accounts for retained XP, recoverable XP, forgotten map memory, and unanchored shortcuts. The Waystone activates only when deliberately tapped in range; that single action restores resources, revives enemies, and integrates XP, map memory, and shortcuts before optionally offering Learn or Continue.

Enemies award XP. Expedition offers a three-choice upgrade after leaving a cleared area with enough XP. Campaign Lab leaves only experience earned since the last Waystone activation at a recoverable Shadow; dying again replaces the old Shadow. Integrated XP can be saved safely and spent on upgrades during a later Waystone activation.

The prototype Duelist combines Dodge with a diagonal cut and directional Sweeping Cut; Guardian uses a compact heavy chop, while Reaver uses a broad sweep. Enemy weapons now have distinct reusable techniques: quick cuts, thrusts, bites, forward smashes, and heavy cleaves. The same world-space pose drives collision and both visual projections. Fast enemies have deliberately low posture and can be interrupted, while grounded Brute and Warden attacks resist interruption after becoming active. Physical contact is deterministic, action information is qualitative, and cooldowns use visual progress rather than decimal timing.

Obstacle-aware route planning guides continuous enemy movement around generated room geometry. The same close camera follows the player in top-down and experimental isometric projections, including inverse-projected taps, swipes, attacks, hazards, and directional skills. Impacts use foreground bursts, floating damage, and player damage framing, while a persistent health bar remains at the top of the playfield. Guardian retains directional Block, while Reaver retains Endure. A small Reset control remains available during actions and after death.

## Run locally

Run `run-prototype.ps1`, or open `project.godot` with Godot 4.x and run the project. A portable Godot 4.7 editor is stored under the ignored `tools/` directory. Android export tooling is not yet configured on this machine.

Run `build-android.ps1` to produce `builds/android/waystone-debug.apk`. The configured project-local toolchain targets arm64 Android devices, including the 2023 Pixel Fold.
