extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _init() -> void:
	test_full_combo_costs()
	test_unused_combo_phases_are_free()
	test_bow_release_costs_follow_draw()
	test_overdraw_completes_then_winds_player()
	test_regeneration_sources_and_exclusions()
	test_temperament_packages()
	test_defensive_and_utility_actions_are_free()
	test_enemies_share_stamina_attribute_without_spending_it()
	print("Stamina costs, overexertion, regeneration, and temperament packages: PASS")
	quit(0)

func fresh_state(loadout: String = "warrior") -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run(loadout, "expedition", 230203)
	state.enemies.clear()
	state.walls.clear()
	return state

func advance_until_ready(state: RunState, limit: int = 3000) -> void:
	var ticks := 0
	while not state.is_player_ready() and state.player_hp > 0 and ticks < limit:
		state.advance_streamed_action_tick()
		ticks += 1
	assert(ticks < limit)

func test_full_combo_costs() -> void:
	var sword := fresh_state()
	assert(sword.request_combo(Vector2.RIGHT, false))
	advance_until_ready(sword)
	assert(is_equal_approx(sword.player_stamina, 12.0))
	var knife := fresh_state("rogue_acrobat")
	assert(knife.request_combo(Vector2.RIGHT, false))
	advance_until_ready(knife)
	assert(is_equal_approx(knife.player_stamina, 12.0))
	var twin := fresh_state("rogue_acrobat")
	twin.player_weapon_frame = "twin_knives"
	assert(twin.request_combo(Vector2.RIGHT, false))
	advance_until_ready(twin)
	assert(is_equal_approx(twin.player_stamina, 12.0))

func test_unused_combo_phases_are_free() -> void:
	var state := fresh_state()
	assert(state.request_combo(Vector2.RIGHT, false))
	assert(is_equal_approx(state.player_stamina, 70.0))
	state.set_attack_hold(false)
	advance_until_ready(state)
	assert(is_equal_approx(state.player_stamina, 70.0))

func test_bow_release_costs_follow_draw() -> void:
	var loose := fresh_state("rogue_sharpshooter")
	assert(loose.begin_bow_draw(Vector2.RIGHT))
	assert(loose.release_bow_attack())
	assert(is_equal_approx(loose.player_stamina, 84.0))
	var full := fresh_state("rogue_sharpshooter")
	assert(full.begin_bow_draw(Vector2.RIGHT))
	full.player_action["elapsed"] = 0.90
	assert(full.release_bow_attack())
	assert(is_equal_approx(full.player_stamina, 66.0))

func test_overdraw_completes_then_winds_player() -> void:
	var state := fresh_state()
	state.player_stamina = 10.0
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(is_equal_approx(state.player_stamina, 0.0))
	assert(is_equal_approx(state.stamina_spent_total, 30.0))
	var saw_winded := false
	var ticks := 0
	while not state.is_player_ready() and ticks < 3000:
		state.advance_streamed_action_tick()
		if String(state.player_action.get("kind", "")) == "winded": saw_winded = true
		ticks += 1
	assert(saw_winded)
	assert(is_equal_approx(state.player_stamina, 35.0))
	assert(state.overexertion_count == 1)
	assert(state.winded_time_total >= 1.16)

func test_regeneration_sources_and_exclusions() -> void:
	var movement := fresh_state()
	movement.player_stamina = 50.0
	assert(movement.request_move(Vector2.RIGHT, movement.MOVE_RANGE, false))
	advance_until_ready(movement)
	var movement_gain := movement.player_stamina - 50.0
	var waiting := fresh_state()
	waiting.player_stamina = 50.0
	assert(waiting.request_wait(0.10, false))
	advance_until_ready(waiting)
	assert(absf((waiting.player_stamina - 50.0) - movement_gain) <= 0.26)
	var attack := fresh_state()
	attack.player_stamina = 50.0
	assert(attack.request_attack(attack.player_pos + Vector2.RIGHT * 100.0, false))
	advance_until_ready(attack)
	assert(is_equal_approx(attack.player_stamina, 20.0))
	assert(is_equal_approx(attack.stamina_regenerated_total, 0.0))

func test_temperament_packages() -> void:
	var steadfast := fresh_state()
	steadfast._apply_character_stage("steadfast_1", "vigilance")
	assert(is_equal_approx(steadfast.player_max_stamina, 110.0))
	assert(int(steadfast.player_attributes["awareness"]) == 6)
	assert(int(steadfast.player_attributes["speed"]) == 5)
	var finesse := fresh_state("rogue_acrobat")
	var hp_before := finesse.player_max_hp
	var awareness_before := int(finesse.player_attributes["awareness"])
	finesse._apply_character_stage("finesse_1", "subtlety")
	assert(finesse.player_max_hp == hp_before + 5)
	assert(int(finesse.player_attributes["stealth"]) == 8)
	assert(int(finesse.player_attributes["awareness"]) == awareness_before)
	var patient := fresh_state("rogue_sharpshooter")
	var stealth_before := int(patient.player_attributes["stealth"])
	patient._apply_character_stage("patient_1", "observation")
	assert(is_equal_approx(patient.player_max_stamina, 110.0))
	assert(int(patient.player_attributes["awareness"]) == 9)
	assert(int(patient.player_attributes["stealth"]) == stealth_before)

func test_defensive_and_utility_actions_are_free() -> void:
	var state := fresh_state()
	var before := state.player_stamina
	assert(state.request_dodge(Vector2.RIGHT, false))
	advance_until_ready(state)
	assert(is_equal_approx(state.player_stamina, before))
	state.player_stamina = 50.0
	state.rally_cooldown = 0.0
	assert(state.request_rally(false))
	advance_until_ready(state)
	assert(state.player_stamina > 50.0)
	var rogue := fresh_state("rogue_acrobat")
	rogue.player_stamina = 50.0
	assert(rogue.request_stealth(false))
	advance_until_ready(rogue)
	assert(rogue.player_stamina > 50.0)

func test_enemies_share_stamina_attribute_without_spending_it() -> void:
	var state := fresh_state()
	var enemy := state._make_enemy("boar", state.player_pos + Vector2.RIGHT * 260.0, 35)
	assert(int(Dictionary(enemy["attributes"])["stamina"]) == 100)
	state.enemies = [enemy]
	state._invalidate_active_enemy_cache()
	assert(state.request_wait(0.5, false))
	advance_until_ready(state)
	assert(int(Dictionary(state.enemies[0]["attributes"])["stamina"]) == 100)
