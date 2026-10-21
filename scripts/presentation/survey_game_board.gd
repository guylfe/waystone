extends "res://scripts/experiments/combat_lab_board.gd"

const Experiment = preload("res://scripts/core/survey_experiment.gd")
var inspection_return := false
var survey_choices := Experiment.defaults()
var survey_setup_confirmed := false
var overlay_pointers: Dictionary = {}
var overlay_replaying := false
var overlay_release_gate := false
var survey_setup_summary: Label

func _close_character_for_action() -> void:
	super._close_character_for_action()
	inspection_return = false

func _return_inspection_view() -> void:
	if not inspection_return: return
	inspection_return=false
	suspended=true
	selector_panel.visible=true
	_sync_information()

func _refresh_setup_choices() -> void:
	for control in survey_overlay.find_children("*","Button",true,false):
		if control.has_meta("menu_refresh"):
			control.get_meta("menu_refresh").call()
			var row=control.get_parent()
			row.get_child(0).disabled=control.disabled
			row.get_child(row.get_child_count()-1).disabled=control.disabled
	_update_setup_summary()

func _choice_row(parent: Node, button: Button, id: String, change: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var previous := _survey_action_button("‹",func(): change.call(-1))
	previous.custom_minimum_size.x=48; previous.set_meta("menu_skip",true)
	row.add_child(previous)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.set_meta("menu_id",id); button.set_meta("menu_change",change)
	row.add_child(button)
	var next := _survey_action_button("›",func(): change.call(1))
	next.custom_minimum_size.x=48; next.set_meta("menu_skip",true)
	row.add_child(next)

func _restart() -> void:
	super._restart()
	survey_choices = Experiment.defaults()

func _ready() -> void:
	survey_integrated = true
	super._ready()
	# The internal lab selectors never replace a rated Survey attempt.
	for child in selector_panel.get_children():
		selector_panel.remove_child(child)
		child.queue_free()
	_selector(selector_panel,["isometric","top_down"],view_mode,"Projection",func(value): view_mode=value; _layout())
	_lab_button(selector_panel,"Character · C",func(): inspection_return=true; _close_inspection(); suspended=false; _open_character_sheet())
	_lab_button(selector_panel,"Map · M",func(): inspection_return=true; _close_inspection(); suspended=false; map_open=true)
	_lab_button(selector_panel,"End Survey / rate",func(): inspection_return=true; _close_inspection(); suspended=false; _build_survey_end_confirmation())
	_lab_button(selector_panel,"Save attempt",func(): state.save_run(); state.lab_notice="Survey saved; Resume to continue.")
	_load_survey_identity()
	_layout()
	if OS.get_cmdline_user_args().has("--survey-smoke"):
		load("res://scripts/core/survey_export_probe.gd").call_deferred("run",self)

func _load_survey_identity() -> void:
	if state.survey_experiment.is_empty(): return
	survey_choices = state.survey_experiment.duplicate(true)
	variant = String(survey_choices["behavior"])
	fixture = String(survey_choices["scenario"])
	arrival = state.survey_profile if fixture == "generated" else String(survey_choices["arrival"])
	lab_rules = state.combat_rules
	lab_loadout = state.loadout_id
	scouting = bool(survey_choices["scouting"])
	enemy_tags.clear()
	notice_history.clear()
	previous_notice = ""

func _start_run() -> void:
	if setup_mode == "combat_survey" and not survey_setup_confirmed:
		_build_experiment_setup()
		return
	survey_setup_confirmed = false
	state.combat_lab = false
	super._start_run()
	_load_survey_identity()
	suspended = false
	_close_inspection()
	_layout()

func survey_start_options() -> Dictionary:
	return survey_choices.duplicate(true) if setup_mode == "combat_survey" else {}

func _build_experiment_setup() -> void:
	_clear_survey_overlay()
	survey_overlay.set_meta("kind","experiment_setup")
	survey_overlay.show()
	seed_input.hide()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	survey_overlay.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	var title := Label.new()
	title.text = "COMBAT SURVEY · BEHAVIOR & SCENARIO"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size",22)
	content.add_child(title)
	_add_choice(content,"behavior",Experiment.BEHAVIORS,"Behavior")
	_add_choice(content,"scenario",Experiment.SCENARIOS,"Encounter")
	_add_choice(content,"arrival",{"full":"Full resources","low":"Diagnostic · 60% HP / 35% Energy","sweep":"Warrior · earned level-two Sweep"},"Preset arrival")
	_add_choice(content,"scouting",{false:"Original placement",true:"Scouting · 340 west / natural awareness"},"Preset approach")
	_add_setup_choice(content,"Character",CombatCatalogScript.loadout_ids(),setup_loadout,func(value): setup_loadout=value)
	_add_setup_choice(content,"Resource rules",["energy","recovery"],setup_combat_rules,func(value): setup_combat_rules=value)
	_add_setup_choice(content,"Between rooms",["encounter","attrition"],setup_survey_profile,func(value): setup_survey_profile=value)
	var seed := LineEdit.new()
	seed.text = seed_input.text
	seed.placeholder_text = "Seed · optional keyboard entry; presets use 42"
	seed.set_meta("menu_id","setup:seed")
	seed.custom_minimum_size.y = 56
	seed.add_theme_font_size_override("font_size",18)
	seed.text_changed.connect(func(value): seed_input.text=value)
	content.add_child(seed)
	content.add_child(_survey_action_button("COMPOSE CUSTOM / EXACT ROSTER · %d SELECTED" % custom_room_roster.size(),func():
		survey_choices["scenario"]="generated"
		survey_choices["arrival"]="full"
		survey_choices["scouting"]=false
		if survey_choices["behavior"] == "G": survey_choices["behavior"]="C"
		survey_overlay.hide(); survey_overlay.set_meta("kind","")
		custom_room_open=true; _layout()))
	survey_setup_summary = Label.new()
	survey_setup_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	survey_setup_summary.add_theme_font_size_override("font_size",17)
	content.add_child(survey_setup_summary)
	_refresh_setup_choices()
	content.add_child(_survey_action_button("PLAY SELECTED SURVEY",_confirm_experiment_setup))
	content.add_child(_survey_action_button("BACK TO CHARACTER / RESOURCE / CUSTOM SETUP",_close_experiment_setup))
	_add_controller_hints(content)
	_layout()
	# Keyboard Tab and controller focus also scroll controls into view.
	for control in content.get_children():
		if control is Control and control.focus_mode != Control.FOCUS_NONE:
			control.focus_entered.connect(func(): scroll.ensure_control_visible(control))

func _add_setup_choice(parent: Node, caption: String, values: Array, _current: String, action: Callable) -> void:
	var property: String={"Character":"setup_loadout","Resource rules":"setup_combat_rules","Between rooms":"setup_survey_profile"}[caption]
	var button := _survey_action_button("",func(): pass)
	var refresh := func():
		var current := str(get(property))
		button.text=caption+" · "+(CombatCatalogScript.loadout_name(current) if caption=="Character" else current.capitalize())
	var change := func(delta: int):
		action.call(str(values[posmod(values.find(str(get(property)))+delta,values.size())]))
		_refresh_setup_choices()
	button.set_meta("menu_refresh",refresh)
	button.pressed.connect(func(): change.call(1))
	_choice_row(parent,button,"setup:"+property,change)
	refresh.call()

func _pointer_pressed(position: Vector2, is_mouse: bool = false) -> void:
	super._pointer_pressed(position,is_mouse)
	if not state.run_active and setup_stage != "root" and setup_mode == "combat_survey" and not custom_room_open and not survey_overlay.visible:
		_build_experiment_setup()

func _add_choice(parent: Node, field: String, options: Dictionary, caption: String) -> void:
	var button := _survey_action_button("",func(): pass)
	var refresh := func():
		button.text=caption+" · "+str(options[survey_choices[field]])
		button.disabled=field in ["arrival","scouting"] and survey_choices.scenario=="generated" or field=="scouting" and survey_choices.scenario=="F0"
	var change := func(delta: int):
		var keys := options.keys()
		survey_choices[field]=keys[posmod(keys.find(survey_choices[field])+delta,keys.size())]
		if survey_choices.behavior=="G" and survey_choices.scenario!="F2":
			if field=="behavior": survey_choices.scenario="F2"
			else: survey_choices.behavior="C"
		if survey_choices.scenario=="generated": survey_choices.arrival="full"; survey_choices.scouting=false
		if survey_choices.scenario=="F0": survey_choices.scouting=false
		_refresh_setup_choices()
	button.set_meta("menu_refresh",refresh)
	button.pressed.connect(func(): change.call(1))
	_choice_row(parent,button,"setup:"+field,change)
	refresh.call()

func _update_setup_summary() -> void:
	var named: bool = survey_choices["scenario"] != "generated"
	survey_setup_summary.text = "%s\nResource rules: %s · %s profile · %s\n%s\n%s" % [Experiment.BEHAVIORS[survey_choices["behavior"]],setup_combat_rules.capitalize(),setup_survey_profile.capitalize(),CombatCatalogScript.loadout_name(setup_loadout),Experiment.SCENARIOS[survey_choices["scenario"]],"Preset uses fixed seed42, replaces the custom roster, and ends in a rated report. Retry replays the same setup." if named else "Uses your seed and generated/custom encounter settings. Next follows ordinary Survey or custom-repeat policy."]
	if setup_loadout != "warrior" and survey_choices["behavior"] != "A": survey_setup_summary.text += "\nPaused cuts and Commit require Sword. This character retains its ordinary primary actions."
	if survey_choices["scenario"] == "F0": survey_setup_summary.text += "\nF0 keeps the native entrance; Scouting does not apply. Recorded geography only; no Expedition progression or journey acceptance. End Survey after the first-site observation."

func _confirm_experiment_setup() -> void:
	assert(Experiment.validate(survey_choices))
	if survey_choices["scenario"] != "generated": seed_input.text = "42"
	survey_overlay.hide()
	survey_overlay.set_meta("kind","")
	survey_setup_confirmed = true
	_start_run()
	overlay_release_gate = true
	if state.combat_lab: state.lab_neutral_required = true

func _close_experiment_setup() -> void:
	survey_overlay.hide()
	survey_overlay.set_meta("kind","")
	_sync_setup_controls()

func _sync_survey_overlay() -> void:
	if survey_overlay != null and survey_overlay.visible and survey_overlay.get_meta("kind","") == "experiment_setup": return
	super._sync_survey_overlay()
	if is_instance_valid(lab_panel): lab_panel.visible = _lab_ui_active() and not state.survey_feedback_pending and not state.trial_complete and not survey_overlay.visible

func _build_survey_report_overlay() -> void:
	super._build_survey_report_overlay()
	if not state.survey_experiment.is_empty() and state.survey_experiment["scenario"] != "generated":
		var content: Node = survey_overlay.get_child(0).get_child(0)
		content.add_child(_survey_action_button("RETRY SAME PRESET · NEW RATED ATTEMPT",_retry_survey_preset))
	_add_experiment_label()

func _build_survey_feedback_overlay() -> void:
	super._build_survey_feedback_overlay()
	_add_experiment_label()
	_layout()

func _submit_survey_feedback() -> void:
	super._submit_survey_feedback()
	_release_feedback_inputs()

func _skip_survey_feedback() -> void:
	super._skip_survey_feedback()
	_release_feedback_inputs()

func _release_feedback_inputs() -> void:
	if state.survey_experiment.is_empty(): return
	controller.release_actions(self)
	_cancel_inspection_input()
	lab_keys.clear()
	lab_pointer = false
	controller.target_id = -1
	overlay_release_gate = true
	_layout()

func _add_experiment_label() -> void:
	if state.survey_experiment.is_empty(): return
	var content: Node = survey_overlay.get_child(0).get_child(0)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",16)
	label.text = "%s\n%s · %s\n%s" % [Experiment.BEHAVIORS[state.survey_experiment["behavior"]],Experiment.SCENARIOS[state.survey_experiment["scenario"]],state.combat_rules.capitalize(),String(state.survey_room_definition.get("experiment",{}).get("provenance",""))]
	content.add_child(label)
	content.move_child(label,1)

func _retry_survey_preset() -> void:
	var options := state.survey_experiment.duplicate(true)
	survey_overlay.hide()
	survey_overlay.set_meta("kind","")
	state.combat_lab = false
	state.start_run(state.loadout_id,"combat_survey",42,state.survey_profile,state.combat_rules,false,options)
	_finish_run_start()
	_load_survey_identity()
	suspended = false
	_close_inspection()
	overlay_release_gate = true
	_layout()

func _refresh_action_panel() -> void:
	super._refresh_action_panel()
	if state.is_player_ready() and not state.lab_armed and not state.lab_neutral_required and not suspended:
		instruction.text = "Paused cuts · Tap cut; hold to continue" if variant == "B" else "Commit · Tap cut; hold to continue"
		if state.player_weapon_frame != "sword": instruction.text = state.player_weapon_frame.capitalize()+" · Ordinary primary actions"
	var count := 0
	for enemy in state.enemies:
		if int(enemy["hp"]) > 0 and state.enemy_visible_to_player(enemy): count += 1
	details_button.text = "All %d enemies\n& full details" % count
	diagnostics.text = "Survey · %s · %s · seed %d\n%s\n%s" % [Experiment.BEHAVIORS[variant],fixture,state.run_seed,String(state.survey_room_definition.get("experiment",{}).get("provenance","")),diagnostics.text]
	# Preserve exact identity in the report; avoid the harness's hard-coded seed42 label.
	diagnostics.text = diagnostics.text.replace("Start opens Compare","Start opens Survey menu").replace(" · seed42"," · seed %d" % state.run_seed)
	var menu: Button = utility_row.get_child(0)
	menu.text = "Survey menu\nStart / Esc"

func enemy_readout_model() -> Array:
	var candidates: Array = []
	for enemy in Array(visual.get("enemies",[])):
		if int(enemy.get("hp",0)) > 0 and state.enemy_visible_to_player(enemy): candidates.append(enemy)
	candidates.sort_custom(func(a,b):
		if int(a["id"]) == controller.target_id: return true
		if int(b["id"]) == controller.target_id: return false
		return Vector2(a["pos"]).distance_squared_to(state.player_pos) < Vector2(b["pos"]).distance_squared_to(state.player_pos))
	var result: Array = []
	if not guidance.visible: return result
	for enemy in candidates.slice(0,enemy_lines.size()):
		var phase := _enemy_phase(enemy)
		var resistance := _resistance_text(enemy)
		var on_board := board_rect.has_point(_world_to_screen(enemy["pos"]))
		var line := "#%s %s · %s · %s%s" % [_enemy_readout_tag(int(enemy["id"])),CombatCatalogScript.presentation(String(enemy["kind"]))["name"],_compact_phase(phase),_compact_resistance(resistance)," · off view" if not on_board else ""]
		var label: Label = enemy_lines[result.size()]
		if label.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x > maxf(1,information_slot.size.x):
			line = "#%s · %s · %s%s" % [_enemy_readout_tag(int(enemy["id"])),_compact_phase(phase),_compact_resistance(resistance)," · off view" if not on_board else ""]
		result.append({"id":int(enemy["id"]),"phase":phase,"resistance":resistance,"on_board":on_board,"rect":label.get_global_rect(),"lines":[line]})
	return result

func _enemy_readout_tag(actor_id: int) -> String:
	if not enemy_tags.has(actor_id): enemy_tags[actor_id] = str(enemy_tags.size()+1)
	return String(enemy_tags[actor_id])

func _unhandled_key_input(event: InputEvent) -> void:
	if survey_overlay.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and survey_overlay.get_meta("kind","") == "experiment_setup": _close_experiment_setup()
		return
	if _lab_ui_active() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_suspend_lab()
		selector_panel.visible = true
		_sync_information()
		return
	super._unhandled_key_input(event)

func _input(event: InputEvent) -> void:
	if state != null: _observe_menu_input(event)
	# Real native Survey overlay touch taps and swipes share one captured route.
	# Pointer IDs stay cancelled across closing/rebuilding/resizing until release.
	if overlay_replaying: return
	if event is InputEventScreenTouch:
		if event.pressed and survey_overlay.visible:
			overlay_pointers[event.index] = {"start":event.position,"last":event.position,"dragged":false,"panel":survey_overlay.get_child(0).get_instance_id() if survey_overlay.get_child_count() else 0}
		if overlay_pointers.has(event.index):
			var pointer: Dictionary = overlay_pointers[event.index]
			get_viewport().set_input_as_handled()
			if not event.pressed:
				overlay_pointers.erase(event.index)
				if not event.canceled and not pointer["dragged"] and survey_overlay.visible and survey_overlay.get_child_count() and survey_overlay.get_child(0).get_instance_id() == pointer["panel"]:
					overlay_replaying = true
					for down in [true,false]:
						var click := InputEventMouseButton.new()
						click.position = event.position
						click.global_position = event.position
						click.button_index = MOUSE_BUTTON_LEFT
						click.pressed = down
						get_viewport().push_input(click,true)
					overlay_replaying = false
			return
	elif event is InputEventScreenDrag and overlay_pointers.has(event.index):
		var pointer: Dictionary = overlay_pointers[event.index]
		if Vector2(pointer["start"]).distance_to(event.position) >= 6: pointer["dragged"] = true
		if survey_overlay.visible and survey_overlay.get_child_count() and survey_overlay.get_child(0) is ScrollContainer:
			var scroll: ScrollContainer = survey_overlay.get_child(0)
			scroll.scroll_vertical += int(round(Vector2(pointer["last"]).y-event.position.y))
		pointer["last"] = event.position
		get_viewport().set_input_as_handled()
		return
	if overlay_release_gate:
		if _physical_input_neutral(): overlay_release_gate = false
		else:
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _process(delta: float) -> void:
	if overlay_release_gate and overlay_pointers.is_empty() and _physical_input_neutral():
		overlay_release_gate = false
	super._process(delta)

func _layout() -> void:
	if previous_layout_size != Vector2.ZERO and previous_layout_size != size:
		for pointer in overlay_pointers.values(): pointer["dragged"] = true
	super._layout()
	if is_instance_valid(survey_overlay) and survey_overlay.get_meta("kind","") == "feedback" and survey_overlay.get_child_count():
		var content := survey_overlay.get_child(0).get_child(0)
		for node in content.get_children():
			if node.get_meta("survey_rating_row",false):
				var narrow := safe_layout_rect.size.x < 660
				node.columns = 1 if narrow else 2
				node.get_child(0).custom_minimum_size = Vector2(0 if narrow else 225,40 if narrow else 58)
			if node.get_meta("survey_tag_grid",false): node.columns = 2 if safe_layout_rect.size.x < 560 else 3
