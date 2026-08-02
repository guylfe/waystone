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
	board._survey_rating_pressed("want_again", 4)
	assert(not board.survey_submit_button.disabled)
	assert(board.survey_notes.virtual_keyboard_enabled)
	assert(board.survey_notes.get_theme_font_size("font_size") >= 19)
	var selected_button: Button = board.survey_rating_buttons["want_again"][3]
	assert(selected_button.get_theme_color("font_pressed_color").get_luminance() > 0.9)
	board._submit_survey_feedback()
	assert(board.state.survey_room_number == 2)
	assert(not board.state.survey_feedback_pending)
	print("COMBAT SURVEY setup and questionnaire UI: PASS")
	quit(0)
