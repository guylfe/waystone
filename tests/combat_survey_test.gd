extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _init() -> void:
	var first = RunStateScript.new(false)
	first.start_run("warrior", "combat_survey", 424242, "encounter")
	var second = RunStateScript.new(false)
	second.start_run("warrior", "combat_survey", 424242, "encounter")
	assert(first.survey_room_seed == second.survey_room_seed)
	assert(first.survey_room_definition == second.survey_room_definition)
	assert(first.enemies.size() > 0 and first.enemies.size() <= 6)
	assert(first.current_layer == "survey_arena")
	assert(first.survey_room_number == 1)
	var first_seed: int = first.survey_room_seed
	for enemy in first.enemies: enemy["hp"] = 0
	first._remove_dead_enemies()
	assert(first.survey_feedback_pending)
	assert(String(first.survey_pending_record["outcome"]) == "victory")
	var ratings := {"difficulty": 3, "fun": 4, "fairness": 5, "tactical_interest": 4, "expedition_fit": 4}
	first.submit_survey_feedback(ratings, ["fair", "good mix"], "Deterministic survey smoke test.")
	assert(not first.survey_feedback_pending)
	assert(first.survey_room_number == 2)
	assert(first.survey_room_seed != first_seed)
	assert(first.player_hp == first.player_max_hp)
	assert(Array(first.survey_session["rooms"]).size() == 1)
	first.end_survey_run()
	assert(first.survey_feedback_pending)
	first.submit_survey_feedback(ratings, [], "Stopped after verifying room two.")
	assert(first.trial_complete)
	assert(Array(first.survey_session["rooms"]).size() == 2)
	var report := first.survey_report_text()
	assert("RUN SEED" not in report or "Run seed: 424242" in report)
	assert("ROOM 1" in report and "ROOM 2" in report)
	assert("Room seed:" in report and "Tags: fair, good mix" in report)
	print("COMBAT SURVEY deterministic rooms, feedback, archive, and report: PASS")
	quit(0)
