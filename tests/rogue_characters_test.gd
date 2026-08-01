extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")

func _init() -> void:
	test_loadout_sheets_and_gates()
	test_knife_sequences_and_art_choice()
	test_stealth_and_vault()
	test_bow_draw_release_and_arts()
	test_sharpshooter_preparation_and_range()
	test_universal_attributes_conditions_and_defenses()
	print("Rogue, weapon, touch-era framework, and universal combat tests passed.")
	quit()

func fresh(loadout: String) -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run(loadout, "expedition", 101010)
	state.enemies.clear()
	state.walls.clear()
	state.carried_xp = 9999
	return state

func advance_until_ready(state: RunState, limit: int = 5000) -> void:
	var ticks := 0
	while not state.is_player_ready() and state.player_hp > 0 and ticks < limit:
		state.advance_streamed_action_tick()
		ticks += 1
	assert(ticks < limit)

func test_loadout_sheets_and_gates() -> void:
	var acrobat := fresh("rogue_acrobat")
	assert(String(acrobat.character_sheet_data()["name"]) == "Rogue · Acrobat")
	assert(acrobat.player_max_hp == 80)
	assert(int(acrobat.player_attributes["strength"]) == 4)
	assert(int(acrobat.player_attributes["defense"]) == 2)
	assert(int(acrobat.player_attributes["resistance"]) == 4)
	assert(acrobat.character_track_order() == ["knife", "evasion", "finesse", "rogue", "acrobat", "adopted"])
	assert(acrobat.available_level_up_options() == ["knife", "evasion", "finesse"])
	var sharpshooter := fresh("rogue_sharpshooter")
	assert(String(sharpshooter.character_sheet_data()["name"]) == "Rogue · Sharpshooter")
	assert(sharpshooter.character_track_order() == ["bow", "evasion", "patient", "rogue", "sharpshooter", "adopted"])
	assert(CombatCatalogScript.loadout_ids().size() == 3)

func test_knife_sequences_and_art_choice() -> void:
	var state := fresh("rogue_acrobat")
	assert(state.request_combo(Vector2.RIGHT, false))
	assert(Array(state.player_action["phases"]).size() == 4)
	assert(String(Dictionary(Array(state.player_action["phases"])[0])["technique"]) == "knife_cut_in")
	state.player_action = state._idle_action()
	assert(state.choose_upgrade("knife|knife_twin_fang"))
	assert(state.player_weapon_frame == "twin_knives")
	assert(state.player_equipped_weapon_art == "knife_twin_fang")
	assert(state.request_combo(Vector2.RIGHT, false))
	assert(Array(state.player_action["phases"]).size() == 6)
	state.player_action = state._idle_action()
	state.skill_cooldown = 0.0
	assert(state.request_twin_fang(Vector2.RIGHT, false))
	assert(Array(state.player_action["phases"]).size() == 2)

func test_stealth_and_vault() -> void:
	var state := fresh("rogue_acrobat")
	assert(state.request_stealth(false))
	advance_until_ready(state)
	assert(state.stealth_remaining > 4.0)
	assert(state.main_ability_cooldown == 0.0)
	assert(state.request_vault(Vector2.RIGHT, false))
	assert(String(state.player_action["kind"]) == "vault")
	var origin := state.player_pos
	advance_until_ready(state)
	assert(state.player_pos.distance_to(origin) > 170.0)
	assert(state.subclass_ability_cooldown > 7.0)

func test_bow_draw_release_and_arts() -> void:
	var state := fresh("rogue_sharpshooter")
	assert(state.begin_bow_draw(Vector2.RIGHT))
	for _tick in range(108): state.advance_streamed_action_tick()
	assert(float(state.player_action["draw_ratio"]) > 0.70)
	assert(state.release_bow_attack(Vector2.RIGHT))
	assert(String(state.player_action["kind"]) == "bow_release")
	while state.projectiles.is_empty(): state.advance_streamed_action_tick()
	assert(not state.projectiles.is_empty())
	var arrow := Dictionary(state.projectiles[0])
	assert(String(arrow["kind"]) == "player_arrow")
	assert(float(arrow["max_range"]) > 500.0)
	advance_until_ready(state)
	state.player_action = state._idle_action()
	state.projectiles.clear()
	assert(state.choose_upgrade("bow|bow_piercing_shot"))
	assert(state.request_skill(Vector2.RIGHT, false))
	while state.projectiles.is_empty(): state.advance_streamed_action_tick()
	assert(state.projectiles.any(func(projectile: Dictionary) -> bool: return String(projectile.get("kind", "")) == "piercing_arrow"))

func test_sharpshooter_preparation_and_range() -> void:
	var state := fresh("rogue_sharpshooter")
	var target := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 250.0, 35)
	target["layer"] = state.current_layer
	state.enemies.append(target)
	state.visible_cells[state._visibility_cell(Vector2(target["pos"]))] = true
	assert(state.request_take_aim(int(target["id"]), false))
	advance_until_ready(state)
	assert(state.aimed_enemy_id == int(target["id"]))
	state.track_ranks["sharpshooter"] = 2
	assert(is_equal_approx(state._aimed_projectile_range_multiplier(), 1.15))
	state.track_ranks["sharpshooter"] = 1
	state.visible_cells.clear()
	assert(not state._sensed_enemy_presentations().is_empty())

func test_universal_attributes_conditions_and_defenses() -> void:
	var state := fresh("rogue_acrobat")
	assert(state._player_physical_damage(2) == 6)
	var threshold := state._condition_threshold("frost", int(state.player_attributes["resistance"]))
	assert(threshold > 16.0)
	assert(state.apply_player_condition_buildup("frost", threshold))
	assert(float(state.player_conditions["frost"]) > 0.0)
	state.player_action = state._idle_action()
	state.defense_id = "block"
	assert(state.request_block(Vector2.RIGHT, false))
	state.player_action["elapsed"] = 0.20
	var posture_before := state.player_posture
	state._resolve_incoming_hit(999, 2, "test", Vector2.RIGHT)
	assert(state.player_posture < posture_before)
	state.set_block_hold(false)
	state.player_action = state._idle_action()
	state.defense_id = "endure"
	assert(state.request_endure(Vector2.RIGHT, false))
	state.player_action["elapsed"] = 0.20
	var hp_before := state.player_hp
	state._resolve_incoming_hit(999, 2, "test", Vector2.RIGHT)
	assert(state.player_hp == hp_before - 4)
