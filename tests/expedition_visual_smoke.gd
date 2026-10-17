extends SceneTree
# Render fixtures, not earned-run evidence. Captures real UI at desktop and Fold
# logical viewport sizes; physical-device interaction is checked separately.
const Generator = preload("res://scripts/core/expedition_generator.gd")
const Coordinator = preload("res://scripts/core/expedition_coordinator.gd")
const Executor = preload("res://scripts/core/expedition_combat.gd")

func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame # Let the desktop scene apply its initial window policy first.
	root.min_size=Vector2i(1,1)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_min_size(Vector2i(1,1))
	for viewport in [Vector2i(1100,760),Vector2i(450,870),Vector2i(700,840)]:
		DisplayServer.window_set_size(viewport)
		scene.desktop_controls = viewport.x>900
		await process_frame
		await process_frame
		for biome in range(3):
			scene.state.start_run("warrior","expedition",42)
			scene.state.expedition["biome"]=biome
			scene.state._install_layout(Generator.generate(42,biome))
			scene.state._respawn_enemies()
			scene.state.player_pos=scene.state.expedition_sites[0]["pos"]+Vector2(-200,150)
			scene.state._update_exploration(true)
			scene.visual=scene.state.snapshot()
			scene.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/expedition-%d-%d.png" % [biome,viewport.x])
			print("Rendered requested ",viewport," physical ",DisplayServer.window_get_size()," canvas ",root.get_texture().get_size())
			scene.state.player_pos=scene.state.expedition_markers["merchant"]
			scene.state._update_exploration(true)
			scene.state.expedition["crowns"]=100
			scene.state.expedition["completed"]=range(biome)
			scene.state.expedition["departed"]=range(biome)
			scene.state.expedition["writ"]=biome>0
			scene.visual=scene.state.snapshot()
			scene._show_expedition_shop()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/merchant-%d-%d.png" % [biome,viewport.x])
			scene.expedition_dialog.hide()
			scene.state.player_pos=scene.state.expedition_markers["landmark"]
			scene.state._update_exploration(true)
			scene.visual=scene.state.snapshot()
			scene.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/vista-%d-%d.png" % [biome,viewport.x])
			scene.state.player_pos=Vector2(11680,2200)
			scene.state._update_exploration(true)
			for enemy in scene.state.enemies:
				if int(enemy.get("expedition_site",-1))!=9: continue
				enemy["expedition_attack_index"]=1 if biome!=1 else 0
				Executor.choose(scene.state,enemy)
			scene.visual=scene.state.snapshot()
			scene.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/boss-%d-%d.png" % [biome,viewport.x])
			var saved_time: float = scene.state.simulation_time
			for frame in range(4): await process_frame
			assert(is_equal_approx(saved_time,scene.state.simulation_time),"Thinking time remains frozen")
	# Touch and mouse use the actual board input path. Map inspection must not
	# secretly advance the simulation, including while a merchant modal is open.
	for touch in [true,false]:
		var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
		event.position=scene._map_close_rect().get_center() if scene.map_open else scene.map_rect.get_center()
		event.pressed=true
		if not touch: event.button_index=MOUSE_BUTTON_LEFT
		var before: bool = scene.map_open
		scene._gui_input(event)
		assert(scene.map_open!=before,"Map accepts native touch/mouse input")
		event.pressed=false
		scene._gui_input(event)
	# Exercise the real pause handler with a held draw, not just serialization.
	scene.state.start_run("rogue_sharpshooter","expedition",42)
	scene._begin_streamed_action(scene.state.begin_bow_draw(Vector2.RIGHT))
	scene.state.advance_streamed_action_tick()
	scene._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	assert(scene.state.is_player_ready() and not scene.streaming_action,"Pause finishes only the existing commitment")
	var resumed = preload("res://scripts/core/run_state.gd").new(false)
	assert(resumed.load_run(),"Pause writes resumable snapshot")
	assert(resumed.player_pos==scene.state.player_pos and resumed.player_hp==scene.state.player_hp and is_equal_approx(resumed.player_energy,scene.state.player_energy),"Pause does not restore resources")
	print("Expedition desktop / Fold viewport captures complete")
	quit()
