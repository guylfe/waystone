class_name StateFieldSchema
extends RefCounted

const SNAPSHOT := "snapshot"
const PRESENTATION := "presentation"
const SAVE := "save"
const DETERMINISM := "determinism"

# Shared authoritative fields are declared once with explicit consumers. Presentation
# pooling and save migration remain audience-specific policies around this schema.
const FIELDS := [
	{"key":"survey_experiment", "source":"survey_experiment", "audiences":[SAVE], "copy":"dictionary"},
	{"key":"next_combo_instance_id", "source":"_next_combo_instance_id", "audiences":[SAVE]},
	{"key":"next_presentation_id", "source":"_next_presentation_id", "audiences":[SAVE]},
	{"key":"condition_tick_accumulator", "source":"_condition_tick_accumulator", "audiences":[SAVE]},
	{"key":"player_burn_debt", "source":"_player_burn_debt", "audiences":[SAVE]},
	{"key":"stealth_last_ended_at", "source":"_stealth_last_ended_at", "audiences":[SAVE]},
	{"key":"combat_lab", "source":"combat_lab", "audiences":[SNAPSHOT,PRESENTATION], "lab_only":true},
	{"key":"lab_variant", "source":"lab_variant", "audiences":[SNAPSHOT,PRESENTATION], "lab_only":true},
	{"key":"lab_armed", "source":"lab_armed", "audiences":[SNAPSHOT,PRESENTATION], "lab_only":true},
	{"key":"lab_neutral_required", "source":"lab_neutral_required", "audiences":[SNAPSHOT,PRESENTATION], "lab_only":true},
	{"key":"lab_notice", "source":"lab_notice", "audiences":[SNAPSHOT,PRESENTATION], "lab_only":true},
	# The immutable presentation does not need a growing run event journal every frame.
	{"key":"expedition", "source":"expedition", "audiences":[SAVE, DETERMINISM], "copy":"dictionary"},
	{"key":"simulation_tick_index", "source":"_simulation_tick_index", "audiences":[SAVE, DETERMINISM]},
	{"key":"time", "source":"simulation_time", "audiences":[SNAPSHOT, PRESENTATION, SAVE], "interpolate":"float"},
	{"key":"player_pos", "source":"player_pos", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "interpolate":"vector"},
	{"key":"player_facing", "source":"player_facing", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "interpolate":"direction"},
	{"key":"player_hp", "source":"player_hp", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"player_max_hp", "source":"player_max_hp", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"player_energy", "source":"player_energy", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "interpolate":"float"},
	{"key":"player_max_energy", "source":"player_max_energy", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "interpolate":"float"},
	{"key":"player_posture", "source":"player_posture", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "interpolate":"float"},
	{"key":"player_posture_max", "source":"player_posture_max", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "interpolate":"float"},
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
	{"key":"stealth_remaining", "source":"stealth_remaining", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "interpolate":"float"},
	{"key":"aimed_remaining", "source":"aimed_remaining", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"rally_active", "source":"rally_active", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"rally_energy_paid", "source":"rally_energy_paid", "audiences":[SNAPSHOT, SAVE], "interpolate":"float"},
	{"key":"battle_flow_pips", "source":"battle_flow_pips", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"battle_flow_remaining", "source":"battle_flow_remaining", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "interpolate":"float"},
	{"key":"message", "source":"message", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"room_clear_pending", "source":"room_clear_pending", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	{"key":"player_action", "source":"player_action", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "copy":"dictionary", "interpolate":"action"},
	{"key":"player_conditions", "source":"player_conditions", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "copy":"dictionary"},
	{"key":"player_condition_buildup", "source":"player_condition_buildup", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "copy":"dictionary"},
	{"key":"player_gale_velocity", "source":"player_gale_velocity", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM], "interpolate":"vector"},
	{"key":"player_exhaustion_remaining", "source":"player_exhaustion_remaining", "audiences":[SNAPSHOT, PRESENTATION, SAVE], "interpolate":"float"},
	{"key":"aimed_enemy_id", "source":"aimed_enemy_id", "audiences":[SNAPSHOT, PRESENTATION, SAVE]},
	# Optional v39 scalar extensions: old saves default false at hydration. Bow's
	# earned preload survives save/resume; each arrow carries its own consumption.
	{"key":"bow_followup_ready", "source":"bow_followup_ready", "audiences":[SAVE, DETERMINISM]},
	{"key":"bow_followup_consumed", "source":"bow_followup_consumed", "audiences":[SAVE, DETERMINISM]},
	{"key":"sensed_enemies", "source":"_sensed_enemy_presentations", "audiences":[SNAPSHOT, PRESENTATION], "copy":"method_array"},
	{"key":"visibility_revision", "source":"visibility_revision", "audiences":[SNAPSHOT, PRESENTATION]},
	{"key":"discovery_revision", "source":"discovery_revision", "audiences":[SNAPSHOT, PRESENTATION]},
	{"key":"visible_cells", "source":"visible_cells", "audiences":[SNAPSHOT, PRESENTATION], "copy":"revision_dictionary", "revision":"visibility_revision"},
	{"key":"discovered_cells", "source":"discovered_cells", "audiences":[SNAPSHOT, PRESENTATION], "copy":"revision_dictionary", "revision":"discovery_revision"},
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

# Entity descriptors are the single projection authority for presentation and
# determinism. Optional fields are copied only when present; a descriptor with a
# `default` is authored into the projection even when an old runtime record lacks it.
const LAB_ACTION_FIELDS := [
	{"key":"lab_pending", "default":false, "audiences":[SNAPSHOT,PRESENTATION,DETERMINISM]},
	{"key":"lab_continue_token", "default":false, "audiences":[SNAPSHOT,PRESENTATION,DETERMINISM]},
	{"key":"lab_prepaid", "default":false, "audiences":[SNAPSHOT,PRESENTATION,DETERMINISM]},
	{"key":"lab_paid_cost", "default":0.0, "audiences":[SNAPSHOT,PRESENTATION,DETERMINISM]},
	{"key":"lab_suspend_exit", "default":false, "audiences":[SNAPSHOT,PRESENTATION,DETERMINISM]},
	{"key":"lab_exit_request", "default":{}, "copy":"dictionary", "audiences":[SNAPSHOT,PRESENTATION,DETERMINISM]},
]

const ENEMY_FIELDS := [
	{"key":"expedition_site", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"expedition_xp", "audiences":[SNAPSHOT, SAVE, DETERMINISM]},
	{"key":"reserve", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"gong_pos", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"gong_used", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"expedition_attack_index", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"expedition_approaching", "audiences":[SNAPSHOT, PRESENTATION, SAVE, DETERMINISM]},
	{"key":"id", "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"presentation_id", "audiences":[PRESENTATION]},
	{"key":"kind", "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"pos", "audiences":[PRESENTATION, DETERMINISM], "interpolate":"vector"},
	{"key":"facing", "audiences":[PRESENTATION, DETERMINISM], "interpolate":"direction"},
	{"key":"hp", "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"max_hp", "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"radius", "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"posture", "audiences":[PRESENTATION, DETERMINISM], "interpolate":"float"},
	{"key":"posture_max", "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"awareness", "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"revealed_to_player", "audiences":[PRESENTATION]},
	{"key":"revealed_elapsed", "audiences":[PRESENTATION], "interpolate":"float"},
	{"key":"layer", "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"action", "audiences":[PRESENTATION, DETERMINISM], "copy":"dictionary", "interpolate":"action"},
	{"key":"conditions", "audiences":[PRESENTATION, DETERMINISM], "copy":"dictionary", "default":{}},
	{"key":"condition_buildup", "audiences":[PRESENTATION, DETERMINISM], "copy":"dictionary", "default":{}},
	{"key":"chants", "audiences":[PRESENTATION, DETERMINISM], "copy":"dictionary", "default":{}},
	{"key":"chant_source_id", "audiences":[PRESENTATION, DETERMINISM], "default":-1},
	{"key":"ward_id", "audiences":[PRESENTATION, DETERMINISM], "default":-1},
	{"key":"ward_lost_time", "audiences":[DETERMINISM], "default":0.0, "interpolate":"float"},
	{"key":"gale_velocity", "audiences":[PRESENTATION, DETERMINISM], "interpolate":"vector", "default":Vector2.ZERO},
	{"key":"pounce_cooldown", "audiences":[DETERMINISM]},
	{"key":"parry_cooldown", "audiences":[DETERMINISM]},
	{"key":"dodge_cooldown", "audiences":[DETERMINISM]},
	{"key":"neutral_cooldown", "audiences":[DETERMINISM]},
	{"key":"knife_flank_side", "audiences":[DETERMINISM], "default":0},
	{"key":"knife_flank_bearing", "audiences":[DETERMINISM], "default":Vector2.ZERO, "interpolate":"direction"},
	{"key":"knife_flank_anchor", "audiences":[DETERMINISM], "default":Vector2.ZERO, "interpolate":"vector"},
	{"key":"knife_flank_elapsed", "audiences":[DETERMINISM], "default":0.0, "interpolate":"float"},
	{"key":"knife_flank_abandoned", "audiences":[DETERMINISM], "default":false},
	{"key":"boss_phase", "audiences":[PRESENTATION, DETERMINISM], "default":1},
	{"key":"boss_phase_pending", "audiences":[PRESENTATION, DETERMINISM], "default":false},
	{"key":"boss_attack_index", "audiences":[DETERMINISM], "default":0},
	{"key":"boss_stalk_available", "audiences":[DETERMINISM], "default":false},
	{"key":"boss_posture_break_pending", "audiences":[PRESENTATION, DETERMINISM], "default":false},
	{"key":"boss_posture_break_contact", "audiences":[DETERMINISM], "default":Vector2.ZERO, "interpolate":"vector"},
	{"key":"boss_posture_break_interrupter", "audiences":[DETERMINISM], "default":"system"},
	{"key":"boss_posture_break_tool", "audiences":[DETERMINISM], "default":"unknown"},
	{"key":"shot_cooldown", "audiences":[DETERMINISM]},
	{"key":"attributes", "audiences":[PRESENTATION], "copy":"dictionary"},
	{"key":"weapon_frame", "audiences":[PRESENTATION]},
	{"key":"equipped_weapon_art", "audiences":[PRESENTATION]},
]

const WORLD_FIELDS := [
	{"key":"lane_start", "entities":["hazard"], "audiences":[PRESENTATION,DETERMINISM]},
	{"key":"lane_end", "entities":["hazard"], "audiences":[PRESENTATION,DETERMINISM]},
	{"key":"ability_id", "entities":["projectile","hazard"], "audiences":[PRESENTATION,DETERMINISM]},
	{"key":"origin", "entities":["hazard"], "audiences":[PRESENTATION,DETERMINISM]},
	{"key":"guard_site", "entities":["pickup"], "audiences":[PRESENTATION,DETERMINISM]},
	{"key":"id", "entities":["projectile", "hazard", "barrier", "effect", "pickup"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"presentation_id", "entities":["projectile", "hazard", "barrier", "effect", "pickup"], "audiences":[PRESENTATION]},
	{"key":"kind", "entities":["projectile", "hazard", "barrier", "effect", "pickup"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"pos", "entities":["projectile", "hazard", "barrier", "effect", "pickup"], "audiences":[PRESENTATION, DETERMINISM], "interpolate":"vector"},
	{"key":"vel", "entities":["projectile"], "audiences":[PRESENTATION, DETERMINISM], "interpolate":"vector"},
	{"key":"direction", "entities":["projectile", "hazard", "effect"], "audiences":[PRESENTATION, DETERMINISM], "interpolate":"direction"},
	{"key":"radius", "entities":["projectile", "hazard", "effect"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"half_angle", "entities":["hazard"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"elapsed", "entities":["projectile", "hazard", "effect"], "audiences":[PRESENTATION, DETERMINISM], "interpolate":"float"},
	{"key":"duration", "entities":["projectile", "hazard", "effect"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"trigger_at", "entities":["hazard"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"triggered", "entities":["hazard"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"damage", "entities":["projectile", "hazard"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"posture", "entities":["projectile", "hazard"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"source_id", "entities":["projectile", "hazard", "barrier"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"friendly", "entities":["projectile", "hazard", "barrier"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"remaining", "entities":["projectile", "barrier", "effect", "pickup"], "audiences":[PRESENTATION, DETERMINISM], "interpolate":"float"},
	{"key":"hp", "entities":["barrier"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"axis", "entities":["barrier"], "audiences":[PRESENTATION, DETERMINISM], "interpolate":"direction"},
	{"key":"half_length", "entities":["barrier"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"thickness", "entities":["barrier"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"layer", "entities":["projectile", "hazard", "barrier", "effect", "pickup"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"travelled", "entities":["projectile"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"max_range", "entities":["projectile"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"arc_span", "entities":["projectile"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"elevation", "entities":["projectile"], "audiences":[PRESENTATION, DETERMINISM], "default":0.0, "interpolate":"float"},
	{"key":"elevation_peak", "entities":["projectile"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"elevation_profile", "entities":["projectile"], "audiences":[PRESENTATION, DETERMINISM], "default":"flat"},
	{"key":"misdirected", "entities":["projectile"], "audiences":[PRESENTATION, DETERMINISM], "default":false},
	{"key":"piercing", "entities":["projectile"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"amount", "entities":["pickup", "effect"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"strength", "entities":["effect"], "audiences":[PRESENTATION, DETERMINISM]},
	{"key":"origin", "entities":["effect"], "audiences":[PRESENTATION, DETERMINISM], "interpolate":"vector"},
	{"key":"label", "entities":["pickup", "effect"], "audiences":[PRESENTATION]},
	{"key":"color", "entities":["effect"], "audiences":[PRESENTATION]},
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
		var value: Variant = state.call(source) if policy in ["method", "method_array"] else state.get(source)
		if policy == "dictionary": value = Dictionary(value).duplicate(true)
		elif policy == "array":
			var entity_by_key := {"projectiles":"projectile", "hazards":"hazard", "effects":"effect", "world_pickups":"pickup", "barriers":"barrier"}
			if audience != SAVE and entity_by_key.has(key):
				var projected: Array = []
				var projection_audience := PRESENTATION if audience == SNAPSHOT else audience
				for item_value in Array(value): projected.append(project_entity(Dictionary(item_value), String(entity_by_key[key]), projection_audience))
				value = projected
			else: value = Array(value).duplicate(true)
		elif policy == "method_array": value = Array(value).duplicate(true)
		elif policy == "revision_dictionary": value = Dictionary(value).duplicate(true)
		result[key] = value
	return result

static func capture_scalars(state: Object, audience: String) -> Dictionary:
	var result := {}
	for descriptor in descriptors_for(audience):
		var policy := String(descriptor.get("copy", "scalar"))
		if policy in ["dictionary", "array", "method_array", "revision_dictionary"]: continue
		var source := String(descriptor["source"])
		result[String(descriptor["key"])] = state.call(source) if policy == "method" else state.get(source)
	return result

static func entity_descriptors(entity: String, audience: String) -> Array[Dictionary]:
	var source: Array = ENEMY_FIELDS if entity == "enemy" else WORLD_FIELDS
	var result: Array[Dictionary] = []
	for descriptor_value in source:
		var descriptor := Dictionary(descriptor_value)
		if audience not in Array(descriptor.get("audiences", [])): continue
		if entity != "enemy" and entity not in Array(descriptor.get("entities", [])): continue
		result.append(descriptor)
	return result

static func project_entity(source: Dictionary, entity: String, audience: String) -> Dictionary:
	var result := {}
	for descriptor in entity_descriptors(entity, audience):
		var key := String(descriptor["key"])
		if not source.has(key) and not descriptor.has("default"): continue
		var value: Variant = source.get(key, descriptor.get("default"))
		var policy := String(descriptor.get("copy", "scalar"))
		if policy == "dictionary": value = Dictionary(value).duplicate(true)
		elif policy == "array": value = Array(value).duplicate(true)
		result[key] = value
	return result

static func interpolation(entity: String, key: String) -> String:
	var source: Array = FIELDS if entity == "state" else ENEMY_FIELDS if entity == "enemy" else WORLD_FIELDS
	for descriptor_value in source:
		var descriptor := Dictionary(descriptor_value)
		if String(descriptor.get("key", "")) != key: continue
		if entity not in ["state", "enemy"] and entity not in Array(descriptor.get("entities", [])): continue
		return String(descriptor.get("interpolate", "carry"))
	return "carry"

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
	for namespace_value in [{"name":"enemy", "fields":ENEMY_FIELDS}, {"name":"world", "fields":WORLD_FIELDS}]:
		var namespace_definition := Dictionary(namespace_value)
		var seen := {}
		for descriptor_value in Array(namespace_definition["fields"]):
			var descriptor := Dictionary(descriptor_value)
			var key := String(descriptor.get("key", ""))
			var identity := "%s:%s" % [key, ",".join(PackedStringArray(descriptor.get("entities", [])))]
			if key.is_empty(): errors.append("%s entity field has no key" % String(namespace_definition["name"]))
			if seen.has(identity): errors.append("Duplicate %s entity field: %s" % [String(namespace_definition["name"]), identity])
			seen[identity] = true
			if Array(descriptor.get("audiences", [])).is_empty(): errors.append("Entity field %s has no audience" % key)
	for required_world_key in ["misdirected", "elevation", "elevation_profile"]:
		var found := false
		for descriptor_value in WORLD_FIELDS:
			var descriptor := Dictionary(descriptor_value)
			if String(descriptor.get("key", "")) == required_world_key and descriptor.has("default"):
				found = true
				break
		if not found: errors.append("World field %s needs an authored default" % required_world_key)
	return errors
