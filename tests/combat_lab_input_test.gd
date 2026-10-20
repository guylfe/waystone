extends SceneTree
const Board = preload("res://scripts/experiments/combat_lab_board.gd")
const Lab = preload("res://scripts/experiments/combat_lab_catalog.gd")
var failures: Array = []
var evidence: Array = []
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func key(board, code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	board._input(event)
	board._unhandled_key_input(event)

func motion(board, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	board.controller.handle(board,event)

func button(board, id: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = id
	event.pressed = down
	board.controller.handle(board,event)

func drive(board, until_junction: bool = true) -> void:
	for _frame in range(80):
		board._process(0.05)
		if board.state.lab_junction() and until_junction: break
		if board.state.is_player_ready(): break

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for viewport_size in [Vector2i(1280,800),Vector2i(390,844)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var board = Board.new()
		board.size = Vector2(viewport_size)
		viewport.add_child(board)
		board.set_process(false)
		await process_frame
		board.fixture = "F1-P"
		board._restart()
		board.state.lab_input_neutral()
		board._process(0.01)
		var frozen := Lab.digest(Lab.authoritative(board.state))
		key(board,KEY_K,true)
		key(board,KEY_K,false)
		check(board.state.lab_armed,"keyboard K arms Commit")
		check(frozen == Lab.digest(Lab.authoritative(board.state)),"keyboard arm advances no world")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = board._world_to_screen(board.state.enemies[0]["pos"])
		board._input(event)
		check(board.state.lab_armed,"keyboard to mouse desktop targeting retains arm")
		board._gui_input(event)
		check(board.streaming_action and bool(board.state.player_action.get("lab_prepaid",false)),"mouse target launches actual Commit")
		event.pressed = false
		board._input(event)
		board._gui_input(event)
		drive(board,false)
		check(board.state.simulation_time >= 2.46,"release cannot shorten mouse Commit")
		board._restart()
		board.state.lab_input_neutral()
		board._begin_streamed_action(board.state.request_combo(Vector2.UP,false))
		drive(board)
		check(board.state.lab_junction() and not board.streaming_action and board.stream_accumulator == 0.0,"GameBoard captures/stops pending junction")
		frozen = Lab.digest(Lab.authoritative(board.state))
		for _pause in range(8): board._process(3.0)
		await create_timer(0.1).timeout
		check(frozen == Lab.digest(Lab.authoritative(board.state)),"GameBoard thinking time freezes complete world")
		key(board,KEY_ENTER,true)
		key(board,KEY_ENTER,false)
		drive(board)
		check(board.state.lab_junction() and int(board.state.player_action["committed_phase"]) == 1,"quick Enter/release advances exactly one cut")
		check(board.stream_accumulator == 0.0,"resuming does not catch up thinking time")
		key(board,KEY_D,true)
		check(board.state.player_action.get("lab_exit_request",{}).get("kind") == "move","keyboard junction move captures recovery debt")
		var original: Dictionary = board.state.player_action.get("lab_exit_request",{}).duplicate(true)
		key(board,KEY_SHIFT,true)
		check(board.state.player_action.get("lab_exit_request",{}) == original,"new input cannot overwrite recovery request")
		drive(board,false)
		key(board,KEY_D,false)
		key(board,KEY_SHIFT,false)
		board._process(0.01)
		board._restart()
		board.state.lab_input_neutral()
		board._begin_streamed_action(board.state.request_combo(Vector2.UP,false))
		drive(board)
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = Rect2(board.buttons["defense"]).get_center()
		board._input(touch)
		board._gui_input(touch)
		check(board.selected_action == "defense" and board.state.lab_junction(),"touch Defense selects queued Dodge without paying time")
		touch.pressed = false
		board._input(touch)
		board._gui_input(touch)
		touch.pressed = true
		touch.position = board._world_to_screen(board.state.player_pos+Vector2.DOWN*100)
		var old_position: Vector2 = board.state.player_pos
		board._input(touch)
		board._gui_input(touch)
		check(board.state.player_action.get("lab_exit_request",{}).get("kind") == "dodge" and board.state.player_pos == old_position,"touch direction queues Dodge without early movement")
		touch.pressed = false
		board._input(touch)
		board._gui_input(touch)
		drive(board,false)
		board._restart()
		board.state.lab_input_neutral()
		board.controller.active = true
		board.controller.neutral_required = false
		board.controller.held.clear()
		motion(board,JOY_AXIS_TRIGGER_LEFT,1.0)
		check(board.state.lab_armed,"controller LT arms")
		var tick: int = board.state._simulation_tick_index
		motion(board,JOY_AXIS_TRIGGER_RIGHT,1.0)
		check(board.state.lab_armed and board.state._simulation_tick_index == tick and board.state.is_player_ready(),"RT without explicit target refuses frozen")
		motion(board,JOY_AXIS_TRIGGER_RIGHT,0.0)
		button(board,JOY_BUTTON_RIGHT_STICK,true)
		button(board,JOY_BUTTON_RIGHT_STICK,false)
		check(board.controller.target_id == 101,"RS selects visible armed Sword target")
		motion(board,JOY_AXIS_TRIGGER_RIGHT,1.0)
		check(bool(board.state.player_action.get("lab_prepaid",false)),"RT selected target starts Commit")
		board.controller.disconnected(board,board.controller.device)
		check(board.state.is_player_ready() and board.state.lab_neutral_required,"disconnect finishes obligation and requires neutral")
		await process_frame
		check(board.status.size.x <= viewport_size.x+1,"status constrained to viewport width")
		evidence.append({"viewport":viewport_size,"board":board.board_rect,"controls":[board.commit_button.get_global_rect(),board.continue_button.get_global_rect(),board.recover_button.get_global_rect()],"layer":"headless direct dispatch to actual GameBoard/controller adapters; no rendered pixels or hardware"})
		viewport.queue_free()
		await process_frame
	var file := FileAccess.open("res://.runtime/lab-input-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(Lab.json_safe({"checks":checks,"failures":failures,"evidence":evidence}),"\t"))
	for failure in failures: print("FAILED: ",failure)
	print("LAB INPUT checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
