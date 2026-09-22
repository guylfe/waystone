# Enemy, Encounter, and First-Boss Design Package

**Author:** Codex — independent design proposal. **Date:** 2026-09-14. **Inspected baseline:** 0.2.91, commit `af40685`.

**Status:** broad design source and review record. Its narrower implementation revision was
approved and partly shipped: Boss Lab (`0.2.92`), support relationships and four lean
encounters (`0.2.93`), Knife differentiation (`0.2.94`), and Werewolf solo (`0.2.95`).
Warden remains proposed/next; pack comparison and journey integration wait for evidence.
Unshipped alternatives and exact values in this broad package remain proposals.

This package covers regular-enemy differentiation, encounter experiments, Werewolf and Warden redesigns, and the Boss Lab needed to evaluate them. It also specifies how successful encounters could later enter Campaign and Expedition. It does not redesign player classes, elementalist spells, the complete expedition generator, or the ultimate campaign boss.

**Reading guide:** [recommendations and disagreements](#1-recommendation-and-evidence), [regular enemies](#3-regular-enemy-design), [encounter cards](#4-encounter-design-and-experiments), [Werewolf](#6-werewolf-design), [Warden](#7-warden-design), [Boss Lab](#8-boss-lab-specification), [implementation sequence](#10-proposed-implementation-sequence-and-review-gates), [decisions to review](#11-decisions-this-package-recommends-settling).

## 1. Recommendation and evidence

The central recommendation is to make enemies differ in **the positional problem they create and the opportunity they leave**, not merely their speed, durability, or number of attacks. Build encounters out of those relationships, then make the first bosses sustained tests of a few legible relationships.

That does not mean every enemy needs a new mechanic. The code already contains meaningful distinctions that earlier discussion understated: Knife has shared flank-path logic; Blade's attack already advances; Brute has a forward smash; Knight has a long thrust and a cleave. Much of the regular-roster work should therefore be presentation, encounter placement, and isolated behavioral experiments rather than wholesale replacement.

### 1.1 Credence and decision status

Credence here concerns the recommendation's suitability for Waystone, not its implementation status. These labels are judgments, not statistical probabilities.

| Label | Meaning |
| --- | --- |
| High | Strong fit with established rules and available evidence. Exact tuning still needs testing. |
| Medium | Plausible design with a specific unresolved tradeoff. Implement as an attributable experiment if approved. |
| Low / exploratory | Insufficient evidence for adoption; useful only as a separately enabled probe. |

Every new specification below remains **proposed** regardless of credence. Statements marked **baseline** describe inspected code. An exact number is a **starting candidate**, not a rule or validated result.

| Decision | Credence | Principal uncertainty |
| --- | --- | --- |
| Preserve deterministic commitment, visible tells, and meaningful recovery | High | Whether each concrete move satisfies the commitment horizon across loadouts |
| Differentiate through space, timing structure, and weaknesses | High | How clearly the differences read on a phone |
| Keep mixed pressure as the normal encounter starting point | High, directional | Historical survey evidence is not a current causal estimate |
| Test lean ranged formations without automatic melee filler | Medium-high | Map-dependent kiting and approach duration |
| Give Knife a clearer stalking-to-closing sequence | Medium | Whether staging improves decisions or simply makes Knife passive |
| Improve Blade's pressing presentation before adding mechanics | High | Whether this is enough to distinguish it in actual play |
| Give Shield a stable, visible ward relationship | Medium-high | Pathfinding and shield/ward congestion |
| Use encounter relationship checks, not a universal pressure score | High | How much generation validation is worth its complexity |
| Werewolf as pursuit and escape; Warden as territory and earned openings | Medium-high | Move interaction, pacing, and build coverage |
| Boss armor preserves commitments but does not erase earned posture breaks | High as a principle | The precise interruption boundary for each action |
| Werewolf pack variant | Medium-low | Adds may obscure the boss lesson and invalidate solo openings |
| Boss Lab before embedding bosses broadly | High | Test coverage and instrument correctness, not the usefulness of a lab |

### 1.2 Sources and limits

Project references:

- [Battle design bible](battle-design-bible.md): commitment horizon, enemy identity, earned openings, credence, and disagreements with overgeneralized Dark Souls lessons.
- [Design foundations](design-foundations.md): deterministic combat, phone readability, Campaign and Expedition purposes.
- [Survey archive findings](survey-archive-findings.md): historical mixed-pressure signal and the failure of simplistic role/conflicting-demand scores to explain fun.
- [Journey design principles](journey-design-principles.md): encounter context, contrast, respite, and larger-scale progression.
- [Expedition encounter redesign](expedition-encounter-redesign.md): deferred locale/encounter/formation integration.
- [Attack capture design](attack-capture-design.md): geometry-derived movement and defensibility.
- [Code structure audit](code-structure-audit.md): shared ownership, explicit schemas, and avoiding parallel authorities.

The prior Dark Souls and Hades reviews are inspiration, not proof. Hades level designer Ed Gorinstein's [level-design discussion](https://threadreaderapp.com/thread/1311777010239193088.html) is particularly relevant to authored placement, biome/locomotion relationships, and changing an encounter through its arena. It does not establish Waystone's timings or justify importing Hades' real-time dash economy.

The survey archive's 297 rooms precede the current build. Its mixed-pressure association is useful directionally; it does not prove that two ranged enemies are always better than one. More recent supplied runs show that sophisticated melee compositions can still rate poorly, while a simple two-archer situation can be enjoyable. Neither observation warrants a universal roster quota.

The current 0.2.91 Ox/control and Battle Flow changes need to remain identifiable in subsequent results. This design does not assume they have already passed a new player trial.

### 1.3 What I disagree with or would revise from the earlier suggestions

1. **“Add flanking to Knife” and “give Blade a forward attack” are not accurate descriptions of missing features.** Both already exist in some form. The missing question is whether their behavior creates and communicates different decisions.
2. **A more complicated melee roster is not automatically a more tactical encounter.** Shield, Duellist, and a heavy can become a crowd that dies to the same sweep. Their spatial relationship matters more than their labels.
3. **Do not make Knife calculate the exact frame at which the player cannot answer.** A visible attacking animation is legitimate information; an exact remaining-recovery or Energy query used to engineer unavoidable punishment would undermine commitment fairness. This design uses visible approach and engagement instead.
4. **Do not implement an abstract “conflicting answers” score as the generator's quality function.** It can describe a situation after the fact, but the historical proxy did not earn that authority. Validate concrete relationships instead.
5. **Do not impose an attack-token system to guarantee that only one enemy threatens at once.** It would remove simultaneous pressure the user already enjoys. Placement, authored cadence, and readable commitments are the first tools.
6. **Do not give every boss a fixed move count, health phase ratio, or mandatory posture-break kill loop.** The proposed first bosses need only the vocabulary that serves their identity. Health damage must remain meaningful throughout.
7. **Do not ship the solo Werewolf redesign and a full-speed two-Hound pack encounter as one inseparable experiment.** Learn whether the boss works alone, then evaluate the separately specified pack variant.
8. **Do not require every encounter to become a highlight.** Familiar, short, or low-pressure encounters can serve the journey. A Combat Survey room rating alone cannot settle that question.

## 2. Combat contracts that the designs must respect

### 2.1 Information before commitment

A player who commits from a reasonable position must have the information needed to evaluate the dangers that can resolve before their next readiness. A boss may punish greed, a late response, a cornered position, or a deliberately long action. It may not conceal a new branch until the player is already locked into the only response that branch defeats.

For every move, review the moment its identity becomes legible, its first damaging contact, the player's remaining commitment, the reachable escape geometry, and any already-active secondary threat. Do not evaluate startup in isolation.

For sequences, either declare the entire sequence with a distinct opening tell, or prove that the shared initial response remains valid through the branch. The initial implementation proposed here uses declared sequences and avoids late branching.

This is not a promise that every state has a safe answer. Earlier choices can remove all safe routes. Test reports must distinguish **newly unanswerable information** from **a previously visible danger made unavoidable by positioning or commitment**.

### 2.2 Timing convention

Existing catalog timings are enemy action-clock values affected by personal tempo. Do not describe them as fixed world seconds.

New boss timelines in this document are **reference-world seconds for the unmodified baseline boss**, with `t = 0` when its tell begins. Translate these once into authored action-clock values using the baseline actor tempo. Continue using the existing runtime tempo/condition system; frost must still slow the resulting action normally. Do not divide by the current slowed tempo every tick and thereby cancel the slow.

Travel is derived using the existing capture model and collision geometry. Distances below are center-to-center unless labeled radius, gap, or travel cap. Travel caps bound a move; they do not authorize speeding up a charge to guarantee contact. A move that cannot reach must miss or not be selected.

### 2.3 Distinct control outcomes

Keep these separate in rules, presentation, and telemetry:

- **Health damage:** normally applies even when an attack continues.
- **Ordinary hit reaction:** the small flinch that may cancel a light enemy.
- **High-impact interruption / forced movement:** governed by the existing shared effect rules and an explicit action resistance policy.
- **Posture break:** an accumulated, earned opening. It must not disappear because a mass-based fallback silently overrides a boss's intended policy.
- **Terrain collision:** a physical stop or crash, not “the player staggered the boss.”

For the proposed bosses, a break can be deferred to a specified safe boundary, but is latched and must then happen. Additional hits must not push that boundary back. Death takes precedence. Hits during the resulting opening do not endlessly refresh it.

### 2.4 Presentation is part of the move

Each move needs a different silhouette, weapon/body preparation, direction cue, and useful sound. Color is supplementary. A claw combination cannot be distinguished from a single pounce only by a small icon or color flash.

Normal play gets qualitative tells, impacts, strain, and recovery poses. Exact timing, geometry, and safe-response diagnostics belong in debug tools or the post-attempt report, not a permanent combat overlay. A camera-obscured tell is not considered communicated just because the simulation recorded it.

## 3. Regular-enemy design

### 3.1 Roster contracts and scope

| Enemy | The problem it should create | Its useful weakness / answer | Proposed work |
| --- | --- | --- | --- |
| Knife | A flank becomes dangerous while attention is directed elsewhere | Face the approach, deny its lane, or intercept its clearly announced close | Focused stalking/closing experiment |
| Blade | A direct advancing attack pressures the space in front of you | Leave its committed line or punish recovery | Presentation and approach consistency; retain attack initially |
| Bandit | A careless first swing can be sidestepped and countered | Bait its committed evasion, reposition, or use appropriate coverage | Retain; ensure Knife does not inherit its counter identity |
| Hound | A light pursuer crosses friendly bodies and attacks through a crowd | Read the leap, evade its endpoint, punish landing | Preserve current vault rules for evaluation |
| Boar | A grounded charge can rearrange lighter allies and close a lane | Exploit terrain, heavier blockers, or the committed path | Preserve current shove rules for evaluation |
| Ox | A heavy moving threat cannot be trivially held in neutral by light flinch | Get out of the gore lane; exploit its reset/recovery | Preserve 0.2.91 behavior before more tuning |
| Shield | A particular ally is difficult to reach from the obvious direction | Change angle, displace the screen, or separate the pair | Explicit ward relationship and readable facing |
| Polearm | A lane is dangerous at a distance that looks safe against shorter weapons | Approach obliquely or get through a committed thrust | Retain two-attack identity; test placement |
| Brute | A slow, substantial forward smash makes one patch of ground unsafe | Move around the committed footprint, then exploit recovery | Clarify footprint/tell; no new radial attack |
| Knight | A durable frontliner alternates a long line threat with a broad closer threat | Recognize thrust versus cleave; stop relying on light flinch | Retain repertoire; introduce in a simpler encounter |
| Archer | A persistent shot line taxes attention and approach | Use cover, cross the line deliberately, close during a commitment | Retain; lean crossfire and screening tests |
| Javelineer | A committed throw threatens the projected path of continued movement | Change course after the throw is legible | Preserve frozen ballistic lead; pair with positional pressure |
| Chanter | A visible support effect changes what an ally can do | Interrupt support or change the fight's geometry to reach it | Buff-specific tells and explicit recipients |
| Fire caster | Remaining in, or repeatedly using, the same threatened area becomes costly | Leave the announced fire threat and exploit casting commitment | Retain current fireball/breath; encounter tests only |
| Ice caster | A line or front changes the cost of the next movement/commitment | Avoid the announced control and approach from another line | Retain frost lance/cold front; encounter tests only |
| Earth caster | The route itself becomes constrained | Anticipate the wall, break it when appropriate, avoid the slowing area | Retain wall/sunder; pair with a reach threat |
| Air caster | Movement and projectile paths become unreliable in a visible field | Reconsider position and firing line; exploit its lack of direct pressure | Retain Gale/Windstep and symmetric projectile danger |
| Duellist | A frontal, careless commitment can meet a parry or precise thrust | Draw out the defense and change timing or angle | Retain; avoid using it as default filler |

This table is a design contract, not evidence that every baseline enemy already succeeds at it. Current caster catalog descriptions contain older terminology in places; any eventual documentation/UI pass should describe the actual abilities rather than revive old designs.

### 3.2 Knife: announce the closing lane

**Credence: medium.** Knife should be an opportunist, not a recovery-sniping calculator or a second Bandit.

**Baseline:** HP 20, movement speed 290, quick cut with authored startup 0.32 and active end 0.43; shared pursuit code already offers flank lanes. Keep health, damage, speed, capture target, and quick-cut geometry unchanged in the first experiment.

Proposed sequence:

1. **Approach:** use the existing flank-path mechanism. Prefer an available side approximately 65 degrees from the player's forward bearing; terrain and occupied space can override the preferred side. Do not repeatedly switch sides every decision tick.
2. **Poised approach:** when a flank is available, seek a staging distance of roughly 150–180. Knife visibly lowers its body and raises the weapon toward its intended closing lane. This is not invulnerability and not a new damaging move.
3. **Declared close:** a minimum 0.60 reference-world-second non-damaging approach tell precedes the quick cut when starting from stalking. Latch the intended lane. Ordinary movement remains collision-aware; there is no teleport, accelerated catch-up, or tracking through the player's chosen escape.
4. **Cut:** perform the existing quick cut only if its normal reach/intent conditions are satisfied. If the player vacated the lane, the close fails naturally and Knife resumes normal approach. Do not turn a missed close into an instant cut at a new bearing.

Knife can still use its normal close-range attack when the player deliberately enters an already-visible Knife's threat range. The new staging rule must not create a compulsory long preamble to every exchange. However, moving behind an occluder and reappearing does not authorize an untelegraphed attack; the normal commitment-horizon test still applies.

**Anti-passivity rule:** after 1.20 world seconds of unsuccessful, unobstructed staging, take a normal direct approach rather than waiting forever for an ideal flank. This is a pursuit fallback, not a hidden attack deadline. The close remains visibly announced.

**Selection information:** player facing, visible ally engagement, valid terrain lanes, and observed positions. Do not inspect Energy, selected input, cooldowns, or exact remaining player recovery to choose a guaranteed hit.

**Expected decision:** turn to intercept Knife and expose yourself to the other threat, or maintain your present objective while moving out of Knife's announced lane.

**Failure criteria:** increased idle time without more legible decisions; repeated lane oscillation; an offscreen close that cannot be answered; or Knife becoming harmless when alone. If these occur, retain existing flanking and keep only the improved tell. Do not compensate by making the cut nearly instantaneous.

### 3.3 Blade: a readable press, not a new lunge

**Credence: high for clarity; medium for behavioral adjustment.**

**Baseline:** HP 35, speed 230, diagonal cut already has 58 units of authored advance with startup 0.52, active end 0.65, and duration 1.50. Adding another advance would double-count an existing distinction.

Keep those attack values initially. Make its approach upright and direct, with the weapon prepared on the side from which the cut will come. Knife seeks a side; Blade makes the front uncomfortable. Once its existing melee intent commits, preserve that line and the actual recovery pose. Do not add a shield, ordinary-hit immunity, or a second attack just to make it feel important.

If trace review shows unnecessary target/lane churn before commitment, test an approach-goal hold of at most 0.60 world seconds, broken immediately by an invalid or blocked path. This is not a delay on collision replanning. The existing movement/stall recovery remains authoritative.

**Test:** same three-enemy roster and seed, current versus clarified behavior. Can the player identify Blade's pressure and Knife's closing lane without reading names? If not, adjust silhouettes and sequencing before buffing damage.

### 3.4 Shield and Chanter: make support relationships visible

**Shield — credence: medium-high.** Bind a designated ward by stable entity ID when a recipe explicitly contains a screen pair. Existing dynamic ally selection remains the fallback for unscripted situations; it should not compete with an explicit recipe assignment every frame.

- Prefer a guard point between the ward and the player, with a candidate Shield–ward center spacing of 140–220, subject to body radii and navigable room.
- The Shield must not overlap the ward, permanently seal it into terrain, or cross an impassable obstacle to maintain the relationship.
- Show a protective orientation and ward-aware repositioning, not a permanent magic tether. A brief pair highlight at encounter introduction is optional and should be evaluated on the phone.
- Once the ward dies or the pair is genuinely separated, fall back to the existing solo frontliner behavior. No instant retarget across the room.
- Displacement can create access. Do not immediately snap the Shield back or compensate with a ward teleport.

**Chanter — credence: high for presentation, medium for authored pairing.** Existing chant choice already distinguishes bulwark, haste, and ward. Telegraph the chosen effect and recipient before application: heavy braced stance for bulwark, quickening repeated motion for haste, enclosing gesture for ward. Use icon/shape and sound as well as color. Applied marks must match the announced effect.

Start with deliberately understandable pairings: Chanter + Brute + Blade to examine heavy support, and Chanter + Blade + Knife to examine fast support. Record the effect actually chosen; the roster label must not pretend to guarantee a buff if the current selector chose something else.

Do not add healing, summons, or another damaging spell to make Chanter useful. Its shared emergency staff poke remains a fallback, not a third support identity. Do not extend support to distant, unalerted groups as an incidental consequence of this work.

### 3.5 Brute, Knight, and the recently changed chargers

**Brute:** retain forward smash. A broad *forward* danger rewards moving around it; making it radial would erase that answer and overlap the Warden's territory attack. Verify that the ground preparation, weapon motion, and actual footprint agree. Start with Brute + Archer before adding another armored melee body. A territorial guard-point behavior is exploratory and is not part of the first proposed change set.

**Knight:** retain thrust and heavy cleave. The existing thrust already advances substantially; do not give it extra gap-closing movement. Introduce Knight + Archer as an exact two-enemy test, then compare the existing Knight + Archer + Ice Caster + Bandit recipe. If players cannot identify thrust versus cleave, improve their preparations before adjusting damage or tracking.

**Hound, Boar, Ox:** hold current 0.2.91 rules constant while testing this package's other changes. Hounds vault friendly bodies; Boars shove lighter allies under their existing rule; Ox has the recently revised posture-only reaction and committed-charge protection. Terrain collisions remain real. Survey “obstacle” cancellations must not be automatically interpreted as ally collisions or insufficient hyperarmor.

**No universal buff pass:** an unsatisfying mixed room is not enough evidence to increase every melee enemy's health, poise, or speed.

## 4. Encounter design and experiments

### 4.1 Build a relationship, not a bag of roles

Each authored variant declares: its exact initial roster, the relation to test, initial positions/facing, the terrain needed for that relation, and its fallback if the arena cannot support it. These can extend the existing recipe and formation machinery. They do not require a new general-purpose encounter language immediately.

Current `reinforcements` fill the starting composition; they are not timed waves. Do not reinterpret that field as a wave schedule. These regular-enemy experiments use no new waves.

Specialized lean variants need an explicit exact-roster setting so the existing minimum-body/fill logic does not turn a two-enemy experiment back into four enemies. Keep existing defaults for other recipes. Do not lower every encounter's roster to accommodate these probes.

### 4.2 Proposed test cards

All cards below are proposals. A variant ID is a suggested identifier, not an existing code reference.

| Proposed variant | Exact initial roster | Spatial relationship and player decision | Primary failure to watch |
| --- | --- | --- | --- |
| `crossfire_light` | Archer ×2 | Separated shot lines; choose which line to cross and which archer to close on | Both hidden behind the same cover, or a long empty chase |
| `screened_shot` | Shield, Archer | Shield protects a specific archer; change angle or displace it | Bodies merge; shield is irrelevant; ward is unreachable |
| `flank_and_press` | Blade, Knife, Archer | Direct pressure and an announced flank while a shot line matters | Knife/Blade still ask the same question; unreadable simultaneous arrival |
| `goring_lane` | Ox, Archer | Gore lane changes when it is safe to approach the archer | Ox repeatedly crashes before influencing the decision |
| `pinch_and_escape` | Boar, Archer | An optional short passage can become pinned from both ends; choose an early exit or create space against a committed threat | The player starts trapped, or only Vanguard's Advance can solve the layout |
| `warded_reach_probe` | Shield, Polearm | Intentional pure-melee test of protected reach and angle | Both are defeated by the same stationary sweep loop |
| `chanted_heavy` | Chanter, Brute, Blade | Recognize support, then decide whether to bypass the heavy | Passive chanter or an unbreakable traffic jam |
| `chanted_fast` | Chanter, Blade, Knife | A visible support commitment makes flank timing more urgent | Buff-specific tells unreadable; unsupported burst pileup |
| `lead_and_press` | Javelineer, Blade | Change course against the throw without drifting into the advancing cut | Throw silently retargets; both threats collapse into one line |
| `broken_ground_probe` | Earth Caster, Polearm, Knife | Route restriction changes which reach/flank answer is available | A newly placed wall makes an already-committed legal response impossible |
| `crosswind_probe` | Air Caster, Javelineer, Shield | Read wind, projectile danger, and a protected approach | Friendly-fire rules are asymmetric or the interaction is illegible |
| `knight_introduction` | Knight, Archer | Learn the heavy's two tells under one secondary pressure | Too much damage before the repertoire can be learned |

The current richer recipes remain comparison conditions, not automatically rejected content. `warded_reach_probe` is deliberately low-credence as a generally enjoyable room. Its purpose is to determine whether the relation works, not establish pure melee as a default.

Add a Hound to `screened_shot` only as a separate named variant after the pair is understood. Likewise, do not add optional filler to the other exact cards while collecting comparative results.

`pinch_and_escape` deliberately follows the user's positive Boar–Archer example. Put a short barrier near a wall with two initially open ends and an alternate route outside the passage. The player chooses whether to enter; enemies can then constrain the exits through ordinary movement. Vanguard can potentially dodge a charge and Advance into the archer, but other builds must be able to avoid the developing pin through earlier route/timing choices. Do not script a guaranteed rescue or demand that every already-trapped state has an escape. The desired event is player-created space under visible pressure, not a mandatory class-key puzzle.

### 4.3 Placement candidates and validation

Use existing formation sockets/path validation where possible. Starting candidates:

- Crossfire: shooters separated by at least 180 units, presenting roughly 50–100 degrees of angular separation from the entry reference point. This is not a universal firing-angle requirement once combat moves.
- Ranged introduction: a visible or clearly discoverable approach typically starts around 350–550 units from the entry reference, within the relevant enemy's actual awareness constraints. Check actual sightlines rather than relying on radial distance alone.
- Screen pairs: candidate spacing above, with guard and ward on navigably connected ground and neither initially overlapping another body.
- Static player passage: at least the player diameter plus 20 units of margin, currently about 80 units. This is only a static minimum; moving actors can still block it, and it is not a proof of safe traversal during an attack.
- Cover should let the player interrupt one important line without automatically disabling the entire encounter from a permanently safe firing spot. This is a design objective, not a mandate to eliminate all strong positions.

Reject initial placements with overlapping bodies, invalid navigation, or an unseen committed attack that can land before the player can respond. For the first implementation, attempt at most 12 placement candidates, then choose a named, prevalidated simpler formation for the same roster. If that also fails, reject that recipe for that arena and report the reason. Do not silently delete a required enemy, add filler, or squeeze bodies into invalid locations.

Avoid runtime omniscient layout correction. The generator can validate the starting relationship; enemies should not rearrange themselves to preserve an intended puzzle after the player successfully disrupts it.

### 4.4 Evaluation: did the relationship happen?

Record concrete observations rather than inventing a “fun score”:

- Did both archers establish distinct shot lines? How much time was spent only chasing?
- Did Shield actually intervene between the player and its designated ward? Did displacement create access?
- Did Knife announce and attempt a flank close? Did the player change facing or route before contact?
- Did the Javelineer's committed throw and Blade's approach overlap in a way that left a readable earlier choice?
- Did an Earth wall alter a route without trapping an already-committed player through newly hidden information?
- What stopped each charge: terrain, ally, player damage, posture break, forced movement, or range exhaustion?

Separate opportunity, attempted interaction, observed consequence, and player enjoyment. A successful ward relation can still be tedious. Low simultaneous-engagement time can be good in a deliberate ranged chase; it is not automatically a failure.

### 4.5 Campaign and Expedition use

Test relationships in Combat Survey first if this work is approved for implementation, then embed a small representative slice. Do not make completion of another player survey a prerequisite for reviewing this design.

For Campaign, use stable locations to teach, vary, and later combine a relationship. For Expedition, use shared encounter definitions but mode-specific placement, resource context, and escalation. Do not copy Survey refresh semantics into a journey.

A useful **candidate sequence**, not a required six-room loop, is:

1. Introduce a relationship in relatively readable space.
2. Revisit it with a changed approach or companion.
3. Relieve one axis of pressure: fewer threats, clearer routes, travel, discovery, or a short familiar encounter.
4. Combine learned relationships in a locally important encounter.
5. Give aftermath and orientation before another demanding decision.

Respite need not mean free healing, zero danger, or an uninteresting enemy. An empty traverse, a familiar advantageous fight, a view of the next landmark, and a recovery opportunity do different jobs. Keep those distinctions in the journey design.

Before a boss, establish its visual and mechanical vocabulary, then provide a legible approach and a chance to orient. Expedition arrival health and supplies remain part of the test; whether to place recovery there is a journey decision, not something the boss silently corrects. Maintain a separate full-resource lab condition to distinguish arrival attrition from boss difficulty.

## 5. First-boss framework

**Werewolf:** “It hunts your escape; survive its committed pursuit and take the landing.”

**Warden:** “It controls the ground in front of it; earn an angle or an opening instead of flinching it out of every action.”

These are complementary identities. Werewolf tests displacement and pursuit. Warden tests geometry, commitment recognition, and bounded durability. Neither should simply be a regular enemy with all its weaknesses removed.

Baseline assignments are Werewolf with two Hounds in the expedition final pack, and Warden in Campaign. The solo designs below are evaluation configurations; they do not decide final narrative placement or authorize replacing both live encounters immediately.

### 5.1 Shared boss rules

- Begin with current HP, armor, movement attributes, and posture capacity: Werewolf HP 210 / posture 14; Warden HP 130 / posture 18. Do not simultaneously increase health to manufacture duration.
- No health-damage immunity phase, mandatory weak-point weapon, automatic anti-repeat adaptation, or private resource counterpick.
- Phase thresholds are candidates, not genre rules. Queue transitions, finish the current action and earned recovery, then enter a non-damaging transition. Never clear an earned posture break to reach a phase script.
- A threshold reached during a posture opening waits for that opening to end. Damage can kill the boss before phase two; no minimum-health clamp.
- Preserve actual terrain collision and stable entity identity across phases. No repositioning teleport to repair bad AI positioning.
- No new Counterstop/time-manipulation mechanic in these first bosses.
- On posture break, use a non-refreshing opening of at least `max(1.20 world seconds, remaining current player commitment + 0.72 world seconds)` from the moment the break is executed. Reuse the existing world-time-to-action-clock logic; do not add a second timer authority.
- Normal attack recovery remains fixed and can be consumed while the player finishes a greedy commitment. Only the earned posture-break opening gets the readiness-aware minimum above.

The 1.20-second break candidate is not a promise of a full combo. Test executable actions, their reach, Energy affordability, and exit commitments. Do not express openings as a fixed number of safe hits.

## 6. Werewolf design

**Credence: medium-high for the identity; medium for the proposed repertoire and timings.**

### 6.1 What changes from baseline

Current Werewolf can choose a short-startup plain charge or a pounce/claw combination, has a close double-claw action, and evades between commitments. The pounce-combination executor uses ordinary actor movement rather than the structured charging-movement path used by regular charges. This risks inconsistent collision and interruption behavior.

Replace the ambiguous single-versus-combination launch with visibly different preparations. Retain a small repertoire. Route its moving strike through shared charge/collision semantics, not a third bespoke movement resolver.

### 6.2 Solo repertoire

All times follow section 2.2. Damage values are proposed base contact damage; use the normal damage resolver rather than guaranteeing final HP loss.

| Move | Tell and reference timeline | Geometry / starting damage | Opening and intended answer |
| --- | --- | --- | --- |
| **Hunting Leap** | Low, forward crouch. Startup 0.80; flight up to 0.70; grounded recovery 1.10 after landing or range expiry | Target direction/landing intent locked at launch after the visible crouch; travel cap 350, speed cap 500; one impact, damage 20 / posture 3 | Leave the announced landing corridor, then approach the grounded recovery |
| **Double Rake** | Upright, both shoulders raised. First contact window 0.75–0.90; second 1.20–1.35; recovery to 2.45 | Two catalog-backed claw footprints, reach 148; direction fixed at action start for both; damage 12 / posture 3 each | Leave the whole combination's coverage; do not treat the first missed claw as its end |
| **Bounding Rake** — phase two | Distinct long crouch with one arm drawn back. Startup 1.00; flight up to 0.60; claw begins 0.45 after landing, active 0.15; recovery 1.25 after claw | Travel cap 300, speed cap 500; impact 16 / posture 3, one follow-up claw 14 / posture 3, reach 152; claw bearing fixed at launch | Move outside the declared pursuit-and-claw lane; larger reward after the complete sequence |

For moving actions, recovery begins at the actual landing/end event, not an assumed maximum flight time. Landing early must not bring a formerly unannounced follow-up forward: Bounding Rake's second strike is announced from the initial tell and always has its full 0.45 post-landing preparation. Validate the complete earliest-contact timeline.

Launch-time locking means the crouch may visibly follow the player until launch, as other committed pursuit rules permit. It must not silently alter direction during flight. The presented landing corridor must agree with the actual locked path. If that cue is not readable, lock earlier rather than add tracking.

**Repositioning:** a visible grounded stalk, up to 180 units over at most 0.65 world seconds, collision-aware, without invulnerability or damage. At most one stalk between attack attempts when an attack is reachable; otherwise ordinary navigation may continue. Do not alternate endless invulnerable evades.

### 6.3 Selection and cadence

- At close range, prefer Double Rake when its valid intent band is reached.
- At a clear, reachable medium distance, prefer Hunting Leap. An initial candidate selection band is 180–380, subject to actual reach and collision checks.
- Outside valid attack conditions, navigate. Do not select a leap through a wall and then accelerate or teleport to the target.
- Phase two adds Bounding Rake as a separately telegraphed alternative, not a hidden extension of every leap.
- At the same valid distance, seeded variation is allowed before the tell begins. It must not switch after the player acts.
- Use a 1.00-world-second leap-family cooldown from the end of its recovery as a starting candidate. During it, grounded movement or close rake is possible. Log actual cycles; do not add an artificial idle if another already-readable action is valid.

No exact behavior should be selected because a player has insufficient Energy to dodge, a spell on cooldown, or a long recovery still remaining. The player can learn and exploit the Werewolf's repertoire; that is desirable until it becomes a trivial, low-risk loop.

### 6.4 Control and collision policy

| State | Ordinary hit reaction | High-impact / forced interruption | Posture reaching zero |
| --- | --- | --- | --- |
| Grounded stalk / approach | No routine light-flinch lock; health and posture damage apply | Existing strong/forced effects work normally | Immediate break |
| Grounded attack preparation | Light hits do not erase the tell | Existing qualifying strong effects can interrupt before launch/contact | Immediate break |
| Airborne moving strike | No ordinary flinch | Resolve resistance through the shared airborne/forced-movement policy; no midair teleport | Latch break and execute at landing, cancelling any follow-up |
| Claw contact window | No ordinary flinch | No new blanket immunity; respect the declared active-action policy | Defer only to the end of the current contact window, cancelling the next strike |
| Normal recovery | No repeated light-flinch extension | Existing damage/effect rules apply without refreshing the recovery | Immediate earned break |
| Posture opening | No timer refresh | Health damage applies; do not chain-reset the opening | Ignore additional break requests until reset |

Grounded strong interruption and posture break are different avenues. Avoid letting a high attack rate convert ordinary hit reactions into a permanent stun even though no posture break occurred.

During airborne travel, vault friendly bodies under the same explicit ally-collision policy used by Hound. This does not make the Werewolf untargetable, immune to projectiles, or able to pass through walls. A terrain crash cancels the follow-up and creates a candidate 1.30-world-second recovery. A blocked landing must resolve to the last legal position without overlapping bodies; do not shove a player through terrain to complete the animation.

Each pounce can damage a given target once. Each claw is a separately identified contact. Body overlap across simulation ticks is not repeated impact damage.

### 6.5 Phase and pack variant

**Solo phase two candidate:** at or below 55% HP, queue a 1.20-world-second non-damaging, clearly visible change of posture/howl after current recovery and any earned opening. Add Bounding Rake. Do not also increase movement speed, shorten tells, and add Hounds.

**Separate pack experiment:** begin with the solo repertoire understood. At the same 55% candidate threshold, replace the solo phase transition with a distinct howl that announces two finite Hounds entering at visible positions. Give at least 1.20 world seconds of arrival warning and check the commitment horizon. Do not spawn them overlapping the player or already in damaging flight. Hounds then use normal rules and do not respawn. This variant does not also unlock Bounding Rake.

While either Hound lives, Werewolf uses stalk, Hunting Leap, and close-range Double Rake, with a candidate 3.00-second leap-family cooldown after recovery. Retaining Double Rake prevents standing close from disabling its entire repertoire. This is a specific authored boss/add cadence, not a universal rule forbidding simultaneous attacks. Hounds remain capable of overlapping an already-visible Werewolf threat. When the pack dies, finish the current action and return to the ordinary solo cadence without a free immediate leap; retain the two-family repertoire in this comparison condition.

Compare pack versus solo phase-two remix as alternatives first. Do not assume the production boss needs both. The existing live expedition pack must be explicitly migrated or retained; enabling a Boss Lab variant alone must not silently alter it.

### 6.6 What would make this fail?

- Every build can circle indefinitely and punish each leap with no positional decision.
- Ranged builds cannot exploit a landing before a guaranteed follow-up reaches them.
- Melee builds have no reachable punish despite apparently long recovery.
- The two leap preparations are visually indistinguishable on the Fold.
- Terrain repeatedly stops the Werewolf before it contributes, or landing repair moves it illegally.
- Pack deaths are mostly attributable to newly unseen threats rather than legible overlapping ones.

Change the responsible geometry, selection, or tell before increasing HP or damage. In particular, do not solve safe circling by enabling invisible midair tracking.

## 7. Warden design

**Credence: medium-high for the identity; medium for exact timings and phase remix.**

### 7.1 What changes from baseline

Baseline Warden has radial slam, heavy cleave, and a charge. Its mass is 1.6, meeting the general heavy-telegraph threshold: posture can currently be held above zero during committed melee/slam/charge. A boss design that promises earned posture openings cannot leave that behavior as an accidental override.

Replace generic charge with a deliberate advancing thrust built through the shared melee/capture system. Keep cleave and radial slam clearly distinct. Introduce an explicit control policy that preserves its active hit but delivers an earned break at a bounded boundary.

### 7.2 Repertoire

All times follow section 2.2. Retain HP 130, armor 1, and posture capacity 18 for the first mechanics comparison. If it dies before meaningful learning, test a separately labeled HP-only condition; 180 is a candidate, not part of the initial redesign.

| Move | Tell and reference timeline | Geometry / starting damage | Opening and intended answer |
| --- | --- | --- | --- |
| **Gate Cleave** | Broad side preparation. Startup 1.05; active 1.05–1.21; recovery ends 2.46 | Forward sector, candidate reach 190; derive travel with `f_rad = 0.55`; damage 20 / posture 6 | Move out of the committed sector or around the flank; punish the finish |
| **Driving Thrust** | Weapon centered, shoulder behind it. Startup 0.85; active 0.85–1.07; recovery ends 2.22 | Narrow shared thrust footprint, reach 230; derive advance with `f_rad = 0.45`; damage 20 / posture 5 | Cross the committed line or approach the exposed side; do not merely retreat along the point |
| **Ground Slam** | Weapon raised vertically, body visibly planted. Startup 1.20; active 1.20–1.36; recovery ends 2.76 | Radial ground footprint, candidate radius 185; no tracking drift or simultaneous new persistent hazard; damage 22 / posture 6 | Leave the announced radius before committing to a punish |
| **Gate Sequence** — phase two | Cleave preparation with the weapon visibly held for a second movement. First active 1.05–1.21; thrust active 2.00–2.22; recovery ends 3.52 | Cleave then narrow thrust, both using their normal damage; all bearings fixed at action start in the first version | Leave the combined coverage rather than stepping back into the center after the first swing |

The sequence needs a distinguishable opening silhouette, not a flash appearing after the first cleave. If players cannot distinguish it reliably, make phase-two cleave always use the sequence and present that phase change clearly, rather than keep two visually identical branches.

Derive forward travel once from the chosen geometry/capture target. Do not add a second charge displacement. Walking around the Warden can be an appropriate answer to a thrust; Ground Slam provides a different local question without making every move omnidirectional.

### 7.3 Selection and phase

- Driving Thrust serves a valid longer line; Gate Cleave serves a closer frontal engagement; Ground Slam serves close radial pressure.
- Exact intent distances must be generated/validated from effective footprints, actor radii, and advance, not independently tuned until one move magically reaches.
- Select from valid intents using visible distance, angle, terrain, and phase. Latch before the tell. Do not choose slam because the player just selected a long combo or because it is the only attack they cannot afford to evade.
- When no attack is valid, advance visibly using normal navigation. Do not add a chase teleport or an offscreen rush.
- At or below 50% HP, queue a 1.20-second non-damaging grip change after recovery and earned openings. Phase two adds Gate Sequence; no simultaneous damage multiplier or faster tempo.
- In phase two, give plain cleave and sequence equal starting selection weights when their shared opening geometry is valid; thrust and slam retain their distance/angle gates. This is seeded variation before the tell, not reactive anti-repeat punishment. If sequence repetition is tedious, first assess its recovery and positional result rather than automatically add an anti-repeat system.

### 7.4 Control policy and earned openings

Warden takes normal health and posture damage. Ordinary light hits do not continually cancel approach, preparation, or recovery. Existing qualifying high-impact effects can interrupt grounded preparation; a new categorical immunity to player tools is not proposed.

If posture reaches zero:

- During approach, preparation, or recovery: break immediately.
- During an active contact window: latch the break, finish that window, then break before any follow-up. Gate Sequence's second strike is cancelled if the first window earned a pending break.
- During the posture opening: do not refresh it. Reset posture through the shared break-completion path.

The pending-break state is an earned event, not a posture value repeatedly forced back to 0.25. Death clears it. Phase transitions wait for it. The general mass-based fallback must not override this explicit policy; ordinary heavy enemies retain their baseline rules unless separately approved.

This creates an alternative to simply leaving the attack, without making posture mandatory for dealing health damage. A low-posture-damage build should still win by learning geometry and normal recoveries.

### 7.5 Arena and failure criteria

Begin in an open, readable arena with enough room to leave the slam and circle a committed thrust. A second condition may add two peripheral pillars. Do not start with a narrow room, additional ranged enemies, and new phase mechanics together.

Pillars should create approach choices without consistently hiding the preparation. Do not remove a legitimate strong position merely because a player uses it; investigate whether it removes all meaningful decisions across the whole fight.

The design fails if cleave/thrust are indistinguishable, if every safe answer is the same backward step, if a posture break never becomes usable, or if winning requires an undocumented control exploit. If the boss dies too quickly to display its identity, adjust HP in an isolated condition after geometry/readability are credible.

## 8. Boss Lab specification

**Credence: high.** Current ordinary Combat Survey is not sufficient to evaluate phase learning, retries, add interactions, and boss-specific openings.

### 8.1 User-facing flow

1. Choose Werewolf or Warden; choose a named solo/phase/pack variant.
2. Choose a real loadout and progression preset, ruleset, arena, and seed.
3. Show exactly which resources reset and any deliberate experimental overrides.
4. Attempt the fight. Normal readiness/time-stop and combat UI remain intact.
5. On victory or death, allow the terminal action/presentation to settle, then show a boss-specific rating and compact diagnostics.
6. Offer **Retry same setup**, **Change setup**, or **Leave**. Same setup restores the same initial snapshot/seed; it is not secretly a new randomized encounter.

The mode must be explicitly registered in mode rules. Do not rely on unknown mode IDs falling back to Expedition. It must not award Campaign progression, advance an expedition, or consume persistent supplies.

### 8.2 Presets and resource context

- **Mechanics baseline:** full HP and Energy, five normal potions, no unlimited replenishment during the fight. Start with representative level-3 builds to expose access problems, then level-9 builds to examine mature toolkits. Use the actual upgrade rules; do not synthesize impossible builds.
- **Arrival condition:** an explicitly supplied health/Energy/potion/build snapshot from a journey. Report that starting state rather than treating its deaths as full-resource balance failures.
- **Phase practice:** an optional direct phase-two start with a clearly labeled health/state setup. It is not a complete boss attempt and must not be pooled with full-fight completion rates.
- **Experimental override:** any HP/cadence/geometry change appears in the setup and report. Never report such an attempt as plain 0.2.91/default boss behavior.

Use Energy as the main current balancing condition. Include Recovery-mode smoke/regression checks where supported, but defer claims about which ruleset is better until matched boss content has been compared.

### 8.3 Measurements and attribution

Extend shared reporting by measurement capability, not scattered `COMBAT_SURVEY` checks and a copied second counter system.

Required attempt metadata: game/content version, setup/variant ID, seed, initial snapshot identity, loadout/progression, resources, arena, ruleset, input/presentation configuration, and any override. Preserve enough data to reproduce action selection and contact geometry under the same version; do not promise identical replays across changed code.

Required event families:

- Boss action selected, tell begun, launch/contact windows begun, recovery begun/ended, normal completion, and interruption/cancellation with cause.
- Phase threshold crossed, transition queued/begun/completed, and any delay because an action or earned opening remained.
- Ordinary reaction, resisted reaction, high-impact interruption, posture damage, pending break, executed break, and break completion.
- Player commitment/readiness boundaries; HP/Energy expenditure; potion usage; defensive action; damage source including adds and hazards.
- Charge path, last legal position, terrain/ally stop, landing, and each uniquely identified impact.
- Pack arrivals/deaths and actual overlapping threats, when that variant is active.

Avoid duplicate counting: one action can create several contacts but only one action completion; one interruption gets one authoritative cause with optional contextual detail. Store bounded detailed traces plus full-run aggregates so long retries do not grow memory indefinitely.

For openings, distinguish:

1. **Authored opening occurred.**
2. **A player became ready during it.**
3. **A tested action could reach and resolve during it from that state.**
4. **The player actually used it.**

These are not interchangeable. A sampled action search can report a found response or no response found; it cannot certify all continuous positions and inputs. Use **unknown / not evaluated** when appropriate, never silently classify untested states as safe.

Record visibility/occlusion at the relevant tell and commitment, not just at impact. A theoretically valid response to an unseen cue is not evidence of readability.

### 8.4 Questions after an attempt

Keep the first screen short: difficulty, enjoyment, perceived fairness, and desire to retry. Then optional targeted questions:

- Which move was hardest to distinguish or understand?
- Did you see an opening but feel unable to use it? Which one?
- Did a death feel caused by an earlier choice, a new surprise, or unclear contact?
- Did the second phase ask you to use what you had learned, or merely add noise?

Do not require players to use every tool. Low use of Rally, Advance, or a spell is evidence about that attempt, not proof of an unusable ability. Respect the user's earlier caution about overinterpreting a single run's tool usage.

## 9. Verification and implementation boundaries

This section specifies future implementation and validation if approved. **No tests described here have been performed merely by writing this document.**

### 9.1 Existing owners to extend

| Concern | Current code / intended ownership |
| --- | --- |
| Archetype facts, technique plans, proposed action parameters | `scripts/core/combat_catalog.gd`; preserve canonical definitions rather than duplicate values in AI and rendering |
| Intent, locomotion, control/effect resolution, phase transitions | Existing boundaries in `scripts/core/run_state.gd`; extract touched shared helpers only where justified |
| Charge versus pounce collision | Shared charging-movement/contact policy; bring moving combo through it rather than introduce another mover |
| Presentation and tells | `scripts/presentation/game_board.gd`, consuming simulation state rather than deciding damage or phase |
| Runtime fields and persisted/projected state | Existing runtime and state-field schemas; stable IDs, explicit defaults, and validation |
| Modes and reporting | `scripts/core/mode_rules.gd` and shared survey-counter/reporting owners |
| Save/replay compatibility | Existing save migrations and deterministic snapshot ownership |
| Survey formation and eventual journey placement | Existing recipe/formation machinery and `scripts/core/floor_generator.gd`; no duplicate boss behavior in the generator |

Both bosses need phase state and deferred-break semantics; that is a concrete shared need. It does not justify building an unrestricted boss scripting language. Start with a small explicit sequence representation or existing action fields with canonical constructors. Presentation should receive the declared move/segment, not infer it from elapsed-time thresholds independently.

Suggested new state, only if needed by the chosen implementation: phase ID, pending phase transition, sequence/segment identity, latched pending break with cause, and designated ward ID. Each needs a canonical constructor/default, descriptor, serialization/snapshot decision, and cleanup boundary. Do not create ad hoc runtime dictionaries without those decisions.

Resolve control policy in one place with explicit precedence: death; existing opening; earned pending break at its boundary; declared action resistance; shared fallback. Verify the exact order against existing effects before implementation. Never make every boss path bypass the ordinary faction, damage, or actor-mutation layer.

Existing saves containing a changed in-flight boss action need an explicit compatibility decision. Preserve the old action to a safe boundary if the old semantics remain supported; otherwise reject that incompatible in-flight setup with a useful message. Do not reinterpret an old airborne action as a new combo halfway through it. A lab retry snapshot is content-versioned.

This work need not complete every remaining architecture-audit proposal first. Fix the ownership seams actually touched, and document any consciously deferred audit concern.

### 9.2 Deterministic and behavioral tests

Before balance claims, verify instrument fixtures with known outcomes. Then cover:

- Freeze: no elapsed-time progression, effects expiry, selection RNG, or phase transition while world time is stopped.
- Replay: same setup and inputs reproduce actions, positions, phases, contacts, and counters; save/load across every relevant boundary preserves them.
- Geometry: contact matches the presented footprint; damage occurs once per intended contact; range expiry, terrain collision, and empty landing are distinguished.
- No hidden retarget: the player moving after launch does not silently steer a locked leap/thrust; a declared sequence does not select a different branch after commitment.
- Control: light hit, high-impact hit, forced movement, posture break, terrain crash, and death tested separately in preparation, active, recovery, and transition states.
- Pending break: boundary is finite; extra hits do not postpone it; follow-up is cancelled; phase change cannot consume it; death wins.
- Formation: no initial overlap, invalid ward IDs, impossible fallback, or hidden automatic filler in an exact-roster experiment.
- Mode isolation: Boss Lab does not mutate journey progression, share retry resources, or fall through to Expedition logic.
- Reporting: selected actions versus contacts versus interruptions reconcile; phase-practice and override attempts are labeled and excluded from inappropriate aggregates.

For commitment-horizon cases, include early/late approach, short/long player commitments, low Energy, close/far/off-angle positions, terrain edges, slow conditions, and relevant secondary threats. A failing fixture should retain the exact state and explain the unavailable information, not just assert “boss too fast.”

### 9.3 Human and device checks

Test the phone presentation in both supported orientations/configurations actually used, including camera edges and occlusion. Inspect each boss's plain-versus-sequence tell, delayed break, crash, transition, and recovery. Automation cannot establish that those cues are understandable.

Use a small pilot of roughly 8–12 attempts distributed across the two bosses and representative builds to find gross failures. This is a bug/readability pilot, not statistical validation. Alternate comparison order where possible; learning and fatigue matter. Expand after the worst failures are addressed.

Success is not a target win rate. Look for learning across retries, correctly identified mistakes, usable openings across builds, meaningful positional decisions, and a desire to retry. Also look for a dominant low-risk loop and long periods of empty pursuit.

## 10. Proposed implementation sequence and review gates

The whole design can be approved together, but implementation should preserve attributable checkpoints. These are proposed stages, not scheduled releases.

1. **Observability and exact encounter variants.** Establish correct action/contact/control attribution, explicit lean rosters, and readable Shield/Chanter relations. Keep new boss mechanics disabled. Gate: fixture correctness and no changes to ordinary roster filling outside named variants.
2. **Focused regular-enemy experiments.** Knife close, Blade clarity, and selected encounter cards. Hold current charger rules constant. Gate: readable distinction and functioning relationships, not a global increase in damage taken.
3. **Boss Lab shell and shared boss control/movement seams.** Reproducible attempts, phase/setup metadata, shared moving contact, deferred-break policy. Existing ordinary-enemy behavior must remain covered. Gate: deterministic lifecycle and no profile/progression leakage.
4. **Werewolf solo.** Hunting Leap, Double Rake, then the declared phase-two Bounding Rake. Gate: commitment-horizon and collision checks, usable landing openings, phone tells. Pack stays a separate switch.
5. **Warden solo.** Cleave, thrust, slam, and declared phase-two sequence. Gate: earned posture openings and viable health-damage play without mandatory control loops.
6. **Compare and embed narrowly.** Evaluate Werewolf pack alternative, then place validated boss/encounter variants into a small Campaign/Expedition slice with explicit arrival-resource context. Only then revisit larger expedition distribution and the planned matched Recovery/Energy comparison.

If delivered under one implementation command, still use separate commits/checkpoints and test each boundary. Do not change both boss health, every regular-enemy cost, encounter density, and recovery economy in the same balancing step.

## 11. Decisions this package recommends settling

Recommended for implementation review:

- Use the roster contracts above, with most enemies retained rather than mechanically expanded.
- Test Knife's declared close; make Blade's existing press readable rather than add another lunge.
- Bind explicit screen pairs where authored; communicate the Chanter's actual chosen buff.
- Permit exact lean encounter variants without changing global encounter size.
- Design Werewolf solo first, with the pack as a separate alternative.
- Replace Warden's generic charge with an advancing thrust and explicit earned-break rules.
- Build a real Boss Lab with reproducible setups and honest opening/visibility diagnostics.

Keep open until evidence:

- Whether the Knife staging sequence is worth its behavioral complexity.
- Which pure-melee variants are enjoyable outside a deliberate contrast slot.
- Whether Werewolf is better with a pack or solo phase remix.
- Boss health, final damage, phase thresholds, and exact timing/cadence values.
- Whether supporting cover improves boss decisions or obscures their tells.
- Which encounters belong in each region and how often; this document supplies relationship candidates, not a complete expedition distribution.

Do not adopt:

- Global Energy/regeneration/stat changes to compensate for these enemy designs.
- A hidden director that cancels enemy commitments to protect the player.
- Private-resource-aware counterpicking, late invisible sequence branches, or universal boss immunity.
- A universal roster/move-count/pressure-score quota presented as a proven lesson from another game.

The intended outcome is a roster and boss pair that invite recognizable, different decisions while retaining Waystone's existing combat logic. Whether those decisions are enjoyable remains a question for implementation, observation, and play—not something a design document can declare solved.
