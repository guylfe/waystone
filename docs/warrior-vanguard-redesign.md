# Warrior and Vanguard — redesign

**Status:** Proposed, not approved and not implemented. Every code fact below was verified against source at `0.2.84`.

**Recorded:** 2026-09-05, from a design conversation that began with *"I think Vanguard is boring."*

**How to read this.** The diagnosis comes first, because the case for changing anything rests on it and several of the findings are surprising. The two tracks follow. The rejected ideas are kept at the end with the reasons they were rejected — that section exists so the same proposals do not come back around, and several of them are ideas a reasonable person would suggest.

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

**Stealth model.** Pays Energy per second while held, cancellable from the skills row. While up, your hits deal more damage and more posture damage. No fixed duration, no flat cooldown.

It **no longer resets Battle Flow.**

Rally is one tool, not the identity. That is the fix for what the conversation called "a relic of a lazy build where the track revolved around the singular skill."

### The track

| Rank | Node | What changes |
|---|---|---|
| **L3** | **Footing** | Introduces poise: committed melee actions absorb incoming posture damage without being interrupted. Passive, introduced explicitly, and shown on the action. |
| **L5** | **Bear Down** / **Brace** | *Bear Down* — your hits deal more posture damage, so you break them faster. *Brace* — your poise capacity rises, so you are harder to break. One or the other. |
| **L7** | *(name TBD)* | **+4 Resolve and +15 maximum Energy.** |
| **L9** | **Set Against It** | Incoming damage is reduced while you are committed to an action. |
| **L10** | **Unbreakable** | While Rally is held, you cannot be posture-broken. |

**The arc:** gain poise → choose how to spend it → become substantially more of a fighter → committing protects you → at mastery, nothing interrupts you at all.

### Why L7 is a stat node, and why that is not the relic

A generic stat node sits beside a track. **Resolve does not** — it is the currency every other node here spends:

```gdscript
capacity += floorf(float(player_attributes.get("resolve", 7)) / 4.0)
```

Resolve is both the posture pool (`posture_max = posture_base + resolve`) *and* poise capacity on every committed action. So Footing, Brace, Set Against It and Unbreakable all improve from it. It multiplies the track rather than decorating it.

**Sizing.** The largest single Temperament is Toughness at +15 health and +1 Resolve; Conviction is +14 Energy and +1 Resolve. So `+4 Resolve, +15 Energy` is Conviction plus three more Resolve — unambiguously a bigger step than any Temperament pick, in the two currencies this track uses.

`floorf(resolve/4)` means four points buys **exactly one more poise step**, which makes the node statable as an outcome rather than a number: *one more hit you can absorb mid-swing.*

The +15 Energy exists because Rally now drains per second, and the Warrior's binding constraint becomes how long they can afford to hold the state that defines them.

### What is cut

- **Warrior's Physique** (+20 health, +1 Speed). A pure stat node with no relationship to anything. **Fold the health into the class's base attributes** — a Warrior should simply *be* tougher, not spend a level becoming it.
- **Building Force** leaves for Vanguard as Battle Flow, freeing L5 for the choice.
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
| **L5** | **Power Through** / **Sword Dance** | *Power Through* — taking a hit no longer breaks your chain. *Sword Dance* — evasive actions no longer break it. One or the other. |
| **L7** | *(name TBD)* | A break costs **one pip** instead of the whole chain. |
| **L9** | *(name TBD)* | A **fourth pip**, and a larger bonus per pip. |

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

Each branch closes the loophole the other opens. **Power Through** still loses the chain to a dodge, so you have to genuinely stand there. **Sword Dance** still loses it to a hit, so you have to genuinely not get hit. No external limiter is needed, and two different Vanguards fall out of one node — the immovable one and the mobile one.

Exhaustion breaks it either way, which ties the two resources together: Rally drains Energy, running dry breaks your momentum, so holding Rally too long costs you the ramp as well as the pool.

### Why L7 is degradation and L9 is the fourth pip

**Order matters.** Pips-degrade-instead-of-breaking makes the chain survivable, and a longer chain is only worth chasing once it is survivable. A fourth pip on a fragile chain is a taunt; on a resilient one it is a goal. It also makes L9 strictly better for having L7 underneath it.

Degradation is also self-scaling — the more momentum you have built, the more you can afford to lose — and it converts the chain from all-or-nothing into a graded resource.

### What is cut

- **Driving Impact** — a pure-number node whose description was a fivefold fossil.
- **Vanguard Bearing** — half-dead and half-redundant. Its +2 Resolve improves a rare event (see §1.8); its poise capacity of 3 overlaps universal post-hit protection, and if Power Through is taken then being hit does not cost the chain anyway.
- **Seize the Line** — a no-op under Energy rules (§1.7).

### How the tracks complement without referencing each other

A Vanguard wants **Brace**, because Power Through and an uninterrupted chain are the same wish. A Berserk wants **Bear Down**, because trading rewards breaking them before they break you. A Guardian wants **Brace** for a different reason — a long swing that survives contact.

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

## 6. Open items

1. **Battle Flow's decay window.** Everything rests on this number. Suggested first pass: **3–4 seconds** — long enough that ordinary combat sustains it, short enough that being forced away costs you. A survey question, not an argument.
2. **Poise values.** Base capacity at Footing, and what Bear Down / Brace are worth. Derive from the existing `_apply_action_poise` capacity of `3.0` rather than inventing figures.
3. **Poise visibility.** An absorbed interruption currently produces nothing the player can see; `interruptions_prevented` is counted in telemetry and never shown in play. Introducing poise at L3 without showing it repeats the Building Force mistake.
4. **Rally's economy.** Rally drains per second, and *Unbreakable* is only worth taking if you can afford to hold Rally long enough to use it. The L7 stat node's +15 Energy helps but does not change the shape. Either fold regeneration into a Rally node, or set the drain low enough that a 115 pool sustains it comfortably.
5. **Rally's baseline.** Does the damage bonus stay at level 1, or does Rally start as pure poise with damage arriving later? The second is tidier, but makes the level-1 Warrior's only active purely defensive — and the Elementalist surveys showed the opening rooms already bite hardest.
6. **Names** for Warrior L7 and Vanguard L7/L9.

---

## 7. Scope and sequencing

This touches Battle Flow (new, Vanguard), Rally (Warrior), Advance (baseline), nine track nodes across two tracks, the Warrior's base attributes, and the HUD twice — pips and poise.

**It is its own version, and it must not ship with unrelated gameplay changes**, so the survey that follows can attribute what it finds. That is rule 8 of the ownership contract and the lesson of `0.2.82`, which bundled seven gameplay changes and left the next survey unable to say which one moved the numbers.

The current priority in `CLAUDE.md` is the `0.2.84` Elementalist survey. The stated plan is that the Vanguard work follows, and that **both** the Elementalist and the Vanguard are surveyed before moving on to bosses.
