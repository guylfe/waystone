# Waystone Prototype

Current prototype version: `0.2.45` (Android version code `245`).

### v0.2.45: Speed stops buying everything

Eight changes from one Acrobat run, most of them the Rogue paying for advantages it was never charged for.

**Concealment could be entered in front of something already swinging at you.** `_enemy_has_eyes_on_player` was an instantaneous cone-and-line-of-sight test, and an Archer sees 620 less 14 per point of stealth — **522 units against a Rogue** — so one could put an arrow into you from beyond that and still fail the test *while the shot was in the air*. Room 3 measured the cost precisely: **12 stealth entries, 4.58s hidden, 265 stamina paid.** Twenty-two stamina per entry for 0.38 seconds of concealment.

A committed hostile action now counts as eyes on you regardless of cone or range, as does having seen you within the last half-second of world time. If something is mid-swing or mid-shot at you, it knows where you are.

**A spotter now rouses its neighbours** — to suspicion, not alert. They turn toward where you were seen and search, which keeps concealment playable instead of ending the fight the instant one body glances the right way.

**Execution was the only player attack in the file that made no sound at all.** Every other one emits, from the knife sequence's 260 to the sweep's 470; Execution emitted nothing. So a room could be cleared one body at a time with nobody ever reacting — room 4 ran six executions, **four of four kills made alone, zero damage taken, 0.04 mean engagement.** It now emits on impact rather than on commitment, which matters because the wind-up is 1.16s and waking the victim inside its own execution defeats the point. **Its cost is also doubled, 30 → 60 raw**, spending 39 where it spent 19.5.

**The knife no longer interrupts with its opening cuts.** *"Knowing my attack is faster than everyone else and staggers them immediately made melee combat trivial."* Weight earns the right to cut a committed attack down; speed does not. Phases 1 and 2 no longer apply a hit reaction — posture still accumulates, so a full sequence still adds to a break, and the later phases and Execution keep their teeth. The sword is untouched.

**The Ox runs its line through its own side.** Its stated trait is that it runs until it hits something, and the one thing it reliably failed to run through was its allies. Restricted to `unstoppable` — the Ox alone today, because if every charger ploughed through, formations would dissolve on contact and the arrangement would stop meaning anything. No slowdown on the pass, and credit goes to the player who chose the ground. Measured: **355 units travelled through an ally that took 7 on the way past.**

**The bow leaves a record.** A Sharpshooter run produced `Strike diagnostics: 0` in every room, because the strike log is built from a melee sector and a projectile has none — the class we could see least was the one carrying an open "might be too strong" against it. Rooms now report **shots fired, hit, and blocked by a guard**.

**Formations bias toward coverage.** One reporting run gave column four rooms, cluster and crossfire and retinue one each, and screen_line none. Selection now prefers the least-used formation so far in the run, within the set the roster's bands can host — so one run covers the library instead of four rooms of one arrangement.

`docs/survey-archive-findings.md` records a caveat that has already misled this analysis twice: **rooms are rated in isolation, and a journey has pacing.** Two respite rooms scored 2/2/2 and were read as composition failures. *"Not every room has to be engaging if it isn't meant to."* Respite scores are uninterpretable until the same room is rated inside a sequence.

### v0.2.44: Concealment that conceals, and a screen that screens

Three defects, reported in one sentence: *"if I go into stealth when enemies are already looking for me but can't see me they can still see me... they don't follow me or run after me but they do strike me when they get into distance."* All three had one cause.

**Pursuit read the player's true position.** `sees_player` correctly refuses to *acquire* a hidden player — it requires `stealth_remaining <= 0.0`. But `_pursuit_target` and `_choose_enemy_action` both open with `var target := player_pos`, with no reference to stealth or `last_known_player`. So for the three seconds of `alert_remaining`, an alerted enemy tracked a hidden player **exactly**. That is "they can still see me". When the alert lapsed they dropped to suspicious and walked to a stale position — "they don't follow me" — while anything still inside its alert window struck on contact. Both halves of the sentence, one bug.

**While the player is hidden, every awake enemy now behaves as merely suspicious**: it goes to the last place it knew of and searches there. `last_known_player` is already frozen while hidden, because nothing refreshes it without sight.

**The vanish was itself visible.** The veil landed at `effect_start = 0.24` into a 0.40s action, so a quarter-second of world time was spent fully exposed — and an enemy that acquired you inside that window then tracked you through the hide. The entry gate says you may only start hiding when unseen, so the action must not be the thing that gets you seen. It lands on commit now; the 0.40s is still spent.

| trial, suspicious enemy at 300 units | `0.2.43` | `0.2.44` |
|---|---|---|
| hidden for | 0.80s | **5.00s** |
| ended by | `broken` | **`expired`** |
| damage taken while hidden | 7 | **0** |

**And being hunted is not the same as being seen.** `player_is_noticed()` returned true for *any* living alerted enemy on the layer — no facing, no distance, no line of sight — so one enemy that had lost you across the room locked the ability out for the rest of the fight. It now means what it says: an alerted enemy with the player inside its cone and a clear line, or close enough that facing stops mattering.

| alerted enemy | can you hide? |
|---|---|
| facing you at 300 | no |
| back turned at 300 | **yes** |
| far and turned away | **yes** |
| on top of you at 80 | no |

The vision range is one shared helper now, so the gate and the awareness update cannot drift apart — the mistake the Shield's guard list already made once.

**The screen now screens arrows.** *"Shield wasn't defended whatsoever from arrows"* — the frontal guard was melee-only, because `_damage_enemy_from_player_projectile` never consulted it. A screen that stops one damage type is not a screen, and it deleted the counter-play the role exists to sell. Blocking is judged on the shot's own travel rather than on where the player stands, so a projectile that has been redirected is answered on the line it actually arrives on. Going around it still works: an arrow from behind lands for full.

`stealth_last_end_reason` records how each hide finished. `expired` is the only outcome the player paid full price for, and the `0.2.43` survey's *3 entries, 0.02s hidden, 60 stamina paid* would have said so on its face.

### v0.2.43: The floor is a disc, and placement did not know it

*"An archer was out of bounds. Another placement bug."* Correct, and a different one — `0.2.42` fixed bodies standing **inside** geometry, and this is bodies standing **outside the world**. The room it happened in had no obstacles at all (`open_ring`), so nothing in the settling loop ever ran.

**The arithmetic was never going to fit.** An anchor is drawn 410–560 units from a player who already stands 380 from the centre, and a rear slot sits up to 330 further out again. The floor is a disc of radius **650**. Nothing anywhere clamped to it, so a body could be seated **975** from the middle — 325 units past the rim, which is where your Archer was.

It was in every arena, not just the empty one:

| | `0.2.42` | `0.2.43` |
|---|---|---|
| off the floor | **78** of 1151 (6.8%) | **0** |
| furthest from centre | **975** | **570** |
| inside a wall | 0 | 0 |
| clipping a wall | 0 | 0 |
| inside contact range | 0 | 0 |

570 is exactly the radius less the margin, which is the clamp doing its job rather than a coincidence.

**The clamp runs inside the convergence loop**, not after it — a body pulled back onto the floor can land on a slab, and that has to be resolved rather than shipped. That is precisely the mistake `0.2.42` was about, one rule further out, and putting the new rule outside the loop would have rebuilt it.

**Anchors are scored on the floor as well as on the walls.** Clamping is a backstop; scoring is what keeps it rare, because a formation whose seats all need dragging inward arrives squashed against the rim instead of arranged. `_formation_blocked_seats` becomes `_formation_misplaced_seats` and counts both failures.

The arena's dimensions are now three named constants used by the layout, the settling and the anchor scoring alike, rather than a `650.0` literal in the floor shape that no other code had ever read.

### v0.2.42: Bodies inside walls — the `0.2.41` regression

The `0.2.41` survey ended after two rooms, both scored 1/1/1 and tagged `empty`: *"one of them got stuck in a wall unable to find me and I was not able to hit it so I had to end the run."* The strike log shows it exactly — a Boar at `(681.6, 688.6)`, inside `Rect2(680, 430, 95, 305)`, logging `move@0.01` at one position forever, every swing at it reading `overlap=true occluded=true TRUE MISS`. In range, and unreachable through the slab.

**Two fixups that undid each other.** Clearing a body off an obstacle was a single pass over the obstacle list, so in `split_approach` — two 95×305 slabs standing 150 units apart — a body shoved clear of the left one landed against the right, and the loop had already passed the left, so nothing looked again. Then the 360-unit minimum distance from the player ran *afterwards* and could shove a cleared body straight back into the slab it had just been moved out of, with no re-check at all.

**Both defects predate formations.** What `0.2.41` changed is how often they fire: authored offsets have no idea where the walls are, while the six hand-picked slots they replaced had been chosen to dodge them. I replaced a set of coordinates that was implicitly wall-aware with a system that was not, and did not notice because nothing asserted it.

The two rules now run **to convergence** in one place, and if they have no fixed point the body is swept out to the nearest clear standing room rather than left inside geometry it can neither be hit through nor path out of. **Anchors are also chosen with the arena in view** — a formation is scored by how many of its seats would land in geometry before it is placed, which stops a whole group being dropped onto a slab and then torn apart body by body.

Measured over 1151 spawns across 275 generated rooms:

| | `0.2.41` | `0.2.42` |
|---|---|---|
| inside a wall | **7** (all `split_approach`) | **0** |
| clipping a wall | 24 (2.1%) | **0** |
| inside contact range | 0 | 0 |
| ranged bodies unscreened | 1.2% | **0.0%** |

Screening improved as a side effect: anchors that avoid geometry also stop a slab standing in for the screen.

**A test was defined and never called.** `test_a_room_never_asks_one_attack_three_times` — the attack-technique cap from `0.2.41` — was written into the file but never added to `_init`, so it had never run once. That is the trap `CLAUDE.md` records about this suite in a new costume: a test that cannot fail is not a test. It is registered now, alongside a regression test asserting no body spawns inside, clipping, or too close to the player.

### v0.2.41: Formations — placement becomes an authored thing

A "formation" used to be six fixed coordinates, with every enemy independently picking its favourite by role score:

```gdscript
"ranged_support": return [Vector2(700, 610), Vector2(1000, 610), Vector2(570, 340), ...]
```

`ranged_support` *promised* an archer supported by melee. What it was, was a hexagon — nothing put a body between the archer and the player. A name describing an intention the code never implemented, which is the same defect as a role label with no behaviour under it.

**A formation is now an arrangement.** Slots are authored in formation-local `(lateral, depth)` where depth counts *away from the player*, and the whole shape is rotated to face the player's entry point. A slot at depth 220 sits 220 units behind the front rank whichever way the player is standing, so **screening is a fact of the geometry** rather than a score a placement function has to be lucky enough to satisfy. Across 330 generated rooms, ranged bodies with nothing in front of them fell to **1.2%**.

**Seven formations, and the number is a constraint rather than a preference.** At ~11 rooms a run, seven reach a readable sample within a few runs; twenty never would, and the entire point of authoring formations is to find out which ones work. A test fails if the library reaches nine.

| | what it tests |
|---|---|
| **Screen Line** | melee abreast, ranged directly behind |
| **Crossfire** | two shooters wide, melee central — closing on one turns your back on the other |
| **Column** | depth on one bearing; the back ranks arrive while you are committed to the front |
| **Pincer** | melee split wide, open centre — the lane is bait and it ends at a caster |
| **Cluster** | everything tight: the control condition, roughly what the old placement did |
| **Picket** | one body forward of everything else — is a lone body a trigger or a speed bump? |
| **Retinue** | the elite as the centre of the room rather than a member of it |

**Bands, not roles, decide where a body stands.** Naming roles on slots conflates who an enemy is with where it belongs, and the Polearm is the proof: it is melee, but `reach` holds at **200** against the frontline's **88**, so a Polearm spawned in the van walks *backwards* the moment the player closes and takes the formation apart with it. A body has to be spawned where its own standing behaviour will keep it. `van` / `wing` / `mid` / `rear` / `elite`, derived from role — and `rear` never falls forward past `mid`, because a caster ending up in front is the failure this replaced. `support` and `movement_denial` had no placement case at all before, so the Chanter was spawned at frontline distance with 40 HP; it was the first thing engaged in its only appearance and died three seconds in.

**Elites are derived from mass, not listed.** `HEAVY_TELEGRAPH_MASS` already selects Warden, Brute, Knight and Ox while excluding Shield, Boar and Polearm, so mass keeps one meaning throughout and there is no second roster to drift. Retinue seats escorts **wide and deeper** rather than ringing the elite: a full ring would put the Ox's own retinue in its charge lane, the worst possible arrangement for the enemy the formation exists to showcase — and placing them behind makes the question interesting rather than procedural. Commit to the big body and they close at your back; clear them first and you eat the elite the whole time.

**Two elite rooms in three centre the elite, and the last third is a control on purpose.** If every elite room were a Retinue there would be no way to tell whether the arrangement is good or whether rooms containing an Ox are good. That is precisely the confound that left *"melee-only rooms are irredeemable"* unfalsifiable across thirty runs, because every melee-only room in the archive happened to be built from the five oldest kinds.

**Formation is now chosen from the roster's own bands rather than listed per recipe**, and all 19 recipe `formations` lists are gone. Decoupling them is what makes the experiment work: `0.2.40` rooms 1 and 2 held the **same four enemies** in different placements and rated **2/2/2 against 3/4/3 in both rule profiles** — the cleanest signal the archive has produced, and it happened by luck. This manufactures those matched pairs deliberately.

**A second group has to earn its place.** Two groups placed independently are two sequential fights, which the archive rates below one good one — `0.2.40` room 6 ran 0.22 engaged with 3 of 3 kills made alone and scored 2/2/2. A second group is legal only if reaching the first puts the player inside its threat: within pursuit range, or with a clear shot. One group stays the default at 53% of rooms, two at 43%, three only under a stress band.

**Roles were not enough to stop repetition.** The `0.2.40` Stamina run landed seven boar pounces and nine hound pounces in one room — sixteen of twenty-eight attacks, *"too many enemies doing the same thing, busy and monotonous"* — and the `0.2.39` role cap waved them through, because Boar is `frontline` and Hound is `flanker`. **Primary attack technique is now capped at two per room** alongside kind and role. The verb is what the player actually reads.

**New telemetry: `Time to reach ranged`.** Seconds from room start until the player first landed a hit on each rear body. *"An archer that spawns next to me is just a blob I have to hit before fighting the rest of the room"* is a claim about time, and it was unmeasurable until now. Formation ids are reported per room so the archive can compare arrangements the way it compared non-melee counts.

**What the matched-seed A/B found**, since it prompted the change. Seed `1787785767017` run under both rule profiles: fun 3.00 against 2.80, tactical interest 2.40 against **2.80**, want-again 2.20 against **2.60**, damage received 86 against **231**. Stamina did *not* reduce attacking — 31 combos against 27 — it made the same play far more expensive, and the run ended at room 6 rather than room 11. It also made the worst room worse: room 3 fell to 2/1/2 as engagement rose from 1.13 to 2.39 and combat time from 15s to 36s. **Stamina does not create composition problems; it extends exposure to them.** The pair is only cleanly controlled for rooms 1 and 2, where the profiles were indistinguishable at 10 damage each, so the resource-model question stays open.

### v0.2.40: One price, two rule sets

Every ability had two numbers — a stamina cost and a cooldown — kept in sync by hand, and three abilities had only one of them. Now there is one authored number and the other is derived.

```
cooldown = (stamina actually spent / max stamina) x 24s
```

**The rate is not a guess.** The six hand-authored pairs that already existed implied 20–33 seconds per 100 stamina — Advance 33.0, Execution 28.2, piercing shot 26.3, bow art 24.0, Twin Fang 21.6, Drawing Cut 20.2, median 25. So the formula mostly *codifies* what was there and repairs the abilities that fell outside it. Most cooldowns move by under a second. Its best confirmation is elsewhere: a full stealth hide costs 50 stamina, which derives **12.0s — exactly the cooldown that shipped before the formula existed.**

**The pool is the denominator on purpose.** Under Recovery, stamina is never spent and never regenerated, so the `+10` max stamina from `vigilance`, `fleetness` and `observation` did *nothing at all* — three track choices with a dead half. Now a deeper pool shortens every cooldown. The accepted consequence, recorded rather than overlooked: max stamina buys **burst depth** under Stamina (more actions before empty, prices unchanged) and **sustain** under Recovery (shorter cooldowns, burst unchanged). The same stat reads differently in each profile.

**Three abilities were free in one profile and walled in the other.** Stealth, Vault and Take Aim were the only things in the file sitting on a cooldown with no `uses_stamina_rules()` waiver and no cost — together **116 stamina of ability use against a 100 pool, free, every room**. Nothing noticed for the whole life of the Rogue, because no test asserted that the two profiles cover the same abilities. One does now.

**Sweeping Cut stops being a special case.** Its exemption from `STAMINA_COST_SCALE` held its price at 56 while everything around it scaled — so a global re-tune of the price level would have moved every ability *except* this one. That, not the number, was the defect. The authored cost carries the surcharge instead (56 → 86 raw, still spending ~56), and its cooldown derives at **13.4s, up from a hand-authored 4.2.** The finisher without the combo's time is a special attack, not a cheaper route to the same place.

**Stealth is charged by the second, not by the use.** 10/s while hidden, with regeneration suspended — a 10/s drain against 28/s of regeneration is a slower profit, not a price, and concealment has to compete with dodging for the same pool or the drain means nothing. Exhaustion drops the veil. There is no Stamina-mode cooldown, matching every other ability.

- **It is cancellable, and the button says so** — "END STEALTH" rather than greyed out. A drain you cannot stop is a fixed cost with extra steps: you would pay the full 50 whether or not you needed five seconds. Cancelling is free and instant, because it stops a cost rather than performing an action.
- **A 20-stamina floor**, charged however the hide ends. Entering stealth fires a one-shot at rogue rank 4 that turns nearby alerted enemies `suspicious`, and `execution_target_was_unaware` accepts anything not `alerted` — so the benefit is instantaneous while a proportional price is not. Without a floor, a quarter-second tap would buy the unaware-execution bonus for a rounding error and tapping would strictly beat hiding.
- **Consequence worth naming:** breaking stealth to attack is a hide cut short, so it now pays the floor rather than the full price — 4.8s of cooldown where it used to be 12.0. That is the intended reward for striking quickly, and **stealth telemetry now reports entries, cancellations, re-entries within 3 seconds, time hidden and stamina paid**, so the next survey can answer whether hide-execute-hide has eaten the class with a number instead of a feeling.

**The Shield's guard drifted between two lists.** The simulation stopped it blocking in six states; the renderer drew the guard down in four. `hit_reaction` and `stagger` were added to the sim in `0.2.38` and never mirrored, so a staggered Shield drew its guard back up while still resolving as open — you hit a raised shield, which the `0.2.38` survey reported. The list is exported and the renderer reads it.

The readiness bar was drawn against hardcoded maxima, which derived cooldowns break outright — Sweeping Cut's 13.4s against an assumed 6.5 would draw full from the first frame. Each cooldown records what it started at.

**What the Rogue survey found, since it prompted all of this.** The first Acrobat run ever recorded, closing a long-owed item. The two melee-experiment rooms averaged **3.5 fun / 3.5 want** against **3.0 / 2.8** for the five rooms carrying ranged pressure — the reverse of the archive rule, which was measured entirely on Warriors. And engagement telemetry split the run without predicting it: the worst room ran 0.22 engaged and 3 of 3 kills alone, but so did the *second-best*, which was rated 4 fun / 5 tactical. Isolation you engineer is the reward; isolation the room hands you is the defect.

One correction to the survey's own note: Execution was never free. It charges 30 raw, 19.5 scaled, and room 2's five executions and four short sequences reconcile to the reported 165.1 exactly.

### v0.2.39: Sameness, not crowding — and the melee experiment reports

**G1's experiment has an answer, and it overturns the premise.** Melee-only rooms built from the *differentiated* roster now have three clean data points against 26 from the five oldest kinds in the same era:

| melee-only rooms | mean fun | want again |
|---|---|---|
| differentiated roster — Shield, Duellist, Ox, Polearm | **2.67** | **2.33** |
| the five oldest kinds — Boar, Hound, Knife, Bandit, Blade | **1.54** | **1.31** |
| difference | **+1.13** | **+1.03** |

So *"melee-only rooms are irredeemable"* was wrong. **Those five enemies were the problem**, and the archive could never separate the two because it had never once composed a melee room from anything else. That reframes what comes next: the answer may be reworking or retiring the oldest kinds rather than guaranteeing an archer in every room.

**And the engagement telemetry earned its keep immediately.** Two rooms in the `0.2.38` survey had near-identical engagement and opposite verdicts:

- Archer + Hound + Knife + Bandit — **2.33 engaged at once, 72% of combat with two or more** → *"felt busy… very difficult to find an opening, but it didn't feel challenging — just tedious"*, rated 2 and tagged **crowded, too hard**.
- Shield + Duellist + Boar + Knife — **2.30 engaged, 73%** → rated 3, no complaint.

**Crowding was never the variable. Sameness was.** The first room fielded a Hound, a Knife and a Bandit: three different kinds, all `flanker`, all answered the same way — one problem asked three times, which is precisely what §4.6 exists to forbid.

- Same-*kind* was already capped at two. **Same-role now is too.** Verified across 390 generated rooms: maximum two enemies per role, zero exceptions, and population untouched at mean 4.22.

**On the `-1` damage popups.** I could not reproduce one and will not claim otherwise: player damage measures 8–10 against every enemy in the roster, the Vanguard Advance deals 10–15, and incoming damage floors at `MIN_FELT_DAMAGE`. What I *did* find is the adjacent defect — `_resolve_player_physical_values` still floored at `maxi(1, ...)`, the exact thing `0.2.32` replaced on the receiving side and never fixed on the dealing side. Nothing in the current roster reaches that floor, but armour or a damage-reducing effect could, so it is now floored the same way. If a `-1` appears again it is on a path I have not found, and the next step is instrumenting rather than guessing.

### v0.2.38: Measure the thing, stop guessing at it

The `0.2.37` survey said the same thing in four separate notes — *"archer was too far from other enemies and was a non-factor"*, *"archers were non-factors at any point. I easily picked enemies off one by one"*, *"enemies being in different sides of the room in isolation makes them easy to beat"*, *"same problem. enemies in different corners... I did not need to fight mobs a single time so far."*

Rooms 4 and 5 rated **1/1/1** despite carrying four and five enemies with two ranged each. Under G1's rule those should have been the good rooms.

**Two explanations were tested against the 297-room archive. Both were confounds.**

- *Split formations disperse the fight.* Across 51 rooms `split` averages **2.06** — above `frontline`'s 1.91. Arenas are flat at 1.88–2.06. The three-room read that suggested otherwise was noise.
- *Spawn spread is the mechanism.* Mean pairwise slot distance correlates with fun at **r = −0.86** across 167 rooms, which looks decisive until it is controlled: **within pure-melee rooms the tight-versus-wide gap is +0.03**, and within ranged rooms `split` (2.65) ties `ranged_support` (2.61) despite being 25% wider. Formation was proxying for composition, exactly as role-diversity did in G1.

So rather than ship a third guess, **the report now measures it**:

- **Enemies engaged at once** — mean count of alive, alerted enemies within 320 units, sampled per simulation tick so it is weighted by world time rather than wall clock. Plus the share of combat spent with two or more.
- **Kills made alone** — when an enemy falls, how many other alerted enemies were near it. Zero witnesses is what *"picked them off one by one"* looks like in data.

Survey format bumped to 17.

**And one thing that was provable.** All three melee experiments were permanently stuck at their base size: expensive bodies (Ox 5, Duellist 4, Brute 4) consumed the entire budget, so the reinforcement loop never ran once. Goring Reach shipped as a **two-enemy room** at cost 8 against a budget of 8, and the tester flagged it in two consecutive surveys — *"ox was fun! if he wasn't alone with only 1 other enemy"*. A room that small cannot answer the question the experiment exists to ask, which is how differentiated melee enemies interact **with each other**.

A population floor now applies regardless of budget: four bodies, three in respite. Measured across 390 rooms: **mean 4.26 enemies, none below 3, and every melee experiment fields at least 4** (mean exactly 4.00).

### v0.2.37: Presence is not pressure

`0.2.35` guaranteed every room a non-melee enemy and the rooms still rated 2. The tester named why: *"when enemies are very dispersed the ranged enemy doesn't really affect the fight."* One melee escort leaves an Archer trivially reachable, and the room becomes a chase rather than a problem.

**The cause was the reinforcement budget, and it had been quietly dead.**

```
target_budget = min(18, 2 + tier + (2 stress / 1 unusual / 0 conventional))
```

At tier 1 conventional that is **3** — and First Arrows already cost 3, Hunted cost 4. Every room in that survey was at or over budget before the fill loop was even considered, so **it never ran once**. The formula was sized for the old deck, whose base recipes were cheap (Boar + Hound = 2) and left reinforcements to do the work; the G1 recipes are front-loaded instead.

- Budget raised to `4 + tier + band`. Measured across 390 generated rooms: **mean enemies per room 3.0 → 4.03**, with rooms 1–3 rising from about 2.3 to 3.71.
- **Capped at five rather than six.** The archive rates six-enemy rooms at **2.29** mean fun — its worst band — against 2.76 at four and 2.71 at five. Thin evidence (n=7), but it is the only evidence and it points one way, and a lower cap also leaves the crowding push less to do.
- Result: **73% of rooms now sit in the measured 4–5 band**, none above it.

Both changes are one lever each, deliberately: base recipe costs were left alone so the next survey can attribute what it sees.

**Watch for a difficulty spike.** This adds roughly one enemy per room across the board. The two things that killed the last run — the Archer's wind-up and the Shield blocking while reeling — were fixed in `0.2.36`, so there is headroom, but this is the change most likely to have overshot.

### v0.2.36: A reeling guard is not a guard

The `0.2.35` survey ran five rooms and tagged two of them **unfair**. Both notes named the same two causes, and neither is about composition.

**The Shield blocked while it was flinching.** `_enemy_blocks_attack` excluded its own attack states but not `hit_reaction` or `stagger` — so you hit it, it reeled, and it blocked your follow-up with a guard it could not possibly be holding. The strike log makes it unarguable: **six blocks landed at `hit_reaction@0.40` through `@1.79`** across the two rooms tagged unfair. `0.2.34`'s lengthening of its attack made this worse by moving more of its life into states that were not on the list. Reeling now counts.

**The Archer was overcorrected.** `0.2.30` was right that ~2.7s between shots is weather rather than pressure, but `0.2.33` went to a 0.46s wind-up — which lands inside a 0.983s strike lockout *every* time, so the only answer was to stop attacking. Now 0.60s wind-up and a 0.86s cooldown, between the two.

**The opening room was thinner than anything ever measured.** *"When enemies are very dispersed the ranged enemy doesn't really affect the fight."* First Arrows fielded two enemies, and the archive contains **no two-enemy rooms at all** — its best band is 4–5 enemies with 2–3 melee alongside the pressure. A lone escort leaves the Archer trivially reachable, so the room becomes a chase. Third body added, and its formations tightened.

**On the G1 result itself: the first melee experiment is confounded.** Warded Duel drew Shield + Duellist + Boar and rated 2/5 for fun — but two of the six bad Shield blocks happened inside it, so the room was measuring the bug rather than the hypothesis. What survived is the tester's own note, which is the encouraging half: *"when the melee enemies are genuinely different from each other it is fun."* The experiment needs a clean run before it says anything.

### v0.2.35: Composition by evidence — Milestone G1

The generator now composes rooms from what 297 rated rooms actually say, and the survey runner stopped hiding failures.

**The rule, and it is not a preference.** Across 200 recent rooms the count of non-melee enemies maps to mean fun of **1.61 / 2.48 / 3.20** for 0 / 1 / 2 of them. The effect holds inside every version era and is *largest* in the most recent (+1.40 at `0.2.27+`), so it is not an artifact of pooling old data. All ten of the best rooms ever recorded contain a non-melee enemy; 87% of the worst are pure melee. Full analysis in `docs/survey-archive-findings.md`.

- **Every room now carries non-melee pressure**, enforced in the selector rather than trusted to the deck, so a recipe added later cannot quietly reintroduce the rooms that measured 1.5.
- **The four recipes that measured 1.5 are retired** — Opening Pursuit, Mixed Skirmish, Melee Cross, Melee Press. Patched rather than retired would have meant bolting an archer onto each and losing the ability to test melee-only rooms at all.
- **Two designs the evidence killed**, recorded so they are not re-proposed: a demand/punish **conflict taxonomy** (193 of 200 rooms scored zero — the metric barely varies) and **role-diversity scoring** (role count and non-melee count are nearly the same variable, because eight melee bodies share two roles while every other role is a singleton).

**Melee experiments, on rooms 3, 7 and 11.** Deterministic, not random — a designed experiment that only *might* appear is how the Chanter and Ox spent a whole version unplayed. Every melee-only room in the archive was built from the five oldest kinds, and **the Shield and Duellist have never once appeared in one**, so "melee-only rooms are irredeemable" and "those five enemies are undifferentiated" are still indistinguishable. Warded Duel, Goring Reach and Heavy Press field Shield, Duellist, Ox, Polearm and Brute to settle it.

**Reachability is now a test.** Every recipe and all 17 enemy kinds can be drawn in a 13-room run. Two recipes previously could not: `dual_elements` and `knight_command`. The trap is structural — climax falls on rooms 5 and 11, and 11 is always an experiment, so any climax-only recipe above tier 3 is unreachable by construction.

**The Hexer is retired.** Under the elemental framework its delayed danger zone is a delivery mechanism rather than an element, and Fire and Ice both already use it.

**The runner was lying.** `run-tests.ps1` counted only `Assertion failed|SCRIPT ERROR` and discarded the exit code, so every test file using the `failures`-array convention reported PASS regardless of outcome. Fixing it revealed failures in **five** files. Four were tests preserving designs that had been deliberately superseded:

- the Polearm's *"never back away from a spear"*, which `0.2.34` inverted on purpose;
- the Hound *"punishing commitment at any range"*, a direction E2 explicitly rejected — the source records the reasoning at the Hound's own charge gate;
- Sweeping Cut costing the *scaled* combo total, when it has been exempt from `STAMINA_COST_SCALE` since `0.2.18`;
- Polearm commitment tests driven by an idle player, when it now decides on lateness.

**And three real bugs the newly-visible tests caught:**

- **A reach enemy could deadlock.** `_melee_intent` could roll the shaft-cut intent while the Polearm stood at range — and the reach role refuses to approach inside its hold distance, so it could never satisfy that intent and simply walked forever. Measured stuck at 194.6 units with clear line of sight, holding an intent that required 116. Its attack is now chosen by distance, not by a weighted roll it cannot honour.
- **The reach role held at 210 while its own thrust commits at 205 + 4.** A Polearm standing exactly at its assigned distance was one unit outside its own commit band. A role must be able to act from the distance it is told to hold.
- **A charging body could be shoved aside.** The `0.2.32` crowding push is mass-gated, and the Hound at 0.75 is the most shoveable thing in the game and the one that spends the most time charging. A committed charge is now solid whatever it weighs — which is what the Ox's `unstoppable` flag already said for one kind.

Test harness fixes worth noting: `survey_state()` now resets `_next_enemy_id` and rebuilds the wall spatial index. Clearing `walls` never rebuilt the index that line-of-sight actually queries, so tests silently kept whatever geometry the opening room drew — which is how changing the recipe deck broke unrelated tests.

### v0.2.34: Six fixes the `0.2.33` survey asked for

That run produced the first 5/5 fun ever recorded (room 9) and the first 5/5 on tactical interest and want-again (room 10). It also isolated the remaining problem precisely — see the note at the end.

**The Shield's opening was unreachable.** Tagged *unfair* twice. Its guard is down for the whole of its own attack, and that attack is its **only** opening — so `0.2.31`'s patience system, by cutting its swings from nine a room to three, shrank the *number* of openings without growing them. Fewer windows, same size.

- The cut runs **2.15s** instead of 1.65s (wind-up 0.62 → 0.74, active end 0.92 → 1.06). Sized against the player's measured 0.983s combo lockout: the Shield commits while you are busy, so the window has to still be open when you get control back. **Measured: 0.67s of reachable window before, 1.17s now.**
- Worth knowing and undocumented until now: its guard is a **72° frontal arc**, so attacking from outside it already ignores the block entirely. Flanking has always worked.

**A light body could act inside the swing that hit it.** A posture break already guarantees `player_remaining + 0.72s`; an ordinary flinch guaranteed nothing, so a Blade's flat 0.48s expired mid-combo and it hit back from frames the player could not answer from — *"he recuperated before I was able to finish the combo."*

- A flinch now lasts at least as long as the commitment that caused it. **This is not a bonus opening**: no time is added, so the enemy is free the instant the player is. Measured: 0.48s → 1.07s against a 1.10s remaining combo.
- Heavies are excluded. They answer with armour instead, and giving them this as well would make a committed heavy unpunishable.

**The Javelineer faced you and threw somewhere else.** The lead was computed at *release*, so it aimed through the whole wind-up at the player and then threw at where they were going — no telegraph, and a shot that could not be read. The line is now committed **at the announcement**, the thrower faces it, and it releases along it without re-aiming, which is the same promise every other attack in this game makes.

**The Polearm went 0 for 5.** Weighted selection kept picking the 205-unit thrust at 105 units (1.7 against reverse_cut's 1.0), and a thrust authored for 205 is trivially walked out of from half that distance. Inside the point it now takes the shaft cut, which needs no lateness gate because at that range there is nothing to be late for. The long thrust is still thrown only at a committed player.

**The Duellist's parry was invisible.** It always had a 3.1s cooldown; the Bandit got a ready-tell in `0.2.32` and this did not, so a mechanic that was already fair read as *"it parries whenever it likes."* It now shows a raised guard in front while the parry is available — distinct from the Bandit's two side ticks. Its poke also became a sword rather than a spear: **reach 132 → 104**, its own `rapier_thrust` technique so it draws with a slim profile, and a shorter commit distance to match.

**The Earth Caster looked like the Polearm.** Literally: `POLEARM_COLOR` is `d08a48` and the Earth Caster was `a08055`. It is now a distinct green-earth, and it carries a **staff** like the other casters — the broken-ground glyph alone never said "caster" at a glance, and a role needs to share its role-mates' silhouette before it says anything of its own.

**Still outstanding from that run:** the Earth Caster's temporary **barrier** — a wall that cuts your retreat rather than taxing it. Not in this build, because walls are baked into a cached navigation grid and a barrier has to live outside it, which means enemies would path as if it were not there. That needs building carefully rather than quickly.

**And the finding that matters more than any of the above:** rooms 1, 2, 3 and 6 — every pure-melee room — scored **1.50 mean fun and 1.00 on want-again, unanimously**, against 3.50 and 3.50 for rooms carrying non-melee pressure. Those four are pre-existing recipes drawing on the pre-existing roster, and *nothing in E2, E3 or E4 moved them*. Melee-only rooms are no longer an enemy problem; they are a composition problem, which is Milestone G1.

### v0.2.33: Four enemies that ask four questions — Milestone E4

The `0.2.30` survey measured a 1.6-point fun gap between rooms carrying non-melee pressure (3.33/5) and melee-only rooms (1.71) — and the roster had exactly **one** `ranged_pressure` enemy. Every good room in that run was carrying the same Archer. This build widens the thing that was doing the work, and retires the enemy that was doing none.

**The Polearm becomes a spear.** Its thrust carried **229 units of forward travel against a 218-unit reach**, so every attack ended in melee and it fought like a slow Blade. That lunge was not a mistake: at a 0.90s wind-up against a 260/s walk the player clears 234 units, so without it the thrust could never land at all. Shortening the wind-up to 0.42 is what let the travel come down to 60.

- It now throws the spear at **lateness rather than range** — the same read the Shield got in `0.2.31`. A free player walks out of it and should; a player locked in a 0.98s combo cannot. Probed: **0 damage to a walking player, 13 to a committed one.**
- The filled tip dot is gone from thrusts. On a sword the weapon end sits near the body and it reads as impact; on a 218-unit spear it was a disc floating in open space.

**The Archer actually fires.** Its cycle was 1.62s of action plus a 1.05–1.49s cooldown — ~2.7s between shots, which is weather, not pressure. Now 1.24s and 0.70s, bringing the cycle under 2s.

**The Captain is gone; the Chanter replaces it.** Its identity was "strengthens nearby movement", which in practice was `×1.14` locomotion inside 720 units: invisible on the enemies it touched, imperceptible in size, and effectively always on for a whole room. Strip that and what remained was a fast enemy leading with a 142-reach thrust — which is why the `0.2.30` tester called it "the spear enemy" in a room containing no Polearm.

- **No attack of its own.** Reaching it ends the problem, which is what makes reaching it worth pricing.
- **A spellbook, one chant at a time**, chosen to suit the allies it actually has: `haste` (blue **ring**), `bulwark` (yellow **chevron**), `ward` (red **diamond**). Colour and shape both carry the meaning, so the colour is never load-bearing.
- Chants are **drawn on the allies carrying them**, not on the caster — what the player needs to read is which bodies in front of them have changed.
- **Bulwark is not a stat**: it lends telegraph armour, so a Blade holds its wind-up like a heavy for as long as it lasts. **Ward reduces damage but never grants immunity** — the answer is the caster, not surrender.
- **Every chant ends the moment the Chanter dies.** Collected from a living-caster sweep rather than a death hook, so no damage path can miss it.
- It hides: with no ally between it and the player it moves behind the nearest one, or away if it has none.

**The Javelineer denies a lane.** It is slower than the Archer and easy to sidestep — that is the design. While the javelin is in the air one direction is unavailable, so what it spends is your **choice of direction**, not your health. Alone it is nearly harmless; behind a frontliner who already dictates where you can stand, it collects. It throws where the player is **going**, which punishes the straight-line running that beats an Archer. Paired with the Archer, both answers are spent at once.

**The Earth Caster introduces a third currency.** Fire and ice deny ground by threatening damage; sundered ground deals **none at all** — crossing it costs *time*, and in frozen time spending time is handing every other enemy in the room a free move. It cuts the ground **between you and where you are going**, never under your feet. The slow is symmetrical: an Ox charging through broken earth is slowed by the same rule, so it is terrain the player can use.

**The Duellist takes your turn instead of your health.** Where the Bandit slips sideways and ripostes, this one plants and catches the blade — no damage to either side, and the player is staggered for 0.86s while the rest of the room acts. It reads the player's wind-up, faces the threat, and only parries from the front, so **getting behind it is the positional answer**. The stance is spent whether or not it catches anything, so a cheap feint really does draw it. Its two attacks put their openings in different places — the poke commits fast and is punished on its recovery, the swing announces itself and is punished before — so no single habit answers both.

**Also:** zero authored damage now means *no hit at all*. `MIN_FELT_DAMAGE` exists to stop armour reducing a real blow to nothing; without a guard it would have turned every damageless effect — sundered ground, the Ox's disengage — into a 5-point hit.

Four new rooms place them: **Chanted Line** (Chanter behind a Brute), **Closing Lanes** (Archer and Javelineer spending both answers while a Shield picks which one you are forced into), **Broken Ground** (sundered earth in front of a spear), and **Measured Guard** (a Duellist wanting your attention while a Javelineer wants you to move).

### v0.2.32: Mass means something, and every hit is felt

Four changes, all of them consequences of reading the `0.2.30` numbers rather than the design documents.

**The enemy you could not avoid did nothing.** Damage resolved as `authored × 5 − defense`, which at the survey's physical defense of 4 produced a cliff rather than a curve: three attacks landed for **1 health** and everything else for 6 or more. The three were `knife quick_cut`, `bandit quick_cut` and `bandit dodge_strike` — and the Knife landed 6 of 9 attempts, the best hit rate in the game. The enemies that hurt never connected; the one that always connected was free. That is rooms 9, 10 and 12 rating 1/5 for difficulty, explained in one table.

- `DAMAGE_HEALTH_COST` replaces the flat multiplier with an explicit curve. At defense 4 the felt values become **5 / 10 / 13 / 16 / 21 / 31** where they were 1 / 6 / 11 / 16 / 21 / 31.
- `MIN_FELT_DAMAGE` is 5. **Every connecting strike is felt**, and armour can never reduce an attack to nothing — the floor holds the whole roster above zero as defense grows through a run.

**A tight ring of five bodies left 14 of 24 movement directions completely dead.** That reads as the controls failing, not as pressure, and it got worse as bodies grew.

- The player now **shoves lighter bodies aside** instead of stopping against them, displaced exactly by the overlap — parting a crowd, not launching anyone. Displacement runs through `_move_actor`, so nothing is pushed through a wall; a body with nowhere to go stays put, which is the cornered case and should feel tight.
- The threshold is `mass < 1.35`, the same line that already decides whether a body reacts to being vaulted. **Mass now has one meaning throughout: 1.35 and up is a body you cannot move.** That leaves Shield, Brute, Knight and Ox as the only things in the game that can physically stop you — which is precisely their job, and it means a Knife can never body-block you again. Enemies still collide with each other, so formations keep their shape.

**The Bandit's "dodge-counter" never read anything.** It fired on a distance band and a 2s timer, closed 117 units with invulnerability on the way in, and stabbed for 1 health. It could not counter, because it never looked at the player — which is why it was never felt.

- It now answers **being swung at**: it triggers during the player's wind-up, before the swing resolves, so it is a read rather than a reaction to being hit.
- It **circle-steps** rather than retreats. A purely perpendicular slip carried it from 90 units out to 131 and the riposte fell short — an evasion that cannot convert is the same half-dead mechanic this replaced. With an inward weight it now converts from 60 through 120 units, for 13.
- The counter is **aimed once**, when the slip ends. A lunge deliberately does not steer, but a riposte swung down the line it dodged along would miss by the width of the dodge.
- **Its cooldown is the tell**, and the tell is drawn: a Bandit still holding its slip shows two guard ticks. An enemy that reads your commitment without a visible ready-state is unfair rather than difficult. Spend it and swinging at that Bandit is safe — that is the loop.

**The Polearm was a support unit with a Boar's body.** Radius 42 and 60 health while acting as a screen-and-poke enemy does not read; a body that size needs a boss's move set to earn it. Dropped to an ordinary humanoid frame (radius 28, health 34) so its **reach** is what makes it dangerous.

Its behaviour is untouched and still wrong — the thrust carries 229 units of forward travel, so it lunges into melee every time. That needs the commitment-read the Shield now has, and is not in this build.

### v0.2.31: Anchors anchor — Milestone E2

`0.2.30`'s coverage sampling did its job — eleven distinct recipes in thirteen rooms — and the honest instrument immediately produced a clean reading. Rooms carrying ranged or area pressure averaged **3.33/5 for fun and 3.17 for tactical interest**; melee-only rooms averaged **1.71 and 1.43**. A 1.6-point gap against a ~0.5 noise floor. The cost confound (melee-only rooms averaged cost 5.1 against 7.2) does not carry it: cost-7 and cost-8 melee rooms still rated 2/5, while a cost-6 room with two archers rated 4/5. More melee does not rescue a melee room, it makes a longer one.

Which means the melee enemy's job is to make reaching the ranged threat expensive — and that job was not being done.

**Ten heavy attacks across Ox, Brute and Polearm. Zero contacts.** Against six landed hits from nine Knife pokes. The heaviest bodies in the game were the safest things in it.

- **Telegraph armour now covers the wind-up.** The hold in `_break_posture` required `active_started`, so armour began only once the weapon was already moving and the telegraph — the entire reason a heavy enemy exists — was a free cancel window. The ordinary flinch path already refused light hits during startup; posture breaks did not, and a combo reaches a break readily. The bigger the body, the longer the opening it handed over.
- The gate is now **`mass >= 1.6`** rather than a hardcoded kind list. That selects Warden, Brute, Knight and **Ox** — which had been in neither armour list, and lost 4 of 4 gores.
- **A committed heavy is still answerable.** High-impact blows (≥ 3.5) interrupt startup as before, so the counter is a specific thing the player must bring rather than any swing at all. An attack with no opening can never be answered if it repeats.
- **The Ox reopens its own charge lane.** It could not charge from inside its own minimum range, and walking toward the player can never restore that gap — hence four gores and then an animal standing in strike range being hit. It now reverses under its own power. The disengage *is* a charge, so at mass 2.4 its wind-up inherits the same armour a gore has and cannot be stunlocked; it is capped at 190 units so it reopens a lane instead of becoming the Hound's unbounded 495-unit retreat. A cornered Ox still crashes into the wall behind it.

**The screen was a frontliner with a block flag.** Nine swings in one room, off a proximity gate — which is a trigger the player can pull at will by stepping in and out.

- **It strikes because the player is late, not because the player is near.** It commits only when your current action's remaining lockout exceeds its own wind-up. Movement and idle are not commitments; **Wait is**, so spending time is the honest way to draw it.
- **Patience degrades its judgement rather than merely releasing it.** Each Shield spawns with a per-instance budget (2.6–4.4s, drawn from the room seed, so a replayed seed replays exactly and two Shields differ). It drains only during a standoff. At full patience it takes only windows it can genuinely punish; as the standoff drags, the window it will accept shrinks toward zero, so it starts biting on footwork and finally on nothing at all. **Those misreads are the openings worth the most**, because a player who has not committed is free to answer the instant the guard drops. The patient player is rewarded rather than stalled, and an enemy that is always correct is annoying rather than difficult.
- **It stations itself relative to its ward, not to the player**, so it cannot be kited off what it is covering. Walking around it costs time — which is what the archer behind it is selling — rather than costing it its position.
- **The guard is no longer drawn through its own attack.** `_enemy_blocks_attack` already dropped the block for those action kinds; the sprite was contradicting the rule, which is part of why the swing read as unanswerable.
- **A ward must be something it can stand in front of.** `_ally_anchor` averaged every matching ally on the layer — on a generated floor a Shield picked a ward 11,754 units away and steered off the navigation grid. Bounded to 420 units. This also fixes frontline bearings outside the survey.

**The deck ran out.** Rooms 12 and 13 repeated because **no recipe above `min_tier` 3 was tagged `respite` or `opening`** — at tier 6 the generator's only legal "respite" was a tier-1 melee room it had already dealt. Coverage sampling cannot fix a deck with nothing left in it. Two additions, both deliberately small, and neither another melee crowd:

- **Warded Caster** (respite/contrast, tier 4+): Shield + Fire Caster — a screen against area denial.
- **Outrider Line** (opening/development, tier 5+): Ox + Archer — you must move to avoid the charge, and moving is what the archer punishes.

Deferred: **polearm reach**. The source already records why — the thrust carries 229 units of authored forward travel, so committing at 218 always ends in melee. Making reach real means reworking its capture curve, which is its own change.

### v0.2.30: The survey is an instrument, not a slice of the game

`0.2.29` fixed the survey deck using pacing logic — a repetition window, and a rule preferring a recipe that introduced a role the previous room lacked. That is variety-as-pacing, which is a property of the game. The Combat Survey's job is **coverage**: show the tester as many distinct room types as one run can hold. Repetition inside it is a sampling question, not a design flaw.

- **Recipe selection samples closer to without-replacement.** Anything not yet seen this run is drawn first; repeats begin only once the eligible pool is exhausted, and the window and family filters survive only as the tie-break for that case. With fourteen recipes and thirteen-room runs, a run should now show nearly the whole deck.
- The role-freshness rule is removed. It optimised against the previous room rather than for total coverage.
- **`docs/design-foundations.md` §4.6 is corrected.** It claimed *"a room's value decays on repetition"*, evidenced by Boar/Hound/Knife rating 3/5 on first appearance and 1/5 on its second and third in the `0.2.18` survey. That measurement is real but it measures the **instrument**: in a survey the tester is grading rooms, and a room whose problem is already solved is less interesting *to assess*. It says nothing about a player mid-run who is not filling in ratings. The observation and its numbers are kept; the design obligation drawn from them is not.
- The conflict rule in §4.6 is unaffected — it compares different room types *within a single run*, not a room against its own repeats.
- §4.6 now carries a standing caution that the survey's ordering, pacing, repetition and threat curve are harness artifacts, and that reading content rules out of its shape is a map-territory error.

The tier and phase changes from `0.2.29` stand: those widen what the instrument can *show*, which is exactly what a coverage instrument should do.

### v0.2.29: Ten melee rooms out of thirteen was the generator

The `0.2.28` survey rated 1.46 for fun with three rooms tagged unfair, and the largest cause was not combat at all: **ten of thirteen rooms were pure melee, and four recipes produced nine of them.**

- **The early deck could not do anything else.** Below tier 4 there was exactly one non-melee recipe, and tier is `1 + (room − 1) / 2`, so the first six rooms could only draw melee. `crossfire_chase` 4 → 2, `polearm_screen` 6 → 3, `fire_pursuit` 5 → 3, `ice_displacement` 5 → 4, `brute_support` 7 → 5, `captain_cross` 7 → 6, `knight_command` 9 → 8.
- **Phase was the harder gate, and it is not fixed by tier.** The `opening` pool offered one ranged option out of three and `respite` one of five, so those rooms were near-guaranteed melee at any tier. `screened_archer` gains `opening`, `fire_pursuit` gains `respite`: now 2 of 4 and 2 of 6.
- **Repetition window 2 → 4**, plus a new rule: prefer a recipe that introduces a role the previous room did not have. A recipe label is not variety.
- **The Shield guarded through its own swing.** Strike diagnostics showed `BLOCKED` against a shield at `melee@0.06` and `melee@1.22` — it was attacking from behind an active guard, which is the opposite of the design. Its guard now drops for the whole of its attack and recovery, which is the opening a screen is supposed to sell you.
- **The Ox could not reach its own charge gate.** At radius 76 it could never stand further than 96 units away, against a hardcoded 120-unit floor — so it walked up and never charged again, two gores in 36 seconds. Radius 76 → **52** (it was larger than the Werewolf, which is a boss), and the gate is now derived from its own body so changing the silhouette cannot disarm the attack.
- **The charge contact ring is gone.** It existed to make an invisible collar honest; with the collar removed in `0.2.26` it only traced body plus player radius and read as an artificial circle.

Still outstanding: enemy crowding, which killed a run by movement lockout rather than by difficulty, and is worse since bodies grew.

### v0.2.28: One fix, one diagnosis, one withdrawal

Three known gaps from `0.2.27` were taken together. One is fixed, one turned out to need work of a different order, and one was tried and taken back out.

**Fixed — the Hound was retreating to half a screen.** The evade-to-charge gate added in `0.2.26` set its cooldown floor *inside* the evade branch, and that branch only runs while the cooldown is already above zero. So it re-armed its own gate on every decision and the Hound could never stop retreating: measured at a **mean 495 units** from the player, for a flanker. The floor now applies on entering the evade only. Mean distance **495 → 133**, with charges still landing.

**Diagnosed, not fixed — reach cannot hold its distance.** The Polearm's thrust carries **229 units** of authored forward travel from Milestone C's capture model, and it commits at 218 — so every thrust ends in melee by construction. A step-back cannot recover it: at speed 120 a retreat covers about 53 units against that 229, and gating the attack behind a retreat only stops the spear attacking, which broke two roster assertions. Making reach real means reworking the thrust's forward travel, which changes its capture curve. That is Milestone C work, recorded in the branch rather than left to be rediscovered. The Polearm's long thrust is weighted up (1.0 → 1.7) so at least its attack choice matches the role.

**Withdrawn — gating attacks on being in position.** A frontliner aligns while approaching and then drifts, because its attacks carry it off the line and nothing pulls it back; it settles about 41° off the bearing it wants. Refusing to attack while out of position corrected that, and also destabilised *when* enemies commit, breaking two roster assertions for a marginal gain. Correcting a held line needs a reposition that does not compete with attacking, not a veto over it.

### v0.2.27: Roles stop being decoration — Milestone E1

`role` was assigned by every recipe, printed in every survey report, and **never read by the simulation**. Behaviour keyed on `kind` through hardcoded lists like `kind in ["bandit", "knife", "hound"]`, so "flanker" was three kind names rather than a concept, and a Boar tagged `frontline` behaved like any other Boar. The vocabulary the whole encounter generator is built on did nothing.

- **Role is now a property of the kind**, declared in `ARCHETYPES` and read through `CombatCatalogScript.role()`. A Hound is always a flanker. Recipes no longer author a role per entry, so a recipe and a kind can no longer disagree.
- **Role drives approach.** `_role_bearing()` decides which way an enemy wants to stand from the player, and both the pursuit target and the melee approach share it. Frontline covers its whole group; a **screen** covers specifically the allies that cannot defend themselves; **reach** holds the bearing it already has instead of closing; flankers keep their existing lane behaviour.
- **The Shield returns to rotation** as the screen, and `Screened Archer` now has an actual screen in it rather than a Blade. Composition cost 3.
- Measured, starting every kind 77° off a backline ally's bearing: a screen settles at **24°** and a flanker at **45°**. They are now cleanly opposed, where before every kind ran at the same point and "flanker" was only a different route into the same pile-up.

**Two limits worth stating rather than discovering.** Frontline reaches 38° rather than fully holding the line — contact and its own attack advance pull it around. And **reach does not yet hold distance**: the Polearm still closes to melee because its intent selection keeps picking the short reverse cut, which is the attack-mix work E lists separately. Both are visible in play rather than hidden.

### v0.2.26: If it reaches further, it has to be bigger

"Large body" was implemented as an invisible collar. A Boar with a 31-unit silhouette carried a 40-unit `contact_bonus` and connected at 91; the Ox reached 115 on a 54-unit body. Drawing a ring around that does not make it honest, it only labels the lie.

- **The animals are actually bigger and the collars are gone.** Boar radius 31 → **42**, Ox 54 → **76**, and every charge now uses the default 8-unit contact epsilon. Reach follows the silhouette: the Boar connects at 70 instead of 91 and the Ox at 104 instead of 115.
- The Boar loses real denial in the trade — 91 to 70 — and will be easier to step around than the `0.2.25` numbers were tuned for. That is the honest cost of a truthful hitbox, and the charge curves are due a tuning pass regardless.
- The Ox's 104 still sits inside the band that defines it: the aim locks at 0.765s and the charge arrives at 1.14s from the nearest interesting range, leaving 0.375s in which walking covers 97 units and a Dodge about 131. Below 97 it would be walkable, above 131 unanswerable.
- **A Hound's retreat no longer feeds straight into a charge.** It could slip a committed strike and be mid-wind-up before the player recovered — a whole evade-and-counter inside one 0.983s commitment, which makes swinging at a Hound strictly a mistake. The Bandit already gates this with a 2.0s `dodge_strike` cooldown; the Hound now spends `0.32 + 0.55` in neutral after evading.
- **The wind-up bar covers every telegraphed action, not just charges.** Melee attacks draw their telegraph from sector geometry, but arrows, casts and slams carried no visible wind-up at all — so the decision each was meant to pose was invisible. Archers included.

### v0.2.25: The Ox asks which way you are standing

Every attack in the game asks a **radial** question — am I close enough. The Ox asks a **lateral** one: am I on its line. It commits from any distance with line of sight and runs until it hits the player, hits a wall, or exhausts a 900-unit cap, so there is no safe range, only a safe bearing.

That inverts the answer rather than adjusting numbers, which is a far more robust way to make an enemy distinct than the tuning this milestone has otherwise consisted of. It also finally gives terrain a job: the obstacle-crash path that already existed now matters, because an Ox baited into a wall staggers and loses posture.

- **`0.85 / 520 / 900-unit cap`, damage 7, 96 health, composition cost 5.** Elite tier, appearing through the new `Goring Line` recipe from tier 5.
- **Unstoppable once running.** Nothing short of a killing blow interrupts it, so stopping it is a spacing decision rather than a damage race.
- **Its width is derived, not chosen.** The aim locks at 0.765s and the charge arrives at 1.14s from the nearest interesting range, leaving 0.375s in which walking covers 97 units and a Dodge about 131 — it displaces 150 but only starts moving 0.08s after commitment, so a late Dodge lands short. The contact radius has to sit between those two numbers or the Ox is either walkable or unanswerable. It sits at **115**.
- Measured at 150: retreating fails at every timing, an immediate Dodge clears by 14 units, an immediate sidestep by 2. At 300 there is room to walk clear. At 500 it runs into the arena edge and wrecks itself.
- **Hound wind-up 0.55 → 0.70**, matching the Boar. At 0.55 a committed player was caught even at 220 — "you can never be busy near a Hound" is a constraint rather than a decision, and the information arrived after the commitment that triggered it. Its differentiation lives in damage, body width, speed and re-charge cadence, all visible before you commit.

### v0.2.24: A charge that resolves inside your swing is not a decision

`0.2.23` shortened the Boar's wind-up to 0.30 and the Hound's to 0.20 on the reasoning that a 0.44s combo phase left one or two decision points. **0.44s is the gap between strikes inside a combo, not the time until control returns.** Measured:

```
basic attack     lockout = 0.800s
combo strike     lockout = 0.983s
held combo       lockout = 2.475s
```

So a commitment costs nearly a second, and at the shipped numbers a charge that fired mid-swing resolved *entirely* before the player could act. The outcome was set by when it happened to fire rather than by any read — which plays exactly as badly as it sounds. Every wind-up figure in `0.2.22` and `0.2.23` was sized against the wrong number.

- **Boar `0.70 / 1.50 @ 360`**, Hound **`0.55 / 0.93 @ 500`**. Both now outlast a single commitment, so answering the telegraph immediately escapes at every range on both axes — which is the rule-4 case working rather than an exception to it.
- **Commitment is what makes you late.** Committing to a strike inside either animal's range is punished at 150; the charge converts a readable telegraph into a hit *because you were busy*, not because it was unreadable. That is the capture principle applied to charges.
- **The differentiation landed somewhere better than the decision-count framing it was designed around.** At 220 a committed player escapes the Boar and is still caught by the Hound. The Hound is the animal you cannot afford to be busy near at any range; the Boar is the one that hits for 5 if it reaches you.
- Sidestepping stays harder than retreating at close range — tracking still caps what stepping off the line is worth — and at point-blank a swing that reaches the animal interrupts the charge outright, which is a legitimate third answer.

The probe that let `0.2.23` ship only ever modelled a player free to act at any moment. It now models a **committed** player as well, and the regression tests assert the commitment case directly.

### v0.2.23: A charge is a question about spacing

`0.2.22` fixed the Boar's arithmetic against a player retreating **along** the charge line. Stepping off the line was never modelled, and it turned out to be roughly twice as forgiving — an effective walk-safe fraction of 0.94 against the authored 0.50, and at longer range a sidestep escaped at any timing whatsoever. The authored number only ever described one axis of movement.

- **Charges track through the wind-up and lock at launch.** `tracking_end` per kind. Re-aiming at someone backing away does not help close a gap you have not started crossing, so this penalises sidestepping while leaving the retreat curve untouched. It cannot create a "too early and it reads you" window — displacement banked after the lock still counts, so the curve plateaus rather than failing — what it sets is the **ceiling** on how much a sidestep can ever be worth.
- **Contact width is per charge** (`contact_bonus`), and **is now drawn while the charge runs**. A charging Boar connects at 91 units against a 31-unit silhouette; that width is what denies the sidestep, and rendering it is the difference between a heavy animal and being struck by empty ground.
- **A wind-up bar.** Charges carried no sector geometry, so `_draw_attack_sector` never saw them and the crouch during which the animal tracks you was completely invisible. Every timing decision a charge is meant to pose was untestable. Fills across the wind-up only, clears at launch, sits between the health bar and the awareness marker.
- **Boar as the heavy:** `0.30 / 1.10 @ 360`, damage 2 → **5**, contact bonus 40, tracking 0.95. Measured at point-blank, **neither retreating nor sidestepping works at any timing** — and the Dodge has a real window on both sides, failing early as the i-frames lapse before 288 units of Boar arrive, and failing late before they begin. At 150 a sidestep survives by 5.9 units; at 220 range answers it. Distance is the defence.
- **Hound as the harrier:** `0.20 / 0.58 @ 500`, damage 2, contact bonus 10, tracking 0.85. The difference that matters is not speed but **how many decisions the telegraph affords** — movement resolves in 0.131s steps, so its 0.20s wind-up is one look at the bar where the Boar's 0.30s is two. Commit on first sight or wear it, but it costs 2 rather than 5, and its narrow body leaves a sidestep available at range.
- Both charges are authored at `f = 0.50`. A charge's effective fraction is dominated by launch distance rather than timing — at 90 only a Dodge answers either animal, at 220 everything does — so 0.50 is the mid-range intent, and the survey records how far observation departs from it.

### v0.2.22: The Boar could not catch anyone

`MELEE_ATTACK_PLANS` covers eight kinds — Blade, Knife, Bandit, Shield, Brute, Polearm, Captain, Knight. Boar and Hound are not among them, and only `melee` actions ever carried capture records. So the two most common melee enemies produced **no capture data at all** across three surveys, and every claim about walking's defensive value described three of the five melee kinds.

They were skipped for a real reason: a charge's forward travel sits inside its damaging window, not its wind-up, so Milestone C's derived advance did not apply. But the arithmetic shows the skip landed very differently for the two of them.

- **The Boar could not touch a walking player from any launch distance.** A 0.52s stationary wind-up handed the player `0.52 × 260 = 135` free units; the charge then closed `158 − 114 = 44` of them back, finishing **91 units further away than it started**. That is the pre-Milestone-C failure — walking as a universal answer — surviving intact in the one kind the milestone did not touch. It explains why the `0.2.20` run ended to a Boar only while the player was committed to something else.
- **Retuned to `0.40 / 0.84 @ 444`** from `0.52 / 0.96 @ 360`, derived rather than guessed. Contact needs the gap to fall to the allowance of 59, not merely to stop growing, and the nearest a charge may launch is 88 — so `f = 0.50` requires a 29-unit net close at the midpoint, giving `V = (130S + 143.4) / W` = 444. Measured: from a launch gap of 90, answering immediately escapes by 52 units, answering at exactly half the wind-up contacts by 4.5. The commitment keeps its character — 195 units of unsteerable travel.
- **`f` for a charge varies with launch distance**, because a charge commits wherever it can reach rather than at one authored strike distance the way melee plans do. 0.50 is the value at the closest launch and grows more forgiving further out; the survey now records the spread.
- **The Hound is instrumented but deliberately unchanged.** Its numbers already net a walking player only +10 units, an effective `f` of about 0.12 — walking almost never saves you and the answer has to be a Dodge. That is recorded as description, not endorsed as design, pending a decision on whether a flanker should be walk-proof.
- **Charges now carry capture records** through commitment, observation, contact, interruption and completion, including the obstacle-collision path that replaces the action mid-charge.

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
