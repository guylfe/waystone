extends "res://tests/combat_lab_review_test.gd"

# Same public UI sequence runs against the preserved and repaired candidates.
# --capture requires an actual renderer; headless runs still check rectangles.
var records: Array = []

func settle(board) -> void:
	board._layout()
	for _frame in range(6): await process_frame
	board.visual = board._presentation_snapshot()
	board._refresh_action_panel()
	board.queue_redraw()

func geometry(board) -> Dictionary:
	return {"world":board.board_rect,"panel":board.lab_panel.get_global_rect(),"hud":board.hud_rect,"wait":board.interaction_rect,"abilities":board.buttons.duplicate(),"belt":board.consumable_rects.duplicate(),"attack":board.continue_button.get_global_rect()}

func close_rect(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < 1.1 and a.size.distance_to(b.size) < 1.1

func contained(board, viewport, name: String) -> void:
	var full := Rect2(Vector2.ZERO,Vector2(viewport.size))
	check(full.encloses(board.board_rect),name+": full world containment")
	check(board.board_rect.size.x >= 300 and board.board_rect.size.y >= 100,name+": usable world rectangle")
	var controls: Array = [board.interaction_rect]
	controls.append_array(board.buttons.values())
	controls.append_array(board.consumable_rects.values())
	for button in [board.continue_button,board.commit_button,board.recover_button,board.target_button]: controls.append(button.get_global_rect())
	for control in board.utility_row.get_children(): controls.append(control.get_global_rect())
	for rect: Rect2 in controls:
		check(full.grow(0.1).encloses(rect),name+": necessary control contained "+str(rect))
		check(rect.size.x >= 48 and rect.size.y >= 48,name+": 48-unit necessary control")
		check(not rect.intersects(board.board_rect),name+": control clear of world")
	var reads: Array = board.call("enemy_readout_model") if board.has_method("enemy_readout_model") else []
	check(board.has_method("enemy_readout_model"),name+": enemy phase/resistance has reserved attributed slots")
	for read in reads:
		check(full.encloses(read["rect"]) and not read["rect"].intersects(board.board_rect),name+": readout outside combat geometry")
		for line in read["lines"]:
			check(ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x <= read["rect"].size.x-16,name+": complete enemy read without truncation: "+line)
		check(read["id"] > 0 and read["phase"] != "" and read["resistance"] != "",name+": actor attribution and current facts")

func shot(board, viewport, name: String, projection: String) -> void:
	await settle(board)
	contained(board,viewport,name)
	var path := ""
	if capture:
		await RenderingServer.frame_post_draw
		path = "res://.runtime/presentation-captures/%dx%d-%s-%s.png" % [viewport.size.x,viewport.size.y,projection,name]
		check(viewport.get_texture().get_image().save_png(path) == OK,"saved "+path)
	records.append({"name":name,"projection":projection,"viewport":viewport.size,"geometry":geometry(board),"title":board.status.text,"notice":board.feedback.text,"image":path,"reads":board.call("enemy_readout_model") if board.has_method("enemy_readout_model") else []})

func restored(board, baseline: Dictionary, name: String) -> void:
	var current := geometry(board)
	for part in ["world","panel","hud","wait","attack"]: check(close_rect(current[part],baseline[part]),name+": restored "+part)
	for part in ["abilities","belt"]:
		for key in baseline[part]: check(close_rect(current[part][key],baseline[part][key]),name+": restored "+part+" "+key)

func run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		quit(2)
		return
	if capture: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/presentation-captures"))
	for dims in [Vector2i(1280,800),Vector2i(960,600),Vector2i(720,480),Vector2i(720,1280),Vector2i(390,844)]:
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
			await shot(board,viewport,"compact",projection)
			var baseline := geometry(board)
			var frozen := Lab.digest(Lab.authoritative(board.state))
			for cycle in range(2):
				board.details_button.pressed.emit()
				await shot(board,viewport,"details-open-%d"%cycle,projection)
				if board.get("inspection_scroll") != null:
					board.inspection_scroll.scroll_vertical = 100000
					await settle(board)
					check(board.inspection_scroll.scroll_vertical > 0,"long inspection actually scrolls")
					check(board.diagnostics.get_global_rect().end.y <= board.inspection_scroll.get_global_rect().end.y+1,"last inspection line reachable")
					await shot(board,viewport,"details-bottom-%d"%cycle,projection)
				board.details_button.pressed.emit()
				await shot(board,viewport,"details-closed-%d"%cycle,projection)
				restored(board,baseline,"details close")
				board.utility_row.get_child(0).pressed.emit()
				await shot(board,viewport,"compare-open-%d"%cycle,projection)
				if board.get("inspection_scroll") != null:
					for control in board.selector_panel.get_children():
						check(control.size.x >= 48 and control.size.y >= 48,"Compare control retains 48-unit target")
						board.inspection_scroll.ensure_control_visible(control)
						await settle(board)
						check(board.inspection_scroll.get_global_rect().grow(1).encloses(control.get_global_rect()),"each Compare option and Start fresh reachable by scrolling")
				board.utility_row.get_child(0).pressed.emit()
				board.utility_row.get_child(1).pressed.emit()
				check(board.state.lab_neutral_required,"Resume requires fresh neutral")
				key(board,KEY_ENTER,true)
				board._process(0)
				check(board.state.lab_neutral_required,"held confirmation cannot clear Resume gate")
				key(board,KEY_ENTER,false)
				board._process(0)
				await shot(board,viewport,"compare-resumed-%d"%cycle,projection)
				check(board.status.text.begins_with("Ready") and not board.feedback.text.contains("Suspended"),"Ready after neutral has no stale suspension notice")
				restored(board,baseline,"compare resume")
			check(frozen == Lab.digest(Lab.authoritative(board.state)),"inspection/suspension does not alter idle authoritative world")
			for notice in ["Interrupted · Sequence ended. Queued Dodge cleared.","Target outside normal attack range."]:
				board.state.lab_notice = notice
				board.state.lab_input_neutral()
				board._process(0)
				check(board.state.lab_notice == notice,"neutral preserves relevant interruption/refusal feedback")
			for rotated in [Vector2i(390,844),Vector2i(720,480),dims]:
				viewport.size = rotated
				board.size = Vector2(rotated)
				await settle(board)
				contained(board,viewport,"resize "+str(rotated))
				if rotated.y > rotated.x: check(board.buttons["defense"].position.y > board.board_rect.end.y,"portrait stays bottom-row after resize")
			await settle(board)
			restored(board,baseline,"rotate back")
			for state_name in ["normal-held","junction-2","recover-dodge","mixed-camp","kiln-recovery","briarhook-tell"]:
				stopped(board,"F2" if state_name == "mixed-camp" else "F3-KP" if state_name == "kiln-recovery" else "F1" if state_name == "briarhook-tell" else "F1-P")
				if state_name == "normal-held": board.continue_button.button_down.emit()
				elif state_name in ["junction-2","recover-dodge"]:
					junction(board,true)
					if state_name == "recover-dodge": board.state.lab_recover("dodge",Vector2.RIGHT)
				await shot(board,viewport,state_name,projection)
			board.queue_free()
			viewport.queue_free()
			await process_frame
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name() if capture else "headless","evidence":records}
	FileAccess.open("res://.runtime/presentation-%s-results.json" % ("render" if capture else "headless"),FileAccess.WRITE).store_string(JSON.stringify(Lab.json_safe(report),"\t"))
	for failure in failures: print("FAILED: ",failure)
	print("PRESENTATION checks=",checks," failures=",failures.size()," capture=",capture)
	quit(0 if failures.is_empty() else 1)
