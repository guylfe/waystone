extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(720, 1280)
	await process_frame
	await process_frame
	await process_frame
	if not scene.state.run_active:
		if not _capture("res://builds/setup-smoke.png"): return
	if not scene.state.run_active:
		scene.state.start_run("duelist", "auto", 739391)
		scene.visual = scene.state.snapshot()
	await process_frame
	await process_frame
	scene.queue_redraw()
	await process_frame
	var impact_enemy: Dictionary = scene.state._make_enemy("blade", scene.state.player_pos + Vector2(0, -125), 7, 1)
	impact_enemy["awareness"] = "alerted"
	impact_enemy["hp"] = 4
	scene.state.enemies.clear()
	scene.state.enemies.append(impact_enemy)
	scene.state.player_hp = maxi(1, scene.state.player_max_hp - 3)
	scene.state._add_effect("hit", Vector2(impact_enemy["pos"]), 3)
	scene.visual = scene.state.snapshot()
	scene.queue_redraw()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if not _capture("res://builds/phone-smoke.png"): return
	scene.map_open = true
	scene.queue_redraw()
	await process_frame
	if not _capture("res://builds/map-smoke.png"): return
	scene.map_open = false
	scene._toggle_view()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	scene.queue_redraw()
	await process_frame
	if not _capture("res://builds/isometric-smoke.png"): return
	scene._toggle_view()
	await process_frame
	scene.state.carried_xp = scene.state.next_upgrade_cost()
	scene.state._roll_upgrade_choices("auto")
	scene.visual = scene.state.snapshot()
	scene.queue_redraw()
	await process_frame
	await process_frame
	if not _capture("res://builds/upgrade-smoke.png"): return
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	if not _capture("res://builds/landscape-smoke.png"): return
	quit(0)

func _capture(path: String) -> bool:
	var image := root.get_texture().get_image()
	var result := image.save_png(path)
	if result != OK:
		push_error("Could not save smoke render: %s" % result)
		quit(1)
		return false
	return true
