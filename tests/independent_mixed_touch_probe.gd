extends "res://tests/independent_recheck.gd"

func run() -> void:
	if capture: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/presentation-captures"))
	var observations: Array = []
	for dims in [Vector2i(720,480),Vector2i(390,844)]:
		for projection in ["top_down","isometric"]:
			var viewport := SubViewport.new()
			viewport.size = dims
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var board = Board.new()
			board.size = Vector2(dims)
			viewport.add_child(board)
			board.set_process(false)
			await process_frame
			board.view_mode = projection
			stopped(board,"F3-K")
			board.inspected_enemy_id = int(board.state.enemies[0]["id"])
			await settle(board)
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = board.details_button.get_global_rect().get_center()
			touch.pressed = true
			viewport.push_input(touch,true)
			await process_frame
			touch.pressed = false
			viewport.push_input(touch,true)
			await settle(board)
			var touched_open: bool = board.detail_open
			if not board.detail_open: await click_ui(viewport,board.details_button)
			await touch_drag(viewport,board)
			check(touched_open,"synthetic screen tap opens Review details")
			check(board.inspection_scroll.scroll_vertical > 0,"synthetic screen drag scrolls useful inspection content")
			observations.append({"viewport":dims,"projection":projection,"screen_touch_opened_details":touched_open,"screen_drag_scroll":board.inspection_scroll.scroll_vertical,"scrollbar_rect":board.inspection_scroll.get_v_scroll_bar().get_global_rect(),"emulate_mouse_from_touch":Input.emulate_mouse_from_touch})
			if board.detail_open: await click_ui(viewport,board.details_button)
			stopped(board,"F2")
			for step in range(4):
				if step > 0: check(board.state.request_wait(0.5,true),"natural Wait accepted")
				await shot(board,viewport,"fresh-mixed-wait-%d"%step,projection)
				var actors: Array = []
				for enemy in board.state.enemies:
					actors.append({"id":enemy["id"],"key":board._enemy_readout_tag(int(enemy["id"])),"kind":enemy["kind"],"foot":board._world_to_screen(enemy["pos"]),"body_center":board._actor_visual_center(enemy["pos"],float(enemy["radius"])),"body_radius":board._actor_body_radius(float(enemy["radius"])),"action":enemy["action"].duplicate(true)})
				observations.append({"viewport":dims,"projection":projection,"wait_step":step,"simulation_time":board.state.simulation_time,"world_scale":board.world_scale,"world_rect":board.board_rect,"actors":actors})
			board.queue_free()
			viewport.queue_free()
			await process_frame
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name() if capture else "headless","evidence":records,"observations":observations}
	FileAccess.open("res://.runtime/independent-mixed-touch-results.json",FileAccess.WRITE).store_string(JSON.stringify(Lab.json_safe(report),"\t"))
	for failure in failures: print("FAILED: ",failure)
	print("MIXED_TOUCH_PROBE checks=",checks," failures=",failures.size()," capture=",capture)
	quit(0 if failures.is_empty() else 1)
