extends Control
## A modal editor above both the regular run menu and Survey's inspection view.

const Metrics = preload("res://scripts/presentation/menu_metrics.gd")
const CommentQueue = preload("res://scripts/core/run_comment_queue.gd")
const Outbox = preload("res://scripts/core/run_comment_outbox.gd")

signal closed
var queue := CommentQueue.new()
var draft_id := ""
var context: Dictionary
var editor: TextEdit
var save_button: Button
var cancel_button: Button
var delivery_button: Button
var back_button: Button
var apply_button: Button
var delivery: Outbox
var settings_scroll: ScrollContainer
var endpoint_field: LineEdit
var token_field: LineEdit
var receipt_field: LineEdit
var settings_status: Label
var editing_delivery := false
var save_failed := false
var toast_id := ""
var heading: Label
var status: Label
var panel: PanelContainer
var toast: Label
var backdrop: ColorRect
var touches: Dictionary = {}
var joy_down: Dictionary = {}
var joy_stick := Vector2.ZERO
var stick_direction := Vector2.ZERO
var previous_focus: Control
var keyboard_height := 0
var replaying := false

func _ready() -> void:
	delivery = get_node("/root/RunCommentOutbox")
	queue = delivery.queue
	delivery.changed.connect(_update_delivery_status)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = ColorRect.new()
	backdrop.color = Color(0.02, 0.04, 0.06, 0.86)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	backdrop.add_child(panel)
	var inset := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]: inset.add_theme_constant_override("margin_" + edge, 12)
	panel.add_child(inset)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	inset.add_child(content)
	heading = Label.new()
	heading.text = "Run comment"
	heading.add_theme_font_size_override("font_size", 23)
	content.add_child(heading)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 2
	content.add_child(status)
	editor = TextEdit.new()
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.placeholder_text = "What happened or what should change?"
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.virtual_keyboard_show_on_focus = false
	editor.text_changed.connect(_text_changed)
	content.add_child(editor)
	_create_delivery_settings(content)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	cancel_button = _add_button(actions, "Cancel", _close)
	save_button = _add_button(actions, "Save comment", _save)
	delivery_button = _add_button(actions, "Delivery", _open_delivery)
	back_button = _add_button(actions, "Back", _return_to_draft)
	apply_button = _add_button(actions, "Apply", _apply_delivery)
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color("19343b")
	toast.add_theme_stylebox_override("normal", toast_style)
	add_child(toast)
	toast.hide()
	backdrop.hide()
	resized.connect(_reflow)
	set_process(false)

func _add_button(parent: Control, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func is_open() -> bool:
	return is_instance_valid(backdrop) and backdrop.visible

func _create_delivery_settings(content: Control) -> void:
	settings_scroll = ScrollContainer.new()
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.follow_focus = true
	content.add_child(settings_scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.add_child(form)
	endpoint_field = _delivery_field(form, "HTTPS relay address", 512)
	token_field = _delivery_field(form, "Player relay token", 4096)
	token_field.secret = true
	receipt_field = _delivery_field(form, "Recent GitHub receipt", 512)
	receipt_field.editable = false
	var instructions := Label.new()
	instructions.text = "The token is stored on this device for retries after restart. Clear both fields to turn off delivery."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(instructions)
	settings_status = Label.new()
	settings_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(settings_status)

func _delivery_field(form: Control, label: String, max_length: int) -> LineEdit:
	var caption := Label.new()
	caption.text = label
	form.add_child(caption)
	var field := LineEdit.new()
	field.accessibility_name = label
	field.max_length = max_length
	form.add_child(field)
	return field

func _open_delivery() -> void:
	endpoint_field.text = delivery.endpoint
	token_field.clear()
	token_field.placeholder_text = "Leave blank to keep the token for this address" if not delivery.endpoint.is_empty() else ""
	settings_status.text = ""
	_set_editor_view(true)
	_update_delivery_status()
	back_button.grab_focus()

func _return_to_draft() -> void:
	token_field.clear()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
	_set_editor_view(false)
	_update_delivery_status()
	delivery_button.grab_focus()

func _apply_delivery() -> void:
	var result := delivery.configure(endpoint_field.text, token_field.text)
	if result == OK:
		_return_to_draft()
		return
	settings_status.text = "Enter an HTTPS relay address and its player token." if result == ERR_INVALID_PARAMETER else "Could not save Delivery settings. Try again."
	settings_scroll.ensure_control_visible(settings_status)

func _set_editor_view(show_settings: bool) -> void:
	editing_delivery = show_settings
	heading.text = "Comment delivery" if show_settings else "Run comment"
	settings_scroll.visible = show_settings
	back_button.visible = show_settings
	apply_button.visible = show_settings
	editor.visible = not show_settings
	save_button.visible = not show_settings
	cancel_button.visible = not show_settings
	delivery_button.visible = not show_settings
	_reflow()

func _update_delivery_status() -> void:
	if not save_failed: status.text = delivery.summary()
	receipt_field.text = delivery.latest_reference
	receipt_field.placeholder_text = "No confirmed delivery yet"
	if toast.visible and not toast_id.is_empty() and not queue.receipt(toast_id).is_empty():
		toast.text = "Comment delivered"

func open(snapshot: Dictionary) -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	if is_instance_valid(previous_focus): previous_focus.release_focus()
	draft_id = CommentQueue.new_id()
	context = snapshot
	save_failed = false
	editor.text = ""
	save_button.disabled = true
	toast.hide()
	backdrop.show()
	keyboard_height = _keyboard_height()
	_set_editor_view(false)
	_update_delivery_status()
	set_process(true)
	editor.grab_focus()

func _save() -> void:
	if not is_open() or editor.text.strip_edges().is_empty(): return
	if queue.enqueue(draft_id, editor.text, context) != OK:
		save_failed = true
		status.text = "Could not save the comment. Your text is still here. Try again."
		_reflow()
		return
	_close()
	toast_id = draft_id
	toast.text = "Comment saved · queued for delivery" if not delivery.endpoint.is_empty() else "Comment saved · queued on this device"
	_reflow()
	toast.show()
	if queue == delivery.queue: delivery.note_saved()
	var saved_id := draft_id
	await get_tree().create_timer(2.5).timeout
	if draft_id == saved_id:
		toast.hide()
		if not is_open(): set_process(false)

func cancel() -> void:
	_close()

func cancel_contacts() -> void:
	for index in touches: touches[index] = Vector2.INF
	joy_down.clear()
	joy_stick = Vector2.ZERO
	stick_direction = Vector2.ZERO

func _close() -> void:
	if not is_open(): return
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus) and backdrop.is_ancestor_of(focus): focus.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
	backdrop.hide()
	editor.clear()
	token_field.clear()
	context = {}
	set_process(false)
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()
	closed.emit()

func _text_changed() -> void:
	# IME and paste can insert multiple characters in one change.
	if editor.text.length() > CommentQueue.MAX_TEXT:
		var line := editor.get_caret_line()
		var column := editor.get_caret_column()
		editor.text = editor.text.left(CommentQueue.MAX_TEXT)
		editor.set_caret_line(mini(line, editor.get_line_count() - 1))
		editor.set_caret_column(column)
	save_button.disabled = editor.text.strip_edges().is_empty()

func _process(_delta: float) -> void:
	if not is_open(): return
	var height := _keyboard_height()
	if height != keyboard_height:
		keyboard_height = height
		_reflow()

func _keyboard_height() -> int:
	return DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0

func _reflow() -> void:
	if not is_instance_valid(panel): return
	var board := get_parent() as Control
	var u := Metrics.unit(board)
	var safe: Rect2 = board._display_safe_layout_rect()
	if is_open():
		var scale_y := get_viewport().get_final_transform().y.length()
		var keyboard_top := size.y - float(keyboard_height) / maxf(0.1, scale_y)
		safe.end.y = minf(safe.end.y, keyboard_top)
		var margin := 12.0 * u
		var extent := Vector2(maxf(1.0, minf(safe.size.x - 2.0 * margin, 600.0 * u)), maxf(1.0, minf(safe.size.y - 2.0 * margin, 360.0 * u)))
		heading.visible = extent.y >= 200.0 * u
		status.visible = heading.visible or status.text.begins_with("Could not")
		Metrics.apply_unit(panel, u)
		panel.size = extent
		panel.position = safe.get_center() - extent * 0.5
		var focus := get_viewport().gui_get_focus_owner()
		if editing_delivery and focus in [endpoint_field, token_field]:
			settings_scroll.ensure_control_visible.call_deferred(focus)
	else:
		var extent := Vector2(minf(safe.size.x, 330.0 * u), 44.0 * u)
		Metrics.apply_unit(toast, u)
		toast.position = Vector2(safe.get_center().x - extent.x * 0.5, safe.position.y + 12.0 * u)
		toast.size = extent

# The project disables global mouse emulation. Capture touch IDs here so a
# contact begun in the editor cannot activate the game after dismissal.
func route(event: InputEvent) -> bool:
	if replaying: return true
	var open_now := is_open()
	if event is InputEventScreenTouch:
		if event.pressed:
			if open_now: touches[event.index] = event.position
			else: touches.erase(event.index)
		if not event.pressed and touches.has(event.index):
			var start: Vector2 = touches[event.index]
			touches.erase(event.index)
			get_viewport().set_input_as_handled()
			if open_now and not event.canceled and start.distance_to(event.position) < _touch_slop():
				_touch_tap(event.position)
			return true
		if open_now:
			get_viewport().set_input_as_handled()
			return true
	if event is InputEventScreenDrag and (open_now or touches.has(event.index)):
		if touches.has(event.index) and Vector2(touches[event.index]).distance_to(event.position) >= _touch_slop():
			touches[event.index] = Vector2.INF
			if open_now and editor.visible and editor.get_global_rect().has_point(event.position):
				editor.scroll_vertical -= event.relative.y / maxf(1.0, editor.get_line_height())
			if open_now and editing_delivery and settings_scroll.get_global_rect().has_point(event.position):
				settings_scroll.scroll_vertical -= int(event.relative.y)
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventJoypadButton:
		var was_down := joy_down.has(event.button_index)
		if event.pressed: joy_down[event.button_index] = true
		else: joy_down.erase(event.button_index)
		if open_now:
			get_viewport().set_input_as_handled()
			if event.pressed and not was_down: _joy_button(event.button_index)
		return open_now
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X: joy_stick.x = event.axis_value
		elif event.axis == JOY_AXIS_LEFT_Y: joy_stick.y = event.axis_value
		var next_direction := Vector2.ZERO
		if joy_stick.length() >= (0.55 if stick_direction.is_zero_approx() else 0.35):
			next_direction = Vector2(signf(joy_stick.x), 0) if absf(joy_stick.x) > absf(joy_stick.y) else Vector2(0, signf(joy_stick.y))
		if open_now:
			get_viewport().set_input_as_handled()
			if next_direction != stick_direction and next_direction != Vector2.ZERO: _step(int(next_direction.x + next_direction.y))
		stick_direction = next_direction
		return open_now
	if open_now and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or (event.ctrl_pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]):
			get_viewport().set_input_as_handled()
			if not event.echo:
				if event.keycode == KEY_ESCAPE: _back()
				elif editing_delivery: _apply_delivery()
				else: _save()
		elif event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			if not event.echo: _step(-1 if event.shift_pressed else 1)
		elif not (get_viewport().gui_get_focus_owner() is TextEdit or get_viewport().gui_get_focus_owner() is LineEdit) and event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			get_viewport().set_input_as_handled()
			if not event.echo: _step(-1 if event.keycode in [KEY_UP, KEY_LEFT] else 1)
	return open_now

func _step(change: int) -> void:
	var controls: Array[Control] = [editor, cancel_button]
	if not save_button.disabled: controls.append(save_button)
	controls.append(delivery_button)
	if editing_delivery: controls = [endpoint_field, token_field, receipt_field, back_button, apply_button]
	var selected := controls.find(get_viewport().gui_get_focus_owner())
	controls[posmod(selected + change, controls.size())].grab_focus()

func _joy_button(button: int) -> void:
	match button:
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT: _step(-1)
		JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT: _step(1)
		JOY_BUTTON_B: _back()
		JOY_BUTTON_A:
			var focus := get_viewport().gui_get_focus_owner()
			if focus == editor and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): _show_keyboard()
			elif focus == cancel_button: _close()
			elif focus == save_button: _save()
			elif focus == delivery_button: _open_delivery()
			elif focus == back_button: _return_to_draft()
			elif focus == apply_button: _apply_delivery()
			elif focus in [endpoint_field, token_field] and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				var field := focus as LineEdit
				var kind := DisplayServer.KEYBOARD_TYPE_PASSWORD if field.secret else DisplayServer.KEYBOARD_TYPE_URL
				DisplayServer.virtual_keyboard_show(field.text, field.get_global_rect(), kind, field.max_length)

func _back() -> void:
	if editing_delivery: _return_to_draft()
	else: _close()

func _touch_slop() -> float:
	return 10.0 * Metrics.unit(get_parent())

func _touch_tap(point: Vector2) -> void:
	replaying = true
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		get_viewport().push_input(click, true)
	replaying = false

func _show_keyboard() -> void:
	editor.grab_focus()
	# TextEdit's native IME keeps newlines and applies edits at the caret.
	DisplayServer.virtual_keyboard_show(editor.text, editor.get_global_rect(), DisplayServer.KEYBOARD_TYPE_MULTILINE, CommentQueue.MAX_TEXT)
