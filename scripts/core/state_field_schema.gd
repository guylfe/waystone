class_name StateFieldSchema
extends RefCounted

const SNAPSHOT := "snapshot"
const PRESENTATION := "presentation"
const SAVE := "save"

# Shared authoritative fields are declared once with explicit consumers. Presentation
# pooling and save migration remain audience-specific policies around this schema.
const FIELDS := [
	{"key":"time", "source":"simulation_time", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_pos", "source":"player_pos", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_facing", "source":"player_facing", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_hp", "source":"player_hp", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_max_hp", "source":"player_max_hp", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_energy", "source":"player_energy", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_max_energy", "source":"player_max_energy", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_posture", "source":"player_posture", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_posture_max", "source":"player_posture_max", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"carried_xp", "source":"carried_xp", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"secured_xp", "source":"secured_xp", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"strength_remaining", "source":"strength_remaining", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"dodge_cooldown", "source":"dodge_cooldown", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"block_cooldown", "source":"block_cooldown", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"endure_cooldown", "source":"endure_cooldown", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"skill_cooldown", "source":"skill_cooldown", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"rally_cooldown", "source":"rally_cooldown", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"advance_cooldown", "source":"advance_cooldown", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"main_ability_cooldown", "source":"main_ability_cooldown", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"subclass_ability_cooldown", "source":"subclass_ability_cooldown", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"weapon_sequence_cooldown", "source":"weapon_sequence_cooldown", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"stealth_remaining", "source":"stealth_remaining", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"aimed_remaining", "source":"aimed_remaining", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"rally_remaining", "source":"rally_remaining", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"message", "source":"message", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_action", "source":"player_action", "audiences":[SNAPSHOT, PRESENTATION], "copy":"dictionary"},
	{"key":"lost_xp", "source":"lost_xp", "audiences":[SNAPSHOT, PRESENTATION, SAVE], "copy":"dictionary"},
	{"key":"projectiles", "source":"projectiles", "audiences":[SNAPSHOT, PRESENTATION, SAVE], "copy":"array"},
	{"key":"hazards", "source":"hazards", "audiences":[SNAPSHOT, PRESENTATION, SAVE], "copy":"array"},
	{"key":"effects", "source":"effects", "audiences":[SNAPSHOT, PRESENTATION, SAVE], "copy":"array"},
	{"key":"world_pickups", "source":"world_pickups", "audiences":[SNAPSHOT, PRESENTATION, SAVE], "copy":"array"},
	{"key":"barriers", "source":"barriers", "audiences":[SNAPSHOT, PRESENTATION, SAVE], "copy":"array"},
	{"key":"circle_pos", "source":"circle_pos", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"circle_remaining", "source":"circle_remaining", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"circle_radius", "source":"circle_radius", "audiences":[SNAPSHOT, PRESENTATION, SAVE], "copy":"method"},
]

static func descriptors_for(audience: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for descriptor in FIELDS:
		if audience in Array(Dictionary(descriptor)["audiences"]): result.append(Dictionary(descriptor))
	return result

static func capture(state: Object, audience: String) -> Dictionary:
	var result := {}
	for descriptor in descriptors_for(audience):
		var key := String(descriptor["key"])
		var source := String(descriptor["source"])
		var policy := String(descriptor.get("copy", "scalar"))
		var value: Variant = state.call(source) if policy == "method" else state.get(source)
		if policy == "dictionary": value = Dictionary(value).duplicate(true)
		elif policy == "array": value = Array(value).duplicate(true)
		result[key] = value
	return result

static func capture_scalars(state: Object, audience: String) -> Dictionary:
	var result := {}
	for descriptor in descriptors_for(audience):
		var policy := String(descriptor.get("copy", "scalar"))
		if policy in ["dictionary", "array"]: continue
		var source := String(descriptor["source"])
		result[String(descriptor["key"])] = state.call(source) if policy == "method" else state.get(source)
	return result

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var keys := {}
	for descriptor in FIELDS:
		var definition := Dictionary(descriptor)
		var key := String(definition.get("key", ""))
		if key.is_empty(): errors.append("State field has no key")
		if keys.has(key): errors.append("Duplicate state field: %s" % key)
		keys[key] = true
		if Array(definition.get("audiences", [])).is_empty(): errors.append("State field %s has no audience" % key)
	return errors
