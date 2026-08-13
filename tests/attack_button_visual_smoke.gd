extends SceneTree

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	var board = load("res://scenes/main.tscn").instantiate()
	root.add_child(board)
	await process_frame
	await process_frame
	board.state.start_run("warrior", "expedition", 270207, "encounter", "stamina")
	board.state.enemies.clear()
	board.visual = board.state.snapshot(true)
	board._layout()
	board.queue_redraw()
	await process_frame
	await process_frame
	_capture("res://builds/stamina-attack-button.png")
	assert(board.board_rect.encloses(board.attack_rect))
	board.state.start_run("warrior", "expedition", 270207, "encounter", "recovery")
	board.state.enemies.clear()
	board.visual = board.state.snapshot(true)
	board.queue_redraw()
	await process_frame
	await process_frame
	_capture("res://builds/recovery-no-attack-button.png")
	quit(0)

func _capture(path: String) -> void:
	var image := root.get_texture().get_image()
	assert(image != null and image.save_png(path) == OK)
