extends "res://scripts/presentation/game_board.gd"

const Lab = preload("res://scripts/experiments/combat_lab_catalog.gd")
var variant := "C"
var fixture := "F1"
var arrival := "full"
var lab_loadout := "warrior"
var lab_rules := "energy"
var scouting := false
var status: Label
var continue_button: Button
var recover_button: Button
var commit_button: Button
var selector_panel: HFlowContainer
var lab_keys: Dictionary = {}
var lab_pointer := false
var lab_device := ""
var suspended := false
var lab_panel: PanelContainer

func _ready() -> void:
	lab_session = true
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()-1):
		match args[index]:
			"--variant": variant = args[index+1]
			"--fixture": fixture = args[index+1]
			"--loadout": lab_loadout = args[index+1]
			"--resources": arrival = args[index+1]
			"--rules": lab_rules = args[index+1]
	scouting = args.has("--scouting")
	super._ready()
	_restart()
	var panel := PanelContainer.new()
	lab_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	panel.resized.connect(_layout)
	var column := VBoxContainer.new()
	panel.add_child(column)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",16)
	column.add_child(status)
	var row := HFlowContainer.new()
	column.add_child(row)
	commit_button = _lab_button(row,"Commit [K / LT]",func(): state.lab_toggle_commit())
	continue_button = _lab_button(row,"Continue [Enter / RT]",func(): _begin_streamed_action(state.lab_continue()))
	recover_button = _lab_button(row,"Recover [J / LS]",func(): _begin_streamed_action(state.lab_recover()))
	_lab_button(row,"Compare / Retry",func():
		_suspend_lab()
		selector_panel.visible = not selector_panel.visible)
	_lab_button(row,"Resume",func():
		suspended = false
		controller.paused = false
		state.lab_neutral_required = true)
	selector_panel = HFlowContainer.new()
	column.add_child(selector_panel)
	selector_panel.visible = false
	_selector(selector_panel,Lab.VARIANTS.keys(),variant,func(value): variant=value)
	_selector(selector_panel,Lab.FIXTURES,fixture,func(value): fixture=value)
	_selector(selector_panel,Lab.LOADOUTS,lab_loadout,func(value): lab_loadout=value)
	_selector(selector_panel,["full","low","sweep"],arrival,func(value): arrival=value)
	_selector(selector_panel,["energy","recovery"],lab_rules,func(value): lab_rules=value)
	var scout := CheckButton.new()
	scout.text = "Scouting (-340 west)"
	scout.button_pressed = scouting
	scout.toggled.connect(func(value): scouting=value)
	selector_panel.add_child(scout)
	_lab_button(selector_panel,"Start fresh",func():
		_restart()
		selector_panel.visible=false)
	DisplayServer.window_set_title("Waystone — Experimental Combat Lab")
	print("LAB READY ",variant," / ",fixture," data=",OS.get_user_data_dir())

func _display_safe_layout_rect() -> Rect2:
	var rect := super._display_safe_layout_rect()
	if is_instance_valid(lab_panel):
		var header := minf(lab_panel.size.y+8.0,rect.size.y*0.45)
		rect.position.y += header
		rect.size.y -= header
	return rect

func _lab_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _selector(parent: Node, options: Array, current: String, action: Callable) -> void:
	var select := OptionButton.new()
	for value in options: select.add_item(String(value))
	select.selected = options.find(current)
	select.item_selected.connect(func(index): action.call(String(options[index])))
	parent.add_child(select)

func _restart() -> void:
	if state != null and state.run_active: state.lab_suspend()
	state = Lab.create(variant,fixture,lab_loadout,arrival,lab_rules,scouting)
	state.changed.connect(_on_state_changed)
	map_view_layer = state.current_layer
	visual = _presentation_snapshot()
	streaming_action = false
	playing = false
	stream_accumulator = 0.0
	suspended = false
	controller.release_actions(self)
	controller.target_id = -1
	controller.paused = false
	lab_keys.clear()
	lab_pointer = false
	state.lab_neutral_required = true
	_layout()
	queue_redraw()
	var entry := FileAccess.open("user://lab-entry-manifest.json",FileAccess.WRITE)
	if entry != null: entry.store_string(JSON.stringify(Lab.json_safe(Lab.manifest(state,fixture,arrival,scouting)),"\t"))

func _sync_survey_overlay() -> void:
	pass

func _mark_autosave(_immediate: bool = false) -> void:
	pass

func _process(delta: float) -> void:
	if state == null: return
	if _physical_input_neutral() and lab_keys.is_empty() and not lab_pointer and desktop_movement_keys.is_empty() and (not controller.active or (controller.stick(JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y).is_zero_approx() and not controller.held.values().has(true))): state.lab_input_neutral()
	if not suspended: super._process(delta)
	else:
		visual = _presentation_snapshot()
		queue_redraw()
	if state.lab_neutral_required:
		attack_key_held = false
		attack_pointer_held = false
		attack_button_pointer_held = false
		controller.attack_held = false
		controller.pending_button = -1
	if state.lab_junction():
		stream_accumulator = 0.0
		visual = _presentation_snapshot()
	if status != null:
		status.text = "EXPERIMENT %s (%s) · %s · %s · seed42\n%s\nOwed %.3fs · current cut %.3fs · %s" % [variant,Lab.VARIANTS[variant],fixture,arrival,state.lab_notice,state.player_commitment_world_remaining(),state.player_control_world_remaining(),"SUSPENDED" if suspended else "ARMED" if state.lab_armed else "FROZEN CHOICE" if state.lab_junction() else "READY" if state.is_player_ready() else "ACTING"]
		continue_button.disabled = not state.lab_junction()
		if state.lab_junction(): continue_button.text = "Continue cut %d [Enter / RT]" % (int(state.player_action["committed_phase"])+2)
		recover_button.disabled = not state.lab_junction()
		commit_button.disabled = not state.is_player_ready() or variant in ["A","B"] or state.player_weapon_frame != "sword"
		commit_button.text = "Disarm [K / LT]" if state.lab_armed else "Commit [K / LT]"

func _physical_input_neutral() -> bool:
	if Input.is_anything_pressed(): return false
	for device in Input.get_connected_joypads():
		for axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y,JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			if absf(Input.get_joy_axis(device,axis)) > controller.DEADZONE: return false
	return true

func _suspend_lab() -> void:
	state.lab_suspend()
	controller.release_actions(self)
	controller.target_id = -1
	controller.axes.clear()
	controller.held.clear()
	lab_keys.clear()
	lab_pointer = false
	desktop_movement_keys.clear()
	streaming_action = false
	playing = false
	stream_accumulator = 0.0
	suspended = true
	visual = _presentation_snapshot()

func _notification(what: int) -> void:
	if state != null and what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: _suspend_lab()
	else: super._notification(what)

func _input(event: InputEvent) -> void:
	var device := "controller" if event is InputEventJoypadMotion or event is InputEventJoypadButton else "touch" if event is InputEventScreenTouch else "desktop" if event is InputEventMouseButton or event is InputEventKey else ""
	if device != "" and lab_device != "" and device != lab_device:
		state.lab_armed = false
		controller.target_id = -1
		state.set_attack_hold(false)
		lab_keys.clear()
		lab_pointer = false
		state.lab_neutral_required = true
	if device != "": lab_device = device
	if event is InputEventKey:
		if event.pressed: lab_keys[event.keycode] = true
		else:
			lab_keys.erase(event.keycode)
			if event.keycode == KEY_ENTER: state.set_attack_hold(false)
	if suspended: return
	super._input(event)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	if not event.pressed or event.echo:
		super._unhandled_key_input(event)
		return
	if event.keycode == KEY_ESCAPE:
		_suspend_lab()
		return
	if suspended: return
	match event.keycode:
		KEY_K: state.lab_toggle_commit()
		KEY_J: _begin_streamed_action(state.lab_recover())
		KEY_T: controller.cycle_target(self)
		KEY_ENTER:
			if state.lab_junction(): _begin_streamed_action(state.lab_continue(true))
			elif state.lab_armed: _begin_streamed_action(state.lab_target(controller.target_id))
		_:
			if state.lab_junction() and _is_desktop_movement_key(event.keycode):
				var direction := _keyboard_direction(event.keycode)
				_begin_streamed_action(state.request_move(direction,state.MOVE_RANGE,false))
			elif state.lab_junction() and event.keycode in [KEY_SHIFT,KEY_B,KEY_2]: _begin_streamed_action(state.request_dodge(state.player_facing,false))
			else: super._unhandled_key_input(event)

func _keyboard_direction(key: int) -> Vector2:
	var direction := Vector2.LEFT if key in [KEY_A,KEY_LEFT] else Vector2.RIGHT if key in [KEY_D,KEY_RIGHT] else Vector2.UP if key in [KEY_W,KEY_UP] else Vector2.DOWN
	return _screen_delta_to_world_direction(direction)

func _gui_input(event: InputEvent) -> void:
	if suspended: return
	var is_pointer := event is InputEventMouseButton or event is InputEventScreenTouch
	if is_pointer and state.lab_armed and (not board_rect.has_point(event.position) or selected_action != ""):
		super._gui_input(event)
		return
	if is_pointer and (state.lab_armed or state.lab_junction() or lab_pointer):
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT: return
		lab_pointer = event.pressed
		if event.pressed:
			var enemy := _enemy_near(event.position,54.0)
			if state.lab_armed:
				_begin_streamed_action(state.lab_target(int(enemy.get("id",-1)),true))
			elif state.lab_junction():
				if Rect2(buttons.get("defense",Rect2())).has_point(event.position):
					selected_action = "defense"
					state.lab_notice = "Choose Dodge direction; recovery is paid first."
				elif board_rect.has_point(event.position):
					if selected_action == "defense":
						selected_action = ""
						_begin_streamed_action(state.request_dodge(_screen_delta_to_world_direction(event.position-_world_to_screen(state.player_pos)),false))
					elif not enemy.is_empty(): _begin_streamed_action(state.lab_target(int(enemy["id"]),true))
					else: _begin_streamed_action(state.request_move(_screen_delta_to_world_direction(event.position-_world_to_screen(state.player_pos)),state.MOVE_RANGE,false))
				else: state.lab_notice = "Choose Continue, Recover, Move or Dodge at this junction."
		else: state.set_attack_hold(false)
		accept_event()
		return
	super._gui_input(event)
