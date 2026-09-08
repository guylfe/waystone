extends SceneTree

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	var board = load("res://scenes/main.tscn").instantiate()
	root.add_child(board)
	await process_frame
	await process_frame
	board.state.abandon_run()
	board.setup_mode = "combat_survey"
	board._layout()
	board.queue_redraw()
	await process_frame
	await process_frame
	_capture("res://builds/survey-setup.png")
	board.state.start_run("rogue_acrobat", "combat_survey", 919191, "encounter")
	board.state.player_action = board.state._action("wait", board.state.SIM_DT * 2.0, Vector2.ZERO)
	for enemy in board.state.enemies: enemy["hp"] = 0
	board.state._remove_dead_enemies()
	board.state._tick(board.state.SIM_DT)
	board.state._tick(board.state.SIM_DT)
	assert(board.state.survey_feedback_pending)
	board.visual = board.state.snapshot(true)
	board.queue_redraw()
	await process_frame
	await process_frame
	_capture("res://builds/survey-room-clear.png")
	await create_timer(board.ROOM_CLEAR_HOLD_SECONDS + 0.1).timeout
	board.queue_redraw()
	await process_frame
	await process_frame
	_capture("res://builds/survey-feedback.png")
	quit(0)

func _capture(path: String) -> void:
	var image := root.get_texture().get_image()
	assert(image != null and image.save_png(path) == OK)
