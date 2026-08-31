class_name DeterminismSnapshot
extends RefCounted

# A semantic projection for structural-refactor tests. It deliberately ignores
# caches, presentation pools, profiler values and storage layout. If two runs play
# identically, these component hashes remain identical even when their internal
# representation changes.

const ACTION_FIELDS := [
	"kind", "technique_id", "label", "elapsed", "duration", "startup",
	"active_end", "direction", "target", "reach", "damage", "posture",
	"advance_distance", "advance_end", "speed", "phase",
]

const ACTOR_FIELDS := [
	"id", "kind", "pos", "facing", "hp", "max_hp", "radius", "posture",
	"posture_max", "awareness", "layer", "pounce_cooldown", "parry_cooldown",
	"dodge_cooldown", "neutral_cooldown", "shot_cooldown", "conditions",
]

const WORLD_FIELDS := [
	"id", "kind", "pos", "vel", "direction", "radius", "half_angle",
	"elapsed", "duration", "trigger_at", "triggered", "damage", "posture",
	"source_id", "friendly", "remaining", "hp", "axis", "half_length",
	"thickness", "layer", "travelled", "max_range",
]

static func checkpoint(state: RunState) -> Dictionary:
	var player := {
		"pos": state.player_pos,
		"facing": state.player_facing,
		"hp": state.player_hp,
		"max_hp": state.player_max_hp,
		"energy": state.player_energy,
		"max_energy": state.player_max_energy,
		"posture": state.player_posture,
		"posture_max": state.player_posture_max,
		"action": _selected(Dictionary(state.player_action), ACTION_FIELDS),
	}
	var enemies: Array = []
	for value in state.enemies:
		var enemy := Dictionary(value)
		var projected := _selected(enemy, ACTOR_FIELDS)
		projected["action"] = _selected(Dictionary(enemy.get("action", {})), ACTION_FIELDS)
		enemies.append(projected)
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", -1)) < int(b.get("id", -1)))
	var world := {
		"projectiles": _project_collection(state.projectiles),
		"hazards": _project_collection(state.hazards),
		"barriers": _project_collection(state.barriers),
		"effects": _project_collection(state.effects),
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

static func _project_collection(source: Array) -> Array:
	var result: Array = []
	for value in source:
		result.append(_selected(Dictionary(value), WORLD_FIELDS))
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
