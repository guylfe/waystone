extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")
const PresentationFrameScript = preload("res://scripts/presentation/presentation_frame.gd")

func _init() -> void:
	test_loadout_sheets_and_gates()
	test_knife_sequences_and_art_choice()
	test_combo_presentation_and_sequence_recovery()
	test_twin_fang_simultaneous_contact()
	test_combo_scoped_hit_reaction()
	test_stealth_and_vault()
	test_stealth_eligibility_breaks_and_alerts()
	test_bow_draw_release_and_arts()
	test_sharpshooter_preparation_and_range()
	test_universal_attributes_conditions_and_defenses()
	test_v010_save_migration()
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
	assert(String(state.player_action["kind"]) == "twin_fang")
	assert(not state.player_action.has("phases"))
	assert(is_equal_approx(float(state.player_action["damage_per_blade"]), 8.0))

func test_combo_presentation_and_sequence_recovery() -> void:
	var knife := fresh("rogue_acrobat")
	assert(knife.request_combo(Vector2.RIGHT, false))
	assert(int(knife.player_action["combo_length"]) == 4)
	var frame: PresentationFrame = PresentationFrameScript.new()
	var captured := frame.capture(knife)
	assert(int(Dictionary(captured["player_action"])["combo_length"]) == 4)
	knife.player_action = knife._idle_action()
	assert(knife.choose_upgrade("knife|knife_twin_fang"))
	assert(knife.request_combo(Vector2.RIGHT, false))
	assert(int(knife.player_action["combo_length"]) == 6)
	advance_until_ready(knife)
	assert(knife.weapon_sequence_cooldown > 0.95)
	assert(not knife.request_combo(Vector2.RIGHT, false))
	assert(knife.request_move(Vector2.RIGHT, 48.0, false))
	advance_until_ready(knife)
	assert(knife.weapon_sequence_cooldown < 0.95)
	var sword := fresh("warrior")
	assert(sword.request_combo(Vector2.RIGHT, false))
	assert(int(sword.player_action["combo_length"]) == 3)

func test_twin_fang_simultaneous_contact() -> void:
	var state := fresh("rogue_acrobat")
	assert(state.choose_upgrade("knife|knife_twin_fang"))
	var target := state._make_enemy("knife", state.player_pos + Vector2.RIGHT * 92.0, 80)
	target["layer"] = state.current_layer
	target["awareness"] = "alerted"
	state.enemies.append(target)
	state._invalidate_active_enemy_cache()
	assert(state.request_twin_fang(Vector2.RIGHT, false))
	advance_until_ready(state)
	var hit_effects := state.effects.filter(func(effect: Dictionary) -> bool: return String(effect.get("kind", "")) == "hit")
	assert(hit_effects.size() == 2)
	assert(int(target["hp"]) <= 68)
	assert(state.skill_cooldown > 3.5)

func test_combo_scoped_hit_reaction() -> void:
	var state := fresh("rogue_acrobat")
	var enemy := state._make_enemy("knife", state.player_pos + Vector2.RIGHT * 70.0, 80)
	enemy["layer"] = state.current_layer
	var first_source := {"combo_instance_id": 41}
	var idle_before := Dictionary(enemy["action"]).duplicate(true)
	assert(state._apply_enemy_hit_reaction(enemy, 1.0, "alerted", idle_before, Vector2(enemy["pos"]), first_source))
	var first_reaction := Dictionary(enemy["action"]).duplicate(true)
	first_reaction["elapsed"] = 0.30
	enemy["action"] = first_reaction
	assert(not state._apply_enemy_hit_reaction(enemy, 1.0, "alerted", first_reaction, Vector2(enemy["pos"]), first_source))
	assert(is_equal_approx(float(Dictionary(enemy["action"])["elapsed"]), 0.30))
	var second_source := {"combo_instance_id": 42}
	var current_reaction := Dictionary(enemy["action"]).duplicate(true)
	assert(not state._apply_enemy_hit_reaction(enemy, 1.0, "alerted", current_reaction, Vector2(enemy["pos"]), second_source))

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

func test_stealth_eligibility_breaks_and_alerts() -> void:
	var state := fresh("rogue_acrobat")
	var alerted := state._make_enemy("knife", state.player_pos + Vector2.RIGHT * 180.0, 30)
	alerted["layer"] = state.current_layer
	alerted["awareness"] = "alerted"
	var idle := state._make_enemy("knife", state.player_pos + Vector2.DOWN * 220.0, 30)
	idle["layer"] = state.current_layer
	state.enemies.assign([alerted, idle])
	state._invalidate_active_enemy_cache()
	assert(state.stealth_status() == "noticed")
	assert(not state.request_stealth(false))
	state.track_ranks["rogue"] = 4
	assert(state.stealth_status() == "available")
	assert(state.request_stealth(false))
	advance_until_ready(state)
	assert(state.stealth_remaining > 4.0)
	assert(String(alerted["awareness"]) == "suspicious")
	assert(String(idle["awareness"]) == "idle")
	assert(state.request_attack(state.player_pos + Vector2.LEFT * 300.0, false))
	while state.stealth_remaining > 0.0 and not state.is_player_ready(): state.advance_streamed_action_tick()
	assert(state.stealth_remaining == 0.0)
	assert(state.main_ability_cooldown > 11.0)

	var alarm_state := fresh("rogue_acrobat")
	var victim := alarm_state._make_enemy("knife", alarm_state.player_pos + Vector2.RIGHT * 80.0, 30)
	victim["layer"] = alarm_state.current_layer
	var ally := alarm_state._make_enemy("knife", alarm_state.player_pos + Vector2.RIGHT * 180.0, 30)
	ally["layer"] = alarm_state.current_layer
	alarm_state.enemies.assign([victim, ally])
	alarm_state._invalidate_active_enemy_cache()
	alarm_state._register_enemy_hit_awareness(victim, {"unaware": true}, {"duration": 1.0, "elapsed": 0.2})
	assert(String(ally["awareness"]) == "alerted")
	ally["awareness"] = "idle"
	alarm_state.track_ranks["rogue"] = 3
	victim["awareness"] = "idle"
	alarm_state._register_enemy_hit_awareness(victim, {"unaware": true}, {"duration": 1.0, "elapsed": 0.2})
	assert(String(ally["awareness"]) == "idle")
	assert(victim.has("alarm_remaining"))
	alarm_state._update_enemy_alarm(victim, 1.0)
	assert(String(ally["awareness"]) == "alerted")

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

func test_v010_save_migration() -> void:
	var path := "user://rogue-v010-migration.save"
	var state := fresh("rogue_acrobat")
	state.carried_xp = 37
	assert(state.save_run(path))
	var read_file := FileAccess.open(path, FileAccess.READ)
	var payload: Dictionary = read_file.get_var(true)
	read_file.close()
	payload["save_version"] = 22
	payload.erase("weapon_sequence_cooldown")
	var write_file := FileAccess.open(path, FileAccess.WRITE)
	write_file.store_var(payload, true)
	write_file.close()
	var loaded: RunState = RunStateScript.new(false)
	assert(loaded.load_run(path))
	assert(loaded.carried_xp == 37)
	assert(loaded.weapon_sequence_cooldown == 0.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
