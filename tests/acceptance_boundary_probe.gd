extends "res://tests/combat_lab_touch_battlefield_test.gd"

var panel_observations: Array = []

func raw_key(viewport, board, code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		await send(viewport,board,event,"independent key %d"%code,false)

func panel_shot(board, viewport, name: String, projection: String) -> void:
	await shot(board,viewport,name,projection)
	var rows: Array = []
	for label in [board.instruction,board.feedback]+board.enemy_lines:
		rows.append({"text":label.text,"rect":label.get_global_rect(),"lines":label.get_line_count()})
	panel_observations.append({"name":name,"viewport":viewport.size,"projection":projection,"rows":rows,"actions":board.action_grid.get_global_rect(),"world":board.board_rect,"panel":board.action_panel_state()})
	for label in board.enemy_lines:
		check(label.get_global_rect().end.y <= board.action_grid.get_global_rect().position.y,"enemy facts clear of actions: "+name)

func run() -> void:
	if capture: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/presentation-captures"))
	for dims in [Vector2i(720,480),Vector2i(390,844)]:
		for projection in ["top_down","isometric"]:
			var viewport := SubViewport.new()
			viewport.size=dims
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var board=Board.new()
			board.size=Vector2(dims)
			viewport.add_child(board)
			board.set_process(false)
			await process_frame
			board.view_mode=projection
			stopped(board,"F2")
			await settle(board)
			await raw_key(viewport,board,KEY_K)
			check(board.state.lab_armed,"raw K arms in three-enemy fixture")
			await raw_key(viewport,board,KEY_ENTER)
			check(board.state.lab_armed and board.state.lab_notice.begins_with("Commit refused"),"raw no-target confirm retains arm and refusal")
			await panel_shot(board,viewport,"independent-three-enemy-refusal",projection)
			stopped(board,"F2")
			check(board.state.request_combo(Vector2.UP,false),"mixed normal starts")
			await panel_shot(board,viewport,"independent-three-enemy-normal",projection)
			check(board._lab_combo_pip_state(board.state.player_action,1)=="optional","mixed normal future cut stays optional")
			for _tick in range(500):
				board.state._tick(board.state.SIM_DT)
				if board.state.lab_junction(): break
			check(board.state.lab_junction(),"mixed fixture reaches natural junction")
			check(board.state.lab_recover("dodge",Vector2.RIGHT),"mixed fixture captures Dodge")
			await panel_shot(board,viewport,"independent-three-enemy-queue",projection)
			check(board.instruction.text.contains("Debt") and board.instruction.text.contains("Exit"),"three-enemy debt and captured exit present")
			# Compare during a running ordinary cut must match its existing legal drain.
			stopped(board,"F1-P")
			var control=Lab.create("C","F1-P","warrior","full","energy",false)
			board.state.request_combo(Vector2.UP,false)
			control.request_combo(Vector2.UP,false)
			control.lab_suspend()
			await joy(viewport,board,JOY_BUTTON_START,false)
			check(Lab.digest(Lab.authoritative(control))==Lab.digest(Lab.authoritative(board.state)),"raw Start matches legal suspension drain")
			var drained=Lab.digest(Lab.authoritative(board.state))
			await joy(viewport,board,JOY_BUTTON_B)
			check(board.suspended and not board.inspection_scroll.visible,"B closes without implicit Resume")
			await tap(viewport,board,board.utility_row.get_child(1))
			board._process(0)
			check(not board.suspended and not board.state.lab_neutral_required,"neutral Resume restores gameplay context")
			check(drained==Lab.digest(Lab.authoritative(board.state)),"close and Resume do not add a gameplay action")
			# Native mappings return after inspection. Synthetic engine events only.
			var axis:=InputEventJoypadMotion.new()
			axis.axis=JOY_AXIS_TRIGGER_LEFT
			# The prior setup used keyboard. A neutral controller event performs the
			# existing device-handover gate before the fresh gameplay press.
			axis.axis_value=0
			await send(viewport,board,axis,"neutral controller handover",false)
			axis.axis_value=1
			await send(viewport,board,axis,"fresh LT after Resume",false)
			axis.axis_value=0
			await send(viewport,board,axis,"release LT",false)
			check(board.state.lab_armed,"ordinary LT arms after inspection")
			await joy(viewport,board,JOY_BUTTON_RIGHT_STICK)
			check(board.controller.target_id==101,"ordinary RS selects after inspection")
			axis.axis=JOY_AXIS_TRIGGER_RIGHT
			axis.axis_value=1
			await send(viewport,board,axis,"fresh RT after Resume",false)
			check(bool(board.state.player_action.get("lab_prepaid",false)),"ordinary RT launches paid Commit after inspection")
			check(board._lab_combo_pip_state(board.state.player_action,1)=="committed","paid future pip stays committed")
			axis.axis_value=0
			await send(viewport,board,axis,"release RT",false)
			await panel_shot(board,viewport,"independent-commit-after-resume",projection)
			board.queue_free();viewport.queue_free();await process_frame
	var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"evidence":records,"panel_observations":panel_observations,"gui_trace":gui_trace}
	FileAccess.open("res://.runtime/acceptance-boundary-results.json",FileAccess.WRITE).store_string(JSON.stringify(Lab.json_safe(report),"\t"))
	for failure in failures:print("FAILED: ",failure)
	print("ACCEPTANCE_BOUNDARY checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
