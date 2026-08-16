extends SceneTree

# Commit distance — g0 must be a controlled quantity.
#
# The capture framework authors one number per attack: `f`, the fraction of its
# windup during which walking still saves you. That number only means anything if
# the enemy starts the attack from a consistent distance. Before this change a
# Blade committed anywhere between 59 and 129 units out — a 70-unit lottery —
# because an enemy only re-decides when its move action ends, and a Blade covers
# 110 units inside one. The same attack was forgiving, harsh, or literally
# unavoidable depending on where that landed.
#
# Measured spreads across 100 seeded approaches per kind:
#   before  blade 69.7  polearm 78.2  captain 51.0  knight 47.5  shield 47.9
#   after   blade  7.3  polearm  0.2  captain  3.4  knight  1.7  shield  2.1
#
# Two properties are locked here: enemies commit inside a tight band around their
# intended strike distance, and enemies with two attacks actually use both.

const RunStateScript = preload("res://scripts/core/run_state.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func fresh_state() -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 4242, "encounter", "stamina")
	state.enemies.clear()
	state.walls.clear()
	return state

# Runs one approach and reports the gap at the moment of commitment.
#
# The seed varies per sample because attack selection consumes the run RNG: a
# fixed seed hands every approach the same roll and collapses the whole sample to
# a single point, which silently hides the randomness this file is measuring.
func approach(kind: String, start_distance: float, enemy_id: int, seed_value: int) -> Dictionary:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", seed_value, "encounter", "stamina")
	state.enemies.clear()
	state.walls.clear()
	var enemy := state._make_enemy(kind, state.player_pos + Vector2.RIGHT * start_distance, 999, enemy_id)
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	enemy["dodge_cooldown"] = 9.0
	enemy["facing"] = Vector2.LEFT
	state.enemies.assign([enemy])
	for _step in range(700):
		state._tick(state.SIM_DT)
		var now: Dictionary = state.enemies[0]
		var action := Dictionary(now["action"])
		if String(action.get("kind", "")) == "melee":
			return {
				"gap": state.player_pos.distance_to(Vector2(now["pos"])),
				"technique": String(action.get("technique_id", "?")),
			}
	return {}

func plan_distance(kind: String, technique: String) -> float:
	for option_value in CombatCatalogScript.melee_attack_plan(kind):
		var option := Dictionary(option_value)
		if String(option["technique"]) == technique: return float(option["distance"])
	return -1.0

func test_commit_distance_band() -> void:
	for kind in ["blade", "knife", "bandit", "shield", "brute", "polearm", "captain", "knight"]:
		var worst := 0.0
		var samples := 0
		var missed := 0
		for id_offset in range(4):
			for distance_step in range(4):
				var result := approach(kind, 300.0 + float(distance_step) * 9.7, 40 + id_offset, 9000 + id_offset * 97 + distance_step * 13)
				if result.is_empty():
					missed += 1
					continue
				samples += 1
				var intended := plan_distance(kind, String(result["technique"]))
				check(intended > 0.0, "%s committed %s, which is not in its plan" % [kind, result["technique"]])
				worst = maxf(worst, absf(float(result["gap"]) - intended))
		check(missed == 0, "%s failed to commit in %d of 16 approaches" % [kind, missed])
		check(samples > 0, "%s produced no commitments at all" % kind)
		# Tolerance covers the band plus one decision's worth of travel. The
		# pre-change deviation was 24-39 units either side of the threshold.
		check(worst <= 12.0, "%s commit gap strayed %.1f units from its intended distance" % [kind, worst])

func test_two_attack_enemies_use_both() -> void:
	# Branch ordering previously made these unreachable on approach: the longer
	# attack was tested at the greater distance and always won, so a Polearm never
	# used its shaft cut and a Knight never cleaved unless the player walked in.
	for kind in ["polearm", "captain", "knight"]:
		var seen := {}
		for id_offset in range(8):
			for distance_step in range(5):
				var result := approach(kind, 300.0 + float(distance_step) * 11.3, 40 + id_offset, 4100 + id_offset * 131 + distance_step * 17)
				if result.is_empty(): continue
				seen[String(result["technique"])] = int(seen.get(String(result["technique"]), 0)) + 1
		for option_value in CombatCatalogScript.melee_attack_plan(kind):
			var technique := String(Dictionary(option_value)["technique"])
			check(int(seen.get(technique, 0)) > 0, "%s never committed %s across 40 approaches" % [kind, technique])

func test_selection_leans_toward_the_suited_range() -> void:
	# Probabilistic, but not indifferent. A Knight met from far away should favour
	# its thrust; one whose space is already taken should favour its cleave.
	var state := fresh_state()
	var far_thrusts := 0
	var near_cleaves := 0
	for trial in range(200):
		var far_enemy := state._make_enemy("knight", state.player_pos + Vector2.RIGHT * 320.0, 999, trial)
		if String(state._melee_intent(far_enemy, 320.0)["technique"]) == "thrust": far_thrusts += 1
		var near_enemy := state._make_enemy("knight", state.player_pos + Vector2.RIGHT * 170.0, 999, trial)
		if String(state._melee_intent(near_enemy, 170.0)["technique"]) == "heavy_cleave": near_cleaves += 1
	check(far_thrusts > 100, "a Knight met at long range should favour its thrust, got %d/200" % far_thrusts)
	check(near_cleaves > 100, "a Knight met at close range should favour its cleave, got %d/200" % near_cleaves)
	# Neither may become a certainty, or the next move is readable from geometry.
	check(far_thrusts < 200, "long-range selection must not be fully deterministic")
	check(near_cleaves < 200, "close-range selection must not be fully deterministic")

func test_intent_is_abandoned_when_the_player_closes() -> void:
	# An enemy that planned a long attack must not back away to honour it once the
	# player has taken its space.
	var state := fresh_state()
	var kept_count := 0
	var rerolled_to_cleave := 0
	for trial in range(120):
		var enemy := state._make_enemy("knight", state.player_pos + Vector2.RIGHT * 300.0, 999, trial)
		enemy["intended_attack"] = "thrust"
		enemy["intended_strike_distance"] = 252.0
		# Just inside the abandon margin: the plan still stands.
		if String(state._melee_intent(enemy, 240.0)["technique"]) == "thrust": kept_count += 1
		enemy["intended_attack"] = "thrust"
		enemy["intended_strike_distance"] = 252.0
		# Well inside it: honouring the plan would mean backing away, so re-pick.
		if String(state._melee_intent(enemy, 120.0)["technique"]) == "heavy_cleave": rerolled_to_cleave += 1
	check(kept_count == 120, "a small gap change must not discard a live intent, kept %d/120" % kept_count)
	check(rerolled_to_cleave > 60, "closing inside an intent must re-pick something suited to the range, got %d/120" % rerolled_to_cleave)

func _init() -> void:
	test_commit_distance_band()
	test_two_attack_enemies_use_both()
	test_selection_leans_toward_the_suited_range()
	test_intent_is_abandoned_when_the_player_closes()
	if failures.is_empty():
		print("Strike commitment tests passed.")
		quit(0)
		return
	for failure in failures:
		printerr("FAILED: %s" % failure)
	printerr("Strike commitment tests failed: %d" % failures.size())
	quit(1)
