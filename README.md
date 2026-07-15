# Waystone Prototype

Current prototype version: `0.0.10`. Android version codes increase independently so newer APKs can always upgrade older installations.

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

Seven seeded rooms grow progressively harder through terrain, encounter budgets, and enemy-role combinations. Rooms now occupy a larger continuous space under a close player-following camera, so only part of the battlefield is visible at once. Blade, Knife, Archer, Polearm, Hound, Brute, Hexer, Captain, and Warden enemies each apply different spatial pressure; Shieldbearers are temporarily removed from encounter generation. Room rewards offer one of three lightweight run upgrades, and the current expedition is saved locally when the app closes.

The prototype Duelist combines Dodge with a diagonal cut and directional Sweeping Cut; Guardian uses a compact heavy chop, while Reaver uses a broad sweep. Enemy weapons now have distinct reusable techniques: quick cuts, thrusts, bites, forward smashes, and heavy cleaves. The same world-space pose drives collision and both visual projections. Fast enemies have deliberately low posture and can be interrupted, while grounded Brute and Warden attacks resist interruption after becoming active. Physical contact is deterministic, action information is qualitative, and cooldowns use visual progress rather than decimal timing.

Obstacle-aware route planning guides continuous enemy movement around generated room geometry. The same close camera follows the player in top-down and experimental isometric projections, including inverse-projected taps, swipes, attacks, hazards, and directional skills. Impacts use foreground bursts, floating damage, and player damage framing, while a persistent health bar remains at the top of the playfield. Guardian retains directional Block, while Reaver retains Endure. A small Reset control remains available during actions and after death.

## Run locally

Run `run-prototype.ps1`, or open `project.godot` with Godot 4.x and run the project. A portable Godot 4.7 editor is stored under the ignored `tools/` directory. Android export tooling is not yet configured on this machine.

Run `build-android.ps1` to produce `builds/android/waystone-debug.apk`. The configured project-local toolchain targets arm64 Android devices, including the 2023 Pixel Fold.
