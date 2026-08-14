class_name RunState
extends RefCounted

const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")
const FloorGeneratorScript = preload("res://scripts/core/floor_generator.gd")
const ModeRulesScript = preload("res://scripts/core/mode_rules.gd")
const SurveyReportScript = preload("res://scripts/core/survey_report.gd")

signal changed
signal message_changed(text: String)

const WORLD_SIZE := Vector2(15600.0, 7000.0)
const SIM_DT := 1.0 / 120.0
const FRAME_DT := 1.0 / 60.0
const PLAYER_RADIUS := 30.0
const ENEMY_RADIUS := 28.0
const PLAYER_MAX_HP := 100
const MOVE_SPEED := 300.0
const WARRIOR_MOVE_SPEED := 260.0
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
const POSTURE_BREAK_OPENING_SECONDS := 0.72
const ENEMY_MOVE_EPSILON := 0.05
const ENEMY_STEER_INTERVAL := 0.14
const ENEMY_STALL_REPATH_TIME := 0.12
const ENEMY_STALL_ABORT_TIME := 0.42
const TWIN_KNIFE_SEQUENCE_RECOVERY := 1.0
const STAMINA_REGEN_PER_SECOND := 60.0
const STAMINA_REGEN_DELAY := 1.0
const EXHAUSTION_DURATION := 2.0
const DODGE_STAMINA_COST := 18.0
const STAMINA_ATTACK_READINESS_FLOOR := 0.45
const STAMINA_REGEN_ACTIONS := ["move", "wait", "rally", "stealth", "take_aim", "potion", "consumable", "vault", "block", "endure", "hit_reaction", "stagger"]
const SAVE_VERSION := 30
const GAME_VERSION := "0.2.9"
const SURVEY_GENERATOR_VERSION := 3
const PRESENTATION_VERSION := 6
const SWORD_ARTS := ["prototype_sweeping_cut", "prototype_drawing_cut"]
const HEALING_CAPACITY := 5
const CONSUMABLE_SLOT_COUNT := 3
const CONSUMABLES := {
	"throwing_knife": {"label": "Throwing Knife", "short": "KNIFE", "targeted": true, "max_stack": 2, "color": "d7dddd"},
	"firebomb": {"label": "Firebomb", "short": "FIRE", "targeted": true, "max_stack": 2, "color": "f28b4b"},
	"smoke_vial": {"label": "Smoke Vial", "short": "SMOKE", "targeted": false, "max_stack": 1, "color": "9ca9bd"},
}

var player_pos := Vector2(800.0, 1900.0)
var player_facing := Vector2.UP
var player_hp := PLAYER_MAX_HP
var player_max_hp := PLAYER_MAX_HP
var player_stamina := 100.0
var player_max_stamina := 100.0
var player_overexertion_pending := false
var player_exhaustion_remaining := 0.0
var player_stamina_regen_delay := 0.0
var player_attack_readiness_remaining := 0.0
var player_posture := 12.0
var player_posture_max := 12.0
var player_posture_recovery_delay := 0.0
var player_move_speed := MOVE_SPEED
var player_attack_duration := 1.20
var player_attack_startup := 0.38
var player_attack_active_end := 0.68
var player_damage_min := 2
var player_damage_max := 3
var player_attack_technique := "diagonal_cut"
var player_attack_reach := 136.0
var player_attack_posture := 2.0
var loadout_id := "warrior"
var defense_id := "dodge"
# Player loadouts are still temporary prototypes. These shared fields are the
# durable actor foundation that future character sheets and weapon swapping use.
var player_attributes: Dictionary = {}
var player_properties: Dictionary = {}
var martial_foundation: Dictionary = {}
var player_weapon_frame := "sword"
var player_weapon_art_library: Array[String] = []
var player_equipped_weapon_art := ""
var equipment_slots: Dictionary = {}
var track_property_ranks: Dictionary = {}
var track_ranks: Dictionary = {}
var track_choices: Dictionary = {}
var player_action := _idle_action()
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var walls: Array[Rect2] = []
var dodge_cooldown := 0.0
var block_cooldown := 0.0
var endure_cooldown := 0.0
var skill_cooldown := 0.0
var rally_cooldown := 0.0
var advance_cooldown := 0.0
var main_ability_cooldown := 0.0
var subclass_ability_cooldown := 0.0
var weapon_sequence_cooldown := 0.0
var stealth_remaining := 0.0
var stealth_cooldown_pending := false
var assassination_window_remaining := 0.0
var turnabout_remaining := 0.0
var aimed_enemy_id := -1
var aimed_remaining := 0.0
var bow_followup_ready := false
var bow_followup_consumed := false
var player_condition_buildup: Dictionary = {}
var player_conditions: Dictionary = {}
var _condition_tick_accumulator := 0.0
var rally_remaining := 0.0
var rally_end_after_action := false
var rally_break_extension_used := false
var building_force_chain := 0
var counterstep_remaining := 0.0
var strength_remaining := 0.0
var potions := HEALING_CAPACITY
var consumable_slots: Array[Dictionary] = []
var world_pickups: Array[Dictionary] = []
var pending_pickup: Dictionary = {}
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
var damage_received_total := 0
var hits_received_total := 0
var potions_used_total := 0
var stamina_spent_total := 0.0
var stamina_depleted_total := 0.0
var stamina_overdraw_total := 0.0
var stamina_regenerated_total := 0.0
var stamina_regen_delay_time_total := 0.0
var stamina_regen_active_time_total := 0.0
var overexertion_count := 0
var winded_time_total := 0.0
var stamina_blocked_continuations := 0
var exhaustion_damage_received_total := 0
var exhaustion_move_time_total := 0.0
var exhaustion_wait_time_total := 0.0
var exhaustion_other_time_total := 0.0
var attack_readiness_blocked_attempts_total := 0
var attack_readiness_active_time_total := 0.0
var direct_attack_uses_total := 0
var dodge_style_uses_total: Dictionary = {}
var dodge_vulnerable_time_total := 0.0
var dodge_recovery_damage_total := 0
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
var route_recipe: Array[Dictionary] = []
var run_graph: Dictionary = {}
var locale_catalog: Dictionary = {}
var floor_shapes: Array[Dictionary] = []
var terrain_features: Array[Dictionary] = []
var geometry_style := "rooms"
var world_size := WORLD_SIZE
var waystones: Array[Dictionary] = []
var shortcuts: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
var secret_passages: Array[Dictionary] = []
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
var _player_reaction_completed_this_tick := false
var _streamed_enemy_indices := PackedInt32Array()
var _active_captains: Array[Dictionary] = []
var _active_enemy_cache_dirty := true
var _flow_target_cell := Vector2i(-999999, -999999)
var _flow_next_cell: Dictionary = {}
var _navigation_cache: Dictionary = {}
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
	"navigation_build_ms": 0.0,
	"navigation_cache_hit": false,
	"navigation_prewarm_ms": 0.0,
}
var _profile_action_count := 0
var _streamed_action_cpu_usec := 0
var _simulation_tick_index := 0
var _next_combo_instance_id := 1
var survey_profile := "encounter"
var combat_rules := "stamina"
var survey_room_number := 0
var survey_room_seed := 0
var survey_feedback_pending := false
var survey_run_ending := false
var survey_end_reason := ""
var survey_room_definition: Dictionary = {}
var survey_room_entry: Dictionary = {}
var survey_pending_record: Dictionary = {}
var survey_session: Dictionary = {}
var survey_last_report: Dictionary = {}
var survey_action_counts: Dictionary = {}
var survey_last_damage_source := ""
var survey_current_view_mode := "isometric"
var survey_room_view_modes: Array[String] = ["isometric"]
var survey_view_switches := 0
var survey_empty_melee_contacts := 0
var survey_strike_diagnostics: Array[Dictionary] = []

func _init(auto_start: bool = true) -> void:
	rng.seed = run_seed
	_apply_loadout()
	player_hp = player_max_hp
	player_stamina = player_max_stamina
	# Headless systems and legacy regressions that instantiate an immediate run
	# retain the established recovery model. The actual setup screen explicitly
	# selects Stamina for normal play and exposes both rules in Combat Survey.
	if auto_start: start_run(loadout_id, mode_id, run_seed, "encounter", "recovery")

func build_laboratory() -> void:
	start_run(loadout_id, ModeRulesScript.CAMPAIGN_LAB, run_seed)

func build_expedition_room() -> void:
	start_run(loadout_id, ModeRulesScript.EXPEDITION, run_seed)

func start_run(chosen_loadout: String, chosen_mode: String, seed_override: int = -1, survey_profile_override: String = "encounter", combat_rules_override: String = "stamina") -> void:
	loadout_id = chosen_loadout if CombatCatalogScript.loadout_ids().has(chosen_loadout) else "warrior"
	mode_id = ModeRulesScript.normalize(chosen_mode)
	mode_config = ModeRulesScript.definition(mode_id)
	progression_mode = String(mode_config["upgrade_policy"])
	survey_profile = survey_profile_override if survey_profile_override in ["encounter", "attrition"] else "encounter"
	combat_rules = combat_rules_override if combat_rules_override in ["recovery", "stamina"] else "stamina"
	if seed_override >= 0: run_seed = seed_override
	else: run_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	_apply_loadout()
	player_hp = player_max_hp
	player_stamina = player_max_stamina
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_stamina_regen_delay = 0.0
	player_attack_readiness_remaining = 0.0
	_refresh_player_posture_capacity(true)
	player_facing = Vector2.UP
	player_action = _idle_action()
	dodge_cooldown = 0.0
	block_cooldown = 0.0
	endure_cooldown = 0.0
	skill_cooldown = 0.0
	rally_cooldown = 0.0
	advance_cooldown = 0.0
	main_ability_cooldown = 0.0
	subclass_ability_cooldown = 0.0
	weapon_sequence_cooldown = 0.0
	stealth_remaining = 0.0
	stealth_cooldown_pending = false
	assassination_window_remaining = 0.0
	turnabout_remaining = 0.0
	aimed_enemy_id = -1
	aimed_remaining = 0.0
	player_condition_buildup.clear()
	player_conditions.clear()
	bow_followup_ready = false
	bow_followup_consumed = false
	_condition_tick_accumulator = 0.0
	_next_combo_instance_id = 1
	rally_remaining = 0.0
	rally_end_after_action = false
	rally_break_extension_used = false
	building_force_chain = 0
	counterstep_remaining = 0.0
	strength_remaining = 0.0
	potions = healing_capacity()
	consumable_slots = _empty_consumable_slots()
	world_pickups.clear()
	pending_pickup.clear()
	trial_complete = false
	upgrade_pending = false
	upgrade_choices.clear()
	upgrades.clear()
	upgrade_ranks.clear()
	track_property_ranks.clear()
	track_ranks = _empty_character_track_ranks()
	track_choices.clear()
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
	_navigation_cache.clear()
	perfect_dodges = 0
	counter_hits = 0
	successful_blocks = 0
	successful_endures = 0
	damage_received_total = 0
	hits_received_total = 0
	potions_used_total = 0
	stamina_spent_total = 0.0
	stamina_depleted_total = 0.0
	stamina_overdraw_total = 0.0
	stamina_regenerated_total = 0.0
	stamina_regen_delay_time_total = 0.0
	stamina_regen_active_time_total = 0.0
	overexertion_count = 0
	winded_time_total = 0.0
	stamina_blocked_continuations = 0
	exhaustion_damage_received_total = 0
	exhaustion_move_time_total = 0.0
	exhaustion_wait_time_total = 0.0
	exhaustion_other_time_total = 0.0
	attack_readiness_blocked_attempts_total = 0
	attack_readiness_active_time_total = 0.0
	direct_attack_uses_total = 0
	dodge_style_uses_total.clear()
	dodge_vulnerable_time_total = 0.0
	dodge_recovery_damage_total = 0
	survey_room_number = 1 if mode_id == ModeRulesScript.COMBAT_SURVEY else 0
	survey_room_seed = 0
	survey_feedback_pending = false
	survey_run_ending = false
	survey_end_reason = ""
	survey_room_definition.clear()
	survey_room_entry.clear()
	survey_pending_record.clear()
	survey_last_report.clear()
	survey_action_counts.clear()
	survey_last_damage_source = ""
	survey_room_view_modes.assign([survey_current_view_mode])
	survey_view_switches = 0
	survey_empty_melee_contacts = 0
	survey_strike_diagnostics.clear()
	survey_session = {
		"format_version": SurveyReportScript.FORMAT_VERSION,
		"game_version": GAME_VERSION,
		"generator_version": SURVEY_GENERATOR_VERSION,
		"presentation_version": PRESENTATION_VERSION,
		"run_seed": run_seed,
		"profile": survey_profile,
		"combat_rules": combat_rules,
		"loadout": CombatCatalogScript.loadout_name(loadout_id),
		"started_at": Time.get_datetime_string_from_system(false, true),
		"ended_at": "",
		"end_reason": "",
		"rooms": [],
	} if mode_id == ModeRulesScript.COMBAT_SURVEY else {}
	effects.clear()
	hazards.clear()
	projectiles.clear()
	death_pending = false
	run_failed = false
	anchor_state.clear()
	shortcut_unlocked = false
	_boss_defeated = false
	rng.seed = run_seed
	var layout: Dictionary = _generate_survey_layout(survey_room_number) if mode_id == ModeRulesScript.COMBAT_SURVEY else FloorGeneratorScript.generate(run_seed, bool(mode_config["waystone_available"]))
	world_size = Vector2(layout.get("world_size", WORLD_SIZE))
	geometry_style = String(layout.get("geometry_style", "rooms"))
	areas.assign(Array(layout["areas"]).duplicate(true))
	connections.assign(Array(layout["connections"]).duplicate(true))
	route_recipe.assign(Array(layout.get("route_recipe", [])).duplicate(true))
	run_graph = Dictionary(layout.get("run_graph", {})).duplicate(true)
	locale_catalog = Dictionary(layout.get("locale_catalog", {})).duplicate(true)
	floor_shapes.assign(Array(layout.get("floor_shapes", [])).duplicate(true))
	terrain_features.assign(Array(layout.get("terrain_features", [])).duplicate(true))
	world_pickups.assign(Array(layout.get("pickups", [])).duplicate(true))
	waystones.assign(Array(layout.get("waystones", [])).duplicate(true))
	shortcuts.assign(Array(layout.get("shortcuts", [])).duplicate(true))
	transitions.assign(Array(layout.get("transitions", [])).duplicate(true))
	secret_passages.assign(Array(layout.get("secret_passages", [])).duplicate(true))
	world_layers = Dictionary(layout.get("layers", {})).duplicate(true)
	encounter_templates = Dictionary(layout["encounters"]).duplicate(true)
	base_walls_by_layer = Dictionary(layout.get("layer_walls", {})).duplicate(true)
	bonfire_pos = Vector2(layout["bonfire_pos"])
	active_waystone_id = String(waystones[0]["id"]) if not waystones.is_empty() else ""
	current_layer = String(waystones[0]["layer"]) if not waystones.is_empty() else "survey_arena" if mode_id == ModeRulesScript.COMBAT_SURVEY else "expedition_surface"
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
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		_capture_survey_room_entry()
		SurveyReportScript.save_current(survey_session)
		message = "Combat Survey room 1. %s" % _combat_rules_intro()
	elif bool(mode_config["waystone_available"]):
		_capture_anchor_history()
		message = "The Waystone anchors this moment. %s" % _combat_rules_intro()
	else:
		message = "The expedition begins. %s" % _combat_rules_intro()
	last_timeline.clear()
	changed.emit()
	message_changed.emit(message)

func _generate_survey_layout(room_number: int) -> Dictionary:
	survey_room_seed = _survey_seed_for_room(room_number)
	var room_rng := RandomNumberGenerator.new()
	room_rng.seed = survey_room_seed
	var pacing_phase := _survey_pacing_phase(room_number)
	var threat_band := _survey_threat_band(pacing_phase, room_rng)
	var composition := _survey_composition(room_rng, room_number, threat_band, pacing_phase)
	var arena_ids := ["open_ring", "central_cover", "broken_sightline", "split_approach", "scattered_cover", "wide_lane"]
	var arena_id := String(arena_ids[room_rng.randi_range(0, arena_ids.size() - 1)])
	var formation_options: Array = composition.get("formations", ["spread"])
	var formation_id := String(formation_options[room_rng.randi_range(0, formation_options.size() - 1)])
	var enemy_plan: Array = composition.get("enemies", [])
	var layer := "survey_arena"
	var center := Vector2(850.0, 700.0)
	var player_start := Vector2(850.0, 1080.0)
	var walls_for_layer: Array[Rect2] = []
	var features: Array[Dictionary] = []
	var obstacle_rects: Array[Rect2] = []
	match arena_id:
		"central_cover": obstacle_rects = [Rect2(735, 555, 230, 150)]
		"broken_sightline": obstacle_rects = [Rect2(505, 485, 105, 250), Rect2(1090, 485, 105, 250)]
		"split_approach": obstacle_rects = [Rect2(680, 430, 95, 305), Rect2(925, 430, 95, 305)]
		"scattered_cover": obstacle_rects = [Rect2(500, 560, 110, 95), Rect2(1050, 430, 110, 95), Rect2(955, 805, 115, 90)]
		"wide_lane": obstacle_rects = [Rect2(365, 430, 90, 420), Rect2(1245, 430, 90, 420)]
		_: obstacle_rects = []
	for obstacle in obstacle_rects:
		walls_for_layer.append(obstacle)
		features.append({"kind": "ancient_ruin", "pos": obstacle.get_center(), "radius": maxf(obstacle.size.x, obstacle.size.y) * 0.48, "part_id": 0, "layer": layer})
	var spawn_slots := _survey_formation_slots(formation_id)
	var available_spawn_slots := spawn_slots.duplicate()
	var templates: Array[Dictionary] = []
	var enemy_labels: Array[String] = []
	var enemy_roles: Array[String] = []
	for index in range(enemy_plan.size()):
		var planned_enemy := Dictionary(enemy_plan[index])
		var kind := String(planned_enemy["kind"])
		var role := String(planned_enemy.get("role", "frontline"))
		var slot := _survey_take_spawn_slot(available_spawn_slots, role, player_start)
		var jitter := Vector2(room_rng.randf_range(-34.0, 34.0), room_rng.randf_range(-28.0, 28.0))
		var spawn_position: Vector2 = slot + jitter
		for obstacle in obstacle_rects:
			if obstacle.grow(70.0).has_point(spawn_position):
				var away := (spawn_position - obstacle.get_center()).normalized()
				if away.is_zero_approx(): away = Vector2.UP
				spawn_position = obstacle.get_center() + away * (maxf(obstacle.size.x, obstacle.size.y) * 0.72 + 90.0)
		# Survey rooms must permit an opening stealth decision. Keep every body out
		# of immediate-contact range and face it into the arena rather than directly
		# at the player; the first player noise or crossed sightline still alerts it.
		var from_player := spawn_position - player_start
		if from_player.length() < 360.0:
			var safe_direction := from_player.normalized() if from_player.length_squared() > 0.001 else Vector2.UP
			spawn_position = player_start + safe_direction * 360.0
		var initial_facing := (spawn_position - player_start).normalized()
		templates.append({"kind": kind, "role": role, "pos": spawn_position, "facing": initial_facing, "layer": layer})
		enemy_labels.append(kind.replace("_", " ").capitalize())
		enemy_roles.append("%s: %s" % [kind.replace("_", " ").capitalize(), role.replace("_", " ")])
	var threat_tier := 1 + int(floor(float(room_number - 1) * 0.5))
	survey_room_definition = {
		"room_number": room_number,
		"room_seed": survey_room_seed,
		"arena": arena_id,
		"formation": formation_id,
		"threat_tier": threat_tier,
		"threat_band": threat_band,
		"pacing_phase": pacing_phase,
		"recipe_id": String(composition.get("id", "unknown")),
		"recipe_label": String(composition.get("label", "Unknown")),
		"recipe_family": String(composition.get("family", "unknown")),
		"composition_cost": int(composition.get("cost", 0)),
		"ranged_pressure_count": int(composition.get("ranged_pressure_count", 0)),
		"enemy_labels": enemy_labels,
		"enemy_roles": enemy_roles,
	}

	var layers := {layer: {"name": "Combat Survey", "depth": 0}}
	var layer_walls := {layer: walls_for_layer}
	return {
		"world_size": Vector2(1700.0, 1400.0),
		"geometry_style": "arena",
		"areas": [{"id": 0, "name": "Survey Arena %d" % room_number, "arrival_text": "%s · %s" % [arena_id.replace("_", " ").capitalize(), formation_id.replace("_", " ").capitalize()], "kind": "survey", "rect": Rect2(175, 75, 1350, 1250), "center": center, "layer": layer, "discovered": true}],
		"connections": [],
		"route_recipe": [],
		"run_graph": {"nodes": [0], "edges": []},
		"locale_catalog": {},
		"floor_shapes": [{"kind": "circle", "center": center, "radius": 650.0, "part_id": 0, "layer": layer}],
		"terrain_features": features,
		"pickups": [],
		"waystones": [],
		"shortcuts": [],
		"transitions": [],
		"secret_passages": [],
		"layers": layers,
		"encounters": {0: templates},
		"layer_walls": layer_walls,
		"base_walls": walls_for_layer,
		"bonfire_pos": Vector2.ZERO,
		"player_start": player_start,
		"shortcut_gate": Rect2(),
		"shortcut_unlock_pos": Vector2.ZERO,
		"shortcut_start_pos": Vector2.ZERO,
	}

func _survey_take_spawn_slot(available: Array, role: String, player_start: Vector2) -> Vector2:
	if available.is_empty(): return player_start + Vector2.UP * 420.0
	var chosen_index := 0
	var chosen_score := -INF
	for index in range(available.size()):
		var slot := Vector2(available[index])
		var distance := slot.distance_to(player_start)
		var lateral := absf(slot.x - player_start.x)
		var score := -absf(distance - 410.0)
		match role:
			"ranged_pressure", "area_denial": score = distance - lateral * 0.08
			"flanker": score = lateral * 1.25 + distance * 0.18
			"anchor": score = -absf(distance - 480.0) - lateral * 0.12
			_: score = -absf(distance - 390.0) - lateral * 0.05
		if score > chosen_score:
			chosen_score = score
			chosen_index = index
	var chosen := Vector2(available[chosen_index])
	available.remove_at(chosen_index)
	return chosen

func _survey_seed_for_room(room_number: int) -> int:
	return absi(hash("waystone-survey:%d:%d:%d" % [SURVEY_GENERATOR_VERSION, run_seed, room_number]))

func _survey_pacing_phase(room_number: int) -> String:
	var phases := ["opening", "development", "contrast", "pressure", "climax", "respite"]
	return String(phases[posmod(room_number - 1, phases.size())])

func _survey_threat_band(pacing_phase: String, room_rng: RandomNumberGenerator) -> String:
	match pacing_phase:
		"contrast": return "unusual"
		"pressure": return "stress" if room_rng.randf() < 0.24 else "unusual"
		"climax": return "stress"
		"development": return "unusual" if room_rng.randf() < 0.18 else "conventional"
		_: return "conventional"

func _survey_recipe_catalog() -> Array[Dictionary]:
	return [
		{"id": "opening_pursuit", "label": "Opening Pursuit", "family": "pursuit", "min_tier": 1, "phases": ["opening", "respite"], "formations": ["frontline", "spread"], "enemies": [{"kind": "boar", "role": "frontline"}, {"kind": "hound", "role": "flanker"}], "reinforcements": [{"kind": "knife", "role": "flanker"}, {"kind": "boar", "role": "frontline"}]},
		{"id": "mixed_skirmish", "label": "Mixed Skirmish", "family": "skirmish", "min_tier": 1, "phases": ["development", "contrast", "respite"], "formations": ["spread", "flanked", "split"], "enemies": [{"kind": "boar", "role": "frontline"}, {"kind": "hound", "role": "flanker"}, {"kind": "knife", "role": "flanker"}], "reinforcements": [{"kind": "bandit", "role": "flanker"}, {"kind": "blade", "role": "frontline"}]},
		{"id": "melee_cross", "label": "Melee Cross", "family": "melee_pressure", "min_tier": 2, "phases": ["opening", "contrast", "pressure", "respite"], "formations": ["flanked", "surround", "split"], "enemies": [{"kind": "bandit", "role": "flanker"}, {"kind": "knife", "role": "flanker"}, {"kind": "hound", "role": "flanker"}], "reinforcements": [{"kind": "blade", "role": "frontline"}, {"kind": "boar", "role": "frontline"}]},
		{"id": "screened_archer", "label": "Screened Archer", "family": "screened_ranged", "min_tier": 2, "phases": ["development", "pressure", "climax"], "formations": ["ranged_support", "split"], "enemies": [{"kind": "archer", "role": "ranged_pressure"}, {"kind": "blade", "role": "frontline"}, {"kind": "hound", "role": "flanker"}], "reinforcements": [{"kind": "bandit", "role": "flanker"}, {"kind": "boar", "role": "frontline"}]},
		{"id": "melee_press", "label": "Melee Press", "family": "melee_pressure", "min_tier": 3, "phases": ["development", "contrast", "climax", "respite"], "formations": ["surround", "flanked", "frontline"], "enemies": [{"kind": "blade", "role": "frontline"}, {"kind": "bandit", "role": "flanker"}, {"kind": "knife", "role": "flanker"}, {"kind": "hound", "role": "flanker"}], "reinforcements": [{"kind": "boar", "role": "frontline"}, {"kind": "blade", "role": "frontline"}]},
		{"id": "crossfire_chase", "label": "Crossfire Chase", "family": "crossfire", "min_tier": 4, "phases": ["pressure", "climax"], "formations": ["ranged_support", "split"], "enemies": [{"kind": "archer", "role": "ranged_pressure"}, {"kind": "archer", "role": "ranged_pressure"}, {"kind": "boar", "role": "frontline"}, {"kind": "hound", "role": "flanker"}], "reinforcements": [{"kind": "bandit", "role": "flanker"}, {"kind": "blade", "role": "frontline"}]},
		{"id": "ice_displacement", "label": "Ice Displacement", "family": "area_denial", "min_tier": 5, "phases": ["contrast", "pressure", "climax"], "formations": ["ranged_support", "split"], "enemies": [{"kind": "ice_caster", "role": "area_denial"}, {"kind": "blade", "role": "frontline"}, {"kind": "hound", "role": "flanker"}, {"kind": "knife", "role": "flanker"}], "reinforcements": [{"kind": "boar", "role": "frontline"}, {"kind": "bandit", "role": "flanker"}]},
		{"id": "fire_pursuit", "label": "Fire Pursuit", "family": "area_denial", "min_tier": 5, "phases": ["development", "pressure", "climax"], "formations": ["ranged_support", "flanked"], "enemies": [{"kind": "fire_caster", "role": "area_denial"}, {"kind": "boar", "role": "frontline"}, {"kind": "bandit", "role": "flanker"}], "reinforcements": [{"kind": "blade", "role": "frontline"}, {"kind": "hound", "role": "flanker"}]},
		{"id": "dual_elements", "label": "Dual Elements", "family": "caster_pair", "min_tier": 5, "phases": ["climax"], "formations": ["ranged_support", "split"], "enemies": [{"kind": "ice_caster", "role": "area_denial"}, {"kind": "fire_caster", "role": "area_denial"}, {"kind": "blade", "role": "frontline"}, {"kind": "hound", "role": "flanker"}], "reinforcements": [{"kind": "bandit", "role": "flanker"}, {"kind": "boar", "role": "frontline"}]},
		{"id": "polearm_screen", "label": "Polearm Screen", "family": "anchor", "min_tier": 6, "phases": ["opening", "development", "contrast", "respite"], "formations": ["frontline", "split"], "enemies": [{"kind": "polearm", "role": "anchor"}, {"kind": "archer", "role": "ranged_pressure"}, {"kind": "bandit", "role": "flanker"}], "reinforcements": [{"kind": "blade", "role": "frontline"}, {"kind": "hound", "role": "flanker"}]},
		{"id": "brute_support", "label": "Brute Support", "family": "heavy_anchor", "min_tier": 7, "phases": ["contrast", "pressure", "climax"], "formations": ["ranged_support", "frontline"], "enemies": [{"kind": "brute", "role": "anchor"}, {"kind": "archer", "role": "ranged_pressure"}, {"kind": "knife", "role": "flanker"}], "reinforcements": [{"kind": "bandit", "role": "flanker"}, {"kind": "blade", "role": "frontline"}]},
		{"id": "captain_cross", "label": "Captain Cross", "family": "command", "min_tier": 7, "phases": ["development", "pressure", "climax"], "formations": ["flanked", "ranged_support"], "enemies": [{"kind": "captain", "role": "anchor"}, {"kind": "archer", "role": "ranged_pressure"}, {"kind": "hound", "role": "flanker"}, {"kind": "blade", "role": "frontline"}], "reinforcements": [{"kind": "bandit", "role": "flanker"}, {"kind": "knife", "role": "flanker"}]},
		{"id": "knight_command", "label": "Knight Command", "family": "heavy_anchor", "min_tier": 9, "phases": ["pressure", "climax"], "formations": ["ranged_support", "frontline"], "enemies": [{"kind": "knight", "role": "anchor"}, {"kind": "archer", "role": "ranged_pressure"}, {"kind": "ice_caster", "role": "area_denial"}, {"kind": "bandit", "role": "flanker"}], "reinforcements": [{"kind": "blade", "role": "frontline"}, {"kind": "hound", "role": "flanker"}]},
	]

func _survey_composition(room_rng: RandomNumberGenerator, room_number: int, threat_band: String, pacing_phase: String) -> Dictionary:
	var tier := 1 + int(floor(float(room_number - 1) * 0.5))
	var candidates: Array[Dictionary] = []
	for recipe_value in _survey_recipe_catalog():
		var recipe := Dictionary(recipe_value)
		if tier >= int(recipe["min_tier"]) and Array(recipe["phases"]).has(pacing_phase): candidates.append(recipe)
	if candidates.is_empty(): candidates.append(Dictionary(_survey_recipe_catalog()[0]))
	var recent_ids: Array[String] = []
	var recent_family := ""
	var completed_rooms: Array = survey_session.get("rooms", [])
	for index in range(maxi(0, completed_rooms.size() - 2), completed_rooms.size()):
		recent_ids.append(String(Dictionary(completed_rooms[index]).get("recipe_id", "")))
	if not completed_rooms.is_empty(): recent_family = String(Dictionary(completed_rooms[-1]).get("recipe_family", ""))
	var unused: Array[Dictionary] = candidates.filter(func(recipe: Dictionary) -> bool: return not recent_ids.has(String(recipe["id"])))
	if not unused.is_empty(): candidates = unused
	var different_family: Array[Dictionary] = candidates.filter(func(recipe: Dictionary) -> bool: return String(recipe["family"]) != recent_family)
	if not different_family.is_empty(): candidates = different_family
	var chosen := Dictionary(candidates[room_rng.randi_range(0, candidates.size() - 1)]).duplicate(true)
	var enemies: Array[Dictionary] = []
	for enemy_value in Array(chosen["enemies"]): enemies.append(Dictionary(enemy_value).duplicate())
	var target_budget := mini(18, 2 + tier + (2 if threat_band == "stress" else 1 if threat_band == "unusual" else 0))
	if pacing_phase == "respite": target_budget = maxi(3, target_budget - 2)
	var cost := _survey_composition_cost(enemies)
	var reinforcements: Array = chosen.get("reinforcements", [])
	var attempts := 0
	while cost < target_budget and enemies.size() < 6 and not reinforcements.is_empty() and attempts < 18:
		attempts += 1
		var option := Dictionary(reinforcements[room_rng.randi_range(0, reinforcements.size() - 1)])
		var kind := String(option["kind"])
		var option_cost := _survey_enemy_cost(kind)
		if cost + option_cost > target_budget: continue
		if _survey_plan_kind_count(enemies, kind) >= 2: continue
		if _survey_is_ranged_pressure(option) and _survey_ranged_pressure_count(enemies) >= 2: continue
		enemies.append(option.duplicate())
		cost += option_cost
	chosen["enemies"] = enemies
	chosen["cost"] = cost
	chosen["ranged_pressure_count"] = _survey_ranged_pressure_count(enemies)
	return chosen

func _survey_enemy_cost(kind: String) -> int:
	return int({"boar": 1, "hound": 1, "knife": 1, "bandit": 2, "blade": 2, "archer": 2, "ice_caster": 3, "fire_caster": 3, "polearm": 3, "brute": 4, "captain": 4, "knight": 5}.get(kind, 2))

func _survey_composition_cost(enemies_plan: Array[Dictionary]) -> int:
	var result := 0
	for planned_enemy in enemies_plan: result += _survey_enemy_cost(String(planned_enemy["kind"]))
	return result

func _survey_is_ranged_pressure(planned_enemy: Dictionary) -> bool:
	return String(planned_enemy.get("role", "")) in ["ranged_pressure", "area_denial"]

func _survey_plan_kind_count(enemies_plan: Array[Dictionary], kind: String) -> int:
	var result := 0
	for planned_enemy in enemies_plan:
		if String(planned_enemy.get("kind", "")) == kind: result += 1
	return result

func _survey_ranged_pressure_count(enemies_plan: Array[Dictionary]) -> int:
	var result := 0
	for planned_enemy in enemies_plan:
		if _survey_is_ranged_pressure(planned_enemy): result += 1
	return result

func _survey_formation_slots(formation_id: String) -> Array[Vector2]:
	match formation_id:
		"spread": return [Vector2(470, 410), Vector2(850, 330), Vector2(1230, 410), Vector2(560, 650), Vector2(1140, 650), Vector2(850, 560)]
		"flanked": return [Vector2(420, 720), Vector2(1280, 720), Vector2(650, 360), Vector2(1050, 360), Vector2(540, 470), Vector2(1160, 470)]
		"ranged_support": return [Vector2(700, 610), Vector2(1000, 610), Vector2(570, 340), Vector2(850, 280), Vector2(1130, 340), Vector2(850, 490)]
		"surround": return [Vector2(510, 690), Vector2(1190, 690), Vector2(670, 380), Vector2(1030, 380), Vector2(560, 930), Vector2(1140, 930)]
		"split": return [Vector2(520, 420), Vector2(630, 570), Vector2(1180, 420), Vector2(1070, 570), Vector2(480, 750), Vector2(1220, 750)]
		_: return [Vector2(610, 460), Vector2(770, 390), Vector2(930, 390), Vector2(1090, 460), Vector2(690, 610), Vector2(1010, 610)]

func _capture_survey_room_entry() -> void:
	survey_room_view_modes.assign([survey_current_view_mode])
	survey_room_entry = {
		"time": simulation_time,
		"hp": player_hp,
		"max_hp": player_max_hp,
		"stamina": player_stamina,
		"max_stamina": player_max_stamina,
		"potions": potions,
		"damage_dealt": damage_dealt,
		"damage_received": damage_received_total,
		"hits_received": hits_received_total,
		"potions_used": potions_used_total,
		"perfect_dodges": perfect_dodges,
		"successful_blocks": successful_blocks,
		"successful_endures": successful_endures,
		"action_counts": survey_action_counts.duplicate(true),
		"view_switches": survey_view_switches,
		"empty_melee_contacts": survey_empty_melee_contacts,
		"stamina_spent": stamina_spent_total,
		"stamina_depleted": stamina_depleted_total,
		"stamina_overdraw": stamina_overdraw_total,
		"stamina_regenerated": stamina_regenerated_total,
		"stamina_regen_delay_time": stamina_regen_delay_time_total,
		"stamina_regen_active_time": stamina_regen_active_time_total,
		"overexertions": overexertion_count,
		"winded_time": winded_time_total,
		"stamina_blocked_continuations": stamina_blocked_continuations,
		"exhaustion_damage_received": exhaustion_damage_received_total,
		"exhaustion_move_time": exhaustion_move_time_total,
		"exhaustion_wait_time": exhaustion_wait_time_total,
		"exhaustion_other_time": exhaustion_other_time_total,
		"attack_readiness_blocked_attempts": attack_readiness_blocked_attempts_total,
		"attack_readiness_active_time": attack_readiness_active_time_total,
		"direct_attack_uses": direct_attack_uses_total,
		"dodge_style_uses": dodge_style_uses_total.duplicate(true),
		"dodge_vulnerable_time": dodge_vulnerable_time_total,
		"dodge_recovery_damage": dodge_recovery_damage_total,
		"strike_diagnostic_count": survey_strike_diagnostics.size(),
	}
	survey_last_damage_source = ""

func record_survey_view_mode(mode: String, switched: bool) -> void:
	if mode not in ["isometric", "top_down"]: return
	var changed_mode := mode != survey_current_view_mode
	survey_current_view_mode = mode
	if mode_id != ModeRulesScript.COMBAT_SURVEY: return
	if not survey_room_view_modes.has(mode): survey_room_view_modes.append(mode)
	if switched and changed_mode: survey_view_switches += 1

func _survey_action_count_delta() -> Dictionary:
	var before := Dictionary(survey_room_entry.get("action_counts", {}))
	var result: Dictionary = {}
	for action_id in survey_action_counts:
		var count := int(survey_action_counts[action_id]) - int(before.get(action_id, 0))
		if count > 0: result[action_id] = count
	return result

func _survey_dodge_style_delta() -> Dictionary:
	var before := Dictionary(survey_room_entry.get("dodge_style_uses", {}))
	var result: Dictionary = {}
	for style_id in dodge_style_uses_total:
		var count := int(dodge_style_uses_total[style_id]) - int(before.get(style_id, 0))
		if count > 0: result[style_id] = count
	return result

func _survey_build_summary() -> String:
	var ranks: Array[String] = []
	for track_id in track_ranks:
		var rank := int(track_ranks[track_id])
		if rank <= 0: continue
		var selected: Array[String] = []
		var definition := CombatCatalogScript.character_track(String(track_id))
		for stage_index in range(mini(rank, Array(definition.get("stages", [])).size())):
			var stage := CombatCatalogScript.character_stage(String(track_id), stage_index)
			var stage_id := String(stage.get("id", ""))
			var choice_id := String(track_choices.get(stage_id, ""))
			if choice_id.is_empty(): continue
			for option_value in Array(stage.get("choices", [])):
				var option := Dictionary(option_value)
				if String(option.get("id", "")) == choice_id:
					selected.append(String(option.get("label", choice_id)))
					break
		var choice_suffix := " (%s)" % ", ".join(selected) if not selected.is_empty() else ""
		ranks.append("%s %d%s" % [String(track_id).replace("_", " ").capitalize(), rank, choice_suffix])
	return "%s; %s; %s" % [CombatCatalogScript.loadout_name(loadout_id), CombatCatalogScript.weapon_frame(player_weapon_frame).get("label", player_weapon_frame), ", ".join(ranks) if not ranks.is_empty() else "base tracks"]

func _complete_survey_room(outcome: String) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY or survey_feedback_pending or trial_complete: return
	_survey_finalize_strike_probe("room_ended")
	survey_pending_record = survey_room_definition.duplicate(true)
	survey_pending_record.merge({
		"outcome": outcome,
		"build_summary": _survey_build_summary(),
		"entry_hp": int(survey_room_entry.get("hp", player_hp)),
		"entry_max_hp": int(survey_room_entry.get("max_hp", player_max_hp)),
		"exit_hp": player_hp,
		"entry_stamina": float(survey_room_entry.get("stamina", player_stamina)),
		"entry_max_stamina": float(survey_room_entry.get("max_stamina", player_max_stamina)),
		"exit_stamina": player_stamina,
		"exit_max_stamina": player_max_stamina,
		"entry_potions": int(survey_room_entry.get("potions", potions)),
		"exit_potions": potions,
		"death_source": survey_last_damage_source if outcome == "death" else "",
		"action_usage": _survey_action_count_delta(),
		"view_modes": survey_room_view_modes.duplicate(),
		"view_switches": survey_view_switches - int(survey_room_entry.get("view_switches", survey_view_switches)),
		"empty_melee_contacts": survey_empty_melee_contacts - int(survey_room_entry.get("empty_melee_contacts", survey_empty_melee_contacts)),
		"combat_time": simulation_time - float(survey_room_entry.get("time", simulation_time)),
		"damage_dealt": damage_dealt - int(survey_room_entry.get("damage_dealt", damage_dealt)),
		"damage_received": damage_received_total - int(survey_room_entry.get("damage_received", damage_received_total)),
		"hits_received": hits_received_total - int(survey_room_entry.get("hits_received", hits_received_total)),
		"potions_used": potions_used_total - int(survey_room_entry.get("potions_used", potions_used_total)),
		"perfect_dodges": perfect_dodges - int(survey_room_entry.get("perfect_dodges", perfect_dodges)),
		"successful_blocks": successful_blocks - int(survey_room_entry.get("successful_blocks", successful_blocks)),
		"successful_endures": successful_endures - int(survey_room_entry.get("successful_endures", successful_endures)),
		"stamina_spent": stamina_spent_total - float(survey_room_entry.get("stamina_spent", stamina_spent_total)),
		"stamina_depleted": stamina_depleted_total - float(survey_room_entry.get("stamina_depleted", stamina_depleted_total)),
		"stamina_overdraw": stamina_overdraw_total - float(survey_room_entry.get("stamina_overdraw", stamina_overdraw_total)),
		"stamina_regenerated": stamina_regenerated_total - float(survey_room_entry.get("stamina_regenerated", stamina_regenerated_total)),
		"stamina_regen_delay_time": stamina_regen_delay_time_total - float(survey_room_entry.get("stamina_regen_delay_time", stamina_regen_delay_time_total)),
		"stamina_regen_active_time": stamina_regen_active_time_total - float(survey_room_entry.get("stamina_regen_active_time", stamina_regen_active_time_total)),
		"overexertions": overexertion_count - int(survey_room_entry.get("overexertions", overexertion_count)),
		"winded_time": winded_time_total - float(survey_room_entry.get("winded_time", winded_time_total)),
		"stamina_blocked_continuations": stamina_blocked_continuations - int(survey_room_entry.get("stamina_blocked_continuations", stamina_blocked_continuations)),
		"exhaustion_damage_received": exhaustion_damage_received_total - int(survey_room_entry.get("exhaustion_damage_received", exhaustion_damage_received_total)),
		"exhaustion_move_time": exhaustion_move_time_total - float(survey_room_entry.get("exhaustion_move_time", exhaustion_move_time_total)),
		"exhaustion_wait_time": exhaustion_wait_time_total - float(survey_room_entry.get("exhaustion_wait_time", exhaustion_wait_time_total)),
		"exhaustion_other_time": exhaustion_other_time_total - float(survey_room_entry.get("exhaustion_other_time", exhaustion_other_time_total)),
		"attack_readiness_blocked_attempts": attack_readiness_blocked_attempts_total - int(survey_room_entry.get("attack_readiness_blocked_attempts", attack_readiness_blocked_attempts_total)),
		"attack_readiness_active_time": attack_readiness_active_time_total - float(survey_room_entry.get("attack_readiness_active_time", attack_readiness_active_time_total)),
		"direct_attack_uses": direct_attack_uses_total - int(survey_room_entry.get("direct_attack_uses", direct_attack_uses_total)),
		"dodge_style_uses": _survey_dodge_style_delta(),
		"dodge_vulnerable_time": dodge_vulnerable_time_total - float(survey_room_entry.get("dodge_vulnerable_time", dodge_vulnerable_time_total)),
		"dodge_recovery_damage": dodge_recovery_damage_total - int(survey_room_entry.get("dodge_recovery_damage", dodge_recovery_damage_total)),
		"strike_diagnostics": survey_strike_diagnostics.slice(int(survey_room_entry.get("strike_diagnostic_count", 0))).duplicate(true),
		"ratings": {}, "tags": [], "notes": "", "subjective_skipped": false,
	}, true)
	survey_feedback_pending = true
	survey_run_ending = outcome in ["death", "manual_end"]
	survey_end_reason = outcome
	player_action = _idle_action()
	projectiles.clear()
	hazards.clear()
	_set_message("Room %d complete. Record how the encounter felt." % survey_room_number)
	changed.emit()

func submit_survey_feedback(ratings: Dictionary, tags: Array, notes: String) -> void:
	if not survey_feedback_pending: return
	survey_pending_record["ratings"] = ratings.duplicate(true)
	survey_pending_record["tags"] = tags.duplicate()
	survey_pending_record["notes"] = notes.strip_edges()
	survey_pending_record["subjective_skipped"] = false
	_store_survey_feedback()

func skip_survey_feedback(notes: String = "") -> void:
	if not survey_feedback_pending: return
	survey_pending_record["ratings"] = {}
	survey_pending_record["tags"] = []
	survey_pending_record["notes"] = notes.strip_edges()
	survey_pending_record["subjective_skipped"] = true
	_store_survey_feedback()

func _store_survey_feedback() -> void:
	var rooms: Array = survey_session.get("rooms", [])
	rooms.append(survey_pending_record.duplicate(true))
	survey_session["rooms"] = rooms
	survey_feedback_pending = false
	survey_pending_record.clear()
	SurveyReportScript.save_current(survey_session)
	if survey_run_ending:
		_finalize_survey_run(survey_end_reason)
	else:
		rooms_cleared += 1
		_load_next_survey_room()

func end_survey_run() -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY or trial_complete or survey_feedback_pending: return
	_complete_survey_room("manual_end")

func _finalize_survey_run(reason: String) -> void:
	survey_session["ended_at"] = Time.get_datetime_string_from_system(false, true)
	survey_session["end_reason"] = reason
	survey_last_report = SurveyReportScript.archive_session(survey_session)
	trial_complete = true
	survey_run_ending = true
	_set_message("Combat Survey saved: %d rooms recorded." % Array(survey_session.get("rooms", [])).size())
	changed.emit()

func _load_next_survey_room() -> void:
	survey_room_number += 1
	if survey_profile == "encounter":
		player_hp = player_max_hp
		player_posture = player_posture_max
		potions = healing_capacity()
		dodge_cooldown = 0.0
		block_cooldown = 0.0
		endure_cooldown = 0.0
		skill_cooldown = 0.0
		rally_cooldown = 0.0
		advance_cooldown = 0.0
		main_ability_cooldown = 0.0
		subclass_ability_cooldown = 0.0
		weapon_sequence_cooldown = 0.0
		player_conditions.clear()
		player_condition_buildup.clear()
	player_stamina = player_max_stamina
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_stamina_regen_delay = 0.0
	player_attack_readiness_remaining = 0.0
	survey_strike_diagnostics.clear()
	var layout := _generate_survey_layout(survey_room_number)
	world_size = Vector2(layout["world_size"])
	geometry_style = String(layout["geometry_style"])
	areas.assign(Array(layout["areas"]).duplicate(true))
	connections.assign(Array(layout["connections"]).duplicate(true))
	route_recipe.assign(Array(layout["route_recipe"]).duplicate(true))
	run_graph = Dictionary(layout["run_graph"]).duplicate(true)
	locale_catalog = Dictionary(layout["locale_catalog"]).duplicate(true)
	floor_shapes.assign(Array(layout["floor_shapes"]).duplicate(true))
	terrain_features.assign(Array(layout["terrain_features"]).duplicate(true))
	world_pickups.clear()
	waystones.clear()
	shortcuts.clear()
	transitions.clear()
	secret_passages.clear()
	world_layers = Dictionary(layout["layers"]).duplicate(true)
	encounter_templates = Dictionary(layout["encounters"]).duplicate(true)
	base_walls_by_layer = Dictionary(layout["layer_walls"]).duplicate(true)
	current_layer = "survey_arena"
	_player_start = Vector2(layout["player_start"])
	player_pos = _player_start
	player_facing = Vector2.UP
	player_action = _idle_action()
	projectiles.clear()
	hazards.clear()
	effects.clear()
	_navigation_cache.clear()
	discovered_cells.clear()
	discovered_cells_by_layer.clear()
	discovered_cells_by_layer[current_layer] = discovered_cells
	visible_cells.clear()
	discovery_revision += 1
	discovery_epoch += 1
	world_render_revision += 1
	_build_shape_spatial_index()
	current_area_id = 0
	_respawn_enemies()
	_apply_shortcut_world_state()
	rng.seed = survey_room_seed ^ 0x51A7E
	_update_exploration(true)
	_capture_survey_room_entry()
	SurveyReportScript.save_current(survey_session)
	_set_message("Combat Survey room %d. Seed %d." % [survey_room_number, survey_room_seed])
	last_timeline.clear()
	changed.emit()

func survey_report_text() -> String:
	return SurveyReportScript.build_text(survey_last_report if not survey_last_report.is_empty() else survey_session)

func survey_report_filename() -> String:
	return SurveyReportScript.report_filename(survey_last_report if not survey_last_report.is_empty() else survey_session)

func survey_archive() -> Dictionary:
	return SurveyReportScript.load_archive()

func survey_all_reports_text() -> String:
	return SurveyReportScript.all_reports_text()

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
	return {"boar": 35, "bandit": 25, "knife": 20, "blade": 35, "hound": 30, "archer": 25, "shield": 50, "polearm": 60, "hexer": 35, "ice_caster": 40, "fire_caster": 40, "brute": 80, "knight": 140, "captain": 60, "warden": 130, "werewolf": 210}.get(kind, 35)

func _make_enemy(kind: String, position: Vector2, hp: int, area_id: int = 0) -> Dictionary:
	var combat_profile := CombatCatalogScript.archetype(kind)
	var attributes := Dictionary(combat_profile["attributes"]).duplicate(true)
	attributes["health"] = hp
	var posture_max := _enemy_posture_base(kind) + float(attributes.get("resolve", 5))
	var enemy := {
		"id": _next_enemy_id,
		"kind": kind,
		"pos": position,
		"spawn_pos": position,
		"area_id": area_id,
		"facing": Vector2.DOWN,
		"hp": hp,
		"max_hp": hp,
		"radius": 62.0 if kind == "werewolf" else 52.0 if kind == "warden" else 49.0 if kind == "knight" else 46.0 if kind == "brute" else 42.0 if kind == "polearm" else 31.0 if kind == "boar" else 25.0 if kind == "hound" else 23.0 if kind == "bandit" else 22.0 if kind == "knife" else ENEMY_RADIUS,
		"posture": posture_max,
		"posture_max": posture_max,
		"posture_recovery_delay": 0.0,
		"is_moving": false,
		"last_motion": Vector2.ZERO,
		"stalled_time": 0.0,
		"action": _idle_action(),
		"awareness": "idle",
		"revealed_to_player": kind != "bandit",
		"revealed_elapsed": 0.0,
		"player_los": false,
		"los_refresh_remaining": 0.0,
		"alert_remaining": 0.0,
		"suspicious_remaining": 0.0,
		"last_known_player": position,
		"heard_sound_sequence": 0,
		"pounce_cooldown": 0.0,
		"dodge_cooldown": 0.0,
		"neutral_cooldown": 0.0,
		"shot_cooldown": 0.22 * float(_next_enemy_id % 3) if kind == "archer" else 0.0,
		"weapon_frame": String(combat_profile["weapon_frame"]),
		"weapon_art_ids": Array(combat_profile["weapon_arts"]).duplicate(),
		"equipped_weapon_art": String(combat_profile["equipped_weapon_art"]),
		"defense_id": String(combat_profile["defense_id"]),
		"attributes": attributes,
		"properties": Dictionary(combat_profile["properties"]).duplicate(true),
		"personal_tempo": _tempo_from_attributes(attributes),
		"posture_recovery_rate": float(Dictionary(combat_profile["properties"]).get("posture_recovery", 1.8)),
		"condition_buildup": {},
		"conditions": {},
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
			if kind in ["warden", "werewolf"] and _boss_defeated: continue
			var enemy := _make_enemy(kind, Vector2(template["pos"]), _enemy_base_hp(kind), area_id)
			enemy["layer"] = String(template.get("layer", "expedition_surface"))
			if template.has("role"): enemy["survey_role"] = String(template["role"])
			if template.has("facing"):
				var authored_facing := Vector2(template["facing"])
				if authored_facing.length_squared() > 0.001: enemy["facing"] = authored_facing.normalized()
			enemy["heard_sound_sequence"] = _sound_sequence
			enemies.append(enemy)
	_invalidate_active_enemy_cache()

func _enemy_posture_base(kind: String) -> float:
	# Resolve supplies the universal portion. These hidden bases preserve body
	# and equipment identity without creating another visible character stat.
	return {"bandit": 0.5, "knife": 0.0, "hound": 0.0, "boar": 0.0, "archer": 0.0, "hexer": 0.0, "ice_caster": 0.5, "fire_caster": 0.5, "blade": 0.0, "captain": 0.0, "shield": 1.0, "polearm": 1.0, "brute": 5.0, "knight": 10.0, "warden": 8.0, "werewolf": 7.0}.get(kind, 0.0)

func _enemy_posture_max(kind: String) -> float:
	var profile := CombatCatalogScript.archetype(kind)
	return _enemy_posture_base(kind) + float(Dictionary(profile["attributes"]).get("resolve", 5))

func _hydrate_enemy_combat_profile(enemy: Dictionary) -> Dictionary:
	var profile := CombatCatalogScript.archetype(String(enemy.get("kind", "blade")))
	if not enemy.has("weapon_frame"): enemy["weapon_frame"] = String(profile["weapon_frame"])
	if not enemy.has("weapon_art_ids"): enemy["weapon_art_ids"] = Array(profile["weapon_arts"]).duplicate()
	if not enemy.has("equipped_weapon_art"): enemy["equipped_weapon_art"] = String(profile["equipped_weapon_art"])
	if not enemy.has("defense_id"): enemy["defense_id"] = String(profile["defense_id"])
	if not enemy.has("attributes"): enemy["attributes"] = Dictionary(profile["attributes"]).duplicate(true)
	elif not Dictionary(enemy["attributes"]).has("stamina"):
		var hydrated_attributes := Dictionary(enemy["attributes"])
		hydrated_attributes["stamina"] = int(Dictionary(profile["attributes"]).get("stamina", 100))
		enemy["attributes"] = hydrated_attributes
	if not enemy.has("properties"): enemy["properties"] = Dictionary(profile["properties"]).duplicate(true)
	if not enemy.has("revealed_to_player"): enemy["revealed_to_player"] = String(enemy.get("kind", "")) != "bandit"
	if not enemy.has("revealed_elapsed"): enemy["revealed_elapsed"] = 0.0
	if not enemy.has("player_los"): enemy["player_los"] = false
	if not enemy.has("los_refresh_remaining"): enemy["los_refresh_remaining"] = 0.0
	if not enemy.has("condition_buildup"): enemy["condition_buildup"] = {}
	if not enemy.has("conditions"): enemy["conditions"] = {}
	enemy["personal_tempo"] = _tempo_from_attributes(Dictionary(enemy["attributes"]))
	enemy["posture_recovery_rate"] = float(Dictionary(enemy["properties"]).get("posture_recovery", 1.8))
	var posture_max := _enemy_posture_base(String(enemy.get("kind", "blade"))) + float(Dictionary(enemy["attributes"]).get("resolve", 5))
	var posture_ratio := float(enemy.get("posture", posture_max)) / maxf(0.001, float(enemy.get("posture_max", posture_max)))
	enemy["posture_max"] = posture_max
	enemy["posture"] = clampf(posture_ratio * posture_max, 0.0, posture_max)
	return enemy

func _sync_player_combat_profile() -> void:
	var profile := CombatCatalogScript.loadout_profile(loadout_id)
	player_weapon_frame = String(profile["weapon_frame"])
	player_weapon_art_library.assign(Array(profile["weapon_arts"]))
	player_equipped_weapon_art = String(profile["equipped_weapon_art"])
	player_attributes = Dictionary(profile["attributes"]).duplicate(true)
	player_properties = Dictionary(profile["properties"]).duplicate(true)
	martial_foundation = CombatCatalogScript.MARTIAL_DEFAULTS.duplicate(true)
	equipment_slots = {
		"main_hand": String(CombatCatalogScript.weapon_frame(player_weapon_frame).get("label", "Weapon")),
		"off_hand": "Empty",
		"head": "Empty",
		"torso": "Padded Jack" if loadout_id == "warrior" else "Travel Leathers",
		"hands": "Worn Gloves",
		"legs": "Travel Boots",
		"charm": "Waystone Fragment",
		"backpack": "Restorative Satchel",
	}
	_refresh_player_posture_capacity(true)

func player_actor() -> Dictionary:
	# Health and movement speed remain live values while the rest of the shared
	# attribute profile remains ready for temperament-gated advancement.
	var attributes := player_attributes.duplicate(true)
	attributes["health"] = player_max_hp
	attributes["stamina"] = roundi(player_max_stamina)
	attributes["speed"] = int(player_attributes.get("speed", 5))
	var properties := player_properties.duplicate(true)
	properties["collision_radius"] = PLAYER_RADIUS
	return {
		"kind": "player",
		"current_stamina": player_stamina,
		"maximum_stamina": player_max_stamina,
		"weapon_frame": player_weapon_frame,
		"weapon_art_ids": player_weapon_art_library.duplicate(),
		"equipped_weapon_art": player_equipped_weapon_art,
		"defense_id": defense_id,
		"attributes": attributes,
		"properties": properties,
		"martial_foundation": martial_foundation.duplicate(true),
		"equipment_slots": equipment_slots.duplicate(true),
		"track_ranks": track_ranks.duplicate(true),
		"track_choices": track_choices.duplicate(true),
	}

func select_loadout(choice: String) -> bool:
	if not CombatCatalogScript.loadout_ids().has(choice): return false
	loadout_id = choice
	if run_active: start_run(loadout_id, mode_id, run_seed)
	else: _apply_loadout()
	return true

func _apply_loadout() -> void:
	_sync_player_combat_profile()
	defense_id = String(CombatCatalogScript.loadout_profile(loadout_id).get("defense_id", "dodge"))
	player_max_hp = int(player_attributes.get("health", PLAYER_MAX_HP))
	player_max_stamina = float(player_attributes.get("stamina", 100))
	# The armoured Warrior should not be able to reset melee pressure through
	# ordinary walking. Faster loadouts retain their existing traversal speed;
	# the Warrior instead depends on deliberate defensive movement when flankers
	# close the distance.
	player_move_speed = WARRIOR_MOVE_SPEED if loadout_id == "warrior" else MOVE_SPEED
	match player_weapon_frame:
		"knife", "twin_knives":
			player_attack_duration = 0.70
			player_attack_startup = 0.16
			player_attack_active_end = 0.27
			player_damage_min = 6
			player_damage_max = 6
			player_attack_technique = "knife_cut_in"
			player_attack_reach = 74.0
			player_attack_posture = 1.0
		"bow":
			player_attack_duration = 0.70
			player_attack_startup = 0.10
			player_attack_active_end = 0.12
			player_damage_min = 6
			player_damage_max = 6
			player_attack_technique = "drawn_shot"
			player_attack_reach = 250.0
			player_attack_posture = 0.0
		_:
			player_attack_duration = 1.06
			player_attack_startup = 0.30
			player_attack_active_end = 0.41
			player_damage_min = 10
			player_damage_max = 10
			player_attack_technique = "diagonal_cut"
			player_attack_reach = 112.0
			player_attack_posture = 2.0

func _tempo_from_attributes(attributes: Dictionary) -> float:
	return clampf(1.0 + 0.03 * (float(attributes.get("speed", 5)) - 5.0), 0.76, 1.30)

func _player_personal_tempo() -> float:
	return _tempo_from_attributes(player_attributes) * (0.85 if float(player_conditions.get("frost", 0.0)) > 0.0 else 1.0)

func uses_stamina_rules() -> bool:
	return combat_rules == "stamina"

func stamina_actions_locked() -> bool:
	return uses_stamina_rules() and (player_stamina <= 0.0001 or player_overexertion_pending or player_exhaustion_remaining > 0.0001)

func melee_attack_readiness_locked() -> bool:
	return uses_stamina_rules() and player_weapon_frame != "bow" and player_attack_readiness_remaining > 0.0001

func basic_attack_lock_remaining() -> float:
	if not uses_stamina_rules() or player_weapon_frame == "bow": return 0.0
	return maxf(0.0, player_attack_readiness_remaining)

func basic_attack_is_available() -> bool:
	if not is_player_ready() or trial_complete or weapon_sequence_cooldown > 0.0001 or not _can_commit_physical_action(): return false
	return not melee_attack_readiness_locked()

func _can_start_basic_attack() -> bool:
	if not is_player_ready() or trial_complete or weapon_sequence_cooldown > 0.0001 or not _can_commit_physical_action(): return false
	if melee_attack_readiness_locked():
		attack_readiness_blocked_attempts_total += 1
		_set_message("Your weapon is not ready for another sequence.")
		return false
	return true

func _arm_stamina_attack_readiness(time_until_active_end: float) -> void:
	if not uses_stamina_rules() or player_weapon_frame == "bow": return
	player_attack_readiness_remaining = maxf(player_attack_readiness_remaining, maxf(0.0, time_until_active_end) + STAMINA_ATTACK_READINESS_FLOOR)

func _combat_rules_intro() -> String:
	if not uses_stamina_rules():
		return "Recovery rules: physical actions use their full commitment and cooldowns; Stamina is inactive."
	return "Stamina rules: physical actions and Dodge spend Stamina with shorter recovery. Regeneration begins after one world-second without spending it; emptying it locks those actions for two world-seconds."

func _can_commit_physical_action() -> bool:
	return not uses_stamina_rules() or not stamina_actions_locked()

func _spend_stamina(amount: float) -> bool:
	if not uses_stamina_rules(): return true
	if amount <= 0.0: return true
	if not _can_commit_physical_action(): return false
	var before := player_stamina
	player_stamina = maxf(0.0, player_stamina - amount)
	stamina_spent_total += amount
	stamina_depleted_total += before - player_stamina
	stamina_overdraw_total += maxf(0.0, amount - before)
	player_stamina_regen_delay = STAMINA_REGEN_DELAY
	if player_stamina <= 0.0001:
		player_stamina = 0.0
		player_overexertion_pending = true
	return true

func _regenerate_stamina(dt: float) -> void:
	if not uses_stamina_rules() or player_overexertion_pending or dt <= 0.0: return
	var active_dt := dt
	if player_stamina_regen_delay > 0.0:
		var delayed := minf(player_stamina_regen_delay, active_dt)
		player_stamina_regen_delay -= delayed
		stamina_regen_delay_time_total += delayed
		active_dt -= delayed
	if active_dt <= 0.0 or player_stamina >= player_max_stamina: return
	var before := player_stamina
	player_stamina = minf(player_max_stamina, player_stamina + STAMINA_REGEN_PER_SECOND * active_dt)
	stamina_regenerated_total += player_stamina - before
	stamina_regen_active_time_total += active_dt

func _begin_exhaustion() -> void:
	if not uses_stamina_rules(): return
	player_overexertion_pending = false
	player_exhaustion_remaining = EXHAUSTION_DURATION
	overexertion_count += 1
	_set_message("EXHAUSTED — physical actions are locked for two world-seconds. Move, Wait, or use a non-physical action.")

func _shorten_recovery(duration: float, active_end: float, factor: float = 0.60) -> float:
	if not uses_stamina_rules(): return duration
	return active_end + maxf(0.0, duration - active_end) * factor

func _profile_combo_phases(raw_phases: Array[Dictionary], factor: float = 0.60) -> Array[Dictionary]:
	if not uses_stamina_rules(): return raw_phases
	var result: Array[Dictionary] = []
	var raw_origin := 0.0
	var new_origin := 0.0
	for raw_value in raw_phases:
		var raw := Dictionary(raw_value)
		var startup_local := float(raw.get("startup", raw_origin)) - raw_origin
		var active_length := float(raw.get("active_end", raw_origin)) - float(raw.get("startup", raw_origin))
		var recovery_length := float(raw.get("end", raw_origin)) - float(raw.get("active_end", raw_origin))
		var profiled := raw.duplicate(true)
		profiled["startup"] = new_origin + maxf(0.0, startup_local)
		profiled["active_end"] = float(profiled["startup"]) + maxf(0.0, active_length)
		profiled["end"] = float(profiled["active_end"]) + maxf(0.0, recovery_length) * factor
		result.append(profiled)
		raw_origin = float(raw.get("end", raw_origin))
		new_origin = float(profiled["end"])
	return result

func _increase_max_stamina(amount: float) -> void:
	player_max_stamina += amount
	player_stamina = minf(player_max_stamina, player_stamina + amount)
	player_attributes["stamina"] = roundi(player_max_stamina)

func _migrate_v25_temperament_to_stamina() -> void:
	player_max_stamina = 100.0
	for stage_index in range(1, 5):
		var steadfast_choice := String(track_choices.get("steadfast_%d" % stage_index, ""))
		if steadfast_choice == "vigilance":
			player_attributes["speed"] = maxi(0, int(player_attributes.get("speed", 0)) - 1)
			player_max_stamina += 10.0
		var finesse_choice := String(track_choices.get("finesse_%d" % stage_index, ""))
		if finesse_choice == "fleetness":
			player_max_hp = maxi(1, player_max_hp - 5)
			player_hp = mini(player_hp, player_max_hp)
			player_max_stamina += 10.0
		elif finesse_choice == "subtlety":
			player_attributes["awareness"] = maxi(0, int(player_attributes.get("awareness", 0)) - 1)
			player_max_hp += 5
			player_hp = mini(player_max_hp, player_hp + 5)
		var patient_choice := String(track_choices.get("patient_%d" % stage_index, ""))
		if patient_choice == "observation":
			player_attributes["stealth"] = maxi(0, int(player_attributes.get("stealth", 0)) - 1)
			player_max_stamina += 10.0
	player_attributes["health"] = player_max_hp
	player_attributes["stamina"] = roundi(player_max_stamina)

func _player_physical_damage(technique_base: int) -> int:
	return technique_base + int(player_attributes.get("strength", 0))

func _enemy_personal_tempo(enemy: Dictionary) -> float:
	return float(enemy.get("personal_tempo", _tempo_from_attributes(Dictionary(enemy.get("attributes", {}))))) * (0.85 if float(Dictionary(enemy.get("conditions", {})).get("frost", 0.0)) > 0.0 else 1.0)

func _refresh_player_posture_capacity(fill: bool = false) -> void:
	var previous_max := maxf(0.001, player_posture_max)
	var previous_ratio := clampf(player_posture / previous_max, 0.0, 1.0)
	player_posture_max = float(player_properties.get("posture_base", 5.0)) + float(player_attributes.get("resolve", 5))
	player_posture = player_posture_max if fill else clampf(previous_ratio * player_posture_max, 0.0, player_posture_max)

func enemy_visible_to_player(enemy: Dictionary) -> bool:
	if String(enemy.get("kind", "")) != "bandit": return true
	return bool(enemy.get("revealed_to_player", false))

func _empty_character_track_ranks() -> Dictionary:
	var result := {}
	for track_id in CombatCatalogScript.track_order_for_loadout(loadout_id): result[String(track_id)] = 0
	return result

func character_track_order() -> Array[String]:
	return CombatCatalogScript.track_order_for_loadout(loadout_id)

func character_level() -> int:
	return upgrade_count + 1

func has_track_rank(track_id: String, rank: int) -> bool:
	return int(track_ranks.get(track_id, 0)) >= rank

func track_choice(stage_id: String) -> String:
	return String(track_choices.get(stage_id, ""))

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
	return run_active and not death_pending and String(player_action["kind"]) == "idle" and player_hp > 0

func request_move(direction: Vector2, distance: float = MOVE_RANGE, simulate_immediately: bool = true) -> bool:
	if not begin_streamed_move(direction, distance): return false
	if simulate_immediately: _simulate_until_ready()
	return true

func begin_streamed_move(direction: Vector2, distance: float = MOVE_RANGE) -> bool:
	if not is_player_ready() or trial_complete or direction.length_squared() < 0.01:
		return false
	_break_player_combo()
	var travel := clampf(distance, 4.0, MOVE_RANGE)
	var normalized := direction.normalized()
	player_facing = normalized
	player_action = _action("move", travel / player_move_speed, normalized)
	player_action["distance"] = travel
	player_action["speed"] = player_move_speed
	player_action["move_origin"] = player_pos
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
	if not _can_start_basic_attack(): return false
	if player_weapon_frame == "bow":
		if not begin_bow_draw(target - player_pos, _enemy_id_near_position(target)): return false
		release_bow_attack(target - player_pos)
		if simulate_immediately: _simulate_until_ready()
		return true
	_break_player_combo()
	var direction := target - player_pos
	if direction.length_squared() < 0.01:
		direction = player_facing
	player_facing = direction.normalized()
	var definition := _player_basic_attack_definition(player_facing)
	var basic_cost := 12.0 if player_weapon_frame == "twin_knives" else 14.0 if player_weapon_frame == "knife" else 18.0
	if not _spend_stamina(basic_cost): return false
	player_action = _melee_action(float(definition["duration"]), float(definition["startup"]), float(definition["active_end"]), float(definition["reach"]), int(definition["damage_max"]), player_facing, String(definition["technique"]), "attack")
	player_action["damage_min"] = int(definition["damage_min"])
	player_action["damage_max"] = int(definition["damage_max"])
	player_action["posture_damage"] = float(definition["posture"])
	player_action["combo_step"] = int(definition["step"])
	player_action["building_force_registered"] = false
	player_action["building_force_bonus"] = _building_force_bonus()
	_arm_stamina_attack_readiness(float(definition["active_end"]))
	_apply_counterstep_to_action(player_action)
	_apply_action_poise(player_action)
	_annotate_player_action("basic_attack_%d" % (int(definition["step"]) + 1))
	_emit_sound(player_pos, 350.0)
	_set_message("You commit to the %s." % AttackGeometryScript.label(String(definition["technique"])).to_lower())
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func player_basic_attack_definition() -> Dictionary:
	return _player_basic_attack_definition(player_facing).duplicate(true)

func player_uses_ranged_basic_attack() -> bool:
	return String(CombatCatalogScript.weapon_frame(player_weapon_frame).get("delivery", "melee")) == "ranged"

func request_skill(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if player_equipped_weapon_art == "prototype_drawing_cut": return request_drawing_cut(direction, simulate_immediately)
	if player_equipped_weapon_art == "prototype_sweeping_cut": return request_sweeping_cut(direction, simulate_immediately)
	if player_equipped_weapon_art == "knife_execution": return request_execution(direction, simulate_immediately)
	if player_equipped_weapon_art == "knife_twin_fang": return request_twin_fang(direction, simulate_immediately)
	if player_equipped_weapon_art == "bow_piercing_shot": return request_bow_art(direction, true, simulate_immediately)
	if player_equipped_weapon_art == "bow_fan_shot": return request_bow_art(direction, false, simulate_immediately)
	_set_message("No Weapon Art has been learned yet.")
	changed.emit()
	return false

func request_combo(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if direction.length_squared() < 0.01 or not _can_start_basic_attack(): return false
	_break_player_combo()
	_reset_building_force()
	_reset_building_force_if_unavailable()
	if player_weapon_frame in ["knife", "twin_knives"]: _begin_knife_combo(direction, true)
	elif player_weapon_frame == "bow": return false
	else: _begin_sword_combo(direction, true, false)
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_direct_attack(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if direction.length_squared() < 0.01: direction = player_facing
	var began := begin_bow_draw(direction) if player_weapon_frame == "bow" else request_combo(direction, false)
	if not began: return false
	direct_attack_uses_total += 1
	if simulate_immediately and player_weapon_frame != "bow": _simulate_until_ready()
	return true

func begin_bow_draw(direction: Vector2, soft_target_id: int = -1) -> bool:
	if not is_player_ready() or trial_complete or player_weapon_frame != "bow" or not _can_commit_physical_action(): return false
	if direction.length_squared() < 0.01: direction = player_facing
	player_facing = direction.normalized()
	player_action = _action("bow_draw", 999.0, player_facing)
	player_action.merge({"aim_direction": player_facing, "draw_ratio": 0.0, "shot_spawned": false, "soft_target_id": soft_target_id, "manual_aim": false}, true)
	if bow_followup_ready:
		player_action["elapsed"] = 0.45
		bow_followup_ready = false
		bow_followup_consumed = true
	else:
		bow_followup_consumed = false
	_annotate_player_action("bow_draw")
	_emit_sound(player_pos, 80.0)
	_set_message("You begin drawing the Bow. Release to fire.")
	_streamed_action_cpu_usec = 0
	return true

func set_bow_aim(direction: Vector2) -> void:
	if String(player_action.get("kind", "")) != "bow_draw" or direction.length_squared() < 0.01: return
	var desired := direction.normalized()
	var current := Vector2(player_action.get("aim_direction", player_facing)).normalized()
	var maximum_turn := deg_to_rad(12.0)
	var angle := clampf(current.angle_to(desired), -maximum_turn, maximum_turn)
	var adjusted := current.rotated(angle).normalized()
	player_action["aim_direction"] = adjusted
	player_action["direction"] = adjusted
	player_action["manual_aim"] = true
	player_action["soft_target_id"] = -1
	player_facing = adjusted

func _enemy_id_near_position(position: Vector2, tolerance: float = 80.0) -> int:
	var best_id := -1
	var best_distance := tolerance
	for enemy in _nearby_enemies(position, tolerance + 80.0):
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		var distance := Vector2(enemy["pos"]).distance_to(position)
		if distance <= best_distance:
			best_distance = distance
			best_id = int(enemy["id"])
	return best_id

func _update_bow_soft_aim(dt: float) -> void:
	var target_id := int(player_action.get("soft_target_id", -1))
	if target_id < 0 or bool(player_action.get("manual_aim", false)): return
	var target := _enemy_by_id(target_id)
	if target.is_empty() or not enemy_visible_to_player(target) or not is_visible(Vector2(target["pos"])) or not _has_line_of_sight(player_pos, Vector2(target["pos"])):
		player_action["soft_target_id"] = -1
		return
	var desired := player_pos.direction_to(Vector2(target["pos"]))
	var current := Vector2(player_action.get("aim_direction", player_facing)).normalized()
	var angle := clampf(current.angle_to(desired), -2.4 * dt, 2.4 * dt)
	var adjusted := current.rotated(angle).normalized()
	player_action["aim_direction"] = adjusted
	player_action["direction"] = adjusted
	player_facing = adjusted

func release_bow_attack(direction: Vector2 = Vector2.ZERO) -> bool:
	if String(player_action.get("kind", "")) != "bow_draw": return false
	if direction.length_squared() > 0.01: set_bow_aim(direction)
	var draw_time := float(player_action.get("elapsed", 0.0))
	var ratio := clampf(draw_time / 0.90, 0.0, 1.0)
	if not _spend_stamina(lerpf(10.0, 28.0, ratio)):
		player_action = _idle_action()
		return false
	var strength_adjustment := int(player_attributes.get("strength", 4)) - 4
	# A loose arrow is an emergency release, not a fast melee substitute. Full
	# draw supplies the Bow's damage and stopping power; quick kiting shots retain
	# utility without repeatedly arresting every pursuer.
	var loose_damage := (6 if has_track_rank("bow", 2) else 4) + strength_adjustment
	var full_damage := (16 if has_track_rank("bow", 3) else 13) + strength_adjustment
	var loose_range := 300.0 if has_track_rank("bow", 2) else 250.0
	var maximum_range := lerpf(loose_range, 700.0, ratio) * _aimed_projectile_range_multiplier()
	var velocity := lerpf(480.0, 820.0, ratio)
	var damage := roundi(lerpf(float(loose_damage), float(full_damage), ratio))
	var posture := lerpf(0.0, 3.25 if has_track_rank("bow", 3) else 2.5, ratio)
	var recovery := lerpf(0.70, 1.30, ratio)
	if has_track_rank("bow", 4): recovery *= 0.80
	recovery = _shorten_recovery(recovery, 0.06, 0.65)
	var aim := Vector2(player_action.get("aim_direction", player_facing)).normalized()
	player_action = _action("bow_release", recovery, aim)
	player_action.merge({"startup": 0.06, "shot_spawned": false, "projectile_damage": damage, "projectile_posture": posture, "projectile_speed": velocity, "projectile_range": maximum_range, "draw_ratio": ratio, "full_draw": ratio >= 0.995}, true)
	_annotate_player_action("bow_shot")
	_set_message("You release a %s shot." % ("Full" if ratio >= 0.995 else "Drawn" if ratio >= 0.42 else "Loose"))
	return true

func _aimed_projectile_range_multiplier() -> float:
	return 1.15 if has_track_rank("sharpshooter", 2) else 1.0

func _begin_knife_combo(direction: Vector2, held: bool) -> void:
	player_facing = direction.normalized()
	var twin := player_weapon_frame == "twin_knives"
	var speed_scale := 0.92 if has_track_rank("knife", 3) else 1.0
	var count := 6 if twin else 4
	var total := 2.65 * speed_scale
	var interval := total / float(count)
	var techniques := ["knife_cut_in", "knife_cut_out", "knife_rising_cut", "knife_falling_cut"]
	var stamina_costs := [12.0, 9.0, 9.0, 9.0, 9.0, 12.0] if twin else [14.0, 12.0, 12.0, 16.0]
	var phases: Array[Dictionary] = []
	for index in range(count):
		var phase_start := interval * float(index)
		phases.append({
			"startup": phase_start + interval * (0.18 if twin else 0.16),
			"active_end": phase_start + interval * (0.34 if twin else 0.32),
			"end": phase_start + interval,
			"reach": 72.0 if twin else 74.0,
			"damage_min": _player_physical_damage(1 if twin else 2) + (1 if has_track_rank("knife", 2) else 0),
			"damage_max": _player_physical_damage(1 if twin else 2) + (1 if has_track_rank("knife", 2) else 0),
			"posture": 0.65 if twin else 1.0,
			"technique": techniques[index % techniques.size()],
			"stamina_cost": stamina_costs[index],
		})
	phases = _profile_combo_phases(phases, 0.55)
	total = float(phases[-1]["end"])
	if not _spend_stamina(float(stamina_costs[0])): return
	player_action = _action("combo", total, player_facing)
	player_action["phases"] = phases
	player_action["combo_length"] = phases.size()
	player_action["combo_instance_id"] = _next_combo_instance_id
	_next_combo_instance_id += 1
	player_action["phase_index"] = -1
	player_action["continue_held"] = held
	player_action["committed_phase"] = 0
	player_action["knife_sequence"] = true
	player_action["knife_contact_chain"] = 0
	player_action["building_force_registered"] = false
	_arm_stamina_attack_readiness(float(Dictionary(phases[0])["active_end"]))
	_apply_action_poise(player_action)
	_annotate_player_action("knife_sequence")
	_emit_sound(player_pos, 260.0)
	_set_message("The Knife sequence begins. Hold to continue cutting.")

func request_execution(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or (skill_cooldown > 0.0001 and not uses_stamina_rules()) or direction.length_squared() < 0.01 or not _spend_stamina(30.0): return false
	player_facing = direction.normalized()
	var execution_damage := _player_physical_damage(8)
	player_action = _melee_action(1.16, 0.34, 0.45, 92.0, execution_damage, player_facing, "knife_falling_cut", "sweep")
	player_action["damage_min"] = execution_damage
	player_action["damage_max"] = execution_damage
	player_action["posture_damage"] = 3.0
	player_action["unaware_bonus_multiplier"] = 1.0
	player_action["move_start"] = 0.06
	player_action["move_end"] = 0.32
	player_action["speed"] = 245.0
	player_action["execution_target_id"] = _execution_target_id(player_facing)
	var execution_target := _enemy_by_id(int(player_action["execution_target_id"]))
	player_action["execution_target_was_unaware"] = not execution_target.is_empty() and String(execution_target.get("awareness", "idle")) != "alerted"
	_apply_action_poise(player_action)
	_annotate_player_action("knife_execution")
	skill_cooldown = 0.0 if uses_stamina_rules() else 5.5 * _skill_cooldown_multiplier
	_set_message("You commit to Execution.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func _execution_target_id(direction: Vector2) -> int:
	var best_id := -1
	var best_distance := INF
	var facing := direction.normalized()
	for enemy in _nearby_enemies(player_pos, 205.0):
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		var offset := Vector2(enemy["pos"]) - player_pos
		var distance := offset.length()
		if distance <= 0.001 or facing.dot(offset / distance) < cos(deg_to_rad(34.0)): continue
		if distance < best_distance:
			best_distance = distance
			best_id = int(enemy["id"])
	return best_id

func request_twin_fang(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or (skill_cooldown > 0.0001 and not uses_stamina_rules()) or direction.length_squared() < 0.01 or not _spend_stamina(32.0): return false
	player_facing = direction.normalized()
	player_action = _action("twin_fang", _shorten_recovery(0.68, 0.29), player_facing)
	player_action.merge({"startup": 0.20, "active_end": 0.29, "move_start": 0.05, "move_end": 0.24, "speed": 320.0, "reach": 104.0, "damage_per_blade": 8, "posture_per_blade": 2.0, "contact_done": false}, true)
	_apply_action_poise(player_action)
	_annotate_player_action("knife_twin_fang")
	skill_cooldown = 0.0 if uses_stamina_rules() else 4.5 * _skill_cooldown_multiplier
	_emit_sound(player_pos, 300.0)
	_set_message("Twin Fang drives both blades through one opening.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_bow_art(direction: Vector2, piercing: bool, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or (skill_cooldown > 0.0001 and not uses_stamina_rules()) or direction.length_squared() < 0.01 or not _spend_stamina(38.0 if piercing else 32.0): return false
	player_facing = direction.normalized()
	var art_startup := 0.54 if piercing else 0.28
	var art_duration := _shorten_recovery(1.50 if piercing else 0.90, art_startup, 0.68)
	player_action = _action("bow_art", art_duration, player_facing)
	player_action.merge({"startup": 0.54 if piercing else 0.28, "shot_spawned": false, "piercing": piercing}, true)
	_annotate_player_action("bow_piercing_shot" if piercing else "bow_fan_shot")
	skill_cooldown = 0.0 if uses_stamina_rules() else (6.5 if piercing else 5.0) * _skill_cooldown_multiplier
	_emit_sound(player_pos, 260.0)
	_set_message("You prepare %s." % ("Piercing Shot" if piercing else "Fan Shot"))
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func player_is_noticed() -> bool:
	_refresh_active_enemy_cache()
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy: Dictionary = enemies[index]
		if _enemy_on_current_layer(enemy) and int(enemy.get("hp", 0)) > 0 and String(enemy.get("awareness", "idle")) == "alerted": return true
	return false

func stealth_status() -> String:
	if not loadout_id.begins_with("rogue_"): return "locked"
	if stealth_remaining > 0.0001: return "active"
	if main_ability_cooldown > 0.0001: return "cooldown"
	if not has_track_rank("rogue", 4) and player_is_noticed(): return "noticed"
	return "available"

func request_stealth(simulate_immediately: bool = true) -> bool:
	if not is_player_ready(): return false
	var status := stealth_status()
	if status != "available":
		if status == "noticed": _set_message("An enemy knows where you are. Vanish is required.")
		return false
	player_action = _action("stealth", 0.40, player_facing)
	player_action["effect_start"] = 0.24
	player_action["effect_done"] = false
	_annotate_player_action("rogue_stealth")
	_set_message("You begin slipping from notice.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_vault(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or subclass_ability_cooldown > 0.0001 or direction.length_squared() < 0.01: return false
	player_facing = direction.normalized()
	var recovery := 0.10 if has_track_rank("acrobat", 1) else 0.20
	player_action = _action("vault", 0.34 + recovery, player_facing)
	player_action.merge({"speed": 582.0, "move_start": 0.0, "move_end": 0.34, "evade_start": 0.0, "evade_end": 0.34 + (0.06 if has_track_rank("acrobat", 2) else 0.0), "clean_dodge_triggered": false, "vault_crossed_ids": []}, true)
	_annotate_player_action("acrobat_vault")
	subclass_ability_cooldown = 4.8 if has_track_rank("acrobat", 4) else 8.0
	_emit_sound(player_pos, 210.0)
	_set_message("You Vault through the opening.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_take_aim(target_id: int, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or subclass_ability_cooldown > 0.0001: return false
	var target := _enemy_by_id(target_id)
	if target.is_empty() or not enemy_visible_to_player(target) or not is_visible(Vector2(target["pos"])): return false
	player_facing = player_pos.direction_to(Vector2(target["pos"]))
	player_action = _action("take_aim", 1.35, player_facing)
	player_action.merge({"target_id": target_id, "effect_start": 1.05, "effect_done": false}, true)
	_annotate_player_action("sharpshooter_take_aim")
	_set_message("You study the target.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func _enemy_by_id(enemy_id: int) -> Dictionary:
	for enemy in enemies:
		if int(enemy.get("id", -1)) == enemy_id: return enemy
	return {}

func _begin_sword_combo(direction: Vector2, held: bool, from_advance: bool) -> void:
	if not _spend_stamina(18.0): return
	player_facing = direction.normalized()
	var edge_damage := 1 if has_track_rank("swordsmanship", 3) else 0
	var edge_posture := 0.5 if has_track_rank("swordsmanship", 3) else 0.0
	var flowing := has_track_rank("swordsmanship", 5)
	var duration := 3.08 if flowing else 3.34
	var opener_startup := 0.24 if from_advance and has_track_rank("vanguard", 2) else 0.30
	var opener_posture := 2.3 if from_advance and has_track_rank("vanguard", 2) else 1.8
	var second_damage := 13 if uses_stamina_rules() else 10
	var finisher_damage := 17 if uses_stamina_rules() else 15
	var second_posture := 2.8 if uses_stamina_rules() else 2.2
	var finisher_posture := 4.5 if uses_stamina_rules() else 3.8
	var phases: Array[Dictionary] = [
		{"startup": opener_startup, "active_end": 0.52, "end": 0.92 if flowing else 0.98, "reach": 104.0, "damage_min": 10 + edge_damage, "damage_max": 10 + edge_damage, "posture": opener_posture + edge_posture, "technique": "opening_cut", "stamina_cost": 18.0},
		{"startup": 0.99 if flowing else 1.08, "active_end": 1.25 if flowing else 1.34, "end": 1.88 if flowing else 2.04, "reach": 116.0, "damage_min": second_damage + edge_damage, "damage_max": second_damage + edge_damage, "posture": second_posture + edge_posture, "technique": "reverse_cut", "stamina_cost": 16.0},
		{"startup": 2.18 if flowing else 2.42, "active_end": 2.48 if flowing else 2.72, "end": duration, "reach": 158.0, "damage_min": finisher_damage + edge_damage, "damage_max": finisher_damage + edge_damage, "posture": finisher_posture + edge_posture, "technique": "turning_slash", "stamina_cost": 22.0},
	]
	phases = _profile_combo_phases(phases, 0.60)
	duration = float(phases[-1]["end"])
	player_action = _action("combo", duration, player_facing)
	player_action["phases"] = phases
	player_action["combo_length"] = 3
	player_action["combo_instance_id"] = _next_combo_instance_id
	_next_combo_instance_id += 1
	player_action["phase_index"] = -1
	# The first cut starts immediately. A release may be corrected by touching down
	# again during recovery; that restores the same held state as an uninterrupted
	# press, rather than queuing only one later strike.
	player_action["continue_held"] = held
	player_action["committed_phase"] = 0
	player_action["building_force_registered"] = false
	player_action["building_force_bonus"] = _building_force_bonus()
	_arm_stamina_attack_readiness(float(Dictionary(phases[0])["active_end"]))
	_apply_counterstep_to_combo(player_action)
	_apply_action_poise(player_action)
	_annotate_player_action("sword_combo")
	_emit_sound(player_pos, 470.0)
	_set_message("The opening cut begins. Hold to commit the next strike.")

func set_attack_hold(held: bool) -> void:
	if String(player_action.get("kind", "idle")) != "combo": return
	player_action["continue_held"] = held
	if not held:
		_set_message("Release noted. Finish the current cut, then time freezes.")

func resume_combo_hold() -> bool:
	if String(player_action.get("kind", "idle")) != "combo": return false
	var phases: Array = player_action.get("phases", [])
	var committed_phase := int(player_action.get("committed_phase", 0))
	if committed_phase >= phases.size() - 1: return false
	var phase: Dictionary = phases[committed_phase]
	var elapsed := float(player_action.get("elapsed", 0.0))
	# A renewed touch may happen anywhere during the current committed strike. What
	# matters is that it remains down when this phase reaches its recovery boundary.
	if elapsed >= float(phase["end"]): return false
	player_action["continue_held"] = true
	_set_message("Your grip returns. The sequence continues.")
	return true

func request_sweeping_cut(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or skill_cooldown > 0.0001 or direction.length_squared() < 0.01 or not _spend_stamina(34.0):
		return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	var extended := has_track_rank("swordsmanship", 4)
	var flowing := has_track_rank("swordsmanship", 5)
	var edge := has_track_rank("swordsmanship", 3)
	player_action = _melee_action(1.29 if flowing else 1.42, 0.44, 0.57, 178.0 if extended else 158.0, 15, player_facing, "broad_sweep", "sweep")
	player_action["posture_damage"] = 5.0 + (0.5 if edge else 0.0)
	player_action["damage_min"] = 15 + (1 if edge else 0)
	player_action["damage_max"] = int(player_action["damage_min"])
	_apply_action_poise(player_action)
	_annotate_player_action(player_equipped_weapon_art if player_equipped_weapon_art != "" else "prototype_sweeping_cut")
	# Sweeping Cut is crowd control, not a replacement basic attack. Its Stamina
	# cost limits burst length while the shared art cooldown prevents repeatedly
	# sweeping a grouped melee formation every time control returns.
	skill_cooldown = SWEEP_COOLDOWN * _skill_cooldown_multiplier
	_emit_sound(player_pos, 470.0)
	_set_message("You commit to a broad, posture-breaking cut.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_drawing_cut(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or (skill_cooldown > 0.0001 and not uses_stamina_rules()) or direction.length_squared() < 0.01 or not _spend_stamina(32.0):
		return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	var extended := has_track_rank("swordsmanship", 4)
	var flowing := has_track_rank("swordsmanship", 5)
	var edge := has_track_rank("swordsmanship", 3)
	player_action = _melee_action(1.15 if flowing else 1.25, 0.29, 0.40, 196.0 if extended else 176.0, 20, player_facing, "driving_cut", "sweep")
	player_action["posture_damage"] = 3.0 + (0.5 if edge else 0.0)
	player_action["damage_min"] = 20 + (1 if edge else 0)
	player_action["damage_max"] = int(player_action["damage_min"])
	_apply_action_poise(player_action)
	_annotate_player_action("prototype_drawing_cut")
	skill_cooldown = 0.0 if uses_stamina_rules() else SWEEP_COOLDOWN * _skill_cooldown_multiplier
	_emit_sound(player_pos, 410.0)
	_set_message("You draw through a narrow opening in one committed cut.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_dodge(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or (dodge_cooldown > 0.0001 and not uses_stamina_rules()) or direction.length_squared() < 0.01 or not _spend_stamina(DODGE_STAMINA_COST):
		return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	var style := track_choice("evasion_style")
	var duration := 0.60 if has_track_rank("evasion", 1) else 0.66
	var move_start := 0.08
	var move_end := 0.38
	var evade_start := 0.08
	var evade_end := 0.38
	var speed := DODGE_SPEED
	var cooldown := 3.6 if has_track_rank("evasion", 1) else DODGE_COOLDOWN
	if uses_stamina_rules():
		# Stamina Dodge has no long cooldown. Every learned form strictly improves
		# the modest but dependable basic Dodge, then specializes either recovery
		# or protected displacement without hiding a higher Stamina cost.
		if style == "sidestep":
			duration = 0.47
			move_start = 0.05
			move_end = 0.29
			evade_start = 0.05
			evade_end = 0.35
			speed = 700.0
		elif style == "long_roll":
			duration = 0.60
			move_start = 0.05
			move_end = 0.40
			evade_start = 0.05
			evade_end = 0.40
			speed = 660.0
		elif has_track_rank("evasion", 1):
			duration = 0.56
			move_start = 0.06
			move_end = 0.36
			evade_start = 0.06
			evade_end = 0.36
			speed = 560.0
		else:
			duration = 0.56
			move_start = 0.08
			move_end = 0.32
			evade_start = 0.08
			evade_end = 0.32
			speed = 625.0
	else:
		# Recovery remains the untouched comparison profile.
		if style == "sidestep":
			duration = 0.48
			move_start = 0.06
			move_end = 0.30
			evade_start = 0.06
			evade_end = 0.36
			speed = 700.0
			cooldown = 2.8
		elif style == "long_roll":
			duration = 0.58
			move_start = 0.05
			move_end = 0.40
			evade_start = move_start
			evade_end = move_end
			speed = 660.0
			cooldown = 3.6
	player_action = _action("dodge", duration, player_facing)
	var reported_style := style if not style.is_empty() else "practised" if has_track_rank("evasion", 1) else "basic"
	player_action.merge({"speed": speed, "move_start": move_start, "move_end": move_end, "evade_start": evade_start, "evade_end": evade_end, "vulnerable_recovery_start": evade_end, "dodge_style": reported_style, "clean_dodge_triggered": false}, true)
	dodge_style_uses_total[reported_style] = int(dodge_style_uses_total.get(reported_style, 0)) + 1
	_annotate_player_action("defense_dodge")
	dodge_cooldown = 0.0 if uses_stamina_rules() else cooldown
	_emit_sound(player_pos, 270.0)
	_set_message("You commit to a dodge.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_rally(simulate_immediately: bool = true) -> bool:
	if not rally_is_available(): return false
	_break_player_combo()
	_reset_building_force()
	player_action = _action("rally", 0.56, player_facing)
	player_action["effect_start"] = 0.18
	player_action["rally_started"] = false
	_annotate_player_action("warrior_rally")
	_set_message("You gather yourself for Rally.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func rally_is_available() -> bool:
	return is_player_ready() and not trial_complete and rally_cooldown <= 0.0001 and rally_remaining <= 0.0001

func request_advance(direction: Vector2, continue_held: bool = false, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or (advance_cooldown > 0.0001 and not uses_stamina_rules()) or direction.length_squared() < 0.01 or not _spend_stamina(28.0): return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	var posture := 6.0 if has_track_rank("vanguard", 1) else 4.0
	var push := 40.0 if has_track_rank("vanguard", 1) else 32.0
	var damage := 15 if has_track_rank("vanguard", 1) else 10
	player_action = _action("advance", _shorten_recovery(0.92, 0.52), player_facing)
	player_action.merge({
		"move_start": 0.08, "move_end": 0.42, "impact_start": 0.36, "impact_end": 0.52,
		"speed": 424.0, "damage_min": damage, "damage_max": damage, "posture_damage": posture, "push": push,
		"continue_held": continue_held, "impact_ids": [], "pass_mass": -1.0, "max_targets": 1,
	}, true)
	_apply_action_poise(player_action, 4.0)
	advance_cooldown = 0.0 if uses_stamina_rules() else 6.0
	_annotate_player_action("vanguard_advance")
	_emit_sound(player_pos, 420.0)
	_set_message("You commit to Advance.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func set_advance_hold(held: bool) -> void:
	if String(player_action.get("kind", "")) == "advance":
		player_action["continue_held"] = held

func request_block(direction: Vector2, simulate_immediately: bool = false) -> bool:
	if not is_player_ready() or trial_complete or direction.length_squared() < 0.01:
		return false
	_break_player_combo()
	_reset_building_force()
	player_facing = direction.normalized()
	player_action = _action("block", 999.0, player_facing)
	player_action["startup"] = 0.16
	player_action["active_end"] = 999.0
	player_action["guard_held"] = true
	_annotate_player_action("defense_block")
	_set_message("Your directional guard remains raised while held.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_endure(direction: Vector2, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete or endure_cooldown > 0.0001:
		return false
	_break_player_combo()
	_reset_building_force()
	if direction.length_squared() > 0.01:
		player_facing = direction.normalized()
	player_action = _action("endure", 1.05, player_facing)
	player_action["startup"] = 0.14
	player_action["active_end"] = 0.72
	_annotate_player_action("defense_endure")
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
	if not is_player_ready() or (potions <= 0 and not has_infinite_potions()) or player_hp >= player_max_hp:
		return false
	_break_player_combo()
	_reset_building_force()
	if not has_infinite_potions(): potions -= 1
	potions_used_total += 1
	player_action = _action("potion", maxf(0.48, 0.72 - 0.06 * float(track_property_ranks.get("fieldcraft_recovery", 0))), Vector2.ZERO)
	_annotate_player_action("rejuvenation_potion")
	_emit_sound(player_pos, 90.0)
	_set_message("You draw from the rejuvenation pouch.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func has_infinite_potions() -> bool:
	return bool(mode_config.get("infinite_potions_for_testing", false))

func healing_capacity() -> int:
	return HEALING_CAPACITY + int(track_property_ranks.get("fieldcraft_capacity", 0))

func _empty_consumable_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index in range(CONSUMABLE_SLOT_COUNT): result.append({"id": "", "count": 0})
	return result

func consumable_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= consumable_slots.size(): return {}
	return Dictionary(consumable_slots[slot])

func consumable_definition(item_id: String) -> Dictionary:
	return Dictionary(CONSUMABLES.get(item_id, {}))

func consumable_requires_direction(slot: int) -> bool:
	return bool(consumable_definition(String(consumable_slot(slot).get("id", ""))).get("targeted", false))

func request_consumable(slot: int, direction: Vector2 = Vector2.ZERO, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete: return false
	var stored := consumable_slot(slot)
	var item_id := String(stored.get("id", ""))
	if item_id.is_empty() or int(stored.get("count", 0)) <= 0: return false
	var definition := consumable_definition(item_id)
	if bool(definition.get("targeted", false)) and direction.length_squared() < 0.01: return false
	_break_player_combo()
	_reset_building_force()
	stored["count"] = int(stored["count"]) - 1
	if int(stored["count"]) <= 0:
		stored["id"] = ""
		stored["count"] = 0
	consumable_slots[slot] = stored
	var facing := direction.normalized() if direction.length_squared() > 0.01 else player_facing
	player_facing = facing
	player_action = _action("consumable", 0.78 if item_id == "firebomb" else 0.58, facing)
	player_action["item_id"] = item_id
	player_action["slot"] = slot
	player_action["startup"] = 0.24 if item_id != "firebomb" else 0.34
	_annotate_player_action("consumable_%s" % item_id)
	_emit_sound(player_pos, 115.0 if item_id == "firebomb" else 72.0)
	_set_message("You ready the %s." % String(definition.get("label", item_id)).to_lower())
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_repack(first_slot: int, second_slot: int, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or first_slot < 0 or second_slot < 0 or first_slot >= consumable_slots.size() or second_slot >= consumable_slots.size() or first_slot == second_slot: return false
	var first := consumable_slot(first_slot)
	_reset_building_force()
	consumable_slots[first_slot] = consumable_slot(second_slot)
	consumable_slots[second_slot] = first
	player_action = _action("repack", 0.32, Vector2.ZERO)
	_set_message("You repack the belt.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func nearby_pickup() -> Dictionary:
	for pickup_value in world_pickups:
		var pickup: Dictionary = pickup_value
		if String(pickup.get("layer", current_layer)) == current_layer and player_pos.distance_to(Vector2(pickup["pos"])) <= 112.0: return pickup
	return {}

func has_pending_pickup() -> bool:
	return not pending_pickup.is_empty()

func request_collect_nearby_pickup(simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or has_pending_pickup(): return false
	var pickup := nearby_pickup()
	if pickup.is_empty(): return false
	var item_id := String(pickup.get("item_id", ""))
	if item_id == "rejuvenation":
		if potions >= healing_capacity():
			_set_message("The rejuvenation pouch is already full.")
			changed.emit()
			return false
		potions = mini(healing_capacity(), potions + int(pickup.get("count", 1)))
		_remove_pickup(String(pickup["id"]))
		return _begin_repack_action("You add a rejuvenation draught to the pouch.", simulate_immediately)
	var amount := int(pickup.get("count", 1))
	for slot_index in range(consumable_slots.size()):
		var stored := consumable_slot(slot_index)
		if String(stored.get("id", "")) != item_id: continue
		var maximum := int(consumable_definition(item_id).get("max_stack", 1))
		if int(stored.get("count", 0)) >= maximum: continue
		stored["count"] = mini(maximum, int(stored["count"]) + amount)
		consumable_slots[slot_index] = stored
		_remove_pickup(String(pickup["id"]))
		return _begin_repack_action("You stow the %s." % String(consumable_definition(item_id).get("label", item_id)).to_lower(), simulate_immediately)
	for slot_index in range(consumable_slots.size()):
		if not String(consumable_slot(slot_index).get("id", "")).is_empty(): continue
		consumable_slots[slot_index] = {"id": item_id, "count": mini(amount, int(consumable_definition(item_id).get("max_stack", 1)))}
		_remove_pickup(String(pickup["id"]))
		return _begin_repack_action("You stow the %s." % String(consumable_definition(item_id).get("label", item_id)).to_lower(), simulate_immediately)
	pending_pickup = pickup.duplicate(true)
	_set_message("Belt full. Tap a belt slot to replace it, or wait to leave it.")
	changed.emit()
	return false

func replace_pending_pickup(slot: int, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or pending_pickup.is_empty() or slot < 0 or slot >= consumable_slots.size(): return false
	var item_id := String(pending_pickup.get("item_id", ""))
	if item_id.is_empty(): return false
	var displaced := consumable_slot(slot)
	consumable_slots[slot] = {"id": item_id, "count": mini(int(pending_pickup.get("count", 1)), int(consumable_definition(item_id).get("max_stack", 1)))}
	_remove_pickup(String(pending_pickup["id"]))
	pending_pickup.clear()
	if not String(displaced.get("id", "")).is_empty() and int(displaced.get("count", 0)) > 0:
		_drop_belt_item(displaced)
	var incoming_label := String(consumable_definition(item_id).get("label", item_id)).to_lower()
	var displaced_label := String(consumable_definition(String(displaced.get("id", ""))).get("label", "belt item")).to_lower()
	return _begin_repack_action("You trade %s for %s." % [displaced_label, incoming_label], simulate_immediately)

func leave_pending_pickup() -> bool:
	if pending_pickup.is_empty(): return false
	pending_pickup.clear()
	_set_message("You leave the item where it lies.")
	changed.emit()
	return true

func _remove_pickup(pickup_id: String) -> void:
	world_pickups = world_pickups.filter(func(value: Dictionary) -> bool: return String(value.get("id", "")) != pickup_id)

func _drop_belt_item(stored: Dictionary) -> void:
	# A full-belt replacement is a physical exchange, not silent destruction.
	# The entire displaced stack remains at the player's feet for a later choice.
	var serial := 0
	var pickup_id := "discard_%d_%d" % [roundi(simulation_time * 120.0), serial]
	while world_pickups.any(func(value: Dictionary) -> bool: return String(value.get("id", "")) == pickup_id):
		serial += 1
		pickup_id = "discard_%d_%d" % [roundi(simulation_time * 120.0), serial]
	world_pickups.append({
		"id": pickup_id,
		"item_id": String(stored["id"]),
		"count": int(stored["count"]),
		"pos": player_pos,
		"layer": current_layer,
		"area_id": current_area_id,
	})

func _begin_repack_action(text: String, simulate_immediately: bool) -> bool:
	_reset_building_force()
	player_action = _action("repack", 0.32, Vector2.ZERO)
	_set_message(text)
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func request_wait(duration: float = 0.50, simulate_immediately: bool = true) -> bool:
	if not is_player_ready() or trial_complete:
		return false
	if interaction_label() != "WAIT": return request_context_action()
	_break_player_combo()
	_reset_building_force()
	player_action = _action("wait", clampf(duration, 0.1, 1.0), Vector2.ZERO)
	_set_message("You deliberately surrender time.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func interaction_label() -> String:
	if not run_active or death_pending: return "WAIT"
	if bool(mode_config["waystone_available"]) and not nearby_waystone().is_empty(): return "REST"
	if not nearby_pickup().is_empty(): return "TAKE"
	var shortcut := _nearby_locked_shortcut()
	if not shortcut.is_empty(): return "CLEAR" if String(shortcut.get("presentation", "")) == "hidden_woodland_path" else "UNLOCK"
	if not _nearby_transition().is_empty(): return "TRAVERSE"
	return "WAIT"

func request_context_action() -> bool:
	if not is_player_ready(): return false
	match interaction_label():
		"REST": return activate_waystone()
		"TAKE": return request_collect_nearby_pickup()
		"UNLOCK", "CLEAR": return unlock_shortcut()
		"TRAVERSE": return use_transition()
		_: return request_wait()

func can_learn_at_waystone() -> bool:
	return level_up_context() == "waystone"

func level_up_context() -> String:
	if not is_player_ready() or trial_complete: return ""
	if mode_id == ModeRulesScript.EXPEDITION:
		return "expedition" if carried_xp >= next_upgrade_cost() else ""
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		return "survey" if carried_xp >= next_upgrade_cost() else ""
	if mode_id == ModeRulesScript.CAMPAIGN_LAB and not nearby_waystone().is_empty() and secured_xp >= next_upgrade_cost():
		return "waystone"
	return ""

func can_open_level_sheet() -> bool:
	return not level_up_context().is_empty() and not available_level_up_options().is_empty()

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
	var parts: Array[String] = ["health and Stamina restored", "enemies revived"]
	if xp_gained > 0: parts.append("%d XP integrated" % xp_gained)
	if memories_gained > 0: parts.append("%d map traces anchored" % memories_gained)
	if shortcut_gained: parts.append("shortcut remembered")
	_set_message("Waystone: %s." % ", ".join(parts))
	changed.emit()
	return true

func learn_at_waystone() -> bool:
	if level_up_context() != "waystone": return false
	_set_message("The Waystone holds still. Choose what the Warrior retains.")
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
		if current_area_id >= 0: desired[current_area_id] = true
		for edge_value in Array(run_graph.get("edges", [])):
			var edge := Dictionary(edge_value)
			var from_id := int(edge.get("from", -1))
			var to_id := int(edge.get("to", -1))
			if from_id == current_area_id and to_id >= 0: desired[to_id] = true
			if to_id == current_area_id and from_id >= 0: desired[from_id] = true
		if desired.size() <= 1:
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
		if bool(feature.get("secret_gate", false)) and _secret_is_revealed(String(feature.get("secret_id", ""))): continue
		loaded_terrain_features.append(feature)
		if bool(feature.get("blocks", String(feature.get("kind", "")) == "tree")):
			var radius := float(feature.get("radius", 40.0))
			base_walls.append(Rect2(Vector2(feature["pos"]) - Vector2.ONE * radius * 0.42, Vector2.ONE * radius * 0.84))
	_build_terrain_feature_spatial_index()
	if geometry_style != "organic": base_walls.assign(Array(base_walls_by_layer.get(current_layer, [])))
	performance_metrics["loaded_regions"] = loaded_region_ids.size()
	_invalidate_active_enemy_cache()

func _secret_is_revealed(secret_id: String) -> bool:
	for secret in secret_passages:
		if String(secret.get("id", "")) == secret_id:
			return bool(secret.get("revealed", false))
	return false

func _update_secret_passages() -> bool:
	for index in range(secret_passages.size()):
		var secret: Dictionary = secret_passages[index]
		if bool(secret.get("revealed", false)) or String(secret.get("layer", current_layer)) != current_layer: continue
		var distance := player_pos.distance_to(Vector2(secret.get("reveal_pos", secret.get("gate_pos", Vector2.ZERO))))
		var awareness_reveal := int(player_attributes.get("awareness", 5)) >= int(secret.get("concealment", 7)) and distance <= float(secret.get("awareness_radius", 240.0))
		var manual_reveal := distance <= float(secret.get("manual_radius", 58.0))
		if not awareness_reveal and not manual_reveal: continue
		secret["revealed"] = true
		secret_passages[index] = secret
		var reward := Dictionary(secret.get("reward", {})).duplicate(true)
		if not reward.is_empty() and not world_pickups.any(func(value: Dictionary) -> bool: return String(value.get("id", "")) == String(reward.get("id", ""))):
			world_pickups.append(reward)
		_add_effect("discover", Vector2(secret.get("gate_pos", player_pos)))
		_set_message("Your Awareness reveals a concealed passage through the thicket." if awareness_reveal else "Up close, the brush gives way to a concealed passage.")
		_apply_shortcut_world_state()
		return true
	return false

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
		var radius := float(feature.get("radius", 45.0))
		var bounds := Rect2(Vector2(feature["pos"]) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		if feature.has("from") and feature.has("to"):
			var start := Vector2(feature["from"])
			var finish := Vector2(feature["to"])
			var half_width := float(feature.get("width", 24.0)) * 0.5 + 70.0
			bounds = Rect2(start.min(finish) - Vector2.ONE * half_width, finish.max(start) - start.min(finish) + Vector2.ONE * half_width * 2.0)
		for cell in _spatial_cells_for_rect(bounds):
			if not _terrain_feature_buckets.has(cell): _terrain_feature_buckets[cell] = []
			_terrain_feature_buckets[cell].append(feature)

func nearby_terrain_features(position: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for cell in _spatial_cells_for_rect(Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
		for feature in Array(_terrain_feature_buckets.get(cell, [])):
			var key := "%s:%s:%s" % [feature.get("part_id", -1), feature.get("kind", ""), feature.get("pos", Vector2.ZERO)]
			if seen.has(key): continue
			seen[key] = true
			result.append(feature)
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
			var wall_rect := Rect2(wall)
			if not seen.has(wall_rect):
				seen[wall_rect] = true
				result.append(wall_rect)
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
	# Loaded regions preserve terrain and enemy state, but they are much larger
	# than the active combat neighbourhood. Simulating every resident in the
	# previous, current, and next locale made crossing a region boundary wake
	# several offscreen encounter groups at once.
	return int(enemy.get("hp", 0)) > 0 \
		and String(enemy.get("layer", current_layer)) == current_layer \
		and Vector2(enemy["pos"]).distance_to(player_pos) <= ACTIVE_ENEMY_RADIUS

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
	player_stamina = player_max_stamina
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_stamina_regen_delay = 0.0
	player_attack_readiness_remaining = 0.0
	potions = healing_capacity()
	dodge_cooldown = 0.0
	block_cooldown = 0.0
	endure_cooldown = 0.0
	skill_cooldown = 0.0
	rally_cooldown = 0.0
	advance_cooldown = 0.0
	main_ability_cooldown = 0.0
	subclass_ability_cooldown = 0.0
	stealth_remaining = 0.0
	stealth_cooldown_pending = false
	assassination_window_remaining = 0.0
	turnabout_remaining = 0.0
	aimed_enemy_id = -1
	aimed_remaining = 0.0
	player_condition_buildup.clear()
	player_conditions.clear()
	rally_remaining = 0.0
	rally_end_after_action = false
	rally_break_extension_used = false
	building_force_chain = 0
	player_posture = player_posture_max
	player_posture_recovery_delay = 0.0
	counterstep_remaining = 0.0
	strength_remaining = 0.0
	player_action = _idle_action()
	projectiles.clear()
	hazards.clear()
	effects.clear()

func choose_upgrade(choice: String) -> bool:
	var context := level_up_context()
	var parts := choice.split("|", false, 1)
	var track_id := String(parts[0])
	var choice_id := String(parts[1]) if parts.size() > 1 else ""
	if context.is_empty() or not available_level_up_options().has(track_id): return false
	var stage := next_track_stage(track_id)
	if stage.is_empty(): return false
	var choices: Array = stage.get("choices", [])
	if not choices.is_empty():
		var valid_choice := false
		for option_value in choices:
			if String(Dictionary(option_value).get("id", "")) == choice_id:
				valid_choice = true
				break
		if not valid_choice: return false
	elif not choice_id.is_empty():
		return false
	var cost := next_upgrade_cost()
	if context == "waystone" and secured_xp < cost: return false
	if context != "waystone" and carried_xp < cost: return false
	carried_xp = maxi(0, carried_xp - cost)
	if context == "waystone": secured_xp = maxi(0, secured_xp - cost)
	var stage_id := String(stage["id"])
	if not choice_id.is_empty(): track_choices[stage_id] = choice_id
	track_ranks[track_id] = int(track_ranks.get(track_id, 0)) + 1
	_apply_character_stage(stage_id, choice_id)
	upgrades.append("%s:%s%s" % [track_id, stage_id, ":%s" % choice_id if not choice_id.is_empty() else ""])
	upgrade_count += 1
	upgrade_ranks[track_id] = int(track_ranks[track_id])
	upgrade_pending = false
	upgrade_choices.clear()
	upgrade_context = ""
	_set_message("Upgrade gained: %s." % String(stage.get("label", track_id.capitalize())))
	changed.emit()
	return true

func set_block_hold(held: bool) -> void:
	if String(player_action.get("kind", "")) != "block": return
	player_action["guard_held"] = held
	if not held:
		player_action["duration"] = float(player_action.get("elapsed", 0.0)) + 0.10
		player_action["active_end"] = float(player_action.get("elapsed", 0.0))

func set_block_direction(direction: Vector2) -> void:
	if String(player_action.get("kind", "")) != "block" or direction.length_squared() < 0.01: return
	var desired := direction.normalized()
	var maximum_turn := deg_to_rad(4.0 + 1.25 * float(player_attributes.get("speed", 5)))
	var angle := clampf(player_facing.angle_to(desired), -maximum_turn, maximum_turn)
	player_facing = player_facing.rotated(angle).normalized()
	player_action["direction"] = player_facing

func leave_upgrade_menu() -> bool:
	if not upgrade_pending or upgrade_context != "waystone": return false
	upgrade_pending = false
	upgrade_choices.clear()
	upgrade_context = ""
	_set_message("You leave the XP unspent.")
	changed.emit()
	return true

func next_upgrade_cost() -> int:
	return 4 * (character_level() + 1) - 2

func upgrade_name(id: String) -> String:
	var track := CombatCatalogScript.character_track(id)
	var stage := next_track_stage(id)
	return "%s · %s" % [String(track.get("label", "Track")), String(stage.get("label", "Complete"))]

func upgrade_description(id: String) -> String:
	return String(next_track_stage(id).get("description", ""))

func _roll_upgrade_choices(context: String = "area_exit") -> void:
	var pool := available_level_up_options(context)
	if pool.is_empty(): return
	# Compatibility only: saves created on the old three-choice screen are
	# normalized on load, and live play now selects directly from the Sheet.
	upgrade_choices.assign(pool.slice(0, mini(3, pool.size())))
	upgrade_pending = false
	upgrade_context = ""

func available_level_up_options(context: String = "") -> Array[String]:
	if context.is_empty(): context = level_up_context()
	if context.is_empty(): return []
	var pool: Array[String] = []
	var target_level := character_level() + 1
	for track_value in character_track_order():
		var track_id := String(track_value)
		if track_id == "adopted": continue
		var stage := next_track_stage(track_id)
		if not stage.is_empty() and int(stage.get("gate", 999)) <= target_level: pool.append(track_id)
	return pool

func track_total(track_id: String) -> int:
	return int(track_ranks.get(track_id, 0))

func next_track_stage(track_id: String) -> Dictionary:
	return CombatCatalogScript.character_stage(track_id, int(track_ranks.get(track_id, 0)))

func _apply_character_stage(stage_id: String, choice_id: String) -> void:
	match stage_id:
		"sword_art":
			player_weapon_art_library = [choice_id]
			player_equipped_weapon_art = choice_id
		"steadfast_1", "steadfast_2", "steadfast_3", "steadfast_4":
			if choice_id == "toughness":
				_increase_max_health(15)
				player_attributes["resolve"] = int(player_attributes.get("resolve", 7)) + 1
				_refresh_player_posture_capacity(false)
			elif choice_id == "vigilance":
				_increase_max_stamina(10.0)
				player_attributes["awareness"] = int(player_attributes.get("awareness", 5)) + 1
		"warriors_physique":
			_increase_max_health(20)
			player_attributes["speed"] = int(player_attributes.get("speed", 5)) + 1
		"vanguard_bearing":
			player_attributes["resolve"] = int(player_attributes.get("resolve", 7)) + 2
			_refresh_player_posture_capacity(false)
		"knife_art":
			player_weapon_art_library = [choice_id]
			player_equipped_weapon_art = choice_id
			if choice_id == "knife_twin_fang":
				player_weapon_frame = "twin_knives"
				equipment_slots["main_hand"] = "Twin Knives"
		"bow_art":
			player_weapon_art_library = [choice_id]
			player_equipped_weapon_art = choice_id
		"finesse_1", "finesse_2", "finesse_3", "finesse_4":
			if choice_id == "fleetness":
				player_attributes["speed"] = int(player_attributes.get("speed", 7)) + 1
				_increase_max_stamina(10.0)
			elif choice_id == "subtlety":
				player_attributes["stealth"] = int(player_attributes.get("stealth", 7)) + 1
				_increase_max_health(5)
		"patient_1", "patient_2", "patient_3", "patient_4":
			if choice_id == "observation":
				player_attributes["awareness"] = int(player_attributes.get("awareness", 8)) + 1
				_increase_max_stamina(10.0)
			elif choice_id == "composure":
				player_attributes["resolve"] = int(player_attributes.get("resolve", 4)) + 1
				_refresh_player_posture_capacity(false)
				_increase_max_health(5)
		"rogue_training":
			if choice_id == "shadow_training":
				player_attributes["speed"] = int(player_attributes.get("speed", 6)) + 1
				player_attributes["stealth"] = int(player_attributes.get("stealth", 7)) + 2
			elif choice_id == "fleet_training":
				player_attributes["speed"] = int(player_attributes.get("speed", 6)) + 2
		"keen_eye":
			player_attributes["awareness"] = int(player_attributes.get("awareness", 8)) + 2
		"far_sight":
			player_properties["vision_range"] = float(player_properties.get("vision_range", SIGHT_RANGE)) * 1.25
			_visibility_anchor_cell = Vector2i(-999999, -999999)

func _increase_max_health(amount: int) -> void:
	player_max_hp += amount
	player_hp += amount
	player_attributes["health"] = player_max_hp

func can_swap_weapon_art() -> bool:
	return false

func equip_weapon_art(art_id: String) -> bool:
	if not can_swap_weapon_art() or not player_weapon_art_library.has(art_id): return false
	player_equipped_weapon_art = art_id
	_set_message("Equipped Sword Art: %s." % String(CombatCatalogScript.weapon_art(art_id).get("label", art_id)))
	changed.emit()
	return true

func character_sheet_data() -> Dictionary:
	var tracks: Array[Dictionary] = []
	for track_value in character_track_order():
		var track_id := String(track_value)
		var definition := CombatCatalogScript.character_track(track_id)
		var rank := int(track_ranks.get(track_id, 0))
		var stages: Array[Dictionary] = []
		for stage_index in range(Array(definition.get("stages", [])).size()):
			var stage := CombatCatalogScript.character_stage(track_id, stage_index)
			stage["completed"] = stage_index < rank
			stage["current"] = stage_index == rank
			stage["choice"] = String(track_choices.get(String(stage["id"]), ""))
			stages.append(stage)
		tracks.append({"id": track_id, "label": definition["label"], "description": definition["description"], "rank": rank, "stages": stages, "next_stage": next_track_stage(track_id)})
	var sheet_attributes := player_attributes.duplicate(true)
	sheet_attributes["health"] = player_max_hp
	sheet_attributes["stamina"] = roundi(player_max_stamina)
	return {
		"name": CombatCatalogScript.loadout_name(loadout_id),
		"attributes": sheet_attributes,
		"current_stamina": player_stamina,
		"maximum_stamina": player_max_stamina,
		"equipment": equipment_slots.duplicate(true),
		"healing_charges": potions,
		"healing_capacity": healing_capacity(),
		"consumable_slots": consumable_slots.duplicate(true),
		"tracks": tracks,
		"weapon_frame": player_weapon_frame,
		"defense": defense_id,
		"known_arts": player_weapon_art_library.duplicate(),
		"equipped_art": player_equipped_weapon_art,
		"upgrade_count": upgrade_count,
		"character_level": character_level(),
		"level_up_context": level_up_context(),
		"level_up_options": available_level_up_options(),
		"level_up_cost": next_upgrade_cost(),
		"level_up_xp": secured_xp if mode_id == ModeRulesScript.CAMPAIGN_LAB else carried_xp,
	}

func _action(kind: String, duration: float, direction: Vector2) -> Dictionary:
	var result := _idle_action()
	result["kind"] = kind
	result["duration"] = duration
	result["direction"] = direction
	result["started_at"] = simulation_time
	return result

func _annotate_player_action(ability_id: String) -> void:
	player_action["actor_kind"] = "player"
	player_action["weapon_frame"] = player_weapon_frame
	player_action["ability_id"] = ability_id
	player_action["defense_id"] = defense_id
	if mode_id == ModeRulesScript.COMBAT_SURVEY and ability_id != "bow_draw":
		survey_action_counts[ability_id] = int(survey_action_counts.get(ability_id, 0)) + 1

func _rally_action_capacity() -> float:
	if rally_remaining <= 0.0: return 0.0
	if has_track_rank("warrior", 5): return 7.0
	return 5.0 if has_track_rank("warrior", 3) else 4.0

func _apply_action_poise(action: Dictionary, native_capacity: float = 0.0) -> void:
	var capacity := maxf(native_capacity, _rally_action_capacity())
	if has_track_rank("vanguard", 3) and String(action.get("kind", "")) in ["attack", "combo", "sweep", "advance"]:
		capacity = maxf(capacity, 3.0)
	if capacity > 0.0:
		capacity += floorf(float(player_attributes.get("resolve", 7)) / 4.0)
	action["guard_capacity"] = capacity
	action["guard_remaining"] = capacity

func _apply_counterstep_to_action(action: Dictionary) -> void:
	if counterstep_remaining <= 0.0: return
	action["startup"] = float(action.get("startup", 0.30)) * 0.80
	action["posture_damage"] = float(action.get("posture_damage", 0.0)) + 1.0
	counterstep_remaining = 0.0

func _apply_counterstep_to_combo(action: Dictionary) -> void:
	if counterstep_remaining <= 0.0: return
	var phases: Array = action.get("phases", [])
	if not phases.is_empty():
		var opener := Dictionary(phases[0])
		opener["startup"] = float(opener["startup"]) * 0.80
		opener["posture"] = float(opener["posture"]) + 1.0
		phases[0] = opener
		action["phases"] = phases
	counterstep_remaining = 0.0

func _rally_damage_bonus() -> int:
	return 1 if rally_remaining > 0.0 and has_track_rank("warrior", 3) else 0

func _rally_posture_bonus() -> float:
	if rally_remaining <= 0.0: return 0.0
	return 2.0 if has_track_rank("warrior", 3) else 1.0

func _building_force_bonus() -> int:
	if not has_track_rank("warrior", 2): return 0
	if rally_remaining > 0.0 and has_track_rank("warrior", 5): return 2
	return clampi(building_force_chain, 0, 2)

func _reset_building_force() -> void:
	building_force_chain = 0

func _reset_building_force_if_unavailable() -> void:
	if not has_track_rank("warrior", 2): building_force_chain = 0

func _register_building_force_hit() -> void:
	if not has_track_rank("warrior", 2): return
	if rally_remaining > 0.0 and has_track_rank("warrior", 5):
		building_force_chain = 2
	elif building_force_chain >= 2:
		building_force_chain = 0
	else:
		building_force_chain += 1

func _finish_rally(begin_cooldown: bool = true) -> void:
	rally_remaining = 0.0
	rally_end_after_action = false
	rally_break_extension_used = false
	building_force_chain = 0
	if begin_cooldown:
		rally_cooldown = 12.0

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
	_player_reaction_completed_this_tick = false
	var player_dt := dt * _player_personal_tempo()
	dodge_cooldown = maxf(0.0, dodge_cooldown - player_dt)
	block_cooldown = maxf(0.0, block_cooldown - player_dt)
	endure_cooldown = maxf(0.0, endure_cooldown - player_dt)
	skill_cooldown = maxf(0.0, skill_cooldown - player_dt)
	rally_cooldown = maxf(0.0, rally_cooldown - player_dt)
	advance_cooldown = maxf(0.0, advance_cooldown - player_dt)
	main_ability_cooldown = maxf(0.0, main_ability_cooldown - player_dt)
	subclass_ability_cooldown = maxf(0.0, subclass_ability_cooldown - player_dt)
	weapon_sequence_cooldown = maxf(0.0, weapon_sequence_cooldown - player_dt)
	if uses_stamina_rules() and player_attack_readiness_remaining > 0.0001:
		attack_readiness_active_time_total += dt
		player_attack_readiness_remaining = maxf(0.0, player_attack_readiness_remaining - player_dt)
	elif not uses_stamina_rules():
		player_attack_readiness_remaining = 0.0
	counterstep_remaining = maxf(0.0, counterstep_remaining - dt)
	turnabout_remaining = maxf(0.0, turnabout_remaining - dt)
	assassination_window_remaining = maxf(0.0, assassination_window_remaining - dt)
	aimed_remaining = maxf(0.0, aimed_remaining - dt)
	if aimed_remaining <= 0.0: aimed_enemy_id = -1
	if stealth_remaining > 0.0:
		stealth_remaining = maxf(0.0, stealth_remaining - dt)
		if stealth_remaining <= 0.0 and stealth_cooldown_pending:
			stealth_cooldown_pending = false
			main_ability_cooldown = 12.0
	if player_posture_recovery_delay > 0.0:
		player_posture_recovery_delay = maxf(0.0, player_posture_recovery_delay - player_dt)
	if player_posture < player_posture_max and player_posture_recovery_delay <= 0.0 and String(player_action.get("kind", "")) not in ["hit_reaction", "stagger"]:
		player_posture = minf(player_posture_max, player_posture + player_dt * float(player_properties.get("posture_recovery", 1.8)))
	if rally_remaining > 0.0:
		rally_remaining = maxf(0.0, rally_remaining - dt)
		if rally_remaining <= 0.0:
			_finish_rally(true)
			_set_message("Rally fades. Its recovery begins.")
	strength_remaining = maxf(0.0, strength_remaining - dt)
	var player_action_kind := String(player_action.get("kind", "idle"))
	if uses_stamina_rules() and player_action_kind in STAMINA_REGEN_ACTIONS:
		_regenerate_stamina(dt)
	if uses_stamina_rules() and player_exhaustion_remaining > 0.0001:
		player_exhaustion_remaining = maxf(0.0, player_exhaustion_remaining - dt)
		winded_time_total += dt
		if player_action_kind == "move": exhaustion_move_time_total += dt
		elif player_action_kind == "wait": exhaustion_wait_time_total += dt
		else: exhaustion_other_time_total += dt
		if player_exhaustion_remaining <= 0.0001:
			_set_message("Your breath steadies. Physical actions are ready.")
	_build_enemy_spatial_index()
	_update_effects(dt)
	_update_conditions(dt)
	_update_player(player_dt)
	_update_exploration()
	_try_recover_xp()
	_update_enemies(dt, _simulation_tick_index % 2 == 0)
	_update_projectiles(dt)
	_update_hazards(dt)
	_remove_dead_enemies()

func _condition_threshold(condition_id: String, resistance: int, specific_multiplier: float = 1.0) -> float:
	var base := float({"laceration": 18.0, "poison": 20.0, "sleep": 18.0, "frost": 16.0, "burning": 14.0, "frenzy": 20.0}.get(condition_id, 20.0))
	return base * (1.0 + 0.08 * float(maxi(0, resistance))) * maxf(0.1, specific_multiplier)

func apply_player_condition_buildup(condition_id: String, amount: float) -> bool:
	if amount <= 0.0: return false
	var immunity := Array(player_properties.get("condition_immunities", []))
	if immunity.has(condition_id): return false
	var current := float(player_condition_buildup.get(condition_id, 0.0)) + amount
	var threshold := _condition_threshold(condition_id, int(player_attributes.get("resistance", 5)))
	if current < threshold:
		player_condition_buildup[condition_id] = current
		return false
	player_condition_buildup[condition_id] = 0.0
	_trigger_player_condition(condition_id)
	return true

func _trigger_player_condition(condition_id: String) -> void:
	match condition_id:
		"laceration":
			player_hp = maxi(0, player_hp - 15)
			survey_last_damage_source = "laceration"
		"poison": player_conditions[condition_id] = 8.0
		"sleep":
			player_conditions[condition_id] = 3.0
			player_action = _action("sleep", 3.0, Vector2.ZERO)
		"frost": player_conditions[condition_id] = 6.0
		"burning": player_conditions[condition_id] = 4.0
		"frenzy": player_conditions[condition_id] = 5.0
	_add_effect("condition", player_pos, 0, {"condition": condition_id})
	_set_message("%s takes hold." % condition_id.capitalize())
	if player_hp <= 0: _begin_death()

func apply_enemy_condition_buildup(enemy: Dictionary, condition_id: String, amount: float) -> bool:
	if amount <= 0.0: return false
	var properties := Dictionary(enemy.get("properties", {}))
	if Array(properties.get("condition_immunities", [])).has(condition_id): return false
	var buildup := Dictionary(enemy.get("condition_buildup", {}))
	var current := float(buildup.get(condition_id, 0.0)) + amount
	var threshold := _condition_threshold(condition_id, int(Dictionary(enemy.get("attributes", {})).get("resistance", 5)), float(Dictionary(properties.get("condition_multipliers", {})).get(condition_id, 1.0)))
	if current < threshold:
		buildup[condition_id] = current
		enemy["condition_buildup"] = buildup
		return false
	buildup[condition_id] = 0.0
	enemy["condition_buildup"] = buildup
	var conditions := Dictionary(enemy.get("conditions", {}))
	if condition_id == "laceration": enemy["hp"] = int(enemy["hp"]) - 15
	else: conditions[condition_id] = {"poison": 8.0, "sleep": 3.0, "frost": 6.0, "burning": 4.0, "frenzy": 5.0}.get(condition_id, 4.0)
	enemy["conditions"] = conditions
	return true

func _update_conditions(dt: float) -> void:
	var ongoing_tick := false
	for condition_id in player_condition_buildup.keys():
		player_condition_buildup[condition_id] = maxf(0.0, float(player_condition_buildup[condition_id]) - dt * 0.75)
	for condition_id in player_conditions.keys():
		player_conditions[condition_id] = maxf(0.0, float(player_conditions[condition_id]) - dt)
		if float(player_conditions[condition_id]) <= 0.0: player_conditions.erase(condition_id)
	_condition_tick_accumulator += dt
	if _condition_tick_accumulator >= 1.0:
		_condition_tick_accumulator -= 1.0
		ongoing_tick = true
		if float(player_conditions.get("poison", 0.0)) > 0.0:
			player_hp = maxi(0, player_hp - 3)
			survey_last_damage_source = "poison"
		if float(player_conditions.get("burning", 0.0)) > 0.0:
			player_hp = maxi(0, player_hp - 6)
			survey_last_damage_source = "burning"
		if player_hp <= 0: _begin_death()
	_refresh_active_enemy_cache()
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy: Dictionary = enemies[index]
		if Dictionary(enemy.get("condition_buildup", {})).is_empty() and Dictionary(enemy.get("conditions", {})).is_empty(): continue
		var buildup := Dictionary(enemy.get("condition_buildup", {}))
		for condition_id in buildup.keys(): buildup[condition_id] = maxf(0.0, float(buildup[condition_id]) - dt * 0.75)
		enemy["condition_buildup"] = buildup
		var conditions := Dictionary(enemy.get("conditions", {}))
		for condition_id in conditions.keys():
			conditions[condition_id] = maxf(0.0, float(conditions[condition_id]) - dt)
			if float(conditions[condition_id]) <= 0.0: conditions.erase(condition_id)
		enemy["conditions"] = conditions
		if ongoing_tick:
			if float(conditions.get("poison", 0.0)) > 0.0: enemy["hp"] = int(enemy["hp"]) - 3
			if float(conditions.get("burning", 0.0)) > 0.0: enemy["hp"] = int(enemy["hp"]) - 6

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
			if elapsed >= float(player_action.get("move_start", 0.08)) and elapsed <= float(player_action.get("move_end", 0.38)):
				player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, PLAYER_RADIUS, 0)
			if uses_stamina_rules():
				var vulnerable_start := float(player_action.get("vulnerable_recovery_start", player_action.get("evade_end", 0.38)))
				var previous_elapsed := elapsed - dt
				var vulnerable_overlap := maxf(0.0, minf(elapsed, float(player_action["duration"])) - maxf(previous_elapsed, vulnerable_start))
				dodge_vulnerable_time_total += vulnerable_overlap
		"attack":
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
				_resolve_player_attack_tick(elapsed)
		"combo", "art_combo":
			_update_player_combo(elapsed)
			elapsed = float(player_action.get("elapsed", elapsed))
		"twin_fang":
			if elapsed >= float(player_action.get("move_start", 0.05)) and elapsed <= float(player_action.get("move_end", 0.24)):
				player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, PLAYER_RADIUS, 0)
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				_resolve_twin_fang_tick(elapsed)
		"sweep":
			if player_action.has("move_start") and elapsed >= float(player_action.get("move_start", 0.0)) and elapsed <= float(player_action.get("move_end", 0.0)):
				player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action.get("speed", 0.0)) * dt, PLAYER_RADIUS, 0)
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
				_resolve_player_attack_tick(elapsed)
		"rally":
			if elapsed >= float(player_action.get("effect_start", 0.18)) and not bool(player_action.get("rally_started", false)):
				player_action["rally_started"] = true
				rally_remaining = 5.5 if has_track_rank("warrior", 3) else 4.5
				rally_end_after_action = false
				rally_break_extension_used = false
				_apply_action_poise(player_action)
				_add_effect("rally", player_pos)
				_set_message("Rally takes hold.")
		"advance":
			if elapsed >= float(player_action["move_start"]) and elapsed <= float(player_action["move_end"]):
				player_pos = _move_player_advance(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, float(player_action.get("pass_mass", -1.0)))
			if elapsed >= float(player_action["impact_start"]) and elapsed <= float(player_action["impact_end"]):
				_resolve_advance_impact()
		"potion":
			if elapsed >= 0.28 and not bool(player_action["effect_done"]):
				player_action["effect_done"] = true
				player_hp = mini(player_max_hp, player_hp + 25 + int(track_property_ranks.get("fieldcraft_restoration", 0)) * 5)
				_set_message("Warmth returns to your limbs.")
		"consumable":
			if elapsed >= float(player_action.get("startup", 0.24)) and not bool(player_action["effect_done"]):
				player_action["effect_done"] = true
				_apply_consumable_effect(String(player_action.get("item_id", "")), Vector2(player_action.get("direction", player_facing)))
		"bow_draw":
			_update_bow_soft_aim(dt)
			var previous_draw := float(player_action.get("draw_ratio", 0.0))
			player_action["draw_ratio"] = clampf(elapsed / 0.90, 0.0, 1.0)
			if previous_draw < 0.995 and float(player_action["draw_ratio"]) >= 0.995:
				_add_effect("full_draw", player_pos)
				_set_message("The Bow reaches Full Draw.")
		"bow_release":
			if elapsed >= float(player_action.get("startup", 0.06)) and not bool(player_action.get("shot_spawned", false)):
				player_action["shot_spawned"] = true
				_spawn_bow_projectile(player_action)
		"bow_art":
			if elapsed >= float(player_action.get("startup", 0.28)) and not bool(player_action.get("shot_spawned", false)):
				player_action["shot_spawned"] = true
				_spawn_bow_art_projectiles(bool(player_action.get("piercing", false)), Vector2(player_action.get("direction", player_facing)))
		"stealth":
			if elapsed >= float(player_action.get("effect_start", 0.24)) and not bool(player_action.get("effect_done", false)):
				player_action["effect_done"] = true
				stealth_remaining = 5.0
				stealth_cooldown_pending = true
				if has_track_rank("rogue", 4):
					for enemy in _nearby_enemies(player_pos, ACTIVE_ENEMY_RADIUS):
						if not _enemy_on_current_layer(enemy) or String(enemy.get("awareness", "idle")) != "alerted": continue
						enemy["awareness"] = "suspicious"
						enemy["last_known_player"] = player_pos
						enemy["suspicious_remaining"] = maxf(float(enemy.get("suspicious_remaining", 0.0)), 2.6)
				_add_effect("stealth", player_pos)
				_set_message("You disappear from direct perception.")
		"vault":
			if elapsed >= float(player_action.get("move_start", 0.0)) and elapsed <= float(player_action.get("move_end", 0.34)):
				var vault_origin := player_pos
				player_pos = _move_vault_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt)
				_resolve_vault_crossings(vault_origin, player_pos)
		"take_aim":
			if elapsed >= float(player_action.get("effect_start", 0.50)) and not bool(player_action.get("effect_done", false)):
				player_action["effect_done"] = true
				aimed_enemy_id = int(player_action.get("target_id", -1))
				aimed_remaining = 6.0
				_set_message("The target is Aimed.")
	if elapsed + 0.00001 >= float(player_action["duration"]):
		if kind in ["attack", "sweep", "combo", "art_combo", "twin_fang"]: _survey_finalize_strike_probe("complete")
		if kind in ["attack", "sweep", "combo", "art_combo"] and Array(player_action["hit_ids"]).is_empty():
			if mode_id == ModeRulesScript.COMBAT_SURVEY: survey_empty_melee_contacts += 1
			_set_message("Your cut finds only air.")
			if kind in ["attack", "combo"]: _reset_building_force()
		elif kind == "block" and not bool(player_action["effect_done"]):
			_set_message("You lower the guard without contact.")
		elif kind == "endure" and not bool(player_action["effect_done"]):
			_set_message("The Endure window passes without a hit.")
		var completed_kind := kind
		var completed_direction := Vector2(player_action.get("direction", player_facing))
		var continue_advance := completed_kind == "advance" and has_track_rank("vanguard", 2) and bool(player_action.get("continue_held", false))
		var completed_twin_sequence := completed_kind == "combo" and bool(player_action.get("knife_sequence", false)) and player_weapon_frame == "twin_knives" and int(player_action.get("committed_phase", 0)) >= int(player_action.get("combo_length", 6)) - 1
		if completed_twin_sequence:
			weapon_sequence_cooldown = 0.0 if uses_stamina_rules() else (0.55 if has_track_rank("knife", 5) else TWIN_KNIFE_SEQUENCE_RECOVERY)
			if not uses_stamina_rules(): _set_message("The full sequence leaves your knives recovering.")
		_break_player_combo()
		player_action = _idle_action()
		if completed_kind in ["stagger", "hit_reaction"]:
			_player_reaction_completed_this_tick = true
			if player_posture <= 0.0001:
				player_posture = player_posture_max
		if rally_end_after_action: _finish_rally(true)
		if player_overexertion_pending:
			if continue_advance: stamina_blocked_continuations += 1
			_begin_exhaustion()
		elif continue_advance:
			_begin_sword_combo(completed_direction, true, true)

func _move_player_advance(origin: Vector2, delta: Vector2, pass_mass: float) -> Vector2:
	if pass_mass < 0.0: return _move_actor(origin, delta, PLAYER_RADIUS, 0)
	var candidate := origin + delta
	if _position_blocked_static(candidate, PLAYER_RADIUS): return origin
	for enemy in _nearby_enemies(candidate, PLAYER_RADIUS + 90.0):
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		if candidate.distance_to(Vector2(enemy["pos"])) >= PLAYER_RADIUS + float(enemy["radius"]): continue
		var mass := float(Dictionary(enemy.get("properties", {})).get("mass", 1.0))
		if mass > pass_mass: return origin
	return candidate

func _position_blocked_static(position: Vector2, radius: float) -> bool:
	if not _inside_world(position, radius): return true
	for wall in _nearby_walls(position, radius + 8.0):
		if _circle_intersects_rect(position, radius, wall): return true
	return not _actor_footprint_on_floor(position, radius)

func _resolve_advance_impact() -> void:
	var hit_ids: Array = player_action.get("impact_ids", [])
	var max_targets := int(player_action.get("max_targets", 1))
	if hit_ids.size() >= max_targets: return
	var direction := Vector2(player_action["direction"]).normalized()
	var side := direction.rotated(PI * 0.5)
	var contacts: Array[Dictionary] = []
	for enemy in _nearby_enemies(player_pos, 125.0):
		if not _enemy_on_current_layer(enemy) or hit_ids.has(int(enemy["id"])): continue
		var offset := Vector2(enemy["pos"]) - player_pos
		var forward := offset.dot(direction)
		var lateral := absf(offset.dot(side))
		if forward < -8.0 or forward > 82.0 + float(enemy["radius"]): continue
		if lateral > 34.0 + float(enemy["radius"]): continue
		contacts.append({"enemy": enemy, "forward": forward})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["forward"]) < float(b["forward"]))
	for contact in contacts:
		if hit_ids.size() >= max_targets: break
		var enemy: Dictionary = contact["enemy"]
		hit_ids.append(int(enemy["id"]))
		var raw_damage := int(player_action.get("damage_min", 10)) + _rally_damage_bonus()
		var resolved := _resolve_player_physical_values(enemy, raw_damage, float(player_action["posture_damage"]) + _rally_posture_bonus(), player_action)
		var damage := int(resolved["damage"])
		enemy["hp"] = int(enemy["hp"]) - damage
		damage_dealt += damage
		var impact := Vector2(enemy["pos"]) - direction * float(enemy["radius"]) * 0.4
		var posture_broken := _apply_posture_damage(enemy, float(resolved["posture"]), impact)
		enemy["pos"] = _push_enemy(enemy, direction, 64.0 if posture_broken else float(player_action["push"]))
		_register_enemy_hit_awareness(enemy, resolved, player_action)
		_add_effect("hit", impact, damage, {"direction": direction})
		_handle_player_contact_aftermath(enemy, resolved)
	_set_message("Advance lands with a driving impact.")
	player_action["impact_ids"] = hit_ids

func _push_enemy(enemy: Dictionary, direction: Vector2, distance: float) -> Vector2:
	var result := Vector2(enemy["pos"])
	var radius := float(enemy["radius"])
	var enemy_id := int(enemy["id"])
	var steps := maxi(1, int(ceil(distance / 10.0)))
	var step := direction.normalized() * (distance / float(steps))
	for index in range(steps):
		var candidate := result + step
		if _position_blocked_static(candidate, radius): break
		var blocked := false
		for other in _nearby_enemies(candidate, radius + 80.0):
			if int(other.get("id", -1)) == enemy_id or int(other.get("hp", 0)) <= 0 or not _enemy_on_current_layer(other): continue
			if candidate.distance_to(Vector2(other["pos"])) < radius + float(other["radius"]):
				blocked = true
				break
		if blocked: break
		result = candidate
	return result

func _apply_consumable_effect(item_id: String, direction: Vector2) -> void:
	match item_id:
		"throwing_knife":
			_break_stealth_for_hostile_action()
			_spawn_player_projectile("throwing_knife", direction)
		"firebomb":
			_break_stealth_for_hostile_action()
			_spawn_player_projectile("firebomb", direction)
		"smoke_vial":
			for enemy in _nearby_enemies(player_pos, 360.0):
				if not _enemy_on_current_layer(enemy): continue
				enemy["smoked_remaining"] = 2.8
				enemy["awareness"] = "suspicious"
				enemy["suspicious_remaining"] = 2.8
				enemy["action"] = _idle_action()
			_add_effect("smoke", player_pos)
			_set_message("Smoke veils the immediate path.")

func _update_player_combo(elapsed: float) -> void:
	var phases: Array = player_action.get("phases", [])
	if phases.is_empty():
		player_action["duration"] = elapsed
		return
	var committed_phase := int(player_action.get("committed_phase", 0))
	while committed_phase < phases.size() - 1 and elapsed >= float(Dictionary(phases[committed_phase])["end"]):
		if not bool(player_action.get("continue_held", false)):
			player_action["duration"] = float(Dictionary(phases[committed_phase])["end"])
			return
		if not _can_commit_physical_action():
			stamina_blocked_continuations += 1
			player_action["duration"] = float(Dictionary(phases[committed_phase])["end"])
			return
		committed_phase += 1
		if not _spend_stamina(float(Dictionary(phases[committed_phase]).get("stamina_cost", 0.0))):
			stamina_blocked_continuations += 1
			player_action["duration"] = float(Dictionary(phases[committed_phase - 1])["end"])
			return
		player_action["committed_phase"] = committed_phase
		_arm_stamina_attack_readiness(float(Dictionary(phases[committed_phase])["active_end"]) - elapsed)
		if player_weapon_frame == "sword" and has_track_rank("swordsmanship", 2): _follow_the_opening(committed_phase)
		_set_message("The sequence flows into strike %d." % (committed_phase + 1))
	for index in range(phases.size()):
		var phase: Dictionary = phases[index]
		if elapsed > float(phase["end"]): continue
		if index > committed_phase:
			player_action["duration"] = float(Dictionary(phases[committed_phase])["end"])
			return
		player_action["technique_id"] = String(phase["technique"])
		player_action["startup"] = float(phase["startup"])
		player_action["active_end"] = float(phase["active_end"])
		player_action["reach"] = float(phase["reach"])
		player_action["damage_min"] = int(phase["damage_min"])
		player_action["damage_max"] = int(phase["damage_max"])
		player_action["posture_damage"] = float(phase["posture"])
		if int(player_action.get("phase_index", -1)) != index:
			if int(player_action.get("phase_index", -1)) >= 0: _survey_finalize_strike_probe("phase_complete")
			if int(player_action.get("phase_index", -1)) >= 0 and Array(player_action.get("hit_ids", [])).is_empty():
				if mode_id == ModeRulesScript.COMBAT_SURVEY: survey_empty_melee_contacts += 1
				_reset_building_force()
				if bool(player_action.get("knife_sequence", false)): player_action["knife_contact_chain"] = 0
			player_action["phase_index"] = index
			player_action["hit_done"] = false
			player_action["hit_ids"] = []
			player_action["building_force_registered"] = false
			player_action["building_force_bonus"] = _building_force_bonus()
		if elapsed >= float(phase["startup"]) and elapsed <= float(phase["active_end"]):
			if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
			_resolve_player_attack_tick(elapsed)
		return

func _break_player_combo() -> void:
	# Combos are now one continuous action, so there is no between-action chain
	# state to preserve. Keeping this boundary makes interruption call sites clear.
	pass

func _follow_the_opening(phase_index: int) -> void:
	var phases: Array = player_action.get("phases", [])
	if phase_index < 0 or phase_index >= phases.size(): return
	var phase := Dictionary(phases[phase_index])
	var reach := float(phase.get("reach", 130.0))
	var test_action := {
		"technique_id": String(phase.get("technique", "diagonal_cut")),
		"elapsed": 0.5,
		"startup": 0.0,
		"active_end": 1.0,
		"duration": 1.0,
		"reach": reach,
	}
	var current_sample := AttackGeometryScript.pose(test_action, player_pos, player_facing, _nearby_walls(player_pos, reach + 90.0))
	for existing in _nearby_enemies(player_pos, reach + 120.0):
		if _enemy_on_current_layer(existing) and enemy_visible_to_player(existing) and AttackGeometryScript.hits_circle(current_sample, Vector2(existing["pos"]), float(existing.get("radius", ENEMY_RADIUS))):
			return
	var best_direction := Vector2.ZERO
	var best_angle := INF
	for enemy in _nearby_enemies(player_pos, reach + 120.0):
		if not _enemy_on_current_layer(enemy) or not enemy_visible_to_player(enemy): continue
		var predicted := Vector2(enemy["pos"])
		var enemy_action: Dictionary = enemy.get("action", {})
		var enemy_kind := String(enemy_action.get("kind", "idle"))
		if enemy_kind in ["move", "evade", "dodge_strike", "charge", "pounce_combo"]:
			var remaining := maxf(0.0, float(enemy_action.get("duration", 0.0)) - float(enemy_action.get("elapsed", 0.0)))
			var sample_time := minf(remaining, maxf(0.0, float(phase.get("startup", 0.0)) - float(player_action.get("elapsed", 0.0))))
			var speed := float(enemy_action.get("speed", _enemy_move_speed(enemy)))
			predicted += Vector2(enemy_action.get("direction", Vector2.ZERO)).normalized() * speed * sample_time
		var offset := predicted - player_pos
		if offset.length() > reach + float(enemy.get("radius", ENEMY_RADIUS)): continue
		var angle := absf(player_facing.angle_to(offset.normalized()))
		if angle <= deg_to_rad(45.0) and angle < best_angle:
			best_angle = angle
			best_direction = offset.normalized()
	if best_direction.length_squared() > 0.001:
		player_facing = best_direction
		player_action["direction"] = best_direction

func _resolve_twin_fang_tick(elapsed: float) -> void:
	if bool(player_action.get("contact_done", false)): return
	# Resolve after the short lunge has carried the actor into the crossing point.
	# Both blades are still sampled on this exact simulation tick.
	if elapsed < 0.245: return
	player_action["contact_done"] = true
	if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
	var contacts_by_id: Dictionary = {}
	var pending_awareness: Array[Dictionary] = []
	for technique_id in ["knife_cut_in", "knife_cut_out"]:
		var sampled_action := player_action.duplicate()
		sampled_action["technique_id"] = technique_id
		sampled_action["elapsed"] = elapsed
		var sample := AttackGeometryScript.pose(sampled_action, player_pos, player_facing, _nearby_walls(player_pos, float(player_action.get("reach", 104.0)) + 70.0))
		_survey_update_strike_probe(sample, elapsed)
		var first_contact: Dictionary = {}
		for enemy in _nearby_enemies(player_pos, float(player_action.get("reach", 104.0)) + 100.0):
			if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
			if not AttackGeometryScript.hits_circle(sample, Vector2(enemy["pos"]), float(enemy["radius"])): continue
			var order := AttackGeometryScript.contact_order(sample, Vector2(enemy["pos"]))
			if first_contact.is_empty() or order < float(first_contact["order"]):
				first_contact = {"enemy": enemy, "order": order, "point": AttackGeometryScript.contact_point(sample, Vector2(enemy["pos"]))}
		if not first_contact.is_empty():
			var enemy: Dictionary = first_contact["enemy"]
			var enemy_id := int(enemy["id"])
			var contact := Dictionary(contacts_by_id.get(enemy_id, {"enemy": enemy, "blades": 0, "point": Vector2.ZERO}))
			contact["blades"] = int(contact["blades"]) + 1
			contact["point"] = Vector2(contact["point"]) + Vector2(first_contact["point"])
			contacts_by_id[enemy_id] = contact
	for enemy_id in contacts_by_id:
		var contact := Dictionary(contacts_by_id[enemy_id])
		var enemy: Dictionary = contact["enemy"]
		var blade_count := int(contact["blades"])
		var hit_point := Vector2(contact["point"]) / float(blade_count)
		var awareness_before := String(enemy.get("awareness", "idle"))
		var action_before := Dictionary(enemy.get("action", _idle_action())).duplicate(true)
		var per_blade_damage := int(player_action.get("damage_per_blade", 8)) + (1 if has_track_rank("knife", 2) else 0)
		var resolved := _resolve_player_physical_values(enemy, per_blade_damage * blade_count, float(player_action.get("posture_per_blade", 2.0)) * float(blade_count), player_action)
		var damage := int(resolved["damage"])
		var posture := float(resolved["posture"])
		enemy["hp"] = int(enemy["hp"]) - damage
		damage_dealt += damage
		var posture_broken := _apply_posture_damage(enemy, posture, hit_point)
		var reaction_applied := false
		if not posture_broken: reaction_applied = _apply_enemy_hit_reaction(enemy, posture, awareness_before, action_before, hit_point, player_action)
		pending_awareness.append({"enemy": enemy, "result": resolved})
		for blade in range(blade_count):
			var blade_offset := player_facing.rotated(PI * 0.5) * (float(blade) - 0.5 * float(blade_count - 1)) * 8.0
			_add_effect("hit", hit_point + blade_offset, damage if blade == 0 else 0, {"direction": (Vector2(enemy["pos"]) - hit_point).normalized(), "interrupted": reaction_applied})
		_handle_player_contact_aftermath(enemy, resolved)
		var hit_ids: Array = player_action["hit_ids"]
		hit_ids.append(int(enemy_id))
		player_action["hit_ids"] = hit_ids
		_survey_mark_strike_resolution(enemy, "hit")
	for pending in pending_awareness:
		_register_enemy_hit_awareness(Dictionary(pending["enemy"]), Dictionary(pending["result"]), player_action)
	if contacts_by_id.is_empty(): _set_message("Twin Fang closes on empty air.")
	else: _set_message("Both blades land in the same instant.")

func _player_basic_attack_definition(_direction: Vector2) -> Dictionary:
	# A direct tap or ×1 command always uses the compact opener. The varied
	# three-form chain belongs to request_combo(), where it is one uninterrupted
	# commitment and cannot be resumed after time freezes.
	if player_weapon_frame != "sword":
		return {"step": 0, "duration": player_attack_duration, "startup": player_attack_startup, "active_end": player_attack_active_end, "reach": player_attack_reach, "damage_min": player_damage_min, "damage_max": player_damage_max, "posture": player_attack_posture, "technique": player_attack_technique}
	var result := {"duration": 1.06, "startup": 0.30, "active_end": 0.41, "reach": 104.0, "damage_min": 10, "damage_max": 10, "posture": 1.8, "technique": "opening_cut"}
	if has_track_rank("swordsmanship", 3):
		result["damage_min"] = int(result["damage_min"]) + 1
		result["damage_max"] = int(result["damage_min"])
		result["posture"] = float(result["posture"]) + 0.5
	if has_track_rank("swordsmanship", 5): result["duration"] = 0.97
	result["step"] = 0
	return result

func _survey_update_strike_probe(sample: Dictionary, elapsed: float) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY or not bool(sample.get("active", false)): return
	var technique_id := String(sample.get("technique_id", player_action.get("technique_id", "attack")))
	var phase_index := int(player_action.get("phase_index", 0))
	var probe: Dictionary = Dictionary(player_action.get("survey_strike_probe", {}))
	if probe.is_empty() or String(probe.get("technique_id", "")) != technique_id or int(probe.get("phase_index", -999)) != phase_index:
		if not probe.is_empty(): _survey_finalize_strike_probe("phase_changed")
		probe = {
			"index": survey_strike_diagnostics.size() + 1,
			"room_time": simulation_time - float(survey_room_entry.get("time", simulation_time)),
			"action": String(player_action.get("ability_id", player_action.get("kind", "attack"))),
			"phase_index": phase_index,
			"phase": phase_index + 1,
			"technique_id": technique_id,
			"technique": AttackGeometryScript.label(technique_id),
			"reach": float(player_action.get("reach", player_attack_reach)),
			"view": survey_current_view_mode,
			"result": "miss",
			"targets": [],
			"closest_clearance": INF,
			"shape": String(sample.get("shape", "unknown")),
		}
		if String(sample.get("shape", "")) == "sector":
			probe.merge({"inner_radius": float(sample.get("inner_radius", 0.0)), "outer_radius": float(sample.get("outer_radius", 0.0)), "arc_degrees": rad_to_deg(float(sample.get("end_angle", 0.0)) - float(sample.get("start_angle", 0.0)))}, true)
		elif String(sample.get("shape", "")) == "segment":
			probe.merge({"footprint_length": Vector2(sample.get("start", player_pos)).distance_to(Vector2(sample.get("end", player_pos))), "footprint_radius": float(sample.get("radius", 0.0))}, true)
		elif String(sample.get("shape", "")) == "circle":
			probe["footprint_radius"] = float(sample.get("radius", 0.0))
	var direction := player_facing.normalized() if player_facing.length_squared() > 0.001 else Vector2.UP
	var side := direction.rotated(PI * 0.5)
	for enemy in _nearby_enemies(player_pos, float(player_action.get("reach", player_attack_reach)) + 260.0):
		if not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		var enemy_pos := Vector2(enemy["pos"])
		var clearance := AttackGeometryScript.clearance_to_circle(sample, enemy_pos, float(enemy.get("radius", ENEMY_RADIUS)))
		if clearance >= float(probe.get("closest_clearance", INF)): continue
		var relative := enemy_pos - player_pos
		var enemy_action := Dictionary(enemy.get("action", {}))
		probe.merge({
			"closest_clearance": clearance,
			"closest_enemy_id": int(enemy.get("id", -1)),
			"closest_enemy": String(enemy.get("kind", "unknown")),
			"center_distance": relative.length(),
			"edge_distance": maxf(0.0, relative.length() - float(enemy.get("radius", ENEMY_RADIUS)) - PLAYER_RADIUS),
			"forward": relative.dot(direction),
			"lateral": relative.dot(side),
			"player_x": player_pos.x,
			"player_y": player_pos.y,
			"enemy_x": enemy_pos.x,
			"enemy_y": enemy_pos.y,
			"facing_x": direction.x,
			"facing_y": direction.y,
			"enemy_action": String(enemy_action.get("kind", "idle")),
			"enemy_action_elapsed": float(enemy_action.get("elapsed", 0.0)),
			"sample_elapsed": elapsed,
			"shape": String(sample.get("shape", "unknown")),
			"geometry_overlap": clearance <= 0.0,
			"occluded": AttackGeometryScript.is_occluded(sample, enemy_pos),
			"weapon_start_x": float(Vector2(sample.get("weapon_start", player_pos)).x),
			"weapon_start_y": float(Vector2(sample.get("weapon_start", player_pos)).y),
			"weapon_end_x": float(Vector2(sample.get("weapon_end", player_pos)).x),
			"weapon_end_y": float(Vector2(sample.get("weapon_end", player_pos)).y),
		}, true)
	player_action["survey_strike_probe"] = probe

func _survey_mark_strike_resolution(enemy: Dictionary, result: String) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY: return
	var probe: Dictionary = Dictionary(player_action.get("survey_strike_probe", {}))
	if probe.is_empty(): return
	var targets: Array = probe.get("targets", [])
	var label := "%s#%d" % [String(enemy.get("kind", "enemy")), int(enemy.get("id", -1))]
	if not targets.has(label): targets.append(label)
	probe["targets"] = targets
	var priority := {"miss": 0, "evaded": 1, "blocked": 2, "hit": 3, "interrupted": 4}
	if int(priority.get(result, 0)) >= int(priority.get(String(probe.get("result", "miss")), 0)): probe["result"] = result
	player_action["survey_strike_probe"] = probe

func _survey_finalize_strike_probe(end_reason: String) -> void:
	if mode_id != ModeRulesScript.COMBAT_SURVEY: return
	var probe: Dictionary = Dictionary(player_action.get("survey_strike_probe", {}))
	if probe.is_empty(): return
	probe["end_reason"] = end_reason
	if not probe.has("closest_enemy"):
		probe["closest_enemy"] = "none nearby"
		probe["closest_clearance"] = -1.0
	probe["visual_overlap_collision_failure"] = String(probe.get("result", "miss")) == "miss" and bool(probe.get("geometry_overlap", false)) and not bool(probe.get("occluded", false))
	survey_strike_diagnostics.append(probe.duplicate(true))
	player_action.erase("survey_strike_probe")

func _resolve_player_attack_tick(elapsed: float) -> void:
	var is_sweep := String(player_action["kind"]) == "sweep"
	var sampled_action := player_action.duplicate()
	var action_reach := float(player_action.get("reach", player_attack_reach))
	var sample: Dictionary = AttackGeometryScript.pose(sampled_action, player_pos, player_facing, _nearby_walls(player_pos, action_reach + 90.0))
	_survey_update_strike_probe(sample, elapsed)
	var hit_ids: Array = player_action["hit_ids"]
	var contacts: Array[Dictionary] = []
	var pending_awareness: Array[Dictionary] = []
	for enemy in _nearby_enemies(player_pos, action_reach + 120.0):
		if not _enemy_on_current_layer(enemy): continue
		var enemy_id := int(enemy["id"])
		if hit_ids.has(enemy_id): continue
		if AttackGeometryScript.hits_circle(sample, Vector2(enemy["pos"]), float(enemy["radius"])):
			contacts.append({"enemy": enemy, "order": AttackGeometryScript.contact_order(sample, Vector2(enemy["pos"])), "point": AttackGeometryScript.contact_point(sample, Vector2(enemy["pos"]))})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["order"]) < float(b["order"]))
	# A player melee form resolves every body physically crossed by its sampled
	# world-space weapon path. Narrow cuts and thrusts still require exact
	# alignment; they simply no longer stop at the first enemy in that path.
	if not contacts.is_empty(): player_action["hit_done"] = true
	for contact in contacts:
		var enemy: Dictionary = contact["enemy"]
		if String(enemy.get("kind", "")) == "bandit":
			enemy["revealed_to_player"] = true
			enemy["revealed_elapsed"] = 0.35
		var awareness_before := String(enemy.get("awareness", "idle"))
		var action_before := Dictionary(enemy.get("action", _idle_action())).duplicate(true)
		var contact_result: Dictionary = {}
		hit_ids.append(int(enemy["id"]))
		var hit_point := Vector2(contact["point"])
		if _enemy_evades_attack(enemy):
			_survey_mark_strike_resolution(enemy, "evaded")
			_add_effect("dodge", Vector2(enemy["pos"]))
			_set_message("The bandit slips through the attack.")
		elif _enemy_blocks_attack(enemy):
			_survey_mark_strike_resolution(enemy, "blocked")
			_apply_posture_damage(enemy, 2.0 if is_sweep else 0.5)
			_add_effect("block", hit_point)
			_set_message("The shield catches your weapon.")
		else:
			var bonus := 2 if strength_remaining > 0.0 else 0
			var enemy_action: Dictionary = enemy.get("action", {})
			var enemy_committed := String(enemy_action.get("kind", "idle")) != "idle"
			var enemy_recovering := enemy_committed and float(enemy_action.get("elapsed", 0.0)) > float(enemy_action.get("active_end", INF))
			var base_damage := int(player_action.get("damage_min", player_damage_min))
			var opening_damage := int(track_property_ranks.get("openings_recovery", 0)) if enemy_recovering else 0
			var force_bonus := int(player_action.get("building_force_bonus", 0)) if String(player_action.get("kind", "")) in ["attack", "combo"] else 0
			if bool(player_action.get("knife_sequence", false)) and has_track_rank("knife", 4):
				var knife_chain := int(player_action.get("knife_contact_chain", 0))
				force_bonus += mini(3, knife_chain + 1)
				player_action["knife_contact_chain"] = knife_chain + 1
			var raw_damage := base_damage + bonus + opening_damage + _rally_damage_bonus() + force_bonus
			var opening_posture := float(track_property_ranks.get("openings_posture", 0)) * 0.4 if enemy_committed else 0.0
			var posture_damage := float(player_action.get("posture_damage", 2.0)) + opening_posture + _rally_posture_bonus()
			var resolved := _resolve_player_physical_values(enemy, raw_damage, posture_damage, player_action)
			contact_result = resolved
			var dealt := int(resolved["damage"])
			posture_damage = float(resolved["posture"])
			enemy["hp"] = int(enemy["hp"]) - dealt
			damage_dealt += dealt
			var posture_broken := _apply_posture_damage(enemy, posture_damage, hit_point)
			var reaction_applied := false
			if not posture_broken:
				reaction_applied = _apply_enemy_hit_reaction(enemy, posture_damage, awareness_before, action_before, hit_point, player_action)
			if enemy_committed and int(track_property_ranks.get("openings_composure", 0)) > 0:
				dodge_cooldown = maxf(0.0, dodge_cooldown - 0.25)
				skill_cooldown = maxf(0.0, skill_cooldown - 0.25)
			_add_effect("hit", hit_point, dealt, {"direction": (Vector2(enemy["pos"]) - hit_point).normalized(), "interrupted": reaction_applied})
			if String(player_action.get("kind", "")) in ["attack", "combo"] and not bool(player_action.get("building_force_registered", false)):
				player_action["building_force_registered"] = true
				_register_building_force_hit()
			_set_message("The %s connects." % AttackGeometryScript.label(String(player_action.get("technique_id", "diagonal_cut"))).to_lower())
			_survey_mark_strike_resolution(enemy, "interrupted" if reaction_applied else "hit")
		if not contact_result.is_empty():
			pending_awareness.append({"enemy": enemy, "result": contact_result})
			_handle_player_contact_aftermath(enemy, contact_result)
	# Contacts sampled on the same simulation tick share the awareness state they
	# had when the weapon crossed them. Broadcast only after all damage resolves,
	# so enemy-array/path order cannot change unaware damage within one strike.
	for pending in pending_awareness:
		_register_enemy_hit_awareness(Dictionary(pending["enemy"]), Dictionary(pending["result"]), player_action)
	player_action["hit_ids"] = hit_ids

func _resolve_player_physical_values(enemy: Dictionary, base_damage: int, posture_damage: float, source_action: Dictionary = {}) -> Dictionary:
	var preserved_execution := String(source_action.get("ability_id", "")) == "knife_execution" and int(source_action.get("execution_target_id", -1)) == int(enemy.get("id", -2)) and bool(source_action.get("execution_target_was_unaware", false))
	var unaware := String(enemy.get("awareness", "idle")) != "alerted" or preserved_execution
	var multiplier := 1.0
	if float(Dictionary(enemy.get("conditions", {})).get("frost", 0.0)) > 0.0 and not bool(source_action.get("frost_vulnerability_used", false)):
		multiplier *= 1.25
		source_action["frost_vulnerability_used"] = true
	if unaware:
		multiplier = 2.0 if has_track_rank("rogue", 1) else 1.5
		multiplier += float(source_action.get("unaware_bonus_multiplier", 0.0))
		if has_track_rank("rogue", 3): source_action["suppress_alert_until_end"] = true
	var explicit_bonus := 0
	var defense_ignore := 0
	var aimed_contact := aimed_enemy_id == int(enemy.get("id", -1)) and aimed_remaining > 0.0
	if aimed_contact:
		explicit_bonus += 10 if has_track_rank("sharpshooter", 3) else 5
		defense_ignore = 6 if has_track_rank("sharpshooter", 3) else 3
		if has_track_rank("sharpshooter", 3): posture_damage += 3.0
		if has_track_rank("sharpshooter", 4):
			multiplier *= 1.5
			posture_damage *= 2.0
		aimed_enemy_id = -1
		aimed_remaining = 0.0
		subclass_ability_cooldown = 8.0
	var source_ability := String(source_action.get("ability_id", ""))
	if turnabout_remaining > 0.0 and source_ability in ["basic_attack", "sword_combo", "knife_sequence"]:
		explicit_bonus += 8
		posture_damage += 3.0
		turnabout_remaining = 0.0
	var attributes := Dictionary(enemy.get("attributes", {}))
	var properties := Dictionary(enemy.get("properties", {}))
	var effective_defense := maxi(0, int(attributes.get("defense", 0)) + int(properties.get("armor", 0)) - defense_ignore)
	var final_damage := maxi(1, roundi((float(base_damage) + float(explicit_bonus)) * multiplier) - effective_defense)
	return {"damage": final_damage, "posture": posture_damage, "unaware": unaware, "aimed": aimed_contact}

func _register_enemy_hit_awareness(enemy: Dictionary, contact_result: Dictionary, source_action: Dictionary = {}) -> void:
	if int(enemy.get("hp", 0)) <= 0:
		enemy.erase("alarm_remaining")
		enemy.erase("alarm_position")
		return
	enemy["awareness"] = "alerted"
	enemy["alert_remaining"] = 3.0
	enemy["last_known_player"] = player_pos
	var clean_work := bool(contact_result.get("unaware", false)) and has_track_rank("rogue", 3)
	if clean_work:
		var resolution_time := float(source_action.get("duration", 0.0))
		if String(source_action.get("kind", "")) in ["combo", "art_combo"]:
			var phases: Array = source_action.get("phases", [])
			var phase_index := clampi(int(source_action.get("phase_index", 0)), 0, maxi(0, phases.size() - 1))
			if not phases.is_empty(): resolution_time = float(Dictionary(phases[phase_index]).get("end", resolution_time))
		var remaining_personal := maxf(0.0, resolution_time - float(source_action.get("elapsed", 0.0)))
		enemy["alarm_remaining"] = maxf(0.18, remaining_personal / maxf(0.01, _player_personal_tempo()))
		enemy["alarm_position"] = player_pos
	else:
		_broadcast_enemy_alarm(enemy, player_pos)

func _broadcast_enemy_alarm(source: Dictionary, known_position: Vector2) -> void:
	var source_id := int(source.get("id", -1))
	for ally in _nearby_enemies(Vector2(source.get("pos", known_position)), 480.0):
		if int(ally.get("id", -1)) == source_id or int(ally.get("hp", 0)) <= 0 or not _enemy_on_current_layer(ally): continue
		ally["awareness"] = "alerted"
		ally["alert_remaining"] = 3.0
		ally["last_known_player"] = known_position
		ally["suspicious_remaining"] = 0.0

func _update_enemy_alarm(enemy: Dictionary, dt: float) -> void:
	if not enemy.has("alarm_remaining"): return
	var remaining := maxf(0.0, float(enemy.get("alarm_remaining", 0.0)) - dt)
	if remaining > 0.0:
		enemy["alarm_remaining"] = remaining
		return
	var known_position := Vector2(enemy.get("alarm_position", player_pos))
	enemy.erase("alarm_remaining")
	enemy.erase("alarm_position")
	if int(enemy.get("hp", 0)) > 0: _broadcast_enemy_alarm(enemy, known_position)

func _handle_player_contact_aftermath(enemy: Dictionary, contact_result: Dictionary = {}) -> void:
	var conditions := Dictionary(enemy.get("conditions", {}))
	if float(conditions.get("sleep", 0.0)) > 0.0:
		conditions["sleep"] = maxf(0.0, float(conditions["sleep"]) - 1.0)
		enemy["conditions"] = conditions
	if stealth_remaining > 0.0: _break_stealth_for_hostile_action()
	if int(enemy.get("hp", 0)) > 0: return
	if has_track_rank("sharpshooter", 4) and bool(contact_result.get("aimed", false)) and subclass_ability_cooldown > 0.0:
		subclass_ability_cooldown = 0.0
	if has_track_rank("rogue", 5) and assassination_window_remaining > 0.0 and not _enemy_death_has_witness(enemy):
		stealth_remaining = 5.0
		stealth_cooldown_pending = true
		main_ability_cooldown = 0.0
		assassination_window_remaining = 0.0
		_add_effect("stealth", player_pos)

func _break_stealth_for_hostile_action() -> void:
	if stealth_remaining <= 0.0: return
	stealth_remaining = 0.0
	stealth_cooldown_pending = false
	main_ability_cooldown = 12.0
	if has_track_rank("rogue", 5):
		var remaining_action := maxf(0.0, float(player_action.get("duration", 0.0)) - float(player_action.get("elapsed", 0.0))) / maxf(0.01, _player_personal_tempo())
		assassination_window_remaining = maxf(2.0, remaining_action + 0.35)

func _enemy_death_has_witness(victim: Dictionary) -> bool:
	for enemy in _nearby_enemies(Vector2(victim.get("pos", player_pos)), 620.0):
		if int(enemy.get("id", -1)) == int(victim.get("id", -1)) or int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
		var enemy_pos := Vector2(enemy["pos"])
		var offset := player_pos - enemy_pos
		var distance := offset.length()
		var vision_range := float(Dictionary(enemy.get("properties", {})).get("vision_range", SIGHT_RANGE))
		var facing := Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
		var within_perception := distance <= 105.0 or (distance <= vision_range and offset.length_squared() > 0.001 and absf(facing.angle_to(offset.normalized())) <= deg_to_rad(65.0))
		if within_perception and _has_line_of_sight(enemy_pos, player_pos): return true
	return false

func _enemy_blocks_attack(enemy: Dictionary) -> bool:
	if String(enemy["kind"]) != "shield": return false
	var incoming := player_pos - Vector2(enemy["pos"])
	return _within_arc(Vector2(enemy["facing"]), incoming, deg_to_rad(72.0))

func _enemy_evades_attack(enemy: Dictionary) -> bool:
	if String(enemy.get("kind", "")) != "bandit": return false
	var action: Dictionary = enemy.get("action", {})
	var action_kind := String(action.get("kind", "idle"))
	var elapsed := float(action.get("elapsed", 0.0))
	return (action_kind == "evade" and elapsed >= 0.04 and elapsed <= 0.30) or (action_kind == "dodge_strike" and elapsed <= float(action.get("dodge_end", 0.30)))

func _apply_posture_damage(enemy: Dictionary, amount: float, contact: Vector2 = Vector2.INF) -> bool:
	if amount <= 0.0 or int(enemy["hp"]) <= 0: return false
	# Stagger is one authored opening, not a state that quick follow-up attacks
	# may perpetually refresh. Health damage has already resolved at each caller;
	# only additional posture damage is suppressed until the original reaction
	# ends and restores the enemy's posture.
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) == "stagger":
		enemy["posture"] = 0.0
		return false
	enemy["posture"] = maxf(0.0, float(enemy.get("posture", 1.0)) - amount)
	enemy["posture_recovery_delay"] = 1.15
	if float(enemy["posture"]) <= 0.0001:
		return _break_posture(enemy, contact)
	return false

func _break_posture(enemy: Dictionary, contact: Vector2 = Vector2.INF) -> bool:
	var action: Dictionary = enemy["action"]
	var kind := String(enemy["kind"])
	var action_kind := String(action.get("kind", "idle"))
	var elapsed := float(action.get("elapsed", 0.0))
	var active_started := action.has("startup") and elapsed >= float(action.get("startup", 999.0))
	if kind in ["brute", "knight", "warden"] and active_started and action_kind in ["melee", "slam", "charge"]:
		enemy["posture"] = 0.25
		_add_effect("strain", Vector2(enemy["pos"]))
		_set_message("The heavy enemy holds its grounded attack.")
		return false
	var break_bonus_seconds := 0.08 * float(track_property_ranks.get("openings_break_duration", 0))
	var stagger_duration := (0.52 if kind in ["knife", "hound", "bandit"] else 0.66 if kind in ["archer", "hexer", "ice_caster", "fire_caster", "boar"] else 0.78) + break_bonus_seconds
	# A posture break is meant to create an actionable opening. Its timer runs
	# while the player's breaking strike is still recovering, so a short fixed
	# duration could expire before time froze again. Guarantee 0.72 seconds of
	# world time after the current player commitment ends, adjusted into the
	# enemy's personal action clock so fast enemies receive the same opportunity.
	var player_recovery_world_seconds := 0.0
	if String(player_action.get("kind", "idle")) != "idle":
		var player_action_remaining := maxf(0.0, float(player_action.get("duration", 0.0)) - float(player_action.get("elapsed", 0.0)))
		player_recovery_world_seconds = player_action_remaining / maxf(0.01, _player_personal_tempo())
	var guaranteed_world_seconds := player_recovery_world_seconds + POSTURE_BREAK_OPENING_SECONDS + break_bonus_seconds
	stagger_duration = maxf(stagger_duration, guaranteed_world_seconds * _enemy_personal_tempo(enemy))
	var contact_point := Vector2(enemy["pos"]) if not contact.is_finite() else contact
	var reaction_direction := (Vector2(enemy["pos"]) - contact_point).normalized()
	if reaction_direction.length_squared() < 0.001: reaction_direction = -Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
	enemy["action"] = _action("stagger", stagger_duration, Vector2.ZERO)
	enemy["action"].merge({
		"reaction_contact": contact_point,
		"reaction_direction": reaction_direction,
		"reaction_strength": 1.65,
		"reaction_source_kind": action_kind,
		"interrupted_action": action.duplicate(true),
	}, true)
	enemy["posture"] = 0.0
	enemy["posture_recovery_delay"] = stagger_duration
	if has_track_rank("vanguard", 4):
		advance_cooldown = 0.0
	if rally_remaining > 0.0 and has_track_rank("warrior", 4) and not rally_break_extension_used:
		rally_break_extension_used = true
		rally_remaining += 1.0
	_add_effect("posture_break", contact_point, 0, {"direction": reaction_direction, "strength": 1.65})
	_set_message("The %s loses its footing." % kind)
	return true

func _apply_enemy_hit_reaction(enemy: Dictionary, impact: float, awareness_before: String, action_before: Dictionary, contact: Vector2 = Vector2.INF, source_action: Dictionary = {}) -> bool:
	if int(enemy.get("hp", 0)) <= 0: return false
	if not bool(source_action.get("allow_hit_reaction", true)): return false
	if String(Dictionary(enemy.get("action", {})).get("kind", "idle")) == "stagger": return false
	var enemy_kind := String(enemy.get("kind", "blade"))
	var action_kind := String(action_before.get("kind", "idle"))
	# Damage and posture still resolve during a chain, but a hit reaction is one
	# authored opening. Later contacts cannot restart its timer and pin an enemy
	# indefinitely; a posture break may still replace it with a distinct stagger.
	if action_kind == "hit_reaction": return false
	var elapsed := float(action_before.get("elapsed", 0.0))
	var active_started := action_before.has("startup") and elapsed >= float(action_before.get("startup", INF))
	var high_impact := impact >= 3.5
	# Heavy bodies do not lose an authored attack to every light contact. Strong
	# impacts may still interrupt startup, and accumulated posture damage remains
	# the universal route to a full break. Once the weapon moves, even a strong
	# ordinary hit must trade with or evade the grounded commitment.
	if enemy_kind in ["brute", "knight", "warden"] and action_kind in ["melee", "slam", "charge"]:
		if active_started or not high_impact: return false
	# A boar earns armour only after its pounce has accelerated. The crouch and
	# early travel remain interruptible, and a posture-heavy technique can still
	# arrest a full-speed charge.
	if enemy_kind == "boar" and action_kind == "charge" and String(action_before.get("label", "")) == "pounce":
		var armour_start := float(action_before.get("momentum_armour_start", INF))
		if elapsed >= armour_start and not high_impact:
			_add_effect("strain", Vector2(enemy["pos"]))
			return false
	# Landing during an ordinary weapon's already-active contact window can still
	# produce a trade. Startup and recovery are interruptible; the hound's pounce
	# is the deliberate exception and can be knocked out of any phase.
	var in_active_contact := action_before.has("startup") and action_before.has("active_end") and elapsed >= float(action_before["startup"]) and elapsed <= float(action_before["active_end"])
	if in_active_contact and action_kind in ["melee", "dodge_strike"] and enemy_kind not in ["hound", "bandit"]:
		return false
	var duration: float = float({
		"knife": 0.64,
		"bandit": 0.64,
		"hound": 0.64,
		"boar": 0.58,
		"archer": 0.56,
		"hexer": 0.56,
		"ice_caster": 0.56,
		"fire_caster": 0.56,
		"blade": 0.48,
		"captain": 0.48,
		"polearm": 0.38,
		"shield": 0.38,
		"brute": 0.24,
		"knight": 0.24,
		"warden": 0.24,
		"werewolf": 0.26,
	}.get(enemy_kind, 0.48))
	if awareness_before != "alerted": duration += 0.16
	if high_impact: duration += 0.10
	var contact_point := Vector2(enemy["pos"]) if not contact.is_finite() else contact
	var reaction_direction := (Vector2(enemy["pos"]) - contact_point).normalized()
	if reaction_direction.length_squared() < 0.001: reaction_direction = -Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
	var reaction_strength := 1.18 if high_impact else 1.0
	if action_kind == "charge": reaction_strength += 0.16
	enemy["action"] = _action("hit_reaction", duration, Vector2.ZERO)
	enemy["action"].merge({
		"reaction_contact": contact_point,
		"reaction_direction": reaction_direction,
		"reaction_strength": reaction_strength,
		"reaction_source_kind": action_kind,
		"interrupted_action": action_before.duplicate(true),
		"reaction_combo_id": int(source_action.get("combo_instance_id", -1)),
	}, true)
	enemy["posture_recovery_delay"] = maxf(float(enemy.get("posture_recovery_delay", 0.0)), duration)
	_add_effect("interrupt", contact_point, 0, {"direction": reaction_direction, "strength": reaction_strength})
	return true

func _emit_sound(position: Vector2, radius: float) -> void:
	_sound_sequence += 1
	var stealth := float(player_attributes.get("stealth", 0)) if position.distance_to(player_pos) < 4.0 else 0.0
	var concealment := clampf(1.0 - 0.055 * stealth, 0.28, 1.0)
	var variation := rng.randf_range(0.78, 1.22) if stealth > 0.0 else 1.0
	last_sound = {"sequence": _sound_sequence, "pos": position, "radius": radius * concealment * variation}

func _update_enemy_awareness(enemy: Dictionary, dt: float) -> void:
	if float(enemy.get("smoked_remaining", 0.0)) > 0.0:
		enemy["awareness"] = "suspicious"
		enemy["suspicious_remaining"] = maxf(float(enemy.get("suspicious_remaining", 0.0)), float(enemy["smoked_remaining"]))
		enemy["action"] = _idle_action()
		return
	var enemy_pos := Vector2(enemy["pos"])
	var offset := player_pos - enemy_pos
	var distance := offset.length()
	var facing := Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
	var vision_range := (620.0 if String(enemy["kind"]) in ["archer", "hexer", "ice_caster", "fire_caster", "warden", "werewolf"] else SIGHT_RANGE) - 14.0 * float(player_attributes.get("stealth", 0))
	var within_cone := distance <= 105.0 or (distance <= vision_range and absf(facing.angle_to(offset.normalized())) <= deg_to_rad(65.0))
	if not within_cone: enemy["los_refresh_remaining"] = 0.0
	var execution_holds_unaware := String(player_action.get("ability_id", "")) == "knife_execution" and int(player_action.get("execution_target_id", -1)) == int(enemy.get("id", -2)) and float(player_action.get("elapsed", 0.0)) <= float(player_action.get("active_end", 0.0)) and not Array(player_action.get("hit_ids", [])).has(int(enemy.get("id", -2)))
	var sees_player := not execution_holds_unaware and stealth_remaining <= 0.0 and within_cone and _sample_enemy_player_los(enemy, enemy_pos, dt)
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

func _sample_enemy_player_los(enemy: Dictionary, enemy_pos: Vector2, dt: float) -> bool:
	# Perception does not need to repeat an identical wall query at combat's
	# 120 Hz contact resolution. A 20 Hz sample remains substantially faster
	# than any enemy reaction or attack startup, and the staggered refresh keeps
	# a crowd from issuing all of its sight queries on the same simulation tick.
	var remaining := float(enemy.get("los_refresh_remaining", 0.0)) - dt
	if remaining <= 0.0:
		enemy["player_los"] = _has_line_of_sight(enemy_pos, player_pos)
		remaining = 0.042 + 0.004 * float(int(enemy["id"]) % 4)
	enemy["los_refresh_remaining"] = remaining
	return bool(enemy.get("player_los", false))

func _update_enemies(dt: float, update_locomotion: bool = true) -> void:
	_refresh_active_enemy_cache()
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy := enemies[index]
		# Large expedition parts may contain several encounter groups. Distant,
		# unaware groups remain frozen until the player approaches, keeping action
		# simulation proportional to the active locale rather than the whole run.
		if Vector2(enemy["pos"]).distance_to(player_pos) > 1450.0 and String(enemy.get("awareness", "idle")) == "idle": continue
		var enemy_dt := dt * _enemy_personal_tempo(enemy)
		if float(Dictionary(enemy.get("conditions", {})).get("sleep", 0.0)) > 0.0:
			enemy["action"] = _idle_action()
			enemies[index] = enemy
			continue
		enemy["smoked_remaining"] = maxf(0.0, float(enemy.get("smoked_remaining", 0.0)) - dt)
		_update_enemy_awareness(enemy, dt)
		_update_enemy_alarm(enemy, dt)
		_update_bandit_concealment(enemy, dt)
		var pounce_cooldown := float(enemy.get("pounce_cooldown", 0.0))
		if pounce_cooldown > 0.0: enemy["pounce_cooldown"] = maxf(0.0, pounce_cooldown - enemy_dt)
		var dodge_cooldown := float(enemy.get("dodge_cooldown", 0.0))
		if dodge_cooldown > 0.0: enemy["dodge_cooldown"] = maxf(0.0, dodge_cooldown - enemy_dt)
		var neutral_cooldown := float(enemy.get("neutral_cooldown", 0.0))
		if neutral_cooldown > 0.0: enemy["neutral_cooldown"] = maxf(0.0, neutral_cooldown - enemy_dt)
		var shot_cooldown := float(enemy.get("shot_cooldown", 0.0))
		if shot_cooldown > 0.0: enemy["shot_cooldown"] = maxf(0.0, shot_cooldown - enemy_dt)
		var recovery_delay := float(enemy.get("posture_recovery_delay", 0.0))
		if recovery_delay > 0.0:
			recovery_delay = maxf(0.0, recovery_delay - enemy_dt)
			enemy["posture_recovery_delay"] = recovery_delay
		var posture := float(enemy["posture"])
		var posture_max := float(enemy["posture_max"])
		if posture < posture_max and recovery_delay <= 0.0 and String(Dictionary(enemy["action"])["kind"]) not in ["hit_reaction", "stagger"]:
			enemy["posture"] = minf(posture_max, posture + enemy_dt * float(enemy.get("posture_recovery_rate", 1.8)))
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
					enemy["action"] = _enemy_move_action(enemy, target, 0.40)
				else:
					# Reaching a noise source begins an actual search instead of leaving
					# the actor motionless with a zero facing vector and a permanent '?'.
					var search_facing := Vector2(enemy.get("facing", Vector2.DOWN)).normalized()
					if search_facing.length_squared() < 0.001: search_facing = Vector2.DOWN
					var search_sign := 1.0 if int(enemy["id"]) % 2 == 0 else -1.0
					enemy["facing"] = search_facing.rotated(search_sign * dt * 1.8).normalized()
					enemies[index] = enemy
					continue
			else: _choose_enemy_action(enemy)
			action = enemy["action"]
		if String(action["kind"]) != "idle":
			# Action execution remains intentionally unchanged, but every committed
			# action now knows the shared frame and ability identity that produced it.
			action["actor_kind"] = String(enemy["kind"])
			action["weapon_frame"] = String(enemy.get("weapon_frame", "unarmed"))
			action["defense_id"] = String(enemy.get("defense_id", ""))
			if not action.has("ability_id"):
				action["ability_id"] = String(action.get("label", action.get("technique_id", action["kind"])))
			enemy["action"] = action
		action["elapsed"] = float(action["elapsed"]) + enemy_dt
		var kind := String(action["kind"])
		var elapsed := float(action["elapsed"])
		if kind not in ["move", "evade"]:
			enemy["is_moving"] = false
			enemy["last_motion"] = Vector2.ZERO
		if kind in ["move", "evade"]:
			if update_locomotion:
				var speed := _enemy_move_speed(enemy) * float(action.get("speed_multiplier", 1.0))
				_advance_enemy_locomotion(enemy, action, speed * enemy_dt * 2.0, enemy_dt * 2.0)
		elif kind == "dodge_strike":
			if update_locomotion and elapsed <= float(action.get("dodge_end", 0.30)):
				enemy["pos"] = _move_actor(Vector2(enemy["pos"]), Vector2(action["direction"]) * float(action.get("speed", 390.0)) * enemy_dt, float(enemy["radius"]), int(enemy["id"]))
			if elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]) and not bool(action["hit_done"]): _resolve_enemy_melee_tick(enemy, elapsed)
		elif kind == "claw_combo":
			_resolve_enemy_combo_tick(enemy, elapsed)
		elif kind == "pounce_combo":
			if elapsed >= float(action["startup"]) and elapsed <= float(action["pounce_end"]):
				var pounce_origin := Vector2(enemy["pos"])
				enemy["pos"] = _move_actor(pounce_origin, Vector2(action["direction"]) * float(action.get("speed", 410.0)) * enemy_dt, float(enemy["radius"]), int(enemy["id"]))
				if not bool(action.get("pounce_hit", false)) and Vector2(enemy["pos"]).distance_to(player_pos) <= float(enemy["radius"]) + PLAYER_RADIUS + 8.0:
					action["pounce_hit"] = true
					_resolve_incoming_hit(int(enemy["id"]), int(action.get("pounce_damage", 3)), String(enemy["kind"]))
			_resolve_enemy_combo_tick(enemy, elapsed)
		elif kind == "melee" and elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]) and not bool(action["hit_done"]):
			_resolve_enemy_melee_tick(enemy, elapsed)
		elif kind == "charge" and elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]):
			var charge_origin := Vector2(enemy["pos"])
			enemy["pos"] = _move_actor(charge_origin, Vector2(action["direction"]) * float(action.get("speed", 340.0)) * enemy_dt, float(enemy["radius"]), int(enemy["id"]))
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
		elif kind in ["hex", "ice_hex"] and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_hex(enemy, Vector2(action["target"]), "ice_hex" if kind == "ice_hex" else "hex")
		elif kind == "ice_cone" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_ice_cone(enemy, Vector2(action["direction"]))
		elif kind == "fire_circle" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_fire_circle(enemy)
		if elapsed + 0.00001 >= float(action["duration"]):
			if kind == "stagger": enemy["posture"] = float(enemy["posture_max"])
			if String(enemy.get("kind", "")) == "bandit" and kind in ["melee", "dodge_strike"]:
				enemy["neutral_cooldown"] = maxf(float(enemy.get("neutral_cooldown", 0.0)), 0.34)
			enemy["action"] = _idle_action()
		_update_enemy_bucket_membership(enemy)
		enemies[index] = enemy

func _update_bandit_concealment(enemy: Dictionary, world_dt: float) -> void:
	if String(enemy.get("kind", "")) != "bandit": return
	var awareness_state := String(enemy.get("awareness", "idle"))
	if awareness_state == "idle":
		enemy["revealed_to_player"] = false
		enemy["revealed_elapsed"] = 0.0
		return
	if bool(enemy.get("revealed_to_player", false)):
		enemy["revealed_elapsed"] = float(enemy.get("revealed_elapsed", 0.0)) + world_dt
		return
	var enemy_attributes := Dictionary(enemy.get("attributes", {}))
	var reveal_distance := clampf(210.0 + 30.0 * (float(player_attributes.get("awareness", 5)) - float(enemy_attributes.get("stealth", 0))), 150.0, 390.0)
	if player_pos.distance_to(Vector2(enemy["pos"])) <= reveal_distance and _has_line_of_sight(player_pos, Vector2(enemy["pos"])):
		enemy["revealed_to_player"] = true
		enemy["revealed_elapsed"] = 0.0
		_add_effect("discover", Vector2(enemy["pos"]))
		_set_message("Movement in the brush resolves into a bandit.")

func _choose_enemy_action(enemy: Dictionary) -> void:
	var offset := player_pos - Vector2(enemy["pos"])
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.01 else Vector2.DOWN
	enemy["facing"] = direction
	var enemy_kind := String(enemy["kind"])
	if enemy_kind == "bandit" and (not bool(enemy.get("revealed_to_player", false)) or float(enemy.get("revealed_elapsed", 0.0)) < 0.35):
		enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.24)
		return
	if enemy_kind == "boar":
		if float(enemy.get("pounce_cooldown", 0.0)) <= 0.0 and distance >= 88.0 and _charge_can_contact(enemy, distance, 360.0, 0.52, 0.96):
			enemy["action"] = _charge_action(1.54, 0.52, 0.96, 360.0, 2, direction)
			enemy["action"]["label"] = "pounce"
			enemy["action"]["momentum_armour_start"] = 0.70
			enemy["pounce_cooldown"] = 2.40
		elif distance < 115.0:
			enemy["action"] = _action("move", 0.38, -direction)
		else: enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.48)
	elif enemy_kind == "bandit":
		if float(enemy.get("neutral_cooldown", 0.0)) > 0.0:
			var neutral_side := direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5)
			enemy["action"] = _enemy_move_action(enemy, Vector2(enemy["pos"]) + (neutral_side - direction * 0.25).normalized() * 95.0, minf(0.24, float(enemy["neutral_cooldown"])))
		elif float(enemy.get("dodge_cooldown", 0.0)) <= 0.0 and distance >= 112.0 and distance <= 245.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(1.18, 0.42, 0.53, 84.0, 1, direction, "quick_cut", "dodge_strike")
			enemy["action"]["dodge_end"] = 0.30
			enemy["action"]["speed"] = 390.0
			enemy["dodge_cooldown"] = 2.00
		elif distance <= 112.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			# The cut remains quick, but its recovery creates a real neutral window.
			# Fast identity comes from startup and footwork, not a full cycle that can
			# repeatedly beat the player's sword back to readiness.
			enemy["action"] = _melee_action(1.22, 0.36, 0.47, 82.0, 1, direction, "quick_cut")
		elif float(enemy.get("dodge_cooldown", 0.0)) <= 0.0 and distance < 155.0:
			var evade_direction := (-direction + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 0.45).normalized()
			enemy["action"] = _action("evade", 0.38, evade_direction)
			enemy["action"]["speed_multiplier"] = 1.55
			enemy["dodge_cooldown"] = 1.45
		else: enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.32)
	elif enemy_kind == "blade":
		if distance <= 132.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(1.50, 0.52, 0.65, 112.0, 2, direction, "diagonal_cut")
		else:
			enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.48)
	elif enemy_kind == "knife":
		if distance <= 108.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(1.15, 0.32, 0.43, 80.0, 1, direction, "quick_cut")
		else:
			enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.32)
	elif enemy_kind == "polearm":
		if distance <= 112.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			# The spear's shaft answers a player who simply walks through the point.
			# Its main identity remains the long, direction-locked thrust.
			enemy["action"] = _melee_action(1.62, 0.54, 0.88, 126.0, 2, direction, "reverse_cut")
		elif distance <= 218.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(2.25, 0.90, 1.35, 218.0, 3, direction, "thrust")
		else:
			enemy["action"] = _enemy_move_action(enemy, player_pos, 0.70)
	elif enemy_kind == "shield":
		if distance <= 120.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(1.65, 0.62, 0.92, 122.0, 2, direction)
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.58)
	elif enemy_kind == "hound":
		if float(enemy.get("pounce_cooldown", 0.0)) <= 0.0 and distance >= 88.0 and _charge_can_contact(enemy, distance, 440.0, 0.30, 0.68):
			enemy["action"] = _charge_action(1.18, 0.30, 0.68, 440.0, 2, direction)
			enemy["action"]["label"] = "pounce"
			enemy["pounce_cooldown"] = 1.78
		elif float(enemy.get("pounce_cooldown", 0.0)) > 0.0:
			var retreat := (-direction + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 0.58).normalized()
			enemy["action"] = _action("evade", 0.32, retreat)
			enemy["action"]["speed_multiplier"] = 1.48
		else: enemy["action"] = _enemy_move_action(enemy, _pursuit_target(enemy), 0.34)
	elif enemy_kind == "brute":
		if distance <= 155.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(2.55, 1.02, 1.52, 158.0, 4, direction, "forward_smash")
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.78)
	elif enemy_kind == "captain":
		if distance <= 102.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(1.02, 0.30, 0.55, 106.0, 2, direction, "quick_cut")
		elif distance <= 172.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(1.26, 0.44, 0.72, 142.0, 2, direction, "thrust")
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.44)
	elif enemy_kind == "ice_caster":
		if distance <= 310.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("ice_cone", 2.42, direction)
			enemy["action"]["startup"] = 1.16
		elif distance <= 650.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("ice_hex", 2.62, direction)
			enemy["action"]["startup"] = 1.30
			enemy["action"]["target"] = player_pos + player_facing * 20.0
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.48)
	elif enemy_kind == "fire_caster":
		if distance <= 180.0:
			enemy["action"] = _action("fire_circle", 1.78, direction)
			enemy["action"]["startup"] = 0.68
		elif distance <= 670.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("shoot", 1.58, direction)
			enemy["action"]["startup"] = 0.64
			enemy["action"]["label"] = "firebolt"
		else:
			var fire_target := Vector2(enemy["pos"]) + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 210.0 if distance < 480.0 else player_pos
			enemy["action"] = _enemy_move_action(enemy, fire_target, 0.48)
	elif enemy_kind == "archer":
		if float(enemy.get("shot_cooldown", 0.0)) <= 0.0 and distance <= 690.0 and distance >= 235.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos) and _archer_has_clear_lane(enemy):
			enemy["action"] = _action("shoot", 1.62, direction)
			enemy["action"]["startup"] = 0.68
			enemy["shot_cooldown"] = 1.05 + 0.22 * float(int(enemy["id"]) % 3)
		else:
			enemy["action"] = _enemy_move_action(enemy, _archer_support_target(enemy, direction, distance), 0.52)
	elif enemy_kind == "knight":
		if distance <= 185.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(2.78, 1.08, 1.66, 194.0, 4, direction, "heavy_cleave")
		elif distance <= 252.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(2.54, 0.94, 1.46, 248.0, 4, direction, "thrust")
		else: enemy["action"] = _enemy_move_action(enemy, _heavy_intercept_target(enemy), 0.72)
	elif enemy_kind == "hexer":
		if distance <= 620.0 and distance >= 150.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("hex", 1.98, direction)
			enemy["action"]["startup"] = 0.76
			enemy["action"]["target"] = player_pos + player_facing * 24.0
		else:
			var target := Vector2(enemy["pos"]) + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 220.0 if distance < 500.0 else player_pos
			enemy["action"] = _enemy_move_action(enemy, target, 0.52)
	elif enemy_kind == "werewolf":
		if float(enemy.get("pounce_cooldown", 0.0)) <= 0.0 and distance >= 165.0 and _charge_can_contact(enemy, distance, 420.0, 0.34, 0.76):
			if rng.randf() < 0.55: enemy["action"] = _werewolf_pounce_combo(direction)
			else:
				enemy["action"] = _charge_action(1.42, 0.34, 0.78, 430.0, 4, direction)
				enemy["action"]["label"] = "pounce"
			enemy["pounce_cooldown"] = 1.72
		elif distance <= 148.0:
			enemy["action"] = _werewolf_claw_combo(direction)
		elif float(enemy.get("pounce_cooldown", 0.0)) > 0.0:
			var wolf_retreat := (-direction + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 0.46).normalized()
			enemy["action"] = _action("evade", 0.34, wolf_retreat)
			enemy["action"]["speed_multiplier"] = 1.34
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.36)
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
		else: enemy["action"] = _enemy_move_action(enemy, player_pos, 0.72)
	else:
		if distance <= 690.0 and distance >= 230.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("shoot", 1.75, direction)
			enemy["action"]["startup"] = 0.72
		else:
			var move_target := player_pos if distance > 520.0 else Vector2(enemy["pos"]) - direction * 240.0
			enemy["action"] = _enemy_move_action(enemy, move_target, 0.56)

func _enemy_move_action(enemy: Dictionary, target: Vector2, duration: float) -> Dictionary:
	var result := _action("move", duration, _navigation_direction(enemy, target))
	result["target"] = target
	result["moving"] = false
	result["steer_elapsed"] = 0.0
	result["recovery_elapsed"] = 0.0
	return result

func _charge_can_contact(enemy: Dictionary, distance: float, speed: float, startup: float, active_end: float) -> bool:
	if not _has_line_of_sight(Vector2(enemy["pos"]), player_pos): return false
	var contact_allowance := float(enemy.get("radius", ENEMY_RADIUS)) + PLAYER_RADIUS + 18.0
	return distance <= speed * maxf(0.0, active_end - startup) + contact_allowance

func _archer_has_clear_lane(archer: Dictionary) -> bool:
	var origin := Vector2(archer["pos"])
	for ally in _nearby_enemies(origin, origin.distance_to(player_pos)):
		if int(ally.get("id", -1)) == int(archer.get("id", -1)) or int(ally.get("hp", 0)) <= 0 or not _enemy_on_current_layer(ally): continue
		var closest := Geometry2D.get_closest_point_to_segment(Vector2(ally["pos"]), origin, player_pos)
		if closest.distance_to(Vector2(ally["pos"])) <= float(ally.get("radius", ENEMY_RADIUS)) + 12.0:
			return false
	return true

func _heavy_intercept_target(_enemy: Dictionary) -> Vector2:
	# Slow heavies aim for the player's lane instead of following the exact current
	# point forever. They remain slow, but can occupy space and protect a back line.
	var lead := player_facing.normalized() * 64.0
	if String(player_action.get("kind", "idle")) == "move":
		lead = Vector2(player_action.get("direction", player_facing)).normalized() * 92.0
	return player_pos + lead

func _advance_enemy_locomotion(enemy: Dictionary, action: Dictionary, step_distance: float, stall_dt: float) -> void:
	var origin := Vector2(enemy["pos"])
	var direction := Vector2(action.get("direction", Vector2.ZERO)).normalized()
	if String(action.get("kind", "")) == "move":
		if action.has("target"):
			action["steer_elapsed"] = float(action.get("steer_elapsed", 0.0)) + stall_dt
			if direction.length_squared() < 0.001 or float(action["steer_elapsed"]) >= ENEMY_STEER_INTERVAL:
				direction = _navigation_direction(enemy, Vector2(action["target"]))
				action["steer_elapsed"] = 0.0
	action["direction"] = direction
	var finish := origin
	if direction.length_squared() > 0.001:
		finish = _move_actor(origin, direction * step_distance, float(enemy["radius"]), int(enemy["id"]))
	var motion := finish - origin
	var moved := motion.length_squared() > ENEMY_MOVE_EPSILON * ENEMY_MOVE_EPSILON
	if moved:
		enemy["pos"] = finish
		enemy["last_motion"] = motion
		enemy["facing"] = motion.normalized()
		enemy["stalled_time"] = 0.0
	else:
		enemy["last_motion"] = Vector2.ZERO
		enemy["stalled_time"] = float(enemy.get("stalled_time", 0.0)) + stall_dt
		action["recovery_elapsed"] = float(action.get("recovery_elapsed", 0.0)) + stall_dt
		if float(enemy["stalled_time"]) >= ENEMY_STALL_REPATH_TIME:
			enemy.erase("nav_path")
			enemy.erase("nav_target_cell")
			if float(action["recovery_elapsed"]) >= ENEMY_STEER_INTERVAL:
				action["recovery_elapsed"] = 0.0
				var recovery_direction := _stalled_recovery_direction(enemy, direction)
				if recovery_direction.length_squared() > 0.001:
					var recovery_finish := _move_actor(origin, recovery_direction * step_distance, float(enemy["radius"]), int(enemy["id"]))
					var recovery_motion := recovery_finish - origin
					if recovery_motion.length_squared() > ENEMY_MOVE_EPSILON * ENEMY_MOVE_EPSILON:
						enemy["pos"] = recovery_finish
						enemy["last_motion"] = recovery_motion
						enemy["facing"] = recovery_motion.normalized()
						enemy["stalled_time"] = 0.0
						action["direction"] = recovery_direction
						moved = true
		if not moved and float(enemy["stalled_time"]) >= ENEMY_STALL_ABORT_TIME:
			# End a movement commitment that cannot make physical progress. The
			# next decision gets a fresh target and path instead of flashing a
			# permanently false MOVING state against the same obstruction.
			action["duration"] = minf(float(action["duration"]), float(action["elapsed"]))
	action["moving"] = moved
	enemy["is_moving"] = moved
	enemy["action"] = action

func _stalled_recovery_direction(enemy: Dictionary, desired: Vector2) -> Vector2:
	var separation := _crowd_separation_direction(enemy)
	var basis := separation
	if basis.length_squared() < 0.001:
		basis = desired.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5)
	if basis.length_squared() < 0.001:
		basis = Vector2.RIGHT if int(enemy["id"]) % 2 == 0 else Vector2.LEFT
	return _local_avoidance_direction(enemy, basis.normalized())

func _enemy_move_speed(enemy: Dictionary) -> float:
	var kind := String(enemy["kind"])
	var speed: float = float({"boar": 245.0, "bandit": 285.0, "knife": 290.0, "blade": 230.0, "polearm": 120.0, "archer": 175.0, "shield": 145.0, "hound": 325.0, "brute": 105.0, "knight": 68.0, "hexer": 155.0, "ice_caster": 150.0, "fire_caster": 160.0, "captain": 235.0, "warden": 125.0, "werewolf": 285.0}.get(kind, 175.0))
	if kind != "captain" and _captain_near(enemy): speed *= 1.14
	return speed

func _archer_support_target(enemy: Dictionary, direction_to_player: Vector2, distance: float) -> Vector2:
	var side := direction_to_player.rotated(PI * 0.5)
	var lateral_spacing := 185.0 + 35.0 * float(int(enemy["id"]) % 3)
	var desired := player_pos - direction_to_player * 470.0 + side * (lateral_spacing if int(enemy["id"]) % 2 == 0 else -lateral_spacing)
	if distance < 235.0: desired = Vector2(enemy["pos"]) - direction_to_player * 280.0 + side * (130.0 if int(enemy["id"]) % 2 == 0 else -130.0)
	return desired

func _pursuit_target(enemy: Dictionary) -> Vector2:
	var target := player_pos
	var kind := String(enemy.get("kind", ""))
	if String(player_action.get("kind", "idle")) == "move":
		var motion := Vector2(player_action.get("direction", player_facing)).normalized()
		var lead := 120.0 if kind in ["hound", "bandit", "knife"] else 45.0
		target += motion * lead
	if kind in ["bandit", "knife", "hound"]:
		# Flankers reserve distinct lanes around the player's projected route. This
		# makes them intercept lateral movement instead of joining a single trailing
		# column that the player can herd into one broad sweep.
		var route := Vector2(player_action.get("direction", player_facing)).normalized()
		if String(player_action.get("kind", "idle")) != "move":
			route = Vector2(enemy["pos"]).direction_to(player_pos)
		if route.length_squared() < 0.001: route = player_facing.normalized()
		var lane_pattern := [-1.0, 1.0, -0.45, 0.45]
		var lane_index := absi(int(enemy["id"])) % lane_pattern.size()
		var lane_spacing := 96.0 if kind == "hound" else 84.0
		target += route.rotated(PI * 0.5) * float(lane_pattern[lane_index]) * lane_spacing
	return target

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

func _werewolf_claw_combo(direction: Vector2) -> Dictionary:
	var result := _action("claw_combo", 1.26, direction)
	result.merge({"first_start": 0.22, "first_end": 0.42, "second_start": 0.57, "second_end": 0.79, "reach": 148.0, "damage": 2, "hit_one": false, "hit_two": false})
	return result

func _werewolf_pounce_combo(direction: Vector2) -> Dictionary:
	var result := _action("pounce_combo", 1.76, direction)
	result.merge({"startup": 0.34, "pounce_end": 0.76, "speed": 420.0, "pounce_damage": 3, "pounce_hit": false, "first_start": 0.82, "first_end": 1.01, "second_start": 1.13, "second_end": 1.34, "reach": 152.0, "damage": 2, "hit_one": false, "hit_two": false})
	return result

func _resolve_enemy_melee_tick(enemy: Dictionary, elapsed: float) -> void:
	var action: Dictionary = enemy["action"]
	var sample: Dictionary = AttackGeometryScript.pose(action, Vector2(enemy["pos"]), Vector2(action.get("direction", enemy["facing"])), _nearby_walls(Vector2(enemy["pos"]), float(action.get("reach", 220.0)) + 90.0))
	if AttackGeometryScript.hits_circle(sample, player_pos, PLAYER_RADIUS):
		enemy["action"]["hit_done"] = true
		var contact := AttackGeometryScript.contact_point(sample, player_pos)
		_resolve_incoming_hit(int(enemy["id"]), int(action["damage"]), String(enemy["kind"]), Vector2.ZERO, contact)
	else:
		_try_clean_evade_from_movement(enemy, sample)

func _try_clean_evade_from_movement(enemy: Dictionary, sample: Dictionary) -> void:
	if not bool(sample.get("active", false)) or String(player_action.get("kind", "")) != "move": return
	var enemy_action := Dictionary(enemy.get("action", {}))
	if bool(enemy_action.get("clean_evade_player_fired", false)): return
	if float(player_action.get("started_at", 0.0)) <= float(enemy_action.get("started_at", -1.0)): return
	var origin := Vector2(player_action.get("move_origin", player_pos))
	var midpoint := origin.lerp(player_pos, 0.5)
	var near_recent_trail := AttackGeometryScript.hits_circle(sample, origin, PLAYER_RADIUS + 18.0) or AttackGeometryScript.hits_circle(sample, midpoint, PLAYER_RADIUS + 18.0)
	if not near_recent_trail: return
	enemy_action["clean_evade_player_fired"] = true
	enemy["action"] = enemy_action
	_trigger_clean_dodge(player_pos, String(enemy.get("kind", "attack")))

func _resolve_enemy_combo_tick(enemy: Dictionary, elapsed: float) -> void:
	var action: Dictionary = enemy["action"]
	var phases := [
		{"start": float(action.get("first_start", 0.22)), "end": float(action.get("first_end", 0.42)), "hit": "hit_one", "technique": "quick_cut"},
		{"start": float(action.get("second_start", 0.57)), "end": float(action.get("second_end", 0.79)), "hit": "hit_two", "technique": "reverse_cut"},
	]
	for phase_value in phases:
		var phase := Dictionary(phase_value)
		var hit_key := String(phase["hit"])
		if bool(action.get(hit_key, false)) or elapsed < float(phase["start"]) or elapsed > float(phase["end"]): continue
		var sampled_action := action.duplicate(false)
		sampled_action["startup"] = float(phase["start"])
		sampled_action["active_end"] = float(phase["end"])
		sampled_action["technique_id"] = String(phase["technique"])
		var sample: Dictionary = AttackGeometryScript.pose(sampled_action, Vector2(enemy["pos"]), Vector2(action["direction"]), _nearby_walls(Vector2(enemy["pos"]), float(action.get("reach", 152.0)) + 90.0))
		if AttackGeometryScript.hits_circle(sample, player_pos, PLAYER_RADIUS):
			action[hit_key] = true
			var contact := AttackGeometryScript.contact_point(sample, player_pos)
			_resolve_incoming_hit(int(enemy["id"]), int(action.get("damage", 2)), String(enemy["kind"]), Vector2.ZERO, contact)

func _melee_action(duration: float, startup: float, active_end: float, reach: float, damage: int, direction: Vector2, technique_id: String = "diagonal_cut", action_kind: String = "melee") -> Dictionary:
	# Stamina shortens player commitments only. Before v0.2.6 this helper also
	# shortened every enemy attack whenever the run used Stamina rules, which made
	# bandits and other fast enemies re-enter attacks before their authored recovery.
	var profiled_duration := _shorten_recovery(duration, active_end) if action_kind in ["attack", "sweep"] else duration
	var result := _action(action_kind, profiled_duration, direction)
	result["startup"] = startup
	result["active_end"] = active_end
	result["reach"] = reach
	result["damage"] = damage
	result["technique_id"] = technique_id
	return result

func _spawn_projectile(enemy: Dictionary) -> void:
	var direction: Vector2 = Vector2(enemy["facing"]).normalized()
	var firebolt := String(enemy["kind"]) == "fire_caster"
	# A firebolt is a fast, lightly canted shot—not a homing missile. The tiny
	# alternating launch bias gives it character while preserving one readable,
	# committed trajectory once it has left the caster.
	if firebolt: direction = direction.rotated(0.065 if int(enemy["id"]) % 2 == 0 else -0.065)
	projectiles.append({
		"pos": Vector2(enemy["pos"]) + direction * 42.0,
		"vel": direction * (465.0 if firebolt else 700.0),
		"radius": 13.0 if firebolt else 9.0,
		"damage": 3 if firebolt else 2,
		"kind": "firebolt" if firebolt else "arrow",
		# Fireballs retain their launch vector for their entire flight. The fields
		# remain on the projectile for older-save compatibility and future variants.
		"launch_direction": direction,
		"turn_rate": 0.0,
		"max_track_angle": 0.0,
		"source_id": int(enemy["id"]),
		"layer": String(enemy.get("layer", current_layer)),
	})

func _spawn_player_projectile(kind: String, direction: Vector2) -> void:
	var facing := direction.normalized()
	if facing.length_squared() < 0.01: facing = player_facing
	projectiles.append({
		"pos": player_pos + facing * 34.0,
		"vel": facing * (520.0 if kind == "firebomb" else 780.0),
		"radius": 15.0 if kind == "firebomb" else 7.0,
		"damage": 20 if kind == "firebomb" else 15,
		"posture": 2.8 if kind == "firebomb" else 1.4,
		"kind": kind,
		"friendly": true,
		"source_id": 0,
		"travelled": 0.0,
		"max_range": (400.0 if kind == "firebomb" else 560.0) * _aimed_projectile_range_multiplier(),
		"layer": current_layer,
	})

func _spawn_bow_projectile(action: Dictionary) -> void:
	var direction := Vector2(action.get("direction", player_facing)).normalized()
	projectiles.append({
		"pos": player_pos + direction * 34.0,
		"vel": direction * float(action.get("projectile_speed", 480.0)),
		"radius": 7.0,
		"damage": int(action.get("projectile_damage", 6)),
		"posture": float(action.get("projectile_posture", 0.25)),
		"kind": "player_arrow",
		"friendly": true,
		"aimed_projectile": true,
		"source_id": 0,
		"travelled": 0.0,
		"max_range": float(action.get("projectile_range", 250.0)),
		"piercing": false,
		"hit_ids": [],
		"draw_ratio": float(action.get("draw_ratio", 0.0)),
		"full_draw": bool(action.get("full_draw", false)),
		"layer": current_layer,
	})
	_break_stealth_for_hostile_action()
	_emit_sound(player_pos, 430.0)

func _spawn_bow_art_projectiles(piercing: bool, direction: Vector2) -> void:
	var base := direction.normalized()
	if piercing:
		projectiles.append({"pos": player_pos + base * 34.0, "vel": base * 900.0, "radius": 8.0, "damage": 22, "posture": 5.0, "kind": "piercing_arrow", "friendly": true, "aimed_projectile": true, "source_id": 0, "travelled": 0.0, "max_range": 780.0 * _aimed_projectile_range_multiplier(), "piercing": true, "hit_ids": [], "layer": current_layer})
	else:
		for offset in [-0.16, 0.0, 0.16]:
			var ray := base.rotated(float(offset))
			projectiles.append({"pos": player_pos + ray * 34.0, "vel": ray * 720.0, "radius": 7.0, "damage": 6, "posture": 0.7, "kind": "fan_arrow", "friendly": true, "aimed_projectile": true, "source_id": 0, "travelled": 0.0, "max_range": 380.0 * _aimed_projectile_range_multiplier(), "piercing": false, "hit_ids": [], "layer": current_layer})
	_break_stealth_for_hostile_action()
	_emit_sound(player_pos, 520.0)

func _move_vault_actor(origin: Vector2, delta: Vector2) -> Vector2:
	var result := origin
	var candidate := Vector2(origin.x + delta.x, origin.y)
	if not _position_blocked_static(candidate, PLAYER_RADIUS): result.x = candidate.x
	candidate = Vector2(result.x, origin.y + delta.y)
	if not _position_blocked_static(candidate, PLAYER_RADIUS): result.y = candidate.y
	return result

func _resolve_vault_crossings(origin: Vector2, finish: Vector2) -> void:
	var crossed_ids: Array = player_action.get("vault_crossed_ids", [])
	for enemy in _nearby_enemies(origin, origin.distance_to(finish) + 95.0):
		var enemy_id := int(enemy.get("id", -1))
		if crossed_ids.has(enemy_id) or not _enemy_on_current_layer(enemy) or int(enemy.get("hp", 0)) <= 0: continue
		if _segment_distance_to_point(origin, finish, Vector2(enemy["pos"])) > PLAYER_RADIUS + float(enemy.get("radius", ENEMY_RADIUS)) + 6.0: continue
		crossed_ids.append(enemy_id)
		enemy["awareness"] = "alerted"
		enemy["alert_remaining"] = 3.0
		enemy["last_known_player"] = player_pos
		var mass := float(Dictionary(enemy.get("properties", {})).get("mass", 1.0))
		var existing_action := Dictionary(enemy.get("action", _idle_action()))
		if mass > 1.35 or String(existing_action.get("kind", "idle")) in ["stagger", "hit_reaction"]: continue
		var reaction_direction := (Vector2(enemy["pos"]) - origin).normalized()
		if reaction_direction.length_squared() < 0.001: reaction_direction = -Vector2(player_action.get("direction", player_facing)).normalized()
		enemy["action"] = _action("hit_reaction", 0.28, Vector2.ZERO)
		enemy["action"].merge({
			"reaction_contact": Vector2(enemy["pos"]),
			"reaction_direction": reaction_direction,
			"reaction_strength": 0.72,
			"reaction_source_kind": "vault",
			"interrupted_action": existing_action.duplicate(true),
		}, true)
		enemy["posture_recovery_delay"] = maxf(float(enemy.get("posture_recovery_delay", 0.0)), 0.28)
		_add_effect("interrupt", Vector2(enemy["pos"]), 0, {"direction": reaction_direction, "strength": 0.72})
	player_action["vault_crossed_ids"] = crossed_ids

func _spawn_player_fire(pos: Vector2) -> void:
	hazards.append({"kind": "player_fire", "pos": pos, "radius": 124.0, "elapsed": 0.0, "trigger_at": 0.16, "duration": 0.56, "damage": 20, "posture": 2.8, "source_id": 0, "triggered": false, "friendly": true, "layer": current_layer})

func _spawn_hex(enemy: Dictionary, target: Vector2, hazard_kind: String = "hex") -> void:
	var ice := hazard_kind == "ice_hex"
	hazards.append({"kind": hazard_kind, "pos": target, "radius": 112.0 if ice else 100.0, "elapsed": 0.0, "trigger_at": 0.88 if ice else 0.82, "duration": 1.22 if ice else 1.12, "damage": 3 if ice else 2, "source_id": int(enemy["id"]), "triggered": false, "layer": String(enemy.get("layer", current_layer))})
	_set_message("Ice gathers beneath you." if ice else "A hex gathers beneath you.")

func _spawn_ice_cone(enemy: Dictionary, direction: Vector2) -> void:
	hazards.append({"kind": "ice_cone", "pos": Vector2(enemy["pos"]), "direction": direction.normalized(), "radius": 285.0, "half_angle": 0.62, "elapsed": 0.0, "trigger_at": 0.86, "duration": 1.02, "damage": 3, "source_id": int(enemy["id"]), "triggered": false, "layer": String(enemy.get("layer", current_layer))})
	_set_message("A fan of ice surges forward.")

func _spawn_fire_circle(enemy: Dictionary) -> void:
	hazards.append({"kind": "fire_circle", "pos": Vector2(enemy["pos"]), "radius": 152.0, "elapsed": 0.0, "trigger_at": 0.64, "duration": 0.98, "damage": 3, "source_id": int(enemy["id"]), "triggered": false, "layer": String(enemy.get("layer", current_layer))})
	_set_message("Fire gathers around the caster.")

func _update_hazards(dt: float) -> void:
	var survivors: Array[Dictionary] = []
	for hazard in hazards:
		if String(hazard.get("layer", current_layer)) != current_layer:
			survivors.append(hazard)
			continue
		hazard["elapsed"] = float(hazard["elapsed"]) + dt
		var kind := String(hazard.get("kind", "hex"))
		if bool(hazard.get("friendly", false)):
			if not bool(hazard["triggered"]) and float(hazard["elapsed"]) >= float(hazard["trigger_at"]):
				hazard["triggered"] = true
				_add_effect("fire", Vector2(hazard["pos"]))
				for enemy in _nearby_enemies(Vector2(hazard["pos"]), float(hazard["radius"]) + 70.0):
					if _enemy_on_current_layer(enemy) and Vector2(enemy["pos"]).distance_to(Vector2(hazard["pos"])) <= float(hazard["radius"]) + float(enemy["radius"]):
						_damage_enemy_from_consumable(enemy, int(hazard["damage"]), float(hazard.get("posture", 0.0)), Vector2(hazard["pos"]))
			if float(hazard["elapsed"]) < float(hazard["duration"]): survivors.append(hazard)
			continue
		if kind == "ice_cone":
			var progress := clampf(float(hazard["elapsed"]) / float(hazard["trigger_at"]), 0.0, 1.0)
			var origin := Vector2(hazard["pos"])
			var offset := player_pos - origin
			var inside_cone := offset.length() <= float(hazard["radius"]) * progress + PLAYER_RADIUS and _within_arc(Vector2(hazard["direction"]), offset, float(hazard["half_angle"]))
			if not bool(hazard["triggered"]) and inside_cone and _has_line_of_sight(origin, player_pos):
				hazard["triggered"] = true
				_add_effect("ice", player_pos)
				_resolve_incoming_hit(int(hazard["source_id"]), int(hazard["damage"]), "ice cone", origin - player_pos)
		elif not bool(hazard["triggered"]) and float(hazard["elapsed"]) >= float(hazard["trigger_at"]):
			hazard["triggered"] = true
			_add_effect("fire" if kind == "fire_circle" else "ice" if kind == "ice_hex" else "hex", Vector2(hazard["pos"]))
			if player_pos.distance_to(Vector2(hazard["pos"])) <= float(hazard["radius"]):
				var source_label := "fire circle" if kind == "fire_circle" else "ice hex" if kind == "ice_hex" else "hex"
				_resolve_incoming_hit(int(hazard["source_id"]), int(hazard["damage"]), source_label, Vector2(hazard["pos"]) - player_pos)
		if float(hazard["elapsed"]) < float(hazard["duration"]): survivors.append(hazard)
	hazards = survivors

func _update_projectiles(dt: float) -> void:
	var survivors: Array[Dictionary] = []
	for projectile in projectiles:
		if String(projectile.get("layer", current_layer)) != current_layer:
			survivors.append(projectile)
			continue
		var projectile_kind := String(projectile.get("kind", "arrow"))
		var start: Vector2 = projectile["pos"]
		var finish := start + Vector2(projectile["vel"]) * dt
		projectile["pos"] = finish
		projectile["travelled"] = float(projectile.get("travelled", 0.0)) + start.distance_to(finish)
		if bool(projectile.get("friendly", false)):
			var explode := not _inside_world(finish, float(projectile["radius"])) or _point_in_wall(finish) or float(projectile["travelled"]) >= float(projectile.get("max_range", INF))
			var hit_ids: Array = projectile.get("hit_ids", [])
			for enemy in _nearby_enemies(start, start.distance_to(finish) + 100.0):
				if not _enemy_on_current_layer(enemy): continue
				if hit_ids.has(int(enemy.get("id", -1))): continue
				if _segment_distance_to_point(start, finish, Vector2(enemy["pos"])) > float(enemy["radius"]) + float(projectile["radius"]): continue
				if projectile_kind == "firebomb":
					explode = true
					break
				hit_ids.append(int(enemy["id"]))
				_damage_enemy_from_player_projectile(enemy, projectile, Vector2(enemy["pos"]))
				if not bool(projectile.get("piercing", false)):
					explode = true
					break
			projectile["hit_ids"] = hit_ids
			if projectile_kind == "firebomb" and explode: _spawn_player_fire(finish if _inside_world(finish, 1.0) and not _point_in_wall(finish) else start)
			if explode: continue
			survivors.append(projectile)
			continue
		if not _inside_world(finish, float(projectile["radius"])) or _point_in_wall(finish): continue
		if _segment_distance_to_point(start, finish, player_pos) <= PLAYER_RADIUS + float(projectile["radius"]):
			_resolve_incoming_hit(int(projectile["source_id"]), int(projectile["damage"]), "firebolt" if projectile_kind == "firebolt" else "arrow", -Vector2(projectile["vel"]).normalized())
			continue
		survivors.append(projectile)
	projectiles = survivors

func _damage_enemy_from_consumable(enemy: Dictionary, damage: int, posture: float, contact: Vector2) -> void:
	_damage_enemy_from_player_projectile(enemy, {"damage": damage, "posture": posture, "kind": "consumable", "ability_id": "consumable"}, contact)

func _damage_enemy_from_player_projectile(enemy: Dictionary, projectile: Dictionary, contact: Vector2) -> void:
	if int(enemy.get("hp", 0)) <= 0: return
	var awareness_before := String(enemy.get("awareness", "idle"))
	var action_before := Dictionary(enemy.get("action", _idle_action())).duplicate(true)
	var projectile_kind := String(projectile.get("kind", "projectile"))
	var draw_ratio := float(projectile.get("draw_ratio", 1.0))
	var source_action := {
		"ability_id": String(projectile.get("ability_id", projectile_kind)),
		"duration": 0.35,
		"elapsed": 0.0,
		"allow_hit_reaction": projectile_kind != "player_arrow" or draw_ratio >= 0.72,
		"ranged_draw_ratio": draw_ratio,
	}
	var resolved := _resolve_player_physical_values(enemy, int(projectile.get("damage", 0)), float(projectile.get("posture", 0.0)), source_action)
	var damage := int(resolved["damage"])
	var posture := float(resolved["posture"])
	enemy["hp"] = int(enemy["hp"]) - damage
	damage_dealt += damage
	var posture_broken := _apply_posture_damage(enemy, posture, contact)
	var reaction_applied := false
	if not posture_broken:
		reaction_applied = _apply_enemy_hit_reaction(enemy, posture, awareness_before, action_before, contact, source_action)
	_register_enemy_hit_awareness(enemy, resolved, source_action)
	_add_effect("hit", contact, damage, {"direction": (Vector2(enemy["pos"]) - contact).normalized(), "interrupted": reaction_applied})
	_handle_player_contact_aftermath(enemy, resolved)
	if bool(projectile.get("full_draw", false)) and has_track_rank("bow", 5) and not bow_followup_consumed:
		bow_followup_ready = true
	var source_label := "projectile" if String(projectile.get("kind", "")) != "consumable" else "consumable"
	_set_message("The %s is struck by the %s." % [String(enemy["kind"]), source_label])

func _resolve_incoming_hit(source_id: int, damage: int, source_name: String, incoming_from: Vector2 = Vector2.ZERO, contact_position: Vector2 = Vector2.INF) -> void:
	var impact := player_pos if not contact_position.is_finite() else contact_position
	var posture_damage := float(damage) * 1.5
	var scaled_damage := damage * 5
	var physical_defense := int(player_attributes.get("defense", 0)) + int(player_properties.get("armor", 0))
	var mitigated_damage := maxi(1, scaled_damage - physical_defense)
	if _is_evasive():
		_trigger_clean_dodge(impact, source_name)
		return
	if _is_blocking(source_id, incoming_from):
		_break_stealth_for_hostile_action()
		successful_blocks += 1
		player_action["effect_done"] = true
		var guard_profile := String(CombatCatalogScript.weapon_frame(player_weapon_frame).get("guard_profile", "standard"))
		var leakage := 0.25 if guard_profile in ["dual", "awkward"] else 0.0
		var chip_damage := roundi(float(mitigated_damage) * leakage)
		if chip_damage > 0: survey_last_damage_source = source_name
		player_hp = maxi(0, player_hp - chip_damage)
		damage_received_total += chip_damage
		hits_received_total += 1
		player_posture = maxf(0.0, player_posture - posture_damage)
		player_posture_recovery_delay = 1.15
		_add_effect("block", impact, chip_damage)
		if player_posture <= 0.0001:
			set_block_hold(false)
			player_action = _action("stagger", 0.78, Vector2.ZERO)
			_set_message("Your guard breaks under sustained pressure.")
		elif chip_damage > 0:
			_set_message("The heavy blow crashes through part of your guard.")
		else:
			_set_message("Your guard catches the %s." % source_name)
		return
	if _is_enduring():
		_break_stealth_for_hostile_action()
		successful_endures += 1
		player_action["effect_done"] = true
		var endured_damage := int(ceil(float(mitigated_damage) * 0.50))
		survey_last_damage_source = source_name
		player_hp = maxi(0, player_hp - endured_damage)
		damage_received_total += endured_damage
		hits_received_total += 1
		strength_remaining = maxf(strength_remaining, 5.0)
		_apply_source_condition_to_player(source_name)
		_add_effect("endure", impact, endured_damage)
		_set_message("You take the hit and gain Strength for 5 seconds.")
		if player_hp <= 0:
			_begin_death()
		return
	var interrupted_kind := String(player_action.get("kind", "idle"))
	var interrupted_action := player_action.duplicate(true)
	var damage_received := mitigated_damage
	survey_last_damage_source = source_name
	player_hp = maxi(0, player_hp - damage_received)
	damage_received_total += damage_received
	if uses_stamina_rules() and interrupted_kind == "dodge" and float(interrupted_action.get("elapsed", 0.0)) > float(interrupted_action.get("evade_end", 0.0)):
		dodge_recovery_damage_total += damage_received
	if player_exhaustion_remaining > 0.0001: exhaustion_damage_received_total += damage_received
	hits_received_total += 1
	player_posture = maxf(0.0, player_posture - posture_damage)
	player_posture_recovery_delay = 1.15
	_add_effect("hurt", impact, damage_received)
	_break_stealth_for_hostile_action()
	_apply_source_condition_to_player(source_name)
	if player_hp <= 0:
		_begin_death()
		return
	# Additional hits remain dangerous while the player is reeling, but they do
	# not restart or lengthen the reaction. Because time freezes as soon as this
	# original commitment ends, the player is guaranteed another decision
	# instead of being held in an indefinite stagger chain by a crowd.
	if interrupted_kind in ["hit_reaction", "stagger"] or _player_reaction_completed_this_tick:
		_set_message("The %s strikes while you reel, but cannot prolong the stagger." % source_name)
		return
	var posture_broken := player_posture <= 0.0001
	var guard_remaining := float(player_action.get("guard_remaining", 0.0))
	if guard_remaining > 0.0 and not posture_broken:
		var received_posture := posture_damage
		if received_posture <= guard_remaining:
			player_action["guard_remaining"] = maxf(0.0, guard_remaining - received_posture)
			_add_effect("strain", impact, 0, {"direction": (player_pos - impact).normalized()})
			_set_message("The %s hurts you, but your committed action holds." % source_name)
			return
	if interrupted_kind == "rally" and not bool(interrupted_action.get("rally_started", false)):
		rally_cooldown = 3.0
	if interrupted_kind == "combo": set_attack_hold(false)
	if interrupted_kind in ["attack", "sweep", "combo", "art_combo", "twin_fang"]: _survey_finalize_strike_probe("interrupted")
	_reset_building_force()
	_break_player_combo()
	player_action = _action("stagger" if posture_broken else "hit_reaction", 0.78 if posture_broken else minf(0.60, 0.20 + 0.08 * float(damage)), Vector2.ZERO)
	player_action.merge({
		"reaction_contact": impact,
		"reaction_direction": (player_pos - impact).normalized(),
		"interrupted_action": interrupted_action,
		"reaction_source": source_name,
	}, true)
	_add_effect("posture_break" if posture_broken else "interrupt", impact, 0, {"direction": (player_pos - impact).normalized(), "strength": 1.65 if posture_broken else 1.3})
	_set_message("Your posture breaks." if posture_broken else "The %s breaks your commitment." % source_name)

func _apply_source_condition_to_player(source_name: String) -> void:
	var lowered := source_name.to_lower()
	if "ice" in lowered or "frost" in lowered: apply_player_condition_buildup("frost", 4.0)
	elif "fire" in lowered or "burn" in lowered: apply_player_condition_buildup("burning", 4.0)

func _trigger_clean_dodge(impact: Vector2, source_name: String) -> void:
	if not bool(player_action.get("clean_dodge_triggered", false)):
		player_action["clean_dodge_triggered"] = true
		perfect_dodges += 1
		if has_track_rank("evasion", 3) and String(player_action.get("kind", "")) == "dodge":
			if track_choice("evasion_style") == "sidestep":
				counterstep_remaining = 3.0
				_set_message("Clean Sidestep: your next basic attack gains Counterstep.")
			elif track_choice("evasion_style") == "long_roll":
				dodge_cooldown = maxf(0.0, dodge_cooldown - 2.0)
				_set_message("Clean Long Roll: Evasive Rhythm restores readiness.")
			else:
				_set_message("The %s crosses only empty space." % source_name)
		else:
			_set_message("The %s misses your evasive movement." % source_name)
		if has_track_rank("acrobat", 3):
			turnabout_remaining = 4.0
			_set_message("CLEAN EVADE — Turnabout empowers your next basic attack.")
	_add_effect("evade", impact)

func _begin_death() -> void:
	if death_pending: return
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		_complete_survey_room("death")
		return
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
	if String(player_action["kind"]) not in ["dodge", "vault"]:
		return false
	var elapsed := float(player_action["elapsed"])
	return elapsed >= float(player_action.get("evade_start", 0.08)) and elapsed <= float(player_action.get("evade_end", 0.38))

func _is_perfect_dodge() -> bool:
	return false

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

func _add_effect(kind: String, position: Vector2, amount: int = 0, details: Dictionary = {}) -> void:
	var duration := 1.10 if kind == "anchor" else 0.90 if kind == "recover" else 0.62 if kind in ["hit", "hurt", "endure"] else 0.42
	var effect := {"kind": kind, "pos": position, "elapsed": 0.0, "duration": duration, "amount": amount, "layer": current_layer}
	effect.merge(details, true)
	effects.append(effect)

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
			if kind in ["warden", "werewolf"]:
				_boss_defeated = true
				if mode_id == ModeRulesScript.EXPEDITION:
					trial_complete = true
					_set_message("The %s falls. The expedition is complete." % ("Werewolf" if kind == "werewolf" else "Warden"))
				else: _set_message("The Warden falls. The path beyond remains anchored.")
			else: _set_message("The %s falls. XP gained." % kind)
	enemies = living
	_invalidate_active_enemy_cache()
	if mode_id == ModeRulesScript.COMBAT_SURVEY and enemies.is_empty():
		_complete_survey_room("victory")
		return
	for area_id in defeated_areas:
		var still_alive := false
		for enemy in enemies:
			if int(enemy.get("area_id", -1)) == int(area_id): still_alive = true
		if not still_alive and int(area_id) >= 0:
			rooms_cleared = maxi(rooms_cleared, _cleared_area_count())

func _xp_for_enemy(kind: String) -> int:
	return int({"boar": 2, "bandit": 2, "knife": 1, "blade": 2, "archer": 2, "hound": 2, "polearm": 4, "hexer": 4, "ice_caster": 4, "fire_caster": 4, "brute": 5, "knight": 7, "captain": 5, "warden": 12, "werewolf": 18}.get(kind, 2))

func _cleared_area_count() -> int:
	var occupied: Dictionary = {}
	for enemy in enemies: occupied[int(enemy.get("area_id", -1))] = true
	var count := 0
	for area in areas:
		var area_id := int(area["id"])
		if not occupied.has(area_id): count += 1
	return count

func _build_navigation() -> void:
	_flow_target_cell = Vector2i(-999999, -999999)
	_flow_next_cell.clear()
	var cache_key := _navigation_cache_key()
	if _navigation_cache.has(cache_key):
		navigation = _navigation_cache[cache_key]
		performance_metrics["navigation_build_ms"] = 0.0
		performance_metrics["navigation_cache_hit"] = true
		return
	var build_start := Time.get_ticks_usec()
	navigation = AStarGrid2D.new()
	performance_metrics["navigation_cache_hit"] = false
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
	if _loaded_floor_shapes.is_empty():
		performance_metrics["navigation_build_ms"] = float(Time.get_ticks_usec() - build_start) / 1000.0
		return
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
	_navigation_cache[cache_key] = navigation
	performance_metrics["navigation_build_ms"] = float(Time.get_ticks_usec() - build_start) / 1000.0

func _navigation_cache_key() -> String:
	var region_ids: Array = loaded_region_ids.keys()
	region_ids.sort()
	return "%s|%s|%s" % [current_layer, region_ids, hash(walls)]

func prewarm_expedition_navigation() -> void:
	if mode_id not in [ModeRulesScript.EXPEDITION, ModeRulesScript.COMBAT_SURVEY] or areas.is_empty(): return
	var started := Time.get_ticks_usec()
	var original_area_id := current_area_id
	for area_value in areas:
		var area := Dictionary(area_value)
		if String(area.get("layer", current_layer)) != current_layer: continue
		current_area_id = int(area["id"])
		_refresh_loaded_region_content()
		walls.assign(base_walls)
		_build_wall_spatial_index()
		_build_navigation()
	current_area_id = original_area_id
	_apply_shortcut_world_state()
	performance_metrics["navigation_prewarm_ms"] = float(Time.get_ticks_usec() - started) / 1000.0

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
	var separation := _crowd_separation_direction(enemy, local_enemies)
	var preferred := desired.normalized()
	if separation.length_squared() > 0.001:
		preferred = (preferred + separation * 1.35).normalized()
	var side := 1.0 if actor_id % 2 == 0 else -1.0
	for base in [preferred, desired.normalized()]:
		for angle in [0.0, 0.42 * side, -0.42 * side, 0.82 * side, -0.82 * side, 1.22 * side, -1.22 * side, 1.57 * side, -1.57 * side]:
			var candidate := Vector2(base).rotated(float(angle)).normalized()
			# Check both the next physical step and a short look-ahead. This
			# prevents choosing a direction that is technically free one frame
			# at a time but immediately feeds the actor back into the blockage.
			if _position_blocked_with_context(origin + candidate * 10.0, radius, actor_id, local_walls, local_enemies): continue
			if not _position_blocked_with_context(origin + candidate * 42.0, radius, actor_id, local_walls, local_enemies): return candidate
	return Vector2.ZERO

func _crowd_separation_direction(enemy: Dictionary, nearby: Array[Dictionary] = []) -> Vector2:
	var origin := Vector2(enemy["pos"])
	var radius := float(enemy["radius"])
	var local_enemies := nearby
	if local_enemies.is_empty(): local_enemies = _nearby_enemies(origin, radius + 125.0)
	var pressure := Vector2.ZERO
	for other in local_enemies:
		if not _enemy_on_current_layer(other) or int(other["id"]) == int(enemy["id"]) or int(other.get("hp", 0)) <= 0: continue
		var offset := origin - Vector2(other["pos"])
		var distance := offset.length()
		# Begin separating before bodies physically bunch together. The larger
		# comfort band preserves several attack lanes and denies effortless herding.
		var comfort := radius + float(other["radius"]) + 44.0
		if distance >= comfort: continue
		var away := offset / distance if distance > 0.001 else Vector2.RIGHT.rotated(float(int(enemy["id"]) % 8) * PI * 0.25)
		pressure += away * (comfort - distance) / comfort
	return pressure.limit_length(1.0) if pressure.length_squared() > 0.001 else Vector2.ZERO

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
	if distance <= 0.001: return true
	var center := (from + to) * 0.5
	for wall in _nearby_walls(center, distance * 0.5 + 4.0):
		if _segment_intersects_rect(from, to, wall): return false
	return true

func _segment_intersects_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	# Liang-Barsky clipping gives an exact answer with a fixed amount of work,
	# replacing the former 12-unit ray march and its repeated spatial queries.
	var delta := finish - start
	var minimum := 0.0
	var maximum := 1.0
	for axis in range(2):
		var start_value := start.x if axis == 0 else start.y
		var delta_value := delta.x if axis == 0 else delta.y
		var rect_minimum := rect.position.x if axis == 0 else rect.position.y
		var rect_maximum := rect.end.x if axis == 0 else rect.end.y
		if absf(delta_value) <= 0.000001:
			if start_value < rect_minimum or start_value > rect_maximum: return false
			continue
		var first := (rect_minimum - start_value) / delta_value
		var second := (rect_maximum - start_value) / delta_value
		if first > second:
			var swap := first
			first = second
			second = swap
		minimum = maxf(minimum, first)
		maximum = minf(maximum, second)
		if minimum > maximum: return false
	return maximum > 0.0001 and minimum < 0.9999

func _update_exploration(force: bool = false) -> void:
	if not run_active: return
	var secret_changed := _update_secret_passages()
	var center_cell := _visibility_cell(player_pos)
	if not force and not secret_changed and center_cell == _visibility_anchor_cell: return
	if center_cell != _visibility_anchor_cell:
		# The active enemy set is distance-based. Refresh it at the same stable
		# 50-unit cadence as visibility rather than scanning the whole run at
		# 120 Hz or leaving an old three-region set alive after the player moves.
		_invalidate_active_enemy_cache()
	var profile_start := Time.get_ticks_usec()
	_visibility_anchor_cell = center_cell
	_visibility_anchor = (Vector2(center_cell) + Vector2(0.5, 0.5)) * VISIBILITY_CELL
	visible_cells.clear()
	var player_sight := float(player_properties.get("vision_range", SIGHT_RANGE))
	var radius_cells := int(ceil(player_sight / VISIBILITY_CELL))
	var added_discovery := false
	for x in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
		for y in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
			var cell := Vector2i(x, y)
			var point := (Vector2(cell) + Vector2(0.5, 0.5)) * VISIBILITY_CELL
			if point.distance_to(_visibility_anchor) > player_sight or not _point_on_floor(point): continue
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
	# Leveling is deliberately player-initiated through the character sheet.
	# Expedition permits it whenever time is idle; Campaign permits it only at a Waystone.
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

func floor_surface_color_at(point: Vector2, layer: String = "") -> Color:
	var target_layer := current_layer if layer == "" else layer
	var selected_shape: Dictionary = {}
	var selected_priority := -1
	var buckets: Dictionary = _shape_buckets_by_layer.get(target_layer, {})
	for shape_value in Array(buckets.get(_spatial_cell_for_point(point), [])):
		var shape: Dictionary = shape_value
		if not _shape_contains_point(shape, point): continue
		var semantic := String(shape.get("semantic", "clearing"))
		var priority := 30 if semantic == "main_path" else 20 if semantic == "side_path" else 10
		if priority > selected_priority:
			selected_priority = priority
			selected_shape = shape
	var profile: Dictionary = {}
	if not selected_shape.is_empty():
		var part_id := int(selected_shape.get("part_id", -1))
		for area in areas:
			if int(area["id"]) == part_id and String(area.get("layer", target_layer)) == target_layer:
				profile = Dictionary(area.get("profile", {}))
				break
	if profile.is_empty(): return Color(String(Dictionary(world_layers.get(target_layer, {})).get("ground_color", "314247")))
	var semantic := String(selected_shape.get("semantic", "clearing"))
	if semantic == "main_path" and profile.has("main_surface_color"): return Color(String(profile["main_surface_color"]))
	if semantic == "side_path" and profile.has("side_surface_color"): return Color(String(profile["side_surface_color"]))
	return Color(String(profile.get("clearing_color", profile.get("ground_color", "314247"))))

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
		"player_stamina": player_stamina,
		"player_max_stamina": player_max_stamina,
		"player_exhaustion_remaining": player_exhaustion_remaining,
		"player_stamina_regen_delay": player_stamina_regen_delay,
		"player_attack_readiness_remaining": player_attack_readiness_remaining,
		"combat_rules": combat_rules,
		"player_posture": player_posture,
		"player_posture_max": player_posture_max,
		"loadout_id": loadout_id,
		"defense_id": defense_id,
		"player_actor": player_actor(),
		"player_action": player_action.duplicate(true),
		"enemies": _timeline_enemies() if lightweight else enemies.duplicate(true),
		"sensed_enemies": _sensed_enemy_presentations(),
		"walls": [] if lightweight else walls.duplicate(),
		"projectiles": projectiles.duplicate(true),
		"hazards": hazards.duplicate(true),
		"effects": effects.duplicate(true),
		"dodge_cooldown": dodge_cooldown,
		"block_cooldown": block_cooldown,
		"endure_cooldown": endure_cooldown,
		"skill_cooldown": skill_cooldown,
		"rally_cooldown": rally_cooldown,
		"advance_cooldown": advance_cooldown,
		"main_ability_cooldown": main_ability_cooldown,
		"subclass_ability_cooldown": subclass_ability_cooldown,
		"weapon_sequence_cooldown": weapon_sequence_cooldown,
		"attack_readiness_blocked_attempts_total": attack_readiness_blocked_attempts_total,
		"attack_readiness_active_time_total": attack_readiness_active_time_total,
		"direct_attack_uses_total": direct_attack_uses_total,
		"dodge_style_uses_total": dodge_style_uses_total.duplicate(true),
		"dodge_vulnerable_time_total": dodge_vulnerable_time_total,
		"dodge_recovery_damage_total": dodge_recovery_damage_total,
		"stealth_remaining": stealth_remaining,
		"turnabout_remaining": turnabout_remaining,
		"aimed_enemy_id": aimed_enemy_id,
		"aimed_remaining": aimed_remaining,
		"player_condition_buildup": player_condition_buildup.duplicate(true),
		"player_conditions": player_conditions.duplicate(true),
		"rally_remaining": rally_remaining,
		"rally_end_after_action": rally_end_after_action,
		"rally_break_extension_used": rally_break_extension_used,
		"building_force_chain": building_force_chain,
		"counterstep_remaining": counterstep_remaining,
		"strength_remaining": strength_remaining,
		"potions": potions,
		"healing_capacity": healing_capacity(),
		"consumable_slots": consumable_slots.duplicate(true),
		"world_pickups": world_pickups.duplicate(true),
		"pending_pickup": pending_pickup.duplicate(true),
		"trial_complete": trial_complete,
		"boss_defeated": _boss_defeated,
		"run_seed": run_seed,
		"upgrade_pending": upgrade_pending,
		"upgrade_choices": upgrade_choices.duplicate(),
		"upgrades": upgrades.duplicate(),
		"rooms_cleared": rooms_cleared,
		"enemies_defeated": enemies_defeated,
		"damage_dealt": damage_dealt,
		"damage_received_total": damage_received_total,
		"hits_received_total": hits_received_total,
		"potions_used_total": potions_used_total,
		"stamina_spent_total": stamina_spent_total,
		"stamina_depleted_total": stamina_depleted_total,
		"stamina_overdraw_total": stamina_overdraw_total,
		"stamina_regenerated_total": stamina_regenerated_total,
		"overexertion_count": overexertion_count,
		"winded_time_total": winded_time_total,
		"stamina_blocked_continuations": stamina_blocked_continuations,
		"exhaustion_damage_received_total": exhaustion_damage_received_total,
		"exhaustion_move_time_total": exhaustion_move_time_total,
		"exhaustion_wait_time_total": exhaustion_wait_time_total,
		"exhaustion_other_time_total": exhaustion_other_time_total,
		"message": message,
		"run_active": run_active,
		"mode_id": mode_id,
		"mode_config": mode_config.duplicate(true),
		"progression_mode": progression_mode,
		"map_presentation": map_presentation,
		"areas": [] if lightweight else areas.duplicate(true),
		"connections": [] if lightweight else connections.duplicate(true),
		"route_recipe": [] if lightweight else route_recipe.duplicate(true),
		"run_graph": {} if lightweight else run_graph.duplicate(true),
		"locale_catalog": {} if lightweight else locale_catalog.duplicate(true),
		"floor_shapes": [] if lightweight else floor_shapes.duplicate(true),
		"terrain_features": [] if lightweight else terrain_features.duplicate(true),
		"geometry_style": geometry_style,
		"world_size": world_size,
		"waystones": [] if lightweight else waystones.duplicate(true),
		"shortcuts": [] if lightweight else shortcuts.duplicate(true),
		"secret_passages": [] if lightweight else secret_passages.duplicate(true),
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
		"track_property_ranks": track_property_ranks.duplicate(true),
		"track_ranks": track_ranks.duplicate(true),
		"track_choices": track_choices.duplicate(true),
		"equipment_slots": equipment_slots.duplicate(true),
		"upgrade_context": upgrade_context,
		"death_pending": death_pending,
		"run_failed": run_failed,
		"survey_profile": survey_profile,
		"survey_room_number": survey_room_number,
		"survey_room_seed": survey_room_seed,
		"survey_feedback_pending": survey_feedback_pending,
		"survey_run_ending": survey_run_ending,
		"survey_end_reason": survey_end_reason,
		"survey_session": survey_session.duplicate(true),
		"anchor_state": {} if lightweight else anchor_state.duplicate(true),
		"performance_metrics": performance_metrics.duplicate(),
	}

func _sensed_enemy_presentations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not has_track_rank("sharpshooter", 1): return result
	var awareness := int(player_attributes.get("awareness", 0))
	for enemy in _nearby_enemies(player_pos, 1050.0):
		if int(enemy.get("hp", 0)) <= 0 or not _enemy_on_current_layer(enemy): continue
		var enemy_pos := Vector2(enemy["pos"])
		var directly_seen := enemy_visible_to_player(enemy) and is_visible(enemy_pos) and _has_line_of_sight(player_pos, enemy_pos)
		if directly_seen: continue
		if awareness + 3 < int(Dictionary(enemy.get("attributes", {})).get("stealth", 0)): continue
		var jitter := Vector2.RIGHT.rotated(float(int(enemy["id"]) % 16) * TAU / 16.0) * 32.0
		result.append({"id": int(enemy["id"]), "pos": enemy_pos + jitter, "layer": String(enemy.get("layer", current_layer))})
	return result

func _timeline_enemies() -> Array[Dictionary]:
	var nearby: Array[Dictionary] = []
	_refresh_active_enemy_cache()
	for index in _streamed_enemy_indices:
		if index < 0 or index >= enemies.size(): continue
		var enemy: Dictionary = enemies[index]
		if Vector2(enemy["pos"]).distance_to(player_pos) <= ACTIVE_ENEMY_RADIUS and enemy_visible_to_player(enemy): nearby.append(_enemy_presentation(enemy))
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
		"revealed_to_player": bool(enemy.get("revealed_to_player", true)),
		"revealed_elapsed": float(enemy.get("revealed_elapsed", 0.0)),
		"attributes": Dictionary(enemy.get("attributes", {})).duplicate(true),
		"weapon_frame": String(enemy.get("weapon_frame", "unarmed")),
		"equipped_weapon_art": String(enemy.get("equipped_weapon_art", "")),
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
		"save_version": SAVE_VERSION,
		"time": simulation_time,
		"player_pos": player_pos,
		"player_facing": player_facing,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_stamina": player_stamina,
		"player_max_stamina": player_max_stamina,
		"player_overexertion_pending": player_overexertion_pending,
		"player_exhaustion_remaining": player_exhaustion_remaining,
		"player_stamina_regen_delay": player_stamina_regen_delay,
		"player_attack_readiness_remaining": player_attack_readiness_remaining,
		"combat_rules": combat_rules,
		"player_posture": player_posture,
		"player_posture_max": player_posture_max,
		"player_posture_recovery_delay": player_posture_recovery_delay,
		"player_move_speed": player_move_speed,
		"player_attack_duration": player_attack_duration,
		"player_attack_startup": player_attack_startup,
		"player_attack_active_end": player_attack_active_end,
		"player_damage_min": player_damage_min,
		"player_damage_max": player_damage_max,
		"player_attack_reach": player_attack_reach,
		"player_attributes": player_attributes.duplicate(true),
		"player_properties": player_properties.duplicate(true),
		"martial_foundation": martial_foundation.duplicate(true),
		"player_weapon_frame": player_weapon_frame,
		"player_weapon_art_library": player_weapon_art_library.duplicate(),
		"player_equipped_weapon_art": player_equipped_weapon_art,
		"equipment_slots": equipment_slots.duplicate(true),
		"track_property_ranks": track_property_ranks.duplicate(true),
		"track_ranks": track_ranks.duplicate(true),
		"track_choices": track_choices.duplicate(true),
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
		"rally_cooldown": rally_cooldown,
		"advance_cooldown": advance_cooldown,
		"main_ability_cooldown": main_ability_cooldown,
		"subclass_ability_cooldown": subclass_ability_cooldown,
		"weapon_sequence_cooldown": weapon_sequence_cooldown,
		"attack_readiness_blocked_attempts_total": attack_readiness_blocked_attempts_total,
		"attack_readiness_active_time_total": attack_readiness_active_time_total,
		"direct_attack_uses_total": direct_attack_uses_total,
		"dodge_style_uses_total": dodge_style_uses_total.duplicate(true),
		"dodge_vulnerable_time_total": dodge_vulnerable_time_total,
		"dodge_recovery_damage_total": dodge_recovery_damage_total,
		"stealth_remaining": stealth_remaining,
		"stealth_cooldown_pending": stealth_cooldown_pending,
		"assassination_window_remaining": assassination_window_remaining,
		"turnabout_remaining": turnabout_remaining,
		"aimed_enemy_id": aimed_enemy_id,
		"aimed_remaining": aimed_remaining,
		"player_condition_buildup": player_condition_buildup.duplicate(true),
		"player_conditions": player_conditions.duplicate(true),
		"rally_remaining": rally_remaining,
		"rally_end_after_action": rally_end_after_action,
		"rally_break_extension_used": rally_break_extension_used,
		"building_force_chain": building_force_chain,
		"counterstep_remaining": counterstep_remaining,
		"strength_remaining": strength_remaining,
		"potions": potions,
		"healing_capacity": healing_capacity(),
		"consumable_slots": consumable_slots.duplicate(true),
		"world_pickups": world_pickups.duplicate(true),
		"pending_pickup": pending_pickup.duplicate(true),
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
		"damage_received_total": damage_received_total,
		"hits_received_total": hits_received_total,
		"potions_used_total": potions_used_total,
		"stamina_spent_total": stamina_spent_total,
		"stamina_depleted_total": stamina_depleted_total,
		"stamina_overdraw_total": stamina_overdraw_total,
		"stamina_regenerated_total": stamina_regenerated_total,
		"stamina_regen_delay_time_total": stamina_regen_delay_time_total,
		"stamina_regen_active_time_total": stamina_regen_active_time_total,
		"overexertion_count": overexertion_count,
		"winded_time_total": winded_time_total,
		"stamina_blocked_continuations": stamina_blocked_continuations,
		"exhaustion_damage_received_total": exhaustion_damage_received_total,
		"exhaustion_move_time_total": exhaustion_move_time_total,
		"exhaustion_wait_time_total": exhaustion_wait_time_total,
		"exhaustion_other_time_total": exhaustion_other_time_total,
		"message": message,
		"run_active": run_active,
		"mode_id": mode_id,
		"progression_mode": progression_mode,
		"map_presentation": map_presentation,
		"current_layer": current_layer,
		"active_waystone_id": active_waystone_id,
		"shortcut_unlocked": shortcut_unlocked,
		"shortcuts": shortcuts.duplicate(true),
		"secret_passages": secret_passages.duplicate(true),
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
		"survey_profile": survey_profile,
		"survey_room_number": survey_room_number,
		"survey_room_seed": survey_room_seed,
		"survey_feedback_pending": survey_feedback_pending,
		"survey_run_ending": survey_run_ending,
		"survey_end_reason": survey_end_reason,
		"survey_room_definition": survey_room_definition.duplicate(true),
		"survey_room_entry": survey_room_entry.duplicate(true),
		"survey_pending_record": survey_pending_record.duplicate(true),
		"survey_session": survey_session.duplicate(true),
		"survey_last_report": survey_last_report.duplicate(true),
		"survey_action_counts": survey_action_counts.duplicate(true),
		"survey_last_damage_source": survey_last_damage_source,
		"survey_current_view_mode": survey_current_view_mode,
		"survey_room_view_modes": survey_room_view_modes.duplicate(),
		"survey_view_switches": survey_view_switches,
		"survey_empty_melee_contacts": survey_empty_melee_contacts,
		"survey_strike_diagnostics": survey_strike_diagnostics.duplicate(true),
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
	var migration_notices: Array[String] = []
	# v19 replaces the prototype Wayfarer progression with the first durable
	# class/subclass sheet.  Importing older ranks would silently produce an
	# invalid build, so old prototype runs deliberately start fresh.
	if save_version not in [21, 22, 23, 24, 25, 26, 27, 28, 29, SAVE_VERSION]: return false
	var saved_loadout := String(payload.get("loadout_id", "warrior"))
	loadout_id = saved_loadout if CombatCatalogScript.loadout_ids().has(saved_loadout) else "warrior"
	map_presentation = String(payload.get("map_presentation", "full"))
	if save_version == 21:
		_apply_loadout()
		run_active = false
		mode_id = ModeRulesScript.EXPEDITION
		mode_config = ModeRulesScript.definition(mode_id)
		progression_mode = String(mode_config["upgrade_policy"])
		message = "The v0.1.0 combat framework requires a new run. Choose a character."
		return true
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
	start_run(loadout_id, mode_id, run_seed, String(payload.get("survey_profile", "encounter")), String(payload.get("combat_rules", "stamina")))
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		var saved_survey_room := int(payload.get("survey_room_number", 1))
		if saved_survey_room > 1:
			survey_room_number = saved_survey_room - 1
			_load_next_survey_room()
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
	player_stamina = float(payload.get("player_stamina", player_max_stamina))
	player_max_stamina = float(payload.get("player_max_stamina", player_max_stamina))
	player_overexertion_pending = bool(payload.get("player_overexertion_pending", false))
	player_exhaustion_remaining = float(payload.get("player_exhaustion_remaining", 0.0))
	player_stamina_regen_delay = float(payload.get("player_stamina_regen_delay", 0.0))
	player_attack_readiness_remaining = float(payload.get("player_attack_readiness_remaining", 0.0))
	player_posture = float(payload.get("player_posture", player_posture))
	player_posture_max = float(payload.get("player_posture_max", player_posture_max))
	player_posture_recovery_delay = float(payload.get("player_posture_recovery_delay", 0.0))
	player_move_speed = float(payload.get("player_move_speed", player_move_speed))
	# Movement speed is a loadout rule rather than earned run state. Apply the
	# corrected Warrior relationship to existing saves as well as fresh runs.
	if loadout_id == "warrior": player_move_speed = WARRIOR_MOVE_SPEED
	player_attack_duration = float(payload.get("player_attack_duration", player_attack_duration))
	player_attack_startup = float(payload.get("player_attack_startup", player_attack_startup))
	player_attack_active_end = float(payload.get("player_attack_active_end", player_attack_active_end))
	# v0.0.49 raises the Wayfarer's base health and tightens sword commitment.
	# Preserve an existing run's earned health bonus and its current health ratio,
	# rather than unexpectedly healing it or removing its learned progress.
	if save_version < 18:
		var legacy_health_ratio := float(player_hp) / maxf(1.0, float(player_max_hp))
		var earned_health_bonus := maxi(0, player_max_hp - 9)
		player_max_hp = 20 + earned_health_bonus
		player_hp = clampi(roundi(legacy_health_ratio * player_max_hp), 1, player_max_hp)
		player_attack_duration = 0.90
		player_attack_startup = 0.27
		player_attack_active_end = 0.50
	player_damage_min = int(payload.get("player_damage_min", player_damage_min))
	player_damage_max = int(payload.get("player_damage_max", player_damage_max))
	player_attack_reach = float(payload.get("player_attack_reach", player_attack_reach))
	if save_version >= 14:
		player_attributes = Dictionary(payload.get("player_attributes", player_attributes)).duplicate(true)
		player_properties = Dictionary(payload.get("player_properties", player_properties)).duplicate(true)
		martial_foundation = Dictionary(payload.get("martial_foundation", martial_foundation)).duplicate(true)
		player_weapon_frame = String(payload.get("player_weapon_frame", player_weapon_frame))
		player_weapon_art_library.assign(Array(payload.get("player_weapon_art_library", player_weapon_art_library)))
		player_equipped_weapon_art = String(payload.get("player_equipped_weapon_art", player_equipped_weapon_art))
	if save_version >= 15:
		equipment_slots = Dictionary(payload.get("equipment_slots", equipment_slots)).duplicate(true)
		track_property_ranks = Dictionary(payload.get("track_property_ranks", {})).duplicate(true)
	track_ranks = Dictionary(payload.get("track_ranks", _empty_character_track_ranks())).duplicate(true)
	track_choices = Dictionary(payload.get("track_choices", {})).duplicate(true)
	if save_version == 25:
		_migrate_v25_temperament_to_stamina()
	# Actions in older saves used the retired forced-Winded state. Migration ends
	# any in-progress commitment and starts the new rule set from a clear resource.
	if save_version < SAVE_VERSION: player_stamina = player_max_stamina
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_stamina_regen_delay = 0.0
	if save_version < SAVE_VERSION: player_attack_readiness_remaining = 0.0
	_defense_cooldown_multiplier = float(payload.get("defense_cooldown_multiplier", 1.0))
	_skill_cooldown_multiplier = float(payload.get("skill_cooldown_multiplier", 1.0))
	player_action = _idle_action()
	player_overexertion_pending = false
	player_exhaustion_remaining = 0.0
	player_stamina_regen_delay = 0.0
	# v13 introduced a new semantic world grammar and changed Campaign area IDs.
	# Older dynamic actors are regenerated so they cannot survive off-floor in the
	# rewritten geography; learned progression and run statistics remain intact.
	if save_version >= 13:
		enemies.assign(Array(payload.get("enemies", enemies)).duplicate(true))
		projectiles.assign(Array(payload.get("projectiles", [])).duplicate(true))
		hazards.assign(Array(payload.get("hazards", [])).duplicate(true))
		effects.assign(Array(payload.get("effects", [])).duplicate(true))
	dodge_cooldown = float(payload.get("dodge_cooldown", 0.0))
	block_cooldown = float(payload.get("block_cooldown", 0.0))
	endure_cooldown = float(payload.get("endure_cooldown", 0.0))
	skill_cooldown = float(payload.get("skill_cooldown", 0.0))
	rally_cooldown = float(payload.get("rally_cooldown", 0.0))
	advance_cooldown = float(payload.get("advance_cooldown", 0.0))
	main_ability_cooldown = float(payload.get("main_ability_cooldown", 0.0))
	subclass_ability_cooldown = float(payload.get("subclass_ability_cooldown", 0.0))
	weapon_sequence_cooldown = float(payload.get("weapon_sequence_cooldown", 0.0))
	stealth_remaining = float(payload.get("stealth_remaining", 0.0))
	stealth_cooldown_pending = bool(payload.get("stealth_cooldown_pending", false))
	assassination_window_remaining = float(payload.get("assassination_window_remaining", 0.0))
	turnabout_remaining = float(payload.get("turnabout_remaining", 0.0))
	aimed_enemy_id = int(payload.get("aimed_enemy_id", -1))
	aimed_remaining = float(payload.get("aimed_remaining", 0.0))
	player_condition_buildup = Dictionary(payload.get("player_condition_buildup", {})).duplicate(true)
	player_conditions = Dictionary(payload.get("player_conditions", {})).duplicate(true)
	rally_remaining = float(payload.get("rally_remaining", 0.0))
	rally_end_after_action = bool(payload.get("rally_end_after_action", false))
	rally_break_extension_used = bool(payload.get("rally_break_extension_used", false))
	building_force_chain = int(payload.get("building_force_chain", 0))
	counterstep_remaining = float(payload.get("counterstep_remaining", 0.0))
	strength_remaining = float(payload.get("strength_remaining", 0.0))
	var saved_potions := int(payload.get("potions", HEALING_CAPACITY))
	# v20 raises the shared starting capacity from three to five. Preserve spent
	# charges while granting the two newly available slots to a v19 run.
	if save_version == 19: saved_potions += 2
	potions = mini(healing_capacity(), saved_potions)
	if save_version >= 16:
		consumable_slots.assign(Array(payload.get("consumable_slots", _empty_consumable_slots())).duplicate(true))
		world_pickups.assign(Array(payload.get("world_pickups", world_pickups)).duplicate(true))
		pending_pickup = Dictionary(payload.get("pending_pickup", {})).duplicate(true)
	else:
		consumable_slots = _empty_consumable_slots()
		pending_pickup.clear()
	# v0.0.48 moves the initial art into Weaponry. Existing runs that already
	# learned an art retain exactly the same progression investment.
	if save_version < 17 and not player_weapon_art_library.is_empty():
		track_property_ranks["weaponry_art"] = 1
		upgrade_ranks["weaponry_art"] = 1
	trial_complete = bool(payload.get("trial_complete", false))
	_boss_defeated = bool(payload.get("boss_defeated", trial_complete))
	# The former modal upgrade screen was removed in v0.0.45.  Any interrupted
	# legacy choice is safely returned to the character-sheet flow instead.
	upgrade_pending = false
	upgrade_choices.clear()
	upgrade_context = ""
	upgrades.assign(Array(payload.get("upgrades", [])))
	upgrade_count = int(payload.get("upgrade_count", upgrades.size()))
	upgrade_ranks = Dictionary(payload.get("upgrade_ranks", {})).duplicate(true)
	if save_version < 15:
		var legacy_map := {"keen_edge": "weaponry_power", "vitality": "vigilance_health", "quick_hands": "weaponry_handling", "long_reach": "weaponry_impact", "footwork": "vigilance_speed", "readiness": "evasion_cooldown"}
		for legacy_id in legacy_map:
			var legacy_rank := int(upgrade_ranks.get(legacy_id, 0))
			if legacy_rank > 0: track_property_ranks[String(legacy_map[legacy_id])] = legacy_rank
		if player_weapon_art_library.has("prototype_sweeping_cut") and upgrade_count == 0:
			player_weapon_art_library.clear()
			player_equipped_weapon_art = ""
	carried_xp = int(payload.get("carried_xp", 0))
	secured_xp = int(payload.get("secured_xp", carried_xp if save_version < 6 and mode_id == ModeRulesScript.CAMPAIGN_LAB else 0))
	if save_version < 21:
		var old_upgrade_count := upgrade_count
		var refund := 2 * old_upgrade_count * old_upgrade_count + 4 * old_upgrade_count
		var health_ratio := float(player_hp) / maxf(1.0, float(player_max_hp))
		_apply_loadout()
		player_hp = clampi(roundi(health_ratio * player_max_hp), 1, player_max_hp)
		track_ranks = _empty_character_track_ranks()
		track_choices.clear()
		track_property_ranks.clear()
		upgrades.clear()
		upgrade_ranks.clear()
		upgrade_count = 0
		carried_xp += refund
		if mode_id == ModeRulesScript.CAMPAIGN_LAB: secured_xp += refund
		migration_notices.append("Your old training was refunded as XP for the revised disciplines.")
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
	if save_version >= 21:
		var saved_secrets: Array = payload.get("secret_passages", [])
		for secret in secret_passages:
			for saved_secret in saved_secrets:
				if String(Dictionary(saved_secret).get("id", "")) == String(secret.get("id", "")):
					secret["revealed"] = bool(Dictionary(saved_secret).get("revealed", false))
	_apply_shortcut_world_state()
	if save_version >= 13:
		visible_cells = Dictionary(payload.get("visible_cells", {})).duplicate()
		discovered_cells_by_layer = Dictionary(payload.get("discovered_cells_by_layer", {})).duplicate(true)
		if discovered_cells_by_layer.is_empty(): discovered_cells_by_layer[current_layer] = Dictionary(payload.get("discovered_cells", {})).duplicate()
		_load_current_layer_discovery()
		current_area_id = int(payload.get("current_area_id", 0))
	else:
		visible_cells.clear()
		discovered_cells.clear()
		discovered_cells_by_layer.clear()
		for layer_id in world_layers: discovered_cells_by_layer[String(layer_id)] = {}
		discovered_cells_by_layer[current_layer] = discovered_cells
		current_area_id = _area_id_at_position(player_pos, current_layer)
	death_pending = bool(payload.get("death_pending", false))
	run_failed = bool(payload.get("run_failed", false))
	rooms_cleared = int(payload.get("rooms_cleared", 0))
	enemies_defeated = int(payload.get("enemies_defeated", 0))
	damage_dealt = int(payload.get("damage_dealt", 0))
	damage_received_total = int(payload.get("damage_received_total", 0))
	hits_received_total = int(payload.get("hits_received_total", 0))
	potions_used_total = int(payload.get("potions_used_total", 0))
	stamina_spent_total = float(payload.get("stamina_spent_total", 0.0))
	stamina_depleted_total = float(payload.get("stamina_depleted_total", stamina_spent_total))
	stamina_overdraw_total = float(payload.get("stamina_overdraw_total", 0.0))
	stamina_regenerated_total = float(payload.get("stamina_regenerated_total", 0.0))
	stamina_regen_delay_time_total = float(payload.get("stamina_regen_delay_time_total", 0.0))
	stamina_regen_active_time_total = float(payload.get("stamina_regen_active_time_total", 0.0))
	overexertion_count = int(payload.get("overexertion_count", 0))
	winded_time_total = float(payload.get("winded_time_total", 0.0))
	stamina_blocked_continuations = int(payload.get("stamina_blocked_continuations", 0))
	exhaustion_damage_received_total = int(payload.get("exhaustion_damage_received_total", 0))
	exhaustion_move_time_total = float(payload.get("exhaustion_move_time_total", 0.0))
	exhaustion_wait_time_total = float(payload.get("exhaustion_wait_time_total", 0.0))
	exhaustion_other_time_total = float(payload.get("exhaustion_other_time_total", 0.0))
	attack_readiness_blocked_attempts_total = int(payload.get("attack_readiness_blocked_attempts_total", 0))
	attack_readiness_active_time_total = float(payload.get("attack_readiness_active_time_total", 0.0))
	direct_attack_uses_total = int(payload.get("direct_attack_uses_total", 0))
	dodge_style_uses_total = Dictionary(payload.get("dodge_style_uses_total", {})).duplicate(true)
	dodge_vulnerable_time_total = float(payload.get("dodge_vulnerable_time_total", 0.0))
	dodge_recovery_damage_total = int(payload.get("dodge_recovery_damage_total", 0))
	perfect_dodges = int(payload.get("perfect_dodges", 0))
	counter_hits = int(payload.get("counter_hits", 0))
	successful_blocks = int(payload.get("successful_blocks", 0))
	successful_endures = int(payload.get("successful_endures", 0))
	if mode_id == ModeRulesScript.COMBAT_SURVEY:
		survey_profile = String(payload.get("survey_profile", "encounter"))
		survey_room_number = int(payload.get("survey_room_number", 1))
		survey_room_seed = int(payload.get("survey_room_seed", _survey_seed_for_room(survey_room_number)))
		survey_feedback_pending = bool(payload.get("survey_feedback_pending", false))
		survey_run_ending = bool(payload.get("survey_run_ending", false))
		survey_end_reason = String(payload.get("survey_end_reason", ""))
		survey_room_definition = Dictionary(payload.get("survey_room_definition", survey_room_definition)).duplicate(true)
		survey_room_entry = Dictionary(payload.get("survey_room_entry", survey_room_entry)).duplicate(true)
		survey_pending_record = Dictionary(payload.get("survey_pending_record", {})).duplicate(true)
		survey_session = Dictionary(payload.get("survey_session", survey_session)).duplicate(true)
		survey_last_report = Dictionary(payload.get("survey_last_report", {})).duplicate(true)
		survey_action_counts = Dictionary(payload.get("survey_action_counts", {})).duplicate(true)
		survey_last_damage_source = String(payload.get("survey_last_damage_source", ""))
		survey_current_view_mode = String(payload.get("survey_current_view_mode", "isometric"))
		survey_room_view_modes.assign(Array(payload.get("survey_room_view_modes", [survey_current_view_mode])))
		survey_view_switches = int(payload.get("survey_view_switches", 0))
		survey_empty_melee_contacts = int(payload.get("survey_empty_melee_contacts", 0))
		survey_strike_diagnostics.assign(Array(payload.get("survey_strike_diagnostics", [])))
	simulation_time = float(payload.get("time", 0.0))
	message = String(payload.get("message", message))
	if position_was_migrated or save_version < 13:
		migration_notices.push_front("The forest shifted. Its old geography fades from memory.")
	if not migration_notices.is_empty():
		message = " ".join(migration_notices)
	rng.state = int(payload.get("rng_state", rng.state))
	_next_enemy_id = 1
	for index in range(enemies.size()):
		var enemy: Dictionary = _hydrate_enemy_combat_profile(enemies[index])
		enemy["action"] = _idle_action()
		enemy["is_moving"] = false
		enemy["last_motion"] = Vector2.ZERO
		enemy["stalled_time"] = 0.0
		enemy.erase("nav_path")
		enemy.erase("nav_target_cell")
		_next_enemy_id = maxi(_next_enemy_id, int(enemy["id"]) + 1)
		enemies[index] = enemy
	anchor_state = Dictionary(payload.get("anchor_state", {})).duplicate(true) if save_version >= 13 else {}
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
