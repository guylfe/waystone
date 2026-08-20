# Waystone Prototype

Current prototype version: `0.2.21` (Android version code `221`).

### v0.2.21: Exhaustion gets its two seconds back

The `0.2.20` survey answered the question it was built to answer, and the answer was not the expected one. Exhaustion was **not** being timed for safe moments: an enemy was alerted for **100%** of exhausted time across all three lockout rooms, at a mean nearest distance of 70 to 189 units. It still cost 2 damage in 8.33 seconds against an expected 9.8 at the run's own rate.

The line that explains it is `0 with an attack already committed`, in all six lockouts. Alerted and close, but not one had launched — which suggests exhaustion is **self-covering**: the combo that empties the bar staggers the enemies that would punish you, and their reaction covers the window.

- **`EXHAUSTION_DURATION` returns to 2.0** from the 1.2 that `0.2.17` adopted to offset the movement slow. There was no danger to offset. If the self-covering reading is right, the first second or so is protected regardless of duration, so this adds roughly 0.8s of genuinely exposed tail where there was almost none — a larger change than doubling the number implies.
- **Alerted enemies are split by whether they can act.** The threat snapshot now separates those in stagger or hit reaction from those free to attack, which is what tests the hypothesis directly rather than inferring it.
- **Closest-approach means are no longer corrupt.** An interrupted attack never opens a damaging window, so it has no closest approach; the `9999` never-sampled sentinel was being averaged in, producing the nonsense values `4994.5`, `4966.9` and `1401.7` in the `0.2.20` report. Unsampled records are now excluded and the column reads `n/a` when nothing was measurable.
- **The zeroed strike row is properly fixed.** `0.2.19` restored the player position and facing but left the weapon arc at `(0,0)`. Those coordinates are now recorded at probe creation regardless of whether an enemy is found. The enemy coordinates stay absent, because there is no enemy.
- **Survey report format 16.**

A note on run-to-run noise: `0.2.19` and `0.2.20` changed no gameplay at all, yet fun moved 2.64 to 2.18 and tactical interest 2.43 to 2.18 between surveys. Rating differences below roughly half a point are variance, not signal.

### v0.2.20: Measure states, not attempts

`0.2.19` shipped a counter of actions refused for Stamina. It was worthless, and for a reason worth writing down: it counts deliberate presses of a disabled control, and a player who can read a greyed-out button never makes one. It would have reported zero whether exhaustion was crushing or irrelevant. The rule it violated — **measure states, not attempts** — is the same one behind the interrupted-attack loss fixed in `0.2.19`: any metric that requires the player to do something futile records their competence rather than the system's behaviour.

- **The refusal counter is removed** and replaced by two measures that accrue from the bar's state regardless of what is attempted against it.
- **Time unable to afford a full combo**, alongside the existing time unable to afford a basic attack. The band between them is the interesting one: you can open a sequence but cannot commit to finishing it, which is the actual decision the resource creates.
- **Time exhausted with an enemy alerted**, sampled continuously rather than only at the two endpoints of each lockout. This is what separates "the slow has no teeth" from "the lockout is timed for moments already made safe" — a distinction damage figures cannot draw, because deliberate play keeps both at zero.
- `Combo continuations prevented by exhaustion` is retained and was wrongly dismissed earlier. It fires when a *held* input meets an empty bar, which needs no decision to try, so it is a valid passive measure. It read zero across the `0.2.18` survey because emptying precisely at a link point is uncommon at 0.65 scale, not because it cannot fire.
- **Survey report format 15.**

### v0.2.19: The survey stops hiding the attacks you win

No balance changes. `0.2.18` played well — fun 1.36 to 2.64, exhaustion at 3.0 lockouts per minute — but two of the conclusions drawn from its report were artifacts of the report itself, so this fixes the instrument before anything else is tuned against it.

- **Interrupted enemy attacks now resolve instead of vanishing.** `_finalise_capture_record` ran only when a melee action reached its own duration, and interruption replaces the action wholesale — so every attack the player cut down was silently dropped. The survey counted only attacks the player *failed* to pre-empt, which is the population most likely to have landed. The `0.2.18` report claimed 11 resolved attacks across 279 seconds; its own strike log showed at least 20 melee commitments in the same rooms. Records now carry an `interrupted` resolution and `interrupted_at_f`, the point in the wind-up where the answer landed, so being cut down before the damaging window is distinguishable from being staggered out of a swing already committed.
- **Threat context at exhaustion**, measured by alerted state rather than proximity — a caster at 600 units is threat and distance says otherwise. Both ends of the lockout record how many enemies are alerted, how near the closest is, and whether any had already committed an attack, with the time until its damaging window opens. This exists to answer whether exhaustion arrives during danger or after the danger is dead, which damage figures alone cannot separate from deliberate play.
- **Refused actions and starved time.** A resource's cost lives in the choices it denies, and nothing recorded them. Every action declined for Stamina is counted, alongside time spent below the price of a basic attack.
- **A swing that finds nobody no longer prints as a corrupt record.** Strike diagnostics with no enemy in range emitted every coordinate as `(0,0)`; they now carry the real player position and facing.
- **Survey report format 14.**

### v0.2.18: Exhaustion you can actually reach

The `0.2.17` survey falsified its own change. The exhaustion design worked — the one room that reached it rated 3/5 against a survey mean of 1.36, with the note *"I got exhausted and it seems to work well. it needs to be less difficult to get to though"* — but it fired four times in 205 seconds of combat, 1.2 lockouts per minute against 4.1 in `0.2.15`. Exhausted time fell from 13.6% of combat to 2.7%. The tester could not empty the bar deliberately.

The error was sizing costs against a static bar instead of against a fight. Room 11 spent 202 Stamina — twice a full bar — without a single lockout, because 4.1 seconds of regeneration returned 115 of it.

- **`STAMINA_COST_SCALE` 0.5 → 0.65.** Chosen by replaying every room of that survey rather than by feel: Room 1 finishes at 89 of a 100 bar and stays clean as an easy room should, Rooms 4 and 11 exhaust once, and the death room lands exactly at the edge. A basic attack now costs 11.7, a Dodge 11.7, a sword combo 36.4 — three combos to a bar.
- **Sweeping Cut is exempt from the scale and costs a flat 56.** The original reasoning — charge the combo's full price for skipping the combo's time — assumed 1.9 saved seconds were worth about a combo's Stamina. They are not, once Stamina regenerates at 28/s. Halving it to 28 brought back *"sweeping is still too easy"*, with the death room played as five sweeps and one combo. Price parity cannot restrain an action that refills faster than its advantage decays, so the sweep now costs 1.54 combos outright and a full bar holds two.
- **Per-room desperate Dodge chains are reported per room.** A maximum is not a difference, so the delta block was emitting the run-wide value and rooms with no desperate Dodge at all reported `0 (longest chain 1)`.

Untouched deliberately: regeneration. Rooms 3, 6 and 7 already showed *zero* regeneration — aggressive play never enters a regeneration-eligible action — so cutting the rate would punish careful play and leave aggression alone, which is backwards.

### v0.2.17: Stamina breathes, and exhaustion has teeth

Stamina was a bookkeeping layer rather than a pressure system: it cost a lot, paused, then snapped back, and running out was safer than average play (0.47 damage per second while exhausted against 0.59 overall). Exhaustion was a rest. This rebuilds the resource around continuous recovery and a punishment that lands in the legs.

- **Every cost is halved.** `STAMINA_COST_SCALE` scales the authored numbers at the point of spending, so the relationships stay readable in source: the sword combo still totals 56 raw and Sweeping Cut still equals it exactly. In play a full combo costs 28, a Dodge 9, and a full bar carries three sweeps with the fourth overdrawing.
- **Regeneration is continuous.** Spending no longer arms a delay. The rate drops from 60/s to 28/s and simply runs, so the bar refills while you reposition instead of holding still and then snapping back. Only a hit suppresses it, and only for 0.5s.
- **Exhaustion slows you to 45% of walking speed** — 117 u/s against a base of 260. That is below the capture escape threshold of every fast enemy (Knife 144, Bandit 142, Blade 131) and above the slow ones (Shield 103, Brute 91), so overdrawing loses you the fights footwork was carrying and does not strand you in a room of Brutes. Its duration drops from 2.0s to 1.2s to compensate.
- **Attacks stay locked while exhausted; the Dodge does not.** Milestone B's floor — a hit must always leave one executable response — outranks the lockout. The desperate Dodge travels 90 units instead of 150, carries 0.16s of i-frames instead of 0.24s, and runs 0.75s instead of 0.56s. It clears one envelope and never a second.
- **Its cost is debt, not Stamina.** Taking it empties the bar and restarts the exhaustion clock at the same flat duration every time. Chaining is self-limiting without escalation: at 117 u/s only the dodged attack misses, so a chain resolves in damage rather than stalling.
- **Survey report format 13** adds desperate Dodge counts with the longest chain, and relabels exhaustion damage to name the slow.

### v0.2.16: A chosen Defense owns the next tap

- Selecting Dodge and then tapping an enemy committed an **attack** instead, silently discarding the Defense the player had already chosen. Tapping an enemy now aims the Dodge at it, exactly as dragging already did.
- The same path also skipped the attack-plausibility check, so the discarded Dodge became a swing at a target well out of reach.
- Ordinary enemy taps with nothing selected still attack, and other selected actions are unchanged.

### v0.2.15: Sweeping Cut is the finisher, arriving early

- Sweeping Cut is now the Sword combo's third strike, available immediately, at the combo's full price. It had become a strictly better version of the strike it was meant to mirror: a `160` degree arc against the turning slash's `117`, at the same reach, in 23% of the combo's time for 61% of its Stamina — so building the sequence for its own finisher was never the correct play.
- It now shares the finisher's geometry, damage and posture, and costs `56` Stamina: exactly what the three combo strikes cost together. What you buy is the *time* you skip, and you pay the full price for it.
- Its terminal recovery is served in full under both rule profiles. Stamina rules previously shortened it, so the commitment the player could see was not the one they paid; physical timing is shared and only the resource model differs.
- The anti-spam cooldown is gone under Stamina rules, matching Drawing Cut. It is governed the way every other physical attack is — commitment, recovery and cost. Recovery rules keep their own budgeting. A second sweep is still reachable by overdraw, and empties the bar into an exhaustion lockout.
- `Long Reach` still grants its authored `+20` reach to the chosen Sword Art. Even fully upgraded, the rebuilt footprint is smaller than the old base sweep.

### v0.2.14: Capture telemetry

- Combat Survey report format 12 records one entry per hostile melee attack: what the player did about it, when they did it as a fraction of the attack's wind-up, how near the attack came, and how it resolved. Attack capture assumes each attack's authored walk-safe fraction is honoured in play, and until now nothing checked that against evidence.
- Reports now carry a per-attack comparison of authored intent against what players actually achieved, plus a walk-only escape rate — how often ordinary movement alone was enough. Those two numbers are what `f` should be tuned from.
- A flinch is not a response: hit reactions and staggers no longer count as the player's answer to an attack, so someone who never chose anything is not scored as reacting instantly.
- Clean evades are now counted by source, and Turnabout is counted when primed and when consumed. Ordinary movement stopped earning clean-evade credit in `0.2.13`, so these say whether Dodge and Vault still raise the event often enough for the Acrobat's capstone to be worth its rank rather than leaving that to assumption.

### v0.2.13: Attack capture

- Enemy melee attacks now travel forward as they swing. Previously an attack triggered at roughly its own maximum reach and then stood still through its entire wind-up, so it could not hit a player walking away at any plausible speed -- and reacting on the first frame of a telegraph produced the same result as reacting on the last.
- Walking is still a real defensive tool. What changed is that its effectiveness now depends on *when* it starts: reading a telegraph early escapes, reacting late does not, and Dodge covers the band between. The Warrior's movement speed is untouched.
- Each attack authors one number -- the fraction of its wind-up during which walking still saves you -- and its forward travel is derived from that, so tuning is a statement of intent rather than a physics constant.
- Attacks travel the line they committed to and do not steer, so an early read still escapes and each one stays a commitment rather than a homing move. Arcs plant before their damaging window; thrusts and the smash carry through, because their geometry is still extending while the attack is live.
- Wait now costs one movement step rather than a flat half second, derived from `MOVE_RANGE / player_move_speed` so waiting in place is never coarser than pacing in place. Holding chains units, each a discrete commitment. It is deliberately unassisted -- Wait is movement without the repositioning and carries movement's risks too, which only becomes a real decision now that standing still is dangerous.
- Ordinary movement no longer earns clean-evade credit; that reward belongs to authored defensive techniques. Dodge and Vault i-frames still raise the event, so the Acrobat's Turnabout keeps working.
- Being hit no longer regenerates Stamina, and taking damage now interrupts Stamina recovery, so sustained pressure suppresses it without touching the regeneration rate or the walking rule.
- Expect the first survey after this to feel too hard. That is the correct direction of error.

### v0.2.12: Deliberate strike commitment

- Melee enemies now choose which attack they intend **before** approaching, then walk to that attack's own strike distance and commit there. Previously an enemy fired whichever branch its current gap happened to satisfy, and only re-decided when its move action ended -- a Blade covers 110 units inside one, so it committed anywhere across a 70-unit band. The same attack was forgiving, harsh, or unavoidable depending on where that landed.
- Measured across 100 seeded approaches per enemy, the commit gap spread falls from `47.5-78.2` units to `0.2-8.0`, centred on each attack's authored distance.
- Attack selection is probabilistic so the next move cannot be read from geometry, but weighted by how well each option suits the current gap: an enemy leans long when long is warranted and short when short is warranted. A Knight met at range favours its thrust; one whose space is already taken favours its cleave.
- Polearm's shaft cut and Knight's heavy cleave now actually occur on approach. Branch ordering tested the shorter attack first while an approaching enemy crossed the longer threshold first, so both were previously unreachable unless the player walked into them -- `0/100` before, `28%` and `34%` of commitments after.
- An enemy abandons its plan if the player closes well inside it, rather than backing away to honour a stale intent.
- Enemy melee attack timing, geometry and strike distances move into `combat_catalog.gd` as authored plans, so enemy profiles own approach and attack selection rather than those emerging from branch ordering.

### v0.2.11: Trustworthy input and post-hit agency

- Combo continuation now follows live input. Continuation is sampled at each authored link point rather than granted at commitment, so a sustained hold commits as many strikes as its live window covers and a tap commits exactly one. Previously every sequence began authorised regardless of input, and a quick tap on an enemy — which resolves after the finger is already up — committed the entire combo.
- Taking a direct hit now starts a short non-refreshing protection window covering the hit reaction and `0.35` world seconds past return of control. Further hits still deal full health and posture damage and can still kill, but cannot replace the response the player chose. This guarantees agency, not safety: the protection does not extend when the hits it protects against land, so standing in a crowd cannot make the player progressively harder to interrupt.
- Combat Survey report format 11 records interruptions prevented and damage taken under post-hit protection separately, so the price of the guarantee stays visible.
- Adds `run-tests.ps1`. Test files call `quit(0)` unconditionally, so a failed assertion inside a test function still exits `0`, while a failed assertion directly inside `_init()` aborts before that `quit` and hangs the process instead of reporting. The runner scans output for assertion failures and applies a per-file timeout, and is the only reliable pass/fail signal.

### v0.2.10: Shared attack commitment

- Gives Sword and Knife sequences weapon-authored link points: holding or renewing Attack before the link flows directly into the next wind-up and skips the remaining terminal recovery.
- Locks a sequence into its visible terminal recovery when no continuation is present at the link; touching Attack after recovery begins cannot reopen the combo.
- Applies the same weapon timing to Recovery and Stamina rules while preserving their actual A/B distinction: ability cooldowns versus Stamina, regeneration, and exhaustion.
- Removes the separate Stamina-only basic-attack readiness timer and its reset meter. Sweeping Cut retains its shared 4.2-world-second anti-spam cooldown.
- Combat Survey report format 10 replaces attack-readiness telemetry with terminal-combo recovery count and exposure time.

### v0.2.9: Display-safe HUD

- Uses Android's reported safe display area for the board, combat HUD, action controls, setup screen, sheets, survey overlays, and full map so camera cutouts and system insets cannot cover health or interactive controls.
- Keeps the background edge-to-edge while deriving the active gameplay aspect ratio from the unobscured region.

### v0.2.8: Melee pressure correction

- Reduced the Warrior's ordinary movement speed from 300 to 260 so walking no longer provides a universal disengage from most melee enemies.
- Restored Sweeping Cut's 4.2-world-second Weapon Art cooldown under Stamina rules while preserving its 34-Stamina cost and broad crowd-control identity.
- Made Bandits, Knives, and Hounds pursue separated interception lanes ahead of player movement, with earlier crowd separation to reduce enemy bunching.
- Left Dodge profiles unchanged so the next survey can measure whether stronger melee pressure makes defensive commitment necessary.

### v0.2.7: Stamina commitment experiment

- Stamina rules now reward completing the Sword sequence: its three contacts escalate in health and posture damage while retaining the existing per-phase Stamina costs.
- A short attack-only readiness floor prevents opening-strike spam after a melee sequence without immobilizing movement, Defense, abilities, or items. Recovery rules retain their prior attack cadence unchanged.
- Stamina mode gains a compact direct Attack control, with `F` as its desktop counterpart. Enemy taps still attack, terrain taps and immediate drags still move, and the control visibly reports attack readiness and exhaustion.
- Stamina Dodge now has an intentionally modest baseline with strictly improving Practised Footwork, Sidestep, and Long Roll profiles. Recovery mode retains its existing Dodge timings and cooldowns for A/B comparison.
- Combat Survey report format 9 records attack-readiness pressure, deliberate Attack-control use, Dodge-form use, and exposure during vulnerable Dodge recovery.

### v0.2.6: Authored attack footprints and combat cadence

- Slash collision now resolves one deterministic annular-sector footprint at impact instead of tracing the displayed weapon segment; thrusts remain narrow capsules. The same ground geometry drives top-down and isometric play.
- Player strikes deliver a fast contact pulse followed by a readable non-damaging recovery, while enemy attacks retain their authored recovery and commit their facing when the wind-up begins.
- Stamina waits one world-second after the last stamina-spending commitment before regenerating rapidly at 60 per world-second. Exhaustion retains its two-second physical-action lockout.
- Pursuers intercept movement more deliberately, fast enemies can contest ordinary retreat, bandits receive real neutral time, and groups of archers spread and stagger their shots.
- Combat Survey report format 8 removes the low-value Fairness rating, records regeneration cadence, and reports authoritative footprint contacts, targets, occlusion, and true misses.

### v0.2.5: Recovery versus Stamina combat laboratory

- Combat Survey now independently selects Encounter/Attrition carryover and Recovery/Stamina combat rules.
- Recovery rules preserve the prior long commitments and cooldowns without spending Stamina.
- Stamina rules shorten only the player action recovery tails, charge physical attacks and Dodge, and replace forced immobility with a clearly displayed two-world-second exhaustion lock.
- Exhaustion advances through movement, Wait, or nonphysical actions while enemies remain active; overdraw is still allowed from any positive Stamina.
- Survey format 7 records the combat rule set, exhaustion exposure, damage received during exhaustion, and how the lock was advanced.

### v0.2.4: Combat diagnostics and resource clarity

- Combat Survey reports now preserve every melee strike's result and closest active-motion approach, including local forward/lateral enemy position and exact world-space weapon endpoints.
- Health and Stamina are the prominent red/green combat-resource group; Posture and XP are visually separated secondary bars.
- Rally, Stealth, and Take Aim recover Stamina while their nonphysical commitments advance time.
- Winded recovery can take damage but is no longer interrupted and restarted by every hit.
- Bandit and Knife attacks retain fast startup but have a readable neutral recovery window.

### v0.2.3: Stamina combat

- Adds 100-point universal Stamina, per-strike combo costs, draw-scaled Bow costs, movement/Wait regeneration, and forced `WINDED` recovery after overexertion.
- Revises every Temperament choice so one package improves Health and the other improves Stamina, with save migration for existing choices.
- Adds Stamina HUD, character-sheet, save, presentation, and Combat Survey reporting support.

### v0.2.2: Contextual held-touch intent

- A stationary touch hold now begins a melee combo only when it started on a plausibly attackable enemy. Holding empty ground or a clearly implausible melee target becomes continuous movement instead of an attack into empty space.
- Continuous hold movement follows the finger's current world direction as it moves. Ranged characters still recognize distant enemies as valid attack targets, while empty-ground holds remain movement.

### v0.2.1: Stable locomotion presentation

- Removes the procedural body bob, squash, and forward offset from ordinary movement. The character now glides steadily with its rendered body and feet anchored to the authoritative moving position; committed attacks, Dodge, Vault, Advance, and other authored actions retain their distinct poses.

### v0.2.0: Isometric-first presentation foundation

- Makes isometric the authored presentation baseline while preserving top-down as a mechanically identical diagnostic and accessibility view. Both views still use the same world-space positions, collision, targeting, attack geometry, timing, enemy logic, and seeded encounter generation.
- Adds reusable procedural poses for committed attacks, movement, evasions, bows, guarding, reactions, and stagger. Actor feet remain locked to their authoritative world-space position while body lean, stride, lift, and facing communicate the action above that contact point.
- Grounds every current weapon form in its real sampled world-space geometry. Startup, contact, and recovery now share one projected weapon pose; active weapons sit near the floor contact plane, project a restrained contact shadow, and retain optional exact geometry only in hitbox-debug mode.
- Gives arrows and firebolts visible ground shadows and elevation tethers, strengthens projected wall and gate bases, and locally fades tall terrain that obscures the player or a relevant nearby combatant.
- Extends Combat Survey report format 4 with presentation version, view usage, mid-room view switches, empty melee contacts, and an `UNCLEAR CONTACT` feedback tag so isometric readability can be compared against top-down without changing encounter composition.
- Deliberately leaves room geometry, enemy composition, combat balance, attack reach, and final character or biome art unchanged. Those remain separate experiments after this projection and pose foundation is validated.

### v0.1.9: Composition and pacing director

- Replaces the Combat Survey's largely random threat-budget assembly with authored tactical recipes built around pursuit, melee pressure, screened ranged support, crossfire, area denial, and heavy anchors.
- Sequences rooms through a repeating opening, development, contrast, pressure, climax, and respite rhythm while suppressing recently used recipes and recipe families.
- Assigns frontline, flanker, ranged-pressure, area-denial, and anchor placement roles without consulting the chosen character. Every loadout receives identical seeded rooms, and every room begins with enemies idle, facing away, and outside immediate detection distance.
- Caps simultaneous ranged-pressure roles at two and records pacing phase, recipe identity, family, composition cost, ranged pressure, and individual enemy roles in report format 3.
- Preserves the existing Survey arena shapes and formation coordinates so the new composition data remains comparable before the planned geometry laboratory.

### v0.1.8: Combat role integrity

- Separates Bow release identities: loose arrows are weaker emergency shots without ordinary hit reaction, while Full Draw carries higher damage, posture pressure, and stopping power. Take Aim now requires an interruptible preparation commitment, and Keen Eye correctly senses enemies hidden behind discovered obstructions.
- Makes Knife and Acrobat play more deliberately with a clearer isometric contact footprint, a less spammable four-cut sequence, an Execution step-in that preserves its committed unaware target until contact, and brief Vault disruption against light enemies.
- Strengthens enemy roles without changing Survey compositions or arena geometry: heavy attacks resist light interruption, Polearms and Captains gain close-range cuts, Ice Caster startup is slower, suspicious enemies actively search, and Survey openings provide a consistent stealth buffer.
- Holding `WAIT` now advances consecutive half-second intervals until release, preserving frozen-time control while making deliberate observation easier.

### v0.1.7: Survey-informed combat correction

- Tightens ordinary Sword, Knife, Twin Knife, and common-enemy melee geometry while preserving multi-target contact for every body actually crossed; broad coverage remains an authored strength of heavy attacks and Weapon Arts.
- Makes immediate drag claim movement before a stationary hold can become an attack, prevents combo hit reactions from refreshing into stunlock, and restricts pounces to trajectories that can physically reach the player.
- Improves ranged/support roles with rear-biased Survey placement, Archer firing-lane checks and repositioning, more readable Ice Caster startup, and lane-leading movement for heavy interceptors.
- Expands Combat Survey reports with entry/exit health and potions, action usage, death source, and a `Skip — Not Enough Information` response that preserves objective telemetry. Both Survey profiles can now spend earned XP; Encounter still refreshes resources between rooms.

### v0.1.6: Reliable Android report export

Combat Survey exports now publish completed text files through Android's Downloads collection and show an explicit success or failure result inside the archive panel. Failed direct exports copy the complete combined report to the clipboard and explain the failure instead of silently disappearing behind the overlay.

### v0.1.5: Attrition leveling fix

Combat Survey's Attrition profile now permits character-sheet level-ups whenever the player is idle and has enough accumulated XP. Upgrade eligibility, purchase validation, XP spending, and the sheet's Attrition Survey label use the same progression context; the per-encounter reset profile intentionally remains non-leveling.

### v0.1.4: Safer survey ending and sword finisher

- `END RUN` now opens a confirmation prompt explaining that the current room will still be rated before the report is archived.
- The sword sequence's third hit is now a delayed, long-reaching turning slash instead of a prolonged forward thrust.

### v0.1.3: Combat Survey readability and mobile input

- Replaces the ambiguous `Expedition fit` score with the direct question `Want a room like this again?` while preserving older archived scores in reports.
- Enlarges survey labels, ratings, tags, notes, and touch targets to better use phone and Fold screen space.
- Gives selected ratings and tags an explicit high-contrast style instead of relying on the platform theme.
- Explicitly focuses the notes field and requests the Android virtual keyboard when it is touched.

### v0.1.2: Combat Survey laboratory

- Adds an endless deterministic Combat Survey mode with visible run and room seeds, independently reproducible room generation, six arena/formation families, bounded six-enemy encounters, and two resource profiles: per-room reset or continuing attrition.
- Prompts after every cleared or fatal room for five one-to-five ratings, multi-select diagnostic tags, and optional notes; manual `END RUN` uses the same final-room report flow.
- Records exact enemy composition, geometry, formation, threat tier, character build, combat time, damage, incoming hits, potion use, dodges, blocks, and Endures for every room.
- Autosaves the current session, archives the last 100 completed runs, and produces Word-friendly UTF-8 reports with a stable room-by-room structure.
- Adds report copy, Android share-sheet support, direct `Downloads/Waystone` text export, archive browsing, latest-report copy, and combined archive export.

### v0.1.1: Rogue combat and Stealth corrections

- Makes the overhead sequence display reflect the actual weapon combo: four Knife cuts, six Twin-Knife cuts, and three Sword cuts.
- Lets one uninterrupted six-cut sequence sustain hit reactions on light enemies, then imposes a one-second personal-time attack recovery that still permits movement, defense, and skills. A new sequence cannot prolong the previous sequence's reaction.
- Rebuilds Twin Fang as a short lunge whose two crossing blades contact simultaneously for two independent 8-damage hits, rather than a weaker sequential combo.
- Gives Bow draw a prominent gold circular meter and a white-gold pulse at Full Draw.
- Makes Stealth eligibility explicit: Alerted enemies disable and grey the skill as `NOTICED` until Vanish is learned; Vanish demotes only those Alerted enemies to searching. Hostile commitments and incoming contact break concealment, while non-hostile actions do not.
- Adds survivor-based ally alerts, Clean Work's delayed broadcast, and distance/cone/line-of-sight witness checks for Ghost, while preserving v0.1.0 run saves through save version 23.

### v0.1.0: shared combat framework and the Rogue class

- Rebuilds player and enemy combat on the same universal attribute language: Health, Strength, Defense, Speed, Stealth, Awareness, Resolve, Resistance, Intelligence, and Faith. Physical damage is fixed, health and damage use a more expressive five-times scale, and conditions now have resistance-based buildup.
- Adds the Rogue with two complete subclasses. Acrobat uses Knife, Finesse, Stealth, and Vault; Sharpshooter uses a continuously drawn Bow, Patient temperament, Stealth, Take Aim, Far Sight, and approximate Keen Eye sensing beyond line of sight.
- Adds Knife and Bow weapon tracks with permanent first-rank art choices, four-cut and six-cut Knife sequences, continuous Bow draw strength, finite soft lock, short-release penalties, and manual post-lock aiming.
- Classifies touch intent before committing it: an immediate drag always moves, a brief enemy tap attacks, and holding deliberately commits a melee sequence or Bow draw. PC Bow draw uses the dedicated attack key and releases on key-up.
- Expands the character sheet and setup screen for Warrior · Vanguard, Rogue · Acrobat, and Rogue · Sharpshooter while preserving bounded, predictable track progression.

### v0.0.71: finite enemy posture openings

- Follow-up attacks against a staggered enemy continue dealing full health damage but cannot restart its posture break or extend the original stagger timer.
- Suppresses additional posture damage until the original stagger ends and restores posture, preventing fast attacks and combos from holding an enemy helpless indefinitely.
- Adds a repeated-hit regression proving that stagger duration and elapsed time remain unchanged through subsequent posture-heavy strikes.

### v0.0.70: local combat streaming and usable posture breaks

- Separates persistent region state from active combat simulation: offscreen enemies remain exactly where they were but no longer consume 120 Hz simulation merely because an adjacent region is loaded.
- Refreshes the active combat neighbourhood at the same stable 50-unit cadence as visibility as the player travels.
- Reduces the reported Fold save from seventeen simulated enemies to the five actually near the player.
- Guarantees that an enemy posture break remains for at least 0.72 seconds after the player's current commitment finishes, accounting for both player and enemy Speed.
- Extends the existing break-duration upgrade from that guaranteed usable opening.

### v0.0.69: reliable Rally and uninterrupted recovery

- Treats an active Rally as unavailable and greys its HUD button without starting the cooldown until Rally actually fades.
- Prevents repeated enemy hits from restarting or extending an existing player hit reaction or stagger, while preserving their health and posture damage.
- Guarantees a frozen-time decision after the original reaction ends, including when another enemy connects on the exact recovery tick.
- Precomputes and caches Expedition navigation windows when a run opens, removing the synchronous pathfinding-grid rebuild that caused a visible hitch at area boundaries.
- Adds focused regression coverage for the Rally lifecycle, stagger chains, and the cached Part 2-to-Part 3 transition.

### v0.0.68: crowd perception and simulation optimization

- Replaces repeated 12-unit line-of-sight ray marches with exact segment-versus-wall intersection over the existing wall spatial index.
- Samples enemy perception at a staggered 20 Hz while preserving movement, attacks, collision, hit contact, cooldowns, and posture at the authoritative 120 Hz simulation rate.
- Caches immutable enemy tempo and posture-recovery values and skips writes for expired cooldowns and already-full posture bars.
- Removes string allocation from repeated nearby-wall de-duplication and adds dedicated crowd rendering and exact sight-boundary benchmarks.
- Reduces the ten-enemy streamed simulation benchmark from roughly 7 ms to roughly 2.5 ms per displayed frame on the development machine, with larger savings as crowds grow.

### v0.0.67: regression repair and compact-sheet legibility

- Restores streamed forest terrain and boundary rendering while preserving the matching collision and navigation data.
- Keeps the Old Forest Road secret local to its region so adding it cannot reroll later terrain or encounters for an existing seed.
- Places the close-range secret discovery point on reachable ground, while Awareness can still reveal it earlier.
- Corrects bandit concealment stability, Practised Footwork's cooldown, active posture recovery, Vanguard's first level gate, and migration notices.
- Fits track labels, upgrade details, equipment copy, and choice descriptions to their character-sheet boxes instead of clipping them.

### v0.0.66: universal actor attributes and authored Warrior progression

Speed now advances each actor's personal action and cooldown clock by 3% per point from the baseline of 5, while released projectiles, hazards, Rally duration, and other world-time effects remain independent. Player damage is fixed rather than rolled, and Resolve now contributes to a persistent posture meter: damage can break posture and interrupt a commitment, while hyperarmor remains an authored property of appropriate actions instead of passive damage reduction.

The Warrior · Vanguard sheet has been rebuilt as five deliberately distinct tracks. Swordsmanship grants a permanent Sword Art, combo correction, fixed edge damage, authored Art reach, and faster flow. Evasion first improves Dodge, then chooses Sidestep or Long Roll and culminates in a clean-dodge reward. Steadfast may be trained four times through visible Toughness or Vigilance packages. Warrior develops physical conditioning, escalating consecutive-hit force, Rally, Battle Rhythm, and Warpath. Vanguard develops a damaging Advance, continuous momentum into the sword sequence, Resolve-backed melee poise, and an Advance refresh on posture break.

Awareness now has physical world consequences. Alerted bandits remain concealed until the player identifies them at a distance determined by Awareness versus Stealth, and must remain revealed briefly before attacking. Old Forest Road also contains a deterministic concealed woodland passage: Awareness 7 reveals it from farther away, while any character can discover it up close, and the pocket contains an extra rejuvenation potion. Version 20 progression is refunded as XP on migration so old runs can enter the revised tracks without silently receiving mismatched nodes.

### v0.0.65: clearer context control and smoother mage progression

The context-sensitive Wait button now sits above the consumable belt in both orientations and has a taller, easier touch target. Hounds use a cool blue-gray presentation color so they cannot be confused with gold-clad bandits. Friendly Forest Part 4 now fields seven spellcasters instead of eleven, preserving its ice-and-fire caster identity without the previous population-driven difficulty spike.

### v0.0.64: finite restorative supply

Expedition and Campaign characters now begin with a finite capacity of five rejuvenation potions. Expedition no longer uses the temporary unlimited testing rule.

### v0.0.63: first durable character sheet

The old Wayfarer prototype progression has been replaced by the first authored character: a Warrior with the Vanguard subclass and Steadfast temperament. Its compact sheet contains six stable positions in two rows—Swordsmanship, Evasion, Steadfast, Warrior, Vanguard, and the locked late-run Adopted Discipline. Each track exposes only its next stage, uses predictable minimum-level gates, and records branch decisions permanently for the run. The first level offers four choices; later availability remains bounded while skipped tracks stay available.

Swordsmanship now begins with a permanent Sweeping Cut or Drawing Cut choice and develops damage, posture, art identity, and combo flow. Evasion improves the deliberately modest basic Dodge into Sidestep or Long Roll and later rewards physically clean evasions. Steadfast repeatedly chooses between explicit `+3 health / +1 Resolve` and `+1 Speed / +1 Awareness / +3.5% movement / +35 sight`. Warrior adds Rally, whose modest damage and posture boost plus action poise never prevents health loss; its cooldown starts only when the effect ends. Vanguard adds an authored forward impact, then branches into Breakthrough or Pursuit and can later flow into the full sword combo by maintaining the original input.

The action HUD now has five stable ability positions: Dodge, Sword Art, Rally, Advance, and the locked Adopted Discipline. Wait, Take, Rest, Unlock, and Traverse share a separate compact context button instead of occupying an ability slot. Old prototype saves are intentionally rejected because their progression cannot map honestly onto this sheet; geography and mode rules otherwise remain unchanged.

### v0.0.62: visible hitstun and broken commitments

Interrupting a foe now preserves the weapon pose and impact direction that caused it. A regular interrupt shows a contact burst, knocked-aside weapon, directional recoil, motion trail, and a readable `REELING` state; posture breaks use a stronger displacement and a separate stance-shatter burst. Hounds visibly skid out of interrupted pounces, while boar momentum armour still produces only a strain response and carries the charge through. These are presentation-only offsets, so collision, targeting, and the frozen-time decision model remain unchanged.

### v0.0.61: responsive contact and differentiated pounces

Every player melee form now damages every enemy physically crossed by its world-space weapon geometry, while each target can still be hit only once per individual combo strike. Ordinary clean hits produce authored, archetype-specific reactions instead of allowing an uncommitted foe to begin an unavoidable counter during the player's recovery. This creates a defensive decision when time freezes without protecting whiffs, continued combos, attacks from a second enemy, already-active trades, or grounded heavy attacks. Hounds now pounce more quickly but can be interrupted throughout the leap; boars telegraph longer and accelerate more slowly, gaining momentum armour only during the committed portion of the charge. Strong posture attacks can still stop that armoured charge.

An original Android-first committed-action roguelike prototype inspired by the low-friction, high-mastery design philosophy of classic mobile roguelikes.

## Current controls

- Tap or quick-swipe: take a short, roughly 0.1-second movement pulse.
- Swipe and hold: continue moving in that direction; release to freeze time.
- Tap an enemy within plausible opening-strike distance: commit to one compact basic strike. A clearly distant melee target instead becomes a movement touch; ranged weapons keep their long-distance attack input.
- Tap an empty reachable position: move precisely toward it.
- Choose Warrior · Vanguard, Rogue · Acrobat, or Rogue · Sharpshooter at setup. Press an enemy to begin the equipped weapon's attack; an immediate drag remains movement even when it begins over an enemy, while holding deliberately commits a melee sequence or draws the Bow. Knife sequences contain four cuts, or six with Twin Knives. Bow damage, speed, recovery, and range depend on draw time; release fires in the current aim direction.
- Tap Dodge and choose a direction to use the equipped defensive action.
- Swordsmanship's first rank offers Sweeping Cut or Drawing Cut. The chosen Sword Art is permanent for the run and the unchosen art is not later unlocked.
- Tap Sheet (or press `C`) to inspect universal attributes, equipment by body slot, combat identity, and six compact progression tracks arranged as three columns by two rows. During leveling, tap an eligible gold track to inspect and confirm its next stage.
- Hold an enemy while time is frozen for qualitative action, speed, reach, stability, and role information.

### v0.0.60: obstruction-aware enemy locomotion

Enemy movement state now comes from real world-space displacement rather than an intended movement action. Actors face the direction they physically travel, steer around nearby bodies with deterministic separation, refresh stale navigation at a bounded rate, and abandon an obstructed commitment when repeated recovery attempts cannot make progress. A blocked enemy therefore no longer flashes `MOVING` while standing still or spends an entire action pressing into the same wall or actor.

### v0.0.49: exploratory woodland pass

Expedition routes now use comparably wide, naturally colored woodland corridors instead of a visibly privileged main lane. Continuations remain something to discover: on reaching a far edge, two understated forest boundary stones make the pass legible without exposing it on the map or from across the locale. The Wayfarer begins with 20 health, and sword cuts recover more quickly while retaining their committed three-strike structure.

### v0.0.50: supplies are physical choices

Visible supplies now use a high-contrast cache marker and a short-range `SUPPLY` label in the world, while remaining absent from unexplored map space and off-route placement rules. Replacing a full belt slot drops the entire displaced stack at the player's feet rather than deleting it.

### v0.0.51: persistent supply discoveries

After a supply has entered explored territory, it remains visibly marked whenever it is on camera. Movement out of the current awareness radius no longer makes an uncollected item blink or disappear.

### v0.0.52: supplies above foliage

Supplies now render above trees, walls, and other isometric world solids. Their marker is an interaction affordance rather than scenery, so camera movement and depth ordering cannot hide an already discovered item.

### v0.0.53: streamed supply persistence

Movement now carries the complete pickup list through the optimized presentation frame path. A discovered supply stays visible while time advances, instead of appearing only during frozen-time snapshots.

### v0.0.59: stronger health ranks

Each Health rank in Vigilant now grants `+3` maximum health and immediately restores those same 3 points, rather than granting only one.

### v0.0.58: exact upgrade effects

Upgrade confirmations now state the precise mechanical contribution of the next rank: for example maximum weapon damage `+1 (3 → 4)`, maximum health `+1`, movement speed `+3.5%`, dodge travel speed `+24 units/sec`, potion healing `+1 HP`, or posture-break time `+0.08 seconds`. Dynamic effects include the current-to-next value where that is meaningful. Features whose prototype mechanics are not active yet are identified honestly instead of implying a nonexistent benefit.

### v0.0.57: deliberate upgrade choices

Eligible upgrade rows now open a confirmation panel rather than spending XP immediately. Each panel explains the property, previews its next rank, shows the cost and remaining XP, and offers Confirm or Cancel. Weapon Skill has a dedicated chooser: the Weaponry row remains readable, then opens a two-option dialog describing Sweeping Cut and Drawing Cut before Learn is enabled. Locked and ordinary non-purchasable properties continue to use the informational detail panel.

### v0.0.56: grouped level-up sheet

Leveling once again preserves the character sheet's full progression structure. Weaponry, Evasion, Vigilant, Fieldcraft, and Openings remain visible as distinct track panels in two rows of three, with track rank and gated future properties retained for context. Eligible upgrades are moderately enlarged gold rows inside their own tracks; inactive rows compress to make room without disappearing. The initial Sweeping Cut and Drawing Cut choice remains inside Weaponry. Level-up mode temporarily hides belt repacking, dims competing world controls, and uses the same hierarchy across phone and wide layouts.

### v0.0.55: touch intent and level-up focus

Melee enemy touches now distinguish an intended opening strike from a movement touch that happened to land on a distant target. The check is deliberately an input-intent heuristic: it uses only the opening attack's nominal reach, target size, a generous anticipation allowance, and a nearby visible foe in the same touch direction. It does not predict enemy actions or guarantee a hit, so judging range and timing a pre-emptive attack remain part of play. Player ranged weapons preserve direct long-distance targeting. The level-up version of the character sheet is now a focused three-column grid of large, whole-card upgrades; it temporarily hides belt repacking and the dense full-track table so each choice is legible and comfortably tappable on a phone.

### v0.0.54: Expedition macro-structure

The seven-part Friendly Forest now runs through an explicit route graph and reusable locale contract. Every locale publishes local branches, reconnections, optional reward pockets, encounter sockets, respite space, and a discovered continuation threshold; enemy groups and physical supplies bind to those geographic roles instead of arbitrary encounter-array positions. The run moves through seven named pacing phases from orientation to climax, with a brief non-modal arrival card and distinct physical boundary treatments, while the route and its exit remain undisclosed until explored. Runtime region streaming follows graph adjacency, so future expeditions can introduce forks and mixed biomes without replacing the current traversal or persistence systems.
- Tap ISO or TOP while time is frozen to switch presentation without changing simulation state.
- Tap Potion to heal, Wait to surrender 0.5 seconds, or Reset to restart.
- Tap after death or press `R`: restart the expedition.
- On desktop, hold a mouse click over an enemy to continue an attack chain, or hold `F` to attack from the current movement direction (or current facing when still). Release after any strike to stop the chain after that recovery.
- Hold `WASD` or the arrow keys for continuous movement. Opposing axes combine, so two simultaneous direction keys move diagonally.

The first expedition uses continuous positions, world-space weapon hitboxes, physical projectiles, persistent hazards, and a 120 Hz fixed-step simulation. Time is frozen whenever the player is ready. Locomotion is granular and interruptible, while strikes and skills commit through startup, active, and recovery phases.

Committed actions now advance through a rolling fixed-step executor instead of simulating and copying their entire future timeline before presentation. This removes the repeated playback boundary from held movement and prevents long strikes from blocking the display under crowd load. Player movement, action clocks, attack contact, charges, projectiles, hazards, and defensive timing remain authoritative at 120 Hz; ordinary enemy locomotion advances at 60 Hz and is interpolated visually. Active enemy membership, Captain auras, spatial buckets, and player-directed navigation fields are cached, while crowd decisions are deterministically distributed across four simulation ticks. v0.0.26 reuses streamed presentation frames instead of allocating nested actor dictionaries every tick, caps real-time catch-up without skipping simulation steps, shares collision-query context across both movement axes, replaces discovery ray marching with cached grid visibility while retaining exact combat line-of-sight, and caches projected floor geometry plus camera-adjacent static render candidates. Debug builds report action CPU time, presentation capture cost, visibility cost, draw submission time, worst recent frame time, and active-versus-resident enemy counts.

v0.0.27 removed the remaining exploration and autosave hitch patterns. Newly discovered floor cells append to the projected geometry cache instead of rebuilding all remembered terrain; explicit discovery epochs still force a correct rebuild after death, regeneration, layer changes, and viewport changes. Ordinary autosaves are deferred until input has remained quiet, while critical lifecycle and Waystone saves remain immediate. Save payloads retain dynamic actors, shortcuts, discovery, XP, Shadow and anchor history, cooldowns, statistics, and RNG state, but omit immutable geography that loading deterministically reconstructs from the mode and seed.

v0.0.28 replaces the repeated clearing-and-side-loop motif with a semantic Friendly Forest grammar. Sunlit Verge uses open glades; Brookwood uses crossings and bank paths; Old Forest Road has a readable spine and overgrown detours; Elder Grove uses radial spokes; Rootbound Woods uses braided routes; Forest Ruins interlocks courts with vegetation; and Heartwood Approach opens into a broad boss perimeter. Every area publishes named traversal and encounter zones, generous mandatory-route widths, landmark traces, and deterministic validation metrics. Brooks, old roads, meadow traces, stone circles, roots, ruins, and the heart tree now have distinct prototype rendering and discovered-map marks.

v0.0.29 temporarily gives Expedition unlimited restorative potions so full seven-part traversal can be tested without attrition ending the run early. Potions still consume action time and cannot be used at full health. Campaign Lab retains its normal finite potion supply.

v0.0.30 gives the first three Friendly Forest regions readable traversal identities instead of undifferentiated green fields. Sunlit Verge opens into a bright meadow bounded by dense growth, Brookwood follows broad banks and crosses its brook at authored fords, and Old Forest Road centers an unmistakable worn route with overgrown side detours. Main routes, side paths, clearings, water, roads, and forest boundaries now use distinct surface or landmark treatments in both views and on the discovered map. The early roster is also deliberate: Sunlit Verge contains only slow boars with a committed pounce; Brookwood mixes those boars with faster hounds that pounce and then evade while recovering; Old Forest Road introduces agile knife bandits alongside hounds. Bandits can dodge defensively or convert a forward dodge directly into a quick knife strike.

v0.0.31 moves Brookwood's brook and the Old Forest Road out of the solid-object pass and into clipped ground materials. Water, banks, shallow fords, road beds, and shoulders now remain on discovered playable terrain beneath actors, trees, walls, weapons, and effects in both projections. Stopped time also eases into a subtle blue world tint and flowing time eases back to the natural palette; HUD and map readability remain unaffected.

v0.0.32 strengthens the temporal presentation: stopped time has a clearer saturated-blue cast, while longer easing into and out of the frozen palette makes each change of temporal state visibly readable even around short movement pulses.

v0.0.33 completes the back half of the Friendly Forest Expedition. Elder Grove introduces separate Ice and Fire Casters: ice forms a delayed ground circle or pushes an expanding close-range cone, while fire erupts around the caster or launches a gently tracking firebolt. Rootbound Woods uses coordinated Bandit and Archer groups, with faster but still evadable arrows. Forest Ruins fields slow, high-health Two-Handed Knights with exceptional posture, a wide greatsword cleave, and a long thrust, backed by archers. Heartwood Approach places two knights among archers and both caster schools before a Werewolf boss arena. The Werewolf pounces, chains pounces into rapid left-right claws, uses a standing claw combination, and evades during pounce recovery; two hounds accompany it. Ice circles and cones fill from world-space shapes in both top-down and isometric views.

v0.0.34 establishes the shared combat foundation without committing to a final player character sheet. Every actor now has the same universal attribute vocabulary (health, speed, stealth, awareness, resolve, intelligence, and faith), hidden combat properties, a weapon frame, and an ability identity. The eight player-facing weapon frames—Sword, Hand Axe, Zweihander, Spear, Twin Knives, Bow, Impact Weapon, and Staff—each define a basic action and two divergent future Weapon Arts. Natural and unarmed frames use the same structure for creatures and future edge cases. Existing enemies retain their current behavior while being mapped to these frames, and save version 14 preserves the new profile data while safely hydrating earlier saves.

v0.0.39 replaces the temporary three-class roster with the Wayfarer and makes the character foundation playable. The responsive character sheet presents universal attributes, eight body/equipment slots, the equipped Sword and Dodge, known Arts, and five small ranked tracks: Weaponry, Evasion, Vigilant, Fieldcraft, and Openings. Track properties have CQ-style repeated ranks and commitment gates, use XP through the existing mode-specific upgrade flow, and modify the shared combat, perception, potion, posture, and cooldown systems. Save version 15 preserves tracks, equipment, and learned/equipped Arts while migrating earlier saves safely.

v0.0.40 replaces the overloaded `×1`/`×3` attack control with hold-to-commit chains. Pressing an enemy starts the opener immediately; the held input is sampled only at each recovery transition, so holding commits the next strike and releasing at any point finishes the current strike before frozen time returns. One, two, and three-strike sequences arise from the same simple input rather than timing a special selection. The action-bar Attack button is removed. Desktop has a dedicated hold-`F` forward attack using held movement direction or current facing, while mouse input follows the same press-and-hold rule.

The seeded Friendly Forest Expedition is now a forward-directed sequence of seven CQ2-scale progression parts with no Waystone or return shortcut. Each part is a large organic region containing several clearings, broad winding paths, a side loop, multiple encounter groups, its own escalation profile, and progressively denser forest identity. The current all-Forest route is represented as a seven-slot locale recipe so later expeditions can substitute Bridge, Town, Castle, Dungeon, and other locale profiles at any global progression position without changing the difficulty contract. The seventh part places its Werewolf, two companion hounds, and map marker from one authoritative boss definition.

The active world seed is shown on the map and can be copied, while the pre-run screen accepts an optional seed for repeatable expeditions. Organic floor capsules and irregular clearings are authoritative for movement and pathfinding; forest dressing preserves wide safety envelopes around every mandatory route. The runtime now streams active regions: Expedition keeps the current progression part and its immediate neighbors resident, while Campaign keeps the current region plus nearby and directly connected same-layer regions. Static terrain, walls, navigation, simulation, enemy queries, rendering, and action snapshots operate on that active set; the full lightweight world definition remains available for saves and the discovered map. Autosaves are debounced during ordinary play and flushed immediately for Waystones, transitions, shortcuts, upgrades, run starts, restarts, and application suspension. The translucent map remains non-modal: movement, combat, and HUD controls remain usable behind it, with only its Close button capturing input.

The prototype now runs under two explicit rule sets and traversal graphs. Expedition preserves its permadeath, forward-directed seven-part route and exit-earned upgrades. Campaign Lab now has three Waystone intervals, a longer outward forest route, a compact local far-side return to Moss, a spatially faithful descent into overlapping Ruin Depths, a Warden vault, an old lift that emerges at the same total coordinates in a hidden surface grove, and a second far-side shortcut back to Dawn. Combat remains 2D: actors, projectiles, hazards, shadows, collision, navigation, and map discovery carry a discrete layer identity.

The Campaign route first reaches the Moss Waystone, takes the long Elder Trail, and then opens a small hidden-woods return to Moss before continuing to the Root Waystone and Sunken Ruin. The ruin descends into independently remembered buried halls and emerges into a forgotten grove near Dawn, where the larger return shortcut opens from its far side. Surface and underground areas may occupy identical world coordinates without sharing collision, visibility, navigation, or map memory. The map draws the actual discovered organic footprint, semantic landmark traces, and each layer independently.

Campaign shortcuts are binding topology rather than markers placed over open floor. Friendly Forest shortcuts now appear as compact blocked paths through dense trees, remain absent from the map and unlabeled from the near side, and expose a clear-path interaction only after the far side is reached. The Moss path remains reachable by the longer outward route while blocked and becomes a materially shorter return when cleared; Forgotten Grove remains disconnected from Dawn on the surface until its path is cleared. Normal play renders only camera-adjacent content from active regions, while the map retains full discovered-area presentation. The full map can page through any number of discovered discrete layers; layer controls never appear on the translucent gameplay overlay. Action playback uses lightweight snapshots that omit the growing discovered-world and static-layout payload. Actors use compact circular models with separate facing wedges over subtler exact collision footprints, so apparent contact remains honest in both projections and the player stays distinct on every biome palette.

Campaign Lab now makes provisional life explicit: integrated and at-risk XP occupy separate portions of the XP bar, the Shadow is marked and gently guides nearby recovery, and death accounts for retained XP, recoverable XP, forgotten map memory, and unanchored shortcuts. The Waystone activates only when deliberately tapped in range; that single action restores resources, revives enemies, and integrates XP, map memory, and shortcuts before optionally offering Learn or Continue.

Enemies award XP. In Expedition, once enough XP is held and time is idle, Sheet becomes a highlighted Level Up entry: any currently eligible track property or Weapon Art can be bought directly there. Campaign Lab leaves only experience earned since the last Waystone activation at a recoverable Shadow; dying again replaces the old Shadow. Integrated XP can be safely spent through the same character-sheet level-up mode, but only while standing at a Waystone.

The Wayfarer currently combines Dodge with the Sword's compact basic strike and committed three-form sequence. Enemy weapons retain distinct reusable techniques: quick cuts, thrusts, bites, forward smashes, and heavy cleaves. The same world-space pose drives collision and both visual projections. Fast enemies have deliberately low posture and can be interrupted, while grounded Brute and Warden attacks resist interruption after becoming active. Physical contact is deterministic, action information is qualitative, and cooldowns use visual progress rather than decimal timing.

Obstacle-aware route planning guides continuous enemy movement around organic floor boundaries, trees, ruins, and shortcut gates. The same close camera follows the player in isometric and top-down projections, including inverse-projected taps, swipes, attacks, hazards, and directional skills. Impacts use foreground bursts, floating damage, and player damage framing, while a persistent health bar remains at the top of the playfield. A small Reset control remains available during actions and after death.

Isometric is now the default presentation. Actor collision bodies render as projected ground footprints beneath compact circular models, and weapon capsules, impact shapes, hazards, and walls are derived from the same world-space geometry used by simulation. Isometric walls and actors share a depth-sorted render queue, foreground walls fade when they would conceal the player, the isometric camera has independent zoom and framing, and taps select the visible actor model when bodies overlap. Top-down remains available from the view toggle and uses the same projection-independent drawing primitives. Frozen-time frames no longer redraw continuously when nothing changes, while active playback interpolates between authoritative 120 Hz simulation snapshots and uses display synchronization for smooth frame pacing across common PC refresh rates. Press `H` on a development keyboard to show exact actor collision outlines.

Windows is a supported prototype target alongside Android. Desktop play uses continuous, combinable screen-relative `WASD`/arrow movement and held left-click steering, `1`/`P` for potion, `2`/`B` for defense, `3`/`Q` for skill, `4`/`Space` for wait or context actions, `M` for map, `V` for view, `R` for reset, right-click inspection, and `F11` or `Alt+Enter` for fullscreen. Upgrade and Waystone menus accept number keys. The expandable canvas switches between phone, foldable-landscape, resizable desktop, and fullscreen layouts without changing simulation rules.

## Run locally

Run `run-prototype.ps1`, or open `project.godot` with Godot 4.x and run the project. The launcher and Android build scripts discover the ignored project-local tool directories and can reuse the existing local Waystone Android toolchain.

Run `build-android.ps1` to produce `builds/android/waystone-debug.apk`. The configured project-local toolchain targets arm64 Android devices, including the 2023 Pixel Fold.

Run `build-windows.ps1` to produce the self-contained x64 build at `builds/windows/Waystone.exe`, or `run-windows.ps1` to build it when missing and launch it. `build-all.ps1` exports both platforms for tandem milestone checks. The Windows build script extracts only the required x64 files from the existing ignored Godot export-template archive.

Run `run-tests.ps1` for the headless suite, optionally naming individual tests (`run-tests.ps1 combo_continuation_test`) or passing `-All`. Test files call `quit(0)` unconditionally, so a failed assertion still exits `0`; the runner scans each run's output for assertion failures and script errors and is the only reliable pass/fail signal. Render-dependent smoke tests are excluded by default because they capture real frames and cannot pass headless — run those against a real renderer.
