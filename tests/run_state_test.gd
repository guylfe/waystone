extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const GameBoardScript = preload("res://scripts/presentation/game_board.gd")
const PresentationFrameScript = preload("res://scripts/presentation/presentation_frame.gd")
const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const FloorGeneratorScript = preload("res://scripts/core/floor_generator.gd")

func _init() -> void:
	test_idle_freezes_time()
	test_expedition_infinite_potions()
	test_continuous_movement()
	test_attacks_are_long_commitments()
	test_enemy_freezes_mid_action()
	test_polearm_reach_and_timing()
	test_projectile_motion()
	test_dodge_world_time()
	test_perfect_dodge()
	test_directional_block()
	test_block_stops_orphaned_projectile()
	test_endure_trades_health_for_strength()
	test_loadout_identities()
	test_duelist_sweeping_cut()
	test_signature_attack_roster()
	test_attack_geometry_boundaries()
	test_first_contact_and_multi_target_rules()
	test_attack_geometry_stops_at_walls()
	test_projected_weapon_endpoints_round_trip()
	test_fast_enemy_posture_break()
	test_grounded_heavy_resists_break()
	test_navigation_routes_around_wall()
	test_isometric_is_default()
	test_isometric_projection_round_trip()
	test_projected_combat_footprints_match_each_view()
	test_compact_actor_model_and_facing_marker()
	test_isometric_actor_pick_uses_visible_body()
	test_desktop_movement_tracks_screen_directions()
	test_desktop_held_keys_combine_diagonally()
	test_playback_interpolates_between_simulation_steps()
	test_actions_stream_without_precomputation()
	test_streaming_caps_realtime_catchup()
	test_presentation_frames_reuse_storage()
	test_desktop_landscape_layout()
	test_close_camera_tracks_player()
	test_camera_culls_offscreen_world()
	test_lightweight_timeline_snapshots()
	test_shield_front_arc()
	test_new_enemy_roles()
	test_progressive_expedition_rooms()
	test_required_passages_have_generous_clearance()
	test_overlay_map_passes_input_through()
	test_region_streaming_limits_active_world()
	test_full_map_supports_arbitrary_discovered_layers()
	test_generated_rooms_have_no_shields()
	test_mode_policies_and_death()
	test_layered_friendly_forest_topology()
	test_waystone_requires_deliberate_activation()
	test_room_reward_progression()
	test_shortcut_and_waystone_persistence()
	test_provisional_progress_accounting()
	test_visibility_memory_and_awareness()
	test_discovery_uses_cached_grid_visibility()
	test_floor_cache_appends_discovery_incrementally()
	test_autosave_waits_for_quiet_input()
	test_xp_death_recovery()
	test_hex_hazard()
	test_save_round_trip()
	test_save_payload_omits_regenerated_world_geometry()
	test_version_one_save_migration()
	test_version_three_attack_migration()
	test_version_twelve_world_grammar_migration()
	test_restart_restores_expedition()
	print("Expedition and committed-action simulation tests passed.")
	quit(0)

func test_idle_freezes_time() -> void:
	var state: RunState = RunStateScript.new()
	var before := state.simulation_time
	state.snapshot()
	assert(is_equal_approx(state.simulation_time, before))

func test_expedition_infinite_potions() -> void:
	var expedition: RunState = RunStateScript.new(false)
	expedition.start_run("duelist", "expedition", 717)
	expedition.potions = 0
	expedition.player_hp = 1
	assert(expedition.has_infinite_potions())
	assert(expedition.request_potion())
	assert(expedition.player_hp == 6 and expedition.potions == 0)
	expedition.player_hp = 1
	assert(expedition.request_potion() and expedition.potions == 0)
	var campaign: RunState = RunStateScript.new(false)
	campaign.start_run("duelist", "campaign_lab", 717)
	campaign.potions = 0
	campaign.player_hp = 1
	assert(not campaign.has_infinite_potions())
	assert(not campaign.request_potion())

func test_continuous_movement() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies.clear()
	var origin := state.player_pos
	assert(state.request_move(Vector2(0.6, -0.8), 123.0))
	assert(state.player_pos.distance_to(origin) > 28.0)
	assert(state.player_pos.distance_to(origin) < 38.0)
	assert(not is_equal_approx(state.player_pos.x, round(state.player_pos.x)))
	assert(state.simulation_time > 0.09 and state.simulation_time < 0.13)
	assert(state.last_timeline.size() >= 6)
	assert(state.is_player_ready())
	var frozen_time := state.simulation_time
	state.snapshot()
	assert(is_equal_approx(state.simulation_time, frozen_time))

func test_attacks_are_long_commitments() -> void:
	var state: RunState = RunStateScript.new()
	assert(state.select_loadout("guardian"))
	state.enemies.clear()
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0))
	assert(state.simulation_time >= 1.39)
	assert(state.last_timeline.size() >= 70)

func test_enemy_freezes_mid_action() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies = [state._make_enemy("blade", state.player_pos + Vector2(0.0, -115.0), 7)]
	assert(state.request_wait(0.20))
	var action: Dictionary = state.enemies[0]["action"]
	assert(String(action["kind"]) == "melee")
	assert(float(action["elapsed"]) > 0.19 and float(action["elapsed"]) < float(action["duration"]))
	assert(float(action["duration"]) >= 1.4)

func test_polearm_reach_and_timing() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies = [state._make_enemy("polearm", state.player_pos + Vector2(0.0, -205.0), 12)]
	assert(state.request_wait(0.20))
	var enemy: Dictionary = state.enemies[0]
	var action: Dictionary = enemy["action"]
	assert(float(enemy["radius"]) > state.ENEMY_RADIUS)
	assert(String(action["kind"]) == "melee")
	assert(float(action["reach"]) >= 210.0)
	assert(float(action["startup"]) >= 0.9)
	assert(float(action["duration"]) >= 2.2)

func test_projectile_motion() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies.clear()
	state.projectiles = [{"pos": Vector2(150.0, 150.0), "vel": Vector2(300.0, 0.0), "radius": 9.0, "damage": 2, "source_id": 99}]
	assert(state.request_wait(0.20))
	assert(state.projectiles.size() == 1)
	var x := Vector2(state.projectiles[0]["pos"]).x
	assert(x > 205.0 and x < 220.0)

func test_dodge_world_time() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies.clear()
	assert(state.request_dodge(Vector2.RIGHT))
	var frozen := state.dodge_cooldown
	assert(frozen < state.DODGE_COOLDOWN and frozen > 3.2)
	state.snapshot()
	assert(is_equal_approx(state.dodge_cooldown, frozen))
	assert(state.request_wait(0.5))
	assert(state.dodge_cooldown < frozen - 0.45)

func test_perfect_dodge() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies = [state._make_enemy("blade", state.player_pos + Vector2(90.0, 0.0), 7)]
	var enemy := state.enemies[0]
	enemy["facing"] = Vector2.LEFT
	enemy["action"] = state._melee_action(1.45, 0.52, 0.82, 128.0, 2, Vector2.LEFT)
	# The swept blade crosses the downward dodge around 0.2 seconds into the
	# commitment, inside the deterministic perfect window.
	enemy["action"]["elapsed"] = 0.331
	state.enemies[0] = enemy
	assert(state.request_dodge(Vector2.DOWN))
	assert(state.perfect_dodges == 1)
	assert(state.counter_hits == 1)
	assert(state.player_hp == state.player_max_hp)

func test_directional_block() -> void:
	var state: RunState = RunStateScript.new()
	assert(state.select_loadout("guardian"))
	state.enemies = [state._make_enemy("blade", state.player_pos + Vector2(0.0, -110.0), 7)]
	var enemy := state.enemies[0]
	enemy["facing"] = Vector2.DOWN
	enemy["action"] = state._melee_action(1.45, 0.52, 0.82, 128.0, 2, Vector2.DOWN)
	enemy["action"]["elapsed"] = 0.22
	state.enemies[0] = enemy
	assert(state.request_block(Vector2.UP))
	assert(state.successful_blocks == 1)
	assert(state.player_hp == state.player_max_hp)
	assert(state.block_cooldown > 0.0 and state.block_cooldown < state.BLOCK_COOLDOWN)

func test_block_stops_orphaned_projectile() -> void:
	var state: RunState = RunStateScript.new()
	assert(state.select_loadout("guardian"))
	state.enemies.clear()
	state.player_action = state._action("block", 1.10, Vector2.UP)
	state.player_action["startup"] = 0.16
	state.player_action["active_end"] = 0.78
	state.player_action["elapsed"] = 0.40
	state.player_facing = Vector2.UP
	var hp_before := state.player_hp
	state._resolve_incoming_hit(999, 2, "arrow", Vector2.UP)
	assert(state.successful_blocks == 1)
	assert(state.player_hp == hp_before)

func test_endure_trades_health_for_strength() -> void:
	var state: RunState = RunStateScript.new()
	assert(state.select_loadout("reaver"))
	state.enemies = [state._make_enemy("blade", state.player_pos + Vector2(0.0, -110.0), 7)]
	var enemy := state.enemies[0]
	enemy["facing"] = Vector2.DOWN
	enemy["action"] = state._melee_action(1.45, 0.52, 0.82, 128.0, 2, Vector2.DOWN)
	enemy["action"]["elapsed"] = 0.22
	state.enemies[0] = enemy
	var hp_before := state.player_hp
	assert(state.request_endure(Vector2.UP))
	assert(state.successful_endures == 1)
	assert(state.player_hp < hp_before)
	assert(state.strength_remaining > 4.0)
	assert(state.endure_cooldown > 0.0)

func test_loadout_identities() -> void:
	var state: RunState = RunStateScript.new()
	assert(state.loadout_id == "duelist" and state.defense_id == "dodge")
	var duelist_speed := state.player_move_speed
	assert(state.select_loadout("guardian"))
	assert(state.defense_id == "block")
	assert(state.player_max_hp == 14)
	assert(state.player_move_speed < duelist_speed)
	assert(state.select_loadout("reaver"))
	assert(state.defense_id == "endure")
	assert(state.player_damage_min >= 3)

func test_duelist_sweeping_cut() -> void:
	var state: RunState = RunStateScript.new()
	state.walls.clear()
	state._build_navigation()
	state.enemies = [state._make_enemy("knife", state.player_pos + Vector2(-42, -98), 8), state._make_enemy("knife", state.player_pos + Vector2(42, -98), 8)]
	assert(state.request_skill(Vector2.UP))
	assert(state.skill_cooldown > 2.7)
	assert(int(state.enemies[0]["hp"]) < 8 and int(state.enemies[1]["hp"]) < 8)
	assert(state.simulation_time >= 1.30)

func test_signature_attack_roster() -> void:
	var state: RunState = RunStateScript.new()
	assert(state.player_attack_technique == "diagonal_cut")
	assert(state.select_loadout("guardian") and state.player_attack_technique == "heavy_chop")
	assert(state.select_loadout("reaver") and state.player_attack_technique == "broad_sweep")
	state.walls.clear()
	var expected := {"knife": "quick_cut", "blade": "diagonal_cut", "polearm": "thrust", "hound": "bite", "brute": "forward_smash", "captain": "thrust"}
	var distances := {"knife": 80.0, "blade": 110.0, "polearm": 190.0, "hound": 70.0, "brute": 140.0, "captain": 120.0}
	for kind in expected:
		var enemy := state._make_enemy(String(kind), state.player_pos + Vector2.UP * float(distances[kind]), state._enemy_base_hp(String(kind)))
		state._choose_enemy_action(enemy)
		assert(String(Dictionary(enemy["action"]).get("technique_id", "")) == String(expected[kind]))

func test_attack_geometry_boundaries() -> void:
	var origin := Vector2(500, 500)
	var thrust := {"technique_id": "thrust", "elapsed": 0.76, "startup": 0.4, "active_end": 0.8, "duration": 1.2, "reach": 200.0}
	var thrust_pose: Dictionary = AttackGeometryScript.pose(thrust, origin, Vector2.RIGHT)
	assert(AttackGeometryScript.hits_circle(thrust_pose, origin + Vector2(150, 5), 6.0))
	assert(not AttackGeometryScript.hits_circle(thrust_pose, origin + Vector2(150, 30), 6.0))
	var cut := {"technique_id": "quick_cut", "elapsed": 0.60, "startup": 0.4, "active_end": 0.8, "duration": 1.2, "reach": 92.0}
	var cut_pose: Dictionary = AttackGeometryScript.pose(cut, origin, Vector2.RIGHT)
	var blade_mid := Vector2(cut_pose["start"]).lerp(Vector2(cut_pose["end"]), 0.8)
	assert(AttackGeometryScript.hits_circle(cut_pose, blade_mid, 4.0))
	assert(not AttackGeometryScript.hits_circle(cut_pose, origin + Vector2.LEFT * 75.0, 4.0))

func test_first_contact_and_multi_target_rules() -> void:
	var state: RunState = RunStateScript.new()
	state.walls.clear()
	state.player_facing = Vector2.RIGHT
	var near := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 90.0, 9)
	var far := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 145.0, 9)
	state.enemies = [far, near]
	state.player_action = state._melee_action(1.2, 0.2, 0.8, 190.0, 2, Vector2.RIGHT, "thrust", "attack")
	state.player_action["elapsed"] = 0.72
	state.player_action["damage_min"] = 2
	state.player_action["damage_max"] = 2
	state._resolve_player_attack_tick(0.72)
	assert(int(near["hp"]) == 7)
	assert(int(far["hp"]) == 9)
	assert(bool(state.player_action["hit_done"]))
	assert(bool(AttackGeometryScript.technique("broad_sweep")["multi"]))

func test_attack_geometry_stops_at_walls() -> void:
	var origin := Vector2(100, 100)
	var wall := Rect2(180, 50, 50, 100)
	var action := {"technique_id": "thrust", "elapsed": 0.79, "startup": 0.4, "active_end": 0.8, "duration": 1.2, "reach": 240.0}
	var sample: Dictionary = AttackGeometryScript.pose(action, origin, Vector2.RIGHT, [wall])
	assert(Vector2(sample["end"]).x <= wall.position.x + 0.01)
	assert(not AttackGeometryScript.hits_circle(sample, Vector2(260, 100), 20.0))

func test_projected_weapon_endpoints_round_trip() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot()
	board.board_area = Rect2(0, 0, 720, 960)
	board.view_mode = "isometric"
	board._update_projection()
	var action: Dictionary = board.state._melee_action(1.2, 0.3, 0.7, 180.0, 2, Vector2.UP, "thrust")
	action["elapsed"] = 0.66
	var sample: Dictionary = AttackGeometryScript.pose(action, board.state.player_pos, Vector2.UP, board.state.walls)
	for key in ["weapon_start", "weapon_end"]:
		var world_point := Vector2(sample[key])
		assert(board._screen_to_world(board._world_to_screen(world_point)).distance_to(world_point) < 0.01)
	board.free()

func test_fast_enemy_posture_break() -> void:
	var state: RunState = RunStateScript.new()
	var knife := state._make_enemy("knife", state.player_pos + Vector2(0, -90), 8)
	knife["action"] = state._melee_action(0.88, 0.28, 0.46, 92.0, 1, Vector2.DOWN)
	state._apply_posture_damage(knife, 2.0)
	assert(String(Dictionary(knife["action"])["kind"]) == "stagger")
	assert(float(knife["posture"]) == 0.0)

func test_grounded_heavy_resists_break() -> void:
	var state: RunState = RunStateScript.new()
	var brute := state._make_enemy("brute", state.player_pos + Vector2(0, -130), 16)
	brute["action"] = state._melee_action(2.55, 1.02, 1.52, 158.0, 4, Vector2.DOWN)
	brute["action"]["elapsed"] = 1.10
	state._apply_posture_damage(brute, 20.0)
	assert(String(Dictionary(brute["action"])["kind"]) == "melee")

func test_navigation_routes_around_wall() -> void:
	var state: RunState = RunStateScript.new(false)
	state.world_size = Vector2(1200, 1200)
	state.current_layer = "test"
	state.floor_shapes = [{"kind": "circle", "center": Vector2(600, 600), "radius": 560.0, "layer": "test", "part_id": 0}]
	state.player_pos = Vector2(850, 600)
	state.walls = [Rect2(525, 300, 150, 600)]
	state.enemies.clear()
	state._build_navigation()
	var blade := state._make_enemy("blade", Vector2(350, 600), 7)
	state.enemies = [blade]
	var start_cell := state._nearest_open_cell(state._world_to_nav(Vector2(blade["pos"])))
	var finish_cell := state._nearest_open_cell(state._world_to_nav(state.player_pos))
	var path := state.navigation.get_id_path(start_cell, finish_cell, true)
	assert(not path.is_empty() and Vector2i(path[path.size() - 1]) == finish_cell)
	var bends_around_wall := false
	for cell in path:
		if absf(state.navigation.get_point_position(cell).y - 600.0) > 250.0: bends_around_wall = true
	assert(bends_around_wall)

func test_isometric_projection_round_trip() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.board_area = Rect2(0, 0, 720, 960)
	board.view_mode = "isometric"
	board._update_projection()
	var world_point := Vector2(237.5, 1044.25)
	var restored: Vector2 = board._screen_to_world(board._world_to_screen(world_point))
	assert(restored.distance_to(world_point) < 0.01)
	var before: float = board.state.simulation_time
	board._toggle_view()
	assert(is_equal_approx(board.state.simulation_time, before))
	board.free()

func test_isometric_is_default() -> void:
	var board = GameBoardScript.new()
	assert(board.view_mode == "isometric")
	board.free()

func test_projected_combat_footprints_match_each_view() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot()
	board.board_area = Rect2(0, 0, 720, 960)
	board.view_mode = "isometric"
	board._update_projection()
	var iso_points: PackedVector2Array = board._project_world_circle(board.state.player_pos, board.state.PLAYER_RADIUS)
	var iso_bounds := Rect2(iso_points[0], Vector2.ZERO)
	for point in iso_points: iso_bounds = iso_bounds.expand(point)
	assert(iso_bounds.size.x > iso_bounds.size.y * 1.8)
	assert(board._actor_visual_center(board.state.player_pos, board.state.PLAYER_RADIUS).y < board._world_to_screen(board.state.player_pos).y)
	board.view_mode = "top_down"
	board._update_projection()
	var top_points: PackedVector2Array = board._project_world_circle(board.state.player_pos, board.state.PLAYER_RADIUS)
	var top_bounds := Rect2(top_points[0], Vector2.ZERO)
	for point in top_points: top_bounds = top_bounds.expand(point)
	assert(absf(top_bounds.size.x - top_bounds.size.y) < 0.1)
	assert(board._actor_visual_center(board.state.player_pos, board.state.PLAYER_RADIUS).distance_to(board._world_to_screen(board.state.player_pos)) < 0.01)
	board.free()

func test_compact_actor_model_and_facing_marker() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot()
	board.board_area = Rect2(0, 0, 720, 960)
	board.view_mode = "isometric"
	board._update_projection()
	var collision_radius: float = board.state.PLAYER_RADIUS * board.world_scale
	var body_radius: float = board._actor_body_radius(board.state.PLAYER_RADIUS)
	assert(body_radius < collision_radius * 0.60)
	var foot := board._world_to_screen(board.state.player_pos)
	var body := board._actor_visual_center(board.state.player_pos, board.state.PLAYER_RADIUS)
	assert(foot.distance_to(body) < collision_radius * 0.36)
	var facing := Vector2(0.6, -0.8).normalized()
	var marker: PackedVector2Array = board._actor_marker_points(body, facing, body_radius)
	assert(marker.size() == 3)
	assert((marker[0] - body).dot(facing) > body_radius * 1.7)
	assert(marker[1].distance_to(body) > body_radius)
	board.view_mode = "top_down"
	board._update_projection()
	assert(board._actor_body_radius(board.state.PLAYER_RADIUS) < board.state.PLAYER_RADIUS * board.world_scale * 0.65)
	board.free()

func test_isometric_actor_pick_uses_visible_body() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.state.enemies.clear()
	var enemy: Dictionary = board.state._make_enemy("blade", board.state.player_pos + Vector2.UP * 110.0, 5)
	board.state.enemies.append(enemy)
	board.state._update_exploration(true)
	board.visual = board.state.snapshot()
	board.board_area = Rect2(0, 0, 720, 960)
	board.view_mode = "isometric"
	board._update_projection()
	var body := board._actor_visual_center(Vector2(enemy["pos"]), float(enemy["radius"]))
	var picked: Dictionary = board._enemy_near(body, 8.0)
	assert(not picked.is_empty() and int(picked["id"]) == int(enemy["id"]))
	board.free()

func test_desktop_movement_tracks_screen_directions() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot()
	board.board_area = Rect2(0, 0, 1280, 800)
	board.view_mode = "isometric"
	board._update_projection()
	var world_up: Vector2 = board._desktop_direction_for_key(KEY_W)
	assert(board._screen_direction(world_up).dot(Vector2.UP) > 0.999)
	board.view_mode = "top_down"
	board._update_projection()
	assert(board._desktop_direction_for_key(KEY_W).dot(Vector2.UP) > 0.999)
	board.free()

func test_desktop_held_keys_combine_diagonally() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot()
	board.board_area = Rect2(0, 0, 1280, 800)
	board.view_mode = "isometric"
	board._update_projection()
	board._set_desktop_movement_key(KEY_UP, true)
	board._set_desktop_movement_key(KEY_RIGHT, true)
	var world_direction: Vector2 = board._desktop_held_direction()
	assert(board._screen_direction(world_direction).dot(Vector2(1.0, -1.0).normalized()) > 0.999)
	board._set_desktop_movement_key(KEY_UP, false)
	assert(board._screen_direction(board._desktop_held_direction()).dot(Vector2.RIGHT) > 0.999)
	board._set_desktop_movement_key(KEY_RIGHT, false)
	assert(board._desktop_held_direction().is_zero_approx())
	board.free()

func test_playback_interpolates_between_simulation_steps() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	var first: Dictionary = board.state.snapshot(true)
	var second: Dictionary = first.duplicate(true)
	first["player_pos"] = Vector2(10.0, 20.0)
	second["player_pos"] = Vector2(30.0, 40.0)
	first["player_action"] = {"kind": "move", "elapsed": 0.0}
	second["player_action"] = {"kind": "move", "elapsed": 1.0}
	var enemy_first: Dictionary = board.state._make_enemy("blade", Vector2(50.0, 60.0), 99)
	var enemy_second: Dictionary = enemy_first.duplicate(true)
	enemy_second["pos"] = Vector2(70.0, 80.0)
	enemy_first["action"] = {"kind": "move", "elapsed": 0.0}
	enemy_second["action"] = {"kind": "move", "elapsed": 1.0}
	first["enemies"] = [enemy_first]
	second["enemies"] = [enemy_second]
	board.timeline.clear()
	board.timeline.append(first)
	board.timeline.append(second)
	board.playback_index = 0
	var visual: Dictionary = board._interpolate_playback_snapshot(0.5)
	assert(Vector2(visual["player_pos"]).distance_to(Vector2(20.0, 30.0)) < 0.01)
	assert(is_equal_approx(float(Dictionary(visual["player_action"])["elapsed"]), 0.5))
	var enemy: Dictionary = Array(visual["enemies"])[0]
	assert(Vector2(enemy["pos"]).distance_to(Vector2(60.0, 70.0)) < 0.01)
	assert(is_equal_approx(float(Dictionary(enemy["action"])["elapsed"]), 0.5))
	board.free()

func test_actions_stream_without_precomputation() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.desktop_controls = false
	board.visual = board.state.snapshot(true)
	var before: float = board.state.simulation_time
	assert(board.state.request_attack(board.state.player_pos + Vector2.RIGHT * 120.0, false))
	board._begin_streamed_action(true)
	assert(board.streaming_action and board.playing)
	assert(board.timeline.is_empty())
	assert(is_equal_approx(board.state.simulation_time, before))
	board._process(1.0 / 60.0)
	assert(board.state.simulation_time > before)
	assert(String(board.state.player_action["kind"]) == "attack")
	for index in range(90): board._process(1.0 / 60.0)
	assert(not board.streaming_action and not board.playing)
	assert(String(board.state.player_action["kind"]) == "idle")
	board.free()

func test_streaming_caps_realtime_catchup() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.desktop_controls = false
	board.visual = board.state.snapshot(true)
	var before: float = board.state.simulation_time
	assert(board.state.request_attack(board.state.player_pos + Vector2.RIGHT * 120.0, false))
	board._begin_streamed_action(true)
	board._process(1.0)
	assert(board.state.simulation_time - before <= board.state.SIM_DT * float(board.MAX_SIM_TICKS_PER_FRAME) + 0.0001)
	assert(float(board.state.performance_metrics["dropped_realtime_ms"]) > 0.0)
	board.free()

func test_presentation_frames_reuse_storage() -> void:
	var state: RunState = RunStateScript.new()
	var current = PresentationFrameScript.new()
	var following = PresentationFrameScript.new()
	var blended = PresentationFrameScript.new()
	var first_capture: Dictionary = current.capture(state)
	var first_enemy_array: Array = first_capture["enemies"]
	assert(state.request_move(Vector2.RIGHT, 12.0, false))
	state.advance_streamed_action_tick()
	following.capture(state)
	var first_blend: Dictionary = blended.blend(current, following, 0.5)
	var blended_enemy_array: Array = first_blend["enemies"]
	var second_blend: Dictionary = blended.blend(current, following, 0.75)
	assert(is_same(first_blend, second_blend))
	assert(is_same(blended_enemy_array, second_blend["enemies"]))
	current.capture(state)
	assert(is_same(first_capture, current.data))
	assert(is_same(first_enemy_array, current.data["enemies"]))
	assert(Vector2(second_blend["player_pos"]).distance_to(state.player_pos) < 12.0)

func test_discovery_uses_cached_grid_visibility() -> void:
	var state: RunState = RunStateScript.new()
	state._visibility_opaque_cells = {Vector2i(1, 0): true}
	assert(not state._visibility_cells_have_line(Vector2i.ZERO, Vector2i(2, 0)))
	assert(state._visibility_cells_have_line(Vector2i.ZERO, Vector2i(1, 0)))
	state._visibility_anchor_cell = state._visibility_cell(state.player_pos)
	state.performance_metrics["visibility_ms"] = -1.0
	state._update_exploration()
	assert(float(state.performance_metrics["visibility_ms"]) < 0.0)
	state.player_pos += Vector2(state.VISIBILITY_CELL, 0.0)
	state._update_exploration()
	assert(float(state.performance_metrics["visibility_ms"]) >= 0.0)

func test_floor_cache_appends_discovery_incrementally() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.state.discovered_cells = {Vector2i(8, 8): true}
	board.state.discovery_epoch += 1
	board.state.discovery_revision += 1
	board.state.discovery_log.clear()
	board._refresh_floor_geometry_cache()
	var chunk := Vector2i(1, 1)
	var existing_chunk: Array = board._floor_cells_by_chunk[chunk]
	assert(board._floor_iso_geometry.size() == 1)
	var added := Vector2i(9, 8)
	board.state.discovered_cells[added] = true
	board.state.discovery_log.append(added)
	board.state.discovery_revision += 1
	board._refresh_floor_geometry_cache()
	assert(board._floor_iso_geometry.size() == 2)
	assert(is_same(existing_chunk, board._floor_cells_by_chunk[chunk]))
	board.free()

func test_autosave_waits_for_quiet_input() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.desktop_controls = false
	board.autosave_pending = true
	board.autosave_elapsed = board.AUTOSAVE_DELAY
	board.pointer_down = true
	board._process(board.AUTOSAVE_QUIET_DELAY + 0.02)
	assert(not board.autosave_deferred)
	board.pointer_down = false
	board._process(board.AUTOSAVE_QUIET_DELAY + 0.02)
	assert(board.autosave_deferred)
	board.autosave_pending = false
	board.free()

func test_save_payload_omits_regenerated_world_geometry() -> void:
	var state: RunState = RunStateScript.new()
	var payload := state._build_save_payload()
	assert(not payload.has("floor_shapes"))
	assert(not payload.has("terrain_features"))
	assert(not payload.has("connections"))
	assert(not payload.has("world_layers"))
	assert(Array(payload["enemies"]).size() == state.enemies.size())
	assert(Dictionary(payload["discovered_cells_by_layer"]).has(state.current_layer))
	assert(var_to_bytes(payload).size() < var_to_bytes(state.snapshot()).size())

func test_desktop_landscape_layout() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot()
	board.desktop_controls = true
	board.size = Vector2(1280, 800)
	board._create_seed_input()
	board._layout()
	assert(board.board_rect.size.x > 900.0 and board.board_rect.size.y == 800.0)
	for rect in board.buttons.values(): assert(Rect2(Vector2.ZERO, board.size).encloses(Rect2(rect)))
	board.free()

func test_close_camera_tracks_player() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.state.player_pos = Vector2(800, 1100)
	board.visual = board.state.snapshot()
	board.board_area = Rect2(0, 0, 720, 960)
	board.view_mode = "top_down"
	board._update_projection()
	assert(board.world_scale > 0.9)
	assert(board._world_to_screen(board.state.player_pos).distance_to(board.board_rect.get_center()) < 0.01)
	board.free()

func test_shield_front_arc() -> void:
	var state: RunState = RunStateScript.new()
	state.walls.clear()
	var shield := state._make_enemy("shield", state.player_pos + Vector2(0, -95), 10)
	shield["facing"] = Vector2.DOWN
	state.enemies = [shield]
	assert(state.request_attack(Vector2(shield["pos"])))
	assert(int(state.enemies[0]["hp"]) == 10)

func test_new_enemy_roles() -> void:
	var state: RunState = RunStateScript.new()
	state.walls.clear()
	var hound := state._make_enemy("hound", state.player_pos + Vector2(0, -220), 6)
	state._choose_enemy_action(hound)
	assert(String(Dictionary(hound["action"])["kind"]) == "charge")
	var hexer := state._make_enemy("hexer", state.player_pos + Vector2(0, -400), 7)
	state._choose_enemy_action(hexer)
	assert(String(Dictionary(hexer["action"])["kind"]) == "hex")
	var brute := state._make_enemy("brute", state.player_pos + Vector2(0, -140), 16)
	state._choose_enemy_action(brute)
	assert(String(Dictionary(brute["action"])["kind"]) == "melee")
	assert(float(Dictionary(brute["action"])["duration"]) > 2.4)
	var captain := state._make_enemy("captain", Vector2(120, 120), 12)
	state.enemies = [captain]
	var blade := state._make_enemy("blade", Vector2(300, 300), 7)
	assert(state._enemy_move_speed(blade) > 190.0)

func test_progressive_expedition_rooms() -> void:
	for seed in [11, 22, 33, 44, 55, 739391]:
		var layout: Dictionary = FloorGeneratorScript.generate(seed, false)
		var areas: Array = layout["areas"]
		var connections: Array = layout["connections"]
		assert(areas.size() == 7)
		assert(connections.size() == 6)
		assert(String(areas[0]["kind"]) == "start")
		assert(String(areas[6]["kind"]) == "boss")
		for index in range(7): assert(int(Dictionary(areas[index])["progression_part"]) == index + 1)
		for connection in connections:
			assert(not bool(connection["shortcut"]))
		var kinds: Array[String] = []
		for templates in Dictionary(layout["encounters"]).values():
			for enemy in Array(templates): kinds.append(String(enemy["kind"]))
		assert(kinds.has("warden") and kinds.has("brute") and kinds.has("hexer"))

func test_required_passages_have_generous_clearance() -> void:
	# This is intentionally much wider than the player's collision radius. A
	# generated route should remain comfortable rather than merely possible.
	const TEST_CLEARANCE_RADIUS := 74.0
	for seed in range(1, 101):
		var layout: Dictionary = FloorGeneratorScript.generate(seed * 7919)
		for connection in Array(layout["connections"]):
			if bool(connection["shortcut"]): continue
			var path: Array = connection.get("path", [])
			var walls: Array = Dictionary(layout["layer_walls"]).get(String(connection["layer"]), [])
			for segment_index in range(path.size() - 1):
				var start := Vector2(path[segment_index])
				var finish := Vector2(path[segment_index + 1])
				var steps := maxi(1, int(ceil(start.distance_to(finish) / 18.0)))
				for step in range(steps + 1):
					var point := start.lerp(finish, float(step) / float(steps))
					for wall in walls:
						assert(not _test_circle_intersects_rect(point, TEST_CLEARANCE_RADIUS, Rect2(wall)))

func _test_circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(nearest) < radius * radius

func test_overlay_map_passes_input_through() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot()
	board.size = Vector2(720, 1280)
	board.board_area = Rect2(0, 0, 720, 960)
	board._update_projection()
	board.map_open = true
	board.state.map_presentation = "overlay"
	board._pointer_pressed(board.board_rect.get_center())
	assert(board.pointer_down)
	board.pointer_down = false
	board.state.map_presentation = "full"
	board._pointer_pressed(board.board_rect.get_center())
	assert(not board.pointer_down)
	board.free()

func test_region_streaming_limits_active_world() -> void:
	var expedition: RunState = RunStateScript.new(false)
	expedition.start_run("duelist", "expedition", 717)
	expedition._build_enemy_spatial_index()
	assert(expedition.loaded_region_ids.size() <= 3)
	assert(expedition._loaded_floor_shapes.size() < expedition.floor_shapes.size())
	assert(int(expedition.performance_metrics["active_enemies"]) < int(expedition.performance_metrics["resident_enemies"]))
	var first_loaded := expedition.loaded_region_ids.keys()
	expedition.current_area_id = 4
	expedition.player_pos = Vector2(expedition.areas[4]["center"])
	expedition._apply_shortcut_world_state()
	assert(expedition.loaded_region_ids.has(3) and expedition.loaded_region_ids.has(4) and expedition.loaded_region_ids.has(5))
	assert(not expedition.loaded_region_ids.has(int(first_loaded[0])))
	var campaign: RunState = RunStateScript.new(false)
	campaign.start_run("duelist", "campaign_lab", 99117)
	assert(not campaign.loaded_region_ids.is_empty())
	assert(campaign._loaded_floor_shapes.size() < campaign.floor_shapes.size())

func test_full_map_supports_arbitrary_discovered_layers() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.size = Vector2(1000, 800)
	board.board_rect = Rect2(Vector2(20, 20), Vector2(960, 760))
	board.state.world_layers.clear()
	board.state.discovered_cells_by_layer.clear()
	for index in range(7):
		var layer_id := "layer_%d" % index
		board.state.world_layers[layer_id] = {"name": "Depth %d" % index}
		board.state.discovered_cells_by_layer[layer_id] = {Vector2i(index, index): true}
	board.state.current_layer = "layer_0"
	board.state.discovered_cells = Dictionary(board.state.discovered_cells_by_layer["layer_0"])
	board.map_view_layer = "layer_0"
	assert(board._available_map_layers().size() == 7)
	board.map_layer_page = 0
	board._update_map_layer_controls()
	assert(board.map_layer_rects.size() == 5)
	board.map_layer_page = 1
	board._update_map_layer_controls()
	assert(board.map_layer_rects.size() == 2)
	board.free()

func test_camera_culls_offscreen_world() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.state.start_run("duelist", "campaign_lab", 1784339476686)
	board.visual = board.state.snapshot()
	board.board_area = Rect2(0, 0, 720, 960)
	board.view_mode = "top_down"
	board._update_projection()
	assert(board._world_point_on_camera(board.state.player_pos))
	assert(not board._world_point_on_camera(Vector2(7000, 800)))
	assert(board._world_rect_on_camera(Rect2(board.state.player_pos - Vector2.ONE * 40.0, Vector2.ONE * 80.0)))
	assert(not board._world_rect_on_camera(Rect2(6900, 700, 100, 100)))
	var bounds: Rect2i = board._camera_cell_bounds()
	assert(bounds.has_point(board.state._visibility_cell(board.state.player_pos)))
	assert(bounds.size.x * bounds.size.y < 1200)
	board.free()

func test_lightweight_timeline_snapshots() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "campaign_lab", 717)
	var full := state.snapshot()
	var light := state.snapshot(true)
	assert(not Dictionary(full["discovered_cells"]).is_empty())
	assert(Dictionary(light["discovered_cells"]).is_empty())
	assert(not Array(full["walls"]).is_empty() and Array(light["walls"]).is_empty())
	assert(Array(light["enemies"]).size() < state.enemies.size())

func test_generated_rooms_have_no_shields() -> void:
	var state: RunState = RunStateScript.new()
	assert(state.WORLD_SIZE.x >= 5000.0 and state.WORLD_SIZE.y >= 4400.0)
	for enemy in state.enemies: assert(String(enemy["kind"]) != "shield")

func test_room_reward_progression() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "expedition", 101)
	state.carried_xp = state.next_upgrade_cost()
	for enemy in state.enemies:
		if int(enemy["area_id"]) == 1: enemy["hp"] = 0
	state._remove_dead_enemies()
	state.carried_xp = state.next_upgrade_cost()
	state.current_area_id = 1
	state.player_pos = Vector2(state.areas[2]["center"])
	state._update_exploration(true)
	assert(state.upgrade_pending and state.upgrade_context == "area_exit")
	assert(state.upgrade_choices.size() == 3)
	var choice := state.upgrade_choices[0]
	assert(state.choose_upgrade(choice))
	assert(not state.upgrade_pending and state.upgrades.has(choice) and state.carried_xp == 0)
	assert(state.upgrade_count == 1 and state.next_upgrade_cost() == 10)
	state.start_run("guardian", "campaign_lab", 102)
	state.carried_xp = 16
	state.player_pos = state.bonfire_pos
	state.player_hp = 1
	assert(state.activate_waystone() and not state.upgrade_pending and state.player_hp == state.player_max_hp)
	assert(state.secured_xp == 16 and state.can_learn_at_waystone())
	assert(state.learn_at_waystone() and state.upgrade_pending and state.upgrade_context == "waystone")
	assert(state.choose_upgrade(state.upgrade_choices[0]))
	assert(state.upgrade_pending and state.carried_xp == 10)
	assert(state.choose_upgrade(state.upgrade_choices[0]))
	assert(state.upgrade_count == 2 and state.carried_xp == 0)

func test_mode_policies_and_death() -> void:
	var expedition: RunState = RunStateScript.new(false)
	expedition.start_run("duelist", "expedition", 201)
	assert(expedition.mode_id == "expedition")
	assert(String(expedition.mode_rules()["death_policy"]) == "end_run")
	assert(not bool(expedition.mode_rules()["waystone_available"]))
	assert(expedition.connections.size() == 6)
	for connection in expedition.connections: assert(not bool(connection["shortcut"]))
	assert(not expedition.unlock_shortcut() and not expedition.activate_waystone())
	expedition.carried_xp = 9
	expedition._begin_death()
	assert(expedition.death_pending and not bool(expedition.lost_xp["active"]))
	assert(expedition.return_after_death())
	assert(not expedition.run_active and expedition.run_failed)

	var campaign: RunState = RunStateScript.new(false)
	campaign.start_run("duelist", "campaign_lab", 202)
	assert(campaign.mode_id == "campaign_lab")
	assert(String(campaign.mode_rules()["death_policy"]) == "waystone")
	assert(bool(campaign.mode_rules()["waystone_available"]))
	assert(campaign.connections.size() == 9)
	assert(campaign.waystones.size() == 3 and campaign.shortcuts.size() == 2 and campaign.transitions.size() == 2)
	assert(campaign.connections.filter(func(connection: Dictionary) -> bool: return bool(connection["shortcut"])).size() == 2)
	campaign.carried_xp = 9
	campaign._begin_death()
	assert(bool(campaign.lost_xp["active"]) and int(campaign.lost_xp["amount"]) == 9)
	assert(campaign.return_after_death() and campaign.run_active and not campaign.run_failed)

func test_layered_friendly_forest_topology() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "campaign_lab", 212)
	assert(state.current_layer == "forest_surface")
	assert(state.current_ground_color().is_equal_approx(Color("82b86d")))
	assert(state.areas.filter(func(area: Dictionary) -> bool: return String(area.get("layer", "")) == "ruin_depths").size() == 3)
	var second: Dictionary = state.waystones[1]
	state.player_pos = Vector2(second["pos"])
	assert(state.activate_waystone() and state.active_waystone_id == "moss")
	state._begin_death()
	assert(state.return_after_death() and state.player_pos.distance_to(Vector2(second["pos"])) < 200.0)
	var stairs: Dictionary = state.transitions[0]
	state.player_pos = Vector2(stairs["from_pos"])
	assert(state.use_transition() and state.current_layer == "ruin_depths")
	assert(state.current_ground_color().is_equal_approx(Color("596653")))
	state.player_pos = Vector2(stairs["to_pos"])
	assert(state.use_transition() and state.current_layer == "forest_surface")
	var ladder: Dictionary = state.transitions[1]
	state.current_layer = "ruin_depths"
	state.player_pos = Vector2(ladder["from_pos"])
	assert(state.use_transition() and state.current_layer == "forest_surface")
	var ruin_shortcut: Dictionary = state.shortcuts.filter(func(item: Dictionary) -> bool: return String(item["id"]) == "dawn_ruin_return_v3")[0]
	for shortcut in state.shortcuts:
		assert(Vector2(shortcut["unlock_pos"]).distance_to(Vector2(shortcut["near_pos"])) > 115.0)
		state.player_pos = Vector2(shortcut["near_pos"])
		assert(state._nearby_locked_shortcut().is_empty())
	state.player_pos = Vector2(ruin_shortcut["unlock_pos"])
	assert(state.unlock_shortcut() and bool(ruin_shortcut["unlocked"]))
	state.walls.clear()
	var other_layer_enemy := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 80.0, 7)
	other_layer_enemy["layer"] = "ruin_depths"
	state.enemies = [other_layer_enemy]
	assert(state.request_attack(Vector2(other_layer_enemy["pos"])))
	assert(int(other_layer_enemy["hp"]) == 7)

func test_waystone_requires_deliberate_activation() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "campaign_lab", 203)
	state.carried_xp = 6
	state.player_hp = 2
	state.player_pos = state.bonfire_pos + Vector2.RIGHT * (state.WAYSTONE_RANGE + 1.0)
	assert(not state.activate_waystone())
	assert(state.player_hp == 2 and state.secured_xp == 0)
	state.player_pos = state.bonfire_pos
	assert(state.player_hp == 2 and state.secured_xp == 0)
	assert(state.interaction_label() == "REST")
	assert(state.request_context_action())
	assert(state.player_hp == state.player_max_hp and state.secured_xp == 6)
	assert(state.can_learn_at_waystone())
	assert(int(state.last_anchor_report["xp"]) == 6 and bool(state.last_anchor_report["restored"]))

func test_shortcut_and_waystone_persistence() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("reaver", "campaign_lab", 303)
	var original_count := state.enemies.size()
	state.player_pos = state.shortcut_start_pos
	assert(not state.unlock_shortcut())
	state.player_pos = state.shortcut_unlock_pos
	assert(state.unlock_shortcut() and state.shortcut_unlocked)
	assert(not state.walls.has(state.shortcut_gate))
	state._begin_death()
	assert(state.return_after_death() and not state.shortcut_unlocked)
	state.player_pos = state.shortcut_unlock_pos
	assert(state.unlock_shortcut() and state.shortcut_unlocked)
	state.carried_xp = 5
	var anchored_cell := Vector2i(77, 77)
	state.discovered_cells[anchored_cell] = true
	state.player_hp = 1
	state.potions = 0
	state.enemies[0]["hp"] = 0
	state._remove_dead_enemies()
	state.player_pos = state.bonfire_pos
	assert(state.activate_waystone())
	assert(state.player_hp == state.player_max_hp and state.potions == 1)
	assert(state.enemies.size() == original_count and state.shortcut_unlocked)
	assert(state.carried_xp >= 5 and state.secured_xp == state.carried_xp)
	state.carried_xp += 3
	state.discovered_cells[Vector2i(88, 88)] = true
	state._begin_death()
	assert(int(state.lost_xp["amount"]) == 3)
	assert(state.return_after_death())
	assert(state.shortcut_unlocked and state.discovered_cells.has(anchored_cell))
	assert(not state.discovered_cells.has(Vector2i(88, 88)))

func test_provisional_progress_accounting() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "campaign_lab", 304)
	state.carried_xp = 5
	var first_trace := Vector2i(91, 91)
	state.discovered_cells[first_trace] = true
	assert(state.provisional_xp() == 5 and state.unanchored_discovery_count() == 1)
	assert(state.has_unanchored_progress())
	state.player_pos = state.bonfire_pos
	assert(state.activate_waystone())
	assert(state.secured_xp == 5 and state.provisional_xp() == 0)
	assert(int(state.last_anchor_report["xp"]) == 5 and int(state.last_anchor_report["memories"]) >= 1)
	assert(state.effects.any(func(effect: Dictionary) -> bool: return String(effect["kind"]) == "anchor"))
	state.carried_xp += 3
	state.discovered_cells[Vector2i(92, 92)] = true
	state.shortcuts[0]["unlocked"] = true
	state.shortcut_unlocked = true
	state.player_pos += Vector2.UP * 180.0
	state._begin_death()
	assert(int(state.death_report["retained_xp"]) == 5)
	assert(int(state.death_report["shadow_xp"]) == 3)
	assert(int(state.death_report["forgotten_cells"]) == 1)
	assert(bool(state.death_report["shortcut_forgotten"]))
	assert(not bool(state.death_report["previous_shadow_erased"]))
	assert(state.return_after_death())
	state.carried_xp += 2
	state._begin_death()
	assert(int(state.death_report["shadow_xp"]) == 2)
	assert(bool(state.death_report["previous_shadow_erased"]))
	assert(state.return_after_death())
	var shadow_pos := Vector2(state.lost_xp["pos"])
	state.player_pos = shadow_pos
	state._try_recover_xp()
	assert(state.provisional_xp() == 2 and state.message.contains("at risk until anchored"))
	assert(state.effects.any(func(effect: Dictionary) -> bool: return String(effect["kind"]) == "recover"))

func test_visibility_memory_and_awareness() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "auto", 404)
	var discovered_before := state.discovered_cells.size()
	var old_pos := state.player_pos
	state.player_pos += Vector2(0, -120)
	state._update_exploration(true)
	assert(state.discovered_cells.size() >= discovered_before)
	assert(state.is_discovered(old_pos))
	var enemy := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 220.0, 7, 1)
	enemy["facing"] = Vector2.RIGHT
	state.enemies = [enemy]
	state._emit_sound(state.player_pos, 300.0)
	var frozen := state.simulation_time
	state.snapshot()
	assert(state.simulation_time == frozen and String(enemy["awareness"]) == "idle")
	state._update_enemy_awareness(enemy, 0.1)
	assert(String(enemy["awareness"]) == "suspicious")

func test_xp_death_recovery() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "campaign_lab", 505)
	state.carried_xp = 9
	var death_pos := state.player_pos + Vector2.UP * 80.0
	state.player_pos = death_pos
	state._begin_death()
	assert(state.death_pending and state.carried_xp == 0)
	assert(bool(state.lost_xp["active"]) and int(state.lost_xp["amount"]) == 9)
	assert(state.return_after_death())
	state.player_pos = death_pos
	state._try_recover_xp()
	assert(state.carried_xp == 9 and not bool(state.lost_xp["active"]))
	state.carried_xp = 7
	state._begin_death()
	assert(state.return_after_death())
	state.carried_xp = 3
	state.player_pos += Vector2.RIGHT * 90.0
	state._begin_death()
	assert(int(state.lost_xp["amount"]) == 3)

func test_hex_hazard() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies.clear()
	state.hazards = [{"kind": "hex", "pos": state.player_pos, "radius": 100.0, "elapsed": 0.0, "trigger_at": 0.10, "duration": 0.30, "damage": 2, "source_id": 99, "triggered": false}]
	assert(state.request_wait(0.20))
	assert(state.hazards.size() == 1 and bool(state.hazards[0]["triggered"]))
	var saw_hex := false
	for effect in state.effects:
		if String(effect["kind"]) == "hex": saw_hex = true
	assert(saw_hex)

func test_save_round_trip() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("guardian", "campaign_lab", 606)
	state.player_hp -= 2
	state.carried_xp = 13
	state.player_pos = state.shortcut_unlock_pos
	assert(state.unlock_shortcut())
	state.player_pos = state.bonfire_pos
	assert(state.activate_waystone())
	var path := "user://waystone-test-expedition.save"
	assert(state.save_run(path))
	var restored: RunState = RunStateScript.new(false)
	assert(restored.load_run(path))
	assert(restored.player_hp == state.player_hp)
	assert(restored.mode_id == "campaign_lab" and restored.progression_mode == "waystone" and restored.carried_xp == 13)
	assert(restored.secured_xp == 13 and restored.shortcut_unlocked and restored.run_seed == 606)

func test_version_one_save_migration() -> void:
	var state: RunState = RunStateScript.new()
	var path := "user://waystone-test-v1-migration.save"
	assert(state.save_run(path))
	var reader := FileAccess.open(path, FileAccess.READ)
	var payload: Dictionary = reader.get_var(true)
	payload["save_version"] = 1
	payload["lunge_cooldown"] = 2.25
	payload.erase("skill_cooldown")
	payload["enemies"].append(state._make_enemy("shield", Vector2(500, 500), 10))
	for enemy in Array(payload["enemies"]):
		enemy.erase("posture")
		enemy.erase("posture_max")
		enemy.erase("posture_recovery_delay")
	reader = null
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(payload, true)
	writer = null
	var restored: RunState = RunStateScript.new(false)
	assert(restored.load_run(path))
	assert(not restored.run_active)
	assert(restored.loadout_id == state.loadout_id and restored.mode_id == "expedition" and restored.progression_mode == "area_exit")

func test_version_three_attack_migration() -> void:
	var state: RunState = RunStateScript.new()
	var path := "user://waystone-test-v3-attack-migration.save"
	assert(state.save_run(path))
	var reader := FileAccess.open(path, FileAccess.READ)
	var payload: Dictionary = reader.get_var(true)
	reader = null
	payload["save_version"] = 3
	payload["player_action"] = state._melee_action(1.2, 0.3, 0.7, 136.0, 3, Vector2.UP, "diagonal_cut", "attack")
	var old_enemy: Dictionary = payload["enemies"][0]
	old_enemy["action"] = state._melee_action(1.45, 0.52, 0.82, 128.0, 2, Vector2.DOWN)
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(payload, true)
	writer = null
	var restored: RunState = RunStateScript.new(false)
	assert(restored.load_run(path))
	assert(not restored.run_active)

func test_version_twelve_world_grammar_migration() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "campaign_lab", 99117)
	state.carried_xp = 11
	state.secured_xp = 5
	var path := "user://waystone-test-v12-world-migration.save"
	assert(state.save_run(path))
	var reader := FileAccess.open(path, FileAccess.READ)
	var payload: Dictionary = reader.get_var(true)
	reader = null
	payload["save_version"] = 12
	payload["enemies"] = [state._make_enemy("knife", Vector2(-500, -500), 1, 1)]
	payload["discovered_cells_by_layer"] = {"forest_surface": {Vector2i(99, 99): true}}
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(payload, true)
	writer = null
	var restored: RunState = RunStateScript.new(false)
	assert(restored.load_run(path))
	assert(restored.carried_xp == 11 and restored.secured_xp == 5)
	assert(restored.enemies.size() > 1)
	assert(not restored.discovered_cells.has(Vector2i(99, 99)))
	assert(restored.message.contains("forest shifted"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_restart_restores_expedition() -> void:
	var state: RunState = RunStateScript.new()
	state.player_hp = 0
	state.dodge_cooldown = 2.0
	state.block_cooldown = 2.0
	state.projectiles.append({"pos": Vector2.ONE, "vel": Vector2.RIGHT, "radius": 1.0, "damage": 1, "source_id": 99})
	state.restart()
	assert(state.player_hp == state.player_max_hp)
	assert(is_zero_approx(state.simulation_time))
	assert(is_zero_approx(state.dodge_cooldown))
	assert(is_zero_approx(state.block_cooldown))
	assert(is_zero_approx(state.endure_cooldown))
	assert(state.projectiles.is_empty())
	assert(not state.enemies.is_empty())
	assert(String(state.enemies[0]["kind"]) == "blade")
	assert(state.upgrades.is_empty())
