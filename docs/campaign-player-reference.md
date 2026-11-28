# Campaign player comparison references

`scripts/campaign/campaign_player_profiles.gd` supplies `static func profile(style: String, weapon: String) -> Dictionary`. Accepted styles are `slow` and `fast`. Weapon IDs are `dagger`, `straight_sword` and `greatsword`. Default and unrecognized pairs return an empty dictionary so the regular Campaign can use its existing profile.

| Field | Runtime meaning |
| --- | --- |
| `move_speed`, `step_distance` | Planar simulation units per reference second and units per ordinary committed step. Step duration equals distance divided by speed. |
| `roll_distance`, `roll_duration` | Unobstructed forward travel in simulation units and commitment in reference seconds. |
| `roll_move_end` | Seconds from roll commitment until forward motion completes. |
| `iframe_start`, `iframe_end` | Seconds from roll commitment. The start is inclusive and the end exclusive. |
| `attacks` | Ordered array of neutral one-handed light attacks. Index zero is the single attack or sequence opener. |
| Per attack `startup`, `active_end`, `duration`, `chain_at` | Absolute seconds from this swing's start. Contact applies on [startup, active_end). Recovery to a free decision is duration minus active_end. A committed continuation can start at chain_at. |
| Per attack `reach`, `advance_distance` | Planar simulation units. Reach is measured from the attacker's current origin. Advance is forward travel of that origin near contact, subject to collision. `travel_at_chain` and `travel_at_move` give the cumulative displacements at the two cancel boundaries. |
| Per attack `advance_at` | Reference seconds to the sampled near-contact advance. DS1 uses its estimated or measured contact start. |

## Units and movement

These profiles represent a neutral one-handed light attack on level ground, an ordinary forward jog and a forward medium-load roll. Reference seconds are elapsed seconds of committed neutral play. Campaign converts these to simulation time with its execution rate and character tempo. Deliberation adds zero simulation time. Below, [10,12) means two active 30 Hz ticks, with first contact 0.333 s after commitment.

Campaign divides planar X and Y by `U = 100.0` to place geometry on Godot X and Z. This comparison assigns one reference metre to one Godot world unit, or 100 planar units. Camera pixels have no role in the conversion. undakovrist measured DS1 ranges using coordinate differences. A separate examination of the original PC engine identifies position delta multiplied by the native tick rate as metres per second. The ER motion exporter specifies metres. Equating the physical scale across games is a design choice. [Campaign projection](../scripts/campaign/campaign_board.gd) · [DS1 coordinate semantics](https://github.com/zofrea1/DS1-FPS-Unlock-PTDE-Remastered) · [ER motion format](https://github.com/AtomechLLC/game-animation-library/blob/7d6a5712946e7a5fbd183ff0d75a29e531e412cb/tools/frame_data/export_er_models.py#L402-L445)

| Movement | Slow / Dark Souls | Fast / Elden Ring |
| --- | --- | --- |
| Ordinary move | 260 units/s, calibrated to the existing Waystone Warrior. DS1 course tests establish a load effect. An absolute medium-load speed remains unknown. | 401.2 units/s, derived from 2.8083 m over 21 intervals in the 30 Hz forward jog loop `a000_020100`. This is clip speed. An independent visual estimate gives 3.20 m/s, leaving live controller speed uncertain. |
| Committed step | 34 units / 0.131 s | 34 units / 0.085 s |
| Forward medium roll | 245 units / 1.100 s. Distance and forward travel ending at 20/30 s are calibrations. Travel clears approximately one DS1 Dagger opening range. | 331.6 units / 0.733 s. `a000_027110` travels 3.3159 m by its Move cancel at tick 22. A 1.06 live measurement reported 3.21 m. |
| Invulnerability | [0,11/30) s. vageta31 measured 11 protected ticks of a 33-tick roll before the PC release. KC reports protection ending at 0.30 s and movement at 1.06–1.10 s. The profile uses the first experiment's pair. The sources differ by two protection ticks. | [0,13/30) s, then nine vulnerable ticks before movement. The Explorer marks [13,16) as effect-dependent. Right Attack and Dodge cancels occur at ticks 20 and 21. |

The 34-unit decision step belongs to Waystone. Both source games have continuous locomotion. Roll distance is for unobstructed travel. [Waystone movement constants](../scripts/core/run_state.gd) · [DS1 jog experiment](https://www.youtube.com/watch?v=5od2FVvX9zQ) · [DS1 roll experiment](https://gamefaqs.gamespot.com/boards/606312-dark-souls/63774400) · [KC debug measurements](https://docs.google.com/document/d/1J_-2gMV6nno65vaeSrkRCrPLCTyWzx3BH7b5RPWxnkM/edit) · [ER speed estimate and animation IDs](https://www.nexusmods.com/eldenring/articles/737) · [ER live roll measurement](https://www.reddit.com/r/Eldenring/comments/wl5mh2/106_iframe_distance_changes/)

## Dark Souls weapon evidence

NewLondoLayingHollow timed uninterrupted neutral attacks and reported average attacks per second (APS). Time resolution was about 0.1 s per timed set. The author estimated about one 30 Hz frame of uncertainty per attack for sets of three or more. The exact build is unspecified. undakovrist tested the farthest consistent opener hit against a frozen Hollow Soldier in Undead Burg, increasing the starting separation by 0.05 coordinate units. This includes forward advance and the target body. The experiment covers the opener only. [Original timing experiment](https://www.reddit.com/r/darksouls/comments/bqk3mn/) · [RocksInMyDryer's named-weapon rows](https://docs.google.com/spreadsheets/d/1gTgL5T0qLRLadnsep58HGWj8vZv2J4LtsF75SnHn_5k/edit) · [undakovrist's range measurements and method](https://docs.google.com/spreadsheets/d/1efEAz6ofer9W-kNd4g1k9Uqt8bBEHrSVWgN4paznSAc/edit)

| One-handed R1 | Attack Speed row / 1H R1 | Neutral attacks row / 1h r1 | Runtime conversion |
| --- | --- | --- | --- |
| Dagger | 24 / 2.19 APS | 5 / 2.40 | Same-hand interval 0.457 s. Estimated opener contact at 0.285 s and free movement at 0.628 s. |
| Longsword | 7 / 1.52 APS | 14 / 3.25 | Same-hand interval 0.658 s. Estimated opener contact at 0.407 s and free movement at 0.909 s. |
| Claymore | 23 / 1.01 APS | 27 / 3.45 | KC's 1H R1 A/B starts at ticks 20/18, reswings at 31/29 and allows movement at 43/40. Their mean reswing interval is 1.000 s, within 0.010 s of the independent APS result. |

KC's **Fast Greatswords** entry includes Claymore. It records the opening hit at 0.67 s and the return at 0.60 s. The active-window ends are missing, so both swings borrow their ER counterpart's three-tick active window. KC lists only two-handed Dagger timings and gives no matching Longsword 1H R1. For those two weapons, each swing gets the measured mean interval. Startup, active end and free movement use the corresponding ER swing's event-to-reswing ratios multiplied by that interval. The inferred DS1 opener can therefore reach contact sooner than the ER opener. The comparison preserves weapon differences within each game. [KC's debug sheet and definitions](https://docs.google.com/document/d/1J_-2gMV6nno65vaeSrkRCrPLCTyWzx3BH7b5RPWxnkM/edit)

The DS1 reach split uses the ER counterpart's opener radius as a proxy. Subtract that radius and Waystone's 28-unit reference target radius from the measured centre separation to obtain forward advance. For Longsword, 325 − 211 − 28 = 86 units. Dagger gives 49.1 and Claymore 104.2. Each return reuses its opener's reach and advance. DS1 post-contact travel is calibrated to zero. Direct measurement supports only the three opening centre separations.

## Elden Ring weapon evidence

Emilia's Frame Data Explorer identifies Dagger (weapon ID 1000000), Longsword (2000000) and Claymore (3180000) in regulation 1.17. Filter on the exact weapon name in `users` and require an Attack event. Read the active interval, the Regular RightAttack cancel and the Regular Move cancel. The nominal Longsword R1 9 entry has no Attack event. A generic attack cancel can open earlier for the other hand. The active and Move boundaries match the independent 1.17.3 extraction after conversion from inclusive one-based frame numbers. The published frame clock already accounts for speed changes such as the Claymore opener's gradient. [Explorer](https://er-frame-data.nyasu.business/) · [Regulation 1.17 animation records](https://er-frame-data.nyasu.business/generated/1.17/animations.json) · [Pinned 1.17.3 records](https://github.com/AtomechLLC/game-animation-library/blob/7d6a5712946e7a5fbd183ff0d75a29e531e412cb/frame-data/elden-ring.json)

| Animation prefix | Swing suffixes in order | Active windows, ticks | RightAttack ticks | Move ticks |
| --- | --- | --- | --- | --- |
| Dagger `a020_` | 030000, 030010, 030020, 030030, 030040, 030050 | [10,12), [8,10), [9,11), [8,10), [9,11), [14,16) | 16, 14, 15, 15, 16, 32 | 22, 20, 23, 19, 25, 33 |
| Longsword `a023_` | 030000, 030010, 030020, 030030, 030040 | [13,16), [13,15), [13,16), [11,14), [18,22) | 21, 23, 20, 23, 44 | 29, 28, 28, 28, 45 |
| Claymore `a025_` | 030000, 030010, 030020, 030030 | [15,18), [15,18), [16,19), [22,27) | 32, 32, 32, 46 | 42, 42, 43, 54 |

Spatial values use Atomech's 1.17.3 numerical 30 Hz tracks at commit `7d6a571`. Each animation ID above identifies a matching `FDA2` track. Subtract the first sample from each forward root coordinate (forward is −Z). To obtain radial reach independently of root motion, transform the weapon's hitbox endpoints to character space using its variation (100, 200, 318), the swing's behavior judge, and the right weapon socket's half turn about Z. For each active sample, take the larger horizontal endpoint radius plus capsule radius. Select the largest result and record forward root travel at that same sample. This projects the 3D swing into Waystone's planar attack shape. Vertical clearance, target motion, facing and walls can change actual contact. [Data inventory](https://github.com/AtomechLLC/game-animation-library/blob/7d6a5712946e7a5fbd183ff0d75a29e531e412cb/docs/reports/elden-ring-data-inventory.md) · [Exporter](https://github.com/AtomechLLC/game-animation-library/blob/7d6a5712946e7a5fbd183ff0d75a29e531e412cb/tools/frame_data/export_er_models.py) · [Coordinate and socket transforms](https://github.com/AtomechLLC/game-animation-library/blob/7d6a5712946e7a5fbd183ff0d75a29e531e412cb/frame-data/viewer3d.js)

| ER opener, planar units | Reach | Advance at widest active sample | Advance by reswing | Advance by free movement |
| --- | ---: | ---: | ---: | ---: |
| Dagger | 162.9 | 116.2 | 146.1 | 153.4 |
| Longsword | 211.0 | 147.5 | 150.8 | 149.3 |
| Claymore | 212.8 | 143.0 | 190.9 | 201.3 |

The module contains all 15 ER swings. To approximate the sampled motion, interpolate cumulative forward travel through four points: (0, 0), (`advance_at`, `advance_distance`), (`chain_at`, `travel_at_chain`) and (`duration`, `travel_at_move`). Start the next swing at the reswing endpoint when chained. A full sequence adds each nonfinal swing's `travel_at_chain` and the finisher's `travel_at_move`. A smaller final displacement can reflect a step back in recovery. An adapter that advances only during startup omits the later displacement. Roll interpolation likewise preserves the endpoint while approximating the speed curve.

For a single Claymore swing, Elden Ring contact starts at 0.500 s, the next right-hand swing opens at 1.067 s and free movement opens at 1.400 s. DS1 gives 0.667, 1.033 and 1.433 s respectively. The ER medium roll returns to movement 0.367 s sooner. Waystone freezes at the end of the chosen commitment.

The older sovietspaceship repository publishes regulation directories through 1.08. The hosted Explorer supplies the later timing data above. Funny-Bones describes how to extract root motion from a locally owned copy, but excludes its generated action table. Atomech's published tables and motion tracks supplied the spatial measurements. The DS1 sources inspected lacked equivalent per-frame tracks for these attacks. [Historical ER dataset](https://github.com/sovietspaceship/elden-ring-frame-data-explorer-data) · [Funny-Bones source availability](https://github.com/Funny-Bones/ELDEN-RING-Combat-Rewrite#how-faithful-it-is)


## Verification

Godot 4.7 loaded six profiles and checked 21 swing records for phase order, distance bounds, fallback behavior and independent return values. A separate numerical check compared the Godot values with all 15 ER hit windows, movement cancels and spatial rows, the forward jog and roll samples, and all three DS1 experimental range and cadence rows. These are data-level checks. Collision in the assembled Campaign and acceptance of feel require separate evidence.
