# Elemental casters and the Elementalist

Design record for the four elemental casters and the player subclass that inherits
their spells. **Nothing here is implemented.** Agreed in conversation on 2026-08-26;
this file is the spec, and the ordering lives in `CLAUDE.md`.

---

## 1. The principle the four elements are built on

An element earns its identity by taxing a **different currency**, not by tinting the
same effect. In frozen time the currencies that exist are space, time, commitment and
position — health is the shallowest of them.

The failure this replaces is measurable in the current source. Fire and Ice today have
one close AoE and one ranged AoE each: four abilities, two verbs, *hurt near me* and
*hurt over there*. The element is paint.

| element | commonality — what it always does | the decision it poses |
|---|---|---|
| **Fire** | damage and burn | **near or far** |
| **Earth** | constrains space | **slow or block** |
| **Ice** | frost: slows you and softens you | **a spike you can answer, or a drip you can't** |
| **Air** | decides where things go | **control the fight or survive it** |

Four different *kinds* of question — a range question, a severity question, an
evadability question, a role question. None is another element's question recoloured.
When adding an ability, the test is whether its decision is already being asked
elsewhere; if it is, the ability is a reskin however different its effect looks.

---

## 2. Shared systems

Everything below depends on these, and they are cheap to get wrong.

### Projectiles

- **A projectile hits whoever it hits.** One systemic rule rather than a friend/foe
  flag. This is safe because `_archer_has_clear_lane()` already refuses a shot when an
  ally sits within its radius + 12 of the firing line — archers already aim around
  their own people. Friendly fire therefore occurs only when something changes *after*
  commitment: a Gale bends the shot, or an ally walks into the line.
- **Elevation becomes a gameplay property.** It currently exists only in the renderer
  (10 for arrows, 18 for firebolts). Javelins **arc**: high early, clearing the melee
  near the thrower, descending late so they can still hit at the far end.
  - Taken literally, "a thrown weapon is airborne" would mean it cannot hit the player
    either, since the player is grounded too. Elevation is friend-blind. The arc is
    what produces *clears my allies, spears the player* without a special case.
  - This is also what makes airborne enemies work rather than merely permitting them:
    the high phase has to genuinely exist for anything to be in it.
- Arrows stay flat, which gives the two ranged enemies a third axis of difference on
  top of speed and lead.
- **Attribution:** a redirected projectile that kills an enemy credits the player and
  counts in `damage_dealt`, dealing the projectile's own authored damage unmodified by
  player stats. The player did the geometry.

### Conditions

- **Burn** — buildup to a threshold, then damage **per world-second**, which in frozen
  time means it only ticks while the player acts. Standing and thinking is free; a held
  combo is expensive. That is the intent: fire charges you for acting.
  - **Dodge reduces remaining burn**, the way rolling smothers fire in other games. This
    guarantees burn always has an answer, and Dodge is already the one action exhaustion
    never takes away — so being on fire and winded still leaves something executable.
- **Frost** — buildup that slows the **whole action** (wind-up, active window and
  recovery) *and* amplifies incoming damage. The amplified hit **consumes the frost**,
  which is the release valve that stops a death spiral.
  - Implement the slow through `_player_personal_tempo()`. One number, already plumbed,
    and the three phases cannot drift apart.
  - Thresholds need tuning so frost actually accumulates within a fight.
- **Both need visible meters.** Frost especially: an invisible tempo modifier is the
  Captain's `×1.14` aura repeated, which was deleted in `0.2.33` for being imperceptible.
- **Telemetry:** capture records must store the player's frost level at commit.
  `f_observed = response_at / startup` measures *player response latency*, so a frosted
  player reads as a late player and every frosted room would lie to us.

### Barriers

A list kept **outside `walls`**, so the cached navigation grid is never touched.
Verified safe: `_navigation_direction()` takes an enemy and both call sites are enemy
movement — the player never uses the A* grid. Because the barrier never blocks enemies,
the grid being ignorant of it is *correct* rather than a concealed bug.

---

## 3. Earth — *caster exists; `sunder` shipped in `0.2.33`*

Commonality: constrains space. Decision: **slow or block**.

- **Sundered Ground** *(shipped)* — a zone that costs time to cross, cutting between the
  player and where they are going. Deals no damage at all: in frozen time, spending time
  is handing every other enemy in the room a free move. Symmetrical, so it is terrain the
  player can use.
- **Earth Wall** *(unbuilt)*
  - Straight, ~340 units, six segments, perpendicular across the player's escape heading
    at ~170 units. Heading is the player's movement direction if moving, otherwise
    directly away from the caster's group. Straight rather than an arc so the ends remain
    a real option.
  - Blocks **the player and projectiles**, never enemies.
  - Feeds `_archer_has_clear_lane()` so ranged enemies reposition rather than firing into
    it — turning "your arrows are wasted" into "you made the archer spend time walking".
  - Segments **lower** near a living enemy (~90 units) and **re-raise** when clear, but
    **never re-raise while the player overlaps one**.
    - Re-raising matters: ratcheting permanently open would mean the gap is wherever an
      enemy passed *earlier* rather than where the danger *is*, and the wall would decay
      fastest under exactly the pressure it exists to create.
    - The wall sits in the escape direction, so pursuers approach it from the player's
      side. An enemy near the wall is an enemy near you — **the gap opens where the
      threat is, and the way out runs through it.**
  - **Breakable:** a `high_impact` blow (≥ 3.5) destroys a segment outright; ordinary
    attacks chip. Earth is the element you answer with your weapon rather than your feet,
    and breaking costs an action — which is time, the thing the wall was taxing. Three
    priced options: around, through the gap, or through the wall.
  - No line-of-sight blocking. ~4.5s duration.
  - **Known risk:** the player can be cornered. Accepted; the wall never closes into a
    ring and its life is short. Watch for it in survey rather than pre-solving it.

**The asymmetry is free.** The enemy caster places the wall *behind* the player, cutting
retreat, so its own Archer is on the far side and the wall never shields them. The
Elementalist places it *toward* the threat, gating ranged enemies. One rule, opposite
value, decided entirely by placement.

---

## 4. Fire — *caster exists; both abilities are replacements*

Commonality: damage and burn. Decision: **near or far**. Fire is the element that
actually kills things, and is the Elementalist's **first unlocked ability** so the class
is playable before it becomes a control caster.

- **Fire Breath** — close cone. Heavy burn buildup, moderate direct damage. Punishes
  being in front of it; the answer is to leave the cone.
- **Fireball** — ranged projectile. Lower buildup, higher direct damage. Punishes
  standing in a line.

*On the shelf, unpicked:* **Detonate** (consume the accumulated burn stack for immediate
damage, turning burn into a resource with a spend decision) and **Cinder Trail** (fire
that persists on the ground where it lands).

---

## 5. Ice — *caster exists; both abilities are replacements*

Commonality: frost, which slows and softens. Decision: **evadability** — a threat that is
a moment, versus a threat that is a condition of being there.

- **Frost Lance** — condensed projectile. Heavy frost plus some damage, dodgeable.
- **Cold Front** — AOE. Small frost per tick, difficult to leave.

Ice never kills you; it decides who does. That keeps it out of Fire's territory, and it
means the Ice Caster is dangerous specifically *beside* a heavy ally rather than anywhere.

**Frost slows the whole action, not just recovery.** Earth taxes travelling through
space; ice taxes finishing what you started — different verbs, so the two slows do not
collide and Earth's needs no change. You can walk around sundered ground; you cannot walk
around your own frost.

### Rejected ice directions, and why

- **Encase / freeze** — a telegraphed ranged lock while world time runs. Rejected: it
  removes agency, which this design has refused explicitly and expensively (the desperate
  Dodge exists so that a hit always leaves one executable response). "Shatters on the
  first hit" bounds the *chain* but not the severity — one Ox gore inside a freeze is 31
  damage with no answer available.
- **Rime as recovery-only** — superseded by the whole-action slow, which is more palpable
  and a less arbitrary reading of the fiction.
- **Black Ice** (a sheet that locks your heading) — dropped because Air owns travel
  direction. Two elements owning direction is the reskin failure again.

---

## 6. Air — *new enemy kind; nothing exists*

Commonality: air decides where things go — bodies, and the things bodies throw. Decision:
**control the fight or survive it**.

- **Gale** — a placed point; everything near it is pushed **away from that point**.
  - **Bodies**, mass-gated on the existing `PUSHABLE_MASS` (1.35) line, *including the
    caster and the player*. Placement decides push versus pull: put the point behind an
    enemy and it comes toward you. One rule, both outcomes, and the decision is made
    fresh every cast rather than locked in at build time.
  - **Projectiles** — pushes **velocity**, not position. Position-pushing would offset an
    arrow while leaving its heading, so it would arrive in the same place merely late.
  - **Javelins** — bends velocity *and* strips **loft**, so a galed javelin comes down
    **short and off-line** into the melee it was meant to sail over. The bend chooses
    which ally it lands near; the grounding is what makes it lethal to them. Neither half
    alone produces the moment.
    - Precision worth keeping: the bend *falls out of* the rule; the grounding is an
      additional consequence. It is not a special case — a gale spoils flight, an arrow's
      flight is direction, a javelin's is direction **and** loft. Same wind, one object
      with more to lose.
  - Failure mode is honest: a badly placed Gale spends the spell to drop a javelin
    harmlessly in open ground.
- **Windstep** — self-traversal. ~400 units (roughly 2× Vault's ~198), point-targeted
  within that range, i-frames throughout travel, **over bodies but not through walls or
  barriers**, with a landing recovery longer than a dodge's tail.
  - `staff_vault` is already reserved in the catalog, style `mobility`, gated on
    `wind_shrine` — a wind mobility art was anticipated in the data.
  - **Why bounded, and why not through terrain.** The i-frames and body-crossing are not
    new: Vault already has both, from frame zero. The only genuinely novel properties of
    an unbounded version are screen-wide range and terrain-ignoring, and those are exactly
    the two that break things. Unlimited range removes the currency every spatial threat
    is priced in — the Ox's charge, the Shield's screen, crowding, sundered ground, the
    wall are all statements about what it costs to be somewhere else, and a cooldown
    rations that answer without weakening it. Terrain-ignoring negates Earth outright,
    and worse on the enemy side, where being walled becomes trivial or impossible
    depending on whether the player happened to take Air.
  - Air moves you *through the crowd*; it does not move you through the world.

*Dropped:* **Squall** (deflects projectiles) — Gale now handles missiles, leaving Squall
nothing to do. **Crosswind** — Gale with a timer, the same verb stretched.

Plus the usual new-kind work: stats, decision branch, colour, glyph, hp/speed/cost
tables, recipes.

---

## 7. Casters, weapons and the Chanter

- **Every caster carries a staff with a weak melee attack**, so none is helpless and the
  player's caster builds have the same desperation option. It should be clearly the worst
  melee weapon in the game.
- The `staff` frame exists and names `staff_strike` as its basic technique, but that
  technique has **no geometry entry and no attack plan** — real, if small, work.
- **This revises the Chanter**, which shipped in `0.2.33` with no attack at all on the
  reasoning that reaching it should end the problem. A feeble poke is better: a wholly
  inert enemy is strange to fight, and ignoring it entirely should carry a small cost.
  Reaching it still effectively ends the problem.
- **The Hexer is retired.** Under this framework its delayed danger zone is a delivery
  mechanism, not an element, and both Fire and Ice use it. Dark magic may return later as
  its own thing.

---

## 8. The Elementalist

One ability per element, **Fire first**, so the class starts as a damage caster and grows
into a control caster — a progression of identity rather than a bigger number.

Every one of the eight is an enemy ability first, learned by being on the receiving end.
The spellbook is the bestiary.

### Economy: no mana

- **Stamina profile** — spells cost stamina, with cooldowns only where cost alone will not
  prevent spam. Casting then competes with dodging; overcast and you are winded and cannot
  evade, and exhaustion already exists as exactly that failure state.
- **Recovery profile** — spells are cooldown-gated, like everything else in that profile.
- Casters get a class property — a deeper pool or faster regeneration — so one bar does
  not starve them.

A second bar would split the tension four milestones went into building: a caster who
spends mana for offence and stamina for defence never faces the trade the Warrior faces,
and casting becomes defensively free. Keeping one bar is also why the
**Recovery-versus-Stamina comparison runs after this class ships rather than in F**:
"casting competes with dodging" is the entire argument against mana, and under Recovery
there is no bar for it to compete with. Testing Warrior-only would answer half the
question and let the caster invalidate it.

### The rename

**Stamina becomes Energy**, shipped *with* the Elementalist rather than before it. The
rename's real cost is the historical record — every survey report, changelog entry and
doc says *Stamina* — and that cost is identical whenever it lands. Doing it alongside the
class that motivates it keeps one break point and puts it where it reads as a reason
rather than churn. Bump the survey `FORMAT_VERSION` with it.
