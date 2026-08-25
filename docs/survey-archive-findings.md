# What 297 rated rooms say about composition

Analysis of the full Combat Survey archive, pulled from the Pixel Fold on 2026-08-26.
It exists because a proposed encounter-grammar design was about to be built on ten
rooms of retrofitted evidence; this is what happened when the whole archive was checked
instead.

**Provenance.** 30 runs, `0.1.2` through `0.2.33`, 297 rooms carrying subjective
ratings. The Windows archive is stale (three unrated `0.2.6` runs) — every real survey
was played on the Fold. Reproduce with:

```bash
adb exec-out "run-as com.waystone.prototype cat files/combat-survey-archive.json" > survey-archive.json
```

The archive is device state and is not committed; the analysis script that produced
these numbers is in the scratch directory referenced by the commit that added this file.

---

## 1. The one variable that matters

| non-melee enemies in the room | rooms | mean fun |
|---|---|---|
| 0 | 132 | **1.61** |
| 1 | 58 | **2.48** |
| 2 | 10 | **3.20** |

*Non-melee* means Archer, Javelineer, or any caster (Hexer, Ice, Fire, Earth, Chanter).
Each one is worth roughly **+0.8 fun**, and this single variable does more predictive
work than any structural property tried against it.

Supporting figures, all from `0.2.0+` (n=200):

- **All ten of the best rooms in the archive (fun 4–5) contain a non-melee enemy.** Every
  one, without exception.
- **87% of the worst rooms (fun 1, n=79) are pure melee.**
- Only **5%** of rooms ever reached fun 4 or above.

---

## 2. It is not an artifact of pooling old data

The obvious objection is that the archive spans a game that changed enormously. So the
effect was checked inside each era rather than across them:

| era | rooms | pure melee | 1+ non-melee | gap |
|---|---|---|---|---|
| `0.1.x` pre-kernel | 97 | 2.14 (n=51) | 3.13 (n=46) | **+0.99** |
| `0.2.0`–`0.2.13` | 76 | 1.62 (n=52) | 2.25 (n=24) | **+0.63** |
| `0.2.14`–`0.2.26` | 82 | 1.65 (n=54) | 2.68 (n=28) | **+1.03** |
| `0.2.27+` post-roles | 42 | 1.54 (n=26) | 2.94 (n=16) | **+1.40** |

The effect holds in every era and is **largest in the most recent one**. Pooling is not
producing it.

### And pure-melee rooms have got worse, not better

`2.14 → 1.62 → 1.65 → 1.54` across those same eras — through E2 (anchors), E3 (mass and
felt damage) and E4 (the roster), all of which were spent differentiating melee
behaviour.

**One honest confound:** ratings are subjective and relative. Melee rooms may be
declining partly because the rooms beside them improved, recalibrating the scale rather
than the experience. The gap widening is consistent with either reading.

---

## 3. Role-based composition is a proxy, not a signal

The current roles, and their members:

| role | members |
|---|---|
| frontline | blade, boar, brute, knight |
| flanker | bandit, duellist, hound, knife |
| area_denial | fire_caster, hexer, ice_caster |
| ranged_pressure | archer, javelineer |
| boss | warden, werewolf |
| screen | shield |
| reach | polearm |
| breaker | ox |
| movement_denial | earth_caster |
| support | chanter |

Distinct role count correlates with fun at `r = +0.42` (`0.2.0+`), which looks
promising until it is broken down:

- Rooms with **0** non-melee enemies have exactly **2** distinct roles — in 131 of 132 cases.
- Rooms with **1** non-melee enemy have exactly **3** — in 54 of 58 cases.

Role count and non-melee count are **nearly the same variable**. Composing by role
diversity would be a roundabout way of saying *put an archer in it*.

**The structural reason:** eight of the roster's melee bodies sit in just two roles,
while every other role is a singleton or a pair — and almost all of those are non-melee.
So role count can only exceed 2 by drawing a singleton, which almost always means
drawing something that is not a melee enemy.

That is also the real indictment of the role taxonomy: it cannot tell melee rooms apart
from each other, which is precisely where the problem lives. A Boar charges, a Brute
holds a telegraph through chip damage, a Knight is slow and enormous — and all three are
`frontline`.

---

## 4. The rejected proposal, recorded so it is not re-proposed

A conflict taxonomy was designed and nearly built: each enemy declares the answers it
*demands* and the answers it *punishes*, and the generator prefers rooms where one
enemy demands what another punishes. It retro-predicted ten rooms convincingly.

Against the archive it fails outright: **193 of 200 rooms score zero conflicts.** The
metric is very nearly constant, so it cannot predict anything — `r = +0.08` to `+0.24`
depending on the slice, against role diversity's `+0.42` and non-melee count's `+0.51`.
Seven rooms scored a single conflict and averaged 2.71 fun against 1.92, which is
directionally right and statistically nothing.

The idea may still be sound; the implementation returned 0 for 96% of its input, and
there is no evidence for it beyond the retrofit that produced it.

---

## 5. What the archive cannot answer

**Every pure-melee room in the archive is built from the oldest, least differentiated
kinds.** Across the whole archive, the melee enemies that have ever appeared in a
melee-only room are: bandit, blade, boar, brute, captain, hound, knife, knight, ox,
polearm. Since `0.2.27` the list shrinks to: **bandit, blade, boar, hound, knife, ox**.

**The Shield and the Duellist have never once been in a pure-melee room** — and they are
the two most behaviourally distinct melee enemies in the game, one built around patience
and screening, the other around reading commitment and punishing it with a parry.

So the data cannot distinguish:

- *melee-only rooms are irredeemable*, from
- *the five oldest melee enemies are undifferentiated, and no room made of them can be good.*

Three milestones were spent differentiating melee behaviour, and no recipe ever composed
a room to test whether it worked.

---

## 6. What G1 should therefore do

1. **Guarantee non-melee presence** — at least one, prefer two. This is the strongest
   result in 200 rooms and it accounts for very nearly the whole effect. It is a small
   rule and it should be built first.
2. **Deliberately generate a small number of pure-melee rooms from the *differentiated*
   roster** — Shield, Duellist, Ox, Polearm, Brute — as an explicit experiment rather
   than as filler. If they still rate ~1.6, melee-only rooms are dead and the generator
   should stop producing them. If they rate 3+, the problem was never *melee*; it was
   those five enemies, and the fix is retiring or reworking them rather than guaranteeing
   an archer in every room.

The second is the question the archive cannot answer and the next survey can. It should
be designed in deliberately, with enough rooms to be readable, rather than left to
chance — the Chanter and the Ox have already spent a whole version unplayed because
nothing guaranteed they would appear.
