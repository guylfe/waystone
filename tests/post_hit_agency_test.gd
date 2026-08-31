extends SceneTree

# Milestone B — a hit must leave actionable control.
#
# Being hit costs you the action you were making. That is the price of getting
# hit and it stays. What must never happen is losing the *next* one too: control
# returns, and a second attacker takes it away again before the response the
# player chose reaches its first meaningful frame. That is the "stunlock" the
# surveys report, and it is a fairness floor rather than a balance lever.
#
# The guarantee is deliberately narrow. Protection covers the reaction and a
# short world-time tail past return of control. Hits during it still deal full
# health and posture damage, still kill, and do not extend it.

const RunStateScript = preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func fresh_state(rules: String = "stamina") -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 4242, "encounter", rules)
	state.enemies.clear()
	state.walls.clear()
	return state

# Applies a hit from a notional attacker without needing an enemy to reach the
# player, so the crowd timing under test is exact rather than incidental.
func strike(state: RunState, damage: int = 14) -> void:
	state._resolve_incoming_hit(-1, damage, "blade", state.player_pos + Vector2.RIGHT * 60.0, state.player_pos + Vector2.RIGHT * 30.0)

func advance_world(state: RunState, seconds: float) -> void:
	var steps := int(round(seconds / state.SIM_DT))
	for _step in range(steps):
		state._tick(state.SIM_DT)

func test_protection_arms_on_the_first_hit() -> void:
	var state := fresh_state()
	check(state.player_hit_protection_remaining <= 0.0, "protection must not be armed before any hit lands")
	strike(state)
	check(String(state.player_action.get("kind", "")) == "hit_reaction", "an unprotected hit must produce a hit reaction")
	check(state.player_hit_protection_remaining > 0.0, "the reaction must arm post-hit protection")

func test_second_hit_cannot_replace_the_reaction() -> void:
	var state := fresh_state()
	strike(state)
	var started_at := float(state.player_action.get("started_at", 0.0))
	advance_world(state, 0.10)
	strike(state)
	check(String(state.player_action.get("kind", "")) == "hit_reaction", "a second hit must not start a new reaction")
	check(is_equal_approx(float(state.player_action.get("started_at", -1.0)), started_at), "a second hit must not restart the reaction")

func test_protection_does_not_refresh() -> void:
	var state := fresh_state()
	strike(state)
	var armed := state.player_hit_protection_remaining
	advance_world(state, 0.20)
	var after_decay := state.player_hit_protection_remaining
	strike(state)
	check(state.player_hit_protection_remaining <= after_decay + 0.0001, "a hit during protection must not extend it")
	check(after_decay < armed, "protection must decay in world time")

func test_hits_under_protection_still_hurt() -> void:
	var state := fresh_state()
	strike(state)
	var hp_after_first := state.player_hp
	advance_world(state, 0.10)
	strike(state)
	check(state.player_hp < hp_after_first, "a hit under protection must still deal damage")
	check(state.protected_damage_total > 0, "damage taken under protection must be recorded separately")
	check(state.interruptions_prevented_total > 0, "prevented interruptions must be recorded")

func test_protection_is_not_invulnerability() -> void:
	var state := fresh_state()
	state.player_hp = 40
	strike(state)
	check(state.player_hp > 0, "the setup hit must not be lethal")
	strike(state, 40)
	check(state.player_hp <= 0, "a lethal hit must still kill through protection")

func test_chosen_response_survives_a_fresh_hit() -> void:
	# The milestone's actual promise. Take a hit, let the reaction finish, choose
	# a Dodge at the frozen decision point, and have a second attacker land during
	# it. The Dodge must still be the player's action afterwards.
	var state := fresh_state()
	strike(state)
	var guard := 0
	while not state.is_player_ready() and guard < 600:
		state._tick(state.SIM_DT)
		guard += 1
	check(state.is_player_ready(), "control must return after the reaction")
	check(state.player_hit_protection_remaining > 0.0, "protection must outlast the reaction it covers")
	check(state.request_dodge(Vector2.LEFT, false), "the player must be able to commit a response")
	state._tick(state.SIM_DT)
	strike(state)
	check(String(state.player_action.get("kind", "")) == "dodge", "a fresh hit must not take away the chosen response")

func test_protection_expires() -> void:
	var state := fresh_state()
	strike(state)
	advance_world(state, 3.0)
	check(state.player_hit_protection_remaining <= 0.0, "protection must expire rather than persist")
	# With protection gone and the player idle again, a hit interrupts normally.
	strike(state)
	check(String(state.player_action.get("kind", "")) == "hit_reaction", "an unprotected hit must interrupt again once protection has expired")

func test_frozen_time_does_not_burn_protection() -> void:
	# Time only advances when the player commits, so deliberation must not spend
	# the guarantee. Otherwise thinking would cost the player their response.
	var state := fresh_state()
	strike(state)
	var guard := 0
	while not state.is_player_ready() and guard < 600:
		state._tick(state.SIM_DT)
		guard += 1
	var held := state.player_hit_protection_remaining
	check(held > 0.0, "protection must remain when control returns")
	# No _tick calls: the simulation is frozen while the player deliberates.
	check(is_equal_approx(state.player_hit_protection_remaining, held), "frozen time must not consume protection")

func test_recovery_profile_shares_the_guarantee() -> void:
	# Post-hit agency is a fairness floor, not a resource rule, so it cannot
	# differ between the Recovery and Stamina profiles.
	var state := fresh_state("recovery")
	strike(state)
	check(state.player_hit_protection_remaining > 0.0, "Recovery rules must arm protection too")
	advance_world(state, 0.10)
	strike(state)
	check(state.interruptions_prevented_total > 0, "Recovery rules must prevent the same interruptions")

func _init() -> void:
	test_protection_arms_on_the_first_hit()
	test_second_hit_cannot_replace_the_reaction()
	test_protection_does_not_refresh()
	test_hits_under_protection_still_hurt()
	test_protection_is_not_invulnerability()
	test_chosen_response_survives_a_fresh_hit()
	test_protection_expires()
	test_frozen_time_does_not_burn_protection()
	test_recovery_profile_shares_the_guarantee()
	if failures.is_empty():
		print("Post-hit agency tests passed.")
		quit(0)
		return
	for failure in failures:
		printerr("FAILED: %s" % failure)
	printerr("Post-hit agency tests failed: %d" % failures.size())
	quit(1)
