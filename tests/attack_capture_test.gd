extends SceneTree

# Milestone C — attack capture.
#
# Walking away used to be an unconditional answer. Reacting on the first frame of
# a telegraph and reacting on its last produced the same result: the attack
# missed. Enemies triggered at roughly their own maximum reach and then stood
# still through startup, so no player speed made ordinary melee connect.
#
# Enemies now step forward as they swing. What is locked here is not "walking
# fails" but that walking's effectiveness became a function of *when* it starts:
# early escapes, late does not, and Dodge covers the band between.

const RunStateScript = preload("res://scripts/core/run_state.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func plan_option(kind: String, technique: String) -> Dictionary:
	for option_value in CombatCatalogScript.melee_attack_plan(kind):
		var option := Dictionary(option_value)
		if String(option["technique"]) == technique: return option
	return {}

# Places one enemy at its own strike distance, forces the named attack, then runs
# the player's chosen response starting at `respond_at` as a fraction of startup.
# `response` is "retreat", "lateral", "dodge" or "none".
func trial(kind: String, technique: String, response: String, respond_at: float, seed_value: int = 7001) -> Dictionary:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", seed_value, "encounter", "stamina")
	state.enemies.clear()
	state.walls.clear()
	var option := plan_option(kind, technique)
	var gap := float(option["distance"])
	var enemy := state._make_enemy(kind, state.player_pos + Vector2.RIGHT * gap, 999, 5)
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	enemy["dodge_cooldown"] = 9.0
	enemy["facing"] = Vector2.LEFT
	enemy["action"] = state._intent_melee_action(option, Vector2.LEFT)
	state.enemies.assign([enemy])

	var startup := float(option["startup"])
	var respond_after := startup * respond_at
	var hp_before := state.player_hp
	var responded := response == "none"
	var enemy_origin := Vector2(enemy["pos"])
	var guard := 0
	while guard < 900:
		guard += 1
		var action := Dictionary(Dictionary(state.enemies[0])["action"])
		if String(action.get("kind", "")) != "melee": break
		if not responded and float(action.get("elapsed", 0.0)) >= respond_after:
			responded = true
			match response:
				"retreat": state.request_move(Vector2.LEFT, state.MOVE_RANGE, false)
				"lateral": state.request_move(Vector2.UP, state.MOVE_RANGE, false)
				"dodge": state.request_dodge(Vector2.LEFT, false)
		elif responded and response in ["retreat", "lateral"] and state.is_player_ready():
			# Keep walking: the model assumes a sustained retreat from the decision
			# point, not a single step.
			state.request_move(Vector2.LEFT if response == "retreat" else Vector2.UP, state.MOVE_RANGE, false)
		state._tick(state.SIM_DT)
	return {
		"hit": state.player_hp < hp_before,
		"advanced": enemy_origin.distance_to(Vector2(state.enemies[0]["pos"])),
	}

func test_stationary_player_is_hit() -> void:
	# The floor: an attack that cannot hit someone standing still is not an attack.
	for kind in ["blade", "knife", "bandit", "shield", "brute", "polearm", "captain", "knight"]:
		for option_value in CombatCatalogScript.melee_attack_plan(kind):
			var technique := String(Dictionary(option_value)["technique"])
			var result := trial(kind, technique, "none", 0.0)
			check(bool(result["hit"]), "%s %s failed to hit a stationary player" % [kind, technique])

func test_walking_early_still_escapes() -> void:
	# Walking must stay a real defensive tool. Reading the telegraph early is
	# rewarded, which is the half of the curve that must survive this change.
	var result := trial("blade", "diagonal_cut", "retreat", 0.0)
	check(not bool(result["hit"]), "retreating from the first frame of a Blade cut must still escape")

func test_walking_late_now_fails() -> void:
	# The half that did not exist before: a late read is punished.
	var result := trial("blade", "diagonal_cut", "retreat", 0.9)
	check(bool(result["hit"]), "retreating at 90% of a Blade's telegraph must no longer escape")

func test_dodge_covers_the_late_window() -> void:
	# A fix that makes walking fail is worthless unless something else succeeds.
	var result := trial("blade", "diagonal_cut", "dodge", 0.7)
	check(not bool(result["hit"]), "Dodge must answer the window where walking has stopped working")

func test_attackers_actually_advance() -> void:
	for kind in ["blade", "knife", "bandit", "shield", "brute", "polearm", "captain", "knight"]:
		for option_value in CombatCatalogScript.melee_attack_plan(kind):
			var option := Dictionary(option_value)
			var authored := float(option.get("advance_distance", 0.0))
			check(authored > 0.0, "%s %s has no authored forward travel" % [kind, option["technique"]])
			var result := trial(kind, String(option["technique"]), "none", 0.0)
			# Collision and actor separation can shorten a lunge; it must never exceed
			# what was authored, and must cover most of it in the clear.
			check(float(result["advanced"]) <= authored + 6.0,
				"%s %s advanced %.1f against an authored %.1f" % [kind, option["technique"], result["advanced"], authored])
			check(float(result["advanced"]) >= authored * 0.6,
				"%s %s advanced only %.1f of an authored %.1f" % [kind, option["technique"], result["advanced"], authored])

func test_spear_punishes_retreat_more_than_lateral() -> void:
	# Identity out of geometry rather than bespoke behaviour: stepping forward ruins
	# backing away but makes going around easier, because the enemy ends up closer
	# and its arc is quicker to clear. "Never back away from a spear."
	var radial := trial("polearm", "thrust", "retreat", 0.5)
	var lateral := trial("polearm", "thrust", "lateral", 0.5)
	check(bool(radial["hit"]), "a spear thrust must punish a mid-telegraph retreat")
	check(not bool(lateral["hit"]), "stepping out of a spear's narrow line must still work")

func test_translation_stops_before_arc_contact() -> void:
	# Arcs must plant before their damaging window, so the lunge reads as a
	# committed step rather than the attack sliding into the player.
	for kind in ["blade", "knife", "bandit", "shield"]:
		for option_value in CombatCatalogScript.melee_attack_plan(kind):
			var option := Dictionary(option_value)
			check(float(option["advance_end"]) < float(option["startup"]),
				"%s %s keeps travelling into its own active window" % [kind, option["technique"]])

func test_direction_is_locked() -> void:
	# The lunge travels the committed line and does not home. A player who reads it
	# early and leaves sideways must not be followed.
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 7001, "encounter", "stamina")
	state.enemies.clear()
	state.walls.clear()
	var option := plan_option("blade", "diagonal_cut")
	var enemy := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * float(option["distance"]), 999, 5)
	enemy["awareness"] = "alerted"
	enemy["action"] = state._intent_melee_action(option, Vector2.LEFT)
	state.enemies.assign([enemy])
	var origin := Vector2(enemy["pos"])
	var drift := 0.0
	for _step in range(600):
		# Measure only while the attack itself is running. Once it ends the enemy
		# resumes ordinary pursuit, which legitimately turns and would otherwise be
		# scored as the lunge homing.
		if String(Dictionary(Dictionary(state.enemies[0])["action"]).get("kind", "")) != "melee": break
		drift = maxf(drift, absf(Vector2(state.enemies[0]["pos"]).y - origin.y))
		if state.is_player_ready(): state.request_move(Vector2.UP, state.MOVE_RANGE, false)
		state._tick(state.SIM_DT)
	check(drift < 12.0, "a committed lunge must not steer toward the player, drifted %.1f" % drift)

func _init() -> void:
	test_stationary_player_is_hit()
	test_walking_early_still_escapes()
	test_walking_late_now_fails()
	test_dodge_covers_the_late_window()
	test_attackers_actually_advance()
	test_spear_punishes_retreat_more_than_lateral()
	test_translation_stops_before_arc_contact()
	test_direction_is_locked()
	if failures.is_empty():
		print("Attack capture tests passed.")
		quit(0)
		return
	for failure in failures:
		printerr("FAILED: %s" % failure)
	printerr("Attack capture tests failed: %d" % failures.size())
	quit(1)
