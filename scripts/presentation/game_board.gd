extends Control

const RunStateScript = preload("res://scripts/core/run_state.gd")
const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const BG := Color("0d151b")
const FLOOR := Color("17272d")
const WALL := Color("344148")
const PLAYER_COLOR := Color("8fd178")
const BLADE_COLOR := Color("e46c63")
const ARCHER_COLOR := Color("c68be4")
const POLEARM_COLOR := Color("d08a48")
const DODGE_COLOR := Color("58d2cf")
const CAMERA_WORLD_WIDTH := 1050.0
const CAMERA_WORLD_HEIGHT := 1000.0

var state: RunState
var visual: Dictionary = {}
var timeline: Array[Dictionary] = []
var playback_index := 0
var playback_accumulator := 0.0
var playing := false
var touch_start := Vector2.ZERO
var touch_current := Vector2.ZERO
var pointer_down := false
var hold_elapsed := 0.0
var hold_consumed := false
var inspected_enemy_id := -1
var held_movement := false
var held_direction := Vector2.ZERO
var board_rect := Rect2()
var world_scale := 1.0
var board_area := Rect2()
var iso_origin := Vector2.ZERO
var view_mode := "top_down"
var selected_action := ""
var buttons: Dictionary = {}
var loadout_rects: Dictionary = {}
var upgrade_rects: Dictionary = {}
var reset_rect := Rect2()
var view_rect := Rect2()
var map_rect := Rect2()
var map_mode_rect := Rect2()
var seed_copy_rect := Rect2()
var start_rect := Rect2()
var progression_rects: Dictionary = {}
var map_open := false
var setup_loadout := "duelist"
var setup_mode := "expedition"
var waystone_menu_open := false
var seed_input: LineEdit
var setup_seed_error := ""

func _ready() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	Input.emulate_mouse_from_touch = false
	state = RunStateScript.new(false)
	state.load_run()
	_create_seed_input()
	setup_loadout = state.loadout_id
	setup_mode = state.mode_id
	visual = state.snapshot()
	state.changed.connect(_on_state_changed)
	resized.connect(_layout)
	_layout()
	call_deferred("_layout")
	_sync_setup_controls()

func _create_seed_input() -> void:
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "WORLD SEED — BLANK FOR RANDOM"
	seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_input.max_length = 19
	seed_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	seed_input.add_theme_font_size_override("font_size", 18)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("17272d")
	normal.border_color = Color("718087")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	var focused: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	focused.border_color = Color("58d2cf")
	seed_input.add_theme_stylebox_override("normal", normal)
	seed_input.add_theme_stylebox_override("focus", focused)
	seed_input.text_submitted.connect(_on_seed_submitted)
	add_child(seed_input)

func _on_seed_submitted(_text: String) -> void:
	if not state.run_active: _start_run()

func _sync_setup_controls() -> void:
	if seed_input != null: seed_input.visible = not state.run_active

func _layout() -> void:
	var portrait := size.y >= size.x
	board_area = Rect2(0, 0, size.x, size.y * 0.76) if portrait else Rect2(0, 0, size.x * 0.74, size.y)
	_update_projection()
	buttons.clear()
	loadout_rects.clear()
	upgrade_rects.clear()
	progression_rects.clear()
	var names := ["potion", "defense", "skill", "wait"]
	var loadouts := ["duelist", "guardian", "reaver"]
	if portrait:
		var hud_top := size.y * 0.77
		var gap := size.x * 0.025
		var tab_height := clampf(size.y * 0.038, 38.0, 58.0)
		var tab_width := (size.x - gap * 4.0) / 3.0
		for i in range(3):
			loadout_rects[loadouts[i]] = Rect2(gap + i * (tab_width + gap), hud_top, tab_width, tab_height)
		var top := hud_top + tab_height + gap * 0.55
		var width := (size.x - gap * 5.0) / 4.0
		for i in range(4):
			buttons[names[i]] = Rect2(gap + i * (width + gap), top, width, size.y - top - gap)
		var upgrade_width := (size.x - gap * 4.0) / 3.0
		for i in range(3): upgrade_rects[i] = Rect2(gap + i * (upgrade_width + gap), top, upgrade_width, size.y - top - gap)
	else:
		var left := size.x * 0.755
		var gap := size.y * 0.025
		var tab_height := (size.y * 0.22 - gap * 4.0) / 3.0
		for i in range(3):
			loadout_rects[loadouts[i]] = Rect2(left, gap + i * (tab_height + gap), size.x - left - gap, tab_height)
		var action_top := size.y * 0.25
		var height := (size.y - action_top - gap * 5.0) / 4.0
		for i in range(4):
			buttons[names[i]] = Rect2(left, action_top + gap + i * (height + gap), size.x - left - gap, height)
		var upgrade_height := (size.y - action_top - gap * 4.0) / 3.0
		for i in range(3): upgrade_rects[i] = Rect2(left, action_top + gap + i * (upgrade_height + gap), size.x - left - gap, upgrade_height)
	var reset_size := Vector2(clampf(size.x * 0.13, 68.0, 104.0), clampf(size.y * 0.035, 36.0, 52.0))
	reset_rect = Rect2(board_rect.end - reset_size - Vector2(8.0, board_rect.size.y - reset_size.y - 8.0), reset_size)
	view_rect = Rect2(reset_rect.position - Vector2(reset_size.x + 8.0, 0.0), reset_size)
	map_rect = Rect2(view_rect.position - Vector2(reset_size.x + 8.0, 0.0), reset_size)
	var setup_width := minf(size.x * 0.76, 640.0)
	var setup_left := (size.x - setup_width) * 0.5
	var setup_center_y := size.y * 0.52
	var setup_gap := clampf(minf(size.x, size.y) * 0.025, 12.0, 28.0)
	var option_width := (setup_width - setup_gap) * 0.5
	progression_rects["expedition"] = Rect2(setup_left, setup_center_y, option_width, 74.0)
	progression_rects["campaign_lab"] = Rect2(setup_left + option_width + setup_gap, setup_center_y, option_width, 74.0)
	seed_input.position = Vector2(setup_left, setup_center_y + 94.0)
	seed_input.size = Vector2(setup_width, 58.0)
	start_rect = Rect2(setup_left, setup_center_y + 168.0, setup_width, 78.0)
	map_mode_rect = _map_action_rect(1)
	seed_copy_rect = _map_action_rect(2)
	queue_redraw()

func _update_projection() -> void:
	world_scale = clampf(maxf(board_area.size.x / CAMERA_WORLD_WIDTH, board_area.size.y / CAMERA_WORLD_HEIGHT), 0.9, 2.0)
	board_rect = board_area
	iso_origin = Vector2.ZERO

func _process(delta: float) -> void:
	if playing:
		playback_accumulator += delta * 1.15
		while playback_accumulator >= state.FRAME_DT and playback_index < timeline.size() - 1:
			playback_accumulator -= state.FRAME_DT
			playback_index += 1
			visual = timeline[playback_index]
		if playback_index >= timeline.size() - 1:
			playing = false
			visual = state.snapshot()
	if not playing and held_movement and pointer_down and state.player_hp > 0:
		_commit(state.request_move(held_direction))
	if pointer_down and not playing and not held_movement and inspected_enemy_id < 0 and board_rect.has_point(touch_start):
		hold_elapsed += delta
		if hold_elapsed >= 0.46:
			var inspected := _enemy_near(touch_start, 68.0)
			if not inspected.is_empty():
				inspected_enemy_id = int(inspected["id"])
				hold_consumed = true
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: _pointer_pressed(event.position)
		else: _pointer_released(event.position)
	elif event is InputEventScreenDrag:
		_pointer_dragged(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _pointer_pressed(event.position)
		else: _pointer_released(event.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_pointer_dragged(event.position)

func _pointer_pressed(position: Vector2) -> void:
	if not state.run_active:
		for choice in ["duelist", "guardian", "reaver"]:
			if _setup_class_rect(choice).has_point(position):
				setup_loadout = choice
				queue_redraw()
				return
		for mode in progression_rects:
			if Rect2(progression_rects[mode]).has_point(position):
				setup_mode = String(mode)
				queue_redraw()
				return
		if start_rect.has_point(position): _start_run()
		return
	if map_open and _map_close_rect().has_point(position):
		map_open = false
		queue_redraw()
		return
	if not map_open and map_rect.has_point(position):
		if not playing:
			map_open = true
			state.map_presentation = "full"
		queue_redraw()
		return
	if map_open and state.map_presentation == "full":
		if map_mode_rect.has_point(position):
			state.map_presentation = "overlay"
			state.save_run()
			queue_redraw()
		elif seed_copy_rect.has_point(position):
			DisplayServer.clipboard_set(str(state.run_seed))
			state.message = "Seed %d copied." % state.run_seed
			queue_redraw()
		return
	if reset_rect.has_point(position):
		_restart()
		return
	if state.death_pending:
		state.return_after_death()
		waystone_menu_open = false
		visual = state.snapshot()
		_sync_setup_controls()
		queue_redraw()
		return
	if view_rect.has_point(position):
		if not playing: _toggle_view()
		return
	if waystone_menu_open:
		_handle_waystone_menu_press(position)
		return
	if state.upgrade_pending:
		if state.upgrade_context == "waystone" and _upgrade_leave_rect().has_point(position):
			state.leave_upgrade_menu()
			visual = state.snapshot()
			queue_redraw()
			return
		for index in upgrade_rects:
			if Rect2(upgrade_rects[index]).has_point(position) and int(index) < state.upgrade_choices.size():
				state.choose_upgrade(state.upgrade_choices[int(index)])
				visual = state.snapshot()
				queue_redraw()
				return
		return
	if playing or state.player_hp <= 0:
		return
	pointer_down = true
	held_movement = false
	hold_elapsed = 0.0
	hold_consumed = false
	inspected_enemy_id = -1
	touch_start = position
	touch_current = position

func _pointer_dragged(position: Vector2) -> void:
	if not pointer_down:
		return
	touch_current = position
	var drag := position - touch_start
	var threshold := maxf(22.0, minf(size.x, size.y) * 0.025)
	if drag.length() < threshold or selected_action != "" or not board_rect.has_point(touch_start):
		return
	inspected_enemy_id = -1
	if not _enemy_near(position, 62.0).is_empty():
		return
	held_direction = _screen_delta_to_world_direction(drag)
	if not held_movement:
		held_movement = true
		if not playing:
			_commit(state.request_move(held_direction))

func _pointer_released(position: Vector2) -> void:
	if not pointer_down:
		return
	pointer_down = false
	if hold_consumed:
		hold_consumed = false
		hold_elapsed = 0.0
		inspected_enemy_id = -1
		queue_redraw()
		return
	if held_movement:
		held_movement = false
		held_direction = Vector2.ZERO
		return
	_handle_gesture(position)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or playing: return
	if event.keycode == KEY_M and state.run_active:
		map_open = not map_open
		queue_redraw()
		return
	if event.keycode == KEY_ESCAPE and map_open:
		map_open = false
		queue_redraw()
		return
	if event.keycode == KEY_ESCAPE and waystone_menu_open:
		waystone_menu_open = false
		queue_redraw()
		return
	if (map_open and state.map_presentation == "full") or not state.run_active: return
	if state.death_pending:
		if event.keycode in [KEY_ENTER, KEY_SPACE]: state.return_after_death()
		return
	match event.keycode:
		KEY_W, KEY_UP: _commit_direction(Vector2.UP)
		KEY_S, KEY_DOWN: _commit_direction(Vector2.DOWN)
		KEY_A, KEY_LEFT: _commit_direction(Vector2.LEFT)
		KEY_D, KEY_RIGHT: _commit_direction(Vector2.RIGHT)
		KEY_SPACE: _advance_or_wait()
		KEY_SHIFT, KEY_B: selected_action = "defense"
		KEY_Q: selected_action = "skill"
		KEY_R: _restart()

func _handle_gesture(end_position: Vector2) -> void:
	if state.player_hp <= 0:
		_restart()
		return
	for name in buttons:
		if Rect2(buttons[name]).has_point(end_position):
			_handle_button(String(name))
			return
	if not board_rect.has_point(end_position): return
	var drag := end_position - touch_start
	var threshold := maxf(22.0, minf(size.x, size.y) * 0.025)
	if drag.length() >= threshold:
		if selected_action in ["defense", "skill"]:
			var action := selected_action
			selected_action = ""
			var world_direction := _screen_delta_to_world_direction(drag)
			_commit(state.request_defense(world_direction) if action == "defense" else state.request_skill(world_direction))
		else:
			var enemy := _enemy_near(end_position, 62.0)
			if enemy.is_empty(): _commit(state.request_move(_screen_delta_to_world_direction(drag)))
			else: _commit(state.request_attack(Vector2(enemy["pos"])))
		return
	var enemy := _enemy_near(end_position, 54.0)
	if not enemy.is_empty():
		if selected_action == "skill":
			selected_action = ""
			_commit(state.request_skill(Vector2(enemy["pos"]) - state.player_pos))
		else: _commit(state.request_attack(Vector2(enemy["pos"])))
	elif selected_action == "defense":
		selected_action = ""
		var direction := _screen_to_world(end_position) - state.player_pos
		_commit(state.request_defense(direction))
	elif selected_action == "skill":
		selected_action = ""
		_commit(state.request_skill(_screen_to_world(end_position) - state.player_pos))
	else:
		_commit(state.request_move_to(_screen_to_world(end_position)))

func _handle_button(name: String) -> void:
	match name:
		"potion": _commit(state.request_potion())
		"defense":
			if _defense_cooldown() <= 0.0001:
				if state.defense_id == "endure": _commit(state.request_endure(state.player_facing))
				else: selected_action = "" if selected_action == "defense" else "defense"
		"skill":
			if state.loadout_id == "duelist" and state.skill_cooldown <= 0.0001:
				selected_action = "" if selected_action == "skill" else "skill"
		"wait":
			_advance_or_wait()
	queue_redraw()

func _commit_direction(direction: Vector2) -> void:
	if selected_action == "defense":
		selected_action = ""
		_commit(state.request_defense(direction))
	elif selected_action == "skill":
		selected_action = ""
		_commit(state.request_skill(direction))
	else: _commit(state.request_move(direction))

func _commit(did_commit: bool) -> void:
	if not did_commit:
		queue_redraw()
		return
	timeline = state.last_timeline.duplicate(true)
	playback_index = 0
	playback_accumulator = 0.0
	visual = timeline[0]
	playing = timeline.size() > 1
	queue_redraw()

func _restart() -> void:
	state.abandon_run()
	state.save_run()
	selected_action = ""
	playing = false
	pointer_down = false
	held_movement = false
	held_direction = Vector2.ZERO
	waystone_menu_open = false
	timeline.clear()
	visual = state.snapshot()
	_sync_setup_controls()
	queue_redraw()

func _start_run() -> void:
	var entered_seed := seed_input.text.strip_edges()
	var chosen_seed := -1
	if entered_seed != "":
		if not entered_seed.is_valid_int() or entered_seed.begins_with("-"):
			setup_seed_error = "Enter a positive whole number, or leave this blank."
			queue_redraw()
			return
		chosen_seed = int(entered_seed)
	setup_seed_error = ""
	seed_input.release_focus()
	state.start_run(setup_loadout, setup_mode, chosen_seed)
	map_open = false
	waystone_menu_open = false
	selected_action = ""
	timeline.clear()
	visual = state.snapshot()
	state.save_run()
	_sync_setup_controls()
	queue_redraw()

func _select_loadout(choice: String) -> void:
	state.select_loadout(choice)
	selected_action = ""
	playing = false
	pointer_down = false
	held_movement = false
	held_direction = Vector2.ZERO
	timeline.clear()
	visual = state.snapshot()
	queue_redraw()

func _advance_or_wait() -> void:
	var interaction := state.interaction_label()
	if interaction == "WAYSTONE":
		waystone_menu_open = true
		selected_action = ""
		queue_redraw()
	elif interaction == "WAIT": _commit(state.request_wait())
	else:
		state.request_context_action()
		visual = state.snapshot()
		queue_redraw()

func _handle_waystone_menu_press(position: Vector2) -> void:
	var actions := {"potion": "rest", "defense": "learn", "skill": "anchor", "wait": "leave"}
	for button_name in actions:
		if not Rect2(buttons[button_name]).has_point(position): continue
		match String(actions[button_name]):
			"rest": state.rest_at_waystone()
			"learn":
				if state.learn_at_waystone(): waystone_menu_open = false
			"anchor": state.anchor_at_waystone()
			"leave": waystone_menu_open = false
		visual = state.snapshot()
		queue_redraw()
		return

func _defense_cooldown() -> float:
	if state.defense_id == "block": return state.block_cooldown
	if state.defense_id == "endure": return state.endure_cooldown
	return state.dodge_cooldown

func _on_state_changed() -> void:
	state.save_run()
	_sync_setup_controls()
	if not playing:
		visual = state.snapshot()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if not state.run_active:
		_draw_setup()
		return
	_draw_world()
	_draw_hud()
	if inspected_enemy_id >= 0: _draw_inspection()
	if state.trial_complete: _draw_results()
	_draw_reset_button()
	_draw_view_button()
	_draw_map_button()
	if map_open: _draw_map()
	if state.death_pending: _draw_death_overlay()

func _draw_world() -> void:
	draw_rect(board_rect, Color("05080a"))
	_draw_discovered_floor()
	_draw_grid()
	var discovered: Dictionary = visual.get("discovered_cells", state.discovered_cells)
	var visible: Dictionary = visual.get("visible_cells", state.visible_cells)
	for wall in state.walls:
		if state.is_discovered(wall.get_center(), discovered): _draw_wall(wall)
	_draw_landmarks(visible, discovered)
	for projectile in Array(visual.get("projectiles", [])):
		if not state.is_visible(Vector2(projectile["pos"]), visible): continue
		var center := _world_to_screen(Vector2(projectile["pos"]))
		var direction := _screen_direction(Vector2(projectile["vel"]).normalized())
		draw_line(center - direction * 15.0, center + direction * 9.0, Color("f1ce72"), maxf(2.0, world_scale * 8.0))
	for hazard in Array(visual.get("hazards", [])):
		if state.is_visible(Vector2(hazard["pos"]), visible): _draw_hazard(hazard)
	if view_mode == "isometric":
		var actors: Array[Dictionary] = []
		for enemy in Array(visual.get("enemies", [])):
			if not state.is_visible(Vector2(enemy["pos"]), visible): continue
			var entry: Dictionary = enemy.duplicate()
			entry["_player"] = false
			actors.append(entry)
		actors.append({"_player": true, "pos": Vector2(visual.get("player_pos", state.player_pos))})
		actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _world_to_screen(Vector2(a["pos"])).y < _world_to_screen(Vector2(b["pos"])).y)
		for actor in actors:
			if bool(actor["_player"]): _draw_player()
			else: _draw_enemy(actor)
	else:
		for enemy in Array(visual.get("enemies", [])):
			if state.is_visible(Vector2(enemy["pos"]), visible): _draw_enemy(enemy)
		_draw_player()
	for effect in Array(visual.get("effects", [])):
		if state.is_visible(Vector2(effect["pos"]), visible): _draw_effect(effect)
	_draw_player_damage_overlay()
	_draw_selected_action_hint()
	var label := "TIME FLOWING" if playing else "TIME FROZEN"
	var color := Color("f0b45a") if playing else DODGE_COLOR
	var font := maxi(14, int(minf(size.x, size.y) * 0.026))
	draw_string(ThemeDB.fallback_font, board_rect.position + Vector2(12, font + 10), label, HORIZONTAL_ALIGNMENT_LEFT, board_rect.size.x * 0.5, font, color)
	var area_text := "AREA %d  •  %d XP" % [int(visual.get("current_area_id", state.current_area_id)) + 1, int(visual.get("carried_xp", state.carried_xp))]
	var area_width := minf(board_rect.size.x * 0.34, 180.0)
	var area_x := board_rect.position.x + (board_rect.size.x - area_width) * 0.5
	draw_string(ThemeDB.fallback_font, Vector2(area_x, board_rect.position.y + font + 10), area_text, HORIZONTAL_ALIGNMENT_CENTER, area_width, font, Color("9fb2b7"))
	_draw_player_health_bar(font)

func _draw_grid() -> void:
	var color := Color(0.18, 0.29, 0.32, 0.35)
	var visible: Dictionary = visual.get("visible_cells", state.visible_cells)
	for cell in visible:
		var top_left := Vector2(cell) * state.VISIBILITY_CELL
		var center := top_left + Vector2.ONE * state.VISIBILITY_CELL * 0.5
		if int(cell.x) % 2 == 0: draw_line(_world_to_screen(Vector2(top_left.x, top_left.y)), _world_to_screen(Vector2(top_left.x, top_left.y + state.VISIBILITY_CELL)), color)
		if int(cell.y) % 2 == 0: draw_line(_world_to_screen(Vector2(top_left.x, top_left.y)), _world_to_screen(Vector2(top_left.x + state.VISIBILITY_CELL, top_left.y)), color)

func _draw_discovered_floor() -> void:
	var discovered: Dictionary = visual.get("discovered_cells", state.discovered_cells)
	var visible: Dictionary = visual.get("visible_cells", state.visible_cells)
	for cell in discovered:
		var top_left := Vector2(cell) * state.VISIBILITY_CELL
		var is_current := visible.has(cell)
		var color := FLOOR if is_current else Color("0c1418")
		if view_mode == "top_down":
			draw_rect(Rect2(_world_to_screen(top_left), Vector2.ONE * state.VISIBILITY_CELL * world_scale + Vector2.ONE), color)
		else:
			var points := PackedVector2Array([_world_to_screen(top_left), _world_to_screen(top_left + Vector2(state.VISIBILITY_CELL, 0)), _world_to_screen(top_left + Vector2.ONE * state.VISIBILITY_CELL), _world_to_screen(top_left + Vector2(0, state.VISIBILITY_CELL))])
			draw_colored_polygon(points, color)

func _draw_wall(wall: Rect2) -> void:
	if view_mode == "top_down":
		var rect := Rect2(_world_to_screen(wall.position), wall.size * world_scale)
		draw_rect(rect, WALL)
		draw_rect(rect.grow(-3.0), Color("29363c"), false, 2.0)
		return
	var top := PackedVector2Array([_world_to_screen(wall.position), _world_to_screen(Vector2(wall.end.x, wall.position.y)), _world_to_screen(wall.end), _world_to_screen(Vector2(wall.position.x, wall.end.y))])
	var height := maxf(10.0, 44.0 * world_scale)
	var drop := Vector2(0, height)
	draw_colored_polygon(PackedVector2Array([top[2], top[3], top[3] + drop, top[2] + drop]), Color("26343a"))
	draw_colored_polygon(PackedVector2Array([top[1], top[2], top[2] + drop, top[1] + drop]), Color("2d3b42"))
	draw_colored_polygon(top, WALL)
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), Color("59666b"), 1.5)

func _draw_player() -> void:
	var world_pos := Vector2(visual.get("player_pos", state.player_pos))
	var pos := _world_to_screen(world_pos)
	var facing := _screen_direction(Vector2(visual.get("player_facing", Vector2.UP)).normalized())
	var action: Dictionary = visual.get("player_action", {})
	var radius := state.PLAYER_RADIUS * world_scale
	if float(visual.get("strength_remaining", 0.0)) > 0.0:
		draw_circle(pos, radius * 1.65, Color(0.91, 0.32, 0.20, 0.16))
		draw_arc(pos, radius * 1.65, 0.0, TAU, 24, Color("e85c3f"), maxf(2.0, radius * 0.12))
	if String(action.get("kind", "idle")) == "dodge": draw_circle(pos - facing * radius * 0.7, radius * 1.25, Color(DODGE_COLOR, 0.16))
	_draw_actor(pos, facing, radius, PLAYER_COLOR)
	if String(action.get("kind", "idle")) in ["attack", "sweep"]: _draw_weapon(world_pos, action, true)
	elif String(action.get("kind", "idle")) == "block": _draw_guard(pos, facing, radius, action)
	elif String(action.get("kind", "idle")) == "endure": _draw_endure(pos, radius, action)
	elif String(action.get("kind", "idle")) == "potion": draw_circle(pos + Vector2(radius * 0.7, -radius * 0.8), radius * 0.25, Color("e35f62"))
	var phase := _phase(action)
	if phase != "": draw_string(ThemeDB.fallback_font, pos + Vector2(-radius * 2.2, -radius * 2.05), phase, HORIZONTAL_ALIGNMENT_CENTER, radius * 4.4, maxi(9, int(radius * 0.55)), Color("d8f4f1"))

func _draw_enemy(enemy: Dictionary) -> void:
	var world_pos := Vector2(enemy["pos"])
	var pos := _world_to_screen(world_pos)
	var facing := _screen_direction(Vector2(enemy["facing"]).normalized())
	var radius := float(enemy["radius"]) * world_scale
	var kind := String(enemy["kind"])
	var colors := {"knife": Color("e5be55"), "blade": BLADE_COLOR, "polearm": POLEARM_COLOR, "archer": ARCHER_COLOR, "shield": Color("6aa9c9"), "hound": Color("d9a75b"), "brute": Color("9f554d"), "hexer": Color("9e72d8"), "captain": Color("e0c24e"), "warden": Color("d84b65")}
	var color: Color = colors.get(kind, BLADE_COLOR)
	if kind == "captain": draw_arc(pos, radius * 1.5, 0.0, TAU, 20, Color(color, 0.45), maxf(2.0, radius * 0.12))
	_draw_actor(pos, facing, radius, color)
	_draw_enemy_identity(kind, pos, facing, radius, color)
	if kind == "shield": _draw_guard(pos, facing, radius, {"elapsed": 0.5, "startup": 0.0, "active_end": 1.0})
	var action: Dictionary = enemy["action"]
	if String(action["kind"]) == "melee": _draw_weapon(world_pos, action, false)
	elif String(action["kind"]) == "shoot": _draw_bow(pos, facing, radius, action)
	elif String(action["kind"]) == "charge": draw_line(pos, pos - facing * radius * 2.2, Color(color, 0.5), maxf(3.0, radius * 0.25))
	elif String(action["kind"]) == "slam": draw_arc(pos, float(action.get("reach", 205.0)) * world_scale, 0.0, TAU, 28, Color(color, 0.45), maxf(3.0, radius * 0.13))
	elif String(action["kind"]) == "hex": draw_circle(_world_to_screen(Vector2(action.get("target", enemy["pos"]))), 12.0, Color("b57bea"))
	var awareness := String(enemy.get("awareness", "idle"))
	if awareness in ["suspicious", "alerted"]:
		var marker := "?" if awareness == "suspicious" else "!"
		var marker_color := Color("e8c35d") if awareness == "suspicious" else Color("ef665c")
		draw_string(ThemeDB.fallback_font, pos + Vector2(-radius, -radius * 2.5), marker, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, maxi(16, int(radius * 0.8)), marker_color)
	_draw_health(pos, radius, int(enemy["hp"]), int(enemy["max_hp"]), color)
	_draw_posture(pos, radius, float(enemy.get("posture", 1.0)), float(enemy.get("posture_max", 1.0)))
	var phase := _phase(action)
	if phase != "": draw_string(ThemeDB.fallback_font, pos + Vector2(-radius * 2.2, radius * 2.1), phase, HORIZONTAL_ALIGNMENT_CENTER, radius * 4.4, maxi(9, int(radius * 0.55)), Color("d8ddd8"))

func _draw_actor(pos: Vector2, facing: Vector2, radius: float, color: Color) -> void:
	var side := facing.rotated(PI * 0.5)
	var points := PackedVector2Array([pos + facing * radius * 1.2, pos - facing * radius * 0.75 + side * radius * 0.82, pos - facing * radius * 0.75 - side * radius * 0.82])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), color.lightened(0.32), 2.0)

func _draw_enemy_identity(kind: String, pos: Vector2, facing: Vector2, radius: float, color: Color) -> void:
	var side := facing.rotated(PI * 0.5)
	if kind == "knife":
		draw_line(pos + side * radius * 0.45, pos + side * radius * 0.75 + facing * radius * 1.05, Color("f3e5aa"), 2.0)
		draw_line(pos - side * radius * 0.45, pos - side * radius * 0.75 + facing * radius * 1.05, Color("f3e5aa"), 2.0)
	elif kind == "hound":
		draw_line(pos - facing * radius * 0.9, pos + facing * radius * 0.75, color.lightened(0.35), maxf(3.0, radius * 0.35))
	elif kind == "polearm":
		draw_line(pos - facing * radius * 0.8, pos + facing * radius * 1.9, Color("e7c590"), maxf(2.0, radius * 0.10))
	elif kind == "brute":
		draw_arc(pos, radius * 1.15, 0.0, TAU, 18, color.lightened(0.28), maxf(3.0, radius * 0.16))
	elif kind == "hexer":
		draw_line(pos + side * radius * 0.65, pos + side * radius * 0.65 + facing * radius * 1.45, Color("d7a5ef"), maxf(2.0, radius * 0.12))
		draw_circle(pos + side * radius * 0.65 + facing * radius * 1.45, radius * 0.18, Color("c78cec"))
	elif kind == "captain":
		draw_polyline(PackedVector2Array([pos - side * radius * 0.55 - facing * radius * 0.5, pos - side * radius * 0.55 + facing * radius * 0.2, pos - side * radius * 0.1 - facing * radius * 0.05]), Color("ffe277"), 2.0)
	elif kind == "warden":
		draw_polyline(PackedVector2Array([pos - side * radius * 0.55 - facing * radius * 0.45, pos - side * radius * 0.25 - facing * radius * 0.85, pos - facing * radius * 0.5, pos + side * radius * 0.25 - facing * radius * 0.85, pos + side * radius * 0.55 - facing * radius * 0.45]), Color("f1c25e"), maxf(2.0, radius * 0.09))

func _draw_weapon(world_pos: Vector2, action: Dictionary, player_weapon: bool) -> void:
	var facing := Vector2(action.get("direction", Vector2.UP)).normalized()
	var sample: Dictionary = AttackGeometryScript.pose(action, world_pos, facing, state.walls)
	var technique := String(sample.get("technique_id", "diagonal_cut"))
	var weapon_start := _world_to_screen(Vector2(sample["weapon_start"]))
	var weapon_end := _world_to_screen(Vector2(sample["weapon_end"]))
	var screen_direction := (weapon_end - weapon_start).normalized()
	var side := screen_direction.rotated(PI * 0.5)
	var active := bool(sample.get("active", false))
	var color := Color("fff1b8") if player_weapon else Color("ead9c8")
	var width := maxf(2.0, world_scale * (4.0 if technique in ["heavy_chop", "heavy_cleave", "forward_smash"] else 2.7))
	if technique == "bite":
		var jaw := maxf(8.0, float(sample.get("head_radius", 20.0)) * world_scale * 0.55)
		draw_line(weapon_end - screen_direction * jaw + side * jaw * 0.55, weapon_end + screen_direction * jaw * 0.35, color, width)
		draw_line(weapon_end - screen_direction * jaw - side * jaw * 0.55, weapon_end + screen_direction * jaw * 0.35, color, width)
		return
	draw_line(weapon_start, weapon_end, color, width)
	if technique == "thrust":
		var tip := maxf(5.0, world_scale * 8.0)
		draw_colored_polygon(PackedVector2Array([weapon_end + screen_direction * tip, weapon_end - screen_direction * tip * 0.65 + side * tip * 0.55, weapon_end - screen_direction * tip * 0.65 - side * tip * 0.55]), color)
	elif technique == "forward_smash":
		var head := maxf(9.0, float(sample.get("head_radius", 30.0)) * world_scale)
		draw_circle(weapon_end, head, Color(color, 0.92))
		draw_arc(weapon_end, head, 0.0, TAU, 16, color.lightened(0.2), maxf(2.0, width * 0.5))
	elif technique in ["heavy_chop", "heavy_cleave"]:
		draw_line(weapon_end - screen_direction * maxf(12.0, world_scale * 20.0), weapon_end, color.lightened(0.16), width * 1.8)
	if active: draw_circle(weapon_end, maxf(2.0, width * 0.55), Color(color, 0.75))

func _draw_guard(pos: Vector2, facing: Vector2, radius: float, action: Dictionary) -> void:
	var elapsed := float(action.get("elapsed", 0.0))
	var active := elapsed >= float(action.get("startup", 0.16)) and elapsed <= float(action.get("active_end", 0.78))
	var color := Color("6ec4e8") if active else Color("718990")
	draw_arc(pos, radius * 1.45, facing.angle() - 1.0, facing.angle() + 1.0, 18, color, maxf(3.0, radius * 0.20))

func _draw_endure(pos: Vector2, radius: float, action: Dictionary) -> void:
	var elapsed := float(action.get("elapsed", 0.0))
	var active := elapsed >= float(action.get("startup", 0.14)) and elapsed <= float(action.get("active_end", 0.72))
	var color := Color("ee6645") if active else Color("8f5d52")
	draw_arc(pos, radius * 1.48, 0.0, TAU, 22, color, maxf(3.0, radius * 0.18))

func _draw_effect(effect: Dictionary) -> void:
	var center := _world_to_screen(Vector2(effect["pos"]))
	var progress := clampf(float(effect["elapsed"]) / float(effect["duration"]), 0.0, 1.0)
	var kind := String(effect["kind"])
	var color := Color("f3d46a")
	if kind == "hurt": color = Color("ef5d61")
	elif kind in ["perfect", "evade"]: color = DODGE_COLOR
	elif kind == "block": color = Color("6ec4e8")
	elif kind == "endure": color = Color("ee6645")
	elif kind in ["hex", "slam"]: color = Color("b57bea") if kind == "hex" else Color("e15c54")
	elif kind in ["miss", "glance"]: color = Color("a9b1b2")
	var radius := lerpf(10.0, 46.0, progress)
	var alpha := 1.0 - progress
	if kind in ["hit", "hurt", "endure"]:
		draw_circle(center, lerpf(22.0, 10.0, progress), Color(color, alpha * 0.45))
		for index in range(8):
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
			draw_line(center + direction * radius * 0.35, center + direction * radius, Color(color, alpha), maxf(2.0, 6.0 * alpha))
		var amount := int(effect.get("amount", 0))
		if amount > 0:
			var text_pos := center + Vector2(-36.0, -34.0 - progress * 30.0)
			draw_string(ThemeDB.fallback_font, text_pos, "-%d" % amount, HORIZONTAL_ALIGNMENT_CENTER, 72.0, maxi(18, int(22.0 * world_scale)), Color(color, alpha))
	draw_arc(center, radius, 0.0, TAU, 18, Color(color, alpha), maxf(2.0, 5.0 * alpha))

func _draw_player_damage_overlay() -> void:
	var intensity := 0.0
	for effect in Array(visual.get("effects", [])):
		if String(effect.get("kind", "")) == "hurt":
			intensity = maxf(intensity, 1.0 - clampf(float(effect["elapsed"]) / float(effect["duration"]), 0.0, 1.0))
	if intensity <= 0.0: return
	draw_rect(board_rect, Color(0.82, 0.08, 0.09, intensity * 0.10))
	draw_rect(board_rect.grow(-4.0), Color(0.95, 0.18, 0.18, intensity * 0.72), false, maxf(4.0, 10.0 * intensity))

func _draw_player_health_bar(header_font: int) -> void:
	var hp := int(visual.get("player_hp", state.player_hp))
	var maximum := maxi(1, int(visual.get("player_max_hp", state.player_max_hp)))
	var ratio := clampf(float(hp) / float(maximum), 0.0, 1.0)
	var width := minf(board_rect.size.x * 0.50, 340.0)
	var height := clampf(board_rect.size.y * 0.016, 15.0, 24.0)
	var bar := Rect2(Vector2(board_rect.get_center().x - width * 0.5, board_rect.position.y + header_font + 34.0), Vector2(width, height))
	draw_rect(bar.grow(4.0), Color(0.03, 0.05, 0.06, 0.94))
	draw_rect(bar, Color("35191c"))
	var health_color := Color("69c86f") if ratio > 0.5 else Color("e2ad4c") if ratio > 0.25 else Color("e55458")
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), health_color)
	draw_rect(bar, Color("d8ddd8"), false, 2.0)
	var label_font := maxi(12, int(height * 0.72))
	draw_string(ThemeDB.fallback_font, bar.position + Vector2(0.0, height * 0.77), "HP  %d / %d" % [hp, maximum], HORIZONTAL_ALIGNMENT_CENTER, width, label_font, Color("f4f2e9"))

func _draw_hazard(hazard: Dictionary) -> void:
	var center := _world_to_screen(Vector2(hazard["pos"]))
	var radius := float(hazard["radius"]) * world_scale
	var elapsed := float(hazard["elapsed"])
	var trigger_at := float(hazard["trigger_at"])
	var progress := clampf(elapsed / trigger_at, 0.0, 1.0)
	if view_mode == "top_down":
		draw_circle(center, radius, Color(0.55, 0.25, 0.70, 0.08 + progress * 0.12))
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 28, Color("b57bea"), maxf(2.0, world_scale * 10.0))
	else:
		var ring := _world_ring(Vector2(hazard["pos"]), float(hazard["radius"]), 32)
		draw_colored_polygon(ring, Color(0.55, 0.25, 0.70, 0.08 + progress * 0.12))
		draw_polyline(PackedVector2Array(Array(ring) + [ring[0]]), Color("b57bea"), maxf(2.0, world_scale * 10.0))

func _draw_selected_action_hint() -> void:
	if selected_action == "": return
	var center := Vector2(visual.get("player_pos", state.player_pos))
	var facing := Vector2(visual.get("player_facing", state.player_facing)).normalized()
	if selected_action == "skill":
		var screen_center := _world_to_screen(center)
		var direction := _screen_direction(facing)
		draw_line(screen_center, screen_center + direction * 62.0 * world_scale, Color("e8c35d"), maxf(2.0, world_scale * 5.0))
	elif selected_action == "defense":
		var screen_center := _world_to_screen(center)
		var direction := _screen_direction(facing)
		draw_line(screen_center, screen_center + direction * 85.0 * world_scale, DODGE_COLOR, maxf(2.0, world_scale * 8.0))

func _world_ring(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments): points.append(_world_to_screen(center + Vector2.RIGHT.rotated(TAU * float(index) / float(segments)) * radius))
	return points

func _draw_bow(pos: Vector2, facing: Vector2, radius: float, action: Dictionary) -> void:
	var side := facing.rotated(PI * 0.5)
	var draw_amount := clampf(float(action["elapsed"]) / float(action.get("startup", 0.72)), 0.0, 1.0)
	var center := pos + facing * radius * 0.8
	draw_arc(center, radius * 0.75, facing.angle() - 1.2, facing.angle() + 1.2, 12, Color("e9cf91"), 2.0)
	draw_line(center + side * radius * 0.7, center - facing * radius * draw_amount, Color("d8d2c3"), 1.5)
	draw_line(center - side * radius * 0.7, center - facing * radius * draw_amount, Color("d8d2c3"), 1.5)

func _draw_health(pos: Vector2, radius: float, hp: int, max_hp: int, color: Color) -> void:
	var bar := Rect2(pos + Vector2(-radius, -radius * 1.75), Vector2(radius * 2.0, maxf(3.0, radius * 0.18)))
	draw_rect(bar, Color("101519"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(hp) / float(max_hp), bar.size.y)), color)

func _draw_posture(pos: Vector2, radius: float, posture: float, maximum: float) -> void:
	if posture >= maximum - 0.01: return
	var ratio := clampf(posture / maxf(0.01, maximum), 0.0, 1.0)
	var bar := Rect2(pos + Vector2(-radius, -radius * 2.05), Vector2(radius * 2.0, maxf(2.0, radius * 0.11)))
	draw_rect(bar, Color("101519"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color("f0c75e") if ratio > 0.34 else Color("ef765f"))

func _phase(action: Dictionary) -> String:
	var kind := String(action.get("kind", "idle"))
	var elapsed := float(action.get("elapsed", 0.0))
	if kind == "attack":
		if elapsed < float(action["startup"]): return "WINDING UP"
		if elapsed < float(action["active_end"]): return "STRIKING"
		return "RECOVERING"
	if kind == "sweep":
		if elapsed < float(action["startup"]): return "DRAWING BACK"
		if elapsed < float(action["active_end"]): return "SWEEPING"
		return "RECOVERING"
	if kind == "block":
		if elapsed < float(action["startup"]): return "RAISING GUARD"
		if elapsed < float(action["active_end"]): return "GUARDING"
		return "RECOVERING"
	if kind == "endure":
		if elapsed < float(action["startup"]): return "BRACING"
		if elapsed < float(action["active_end"]): return "ENDURING"
		return "RECOVERING"
	if kind == "melee":
		if elapsed < float(action["startup"]): return "WINDING UP"
		if elapsed < float(action["active_end"]): return "STRIKING"
		return "RECOVERING"
	if kind == "shoot": return "DRAWING" if elapsed < float(action.get("startup", 0.72)) else "RECOVERING"
	if kind == "charge":
		if elapsed < float(action.get("startup", 0.4)): return "CROUCHING"
		if elapsed < float(action.get("active_end", 0.8)): return "CHARGING"
		return "RECOVERING"
	if kind == "hex": return "CHANNELING" if elapsed < float(action.get("startup", 0.68)) else "RECOVERING"
	if kind == "slam": return "RAISING" if elapsed < float(action.get("startup", 1.0)) else "RECOVERING"
	if kind == "stagger": return "STAGGERED"
	if kind == "move": return "MOVING"
	return ""

func _draw_hud() -> void:
	if state.upgrade_pending: _draw_upgrade_choices()
	elif waystone_menu_open: _draw_waystone_menu()
	else:
		for name in buttons: _draw_button(String(name), Rect2(buttons[name]))
	var font := maxi(11, int(minf(size.x, size.y) * 0.022))
	var hp_text := "HP %d/%d  •  XP %d/%d" % [int(visual.get("player_hp", state.player_hp)), int(visual.get("player_max_hp", state.player_max_hp)), int(visual.get("carried_xp", state.carried_xp)), state.next_upgrade_cost()]
	hp_text += "  •  %s" % state.mode_label().to_upper()
	if float(visual.get("strength_remaining", 0.0)) > 0.0:
		hp_text += "  STR ACTIVE"
	var text := String(visual.get("message", state.message))
	var y := board_rect.end.y - font * 0.7
	if size.y >= size.x:
		draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x + 10, y), hp_text, HORIZONTAL_ALIGNMENT_LEFT, board_rect.size.x * 0.25, font, Color("f0ddd7"))
		draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x + board_rect.size.x * 0.26, y), text, HORIZONTAL_ALIGNMENT_LEFT, board_rect.size.x * 0.7, font, Color("d9ded8"))
	else:
		var left := board_rect.end.x + 10.0
		draw_string(ThemeDB.fallback_font, Vector2(left, size.y - font * 2.5), hp_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - left - 8.0, font, Color("f0ddd7"))
		draw_string(ThemeDB.fallback_font, Vector2(left, size.y - font * 1.1), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - left - 8.0, font, Color("d9ded8"))
	if held_movement and pointer_down:
		draw_line(touch_start, touch_current, Color(DODGE_COLOR, 0.55), 4.0)
		draw_circle(touch_current, 8.0, DODGE_COLOR)

func _draw_reset_button() -> void:
	draw_rect(reset_rect, Color(0.06, 0.09, 0.11, 0.86))
	draw_rect(reset_rect, Color("718087"), false, 1.5)
	var font := maxi(9, int(reset_rect.size.y * 0.30))
	draw_string(ThemeDB.fallback_font, reset_rect.position + Vector2(0.0, reset_rect.size.y * 0.61), "RESET", HORIZONTAL_ALIGNMENT_CENTER, reset_rect.size.x, font, Color("b7c0c2"))

func _draw_map_button() -> void:
	draw_rect(map_rect, Color(0.06, 0.09, 0.11, 0.86))
	draw_rect(map_rect, Color("d7aa58") if map_open else Color("718087"), false, 1.5)
	var font := maxi(8, int(map_rect.size.y * 0.27))
	draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(0.0, map_rect.size.y * 0.61), "MAP", HORIZONTAL_ALIGNMENT_CENTER, map_rect.size.x, font, Color("d7dddd"))

func _draw_view_button() -> void:
	draw_rect(view_rect, Color(0.06, 0.09, 0.11, 0.86))
	draw_rect(view_rect, DODGE_COLOR if view_mode == "isometric" else Color("718087"), false, 1.5)
	var font := maxi(8, int(view_rect.size.y * 0.27))
	var label := "TOP" if view_mode == "isometric" else "ISO"
	draw_string(ThemeDB.fallback_font, view_rect.position + Vector2(0.0, view_rect.size.y * 0.61), label, HORIZONTAL_ALIGNMENT_CENTER, view_rect.size.x, font, Color("d7dddd"))

func _draw_landmarks(visible: Dictionary, discovered: Dictionary) -> void:
	if state.is_discovered(state.bonfire_pos, discovered):
		var bonfire := _world_to_screen(state.bonfire_pos)
		var bright := state.is_visible(state.bonfire_pos, visible)
		draw_circle(bonfire, 25.0 * world_scale, Color("e89145") if bright else Color("62452f"))
		draw_circle(bonfire + Vector2(0, -12.0 * world_scale), 13.0 * world_scale, Color("f4d36b") if bright else Color("695b3c"))
	if state.is_discovered(state.shortcut_gate.get_center(), discovered):
		var gate := _world_to_screen(state.shortcut_gate.get_center())
		draw_circle(gate, 15.0 * world_scale, Color("65c5b5") if state.shortcut_unlocked else Color("bb5960"))
	if bool(state.lost_xp.get("active", false)) and state.is_discovered(Vector2(state.lost_xp["pos"]), discovered):
		var mark := _world_to_screen(Vector2(state.lost_xp["pos"]))
		draw_circle(mark, 24.0 * world_scale, Color(0.78, 0.90, 0.42, 0.22))
		draw_arc(mark, 20.0 * world_scale, 0.0, TAU, 20, Color("d8ed78"), maxf(3.0, world_scale * 4.0))
		draw_string(ThemeDB.fallback_font, mark + Vector2(-32, -30), "%d XP" % int(state.lost_xp.get("amount", 0)), HORIZONTAL_ALIGNMENT_CENTER, 64, maxi(10, int(13 * world_scale)), Color("e9f4b1"))

func _draw_setup() -> void:
	var title_font := maxi(28, int(minf(size.x, size.y) * 0.055))
	var body_font := maxi(14, int(title_font * 0.44))
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.16), "WAYSTONE", HORIZONTAL_ALIGNMENT_CENTER, size.x, title_font, Color("f2e7c8"))
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.23), "Choose a prototype class and rule set", HORIZONTAL_ALIGNMENT_CENTER, size.x, body_font, Color("9fb2b7"))
	for choice in ["duelist", "guardian", "reaver"]:
		var rect: Rect2 = _setup_class_rect(String(choice))
		var selected: bool = setup_loadout == String(choice)
		draw_rect(rect, Color("17272d"))
		draw_rect(rect, Color("58d2cf") if selected else Color("45545a"), false, 3.0 if selected else 1.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.58), String(choice).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, body_font, Color("eef0e9"))
	for mode in progression_rects:
		var rect := Rect2(progression_rects[mode])
		var selected: bool = setup_mode == String(mode)
		draw_rect(rect, Color("17272d"))
		draw_rect(rect, Color("d7aa58") if selected else Color("45545a"), false, 3.0 if selected else 1.0)
		var label := "EXPEDITION" if String(mode) == "expedition" else "CAMPAIGN LAB"
		var subtitle := "PERMADEATH • EXIT LEVELS" if String(mode) == "expedition" else "RESPAWN • STONE LEVELS"
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.40), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, body_font, Color("eef0e9"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(5, rect.size.y * 0.70), subtitle, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 10, maxi(9, int(body_font * 0.62)), Color("9fb2b7"))
	draw_rect(start_rect, Color("24433f"))
	draw_rect(start_rect, Color("58d2cf"), false, 3.0)
	draw_string(ThemeDB.fallback_font, start_rect.position + Vector2(0, start_rect.size.y * 0.60), "START RUN", HORIZONTAL_ALIGNMENT_CENTER, start_rect.size.x, maxi(18, body_font), Color("f3f2e8"))
	if setup_seed_error != "":
		draw_string(ThemeDB.fallback_font, Vector2(start_rect.position.x, start_rect.end.y + 24.0), setup_seed_error, HORIZONTAL_ALIGNMENT_CENTER, start_rect.size.x, maxi(12, int(body_font * 0.8)), Color("e46c63"))

func _setup_class_rect(choice: String) -> Rect2:
	var choices := ["duelist", "guardian", "reaver"]
	var index := choices.find(choice)
	var total_width := minf(size.x * 0.84, 760.0)
	var gap := clampf(total_width * 0.025, 10.0, 20.0)
	var width := (total_width - gap * 2.0) / 3.0
	return Rect2(Vector2((size.x - total_width) * 0.5 + index * (width + gap), size.y * 0.33), Vector2(width, 82.0))

func _upgrade_leave_rect() -> Rect2:
	return Rect2(Vector2(board_rect.get_center().x - 80.0, board_rect.end.y - 72.0), Vector2(160.0, 48.0))

func _draw_death_overlay() -> void:
	draw_rect(board_rect, Color(0.02, 0.02, 0.025, 0.78))
	var font := maxi(30, int(minf(size.x, size.y) * 0.065))
	var title := "EXPEDITION ENDED" if state.mode_id == "expedition" else "FALLEN"
	var prompt := "Tap to return to setup" if state.mode_id == "expedition" else "Tap to return to the Waystone"
	draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x, board_rect.get_center().y - 28.0), title, HORIZONTAL_ALIGNMENT_CENTER, board_rect.size.x, font, Color("d76a68"))
	draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x, board_rect.get_center().y + 40.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, board_rect.size.x, maxi(14, int(font * 0.42)), Color("d6d3c7"))

func _draw_map() -> void:
	var overlay := state.map_presentation == "overlay"
	var rect := _map_panel_rect()
	draw_rect(rect, Color(0.025, 0.04, 0.05, 0.36 if overlay else 0.98))
	draw_rect(rect, Color(0.62, 0.70, 0.72, 0.62 if overlay else 1.0), false, 2.0)
	var map_bounds := _discovered_map_bounds().grow(120.0)
	var scale := minf((rect.size.x - 72.0) / map_bounds.size.x, (rect.size.y - 110.0) / map_bounds.size.y)
	var origin := rect.get_center() - map_bounds.get_center() * scale + Vector2(0, 18)
	for connection in state.connections:
		var corridor := Rect2(connection["corridor"])
		if not state.is_discovered(corridor.get_center()): continue
		var mapped := Rect2(origin + corridor.position * scale, corridor.size * scale)
		draw_rect(mapped, Color(0.26, 0.33, 0.35, 0.58 if overlay else 1.0))
	for area in state.areas:
		if not bool(area.get("discovered", false)): continue
		var world_rect := Rect2(area["rect"])
		var mapped := Rect2(origin + world_rect.position * scale, world_rect.size * scale)
		draw_rect(mapped, Color(0.15, 0.22, 0.24, 0.55 if overlay else 1.0))
		draw_rect(mapped, Color(0.42, 0.49, 0.51, 0.7 if overlay else 1.0), false, 1.5)
	var player := origin + state.player_pos * scale
	var bonfire := origin + state.bonfire_pos * scale
	draw_circle(bonfire, 8.0, Color("e89b52"))
	draw_circle(player, 7.0, PLAYER_COLOR)
	if bool(state.areas[6].get("discovered", false)):
		var exit_center := origin + Vector2(state.areas[6]["center"]) * scale
		draw_colored_polygon(PackedVector2Array([exit_center + Vector2(0, -9), exit_center + Vector2(9, 8), exit_center + Vector2(-9, 8)]), Color("d76a68"))
	if state.is_discovered(state.shortcut_gate.get_center()): draw_circle(origin + state.shortcut_gate.get_center() * scale, 7.0, Color("65c5b5") if state.shortcut_unlocked else Color("bb5960"))
	if bool(state.lost_xp.get("active", false)): draw_circle(origin + Vector2(state.lost_xp["pos"]) * scale, 7.0, Color("d8ed78"))
	var header := "DISCOVERED AREAS  •  %s  •  SEED %d" % [state.mode_label().to_upper(), state.run_seed]
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(18, 34), header, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 170.0, maxi(15, int(minf(size.x, size.y) * 0.026)), Color("e6e7dc"))
	_draw_map_action(_map_close_rect(), "CLOSE")
	if not overlay:
		_draw_map_action(map_mode_rect, "OVERLAY")
		_draw_map_action(seed_copy_rect, "COPY SEED")

func _map_panel_rect() -> Rect2:
	return board_rect.grow(-18.0) if state.map_presentation == "overlay" else Rect2(Vector2(14, 14), size - Vector2(28, 28))

func _map_close_rect() -> Rect2:
	var rect := _map_panel_rect()
	return Rect2(rect.position + Vector2(rect.size.x - 132.0, 12.0), Vector2(120.0, 46.0))

func _map_action_rect(row: int) -> Rect2:
	var rect := Rect2(Vector2(14, 14), size - Vector2(28, 28))
	return Rect2(rect.position + Vector2(rect.size.x - 132.0, 12.0 + row * 56.0), Vector2(120.0, 46.0))

func _draw_map_action(rect: Rect2, label: String) -> void:
	draw_rect(rect, Color(0.09, 0.15, 0.17, 0.88))
	draw_rect(rect, Color("d7aa58"), false, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color("f1e8d0"))

func _discovered_map_bounds() -> Rect2:
	var bounds := Rect2(state.player_pos - Vector2.ONE * 40.0, Vector2.ONE * 80.0)
	for area in state.areas:
		if bool(area.get("discovered", false)): bounds = bounds.merge(Rect2(area["rect"]))
	for connection in state.connections:
		var corridor := Rect2(connection["corridor"])
		if state.is_discovered(corridor.get_center()): bounds = bounds.merge(corridor)
	if bool(state.lost_xp.get("active", false)):
		bounds = bounds.merge(Rect2(Vector2(state.lost_xp["pos"]) - Vector2.ONE * 30.0, Vector2.ONE * 60.0))
	return bounds

func _draw_inspection() -> void:
	var enemy: Dictionary = {}
	for candidate in Array(visual.get("enemies", [])):
		if int(candidate["id"]) == inspected_enemy_id:
			enemy = candidate
			break
	if enemy.is_empty(): return
	var kind := String(enemy["kind"])
	var names := {"knife": "Knife", "blade": "Blade", "archer": "Archer", "polearm": "Polearm", "shield": "Shieldbearer", "hound": "Hound", "brute": "Brute", "hexer": "Hexer", "captain": "Captain", "warden": "Warden"}
	var speeds := {"knife": "Fast", "hound": "Fast", "captain": "Fast", "blade": "Medium", "archer": "Medium", "hexer": "Medium", "shield": "Slow", "polearm": "Slow", "brute": "Slow", "warden": "Slow"}
	var reaches := {"knife": "Short", "hound": "Medium", "blade": "Medium", "shield": "Medium", "captain": "Medium", "brute": "Medium", "archer": "Long", "hexer": "Long", "polearm": "Long", "warden": "Long"}
	var traits := {"knife": "Low stability", "hound": "Charge; low stability", "archer": "Ranged pressure", "polearm": "Heavy long reach", "shield": "Frontal guard", "brute": "Grounded heavy attacks", "hexer": "Delayed danger zones", "captain": "Strengthens nearby movement", "warden": "Grounded boss", "blade": "Balanced melee"}
	var action_text := _phase(Dictionary(enemy["action"]))
	if action_text == "": action_text = "READY"
	var signature_techniques := {"knife": "quick_cut", "blade": "diagonal_cut", "polearm": "thrust", "hound": "bite", "brute": "forward_smash", "captain": "thrust", "warden": "heavy_cleave"}
	var technique_id := String(Dictionary(enemy["action"]).get("technique_id", signature_techniques.get(kind, "")))
	var technique_text := AttackGeometryScript.label(technique_id) if technique_id != "" else "Ranged"
	var posture_ratio := float(enemy.get("posture", 1.0)) / maxf(0.01, float(enemy.get("posture_max", 1.0)))
	var stability := "Strained" if posture_ratio < 0.45 else "Unsteady" if posture_ratio < 0.8 else "Stable"
	var width := minf(board_rect.size.x * 0.82, 520.0)
	var height := clampf(board_rect.size.y * 0.14, 112.0, 170.0)
	var rect := Rect2(Vector2(board_rect.get_center().x - width * 0.5, board_rect.end.y - height - 34.0), Vector2(width, height))
	draw_rect(rect, Color(0.04, 0.07, 0.09, 0.95))
	draw_rect(rect, Color("9fb2b7"), false, 2.0)
	var title_font := maxi(13, int(height * 0.16))
	var body_font := maxi(10, int(title_font * 0.65))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, height * 0.25), String(names.get(kind, kind.capitalize())).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width - 20, title_font, Color("eef0e9"))
	var line_one := "%s  |  %s  |  %s speed  |  %s reach" % [action_text.capitalize(), technique_text, String(speeds.get(kind, "Medium")), String(reaches.get(kind, "Medium"))]
	var line_two := "%s  |  %s" % [stability, String(traits.get(kind, ""))]
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, height * 0.56), line_one, HORIZONTAL_ALIGNMENT_LEFT, width - 20, body_font, Color("d8ddd8"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, height * 0.80), line_two, HORIZONTAL_ALIGNMENT_LEFT, width - 20, body_font, Color("d7aa58"))

func _draw_loadout_tab(choice: String, rect: Rect2) -> void:
	var selected := state.loadout_id == choice
	var colors := {"duelist": Color("58d2cf"), "guardian": Color("6ec4e8"), "reaver": Color("ee6645")}
	var color: Color = colors[choice]
	draw_rect(rect, Color("17272d") if selected else Color("10191e"))
	draw_rect(rect, color if selected else Color("45545a"), false, 3.0 if selected else 1.0)
	var font := maxi(9, int(minf(rect.size.x, rect.size.y) * 0.25))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, rect.size.y * 0.62), choice.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font, Color("eef0e9") if selected else Color("718087"))

func _draw_button(name: String, rect: Rect2) -> void:
	var available := true
	var subtitle := ""
	var title := name.to_upper()
	if name == "potion":
		available = state.potions > 0 and state.player_hp < state.player_max_hp
		subtitle = "%d LEFT" % state.potions
	elif name == "defense":
		title = state.defense_id.to_upper()
		available = _defense_cooldown() <= 0.0001
		subtitle = "FAST" if available and state.defense_id == "dodge" else "MEDIUM" if available else "COOLING"
	elif name == "skill":
		title = "SWEEP" if state.loadout_id == "duelist" else "NO SKILL"
		available = state.loadout_id == "duelist" and state.skill_cooldown <= 0.0001
		subtitle = "SLOW / WIDE" if available else "COOLING" if state.loadout_id == "duelist" else ""
	elif name == "wait":
		title = state.interaction_label()
		if title == "WAYSTONE":
			title = "STONE"
			subtitle = "REST / LEARN"
		else:
			subtitle = "OPEN SHORTCUT" if title == "UNLOCK" else "+0.5s"
		available = not state.trial_complete
	var color := Color("6ec4e8") if name == "defense" and state.defense_id == "block" else Color("ee6645") if name == "defense" and state.defense_id == "endure" else DODGE_COLOR if name == "defense" else Color("e8c35d") if name == "skill" else Color("d7aa58") if name == "wait" else Color("db6463")
	draw_rect(rect, Color("15232a") if available else Color("11191d"))
	draw_rect(rect, color if available else Color("465359"), false, 4.0 if selected_action == name else 2.0)
	if not available and (name == "defense" or (name == "skill" and state.loadout_id == "duelist")):
		var remaining := _defense_cooldown() if name == "defense" else state.skill_cooldown
		var defense_maximum := state.BLOCK_COOLDOWN if state.defense_id == "block" else state.ENDURE_COOLDOWN if state.defense_id == "endure" else state.DODGE_COOLDOWN
		var maximum := defense_maximum if name == "defense" else state.SWEEP_COOLDOWN
		var ready_ratio := 1.0 - clampf(remaining / maximum, 0.0, 1.0)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 5.0), Vector2(rect.size.x * ready_ratio, 5.0)), color)
	var title_font := maxi(12, int(minf(rect.size.x, rect.size.y) * 0.21))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.46), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, title_font, Color("f0ece0") if available else Color("68777c"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.72), subtitle, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(9, int(title_font * 0.6)), color if available else Color("59666b"))

func _draw_waystone_menu() -> void:
	var definitions := {
		"potion": ["REST", "HEAL • RESPAWN"],
		"defense": ["LEARN", "SPEND XP"],
		"skill": ["ANCHOR", "SECURE PROGRESS"],
		"wait": ["LEAVE", "CLOSE"],
	}
	for name in definitions:
		var rect := Rect2(buttons[name])
		var definition: Array = definitions[name]
		draw_rect(rect, Color("17272d"))
		draw_rect(rect, Color("d7aa58"), false, 2.0)
		var title_font := maxi(12, int(minf(rect.size.x, rect.size.y) * 0.19))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.44), String(definition[0]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, title_font, Color("f2e7c8"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, rect.size.y * 0.72), String(definition[1]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, maxi(8, int(title_font * 0.52)), Color("9fb2b7"))

func _draw_upgrade_choices() -> void:
	for index in upgrade_rects:
		if int(index) >= state.upgrade_choices.size(): continue
		var rect := Rect2(upgrade_rects[index])
		var id := state.upgrade_choices[int(index)]
		var title := state.upgrade_name(id).to_upper()
		var description := state.upgrade_description(id)
		draw_rect(rect, Color("17272d"))
		draw_rect(rect, Color("d7aa58"), false, 3.0)
		var title_font := maxi(10, int(minf(rect.size.x, rect.size.y) * 0.16))
		title_font = mini(title_font, maxi(9, int((rect.size.x - 16.0) / maxf(1.0, title.length() * 0.72))))
		var description_font := mini(maxi(8, int(title_font * 0.58)), maxi(7, int((rect.size.x - 18.0) / maxf(1.0, description.length() * 0.60))))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, rect.size.y * 0.38), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, title_font, Color("f2e7c8"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, rect.size.y * 0.66), description, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12, description_font, Color("d2d8d4"))
	var cost_text := "SPEND %d XP" % state.next_upgrade_cost()
	draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x, board_rect.end.y - 84.0), cost_text, HORIZONTAL_ALIGNMENT_CENTER, board_rect.size.x, 14, Color("d7aa58"))
	if state.upgrade_context == "waystone":
		var leave := _upgrade_leave_rect()
		draw_rect(leave, Color("17272d"))
		draw_rect(leave, Color("718087"), false, 2.0)
		draw_string(ThemeDB.fallback_font, leave.position + Vector2(0, leave.size.y * 0.62), "LEAVE", HORIZONTAL_ALIGNMENT_CENTER, leave.size.x, 13, Color("d7dddd"))

func _draw_results() -> void:
	var width := minf(board_rect.size.x * 0.78, 620.0)
	var height := minf(board_rect.size.y * 0.30, 330.0)
	var rect := Rect2(board_rect.get_center() - Vector2(width, height) * 0.5, Vector2(width, height))
	draw_rect(rect, Color(0.04, 0.07, 0.09, 0.94))
	draw_rect(rect, Color("d7aa58"), false, 3.0)
	var title_font := maxi(18, int(minf(size.x, size.y) * 0.04))
	var body_font := maxi(12, int(title_font * 0.55))
	var result_title := "EXPEDITION COMPLETE" if state.mode_id == "expedition" else "CAMPAIGN LAB COMPLETE"
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, height * 0.24), result_title, HORIZONTAL_ALIGNMENT_CENTER, width, title_font, Color("f2e7c8"))
	var results := "%s  |  %d rooms  |  %d enemies\n%d damage dealt  |  %d perfect dodges\nSeed %d" % [state.loadout_id.capitalize(), state.rooms_cleared, state.enemies_defeated, state.damage_dealt, state.perfect_dodges, state.run_seed]
	for line_index in range(results.split("\n").size()):
		var line := results.split("\n")[line_index]
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, height * (0.48 + line_index * 0.16)), line, HORIZONTAL_ALIGNMENT_CENTER, width, body_font, Color("d2d8d4"))

func _enemy_near(screen_position: Vector2, radius: float) -> Dictionary:
	for enemy in state.enemies:
		if not state.is_visible(Vector2(enemy["pos"]), Dictionary(visual.get("visible_cells", state.visible_cells))): continue
		if _world_to_screen(Vector2(enemy["pos"])).distance_to(screen_position) <= radius: return enemy
	return {}

func _world_to_screen(world: Vector2) -> Vector2:
	var origin := _projection_origin()
	if view_mode == "isometric": return origin + Vector2((world.x - world.y) * 0.5, (world.x + world.y) * 0.25) * world_scale
	return origin + world * world_scale

func _screen_to_world(screen: Vector2) -> Vector2:
	var origin := _projection_origin()
	if view_mode == "isometric":
		var projected := (screen - origin) / world_scale
		return Vector2(projected.x + projected.y * 2.0, projected.y * 2.0 - projected.x)
	return (screen - origin) / world_scale

func _projection_origin() -> Vector2:
	var camera := _camera_world_position()
	if view_mode == "isometric":
		var projected_camera := Vector2((camera.x - camera.y) * 0.5, (camera.x + camera.y) * 0.25)
		return board_rect.get_center() - projected_camera * world_scale
	return board_rect.get_center() - camera * world_scale

func _camera_world_position() -> Vector2:
	var camera := Vector2(visual.get("player_pos", state.player_pos))
	if view_mode == "top_down":
		var half_view := board_rect.size / (world_scale * 2.0)
		camera.x = clampf(camera.x, minf(half_view.x, state.WORLD_SIZE.x * 0.5), maxf(state.WORLD_SIZE.x - half_view.x, state.WORLD_SIZE.x * 0.5))
		camera.y = clampf(camera.y, minf(half_view.y, state.WORLD_SIZE.y * 0.5), maxf(state.WORLD_SIZE.y - half_view.y, state.WORLD_SIZE.y * 0.5))
	return camera

func _screen_direction(world_direction: Vector2) -> Vector2:
	if view_mode == "top_down": return world_direction.normalized()
	var projected := Vector2((world_direction.x - world_direction.y) * 0.5, (world_direction.x + world_direction.y) * 0.25)
	return projected.normalized()

func _screen_delta_to_world_direction(screen_delta: Vector2) -> Vector2:
	if view_mode == "top_down": return screen_delta.normalized()
	var world_delta := Vector2(screen_delta.x + screen_delta.y * 2.0, screen_delta.y * 2.0 - screen_delta.x)
	return world_delta.normalized()

func _toggle_view() -> void:
	view_mode = "isometric" if view_mode == "top_down" else "top_down"
	selected_action = ""
	pointer_down = false
	held_movement = false
	_update_projection()
	reset_rect.position = board_rect.end - reset_rect.size - Vector2(8.0, board_rect.size.y - reset_rect.size.y - 8.0)
	view_rect.position = reset_rect.position - Vector2(view_rect.size.x + 8.0, 0.0)
	map_rect.position = view_rect.position - Vector2(map_rect.size.x + 8.0, 0.0)
	queue_redraw()
