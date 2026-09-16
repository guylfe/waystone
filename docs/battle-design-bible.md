# Waystone Battle Design Bible

**Purpose:** a single, reviewable source for designing enemies, attacks, encounters,
and bosses in Waystone.

**Recorded:** 2026-09-12

**Current code baseline:** `0.2.91`

**Status:** mixed. This document deliberately contains settled rules, strong defaults,
and unproven proposals. Every prescriptive claim carries both a **credence** and a
**decision status** so that an attractive hypothesis cannot quietly become doctrine.

This bible consolidates the relevant parts of:

- `docs/design-foundations.md`;
- `docs/combat-character-framework.md`;
- `docs/combat-loop-diagnosis.md`;
- `docs/attack-capture-design.md`;
- `docs/survey-archive-findings.md`;
- `docs/expedition-encounter-redesign.md`;
- `docs/journey-design-principles.md`;
- `docs/elemental-casters.md`;
- `docs/warrior-vanguard-redesign.md`;
- the supplied *Waystone Enemy Combat Design Specification*, derived from a study
  of Dark Souls enemy design.

It does not replace the detailed mechanical documents or the code. When they
disagree, current source is the implementation fact and the documents are design
evidence. Investigate the difference rather than silently choosing one.

---

## 1. How to read the ratings

Credence means **confidence that the principle is right for Waystone**, not a
statistical probability and not proof that it is implemented.

| Credence | Meaning | How to use it |
|---|---|---|
| **95–100% — Foundation** | A load-bearing Waystone promise or repeatedly confirmed rule. | Do not violate without an explicit design reversal. |
| **80–94% — Strong** | Supported by several arguments, tests, or observations. | Use as the default; challenge with concrete contrary evidence. |
| **60–79% — Provisional** | Coherent and promising, but not sufficiently isolated in Waystone play. | Prototype and falsify before generalising. |
| **35–59% — Exploratory** | A useful possibility with major unanswered questions. | Keep out of shared rules until a focused test earns promotion. |
| **0–34% — Rejected for now** | Conflicts with Waystone or is too poorly supported in its current form. | Do not implement as written without new evidence and a revised argument. |

Decision status is separate:

- **Settled:** explicitly established as a Waystone rule.
- **Implemented:** present in the `0.2.91` code baseline; this alone does not make
  it good design.
- **Working default:** the best current rule, but revisable.
- **Proposal:** not approved merely because it appears here.
- **Open:** a question, not a rule.
- **Rejected:** argued against in its current form.

The numeric score is intentionally visible. “Strong” can otherwise make an 82%
working assumption look indistinguishable from a 98% foundation.

---

## 2. The battle promise

### B01 — Deliberation is unlimited; committed actions have continuous consequences

**Credence: 100% — Foundation. Status: Settled and implemented.**

Waystone is a knowledge-driven action RPG in which time stops while the player
thinks and runs while the player acts. The player is tested on prediction, spatial
judgment, action choice, and adaptation—not reaction speed.

Every action therefore needs a legible commitment. During startup, active contact,
and recovery, enemies, projectiles, conditions, and hazards continue to advance.

### B02 — Releasing input must always return to a safe thinking state

**Credence: 100% — Foundation. Status: Settled and implemented.**

The player cannot be damaged merely because they stopped touching the game. A
held input remains an active decision and may continue to advance danger. Even an
endgame time-manipulating enemy must return control before damage becomes active.

This forbids reflex checks and narrow response windows. It does not forbid timing:
the player may choose *when* in a readable wind-up to commit.

### B03 — Visible physical contact resolves deterministically

**Credence: 100% — Foundation. Status: Settled and implemented.**

The visual attack is a promise. If the displayed attack crosses a valid target, it
hits; ordinary damage is fixed after explicit modifiers. Uncertainty may govern
which sensible action an enemy selects, but not whether a visibly successful hit
arbitrarily fails.

Exact distances, timings, and posture values should remain hidden in normal play.
The player should judge “long reach” or “high stability,” not solve exposed decimal
arithmetic with unlimited thinking time.

### B04 — The commitment horizon is a fairness boundary

**Credence: 94% — Strong. Status: Working default.**

An enemy that was not visibly threatening when the player committed should not be
able to begin and land an unavoidable attack before the player’s next decision
point. A branch may become dangerous during the player’s action only if:

1. the dangerous branch was already legible before commitment; or
2. every branch still available shares at least one legal response through the
   player’s next readiness point.

This is the Waystone-specific constraint on delayed attacks, combo branches, and
initiative reversals. Frozen time allows deep decisions; it does not excuse hidden
future traps.

### B05 — A late read is punished

**Credence: 98% — Foundation. Status: Settled and implemented.**

Walking early may answer an attack; beginning the same walk at the end of the
wind-up should not. The exact capture point is an authored tuning question. Dodge
and other defensive techniques retain their purpose because ordinary movement is
timing-sensitive rather than universally sufficient.

### B06 — Actions pay distinct costs rather than one universal tax

**Credence: 91% — Strong. Status: Working default.**

An action may charge time, space, resource, initiative, information, and future
options. Recovery answers “when may I choose again?” Energy answers “how much can
I do before yielding?” Hitstun, action poise/hyperarmor, and cumulative posture
answer different questions again. Do not make one global lever compensate for a
problem owned by another.

---

## 3. Player answers and defensive legibility

### B07 — Ordinary movement is a real defense, but not a universal escape

**Credence: 97% — Foundation. Status: Settled and implemented.**

Walking is free, continuously steerable, and a first-class tactical tool. Enemy
capture comes from authored attack travel and commitment distance, not from making
walking unusably slow. Early movement should often work; late movement should
often fail.

### B08 — Each defensive technique must own a recognizable answer

**Credence: 91% — Strong. Status: Working default.**

Walking, Dodge, Vault, Block, Endure, displacement, and class abilities should not
be cosmetically different ways to negate the same event. Each needs a different
combination of geometry, cost, timing, and follow-up. If one dominates, inspect the
six action costs before simply buffing the ignored option.

### B09 — Taking one hit must not silently remove all agency

**Credence: 92% — Strong. Status: Implemented working default.**

Hit reactions, overlap, body collision, and follow-up timing must preserve a legal
next decision unless the player knowingly entered a terminal state. A hit can be
severe without becoming an unreadable chain caused by simulation bookkeeping.

### B10 — Resource rules belong to the action that creates the problem

**Credence: 94% — Strong. Status: Settled architecture.**

Spell economy is tuned through spell costs and Intelligence, weapon economy
through authored physical costs, Rally through its sustained drain, and recovery
through action timing. Do not globally distort movement, regeneration, or all
attacks to repair one class, ability, or enemy.

---

## 4. Building an enemy

### B11 — One enemy, one clear tactical sentence

**Credence: 92% — Strong. Status: Working default.**

A regular enemy should first be describable as one problem:

- “The Boar commits down a lane and makes bearing matter.”
- “The Hound rapidly re-enters from changing angles.”
- “The Shield makes frontal offense inefficient.”
- “The Archer prices open ground.”

Additional moves should develop that sentence or cover a specific positional
failure, not turn the enemy into a general answer to every player strategy.

### B12 — Weaknesses are part of identity

**Credence: 95% — Foundation. Status: Settled direction.**

An enemy does not need a response to every range, facing, weapon, or tactic. The
player should be able to learn and exploit what it cannot do. Composition creates
difficulty by making one enemy’s exploit expensive in the presence of another.

### B13 — Individually solvable, combinatorially hard

**Credence: 97% — Foundation. Status: Settled.**

A patient player should be able to beat any non-boss enemy one-on-one. Difficulty
belongs mainly to the encounter: pair enemies whose correct answers conflict. A
roster of individually self-sufficient opponents becomes a roster of walls.

### B14 — Repertoire must match tactical purpose and expected lifetime

**Credence: 89% — Strong. Status: Working default.**

A move family is tactically distinct, not merely a different animation. A
three-swing predictable combo may be one family; two similar-looking attacks may
be separate if they demand different decisions. Short-lived enemies need enough
repetition to be learned. Long-lived enemies need enough relationships to remain
interesting.

**Prototype budgets, not quotas — Credence: 70%. Status: Proposal.**

| Combatant | Starting budget of meaningful families | Where complexity should live |
|---|---:|---|
| Basic regular | 1–3 | One strong idea, group interaction, terrain |
| Complex regular | 2–4 | A primary problem plus one timing/position variation |
| Elite or centerpiece | 3–6 | Initiative reversal, conditional state, matchup knowledge |
| First boss vertical slice | 4–6 | A few repeated anchors, relationships, a phase remix |
| Mature boss | 6–10 active/total as earned | Long-form learning and conditional branches |

These are smaller than the supplied Dark Souls-derived 3–5 / 6–8 / 10–15
targets because Waystone usually resolves regulars in groups, has frozen
reassessment, and does not yet have a mechanically defined universal elite tier.
Add a family only when it asks a missing question.

### B15 — Bounded uncertainty is preferable to either scripts or chaos

**Credence: 88% — Strong. Status: Proposal requiring enemy-specific tests.**

An enemy may have several moves, but range, facing, state, recovery, previous move,
and visible pressure state should usually narrow the plausible next choices. For a
complex enemy or boss, roughly two to four plausible choices in one state is a
useful starting heuristic—not a requirement for every regular.

The player should understand *why this category of response was available* without
knowing the exact next selection. Uniform selection from the whole repertoire is
noise, while a fixed script becomes rote.

### B16 — Enemy choice may read observable state, never secret bookkeeping

**Credence: 96% — Foundation. Status: Settled direction.**

Valid context includes distance, facing, visible movement, a committed attack,
healing animation, known conditions, and the enemy’s own state. Invalid context
includes the player’s unshown Energy number, hidden cooldowns, future input, or a
decision made only after seeing information that was unavailable at commitment.

An enemy may punish *healing it can see*. It may not select a perfect counter
because a private variable says the player cannot afford Dodge.

### B17 — Timing profiles should differ because the decisions differ

**Credence: 85% — Strong. Status: Working default.**

Fast checks, deliberate commitments, advancing attacks, branches, and large
punishable actions are useful only when they ask different questions. “Delayed” is
not automatically deeper: in frozen time, the delay must expose a meaningful state
or change the cost of acting, not merely copy a Souls dodge-roll trap.

### B18 — Openings are measured in executable commitments and world time

**Credence: 93% — Strong. Status: Working default.**

Do not define an opening as “two hits.” Sword, Staff, heavy weapons, projectiles,
and spells pay different durations and resources. Define:

- when the enemy can next threaten;
- what visible state precedes that threat;
- which player actions can start and safely reach their next decision point;
- what position and resource reserve those actions leave.

Hit counts may be reported afterward as weapon-specific playtest observations, not
authored as the universal contract.

### B19 — Stagger, action poise, and posture must remain separate

**Credence: 94% — Strong. Status: Implemented architecture, values provisional.**

- **Hitstun** is the immediate reaction to one impact.
- **Action poise or hyperarmor** determines whether the current commitment holds.
- **Posture** is cumulative control pressure that may earn a larger state change.

Protection should usually belong to a readable action or state. Resolve controls
the player’s base action poise; enemies use their catalogued control policies.
Permanent blanket immunity should be rare because it erases attack timing as a
decision.

### B20 — Initiative should have a readable hierarchy

**Credence: 82% — Strong. Status: Proposal.**

- A regular often loses initiative when cleanly caught, subject to its identity.
- A centerpiece or elite can visibly contest or retake initiative.
- A boss primarily grants earned windows rather than permitting indefinite control.

This is a useful relational model, not a mandatory hitstun ladder. The Ox, Shield,
Duellist, Fire Caster, and a future elite should contest initiative in different
ways rather than inheriting one tier flag.

---

## 5. Roles and composition

### B21 — Encounter difficulty comes from conflicting demands

**Credence: 96% — Foundation. Status: Settled and survey-supported.**

Enemy count and composition cost are weak proxies for tactical difficulty. The
stronger question is whether the room forces the player to manage two legitimate,
competing problems. Examples:

- go around the Shield, but the Archer prices open ground;
- watch the Ox’s bearing, but flankers tax rear awareness;
- interrupt the compounding support threat, but a frontliner owns the approach.

Pure-melee groups have repeatedly underperformed mixed pressure in survey evidence,
but the Combat Survey is a coverage instrument, not an Expedition pacing model.

### B22 — Roles describe pressure, not appearance

**Credence: 91% — Strong. Status: Working default.**

Current useful roles include frontline, flanker, screen, reach, ranged pressure,
area denial, breaker, support, and anchor. A role should say what freedom it removes
or what decision it forces. Two enemies with different art but the same pressure
are not a meaningful composition.

### B23 — The room owns a pressure budget

**Credence: 74% — Provisional. Status: Proposal.**

Waystone likely needs encounter-level coordination so several individually fair
attacks do not overlap into a state with no legal response. This should not become
a rigid one-at-a-time “attack token,” which would make groups feel staged. A better
prototype would budget simultaneous **pressure classes**:

- immediate contact;
- lane or projectile pressure;
- area denial;
- displacement or body-blocking;
- compounding support.

The acceptance test is whether the combined state preserves at least one readable
answer—not whether only one enemy is attacking.

### B24 — Terrain participates in the composition

**Credence: 90% — Strong. Status: Working default.**

Cover, approach lanes, obstacles, walls, and escape space can transform an enemy’s
question. They must not randomly invalidate it or create invisible-body traps.
Terrain should generate deliberate constraints and opportunities, such as the
surveyed moment in which a Dodge plus Advance escaped a corridor trapped between a
Boar and an Archer.

### B25 — Ally collision is part of enemy identity when it creates a readable rule

**Credence: 81% — Strong. Status: Implemented direction, still under test.**

Hounds may clear allies as agile pouncers; Boars may collide with and displace or
hurt allies as heavy commitments. Such differences are useful when they create
predictable tactical stories. They fail when allies merely freeze pathfinding,
cancel commitments invisibly, or become an exploit unrelated to the enemy fantasy.

---

## 6. Ranged pressure and area denial

### B26 — Ranged enemies price space; they should not merely be melee enemies at distance

**Credence: 92% — Strong. Status: Working default.**

Ranged pressure should change routes, cover use, facing, and priority. Closing the
distance should matter, but reaching the shooter need not turn it into a complete
duellist. Multiple ranged enemies with few melee enemies are a valid formation when
their lanes and timing create a coherent problem rather than unavoidable weather.

### B27 — Projectiles obey physical, symmetric world rules

**Credence: 97% — Foundation. Status: Settled and implemented.**

A projectile hits whatever it physically hits. Elevation, collision, faction, and
an explicit `misdirected` state determine eligibility. A pre-launch AI lane check
cannot guarantee later geometry. Player and enemy projectiles use the same rule;
Gale can therefore make either side’s projectile dangerous to its source side.

### B28 — Area denial must create a route or timing problem with a legal release valve

**Credence: 90% — Strong. Status: Working default.**

Hazards should constrain movement, action timing, or position rather than add
decorative damage. Setup/payoff sequences are welcome when the setup is legible and
the player can disrupt, redirect, outrange, wait out, or deliberately pay the
consequence. Dense overlapping fields with no readable answer are not depth.

### B29 — Enemy abilities and player spells may share systems without becoming reskins

**Credence: 91% — Strong. Status: Settled direction.**

“Use the whole buffalo” means sharing projectile, barrier, condition, displacement,
and resolution machinery. It does not mean every caster fires the same coloured
circle. Each element and enemy should tax a different tactical currency.

---

## 7. Elites and bosses

### B30 — “Elite” must be a behavioral contract before it is a content tier

**Credence: 95% — Strong. Status: Open; not currently universal.**

The current project does not have one authoritative elite behavior tier merely
because formation bands or gates use the word. Before assigning elite move counts
or rules, define what the label guarantees: expected lifetime, initiative reversal,
control resistance, reward, encounter slot, and survey treatment. Until then,
design named centerpiece enemies individually.

### B31 — A boss is an extended learning problem, not a large regular enemy

**Credence: 93% — Strong. Status: Working direction; bosses provisional.**

A boss should reuse a small set of frequent anchor actions so the player can learn
relationships during the fight. Complexity should come from state, position,
branches, resource pressure, and phase remixing rather than a bag of unrelated
attacks.

### B32 — Boss vulnerability is state-driven, not universally absent

**Credence: 90% — Strong. Status: Proposal.**

Routine attacks need not flinch a boss, but “bosses do not stagger” is too blunt.
The Warden may be a posture-centric anchor; the Werewolf may resist control during
a committed pursuit yet be interruptible or vulnerable after overextension.
Humanoid, beast, armored, exposed, and stance-broken states should behave according
to their readable fiction and tactical purpose.

### B33 — Boss phases should remix learned grammar

**Credence: 89% — Strong. Status: Working default.**

A later phase should change the tactical question while preserving enough anchors
for earlier learning to remain valuable. Extensions, new relationships, altered
terrain, or one signature rule usually teach better than replacing the whole
moveset.

**The supplied 60–75% retained / 25–40% new split has 48% credence and is only an
exploratory audit prompt.** It may help diagnose a completely unrelated second
phase, but it is not a production target.

### B34 — The first boss implementation should be a vertical slice with its own instrument

**Credence: 86% — Strong. Status: Proposal in the current roadmap.**

The ordinary Combat Survey grades rooms; it cannot automatically validate a
multi-phase learning arc. A Boss Lab should record at least:

- attempts and time survived;
- actions encountered and repeated;
- cause and state of damage/death;
- punish opportunities created, used, and overextended;
- posture/control events;
- phase transitions and which prior knowledge transferred;
- resource state through the fight;
- subjective readability, fairness, learning, and desire to retry.

The instrument’s first run should try to falsify the instrument as well as the
boss. A Werewolf-first slice is promising because pursuit, commitment, routing,
and exposed recovery directly test the core combat loop; this ordering remains a
proposal, not a law.

---

## 8. Difficulty, progression, and pacing around battles

### B35 — Difficulty adds techniques and relationships before numbers

**Credence: 97% — Foundation. Status: Settled.**

Escalate through new enemy techniques, compositions, terrain, partial information,
resource pressure, elite properties, and explicit rule changes. Do not rely on
inflated health, hidden arithmetic, random misses, or input-dexterity tests.

### B36 — Every room should have a function; not every room should be a climax

**Credence: 96% — Foundation. Status: Settled journey principle.**

A technically excellent battle can become monotonous when every adjacent battle
demands maximum intensity. Encounters may orient, develop, contrast, twist,
culminate, resolve, demonstrate mastery, or alter resources and routes. Respite
must still contain meaning; it is not merely an easy fight or empty walking.

### B37 — Familiar enemies remain legitimate content

**Credence: 94% — Strong. Status: Settled correction.**

Knowledge of an enemy accumulates, but a continuously simulated room is not a
memorized tactics puzzle. Geometry, timing, formation, terrain, build, and arrival
state create new instances. Repetition fails when it asks the same primary question
without a new context—not merely because the roster has appeared before.

### B38 — The generator composes legal expressions of authored pacing roles

**Credence: 89% — Strong. Status: Working direction.**

Expedition can use a bounded macro-waveform. Campaign must derive more of its
rhythm from topology, distance, branches, Waystones, shortcuts, and persistent
world change. Neither mode should secretly falsify combat rules to show mercy.

---

## 9. Evaluation standard

### B39 — A design claim needs an instrument that can actually observe it

**Credence: 98% — Foundation. Status: Settled method.**

Headless tests establish simulation contracts, not feel or visual truth. The Combat
Survey compares room types within a coverage run; it does not prove Expedition
pacing. Boss learning needs a boss instrument. Claims about readability require a
renderer and device. Claims about balance require play rather than only passing
tests.

### B40 — Change one attributable design relationship at a time

**Credence: 93% — Strong. Status: Working method.**

Bundle inseparable mechanics when they form one hypothesis, but do not answer a
local problem through several global changes. Preserve matched seeds and report
what was implemented, what tests verified, what was visually inspected, and what
remains subjective.

### B41 — Telemetry should answer design questions, not merely count events

**Credence: 92% — Strong. Status: Working method.**

For an enemy or encounter experiment, record the causal state around outcomes:
distance, visible commitment, response timing, capture, interruption source,
control state, allies/terrain involved, player resource and readiness, and whether
a legal answer existed. A hit rate without this context cannot distinguish a good
attack from stuck pathfinding or an unreadable overlap.

### B42 — Prototype acceptance criteria are enemy-specific

**Credence: 87% — Strong. Status: Working default.**

Each change should begin with falsifiable questions such as:

- Can a player describe this enemy’s tactical idea after a few encounters?
- Do its repeated actions create learning rather than random surprise?
- Does its protected state visibly explain why control failed?
- Does its counterplay remain legal across the player’s supported weapons?
- Does pairing it with another role create a new conflict rather than duplicate
  pressure?
- Does the telemetry distinguish a deliberate interaction from collision or AI
  failure?

Move-count compliance is not an acceptance criterion.

---

## 10. Disagreements with the supplied Enemy Combat Design Specification

These objections apply to the recommendations **as written**. They do not reject
the Dark Souls observations that motivated them.

### D01 — Fixed repertoire counts are too large and too authoritative

**Credence in disagreement: 88%. Status: Reject the quotas; retain the principle.**

The proposed 3–5 regular, 6–8 elite, and 10–15 boss families risk content bloat.
Dark Souls usually presents one enemy in real time and expects repeated deaths;
Waystone often presents several enemies simultaneously and stops between player
actions. Each additional family multiplies group-state uncertainty. Repertoire
should follow a tactical gap and expected lifetime, using B14’s smaller prototype
budgets.

### D02 — “Two or three safe hits” is not a portable opening definition

**Credence in disagreement: 95%. Status: Reject as an authored rule.**

Hit count changes with weapon, spell, combo phase, tempo, Energy, and position.
World time and executable commitments remain comparable. Hit count is useful
observational shorthand only after naming the loadout.

### D03 — Attack trees need a stricter fairness rule than “readable eventually”

**Credence in disagreement: 94%. Status: Require B04 before adopting branches.**

Time stop does not help if a branch is selected and becomes unavoidable while the
player is already committed. Every attack tree must be audited at the player’s
decision horizon, not merely at the enemy animation’s branch point.

### D04 — AI should not read “low stamina” or equivalent private values

**Credence in disagreement: 97%. Status: Reject hidden-state counterpicking.**

Waystone currently supports Energy and Recovery profiles, not a universal Stamina
assumption. More importantly, an enemy reading hidden affordability manufactures
omniscience. It may respond to visible exhaustion or behavior, not private meters.

### D05 — Universal boss anti-hitstun would erase useful identities

**Credence in disagreement: 90%. Status: Reject the universal rule.**

Control response should express boss state and fiction. Conditional armor,
overextension, exposure, and posture can distinguish the Werewolf from the Warden.
Blanket immunity would make both read as the same category with different art.

### D06 — Phase percentages are a diagnostic, not a target

**Credence in disagreement: 86%. Status: Downgrade to exploratory.**

Counting retained moves cannot tell whether prior *knowledge* transfers. One new
rule can transform every old move; five new animations can ask the same old
question. Audit the tactical grammar first and percentages only as a warning sign.

### D07 — Automated diversity constraints can fight identity and learning

**Credence in disagreement: 78%. Status: Reject as a default implementation.**

Preventing pathological repetition sounds harmless, but anchor attacks must repeat
for the player to learn them and some enemies should be persistent. Use authored
cooldowns, state transitions, and context weights. Add anti-repeat logic only after
telemetry demonstrates a real pathology.

### D08 — A universal elite tier is assumed before it is defined

**Credence in disagreement: 95%. Status: Reject until B30 is answered.**

The specification assigns elites a full behavior contract that Waystone does not
currently possess. Implementing the move counts first would let a label drive the
architecture rather than a demonstrated encounter need.

### D09 — The specification underweights encounter-level fairness

**Credence in disagreement: 91%. Status: Treat as a major omission.**

Individually readable attacks can combine into impossible states. The document
correctly says regular complexity comes from composition, but does not specify how
simultaneous pressure preserves legal answers. B21–B24 are necessary companions.

### D10 — Ranged pressure and area denial are too thinly specified

**Credence in disagreement: 90%. Status: Treat as a major omission.**

The imported model is melee-duel heavy. Waystone survey evidence says ranged and
area-denial conflicts are among the strongest room ingredients. Projectile physics,
cover, approach time, crossfire, reachability, and hazard release valves deserve
first-class treatment.

### D11 — “Stamina versus opening” uses a superseded universal vocabulary

**Credence in disagreement: 99%. Status: Replace with Energy/Recovery-neutral wording.**

Waystone is explicitly comparing Energy and Recovery rule profiles. The durable
principle is to separate action capacity from safety and recovery, not to presume
Stamina is the final system.

### D12 — The data-model and acceptance sections are too incomplete to implement safely

**Credence in disagreement: 96%. Status: Reject implementation directly from the spec.**

The supplied sections on tier comparison, opening sizes, and data model are empty
or skeletal. New behavior must use the existing catalogs, runtime schemas, stable
state fields, deterministic snapshots, and one behavioral contract owner. Design
questions must be paired with telemetry before a numbered gameplay update.

---

## 11. Credence ledger

This condensed register makes it possible to audit whether a future proposal is
being treated more confidently than the evidence warrants.

| ID | Short principle | Credence | Status |
|---|---|---:|---|
| B01 | Unlimited deliberation, continuous commitment | 100% | Settled/implemented |
| B02 | Released input is safe | 100% | Settled/implemented |
| B03 | Deterministic visible contact | 100% | Settled/implemented |
| B04 | Commitment-horizon fairness | 94% | Working default |
| B05 | Late reads are punished | 98% | Settled/implemented |
| B06 | Keep action costs distinct | 91% | Working default |
| B07 | Walking is timing-sensitive defense | 97% | Settled/implemented |
| B08 | Defensive techniques own distinct answers | 91% | Working default |
| B09 | Preserve post-hit agency | 92% | Implemented working default |
| B10 | Tune through the owning system | 94% | Settled architecture |
| B11 | One clear tactical sentence per regular | 92% | Working default |
| B12 | Weaknesses are identity | 95% | Settled direction |
| B13 | Individually solvable, combinatorially hard | 97% | Settled |
| B14 | Repertoire follows purpose/lifetime | 89% | Working default |
| B14a | Proposed smaller repertoire budgets | 70% | Proposal |
| B15 | Bounded uncertainty | 88% | Proposal/testing needed |
| B16 | AI reads only observable state | 96% | Settled direction |
| B17 | Timing profiles ask distinct questions | 85% | Working default |
| B18 | Openings use time/commitments, not hits | 93% | Working default |
| B19 | Separate stagger, poise, posture | 94% | Implemented architecture |
| B20 | Readable initiative hierarchy | 82% | Proposal |
| B21 | Difficulty from conflicting demands | 96% | Settled/survey-supported |
| B22 | Roles describe pressure | 91% | Working default |
| B23 | Encounter pressure budget | 74% | Proposal |
| B24 | Terrain participates in composition | 90% | Working default |
| B25 | Readable ally-collision identities | 81% | Implemented/under test |
| B26 | Ranged enemies price space | 92% | Working default |
| B27 | Symmetric physical projectiles | 97% | Settled/implemented |
| B28 | Area denial has a legal release valve | 90% | Working default |
| B29 | Share systems, not effects | 91% | Settled direction |
| B30 | Define elite before tiering it | 95% | Open |
| B31 | Boss as extended learning problem | 93% | Working direction |
| B32 | Boss vulnerability is state-driven | 90% | Proposal |
| B33 | Phases remix learned grammar | 89% | Working default |
| B33a | 60–75% retention percentage | 48% | Exploratory only |
| B34 | Boss vertical slice needs Boss Lab | 86% | Proposal |
| B35 | Difficulty through techniques/relationships | 97% | Settled |
| B36 | Encounters have varied journey functions | 96% | Settled |
| B37 | Familiar enemies remain legitimate | 94% | Settled correction |
| B38 | Generator expresses authored pacing roles | 89% | Working direction |
| B39 | Match the instrument to the claim | 98% | Settled method |
| B40 | Preserve causal attribution | 93% | Working method |
| B41 | Telemetry records causal context | 92% | Working method |
| B42 | Acceptance criteria are enemy-specific | 87% | Working default |

---

## 12. Open questions for the online reviewer

1. Which credence ratings seem too high or too low, and what Waystone-specific
   evidence—not genre convention—would change them?
2. Is B04’s commitment-horizon rule sufficient for branching enemy attacks, or is
   there a frozen-time failure case it misses?
3. What should “elite” guarantee mechanically, if Waystone needs the category at all?
4. Can encounter-level pressure be coordinated without a conspicuous one-at-a-time
   attack token? What is the smallest test of B23?
5. Are B14’s smaller repertoire budgets appropriate for group combat, or should
   bosses earn more families through longer expected learning time?
6. How should Werewolf and Warden differ in pursuit, control resistance, punish
   windows, and phase logic so B32 produces two identities rather than exceptions?
7. What Boss Lab observations would falsify “boss as extended learning problem”?
8. Which principles above are actually independent, and which are consequences of
   the frozen-time promise that should not be tuned separately?

---

## 13. Evidence and provenance map

This is not a claim that every older sentence remains current. It records where the
reasoning and evidence behind each group can be inspected.

| Bible material | Primary provenance |
|---|---|
| B01–B06 | `docs/design-foundations.md` §§4.2–6; `docs/combat-character-framework.md`; `docs/attack-capture-design.md` |
| B07–B10 | `docs/combat-loop-diagnosis.md`; `docs/attack-capture-design.md`; `docs/warrior-vanguard-redesign.md`; recent Energy/Recovery decisions |
| B11–B20 | `docs/design-foundations.md` §§4.3–4.6; supplied Enemy Combat Design Specification; current enemy behavior and control policies |
| B21–B25 | `docs/survey-archive-findings.md`; `docs/expedition-encounter-redesign.md`; `0.2.89`–`0.2.91` survey observations and collision work |
| B26–B29 | `docs/elemental-casters.md`; survey findings on non-melee pressure; canonical projectile/effect rules |
| B30–B34 | supplied Enemy Combat Design Specification; current provisional Werewolf/Warden code; Boss Lab proposal |
| B35–B38 | `docs/design-foundations.md`; `docs/journey-design-principles.md`; `docs/expedition-encounter-redesign.md` |
| B39–B42 | `CLAUDE.md` verification rules; `docs/survey-archive-findings.md`; combat survey and telemetry contracts |
| D01–D12 | Comparison of the supplied specification against the sources above and the `0.2.91` implementation baseline |

---

## 14. Use in future work

Before adding or changing an enemy, encounter, or boss:

1. Name the missing player decision or pressure relationship.
2. Identify the relevant B-principles and their credence.
3. State whether the work preserves a settled rule or tests a proposal.
4. Define a falsifiable acceptance question and the instrument that can observe it.
5. Implement through the canonical catalogs and shared resolution boundaries.
6. Verify simulation, presentation, device behavior, and play only to the extent
   each is needed; report the unverified layers explicitly.
7. Change a credence rating only when new reasoning or evidence is recorded.

The bible is successful if it makes disagreement clearer. It has failed if a
numbered suggestion becomes a “rule” merely because it was written down.
