extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _init() -> void:
	test_parallel_rule_sets()
	test_new_combo_costs()
	test_overdraw_starts_exhaustion_after_recovery()
	test_exhaustion_uses_fixed_world_time()
	test_dodge_cost_and_utility_regeneration()
	test_shared_terminal_recovery_and_energy_combo_reward()
	test_warrior_speed_and_sweeping_cut_budgeting()
	test_energy_dodge_forms_improve_the_basic_dodge()
	test_direct_attack_is_deliberate_and_profile_scoped()
	test_exhaustion_slows_movement()
	test_desperate_dodge_is_the_only_exhausted_action()
	test_temperament_packages()
	test_enemies_share_energy_attribute_without_spending_it()
	print("Recovery/Energy profiles, overdraw, exhaustion, and regeneration: PASS")
	quit(0)

func fresh_state(loadout: String = "warrior", rules: String = "energy") -> RunState:
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
	assert(is_equal_approx(recovery.player_energy, 100.0))
	assert(not recovery.energy_actions_locked())
	var energy := fresh_state()
	assert(energy.request_attack(energy.player_pos + Vector2.RIGHT * 100.0, false))
	assert(is_equal_approx(energy.player_energy, 100.0 - energy.energy_cost(18.0)))
	assert(float(energy.player_action["duration"]) < recovery_duration)

func test_new_combo_costs() -> void:
	# These are whole-sequence costs, so each combo is started from a live input
	# and held throughout. Continuation is sampled at every link point: without a
	# held input the sequence stops after its opening strike and only that strike
	# is paid for. See WAYSTONE_MIGRATION_HANDOFF.md section 5.3.
	var sword := fresh_state()
	assert(sword.request_combo(Vector2.RIGHT, false, true))
	advance_until_ready(sword)
	assert(is_equal_approx(sword.player_energy, 100.0 - sword.energy_cost(18.0 + 16.0 + 22.0)))
	var knife := fresh_state("rogue_acrobat")
	assert(knife.request_combo(Vector2.RIGHT, false, true))
	advance_until_ready(knife)
	assert(is_equal_approx(knife.player_energy, 100.0 - knife.energy_cost(14.0 + 12.0 + 12.0 + 16.0)))
	var twin := fresh_state("rogue_acrobat")
	twin.player_weapon_frame = "twin_knives"
	assert(twin.request_combo(Vector2.RIGHT, false, true))
	advance_until_ready(twin)
	assert(is_equal_approx(twin.player_energy, 100.0 - twin.energy_cost(12.0 + 9.0 + 9.0 + 9.0 + 9.0 + 12.0)))

func test_overdraw_starts_exhaustion_after_recovery() -> void:
	var state := fresh_state()
	state.player_energy = 8.0
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(is_equal_approx(state.player_energy, 0.0))
	assert(state.player_overexertion_pending)
	assert(is_equal_approx(state.player_exhaustion_remaining, 0.0))
	advance_until_ready(state)
	assert(not state.player_overexertion_pending)
	assert(is_equal_approx(state.player_exhaustion_remaining, state.EXHAUSTION_DURATION))
	assert(state.overexertion_count == 1)
	assert(not state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))

func test_exhaustion_uses_fixed_world_time() -> void:
	var state := fresh_state()
	state.player_energy = 1.0
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	advance_until_ready(state)
	assert(is_equal_approx(state.player_exhaustion_remaining, state.EXHAUSTION_DURATION))
	assert(state.request_wait(0.6, false))
	advance_until_ready(state)
	assert(absf(state.player_exhaustion_remaining - (state.EXHAUSTION_DURATION - 0.6)) <= 0.02)
	# Regeneration runs *through* exhaustion now rather than waiting it out, so the
	# bar is already refilling while the lockout is still in force.
	assert(state.player_energy > 10.0)
	assert(state.request_move(Vector2.RIGHT, state.MOVE_RANGE, false))
	advance_until_ready(state)
	assert(state.player_exhaustion_remaining < state.EXHAUSTION_DURATION - 0.6)
	# Drain the remainder in Wait units rather than one span of a fixed length, so
	# this survives a change to EXHAUSTION_DURATION instead of encoding its value.
	var guard := 0
	while state.player_exhaustion_remaining > 0.0001 and guard < 40:
		assert(state.request_wait(0.4, false))
		advance_until_ready(state)
		guard += 1
	assert(guard < 40)
	assert(is_equal_approx(state.player_exhaustion_remaining, 0.0))
	assert(state.energy_regen_active_time_total >= 1.3)
	# Spending no longer arms the delay -- only being hit does, and nothing hit here.
	assert(is_equal_approx(state.energy_regen_delay_time_total, 0.0))

func test_dodge_cost_and_utility_regeneration() -> void:
	var energy := fresh_state()
	assert(energy.request_dodge(Vector2.RIGHT, false))
	advance_until_ready(energy)
	assert(is_equal_approx(energy.player_energy, 100.0 - energy.energy_cost(energy.DODGE_ENERGY_COST)))
	assert(is_equal_approx(energy.dodge_cooldown, 0.0))
	energy.player_energy = 50.0
	assert(energy.request_rally(false))
	advance_until_ready(energy)
	# Rally spends nothing, and now regenerates while it runs.
	assert(energy.player_energy >= 50.0)
	assert(energy.request_wait(1.1, false))
	advance_until_ready(energy)
	assert(energy.player_energy > 50.0)
	var recovery := fresh_state("warrior", "recovery")
	assert(recovery.request_dodge(Vector2.RIGHT, false))
	advance_until_ready(recovery)
	assert(is_equal_approx(recovery.player_energy, 100.0))
	assert(recovery.dodge_cooldown > 0.0)

func test_shared_terminal_recovery_and_energy_combo_reward() -> void:
	var recovery := fresh_state("warrior", "recovery")
	assert(recovery.request_combo(Vector2.RIGHT, false))
	var recovery_phases: Array = recovery.player_action["phases"]
	assert(int(Dictionary(recovery_phases[1])["damage_min"]) == 10)
	assert(int(Dictionary(recovery_phases[2])["damage_min"]) == 15)
	assert(is_equal_approx(float(Dictionary(recovery_phases[1])["posture"]), 2.2))

	var energy := fresh_state()
	assert(energy.request_combo(Vector2.RIGHT, false))
	var energy_phases: Array = energy.player_action["phases"]
	assert(int(Dictionary(energy_phases[0])["damage_min"]) == 10)
	assert(int(Dictionary(energy_phases[1])["damage_min"]) == 13)
	assert(int(Dictionary(energy_phases[2])["damage_min"]) == 17)
	assert(is_equal_approx(float(Dictionary(energy_phases[1])["posture"]), 2.8))
	assert(is_equal_approx(float(Dictionary(energy_phases[2])["posture"]), 4.5))
	for index in range(recovery_phases.size()):
		var recovery_phase := Dictionary(recovery_phases[index])
		var energy_phase := Dictionary(energy_phases[index])
		assert(is_equal_approx(float(recovery_phase["startup"]), float(energy_phase["startup"])))
		assert(is_equal_approx(float(recovery_phase["active_end"]), float(energy_phase["active_end"])))
		assert(is_equal_approx(float(recovery_phase["link"]), float(energy_phase["link"])))
		assert(is_equal_approx(float(recovery_phase["end"]), float(energy_phase["end"])))
		assert(float(recovery_phase["link"]) < float(recovery_phase["end"]))
	assert(float(Dictionary(recovery_phases[1])["startup"]) < float(Dictionary(recovery_phases[0])["end"]))

	recovery.set_attack_hold(false)
	advance_until_ready(recovery)
	assert(recovery.terminal_combo_recoveries_total == 1)
	assert(recovery.terminal_combo_recovery_time_total > 0.20)
	assert(recovery.request_combo(Vector2.RIGHT, false))

	energy.set_attack_hold(false)
	advance_until_ready(energy)
	assert(is_equal_approx(energy.basic_attack_lock_remaining(), 0.0))
	assert(energy.terminal_combo_recoveries_total == 1)
	assert(energy.terminal_combo_recovery_time_total > 0.20)
	assert(energy.request_combo(Vector2.RIGHT, false))

func test_warrior_speed_and_sweeping_cut_budgeting() -> void:
	# Sweeping Cut lost its attack cooldown under Energy rules when it was rebuilt
	# as the combo's finisher. It is now governed the way every other physical
	# attack is -- commitment, recovery and cost -- so this asserts the cost does
	# the limiting rather than a timer. Recovery rules keep their own budgeting,
	# which is the profiles' actual difference.
	var energy := fresh_state()
	assert(is_equal_approx(energy.player_move_speed, 260.0))
	energy.player_weapon_art_library.assign(["prototype_sweeping_cut"])
	energy.player_equipped_weapon_art = "prototype_sweeping_cut"
	var before := energy.player_energy
	assert(energy.request_sweeping_cut(Vector2.RIGHT, false))
	assert(is_equal_approx(energy.skill_cooldown, 0.0))
	# No longer exempt from ENERGY_COST_SCALE. The surcharge that exemption bought is
	# now carried by the authored number (86 raw, spending ~56), so a global re-tune of
	# the price level moves the sweep with everything else instead of stranding it. The
	# relationship this test actually cares about -- the sweep costs more than a combo
	# outright -- is unchanged, and is now compared scaled against scaled.
	assert(is_equal_approx(before - energy.player_energy, energy.energy_cost(energy.SWEEPING_CUT_ENERGY)))
	assert(energy.energy_cost(energy.SWEEPING_CUT_ENERGY) > energy.energy_cost(18.0 + 16.0 + 22.0) * 1.4)
	advance_until_ready(energy)
	assert(is_equal_approx(energy.skill_cooldown, 0.0))
	# A second sweep is reachable only by overdrawing, which empties the bar. Price
	# parity with the combo could not restrain an action that refills faster than
	# its time advantage decays, so the sweep costs more than a combo outright.
	var sweeps := 1
	while energy.player_energy > 0.0001 and sweeps < 8:
		assert(energy.request_sweeping_cut(Vector2.RIGHT, false))
		advance_until_ready(energy)
		sweeps += 1
	assert(sweeps == 2)
	assert(energy.player_overexertion_pending or energy.player_exhaustion_remaining > 0.0001)

	var recovery := fresh_state("warrior", "recovery")
	recovery.player_weapon_art_library.assign(["prototype_sweeping_cut"])
	recovery.player_equipped_weapon_art = "prototype_sweeping_cut"
	assert(recovery.request_sweeping_cut(Vector2.RIGHT, false))
	# SWEEP_COOLDOWN is gone: cooldowns are derived from the energy price now, so the
	# hand-authored 4.2s no longer exists to compare against. The sweep spends ~56 of a
	# 100 pool, which at 24s per pool is 13.4s -- the finisher without the combo's time
	# is a special attack, not a cheaper route to the same place.
	assert(is_equal_approx(recovery.skill_cooldown, recovery._cooldown_for(recovery.energy_cost(recovery.SWEEPING_CUT_ENERGY))))
	assert(recovery.skill_cooldown > 12.0 and recovery.skill_cooldown < 15.0)

	var rogue := fresh_state("rogue_acrobat")
	assert(is_equal_approx(rogue.player_move_speed, rogue.MOVE_SPEED))

func test_energy_dodge_forms_improve_the_basic_dodge() -> void:
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
	var energy := fresh_state()
	assert(energy.request_direct_attack(Vector2.LEFT, false))
	assert(energy.direct_attack_uses_total == 1)
	assert(String(energy.player_action["kind"]) == "combo")
	assert(Vector2(energy.player_action["direction"]).dot(Vector2.LEFT) > 0.99)
	var recovery := fresh_state("warrior", "recovery")
	assert(recovery.request_combo(Vector2.LEFT, false))
	assert(recovery.direct_attack_uses_total == 0)

func exhaust(state: RunState) -> void:
	state.player_energy = 1.0
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
	assert(is_equal_approx(state.player_energy, 0.0))
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
	assert(is_equal_approx(steadfast.player_max_energy, 110.0))
	assert(int(steadfast.player_attributes["awareness"]) == 6)
	var patient := fresh_state("rogue_sharpshooter")
	patient._apply_character_stage("patient_1", "observation")
	assert(is_equal_approx(patient.player_max_energy, 110.0))
	assert(int(patient.player_attributes["awareness"]) == 9)

func test_enemies_share_energy_attribute_without_spending_it() -> void:
	var state := fresh_state()
	var enemy := state._make_enemy("boar", state.player_pos + Vector2.RIGHT * 260.0, 35)
	assert(int(Dictionary(enemy["attributes"])["energy"]) == 100)
	state.enemies = [enemy]
	state._invalidate_active_enemy_cache()
	assert(state.request_wait(0.5, false))
	advance_until_ready(state)
	assert(int(Dictionary(state.enemies[0]["attributes"])["energy"]) == 100)
