# Campaign enemy comparison

Regional Campaign uses `CampaignEnemyProfiles.profile(style, kind)`. Use `slow` or `fast` with `blade`, `knife`, `shield` or `polearm`. Other pairs return an empty dictionary. Keep the current Catalog and normal AI for those pairs.

## Gameplay integration

| Profile key | Meaning |
| --- | --- |
| `attacks` | Ordered Array of complete melee options in the native `MELEE_ATTACK_PLANS` format. Index zero opens the phrase. Each later option is a separately committed follow-up with its own direction, hit state and telegraph. |
| `chain_chances` | Conditional probabilities, one per transition. Test once at the preceding attack's `chain_at`. Continue only while the target is in range and in sight. Interruption, death or a failed chance roll ends the phrase. The last attack takes its full recovery. |
| Per attack `distance`, `reach`, `advance_distance` | Center distance for commitment in Waystone, weapon extent from the moving actor origin and authorized forward travel respectively. Use collision for committed travel. |
| Per attack `startup`, `active_end`, `duration`, `chain_at`, `advance_end` | Seconds from this swing's start during unfrozen playback. Campaign converts these to the attacker's local clock once when committing the move. |
| `move_speed` | Calibrated neutral pursuit speed in planar units per real second during active play. Campaign converts once for playback and personal tempo. |

## Where to compare

Start at Dawn, take the ridge stairs at (2290, 530), then walk east into Windbreak. Use the same character, seed, HP, energy and consumables for each fresh Campaign. The solo Polearm compares behavior at a fixed seat. The mixed encounter deliberately varies composition as well as individual behavior.

| Regular Campaign place | Default | Slow | Fast |
| --- | --- | --- | --- |
| Bell Road 200, Ridge Stairs, (2650, 540) | Polearm | Polearm | Polearm |
| Bell Road 201, Windbreak, forward (3260, 595) and rear (3440, 745) | Shield + Knife | Shield + Blade | Blade + Knife |
| Dawn east ruin, Blade (1850, 980) and Archer (2200, 950) | Blade + Archer | Blade + Archer | Blade + Archer |

The Windbreak wall begins at (2990, 400) and measures 150 × 260 units. The southern opening lets the player approach one fighter with the other still screened. Slow's shield has one long committed thrust. Passing its point gives time for a counter, but staying to finish a combo invites the Blade's return cut. Fast's Blade can commit a second cut, and the Knife can flank while the player deals with the first. At the stairs, watch whether the player escapes the point by moving sideways, commits a cut during recovery, or rolls through and takes a new bearing. Shield and Knife are existing Waystone roles. The reference groups supply selected attack behaviors. The roster, walls, cover, alert system and Archer's projectile are Waystone's own. [Regional layout](../scripts/campaign/campaign_regions.gd) · [Campaign integration](../scripts/campaign/campaign_state.gd)

## Dark Souls I — Undead Burg

The Burg map's AI dump identifies a light sword Hollow (254000), a longsword soldier (255001) and a spear soldier (255000). The Remastered NpcThinkParam rows for all three have near/mid/far/out distances 1.5/3.5/10/20, sight distance 30 and hearing distance 10. The individual battle goals specify substantially different attack distances within those bands. The wiki records both sword attacks from a sprint and consecutive spear attacks. [Burg AI directory at the inspected revision](https://github.com/Grimrukh/SoulsAI/tree/0dcd0c400e88c26c9367fa840793a5ac668090ac/ai_scripts/m10_01_00_00) · [Remastered AI rows](https://github.com/dark-souls-playground/dsr-data/blob/9dfe98d12ad2ad405f46795b23aa251c0702f391/param/GameParam/gameparam.parambnd/AI.json) · [Undead Soldier field notes](https://darksouls.wikidot.com/undead-soldier)

| Waystone kind | Source selection and follow-up | Transfer |
| --- | --- | --- |
| Blade | 254000 Act03 closes to 2.2. Its 3003 opener queues one, two or three attacks with 20%, 35% and 45% probability. [Act03](https://github.com/Grimrukh/SoulsAI/blob/0dcd0c400e88c26c9367fa840793a5ac668090ac/ai_scripts/m10_01_00_00/254000_battle.lua#L77-L95) | Conditional chances of 80% after the first attack and 45/80 after the second reproduce the three outcomes while the target stays in range. |
| Knife | 254000's first default action uses attack 3010 with a 2.0 distance parameter. [Sword Hollow](https://github.com/Grimrukh/SoulsAI/blob/0dcd0c400e88c26c9367fa840793a5ac668090ac/ai_scripts/m10_01_00_00/254000_battle.lua#L48-L66) | A single short-range action rendered as the existing Knife cut. This is a light-infantry proxy. |
| Shield | 255001 Act07 approaches to 4.1 and issues one attack, 3005, with a 75 guard parameter on the approach. The heavy soldier attack table includes a running longsword thrust. [Longsword soldier](https://github.com/Grimrukh/SoulsAI/blob/0dcd0c400e88c26c9367fa840793a5ac668090ac/ai_scripts/m10_01_00_00/255001_battle.lua#L154-L165) · [Remastered NPC attacks](https://github.com/dark-souls-playground/dsr-data/blob/9dfe98d12ad2ad405f46795b23aa251c0702f391/param/GameParam/gameparam.parambnd/NonPlayerAttacks.json) | A long, narrow sword thrust with one punishable recovery. Waystone uses its normal shield and ward rules. |
| Polearm | In 255000 OnIf code 0, at 1.5 ≤ gap < 2.8 on the unguarded-target branch, a 60% decision leads to a 3000 thrust phrase. Within it, one, two and three hits have 30%, 40% and 30% odds. [Spear soldier](https://github.com/Grimrukh/SoulsAI/blob/0dcd0c400e88c26c9367fa840793a5ac668090ac/ai_scripts/m10_01_00_00/255000_battle.lua#L36-L64) | 2.8 outer band and conditional 70%, then 30/70. Waystone uses the attack branch as its selected sample. The original also circles or retreats. |

The selected Slow strikes have authored timing. The original Lua gives goal timeouts and positioning decisions. For example, interpreting the 10 in a common attack subgoal as a ten-second attack would be wrong. The Remastered attack rows 255000–255002 give 165/167/169 physical attack power, a 0.20 hit shape radius and 0.45 knockback distance. These describe offensive power, capsule thickness and an effect on the defender. None supplies the attacker's forward motion or the first damaging animation tick. The publicly documented animation index and the available move/footage references did not establish exact motion or complete phase timings for these particular Hollow attacks. [NPC attack rows](https://github.com/dark-souls-playground/dsr-data/blob/9dfe98d12ad2ad405f46795b23aa251c0702f391/param/GameParam/gameparam.parambnd/NonPlayerAttacks.json) · [DS1 animation index](https://soulsmodding.com/doku.php?id=ds1-refmat:animation-list)

## Elden Ring — Gatefront infantry

Godrick Soldier is character c4311. The one-handed sword uses AI 431000. Its base and shield-style sword groups have matching first-contact ticks on the selected cuts. The spearman uses AI 431030 and group 4. Gatefront has several sword-and-shield soldiers. The comparison uses infantry and excludes the Godrick Knight who patrols the camp. [Character rows](https://github.com/soulsmods/Paramdex/blob/ff7245e524329bc3eab00036723d2bd53384cedf/ER/Names/NpcParam.txt) · [Gatefront shield locations](https://eldenring.wiki.gg/wiki/Brass_Shield) · [Godrick spear soldier reference footage](https://www.youtube.com/watch?v=L9stZBplbQY)

| Kind | Selected action and distance | First damaging event in 30 Hz ticks from each clip's start |
| --- | --- | --- |
| Blade | Sword Act02 approaches to 2.5. It queues 3006 and randomly chooses 3002 or 3003. The comparison selects 3002 for a repeatable second cut. [Act02](https://github.com/cyberworm-uk/er-ai/blob/b796a5b346498d2e40f846fb8a9b3f93e16872dd/431000_battle.dec.lua#L1318-L1368) | 22 then 30. The alternate finisher starts at tick 35. |
| Knife | Sword Act10 approaches to 2.5 and queues 3005 alone. The Knife borrows this quick single attack and its Waystone flanking route. [Act10](https://github.com/cyberworm-uk/er-ai/blob/b796a5b346498d2e40f846fb8a9b3f93e16872dd/431000_battle.dec.lua#L1528-L1548) | 12. |
| Shield | Sword Act01 approaches to 2.5, queues 3000 → 3001 → 3002/3003, and passes distance arguments 2.5/2.5/3 to the subgoals. The comparison selects 3002 and rechecks range and sight on every link. [Act01](https://github.com/cyberworm-uk/er-ai/blob/b796a5b346498d2e40f846fb8a9b3f93e16872dd/431000_battle.dec.lua#L1261-L1314) | 24, 17, 30. |
| Polearm | Spear Act02 approaches or withdraws toward 3.2 and queues 3100. The comparison uses that spacing and the single thrust. [Act02](https://github.com/cyberworm-uk/er-ai/blob/b796a5b346498d2e40f846fb8a9b3f93e16872dd/431030_battle.dec.lua#L444-L495) | 18, key 431104003100. |

The published extractor resolves the first damaging attack behavior against the enemy's attack tables. Its key is character number × 100,000,000 + full animation ID. For c4311, keys 431100003000/1/2/3/5/6 have earliest damaging events at 0.800/0.567/1.000/1.167/0.400/0.733 seconds. Group 4 animation 4003100 gives 0.600 seconds. The data file rounds to milliseconds. The module converts these entries back to the nearest 30 Hz tick. In play, contact also requires the weapon to intersect a target. A roll can clear the strike even after its damaging window opens. [Measured sword data](https://github.com/Banon-Labs/er-mods-rs/blob/72de5aed9deadab00f14efc1c42053599aa88b7e/scripts/frida/ai-lua/data/attack_table.lua#L4681-L4687) · [Measured spear data](https://github.com/Banon-Labs/er-mods-rs/blob/72de5aed9deadab00f14efc1c42053599aa88b7e/scripts/frida/ai-lua/data/attack_table.lua#L4763-L4772) · [Extraction method](https://github.com/Banon-Labs/er-mods-rs/blob/72de5aed9deadab00f14efc1c42053599aa88b7e/scripts/er-attack-windup-table.py)

## Units, recovery and uncertainty

The world projection uses **100 Waystone planar units per reference metre**, matching the player comparison. The module projects one AI distance unit as one reference metre and compares the result with Waystone's center-to-center distance. The native AI functions may include capsule clearance. Exact equivalence of native and Waystone distance origins is unverified. The approach parameter and the attacker's displacement are supplied independently. The original AI dumps and timing extract are pinned above. Their publishers do not identify an exact game patch for each input, so the commit identifies the inspected data version.

| Opening attack | Commit distance | Weapon reach | Body travel to first active tick | Startup / active / recovery to free action, seconds |
| --- | ---: | ---: | ---: | --- |
| Slow Blade | 220 | 173 | 67 | 0.833 / 0.200 / 0.967 |
| Fast Blade | 250 | 175 | 87 | 0.733 / 0.167 / 0.667 |
| Slow Knife | 200 | 133 | 55 | 0.600 / 0.133 / 0.700 |
| Fast Knife | 250 | 140 | 100 | 0.400 / 0.167 / 0.600 |
| Slow Shield | 410 | 197 | 200 | 1.167 / 0.233 / 1.033 |
| Fast Shield | 250 | 187 | 70 | 0.800 / 0.167 / 0.733 |
| Slow Polearm | 280 | 255 | 33 | 0.800 / 0.200 / 1.033 |
| Fast Polearm | 320 | 275 | 53 | 0.600 / 0.200 / 0.667 |

Attack-specific root-motion tracks and weapon endpoint trajectories were unavailable for these enemies. The ER reach study publishes a player-weapon motion breakdown. Its character is c0000. Applying those tracks to c4311 would misidentify the performer. All weapon extents and attacker travel in this table are therefore **Waystone estimates**. They give the spear a long point and short step, charge the Slow Shield's longer strike distance to body movement, and let an on-axis stationary player be reached from the commitment boundary. Walls can shorten the travel. The Slow timing, both styles' active widths, chain points and free recoveries are also **Waystone estimates**. The values are chosen around a visible commitment, a separate attack on each continuation and a recovery the player can spend. Fast can have a deliberately delayed finisher. [Reach study and its source character](https://github.com/Banon-Labs/er-mods-rs/blob/72de5aed9deadab00f14efc1c42053599aa88b7e/docs/er-mechanics/reach.md) · [Full per-strike data](../scripts/campaign/campaign_enemy_profiles.gd)

The selected AI records establish approach goals but do not give a reliable neutral walking speed. For this test, pursuit is calibrated against each style’s player jog (260 or 401.2 units/s). Shield advances at 65% of that pace, Polearm at 78%, Blade at 88%, and Knife at 110%. These fractions preserve the roles of the screening shield and pursuing knife and are Waystone estimates. A player can widen the gap against the shield on open ground; the knife can gain on a straight retreat. Damage, HP and posture retain the existing Waystone rules. The two style names identify reference sets. No global enemy-speed ratio was measured. Gameplay clocks and collision stay with the regular Campaign. Independent feel judgments require play.

## Verification

A Godot 4.7 headless check loaded the regular regional Campaign state at seed 131137 in all three styles. It verified the authored Ridge Stairs and Windbreak rosters and 84 assertions in total. For each reference style it took the ridge transition, placed a stationary target at the actual Polearm resident's commitment boundary, and advanced time through Wait. The resident advanced and hit, reducing HP from 100 to 86 in each case. At Windbreak the front resident was isolated to exercise its own action. Slow produced the Shield thrust and Fast produced both Blade attacks. This is a scripted encounter check. Mixed-pressure outcomes, rendered telegraphs and Guy's judgment of feel require play.
