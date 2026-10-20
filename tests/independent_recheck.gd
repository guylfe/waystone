extends "res://tests/combat_lab_presentation_test.gd"

func mouse(viewport, point: Vector2, button: int, down: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = down
	viewport.push_input(event, true)
	await process_frame

func click_ui(viewport, control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	await mouse(viewport,point,MOUSE_BUTTON_LEFT,true)
	await mouse(viewport,point,MOUSE_BUTTON_LEFT,false)
	for _frame in range(3): await process_frame

func wheel(viewport, board, down: bool, count: int = 18) -> void:
	var point: Vector2 = board.inspection_scroll.get_global_rect().get_center()
	for _step in range(count):
		await mouse(viewport,point,MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP,true)
		await mouse(viewport,point,MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP,false)
	await settle(board)

func touch_drag(viewport, board) -> void:
	var area: Rect2 = board.inspection_scroll.get_global_rect()
	var start := area.position + Vector2(90,70)
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = start
	event.pressed = true
	viewport.push_input(event,true)
	await process_frame
	for step in range(1,7):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = start - Vector2(0,step*8)
		drag.relative = Vector2(0,-8)
		drag.screen_relative = Vector2(0,-8)
		viewport.push_input(drag,true)
		await process_frame
	event.position = start-Vector2(0,48)
	event.pressed = false
	viewport.push_input(event,true)
	for _frame in range(8): await process_frame

func run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		quit(2)
		return
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
			var baseline := geometry(board)
			var world := Lab.digest(Lab.authoritative(board.state))
			await click_ui(viewport,board.details_button)
			check(board.detail_open,"GUI pointer opens details")
			await wheel(viewport,board,true)
			check(board.inspection_scroll.scroll_vertical > 0,"GUI wheel scrolls details")
			await shot(board,viewport,"fresh-details-wheel-bottom",projection)
			await wheel(viewport,board,false)
			var touch_before: int = board.inspection_scroll.scroll_vertical
			await touch_drag(viewport,board)
			observations.append({"viewport":dims,"projection":projection,"touch_scroll_before":touch_before,"touch_scroll_after":board.inspection_scroll.scroll_vertical,"touch_emulates_mouse":Input.emulate_mouse_from_touch})
			await shot(board,viewport,"fresh-details-after-touch-drag",projection)
			var rotated := Vector2i(390,844) if dims.x == 720 else Vector2i(720,480)
			viewport.size = rotated
			board.size = Vector2(rotated)
			await shot(board,viewport,"fresh-rotated-open-from-%dx%d"%[dims.x,dims.y],projection)
			check(board.detail_open,"rotation keeps details accessible")
			await click_ui(viewport,board.details_button)
			check(not board.detail_open,"GUI closes details after rotation")
			viewport.size = dims
			board.size = Vector2(dims)
			await settle(board)
			restored(board,baseline,"fresh pointer close and rotation back")
			check(world == Lab.digest(Lab.authoritative(board.state)),"GUI inspection and scroll preserves authoritative world")
			await click_ui(viewport,board.utility_row.get_child(0))
			check(board.selector_panel.visible and board.suspended,"GUI Compare opens suspended")
			await wheel(viewport,board,true)
			await shot(board,viewport,"fresh-compare-wheel-bottom",projection)
			var fresh = board.selector_panel.get_child(board.selector_panel.get_child_count()-1)
			check(board.inspection_scroll.get_global_rect().encloses(fresh.get_global_rect()),"GUI wheel exposes Start fresh")
			await click_ui(viewport,fresh)
			check(not board.selector_panel.visible,"GUI Start fresh applies and closes Compare")
			await click_ui(viewport,board.utility_row.get_child(0))
			await click_ui(viewport,board.utility_row.get_child(0))
			await click_ui(viewport,board.utility_row.get_child(1))
			check(board.state.lab_neutral_required,"GUI Resume requires neutral")
			key(board,KEY_ENTER,true)
			board._process(0)
			check(board.state.lab_neutral_required,"fresh held key preserves gate")
			key(board,KEY_ENTER,false)
			board._process(0)
			await shot(board,viewport,"fresh-resumed-neutral",projection)
			check(board.status.text.begins_with("Ready") and board.state.lab_notice == "","GUI Resume then neutral retires obsolete notice")
			for notice in ["Interrupted · Sequence ended. Queued Dodge cleared.","Target outside normal attack range."]:
				board.state.lab_notice = notice
				board.state.lab_input_neutral()
				check(board.state.lab_notice == notice,"fresh neutral preserves event "+notice)
			board.queue_free()
			viewport.queue_free()
			await process_frame
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name() if capture else "headless","evidence":records,"observations":observations}
	FileAccess.open("res://.runtime/independent-recheck-results.json",FileAccess.WRITE).store_string(JSON.stringify(Lab.json_safe(report),"\t"))
	for failure in failures: print("FAILED: ",failure)
	print("INDEPENDENT_RECHECK checks=",checks," failures=",failures.size()," capture=",capture)
	quit(0 if failures.is_empty() else 1)
