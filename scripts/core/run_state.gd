class_name RunState
extends RefCounted

const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const FloorGeneratorScript = preload("res://scripts/core/floor_generator.gd")
const ModeRulesScript = preload("res://scripts/core/mode_rules.gd")

signal changed
signal message_changed(text: String)

const WORLD_SIZE := Vector2(5000.0, 4400.0)
const SIM_DT := 1.0 / 120.0
const FRAME_DT := 1.0 / 60.0
const PLAYER_RADIUS := 30.0
const ENEMY_RADIUS := 28.0
const PLAYER_MAX_HP := 10
const MOVE_SPEED := 320.0
const MOVE_RANGE := 34.0
const DODGE_SPEED := 560.0
const DODGE_COOLDOWN := 4.0
const BLOCK_COOLDOWN := 3.5
const ENDURE_COOLDOWN := 4.5
const SWEEP_COOLDOWN := 4.2
const NAV_CELL := 50.0
const VISIBILITY_CELL := 50.0
const SIGHT_RANGE := 520.0

var player_pos := Vector2(800.0, 1900.0)
var player_facing := Vector2.UP
var player_hp := PLAYER_MAX_HP
var player_max_hp := PLAYER_MAX_HP
var player_move_speed := MOVE_SPEED
var player_attack_duration := 1.20
var player_attack_startup := 0.38
var player_attack_active_end := 0.68
var player_damage_min := 2
var player_damage_max := 3
var player_attack_technique := "diagonal_cut"
var player_attack_reach := 136.0
var player_attack_posture := 2.0
var loadout_id := "duelist"
var defense_id := "dodge"
var player_action := _idle_action()
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var walls: Array[Rect2] = []
var dodge_cooldown := 0.0
var block_cooldown := 0.0
var endure_cooldown := 0.0
var skill_cooldown := 0.0
var strength_remaining := 0.0
var potions := 1
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
var effects: Array[Dictionary] = []
var message := "Time is frozen. Choose an action."
var last_timeline: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var _next_enemy_id := 1
var navigation := AStarGrid2D.new()
var run_active := false
var mode_id := ModeRulesScript.EXPEDITION
var mode_config: Dictionary = ModeRulesScript.definition(mode_id)
var progression_mode := "area_exit"
var map_presentation := "full"
var areas: Array[Dictionary] = []
var connections: Array[Dictionary] = []
var encounter_templates: Dictionary = {}
var base_walls: Array[Rect2] = []
var bonfire_pos := Vector2.ZERO
var shortcut_gate := Rect2()
var shortcut_unlock_pos := Vector2.ZERO
var shortcut_start_pos := Vector2.ZERO
var shortcut_unlocked := false
var visible_cells: Dictionary = {}
var discovered_cells: Dictionary = {}
var _visibility_anchor := Vector2.INF
var current_area_id := 0
var carried_xp := 0
var secured_xp := 0
var lost_xp := {"active": false, "amount": 0, "pos": Vector2.ZERO}
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

func _init(auto_start: bool = true) -> void:
	rng.seed = run_seed
	_apply_loadout()
	player_hp = player_max_hp
	if auto_start: start_run(loadout_id, mode_id, run_seed)

func build_laboratory() -> void:
	start_run(loadout_id, ModeRulesScript.CAMPAIGN_LAB, run_seed)

func build_expedition_room() -> void:
	start_run(loadout_id, ModeRulesScript.EXPEDITION, run_seed)

func start_run(chosen_loadout: String, chosen_mode: String, seed_override: int = -1) -> void:
	loadout_id = chosen_loadout if chosen_loadout in ["duelist", "guardian", "reaver"] else "duelist"
	mode_id = ModeRulesScript.normalize(chosen_mode)
	mode_config = ModeRulesScript.definition(mode_id)
	progression_mode = String(mode_config["upgrade_policy"])
	if seed_override >= 0: run_seed = seed_override
	else: run_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	_apply_loadout()
	player_hp = player_max_hp
	player_facing = Vector2.UP
	player_action = _idle_action()
	dodge_cooldown = 0.0
	block_cooldown = 0.0
	endure_cooldown = 0.0
	skill_cooldown = 0.0
	strength_remaining = 0.0
	potions = 1
	trial_complete = false
	upgrade_pending = false
	upgrade_choices.clear()
	upgrades.clear()
	upgrade_ranks.clear()
	upgrade_count = 0
	upgrade_context = ""
	_defense_cooldown_multiplier = 1.0
	_skill_cooldown_multiplier = 1.0
	_sound_sequence = 0
	last_sound = {"sequence": 0, "pos": Vector2.ZERO, "radius": 0.0}
	carried_xp = 0
	secured_xp = 0
	lost_xp = {"active": false, "amount": 0, "pos": Vector2.ZERO}
	rooms_cleared = 0
	enemies_defeated = 0
	damage_dealt = 0
	simulation_time = 0.0
	perfect_dodges = 0
	counter_hits = 0
	successful_blocks = 0
	successful_endures = 0
	effects.clear()
	hazards.clear()
	projectiles.clear()
	death_pending = false
	run_failed = false
	anchor_state.clear()
	shortcut_unlocked = false
	_boss_defeated = false
	rng.seed = run_seed
	var layout: Dictionary = FloorGeneratorScript.generate(run_seed)
	areas.assign(Array(layout["areas"]).duplicate(true))
	connections.assign(Array(layout["connections"]).duplicate(true))
	encounter_templates = Dictionary(layout["encounters"]).duplicate(true)
	base_walls.assign(Array(layout["base_walls"]))
	walls.assign(Array(layout["walls"]))
	bonfire_pos = Vector2(layout["bonfire_pos"])
	_player_start = Vector2(layout["player_start"])
	player_pos = _player_start
	shortcut_gate = Rect2(layout["shortcut_gate"])
	shortcut_unlock_pos = Vector2(layout["shortcut_unlock_pos"])
	shortcut_start_pos = Vector2(layout["shortcut_start_pos"])
	discovered_cells.clear()
	visible_cells.clear()
	_visibility_anchor = Vector2.INF
	_respawn_enemies()
	_build_navigation()
	run_active = true
	_update_exploration(true)
	if bool(mode_config["waystone_available"]):
		_capture_anchor_history()
		message = "The Waystone anchors this moment. Time is frozen."
	else:
		message = "The starting Waystone fades behind you. Death ends the expedition."
	last_timeline.clear()
	changed.emit()
	message_changed.emit(message)

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

func _enemy_base_hp(kind: String) -> int:
	return {"knife": 4, "blade": 7, "hound": 6, "archer": 5, "shield": 10, "polearm": 12, "hexer": 7, "brute": 16, "captain": 12, "warden": 26}.get(kind, 7)

func _make_enemy(kind: String, position: Vector2, hp: int, area_id: int = 0) -> Dictionary:
	var posture_max := _enemy_posture_max(kind)
	var enemy := {
		"id": _next_enemy_id,
		"kind": kind,
		"pos": position,
		"spawn_pos": position,
		"area_id": area_id,
		"facing": Vector2.DOWN,
		"hp": hp,
		"max_hp": hp,
		"radius": 52.0 if kind == "warden" else 46.0 if kind == "brute" else 42.0 if kind == "polearm" else 25.0 if kind == "hound" else 22.0 if kind == "knife" else ENEMY_RADIUS,
		"posture": posture_max,
		"posture_max": posture_max,
		"posture_recovery_delay": 0.0,
		"action": _idle_action(),
		"awareness": "idle",
		"alert_remaining": 0.0,
		"suspicious_remaining": 0.0,
		"last_known_player": position,
		"heard_sound_sequence": 0,
	}
	_next_enemy_id += 1
	return enemy

func _respawn_enemies() -> void:
	enemies.clear()
	projectiles.clear()
	hazards.clear()
	_next_enemy_id = 1
	for area_key in encounter_templates:
		var area_id := int(area_key)
		for template in Array(encounter_templates[area_key]):
			var kind := String(template["kind"])
			if kind == "warden" and _boss_defeated: continue
			var enemy := _make_enemy(kind, Vector2(template["pos"]), _enemy_base_hp(kind), area_id)
			enemy["heard_sound_sequence"] = _sound_sequence
			enemies.append(enemy)

func _enemy_posture_max(kind: String) -> float:
	return {"knife": 2.0, "hound": 3.0, "archer": 3.0, "hexer": 3.0, "blade": 5.0, "captain": 6.0, "shield": 8.0, "polearm": 8.0, "brute": 14.0, "warden": 18.0}.get(kind, 5.0)

func select_loadout(choice: String) -> bool:
	if not ["duelist", "guardian", "reaver"].has(choice):
		return false
	loadout_id = choice
	if run_active: start_run(loadout_id, mode_id, run_seed)
	else: _apply_loadout()
	return true

func _apply_loadout() -> void:
	match loadout_id:
		"guardian":
			defense_id = "block"
			player_max_hp = 14
			player_move_speed = 285.0
			player_attack_duration = 1.40
			player_attack_startup = 0.48
			player_attack_active_end = 0.82
			player_damage_min = 2
			player_damage_max = 4
			player_attack_technique = "heavy_chop"
			player_attack_reach = 142.0
			player_attack_posture = 3.5
		"reaver":
			defense_id = "endure"
			player_max_hp = 11
			player_move_speed = 305.0
			player_attack_duration = 1.50
			player_attack_startup = 0.55
			player_attack_active_end = 0.90
			player_damage_min = 3
			player_damage_max = 4
			player_attack_technique = "broad_sweep"
			player_attack_reach = 150.0
			player_attack_posture = 3.0
		_:
			defense_id = "dodge"
			player_max_hp = 9
			player_move_speed = 340.0
			player_attack_duration = 1.05
			player_attack_startup = 0.32
			player_attack_active_end = 0.58
			player_damage_min = 2
			player_damage_max = 3
			player_attack_technique = "diagonal_cut"
			player_attack_reach = 136.0
			player_attack_posture = 2.0

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
	return run_active and not death_pending and not upgrade_pending and String(player_action["kind"]) == "idle" and player_hp > 0

func request_move(direction: Vector2, distance: float = MOVE_RANGE) -> bool:
	if not is_player_ready() or trial_complete or direction.length_squared() < 0.01:
		return false
	var travel := clampf(distance, 4.0, MOVE_RANGE)
	var normalized := direction.normalized()
	player_facing = normalized
	player_action = _action("move", travel / player_move_speed, normalized)
	player_action["distance"] = travel
	player_action["speed"] = player_move_speed
	_emit_sound(player_pos, 130.0)
	_set_message("You commit to a step.")
	_simulate_until_ready()
	return true

func request_move_to(target: Vector2) -> bool:
	var delta := target - player_pos
	return request_move(delta, minf(delta.length(), MOVE_RANGE))

func request_attack(target: Vector2) -> bool:
	if not is_player_ready() or trial_complete:
		return false
	var direction := target - player_pos
	if direction.length_squared() < 0.01:
		direction = player_facing
	player_facing = direction.normalized()
	player_action = _melee_action(player_attack_duration, player_attack_startup, player_attack_active_end, player_attack_reach, player_damage_max, player_facing, player_attack_technique, "attack")
	player_action["damage_min"] = player_damage_min
	player_action["damage_max"] = player_damage_max
	player_action["posture_damage"] = player_attack_posture
	_emit_sound(player_pos, 350.0)
	_set_message("You commit to the %s." % AttackGeometryScript.label(player_attack_technique).to_lower())
	_simulate_until_ready()
	return true

func request_skill(direction: Vector2) -> bool:
	if loadout_id != "duelist": return false
	return request_sweeping_cut(direction)

func request_sweeping_cut(direction: Vector2) -> bool:
	if not is_player_ready() or trial_complete or skill_cooldown > 0.0001 or direction.length_squared() < 0.01:
		return false
	player_facing = direction.normalized()
	player_action = _melee_action(1.32, 0.44, 0.84, 158.0, 3, player_facing, "broad_sweep", "sweep")
	player_action["posture_damage"] = 5.0
	player_action["damage_min"] = 2
	player_action["damage_max"] = 3
	skill_cooldown = SWEEP_COOLDOWN * _skill_cooldown_multiplier
	_emit_sound(player_pos, 470.0)
	_set_message("You commit to a broad, posture-breaking cut.")
	_simulate_until_ready()
	return true

func request_dodge(direction: Vector2) -> bool:
	if not is_player_ready() or trial_complete or dodge_cooldown > 0.0001 or direction.length_squared() < 0.01:
		return false
	player_facing = direction.normalized()
	player_action = _action("dodge", 0.66, player_facing)
	player_action["speed"] = DODGE_SPEED
	dodge_cooldown = DODGE_COOLDOWN * _defense_cooldown_multiplier
	_emit_sound(player_pos, 270.0)
	_set_message("You commit to a dodge.")
	_simulate_until_ready()
	return true

func request_block(direction: Vector2) -> bool:
	if not is_player_ready() or trial_complete or block_cooldown > 0.0001 or direction.length_squared() < 0.01:
		return false
	player_facing = direction.normalized()
	player_action = _action("block", 1.10, player_facing)
	player_action["startup"] = 0.16
	player_action["active_end"] = 0.78
	block_cooldown = BLOCK_COOLDOWN * _defense_cooldown_multiplier
	_set_message("You commit to a directional guard.")
	_simulate_until_ready()
	return true

func request_endure(direction: Vector2) -> bool:
	if not is_player_ready() or trial_complete or endure_cooldown > 0.0001:
		return false
	if direction.length_squared() > 0.01:
		player_facing = direction.normalized()
	player_action = _action("endure", 1.05, player_facing)
	player_action["startup"] = 0.14
	player_action["active_end"] = 0.72
	endure_cooldown = ENDURE_COOLDOWN * _defense_cooldown_multiplier
	_set_message("You brace to turn pain into strength.")
	_simulate_until_ready()
	return true

func request_defense(direction: Vector2) -> bool:
	match defense_id:
		"block": return request_block(direction)
		"endure": return request_endure(direction)
		_: return request_dodge(direction)

func request_potion() -> bool:
	if not is_player_ready() or potions <= 0 or player_hp >= player_max_hp:
		return false
	potions -= 1
	player_action = _action("potion", 0.72, Vector2.ZERO)
	_emit_sound(player_pos, 90.0)
	_set_message("You uncork the last restorative.")
	_simulate_until_ready()
	return true

func request_wait(duration: float = 0.50) -> bool:
	if not is_player_ready() or trial_complete:
		return false
	if interaction_label() != "WAIT": return request_context_action()
	player_action = _action("wait", clampf(duration, 0.1, 1.0), Vector2.ZERO)
	_set_message("You deliberately surrender time.")
	_simulate_until_ready()
	return true

func interaction_label() -> String:
	if not run_active or death_pending: return "WAIT"
	if not shortcut_unlocked and player_pos.distance_to(shortcut_unlock_pos) <= 115.0: return "UNLOCK"
	if bool(mode_config["waystone_available"]) and player_pos.distance_to(bonfire_pos) <= 125.0: return "WAYSTONE"
	return "WAIT"

func request_context_action() -> bool:
	if not is_player_ready(): return false
	match interaction_label():
		"UNLOCK": return unlock_shortcut()
		_: return request_wait()

func rest_at_waystone() -> bool:
	if not bool(mode_config["waystone_available"]) or player_pos.distance_to(bonfire_pos) > 125.0 or not is_player_ready(): return false
	_restore_at_waystone()
	_respawn_enemies()
	_update_exploration(true)
	_set_message("The Waystone restores you. The world stirs again.")
	changed.emit()
	return true

func learn_at_waystone() -> bool:
	if not bool(mode_config["waystone_available"]) or player_pos.distance_to(bonfire_pos) > 125.0 or not is_player_ready(): return false
	if carried_xp < next_upgrade_cost():
		_set_message("More experience is needed before another lesson can be integrated.")
		changed.emit()
		return false
	_roll_upgrade_choices("waystone")
	changed.emit()
	return true

func anchor_at_waystone() -> bool:
	if not bool(mode_config["waystone_available"]) or player_pos.distance_to(bonfire_pos) > 125.0 or not is_player_ready(): return false
	secured_xp = carried_xp
	_capture_anchor_history()
	_set_message("Your experience, map, and opened paths settle into the Waystone.")
	changed.emit()
	return true

func unlock_shortcut() -> bool:
	if shortcut_unlocked or player_pos.distance_to(shortcut_unlock_pos) > 115.0 or not is_player_ready(): return false
	shortcut_unlocked = true
	walls.assign(base_walls)
	for connection in connections:
		if bool(connection.get("shortcut", false)): connection["unlocked"] = true
	_build_navigation()
	_update_exploration(true)
	_set_message("The sealed way opens back to the Waystone.")
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
	player_pos = _player_start
	player_facing = (bonfire_pos - player_pos).normalized()
	_respawn_enemies()
	_update_exploration(true)
	_set_message("You reform at the Waystone. Reclaim your lost XP.")
	changed.emit()
	return true

func _capture_anchor_history() -> void:
	var discovered_areas: Array[bool] = []
	for area in areas: discovered_areas.append(bool(area.get("discovered", false)))
	anchor_state = {
		"shortcut_unlocked": shortcut_unlocked,
		"discovered_cells": discovered_cells.duplicate(),
		"discovered_areas": discovered_areas,
	}

func _restore_anchor_history() -> void:
	if anchor_state.is_empty(): return
	shortcut_unlocked = bool(anchor_state.get("shortcut_unlocked", false))
	_apply_shortcut_world_state()
	discovered_cells = Dictionary(anchor_state.get("discovered_cells", {})).duplicate()
	var discovered_areas: Array = anchor_state.get("discovered_areas", [])
	for index in range(areas.size()):
		areas[index]["discovered"] = bool(discovered_areas[index]) if index < discovered_areas.size() else index == 0
	visible_cells.clear()
	_visibility_anchor = Vector2.INF

func _apply_shortcut_world_state() -> void:
	walls.assign(base_walls)
	if not shortcut_unlocked: walls.append(shortcut_gate)
	for connection in connections:
		if bool(connection.get("shortcut", false)): connection["unlocked"] = shortcut_unlocked
	_build_navigation()

func _restore_at_waystone() -> void:
	player_hp = player_max_hp
	potions = 1
	dodge_cooldown = 0.0
	block_cooldown = 0.0
	endure_cooldown = 0.0
	skill_cooldown = 0.0
	strength_remaining = 0.0
	player_action = _idle_action()
	projectiles.clear()
	hazards.clear()
	effects.clear()

func choose_upgrade(choice: String) -> bool:
	if not upgrade_pending or not upgrade_choices.has(choice) or carried_xp < next_upgrade_cost(): return false
	var cost := next_upgrade_cost()
	carried_xp -= cost
	secured_xp = mini(secured_xp, carried_xp)
	upgrades.append(choice)
	upgrade_ranks[choice] = int(upgrade_ranks.get(choice, 0)) + 1
	upgrade_count += 1
	match choice:
		"keen_edge": player_damage_max += 1
		"vitality":
			player_max_hp += 2
			player_hp += 2
		"quick_hands": player_attack_duration = maxf(player_attack_active_end + 0.16, player_attack_duration - 0.10)
		"long_reach": player_attack_reach += 14.0
		"footwork": player_move_speed *= 1.05
		"readiness":
			_defense_cooldown_multiplier *= 0.92
			_skill_cooldown_multiplier *= 0.92
	upgrade_pending = false
	upgrade_choices.clear()
	var context := upgrade_context
	upgrade_context = ""
	_set_message("Upgrade gained: %s." % upgrade_name(choice))
	if carried_xp >= next_upgrade_cost() and context in ["area_exit", "waystone"]:
		_roll_upgrade_choices(context)
	changed.emit()
	return true

func leave_upgrade_menu() -> bool:
	if not upgrade_pending or upgrade_context != "waystone": return false
	upgrade_pending = false
	upgrade_choices.clear()
	upgrade_context = ""
	_set_message("You leave the XP unspent.")
	changed.emit()
	return true

func next_upgrade_cost() -> int:
	return 6 + 4 * upgrade_count

func upgrade_name(id: String) -> String:
	return {"keen_edge": "Keen Edge", "vitality": "Vitality", "quick_hands": "Quick Hands", "long_reach": "Long Reach", "footwork": "Footwork", "readiness": "Readiness"}.get(id, id.capitalize())

func upgrade_description(id: String) -> String:
	return {"keen_edge": "+1 maximum damage", "vitality": "+2 maximum health", "quick_hands": "Shorter attack recovery", "long_reach": "+14 attack reach", "footwork": "+5% movement speed", "readiness": "Shorter cooldowns"}.get(id, "")

func _roll_upgrade_choices(context: String = "area_exit") -> void:
	var pool: Array[String] = ["keen_edge", "vitality", "quick_hands", "long_reach", "footwork", "readiness"]
	for index in range(pool.size() - 1, -1, -1):
		if int(upgrade_ranks.get(pool[index], 0)) >= 3: pool.remove_at(index)
	if pool.is_empty(): return
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = temporary
	upgrade_choices.assign(pool.slice(0, mini(3, pool.size())))
	upgrade_pending = true
	upgrade_context = context

func _action(kind: String, duration: float, direction: Vector2) -> Dictionary:
	var result := _idle_action()
	result["kind"] = kind
	result["duration"] = duration
	result["direction"] = direction
	return result

func _simulate_until_ready() -> void:
	last_timeline.clear()
	last_timeline.append(snapshot())
	var frame_accumulator := 0.0
	var guard := 0
	while String(player_action["kind"]) != "idle" and player_hp > 0 and guard < 1000:
		_tick(SIM_DT)
		frame_accumulator += SIM_DT
		if frame_accumulator + 0.00001 >= FRAME_DT:
			last_timeline.append(snapshot())
			frame_accumulator = 0.0
		guard += 1
	if last_timeline.is_empty() or float(last_timeline[-1]["time"]) != simulation_time:
		last_timeline.append(snapshot())
	changed.emit()

func _tick(dt: float) -> void:
	simulation_time += dt
	dodge_cooldown = maxf(0.0, dodge_cooldown - dt)
	block_cooldown = maxf(0.0, block_cooldown - dt)
	endure_cooldown = maxf(0.0, endure_cooldown - dt)
	skill_cooldown = maxf(0.0, skill_cooldown - dt)
	strength_remaining = maxf(0.0, strength_remaining - dt)
	_update_effects(dt)
	_update_player(dt)
	_update_exploration()
	_try_recover_xp()
	_update_enemies(dt)
	_update_projectiles(dt)
	_update_hazards(dt)
	_remove_dead_enemies()

func _try_recover_xp() -> void:
	if bool(lost_xp.get("active", false)) and player_pos.distance_to(Vector2(lost_xp.get("pos", Vector2.ZERO))) <= 58.0:
		var amount := int(lost_xp.get("amount", 0))
		carried_xp += amount
		lost_xp = {"active": false, "amount": 0, "pos": Vector2.ZERO}
		_add_effect("recover", player_pos, amount)
		_set_message("Recovered %d XP." % amount)

func _update_player(dt: float) -> void:
	var kind := String(player_action["kind"])
	if kind == "idle":
		return
	player_action["elapsed"] = float(player_action["elapsed"]) + dt
	var elapsed := float(player_action["elapsed"])
	match kind:
		"move":
			player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, PLAYER_RADIUS, 0)
		"dodge":
			if elapsed >= 0.08 and elapsed <= 0.38:
				player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, PLAYER_RADIUS, 0)
		"attack":
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				_resolve_player_attack_tick(elapsed)
		"sweep":
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				_resolve_player_attack_tick(elapsed)
		"potion":
			if elapsed >= 0.28 and not bool(player_action["effect_done"]):
				player_action["effect_done"] = true
				player_hp = mini(player_max_hp, player_hp + 5)
				_set_message("Warmth returns to your limbs.")
	if elapsed + 0.00001 >= float(player_action["duration"]):
		if kind in ["attack", "sweep"] and Array(player_action["hit_ids"]).is_empty():
			_set_message("Your cut finds only air.")
		elif kind == "block" and not bool(player_action["effect_done"]):
			_set_message("You lower the guard without contact.")
		elif kind == "endure" and not bool(player_action["effect_done"]):
			_set_message("The Endure window passes without a hit.")
		player_action = _idle_action()

func _resolve_player_attack_tick(elapsed: float) -> void:
	var is_sweep := String(player_action["kind"]) == "sweep"
	var sampled_action := player_action.duplicate()
	var sample: Dictionary = AttackGeometryScript.pose(sampled_action, player_pos, player_facing, walls)
	if not bool(sample.get("multi", false)) and bool(player_action.get("hit_done", false)): return
	var hit_ids: Array = player_action["hit_ids"]
	var contacts: Array[Dictionary] = []
	for enemy in enemies:
		var enemy_id := int(enemy["id"])
		if hit_ids.has(enemy_id): continue
		if AttackGeometryScript.hits_circle(sample, Vector2(enemy["pos"]), float(enemy["radius"])):
			contacts.append({"enemy": enemy, "order": AttackGeometryScript.contact_order(sample, Vector2(enemy["pos"])), "point": AttackGeometryScript.contact_point(sample, Vector2(enemy["pos"]))})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["order"]) < float(b["order"]))
	if not bool(sample.get("multi", false)) and contacts.size() > 1: contacts.resize(1)
	if not bool(sample.get("multi", false)) and not contacts.is_empty(): player_action["hit_done"] = true
	for contact in contacts:
		var enemy: Dictionary = contact["enemy"]
		enemy["awareness"] = "alerted"
		enemy["alert_remaining"] = 3.0
		enemy["last_known_player"] = player_pos
		hit_ids.append(int(enemy["id"]))
		var hit_point := Vector2(contact["point"])
		if _enemy_blocks_attack(enemy):
			_apply_posture_damage(enemy, 2.0 if is_sweep else 0.5)
			_add_effect("block", hit_point)
			_set_message("The shield catches your weapon.")
		else:
			var bonus := 2 if strength_remaining > 0.0 else 0
			var damage_min := int(player_action.get("damage_min", player_damage_min))
			var damage_max := int(player_action.get("damage_max", player_damage_max))
			var dealt := rng.randi_range(damage_min + bonus, damage_max + bonus)
			enemy["hp"] = int(enemy["hp"]) - dealt
			damage_dealt += dealt
			_apply_posture_damage(enemy, float(player_action.get("posture_damage", 2.0)))
			_add_effect("hit", hit_point, dealt)
			_set_message("The %s connects." % AttackGeometryScript.label(String(player_action.get("technique_id", "diagonal_cut"))).to_lower())
	player_action["hit_ids"] = hit_ids

func _enemy_blocks_attack(enemy: Dictionary) -> bool:
	if String(enemy["kind"]) != "shield": return false
	var incoming := player_pos - Vector2(enemy["pos"])
	return _within_arc(Vector2(enemy["facing"]), incoming, deg_to_rad(72.0))

func _apply_posture_damage(enemy: Dictionary, amount: float) -> void:
	if amount <= 0.0 or int(enemy["hp"]) <= 0: return
	enemy["posture"] = maxf(0.0, float(enemy.get("posture", 1.0)) - amount)
	enemy["posture_recovery_delay"] = 1.15
	if float(enemy["posture"]) <= 0.0001:
		_break_posture(enemy)

func _break_posture(enemy: Dictionary) -> void:
	var action: Dictionary = enemy["action"]
	var kind := String(enemy["kind"])
	var action_kind := String(action.get("kind", "idle"))
	var elapsed := float(action.get("elapsed", 0.0))
	var active_started := action.has("startup") and elapsed >= float(action.get("startup", 999.0))
	if kind in ["brute", "warden"] and active_started and action_kind in ["melee", "slam", "charge"]:
		enemy["posture"] = 0.25
		_add_effect("strain", Vector2(enemy["pos"]))
		_set_message("The heavy enemy holds its grounded attack.")
		return
	var stagger_duration := 0.52 if kind in ["knife", "hound"] else 0.66 if kind in ["archer", "hexer"] else 0.78
	enemy["action"] = _action("stagger", stagger_duration, Vector2.ZERO)
	enemy["posture"] = 0.0
	enemy["posture_recovery_delay"] = stagger_duration
	_add_effect("posture_break", Vector2(enemy["pos"]))
	_set_message("The %s loses its footing." % kind)

func _emit_sound(position: Vector2, radius: float) -> void:
	_sound_sequence += 1
	last_sound = {"sequence": _sound_sequence, "pos": position, "radius": radius}

func _update_enemy_awareness(enemy: Dictionary, dt: float) -> void:
	var enemy_pos := Vector2(enemy["pos"])
	var offset := player_pos - enemy_pos
	var distance := offset.length()
	var facing := Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
	var vision_range := 620.0 if String(enemy["kind"]) in ["archer", "hexer", "warden"] else SIGHT_RANGE
	var within_cone := distance <= 105.0 or (distance <= vision_range and absf(facing.angle_to(offset.normalized())) <= deg_to_rad(65.0))
	var sees_player := within_cone and _has_line_of_sight(enemy_pos, player_pos)
	if sees_player:
		enemy["awareness"] = "alerted"
		enemy["alert_remaining"] = 3.0
		enemy["last_known_player"] = player_pos
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

func _update_enemies(dt: float) -> void:
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if int(enemy["hp"]) <= 0:
			continue
		_update_enemy_awareness(enemy, dt)
		enemy["posture_recovery_delay"] = maxf(0.0, float(enemy.get("posture_recovery_delay", 0.0)) - dt)
		if float(enemy["posture_recovery_delay"]) <= 0.0 and String(Dictionary(enemy["action"])["kind"]) == "idle":
			enemy["posture"] = minf(float(enemy["posture_max"]), float(enemy["posture"]) + dt * 1.8)
		var action: Dictionary = enemy["action"]
		if String(action["kind"]) == "idle":
			var awareness := String(enemy.get("awareness", "idle"))
			if awareness == "idle":
				enemies[index] = enemy
				continue
			elif awareness == "suspicious":
				var target := Vector2(enemy.get("last_known_player", enemy["spawn_pos"]))
				if Vector2(enemy["pos"]).distance_to(target) > 45.0:
					enemy["action"] = _action("move", 0.40, _navigation_direction(enemy, target))
				else:
					enemy["facing"] = (target - Vector2(enemy["pos"])).normalized()
					enemies[index] = enemy
					continue
			else: _choose_enemy_action(enemy)
			action = enemy["action"]
		action["elapsed"] = float(action["elapsed"]) + dt
		var kind := String(action["kind"])
		var elapsed := float(action["elapsed"])
		if kind == "move":
			var speed := _enemy_move_speed(enemy)
			enemy["pos"] = _move_actor(Vector2(enemy["pos"]), Vector2(action["direction"]) * speed * dt, float(enemy["radius"]), int(enemy["id"]))
		elif kind == "melee" and elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]) and not bool(action["hit_done"]):
			_resolve_enemy_melee_tick(enemy, elapsed)
		elif kind == "charge" and elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]):
			var charge_origin := Vector2(enemy["pos"])
			enemy["pos"] = _move_actor(charge_origin, Vector2(action["direction"]) * float(action.get("speed", 340.0)) * dt, float(enemy["radius"]), int(enemy["id"]))
			if Vector2(enemy["pos"]).is_equal_approx(charge_origin):
				enemy["action"] = _action("stagger", 0.62, Vector2.ZERO)
				enemy["posture"] = maxf(0.0, float(enemy["posture"]) - 1.0)
				_add_effect("posture_break", charge_origin)
				_set_message("The %s crashes into an obstacle." % String(enemy["kind"]))
				enemies[index] = enemy
				continue
			if not bool(action["hit_done"]) and Vector2(enemy["pos"]).distance_to(player_pos) <= float(enemy["radius"]) + PLAYER_RADIUS + 8.0:
				action["hit_done"] = true
				_resolve_incoming_hit(int(enemy["id"]), int(action.get("damage", 2)), String(enemy["kind"]))
		elif kind == "slam" and elapsed >= float(action["startup"]) and not bool(action["hit_done"]):
			action["hit_done"] = true
			_add_effect("slam", Vector2(enemy["pos"]))
			if Vector2(enemy["pos"]).distance_to(player_pos) <= float(action.get("reach", 205.0)):
				_resolve_incoming_hit(int(enemy["id"]), int(action.get("damage", 4)), String(enemy["kind"]))
		elif kind == "shoot" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_projectile(enemy)
		elif kind == "hex" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_hex(enemy, Vector2(action["target"]))
		if elapsed + 0.00001 >= float(action["duration"]):
			if kind == "stagger": enemy["posture"] = float(enemy["posture_max"])
			enemy["action"] = _idle_action()
		enemies[index] = enemy

func _choose_enemy_action(enemy: Dictionary) -> void:
	var offset := player_pos - Vector2(enemy["pos"])
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.01 else Vector2.DOWN
	enemy["facing"] = direction
	var enemy_kind := String(enemy["kind"])
	if enemy_kind == "blade":
		if distance <= 125.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(1.45, 0.52, 0.82, 128.0, 2, direction, "diagonal_cut")
		else:
			enemy["action"] = _action("move", 0.48, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "knife":
		if distance <= 92.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(0.88, 0.28, 0.46, 92.0, 1, direction, "quick_cut")
		else:
			enemy["action"] = _action("move", 0.32, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "polearm":
		if distance <= 218.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(2.25, 0.90, 1.35, 218.0, 3, direction, "thrust")
		else:
			enemy["action"] = _action("move", 0.70, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "shield":
		if distance <= 120.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(1.65, 0.62, 0.92, 122.0, 2, direction)
		else: enemy["action"] = _action("move", 0.58, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "hound":
		if distance <= 330.0 and distance >= 82.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _charge_action(1.28, 0.42, 0.78, 405.0, 2, direction)
		elif distance < 82.0: enemy["action"] = _melee_action(0.95, 0.28, 0.48, 88.0, 1, direction, "bite")
		else: enemy["action"] = _action("move", 0.38, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "brute":
		if distance <= 155.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(2.55, 1.02, 1.52, 158.0, 4, direction, "forward_smash")
		else: enemy["action"] = _action("move", 0.78, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "captain":
		if distance <= 138.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(1.22, 0.42, 0.70, 140.0, 2, direction, "thrust")
		else: enemy["action"] = _action("move", 0.44, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "hexer":
		if distance <= 620.0 and distance >= 150.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("hex", 1.85, direction)
			enemy["action"]["startup"] = 0.68
			enemy["action"]["target"] = player_pos + player_facing * 24.0
		else:
			var target := Vector2(enemy["pos"]) + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 220.0 if distance < 500.0 else player_pos
			enemy["action"] = _action("move", 0.52, _navigation_direction(enemy, target))
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
		else: enemy["action"] = _action("move", 0.72, _navigation_direction(enemy, player_pos))
	else:
		if distance <= 690.0 and distance >= 230.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("shoot", 1.75, direction)
			enemy["action"]["startup"] = 0.72
		else:
			var move_target := player_pos if distance > 520.0 else Vector2(enemy["pos"]) - direction * 240.0
			var move_direction := _navigation_direction(enemy, move_target)
			enemy["facing"] = direction
			enemy["action"] = _action("move", 0.56, move_direction)

func _enemy_move_speed(enemy: Dictionary) -> float:
	var kind := String(enemy["kind"])
	var speed: float = float({"knife": 230.0, "blade": 175.0, "polearm": 95.0, "archer": 135.0, "shield": 120.0, "hound": 245.0, "brute": 82.0, "hexer": 125.0, "captain": 180.0, "warden": 105.0}.get(kind, 135.0))
	if kind != "captain" and _captain_near(enemy): speed *= 1.14
	return speed

func _captain_near(subject: Dictionary) -> bool:
	for enemy in enemies:
		if String(enemy["kind"]) == "captain" and int(enemy["hp"]) > 0 and Vector2(enemy["pos"]).distance_to(Vector2(subject["pos"])) <= 720.0: return true
	return false

func _charge_action(duration: float, startup: float, active_end: float, speed: float, damage: int, direction: Vector2) -> Dictionary:
	var result := _action("charge", duration, direction)
	result["startup"] = startup
	result["active_end"] = active_end
	result["speed"] = speed
	result["damage"] = damage
	return result

func _resolve_enemy_melee_tick(enemy: Dictionary, elapsed: float) -> void:
	var action: Dictionary = enemy["action"]
	var sample: Dictionary = AttackGeometryScript.pose(action, Vector2(enemy["pos"]), Vector2(enemy["facing"]), walls)
	if AttackGeometryScript.hits_circle(sample, player_pos, PLAYER_RADIUS):
		enemy["action"]["hit_done"] = true
		var contact := AttackGeometryScript.contact_point(sample, player_pos)
		_resolve_incoming_hit(int(enemy["id"]), int(action["damage"]), String(enemy["kind"]), Vector2.ZERO, contact)

func _melee_action(duration: float, startup: float, active_end: float, reach: float, damage: int, direction: Vector2, technique_id: String = "diagonal_cut", action_kind: String = "melee") -> Dictionary:
	var result := _action(action_kind, duration, direction)
	result["startup"] = startup
	result["active_end"] = active_end
	result["reach"] = reach
	result["damage"] = damage
	result["technique_id"] = technique_id
	return result

func _spawn_projectile(enemy: Dictionary) -> void:
	var direction: Vector2 = Vector2(enemy["facing"]).normalized()
	projectiles.append({
		"pos": Vector2(enemy["pos"]) + direction * 42.0,
		"vel": direction * 470.0,
		"radius": 9.0,
		"damage": 2,
		"source_id": int(enemy["id"]),
	})

func _spawn_hex(enemy: Dictionary, target: Vector2) -> void:
	hazards.append({"kind": "hex", "pos": target, "radius": 100.0, "elapsed": 0.0, "trigger_at": 0.82, "duration": 1.12, "damage": 2, "source_id": int(enemy["id"]), "triggered": false})
	_set_message("A hex gathers beneath you.")

func _update_hazards(dt: float) -> void:
	var survivors: Array[Dictionary] = []
	for hazard in hazards:
		hazard["elapsed"] = float(hazard["elapsed"]) + dt
		if not bool(hazard["triggered"]) and float(hazard["elapsed"]) >= float(hazard["trigger_at"]):
			hazard["triggered"] = true
			_add_effect("hex", Vector2(hazard["pos"]))
			if player_pos.distance_to(Vector2(hazard["pos"])) <= float(hazard["radius"]):
				_resolve_incoming_hit(int(hazard["source_id"]), int(hazard["damage"]), "hex", Vector2(hazard["pos"]) - player_pos)
		if float(hazard["elapsed"]) < float(hazard["duration"]): survivors.append(hazard)
	hazards = survivors

func _update_projectiles(dt: float) -> void:
	var survivors: Array[Dictionary] = []
	for projectile in projectiles:
		var start: Vector2 = projectile["pos"]
		var finish := start + Vector2(projectile["vel"]) * dt
		projectile["pos"] = finish
		if not _inside_world(finish, float(projectile["radius"])) or _point_in_wall(finish):
			continue
		if _segment_distance_to_point(start, finish, player_pos) <= PLAYER_RADIUS + float(projectile["radius"]):
			_resolve_incoming_hit(int(projectile["source_id"]), int(projectile["damage"]), "arrow", -Vector2(projectile["vel"]).normalized())
			continue
		survivors.append(projectile)
	projectiles = survivors

func _resolve_incoming_hit(source_id: int, damage: int, source_name: String, incoming_from: Vector2 = Vector2.ZERO, contact_position: Vector2 = Vector2.INF) -> void:
	var impact := player_pos if not contact_position.is_finite() else contact_position
	if _is_perfect_dodge():
		perfect_dodges += 1
		if not bool(player_action["perfect_triggered"]):
			player_action["perfect_triggered"] = true
			_counter_source(source_id)
		_add_effect("perfect", impact)
		_set_message("Perfect dodge.")
		return
	if _is_blocking(source_id, incoming_from):
		successful_blocks += 1
		player_action["effect_done"] = true
		var chip_damage := 1 if damage >= 3 else 0
		player_hp = maxi(0, player_hp - chip_damage)
		_add_effect("block", impact, chip_damage)
		if chip_damage > 0:
			_set_message("The heavy blow crashes through part of your guard.")
		else:
			_set_message("Your guard catches the %s." % source_name)
		return
	if _is_enduring():
		successful_endures += 1
		player_action["effect_done"] = true
		var endured_damage := maxi(1, int(ceil(float(damage) * 0.70)))
		player_hp = maxi(0, player_hp - endured_damage)
		strength_remaining = maxf(strength_remaining, 5.0)
		_add_effect("endure", impact, endured_damage)
		_set_message("You take the hit and gain Strength for 5 seconds.")
		if player_hp <= 0:
			_begin_death()
		return
	if _is_evasive():
		_add_effect("evade", impact)
		_set_message("The %s misses your evasive movement." % source_name)
		return
	player_hp = maxi(0, player_hp - damage)
	_add_effect("hurt", impact, damage)
	_set_message("The %s hits during your commitment." % source_name)
	if player_hp <= 0:
		_begin_death()

func _begin_death() -> void:
	if death_pending: return
	if bool(mode_config["shadow_enabled"]):
		if bool(lost_xp.get("active", false)): lost_xp = {"active": false, "amount": 0, "pos": Vector2.ZERO}
		var provisional_xp := maxi(0, carried_xp - secured_xp)
		if provisional_xp > 0: lost_xp = {"active": true, "amount": provisional_xp, "pos": player_pos}
		carried_xp = secured_xp
	else:
		lost_xp = {"active": false, "amount": 0, "pos": Vector2.ZERO}
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
		if int(enemy["id"]) == source_id and Vector2(enemy["pos"]).distance_to(player_pos) <= 155.0:
			enemy["hp"] = int(enemy["hp"]) - 2
			_add_effect("hit", Vector2(enemy["pos"]), 2)
			counter_hits += 1
			return

func _is_evasive() -> bool:
	if String(player_action["kind"]) != "dodge":
		return false
	var elapsed := float(player_action["elapsed"])
	return elapsed >= 0.08 and elapsed <= 0.38

func _is_perfect_dodge() -> bool:
	if String(player_action["kind"]) != "dodge":
		return false
	var elapsed := float(player_action["elapsed"])
	return elapsed >= 0.18 and elapsed <= 0.26

func _is_blocking(source_id: int, incoming_from: Vector2 = Vector2.ZERO) -> bool:
	if String(player_action["kind"]) != "block":
		return false
	var elapsed := float(player_action["elapsed"])
	if elapsed < float(player_action["startup"]) or elapsed > float(player_action["active_end"]):
		return false
	if incoming_from.length_squared() > 0.01:
		return _within_arc(player_facing, incoming_from, deg_to_rad(65.0))
	for enemy in enemies:
		if int(enemy["id"]) == source_id:
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

func _add_effect(kind: String, position: Vector2, amount: int = 0) -> void:
	var duration := 0.62 if kind in ["hit", "hurt", "endure"] else 0.42
	effects.append({"kind": kind, "pos": position, "elapsed": 0.0, "duration": duration, "amount": amount})

func _remove_dead_enemies() -> void:
	var living: Array[Dictionary] = []
	var defeated_areas: Dictionary = {}
	for enemy in enemies:
		if int(enemy["hp"]) > 0:
			living.append(enemy)
		else:
			enemies_defeated += 1
			var kind := String(enemy["kind"])
			carried_xp += _xp_for_enemy(kind)
			defeated_areas[int(enemy.get("area_id", 0))] = true
			if kind == "warden":
				_boss_defeated = true
				trial_complete = true
				_set_message("The Warden falls. The expedition is complete.")
			else: _set_message("The %s falls. XP gained." % kind)
	enemies = living
	for area_id in defeated_areas:
		var still_alive := false
		for enemy in enemies:
			if int(enemy.get("area_id", -1)) == int(area_id): still_alive = true
		if not still_alive and int(area_id) > 0:
			rooms_cleared = maxi(rooms_cleared, _cleared_area_count())

func _xp_for_enemy(kind: String) -> int:
	return int({"knife": 1, "blade": 2, "archer": 2, "hound": 2, "polearm": 4, "hexer": 4, "brute": 5, "captain": 5, "warden": 12}.get(kind, 2))

func _cleared_area_count() -> int:
	var occupied: Dictionary = {}
	for enemy in enemies: occupied[int(enemy.get("area_id", -1))] = true
	var count := 0
	for area_id in range(1, 7):
		if not occupied.has(area_id): count += 1
	return count

func _build_navigation() -> void:
	var columns := int(ceil(WORLD_SIZE.x / NAV_CELL))
	var rows := int(ceil(WORLD_SIZE.y / NAV_CELL))
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(0, 0, columns, rows)
	navigation.cell_size = Vector2(NAV_CELL, NAV_CELL)
	navigation.offset = Vector2(NAV_CELL * 0.5, NAV_CELL * 0.5)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(columns):
		for y in range(rows):
			var cell := Vector2i(x, y)
			var center := navigation.get_point_position(cell)
			var solid := false
			for wall in walls:
				if _circle_intersects_rect(center, 34.0, wall):
					solid = true
					break
			navigation.set_point_solid(cell, solid)

func _navigation_direction(enemy: Dictionary, target: Vector2) -> Vector2:
	var origin := Vector2(enemy["pos"])
	var direct := (target - origin).normalized()
	if navigation.region.size == Vector2i.ZERO: return direct
	var from_cell := _nearest_open_cell(_world_to_nav(origin))
	var target_cell := _nearest_open_cell(_world_to_nav(target))
	var path := navigation.get_id_path(from_cell, target_cell, true)
	var desired := direct
	if path.size() >= 2: desired = (navigation.get_point_position(path[1]) - origin).normalized()
	elif path.size() == 1: desired = direct
	return _local_avoidance_direction(enemy, desired)

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
	for angle in [0.0, 0.55, -0.55, 1.05, -1.05, 1.55, -1.55]:
		var candidate := desired.rotated(float(angle)).normalized()
		if not _position_blocked(origin + candidate * 42.0, radius, actor_id): return candidate
	return Vector2.ZERO

func _move_actor(origin: Vector2, delta: Vector2, radius: float, actor_id: int) -> Vector2:
	var result := origin
	var candidate := Vector2(origin.x + delta.x, origin.y)
	if not _position_blocked(candidate, radius, actor_id):
		result.x = candidate.x
	candidate = Vector2(result.x, origin.y + delta.y)
	if not _position_blocked(candidate, radius, actor_id):
		result.y = candidate.y
	return result

func _position_blocked(position: Vector2, radius: float, actor_id: int) -> bool:
	if not _inside_world(position, radius):
		return true
	for wall in walls:
		if _circle_intersects_rect(position, radius, wall):
			return true
	if actor_id == 0:
		for enemy in enemies:
			if int(enemy["hp"]) > 0 and position.distance_to(Vector2(enemy["pos"])) < radius + float(enemy["radius"]):
				return true
	else:
		if position.distance_to(player_pos) < radius + PLAYER_RADIUS:
			return true
		for enemy in enemies:
			if int(enemy["id"]) != actor_id and int(enemy["hp"]) > 0 and position.distance_to(Vector2(enemy["pos"])) < radius + float(enemy["radius"]):
				return true
	return false

func _inside_world(position: Vector2, radius: float) -> bool:
	return position.x >= radius and position.y >= radius and position.x <= WORLD_SIZE.x - radius and position.y <= WORLD_SIZE.y - radius

func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(nearest) < radius * radius

func _point_in_wall(point: Vector2) -> bool:
	for wall in walls:
		if wall.has_point(point):
			return true
	return false

func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var distance := from.distance_to(to)
	var steps := maxi(1, int(ceil(distance / 12.0)))
	for index in range(1, steps):
		if _point_in_wall(from.lerp(to, float(index) / float(steps))):
			return false
	return true

func _update_exploration(force: bool = false) -> void:
	if not run_active: return
	if not force and _visibility_anchor.is_finite() and _visibility_anchor.distance_to(player_pos) < VISIBILITY_CELL * 0.45: return
	_visibility_anchor = player_pos
	visible_cells.clear()
	var center_cell := _visibility_cell(player_pos)
	var radius_cells := int(ceil(SIGHT_RANGE / VISIBILITY_CELL))
	for x in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
		for y in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
			var cell := Vector2i(x, y)
			var point := (Vector2(cell) + Vector2(0.5, 0.5)) * VISIBILITY_CELL
			if point.distance_to(player_pos) > SIGHT_RANGE or not _point_on_floor(point): continue
			if _has_line_of_sight(player_pos, point):
				visible_cells[cell] = true
				discovered_cells[cell] = true
	var previous_area_id := current_area_id
	current_area_id = 0
	for area in areas:
		if Rect2(area["rect"]).has_point(player_pos): current_area_id = int(area["id"])
		if _rect_has_discovered_cell(Rect2(area["rect"])): area["discovered"] = true
	if String(mode_config["upgrade_policy"]) == "area_exit" and previous_area_id > 0 and current_area_id != previous_area_id:
		if _area_is_clear(previous_area_id) and carried_xp >= next_upgrade_cost() and not upgrade_pending and not trial_complete:
			_roll_upgrade_choices("area_exit")

func _area_is_clear(area_id: int) -> bool:
	for enemy in enemies:
		if int(enemy.get("area_id", -1)) == area_id and int(enemy.get("hp", 0)) > 0: return false
	return true

func _visibility_cell(position: Vector2) -> Vector2i:
	return Vector2i(int(floor(position.x / VISIBILITY_CELL)), int(floor(position.y / VISIBILITY_CELL)))

func is_visible(position: Vector2, cells: Dictionary = visible_cells) -> bool:
	return cells.has(_visibility_cell(position))

func is_discovered(position: Vector2, cells: Dictionary = discovered_cells) -> bool:
	return cells.has(_visibility_cell(position))

func _point_on_floor(point: Vector2) -> bool:
	for area in areas:
		if Rect2(area["rect"]).has_point(point): return true
	for connection in connections:
		if Rect2(connection["corridor"]).has_point(point): return true
	return false

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

func snapshot() -> Dictionary:
	return {
		"time": simulation_time,
		"player_pos": player_pos,
		"player_facing": player_facing,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"loadout_id": loadout_id,
		"defense_id": defense_id,
		"player_action": player_action.duplicate(true),
		"enemies": enemies.duplicate(true),
		"walls": walls.duplicate(),
		"projectiles": projectiles.duplicate(true),
		"hazards": hazards.duplicate(true),
		"effects": effects.duplicate(true),
		"dodge_cooldown": dodge_cooldown,
		"block_cooldown": block_cooldown,
		"endure_cooldown": endure_cooldown,
		"skill_cooldown": skill_cooldown,
		"strength_remaining": strength_remaining,
		"potions": potions,
		"trial_complete": trial_complete,
		"run_seed": run_seed,
		"upgrade_pending": upgrade_pending,
		"upgrade_choices": upgrade_choices.duplicate(),
		"upgrades": upgrades.duplicate(),
		"rooms_cleared": rooms_cleared,
		"enemies_defeated": enemies_defeated,
		"damage_dealt": damage_dealt,
		"message": message,
		"run_active": run_active,
		"mode_id": mode_id,
		"mode_config": mode_config.duplicate(true),
		"progression_mode": progression_mode,
		"map_presentation": map_presentation,
		"areas": areas.duplicate(true),
		"connections": connections.duplicate(true),
		"shortcut_unlocked": shortcut_unlocked,
		"bonfire_pos": bonfire_pos,
		"shortcut_unlock_pos": shortcut_unlock_pos,
		"shortcut_start_pos": shortcut_start_pos,
		"visible_cells": visible_cells.duplicate(),
		"discovered_cells": discovered_cells.duplicate(),
		"current_area_id": current_area_id,
		"carried_xp": carried_xp,
		"secured_xp": secured_xp,
		"lost_xp": lost_xp.duplicate(true),
		"upgrade_count": upgrade_count,
		"upgrade_ranks": upgrade_ranks.duplicate(true),
		"upgrade_context": upgrade_context,
		"death_pending": death_pending,
		"run_failed": run_failed,
		"anchor_state": anchor_state.duplicate(true),
	}

func save_run(path: String = "user://waystone-expedition.save") -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	var payload := snapshot()
	payload["save_version"] = 6
	payload["player_move_speed"] = player_move_speed
	payload["player_attack_duration"] = player_attack_duration
	payload["player_attack_startup"] = player_attack_startup
	payload["player_attack_active_end"] = player_attack_active_end
	payload["player_damage_min"] = player_damage_min
	payload["player_damage_max"] = player_damage_max
	payload["player_attack_reach"] = player_attack_reach
	payload["defense_cooldown_multiplier"] = _defense_cooldown_multiplier
	payload["skill_cooldown_multiplier"] = _skill_cooldown_multiplier
	payload["player_facing"] = player_facing
	payload["perfect_dodges"] = perfect_dodges
	payload["counter_hits"] = counter_hits
	payload["successful_blocks"] = successful_blocks
	payload["successful_endures"] = successful_endures
	payload["rng_state"] = rng.state
	file.store_var(payload, true)
	return true

func load_run(path: String = "user://waystone-expedition.save") -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var value: Variant = file.get_var(true)
	if not value is Dictionary: return false
	var payload: Dictionary = value
	var save_version := int(payload.get("save_version", 0))
	if save_version < 1 or save_version > 6: return false
	loadout_id = String(payload.get("loadout_id", "duelist"))
	map_presentation = String(payload.get("map_presentation", "full"))
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
	start_run(loadout_id, mode_id, run_seed)
	run_active = bool(payload.get("run_active", true))
	player_pos = Vector2(payload.get("player_pos", player_pos))
	player_facing = Vector2(payload.get("player_facing", Vector2.UP))
	player_hp = int(payload.get("player_hp", player_max_hp))
	player_max_hp = int(payload.get("player_max_hp", player_max_hp))
	player_move_speed = float(payload.get("player_move_speed", player_move_speed))
	player_attack_duration = float(payload.get("player_attack_duration", player_attack_duration))
	player_attack_startup = float(payload.get("player_attack_startup", player_attack_startup))
	player_attack_active_end = float(payload.get("player_attack_active_end", player_attack_active_end))
	player_damage_min = int(payload.get("player_damage_min", player_damage_min))
	player_damage_max = int(payload.get("player_damage_max", player_damage_max))
	player_attack_reach = float(payload.get("player_attack_reach", player_attack_reach))
	_defense_cooldown_multiplier = float(payload.get("defense_cooldown_multiplier", 1.0))
	_skill_cooldown_multiplier = float(payload.get("skill_cooldown_multiplier", 1.0))
	player_action = _idle_action()
	enemies.assign(Array(payload.get("enemies", enemies)).duplicate(true))
	projectiles.assign(Array(payload.get("projectiles", [])).duplicate(true))
	hazards.assign(Array(payload.get("hazards", [])).duplicate(true))
	effects.assign(Array(payload.get("effects", [])).duplicate(true))
	dodge_cooldown = float(payload.get("dodge_cooldown", 0.0))
	block_cooldown = float(payload.get("block_cooldown", 0.0))
	endure_cooldown = float(payload.get("endure_cooldown", 0.0))
	skill_cooldown = float(payload.get("skill_cooldown", 0.0))
	strength_remaining = float(payload.get("strength_remaining", 0.0))
	potions = int(payload.get("potions", 1))
	trial_complete = bool(payload.get("trial_complete", false))
	_boss_defeated = trial_complete
	upgrade_pending = bool(payload.get("upgrade_pending", false))
	upgrade_choices.assign(Array(payload.get("upgrade_choices", [])))
	upgrade_context = String(payload.get("upgrade_context", ""))
	upgrades.assign(Array(payload.get("upgrades", [])))
	upgrade_count = int(payload.get("upgrade_count", upgrades.size()))
	upgrade_ranks = Dictionary(payload.get("upgrade_ranks", {})).duplicate(true)
	carried_xp = int(payload.get("carried_xp", 0))
	secured_xp = int(payload.get("secured_xp", carried_xp if save_version < 6 and mode_id == ModeRulesScript.CAMPAIGN_LAB else 0))
	lost_xp = Dictionary(payload.get("lost_xp", {"active": false, "amount": 0, "pos": Vector2.ZERO})).duplicate(true)
	shortcut_unlocked = bool(payload.get("shortcut_unlocked", false))
	_apply_shortcut_world_state()
	visible_cells = Dictionary(payload.get("visible_cells", {})).duplicate()
	discovered_cells = Dictionary(payload.get("discovered_cells", {})).duplicate()
	current_area_id = int(payload.get("current_area_id", 0))
	death_pending = bool(payload.get("death_pending", false))
	run_failed = bool(payload.get("run_failed", false))
	rooms_cleared = int(payload.get("rooms_cleared", 0))
	enemies_defeated = int(payload.get("enemies_defeated", 0))
	damage_dealt = int(payload.get("damage_dealt", 0))
	perfect_dodges = int(payload.get("perfect_dodges", 0))
	counter_hits = int(payload.get("counter_hits", 0))
	successful_blocks = int(payload.get("successful_blocks", 0))
	successful_endures = int(payload.get("successful_endures", 0))
	simulation_time = float(payload.get("time", 0.0))
	message = String(payload.get("message", message))
	rng.state = int(payload.get("rng_state", rng.state))
	_next_enemy_id = 1
	for enemy in enemies:
		enemy["action"] = _idle_action()
		_next_enemy_id = maxi(_next_enemy_id, int(enemy["id"]) + 1)
	anchor_state = Dictionary(payload.get("anchor_state", {})).duplicate(true)
	if bool(mode_config["waystone_available"]) and anchor_state.is_empty(): _capture_anchor_history()
	_build_navigation()
	_visibility_anchor = Vector2.INF
	_update_exploration(true)
	last_timeline.clear()
	return true

func restart() -> void:
	start_run(loadout_id, mode_id, run_seed)

func _set_message(text: String) -> void:
	message = text
	message_changed.emit(message)
