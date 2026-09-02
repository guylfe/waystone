class_name RunState
extends RefCounted

const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const AbilityCatalogScript = preload("res://scripts/core/ability_catalog.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")
const FloorGeneratorScript = preload("res://scripts/core/floor_generator.gd")
const ModeRulesScript = preload("res://scripts/core/mode_rules.gd")
const SurveyReportScript = preload("res://scripts/core/survey_report.gd")
const SurveyCounterCatalogScript = preload("res://scripts/core/survey_counter_catalog.gd")
const StateFieldSchemaScript = preload("res://scripts/core/state_field_schema.gd")
const SaveMigrationsScript = preload("res://scripts/core/save_migrations.gd")
const RuntimeSchemaScript = preload("res://scripts/core/runtime_schema.gd")

signal changed
signal message_changed(text: String)

const WORLD_SIZE := Vector2(15600.0, 7000.0)
const SIM_DT := 1.0 / 120.0
const FRAME_DT := 1.0 / 60.0
const PLAYER_RADIUS := 30.0
const ENEMY_RADIUS := 28.0
const PLAYER_MAX_HP := 100
const MOVE_SPEED := 300.0
const WARRIOR_MOVE_SPEED := 260.0
const MOVE_RANGE := 34.0
const DODGE_SPEED := 560.0
const DODGE_COOLDOWN := 4.0
const BLOCK_COOLDOWN := 3.5
const ENDURE_COOLDOWN := 4.5
const NAV_CELL := 75.0
const VISIBILITY_CELL := 50.0
const SIGHT_RANGE := 520.0
const WAYSTONE_RANGE := 145.0
const SPATIAL_CELL := 360.0
const ACTIVE_ENEMY_RADIUS := 1750.0
const POSTURE_BREAK_OPENING_SECONDS := 0.72
const ENEMY_MOVE_EPSILON := 0.05
const ENEMY_STEER_INTERVAL := 0.14
# Tolerance around the intended strike distance within which an enemy commits.
# Approach moves are truncated at the intended distance itself so the enemy
# re-decides there rather than overshooting by a whole move action -- up to 110
# units for a Blade, which is what made the commit gap a ~70-unit lottery.
#
# Kept small deliberately. It is tolerance, not a target: a wide band lets an
# enemy whose move happens to end mid-band commit early, which reintroduces the
# spread the truncation just removed. An enemy that re-decides outside it simply
# approaches again, which reads as settling into range.
const STRIKE_COMMIT_BAND := 4.0
# Softness of range-weighted attack selection, in world units. An option whose
# preferred distance is this far from the current gap gets half the weight of a
# perfectly matched one. Larger values make selection more random and less
# situational; smaller values make it more predictable.
const STRIKE_SELECTION_SOFTNESS := 90.0
# An intent is abandoned if the gap closes this far inside it, so an enemy whose
# space is taken re-picks something suited to the range it is actually at instead
# of retreating to honour a stale plan.
const STRIKE_INTENT_ABANDON_MARGIN := 60.0
const ENEMY_STALL_REPATH_TIME := 0.12
const ENEMY_STALL_ABORT_TIME := 0.42
const TWIN_KNIFE_SEQUENCE_RECOVERY := 1.0
# Energy is the burst budget, not the fight gate -- recovery is the primary
# limiter. Costs are authored at their original relative shape and scaled here,
# so the relationships stay legible and the global price level is one number.
#
# 0.5 was too generous: the 0.2.17 survey emptied the bar 4 times in 205 seconds
# of combat (1.2 lockouts per minute against 4.1 in 0.2.15) and the tester could
# not exhaust himself deliberately. The error was sizing costs against a static
# bar rather than against a fight -- Room 11 spent 202 Energy without a single
# lockout because 4.1 seconds of regeneration returned 115 of it. 0.65 was chosen
# by replaying every room of that survey: easy rooms still finish with breath to
# spare, and the pressure rooms exhaust once or twice as they should.
const ENERGY_COST_SCALE := 0.65
# Slower than the old 60/s, but continuous: spending no longer arms a delay, so
# the bar refills while you reposition rather than pausing then snapping back.
const ENERGY_REGEN_PER_SECOND := 28.0
# Only a hit suppresses regeneration now, and only briefly.
const ENERGY_REGEN_DELAY := 0.5
# The single exchange rate between the two rule profiles. A cooldown is how long it
# would take to earn an ability's price back as a share of the whole pool, so ONE
# authored energy number now sets both -- there is no second table to keep in sync,
# and a global re-tune of ENERGY_COST_SCALE carries the cooldowns with it.
#
# 24s is not a guess. The six hand-authored pairs that already existed implied 20-33
# seconds per 100 energy (Advance 33.0, Execution 28.2, piercing shot 26.3, bow art
# 24.0, Twin Fang 21.6, Drawing Cut 20.2, median 25), so the formula mostly codifies
# what was there and repairs the three abilities that fell outside it entirely.
#
# The pool is the denominator deliberately. Under Recovery energy is never spent and
# never regenerated, so the +10 max energy from `vigilance`, `fleetness` and
# `observation` did nothing at all -- three track choices with a dead half. This gives
# that half a job. The accepted consequence: max energy buys burst depth under
# Energy (more actions before empty, prices unchanged) and sustain under Recovery
# (every cooldown shorter, burst unchanged). The same stat reads differently in each
# profile, which is a known divergence rather than an oversight.
const COOLDOWN_SECONDS_PER_FULL_POOL := 24.0
# Stealth is charged by the second rather than by the use, so a hide you cut short
# costs less than one you sit in. That is the whole reason it is a drain and not a
# cooldown: a cooldown rewards squeezing the most out of each activation, a drain
# rewards striking quickly and getting out.
const STEALTH_DRAIN_PER_SECOND := 10.0
# The floor, and it is what makes cancellation safe to offer. Entering stealth fires a
# one-shot at rogue rank 4 that turns every nearby alerted enemy `suspicious`, and
# `execution_target_was_unaware` accepts anything that is not `alerted` -- so the
# benefit is instantaneous while a purely proportional price is not. Without a floor a
# quarter-second tap would buy the unaware-execution bonus for a rounding error, and
# tapping would strictly beat hiding.
const STEALTH_MINIMUM_ENERGY := 20.0
const STEALTH_DURATION := 5.0
# Back to 2.0 from the 1.2 that 0.2.17 adopted to offset the movement slow. The
# 0.2.20 survey found exhaustion costing 2 damage across 8.33 seconds *despite*
# an enemy being alerted for 100% of it, so there was no danger to offset. If the
# self-covering hypothesis holds -- your own combo staggers whatever would punish
# you -- then the first second or so is covered regardless of duration, and this
# adds roughly 0.8s of genuinely exposed tail where there was previously almost
# none. The effect should therefore be larger than doubling the number suggests.
const EXHAUSTION_DURATION := 2.0
# Exhaustion's teeth. 45% of a 260 u/s walk is 117 u/s, below the capture escape
# threshold of every fast enemy (Knife 144, Bandit 142, Blade 131) and above the
# slow ones (Shield 103, Brute 91) -- so being winded loses you the fights where
# footwork was carrying you, without stranding you in a room of Brutes.
# The Ox. A committed line rather than a committed distance: it runs until it hits
# something or exhausts the cap, so an open arena lets it cross most of a room and
# a wall ends it in a stagger. Startup outlasts a player commitment (0.983s for a
# combo strike) by design -- an elite that resolves inside your swing is the same
# defect as a Boar that does.
const OX_CHARGE_MIN_GAP := 40.0
const OX_CHARGE_STARTUP := 0.85
const OX_CHARGE_SPEED := 520.0
const OX_CHARGE_CAP := 900.0
const OX_CHARGE_ACTIVE_END := OX_CHARGE_STARTUP + OX_CHARGE_CAP / OX_CHARGE_SPEED
const OX_CHARGE_DURATION := OX_CHARGE_ACTIVE_END + 0.85
# The Ox's reach is its body: radius 76 puts contact at 104, which still sits in
# the band the design needs -- the aim locks at 0.765s and the charge arrives at
# 1.14s from the nearest interesting range, leaving 0.375s in which walking covers
# 97 units and a Dodge about 131. Below 97 it is walkable, above 131 unanswerable.
# It used to reach 115 by wearing a 41-unit invisible collar, which is a lie a
# drawn ring only labels.
const HOUND_NEUTRAL_AFTER_EVADE := 0.55
# Where each role wants to stand relative to the player. Frontline and screen sit
# between the player and something they are covering; reach holds its own bearing
# at spear distance instead of closing.
const RECIPE_REPEAT_WINDOW := 4
# Roles that are not a melee body. Expressed as roles rather than as a list of kinds so
# the elemental casters slot in as rows later instead of needing a retrofit.
const NON_MELEE_ROLES := ["ranged_pressure", "area_denial", "movement_denial", "support"]
# Every fourth room is a melee experiment: rooms 3, 7 and 11 of a run. Deterministic
# rather than random, because a designed experiment that only *might* appear is how the
# Chanter and the Ox spent a whole version unplayed.
const MELEE_EXPERIMENT_EVERY := 4
const ANCHORED_ROLES := ["frontline", "screen", "reach"]
# Generous, so a frontliner corrects only when it is genuinely out of place rather
# than shuffling instead of fighting.
# NOTE: a frontliner aligns while approaching and then drifts, because its attacks
# carry it off the line and nothing pulls it back -- measured at 41 degrees off the
# bearing it wants. Gating attack commitment on being in position was tried and
# withdrawn: it destabilised when an enemy should commit, breaking two roster
# assertions for a marginal gain. Correcting a held line needs a reposition that
# does not compete with attacking, not a veto over it.
# Reach holds at 200 rather than 210 for a specific reason: the thrust commits at
# 205 + STRIKE_COMMIT_BAND (4), so a Polearm standing at 210 was one unit outside its
# own commit band and would hold that spot without ever attacking. A role must be able
# to act from the distance it is told to hold.
const ROLE_HOLD_DISTANCE := {"frontline": 88.0, "screen": 78.0, "reach": 200.0}
# Where a kind belongs in a formation, derived from its role rather than authored per
# slot. Naming roles directly on slots conflates who an enemy is with where it stands,
# and the Polearm is the proof: it is melee, but `reach` holds at 200 against the
# frontline's 88, so a Polearm spawned in the van walks BACKWARDS the moment the player
# closes and the formation dissolves in the first two seconds. A body has to be spawned
# where its own standing behaviour will keep it.
#
#   van  -- wants contact and holds it: screen, frontline, breaker, boss
#   wing -- wants an angle rather than depth: flanker
#   mid  -- melee that fights over the front rank: reach
#   rear -- everything that never wants to be reached at all
const ROLE_FORMATION_BAND := {
	"screen": "van", "frontline": "van", "breaker": "van", "boss": "van",
	"flanker": "wing",
	"reach": "mid",
	"ranged_pressure": "rear", "area_denial": "rear", "movement_denial": "rear", "support": "rear",
}
# Where a body may go when its own band is full, in order of preference. `rear` never
# falls forward past `mid`: the whole point of the change is that a caster cannot end
# up in front, which is how the Chanter died three seconds into its only appearance.
const BAND_FALLBACK := {
	"elite": ["elite", "van", "mid"],
	"van": ["van", "elite", "wing", "mid"],
	"wing": ["wing", "van", "mid"],
	"mid": ["mid", "rear", "van"],
	"rear": ["rear", "mid"],
}
# Two groups placed independently are two sequential fights, which the archive rates
# worse than one good one -- 0.2.40 room 6 ran 0.22 engaged with 3 of 3 kills made
# alone and scored 2/2/2. A second group is only legal if reaching the first puts the
# player inside its threat: close enough to be pursued, or with a clear shot.
const GROUP_PURSUIT_REACH := 460.0
# The survey arena is a disc, and nothing in placement knew it. Anchors are drawn up to
# 560 units from a player who already stands 380 from the centre, and a rear slot sits
# up to 330 further out again -- so a body could be seated 975 units from the middle of
# a floor with a 650 radius, which is what put an Archer outside the world in the
# 0.2.42 survey. Margin keeps a body clear of the rim rather than balanced on it.
const SURVEY_ARENA_CENTER := Vector2(850.0, 700.0)
const SURVEY_ARENA_RADIUS := 650.0
const SURVEY_ARENA_MARGIN := 80.0
# Actions that leave an enemy uncommitted. Anything NOT on this list is a body that has
# thrown itself at the player and therefore knows exactly where they are.
const NON_COMMITTAL_ACTION_KINDS := ["idle", "move", "hit_reaction", "stagger", "evade", "chant", "parry_stance"]
# How far a spotter's shout carries. Suspicion, not alert: neighbours turn and look.
const SPOTTER_ROUSE_RADIUS := 320.0
# Elevation existed only in the renderer -- 10 for arrows, 18 for firebolts -- and meant
# nothing to the simulation. It is a gameplay property now, and it is FRIEND-BLIND: while
# a shot is above this it passes over everything standing on the ground, the player
# included. Taken literally that is what "a thrown weapon is airborne" means, and it is
# what produces "clears my allies, spears the player" out of geometry rather than out of
# a friend/foe flag. It is also what makes airborne enemies work later rather than merely
# permitting them: the high phase has to genuinely exist for anything to be in it.
const PROJECTILE_GROUND_ELEVATION := 26.0
# Fire charges you for ACTING. Burn ticks in world seconds, and world time only advances
# while the player is committed to something -- so standing still and thinking is free,
# and a held combo is expensive. That is the whole identity of the element: every other
# threat in the game punishes the wrong action, and this one punishes duration.
const BURN_DAMAGE_PER_SECOND := 11.0
# Rolling smothers it, the way it does everywhere else. This matters beyond flavour:
# Dodge is the one action exhaustion never takes away, so being on fire and winded still
# leaves something executable rather than being a death sentence with no input.
const BURN_DODGE_RELIEF := 1.6
# Frost slows the WHOLE action -- wind-up, active window and recovery -- by scaling
# personal tempo, which is one number already plumbed through all three. They cannot
# drift apart because there is nothing to drift.
const FROST_MAX_SLOW := 0.34
# ...and makes the next hit land harder, which is the release valve: the amplified blow
# consumes the frost, so a frosted player is in danger rather than in a death spiral.
const FROST_DAMAGE_AMPLIFY := 0.55
const FROST_FULL_DURATION := 6.0
# Barriers live OUTSIDE `walls`, so the cached navigation grid is never touched. That is
# safe rather than a concealed bug: `_navigation_direction()` is only ever called from
# enemy movement, and a barrier never blocks enemies -- so a grid ignorant of it is
# correct. The player does not use the A* grid at all.
const EARTH_WALL_SEGMENTS := 6
const EARTH_WALL_SPAN := 340.0
const EARTH_WALL_STANDOFF := 170.0
const EARTH_WALL_DURATION := 4.5
# The player's wall stands far longer than a caster's. They are the same object doing
# opposite jobs: an enemy raises it behind you to tax a retreat you are making right now,
# so it only has to outlive that moment, while the player raises it to build a fight
# around. At 4.5 world-seconds a wall cast at arm's length was gone before it could be
# reached, which is why it read as invisible and as impossible to hit.
const EARTH_WALL_PLAYER_DURATION := 11.0
const EARTH_WALL_THICKNESS := 17.0
const EARTH_WALL_SEGMENT_HP := 10.0
# A high-impact blow destroys a segment outright; anything lighter chips. Earth is the
# element you answer with your weapon rather than your feet, and breaking costs an action
# -- which is time, the thing the wall was taxing in the first place.
const EARTH_WALL_SHATTER_IMPACT := 3.5
# Segments lower near a living enemy and rise again when it is clear. Ratcheting
# permanently open would put the gap wherever an enemy passed EARLIER rather than where
# the danger is, and the wall would decay fastest under exactly the pressure it exists to
# create. Because it is placed in the escape direction, pursuers reach it from the
# player's side: the gap opens where the threat is, and the way out runs through it.
const EARTH_WALL_LOWER_RANGE := 90.0
# A lowered segment does not snap back up the instant its enemy walks on. It used to, and
# that produced the one thing a wall must never be: a wall you cannot see.
#
# The sequence was exact. A pursuer stands near a segment, so the segment lowers to a scar
# on the ground and stops blocking. The player looks at the gap and commits to moving
# through it -- and committing is what advances world time, so the pursuer moves on, the
# segment stands back up on the very next tick, and the player arrives at a wall that was
# flat ground when they chose to walk there. Nothing was mis-drawn; the state the player
# could see had simply stopped being true by the time they got there.
#
# So rising takes a beat, and during that beat the segment is visibly rising and still
# passable. Whatever the player can see is now something they can act on.
const EARTH_WALL_RISE_TIME := 0.75
# And it will not stand up in someone's face. PLAYER_RADIUS alone only refused to rise
# through the player; this refuses to rise within a step of them.
const EARTH_WALL_RISE_CLEARANCE := 46.0

# Arrows stay flat, which gives the two ranged enemies a third axis of difference on top
# of speed and lead. Javelins arc: high early to clear the melee standing near the
# thrower, descending late so they still reach at the far end. The peak sits at roughly
# 38% of range rather than the midpoint, because the bodies to clear are the near ones.
func _projectile_elevation(projectile: Dictionary) -> float:
	if String(projectile.get("elevation_profile", "flat")) != "arc":
		return float(projectile.get("elevation", 10.0))
	var span := maxf(1.0, float(projectile.get("max_range", 600.0)))
	var travelled := clampf(float(projectile.get("travelled", 0.0)) / span, 0.0, 1.0)
	return float(projectile.get("elevation_peak", 78.0)) * sin(PI * pow(travelled, 0.72))
# Mass at which a body stops losing its own authored attack to chip damage. 1.6
# selects Warden, Brute, Knight and Ox and excludes Shield (1.35), Boar (1.25) and
# Polearm (1.15) -- the previous hardcoded list plus the Ox, which had been in
# neither armour list and lost 4 of 4 gores in the 0.2.30 survey.
const HEAVY_TELEGRAPH_MASS := 1.6
# Bodies the player shoves aside rather than stops dead against. 1.35 is the line
# that already decides whether a body reacts to being vaulted, so mass now has one
# meaning throughout: 1.35 and up is a body you cannot move. That leaves Shield,
# Brute, Knight and Ox as the only things in the game that can physically stop you,
# which is their job -- and a Knife can never body-block you again.
const PUSHABLE_MASS := 1.35
# What an attack does is the number written on the attack. There is no translation step.
#
# Until 0.2.60 enemy damage was authored 1-4 and inflated at the point of contact through
# a lookup table, because the bottom of that range was too weak to matter. Bending the
# curve to fix a range that is too narrow is the wrong repair -- the fix is to widen the
# range. Everything else already worked this way: the player's combo is authored 10/15/17
# and enemy health runs 20 to 210, so enemy damage was the last thing on its own scale.
#
# Posture is now authored beside damage rather than derived from it. It used to be
# `damage x 1.5`, which meant re-authoring health silently re-authored stagger; they are
# separate questions, and a Knife should keep chipping posture lightly however hard it
# hits. Sources with no authored posture fall back to this rate.
const POSTURE_PER_DAMAGE := 0.22
# Intelligence is the caster's Strength: Strength adds to physical damage, Intelligence
# subtracts from spell cost. It does NOT add magnitude -- a stat that multiplies every
# spell in the game forces every casting class onto one curve and prevents spells from
# having independent worth, which is the "element is paint" failure the caster design
# exists to avoid. Spell power lives in the spell.
#
# Because a cooldown is `spend / pool x 24`, cutting the cost cuts the cooldown by the
# same proportion. One stat, one effect, and it means the same thing under both rule
# profiles without a second rule.
const INTELLIGENCE_BASELINE := 5
const SPELL_COST_PER_INTELLIGENCE := 0.055
const SPELL_COST_FLOOR := 0.40
# The Circle. A place where your casting is cheaper, and nothing else -- not faster, since
# a speed bonus would reduce the time you stand exposed and so cancel its own price, and
# not stronger, since magnitude belongs to the spell.
#
# 168 is the Earth caster's radius, and it is also exactly how far a Sidestep travels. From
# the centre a Sidestep lands you on the rim and a Long Roll (231) puts you outside, so the
# Evasion track's permanent fork acquires a new meaning for a caster: Sidestep is the form
# that can hold ground.
const CIRCLE_RADIUS := 168.0
const CIRCLE_WIDE_RADIUS := 248.0
const CIRCLE_DURATION := 16.0
const CIRCLE_WIND_UP := 1.5
const CIRCLE_ENERGY := 8.0
const CIRCLE_INTELLIGENCE := 3
# Every spell the Elementalist can learn, and which stage teaches it. Each is an enemy
# ability first; the spellbook is the bestiary.
const ELEMENT_STAGE_SPELLS := AbilityCatalogScript.ELEMENT_STAGE_SPELLS
# Raw cost before Intelligence and before ENERGY_COST_SCALE. The bolt is deliberately the
# cheapest thing a caster can do and the weakest: it is what raw force does before it has
# been shaped into an element, which is why it has no condition, no fork and no terrain.
# Placed spells land where the player tapped; aimed spells only need a heading. The tap
# already carries a world point, and until 0.2.68 that point was reduced to a direction and
# re-projected to a fixed 340 units -- so an Earth Wall could not be put anywhere in
# particular, and in isometric it routinely landed off the visible floor. It was not
# invisible; it was somewhere else.
const SPELL_PLACE_RANGE := AbilityCatalogScript.PLACE_RANGE

static func spell_is_placed(spell_id: String) -> bool:
	return AbilityCatalogScript.spell_is_placed(spell_id)

# How far a spell reaches, for the ring the renderer draws when one is armed. Placed spells
# reach as far as they may be put; the bolt reaches as far as it strikes; everything else is
# a heading rather than a distance and has no ring to draw.
func spell_reach(spell_id: String) -> float:
	return float(AbilityCatalogScript.spell(spell_id).get("reach", 0.0))

func spell_target_for(spell_id: String, world_point: Vector2) -> Vector2:
	if not spell_is_placed(spell_id): return world_point
	var offset := world_point - player_pos
	if offset.length() <= SPELL_PLACE_RANGE: return world_point
	return player_pos + offset.normalized() * SPELL_PLACE_RANGE

# 340 rather than 560. The bolt is the caster's jab -- reliable, cheap, unimpressive -- and
# a jab that reaches most of the arena is the answer to every question in the room. It now
# reaches about as far as a Javelineer throws, so closing on a caster is a real approach
# rather than a formality, and the range is drawn when the spell is armed so the limit is
# something the player can see rather than discover.
const LIGHTNING_RANGE := 340.0
const LIGHTNING_DAMAGE := 11
# A parry costs the player their turn rather than their health. Long enough that the
# rest of the room gets to act inside it, short enough that it is a mistake and not a
# death sentence.
const DUELLIST_PARRY_STAGGER := 0.86
const DUELLIST_PARRY_COOLDOWN := 3.10
# The Chanter's spellbook. One effect at a time, each with its own colour AND its own
# silhouette so the colour is never load-bearing. Every one of them ends the moment
# the Chanter dies -- otherwise killing it first accomplishes nothing retroactively
# and the decision it is supposed to pose has no payoff.
const CHANT_DURATION := 7.0
const CHANT_COOLDOWN := 3.6
const CHANT_STARTUP := 0.78
const CHANT_RADIUS := 300.0
const CHANT_SPEED_SCALE := 1.35
const CHANT_WARD_REDUCTION := 0.45
const CHANT_POISE_BONUS := 2.5
# Sundered ground. It deals no damage at all: crossing it costs TIME, and in frozen
# time spending time is handing every other enemy in the room a free move. That is a
# different currency from the fire and ice zones, which threaten damage instead.
const SUNDERED_SLOW := 0.5
const SUNDERED_RADIUS := 168.0
const SUNDERED_DURATION := 7.5
# The javelin. Slow and wide rather than fast and precise -- it is a lane being taken
# away, not a shot to be feared.
const JAVELIN_SPEED := 360.0
const JAVELIN_RADIUS := 22.0
# The Ox reopening its own charge lane. Reversing is itself a charge so the wind-up
# inherits the same armour a gore has; the cap keeps it a repositioning step rather
# than a retreat.
const OX_DISENGAGE_STARTUP := 0.34
const OX_DISENGAGE_SPEED := 430.0
const OX_DISENGAGE_CAP := 190.0
# The screen. Its guard radius is the zone it contests; its station is measured from
# the ward rather than from the player. Patience is per-instance and spans a few
# seconds of standoff, so its temper cannot be counted the way a fixed timer could.
# How far away an ally can be and still be something a role is covering. Unbounded,
# _ally_anchor averaged every matching enemy on the layer -- on a generated floor a
# Shield picked a ward 11,754 units away and steered off the navigation grid. A role
# covers what it can stand in front of.
const ROLE_ANCHOR_RADIUS := 420.0
const SHIELD_GUARD_RADIUS := 150.0
const SHIELD_WARD_STATION := 104.0
const SHIELD_STRIKE_WINDUP := 0.46
const SHIELD_PATIENCE_MIN := 2.6
const SHIELD_PATIENCE_MAX := 4.4
# Exported because the renderer needs the same list. It previously kept its own copy
# of four states while this one grew to six, so a staggered Shield drew its guard back
# up while the simulation still treated it as open -- you hit a raised shield, which
# the 0.2.38 survey reported. One list, one source.
const SHIELD_OPEN_ACTION_KINDS := ["melee", "dodge_strike", "charge", "slam", "hit_reaction", "stagger"]
const EXHAUSTED_MOVE_SCALE := 0.45
const DODGE_ENERGY_COST := 18.0
# The desperate Dodge: reachable while exhausted, because a hit must always leave
# one executable response. 90 units of travel clears a Blade's envelope (68) and
# little else, the i-frame window is two thirds of a real Dodge's, and the tail is
# longer. Taking it re-empties the bar and restarts the exhaustion clock at the
# same flat duration -- the cost compounds by repetition, not by escalation.
const EXHAUSTED_DODGE_SPEED := 450.0
const EXHAUSTED_DODGE_DURATION := 0.75
# World-time tail past return of control during which a fresh hit still damages
# the player but cannot interrupt the response they chose. Long enough to commit
# one deliberate action -- a Dodge's i-frames open at 0.08 -- and deliberately too
# short to cover an offensive sequence. Provisional; see the handoff section 5.4.
const POST_HIT_PROTECTION_TAIL := 0.35
# "hit_reaction" and "stagger" are deliberately absent. Player posture recovery
# already excludes them, so energy regenerating through a flinch had the two
# resources disagreeing about whether being hit is a chance to recover.
# What counts as an enemy having committed to hurting you. Used by the threat
# snapshot, so a caster mid-cone reads as danger the same way a Blade mid-swing does.
# Player actions that are a swing at something -- what a Bandit reads to know it is
# being attacked. Kept beside the enemy list so the two stay recognisably a pair.
const PLAYER_ATTACK_ACTION_KINDS := AbilityCatalogScript.PLAYER_ATTACK_ACTION_KINDS
const ENEMY_ATTACK_ACTION_KINDS := AbilityCatalogScript.ENEMY_ATTACK_ACTION_KINDS
const ENERGY_REGEN_ACTIONS := AbilityCatalogScript.ENERGY_REGEN_ACTION_KINDS
const SAVE_VERSION := 35
const GAME_VERSION := "0.2.81"
const SURVEY_GENERATOR_VERSION := 3
const PRESENTATION_VERSION := 9
const SWORD_ARTS := ["prototype_sweeping_cut", "prototype_drawing_cut"]
const HEALING_CAPACITY := 5
const CONSUMABLE_SLOT_COUNT := 3
const COOLDOWN_DODGE := "dodge"
const COOLDOWN_BLOCK := "block"
const COOLDOWN_ENDURE := "endure"
const COOLDOWN_SKILL := "skill"
const COOLDOWN_RALLY := "rally"
const COOLDOWN_ADVANCE := "advance"
const COOLDOWN_MAIN := "main_ability"
const COOLDOWN_SUBCLASS := "subclass_ability"
const COOLDOWN_WEAPON_SEQUENCE := "weapon_sequence"
const COOLDOWN_SPELL := "spell"
const COOLDOWN_SLOT_DEFAULTS := {
	COOLDOWN_DODGE: DODGE_COOLDOWN, COOLDOWN_BLOCK: BLOCK_COOLDOWN, COOLDOWN_ENDURE: ENDURE_COOLDOWN,
	COOLDOWN_SKILL: 6.5, COOLDOWN_RALLY: 12.0, COOLDOWN_ADVANCE: 6.0,
	COOLDOWN_MAIN: 12.0, COOLDOWN_SUBCLASS: 8.0,
	COOLDOWN_WEAPON_SEQUENCE: 0.0001, COOLDOWN_SPELL: 8.0,
}
const CONSUMABLES := {
	"throwing_knife": {"label": "Throwing Knife", "short": "KNIFE", "targeted": true, "max_stack": 2, "color": "d7dddd"},
	"firebomb": {"label": "Firebomb", "short": "FIRE", "targeted": true, "max_stack": 2, "color": "f28b4b"},
	"smoke_vial": {"label": "Smoke Vial", "short": "SMOKE", "targeted": false, "max_stack": 1, "color": "9ca9bd"},
}

var player_pos := Vector2(800.0, 1900.0)
var player_facing := Vector2.UP
var player_hp := PLAYER_MAX_HP
var player_max_hp := PLAYER_MAX_HP
var player_energy := 100.0
var player_max_energy := 100.0
var player_overexertion_pending := false
var player_exhaustion_remaining := 0.0
var player_energy_regen_delay := 0.0
var player_posture := 12.0
var player_posture_max := 12.0
var player_posture_recovery_delay := 0.0
var player_move_speed := MOVE_SPEED
var player_attack_duration := 1.20
var player_attack_startup := 0.38
var player_attack_active_end := 0.68
var player_damage_min := 2
var player_damage_max := 3
var player_attack_technique := "diagonal_cut"
var player_attack_reach := 136.0
var player_attack_posture := 2.0
var loadout_id := "warrior"
var defense_id := "dodge"
# Player loadouts are still temporary prototypes. These shared fields are the
# durable actor foundation that future character sheets and weapon swapping use.
var player_attributes: Dictionary = {}
var player_properties: Dictionary = {}
var martial_foundation: Dictionary = {}
var player_weapon_frame := "sword"
var player_weapon_art_library: Array[String] = []
var player_equipped_weapon_art := ""
var equipment_slots: Dictionary = {}
var track_property_ranks: Dictionary = {}
var track_ranks: Dictionary = {}
var track_choices: Dictionary = {}
var player_action := _idle_action()
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var walls: Array[Rect2] = []
var cooldowns: Dictionary = _new_cooldown_slots()
var dodge_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_DODGE)
	set(value): _set_cooldown_remaining(COOLDOWN_DODGE, value)
var block_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_BLOCK)
	set(value): _set_cooldown_remaining(COOLDOWN_BLOCK, value)
var endure_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_ENDURE)
	set(value): _set_cooldown_remaining(COOLDOWN_ENDURE, value)
var skill_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_SKILL)
	set(value): _set_cooldown_remaining(COOLDOWN_SKILL, value)
var rally_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_RALLY)
	set(value): _set_cooldown_remaining(COOLDOWN_RALLY, value)
var advance_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_ADVANCE)
	set(value): _set_cooldown_remaining(COOLDOWN_ADVANCE, value)
var main_ability_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_MAIN)
	set(value): _set_cooldown_remaining(COOLDOWN_MAIN, value)
var subclass_ability_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_SUBCLASS)
	set(value): _set_cooldown_remaining(COOLDOWN_SUBCLASS, value)
var weapon_sequence_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_WEAPON_SEQUENCE)
	set(value): _set_cooldown_remaining(COOLDOWN_WEAPON_SEQUENCE, value)
var stealth_remaining := 0.0
var stealth_cooldown_pending := false
# What this hide has cost so far. Accrues in BOTH profiles: Recovery never deducts it
# but derives the cooldown from it, which is how a cancelled hide gets a short one.
var stealth_energy_paid := 0.0
var _stealth_last_ended_at := -1.0
# How often each arrangement has been drawn this run. Left to chance, one run gave
# column four rooms and screen_line none -- and the whole reason for authoring
# formations was to find out which ones work, which needs each of them played.
var _formation_use_counts: Dictionary = {}
# Why the last hide ended. "expired" is the only outcome the player paid for in full.
var stealth_last_end_reason := ""
# The last amount _spend_energy actually priced, so a cooldown can be derived from
# the cost sitting two lines above it instead of from a duplicated literal.
var _last_energy_spend := 0.0
# What each cooldown started at, so the readiness bar is drawn against the real
# maximum rather than against a hardcoded guess that derived values now break.
var skill_cooldown_max: float:
	get: return cooldown_maximum(COOLDOWN_SKILL)
	set(value): _set_cooldown_maximum(COOLDOWN_SKILL, value)
var advance_cooldown_max: float:
	get: return cooldown_maximum(COOLDOWN_ADVANCE)
	set(value): _set_cooldown_maximum(COOLDOWN_ADVANCE, value)
var main_ability_cooldown_max: float:
	get: return cooldown_maximum(COOLDOWN_MAIN)
	set(value): _set_cooldown_maximum(COOLDOWN_MAIN, value)
var subclass_ability_cooldown_max: float:
	get: return cooldown_maximum(COOLDOWN_SUBCLASS)
	set(value): _set_cooldown_maximum(COOLDOWN_SUBCLASS, value)
# How long a ranged body survives before the player is standing on top of it. "An
# archer that spawns next to me is just a blob I have to hit before fighting the rest
# of the room" -- that is a claim about time, and until now it was unmeasurable.
# A bow run produced `Strike diagnostics: 0` in every room, because the strike log is
# built from a melee sector and a projectile has none. The Sharpshooter was the class we
# could see least, and the one carrying an open "might be too strong" against it.
# Friendly fire only happens when something changed after commitment, so counting it is
# how we find out whether that ever actually occurs in play rather than on paper.
# Three versions of "the wall is invisible" have now been diagnosed from the code and two
# of those diagnoses were wrong. Both walls render correctly in isolation and the camera
# cull keeps them at every distance the player can touch one, so the next theory needs
# evidence rather than another reading of the source. These count what actually happened:
# how many walls went up, and how many times the player was physically stopped by one.
# A run that reports collisions the player never saw is a rendering fault; a run that
# reports none while the player insists they hit something means they hit terrain and the
# Earth Caster was a coincidence.
# Counts how often the player was stopped by a body they could not see. It should sit at
# zero once rooms stop hiding solid objects in the player's path; while it does not, it is
# the measure of how often the room lies about what is in front of you.
var survey_blind_collisions := 0
var survey_barriers_raised := 0
var survey_barrier_blocks := 0
var survey_javelins_grounded := 0
var survey_stray_projectile_hits := 0
var survey_shots_fired := 0
var survey_shots_hit := 0
var survey_shots_blocked := 0
var survey_reach_times: Array[Dictionary] = []
var survey_stealth_entries_total := 0
var survey_stealth_cancels_total := 0
var survey_stealth_quick_reentries_total := 0
var survey_stealth_hidden_time_total := 0.0
var survey_stealth_energy_paid_total := 0.0
var assassination_window_remaining := 0.0
var turnabout_remaining := 0.0
# Counts down in world time from the moment a hit reaction begins, through the
# reaction and on past return of control. It is armed once per reaction and never
# refreshed by the hits it protects against, so standing in a crowd cannot make
# the player progressively harder to interrupt.
var player_hit_protection_remaining := 0.0
var aimed_enemy_id := -1
var aimed_remaining := 0.0
var bow_followup_ready := false
var bow_followup_consumed := false
var barriers: Array[Dictionary] = []
var player_gale_velocity := Vector2.ZERO
var circle_pos := Vector2.ZERO
var circle_remaining := 0.0
# Learned spells, in the order they were learned. The Elementalist starts with the bolt and
# adds one element per subclass rank, so this is never empty and never longer than five.
var player_spells: Array[String] = []
var selected_spell := ""
var spell_cooldown: float:
	get: return cooldown_remaining(COOLDOWN_SPELL)
	set(value): _set_cooldown_remaining(COOLDOWN_SPELL, value)
var spell_cooldown_max: float:
	get: return cooldown_maximum(COOLDOWN_SPELL)
	set(value): _set_cooldown_maximum(COOLDOWN_SPELL, value)
var survey_circle_casts := 0
var survey_spell_counts: Dictionary = {}
var player_condition_buildup: Dictionary = {}
# How much of the frost still stands, 0..1. Read by tempo, by the damage amplifier and by
# the meter, so all three agree by construction.
func player_frost_fraction() -> float:
	return clampf(float(player_conditions.get("frost", 0.0)) / FROST_FULL_DURATION, 0.0, 1.0)

func player_burn_fraction() -> float:
	return clampf(float(player_conditions.get("burning", 0.0)) / 4.0, 0.0, 1.0)

func player_condition_charge(condition_id: String) -> float:
	var threshold := _condition_threshold(condition_id, int(player_attributes.get("resistance", 5)))
	return clampf(float(player_condition_buildup.get(condition_id, 0.0)) / maxf(1.0, threshold), 0.0, 1.0)
var player_conditions: Dictionary = {}
var _condition_tick_accumulator := 0.0
# Burn is charged per world-second but health is an integer, so the fraction is carried
# rather than rounded away -- otherwise a short action would cost nothing at all.
var _player_burn_debt := 0.0
var survey_burn_damage_total := 0
var survey_frost_amplified_hits := 0
var rally_remaining := 0.0
var rally_end_after_action := false
var rally_break_extension_used := false
var building_force_chain := 0
var counterstep_remaining := 0.0
var strength_remaining := 0.0
var potions := HEALING_CAPACITY
var consumable_slots: Array[Dictionary] = []
var world_pickups: Array[Dictionary] = []
var pending_pickup: Dictionary = {}
var trial_complete := false
var run_seed := 739391
var upgrades: Array[String] = []
var upgrade_choices: Array[String] = []
var upgrade_pending := false
var rooms_cleared := 0
var enemies_defeated := 0
var damage_dealt := 0
var hazards: Array[Dictionary] = []
var simulation_time := 0.0
var perfect_dodges := 0
var counter_hits := 0
var successful_blocks := 0
var successful_endures := 0
var damage_received_total := 0
var hits_received_total := 0
# Milestone B telemetry. `protected_damage_total` is damage taken while post-hit
# protection was active; `interruptions_prevented_total` counts hits that would
# have replaced the player's action with a fresh reaction and did not. The handoff
# section 5.4 asks for these to be distinguishable -- protection guarantees agency,
# not safety, and only the first number shows the price being paid for it.
var protected_damage_total := 0
var interruptions_prevented_total := 0
# Capture telemetry. One record per hostile melee attack that resolves, so the
# authored walk-safe fraction can be checked against what players actually
# achieve instead of being trusted from theory. `f_observed` is the direct
# measurement of the timing curve attack capture exists to create.
var survey_attack_records: Array = []
# Clean evasion by source. Ordinary movement no longer earns credit, so these
# answer whether Dodge and Vault still raise the event often enough for the
# Acrobat's Turnabout to remain worth its rank.
var clean_evade_dodge_total := 0
var clean_evade_vault_total := 0
var turnabout_primed_total := 0
var turnabout_consumed_total := 0
var potions_used_total := 0
var energy_spent_total := 0.0
var energy_depleted_total := 0.0
var energy_overdraw_total := 0.0
var energy_regenerated_total := 0.0
var energy_regen_delay_time_total := 0.0
var energy_regen_active_time_total := 0.0
var overexertion_count := 0
var winded_time_total := 0.0
var energy_blocked_continuations := 0
var exhaustion_damage_received_total := 0
var exhaustion_move_time_total := 0.0
var exhaustion_wait_time_total := 0.0
var exhaustion_other_time_total := 0.0
var exhausted_dodge_total := 0
var exhausted_dodge_chain := 0
var exhausted_dodge_max_chain := 0
var exhaustion_start_samples := 0
var exhaustion_start_alerted_sum := 0
var exhaustion_start_clear := 0
var exhaustion_start_pending := 0
var exhaustion_start_reacting_sum := 0
var exhaustion_end_samples := 0
var exhaustion_end_alerted_sum := 0
var exhaustion_end_clear := 0
var exhaustion_start_soonest_sum := 0.0
var exhaustion_start_nearest_sum := 0.0
var energy_starved_time_total := 0.0
var energy_combo_starved_time_total := 0.0
var exhaustion_threatened_time_total := 0.0
var exhausted_dodge_room_max_chain := 0
var terminal_combo_recoveries_total := 0
var terminal_combo_recovery_time_total := 0.0
var direct_attack_uses_total := 0
var dodge_style_uses_total: Dictionary = {}
var dodge_vulnerable_time_total := 0.0
var dodge_recovery_damage_total := 0
var effects: Array[Dictionary] = []
var message := "Time is frozen. Choose an action."
var last_timeline: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var _next_enemy_id := 1
var _next_presentation_id := 1
var navigation := AStarGrid2D.new()
var run_active := false
var mode_id := ModeRulesScript.EXPEDITION
var mode_config: Dictionary = ModeRulesScript.definition(mode_id)
var progression_mode := "area_exit"
var map_presentation := "full"
var areas: Array[Dictionary] = []
var connections: Array[Dictionary] = []
var route_recipe: Array[Dictionary] = []
var run_graph: Dictionary = {}
var locale_catalog: Dictionary = {}
var floor_shapes: Array[Dictionary] = []
var terrain_features: Array[Dictionary] = []
var geometry_style := "rooms"
var world_size := WORLD_SIZE
var waystones: Array[Dictionary] = []
var shortcuts: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
var secret_passages: Array[Dictionary] = []
var world_layers: Dictionary = {}
var current_layer := "expedition_surface"
var active_waystone_id := ""
var encounter_templates: Dictionary = {}
var base_walls: Array[Rect2] = []
var base_walls_by_layer: Dictionary = {}
var bonfire_pos := Vector2.ZERO
var shortcut_gate := Rect2()
var shortcut_unlock_pos := Vector2.ZERO
var shortcut_start_pos := Vector2.ZERO
var shortcut_unlocked := false
var visible_cells: Dictionary = {}
var discovered_cells: Dictionary = {}
var discovered_cells_by_layer: Dictionary = {}
var _visibility_anchor := Vector2.INF
var _visibility_anchor_cell := Vector2i(-999999, -999999)
var _visibility_opaque_cells: Dictionary = {}
var visibility_revision := 0
var discovery_revision := 0
var discovery_epoch := 0
var discovery_log: Array[Vector2i] = []
var world_render_revision := 0
var current_area_id := 0
var carried_xp := 0
var secured_xp := 0
var lost_xp := {"active": false, "amount": 0, "pos": Vector2.ZERO}
var death_report: Dictionary = {}
var last_anchor_report: Dictionary = {}
var upgrade_count := 0
var upgrade_ranks: Dictionary = {}
var death_pending := false
var run_failed := false
var upgrade_context := ""
var anchor_state: Dictionary = {}
var _sound_sequence := 0
var last_sound := {"sequence": 0, "pos": Vector2.ZERO, "radius": 0.0}
var _defense_cooldown_multiplier := 1.0
var _skill_cooldown_multiplier := 1.0
var _player_start := Vector2.ZERO
var _boss_defeated := false
var loaded_region_ids: Dictionary = {}
var loaded_terrain_features: Array[Dictionary] = []
var _loaded_floor_shapes: Array[Dictionary] = []
var _wall_buckets: Dictionary = {}
var _shape_buckets_by_layer: Dictionary = {}
var _enemy_buckets: Dictionary = {}
var _enemy_bucket_cell_by_id: Dictionary = {}
var _enemy_spatial_cache_dirty := true
var _terrain_feature_buckets: Dictionary = {}
var _player_reaction_completed_this_tick := false
var _streamed_enemy_indices := PackedInt32Array()
var _active_enemy_cache_dirty := true
var _flow_target_cell := Vector2i(-999999, -999999)
var _flow_next_cell: Dictionary = {}
var _navigation_cache: Dictionary = {}
var performance_metrics := {
	"last_action_ms": 0.0,
	"last_save_ms": 0.0,
	"last_save_payload_ms": 0.0,
	"last_save_write_ms": 0.0,
	"last_save_bytes": 0,
	"timeline_frames": 0,
	"active_enemies": 0,
	"resident_enemies": 0,
	"loaded_regions": 0,
	"simulation_ms": 0.0,
	"snapshot_ms": 0.0,
	"draw_cpu_ms": 0.0,
	"worst_frame_ms": 0.0,
	"visibility_ms": 0.0,
	"visibility_cells": 0,
	"presentation_capture_ms": 0.0,
	"dropped_realtime_ms": 0.0,
	"navigation_build_ms": 0.0,
	"navigation_cache_hit": false,
	"navigation_prewarm_ms": 0.0,
}
var _profile_action_count := 0
var _streamed_action_cpu_usec := 0
var _simulation_tick_index := 0
var _next_combo_instance_id := 1
var survey_profile := "encounter"
var combat_rules := "energy"
var survey_room_number := 0
# A custom room is a Combat Survey room whose roster and arrangement are chosen rather
# than drawn. It is deliberately NOT a separate mode: keeping it inside the survey means
# the report, the archive, the ratings prompt and the character sheet all work unchanged,
# and a custom room can be compared against a generated one without a second instrument.
#
# `kinds` may hold literal enemy ids and two tokens: CUSTOM_RANDOM picks any kind,
# CUSTOM_RANDOM_NEW picks one not yet used in this session -- which is the answer to the
# Chanter spending a whole version unplayed because nothing ever drew it.
const CUSTOM_RANDOM := "__random__"
const CUSTOM_RANDOM_NEW := "__random_new__"
var custom_room_kinds: Array[String] = []
var custom_room_formation := ""
var custom_room_hp_percent := 1.0
var custom_room_xp := 0
# A custom room is an instrument, and an instrument answers one question at a time. It used
# to roll straight into a second room and a third, so testing one composition meant ending
# the run by hand every time. One room and then the end screen is the default; repeating is
# something you ask for.
var custom_room_repeat := false
var custom_room_used_kinds: Dictionary = {}
var custom_room_last_roster: Array[String] = []
var survey_room_seed := 0
var survey_feedback_pending := false
var survey_run_ending := false
var survey_end_reason := ""
var survey_room_definition: Dictionary = {}
var survey_room_entry: Dictionary = {}
var survey_pending_record: Dictionary = {}
var survey_session: Dictionary = {}
var survey_last_report: Dictionary = {}
var survey_action_counts: Dictionary = {}
var survey_last_damage_source := ""
var survey_current_view_mode := "isometric"
var survey_room_view_modes: Array[String] = ["isometric"]
var survey_view_switches := 0
var survey_empty_melee_contacts := 0
# Four separate 0.2.37 notes said the same thing -- "archers were non-factors", "enemies
# in different corners", "I easily picked enemies off one by one", "I did not need to
# fight mobs a single time". Nothing in the report could confirm or refute it, and two
# plausible explanations (formation spread, spawn clustering) were tested against the
# archive and both turned out to be confounds for composition. So measure it directly
# rather than guessing a third time.
var survey_engagement_samples := 0
var survey_engagement_alerted_sum := 0
var survey_engagement_multi_samples := 0
var survey_isolated_kills := 0
var survey_engaged_kills := 0
const CROWDING_COMFORT_DISTANCE := 118.0
var survey_crowding_samples := 0
var survey_crowding_nearest_sum := 0.0
var survey_crowding_close_samples := 0
var survey_misdirected_ally_hits := 0
var survey_interruption_events: Array[Dictionary] = []
var survey_strike_diagnostics: Array[Dictionary] = []

func _init(auto_start: bool = true) -> void:
	rng.seed = run_seed
	_apply_loadout()
	player_hp = player_max_hp
	player_energy = player_max_energy
	# Headless systems and legacy regressions that instantiate an immediate run
	# retain the established recovery model. The actual setup screen explicitly
	# selects Energy for normal play and exposes both rules in Combat Survey.
	if auto_start: start_run(loadout_id, mode_id, run_seed, "encounter", "recovery")

func build_laboratory() -> void:
	start_run(loadout_id, ModeRulesScript.CAMPAIGN_LAB, run_seed)

func build_expedition_room() -> void:
	start_run(loadout_id, ModeRulesScript.EXPEDITION, run_seed)

func start_run(chosen_loadout: String, chosen_mode: String, seed_override: int = -1, survey_profile_override: String = "encounter", combat_rules_override: String = "energy") -> void:
	loadout_id = chosen_loadout if CombatCatalogScript.loadout_ids().has(chosen_loadout) else "warrior"
	mode_id = ModeRulesScript.normalize(chosen_mode)
	mode_config = ModeRulesScript.definition(mode_id)
	progression_mode = String(mode_config["upgrade_policy"])
	survey_profile = survey_profile_override if survey_profile_override in ["encounter", "attrition"] else "encounter"
	combat_rules = normalize_combat_rules(combat_rules_override)
	if seed_override >= 0: run_seed = seed_override
	else: run_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	_apply_loadout()
	player_hp = player_max_hp
	player_energy = player_max_energy
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_energy_regen_delay = 0.0
	_refresh_player_posture_capacity(true)
	player_facing = Vector2.UP
	player_action = _idle_action()
	dodge_cooldown = 0.0
	block_cooldown = 0.0
	endure_cooldown = 0.0
	skill_cooldown = 0.0
	rally_cooldown = 0.0
	advance_cooldown = 0.0
	main_ability_cooldown = 0.0
	subclass_ability_cooldown = 0.0
	weapon_sequence_cooldown = 0.0
	stealth_remaining = 0.0
	stealth_cooldown_pending = false
	stealth_energy_paid = 0.0
	_stealth_last_ended_at = -1.0
	_formation_use_counts.clear()
	_last_energy_spend = 0.0
	skill_cooldown_max = 6.5
	advance_cooldown_max = 6.0
	main_ability_cooldown_max = 12.0
	subclass_ability_cooldown_max = 8.0
	assassination_window_remaining = 0.0
	turnabout_remaining = 0.0
	player_hit_protection_remaining = 0.0
	aimed_enemy_id = -1
	aimed_remaining = 0.0
	player_condition_buildup.clear()
	player_conditions.clear()
	barriers.clear()
	circle_remaining = 0.0
	player_gale_velocity = Vector2.ZERO
	spell_cooldown = 0.0
	_player_burn_debt = 0.0
	bow_followup_ready = false
	bow_followup_consumed = false
	_condition_tick_accumulator = 0.0
	_next_combo_instance_id = 1
	_next_presentation_id = 1
	rally_remaining = 0.0
	rally_end_after_action = false
	rally_break_extension_used = false
	building_force_chain = 0
	counterstep_remaining = 0.0
	strength_remaining = 0.0
	potions = healing_capacity()
	consumable_slots = _empty_consumable_slots()
	world_pickups.clear()
	pending_pickup.clear()
	trial_complete = false
	upgrade_pending = false
	upgrade_choices.clear()
	upgrades.clear()
	upgrade_ranks.clear()
	track_property_ranks.clear()
	track_ranks = _empty_character_track_ranks()
	track_choices.clear()
	upgrade_count = 0
	upgrade_context = ""
	_defense_cooldown_multiplier = 1.0
	_skill_cooldown_multiplier = 1.0
	_sound_sequence = 0
	last_sound = {"sequence": 0, "pos": Vector2.ZERO, "radius": 0.0}
	carried_xp = 0
	secured_xp = 0
	lost_xp = {"active": false, "amount": 0, "pos": Vector2.ZERO}
	death_report.clear()
	last_anchor_report.clear()
	rooms_cleared = 0
	current_area_id = -1
	enemies_defeated = 0
	damage_dealt = 0
	simulation_time = 0.0
	_simulation_tick_index = 0
	_navigation_cache.clear()
	perfect_dodges = 0
	counter_hits = 0
	successful_blocks = 0
	successful_endures = 0
	damage_received_total = 0
	hits_received_total = 0
	protected_damage_total = 0
	interruptions_prevented_total = 0
	survey_attack_records.clear()
	clean_evade_dodge_total = 0
	clean_evade_vault_total = 0
	turnabout_primed_total = 0
	turnabout_consumed_total = 0
	potions_used_total = 0
	energy_spent_total = 0.0
	energy_depleted_total = 0.0
	energy_overdraw_total = 0.0
	energy_regenerated_total = 0.0
	energy_regen_delay_time_total = 0.0
	energy_regen_active_time_total = 0.0
	overexertion_count = 0
	winded_time_total = 0.0
	energy_blocked_continuations = 0
	exhaustion_damage_received_total = 0
	exhaustion_move_time_total = 0.0
	exhaustion_wait_time_total = 0.0
	exhaustion_other_time_total = 0.0
	exhausted_dodge_total = 0
	exhausted_dodge_chain = 0
	exhausted_dodge_max_chain = 0
	exhaustion_start_samples = 0
	exhaustion_start_alerted_sum = 0
	exhaustion_start_clear = 0
	exhaustion_start_pending = 0
	exhaustion_start_reacting_sum = 0
	exhaustion_end_samples = 0
	exhaustion_end_alerted_sum = 0
	exhaustion_end_clear = 0
	exhaustion_start_soonest_sum = 0.0
	exhaustion_start_nearest_sum = 0.0
	energy_starved_time_total = 0.0
	energy_combo_starved_time_total = 0.0
	exhaustion_threatened_time_total = 0.0
	exhausted_dodge_room_max_chain = 0
	terminal_combo_recoveries_total = 0
	survey_reach_times.clear()
	survey_stray_projectile_hits = 0
	survey_javelins_grounded = 0
	survey_barriers_raised = 0
	survey_blind_collisions = 0
	survey_barrier_blocks = 0
	survey_burn_damage_total = 0
	survey_frost_amplified_hits = 0
	survey_shots_fired = 0
	survey_shots_hit = 0
	survey_shots_blocked = 0
	survey_stealth_entries_total = 0
	survey_stealth_cancels_total = 0
	survey_stealth_quick_reentries_total = 0
	survey_stealth_hidden_time_total = 0.0
	survey_stealth_energy_paid_total = 0.0
	terminal_combo_recovery_time_total = 0.0
	direct_attack_uses_total = 0
	dodge_style_uses_total.clear()
	dodge_vulnerable_time_total = 0.0
	dodge_recovery_damage_total = 0
	survey_room_number = 1 if mode_id == ModeRulesScript.COMBAT_SURVEY else 0
	custom_room_used_kinds.clear()
	custom_room_last_roster.clear()
	# Granted once, and spent through the character sheet the player already uses. That
	# is what "pick by hand" costs: no bespoke track picker, just enough XP to buy the
	# build being tested.
	if _custom_room_active(): carried_xp += custom_room_xp
	survey_room_seed = 0
	survey_feedback_pending = false
	survey_run_ending = false
	survey_end_reason = ""
	survey_room_definition.clear()
	survey_room_entry.clear()
	survey_pending_record.clear()
	survey_last_report.clear()
	survey_action_counts.clear()
	survey_last_damage_source = ""
	survey_room_view_modes.assign([survey_current_view_mode])
	survey_view_switches = 0
	survey_empty_melee_contacts = 0
	survey_engagement_samples = 0
	survey_engagement_alerted_sum = 0
	survey_spell_counts.clear()
	survey_crowding_samples = 0
	survey_crowding_nearest_sum = 0.0
	survey_crowding_close_samples = 0
	survey_misdirected_ally_hits = 0
	survey_interruption_events.clear()
	survey_engagement_multi_samples = 0
	survey_isolated_kills = 0
	survey_engaged_kills = 0
	survey_strike_diagnostics.clear()
	survey_session = {
		"format_version": SurveyReportScript.FORMAT_VERSION,
		"game_version": GAME_VERSION,
		"generator_version": SURVEY_GENERATOR_VERSION,
		"presentation_version": PRESENTATION_VERSION,
		"run_seed": run_seed,
		"profile": survey_profile,
		"combat_rules": combat_rules,
		"loadout": CombatCatalogScript.loadout_name(loadout_id),
		"started_at": Time.get_datetime_string_from_system(false, true),
		"ended_at": "",
		"end_reason": "",
		"rooms": [],
	} if mode_id == ModeRulesScript.COMBAT_SURVEY else {}
	effects.clear()
	hazards.clear()
	projectiles.clear()
	death_pending = false
	run_failed = false
	anchor_state.clear()
	shortcut_unlocked = false
	_boss_defeated = false
	rng.seed = run_seed
	var layout: Dictionary = _generate_survey_layout(survey_room_number) if mode_id == ModeRulesScript.COMBAT_SURVEY else FloorGeneratorScript.generate(run_seed, bool(mode_config["waystone_available"]))
	world_size = Vector2(layout.get("world_size", WORLD_SIZE))
	geometry_style = String(layout.get("geometry_style", "rooms"))
	areas.assign(Array(layout["areas"]).duplicate(true))
	connections.assign(Array(layout["connections"]).duplicate(true))
	route_recipe.assign(Array(layout.get("route_recipe", [])).duplicate(true))
	run_graph = Dictionary(layout.get("run_graph", {})).duplicate(true)
	locale_catalog = Dictionary(layout.get("locale_catalog", {})).duplicate(true)
	floor_shapes.assign(Array(layout.get("floor_shapes", [])).duplicate(true))
	terrain_features.assign(Array(layout.get("terrain_features", [])).duplicate(true))
	world_pickups.assign(Array(layout.get("pickups", [])).duplicate(true))
	waystones.assign(Array(layout.get("waystones", [])).duplicate(true))
	shortcuts.assign(Array(layout.get("shortcuts", [])).duplicate(true))
	transitions.assign(Array(layout.get("transitions", [])).duplicate(true))
	secret_passages.assign(Array(layout.get("secret_passages", [])).duplicate(true))
	world_layers = Dictionary(layout.get("layers", {})).duplicate(true)
	encounter_templates = Dictionary(layout["encounters"]).duplicate(true)
	base_walls_by_layer = Dictionary(layout.get("layer_walls", {})).duplicate(true)
	bonfire_pos = Vector2(layout["bonfire_pos"])
	active_waystone_id = String(waystones[0]["id"]) if not waystones.is_empty() else ""
	current_layer = String(waystones[0]["layer"]) if not waystones.is_empty() else "survey_arena" if mode_id == ModeRulesScript.COMBAT_SURVEY else "expedition_surface"
	if base_walls_by_layer.is_empty(): base_walls_by_layer[current_layer] = Array(layout["base_walls"]).duplicate()
	_player_start = Vector2(layout["player_start"])
	player_pos = _player_start
	shortcut_gate = Rect2(layout["shortcut_gate"])
	shortcut_unlock_pos = Vector2(layout["shortcut_unlock_pos"])
	shortcut_start_pos = Vector2(layout["shortcut_start_pos"])
	discovered_cells.clear()
	discovered_cells_by_layer.clear()
	discovery_revision += 1
	discovery_epoch += 1
	discovery_log.clear()
	world_render_revision += 1
	for layer_id in world_layers: discovered_cells_by_layer[String(layer_id)] = {}
	discovered_cells_by_layer[current_layer] = discovered_cells
	visible_cells.clear()
	_visibility_anchor = Vector2.INF
	_visibility_anchor_cell = Vector2i(-999999, -999999)
	_build_shape_spatial_index()
	current_area_id = _area_id_at_position(player_pos, current_layer)
	_respawn_enemies()
	_apply_shortcut_world_state()
	run_active = true
	_update_exploration(true)
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		_capture_survey_room_entry()
		SurveyReportScript.save_current(survey_session)
		message = "Combat Survey room 1. %s" % _combat_rules_intro()
	elif bool(mode_config["waystone_available"]):
		_capture_anchor_history()
		message = "The Waystone anchors this moment. %s" % _combat_rules_intro()
	else:
		message = "The expedition begins. %s" % _combat_rules_intro()
	last_timeline.clear()
	changed.emit()
	message_changed.emit(message)

func _generate_survey_layout(room_number: int) -> Dictionary:
	survey_room_seed = _survey_seed_for_room(room_number)
	var room_rng := RandomNumberGenerator.new()
	room_rng.seed = survey_room_seed
	var pacing_phase := _survey_pacing_phase(room_number)
	var threat_band := _survey_threat_band(pacing_phase, room_rng)
	var composition := _custom_room_composition(room_rng) if _custom_room_active() else _survey_composition(room_rng, room_number, threat_band, pacing_phase)
	var arena_ids := ["open_ring", "central_cover", "broken_sightline", "split_approach", "scattered_cover", "wide_lane"]
	var arena_id := String(arena_ids[room_rng.randi_range(0, arena_ids.size() - 1)])
	var enemy_plan: Array = composition.get("enemies", [])
	var layer := "survey_arena"
	var center := SURVEY_ARENA_CENTER
	var player_start := Vector2(850.0, 1080.0)
	var walls_for_layer: Array[Rect2] = []
	var features: Array[Dictionary] = []
	var obstacle_rects: Array[Rect2] = []
	match arena_id:
		"central_cover": obstacle_rects = [Rect2(735, 555, 230, 150)]
		"broken_sightline": obstacle_rects = [Rect2(505, 485, 105, 250), Rect2(1090, 485, 105, 250)]
		"split_approach": obstacle_rects = [Rect2(680, 430, 95, 305), Rect2(925, 430, 95, 305)]
		"scattered_cover": obstacle_rects = [Rect2(500, 560, 110, 95), Rect2(1050, 430, 110, 95), Rect2(955, 805, 115, 90)]
		"wide_lane": obstacle_rects = [Rect2(365, 430, 90, 420), Rect2(1245, 430, 90, 420)]
		_: obstacle_rects = []
	for obstacle in obstacle_rects:
		walls_for_layer.append(obstacle)
		features.append({"kind": "ancient_ruin", "pos": obstacle.get_center(), "radius": maxf(obstacle.size.x, obstacle.size.y) * 0.48, "part_id": 0, "layer": layer})
	# Formation is now chosen from the roster's own bands rather than listed per recipe.
	# Decoupling the two is what makes the experiment work: 0.2.40 rooms 1 and 2 held the
	# same four enemies in different placements and rated 2/2/2 against 3/4/3 in both rule
	# profiles -- the cleanest signal the archive has produced, and it happened by luck.
	# This manufactures those matched pairs on purpose.
	var placement := _survey_place_formations(enemy_plan, room_rng, player_start, obstacle_rects, threat_band, custom_room_formation if _custom_room_active() else "")
	var formation_ids: Array = placement["formation_ids"]
	var formation_id := " + ".join(PackedStringArray(formation_ids))
	var templates: Array[Dictionary] = []
	var enemy_labels: Array[String] = []
	var enemy_roles: Array[String] = []
	for seat_value in Array(placement["seats"]):
		var seat := Dictionary(seat_value)
		var planned_enemy := Dictionary(seat["entry"])
		var kind := String(planned_enemy["kind"])
		var role := CombatCatalogScript.role(kind)
		var jitter := Vector2(room_rng.randf_range(-22.0, 22.0), room_rng.randf_range(-18.0, 18.0))
		var spawn_position := _survey_settle_spawn(Vector2(seat["pos"]) + jitter, obstacle_rects, player_start)
		var initial_facing := (spawn_position - player_start).normalized()
		templates.append({"kind": kind, "role": role, "pos": spawn_position, "facing": initial_facing, "layer": layer})
		enemy_labels.append(kind.replace("_", " ").capitalize())
		enemy_roles.append("%s: %s" % [kind.replace("_", " ").capitalize(), role.replace("_", " ")])
	# Set per room rather than once, so replaying the same composition at a different
	# health is one control changed rather than a fresh run. Low health is the strongest
	# single thing we know of for how a room reads -- "the low HP helped", "being on the
	# verge of death is a great lock-in catalyst" -- so it has to be settable directly.
	if _custom_room_active():
		player_hp = clampi(roundi(float(player_max_hp) * custom_room_hp_percent), 1, player_max_hp)
	var threat_tier := 1 + int(floor(float(room_number - 1) * 0.5))
	survey_room_definition = {
		"room_number": room_number,
		"room_seed": survey_room_seed,
		"arena": arena_id,
		"formation": formation_id,
		"formation_ids": formation_ids,
		# Tagged rather than kept in a separate archive. A conditional estimate -- how does
		# a pincer rate -- does not care how the room came to exist, so segregating these
		# would throw away usable data. What DOES bite is that custom rooms are chosen on a
		# hunch and carry a hand-set health, so both are recorded and any analysis can
		# filter on them.
		"custom_room": _custom_room_active(),
		"entry_hp_percent": custom_room_hp_percent if _custom_room_active() else -1.0,
		"threat_tier": threat_tier,
		"threat_band": threat_band,
		"pacing_phase": pacing_phase,
		"recipe_id": String(composition.get("id", "unknown")),
		"recipe_label": String(composition.get("label", "Unknown")),
		"recipe_family": String(composition.get("family", "unknown")),
		"composition_cost": int(composition.get("cost", 0)),
		"ranged_pressure_count": int(composition.get("ranged_pressure_count", 0)),
		"enemy_labels": enemy_labels,
		"enemy_roles": enemy_roles,
	}

	var layers := {layer: {"name": "Combat Survey", "depth": 0}}
	var layer_walls := {layer: walls_for_layer}
	return {
		"world_size": Vector2(1700.0, 1400.0),
		"geometry_style": "arena",
		"areas": [{"id": 0, "name": "Survey Arena %d" % room_number, "arrival_text": "%s · %s" % [arena_id.replace("_", " ").capitalize(), formation_id.replace("_", " ").capitalize()], "kind": "survey", "rect": Rect2(175, 75, 1350, 1250), "center": center, "layer": layer, "discovered": true}],
		"connections": [],
		"route_recipe": [],
		"run_graph": {"nodes": [0], "edges": []},
		"locale_catalog": {},
		"floor_shapes": [{"kind": "circle", "center": center, "radius": SURVEY_ARENA_RADIUS, "part_id": 0, "layer": layer}],
		"terrain_features": features,
		"pickups": [],
		"waystones": [],
		"shortcuts": [],
		"transitions": [],
		"secret_passages": [],
		"layers": layers,
		"encounters": {0: templates},
		"layer_walls": layer_walls,
		"base_walls": walls_for_layer,
		"bonfire_pos": Vector2.ZERO,
		"player_start": player_start,
		"shortcut_gate": Rect2(),
		"shortcut_unlock_pos": Vector2.ZERO,
		"shortcut_start_pos": Vector2.ZERO,
	}

# How many enemies are actually in the fight right now: alerted, alive, and close
# enough to act on the player. Sampled per simulation tick, so it is weighted by world
# time rather than by wall clock -- which is the right weighting, because a room the
# player crosses slowly is a room they are spending time in.
const ENGAGEMENT_RADIUS := 320.0

func _engaged_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
		if String(enemy.get("awareness", "idle")) != "alerted": continue
		if Vector2(enemy["pos"]).distance_to(player_pos) > ENGAGEMENT_RADIUS: continue
		count += 1
	return count

func _sample_engagement() -> void:
	var engaged := _engaged_enemy_count()
	survey_engagement_samples += 1
	survey_engagement_alerted_sum += engaged
	if engaged >= 2: survey_engagement_multi_samples += 1
	var active: Array[Dictionary] = []
	for enemy in enemies:
		if int(enemy.get("hp", 0)) > 0 and _enemy_on_current_layer(enemy) and String(enemy.get("awareness", "idle")) == "alerted": active.append(enemy)
	if active.size() < 2: return
	var nearest_sum := 0.0
	var close_pair := false
	for enemy in active:
		var nearest := INF
		for other in active:
			if int(other.get("id", -1)) == int(enemy.get("id", -1)): continue
			nearest = minf(nearest, Vector2(enemy["pos"]).distance_to(Vector2(other["pos"])))
		nearest_sum += nearest
		if nearest < CROWDING_COMFORT_DISTANCE: close_pair = true
	survey_crowding_samples += 1
	survey_crowding_nearest_sum += nearest_sum / float(active.size())
	if close_pair: survey_crowding_close_samples += 1

func _survey_seed_for_room(room_number: int) -> int:
	return absi(hash("waystone-survey:%d:%d:%d" % [SURVEY_GENERATOR_VERSION, run_seed, room_number]))

func _survey_pacing_phase(room_number: int) -> String:
	var phases := ["opening", "development", "contrast", "pressure", "climax", "respite"]
	return String(phases[posmod(room_number - 1, phases.size())])

func _survey_threat_band(pacing_phase: String, room_rng: RandomNumberGenerator) -> String:
	match pacing_phase:
		"contrast": return "unusual"
		"pressure": return "stress" if room_rng.randf() < 0.24 else "unusual"
		"climax": return "stress"
		"development": return "unusual" if room_rng.randf() < 0.18 else "conventional"
		_: return "conventional"

func _survey_recipe_catalog() -> Array[Dictionary]:
	return [
		# Every room carries non-melee pressure unless it is explicitly flagged as a
		# melee experiment below. That is not a preference: across 200 rooms of archive,
		# rooms with 0/1/2 non-melee enemies rate 1.61/2.48/3.20 for fun, the effect
		# holds inside every version era, and it is largest in the most recent. See
		# docs/survey-archive-findings.md.
		#
		# The four recipes this deck used to open with -- Opening Pursuit, Mixed
		# Skirmish, Melee Cross and Melee Press -- were the measured 1.5s. They are
		# retired rather than patched, because patching them would have meant adding an
		# archer to each and losing the ability to test melee-only rooms at all.
				# Three bodies, not two. A lone melee escort leaves the Archer trivially reachable
		# -- "when enemies are very dispersed the ranged enemy doesn't really affect the
		# fight", 0.2.35 room 2 -- and the archive has no rooms of two enemies at all, so
		# that shape was below anything ever measured. Its best band is 4-5 enemies with
		# 2-3 melee alongside the pressure.
		{"id": "first_arrows", "label": "First Arrows", "family": "skirmish", "min_tier": 1, "phases": ["opening", "development", "respite"], "enemies": [{"kind": "archer"}, {"kind": "hound"}, {"kind": "knife"}], "reinforcements": [{"kind": "boar"}, {"kind": "bandit"}]},
		{"id": "hunted", "label": "Hunted", "family": "pursuit", "min_tier": 1, "phases": ["contrast", "pressure", "development"], "enemies": [{"kind": "archer"}, {"kind": "boar"}, {"kind": "knife"}], "reinforcements": [{"kind": "hound"}, {"kind": "bandit"}]},
		# --- Melee experiments -------------------------------------------------------
		# Deliberate, not filler. Every melee-only room in the archive was built from the
		# five oldest kinds; the Shield and Duellist have never once appeared in one.
		# So "melee-only rooms are irredeemable" and "those five enemies are
		# undifferentiated" are still indistinguishable, and three milestones of melee
		# differentiation have never been composed into a room that could test them.
		#
		# These are drawn from the differentiated roster and each asks three different
		# questions: go around it, do not swing at it, get out of its line.
		{"id": "warded_duel", "label": "Warded Duel", "family": "melee_experiment", "melee_experiment": true, "min_tier": 2, "phases": ["contrast", "opening", "development"], "enemies": [{"kind": "shield"}, {"kind": "duellist"}, {"kind": "boar"}], "reinforcements": [{"kind": "knife"}, {"kind": "hound"}]},
		{"id": "goring_reach", "label": "Goring Reach", "family": "melee_experiment", "melee_experiment": true, "min_tier": 4, "phases": ["opening", "pressure", "climax"], "enemies": [{"kind": "ox"}, {"kind": "polearm"}], "reinforcements": [{"kind": "duellist"}, {"kind": "hound"}]},
		{"id": "heavy_press", "label": "Heavy Press", "family": "melee_experiment", "melee_experiment": true, "min_tier": 5, "phases": ["climax", "pressure", "contrast"], "enemies": [{"kind": "brute"}, {"kind": "polearm"}, {"kind": "duellist"}], "reinforcements": [{"kind": "shield"}, {"kind": "bandit"}]},
		{"id": "screened_archer", "label": "Screened Archer", "family": "screened_ranged", "min_tier": 2, "phases": ["opening", "development", "pressure", "climax"], "enemies": [{"kind": "archer"}, {"kind": "shield"}, {"kind": "hound"}], "reinforcements": [{"kind": "bandit"}, {"kind": "boar"}]},
		{"id": "crossfire_chase", "label": "Crossfire Chase", "family": "crossfire", "min_tier": 2, "phases": ["pressure", "climax"], "enemies": [{"kind": "archer"}, {"kind": "archer"}, {"kind": "boar"}, {"kind": "hound"}], "reinforcements": [{"kind": "bandit"}, {"kind": "blade"}]},
		{"id": "ice_displacement", "label": "Ice Displacement", "family": "area_denial", "min_tier": 4, "phases": ["contrast", "pressure", "climax"], "enemies": [{"kind": "ice_caster"}, {"kind": "blade"}, {"kind": "hound"}, {"kind": "knife"}], "reinforcements": [{"kind": "boar"}, {"kind": "bandit"}]},
		{"id": "fire_pursuit", "label": "Fire Pursuit", "family": "area_denial", "min_tier": 3, "phases": ["development", "pressure", "climax", "respite"], "enemies": [{"kind": "fire_caster"}, {"kind": "boar"}, {"kind": "bandit"}], "reinforcements": [{"kind": "blade"}, {"kind": "hound"}]},
		{"id": "dual_elements", "label": "Dual Elements", "family": "caster_pair", "min_tier": 5, "phases": ["climax", "pressure", "contrast"], "enemies": [{"kind": "ice_caster"}, {"kind": "fire_caster"}, {"kind": "blade"}, {"kind": "hound"}], "reinforcements": [{"kind": "bandit"}, {"kind": "boar"}]},
		{"id": "polearm_screen", "label": "Polearm Screen", "family": "anchor", "min_tier": 3, "phases": ["opening", "development", "contrast", "respite"], "enemies": [{"kind": "polearm"}, {"kind": "archer"}, {"kind": "bandit"}], "reinforcements": [{"kind": "blade"}, {"kind": "hound"}]},
		{"id": "brute_support", "label": "Brute Support", "family": "heavy_anchor", "min_tier": 5, "phases": ["contrast", "pressure", "climax"], "enemies": [{"kind": "brute"}, {"kind": "archer"}, {"kind": "knife"}], "reinforcements": [{"kind": "bandit"}, {"kind": "blade"}]},
		# Kill-the-caster, priced. The Chanter hardens or hastens the bodies in front of
		# it and hides behind them, so the room asks whether reaching it is worth what
		# reaching it costs.
		{"id": "chanted_line", "label": "Chanted Line", "family": "command", "min_tier": 4, "phases": ["development", "pressure", "climax"], "enemies": [{"kind": "chanter"}, {"kind": "brute"}, {"kind": "hound"}, {"kind": "blade"}], "reinforcements": [{"kind": "bandit"}, {"kind": "knife"}]},
		# The two ranged enemies together, deliberately: the Archer punishes standing
		# still and the Javelineer punishes running in a straight line, so between them
		# both answers are spent and the Shield decides which one you are forced into.
		{"id": "closing_lanes", "label": "Closing Lanes", "family": "lane_denial", "min_tier": 3, "phases": ["pressure", "climax", "contrast"], "enemies": [{"kind": "archer"}, {"kind": "javelineer"}, {"kind": "shield"}], "reinforcements": [{"kind": "hound"}, {"kind": "knife"}]},
		# Ground that costs time, in front of an enemy you cannot afford to reach late.
		{"id": "crosswind", "label": "Crosswind", "family": "caster_pair", "min_tier": 4, "phases": ["pressure", "contrast", "climax"], "enemies": [{"kind": "air_caster"}, {"kind": "javelineer"}, {"kind": "shield"}], "reinforcements": [{"kind": "hound"}, {"kind": "blade"}]},
		{"id": "broken_ground", "label": "Broken Ground", "family": "area_denial", "min_tier": 4, "phases": ["development", "contrast", "respite"], "enemies": [{"kind": "earth_caster"}, {"kind": "polearm"}, {"kind": "knife"}], "reinforcements": [{"kind": "archer"}, {"kind": "boar"}]},
		# The Duellist wants your attention on it. The Javelineer wants you to move.
		{"id": "measured_guard", "label": "Measured Guard", "family": "skirmish", "min_tier": 4, "phases": ["opening", "contrast", "pressure"], "enemies": [{"kind": "duellist"}, {"kind": "javelineer"}, {"kind": "hound"}], "reinforcements": [{"kind": "blade"}, {"kind": "bandit"}]},
		# High-tier respite and opening. Both phases previously topped out at min_tier 3,
		# so a tier-6 "respite" could only be a tier-1 melee recipe it had already shown:
		# the 0.2.30 run exhausted the eligible pool at room 12 and repeated, which the
		# tester read as the generator recycling. Coverage sampling cannot fix a deck
		# that has nothing left to deal.
		#
		# Both are deliberately small. A respite is a light room, not a slow one, and
		# neither is another melee crowd -- the same run rated melee-only rooms 1.7/5 for
		# fun against 3.3 for rooms carrying ranged or area pressure.
		{"id": "warded_caster", "label": "Warded Caster", "family": "warded", "min_tier": 4, "phases": ["respite", "contrast"], "enemies": [{"kind": "shield"}, {"kind": "fire_caster"}], "reinforcements": [{"kind": "polearm"}, {"kind": "hound"}]},
		{"id": "outrider_line", "label": "Outrider Line", "family": "elite_charge", "min_tier": 4, "phases": ["opening", "development"], "enemies": [{"kind": "ox"}, {"kind": "archer"}], "reinforcements": [{"kind": "knife"}, {"kind": "hound"}]},
		{"id": "knight_command", "label": "Knight Command", "family": "heavy_anchor", "min_tier": 5, "phases": ["pressure", "climax", "contrast"], "enemies": [{"kind": "knight"}, {"kind": "archer"}, {"kind": "ice_caster"}, {"kind": "bandit"}], "reinforcements": [{"kind": "blade"}, {"kind": "hound"}]},
	]

# How many enemies in a recipe are not melee bodies. This is the single strongest
# predictor of a room's rating in the entire survey archive -- 0/1/2 of them maps to
# 1.61/2.48/3.20 mean fun across 200 rooms.
# Rooms 3, 7 and 11 of a run. Three melee-only rooms per thirteen is a readable sample
# without letting the deck drift back to what the archive already condemned.
#
# The question they exist to answer: every melee-only room ever surveyed was built from
# the five oldest kinds, and the Shield and Duellist have never appeared in one. So the
# archive cannot separate "melee-only rooms are irredeemable" from "those five enemies
# are undifferentiated" -- and E2, E3 and E4 all went into differentiating melee
# behaviour without a single room composed to test it.
func _survey_is_melee_experiment_room(room_number: int) -> bool:
	return room_number % MELEE_EXPERIMENT_EVERY == 3

func _recipe_non_melee_count(recipe: Dictionary) -> int:
	var count := 0
	for entry in Array(recipe.get("enemies", [])):
		if CombatCatalogScript.role(String(Dictionary(entry).get("kind", ""))) in NON_MELEE_ROLES: count += 1
	return count

func _custom_room_active() -> bool:
	return mode_id == ModeRulesScript.COMBAT_SURVEY and not custom_room_kinds.is_empty()

func _custom_selectable_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for kind in CombatCatalogScript.enemy_kinds():
		if String(kind) in ["warden", "werewolf"]: continue
		kinds.append(String(kind))
	kinds.sort()
	return kinds

# Re-rolled per room, so a spec holding RANDOM produces a different body each time it is
# played rather than one body forever.
func _custom_resolve_kind(token: String, room_rng: RandomNumberGenerator) -> String:
	var pool := _custom_selectable_kinds()
	if token == CUSTOM_RANDOM_NEW:
		var unused: Array[String] = []
		for kind in pool:
			if not custom_room_used_kinds.has(kind): unused.append(kind)
		if not unused.is_empty(): pool = unused
	elif token != CUSTOM_RANDOM:
		return token
	if pool.is_empty(): return "blade"
	return String(pool[room_rng.randi_range(0, pool.size() - 1)])

func _custom_room_composition(room_rng: RandomNumberGenerator) -> Dictionary:
	var enemies: Array[Dictionary] = []
	var labels: Array[String] = []
	var cost := 0
	for token in custom_room_kinds:
		var kind := _custom_resolve_kind(String(token), room_rng)
		custom_room_used_kinds[kind] = true
		labels.append(kind)
		enemies.append({"kind": kind})
		cost += _survey_enemy_cost(kind)
	custom_room_last_roster.assign(labels)
	return {
		"id": "custom_room", "label": "Custom Room", "family": "custom",
		"min_tier": 1, "phases": ["opening"], "enemies": enemies, "reinforcements": [],
		"cost": cost, "ranged_pressure_count": _recipe_non_melee_count({"enemies": enemies}),
		"melee_experiment": false,
	}

func _survey_composition(room_rng: RandomNumberGenerator, room_number: int, threat_band: String, pacing_phase: String) -> Dictionary:
	var tier := 1 + int(floor(float(room_number - 1) * 0.5))
	var candidates: Array[Dictionary] = []
	for recipe_value in _survey_recipe_catalog():
		var recipe := Dictionary(recipe_value)
		if tier >= int(recipe["min_tier"]) and Array(recipe["phases"]).has(pacing_phase): candidates.append(recipe)
	if candidates.is_empty(): candidates.append(Dictionary(_survey_recipe_catalog()[0]))
	# G1. Two rules, both from docs/survey-archive-findings.md rather than from taste.
	#
	# The first is a guarantee: a room carries non-melee pressure. Across 200 rooms the
	# count of non-melee enemies explains very nearly the whole variation in rating, all
	# ten of the best rooms ever recorded contain one, and 87% of the worst rooms are
	# pure melee. This is enforced here rather than trusted to the deck, so a recipe
	# added later cannot quietly reintroduce the rooms that measured 1.5.
	#
	# The second is an experiment, and it is the reason the guarantee has an exception
	# at all -- see _survey_is_melee_experiment_room.
	var experiments: Array[Dictionary] = candidates.filter(func(recipe: Dictionary) -> bool: return bool(recipe.get("melee_experiment", false)))
	var pressured: Array[Dictionary] = candidates.filter(func(recipe: Dictionary) -> bool: return _recipe_non_melee_count(recipe) > 0)
	if _survey_is_melee_experiment_room(room_number) and not experiments.is_empty():
		candidates = experiments
	elif not pressured.is_empty():
		candidates = pressured
	var completed_rooms: Array = survey_session.get("rooms", [])
	# Coverage, not pacing. The survey exists to show the tester as many distinct
	# room types as one run can hold, so anything not yet seen this run is drawn
	# first and repeats begin only once the eligible pool is exhausted.
	#
	# An earlier version optimised against the PREVIOUS room instead -- a repetition
	# window and a role-freshness rule -- which is variety-as-pacing, a property of
	# the game rather than of the instrument. See the caution in
	# docs/design-foundations.md section 4.6: survey ordering and repetition are
	# harness artifacts and are not evidence about how the game plays.
	var seen_ids: Array[String] = []
	for room_value in completed_rooms: seen_ids.append(String(Dictionary(room_value).get("recipe_id", "")))
	var unseen: Array[Dictionary] = candidates.filter(func(recipe: Dictionary) -> bool: return not seen_ids.has(String(recipe["id"])))
	if not unseen.is_empty():
		candidates = unseen
	else:
		# Pool exhausted. Fall back to spacing repeats out rather than clustering them.
		var recent_ids: Array[String] = []
		for index in range(maxi(0, completed_rooms.size() - RECIPE_REPEAT_WINDOW), completed_rooms.size()):
			recent_ids.append(String(Dictionary(completed_rooms[index]).get("recipe_id", "")))
		var unused: Array[Dictionary] = candidates.filter(func(recipe: Dictionary) -> bool: return not recent_ids.has(String(recipe["id"])))
		if not unused.is_empty(): candidates = unused
	var recent_family := "" if completed_rooms.is_empty() else String(Dictionary(completed_rooms[-1]).get("recipe_family", ""))
	var different_family: Array[Dictionary] = candidates.filter(func(recipe: Dictionary) -> bool: return String(recipe["family"]) != recent_family)
	if not different_family.is_empty(): candidates = different_family
	# Prefer two sources of non-melee pressure where the phase wants weight -- applied
	# LAST, after coverage and family variety, because it is the weakest claim in the
	# analysis. The 0-to-1 step rests on 132 rooms against 58; the 1-to-2 step rests on
	# 58 against 10. A lean, not a rule, and it yields to anything better evidenced.
	if pacing_phase in ["pressure", "climax"]:
		var doubled: Array[Dictionary] = candidates.filter(func(recipe: Dictionary) -> bool: return _recipe_non_melee_count(recipe) >= 2)
		if not doubled.is_empty(): candidates = doubled
	var chosen := Dictionary(candidates[room_rng.randi_range(0, candidates.size() - 1)]).duplicate(true)
	var enemies: Array[Dictionary] = []
	for enemy_value in Array(chosen["enemies"]): enemies.append(Dictionary(enemy_value).duplicate())
	# 2 + tier was sized for the old deck, whose base recipes were cheap -- Boar + Hound
	# cost 2 -- and left the fill loop below to do the work. The G1 recipes are
	# front-loaded instead, so at tier 1 the budget of 3 was already spent by the base
	# composition and reinforcements never fired at all: the 0.2.35 survey ran rooms of
	# 2, 3, 3, 4 and 3 enemies, and the tester noted that a dispersed ranged enemy
	# "doesn't really affect the fight". The archive's best band is 4-5 enemies with 2-3
	# melee alongside the pressure, which needs roughly two more points of budget.
	var target_budget := mini(18, 4 + tier + (2 if threat_band == "stress" else 1 if threat_band == "unusual" else 0))
	if pacing_phase == "respite": target_budget = maxi(3, target_budget - 2)
	var cost := _survey_composition_cost(enemies)
	var reinforcements: Array = chosen.get("reinforcements", [])
	var attempts := 0
	# Capped at five, not six. The archive rates six-enemy rooms at 2.29 mean fun -- its
	# worst band -- against 2.76 at four and 2.71 at five. Thin evidence (n=7) but it is
	# the only evidence, it points one way, and a lower cap also keeps the crowding push
	# from having to do as much work.
	# A floor, independent of budget. The melee experiments are built from expensive
	# bodies -- Ox 5, Duellist 4, Brute 4 -- so their base composition consumes the whole
	# allowance and the loop below never ran once: Goring Reach shipped as a TWO enemy
	# room at cost 8 against a budget of 8, and the tester flagged it in two consecutive
	# surveys ("this was once again a 2 enemy room"). A room that small cannot answer the
	# question the experiment exists to ask, which is how differentiated melee enemies
	# interact with each other.
	var minimum_bodies := 3 if pacing_phase == "respite" else 4
	while enemies.size() < minimum_bodies and not reinforcements.is_empty() and attempts < 12:
		attempts += 1
		var filler := Dictionary(reinforcements[room_rng.randi_range(0, reinforcements.size() - 1)])
		if _survey_plan_kind_count(enemies, String(filler["kind"])) >= 2: continue
		if _survey_plan_role_count(enemies, String(filler["kind"])) >= 2: continue
		if _survey_plan_technique_count(enemies, String(filler["kind"])) >= 2: continue
		if _survey_is_ranged_pressure(filler) and _survey_ranged_pressure_count(enemies) >= 2: continue
		enemies.append(filler.duplicate())
		cost += _survey_enemy_cost(String(filler["kind"]))
	while cost < target_budget and enemies.size() < 5 and not reinforcements.is_empty() and attempts < 18:
		attempts += 1
		var option := Dictionary(reinforcements[room_rng.randi_range(0, reinforcements.size() - 1)])
		var kind := String(option["kind"])
		var option_cost := _survey_enemy_cost(kind)
		if cost + option_cost > target_budget: continue
		if _survey_plan_kind_count(enemies, kind) >= 2: continue
		if _survey_plan_role_count(enemies, kind) >= 2: continue
		if _survey_plan_technique_count(enemies, kind) >= 2: continue
		if _survey_is_ranged_pressure(option) and _survey_ranged_pressure_count(enemies) >= 2: continue
		enemies.append(option.duplicate())
		cost += option_cost
	chosen["enemies"] = enemies
	chosen["cost"] = cost
	chosen["ranged_pressure_count"] = _survey_ranged_pressure_count(enemies)
	return chosen

func _survey_enemy_cost(kind: String) -> int:
	return int(CombatCatalogScript.enemy_fact(kind, "survey_cost"))

func _survey_composition_cost(enemies_plan: Array[Dictionary]) -> int:
	var result := 0
	for planned_enemy in enemies_plan: result += _survey_enemy_cost(String(planned_enemy["kind"]))
	return result

func _survey_is_ranged_pressure(planned_enemy: Dictionary) -> bool:
	return CombatCatalogScript.role(String(planned_enemy.get("kind", ""))) in ["ranged_pressure", "area_denial"]

# Same-kind was already capped at two; same-ROLE was not, so a room could stack three
# different flankers -- Hound, Knife and Bandit -- which is one problem asked three
# times rather than three problems. The 0.2.38 survey rated exactly that room "crowded,
# too hard... it didn't feel challenging, just tedious", while a four-enemy room of a
# screen, a flanker, a frontliner and a knife rated a point higher at identical
# engagement (2.33 versus 2.30 enemies engaged at once).
# Two kinds can hold different roles and still ask the same question. The 0.2.40
# Energy run's room 3 landed seven boar pounces and nine hound pounces -- sixteen of
# twenty-eight attacks -- and the note read "too many enemies doing the same thing,
# busy and monotonous". Boar is `frontline` and Hound is `flanker`, so the role cap
# waved them both through. The verb is what the player actually reads.
func _survey_primary_technique(kind: String) -> String:
	var plan := CombatCatalogScript.melee_attack_plan(kind)
	if plan.is_empty(): return ""
	return String(Dictionary(plan[0]).get("technique", ""))

func _survey_plan_technique_count(enemies: Array, kind: String) -> int:
	var technique := _survey_primary_technique(kind)
	if technique.is_empty(): return 0
	var count := 0
	for entry in enemies:
		if _survey_primary_technique(String(Dictionary(entry).get("kind", ""))) == technique: count += 1
	return count

func _survey_plan_role_count(enemies_plan: Array[Dictionary], kind: String) -> int:
	var role := CombatCatalogScript.role(kind)
	var result := 0
	for planned_enemy in enemies_plan:
		if CombatCatalogScript.role(String(planned_enemy.get("kind", ""))) == role: result += 1
	return result

func _survey_plan_kind_count(enemies_plan: Array[Dictionary], kind: String) -> int:
	var result := 0
	for planned_enemy in enemies_plan:
		if String(planned_enemy.get("kind", "")) == kind: result += 1
	return result

func _survey_ranged_pressure_count(enemies_plan: Array[Dictionary]) -> int:
	var result := 0
	for planned_enemy in enemies_plan:
		if _survey_is_ranged_pressure(planned_enemy): result += 1
	return result

# The formation library. A formation is an authored ARRANGEMENT, not a bag of points.
#
# What was here before was six fixed coordinates per formation id, with every enemy
# independently picking its favourite by role score. `ranged_support` promised an
# archer supported by melee; what it actually was, was a hexagon, and nothing put a
# body between the archer and the player. The name described an intention the code
# never implemented -- the same defect as a role label with no behaviour under it.
#
# Slots are authored in formation-local space as (lateral, depth), where depth counts
# AWAY from the player. A slot at depth 220 is 220 units further from the player than
# the anchor, whatever direction the player is standing in, so screening is a fact of
# the geometry rather than a score some placement function has to be lucky enough to
# satisfy.
#
# The library is deliberately SIX. At roughly eleven rooms a run, six formations reach
# fifty rooms each within a few runs, which is enough to compare them the way non-melee
# count was compared in docs/survey-archive-findings.md. Twenty would never reach a
# readable sample, and the entire reason for authoring formations is to find out which
# ones work. Add a seventh only by retiring one.
func _survey_formation_catalog() -> Array[Dictionary]:
	return [
		# You must go through them. The canonical answer to a reachable archer.
		{"id": "screen_line", "label": "Screen Line", "slots": [
			{"band": "van", "at": Vector2(-62.0, 0.0)},
			{"band": "van", "at": Vector2(62.0, 0.0)},
			{"band": "wing", "at": Vector2(-176.0, -24.0)},
			{"band": "wing", "at": Vector2(176.0, -24.0)},
			{"band": "mid", "at": Vector2(0.0, 112.0)},
			{"band": "rear", "at": Vector2(0.0, 224.0)},
		]},
		# Two shooters wide of each other with the melee central, so closing on either
		# one turns your back on the other.
		{"id": "crossfire", "label": "Crossfire", "slots": [
			{"band": "van", "at": Vector2(0.0, 0.0)},
			{"band": "wing", "at": Vector2(-140.0, -20.0)},
			{"band": "wing", "at": Vector2(140.0, -20.0)},
			{"band": "mid", "at": Vector2(0.0, 118.0)},
			{"band": "rear", "at": Vector2(-208.0, 132.0)},
			{"band": "rear", "at": Vector2(208.0, 132.0)},
		]},
		# Depth on one bearing. The back ranks arrive while you are committed to the front.
		{"id": "column", "label": "Column", "slots": [
			{"band": "van", "at": Vector2(0.0, 0.0)},
			{"band": "van", "at": Vector2(26.0, 72.0)},
			{"band": "wing", "at": Vector2(-64.0, 34.0)},
			{"band": "mid", "at": Vector2(-18.0, 152.0)},
			{"band": "rear", "at": Vector2(0.0, 262.0)},
			{"band": "rear", "at": Vector2(48.0, 330.0)},
		]},
		# Melee split wide with an open centre -- the lane is bait, and it ends at a caster.
		{"id": "pincer", "label": "Pincer", "slots": [
			{"band": "van", "at": Vector2(-118.0, 0.0)},
			{"band": "van", "at": Vector2(118.0, 0.0)},
			{"band": "wing", "at": Vector2(-198.0, -32.0)},
			{"band": "wing", "at": Vector2(198.0, -32.0)},
			{"band": "mid", "at": Vector2(0.0, 94.0)},
			{"band": "rear", "at": Vector2(0.0, 196.0)},
		]},
		# Everything tight. The control condition: roughly what the old placement did.
		{"id": "cluster", "label": "Cluster", "slots": [
			{"band": "van", "at": Vector2(-42.0, 0.0)},
			{"band": "van", "at": Vector2(42.0, 0.0)},
			{"band": "wing", "at": Vector2(-74.0, -44.0)},
			{"band": "wing", "at": Vector2(74.0, -44.0)},
			{"band": "mid", "at": Vector2(0.0, 62.0)},
			{"band": "rear", "at": Vector2(0.0, 116.0)},
		]},
		# The elite as the centre of the room rather than a member of it. Requires a body
		# heavy enough to hold that place, so it is drawn only when one is present.
		#
		# The escorts sit WIDE and DEEPER rather than ringing the elite completely, for
		# two reasons. The Ox runs its line until it hits something, and a full ring
		# would have its own retinue standing in the lane -- the worst possible
		# arrangement for the one enemy this formation exists to showcase. And placing
		# them behind the elite makes the question interesting rather than procedural:
		# commit to the big body and the escorts close at your back, clear the escorts
		# first and you eat the elite the whole time.
		{"id": "retinue", "label": "Retinue", "requires": "elite", "slots": [
			{"band": "elite", "at": Vector2(0.0, 44.0)},
			{"band": "wing", "at": Vector2(-152.0, 92.0)},
			{"band": "wing", "at": Vector2(152.0, 92.0)},
			{"band": "van", "at": Vector2(-92.0, 156.0)},
			{"band": "van", "at": Vector2(92.0, 156.0)},
			{"band": "rear", "at": Vector2(0.0, 254.0)},
		]},
		# One body forward of everything else. The direct test of whether a lone body in
		# the open is a speed bump or a trigger -- "an archer that spawns next to me is
		# just a blob I have to hit before fighting the rest of the room".
		{"id": "picket", "label": "Picket", "slots": [
			{"band": "wing", "at": Vector2(0.0, -96.0)},
			{"band": "van", "at": Vector2(-58.0, 64.0)},
			{"band": "van", "at": Vector2(58.0, 64.0)},
			{"band": "wing", "at": Vector2(-168.0, 40.0)},
			{"band": "mid", "at": Vector2(0.0, 158.0)},
			{"band": "rear", "at": Vector2(0.0, 258.0)},
		]},
	]

func _formation_band_for_role(role: String) -> String:
	return String(ROLE_FORMATION_BAND.get(role, "van"))

# Which bodies are big enough to be the centre of a room rather than a member of one.
# Derived from mass rather than from a list, using the threshold that already decides
# who keeps their attack through chip damage: HEAVY_TELEGRAPH_MASS selects Warden,
# Brute, Knight and Ox, and excludes Shield (1.35), Boar (1.25) and Polearm (1.15).
# One meaning for mass throughout, and no second roster to drift out of sync.
# Called wherever the player's own damage lands. Records the first time each body was
# reached, measured from the start of the room in world time.
# Every path where the player's own damage lands. An action carrying `impact_sound`
# announces itself here, once, on contact.
func _on_player_hit_landed(enemy: Dictionary) -> void:
	var loudness := float(player_action.get("impact_sound", 0.0))
	if loudness > 0.0 and not bool(player_action.get("impact_sound_done", false)):
		player_action["impact_sound_done"] = true
		_emit_sound(player_pos, loudness)
	_note_player_reached(enemy)

func _note_player_reached(enemy: Dictionary) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY or bool(enemy.get("survey_reached", false)): return
	enemy["survey_reached"] = true
	var kind := String(enemy.get("kind", ""))
	if _formation_band_for_kind(kind) != "rear": return
	survey_reach_times.append({"kind": kind, "at": simulation_time - float(survey_room_entry.get("time", 0.0))})

# Both fixups that used to live inline in the assembly loop, run to convergence.
#
# They were a single pass each, in the wrong order, and they undid one another.
# `split_approach` stands two 95x305 slabs 150 units apart: a body shoved clear of the
# left one lands against the right, and the loop had already passed the left, so
# nothing looked again. Then the 360-unit minimum distance from the player ran
# AFTERWARDS and could shove a cleared body straight back into the slab it had just
# been moved out of, with no re-check at all.
#
# Both defects predate formations. What 0.2.41 changed is how often they fire: authored
# offsets have no idea where the walls are, while the six hand-picked slots they
# replaced had been chosen to dodge them. The 0.2.41 survey found a Boar standing
# inside a wall -- unhittable, unable to path, `move@0.01` forever at one position --
# and both rooms scored 1/1/1.
func _survey_settle_spawn(position: Vector2, obstacle_rects: Array, player_start: Vector2) -> Vector2:
	var result := position
	for _pass in range(8):
		var moved := false
		for obstacle_value in obstacle_rects:
			var obstacle: Rect2 = obstacle_value
			if not obstacle.grow(70.0).has_point(result): continue
			var away := result - obstacle.get_center()
			if away.is_zero_approx(): away = Vector2.UP
			result = obstacle.get_center() + away.normalized() * (maxf(obstacle.size.x, obstacle.size.y) * 0.72 + 90.0)
			moved = true
		# Survey rooms must permit an opening stealth decision, so nothing starts inside
		# immediate contact range.
		var from_player := result - player_start
		if from_player.length() < 360.0:
			var safe_direction := from_player.normalized() if from_player.length_squared() > 0.001 else Vector2.UP
			result = player_start + safe_direction * 360.0
			moved = true
		# Inside the loop rather than after it: a body pulled back onto the floor can land
		# on a slab, and that has to be resolved rather than shipped. This is the same
		# mistake the wall fix was about, one rule further out.
		var from_centre := result - SURVEY_ARENA_CENTER
		if from_centre.length() > SURVEY_ARENA_RADIUS - SURVEY_ARENA_MARGIN:
			var inward := from_centre.normalized() if from_centre.length_squared() > 0.001 else Vector2.UP
			result = SURVEY_ARENA_CENTER + inward * (SURVEY_ARENA_RADIUS - SURVEY_ARENA_MARGIN)
			moved = true
		if not moved: return result
	# Still contested after eight passes, which means the two rules have no fixed point
	# here. Sweep for the nearest clear standing room rather than leaving a body inside
	# geometry it can neither be hit through nor path out of.
	for radius: float in [380.0, 450.0, 530.0, 620.0]:
		for step in range(24):
			var candidate := player_start + Vector2.UP.rotated(TAU * float(step) / 24.0) * radius
			var clear := candidate.distance_to(SURVEY_ARENA_CENTER) <= SURVEY_ARENA_RADIUS - SURVEY_ARENA_MARGIN
			for obstacle_value in obstacle_rects:
				if Rect2(obstacle_value).grow(70.0).has_point(candidate): clear = false
			if clear: return candidate
	return result

# How many of a template's seats would be misplaced if it were anchored here -- in
# geometry, or off the floor entirely. The anchor was previously chosen with no
# knowledge of the arena at all, so a whole formation could be dropped onto a slab, or
# past the rim, and then dragged back body by body by the settling above. Clamping is a
# backstop; scoring is what keeps it rare, because a formation whose seats all need
# pulling in arrives squashed against the edge.
func _formation_misplaced_seats(template: Dictionary, anchor: Vector2, player_start: Vector2, obstacle_rects: Array) -> int:
	var forward := (player_start - anchor)
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector2.DOWN
	var right := forward.rotated(PI * 0.5)
	var blocked := 0
	for slot_value in Array(template["slots"]):
		var local := Vector2(Dictionary(slot_value)["at"])
		var world := anchor + right * local.x - forward * local.y
		if world.distance_to(SURVEY_ARENA_CENTER) > SURVEY_ARENA_RADIUS - SURVEY_ARENA_MARGIN:
			blocked += 1
			continue
		for obstacle_value in obstacle_rects:
			if Rect2(obstacle_value).grow(70.0).has_point(world):
				blocked += 1
				break
	return blocked

func _formation_band_for_kind(kind: String) -> String:
	if CombatCatalogScript.role(kind) == "boss" or _enemy_mass(kind) >= HEAVY_TELEGRAPH_MASS: return "elite"
	return _formation_band_for_role(CombatCatalogScript.role(kind))

# Split the roster into groups so that every group gets a van before any group gets a
# second, and the rear bodies are spread rather than pooled. A group of nothing but
# casters is a group with no screen, which is the arrangement this whole change exists
# to stop happening by accident.
func _survey_group_roster(plan: Array, group_count: int) -> Array:
	var order := {"elite": 0, "van": 1, "wing": 2, "mid": 3, "rear": 4}
	var sorted_plan := plan.duplicate()
	sorted_plan.sort_custom(func(a, b):
		var band_a := _formation_band_for_kind(String(Dictionary(a)["kind"]))
		var band_b := _formation_band_for_kind(String(Dictionary(b)["kind"]))
		return int(order.get(band_a, 0)) < int(order.get(band_b, 0)))
	var groups: Array = []
	for _i in range(group_count): groups.append([])
	for index in range(sorted_plan.size()):
		Array(groups[index % group_count]).append(sorted_plan[index])
	var populated: Array = []
	for group in groups:
		if not Array(group).is_empty(): populated.append(group)
	return populated

# Pick the template that can seat the most of this group in its own band, breaking ties
# toward the one with the fewest wasted slots. A group of four should not be placed in
# a six-slot Column with two empty ranks stretching it across the arena.
func _survey_choose_formation(group: Array, room_rng: RandomNumberGenerator, used_ids: Dictionary, forced_formation: String = "") -> Dictionary:
	if not forced_formation.is_empty():
		for template_value in _survey_formation_catalog():
			if String(Dictionary(template_value)["id"]) == forced_formation: return Dictionary(template_value)
	var wanted: Dictionary = {}
	for entry in group:
		var band := _formation_band_for_kind(String(Dictionary(entry)["kind"]))
		wanted[band] = int(wanted.get(band, 0)) + 1
	# Two elite rooms in three centre the elite; the last third leaves it in an ordinary
	# formation ON PURPOSE. Without that control there is no way to tell whether Retinue
	# is good or whether rooms containing an Ox are good -- the same confound that left
	# "melee-only rooms are irredeemable" unfalsifiable across thirty runs, because every
	# melee-only room in the archive happened to be built from the five oldest kinds.
	var wants_centre := int(wanted.get("elite", 0)) > 0 and room_rng.randf() < 0.65
	var best: Dictionary = {}
	var best_score := -INF
	var catalog := _survey_formation_catalog()
	for template_value in catalog:
		var template := Dictionary(template_value)
		var requirement := String(template.get("requires", ""))
		if not requirement.is_empty() and int(wanted.get(requirement, 0)) <= 0: continue
		if (not requirement.is_empty()) != wants_centre: continue
		var supply: Dictionary = {}
		for slot_value in Array(template["slots"]):
			var band := String(Dictionary(slot_value)["band"])
			supply[band] = int(supply.get(band, 0)) + 1
		var seated := 0
		for band in wanted:
			seated += mini(int(wanted[band]), int(supply.get(band, 0)))
		# Prefer variety: a formation already used in this room is a worse experiment
		# than a second arrangement, because two identical groups measure one thing.
		var score := float(seated) * 10.0 - absf(float(Array(template["slots"]).size() - group.size())) + room_rng.randf() * 2.0
		if used_ids.has(String(template["id"])): score -= 6.0
		# Coverage, not assignment. Pinning a formation to a room index would weld it to
		# that room's tier and pacing, so crossfire would always draw room 1's easy roster
		# and the comparison would be worthless. Biasing toward the least-played
		# arrangement keeps band-compatibility as the filter and rosters varied, while
		# turning "four columns and no screen line" into roughly two of each.
		score -= float(_formation_use_counts.get(String(template["id"]), 0)) * 4.5
		if score > best_score:
			best_score = score
			best = template
	return best

# Seat one group. Bands fall back through BAND_FALLBACK when their own rank is full,
# and `rear` never falls forward past `mid` -- a caster that ends up in front is the
# failure this replaced.
func _survey_seat_group(group: Array, template: Dictionary, anchor: Vector2, player_start: Vector2) -> Array:
	var forward := (player_start - anchor)
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector2.DOWN
	var right := forward.rotated(PI * 0.5)
	var free: Array = []
	for slot_value in Array(template["slots"]):
		var slot := Dictionary(slot_value)
		free.append({"band": String(slot["band"]), "at": Vector2(slot["at"]), "depth": float(Vector2(slot["at"]).y)})
	var seated: Array = []
	var order := {"elite": 0, "rear": 1, "mid": 2, "van": 3, "wing": 4}
	var seat_order := group.duplicate()
	# Rear first, so the deepest slots go to the bodies that need them. Support is the
	# strictest case: the Chanter's entire contribution is surviving long enough to
	# chant, and it spent its only appearance dead three seconds in.
	seat_order.sort_custom(func(a, b):
		var band_a := _formation_band_for_kind(String(Dictionary(a)["kind"]))
		var band_b := _formation_band_for_kind(String(Dictionary(b)["kind"]))
		return int(order.get(band_a, 9)) < int(order.get(band_b, 9)))
	for entry_value in seat_order:
		var entry := Dictionary(entry_value)
		var band := _formation_band_for_kind(String(entry["kind"]))
		var chosen_index := -1
		for candidate_band in Array(BAND_FALLBACK.get(band, [band])):
			var deepest := -INF
			for index in range(free.size()):
				if String(Dictionary(free[index])["band"]) != String(candidate_band): continue
				# Deepest first inside a band, so `support` takes the back of the rear.
				var depth := float(Dictionary(free[index])["depth"])
				if depth > deepest:
					deepest = depth
					chosen_index = index
			if chosen_index >= 0: break
		var local: Vector2 = Vector2(Dictionary(free[chosen_index])["at"]) if chosen_index >= 0 else Vector2(0.0, 180.0)
		if chosen_index >= 0: free.remove_at(chosen_index)
		seated.append({"entry": entry, "pos": anchor + right * local.x - forward * local.y})
	return seated

func _survey_place_formations(plan: Array, room_rng: RandomNumberGenerator, player_start: Vector2, obstacle_rects: Array, threat_band: String, forced_formation: String = "") -> Dictionary:
	# One group by default. Two groups placed independently are two sequential fights,
	# and the archive rates those below one good one -- so a second group has to earn
	# its place by interacting with the first, and a third needs a stress band behind it.
	var group_count := 1
	# A named formation means one arrangement, not two copies of it. Splitting a forced
	# spec across groups would answer a different question than the one being asked.
	if forced_formation.is_empty():
		if plan.size() >= 4 and room_rng.randf() < 0.45: group_count = 2
		if threat_band == "stress" and plan.size() >= 5 and room_rng.randf() < 0.30: group_count = 3
	var groups := _survey_group_roster(plan, group_count)
	var toward_arena := (SURVEY_ARENA_CENTER - player_start).normalized()
	var placed: Array = []
	var used_ids: Dictionary = {}
	var formation_ids: Array[String] = []
	for group_index in range(groups.size()):
		var group: Array = groups[group_index]
		var template := _survey_choose_formation(group, room_rng, used_ids, forced_formation)
		used_ids[String(template["id"])] = true
		_formation_use_counts[String(template["id"])] = int(_formation_use_counts.get(String(template["id"]), 0)) + 1
		formation_ids.append(String(template["id"]))
		var has_rear := false
		for entry in group:
			if _formation_band_for_kind(String(Dictionary(entry)["kind"])) == "rear": has_rear = true
		var seated: Array = []
		var anchor := player_start + toward_arena * 470.0
		var best_penalty := INF
		for attempt in range(18):
			var spread := 0.0
			if group_index == 1: spread = deg_to_rad(room_rng.randf_range(46.0, 104.0) - float(attempt) * 4.0) * (1.0 if room_rng.randf() < 0.5 else -1.0)
			elif group_index == 2: spread = deg_to_rad(-(room_rng.randf_range(46.0, 104.0) - float(attempt) * 4.0))
			else: spread = deg_to_rad(room_rng.randf_range(-26.0, 26.0))
			var candidate := player_start + toward_arena.rotated(spread) * room_rng.randf_range(410.0, 560.0)
			var record := {"anchor": candidate, "has_rear": has_rear}
			var interacts := true
			for other in placed:
				if not _groups_interact(record, Dictionary(other), obstacle_rects): interacts = false
			# Seats in geometry cost far more than a missed interaction: a body inside a
			# slab cannot be reached, cannot path, and ends the room.
			var penalty := float(_formation_misplaced_seats(template, candidate, player_start, obstacle_rects)) * 10.0
			if not interacts: penalty += 3.0
			if penalty < best_penalty:
				best_penalty = penalty
				anchor = candidate
			if penalty <= 0.0: break
		seated = _survey_seat_group(group, template, anchor, player_start)
		placed.append({"anchor": anchor, "has_rear": has_rear, "seats": seated})
	var seats: Array = []
	for record in placed:
		for seat in Array(Dictionary(record).get("seats", [])): seats.append(seat)
	return {"seats": seats, "formation_ids": formation_ids}

func _segment_hits_rects(from_point: Vector2, to_point: Vector2, rects: Array) -> bool:
	# Generation runs before the wall spatial index exists for this room, so line of
	# sight is tested against the obstacle list directly rather than through
	# _has_line_of_sight, which would silently answer using the PREVIOUS room's walls.
	# Sampled rather than analytic: Rect2 has no segment test, and at these distances
	# (a few hundred units against obstacles 90 units on their shortest side) twenty
	# samples cannot step over one.
	for rect_value in rects:
		var rect: Rect2 = rect_value
		for step in range(0, 21):
			if rect.has_point(from_point.lerp(to_point, float(step) / 20.0)): return true
	return false

func _groups_interact(first: Dictionary, second: Dictionary, obstacle_rects: Array) -> bool:
	var a := Vector2(first["anchor"])
	var b := Vector2(second["anchor"])
	if a.distance_to(b) <= GROUP_PURSUIT_REACH: return true
	# Otherwise one of them must be able to shoot into the other's fight.
	for pair in [[first, second], [second, first]]:
		var shooter := Dictionary(pair[0])
		if not bool(shooter.get("has_rear", false)): continue
		if not _segment_hits_rects(Vector2(shooter["anchor"]), Vector2(Dictionary(pair[1])["anchor"]), obstacle_rects): return true
	return false

func _capture_survey_room_entry() -> void:
	survey_room_view_modes.assign([survey_current_view_mode])
	# Attack records are per room. The aggregate is computed when the room closes,
	# so carrying the previous room's attacks in would blend two encounters.
	survey_attack_records.clear()
	survey_reach_times.clear()
	exhausted_dodge_room_max_chain = 0
	survey_room_entry = {
		"time": simulation_time,
		"hp": player_hp,
		"max_hp": player_max_hp,
		"energy": player_energy,
		"max_energy": player_max_energy,
		"potions": potions,
		"damage_dealt": damage_dealt,
		# These four accumulate across the run and are differenced per room like every other
		# figure in the record. Reporting them raw made every room show the run's running
		# total -- room 2 of the 0.2.66 survey reported six friendly-fire hits with zero
		# combat time, which is where it was caught.
		"stray_projectile_hits": survey_stray_projectile_hits,
		"javelins_grounded": survey_javelins_grounded,
		"barriers_raised": survey_barriers_raised,
		"barrier_blocks": survey_barrier_blocks,
		"blind_collisions": survey_blind_collisions,
		"burn_damage": survey_burn_damage_total,
		"frost_amplified_hits": survey_frost_amplified_hits,
		"damage_received": damage_received_total,
		"hits_received": hits_received_total,
		"protected_damage": protected_damage_total,
		"interruptions_prevented": interruptions_prevented_total,
		"clean_evade_dodge": clean_evade_dodge_total,
		"clean_evade_vault": clean_evade_vault_total,
		"turnabout_primed": turnabout_primed_total,
		"turnabout_consumed": turnabout_consumed_total,
		"potions_used": potions_used_total,
		"perfect_dodges": perfect_dodges,
		"successful_blocks": successful_blocks,
		"successful_endures": successful_endures,
		"action_counts": survey_action_counts.duplicate(true),
		"view_switches": survey_view_switches,
		"empty_melee_contacts": survey_empty_melee_contacts,
		"engagement_samples": survey_engagement_samples,
		"engagement_alerted_sum": survey_engagement_alerted_sum,
		"engagement_multi_samples": survey_engagement_multi_samples,
		"isolated_kills": survey_isolated_kills,
		"engaged_kills": survey_engaged_kills,
		"energy_spent": energy_spent_total,
		"energy_depleted": energy_depleted_total,
		"energy_overdraw": energy_overdraw_total,
		"energy_regenerated": energy_regenerated_total,
		"energy_regen_delay_time": energy_regen_delay_time_total,
		"energy_regen_active_time": energy_regen_active_time_total,
		"overexertions": overexertion_count,
		"winded_time": winded_time_total,
		"energy_blocked_continuations": energy_blocked_continuations,
		"exhaustion_damage_received": exhaustion_damage_received_total,
		"exhaustion_move_time": exhaustion_move_time_total,
		"exhaustion_wait_time": exhaustion_wait_time_total,
		"exhaustion_other_time": exhaustion_other_time_total,
		"exhausted_dodges": exhausted_dodge_total,
		"exhausted_dodge_max_chain": exhausted_dodge_max_chain,
		"exhaustion_start_samples": exhaustion_start_samples,
		"exhaustion_start_alerted_sum": exhaustion_start_alerted_sum,
		"exhaustion_start_clear": exhaustion_start_clear,
		"exhaustion_start_pending": exhaustion_start_pending,
		"exhaustion_start_reacting_sum": exhaustion_start_reacting_sum,
		"exhaustion_end_samples": exhaustion_end_samples,
		"exhaustion_end_alerted_sum": exhaustion_end_alerted_sum,
		"exhaustion_end_clear": exhaustion_end_clear,
		"exhaustion_start_soonest_sum": exhaustion_start_soonest_sum,
		"exhaustion_start_nearest_sum": exhaustion_start_nearest_sum,
		"energy_starved_time_total": energy_starved_time_total,
		"energy_combo_starved_time_total": energy_combo_starved_time_total,
		"exhaustion_threatened_time_total": exhaustion_threatened_time_total,
		"terminal_combo_recoveries": terminal_combo_recoveries_total,
		"stealth_entries": survey_stealth_entries_total,
		"stealth_cancels": survey_stealth_cancels_total,
		"stealth_quick_reentries": survey_stealth_quick_reentries_total,
		"stealth_hidden_time": survey_stealth_hidden_time_total,
		"stealth_energy_paid": survey_stealth_energy_paid_total,
		"terminal_combo_recovery_time": terminal_combo_recovery_time_total,
		"direct_attack_uses": direct_attack_uses_total,
		"dodge_style_uses": dodge_style_uses_total.duplicate(true),
		"dodge_vulnerable_time": dodge_vulnerable_time_total,
		"dodge_recovery_damage": dodge_recovery_damage_total,
		"strike_diagnostic_count": survey_strike_diagnostics.size(),
	}
	survey_room_entry.merge(SurveyCounterCatalogScript.capture(self), true)
	survey_last_damage_source = ""

func record_survey_view_mode(mode: String, switched: bool) -> void:
	if mode not in ["isometric", "top_down"]: return
	var changed_mode := mode != survey_current_view_mode
	survey_current_view_mode = mode
	if mode_id != ModeRulesScript.COMBAT_SURVEY: return
	if not survey_room_view_modes.has(mode): survey_room_view_modes.append(mode)
	if switched and changed_mode: survey_view_switches += 1

func _survey_action_count_delta() -> Dictionary:
	var before := Dictionary(survey_room_entry.get("action_counts", {}))
	var result: Dictionary = {}
	for action_id in survey_action_counts:
		var count := int(survey_action_counts[action_id]) - int(before.get(action_id, 0))
		if count > 0: result[action_id] = count
	return result

func _survey_dodge_style_delta() -> Dictionary:
	var before := Dictionary(survey_room_entry.get("dodge_style_uses", {}))
	var result: Dictionary = {}
	for style_id in dodge_style_uses_total:
		var count := int(dodge_style_uses_total[style_id]) - int(before.get(style_id, 0))
		if count > 0: result[style_id] = count
	return result

func _survey_build_summary() -> String:
	var ranks: Array[String] = []
	for track_id in track_ranks:
		var rank := int(track_ranks[track_id])
		if rank <= 0: continue
		var selected: Array[String] = []
		var definition := CombatCatalogScript.character_track(String(track_id))
		for stage_index in range(mini(rank, Array(definition.get("stages", [])).size())):
			var stage := CombatCatalogScript.character_stage(String(track_id), stage_index)
			var stage_id := String(stage.get("id", ""))
			var choice_id := String(track_choices.get(stage_id, ""))
			if choice_id.is_empty(): continue
			for option_value in Array(stage.get("choices", [])):
				var option := Dictionary(option_value)
				if String(option.get("id", "")) == choice_id:
					selected.append(String(option.get("label", choice_id)))
					break
		var choice_suffix := " (%s)" % ", ".join(selected) if not selected.is_empty() else ""
		ranks.append("%s %d%s" % [String(track_id).replace("_", " ").capitalize(), rank, choice_suffix])
	return "%s; %s; %s" % [CombatCatalogScript.loadout_name(loadout_id), CombatCatalogScript.weapon_frame(player_weapon_frame).get("label", player_weapon_frame), ", ".join(ranks) if not ranks.is_empty() else "base tracks"]

func _complete_survey_room(outcome: String) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY or survey_feedback_pending or trial_complete: return
	_survey_finalize_strike_probe("room_ended")
	survey_pending_record = survey_room_definition.duplicate(true)
	survey_pending_record.merge({
		"outcome": outcome,
		"build_summary": _survey_build_summary(),
		"entry_hp": int(survey_room_entry.get("hp", player_hp)),
		"entry_max_hp": int(survey_room_entry.get("max_hp", player_max_hp)),
		"exit_hp": player_hp,
		"entry_energy": float(survey_room_entry.get("energy", player_energy)),
		"entry_max_energy": float(survey_room_entry.get("max_energy", player_max_energy)),
		"exit_energy": player_energy,
		"exit_max_energy": player_max_energy,
		"entry_potions": int(survey_room_entry.get("potions", potions)),
		"exit_potions": potions,
		"death_source": survey_last_damage_source if outcome == "death" else "",
		"action_usage": _survey_action_count_delta(),
		"view_modes": survey_room_view_modes.duplicate(),
		"view_switches": survey_view_switches - int(survey_room_entry.get("view_switches", survey_view_switches)),
		"empty_melee_contacts": survey_empty_melee_contacts - int(survey_room_entry.get("empty_melee_contacts", survey_empty_melee_contacts)),
		"engagement_samples": survey_engagement_samples - int(survey_room_entry.get("engagement_samples", survey_engagement_samples)),
		"engagement_alerted_sum": survey_engagement_alerted_sum - int(survey_room_entry.get("engagement_alerted_sum", survey_engagement_alerted_sum)),
		"engagement_multi_samples": survey_engagement_multi_samples - int(survey_room_entry.get("engagement_multi_samples", survey_engagement_multi_samples)),
		"isolated_kills": survey_isolated_kills - int(survey_room_entry.get("isolated_kills", survey_isolated_kills)),
		"engaged_kills": survey_engaged_kills - int(survey_room_entry.get("engaged_kills", survey_engaged_kills)),
		"combat_time": simulation_time - float(survey_room_entry.get("time", simulation_time)),
		"damage_dealt": damage_dealt - int(survey_room_entry.get("damage_dealt", damage_dealt)),
		"damage_received": damage_received_total - int(survey_room_entry.get("damage_received", damage_received_total)),
		"hits_received": hits_received_total - int(survey_room_entry.get("hits_received", hits_received_total)),
		"protected_damage": protected_damage_total - int(survey_room_entry.get("protected_damage", protected_damage_total)),
		"interruptions_prevented": interruptions_prevented_total - int(survey_room_entry.get("interruptions_prevented", interruptions_prevented_total)),
		"clean_evade_dodge": clean_evade_dodge_total - int(survey_room_entry.get("clean_evade_dodge", clean_evade_dodge_total)),
		"clean_evade_vault": clean_evade_vault_total - int(survey_room_entry.get("clean_evade_vault", clean_evade_vault_total)),
		"turnabout_primed": turnabout_primed_total - int(survey_room_entry.get("turnabout_primed", turnabout_primed_total)),
		"turnabout_consumed": turnabout_consumed_total - int(survey_room_entry.get("turnabout_consumed", turnabout_consumed_total)),
		"capture": _survey_capture_summary(),
		"potions_used": potions_used_total - int(survey_room_entry.get("potions_used", potions_used_total)),
		"perfect_dodges": perfect_dodges - int(survey_room_entry.get("perfect_dodges", perfect_dodges)),
		"successful_blocks": successful_blocks - int(survey_room_entry.get("successful_blocks", successful_blocks)),
		"successful_endures": successful_endures - int(survey_room_entry.get("successful_endures", successful_endures)),
		"energy_spent": energy_spent_total - float(survey_room_entry.get("energy_spent", energy_spent_total)),
		"energy_depleted": energy_depleted_total - float(survey_room_entry.get("energy_depleted", energy_depleted_total)),
		"energy_overdraw": energy_overdraw_total - float(survey_room_entry.get("energy_overdraw", energy_overdraw_total)),
		"energy_regenerated": energy_regenerated_total - float(survey_room_entry.get("energy_regenerated", energy_regenerated_total)),
		"energy_regen_delay_time": energy_regen_delay_time_total - float(survey_room_entry.get("energy_regen_delay_time", energy_regen_delay_time_total)),
		"energy_regen_active_time": energy_regen_active_time_total - float(survey_room_entry.get("energy_regen_active_time", energy_regen_active_time_total)),
		"overexertions": overexertion_count - int(survey_room_entry.get("overexertions", overexertion_count)),
		"winded_time": winded_time_total - float(survey_room_entry.get("winded_time", winded_time_total)),
		"energy_blocked_continuations": energy_blocked_continuations - int(survey_room_entry.get("energy_blocked_continuations", energy_blocked_continuations)),
		"exhaustion_damage_received": exhaustion_damage_received_total - int(survey_room_entry.get("exhaustion_damage_received", exhaustion_damage_received_total)),
		"exhaustion_move_time": exhaustion_move_time_total - float(survey_room_entry.get("exhaustion_move_time", exhaustion_move_time_total)),
		"exhaustion_wait_time": exhaustion_wait_time_total - float(survey_room_entry.get("exhaustion_wait_time", exhaustion_wait_time_total)),
		"exhaustion_other_time": exhaustion_other_time_total - float(survey_room_entry.get("exhaustion_other_time", exhaustion_other_time_total)),
		"exhausted_dodges": exhausted_dodge_total - int(survey_room_entry.get("exhausted_dodges", exhausted_dodge_total)),
		"exhausted_dodge_max_chain": exhausted_dodge_room_max_chain,
		"exhaustion_start_samples": exhaustion_start_samples - int(survey_room_entry.get("exhaustion_start_samples", exhaustion_start_samples)),
		"exhaustion_start_alerted_sum": exhaustion_start_alerted_sum - int(survey_room_entry.get("exhaustion_start_alerted_sum", exhaustion_start_alerted_sum)),
		"exhaustion_start_clear": exhaustion_start_clear - int(survey_room_entry.get("exhaustion_start_clear", exhaustion_start_clear)),
		"exhaustion_start_pending": exhaustion_start_pending - int(survey_room_entry.get("exhaustion_start_pending", exhaustion_start_pending)),
		"exhaustion_start_reacting_sum": exhaustion_start_reacting_sum - int(survey_room_entry.get("exhaustion_start_reacting_sum", exhaustion_start_reacting_sum)),
		"exhaustion_end_samples": exhaustion_end_samples - int(survey_room_entry.get("exhaustion_end_samples", exhaustion_end_samples)),
		"exhaustion_end_alerted_sum": exhaustion_end_alerted_sum - int(survey_room_entry.get("exhaustion_end_alerted_sum", exhaustion_end_alerted_sum)),
		"exhaustion_end_clear": exhaustion_end_clear - int(survey_room_entry.get("exhaustion_end_clear", exhaustion_end_clear)),
		"exhaustion_start_soonest_sum": exhaustion_start_soonest_sum - float(survey_room_entry.get("exhaustion_start_soonest_sum", exhaustion_start_soonest_sum)),
		"exhaustion_start_nearest_sum": exhaustion_start_nearest_sum - float(survey_room_entry.get("exhaustion_start_nearest_sum", exhaustion_start_nearest_sum)),
		"energy_starved_time_total": energy_starved_time_total - float(survey_room_entry.get("energy_starved_time_total", energy_starved_time_total)),
		"energy_combo_starved_time_total": energy_combo_starved_time_total - float(survey_room_entry.get("energy_combo_starved_time_total", energy_combo_starved_time_total)),
		"exhaustion_threatened_time_total": exhaustion_threatened_time_total - float(survey_room_entry.get("exhaustion_threatened_time_total", exhaustion_threatened_time_total)),
		"terminal_combo_recoveries": terminal_combo_recoveries_total - int(survey_room_entry.get("terminal_combo_recoveries", terminal_combo_recoveries_total)),
		"formation_ids": Array(survey_room_definition.get("formation_ids", [])).duplicate(),
		"reach_times": survey_reach_times.duplicate(true),
		"stray_projectile_hits": survey_stray_projectile_hits - int(survey_room_entry.get("stray_projectile_hits", survey_stray_projectile_hits)),
		"javelins_grounded": survey_javelins_grounded - int(survey_room_entry.get("javelins_grounded", survey_javelins_grounded)),
		"barriers_raised": survey_barriers_raised - int(survey_room_entry.get("barriers_raised", survey_barriers_raised)),
		"blind_collisions": survey_blind_collisions - int(survey_room_entry.get("blind_collisions", survey_blind_collisions)),
		"barrier_blocks": survey_barrier_blocks - int(survey_room_entry.get("barrier_blocks", survey_barrier_blocks)),
		"burn_damage": survey_burn_damage_total - int(survey_room_entry.get("burn_damage", survey_burn_damage_total)),
		"frost_amplified_hits": survey_frost_amplified_hits - int(survey_room_entry.get("frost_amplified_hits", survey_frost_amplified_hits)),
		"shots_fired": survey_shots_fired,
		"shots_hit": survey_shots_hit,
		"shots_blocked": survey_shots_blocked,
		"stealth_entries": survey_stealth_entries_total - int(survey_room_entry.get("stealth_entries", survey_stealth_entries_total)),
		"stealth_cancels": survey_stealth_cancels_total - int(survey_room_entry.get("stealth_cancels", survey_stealth_cancels_total)),
		"stealth_quick_reentries": survey_stealth_quick_reentries_total - int(survey_room_entry.get("stealth_quick_reentries", survey_stealth_quick_reentries_total)),
		"stealth_hidden_time": survey_stealth_hidden_time_total - float(survey_room_entry.get("stealth_hidden_time", survey_stealth_hidden_time_total)),
		"stealth_energy_paid": survey_stealth_energy_paid_total - float(survey_room_entry.get("stealth_energy_paid", survey_stealth_energy_paid_total)),
		"terminal_combo_recovery_time": terminal_combo_recovery_time_total - float(survey_room_entry.get("terminal_combo_recovery_time", terminal_combo_recovery_time_total)),
		"direct_attack_uses": direct_attack_uses_total - int(survey_room_entry.get("direct_attack_uses", direct_attack_uses_total)),
		"dodge_style_uses": _survey_dodge_style_delta(),
		"dodge_vulnerable_time": dodge_vulnerable_time_total - float(survey_room_entry.get("dodge_vulnerable_time", dodge_vulnerable_time_total)),
		"dodge_recovery_damage": dodge_recovery_damage_total - int(survey_room_entry.get("dodge_recovery_damage", dodge_recovery_damage_total)),
		"strike_diagnostics": survey_strike_diagnostics.slice(int(survey_room_entry.get("strike_diagnostic_count", 0))).duplicate(true),
		"ratings": {}, "tags": [], "notes": "", "subjective_skipped": false,
	}, true)
	# Counter descriptors are authoritative. The explicit fields above remain during
	# this migration only as a compatibility audit: descriptor values overwrite them.
	survey_pending_record.merge(SurveyCounterCatalogScript.room_values(self, survey_room_entry), true)
	survey_feedback_pending = true
	# A one-shot custom room finishes the run when its room finishes, whatever the outcome.
	survey_run_ending = outcome in ["death", "manual_end"] or (_custom_room_active() and not custom_room_repeat)
	survey_end_reason = outcome
	player_action = _idle_action()
	projectiles.clear()
	hazards.clear()
	_set_message("Room %d complete. Record how the encounter felt." % survey_room_number)
	changed.emit()

func submit_survey_feedback(ratings: Dictionary, tags: Array, notes: String) -> void:
	if not survey_feedback_pending: return
	survey_pending_record["ratings"] = ratings.duplicate(true)
	survey_pending_record["tags"] = tags.duplicate()
	survey_pending_record["notes"] = notes.strip_edges()
	survey_pending_record["subjective_skipped"] = false
	_store_survey_feedback()

func skip_survey_feedback(notes: String = "") -> void:
	if not survey_feedback_pending: return
	survey_pending_record["ratings"] = {}
	survey_pending_record["tags"] = []
	survey_pending_record["notes"] = notes.strip_edges()
	survey_pending_record["subjective_skipped"] = true
	_store_survey_feedback()

func _store_survey_feedback() -> void:
	var rooms: Array = survey_session.get("rooms", [])
	rooms.append(survey_pending_record.duplicate(true))
	survey_session["rooms"] = rooms
	survey_feedback_pending = false
	survey_pending_record.clear()
	SurveyReportScript.save_current(survey_session)
	if survey_run_ending:
		_finalize_survey_run(survey_end_reason)
	else:
		rooms_cleared += 1
		_load_next_survey_room()

func end_survey_run() -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY or trial_complete or survey_feedback_pending: return
	_complete_survey_room("manual_end")

func _finalize_survey_run(reason: String) -> void:
	survey_session["ended_at"] = Time.get_datetime_string_from_system(false, true)
	survey_session["end_reason"] = reason
	survey_last_report = SurveyReportScript.archive_session(survey_session)
	trial_complete = true
	survey_run_ending = true
	_set_message("Combat Survey saved: %d rooms recorded." % Array(survey_session.get("rooms", [])).size())
	changed.emit()

func _load_next_survey_room() -> void:
	survey_room_number += 1
	if survey_profile == "encounter":
		player_hp = player_max_hp
		player_posture = player_posture_max
		potions = healing_capacity()
		dodge_cooldown = 0.0
		block_cooldown = 0.0
		endure_cooldown = 0.0
		skill_cooldown = 0.0
		rally_cooldown = 0.0
		advance_cooldown = 0.0
		main_ability_cooldown = 0.0
		subclass_ability_cooldown = 0.0
		weapon_sequence_cooldown = 0.0
		player_conditions.clear()
		player_condition_buildup.clear()
	player_energy = player_max_energy
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_energy_regen_delay = 0.0
	survey_strike_diagnostics.clear()
	var layout := _generate_survey_layout(survey_room_number)
	world_size = Vector2(layout["world_size"])
	geometry_style = String(layout["geometry_style"])
	areas.assign(Array(layout["areas"]).duplicate(true))
	connections.assign(Array(layout["connections"]).duplicate(true))
	route_recipe.assign(Array(layout["route_recipe"]).duplicate(true))
	run_graph = Dictionary(layout["run_graph"]).duplicate(true)
	locale_catalog = Dictionary(layout["locale_catalog"]).duplicate(true)
	floor_shapes.assign(Array(layout["floor_shapes"]).duplicate(true))
	terrain_features.assign(Array(layout["terrain_features"]).duplicate(true))
	world_pickups.clear()
	waystones.clear()
	shortcuts.clear()
	transitions.clear()
	secret_passages.clear()
	world_layers = Dictionary(layout["layers"]).duplicate(true)
	encounter_templates = Dictionary(layout["encounters"]).duplicate(true)
	base_walls_by_layer = Dictionary(layout["layer_walls"]).duplicate(true)
	current_layer = "survey_arena"
	_player_start = Vector2(layout["player_start"])
	player_pos = _player_start
	player_facing = Vector2.UP
	player_action = _idle_action()
	projectiles.clear()
	hazards.clear()
	effects.clear()
	_navigation_cache.clear()
	discovered_cells.clear()
	discovered_cells_by_layer.clear()
	discovered_cells_by_layer[current_layer] = discovered_cells
	visible_cells.clear()
	discovery_revision += 1
	discovery_epoch += 1
	world_render_revision += 1
	_build_shape_spatial_index()
	current_area_id = 0
	_respawn_enemies()
	_apply_shortcut_world_state()
	rng.seed = survey_room_seed ^ 0x51A7E
	_update_exploration(true)
	_capture_survey_room_entry()
	SurveyReportScript.save_current(survey_session)
	_set_message("Combat Survey room %d. Seed %d." % [survey_room_number, survey_room_seed])
	last_timeline.clear()
	changed.emit()

func survey_report_text() -> String:
	return SurveyReportScript.build_text(survey_last_report if not survey_last_report.is_empty() else survey_session)

func survey_report_filename() -> String:
	return SurveyReportScript.report_filename(survey_last_report if not survey_last_report.is_empty() else survey_session)

func survey_archive() -> Dictionary:
	return SurveyReportScript.load_archive()

func survey_all_reports_text() -> String:
	return SurveyReportScript.all_reports_text()

func abandon_run() -> void:
	run_active = false
	death_pending = false
	upgrade_pending = false
	player_action = _idle_action()
	last_timeline.clear()
	changed.emit()

func mode_rules() -> Dictionary:
	return mode_config.duplicate(true)

func mode_label() -> String:
	return ModeRulesScript.label(mode_id)

func provisional_xp() -> int:
	return maxi(0, carried_xp - secured_xp) if bool(mode_config["waystone_available"]) else carried_xp

func unanchored_discovery_count() -> int:
	if not bool(mode_config["waystone_available"]): return 0
	_store_current_layer_discovery()
	var anchored_layers: Dictionary = anchor_state.get("discovered_cells_by_layer", {})
	var count := 0
	for layer in discovered_cells_by_layer:
		var current: Dictionary = discovered_cells_by_layer[layer]
		var anchored: Dictionary = anchored_layers.get(layer, {})
		for cell in current:
			if not anchored.has(cell): count += 1
	return count

func unanchored_shortcut() -> bool:
	var anchored: Dictionary = anchor_state.get("shortcut_states", {})
	for shortcut in shortcuts:
		if bool(shortcut.get("unlocked", false)) and not bool(anchored.get(String(shortcut["id"]), false)): return true
	return shortcut_unlocked and shortcuts.is_empty() and not bool(anchor_state.get("shortcut_unlocked", false))

func has_unanchored_progress() -> bool:
	return provisional_xp() > 0 or unanchored_discovery_count() > 0 or unanchored_shortcut()

func _enemy_base_hp(kind: String) -> int:
	# The Polearm is a soldier carrying a long weapon, not a heavyweight. At radius 42
	# and 60 health it had a Boar's body and nearly a Shield's durability while acting
	# as a support unit, which does not read: an enemy that size needs a boss's move
	# set to earn it. Dropped to an ordinary humanoid frame so its reach is the thing
	# that makes it dangerous.
	return int(CombatCatalogScript.enemy_fact(kind, "base_hp"))

func _make_enemy(kind: String, position: Vector2, hp: int, area_id: int = 0) -> Dictionary:
	var combat_profile := CombatCatalogScript.archetype(kind)
	var attributes := Dictionary(combat_profile["attributes"]).duplicate(true)
	attributes["health"] = hp
	var posture_max := _enemy_posture_base(kind) + float(attributes.get("resolve", 5))
	var enemy := {
		"id": _next_enemy_id,
		"faction": "enemy",
		"kind": kind,
		"pos": position,
		"spawn_pos": position,
		"area_id": area_id,
		"facing": Vector2.DOWN,
		"hp": hp,
		"max_hp": hp,
		"radius": float(combat_profile["radius"]),
		"posture": posture_max,
		"posture_max": posture_max,
		"posture_recovery_delay": 0.0,
		"is_moving": false,
		"last_motion": Vector2.ZERO,
		"stalled_time": 0.0,
		"action": _idle_action(),
		"awareness": "idle",
		"revealed_to_player": kind != "bandit",
		"revealed_elapsed": 0.0,
		"player_los": false,
		"los_refresh_remaining": 0.0,
		"alert_remaining": 0.0,
		"suspicious_remaining": 0.0,
		"last_known_player": position,
		"heard_sound_sequence": 0,
		"pounce_cooldown": 0.0,
		"chants": {},
		"chant_source_id": -1,
		"parry_cooldown": 0.0,
		"patience": _shield_patience_budget(kind, position, _next_enemy_id),
		"patience_max": _shield_patience_budget(kind, position, _next_enemy_id),
		"dodge_cooldown": 0.0,
		"neutral_cooldown": 0.0,
		"shot_cooldown": 0.22 * float(_next_enemy_id % 3) if kind == "archer" else 0.0,
		"weapon_frame": String(combat_profile["weapon_frame"]),
		"weapon_art_ids": Array(combat_profile["weapon_arts"]).duplicate(),
		"equipped_weapon_art": String(combat_profile["equipped_weapon_art"]),
		"defense_id": String(combat_profile["defense_id"]),
		"attributes": attributes,
		"properties": Dictionary(combat_profile["properties"]).duplicate(true),
		"personal_tempo": _tempo_from_attributes(attributes),
		"posture_recovery_rate": float(Dictionary(combat_profile["properties"]).get("posture_recovery", 1.8)),
		"condition_buildup": {},
		"conditions": {},
	}
	_next_enemy_id += 1
	return enemy

func _respawn_enemies() -> void:
	_replace_enemy_actors([])
	projectiles.clear()
	hazards.clear()
	_next_enemy_id = 1
	for area_key in encounter_templates:
		var area_id := int(area_key)
		for template in Array(encounter_templates[area_key]):
			var kind := String(template["kind"])
			if kind in ["warden", "werewolf"] and _boss_defeated: continue
			var enemy := _make_enemy(kind, Vector2(template["pos"]), _enemy_base_hp(kind), area_id)
			enemy["layer"] = String(template.get("layer", "expedition_surface"))
			enemy["survey_role"] = CombatCatalogScript.role(String(template.get("kind", enemy.get("kind", ""))))
			if template.has("facing"):
				var authored_facing := Vector2(template["facing"])
				if authored_facing.length_squared() > 0.001: enemy["facing"] = authored_facing.normalized()
			enemy["heard_sound_sequence"] = _sound_sequence
			_add_enemy_actor(enemy)

func _enemy_posture_base(kind: String) -> float:
	# Resolve supplies the universal portion. These hidden bases preserve body
	# and equipment identity without creating another visible character stat.
	return float(CombatCatalogScript.enemy_fact(kind, "posture_base"))

func _enemy_posture_max(kind: String) -> float:
	var profile := CombatCatalogScript.archetype(kind)
	return _enemy_posture_base(kind) + float(Dictionary(profile["attributes"]).get("resolve", 5))

func _hydrate_enemy_combat_profile(enemy: Dictionary) -> Dictionary:
	if not enemy.has("faction"): enemy["faction"] = "enemy"
	var profile := CombatCatalogScript.archetype(String(enemy.get("kind", "blade")))
	if not enemy.has("weapon_frame"): enemy["weapon_frame"] = String(profile["weapon_frame"])
	if not enemy.has("weapon_art_ids"): enemy["weapon_art_ids"] = Array(profile["weapon_arts"]).duplicate()
	if not enemy.has("equipped_weapon_art"): enemy["equipped_weapon_art"] = String(profile["equipped_weapon_art"])
	if not enemy.has("defense_id"): enemy["defense_id"] = String(profile["defense_id"])
	if not enemy.has("attributes"): enemy["attributes"] = Dictionary(profile["attributes"]).duplicate(true)
	elif not Dictionary(enemy["attributes"]).has("energy"):
		var hydrated_attributes := Dictionary(enemy["attributes"])
		hydrated_attributes["energy"] = int(Dictionary(profile["attributes"]).get("energy", 100))
		enemy["attributes"] = hydrated_attributes
	if not enemy.has("properties"): enemy["properties"] = Dictionary(profile["properties"]).duplicate(true)
	if not enemy.has("revealed_to_player"): enemy["revealed_to_player"] = String(enemy.get("kind", "")) != "bandit"
	if not enemy.has("revealed_elapsed"): enemy["revealed_elapsed"] = 0.0
	if not enemy.has("player_los"): enemy["player_los"] = false
	if not enemy.has("los_refresh_remaining"): enemy["los_refresh_remaining"] = 0.0
	if not enemy.has("condition_buildup"): enemy["condition_buildup"] = {}
	if not enemy.has("conditions"): enemy["conditions"] = {}
	enemy["personal_tempo"] = _tempo_from_attributes(Dictionary(enemy["attributes"]))
	enemy["posture_recovery_rate"] = float(Dictionary(enemy["properties"]).get("posture_recovery", 1.8))
	var posture_max := _enemy_posture_base(String(enemy.get("kind", "blade"))) + float(Dictionary(enemy["attributes"]).get("resolve", 5))
	var posture_ratio := float(enemy.get("posture", posture_max)) / maxf(0.001, float(enemy.get("posture_max", posture_max)))
	enemy["posture_max"] = posture_max
	enemy["posture"] = clampf(posture_ratio * posture_max, 0.0, posture_max)
	return enemy

func _sync_player_combat_profile() -> void:
	var profile := CombatCatalogScript.loadout_profile(loadout_id)
	player_weapon_frame = String(profile["weapon_frame"])
	player_weapon_art_library.assign(Array(profile["weapon_arts"]))
	player_equipped_weapon_art = String(profile["equipped_weapon_art"])
	player_attributes = Dictionary(profile["attributes"]).duplicate(true)
	player_properties = Dictionary(profile["properties"]).duplicate(true)
	martial_foundation = CombatCatalogScript.MARTIAL_DEFAULTS.duplicate(true)
	equipment_slots = {
		"main_hand": String(CombatCatalogScript.weapon_frame(player_weapon_frame).get("label", "Weapon")),
		"off_hand": "Empty",
		"head": "Empty",
		"torso": "Padded Jack" if loadout_id == "warrior" else "Travel Leathers",
		"hands": "Worn Gloves",
		"legs": "Travel Boots",
		"charm": "Waystone Fragment",
		"backpack": "Restorative Satchel",
	}
	_refresh_player_posture_capacity(true)

func player_actor() -> Dictionary:
	# Health and movement speed remain live values while the rest of the shared
	# attribute profile remains ready for temperament-gated advancement.
	var attributes := player_attributes.duplicate(true)
	attributes["health"] = player_max_hp
	attributes["energy"] = roundi(player_max_energy)
	attributes["speed"] = int(player_attributes.get("speed", 5))
	var properties := player_properties.duplicate(true)
	properties["collision_radius"] = PLAYER_RADIUS
	return {
		"kind": "player",
		"current_energy": player_energy,
		"maximum_energy": player_max_energy,
		"weapon_frame": player_weapon_frame,
		"weapon_art_ids": player_weapon_art_library.duplicate(),
		"equipped_weapon_art": player_equipped_weapon_art,
		"defense_id": defense_id,
		"attributes": attributes,
		"properties": properties,
		"martial_foundation": martial_foundation.duplicate(true),
		"equipment_slots": equipment_slots.duplicate(true),
		"track_ranks": track_ranks.duplicate(true),
		"track_choices": track_choices.duplicate(true),
	}

func select_loadout(choice: String) -> bool:
	if not CombatCatalogScript.loadout_ids().has(choice): return false
	loadout_id = choice
	if run_active: start_run(loadout_id, mode_id, run_seed)
	else: _apply_loadout()
	return true

func _apply_loadout() -> void:
	_sync_player_combat_profile()
	defense_id = String(CombatCatalogScript.loadout_profile(loadout_id).get("defense_id", "dodge"))
	player_max_hp = int(player_attributes.get("health", PLAYER_MAX_HP))
	player_max_energy = float(player_attributes.get("energy", 100))
	# The armoured Warrior should not be able to reset melee pressure through
	# ordinary walking. Faster loadouts retain their existing traversal speed;
	# the Warrior instead depends on deliberate defensive movement when flankers
	# close the distance.
	player_move_speed = WARRIOR_MOVE_SPEED if loadout_id == "warrior" else MOVE_SPEED
	if loadout_id == "mage_elementalist" and player_spells.is_empty():
		player_spells = ["lightning_bolt"]
		selected_spell = "lightning_bolt"
	match player_weapon_frame:
		"knife", "twin_knives":
			player_attack_duration = 0.70
			player_attack_startup = 0.16
			player_attack_active_end = 0.27
			player_damage_min = 6
			player_damage_max = 6
			player_attack_technique = "knife_cut_in"
			player_attack_reach = 74.0
			player_attack_posture = 1.0
		"staff":
			# Long and slow, and it does less per hit than a sword. The staff's whole case is
			# the ground it covers and the posture it takes.
			player_attack_duration = 1.24
			player_attack_startup = 0.30
			player_attack_active_end = 0.44
			player_damage_min = 8
			player_damage_max = 8
			player_attack_technique = "staff_thrust"
			player_attack_reach = 150.0
			player_attack_posture = 1.8
		"bow":
			player_attack_duration = 0.70
			player_attack_startup = 0.10
			player_attack_active_end = 0.12
			player_damage_min = 6
			player_damage_max = 6
			player_attack_technique = "drawn_shot"
			player_attack_reach = 250.0
			player_attack_posture = 0.0
		_:
			player_attack_duration = 1.06
			player_attack_startup = 0.30
			player_attack_active_end = 0.41
			player_damage_min = 10
			player_damage_max = 10
			player_attack_technique = "diagonal_cut"
			player_attack_reach = 112.0
			player_attack_posture = 2.0

func _tempo_from_attributes(attributes: Dictionary) -> float:
	return clampf(1.0 + 0.03 * (float(attributes.get("speed", 5)) - 5.0), 0.76, 1.30)

func _player_personal_tempo() -> float:
	# Proportional to what is left rather than a flat 0.85 while any frost stands. A meter
	# the player can watch draining is legible; a binary modifier is the Captain's x1.14
	# aura again, which 0.2.33 deleted for being imperceptible.
	return _tempo_from_attributes(player_attributes) * (1.0 - FROST_MAX_SLOW * player_frost_fraction())

# "stamina" is still accepted as an id. The rename is a rename, and a saved run or an
# archived survey that predates it names a profile that still exists under another word.
static func normalize_combat_rules(value: String) -> String:
	return "energy" if value == "stamina" else ("energy" if value not in ["recovery", "energy"] else value)

func uses_energy_rules() -> bool:
	return combat_rules == "energy"

func energy_actions_locked() -> bool:
	return uses_energy_rules() and (player_energy <= 0.0001 or player_overexertion_pending or player_exhaustion_remaining > 0.0001)

func basic_attack_lock_remaining() -> float:
	return 0.0

func basic_attack_is_available() -> bool:
	return is_player_ready() and not trial_complete and weapon_sequence_cooldown <= 0.0001 and _can_commit_physical_action()

func _can_start_basic_attack() -> bool:
	return is_player_ready() and not trial_complete and weapon_sequence_cooldown <= 0.0001 and _can_commit_physical_action()

# The log is one line, occasionally two. These used to run to four sentences and arrived
# truncated mid-word however the renderer shrank or wrapped them, which is the game
# explaining its own rules halfway. What survives is what a player needs on entering a
# room; the rest is discoverable by playing, which is where it was always going to be
# learned anyway.
func _combat_rules_intro() -> String:
	if not uses_energy_rules():
		return "Recovery rules: abilities and defences run on cooldowns. Energy is inactive."
	return "Energy rules: acting and dodging spend Energy, which refills unless you are hit. Empty it and you are exhausted."

func _can_commit_physical_action() -> bool:
	return not uses_energy_rules() or not energy_actions_locked()

func player_is_exhausted() -> bool:
	return uses_energy_rules() and player_exhaustion_remaining > 0.0001

# Every consumer of walking speed goes through this, so exhaustion slows stepping,
# the Wait unit derived from a step, and the streamed-move duration together.
func current_move_speed() -> float:
	return player_move_speed * (EXHAUSTED_MOVE_SCALE if player_is_exhausted() else 1.0) * _terrain_speed_scale(player_pos)

# Sundered ground slows whoever is standing in it, player and enemy alike. Making it
# one-sided would have been simpler and would have read as arbitrary; symmetrical, it
# becomes terrain the player can use -- an Ox charging through broken earth is slowed
# by the same rule, which is the whole-buffalo principle applied to a hazard.
func _terrain_speed_scale(position: Vector2) -> float:
	var scale := 1.0
	for hazard in hazards:
		if String(hazard.get("kind", "")) != "sundered_ground": continue
		if String(hazard.get("layer", current_layer)) != current_layer: continue
		if not bool(hazard.get("triggered", false)): continue
		if position.distance_to(Vector2(hazard["pos"])) > float(hazard.get("radius", SUNDERED_RADIUS)): continue
		scale = minf(scale, float(hazard.get("slow", SUNDERED_SLOW)))
	return scale

# Dodge is the one physical action exhaustion does not take away. The UI asks this
# rather than energy_actions_locked() so the button stays live while winded.
func dodge_is_available() -> bool:
	return is_player_ready() and not trial_complete and (uses_energy_rules() or dodge_cooldown <= 0.0001)

func energy_cost(amount: float) -> float:
	return amount * ENERGY_COST_SCALE

# Intelligence applies to spells only. A staff swing is not cleverer for being cast by a
# clever person, and letting Intelligence discount physical actions would make it a
# universal stat that every class wanted.
func player_intelligence() -> int:
	var total := int(player_attributes.get("intelligence", INTELLIGENCE_BASELINE))
	if player_is_inside_circle(): total += circle_intelligence_bonus()
	return total

func circle_intelligence_bonus() -> int:
	return CIRCLE_INTELLIGENCE * (2 if track_choice("circle_mastery") == "deep_circle" else 1)

func circle_radius() -> float:
	return CIRCLE_WIDE_RADIUS if track_choice("circle_mastery") == "wide_circle" else CIRCLE_RADIUS

func player_is_inside_circle() -> bool:
	return circle_remaining > 0.0 and player_pos.distance_to(circle_pos) <= circle_radius()

func spell_energy_cost(spell_id: String) -> float:
	var raw := float(AbilityCatalogScript.spell(spell_id).get("energy", 24.0))
	var discount := 1.0 - float(player_intelligence() - INTELLIGENCE_BASELINE) * SPELL_COST_PER_INTELLIGENCE
	return energy_cost(raw * maxf(SPELL_COST_FLOOR, discount))

# A cooldown is the ability's price expressed as a share of the pool, times the one
# global rate. See COOLDOWN_SECONDS_PER_FULL_POOL for why the pool is the denominator.
func _cooldown_for(spend: float) -> float:
	return spend / maxf(1.0, player_max_energy) * COOLDOWN_SECONDS_PER_FULL_POOL

func _cooldown_for_last_spend() -> float:
	return _cooldown_for(_last_energy_spend)

func _new_cooldown_slots() -> Dictionary:
	var result := {}
	for slot in COOLDOWN_SLOT_DEFAULTS:
		result[slot] = {"remaining": 0.0, "maximum": float(COOLDOWN_SLOT_DEFAULTS[slot])}
	return result

func _cooldown_slot(slot: String) -> Dictionary:
	if not cooldowns.has(slot):
		push_error("Unknown cooldown slot: %s" % slot)
		cooldowns[slot] = {"remaining": 0.0, "maximum": 0.0001}
	return Dictionary(cooldowns[slot])

func cooldown_remaining(slot: String) -> float:
	return float(_cooldown_slot(slot).get("remaining", 0.0))

func cooldown_maximum(slot: String) -> float:
	return float(_cooldown_slot(slot).get("maximum", 0.0001))

func _set_cooldown_remaining(slot: String, seconds: float) -> void:
	var value := _cooldown_slot(slot)
	value["remaining"] = maxf(0.0, seconds)
	cooldowns[slot] = value

func _set_cooldown_maximum(slot: String, seconds: float) -> void:
	var value := _cooldown_slot(slot)
	value["maximum"] = maxf(0.0001, seconds)
	cooldowns[slot] = value

func begin_cooldown(slot: String, seconds: float) -> void:
	_set_cooldown_remaining(slot, seconds)
	_set_cooldown_maximum(slot, seconds)

func _begin_skill_cooldown(seconds: float) -> void:
	begin_cooldown(COOLDOWN_SKILL, seconds)

func _begin_advance_cooldown(seconds: float) -> void:
	begin_cooldown(COOLDOWN_ADVANCE, seconds)

func _begin_main_ability_cooldown(seconds: float) -> void:
	begin_cooldown(COOLDOWN_MAIN, seconds)

func _begin_subclass_cooldown(seconds: float) -> void:
	begin_cooldown(COOLDOWN_SUBCLASS, seconds)

# `scaled = false` charges the authored number directly. Sweeping Cut uses it:
# see the note on SWEEPING_CUT_ENERGY for why price parity with the combo could
# not hold it in check.
func _basic_attack_energy_cost() -> float:
	return 12.0 if player_weapon_frame == "twin_knives" else 14.0 if player_weapon_frame == "knife" else 18.0

# Whole-sequence price. Sitting between this and the basic cost is the interesting
# band: you can open, but you cannot commit to finishing. Kept in sync by hand with
# the phase arrays in _begin_sword_combo and _begin_knife_combo.
func _combo_energy_cost() -> float:
	return 60.0 if player_weapon_frame == "twin_knives" else 54.0 if player_weapon_frame == "knife" else 56.0

func _spend_energy(raw_amount: float, scaled: bool = true) -> bool:
	# Priced in both profiles even though Recovery deducts nothing, because Recovery
	# derives its cooldown from this number. One authored cost, two rule sets.
	_last_energy_spend = energy_cost(raw_amount) if scaled else raw_amount
	if not uses_energy_rules(): return true
	if raw_amount <= 0.0: return true
	if not _can_commit_physical_action(): return false
	var amount := energy_cost(raw_amount) if scaled else raw_amount
	var before := player_energy
	player_energy = maxf(0.0, player_energy - amount)
	energy_spent_total += amount
	energy_depleted_total += before - player_energy
	energy_overdraw_total += maxf(0.0, amount - before)
	# Spending no longer arms the regeneration delay. Only being hit does, so
	# recovery reads as continuous breathing rather than a hold-then-snap refill.
	if player_energy <= 0.0001:
		player_energy = 0.0
		player_overexertion_pending = true
	return true

func _regenerate_energy(dt: float) -> void:
	if not uses_energy_rules() or player_overexertion_pending or dt <= 0.0: return
	# Suspended while hidden. A 10/s drain against 28/s of regeneration is not a price,
	# it is a slower profit -- hiding would still refill you. Concealment has to compete
	# with dodging for the same pool or the drain means nothing.
	if stealth_remaining > 0.0: return
	var active_dt := dt
	if player_energy_regen_delay > 0.0:
		var delayed := minf(player_energy_regen_delay, active_dt)
		player_energy_regen_delay -= delayed
		energy_regen_delay_time_total += delayed
		active_dt -= delayed
	if active_dt <= 0.0 or player_energy >= player_max_energy: return
	var before := player_energy
	player_energy = minf(player_max_energy, player_energy + ENERGY_REGEN_PER_SECOND * active_dt)
	energy_regenerated_total += player_energy - before
	energy_regen_active_time_total += active_dt

# Alerted state rather than raw proximity: an Archer at 600 units putting arrows
# into you is threat, and distance alone says otherwise. `soonest` is how long
# until the nearest committed attack opens its damaging window, which is what
# actually answers whether exhaustion arrived during a window of danger.
func _threat_snapshot() -> Dictionary:
	var alerted := 0
	var nearest := -1.0
	var pending := 0
	var reacting := 0
	var soonest := -1.0
	for enemy in enemies:
		if int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
		if String(enemy.get("awareness", "idle")) != "alerted": continue
		alerted += 1
		var gap := Vector2(enemy["pos"]).distance_to(player_pos)
		if nearest < 0.0 or gap < nearest: nearest = gap
		var action: Dictionary = enemy.get("action", {})
		# An alerted enemy in stagger or hit reaction is awake but cannot punish
		# anything. Separating them tests whether exhaustion is covered by the very
		# combo that caused it.
		if String(action.get("kind", "idle")) in ["stagger", "hit_reaction"]: reacting += 1
		if String(action.get("kind", "idle")) not in ENEMY_ATTACK_ACTION_KINDS: continue
		var startup := float(action.get("startup", -1.0))
		if startup < 0.0: continue
		var remaining := startup - float(action.get("elapsed", 0.0))
		if remaining < 0.0: continue
		pending += 1
		if soonest < 0.0 or remaining < soonest: soonest = remaining
	return {"alerted": alerted, "nearest": nearest, "pending": pending, "reacting": reacting, "soonest": soonest}

func _record_exhaustion_threat(start: bool) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY: return
	var snapshot := _threat_snapshot()
	var alerted := int(snapshot["alerted"])
	if start:
		exhaustion_start_samples += 1
		exhaustion_start_alerted_sum += alerted
		if alerted == 0: exhaustion_start_clear += 1
		if int(snapshot["pending"]) > 0:
			exhaustion_start_pending += 1
			exhaustion_start_soonest_sum += float(snapshot["soonest"])
		exhaustion_start_reacting_sum += int(snapshot["reacting"])
		if float(snapshot["nearest"]) >= 0.0: exhaustion_start_nearest_sum += float(snapshot["nearest"])
	else:
		exhaustion_end_samples += 1
		exhaustion_end_alerted_sum += alerted
		if alerted == 0: exhaustion_end_clear += 1

func _begin_exhaustion() -> void:
	if not uses_energy_rules(): return
	player_overexertion_pending = false
	player_exhaustion_remaining = EXHAUSTION_DURATION
	overexertion_count += 1
	_record_exhaustion_threat(true)
	_set_message("EXHAUSTED — attacks are locked and your footwork is slow. Dodge still answers, but it costs you the recovery.")

func _shorten_recovery(duration: float, active_end: float, factor: float = 0.60) -> float:
	if not uses_energy_rules(): return duration
	return active_end + maxf(0.0, duration - active_end) * factor

func _linked_combo_phases(raw_phases: Array[Dictionary], recovery_before_link: float = 0.25) -> Array[Dictionary]:
	# Each authored phase keeps its complete terminal recovery. Continuing the
	# sequence commits at a weapon-specific link point during the follow-through,
	# then starts the next wind-up without serving the rest of that recovery.
	# This timing grammar is shared by Recovery and Energy rules; the profiles
	# differ in how actions are budgeted, not in how the same weapon handles.
	var result: Array[Dictionary] = []
	var raw_origin := 0.0
	var linked_origin := 0.0
	for raw_value in raw_phases:
		var raw := Dictionary(raw_value)
		var startup_local := float(raw.get("startup", raw_origin)) - raw_origin
		var active_length := float(raw.get("active_end", raw_origin)) - float(raw.get("startup", raw_origin))
		var recovery_length := float(raw.get("end", raw_origin)) - float(raw.get("active_end", raw_origin))
		var linked := raw.duplicate(true)
		linked["startup"] = linked_origin + maxf(0.0, startup_local)
		linked["active_end"] = float(linked["startup"]) + maxf(0.0, active_length)
		linked["link"] = float(linked["active_end"]) + maxf(0.0, recovery_length) * clampf(recovery_before_link, 0.0, 1.0)
		linked["end"] = float(linked["active_end"]) + maxf(0.0, recovery_length)
		result.append(linked)
		raw_origin = float(raw.get("end", raw_origin))
		linked_origin = float(linked["link"])
	return result

# Cast and Circle both resolve on their own wind-up rather than through the melee tick,
# because neither has attack geometry. Windstep is the one that also moves you, so it runs
# per tick across its travel window like the enemy version does.
func _tick_player_cast(dt: float) -> void:
	var kind := String(player_action.get("kind", "idle"))
	if kind not in ["cast", "circle"]: return
	var elapsed := float(player_action.get("elapsed", 0.0))
	var startup := float(player_action.get("startup", 0.4))
	if kind == "circle":
		if elapsed >= startup and not bool(player_action.get("effect_done", false)):
			player_action["effect_done"] = true
			circle_pos = player_pos
			circle_remaining = CIRCLE_DURATION
			survey_circle_casts += 1
			_add_effect("earth_wall", player_pos)
			_set_message("The circle takes. Your casting is cheaper while you stand in it.")
		return
	var spell_id := String(player_action.get("spell_id", ""))
	if spell_id == "windstep":
		if elapsed >= startup and elapsed <= startup + 0.32:
			var step := Vector2(player_action["direction"]).normalized() * 1250.0 * dt
			var landing := player_pos + step
			if _teleport_allowed(landing, PLAYER_RADIUS, 0):
				player_pos = landing
		return
	if elapsed >= startup and not bool(player_action.get("effect_done", false)):
		player_action["effect_done"] = true
		_resolve_player_spell(spell_id, Vector2(player_action.get("target", player_pos + player_facing * 200.0)), Vector2(player_action["direction"]))

func _update_circle(dt: float) -> void:
	if circle_remaining <= 0.0: return
	circle_remaining = maxf(0.0, circle_remaining - dt)
	if circle_remaining <= 0.0: _set_message("The circle fades.")

func _increase_max_energy(amount: float) -> void:
	player_max_energy += amount
	player_energy = minf(player_max_energy, player_energy + amount)
	player_attributes["energy"] = roundi(player_max_energy)

func _migrate_v25_temperament_to_energy() -> void:
	player_max_energy = 100.0
	for stage_index in range(1, 5):
		var steadfast_choice := String(track_choices.get("steadfast_%d" % stage_index, ""))
		if steadfast_choice == "vigilance":
			player_attributes["speed"] = maxi(0, int(player_attributes.get("speed", 0)) - 1)
			player_max_energy += 10.0
		var finesse_choice := String(track_choices.get("finesse_%d" % stage_index, ""))
		if finesse_choice == "fleetness":
			player_max_hp = maxi(1, player_max_hp - 5)
			player_hp = mini(player_hp, player_max_hp)
			player_max_energy += 10.0
		elif finesse_choice == "subtlety":
			player_attributes["awareness"] = maxi(0, int(player_attributes.get("awareness", 0)) - 1)
			player_max_hp += 5
			player_hp = mini(player_max_hp, player_hp + 5)
		var patient_choice := String(track_choices.get("patient_%d" % stage_index, ""))
		if patient_choice == "observation":
			player_attributes["stealth"] = maxi(0, int(player_attributes.get("stealth", 0)) - 1)
			player_max_energy += 10.0
	player_attributes["health"] = player_max_hp
	player_attributes["energy"] = roundi(player_max_energy)

func _player_physical_damage(technique_base: int) -> int:
	return technique_base + int(player_attributes.get("strength", 0))

func _enemy_personal_tempo(enemy: Dictionary) -> float:
	# The same proportional slow the player gets. 0.2.54 made frost a draining meter on the
	# player side and left enemies on the old binary 0.85-while-any-frost-stands, so one
	# condition computed itself two different ways depending on who was frozen. Shared rules
	# are the premise, and this is one of them.
	var frost_fraction := clampf(float(Dictionary(enemy.get("conditions", {})).get("frost", 0.0)) / FROST_FULL_DURATION, 0.0, 1.0)
	return float(enemy.get("personal_tempo", _tempo_from_attributes(Dictionary(enemy.get("attributes", {}))))) * (1.0 - FROST_MAX_SLOW * frost_fraction)

func _refresh_player_posture_capacity(fill: bool = false) -> void:
	var previous_max := maxf(0.001, player_posture_max)
	var previous_ratio := clampf(player_posture / previous_max, 0.0, 1.0)
	player_posture_max = float(player_properties.get("posture_base", 5.0)) + float(player_attributes.get("resolve", 5))
	player_posture = player_posture_max if fill else clampf(previous_ratio * player_posture_max, 0.0, player_posture_max)

func enemy_visible_to_player(enemy: Dictionary) -> bool:
	if String(enemy.get("kind", "")) != "bandit": return true
	return bool(enemy.get("revealed_to_player", false))

func _empty_character_track_ranks() -> Dictionary:
	var result := {}
	for track_id in CombatCatalogScript.track_order_for_loadout(loadout_id): result[String(track_id)] = 0
	return result

func character_track_order() -> Array[String]:
	return CombatCatalogScript.track_order_for_loadout(loadout_id)

func character_level() -> int:
	return upgrade_count + 1

func has_track_rank(track_id: String, rank: int) -> bool:
	return int(track_ranks.get(track_id, 0)) >= rank

func track_choice(stage_id: String) -> String:
	return String(track_choices.get(stage_id, ""))

func _idle_action() -> Dictionary:
	return {
		"kind": "idle",
		"elapsed": 0.0,
		"duration": 0.0,
		"direction": Vector2.ZERO,
		"hit_done": false,
		"hit_ids": [],
		"effect_done": false,
		"perfect_triggered": false,
	}

func is_player_ready() -> bool:
	return run_active and not death_pending and String(player_action["kind"]) == "idle" and player_hp > 0

func request_move(direction: Vector2, distance: float = MOVE_RANGE, simulate_immediately: bool = true) -> bool:
	if not begin_streamed_move(direction, distance): return false
	if simulate_immediately: _simulate_until_ready()
	return true

func begin_streamed_move(direction: Vector2, distance: float = MOVE_RANGE) -> bool:
	if not is_player_ready() or trial_complete or direction.length_squared() < 0.01:
		return false
	_break_player_combo()
	var travel := clampf(distance, 4.0, MOVE_RANGE)
	var normalized := direction.normalized()
	player_facing = normalized
	var speed := current_move_speed()
	player_action = _action("move", travel / speed, normalized)
	player_action["distance"] = travel
	player_action["speed"] = speed
	player_action["move_origin"] = player_pos
	_emit_sound(player_pos, 130.0)
	_set_message("You commit to a step.")
	_streamed_action_cpu_usec = 0
	return true

func advance_streamed_action_tick() -> bool:
	if String(player_action["kind"]) == "idle" or player_hp <= 0: return false
	var tick_start := Time.get_ticks_usec()
	_tick(SIM_DT)
	_streamed_action_cpu_usec += Time.get_ticks_usec() - tick_start
	if String(player_action["kind"]) == "idle" or player_hp <= 0:
		performance_metrics["last_action_ms"] = float(_streamed_action_cpu_usec) / 1000.0
		performance_metrics["simulation_ms"] = performance_metrics["last_action_ms"]
		performance_metrics["snapshot_ms"] = 0.0
		performance_metrics["timeline_frames"] = 0
		_profile_action_count += 1
		changed.emit()
	return true

func request_move_to(target: Vector2, simulate_immediately: bool = true) -> bool:
	var delta := target - player_pos
	return request_move(delta, minf(delta.length(), MOVE_RANGE), simulate_immediately)

func request_attack(target: Vector2, simulate_immediately: bool = true) -> bool:
	if not _can_start_basic_attack(): return false
	if player_weapon_frame == "bow":
		if not begin_bow_draw(target - player_pos, _enemy_id_near_position(target)): return false
		release_bow_attack(target - player_pos)
		if simulate_immediately: _simulate_until_ready()
		return true
	_break_player_combo()
	var direction := target - player_pos
	if direction.length_squared() < 0.01:
		direction = player_facing
	player_facing = direction.normalized()
	var definition := _player_basic_attack_definition(player_facing)
	if not _spend_energy(_basic_attack_energy_cost()): return false
	player_action = _melee_action(float(definition["duration"]), float(definition["startup"]), float(definition["active_end"]), float(definition["reach"]), int(definition["damage_max"]), player_facing, String(definition["technique"]), "attack")
	player_action["damage_min"] = int(definition["damage_min"])
	player_action["damage_max"] = int(definition["damage_max"])
	player_action["posture_damage"] = float(definition["posture"])
	player_action["combo_step"] = int(definition["step"])
	player_action["building_force_registered"] = false
	player_action["building_force_bonus"] = _building_force_bonus()
	_apply_counterstep_to_action(player_action)
	_apply_action_poise(player_action)
	_annotate_player_action("basic_attack_%d" % (int(definition["step"]) + 1))
	_emit_sound(player_pos, 350.0)
	_set_message("You commit to the %s." % AttackGeometryScript.label(String(definition["technique"])).to_lower())
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func player_basic_attack_definition() -> Dictionary:
	return _player_basic_attack_definition(player_facing).duplicate(true)

func player_uses_ranged_basic_attack() -> bool:
	return String(CombatCatalogScript.weapon_frame(player_weapon_frame).get("delivery", "melee")) == "ranged"

func request_skill(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if player_equipped_weapon_art == "prototype_drawing_cut": return request_drawing_cut(direction, simulate_immediately)
	if player_equipped_weapon_art == "prototype_sweeping_cut": return request_sweeping_cut(direction, simulate_immediately)
	if player_equipped_weapon_art == "knife_execution": return request_execution(direction, simulate_immediately)
	if player_equipped_weapon_art == "knife_twin_fang": return request_twin_fang(direction, simulate_immediately)
	if player_equipped_weapon_art == "bow_piercing_shot": return request_bow_art(direction, true, simulate_immediately)
	if player_equipped_weapon_art == "bow_fan_shot": return request_bow_art(direction, false, simulate_immediately)
	if player_equipped_weapon_art in ["staff_whirlwind", "staff_leg_sweep"]: return request_staff_art(direction, simulate_immediately)
	_set_message("No Weapon Art has been learned yet.")
	changed.emit()
	return false

# `held` states whether a qualifying input is genuinely live at commitment. It is
# sampled again at every authored link point, so a sustained hold continues the
# sequence for as long as it lasts while a tap commits exactly one strike. It must
# never be assumed: an action begun from a released input has no continuation.
func request_combo(direction: Vector2, simulate_immediately: bool = true, held: bool = false) -> bool:
	if direction.length_squared() < 0.01 or not _can_start_basic_attack(): return false
	_break_player_combo()
	_reset_building_force()
	_reset_building_force_if_unavailable()
	if player_weapon_frame in ["knife", "twin_knives"]: _begin_knife_combo(direction, held)
	elif player_weapon_frame == "staff": _begin_staff_combo(direction, held)
	elif player_weapon_frame == "bow": return false
	else: _begin_sword_combo(direction, held, false)
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_direct_attack(direction: Vector2, simulate_immediately: bool = true, held: bool = false) -> bool:
	if direction.length_squared() < 0.01: direction = player_facing
	var began := begin_bow_draw(direction) if player_weapon_frame == "bow" else request_combo(direction, false, held)
	if not began: return false
	direct_attack_uses_total += 1
	if simulate_immediately and player_weapon_frame != "bow": _simulate_until_ready()
	return true

func begin_bow_draw(direction: Vector2, soft_target_id: int = -1) -> bool:
	if not is_player_ready() or trial_complete or player_weapon_frame != "bow" or not _can_commit_physical_action(): return false
	if direction.length_squared() < 0.01: direction = player_facing
	player_facing = direction.normalized()
	player_action = _action("bow_draw", 999.0, player_facing)
	player_action.merge({"aim_direction": player_facing, "draw_ratio": 0.0, "shot_spawned": false, "soft_target_id": soft_target_id, "manual_aim": false}, true)
	if bow_followup_ready:
		player_action["elapsed"] = 0.45
		bow_followup_ready = false
		bow_followup_consumed = true
	else:
		bow_followup_consumed = false
	_annotate_player_action("bow_draw")
	_emit_sound(player_pos, 80.0)
	_set_message("You begin drawing the Bow. Release to fire.")
	_streamed_action_cpu_usec = 0
	return true

func set_bow_aim(direction: Vector2) -> void:
	if String(player_action.get("kind", "")) != "bow_draw" or direction.length_squared() < 0.01: return
	var desired := direction.normalized()
	var current := Vector2(player_action.get("aim_direction", player_facing)).normalized()
	var maximum_turn := deg_to_rad(12.0)
	var angle := clampf(current.angle_to(desired), -maximum_turn, maximum_turn)
	var adjusted := current.rotated(angle).normalized()
	player_action["aim_direction"] = adjusted
	player_action["direction"] = adjusted
	player_action["manual_aim"] = true
	player_action["soft_target_id"] = -1
	player_facing = adjusted

func _enemy_id_near_position(position: Vector2, tolerance: float = 80.0) -> int:
	var best_id := -1
	var best_distance := tolerance
	for enemy in _nearby_enemies(position, tolerance + 80.0):
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		var distance := Vector2(enemy["pos"]).distance_to(position)
		if distance <= best_distance:
			best_distance = distance
			best_id = int(enemy["id"])
	return best_id

func _update_bow_soft_aim(dt: float) -> void:
	var target_id := int(player_action.get("soft_target_id", -1))
	if target_id < 0 or bool(player_action.get("manual_aim", false)): return
	var target := _enemy_by_id(target_id)
	if target.is_empty() or not enemy_visible_to_player(target) or not is_visible(Vector2(target["pos"])) or not _has_line_of_sight(player_pos, Vector2(target["pos"])):
		player_action["soft_target_id"] = -1
		return
	var desired := player_pos.direction_to(Vector2(target["pos"]))
	var current := Vector2(player_action.get("aim_direction", player_facing)).normalized()
	var angle := clampf(current.angle_to(desired), -2.4 * dt, 2.4 * dt)
	var adjusted := current.rotated(angle).normalized()
	player_action["aim_direction"] = adjusted
	player_action["direction"] = adjusted
	player_facing = adjusted

func release_bow_attack(direction: Vector2 = Vector2.ZERO) -> bool:
	if String(player_action.get("kind", "")) != "bow_draw": return false
	if direction.length_squared() > 0.01: set_bow_aim(direction)
	var draw_time := float(player_action.get("elapsed", 0.0))
	var ratio := clampf(draw_time / 0.90, 0.0, 1.0)
	if not _spend_energy(lerpf(10.0, 28.0, ratio)):
		player_action = _idle_action()
		return false
	var strength_adjustment := int(player_attributes.get("strength", 4)) - 4
	# A loose arrow is an emergency release, not a fast melee substitute. Full
	# draw supplies the Bow's damage and stopping power; quick kiting shots retain
	# utility without repeatedly arresting every pursuer.
	var loose_damage := (6 if has_track_rank("bow", 2) else 4) + strength_adjustment
	var full_damage := (16 if has_track_rank("bow", 3) else 13) + strength_adjustment
	var loose_range := 300.0 if has_track_rank("bow", 2) else 250.0
	var maximum_range := lerpf(loose_range, 700.0, ratio) * _aimed_projectile_range_multiplier()
	var velocity := lerpf(480.0, 820.0, ratio)
	var damage := roundi(lerpf(float(loose_damage), float(full_damage), ratio))
	var posture := lerpf(0.0, 3.25 if has_track_rank("bow", 3) else 2.5, ratio)
	var recovery := lerpf(0.70, 1.30, ratio)
	if has_track_rank("bow", 4): recovery *= 0.80
	recovery = _shorten_recovery(recovery, 0.06, 0.65)
	var aim := Vector2(player_action.get("aim_direction", player_facing)).normalized()
	player_action = _action("bow_release", recovery, aim)
	player_action.merge({"startup": 0.06, "shot_spawned": false, "projectile_damage": damage, "projectile_posture": posture, "projectile_speed": velocity, "projectile_range": maximum_range, "draw_ratio": ratio, "full_draw": ratio >= 0.995}, true)
	_annotate_player_action("bow_shot")
	_set_message("You release a %s shot." % ("Full" if ratio >= 0.995 else "Drawn" if ratio >= 0.42 else "Loose"))
	return true

func _aimed_projectile_range_multiplier() -> float:
	return 1.15 if has_track_rank("sharpshooter", 2) else 1.0

# Thrust, sweep, overhead spin. The reward for finishing is that the last hit catches
# everything around you rather than that it hits harder -- the staff's growth is in ground
# covered, which is why Flowing Form widens the middle hit at the same duration instead of
# speeding anything up.
func _begin_staff_combo(direction: Vector2, held: bool) -> void:
	player_facing = direction.normalized()
	var reach_bonus := 18.0 if has_track_rank("staff", 2) else 0.0
	var wide_middle := has_track_rank("staff", 3)
	var phases: Array[Dictionary] = [
		{"startup": 0.30, "active_end": 0.44, "end": 0.92, "reach": 150.0 + reach_bonus, "damage_min": _player_physical_damage(5), "damage_max": _player_physical_damage(5), "posture": 1.8, "technique": "staff_thrust", "energy_cost": 14.0},
		{"startup": 1.06, "active_end": 1.26, "end": 1.78, "reach": 138.0 + reach_bonus, "damage_min": _player_physical_damage(4), "damage_max": _player_physical_damage(4), "posture": 2.4, "technique": "staff_spin" if wide_middle else "staff_sweep", "energy_cost": 14.0},
		{"startup": 1.94, "active_end": 2.22, "end": 2.86, "reach": 146.0 + reach_bonus, "damage_min": _player_physical_damage(5), "damage_max": _player_physical_damage(5), "posture": 3.6, "technique": "staff_spin", "energy_cost": 18.0},
	]
	phases = _linked_combo_phases(phases, 0.25)
	if not _spend_energy(float(phases[0]["energy_cost"])): return
	player_action = _action("combo", float(phases[-1]["end"]), player_facing)
	player_action["phases"] = phases
	player_action["combo_length"] = phases.size()
	player_action["combo_instance_id"] = _next_combo_instance_id
	_next_combo_instance_id += 1
	player_action["phase_index"] = -1
	player_action["continue_held"] = held
	player_action["committed_phase"] = 0
	player_action["terminal_recovery_locked"] = false
	player_action["terminal_recovery_recorded"] = false
	player_action["building_force_registered"] = false
	_apply_action_poise(player_action)
	_annotate_player_action("staff_combo")
	_emit_sound(player_pos, 300.0)
	_set_message("The staff comes up. Hold to carry the form through.")

func _begin_knife_combo(direction: Vector2, held: bool) -> void:
	player_facing = direction.normalized()
	var twin := player_weapon_frame == "twin_knives"
	var speed_scale := 0.92 if has_track_rank("knife", 3) else 1.0
	var count := 6 if twin else 4
	var total := 2.65 * speed_scale
	var interval := total / float(count)
	var techniques := ["knife_cut_in", "knife_cut_out", "knife_rising_cut", "knife_falling_cut"]
	var energy_costs := [12.0, 9.0, 9.0, 9.0, 9.0, 12.0] if twin else [14.0, 12.0, 12.0, 16.0]
	var phases: Array[Dictionary] = []
	for index in range(count):
		var phase_start := interval * float(index)
		phases.append({
			"startup": phase_start + interval * (0.18 if twin else 0.16),
			"active_end": phase_start + interval * (0.34 if twin else 0.32),
			"end": phase_start + interval,
			"reach": 72.0 if twin else 74.0,
			"damage_min": _player_physical_damage(1 if twin else 2) + (1 if has_track_rank("knife", 2) else 0),
			"damage_max": _player_physical_damage(1 if twin else 2) + (1 if has_track_rank("knife", 2) else 0),
			"posture": 0.65 if twin else 1.0,
			"technique": techniques[index % techniques.size()],
			"energy_cost": energy_costs[index],
		})
	phases = _linked_combo_phases(phases, 0.20)
	total = float(phases[-1]["end"])
	if not _spend_energy(float(energy_costs[0])): return
	player_action = _action("combo", total, player_facing)
	player_action["phases"] = phases
	player_action["combo_length"] = phases.size()
	player_action["combo_instance_id"] = _next_combo_instance_id
	_next_combo_instance_id += 1
	player_action["phase_index"] = -1
	player_action["continue_held"] = held
	player_action["committed_phase"] = 0
	player_action["terminal_recovery_locked"] = false
	player_action["terminal_recovery_recorded"] = false
	player_action["knife_sequence"] = true
	player_action["knife_contact_chain"] = 0
	player_action["building_force_registered"] = false
	_apply_action_poise(player_action)
	_annotate_player_action("knife_sequence")
	_emit_sound(player_pos, 260.0)
	_set_message("The Knife sequence begins. Hold to continue cutting.")

func request_execution(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or (skill_cooldown > 0.0001 and not uses_energy_rules()) or direction.length_squared() < 0.01 or not _spend_energy(EXECUTION_ENERGY): return false
	player_facing = direction.normalized()
	var execution_damage := _player_physical_damage(8)
	player_action = _melee_action(1.16, 0.34, 0.45, 92.0, execution_damage, player_facing, "knife_falling_cut", "sweep")
	player_action["damage_min"] = execution_damage
	player_action["damage_max"] = execution_damage
	player_action["posture_damage"] = 3.0
	player_action["unaware_bonus_multiplier"] = 1.0
	player_action["move_start"] = 0.06
	player_action["move_end"] = 0.32
	player_action["speed"] = 245.0
	player_action["execution_target_id"] = _execution_target_id(player_facing)
	var execution_target := _enemy_by_id(int(player_action["execution_target_id"]))
	player_action["execution_target_was_unaware"] = not execution_target.is_empty() and String(execution_target.get("awareness", "idle")) != "alerted"
	_apply_action_poise(player_action)
	_annotate_player_action("knife_execution")
	# It was the only player attack in the file that made no sound at all -- every other
	# one emits, from the knife sequence's 260 to the sweep's 470. So a room could be
	# cleared one body at a time with nobody ever reacting: 0.2.44 room 4 ran six
	# executions, four of four kills made alone, zero damage taken, 0.04 mean engagement.
	#
	# Carried on the action and emitted when the blow LANDS. Emitting it at request time
	# announced the approach instead: the victim woke during the 1.16s wind-up and walked
	# out of its own execution.
	player_action["impact_sound"] = 260.0
	_begin_skill_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend() * _skill_cooldown_multiplier)
	_set_message("You commit to Execution.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func _execution_target_id(direction: Vector2) -> int:
	var best_id := -1
	var best_distance := INF
	var facing := direction.normalized()
	for enemy in _nearby_enemies(player_pos, 205.0):
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		var offset := Vector2(enemy["pos"]) - player_pos
		var distance := offset.length()
		if distance <= 0.001 or facing.dot(offset / distance) < cos(deg_to_rad(34.0)): continue
		if distance < best_distance:
			best_distance = distance
			best_id = int(enemy["id"])
	return best_id

func request_twin_fang(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or (skill_cooldown > 0.0001 and not uses_energy_rules()) or direction.length_squared() < 0.01 or not _spend_energy(32.0): return false
	player_facing = direction.normalized()
	player_action = _action("twin_fang", _shorten_recovery(0.68, 0.29), player_facing)
	player_action.merge({"startup": 0.20, "active_end": 0.29, "move_start": 0.05, "move_end": 0.24, "speed": 320.0, "reach": 104.0, "damage_per_blade": 8, "posture_per_blade": 2.0, "contact_done": false}, true)
	_apply_action_poise(player_action)
	_annotate_player_action("knife_twin_fang")
	_begin_skill_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend() * _skill_cooldown_multiplier)
	_emit_sound(player_pos, 300.0)
	_set_message("Twin Fang drives both blades through one opening.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_bow_art(direction: Vector2, piercing: bool, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or (skill_cooldown > 0.0001 and not uses_energy_rules()) or direction.length_squared() < 0.01 or not _spend_energy(38.0 if piercing else 32.0): return false
	player_facing = direction.normalized()
	var art_startup := 0.54 if piercing else 0.28
	var art_duration := _shorten_recovery(1.50 if piercing else 0.90, art_startup, 0.68)
	player_action = _action("bow_art", art_duration, player_facing)
	player_action.merge({"startup": 0.54 if piercing else 0.28, "shot_spawned": false, "piercing": piercing}, true)
	_annotate_player_action("bow_piercing_shot" if piercing else "bow_fan_shot")
	_begin_skill_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend() * _skill_cooldown_multiplier)
	_emit_sound(player_pos, 260.0)
	_set_message("You prepare %s." % ("Piercing Shot" if piercing else "Fan Shot"))
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

# How far a kind can see, shared so the gate below and the awareness update cannot
# drift apart -- the mistake the Shield's guard list already made once.
func _enemy_vision_range(enemy: Dictionary) -> float:
	var profile := CombatCatalogScript.archetype(String(enemy.get("kind", "")))
	var authored := float(Dictionary(profile.get("properties", {})).get("vision_range", SIGHT_RANGE))
	return authored - 14.0 * float(player_attributes.get("stealth", 0))

# Eyes on the player right now: inside the cone (or close enough that facing stops
# mattering) with a clear line.
func _enemy_has_eyes_on_player(enemy: Dictionary) -> bool:
	var enemy_pos := Vector2(enemy["pos"])
	var offset := player_pos - enemy_pos
	var distance := offset.length()
	if offset.length_squared() < 0.001: return true
	# Something mid-swing or mid-shot at the player knows precisely where they are,
	# whatever its facing has drifted to and whatever its notice range says. An Archer
	# sees 620 less 14 per point of stealth -- 522 against a Rogue -- so one could put an
	# arrow into the player from beyond that and still fail the cone test while the shot
	# was in the air. That is the 0.2.44 report: "an archer shot me and I was able to
	# stealth as it was doing it, meaning he was aware of my exact location."
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) not in NON_COMMITTAL_ACTION_KINDS: return true
	var facing := Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
	var within_cone := distance <= 105.0 or (distance <= _enemy_vision_range(enemy) and absf(facing.angle_to(offset.normalized())) <= deg_to_rad(65.0))
	return within_cone and _has_line_of_sight(enemy_pos, player_pos)

# "Looking for me but cannot see me" has to remain a hideable situation -- that is the
# whole shape of the ability. This used to return true for ANY living alerted enemy on
# the layer, with no facing, no distance and no line of sight, so one enemy that had
# lost you across the room locked the hide out for the rest of the fight.
func player_is_noticed() -> bool:
	_refresh_active_enemy_cache()
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy: Dictionary = enemies[index]
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		if String(enemy.get("awareness", "idle")) != "alerted": continue
		if _enemy_has_eyes_on_player(enemy): return true
	return false

func stealth_status() -> String:
	if not loadout_id.begins_with("rogue_"): return "locked"
	if stealth_remaining > 0.0001: return "active"
	if main_ability_cooldown > 0.0001: return "cooldown"
	if not has_track_rank("rogue", 4) and player_is_noticed(): return "noticed"
	return "available"

func request_stealth(simulate_immediately: bool = true) -> bool:
	if not is_player_ready(): return false
	var status := stealth_status()
	if status != "available":
		if status == "noticed": _set_message("An enemy knows where you are. Vanish is required.")
		return false
	player_action = _action("stealth", 0.40, player_facing)
	# The veil lands on commit rather than 0.24s in. It used to fire late, which meant
	# the act of hiding was itself fully visible: an enemy could acquire you during your
	# own vanish, and then track you through it. The entry gate says you may only start
	# hiding when unseen, so the action must not be the thing that gets you seen. The
	# 0.40s of world time is still spent.
	player_action["effect_start"] = 0.0
	player_action["effect_done"] = false
	_annotate_player_action("rogue_stealth")
	_set_message("You begin slipping from notice.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

# Priced under Energy for the first time. Vault, Take Aim and Stealth were the only
# abilities in the file sitting on a cooldown with NO `uses_energy_rules()` waiver and
# no cost -- together 116 energy of ability use against a 100 pool, free, every room.
# 51 raw spends 33.2 and derives the 8.0s cooldown that was previously hand-authored;
# the Acrobat's rank-4 discount moves the cost rather than the cooldown, so one number
# still drives both profiles and the 4.8s falls out unchanged.
const VAULT_ENERGY := 51.0
const TAKE_AIM_ENERGY := 51.0

func request_vault(direction: Vector2, simulate_immediately: bool = true) -> bool:
	var vault_energy := VAULT_ENERGY * (0.6 if has_track_rank("acrobat", 4) else 1.0)
	if not is_player_ready() or (subclass_ability_cooldown > 0.0001 and not uses_energy_rules()) or direction.length_squared() < 0.01 or not _spend_energy(vault_energy): return false
	player_facing = direction.normalized()
	var recovery := 0.10 if has_track_rank("acrobat", 1) else 0.20
	player_action = _action("vault", 0.34 + recovery, player_facing)
	player_action.merge({"speed": 582.0, "move_start": 0.0, "move_end": 0.34, "evade_start": 0.0, "evade_end": 0.34 + (0.06 if has_track_rank("acrobat", 2) else 0.0), "clean_dodge_triggered": false, "vault_crossed_ids": []}, true)
	_annotate_player_action("acrobat_vault")
	_begin_subclass_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend())
	_emit_sound(player_pos, 210.0)
	_set_message("You Vault through the opening.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_take_aim(target_id: int, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or (subclass_ability_cooldown > 0.0001 and not uses_energy_rules()) or not _spend_energy(TAKE_AIM_ENERGY): return false
	var target := _enemy_by_id(target_id)
	if target.is_empty() or not enemy_visible_to_player(target) or not is_visible(Vector2(target["pos"])): return false
	player_facing = player_pos.direction_to(Vector2(target["pos"]))
	player_action = _action("take_aim", 1.35, player_facing)
	player_action.merge({"target_id": target_id, "effect_start": 1.05, "effect_done": false}, true)
	_annotate_player_action("sharpshooter_take_aim")
	_set_message("You study the target.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func _enemy_by_id(enemy_id: int) -> Dictionary:
	for enemy in enemies:
		if int(enemy.get("id", -1)) == enemy_id: return enemy
	return {}

func _actor_id(actor: Variant) -> int:
	return int(Dictionary(actor).get("id", -1)) if actor is Dictionary else int(actor)

func _actor_storage(actor: Variant) -> Dictionary:
	if actor is Dictionary: return Dictionary(actor)
	var actor_id := int(actor)
	return {} if actor_id == 0 else _enemy_by_id(actor_id)

func _faction_of(actor: Variant) -> String:
	var actor_id := _actor_id(actor)
	if actor_id == 0: return "player"
	var storage := _actor_storage(actor)
	return String(storage.get("faction", "enemy")) if not storage.is_empty() else "neutral"

func _opposes(first: Variant, second: Variant) -> bool:
	var first_faction := _faction_of(first)
	var second_faction := _faction_of(second)
	return first_faction != "neutral" and second_faction != "neutral" and first_faction != second_faction

func actor_view(actor: Variant) -> Dictionary:
	var actor_id := _actor_id(actor)
	if actor_id == 0:
		return {"id":0, "kind":"player", "faction":"player", "pos":player_pos, "radius":PLAYER_RADIUS, "hp":player_hp, "posture":player_posture}
	var storage := _actor_storage(actor)
	if storage.is_empty(): return {}
	return {"id":actor_id, "kind":String(storage.get("kind", "")), "faction":_faction_of(storage), "pos":Vector2(storage.get("pos", Vector2.ZERO)), "radius":float(storage.get("radius", ENEMY_RADIUS)), "hp":int(storage.get("hp", 0)), "posture":float(storage.get("posture", 0.0))}

func _change_actor_hp(actor: Variant, delta: int) -> int:
	var actor_id := _actor_id(actor)
	if actor_id == 0:
		var before := player_hp
		player_hp = clampi(player_hp + delta, 0, player_max_hp)
		return player_hp - before
	var storage := _actor_storage(actor)
	if storage.is_empty(): return 0
	var before := int(storage.get("hp", 0))
	storage["hp"] = before + delta
	return int(storage["hp"]) - before

func _apply_actor_condition_buildup(actor: Variant, condition_id: String, amount: float) -> bool:
	return apply_player_condition_buildup(condition_id, amount) if _actor_id(actor) == 0 else apply_enemy_condition_buildup(_actor_storage(actor), condition_id, amount)

func _apply_actor_posture_damage(actor: Variant, amount: float, contact: Vector2 = Vector2.INF) -> bool:
	if _actor_id(actor) == 0:
		player_posture = maxf(0.0, player_posture - amount)
		player_posture_recovery_delay = 1.15
		return player_posture <= 0.0001
	return _apply_posture_damage(_actor_storage(actor), amount, contact)

func _set_actor_impulse(actor: Variant, velocity: Vector2) -> void:
	if _actor_id(actor) == 0: player_gale_velocity = velocity
	else:
		var storage := _actor_storage(actor)
		if not storage.is_empty(): storage["gale_velocity"] = velocity

func _begin_sword_combo(direction: Vector2, held: bool, from_advance: bool) -> void:
	if not _spend_energy(18.0): return
	player_facing = direction.normalized()
	var edge_damage := 1 if has_track_rank("swordsmanship", 3) else 0
	var edge_posture := 0.5 if has_track_rank("swordsmanship", 3) else 0.0
	var flowing := has_track_rank("swordsmanship", 5)
	var duration := 3.08 if flowing else 3.34
	var opener_startup := 0.24 if from_advance and has_track_rank("vanguard", 2) else 0.30
	var opener_posture := 2.3 if from_advance and has_track_rank("vanguard", 2) else 1.8
	var second_damage := 13 if uses_energy_rules() else 10
	var finisher_damage := 17 if uses_energy_rules() else 15
	var second_posture := 2.8 if uses_energy_rules() else 2.2
	var finisher_posture := 4.5 if uses_energy_rules() else 3.8
	var phases: Array[Dictionary] = [
		{"startup": opener_startup, "active_end": 0.52, "end": 0.92 if flowing else 0.98, "reach": 104.0, "damage_min": 10 + edge_damage, "damage_max": 10 + edge_damage, "posture": opener_posture + edge_posture, "technique": "opening_cut", "energy_cost": 18.0},
		{"startup": 0.99 if flowing else 1.08, "active_end": 1.25 if flowing else 1.34, "end": 1.88 if flowing else 2.04, "reach": 116.0, "damage_min": second_damage + edge_damage, "damage_max": second_damage + edge_damage, "posture": second_posture + edge_posture, "technique": "reverse_cut", "energy_cost": 16.0},
		{"startup": 2.18 if flowing else 2.42, "active_end": 2.48 if flowing else 2.72, "end": duration, "reach": 158.0, "damage_min": finisher_damage + edge_damage, "damage_max": finisher_damage + edge_damage, "posture": finisher_posture + edge_posture, "technique": "turning_slash", "energy_cost": 22.0},
	]
	phases = _linked_combo_phases(phases, 0.25)
	duration = float(phases[-1]["end"])
	player_action = _action("combo", duration, player_facing)
	player_action["phases"] = phases
	player_action["combo_length"] = 3
	player_action["combo_instance_id"] = _next_combo_instance_id
	_next_combo_instance_id += 1
	player_action["phase_index"] = -1
	# The first cut starts immediately. A renewed touch may restore the hold before
	# the link point; once terminal recovery starts, the sequence is locked closed.
	player_action["continue_held"] = held
	player_action["committed_phase"] = 0
	player_action["terminal_recovery_locked"] = false
	player_action["terminal_recovery_recorded"] = false
	player_action["building_force_registered"] = false
	player_action["building_force_bonus"] = _building_force_bonus()
	_apply_counterstep_to_combo(player_action)
	_apply_action_poise(player_action)
	_annotate_player_action("sword_combo")
	_emit_sound(player_pos, 470.0)
	_set_message("The opening cut begins. Hold to commit the next strike.")

func set_attack_hold(held: bool) -> void:
	if String(player_action.get("kind", "idle")) != "combo": return
	player_action["continue_held"] = held
	if not held:
		_set_message("Release noted. Finish the current cut, then time freezes.")

func resume_combo_hold() -> bool:
	if String(player_action.get("kind", "idle")) != "combo": return false
	var phases: Array = player_action.get("phases", [])
	var committed_phase := int(player_action.get("committed_phase", 0))
	if committed_phase >= phases.size() - 1: return false
	if bool(player_action.get("terminal_recovery_locked", false)): return false
	var phase: Dictionary = phases[committed_phase]
	var elapsed := float(player_action.get("elapsed", 0.0))
	# Input is intentionally generous: a renewed touch may happen at any point
	# before the link. This is a commitment decision, not a narrow timing test.
	if elapsed >= float(phase.get("link", phase["active_end"])): return false
	player_action["continue_held"] = true
	_set_message("Your grip returns. The sequence continues.")
	return true

# Sweeping Cut is the Sword combo's third strike, available immediately, at the
# combo's full price. It is not a wider, cheaper, faster version of that finisher,
# which is what it had become: a 160-degree arc for 34 Energy in 23% of the
# combo's time, so building the sequence for its own finisher was never correct.
#
# Now it shares the finisher's geometry, damage and posture, costs exactly what
# the whole combo costs, and serves its complete terminal recovery in both rule
# profiles. What you buy is the *time* you skip, and you pay the full price for it.
# It is no longer exempt from ENERGY_COST_SCALE. The exemption held the price at 56
# while everything around it scaled, which meant a global re-tune of the price level
# would move every ability EXCEPT this one -- the real defect, and not one the number
# itself caused. The authored cost is raised to 86 instead, so it still spends ~56 by
# default and now travels with the scale like anything else. Its cooldown falls out of
# that spend at 13.4s, up from a hand-authored 4.2: the finisher without the combo's
# time is a special attack, not a cheaper way to reach the same place.
#
# The original reasoning -- charge the sword combo's full price for skipping the
# combo's time -- assumed 1.9 saved seconds were worth about a combo's Energy.
# They are not, once Energy regenerates at 28/s: 0.2.17 halved the sweep to 28
# and the 0.2.18 survey came back "sweeping is still too easy", with the death
# room played as five sweeps and one combo. Price parity cannot restrain an
# action that refills faster than its advantage decays, so the sweep keeps the
# full 56 while everything around it scales -- roughly one and a half combos.
const SWEEPING_CUT_ENERGY := 86.0
# Doubled from 30. A silent, cheap, high-damage opener with no wind-up was worth
# spamming; noise alone might have restrained it, but the price is the part that makes
# choosing it a decision rather than a default.
const EXECUTION_ENERGY := 60.0

func request_sweeping_cut(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or (skill_cooldown > 0.0001 and not uses_energy_rules()) or direction.length_squared() < 0.01 or not _spend_energy(SWEEPING_CUT_ENERGY):
		return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	var extended := has_track_rank("swordsmanship", 4)
	var flowing := has_track_rank("swordsmanship", 5)
	var edge := has_track_rank("swordsmanship", 3)
	# Deliberately identical to the combo's turning slash, including how the two
	# rule profiles differ, so this reads as that strike arriving early rather than
	# as a separate and better attack.
	var finisher_damage := 17 if uses_energy_rules() else 15
	var finisher_posture := 4.5 if uses_energy_rules() else 3.8
	var full_duration := 1.29 if flowing else 1.42
	player_action = _melee_action(full_duration, 0.44, 0.57, 178.0 if extended else 158.0, finisher_damage, player_facing, "turning_slash", "sweep")
	# `_melee_action` shortens recovery for "sweep" under Energy rules, which is
	# right for Knife Execution and Drawing Cut but not here: physical commitment is
	# shared across profiles and only the resource model differs. Restore the full
	# authored recovery so the terminal window is actually visible.
	player_action["duration"] = full_duration
	player_action["posture_damage"] = finisher_posture + (0.5 if edge else 0.0)
	player_action["damage_min"] = finisher_damage + (1 if edge else 0)
	player_action["damage_max"] = int(player_action["damage_min"])
	_apply_action_poise(player_action)
	_annotate_player_action(player_equipped_weapon_art if player_equipped_weapon_art != "" else "prototype_sweeping_cut")
	# No attack cooldown under Energy: commitment, recovery and cost govern it, as
	# they govern every other physical attack. Recovery rules keep their own
	# budgeting, which is the modes' actual difference. Matches Drawing Cut.
	_begin_skill_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend() * _skill_cooldown_multiplier)
	_emit_sound(player_pos, 470.0)
	_set_message("You commit to a broad, posture-breaking cut.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

# 0.2.62 authored both of these in the catalog and implemented neither, so choosing one
# armed a button that did nothing and left time frozen -- the worst possible failure in a
# game where time only moves when you commit, because nothing tells you the commitment did
# not happen.
#
# Whirlwind buys SPACE and Sweep the Legs buys TIME. They are priced apart to match: the
# circle costs about half again what the sweep does, because shoving a crowd off you is
# worth more than taking one body off its feet.
const WHIRLWIND_ENERGY := 62.0
const LEG_SWEEP_ENERGY := 40.0
const WHIRLWIND_PUSH := 104.0

func request_staff_art(direction: Vector2, simulate_immediately: bool = true) -> bool:
	var whirlwind := player_equipped_weapon_art == "staff_whirlwind"
	var cost := WHIRLWIND_ENERGY if whirlwind else LEG_SWEEP_ENERGY
	if not is_player_ready() or trial_complete or direction.length_squared() < 0.01: return false
	if skill_cooldown > 0.0001 and not uses_energy_rules(): return false
	if not _spend_energy(cost): return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	var mastered := has_track_rank("staff", 4)
	var reach_bonus := 18.0 if has_track_rank("staff", 2) else 0.0
	if whirlwind:
		# Slow, because it is the answer to being surrounded and an instant answer to that
		# would remove the mistake that produced it.
		player_action = _melee_action(1.62, 0.58, 0.82, 168.0 + reach_bonus, 9, player_facing, "staff_whirlwind", "sweep")
		player_action["duration"] = 1.62
		player_action["posture_damage"] = 3.0
		player_action["staff_push"] = WHIRLWIND_PUSH * (1.45 if mastered else 1.0)
		player_action["staff_knockdown"] = mastered
		_set_message("You sweep the staff in a full circle.")
	else:
		# Long and low. Almost no damage; what it does is take one body off its feet, and
		# the reach is what lets you do it before they arrive.
		# 98 degrees was a broad sweep wearing a different name -- the same shape as the
		# Whirlwind it is supposed to contrast with. Narrow and long is the whole idea: it
		# reaches past anything else the player owns and catches one line of bodies.
		player_action = _melee_action(1.24, 0.42, 0.60, 268.0 + reach_bonus, 5, player_facing, "staff_leg_sweep", "sweep")
		player_action["duration"] = 1.24
		player_action["posture_damage"] = 11.0 if mastered else 8.5
		_set_message("You take their legs out from under them.")
	player_action["damage_min"] = int(player_action["damage"])
	player_action["damage_max"] = int(player_action["damage"])
	_apply_action_poise(player_action)
	_annotate_player_action(player_equipped_weapon_art)
	_begin_skill_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend() * _skill_cooldown_multiplier)
	_emit_sound(player_pos, 440.0)
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_drawing_cut(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or (skill_cooldown > 0.0001 and not uses_energy_rules()) or direction.length_squared() < 0.01 or not _spend_energy(32.0):
		return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	var extended := has_track_rank("swordsmanship", 4)
	var flowing := has_track_rank("swordsmanship", 5)
	var edge := has_track_rank("swordsmanship", 3)
	player_action = _melee_action(1.15 if flowing else 1.25, 0.29, 0.40, 196.0 if extended else 176.0, 20, player_facing, "driving_cut", "sweep")
	player_action["posture_damage"] = 3.0 + (0.5 if edge else 0.0)
	player_action["damage_min"] = 20 + (1 if edge else 0)
	player_action["damage_max"] = int(player_action["damage_min"])
	_apply_action_poise(player_action)
	_annotate_player_action("prototype_drawing_cut")
	_begin_skill_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend() * _skill_cooldown_multiplier)
	_emit_sound(player_pos, 410.0)
	_set_message("You draw through a narrow opening in one committed cut.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func knows_spell(spell_id: String) -> bool:
	return player_spells.has(spell_id)

func spell_label(spell_id: String) -> String:
	return String(AbilityCatalogScript.spell(spell_id).get("label", spell_id.capitalize()))

func spell_is_available() -> bool:
	return is_player_ready() and not player_spells.is_empty() and spell_cooldown <= 0.0001 and not energy_actions_locked()

func select_spell(spell_id: String) -> bool:
	if not knows_spell(spell_id): return false
	selected_spell = spell_id
	return true

# Casting roots you. That positional cost is what makes "casting competes with dodging"
# true, so Walking Cast frees the recovery and never the wind-up: you still commit in
# place, you just do not have to serve the whole bill standing there.
func _spell_action(spell_id: String, direction: Vector2, wind_up: float, total: float) -> Dictionary:
	var pace := 0.88 if has_track_rank("mage", 2) else 1.0
	var action := _action("cast", total * pace, direction)
	action["startup"] = wind_up * pace
	action["spell_id"] = spell_id
	action["effect_done"] = false
	action["mobile_recovery"] = has_track_rank("mage", 4)
	return action

func request_spell(spell_id: String, target: Vector2, simulate_immediately: bool = true) -> bool:
	if not spell_is_available() or not knows_spell(spell_id): return false
	var offset := target - player_pos
	var direction := offset.normalized() if offset.length_squared() > 0.01 else player_facing
	if not _spend_energy(spell_energy_cost(spell_id), false): return false
	selected_spell = spell_id
	player_facing = direction
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		survey_spell_counts[spell_id] = int(survey_spell_counts.get(spell_id, 0)) + 1
	var spell_definition := AbilityCatalogScript.spell(spell_id)
	player_action = _spell_action(spell_id, direction, float(spell_definition["player_startup"]), float(spell_definition["player_duration"]))
	player_action["target"] = target
	_begin_spell_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend())
	_annotate_player_action("spell")
	_break_stealth_for_hostile_action()
	_set_message("You cast %s." % spell_label(spell_id))
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func _begin_spell_cooldown(seconds: float) -> void:
	begin_cooldown(COOLDOWN_SPELL, seconds)

# The player's spells are the enemies' spells. Every one of these reuses the spawner the
# enemy version already calls, with the player standing in as the source, which is what
# keeps "the spellbook is the bestiary" true in the code and not only in the design.
func _resolve_player_spell(spell_id: String, target: Vector2, direction: Vector2) -> void:
	var caster := {"id": 0, "pos": player_pos, "layer": current_layer, "kind": "player"}
	var definition := AbilityCatalogScript.spell(spell_id)
	match String(definition["resolver"]):
		"lightning_bolt": _resolve_lightning_bolt(direction)
		"projectile": _spawn_spell_projectile(caster, String(definition["projectile"]), direction)
		"hazard":
			match String(definition["hazard"]):
				"fire_breath": _spawn_fire_breath(caster, direction)
				"cold_front": _spawn_cold_front(caster, target)
				"sundered_ground": _spawn_sundered_ground(target, 0, current_layer)
				"gale": _spawn_gale(caster, target)
		"barrier": _raise_player_earth_wall(target)
		"movement": pass

func _resolve_lightning_bolt(direction: Vector2) -> void:
	# An instant line to the first thing in it. Not a travelling projectile and not a cone,
	# so it shares geometry with neither Fire ability -- and it cannot be dodged in flight,
	# because there is no flight. It is the caster's jab: reliable, cheap, unimpressive.
	var best: Dictionary = {}
	var best_distance := LIGHTNING_RANGE
	for enemy in _nearby_enemies(player_pos, LIGHTNING_RANGE + 80.0):
		if int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
		var offset := Vector2(enemy["pos"]) - player_pos
		var along := offset.dot(direction)
		if along <= 0.0 or along > best_distance: continue
		if absf(offset.cross(direction)) > float(enemy.get("radius", ENEMY_RADIUS)) + 16.0: continue
		if not _has_line_of_sight(player_pos, Vector2(enemy["pos"])): continue
		best = enemy
		best_distance = along
	var strike_point := player_pos + direction * minf(best_distance, LIGHTNING_RANGE)
	if not best.is_empty(): strike_point = Vector2(best["pos"])
	_add_effect("lightning", strike_point, 0, {"origin": player_pos + direction * 26.0})
	if best.is_empty():
		_set_message("The bolt earths itself on nothing.")
		return
	var contact := Vector2(best["pos"])
	var awareness_before := String(best.get("awareness", "idle"))
	var action_before: Dictionary = Dictionary(best.get("action", {})).duplicate(true)
	var source_action := {"kind": "cast", "ability_id": "lightning_bolt", "duration": 0.35, "elapsed": 0.0, "allow_hit_reaction": true}
	var resolved := _resolve_player_physical_values(best, LIGHTNING_DAMAGE, 1.2, source_action)
	var damage := int(resolved["damage"])
	best["hp"] = int(best["hp"]) - damage
	damage_dealt += damage
	_on_player_hit_landed(best)
	var posture_broken := _apply_actor_posture_damage(best, float(resolved["posture"]), contact)
	if not posture_broken:
		_apply_enemy_hit_reaction(best, float(resolved["posture"]), awareness_before, action_before, contact, source_action)
	_register_enemy_hit_awareness(best, resolved, source_action)
	_add_effect("hit", contact, damage, {"direction": (contact - player_pos).normalized()})
	_handle_player_contact_aftermath(best, resolved)
	_set_message("The bolt earths itself in the %s." % String(best["kind"]))

func _raise_player_earth_wall(target: Vector2) -> void:
	# Placed where the player asked rather than across their retreat. Same rule, opposite
	# value: an enemy caster puts it behind you to cut the way out, and you put it toward
	# the threat to gate them -- and because a barrier never blocks enemies, what it
	# actually gates is their archers and everything else that gets thrown.
	var heading := (target - player_pos)
	if heading.length_squared() < 0.001: heading = player_facing
	heading = heading.normalized()
	var axis := heading.rotated(PI * 0.5)
	var segment_span := EARTH_WALL_SPAN / float(EARTH_WALL_SEGMENTS)
	for index in range(EARTH_WALL_SEGMENTS):
		var offset := (float(index) - float(EARTH_WALL_SEGMENTS - 1) * 0.5) * segment_span
		_add_barrier({
			"pos": target + axis * offset, "axis": axis, "half_length": segment_span * 0.5,
			"thickness": EARTH_WALL_THICKNESS, "hp": EARTH_WALL_SEGMENT_HP,
			"remaining": EARTH_WALL_PLAYER_DURATION, "lowered": false, "source_id": 0, "layer": current_layer,
		})
	survey_barriers_raised += 1
	for index in range(EARTH_WALL_SEGMENTS):
		var mark := (float(index) - float(EARTH_WALL_SEGMENTS - 1) * 0.5) * segment_span
		_add_effect("earth_wall", target + axis * mark)

func request_circle(simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or loadout_id != "mage_elementalist": return false
	if main_ability_cooldown > 0.0001 or energy_actions_locked(): return false
	if not _spend_energy(CIRCLE_ENERGY, true): return false
	var wind_up := CIRCLE_WIND_UP * (0.5 if track_choice("circle_mastery") == "swift_circle" else 1.0)
	player_action = _action("circle", wind_up + 0.42, player_facing)
	player_action["startup"] = wind_up
	player_action["effect_done"] = false
	_begin_main_ability_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend())
	_annotate_player_action("circle")
	_set_message("You draw a circle underfoot.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_dodge(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or (dodge_cooldown > 0.0001 and not uses_energy_rules()) or direction.length_squared() < 0.01:
		return false
	# Exhaustion locks every physical action except this one. Milestone B's floor --
	# a hit must always leave one executable response -- outranks the lockout, so
	# the Dodge stays reachable and pays in debt instead of Energy.
	var desperate := uses_energy_rules() and not _can_commit_physical_action()
	# Rolling smothers fire. Checked before the energy gate so a winded player still has
	# the one answer to burning that exhaustion cannot take away.
	if float(player_conditions.get("burning", 0.0)) > 0.0:
		player_conditions["burning"] = maxf(0.0, float(player_conditions["burning"]) - BURN_DODGE_RELIEF)
		if float(player_conditions["burning"]) <= 0.0: player_conditions.erase("burning")
		player_condition_buildup["burning"] = 0.0
	if not desperate and not _spend_energy(DODGE_ENERGY_COST):
		return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	var style := track_choice("evasion_style")
	var duration := 0.60 if has_track_rank("evasion", 1) else 0.66
	var move_start := 0.08
	var move_end := 0.38
	var evade_start := 0.08
	var evade_end := 0.38
	var speed := DODGE_SPEED
	var cooldown := 3.6 if has_track_rank("evasion", 1) else DODGE_COOLDOWN
	if uses_energy_rules():
		# Energy Dodge has no long cooldown. Every learned form strictly improves
		# the modest but dependable basic Dodge, then specializes either recovery
		# or protected displacement without hiding a higher Energy cost.
		if style == "sidestep":
			duration = 0.47
			move_start = 0.05
			move_end = 0.29
			evade_start = 0.05
			evade_end = 0.35
			speed = 700.0
		elif style == "long_roll":
			duration = 0.60
			move_start = 0.05
			move_end = 0.40
			evade_start = 0.05
			evade_end = 0.40
			speed = 660.0
		elif has_track_rank("evasion", 1):
			duration = 0.56
			move_start = 0.06
			move_end = 0.36
			evade_start = 0.06
			evade_end = 0.36
			speed = 560.0
		else:
			duration = 0.56
			move_start = 0.08
			move_end = 0.32
			evade_start = 0.08
			evade_end = 0.32
			speed = 625.0
	else:
		# Recovery remains the untouched comparison profile.
		if style == "sidestep":
			duration = 0.48
			move_start = 0.06
			move_end = 0.30
			evade_start = 0.06
			evade_end = 0.36
			speed = 700.0
			cooldown = 2.8
		elif style == "long_roll":
			duration = 0.58
			move_start = 0.05
			move_end = 0.40
			evade_start = move_start
			evade_end = move_end
			speed = 660.0
			cooldown = 3.6
	if desperate:
		# 90 units of travel over 0.20s, i-frames covering 0.16s of it, and the
		# remaining 0.51s spent exposed. It clears one envelope, never a second.
		duration = EXHAUSTED_DODGE_DURATION
		move_start = 0.08
		move_end = 0.28
		evade_start = 0.08
		evade_end = 0.24
		speed = EXHAUSTED_DODGE_SPEED
	player_action = _action("dodge", duration, player_facing)
	var reported_style := "desperate" if desperate else style if not style.is_empty() else "practised" if has_track_rank("evasion", 1) else "basic"
	player_action.merge({"speed": speed, "move_start": move_start, "move_end": move_end, "evade_start": evade_start, "evade_end": evade_end, "vulnerable_recovery_start": evade_end, "dodge_style": reported_style, "clean_dodge_triggered": false}, true)
	dodge_style_uses_total[reported_style] = int(dodge_style_uses_total.get(reported_style, 0)) + 1
	_annotate_player_action("defense_dodge")
	dodge_cooldown = 0.0 if uses_energy_rules() else cooldown
	_emit_sound(player_pos, 270.0)
	if desperate:
		# Flat debt: the bar empties and the clock restarts at the same duration
		# every time. Chaining is already self-limiting -- at 117 u/s only the
		# dodged attack misses, so a chain resolves in damage rather than stalling.
		player_energy = 0.0
		player_overexertion_pending = false
		player_energy_regen_delay = 0.0
		player_exhaustion_remaining = EXHAUSTION_DURATION
		exhausted_dodge_total += 1
		exhausted_dodge_chain += 1
		exhausted_dodge_max_chain = maxi(exhausted_dodge_max_chain, exhausted_dodge_chain)
		exhausted_dodge_room_max_chain = maxi(exhausted_dodge_room_max_chain, exhausted_dodge_chain)
		_set_message("You throw yourself clear on nothing but nerve. Your breath is gone again.")
	else:
		_set_message("You commit to a dodge.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_rally(simulate_immediately: bool = true) -> bool:
	if not rally_is_available(): return false
	_break_player_combo()
	_reset_building_force()
	player_action = _action("rally", 0.56, player_facing)
	player_action["effect_start"] = 0.18
	player_action["rally_started"] = false
	_annotate_player_action("warrior_rally")
	_set_message("You gather yourself for Rally.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func rally_is_available() -> bool:
	return is_player_ready() and not trial_complete and rally_cooldown <= 0.0001 and rally_remaining <= 0.0001

func request_advance(direction: Vector2, continue_held: bool = false, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or (advance_cooldown > 0.0001 and not uses_energy_rules()) or direction.length_squared() < 0.01 or not _spend_energy(28.0): return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	var posture := 6.0 if has_track_rank("vanguard", 1) else 4.0
	var push := 40.0 if has_track_rank("vanguard", 1) else 32.0
	var damage := 15 if has_track_rank("vanguard", 1) else 10
	player_action = _action("advance", _shorten_recovery(0.92, 0.52), player_facing)
	player_action.merge({
		"move_start": 0.08, "move_end": 0.42, "impact_start": 0.36, "impact_end": 0.52,
		"speed": 424.0, "damage_min": damage, "damage_max": damage, "posture_damage": posture, "push": push,
		"continue_held": continue_held, "impact_ids": [], "pass_mass": -1.0, "max_targets": 1,
	}, true)
	_apply_action_poise(player_action, 4.0)
	_begin_advance_cooldown(0.0 if uses_energy_rules() else _cooldown_for_last_spend())
	_annotate_player_action("vanguard_advance")
	_emit_sound(player_pos, 420.0)
	_set_message("You commit to Advance.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func set_advance_hold(held: bool) -> void:
	if String(player_action.get("kind", "")) == "advance":
		player_action["continue_held"] = held

func request_block(direction: Vector2, simulate_immediately: bool = false) -> bool:
	if not is_player_ready() or trial_complete or direction.length_squared() < 0.01:
		return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	player_action = _action("block", 999.0, player_facing)
	player_action["startup"] = 0.16
	player_action["active_end"] = 999.0
	player_action["guard_held"] = true
	_annotate_player_action("defense_block")
	_set_message("Your directional guard remains raised while held.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_endure(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or endure_cooldown > 0.0001:
		return false
	_break_player_combo()
	_reset_building_force()
	if direction.length_squared() > 0.01:
		player_facing = direction.normalized()
	player_action = _action("endure", 1.05, player_facing)
	player_action["startup"] = 0.14
	player_action["active_end"] = 0.72
	_annotate_player_action("defense_endure")
	endure_cooldown = ENDURE_COOLDOWN * _defense_cooldown_multiplier
	_set_message("You brace to turn pain into strength.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_defense(direction: Vector2, simulate_immediately: bool = true) -> bool:
	match defense_id:
		"block": return request_block(direction, simulate_immediately)
		"endure": return request_endure(direction, simulate_immediately)
		_: return request_dodge(direction, simulate_immediately)

func request_potion(simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or (potions <= 0 and not has_infinite_potions()) or player_hp >= player_max_hp:
		return false
	_break_player_combo()
	_reset_building_force()
	if not has_infinite_potions(): potions -= 1
	potions_used_total += 1
	player_action = _action("potion", maxf(0.48, 0.72 - 0.06 * float(track_property_ranks.get("fieldcraft_recovery", 0))), Vector2.ZERO)
	_annotate_player_action("rejuvenation_potion")
	_emit_sound(player_pos, 90.0)
	_set_message("You draw from the rejuvenation pouch.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func has_infinite_potions() -> bool:
	return bool(mode_config.get("infinite_potions_for_testing", false))

func healing_capacity() -> int:
	return HEALING_CAPACITY + int(track_property_ranks.get("fieldcraft_capacity", 0))

func _empty_consumable_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index in range(CONSUMABLE_SLOT_COUNT): result.append({"id": "", "count": 0})
	return result

func consumable_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= consumable_slots.size(): return {}
	return Dictionary(consumable_slots[slot])

func consumable_definition(item_id: String) -> Dictionary:
	return Dictionary(CONSUMABLES.get(item_id, {}))

func consumable_requires_direction(slot: int) -> bool:
	return bool(consumable_definition(String(consumable_slot(slot).get("id", ""))).get("targeted", false))

func request_consumable(slot: int, direction: Vector2 = Vector2.ZERO, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete: return false
	var stored := consumable_slot(slot)
	var item_id := String(stored.get("id", ""))
	if item_id.is_empty() or int(stored.get("count", 0)) <= 0: return false
	var definition := consumable_definition(item_id)
	if bool(definition.get("targeted", false)) and direction.length_squared() < 0.01: return false
	_break_player_combo()
	_reset_building_force()
	stored["count"] = int(stored["count"]) - 1
	if int(stored["count"]) <= 0:
		stored["id"] = ""
		stored["count"] = 0
	consumable_slots[slot] = stored
	var facing := direction.normalized() if direction.length_squared() > 0.01 else player_facing
	player_facing = facing
	player_action = _action("consumable", 0.78 if item_id == "firebomb" else 0.58, facing)
	player_action["item_id"] = item_id
	player_action["slot"] = slot
	player_action["startup"] = 0.24 if item_id != "firebomb" else 0.34
	_annotate_player_action("consumable_%s" % item_id)
	_emit_sound(player_pos, 115.0 if item_id == "firebomb" else 72.0)
	_set_message("You ready the %s." % String(definition.get("label", item_id)).to_lower())
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_repack(first_slot: int, second_slot: int, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or first_slot < 0 or second_slot < 0 or first_slot >= consumable_slots.size() or second_slot >= consumable_slots.size() or first_slot == second_slot: return false
	var first := consumable_slot(first_slot)
	_reset_building_force()
	consumable_slots[first_slot] = consumable_slot(second_slot)
	consumable_slots[second_slot] = first
	player_action = _action("repack", 0.32, Vector2.ZERO)
	_set_message("You repack the belt.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func nearby_pickup() -> Dictionary:
	for pickup_value in world_pickups:
		var pickup: Dictionary = pickup_value
		if String(pickup.get("layer", current_layer)) == current_layer and player_pos.distance_to(Vector2(pickup["pos"])) <= 112.0: return pickup
	return {}

func has_pending_pickup() -> bool:
	return not pending_pickup.is_empty()

func request_collect_nearby_pickup(simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or has_pending_pickup(): return false
	var pickup := nearby_pickup()
	if pickup.is_empty(): return false
	var item_id := String(pickup.get("item_id", ""))
	if item_id == "rejuvenation":
		if potions >= healing_capacity():
			_set_message("The rejuvenation pouch is already full.")
			changed.emit()
			return false
		potions = mini(healing_capacity(), potions + int(pickup.get("count", 1)))
		_remove_pickup(String(pickup["id"]))
		return _begin_repack_action("You add a rejuvenation draught to the pouch.", simulate_immediately)
	var amount := int(pickup.get("count", 1))
	for slot_index in range(consumable_slots.size()):
		var stored := consumable_slot(slot_index)
		if String(stored.get("id", "")) != item_id: continue
		var maximum := int(consumable_definition(item_id).get("max_stack", 1))
		if int(stored.get("count", 0)) >= maximum: continue
		stored["count"] = mini(maximum, int(stored["count"]) + amount)
		consumable_slots[slot_index] = stored
		_remove_pickup(String(pickup["id"]))
		return _begin_repack_action("You stow the %s." % String(consumable_definition(item_id).get("label", item_id)).to_lower(), simulate_immediately)
	for slot_index in range(consumable_slots.size()):
		if not String(consumable_slot(slot_index).get("id", "")).is_empty(): continue
		consumable_slots[slot_index] = {"id": item_id, "count": mini(amount, int(consumable_definition(item_id).get("max_stack", 1)))}
		_remove_pickup(String(pickup["id"]))
		return _begin_repack_action("You stow the %s." % String(consumable_definition(item_id).get("label", item_id)).to_lower(), simulate_immediately)
	pending_pickup = pickup.duplicate(true)
	_set_message("Belt full. Tap a belt slot to replace it, or wait to leave it.")
	changed.emit()
	return false

func replace_pending_pickup(slot: int, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or pending_pickup.is_empty() or slot < 0 or slot >= consumable_slots.size(): return false
	var item_id := String(pending_pickup.get("item_id", ""))
	if item_id.is_empty(): return false
	var displaced := consumable_slot(slot)
	consumable_slots[slot] = {"id": item_id, "count": mini(int(pending_pickup.get("count", 1)), int(consumable_definition(item_id).get("max_stack", 1)))}
	_remove_pickup(String(pending_pickup["id"]))
	pending_pickup.clear()
	if not String(displaced.get("id", "")).is_empty() and int(displaced.get("count", 0)) > 0:
		_drop_belt_item(displaced)
	var incoming_label := String(consumable_definition(item_id).get("label", item_id)).to_lower()
	var displaced_label := String(consumable_definition(String(displaced.get("id", ""))).get("label", "belt item")).to_lower()
	return _begin_repack_action("You trade %s for %s." % [displaced_label, incoming_label], simulate_immediately)

func leave_pending_pickup() -> bool:
	if pending_pickup.is_empty(): return false
	pending_pickup.clear()
	_set_message("You leave the item where it lies.")
	changed.emit()
	return true

func _remove_pickup(pickup_id: String) -> void:
	world_pickups = world_pickups.filter(func(value: Dictionary) -> bool: return String(value.get("id", "")) != pickup_id)

func _drop_belt_item(stored: Dictionary) -> void:
	# A full-belt replacement is a physical exchange, not silent destruction.
	# The entire displaced stack remains at the player's feet for a later choice.
	var serial := 0
	var pickup_id := "discard_%d_%d" % [roundi(simulation_time * 120.0), serial]
	while world_pickups.any(func(value: Dictionary) -> bool: return String(value.get("id", "")) == pickup_id):
		serial += 1
		pickup_id = "discard_%d_%d" % [roundi(simulation_time * 120.0), serial]
	_add_pickup({
		"id": pickup_id,
		"item_id": String(stored["id"]),
		"count": int(stored["count"]),
		"pos": player_pos,
		"layer": current_layer,
		"area_id": current_area_id,
	})

func _begin_repack_action(text: String, simulate_immediately: bool) -> bool:
	_reset_building_force()
	player_action = _action("repack", 0.32, Vector2.ZERO)
	_set_message(text)
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

# One unit of waiting is exactly one movement step. Derived rather than fixed, so
# waiting in place is never coarser than pacing in place: at a hardcoded 0.5s a
# player who wanted to spend a little time was better off walking back and forth,
# which made the action built for spending time the worst way to spend it. It also
# survives retuning -- if combat movement speed is revisited, a step lengthens and
# Wait tracks it automatically instead of silently drifting finer.
func wait_unit_duration() -> float:
	# One movement step's worth of world time. It tracks the *current* walk speed,
	# so waiting while exhausted is as coarse as stepping while exhausted and the
	# two never disagree about what "a beat" costs.
	return MOVE_RANGE / maxf(1.0, current_move_speed())

func request_wait(duration: float = -1.0, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete:
		return false
	if interaction_label() != "WAIT": return request_context_action()
	_break_player_combo()
	_reset_building_force()
	if duration < 0.0: duration = wait_unit_duration()
	# The clamp floor sits below any real loadout's step so the derivation, not the
	# clamp, decides the value.
	player_action = _action("wait", clampf(duration, 0.05, 1.0), Vector2.ZERO)
	_set_message("You deliberately surrender time.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func interaction_label() -> String:
	if not run_active or death_pending: return "WAIT"
	if bool(mode_config["waystone_available"]) and not nearby_waystone().is_empty(): return "REST"
	if not nearby_pickup().is_empty(): return "TAKE"
	var shortcut := _nearby_locked_shortcut()
	if not shortcut.is_empty(): return "CLEAR" if String(shortcut.get("presentation", "")) == "hidden_woodland_path" else "UNLOCK"
	if not _nearby_transition().is_empty(): return "TRAVERSE"
	return "WAIT"

func request_context_action() -> bool:
	if not is_player_ready(): return false
	match interaction_label():
		"REST": return activate_waystone()
		"TAKE": return request_collect_nearby_pickup()
		"UNLOCK", "CLEAR": return unlock_shortcut()
		"TRAVERSE": return use_transition()
		_: return request_wait()

func can_learn_at_waystone() -> bool:
	return level_up_context() == "waystone"

func level_up_context() -> String:
	if not is_player_ready() or trial_complete: return ""
	if mode_id == ModeRulesScript.EXPEDITION:
		return "expedition" if carried_xp >= next_upgrade_cost() else ""
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		return "survey" if carried_xp >= next_upgrade_cost() else ""
	if mode_id == ModeRulesScript.CAMPAIGN_LAB and not nearby_waystone().is_empty() and secured_xp >= next_upgrade_cost():
		return "waystone"
	return ""

func can_open_level_sheet() -> bool:
	return not level_up_context().is_empty() and not available_level_up_options().is_empty()

func activate_waystone() -> bool:
	var stone := nearby_waystone()
	if not bool(mode_config["waystone_available"]) or stone.is_empty() or not is_player_ready(): return false
	active_waystone_id = String(stone["id"])
	bonfire_pos = Vector2(stone["pos"])
	current_layer = String(stone.get("layer", current_layer))
	_restore_at_waystone()
	_respawn_enemies()
	_update_exploration(true)
	var xp_gained := provisional_xp()
	var memories_gained := unanchored_discovery_count()
	var shortcut_gained := unanchored_shortcut()
	secured_xp = carried_xp
	_capture_anchor_history()
	last_anchor_report = {"xp": xp_gained, "memories": memories_gained, "shortcut": shortcut_gained, "restored": true}
	_add_effect("anchor", bonfire_pos, xp_gained)
	var parts: Array[String] = ["health and Energy restored", "enemies revived"]
	if xp_gained > 0: parts.append("%d XP integrated" % xp_gained)
	if memories_gained > 0: parts.append("%d map traces anchored" % memories_gained)
	if shortcut_gained: parts.append("shortcut remembered")
	_set_message("Waystone: %s." % ", ".join(parts))
	changed.emit()
	return true

func learn_at_waystone() -> bool:
	if level_up_context() != "waystone": return false
	_set_message("The Waystone holds still. Choose what the Warrior retains.")
	changed.emit()
	return true

func unlock_shortcut() -> bool:
	var target := _nearby_locked_shortcut()
	if not bool(mode_config["waystone_available"]) or target.is_empty() or not is_player_ready(): return false
	target["unlocked"] = true
	shortcut_unlocked = shortcuts.any(func(item: Dictionary) -> bool: return bool(item.get("unlocked", false)))
	_apply_shortcut_world_state()
	_update_exploration(true)
	_set_message("You clear a hidden path through the woods." if String(target.get("presentation", "")) == "hidden_woodland_path" else "The sealed way opens into a remembered path.")
	changed.emit()
	return true

func nearby_waystone() -> Dictionary:
	for stone in waystones:
		if String(stone.get("layer", current_layer)) == current_layer and player_pos.distance_to(Vector2(stone["pos"])) <= WAYSTONE_RANGE: return stone
	return {}

func _nearby_locked_shortcut() -> Dictionary:
	if not bool(mode_config.get("waystone_available", false)): return {}
	for shortcut in shortcuts:
		var interaction_radius := float(shortcut.get("interaction_radius", 115.0))
		if not bool(shortcut.get("unlocked", false)) and String(shortcut.get("layer", current_layer)) == current_layer and player_pos.distance_to(Vector2(shortcut["unlock_pos"])) <= interaction_radius: return shortcut
	return {}

func _nearby_transition() -> Dictionary:
	for transition in transitions:
		if not bool(transition.get("unlocked", true)): continue
		if String(transition["from_layer"]) == current_layer and player_pos.distance_to(Vector2(transition["from_pos"])) <= 120.0:
			return {"transition": transition, "reverse": false}
		if String(transition["to_layer"]) == current_layer and player_pos.distance_to(Vector2(transition["to_pos"])) <= 120.0:
			return {"transition": transition, "reverse": true}
	return {}

func use_transition() -> bool:
	if not is_player_ready(): return false
	var nearby := _nearby_transition()
	if nearby.is_empty(): return false
	var transition: Dictionary = nearby["transition"]
	var reverse := bool(nearby["reverse"])
	_store_current_layer_discovery()
	current_layer = String(transition["from_layer"] if reverse else transition["to_layer"])
	_load_current_layer_discovery()
	player_pos = Vector2(transition["from_pos"] if reverse else transition["to_pos"])
	current_area_id = _area_id_at_position(player_pos, current_layer)
	player_facing = Vector2.UP
	projectiles.clear()
	hazards.clear()
	_visibility_anchor = Vector2.INF
	_visibility_anchor_cell = Vector2i(-999999, -999999)
	_apply_shortcut_world_state()
	_update_exploration(true)
	_set_message("You return to the forest above." if current_layer == "forest_surface" else "You descend beneath the ruined forest.")
	changed.emit()
	return true

func return_after_death() -> bool:
	if not death_pending: return false
	if String(mode_config["death_policy"]) == "end_run":
		death_pending = false
		run_failed = true
		run_active = false
		player_action = _idle_action()
		last_timeline.clear()
		message = "The expedition has ended."
		changed.emit()
		return true
	death_pending = false
	_restore_at_waystone()
	_restore_anchor_history()
	player_pos = bonfire_pos + Vector2.DOWN * 170.0
	player_facing = (bonfire_pos - player_pos).normalized()
	_respawn_enemies()
	_update_exploration(true)
	_set_message("You reform at the Waystone. Reclaim your lost XP.")
	changed.emit()
	return true

func _capture_anchor_history() -> void:
	_store_current_layer_discovery()
	var discovered_areas: Array[bool] = []
	for area in areas: discovered_areas.append(bool(area.get("discovered", false)))
	var shortcut_states: Dictionary = {}
	for shortcut in shortcuts: shortcut_states[String(shortcut["id"])] = bool(shortcut.get("unlocked", false))
	anchor_state = {
		"shortcut_unlocked": shortcut_unlocked,
		"shortcut_states": shortcut_states,
		"discovered_cells": discovered_cells.duplicate(),
		"discovered_cells_by_layer": discovered_cells_by_layer.duplicate(true),
		"discovered_areas": discovered_areas,
		"active_waystone_id": active_waystone_id,
		"bonfire_pos": bonfire_pos,
		"current_layer": current_layer,
	}

func _restore_anchor_history() -> void:
	if anchor_state.is_empty(): return
	shortcut_unlocked = bool(anchor_state.get("shortcut_unlocked", false))
	var shortcut_states: Dictionary = anchor_state.get("shortcut_states", {})
	for shortcut in shortcuts: shortcut["unlocked"] = bool(shortcut_states.get(String(shortcut["id"]), false))
	active_waystone_id = String(anchor_state.get("active_waystone_id", active_waystone_id))
	bonfire_pos = Vector2(anchor_state.get("bonfire_pos", bonfire_pos))
	current_layer = String(anchor_state.get("current_layer", current_layer))
	current_area_id = _area_id_at_position(bonfire_pos, current_layer)
	_apply_shortcut_world_state()
	discovered_cells_by_layer = Dictionary(anchor_state.get("discovered_cells_by_layer", {})).duplicate(true)
	if discovered_cells_by_layer.is_empty(): discovered_cells_by_layer[current_layer] = Dictionary(anchor_state.get("discovered_cells", {})).duplicate()
	_load_current_layer_discovery()
	var discovered_areas: Array = anchor_state.get("discovered_areas", [])
	for index in range(areas.size()):
		areas[index]["discovered"] = bool(discovered_areas[index]) if index < discovered_areas.size() else index == 0
	visible_cells.clear()
	_visibility_anchor = Vector2.INF
	_visibility_anchor_cell = Vector2i(-999999, -999999)

func _apply_shortcut_world_state() -> void:
	_refresh_loaded_region_content()
	walls.assign(base_walls)
	if bool(mode_config["waystone_available"]):
		for shortcut in shortcuts:
			if not bool(shortcut.get("unlocked", false)): walls.append(Rect2(shortcut["gate"]))
	for connection in connections:
		if bool(connection.get("shortcut", false)):
			var unlocked := false
			for shortcut in shortcuts:
				if String(shortcut["id"]) == String(connection.get("shortcut_id", "")): unlocked = bool(shortcut.get("unlocked", false))
			connection["unlocked"] = unlocked
	shortcut_unlocked = shortcuts.any(func(item: Dictionary) -> bool: return bool(item.get("unlocked", false))) if not shortcuts.is_empty() else shortcut_unlocked
	_build_wall_spatial_index()
	_build_navigation()
	world_render_revision += 1

func _refresh_loaded_region_content() -> void:
	var desired: Dictionary = {}
	if mode_id == ModeRulesScript.EXPEDITION:
		if current_area_id >= 0: desired[current_area_id] = true
		for edge_value in Array(run_graph.get("edges", [])):
			var edge := Dictionary(edge_value)
			var from_id := int(edge.get("from", -1))
			var to_id := int(edge.get("to", -1))
			if from_id == current_area_id and to_id >= 0: desired[to_id] = true
			if to_id == current_area_id and from_id >= 0: desired[from_id] = true
		if desired.size() <= 1:
			for area_id in range(maxi(0, current_area_id - 1), mini(areas.size(), current_area_id + 2)):
				desired[area_id] = true
	else:
		if current_area_id >= 0: desired[current_area_id] = true
		for connection in connections:
			if String(connection.get("layer", current_layer)) != current_layer: continue
			var from_id := int(connection.get("from", -1))
			var to_id := int(connection.get("to", -1))
			if from_id == current_area_id and to_id >= 0: desired[to_id] = true
			if to_id == current_area_id and from_id >= 0: desired[from_id] = true
		for area in areas:
			if String(area.get("layer", current_layer)) == current_layer and Vector2(area["center"]).distance_to(player_pos) <= 1900.0:
				desired[int(area["id"])] = true
	if desired.is_empty() and current_area_id >= 0: desired[current_area_id] = true
	loaded_region_ids = desired
	_loaded_floor_shapes.clear()
	for shape in floor_shapes:
		if String(shape.get("layer", current_layer)) == current_layer and desired.has(int(shape.get("part_id", -1))):
			_loaded_floor_shapes.append(shape)
	loaded_terrain_features.clear()
	base_walls.clear()
	for feature in terrain_features:
		if String(feature.get("layer", current_layer)) != current_layer or not desired.has(int(feature.get("part_id", -1))): continue
		if bool(feature.get("secret_gate", false)) and _secret_is_revealed(String(feature.get("secret_id", ""))): continue
		loaded_terrain_features.append(feature)
		if bool(feature.get("blocks", String(feature.get("kind", "")) == "tree")):
			var radius := float(feature.get("radius", 40.0))
			base_walls.append(Rect2(Vector2(feature["pos"]) - Vector2.ONE * radius * 0.42, Vector2.ONE * radius * 0.84))
	_build_terrain_feature_spatial_index()
	if geometry_style != "organic": base_walls.assign(Array(base_walls_by_layer.get(current_layer, [])))
	performance_metrics["loaded_regions"] = loaded_region_ids.size()
	_invalidate_active_enemy_cache()

func _secret_is_revealed(secret_id: String) -> bool:
	for secret in secret_passages:
		if String(secret.get("id", "")) == secret_id:
			return bool(secret.get("revealed", false))
	return false

func _update_secret_passages() -> bool:
	for index in range(secret_passages.size()):
		var secret: Dictionary = secret_passages[index]
		if bool(secret.get("revealed", false)) or String(secret.get("layer", current_layer)) != current_layer: continue
		var distance := player_pos.distance_to(Vector2(secret.get("reveal_pos", secret.get("gate_pos", Vector2.ZERO))))
		var awareness_reveal := int(player_attributes.get("awareness", 5)) >= int(secret.get("concealment", 7)) and distance <= float(secret.get("awareness_radius", 240.0))
		var manual_reveal := distance <= float(secret.get("manual_radius", 58.0))
		if not awareness_reveal and not manual_reveal: continue
		secret["revealed"] = true
		secret_passages[index] = secret
		var reward := Dictionary(secret.get("reward", {})).duplicate(true)
		if not reward.is_empty() and not world_pickups.any(func(value: Dictionary) -> bool: return String(value.get("id", "")) == String(reward.get("id", ""))):
			_add_pickup(reward)
		_add_effect("discover", Vector2(secret.get("gate_pos", player_pos)))
		_set_message("Your Awareness reveals a concealed passage through the thicket." if awareness_reveal else "Up close, the brush gives way to a concealed passage.")
		_apply_shortcut_world_state()
		return true
	return false

func _build_shape_spatial_index() -> void:
	_shape_buckets_by_layer.clear()
	for shape in floor_shapes:
		var layer := String(shape.get("layer", current_layer))
		if not _shape_buckets_by_layer.has(layer): _shape_buckets_by_layer[layer] = {}
		var buckets: Dictionary = _shape_buckets_by_layer[layer]
		var bounds := _shape_bounds(shape)
		for cell in _spatial_cells_for_rect(bounds):
			if not buckets.has(cell): buckets[cell] = []
			buckets[cell].append(shape)

func _build_wall_spatial_index() -> void:
	_wall_buckets.clear()
	_visibility_opaque_cells.clear()
	for wall in walls:
		for cell in _spatial_cells_for_rect(Rect2(wall).grow(40.0)):
			if not _wall_buckets.has(cell): _wall_buckets[cell] = []
			_wall_buckets[cell].append(wall)
		var wall_rect := Rect2(wall)
		var inset := minf(5.0, minf(wall_rect.size.x, wall_rect.size.y) * 0.18)
		var occluder := wall_rect.grow(-inset)
		var first := _visibility_cell(occluder.position)
		var last := _visibility_cell(occluder.end - Vector2.ONE * 0.001)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				_visibility_opaque_cells[Vector2i(x, y)] = true

func _build_terrain_feature_spatial_index() -> void:
	_terrain_feature_buckets.clear()
	for feature in loaded_terrain_features:
		var radius := float(feature.get("radius", 45.0))
		var bounds := Rect2(Vector2(feature["pos"]) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		if feature.has("from") and feature.has("to"):
			var start := Vector2(feature["from"])
			var finish := Vector2(feature["to"])
			var half_width := float(feature.get("width", 24.0)) * 0.5 + 70.0
			bounds = Rect2(start.min(finish) - Vector2.ONE * half_width, finish.max(start) - start.min(finish) + Vector2.ONE * half_width * 2.0)
		for cell in _spatial_cells_for_rect(bounds):
			if not _terrain_feature_buckets.has(cell): _terrain_feature_buckets[cell] = []
			_terrain_feature_buckets[cell].append(feature)

func nearby_terrain_features(position: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for cell in _spatial_cells_for_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		for feature in Array(_terrain_feature_buckets.get(cell, [])):
			var key := "%s:%s:%s" % [feature.get("part_id", -1), feature.get("kind", ""), feature.get("pos", Vector2.ZERO)]
			if seen.has(key): continue
			seen[key] = true
			result.append(feature)
	return result

func nearby_render_walls(position: Vector2, radius: float) -> Array[Rect2]:
	return _nearby_walls(position, radius)

func _invalidate_active_enemy_cache() -> void:
	_active_enemy_cache_dirty = true
	_enemy_spatial_cache_dirty = true

func _add_enemy_actor(enemy: Dictionary) -> void:
	enemies.append(enemy)
	_invalidate_active_enemy_cache()

func _replace_enemy_actors(values: Array) -> void:
	enemies.assign(values)
	_invalidate_active_enemy_cache()

func _set_enemy_position(enemy: Dictionary, position: Vector2) -> void:
	enemy["pos"] = position
	_update_enemy_bucket_membership(enemy)

func _append_presented(collection: Array, value: Dictionary) -> Dictionary:
	if not value.has("presentation_id"):
		value["presentation_id"] = _next_presentation_id
		_next_presentation_id += 1
	collection.append(value)
	return value

func _add_projectile(value: Dictionary) -> Dictionary:
	# Faction collision is an authored projectile property, not an inferred renderer
	# fallback. Ordinary shots begin loyal to their source side; Gale is what changes
	# that contract after launch.
	if not value.has("misdirected"): value["misdirected"] = false
	return _append_presented(projectiles, RuntimeSchemaScript.construct("projectile", value))

func _add_hazard(value: Dictionary) -> Dictionary:
	return _append_presented(hazards, RuntimeSchemaScript.construct("hazard", value))

func _add_barrier(value: Dictionary) -> Dictionary:
	return _append_presented(barriers, RuntimeSchemaScript.construct("barrier", value))

func _add_effect_entity(value: Dictionary) -> Dictionary:
	return _append_presented(effects, RuntimeSchemaScript.construct("effect", value))

func _add_pickup(value: Dictionary) -> Dictionary:
	return _append_presented(world_pickups, RuntimeSchemaScript.construct("pickup", value))

func _normalize_presentation_ids() -> void:
	_next_presentation_id = 1
	for collection in [projectiles, hazards, effects, world_pickups, barriers]:
		for value in collection:
			var item := Dictionary(value)
			if not item.has("presentation_id"):
				item["presentation_id"] = _next_presentation_id
			_next_presentation_id = maxi(_next_presentation_id, int(item["presentation_id"]) + 1)

func _refresh_active_enemy_cache() -> void:
	if not _active_enemy_cache_dirty: return
	_streamed_enemy_indices.clear()
	for index in range(enemies.size()):
		if _enemy_is_streamed(enemies[index]): _streamed_enemy_indices.append(index)
	_active_enemy_cache_dirty = false

func _build_enemy_spatial_index() -> void:
	if not _enemy_spatial_cache_dirty: return
	_enemy_buckets.clear()
	_enemy_bucket_cell_by_id.clear()
	_refresh_active_enemy_cache()
	var active_count := 0
	for index in _streamed_enemy_indices:
		var enemy: Dictionary = enemies[index]
		var cell := _spatial_cell_for_point(Vector2(enemy["pos"]))
		if not _enemy_buckets.has(cell): _enemy_buckets[cell] = []
		_enemy_buckets[cell].append(enemy)
		_enemy_bucket_cell_by_id[int(enemy["id"])] = cell
		active_count += 1
	performance_metrics["active_enemies"] = active_count
	performance_metrics["resident_enemies"] = enemies.size()
	_enemy_spatial_cache_dirty = false

func _update_enemy_bucket_membership(enemy: Dictionary) -> void:
	var enemy_id := int(enemy["id"])
	var next_cell := _spatial_cell_for_point(Vector2(enemy["pos"]))
	var previous_cell := Vector2i(_enemy_bucket_cell_by_id.get(enemy_id, next_cell))
	if previous_cell == next_cell: return
	var previous_bucket: Array = _enemy_buckets.get(previous_cell, [])
	for index in range(previous_bucket.size() - 1, -1, -1):
		if int(Dictionary(previous_bucket[index]).get("id", -1)) == enemy_id: previous_bucket.remove_at(index)
	if not _enemy_buckets.has(next_cell): _enemy_buckets[next_cell] = []
	_enemy_buckets[next_cell].append(enemy)
	_enemy_bucket_cell_by_id[enemy_id] = next_cell

func _shape_bounds(shape: Dictionary) -> Rect2:
	var radius := float(shape.get("radius", 0.0))
	if String(shape.get("kind", "circle")) == "circle":
		return Rect2(Vector2(shape["center"]) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	var start := Vector2(shape["from"])
	var finish := Vector2(shape["to"])
	return Rect2(start.min(finish) - Vector2.ONE * radius, (start.max(finish) - start.min(finish)) + Vector2.ONE * radius * 2.0)

func _spatial_cell_for_point(point: Vector2) -> Vector2i:
	return Vector2i(int(floor(point.x / SPATIAL_CELL)), int(floor(point.y / SPATIAL_CELL)))

func _spatial_cells_for_rect(rect: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start := _spatial_cell_for_point(rect.position)
	var finish := _spatial_cell_for_point(rect.end)
	for x in range(start.x, finish.x + 1):
		for y in range(start.y, finish.y + 1): result.append(Vector2i(x, y))
	return result

func _nearby_walls(position: Vector2, radius: float) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if _wall_buckets.is_empty():
		for wall in walls: result.append(Rect2(wall))
		return result
	var seen: Dictionary = {}
	for cell in _spatial_cells_for_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		for wall in Array(_wall_buckets.get(cell, [])):
			var wall_rect := Rect2(wall)
			if not seen.has(wall_rect):
				seen[wall_rect] = true
				result.append(wall_rect)
	return result

func _nearby_enemies(position: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _enemy_buckets.is_empty():
		for enemy in enemies:
			if int(enemy.get("hp", 0)) > 0 and Vector2(enemy["pos"]).distance_to(position) <= radius: result.append(enemy)
		return result
	var seen: Dictionary = {}
	for cell in _spatial_cells_for_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		for enemy in Array(_enemy_buckets.get(cell, [])):
			var enemy_id := int(enemy["id"])
			if not seen.has(enemy_id):
				seen[enemy_id] = true
				result.append(enemy)
	return result

func _enemy_is_streamed(enemy: Dictionary) -> bool:
	# Loaded regions preserve terrain and enemy state, but they are much larger
	# than the active combat neighbourhood. Simulating every resident in the
	# previous, current, and next locale made crossing a region boundary wake
	# several offscreen encounter groups at once.
	return int(enemy.get("hp", 0)) > 0 \
		and String(enemy.get("layer", current_layer)) == current_layer \
		and Vector2(enemy["pos"]).distance_to(player_pos) <= ACTIVE_ENEMY_RADIUS

func _store_current_layer_discovery() -> void:
	discovered_cells_by_layer[current_layer] = discovered_cells

func _load_current_layer_discovery() -> void:
	discovered_cells = Dictionary(discovered_cells_by_layer.get(current_layer, {})).duplicate()
	discovered_cells_by_layer[current_layer] = discovered_cells
	discovery_revision += 1
	discovery_epoch += 1
	discovery_log.clear()
	_visibility_anchor_cell = Vector2i(-999999, -999999)

func _restore_at_waystone() -> void:
	player_hp = player_max_hp
	player_energy = player_max_energy
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_energy_regen_delay = 0.0
	potions = healing_capacity()
	dodge_cooldown = 0.0
	block_cooldown = 0.0
	endure_cooldown = 0.0
	skill_cooldown = 0.0
	rally_cooldown = 0.0
	advance_cooldown = 0.0
	main_ability_cooldown = 0.0
	subclass_ability_cooldown = 0.0
	stealth_remaining = 0.0
	stealth_cooldown_pending = false
	stealth_energy_paid = 0.0
	_stealth_last_ended_at = -1.0
	_formation_use_counts.clear()
	_last_energy_spend = 0.0
	skill_cooldown_max = 6.5
	advance_cooldown_max = 6.0
	main_ability_cooldown_max = 12.0
	subclass_ability_cooldown_max = 8.0
	assassination_window_remaining = 0.0
	turnabout_remaining = 0.0
	player_hit_protection_remaining = 0.0
	aimed_enemy_id = -1
	aimed_remaining = 0.0
	player_condition_buildup.clear()
	player_conditions.clear()
	barriers.clear()
	circle_remaining = 0.0
	player_gale_velocity = Vector2.ZERO
	spell_cooldown = 0.0
	_player_burn_debt = 0.0
	rally_remaining = 0.0
	rally_end_after_action = false
	rally_break_extension_used = false
	building_force_chain = 0
	player_posture = player_posture_max
	player_posture_recovery_delay = 0.0
	counterstep_remaining = 0.0
	strength_remaining = 0.0
	player_action = _idle_action()
	projectiles.clear()
	hazards.clear()
	effects.clear()

func choose_upgrade(choice: String) -> bool:
	var context := level_up_context()
	var parts := choice.split("|", false, 1)
	var track_id := String(parts[0])
	var choice_id := String(parts[1]) if parts.size() > 1 else ""
	if context.is_empty() or not available_level_up_options().has(track_id): return false
	var stage := next_track_stage(track_id)
	if stage.is_empty(): return false
	var choices: Array = stage.get("choices", [])
	if not choices.is_empty():
		var valid_choice := false
		for option_value in choices:
			if String(Dictionary(option_value).get("id", "")) == choice_id:
				valid_choice = true
				break
		if not valid_choice: return false
	elif not choice_id.is_empty():
		return false
	var cost := next_upgrade_cost()
	if context == "waystone" and secured_xp < cost: return false
	if context != "waystone" and carried_xp < cost: return false
	carried_xp = maxi(0, carried_xp - cost)
	if context == "waystone": secured_xp = maxi(0, secured_xp - cost)
	var stage_id := String(stage["id"])
	if not choice_id.is_empty(): track_choices[stage_id] = choice_id
	track_ranks[track_id] = int(track_ranks.get(track_id, 0)) + 1
	_apply_character_stage(stage_id, choice_id)
	upgrades.append("%s:%s%s" % [track_id, stage_id, ":%s" % choice_id if not choice_id.is_empty() else ""])
	upgrade_count += 1
	upgrade_ranks[track_id] = int(track_ranks[track_id])
	upgrade_pending = false
	upgrade_choices.clear()
	upgrade_context = ""
	_set_message("Upgrade gained: %s." % String(stage.get("label", track_id.capitalize())))
	changed.emit()
	return true

func set_block_hold(held: bool) -> void:
	if String(player_action.get("kind", "")) != "block": return
	player_action["guard_held"] = held
	if not held:
		player_action["duration"] = float(player_action.get("elapsed", 0.0)) + 0.10
		player_action["active_end"] = float(player_action.get("elapsed", 0.0))

func set_block_direction(direction: Vector2) -> void:
	if String(player_action.get("kind", "")) != "block" or direction.length_squared() < 0.01: return
	var desired := direction.normalized()
	var maximum_turn := deg_to_rad(4.0 + 1.25 * float(player_attributes.get("speed", 5)))
	var angle := clampf(player_facing.angle_to(desired), -maximum_turn, maximum_turn)
	player_facing = player_facing.rotated(angle).normalized()
	player_action["direction"] = player_facing

func leave_upgrade_menu() -> bool:
	if not upgrade_pending or upgrade_context != "waystone": return false
	upgrade_pending = false
	upgrade_choices.clear()
	upgrade_context = ""
	_set_message("You leave the XP unspent.")
	changed.emit()
	return true

func next_upgrade_cost() -> int:
	return 4 * (character_level() + 1) - 2

# What reaching a level costs from scratch. The k-th upgrade costs 4k + 2 by the curve
# above, so N upgrades cost 2N^2 + 4N -- kept beside next_upgrade_cost() rather than in
# the picker, because the two must not drift. Level 1 is a fresh character, so the target
# level buys `level - 1` upgrades.
static func xp_for_character_level(level: int) -> int:
	var upgrades := maxi(0, level - 1)
	return 2 * upgrades * upgrades + 4 * upgrades

func upgrade_name(id: String) -> String:
	var track := CombatCatalogScript.character_track(id)
	var stage := next_track_stage(id)
	return "%s · %s" % [String(track.get("label", "Track")), String(stage.get("label", "Complete"))]

func upgrade_description(id: String) -> String:
	return String(next_track_stage(id).get("description", ""))

func _roll_upgrade_choices(context: String = "area_exit") -> void:
	var pool := available_level_up_options(context)
	if pool.is_empty(): return
	# Compatibility only: saves created on the old three-choice screen are
	# normalized on load, and live play now selects directly from the Sheet.
	upgrade_choices.assign(pool.slice(0, mini(3, pool.size())))
	upgrade_pending = false
	upgrade_context = ""

func available_level_up_options(context: String = "") -> Array[String]:
	if context.is_empty(): context = level_up_context()
	if context.is_empty(): return []
	var pool: Array[String] = []
	var target_level := character_level() + 1
	for track_value in character_track_order():
		var track_id := String(track_value)
		if track_id == "adopted": continue
		var stage := next_track_stage(track_id)
		if not stage.is_empty() and int(stage.get("gate", 999)) <= target_level: pool.append(track_id)
	return pool

func track_total(track_id: String) -> int:
	return int(track_ranks.get(track_id, 0))

func next_track_stage(track_id: String) -> Dictionary:
	return CombatCatalogScript.character_stage(track_id, int(track_ranks.get(track_id, 0)))

func _apply_character_stage(stage_id: String, choice_id: String) -> void:
	if ELEMENT_STAGE_SPELLS.has(stage_id):
		# One element per rank, and the fork is permanent. Both halves exist as enemy
		# abilities whichever you pick, so the one you refused is still something the room
		# can do to you.
		if not player_spells.has(choice_id): player_spells.append(choice_id)
		if selected_spell == "": selected_spell = choice_id
		_set_message("You have learned %s." % spell_label(choice_id))
		return
	match stage_id:
		"staff_art":
			player_weapon_art_library = [choice_id]
			player_equipped_weapon_art = choice_id
		"measured_1", "measured_2", "measured_3", "measured_4":
			if choice_id == "temperance":
				player_attributes["intelligence"] = int(player_attributes.get("intelligence", 5)) + 1
				_increase_max_health(12)
			else:
				_increase_max_energy(14.0)
				player_attributes["resolve"] = int(player_attributes.get("resolve", 3)) + 1
				_refresh_player_posture_capacity(true)
		"learned":
			player_attributes["intelligence"] = int(player_attributes.get("intelligence", 5)) + 3
		"sword_art":
			player_weapon_art_library = [choice_id]
			player_equipped_weapon_art = choice_id
		"steadfast_1", "steadfast_2", "steadfast_3", "steadfast_4":
			if choice_id == "toughness":
				_increase_max_health(15)
				player_attributes["resolve"] = int(player_attributes.get("resolve", 7)) + 1
				_refresh_player_posture_capacity(false)
			elif choice_id == "vigilance":
				_increase_max_energy(10.0)
				player_attributes["awareness"] = int(player_attributes.get("awareness", 5)) + 1
		"warriors_physique":
			_increase_max_health(20)
			player_attributes["speed"] = int(player_attributes.get("speed", 5)) + 1
		"vanguard_bearing":
			player_attributes["resolve"] = int(player_attributes.get("resolve", 7)) + 2
			_refresh_player_posture_capacity(false)
		"knife_art":
			player_weapon_art_library = [choice_id]
			player_equipped_weapon_art = choice_id
			if choice_id == "knife_twin_fang":
				player_weapon_frame = "twin_knives"
				equipment_slots["main_hand"] = "Twin Knives"
		"bow_art":
			player_weapon_art_library = [choice_id]
			player_equipped_weapon_art = choice_id
		"finesse_1", "finesse_2", "finesse_3", "finesse_4":
			if choice_id == "fleetness":
				player_attributes["speed"] = int(player_attributes.get("speed", 7)) + 1
				_increase_max_energy(10.0)
			elif choice_id == "subtlety":
				player_attributes["stealth"] = int(player_attributes.get("stealth", 7)) + 1
				_increase_max_health(5)
		"patient_1", "patient_2", "patient_3", "patient_4":
			if choice_id == "observation":
				player_attributes["awareness"] = int(player_attributes.get("awareness", 8)) + 1
				_increase_max_energy(10.0)
			elif choice_id == "composure":
				player_attributes["resolve"] = int(player_attributes.get("resolve", 4)) + 1
				_refresh_player_posture_capacity(false)
				_increase_max_health(5)
		"rogue_training":
			if choice_id == "shadow_training":
				player_attributes["speed"] = int(player_attributes.get("speed", 6)) + 1
				player_attributes["stealth"] = int(player_attributes.get("stealth", 7)) + 2
			elif choice_id == "fleet_training":
				player_attributes["speed"] = int(player_attributes.get("speed", 6)) + 2
		"keen_eye":
			player_attributes["awareness"] = int(player_attributes.get("awareness", 8)) + 2
		"far_sight":
			player_properties["vision_range"] = float(player_properties.get("vision_range", SIGHT_RANGE)) * 1.25
			_visibility_anchor_cell = Vector2i(-999999, -999999)

func _increase_max_health(amount: int) -> void:
	player_max_hp += amount
	player_hp += amount
	player_attributes["health"] = player_max_hp

func can_swap_weapon_art() -> bool:
	return false

func equip_weapon_art(art_id: String) -> bool:
	if not can_swap_weapon_art() or not player_weapon_art_library.has(art_id): return false
	player_equipped_weapon_art = art_id
	_set_message("Equipped Sword Art: %s." % String(CombatCatalogScript.weapon_art(art_id).get("label", art_id)))
	changed.emit()
	return true

func character_sheet_data() -> Dictionary:
	var tracks: Array[Dictionary] = []
	for track_value in character_track_order():
		var track_id := String(track_value)
		var definition := CombatCatalogScript.character_track(track_id)
		var rank := int(track_ranks.get(track_id, 0))
		var stages: Array[Dictionary] = []
		for stage_index in range(Array(definition.get("stages", [])).size()):
			var stage := CombatCatalogScript.character_stage(track_id, stage_index)
			stage["completed"] = stage_index < rank
			stage["current"] = stage_index == rank
			stage["choice"] = String(track_choices.get(String(stage["id"]), ""))
			stages.append(stage)
		tracks.append({"id": track_id, "label": definition["label"], "description": definition["description"], "rank": rank, "stages": stages, "next_stage": next_track_stage(track_id)})
	var sheet_attributes := player_attributes.duplicate(true)
	sheet_attributes["health"] = player_max_hp
	sheet_attributes["energy"] = roundi(player_max_energy)
	return {
		"name": CombatCatalogScript.loadout_name(loadout_id),
		"attributes": sheet_attributes,
		"current_energy": player_energy,
		"maximum_energy": player_max_energy,
		"equipment": equipment_slots.duplicate(true),
		"healing_charges": potions,
		"healing_capacity": healing_capacity(),
		"consumable_slots": consumable_slots.duplicate(true),
		"tracks": tracks,
		"weapon_frame": player_weapon_frame,
		"defense": defense_id,
		"known_arts": player_weapon_art_library.duplicate(),
		"equipped_art": player_equipped_weapon_art,
		"upgrade_count": upgrade_count,
		"character_level": character_level(),
		"level_up_context": level_up_context(),
		"level_up_options": available_level_up_options(),
		"level_up_cost": next_upgrade_cost(),
		"level_up_xp": secured_xp if mode_id == ModeRulesScript.CAMPAIGN_LAB else carried_xp,
	}

func _action(kind: String, duration: float, direction: Vector2) -> Dictionary:
	var result := _idle_action()
	result["kind"] = kind
	result["duration"] = duration
	result["direction"] = direction
	result["started_at"] = simulation_time
	return result

func _annotate_player_action(ability_id: String) -> void:
	player_action["actor_kind"] = "player"
	player_action["weapon_frame"] = player_weapon_frame
	player_action["ability_id"] = ability_id
	player_action["defense_id"] = defense_id
	if mode_id == ModeRulesScript.COMBAT_SURVEY and ability_id != "bow_draw":
		survey_action_counts[ability_id] = int(survey_action_counts.get(ability_id, 0)) + 1

func _rally_action_capacity() -> float:
	if rally_remaining <= 0.0: return 0.0
	if has_track_rank("warrior", 5): return 7.0
	return 5.0 if has_track_rank("warrior", 3) else 4.0

func _apply_action_poise(action: Dictionary, native_capacity: float = 0.0) -> void:
	var capacity := maxf(native_capacity, _rally_action_capacity())
	if has_track_rank("vanguard", 3) and String(action.get("kind", "")) in ["attack", "combo", "sweep", "advance"]:
		capacity = maxf(capacity, 3.0)
	if capacity > 0.0:
		capacity += floorf(float(player_attributes.get("resolve", 7)) / 4.0)
	action["guard_capacity"] = capacity
	action["guard_remaining"] = capacity

func _apply_counterstep_to_action(action: Dictionary) -> void:
	if counterstep_remaining <= 0.0: return
	action["startup"] = float(action.get("startup", 0.30)) * 0.80
	action["posture_damage"] = float(action.get("posture_damage", 0.0)) + 1.0
	counterstep_remaining = 0.0

func _apply_counterstep_to_combo(action: Dictionary) -> void:
	if counterstep_remaining <= 0.0: return
	var phases: Array = action.get("phases", [])
	if not phases.is_empty():
		var opener := Dictionary(phases[0])
		opener["startup"] = float(opener["startup"]) * 0.80
		opener["posture"] = float(opener["posture"]) + 1.0
		phases[0] = opener
		action["phases"] = phases
	counterstep_remaining = 0.0

func _rally_damage_bonus() -> int:
	return 1 if rally_remaining > 0.0 and has_track_rank("warrior", 3) else 0

func _rally_posture_bonus() -> float:
	if rally_remaining <= 0.0: return 0.0
	return 2.0 if has_track_rank("warrior", 3) else 1.0

func _building_force_bonus() -> int:
	if not has_track_rank("warrior", 2): return 0
	if rally_remaining > 0.0 and has_track_rank("warrior", 5): return 2
	return clampi(building_force_chain, 0, 2)

func _reset_building_force() -> void:
	building_force_chain = 0

func _reset_building_force_if_unavailable() -> void:
	if not has_track_rank("warrior", 2): building_force_chain = 0

func _register_building_force_hit() -> void:
	if not has_track_rank("warrior", 2): return
	if rally_remaining > 0.0 and has_track_rank("warrior", 5):
		building_force_chain = 2
	elif building_force_chain >= 2:
		building_force_chain = 0
	else:
		building_force_chain += 1

func _finish_rally(begin_cooldown: bool = true) -> void:
	rally_remaining = 0.0
	rally_end_after_action = false
	rally_break_extension_used = false
	building_force_chain = 0
	if begin_cooldown:
		rally_cooldown = 12.0

func _simulate_until_ready() -> void:
	var profile_start := Time.get_ticks_usec()
	var snapshot_usec := 0
	last_timeline.clear()
	var snapshot_start := Time.get_ticks_usec()
	last_timeline.append(snapshot(true))
	snapshot_usec += Time.get_ticks_usec() - snapshot_start
	var frame_accumulator := 0.0
	var guard := 0
	while String(player_action["kind"]) != "idle" and player_hp > 0 and guard < 1000:
		_tick(SIM_DT)
		frame_accumulator += SIM_DT
		if frame_accumulator + 0.00001 >= FRAME_DT:
			snapshot_start = Time.get_ticks_usec()
			last_timeline.append(snapshot(true))
			snapshot_usec += Time.get_ticks_usec() - snapshot_start
			frame_accumulator = 0.0
		guard += 1
	if last_timeline.is_empty() or float(last_timeline[-1]["time"]) != simulation_time:
		snapshot_start = Time.get_ticks_usec()
		last_timeline.append(snapshot(true))
		snapshot_usec += Time.get_ticks_usec() - snapshot_start
	var total_usec := Time.get_ticks_usec() - profile_start
	performance_metrics["last_action_ms"] = float(total_usec) / 1000.0
	performance_metrics["snapshot_ms"] = float(snapshot_usec) / 1000.0
	performance_metrics["simulation_ms"] = float(total_usec - snapshot_usec) / 1000.0
	performance_metrics["timeline_frames"] = last_timeline.size()
	_profile_action_count += 1
	if OS.is_debug_build() and _profile_action_count % 20 == 0:
		print("WAYSTONE PERF action=%.2fms frames=%d active=%d resident=%d regions=%d save=%.2fms" % [float(performance_metrics["last_action_ms"]), int(performance_metrics["timeline_frames"]), int(performance_metrics["active_enemies"]), int(performance_metrics["resident_enemies"]), int(performance_metrics["loaded_regions"]), float(performance_metrics["last_save_ms"])])
	changed.emit()

func _tick(dt: float) -> void:
	_simulation_tick_index += 1
	simulation_time += dt
	if mode_id == ModeRulesScript.COMBAT_SURVEY: _sample_engagement()
	_player_reaction_completed_this_tick = false
	var player_dt := dt * _player_personal_tempo()
	for slot in cooldowns:
		_set_cooldown_remaining(String(slot), cooldown_remaining(String(slot)) - player_dt)
	counterstep_remaining = maxf(0.0, counterstep_remaining - dt)
	turnabout_remaining = maxf(0.0, turnabout_remaining - dt)
	# World time, matching hit reactions themselves. Personal tempo must not buy a
	# slow character a longer guarantee than a fast one, and frozen time does not
	# burn it -- the player may deliberate as long as they like before spending it.
	player_hit_protection_remaining = maxf(0.0, player_hit_protection_remaining - dt)
	assassination_window_remaining = maxf(0.0, assassination_window_remaining - dt)
	aimed_remaining = maxf(0.0, aimed_remaining - dt)
	if aimed_remaining <= 0.0: aimed_enemy_id = -1
	if stealth_remaining > 0.0:
		_drain_stealth(dt)
		# _drain_stealth can end the hide outright by emptying the pool, so re-check
		# rather than running the duration clock on something already over.
		if stealth_remaining > 0.0:
			stealth_remaining = maxf(0.0, stealth_remaining - dt)
			if stealth_remaining <= 0.0: _end_stealth("expired")
	if player_posture_recovery_delay > 0.0:
		player_posture_recovery_delay = maxf(0.0, player_posture_recovery_delay - player_dt)
	if player_posture < player_posture_max and player_posture_recovery_delay <= 0.0 and String(player_action.get("kind", "")) not in ["hit_reaction", "stagger"]:
		player_posture = minf(player_posture_max, player_posture + player_dt * float(player_properties.get("posture_recovery", 1.8)))
	if rally_remaining > 0.0:
		rally_remaining = maxf(0.0, rally_remaining - dt)
		if rally_remaining <= 0.0:
			_finish_rally(true)
			_set_message("Rally fades. Its recovery begins.")
	strength_remaining = maxf(0.0, strength_remaining - dt)
	var player_action_kind := String(player_action.get("kind", "idle"))
	if uses_energy_rules() and player_action_kind in ENERGY_REGEN_ACTIONS:
		_regenerate_energy(dt)
	# Time too poor to act, measured as a state rather than as refused attempts.
	# A counter of declined actions records nothing, because a player who can read
	# a greyed-out control never presses it -- the constraint has to be observed
	# from the bar, not from what was tried against it.
	if uses_energy_rules():
		if player_energy < energy_cost(_basic_attack_energy_cost()):
			energy_starved_time_total += dt
		if player_energy < energy_cost(_combo_energy_cost()):
			energy_combo_starved_time_total += dt
	if uses_energy_rules() and player_exhaustion_remaining > 0.0001:
		player_exhaustion_remaining = maxf(0.0, player_exhaustion_remaining - dt)
		winded_time_total += dt
		# Exhaustion sampled continuously rather than only at its two endpoints:
		# this is what separates "the slow has no teeth" from "the lockout is timed
		# for moments already made safe".
		if player_is_noticed(): exhaustion_threatened_time_total += dt
		if player_action_kind == "move": exhaustion_move_time_total += dt
		elif player_action_kind == "wait": exhaustion_wait_time_total += dt
		else: exhaustion_other_time_total += dt
		if player_exhaustion_remaining <= 0.0001:
			exhausted_dodge_chain = 0
			_record_exhaustion_threat(false)
			_set_message("Your breath steadies. Your footing and your attacks return.")
	_build_enemy_spatial_index()
	_update_effects(dt)
	_update_conditions(dt)
	_update_player(player_dt)
	_update_exploration()
	_try_recover_xp()
	_update_enemies(dt, _simulation_tick_index % 2 == 0)
	_update_projectiles(dt)
	_update_hazards(dt)
	_remove_dead_enemies()

func _condition_threshold(condition_id: String, resistance: int, specific_multiplier: float = 1.0) -> float:
	var base := float({"laceration": 18.0, "poison": 20.0, "sleep": 18.0, "frost": 16.0, "burning": 14.0, "frenzy": 20.0}.get(condition_id, 20.0))
	return base * (1.0 + 0.08 * float(maxi(0, resistance))) * maxf(0.1, specific_multiplier)

func apply_player_condition_buildup(condition_id: String, amount: float) -> bool:
	if amount <= 0.0: return false
	var immunity := Array(player_properties.get("condition_immunities", []))
	if immunity.has(condition_id): return false
	var current := float(player_condition_buildup.get(condition_id, 0.0)) + amount
	var threshold := _condition_threshold(condition_id, int(player_attributes.get("resistance", 5)))
	if current < threshold:
		player_condition_buildup[condition_id] = current
		return false
	player_condition_buildup[condition_id] = 0.0
	_trigger_player_condition(condition_id)
	return true

func _trigger_player_condition(condition_id: String) -> void:
	match condition_id:
		"laceration":
			_change_actor_hp(0, -15)
			survey_last_damage_source = "laceration"
		"poison": player_conditions[condition_id] = 8.0
		"sleep":
			player_conditions[condition_id] = 3.0
			player_action = _action("sleep", 3.0, Vector2.ZERO)
		"frost": player_conditions[condition_id] = 6.0
		"burning": player_conditions[condition_id] = 4.0
		"frenzy": player_conditions[condition_id] = 5.0
	_add_effect("condition", player_pos, 0, {"condition": condition_id})
	_set_message("%s takes hold." % condition_id.capitalize())
	if player_hp <= 0: _begin_death()

func apply_enemy_condition_buildup(enemy: Dictionary, condition_id: String, amount: float) -> bool:
	if amount <= 0.0: return false
	var properties := Dictionary(enemy.get("properties", {}))
	if Array(properties.get("condition_immunities", [])).has(condition_id): return false
	var buildup := Dictionary(enemy.get("condition_buildup", {}))
	var current := float(buildup.get(condition_id, 0.0)) + amount
	var threshold := _condition_threshold(condition_id, int(Dictionary(enemy.get("attributes", {})).get("resistance", 5)), float(Dictionary(properties.get("condition_multipliers", {})).get(condition_id, 1.0)))
	if current < threshold:
		buildup[condition_id] = current
		enemy["condition_buildup"] = buildup
		return false
	buildup[condition_id] = 0.0
	enemy["condition_buildup"] = buildup
	var conditions := Dictionary(enemy.get("conditions", {}))
	if condition_id == "laceration": _change_actor_hp(enemy, -15)
	else: conditions[condition_id] = {"poison": 8.0, "sleep": 3.0, "frost": 6.0, "burning": 4.0, "frenzy": 5.0}.get(condition_id, 4.0)
	enemy["conditions"] = conditions
	return true

func _update_conditions(dt: float) -> void:
	var ongoing_tick := false
	# Charged in world time, which is the point: this is a cost on acting, not on existing.
	if float(player_conditions.get("burning", 0.0)) > 0.0 and player_hp > 0:
		var burn_damage := BURN_DAMAGE_PER_SECOND * dt
		_player_burn_debt += burn_damage
		if _player_burn_debt >= 1.0:
			var applied := int(floor(_player_burn_debt))
			_player_burn_debt -= float(applied)
			_change_actor_hp(0, -applied)
			damage_received_total += applied
			survey_burn_damage_total += applied
			survey_last_damage_source = "burning"
			if player_hp <= 0:
				_begin_death()
				return
	for condition_id in player_condition_buildup.keys():
		player_condition_buildup[condition_id] = maxf(0.0, float(player_condition_buildup[condition_id]) - dt * 0.75)
	for condition_id in player_conditions.keys():
		player_conditions[condition_id] = maxf(0.0, float(player_conditions[condition_id]) - dt)
		if float(player_conditions[condition_id]) <= 0.0: player_conditions.erase(condition_id)
	_condition_tick_accumulator += dt
	if _condition_tick_accumulator >= 1.0:
		_condition_tick_accumulator -= 1.0
		ongoing_tick = true
		if float(player_conditions.get("poison", 0.0)) > 0.0:
			_change_actor_hp(0, -3)
			survey_last_damage_source = "poison"
		# Burning is charged per world-second above, not in this once-a-second sweep. Both
		# were running, so fire cost 27 health across two seconds while reporting 21 --
		# the meter and the damage disagreeing is exactly the kind of invisible combat
		# maths the design refuses.
		if player_hp <= 0: _begin_death()
	_refresh_active_enemy_cache()
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy: Dictionary = enemies[index]
		if Dictionary(enemy.get("condition_buildup", {})).is_empty() and Dictionary(enemy.get("conditions", {})).is_empty(): continue
		var buildup := Dictionary(enemy.get("condition_buildup", {}))
		for condition_id in buildup.keys(): buildup[condition_id] = maxf(0.0, float(buildup[condition_id]) - dt * 0.75)
		enemy["condition_buildup"] = buildup
		var conditions := Dictionary(enemy.get("conditions", {}))
		for condition_id in conditions.keys():
			conditions[condition_id] = maxf(0.0, float(conditions[condition_id]) - dt)
			if float(conditions[condition_id]) <= 0.0: conditions.erase(condition_id)
		enemy["conditions"] = conditions
		if ongoing_tick:
			if float(conditions.get("poison", 0.0)) > 0.0: _change_actor_hp(enemy, -3)
			if float(conditions.get("burning", 0.0)) > 0.0: _change_actor_hp(enemy, -6)

func _try_recover_xp() -> void:
	if bool(lost_xp.get("active", false)) and String(lost_xp.get("layer", current_layer)) == current_layer and player_pos.distance_to(Vector2(lost_xp.get("pos", Vector2.ZERO))) <= 58.0:
		var amount := int(lost_xp.get("amount", 0))
		carried_xp += amount
		lost_xp = {"active": false, "amount": 0, "pos": Vector2.ZERO}
		_add_effect("recover", player_pos, amount)
		_set_message("Reclaimed %d XP. It remains at risk until anchored." % amount)

func _update_player(dt: float) -> void:
	var kind := String(player_action["kind"])
	if kind == "idle":
		return
	player_action["elapsed"] = float(player_action["elapsed"]) + dt
	var elapsed := float(player_action["elapsed"])
	_tick_player_cast(dt)
	match kind:
		"cast", "circle":
			pass
		"move":
			player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, PLAYER_RADIUS, 0)
		"dodge":
			if elapsed >= float(player_action.get("move_start", 0.08)) and elapsed <= float(player_action.get("move_end", 0.38)):
				player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, PLAYER_RADIUS, 0)
			if uses_energy_rules():
				var vulnerable_start := float(player_action.get("vulnerable_recovery_start", player_action.get("evade_end", 0.38)))
				var previous_elapsed := elapsed - dt
				var vulnerable_overlap := maxf(0.0, minf(elapsed, float(player_action["duration"])) - maxf(previous_elapsed, vulnerable_start))
				dodge_vulnerable_time_total += vulnerable_overlap
		"attack":
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
				_resolve_player_attack_tick(elapsed)
		"combo", "art_combo":
			_update_player_combo(elapsed)
			elapsed = float(player_action.get("elapsed", elapsed))
			if kind == "combo" and bool(player_action.get("terminal_recovery_locked", false)):
				var recovery_start := float(player_action.get("terminal_recovery_start", elapsed))
				var previous_elapsed := elapsed - dt
				terminal_combo_recovery_time_total += maxf(0.0, minf(elapsed, float(player_action["duration"])) - maxf(previous_elapsed, recovery_start))
		"twin_fang":
			if elapsed >= float(player_action.get("move_start", 0.05)) and elapsed <= float(player_action.get("move_end", 0.24)):
				player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, PLAYER_RADIUS, 0)
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				_resolve_twin_fang_tick(elapsed)
		"sweep":
			if player_action.has("move_start") and elapsed >= float(player_action.get("move_start", 0.0)) and elapsed <= float(player_action.get("move_end", 0.0)):
				player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action.get("speed", 0.0)) * dt, PLAYER_RADIUS, 0)
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
				_resolve_player_attack_tick(elapsed)
		"rally":
			if elapsed >= float(player_action.get("effect_start", 0.18)) and not bool(player_action.get("rally_started", false)):
				player_action["rally_started"] = true
				rally_remaining = 5.5 if has_track_rank("warrior", 3) else 4.5
				rally_end_after_action = false
				rally_break_extension_used = false
				_apply_action_poise(player_action)
				_add_effect("rally", player_pos)
				_set_message("Rally takes hold.")
		"advance":
			if elapsed >= float(player_action["move_start"]) and elapsed <= float(player_action["move_end"]):
				player_pos = _move_player_advance(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, float(player_action.get("pass_mass", -1.0)))
			if elapsed >= float(player_action["impact_start"]) and elapsed <= float(player_action["impact_end"]):
				_resolve_advance_impact()
		"potion":
			if elapsed >= 0.28 and not bool(player_action["effect_done"]):
				player_action["effect_done"] = true
				player_hp = mini(player_max_hp, player_hp + 25 + int(track_property_ranks.get("fieldcraft_restoration", 0)) * 5)
				_set_message("Warmth returns to your limbs.")
		"consumable":
			if elapsed >= float(player_action.get("startup", 0.24)) and not bool(player_action["effect_done"]):
				player_action["effect_done"] = true
				_apply_consumable_effect(String(player_action.get("item_id", "")), Vector2(player_action.get("direction", player_facing)))
		"bow_draw":
			_update_bow_soft_aim(dt)
			var previous_draw := float(player_action.get("draw_ratio", 0.0))
			player_action["draw_ratio"] = clampf(elapsed / 0.90, 0.0, 1.0)
			if previous_draw < 0.995 and float(player_action["draw_ratio"]) >= 0.995:
				_add_effect("full_draw", player_pos)
				_set_message("The Bow reaches Full Draw.")
		"bow_release":
			if elapsed >= float(player_action.get("startup", 0.06)) and not bool(player_action.get("shot_spawned", false)):
				player_action["shot_spawned"] = true
				_spawn_bow_projectile(player_action)
		"bow_art":
			if elapsed >= float(player_action.get("startup", 0.28)) and not bool(player_action.get("shot_spawned", false)):
				player_action["shot_spawned"] = true
				_spawn_bow_art_projectiles(bool(player_action.get("piercing", false)), Vector2(player_action.get("direction", player_facing)))
		"stealth":
			if elapsed >= float(player_action.get("effect_start", 0.24)) and not bool(player_action.get("effect_done", false)):
				player_action["effect_done"] = true
				_begin_stealth()
				if has_track_rank("rogue", 4):
					for enemy in _nearby_enemies(player_pos, ACTIVE_ENEMY_RADIUS):
						if not _enemy_on_current_layer(enemy) or String(enemy.get("awareness", "idle")) != "alerted": continue
						enemy["awareness"] = "suspicious"
						enemy["last_known_player"] = player_pos
						enemy["suspicious_remaining"] = maxf(float(enemy.get("suspicious_remaining", 0.0)), 2.6)
				_set_message("You disappear from direct perception.")
		"vault":
			if elapsed >= float(player_action.get("move_start", 0.0)) and elapsed <= float(player_action.get("move_end", 0.34)):
				var vault_origin := player_pos
				player_pos = _move_vault_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt)
				_resolve_vault_crossings(vault_origin, player_pos)
		"take_aim":
			if elapsed >= float(player_action.get("effect_start", 0.50)) and not bool(player_action.get("effect_done", false)):
				player_action["effect_done"] = true
				aimed_enemy_id = int(player_action.get("target_id", -1))
				aimed_remaining = 6.0
				_set_message("The target is Aimed.")
	if elapsed + 0.00001 >= float(player_action["duration"]):
		if kind in ["attack", "sweep", "combo", "art_combo", "twin_fang"]: _survey_finalize_strike_probe("complete")
		if kind in ["attack", "sweep", "combo", "art_combo"] and Array(player_action["hit_ids"]).is_empty():
			if mode_id == ModeRulesScript.COMBAT_SURVEY: survey_empty_melee_contacts += 1
			_set_message("Your cut finds only air.")
			if kind in ["attack", "combo"]: _reset_building_force()
		elif kind == "block" and not bool(player_action["effect_done"]):
			_set_message("You lower the guard without contact.")
		elif kind == "endure" and not bool(player_action["effect_done"]):
			_set_message("The Endure window passes without a hit.")
		var completed_kind := kind
		var completed_direction := Vector2(player_action.get("direction", player_facing))
		var continue_advance := completed_kind == "advance" and has_track_rank("vanguard", 2) and bool(player_action.get("continue_held", false))
		var completed_twin_sequence := completed_kind == "combo" and bool(player_action.get("knife_sequence", false)) and player_weapon_frame == "twin_knives" and int(player_action.get("committed_phase", 0)) >= int(player_action.get("combo_length", 6)) - 1
		if completed_twin_sequence:
			weapon_sequence_cooldown = 0.0 if uses_energy_rules() else (0.55 if has_track_rank("knife", 5) else TWIN_KNIFE_SEQUENCE_RECOVERY)
			if not uses_energy_rules(): _set_message("The full sequence leaves your knives recovering.")
		_break_player_combo()
		player_action = _idle_action()
		if completed_kind in ["stagger", "hit_reaction"]:
			_player_reaction_completed_this_tick = true
			if player_posture <= 0.0001:
				player_posture = player_posture_max
		if rally_end_after_action: _finish_rally(true)
		if player_overexertion_pending:
			if continue_advance: energy_blocked_continuations += 1
			_begin_exhaustion()
		elif continue_advance:
			_begin_sword_combo(completed_direction, true, true)

func _move_player_advance(origin: Vector2, delta: Vector2, pass_mass: float) -> Vector2:
	if pass_mass < 0.0: return _move_actor(origin, delta, PLAYER_RADIUS, 0)
	var candidate := origin + delta
	if _position_blocked_static(candidate, PLAYER_RADIUS): return origin
	for enemy in _nearby_enemies(candidate, PLAYER_RADIUS + 90.0):
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		if candidate.distance_to(Vector2(enemy["pos"])) >= PLAYER_RADIUS + float(enemy["radius"]): continue
		var mass := float(Dictionary(enemy.get("properties", {})).get("mass", 1.0))
		if mass > pass_mass: return origin
	return candidate

func _position_blocked_static(position: Vector2, radius: float) -> bool:
	if not _inside_world(position, radius): return true
	for wall in _nearby_walls(position, radius + 8.0):
		if _circle_intersects_rect(position, radius, wall): return true
	return not _actor_footprint_on_floor(position, radius)

func _resolve_advance_impact() -> void:
	var hit_ids: Array = player_action.get("impact_ids", [])
	var max_targets := int(player_action.get("max_targets", 1))
	if hit_ids.size() >= max_targets: return
	var direction := Vector2(player_action["direction"]).normalized()
	var side := direction.rotated(PI * 0.5)
	var contacts: Array[Dictionary] = []
	for enemy in _nearby_enemies(player_pos, 125.0):
		if not _enemy_on_current_layer(enemy) or hit_ids.has(int(enemy["id"])): continue
		var offset := Vector2(enemy["pos"]) - player_pos
		var forward := offset.dot(direction)
		var lateral := absf(offset.dot(side))
		if forward < -8.0 or forward > 82.0 + float(enemy["radius"]): continue
		if lateral > 34.0 + float(enemy["radius"]): continue
		contacts.append({"enemy": enemy, "forward": forward})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["forward"]) < float(b["forward"]))
	for contact in contacts:
		if hit_ids.size() >= max_targets: break
		var enemy: Dictionary = contact["enemy"]
		hit_ids.append(int(enemy["id"]))
		var raw_damage := int(player_action.get("damage_min", 10)) + _rally_damage_bonus()
		var resolved := _resolve_player_physical_values(enemy, raw_damage, float(player_action["posture_damage"]) + _rally_posture_bonus(), player_action)
		var damage := int(resolved["damage"])
		_change_actor_hp(enemy, -damage)
		damage_dealt += damage
		_on_player_hit_landed(enemy)
		var impact := Vector2(enemy["pos"]) - direction * float(enemy["radius"]) * 0.4
		var posture_broken := _apply_actor_posture_damage(enemy, float(resolved["posture"]), impact)
		_set_enemy_position(enemy, _push_enemy(enemy, direction, 64.0 if posture_broken else float(player_action["push"])))
		_register_enemy_hit_awareness(enemy, resolved, player_action)
		_add_effect("hit", impact, damage, {"direction": direction})
		_handle_player_contact_aftermath(enemy, resolved)
	_set_message("Advance lands with a driving impact.")
	player_action["impact_ids"] = hit_ids

func _push_enemy(enemy: Dictionary, direction: Vector2, distance: float) -> Vector2:
	var result := Vector2(enemy["pos"])
	var radius := float(enemy["radius"])
	var enemy_id := int(enemy["id"])
	var steps := maxi(1, int(ceil(distance / 10.0)))
	var step := direction.normalized() * (distance / float(steps))
	for index in range(steps):
		var candidate := result + step
		if _position_blocked_static(candidate, radius): break
		var blocked := false
		for other in _nearby_enemies(candidate, radius + 80.0):
			if int(other.get("id", -1)) == enemy_id or int(other.get("hp", 0)) <= 0 or not _enemy_on_current_layer(other): continue
			if candidate.distance_to(Vector2(other["pos"])) < radius + float(other["radius"]):
				blocked = true
				break
		if blocked: break
		result = candidate
	return result

func _apply_consumable_effect(item_id: String, direction: Vector2) -> void:
	match item_id:
		"throwing_knife":
			_break_stealth_for_hostile_action()
			_spawn_player_projectile("throwing_knife", direction)
		"firebomb":
			_break_stealth_for_hostile_action()
			_spawn_player_projectile("firebomb", direction)
		"smoke_vial":
			for enemy in _nearby_enemies(player_pos, 360.0):
				if not _enemy_on_current_layer(enemy): continue
				enemy["smoked_remaining"] = 2.8
				enemy["awareness"] = "suspicious"
				enemy["suspicious_remaining"] = 2.8
				enemy["action"] = _idle_action()
			_add_effect("smoke", player_pos)
			_set_message("Smoke veils the immediate path.")

func _update_player_combo(elapsed: float) -> void:
	var phases: Array = player_action.get("phases", [])
	if phases.is_empty():
		player_action["duration"] = elapsed
		return
	var committed_phase := int(player_action.get("committed_phase", 0))
	var phase: Dictionary = phases[committed_phase]
	var link := float(phase.get("link", phase["active_end"]))
	if not bool(player_action.get("terminal_recovery_locked", false)) and elapsed >= link:
		if committed_phase >= phases.size() - 1 or not bool(player_action.get("continue_held", false)):
			_lock_combo_terminal_recovery(phase)
		elif not _can_commit_physical_action():
			energy_blocked_continuations += 1
			_lock_combo_terminal_recovery(phase)
		else:
			var next_phase := committed_phase + 1
			if not _spend_energy(float(Dictionary(phases[next_phase]).get("energy_cost", 0.0))):
				energy_blocked_continuations += 1
				_lock_combo_terminal_recovery(phase)
			else:
				committed_phase = next_phase
				player_action["committed_phase"] = committed_phase
				phase = Dictionary(phases[committed_phase])
				if player_weapon_frame == "sword" and has_track_rank("swordsmanship", 2): _follow_the_opening(committed_phase)
				_set_message("The sequence flows into strike %d." % (committed_phase + 1))
	player_action["technique_id"] = String(phase["technique"])
	player_action["startup"] = float(phase["startup"])
	player_action["active_end"] = float(phase["active_end"])
	player_action["reach"] = float(phase["reach"])
	player_action["damage_min"] = int(phase["damage_min"])
	player_action["damage_max"] = int(phase["damage_max"])
	player_action["posture_damage"] = float(phase["posture"])
	if int(player_action.get("phase_index", -1)) != committed_phase:
		if int(player_action.get("phase_index", -1)) >= 0: _survey_finalize_strike_probe("phase_complete")
		if int(player_action.get("phase_index", -1)) >= 0 and Array(player_action.get("hit_ids", [])).is_empty():
			if mode_id == ModeRulesScript.COMBAT_SURVEY: survey_empty_melee_contacts += 1
			_reset_building_force()
			if bool(player_action.get("knife_sequence", false)): player_action["knife_contact_chain"] = 0
		player_action["phase_index"] = committed_phase
		player_action["hit_done"] = false
		player_action["hit_ids"] = []
		player_action["building_force_registered"] = false
		player_action["building_force_bonus"] = _building_force_bonus()
	if elapsed >= float(phase["startup"]) and elapsed <= float(phase["active_end"]):
		if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
		_resolve_player_attack_tick(elapsed)

func _lock_combo_terminal_recovery(phase: Dictionary) -> void:
	if bool(player_action.get("terminal_recovery_locked", false)): return
	player_action["terminal_recovery_locked"] = true
	player_action["continue_held"] = false
	player_action["terminal_recovery_start"] = float(phase.get("link", phase["active_end"]))
	player_action["duration"] = float(phase["end"])
	if not bool(player_action.get("terminal_recovery_recorded", false)):
		player_action["terminal_recovery_recorded"] = true
		terminal_combo_recoveries_total += 1
	_set_message("The sequence ends. Your weapon completes its recovery.")

func _break_player_combo() -> void:
	# Combos are now one continuous action, so there is no between-action chain
	# state to preserve. Keeping this boundary makes interruption call sites clear.
	pass

func _follow_the_opening(phase_index: int) -> void:
	var phases: Array = player_action.get("phases", [])
	if phase_index < 0 or phase_index >= phases.size(): return
	var phase := Dictionary(phases[phase_index])
	var reach := float(phase.get("reach", 130.0))
	var test_action := {
		"technique_id": String(phase.get("technique", "diagonal_cut")),
		"elapsed": 0.5,
		"startup": 0.0,
		"active_end": 1.0,
		"duration": 1.0,
		"reach": reach,
	}

	var current_sample := AttackGeometryScript.pose(test_action, player_pos, player_facing, _nearby_walls(player_pos, reach + 90.0))
	for existing in _nearby_enemies(player_pos, reach + 120.0):
		if _enemy_on_current_layer(existing) and enemy_visible_to_player(existing) and AttackGeometryScript.hits_circle(current_sample, Vector2(existing["pos"]), float(existing.get("radius", ENEMY_RADIUS))):
			return
	var best_direction := Vector2.ZERO
	var best_angle := INF
	for enemy in _nearby_enemies(player_pos, reach + 120.0):
		if not _enemy_on_current_layer(enemy) or not enemy_visible_to_player(enemy): continue
		var predicted := Vector2(enemy["pos"])
		var enemy_action: Dictionary = enemy.get("action", {})
		var enemy_kind := String(enemy_action.get("kind", "idle"))
		if enemy_kind in ["move", "evade", "dodge_strike", "charge", "pounce_combo"]:
			var remaining := maxf(0.0, float(enemy_action.get("duration", 0.0)) - float(enemy_action.get("elapsed", 0.0)))
			var sample_time := minf(remaining, maxf(0.0, float(phase.get("startup", 0.0)) - float(player_action.get("elapsed", 0.0))))
			var speed := float(enemy_action.get("speed", _enemy_move_speed(enemy)))
			predicted += Vector2(enemy_action.get("direction", Vector2.ZERO)).normalized() * speed * sample_time
		var offset := predicted - player_pos
		if offset.length() > reach + float(enemy.get("radius", ENEMY_RADIUS)): continue
		var angle := absf(player_facing.angle_to(offset.normalized()))
		if angle <= deg_to_rad(45.0) and angle < best_angle:
			best_angle = angle
			best_direction = offset.normalized()
	if best_direction.length_squared() > 0.001:
		player_facing = best_direction
		player_action["direction"] = best_direction

func _enemy_ability_action(ability_id: String, direction: Vector2) -> Dictionary:
	var definition := AbilityCatalogScript.enemy_ability(ability_id)
	if definition.is_empty():
		push_error("Unknown enemy ability '%s'." % ability_id)
		return _idle_action()
	var action := _action(String(definition["action_kind"]), float(definition["duration"]), direction)
	action["startup"] = float(definition["startup"])
	action["ability_id"] = ability_id
	if ability_id == "fireball": action["label"] = "fireball"
	return action

func _resolve_twin_fang_tick(elapsed: float) -> void:
	if bool(player_action.get("contact_done", false)): return
	# Resolve after the short lunge has carried the actor into the crossing point.
	# Both blades are still sampled on this exact simulation tick.
	if elapsed < 0.245: return
	player_action["contact_done"] = true
	if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
	var contacts_by_id: Dictionary = {}
	var pending_awareness: Array[Dictionary] = []
	for technique_id in ["knife_cut_in", "knife_cut_out"]:
		var sampled_action := player_action.duplicate()
		sampled_action["technique_id"] = technique_id
		sampled_action["elapsed"] = elapsed
		var sample := AttackGeometryScript.pose(sampled_action, player_pos, player_facing, _nearby_walls(player_pos, float(player_action.get("reach", 104.0)) + 70.0))
		_survey_update_strike_probe(sample, elapsed)
		var first_contact: Dictionary = {}
		for enemy in _nearby_enemies(player_pos, float(player_action.get("reach", 104.0)) + 100.0):
			if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
			if not AttackGeometryScript.hits_circle(sample, Vector2(enemy["pos"]), float(enemy["radius"])): continue
			var order := AttackGeometryScript.contact_order(sample, Vector2(enemy["pos"]))
			if first_contact.is_empty() or order < float(first_contact["order"]):
				first_contact = {"enemy": enemy, "order": order, "point": AttackGeometryScript.contact_point(sample, Vector2(enemy["pos"]))}
		if not first_contact.is_empty():
			var enemy: Dictionary = first_contact["enemy"]
			var enemy_id := int(enemy["id"])
			var contact := Dictionary(contacts_by_id.get(enemy_id, {"enemy": enemy, "blades": 0, "point": Vector2.ZERO}))
			contact["blades"] = int(contact["blades"]) + 1
			contact["point"] = Vector2(contact["point"]) + Vector2(first_contact["point"])
			contacts_by_id[enemy_id] = contact
	for enemy_id in contacts_by_id:
		var contact := Dictionary(contacts_by_id[enemy_id])
		var enemy: Dictionary = contact["enemy"]
		var blade_count := int(contact["blades"])
		var hit_point := Vector2(contact["point"]) / float(blade_count)
		var awareness_before := String(enemy.get("awareness", "idle"))
		var action_before := Dictionary(enemy.get("action", _idle_action())).duplicate(true)
		var per_blade_damage := int(player_action.get("damage_per_blade", 8)) + (1 if has_track_rank("knife", 2) else 0)
		var resolved := _resolve_player_physical_values(enemy, per_blade_damage * blade_count, float(player_action.get("posture_per_blade", 2.0)) * float(blade_count), player_action)
		var damage := int(resolved["damage"])
		var posture := float(resolved["posture"])
		_change_actor_hp(enemy, -damage)
		damage_dealt += damage
		_on_player_hit_landed(enemy)
		var posture_broken := _apply_actor_posture_damage(enemy, posture, hit_point)
		var reaction_applied := false
		if not posture_broken and _player_hit_can_interrupt(): reaction_applied = _apply_enemy_hit_reaction(enemy, posture, awareness_before, action_before, hit_point, player_action)
		pending_awareness.append({"enemy": enemy, "result": resolved})
		for blade in range(blade_count):
			var blade_offset := player_facing.rotated(PI * 0.5) * (float(blade) - 0.5 * float(blade_count - 1)) * 8.0
			_add_effect("hit", hit_point + blade_offset, damage if blade == 0 else 0, {"direction": (Vector2(enemy["pos"]) - hit_point).normalized(), "interrupted": reaction_applied})
		_handle_player_contact_aftermath(enemy, resolved)
		var hit_ids: Array = player_action["hit_ids"]
		hit_ids.append(int(enemy_id))
		player_action["hit_ids"] = hit_ids
		_survey_mark_strike_resolution(enemy, "hit")
	for pending in pending_awareness:
		_register_enemy_hit_awareness(Dictionary(pending["enemy"]), Dictionary(pending["result"]), player_action)
	if contacts_by_id.is_empty(): _set_message("Twin Fang closes on empty air.")
	else: _set_message("Both blades land in the same instant.")

func _player_basic_attack_definition(_direction: Vector2) -> Dictionary:
	# A direct tap or ×1 command always uses the compact opener. The varied
	# three-form chain belongs to request_combo(), where it is one uninterrupted
	# commitment and cannot be resumed after time freezes.
	if player_weapon_frame != "sword":
		return {"step": 0, "duration": player_attack_duration, "startup": player_attack_startup, "active_end": player_attack_active_end, "reach": player_attack_reach, "damage_min": player_damage_min, "damage_max": player_damage_max, "posture": player_attack_posture, "technique": player_attack_technique}
	var result := {"duration": 1.06, "startup": 0.30, "active_end": 0.41, "reach": 104.0, "damage_min": 10, "damage_max": 10, "posture": 1.8, "technique": "opening_cut"}
	if has_track_rank("swordsmanship", 3):
		result["damage_min"] = int(result["damage_min"]) + 1
		result["damage_max"] = int(result["damage_min"])
		result["posture"] = float(result["posture"]) + 0.5
	if has_track_rank("swordsmanship", 5): result["duration"] = 0.97
	result["step"] = 0
	return result

func _survey_update_strike_probe(sample: Dictionary, elapsed: float) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY or not bool(sample.get("active", false)): return
	var technique_id := String(sample.get("technique_id", player_action.get("technique_id", "attack")))
	var phase_index := int(player_action.get("phase_index", 0))
	var probe: Dictionary = Dictionary(player_action.get("survey_strike_probe", {}))
	if probe.is_empty() or String(probe.get("technique_id", "")) != technique_id or int(probe.get("phase_index", -999)) != phase_index:
		if not probe.is_empty(): _survey_finalize_strike_probe("phase_changed")
		probe = {
			"index": survey_strike_diagnostics.size() + 1,
			"room_time": simulation_time - float(survey_room_entry.get("time", simulation_time)),
			"action": String(player_action.get("ability_id", player_action.get("kind", "attack"))),
			"phase_index": phase_index,
			"phase": phase_index + 1,
			"technique_id": technique_id,
			"technique": AttackGeometryScript.label(technique_id),
			"reach": float(player_action.get("reach", player_attack_reach)),
			"view": survey_current_view_mode,
			"result": "miss",
			"targets": [],
			"closest_clearance": INF,
			"shape": String(sample.get("shape", "unknown")),
		}
		if String(sample.get("shape", "")) == "sector":
			probe.merge({"inner_radius": float(sample.get("inner_radius", 0.0)), "outer_radius": float(sample.get("outer_radius", 0.0)), "arc_degrees": rad_to_deg(float(sample.get("end_angle", 0.0)) - float(sample.get("start_angle", 0.0)))}, true)
		elif String(sample.get("shape", "")) == "segment":
			probe.merge({"footprint_length": Vector2(sample.get("start", player_pos)).distance_to(Vector2(sample.get("end", player_pos))), "footprint_radius": float(sample.get("radius", 0.0))}, true)
		elif String(sample.get("shape", "")) == "circle":
			probe["footprint_radius"] = float(sample.get("radius", 0.0))
	var direction := player_facing.normalized() if player_facing.length_squared() > 0.001 else Vector2.UP
	var side := direction.rotated(PI * 0.5)
	# Recorded whether or not an enemy is found. The enemy loop below overwrites
	# these with identical values; without them a swing that found nobody printed
	# every coordinate as (0,0) and read as a corrupt record rather than an honest
	# one. The enemy coordinates stay absent, because there is no enemy.
	probe.merge({
		"player_x": player_pos.x,
		"player_y": player_pos.y,
		"facing_x": direction.x,
		"facing_y": direction.y,
		"weapon_start_x": float(Vector2(sample.get("weapon_start", player_pos)).x),
		"weapon_start_y": float(Vector2(sample.get("weapon_start", player_pos)).y),
		"weapon_end_x": float(Vector2(sample.get("weapon_end", player_pos)).x),
		"weapon_end_y": float(Vector2(sample.get("weapon_end", player_pos)).y),
	}, true)
	for enemy in _nearby_enemies(player_pos, float(player_action.get("reach", player_attack_reach)) + 260.0):
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		var enemy_pos := Vector2(enemy["pos"])
		var clearance := AttackGeometryScript.clearance_to_circle(sample, enemy_pos, float(enemy.get("radius", ENEMY_RADIUS)))
		if clearance >= float(probe.get("closest_clearance", INF)): continue
		var relative := enemy_pos - player_pos
		var enemy_action := Dictionary(enemy.get("action", {}))
		probe.merge({
			"closest_clearance": clearance,
			"closest_enemy_id": int(enemy.get("id", -1)),
			"closest_enemy": String(enemy.get("kind", "unknown")),
			"center_distance": relative.length(),
			"edge_distance": maxf(0.0, relative.length() - float(enemy.get("radius", ENEMY_RADIUS)) - PLAYER_RADIUS),
			"forward": relative.dot(direction),
			"lateral": relative.dot(side),
			"player_x": player_pos.x,
			"player_y": player_pos.y,
			"enemy_x": enemy_pos.x,
			"enemy_y": enemy_pos.y,
			"facing_x": direction.x,
			"facing_y": direction.y,
			"enemy_action": String(enemy_action.get("kind", "idle")),
			"enemy_action_elapsed": float(enemy_action.get("elapsed", 0.0)),
			"sample_elapsed": elapsed,
			"shape": String(sample.get("shape", "unknown")),
			"geometry_overlap": clearance <= 0.0,
			"occluded": AttackGeometryScript.is_occluded(sample, enemy_pos),
			"weapon_start_x": float(Vector2(sample.get("weapon_start", player_pos)).x),
			"weapon_start_y": float(Vector2(sample.get("weapon_start", player_pos)).y),
			"weapon_end_x": float(Vector2(sample.get("weapon_end", player_pos)).x),
			"weapon_end_y": float(Vector2(sample.get("weapon_end", player_pos)).y),
		}, true)
	player_action["survey_strike_probe"] = probe

func _survey_mark_strike_resolution(enemy: Dictionary, result: String) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY: return
	var probe: Dictionary = Dictionary(player_action.get("survey_strike_probe", {}))
	if probe.is_empty(): return
	var targets: Array = probe.get("targets", [])
	var label := "%s#%d" % [String(enemy.get("kind", "enemy")), int(enemy.get("id", -1))]
	if not targets.has(label): targets.append(label)
	probe["targets"] = targets
	var priority := {"miss": 0, "evaded": 1, "blocked": 2, "hit": 3, "interrupted": 4}
	if int(priority.get(result, 0)) >= int(priority.get(String(probe.get("result", "miss")), 0)): probe["result"] = result
	player_action["survey_strike_probe"] = probe

func _survey_finalize_strike_probe(end_reason: String) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY: return
	var probe: Dictionary = Dictionary(player_action.get("survey_strike_probe", {}))
	if probe.is_empty(): return
	probe["end_reason"] = end_reason
	if not probe.has("closest_enemy"):
		probe["closest_enemy"] = "none nearby"
		probe["closest_clearance"] = -1.0
	probe["visual_overlap_collision_failure"] = String(probe.get("result", "miss")) == "miss" and bool(probe.get("geometry_overlap", false)) and not bool(probe.get("occluded", false))
	survey_strike_diagnostics.append(probe.duplicate(true))
	player_action.erase("survey_strike_probe")

func _resolve_player_attack_tick(elapsed: float) -> void:
	var is_sweep := String(player_action["kind"]) == "sweep"
	var sampled_action := player_action.duplicate()
	var action_reach := float(player_action.get("reach", player_attack_reach))
	var sample: Dictionary = AttackGeometryScript.pose(sampled_action, player_pos, player_facing, _nearby_walls(player_pos, action_reach + 90.0))
	_survey_update_strike_probe(sample, elapsed)
	_strike_barriers(sample, float(player_action.get("posture_damage", 1.0)))
	var hit_ids: Array = player_action["hit_ids"]
	var contacts: Array[Dictionary] = []
	var pending_awareness: Array[Dictionary] = []
	for enemy in _nearby_enemies(player_pos, action_reach + 120.0):
		if not _enemy_on_current_layer(enemy): continue
		var enemy_id := int(enemy["id"])
		if hit_ids.has(enemy_id): continue
		if AttackGeometryScript.hits_circle(sample, Vector2(enemy["pos"]), float(enemy["radius"])):
			contacts.append({"enemy": enemy, "order": AttackGeometryScript.contact_order(sample, Vector2(enemy["pos"])), "point": AttackGeometryScript.contact_point(sample, Vector2(enemy["pos"]))})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["order"]) < float(b["order"]))
	# A player melee form resolves every body physically crossed by its sampled
	# world-space weapon path. Narrow cuts and thrusts still require exact
	# alignment; they simply no longer stop at the first enemy in that path.
	if not contacts.is_empty(): player_action["hit_done"] = true
	for contact in contacts:
		var enemy: Dictionary = contact["enemy"]
		if String(enemy.get("kind", "")) == "bandit":
			enemy["revealed_to_player"] = true
			enemy["revealed_elapsed"] = 0.35
		var awareness_before := String(enemy.get("awareness", "idle"))
		var action_before := Dictionary(enemy.get("action", _idle_action())).duplicate(true)
		var contact_result: Dictionary = {}
		hit_ids.append(int(enemy["id"]))
		var hit_point := Vector2(contact["point"])
		if _enemy_parries_attack(enemy):
			# The Duellist takes your TURN, not your health. That is the whole distinction
			# from the Bandit: one relocates and counters, the other stands its ground and
			# spends the thing you cannot buy back in frozen time.
			_survey_mark_strike_resolution(enemy, "blocked")
			enemy["parry_cooldown"] = DUELLIST_PARRY_COOLDOWN
			enemy["action"] = _action("idle", 0.0, Vector2.ZERO)
			_add_effect("block", hit_point)
			_add_effect("posture_break", player_pos)
			player_action = _action("stagger", DUELLIST_PARRY_STAGGER, Vector2.ZERO)
			_apply_action_poise(player_action)
			_set_message("The duellist turns your blade aside.")
		elif _enemy_evades_attack(enemy):
			_survey_mark_strike_resolution(enemy, "evaded")
			_add_effect("dodge", Vector2(enemy["pos"]))
			_set_message("The bandit slips through the attack.")
		elif _enemy_blocks_attack(enemy):
			_survey_mark_strike_resolution(enemy, "blocked")
			_apply_actor_posture_damage(enemy, 2.0 if is_sweep else 0.5)
			_add_effect("block", hit_point)
			_set_message("The shield catches your weapon.")
		else:
			var bonus := 2 if strength_remaining > 0.0 else 0
			var enemy_action: Dictionary = enemy.get("action", {})
			var enemy_committed := String(enemy_action.get("kind", "idle")) != "idle"
			var enemy_recovering := enemy_committed and float(enemy_action.get("elapsed", 0.0)) > float(enemy_action.get("active_end", INF))
			var base_damage := int(player_action.get("damage_min", player_damage_min))
			var opening_damage := int(track_property_ranks.get("openings_recovery", 0)) if enemy_recovering else 0
			var force_bonus := int(player_action.get("building_force_bonus", 0)) if String(player_action.get("kind", "")) in ["attack", "combo"] else 0
			if bool(player_action.get("knife_sequence", false)) and has_track_rank("knife", 4):
				var knife_chain := int(player_action.get("knife_contact_chain", 0))
				force_bonus += mini(3, knife_chain + 1)
				player_action["knife_contact_chain"] = knife_chain + 1
			var raw_damage := base_damage + bonus + opening_damage + _rally_damage_bonus() + force_bonus
			var opening_posture := float(track_property_ranks.get("openings_posture", 0)) * 0.4 if enemy_committed else 0.0
			var posture_damage := float(player_action.get("posture_damage", 2.0)) + opening_posture + _rally_posture_bonus()
			var resolved := _resolve_player_physical_values(enemy, raw_damage, posture_damage, player_action)
			contact_result = resolved
			var dealt := int(resolved["damage"])
			posture_damage = float(resolved["posture"])
			_change_actor_hp(enemy, -dealt)
			damage_dealt += dealt
			_on_player_hit_landed(enemy)
			var posture_broken := _apply_actor_posture_damage(enemy, posture_damage, hit_point)
			var reaction_applied := false
			if not posture_broken and _player_hit_can_interrupt():
				reaction_applied = _apply_enemy_hit_reaction(enemy, posture_damage, awareness_before, action_before, hit_point, player_action)
			if enemy_committed and int(track_property_ranks.get("openings_composure", 0)) > 0:
				dodge_cooldown = maxf(0.0, dodge_cooldown - 0.25)
				skill_cooldown = maxf(0.0, skill_cooldown - 0.25)
			_add_effect("hit", hit_point, dealt, {"direction": (Vector2(enemy["pos"]) - hit_point).normalized(), "interrupted": reaction_applied})
			if String(player_action.get("kind", "")) in ["attack", "combo"] and not bool(player_action.get("building_force_registered", false)):
				player_action["building_force_registered"] = true
				_register_building_force_hit()
			_set_message("The %s connects." % AttackGeometryScript.label(String(player_action.get("technique_id", "diagonal_cut"))).to_lower())
			_survey_mark_strike_resolution(enemy, "interrupted" if reaction_applied else "hit")
		if not contact_result.is_empty():
			pending_awareness.append({"enemy": enemy, "result": contact_result})
			_handle_player_contact_aftermath(enemy, contact_result)
	# Contacts sampled on the same simulation tick share the awareness state they
	# had when the weapon crossed them. Broadcast only after all damage resolves,
	# so enemy-array/path order cannot change unaware damage within one strike.
	for pending in pending_awareness:
		_register_enemy_hit_awareness(Dictionary(pending["enemy"]), Dictionary(pending["result"]), player_action)
	player_action["hit_ids"] = hit_ids

func _resolve_player_physical_values(enemy: Dictionary, base_damage: int, posture_damage: float, source_action: Dictionary = {}) -> Dictionary:
	var preserved_execution := String(source_action.get("ability_id", "")) == "knife_execution" and int(source_action.get("execution_target_id", -1)) == int(enemy.get("id", -2)) and bool(source_action.get("execution_target_was_unaware", false))
	var unaware := String(enemy.get("awareness", "idle")) != "alerted" or preserved_execution
	var multiplier := 1.0
	if float(Dictionary(enemy.get("conditions", {})).get("frost", 0.0)) > 0.0 and not bool(source_action.get("frost_vulnerability_used", false)):
		multiplier *= 1.25
		source_action["frost_vulnerability_used"] = true
	if unaware:
		multiplier = 2.0 if has_track_rank("rogue", 1) else 1.5
		multiplier += float(source_action.get("unaware_bonus_multiplier", 0.0))
		if has_track_rank("rogue", 3): source_action["suppress_alert_until_end"] = true
	# Red chant. Reduction rather than immunity, so a warded enemy is slower to kill
	# but never a wall -- the answer is to remove the Chanter, not to give up.
	if _enemy_has_chant(enemy, "ward"): multiplier *= 1.0 - CHANT_WARD_REDUCTION
	var explicit_bonus := 0
	var defense_ignore := 0
	var aimed_contact := aimed_enemy_id == int(enemy.get("id", -1)) and aimed_remaining > 0.0
	if aimed_contact:
		explicit_bonus += 10 if has_track_rank("sharpshooter", 3) else 5
		defense_ignore = 6 if has_track_rank("sharpshooter", 3) else 3
		if has_track_rank("sharpshooter", 3): posture_damage += 3.0
		if has_track_rank("sharpshooter", 4):
			multiplier *= 1.5
			posture_damage *= 2.0
		aimed_enemy_id = -1
		aimed_remaining = 0.0
		_begin_subclass_cooldown(0.0 if uses_energy_rules() else _cooldown_for(energy_cost(TAKE_AIM_ENERGY)))
	var source_ability := String(source_action.get("ability_id", ""))
	if turnabout_remaining > 0.0 and source_ability in ["basic_attack", "sword_combo", "knife_sequence"]:
		explicit_bonus += 8
		posture_damage += 3.0
		turnabout_consumed_total += 1
		turnabout_remaining = 0.0
	var attributes := Dictionary(enemy.get("attributes", {}))
	var properties := Dictionary(enemy.get("properties", {}))
	var effective_defense := maxi(0, int(attributes.get("defense", 0)) + int(properties.get("armor", 0)) - defense_ignore)
	# Floored the same way incoming damage is. 0.2.32 established that every connecting
	# strike must be felt and replaced this exact `maxi(1, ...)` on the RECEIVING side;
	# the dealing side kept it, so armour or a damage-reducing effect could still put a
	# "-1" over an enemy the player cleanly hit. Nothing in the current roster reaches
	# that floor -- player damage lands at 8-10 against everything measured -- but the
	# guard costs nothing and closes the case rather than leaving it open.
	var final_damage := maxi(0, roundi((float(base_damage) + float(explicit_bonus)) * multiplier) - effective_defense)
	return {"damage": final_damage, "posture": posture_damage, "unaware": unaware, "aimed": aimed_contact}

func _register_enemy_hit_awareness(enemy: Dictionary, contact_result: Dictionary, source_action: Dictionary = {}) -> void:
	if int(enemy.get("hp", 0)) <= 0:
		enemy.erase("alarm_remaining")
		enemy.erase("alarm_position")
		return
	enemy["awareness"] = "alerted"
	enemy["alert_remaining"] = 3.0
	enemy["last_known_player"] = player_pos
	var clean_work := bool(contact_result.get("unaware", false)) and has_track_rank("rogue", 3)
	if clean_work:
		var resolution_time := float(source_action.get("duration", 0.0))
		if String(source_action.get("kind", "")) in ["combo", "art_combo"]:
			var phases: Array = source_action.get("phases", [])
			var phase_index := clampi(int(source_action.get("phase_index", 0)), 0, maxi(0, phases.size() - 1))
			if not phases.is_empty(): resolution_time = float(Dictionary(phases[phase_index]).get("end", resolution_time))
		var remaining_personal := maxf(0.0, resolution_time - float(source_action.get("elapsed", 0.0)))
		enemy["alarm_remaining"] = maxf(0.18, remaining_personal / maxf(0.01, _player_personal_tempo()))
		enemy["alarm_position"] = player_pos
	else:
		_broadcast_enemy_alarm(enemy, player_pos)

func _broadcast_enemy_alarm(source: Dictionary, known_position: Vector2) -> void:
	var source_id := int(source.get("id", -1))
	for ally in _nearby_enemies(Vector2(source.get("pos", known_position)), 480.0):
		if int(ally.get("id", -1)) == source_id or int(ally.get("hp", 0)) <= 0 or not _enemy_on_current_layer(ally): continue
		ally["awareness"] = "alerted"
		ally["alert_remaining"] = 3.0
		ally["last_known_player"] = known_position
		ally["suspicious_remaining"] = 0.0

func _update_enemy_alarm(enemy: Dictionary, dt: float) -> void:
	if not enemy.has("alarm_remaining"): return
	var remaining := maxf(0.0, float(enemy.get("alarm_remaining", 0.0)) - dt)
	if remaining > 0.0:
		enemy["alarm_remaining"] = remaining
		return
	var known_position := Vector2(enemy.get("alarm_position", player_pos))
	enemy.erase("alarm_remaining")
	enemy.erase("alarm_position")
	if int(enemy.get("hp", 0)) > 0: _broadcast_enemy_alarm(enemy, known_position)

# Whirlwind is the only player attack that moves bodies, and it is gated on the same
# PUSHABLE_MASS line as everything else that does -- so a Shield, Brute, Knight or Ox
# stands in it and everything lighter goes out. That is the art's honest limit: it buys
# room from a crowd of ordinary bodies and does nothing at all about a wall of heavy ones.
func _apply_whirlwind_push(enemy: Dictionary, distance: float) -> void:
	if distance <= 0.0 or int(enemy.get("hp", 0)) <= 0: return
	if _enemy_mass(String(enemy.get("kind", ""))) >= PUSHABLE_MASS: return
	var offset := Vector2(enemy["pos"]) - player_pos
	var away := offset.normalized() if offset.length_squared() > 0.001 else Vector2.RIGHT
	_set_enemy_position(enemy, _move_actor(Vector2(enemy["pos"]), away * distance, float(enemy.get("radius", ENEMY_RADIUS)), int(enemy["id"])))

func _handle_player_contact_aftermath(enemy: Dictionary, contact_result: Dictionary = {}) -> void:
	var conditions := Dictionary(enemy.get("conditions", {}))
	if float(conditions.get("sleep", 0.0)) > 0.0:
		conditions["sleep"] = maxf(0.0, float(conditions["sleep"]) - 1.0)
		enemy["conditions"] = conditions
	if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
	_apply_whirlwind_push(enemy, float(player_action.get("staff_push", 0.0)))
	if int(enemy.get("hp", 0)) > 0: return
	if has_track_rank("sharpshooter", 4) and bool(contact_result.get("aimed", false)) and subclass_ability_cooldown > 0.0:
		subclass_ability_cooldown = 0.0
	if has_track_rank("rogue", 5) and assassination_window_remaining > 0.0 and not _enemy_death_has_witness(enemy):
		_begin_stealth()
		# Rank 5 refunds the hide it just earned rather than charging for it twice.
		_begin_main_ability_cooldown(0.0)
		stealth_energy_paid = 0.0
		assassination_window_remaining = 0.0

func _begin_stealth(duration: float = STEALTH_DURATION) -> void:
	if stealth_remaining <= 0.0:
		stealth_energy_paid = 0.0
		survey_stealth_entries_total += 1
		# How fast concealment is re-entered is the measure of whether hide-execute-hide
		# has become the whole class. With no Energy-mode cooldown, `player_is_noticed()`
		# is the only thing rationing it -- and rogue rank 4 removes even that.
		if _stealth_last_ended_at >= 0.0 and simulation_time - _stealth_last_ended_at <= 3.0:
			survey_stealth_quick_reentries_total += 1
	stealth_remaining = duration
	stealth_cooldown_pending = true
	_add_effect("stealth", player_pos)

func _drain_stealth(dt: float) -> void:
	var charge := STEALTH_DRAIN_PER_SECOND * dt
	stealth_energy_paid += charge
	survey_stealth_hidden_time_total += dt
	if not uses_energy_rules(): return
	_spend_energy(charge, false)
	# Running the pool dry drops the veil. Exhaustion is a state you cannot hide in.
	if player_energy <= 0.0001 or player_overexertion_pending or player_exhaustion_remaining > 0.0:
		_end_stealth("exhausted")

func _end_stealth(reason: String) -> void:
	if stealth_remaining <= 0.0 and not stealth_cooldown_pending: return
	stealth_remaining = 0.0
	stealth_cooldown_pending = false
	# The floor, charged however the hide ended. See STEALTH_MINIMUM_ENERGY: the
	# rank-4 awareness wipe is instantaneous while a proportional price is not, so
	# without this a quarter-second tap would be the strictly better play.
	var owed := maxf(0.0, STEALTH_MINIMUM_ENERGY - stealth_energy_paid)
	if owed > 0.0:
		stealth_energy_paid += owed
		if uses_energy_rules(): _spend_energy(owed, false)
	survey_stealth_energy_paid_total += stealth_energy_paid
	stealth_last_end_reason = reason
	if reason == "cancelled": survey_stealth_cancels_total += 1
	_stealth_last_ended_at = simulation_time
	# A full 5s hide pays 50, which derives 12.0s -- exactly the cooldown that shipped
	# before this change. A hide cut short at 1.5s pays 20 (the floor) and derives 4.8s.
	_begin_main_ability_cooldown(0.0 if uses_energy_rules() else _cooldown_for(stealth_energy_paid))
	stealth_energy_paid = 0.0

# Free and instant: this stops a cost rather than performing an action, so there is
# nothing to commit to and no world time to spend. Without it the drain is not a drain
# -- you would pay the full 50 whether or not you needed five seconds, which is a
# cooldown with extra steps.
func request_end_stealth() -> bool:
	if stealth_remaining <= 0.0: return false
	_end_stealth("cancelled")
	_set_message("You step back into the open.")
	return true

func _break_stealth_for_hostile_action() -> void:
	if stealth_remaining <= 0.0: return
	var remaining_action := maxf(0.0, float(player_action.get("duration", 0.0)) - float(player_action.get("elapsed", 0.0))) / maxf(0.01, _player_personal_tempo())
	_end_stealth("broken")
	if has_track_rank("rogue", 5):
		assassination_window_remaining = maxf(2.0, remaining_action + 0.35)

func _enemy_death_has_witness(victim: Dictionary) -> bool:
	for enemy in _nearby_enemies(Vector2(victim.get("pos", player_pos)), 620.0):
		if int(enemy.get("id", -1)) == int(victim.get("id", -1)) or int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
		var enemy_pos := Vector2(enemy["pos"])
		var offset := player_pos - enemy_pos
		var distance := offset.length()
		var vision_range := _enemy_vision_range(enemy)
		var facing := Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
		var within_perception := distance <= 105.0 or (distance <= vision_range and offset.length_squared() > 0.001 and absf(facing.angle_to(offset.normalized())) <= deg_to_rad(65.0))
		if within_perception and _has_line_of_sight(enemy_pos, player_pos): return true
	return false

func _enemy_blocks_attack(enemy: Dictionary) -> bool:
	return _enemy_blocks_incoming(enemy, player_pos - Vector2(enemy["pos"]))

# Split out so a projectile can ask the same question. The guard was melee-only, so a
# Shieldbearer walked into arrows with no defence at all -- "shield wasn't defended
# whatsoever from arrows". A screen that only screens one damage type is not a screen,
# and it removes the counter-play the role exists to sell: go around it.
func _enemy_blocks_incoming(enemy: Dictionary, toward_source: Vector2) -> bool:
	if String(enemy["kind"]) != "shield": return false
	# The guard cannot be up while the sword is out. Its own strike, and the long
	# recovery after it, is the opening a screen is supposed to sell you -- blocking
	# straight through the attack made it unanswerable, which the 0.2.28 survey
	# tagged unfair after landing BLOCKED against a shield at melee@0.06 and 1.22.
	# Reeling counts too. The 0.2.35 survey tagged two rooms unfair, and the strike log
	# shows why: six blocks landed while the Shield was in `hit_reaction`, at elapsed
	# 0.40 through 1.79 -- you hit it, it flinched, and it blocked your follow-up with a
	# guard it could not possibly be holding. The 0.2.34 lengthening made this worse by
	# putting more of its life into states that were not on this list.
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) in ["melee", "dodge_strike", "charge", "slam", "hit_reaction", "stagger"]: return false
	return _within_arc(Vector2(enemy["facing"]), toward_source, deg_to_rad(72.0))

# The Duellist's answer to being swung at. Where the Bandit slips sideways and
# ripostes, this one plants and catches the blade: no damage to either side, and the
# player loses their turn instead of their health. In frozen time that is the more
# expensive currency, because every other enemy in the room gets to act inside it.
#
# The stance is entered in _try_duellist_parry during the player's wind-up, so it is a
# read on a commitment, not a reaction to a landed hit. It is also visible -- the
# stance is drawn -- and it has a cooldown, so the counter-play is to bait it out with
# something cheap and then attack into the gap.
func _enemy_parries_attack(enemy: Dictionary) -> bool:
	if String(enemy.get("kind", "")) != "duellist": return false
	var action: Dictionary = enemy.get("action", {})
	if String(action.get("kind", "idle")) != "parry_stance": return false
	var elapsed := float(action.get("elapsed", 0.0))
	if elapsed > float(action.get("parry_end", 0.42)): return false
	var incoming := player_pos - Vector2(enemy["pos"])
	# Front only. Getting behind a Duellist is the positional answer to it.
	return _within_arc(Vector2(enemy["facing"]), incoming, deg_to_rad(96.0))

func _try_duellist_parry(enemy: Dictionary) -> void:
	if String(enemy.get("kind", "")) != "duellist" or int(enemy.get("hp", 0)) <= 0: return
	var cooldown := float(enemy.get("parry_cooldown", 0.0))
	if cooldown > 0.0:
		enemy["parry_cooldown"] = maxf(0.0, cooldown - SIM_DT)
		return
	if String(enemy.get("awareness", "idle")) != "alerted": return
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) not in ["idle", "move"]: return
	if String(player_action.get("kind", "idle")) not in PLAYER_ATTACK_ACTION_KINDS: return
	if float(player_action.get("elapsed", 0.0)) >= float(player_action.get("startup", 0.24)): return
	var to_enemy := Vector2(enemy["pos"]) - player_pos
	if to_enemy.length() > float(player_action.get("reach", player_attack_reach)) + float(enemy["radius"]) + 24.0: return
	if not _within_arc(player_facing, to_enemy, deg_to_rad(85.0)): return
	_interrupt_enemy_action(enemy)
	# Face the threat: the parry only catches what comes at its front.
	enemy["facing"] = (player_pos - Vector2(enemy["pos"])).normalized()
	enemy["action"] = _action("parry_stance", 0.72, (player_pos - Vector2(enemy["pos"])).normalized())
	enemy["action"]["parry_end"] = 0.42
	# Spent whether or not it catches anything, so a feint really does draw it.
	enemy["parry_cooldown"] = DUELLIST_PARRY_COOLDOWN

func _enemy_evades_attack(enemy: Dictionary) -> bool:
	# Windstep is the caster's one answer to being reached, and it has to actually work or
	# it is a slow retreat that gets punished on the wind-up. The window is the travel
	# window itself -- it evades while it is gone, not before and not after, so swinging
	# early or waiting for the landing both beat it.
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) == "windstep":
		var step_elapsed := float(Dictionary(enemy["action"]).get("elapsed", 0.0))
		return step_elapsed >= float(Dictionary(enemy["action"]).get("move_start", 0.26)) and step_elapsed <= float(Dictionary(enemy["action"]).get("move_end", 0.58))
	if String(enemy.get("kind", "")) != "bandit": return false
	var action: Dictionary = enemy.get("action", {})
	var action_kind := String(action.get("kind", "idle"))
	var elapsed := float(action.get("elapsed", 0.0))
	return (action_kind == "evade" and elapsed >= 0.04 and elapsed <= 0.30) or (action_kind == "dodge_strike" and elapsed <= float(action.get("dodge_end", 0.30)))

func _apply_posture_damage(enemy: Dictionary, amount: float, contact: Vector2 = Vector2.INF) -> bool:
	if amount <= 0.0 or int(enemy["hp"]) <= 0: return false
	# Stagger is one authored opening, not a state that quick follow-up attacks
	# may perpetually refresh. Health damage has already resolved at each caller;
	# only additional posture damage is suppressed until the original reaction
	# ends and restores the enemy's posture.
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) == "stagger":
		enemy["posture"] = 0.0
		return false
	enemy["posture"] = maxf(0.0, float(enemy.get("posture", 1.0)) - amount)
	enemy["posture_recovery_delay"] = 1.15
	if float(enemy["posture"]) <= 0.0001:
		return _break_posture(enemy, contact)
	return false

func _break_posture(enemy: Dictionary, contact: Vector2 = Vector2.INF) -> bool:
	var action: Dictionary = enemy["action"]
	var kind := String(enemy["kind"])
	var action_kind := String(action.get("kind", "idle"))
	# Armour covers the WIND-UP, not just the swing. The hold used to require
	# active_started, which left the telegraph -- the entire reason a heavy enemy
	# exists -- as a free cancel window: the 0.2.30 survey recorded ten heavy attacks
	# across Ox, Brute and Polearm and zero contacts, against six landed hits from
	# nine Knife pokes. The bigger the body, the longer the opening it handed over.
	#
	# The ordinary flinch path already refused light hits here; posture breaks did
	# not, and a combo reaches a break readily. High-impact blows still interrupt
	# startup through _apply_enemy_hit_reaction, so a committed heavy is answered by
	# a real blow or by leaving -- never by chip damage, and never by nothing.
	if (_enemy_mass(kind) >= HEAVY_TELEGRAPH_MASS or _enemy_has_chant(enemy, "bulwark")) and action_kind in ["melee", "slam", "charge"]:
		enemy["posture"] = 0.25
		_add_effect("strain", Vector2(enemy["pos"]))
		_set_message("The heavy enemy holds its grounded attack.")
		return false
	var break_bonus_seconds := 0.08 * float(track_property_ranks.get("openings_break_duration", 0))
	var stagger_duration := (0.52 if kind in ["knife", "hound", "bandit"] else 0.66 if kind in ["archer", "ice_caster", "fire_caster", "boar"] else 0.78) + break_bonus_seconds
	# A posture break is meant to create an actionable opening. Its timer runs
	# while the player's breaking strike is still recovering, so a short fixed
	# duration could expire before time froze again. Guarantee 0.72 seconds of
	# world time after the current player commitment ends, adjusted into the
	# enemy's personal action clock so fast enemies receive the same opportunity.
	var player_recovery_world_seconds := 0.0
	if String(player_action.get("kind", "idle")) != "idle":
		var player_action_remaining := maxf(0.0, float(player_action.get("duration", 0.0)) - float(player_action.get("elapsed", 0.0)))
		player_recovery_world_seconds = player_action_remaining / maxf(0.01, _player_personal_tempo())
	var guaranteed_world_seconds := player_recovery_world_seconds + POSTURE_BREAK_OPENING_SECONDS + break_bonus_seconds
	stagger_duration = maxf(stagger_duration, guaranteed_world_seconds * _enemy_personal_tempo(enemy))
	var contact_point := Vector2(enemy["pos"]) if not contact.is_finite() else contact
	var reaction_direction := (Vector2(enemy["pos"]) - contact_point).normalized()
	if reaction_direction.length_squared() < 0.001: reaction_direction = -Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
	_interrupt_enemy_action(enemy)
	enemy["action"] = _action("stagger", stagger_duration, Vector2.ZERO)
	_clear_melee_intent(enemy)
	enemy["action"].merge({
		"reaction_contact": contact_point,
		"reaction_direction": reaction_direction,
		"reaction_strength": 1.65,
		"reaction_source_kind": action_kind,
		"interrupted_action": action.duplicate(true),
	}, true)
	enemy["posture"] = 0.0
	enemy["posture_recovery_delay"] = stagger_duration
	if has_track_rank("vanguard", 4):
		advance_cooldown = 0.0
	if rally_remaining > 0.0 and has_track_rank("warrior", 4) and not rally_break_extension_used:
		rally_break_extension_used = true
		rally_remaining += 1.0
	_add_effect("posture_break", contact_point, 0, {"direction": reaction_direction, "strength": 1.65})
	_set_message("The %s loses its footing." % kind)
	return true

# "Knowing my attack is faster than everyone else and staggers them immediately made
# melee combat trivial." Weight earns the right to cut a committed attack down; speed
# does not. The knife's opening cuts no longer interrupt -- posture still accumulates,
# so a full sequence still adds up to a break, and the later phases and Execution keep
# their teeth. This is the one place the Rogue's speed is allowed to cost it something.
func _cast_survives_light_hit() -> bool:
	return has_track_rank("mage", 1)

func _player_hit_can_interrupt() -> bool:
	if player_weapon_frame not in ["knife", "twin_knives"]: return true
	if String(player_action.get("kind", "idle")) != "combo": return true
	return int(player_action.get("phase_index", 0)) >= 2

func _apply_enemy_hit_reaction(enemy: Dictionary, impact: float, awareness_before: String, action_before: Dictionary, contact: Vector2 = Vector2.INF, source_action: Dictionary = {}) -> bool:
	if int(enemy.get("hp", 0)) <= 0: return false
	if not bool(source_action.get("allow_hit_reaction", true)): return false
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) == "stagger": return false
	var enemy_kind := String(enemy.get("kind", "blade"))
	var action_kind := String(action_before.get("kind", "idle"))
	# Damage and posture still resolve during a chain, but a hit reaction is one
	# authored opening. Later contacts cannot restart its timer and pin an enemy
	# indefinitely; a posture break may still replace it with a distinct stagger.
	if action_kind == "hit_reaction": return false
	var elapsed := float(action_before.get("elapsed", 0.0))
	var active_started := action_before.has("startup") and elapsed >= float(action_before.get("startup", INF))
	var high_impact := impact >= 3.5
	# Heavy bodies do not lose an authored attack to every light contact. Strong
	# impacts may still interrupt startup, and accumulated posture damage remains
	# the universal route to a full break. Once the weapon moves, even a strong
	# ordinary hit must trade with or evade the grounded commitment.
	if (_enemy_mass(enemy_kind) >= HEAVY_TELEGRAPH_MASS or _enemy_has_chant(enemy, "bulwark")) and action_kind in ["melee", "slam", "charge"]:
		if active_started or not high_impact: return false
	# A boar earns armour only after its pounce has accelerated. The crouch and
	# early travel remain interruptible, and a posture-heavy technique can still
	# arrest a full-speed charge.
	# Nothing short of lethal stops a running Ox. The damage has already been applied
	# by the caller, so reaching here means the blow did not kill it.
	if action_kind == "charge" and bool(action_before.get("unstoppable", false)) and elapsed >= float(action_before.get("startup", 0.0)):
		_add_effect("strain", Vector2(enemy["pos"]))
		return false
	if enemy_kind == "boar" and action_kind == "charge" and String(action_before.get("label", "")) == "pounce":
		var armour_start := float(action_before.get("momentum_armour_start", INF))
		if elapsed >= armour_start and not high_impact:
			_add_effect("strain", Vector2(enemy["pos"]))
			return false
	# Landing during an ordinary weapon's already-active contact window can still
	# produce a trade. Startup and recovery are interruptible; the hound's pounce
	# is the deliberate exception and can be knocked out of any phase.
	var in_active_contact := action_before.has("startup") and action_before.has("active_end") and elapsed >= float(action_before["startup"]) and elapsed <= float(action_before["active_end"])
	if in_active_contact and action_kind in ["melee", "dodge_strike"] and enemy_kind not in ["hound", "bandit"]:
		return false
	var duration := float(CombatCatalogScript.enemy_fact(enemy_kind, "hit_reaction"))
	if awareness_before != "alerted": duration += 0.16
	if high_impact: duration += 0.10
	# A light body cannot recover and act INSIDE the swing that hit it. A posture break
	# already guarantees player_remaining + 0.72s; an ordinary flinch guaranteed nothing,
	# so a Blade's flat 0.48s expired mid-combo and it got a free hit in frames the
	# player could not answer from -- "he recuperated before I was able to finish the
	# combo", 0.2.33 room 6.
	#
	# This is not a bonus opening: there is no added time, so the enemy is free the
	# instant the player is. Heavies are excluded because they answer with armour
	# instead, and giving them this as well would make a committed heavy unpunishable.
	if _enemy_mass(enemy_kind) < HEAVY_TELEGRAPH_MASS:
		duration = maxf(duration, _player_commitment_remaining() * _enemy_personal_tempo(enemy))
	var contact_point := Vector2(enemy["pos"]) if not contact.is_finite() else contact
	var reaction_direction := (Vector2(enemy["pos"]) - contact_point).normalized()
	if reaction_direction.length_squared() < 0.001: reaction_direction = -Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
	var reaction_strength := 1.18 if high_impact else 1.0
	if action_kind == "charge": reaction_strength += 0.16
	_interrupt_enemy_action(enemy)
	enemy["action"] = _action("hit_reaction", duration, Vector2.ZERO)
	_clear_melee_intent(enemy)
	enemy["action"].merge({
		"reaction_contact": contact_point,
		"reaction_direction": reaction_direction,
		"reaction_strength": reaction_strength,
		"reaction_source_kind": action_kind,
		"interrupted_action": action_before.duplicate(true),
		"reaction_combo_id": int(source_action.get("combo_instance_id", -1)),
	}, true)
	enemy["posture_recovery_delay"] = maxf(float(enemy.get("posture_recovery_delay", 0.0)), duration)
	_add_effect("interrupt", contact_point, 0, {"direction": reaction_direction, "strength": reaction_strength})
	return true

func _emit_sound(position: Vector2, radius: float) -> void:
	_sound_sequence += 1
	var stealth := float(player_attributes.get("stealth", 0)) if position.distance_to(player_pos) < 4.0 else 0.0
	var concealment := clampf(1.0 - 0.055 * stealth, 0.28, 1.0)
	var variation := rng.randf_range(0.78, 1.22) if stealth > 0.0 else 1.0
	last_sound = {"sequence": _sound_sequence, "pos": position, "radius": radius * concealment * variation}

func _update_enemy_awareness(enemy: Dictionary, dt: float) -> void:
	if float(enemy.get("smoked_remaining", 0.0)) > 0.0:
		enemy["awareness"] = "suspicious"
		enemy["suspicious_remaining"] = maxf(float(enemy.get("suspicious_remaining", 0.0)), float(enemy["smoked_remaining"]))
		enemy["action"] = _idle_action()
		return
	var enemy_pos := Vector2(enemy["pos"])
	var offset := player_pos - enemy_pos
	var distance := offset.length()
	var facing := Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
	var vision_range := _enemy_vision_range(enemy)
	var within_cone := distance <= 105.0 or (distance <= vision_range and absf(facing.angle_to(offset.normalized())) <= deg_to_rad(65.0))
	if not within_cone: enemy["los_refresh_remaining"] = 0.0
	var execution_holds_unaware := String(player_action.get("ability_id", "")) == "knife_execution" and int(player_action.get("execution_target_id", -1)) == int(enemy.get("id", -2)) and float(player_action.get("elapsed", 0.0)) <= float(player_action.get("active_end", 0.0)) and not Array(player_action.get("hit_ids", [])).has(int(enemy.get("id", -2)))
	var sees_player := not execution_holds_unaware and stealth_remaining <= 0.0 and within_cone and _sample_enemy_player_los(enemy, enemy_pos, dt)
	if sees_player:
		var already_alerted := String(enemy.get("awareness", "idle")) == "alerted"
		enemy["awareness"] = "alerted"
		enemy["alert_remaining"] = 3.0
		enemy["last_known_player"] = player_pos
		if not already_alerted: _rouse_neighbours(enemy)
		return
	var sound_sequence := int(last_sound.get("sequence", 0))
	if sound_sequence > int(enemy.get("heard_sound_sequence", 0)):
		enemy["heard_sound_sequence"] = sound_sequence
		if enemy_pos.distance_to(Vector2(last_sound.get("pos", player_pos))) <= float(last_sound.get("radius", 0.0)):
			enemy["last_known_player"] = Vector2(last_sound["pos"])
			if String(enemy.get("awareness", "idle")) != "alerted":
				enemy["awareness"] = "suspicious"
				enemy["suspicious_remaining"] = 2.6
	if String(enemy.get("awareness", "idle")) == "alerted":
		enemy["alert_remaining"] = maxf(0.0, float(enemy.get("alert_remaining", 0.0)) - dt)
		if float(enemy["alert_remaining"]) <= 0.0:
			enemy["awareness"] = "suspicious"
			enemy["suspicious_remaining"] = 2.6
	elif String(enemy.get("awareness", "idle")) == "suspicious":
		enemy["suspicious_remaining"] = maxf(0.0, float(enemy.get("suspicious_remaining", 0.0)) - dt)
		if float(enemy["suspicious_remaining"]) <= 0.0:
			enemy["awareness"] = "idle"
		enemy["action"] = _idle_action()

# "If an enemy notices me, the natural way to work is that enemies around that enemy
# become alerted as well." Suspicion rather than alert: they turn toward where the
# player was seen and search, which keeps concealment playable instead of ending the
# fight the instant one body glances the right way.
# "Might be a good idea to have ox ram through allies. It getting stuck behind other
# enemies is anticlimactic, and having him possibly attack its friends could provide
# tactical fun." Its stated trait is that it runs its line until it hits something, and
# the one thing it reliably failed to run through was its own side.
#
# Restricted to `unstoppable`, which is the Ox alone today. If every charger ploughed
# through its allies, formations would dissolve on contact and the arrangement would
# stop meaning anything -- which is the whole point of authoring them. No slowdown on
# the pass either: unstoppable should mean it. Credit goes to the player, who chose the
# ground this happens on.
func _gore_allies_in_path(charger: Dictionary, origin: Vector2, finish: Vector2, action: Dictionary) -> void:
	var gored: Array = action.get("gored_ids", [])
	var charger_id := int(charger.get("id", -2))
	var reach := float(charger.get("radius", ENEMY_RADIUS))
	for other in _nearby_enemies(origin, origin.distance_to(finish) + reach + 90.0):
		var other_id := int(other.get("id", -1))
		if other_id == charger_id or gored.has(other_id): continue
		if int(other.get("hp", 0)) <= 0 or not _enemy_on_current_layer(other): continue
		if _segment_distance_to_point(origin, finish, Vector2(other["pos"])) > reach + float(other.get("radius", ENEMY_RADIUS)): continue
		gored.append(other_id)
		_damage_enemy_from_consumable(other, int(action.get("damage_max", action.get("damage", 10))), 4.0, Vector2(other["pos"]))
	action["gored_ids"] = gored

# Straight rather than an arc, so the ends stay a real option. Perpendicular to the
# player's escape heading -- their movement direction if moving, otherwise straight away
# from the caster -- and placed ahead of them, so it cuts retreat rather than shielding it.
#
# The asymmetry is free: an enemy caster placing it behind the player leaves its own
# archers on the far side, while an Elementalist placing it toward the threat gates them.
# One rule, opposite value, decided entirely by where it goes.
func _raise_earth_wall(origin: Vector2, source_id: int) -> void:
	var heading := Vector2(player_action.get("direction", Vector2.ZERO))
	if String(player_action.get("kind", "idle")) != "move" or heading.length_squared() < 0.001:
		heading = player_pos - origin
	if heading.length_squared() < 0.001: heading = Vector2.DOWN
	heading = heading.normalized()
	var centre := player_pos + heading * EARTH_WALL_STANDOFF
	var axis := heading.rotated(PI * 0.5)
	var segment_span := EARTH_WALL_SPAN / float(EARTH_WALL_SEGMENTS)
	for index in range(EARTH_WALL_SEGMENTS):
		var offset := (float(index) - float(EARTH_WALL_SEGMENTS - 1) * 0.5) * segment_span
		_add_barrier({
			"pos": centre + axis * offset,
			"axis": axis,
			"half_length": segment_span * 0.5,
			"thickness": EARTH_WALL_THICKNESS,
			"hp": EARTH_WALL_SEGMENT_HP,
			"remaining": EARTH_WALL_DURATION,
			"lowered": false,
			"source_id": source_id,
			"layer": current_layer,
		})
	survey_barriers_raised += 1
	# One effect per segment along the length, so the raise itself is visible even if the
	# standing wall somehow is not. A wall that appears without an event to mark it is a
	# wall the player has no reason to look at.
	for index in range(EARTH_WALL_SEGMENTS):
		var mark := (float(index) - float(EARTH_WALL_SEGMENTS - 1) * 0.5) * segment_span
		_add_effect("earth_wall", centre + axis * mark)
	_set_message("The ground heaves into a wall.")

func barrier_rise_fraction(segment: Dictionary) -> float:
	if not bool(segment.get("lowered", false)): return 1.0
	return clampf(float(segment.get("rising", 0.0)) / EARTH_WALL_RISE_TIME, 0.0, 1.0)

func _barrier_blocks(segment: Dictionary, point: Vector2, radius: float) -> bool:
	if bool(segment.get("lowered", false)) or float(segment.get("hp", 0.0)) <= 0.0: return false
	if String(segment.get("layer", current_layer)) != current_layer: return false
	var axis := Vector2(segment["axis"])
	var offset := point - Vector2(segment["pos"])
	var along := clampf(offset.dot(axis), -float(segment["half_length"]), float(segment["half_length"]))
	return (Vector2(segment["pos"]) + axis * along).distance_to(point) <= float(segment["thickness"]) + radius

# The player is stopped by a barrier; enemies never are. That is the whole asymmetry, and
# it is why the navigation grid can stay ignorant of the thing.
# A wall stops the other side. The player's own wall was stopping the player and letting
# enemies walk through it, which is the rule exactly inverted: it was written as "barriers
# block the player" back when only enemies could raise one, and never revisited when the
# Elementalist learned to. Ownership is what decides, not whether you happen to be the
# player -- so an Earth Caster's wall cuts your retreat and yours gates their approach, and
# the same object reads as help or hindrance purely by who put it there.
func _barrier_opposes(segment: Dictionary, actor_id: int) -> bool:
	return _opposes(int(segment.get("source_id", -1)), actor_id)

func _point_in_barrier(point: Vector2, radius: float = 0.0, actor_id: int = 0) -> bool:
	for segment in barriers:
		if not _barrier_opposes(segment, actor_id): continue
		if _barrier_blocks(segment, point, radius): return true
	return false

func _segment_crosses_barrier(from_point: Vector2, to_point: Vector2) -> bool:
	for step in range(0, 13):
		if _point_in_barrier(from_point.lerp(to_point, float(step) / 12.0)): return true
	return false

# Enemy-facing hazards, for the ones the player casts. Deliberately NOT symmetric with the
# projectile rule: a shot hits whoever it hits because it can be redirected after it is
# committed, whereas a zone is placed where the caster chose. Making enemy zones burn their
# own side would be a real balance change to eight existing abilities and belongs in its
# own version, not smuggled in as a bug fix.
func _resolve_player_hazard_hit(hazard: Dictionary, source_label: String, hit_test: Callable) -> void:
	var struck: Array = Array(hazard.get("player_hit_ids", []))
	for enemy in _nearby_enemies(Vector2(hazard["pos"]), float(hazard["radius"]) + 120.0):
		if int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
		if struck.has(int(enemy["id"])): continue
		if not hit_test.call(enemy): continue
		struck.append(int(enemy["id"]))
		var contact := Vector2(enemy["pos"])
		var awareness_before := String(enemy.get("awareness", "idle"))
		var action_before: Dictionary = Dictionary(enemy.get("action", {})).duplicate(true)
		var source_action := {"kind": "cast", "ability_id": source_label, "duration": 0.35, "elapsed": 0.0, "allow_hit_reaction": true}
		var resolved := _resolve_player_physical_values(enemy, int(hazard["damage"]), float(hazard.get("posture", 1.4)), source_action)
		var damage := int(resolved["damage"])
		_change_actor_hp(enemy, -damage)
		damage_dealt += damage
		_on_player_hit_landed(enemy)
		if not _apply_actor_posture_damage(enemy, float(resolved["posture"]), contact):
			_apply_enemy_hit_reaction(enemy, float(resolved["posture"]), awareness_before, action_before, contact, source_action)
		_register_enemy_hit_awareness(enemy, resolved, source_action)
		_add_effect("hit", contact, damage, {"direction": (contact - Vector2(hazard["pos"])).normalized()})
		var charge := float(CONDITION_BUILDUP_BY_SOURCE.get(source_label, 0.0))
		if charge > 0.0: _apply_actor_condition_buildup(enemy, "burning" if "fire" in source_label else "frost", charge)
		_handle_player_contact_aftermath(enemy, resolved)
	hazard["player_hit_ids"] = struck

func _update_barriers(dt: float) -> void:
	if barriers.is_empty(): return
	var survivors: Array[Dictionary] = []
	for segment in barriers:
		segment["remaining"] = float(segment.get("remaining", 0.0)) - dt
		if float(segment["remaining"]) <= 0.0 or float(segment.get("hp", 0.0)) <= 0.0: continue
		var near_enemy := false
		for enemy in _nearby_enemies(Vector2(segment["pos"]), EARTH_WALL_LOWER_RANGE + float(segment["half_length"])):
			if int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
			if _barrier_blocks(segment, Vector2(enemy["pos"]), EARTH_WALL_LOWER_RANGE):
				near_enemy = true
				break
		if near_enemy:
			segment["lowered"] = true
			segment["rising"] = 0.0
		elif bool(segment.get("lowered", false)):
			# Never rise underneath the player, nor within a step of them -- being shut in by
			# something that was open ground when you committed is the outcome this exists to
			# prevent, and standing up against someone's back is the same failure by inches.
			var standing := {"pos": segment["pos"], "axis": segment["axis"], "half_length": segment["half_length"], "thickness": segment["thickness"], "hp": 1.0, "lowered": false, "layer": segment["layer"]}
			if _barrier_blocks(standing, player_pos, PLAYER_RADIUS + EARTH_WALL_RISE_CLEARANCE):
				segment["rising"] = 0.0
			else:
				# Rising is a state of its own: visible, and still passable until it finishes.
				segment["rising"] = float(segment.get("rising", 0.0)) + dt
				if float(segment["rising"]) >= EARTH_WALL_RISE_TIME:
					segment["lowered"] = false
					segment["rising"] = 0.0
		survivors.append(segment)
	barriers = survivors

# Earth is answered with the weapon. A high-impact blow takes a segment out in one; a
# light one chips, so the choice between going around, through the gap, or through the
# wall is priced rather than free.
func _strike_barriers(sample: Dictionary, impact: float) -> void:
	if barriers.is_empty(): return
	for segment in barriers:
		if bool(segment.get("lowered", false)) or float(segment.get("hp", 0.0)) <= 0.0: continue
		var axis := Vector2(segment["axis"])
		var hit := false
		for step: float in [-1.0, 0.0, 1.0]:
			var point := Vector2(segment["pos"]) + axis * (step * float(segment["half_length"]))
			if AttackGeometryScript.hits_circle(sample, point, float(segment["thickness"])):
				hit = true
				break
		if not hit: continue
		if impact >= EARTH_WALL_SHATTER_IMPACT:
			segment["hp"] = 0.0
			_add_effect("posture_break", Vector2(segment["pos"]))
			_set_message("The wall shatters.")
		else:
			segment["hp"] = maxf(0.0, float(segment["hp"]) - 3.0)
			_add_effect("hurt", Vector2(segment["pos"]), 0)

func _rouse_neighbours(spotter: Dictionary) -> void:
	for other in _nearby_enemies(Vector2(spotter["pos"]), SPOTTER_ROUSE_RADIUS):
		if int(other.get("id", -1)) == int(spotter.get("id", -2)): continue
		if int(other.get("hp", 0)) <= 0 or not _enemy_on_current_layer(other): continue
		if String(other.get("awareness", "idle")) == "alerted": continue
		other["awareness"] = "suspicious"
		other["suspicious_remaining"] = maxf(float(other.get("suspicious_remaining", 0.0)), 3.0)
		other["last_known_player"] = player_pos

func _sample_enemy_player_los(enemy: Dictionary, enemy_pos: Vector2, dt: float) -> bool:
	# Perception does not need to repeat an identical wall query at combat's
	# 120 Hz contact resolution. A 20 Hz sample remains substantially faster
	# than any enemy reaction or attack startup, and the staggered refresh keeps
	# a crowd from issuing all of its sight queries on the same simulation tick.
	var remaining := float(enemy.get("los_refresh_remaining", 0.0)) - dt
	if remaining <= 0.0:
		enemy["player_los"] = _has_line_of_sight(enemy_pos, player_pos)
		remaining = 0.042 + 0.004 * float(int(enemy["id"]) % 4)
	enemy["los_refresh_remaining"] = remaining
	return bool(enemy.get("player_los", false))

func _update_enemies(dt: float, update_locomotion: bool = true) -> void:
	_update_barriers(dt)
	_update_circle(dt)
	_update_gale_drift(dt)
	_refresh_active_enemy_cache()
	# Which casters are still standing. Anything sustained by a Chanter that is no
	# longer alive ends this tick -- collected here rather than through a death hook so
	# it cannot be missed by whichever of the several damage paths landed the kill.
	var living_chanters: Dictionary = {}
	for other in enemies:
		if String(other.get("kind", "")) == "chanter" and int(other.get("hp", 0)) > 0: living_chanters[int(other.get("id", -1))] = true
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy := enemies[index]
		# Large expedition parts may contain several encounter groups. Distant,
		# unaware groups remain frozen until the player approaches, keeping action
		# simulation proportional to the active locale rather than the whole run.
		if Vector2(enemy["pos"]).distance_to(player_pos) > 1450.0 and String(enemy.get("awareness", "idle")) == "idle": continue
		var enemy_dt := dt * _enemy_personal_tempo(enemy)
		if float(Dictionary(enemy.get("conditions", {})).get("sleep", 0.0)) > 0.0:
			enemy["action"] = _idle_action()
			enemies[index] = enemy
			continue
		enemy["smoked_remaining"] = maxf(0.0, float(enemy.get("smoked_remaining", 0.0)) - dt)
		_update_enemy_awareness(enemy, dt)
		_update_enemy_alarm(enemy, dt)
		_update_bandit_concealment(enemy, dt)
		var pounce_cooldown := float(enemy.get("pounce_cooldown", 0.0))
		if pounce_cooldown > 0.0: enemy["pounce_cooldown"] = maxf(0.0, pounce_cooldown - enemy_dt)
		var dodge_cooldown := float(enemy.get("dodge_cooldown", 0.0))
		if dodge_cooldown > 0.0: enemy["dodge_cooldown"] = maxf(0.0, dodge_cooldown - enemy_dt)
		_try_bandit_counter(enemy)
		if float(enemy.get("patience_max", 0.0)) > 0.0: _update_shield_patience(enemy, enemy_dt)
		if not Dictionary(enemy.get("chants", {})).is_empty():
			if not living_chanters.has(int(enemy.get("chant_source_id", -1))):
				enemy["chants"] = {}
				_add_effect("strain", Vector2(enemy["pos"]))
			else:
				_tick_chants(enemy, enemy_dt)
		_try_duellist_parry(enemy)
		var neutral_cooldown := float(enemy.get("neutral_cooldown", 0.0))
		if neutral_cooldown > 0.0: enemy["neutral_cooldown"] = maxf(0.0, neutral_cooldown - enemy_dt)
		var shot_cooldown := float(enemy.get("shot_cooldown", 0.0))
		if shot_cooldown > 0.0: enemy["shot_cooldown"] = maxf(0.0, shot_cooldown - enemy_dt)
		var recovery_delay := float(enemy.get("posture_recovery_delay", 0.0))
		if recovery_delay > 0.0:
			recovery_delay = maxf(0.0, recovery_delay - enemy_dt)
			enemy["posture_recovery_delay"] = recovery_delay
		var posture := float(enemy["posture"])
		var posture_max := float(enemy["posture_max"])
		if posture < posture_max and recovery_delay <= 0.0 and String(Dictionary(enemy["action"])["kind"]) not in ["hit_reaction", "stagger"]:
			enemy["posture"] = minf(posture_max, posture + enemy_dt * float(enemy.get("posture_recovery_rate", 1.8)))
		var action: Dictionary = enemy["action"]
		if String(action["kind"]) == "idle":
			var awareness := String(enemy.get("awareness", "idle"))
			if awareness == "idle":
				enemies[index] = enemy
				continue
			elif _streamed_enemy_indices.size() > 8 and (_simulation_tick_index + int(enemy["id"])) % 4 != 0:
				enemies[index] = enemy
				continue
			elif awareness == "suspicious" or stealth_remaining > 0.0:
				# Concealment used to do nothing once an enemy was already alerted.
				# `sees_player` correctly refuses to ACQUIRE a hidden player, but pursuit
				# and attack selection both read `player_pos` directly, so for the three
				# seconds of `alert_remaining` an alerted enemy tracked a hidden player
				# exactly -- "they can still see me". Then the alert lapsed and they
				# walked to a stale position instead, which is the other half of the same
				# report: "they don't follow me, but they do strike me".
				#
				# While the player is hidden every awake enemy behaves as though it is
				# merely suspicious: it goes to the last place it knew of and searches
				# there. `last_known_player` is already frozen while hidden, because
				# nothing refreshes it without sight.
				var target := Vector2(enemy.get("last_known_player", enemy["spawn_pos"]))
				if Vector2(enemy["pos"]).distance_to(target) > 45.0:
					enemy["action"] = _enemy_move_action(enemy, target, 0.40)
				else:
					# Reaching a noise source begins an actual search instead of leaving
					# the actor motionless with a zero facing vector and a permanent '?'.
					var search_facing := Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
					if search_facing.length_squared() < 0.001: search_facing = Vector2.DOWN
					var search_sign := 1.0 if int(enemy["id"]) % 2 == 0 else -1.0
					enemy["facing"] = search_facing.rotated(search_sign * dt * 1.8).normalized()
					enemies[index] = enemy
					continue
			else: _choose_enemy_action(enemy)
			action = enemy["action"]
		if String(action["kind"]) != "idle":
			# Action execution remains intentionally unchanged, but every committed
			# action now knows the shared frame and ability identity that produced it.
			action["actor_kind"] = String(enemy["kind"])
			action["weapon_frame"] = String(enemy.get("weapon_frame", "unarmed"))
			action["defense_id"] = String(enemy.get("defense_id", ""))
			if not action.has("ability_id"):
				action["ability_id"] = String(action.get("label", action.get("technique_id", action["kind"])))
			enemy["action"] = action
		action["elapsed"] = float(action["elapsed"]) + enemy_dt
		var kind := String(action["kind"])
		var elapsed := float(action["elapsed"])
		if kind not in ["move", "evade"]:
			enemy["is_moving"] = false
			enemy["last_motion"] = Vector2.ZERO
		if kind == "charge":
			# The aim follows the player through most of the wind-up and locks the
			# instant the run begins. This penalises sidestepping without touching the
			# retreat curve -- re-aiming at someone backing away does not help close a
			# gap you have not started crossing. Deliberately short of the full wind-up
			# so an early step is capped rather than erased.
			if elapsed < float(action.get("tracking_end", 0.0)):
				var aim := player_pos - Vector2(enemy["pos"])
				if aim.length_squared() > 0.01:
					action["direction"] = aim.normalized()
					enemy["facing"] = Vector2(action["direction"])
			_observe_capture(enemy, action, elapsed)
		if kind in ["move", "evade"]:
			if update_locomotion:
				var speed := _enemy_move_speed(enemy) * float(action.get("speed_multiplier", 1.0))
				_advance_enemy_locomotion(enemy, action, speed * enemy_dt * 2.0, enemy_dt * 2.0)
			# End an approach the moment it reaches its intended strike distance, so
			# the next decision happens here rather than up to a whole move action
			# later. A Blade covers 110 units inside one 0.48s move, which is what
			# turned the commit gap into a ~70-unit lottery and made the authored
			# walk-safe fraction meaningless. Mirrors the stall-abort truncation below.
			# Truncate at the intended distance itself, not at the edge of the commit
			# band. The band is tolerance for a slight overshoot, not a target: aiming
			# at its edge would put every commitment a band-width further out than the
			# authored capture values assume.
			if kind == "move":
				var intended_distance := float(enemy.get("intended_strike_distance", 0.0))
				if intended_distance > 0.0 and Vector2(enemy["pos"]).distance_to(player_pos) <= intended_distance:
					action["duration"] = minf(float(action["duration"]), float(action["elapsed"]))
		elif kind == "dodge_strike":
			# Aim the counter once, at the moment the slip ends. A lunge deliberately does
			# not steer, but a counter that swung down the line it dodged along would miss
			# by the width of the dodge -- the evasion is the commitment here, the riposte
			# is the payoff for it.
			if elapsed > float(action.get("dodge_end", 0.30)) and not bool(action.get("counter_aimed", false)):
				action["counter_aimed"] = true
				var aim := (player_pos - Vector2(enemy["pos"])).normalized()
				if aim.length_squared() > 0.001:
					action["direction"] = aim
					enemy["facing"] = aim
			if update_locomotion and elapsed <= float(action.get("dodge_end", 0.30)):
				# Locomotion runs on alternate simulation ticks, so the step is doubled to
				# keep the authored world speed correct -- see this loop's caller. Without
				# it the Bandit closed ~59 units instead of the ~117 its 390 x 0.30 implies,
				# i.e. every dodge-strike travelled at exactly half its authored speed.
				# `charge` and `pounce_combo` are not gated on this flag and were correct.
				_set_enemy_position(enemy, _move_actor(Vector2(enemy["pos"]), Vector2(action.get("dodge_direction", action["direction"])) * float(action.get("speed", 390.0)) * enemy_dt * 2.0, float(enemy["radius"]), int(enemy["id"])))
			if elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]) and not bool(action["hit_done"]): _resolve_enemy_melee_tick(enemy, elapsed)
		elif kind == "claw_combo":
			_resolve_enemy_combo_tick(enemy, elapsed)
		elif kind == "pounce_combo":
			if elapsed >= float(action["startup"]) and elapsed <= float(action["pounce_end"]):
				var pounce_origin := Vector2(enemy["pos"])
				_set_enemy_position(enemy, _move_actor(pounce_origin, Vector2(action["direction"]) * float(action.get("speed", 410.0)) * enemy_dt, float(enemy["radius"]), int(enemy["id"])))
				if not bool(action.get("pounce_hit", false)) and Vector2(enemy["pos"]).distance_to(player_pos) <= float(enemy["radius"]) + PLAYER_RADIUS + 8.0:
					action["pounce_hit"] = true
					_resolve_incoming_hit(int(enemy["id"]), int(action.get("pounce_damage", 16)), String(enemy["kind"]))
			_resolve_enemy_combo_tick(enemy, elapsed)
		elif kind == "melee":
			# Attack capture. The attacker advances along the vector it committed to,
			# which is what lets an attack reach a player who read the telegraph late.
			# Without it melee triggers at its own maximum reach and then stands still
			# through startup, so walking away works no matter when you start.
			#
			# The direction is deliberately not recomputed: the lunge travels the
			# committed line and does not steer, so an early read still escapes it and
			# the attack stays a commitment rather than a homing move.
			var advance_end := float(action.get("advance_end", 0.0))
			if update_locomotion and advance_end > 0.0 and elapsed <= advance_end:
				# Locomotion runs on alternate ticks, so the step is doubled to keep the
				# authored world distance correct. Omitting this is the half-speed trap
				# that dodge_strike sat in for several versions.
				var advance_speed := float(action.get("advance_distance", 0.0)) / advance_end
				var step := Vector2(action["direction"]) * advance_speed * enemy_dt * 2.0
				_set_enemy_position(enemy, _move_actor(Vector2(enemy["pos"]), step, float(enemy["radius"]), int(enemy["id"])))
				enemy["is_moving"] = true
				enemy["last_motion"] = step
			_observe_capture(enemy, action, elapsed)
			if elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]) and not bool(action["hit_done"]):
				_resolve_enemy_melee_tick(enemy, elapsed)
		elif kind == "charge" and elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]):
			var charge_origin := Vector2(enemy["pos"])
			var ploughs_through := bool(action.get("unstoppable", false))
			_set_enemy_position(enemy, _move_actor(charge_origin, Vector2(action["direction"]) * float(action.get("speed", 340.0)) * enemy_dt, float(enemy["radius"]), int(enemy["id"]), ploughs_through))
			if ploughs_through: _gore_allies_in_path(enemy, charge_origin, Vector2(enemy["pos"]), action)
			if Vector2(enemy["pos"]).is_equal_approx(charge_origin):
				# Released before the action is replaced -- afterwards the charge
				# dictionary and its record are already gone.
				_interrupt_enemy_action(enemy)
				enemy["action"] = _action("stagger", 0.62, Vector2.ZERO)
				enemy["posture"] = maxf(0.0, float(enemy["posture"]) - 1.0)
				_add_effect("posture_break", charge_origin)
				_set_message("The %s crashes into an obstacle." % String(enemy["kind"]))
				enemies[index] = enemy
				continue
			var cap := float(action.get("charge_cap", 0.0))
			if cap > 0.0:
				action["charge_travelled"] = float(action.get("charge_travelled", 0.0)) + charge_origin.distance_to(Vector2(enemy["pos"]))
				if float(action["charge_travelled"]) >= cap:
					# Spent. End the run here and let the recovery play out, rather than
					# letting an uncapped line cross the whole floor.
					action["active_end"] = elapsed
			if not bool(action["hit_done"]) and Vector2(enemy["pos"]).distance_to(player_pos) <= float(enemy["radius"]) + PLAYER_RADIUS + float(action.get("contact_bonus", 8.0)):
				action["hit_done"] = true
				# Charges resolve contact here rather than through the melee tick, so the
				# record has to be stamped on this path too or every landed charge would
				# finalise as a miss.
				var charge_record: Dictionary = action.get("capture_record", {})
				if not charge_record.is_empty():
					charge_record["resolution"] = "evaded" if _is_evasive() else "contact"
					action["capture_record"] = charge_record
				_resolve_incoming_hit(int(enemy["id"]), int(action.get("damage", 14)), String(enemy["kind"]), Vector2.ZERO, Vector2.INF, float(action.get("posture", -1.0)))
		elif kind == "slam" and elapsed >= float(action["startup"]) and not bool(action["hit_done"]):
			action["hit_done"] = true
			_add_effect("slam", Vector2(enemy["pos"]))
			if Vector2(enemy["pos"]).distance_to(player_pos) <= float(action.get("reach", 205.0)):
				_resolve_incoming_hit(int(enemy["id"]), int(action.get("damage", 24)), String(enemy["kind"]), Vector2.ZERO, Vector2.INF, float(action.get("posture", -1.0)))
		elif kind == "shoot" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_projectile(enemy)
		elif kind == "hurl" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_javelin(enemy)
		elif kind == "sunder" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_sundered_ground(Vector2(action.get("target", player_pos)), int(enemy["id"]), String(enemy.get("layer", current_layer)))
		elif kind == "chant" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_resolve_chant(enemy, String(action.get("label", "ward")))
		elif kind == "earth_wall" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_raise_earth_wall(Vector2(enemy["pos"]), int(enemy["id"]))
		elif kind == "gale" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_gale(enemy, Vector2(action.get("target", player_pos)))
		elif kind == "windstep" and elapsed >= float(action.get("move_start", 0.26)) and elapsed <= float(action.get("move_end", 0.58)):
			# Over bodies, never through geometry. Barriers stop it too, which is what
			# keeps Air from negating Earth outright.
			var step := Vector2(action["direction"]).normalized() * float(action.get("speed", 1250.0)) * enemy_dt
			var landing := Vector2(enemy["pos"]) + step
			if _teleport_allowed(landing, float(enemy.get("radius", ENEMY_RADIUS)), int(enemy["id"])):
				_set_enemy_position(enemy, landing)
		elif kind == "cold_front" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_cold_front(enemy, Vector2(action.get("target", player_pos)))
		elif kind == "frost_lance" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_frost_lance(enemy, Vector2(action.get("direction", enemy.get("facing", Vector2.DOWN))))
		elif kind == "fire_breath" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_fire_breath(enemy, Vector2(action.get("direction", enemy.get("facing", Vector2.DOWN))))
		if elapsed + 0.00001 >= float(action["duration"]):
			if kind in ["melee", "charge"]: _finalise_capture_record(enemy, action)
			if kind == "stagger": enemy["posture"] = float(enemy["posture_max"])
			if String(enemy.get("kind", "")) == "bandit" and kind in ["melee", "dodge_strike"]:
				enemy["neutral_cooldown"] = maxf(float(enemy.get("neutral_cooldown", 0.0)), 0.34)
			enemy["action"] = _idle_action()
		_update_enemy_bucket_membership(enemy)
		enemies[index] = enemy
	_normalize_presentation_ids()

func _update_bandit_concealment(enemy: Dictionary, world_dt: float) -> void:
	if String(enemy.get("kind", "")) != "bandit": return
	var awareness_state := String(enemy.get("awareness", "idle"))
	if awareness_state == "idle":
		enemy["revealed_to_player"] = false
		enemy["revealed_elapsed"] = 0.0
		return
	if bool(enemy.get("revealed_to_player", false)):
		enemy["revealed_elapsed"] = float(enemy.get("revealed_elapsed", 0.0)) + world_dt
		return
	var enemy_attributes := Dictionary(enemy.get("attributes", {}))
	var reveal_distance := clampf(210.0 + 30.0 * (float(player_attributes.get("awareness", 5)) - float(enemy_attributes.get("stealth", 0))), 150.0, 390.0)
	if player_pos.distance_to(Vector2(enemy["pos"])) <= reveal_distance and _has_line_of_sight(player_pos, Vector2(enemy["pos"])):
		enemy["revealed_to_player"] = true
		enemy["revealed_elapsed"] = 0.0
		_add_effect("discover", Vector2(enemy["pos"]))
		_set_message("Movement in the brush resolves into a bandit.")

func _choose_enemy_action(enemy: Dictionary) -> void:
	var offset := player_pos - Vector2(enemy["pos"])
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.01 else Vector2.DOWN
	enemy["facing"] = direction
	var authored_kind := String(enemy["kind"])
	var enemy_kind := String(CombatCatalogScript.enemy_fact(authored_kind, "ai_id"))
	if enemy_kind == "bandit" and (not bool(enemy.get("revealed_to_player", false)) or float(enemy.get("revealed_elapsed", 0.0)) < 0.35):
		enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.24)
		return
	if enemy_kind == "boar":
		# A charge's travel happens inside its damaging window, not its wind-up, so
		# Milestone C's forward travel never applied here. At the old 0.52s stationary
		# wind-up that left the Boar unable to touch a walking player from ANY launch
		# distance: the player banked 0.52 x 260 = 135 units for free, and the charge
		# only closed 158 - 114 = 44 of them back, finishing 91 units further away
		# than it started. Walking beat it unconditionally -- the exact failure
		# Milestone C existed to remove, surviving in the one kind it did not touch.
		#
		# f = 0.50 means the charge reaches contact range against a player who answers
		# at half the wind-up. Contact needs the gap to fall to the allowance (radius
		# 31 + player 20 + 8 = 59), not merely to stop growing, and the nearest this
		# may launch is 88 -- so the requirement is a 29-unit net close at the
		# midpoint: 260(S + W) - 260(phi)S - V.W = -29, giving V = (130S + 143.4)/W.
		# S = 0.40 with the 0.44s window kept intact yields V = 444.
		#
		# f varies with launch distance, because a charge commits anywhere it can
		# reach rather than at one authored strike distance the way MELEE_ATTACK_PLANS
		# entries do. 0.50 is therefore the value at the closest launch and it grows
		# more forgiving further out; the survey records the spread.
		# Genuinely large -- radius 42, rather than a 31-unit animal wearing a 40-unit
		# invisible collar. Reach now follows the silhouette, which costs the Boar real
		# denial (91 down to 70) and is worth it.
		# Slow, heavy and wide, with a short telegraph -- a slow charge is trivially
		# escaped if you also get a long look at it coming. 0.80s of travel at 360
		# covers 288 units, which out-ranges a backpedal: retreating only works if
		# begun in the first fraction of the wind-up. Sidestepping is the real answer,
		# and stays available because the body is wide rather than because the run is
		# short. Tracking below 1.0 so a step taken early is not simply erased.
		# The wind-up must outlast a player commitment or it is not a decision, and the
		# commitment is far longer than the 0.44s between combo strikes suggests:
		# measured, a single strike locks control for 0.983s, a basic attack 0.800s, a
		# held combo 2.475s. At the 0.30s this first shipped with, a charge that fired
		# mid-swing resolved entirely before control returned and the outcome was set by
		# when it happened to fire rather than by any read. 0.70 plus travel clears a
		# single strike everywhere except point-blank, where standing inside a Boar's
		# reach and committing anyway is a risk rather than an injustice.
		if float(enemy.get("pounce_cooldown", 0.0)) <= 0.0 and distance >= 88.0 and _charge_can_contact(enemy, distance, 360.0, 0.70, 1.50):
			enemy["action"] = _charge_action(1.95, 0.70, 1.50, 360.0, 5, direction)
			enemy["action"]["label"] = "pounce"
			# A charging body is wider than the circle it collides on: the shoulders carry
			# past the centre line. Without this the Boar missed a sidestep begun at the
			# instant its wind-up ended -- by 9.6 units of a 72-unit contact -- so the last
			# possible read escaped a committed line, which is the one read the design says
			# must not work. How late is late enough to survive is a tuning question and the
			# surveys own it; that a late read is punished at all is not.
			# 22 rather than the 14 that first looked sufficient: measured, a late sidestep
			# still cleared the line by 1.9 units at 14, which is a knife-edge rather than a
			# rule. At 22 the late read is caught by about 6 units and an EARLY sidestep still
			# clears by 58 -- the two answers stay far apart, which is what makes the timing a
			# decision rather than a coin toss.
			enemy["action"]["contact_bonus"] = 22.0
			enemy["action"]["momentum_armour_start"] = 0.88
			enemy["action"]["tracking_end"] = 0.70 * 0.95
			_attach_charge_capture(enemy["action"], 0.50, "pounce")
			enemy["pounce_cooldown"] = 2.40
		elif distance < 115.0:
			enemy["action"] = _action("move", 0.38, -direction)
		else: enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.48)
	elif enemy_kind == "bandit":
		if float(enemy.get("neutral_cooldown", 0.0)) > 0.0:
			var neutral_side := direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5)
			enemy["action"] = _enemy_move_action(enemy, Vector2(enemy["pos"]) + (neutral_side - direction * 0.25).normalized() * 95.0, minf(0.24, float(enemy["neutral_cooldown"])))
		elif distance <= float(_melee_intent(enemy, distance)["distance"]) + STRIKE_COMMIT_BAND and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			# The cut remains quick, but its recovery creates a real neutral window.
			# Fast identity comes from startup and footwork, not a full cycle that can
			# repeatedly beat the player sword back to readiness.
			enemy["action"] = _intent_melee_action(_melee_intent(enemy, distance), direction)
			_clear_melee_intent(enemy)
		elif float(enemy.get("dodge_cooldown", 0.0)) <= 0.0 and distance < 155.0:
			var evade_direction := (-direction + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 0.45).normalized()
			enemy["action"] = _action("evade", 0.38, evade_direction)
			enemy["action"]["speed_multiplier"] = 1.55
			enemy["dodge_cooldown"] = 1.45
		else: enemy["action"] = _enemy_move_action(enemy, _approach_target(enemy, float(_melee_intent(enemy, distance)["distance"])), 0.32)
	elif enemy_kind == "blade":
		var blade_intent := _melee_intent(enemy, distance)
		if distance <= float(blade_intent["distance"]) + STRIKE_COMMIT_BAND and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _intent_melee_action(blade_intent, direction)
			_clear_melee_intent(enemy)
		else:
			enemy["action"] = _enemy_move_action(enemy, _approach_target(enemy, float(blade_intent["distance"])), 0.48)
	elif enemy_kind == "knife":
		var knife_intent := _melee_intent(enemy, distance)
		if distance <= float(knife_intent["distance"]) + STRIKE_COMMIT_BAND and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _intent_melee_action(knife_intent, direction)
			_clear_melee_intent(enemy)
		else:
			enemy["action"] = _enemy_move_action(enemy, _approach_target(enemy, float(knife_intent["distance"])), 0.32)
	elif enemy_kind == "polearm":
		# The shaft cut answers a player who walks through the point; the long thrust
		# remains the spear identity. Which one it commits to is now chosen before the
		# approach rather than falling out of branch order, so both actually occur
		# instead of the thrust always winning by being tested at the greater distance.
		var polearm_intent := _melee_intent(enemy, distance)
		# Reach holds now. The thrust used to carry 229 units of authored forward travel
		# -- more than its own 218 reach -- so committing at 218 always ended with the
		# spear in melee and the Polearm fought like a slow Blade. That travel was not a
		# mistake: at a 0.90s wind-up against a 260/s walk the player clears 234 units,
		# so without the lunge the attack could never land at all. Shortening the wind-up
		# to 0.42 is what let the travel come down to 60.
		#
		# What it buys is a reach enemy that behaves like one. A free player walks out of
		# the thrust and should; a player locked into a combo cannot, and wears it. So it
		# throws the spear at LATENESS rather than at range -- the same read the Shield
		# uses -- which is what "strike from behind other enemies" actually means.
		# Inside the point, the shaft cut is the answer -- not a 205-unit thrust thrown at
		# someone standing on top of you. Weighted selection alone kept picking the thrust
		# at 105 units (1.7 against 1.0) and it went 0 for 5 across the 0.2.33 run, because
		# a thrust authored for 205 is trivially walked out of from half that distance.
		# Distance decides which attack, not a weighted roll. The roll could hand a reach
		# enemy the shaft-cut intent while it stood at range -- and the reach role refuses
		# to approach inside its hold distance, so it could never satisfy that intent and
		# simply walked forever. Measured: a Polearm stuck at 194.6 units with clear line
		# of sight, holding an intent that required 116.
		var polearm_short: Dictionary = _plan_option("polearm", "reverse_cut")
		var polearm_long: Dictionary = _plan_option("polearm", "thrust")
		if not polearm_short.is_empty() and distance <= float(polearm_short["distance"]) + STRIKE_COMMIT_BAND:
			polearm_intent = polearm_short
		elif not polearm_long.is_empty():
			polearm_intent = polearm_long
		var polearm_in_band := distance <= float(polearm_intent["distance"]) + STRIKE_COMMIT_BAND
		# The long thrust is still gated on lateness; the short cut is not, because at
		# that range there is nothing to be late for.
		var polearm_can_convert := String(polearm_intent["technique"]) != "thrust" or _player_commitment_remaining() >= float(polearm_intent["startup"]) * 0.60
		if polearm_in_band and polearm_can_convert and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _intent_melee_action(polearm_intent, direction)
			_clear_melee_intent(enemy)
		else:
			enemy["action"] = _enemy_move_action(enemy, _approach_target(enemy, float(polearm_intent["distance"])), 0.70)
	elif enemy_kind == "shield":
		# A screen denies access; its sword is the exception, not the job. The 0.2.30
		# survey caught it swinging nine times in one room off a proximity gate, which
		# is a trigger the player can pull at will by stepping in and out.
		var shield_intent := _melee_intent(enemy, distance)
		var ward := _ally_anchor(enemy, ["ranged_pressure", "area_denial", "reach"])
		var guarding := not ward.is_equal_approx(player_pos)
		var sees_player := _has_line_of_sight(Vector2(enemy["pos"]), player_pos)
		var in_guard := distance <= SHIELD_GUARD_RADIUS and sees_player
		if distance <= float(shield_intent["distance"]) + STRIKE_COMMIT_BAND and sees_player and _shield_wants_to_strike(enemy, in_guard, guarding):
			enemy["action"] = _intent_melee_action(shield_intent, direction)
			_clear_melee_intent(enemy)
			# It got what it was waiting for. Composure returns whether or not the swing
			# connects, so one read cannot cascade into a chain of free ones.
			enemy["patience"] = float(enemy.get("patience_max", 0.0))
		elif guarding:
			enemy["action"] = _enemy_move_action(enemy, _shield_station(ward), 0.58)
		else:
			# Nothing left to guard. A screen with no ward is just a defensive frontliner;
			# holding a line to nowhere would stall the last enemy alive.
			enemy["action"] = _enemy_move_action(enemy, _approach_target(enemy, float(shield_intent["distance"])), 0.58)
	elif enemy_kind == "ox":
		# The Ox asks a different question from every other attack in the game. Theirs
		# is radial -- am I close enough. This one is lateral: am I on its line. It
		# commits from any distance with line of sight and runs until it hits the
		# player, hits a wall, or exhausts its cap, so there is no safe range, only a
		# safe bearing. Its body is far too wide to walk out of and just narrow enough
		# to Dodge out of, which makes the evasive action the answer rather than an
		# alternative to footwork.
		# Derived from its own body rather than a constant. At radius 76 the Ox could
		# not physically stand further than 96 units away, so a hardcoded 120-unit
		# floor meant it walked up and never charged again -- two gores in 36 seconds
		# in the 0.2.28 survey. Changing the silhouette must not disarm the attack.
		if float(enemy.get("pounce_cooldown", 0.0)) <= 0.0 and distance >= float(enemy["radius"]) + PLAYER_RADIUS + OX_CHARGE_MIN_GAP and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _charge_action(OX_CHARGE_DURATION, OX_CHARGE_STARTUP, OX_CHARGE_ACTIVE_END, OX_CHARGE_SPEED, 7, direction)
			enemy["action"]["label"] = "gore"
			enemy["action"]["tracking_end"] = OX_CHARGE_STARTUP * 0.90
			enemy["action"]["charge_cap"] = OX_CHARGE_CAP
			enemy["action"]["charge_travelled"] = 0.0
			# Nothing short of a killing blow stops it once it is moving.
			enemy["action"]["unstoppable"] = true
			_attach_charge_capture(enemy["action"], 0.50, "gore")
			enemy["pounce_cooldown"] = 3.20
		elif float(enemy.get("pounce_cooldown", 0.0)) <= 0.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			# Ready, but standing inside its own minimum range. Walking toward the player
			# can never restore the gap a charge needs, so the 0.2.30 Ox landed four gores
			# and then milled about in strike range being hit -- "he starts getting
			# confused and not knowing what to do".
			#
			# Backing out is itself a charge, deliberately: mass 2.4 clears
			# HEAVY_TELEGRAPH_MASS, so the reverse wind-up carries the same armour the
			# gore does and the escape cannot be stunlocked out of existence. Capped, so
			# it reopens a lane instead of becoming the Hound's unbounded retreat, which
			# measured 495 units. A cornered Ox still crashes into the wall behind it.
			var reset_end := OX_DISENGAGE_STARTUP + OX_DISENGAGE_CAP / OX_DISENGAGE_SPEED
			enemy["action"] = _charge_action(reset_end + 0.20, OX_DISENGAGE_STARTUP, reset_end, OX_DISENGAGE_SPEED, 0, -direction)
			enemy["action"]["label"] = "reset"
			enemy["action"]["charge_cap"] = OX_DISENGAGE_CAP
			enemy["action"]["charge_travelled"] = 0.0
			# A disengage has no contact window; it must never resolve a hit on the way out.
			enemy["action"]["hit_done"] = true
		else: enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.62)
	elif enemy_kind == "hound":
		if float(enemy.get("pounce_cooldown", 0.0)) <= 0.0 and distance >= 88.0 and _charge_can_contact(enemy, distance, 500.0, 0.70, 1.08):
			# The Boar's opposite. The difference that matters is not speed but how many
			# decisions the telegraph affords: movement resolves in 0.131s steps, so a
			# Matched to the Boar's 0.70s. At 0.55 a committed player was caught even at
			# 220 -- "you can never be busy near a Hound" is not a decision, it is a
			# constraint, and the information arrived after the commitment that triggered
			# it. Differentiation lives in damage, body width, speed and re-charge
			# cadence instead, all of which are visible before you commit. Commit
			# the Dodge on first sight or wear it -- but it costs 2 rather than 5, and
			# the narrow body leaves a sidestep genuinely available at range.
			enemy["action"] = _charge_action(1.58, 0.70, 1.08, 500.0, 2, direction)
			enemy["action"]["label"] = "pounce"
			enemy["action"]["tracking_end"] = 0.70 * 0.85
			# A charge's effective walk-safe fraction is dominated by launch distance
			# rather than by timing: at 90 nothing but a Dodge answers either animal, at
			# 220 everything does. 0.50 is the mid-range intent both are authored to, and
			# the survey records how far the observed spread departs from it.
			_attach_charge_capture(enemy["action"], 0.50, "pounce")
			enemy["pounce_cooldown"] = 1.78
		elif float(enemy.get("pounce_cooldown", 0.0)) > 0.0:
			var retreat := (-direction + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 0.58).normalized()
			enemy["action"] = _action("evade", 0.32, retreat)
			enemy["action"]["speed_multiplier"] = 1.48
			# A retreat must not feed straight back into a charge. The Bandit already
			# gates this with a 2.0s dodge_strike cooldown; without it the Hound slips a
			# committed strike and is mid-wind-up before the player recovers from it --
			# a whole evade-and-counter inside one 0.983s commitment, which makes
			# swinging at a Hound strictly a mistake.
			# Applied on ENTERING the evade only. This branch runs while the cooldown is
			# already above zero, so re-arming it every decision made the gate feed
			# itself and the Hound retreated indefinitely -- measured at a mean 495
			# units from the player, half a screen, for a flanker.
			if String(Dictionary(enemy.get("action", {})).get("kind", "")) != "evade":
				enemy["pounce_cooldown"] = maxf(float(enemy["pounce_cooldown"]), 0.32 + HOUND_NEUTRAL_AFTER_EVADE)
		else: enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.34)
	elif enemy_kind == "brute":
		var brute_intent := _melee_intent(enemy, distance)
		if distance <= float(brute_intent["distance"]) + STRIKE_COMMIT_BAND and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _intent_melee_action(brute_intent, direction)
			_clear_melee_intent(enemy)
		else: enemy["action"] = _enemy_move_action(enemy, _approach_target(enemy, float(brute_intent["distance"])), 0.78)
	elif enemy_kind == "chanter":
		# Order of business for a support unit: get behind something, then work. Reaching it
		# still finishes it -- that is the price it pays for being worth reaching -- but as
		# of 0.2.59 it is no longer literally defenceless, because "walks backward forever
		# and never contests anything" was not a price, it was an absence.
		var chant_allies := _chant_targets(enemy)
		if not _chanter_is_screened(enemy, chant_allies) or distance < 240.0:
			if distance <= STAFF_POKE_RANGE * 0.72 and _try_staff_poke(enemy, distance, direction): pass
			else: enemy["action"] = _enemy_move_action(enemy, _chanter_retreat_target(enemy, chant_allies), 0.42)
		elif float(enemy.get("shot_cooldown", 0.0)) <= 0.0 and not chant_allies.is_empty():
			var chant := _choose_chant(chant_allies)
			enemy["action"] = _action("chant", CHANT_STARTUP + 0.46, direction)
			enemy["action"]["startup"] = CHANT_STARTUP
			enemy["action"]["label"] = chant
			enemy["shot_cooldown"] = CHANT_COOLDOWN
		else:
			enemy["action"] = _enemy_move_action(enemy, _chanter_retreat_target(enemy, chant_allies), 0.42)
	elif enemy_kind == "javelineer":
		# Slower than an Archer and far easier to sidestep. That is not a weakness to be
		# corrected: while the javelin is in the air one lane is unavailable, so what it
		# actually spends is the player's choice of direction. Alone it is nearly
		# harmless; behind a frontliner who already dictates where you can stand, it
		# collects.
		if float(enemy.get("shot_cooldown", 0.0)) <= 0.0 and distance <= 720.0 and distance >= 190.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			# Aimed here, at the announcement, rather than at release. Computing the lead
			# when the javelin left the hand let the thrower face the player through the
			# whole wind-up and then throw somewhere else -- no telegraph, and a shot that
			# could not be read. Committing the line up front makes it the same kind of
			# promise every other attack in this game makes.
			enemy["action"] = _action("hurl", 1.46, _javelin_lead(enemy))
			enemy["action"]["startup"] = 0.86
			enemy["facing"] = Vector2(enemy["action"]["direction"])
			enemy["shot_cooldown"] = 2.30 + 0.20 * float(int(enemy["id"]) % 3)
		else:
			enemy["action"] = _enemy_move_action(enemy, _archer_support_target(enemy, direction, distance), 0.52)
	elif enemy_kind == "air_caster":
		# Control the fight or survive it. Cornered, it goes; with room, it rearranges the
		# room. Windstep is the same escape the Elementalist will get -- over bodies, never
		# through walls or barriers, because Air moves you through the crowd and not
		# through the world.
		if distance <= 190.0 and float(enemy.get("pounce_cooldown", 0.0)) <= 0.0:
			enemy["action"] = _enemy_ability_action("windstep", -direction)
			enemy["action"]["move_start"] = 0.26
			enemy["action"]["move_end"] = 0.58
			enemy["action"]["speed"] = 1250.0
			enemy["pounce_cooldown"] = 4.60
		elif distance <= STAFF_POKE_RANGE and _try_staff_poke(enemy, distance, direction): pass
		elif float(enemy.get("shot_cooldown", 0.0)) <= 0.0 and distance <= 640.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _enemy_ability_action("gale", direction)
			# Placed between itself and the player, so the blast shoves the player back and
			# any shot crossing that space is spoiled on the way through.
			enemy["action"]["target"] = Vector2(enemy["pos"]).lerp(player_pos, 0.62)
			enemy["shot_cooldown"] = 5.20
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.48)
	elif enemy_kind == "earth_caster":
		# The poke is checked first only at contact range, which STAFF_POKE_RANGE already
		# enforces -- beyond it the call returns false and the ground work proceeds.
		# It never aims at where you are. Ground you are standing on is ground you have
		# already spent; the cut that matters is between you and where you want to be.
		if _try_staff_poke(enemy, distance, direction): pass
		elif float(enemy.get("shot_cooldown", 0.0)) <= 0.0 and distance <= 640.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			# Slow or block -- the element's decision. The wall goes up when the player is
			# far enough away for cutting the retreat to mean something; up close there is
			# no retreat to cut, so the ground opens instead.
			if barriers.is_empty() and distance >= 300.0:
				enemy["action"] = _enemy_ability_action("earth_wall", direction)
				enemy["shot_cooldown"] = 6.40
			else:
				enemy["action"] = _enemy_ability_action("sunder", direction)
				enemy["action"]["target"] = _sunder_target(enemy)
				enemy["shot_cooldown"] = 4.20
		else:
			enemy["action"] = _enemy_move_action(enemy, _archer_support_target(enemy, direction, distance), 0.52)
	elif enemy_kind == "duellist":
		# It reads a swing the way the Bandit does, but it answers by standing still and
		# taking your turn rather than by relocating. The parry itself lives in
		# _try_duellist_parry; this branch is only its ordinary footwork and attacks.
		var duellist_intent := _melee_intent(enemy, distance)
		if distance <= float(duellist_intent["distance"]) + STRIKE_COMMIT_BAND and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _intent_melee_action(duellist_intent, direction)
			_clear_melee_intent(enemy)
		else: enemy["action"] = _enemy_move_action(enemy, _approach_target(enemy, float(duellist_intent["distance"])), 0.40)
	elif enemy_kind == "ice_caster":
		if distance <= 310.0 and float(enemy.get("shot_cooldown", 0.0)) <= 0.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			# Close in, the front: wide and repeating, so backing off is not enough.
			enemy["action"] = _enemy_ability_action("cold_front", direction)
			enemy["action"]["target"] = player_pos + player_facing * 40.0
			enemy["shot_cooldown"] = 3.40
		elif _try_staff_poke(enemy, distance, direction): pass
		elif distance <= 650.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _enemy_ability_action("frost_lance", direction)
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.48)
	elif enemy_kind == "fire_caster":
		if distance <= 250.0 and float(enemy.get("shot_cooldown", 0.0)) <= 0.0:
			enemy["action"] = _enemy_ability_action("fire_breath", direction)
			enemy["shot_cooldown"] = 3.00
		elif _try_staff_poke(enemy, distance, direction): pass
		elif distance <= 670.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _enemy_ability_action("fireball", direction)
		else:
			var fire_target := Vector2(enemy["pos"]) + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 210.0 if distance < 480.0 else player_pos
			enemy["action"] = _enemy_move_action(enemy, fire_target, 0.48)
	elif enemy_kind == "archer":
		if float(enemy.get("shot_cooldown", 0.0)) <= 0.0 and distance <= 690.0 and distance >= 235.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			# ~2.7s between shots was not pressure, it was weather. The 0.2.30 survey
			# scored every room carrying ranged pressure at 3.33/5 against 1.71 for
			# melee-only rooms, and the Archer was the only ranged enemy in all of them.
			# The thing carrying the good rooms should actually push.
			# 0.2.30 was right that ~2.7s between shots is weather rather than pressure, and
			# 0.2.33 overcorrected: at 0.46 startup a shot begun the instant the player
			# commits lands well inside a 0.983s strike lockout, every time, so the answer
			# was "never attack" rather than a decision. Sat between the two.
			enemy["action"] = _action("shoot", 1.30, direction)
			enemy["action"]["startup"] = 0.60
			enemy["shot_cooldown"] = 0.86 + 0.15 * float(int(enemy["id"]) % 3)
		else:
			enemy["action"] = _enemy_move_action(enemy, _archer_support_target(enemy, direction, distance), 0.52)
	elif enemy_kind == "knight":
		var knight_intent := _melee_intent(enemy, distance)
		if distance <= float(knight_intent["distance"]) + STRIKE_COMMIT_BAND and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _intent_melee_action(knight_intent, direction)
			_clear_melee_intent(enemy)
		else: enemy["action"] = _enemy_move_action(enemy, _approach_target(enemy, float(knight_intent["distance"])), 0.72)
	elif enemy_kind == "werewolf":
		if float(enemy.get("pounce_cooldown", 0.0)) <= 0.0 and distance >= 165.0 and _charge_can_contact(enemy, distance, 420.0, 0.34, 0.76):
			if rng.randf() < 0.55: enemy["action"] = _werewolf_pounce_combo(direction)
			else:
				enemy["action"] = _charge_action(1.42, 0.34, 0.78, 430.0, 4, direction)
				enemy["action"]["label"] = "pounce"
			enemy["pounce_cooldown"] = 1.72
		elif distance <= 148.0:
			enemy["action"] = _werewolf_claw_combo(direction)
		elif float(enemy.get("pounce_cooldown", 0.0)) > 0.0:
			var wolf_retreat := (-direction + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 0.46).normalized()
			enemy["action"] = _action("evade", 0.34, wolf_retreat)
			enemy["action"]["speed_multiplier"] = 1.34
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.36)
	elif enemy_kind == "warden":
		if distance <= 215.0:
			if rng.randf() < 0.46:
				enemy["action"] = _action("slam", 2.45, direction)
				enemy["action"]["startup"] = 1.02
				enemy["action"]["active_end"] = 1.22
				enemy["action"]["reach"] = 215.0
				enemy["action"]["damage"] = 4
			else: enemy["action"] = _melee_action(2.15, 0.76, 1.30, 205.0, 4, direction, "heavy_cleave")
		elif distance <= 520.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _charge_action(1.80, 0.62, 1.05, 300.0, 4, direction)
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.72)
	else:
		if distance <= 690.0 and distance >= 230.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("shoot", 1.75, direction)
			enemy["action"]["startup"] = 0.72
		else:
			var move_target := player_pos if distance > 520.0 else Vector2(enemy["pos"]) - direction * 240.0
			enemy["action"] = _enemy_move_action(enemy, move_target, 0.56)

# A caster reached used to be a stationary object: every one of them either retreated,
# cast something it could not cast at that range, or simply stood there. That made closing
# on a caster a formality rather than a decision, which is the opposite of what the
# formation work in 0.2.41 was for -- screening only means something if getting past the
# screen still costs you.
#
# The answer is one weak melee attack, shared by all five, gated on the caster's real verbs
# being unavailable. It is not an attack a caster wants to make.
const STAFF_POKE_RANGE := 176.0
const STAFF_POKE_COOLDOWN := 2.30

func _try_staff_poke(enemy: Dictionary, distance: float, direction: Vector2) -> bool:
	if distance > STAFF_POKE_RANGE: return false
	if float(enemy.get("neutral_cooldown", 0.0)) > 0.0: return false
	if not _has_line_of_sight(Vector2(enemy["pos"]), player_pos): return false
	var poke := _plan_option(String(enemy["kind"]), "staff_poke")
	if poke.is_empty(): return false
	enemy["action"] = _intent_melee_action(poke, direction)
	enemy["neutral_cooldown"] = STAFF_POKE_COOLDOWN
	return true

func _plan_option(kind: String, technique: String) -> Dictionary:
	for option_value in CombatCatalogScript.melee_attack_plan(kind):
		var option := Dictionary(option_value)
		if String(option["technique"]) == technique: return option
	return {}

func _melee_intent(enemy: Dictionary, gap: float) -> Dictionary:
	# An enemy carries its chosen attack across the whole approach so it walks to a
	# stable distance instead of re-rolling every decision and oscillating. The
	# intent is dropped when it is spent, when the enemy is interrupted, or when the
	# player closes far enough inside it that honouring it would mean backing away.
	var plan := CombatCatalogScript.melee_attack_plan(String(enemy["kind"]))
	if plan.is_empty(): return {}
	var current := String(enemy.get("intended_attack", ""))
	if not current.is_empty():
		for option_value in plan:
			var option := Dictionary(option_value)
			if String(option["technique"]) != current: continue
			if gap >= float(option["distance"]) - STRIKE_INTENT_ABANDON_MARGIN: return option
			break
	var weights: Array[float] = []
	var total := 0.0
	for option_value in plan:
		var option := Dictionary(option_value)
		# Range affinity: 1.0 at a perfect match, halving every softness unit away.
		var offset := absf(gap - float(option["distance"])) / STRIKE_SELECTION_SOFTNESS
		var weight := maxf(0.0001, float(option.get("weight", 1.0))) / (1.0 + offset * offset)
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	var chosen := Dictionary(plan[plan.size() - 1])
	for index in plan.size():
		roll -= weights[index]
		if roll <= 0.0:
			chosen = Dictionary(plan[index])
			break
	enemy["intended_attack"] = String(chosen["technique"])
	enemy["intended_strike_distance"] = float(chosen["distance"])
	return chosen

# Records what actually happened to one hostile attack. Gated on Combat Survey:
# these are report instruments, and sampling attack geometry every active frame
# is not worth the cost in ordinary play.
func _observe_capture(enemy: Dictionary, action: Dictionary, elapsed: float) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY: return
	var record: Dictionary = action.get("capture_record", {})
	if record.is_empty(): return
	if float(record["gap"]) < 0.0:
		record["gap"] = Vector2(enemy["pos"]).distance_to(player_pos)
	# The response is the player's first commitment after this attack became
	# readable. Bucketing it as a fraction of startup is the only measurement that
	# separates "walking is overpowered" from "the player read the attack well".
	if float(record["response_at"]) < 0.0:
		var player_kind := String(player_action.get("kind", "idle"))
		var started := float(player_action.get("started_at", -1.0))
		# A flinch is not a decision. Counting hit_reaction or stagger as the response
		# would score a player who never chose anything as reacting instantly.
		if player_kind not in ["idle", "hit_reaction", "stagger"] and started >= float(record["committed_at"]):
			record["response_at"] = maxf(0.0, started - float(record["committed_at"]))
			record["response"] = player_kind
	# How near the attack came during its damaging window. This is what tunes `f`:
	# a miss by two units and a miss by ninety are different design problems.
	if elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]):
		if String(action.get("kind", "")) == "charge":
			# A charge has no swept footprint. Its contact test is proximity against
			# the same allowance the charge branch uses, so that is the honest measure.
			var allowance := float(enemy.get("radius", ENEMY_RADIUS)) + PLAYER_RADIUS + float(action.get("contact_bonus", 8.0))
			record["closest"] = minf(float(record["closest"]), Vector2(enemy["pos"]).distance_to(player_pos) - allowance)
			action["capture_record"] = record
			return
		var sample: Dictionary = AttackGeometryScript.pose(action, Vector2(enemy["pos"]),
			Vector2(action.get("direction", enemy["facing"])),
			_nearby_walls(Vector2(enemy["pos"]), float(action.get("reach", 220.0)) + 90.0))
		record["closest"] = minf(float(record["closest"]), AttackGeometryScript.clearance_to_circle(sample, player_pos, PLAYER_RADIUS))
	action["capture_record"] = record

# An attack the player cuts down never reaches its own duration, so the branch
# that finalises capture records at completion never sees it. Every path that
# replaces a live action has to release the record here, or the survey counts
# only the attacks the player failed to pre-empt -- the population most likely to
# have landed. Measured: the 0.2.18 survey reported 11 resolved attacks while its
# own strike log showed at least 20 melee commitments in the same rooms.
# Charges carry capture records too. Their travel sits inside the damaging window
# rather than the wind-up, so `f` means the same thing -- the fraction of the
# telegraph during which walking still saves you -- but is authored rather than
# derived from forward travel, which the charge already owns.
func _attach_charge_capture(action: Dictionary, authored_f: float, technique: String) -> void:
	action["capture_record"] = {
		"technique": technique,
		"authored_f": authored_f,
		"committed_at": simulation_time,
		"gap": -1.0,
		"response_at": -1.0,
		"response": "",
		"closest": INF,
		"resolution": "",
	}

func _interrupt_enemy_action(enemy: Dictionary, interrupter: String = "player", tool: String = "") -> void:
	var action: Dictionary = enemy.get("action", {})
	var interrupted_kind := String(action.get("kind", "idle"))
	if mode_id == ModeRulesScript.COMBAT_SURVEY and interrupted_kind in ENEMY_ATTACK_ACTION_KINDS:
		var tool_id := tool
		if tool_id.is_empty(): tool_id = String(player_action.get("ability_id", player_action.get("kind", "unknown")))
		survey_interruption_events.append({
			"enemy_id": int(enemy.get("id", -1)),
			"enemy_kind": String(enemy.get("kind", "unknown")),
			"interrupted_action": interrupted_kind,
			"interrupter": interrupter,
			"tool": tool_id,
			"at": simulation_time,
		})
	if String(action.get("kind", "")) in ["melee", "charge"]:
		_finalise_capture_record(enemy, action, true)

func _finalise_capture_record(enemy: Dictionary, action: Dictionary, interrupted: bool = false) -> void:
	var record: Dictionary = action.get("capture_record", {})
	if record.is_empty(): return
	action.erase("capture_record")
	if mode_id != ModeRulesScript.COMBAT_SURVEY: return
	if interrupted and String(record.get("resolution", "")).is_empty():
		record["resolution"] = "interrupted"
		# Where in the wind-up the answer landed. Below 1.0 means the attack was
		# cut down before its damaging window ever opened.
		record["interrupted_at_f"] = float(action.get("elapsed", 0.0)) / maxf(0.001, float(action.get("startup", 0.30)))
	if String(record.get("resolution", "")).is_empty(): record["resolution"] = "miss"
	record["enemy"] = String(enemy.get("kind", "unknown"))
	# f_observed = response_at / startup measures PLAYER RESPONSE LATENCY, and frost slows
	# the player's whole action. So a frosted player reads as a late player, and without
	# this every frosted room would quietly lie about capture timing.
	record["player_frost"] = player_frost_fraction()
	record["arena"] = String(survey_room_definition.get("arena", "unknown"))
	var startup := maxf(0.001, float(action.get("startup", 0.30)))
	# -1 means the player never committed anything while the attack ran.
	record["f_observed"] = (float(record["response_at"]) / startup) if float(record["response_at"]) >= 0.0 else -1.0
	if is_inf(float(record["closest"])): record["closest"] = 9999.0
	survey_attack_records.append(record)

# Collapses this room's attack records into the numbers that answer whether
# capture is working: how often walking alone was enough, and how the achieved
# walk-safe fraction compares with the authored intent.
func _survey_capture_summary() -> Dictionary:
	var per_attack := {}
	var resolved := 0
	var walk_escapes := 0
	var walk_attempts := 0
	var interrupted := 0
	var pre_empted := 0
	for record_value in survey_attack_records:
		var record := Dictionary(record_value)
		resolved += 1
		var label := "%s %s" % [record.get("enemy", "?"), record.get("technique", "?")]
		if not per_attack.has(label):
			per_attack[label] = {"n": 0, "contact": 0, "evaded": 0, "miss": 0, "interrupted": 0, "authored_f": float(record.get("authored_f", 0.0)), "f_sum": 0.0, "f_n": 0, "closest_sum": 0.0, "closest_n": 0}
		var bucket: Dictionary = per_attack[label]
		bucket["n"] = int(bucket["n"]) + 1
		var resolution := String(record.get("resolution", "miss"))
		bucket[resolution] = int(bucket.get(resolution, 0)) + 1
		if resolution == "interrupted":
			interrupted += 1
			# Cut down before the damaging window opened, rather than merely
			# staggered out of a swing that had already committed.
			if float(record.get("interrupted_at_f", 9.0)) < 1.0: pre_empted += 1
		# 9999 is the never-sampled sentinel. An attack cut down before its damaging
		# window has no closest approach to report, and averaging the sentinel in
		# destroyed the mean -- 0.2.20 printed closest values of 4994 and 1401.
		var closest := float(record.get("closest", 9999.0))
		if closest < 9000.0:
			bucket["closest_sum"] = float(bucket["closest_sum"]) + closest
			bucket["closest_n"] = int(bucket["closest_n"]) + 1
		var observed := float(record.get("f_observed", -1.0))
		if observed >= 0.0:
			bucket["f_sum"] = float(bucket["f_sum"]) + observed
			bucket["f_n"] = int(bucket["f_n"]) + 1
		# Walking alone means the only response committed was ordinary movement.
		if String(record.get("response", "")) == "move":
			walk_attempts += 1
			if resolution == "miss": walk_escapes += 1
	var rows := []
	for label in per_attack.keys():
		var bucket: Dictionary = per_attack[label]
		var count := maxi(1, int(bucket["n"]))
		rows.append({
			"attack": label,
			"n": int(bucket["n"]),
			"contact": int(bucket.get("contact", 0)),
			"evaded": int(bucket.get("evaded", 0)),
			"miss": int(bucket.get("miss", 0)),
			"interrupted": int(bucket.get("interrupted", 0)),
			"authored_f": float(bucket["authored_f"]),
			"observed_f": (float(bucket["f_sum"]) / float(maxi(1, int(bucket["f_n"])))) if int(bucket["f_n"]) > 0 else -1.0,
			"closest": (float(bucket["closest_sum"]) / float(maxi(1, int(bucket["closest_n"])))) if int(bucket["closest_n"]) > 0 else 0.0,
			"closest_samples": int(bucket["closest_n"]),
		})
	rows.sort_custom(func(a, b): return String(a["attack"]) < String(b["attack"]))
	return {
		"resolved": resolved,
		"interrupted": interrupted,
		"pre_empted": pre_empted,
		"walk_only_attempts": walk_attempts,
		"walk_only_escapes": walk_escapes,
		"walk_only_escape_rate": (float(walk_escapes) / float(walk_attempts)) if walk_attempts > 0 else -1.0,
		"attacks": rows,
	}

func _clear_melee_intent(enemy: Dictionary) -> void:
	enemy["intended_attack"] = ""
	enemy["intended_strike_distance"] = 0.0

func _intent_melee_action(option: Dictionary, direction: Vector2) -> Dictionary:
	var action := _melee_action(float(option["duration"]), float(option["startup"]), float(option["active_end"]),
		float(option["reach"]), int(option["damage"]), direction, String(option["technique"]))
	# Forward travel is carried on the action so the melee branch can apply it
	# without consulting the catalogue every tick. Defaults of zero mean any attack
	# built outside a plan keeps its current standing-still behaviour.
	action["advance_distance"] = float(option.get("advance_distance", 0.0))
	action["advance_end"] = float(option.get("advance_end", 0.0))
	action["capture_record"] = {
		"technique": String(option["technique"]),
		"authored_f": float(option.get("f_rad", 0.0)),
		"committed_at": simulation_time,
		"gap": -1.0,
		"response_at": -1.0,
		"response": "",
		"closest": INF,
		"resolution": "",
	}
	return action

func _approach_target(enemy: Dictionary, strike_distance: float) -> Vector2:
	# Walk to a ring at the intended strike distance around the pursuit anchor
	# rather than into the player's body. The anchor keeps the existing lead and
	# lane behaviour, so flankers still reserve separate approach corridors.
	var role := _enemy_role(enemy)
	if role in ANCHORED_ROLES:
		# These roles hold a bearing rather than orbit the player. Orbiting the anchor
		# would put a frontliner a whole strike distance BEHIND the line it is meant
		# to hold, which is how the first cut of this measured 199 units out when it
		# was aiming for 88.
		#
		# Reach additionally refuses to approach inside its hold distance. Its short
		# attack exists to answer a player who walks onto the point, not to be walked
		# to: approaching at the selected intent's distance let one reverse-cut roll
		# pull the Polearm to 112, where the same roll became overwhelmingly likely
		# and it never came back out.
		var stand := strike_distance
		if role == "reach": stand = maxf(stand, float(ROLE_HOLD_DISTANCE[role]))
		return player_pos + _role_bearing(enemy, role) * stand
	var anchor := _pursuit_target(enemy)
	var outward := Vector2(enemy["pos"]) - anchor
	if outward.length_squared() < 0.001: outward = Vector2(enemy["pos"]) - player_pos
	if outward.length_squared() < 0.001: outward = Vector2.RIGHT
	return anchor + outward.normalized() * strike_distance

func _enemy_move_action(enemy: Dictionary, target: Vector2, duration: float) -> Dictionary:
	var result := _action("move", duration, _navigation_direction(enemy, target))
	result["target"] = target
	result["moving"] = false
	result["steer_elapsed"] = 0.0
	result["recovery_elapsed"] = 0.0
	return result

func _charge_can_contact(enemy: Dictionary, distance: float, speed: float, startup: float, active_end: float) -> bool:
	if not _has_line_of_sight(Vector2(enemy["pos"]), player_pos): return false
	var contact_allowance := float(enemy.get("radius", ENEMY_RADIUS)) + PLAYER_RADIUS + 18.0
	return distance <= speed * maxf(0.0, active_end - startup) + contact_allowance

func _heavy_intercept_target(_enemy: Dictionary) -> Vector2:
	# Slow heavies aim for the player's lane instead of following the exact current
	# point forever. They remain slow, but can occupy space and protect a back line.
	var lead := player_facing.normalized() * 64.0
	if String(player_action.get("kind", "idle")) == "move":
		lead = Vector2(player_action.get("direction", player_facing)).normalized() * 92.0
	return player_pos + lead

func _advance_enemy_locomotion(enemy: Dictionary, action: Dictionary, step_distance: float, stall_dt: float) -> void:
	var origin := Vector2(enemy["pos"])
	var direction := Vector2(action.get("direction", Vector2.ZERO)).normalized()
	if String(action.get("kind", "")) == "move":
		if action.has("target"):
			action["steer_elapsed"] = float(action.get("steer_elapsed", 0.0)) + stall_dt
			if direction.length_squared() < 0.001 or float(action["steer_elapsed"]) >= ENEMY_STEER_INTERVAL:
				direction = _navigation_direction(enemy, Vector2(action["target"]))
				action["steer_elapsed"] = 0.0
	action["direction"] = direction
	var finish := origin
	if direction.length_squared() > 0.001:
		finish = _move_actor(origin, direction * step_distance, float(enemy["radius"]), int(enemy["id"]))
	var motion := finish - origin
	var moved := motion.length_squared() > ENEMY_MOVE_EPSILON * ENEMY_MOVE_EPSILON
	if moved:
		_set_enemy_position(enemy, finish)
		enemy["last_motion"] = motion
		enemy["facing"] = motion.normalized()
		enemy["stalled_time"] = 0.0
	else:
		enemy["last_motion"] = Vector2.ZERO
		enemy["stalled_time"] = float(enemy.get("stalled_time", 0.0)) + stall_dt
		action["recovery_elapsed"] = float(action.get("recovery_elapsed", 0.0)) + stall_dt
		if float(enemy["stalled_time"]) >= ENEMY_STALL_REPATH_TIME:
			enemy.erase("nav_path")
			enemy.erase("nav_target_cell")
			if float(action["recovery_elapsed"]) >= ENEMY_STEER_INTERVAL:
				action["recovery_elapsed"] = 0.0
				var recovery_direction := _stalled_recovery_direction(enemy, direction)
				if recovery_direction.length_squared() > 0.001:
					var recovery_finish := _move_actor(origin, recovery_direction * step_distance, float(enemy["radius"]), int(enemy["id"]))
					var recovery_motion := recovery_finish - origin
					if recovery_motion.length_squared() > ENEMY_MOVE_EPSILON * ENEMY_MOVE_EPSILON:
						_set_enemy_position(enemy, recovery_finish)
						enemy["last_motion"] = recovery_motion
						enemy["facing"] = recovery_motion.normalized()
						enemy["stalled_time"] = 0.0
						action["direction"] = recovery_direction
						moved = true
		if not moved and float(enemy["stalled_time"]) >= ENEMY_STALL_ABORT_TIME:
			# End a movement commitment that cannot make physical progress. The
			# next decision gets a fresh target and path instead of flashing a
			# permanently false MOVING state against the same obstruction.
			action["duration"] = minf(float(action["duration"]), float(action["elapsed"]))
	action["moving"] = moved
	enemy["is_moving"] = moved
	enemy["action"] = action

func _stalled_recovery_direction(enemy: Dictionary, desired: Vector2) -> Vector2:
	var separation := _crowd_separation_direction(enemy)
	var basis := separation
	if basis.length_squared() < 0.001:
		basis = desired.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5)
	if basis.length_squared() < 0.001:
		basis = Vector2.RIGHT if int(enemy["id"]) % 2 == 0 else Vector2.LEFT
	return _local_avoidance_direction(enemy, basis.normalized())

func _enemy_move_speed(enemy: Dictionary) -> float:
	var kind := String(enemy["kind"])
	var speed := float(CombatCatalogScript.enemy_fact(kind, "move_speed"))
	# The Captain's invisible x1.14 aura is gone. What replaces it is the Chanter's
	# Quickening -- same idea, but you can see which enemies have it and you can end it
	# by killing the caster.
	if _enemy_has_chant(enemy, "haste"): speed *= CHANT_SPEED_SCALE
	speed *= _terrain_speed_scale(Vector2(enemy["pos"]))
	return speed

func _archer_support_target(enemy: Dictionary, direction_to_player: Vector2, distance: float) -> Vector2:
	var side := direction_to_player.rotated(PI * 0.5)
	var lateral_spacing := 185.0 + 35.0 * float(int(enemy["id"]) % 3)
	var desired := player_pos - direction_to_player * 470.0 + side * (lateral_spacing if int(enemy["id"]) % 2 == 0 else -lateral_spacing)
	if distance < 235.0: desired = Vector2(enemy["pos"]) - direction_to_player * 280.0 + side * (130.0 if int(enemy["id"]) % 2 == 0 else -130.0)
	return desired

# Per-instance temper, drawn from the spawn the room seed produced. A replayed seed
# replays exactly, and two Shields in one room still differ -- a fixed budget would
# be countable, and this has to be read off the enemy instead.
func _shield_patience_budget(kind: String, position: Vector2, id: int) -> float:
	if kind != "shield": return 0.0
	var mixed := absi(hash(Vector2i(position.round())) ^ (id * 2654435761))
	return SHIELD_PATIENCE_MIN + float(mixed % 1000) / 999.0 * (SHIELD_PATIENCE_MAX - SHIELD_PATIENCE_MIN)

# Patience runs only during a standoff -- the player inside the guard zone and not
# committed to anything worth punishing. A screen has no reason to lose composure
# over someone who is not threatening its ward, and none while it is reeling.
func _update_shield_patience(enemy: Dictionary, dt: float) -> void:
	var budget := float(enemy.get("patience_max", 0.0))
	var patience := float(enemy.get("patience", budget))
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) in ["hit_reaction", "stagger"]: return
	var near := String(enemy.get("awareness", "idle")) == "alerted" and Vector2(enemy["pos"]).distance_to(player_pos) <= SHIELD_GUARD_RADIUS
	if not near:
		enemy["patience"] = minf(budget, patience + dt * 0.55)
	elif _player_commitment_remaining() <= 0.0:
		enemy["patience"] = maxf(0.0, patience - dt)

# How long the player is still locked into what they are doing, in world seconds.
# Movement and idle are not commitments: they are short and interruptible, which is
# precisely why a gate built on proximity could be baited by stepping in and out.
# Wait is a commitment, so spending time is the honest way to draw a screen.
func _player_commitment_remaining() -> float:
	var kind := String(player_action.get("kind", "idle"))
	if kind in ["idle", "move"]: return 0.0
	var remaining := maxf(0.0, float(player_action.get("duration", 0.0)) - float(player_action.get("elapsed", 0.0)))
	return remaining / maxf(0.01, _player_personal_tempo())

# A screen strikes because the player is LATE, not because the player is near.
#
# Patience degrades its judgement rather than merely releasing it. Full, it accepts
# only a window it can genuinely punish. As a standoff drags, the window it will
# take shrinks toward zero, so it begins biting on footwork and finally on nothing
# at all -- and those are the openings worth the most, because a player who has not
# committed is free to answer the instant the guard drops. Being right and being
# patient trade against each other, which is what keeps this from being a wall with
# a timer, and it means the patient player is rewarded rather than stalled.
func _shield_wants_to_strike(enemy: Dictionary, in_guard: bool, guarding: bool) -> bool:
	if not guarding: return true
	var budget := float(enemy.get("patience_max", 0.0))
	if budget <= 0.0: return true
	var patience := clampf(float(enemy.get("patience", budget)) / budget, 0.0, 1.0)
	if patience <= 0.0: return true
	if not in_guard: return false
	var window := _player_commitment_remaining()
	# Below a third it starts mistaking footwork for commitment. That is a genuine
	# misread and the most punishable thing it does, which is the point: an enemy that
	# is always correct is annoying rather than difficult.
	if patience < 0.34 and String(player_action.get("kind", "idle")) == "move": window = maxf(window, 0.30)
	return window >= SHIELD_STRIKE_WINDUP * patience

# The station is measured from the WARD, not from the player, so a screen cannot be
# kited off the thing it is covering. Walking around it costs time -- which is what
# the archer behind it is selling -- rather than costing it its position.
func _shield_station(ward: Vector2) -> Vector2:
	var outward := player_pos - ward
	if outward.length_squared() < 1.0: return ward
	return ward + outward.normalized() * SHIELD_WARD_STATION

# The Bandit answers being SWUNG AT. What stood here before was named dodge_strike
# but read nothing: it fired on a distance band and a timer, closed 117 units with
# invulnerability on the way in, and stabbed for 1 health. It could not counter
# anything because it never looked at the player -- which is why it was never felt.
#
# This reads the commitment instead. It triggers during the player's WIND-UP, before
# the swing resolves, so it is a read rather than a reaction to being hit, and it
# slips sideways: perpendicular motion leaves the arc while holding the distance its
# counter needs. Its cooldown is the tell -- once it has spent the dodge, swinging at
# it is safe, and that is the loop the player is meant to learn.
func _try_bandit_counter(enemy: Dictionary) -> void:
	if String(enemy.get("kind", "")) != "bandit" or int(enemy.get("hp", 0)) <= 0: return
	if float(enemy.get("dodge_cooldown", 0.0)) > 0.0: return
	if String(enemy.get("awareness", "idle")) != "alerted": return
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) not in ["idle", "move"]: return
	if String(player_action.get("kind", "idle")) not in PLAYER_ATTACK_ACTION_KINDS: return
	# Only during the wind-up. Slipping a swing that has already landed is not a read.
	if float(player_action.get("elapsed", 0.0)) >= float(player_action.get("startup", 0.24)): return
	var to_enemy := Vector2(enemy["pos"]) - player_pos
	var distance := to_enemy.length()
	if distance > float(player_action.get("reach", player_attack_reach)) + float(enemy["radius"]) + 30.0: return
	if not _within_arc(player_facing, to_enemy, deg_to_rad(85.0)): return
	# Circle-step, not a retreat. A purely perpendicular slip carried the Bandit from
	# 90 units out to 131 and its riposte fell short -- an evasion that cannot convert
	# is the same half-dead mechanic this replaced. The inward weight keeps the
	# distance its counter needs while still leaving the arc.
	var lateral := to_enemy.normalized().rotated(PI * 0.5 * (1.0 if int(enemy["id"]) % 2 == 0 else -1.0))
	var side := (lateral - to_enemy.normalized() * 0.5).normalized()
	_interrupt_enemy_action(enemy)
	enemy["action"] = _melee_action(1.24, 0.46, 0.58, 96.0, 3, -to_enemy.normalized(), "quick_cut", "dodge_strike")
	enemy["action"]["dodge_end"] = 0.26
	enemy["action"]["speed"] = 330.0
	enemy["action"]["dodge_direction"] = side
	enemy["dodge_cooldown"] = 2.40
	_add_effect("strain", Vector2(enemy["pos"]))

func _enemy_mass(kind: String) -> float:
	return float(Dictionary(CombatCatalogScript.archetype(kind).get("properties", {})).get("mass", 1.0))

func _enemy_role(enemy: Dictionary) -> String:
	return CombatCatalogScript.role(String(enemy.get("kind", "")))

# Centre of the living allies matching `roles`, excluding the subject itself.
# Returns the player's position when there is nobody to anchor to, which collapses
# the anchored roles back to a straight approach rather than to a stalled one.
func _ally_anchor(subject: Dictionary, roles: Array) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	var origin := Vector2(subject.get("pos", player_pos))
	for other in enemies:
		if int(other.get("id", -1)) == int(subject.get("id", -2)): continue
		if int(other.get("hp", 0)) <= 0 or not _enemy_on_current_layer(other): continue
		if not roles.is_empty() and _enemy_role(other) not in roles: continue
		if origin.distance_to(Vector2(other.get("pos", origin))) > ROLE_ANCHOR_RADIUS: continue
		sum += Vector2(other["pos"])
		count += 1
	return player_pos if count == 0 else sum / float(count)

# Which way a role wants to stand from the player. Frontline covers its whole
# group, a screen covers specifically the allies that cannot defend themselves,
# and reach simply holds the bearing it already has instead of closing. When there
# is nobody to cover, all three collapse to the enemy's own bearing -- a straight
# approach rather than a stalled one.
func _role_bearing(enemy: Dictionary, role: String) -> Vector2:
	var anchor := player_pos
	if role == "frontline": anchor = _ally_anchor(enemy, [])
	elif role == "screen": anchor = _ally_anchor(enemy, ["ranged_pressure", "area_denial", "reach"])
	var outward := anchor - player_pos
	if outward.length_squared() < 1.0: outward = Vector2(enemy["pos"]) - player_pos
	if outward.length_squared() < 0.001: outward = -player_facing
	return outward.normalized()

func _pursuit_target(enemy: Dictionary) -> Vector2:
	var target := player_pos
	var kind := String(enemy.get("kind", ""))
	var role := _enemy_role(enemy)
	if String(player_action.get("kind", "idle")) == "move":
		var motion := Vector2(player_action.get("direction", player_facing)).normalized()
		var lead := 120.0 if role == "flanker" else 45.0
		target += motion * lead
	if role in ANCHORED_ROLES:
		return player_pos + _role_bearing(enemy, role) * ROLE_HOLD_DISTANCE[role]
	if role == "flanker":
		# Flankers reserve distinct lanes around the player's projected route. This
		# makes them intercept lateral movement instead of joining a single trailing
		# column that the player can herd into one broad sweep.
		var route := Vector2(player_action.get("direction", player_facing)).normalized()
		if String(player_action.get("kind", "idle")) != "move":
			route = Vector2(enemy["pos"]).direction_to(player_pos)
		if route.length_squared() < 0.001: route = player_facing.normalized()
		var lane_pattern := [-1.0, 1.0, -0.45, 0.45]
		var lane_index := absi(int(enemy["id"])) % lane_pattern.size()
		var lane_spacing := 96.0 if kind == "hound" else 84.0
		target += route.rotated(PI * 0.5) * float(lane_pattern[lane_index]) * lane_spacing
	return target

# --- The Chanter's spellbook ----------------------------------------------------
#
# Three chants, one at a time, each with a colour and a distinct silhouette:
#   haste  -- blue,   a ring: moves faster
#   bulwark-- yellow, a chevron: posture and telegraph armour
#   ward   -- red,    a diamond: incoming damage reduced
#
# You know the Chanter buffs. You do not know which buff is coming, which is the same
# information shape as an enemy with two attacks. What you can always see is which
# allies are currently carrying what, because the effect is drawn on THEM.

func _enemy_has_chant(enemy: Dictionary, chant: String) -> bool:
	return float(Dictionary(enemy.get("chants", {})).get(chant, 0.0)) > 0.0

func _chant_remaining(enemy: Dictionary, chant: String) -> float:
	return float(Dictionary(enemy.get("chants", {})).get(chant, 0.0))

func _tick_chants(enemy: Dictionary, dt: float) -> void:
	var chants: Dictionary = enemy.get("chants", {})
	if chants.is_empty(): return
	var survivors: Dictionary = {}
	for chant in chants.keys():
		var remaining := float(chants[chant]) - dt
		if remaining > 0.0: survivors[chant] = remaining
	enemy["chants"] = survivors

# Every chant this caster is sustaining dies with it. Without this, killing the
# Chanter first buys nothing you can see, and "kill it first" stops being a decision.
func _end_chants_from(source_id: int) -> void:
	for enemy in enemies:
		var chants: Dictionary = enemy.get("chants", {})
		if chants.is_empty(): continue
		if int(enemy.get("chant_source_id", -1)) != source_id: continue
		enemy["chants"] = {}
		_add_effect("strain", Vector2(enemy["pos"]))

# Allies close enough to be worth chanting over, excluding the caster itself.
func _chant_targets(caster: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for other in enemies:
		if int(other.get("id", -1)) == int(caster.get("id", -2)): continue
		if int(other.get("hp", 0)) <= 0 or not _enemy_on_current_layer(other): continue
		if String(other.get("kind", "")) == "chanter": continue
		if Vector2(caster["pos"]).distance_to(Vector2(other["pos"])) > CHANT_RADIUS: continue
		result.append(other)
	return result

# Which chant this room wants. Not random: it reads what its allies are and picks the
# one that suits them, so a Chanter behind a Brute hardens it while a Chanter behind
# Hounds speeds them up. You still cannot know which is coming until it lands, because
# you cannot see which allies it has counted.
func _choose_chant(targets: Array[Dictionary]) -> String:
	var heavy := 0
	var fast := 0
	for enemy in targets:
		if _enemy_mass(String(enemy.get("kind", ""))) >= HEAVY_TELEGRAPH_MASS: heavy += 1
		elif _enemy_move_speed(enemy) >= 250.0: fast += 1
	if heavy > 0 and heavy >= fast: return "bulwark"
	if fast > 0: return "haste"
	return "ward"

# Nothing of its own left between it and the player: put an ally there. A support unit
# caught in the open should be trying to get behind something, not trading.
func _chanter_retreat_target(caster: Dictionary, allies: Array[Dictionary]) -> Vector2:
	var away := (Vector2(caster["pos"]) - player_pos)
	if away.length_squared() < 1.0: away = -player_facing
	var best := Vector2.INF
	var best_score := INF
	for ally in allies:
		var ally_pos := Vector2(ally["pos"])
		# Stand a body-length behind the ally, on the far side from the player.
		var behind := ally_pos + (ally_pos - player_pos).normalized() * (float(ally.get("radius", ENEMY_RADIUS)) + 74.0)
		var score := Vector2(caster["pos"]).distance_to(behind)
		if score < best_score:
			best_score = score
			best = behind
	if best.is_finite(): return best
	# Nobody to hide behind. Put distance between itself and the player instead.
	return Vector2(caster["pos"]) + away.normalized() * 340.0

# Is any living ally actually between this caster and the player? Measured against the
# segment, so an ally off to one side does not count as cover.
func _chanter_is_screened(caster: Dictionary, allies: Array[Dictionary]) -> bool:
	for ally in allies:
		if _segment_distance_to_point(player_pos, Vector2(caster["pos"]), Vector2(ally["pos"])) <= float(ally.get("radius", ENEMY_RADIUS)) + 34.0: return true
	return false

func _charge_action(duration: float, startup: float, active_end: float, speed: float, damage: int, direction: Vector2) -> Dictionary:
	var result := _action("charge", duration, direction)
	result["startup"] = startup
	result["active_end"] = active_end
	result["speed"] = speed
	result["damage"] = damage
	return result

func _werewolf_claw_combo(direction: Vector2) -> Dictionary:
	var result := _action("claw_combo", 1.26, direction)
	result.merge({"first_start": 0.22, "first_end": 0.42, "second_start": 0.57, "second_end": 0.79, "reach": 148.0, "damage": 14, "posture": 3.0, "hit_one": false, "hit_two": false})
	return result

func _werewolf_pounce_combo(direction: Vector2) -> Dictionary:
	var result := _action("pounce_combo", 1.76, direction)
	result.merge({"startup": 0.34, "pounce_end": 0.76, "speed": 420.0, "pounce_damage": 16, "pounce_hit": false, "first_start": 0.82, "first_end": 1.01, "second_start": 1.13, "second_end": 1.34, "reach": 152.0, "damage": 14, "posture": 3.0, "hit_one": false, "hit_two": false})
	return result

func _resolve_enemy_melee_tick(enemy: Dictionary, elapsed: float) -> void:
	var action: Dictionary = enemy["action"]
	var sample: Dictionary = AttackGeometryScript.pose(action, Vector2(enemy["pos"]), Vector2(action.get("direction", enemy["facing"])), _nearby_walls(Vector2(enemy["pos"]), float(action.get("reach", 220.0)) + 90.0))
	if AttackGeometryScript.hits_circle(sample, player_pos, PLAYER_RADIUS):
		enemy["action"]["hit_done"] = true
		var contact_record: Dictionary = Dictionary(enemy["action"]).get("capture_record", {})
		if not contact_record.is_empty():
			# "contact" covers landed, blocked and endured; the report already counts
			# blocks and endures separately. Only an i-frame evade is distinct here,
			# because it is the outcome capture is meant to make necessary.
			contact_record["resolution"] = "evaded" if _is_evasive() else "contact"
		var contact := AttackGeometryScript.contact_point(sample, player_pos)
		_resolve_incoming_hit(int(enemy["id"]), int(action["damage"]), String(enemy["kind"]), Vector2.ZERO, contact, float(action.get("posture", -1.0)))

func _resolve_enemy_combo_tick(enemy: Dictionary, elapsed: float) -> void:
	var action: Dictionary = enemy["action"]
	var phases := [
		{"start": float(action.get("first_start", 0.22)), "end": float(action.get("first_end", 0.42)), "hit": "hit_one", "technique": "quick_cut"},
		{"start": float(action.get("second_start", 0.57)), "end": float(action.get("second_end", 0.79)), "hit": "hit_two", "technique": "reverse_cut"},
	]
	for phase_value in phases:
		var phase := Dictionary(phase_value)
		var hit_key := String(phase["hit"])
		if bool(action.get(hit_key, false)) or elapsed < float(phase["start"]) or elapsed > float(phase["end"]): continue
		var sampled_action := action.duplicate(false)
		sampled_action["startup"] = float(phase["start"])
		sampled_action["active_end"] = float(phase["end"])
		sampled_action["technique_id"] = String(phase["technique"])
		var sample: Dictionary = AttackGeometryScript.pose(sampled_action, Vector2(enemy["pos"]), Vector2(action["direction"]), _nearby_walls(Vector2(enemy["pos"]), float(action.get("reach", 152.0)) + 90.0))
		if AttackGeometryScript.hits_circle(sample, player_pos, PLAYER_RADIUS):
			action[hit_key] = true
			var contact := AttackGeometryScript.contact_point(sample, player_pos)
			_resolve_incoming_hit(int(enemy["id"]), int(action.get("damage", 14)), String(enemy["kind"]), Vector2.ZERO, contact, float(action.get("posture", -1.0)))

func _melee_action(duration: float, startup: float, active_end: float, reach: float, damage: int, direction: Vector2, technique_id: String = "diagonal_cut", action_kind: String = "melee") -> Dictionary:
	# Energy shortens player commitments only. Before v0.2.6 this helper also
	# shortened every enemy attack whenever the run used Energy rules, which made
	# bandits and other fast enemies re-enter attacks before their authored recovery.
	var profiled_duration := _shorten_recovery(duration, active_end) if action_kind in ["attack", "sweep"] else duration
	var result := _action(action_kind, profiled_duration, direction)
	result["startup"] = startup
	result["active_end"] = active_end
	result["reach"] = reach
	result["damage"] = damage
	result["technique_id"] = technique_id
	return result

# Thrown where the player is GOING. Running in a straight line is what beats an
# Archer, so the second ranged enemy has to punish exactly that -- otherwise both of
# them ask the same question and the room learns nothing new.
# Where the player will be, not where they are. Running in a straight line is what
# beats an Archer, so the second ranged enemy has to punish exactly that.
func _javelin_lead(enemy: Dictionary) -> Vector2:
	var origin := Vector2(enemy["pos"])
	var aim := player_pos
	if String(player_action.get("kind", "idle")) == "move":
		var motion := Vector2(player_action.get("direction", player_facing)).normalized()
		var flight := origin.distance_to(player_pos) / JAVELIN_SPEED
		aim += motion * current_move_speed() * flight
	var lead := (aim - origin).normalized()
	if lead.length_squared() < 0.001: lead = Vector2(enemy["facing"]).normalized()
	if lead.length_squared() < 0.001: lead = Vector2.DOWN
	return lead

# The moment, not the condition: fast, aimed, and answerable by moving. It carries most
# of the element's frost, so evading it is the difference between being slowed and not.
func _spawn_spell_projectile(caster: Dictionary, spell_id: String, direction: Vector2) -> void:
	var source_id := int(caster.get("id", -1))
	var player_cast := source_id == 0
	var facing := direction.normalized()
	var layer := String(caster.get("layer", current_layer))
	if spell_id == "fireball":
		if not player_cast: facing = facing.rotated(0.065 if source_id % 2 == 0 else -0.065)
		var fireball := {
			"pos": Vector2(caster["pos"]) + facing * (36.0 if player_cast else 42.0),
			"vel": facing * 465.0,
			"radius": 13.0,
			"damage": 20,
			"kind": "firebolt",
			"source_id": source_id,
			"layer": layer,
		}
		if player_cast:
			fireball.merge({"posture": 1.6, "friendly": true, "travelled": 0.0, "max_range": 700.0, "hit_ids": [], "elevation_profile": "flat", "elevation": PROJECTILE_GROUND_ELEVATION})
		else:
			fireball.merge({"launch_direction": facing, "turn_rate": 0.0, "max_track_angle": 0.0})
		_add_projectile(fireball)
		return
	if spell_id == "frost_lance":
		var lance := {
			"pos": Vector2(caster["pos"]) + facing * (36.0 if player_cast else 40.0),
			"vel": facing * 610.0,
			"radius": 11.0,
			"damage": 16,
			"kind": "frost_lance",
			"source_id": source_id,
			"layer": layer,
		}
		if player_cast:
			lance.merge({"posture": 1.4, "friendly": true, "travelled": 0.0, "max_range": 660.0, "hit_ids": [], "elevation_profile": "flat", "elevation": PROJECTILE_GROUND_ELEVATION})
		else:
			lance.merge({"launch_direction": facing, "turn_rate": 0.0, "max_track_angle": 0.0})
		_add_projectile(lance)
		return
	push_error("Spell '%s' does not define a projectile spawner." % spell_id)

func _spawn_frost_lance(enemy: Dictionary, direction: Vector2) -> void:
	_spawn_spell_projectile(enemy, "frost_lance", direction)
	_set_message("A lance of ice is loosed.")

func _spawn_javelin(enemy: Dictionary) -> void:
	var origin := Vector2(enemy["pos"])
	# The line committed to at the announcement. It does not re-aim: an early read
	# escapes it, which is what makes the telegraph worth reading.
	var direction := Vector2(Dictionary(enemy.get("action", {})).get("direction", Vector2(enemy["facing"]))).normalized()
	if direction.length_squared() < 0.001: direction = _javelin_lead(enemy)
	_add_projectile({
		# The one projectile in the game that arcs. High early so it clears whatever is
		# standing beside the thrower, descending late so it still reaches -- which is the
		# Javelineer's whole shape as a lane denier rather than a second archer.
		"elevation_profile": "arc",
		"elevation_peak": 78.0,
		"pos": origin + direction * 44.0,
		"vel": direction * JAVELIN_SPEED,
		"radius": JAVELIN_RADIUS,
		"damage": 16,
		"kind": "javelin",
		"launch_direction": direction,
		"turn_rate": 0.0,
		"max_track_angle": 0.0,
		"source_id": int(enemy["id"]),
		"layer": String(enemy.get("layer", current_layer)),
	})
	_set_message("A javelin is away.")

# The cut goes between the player and where the player is trying to reach, not under
# their feet.
func _sunder_target(enemy: Dictionary) -> Vector2:
	var target := player_pos
	if String(player_action.get("kind", "idle")) == "move":
		var motion := Vector2(player_action.get("direction", player_facing)).normalized()
		target += motion * 190.0
	else:
		# Standing still: cut the line back toward the caster's own allies, which is the
		# ground the player would have to cross to reach anything.
		var inward := (Vector2(enemy["pos"]) - player_pos)
		if inward.length_squared() > 1.0: target += inward.normalized() * 150.0
	return target

func _spawn_sundered_ground(position: Vector2, source_id: int, layer: String) -> void:
	_add_hazard({
		"kind": "sundered_ground",
		"pos": position,
		"radius": SUNDERED_RADIUS,
		"elapsed": 0.0,
		"trigger_at": 0.55,
		"duration": SUNDERED_DURATION,
		"damage": 0,
		"slow": SUNDERED_SLOW,
		"source_id": source_id,
		"triggered": false,
		"layer": layer,
	})
	_set_message("The ground splits and buckles.")

func _resolve_chant(caster: Dictionary, chant: String) -> void:
	var targets := _chant_targets(caster)
	if targets.is_empty(): return
	for enemy in targets:
		var chants: Dictionary = enemy.get("chants", {})
		chants[chant] = CHANT_DURATION
		enemy["chants"] = chants
		enemy["chant_source_id"] = int(caster["id"])
		_add_effect("posture_break" if chant == "bulwark" else "strain", Vector2(enemy["pos"]))
	_set_message({"haste": "A quickening runs through them.", "bulwark": "Their stances harden.", "ward": "A ward settles over them."}.get(chant, "A chant rises."))

func _spawn_projectile(enemy: Dictionary) -> void:
	var direction: Vector2 = Vector2(enemy["facing"]).normalized()
	var firebolt := String(enemy["kind"]) == "fire_caster"
	# A firebolt is a fast, lightly canted shot—not a homing missile. The tiny
	# alternating launch bias gives it character while preserving one readable,
	# committed trajectory once it has left the caster.
	if firebolt:
		_spawn_spell_projectile(enemy, "fireball", direction)
		return
	_add_projectile({
		"pos": Vector2(enemy["pos"]) + direction * 42.0,
		"vel": direction * 700.0,
		"radius": 9.0,
		# The ball hits harder than the breath and barely kindles; the breath buries you in
		# burn for moderate damage. Near or far is a real choice only if the two differ in
		# what they cost you, not just in reach.
		"damage": 14,
		"kind": "arrow",
		# Fireballs retain their launch vector for their entire flight. The fields
		# remain on the projectile for older-save compatibility and future variants.
		"launch_direction": direction,
		"turn_rate": 0.0,
		"max_track_angle": 0.0,
		"source_id": int(enemy["id"]),
		"layer": String(enemy.get("layer", current_layer)),
	})

func _spawn_player_projectile(kind: String, direction: Vector2) -> void:
	var facing := direction.normalized()
	if facing.length_squared() < 0.01: facing = player_facing
	_add_projectile({
		"pos": player_pos + facing * 34.0,
		"vel": facing * (520.0 if kind == "firebomb" else 780.0),
		"radius": 15.0 if kind == "firebomb" else 7.0,
		"damage": 20 if kind == "firebomb" else 15,
		"posture": 2.8 if kind == "firebomb" else 1.4,
		"kind": kind,
		"friendly": true,
		"source_id": 0,
		"travelled": 0.0,
		"max_range": (400.0 if kind == "firebomb" else 560.0) * _aimed_projectile_range_multiplier(),
		"layer": current_layer,
	})

func _spawn_bow_projectile(action: Dictionary) -> void:
	var direction := Vector2(action.get("direction", player_facing)).normalized()
	_add_projectile({
		"pos": player_pos + direction * 34.0,
		"vel": direction * float(action.get("projectile_speed", 480.0)),
		"radius": 7.0,
		"damage": int(action.get("projectile_damage", 6)),
		"posture": float(action.get("projectile_posture", 0.25)),
		"kind": "player_arrow",
		"friendly": true,
		"aimed_projectile": true,
		"source_id": 0,
		"travelled": 0.0,
		"max_range": float(action.get("projectile_range", 250.0)),
		"piercing": false,
		"hit_ids": [],
		"draw_ratio": float(action.get("draw_ratio", 0.0)),
		"full_draw": bool(action.get("full_draw", false)),
		"layer": current_layer,
	})
	survey_shots_fired += 1
	_break_stealth_for_hostile_action()
	_emit_sound(player_pos, 430.0)

func _spawn_bow_art_projectiles(piercing: bool, direction: Vector2) -> void:
	var base := direction.normalized()
	if piercing:
		_add_projectile({"pos": player_pos + base * 34.0, "vel": base * 900.0, "radius": 8.0, "damage": 22, "posture": 5.0, "kind": "piercing_arrow", "friendly": true, "aimed_projectile": true, "source_id": 0, "travelled": 0.0, "max_range": 780.0 * _aimed_projectile_range_multiplier(), "piercing": true, "hit_ids": [], "layer": current_layer})
	else:
		for offset in [-0.16, 0.0, 0.16]:
			var ray := base.rotated(float(offset))
			_add_projectile({"pos": player_pos + ray * 34.0, "vel": ray * 720.0, "radius": 7.0, "damage": 6, "posture": 0.7, "kind": "fan_arrow", "friendly": true, "aimed_projectile": true, "source_id": 0, "travelled": 0.0, "max_range": 380.0 * _aimed_projectile_range_multiplier(), "piercing": false, "hit_ids": [], "layer": current_layer})
	survey_shots_fired += 1
	_break_stealth_for_hostile_action()
	_emit_sound(player_pos, 520.0)

func _move_vault_actor(origin: Vector2, delta: Vector2) -> Vector2:
	var result := origin
	var candidate := Vector2(origin.x + delta.x, origin.y)
	if not _position_blocked_static(candidate, PLAYER_RADIUS): result.x = candidate.x
	candidate = Vector2(result.x, origin.y + delta.y)
	if not _position_blocked_static(candidate, PLAYER_RADIUS): result.y = candidate.y
	return result

func _resolve_vault_crossings(origin: Vector2, finish: Vector2) -> void:
	var crossed_ids: Array = player_action.get("vault_crossed_ids", [])
	for enemy in _nearby_enemies(origin, origin.distance_to(finish) + 95.0):
		var enemy_id := int(enemy.get("id", -1))
		if crossed_ids.has(enemy_id) or not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		if _segment_distance_to_point(origin, finish, Vector2(enemy["pos"])) > PLAYER_RADIUS + float(enemy.get("radius", ENEMY_RADIUS)) + 6.0: continue
		crossed_ids.append(enemy_id)
		enemy["awareness"] = "alerted"
		enemy["alert_remaining"] = 3.0
		enemy["last_known_player"] = player_pos
		var mass := float(Dictionary(enemy.get("properties", {})).get("mass", 1.0))
		var existing_action := Dictionary(enemy.get("action", _idle_action()))
		if mass > 1.35 or String(existing_action.get("kind", "idle")) in ["stagger", "hit_reaction"]: continue
		var reaction_direction := (Vector2(enemy["pos"]) - origin).normalized()
		if reaction_direction.length_squared() < 0.001: reaction_direction = -Vector2(player_action.get("direction", player_facing)).normalized()
		_interrupt_enemy_action(enemy)
		enemy["action"] = _action("hit_reaction", 0.28, Vector2.ZERO)
		_clear_melee_intent(enemy)
		enemy["action"].merge({
			"reaction_contact": Vector2(enemy["pos"]),
			"reaction_direction": reaction_direction,
			"reaction_strength": 0.72,
			"reaction_source_kind": "vault",
			"interrupted_action": existing_action.duplicate(true),
		}, true)
		enemy["posture_recovery_delay"] = maxf(float(enemy.get("posture_recovery_delay", 0.0)), 0.28)
		_add_effect("interrupt", Vector2(enemy["pos"]), 0, {"direction": reaction_direction, "strength": 0.72})
	player_action["vault_crossed_ids"] = crossed_ids

func _spawn_player_fire(pos: Vector2) -> void:
	_add_hazard({"kind": "player_fire", "pos": pos, "radius": 124.0, "elapsed": 0.0, "trigger_at": 0.16, "duration": 0.56, "damage": 20, "posture": 2.8, "source_id": 0, "triggered": false, "friendly": true, "layer": current_layer})

# Ice decides EVADABILITY: a threat that is a moment, versus a threat that is a condition
# of being there. The front is the second -- wide, slow and repeating, so leaving it is a
# journey rather than a sidestep. It never kills; it decides who does.
const COLD_FRONT_TICKS := 4
const COLD_FRONT_INTERVAL := 0.46

# A placed point; everything near it is pushed AWAY from that point. Placement decides
# push versus pull -- put the point behind an enemy and it comes toward you -- so one rule
# produces both outcomes and the decision is made fresh every cast rather than locked in
# at build time. It moves the caster and the player too; the wind does not take sides.
const GALE_RADIUS := 250.0
const GALE_BODY_PUSH := 116.0
const GALE_PLAYER_PUSH := 96.0
# Velocity, not position. Pushing a shot's position would offset it while leaving its
# heading, so it would arrive in the same place merely late.
const GALE_PROJECTILE_TURN := 0.62
# A gust gives you a shove, not a new address. Until 0.2.73 the push was a single position
# write on the frame it landed -- nobody travelled, they were simply somewhere else, which
# is the shape of a MOBA displacement rather than of wind. Adding falloff changed how far
# they went and not that they got there instantly.
#
# Now it is an impulse: a velocity that carries the body and decays, so the movement has a
# direction you can watch and an arrival you can predict, and anything in the way -- a wall,
# a barrier, another body -- stops it where it stands. Being blown INTO something becomes a
# real interaction rather than a number that was already applied.
#
# Deliberately NOT a sustained force field, tempting as that is in frozen time. A wind that
# kept pushing while world time advanced would tax the duration of your commitment, and that
# is Burn's currency. Air's question is where things are, not how long you spend acting.
const GALE_DECELERATION := 1165.0
const GALE_DRIFT_FLOOR := 24.0

func _spawn_gale(enemy: Dictionary, target: Vector2) -> void:
	_add_hazard({
		"kind": "gale", "pos": target, "radius": GALE_RADIUS,
		"elapsed": 0.0, "trigger_at": 0.08 if int(enemy.get("id", -1)) == 0 else 0.52, "duration": 0.88, "damage": 0,
		"source_id": int(enemy["id"]), "triggered": false, "layer": String(enemy.get("layer", current_layer)),
	})
	_set_message("The air tears outward.")

# Distance travelled under linear deceleration is v^2 / 2a, so the speed that produces a
# given distance is sqrt(2 a d). Authoring the distance and deriving the speed keeps the
# numbers that were tuned by play and makes the impulse a presentation of them.
func _gale_launch_speed(distance: float) -> float:
	return sqrt(2.0 * GALE_DECELERATION * maxf(0.0, distance))

# Carries anything the wind has hold of. Runs on world time like everything else, so a body
# blown across a room travels while the world is moving and stands still while it is not.
func _update_gale_drift(dt: float) -> void:
	# Drift is checked against GEOMETRY rather than against bodies. The wind does not care
	# what it blows you past, and checking bodies made the whole thing fail in the one case
	# that matters most: anything already crowding you starts inside your own radius, so
	# every incremental step was refused and the shove died on the frame it began. The old
	# instant write escaped this by accident, by covering the whole distance at once.
	# Overlaps that survive the drift are resolved by the crowding push, as they always are.
	if player_gale_velocity.length() > GALE_DRIFT_FLOOR:
		var landing := player_pos + player_gale_velocity * dt
		if _teleport_allowed(landing, PLAYER_RADIUS, 0):
			player_pos = landing
			player_gale_velocity = player_gale_velocity.move_toward(Vector2.ZERO, GALE_DECELERATION * dt)
		else:
			# Stopped by the world. The wind spends itself on the impact rather than pressing
			# a body into a wall, which is what makes being blown INTO cover matter.
			player_gale_velocity = Vector2.ZERO
	else:
		player_gale_velocity = Vector2.ZERO
	for enemy in enemies:
		var velocity := Vector2(enemy.get("gale_velocity", Vector2.ZERO))
		if velocity.length() <= GALE_DRIFT_FLOOR or int(enemy.get("hp", 0)) <= 0:
			if enemy.has("gale_velocity"): enemy.erase("gale_velocity")
			continue
		var radius := float(enemy.get("radius", ENEMY_RADIUS))
		var target := Vector2(enemy["pos"]) + velocity * dt
		if not _teleport_allowed(target, radius, int(enemy["id"])):
			enemy.erase("gale_velocity")
			continue
		_set_enemy_position(enemy, target)
		enemy["gale_velocity"] = velocity.move_toward(Vector2.ZERO, GALE_DECELERATION * dt)

func _resolve_gale(centre: Vector2) -> void:
	_add_effect("strain", centre)
	for enemy in _nearby_enemies(centre, GALE_RADIUS + 90.0):
		if int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
		var offset := Vector2(enemy["pos"]) - centre
		if offset.length() > GALE_RADIUS: continue
		# Mass-gated on the same line that already decides who the player can shove, so
		# "heavy" means one thing throughout rather than one thing per system.
		if _enemy_mass(String(enemy.get("kind", ""))) >= PUSHABLE_MASS: continue
		var away := offset.normalized() if offset.length_squared() > 0.001 else Vector2.RIGHT
		# A gust, not a tow rope. The push falls off with distance from the centre, so
		# standing at the edge is a shove and standing on it is thrown -- which is what makes
		# WHERE the point goes the decision rather than merely whether you were inside it.
		var falloff := 1.0 - clampf(offset.length() / GALE_RADIUS, 0.0, 1.0)
		var shove := GALE_BODY_PUSH * (0.25 + 0.75 * falloff * falloff)
		# The launch speed is derived from the distance rather than authored beside it, so
		# the tuning from 0.2.72 survives intact and only the delivery changes.
		_set_actor_impulse(enemy, away * _gale_launch_speed(shove))
		# Being physically thrown is not something a body sleeps through. It learns where the
		# player is, the same way it would from being hit -- an enemy that is shoved across a
		# room and then keeps idling is the room telling an obvious lie.
		_broadcast_enemy_alarm(enemy, player_pos)
	var player_offset := player_pos - centre
	if player_offset.length() <= GALE_RADIUS:
		var push := player_offset.normalized() if player_offset.length_squared() > 0.001 else Vector2.LEFT
		var player_falloff := 1.0 - clampf(player_offset.length() / GALE_RADIUS, 0.0, 1.0)
		_set_actor_impulse(0, push * _gale_launch_speed(GALE_PLAYER_PUSH * (0.25 + 0.75 * player_falloff * player_falloff)))
	for projectile in projectiles:
		var to_shot := Vector2(projectile["pos"]) - centre
		if to_shot.length() > GALE_RADIUS: continue
		var velocity := Vector2(projectile.get("vel", Vector2.ZERO))
		if velocity.length_squared() < 0.001: continue
		var away := to_shot.normalized() if to_shot.length_squared() > 0.001 else velocity.normalized()
		projectile["vel"] = (velocity.normalized() + away * GALE_PROJECTILE_TURN).normalized() * velocity.length()
		# Once Gale changes a committed trajectory, the shot is no longer protected by
		# its source faction. This applies equally to enemy and player projectiles: a
		# bent player shot can come back through the player who loosed it.
		projectile["misdirected"] = true
		# A gale spoils flight. An arrow's flight is direction; a javelin's is direction
		# AND loft, so the same wind takes more from it -- one object with more to lose,
		# not a special case. Grounded, it comes down short and off-line into the melee it
		# was meant to sail over.
		if String(projectile.get("elevation_profile", "flat")) == "arc":
			projectile["elevation_profile"] = "flat"
			projectile["elevation"] = 8.0
			survey_javelins_grounded += 1
			_set_message("The javelin is torn out of the air.")

func _spawn_cold_front(enemy: Dictionary, target: Vector2) -> void:
	_add_hazard({
		"kind": "cold_front", "pos": target, "radius": 268.0,
		"elapsed": 0.0, "trigger_at": 0.70, "duration": 0.70 + COLD_FRONT_INTERVAL * float(COLD_FRONT_TICKS),
		# 3, down from 9. At 9 the front dealt 7 per tick to a Mage -- about 15 a second
		# across its life, and the listed death source of the 0.2.72 survey. Frost is what
		# this ability is for: it slows the whole action and softens the next hit, and the
		# damage was never the payload. A heavily armoured body now walks through taking
		# almost nothing and is frosted anyway, which is the correct reading of it.
		#
		# A repeating zone is also the one hazard where frozen time works against the player:
		# leaving costs world time, and spending world time is what advances the ticks. Its
		# per-tick damage has to be low precisely because its duration is self-inflicted.
		"damage": 3, "posture": 1.1, "ticks_done": 0, "next_tick": 0.10 if int(enemy.get("id", -1)) == 0 else 0.70,
		"source_id": int(enemy["id"]), "triggered": false, "layer": String(enemy.get("layer", current_layer)),
	})
	_set_message("The air goes bitter and still.")

# A cone, not a ring. A ring centred on the caster asks "are you close?", which the
# player answers by backing off -- the same answer every close threat already has. A cone
# asks "are you in front of it?", so the answer is to leave the arc, which is a different
# decision and one the caster's own facing telegraphs.
func _spawn_fire_breath(enemy: Dictionary, direction: Vector2) -> void:
	_add_hazard({"kind": "fire_breath", "pos": Vector2(enemy["pos"]), "direction": direction.normalized(), "radius": 232.0, "half_angle": 0.52, "elapsed": 0.0, "trigger_at": 0.72, "duration": 1.06, "damage": 16, "posture": 2.0, "source_id": int(enemy["id"]), "triggered": false, "layer": String(enemy.get("layer", current_layer))})
	_set_message("The caster breathes fire.")

func _update_hazards(dt: float) -> void:
	var survivors: Array[Dictionary] = []
	for hazard in hazards:
		if String(hazard.get("layer", current_layer)) != current_layer:
			survivors.append(hazard)
			continue
		hazard["elapsed"] = float(hazard["elapsed"]) + dt
		var kind := String(hazard.get("kind", ""))
		if bool(hazard.get("friendly", false)):
			if not bool(hazard["triggered"]) and float(hazard["elapsed"]) >= float(hazard["trigger_at"]):
				hazard["triggered"] = true
				_add_effect("fire", Vector2(hazard["pos"]))
				for enemy in _nearby_enemies(Vector2(hazard["pos"]), float(hazard["radius"]) + 70.0):
					if _enemy_on_current_layer(enemy) and Vector2(enemy["pos"]).distance_to(Vector2(hazard["pos"])) <= float(hazard["radius"]) + float(enemy["radius"]):
						_damage_enemy_from_consumable(enemy, int(hazard["damage"]), float(hazard.get("posture", 0.0)), Vector2(hazard["pos"]))
			if float(hazard["elapsed"]) < float(hazard["duration"]): survivors.append(hazard)
			continue
		if kind == "gale":
			if not bool(hazard["triggered"]) and float(hazard["elapsed"]) >= float(hazard["trigger_at"]):
				hazard["triggered"] = true
				_resolve_gale(Vector2(hazard["pos"]))
			if float(hazard["elapsed"]) < float(hazard["duration"]): survivors.append(hazard)
			continue
		if kind == "cold_front":
			# Ticks repeatedly instead of resolving once, which is what makes it a place
			# rather than a moment. Small frost each time, so standing in it is the mistake
			# rather than being caught by it.
			if float(hazard["elapsed"]) >= float(hazard.get("next_tick", 0.0)) and int(hazard.get("ticks_done", 0)) < COLD_FRONT_TICKS:
				hazard["ticks_done"] = int(hazard.get("ticks_done", 0)) + 1
				hazard["next_tick"] = float(hazard["elapsed"]) + COLD_FRONT_INTERVAL
				_add_effect("ice", Vector2(hazard["pos"]))
				if int(hazard["source_id"]) == 0:
					# The player's own front. Each tick is a fresh chance to be caught, so the
					# struck list is cleared between ticks rather than kept for the hazard.
					hazard["player_hit_ids"] = []
					var front_centre := Vector2(hazard["pos"])
					var front_reach := float(hazard["radius"])
					_resolve_player_hazard_hit(hazard, "cold front", func(enemy: Dictionary) -> bool:
						return Vector2(enemy["pos"]).distance_to(front_centre) <= front_reach + float(enemy.get("radius", ENEMY_RADIUS)))
				elif player_pos.distance_to(Vector2(hazard["pos"])) <= float(hazard["radius"]) + PLAYER_RADIUS:
					_resolve_incoming_hit(int(hazard["source_id"]), int(hazard["damage"]), "cold front", Vector2(hazard["pos"]) - player_pos, Vector2.INF, -1.0, "cold_front:%d" % int(hazard.get("hazard_id", hazard.get("source_id", 0))))
			if float(hazard["elapsed"]) < float(hazard["duration"]): survivors.append(hazard)
			continue
		if kind == "fire_breath":
			var progress := clampf(float(hazard["elapsed"]) / float(hazard["trigger_at"]), 0.0, 1.0)
			var origin := Vector2(hazard["pos"])
			var offset := player_pos - origin
			if int(hazard["source_id"]) == 0:
				var cone_origin := origin
				var cone_facing := Vector2(hazard["direction"])
				var cone_half := float(hazard["half_angle"])
				var cone_reach := float(hazard["radius"]) * progress
				_resolve_player_hazard_hit(hazard, "fire breath", func(enemy: Dictionary) -> bool:
					var to_enemy := Vector2(enemy["pos"]) - cone_origin
					return to_enemy.length() <= cone_reach + float(enemy.get("radius", ENEMY_RADIUS)) and _within_arc(cone_facing, to_enemy, cone_half) and _has_line_of_sight(cone_origin, Vector2(enemy["pos"])))
				if float(hazard["elapsed"]) < float(hazard["duration"]): survivors.append(hazard)
				continue
			var inside_cone := offset.length() <= float(hazard["radius"]) * progress + PLAYER_RADIUS and _within_arc(Vector2(hazard["direction"]), offset, float(hazard["half_angle"]))
			if not bool(hazard["triggered"]) and inside_cone and _has_line_of_sight(origin, player_pos):
				hazard["triggered"] = true
				_add_effect("fire", player_pos)
				_resolve_incoming_hit(int(hazard["source_id"]), int(hazard["damage"]), "fire breath", origin - player_pos)
		elif kind == "sundered_ground":
			# It never resolves a hit. The cost of this ground is the time it takes to
			# cross, which _terrain_speed_scale collects, and in frozen time that is the
			# same as handing every other enemy in the room a free move.
			if not bool(hazard["triggered"]) and float(hazard["elapsed"]) >= float(hazard["trigger_at"]):
				hazard["triggered"] = true
				_add_effect("strain", Vector2(hazard["pos"]))
		if float(hazard["elapsed"]) < float(hazard["duration"]): survivors.append(hazard)
	hazards = survivors

func _update_projectiles(dt: float) -> void:
	var survivors: Array[Dictionary] = []
	for projectile in projectiles:
		if String(projectile.get("layer", current_layer)) != current_layer:
			survivors.append(projectile)
			continue
		var projectile_kind := String(projectile.get("kind", "arrow"))
		var start: Vector2 = projectile["pos"]
		var finish := start + Vector2(projectile["vel"]) * dt
		projectile["pos"] = finish
		projectile["travelled"] = float(projectile.get("travelled", 0.0)) + start.distance_to(finish)
		# One faction rule for every shot in the game. An ordinary projectile passes
		# through actors allied with its original source. Only a projectile explicitly
		# marked misdirected -- currently by Gale -- may collide with that original side,
		# including the source actor itself.
		var source_id := int(projectile.get("source_id", -1))
		var misdirected := bool(projectile["misdirected"])
		var spent := not _inside_world(finish, float(projectile["radius"])) or _point_in_wall(finish) or float(projectile["travelled"]) >= float(projectile.get("max_range", INF))
		var hit_ids: Array = projectile.get("hit_ids", [])
		# Above the ground band it passes over everyone, which is the whole point of the
		# javelin's arc and the reason the check is not conditioned on allegiance.
		# A raised segment stops a shot at ground level. An arcing javelin sails over it,
		# which is the same friend-blind elevation rule doing double duty.
		if not spent and _projectile_elevation(projectile) <= PROJECTILE_GROUND_ELEVATION and _segment_crosses_barrier(start, finish): spent = true
		if not spent and _projectile_elevation(projectile) <= PROJECTILE_GROUND_ELEVATION:
			var nearest_enemy: Dictionary = {}
			var nearest_order := INF
			for enemy in _nearby_enemies(start, start.distance_to(finish) + 100.0):
				if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
				var enemy_id := int(enemy.get("id", -1))
				if hit_ids.has(enemy_id): continue
				var same_side := not _opposes(source_id, enemy)
				if same_side and not misdirected: continue
				if _segment_distance_to_point(start, finish, Vector2(enemy["pos"])) > float(enemy["radius"]) + float(projectile["radius"]): continue
				var order := start.distance_to(Vector2(enemy["pos"]))
				if order < nearest_order:
					nearest_order = order
					nearest_enemy = enemy
			var player_order := INF
			var player_same_side := not _opposes(source_id, 0)
			if (not player_same_side or misdirected) and _segment_distance_to_point(start, finish, player_pos) <= PLAYER_RADIUS + float(projectile["radius"]):
				player_order = start.distance_to(player_pos)
			# Whatever eligible body it reaches first along this step resolves the hit.
			if player_order < nearest_order:
				var hit_label := "fireball" if projectile_kind == "firebolt" else "frost lance" if projectile_kind == "frost_lance" else "arrow"
				if player_same_side: survey_misdirected_ally_hits += 1
				_resolve_incoming_hit(source_id, int(projectile["damage"]), hit_label, -Vector2(projectile["vel"]).normalized())
				continue
			if not nearest_enemy.is_empty():
				if projectile_kind == "firebomb":
					spent = true
				else:
					hit_ids.append(int(nearest_enemy["id"]))
					if not _opposes(source_id, nearest_enemy): _damage_enemy_from_stray_projectile(nearest_enemy, projectile, Vector2(nearest_enemy["pos"]))
					else: _damage_enemy_from_player_projectile(nearest_enemy, projectile, Vector2(nearest_enemy["pos"]))
					if not bool(projectile.get("piercing", false)): spent = true
		projectile["hit_ids"] = hit_ids
		if projectile_kind == "firebomb" and spent: _spawn_player_fire(finish if _inside_world(finish, 1.0) and not _point_in_wall(finish) else start)
		if spent: continue
		survivors.append(projectile)
	projectiles = survivors

# A misdirected shot that reached its original side. The player takes the credit when
# an enemy projectile does the damage, because they did the geometry -- but not the bonus.
# This is the projectile's own authored number, so a strong player does not make a
# Javelineer's throw hit its own side harder than it hits them.
func _damage_enemy_from_stray_projectile(enemy: Dictionary, projectile: Dictionary, contact: Vector2) -> void:
	if not bool(projectile["misdirected"]): return
	if int(enemy.get("hp", 0)) <= 0: return
	survey_misdirected_ally_hits += 1
	var flight := Vector2(projectile.get("vel", Vector2.ZERO))
	if flight.length_squared() > 0.001 and _enemy_blocks_incoming(enemy, -flight.normalized()):
		_add_effect("block", contact)
		return
	# Through the same curve the player's own hits are scaled by. An enemy projectile
	# authors its damage on the player-facing scale -- a javelin is 3, which becomes 17 --
	# and enemy health is in raw points, so passing the authored number straight through
	# would floor a javelin to 5 against a Blade's 35. "Hits whoever it hits" has to mean
	# the same shot means the same thing to whoever it reaches, or the rule is systemic in
	# name only. The victim's own armour still applies.
	var authored := int(projectile.get("damage", 0))
	var defence := int(Dictionary(enemy.get("attributes", {})).get("defense", 0)) + int(Dictionary(enemy.get("properties", {})).get("armor", 0))
	var damage := maxi(0, authored - defence)
	_change_actor_hp(enemy, -damage)
	damage_dealt += damage
	survey_stray_projectile_hits += 1
	_note_player_reached(enemy)
	_add_effect("hurt", contact, damage)
	_apply_actor_posture_damage(enemy, float(projectile.get("posture", 0.0)), contact)
	enemy["awareness"] = "alerted"
	enemy["alert_remaining"] = 3.0
	enemy["last_known_player"] = player_pos

func _damage_enemy_from_consumable(enemy: Dictionary, damage: int, posture: float, contact: Vector2) -> void:
	_damage_enemy_from_player_projectile(enemy, {"damage": damage, "posture": posture, "kind": "consumable", "ability_id": "consumable"}, contact)

func _damage_enemy_from_player_projectile(enemy: Dictionary, projectile: Dictionary, contact: Vector2) -> void:
	if int(enemy.get("hp", 0)) <= 0: return
	# Taken from the shot's own travel rather than from where the player stands, so a
	# projectile that has been redirected is judged on the line it actually arrives on.
	var flight := Vector2(projectile.get("vel", Vector2.ZERO))
	if flight.length_squared() > 0.001 and _enemy_blocks_incoming(enemy, -flight.normalized()):
		_add_effect("block", contact)
		survey_shots_blocked += 1
		enemy["last_known_player"] = player_pos
		if String(enemy.get("awareness", "idle")) != "alerted":
			enemy["awareness"] = "suspicious"
			enemy["suspicious_remaining"] = maxf(float(enemy.get("suspicious_remaining", 0.0)), 2.6)
		return
	var awareness_before := String(enemy.get("awareness", "idle"))
	var action_before := Dictionary(enemy.get("action", _idle_action())).duplicate(true)
	var projectile_kind := String(projectile.get("kind", "projectile"))
	var draw_ratio := float(projectile.get("draw_ratio", 1.0))
	var source_action := {
		"ability_id": String(projectile.get("ability_id", projectile_kind)),
		"duration": 0.35,
		"elapsed": 0.0,
		"allow_hit_reaction": projectile_kind != "player_arrow" or draw_ratio >= 0.72,
		"ranged_draw_ratio": draw_ratio,
	}
	survey_shots_hit += 1
	var resolved := _resolve_player_physical_values(enemy, int(projectile.get("damage", 0)), float(projectile.get("posture", 0.0)), source_action)
	var damage := int(resolved["damage"])
	var posture := float(resolved["posture"])
	_change_actor_hp(enemy, -damage)
	damage_dealt += damage
	_on_player_hit_landed(enemy)
	var posture_broken := _apply_actor_posture_damage(enemy, posture, contact)
	var reaction_applied := false
	if not posture_broken:
		reaction_applied = _apply_enemy_hit_reaction(enemy, posture, awareness_before, action_before, contact, source_action)
	_register_enemy_hit_awareness(enemy, resolved, source_action)
	_add_effect("hit", contact, damage, {"direction": (Vector2(enemy["pos"]) - contact).normalized(), "interrupted": reaction_applied})
	_handle_player_contact_aftermath(enemy, resolved)
	if bool(projectile.get("full_draw", false)) and has_track_rank("bow", 5) and not bow_followup_consumed:
		bow_followup_ready = true
	var source_label := "projectile" if String(projectile.get("kind", "")) != "consumable" else "consumable"
	_set_message("The %s is struck by the %s." % [String(enemy["kind"]), source_label])

# A repeating zone reports one running total rather than a stream of tiny numbers. Cold
# Front ticks four times per cast, and four separate figures over the player's head add up
# to nothing they can read -- the number said 1 while the health bar moved by four times
# that, which is the same complaint as a hidden calculation even though nothing was hidden.
# Anything that damages repeatedly from one source passes a key and accumulates into a
# single figure while that figure is still on screen.
func _aggregate_damage_effect(key: String, impact: Vector2, amount: int) -> bool:
	if key == "": return false
	for effect in effects:
		if String(effect.get("kind", "")) != "hurt" or String(effect.get("aggregate", "")) != key: continue
		effect["amount"] = int(effect.get("amount", 0)) + amount
		effect["pos"] = impact
		effect["elapsed"] = 0.0
		return true
	return false

func _resolve_incoming_hit(source_id: int, damage: int, source_name: String, incoming_from: Vector2 = Vector2.ZERO, contact_position: Vector2 = Vector2.INF, authored_posture: float = -1.0, aggregate_key: String = "") -> void:
	# Zero authored damage is not an attack -- sundered ground and the disengage shove both
	# arrive here with nothing to deal.
	if damage <= 0: return
	var impact := player_pos if not contact_position.is_finite() else contact_position
	var posture_damage := authored_posture if authored_posture >= 0.0 else float(damage) * POSTURE_PER_DAMAGE
	# Flat subtraction with no floor under it. Armour reducing a caster's staff poke to
	# almost nothing is the design working rather than a case to guard against: it is the
	# worst weapon in the game meeting the most armoured class. The old floor raised that
	# back up and erased the distinction the numbers were drawing.
	var physical_defense := int(player_attributes.get("defense", 0)) + int(player_properties.get("armor", 0))
	var mitigated_damage := maxi(0, damage - physical_defense)
	if _is_evasive():
		_trigger_clean_dodge(impact, source_name)
		return
	if _is_blocking(source_id, incoming_from):
		_break_stealth_for_hostile_action()
		successful_blocks += 1
		player_action["effect_done"] = true
		var guard_profile := String(CombatCatalogScript.weapon_frame(player_weapon_frame).get("guard_profile", "standard"))
		var leakage := 0.25 if guard_profile in ["dual", "awkward"] else 0.0
		var chip_damage := roundi(float(mitigated_damage) * leakage)
		if chip_damage > 0: survey_last_damage_source = source_name
		_change_actor_hp(0, -chip_damage)
		damage_received_total += chip_damage
		hits_received_total += 1
		player_posture = maxf(0.0, player_posture - posture_damage)
		player_posture_recovery_delay = 1.15
		_add_effect("block", impact, chip_damage)
		if player_posture <= 0.0001:
			set_block_hold(false)
			player_action = _action("stagger", 0.78, Vector2.ZERO)
			_set_message("Your guard breaks under sustained pressure.")
		elif chip_damage > 0:
			_set_message("The heavy blow crashes through part of your guard.")
		else:
			_set_message("Your guard catches the %s." % source_name)
		return
	if _is_enduring():
		_break_stealth_for_hostile_action()
		successful_endures += 1
		player_action["effect_done"] = true
		var endured_damage := int(ceil(float(mitigated_damage) * 0.50))
		survey_last_damage_source = source_name
		_change_actor_hp(0, -endured_damage)
		damage_received_total += endured_damage
		hits_received_total += 1
		strength_remaining = maxf(strength_remaining, 5.0)
		_apply_source_condition_to_player(source_name)
		_add_effect("endure", impact, endured_damage)
		_set_message("You take the hit and gain Strength for 5 seconds.")
		if player_hp <= 0:
			_begin_death()
		return
	var interrupted_kind := String(player_action.get("kind", "idle"))
	var interrupted_action := player_action.duplicate(true)
	var damage_received := mitigated_damage
	# The frost pays out on the next hit and is spent doing it. Without that release the
	# slow compounds into a spiral with no way out; with it, being frosted is a warning
	# that the next mistake costs double rather than a sentence.
	# Frost never amplifies frost. Cold Front ticks four times, so without this the second
	# tick is amplified by the first, and ice quietly becomes the hardest-hitting element
	# in the game -- measured at 46 damage from a single front. "Ice never kills you; it
	# decides who does" only holds if the thing it makes deadlier is somebody else.
	var frost_standing := 0.0 if ("ice" in source_name.to_lower() or "frost" in source_name.to_lower() or "cold" in source_name.to_lower()) else player_frost_fraction()
	if frost_standing > 0.0:
		damage_received = int(round(float(damage_received) * (1.0 + FROST_DAMAGE_AMPLIFY * frost_standing)))
		player_conditions.erase("frost")
		player_condition_buildup["frost"] = 0.0
		survey_frost_amplified_hits += 1
		_add_effect("condition", impact, 0, {"condition": "frost_shatter"})
	var was_protected := player_hit_protection_remaining > 0.0
	survey_last_damage_source = source_name
	_change_actor_hp(0, -damage_received)
	damage_received_total += damage_received
	if was_protected: protected_damage_total += damage_received
	if uses_energy_rules() and interrupted_kind == "dodge" and float(interrupted_action.get("elapsed", 0.0)) > float(interrupted_action.get("evade_end", 0.0)):
		dodge_recovery_damage_total += damage_received
	if player_exhaustion_remaining > 0.0001: exhaustion_damage_received_total += damage_received
	hits_received_total += 1
	player_posture = maxf(0.0, player_posture - posture_damage)
	player_posture_recovery_delay = 1.15
	player_energy_regen_delay = maxf(player_energy_regen_delay, ENERGY_REGEN_DELAY)
	if not _aggregate_damage_effect(aggregate_key, impact, damage_received):
		_add_effect("hurt", impact, damage_received, {"aggregate": aggregate_key} if aggregate_key != "" else {})
	_break_stealth_for_hostile_action()
	_apply_source_condition_to_player(source_name)
	if player_hp <= 0:
		_begin_death()
		return
	# Additional hits remain dangerous while the player is reeling, but they do
	# not restart or lengthen the reaction. Because time freezes as soon as this
	# original commitment ends, the player is guaranteed another decision
	# instead of being held in an indefinite stagger chain by a crowd.
	#
	# The protection window extends that guarantee past return of control, so the
	# response the player actually chose gets to happen. Without the tail, control
	# returns and a second attacker can take it away again before the new action
	# reaches its first meaningful frame -- which is the "stunlock" the surveys
	# report. Damage and posture above are already applied: this guarantees agency,
	# not safety, and a lethal hit still kills through it.
	if interrupted_kind in ["hit_reaction", "stagger"] or _player_reaction_completed_this_tick or was_protected:
		interruptions_prevented_total += 1
		if was_protected and interrupted_kind not in ["hit_reaction", "stagger"]:
			_add_effect("strain", impact, 0, {"direction": (player_pos - impact).normalized()})
			_set_message("The %s lands, but cannot take your answer away." % source_name)
		else:
			_set_message("The %s strikes while you reel, but cannot prolong the stagger." % source_name)
		return
	var posture_broken := player_posture <= 0.0001
	# Steadier Cast. A caster's real vulnerability is not that a hit hurts, it is that a hit
	# ERASES the thing they were doing -- which is why this is the Mage track's first node
	# and why it is the difference between a caster that functions and one that does not.
	# It holds against a light blow only; a heavy one, or one that breaks posture, still
	# takes the spell.
	if interrupted_kind in ["cast", "circle"] and _cast_survives_light_hit() and not posture_broken and posture_damage < 3.0:
		interruptions_prevented_total += 1
		_add_effect("strain", impact, 0, {"direction": (player_pos - impact).normalized()})
		_set_message("The %s lands, but the working holds." % source_name)
		return
	var guard_remaining := float(player_action.get("guard_remaining", 0.0))
	if guard_remaining > 0.0 and not posture_broken:
		var received_posture := posture_damage
		if received_posture <= guard_remaining:
			player_action["guard_remaining"] = maxf(0.0, guard_remaining - received_posture)
			_add_effect("strain", impact, 0, {"direction": (player_pos - impact).normalized()})
			_set_message("The %s hurts you, but your committed action holds." % source_name)
			return
	if interrupted_kind == "rally" and not bool(interrupted_action.get("rally_started", false)):
		rally_cooldown = 3.0
	if interrupted_kind == "combo": set_attack_hold(false)
	if interrupted_kind in ["attack", "sweep", "combo", "art_combo", "twin_fang"]: _survey_finalize_strike_probe("interrupted")
	_reset_building_force()
	_break_player_combo()
	var reaction_duration := 0.78 if posture_broken else minf(0.60, 0.20 + 0.08 * float(damage))
	# Reaching this line means no protection was active -- the guard above returns
	# otherwise -- so arming unconditionally is non-refreshing by construction.
	# Action time advances on personal tempo, so convert to world seconds before
	# adding the tail; otherwise a fast character's reaction would end sooner in
	# world time and silently earn a longer guarantee than a slow one.
	player_hit_protection_remaining = reaction_duration / maxf(0.01, _player_personal_tempo()) + POST_HIT_PROTECTION_TAIL
	player_action = _action("stagger" if posture_broken else "hit_reaction", reaction_duration, Vector2.ZERO)
	player_action.merge({
		"reaction_contact": impact,
		"reaction_direction": (player_pos - impact).normalized(),
		"interrupted_action": interrupted_action,
		"reaction_source": source_name,
	}, true)
	_add_effect("posture_break" if posture_broken else "interrupt", impact, 0, {"direction": (player_pos - impact).normalized(), "strength": 1.65 if posture_broken else 1.3})
	_set_message("Your posture breaks." if posture_broken else "The %s breaks your commitment." % source_name)

# Each element's two abilities differ in WHICH meter they load, not just how hard. Fire
# decides near or far: the breath buries you in burn for moderate damage, the ball hits
# harder and barely kindles. Ice decides evadability: the lance is dodgeable and dumps
# frost, the front is hard to leave and trickles it.
const CONDITION_BUILDUP_BY_SOURCE := {
	"fire breath": 11.0,
	"fireball": 3.0,
	# Tuned so frost is reachable within a fight but never from one ability alone. The
	# Warrior's threshold is 23.7, so a lance plus a full front (13.0 + 13.6) crosses it
	# and so does a second lance -- while either on its own leaves the player cold but
	# not slowed. The element is supposed to compound, not to land.
	"frost lance": 13.0,
	"cold front": 3.4,
}

func _apply_source_condition_to_player(source_name: String) -> void:
	var lowered := source_name.to_lower()
	var authored := float(CONDITION_BUILDUP_BY_SOURCE.get(lowered, 4.0))
	if "ice" in lowered or "frost" in lowered or "cold" in lowered: _apply_actor_condition_buildup(0, "frost", authored)
	elif "fire" in lowered or "burn" in lowered: _apply_actor_condition_buildup(0, "burning", authored)

func _trigger_clean_dodge(impact: Vector2, source_name: String) -> void:
	if not bool(player_action.get("clean_dodge_triggered", false)):
		player_action["clean_dodge_triggered"] = true
		perfect_dodges += 1
		if has_track_rank("evasion", 3) and String(player_action.get("kind", "")) == "dodge":
			if track_choice("evasion_style") == "sidestep":
				counterstep_remaining = 3.0
				_set_message("Clean Sidestep: your next basic attack gains Counterstep.")
			elif track_choice("evasion_style") == "long_roll":
				dodge_cooldown = maxf(0.0, dodge_cooldown - 2.0)
				_set_message("Clean Long Roll: Evasive Rhythm restores readiness.")
			else:
				_set_message("The %s crosses only empty space." % source_name)
		else:
			_set_message("The %s misses your evasive movement." % source_name)
		if String(player_action.get("kind", "")) == "vault": clean_evade_vault_total += 1
		else: clean_evade_dodge_total += 1
		if has_track_rank("acrobat", 3):
			turnabout_primed_total += 1
			turnabout_remaining = 4.0
			_set_message("CLEAN EVADE — Turnabout empowers your next basic attack.")
	_add_effect("evade", impact)

func _begin_death() -> void:
	if death_pending: return
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		_complete_survey_room("death")
		return
	var previous_shadow_erased := bool(lost_xp.get("active", false))
	var xp_before_death := carried_xp
	var forgotten_cells := unanchored_discovery_count()
	var shortcut_forgotten := unanchored_shortcut()
	if bool(mode_config["shadow_enabled"]):
		if bool(lost_xp.get("active", false)): lost_xp = {"active": false, "amount": 0, "pos": Vector2.ZERO, "layer": current_layer}
		var provisional_xp := maxi(0, carried_xp - secured_xp)
		if provisional_xp > 0: lost_xp = {"active": true, "amount": provisional_xp, "pos": player_pos, "layer": current_layer}
		carried_xp = secured_xp
	else:
		lost_xp = {"active": false, "amount": 0, "pos": Vector2.ZERO}
	death_report = {
		"retained_xp": carried_xp,
		"shadow_xp": int(lost_xp.get("amount", 0)),
		"lost_xp": xp_before_death if not bool(mode_config["shadow_enabled"]) else 0,
		"forgotten_cells": forgotten_cells,
		"shortcut_forgotten": shortcut_forgotten,
		"previous_shadow_erased": previous_shadow_erased,
	}
	death_pending = true
	player_action = _idle_action()
	projectiles.clear()
	hazards.clear()
	upgrade_pending = false
	upgrade_choices.clear()
	upgrade_context = ""
	if String(mode_config["death_policy"]) == "end_run":
		_set_message("You have fallen. The expedition is over.")
	else:
		_set_message("You have fallen. Your unanchored XP remains where you died.")

func _counter_source(source_id: int) -> void:
	for enemy in enemies:
		if _enemy_on_current_layer(enemy) and int(enemy["id"]) == source_id and Vector2(enemy["pos"]).distance_to(player_pos) <= 155.0:
			_change_actor_hp(enemy, -2)
			_add_effect("hit", Vector2(enemy["pos"]), 2)
			counter_hits += 1
			return

func _is_evasive() -> bool:
	if String(player_action["kind"]) not in ["dodge", "vault"]:
		return false
	var elapsed := float(player_action["elapsed"])
	return elapsed >= float(player_action.get("evade_start", 0.08)) and elapsed <= float(player_action.get("evade_end", 0.38))

func _is_perfect_dodge() -> bool:
	return false

func _is_blocking(source_id: int, incoming_from: Vector2 = Vector2.ZERO) -> bool:
	if String(player_action["kind"]) != "block":
		return false
	var elapsed := float(player_action["elapsed"])
	if elapsed < float(player_action["startup"]) or elapsed > float(player_action["active_end"]):
		return false
	if incoming_from.length_squared() > 0.01:
		return _within_arc(player_facing, incoming_from, deg_to_rad(65.0))
	for enemy in enemies:
		if _enemy_on_current_layer(enemy) and int(enemy["id"]) == source_id:
			var incoming := Vector2(enemy["pos"]) - player_pos
			return _within_arc(player_facing, incoming, deg_to_rad(65.0))
	return false

func _is_enduring() -> bool:
	if String(player_action["kind"]) != "endure":
		return false
	var elapsed := float(player_action["elapsed"])
	return elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"])

func _update_effects(dt: float) -> void:
	var active: Array[Dictionary] = []
	for effect in effects:
		effect["elapsed"] = float(effect["elapsed"]) + dt
		if float(effect["elapsed"]) < float(effect["duration"]):
			active.append(effect)
	effects = active

func _add_effect(kind: String, position: Vector2, amount: int = 0, details: Dictionary = {}) -> void:
	var duration := 1.10 if kind == "anchor" else 0.90 if kind == "recover" else 0.62 if kind in ["hit", "hurt", "endure"] else 0.42
	var effect := {"kind": kind, "pos": position, "elapsed": 0.0, "duration": duration, "amount": amount, "layer": current_layer}
	effect.merge(details, true)
	_add_effect_entity(effect)

func _remove_dead_enemies() -> void:
	var has_dead := false
	for enemy in enemies:
		if int(enemy["hp"]) <= 0:
			has_dead = true
			break
	if not has_dead: return
	var living: Array[Dictionary] = []
	var defeated_areas: Dictionary = {}
	for enemy in enemies:
		if int(enemy["hp"]) > 0:
			living.append(enemy)
		else:
			enemies_defeated += 1
			if mode_id == ModeRulesScript.COMBAT_SURVEY:
				# Everything still standing, alerted and near the body that just fell. Zero
				# means this one was fought alone, which is what "picked them off one by
				# one" looks like in data.
				var witnesses := 0
				for other in enemies:
					if int(other.get("id", -1)) == int(enemy.get("id", -2)): continue
					if int(other.get("hp", 0)) <= 0 or not _enemy_on_current_layer(other): continue
					if String(other.get("awareness", "idle")) != "alerted": continue
					if Vector2(other["pos"]).distance_to(Vector2(enemy["pos"])) > ENGAGEMENT_RADIUS: continue
					witnesses += 1
				if witnesses == 0: survey_isolated_kills += 1
				else: survey_engaged_kills += 1
			var kind := String(enemy["kind"])
			carried_xp += _xp_for_enemy(kind)
			defeated_areas[int(enemy.get("area_id", 0))] = true
			if kind in ["warden", "werewolf"]:
				_boss_defeated = true
				if mode_id == ModeRulesScript.EXPEDITION:
					trial_complete = true
					_set_message("The %s falls. The expedition is complete." % ("Werewolf" if kind == "werewolf" else "Warden"))
				else: _set_message("The Warden falls. The path beyond remains anchored.")
			else: _set_message("The %s falls. XP gained." % kind)
	_replace_enemy_actors(living)
	if mode_id == ModeRulesScript.COMBAT_SURVEY and enemies.is_empty():
		_complete_survey_room("victory")
		return
	for area_id in defeated_areas:
		var still_alive := false
		for enemy in enemies:
			if int(enemy.get("area_id", -1)) == int(area_id): still_alive = true
		if not still_alive and int(area_id) >= 0:
			rooms_cleared = maxi(rooms_cleared, _cleared_area_count())

func _xp_for_enemy(kind: String) -> int:
	return int(CombatCatalogScript.enemy_fact(kind, "xp"))

func _cleared_area_count() -> int:
	var occupied: Dictionary = {}
	for enemy in enemies: occupied[int(enemy.get("area_id", -1))] = true
	var count := 0
	for area in areas:
		var area_id := int(area["id"])
		if not occupied.has(area_id): count += 1
	return count

func _build_navigation() -> void:
	_flow_target_cell = Vector2i(-999999, -999999)
	_flow_next_cell.clear()
	var cache_key := _navigation_cache_key()
	if _navigation_cache.has(cache_key):
		navigation = _navigation_cache[cache_key]
		performance_metrics["navigation_build_ms"] = 0.0
		performance_metrics["navigation_cache_hit"] = true
		return
	var build_start := Time.get_ticks_usec()
	navigation = AStarGrid2D.new()
	performance_metrics["navigation_cache_hit"] = false
	var has_current_shapes := false
	for shape in _loaded_floor_shapes:
		if String(shape.get("layer", current_layer)) == current_layer:
			has_current_shapes = true
			break
	if not has_current_shapes and not floor_shapes.is_empty():
		_loaded_floor_shapes.clear()
		_build_shape_spatial_index()
		for shape in floor_shapes:
			if String(shape.get("layer", current_layer)) == current_layer:
				_loaded_floor_shapes.append(shape)
				if loaded_region_ids.is_empty(): loaded_region_ids[int(shape.get("part_id", -1))] = true
	_build_wall_spatial_index()
	if _loaded_floor_shapes.is_empty():
		performance_metrics["navigation_build_ms"] = float(Time.get_ticks_usec() - build_start) / 1000.0
		return
	var bounds := _shape_bounds(_loaded_floor_shapes[0])
	for shape in _loaded_floor_shapes: bounds = bounds.merge(_shape_bounds(shape))
	bounds = bounds.grow(NAV_CELL * 2.0).intersection(Rect2(Vector2.ZERO, world_size))
	var start := Vector2i(int(floor(bounds.position.x / NAV_CELL)), int(floor(bounds.position.y / NAV_CELL)))
	var finish := Vector2i(int(ceil(bounds.end.x / NAV_CELL)), int(ceil(bounds.end.y / NAV_CELL)))
	navigation.region = Rect2i(start, Vector2i(maxi(1, finish.x - start.x), maxi(1, finish.y - start.y)))
	navigation.cell_size = Vector2(NAV_CELL, NAV_CELL)
	navigation.offset = Vector2(NAV_CELL * 0.5, NAV_CELL * 0.5)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(navigation.region.position.x, navigation.region.end.x):
		for y in range(navigation.region.position.y, navigation.region.end.y):
			var cell := Vector2i(x, y)
			var center := navigation.get_point_position(cell)
			var solid := not _point_on_loaded_floor(center)
			for wall in _nearby_walls(center, 40.0):
				if _circle_intersects_rect(center, 34.0, wall):
					solid = true
					break
			navigation.set_point_solid(cell, solid)
	_navigation_cache[cache_key] = navigation
	performance_metrics["navigation_build_ms"] = float(Time.get_ticks_usec() - build_start) / 1000.0

func _navigation_cache_key() -> String:
	var region_ids: Array = loaded_region_ids.keys()
	region_ids.sort()
	return "%s|%s|%s" % [current_layer, region_ids, hash(walls)]

func prewarm_expedition_navigation() -> void:
	if mode_id not in [ModeRulesScript.EXPEDITION, ModeRulesScript.COMBAT_SURVEY] or areas.is_empty(): return
	var started := Time.get_ticks_usec()
	var original_area_id := current_area_id
	for area_value in areas:
		var area := Dictionary(area_value)
		if String(area.get("layer", current_layer)) != current_layer: continue
		current_area_id = int(area["id"])
		_refresh_loaded_region_content()
		walls.assign(base_walls)
		_build_wall_spatial_index()
		_build_navigation()
	current_area_id = original_area_id
	_apply_shortcut_world_state()
	performance_metrics["navigation_prewarm_ms"] = float(Time.get_ticks_usec() - started) / 1000.0

func _navigation_direction(enemy: Dictionary, target: Vector2) -> Vector2:
	var origin := Vector2(enemy["pos"])
	var direct := (target - origin).normalized()
	if navigation.region.size == Vector2i.ZERO: return direct
	var from_cell := _nearest_open_cell(_world_to_nav(origin))
	var target_cell := _nearest_open_cell(_world_to_nav(target))
	if target.distance_to(player_pos) <= NAV_CELL * 0.75:
		_ensure_player_flow_field(target_cell)
		if _flow_next_cell.has(from_cell):
			var next_cell := Vector2i(_flow_next_cell[from_cell])
			if next_cell != from_cell:
				return _local_avoidance_direction(enemy, (navigation.get_point_position(next_cell) - origin).normalized())
	var cached_target := Vector2i(enemy.get("nav_target_cell", Vector2i(-999999, -999999)))
	var path: Array = enemy.get("nav_path", [])
	if cached_target != target_cell or path.is_empty():
		path = navigation.get_id_path(from_cell, target_cell, true)
		enemy["nav_target_cell"] = target_cell
		enemy["nav_path"] = path
	else:
		while path.size() > 1 and Vector2i(path[0]) != from_cell: path.pop_front()
		enemy["nav_path"] = path
	var desired := direct
	if path.size() >= 2: desired = (navigation.get_point_position(path[1]) - origin).normalized()
	elif path.size() == 1: desired = direct
	return _local_avoidance_direction(enemy, desired)

func _ensure_player_flow_field(target_cell: Vector2i) -> void:
	if target_cell == _flow_target_cell and not _flow_next_cell.is_empty(): return
	_flow_target_cell = target_cell
	_flow_next_cell.clear()
	if not navigation.is_in_boundsv(target_cell) or navigation.is_point_solid(target_cell): return
	var frontier: Array[Vector2i] = [target_cell]
	var head := 0
	_flow_next_cell[target_cell] = target_cell
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	while head < frontier.size():
		var current := frontier[head]
		head += 1
		for direction in directions:
			var neighbor := current + direction
			if _flow_next_cell.has(neighbor) or not navigation.is_in_boundsv(neighbor) or navigation.is_point_solid(neighbor): continue
			if direction.x != 0 and direction.y != 0:
				if navigation.is_point_solid(current + Vector2i(direction.x, 0)) or navigation.is_point_solid(current + Vector2i(0, direction.y)): continue
			_flow_next_cell[neighbor] = current
			frontier.append(neighbor)

func _world_to_nav(position: Vector2) -> Vector2i:
	var cell := Vector2i(int(floor(position.x / NAV_CELL)), int(floor(position.y / NAV_CELL)))
	return Vector2i(clampi(cell.x, navigation.region.position.x, navigation.region.end.x - 1), clampi(cell.y, navigation.region.position.y, navigation.region.end.y - 1))

func _nearest_open_cell(origin: Vector2i) -> Vector2i:
	if navigation.is_in_boundsv(origin) and not navigation.is_point_solid(origin): return origin
	for radius in range(1, 6):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				var candidate := Vector2i(x, y)
				if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate): return candidate
	return Vector2i.ZERO

func _local_avoidance_direction(enemy: Dictionary, desired: Vector2) -> Vector2:
	if desired.length_squared() < 0.001: return Vector2.ZERO
	var origin := Vector2(enemy["pos"])
	var radius := float(enemy["radius"])
	var actor_id := int(enemy["id"])
	var local_walls := _nearby_walls(origin, radius + 58.0)
	var local_enemies := _nearby_enemies(origin, radius + 115.0)
	var separation := _crowd_separation_direction(enemy, local_enemies)
	var preferred := desired.normalized()
	if separation.length_squared() > 0.001:
		preferred = (preferred + separation * 1.35).normalized()
	var side := 1.0 if actor_id % 2 == 0 else -1.0
	for base in [preferred, desired.normalized()]:
		for angle in [0.0, 0.42 * side, -0.42 * side, 0.82 * side, -0.82 * side, 1.22 * side, -1.22 * side, 1.57 * side, -1.57 * side]:
			var candidate := Vector2(base).rotated(float(angle)).normalized()
			# Check both the next physical step and a short look-ahead. This
			# prevents choosing a direction that is technically free one frame
			# at a time but immediately feeds the actor back into the blockage.
			if not _can_occupy_with_context(origin + candidate * 10.0, radius, actor_id, local_walls, local_enemies): continue
			if _can_occupy_with_context(origin + candidate * 42.0, radius, actor_id, local_walls, local_enemies): return candidate
	return Vector2.ZERO

func _crowd_separation_direction(enemy: Dictionary, nearby: Array[Dictionary] = []) -> Vector2:
	var origin := Vector2(enemy["pos"])
	var radius := float(enemy["radius"])
	var local_enemies := nearby
	if local_enemies.is_empty(): local_enemies = _nearby_enemies(origin, radius + 125.0)
	var pressure := Vector2.ZERO
	for other in local_enemies:
		if not _enemy_on_current_layer(other) or int(other["id"]) == int(enemy["id"]) or int(other.get("hp", 0)) <= 0: continue
		var offset := origin - Vector2(other["pos"])
		var distance := offset.length()
		# Begin separating before bodies physically bunch together. The larger
		# comfort band preserves several attack lanes and denies effortless herding.
		var comfort := radius + float(other["radius"]) + 44.0
		if distance >= comfort: continue
		var away := offset / distance if distance > 0.001 else Vector2.RIGHT.rotated(float(int(enemy["id"]) % 8) * PI * 0.25)
		pressure += away * (comfort - distance) / comfort
	return pressure.limit_length(1.0) if pressure.length_squared() > 0.001 else Vector2.ZERO

func _can_occupy_with_context(position: Vector2, radius: float, actor_id: int, local_walls: Array[Rect2], local_enemies: Array[Dictionary]) -> bool:
	if not _inside_world(position, radius): return false
	# A barrier stops whichever side did not raise it, so enemies must route around the
	# player's wall exactly as the player routes around theirs.
	if _point_in_barrier(position, radius, actor_id):
		survey_barrier_blocks += 1
		return false
	for wall in local_walls:
		if _circle_intersects_rect(position, radius, wall): return false
	if actor_id != 0 and position.distance_to(player_pos) < radius + PLAYER_RADIUS: return false
	for enemy in local_enemies:
		if not _enemy_on_current_layer(enemy) or int(enemy["id"]) == actor_id or int(enemy["hp"]) <= 0: continue
		# Light bodies do not block the PLAYER -- they are displaced instead, in
		# _displace_light_bodies. Enemies still collide with each other normally, so
		# formations keep their shape and only the player parts a crowd.
		if actor_id == 0 and _enemy_is_pushable(enemy): continue
		if position.distance_to(Vector2(enemy["pos"])) < radius + float(enemy["radius"]):
			# You have just walked into it, so you know it is there. Heavy bodies stop the
			# player dead, and the renderer draws an enemy only when the player can SEE it --
			# so an unseen Shield, Brute, Knight or Ox was a wall with nothing on screen, in a
			# spot that was open before it arrived and open again once it moved. That is the
			# invisible-combat-math rule broken in its most literal form: a solid object with
			# no representation. Touching it reveals it.
			if actor_id == 0 and not bool(enemy.get("touch_revealed", false)):
				enemy["touch_revealed"] = true
				survey_blind_collisions += 1
				_set_message("You walk into something you had not seen.")
			return false
	return _actor_footprint_on_floor(position, radius)

func _can_occupy(position: Vector2, radius: float, actor_id: int, ignore_bodies: bool = false) -> bool:
	if not _inside_world(position, radius): return false
	if _point_in_barrier(position, radius, actor_id): return false
	for wall in _nearby_walls(position, radius + 8.0):
		if _circle_intersects_rect(position, radius, wall): return false
	if not _actor_footprint_on_floor(position, radius): return false
	if ignore_bodies: return true
	if actor_id != 0 and position.distance_to(player_pos) < radius + PLAYER_RADIUS: return false
	for enemy in _nearby_enemies(position, radius + 80.0):
		if not _enemy_on_current_layer(enemy) or int(enemy.get("id", -1)) == actor_id or int(enemy.get("hp", 0)) <= 0: continue
		if actor_id == 0 and _enemy_is_pushable(enemy): continue
		if position.distance_to(Vector2(enemy["pos"])) < radius + float(enemy["radius"]): return false
	return true

func _enemy_is_pushable(enemy: Dictionary) -> bool:
	# A committed charge is a mass in motion and is never shoved aside, whatever the body
	# weighs. This matters most for the Hound, at mass 0.75 the most shoveable thing in
	# the game and the one that spends the most time charging -- walking through a
	# charging animal is not a defence anyone authored. The Ox already said this with its
	# `unstoppable` flag; the rule belongs to charges rather than to one kind.
	if String(Dictionary(enemy.get("action", {})).get("kind", "")) == "charge": return false
	return _enemy_mass(String(enemy.get("kind", ""))) < PUSHABLE_MASS

# Shove overlapping light bodies out along the contact normal. A tight ring of five
# left 14 of 24 movement directions completely dead, which reads as the controls
# failing rather than as pressure -- and it got worse as bodies grew.
#
# The push is exactly the overlap and no more: the player parts a crowd, it does not
# launch anyone. Displacement runs through _move_actor so a body cannot be shoved
# through a wall or into another body; when it genuinely has nowhere to go it stays,
# which is the cornered case and should feel tight.
func _displace_light_bodies(position: Vector2, radius: float, local_enemies: Array[Dictionary]) -> void:
	for enemy in local_enemies:
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		if not _enemy_is_pushable(enemy): continue
		var enemy_pos := Vector2(enemy["pos"])
		var overlap := radius + float(enemy["radius"]) - position.distance_to(enemy_pos)
		if overlap <= 0.0: continue
		var away := enemy_pos - position
		if away.length_squared() < 0.001: away = Vector2(enemy.get("facing", Vector2.DOWN))
		if away.length_squared() < 0.001: away = Vector2.RIGHT
		_set_enemy_position(enemy, _move_actor(enemy_pos, away.normalized() * overlap, float(enemy["radius"]), int(enemy["id"])))

func _move_actor(origin: Vector2, delta: Vector2, radius: float, actor_id: int, ignore_bodies: bool = false) -> Vector2:
	# Both axis candidates share the same nearby geometry. Querying the spatial
	# buckets twice was a major dense-crowd movement cost with no behavior gain.
	var query_padding := delta.length() + 8.0
	var local_walls := _nearby_walls(origin, radius + query_padding)
	var local_enemies := _nearby_enemies(origin, radius + delta.length() + 80.0)
	# An unstoppable charge is stopped by geometry, never by a body.
	var no_bodies: Array[Dictionary] = []
	var blocking_bodies := no_bodies if ignore_bodies else local_enemies
	var result := origin
	var candidate := Vector2(origin.x + delta.x, origin.y)
	if _can_occupy_with_context(candidate, radius, actor_id, local_walls, blocking_bodies):
		result.x = candidate.x
	candidate = Vector2(result.x, origin.y + delta.y)
	if _can_occupy_with_context(candidate, radius, actor_id, local_walls, blocking_bodies):
		result.y = candidate.y
	if actor_id == 0: _displace_light_bodies(result, radius, local_enemies)
	return result

func _position_blocked(position: Vector2, radius: float, actor_id: int) -> bool:
	return not _can_occupy(position, radius, actor_id)

func _inside_world(position: Vector2, radius: float) -> bool:
	return position.x >= radius and position.y >= radius and position.x <= world_size.x - radius and position.y <= world_size.y - radius

func _actor_footprint_on_floor(position: Vector2, radius: float) -> bool:
	for direction in [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		if not _point_on_loaded_floor(position + direction * radius * 0.72): return false
	return true

func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(nearest) < radius * radius

# One gate for every movement that writes a position directly instead of going through
# _move_actor -- Windstep today, anything that blinks or is thrown tomorrow. `_inside_world`
# alone was not enough: the survey arena is a disc inside a much larger world, so a Windstep
# could clear the arena entirely and still be "inside the world", which is how an Air Caster
# threw itself off the edge of the map. The floor is the boundary that matters.
func _teleport_allowed(position: Vector2, radius: float, actor_id: int) -> bool:
	return _can_occupy(position, radius, actor_id, true)

func _point_in_wall(point: Vector2) -> bool:
	for wall in _nearby_walls(point, 2.0):
		if wall.has_point(point):
			return true
	return false

func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var distance := from.distance_to(to)
	if distance <= 0.001: return true
	var center := (from + to) * 0.5
	for wall in _nearby_walls(center, distance * 0.5 + 4.0):
		if _segment_intersects_rect(from, to, wall): return false
	return true

func _segment_intersects_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	# Liang-Barsky clipping gives an exact answer with a fixed amount of work,
	# replacing the former 12-unit ray march and its repeated spatial queries.
	var delta := finish - start
	var minimum := 0.0
	var maximum := 1.0
	for axis in range(2):
		var start_value := start.x if axis == 0 else start.y
		var delta_value := delta.x if axis == 0 else delta.y
		var rect_minimum := rect.position.x if axis == 0 else rect.position.y
		var rect_maximum := rect.end.x if axis == 0 else rect.end.y
		if absf(delta_value) <= 0.000001:
			if start_value < rect_minimum or start_value > rect_maximum: return false
			continue
		var first := (rect_minimum - start_value) / delta_value
		var second := (rect_maximum - start_value) / delta_value
		if first > second:
			var swap := first
			first = second
			second = swap
		minimum = maxf(minimum, first)
		maximum = minf(maximum, second)
		if minimum > maximum: return false
	return maximum > 0.0001 and minimum < 0.9999

func _update_exploration(force: bool = false) -> void:
	if not run_active: return
	var secret_changed := _update_secret_passages()
	var center_cell := _visibility_cell(player_pos)
	if not force and not secret_changed and center_cell == _visibility_anchor_cell: return
	if center_cell != _visibility_anchor_cell:
		# The active enemy set is distance-based. Refresh it at the same stable
		# 50-unit cadence as visibility rather than scanning the whole run at
		# 120 Hz or leaving an old three-region set alive after the player moves.
		_invalidate_active_enemy_cache()
	var profile_start := Time.get_ticks_usec()
	_visibility_anchor_cell = center_cell
	_visibility_anchor = (Vector2(center_cell) + Vector2(0.5, 0.5)) * VISIBILITY_CELL
	visible_cells.clear()
	var player_sight := float(player_properties.get("vision_range", SIGHT_RANGE))
	var radius_cells := int(ceil(player_sight / VISIBILITY_CELL))
	var added_discovery := false
	for x in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
		for y in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
			var cell := Vector2i(x, y)
			var point := (Vector2(cell) + Vector2(0.5, 0.5)) * VISIBILITY_CELL
			if point.distance_to(_visibility_anchor) > player_sight or not _point_on_floor(point): continue
			if _visibility_cells_have_line(center_cell, cell):
				visible_cells[cell] = true
				if not discovered_cells.has(cell):
					discovered_cells[cell] = true
					discovery_log.append(cell)
					added_discovery = true
	visibility_revision += 1
	if added_discovery: discovery_revision += 1
	var previous_area_id := current_area_id
	current_area_id = _area_id_at_position(player_pos, current_layer)
	if current_area_id >= 0:
		for area in areas:
			if int(area["id"]) == current_area_id and String(area.get("layer", current_layer)) == current_layer:
				area["discovered"] = true
				break
	_store_current_layer_discovery()
	if current_area_id >= 0 and current_area_id != previous_area_id: _apply_shortcut_world_state()
	# Leveling is deliberately player-initiated through the character sheet.
	# Expedition permits it whenever time is idle; Campaign permits it only at a Waystone.
	performance_metrics["visibility_ms"] = float(Time.get_ticks_usec() - profile_start) / 1000.0
	performance_metrics["visibility_cells"] = visible_cells.size()

func _visibility_cells_have_line(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	if from_cell == to_cell: return true
	var current := from_cell
	var dx := absi(to_cell.x - from_cell.x)
	var dy := absi(to_cell.y - from_cell.y)
	var step_x := 1 if from_cell.x < to_cell.x else -1
	var step_y := 1 if from_cell.y < to_cell.y else -1
	var error := dx - dy
	while current != to_cell:
		var doubled := error * 2
		if doubled > -dy:
			error -= dy
			current.x += step_x
		if doubled < dx:
			error += dx
			current.y += step_y
		if current != to_cell and _visibility_opaque_cells.has(current): return false
	return true

func _area_is_clear(area_id: int) -> bool:
	for enemy in enemies:
		if int(enemy.get("area_id", -1)) == area_id and int(enemy.get("hp", 0)) > 0: return false
	return true

func _enemy_on_current_layer(enemy: Dictionary) -> bool:
	return String(enemy.get("layer", current_layer)) == current_layer

func _visibility_cell(position: Vector2) -> Vector2i:
	return Vector2i(int(floor(position.x / VISIBILITY_CELL)), int(floor(position.y / VISIBILITY_CELL)))

func is_visible(position: Vector2, cells: Dictionary = visible_cells) -> bool:
	return cells.has(_visibility_cell(position))

func is_discovered(position: Vector2, cells: Dictionary = discovered_cells) -> bool:
	return cells.has(_visibility_cell(position))

func _point_on_floor(point: Vector2) -> bool:
	return _point_on_floor_for_layer(point, current_layer)

func _point_on_floor_for_layer(point: Vector2, layer: String) -> bool:
	if not floor_shapes.is_empty():
		var buckets: Dictionary = _shape_buckets_by_layer.get(layer, {})
		for shape in Array(buckets.get(_spatial_cell_for_point(point), [])):
			if _shape_contains_point(shape, point): return true
		return false
	for area in areas:
		if String(area.get("layer", layer)) == layer and Rect2(area["rect"]).has_point(point): return true
	for connection in connections:
		if String(connection.get("layer", layer)) == layer and Rect2(connection["corridor"]).has_point(point): return true
	return false

func _point_on_loaded_floor(point: Vector2) -> bool:
	var buckets: Dictionary = _shape_buckets_by_layer.get(current_layer, {})
	for shape in Array(buckets.get(_spatial_cell_for_point(point), [])):
		if loaded_region_ids.has(int(shape.get("part_id", -1))) and _shape_contains_point(shape, point): return true
	return false

func _shape_contains_point(shape: Dictionary, point: Vector2) -> bool:
	var radius := float(shape.get("radius", 0.0))
	if String(shape.get("kind", "circle")) == "circle": return point.distance_to(Vector2(shape["center"])) <= radius
	return _distance_to_segment(point, Vector2(shape["from"]), Vector2(shape["to"])) <= radius

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.001: return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * amount)

func _area_id_at_position(point: Vector2, layer: String) -> int:
	var candidate_ids: Dictionary = {}
	var buckets: Dictionary = _shape_buckets_by_layer.get(layer, {})
	for shape in Array(buckets.get(_spatial_cell_for_point(point), [])):
		if String(shape.get("layer", layer)) != layer: continue
		var part_id := int(shape.get("part_id", -1))
		if part_id < 0: continue
		var radius := float(shape.get("radius", 0.0))
		var inside := point.distance_to(Vector2(shape["center"])) <= radius if String(shape.get("kind", "circle")) == "circle" else _distance_to_segment(point, Vector2(shape["from"]), Vector2(shape["to"])) <= radius
		if inside: candidate_ids[part_id] = true
	var best_id := -1
	var best_distance := INF
	for area in areas:
		var area_id := int(area["id"])
		if not candidate_ids.has(area_id) or String(area.get("layer", layer)) != layer: continue
		var distance := point.distance_squared_to(Vector2(area["center"]))
		if distance < best_distance:
			best_distance = distance
			best_id = area_id
	return best_id

func _part_has_discovered_cell(part_id: int, layer: String) -> bool:
	for cell in discovered_cells:
		var point := (Vector2(cell) + Vector2(0.5, 0.5)) * VISIBILITY_CELL
		for shape in floor_shapes:
			if int(shape.get("part_id", -1)) != part_id or String(shape.get("layer", layer)) != layer: continue
			var radius := float(shape.get("radius", 0.0))
			if String(shape.get("kind", "circle")) == "circle" and point.distance_to(Vector2(shape["center"])) <= radius: return true
			if String(shape.get("kind", "")) == "capsule" and _distance_to_segment(point, Vector2(shape["from"]), Vector2(shape["to"])) <= radius: return true
	return false

func current_area_name() -> String:
	for area in areas:
		if int(area["id"]) == current_area_id: return String(area.get("name", "Area %d" % (current_area_id + 1)))
	return String(Dictionary(world_layers.get(current_layer, {})).get("name", "Unknown Path"))

func current_ground_color() -> Color:
	for area in areas:
		if int(area["id"]) == current_area_id and area.has("profile"):
			var profile := Dictionary(area["profile"])
			if profile.has("ground_color"): return Color(String(profile["ground_color"]))
	var definition: Dictionary = world_layers.get(current_layer, {})
	return Color(String(definition.get("ground_color", "314247")))

func floor_surface_color_at(point: Vector2, layer: String = "") -> Color:
	var target_layer := current_layer if layer == "" else layer
	var selected_shape: Dictionary = {}
	var selected_priority := -1
	var buckets: Dictionary = _shape_buckets_by_layer.get(target_layer, {})
	for shape_value in Array(buckets.get(_spatial_cell_for_point(point), [])):
		var shape: Dictionary = shape_value
		if not _shape_contains_point(shape, point): continue
		var semantic := String(shape.get("semantic", "clearing"))
		var priority := 30 if semantic == "main_path" else 20 if semantic == "side_path" else 10
		if priority > selected_priority:
			selected_priority = priority
			selected_shape = shape
	var profile: Dictionary = {}
	if not selected_shape.is_empty():
		var part_id := int(selected_shape.get("part_id", -1))
		for area in areas:
			if int(area["id"]) == part_id and String(area.get("layer", target_layer)) == target_layer:
				profile = Dictionary(area.get("profile", {}))
				break
	if profile.is_empty(): return Color(String(Dictionary(world_layers.get(target_layer, {})).get("ground_color", "314247")))
	var semantic := String(selected_shape.get("semantic", "clearing"))
	if semantic == "main_path" and profile.has("main_surface_color"): return Color(String(profile["main_surface_color"]))
	if semantic == "side_path" and profile.has("side_surface_color"): return Color(String(profile["side_surface_color"]))
	return Color(String(profile.get("clearing_color", profile.get("ground_color", "314247"))))

func _rect_has_discovered_cell(rect: Rect2) -> bool:
	for cell in discovered_cells:
		var point := (Vector2(cell) + Vector2(0.5, 0.5)) * VISIBILITY_CELL
		if rect.has_point(point): return true
	return false

func _within_arc(facing: Vector2, offset: Vector2, half_angle: float) -> bool:
	if offset.length_squared() < 0.01:
		return true
	return absf(facing.normalized().angle_to(offset.normalized())) <= half_angle

func _segment_distance_to_point(a: Vector2, b: Vector2, point: Vector2) -> float:
	var segment := b - a
	if segment.length_squared() < 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(a + segment * t)

func snapshot(lightweight: bool = false) -> Dictionary:
	var result := {
		"time": simulation_time,
		"player_pos": player_pos,
		"player_facing": player_facing,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_energy": player_energy,
		"player_max_energy": player_max_energy,
		"player_exhaustion_remaining": player_exhaustion_remaining,
		"player_energy_regen_delay": player_energy_regen_delay,
		"combat_rules": combat_rules,
		"player_posture": player_posture,
		"player_posture_max": player_posture_max,
		"loadout_id": loadout_id,
		"defense_id": defense_id,
		"player_actor": player_actor(),
		"player_action": player_action.duplicate(true),
		"enemies": _timeline_enemies() if lightweight else enemies.duplicate(true),
		"sensed_enemies": _sensed_enemy_presentations(),
		"walls": [] if lightweight else walls.duplicate(),
		"projectiles": projectiles.duplicate(true),
		"hazards": hazards.duplicate(true),
		"barriers": barriers.duplicate(true),
		"circle_pos": circle_pos,
		"circle_remaining": circle_remaining,
		"circle_radius": circle_radius(),
		"effects": effects.duplicate(true),
		"cooldowns": cooldowns.duplicate(true),
		"dodge_cooldown": dodge_cooldown,
		"block_cooldown": block_cooldown,
		"endure_cooldown": endure_cooldown,
		"skill_cooldown": skill_cooldown,
		"rally_cooldown": rally_cooldown,
		"advance_cooldown": advance_cooldown,
		"main_ability_cooldown": main_ability_cooldown,
		"subclass_ability_cooldown": subclass_ability_cooldown,
		"weapon_sequence_cooldown": weapon_sequence_cooldown,
		"terminal_combo_recoveries_total": terminal_combo_recoveries_total,
		"survey_stealth_entries_total": survey_stealth_entries_total,
		"survey_stealth_cancels_total": survey_stealth_cancels_total,
		"survey_stealth_quick_reentries_total": survey_stealth_quick_reentries_total,
		"survey_stealth_hidden_time_total": survey_stealth_hidden_time_total,
		"survey_stealth_energy_paid_total": survey_stealth_energy_paid_total,
		"stealth_energy_paid": stealth_energy_paid,
		"skill_cooldown_max": skill_cooldown_max,
		"advance_cooldown_max": advance_cooldown_max,
		"main_ability_cooldown_max": main_ability_cooldown_max,
		"subclass_ability_cooldown_max": subclass_ability_cooldown_max,
		"terminal_combo_recovery_time_total": terminal_combo_recovery_time_total,
		"direct_attack_uses_total": direct_attack_uses_total,
		"dodge_style_uses_total": dodge_style_uses_total.duplicate(true),
		"dodge_vulnerable_time_total": dodge_vulnerable_time_total,
		"dodge_recovery_damage_total": dodge_recovery_damage_total,
		"stealth_remaining": stealth_remaining,
		"turnabout_remaining": turnabout_remaining,
		"player_hit_protection_remaining": player_hit_protection_remaining,
		"aimed_enemy_id": aimed_enemy_id,
		"aimed_remaining": aimed_remaining,
		"player_condition_buildup": player_condition_buildup.duplicate(true),
		"player_conditions": player_conditions.duplicate(true),
		"rally_remaining": rally_remaining,
		"rally_end_after_action": rally_end_after_action,
		"rally_break_extension_used": rally_break_extension_used,
		"building_force_chain": building_force_chain,
		"counterstep_remaining": counterstep_remaining,
		"strength_remaining": strength_remaining,
		"potions": potions,
		"healing_capacity": healing_capacity(),
		"consumable_slots": consumable_slots.duplicate(true),
		"world_pickups": world_pickups.duplicate(true),
		"pending_pickup": pending_pickup.duplicate(true),
		"trial_complete": trial_complete,
		"boss_defeated": _boss_defeated,
		"run_seed": run_seed,
		"upgrade_pending": upgrade_pending,
		"upgrade_choices": upgrade_choices.duplicate(),
		"upgrades": upgrades.duplicate(),
		"rooms_cleared": rooms_cleared,
		"enemies_defeated": enemies_defeated,
		"damage_dealt": damage_dealt,
		"damage_received_total": damage_received_total,
		"hits_received_total": hits_received_total,
		"protected_damage_total": protected_damage_total,
		"interruptions_prevented_total": interruptions_prevented_total,
		"potions_used_total": potions_used_total,
		"energy_spent_total": energy_spent_total,
		"energy_depleted_total": energy_depleted_total,
		"energy_overdraw_total": energy_overdraw_total,
		"energy_regenerated_total": energy_regenerated_total,
		"overexertion_count": overexertion_count,
		"winded_time_total": winded_time_total,
		"energy_blocked_continuations": energy_blocked_continuations,
		"exhaustion_damage_received_total": exhaustion_damage_received_total,
		"exhaustion_move_time_total": exhaustion_move_time_total,
		"exhaustion_wait_time_total": exhaustion_wait_time_total,
		"exhaustion_other_time_total": exhaustion_other_time_total,
		"exhausted_dodge_total": exhausted_dodge_total,
		"exhausted_dodge_max_chain": exhausted_dodge_max_chain,
		"exhaustion_start_samples": exhaustion_start_samples,
		"exhaustion_start_alerted_sum": exhaustion_start_alerted_sum,
		"exhaustion_start_clear": exhaustion_start_clear,
		"exhaustion_start_pending": exhaustion_start_pending,
		"exhaustion_start_reacting_sum": exhaustion_start_reacting_sum,
		"exhaustion_end_samples": exhaustion_end_samples,
		"exhaustion_end_alerted_sum": exhaustion_end_alerted_sum,
		"exhaustion_end_clear": exhaustion_end_clear,
		"exhaustion_start_soonest_sum": exhaustion_start_soonest_sum,
		"exhaustion_start_nearest_sum": exhaustion_start_nearest_sum,
		"energy_starved_time_total": energy_starved_time_total,
		"energy_combo_starved_time_total": energy_combo_starved_time_total,
		"exhaustion_threatened_time_total": exhaustion_threatened_time_total,
		"message": message,
		"run_active": run_active,
		"mode_id": mode_id,
		"mode_config": mode_config.duplicate(true),
		"progression_mode": progression_mode,
		"map_presentation": map_presentation,
		"areas": [] if lightweight else areas.duplicate(true),
		"connections": [] if lightweight else connections.duplicate(true),
		"route_recipe": [] if lightweight else route_recipe.duplicate(true),
		"run_graph": {} if lightweight else run_graph.duplicate(true),
		"locale_catalog": {} if lightweight else locale_catalog.duplicate(true),
		"floor_shapes": [] if lightweight else floor_shapes.duplicate(true),
		"terrain_features": [] if lightweight else terrain_features.duplicate(true),
		"geometry_style": geometry_style,
		"world_size": world_size,
		"waystones": [] if lightweight else waystones.duplicate(true),
		"shortcuts": [] if lightweight else shortcuts.duplicate(true),
		"secret_passages": [] if lightweight else secret_passages.duplicate(true),
		"transitions": [] if lightweight else transitions.duplicate(true),
		"world_layers": {} if lightweight else world_layers.duplicate(true),
		"current_layer": current_layer,
		"active_waystone_id": active_waystone_id,
		"shortcut_unlocked": shortcut_unlocked,
		"bonfire_pos": bonfire_pos,
		"shortcut_unlock_pos": shortcut_unlock_pos,
		"shortcut_start_pos": shortcut_start_pos,
		"visible_cells": {} if lightweight else visible_cells.duplicate(),
		"discovered_cells": {} if lightweight else discovered_cells.duplicate(),
		"discovered_cells_by_layer": {} if lightweight else discovered_cells_by_layer.duplicate(true),
		"current_area_id": current_area_id,
		"carried_xp": carried_xp,
		"secured_xp": secured_xp,
		"lost_xp": lost_xp.duplicate(true),
		"death_report": death_report.duplicate(true),
		"last_anchor_report": last_anchor_report.duplicate(true),
		"upgrade_count": upgrade_count,
		"upgrade_ranks": upgrade_ranks.duplicate(true),
		"track_property_ranks": track_property_ranks.duplicate(true),
		"track_ranks": track_ranks.duplicate(true),
		"track_choices": track_choices.duplicate(true),
		"equipment_slots": equipment_slots.duplicate(true),
		"upgrade_context": upgrade_context,
		"death_pending": death_pending,
		"run_failed": run_failed,
		"survey_profile": survey_profile,
		"survey_room_number": survey_room_number,
		"survey_room_seed": survey_room_seed,
		"survey_feedback_pending": survey_feedback_pending,
		"survey_run_ending": survey_run_ending,
		"survey_end_reason": survey_end_reason,
		"survey_session": survey_session.duplicate(true),
		"anchor_state": {} if lightweight else anchor_state.duplicate(true),
		"performance_metrics": performance_metrics.duplicate(),
	}
	result.merge(StateFieldSchemaScript.capture(self, StateFieldSchemaScript.SNAPSHOT), true)
	if lightweight:
		result["enemies"] = _timeline_enemies()
		result["visible_cells"] = {}
		result["discovered_cells"] = {}
	return result

func _sensed_enemy_presentations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not has_track_rank("sharpshooter", 1): return result
	var awareness := int(player_attributes.get("awareness", 0))
	for enemy in _nearby_enemies(player_pos, 1050.0):
		if int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
		var enemy_pos := Vector2(enemy["pos"])
		var directly_seen := enemy_visible_to_player(enemy) and is_visible(enemy_pos) and _has_line_of_sight(player_pos, enemy_pos)
		if directly_seen: continue
		if awareness + 3 < int(Dictionary(enemy.get("attributes", {})).get("stealth", 0)): continue
		var jitter := Vector2.RIGHT.rotated(float(int(enemy["id"]) % 16) * TAU / 16.0) * 32.0
		result.append({"id": int(enemy["id"]), "pos": enemy_pos + jitter, "layer": String(enemy.get("layer", current_layer))})
	return result

func _timeline_enemies() -> Array[Dictionary]:
	var nearby: Array[Dictionary] = []
	_refresh_active_enemy_cache()
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy: Dictionary = enemies[index]
		if Vector2(enemy["pos"]).distance_to(player_pos) <= ACTIVE_ENEMY_RADIUS and enemy_visible_to_player(enemy): nearby.append(_enemy_presentation(enemy))
	return nearby

func _enemy_presentation(enemy: Dictionary) -> Dictionary:
	var result := StateFieldSchemaScript.project_entity(enemy, "enemy", StateFieldSchemaScript.PRESENTATION)
	if not result.has("layer"): result["layer"] = current_layer
	return result

func save_run(path: String = "user://waystone-expedition.save") -> bool:
	var profile_start := Time.get_ticks_usec()
	var payload_start := profile_start
	var payload := _build_save_payload()
	performance_metrics["last_save_payload_ms"] = float(Time.get_ticks_usec() - payload_start) / 1000.0
	var write_start := Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_var(payload, true)
	file.flush()
	performance_metrics["last_save_bytes"] = file.get_position()
	performance_metrics["last_save_write_ms"] = float(Time.get_ticks_usec() - write_start) / 1000.0
	performance_metrics["last_save_ms"] = float(Time.get_ticks_usec() - profile_start) / 1000.0
	return true

func _build_save_payload() -> Dictionary:
	# Generated geography is reconstructed from mode + seed during load. Keeping
	# it out of every autosave avoids repeatedly copying and serializing immutable
	# floor, wall, feature, connection, layer, and Waystone definitions.
	var result := {
		"save_version": SAVE_VERSION,
		"time": simulation_time,
		"player_pos": player_pos,
		"player_facing": player_facing,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_energy": player_energy,
		"player_max_energy": player_max_energy,
		"player_overexertion_pending": player_overexertion_pending,
		"player_exhaustion_remaining": player_exhaustion_remaining,
		"player_energy_regen_delay": player_energy_regen_delay,
		"combat_rules": combat_rules,
		"player_posture": player_posture,
		"player_posture_max": player_posture_max,
		"player_posture_recovery_delay": player_posture_recovery_delay,
		"player_move_speed": player_move_speed,
		"player_attack_duration": player_attack_duration,
		"player_attack_startup": player_attack_startup,
		"player_attack_active_end": player_attack_active_end,
		"player_damage_min": player_damage_min,
		"player_damage_max": player_damage_max,
		"player_attack_reach": player_attack_reach,
		"player_attributes": player_attributes.duplicate(true),
		"player_properties": player_properties.duplicate(true),
		"martial_foundation": martial_foundation.duplicate(true),
		"player_weapon_frame": player_weapon_frame,
		"player_weapon_art_library": player_weapon_art_library.duplicate(),
		"player_equipped_weapon_art": player_equipped_weapon_art,
		"equipment_slots": equipment_slots.duplicate(true),
		"track_property_ranks": track_property_ranks.duplicate(true),
		"track_ranks": track_ranks.duplicate(true),
		"track_choices": track_choices.duplicate(true),
		"defense_cooldown_multiplier": _defense_cooldown_multiplier,
		"skill_cooldown_multiplier": _skill_cooldown_multiplier,
		"loadout_id": loadout_id,
		"enemies": enemies.duplicate(true),
		"projectiles": projectiles.duplicate(true),
		"hazards": hazards.duplicate(true),
		"barriers": barriers.duplicate(true),
		"circle_pos": circle_pos,
		"circle_remaining": circle_remaining,
		"circle_radius": circle_radius(),
		"effects": effects.duplicate(true),
		"cooldowns": cooldowns.duplicate(true),
		"dodge_cooldown": dodge_cooldown,
		"block_cooldown": block_cooldown,
		"endure_cooldown": endure_cooldown,
		"skill_cooldown": skill_cooldown,
		"rally_cooldown": rally_cooldown,
		"advance_cooldown": advance_cooldown,
		"main_ability_cooldown": main_ability_cooldown,
		"subclass_ability_cooldown": subclass_ability_cooldown,
		"weapon_sequence_cooldown": weapon_sequence_cooldown,
		"terminal_combo_recoveries_total": terminal_combo_recoveries_total,
		"survey_stealth_entries_total": survey_stealth_entries_total,
		"survey_stealth_cancels_total": survey_stealth_cancels_total,
		"survey_stealth_quick_reentries_total": survey_stealth_quick_reentries_total,
		"survey_stealth_hidden_time_total": survey_stealth_hidden_time_total,
		"survey_stealth_energy_paid_total": survey_stealth_energy_paid_total,
		"stealth_energy_paid": stealth_energy_paid,
		"skill_cooldown_max": skill_cooldown_max,
		"advance_cooldown_max": advance_cooldown_max,
		"main_ability_cooldown_max": main_ability_cooldown_max,
		"subclass_ability_cooldown_max": subclass_ability_cooldown_max,
		"terminal_combo_recovery_time_total": terminal_combo_recovery_time_total,
		"direct_attack_uses_total": direct_attack_uses_total,
		"dodge_style_uses_total": dodge_style_uses_total.duplicate(true),
		"dodge_vulnerable_time_total": dodge_vulnerable_time_total,
		"dodge_recovery_damage_total": dodge_recovery_damage_total,
		"stealth_remaining": stealth_remaining,
		"stealth_cooldown_pending": stealth_cooldown_pending,
		"assassination_window_remaining": assassination_window_remaining,
		"turnabout_remaining": turnabout_remaining,
		"player_hit_protection_remaining": player_hit_protection_remaining,
		"aimed_enemy_id": aimed_enemy_id,
		"aimed_remaining": aimed_remaining,
		"player_condition_buildup": player_condition_buildup.duplicate(true),
		"player_conditions": player_conditions.duplicate(true),
		"rally_remaining": rally_remaining,
		"rally_end_after_action": rally_end_after_action,
		"rally_break_extension_used": rally_break_extension_used,
		"building_force_chain": building_force_chain,
		"counterstep_remaining": counterstep_remaining,
		"strength_remaining": strength_remaining,
		"potions": potions,
		"healing_capacity": healing_capacity(),
		"consumable_slots": consumable_slots.duplicate(true),
		"world_pickups": world_pickups.duplicate(true),
		"pending_pickup": pending_pickup.duplicate(true),
		"trial_complete": trial_complete,
		"boss_defeated": _boss_defeated,
		"run_seed": run_seed,
		"upgrade_pending": upgrade_pending,
		"upgrade_choices": upgrade_choices.duplicate(),
		"upgrades": upgrades.duplicate(),
		"upgrade_count": upgrade_count,
		"upgrade_ranks": upgrade_ranks.duplicate(true),
		"upgrade_context": upgrade_context,
		"rooms_cleared": rooms_cleared,
		"enemies_defeated": enemies_defeated,
		"damage_dealt": damage_dealt,
		"damage_received_total": damage_received_total,
		"hits_received_total": hits_received_total,
		"protected_damage_total": protected_damage_total,
		"interruptions_prevented_total": interruptions_prevented_total,
		"potions_used_total": potions_used_total,
		"energy_spent_total": energy_spent_total,
		"energy_depleted_total": energy_depleted_total,
		"energy_overdraw_total": energy_overdraw_total,
		"energy_regenerated_total": energy_regenerated_total,
		"energy_regen_delay_time_total": energy_regen_delay_time_total,
		"energy_regen_active_time_total": energy_regen_active_time_total,
		"overexertion_count": overexertion_count,
		"winded_time_total": winded_time_total,
		"energy_blocked_continuations": energy_blocked_continuations,
		"exhaustion_damage_received_total": exhaustion_damage_received_total,
		"exhaustion_move_time_total": exhaustion_move_time_total,
		"exhaustion_wait_time_total": exhaustion_wait_time_total,
		"exhaustion_other_time_total": exhaustion_other_time_total,
		"exhausted_dodge_total": exhausted_dodge_total,
		"exhausted_dodge_max_chain": exhausted_dodge_max_chain,
		"exhaustion_start_samples": exhaustion_start_samples,
		"exhaustion_start_alerted_sum": exhaustion_start_alerted_sum,
		"exhaustion_start_clear": exhaustion_start_clear,
		"exhaustion_start_pending": exhaustion_start_pending,
		"exhaustion_start_reacting_sum": exhaustion_start_reacting_sum,
		"exhaustion_end_samples": exhaustion_end_samples,
		"exhaustion_end_alerted_sum": exhaustion_end_alerted_sum,
		"exhaustion_end_clear": exhaustion_end_clear,
		"exhaustion_start_soonest_sum": exhaustion_start_soonest_sum,
		"exhaustion_start_nearest_sum": exhaustion_start_nearest_sum,
		"energy_starved_time_total": energy_starved_time_total,
		"energy_combo_starved_time_total": energy_combo_starved_time_total,
		"exhaustion_threatened_time_total": exhaustion_threatened_time_total,
		"message": message,
		"run_active": run_active,
		"mode_id": mode_id,
		"progression_mode": progression_mode,
		"map_presentation": map_presentation,
		"current_layer": current_layer,
		"active_waystone_id": active_waystone_id,
		"shortcut_unlocked": shortcut_unlocked,
		"shortcuts": shortcuts.duplicate(true),
		"secret_passages": secret_passages.duplicate(true),
		"discovered_cells_by_layer": discovered_cells_by_layer.duplicate(true),
		"current_area_id": current_area_id,
		"carried_xp": carried_xp,
		"secured_xp": secured_xp,
		"lost_xp": lost_xp.duplicate(true),
		"death_report": death_report.duplicate(true),
		"last_anchor_report": last_anchor_report.duplicate(true),
		"death_pending": death_pending,
		"run_failed": run_failed,
		"anchor_state": anchor_state.duplicate(true),
		"perfect_dodges": perfect_dodges,
		"counter_hits": counter_hits,
		"successful_blocks": successful_blocks,
		"successful_endures": successful_endures,
		"survey_profile": survey_profile,
		"survey_room_number": survey_room_number,
		"survey_room_seed": survey_room_seed,
		"survey_feedback_pending": survey_feedback_pending,
		"survey_run_ending": survey_run_ending,
		"survey_end_reason": survey_end_reason,
		"survey_room_definition": survey_room_definition.duplicate(true),
		"survey_room_entry": survey_room_entry.duplicate(true),
		"survey_pending_record": survey_pending_record.duplicate(true),
		"survey_session": survey_session.duplicate(true),
		"survey_last_report": survey_last_report.duplicate(true),
		"survey_action_counts": survey_action_counts.duplicate(true),
		"survey_last_damage_source": survey_last_damage_source,
		"survey_current_view_mode": survey_current_view_mode,
		"survey_room_view_modes": survey_room_view_modes.duplicate(),
		"survey_view_switches": survey_view_switches,
		"survey_empty_melee_contacts": survey_empty_melee_contacts,
		"survey_strike_diagnostics": survey_strike_diagnostics.duplicate(true),
		"rng_state": rng.state,
	}
	result.merge(StateFieldSchemaScript.capture(self, StateFieldSchemaScript.SAVE), true)
	for error in SaveMigrationsScript.validate_current(result, SAVE_VERSION): push_error(String(error))
	return result

func load_run(path: String = "user://waystone-expedition.save") -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var value: Variant = file.get_var(true)
	if not value is Dictionary: return false
	var payload: Dictionary = value
	# Every `..._stamina...` key written before 0.2.61 is read under its new name. The
	# rename cost the historical record, which was known and accepted when it was
	# scheduled -- but a save is not the historical record, it is a run in progress, and
	# silently resetting someone's Energy to a default is a different thing entirely.
	for saved_key in payload.keys():
		var key_name := String(saved_key)
		if not key_name.contains("stamina"): continue
		var renamed := key_name.replace("stamina", "energy")
		if not payload.has(renamed): payload[renamed] = payload[saved_key]
	var save_version := int(payload.get("save_version", 0))
	var normalized_payload := SaveMigrationsScript.normalize(payload, SAVE_VERSION)
	if normalized_payload.is_empty(): return false
	payload = normalized_payload
	var migration_notices: Array[String] = []
	# v19 replaces the prototype Wayfarer progression with the first durable
	# class/subclass sheet.  Importing older ranks would silently produce an
	# invalid build, so old prototype runs deliberately start fresh.
	var saved_loadout := String(payload.get("loadout_id", "warrior"))
	loadout_id = saved_loadout if CombatCatalogScript.loadout_ids().has(saved_loadout) else "warrior"
	map_presentation = String(payload.get("map_presentation", "full"))
	if save_version == 21:
		_apply_loadout()
		run_active = false
		mode_id = ModeRulesScript.EXPEDITION
		mode_config = ModeRulesScript.definition(mode_id)
		progression_mode = String(mode_config["upgrade_policy"])
		message = "The v0.1.0 combat framework requires a new run. Choose a character."
		return true
	if save_version < 5:
		_apply_loadout()
		run_active = false
		mode_id = ModeRulesScript.EXPEDITION
		mode_config = ModeRulesScript.definition(mode_id)
		progression_mode = String(mode_config["upgrade_policy"])
		message = "Choose a class and mode for the prototype world."
		return true
	var saved_mode := String(payload.get("mode_id", payload.get("progression_mode", "auto")))
	mode_id = ModeRulesScript.normalize(saved_mode)
	mode_config = ModeRulesScript.definition(mode_id)
	progression_mode = String(mode_config["upgrade_policy"])
	run_seed = int(payload.get("run_seed", run_seed))
	start_run(loadout_id, mode_id, run_seed, String(payload.get("survey_profile", "encounter")), String(payload.get("combat_rules", "energy")))
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		var saved_survey_room := int(payload.get("survey_room_number", 1))
		if saved_survey_room > 1:
			survey_room_number = saved_survey_room - 1
			_load_next_survey_room()
	current_layer = String(payload.get("current_layer", current_layer))
	active_waystone_id = String(payload.get("active_waystone_id", active_waystone_id))
	for stone in waystones:
		if String(stone["id"]) == active_waystone_id: bonfire_pos = Vector2(stone["pos"])
	run_active = bool(payload.get("run_active", true))
	player_pos = Vector2(payload.get("player_pos", player_pos))
	var position_was_migrated := false
	if not _point_on_floor(player_pos):
		player_pos = _player_start
		position_was_migrated = true
	player_facing = Vector2(payload.get("player_facing", Vector2.UP))
	player_hp = int(payload.get("player_hp", player_max_hp))
	player_max_hp = int(payload.get("player_max_hp", player_max_hp))
	player_energy = float(payload.get("player_energy", player_max_energy))
	player_max_energy = float(payload.get("player_max_energy", player_max_energy))
	player_overexertion_pending = bool(payload.get("player_overexertion_pending", false))
	player_exhaustion_remaining = float(payload.get("player_exhaustion_remaining", 0.0))
	player_energy_regen_delay = float(payload.get("player_energy_regen_delay", 0.0))
	player_posture = float(payload.get("player_posture", player_posture))
	player_posture_max = float(payload.get("player_posture_max", player_posture_max))
	player_posture_recovery_delay = float(payload.get("player_posture_recovery_delay", 0.0))
	player_move_speed = float(payload.get("player_move_speed", player_move_speed))
	# Movement speed is a loadout rule rather than earned run state. Apply the
	# corrected Warrior relationship to existing saves as well as fresh runs.
	if loadout_id == "warrior": player_move_speed = WARRIOR_MOVE_SPEED
	player_attack_duration = float(payload.get("player_attack_duration", player_attack_duration))
	player_attack_startup = float(payload.get("player_attack_startup", player_attack_startup))
	player_attack_active_end = float(payload.get("player_attack_active_end", player_attack_active_end))
	# v0.0.49 raises the Wayfarer's base health and tightens sword commitment.
	# Preserve an existing run's earned health bonus and its current health ratio,
	# rather than unexpectedly healing it or removing its learned progress.
	if save_version < 18:
		var legacy_health_ratio := float(player_hp) / maxf(1.0, float(player_max_hp))
		var earned_health_bonus := maxi(0, player_max_hp - 9)
		player_max_hp = 20 + earned_health_bonus
		player_hp = clampi(roundi(legacy_health_ratio * player_max_hp), 1, player_max_hp)
		player_attack_duration = 0.90
		player_attack_startup = 0.27
		player_attack_active_end = 0.50
	player_damage_min = int(payload.get("player_damage_min", player_damage_min))
	player_damage_max = int(payload.get("player_damage_max", player_damage_max))
	player_attack_reach = float(payload.get("player_attack_reach", player_attack_reach))
	if save_version >= 14:
		player_attributes = Dictionary(payload.get("player_attributes", player_attributes)).duplicate(true)
		player_properties = Dictionary(payload.get("player_properties", player_properties)).duplicate(true)
		martial_foundation = Dictionary(payload.get("martial_foundation", martial_foundation)).duplicate(true)
		player_weapon_frame = String(payload.get("player_weapon_frame", player_weapon_frame))
		player_weapon_art_library.assign(Array(payload.get("player_weapon_art_library", player_weapon_art_library)))
		player_equipped_weapon_art = String(payload.get("player_equipped_weapon_art", player_equipped_weapon_art))
	if save_version >= 15:
		equipment_slots = Dictionary(payload.get("equipment_slots", equipment_slots)).duplicate(true)
		track_property_ranks = Dictionary(payload.get("track_property_ranks", {})).duplicate(true)
	track_ranks = Dictionary(payload.get("track_ranks", _empty_character_track_ranks())).duplicate(true)
	track_choices = Dictionary(payload.get("track_choices", {})).duplicate(true)
	if save_version == 25:
		_migrate_v25_temperament_to_energy()
	# Actions in older saves used the retired forced-Winded state. Migration ends
	# any in-progress commitment and starts the new rule set from a clear resource.
	if save_version < 33: player_energy = player_max_energy
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_energy_regen_delay = 0.0
	_defense_cooldown_multiplier = float(payload.get("defense_cooldown_multiplier", 1.0))
	_skill_cooldown_multiplier = float(payload.get("skill_cooldown_multiplier", 1.0))
	player_action = _idle_action()
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_energy_regen_delay = 0.0
	# v13 introduced a new semantic world grammar and changed Campaign area IDs.
	# Older dynamic actors are regenerated so they cannot survive off-floor in the
	# rewritten geography; learned progression and run statistics remain intact.
	if save_version >= 13:
		_replace_enemy_actors(Array(payload.get("enemies", enemies)).duplicate(true))
		projectiles.assign(Array(payload.get("projectiles", [])).duplicate(true))
		hazards.assign(Array(payload.get("hazards", [])).duplicate(true))
		barriers.assign(Array(payload.get("barriers", [])).duplicate(true))
		effects.assign(Array(payload.get("effects", [])).duplicate(true))
	dodge_cooldown = float(payload.get("dodge_cooldown", 0.0))
	block_cooldown = float(payload.get("block_cooldown", 0.0))
	endure_cooldown = float(payload.get("endure_cooldown", 0.0))
	skill_cooldown = float(payload.get("skill_cooldown", 0.0))
	rally_cooldown = float(payload.get("rally_cooldown", 0.0))
	advance_cooldown = float(payload.get("advance_cooldown", 0.0))
	main_ability_cooldown = float(payload.get("main_ability_cooldown", 0.0))
	subclass_ability_cooldown = float(payload.get("subclass_ability_cooldown", 0.0))
	weapon_sequence_cooldown = float(payload.get("weapon_sequence_cooldown", 0.0))
	stealth_remaining = float(payload.get("stealth_remaining", 0.0))
	stealth_cooldown_pending = bool(payload.get("stealth_cooldown_pending", false))
	assassination_window_remaining = float(payload.get("assassination_window_remaining", 0.0))
	turnabout_remaining = float(payload.get("turnabout_remaining", 0.0))
	player_hit_protection_remaining = float(payload.get("player_hit_protection_remaining", 0.0))
	aimed_enemy_id = int(payload.get("aimed_enemy_id", -1))
	aimed_remaining = float(payload.get("aimed_remaining", 0.0))
	player_condition_buildup = Dictionary(payload.get("player_condition_buildup", {})).duplicate(true)
	player_conditions = Dictionary(payload.get("player_conditions", {})).duplicate(true)
	rally_remaining = float(payload.get("rally_remaining", 0.0))
	rally_end_after_action = bool(payload.get("rally_end_after_action", false))
	rally_break_extension_used = bool(payload.get("rally_break_extension_used", false))
	building_force_chain = int(payload.get("building_force_chain", 0))
	counterstep_remaining = float(payload.get("counterstep_remaining", 0.0))
	strength_remaining = float(payload.get("strength_remaining", 0.0))
	var saved_potions := int(payload.get("potions", HEALING_CAPACITY))
	# v20 raises the shared starting capacity from three to five. Preserve spent
	# charges while granting the two newly available slots to a v19 run.
	if save_version == 19: saved_potions += 2
	potions = mini(healing_capacity(), saved_potions)
	if save_version >= 16:
		consumable_slots.assign(Array(payload.get("consumable_slots", _empty_consumable_slots())).duplicate(true))
		world_pickups.assign(Array(payload.get("world_pickups", world_pickups)).duplicate(true))
		pending_pickup = Dictionary(payload.get("pending_pickup", {})).duplicate(true)
	else:
		consumable_slots = _empty_consumable_slots()
		pending_pickup.clear()
	# v0.0.48 moves the initial art into Weaponry. Existing runs that already
	# learned an art retain exactly the same progression investment.
	if save_version < 17 and not player_weapon_art_library.is_empty():
		track_property_ranks["weaponry_art"] = 1
		upgrade_ranks["weaponry_art"] = 1
	trial_complete = bool(payload.get("trial_complete", false))
	_boss_defeated = bool(payload.get("boss_defeated", trial_complete))
	# The former modal upgrade screen was removed in v0.0.45.  Any interrupted
	# legacy choice is safely returned to the character-sheet flow instead.
	upgrade_pending = false
	upgrade_choices.clear()
	upgrade_context = ""
	upgrades.assign(Array(payload.get("upgrades", [])))
	upgrade_count = int(payload.get("upgrade_count", upgrades.size()))
	upgrade_ranks = Dictionary(payload.get("upgrade_ranks", {})).duplicate(true)
	if save_version < 15:
		var legacy_map := {"keen_edge": "weaponry_power", "vitality": "vigilance_health", "quick_hands": "weaponry_handling", "long_reach": "weaponry_impact", "footwork": "vigilance_speed", "readiness": "evasion_cooldown"}
		for legacy_id in legacy_map:
			var legacy_rank := int(upgrade_ranks.get(legacy_id, 0))
			if legacy_rank > 0: track_property_ranks[String(legacy_map[legacy_id])] = legacy_rank
		if player_weapon_art_library.has("prototype_sweeping_cut") and upgrade_count == 0:
			player_weapon_art_library.clear()
			player_equipped_weapon_art = ""
	carried_xp = int(payload.get("carried_xp", 0))
	secured_xp = int(payload.get("secured_xp", carried_xp if save_version < 6 and mode_id == ModeRulesScript.CAMPAIGN_LAB else 0))
	if save_version < 21:
		var old_upgrade_count := upgrade_count
		var refund := 2 * old_upgrade_count * old_upgrade_count + 4 * old_upgrade_count
		var health_ratio := float(player_hp) / maxf(1.0, float(player_max_hp))
		_apply_loadout()
		player_hp = clampi(roundi(health_ratio * player_max_hp), 1, player_max_hp)
		track_ranks = _empty_character_track_ranks()
		track_choices.clear()
		track_property_ranks.clear()
		upgrades.clear()
		upgrade_ranks.clear()
		upgrade_count = 0
		carried_xp += refund
		if mode_id == ModeRulesScript.CAMPAIGN_LAB: secured_xp += refund
		migration_notices.append("Your old training was refunded as XP for the revised disciplines.")
	lost_xp = Dictionary(payload.get("lost_xp", {"active": false, "amount": 0, "pos": Vector2.ZERO})).duplicate(true)
	death_report = Dictionary(payload.get("death_report", {})).duplicate(true)
	last_anchor_report = Dictionary(payload.get("last_anchor_report", {})).duplicate(true)
	# v0.0.22 gates could be bypassed and were not recognizable world objects.
	# Do not import those invalid shortcut states into the corrected topology.
	shortcut_unlocked = bool(payload.get("shortcut_unlocked", false)) if save_version >= 11 else false
	if save_version >= 11:
		var saved_shortcuts: Array = payload.get("shortcuts", [])
		for shortcut in shortcuts:
			for saved in saved_shortcuts:
				if String(saved.get("id", "")) == String(shortcut["id"]): shortcut["unlocked"] = bool(saved.get("unlocked", false))
	if save_version >= 21:
		var saved_secrets: Array = payload.get("secret_passages", [])
		for secret in secret_passages:
			for saved_secret in saved_secrets:
				if String(Dictionary(saved_secret).get("id", "")) == String(secret.get("id", "")):
					secret["revealed"] = bool(Dictionary(saved_secret).get("revealed", false))
	_apply_shortcut_world_state()
	if save_version >= 13:
		visible_cells = Dictionary(payload.get("visible_cells", {})).duplicate()
		discovered_cells_by_layer = Dictionary(payload.get("discovered_cells_by_layer", {})).duplicate(true)
		if discovered_cells_by_layer.is_empty(): discovered_cells_by_layer[current_layer] = Dictionary(payload.get("discovered_cells", {})).duplicate()
		_load_current_layer_discovery()
		current_area_id = int(payload.get("current_area_id", 0))
	else:
		visible_cells.clear()
		discovered_cells.clear()
		discovered_cells_by_layer.clear()
		for layer_id in world_layers: discovered_cells_by_layer[String(layer_id)] = {}
		discovered_cells_by_layer[current_layer] = discovered_cells
		current_area_id = _area_id_at_position(player_pos, current_layer)
	death_pending = bool(payload.get("death_pending", false))
	run_failed = bool(payload.get("run_failed", false))
	rooms_cleared = int(payload.get("rooms_cleared", 0))
	enemies_defeated = int(payload.get("enemies_defeated", 0))
	damage_dealt = int(payload.get("damage_dealt", 0))
	damage_received_total = int(payload.get("damage_received_total", 0))
	hits_received_total = int(payload.get("hits_received_total", 0))
	protected_damage_total = int(payload.get("protected_damage_total", 0))
	interruptions_prevented_total = int(payload.get("interruptions_prevented_total", 0))
	potions_used_total = int(payload.get("potions_used_total", 0))
	energy_spent_total = float(payload.get("energy_spent_total", 0.0))
	energy_depleted_total = float(payload.get("energy_depleted_total", energy_spent_total))
	energy_overdraw_total = float(payload.get("energy_overdraw_total", 0.0))
	energy_regenerated_total = float(payload.get("energy_regenerated_total", 0.0))
	energy_regen_delay_time_total = float(payload.get("energy_regen_delay_time_total", 0.0))
	energy_regen_active_time_total = float(payload.get("energy_regen_active_time_total", 0.0))
	overexertion_count = int(payload.get("overexertion_count", 0))
	winded_time_total = float(payload.get("winded_time_total", 0.0))
	energy_blocked_continuations = int(payload.get("energy_blocked_continuations", 0))
	exhaustion_damage_received_total = int(payload.get("exhaustion_damage_received_total", 0))
	exhaustion_move_time_total = float(payload.get("exhaustion_move_time_total", 0.0))
	exhaustion_wait_time_total = float(payload.get("exhaustion_wait_time_total", 0.0))
	exhaustion_other_time_total = float(payload.get("exhaustion_other_time_total", 0.0))
	exhausted_dodge_total = int(payload.get("exhausted_dodge_total", 0))
	exhausted_dodge_max_chain = int(payload.get("exhausted_dodge_max_chain", 0))
	exhaustion_start_samples = int(payload.get("exhaustion_start_samples", 0))
	exhaustion_start_alerted_sum = int(payload.get("exhaustion_start_alerted_sum", 0))
	exhaustion_start_clear = int(payload.get("exhaustion_start_clear", 0))
	exhaustion_start_pending = int(payload.get("exhaustion_start_pending", 0))
	exhaustion_start_reacting_sum = int(payload.get("exhaustion_start_reacting_sum", 0))
	exhaustion_end_samples = int(payload.get("exhaustion_end_samples", 0))
	exhaustion_end_alerted_sum = int(payload.get("exhaustion_end_alerted_sum", 0))
	exhaustion_end_clear = int(payload.get("exhaustion_end_clear", 0))
	exhaustion_start_soonest_sum = float(payload.get("exhaustion_start_soonest_sum", 0.0))
	exhaustion_start_nearest_sum = float(payload.get("exhaustion_start_nearest_sum", 0.0))
	energy_starved_time_total = float(payload.get("energy_starved_time_total", 0.0))
	energy_combo_starved_time_total = float(payload.get("energy_combo_starved_time_total", 0.0))
	exhaustion_threatened_time_total = float(payload.get("exhaustion_threatened_time_total", 0.0))
	terminal_combo_recoveries_total = int(payload.get("terminal_combo_recoveries_total", 0))
	survey_stealth_entries_total = int(payload.get("survey_stealth_entries_total", 0))
	survey_stealth_cancels_total = int(payload.get("survey_stealth_cancels_total", 0))
	survey_stealth_quick_reentries_total = int(payload.get("survey_stealth_quick_reentries_total", 0))
	survey_stealth_hidden_time_total = float(payload.get("survey_stealth_hidden_time_total", 0.0))
	survey_stealth_energy_paid_total = float(payload.get("survey_stealth_energy_paid_total", 0.0))
	stealth_energy_paid = float(payload.get("stealth_energy_paid", 0.0))
	skill_cooldown_max = float(payload.get("skill_cooldown_max", 6.5))
	advance_cooldown_max = float(payload.get("advance_cooldown_max", 6.0))
	main_ability_cooldown_max = float(payload.get("main_ability_cooldown_max", 12.0))
	subclass_ability_cooldown_max = float(payload.get("subclass_ability_cooldown_max", 8.0))
	if payload.has("cooldowns"):
		var saved_cooldowns := Dictionary(payload["cooldowns"])
		for slot in COOLDOWN_SLOT_DEFAULTS:
			if not saved_cooldowns.has(slot): continue
			var saved_slot := Dictionary(saved_cooldowns[slot])
			_set_cooldown_remaining(String(slot), float(saved_slot.get("remaining", cooldown_remaining(String(slot)))))
			_set_cooldown_maximum(String(slot), float(saved_slot.get("maximum", cooldown_maximum(String(slot)))))
	terminal_combo_recovery_time_total = float(payload.get("terminal_combo_recovery_time_total", 0.0))
	direct_attack_uses_total = int(payload.get("direct_attack_uses_total", 0))
	dodge_style_uses_total = Dictionary(payload.get("dodge_style_uses_total", {})).duplicate(true)
	dodge_vulnerable_time_total = float(payload.get("dodge_vulnerable_time_total", 0.0))
	dodge_recovery_damage_total = int(payload.get("dodge_recovery_damage_total", 0))
	perfect_dodges = int(payload.get("perfect_dodges", 0))
	counter_hits = int(payload.get("counter_hits", 0))
	successful_blocks = int(payload.get("successful_blocks", 0))
	successful_endures = int(payload.get("successful_endures", 0))
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		survey_profile = String(payload.get("survey_profile", "encounter"))
		survey_room_number = int(payload.get("survey_room_number", 1))
		survey_room_seed = int(payload.get("survey_room_seed", _survey_seed_for_room(survey_room_number)))
		survey_feedback_pending = bool(payload.get("survey_feedback_pending", false))
		survey_run_ending = bool(payload.get("survey_run_ending", false))
		survey_end_reason = String(payload.get("survey_end_reason", ""))
		survey_room_definition = Dictionary(payload.get("survey_room_definition", survey_room_definition)).duplicate(true)
		survey_room_entry = Dictionary(payload.get("survey_room_entry", survey_room_entry)).duplicate(true)
		survey_pending_record = Dictionary(payload.get("survey_pending_record", {})).duplicate(true)
		survey_session = Dictionary(payload.get("survey_session", survey_session)).duplicate(true)
		survey_last_report = Dictionary(payload.get("survey_last_report", {})).duplicate(true)
		survey_action_counts = Dictionary(payload.get("survey_action_counts", {})).duplicate(true)
		survey_last_damage_source = String(payload.get("survey_last_damage_source", ""))
		survey_current_view_mode = String(payload.get("survey_current_view_mode", "isometric"))
		survey_room_view_modes.assign(Array(payload.get("survey_room_view_modes", [survey_current_view_mode])))
		survey_view_switches = int(payload.get("survey_view_switches", 0))
		survey_empty_melee_contacts = int(payload.get("survey_empty_melee_contacts", 0))
		survey_strike_diagnostics.assign(Array(payload.get("survey_strike_diagnostics", [])))
	simulation_time = float(payload.get("time", 0.0))
	message = String(payload.get("message", message))
	if position_was_migrated or save_version < 13:
		migration_notices.push_front("The forest shifted. Its old geography fades from memory.")
	if not migration_notices.is_empty():
		message = " ".join(migration_notices)
	rng.state = int(payload.get("rng_state", rng.state))
	_next_enemy_id = 1
	for index in range(enemies.size()):
		var enemy: Dictionary = _hydrate_enemy_combat_profile(enemies[index])
		enemy["action"] = _idle_action()
		enemy["is_moving"] = false
		enemy["last_motion"] = Vector2.ZERO
		enemy["stalled_time"] = 0.0
		enemy.erase("nav_path")
		enemy.erase("nav_target_cell")
		_next_enemy_id = maxi(_next_enemy_id, int(enemy["id"]) + 1)
		enemies[index] = enemy
	anchor_state = Dictionary(payload.get("anchor_state", {})).duplicate(true) if save_version >= 13 else {}
	if bool(mode_config["waystone_available"]) and anchor_state.is_empty(): _capture_anchor_history()
	_apply_shortcut_world_state()
	_visibility_anchor = Vector2.INF
	_visibility_anchor_cell = Vector2i(-999999, -999999)
	_update_exploration(true)
	last_timeline.clear()
	return true

func restart() -> void:
	start_run(loadout_id, mode_id, run_seed)

func _set_message(text: String) -> void:
	message = text
	message_changed.emit(message)
