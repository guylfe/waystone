class_name RunState
extends RefCounted

const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const FloorGeneratorScript = preload("res://scripts/core/floor_generator.gd")
const ModeRulesScript = preload("res://scripts/core/mode_rules.gd")

signal changed
signal message_changed(text: String)

const WORLD_SIZE := Vector2(15600.0, 7000.0)
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
const NAV_CELL := 75.0
const VISIBILITY_CELL := 50.0
const SIGHT_RANGE := 520.0
const WAYSTONE_RANGE := 145.0
const SPATIAL_CELL := 360.0
const ACTIVE_ENEMY_RADIUS := 1750.0

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
var floor_shapes: Array[Dictionary] = []
var terrain_features: Array[Dictionary] = []
var geometry_style := "rooms"
var world_size := WORLD_SIZE
var waystones: Array[Dictionary] = []
var shortcuts: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
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
var _streamed_enemy_indices := PackedInt32Array()
var _active_captains: Array[Dictionary] = []
var _active_enemy_cache_dirty := true
var _flow_target_cell := Vector2i(-999999, -999999)
var _flow_next_cell: Dictionary = {}
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
}
var _profile_action_count := 0
var _streamed_action_cpu_usec := 0
var _simulation_tick_index := 0

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
	death_report.clear()
	last_anchor_report.clear()
	rooms_cleared = 0
	current_area_id = -1
	enemies_defeated = 0
	damage_dealt = 0
	simulation_time = 0.0
	_simulation_tick_index = 0
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
	var layout: Dictionary = FloorGeneratorScript.generate(run_seed, bool(mode_config["waystone_available"]))
	world_size = Vector2(layout.get("world_size", WORLD_SIZE))
	geometry_style = String(layout.get("geometry_style", "rooms"))
	areas.assign(Array(layout["areas"]).duplicate(true))
	connections.assign(Array(layout["connections"]).duplicate(true))
	floor_shapes.assign(Array(layout.get("floor_shapes", [])).duplicate(true))
	terrain_features.assign(Array(layout.get("terrain_features", [])).duplicate(true))
	waystones.assign(Array(layout.get("waystones", [])).duplicate(true))
	shortcuts.assign(Array(layout.get("shortcuts", [])).duplicate(true))
	transitions.assign(Array(layout.get("transitions", [])).duplicate(true))
	world_layers = Dictionary(layout.get("layers", {})).duplicate(true)
	encounter_templates = Dictionary(layout["encounters"]).duplicate(true)
	base_walls_by_layer = Dictionary(layout.get("layer_walls", {})).duplicate(true)
	bonfire_pos = Vector2(layout["bonfire_pos"])
	active_waystone_id = String(waystones[0]["id"]) if not waystones.is_empty() else ""
	current_layer = String(waystones[0]["layer"]) if not waystones.is_empty() else "expedition_surface"
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
	if bool(mode_config["waystone_available"]):
		_capture_anchor_history()
		message = "The Waystone anchors this moment. Time is frozen."
	else:
		message = "The expedition begins. Death ends the run."
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
			enemy["layer"] = String(template.get("layer", "expedition_surface"))
			enemy["heard_sound_sequence"] = _sound_sequence
			enemies.append(enemy)
	_invalidate_active_enemy_cache()

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

func request_move(direction: Vector2, distance: float = MOVE_RANGE, simulate_immediately: bool = true) -> bool:
	if not begin_streamed_move(direction, distance): return false
	if simulate_immediately: _simulate_until_ready()
	return true

func begin_streamed_move(direction: Vector2, distance: float = MOVE_RANGE) -> bool:
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
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_skill(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if loadout_id != "duelist": return false
	return request_sweeping_cut(direction, simulate_immediately)

func request_sweeping_cut(direction: Vector2, simulate_immediately: bool = true) -> bool:
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
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_dodge(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or dodge_cooldown > 0.0001 or direction.length_squared() < 0.01:
		return false
	player_facing = direction.normalized()
	player_action = _action("dodge", 0.66, player_facing)
	player_action["speed"] = DODGE_SPEED
	dodge_cooldown = DODGE_COOLDOWN * _defense_cooldown_multiplier
	_emit_sound(player_pos, 270.0)
	_set_message("You commit to a dodge.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_block(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or block_cooldown > 0.0001 or direction.length_squared() < 0.01:
		return false
	player_facing = direction.normalized()
	player_action = _action("block", 1.10, player_facing)
	player_action["startup"] = 0.16
	player_action["active_end"] = 0.78
	block_cooldown = BLOCK_COOLDOWN * _defense_cooldown_multiplier
	_set_message("You commit to a directional guard.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_endure(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or endure_cooldown > 0.0001:
		return false
	if direction.length_squared() > 0.01:
		player_facing = direction.normalized()
	player_action = _action("endure", 1.05, player_facing)
	player_action["startup"] = 0.14
	player_action["active_end"] = 0.72
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
	if not is_player_ready() or potions <= 0 or player_hp >= player_max_hp:
		return false
	potions -= 1
	player_action = _action("potion", 0.72, Vector2.ZERO)
	_emit_sound(player_pos, 90.0)
	_set_message("You uncork the last restorative.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_wait(duration: float = 0.50, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete:
		return false
	if interaction_label() != "WAIT": return request_context_action()
	player_action = _action("wait", clampf(duration, 0.1, 1.0), Vector2.ZERO)
	_set_message("You deliberately surrender time.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func interaction_label() -> String:
	if not run_active or death_pending: return "WAIT"
	if bool(mode_config["waystone_available"]) and not nearby_waystone().is_empty(): return "REST"
	var shortcut := _nearby_locked_shortcut()
	if not shortcut.is_empty(): return "CLEAR" if String(shortcut.get("presentation", "")) == "hidden_woodland_path" else "UNLOCK"
	if not _nearby_transition().is_empty(): return "TRAVERSE"
	return "WAIT"

func request_context_action() -> bool:
	if not is_player_ready(): return false
	match interaction_label():
		"REST": return activate_waystone()
		"UNLOCK", "CLEAR": return unlock_shortcut()
		"TRAVERSE": return use_transition()
		_: return request_wait()

func can_learn_at_waystone() -> bool:
	return bool(mode_config["waystone_available"]) and secured_xp >= next_upgrade_cost()

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
	var parts: Array[String] = ["health restored", "enemies revived"]
	if xp_gained > 0: parts.append("%d XP integrated" % xp_gained)
	if memories_gained > 0: parts.append("%d map traces anchored" % memories_gained)
	if shortcut_gained: parts.append("shortcut remembered")
	_set_message("Waystone: %s." % ", ".join(parts))
	changed.emit()
	return true

func learn_at_waystone() -> bool:
	if not bool(mode_config["waystone_available"]) or nearby_waystone().is_empty() or not is_player_ready(): return false
	if secured_xp < next_upgrade_cost():
		_set_message("More experience is needed before another lesson can be integrated.")
		changed.emit()
		return false
	_roll_upgrade_choices("waystone")
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
		loaded_terrain_features.append(feature)
		if String(feature.get("kind", "")) == "tree":
			var radius := float(feature.get("radius", 40.0))
			base_walls.append(Rect2(Vector2(feature["pos"]) - Vector2.ONE * radius * 0.42, Vector2.ONE * radius * 0.84))
	_build_terrain_feature_spatial_index()
	if geometry_style != "organic": base_walls.assign(Array(base_walls_by_layer.get(current_layer, [])))
	performance_metrics["loaded_regions"] = loaded_region_ids.size()
	_invalidate_active_enemy_cache()

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
		var cell := _spatial_cell_for_point(Vector2(feature["pos"]))
		if not _terrain_feature_buckets.has(cell): _terrain_feature_buckets[cell] = []
		_terrain_feature_buckets[cell].append(feature)

func nearby_terrain_features(position: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in _spatial_cells_for_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		for feature in Array(_terrain_feature_buckets.get(cell, [])): result.append(feature)
	return result

func nearby_render_walls(position: Vector2, radius: float) -> Array[Rect2]:
	return _nearby_walls(position, radius)

func _invalidate_active_enemy_cache() -> void:
	_active_enemy_cache_dirty = true
	_enemy_spatial_cache_dirty = true

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
	_active_captains.clear()
	_refresh_active_enemy_cache()
	var active_count := 0
	for index in _streamed_enemy_indices:
		var enemy: Dictionary = enemies[index]
		var cell := _spatial_cell_for_point(Vector2(enemy["pos"]))
		if not _enemy_buckets.has(cell): _enemy_buckets[cell] = []
		_enemy_buckets[cell].append(enemy)
		_enemy_bucket_cell_by_id[int(enemy["id"])] = cell
		if String(enemy.get("kind", "")) == "captain" and int(enemy.get("hp", 0)) > 0: _active_captains.append(enemy)
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
			var key := str(Rect2(wall))
			if not seen.has(key):
				seen[key] = true
				result.append(wall)
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
	return int(enemy.get("hp", 0)) > 0 and String(enemy.get("layer", current_layer)) == current_layer and (loaded_region_ids.has(int(enemy.get("area_id", -1))) or Vector2(enemy["pos"]).distance_to(player_pos) <= ACTIVE_ENEMY_RADIUS)

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
	dodge_cooldown = maxf(0.0, dodge_cooldown - dt)
	block_cooldown = maxf(0.0, block_cooldown - dt)
	endure_cooldown = maxf(0.0, endure_cooldown - dt)
	skill_cooldown = maxf(0.0, skill_cooldown - dt)
	strength_remaining = maxf(0.0, strength_remaining - dt)
	_build_enemy_spatial_index()
	_update_effects(dt)
	_update_player(dt)
	_update_exploration()
	_try_recover_xp()
	_update_enemies(dt, _simulation_tick_index % 2 == 0)
	_update_projectiles(dt)
	_update_hazards(dt)
	_remove_dead_enemies()

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
	var sample: Dictionary = AttackGeometryScript.pose(sampled_action, player_pos, player_facing, _nearby_walls(player_pos, player_attack_reach + 90.0))
	if not bool(sample.get("multi", false)) and bool(player_action.get("hit_done", false)): return
	var hit_ids: Array = player_action["hit_ids"]
	var contacts: Array[Dictionary] = []
	for enemy in _nearby_enemies(player_pos, player_attack_reach + 120.0):
		if not _enemy_on_current_layer(enemy): continue
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

func _update_enemies(dt: float, update_locomotion: bool = true) -> void:
	_refresh_active_enemy_cache()
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy := enemies[index]
		# Large expedition parts may contain several encounter groups. Distant,
		# unaware groups remain frozen until the player approaches, keeping action
		# simulation proportional to the active locale rather than the whole run.
		if Vector2(enemy["pos"]).distance_to(player_pos) > 1450.0 and String(enemy.get("awareness", "idle")) == "idle": continue
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
			elif _streamed_enemy_indices.size() > 8 and (_simulation_tick_index + int(enemy["id"])) % 4 != 0:
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
			if update_locomotion:
				var speed := _enemy_move_speed(enemy)
				enemy["pos"] = _move_actor(Vector2(enemy["pos"]), Vector2(action["direction"]) * speed * dt * 2.0, float(enemy["radius"]), int(enemy["id"]))
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
		_update_enemy_bucket_membership(enemy)
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
	if _enemy_spatial_cache_dirty: _build_enemy_spatial_index()
	for enemy in _active_captains:
		if String(enemy.get("layer", current_layer)) == String(subject.get("layer", current_layer)) and String(enemy["kind"]) == "captain" and int(enemy["hp"]) > 0 and Vector2(enemy["pos"]).distance_to(Vector2(subject["pos"])) <= 720.0: return true
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
	var sample: Dictionary = AttackGeometryScript.pose(action, Vector2(enemy["pos"]), Vector2(enemy["facing"]), _nearby_walls(Vector2(enemy["pos"]), float(action.get("reach", 220.0)) + 90.0))
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
		"layer": String(enemy.get("layer", current_layer)),
	})

func _spawn_hex(enemy: Dictionary, target: Vector2) -> void:
	hazards.append({"kind": "hex", "pos": target, "radius": 100.0, "elapsed": 0.0, "trigger_at": 0.82, "duration": 1.12, "damage": 2, "source_id": int(enemy["id"]), "triggered": false, "layer": String(enemy.get("layer", current_layer))})
	_set_message("A hex gathers beneath you.")

func _update_hazards(dt: float) -> void:
	var survivors: Array[Dictionary] = []
	for hazard in hazards:
		if String(hazard.get("layer", current_layer)) != current_layer:
			survivors.append(hazard)
			continue
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
		if String(projectile.get("layer", current_layer)) != current_layer:
			survivors.append(projectile)
			continue
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

func _add_effect(kind: String, position: Vector2, amount: int = 0) -> void:
	var duration := 1.10 if kind == "anchor" else 0.90 if kind == "recover" else 0.62 if kind in ["hit", "hurt", "endure"] else 0.42
	effects.append({"kind": kind, "pos": position, "elapsed": 0.0, "duration": duration, "amount": amount, "layer": current_layer})

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
			var kind := String(enemy["kind"])
			carried_xp += _xp_for_enemy(kind)
			defeated_areas[int(enemy.get("area_id", 0))] = true
			if kind == "warden":
				_boss_defeated = true
				if mode_id == ModeRulesScript.EXPEDITION:
					trial_complete = true
					_set_message("The Warden falls. The expedition is complete.")
				else: _set_message("The Warden falls. The path beyond remains anchored.")
			else: _set_message("The %s falls. XP gained." % kind)
	enemies = living
	_invalidate_active_enemy_cache()
	for area_id in defeated_areas:
		var still_alive := false
		for enemy in enemies:
			if int(enemy.get("area_id", -1)) == int(area_id): still_alive = true
		if not still_alive and int(area_id) >= 0:
			rooms_cleared = maxi(rooms_cleared, _cleared_area_count())

func _xp_for_enemy(kind: String) -> int:
	return int({"knife": 1, "blade": 2, "archer": 2, "hound": 2, "polearm": 4, "hexer": 4, "brute": 5, "captain": 5, "warden": 12}.get(kind, 2))

func _cleared_area_count() -> int:
	var occupied: Dictionary = {}
	for enemy in enemies: occupied[int(enemy.get("area_id", -1))] = true
	var count := 0
	for area in areas:
		var area_id := int(area["id"])
		if not occupied.has(area_id): count += 1
	return count

func _build_navigation() -> void:
	navigation = AStarGrid2D.new()
	_flow_target_cell = Vector2i(-999999, -999999)
	_flow_next_cell.clear()
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
	if _loaded_floor_shapes.is_empty(): return
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
	for angle in [0.0, 0.55, -0.55, 1.05, -1.05, 1.55, -1.55]:
		var candidate := desired.rotated(float(angle)).normalized()
		if not _position_blocked_with_context(origin + candidate * 42.0, radius, actor_id, local_walls, local_enemies): return candidate
	return Vector2.ZERO

func _position_blocked_with_context(position: Vector2, radius: float, actor_id: int, local_walls: Array[Rect2], local_enemies: Array[Dictionary]) -> bool:
	if not _inside_world(position, radius): return true
	for wall in local_walls:
		if _circle_intersects_rect(position, radius, wall): return true
	if actor_id != 0 and position.distance_to(player_pos) < radius + PLAYER_RADIUS: return true
	for enemy in local_enemies:
		if _enemy_on_current_layer(enemy) and int(enemy["id"]) != actor_id and int(enemy["hp"]) > 0 and position.distance_to(Vector2(enemy["pos"])) < radius + float(enemy["radius"]): return true
	return not _actor_footprint_on_floor(position, radius)

func _move_actor(origin: Vector2, delta: Vector2, radius: float, actor_id: int) -> Vector2:
	# Both axis candidates share the same nearby geometry. Querying the spatial
	# buckets twice was a major dense-crowd movement cost with no behavior gain.
	var query_padding := delta.length() + 8.0
	var local_walls := _nearby_walls(origin, radius + query_padding)
	var local_enemies := _nearby_enemies(origin, radius + delta.length() + 80.0)
	var result := origin
	var candidate := Vector2(origin.x + delta.x, origin.y)
	if not _position_blocked_with_context(candidate, radius, actor_id, local_walls, local_enemies):
		result.x = candidate.x
	candidate = Vector2(result.x, origin.y + delta.y)
	if not _position_blocked_with_context(candidate, radius, actor_id, local_walls, local_enemies):
		result.y = candidate.y
	return result

func _position_blocked(position: Vector2, radius: float, actor_id: int) -> bool:
	if not _inside_world(position, radius): return true
	for wall in _nearby_walls(position, radius + 8.0):
		if _circle_intersects_rect(position, radius, wall):
			return true
	if actor_id == 0:
		for enemy in _nearby_enemies(position, radius + 80.0):
			if _enemy_on_current_layer(enemy) and int(enemy["hp"]) > 0 and position.distance_to(Vector2(enemy["pos"])) < radius + float(enemy["radius"]):
				return true
	else:
		if position.distance_to(player_pos) < radius + PLAYER_RADIUS:
			return true
		for enemy in _nearby_enemies(position, radius + 80.0):
			if _enemy_on_current_layer(enemy) and int(enemy["id"]) != actor_id and int(enemy["hp"]) > 0 and position.distance_to(Vector2(enemy["pos"])) < radius + float(enemy["radius"]):
				return true
	return not _actor_footprint_on_floor(position, radius)

func _inside_world(position: Vector2, radius: float) -> bool:
	return position.x >= radius and position.y >= radius and position.x <= world_size.x - radius and position.y <= world_size.y - radius

func _actor_footprint_on_floor(position: Vector2, radius: float) -> bool:
	for direction in [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		if not _point_on_loaded_floor(position + direction * radius * 0.72): return false
	return true

func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(nearest) < radius * radius

func _point_in_wall(point: Vector2) -> bool:
	for wall in _nearby_walls(point, 2.0):
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
	var center_cell := _visibility_cell(player_pos)
	if not force and center_cell == _visibility_anchor_cell: return
	var profile_start := Time.get_ticks_usec()
	_visibility_anchor_cell = center_cell
	_visibility_anchor = (Vector2(center_cell) + Vector2(0.5, 0.5)) * VISIBILITY_CELL
	visible_cells.clear()
	var radius_cells := int(ceil(SIGHT_RANGE / VISIBILITY_CELL))
	var added_discovery := false
	for x in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
		for y in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
			var cell := Vector2i(x, y)
			var point := (Vector2(cell) + Vector2(0.5, 0.5)) * VISIBILITY_CELL
			if point.distance_to(_visibility_anchor) > SIGHT_RANGE or not _point_on_floor(point): continue
			if _visibility_cells_have_line(center_cell, cell):
				visible_cells[cell] = true
				if not discovered_cells.has(cell):
					discovered_cells[cell] = true
					discovery_log.append(cell)
					added_discovery = true
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
	if String(mode_config["upgrade_policy"]) == "area_exit" and previous_area_id >= 0 and current_area_id != previous_area_id:
		if _area_is_clear(previous_area_id) and carried_xp >= next_upgrade_cost() and not upgrade_pending and not trial_complete:
			_roll_upgrade_choices("area_exit")
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
	return {
		"time": simulation_time,
		"player_pos": player_pos,
		"player_facing": player_facing,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"loadout_id": loadout_id,
		"defense_id": defense_id,
		"player_action": player_action.duplicate(true),
		"enemies": _timeline_enemies() if lightweight else enemies.duplicate(true),
		"walls": [] if lightweight else walls.duplicate(),
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
		"boss_defeated": _boss_defeated,
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
		"areas": [] if lightweight else areas.duplicate(true),
		"connections": [] if lightweight else connections.duplicate(true),
		"floor_shapes": [] if lightweight else floor_shapes.duplicate(true),
		"terrain_features": [] if lightweight else terrain_features.duplicate(true),
		"geometry_style": geometry_style,
		"world_size": world_size,
		"waystones": [] if lightweight else waystones.duplicate(true),
		"shortcuts": [] if lightweight else shortcuts.duplicate(true),
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
		"upgrade_context": upgrade_context,
		"death_pending": death_pending,
		"run_failed": run_failed,
		"anchor_state": {} if lightweight else anchor_state.duplicate(true),
		"performance_metrics": performance_metrics.duplicate(),
	}

func _timeline_enemies() -> Array[Dictionary]:
	var nearby: Array[Dictionary] = []
	_refresh_active_enemy_cache()
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy: Dictionary = enemies[index]
		if Vector2(enemy["pos"]).distance_to(player_pos) <= ACTIVE_ENEMY_RADIUS: nearby.append(_enemy_presentation(enemy))
	return nearby

func _enemy_presentation(enemy: Dictionary) -> Dictionary:
	return {
		"id": int(enemy["id"]),
		"kind": String(enemy["kind"]),
		"pos": Vector2(enemy["pos"]),
		"facing": Vector2(enemy["facing"]),
		"hp": int(enemy["hp"]),
		"max_hp": int(enemy["max_hp"]),
		"radius": float(enemy["radius"]),
		"posture": float(enemy.get("posture", 0.0)),
		"posture_max": float(enemy.get("posture_max", 1.0)),
		"action": Dictionary(enemy["action"]).duplicate(true),
		"awareness": String(enemy.get("awareness", "idle")),
		"layer": String(enemy.get("layer", current_layer)),
	}

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
	return {
		"save_version": 12,
		"time": simulation_time,
		"player_pos": player_pos,
		"player_facing": player_facing,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_move_speed": player_move_speed,
		"player_attack_duration": player_attack_duration,
		"player_attack_startup": player_attack_startup,
		"player_attack_active_end": player_attack_active_end,
		"player_damage_min": player_damage_min,
		"player_damage_max": player_damage_max,
		"player_attack_reach": player_attack_reach,
		"defense_cooldown_multiplier": _defense_cooldown_multiplier,
		"skill_cooldown_multiplier": _skill_cooldown_multiplier,
		"loadout_id": loadout_id,
		"enemies": enemies.duplicate(true),
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
		"message": message,
		"run_active": run_active,
		"mode_id": mode_id,
		"progression_mode": progression_mode,
		"map_presentation": map_presentation,
		"current_layer": current_layer,
		"active_waystone_id": active_waystone_id,
		"shortcut_unlocked": shortcut_unlocked,
		"shortcuts": shortcuts.duplicate(true),
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
		"rng_state": rng.state,
	}

func load_run(path: String = "user://waystone-expedition.save") -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var value: Variant = file.get_var(true)
	if not value is Dictionary: return false
	var payload: Dictionary = value
	var save_version := int(payload.get("save_version", 0))
	if save_version < 1 or save_version > 12: return false
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
	_boss_defeated = bool(payload.get("boss_defeated", trial_complete))
	upgrade_pending = bool(payload.get("upgrade_pending", false))
	upgrade_choices.assign(Array(payload.get("upgrade_choices", [])))
	upgrade_context = String(payload.get("upgrade_context", ""))
	upgrades.assign(Array(payload.get("upgrades", [])))
	upgrade_count = int(payload.get("upgrade_count", upgrades.size()))
	upgrade_ranks = Dictionary(payload.get("upgrade_ranks", {})).duplicate(true)
	carried_xp = int(payload.get("carried_xp", 0))
	secured_xp = int(payload.get("secured_xp", carried_xp if save_version < 6 and mode_id == ModeRulesScript.CAMPAIGN_LAB else 0))
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
	_apply_shortcut_world_state()
	visible_cells = Dictionary(payload.get("visible_cells", {})).duplicate()
	discovered_cells_by_layer = Dictionary(payload.get("discovered_cells_by_layer", {})).duplicate(true)
	if discovered_cells_by_layer.is_empty(): discovered_cells_by_layer[current_layer] = Dictionary(payload.get("discovered_cells", {})).duplicate()
	_load_current_layer_discovery()
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
	if position_was_migrated: message = "The expedition route shifted. You return to its beginning."
	rng.state = int(payload.get("rng_state", rng.state))
	_next_enemy_id = 1
	for enemy in enemies:
		enemy["action"] = _idle_action()
		enemy.erase("nav_path")
		enemy.erase("nav_target_cell")
		_next_enemy_id = maxi(_next_enemy_id, int(enemy["id"]) + 1)
	anchor_state = Dictionary(payload.get("anchor_state", {})).duplicate(true)
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
