class_name DeterminismSnapshot
extends RefCounted

const StateFieldSchemaScript = preload("res://scripts/core/state_field_schema.gd")

# A semantic projection for structural-refactor tests. It deliberately ignores
# caches, presentation pools, profiler values and storage layout. If two runs play
# identically, these component hashes remain identical even when their internal
# representation changes.

const ACTION_FIELDS := [
	"kind", "technique_id", "label", "elapsed", "duration", "startup",
	"active_end", "direction", "movement_direction", "cast_move_scale", "target", "reach", "damage", "posture",
	"advance_distance", "advance_end", "speed", "phase", "guard_capacity", "guard_remaining",
	"flight_time", "projectile_speed", "projectile_radius", "launch", "arc_span", "max_range",
	"battle_flow_damage", "battle_flow_posture", "battle_flow_registered", "force_hit_reaction",
]
const EXPEDITION_ACTION_FIELDS := ["ability_id", "shape", "origin", "travel", "arc", "pull", "protected", "track_until", "spent", "world_elapsed", "world_startup"]

static func checkpoint(state: RunState) -> Dictionary:
	var player := StateFieldSchemaScript.capture(state, StateFieldSchemaScript.DETERMINISM)
	# Optional earned Bow flags were absent in historical checkpoints. False is
	# the same semantic default, while an active benefit/consumption must hash.
	for key in ["bow_followup_ready","bow_followup_consumed"]:
		if not bool(player.get(key,false)): player.erase(key)
	# An absent expedition must not change historical Survey fingerprints. The
	# journal observes outcomes but never determines simulation behaviour.
	if state.expedition.is_empty():
		player.erase("expedition")
		player.erase("simulation_tick_index")
	else:
		player["expedition"] = state.expedition.duplicate(true)
		player["expedition"].erase("events")
	player["player_action"] = _selected(Dictionary(state.player_action), ACTION_FIELDS)
	if bool(state.player_action.get("commit_shot",false)): player["player_action"]["commit_shot"]=true
	if bool(state.player_action.get("bow_followup_consumed",false)): player["player_action"]["bow_followup_consumed"]=true
	if String(state.player_action.get("kind",""))=="adopted":
		player["player_action"].merge(_selected(state.player_action,["ability_id","rank","effect_done"]))
	var enemies: Array = []
	for value in state.enemies:
		var enemy := Dictionary(value)
		var projected := StateFieldSchemaScript.project_entity(enemy, "enemy", StateFieldSchemaScript.DETERMINISM)
		projected["action"] = _selected(Dictionary(enemy.get("action", {})), ACTION_FIELDS)
		if String(Dictionary(enemy.get("action", {})).get("kind", "")) == "expedition_attack":
			projected["action"].merge(_selected(enemy["action"], EXPEDITION_ACTION_FIELDS))
		if not state.expedition.is_empty():
			projected["action"].merge(_selected(enemy["action"],["speed_multiplier","effect_done","hit_done","advance"]))
		enemies.append(projected)
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", -1)) < int(b.get("id", -1)))
	var world := {
		"projectiles": _project_collection(state.projectiles, "projectile"),
		"hazards": _project_collection(state.hazards, "hazard"),
		"barriers": _project_collection(state.barriers, "barrier"),
		"effects": _project_collection(state.effects, "effect"),
	}
	var run := {
		"time": state.simulation_time,
		"rng_state": state.rng.state,
		"layer": state.current_layer,
		"area": state.current_area_id,
		"carried_xp": state.carried_xp,
		"secured_xp": state.secured_xp,
		"rooms_cleared": state.rooms_cleared,
	}
	return {
		"player": hash_value(player),
		"enemies": hash_value(enemies),
		"world": hash_value(world),
		"run": hash_value(run),
		"all": hash_value({"player": player, "enemies": enemies, "world": world, "run": run}),
	}

static func hash_value(value: Variant) -> String:
	return _canonical(value).sha256_text()

static func _project_collection(source: Array, entity: String) -> Array:
	var result: Array = []
	for value in source:
		result.append(StateFieldSchemaScript.project_entity(Dictionary(value), entity, StateFieldSchemaScript.DETERMINISM))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_id := int(a.get("id", -1))
		var b_id := int(b.get("id", -1))
		if a_id != b_id: return a_id < b_id
		return _canonical(a) < _canonical(b)
	)
	return result

static func _selected(source: Dictionary, fields: Array) -> Dictionary:
	var result := {}
	for key_value in fields:
		var key := String(key_value)
		if source.has(key): result[key] = source[key]
	return result

static func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var source := Dictionary(value)
		var keys: Array[String] = []
		for key_value in source: keys.append(String(key_value))
		keys.sort()
		var parts: Array[String] = []
		for key in keys: parts.append("%s:%s" % [_escape(key), _canonical(source[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts: Array[String] = []
		for item in Array(value): parts.append(_canonical(item))
		return "[%s]" % ",".join(parts)
	if value is Vector2:
		var vector := Vector2(value)
		return "v(%.6f,%.6f)" % [vector.x, vector.y]
	if value is float:
		return "f(%.6f)" % float(value)
	if value is int: return "i(%d)" % int(value)
	if value is bool: return "b(1)" if bool(value) else "b(0)"
	if value == null: return "null"
	return "s(%s)" % _escape(String(value))

static func _escape(value: String) -> String:
	return value.replace("\\", "\\\\").replace(":", "\\:").replace(",", "\\,").replace("{", "\\{").replace("}", "\\}").replace("[", "\\[").replace("]", "\\]")
