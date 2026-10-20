extends RefCounted

# Explicit debug-build verification of the exported normal-game route. Artificial
# answers are confined to task-isolated user data; ordinary launch never enters it.
static func run(board) -> void:
	if not OS.is_debug_build() or not OS.get_user_data_dir().contains(".runtime"):
		push_error("Survey export probe requires isolated .runtime user data and a debug build.")
		board.get_tree().quit(2)
		return
	var failures: Array = []
	board.set_process(false)
	board.state.abandon_run()
	board.setup_stage="options"
	board.setup_mode="combat_survey"
	board.survey_choices={"version":1,"behavior":"C","scenario":"F2","arrival":"full","scouting":false}
	board._start_run()
	if board.survey_overlay.get_meta("kind","") != "experiment_setup": failures.append("normal Survey setup")
	board._confirm_experiment_setup()
	if not board.state.combat_lab or board.state.enemies.size()!=3: failures.append("preset play")
	board.state.end_survey_run()
	board.room_clear_remaining=0
	board._sync_survey_overlay()
	for question in board.survey_rating_buttons: board._survey_rating_pressed(question,3)
	board.survey_notes.text="AUTOMATED EXPORTED BUILD SMOKE"
	board._submit_survey_feedback()
	var identity: Dictionary = load("res://scripts/core/survey_experiment.gd").identity()
	if not board.state.trial_complete or not board.state.survey_report_text().contains(String(identity["source"])): failures.append("feedback / archive / source identity")
	if not board.state.save_run(): failures.append("exported save")
	var result := {"identity":identity,"failures":failures,"data":OS.get_user_data_dir(),"report":board.state.survey_report_filename()}
	var file := FileAccess.open("user://survey-export-smoke.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("EXPORTED SURVEY PROBE ",JSON.stringify(result))
	board.get_tree().quit(0 if failures.is_empty() else 1)
