extends SceneTree
## Launched by run_comment_delivery_test.py with disposable app data.

const Outbox = preload("res://scripts/core/run_comment_outbox.gd")
const REFERENCE := "https://github.com/example/waystone/issues/42"
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
	var endpoint := args[2]
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
		var opening_tick: int = modal.context.tick
		_key(KEY_N, 110)
		await process_frame
		_click(modal.delivery_button)
		await process_frame
		_check(modal.editing_delivery, "Delivery is reachable in the editor")
		modal.endpoint_field.text = endpoint
		_click(modal.apply_button)
		await process_frame
		_check(outbox.endpoint == endpoint and not modal.editing_delivery, "Apply saves relay via game UI")
		_check(modal.editor.text == "n" and board.state._simulation_tick_index == opening_tick, "config preserves draft and suspended simulation")
		var id: String = modal.draft_id
		_key(KEY_ENTER, 13, true)
		_check(not modal.is_open() and not board.controller.paused, "real Save restores prior gameplay immediately")
		_check(outbox.pending.has(id) and modal.toast.text.contains("queued"), "Save persists before delivery and reports queued")
		var record: Variant = JSON.parse_string(outbox.queue.payload(id))
		_check(record is Dictionary and record.text == "n" and int(record.context.tick) == opening_tick, "immutable note carries gameplay context")
		await create_timer(0.8).timeout
		_check(outbox.pending.has(id) and outbox.queue.receipt(id).is_empty(), "failed request stays queued through process exit")
	elif phase == "recover":
		_check(outbox.endpoint == endpoint and outbox.pending.size() == 1 and modal.status.text.contains("1 queued"), "relaunch loads settings and shows persisted pending note")
		await create_timer(0.8).timeout
		_check(outbox.pending.size() == 1 and outbox.delivered_count == 0, "mismatched receipt stays pending")
		var deadline := Time.get_ticks_msec() + 6500
		while not outbox.pending.is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		_check(outbox.pending.is_empty() and outbox.delivered_count == 1 and modal.status.text.contains("1 delivered"), "backoff retries while editor is open and updates status")
		_click(modal.delivery_button)
		await process_frame
		_check(modal.editing_delivery and modal.receipt_field.text == REFERENCE, "confirmed reference visible in Delivery")
		_check(board._display_safe_layout_rect().encloses(modal.panel.get_global_rect()), "portrait Delivery stays in the gameplay safe area")
	elif phase == "readback":
		_check(outbox.pending.is_empty() and outbox.delivered_count == 1, "matching receipt survives a second relaunch")
		_click(modal.delivery_button)
		await process_frame
		_check(modal.receipt_field.text == REFERENCE, "relaunch exposes stored receipt")
		modal.endpoint_field.clear()
		_click(modal.apply_button)
		_check(outbox.endpoint.is_empty() and not modal.editing_delivery and modal.status.text.contains("Delivery is off"), "can disable delivery without discarding receipt")
		var settings := ConfigFile.new()
		_check(settings.load(Outbox.CONFIG_PATH) == OK and settings.get_value("relay", "token", "missing").is_empty(), "disabling writes cleared credentials")
	print("Run comment normal entry ", phase, ": ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
