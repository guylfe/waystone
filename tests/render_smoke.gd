extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.desktop_controls = false
	DisplayServer.window_set_size(Vector2i(450, 800))
	await process_frame
	await process_frame
	await process_frame
	scene.state.abandon_run()
	scene.visual = scene.state.snapshot()
	if not _capture("res://builds/setup-smoke.png"): return
	scene.state.start_run("duelist", "expedition", 739391)
	scene.visual = scene.state.snapshot()
	var streamed_origin: Vector2 = scene.state.player_pos
	scene._begin_streamed_move(Vector2.RIGHT)
	for index in range(10): await process_frame
	assert(not scene.streaming_action)
	assert(scene.state.player_pos.distance_to(streamed_origin) > 28.0)
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
	scene.state.player_facing = Vector2.UP
	scene.state.player_action = scene.state._melee_action(1.20, 0.38, 0.68, 136.0, 3, Vector2.UP, "diagonal_cut", "attack")
	scene.state.player_action["elapsed"] = 0.56
	scene.visual = scene.state.snapshot()
	scene.queue_redraw()
	await process_frame
	if not _capture("res://builds/isometric-attack-smoke.png"): return
	scene._toggle_view()
	await process_frame
	if not _capture("res://builds/top-down-attack-smoke.png"): return
	scene._toggle_view()
	scene.state.player_action = scene.state._idle_action()
	scene.visual = scene.state.snapshot()
	scene.map_open = true
	scene.state.map_presentation = "full"
	scene.queue_redraw()
	await process_frame
	if not _capture("res://builds/map-smoke.png"): return
	scene.state.map_presentation = "overlay"
	scene.queue_redraw()
	await process_frame
	if not _capture("res://builds/map-overlay-smoke.png"): return
	scene.map_open = false
	scene._toggle_view()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	scene.queue_redraw()
	await process_frame
	if not _capture("res://builds/top-down-smoke.png"): return
	scene._toggle_view()
	await process_frame
	scene.state.carried_xp = scene.state.next_upgrade_cost()
	scene.state._roll_upgrade_choices("area_exit")
	scene.visual = scene.state.snapshot()
	scene.queue_redraw()
	await process_frame
	await process_frame
	if not _capture("res://builds/upgrade-smoke.png"): return
	scene.state.start_run("duelist", "campaign_lab", 739391)
	var return_gate: Dictionary = scene.state.shortcuts[1]
	var depth_cell: Vector2i = scene.state._visibility_cell(Vector2(scene.state.transitions[0]["to_pos"]))
	scene.state.discovered_cells_by_layer["ruin_depths"] = {depth_cell: true}
	scene.map_open = true
	scene.state.map_presentation = "full"
	scene.map_view_layer = "ruin_depths"
	scene.queue_redraw()
	await process_frame
	if not _capture("res://builds/campaign-layer-map-smoke.png"): return
	scene.map_open = false
	scene.state.player_pos = Vector2(return_gate["near_pos"])
	scene.state._update_exploration(true)
	scene.visual = scene.state.snapshot()
	scene.queue_redraw()
	await process_frame
	await process_frame
	if not _capture("res://builds/locked-shortcut-isometric-smoke.png"): return
	scene._toggle_view()
	await process_frame
	if not _capture("res://builds/locked-shortcut-top-down-smoke.png"): return
	scene._toggle_view()
	scene.state.player_pos = scene.state.bonfire_pos
	scene.state.carried_xp = scene.state.next_upgrade_cost()
	scene.visual = scene.state.snapshot()
	assert(scene._try_waystone_press(scene._world_to_screen(scene.state.bonfire_pos)))
	assert(scene.waystone_menu_open and scene.state.secured_xp == scene.state.carried_xp)
	scene.queue_redraw()
	await process_frame
	await process_frame
	if not _capture("res://builds/waystone-menu-smoke.png"): return
	scene.waystone_menu_open = false
	scene.state.carried_xp = 8
	scene.state.secured_xp = 5
	scene.state.player_pos += Vector2.UP * 240.0
	scene.state._begin_death()
	scene.visual = scene.state.snapshot()
	scene.queue_redraw()
	await process_frame
	await process_frame
	if not _capture("res://builds/death-accounting-smoke.png"): return
	scene.state.return_after_death()
	scene.visual = scene.state.snapshot()
	scene.map_open = true
	scene.state.map_presentation = "full"
	scene.queue_redraw()
	await process_frame
	if not _capture("res://builds/shadow-map-smoke.png"): return
	scene.map_open = false
	scene.state.player_pos = Vector2(scene.state.lost_xp["pos"]) + Vector2.DOWN * 260.0
	scene.visual = scene.state.snapshot()
	scene.queue_redraw()
	await process_frame
	if not _capture("res://builds/shadow-guidance-smoke.png"): return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	await process_frame
	if not _capture("res://builds/landscape-smoke.png"): return
	scene.desktop_controls = true
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	await process_frame
	if not _capture("res://builds/desktop-smoke.png"): return
	quit(0)

func _capture(path: String) -> bool:
	var image := root.get_texture().get_image()
	var result := image.save_png(path)
	if result != OK:
		push_error("Could not save smoke render: %s" % result)
		quit(1)
		return false
	return true
