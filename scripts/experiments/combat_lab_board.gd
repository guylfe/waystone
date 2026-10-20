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
var instruction: Label
var feedback: Label
var diagnostics: Label
var action_grid: GridContainer
var target_button: Button
var details_button: Button
var utility_row: HBoxContainer
var lab_badge_rects: Array[Rect2] = []
var hud_rect := Rect2()
var detail_open := false
var previous_layout_size := Vector2.ZERO
var information_slot: Control
var guidance: VBoxContainer
var inspection_scroll: ScrollContainer
var inspection_content: VBoxContainer
var enemy_readout_rect := Rect2()


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
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("151b1f")
	panel.add_theme_stylebox_override("panel",surface)
	add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 8)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	status = _lab_label(column, 20, 26)
	# Fixed-height information slot: expanded content scrolls rather than taking
	# space from the world. The title and every action remain available.
	information_slot = Control.new()
	information_slot.custom_minimum_size.y = 82
	column.add_child(information_slot)
	guidance = VBoxContainer.new()
	information_slot.add_child(guidance)
	guidance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	instruction = _lab_label(guidance, 15, 40)
	feedback = _lab_label(guidance, 14, 34)
	inspection_scroll = ScrollContainer.new()
	inspection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	information_slot.add_child(inspection_scroll)
	inspection_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inspection_content = VBoxContainer.new()
	inspection_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspection_scroll.add_child(inspection_content)
	inspection_scroll.visible = false
	feedback.add_theme_color_override("font_color", Color("f0c680"))
	action_grid = GridContainer.new()
	action_grid.columns = 4
	action_grid.add_theme_constant_override("h_separation", 8)
	action_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(action_grid)
	continue_button = _lab_button(action_grid,"Attack\nF / RT",func(): pass)
	continue_button.button_down.connect(func(): _lab_attack(true))
	continue_button.button_up.connect(func():
		state.set_attack_hold(false)
		if String(state.player_action.get("kind","")) == "bow_draw": state.release_bow_attack(state.player_facing))
	recover_button = _lab_button(action_grid,"Recover\nJ / LS click",func(): _begin_streamed_action(state.lab_recover()))
	commit_button = _lab_button(action_grid,"Commit\nK / LT",func(): state.lab_toggle_commit())
	target_button = _lab_button(action_grid,"Next target\nT / RS click",func():
		if state.lab_armed: controller.cycle_target(self)
		else: state.lab_notice = "Arm Commit before selecting a target.")
	utility_row = HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 8)
	column.add_child(utility_row)
	_lab_button(utility_row,"Compare / Retry",func():
		_suspend_lab()
		selector_panel.visible = not selector_panel.visible
		_sync_information())
	_lab_button(utility_row,"Resume",func():
		suspended = false
		controller.paused = false
		state.lab_neutral_required = true
		if state.lab_notice.begins_with("Suspended"): state.lab_notice = "Release controls to continue.")
	details_button = _lab_button(utility_row,"Review details",func():
		detail_open = not detail_open
		diagnostics.visible = detail_open
		_sync_information())
	diagnostics = _lab_label(inspection_content, 14, 0)
	diagnostics.visible = false
	selector_panel = HFlowContainer.new()
	inspection_content.add_child(selector_panel)
	selector_panel.visible = false
	_selector(selector_panel,["isometric","top_down"],view_mode,func(value):
		view_mode=value
		_layout())
	_selector(selector_panel,Lab.VARIANTS.keys(),variant,func(value): variant=value)
	_selector(selector_panel,Lab.FIXTURES,fixture,func(value): fixture=value)
	_selector(selector_panel,Lab.LOADOUTS,lab_loadout,func(value): lab_loadout=value)
	_selector(selector_panel,["full","low","sweep"],arrival,func(value): arrival=value)
	_selector(selector_panel,["energy","recovery"],lab_rules,func(value): lab_rules=value)
	var scout := CheckButton.new()
	scout.text = "Scouting (-340 west)"
	scout.custom_minimum_size.y = 48
	scout.button_pressed = scouting
	scout.toggled.connect(func(value): scouting=value)
	selector_panel.add_child(scout)
	_lab_button(selector_panel,"Start fresh",func():
		_restart()
		selector_panel.visible=false
		_sync_information())
	_layout()
	DisplayServer.window_set_title("Waystone — Experimental Combat Lab")
	print("LAB READY ",variant," / ",fixture," data=",OS.get_user_data_dir())

func _lab_label(parent: Node, font: int, height: float) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font)
	if height > 0:
		var slot := Control.new()
		slot.custom_minimum_size.y = height + 4
		slot.clip_contents = true
		parent.add_child(slot)
		slot.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else: parent.add_child(label)
	return label

func _sync_information() -> void:
	inspection_scroll.visible = detail_open or selector_panel.visible
	guidance.visible = not inspection_scroll.visible
	inspection_scroll.scroll_vertical = 0
	_layout()

func _layout() -> void:
	# Native orientation is always derived from the full safe display. Reserved
	# header space must never turn a physical portrait surface into landscape.
	super._layout()
	if not is_instance_valid(lab_panel) or not is_instance_valid(action_grid): return
	var full := super._display_safe_layout_rect()
	var portrait := full.size.y >= full.size.x
	var side_width := maxf(228,full.size.x*0.245)
	var width := full.size.x if portrait else full.size.x-side_width-12
	action_grid.columns = 2 if width < 460 else 4
	# Recompute from authored compact slots, never the previous Container size.
	var header := 30.0 + 82.0 + (104.0 if action_grid.columns == 2 else 48.0) + 48.0 + 24.0 + 16.0
	lab_panel.position = full.position
	lab_panel.size = Vector2(width,header)
	if portrait:
		for action_name in buttons:
			var rect: Rect2 = buttons[action_name]
			rect.size.y = maxf(48,rect.size.y)
			buttons[action_name] = rect
		interaction_rect.size.y = maxf(48,interaction_rect.size.y)
		hud_rect = Rect2(full.position + Vector2(8,header+8),Vector2(full.size.x-16,62))
	else:
		var side_x := full.end.x-side_width+4
		var control_width := side_width-12
		hud_rect = Rect2(Vector2(side_x,full.position.y+8),Vector2(control_width,82))
		interaction_rect = Rect2(Vector2(side_x,full.position.y+92),Vector2(control_width,48))
		var slot_width := (control_width-24)/4
		var belt_keys := ["healing","slot_0","slot_1","slot_2"]
		for index in range(4): consumable_rects[belt_keys[index]] = Rect2(Vector2(side_x+index*(slot_width+8),full.position.y+148),Vector2(slot_width,48))
		var action_names := ["defense","skill","rally","advance","adopted"]
		var action_height := maxf(48,(full.size.y-212-32)/5)
		for index in range(5): buttons[action_names[index]] = Rect2(Vector2(side_x,full.position.y+204+index*(action_height+8)),Vector2(control_width,action_height))
	# Phase/resistance reads have their own strip, outside every contact tell.
	# Reserve by fixture roster (including off-camera actors), so action/visibility
	# changes do not shift the world. The current F2 maximum is three actors.
	var rows := mini(3,state.enemies.size()) if state != null else 0
	var readout_y := full.position.y + header + (78.0 if portrait else 8.0)
	enemy_readout_rect = Rect2(Vector2(full.position.x,readout_y),Vector2(width,rows*38.0))
	var world_y := enemy_readout_rect.end.y + 4
	var world_end := interaction_rect.position.y-8 if portrait else full.end.y
	board_area = Rect2(Vector2(full.position.x,world_y),Vector2(width,maxf(0,world_end-world_y)))
	_update_projection()
	# These native toolbar hit regions would be invisible under the lab panel.
	reset_rect = Rect2()
	view_rect = Rect2()
	map_rect = Rect2()
	sheet_button_rect = Rect2()
	survey_end_rect = Rect2()
	# Fit the local actor pair into the reduced world rectangle. This changes only
	# projection scale; attack/contact geometry remains in world coordinates.
	world_scale = minf(world_scale,maxf(0.35,minf(board_rect.size.x/650.0,board_rect.size.y/360.0)))
	# A resize cancels adapter gestures, never executes stale coordinates.
	if previous_layout_size != Vector2.ZERO and previous_layout_size != size:
		pointer_down = false
		lab_pointer = false
		selected_action = ""
		state.set_attack_hold(false)
	previous_layout_size = size

func _lab_attack(held: bool = false) -> void:
	if suspended:
		state.lab_notice = "Suspended · Resume first."
	elif state.player_action.has("lab_exit_request"): state.lab_notice = "Already queued: " + String(state.player_action["lab_exit_request"]["kind"]).capitalize()
	elif bool(state.player_action.get("lab_prepaid",false)): state.lab_notice = "Commit running · All remaining cuts locked."
	elif state.lab_junction(): _begin_streamed_action(state.lab_continue(held))
	elif state.lab_armed: _begin_streamed_action(state.lab_target(controller.target_id))
	elif state.lab_neutral_required: state.lab_notice = "Release controls to continue."
	elif not state.is_player_ready(): state.lab_notice = "Finish the current commitment first."
	else: _begin_streamed_action(state.request_direct_attack(state.player_facing,false,held))

func _lab_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(48,48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",14)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _selector(parent: Node, options: Array, current: String, action: Callable) -> void:
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(48,48)
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
	if status != null: _refresh_action_panel()

# Player-facing state is derived from authoritative facts; diagnostics stay separate.
func action_panel_state() -> Dictionary:
	var action: Dictionary = state.player_action
	var kind := String(action.get("kind", "idle"))
	var queued: Dictionary = action.get("lab_exit_request", {})
	var remaining := state.player_commitment_world_remaining()
	var title := "Ready · Time frozen"
	var text := "Tap: one cut · Hold: continue"
	var phase := _phase(action).capitalize()
	if suspended:
		title = "Suspended · Time frozen"
		text = "Resume requires neutral controls."
	elif kind in ["hit_reaction", "stagger"]:
		title = "Interrupted · " + ("Reeling" if kind == "hit_reaction" else "Staggered")
		text = "Sequence ended · " + ("Queued request cleared. " if state.lab_notice.contains("Queued") else "") + "Consequence still running."
	elif not queued.is_empty():
		title = "Recovering → " + String(queued["kind"]).capitalize()
		text = "Starts in ~%.2fs · Not active yet\nAfter recovery: %s · Queue locked" % [remaining,_direction_read(queued["direction"])]
	elif state.lab_junction():
		title = "Choose next cut · Time frozen"
		text = "Recovery still owed: ~%.2fs\nContinues sequence facing %s" % [state.player_control_world_remaining(),_direction_read(state.player_facing)]
	elif kind == "combo":
		var paid := bool(action.get("lab_prepaid",false))
		if bool(action.get("terminal_recovery_locked",false)) or int(action.get("committed_phase",0)) >= Array(action.get("phases",[])).size()-1 and phase == "Following through":
			title = "Recovering"
			text = "Ready in ~%.2fs · %s" % [remaining,"All cuts locked" if paid else "Recovery chosen" if bool(action.get("terminal_recovery_locked",false)) else "Final cut"]
			if paid: title = "Commit · Recovering"
		else:
			title = "%s · Cut %d/3" % ["Commit" if paid else "Normal",maxi(0,int(action.get("phase_index",0)))+1]
			text = "%s · %s: ~%.2fs" % [phase,"Whole commitment" if paid else "Current cut + exit",remaining]
			text += " · All cuts locked" if paid else " · Future cuts optional"
	elif not state.is_player_ready():
		title = phase if phase != "" else kind.capitalize()
		text = "Current commitment: ~%.2fs" % remaining
	elif state.lab_neutral_required:
		title = "Release controls to continue"
		text = "Time frozen · Release attack, buttons and sticks."
	elif state.lab_armed:
		title = "Commit armed · Time frozen"
		var target: Dictionary = state._enemy_by_id(controller.target_id)
		text = "Choose eligible enemy" if target.is_empty() or state.lab_target_refusal(controller.target_id) != "" else "Target: " + String(CombatCatalogScript.presentation(String(target["kind"]))["name"])
		text += " · %.2f Energy" % state.lab_commit_cost() if state.uses_energy_rules() else " · Recovery rules"
		text += "\n3 cuts · No refund · Interruptible"
	if state.lab_variant == "A" and kind == "idle" and not suspended and not state.lab_neutral_required: text = "Control · Existing tap / hold rules"
	elif state.lab_variant == "B" and state.is_player_ready(): text += " · Commit unavailable in B"
	return {"title":title,"instruction":text,"queued":queued,"whole_remaining":remaining,"cut_remaining":state.player_control_world_remaining()}

func _refresh_action_panel() -> void:
	var model := action_panel_state()
	status.text = model["title"]
	instruction.text = model["instruction"]
	feedback.text = state.lab_notice
	continue_button.text = "Continue cut %d\nEnter / RT" % (int(state.player_action["committed_phase"])+2) if state.lab_junction() else "Confirm target\nEnter / RT" if state.lab_armed else "Attack\nF / RT"
	commit_button.text = "Disarm\nK / LT" if state.lab_armed else "Commit\nK / LT"
	# Keep refusals tappable and positions fixed; unavailable actions explain why.
	for entry in [[continue_button,(state.is_player_ready() and not state.lab_neutral_required) or state.lab_junction()],[recover_button,state.lab_junction()],[commit_button,state.is_player_ready() and variant not in ["A","B"] and state.player_weapon_frame == "sword"],[target_button,state.lab_armed]]:
		entry[0].modulate = Color.WHITE if entry[1] else Color("9da8ad")
	diagnostics.text = "%s / %s · %s · %s · %s · seed42\nWhole obligation %.3fs · Current-cut debt %.3fs\nFacing %s · Poise %.2f · Future: hollow optional, square locked.\nTarget confirmation: T / RS click then Enter / RT. Finisher bonus only on contact.\nLegacy active melee / heavy bodies may resist flinch; damage and posture resolve separately." % [variant,Lab.VARIANTS[variant],fixture,arrival,lab_rules,model["whole_remaining"],model["cut_remaining"],str(state.player_facing),float(state.player_action.get("guard_remaining",0.0))]
	if inspected_enemy_id >= 0:
		var inspected: Dictionary = state._enemy_by_id(inspected_enemy_id)
		if not inspected.is_empty():
			var facts := CombatCatalogScript.presentation(String(inspected["kind"]))
			diagnostics.text += "\nInspected %s · %s · %s speed · %s reach · %s" % [facts["name"],_resistance_text(inspected),facts["speed"],facts["reach"],facts["trait"]]

func _resistance_text(enemy: Dictionary) -> String:
	var action := Dictionary(enemy.get("action",{}))
	if String(action.get("kind","")) in ["hit_reaction","stagger"]: return "Reeling · No flinch refresh"
	var resistance := state.enemy_hit_reaction_resistance(enemy,action)
	if resistance != "": return resistance
	var recovering := action.has("active_end") and float(action.get("elapsed",0.0)) > float(action["active_end"])
	return ("Recovering" if recovering else "Current phase") + " · Flinch allowed"

func _draw() -> void:
	lab_badge_rects.clear()
	super._draw()
	if state == null or not state.run_active: return
	var origin := _world_to_screen(state.player_pos)
	if state.lab_armed:
		var target: Dictionary = state._enemy_by_id(controller.target_id)
		if not target.is_empty() and state.lab_target_refusal(controller.target_id) == "":
			var point := _world_to_screen(target["pos"])
			draw_arc(point, 22, 0, TAU, 28, Color("f0cf77"),2)
			draw_dashed_line(origin,point,Color("f0cf77"),2,6)
			_draw_lab_arrow(origin,point,Color("f0cf77"))

	if state.lab_junction() or String(state.player_action.get("kind","")) == "combo":
		var end := _world_to_screen(state.player_pos + state.player_facing * 95)
		draw_line(origin,end,Color("b8e2ec"),3)
		_draw_lab_arrow(origin,end,Color("b8e2ec"))
	var queued: Dictionary = state.player_action.get("lab_exit_request",{})
	if not queued.is_empty():
		var end := _world_to_screen(state.player_pos + Vector2(queued["direction"]).normalized() * 140)
		draw_dashed_line(origin,end,Color("f0cf77"),2,7)
		_draw_lab_arrow(origin,end,Color("f0cf77"))
	draw_rect(enemy_readout_rect,Color("101b23"))
	for read in enemy_readout_model():
		var rect: Rect2 = read["rect"]
		draw_rect(rect,Color("101b23"))
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(8,15),read["lines"][0],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("eff3e8"))
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(8,32),read["lines"][1],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c3d9d6"))

func enemy_readout_model() -> Array:
	var result: Array = []
	for enemy in Array(visual.get("enemies",[])):
		if result.size() >= 3: break
		if int(enemy.get("hp",0)) <= 0: continue
		var pos := _world_to_screen(enemy["pos"])
		# No offscreen-threat completeness claim: identify unseen actors explicitly.
		var on_board := board_rect.has_point(pos)
		if not state.enemy_visible_to_player(enemy): continue
		var facts := CombatCatalogScript.presentation(String(enemy["kind"]))
		var action: Dictionary = enemy.get("action",{})
		var phase := _phase(action).capitalize()
		if phase == "": phase = String(action.get("kind","idle")).capitalize()
		var resistance := _resistance_text(enemy)
		var tag := _enemy_readout_tag(int(enemy["id"]))
		result.append({"id":int(enemy["id"]),"phase":phase,"resistance":resistance,"on_board":on_board,
			"rect":Rect2(enemy_readout_rect.position+Vector2(0,result.size()*38),Vector2(enemy_readout_rect.size.x,36)),
			"lines":["#%s %s · %s%s" % [tag,facts["name"],phase," · off view" if not on_board else ""],resistance]})
	return result

func _enemy_readout_tag(actor_id: int) -> String:
	# Stable short fixture-local key; removing a dead actor never renumbers peers.
	for index in range(state.enemies.size()):
		if int(state.enemies[index]["id"]) == actor_id: return str(index+1)
	return "?"

func _draw_actor_phase(_pos: Vector2, _radius: float, _phase_text: String, _player: bool) -> void:
	# Player phase belongs in the main panel; enemy phase in the readout strip.
	pass

func _direction_read(direction: Vector2) -> String:
	var screen := _screen_direction(direction)
	var angle := wrapf(screen.angle(),0,TAU)
	return ["Right →","Down-right ↘","Down ↓","Down-left ↙","Left ←","Up-left ↖","Up ↑","Up-right ↗"][int(round(angle/(PI/4)))%8]

func _draw_lab_arrow(start: Vector2, end: Vector2, color: Color) -> void:
	var backward := (start-end).normalized()
	draw_line(end,end+backward.rotated(0.5)*10,color,2)
	draw_line(end,end+backward.rotated(-0.5)*10,color,2)

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
	if state.player_action.has("lab_exit_request"):
		state.lab_notice = "Already queued: %s · Starts after recovery." % String(state.player_action["lab_exit_request"]["kind"]).capitalize()
		return
	if bool(state.player_action.get("lab_prepaid",false)):
		state.lab_notice = "Commit running · All remaining cuts locked."
		return
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

func _draw_attack_button() -> void:
	pass

# The native HUD puts gauges over the board. The lab reserves their own region.
func _draw_hud() -> void:
	for slot_id in consumable_rects: _draw_consumable(String(slot_id),Rect2(consumable_rects[slot_id]))
	for name in buttons: _draw_button(String(name),Rect2(buttons[name]))
	_draw_spell_row()
	_draw_button("wait",interaction_rect)
	if controller.active: controller.draw_hud(self)
	var rows := [["Health",float(state.player_hp),float(state.player_max_hp),Color("c14a5d")],["Energy",state.player_energy,state.player_max_energy,Color("26aebf")],["Posture",state.player_posture,state.player_posture_max,Color("759ab5")]]
	for index in range(rows.size()):
		var row: Array = rows[index]
		var rect := Rect2(hud_rect.position+Vector2(0,index*20),Vector2(hud_rect.size.x,17))
		draw_rect(rect,Color("0c161c"))
		draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(row[1]/maxf(1,row[2]),0,1),rect.size.y)),row[3])
		draw_rect(rect,Color("bdcfce"),false)
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(4,13),"%s %.0f / %.0f" % [row[0],row[1],row[2]],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	if hud_rect.size.y > 65:
		draw_string(ThemeDB.fallback_font,hud_rect.position+Vector2(0,78),"XP %d/%d · %s / %s" % [state.carried_xp,state.next_upgrade_cost(),variant,fixture],HORIZONTAL_ALIGNMENT_LEFT,hud_rect.size.x,12,Color("bdcfce"))

func _draw_reset_button() -> void:
	pass
func _draw_view_button() -> void:
	pass
func _draw_map_button() -> void:
	pass
func _draw_sheet_button() -> void:
	pass
func _draw_survey_end_button() -> void:
	pass
func _draw_inspection() -> void:
	# Phase/resistance use the reserved strip. Full traits and actual facing
	# remain in scrollable Review details, outside world telegraphs.
	if not detail_open: return

func _draw_world_header() -> void:
	pass

func _draw_enemy(enemy: Dictionary) -> void:
	# The native camera has a generous offscreen draw margin. A lab actor outside
	# its reserved board must not be painted under the action/ability panels.
	var pos := _world_to_screen(enemy["pos"])
	if not board_rect.has_point(pos): return
	super._draw_enemy(enemy)
	# Short identifier sits inside the actor silhouette rather than across its
	# facing, pips or contact geometry. Full name and facts live in the strip.
	var tag := _enemy_readout_tag(int(enemy["id"]))
	var width := ThemeDB.fallback_font.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	draw_rect(Rect2(pos-Vector2(width/2+2,9),Vector2(width+4,14)),Color("101b23"))
	draw_string(ThemeDB.fallback_font,pos+Vector2(-width/2,2),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
