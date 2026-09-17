extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.desktop_controls = true
	DisplayServer.window_set_size(Vector2i(1100, 760))
	await process_frame
	await process_frame
	scene.state.start_run("wayfarer", "expedition", 739391)
	var center := Vector2(scene.state.areas[3]["center"])
	scene.state.current_area_id = 3
	scene.state.player_pos = center
	scene.state._apply_shortcut_world_state()
	scene.state._update_exploration(true)
	var samples := [
		{"name": "cold-front", "hazard": {"kind": "cold_front", "pos": center, "radius": 268.0, "elapsed": 0.55, "trigger_at": 0.70, "duration": 2.30, "damage": 3, "source_id": 1, "triggered": false, "layer": scene.state.current_layer}},
		{"name": "fire-breath", "hazard": {"kind": "fire_breath", "pos": center + Vector2(0, 170), "direction": Vector2.UP, "radius": 232.0, "half_angle": 0.52, "elapsed": 0.55, "trigger_at": 0.72, "duration": 1.06, "damage": 3, "source_id": 2, "triggered": false, "layer": scene.state.current_layer}},
		{"name": "sundered-ground", "hazard": {"kind": "sundered_ground", "pos": center, "radius": 156.0, "elapsed": 0.40, "trigger_at": 0.28, "duration": 4.0, "damage": 0, "source_id": 3, "triggered": true, "layer": scene.state.current_layer}},
	]
	for sample_value in samples:
		var sample: Dictionary = sample_value
		scene.state.hazards.clear()
		scene.state.hazards.append(Dictionary(sample["hazard"]))
		scene.visual = scene.state.snapshot()
		scene.queue_redraw()
		await process_frame
		await process_frame
		_capture("res://builds/%s-iso.png" % String(sample["name"]))
		scene._toggle_view()
		await process_frame
		_capture("res://builds/%s-top.png" % String(sample["name"]))
		scene._toggle_view()
	quit(0)

func _capture(path: String) -> void:
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Could not save spell smoke render: %s" % path)
		quit(1)
