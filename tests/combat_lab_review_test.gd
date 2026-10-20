extends SceneTree
const Board = preload("res://scripts/experiments/combat_lab_board.gd")
const Lab = preload("res://scripts/experiments/combat_lab_catalog.gd")
var failures: Array = []
var evidence: Array = []
var checks := 0
var capture := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _init() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	call_deferred("run")

func stopped(board, fixture: String = "F1-P") -> void:
	board.fixture = fixture
	board._restart()
	board.set_process(false)
	board.state.lab_input_neutral()
	board.controller.active = false
	board._refresh_action_panel()

func junction(board, second: bool = false) -> void:
	board.state.request_combo(Vector2.UP,false)
	for _tick in range(500):
		board.state._tick(board.state.SIM_DT)
		if board.state.lab_junction(): break
	if second:
		board.state.lab_continue()
		for _tick in range(500):
			board.state._tick(board.state.SIM_DT)
			if board.state.lab_junction(): break

func sample(board, viewport, name: String, projection: String) -> void:
	board.visual = board._presentation_snapshot()
	board._refresh_action_panel()
	board.queue_redraw()
	await process_frame
	await process_frame
	check(not board.board_rect.intersects(board.interaction_rect),"world viewport excludes Wait controls")
	var defense: Rect2 = board.buttons["defense"]
	check(defense.size.x >= 48 and defense.size.y >= 48,"48-unit defense target")
	var rects: Array = []
	for control in [board.continue_button,board.recover_button,board.commit_button,board.target_button]:
		var rect: Rect2 = control.get_global_rect()
		check(rect.size.x >= 48 and rect.size.y >= 48,"48-unit target: " + name)
		check(Rect2(Vector2.ZERO,Vector2(viewport.size)).encloses(rect),"control inside viewport: " + name)
		check(not rect.intersects(board.board_rect),"controls outside world telegraphs: " + name)
		for other in rects: check(not rect.intersects(other),"distinct primary hit regions: " + name)
		rects.append(rect)
	var image_path := ""
	if capture:
		await RenderingServer.frame_post_draw
		for first in range(board.lab_badge_rects.size()):
			for second in range(first+1,board.lab_badge_rects.size()): check(not board.lab_badge_rects[first].intersects(board.lab_badge_rects[second]),"rendered resistance badges have distinct regions")
		image_path = "res://.runtime/review-captures/%dx%d-%s-%s.png" % [viewport.size.x,viewport.size.y,projection,name]
		check(viewport.get_texture().get_image().save_png(image_path) == OK,"capture written " + name)
	evidence.append({"name":name,"projection":projection,"viewport":viewport.size,"panel":board.action_panel_state(),"controls":rects,"board":board.board_rect,"image":image_path,"notice":board.state.lab_notice})

func run() -> void:
	if capture and DisplayServer.get_name() == "headless":
		print("FAILED: actual renderer required for captures")
		quit(1)
		return
	if capture:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/review-captures"))
	for viewport_size in [Vector2i(1280,800),Vector2i(960,600),Vector2i(720,480),Vector2i(720,1280),Vector2i(390,844)]:
		for projection in ["top_down","isometric"]:
			var viewport := SubViewport.new()
			viewport.size = viewport_size
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var board = Board.new()
			board.size = Vector2(viewport_size)
			viewport.add_child(board)
			board.set_process(false)
			await process_frame
			board.view_mode = projection
			stopped(board)
			await sample(board,viewport,"ready",projection)
			var stable: Rect2 = board.continue_button.get_global_rect()
			var world := Lab.digest(Lab.authoritative(board.state))
			check(board.state.lab_toggle_commit(),"arm accepted")
			board.controller.cycle_target(board)
			check(board.controller.target_id == 101,"explicit keyboard/controller target selection")
			check(world == Lab.digest(Lab.authoritative(board.state)),"arming/selecting does not rotate or advance world")
			await sample(board,viewport,"armed",projection)
			check(stable == board.continue_button.get_global_rect(),"fixed control slot while arming")
			board.state.enemies[0]["pos"] = board.state.player_pos + Vector2.UP * 500
			board.controller.target_id = -1
			board.controller.cycle_target(board)
			check(board.controller.target_id == -1,"selection excludes out-of-range enemy")
			world = Lab.digest(Lab.authoritative(board.state))
			check(not board.state.lab_target(101) and board.state.lab_armed,"out-of-range request preserves arm")
			check(world == Lab.digest(Lab.authoritative(board.state)),"rejected confirmation preserves world")
			check(board.state.lab_notice.contains("range"),"range refusal is explicit")
			stopped(board)
			board.state.lab_toggle_commit()
			board.state.player_energy = 1
			check(not board.state.lab_target(101) and board.state.lab_notice.contains("Have 1.00"),"resource refusal includes actual amount")
			stopped(board)
			board.continue_button.button_down.emit()
			check(board.streaming_action and bool(board.state.player_action.get("continue_held",false)),"primary button down starts actual held attack")
			for index in [1,2]: check(board._lab_combo_pip_state(board.state.player_action,index) == "optional","held future cuts optional")
			await sample(board,viewport,"normal-held",projection)
			board.continue_button.button_up.emit()
			check(not bool(board.state.player_action.get("continue_held",true)),"primary release clears only automatic intent")
			stopped(board)
			board.state.lab_toggle_commit()
			check(board.state.lab_target(101),"selected legal target launches")
			check(board._lab_combo_pip_state(board.state.player_action,0) == "current","startup current cut is one before first tick")
			check(board.action_panel_state()["title"] == "Commit · Cut 1/3","no zero-index cut shown at launch")
			check(board._lab_combo_pip_state(board.state.player_action,2) == "committed","prepaid future cut locked")
			check(board.state.player_commitment_world_remaining() > board.state.player_control_world_remaining(),"whole commitment distinct from current-cut debt")
			await sample(board,viewport,"commit",projection)
			board.state._resolve_incoming_hit(-1,30,"blade",board.state.player_pos+Vector2.RIGHT*60,board.state.player_pos+Vector2.RIGHT*30)
			await sample(board,viewport,"interrupted",projection)
			check(board.state.lab_notice.begins_with("Interrupted"),"interruption persists as event feedback")
			stopped(board)
			board.state.lab_neutral_required = true
			await sample(board,viewport,"neutral-required",projection)
			check(board.action_panel_state()["title"].begins_with("Release"),"neutral gate differs from Ready")
			for second in [false,true]:
				stopped(board)
				junction(board,second)
				check(board.state.lab_junction(),"real executor reaches junction")
				await sample(board,viewport,"junction-2" if second else "junction-1",projection)
				check(stable == board.continue_button.get_global_rect(),"fixed control slot across choice states")
				world = Lab.digest(Lab.authoritative(board.state))
				for _thinking in range(31): board._process(1.0)
				check(world == Lab.digest(Lab.authoritative(board.state)),"31 simulated seconds cannot advance frozen world")
				var action_kind := "dodge" if second else "move"
				board.state.lab_recover(action_kind,Vector2.RIGHT)
				var queue: Dictionary = board.state.player_action["lab_exit_request"].duplicate(true)
				var pos: Vector2 = board.state.player_pos
				board._unhandled_key_input(_key(KEY_A))
				check(queue == board.state.player_action["lab_exit_request"] and board.state.player_pos == pos,"queued exit locked, no early movement")
				await sample(board,viewport,"recover-"+action_kind,projection)
				check(board.action_panel_state()["title"] == "Recovering → " + action_kind.capitalize(),"recovery identifies captured request")
				board.state._resolve_incoming_hit(-1,30,"blade",board.state.player_pos+Vector2.RIGHT*60,board.state.player_pos+Vector2.RIGHT*30)
				check(board.action_panel_state()["queued"].is_empty() and board.state.lab_notice.contains("cleared"),"interruption clears queue promise")
			stopped(board,"F3-K")
			check(board._resistance_text(board.state.enemies[0]).contains("Armored attack"),"actual Kiln protection read")
			await sample(board,viewport,"kiln-protected",projection)
			stopped(board,"F3-KP")
			check(board._resistance_text(board.state.enemies[0]).contains("Flinch allowed"),"protection expires into recovery read")
			await sample(board,viewport,"kiln-recovery",projection)
			stopped(board,"F2")
			await sample(board,viewport,"mixed-camp",projection)
			stopped(board,"F1")
			check(board._resistance_text(board.state.enemies[0]).contains("Flinch allowed"),"Briarhook ordinary attack has no legacy active melee exception")
			await sample(board,viewport,"briarhook-tell",projection)
			# Resize cannot consume a stale gesture or alter simulation state.
			var frozen_resize := Lab.digest(Lab.authoritative(board.state))
			board.pointer_down = true
			board.lab_pointer = true
			board.selected_action = "defense"
			board.size += Vector2(0,20)
			board._layout()
			check(not board.pointer_down and not board.lab_pointer and board.selected_action == "","resize cancels stale gesture")
			check(frozen_resize == Lab.digest(Lab.authoritative(board.state)),"resize cannot queue or advance world")
			board.size = Vector2(viewport_size)
			stopped(board)
			for code in [KEY_K,KEY_T]:
				key(board,code,true)
				key(board,code,false)
			check(board.state.lab_armed and board.controller.target_id == 101,"K/T choose target without confirmation")
			key(board,KEY_ENTER,true)
			check(bool(board.state.player_action.get("lab_prepaid",false)),"fresh keyboard Enter confirms explicit target")
			for _frame in range(100):
				board._process(0.05)
				if board.state.is_player_ready(): break
			check(board.state.is_player_ready() and board.state.lab_neutral_required,"held Enter reaches neutral-required after Commit")
			var completed: float = board.state.simulation_time
			for _frame in range(5): board._process(1.0)
			check(board.state.simulation_time == completed,"held confirmation cannot add an unchosen sequence")
			key(board,KEY_ENTER,false)
			board._process(0.01)
			check(not board.state.lab_neutral_required,"actual keyboard release clears neutral gate")
			board.queue_free()
			viewport.queue_free()
			await process_frame
	var file := FileAccess.open("res://.runtime/review-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(Lab.json_safe({"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name() if capture else "headless; synthetic only","evidence":evidence}),"\t"))
	for failure in failures: print("FAILED: ",failure)
	print("LAB REVIEW checks=",checks," failures=",failures.size()," capture=",capture)
	quit(0 if failures.is_empty() else 1)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func key(board, code: Key, down: bool) -> void:
	var event := _key(code)
	event.pressed = down
	board._input(event)
	board._unhandled_key_input(event)
