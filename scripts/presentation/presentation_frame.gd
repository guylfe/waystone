class_name PresentationFrame
extends RefCounted

var data: Dictionary = {}
var _player_action: Dictionary = {}
var _lost_xp: Dictionary = {}
var _enemy_pool: Array[Dictionary] = []
var _enemies: Array[Dictionary] = []
var _projectile_pool: Array[Dictionary] = []
var _projectiles: Array[Dictionary] = []
var _hazard_pool: Array[Dictionary] = []
var _hazards: Array[Dictionary] = []
var _effect_pool: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _pickup_pool: Array[Dictionary] = []
var _pickups: Array[Dictionary] = []
var _following_by_id: Dictionary = {}

func capture(state: RunState) -> Dictionary:
	data["time"] = state.simulation_time
	data["player_pos"] = state.player_pos
	data["player_facing"] = state.player_facing
	data["player_hp"] = state.player_hp
	data["player_max_hp"] = state.player_max_hp
	data["carried_xp"] = state.carried_xp
	data["secured_xp"] = state.secured_xp
	data["strength_remaining"] = state.strength_remaining
	data["dodge_cooldown"] = state.dodge_cooldown
	data["block_cooldown"] = state.block_cooldown
	data["endure_cooldown"] = state.endure_cooldown
	data["skill_cooldown"] = state.skill_cooldown
	data["message"] = state.message
	_copy_flat_dictionary(state.player_action, _player_action)
	_copy_flat_dictionary(state.lost_xp, _lost_xp)
	data["player_action"] = _player_action
	data["lost_xp"] = _lost_xp

	_enemies.clear()
	state._refresh_active_enemy_cache()
	var presentation_index := 0
	for enemy_index in state._streamed_enemy_indices:
		if enemy_index < 0 or enemy_index >= state.enemies.size(): continue
		var enemy: Dictionary = state.enemies[enemy_index]
		if Vector2(enemy["pos"]).distance_to(state.player_pos) > state.ACTIVE_ENEMY_RADIUS: continue
		_ensure_enemy_pool(presentation_index + 1)
		_copy_enemy(enemy, _enemy_pool[presentation_index], state.current_layer)
		_enemies.append(_enemy_pool[presentation_index])
		presentation_index += 1
	data["enemies"] = _enemies

	_capture_flat_array(state.projectiles, _projectile_pool, _projectiles)
	_capture_flat_array(state.hazards, _hazard_pool, _hazards)
	_capture_flat_array(state.effects, _effect_pool, _effects)
	# Pickups are static most of the time, but they must still be part of every
	# streamed frame. Otherwise they appear while time is frozen (full snapshot)
	# and vanish as soon as movement switches to the optimized frame path.
	_capture_flat_array(state.world_pickups, _pickup_pool, _pickups)
	data["projectiles"] = _projectiles
	data["hazards"] = _hazards
	data["effects"] = _effects
	data["world_pickups"] = _pickups
	return data

func blend(current: PresentationFrame, following: PresentationFrame, weight: float) -> Dictionary:
	var amount := clampf(weight, 0.0, 1.0)
	var current_data := current.data
	var following_data := following.data
	data["time"] = lerpf(float(current_data.get("time", 0.0)), float(following_data.get("time", 0.0)), amount)
	data["player_pos"] = Vector2(current_data["player_pos"]).lerp(Vector2(following_data["player_pos"]), amount)
	data["player_facing"] = _blend_direction(Vector2(current_data["player_facing"]), Vector2(following_data["player_facing"]), amount)
	for key in ["player_hp", "player_max_hp", "carried_xp", "secured_xp", "message"]:
		data[key] = following_data.get(key, current_data.get(key))
	for key in ["strength_remaining", "dodge_cooldown", "block_cooldown", "endure_cooldown", "skill_cooldown"]:
		data[key] = lerpf(float(current_data.get(key, 0.0)), float(following_data.get(key, 0.0)), amount)
	_blend_action(Dictionary(current_data["player_action"]), Dictionary(following_data["player_action"]), amount, _player_action)
	_copy_flat_dictionary(Dictionary(following_data.get("lost_xp", {})), _lost_xp)
	data["player_action"] = _player_action
	data["lost_xp"] = _lost_xp

	_following_by_id.clear()
	for enemy_value in Array(following_data.get("enemies", [])):
		var enemy := Dictionary(enemy_value)
		_following_by_id[int(enemy.get("id", -1))] = enemy
	_enemies.clear()
	var current_enemies: Array = current_data.get("enemies", [])
	for index in range(current_enemies.size()):
		var enemy := Dictionary(current_enemies[index])
		var next_enemy: Dictionary = _following_by_id.get(int(enemy.get("id", -1)), enemy)
		_ensure_enemy_pool(index + 1)
		var output := _enemy_pool[index]
		_copy_flat_dictionary(enemy, output, ["action"])
		output["pos"] = Vector2(enemy["pos"]).lerp(Vector2(next_enemy["pos"]), amount)
		output["facing"] = _blend_direction(Vector2(enemy["facing"]), Vector2(next_enemy["facing"]), amount)
		output["posture"] = lerpf(float(enemy.get("posture", 0.0)), float(next_enemy.get("posture", 0.0)), amount)
		var action: Dictionary = output.get("action", {})
		_blend_action(Dictionary(enemy["action"]), Dictionary(next_enemy["action"]), amount, action)
		output["action"] = action
		_enemies.append(output)
	data["enemies"] = _enemies

	_blend_flat_array(Array(current_data.get("projectiles", [])), Array(following_data.get("projectiles", [])), amount, _projectile_pool, _projectiles, ["pos"], [])
	_blend_flat_array(Array(current_data.get("hazards", [])), Array(following_data.get("hazards", [])), amount, _hazard_pool, _hazards, ["pos"], ["elapsed"])
	_blend_flat_array(Array(current_data.get("effects", [])), Array(following_data.get("effects", [])), amount, _effect_pool, _effects, ["pos"], ["elapsed"])
	_blend_flat_array(Array(current_data.get("world_pickups", [])), Array(following_data.get("world_pickups", [])), amount, _pickup_pool, _pickups, ["pos"], [])
	data["projectiles"] = _projectiles
	data["hazards"] = _hazards
	data["effects"] = _effects
	data["world_pickups"] = _pickups
	return data

func _copy_enemy(source: Dictionary, target: Dictionary, default_layer: String) -> void:
	var action: Dictionary = target.get("action", {})
	target.clear()
	target["id"] = int(source["id"])
	target["kind"] = String(source["kind"])
	target["pos"] = Vector2(source["pos"])
	target["facing"] = Vector2(source["facing"])
	target["hp"] = int(source["hp"])
	target["max_hp"] = int(source["max_hp"])
	target["radius"] = float(source["radius"])
	target["posture"] = float(source.get("posture", 0.0))
	target["posture_max"] = float(source.get("posture_max", 1.0))
	target["awareness"] = String(source.get("awareness", "idle"))
	target["layer"] = String(source.get("layer", default_layer))
	_copy_flat_dictionary(Dictionary(source["action"]), action)
	target["action"] = action

func _blend_action(current: Dictionary, following: Dictionary, weight: float, target: Dictionary) -> void:
	_copy_flat_dictionary(following, target)
	if String(current.get("kind", "idle")) == String(following.get("kind", "idle")):
		target["elapsed"] = lerpf(float(current.get("elapsed", 0.0)), float(following.get("elapsed", 0.0)), weight)

func _capture_flat_array(source: Array, pool: Array[Dictionary], output: Array[Dictionary]) -> void:
	_ensure_pool(pool, source.size())
	output.clear()
	for index in range(source.size()):
		_copy_flat_dictionary(Dictionary(source[index]), pool[index])
		output.append(pool[index])

func _blend_flat_array(current: Array, following: Array, weight: float, pool: Array[Dictionary], output: Array[Dictionary], vector_keys: Array[String], float_keys: Array[String]) -> void:
	_ensure_pool(pool, current.size())
	output.clear()
	for index in range(current.size()):
		var item := Dictionary(current[index])
		var next_item := Dictionary(following[index]) if index < following.size() else item
		var target := pool[index]
		_copy_flat_dictionary(item, target)
		for key in vector_keys:
			if item.has(key) and next_item.has(key): target[key] = Vector2(item[key]).lerp(Vector2(next_item[key]), weight)
		for key in float_keys:
			if item.has(key) and next_item.has(key): target[key] = lerpf(float(item[key]), float(next_item[key]), weight)
		output.append(target)

func _copy_flat_dictionary(source: Dictionary, target: Dictionary, excluded: Array[String] = []) -> void:
	target.clear()
	for key_value in source:
		var key := String(key_value)
		if excluded.has(key): continue
		var value: Variant = source[key_value]
		if value is Array or value is Dictionary: continue
		target[key_value] = value

func _ensure_enemy_pool(size: int) -> void:
	while _enemy_pool.size() < size: _enemy_pool.append({"action": {}})

func _ensure_pool(pool: Array[Dictionary], size: int) -> void:
	while pool.size() < size: pool.append({})

func _blend_direction(current: Vector2, following: Vector2, weight: float) -> Vector2:
	var blended := current.lerp(following, weight)
	return blended.normalized() if blended.length_squared() > 0.001 else current.normalized()
