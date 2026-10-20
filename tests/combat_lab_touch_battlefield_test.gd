extends "res://tests/independent_recheck.gd"

var gui_trace: Array = []
var observations: Array = []

func contained(board, viewport, name: String) -> void:
	super.contained(board,viewport,name)
	if not board.detail_open and not board.selector_panel.visible:
		check(not board.previous_page.is_visible_in_tree() and not board.next_page.is_visible_in_tree(),"closed inspection hides all paging controls: "+name)

func send(viewport, board, event: InputEvent, label: String, preserve: bool = true) -> void:
	var before := Lab.digest(Lab.authoritative(board.state))
	viewport.push_input(event,true)
	await process_frame
	board._process(0.016)
	var after := Lab.digest(Lab.authoritative(board.state))
	gui_trace.append({"event":event.as_text(),"label":label,"preserve_expected":preserve,"before":before,"after":after,"time":board.state.simulation_time,"scroll":board.inspection_scroll.scroll_vertical,"focus":str(viewport.gui_get_focus_owner())})
	if preserve: check(before == after,"GUI event preserves world: "+label)

func tap(viewport, board, control, preserve: bool = true) -> void:
	var point: Vector2 = control.get_global_rect().get_center() if control is Control else control
	for down in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 7
		event.position = point
		event.pressed = down
		await send(viewport,board,event,"tap "+str(point),preserve)
	for _frame in range(3): await process_frame

func joy(viewport, board, button: int, preserve: bool = true) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		await send(viewport,board,event,"controller "+str(button),preserve)
	for _frame in range(3): await process_frame

func finger(viewport, board, index: int, point: Vector2, down: bool, cancel: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index
	event.position=point
	event.pressed=down
	event.canceled=cancel
	await send(viewport,board,event,"finger %d %s"%[index,str(down)])

func drag(viewport, board, index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index
	event.position=point
	event.relative=relative
	event.screen_relative=relative
	await send(viewport,board,event,"content swipe %d"%index)

func bottom(board) -> bool:
	var bar: VScrollBar = board.inspection_scroll.get_v_scroll_bar()
	return board.inspection_scroll.scroll_vertical >= bar.max_value-bar.page-1

func run() -> void:
	if capture and DisplayServer.get_name() == "headless": quit(2); return
	if capture: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/presentation-captures"))
	for dims in [Vector2i(720,480),Vector2i(390,844),Vector2i(1280,800),Vector2i(960,600),Vector2i(720,1280)]:
		for projection in ["top_down","isometric"]:
			var viewport := SubViewport.new()
			viewport.size=dims
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var board = Board.new()
			board.size=Vector2(dims)
			viewport.add_child(board)
			board.set_process(false)
			await process_frame
			board.view_mode=projection
			stopped(board,"F2")
			await settle(board)
			var baseline := geometry(board)
			if dims == Vector2i(720,480): check(board.board_rect.size.y >= 200,"landscape F2 world >= 200")
			if dims == Vector2i(390,844): check(board.board_rect.size.y >= 250,"portrait F2 world >= 250")
			await shot(board,viewport,"repaired-mixed-initial",projection)
			if dims.x > 720 or dims.y == 1280:
				stopped(board,"F1-P")
				junction(board,true)
				board.state.lab_recover("dodge",Vector2.RIGHT)
				await shot(board,viewport,"repaired-queue",projection)
				board.queue_free(); viewport.queue_free(); await process_frame
				continue
			# The exact fresh contact sequence, with ordinary Wait requests only.
			for step in range(4):
				if step > 0: check(board.state.request_wait(0.5,true),"ordinary Wait accepted")
				await shot(board,viewport,"repaired-natural-wait-%d"%step,projection)
				var markers: Array = board.enemy_marker_model()
				for i in range(markers.size()):
					check(markers[i]["key"] == str(int(markers[i]["id"])-500),"fixture key still attributable")
					for j in range(i): check(not Rect2(markers[i]["rect"]).grow(3).intersects(markers[j]["rect"]),"crowded keys separated")
					for enemy in board.state.enemies:
						var center: Vector2 = board._actor_visual_center(enemy["pos"],float(enemy["radius"]))
						var radius: float = board._actor_body_radius(float(enemy["radius"]))
						check(not Rect2(markers[i]["rect"]).grow(radius*2).has_point(center),"key clear of actor body and facing")
				observations.append({"viewport":dims,"projection":projection,"step":step,"time":board.state.simulation_time,"world":board.board_rect,"markers":markers,"world_digest":Lab.digest(Lab.authoritative(board.state))})
			board.state.enemies.remove_at(0)
			check(board._enemy_readout_tag(502)=="2" and board._enemy_readout_tag(503)=="3","removing an earlier actor preserves numeric keys")
			stopped(board,"F3-K")
			await settle(board)
			var arm: bool = board.state.lab_toggle_commit()
			check(arm,"ready Sword arms before inspection")
			var armed_digest := Lab.decision_digest(board.state)
			await tap(viewport,board,board.details_button)
			check(board.detail_open,"actual touch opens Details")
			check(board.state.lab_armed and armed_digest == Lab.decision_digest(board.state),"touch inspection preserves arm and full decision state")
			await tap(viewport,board,board.continue_button)
			check(board.state.lab_armed and armed_digest == Lab.decision_digest(board.state),"inspection surface blocks underlying action controls")
			var area: Rect2 = board.inspection_scroll.get_global_rect()
			var start := area.position+Vector2(90,70)
			await finger(viewport,board,1,start,true)
			for step in range(1,7): await drag(viewport,board,1,start-Vector2(0,step*8),Vector2(0,-8))
			await finger(viewport,board,1,start-Vector2(0,48),false)
			check(board.inspection_scroll.scroll_vertical >= 48,"six real drags scroll at least 48")
			for page in range(20):
				if bottom(board): break
				await tap(viewport,board,board.next_page)
			check(bottom(board),"tap-only Next reaches final details line")
			check(board.diagnostics.get_global_rect().end.y <= board.inspection_scroll.get_global_rect().end.y+1,"final traits line visible")
			await shot(board,viewport,"repaired-details-tap-bottom",projection)
			for page in range(20):
				if board.inspection_scroll.scroll_vertical == 0: break
				await tap(viewport,board,board.previous_page)
			check(board.inspection_scroll.scroll_vertical == 0,"tap-only Previous returns to top")
			# Captured finger leaves panel, another finger cancels/closes, then releases
			# in the battlefield. It must never become a move, target or attack.
			await finger(viewport,board,2,start,true)
			await drag(viewport,board,2,board.board_rect.get_center(),Vector2(0,100))
			await tap(viewport,board,board.details_button)
			await finger(viewport,board,2,board.board_rect.get_center(),false)
			check(not board.detail_open and board.state.lab_armed,"close captures outstanding release without disarming")
			await tap(viewport,board,board.details_button)
			await finger(viewport,board,3,start,true)
			var rotated := Vector2i(390,844) if dims.x==720 else Vector2i(720,480)
			viewport.size=rotated; board.size=Vector2(rotated)
			await settle(board)
			await drag(viewport,board,3,board.board_rect.get_center(),Vector2(0,-80))
			await finger(viewport,board,3,board.board_rect.get_center(),false,true)
			await tap(viewport,board,board.details_button)
			viewport.size=dims; board.size=Vector2(dims)
			await settle(board)
			# F3-K now has the same fixed geometry as F2: roster count never shifts it.
			restored(board,baseline,"touch close/rotate restore")
			# Tap-only Compare reaches and operates each whole 48-unit cycling field.
			await tap(viewport,board,board.utility_row.get_child(0))
			check(board.selector_panel.visible,"touch opens Compare")
			for control in board.selector_panel.get_children():
				for page in range(20):
					if board.inspection_scroll.get_global_rect().grow(1).encloses(control.get_global_rect()): break
					await tap(viewport,board,board.next_page)
				check(board.inspection_scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"tap paging exposes every Compare field")
				if control.has_meta("selection"):
					var selected: int = control.get_meta("selection")
					await tap(viewport,board,control)
					check(control.get_meta("selection") != selected,"touch advances Compare field")
				elif control is CheckButton:
					var selected: bool = control.button_pressed
					await tap(viewport,board,control)
					check(control.button_pressed != selected,"touch toggles Scouting")
				else:
					await shot(board,viewport,"repaired-touch-start-fresh-visible",projection)
					await tap(viewport,board,control,false)
			check(not board.selector_panel.visible and board.state.simulation_time==0,"touch explicitly applies Start fresh")
			await joy(viewport,board,JOY_BUTTON_START)
			check(board.selector_panel.visible and board.suspended,"controller Start opens Compare")
			check(viewport.gui_get_focus_owner()==board.previous_page,"controller receives GUI focus")
			await joy(viewport,board,JOY_BUTTON_DPAD_DOWN)
			check(viewport.gui_get_focus_owner()==board.next_page,"controller navigates to Next page")
			# Reach each selector, its context-specific next-value action, checkbox and Start fresh
			# using only actual JoypadButton events. No direct signals or scroll writes.
			for control in board.selector_panel.get_children():
				await joy(viewport,board,JOY_BUTTON_DPAD_DOWN)
				check(viewport.gui_get_focus_owner()==control,"controller focus reaches "+control.get_class())
				check(board.inspection_scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"focused Compare control is visible")
				if control.has_meta("selection"):
					var selected: int = control.get_meta("selection")
					await joy(viewport,board,JOY_BUTTON_A)
					check(control.get_meta("selection") != selected,"controller changes selector option")
				elif control is CheckButton:
					var selected: bool = control.button_pressed
					await joy(viewport,board,JOY_BUTTON_A)
					check(control.button_pressed != selected,"controller changes Scouting")
				else:
					await shot(board,viewport,"repaired-controller-start-fresh-visible",projection)
			# Continue through utility buttons to Details without applying reset yet.
			for _step in range(3): await joy(viewport,board,JOY_BUTTON_DPAD_DOWN)
			check(viewport.gui_get_focus_owner()==board.details_button,"controller reaches Review details")
			await joy(viewport,board,JOY_BUTTON_A)
			check(board.detail_open,"controller opens details")
			await joy(viewport,board,JOY_BUTTON_DPAD_DOWN)
			await joy(viewport,board,JOY_BUTTON_DPAD_DOWN)
			check(viewport.gui_get_focus_owner()==board.next_page,"controller focuses details Next page")
			for page in range(20):
				if bottom(board): break
				await joy(viewport,board,JOY_BUTTON_A)
			check(bottom(board) and board.diagnostics.get_global_rect().end.y <= board.inspection_scroll.get_global_rect().end.y+1,"controller reaches final details line")
			await shot(board,viewport,"repaired-controller-details-bottom",projection)
			var motion := InputEventJoypadMotion.new()
			motion.axis=JOY_AXIS_TRIGGER_RIGHT; motion.axis_value=1
			await send(viewport,board,motion,"inspection held trigger")
			await joy(viewport,board,JOY_BUTTON_B)
			check(not board.inspection_scroll.visible,"controller B closes inspection")
			check(board.inspection_release_required,"held inspection trigger retains release gate")
			motion.axis_value=0
			await send(viewport,board,motion,"inspection trigger released")
			check(not board.inspection_release_required,"released trigger clears adapter gate")
			# Explicit Start fresh is the sole navigation action allowed to reset world.
			await joy(viewport,board,JOY_BUTTON_START)
			for _step in range(board.selector_panel.get_child_count()+1): await joy(viewport,board,JOY_BUTTON_DPAD_DOWN)
			var fresh = board.selector_panel.get_child(board.selector_panel.get_child_count()-1)
			check(viewport.gui_get_focus_owner()==fresh,"controller returns to Start fresh")
			await joy(viewport,board,JOY_BUTTON_A,false)
			await settle(board)
			check(not board.selector_panel.visible and board.state.simulation_time==0,"controller explicitly applies Start fresh reset")
			# Active/queued presentation still has immediate obligation and event reads.
			board.variant="C"; board.lab_loadout="warrior"; board.lab_rules="energy"
			board.arrival="full"; board.scouting=false; board.view_mode=projection
			stopped(board,"F1-P")
			junction(board,true)
			board.state.lab_recover("dodge",Vector2.RIGHT)
			await shot(board,viewport,"repaired-queue",projection)
			check(board.instruction.text.contains("Debt") and board.instruction.text.contains("Exit"),"queue debt and captured exit immediately shown")
			board.queue_free(); viewport.queue_free(); await process_frame
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name() if capture else "headless","evidence":records,"observations":observations,"gui_trace":gui_trace}
	FileAccess.open("res://.runtime/touch-battlefield-%s.json"%["render" if capture else "headless"],FileAccess.WRITE).store_string(JSON.stringify(Lab.json_safe(report),"\t"))
	for failure in failures: print("FAILED: ",failure)
	print("TOUCH_BATTLEFIELD checks=",checks," failures=",failures.size()," capture=",capture)
	quit(0 if failures.is_empty() else 1)
