extends SceneTree

func _initialize() -> void:
	var board = load("res://scenes/main.tscn").instantiate()
	root.add_child(board)
	await process_frame
	board.state.start_run("rogue_acrobat", "combat_survey", 919191, "encounter")
	board.visual = board.state.snapshot(true)
	board._sync_setup_controls()
	assert(board.state.survey_room_number == 1)
	assert(not board.survey_overlay.visible)
	for enemy in board.state.enemies: enemy["hp"] = 0
	board.state._remove_dead_enemies()
	board._sync_survey_overlay()
	assert(board.survey_overlay.visible)
	assert(board.survey_overlay.get_meta("kind", "") == "feedback")
	assert(board.survey_rating_buttons.size() == 5)
	board._survey_rating_pressed("difficulty", 3)
	board._survey_rating_pressed("fun", 4)
	board._survey_rating_pressed("fairness", 4)
	board._survey_rating_pressed("tactical_interest", 5)
	board._survey_rating_pressed("expedition_fit", 4)
	assert(not board.survey_submit_button.disabled)
	board._submit_survey_feedback()
	assert(board.state.survey_room_number == 2)
	assert(not board.state.survey_feedback_pending)
	print("COMBAT SURVEY setup and questionnaire UI: PASS")
	quit(0)
