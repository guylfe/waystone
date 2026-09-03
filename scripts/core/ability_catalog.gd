class_name AbilityCatalog
extends RefCounted

# Authored identity for the Elementalist spellbook and the enemy abilities it
# borrows. RunState still owns simulation and AI choice; this catalog is the one
# place that says what a spell costs, how it is targeted, how long the player's
# cast commits, and how the corresponding enemy cast is presented.

const PLACE_RANGE := 420.0

const PLAYER_ATTACK_ACTION_KINDS := ["attack", "sweep", "combo", "art_combo", "twin_fang"]
const ENEMY_ATTACK_ACTION_KINDS := ["melee", "dodge_strike", "charge", "claw_combo", "pounce_combo", "shoot", "hurl", "slam", "sunder", "fire_breath", "earth_wall", "cold_front", "frost_lance", "gale"]
const ENERGY_REGEN_ACTION_KINDS := ["move", "wait", "rally", "take_aim", "potion", "consumable", "vault", "block", "endure"]

const ELEMENT_STAGE_SPELLS := {
	"element_fire": ["fireball", "fire_breath"],
	"element_ice": ["frost_lance", "cold_front"],
	"element_earth": ["earth_wall", "sunder"],
	"element_air": ["gale", "windstep"],
}

const SPELLS := {
	# Spell prices are literal and never pass through the physical-action scale. A
	# starting Mage can afford one major cast safely, not build a whole fight out of
	# repeated casts. Intelligence turns those expensive tools into a spellbook later.
	"lightning_bolt": {"label": "Lightning Bolt", "energy": 68.0, "target_mode": "direction", "reach": 340.0, "player_startup": 0.27, "player_duration": 0.69, "resolver": "lightning_bolt"},
	"fireball": {"label": "Fireball", "energy": 78.0, "target_mode": "direction", "reach": 0.0, "player_startup": 0.66, "player_duration": 1.44, "resolver": "projectile", "projectile": "fireball"},
	"fire_breath": {"label": "Fire Breath", "energy": 82.0, "target_mode": "direction", "reach": 0.0, "player_startup": 0.74, "player_duration": 1.62, "resolver": "hazard", "hazard": "fire_breath"},
	"frost_lance": {"label": "Frost Lance", "energy": 76.0, "target_mode": "direction", "reach": 0.0, "player_startup": 0.66, "player_duration": 1.44, "resolver": "projectile", "projectile": "frost_lance"},
	"cold_front": {"label": "Cold Front", "energy": 90.0, "target_mode": "placed", "reach": PLACE_RANGE, "player_startup": 0.96, "player_duration": 1.94, "resolver": "hazard", "hazard": "cold_front"},
	"earth_wall": {"label": "Earth Wall", "energy": 82.0, "target_mode": "placed", "reach": PLACE_RANGE, "player_startup": 1.02, "player_duration": 1.74, "resolver": "barrier"},
	"sunder": {"label": "Sunder", "energy": 72.0, "target_mode": "placed", "reach": PLACE_RANGE, "player_startup": 0.66, "player_duration": 1.44, "resolver": "hazard", "hazard": "sundered_ground"},
	"gale": {"label": "Gale", "energy": 78.0, "target_mode": "placed", "reach": PLACE_RANGE, "player_startup": 0.30, "player_duration": 0.82, "resolver": "hazard", "hazard": "gale"},
	"windstep": {"label": "Windstep", "energy": 66.0, "target_mode": "direction", "reach": 0.0, "player_startup": 0.22, "player_duration": 0.78, "resolver": "movement"},
}

# Enemy timing and presentation are keyed by the ability identity rather than by
# whichever generic action carrier happens to deliver it. Fireball uses `shoot`
# in the simulator, for example, but it is not an Archer shot in presentation.
const ENEMY_ABILITIES := {
	"fireball": {"action_kind": "shoot", "startup": 0.64, "duration": 1.58, "phase_before": "KINDLING", "phase_after": "RECOVERING", "color": "ff8a45", "executor": "projectile"},
	"fire_breath": {"action_kind": "fire_breath", "startup": 0.74, "duration": 1.82, "phase_before": "DRAWING BREATH", "phase_after": "BREATHING FIRE", "color": "ff8a45", "executor": "hazard"},
	"frost_lance": {"action_kind": "frost_lance", "startup": 0.78, "duration": 1.66, "phase_before": "CONDENSING", "phase_after": "LOOSED", "color": "9be7ff", "executor": "projectile"},
	"cold_front": {"action_kind": "cold_front", "startup": 1.12, "duration": 2.34, "phase_before": "THE AIR STILLS", "phase_after": "FREEZING", "color": "8edcff", "executor": "hazard"},
	"earth_wall": {"action_kind": "earth_wall", "startup": 1.10, "duration": 1.94, "phase_before": "HEAVING", "phase_after": "RECOVERING", "color": "87ac7d", "executor": "barrier"},
	"sunder": {"action_kind": "sunder", "startup": 0.92, "duration": 1.72, "phase_before": "BREAKING", "phase_after": "RECOVERING", "color": "87ac7d", "executor": "hazard"},
	"gale": {"action_kind": "gale", "startup": 0.80, "duration": 1.64, "phase_before": "BREATHING IN", "phase_after": "TEARING", "color": "d8ecf6", "executor": "hazard"},
	"windstep": {"action_kind": "windstep", "startup": 0.26, "duration": 0.86, "phase_before": "GONE", "phase_after": "GONE", "color": "d8ecf6", "executor": "movement"},
}

const ACTION_EXECUTORS := {
	"idle": "none", "move": "locomotion", "evade": "locomotion", "dodge_strike": "melee",
	"claw_combo": "melee", "pounce_combo": "melee", "melee": "melee", "charge": "melee",
	"slam": "area", "shoot": "projectile", "hurl": "projectile", "sunder": "hazard",
	"chant": "support", "earth_wall": "barrier",
	"gale": "hazard", "windstep": "movement", "cold_front": "hazard",
	"frost_lance": "projectile", "fire_breath": "hazard",
	"stagger": "reaction", "hit_reaction": "reaction", "parry_stance": "defense",
	"attack": "player", "sweep": "player", "combo": "player", "art_combo": "player",
	"twin_fang": "player", "cast": "player", "wait": "player", "circle": "player",
	"bow_draw": "player", "dodge": "player", "vault": "player", "advance": "player",
	"block": "player", "endure": "player", "rally": "player", "potion": "player",
	"consumable": "player", "take_aim": "player", "execution": "player",
}

const HAZARD_EXECUTORS := {
	"player_fire": "friendly_burst", "gale": "impulse", "cold_front": "repeating_zone",
	"fire_breath": "cone", "sundered_ground": "slow_zone",
}

# Lifecycle metadata makes both halves of an ability contract explicit. Active
# definitions need a producer and a consumer; future reserved/legacy entries must
# carry their reason or migration rather than masquerading as live content.
const HAZARD_LIFECYCLE := {
	"player_fire": {"status":"active", "producer":"consumable", "consumer":"friendly_burst"},
	"gale": {"status":"active", "producer":"spellbook_and_air_caster", "consumer":"impulse"},
	"cold_front": {"status":"active", "producer":"spellbook_and_ice_caster", "consumer":"repeating_zone"},
	"fire_breath": {"status":"active", "producer":"spellbook_and_fire_caster", "consumer":"cone"},
	"sundered_ground": {"status":"active", "producer":"spellbook_and_earth_caster", "consumer":"slow_zone"},
}

static func has_spell(id: String) -> bool:
	return SPELLS.has(id)

static func spell(id: String) -> Dictionary:
	if not SPELLS.has(id):
		push_error("Unknown spell '%s'." % id)
		return {}
	return Dictionary(SPELLS[id]).duplicate(true)

static func spell_ids() -> Array[String]:
	var result: Array[String] = []
	for id in SPELLS: result.append(String(id))
	result.sort()
	return result

static func spell_is_placed(id: String) -> bool:
	return String(spell(id).get("target_mode", "direction")) == "placed"

static func enemy_ability(id: String) -> Dictionary:
	if not ENEMY_ABILITIES.has(id): return {}
	return Dictionary(ENEMY_ABILITIES[id]).duplicate(true)

static func enemy_ability_for_action(action: Dictionary) -> Dictionary:
	var kind := String(action.get("kind", ""))
	if kind == "shoot" and String(action.get("label", "")) in ["firebolt", "fireball"]: return enemy_ability("fireball")
	for id in ENEMY_ABILITIES:
		var definition := Dictionary(ENEMY_ABILITIES[id])
		if String(definition["action_kind"]) == kind: return definition.duplicate(true)
	return {}

static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var learned: Dictionary = {}
	for stage_id in ELEMENT_STAGE_SPELLS:
		for spell_value in Array(ELEMENT_STAGE_SPELLS[stage_id]):
			var spell_id := String(spell_value)
			learned[spell_id] = true
			if not SPELLS.has(spell_id): errors.append("%s teaches unknown spell %s" % [stage_id, spell_id])
	for id in SPELLS:
		var definition := Dictionary(SPELLS[id])
		for key in ["label", "energy", "target_mode", "reach", "player_startup", "player_duration", "resolver"]:
			if not definition.has(key): errors.append("spell %s is missing %s" % [id, key])
	for id in ENEMY_ABILITIES:
		var definition := Dictionary(ENEMY_ABILITIES[id])
		for key in ["action_kind", "startup", "duration", "phase_before", "phase_after", "color", "executor"]:
			if not definition.has(key): errors.append("enemy ability %s is missing %s" % [id, key])
		if not ACTION_EXECUTORS.has(String(definition.get("action_kind", ""))): errors.append("enemy ability %s names an unhandled action" % id)
	for kind in HAZARD_EXECUTORS:
		if String(HAZARD_EXECUTORS[kind]) == "": errors.append("hazard %s has no executor" % kind)
		if not HAZARD_LIFECYCLE.has(kind): errors.append("hazard %s has no lifecycle definition" % kind)
	for kind in HAZARD_LIFECYCLE:
		var lifecycle := Dictionary(HAZARD_LIFECYCLE[kind])
		var status := String(lifecycle.get("status", ""))
		if status == "active":
			if not HAZARD_EXECUTORS.has(kind): errors.append("active hazard %s has no consumer" % kind)
			if String(lifecycle.get("producer", "")).is_empty(): errors.append("active hazard %s has no producer" % kind)
		elif status == "reserved":
			if String(lifecycle.get("reason", "")).is_empty(): errors.append("reserved hazard %s has no reason" % kind)
		elif status == "legacy":
			if String(lifecycle.get("migration", "")).is_empty(): errors.append("legacy hazard %s has no migration" % kind)
		else: errors.append("hazard %s has unknown lifecycle %s" % [kind, status])
	for kind in PLAYER_ATTACK_ACTION_KINDS + ENEMY_ATTACK_ACTION_KINDS + ENERGY_REGEN_ACTION_KINDS:
		if not ACTION_EXECUTORS.has(kind): errors.append("classified action %s has no executor" % kind)
	return errors
