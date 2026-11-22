extends RefCounted

const Experiment = preload("res://scripts/core/survey_experiment.gd")
const MAX_EVENTS := 8
const MAX_ENEMIES := 8

static func capture(state: RunState, entry: String, presentation: String) -> Dictionary:
	var identity := Experiment.identity()
	var player := _actor(state.actor_view(0), state.player_action, state.player_facing, state.player_conditions)
	player.merge({
		"character": state.loadout_id, "weapon": state.player_weapon_frame,
		"max_hp": state.player_max_hp, "energy": state.player_energy,
		"level": state.character_level(), "posture_max": state.player_posture_max,
	})
	var nearby: Array[Dictionary] = []
	for enemy in state.enemies:
		if enemy.layer == state.current_layer and int(enemy.hp) > 0 and state.enemy_visible_to_player(enemy) and state.is_visible(enemy.pos):
			nearby.append(enemy)
	nearby.sort_custom(func(a, b): return state.player_pos.distance_squared_to(a.pos) < state.player_pos.distance_squared_to(b.pos))
	var actors: Array[Dictionary] = []
	for enemy in nearby.slice(0, MAX_ENEMIES):
		var actor := _actor(state.actor_view(enemy), enemy.action, enemy.facing, enemy.conditions)
		actor.merge({"awareness": enemy.awareness, "max_hp": enemy.max_hp, "boss_phase": enemy.boss_phase})
		actors.append(actor)

	var context := {
		"game_version": state.GAME_VERSION,
		"build": String(identity.get("build", "development")).left(120),
		"source": String(identity.get("source", "")).left(64),
		"mode": entry, "seed": str(state.run_seed), "layer": state.current_layer,
		"area_id": state.current_area_id, "area": state.current_area_name(),
		"combat_rules": state.combat_rules, "view": presentation,
		"tick": state._simulation_tick_index, "simulation_seconds": state.simulation_time,
		"player": player, "visible_enemy_count": nearby.size(), "enemies": actors,
		"recent_messages": state.recent_gameplay_messages.duplicate(true),
	}
	if not state.expedition.is_empty(): context["biome_index"] = int(state.expedition["biome"])
	if state.is_measurement_mode():
		context["room"] = {
			"number": state.survey_room_number, "seed": str(state.survey_room_seed),
			"profile": state.survey_profile,
			"arena": String(state.survey_room_definition.get("arena", "")),
			"recipe": String(state.survey_room_definition.get("recipe_id", "")),
			"behavior": String(state.survey_experiment.get("behavior", "")),
			"scenario": String(state.survey_experiment.get("scenario", "")),
		}
		var events: Array[Dictionary] = []
		for event in state.survey_enemy_action_events.slice(-MAX_EVENTS):
			events.append({
				"at": float(event.get("at", 0.0)), "enemy_id": int(event.get("enemy_id", -1)),
				"enemy_kind": String(event.get("enemy_kind", "")).left(48), "event": String(event.get("event", "")).left(48),
				"action": String(event.get("action", "")).left(48), "label": String(event.get("label", "")).left(80),
				"elapsed": float(event.get("elapsed", 0.0)), "startup": float(event.get("startup", 0.0)),
				"visible": bool(event.get("visible", false)),
			})
		context["recent_enemy_actions"] = events
	return context

static func _actor(actor: Dictionary, action: Dictionary, facing: Vector2, conditions: Dictionary) -> Dictionary:
	var position: Vector2 = actor.pos
	var elapsed := float(action.get("elapsed", 0.0))
	var active_end := float(action.get("active_end", 0.0))
	var startup := float(action.get("startup", 0.0))
	return {
		"id": actor.id, "kind": actor.kind, "pos": [position.x, position.y],
		"facing": [facing.x, facing.y], "hp": actor.hp, "posture": actor.posture,
		"conditions": conditions.keys().slice(0, 12),
		"action": {
			"kind": String(action.get("kind", "idle")),
			"ability": String(action.get("ability_id", "")),
			"technique": String(action.get("technique_id", "")),
			"elapsed": elapsed, "startup": startup, "active_end": active_end,
			"duration": float(action.get("duration", 0.0)),
			"combo_phase": int(action.get("committed_phase", -1)),
		},
	}
