extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _init() -> void:
	test_parallel_rule_sets()
	test_new_combo_costs()
	test_overdraw_starts_exhaustion_after_recovery()
	test_exhaustion_uses_fixed_world_time()
	test_dodge_cost_and_utility_regeneration()
	test_shared_terminal_recovery_and_stamina_combo_reward()
	test_warrior_speed_and_sweeping_cut_budgeting()
	test_stamina_dodge_forms_improve_the_basic_dodge()
	test_direct_attack_is_deliberate_and_profile_scoped()
	test_exhaustion_slows_movement()
	test_desperate_dodge_is_the_only_exhausted_action()
	test_temperament_packages()
	test_enemies_share_stamina_attribute_without_spending_it()
	print("Recovery/Stamina profiles, overdraw, exhaustion, and regeneration: PASS")
	quit(0)

func fresh_state(loadout: String = "warrior", rules: String = "stamina") -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run(loadout, "expedition", 230203, "encounter", rules)
	state.enemies.clear()
	state.walls.clear()
	return state

func advance_until_ready(state: RunState, limit: int = 3000) -> void:
	var ticks := 0
	while not state.is_player_ready() and state.player_hp > 0 and ticks < limit:
		state.advance_streamed_action_tick()
		ticks += 1
	assert(ticks < limit)

func test_parallel_rule_sets() -> void:
	var recovery := fresh_state("warrior", "recovery")
	var recovery_definition := recovery.player_basic_attack_definition()
	var recovery_duration := float(recovery_definition["duration"])
	assert(recovery.request_attack(recovery.player_pos + Vector2.RIGHT * 100.0, false))
	assert(is_equal_approx(recovery.player_stamina, 100.0))
	assert(not recovery.stamina_actions_locked())
	var stamina := fresh_state()
	assert(stamina.request_attack(stamina.player_pos + Vector2.RIGHT * 100.0, false))
	assert(is_equal_approx(stamina.player_stamina, 91.0))
	assert(float(stamina.player_action["duration"]) < recovery_duration)

func test_new_combo_costs() -> void:
	# These are whole-sequence costs, so each combo is started from a live input
	# and held throughout. Continuation is sampled at every link point: without a
	# held input the sequence stops after its opening strike and only that strike
	# is paid for. See WAYSTONE_MIGRATION_HANDOFF.md section 5.3.
	var sword := fresh_state()
	assert(sword.request_combo(Vector2.RIGHT, false, true))
	advance_until_ready(sword)
	assert(is_equal_approx(sword.player_stamina, 72.0))
	var knife := fresh_state("rogue_acrobat")
	assert(knife.request_combo(Vector2.RIGHT, false, true))
	advance_until_ready(knife)
	assert(is_equal_approx(knife.player_stamina, 73.0))
	var twin := fresh_state("rogue_acrobat")
	twin.player_weapon_frame = "twin_knives"
	assert(twin.request_combo(Vector2.RIGHT, false, true))
	advance_until_ready(twin)
	assert(is_equal_approx(twin.player_stamina, 70.0))

func test_overdraw_starts_exhaustion_after_recovery() -> void:
	var state := fresh_state()
	state.player_stamina = 8.0
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(is_equal_approx(state.player_stamina, 0.0))
	assert(state.player_overexertion_pending)
	assert(is_equal_approx(state.player_exhaustion_remaining, 0.0))
	advance_until_ready(state)
	assert(not state.player_overexertion_pending)
	assert(is_equal_approx(state.player_exhaustion_remaining, state.EXHAUSTION_DURATION))
	assert(state.overexertion_count == 1)
	assert(not state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))

func test_exhaustion_uses_fixed_world_time() -> void:
	var state := fresh_state()
	state.player_stamina = 1.0
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	advance_until_ready(state)
	assert(is_equal_approx(state.player_exhaustion_remaining, state.EXHAUSTION_DURATION))
	assert(state.request_wait(0.6, false))
	advance_until_ready(state)
	assert(absf(state.player_exhaustion_remaining - (state.EXHAUSTION_DURATION - 0.6)) <= 0.02)
	# Regeneration runs *through* exhaustion now rather than waiting it out, so the
	# bar is already refilling while the lockout is still in force.
	assert(state.player_stamina > 10.0)
	assert(state.request_move(Vector2.RIGHT, state.MOVE_RANGE, false))
	advance_until_ready(state)
	assert(state.player_exhaustion_remaining < state.EXHAUSTION_DURATION - 0.6)
	assert(state.request_wait(0.8, false))
	advance_until_ready(state)
	assert(is_equal_approx(state.player_exhaustion_remaining, 0.0))
	assert(state.stamina_regen_active_time_total >= 1.3)
	# Spending no longer arms the delay -- only being hit does, and nothing hit here.
	assert(is_equal_approx(state.stamina_regen_delay_time_total, 0.0))

func test_dodge_cost_and_utility_regeneration() -> void:
	var stamina := fresh_state()
	assert(stamina.request_dodge(Vector2.RIGHT, false))
	advance_until_ready(stamina)
	assert(is_equal_approx(stamina.player_stamina, 91.0))
	assert(is_equal_approx(stamina.dodge_cooldown, 0.0))
	stamina.player_stamina = 50.0
	assert(stamina.request_rally(false))
	advance_until_ready(stamina)
	# Rally spends nothing, and now regenerates while it runs.
	assert(stamina.player_stamina >= 50.0)
	assert(stamina.request_wait(1.1, false))
	advance_until_ready(stamina)
	assert(stamina.player_stamina > 50.0)
	var recovery := fresh_state("warrior", "recovery")
	assert(recovery.request_dodge(Vector2.RIGHT, false))
	advance_until_ready(recovery)
	assert(is_equal_approx(recovery.player_stamina, 100.0))
	assert(recovery.dodge_cooldown > 0.0)

func test_shared_terminal_recovery_and_stamina_combo_reward() -> void:
	var recovery := fresh_state("warrior", "recovery")
	assert(recovery.request_combo(Vector2.RIGHT, false))
	var recovery_phases: Array = recovery.player_action["phases"]
	assert(int(Dictionary(recovery_phases[1])["damage_min"]) == 10)
	assert(int(Dictionary(recovery_phases[2])["damage_min"]) == 15)
	assert(is_equal_approx(float(Dictionary(recovery_phases[1])["posture"]), 2.2))

	var stamina := fresh_state()
	assert(stamina.request_combo(Vector2.RIGHT, false))
	var stamina_phases: Array = stamina.player_action["phases"]
	assert(int(Dictionary(stamina_phases[0])["damage_min"]) == 10)
	assert(int(Dictionary(stamina_phases[1])["damage_min"]) == 13)
	assert(int(Dictionary(stamina_phases[2])["damage_min"]) == 17)
	assert(is_equal_approx(float(Dictionary(stamina_phases[1])["posture"]), 2.8))
	assert(is_equal_approx(float(Dictionary(stamina_phases[2])["posture"]), 4.5))
	for index in range(recovery_phases.size()):
		var recovery_phase := Dictionary(recovery_phases[index])
		var stamina_phase := Dictionary(stamina_phases[index])
		assert(is_equal_approx(float(recovery_phase["startup"]), float(stamina_phase["startup"])))
		assert(is_equal_approx(float(recovery_phase["active_end"]), float(stamina_phase["active_end"])))
		assert(is_equal_approx(float(recovery_phase["link"]), float(stamina_phase["link"])))
		assert(is_equal_approx(float(recovery_phase["end"]), float(stamina_phase["end"])))
		assert(float(recovery_phase["link"]) < float(recovery_phase["end"]))
	assert(float(Dictionary(recovery_phases[1])["startup"]) < float(Dictionary(recovery_phases[0])["end"]))

	recovery.set_attack_hold(false)
	advance_until_ready(recovery)
	assert(recovery.terminal_combo_recoveries_total == 1)
	assert(recovery.terminal_combo_recovery_time_total > 0.20)
	assert(recovery.request_combo(Vector2.RIGHT, false))

	stamina.set_attack_hold(false)
	advance_until_ready(stamina)
	assert(is_equal_approx(stamina.basic_attack_lock_remaining(), 0.0))
	assert(stamina.terminal_combo_recoveries_total == 1)
	assert(stamina.terminal_combo_recovery_time_total > 0.20)
	assert(stamina.request_combo(Vector2.RIGHT, false))

func test_warrior_speed_and_sweeping_cut_budgeting() -> void:
	# Sweeping Cut lost its attack cooldown under Stamina rules when it was rebuilt
	# as the combo's finisher. It is now governed the way every other physical
	# attack is -- commitment, recovery and cost -- so this asserts the cost does
	# the limiting rather than a timer. Recovery rules keep their own budgeting,
	# which is the profiles' actual difference.
	var stamina := fresh_state()
	assert(is_equal_approx(stamina.player_move_speed, 260.0))
	stamina.player_weapon_art_library.assign(["prototype_sweeping_cut"])
	stamina.player_equipped_weapon_art = "prototype_sweeping_cut"
	var before := stamina.player_stamina
	assert(stamina.request_sweeping_cut(Vector2.RIGHT, false))
	assert(is_equal_approx(stamina.skill_cooldown, 0.0))
	assert(is_equal_approx(before - stamina.player_stamina, stamina.stamina_cost(stamina.SWEEPING_CUT_STAMINA)))
	advance_until_ready(stamina)
	assert(is_equal_approx(stamina.skill_cooldown, 0.0))
	# Halved costs put three sweeps in a full bar and overdraw on the fourth. Cost
	# still does the limiting; it now limits a burst rather than a single use.
	var sweeps := 1
	while stamina.player_stamina > 0.0001 and sweeps < 8:
		assert(stamina.request_sweeping_cut(Vector2.RIGHT, false))
		advance_until_ready(stamina)
		sweeps += 1
	assert(sweeps == 4)
	assert(stamina.player_overexertion_pending or stamina.player_exhaustion_remaining > 0.0001)

	var recovery := fresh_state("warrior", "recovery")
	recovery.player_weapon_art_library.assign(["prototype_sweeping_cut"])
	recovery.player_equipped_weapon_art = "prototype_sweeping_cut"
	assert(recovery.request_sweeping_cut(Vector2.RIGHT, false))
	assert(is_equal_approx(recovery.skill_cooldown, recovery.SWEEP_COOLDOWN))

	var rogue := fresh_state("rogue_acrobat")
	assert(is_equal_approx(rogue.player_move_speed, rogue.MOVE_SPEED))

func test_stamina_dodge_forms_improve_the_basic_dodge() -> void:
	var basic := fresh_state()
	assert(basic.request_dodge(Vector2.RIGHT, false))
	var basic_action := basic.player_action
	assert(is_equal_approx((float(basic_action["move_end"]) - float(basic_action["move_start"])) * float(basic_action["speed"]), 150.0))
	assert(is_equal_approx(float(basic_action["evade_end"]) - float(basic_action["evade_start"]), 0.24))
	assert(is_equal_approx(float(basic_action["duration"]) - float(basic_action["evade_end"]), 0.24))

	var practised := fresh_state()
	practised.track_ranks["evasion"] = 1
	assert(practised.request_dodge(Vector2.RIGHT, false))
	var practised_action := practised.player_action
	assert(is_equal_approx((float(practised_action["move_end"]) - float(practised_action["move_start"])) * float(practised_action["speed"]), 168.0))
	assert(is_equal_approx(float(practised_action["evade_end"]) - float(practised_action["evade_start"]), 0.30))
	assert(is_equal_approx(float(practised_action["duration"]) - float(practised_action["evade_end"]), 0.20))

	var sidestep := fresh_state()
	sidestep.track_ranks["evasion"] = 2
	sidestep.track_choices["evasion_style"] = "sidestep"
	assert(sidestep.request_dodge(Vector2.RIGHT, false))
	var sidestep_action := sidestep.player_action
	assert(is_equal_approx((float(sidestep_action["move_end"]) - float(sidestep_action["move_start"])) * float(sidestep_action["speed"]), 168.0))
	assert(is_equal_approx(float(sidestep_action["evade_end"]) - float(sidestep_action["evade_start"]), 0.30))
	assert(is_equal_approx(float(sidestep_action["duration"]) - float(sidestep_action["evade_end"]), 0.12))

	var long_roll := fresh_state()
	long_roll.track_ranks["evasion"] = 2
	long_roll.track_choices["evasion_style"] = "long_roll"
	assert(long_roll.request_dodge(Vector2.RIGHT, false))
	var roll_action := long_roll.player_action
	assert(is_equal_approx((float(roll_action["move_end"]) - float(roll_action["move_start"])) * float(roll_action["speed"]), 231.0))
	assert(is_equal_approx(float(roll_action["evade_end"]) - float(roll_action["evade_start"]), 0.35))
	assert(is_equal_approx(float(roll_action["duration"]) - float(roll_action["evade_end"]), 0.20))

	var recovery := fresh_state("warrior", "recovery")
	assert(recovery.request_dodge(Vector2.RIGHT, false))
	assert(is_equal_approx(float(recovery.player_action["duration"]), 0.66))
	assert(is_equal_approx(recovery.dodge_cooldown, recovery.DODGE_COOLDOWN))

func test_direct_attack_is_deliberate_and_profile_scoped() -> void:
	var stamina := fresh_state()
	assert(stamina.request_direct_attack(Vector2.LEFT, false))
	assert(stamina.direct_attack_uses_total == 1)
	assert(String(stamina.player_action["kind"]) == "combo")
	assert(Vector2(stamina.player_action["direction"]).dot(Vector2.LEFT) > 0.99)
	var recovery := fresh_state("warrior", "recovery")
	assert(recovery.request_combo(Vector2.LEFT, false))
	assert(recovery.direct_attack_uses_total == 0)

func exhaust(state: RunState) -> void:
	state.player_stamina = 1.0
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	advance_until_ready(state)
	assert(state.player_exhaustion_remaining > 0.0001)

func test_exhaustion_slows_movement() -> void:
	# Exhaustion's teeth are in the legs. A winded step is slow enough that the fast
	# enemies' capture envelopes catch it, which is what makes overdrawing cost.
	var state := fresh_state()
	assert(is_equal_approx(state.current_move_speed(), state.player_move_speed))
	var quick := state.wait_unit_duration()
	exhaust(state)
	assert(is_equal_approx(state.current_move_speed(), state.player_move_speed * state.EXHAUSTED_MOVE_SCALE))
	assert(state.current_move_speed() < 131.0)
	# Wait is one movement step, so it coarsens with the step rather than drifting.
	assert(is_equal_approx(state.wait_unit_duration(), quick / state.EXHAUSTED_MOVE_SCALE))
	var origin := state.player_pos
	assert(state.request_move(Vector2.RIGHT, state.MOVE_RANGE, false))
	var slow_duration := float(state.player_action["duration"])
	advance_until_ready(state)
	assert(absf(state.player_pos.distance_to(origin) - state.MOVE_RANGE) <= 0.5)
	assert(slow_duration > state.MOVE_RANGE / state.player_move_speed * 2.0)

func test_desperate_dodge_is_the_only_exhausted_action() -> void:
	var state := fresh_state()
	exhaust(state)
	# Attacks, combos and weapon arts stay locked.
	assert(not state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(not state.request_advance(Vector2.RIGHT, false, false))
	# The Dodge does not. It is the agency floor -- a hit must always leave one
	# executable response -- so it degrades instead of disappearing.
	var origin := state.player_pos
	assert(state.request_dodge(Vector2.RIGHT, false))
	assert(String(state.player_action["dodge_style"]) == "desperate")
	assert(is_equal_approx(float(state.player_action["duration"]), state.EXHAUSTED_DODGE_DURATION))
	var iframes := float(state.player_action["evade_end"]) - float(state.player_action["evade_start"])
	assert(iframes < 0.24)
	# The debt: bar emptied, clock restarted, and it restarts flat every time.
	assert(is_equal_approx(state.player_stamina, 0.0))
	assert(is_equal_approx(state.player_exhaustion_remaining, state.EXHAUSTION_DURATION))
	assert(state.exhausted_dodge_total == 1 and state.exhausted_dodge_chain == 1)
	advance_until_ready(state)
	# Far enough to clear one envelope, nowhere near a full Dodge's 150 units.
	var travel := state.player_pos.distance_to(origin)
	assert(travel > 68.0 and travel < 120.0)
	var after_first := state.player_exhaustion_remaining
	assert(state.request_dodge(Vector2.RIGHT, false))
	assert(is_equal_approx(state.player_exhaustion_remaining, state.EXHAUSTION_DURATION))
	assert(state.player_exhaustion_remaining > after_first)
	assert(state.exhausted_dodge_chain == 2 and state.exhausted_dodge_max_chain == 2)

func test_temperament_packages() -> void:
	var steadfast := fresh_state()
	steadfast._apply_character_stage("steadfast_1", "vigilance")
	assert(is_equal_approx(steadfast.player_max_stamina, 110.0))
	assert(int(steadfast.player_attributes["awareness"]) == 6)
	var patient := fresh_state("rogue_sharpshooter")
	patient._apply_character_stage("patient_1", "observation")
	assert(is_equal_approx(patient.player_max_stamina, 110.0))
	assert(int(patient.player_attributes["awareness"]) == 9)

func test_enemies_share_stamina_attribute_without_spending_it() -> void:
	var state := fresh_state()
	var enemy := state._make_enemy("boar", state.player_pos + Vector2.RIGHT * 260.0, 35)
	assert(int(Dictionary(enemy["attributes"])["stamina"]) == 100)
	state.enemies = [enemy]
	state._invalidate_active_enemy_cache()
	assert(state.request_wait(0.5, false))
	advance_until_ready(state)
	assert(int(Dictionary(state.enemies[0]["attributes"])["stamina"]) == 100)
