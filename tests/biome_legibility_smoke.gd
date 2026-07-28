extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.desktop_controls = true
	DisplayServer.window_set_size(Vector2i(1100, 760))
	await process_frame
	await process_frame
	scene.state.start_run("wayfarer", "expedition", 739391)
	for area_id in range(7):
		scene.state.current_area_id = area_id
		scene.state.player_pos = Vector2(scene.state.areas[area_id]["center"])
		scene.state._apply_shortcut_world_state()
		scene.state._update_exploration(true)
		scene.visual = scene.state.snapshot()
		scene.queue_redraw()
		await process_frame
		await process_frame
		_capture("res://builds/biome-%d-iso.png" % (area_id + 1))
		scene._toggle_view()
		await process_frame
		_capture("res://builds/biome-%d-top.png" % (area_id + 1))
		scene._toggle_view()
	quit(0)

func _capture(path: String) -> void:
	var image := root.get_texture().get_image()
	assert(image.save_png(path) == OK)
