extends SceneTree

# Milestone D — Sweeping Cut is the combo's finisher, arriving early.
#
# It had become a strictly better version of the strike it was supposed to
# mirror: a 160-degree arc against the turning slash's 117, at the same reach,
# in 23% of the combo's time, for 61% of its Energy. There was no situation in
# which building the sequence for its own finisher was correct, and restoring a
# cooldown never touched that comparison — you swept, walked for four seconds,
# and swept again.
#
# The rebuild charges a premium over the combo for skipping the whole combo's
# time. What is locked here is that relationship, not geometry drift.

const RunStateScript = preload("res://scripts/core/run_state.gd")
const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")

const SWEEPING_CUT_COST_FLOOR := 56.0

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func fresh_state(rules: String = "energy") -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 4242, "encounter", rules)
	state.enemies.clear()
	state.walls.clear()
	return state

func combo_phase(state: RunState, index: int) -> Dictionary:
	state.request_combo(Vector2.RIGHT, false, true)
	var phases: Array = state.player_action.get("phases", [])
	return Dictionary(phases[index])

func test_it_is_the_finisher_not_a_wider_one() -> void:
	var state := fresh_state()
	check(state.request_sweeping_cut(Vector2.RIGHT, false), "Sweeping Cut must be available at full Energy")
	var technique := String(state.player_action.get("technique_id", ""))
	check(technique == "turning_slash", "Sweeping Cut must use the finisher's geometry, got %s" % technique)
	var sweep_arc: Dictionary = AttackGeometryScript.technique("turning_slash")
	var old_arc: Dictionary = AttackGeometryScript.technique("broad_sweep")
	var sweep_width: float = absf(float(sweep_arc["end_angle"]) - float(sweep_arc["start_angle"]))
	var old_width: float = absf(float(old_arc["end_angle"]) - float(old_arc["start_angle"]))
	check(sweep_width < old_width, "the rebuilt arc must be narrower than the broad sweep it replaces")

func test_it_costs_more_than_the_whole_combo() -> void:
	# The finisher without the combo's time is a special attack. Its literal 56
	# price remains about one and a half times the Sword combo's literal 36.
	var swept := fresh_state()
	var before := swept.player_energy
	swept.request_sweeping_cut(Vector2.RIGHT, false)
	var sweep_cost := before - swept.player_energy

	var combo := fresh_state()
	var combo_before := combo.player_energy
	combo.request_combo(Vector2.RIGHT, false, true)
	while combo.advance_streamed_action_tick(): pass
	var combo_cost := combo_before - combo.player_energy

	check(absf(sweep_cost - 56.0) < 0.1, "Sweeping Cut should spend its literal 56, spent %.1f" % sweep_cost)
	check(sweep_cost > combo_cost * 1.5,
		"Sweeping Cut should cost a premium over the combo: sweep %.0f versus combo %.0f" % [sweep_cost, combo_cost])

func test_damage_and_posture_match_the_finisher() -> void:
	for rules in ["energy", "recovery"]:
		var swept := fresh_state(rules)
		swept.request_sweeping_cut(Vector2.RIGHT, false)
		var sweep_damage := int(swept.player_action["damage_min"])
		var sweep_posture := float(swept.player_action["posture_damage"])
		var finisher := combo_phase(fresh_state(rules), 2)
		check(sweep_damage == int(finisher["damage_min"]),
			"%s: sweep damage %d should match the finisher's %d" % [rules, sweep_damage, int(finisher["damage_min"])])
		check(is_equal_approx(sweep_posture, float(finisher["posture"])),
			"%s: sweep posture %.1f should match the finisher's %.1f" % [rules, sweep_posture, float(finisher["posture"])])

func test_reach_matches_the_finisher() -> void:
	var swept := fresh_state()
	swept.request_sweeping_cut(Vector2.RIGHT, false)
	var finisher := combo_phase(fresh_state(), 2)
	check(is_equal_approx(float(swept.player_action["reach"]), float(finisher["reach"])),
		"an un-upgraded sweep should reach exactly as far as the finisher")

func test_terminal_recovery_is_served_in_full() -> void:
	# The recovery used to be shortened under Energy rules, so the commitment the
	# player could see was not the one they paid. Physical timing is shared across
	# profiles; only the resource model differs.
	var energy := fresh_state("energy")
	energy.request_sweeping_cut(Vector2.RIGHT, false)
	var energy_duration := float(energy.player_action["duration"])
	var recovery := fresh_state("recovery")
	recovery.request_sweeping_cut(Vector2.RIGHT, false)
	var recovery_duration := float(recovery.player_action["duration"])
	check(is_equal_approx(energy_duration, recovery_duration),
		"both profiles must serve the same physical commitment, got %.2f and %.2f" % [energy_duration, recovery_duration])
	var active_end := float(energy.player_action["active_end"])
	check(energy_duration - active_end > 0.7,
		"a complete terminal recovery must follow contact, got %.2fs" % (energy_duration - active_end))

func test_no_attack_cooldown_under_energy() -> void:
	# Governed as a physical attack by commitment, recovery and cost, not by an
	# anti-spam timer. Recovery rules keep their own budgeting.
	var state := fresh_state("energy")
	state.request_sweeping_cut(Vector2.RIGHT, false)
	check(state.skill_cooldown <= 0.0001, "Energy rules must not add an attack cooldown")
	var recovery := fresh_state("recovery")
	recovery.request_sweeping_cut(Vector2.RIGHT, false)
	check(recovery.skill_cooldown > 0.0001, "Recovery rules keep their own cooldown budgeting")

func test_energy_now_limits_repetition() -> void:
	# With the cooldown gone, cost is the limiter — but not by refusal. Overdraw is
	# deliberately permitted from any positive Energy, so a second sweep is
	# available and *ruinous*: it empties the bar and hands the player an exhaustion
	# lockout. Cycling it is possible exactly once, and then you are helpless.
	var state := fresh_state("energy")
	check(state.request_sweeping_cut(Vector2.RIGHT, false), "the first sweep must be affordable")
	while state.advance_streamed_action_tick(): pass
	check(state.player_energy < SWEEPING_CUT_COST_FLOOR,
		"one sweep must leave too little to pay for another outright, got %.0f" % state.player_energy)
	state.request_sweeping_cut(Vector2.RIGHT, false)
	while state.advance_streamed_action_tick(): pass
	check(state.player_energy <= 0.01, "a second sweep must empty the bar, got %.0f" % state.player_energy)
	check(state.energy_actions_locked() or state.player_exhaustion_remaining > 0.0,
		"emptying the bar on a second sweep must impose exhaustion rather than being free")

func test_building_the_combo_is_now_worthwhile() -> void:
	# The comparison that was broken: for the same Energy, the full sequence must
	# deliver more than the finisher alone. Otherwise there is still no reason to
	# ever build it.
	var combo := fresh_state()
	combo.request_combo(Vector2.RIGHT, false, true)
	var phases: Array = combo.player_action.get("phases", [])
	var combo_damage := 0
	for phase_value in phases:
		combo_damage += int(Dictionary(phase_value)["damage_min"])
	var swept := fresh_state()
	swept.request_sweeping_cut(Vector2.RIGHT, false)
	var sweep_damage := int(swept.player_action["damage_min"])
	check(combo_damage > sweep_damage,
		"the full sequence must out-damage its own finisher for the same cost, %d versus %d" % [combo_damage, sweep_damage])

func _init() -> void:
	test_it_is_the_finisher_not_a_wider_one()
	test_it_costs_more_than_the_whole_combo()
	test_damage_and_posture_match_the_finisher()
	test_reach_matches_the_finisher()
	test_terminal_recovery_is_served_in_full()
	test_no_attack_cooldown_under_energy()
	test_energy_now_limits_repetition()
	test_building_the_combo_is_now_worthwhile()
	if failures.is_empty():
		print("Sweeping Cut tests passed.")
		quit(0)
		return
	for failure in failures:
		printerr("FAILED: %s" % failure)
	printerr("Sweeping Cut tests failed: %d" % failures.size())
	quit(1)
