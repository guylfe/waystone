extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _init() -> void:
	test_true_miss()
	test_authoritative_hit()
	print("Strike-local hit and true-miss diagnostics: PASS")
	quit(0)

func test_true_miss() -> void:
	var state = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 939393, "encounter")
	state.enemies.clear()
	var enemy := state._make_enemy("boar", state.player_pos + Vector2(190.0, 32.0), 35)
	enemy["conditions"] = {"sleep": 10.0}
	state.enemies.append(enemy)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0))
	assert(state.survey_strike_diagnostics.size() == 1)
	var strike := Dictionary(state.survey_strike_diagnostics[0])
	assert(String(strike["result"]) == "miss")
	assert(String(strike["shape"]) == "sector")
	assert(String(strike["closest_enemy"]) == "boar")
	assert(float(strike["forward"]) > 0.0 and absf(float(strike["lateral"])) > 0.0)
	for existing in state.enemies: existing["hp"] = 0
	state._remove_dead_enemies()
	assert(Array(state.survey_pending_record.get("strike_diagnostics", [])).size() == 1)

func test_authoritative_hit() -> void:
	var state = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 939394, "encounter")
	state.enemies.clear()
	var enemy := state._make_enemy("boar", state.player_pos + Vector2.RIGHT * 92.0, 35)
	enemy["conditions"] = {"sleep": 10.0}
	state.enemies.append(enemy)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0))
	assert(state.survey_strike_diagnostics.size() == 1)
	var strike := Dictionary(state.survey_strike_diagnostics[0])
	assert(String(strike["result"]) in ["hit", "interrupted"])
	assert(not Array(strike["targets"]).is_empty())
	assert(not bool(strike["visual_overlap_collision_failure"]))
