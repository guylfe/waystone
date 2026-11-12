> **12 November 2026 candidate:** normal gameplay now uses single-cut ordinary melee, explicit prepaid full combos, fixed automatic ordinary Bow, and universal 1.25× playback at unchanged 120 Hz. Explicit Survey comparisons retain their grammar. This candidate is not published or installed. Normal movement now commits full 34-unit strides including nearby ground taps; interaction ranges and collision remain intact. Bounded enemy uncertainty review remains open. [Scope and verification](combat-decision-update.md).

# Waystone combat and character framework

**Status:** living design checkpoint. Implemented portions include the approved `0.3.0` expedition prototype;
future classes and deferred systems remain targets rather than current code.

**Recorded:** 2026-07-31

**Updated:** 2026-10-17; expedition additions below build on the existing Intelligence,
Mage, Warrior, and Vanguard identities. Release verification is tracked in `current-state.md`.

**Scope:** Shared actor, combat, weapon, defense, perception, condition, and character-progression rules

This document records the agreed combat and character framework introduced in Waystone `0.1.0`. It remains the authoritative design target where later prototypes are incomplete or deliberately defer a system, and future implementation should migrate toward it with regression coverage.

Exact balance values remain provisional unless this document labels a rule as structural. Faith, Blood drops, and several class-specific details remain intentionally deferred until their first concrete users are designed. Intelligence and elemental spellcasting now have concrete consumers; their current shared rules are recorded below and in `docs/elemental-casters.md`.

## Design principles

- Time freezes whenever the player is ready and has not committed another action.
- Combat depth comes from spatial judgment, action choice, and commitment rather than reflex dexterity.
- Movement and touch controls remain simple enough for mobile while keyboard and controller equivalents preserve the same simulation.
- Players and enemies use the same attributes, geometry, action phases, perception rules, posture rules, conditions, and damage events.
- Damage is deterministic. Waystone may use randomness in systems such as noise detection, but ordinary damage does not use damage ranges for now.
- Exact timing and geometry are not exposed as optimization homework. Player-facing descriptions prefer qualitative terms such as `fast`, `slow`, `long reach`, or `strong guard`.
- Tracks are authored independently. They do not follow a mandatory branching pattern or a repeated generic node formula.
- The same foundation should support Expedition, Endless, and Campaign without making their world topology or progression cadence identical.

## 1. Time, actions, and movement

### 0.3.0 timing clarification

Commitment measurements count the remainder of the action actually committed now.
A held combo does not promise its later phases until continuation is accepted.
Voluntary actions retain personal tempo; imposed hit reactions, posture-break
openings and post-hit protection own world time. Faster actors must not silently
lose their defensive opportunity because a forced reaction consumed it faster.

Capture records freeze their response classification when contact/evasion resolves
or the damaging window ends. The reaction caused by a failed walk is not a second
voluntary defense and must not remove that failed attempt from the walk-only
denominator. A later recovery punish cannot rewrite the earlier response. Startup
fractions use measured world-time startup, not an unscaled personal-time duration.
Delayed projectiles/hazards are not called misses merely because their caster recovered.

### Expedition equipment and adopted tracks

Three functional slots (Body, Boots, Gloves) modify the existing attributes and
shared displacement/projectile rules. `expedition_catalog.gd` owns the nine initial
items. Equipping requires safety/readiness, displays the replacement comparison,
leaves displaced gear on the ground and clamps current resources without healing.
Fletcher Gloves extend physical projectiles only; Surefoot Boots reduce displacement
distance, including impulse travel, rather than becoming damage reduction.

The midpoint Cinderworks Exchange consumes boss one's writ, not money, for a permanent
Trapper or Sapper choice at rank two. Rank three uses an ordinary upgrade from level
nine. Trapper: 24/20 Energy, 0.7-second action, ten-second cooldown, visible snare
lasting twelve simulation seconds; 40% movement slow for two seconds and three
posture damage; rank three permits two active snares. Sapper: 30/26 Energy,
0.9-second action, ten-second cooldown, radius 140; eight damage, three posture and
mass-sensitive displacement; rank three gives four posture and 50% more displacement.
These use the existing adopted slot, not an Elementalist-exclusive spell.

The original five-charge Rejuvenation pouch retains its 25-health timed use.
Single-use Trail Rations heal fifteen, stack to two in one of three utility slots,
reject full health and never replenish at a Waystone. Repulsion Pots use the same
mass-sensitive displacement boundary without damage. Healing discoveries and stock
are finite; there is no Salve, Field Medic, pouch-capacity upgrade or refill merchant.

### 1.1 Action phases

Committed actions may contain startup, active motion or contact, and recovery. Direction locks when an attack begins unless the technique explicitly defines guided or tracking behavior. Rendering and collision sample the same world-space action geometry.

The simulation remains authoritative at 120 Hz for combat contact and timing. Presentation may interpolate, but it must not create a second timeline.

### 1.2 Personal tempo

Speed governs an actor's personal tempo. The prototype's current starting formula remains the design baseline:

```text
personal tempo = 1 + 0.03 × (Speed - 5)
```

Speed 5 is normal tempo. Each point changes voluntary action pace by approximately 3%, subject to safe lower and upper bounds.

Personal tempo accelerates:

- ordinary movement;
- attack startup, active motion, and recovery;
- combo transitions and Weapon Arts;
- Dodge movement and recovery;
- Block raising, lowering, and guard rotation;
- Endure startup and recovery;
- spell and consumable preparation;
- personal cooldown recovery.

Speed changes time, not geometry. It does not directly change damage, posture damage, attack reach, Dodge distance, guard strength, or released projectile speed.

World-time effects do not use personal tempo. This includes condition duration and damage ticks, Rally and similar buff duration, environmental hazards, hit reactions, posture-break stagger, and other imposed conditions. A faster actor can consequently fit more voluntary actions into a world-time buff.

Posture recovery is governed by Resolve and world time rather than Speed. Speed must not become a universal resistance to stagger and bodily recovery.

Touch and keyboard forgiveness must retain an accessibility floor. A high-Speed attack may resolve more quickly, but combo continuation and similar input buffers must not become physically difficult to operate.

### 1.3 Movement controls

There is no universal walk/run distinction.

- Touch-down initially commits neither movement nor attack. A short real-time classification window does not advance simulation.
- Dragging beyond a screen-density-adjusted tolerance immediately classifies the contact as movement, even when touch-down occurred on an enemy or interactable.
- A quick release on an attackable target requests one ordinary attack when that target is contextually attackable by the equipped weapon; otherwise it remains a movement tap.
- Remaining within the tolerance for approximately 100–130 real milliseconds locks held-attack behavior.
- A quick release on open terrain commits one small, fixed-distance movement step.
- Holding chains those steps.
- Releasing stops after the current small commitment completes.
- Dragging can change the direction used by the next movement commitment.
- Once classified as movement, a contact cannot become an attack. Once classified as attack, it cannot become movement.
- Keyboard movement chains the same actions independently of operating-system key-repeat rate.
- Diagonal directions are normalized.

The classification delay is an input-accessibility rule, not world time. Movement begins as soon as drag intent crosses tolerance. A quick attack tap begins its authored simulation after release; held attacks begin after the hold threshold. Melee attacks ignore later finger drift so an original combo hold remains stable. Ranged weapons may explicitly interpret post-lock dragging as aim adjustment.

Contextual attackability remains weapon-dependent. A melee tap on a target that is clearly beyond any plausible contact is movement; an equipped ranged weapon may legitimately attack the same distant target.

#### PC controller adapter (0.3.3 input/interface revision)

Xbox-style gamepads issue semantic actions directly, not touch gestures or virtual
mouse events. Left-stick movement chains the same short commitments; right-stick
aiming alone spends no simulation time. RT is a live weapon hold (release ends
continuations or fires the Bow), B is directional defense and RB is weapon art.
Melee, defense, Advance, Vault and Windstep use movement/facing, never stale ranged
aim. Bow and directional spells use the full analog right-stick heading; magnitude
does not set distance. RS click cycles visible ranged targets for Bow/Mage; manual
aim clears the selection. Placed spells and Sapper open an explicit ground marker:
RS translates it at proportional speed, release holds it, A uses it and B cancels.
Choosing a location does not spend simulation time or Energy; authored range and
placement legality remain authoritative. Trapper remains directional at its fixed reach.
The touch ability/item layout is retained with illustrated slot badges. Holding LB
reveals direct shortcuts on those same slots; it is not a select-then-Y menu.

The adapter owns only input/presentation state. Combat costs, cooldowns, geometry,
commitment and legality remain in RunState. It supplies a 0.22-second fresh-button
buffer at action boundaries, not cancellation or a durable queued command. UI
navigation never advances simulation. Opening a menu releases holds and lets an
already committed action finish before save/quit becomes available. Closing a menu,
focus loss or disconnection cannot replay a held movement/attack: neutral controls
are required before further combat. Keyboard and touch remain independent adapters.
Connecting a PC gamepad displays the controller interface without requiring a first
press; neutral-on-connect prevents accidental movement. Illustrated button prompts
always retain action text and tap/hold/release distinctions. The complete guide is
available through Menu; opening it is presentation-only, not a combat action.
Full bindings and test evidence: [controller-controls.md](controller-controls.md).

Fast and slow actors use identical controls and move the same distance per step. A fast actor completes that distance in less world time, allowing fewer enemy actions during the movement.

Heavy weapons do not reduce ordinary movement by default. Their encumbrance is expressed through mobile defensive techniques and guard handling.

## 2. Universal actor attributes

Every player and enemy uses the same visible attribute vocabulary.

### 2.1 Health

Health determines how much health damage the actor can survive. Maximum-health improvements change the underlying health scale directly.

### 2.2 Strength

Strength is a visible universal attribute. It contributes a deterministic actor-level modifier to physical health damage:

```text
physical strike damage =
    technique base damage
    + actor Strength contribution
    + explicit modifiers
```

This is not Dark Souls-style weapon scaling:

- weapons do not have letter-grade attribute scaling;
- Strength does not normally restrict weapon categories;
- the actor's Strength contribution is general physical power;
- weapon tracks improve authored weapon techniques rather than a scaling grade.

A multi-contact technique receives the Strength contribution once in its strike damage budget and distributes that budget across its contacts. It does not add the complete Strength bonus to every knife contact. Distinct stages of a sword combo are distinct strikes and can each receive the contribution.

For the initial scaled-health implementation, use the deliberately simple provisional contribution:

```text
actor Strength contribution = actor Strength
```

Consequently, a one-contact technique with base damage 2 performed at Strength 4 deals 6 physical damage before Defense and explicit modifiers. This remains a playtest formula rather than a permanent balance commitment.

Strength does not automatically change posture damage, status buildup, reach, speed, hyperarmor, or push distance. A specific track may create one of those interactions explicitly.

### 2.3 Defense

Defense is visible universal physical protection:

```text
effective Defense =
    actor base Defense
    + equipment contribution
    + active ability contribution
```

Defense mitigates physical health damage. It does not ordinarily reduce posture damage, condition buildup, Poison or Burning ticks, Sleep duration, Frenzy, or knockback.

The exact mitigation curve will be selected during the health-scale implementation. All multiplicative mitigation and vulnerability effects should combine before the result is rounded once.

### 2.4 Speed

Speed determines personal tempo as defined above. Permanent Speed increases are powerful and should be comparatively scarce. Ordinary improvements are expected to be small, with approximately 3% tempo per point as the starting balance.

### 2.5 Stealth

Stealth reduces the effective noise produced by the actor's actions and makes the actor more difficult to perceive through concealment rules. It does not guarantee invisibility.

### 2.6 Awareness

Awareness improves detection of noise, concealed actors, hidden traps, and secret geography. It does not grant hit chance or direct combat damage.

### 2.7 Resolve

Resolve governs:

- maximum posture;
- posture recovery;
- the actor-level stability available to actions that can express hyperarmor.

Resolve is not direct damage reduction and does not automatically make every action uninterruptible.

### 2.8 Resistance

Resistance is a visible universal condition-resistance attribute. It increases the buildup threshold required to trigger harmful conditions.

Each actor may additionally carry condition-specific modifiers or explicit immunities. These are profile properties rather than separate visible stats for Poison, Frost, Sleep, and every other condition.

Resistance affects buildup threshold only. It does not also reduce a condition's duration or damage after that condition triggers.

### 2.9 Intelligence and Faith

Intelligence and Faith remain universal actor attributes, associated respectively with spellcasting and prayers. Faith's exact effect remains deferred until prayer-bearing classes and corresponding enemies are designed.

Intelligence reduces spell Energy cost and does nothing else. At the universal baseline of `5`, a spell costs its full authored price. Points `6`–`10` each multiply the remaining cost by `0.91`, points `11`–`15` by `0.94`, and points above `15` by `0.97`. These are soft caps, not a maximum or a floor: Circle and future equipment gains continue to count. Intelligence below `5` never adds a surcharge. Spell prices bypass the physical-action Energy multiplier, so their authored values, UI prices and progression math share one owner.

This is a long-term efficiency curve, not a power curve. Intelligence does not increase spell damage, condition magnitude, range, cast speed or physical-weapon efficiency. Those properties remain authored by the individual spell, condition, technique or track.

Neither attribute modifies ordinary physical weapon damage by default.

## 3. Health and damage scale

Waystone should increase its health-unit scale by approximately five times before the roster expands substantially.

The migration reference is:

| Prototype value | Initial scaled equivalent |
|---:|---:|
| 20 player health | 100 |
| 2 sword damage | 10 |
| 5 potion healing | 25 |
| +3 maximum health | +15 |
| 4 heavy damage | 20 |

These are migration equivalents, not permanent balance mandates. After conversion, values may be adjusted individually rather than remaining multiples of five.

Scale:

- maximum and current health;
- direct health damage;
- healing;
- condition and environmental health damage;
- health costs;
- health upgrades;
- Blood healing when that system is designed;
- health-dependent AI and achievement thresholds.

Do not scale:

- attributes;
- posture;
- status buildup;
- cooldowns;
- movement and reach;
- XP or upgrade levels.

The implementation must separate any current logic that derives posture damage, hit-reaction duration, or block behavior directly from the old small health-damage number. Every attack should define health and posture effects explicitly.

## 4. Damage-event language

Each resolved damage event carries independent properties instead of being forced into one monolithic damage type.

### 4.1 Health and posture

Health damage and posture damage are separate values. A technique may deal one without the other.

- Defense mitigates physical health damage.
- Resolve supplies posture capacity.
- guard profiles modify posture received while blocking.

### 4.2 Direct and ongoing damage

Direct damage comes from a discrete contact such as a melee strike, projectile impact, explosion, or immediate trap impact. It can interact with Dodge, Block, Endure, Parry, hit reaction, hyperarmor, unaware damage, Sleep waking, and Frost vulnerability.

Ongoing damage comes from an already-triggered condition or persistent exposure, such as Poison or Burning. It does not ordinarily interrupt, deal posture damage, wake Sleep, receive unaware bonuses, receive Frost's direct-attack vulnerability, or get blocked after the condition has triggered.

### 4.3 Damage channel

Damage events can carry a channel such as Physical, Fire, Frost, or a future element. Only Physical needs a complete formula before spellcaster design. A poisoned physical knife can deal Physical health damage and Poison buildup in the same contact.

### 4.4 Delivery

Damage events identify delivery such as:

- melee contact;
- projectile;
- area or explosion;
- trap;
- condition;
- environment.

The delivery determines possible defensive interactions independently of the damage channel.

### 4.5 Exceptional tags

Rare effects may explicitly ignore Defense, bypass Block, suppress interruption, enable friendly fire, or count as a self-inflicted cost. These remain exceptional tags rather than new universal damage categories.

### 4.6 Effect frequency

Authored effects state whether they occur:

- per contact;
- per target per action;
- per action;
- on interruption;
- on posture break;
- on clean evade;
- on kill.

This is especially important for multi-contact weapons, broad attacks, and conditions.

### 4.7 Direct physical hit order

The target resolution order is:

1. confirm world-space geometric contact;
2. resolve Dodge, Block, Parry, or Endure;
3. calculate technique damage, Strength contribution, and explicit modifiers;
4. combine Defense, guard leakage, Endure, vulnerability, and other health modifiers;
5. round once;
6. apply health damage;
7. apply posture damage separately;
8. resolve action stability, interruption, or posture break;
9. apply buildup and contact effects.

## 5. Weapon configurations

There is no player-facing main-hand/off-hand slot system.

The active combat configuration consists of:

- one equipped weapon category;
- one equipped defensive technique.

A weapon category represents its complete fighting configuration, whether that presentation contains one sword, two knives, two axes, a spear, a bow, or a zweihander.

A shield is not ordinary independent loot. Block is the learned defensive technique; a shield is its physical expression when the configuration permits one. A dual-wield or two-handed configuration instead guards with its weapon or weapons.

Each weapon defines:

- attack profile: technique, sequence, geometry, damage, posture, and timing;
- guard profile: health leakage, posture modifier, guard recovery, arc, turn modifier, and animation;
- encumbrance: modification to mobile defensive techniques.

Weapon modifiers remain sparse and qualitative in ordinary inspection. Examples include `strong guard` and `cumbersome dodge`.

Heavy encumbrance should initially lengthen Dodge recovery without changing i-frames. Extremely heavy exceptions may also shorten travel modestly. A weapon should not simultaneously cripple distance, movement speed, recovery, and i-frames.

A late second-loadout feature stores two complete trained weapon configurations. It does not expose hand slots.

## 6. Weapon proficiency and category switching

Weapon-track nodes are completely category-specific. There are no generic nodes such as “all weapons deal more damage.”

Every weapon category has five proficiency positions so cross-category proficiency remains legible, but each category authors entirely different content.

Let `X` be the highest Weapon proficiency the character has achieved during the run. A newly trained category begins at:

```text
max(0, X - 1)
```

The player immediately selects the new category's weapon-specific nodes through that granted proficiency. The next ordinary Weapon investment brings it level with the previous highest proficiency instead of advancing the old weapon further.

Each trained category remembers:

- its proficiency;
- permanent art choice;
- permanent node decisions;
- currently selected configuration.

Returning to a trained category restores its recorded decisions. Switching cannot reroll a permanent Weapon Art.

### 6.1 Expedition and Endless

Expedition may permit immediate category retraining outside active combat for pacing reasons. The discovery should ordinarily be a procedurally placed weapon master or equivalent teaching encounter rather than an unexplained loose weapon.

The interaction:

1. previews the category and complete visible track;
2. confirms the switch;
3. grants `X - 1` proficiency;
4. allows immediate weapon-specific choices;
5. shows a brief, skippable training transition;
6. resumes with the new configuration.

The selection interface freezes simulation. Confirmed physical training may advance a modest fixed amount of world time without exposing the player to a hidden combat-menu attack.

Endless can use the same rule unless later pacing gives it a reason not to.

### 6.2 Campaign

Campaign category retraining normally occurs at a Waystone, trainer, or appropriate safe location. The persistent world can support authored masters and training sites without making Expedition depend on finding one later.

### 6.3 Second loadout

Before the late second-loadout unlock, one trained configuration is active. After the unlock, two trained configurations can switch in the field. Each preserves its own permanent weapon-specific choices.

## 7. Defensive techniques

The general character-sheet category is **Defense**, not Evasion, because its techniques include Dodge, Block, Endure, and future Parry.

### 7.1 Dodge

Dodge combines quick directional movement with a brief true i-frame window.

- Physical displacement should be fast enough to escape attack geometry without relying exclusively on i-frames.
- I-frames permit committed close-range evasions through attacks rather than forcing every Dodge away from contact.
- A clean evade occurs only when hostile attack geometry actually crosses the actor during the i-frame window.
- Recovery rules use the established Dodge cooldown. Energy rules instead pay a Dodge Energy cost and express the commitment through a brief vulnerable recovery.
- Weapon encumbrance may alter recovery and exceptional travel properties, but does not normally alter i-frame proportion.

Potential authored forms include a shorter, quicker Sidestep and a longer Roll with greater recovery. Both must be improvements over an intentionally modest default Dodge.

### 7.2 Block

Block is a sustained directional guard rather than a fixed-duration cooldown skill.

- Raising the guard has startup.
- The guard remains active while the player maintains the guarding input.
- Time continues while the guard is held.
- Every intercepted hit deals guard-adjusted posture damage.
- Posture does not recover while guarding.
- Releasing Block incurs a short lowering recovery.
- Block has no cooldown.
- Reaching zero posture causes a substantial guard-break stagger.

The finger or pointer sets a desired guard direction while held. The shield or weapon rotates toward that direction at a finite world-time rate rather than snapping instantly. Actual current orientation determines whether a hit is blocked.

Guard rotation uses:

```text
base Block turn rate
× actor Speed modifier
× weapon guard modifier
```

A short input-continuity allowance may smooth accidental touch lifts, but it must not create a separate tactical advantage.

### 7.3 Endure

Endure is a short predictive defense that converts an incoming threat into health cost and offensive momentum.

- It takes `ceil(incoming health damage × 0.5)` after applicable mitigation is combined.
- It takes no posture damage from the caught hit.
- The caught hit does not interrupt the actor.
- The actor gains a temporary Strength benefit only after actually enduring a hit.
- Endure remains capable of causing death.
- It uses a substantial cooldown, beginning after the resulting Strength effect ends.

The 50% value is the starting playtest value. If Endure is not a legitimate primary defense, improve its reduction directly rather than hiding weakness behind elaborate secondary rewards.

### 7.4 Parry

Parry is a future Defense technique with a very short active window. A successful Parry prevents the incoming contact, interrupts the attacker, and deals substantial posture damage. In Waystone it tests prediction and commitment at a frozen decision point rather than reflex dexterity.

### 7.5 Vault

Vault is planned as an Acrobat ability rather than the equipped Defense technique. It nevertheless uses the universal i-frame and clean-evade events, allowing Acrobat to have a soft affinity with Dodge without requiring Dodge.

### 7.6 Universal defense events

Shared events include:

- `cleanly_evaded`;
- `successfully_blocked`;
- `successfully_parried`;
- `endured_hit`.

Tracks react to these events rather than hardcoding themselves to a particular button.

## 8. Posture, interruption, and hyperarmor

### 8.1 Contact outcomes

When an unavoided attack connects:

1. apply health damage;
2. apply posture damage;
3. if posture reaches zero, apply posture break;
4. otherwise test the current action's hyperarmor capacity;
5. if insufficient, cancel the action and apply a short hit reaction.

An ordinary landed hit interrupts an unprotected action before a full posture break. This preserves the advantage of landing the first strike. Posture break is the larger reward that creates an extended punish window.

### 8.2 Posture

Every actor has maximum posture, current posture, a world-time recovery delay, and a Resolve-influenced recovery rate.

- Posture begins recovering after pressure stops.
- It cannot recover while Block is raised.
- It cannot recover while time is frozen.
- A completed posture-break stagger restores posture so the victim cannot be immediately posture-locked again.
- Hits during an existing break can deal health damage but cannot restart or extend the break.

Fast enemies generally have lower posture. Heavy knights, Guardians, and bosses generally have more.

### 8.3 Hit reaction

A normal hit reaction:

- cancels the current unprotected action;
- is visibly distinct from a posture break;
- is brief;
- cannot be refreshed while already occurring.

Subsequent contacts may continue dealing damage without extending the reaction.

### 8.4 Posture break

A posture break:

- cancels ordinary actions regardless of normal hyperarmor;
- creates a substantially longer vulnerability;
- cannot be refreshed while active;
- guarantees a usable opening after the attacker's current committed action finishes.

The opening must not expire entirely during the recovery of the strike that caused it.

### 8.5 Actor and action stability

Hyperarmor combines actor stability with action stability:

```text
action hyperarmor capacity =
    Resolve-derived actor stability
    × action stability rating
    + class, track, equipment, and temporary modifiers
```

Action stability ratings may be described internally as Exposed, Light, Standard, Committed, or Braced. They determine how much actor stability an action can express.

The same Standard sword attack therefore has more hyperarmor when performed by a Guardian than by an Acrobat. A delicate action uses less of that difference; a deliberately grounded heavy action uses more.

Incoming posture damage reduces both the action's remaining interruption resistance and the actor's persistent posture. Exhausting action hyperarmor causes an ordinary interruption; exhausting posture causes the longer break.

Resolve improves stability that an action can express. It does not add a full unconditional hyperarmor value to every action. This prevents high Resolve from making healing, delicate casting, and recovery universally safe.

Exceptional body types may have an internal stability modifier, but Waystone does not need a second routine upgradeable Hyperarmor stat.

### 8.6 Knockback

Knockback remains separate:

- posture governs interruption and break;
- actor mass and attack force govern displacement;
- an action may resist interruption without resisting push;
- explicitly grounded actions can resist both.

## 9. Awareness, noise, and Stealth

### 9.1 Knowledge states

An observer can be:

- **Unaware:** no reason to believe the target is nearby;
- **Searching:** has a disturbance or last-known position but not the target's current position;
- **Engaged:** has valid line of sight and knows the current position.

Detection does not progress while world time is frozen.

### 9.2 Probabilistic noise

Every committed action emits an authored noise event. Stealth reduces effective noise; action type, distance, walls, terrain, and observer Awareness modify the chance of detection.

A nearby observer performs a seeded random check once per meaningful action event, not every simulation tick. A success without line of sight creates Searching and records the approximate action location.

Examples:

- Wait is silent or nearly silent.
- movement noise depends on action and Stealth;
- Dodge is relatively loud;
- light strikes are moderate;
- heavy impacts, breaking objects, and major spells are loud.

Repeated actions create repeated risk. RNG state must be saved so seeds and bug reports remain reproducible.

In the 0.3.0 expedition, suspend first finishes the player's existing commitment,
then publishes one atomic snapshot. Loading does not cancel enemy tells or recovery,
clear exhaustion or reset the Energy regeneration delay. Boss phase, pending hazards,
stable IDs, stock, equipment and consumable counts survive; resuming is not restoration.
Legacy save migrations retain their historical compatibility rules.

### 9.3 Line of sight

Valid line of sight creates Engaged and exact current knowledge. Hearing alone does not.

Enemies do not share a global hive mind:

- direct sight gives exact engagement;
- witnessing an ally's attack may give exact knowledge if the attacker is visible;
- hearing combat creates Searching at the sound or attack origin;
- ranged attacks can reveal their firing origin without magically tracking the shooter afterward.

### 9.4 Unaware attacks

An unaware hit lands while the target does not know the attacker's current position. Searching the wrong location can still qualify.

The starting universal multiplier is approximately `1.5×`, subject to playtesting.

- Rogue and weapon-specific bonuses add into the final multiplier rather than multiplying one another.
- Only the first damaging contact of an action receives the unaware bonus.
- That contact reveals the attacker to the victim.
- A long multi-contact knife sequence cannot multiply every contact.
- Eligibility is checked immediately before contact; crossing valid line of sight before impact removes the bonus unless an active Stealth effect suppresses detection.

### 9.5 Stealth abilities and concealed enemies

Ordinary stealthy bandits should use high Stealth, quiet actions, cover-seeking behavior, and the universal perception system rather than a bespoke invisibility ability.

An explicit concealment ability is reserved for exceptional effects such as Rogue Stealth, magical invisibility, or terrain-specific camouflage.

Rogue Stealth is expected to:

- begin as an ability usable while no enemy knows the Rogue's current position;
- suppress ordinary visual acquisition for limited advancing world time;
- end on attack, damage, or direct contact;
- later upgrade to break existing engagement and leave enemies Searching the last-known position.

No enemy may deliver a completely unreadable invisible attack. Hostile commitment must become perceptible before active contact.

### 9.6 Traps and secrets

Traps carry concealment determined by trap type, creator abilities, and terrain. Player and enemy Awareness checks use the same system against player- and enemy-created traps.

Awareness also reveals secret passages and environmental clues from farther away. Low-Awareness characters can still discover appropriate secrets through very close examination unless the content explicitly requires otherwise.

## 10. Conditions and buildup

### 10.1 Thresholds

Hostile conditions generally accumulate buildup. Each condition has a base threshold:

```text
final threshold =
    condition base threshold
    × universal Resistance modifier
    × condition-specific actor modifier
```

Buildup and condition timers advance only in world time. Buildup can decay after pressure stops. Players, enemies, traps, consumables, and spells use the same system.

Specific immunities remain exceptional actor properties. An undead actor can be immune to Sleep or Poison without creating a visible resistance stat for every condition.

### 10.2 Buildup conditions

The initial condition vocabulary is:

- **Laceration:** buildup culminates in immediate fixed damage, then resets.
- **Poison:** buildup triggers sustained damage over world time.
- **Sleep:** completely immobilizes the actor for a fixed world-time duration. Each direct damaging hit reduces the remaining duration by a fixed amount; ongoing damage does not. The first direct hit reveals its attacker even if the victim remains immobilized.
- **Frost:** reduces personal tempo and increases vulnerability to direct attacks. Its bonus damage should initially apply once per attack action rather than once per contact, preventing automatic dominance by high-contact weapons.
- **Burning:** shorter and more urgent ongoing health pressure than Poison.
- **Frenzy:** disrupts faction targeting for AI and corrupts player commands.

Sleep is a forced advancing state for the player, like stagger; it cannot freeze forever merely because the player cannot act.

Frenzied enemies can physically attack and damage former allies through the same geometry. Frenzy does not autonomously advance player time without input. Instead it can redirect movement, misdirect offensive skills or Defense, or replace an attempted action with a basic strike in a random direction. Potions and inventory use remain reliable; Wait remains reliable but advances enemy time.

### 10.3 Direct states

Not every timed effect uses buildup. Self-buffs and guaranteed ability states apply directly, including:

- Rally;
- Strength;
- Stealth;
- Counterstep;
- action-granted hyperarmor.

A hostile ability may exceptionally apply a condition directly, but buildup is the ordinary resisted path.

### 10.4 Blood

Blood drops are not a condition. They belong to a later death-reward and battlefield-pickup framework, designed with Berserker.

## 11. Character and track architecture

### 11.1 Sheet

An ordinary character has five tracks:

1. Weapon;
2. Defense;
3. Temperament;
4. Main Class;
5. Subclass.

A late Adopted Track can add a sixth position in sufficiently long runs.

Main Class determines the common class identity and main ability. Subclass determines the secondary class identity and ability. For example, all Rogues share the Rogue main track while Acrobat and Sharpshooter supply different subclass tracks.

### 11.2 Track content

A track can contain:

- active abilities;
- changes to regular attacks or combos;
- passive properties;
- compound or ordinary stat improvements;
- equipment interactions;
- condition interactions;
- mechanical permissions;
- authored capstones.

A track is not defined solely by its active skill. It does not need a binary branch, equal node count, or generic sequence of choice, statistical improvement, skill upgrade, and capstone.

Linear tracks, repeated visible package choices, one-of-three commitments, or rare completely visible branches are all valid when the subject warrants them.

All future nodes and permanent consequences remain visible so the player can plan a build.

### 11.3 Starting identity

At run start, a character already has:

- a basic weapon attack;
- a basic defensive technique;
- a main-class ability;
- a subclass ability.

Tracks improve and broaden identity rather than withholding it entirely.

The Weapon Art is the primary exception. The first Weapon-track purchase presents a permanent choice between the category's two arts. The unchosen art is not later unlocked during that run.

### 11.4 Active controls

The ordinary HUD supports:

- Defense;
- Weapon Art;
- main-class ability;
- subclass ability;
- late adopted ability.

Regular attacks and movement come from the world field. Consumables, including rejuvenation potions, occupy a separate belt. Wait is a separate smaller button above the belt. A late weapon-loadout switch receives its own compact control.

A Mage spellbook may exceptionally open a palette from one slot. Palettes should not become the default solution for every class.

### 11.5 Level introduction

Characters begin at level 1.

- First level-up, reaching level 2: Weapon, Defense, and Temperament are introduced.
- Second level-up, reaching level 3: Main Class and Subclass both become available.
- Third level-up, reaching level 4: Weapon's second opportunity remains available and the second Temperament purchase becomes available.

The player ordinarily sees no more than four available upgrade destinations at once and only rarely five. A normal Expedition should allow at least one chosen track to reach completion by approximately level 9 or 10.

Level-up presents the actual next upgrades directly in the character sheet, usually
three options and occasionally four or five. Each option exposes the upgrade and
its consequences before the player selects it.

### 11.6 Gating positions and authored track length

Every ordinary authored track family has five potential gating positions, even when a particular track deliberately leaves positions empty. Level 10 remains a universal final opportunity.

Weapon is the structural exception in the other direction: every weapon category must contain exactly five proficiency ranks so that cross-category proficiency transfer remains coherent. Defense, Main Class, and Subclass tracks use only as many of their potential positions as their content warrants.

The provisional family schedules are:

| Track | Potential minimum levels |
|---|---|
| Weapon | 2, 4, 6, 8, 10 |
| Defense | 2, 5, 7, 9, 10 |
| Temperament | First purchase at 2, second no earlier than 4, then sequentially subject to its global purchase cap |
| Main Class | 3, 5, 7, 9, 10 |
| Subclass | 3, 6, 8, 9, 10 |

These schedules are subject to a choice-count audit after concrete tracks exist. They are gating opportunities, not a command that every track contain five nodes.

Temperament is not a conventional node sequence. Its first purchase is available at level 2 and its second at level 4; later purchases follow sequentially until the global four-investment cap is reached. Its two or three compound stat packages remain simultaneously visible, along with `X/4`. Temperaments share this four-purchase limit so their opportunity cost remains comparable; their identity comes from package content rather than different track lengths. The level-4 pause prevents Temperament II from competing with the newly shared Main Class/Subclass opening at level 3.

### 11.7 Permanent choices

Track choices are permanent for the run.

- The unchosen Weapon Art is not a later unlock.
- Future consequences remain visible before commitment.
- Branch-dependent future nodes are rare.
- Choices should change play rather than select between two nearly identical numerical bonuses.

### 11.8 Adopted Track

A late discovery may grant an Adopted Track, commonly a specialized subclass-style discipline associated with another class.

Because it appears late, the player receives immediate catch-up investment rather than beginning from rank zero. Exact timing and catch-up count will be designed with the first concrete adopted discipline.

If the track supplies an active ability, it uses the fifth active-action position.

### 11.9 Wanderer

Wanderer builds the same five-track sheet through forced choices among weapon, Defense, main identity, and secondary identity. The choices occur during the run or its opening rather than creating a separate progression system.

Achievements expand the pool of options available to those forced choices. The
intended reward is access to more ways to construct a character.

The current leaning is forced construction in both Expedition and Campaign, with collection sites potentially affecting presentation in Campaign. Exact acquisition cadence remains deferred.

## 12. Mode-specific boundaries

- Expedition is forward-directed and permadeath. The approved 0.3.0 prototype has three standalone biomes and a single-use restorative Waystone after each boss; these neither respawn enemies nor create death checkpoints. Departed biomes cannot be revisited. This supersedes the previous no-Waystone rule.
- Campaign can use Waystones, persistent trainers, layered regions, death recovery, and anchored knowledge.
- Leveling remains available outside active combat in Expedition.
- Campaign leveling and major retraining occur at Waystones or appropriate safe sites.
- Differences in access points do not create different actor, combat, track, or proficiency rules.

## 13. Explicitly deferred decisions

The following are not accidental omissions:

- Faith's formula and prayer economy;
- elemental damage and elemental resistance details;
- exact condition buildup, duration, and damage values;
- Blood-drop chance, healing, and low-health scaling;
- final physical Defense mitigation curve;
- final Strength-to-damage breakpoints;
- equipment loot and armor-slot behavior;
- exact adopted-track acquisition and catch-up amount;
- final second-loadout timing;
- exact Wanderer acquisition cadence;
- final balance of Block guard profiles and weapon encumbrance;
- final UI presentation and art.

These should be decided with their first concrete classes or content rather than abstractly.

## 14. First concrete consumer: Rogue · Acrobat

Rogue · Acrobat is the first complete character authored against this framework. Its numerical values are initial playtest targets using the scaled health and damage language in section 3. Its structural separation tests are mandatory:

- Knife must remain useful without Rogue;
- Rogue must remain useful with every weapon category;
- Acrobat must remain useful with Block, Endure, Parry, or another Defense instead of Dodge;
- the strongest synergies should emerge from shared events rather than explicit class-lock checks.

### 14.1 Starting sheet

| Position | Starting identity |
|---|---|
| Weapon | Single Knife; Weapon Art selected at the first Knife purchase |
| Defense | Basic Dodge |
| Temperament | Finesse |
| Main Class | Rogue with Stealth |
| Subclass | Acrobat with Vault |

The provisional base attributes are:

| Attribute | Value |
|---|---:|
| Health | 80 |
| Strength | 4 |
| Defense | 2 |
| Speed | 7 |
| Stealth | 7 |
| Awareness | 6 |
| Resolve | 3 |
| Resistance | 4 |
| Intelligence | 4 |
| Faith | 2 |

Faith remains provisional because its system is deferred. Intelligence `4` is intentionally below the spell-cost baseline: non-casters may possess ordinary intelligence without receiving a hidden penalty, while Mage begins above the baseline. The intended physical identity is approximately 20% less health than the scaled Warrior, low protection and action stability, and substantially greater Speed and Stealth.

### 14.2 Knife attack language

Single Knife uses four fast, compact cuts:

- four distinct one-contact strikes;
- approximately 2.3 authored seconds for a complete sequence before personal tempo;
- approximately 92 reach;
- compact alternating arcs of approximately 65–80 degrees;
- technique base damage 2, delivering approximately 6 damage per contact at starting Strength;
- approximately 1 posture damage per contact;
- no thrust, lunge, privileged finisher, or unusually committed final strike.

Twin Knives use six faster alternating cuts:

- six distinct one-contact strikes;
- approximately 2.65 authored seconds for a complete sequence before personal tempo;
- approximately 88–92 reach;
- technique base damage 1, delivering approximately 5 damage per contact at starting Strength;
- less posture damage per contact than Single Knife;
- a longer complete commitment but shorter individual commitments.

Moving the original held attack touch does not redirect either sequence. Knife introduces no new aiming rule. Releasing between cuts ends the sequence after the current cut resolves.

### 14.3 Knife Weapon Art

The first Knife purchase permanently selects one Art.

**Execution** retains Single Knife and grants a close-range execution cut:

- no added reach or forward lunge;
- approximately 1.05 seconds of total authored commitment;
- technique base damage 8, delivering approximately 12 damage at starting Strength;
- approximately 3 posture damage;
- 5.5 personal-time seconds of cooldown;
- adds `+1.0` to the unaware multiplier.

With the universal `1.5x` unaware modifier and Rogue's Ambush, an unaware Rogue Execution therefore begins near `3x` damage. It remains usable but inefficient in open combat.

**Twin Fang** equips a second knife and changes the regular sequence to six cuts. Its active Art is a two-contact crossing cut:

- approximately 0.85 seconds of authored commitment;
- approximately 12 total damage at starting Strength, with the one Strength contribution divided across the two contacts;
- approximately 4.2 personal-time seconds of cooldown;
- the inferior dual-wield guard profile when paired with Block.

### 14.4 Knife proficiency

Knife uses all five Weapon ranks:

| Rank | Minimum level | Upgrade |
|---:|---:|---|
| I | 2 | **Weapon Art:** permanently choose Execution or Twin Fang. |
| II | 4 | **Honed Edges:** every Knife contact deals exactly +1 health damage. |
| III | 6 | **Light Hands:** Knife startup, continuation, and recovery resolve approximately 8% faster. |
| IV | 8 | **Relentless Cuts:** consecutive contacts in one uninterrupted sequence gain +1, then +2, then +3 damage; +3 persists until the sequence stops, misses, or is interrupted. |
| V | 10 | **Ceaseless Cuts:** maintained attack input flows from the last regular cut directly back into the first without full combo recovery. |

Ceaseless Cuts is the culmination rather than a routine Art refinement. Single Knife cycles its four-cut pattern and Twin Knives cycle their six-cut pattern. The player can still release between any two contacts.

### 14.5 Dodge

Rogue · Acrobat begins with the already authored three-purchase Dodge track. Acrobat does not replace or rewrite it. Recovery and Energy profiles deliberately retain distinct timing economies for A/B testing.

| Purchase | Minimum level | Upgrade |
|---:|---:|---|
| I | 2 | **Practised Footwork:** improves the baseline Dodge. Under Recovery rules, recovery falls from 0.66 to 0.60 authored seconds and cooldown from 4.0 to 3.6 personal-time seconds. Under Energy rules, travel increases from 150 to 168 units, i-frames from 0.24 to 0.30 seconds, and vulnerable recovery falls from 0.24 to 0.20 seconds. |
| II | 5 | **Evasive Form:** permanently choose Sidestep or Long Roll. |
| III | 9 | **Perfect Form:** clean Sidestep primes Counterstep; clean Long Roll restores 2 seconds of Dodge cooldown. |

Under Recovery rules, Sidestep covers the basic 168-unit distance more quickly with a 2.8-second cooldown, while Long Roll covers approximately 231 units with a 3.6-second cooldown. Under Energy rules, both cost 18 Energy: Sidestep retains 168-unit travel and a 0.30-second i-frame window while reducing vulnerable recovery to 0.12 seconds; Long Roll travels 231 units with 0.35 seconds of i-frames and 0.20 seconds of vulnerable recovery. Perfect Form responds only to the corresponding Dodge action; it does not trigger from ordinary movement or Vault.

### 14.6 Finesse Temperament

Finesse permits four investments from level 2. Each investment permanently selects one of two packages:

- **Fleetness:** `+1 Speed` and `+5 maximum health`;
- **Subtlety:** `+1 Stealth` and `+1 Awareness`.

The sheet shows both packages directly and records `X/4`. Repeating Fleetness four times is initially permitted; its substantial opportunity cost should be tested before adding a package-specific cap.

### 14.7 Stealth

Stealth is the Rogue's starting main ability:

- approximately 0.4 seconds of activation commitment;
- 5 world-time seconds of concealment;
- 12 personal-time seconds of cooldown beginning when concealment ends;
- before Vanish, activation requires that no enemy hold the player's exact current location;
- enemies cannot visually acquire the concealed Rogue, although noise can make them Search an approximate location;
- damaging contact, receiving direct damage, or releasing an overtly hostile consumable ends concealment;
- movement, defensive actions, Vault, and quiet interactions do not end it.

Frozen decision time does not consume Stealth duration.

### 14.8 Rogue track

Rogue deliberately contains five distinct purchases because it has five worthwhile functions:

| Rank | Minimum level | Upgrade |
|---:|---:|---|
| I | 3 | **Ambush:** raises the universal unaware modifier from `1.5x` to `2x` with every weapon. |
| II | 5 | **Rogue's Training:** permanently choose Shadow Training or Fleet Training. |
| III | 7 | **Clean Work:** an unaware victim cannot broadcast an alert until the current attack action resolves; if it dies during that action, its alarm and death noise are suppressed. |
| IV | 9 | **Vanish:** Stealth can be activated while Engaged; enemies lose the exact position and Search around the last known location. |
| V | 10 | **Ghost:** breaking Stealth begins a brief assassination window; killing the victim without another direct witness restores Stealth at full duration. |

Rogue's Training offers:

- **Shadow Training:** `+1 Speed` and `+2 Stealth`;
- **Fleet Training:** `+2 Speed`.

This choice is permanent but does not branch or change later Rogue nodes.

Clean Work suppresses the victim's alarm and death noise, not ordinary weapon-release noise or direct visual witnesses. During Ghost's approximately two-second assassination window, the victim and direct witnesses may see and fight the Rogue, but the victim does not propagate an alert. Failure begins the normal Stealth cooldown.

The track must work across all three planned Rogue subclasses:

- Acrobat repositions and finishes isolated targets;
- Sharpshooter kills before an alert propagates;
- Cutthroat has time for multiple fast contacts instead of requiring the first contact to kill.

### 14.9 Vault

Vault is Acrobat's starting subclass ability and exists independently of the equipped Defense:

- tap Vault, then choose a direction using the same directional interaction as Dodge;
- approximately 198 units of travel;
- approximately 0.54 authored seconds of total action time;
- i-frames during travel, not landing recovery;
- passes through actor bodies but not walls, gates, gaps, or other solid terrain;
- ends facing the travel direction;
- deals no damage and does not automatically attack;
- obstruction truncates travel and still consumes the ability;
- approximately 0.2 seconds of landing recovery;
- 8 personal-time seconds of cooldown beginning on landing.

### 14.10 Acrobat track

Acrobat contains four purchases rather than filling every potential Subclass position:

| Rank | Minimum level | Upgrade |
|---:|---:|---|
| I | 4 | **Soft Landing:** Vault landing recovery falls from approximately 0.2 to 0.1 seconds; held movement begins when recovery ends. |
| II | 6 | **Elastic Moment:** adds approximately 0.06 seconds to every genuine i-frame window the actor possesses without creating i-frames on other actions. |
| III | 8 | **Turnabout:** a clean evade empowers the next basic physical attack made within 4 world-time seconds; its first contact gains +8 health and +3 posture damage. |
| IV | 10 | **Encore:** Vault cooldown falls from 8 to 4.8 personal-time seconds. |

Turnabout triggers once per empowered attack, not once per Knife contact. Acrobat consequently has a soft affinity with Dodge while remaining fully functional with Block, Endure, or Parry.

### 14.11 Universal clean evasion

> **Superseded in `0.2.13`, in part.** Source 2 below -- clean-evade credit for
> ordinary movement -- was removed with attack capture. The current event contract is:
> evasion rewards belong to authored defensive techniques. It was also about to
> fire constantly, since capture makes attacks pass close to a retreating player
> by design. Source 1 (genuine i-frames) is unchanged, so Dodge and Vault both
> still raise the event and Acrobat's Turnabout in 14.10 keeps two of its three
> trigger sources. The rest of this section stands.

A clean evade can occur through:

1. hostile attack geometry crossing the actor during genuine i-frames; or
2. voluntary ordinary movement begun after hostile attack commitment narrowly carrying the actor outside the active geometry.

The initial ordinary-movement test requires all of the following:

- the movement began after the hostile action committed;
- the attack misses the actor's actual current body;
- its geometry crosses the actor's recent swept movement trail;
- its final clearance is within a narrow initial margin of approximately 18 world units;
- the event has not already fired for that hostile action.

An attack aimed elsewhere does not qualify simply for passing nearby. Values remain subject to geometric playtesting.

Every clean evade presents a brief cyan-white ring, clear `CLEAN EVADE` text, and a combat-message entry. It adds no artificial slow motion, vibration, or additional pause.

Perfect Form reacts only to clean evasions performed with its equipped Dodge form. Acrobat's Turnabout reacts to every clean-evade source, including ordinary movement and Vault.

### 14.12 Rogue · Acrobat level audit

| Track | Concrete availability |
|---|---|
| Knife | 2, 4, 6, 8, 10 |
| Dodge | 2, 5, 9 |
| Finesse | Four investments available from level 2 |
| Rogue | 3, 5, 7, 9, 10 |
| Acrobat | 3, 6, 8, 10 |

The ordinary route presents three or four upgrade destinations. Five may appear after deliberately leaving several earlier tracks untouched, but should not be the normal level-up experience.

## 15. Second concrete consumer: Rogue · Sharpshooter

Rogue · Sharpshooter validates that Rogue supports a ranged subclass and that Sharpshooter remains useful without Bow. Its separation tests are mandatory:

- Bow must provide complete ordinary ranged combat without Rogue or Sharpshooter;
- Sharpshooter must retain perception, preparation, and precision benefits with a melee weapon;
- Rogue's Stealth, unaware damage, Clean Work, Vanish, and Ghost must work with projectiles without Bow-specific checks;
- aimed consumable and spell projectiles should reuse the same range-tag language as weapon projectiles.

### 15.1 Starting sheet

| Position | Starting identity |
|---|---|
| Weapon | Bow; Weapon Art selected at the first Bow purchase |
| Defense | Basic Dodge |
| Temperament | Patient |
| Main Class | Rogue with Stealth and the track in section 14.8 |
| Subclass | Sharpshooter with Take Aim |

The provisional base attributes are:

| Attribute | Value |
|---|---:|
| Health | 85 |
| Strength | 4 |
| Defense | 2 |
| Speed | 6 |
| Stealth | 7 |
| Awareness | 8 |
| Resolve | 4 |
| Resistance | 4 |
| Intelligence | 4 |
| Faith | 2 |

Compared with Rogue · Acrobat, Sharpshooter is slightly tougher, slower, more aware, and more stable under pressure.

### 15.2 Bow draw, release, and aiming

Bow's regular attack is a projectile shot rather than a contextual melee substitute. Pressing begins a draw; releasing always fires. Accumulated authored draw time continuously determines damage, posture force, projectile velocity, and maximum travel distance.

The internal curve is presented through three readable animation states rather than numerical timing homework:

- **Loose:** low bend, short range, low damage, low velocity, and negligible posture force;
- **Drawn:** useful intermediate performance;
- **Full:** a clear visual and audio state indicating maximum performance.

There is no narrow perfect-release bonus. Holding beyond Full preserves maximum output while time continues to advance, so waiting for a better release position carries risk. A very short release debounce may reject accidental touch noise, but must not make the Bow feel unresponsive.

Initial scaled-health targets are:

| Draw state | Approximate damage at starting Strength | Maximum range | Posture | Total commitment after immediate release |
|---|---:|---:|---:|---|
| Loose | 6 | 220–250 | Minimal | Fast, approximately 0.7 seconds including recovery |
| Drawn | 9 | Approximately 450 | Low | Intermediate |
| Full | 12 | Approximately 650–700 | Approximately 2 | Slow, approximately 1.3 seconds including recovery |

These are calibration points on a continuous curve. Damage does not decay during flight; draw strength determines the projectile at release.

Bow uses the universal gesture classifier:

- an immediate pre-lock drag is movement even if touch began on an enemy;
- a quick attackable-target tap produces the minimum Loose shot;
- holding beyond the attack threshold locks Bow draw;
- touching an enemy supplies a soft target lock while the enemy remains visible;
- after attack lock, dragging adjusts aim and permits manual leading instead of moving the character;
- holding open terrain beyond the attack threshold begins free directional aiming;
- release fires along the current aim direction;
- the arrow never homes or turns after release.

Soft lock follows the visible target at a finite turning rate but does not calculate a perfect intercept. Manual aim can lead lateral movement. If line of sight breaks, target following stops and aim retains its last valid direction.

The character is immobile while drawing. A second press during post-shot recovery may buffer the next draw; continuous hold is not required because release is the firing input.

### 15.2a Isolated additional Commit Shot — 1 November 2026

Status: implemented in the isolated phone correction successor to `e35ffd8`;
combined independent review, build/device verification and Guy's feel acceptance
remain open. This is an additional starting Sharpshooter/Bow action. Ordinary
quick/partial/full hold-and-release, Take Aim, Piercing Shot and Fan Shot remain.

Select **Commit Shot**, then confirm a living visible enemy on the current layer
with clear line of sight. Selection/toggling/cancelling costs no time or Energy;
invalid confirmation explains its refusal and neither moves nor shoots. A valid
confirmation consumes the selection and prepays the ordinary full-shot raw cost
**18** through `RunState._spend_energy`, retaining physical scaling, permitted
overdraw and Recovery accounting. Zero-Energy/exhaustion follows the ordinary
physical-action lock; there is no new requirement to possess the entire price.

The shared Bow draw then completes automatically to 0.90 authored local seconds,
using any earned 0.45 preload, and enters the ordinary full-shot release/recovery.
No hold or release timing is needed. Physical releases cannot fire early, cancel,
discount or repeat it. Ordinary poise, incoming interruption, death and subsequent
exhaustion still apply. The same finite-rate visible-target aim and 12-degree
manual adjustment are retained; target loss ends following and keeps the last
valid aim, with ordinary projectile collision. A fresh touch drag or right-stick
aim during the draw may lead the shot; lifting it cannot end the commitment.

The lead's initial tuning grants **+25% projectile damage**, constructed once as
`roundi(ordinary_full_damage * 1.25)` after existing Strength/rank construction
and before target mitigation. The actual current full base is 13, or 16 at Bow
rank III, plus Strength adjustment; the earlier calibration table above is design
history. No other shot/art gets this bonus. Posture, velocity, range, hit rules,
Quick Nock and full recovery are unchanged. Take Aim and earned full-hit follow-up
use their existing owners. Follow-up consumption now travels with its action and
arrow so a later draw or save/resume cannot reclassify the earlier arrow. Optional
v39 save fields preserve earned preload readiness/consumption; old saves default
false, and existing progression is retained without a schema/version bump.

The bounded descendant of `30c1900` repairs deterministic verification of this
ownership. A projectile-only DETERMINISM descriptor registers the saved raw flag;
the semantic checkpoint resolves the existing `arrow.get(flag, global)` fallback
for friendly full shots. Active Bow draw/release actions resolve the same fallback.
Effective true consumption hashes explicitly; effective false is omitted to retain
genuinely equivalent historical defaults. With global true, an absent field hashes
like explicit true, while explicit false hashes differently. With global false,
absent and explicit false remain equivalent. Inactive non-full/enemy projectile
ownership is omitted. The projection never mutates the action/projectile, changes
save dictionaries or adds rendering state. Real-arrow contact and old-format model
saves exercise all six combinations and action→projectile inheritance. Unchanged
ordinary goldens remain the historical compatibility control. Combat/save logic,
schema version, tuning and earned-perk rules are unchanged.

Controls and information live in [the controller owner](controller-controls.md)
and Character → Combat. Existing menu/suspend policy is preserved: controller
Start shows “Finishing current action” while normal processing serves the complete
paid obligation; it does not cancel the shot. Busy map/Character inputs retain
their ordinary gates. Focus/pause cleanup finishes the current obligation through
the shared executor before saving; actual OS pause is not a promise of background
processing. Expedition still refuses an in-progress save. The existing integrated
Survey mid-obligation save policy retains the prepaid action and consumed preload.
Tests distinguish this from ordinary ready-state progression saves.

See [the cumulative repair ledger](phone-world-repair.md#cumulative-phone-correction--1-november-2026)
for geometry/shop repairs, exact evidence boundaries and the lead-owned delivery.

### 15.3 Projectile range language

Every projectile carries world-space velocity, collision geometry, and maximum travel distance. Reaching maximum distance causes a physical presentation such as an arrow dropping or embedding rather than invisible deletion.

Draw strength sets Bow's base range. Directly aimed projectiles use the shared `aimed_projectile` capability tag, including:

- arrows and bolts;
- throwing knives, darts, and similar consumables;
- lobbed firebombs and other explicitly aimed consumables;
- direct projectile spells;
- future ranged-weapon techniques.

The tag does not include melee reach, self-centered areas, cones, beams, traps, summons, or an explosion's radius after impact. Tapping beyond attainable range launches toward the chosen direction and terminates at the maximum reachable point, so range judgment remains meaningful.

Range modifiers combine additively rather than compounding:

```text
final maximum range =
    base range × (1 + weapon range bonus + Sharpshooter range bonus + other additive bonuses)
```

Increasing range does not automatically increase projectile speed or damage. Longer flight consequently gives targets more opportunity to move.

### 15.4 Bow Weapon Arts

The first Bow purchase permanently selects one Art. Weapon Arts have fixed authored draws rather than reusing regular-shot release scaling.

**Piercing Shot** is a slow line attack:

- approximately 22 damage and 5 posture damage;
- approximately 780 base range;
- fast projectile after release;
- passes through every physically crossed actor;
- approximately 1.5 seconds of commitment;
- approximately 6.5 personal-time seconds of cooldown.

**Fan Shot** releases three independent arrows in a compact cone:

- approximately 6 damage per arrow;
- approximately 380 base range;
- low posture damage;
- approximately 0.9 seconds of commitment;
- approximately 5 personal-time seconds of cooldown;
- independent geometry permits multiple arrows to contact a sufficiently large or close target.

Neither Art depends on Rogue or Sharpshooter.

### 15.5 Bow proficiency

Bow uses all five Weapon ranks:

| Rank | Minimum level | Upgrade |
|---:|---:|---|
| I | 2 | **Weapon Art:** permanently choose Piercing Shot or Fan Shot. |
| II | 4 | **Instinctive Release:** improves the low-draw portion of the continuous curve, raising a Loose shot from approximately 6 to 8 damage and from roughly 250 to 300 maximum range. |
| III | 6 | **Settled Draw:** Full damage rises from approximately 12 to 15 and posture damage from approximately 2 to 3. |
| IV | 8 | **Quick Nock:** post-release recovery and a buffered next draw become approximately 20% faster. |
| V | 10 | **Following Arrow:** a Full shot that hits permits one accelerated follow-up draw when a new press is buffered during recovery; the follow-up cannot enable another accelerated draw. |

Following Arrow creates a deliberate two-shot culmination rather than automatic fire. A miss does not earn the accelerated follow-up.

### 15.6 Dodge

Rogue · Sharpshooter uses the existing three-purchase Dodge track in section 14.5 without modification. It relies on Dodge to recreate firing distance but receives none of Acrobat's universal i-frame or clean-evade improvements.

### 15.7 Patient Temperament

Patient permits four investments from level 2. Each investment permanently selects one package:

- **Observation:** `+1 Awareness` and `+1 Stealth`;
- **Composure:** `+1 Resolve` and `+5 maximum health`.

Patient is not an archery-only temperament. Its packages support perception, concealment, posture, and survival with every weapon.

### 15.8 Take Aim

Take Aim is Sharpshooter's starting subclass ability:

- select a currently visible enemy;
- commit approximately 0.5 seconds to studying it;
- retain the Aimed state for 6 world-time seconds;
- the next direct physical attack against it grants +5 damage and ignores 3 points of physical Defense on its first contact;
- the mark supplies no homing and does not permit attacks through walls;
- temporary loss of line of sight does not erase the mark or reveal unexplored geography;
- cooldown is approximately 8 personal-time seconds, beginning when the mark is consumed or expires.

Take Aim applies to every weapon category. Only the first contact receives its damage and Defense benefit, preventing multi-contact multiplication.

### 15.9 Sharpshooter track

Sharpshooter contains four justified purchases:

| Rank | Minimum level | Upgrade |
|---:|---:|---|
| I | 4 | **Keen Eye:** gain +2 Awareness and sense approximate enemy blobs outside line of sight. |
| II | 6 | **Far Sight:** increase unobstructed sight distance by approximately 25% and maximum range of every `aimed_projectile` by approximately 15%. |
| III | 8 | **Expose Weakness:** Take Aim's bonus rises from +5 to +10 damage, Defense ignored rises from 3 to 6, and its first contact gains +3 posture damage. |
| IV | 10 | **Dead to Rights:** the first contact against an Aimed target deals 50% additional final physical damage and double resulting posture damage; killing the target refreshes Take Aim. |

Keen Eye blobs:

- represent approximate last-sensed position, not a continuously exact outline;
- update through committed world time rather than while time is frozen;
- do not reveal identity, health, facing, action, or targetability;
- do not reveal unexplored terrain;
- still require an Awareness check for concealed or exceptionally stealthy actors.

Far Sight increases actor sight distance and aiming-camera lead rather than globally zooming the camera out. Its range bonus applies to Bow, other ranged weapons, aimed consumables, and direct projectile spells through capability tags rather than class checks. It does not change damage, velocity, explosion radius, or non-projectile geometry.

Dead to Rights applies its multipliers once to the prepared contact. Fan Shot, Twin Knives, and other multi-contact actions do not receive the multiplier separately on every contact.

### 15.10 Rogue · Sharpshooter level audit

| Track | Concrete availability |
|---|---|
| Bow | 2, 4, 6, 8, 10 |
| Dodge | 2, 5, 9 |
| Patient | Four investments available from level 2 |
| Rogue | 3, 5, 7, 9, 10 |
| Sharpshooter | 3, 6, 8, 10 |

The character's active controls are Defense, Bow Art, Stealth, Take Aim, and the late Adopted ability. Regular shots use the world field and universal gesture classifier rather than an additional ability button.

## 16. Current implementation boundary and future order

The old post-Sharpshooter order was superseded when Mage · Elementalist became the
architecture stress test and shipped. Warrior · Vanguard, Rogue · Acrobat, Rogue ·
Sharpshooter, and Mage · Elementalist are now playable; the shared actor/stat, posture,
track, migration, and dual-platform foundations in the former staged list are implemented.

Rogue · Cutthroat, Warrior · Guardian, and Warrior · Berserker remain design concepts,
not an approved implementation queue. Current work is enemy/boss validation, beginning
with Warden after the implemented Werewolf slice; see `docs/current-state.md`.

Amend this framework whenever concrete play or implementation changes an owned rule.
Changes must be explicit and land with the code rather than silently allowing behavior or
an obsolete roadmap to become the de facto design.

## Local combat coherence experiment (20 October 2026)

The isolated, unnumbered candidate implements selectable A/B/C/G/E lab rules and seed42 fixtures. Production remains 0.3.3. See [the lab implementation and verification boundary](combat-coherence-lab.md); automated success does not establish human acceptance of feel.
