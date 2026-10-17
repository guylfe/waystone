# Revised three-biome expedition — implementation ledger

Status: 0.3.0 implemented and mechanically verified; both builds complete and final
Android package installed. Human play acceptance remains open. Initial tuning is not
validated balance doctrine.

The user's October 17, 2026 approval supersedes the older Warden-first/content-expansion
gate for this prototype. Existing combat identities, frozen-time decisions and the
shared combat kernel remain authoritative. Existing uncommitted foundation audits
are preserved, not silently folded into this release.

## Release contract

- One mountain ascent: Briarwild Foothills → above-ground Cinderworks → Stormglass Summit.
- Standalone, continuously explored maps; six main and two optional encounters each,
  a quiet landmark, preparation area and new solo boss. No ordinary room locks.
- Departure is explicit and irreversible. Each boss unlocks a single-use healing
  Waystone; the third also unlocks a distinct victory exit. No checkpoints or respawns.
- Eight authored ordinary kinds per biome, five core plus two rotating kinds per seed;
  all seven placed. Six new ordinary kinds and three new solo bosses. Legacy bosses
  remain in their existing modes.
- Original five-charge, 25-health pouch. Finite 15-health Trail Rations, stack two,
  utility slot, no Waystone refill. No Salve, Field Medic or merchant pouch refills.
- Existing XP curve; main-route levels 4/7/10 before bosses and level 6 at the
  Cinderworks Exchange. Optional XP can reach level 11. Free writ adopts Trapper or
  Sapper at rank two; rank three is a normal upgrade from level nine.
- Three equipment slots, nine approved items, run-only crowns, finite merchants and
  utility supplies. Safe equipment comparisons; swapping cannot heal.
- Energy expedition; Recovery and old saves/test modes remain supported.

## Checkpoints

- [x] Lifecycle, three maps, one-way transitions, boss gates, Waystones, persistence.
- [x] Regional geography, 36 templates, seven-kind coverage, pacing, XP and crowns.
- [x] Equipment, consumables, finite merchants, adopted disciplines.
- [x] Six signature enemies and three solo bosses, automated mechanic verification.
- [x] Required timing/reaction/response-measurement repairs.
- [x] 100-seed validation; transactions, migration and economy tests.
- [x] Four legal automated end-to-end character runs.
- [x] Boss response/punish probes and existing regression suite (expected failure disclosed).
- [x] Desktop rendering, Fold-sized layouts, native input and suspension smoke checks.
- [x] Windows/Android builds and wireless installation/version readback on the Pixel Fold.
- [x] Physical Fold portrait touch, map, frozen time and cold-restart save/resume smoke checks.
- [ ] Human Fold combat, inner-display and sustained performance assessment.
- [x] Final documentation reconciliation. Publish the approved release through the
  normal commit/push workflow, verifying the remote revision independently.

Automated combat success is not evidence of fun or human fairness. Installation and
device testing are reported independently. The documented pre-existing Bandit opening
assertion in `run_state_test.gd` is not permission to hide any additional failure.

## Ownership

`expedition_catalog.gd` owns journey content and economy; `expedition_generator.gd`
owns standalone geography and placement; `expedition_coordinator.gd` owns run-level
progress and transaction rules. Enemy facts remain in `combat_catalog.gd`, ability
facts in `ability_catalog.gd`, and shared state in `state_field_schema.gd`.

The new generator has its own identity. Existing Combat Survey seeds do not change
merely because expedition content is added. Legacy expedition saves retain their
original generator rather than being transplanted onto different geography.

## Content and tuning reference

These are prototype starting values, not permanent balance rules. The executable
owners named above take precedence over duplicated prose when diagnosing drift.

| Biome | Always placed | Two selected and placed from | Boss |
|---|---|---|---|
| Briarwild Foothills | Boar, Hound, Archer, Briarhook, Thornspitter | Knife, Bandit, Earth Caster | Thornhart: 260 health, representative 14 base damage |
| Above-ground Cinderworks | Shield, Javelineer, Fire Caster, Kiln Guard, Slagthrower | Hound, Bandit, Chanter | Kilnmaster: 360 health, representative 18 base damage |
| Stormglass Summit | Polearm, Air Caster, Archer, Glasswing, Bellrunner | Shield, Chanter, Duellist | Bell Regent: 460 health, representative 22 base damage |

The roster has 19 distinct ordinary kinds, including six new kinds. Regional
appearance does not increase that count. Two introductory templates precede the
more demanding combinations; four further main templates and two optional ones
are selected without replacement. Each template declares its interaction, terrain
and permitted rotating substitutions. Typical populations are two or three, never
above four, and at most two ranged-pressure actors. A gong's finite reserve is
already counted in the population and XP budget, not spawned as extra free pressure.

The signature relationships are hook/contact-pull/missed recovery; rooted quill fan;
protected hammer/vent; delayed temporary slag; ally-vaulting fly-through/landing;
and visible gong/one finite reserve. Bosses reuse shared posture, damage, conditions,
projectile allegiance and displacement. Half-health transitions are announced.
The Kilnmaster's parallel lanes preserve a central escape corridor and ground zones
are capped at three. Bell Regent wind deflects player projectiles too.

| Adopted discipline | Rank one | Writ-granted rank two | Optional rank three from level nine |
|---|---|---|---|
| Trapper | 24 Energy; 0.7-second placement, ten-second cooldown; snare lasts 12 simulation seconds, applies 40% slowing for two seconds and three posture damage | Cost 20 | Two active snares |
| Sapper | 30 Energy; 0.9-second action, ten-second cooldown; eight damage, three posture damage and mass-sensitive displacement in radius 140 | Cost 26 | Four posture damage and 50% more displacement |

The first boss grants the writ. The Cinderworks midpoint Exchange exchanges it for
both initial ranks for free, once, permanently. This uses the existing adopted slot;
neither option is an Elementalist spell. The first three Cinderworks main rewards
put a main-route character at level six at that Exchange.

| Slot | Initial items |
|---|---|
| Body | Reinforced Jack: +2 Defense, −1 Speed; Trailcoat: +15 maximum health; Channeler Wrap: +15 maximum Energy |
| Boots | Surefoot: 35% less incoming displacement; Scout: +1 Awareness and Stealth; Runner: +1 Speed |
| Gloves | Gripping: +1 Resolve; Fletcher: +12% physical-projectile range; Inscribed: +1 Intelligence |

Main encounter crowns are 12/16/20 by biome, optional encounters 18/24/30, and the
first two bosses 25/40. Each merchant has three compatible gear choices at 40,
two Rations at 12, and finite knives/bombs/smoke/Repulsion Pots at 12/18/14/16.
No selling, rerolling, stock regeneration, pouch refills or rechargeable bandages.
Two additional finite Rations are placed in each biome: an exploration pocket and
one guarded discovery. Rations heal 15, stack to two, occupy a utility slot and
reject full-health use. The five-charge pouch retains its existing timed 25-health
use. Equipping can clamp current health/Energy downward but never raises either.

### Playing and reporting

Choose Expedition and any of the four existing characters. Explore continuously;
the map exposes discovered routes and a run journal. Near merchants use **TRADE**;
gear on the ground opens its replacement comparison. Waystones explicitly show
locked, single-use or spent status. **LEAVE BIOME** presents a warning and requires
a second confirmation; moving away or reloading does not retain that confirmation.
The third biome has a separate victory exit after its final Waystone. Death/victory
produce an expedition report with biome, encounter, healing, purchasing and boss
events. Reports leave human ratings unrated rather than inventing feedback.

## Verification evidence — October 17

- `expedition_lifecycle_test.gd`: 100 seeds across all three biomes (300 maps),
  player-width connected routes, legal placements, all seven selected kinds, unique
  templates and IDs, population/ranged caps, exact XP/crown budgets, finite discoveries
  and clear respite footprints. These are geometric/content checks, not fun ratings.
- `expedition_systems_test.gd` and `expedition_edge_cases_test.gd`: all four loadouts,
  both adopted disciplines, all six new enemy signatures, guarded rewards, finite
  stocks, atomic-save interruption, legacy migration, irreversible departures, skipped
  and spent stones, victory exit, death rejection, equipment swapping and ration limits.
  Current-expedition resumes preserve enemy commitments, boss phases, exhaustion and
  regeneration delay; an unfinished player action must finish before publishing a save.
  A reproduced merchant-lock regression was fixed: an escaped, unloaded group's
  frozen alert flag no longer blocks a distant safe shop. Nearby alerted actors,
  projectiles and hostile hazards still prevent trading and equipment changes.
- `expedition_boss_responses_test.gd`: all three signatures catch early retreat/orbit
  at their authored ranges. All four characters have a successful defensive answer;
  a range of Dodge timings succeeds. Tests also land an actual recovery punish, check
  posture-only ordinary-hit policy, non-refreshing posture breaks, announced phase
  changes, a legal corridor between furnace lanes, a three-zone cap and symmetric wind.
  The actual second-phase Crosswind → Resonant Volley sequence also permits a clean
  Dodge for all four starting characters at 100 and 290 units: all three tested
  tell timings (0.45/0.50/0.55 seconds into the volley) succeed. A failed Acrobat
  journey motivated this specific response test; that failure was retained, and the
  subsequent test-player policy uses the proved tell response without changing the boss.
- Legal search-driver victories: all four characters, seed 42, main-route level 10,
  three boss kills and all three one-use stones. Both adopted disciplines were used.
  The test driver uses isolated perfect-information forecasts to select **legal public
  requests**; it does not grant resources, teleport, force kills or make the earned run
  invincible. That establishes mechanical feasibility, not human readability or fairness.

  | Character | Adopted discipline | Legal actions | Simulation seconds | Result |
  |---|---|---:|---:|---|
  | Warrior · Vanguard | Trapper | 2,078 | 680.0 | Full victory |
  | Rogue · Sharpshooter | Sapper | 2,259 | 546.1 | Full victory |
  | Mage · Elementalist | Trapper | 3,582 | 855.4 | Full victory |
  | Rogue · Acrobat | Sapper | 3,629 | 767.6 | Full victory |

  These runs clear the main route, not every optional guard. Successful records are
  `.runtime/playthrough-warrior.json`, `.runtime/playthrough-rogue_sharpshooter.json`
  plus `.runtime/playthrough-mage_elementalist-1792198328.json` and
  `.runtime/playthrough-rogue_acrobat-1792199271.json`. Each records three
  boss outcomes, three used Waystones and the actual midpoint discipline transaction.
  The Acrobat finished the final fight at 35 health with no pouch charges before using
  the last Waystone; the final restoration is not counted as surviving that fight.
- Native renderer checked at 1100×760, 450×870 and 700×840, including all three biomes,
  bosses, merchants and distant landmark vistas (citadel, forest and foundry smoke).
  Touch/mouse input, frozen thinking time and held-action suspension
  were exercised. Fold-sized desktop viewports are **not physical Fold testing**.
- Desktop performance sample under concurrent tests: expedition generation 59.57 ms,
  mean short action 7.27 ms, two active / 20 resident actors and four / 13 areas loaded.
  Synthetic 30/50-actor crowds exceed the authored 2–4-enemy encounter budget and show
  scaling costs (17.88/37.70 ms average two-tick frame); these are not mobile frame rates.
- Windows executable starts cleanly. Android package verifies as
  `com.waystone.prototype`, version `0.3.0`, code `300`. Test and audit sources are
  excluded from distribution. Final artifact hashes appear below.
- Wireless pairing and installation on the Pixel Fold succeeded. Package readback
  confirms `0.3.0` / `300`. Actual 1080×2092 portrait title, character selection,
  expedition and map screens were inspected. Touch movement advanced one legal step;
  opening the map and real elapsed thinking time did not advance simulation time.
  Backgrounding, resuming and a full process restart preserved seed, position, health,
  biome and simulation time (0.133333 seconds). The cold restart completed in 337 ms.
  The disposable test's PSS was 320,300 KB; this is not a sustained combat frame-rate
  benchmark. The prior inactive save was restored and its SHA-256 matched the backup.
  Startup reported a shader-cache recompilation warning, not a crash. Inner-display
  play, combat performance and human input/readability acceptance remain unverified.
  The root menu's obsolete “exit levels” subtitle was corrected to “three biomes”.
- The 27-file default regression suite completed with 26 passing files and the one
  documented Bandit expected failure; no additional regression was accepted. The
  extended resume and character-specific punish probes are rerun independently.

### Build evidence

The final Windows executable starts with exit code zero; Android signing and package
verification succeed. These hashes identify the built combat code. The exact APK was
installed after the final menu-text correction; physical-device limits remain as
described above and are not erased by the four automated victories.

- Windows `builds/windows/Waystone.exe` SHA-256:
  `EA49533A0144073CD327E36380F4D494EBF1578C00F0758EC7FD3DB770CEEEFC`
- Android `builds/android/waystone-debug.apk` SHA-256:
  `736D697979D817C8CD8FA2AB15B7EB2E5D130563CF945F898A0D90B0EB54F08E`
- Android package `com.waystone.prototype`, version name `0.3.0`, code `300`,
  minimum SDK 24, target SDK 36. The installed build tools are 35.0.1; the exporter
  reports their selection, signs the APK and verifies it successfully.

### Repeating the checks

Use `run-tests.ps1` for the default regression suite. The expedition lifecycle,
systems, edge-case and boss-response scripts are included. The slow acceptance
driver is intentionally separate: launch Godot headlessly with
`--script tests/expedition_playthrough_test.gd -- <loadout> <trapper|sapper> 42 search`.
Its optional `short` flag selects the shorter-horizon test policy. Failed attempts
are retained as diagnostics; a constructed isolated boss fixture is never counted
as an earned journey. `tests/expedition_visual_smoke.gd` requires the real renderer,
not `--headless`. `build-all.ps1` produces both platform artifacts.

### Known limits

The existing Bandit clean-opening assertion remains a separately documented expected
failure. It has not been erased, relaxed or counted as a new expedition pass. Initial
survey-version and legacy region-count assertions were updated to the current metadata
and geographic-streaming contract; their targeted reruns pass. Failed playthroughs and
a route-follower stall remain diagnostic evidence, not successful runs. Human testing
must still judge pacing, teaching, useful equipment choices and whether boss patterns
feel fair with frozen-time input.
