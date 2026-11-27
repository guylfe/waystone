extends SceneTree
## Launched by run_comment_delivery_test.py with disposable app data.

const Delivery = preload("res://scripts/core/run_comment_delivery.gd")
const Outbox = preload("res://scripts/core/run_comment_outbox.gd")
var failures := 0
var checks := 0
var view: SubViewport

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAILED: ", description)

func _key(code: Key, unicode: int = 0, ctrl: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode
		event.ctrl_pressed = ctrl
		event.pressed = down
		view.push_input(event, true)

func _click(button: Button) -> void:
	_click_at(button.get_global_rect().get_center())

func _click_at(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		view.push_input(event, true)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/comment-delivery-") or args.size() != 3 or args[0] != "--loopback":
		printerr("Requires the isolated delivery runner.")
		quit(2)
		return
	var phase := args[1]
	var outbox := root.get_node("RunCommentOutbox") as Outbox
	var origin := args[2]
	_check(outbox.endpoint == Delivery.DEFAULT_ENDPOINT, "production intake selected without setup")
	outbox.endpoint = origin + Delivery.ROUTE
	var main := String(ProjectSettings.get_setting("application/run/main_scene"))
	# Headless DisplayServer has no desktop window. Use a gameplay-sized viewport
	# while keeping the actual main scene, startup layout and input handlers.
	view = SubViewport.new()
	view.size = Vector2i(390, 844) if phase == "recover" else Vector2i(1280, 800)
	root.add_child(view)
	var board = load(main).instantiate()
	view.add_child(board)
	await process_frame
	await process_frame
	if not board.state.run_active:
		var mode_rect: Rect2 = board.progression_rects["expedition"]
		_click_at(mode_rect.get_center())
		await process_frame
		_click_at(board.start_rect.get_center())
		await process_frame
	_check(board.state.run_active and board.state.mode_id == "expedition", "production main scene starts Expedition via setup input")
	_key(KEY_F8)
	var modal = board.run_comment_editor
	_check(modal.is_open(), "production board routes F8 to run comment")
	if not modal.is_open():
		quit(2)
		return
	await process_frame
	if phase == "capture":
		_check(outbox.pending.is_empty() and outbox.local_count == 2, "local-only records remain local")
		var opening_tick: int = modal.context.tick
		_key(KEY_N, 110)
		await process_frame
		var id: String = modal.draft_id
		_check(modal.disclosure.text.contains("privately") and outbox.pending.is_empty(), "private destination disclosed before sending")
		_click(modal.send_button)
		_check(not modal.is_open() and not board.controller.paused, "real Save restores prior gameplay immediately")
		_check(outbox.pending.has(id) and modal.toast.text.contains("queued"), "Save persists before delivery and reports queued")
		var record: Variant = JSON.parse_string(outbox.queue.payload(id))
		_check(record is Dictionary and record.text == "n" and int(record.context.tick) == opening_tick, "immutable note carries gameplay context")
		await create_timer(0.8).timeout
		_check(outbox.pending.has(id) and outbox.queue.receipt(id).is_empty(), "accepted asynchronous request stays queued through process exit")
		var settings := ConfigFile.new()
		_check(settings.load(Outbox.CONFIG_PATH) == OK and settings.get_value(Outbox.CONFIG_SECTION, "retry_at") > Time.get_unix_time_from_system(), "the service's retry deadline is saved")
	elif phase == "recover":
		_check(outbox.pending.size() == 1 and modal.status.text.contains("1 queued"), "relaunch loads settings and shows persisted pending note")
		await create_timer(0.8).timeout
		_check(outbox.pending.size() == 1 and outbox.sent_count == 0, "the retry deadline survives relaunch and the report stays pending")
		_key(KEY_ESCAPE)
		_check(not modal.is_open() and not modal.toast.visible, "returns to live game before late acknowledgement")
		var deadline := Time.get_ticks_msec() + 18000
		while not outbox.pending.is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(outbox.pending.is_empty() and outbox.sent_count == 1, "automatic backoff confirms the queued report")
		_check(modal.toast.visible and modal.toast.text == "Feedback sent", "gameplay shows confirmation")
	elif phase == "readback":
		_check(outbox.pending.is_empty() and outbox.sent_count == 1 and outbox.local_count == 2 and modal.status.text.contains("1 sent"), "delivery receipt survives restart")
	elif phase == "terminal":
		var deadline := Time.get_ticks_msec() + 3000
		while outbox.rejected_count != 2 and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(outbox.pending.is_empty() and outbox.rejected_count == 2 and outbox.sent_count == 1, "400 and 409 stop affected records")
	elif phase == "terminal_restart":
		_check(outbox.pending.is_empty() and outbox.rejected_count == 2 and modal.status.text.contains("2 could not be sent"), "terminal rejections survive restart")
		await create_timer(0.5).timeout
	print("Run comment normal entry ", phase, ": ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
