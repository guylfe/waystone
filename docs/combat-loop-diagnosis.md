# Waystone — combat loop diagnosis

**Analysed against:** source at `0.2.10`, `run_state.gd`, `combat_catalog.gd`, `attack_geometry.gd`, and `WAYSTONE_MIGRATION_HANDOFF.md` (2026-08-14).
**Status of this document:** analysis and proposals only. Nothing here has been implemented.

---

## In plain terms

Enemies fight with their feet nailed to the floor. They wind up, they swing, and they never step toward the player — so taking one step back always works, and it works just as well whether the player reacted instantly or waited until the last possible moment.

That last part is the actual defect. Walking is not merely strong, it is *unconditionally* strong: reacting early and reacting late produce the same outcome, so no situation ever arises that walking cannot solve. Dodge goes unused because there is nothing it does that walking does not already do for free.

Three smaller problems sit on top of that one, and they compound in a fixed order. Attacks that cannot land make retreating safe; safe retreating makes stamina free, because walking regenerates it; free stamina makes Dodge's 18-point cost irrelevant. Fixing any of the later links while the first one holds changes nothing.

The rest of this document establishes that from the source, with the arithmetic.

---

## Summary

The handoff document names four failures and puts player movement speed at the centre of the repair. Having read the actual combat code, I think the ordering is wrong, and specifically:

**Reducing player movement speed to the proposed 165–180 band will not fix the core problem, because the core problem is not player speed.** Ordinary enemy melee attacks in `0.2.10` are authored so that they cannot hit a player who is moving away *at almost any speed*. The player-speed threshold below which a Blade's attack can connect is roughly **19–81 world units per second**. The proposed fix lands at 175. The current value is 260. Both are far above the threshold, so the attack misses either way.

This single fact explains the survey results better than any other cause: difficulty rated 1/5, Dodge unused, stamina never scarce, encounters that scale in duration rather than threat. There is very little to dodge, because ordinary melee cannot land on a moving target.

The good news is that this is cheap to fix and the mechanism already exists in the codebase.

---

## 1. The primary finding: melee attacks cannot hit a moving player

Every ordinary melee attack follows the same authored pattern:

1. The enemy triggers its attack the moment the player is within a trigger distance.
2. The attack has a long, readable startup (0.30–1.02s).
3. **The enemy does not move at all during the attack.** In the action loop inside `_update_enemies` (`run_state.gd:4030–4159`), only `move`, `evade`, `dodge_strike`, `charge`, and `pounce_combo` update enemy position. The `melee` branch does not.
4. Contact is tested against the attack's footprint projected from the enemy's stationary position, hitting the player circle of radius 30.

For **arc** attacks the footprint is the whole sector from the first active frame, so the hit envelope is a constant `reach + 30` centre-to-centre. The table below uses that. For **thrusts** and **smashes** the footprint extends over the active window — a thrust from `0.42 × reach` to full reach, a smash from `0.40` to only `0.76 × reach` — so their envelopes are time-varying and the table's `reach + 30` overstates them at attack start. This does not change the finding, since all four still miss a moving player either way, but it does change their derived capture values; see `docs/attack-capture-implementation.md` §5.

The problem is that **trigger distance is set at roughly the same value as the hit envelope.** The attack therefore begins at the outer edge of its own range and then commits to standing still for the length of its startup. The margin available for the player to leave is the difference between the two, which is usually near zero.

| Enemy (attack) | Trigger | Startup | Reach | Hit envelope | Margin | Max player speed that still gets hit |
|---|---|---|---|---|---|---|
| Bandit (quick cut) | ≤112 | 0.36s | 82 | 112 | 0 | **0–111 u/s** |
| Knife | ≤108 | 0.32s | 80 | 110 | 2 | **6–134 u/s** |
| Blade | ≤132 | 0.52s | 112 | 142 | 10 | **19–81 u/s** |
| Captain (thrust) | ≤172 | 0.44s | 142 | 172 | 0 | **0–75 u/s** |
| Shield | ≤120 | 0.62s | 122 | 152 | 32 | **52–77 u/s** |
| Polearm (thrust) | ≤218 | 0.90s | 218 | 248 | 30 | **33–52 u/s** |
| Brute (smash) | ≤155 | 1.02s | 158 | 188 | 33 | **32–47 u/s** |
| Captain (quick cut) | ≤102 | 0.30s | 106 | 136 | 34 | **113–223 u/s** |

The ranges account for the fact that an enemy re-evaluates every `ENEMY_STEER_INTERVAL` (0.14s) while closing, so it can trigger some distance inside the threshold rather than exactly at it. The low end of each range is "triggered at maximum range", the high end is "triggered as deep as the steering interval allows".

**The Warrior walks at 260 u/s. Every attack in that table misses, at every speed in the table, except the Captain's short cut in its most favourable case.** At the proposed 175 u/s, the picture barely changes — the Blade still misses by a wide margin.

### The two exceptions prove the rule

Exactly two melee attacks in the game move the enemy forward during the attack:

- **Hound pounce** — a `charge` action at 440 u/s, gated by `_charge_can_contact()` so it only commits when the trajectory can actually connect.
- **Bandit dodge-strike** — a `dodge_strike` that travels at 390 u/s for its first 0.30s.

These are precisely the two enemies your own playtesting repeatedly flagged as *actually threatening*. That is independent confirmation of the diagnosis: the attacks that work are the attacks that close distance, and they are the only two that do.

### Why this reframes the plan

The handoff lists "attack forward travel" as one of six variables to tune together in §7.2, and Milestone C is framed around combat speed. On the numbers, the relationship is not symmetric: **forward travel is the dominant term and player speed is a distant secondary.** You could take the Warrior down to 100 u/s and a Blade would still miss a player who walks away.

This also explains something the surveys have been showing without anyone quite naming it: melee enemies are not failing because they are *slow*, they are failing because their attacks are *decorative*. Adding pursuit speed to an attack that cannot connect just makes the enemy arrive faster to miss.

---

## 2. Secondary finding: Dodge is numerically dominated by walking

Independent of the above, basic Dodge is a bad action on pure numbers. From `request_dodge()` under Stamina rules, with no Evasion rank:

- duration `0.56s`, movement window `0.08 → 0.32` (0.24s), speed `625` → **150 units of displacement**
- cost **18 stamina**, i-frames `0.08 → 0.32`, then a 0.24s tail where you have stopped moving but are still locked

| | Displacement | World time | Effective speed | Stamina | Decision points | Vulnerable time |
|---|---|---|---|---|---|---|
| Walking (`MOVE_RANGE` 34 @ 260) | 34 u/step | 0.131s | **260 u/s** | **+60/s regen** | 1 per 34u | 0.131s |
| Basic Dodge | 150 u | 0.56s | **268 u/s** | **−18** | 1 per 150u | 0.32s |

Basic Dodge is **3% faster than walking**, costs 18 stamina, surrenders 3.4 decision points, and leaves you vulnerable for *more* total world-time per use than a walk step does. Walking dominates it on every axis except the i-frames, and i-frames are worthless when nothing can hit you anyway (see §1).

Worth noting: the upgraded forms are fine. Sidestep is 168u in 0.47s (357 u/s) and Long Roll 231u in 0.60s (385 u/s) — genuinely better than walking. **It is specifically the starting Dodge that is broken**, which means a player forms the judgement "Dodge does nothing" in the first minutes of their first run and has no reason to revisit it after upgrading. The survey observation that Dodge stays unused *even after Long Roll is unlocked* is consistent with a learned judgement, not an ongoing numerical one.

---

## 3. Third finding: Sweeping Cut strictly dominates the sword combo

From `attack_geometry.gd` and the combo definition:

| | Arc | Reach | Multi-target | Time to payoff | Stamina |
|---|---|---|---|---|---|
| Combo strike 1 (opening cut) | 49° | 104 | no | 0.52s | 18 |
| Combo strike 2 (reverse cut) | 54° | 116 | no | 1.25s | 16 |
| Combo strike 3 (turning slash) | **117°** | **158** | **yes** | **2.48s** | **56 total** |
| **Sweeping Cut (broad sweep)** | **160°** | **158** | **yes** | **0.57s** | **34** |

Sweeping Cut delivers a *wider* version of the combo's finisher, at the same reach, in **23% of the time**, for **61% of the stamina**. There is no situation in which building the combo for the finisher is correct. Restoring its 4.2s cooldown did not change this, because the cooldown does not touch the comparison — you simply sweep, walk for 4.2 seconds (which is free and regenerates stamina), and sweep again.

The handoff's proposed rebuild — make it an immediate version of strike 3 at ~50–56 stamina — is structurally right, and the numbers support it precisely: **56 is exactly the combo's total stamina cost.** Charging the full combo price for skipping the full combo's time is the correct shape, and narrowing the arc from 160° to 117° makes it literally the finisher rather than a better one. That item needs no revision, only implementation.

---

## 4. Fourth finding: retreat is stamina-positive

`STAMINA_REGEN_ACTIONS` includes `"move"`. At `STAMINA_REGEN_PER_SECOND = 60.0` with a `1.0s` delay, a full 100-point bar refills in **2.67 seconds of walking**.

So the loop is not merely "retreat is safe", it is "retreat is profitable": you spend stamina attacking and recover all of it by doing the thing that is already the strongest defensive option. Dodge's 18-point cost is 0.3 seconds of walking.

This is the reason exhaustion never produces danger in telemetry. It is not that the numbers are too generous in isolation — 60/s on a 100 bar is close to Dark Souls' ~45/s on a ~100 bar. It is that in Souls you rarely get 2.7 uninterrupted seconds, and here you always do, because of §1.

Note this also means the four findings compound in a specific order. §1 makes retreat safe → safe retreat makes stamina free → free stamina makes Dodge's cost irrelevant → and since walking already matches Dodge's displacement (§2), Dodge has no remaining purpose. Fixing §4 or §2 alone changes nothing while §1 holds.

---

## 5. Where I'd push back on the current plan

Three specific concerns, offered because you asked to be challenged rather than agreed with.

**The 165–180 band is not derived from anything, and the derivation that would justify it doesn't hold.** Working back from the table in §1, the player speed at which ordinary melee starts connecting is roughly 20–110 u/s depending on enemy. If you genuinely wanted speed alone to solve this, you would need something near 100 — which would be a different game, and a slow one. 175 sits in a dead zone: fast enough that melee still misses, slow enough that traversal and the Rogues suffer. It is the worst of both.

**A global speed reduction breaks the Sharpshooter, and there is no plan for that.** The Sharpshooter's loop is create distance → Take Aim → release. At 175 u/s it is slower than Hound (325), Knife (290), Bandit (285), Werewolf (285), Boar (245), Captain (235) and Blade (230) — seven of the melee roster. Its core loop stops functioning against most of the game. The Acrobat is partly protected by Vault, the Warrior is the one being surveyed so the problem is invisible in current data. If the speed change ships globally without a Rogue answer designed first, you will discover this in a Sharpshooter survey and it will look like a new problem rather than a consequence.

**Enemy speeds span 68–325, and a single player speed cannot be correct against that range.** At 175 you are outrun by seven enemy types and comfortably outrun nine (Knight 68, Brute 105, Polearm 120, Warden 125, Shield 145, Ice 150, Hexer 155, Fire 160, Archer 175). Slow heavy enemies were already reported as "pushovers you walk around"; lowering player speed makes the fast ones oppressive without making the slow ones relevant. Heavy enemies need to threaten through reach, area denial and forcing commitment — Polearm's 218 reach and Knight's 194 are the right instinct — but at any walk speed you can simply stand outside that radius indefinitely. That is a separate problem from disengagement and it will not be solved by the same lever.

---

## 6. What I would do instead

### Priority 1 — Give melee attacks forward travel (highest leverage, lowest cost)

Add a modest forward advance to `melee` actions during startup, in the same way `dodge_strike` and `charge` already do. Roughly:

- Attack advances the enemy at some fraction of its pursuit speed during startup only, stopping at the active window.
- Blade: ~90–130 u/s over its 0.52s startup ≈ 47–68 units of closure. That converts a 10-unit margin into a −40 to −58 unit margin, which means it connects against a player walking at up to ~110–130 u/s… still not 260. So this needs to pair with either a deeper trigger or a real speed reduction — but now the two work together instead of one carrying all the weight.
- Alternatively or additionally: **move trigger distances well inside reach.** A Blade that only commits at ≤95 (rather than ≤132) against a 142 envelope has 47 units of margin instead of 10.

The cleanest version is probably both: trigger deeper *and* advance during startup, so the attack is committed, readable, and lands on anyone who does not take a real defensive action. This is authored per-enemy data, which fits §7.4 of the handoff (enemy profiles own approach and attack selection).

**Do this before touching player speed.** Once melee can actually connect, the correct player speed becomes an empirical question with a visible answer instead of a guess.

### Priority 2 — Fix basic Dodge's displacement, not just walking's

Basic Dodge needs to be clearly better than a walk step *on arrival*, not after two upgrades. The 0.24s dead tail is the problem: you stop moving at 0.32 but stay locked until 0.56. Options, in rough order of preference:

- Shorten the tail (0.56 → ~0.46) so effective speed goes from 268 to ~326 u/s.
- Or extend the movement window slightly at the same speed.
- Keep the upgrade forms as specialisations from that improved baseline rather than as rescues of a broken one.

The design goal from the handoff — "does a deliberate Dodge create separation that walking cannot?" — should be checkable as a number, not a feel. I'd suggest making it explicit: **basic Dodge should deliver at least 1.5× the displacement-per-second of walking.** At walk 260 that means ≥390 u/s; at walk 200, ≥300 u/s. Pick the ratio first, then let it constrain both values.

### Priority 3 — Leave walking-regen alone; fix only the incoherent cases

*(Revised. An earlier version of this document proposed removing `"move"` from `STAMINA_REGEN_ACTIONS`. That was wrong — see §9. Walking must keep regenerating, and making Wait the primary recovery action would wreck the game's pace for no real gain.)*

Regen-while-walking is not the defect. It is only exploitable because walking is *safe*, which is §1. Once attacks can capture a retreating player, walking to recover becomes a genuine risk/reward decision — you get your stamina back, and you eat hits while doing it. That is exactly how Souls behaves, and it needs no new rule.

Two narrower things are worth correcting regardless:

- **`"hit_reaction"` and `"stagger"` are in `STAMINA_REGEN_ACTIONS`.** Being hit and being staggered currently regenerate stamina. Player *posture* recovery explicitly excludes those two states (`run_state.gd:3024`), so the two resources already disagree about whether being hit is a recovery opportunity. Stamina should follow posture here.
- **The regen delay is only triggered by spending, not by being hit.** In Souls, taking a hit interrupts recovery. Making incoming damage reset `player_stamina_regen_delay` is a one-line change that makes crowd pressure suppress recovery without touching the rate, the walking rule, or the pace.

Both of these make sustained pressure meaningful without limiting the player's movement.

### Priority 4 — Rebuild Sweeping Cut as specified

No revision needed; §3 above confirms the handoff's numbers. Worth noting it should be done *after* Priority 1, because part of Sweeping Cut's dominance is that walking cheaply herds enemies into a 160° cone. Once melee closes properly and lanes separate, the same sweep is worth meaningfully less, and you may find you over-nerf it if you tune against the current herding behaviour.

### Priority 5 — Only then revisit player speed

It is worth separating two jobs that the current plan treats as one:

- **Job A — you cannot leave an engagement for free.** This is a pursuit-speed question. It requires walk speed below the slowest common melee pursuer, i.e. under Blade's 230. Note this is only *mildly* broken today: at 260 you outrun Blade (230) and Boar (245) by a modest margin, but you already cannot outrun Hound (325), Knife (290), Bandit (285), Werewolf (285) or Captain (235). Half the melee roster already out-pursues you.
- **Job B — staying inside a threatened space punishes you.** This is the §1 problem, and it is completely broken. It is not a speed question at all.

The handoff's own prose in §5.1 actually describes Job B — "the player can… leave many threatened spaces without Dodge" — but the proposed remedy addresses Job A. That is the mismatch at the heart of the current plan.

With Job B fixed, a Dodge worth using, and retreat that costs something, the right walk speed for Job A is probably somewhere around **200–215** — below Blade and Boar, but far above the 165–180 band. That preserves traversal feel, keeps the Sharpshooter viable against most of the roster, and avoids the "sticky, jittery, input-limited" risk the handoff itself names as a Milestone C exit criterion.

### Unchanged from the current plan

Milestone A (combo continuation follows live input) and Milestone B (post-hit hyperarmor) should proceed as written and first. A is a straightforward regression fix — narrower than it first appeared, since the link-point sampling is already the intended grammar and only the unconditional seeding is wrong. B is correct as specified and independently justified: even after everything above, guaranteeing one actionable decision after being hit is a fairness floor, not a balance lever. Also worth clearing while you are in this code: `_try_clean_evade_from_movement()` grants clean-evade credit for ordinary movement, which guardrail #7 already says should be removed.

---

## 7. How to falsify each of these

The Combat Survey tool is well suited to this, but the changes above are mostly testable *without* a survey, as deterministic regressions — which is faster and less ambiguous. Suggested checks, matching the style of §7.5 in the handoff:

| Change | Deterministic test | Survey signal if it worked |
|---|---|---|
| Melee forward travel | Place a Blade at trigger range, walk directly away at current speed → attack must connect | Damage-received rises; difficulty ratings rise above 1 |
| Melee forward travel | Same setup, Dodge instead → must cleanly evade | Dodge uses per room rise from ~0 |
| Basic Dodge buff | Assert Dodge displacement-per-second ≥ 1.5× walk | Dodge used before Evasion upgrades, not after |
| Stamina regen change | Walk 3 world-seconds after a full combo → bar must not be full | Exhaustion events correlate with damage taken |
| Sweeping Cut rebuild | Assert arc 117°, cost ≈56, full terminal recovery, no cooldown | Combo usage rises; sweep stops being >50% of attacks |

One methodological note: I would not run a long survey until Priority 1 is in. Survey data collected while melee cannot connect is measuring a game that is about to stop existing, and it will make the *next* set of ratings look like a bigger improvement than it is.

---

## 9. How Souls-likes actually avoid this, mechanism by mechanism

Since walking-regen has to stay, the question becomes: how do these games let you recover while moving without making retreat dominant? The answer is that none of them rely on a single mechanism, and **none of them solve it by restricting recovery.**

**1. Fast movement costs stamina; free movement is slow.** In Dark Souls, sprinting drains stamina continuously and walking does not. So the movement that actually creates distance is the movement that spends the resource, and the movement that regenerates it is too slow to escape with. Waystone has collapsed these into one action that is simultaneously fast, free, and regenerating. This is the cleanest structural difference between the two games. You have twice rejected a walk/run split, which is a reasonable call for a touch game — but it means the job that split was doing has to be done somewhere else.

**2. Attacks travel forward substantially.** A straight-sword R1 steps into its swing; running attacks cover several body-lengths. Souls attacks are gap-closers as much as damage. This is §1 of this document, and it is the mechanism that most directly substitutes for the walk/run split.

**3. You usually cannot retreat in a straight line.** Souls level geometry is corridors, doorways, ledges, stairs, and enemies placed behind you. Backing up means backing into a wall, off a cliff, or into the archer you already passed. **I suspect this is the single largest factor, and it is the one Waystone's Combat Survey most systematically removes** — survey rooms are arenas, and the transcript shows the geometry pass was deferred. Some of what currently reads as a combat-mechanics failure may be a missing-terrain failure.

**4. Disengaging costs information.** Locked on, you strafe, which is slower than running; to actually flee you unlock and lose target tracking. Retreat trades safety for awareness. Waystone's frozen time gives perfect information at every decision point regardless of what you do, so nothing is traded.

**5. Being hit interrupts recovery.** The regen delay resets on damage, so pressure suppresses recovery. Waystone currently regenerates *through* hit reactions and staggers (see Priority 3).

**6. Retreat costs progress toward the win condition.** This is Sekiro's answer: posture decays when you disengage, so backing off undoes your work. Waystone already has this — enemy posture recovers at 1.8/s after a delay, and a full sword combo deals 9.1 posture, so roughly five seconds of kiting erases a full combo's progress. The mechanism exists; it just doesn't bite, because posture isn't the primary win condition and killing by safe attrition is always available. Worth measuring rather than assuming: if telemetry shows players are repeatedly rebuilding posture from zero, that is a real cost already being paid and ignored.

The honest summary is that Waystone is currently missing #1, #2, #3, #4 and #5, and has #6 in a form too weak to matter. That is why it feels like no single fix works — the game is not missing one mechanism, it is missing the whole redundant set, and any one of them added alone will be doing a job that five systems share elsewhere.

The two that fit Waystone's constraints most naturally are **#2 (attack travel)** and **#3 (geometry)**, because neither costs the player agency, neither adds a dexterity test, and neither requires splitting movement into two speeds.

---

## 10. Assessment of the proposed telemetry-and-experiment plan

The plan is a real improvement on what came before — it refuses to assume a single cause, sets up a controlled comparison, and defers the changes most likely to confound results. Several parts I would keep unchanged:

- **The attack-response record with classified resolution** (`hit_player` / `dodge_iframe` / `miss_out_of_range` / `miss_angular` / …) is the right instrument, and `walk_only_escape_rate` measures the actual problem directly rather than by proxy.
- **Bucketing the player's first response by fraction of startup remaining is the best idea in the document.** It is the only proposed metric that distinguishes "walking is overpowered" from "the player read the attack well", and it operationalises the success condition precisely: early read should succeed, late response should fail. Keep this even if everything else is cut.
- **Per-weapon capture identities** — spear with strong forward capture so retreat is weak but lateral is strong, brute overhead with poor capture so early recognition still wins — is a much better route to enemy differentiation than the abstract "differentiate melee roles" milestone. It gives each enemy a *spatial answer* rather than a stat spread.
- **Recording the closest distance between attack geometry and the player during active frames.** This document computes that analytically for the ideal case; the real distribution is what you would tune against.
- **Deferring speed and telegraph changes** is correct sequencing.

Four things I would change:

**Profile B does not need to be an experiment.** Whether attack capture matters is not an open question — §1 is arithmetic, not hypothesis. Enemies trigger at their own hit envelope and do not move; the margins are 0–34 units against 0.3–1.0s startups. Running A vs B to discover that capture matters spends scarce playtesting budget confirming something the source already proves. Implement capture, then use the telemetry to tune its *shape* per weapon. Reserve the experimental A/B for Profile C, where the answer genuinely isn't knowable from the code.

**Tracking and forward translation are not co-equal halves of "capture".** The current failure is almost entirely radial — players walk straight away and the margins in the table are all in the retreat direction. Rotation barely touches that. Forward translation is close to the whole fix; tracking is polish that matters for lateral/circling play *after* retreat stops working. The plan's own hypothesis 3 half-recognises this, then the implementation section treats them as two equal sub-items.

**The stride experiment is likely to fail for feel reasons and be wrongly dismissed.** "Direction changes apply at the next stride boundary" puts up to 0.2s of latency on steering, which on a touchscreen will read as unresponsive — and the plan's own question 9 anticipates exactly that. That would produce a false negative on decision granularity, which is a hypothesis worth testing properly. The fix is to decouple two things the plan treats as one: let **steering stay instant and continuous**, but make **frozen time return only at stride boundaries**. The character responds immediately to a drag; what changes is how often the player gets a fresh deliberation point. That isolates decision granularity from responsiveness, which is what the experiment is actually for.

**Add escape rate broken down by arena template.** The survey already generates `central_cover`, `wide_lane`, `scattered_cover`, `broken_sightline`, `split_approach`, `open_ring`. Reporting `walk_only_escape_rate` per template is nearly free and directly tests the geometry hypothesis in §9 — which, if the Souls comparison is right, may be a larger factor than anything in Profiles B–D. It would be unfortunate to run a four-profile factorial and never learn that the answer was terrain.

One smaller note: the plan says not to rebalance stamina during the experiment, which is right for isolation, but it also asks (question 11) whether stamina creates deliberate defensive-reserve decisions. It will not, and the telemetry will say so, because the regen loop is untouched. That is fine as a baseline measurement as long as the negative result isn't read as evidence against stamina as a system.

---

## 11. What I could not determine from the code

- **Whether `_charge_can_contact()`'s gating is too strict**, which would explain Hound pounces feeling rare. Worth checking against telemetry rather than reading.
- **Actual trigger-depth distribution.** My table's ranges assume enemies trigger somewhere between the threshold and one steering interval inside it. Real distributions may cluster differently — the strike diagnostics in format 10 record enemy position at impact, so this is measurable rather than assumable.
- **How much of the "enemies clump" problem survives the existing lane logic.** `_pursuit_target()` already reserves lanes for Hound, Bandit and Knife and leads the player's motion by 120 units. Whether that is working and being defeated, or not firing in practice, needs a look at real positions rather than the code path.
- **Whether Recovery mode has the same §1 problem.** I analysed Stamina mode. The `_melee_action` comment notes that before v0.2.6 Stamina rules were incorrectly shortening enemy recovery too, so the two profiles have diverged before and may differ here.

I would resolve those four from a survey export before committing to final numbers on Priority 1.
