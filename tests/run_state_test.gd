extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const GameBoardScript = preload("res://scripts/presentation/game_board.gd")
const PresentationFrameScript = preload("res://scripts/presentation/presentation_frame.gd")
const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")
const FloorGeneratorScript = preload("res://scripts/core/floor_generator.gd")

func _init() -> void:
	test_idle_freezes_time()
	test_rejuvenation_belt_rules()
	test_full_belt_swap_drops_displaced_stack()
	test_continuous_movement()
	test_attacks_are_long_commitments()
	test_sword_combo_uses_distinct_geometry_and_resets()
	test_combo_hold_commits_each_strike()
	test_combo_retouch_resumes_the_held_chain()
	test_attack_swipe_queues_movement()
	test_original_attack_swipe_keeps_combo_held()
	test_enemy_freezes_mid_action()
	test_polearm_reach_and_timing()
	test_projectile_motion()
	test_firebolt_tracking_is_limited()
	test_dodge_world_time()
	test_perfect_dodge()
	test_directional_block()
	test_block_stops_orphaned_projectile()
	test_endure_trades_health_for_strength()
	test_loadout_identities()
	test_shared_actor_and_weapon_foundation()
	test_warrior_weapon_arts()
	test_warrior_tracks_and_art_gate()
	test_signature_attack_roster()
	test_attack_geometry_boundaries()
	test_player_melee_hits_every_crossed_enemy()
	test_attack_geometry_stops_at_walls()
	test_projected_weapon_endpoints_round_trip()
	test_fast_enemy_posture_break()
	test_enemy_stagger_cannot_be_refreshed()
	test_grounded_heavy_resists_break()
	test_clean_opening_hit_preserves_a_defensive_choice()
	test_boar_momentum_armour_and_hound_interruptibility()
	test_active_weapon_contact_can_still_trade()
	test_hit_reaction_preserves_contact_and_interrupted_pose()
	test_player_reaction_cannot_be_stunlocked()
	test_line_of_sight_uses_exact_wall_intersection()
	test_navigation_routes_around_wall()
	test_enemy_facing_and_moving_follow_real_displacement()
	test_blocked_enemy_stops_claiming_movement_and_replans()
	test_crowded_enemy_steers_around_another_actor()
	test_flankers_reserve_interception_lanes()
	test_isometric_is_default()
	test_isometric_projection_round_trip()
	test_projected_combat_footprints_match_each_view()
	test_compact_actor_model_and_facing_marker()
	test_isometric_actor_pick_uses_visible_body()
	test_desktop_movement_tracks_screen_directions()
	test_desktop_held_keys_combine_diagonally()
	test_desktop_hold_attack_key()
	test_stamina_direct_attack_button()
	test_held_wait_repeats_until_release()
	test_melee_enemy_tap_intent_classifier()
	test_immediate_touch_drag_claims_movement()
	test_empty_hold_becomes_continuous_movement()
	test_valid_enemy_hold_still_begins_combo()
	test_playback_interpolates_between_simulation_steps()
	test_actions_stream_without_precomputation()
	test_streaming_caps_realtime_catchup()
	test_temporal_tint_eases_between_states()
	test_area_entry_title_uses_pacing_metadata()
	test_long_landmarks_are_ground_materials()
	test_presentation_frames_reuse_storage()
	test_desktop_landscape_layout()
	test_mobile_safe_area_layout()
	test_close_camera_tracks_player()
	test_camera_culls_offscreen_world()
	test_lightweight_timeline_snapshots()
	test_shield_front_arc()
	test_new_enemy_roles()
	test_back_half_expedition_roles()
	test_progressive_expedition_rooms()
	test_required_passages_have_generous_clearance()
	test_overlay_map_passes_input_through()
	test_region_streaming_limits_active_world()
	test_expedition_streaming_follows_route_graph()
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

func test_rejuvenation_belt_rules() -> void:
	var expedition: RunState = RunStateScript.new(false)
	expedition.start_run("warrior", "expedition", 717)
	assert(expedition.potions == 5)
	expedition.player_hp = 1
	assert(not expedition.has_infinite_potions())
	assert(expedition.request_potion())
	assert(expedition.player_hp == 26 and expedition.potions == 4)
	assert(expedition.consumable_slots.size() == 3)
	var campaign: RunState = RunStateScript.new(false)
	campaign.start_run("warrior", "campaign_lab", 717)
	campaign.potions = 0
	campaign.player_hp = 1
	assert(not campaign.has_infinite_potions())
	assert(not campaign.request_potion())

func test_full_belt_swap_drops_displaced_stack() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("wayfarer", "expedition", 717)
	var target: Dictionary = {}
	for pickup_value in state.world_pickups:
		var pickup: Dictionary = pickup_value
		if String(pickup.get("item_id", "")) == "firebomb":
			target = pickup
			break
	assert(not target.is_empty())
	state.player_pos = Vector2(target["pos"])
	state.consumable_slots = [{"id": "throwing_knife", "count": 2}, {"id": "smoke_vial", "count": 1}, {"id": "throwing_knife", "count": 1}]
	assert(not state.request_collect_nearby_pickup())
	assert(state.has_pending_pickup())
	assert(state.replace_pending_pickup(0))
	assert(String(state.consumable_slot(0).get("id", "")) == "firebomb")
	var dropped: Dictionary = {}
	for pickup_value in state.world_pickups:
		var pickup: Dictionary = pickup_value
		if String(pickup.get("id", "")).begins_with("discard_"):
			dropped = pickup
			break
	assert(String(dropped.get("item_id", "")) == "throwing_knife")
	assert(int(dropped.get("count", 0)) == 2 and Vector2(dropped.get("pos", Vector2.ZERO)).distance_to(state.player_pos) < 0.1)

func test_continuous_movement() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies.clear()
	var origin := state.player_pos
	assert(state.request_move(Vector2(0.6, -0.8), 123.0))
	assert(state.player_pos.distance_to(origin) > 28.0)
	assert(state.player_pos.distance_to(origin) < 38.0)
	assert(not is_equal_approx(state.player_pos.x, round(state.player_pos.x)))
	assert(state.simulation_time > 0.12 and state.simulation_time < 0.15)
	assert(state.last_timeline.size() >= 6)
	assert(state.is_player_ready())
	var frozen_time := state.simulation_time
	state.snapshot()
	assert(is_equal_approx(state.simulation_time, frozen_time))

func test_attacks_are_long_commitments() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "expedition", 739391, "encounter", "recovery")
	state.enemies.clear()
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0))
	assert(state.simulation_time >= 0.96)
	assert(state.last_timeline.size() >= 60)

func test_sword_combo_uses_distinct_geometry_and_resets() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "expedition", 739391, "encounter", "recovery")
	state.enemies.clear()
	# Held throughout so all three phases are actually reached and their authored
	# geometry can be compared.
	assert(state.request_combo(Vector2.UP, false, true))
	assert(String(state.player_action["kind"]) == "combo")
	var phases: Array = state.player_action["phases"]
	assert(String(Dictionary(phases[0])["technique"]) == "opening_cut")
	assert(String(Dictionary(phases[1])["technique"]) == "reverse_cut")
	assert(String(Dictionary(phases[2])["technique"]) == "turning_slash")
	assert(float(Dictionary(phases[2])["reach"]) > float(Dictionary(phases[1])["reach"]))
	assert(float(Dictionary(phases[2])["reach"]) == 158.0)
	assert(float(Dictionary(phases[0])["link"]) < float(Dictionary(phases[0])["end"]))
	assert(float(Dictionary(phases[1])["startup"]) >= float(Dictionary(phases[0])["link"]))
	assert(float(Dictionary(phases[1])["startup"]) < float(Dictionary(phases[0])["end"]))
	assert(String(AttackGeometryScript.technique("turning_slash")["motion"]) == "arc")
	assert(advance_until_elapsed(state, 2.40))
	assert(String(state.player_action["kind"]) == "combo")
	while state.advance_streamed_action_tick(): pass
	assert(state.is_player_ready() and state.simulation_time >= 2.45 and state.simulation_time < 2.55)

# Bounded equivalent of `while elapsed < target: advance()`. An action that ends
# before `target` resets its elapsed clock, so the naive loop spins forever the
# moment timing shifts. This fails the caller's assertion instead of hanging.
func advance_until_elapsed(state: RunState, target: float) -> bool:
	while float(state.player_action.get("elapsed", 0.0)) < target:
		if not state.advance_streamed_action_tick(): return false
	return true

func test_combo_hold_commits_each_strike() -> void:
	# Continuation is sampled at each authored link, so the number of strikes a
	# sequence commits is decided by how long the input stays live.
	var single: RunState = RunStateScript.new(false)
	single.start_run("warrior", "expedition", 739391, "encounter", "recovery")
	single.enemies.clear()
	assert(single.request_combo(Vector2.UP, false))
	single.set_attack_hold(false)
	assert(advance_until_elapsed(single, 0.70))
	assert(bool(single.player_action.get("terminal_recovery_locked", false)))
	assert(not single.resume_combo_hold())
	while single.advance_streamed_action_tick(): pass
	assert(single.is_player_ready() and single.simulation_time >= 0.97 and single.simulation_time < 1.05)

	var double: RunState = RunStateScript.new(false)
	double.start_run("warrior", "expedition", 739391, "encounter", "recovery")
	double.enemies.clear()
	assert(double.request_combo(Vector2.UP, false, true))
	assert(advance_until_elapsed(double, 0.90))
	assert(int(double.player_action.get("committed_phase", -1)) == 1)
	double.set_attack_hold(false)
	while double.advance_streamed_action_tick(): pass
	assert(double.is_player_ready() and double.simulation_time >= 1.68 and double.simulation_time < 1.74)

	var full: RunState = RunStateScript.new(false)
	full.start_run("warrior", "expedition", 739391, "encounter", "recovery")
	full.enemies.clear()
	assert(full.request_combo(Vector2.UP, false, true))
	while full.advance_streamed_action_tick(): pass
	assert(full.is_player_ready() and full.simulation_time >= 2.45 and full.simulation_time < 2.55)

func test_combo_retouch_resumes_the_held_chain() -> void:
	var retouched: RunState = RunStateScript.new()
	retouched.enemies.clear()
	# Begins from a tap, with no live input, then renews the touch before each
	# link. Each renewal restores a live input for the sample at that link.
	assert(retouched.request_combo(Vector2.UP, false))
	retouched.set_attack_hold(false)
	assert(advance_until_elapsed(retouched, 0.44))
	assert(retouched.resume_combo_hold())
	assert(advance_until_elapsed(retouched, 0.90))
	assert(int(retouched.player_action.get("committed_phase", -1)) == 1)
	retouched.set_attack_hold(false)
	assert(advance_until_elapsed(retouched, 1.10))
	assert(retouched.resume_combo_hold())
	while retouched.advance_streamed_action_tick(): pass
	assert(retouched.is_player_ready() and retouched.simulation_time >= 2.45 and retouched.simulation_time < 2.55)

func test_attack_swipe_queues_movement() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.board_rect = Rect2(Vector2.ZERO, Vector2(800.0, 600.0))
	board.size = Vector2(800.0, 600.0)
	assert(board.state.request_combo(Vector2.UP, false))
	board.playing = true
	board.pointer_down = true
	board.attack_pointer_held = true
	board.attack_touch_is_original = false
	board.touch_start = Vector2(250.0, 250.0)
	board._pointer_dragged(Vector2(330.0, 250.0))
	assert(not board.attack_pointer_held)
	assert(not bool(board.state.player_action.get("continue_held", true)))
	assert(board.queued_movement_after_attack and board.held_movement)
	board.free()

func test_original_attack_swipe_keeps_combo_held() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.board_rect = Rect2(Vector2.ZERO, Vector2(800.0, 600.0))
	board.size = Vector2(800.0, 600.0)
	# Started from a live hold, exactly as the board's hold path does. Previously
	# this passed because every combo was seeded held regardless of input; the
	# intent under test is that finger drift does not cancel an ongoing attack.
	assert(board.state.request_combo(Vector2.UP, false, true))
	board.playing = true
	board.pointer_down = true
	board.attack_pointer_held = true
	board.attack_touch_is_original = true
	board.touch_start = Vector2(250.0, 250.0)
	board._pointer_dragged(Vector2(330.0, 250.0))
	assert(board.attack_pointer_held and board.attack_touch_is_original)
	assert(bool(board.state.player_action.get("continue_held", false)))
	assert(not board.queued_movement_after_attack)
	board.free()

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
	enemy["pos"] = state.player_pos + Vector2(0.0, -95.0)
	state._choose_enemy_action(enemy)
	action = enemy["action"]
	assert(String(action["technique_id"]) == "reverse_cut")
	assert(float(action["reach"]) >= 120.0)

func test_projectile_motion() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies.clear()
	state.projectiles = [{"pos": Vector2(150.0, 150.0), "vel": Vector2(300.0, 0.0), "radius": 9.0, "damage": 2, "source_id": 99}]
	assert(state.request_wait(0.20))
	assert(state.projectiles.size() == 1)
	var x := Vector2(state.projectiles[0]["pos"]).x
	assert(x > 205.0 and x < 220.0)

func test_firebolt_tracking_is_limited() -> void:
	var state: RunState = RunStateScript.new()
	state.player_pos = Vector2(420.0, 300.0)
	state.projectiles = [{"pos": Vector2(100.0, 100.0), "vel": Vector2.RIGHT * 465.0, "launch_direction": Vector2.RIGHT, "turn_rate": 0.0, "max_track_angle": 0.0, "radius": 13.0, "damage": 3, "kind": "firebolt", "source_id": 99, "layer": state.current_layer}]
	for index in range(20): state._update_projectiles(0.05)
	assert(state.projectiles.size() == 1)
	var steering: float = absf(Vector2.RIGHT.angle_to(Vector2(state.projectiles[0]["vel"]).normalized()))
	assert(steering < 0.001)
	state.player_pos = Vector2(180.0, 720.0)
	var heading_before := Vector2(state.projectiles[0]["vel"]).normalized()
	state._update_projectiles(0.10)
	assert(heading_before.angle_to(Vector2(state.projectiles[0]["vel"]).normalized()) < 0.001)

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
	assert(state.counter_hits == 0)
	assert(state.player_hp == state.player_max_hp)

func test_directional_block() -> void:
	var state: RunState = RunStateScript.new()
	state.defense_id = "block"
	state.enemies = [state._make_enemy("blade", state.player_pos + Vector2(0.0, -110.0), 7)]
	var enemy := state.enemies[0]
	enemy["facing"] = Vector2.DOWN
	enemy["action"] = state._melee_action(1.45, 0.52, 0.82, 128.0, 2, Vector2.DOWN)
	enemy["action"]["elapsed"] = 0.22
	state.enemies[0] = enemy
	assert(state.request_block(Vector2.UP))
	for step in range(180):
		state._tick(state.SIM_DT)
		if state.successful_blocks > 0: break
	assert(state.successful_blocks == 1)
	assert(state.player_hp == state.player_max_hp)
	assert(state.block_cooldown <= 0.0)
	state.set_block_hold(false)

func test_block_stops_orphaned_projectile() -> void:
	var state: RunState = RunStateScript.new()
	state.defense_id = "block"
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
	state.defense_id = "endure"
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
	assert(state.loadout_id == "warrior" and state.defense_id == "dodge")
	assert(state.select_loadout("warrior"))
	assert(not state.select_loadout("duelist"))
	assert(not state.select_loadout("guardian"))
	assert(not state.select_loadout("reaver"))

func test_shared_actor_and_weapon_foundation() -> void:
	var state: RunState = RunStateScript.new()
	state.start_run("warrior", "expedition", 717, "encounter", "recovery")
	var player := state.player_actor()
	for attribute in CombatCatalogScript.ATTRIBUTE_KEYS:
		assert(Dictionary(player["attributes"]).has(attribute))
	for property in ["armor", "resistances", "mass", "collision_radius", "vision_range", "temporal_authority"]:
		assert(Dictionary(player["properties"]).has(property))
	assert(String(player["weapon_frame"]) == "sword")
	assert(String(player["equipped_weapon_art"]) == "")
	assert(Array(player["weapon_art_ids"]).is_empty())
	assert(Dictionary(player["equipment_slots"])["main_hand"] == "Sword")
	assert(Dictionary(player["martial_foundation"]).has("power"))
	for frame_id in ["knife", "sword", "axe", "zweihander", "spear", "twin_knives", "bow", "impact", "staff"]:
		var frame: Dictionary = CombatCatalogScript.weapon_frame(frame_id)
		assert(not Array(frame["art_ids"]).is_empty())
		for art_id in Array(frame["art_ids"]): assert(not CombatCatalogScript.weapon_art(String(art_id)).is_empty())
	var expected_frames := {"boar": "natural", "hound": "natural", "bandit": "twin_knives", "archer": "bow", "ice_caster": "staff", "fire_caster": "staff", "knight": "zweihander", "werewolf": "natural", "brute": "impact", "captain": "sword", "polearm": "spear", "blade": "sword", "knife": "twin_knives", "warden": "zweihander"}
	for enemy_kind in expected_frames:
		var enemy := state._make_enemy(String(enemy_kind), state.player_pos, state._enemy_base_hp(String(enemy_kind)))
		assert(String(enemy["weapon_frame"]) == String(expected_frames[enemy_kind]))
		for attribute in CombatCatalogScript.ATTRIBUTE_KEYS: assert(Dictionary(enemy["attributes"]).has(attribute))

func test_warrior_weapon_arts() -> void:
	var state: RunState = RunStateScript.new()
	state.start_run("warrior", "expedition", 717, "encounter", "recovery")
	state.walls.clear()
	state._build_navigation()
	var left := state._make_enemy("knife", state.player_pos + Vector2(-24, -84), 80)
	var right := state._make_enemy("knife", state.player_pos + Vector2(24, -84), 80)
	state.enemies = [left, right]
	for enemy in state.enemies: enemy["action"] = state._action("stagger", 2.0, Vector2.ZERO)
	assert(not state.request_skill(Vector2.UP))
	state.player_weapon_art_library.assign(["prototype_sweeping_cut"])
	state.player_equipped_weapon_art = "prototype_sweeping_cut"
	assert(state.request_skill(Vector2.UP))
	assert(state.skill_cooldown > 2.7)
	assert(int(left["hp"]) < 80 and int(right["hp"]) < 80)
	assert(state.simulation_time >= 1.30)
	state.skill_cooldown = 0.0
	state.player_weapon_art_library.assign(["prototype_drawing_cut"])
	state.player_equipped_weapon_art = "prototype_drawing_cut"
	state.enemies.clear()
	assert(state.request_skill(Vector2.UP, false))
	assert(String(state.player_action["technique_id"]) == "driving_cut")
	assert(String(state.player_action["ability_id"]) == "prototype_drawing_cut")
	while state.advance_streamed_action_tick(): pass

func test_warrior_tracks_and_art_gate() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "campaign_lab", 919)
	var sheet := state.character_sheet_data()
	assert(Array(sheet["tracks"]).size() == 6)
	assert(Dictionary(sheet["equipment"])["charm"] == "Waystone Fragment")
	state.carried_xp = 100
	state.secured_xp = 100
	state.player_pos = state.bonfire_pos
	assert(state.level_up_context() == "waystone")
	assert(state.available_level_up_options().has("swordsmanship"))
	assert(state.choose_upgrade("swordsmanship|prototype_drawing_cut"))
	assert(state.player_equipped_weapon_art == "prototype_drawing_cut")
	assert(state.player_weapon_art_library.size() == 1)
	assert(state.track_total("swordsmanship") == 1)
	assert(not state.choose_upgrade("swordsmanship|prototype_sweeping_cut"))
	assert(not state.can_swap_weapon_art())

func test_signature_attack_roster() -> void:
	var state: RunState = RunStateScript.new()
	assert(state.player_attack_technique == "diagonal_cut" and state.player_weapon_frame == "sword")
	assert(String(state._player_basic_attack_definition(Vector2.UP)["technique"]) == "opening_cut")
	state.walls.clear()
	# Attack selection is deliberately probabilistic and range-weighted, so a kind
	# with two options does not always produce the same technique at a given gap.
	# What must hold is that whatever it commits comes from its own authored plan.
	# Each enemy is placed at its plan's shortest strike distance, where every
	# option is inside its commit band, so a commitment always happens.
	for kind in ["bandit", "knife", "blade", "polearm", "brute", "captain", "knight", "shield"]:
		var plan: Array = CombatCatalogScript.melee_attack_plan(kind)
		assert(not plan.is_empty())
		var techniques: Array[String] = []
		var nearest := INF
		for option_value in plan:
			var option := Dictionary(option_value)
			techniques.append(String(option["technique"]))
			nearest = minf(nearest, float(option["distance"]))
		var enemy := state._make_enemy(kind, state.player_pos + Vector2.UP * nearest, state._enemy_base_hp(kind))
		if kind == "bandit":
			enemy["revealed_to_player"] = true
			enemy["revealed_elapsed"] = 0.35
			enemy["dodge_cooldown"] = 1.0
		state._choose_enemy_action(enemy)
		var committed := Dictionary(enemy["action"])
		assert(String(committed.get("kind", "")) == "melee")
		assert(String(committed.get("technique_id", "")) in techniques)

func test_attack_geometry_boundaries() -> void:
	var origin := Vector2(500, 500)
	var thrust := {"technique_id": "thrust", "elapsed": 0.76, "startup": 0.4, "active_end": 0.8, "duration": 1.2, "reach": 200.0}
	var thrust_pose: Dictionary = AttackGeometryScript.pose(thrust, origin, Vector2.RIGHT)
	assert(AttackGeometryScript.hits_circle(thrust_pose, origin + Vector2(150, 5), 6.0))
	assert(not AttackGeometryScript.hits_circle(thrust_pose, origin + Vector2(150, 30), 6.0))
	var cut := {"technique_id": "quick_cut", "elapsed": 0.60, "startup": 0.4, "active_end": 0.8, "duration": 1.2, "reach": 92.0}
	var cut_pose: Dictionary = AttackGeometryScript.pose(cut, origin, Vector2.RIGHT)
	var footprint_mid := origin + Vector2.RIGHT * 68.0
	assert(String(cut_pose["shape"]) == "sector")
	assert(AttackGeometryScript.hits_circle(cut_pose, footprint_mid, 4.0))
	assert(not AttackGeometryScript.hits_circle(cut_pose, origin + Vector2.LEFT * 75.0, 4.0))

func test_player_melee_hits_every_crossed_enemy() -> void:
	var state: RunState = RunStateScript.new()
	state.walls.clear()
	state.player_facing = Vector2.RIGHT
	var near := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 90.0, 90)
	var far := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 145.0, 90)
	state.enemies = [far, near]
	state.player_action = state._melee_action(1.2, 0.2, 0.8, 190.0, 2, Vector2.RIGHT, "thrust", "attack")
	state.player_action["elapsed"] = 0.72
	state.player_action["damage_min"] = 2
	state.player_action["damage_max"] = 2
	state._resolve_player_attack_tick(0.72)
	assert(int(near["hp"]) < 90)
	assert(int(far["hp"]) == int(near["hp"]))
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
	state.player_action = state._action("attack", 0.98, Vector2.UP)
	state.player_action["elapsed"] = 0.40
	state._apply_posture_damage(knife, 2.0)
	assert(String(Dictionary(knife["action"])["kind"]) == "stagger")
	assert(float(knife["posture"]) == 0.0)
	var player_recovery_world := (0.98 - 0.40) / state._player_personal_tempo()
	var enemy_stagger_world := float(Dictionary(knife["action"])["duration"]) / state._enemy_personal_tempo(knife)
	assert(enemy_stagger_world >= player_recovery_world + state.POSTURE_BREAK_OPENING_SECONDS - 0.0001)

func test_enemy_stagger_cannot_be_refreshed() -> void:
	var state: RunState = RunStateScript.new()
	var bandit := state._make_enemy("bandit", state.player_pos + Vector2.UP * 90.0, 20)
	bandit["posture"] = 1.0
	assert(state._apply_posture_damage(bandit, 2.0))
	var original_duration := float(Dictionary(bandit["action"])["duration"])
	bandit["action"]["elapsed"] = 0.24
	for follow_up in range(3):
		assert(not state._apply_posture_damage(bandit, 5.0))
		assert(String(Dictionary(bandit["action"])["kind"]) == "stagger")
		assert(is_equal_approx(float(Dictionary(bandit["action"])["duration"]), original_duration))
		assert(is_equal_approx(float(Dictionary(bandit["action"])["elapsed"]), 0.24))
		assert(is_equal_approx(float(bandit["posture"]), 0.0))

func test_grounded_heavy_resists_break() -> void:
	var state: RunState = RunStateScript.new()
	var brute := state._make_enemy("brute", state.player_pos + Vector2(0, -130), 16)
	brute["action"] = state._melee_action(2.55, 1.02, 1.52, 158.0, 4, Vector2.DOWN)
	brute["action"]["elapsed"] = 1.10
	state._apply_posture_damage(brute, 20.0)
	assert(String(Dictionary(brute["action"])["kind"]) == "melee")
	var startup := state._melee_action(2.55, 1.02, 1.52, 158.0, 4, Vector2.DOWN, "forward_smash")
	startup["elapsed"] = 0.40
	brute["action"] = startup
	assert(not state._apply_enemy_hit_reaction(brute, 1.8, "alerted", startup))
	assert(String(Dictionary(brute["action"])["kind"]) == "melee")
	assert(state._apply_enemy_hit_reaction(brute, 4.0, "alerted", startup))
	assert(String(Dictionary(brute["action"])["kind"]) == "hit_reaction")

func test_clean_opening_hit_preserves_a_defensive_choice() -> void:
	for enemy_kind in ["bandit", "boar"]:
		var state: RunState = RunStateScript.new()
		state.walls.clear()
		state.enemies.clear()
		var distance := 108.0 if enemy_kind == "bandit" else 110.0
		var enemy := state._make_enemy(enemy_kind, state.player_pos + Vector2.RIGHT * distance, state._enemy_base_hp(enemy_kind) + 10)
		enemy["awareness"] = "alerted"
		enemy["facing"] = Vector2.LEFT
		# At this spacing the bandit is moving in, not already attacking or
		# entering its evasive strike. The boar is still in its interruptible
		# crouch when the sword reaches it.
		if enemy_kind == "bandit": enemy["dodge_cooldown"] = 1.0
		state.enemies = [enemy]
		var hp_before := state.player_hp
		assert(state.request_attack(Vector2(enemy["pos"]), false))
		while state.advance_streamed_action_tick(): pass
		assert(state.player_hp == hp_before)
		assert(int(state.enemies[0]["hp"]) < int(state.enemies[0]["max_hp"]))
		# A guard chosen at the frozen decision point must become active before
		# this ordinary enemy's fresh counter can land.
		assert(state.request_block(Vector2.RIGHT))
		for step in range(180):
			state._tick(state.SIM_DT)
			if state.successful_blocks > 0: break
		assert(state.player_hp == hp_before)
		state.set_block_hold(false)

func test_boar_momentum_armour_and_hound_interruptibility() -> void:
	var state: RunState = RunStateScript.new()
	var boar := state._make_enemy("boar", state.player_pos + Vector2.RIGHT * 180.0, 20)
	var early_pounce := state._charge_action(1.54, 0.52, 0.96, 360.0, 2, Vector2.LEFT)
	early_pounce["label"] = "pounce"
	early_pounce["momentum_armour_start"] = 0.70
	early_pounce["elapsed"] = 0.60
	boar["action"] = early_pounce
	assert(state._apply_enemy_hit_reaction(boar, 1.8, "alerted", early_pounce))
	assert(String(Dictionary(boar["action"])["kind"]) == "hit_reaction")

	var full_pounce := state._charge_action(1.54, 0.52, 0.96, 360.0, 2, Vector2.LEFT)
	full_pounce["label"] = "pounce"
	full_pounce["momentum_armour_start"] = 0.70
	full_pounce["elapsed"] = 0.76
	boar["action"] = full_pounce
	assert(not state._apply_enemy_hit_reaction(boar, 1.8, "alerted", full_pounce))
	assert(String(Dictionary(boar["action"])["kind"]) == "charge")
	assert(state._apply_enemy_hit_reaction(boar, 5.0, "alerted", full_pounce))
	assert(String(Dictionary(boar["action"])["kind"]) == "hit_reaction")

	var hound := state._make_enemy("hound", state.player_pos + Vector2.RIGHT * 180.0, 12)
	var hound_pounce := state._charge_action(1.18, 0.30, 0.68, 440.0, 2, Vector2.LEFT)
	hound_pounce["label"] = "pounce"
	hound_pounce["elapsed"] = 0.50
	hound["action"] = hound_pounce
	assert(state._apply_enemy_hit_reaction(hound, 1.8, "alerted", hound_pounce))
	assert(String(Dictionary(hound["action"])["kind"]) == "hit_reaction")

func test_active_weapon_contact_can_still_trade() -> void:
	var state: RunState = RunStateScript.new()
	var bandit := state._make_enemy("bandit", state.player_pos + Vector2.RIGHT * 88.0, 12)
	var active_cut := state._melee_action(0.86, 0.26, 0.45, 94.0, 1, Vector2.LEFT, "quick_cut")
	active_cut["elapsed"] = 0.34
	bandit["action"] = active_cut
	assert(state._apply_enemy_hit_reaction(bandit, 1.8, "alerted", active_cut))
	assert(String(Dictionary(bandit["action"])["kind"]) == "hit_reaction")

func test_hit_reaction_preserves_contact_and_interrupted_pose() -> void:
	var state: RunState = RunStateScript.new()
	var bandit := state._make_enemy("bandit", state.player_pos + Vector2.RIGHT * 120.0, 12)
	var winding_cut := state._melee_action(0.86, 0.26, 0.45, 94.0, 1, Vector2.LEFT, "quick_cut")
	winding_cut["elapsed"] = 0.18
	bandit["action"] = winding_cut
	var contact := Vector2(bandit["pos"]) + Vector2.LEFT * 12.0
	assert(state._apply_enemy_hit_reaction(bandit, 1.8, "alerted", winding_cut, contact))
	var reaction: Dictionary = bandit["action"]
	assert(String(reaction["kind"]) == "hit_reaction")
	assert(Vector2(reaction["reaction_contact"]).distance_to(contact) < 0.01)
	assert(Vector2(reaction["reaction_direction"]).x > 0.9)
	assert(String(Dictionary(reaction["interrupted_action"])["technique_id"]) == "quick_cut")

	var knife := state._make_enemy("knife", state.player_pos + Vector2.UP * 100.0, 8)
	var knife_cut := state._melee_action(0.88, 0.28, 0.46, 92.0, 1, Vector2.DOWN, "quick_cut")
	knife["action"] = knife_cut
	var break_contact := Vector2(knife["pos"]) + Vector2.UP * 10.0
	assert(state._apply_posture_damage(knife, 2.0, break_contact))
	var stagger: Dictionary = knife["action"]
	assert(String(stagger["kind"]) == "stagger")
	assert(Vector2(stagger["reaction_contact"]).distance_to(break_contact) < 0.01)
	assert(String(Dictionary(stagger["interrupted_action"])["technique_id"]) == "quick_cut")

func test_player_reaction_cannot_be_stunlocked() -> void:
	var state: RunState = RunStateScript.new()
	state.enemies.clear()
	state.player_max_hp = 100
	state.player_hp = 100
	state.player_posture = 1.0
	state.player_action = state._idle_action()
	state._resolve_incoming_hit(1, 1, "first bandit", Vector2.LEFT, state.player_pos)
	assert(String(state.player_action["kind"]) == "stagger")
	state.advance_streamed_action_tick()
	var elapsed_before := float(state.player_action["elapsed"])
	var duration_before := float(state.player_action["duration"])
	state._resolve_incoming_hit(2, 1, "second bandit", Vector2.RIGHT, state.player_pos)
	assert(state.player_hp == 98)
	assert(String(state.player_action["kind"]) == "stagger")
	assert(is_equal_approx(float(state.player_action["elapsed"]), elapsed_before))
	assert(is_equal_approx(float(state.player_action["duration"]), duration_before))
	var ticks := 0
	while not state.is_player_ready() and ticks < 120:
		if ticks % 12 == 0: state._resolve_incoming_hit(3, 1, "bandit chain", Vector2.UP, state.player_pos)
		state.advance_streamed_action_tick()
		ticks += 1
	assert(state.is_player_ready())
	assert(ticks < 120)
	var hp_before_recovery_tick_hit := state.player_hp
	state._player_reaction_completed_this_tick = true
	state._resolve_incoming_hit(4, 1, "late bandit", Vector2.DOWN, state.player_pos)
	assert(state.player_hp == hp_before_recovery_tick_hit - 1)
	assert(state.is_player_ready())

func test_line_of_sight_uses_exact_wall_intersection() -> void:
	var state: RunState = RunStateScript.new(false)
	state.walls = [Rect2(100.0, 80.0, 40.0, 160.0)]
	state._build_wall_spatial_index()
	assert(state._segment_intersects_rect(Vector2(40.0, 160.0), Vector2(220.0, 160.0), state.walls[0]))
	assert(not state._segment_intersects_rect(Vector2(40.0, 40.0), Vector2(220.0, 40.0), state.walls[0]))
	assert(not state._has_line_of_sight(Vector2(40.0, 160.0), Vector2(220.0, 160.0)))
	assert(state._has_line_of_sight(Vector2(40.0, 40.0), Vector2(220.0, 40.0)))

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

func test_enemy_facing_and_moving_follow_real_displacement() -> void:
	var state: RunState = RunStateScript.new(false)
	state.world_size = Vector2(1200, 1200)
	state.current_layer = "test"
	state.floor_shapes = [{"kind": "circle", "center": Vector2(600, 600), "radius": 560.0, "layer": "test", "part_id": 0}]
	state.player_pos = Vector2(980, 600)
	state.walls.clear()
	state.enemies.clear()
	state._build_navigation()
	var blade := state._make_enemy("blade", Vector2(360, 600), 7)
	blade["layer"] = "test"
	blade["facing"] = Vector2.LEFT
	state.enemies = [blade]
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	var action := state._enemy_move_action(blade, state.player_pos, 0.48)
	blade["action"] = action
	var before := Vector2(blade["pos"])
	state._advance_enemy_locomotion(blade, action, 8.0, 1.0 / 60.0)
	var motion := Vector2(blade["pos"]) - before
	assert(motion.length() > 0.1)
	assert(bool(action["moving"]))
	assert(bool(blade["is_moving"]))
	assert(Vector2(blade["facing"]).dot(motion.normalized()) > 0.99)

func test_blocked_enemy_stops_claiming_movement_and_replans() -> void:
	var state: RunState = RunStateScript.new(false)
	state.world_size = Vector2(1200, 1200)
	state.current_layer = "test"
	state.floor_shapes = [{"kind": "circle", "center": Vector2(600, 600), "radius": 560.0, "layer": "test", "part_id": 0}]
	state.player_pos = Vector2(980, 600)
	state.walls = [
		Rect2(520, 520, 60, 160),
		Rect2(620, 520, 60, 160),
		Rect2(520, 520, 160, 60),
		Rect2(520, 620, 160, 60),
	]
	state.enemies.clear()
	state._build_navigation()
	var blade := state._make_enemy("blade", Vector2(600, 600), 7)
	blade["layer"] = "test"
	state.enemies = [blade]
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	var action := state._enemy_move_action(blade, state.player_pos, 0.9)
	blade["action"] = action
	for index in range(32):
		action["elapsed"] = float(action["elapsed"]) + 1.0 / 60.0
		state._advance_enemy_locomotion(blade, action, 8.0, 1.0 / 60.0)
	assert(Vector2(blade["pos"]).is_equal_approx(Vector2(600, 600)))
	assert(not bool(action["moving"]))
	assert(float(action["duration"]) <= float(action["elapsed"]))
	assert(not blade.has("nav_path"))

func test_crowded_enemy_steers_around_another_actor() -> void:
	var state: RunState = RunStateScript.new(false)
	state.world_size = Vector2(1200, 1200)
	state.current_layer = "test"
	state.floor_shapes = [{"kind": "circle", "center": Vector2(600, 600), "radius": 560.0, "layer": "test", "part_id": 0}]
	state.player_pos = Vector2(1040, 600)
	state.walls.clear()
	state.enemies.clear()
	state._build_navigation()
	var mover := state._make_enemy("blade", Vector2(420, 600), 7)
	var blocker := state._make_enemy("blade", Vector2(490, 600), 7)
	mover["layer"] = "test"
	blocker["layer"] = "test"
	state.enemies = [mover, blocker]
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	var action := state._enemy_move_action(mover, state.player_pos, 0.8)
	mover["action"] = action
	var before := Vector2(mover["pos"])
	for index in range(12):
		action["elapsed"] = float(action["elapsed"]) + 1.0 / 60.0
		state._advance_enemy_locomotion(mover, action, 7.0, 1.0 / 60.0)
	var motion := Vector2(mover["pos"]) - before
	assert(motion.length() > 1.0)
	assert(absf(motion.y) > 0.5)
	assert(Vector2(mover["facing"]).dot(Vector2(mover["last_motion"]).normalized()) > 0.99)

func test_flankers_reserve_interception_lanes() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "expedition", 717, "encounter", "stamina")
	state.player_pos = Vector2(600, 600)
	state.player_facing = Vector2.RIGHT
	state.player_action = state._action("move", 0.2, Vector2.RIGHT)
	var left := state._make_enemy("bandit", Vector2(400, 520), 7)
	var right := state._make_enemy("knife", Vector2(400, 680), 7)
	left["id"] = 4
	right["id"] = 5
	var left_target := state._pursuit_target(left)
	var right_target := state._pursuit_target(right)
	assert(left_target.x >= state.player_pos.x + 119.0)
	assert(right_target.x >= state.player_pos.x + 119.0)
	assert(left_target.y < state.player_pos.y)
	assert(right_target.y > state.player_pos.y)
	assert(absf(left_target.y - right_target.y) >= 160.0)

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

func test_desktop_hold_attack_key() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot(true)
	board.desktop_controls = true
	board.board_area = Rect2(0, 0, 1280, 800)
	board._update_projection()
	var down := InputEventKey.new()
	down.keycode = KEY_F
	down.pressed = true
	board._unhandled_key_input(down)
	assert(board.attack_key_held and String(board.state.player_action["kind"]) == "combo")
	var up := InputEventKey.new()
	up.keycode = KEY_F
	up.pressed = false
	board._unhandled_key_input(up)
	assert(not board.attack_key_held and not bool(board.state.player_action.get("continue_held", true)))
	board.free()

func test_stamina_direct_attack_button() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.state.start_run("warrior", "expedition", 919191, "encounter", "stamina")
	board.state.enemies.clear()
	board.visual = board.state.snapshot(true)
	board.size = Vector2(1280, 800)
	board._create_seed_input()
	board._layout()
	assert(board.board_rect.encloses(board.attack_rect))
	var attack_point: Vector2 = board.attack_rect.get_center()
	board._pointer_pressed(attack_point)
	assert(board.attack_button_pointer_held and board.attack_pointer_held)
	assert(String(board.state.player_action["kind"]) == "combo")
	assert(board.state.direct_attack_uses_total == 1)
	board._pointer_dragged(attack_point + Vector2(-120.0, 0.0))
	assert(board.attack_button_pointer_held and not board.queued_movement_after_attack)
	board._pointer_released(attack_point)
	assert(not board.attack_button_pointer_held and not bool(board.state.player_action.get("continue_held", true)))
	board.free()

	var recovery_board = GameBoardScript.new()
	recovery_board.state = RunStateScript.new(false)
	recovery_board.state.start_run("warrior", "expedition", 919191, "encounter", "recovery")
	recovery_board.state.enemies.clear()
	recovery_board.visual = recovery_board.state.snapshot(true)
	recovery_board.size = Vector2(1280, 800)
	recovery_board._create_seed_input()
	recovery_board._layout()
	recovery_board._pointer_pressed(recovery_board.attack_rect.get_center())
	assert(not recovery_board.attack_button_pointer_held)
	assert(String(recovery_board.state.player_action["kind"]) == "idle")
	recovery_board.free()

func test_held_wait_repeats_until_release() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.state.start_run("warrior", "combat_survey", 919191, "encounter")
	board.visual = board.state.snapshot(true)
	board.size = Vector2(1280, 800)
	board._create_seed_input()
	board._layout()
	var start_time: float = board.state.simulation_time
	var wait_point: Vector2 = board.interaction_rect.get_center()
	board._pointer_pressed(wait_point)
	assert(board.wait_pointer_held and board.pointer_down)
	for _frame in range(24): board._process(0.10)
	# Assert the unit count, not a floor. The old assertion was "more than 0.75s
	# elapsed", which still passes at 0.131s units while no longer testing that
	# holding chains whole units at movement's granularity.
	var unit: float = board.state.wait_unit_duration()
	var elapsed: float = board.state.simulation_time - start_time
	var units: float = roundf(elapsed / unit)
	assert(units >= 4.0)
	# Each unit resolves on the fixed step, so it can overshoot its authored length
	# by up to one tick. The point is that the total is whole units of movement
	# granularity, not that it lands on an exact float multiple.
	assert(absf(elapsed - units * unit) <= units * board.state.SIM_DT + 0.001)
	board._pointer_released(wait_point)
	assert(not board.wait_pointer_held and not board.pointer_down)
	for _frame in range(16): board._process(0.10)
	var stopped_time: float = board.state.simulation_time
	for _frame in range(6): board._process(0.10)
	assert(is_equal_approx(board.state.simulation_time, stopped_time))
	board.free()

func test_melee_enemy_tap_intent_classifier() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.state.enemies.clear()
	var origin: Vector2 = board.state.player_pos
	var direct_boar: Dictionary = board.state._make_enemy("boar", origin + Vector2.RIGHT * 230.0, 7, 0)
	board.state.enemies.assign([direct_boar])
	assert(board._enemy_touch_should_attack(direct_boar))
	var distant_boar: Dictionary = board.state._make_enemy("boar", origin + Vector2.RIGHT * 285.0, 7, 0)
	board.state.enemies.assign([distant_boar])
	assert(not board._enemy_touch_should_attack(distant_boar))
	var nearby_blade: Dictionary = board.state._make_enemy("blade", origin + Vector2.RIGHT.rotated(deg_to_rad(24.0)) * 145.0, 7, 0)
	board.state.enemies.assign([distant_boar, nearby_blade])
	board.state.visible_cells[board.state._visibility_cell(Vector2(nearby_blade["pos"]))] = true
	assert(board._enemy_touch_should_attack(distant_boar))
	var off_angle_blade: Dictionary = board.state._make_enemy("blade", origin + Vector2.RIGHT.rotated(deg_to_rad(58.0)) * 145.0, 7, 0)
	board.state.enemies.assign([distant_boar, off_angle_blade])
	board.state.visible_cells.clear()
	board.state.visible_cells[board.state._visibility_cell(Vector2(off_angle_blade["pos"]))] = true
	assert(not board._enemy_touch_should_attack(distant_boar))
	board.state.player_weapon_frame = "bow"
	assert(board._enemy_touch_should_attack(distant_boar))
	board.free()

func test_immediate_touch_drag_claims_movement() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot(true)
	board.desktop_controls = false
	board.set_size(Vector2(1080.0, 1920.0))
	board.board_rect = Rect2(0.0, 0.0, 1080.0, 1600.0)
	board.pointer_down = true
	board.pointer_intent = ""
	board.touch_start = Vector2(500.0, 500.0)
	board.touch_current = board.touch_start
	board._pointer_dragged(Vector2(520.0, 500.0))
	assert(board.pointer_intent == "move")
	assert(board.held_movement)
	board.free()

func test_empty_hold_becomes_continuous_movement() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.state.enemies.clear()
	board.visual = board.state.snapshot(true)
	board.desktop_controls = false
	board.set_size(Vector2(1080.0, 1920.0))
	board.board_rect = Rect2(0.0, 0.0, 1080.0, 1600.0)
	var right_point := board._world_to_screen(board.state.player_pos + Vector2.RIGHT * 240.0)
	board._pointer_pressed(right_point)
	board._process(0.17)
	assert(board.pointer_intent == "move")
	assert(board.held_movement and board.held_movement_tracks_pointer)
	assert(String(board.state.player_action.get("kind", "idle")) == "move")
	var down_point := board._world_to_screen(board.state.player_pos + Vector2.DOWN * 240.0)
	board._pointer_dragged(down_point)
	assert(board.held_direction.dot(Vector2.DOWN) > 0.95)
	board._pointer_released(down_point)
	assert(not board.held_movement and not board.held_movement_tracks_pointer)
	board.free()

func test_valid_enemy_hold_still_begins_combo() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.state.enemies.clear()
	var enemy: Dictionary = board.state._make_enemy("boar", board.state.player_pos + Vector2.RIGHT * 120.0, 7001, 0)
	board.state.enemies.assign([enemy])
	board.state.visible_cells[board.state._visibility_cell(Vector2(enemy["pos"]))] = true
	board.visual = board.state.snapshot(true)
	board.desktop_controls = false
	board.set_size(Vector2(1080.0, 1920.0))
	board.board_rect = Rect2(0.0, 0.0, 1080.0, 1600.0)
	var enemy_point := board._world_to_screen(Vector2(enemy["pos"]))
	board._pointer_pressed(enemy_point)
	board._process(0.17)
	assert(board.pointer_intent == "attack")
	assert(board.attack_pointer_held and board.attack_touch_is_original)
	assert(String(board.state.player_action.get("kind", "idle")) == "combo")
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

func test_temporal_tint_eases_between_states() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.playing = false
	assert(board._update_temporal_tint(0.08))
	assert(board.temporal_tint_strength > 0.0 and board.temporal_tint_strength < 1.0)
	for index in range(10): board._update_temporal_tint(0.08)
	assert(is_equal_approx(board.temporal_tint_strength, 1.0))
	board.playing = true
	assert(board._update_temporal_tint(0.04))
	assert(board.temporal_tint_strength < 1.0 and board.temporal_tint_strength > 0.0)
	for index in range(10): board._update_temporal_tint(0.08)
	assert(is_zero_approx(board.temporal_tint_strength))
	board.free()

func test_area_entry_title_uses_pacing_metadata() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.state.start_run("wayfarer", "expedition", 717)
	board._presented_area_id = -999999
	assert(board._update_area_title(0.0))
	assert(board.area_title_name == board.state.current_area_name())
	assert(not board.area_title_subtitle.is_empty())
	assert(is_equal_approx(board.area_title_remaining, board.AREA_TITLE_DURATION))
	board.state.current_area_id = 1
	assert(board._update_area_title(0.1))
	assert(board._presented_area_id == 1)
	assert(board.area_title_name == String(board.state.areas[1]["name"]))
	assert(board.area_title_subtitle == String(board.state.areas[1]["arrival_text"]))
	board.free()

func test_long_landmarks_are_ground_materials() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.state.start_run("wayfarer", "expedition", 739391)
	board._refresh_ground_surface_landmarks()
	var brook: Dictionary = {}
	var road: Dictionary = {}
	for feature in board._ground_surface_landmarks:
		if String(feature["kind"]) == "brook": brook = feature
		if String(feature["kind"]) == "old_road": road = feature
	assert(not brook.is_empty() and not road.is_empty())
	board._ground_surface_landmarks.clear()
	board._ground_surface_landmarks.append(brook)
	var brook_point := Vector2(brook["from"]).lerp(Vector2(brook["to"]), 0.02)
	var brook_base := Color("79ad68")
	assert(board._ground_surface_color_at(brook_point, brook_base) != brook_base)
	var ford_point := Vector2(Array(brook["fords"])[0])
	assert(board._ground_surface_color_at(ford_point, brook_base) != board._ground_surface_color_at(brook_point, brook_base))
	board._ground_surface_landmarks.clear()
	board._ground_surface_landmarks.append(road)
	var road_point := Vector2(road["from"]).lerp(Vector2(road["to"]), 0.5)
	var road_base := Color("70a162")
	assert(board._ground_surface_color_at(road_point, road_base) != road_base)
	board.free()

func test_presentation_frames_reuse_storage() -> void:
	var state: RunState = RunStateScript.new()
	state.start_run("wayfarer", "expedition", 717)
	var current = PresentationFrameScript.new()
	var following = PresentationFrameScript.new()
	var blended = PresentationFrameScript.new()
	var first_capture: Dictionary = current.capture(state)
	var first_enemy_array: Array = first_capture["enemies"]
	var first_pickup_array: Array = first_capture["world_pickups"]
	assert(first_pickup_array.size() == state.world_pickups.size() and not first_pickup_array.is_empty())
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
	assert(is_same(first_pickup_array, current.data["world_pickups"]))
	assert(Array(second_blend["world_pickups"]).size() == state.world_pickups.size())
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
	assert(not board.buttons.has("attack") and not board.buttons.has("wait") and board.buttons.size() == 5)
	assert(board.interaction_rect.size.y >= 44.0)
	assert(board.interaction_rect.end.y < Rect2(board.consumable_rects["healing"]).position.y)
	board.free()

func test_mobile_safe_area_layout() -> void:
	var board = GameBoardScript.new()
	board.state = RunStateScript.new()
	board.visual = board.state.snapshot()
	board.desktop_controls = false
	board.size = Vector2(720, 1394)
	board.layout_safe_area_override = Rect2(0, 89, 720, 1263)
	board._create_seed_input()
	board._layout()
	assert(board.safe_layout_rect == board.layout_safe_area_override)
	assert(board.board_rect.position.y == 89.0)
	assert(board.board_rect.end.y < board.layout_safe_area_override.end.y)
	assert(board.loadout_rects["warrior"].position.y > board.board_rect.end.y)
	assert(board.layout_safe_area_override.encloses(board.loadout_rects["warrior"]))
	assert(board.layout_safe_area_override.encloses(board.interaction_rect))
	for rect in board.buttons.values(): assert(board.layout_safe_area_override.encloses(Rect2(rect)))
	for rect in board.consumable_rects.values(): assert(board.layout_safe_area_override.encloses(Rect2(rect)))
	assert(board.sheet_panel_rect.position.y >= board.layout_safe_area_override.position.y)
	assert(board.sheet_panel_rect.end.y <= board.layout_safe_area_override.end.y)
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
	var boar := state._make_enemy("boar", state.player_pos + Vector2(0, -220), 7)
	state._choose_enemy_action(boar)
	assert(String(Dictionary(boar["action"])["kind"]) == "charge")
	assert(String(Dictionary(boar["action"])["label"]) == "pounce")
	boar["pounce_cooldown"] = 1.0
	boar["pos"] = state.player_pos + Vector2(0, -70)
	state._choose_enemy_action(boar)
	assert(String(Dictionary(boar["action"])["kind"]) == "move")
	var hound := state._make_enemy("hound", state.player_pos + Vector2(0, -220), 6)
	state._choose_enemy_action(hound)
	assert(String(Dictionary(hound["action"])["kind"]) == "charge")
	assert(String(Dictionary(hound["action"])["label"]) == "pounce")
	var futile_hound := state._make_enemy("hound", state.player_pos + Vector2(0, -310), 6)
	state._choose_enemy_action(futile_hound)
	assert(String(Dictionary(futile_hound["action"])["kind"]) == "move")
	hound["pounce_cooldown"] = 0.8
	state._choose_enemy_action(hound)
	assert(String(Dictionary(hound["action"])["kind"]) == "evade")
	var bandit := state._make_enemy("bandit", state.player_pos + Vector2(0, -180), 5)
	bandit["revealed_to_player"] = true
	bandit["revealed_elapsed"] = 0.35
	state._choose_enemy_action(bandit)
	assert(String(Dictionary(bandit["action"])["kind"]) == "dodge_strike")
	bandit["action"]["elapsed"] = 0.18
	assert(state._enemy_evades_attack(bandit))
	var hexer := state._make_enemy("hexer", state.player_pos + Vector2(0, -400), 7)
	state._choose_enemy_action(hexer)
	assert(String(Dictionary(hexer["action"])["kind"]) == "hex")
	var brute := state._make_enemy("brute", state.player_pos + Vector2(0, -140), 16)
	state._choose_enemy_action(brute)
	assert(String(Dictionary(brute["action"])["kind"]) == "melee")
	assert(float(Dictionary(brute["action"])["duration"]) > 2.4)
	var close_polearm := state._make_enemy("polearm", state.player_pos + Vector2.UP * 94.0, 12)
	state._choose_enemy_action(close_polearm)
	assert(String(Dictionary(close_polearm["action"])["technique_id"]) == "reverse_cut")
	var close_captain := state._make_enemy("captain", state.player_pos + Vector2.UP * 90.0, 12)
	state._choose_enemy_action(close_captain)
	assert(String(Dictionary(close_captain["action"])["technique_id"]) == "quick_cut")
	var captain := state._make_enemy("captain", Vector2(120, 120), 12)
	state.player_pos = Vector2(200, 200)
	state.enemies = [captain]
	state._invalidate_active_enemy_cache()
	var blade := state._make_enemy("blade", Vector2(300, 300), 7)
	assert(state._enemy_move_speed(blade) > 190.0)

func test_back_half_expedition_roles() -> void:
	var state: RunState = RunStateScript.new()
	state.walls.clear()
	var ice := state._make_enemy("ice_caster", state.player_pos + Vector2.UP * 400.0, 8)
	state._choose_enemy_action(ice)
	assert(String(Dictionary(ice["action"])["kind"]) == "ice_hex")
	assert(float(Dictionary(ice["action"])["startup"]) >= 1.29)
	assert(Vector2(Dictionary(ice["action"])["target"]).distance_to(state.player_pos) <= 21.0)
	ice["pos"] = state.player_pos + Vector2.UP * 250.0
	state._choose_enemy_action(ice)
	assert(String(Dictionary(ice["action"])["kind"]) == "ice_cone")
	assert(float(Dictionary(ice["action"])["startup"]) >= 1.15)
	var fire := state._make_enemy("fire_caster", state.player_pos + Vector2.UP * 400.0, 8)
	state._choose_enemy_action(fire)
	assert(String(Dictionary(fire["action"])["kind"]) == "shoot" and String(Dictionary(fire["action"])["label"]) == "firebolt")
	state.projectiles.clear()
	state._spawn_projectile(fire)
	assert(String(state.projectiles[0]["kind"]) == "firebolt" and is_equal_approx(Vector2(state.projectiles[0]["vel"]).length(), 465.0))
	fire["pos"] = state.player_pos + Vector2.UP * 150.0
	state._choose_enemy_action(fire)
	assert(String(Dictionary(fire["action"])["kind"]) == "fire_circle")
	var archer := state._make_enemy("archer", state.player_pos + Vector2.UP * 400.0, 5)
	state._choose_enemy_action(archer)
	state.projectiles.clear()
	state._spawn_projectile(archer)
	var arrow_speed := Vector2(state.projectiles[0]["vel"]).length()
	assert(arrow_speed >= 680.0 and arrow_speed <= 720.0)
	var screening_blade := state._make_enemy("blade", archer["pos"] + Vector2.DOWN * 120.0, 7)
	state.enemies = [archer, screening_blade]
	state._invalidate_active_enemy_cache()
	assert(not state._archer_has_clear_lane(archer))
	state._choose_enemy_action(archer)
	assert(String(Dictionary(archer["action"])["kind"]) == "move")
	var knight := state._make_enemy("knight", state.player_pos + Vector2.UP * 220.0, 28)
	state._choose_enemy_action(knight)
	assert(String(Dictionary(knight["action"])["technique_id"]) == "thrust")
	knight["pos"] = state.player_pos + Vector2.UP * 150.0
	state._choose_enemy_action(knight)
	assert(String(Dictionary(knight["action"])["technique_id"]) == "heavy_cleave")
	assert(float(knight["posture_max"]) >= 20.0 and state._enemy_move_speed(knight) <= 70.0)
	var wolf := state._make_enemy("werewolf", state.player_pos + Vector2.UP * 125.0, 42)
	state._choose_enemy_action(wolf)
	assert(String(Dictionary(wolf["action"])["kind"]) == "claw_combo")
	var leap_chain: Dictionary = state._werewolf_pounce_combo(Vector2.DOWN)
	assert(String(leap_chain["kind"]) == "pounce_combo" and int(leap_chain["pounce_damage"]) > 0)
	state.hazards.clear()
	state._spawn_hex(ice, state.player_pos, "ice_hex")
	assert(String(state.hazards[0]["kind"]) == "ice_hex" and float(state.hazards[0]["trigger_at"]) >= 0.8)
	state.hazards.clear()
	state._spawn_ice_cone(ice, Vector2.DOWN)
	assert(String(state.hazards[0]["kind"]) == "ice_cone" and float(state.hazards[0]["radius"]) >= 280.0)

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
		var encounters: Dictionary = layout["encounters"]
		var expected_rosters := [
			{"boar": 8},
			{"boar": 5, "hound": 4},
			{"bandit": 5, "hound": 5},
			{"ice_caster": 4, "fire_caster": 3},
			{"bandit": 7, "archer": 5},
			{"knight": 3, "archer": 10},
			{"knight": 2, "archer": 5, "ice_caster": 2, "fire_caster": 2, "werewolf": 1, "hound": 2},
		]
		for part in range(7):
			var actual: Dictionary = {}
			for enemy in Array(encounters[part]):
				var kind := String(enemy["kind"])
				actual[kind] = int(actual.get(kind, 0)) + 1
			assert(actual == expected_rosters[part], "unexpected Region %d roster: %s" % [part + 1, actual])

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
	expedition.start_run("wayfarer", "expedition", 717)
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
	var nearby := expedition._make_enemy("bandit", expedition.player_pos + Vector2.RIGHT * 400.0, 8, 4)
	var distant := expedition._make_enemy("bandit", expedition.player_pos + Vector2.RIGHT * (expedition.ACTIVE_ENEMY_RADIUS + 300.0), 8, 4)
	expedition.enemies = [nearby, distant]
	expedition.loaded_region_ids = {3: true, 4: true, 5: true}
	expedition._invalidate_active_enemy_cache()
	expedition._refresh_active_enemy_cache()
	assert(expedition._streamed_enemy_indices.size() == 1)
	expedition._active_enemy_cache_dirty = false
	expedition._enemy_spatial_cache_dirty = false
	expedition._visibility_anchor_cell = expedition._visibility_cell(expedition.player_pos)
	expedition.player_pos += Vector2.RIGHT * 60.0
	expedition._update_exploration()
	assert(expedition._active_enemy_cache_dirty)
	var campaign: RunState = RunStateScript.new(false)
	campaign.start_run("wayfarer", "campaign_lab", 99117)
	assert(not campaign.loaded_region_ids.is_empty())
	assert(campaign._loaded_floor_shapes.size() < campaign.floor_shapes.size())

func test_expedition_streaming_follows_route_graph() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("wayfarer", "expedition", 717)
	state.current_area_id = 2
	state.player_pos = Vector2(state.areas[2]["center"])
	state.run_graph = {
		"nodes": state.run_graph["nodes"],
		"edges": [
			{"from": 0, "to": 2},
			{"from": 2, "to": 5},
		],
	}
	state._apply_shortcut_world_state()
	assert(state.loaded_region_ids.has(0))
	assert(state.loaded_region_ids.has(2))
	assert(state.loaded_region_ids.has(5))
	assert(not state.loaded_region_ids.has(1))
	assert(not state.loaded_region_ids.has(3))

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
	board.state.start_run("wayfarer", "campaign_lab", 1784339476686)
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
	state.start_run("wayfarer", "campaign_lab", 717)
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
	state.start_run("wayfarer", "expedition", 101)
	state.carried_xp = state.next_upgrade_cost()
	assert(state.level_up_context() == "expedition")
	var choice := state.available_level_up_options()[0]
	var encoded_choice := "%s|prototype_sweeping_cut" % choice if choice == "swordsmanship" else choice
	assert(state.choose_upgrade(encoded_choice))
	assert(state.upgrades.size() == 1 and state.carried_xp == 0)
	assert(state.upgrade_count == 1 and state.next_upgrade_cost() == 10)
	state.start_run("wayfarer", "campaign_lab", 102)
	state.carried_xp = 16
	state.player_pos = state.bonfire_pos
	state.player_hp = 1
	assert(state.activate_waystone() and not state.upgrade_pending and state.player_hp == state.player_max_hp)
	assert(state.secured_xp == 16 and state.can_learn_at_waystone())
	assert(state.learn_at_waystone())
	var first_campaign_choice := String(state.available_level_up_options()[0])
	assert(state.choose_upgrade("%s|prototype_sweeping_cut" % first_campaign_choice if first_campaign_choice == "swordsmanship" else first_campaign_choice))
	assert(state.carried_xp == 10 and state.secured_xp == 10)
	var second_campaign_choice := String(state.available_level_up_options()[0])
	assert(state.choose_upgrade("%s|prototype_sweeping_cut" % second_campaign_choice if second_campaign_choice == "swordsmanship" else second_campaign_choice))
	assert(state.upgrade_count == 2 and state.carried_xp == 0)

func test_mode_policies_and_death() -> void:
	var expedition: RunState = RunStateScript.new(false)
	expedition.start_run("wayfarer", "expedition", 201)
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
	campaign.start_run("wayfarer", "campaign_lab", 202)
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
	state.start_run("wayfarer", "campaign_lab", 212)
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
	state.start_run("wayfarer", "campaign_lab", 203)
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
	state.start_run("wayfarer", "campaign_lab", 303)
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
	assert(state.player_hp == state.player_max_hp and state.potions == state.healing_capacity())
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
	state.start_run("wayfarer", "campaign_lab", 304)
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
	state.start_run("wayfarer", "auto", 404)
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
	state.start_run("wayfarer", "campaign_lab", 505)
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
	var saw_hex := false
	for effect in state.effects:
		if String(effect["kind"]) == "hex": saw_hex = true
	assert(saw_hex)

func test_save_round_trip() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("wayfarer", "campaign_lab", 606)
	state.track_ranks["swordsmanship"] = 1
	state.track_choices["sword_art"] = "prototype_drawing_cut"
	state.player_weapon_art_library.assign(["prototype_drawing_cut"])
	state.player_equipped_weapon_art = "prototype_drawing_cut"
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
	assert(restored.mode_id == "campaign_lab" and restored.progression_mode == "waystone_sheet" and restored.carried_xp == 13)
	assert(restored.secured_xp == 13 and restored.shortcut_unlocked and restored.run_seed == 606)
	assert(String(restored.player_actor()["weapon_frame"]) == "sword")
	assert(int(restored.track_ranks["swordsmanship"]) == 1)
	assert(restored.track_choice("sword_art") == "prototype_drawing_cut")
	assert(restored.player_equipped_weapon_art == "prototype_drawing_cut")
	assert(Dictionary(restored.enemies[0]).has("attributes") and Dictionary(restored.enemies[0]).has("weapon_frame"))

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
	assert(not restored.load_run(path))

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
	assert(not restored.load_run(path))

func test_version_twelve_world_grammar_migration() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("wayfarer", "campaign_lab", 99117)
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
	assert(not restored.load_run(path))
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
	assert(String(state.enemies[0]["kind"]) == "boar")
	assert(state.upgrades.is_empty())
