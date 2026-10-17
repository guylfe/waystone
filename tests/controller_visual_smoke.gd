extends SceneTree

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var board = load("res://scenes/main.tscn").instantiate()
	root.add_child(board)
	await process_frame
	await process_frame
	board.controller.active = true
	board.state.start_run("mage_elementalist", "expedition", 270207, "encounter", "energy")
	board.visual = board.state.snapshot(true)
	board._presented_area_id = -999999
	board._layout()
	board.controller.aim = Vector2.RIGHT
	await capture("controller-desktop")
	board.controller.palette_open = true
	await capture("controller-palette")
	board.controller.palette_open = false
	board.controller.paused = true
	await capture("controller-menu")
	board.controller.paused = false
	board._open_character_sheet()
	await capture("controller-character")
	board.character_sheet_open = false
	var content = board._expedition_panel("Controller focus check")
	var test_button := Button.new()
	test_button.text = "A confirms · B closes"
	content.add_child(test_button)
	var presses := [0]
	test_button.pressed.connect(func(): presses[0] += 1)
	await capture("controller-native-dialog")
	var entries: Array = board.controller.menu_entries(board)
	for i in entries.size():
		if entries[i].get("control") == test_button: board.controller.focus_index = i
	var confirm := InputEventJoypadButton.new()
	confirm.button_index = JOY_BUTTON_A
	confirm.pressed = true
	board.expedition_dialog.push_input(confirm)
	await process_frame
	confirm = confirm.duplicate()
	confirm.pressed = false
	board.expedition_dialog.push_input(confirm)
	if presses[0] != 1:
		print("FAILED: native window confirm count ", presses[0])
		quit(1)
		return
	board.expedition_dialog.hide()
	board.controller.active = false
	DisplayServer.window_set_size(Vector2i(720, 1280))
	board.desktop_controls = false
	board._layout()
	await capture("controller-touch-preserved")
	print("Controller render smoke passed. Connected pads: ", Input.get_connected_joypads())
	quit()

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image != null and image.save_png("res://.runtime/%s.png" % label) == OK)
