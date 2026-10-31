class_name PresentationFrame
extends RefCounted

const StateFieldSchemaScript = preload("res://scripts/core/state_field_schema.gd")

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
var _barrier_pool: Array[Dictionary] = []
var _barriers: Array[Dictionary] = []
var _following_by_id: Dictionary = {}
var _visible_revision := -1
var _discovery_revision := -1
var _visible_snapshot: Dictionary = {}
var _discovered_snapshot: Dictionary = {}
var _entity_fields: Dictionary = {}

func capture(state: RunState) -> Dictionary:
	var shared := StateFieldSchemaScript.capture_scalars(state, StateFieldSchemaScript.PRESENTATION)
	for key in shared:
		data[key] = shared[key]
	_copy_dictionary(state.player_action, _player_action)
	_copy_dictionary(state.lost_xp, _lost_xp)
	data["player_action"] = _player_action
	data["lost_xp"] = _lost_xp
	data["player_conditions"] = state.player_conditions.duplicate(true)
	data["player_condition_buildup"] = state.player_condition_buildup.duplicate(true)
	data["sensed_enemies"] = state._sensed_enemy_presentations().duplicate(true)
	if _visible_revision != state.visibility_revision:
		_visible_revision = state.visibility_revision
		_visible_snapshot = state.visible_cells.duplicate(true)
	if _discovery_revision != state.discovery_revision:
		_discovery_revision = state.discovery_revision
		_discovered_snapshot = state.discovered_cells.duplicate(true)
	# Frames own immutable copies. Never point presentation at the dictionaries the
	# visibility solver clears and repopulates during the next simulation tick.
	data["visible_cells"] = _visible_snapshot
	data["discovered_cells"] = _discovered_snapshot

	_enemies.clear()
	state._refresh_active_enemy_cache()
	var presentation_index := 0
	for enemy_index in state._streamed_enemy_indices:
		if enemy_index < 0 or enemy_index >= state.enemies.size(): continue
		var enemy: Dictionary = state.enemies[enemy_index]
		if Vector2(enemy["pos"]).distance_to(state.player_pos) > state.ACTIVE_ENEMY_RADIUS: continue
		if not state.enemy_visible_to_player(enemy): continue
		_ensure_enemy_pool(presentation_index + 1)
		_copy_entity(enemy, _enemy_pool[presentation_index], "enemy")
		if not _enemy_pool[presentation_index].has("layer"): _enemy_pool[presentation_index]["layer"] = state.current_layer
		_enemies.append(_enemy_pool[presentation_index])
		presentation_index += 1
	data["enemies"] = _enemies

	_capture_entity_array(state.projectiles, _projectile_pool, _projectiles, "projectile")
	_capture_entity_array(state.hazards, _hazard_pool, _hazards, "hazard")
	_capture_entity_array(state.effects, _effect_pool, _effects, "effect")
	# Pickups are static most of the time, but they must still be part of every
	# streamed frame. Otherwise they appear while time is frozen (full snapshot)
	# and vanish as soon as movement switches to the optimized frame path.
	_capture_entity_array(state.world_pickups, _pickup_pool, _pickups, "pickup")
	_capture_entity_array(state.barriers, _barrier_pool, _barriers, "barrier")
	data["projectiles"] = _projectiles
	data["hazards"] = _hazards
	data["effects"] = _effects
	data["world_pickups"] = _pickups
	data["barriers"] = _barriers
	return data

func blend(current: PresentationFrame, following: PresentationFrame, weight: float) -> Dictionary:
	var amount := clampf(weight, 0.0, 1.0)
	var current_data := current.data
	var following_data := following.data
	for descriptor in StateFieldSchemaScript.descriptors_for(StateFieldSchemaScript.PRESENTATION):
		var key := String(descriptor["key"])
		if key in ["player_action", "lost_xp", "projectiles", "hazards", "effects", "world_pickups", "barriers"]: continue
		if not current_data.has(key) and not following_data.has(key): continue
		data[key] = _blended_value(current_data.get(key), following_data.get(key, current_data.get(key)), String(descriptor.get("interpolate", "carry")), amount)
	_blend_action(Dictionary(current_data["player_action"]), Dictionary(following_data["player_action"]), amount, _player_action)
	_copy_dictionary(Dictionary(following_data.get("lost_xp", {})), _lost_xp)
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
		_blend_entity(enemy, next_enemy, output, "enemy", amount, ["action"])
		var action: Dictionary = output.get("action", {})
		_blend_action(Dictionary(enemy["action"]), Dictionary(next_enemy["action"]), amount, action)
		output["action"] = action
		_enemies.append(output)
	data["enemies"] = _enemies

	_blend_entity_array(Array(current_data.get("projectiles", [])), Array(following_data.get("projectiles", [])), amount, _projectile_pool, _projectiles, "projectile")
	_blend_entity_array(Array(current_data.get("hazards", [])), Array(following_data.get("hazards", [])), amount, _hazard_pool, _hazards, "hazard")
	_blend_entity_array(Array(current_data.get("effects", [])), Array(following_data.get("effects", [])), amount, _effect_pool, _effects, "effect")
	_blend_entity_array(Array(current_data.get("world_pickups", [])), Array(following_data.get("world_pickups", [])), amount, _pickup_pool, _pickups, "pickup")
	_blend_entity_array(Array(current_data.get("barriers", [])), Array(following_data.get("barriers", [])), amount, _barrier_pool, _barriers, "barrier")
	data["projectiles"] = _projectiles
	data["hazards"] = _hazards
	data["effects"] = _effects
	data["world_pickups"] = _pickups
	data["barriers"] = _barriers
	return data

func _copy_entity(source: Dictionary, target: Dictionary, entity: String) -> void:
	# Schema descriptors are static. Reuse their selection and copy each mutable
	# value once into the frame, preserving ownership without an intermediate copy.
	target.clear()
	for descriptor in _fields_for(entity):
		var key := String(descriptor["key"])
		if not source.has(key) and not descriptor.has("default"): continue
		var value: Variant = source.get(key, descriptor.get("default"))
		if value is Array: value = Array(value).duplicate(true)
		elif value is Dictionary: value = Dictionary(value).duplicate(true)
		target[key] = value

func _fields_for(entity: String) -> Array[Dictionary]:
	if not _entity_fields.has(entity):
		_entity_fields[entity] = StateFieldSchemaScript.entity_descriptors(entity, StateFieldSchemaScript.PRESENTATION)
	return _entity_fields[entity]

func _blend_action(current: Dictionary, following: Dictionary, weight: float, target: Dictionary) -> void:
	_copy_dictionary(following, target)
	if String(current.get("kind", "idle")) == String(following.get("kind", "idle")):
		target["elapsed"] = lerpf(float(current.get("elapsed", 0.0)), float(following.get("elapsed", 0.0)), weight)

func _capture_entity_array(source: Array, pool: Array[Dictionary], output: Array[Dictionary], entity: String) -> void:
	_ensure_pool(pool, source.size())
	output.clear()
	for index in range(source.size()):
		_copy_entity(Dictionary(source[index]), pool[index], entity)
		output.append(pool[index])

func _blend_entity_array(current: Array, following: Array, weight: float, pool: Array[Dictionary], output: Array[Dictionary], entity: String) -> void:
	_following_by_id.clear()
	for index in range(following.size()):
		var following_item := Dictionary(following[index])
		_following_by_id[_presentation_key(following_item, index)] = following_item
	_ensure_pool(pool, maxi(current.size(), following.size()))
	output.clear()
	for index in range(current.size()):
		var item := Dictionary(current[index])
		var presentation_key: Variant = _presentation_key(item, index)
		var has_following := _following_by_id.has(presentation_key)
		if not has_following and weight >= 0.5: continue
		var next_item := Dictionary(_following_by_id.get(presentation_key, item))
		var target := pool[output.size()]
		_blend_entity(item, next_item, target, entity, weight)
		output.append(target)
		_following_by_id.erase(presentation_key)
	if weight >= 0.5:
		for value in _following_by_id.values():
			var target := pool[output.size()]
			_copy_entity(Dictionary(value), target, entity)
			output.append(target)

func _presentation_key(item: Dictionary, legacy_index: int) -> Variant:
	return int(item["presentation_id"]) if item.has("presentation_id") else "legacy:%d" % legacy_index

func _copy_dictionary(source: Dictionary, target: Dictionary, excluded: Array[String] = []) -> void:
	target.clear()
	for key_value in source:
		var key := String(key_value)
		if excluded.has(key): continue
		var value: Variant = source[key_value]
		if value is Array: target[key_value] = Array(value).duplicate(true)
		elif value is Dictionary: target[key_value] = Dictionary(value).duplicate(true)
		else: target[key_value] = value

func _blend_entity(current: Dictionary, following: Dictionary, target: Dictionary, entity: String, weight: float, excluded: Array[String] = []) -> void:
	target.clear()
	for descriptor in _fields_for(entity):
		var key := String(descriptor["key"])
		if key in excluded or (not current.has(key) and not following.has(key)): continue
		var current_value: Variant = current.get(key, descriptor.get("default"))
		var following_value: Variant = following.get(key, current_value)
		target[key] = _blended_value(current_value, following_value, String(descriptor.get("interpolate", "carry")), weight)

func _blended_value(current: Variant, following: Variant, policy: String, weight: float) -> Variant:
	match policy:
		"float": return lerpf(float(current), float(following), weight)
		"vector": return Vector2(current).lerp(Vector2(following), weight)
		"direction": return _blend_direction(Vector2(current), Vector2(following), weight)
		"action":
			var action := {}
			_blend_action(Dictionary(current), Dictionary(following), weight, action)
			return action
		_:
			if following is Dictionary: return Dictionary(following).duplicate(true)
			if following is Array: return Array(following).duplicate(true)
			return following

func _ensure_enemy_pool(size: int) -> void:
	while _enemy_pool.size() < size: _enemy_pool.append({"action": {}})

func _ensure_pool(pool: Array[Dictionary], size: int) -> void:
	while pool.size() < size: pool.append({})

func _blend_direction(current: Vector2, following: Vector2, weight: float) -> Vector2:
	var blended := current.lerp(following, weight)
	return blended.normalized() if blended.length_squared() > 0.001 else current.normalized()
