extends SceneTree

const Queue = preload("res://scripts/core/run_comment_queue.gd")
const Session = preload("res://scripts/core/mode_session.gd")
const Survey = preload("res://scripts/core/survey_experiment.gd")

var board
var viewport: SubViewport
var queue: Queue
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAILED: ", label)

func frames(count: int = 3) -> void:
	for i in count: await process_frame

func key(code: Key, unicode: int = 0, ctrl: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode
		event.ctrl_pressed = ctrl
		event.pressed = down
		viewport.push_input(event, true)

func joy(button: int) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		viewport.push_input(event, true)

func touch(point: Vector2, down: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	viewport.push_input(event, true)

func tap(point: Vector2) -> void:
	touch(point, true)
	touch(point, false)

func start(mode: String, portrait: bool, variant: String = "A") -> void:
	if is_instance_valid(viewport):
		viewport.queue_free()
		await frames()
	var regional := mode == Session.REGIONAL
	viewport = SubViewport.new()
	viewport.size = Vector2i(390, 844) if portrait else Vector2i(1280, 800)
	root.add_child(viewport)
	board = load(Session.CAMPAIGN_SCENE if regional else Session.MAIN_SCENE).instantiate()
	board.desktop_controls = not portrait
	viewport.add_child(board)
	board.set_process(false)
	if not regional:
		var experiment := Survey.defaults() if mode == "combat_survey" else {}
		if not experiment.is_empty():
			experiment.behavior = variant
			experiment.scenario = "F1-P" if variant == "C" else "generated"
		board.state.start_run("warrior", mode, 42, "encounter", "energy", false, experiment)
		board._load_survey_identity()
	board._layout()
	board._process(0.0)
	board.run_comment_editor.queue = queue
	await frames()
	check(board.state.run_active, "active " + mode)

func menu_row(label: String) -> Vector2:
	var entries: Array = board.controller.menu_entries(board)
	for i in entries.size():
		if entries[i].label == label:
			return board.controller._pause_row(board.controller._pause_box(board, entries.size()), i).get_center()
	check(false, "run menu entry " + label)
	return Vector2.ZERO

func touch_menu(mode: String) -> void:
	await start(mode, true)
	tap(board.reset_rect.get_center())
	check(board.controller.paused, mode + " touch opens pause")
	tap(menu_row("Comment"))
	var modal = board.run_comment_editor
	check(modal.is_open(), mode + " touch opens comment")
	if not modal.is_open(): return
	await frames()
	check(board._display_safe_layout_rect().encloses(modal.panel.get_global_rect()), mode + " portrait containment " + str([board._display_safe_layout_rect(), modal.panel.get_global_rect(), modal.save_button.get_global_rect()]))
	check(modal.context.mode == mode and int(modal.context.area_id) == board.state.current_area_id, mode + " entry/area context")
	check(modal.context.has("room") == board.state.is_measurement_mode(), mode + " measurement context boundary")
	if mode == Session.REGIONAL:
		check(String(modal.context.area) == board.state.current_area_name() and modal.context.layer == board.state.current_layer, "regional place and layer")
	var id: String = modal.draft_id
	tap(modal.editor.get_global_rect().get_center())
	key(KEY_F, 102)
	await frames()
	check(modal.editor.text == "f", mode + " touch focus routes keyboard text")
	touch(board.reset_rect.get_center(), true, 2)
	tap(modal.save_button.get_global_rect().get_center())
	touch(board.reset_rect.get_center(), false, 2)
	check(not modal.is_open() and board.controller.paused, mode + " save returns to same run menu")
	var reopened := Queue.new(queue.directory)
	var record: Variant = JSON.parse_string(reopened.payload(id))
	check(record is Dictionary and record.text == "f" and record.context.mode == mode, mode + " persisted text and context")
	check(reopened.pending_ids().has(id), mode + " conserves pending upload")

func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/"):
		printerr("Requires isolated .runtime data.")
		quit(2)
		return
	queue = Queue.new("user://tests/run-comment-ui-" + Queue.new_id())
	for mode in ["expedition", "boss_lab", "combat_survey", Session.REGIONAL]:
		await touch_menu(mode)

	await start("campaign_lab", false)
	joy(JOY_BUTTON_START)
	joy(JOY_BUTTON_DPAD_DOWN)
	joy(JOY_BUTTON_A)
	var modal = board.run_comment_editor
	check(modal.is_open(), "controller opens Comment in Campaign Lab")
	if modal.is_open():
		key(KEY_R, 114)
		await frames()
		joy(JOY_BUTTON_DPAD_DOWN)
		joy(JOY_BUTTON_DPAD_DOWN)
		check(viewport.gui_get_focus_owner() == modal.save_button, "controller focuses save after keyboard entry")
		var gamepad_id: String = modal.draft_id
		joy(JOY_BUTTON_A)
		check(not modal.is_open() and not queue.payload(gamepad_id).is_empty(), "controller saves keyboard text")
		check(board.controller.paused, "controller stays in Run menu")
		joy(JOY_BUTTON_B)
		check(not board.controller.paused, "next controller Back resumes")

	await start("combat_survey", true, "C")
	for child in board.utility_row.get_children():
		if child is Button and child.text.begins_with("Survey menu"): tap(child.get_global_rect().get_center())
	await frames()
	check(board.suspended and board.selector_panel.is_visible_in_tree(), "experimental Survey opens its touch menu")
	for child in board.selector_panel.get_children():
		if child is Button and child.text == "Comment":
			board.inspection_scroll.ensure_control_visible(child)
			await frames()
			tap(child.get_global_rect().get_center())
	modal = board.run_comment_editor
	check(modal.is_open(), "experimental Survey touch Comment")
	if modal.is_open():
		check(modal.context.room.behavior == "C" and modal.context.room.scenario == "F1-P", "Survey behavior and exact fixture captured")
		var survey_id: String = modal.draft_id
		await frames()
		tap(modal.cancel_button.get_global_rect().get_center())
		check(not modal.is_open() and board.suspended and board.selector_panel.visible, "Survey returns to its own paused menu")
		check(queue.payload(survey_id).is_empty(), "Survey cancel leaves no payload")


	await start("combat_survey", false, "C")
	joy(JOY_BUTTON_START)
	await frames()
	check(board.suspended and board.selector_panel.visible, "controller opens experimental Survey menu")
	# Projection, Character, then Comment in the Survey's distinct navigation.
	joy(JOY_BUTTON_DPAD_DOWN)
	joy(JOY_BUTTON_DPAD_DOWN)
	joy(JOY_BUTTON_A)
	modal = board.run_comment_editor
	check(modal.is_open(), "controller opens Comment through Survey menu")
	if modal.is_open():
		joy(JOY_BUTTON_B)
		check(not modal.is_open() and board.suspended and board.selector_panel.visible, "controller cancel restores Survey menu")

	await start("expedition", false)
	for i in 15: board.state._set_message("Game event " + str(i))
	key(KEY_W)
	board._process(0.06)
	check(board.playing and board.state.simulation_time > 0.0, "committed stride in progress")
	var tick: int = board.state._simulation_tick_index
	var pos: Vector2 = board.state.player_pos
	key(KEY_F8)
	modal = board.run_comment_editor
	check(modal.is_open() and not board.controller.paused, "F8 opens over active action")
	if modal.is_open():
		key(KEY_F, 102)
		key(KEY_M, 109)
		key(KEY_R, 114)
		key(KEY_ENTER, 10)
		key(KEY_W, 119)
		await frames()
		for frame in 20: board._process(0.05)
		check(modal.editor.text == "fmr\nw", "gameplay keys type multiline text")
		check(board.state._simulation_tick_index == tick and board.state.player_pos == pos and not board.map_open, "world and action freeze while editing")
		var bad_path := queue.directory.path_join("not-a-directory")
		DirAccess.make_dir_recursive_absolute(queue.directory)
		var blocker := FileAccess.open(bad_path, FileAccess.WRITE)
		if blocker != null: blocker.close()
		modal.queue = Queue.new(bad_path)
		var id: String = modal.draft_id
		key(KEY_ENTER, 13, true)
		check(modal.is_open() and modal.editor.text == "fmr\nw" and modal.draft_id == id and modal.status.text.begins_with("Could not"), "write failure retains draft, ID and view")
		modal.queue = queue
		key(KEY_ENTER, 13, true)
		check(not modal.is_open() and not board.controller.paused and board.state._simulation_tick_index == tick, "Ctrl+Enter saves and restores active action")
		var record: Variant = JSON.parse_string(queue.payload(id))
		check(record is Dictionary and int(record.context.tick) == tick and record.text == "fmr\nw", "saved tick and multiline note match opening")
		if record is Dictionary:
			check(record.context.recent_messages.size() == 8 and record.context.enemies.size() <= 8, "bounded messages and visible actors")
		for frame in 15: board._process(0.05)
		check(board.state._simulation_tick_index > tick and not board.playing and board.desktop_movement_keys.is_empty(), "committed stride finishes without repeating held movement")
		key(KEY_F8)
		var canceled: String = modal.draft_id
		key(KEY_ESCAPE)
		check(not modal.is_open() and queue.payload(canceled).is_empty(), "Escape cancels without saving")
	print("Run comment UI: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
