# Warrior and Vanguard — redesign

**Status:** Approved and implemented in `0.2.85`. The diagnosis and debate below were verified against the pre-change `0.2.84` source and are retained as design history.

**Recorded:** 2026-09-05, from a design conversation that began with *"I think Vanguard is boring."* The Warrior proposal and first-pass values were subsequently revised in conversation on the same date; the final values and names were approved and shipped together in `0.2.85`.

**Authorship.** §1–§2 and §4–§7 are Claude's, with §3 and the first-pass values revised by Sol 5.6. **§8 is Claude's objections to that revision** and remains as the review record; the implementation resolution immediately below states what was accepted or superseded.

**How to read this.** The diagnosis comes first, because the case for changing anything rests on it and several of the findings are surprising. The two tracks follow. The rejected ideas are kept at the end with the reasons they were rejected — that section exists so the same proposals do not come back around, and several of them are ideas a reasonable person would suggest.

**Implementation resolution (`0.2.85`).** Rally drains `8` Energy per second, or `6` with Enduring Rally; Battle Flow decays after `3.5` seconds; natural action poise is `floor(Resolve / 2)` with no separate character, weapon, or action base; the L7/L9 Vanguard nodes are **Steady Momentum** and **Full Momentum**. Battle Flow pips, decay, and action-poise capacity are visible. Survey format `30` records the requested attribution. Claude's principal breakpoint objection was resolved by carrying the already-authored melee posture values through action construction and by authoring posture on hostile projectiles and damaging hazards, rather than reverting to damage-derived values at the shared hit boundary. The Mage comment identified in O4 was corrected without changing Mage gameplay.

---

## 1. Why change anything

Seven findings, all verified in source. Together they explain the complaint better than any of them does alone.

### 1.1 Vanguard offers no decisions at all

Counting choice stages across every track a class can take:

| | choice stages |
|---|---|
| Warrior total | **7** |
| Mage total | **11** |
| **Vanguard contributes** | **0** |
| Elementalist contributes | 4 |

Vanguard is four fixed nodes. Nothing in it is ever a question.

### 1.2 Three of its four nodes upgrade one ability nobody presses

`driving_impact`, `maintain_momentum` and `seize_the_line` all improve Advance. Only `vanguard_bearing` does anything else. The subclass is a four-level investment in a single verb.

### 1.3 Advance is a bad trade at any number

It spends a commitment and Energy to cross distance that walking crosses free, for less damage than a combo. In frozen time **committing is the risk** — it is the only thing the player actually spends. Paying to commit for a worse attack cannot be fixed by raising its damage.

### 1.4 The main class and the subclass do not touch

Warrior produces Rally and Building Force. Vanguard has Advance. **No Warrior node affects Advance, and Advance consumes neither Rally nor Building Force.**

Worse, the two Warrior mechanics fight each other: `request_rally()` calls `_reset_building_force()`, so using your buff discards your ramp. That is only repaired at level 10 by Warpath.

### 1.5 Rally is free, so it is not a decision

`request_rally()` contains no `_spend_energy` call. Its only gate is `rally_cooldown <= 0.0001`, with a flat `rally_cooldown = 12.0` on completion. Under Energy rules it costs nothing but 0.56s of world time.

There is no reason not to press it the moment it is available. A single optimal policy is not a decision.

### 1.6 Building Force is invisible, and its value is a fossil

`grep -c building_force scripts/presentation/game_board.gd` returns **0**. It is drawn nowhere. Its own designer forgot it existed.

And the number is stale. Building Force grants `+0/+1/+2` damage, authored when a sword hit dealt **2, 2, 3**. A full stack roughly doubled your hit. Today the combo is **10/13/17**, so the same `+2` is a 12–20% bump — about a sixth of its designed weight.

This is the same fossil that left Advance's level-3 node claiming it rises "from 2 to 3 damage" when the code does `10 → 15`. That string was corrected in `0.2.83`; the Building Force value has not been.

### 1.7 The Vanguard capstone does nothing

`seize_the_line` (rank 4, level 9) does exactly one thing:

```gdscript
if has_track_rank("vanguard", 4):
    advance_cooldown = 0.0
```

Advance's gate is `advance_cooldown > 0.0001 and not uses_energy_rules()` — the cooldown is never consulted under Energy rules — and `_begin_advance_cooldown(0.0 if uses_energy_rules() else …)` means it is already always zero.

**The level-9 capstone sets a value to zero that is already zero and that nothing reads.** It has never done anything in the profile the game runs on.

### 1.8 A correction worth recording

An earlier pass proposed that the Warrior become "the class that makes enemies stagger." **The data killed it**, and the reasoning error is instructive: it measured the *player's* posture pool and generalised to enemies.

| | posture pool |
|---|---|
| Knife | 2 |
| Hound, Archer | 3 |
| Blade, Boar | 5 |
| Shield | 8 |
| Brute | 14 |
| **Player (Warrior)** | **12** |

Player posture is `posture_base 5.0 + resolve`. Against staff hits of 1.8–3.6 posture, **ordinary enemies stagger in one to three hits** — it already happens constantly. Only the player's staggers are rare.

So there is no gap in *breaking them*. The entire design space is on the other side: **not being stopped yourself.**

---

## 2. The model: Sharpshooter

Sharpshooter is the benchmark, and the reason it works is structural.

**The subclass owns both the verb and the resource it feeds on. The main class complements indirectly and never names it.**

Take Aim is a Sharpshooter ability — `_annotate_player_action("sharpshooter_take_aim")`, its own `TAKE_AIM_ENERGY`, on `subclass_ability_cooldown`. Every Sharpshooter rank deepens it: Far Sight extends aimed range, Expose Weakness makes Take Aim grant damage and armour pierce, Dead to Rights doubles the first aimed contact.

Rogue's nodes are all **universal** — "your universal unaware multiplier", "an unaware victim", "with every weapon". Stealth makes Take Aim better; Take Aim works without it. Nothing in Rogue says "Sharpshooter".

Three rules follow, and they govern everything below.

1. **The main class owns the substrate; the subclass owns the fantasy.** Anything that turns commitment into a *feeling* — momentum, retaliation, holding a wall — belongs downstream. A main class is shared across subclasses, so taking the flavourful idea leaves the subclasses with nothing to be.
2. **A main class never explicitly mentions a subclass.** It may complement one indirectly.
3. **A subclass verb must be self-sufficient.** Its baseline value cannot depend on a resource another track provides, or it is worthless to anyone who adopts it.

Two further principles came out of this conversation and are now in `CLAUDE.md`:

- **A passive is introduced by a node, never granted silently** — and an introduced passive must still be *observable* while it runs. Building Force is the case that proved it.
- **The Stealth model**: an ability that costs while held pays Energy per second and is cancellable from the skills row. Both halves matter; a fixed duration on a cooldown has one optimal policy.

---

## 3. Warrior — the fighting class

**Identity: poise. The class that does not get stopped.**

The substrate exists and is barely used. `_apply_action_poise()` lets an action absorb incoming posture damage without being interrupted, and today only Rally and the (near-dead) Vanguard Bearing touch it.

**Why it is general enough for three subclasses:**

- **Vanguard** needs uninterrupted commitment — momentum only survives if swings and dashes finish.
- **Berserk** needs to survive the trade. Eating a hit to land the counter *requires* poise; it is the precondition for regain, not an extra.
- **Guardian** swings slowly. A heavy weapon behind a shield has long commitments, and poise is what makes them viable rather than suicidal.

Each wants it for a different reason. None of them is *defined* by it, which is what makes it substrate rather than fantasy.

### Rally, reworked

**Stealth model.** Pays Energy per second while held, prevents Energy regeneration, and is cancellable from the skills row while the player is ready. It has no fixed duration and no flat cooldown. Reaching zero Energy ends Rally and causes ordinary exhaustion. Rally drains only while world time advances.

**Agreed first-pass values:** preserve the existing 0.56-second activation commitment and 0.18-second effect point. Once active, Rally drains **8 Energy per second** and grants committed physical attacks **+15% damage, +20% posture damage, and +2 poise**. Damage and posture bonuses combine additively with other percentage bonuses rather than multiplying them. Rally applies to basic weapon attacks, linked combos, Weapon Arts, and physical subclass attacks such as Advance; it does not improve spells, consumables, movement, or defensive actions. The activation itself remains interruptible.

A full sword combo lasts about 3.3 seconds and costs 36 Energy. Holding baseline Rally through it therefore costs about another 27 Energy, for roughly **63 Energy total**. This is the intended first-pass pressure: the Warrior can still retain a defensive reserve, but cannot casually repeat full Rally sequences.

It **no longer resets Battle Flow.**

Rally is one tool, not the identity. That is the fix for what the conversation called "a relic of a lazy build where the track revolved around the singular skill."

### The track

| Rank | Node | What changes |
|---|---|---|
| **L3** | **Bear Down** / **Brace** | *Bear Down* — committed physical attacks deal **+30% posture damage**. *Brace* — committed physical attacks gain **+2 poise**. One or the other. |
| **L5** | **Enduring Rally** | Rally's drain falls by **25%**, from 8 to **6 Energy per second**. |
| **L7** | **Iron Constitution** / **Deep Reserves** | *Iron Constitution* — gain **+4 Resolve**. *Deep Reserves* — gain **+20 maximum Energy**. One or the other. |
| **L9** | **Power Through** | While performing a committed physical attack, take **25% less final health damage** from direct attacks that do not interrupt that attack. |
| **L10** | **Unbreakable** | While Rally is active, committed physical attacks cannot be interrupted or staggered. |

**The arc:** choose whether to break their posture or protect your own attacks → sustain Rally more efficiently → choose permanent stability or a larger active budget → successful poise also mitigates damage → at mastery, active Rally makes commitment completely uninterruptible.

### Poise breakpoints and the L3 choice

Poise is derived universally from **Resolve**, not unlocked by Warrior and not authored independently by characters, weapons, or actions. A committed attack uses the character's current Resolve-derived poise; individual abilities or upgrades may then apply explicit modifiers such as Rally's +2 or Brace's +2. Higher poise deterministically increases the range of attacks a commitment can withstand—it does not create a random chance, and changing weapons does not replace the character's value. If a character should have more natural poise, that character should begin with more Resolve rather than introducing a second base-poise variable.

The implemented conversion is **`floor(resolve / 2)`**: the starting Warrior's 7 Resolve produces 3 poise, while a 3-Resolve Mage or Rogue produces 1 and a 4-Resolve Sharpshooter produces 2. Current authored enemy posture damage provides useful thresholds:

| Enemy attack class | Authored posture damage |
|---|---:|
| Knife / Bandit | 1.5 |
| Blade / Shield | 3.0 |
| Polearm thrust | 4.5 |
| Brute / Knight heavy attack | 6.0 |

Under that rule, an ordinary Warrior at 3 withstands Knife- and Blade-class individual attacks; either Rally or Brace adds 2 and reaches 5, enough for a Polearm thrust; Rally plus Brace reaches 7, enough for a heavy attack. Iron Constitution raises Resolve from 7 to 11 and therefore raises natural poise from 3 to 5, producing 7 with either Rally or Brace and 9 with both. Hits still consume the current commitment's available poise normally, and all hits continue to damage the global posture pool.

The choice is deliberately mirrored and simple. **Bear Down** attacks the enemy's posture; **Brace** protects the Warrior's commitment. Bear Down is percentage-authored so it cannot fossilise as weapon damage changes. A baseline sword combo deals about 9.1 posture; Bear Down raises that to about 11.8. Bear Down and Rally together supply +50% additive posture damage, enough for a developed Warrior to threaten high-stability enemies without making Bear Down alone erase every heavy enemy.

### Why L7 is a choice

Both stats are central, but granting both in one automatic node would be excessive and would conceal which resource actually made the class stronger. **Iron Constitution** enlarges the global posture pool and, under the proposed conversion, adds 2 poise whenever Rally is absent or active. **Deep Reserves** supports Rally, attacks, Advance, and defensive techniques. At the improved 6-per-second drain, Deep Reserves' extra 20 Energy represents about 3.3 seconds of additional Rally before accounting for other action costs.

### Power Through

The exact player-facing rule is: **"While performing a committed attack, you take less damage from hits that do not interrupt that attack."** Resolve interruption first. If the attack holds, reduce that hit's final health damage by 25%; the hit still deals full posture damage and consumes full action poise. An interrupting or posture-breaking hit receives no reduction. Direct melee, projectile, and spell attacks qualify; ongoing hazards and damage-over-time effects do not. It applies only during committed physical attacks, not movement, Rally activation, potions, or defensive actions.

At the Warrior's current 4 physical defence, a 14-damage Blade cut ordinarily deals 10 and falls to about 8 under Power Through; a 24-damage Brute hit ordinarily deals 20 and falls to 15. The reduction is consequently visible against both common and heavy attacks without making the Warrior safe merely for having pressed Attack.

### Unbreakable

At mastery, active Rally suppresses posture stagger and ordinary hit interruption **during a committed physical attack**. Health damage, posture damage, conditions, action costs, and Rally drain still resolve normally, and the Warrior can still die or exhaust Rally. Posture may reach zero during that protected commitment, but no delayed automatic stagger occurs when Rally or the action ends; posture simply begins recovering from zero, leaving the Warrior exposed to the next hit. Rally's activation commitment remains interruptible before the active state begins.

### What is cut

- **Warrior's Physique** (+20 health, +1 Speed). A pure stat node with no relationship to anything. Do **not** silently fold its full reward into the base class: the Warrior already starts at 100 health, and granting the old reward at level 1 while also replacing its node would be an unmeasured double buff. Keep 100 starting health for the first experiment.
- **Building Force** leaves for Vanguard as Battle Flow.
- **Battle Rhythm** (a posture break extends Rally by 1s) — bookkeeping.
- **Warpath** (Building Force holds during Rally) — it existed only to paper over Rally and Building Force fighting each other, which no longer happens.

---

## 4. Vanguard — momentum

**Advance (baseline, level 1)** is a fast committed dash **toward an enemy** that staggers on arrival. It requires a target in its arc and is unavailable without one, so it can never be a free disengage button — it can still be used to escape, but only *through* the fight, which makes it a positioning decision rather than an exit.

The stagger is what makes it self-sufficient: a future adopted-Vanguard gets something useful on day one, independent of any other track. Battle Flow arrives at L3 as part of the same package.

Its damage is incidental. **Its job is that it is the only action that crosses distance without costing you Battle Flow.**

### The track

| Rank | Node | What changes |
|---|---|---|
| **L3** | **Battle Flow** | Introduces the chain: consecutive contact ramps your damage. Advance maintains it and refreshes its timer. |
| **L5** | **Unshaken** / **Sword Dance** | *Unshaken* — taking a hit no longer breaks your chain. *Sword Dance* — evasive actions no longer break it. One or the other. **Unshaken** is a provisional rename because the revised Warrior now owns **Power Through**. |
| **L7** | **Steady Momentum** | A break costs **one pip** instead of the whole chain. |
| **L9** | **Full Momentum** | A **fourth pip**; each pip becomes **+20% damage** and **+10% posture**. |

### Battle Flow, specified

**Three pips.** Each worth **~16.7% of a hit's base damage**, so a full chain is **+50% damage** and **+25% posture**.

| hit | base | at full chain |
|---|---|---|
| Opening cut | 10 | **15** |
| Returning cut | 13 | **20** |
| Finisher | 17 | **26** |
| **Combo total** | **40** | **61** |

**Authored as a percentage, not a flat integer.** This is the direct fix for §1.6 — a percentage moves with the damage it modifies and cannot fossilise. It also means the finisher gains most, which rewards completing the sequence rather than mashing openers.

**It breaks on:** taking a hit, any evasive action, exhaustion, the decay timer, and being staggered (rare, and included for completeness rather than as a balance lever).

**It must be visible** — three pips showing current stacks and time remaining. Introducing a passive without showing it repeats the Building Force mistake exactly.

### Why the L5 choice is self-limiting

Each branch closes the loophole the other opens. **Unshaken** still loses the chain to a dodge, so you have to genuinely stand there. **Sword Dance** still loses it to a hit, so you have to genuinely not get hit. No external limiter is needed, and two different Vanguards fall out of one node — the immovable one and the mobile one.

Exhaustion breaks it either way, which ties the two resources together: Rally drains Energy, running dry breaks your momentum, so holding Rally too long costs you the ramp as well as the pool.

### Why L7 is degradation and L9 is the fourth pip

**Order matters.** Pips-degrade-instead-of-breaking makes the chain survivable, and a longer chain is only worth chasing once it is survivable. A fourth pip on a fragile chain is a taunt; on a resilient one it is a goal. It also makes L9 strictly better for having L7 underneath it.

Degradation is also self-scaling — the more momentum you have built, the more you can afford to lose — and it converts the chain from all-or-nothing into a graded resource.

### What is cut

- **Driving Impact** — a pure-number node whose description was a fivefold fossil.
- **Vanguard Bearing** — half-dead and half-redundant. Its +2 Resolve improves a rare event (see §1.8); its poise capacity of 3 overlaps universal post-hit protection, and if Unshaken is taken then being hit does not cost the chain anyway.
- **Seize the Line** — a no-op under Energy rules (§1.7).

### How the tracks complement without referencing each other

A Vanguard may want **Brace**, because preserving a commitment helps preserve its chain, or Bear Down to turn sustained contact into faster breaks. A Berserk may prefer **Bear Down**, because trading rewards breaking them before they break you. A Guardian may want **Brace** for a different reason — a long swing that survives contact. Deep Reserves and Iron Constitution create a second independent choice between active Rally capacity and permanent stability.

None of that is written anywhere in either track. It falls out of the mechanics, which is rule 2 from §2.

---

## 5. Rejected, and why

Kept because several are reasonable ideas that will otherwise be re-proposed.

| Idea | Why not |
|---|---|
| Warrior owns **stagger pressure** | Killed by data. Enemy staggers already happen in 1–3 hits (§1.8). No gap. |
| **Weight of the Blow** — hits you shrug off make your current blow land harder | That is Berserk's entire loop: take punishment, convert to output. Main class taking it leaves Berserk with nothing to be. |
| **First Blood** — you win simultaneous trades | Too situational to be exciting; never the reason you take a rank. |
| **Take Their Measure** — being hit reveals that enemy's telegraphs | Too unintuitive and complex, and helps least in the single room a survey can measure. |
| **Deep Commitment** — longer actions carry more poise | Verified false premise: Warrior actions cluster at 1.0–1.3s (Drawing Cut 1.15–1.25, combo phases ~1s, Rally 0.56). Not enough spread to be a dial. |
| **Second Wind** — Energy regenerates while committed | Sound, and it directly answers Rally's drain — but superseded by the L7 stat node. **The economy question it solved is still open** (§6). |
| **Rallying Cry** — poise applies to every action while Rally is held | A scope increase, not an idea. |
| **Hard to Kill** — faster stagger recovery | Improves a rare event; the same flaw as Vanguard Bearing. |
| **Advance as a pure punish** — only strong against a committed enemy | Too conditional to build a subclass on. Survives as *Overrun*-style flavour inside a broader frame. |
| **The Line** — Advance ends in a braced stance | Overlaps the Shieldbearer's identity. |
| **A second Vanguard verb** | New content. The standing gate requires a demonstrated gap, not an anticipated one. |
| **Condition-X abstraction** so Advance reads a general "offensive state" | Infrastructure for content that does not exist. The `adopted` track is `"deliberately unavailable in this prototype"` with empty stages. Advance's baseline stagger solves portability instead. |
| **Poise refills from landing hits** / **cannot be displaced** | Rejected as flavour. |

---

## 6. First-survey values, resolved for implementation

1. **Battle Flow decay:** `3.5` seconds, refreshed by a weapon contact or Advance.
2. **Resolve-to-poise conversion:** `floor(resolve / 2)`, with Resolve as the sole natural source.
3. **Poise visibility:** capacity and remaining poise are drawn during every committed physical action.
4. **Vanguard names:** **Steady Momentum** at L7 and **Full Momentum** at L9.
5. **Survey attribution:** all listed Rally, poise, Power Through, and Unbreakable counters ship in format `30`.

---

## 7. Scope and sequencing

This touches Battle Flow (new, Vanguard), Rally (Warrior), Advance (baseline), nine track nodes across two tracks, the Warrior's base attributes, and the HUD twice — pips and poise.

**It is its own version, and it must not ship with unrelated gameplay changes**, so the survey that follows can attribute what it finds. That is rule 8 of the ownership contract and the lesson of `0.2.82`, which bundled seven gameplay changes and left the next survey unable to say which one moved the numbers.

The current priority in `CLAUDE.md` is the `0.2.85` Warrior · Vanguard survey. The Elementalist survey and follow-up are complete; the Vanguard survey remains the gate before moving on to bosses.

---

## 8. Claude's objections to the revised proposal

> **Authorship and status:** This section is Claude's, written after reading Sol 5.6's revision of §3 and its first-pass values. Every claim was checked against source at `0.2.84`. Nothing here is an approved decision. One earlier objection of mine is retracted below rather than deleted, because the reasoning that produced it is the kind that will look convincing again.
>
> The revision is a clear improvement on what it replaced — the Rally drain, Power Through's resolution order and Unbreakable's edge cases are specified far more tightly than my draft, and it caught a real error in mine (folding Warrior's Physique health into the base class would have been an unmeasured buff, since the Warrior already starts at 100). These are objections to specific values, not to the direction.

### O1. The poise breakpoints do not survive the comparison the code actually makes

**This is the objection that matters, and it changes what the L3 choice is worth.**

Poise is consumed all-or-nothing per hit. There is no partial absorption (`run_state.gd`, incoming-hit resolution):

```gdscript
if received_posture <= guard_remaining:
    player_action["guard_remaining"] = maxf(0.0, guard_remaining - received_posture)
    # the action holds
    return
# otherwise: interrupted
```

And incoming posture is derived, not authored:

```gdscript
var posture_damage := authored_posture if authored_posture >= 0.0 else float(damage) * POSTURE_PER_DAMAGE
```

`POSTURE_PER_DAMAGE` is `0.22`, and **no call site in the codebase passes an authored incoming posture**, so in practice every incoming hit produces exactly `damage × 0.22`.

The proposal's breakpoint table lists posture values rounded to one decimal — 1.5 / 3.0 / 4.5 / 6.0 — and then reads them against poise as though equality passes. It does not, because the real numbers are rarely round. A Blade-class cut listed at `3.0` is `14 × 0.22 = 3.08`, and `3.08 <= 3` is **false**. An ordinary Warrior at 3 poise is stated to withstand Blade-class attacks; under the code's own rule, it does not.

Every tier in the ladder is exposed to the same off-by-a-hair problem, and the direction of the error is always the same: a rounded-down table promises a tier the comparison then denies.

**This is the Sweeping Cut problem again** — a rule that held by two points out of fifty-six, in a test that would have failed on any small retune. A breakpoint that sits exactly on a boundary is not a breakpoint.

**Two fixes, either acceptable:**

- **Derive the table** from the real damage values rather than authoring rounded posture figures beside them. This is the *prefer deriving a number over authoring it twice* habit, applied to the exact numbers that motivated the redesign.
- **Or give poise a margin** — clear the tier it claims by a stated amount rather than by equality, so a later damage retune does not silently move a class across a threshold.

Whichever is chosen, the level-up text must describe what the comparison actually does. The redesign exists partly because Advance's node described a fivefold-wrong number; shipping a breakpoint table that is wrong by one hundredth would be the same failure in a smaller coat.

### O2. One poise is very nearly inert, which undercuts the stated reason for `floor(resolve / 2)`

Because absorption is all-or-nothing, **N poise absorbs a hit only if that hit deals `N / 0.22` damage or less.** At 1 poise that is **4 damage or less**:

| incoming damage | posture produced | held by 1 poise? |
|---:|---:|:--|
| 3 | 0.66 | yes |
| 4 | 0.88 | yes |
| **5** | **1.10** | **no** |
| 6 | 1.32 | no |
| 14 | 3.08 | no |

The only attacks that weak are chip hits — the Bandit's `dodge_strike` at 3 damage and one 4-damage melee. Everything else in the roster breaks straight through.

`floor(resolve / 2)` is justified as preserving "meaningful class differences using Resolve alone", giving Mage 1, Acrobat 1, Sharpshooter 2, Warrior 3. But **1 poise is not meaningfully different from 0 poise** — it changes the outcome of two of the weakest attacks in the game and nothing else. The real spread the conversion produces is closer to *Warrior 3, Sharpshooter 2, everyone else effectively nothing*, which may be the intended shape but is not what the text claims.

Worth deciding deliberately: if low-Resolve classes are meant to have *no* poise, say so and let the conversion floor at zero for them. If they are meant to have a little, the conversion needs to clear at least the 5-damage tier (`1.10`), which means 2 poise minimum — and `floor(resolve / 2)` does not give a 3-Resolve class 2.

### O3. Retracted — the Elementalist collision I raised does not hold

**I previously objected** that making poise universal would hand the Mage free protection against spell cancellation — the vulnerability its design deliberately leaves open — and that this would contaminate the queued Elementalist survey.

**That objection is withdrawn**, for two independent reasons. The survey has since been run. And per O2, the Mage's 1 poise would have held against 3- and 4-damage hits only, which is not a meaningful repair of anything.

The reasoning error is worth recording: I reasoned from *"the Mage gains poise where it had none"* to *"the Mage's vulnerability is partially repaired"* without checking what one point of poise can actually absorb. The step I skipped was dividing by `POSTURE_PER_DAMAGE`.

### O4. A stale comment the redesign should not inherit

`combat_catalog.gd` (Mage archetype) still reads:

> *"Resolve is deliberately low: a caster's vulnerability is that a hit cancels the spell, which is what the Mage track's first node exists to repair."*

At `0.2.84` the Mage track's first node is **Studious** (+1 Intelligence). Steadier Cast is gone, and **nothing in the track repairs spell cancellation any more.** The comment describes a node that no longer exists.

This matters here because it is the only written statement of *why* the Mage's Resolve is 3, and a universal Resolve-to-poise conversion makes that number load-bearing in a second system. Whoever implements the conversion should correct or replace the comment rather than deriving from it.
