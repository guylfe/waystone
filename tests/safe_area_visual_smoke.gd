extends SceneTree

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1394))
	var board = load("res://scenes/main.tscn").instantiate()
	root.add_child(board)
	await process_frame
	await process_frame
	board.desktop_controls = false
	board.layout_safe_area_override = Rect2(0, board.size.y * 89.0 / 1394.0, board.size.x, board.size.y * 1263.0 / 1394.0)
	board.state.start_run("warrior", "combat_survey", 290801, "attrition", "energy")
	board.state.enemies.clear()
	board.visual = board.state.snapshot(true)
	board._layout()
	board.queue_redraw()
	await process_frame
	await process_frame
	if not board.safe_layout_rect.is_equal_approx(board.layout_safe_area_override):
		push_error("Safe layout override was not preserved: %s != %s" % [board.safe_layout_rect, board.layout_safe_area_override])
		quit(1)
		return
	if not is_equal_approx(board.board_rect.position.y, board.safe_layout_rect.position.y) or board.board_rect.end.y > board.safe_layout_rect.end.y + 0.01 or not board.safe_layout_rect.encloses(board.interaction_rect):
		push_error("Board or controls escaped the safe layout area: safe=%s board=%s interaction=%s" % [board.safe_layout_rect, board.board_rect, board.interaction_rect])
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image == null or image.save_png("res://builds/safe-area-fold-outer.png") != OK:
		push_error("Could not save safe-area visual smoke frame")
		quit(1)
		return
	quit(0)
