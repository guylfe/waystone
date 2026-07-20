extends Control

const RunStateScript = preload("res://scripts/core/run_state.gd")
const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const PresentationFrameScript = preload("res://scripts/presentation/presentation_frame.gd")
const BG := Color("0d151b")
const FLOOR := Color("17272d")
const WALL := Color("344148")
const PLAYER_COLOR := Color("39ddff")
const BLADE_COLOR := Color("e46c63")
const ARCHER_COLOR := Color("c68be4")
const POLEARM_COLOR := Color("d08a48")
const DODGE_COLOR := Color("58d2cf")
const CAMERA_WORLD_WIDTH := 1050.0
const CAMERA_WORLD_HEIGHT := 1000.0
const ISO_ZOOM := 1.38
const ISO_CAMERA_DROP := 0.075
const ISO_WALL_HEIGHT := 54.0
const MOUSE_HOLD_DELAY := 0.14
const AUTOSAVE_DELAY := 2.0
const AUTOSAVE_QUIET_DELAY := 0.24
const MAP_LAYERS_PER_PAGE := 5
const MAX_SIM_TICKS_PER_FRAME := 4
const RENDER_QUERY_REUSE_DISTANCE := 220.0
const FLOOR_RENDER_CHUNK_CELLS := 8

var state: RunState
var visual: Dictionary = {}
var timeline: Array[Dictionary] = []
var playback_index := 0
var playback_accumulator := 0.0
var playing := false
var streaming_action := false
var stream_accumulator := 0.0
var stream_frame_a = PresentationFrameScript.new()
var stream_frame_b = PresentationFrameScript.new()
var stream_previous_frame = stream_frame_a
var stream_current_frame = stream_frame_a
var stream_blended_frame = PresentationFrameScript.new()
var touch_start := Vector2.ZERO
var touch_current := Vector2.ZERO
var pointer_down := false
var hold_elapsed := 0.0
var hold_consumed := false
var inspected_enemy_id := -1
var held_movement := false
var held_direction := Vector2.ZERO
var pointer_is_mouse := false
var desktop_movement_keys: Dictionary = {}
var board_rect := Rect2()
var world_scale := 1.0
var board_area := Rect2()
var iso_origin := Vector2.ZERO
var view_mode := "isometric"
var debug_hitboxes := false
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
var map_view_layer := ""
var map_layer_page := 0
var map_layer_rects: Dictionary = {}
var map_layer_previous_rect := Rect2()
var map_layer_next_rect := Rect2()
var autosave_pending := false
var autosave_elapsed := 0.0
var autosave_quiet_elapsed := 0.0
var autosave_deferred := false
var setup_loadout := "duelist"
var setup_mode := "expedition"
var waystone_menu_open := false
var seed_input: LineEdit
var setup_seed_error := ""
var desktop_controls := not OS.has_feature("mobile")
var frame_metric_elapsed := 0.0
var frame_metric_worst_ms := 0.0
var completed_streamed_actions := 0
var _static_query_revision := -1
var _static_query_layer := ""
var _static_query_view := ""
var _static_query_scale := -1.0
var _static_query_anchor := Vector2.INF
var _cached_render_walls: Array[Rect2] = []
var _cached_render_features: Array[Dictionary] = []
var _floor_cache_revision := -1
var _floor_cache_epoch := -1
var _floor_cache_seed := -1
var _floor_cache_layer := ""
var _floor_cache_view := ""
var _floor_cache_scale := -1.0
var _floor_cells_by_chunk: Dictionary = {}
var _floor_iso_geometry: Dictionary = {}
var _floor_top_down_geometry: Dictionary = {}

func _ready() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	if desktop_controls and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(Vector2i(720, 480))
	Input.emulate_mouse_from_touch = false
	state = RunStateScript.new(false)
	state.load_run()
	_create_seed_input()
	setup_loadout = state.loadout_id
	setup_mode = state.mode_id
	map_view_layer = state.current_layer
	visual = _presentation_snapshot()
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
		var footer_height := clampf(size.y * 0.11, 58.0, 92.0)
		var action_bottom := size.y - footer_height
		var tab_height := (size.y * 0.22 - gap * 4.0) / 3.0
		for i in range(3):
			loadout_rects[loadouts[i]] = Rect2(left, gap + i * (tab_height + gap), size.x - left - gap, tab_height)
		var action_top := size.y * 0.25
		var height := (action_bottom - action_top - gap * 5.0) / 4.0
		for i in range(4):
			buttons[names[i]] = Rect2(left, action_top + gap + i * (height + gap), size.x - left - gap, height)
		var upgrade_height := (action_bottom - action_top - gap * 4.0) / 3.0
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
	var base_scale := clampf(maxf(board_area.size.x / CAMERA_WORLD_WIDTH, board_area.size.y / CAMERA_WORLD_HEIGHT), 0.9, 2.0)
	world_scale = base_scale * ISO_ZOOM if view_mode == "isometric" else base_scale
	board_rect = board_area
	iso_origin = Vector2.ZERO

func _process(delta: float) -> void:
	frame_metric_elapsed += delta
	frame_metric_worst_ms = maxf(frame_metric_worst_ms, delta * 1000.0)
	if frame_metric_elapsed >= 2.0:
		state.performance_metrics["worst_frame_ms"] = frame_metric_worst_ms
		frame_metric_elapsed = 0.0
		frame_metric_worst_ms = 0.0
	var needs_redraw := false
	var finished_streamed_movement := false
	if _autosave_frame_is_quiet(): autosave_quiet_elapsed += delta
	else: autosave_quiet_elapsed = 0.0
	if autosave_pending:
		autosave_elapsed += delta
		if autosave_elapsed >= AUTOSAVE_DELAY and autosave_quiet_elapsed >= AUTOSAVE_QUIET_DELAY and not autosave_deferred:
			autosave_deferred = true
			call_deferred("_flush_autosave_if_quiet")
	if streaming_action:
		var requested_accumulator := stream_accumulator + minf(delta, 0.10)
		var maximum_accumulator := state.SIM_DT * float(MAX_SIM_TICKS_PER_FRAME)
		if requested_accumulator > maximum_accumulator:
			state.performance_metrics["dropped_realtime_ms"] = float(state.performance_metrics.get("dropped_realtime_ms", 0.0)) + (requested_accumulator - maximum_accumulator) * 1000.0
		stream_accumulator = minf(requested_accumulator, maximum_accumulator)
		var ticks_processed := 0
		while stream_accumulator >= state.SIM_DT and ticks_processed < MAX_SIM_TICKS_PER_FRAME and String(state.player_action["kind"]) != "idle" and state.player_hp > 0:
			stream_previous_frame = stream_current_frame
			stream_current_frame = stream_frame_b if stream_current_frame == stream_frame_a else stream_frame_a
			state.advance_streamed_action_tick()
			var capture_start := Time.get_ticks_usec()
			stream_current_frame.capture(state)
			state.performance_metrics["presentation_capture_ms"] = float(Time.get_ticks_usec() - capture_start) / 1000.0
			stream_accumulator -= state.SIM_DT
			ticks_processed += 1
		if String(state.player_action["kind"]) == "idle" or state.player_hp <= 0:
			streaming_action = false
			playing = false
			visual = stream_current_frame.data
			finished_streamed_movement = true
			completed_streamed_actions += 1
			if OS.is_debug_build() and completed_streamed_actions % 20 == 0:
				print("WAYSTONE FRAME action=%.2fms capture=%.2fms visibility=%.2fms draw=%.2fms worst=%.2fms dropped=%.1fms active=%d resident=%d" % [float(state.performance_metrics["last_action_ms"]), float(state.performance_metrics["presentation_capture_ms"]), float(state.performance_metrics["visibility_ms"]), float(state.performance_metrics["draw_cpu_ms"]), float(state.performance_metrics["worst_frame_ms"]), float(state.performance_metrics["dropped_realtime_ms"]), int(state.performance_metrics["active_enemies"]), int(state.performance_metrics["resident_enemies"])])
		else:
			visual = stream_blended_frame.blend(stream_previous_frame, stream_current_frame, stream_accumulator / state.SIM_DT)
		needs_redraw = true
	elif playing:
		playback_accumulator += delta
		while playback_accumulator >= state.FRAME_DT and playback_index < timeline.size() - 1:
			playback_accumulator -= state.FRAME_DT
			playback_index += 1
		if playback_index >= timeline.size() - 1:
			playing = false
			visual = _presentation_snapshot()
			needs_redraw = true
		else:
			visual = _interpolate_playback_snapshot(playback_accumulator / state.FRAME_DT)
			needs_redraw = true
	if not playing and _can_repeat_primary_action():
		if held_movement and pointer_down:
			if pointer_is_mouse: _commit_mouse_primary(finished_streamed_movement)
			else: _begin_streamed_move(held_direction, state.MOVE_RANGE, finished_streamed_movement)
		elif desktop_controls:
			var keyboard_direction := _desktop_held_direction()
			if not keyboard_direction.is_zero_approx(): _begin_streamed_move(keyboard_direction, state.MOVE_RANGE, finished_streamed_movement)
	if finished_streamed_movement and not streaming_action: stream_accumulator = 0.0
	if pointer_down and not playing and not held_movement and inspected_enemy_id < 0 and board_rect.has_point(touch_start):
		hold_elapsed += delta
		if pointer_is_mouse and hold_elapsed >= MOUSE_HOLD_DELAY and selected_action == "":
			held_movement = true
			_commit_mouse_primary()
		elif not pointer_is_mouse and hold_elapsed >= 0.46:
			var inspected := _enemy_near(touch_start, 68.0)
			if not inspected.is_empty():
				inspected_enemy_id = int(inspected["id"])
				hold_consumed = true
				needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _interpolate_playback_snapshot(weight: float) -> Dictionary:
	var current: Dictionary = timeline[playback_index]
	var following: Dictionary = timeline[min(playback_index + 1, timeline.size() - 1)]
	return _interpolate_snapshots(current, following, weight)

func _interpolate_snapshots(current: Dictionary, following: Dictionary, weight: float) -> Dictionary:
	var amount := clampf(weight, 0.0, 1.0)
	var result := current.duplicate(false)
	result["time"] = lerpf(float(current.get("time", 0.0)), float(following.get("time", 0.0)), amount)
	result["player_pos"] = Vector2(current["player_pos"]).lerp(Vector2(following["player_pos"]), amount)
	result["player_facing"] = _interpolate_direction(Vector2(current["player_facing"]), Vector2(following["player_facing"]), amount)
	result["player_action"] = _interpolate_action(Dictionary(current["player_action"]), Dictionary(following["player_action"]), amount)
	for key in ["dodge_cooldown", "block_cooldown", "endure_cooldown", "skill_cooldown", "strength_remaining"]:
		result[key] = lerpf(float(current.get(key, 0.0)), float(following.get(key, 0.0)), amount)
	result["enemies"] = _interpolate_enemies(Array(current.get("enemies", [])), Array(following.get("enemies", [])), amount)
	result["projectiles"] = _interpolate_visual_array(Array(current.get("projectiles", [])), Array(following.get("projectiles", [])), amount, ["pos"], [])
	result["hazards"] = _interpolate_visual_array(Array(current.get("hazards", [])), Array(following.get("hazards", [])), amount, ["pos"], ["elapsed"])
	result["effects"] = _interpolate_visual_array(Array(current.get("effects", [])), Array(following.get("effects", [])), amount, ["pos"], ["elapsed"])
	return result

func _interpolate_direction(current: Vector2, following: Vector2, weight: float) -> Vector2:
	var blended := current.lerp(following, weight)
	return blended.normalized() if blended.length_squared() > 0.001 else current.normalized()

func _interpolate_action(current: Dictionary, following: Dictionary, weight: float) -> Dictionary:
	var result := current.duplicate(false)
	if String(current.get("kind", "idle")) == String(following.get("kind", "idle")):
		result["elapsed"] = lerpf(float(current.get("elapsed", 0.0)), float(following.get("elapsed", 0.0)), weight)
	return result

func _interpolate_enemies(current: Array, following: Array, weight: float) -> Array[Dictionary]:
	var following_by_id: Dictionary = {}
	for enemy_value in following:
		var enemy := Dictionary(enemy_value)
		following_by_id[int(enemy.get("id", -1))] = enemy
	var result: Array[Dictionary] = []
	for enemy_value in current:
		var enemy := Dictionary(enemy_value)
		var blended := enemy.duplicate(false)
		var next_enemy: Dictionary = following_by_id.get(int(enemy.get("id", -1)), {})
		if not next_enemy.is_empty():
			blended["pos"] = Vector2(enemy["pos"]).lerp(Vector2(next_enemy["pos"]), weight)
			blended["facing"] = _interpolate_direction(Vector2(enemy["facing"]), Vector2(next_enemy["facing"]), weight)
			blended["posture"] = lerpf(float(enemy.get("posture", 0.0)), float(next_enemy.get("posture", 0.0)), weight)
			blended["action"] = _interpolate_action(Dictionary(enemy["action"]), Dictionary(next_enemy["action"]), weight)
		result.append(blended)
	return result

func _interpolate_visual_array(current: Array, following: Array, weight: float, vector_keys: Array, float_keys: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(current.size()):
		var item := Dictionary(current[index]).duplicate(false)
		if index < following.size():
			var next_item := Dictionary(following[index])
			for key_value in vector_keys:
				var key := String(key_value)
				if item.has(key) and next_item.has(key): item[key] = Vector2(item[key]).lerp(Vector2(next_item[key]), weight)
			for key_value in float_keys:
				var key := String(key_value)
				if item.has(key) and next_item.has(key): item[key] = lerpf(float(item[key]), float(next_item[key]), weight)
		result.append(item)
	return result

func _gui_input(event: InputEvent) -> void:
	autosave_quiet_elapsed = 0.0
	if event is InputEventScreenTouch:
		if event.pressed: _pointer_pressed(event.position, false)
		else: _pointer_released(event.position)
	elif event is InputEventScreenDrag:
		_pointer_dragged(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var inspected := _enemy_near(event.position, 28.0)
		inspected_enemy_id = -1 if inspected.is_empty() else int(inspected["id"])
		queue_redraw()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _pointer_pressed(event.position, true)
		else: _pointer_released(event.position)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_pointer_dragged(event.position)

func _pointer_pressed(position: Vector2, is_mouse: bool = false) -> void:
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
			map_view_layer = state.current_layer
			map_layer_page = 0
			queue_redraw()
		return
	if map_open and state.map_presentation == "full":
		_update_map_layer_controls()
		if map_layer_previous_rect.size != Vector2.ZERO and map_layer_previous_rect.has_point(position):
			map_layer_page = maxi(0, map_layer_page - 1)
			queue_redraw()
		elif map_layer_next_rect.size != Vector2.ZERO and map_layer_next_rect.has_point(position):
			map_layer_page += 1
			queue_redraw()
		else:
			for layer_id in map_layer_rects:
				if Rect2(map_layer_rects[layer_id]).has_point(position):
					map_view_layer = String(layer_id)
					queue_redraw()
					return
		if map_mode_rect.has_point(position):
			state.map_presentation = "overlay"
			map_view_layer = state.current_layer
			_mark_autosave()
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
		visual = _presentation_snapshot()
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
			visual = _presentation_snapshot()
			queue_redraw()
			return
		for index in upgrade_rects:
			if Rect2(upgrade_rects[index]).has_point(position) and int(index) < state.upgrade_choices.size():
				state.choose_upgrade(state.upgrade_choices[int(index)])
				visual = _presentation_snapshot()
				queue_redraw()
				return
		return
	if playing or state.player_hp <= 0:
		return
	pointer_down = true
	pointer_is_mouse = is_mouse
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
	if pointer_is_mouse:
		if not held_movement:
			held_movement = true
			if not playing: _commit_mouse_primary()
		return
	if not _enemy_near(position, 62.0).is_empty(): return
	held_direction = _screen_delta_to_world_direction(drag)
	if not held_movement:
		held_movement = true
		if not playing:
			_begin_streamed_move(held_direction)

func _pointer_released(position: Vector2) -> void:
	if not pointer_down:
		return
	pointer_down = false
	pointer_is_mouse = false
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
	if desktop_controls and _is_desktop_movement_key(event.keycode):
		if event.echo: return
		_set_desktop_movement_key(event.keycode, event.pressed)
		if event.pressed and not playing and _can_repeat_primary_action():
			var held := _desktop_held_direction()
			if not held.is_zero_approx(): _commit_direction(held)
		return
	if not event.pressed: return
	if desktop_controls and (event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed)):
		_toggle_fullscreen()
		return
	if playing or event.echo: return
	if not state.run_active:
		match event.keycode:
			KEY_1: setup_loadout = "duelist"
			KEY_2: setup_loadout = "guardian"
			KEY_3: setup_loadout = "reaver"
			KEY_TAB: setup_mode = "campaign_lab" if setup_mode == "expedition" else "expedition"
			KEY_ENTER: _start_run()
			_: return
		queue_redraw()
		return
	if event.keycode == KEY_H and state.run_active:
		debug_hitboxes = not debug_hitboxes
		queue_redraw()
		return
	if event.keycode == KEY_M and state.run_active:
		map_open = not map_open
		if map_open:
			map_view_layer = state.current_layer
			map_layer_page = 0
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
	if event.keycode == KEY_ESCAPE and desktop_controls and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		return
	if map_open and state.map_presentation == "full": return
	if state.death_pending:
		if event.keycode in [KEY_ENTER, KEY_SPACE]: state.return_after_death()
		return
	if waystone_menu_open:
		if event.keycode in [KEY_1, KEY_L]:
			if state.learn_at_waystone(): waystone_menu_open = false
		elif event.keycode in [KEY_2, KEY_ENTER, KEY_C]: waystone_menu_open = false
		visual = _presentation_snapshot()
		queue_redraw()
		return
	if state.upgrade_pending:
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			var index := [KEY_1, KEY_2, KEY_3].find(event.keycode)
			if index < state.upgrade_choices.size(): state.choose_upgrade(state.upgrade_choices[index])
		elif event.keycode == KEY_ESCAPE and state.upgrade_context == "waystone": state.leave_upgrade_menu()
		visual = _presentation_snapshot()
		queue_redraw()
		return
	if event.keycode == KEY_V:
		_toggle_view()
		return
	match event.keycode:
		KEY_1, KEY_P: _handle_button("potion")
		KEY_2, KEY_SHIFT, KEY_B: _handle_button("defense")
		KEY_3, KEY_Q: _handle_button("skill")
		KEY_4, KEY_E, KEY_SPACE: _advance_or_wait()
		KEY_R: _restart()

func _desktop_direction_for_key(keycode: Key) -> Vector2:
	var screen_direction := Vector2.ZERO
	match keycode:
		KEY_W, KEY_UP: screen_direction = Vector2.UP
		KEY_S, KEY_DOWN: screen_direction = Vector2.DOWN
		KEY_A, KEY_LEFT: screen_direction = Vector2.LEFT
		KEY_D, KEY_RIGHT: screen_direction = Vector2.RIGHT
	return _screen_delta_to_world_direction(screen_direction) if not screen_direction.is_zero_approx() else Vector2.ZERO

func _is_desktop_movement_key(keycode: Key) -> bool:
	return keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]

func _set_desktop_movement_key(keycode: Key, pressed: bool) -> void:
	if pressed: desktop_movement_keys[keycode] = true
	else: desktop_movement_keys.erase(keycode)

func _desktop_held_direction() -> Vector2:
	var up := desktop_movement_keys.has(KEY_W) or desktop_movement_keys.has(KEY_UP)
	var down := desktop_movement_keys.has(KEY_S) or desktop_movement_keys.has(KEY_DOWN)
	var left := desktop_movement_keys.has(KEY_A) or desktop_movement_keys.has(KEY_LEFT)
	var right := desktop_movement_keys.has(KEY_D) or desktop_movement_keys.has(KEY_RIGHT)
	var screen_direction := Vector2(float(int(right) - int(left)), float(int(down) - int(up)))
	return _screen_delta_to_world_direction(screen_direction) if not screen_direction.is_zero_approx() else Vector2.ZERO

func _can_repeat_primary_action() -> bool:
	if not state.run_active or not state.is_player_ready() or state.trial_complete: return false
	if waystone_menu_open or state.upgrade_pending or state.death_pending: return false
	return not (map_open and state.map_presentation == "full")

func _commit_mouse_primary(preserve_stream_time: bool = false) -> void:
	if not _can_repeat_primary_action() or not board_rect.has_point(touch_current): return
	var enemy := _enemy_near(touch_current, 54.0)
	if not enemy.is_empty():
		_begin_streamed_action(state.request_attack(Vector2(enemy["pos"]), false), preserve_stream_time)
		return
	var target := _screen_to_world(touch_current)
	var delta := target - state.player_pos
	if delta.length() < 8.0: return
	_begin_streamed_move(delta, minf(delta.length(), state.MOVE_RANGE), preserve_stream_time)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		desktop_movement_keys.clear()
		pointer_down = false
		held_movement = false
		if streaming_action and state != null:
			var guard := 0
			while String(state.player_action["kind"]) != "idle" and state.player_hp > 0 and guard < 1000:
				state.advance_streamed_action_tick()
				guard += 1
			streaming_action = false
			playing = false
			stream_accumulator = 0.0
			visual = _presentation_snapshot()
		if state != null: _mark_autosave(true)

func _toggle_fullscreen() -> void:
	if not desktop_controls: return
	var mode := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _handle_gesture(end_position: Vector2) -> void:
	if state.player_hp <= 0:
		_restart()
		return
	for name in buttons:
		if Rect2(buttons[name]).has_point(end_position):
			_handle_button(String(name))
			return
	if not board_rect.has_point(end_position): return
	if _try_waystone_press(end_position): return
	if _try_transition_press(end_position): return
	var drag := end_position - touch_start
	var threshold := maxf(22.0, minf(size.x, size.y) * 0.025)
	if drag.length() >= threshold:
		if selected_action in ["defense", "skill"]:
			var action := selected_action
			selected_action = ""
			var world_direction := _screen_delta_to_world_direction(drag)
			_begin_streamed_action(state.request_defense(world_direction, false) if action == "defense" else state.request_skill(world_direction, false))
		else:
			var enemy := _enemy_near(end_position, 62.0)
			if enemy.is_empty(): _begin_streamed_move(_screen_delta_to_world_direction(drag))
			else: _begin_streamed_action(state.request_attack(Vector2(enemy["pos"]), false))
		return
	var enemy := _enemy_near(end_position, 54.0)
	if not enemy.is_empty():
		if selected_action == "skill":
			selected_action = ""
			_begin_streamed_action(state.request_skill(Vector2(enemy["pos"]) - state.player_pos, false))
		else: _begin_streamed_action(state.request_attack(Vector2(enemy["pos"]), false))
	elif selected_action == "defense":
		selected_action = ""
		var direction := _screen_to_world(end_position) - state.player_pos
		_begin_streamed_action(state.request_defense(direction, false))
	elif selected_action == "skill":
		selected_action = ""
		_begin_streamed_action(state.request_skill(_screen_to_world(end_position) - state.player_pos, false))
	else:
		var target := _screen_to_world(end_position)
		_begin_streamed_move(target - state.player_pos, minf(target.distance_to(state.player_pos), state.MOVE_RANGE))

func _handle_button(name: String) -> void:
	match name:
		"potion": _begin_streamed_action(state.request_potion(false))
		"defense":
			if _defense_cooldown() <= 0.0001:
				if state.defense_id == "endure": _begin_streamed_action(state.request_endure(state.player_facing, false))
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
		_begin_streamed_action(state.request_defense(direction, false))
	elif selected_action == "skill":
		selected_action = ""
		_begin_streamed_action(state.request_skill(direction, false))
	else: _begin_streamed_move(direction)

func _begin_streamed_move(direction: Vector2, distance: float = -1.0, preserve_stream_time: bool = false) -> void:
	if distance < 0.0: distance = state.MOVE_RANGE
	_begin_streamed_action(state.begin_streamed_move(direction, distance), preserve_stream_time)

func _begin_streamed_action(did_begin: bool, preserve_stream_time: bool = false) -> void:
	if not did_begin:
		queue_redraw()
		return
	if not preserve_stream_time: stream_accumulator = 0.0
	var capture_start := Time.get_ticks_usec()
	stream_current_frame.capture(state)
	state.performance_metrics["presentation_capture_ms"] = float(Time.get_ticks_usec() - capture_start) / 1000.0
	stream_previous_frame = stream_current_frame
	visual = stream_current_frame.data
	streaming_action = true
	playing = true
	timeline.clear()
	queue_redraw()

func _commit(did_commit: bool) -> void:
	if not did_commit:
		queue_redraw()
		return
	streaming_action = false
	stream_accumulator = 0.0
	timeline = state.last_timeline
	playback_index = 0
	playback_accumulator = 0.0
	visual = timeline[0]
	playing = timeline.size() > 1
	queue_redraw()

func _restart() -> void:
	state.abandon_run()
	state.save_run()
	autosave_pending = false
	selected_action = ""
	playing = false
	streaming_action = false
	stream_accumulator = 0.0
	pointer_down = false
	held_movement = false
	held_direction = Vector2.ZERO
	waystone_menu_open = false
	timeline.clear()
	visual = _presentation_snapshot()
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
	playing = false
	streaming_action = false
	stream_accumulator = 0.0
	map_open = false
	waystone_menu_open = false
	selected_action = ""
	timeline.clear()
	visual = _presentation_snapshot()
	state.save_run()
	autosave_pending = false
	_sync_setup_controls()
	queue_redraw()

func _select_loadout(choice: String) -> void:
	state.select_loadout(choice)
	selected_action = ""
	playing = false
	streaming_action = false
	stream_accumulator = 0.0
	pointer_down = false
	held_movement = false
	held_direction = Vector2.ZERO
	timeline.clear()
	visual = _presentation_snapshot()
	queue_redraw()

func _advance_or_wait() -> void:
	var interaction := state.interaction_label()
	if interaction == "WAIT": _begin_streamed_action(state.request_wait(0.50, false))
	else:
		state.request_context_action()
		if interaction == "REST": waystone_menu_open = state.can_learn_at_waystone()
		visual = _presentation_snapshot()
		_mark_autosave(true)
		queue_redraw()

func _try_waystone_press(position: Vector2) -> bool:
	if not bool(state.mode_config["waystone_available"]): return false
	var selected: Dictionary = {}
	for stone in state.waystones:
		if String(stone.get("layer", state.current_layer)) == state.current_layer and _world_to_screen(Vector2(stone["pos"])).distance_to(position) <= maxf(38.0, 42.0 * world_scale): selected = stone
	if selected.is_empty(): return false
	if state.player_pos.distance_to(Vector2(selected["pos"])) > state.WAYSTONE_RANGE:
		state.message = "Move closer to activate the Waystone."
		visual = _presentation_snapshot()
		queue_redraw()
		return true
	if not state.activate_waystone(): return true
	waystone_menu_open = state.can_learn_at_waystone()
	selected_action = ""
	visual = _presentation_snapshot()
	_mark_autosave(true)
	queue_redraw()
	return true

func _try_transition_press(position: Vector2) -> bool:
	for transition in state.transitions:
		var marker := Vector2.ZERO
		if String(transition["from_layer"]) == state.current_layer: marker = Vector2(transition["from_pos"])
		elif String(transition["to_layer"]) == state.current_layer: marker = Vector2(transition["to_pos"])
		else: continue
		if _world_to_screen(marker).distance_to(position) > maxf(38.0, 42.0 * world_scale): continue
		if state.player_pos.distance_to(marker) > 120.0:
			state.message = "Move closer to use this passage."
			visual = _presentation_snapshot()
			queue_redraw()
			return true
		state.use_transition()
		visual = _presentation_snapshot()
		_mark_autosave(true)
		queue_redraw()
		return true
	return false

func _waystone_option_rect(option: String) -> Rect2:
	return Rect2(buttons["potion"]).merge(Rect2(buttons["defense"])) if option == "learn" else Rect2(buttons["skill"]).merge(Rect2(buttons["wait"]))

func _handle_waystone_menu_press(position: Vector2) -> void:
	if _waystone_option_rect("learn").has_point(position):
		if state.learn_at_waystone(): waystone_menu_open = false
	elif _waystone_option_rect("continue").has_point(position):
		waystone_menu_open = false
	else: return
	visual = _presentation_snapshot()
	_mark_autosave(true)
	queue_redraw()

func _defense_cooldown() -> float:
	if state.defense_id == "block": return state.block_cooldown
	if state.defense_id == "endure": return state.endure_cooldown
	return state.dodge_cooldown

func _on_state_changed() -> void:
	_mark_autosave()
	_sync_setup_controls()
	queue_redraw()

func _presentation_snapshot() -> Dictionary:
	return state.snapshot(true)

func _mark_autosave(critical: bool = false) -> void:
	autosave_pending = true
	autosave_elapsed = 0.0
	if critical: _flush_autosave()

func _autosave_frame_is_quiet() -> bool:
	if playing or streaming_action or pointer_down or held_movement: return false
	if desktop_controls and not _desktop_held_direction().is_zero_approx(): return false
	return state == null or String(state.player_action.get("kind", "idle")) == "idle"

func _flush_autosave_if_quiet() -> void:
	if not autosave_pending:
		autosave_deferred = false
		return
	if not _autosave_frame_is_quiet() or autosave_quiet_elapsed < AUTOSAVE_QUIET_DELAY:
		autosave_deferred = false
		return
	_flush_autosave()

func _flush_autosave() -> void:
	if not autosave_pending:
		autosave_deferred = false
		return
	state.save_run()
	autosave_pending = false
	autosave_elapsed = 0.0
	autosave_quiet_elapsed = 0.0
	autosave_deferred = false

func _draw() -> void:
	var draw_start := Time.get_ticks_usec()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if not state.run_active:
		_draw_setup()
		state.performance_metrics["draw_cpu_ms"] = float(Time.get_ticks_usec() - draw_start) / 1000.0
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
	state.performance_metrics["draw_cpu_ms"] = float(Time.get_ticks_usec() - draw_start) / 1000.0

func _draw_world() -> void:
	draw_rect(board_rect, Color("05080a"))
	_draw_discovered_floor()
	_draw_grid()
	var discovered := _render_discovered_cells()
	var visible: Dictionary = _render_visible_cells()
	if view_mode == "top_down":
		for wall in _render_walls():
			if not _world_rect_on_camera(wall): continue
			var shortcut_gate := _locked_shortcut_for_wall(wall)
			if shortcut_gate.is_empty() and not state.is_discovered(wall.get_center(), discovered): continue
			if not shortcut_gate.is_empty() and not _shortcut_gate_is_discovered(shortcut_gate, discovered): continue
			if shortcut_gate.is_empty(): _draw_wall(wall)
			else: _draw_shortcut_gate(shortcut_gate)
		for feature in _render_features():
			var feature_pos := Vector2(feature["pos"])
			if String(feature.get("layer", state.current_layer)) == state.current_layer and _world_point_on_camera(feature_pos, float(feature.get("radius", 45.0)) * 2.5) and state.is_discovered(feature_pos, discovered): _draw_terrain_feature(feature)
	_draw_landmarks(visible, discovered)
	for projectile in Array(visual.get("projectiles", [])):
		if String(projectile.get("layer", state.current_layer)) != state.current_layer: continue
		if not _world_point_on_camera(Vector2(projectile["pos"]), 30.0): continue
		if not state.is_visible(Vector2(projectile["pos"]), visible): continue
		var center := _world_to_screen(Vector2(projectile["pos"]))
		var direction := _screen_direction(Vector2(projectile["vel"]).normalized())
		draw_line(center - direction * 15.0, center + direction * 9.0, Color("f1ce72"), maxf(2.0, world_scale * 8.0))
	for hazard in Array(visual.get("hazards", [])):
		if String(hazard.get("layer", state.current_layer)) != state.current_layer: continue
		if not _world_point_on_camera(Vector2(hazard["pos"]), float(hazard.get("radius", 100.0))): continue
		if state.is_visible(Vector2(hazard["pos"]), visible): _draw_hazard(hazard)
	if view_mode == "isometric":
		_draw_isometric_solids(visible, discovered)
	else:
		for enemy in Array(visual.get("enemies", [])):
			if String(enemy.get("layer", state.current_layer)) == state.current_layer and _world_point_on_camera(Vector2(enemy["pos"]), float(enemy.get("radius", 30.0)) * 2.5) and state.is_visible(Vector2(enemy["pos"]), visible): _draw_enemy(enemy)
		_draw_player()
	_draw_shortcut_gate_labels(discovered)
	for effect in Array(visual.get("effects", [])):
		if String(effect.get("layer", state.current_layer)) == state.current_layer and _world_point_on_camera(Vector2(effect["pos"]), 80.0) and state.is_visible(Vector2(effect["pos"]), visible): _draw_effect(effect)
	_draw_shadow_guidance()
	_draw_player_damage_overlay()
	_draw_selected_action_hint()
	var label := "TIME FLOWING" if playing else "TIME FROZEN"
	var color := Color("f0b45a") if playing else DODGE_COLOR
	var font := maxi(14, int(minf(size.x, size.y) * 0.026))
	draw_string(ThemeDB.fallback_font, board_rect.position + Vector2(12, font + 10), label, HORIZONTAL_ALIGNMENT_LEFT, board_rect.size.x * 0.5, font, color)
	var current_xp := int(visual.get("carried_xp", state.carried_xp))
	var safe_xp := int(visual.get("secured_xp", state.secured_xp))
	var risk_xp := maxi(0, current_xp - safe_xp)
	var area_text := "%s  •  %d XP" % [state.current_area_name().to_upper(), current_xp]
	if state.mode_id == "campaign_lab":
		area_text = "%s  •  TIMELINE SECURE" % state.current_area_name().to_upper() if risk_xp == 0 else "%s  •  %d XP AT RISK" % [state.current_area_name().to_upper(), risk_xp]
	var area_width := minf(board_rect.size.x * 0.50, 360.0)
	var area_x := board_rect.position.x + (board_rect.size.x - area_width) * 0.5
	draw_string(ThemeDB.fallback_font, Vector2(area_x, board_rect.position.y + font + 10), area_text, HORIZONTAL_ALIGNMENT_CENTER, area_width, font, Color("9fb2b7"))
	_draw_player_health_bar(font)
	_draw_player_progress_bar(font)

func _draw_isometric_solids(visible: Dictionary, discovered: Dictionary) -> void:
	var entries: Array[Dictionary] = []
	for wall in _render_walls():
		if not _world_rect_on_camera(wall): continue
		var shortcut_gate := _locked_shortcut_for_wall(wall)
		if shortcut_gate.is_empty() and not state.is_discovered(wall.get_center(), discovered): continue
		if not shortcut_gate.is_empty() and not _shortcut_gate_is_discovered(shortcut_gate, discovered): continue
		if shortcut_gate.is_empty(): entries.append({"kind": "wall", "wall": wall, "depth": _wall_depth(wall)})
		else: entries.append({"kind": "shortcut_gate", "shortcut": shortcut_gate, "depth": _wall_depth(wall)})
	for enemy in Array(visual.get("enemies", [])):
		if String(enemy.get("layer", state.current_layer)) != state.current_layer: continue
		if not _world_point_on_camera(Vector2(enemy["pos"]), float(enemy.get("radius", 30.0)) * 2.5): continue
		if not state.is_visible(Vector2(enemy["pos"]), visible): continue
		entries.append({"kind": "enemy", "enemy": enemy, "depth": _world_to_screen(Vector2(enemy["pos"])).y})
	for feature in _render_features():
		if String(feature.get("layer", state.current_layer)) != state.current_layer: continue
		var feature_pos := Vector2(feature["pos"])
		if not _world_point_on_camera(feature_pos, float(feature.get("radius", 45.0)) * 2.5): continue
		if not state.is_discovered(feature_pos, discovered): continue
		entries.append({"kind": "feature", "feature": feature, "depth": _world_to_screen(feature_pos).y})
	entries.append({"kind": "player", "depth": _world_to_screen(Vector2(visual.get("player_pos", state.player_pos))).y})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["depth"]), float(b["depth"])): return String(a["kind"]) == "wall"
		return float(a["depth"]) < float(b["depth"])
	)
	for entry in entries:
		match String(entry["kind"]):
			"wall":
				var wall := Rect2(entry["wall"])
				_draw_wall(wall, _wall_occlusion_alpha(wall))
			"shortcut_gate":
				var shortcut := Dictionary(entry["shortcut"])
				var gate_rect := Rect2(shortcut["gate"])
				_draw_shortcut_gate(shortcut, _wall_occlusion_alpha(gate_rect))
			"enemy": _draw_enemy(Dictionary(entry["enemy"]))
			"feature": _draw_terrain_feature(Dictionary(entry["feature"]))
			"player": _draw_player()

func _render_query_radius() -> float:
	var center := _camera_world_position()
	var radius := 0.0
	for screen_point in [board_rect.position, Vector2(board_rect.end.x, board_rect.position.y), board_rect.end, Vector2(board_rect.position.x, board_rect.end.y)]:
		radius = maxf(radius, center.distance_to(_screen_to_world(screen_point)))
	return radius + 220.0

func _render_walls() -> Array[Rect2]:
	_refresh_static_render_query()
	return _cached_render_walls

func _render_features() -> Array[Dictionary]:
	_refresh_static_render_query()
	return _cached_render_features

func _refresh_static_render_query() -> void:
	var camera := _camera_world_position()
	var cache_valid := _static_query_revision == state.world_render_revision \
		and _static_query_layer == state.current_layer \
		and _static_query_view == view_mode \
		and is_equal_approx(_static_query_scale, world_scale) \
		and _static_query_anchor.is_finite() \
		and _static_query_anchor.distance_to(camera) <= RENDER_QUERY_REUSE_DISTANCE
	if cache_valid: return
	_static_query_revision = state.world_render_revision
	_static_query_layer = state.current_layer
	_static_query_view = view_mode
	_static_query_scale = world_scale
	_static_query_anchor = camera
	var radius := _render_query_radius() + RENDER_QUERY_REUSE_DISTANCE + 80.0
	_cached_render_walls = state.nearby_render_walls(camera, radius)
	_cached_render_features = state.nearby_terrain_features(camera, radius)

func _wall_depth(wall: Rect2) -> float:
	var corners := [wall.position, Vector2(wall.end.x, wall.position.y), wall.end, Vector2(wall.position.x, wall.end.y)]
	var depth := -INF
	for corner in corners: depth = maxf(depth, _world_to_screen(Vector2(corner)).y)
	return depth

func _wall_occlusion_alpha(wall: Rect2) -> float:
	var base := _project_world_rect(wall)
	if base.is_empty(): return 1.0
	var bounds := Rect2(base[0], Vector2.ZERO)
	for point in base: bounds = bounds.expand(point)
	bounds = bounds.expand(bounds.position - Vector2(0.0, ISO_WALL_HEIGHT * world_scale))
	var player_foot := _world_to_screen(Vector2(visual.get("player_pos", state.player_pos)))
	var player_radius := state.PLAYER_RADIUS * world_scale
	var player_bounds := Rect2(player_foot + Vector2(-player_radius, -player_radius * 2.65), Vector2(player_radius * 2.0, player_radius * 2.9))
	return 0.30 if bounds.intersects(player_bounds, true) else 1.0

func _draw_shadow_guidance() -> void:
	var shadow: Dictionary = visual.get("lost_xp", state.lost_xp)
	if not bool(shadow.get("active", false)): return
	var player_world := Vector2(visual.get("player_pos", state.player_pos))
	var shadow_world := Vector2(shadow.get("pos", Vector2.ZERO))
	var distance := player_world.distance_to(shadow_world)
	if distance > 850.0 or distance < 70.0: return
	var direction := (shadow_world - player_world).normalized()
	var side := direction.rotated(PI * 0.5)
	var strength := clampf(1.0 - (distance - 70.0) / 780.0, 0.18, 0.78)
	for index in range(4):
		var center_world := player_world + direction * (75.0 + index * 48.0)
		var center := _world_to_screen(center_world)
		var radius := (5.0 + index * 1.5) * world_scale
		draw_circle(center, radius, Color(0.85, 0.95, 0.48, strength * (0.35 + index * 0.12)))
		if index == 3:
			var facing := _screen_direction(direction)
			var screen_side := _screen_direction(side)
			draw_colored_polygon(PackedVector2Array([center + facing * radius * 2.3, center - facing * radius + screen_side * radius, center - facing * radius - screen_side * radius]), Color(0.85, 0.95, 0.48, strength))

func _draw_grid() -> void:
	if state.geometry_style == "organic": return
	var color := Color(0.18, 0.29, 0.32, 0.35)
	var visible: Dictionary = _render_visible_cells()
	for cell in visible:
		var top_left := Vector2(cell) * state.VISIBILITY_CELL
		var center := top_left + Vector2.ONE * state.VISIBILITY_CELL * 0.5
		if int(cell.x) % 2 == 0: draw_line(_world_to_screen(Vector2(top_left.x, top_left.y)), _world_to_screen(Vector2(top_left.x, top_left.y + state.VISIBILITY_CELL)), color)
		if int(cell.y) % 2 == 0: draw_line(_world_to_screen(Vector2(top_left.x, top_left.y)), _world_to_screen(Vector2(top_left.x + state.VISIBILITY_CELL, top_left.y)), color)

func _draw_discovered_floor() -> void:
	_refresh_floor_geometry_cache()
	var visible: Dictionary = _render_visible_cells()
	var bounds := _camera_cell_bounds()
	var first_chunk := Vector2i(int(floor(float(bounds.position.x) / FLOOR_RENDER_CHUNK_CELLS)), int(floor(float(bounds.position.y) / FLOOR_RENDER_CHUNK_CELLS)))
	var last_cell := bounds.end - Vector2i.ONE
	var last_chunk := Vector2i(int(floor(float(last_cell.x) / FLOOR_RENDER_CHUNK_CELLS)), int(floor(float(last_cell.y) / FLOOR_RENDER_CHUNK_CELLS)))
	var ground_color := state.current_ground_color()
	var hidden_color := ground_color.darkened(0.72)
	draw_set_transform(_projection_origin())
	for chunk_x in range(first_chunk.x, last_chunk.x + 1):
		for chunk_y in range(first_chunk.y, last_chunk.y + 1):
			for cell_value in Array(_floor_cells_by_chunk.get(Vector2i(chunk_x, chunk_y), [])):
				var cell := Vector2i(cell_value)
				if not bounds.has_point(cell): continue
				var color := ground_color if visible.has(cell) else hidden_color
				if view_mode == "top_down": draw_rect(Rect2(_floor_top_down_geometry[cell]), color)
				else: draw_colored_polygon(PackedVector2Array(_floor_iso_geometry[cell]), color)
	draw_set_transform(Vector2.ZERO)

func _refresh_floor_geometry_cache() -> void:
	var identity_changed := _floor_cache_epoch != state.discovery_epoch \
		or _floor_cache_seed != state.run_seed \
		or _floor_cache_layer != state.current_layer \
		or _floor_cache_view != view_mode \
		or not is_equal_approx(_floor_cache_scale, world_scale)
	if identity_changed:
		_floor_cache_epoch = state.discovery_epoch
		_floor_cache_seed = state.run_seed
		_floor_cache_layer = state.current_layer
		_floor_cache_view = view_mode
		_floor_cache_scale = world_scale
		_clear_floor_geometry_cache()
		for cell_value in _render_discovered_cells(): _cache_floor_cell(Vector2i(cell_value))
		state.discovery_log.clear()
		_floor_cache_revision = state.discovery_revision
		return
	if _floor_cache_revision == state.discovery_revision: return
	for cell_value in state.discovery_log:
		var cell := Vector2i(cell_value)
		if state.discovered_cells.has(cell): _cache_floor_cell(cell)
	state.discovery_log.clear()
	_floor_cache_revision = state.discovery_revision

func _clear_floor_geometry_cache() -> void:
	_floor_cells_by_chunk.clear()
	_floor_iso_geometry.clear()
	_floor_top_down_geometry.clear()

func _cache_floor_cell(cell: Vector2i) -> void:
	if _floor_iso_geometry.has(cell): return
	var chunk := Vector2i(int(floor(float(cell.x) / FLOOR_RENDER_CHUNK_CELLS)), int(floor(float(cell.y) / FLOOR_RENDER_CHUNK_CELLS)))
	if not _floor_cells_by_chunk.has(chunk): _floor_cells_by_chunk[chunk] = []
	_floor_cells_by_chunk[chunk].append(cell)
	var top_left := Vector2(cell) * state.VISIBILITY_CELL
	_floor_top_down_geometry[cell] = Rect2(top_left * world_scale, Vector2.ONE * state.VISIBILITY_CELL * world_scale + Vector2.ONE)
	_floor_iso_geometry[cell] = PackedVector2Array([
		_project_world_without_camera(top_left),
		_project_world_without_camera(top_left + Vector2(state.VISIBILITY_CELL, 0.0)),
		_project_world_without_camera(top_left + Vector2.ONE * state.VISIBILITY_CELL),
		_project_world_without_camera(top_left + Vector2(0.0, state.VISIBILITY_CELL)),
	])

func _project_world_without_camera(world: Vector2) -> Vector2:
	if view_mode == "isometric": return Vector2((world.x - world.y) * 0.5, (world.x + world.y) * 0.25) * world_scale
	return world * world_scale

func _draw_wall(wall: Rect2, alpha: float = 1.0) -> void:
	if view_mode == "top_down":
		var rect := Rect2(_world_to_screen(wall.position), wall.size * world_scale)
		draw_rect(rect, Color(WALL, alpha))
		draw_rect(rect.grow(-3.0), Color(Color("29363c"), alpha), false, 2.0)
		return
	var base := _project_world_rect(wall)
	var lift := Vector2(0.0, -ISO_WALL_HEIGHT * world_scale)
	var top := PackedVector2Array()
	for point in base: top.append(point + lift)
	draw_colored_polygon(PackedVector2Array([top[2], top[3], base[3], base[2]]), Color(Color("26343a"), alpha))
	draw_colored_polygon(PackedVector2Array([top[1], top[2], base[2], base[1]]), Color(Color("2d3b42"), alpha))
	draw_colored_polygon(top, Color(WALL, alpha))
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), Color(Color("718087"), alpha), maxf(1.5, world_scale))

func _locked_shortcut_for_wall(wall: Rect2) -> Dictionary:
	for shortcut in state.shortcuts:
		if bool(shortcut.get("unlocked", false)) or String(shortcut.get("layer", state.current_layer)) != state.current_layer: continue
		if Rect2(shortcut["gate"]) == wall: return shortcut
	return {}

func _shortcut_gate_is_discovered(shortcut: Dictionary, discovered: Dictionary) -> bool:
	var gate := Rect2(shortcut["gate"])
	return state.is_discovered(gate.get_center(), discovered) or state.is_discovered(Vector2(shortcut.get("near_pos", gate.get_center())), discovered) or state.is_discovered(Vector2(shortcut.get("far_pos", gate.get_center())), discovered)

func _draw_shortcut_gate(shortcut: Dictionary, alpha: float = 1.0) -> void:
	if String(shortcut.get("presentation", "")) == "hidden_woodland_path":
		_draw_hidden_woodland_barrier(shortcut, alpha)
		return
	var wall := Rect2(shortcut["gate"])
	var bark := Color(Color("71482f"), alpha)
	var dark_bark := Color(Color("33251d"), alpha)
	var edge := Color(Color("e19a58"), alpha)
	if view_mode == "top_down":
		var rect := Rect2(_world_to_screen(wall.position), wall.size * world_scale)
		draw_rect(rect, dark_bark)
		draw_rect(rect.grow(-maxf(2.0, 5.0 * world_scale)), bark)
		var vertical := wall.size.y > wall.size.x
		for ratio in [0.16, 0.34, 0.53, 0.72, 0.88]:
			if vertical:
				var y := lerpf(rect.position.y, rect.end.y, float(ratio))
				draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y + 8.0 * world_scale), edge, maxf(2.0, 4.0 * world_scale))
			else:
				var x := lerpf(rect.position.x, rect.end.x, float(ratio))
				draw_line(Vector2(x, rect.position.y), Vector2(x + 8.0 * world_scale, rect.end.y), edge, maxf(2.0, 4.0 * world_scale))
		return
	var base := _project_world_rect(wall)
	var lift := Vector2(0.0, -ISO_WALL_HEIGHT * world_scale)
	var top := PackedVector2Array()
	for point in base: top.append(point + lift)
	draw_colored_polygon(PackedVector2Array([top[2], top[3], base[3], base[2]]), dark_bark)
	draw_colored_polygon(PackedVector2Array([top[1], top[2], base[2], base[1]]), bark.darkened(0.12))
	draw_colored_polygon(top, bark)
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), edge, maxf(2.0, 2.5 * world_scale))
	for ratio in [0.20, 0.40, 0.60, 0.80]:
		var start := top[0].lerp(top[3], float(ratio))
		var finish := top[1].lerp(top[2], float(ratio))
		draw_line(start, finish, edge.darkened(0.18), maxf(2.0, 3.5 * world_scale))

func _draw_hidden_woodland_barrier(shortcut: Dictionary, alpha: float = 1.0) -> void:
	var gate := Rect2(shortcut["gate"])
	var vertical := gate.size.y > gate.size.x
	var start := Vector2(gate.get_center().x, gate.position.y) if vertical else Vector2(gate.position.x, gate.get_center().y)
	var finish := Vector2(gate.get_center().x, gate.end.y) if vertical else Vector2(gate.end.x, gate.get_center().y)
	for index in range(5):
		var ratio := float(index) / 4.0
		var position := start.lerp(finish, ratio)
		var feature := {"kind": "tree", "pos": position, "radius": 58.0 if index % 2 == 0 else 50.0, "layer": state.current_layer}
		_draw_terrain_feature(feature)
	if view_mode == "top_down":
		var center := _world_to_screen(gate.get_center())
		draw_circle(center, 24.0 * world_scale, Color(0.08, 0.18, 0.09, 0.72 * alpha))

func _draw_shortcut_gate_labels(discovered: Dictionary) -> void:
	for shortcut in state.shortcuts:
		if bool(shortcut.get("unlocked", false)) or String(shortcut.get("layer", state.current_layer)) != state.current_layer: continue
		var gate := Rect2(shortcut["gate"])
		if not _shortcut_gate_is_discovered(shortcut, discovered) or not _world_rect_on_camera(gate.grow(90.0)): continue
		var gate_screen := _world_to_screen(gate.get_center())
		var activation_world := Vector2(shortcut["unlock_pos"])
		var interaction_radius := float(shortcut.get("interaction_radius", 115.0))
		var can_unlock := state.player_pos.distance_to(activation_world) <= interaction_radius + 35.0
		var hidden_path := String(shortcut.get("presentation", "")) == "hidden_woodland_path"
		if hidden_path and not can_unlock: continue
		var label := "CLEAR HIDDEN PATH" if hidden_path else "UNLOCK ROOT GATE" if can_unlock else "SEALED ROOT GATE"
		var label_rect := Rect2(gate_screen + Vector2(-82, -38), Vector2(164, 24))
		draw_rect(label_rect, Color(0.035, 0.045, 0.04, 0.86))
		draw_rect(label_rect, Color("e19a58") if can_unlock else Color("b8664d"), false, 2.0)
		draw_string(ThemeDB.fallback_font, label_rect.position + Vector2(0, 17), label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, 11, Color("fff0cf"))

func _draw_terrain_feature(feature: Dictionary) -> void:
	var world_pos := Vector2(feature["pos"])
	var foot := _world_to_screen(world_pos)
	var radius := float(feature.get("radius", 44.0)) * world_scale
	var kind := String(feature.get("kind", "tree"))
	if kind in ["brook", "old_road"]:
		var start := _world_to_screen(Vector2(feature.get("from", world_pos - Vector2.RIGHT * float(feature.get("radius", 300.0)))))
		var finish := _world_to_screen(Vector2(feature.get("to", world_pos + Vector2.RIGHT * float(feature.get("radius", 300.0)))))
		var color := Color(0.22, 0.50, 0.64, 0.78) if kind == "brook" else Color(0.39, 0.31, 0.20, 0.62)
		var edge := Color(0.58, 0.69, 0.52, 0.72) if kind == "brook" else Color(0.56, 0.45, 0.28, 0.46)
		draw_line(start, finish, edge, maxf(10.0, 22.0 * world_scale))
		draw_line(start, finish, color, maxf(5.0, 12.0 * world_scale))
		return
	if kind == "meadow":
		draw_circle(foot, radius * 0.46, Color(0.54, 0.72, 0.34, 0.16))
		for index in range(7):
			var flower := foot + Vector2.RIGHT.rotated(float(index) * 2.399) * radius * (0.16 + 0.06 * index)
			draw_circle(flower, maxf(1.5, 2.5 * world_scale), Color("e5d77a") if index % 2 == 0 else Color("d9b7d7"))
		return
	if kind == "flowers":
		for index in range(4): draw_circle(foot + Vector2.RIGHT.rotated(float(index) * 1.7) * radius * 0.35, maxf(1.4, radius * 0.10), Color("e9d77c"))
		return
	if kind == "stone_circle":
		for index in range(8):
			var stone := foot + _screen_direction(Vector2.RIGHT.rotated(TAU * float(index) / 8.0)) * radius * 0.66
			draw_circle(stone, maxf(3.0, radius * 0.10), Color("8f9586"))
		return
	if kind in ["roots", "undergrowth"]:
		var root_color := Color("4f5a35") if kind == "roots" else Color("41613b")
		for index in range(3):
			var direction := _screen_direction(Vector2.RIGHT.rotated(float(index) * 2.05 + 0.35))
			draw_line(foot - direction * radius * 0.10, foot + direction * radius * (0.42 + index * 0.08), root_color, maxf(2.0, radius * 0.07))
		return
	if kind in ["ancient_ruin", "ruin_fragment"]:
		var ruin_color := Color("74766a")
		var width := radius * (0.62 if kind == "ancient_ruin" else 0.38)
		draw_rect(Rect2(foot - Vector2(width, radius * 0.16), Vector2(width * 2.0, radius * 0.32)), Color(0.05, 0.06, 0.05, 0.42))
		draw_line(foot - Vector2(width, 0), foot + Vector2(width, 0), ruin_color, maxf(3.0, radius * 0.10))
		draw_line(foot - Vector2(width * 0.55, 0), foot - Vector2(width * 0.55, radius * 0.42), ruin_color.darkened(0.12), maxf(3.0, radius * 0.09))
		return
	var underground := String(feature.get("layer", state.current_layer)) == "ruin_depths"
	var trunk_color := Color("394638") if not underground else Color("3e4138")
	var canopy_color := Color("294f31") if kind == "heart_tree" else Color("315e39") if not underground else Color("52614a")
	if view_mode == "top_down":
		draw_circle(foot, radius * 0.88, Color(0.02, 0.04, 0.025, 0.62))
		draw_circle(foot, radius * 0.72, canopy_color)
		draw_circle(foot, maxf(3.0, radius * 0.20), trunk_color)
		return
	var trunk_top := foot + Vector2(0.0, -radius * 1.25)
	draw_line(foot, trunk_top, trunk_color, maxf(3.0, radius * 0.24))
	draw_circle(trunk_top, radius * 0.82, Color(0.015, 0.03, 0.02, 0.72))
	draw_circle(trunk_top + Vector2(0.0, -radius * 0.08), radius * 0.68, canopy_color)
	draw_arc(trunk_top, radius * 0.70, 0.0, TAU, 18, canopy_color.lightened(0.16), maxf(1.5, radius * 0.07))

func _draw_player() -> void:
	var world_pos := Vector2(visual.get("player_pos", state.player_pos))
	var world_facing := Vector2(visual.get("player_facing", Vector2.UP)).normalized()
	var foot := _world_to_screen(world_pos)
	var pos := _actor_visual_center(world_pos, state.PLAYER_RADIUS)
	var facing := _screen_direction(world_facing)
	var action: Dictionary = visual.get("player_action", {})
	var collision_radius := state.PLAYER_RADIUS * world_scale
	var radius := _actor_body_radius(state.PLAYER_RADIUS)
	_draw_actor_footprint(world_pos, state.PLAYER_RADIUS, Color("f5fbff"), true)
	if float(visual.get("strength_remaining", 0.0)) > 0.0:
		if view_mode == "isometric": _draw_projected_world_circle(world_pos, state.PLAYER_RADIUS * 1.65, Color(0.91, 0.32, 0.20, 0.16), Color("e85c3f"), maxf(2.0, collision_radius * 0.12))
		else:
			draw_circle(pos, collision_radius * 1.65, Color(0.91, 0.32, 0.20, 0.16))
			draw_arc(pos, collision_radius * 1.65, 0.0, TAU, 24, Color("e85c3f"), maxf(2.0, collision_radius * 0.12))
	if String(action.get("kind", "idle")) == "dodge":
		if view_mode == "isometric": _draw_projected_world_circle(world_pos - world_facing * state.PLAYER_RADIUS * 0.7, state.PLAYER_RADIUS * 1.25, Color(DODGE_COLOR, 0.16))
		else: draw_circle(pos - facing * collision_radius * 0.7, collision_radius * 1.25, Color(DODGE_COLOR, 0.16))
	_draw_actor(pos, foot, facing, radius, PLAYER_COLOR, Color("ffffff"))
	if String(action.get("kind", "idle")) in ["attack", "sweep"]: _draw_weapon(world_pos, action, true)
	elif String(action.get("kind", "idle")) == "block": _draw_guard(pos, facing, radius, action)
	elif String(action.get("kind", "idle")) == "endure": _draw_endure(pos, radius, action)
	elif String(action.get("kind", "idle")) == "potion": draw_circle(pos + Vector2(radius * 0.7, -radius * 0.8), radius * 0.25, Color("e35f62"))
	var phase := _phase(action)
	if phase != "": draw_string(ThemeDB.fallback_font, pos + Vector2(-radius * 2.2, -radius * 2.05), phase, HORIZONTAL_ALIGNMENT_CENTER, radius * 4.4, maxi(9, int(radius * 0.55)), Color("d8f4f1"))

func _draw_enemy(enemy: Dictionary) -> void:
	var world_pos := Vector2(enemy["pos"])
	var foot := _world_to_screen(world_pos)
	var world_radius := float(enemy["radius"])
	var pos := _actor_visual_center(world_pos, world_radius)
	var facing := _screen_direction(Vector2(enemy["facing"]).normalized())
	var collision_radius := world_radius * world_scale
	var radius := _actor_body_radius(world_radius)
	var kind := String(enemy["kind"])
	var colors := {"knife": Color("e5be55"), "blade": BLADE_COLOR, "polearm": POLEARM_COLOR, "archer": ARCHER_COLOR, "shield": Color("6aa9c9"), "hound": Color("d9a75b"), "brute": Color("9f554d"), "hexer": Color("9e72d8"), "captain": Color("e0c24e"), "warden": Color("d84b65")}
	var color: Color = colors.get(kind, BLADE_COLOR)
	_draw_actor_footprint(world_pos, world_radius, color.lightened(0.28), false)
	if kind == "captain": draw_arc(pos, radius * 1.5, 0.0, TAU, 20, Color(color, 0.45), maxf(2.0, radius * 0.12))
	_draw_actor(pos, foot, facing, radius, color, color.lightened(0.46))
	_draw_enemy_identity(kind, pos, facing, radius, color)
	if kind == "shield": _draw_guard(pos, facing, radius, {"elapsed": 0.5, "startup": 0.0, "active_end": 1.0})
	var action: Dictionary = enemy["action"]
	if String(action["kind"]) == "melee": _draw_weapon(world_pos, action, false)
	elif String(action["kind"]) == "shoot": _draw_bow(pos, facing, radius, action)
	elif String(action["kind"]) == "charge": draw_line(pos, pos - facing * radius * 2.2, Color(color, 0.5), maxf(3.0, radius * 0.25))
	elif String(action["kind"]) == "slam":
		if view_mode == "isometric": _draw_projected_world_circle(world_pos, float(action.get("reach", 205.0)), Color.TRANSPARENT, Color(color, 0.45), maxf(3.0, collision_radius * 0.13))
		else: draw_arc(pos, float(action.get("reach", 205.0)) * world_scale, 0.0, TAU, 28, Color(color, 0.45), maxf(3.0, collision_radius * 0.13))
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

func _draw_actor(pos: Vector2, foot: Vector2, facing: Vector2, radius: float, color: Color, marker_color: Color) -> void:
	if view_mode == "isometric":
		draw_line(foot, pos + Vector2(0.0, radius * 0.45), Color(0.02, 0.03, 0.04, 0.66), maxf(1.5, radius * 0.16))
	draw_circle(pos, radius, Color(0.015, 0.025, 0.035, 0.94))
	draw_circle(pos, radius * 0.84, color)
	draw_arc(pos, radius, 0.0, TAU, 24, color.lightened(0.28), maxf(1.5, radius * 0.11))
	var marker := _actor_marker_points(pos, facing, radius)
	draw_colored_polygon(marker, marker_color)
	draw_polyline(PackedVector2Array([marker[0], marker[1], marker[2], marker[0]]), Color(0.015, 0.025, 0.035, 0.94), maxf(1.0, radius * 0.09))

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
	var visual_lift := Vector2(0.0, -_weapon_visual_height(technique))
	var weapon_start := _world_to_screen(Vector2(sample["weapon_start"])) + visual_lift
	var weapon_end := _world_to_screen(Vector2(sample["weapon_end"])) + visual_lift
	var screen_direction := (weapon_end - weapon_start).normalized()
	var side := screen_direction.rotated(PI * 0.5)
	var active := bool(sample.get("active", false))
	var color := Color("fff1b8") if player_weapon else Color("ead9c8")
	var width := maxf(2.0, world_scale * (4.0 if technique in ["heavy_chop", "heavy_cleave", "forward_smash"] else 2.7))
	if technique == "bite":
		var bite_shape := _project_world_circle(Vector2(sample.get("center", sample["weapon_end"])), float(sample.get("head_radius", 20.0)))
		_offset_points(bite_shape, visual_lift)
		draw_colored_polygon(bite_shape, Color(color, 0.14 if not active else 0.28))
		draw_polyline(_closed_points(bite_shape), Color(color, 0.72), maxf(1.5, width * 0.55))
		var jaw := maxf(8.0, float(sample.get("head_radius", 20.0)) * world_scale * 0.44)
		draw_line(weapon_end - screen_direction * jaw + side * jaw * 0.55, weapon_end + screen_direction * jaw * 0.35, color, width)
		draw_line(weapon_end - screen_direction * jaw - side * jaw * 0.55, weapon_end + screen_direction * jaw * 0.35, color, width)
		return
	if String(sample.get("shape", "")) == "segment":
		var body := _project_world_capsule(Vector2(sample["start"]), Vector2(sample["end"]), float(sample.get("radius", 8.0)))
		_offset_points(body, visual_lift)
		draw_colored_polygon(body, Color(color, 0.13 if not active else 0.24))
		draw_polyline(_closed_points(body), Color(color, 0.50 if not active else 0.86), maxf(1.0, width * 0.42))
	draw_line(weapon_start, weapon_end, color, width)
	if technique == "thrust":
		var tip := maxf(5.0, world_scale * 8.0)
		draw_colored_polygon(PackedVector2Array([weapon_end + screen_direction * tip, weapon_end - screen_direction * tip * 0.65 + side * tip * 0.55, weapon_end - screen_direction * tip * 0.65 - side * tip * 0.55]), color)
	elif technique == "forward_smash":
		var head_shape := _project_world_circle(Vector2(sample.get("center", sample["weapon_end"])), float(sample.get("head_radius", 30.0)))
		_offset_points(head_shape, visual_lift)
		draw_colored_polygon(head_shape, Color(color, 0.92))
		draw_polyline(_closed_points(head_shape), color.lightened(0.2), maxf(2.0, width * 0.5))
	elif technique in ["heavy_chop", "heavy_cleave"]:
		draw_line(weapon_end - screen_direction * maxf(12.0, world_scale * 20.0), weapon_end, color.lightened(0.16), width * 1.8)
	if active: draw_circle(weapon_end, maxf(2.0, width * 0.55), Color(color, 0.75))

func _weapon_visual_height(technique: String) -> float:
	if view_mode != "isometric": return 0.0
	var factor := 7.0 if technique in ["bite", "forward_smash"] else 11.0
	return factor * world_scale

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
	elif kind == "recover": color = Color("d8ed78")
	elif kind == "anchor": color = Color("f0b45a")
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
	elif kind in ["recover", "anchor"]:
		for index in range(10):
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / 10.0)
			draw_line(center + direction * radius * 0.35, center + direction * radius * 1.25, Color(color, alpha), maxf(2.0, 5.0 * alpha))
		var amount := int(effect.get("amount", 0))
		var label := "+%d XP RECLAIMED" % amount if kind == "recover" else "INTEGRATED" if amount == 0 else "+%d XP INTEGRATED" % amount
		draw_string(ThemeDB.fallback_font, center + Vector2(-100.0, -40.0 - progress * 35.0), label, HORIZONTAL_ALIGNMENT_CENTER, 200.0, maxi(14, int(18.0 * world_scale)), Color(color, alpha))
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

func _draw_player_progress_bar(header_font: int) -> void:
	var carried := int(visual.get("carried_xp", state.carried_xp))
	var secured := mini(carried, int(visual.get("secured_xp", state.secured_xp))) if state.mode_id == "campaign_lab" else 0
	var risk := maxi(0, carried - secured)
	var target := maxi(1, maxi(state.next_upgrade_cost(), carried))
	var width := minf(board_rect.size.x * 0.50, 340.0)
	var health_height := clampf(board_rect.size.y * 0.016, 15.0, 24.0)
	var height := clampf(board_rect.size.y * 0.013, 12.0, 19.0)
	var bar := Rect2(Vector2(board_rect.get_center().x - width * 0.5, board_rect.position.y + header_font + 42.0 + health_height), Vector2(width, height))
	draw_rect(bar.grow(3.0), Color(0.03, 0.05, 0.06, 0.94))
	draw_rect(bar, Color("171d20"))
	if state.mode_id == "campaign_lab":
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(secured) / float(target), bar.size.y)), Color("d7aa58"))
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * float(secured) / float(target), 0.0), Vector2(bar.size.x * float(risk) / float(target), bar.size.y)), Color("b9d85d"))
	else:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(carried) / float(target), bar.size.y)), Color("d7aa58"))
	draw_rect(bar, Color("d8ddd8"), false, 1.5)
	var label := "XP  %d / %d" % [carried, state.next_upgrade_cost()]
	if state.mode_id == "campaign_lab": label = "INTEGRATED %d   •   AT RISK %d   •   NEXT %d" % [secured, risk, state.next_upgrade_cost()]
	draw_string(ThemeDB.fallback_font, bar.position + Vector2(0.0, height * 0.78), label, HORIZONTAL_ALIGNMENT_CENTER, width, maxi(9, int(height * 0.66)), Color("f4f2e9"))

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

func _actor_visual_center(world_pos: Vector2, world_radius: float) -> Vector2:
	var foot := _world_to_screen(world_pos)
	if view_mode == "top_down": return foot
	return foot + Vector2(0.0, -world_radius * world_scale * 0.32)

func _actor_body_radius(world_radius: float) -> float:
	var scale_factor := 0.56 if view_mode == "isometric" else 0.62
	return maxf(7.0, world_radius * world_scale * scale_factor)

func _actor_marker_points(pos: Vector2, facing: Vector2, radius: float) -> PackedVector2Array:
	var direction := facing.normalized()
	if direction.length_squared() < 0.01: direction = Vector2.UP
	var side := direction.rotated(PI * 0.5)
	var tip := pos + direction * radius * 1.78
	var base := pos + direction * radius * 1.12
	return PackedVector2Array([tip, base + side * radius * 0.26, base - side * radius * 0.26])

func _draw_actor_footprint(world_pos: Vector2, world_radius: float, outline: Color, player: bool) -> void:
	var fill_alpha := 0.36 if player else 0.22
	var outline_alpha := 0.82 if player or debug_hitboxes else 0.34
	_draw_projected_world_circle(world_pos, world_radius, Color(0.01, 0.02, 0.025, fill_alpha), Color(outline, outline_alpha), maxf(1.5, world_scale * (2.4 if player else 1.4)))
	if debug_hitboxes:
		_draw_projected_world_circle(world_pos, world_radius, Color.TRANSPARENT, Color("ff4fd8"), maxf(2.0, world_scale * 2.0))

func _draw_projected_world_circle(center: Vector2, radius: float, fill: Color, outline: Color = Color.TRANSPARENT, outline_width: float = 0.0) -> void:
	var points := _project_world_circle(center, radius)
	if fill.a > 0.001: draw_colored_polygon(points, fill)
	if outline.a > 0.001 and outline_width > 0.0: draw_polyline(_closed_points(points), outline, outline_width)

func _project_world_circle(center: Vector2, radius: float, segments: int = 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var world_point := center + Vector2.RIGHT.rotated(TAU * float(index) / float(segments)) * radius
		points.append(_world_to_screen(world_point))
	return points

func _project_world_capsule(start: Vector2, finish: Vector2, radius: float, cap_segments: int = 8) -> PackedVector2Array:
	var segment := finish - start
	if segment.length_squared() < 0.001: return _project_world_circle(start, radius, cap_segments * 2)
	var angle := segment.angle()
	var points := PackedVector2Array()
	for index in range(cap_segments + 1):
		var cap_angle := angle + PI * 0.5 + PI * float(index) / float(cap_segments)
		points.append(_world_to_screen(start + Vector2.RIGHT.rotated(cap_angle) * radius))
	for index in range(cap_segments + 1):
		var cap_angle := angle - PI * 0.5 + PI * float(index) / float(cap_segments)
		points.append(_world_to_screen(finish + Vector2.RIGHT.rotated(cap_angle) * radius))
	return points

func _project_world_rect(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([_world_to_screen(rect.position), _world_to_screen(Vector2(rect.end.x, rect.position.y)), _world_to_screen(rect.end), _world_to_screen(Vector2(rect.position.x, rect.end.y))])

func _offset_points(points: PackedVector2Array, offset: Vector2) -> void:
	for index in range(points.size()): points[index] += offset

func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array()
	for point in points: closed.append(point)
	if not points.is_empty(): closed.append(points[0])
	return closed

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
	var hp_text := "XP %d/%d  •  EXPEDITION" % [int(visual.get("carried_xp", state.carried_xp)), state.next_upgrade_cost()]
	if state.mode_id == "campaign_lab":
		var safe := int(visual.get("secured_xp", state.secured_xp))
		var risk := maxi(0, int(visual.get("carried_xp", state.carried_xp)) - safe)
		hp_text = "INT %d  •  RISK %d" % [safe, risk]
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
	var label := "RESET [R]" if desktop_controls else "RESET"
	draw_string(ThemeDB.fallback_font, reset_rect.position + Vector2(0.0, reset_rect.size.y * 0.61), label, HORIZONTAL_ALIGNMENT_CENTER, reset_rect.size.x, font, Color("b7c0c2"))

func _draw_map_button() -> void:
	draw_rect(map_rect, Color(0.06, 0.09, 0.11, 0.86))
	draw_rect(map_rect, Color("d7aa58") if map_open else Color("718087"), false, 1.5)
	var font := maxi(8, int(map_rect.size.y * 0.27))
	var label := "MAP [M]" if desktop_controls else "MAP"
	draw_string(ThemeDB.fallback_font, map_rect.position + Vector2(0.0, map_rect.size.y * 0.61), label, HORIZONTAL_ALIGNMENT_CENTER, map_rect.size.x, font, Color("d7dddd"))

func _draw_view_button() -> void:
	draw_rect(view_rect, Color(0.06, 0.09, 0.11, 0.86))
	draw_rect(view_rect, DODGE_COLOR if view_mode == "isometric" else Color("718087"), false, 1.5)
	var font := maxi(8, int(view_rect.size.y * 0.27))
	var label := "TOP" if view_mode == "isometric" else "ISO"
	if desktop_controls: label += " [V]"
	draw_string(ThemeDB.fallback_font, view_rect.position + Vector2(0.0, view_rect.size.y * 0.61), label, HORIZONTAL_ALIGNMENT_CENTER, view_rect.size.x, font, Color("d7dddd"))

func _draw_landmarks(visible: Dictionary, discovered: Dictionary) -> void:
	if bool(state.mode_config["waystone_available"]):
		for stone in state.waystones:
			if String(stone.get("layer", state.current_layer)) != state.current_layer or not state.is_discovered(Vector2(stone["pos"]), discovered): continue
			if not _world_point_on_camera(Vector2(stone["pos"]), 70.0): continue
			var bonfire := _world_to_screen(Vector2(stone["pos"]))
			var bright := state.is_visible(Vector2(stone["pos"]), visible)
			draw_circle(bonfire, 25.0 * world_scale, Color("e89145") if bright else Color("62452f"))
			draw_circle(bonfire + Vector2(0, -12.0 * world_scale), 13.0 * world_scale, Color("f4d36b") if bright else Color("695b3c"))
			if state.player_pos.distance_to(Vector2(stone["pos"])) <= state.WAYSTONE_RANGE:
				draw_arc(bonfire, 38.0 * world_scale, 0.0, TAU, 24, Color("f3d46a"), maxf(2.0, 3.0 * world_scale))
				var prompt := "SPACE" if desktop_controls else "TAP"
				draw_string(ThemeDB.fallback_font, bonfire + Vector2(-45.0, -48.0 * world_scale), prompt, HORIZONTAL_ALIGNMENT_CENTER, 90.0, maxi(11, int(13.0 * world_scale)), Color("f4e2a1"))
	for transition in state.transitions:
		var transition_pos := Vector2.ZERO
		if String(transition["from_layer"]) == state.current_layer: transition_pos = Vector2(transition["from_pos"])
		elif String(transition["to_layer"]) == state.current_layer: transition_pos = Vector2(transition["to_pos"])
		else: continue
		if not state.is_discovered(transition_pos, discovered): continue
		if not _world_point_on_camera(transition_pos, 60.0): continue
		var marker := _world_to_screen(transition_pos)
		draw_rect(Rect2(marker - Vector2(18, 12) * world_scale, Vector2(36, 24) * world_scale), Color("b9a46c"), true)
		draw_line(marker + Vector2(-12, -6) * world_scale, marker + Vector2(12, 6) * world_scale, Color("4b4234"), maxf(2.0, 3.0 * world_scale))
	for shortcut in state.shortcuts:
		if String(shortcut.get("layer", state.current_layer)) != state.current_layer or not _shortcut_gate_is_discovered(shortcut, discovered): continue
		if not _world_rect_on_camera(Rect2(shortcut["gate"]).grow(90.0)): continue
		if not bool(shortcut.get("unlocked", false)):
			var activation_world := Vector2(shortcut["unlock_pos"])
			var activation := _world_to_screen(activation_world)
			draw_circle(activation, maxf(7.0, 10.0 * world_scale), Color(0.96, 0.78, 0.29, 0.28))
			draw_arc(activation, maxf(9.0, 13.0 * world_scale), 0.0, TAU, 20, Color("f0c84b"), maxf(2.0, 2.5 * world_scale))
			var interaction_radius := float(shortcut.get("interaction_radius", 115.0))
			if state.player_pos.distance_to(activation_world) <= interaction_radius + 35.0:
				draw_string(ThemeDB.fallback_font, activation + Vector2(-70, -28), "UNLOCK ROOT GATE", HORIZONTAL_ALIGNMENT_CENTER, 140, maxi(10, int(12 * world_scale)), Color("fff0a6"))
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
	if desktop_controls:
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.275), "1–3 class  •  Tab mode  •  Enter start  •  F11 fullscreen", HORIZONTAL_ALIGNMENT_CENTER, size.x, maxi(10, int(body_font * 0.72)), Color("718087"))
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
	if desktop_controls: prompt = "Press Enter to return to setup" if state.mode_id == "expedition" else "Press Enter to return to the Waystone"
	var report: Dictionary = state.death_report
	var center_y := board_rect.get_center().y
	draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x, center_y - 120.0), title, HORIZONTAL_ALIGNMENT_CENTER, board_rect.size.x, font, Color("d76a68"))
	var lines: Array[String] = []
	if state.mode_id == "expedition":
		lines.append("XP LOST  %d" % int(report.get("lost_xp", 0)))
	else:
		lines.append("INTEGRATED  %d XP" % int(report.get("retained_xp", 0)))
		lines.append("SHADOW  %d XP" % int(report.get("shadow_xp", 0)))
		var forgotten := int(report.get("forgotten_cells", 0))
		lines.append("MEMORY  SECURE" if forgotten == 0 else "MEMORY LOST  %d TRACES" % forgotten)
		if bool(report.get("shortcut_forgotten", false)): lines.append("SHORTCUT KNOWLEDGE LOST")
		if bool(report.get("previous_shadow_erased", false)): lines.append("OLDER SHADOW ERASED")
	var report_font := maxi(13, int(font * 0.42))
	for index in range(lines.size()):
		var line_color := Color("e9f4b1") if String(lines[index]).begins_with("SHADOW") else Color("f0c36b") if String(lines[index]).begins_with("INTEGRATED") else Color("d6d3c7")
		draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x, center_y - 42.0 + index * (report_font + 10.0)), lines[index], HORIZONTAL_ALIGNMENT_CENTER, board_rect.size.x, report_font, line_color)
	draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x, center_y + 118.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, board_rect.size.x, maxi(14, int(font * 0.42)), Color("d6d3c7"))

func _draw_map() -> void:
	var overlay := state.map_presentation == "overlay"
	var viewed_layer := state.current_layer if overlay else _normalized_map_view_layer()
	var map_cells := _map_cells_for_layer(viewed_layer)
	if not overlay: _update_map_layer_controls()
	var rect := _map_panel_rect()
	draw_rect(rect, Color(0.025, 0.04, 0.05, 0.36 if overlay else 0.98))
	draw_rect(rect, Color(0.62, 0.70, 0.72, 0.62 if overlay else 1.0), false, 2.0)
	var map_bounds := _discovered_map_bounds(map_cells, viewed_layer).grow(120.0)
	var scale := minf((rect.size.x - 72.0) / map_bounds.size.x, (rect.size.y - 110.0) / map_bounds.size.y)
	var origin := rect.get_center() - map_bounds.get_center() * scale + Vector2(0, 18)
	var map_cell_size := state.VISIBILITY_CELL * scale + 0.7
	for cell in map_cells:
		var world_cell := Vector2(cell) * state.VISIBILITY_CELL
		draw_rect(Rect2(origin + world_cell * scale, Vector2.ONE * map_cell_size), Color(0.23, 0.34, 0.30, 0.50 if overlay else 0.96))
	for feature_value in state.terrain_features:
		var feature: Dictionary = feature_value
		var feature_kind := String(feature.get("kind", "tree"))
		var feature_pos := Vector2(feature["pos"])
		if feature_kind in ["tree", "undergrowth", "flowers"] or String(feature.get("layer", viewed_layer)) != viewed_layer or not state.is_discovered(feature_pos, map_cells): continue
		var map_color := Color(0.24, 0.57, 0.72, 0.62 if overlay else 0.90) if feature_kind == "brook" else Color(0.57, 0.46, 0.28, 0.50 if overlay else 0.80) if feature_kind == "old_road" else Color(0.72, 0.69, 0.52, 0.58 if overlay else 0.88)
		if feature_kind in ["brook", "old_road"] and feature.has("from") and feature.has("to"):
			draw_line(origin + Vector2(feature["from"]) * scale, origin + Vector2(feature["to"]) * scale, map_color, 2.0 if overlay else 3.0)
		else:
			draw_circle(origin + feature_pos * scale, 3.5 if overlay else 5.0, map_color)
	var player := origin + state.player_pos * scale
	if bool(state.mode_config["waystone_available"]):
		for stone in state.waystones:
			if String(stone.get("layer", viewed_layer)) == viewed_layer and state.is_discovered(Vector2(stone["pos"]), map_cells):
				draw_circle(origin + Vector2(stone["pos"]) * scale, 8.0, Color("f3d16a") if String(stone["id"]) == state.active_waystone_id else Color("e89b52"))
	if viewed_layer == state.current_layer: draw_circle(player, 7.0, PLAYER_COLOR)
	for area in state.areas:
		if String(area.get("kind", "")) == "boss" and String(area.get("layer", viewed_layer)) == viewed_layer and bool(area.get("discovered", false)):
			var exit_center := origin + Vector2(area.get("boss_pos", area["center"])) * scale
			draw_colored_polygon(PackedVector2Array([exit_center + Vector2(0, -9), exit_center + Vector2(9, 8), exit_center + Vector2(-9, 8)]), Color("d76a68"))
	for shortcut in state.shortcuts:
		if String(shortcut.get("layer", viewed_layer)) == viewed_layer and _shortcut_gate_is_discovered(shortcut, map_cells):
			if String(shortcut.get("presentation", "")) == "hidden_woodland_path" and not bool(shortcut.get("unlocked", false)) and not state.is_discovered(Vector2(shortcut["far_pos"]), map_cells): continue
			draw_circle(origin + Rect2(shortcut["gate"]).get_center() * scale, 7.0, Color("65c5b5") if bool(shortcut.get("unlocked", false)) else Color("bb5960"))
	for transition in state.transitions:
		var point := Vector2.INF
		if String(transition["from_layer"]) == viewed_layer: point = Vector2(transition["from_pos"])
		elif String(transition["to_layer"]) == viewed_layer: point = Vector2(transition["to_pos"])
		if point.is_finite() and state.is_discovered(point, map_cells): draw_rect(Rect2(origin + point * scale - Vector2(5, 5), Vector2(10, 10)), Color("b9a46c"))
	if bool(state.lost_xp.get("active", false)) and String(state.lost_xp.get("layer", state.current_layer)) == viewed_layer:
		var shadow := origin + Vector2(state.lost_xp["pos"]) * scale
		if viewed_layer == state.current_layer:
			var segments := 18
			for index in range(0, segments, 2):
				var from := player.lerp(shadow, float(index) / float(segments))
				var to := player.lerp(shadow, float(index + 1) / float(segments))
				draw_line(from, to, Color(0.85, 0.93, 0.48, 0.52), 2.0)
		draw_circle(shadow, 8.0, Color("d8ed78"))
		draw_string(ThemeDB.fallback_font, shadow + Vector2(-55.0, -14.0), "SHADOW %d XP" % int(state.lost_xp.get("amount", 0)), HORIZONTAL_ALIGNMENT_CENTER, 110.0, 11, Color("e9f4b1"))
	var layer_name := String(Dictionary(state.world_layers.get(viewed_layer, {})).get("name", viewed_layer)).to_upper()
	var header := "%s  •  %s  •  SEED %d" % [layer_name, state.mode_label().to_upper(), state.run_seed]
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(18, 34), header, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 170.0, maxi(15, int(minf(size.x, size.y) * 0.026)), Color("e6e7dc"))
	_draw_map_action(_map_close_rect(), "CLOSE [ESC]" if desktop_controls else "CLOSE")
	if not overlay:
		_draw_map_action(map_mode_rect, "OVERLAY")
		_draw_map_action(seed_copy_rect, "COPY SEED")
		_draw_map_layer_controls()

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

func _map_cells_for_layer(layer: String) -> Dictionary:
	if layer == state.current_layer: return state.discovered_cells
	return Dictionary(state.discovered_cells_by_layer.get(layer, {}))

func _available_map_layers() -> Array[String]:
	var result: Array[String] = []
	for layer_value in state.world_layers:
		var layer := String(layer_value)
		if layer == state.current_layer or not _map_cells_for_layer(layer).is_empty(): result.append(layer)
	if not result.has(state.current_layer): result.append(state.current_layer)
	return result

func _normalized_map_view_layer() -> String:
	var available := _available_map_layers()
	if map_view_layer == "" or not available.has(map_view_layer): map_view_layer = state.current_layer
	return map_view_layer

func _update_map_layer_controls() -> void:
	map_layer_rects.clear()
	map_layer_previous_rect = Rect2()
	map_layer_next_rect = Rect2()
	var available := _available_map_layers()
	var page_count := maxi(1, int(ceil(float(available.size()) / float(MAP_LAYERS_PER_PAGE))))
	map_layer_page = clampi(map_layer_page, 0, page_count - 1)
	var first := map_layer_page * MAP_LAYERS_PER_PAGE
	var visible_layers := available.slice(first, mini(first + MAP_LAYERS_PER_PAGE, available.size()))
	if visible_layers.is_empty(): return
	var panel := _map_panel_rect()
	var left := panel.position.x + 14.0
	var right := panel.end.x - 150.0
	var gap := 6.0
	var arrow_width := 38.0 if page_count > 1 else 0.0
	if page_count > 1:
		map_layer_previous_rect = Rect2(Vector2(left, panel.end.y - 54.0), Vector2(arrow_width, 40.0))
		map_layer_next_rect = Rect2(Vector2(right - arrow_width, panel.end.y - 54.0), Vector2(arrow_width, 40.0))
		left += arrow_width + gap
		right -= arrow_width + gap
	var width := maxf(62.0, (right - left - gap * float(visible_layers.size() - 1)) / float(visible_layers.size()))
	for index in range(visible_layers.size()):
		map_layer_rects[String(visible_layers[index])] = Rect2(Vector2(left + index * (width + gap), panel.end.y - 54.0), Vector2(width, 40.0))

func _draw_map_layer_controls() -> void:
	for layer_id in map_layer_rects:
		var rect := Rect2(map_layer_rects[layer_id])
		var selected := String(layer_id) == map_view_layer
		var name := String(Dictionary(state.world_layers.get(layer_id, {})).get("name", layer_id)).to_upper()
		draw_rect(rect, Color("19302f") if selected else Color("101a1e"))
		draw_rect(rect, Color("58d2cf") if selected else Color("718087"), false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, 25), name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 10, Color("eef0e9"))
	if map_layer_previous_rect.size != Vector2.ZERO:
		_draw_map_action(map_layer_previous_rect, "<")
		_draw_map_action(map_layer_next_rect, ">")

func _discovered_map_bounds(cells: Dictionary, layer: String) -> Rect2:
	var anchor := state.player_pos if layer == state.current_layer else Vector2.ZERO
	if layer != state.current_layer and not cells.is_empty(): anchor = Vector2(cells.keys()[0]) * state.VISIBILITY_CELL
	var bounds := Rect2(anchor - Vector2.ONE * 40.0, Vector2.ONE * 80.0)
	for cell in cells:
		var position := Vector2(cell) * state.VISIBILITY_CELL
		bounds = bounds.merge(Rect2(position, Vector2.ONE * state.VISIBILITY_CELL))
	if bool(state.lost_xp.get("active", false)) and String(state.lost_xp.get("layer", state.current_layer)) == layer:
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
		available = (state.has_infinite_potions() or state.potions > 0) and state.player_hp < state.player_max_hp
		subtitle = "UNLIMITED" if state.has_infinite_potions() else "%d LEFT" % state.potions
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
		subtitle = "REST AT WAYSTONE" if title == "REST" else "OPEN SHORTCUT" if title == "UNLOCK" else "USE PASSAGE" if title == "TRAVERSE" else "+0.5s"
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
	if desktop_controls:
		var shortcuts := {"potion": "[1 / P]", "defense": "[2 / B]", "skill": "[3 / Q]", "wait": "[4 / SPACE]"}
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.91), String(shortcuts[name]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(8, int(title_font * 0.48)), Color("718087"))

func _draw_waystone_menu() -> void:
	var definitions := {"learn": ["LEARN", "SPEND %d XP" % state.next_upgrade_cost()], "continue": ["CONTINUE", "RETURN TO THE WORLD"]}
	for option in definitions:
		var rect := _waystone_option_rect(String(option))
		var definition: Array = definitions[option]
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
	var best: Dictionary = {}
	var best_score := INF
	var best_depth := -INF
	for enemy in state.enemies:
		if String(enemy.get("layer", state.current_layer)) != state.current_layer: continue
		if not state.is_visible(Vector2(enemy["pos"]), _render_visible_cells()): continue
		var world_pos := Vector2(enemy["pos"])
		var foot := _world_to_screen(world_pos)
		var world_radius := float(enemy.get("radius", 24.0))
		var body := _actor_visual_center(world_pos, world_radius)
		var silhouette_radius := _actor_body_radius(world_radius)
		var distance := _point_segment_distance(screen_position, foot, body)
		if distance > radius + silhouette_radius: continue
		var score := distance - silhouette_radius * 0.25
		if score < best_score - 2.0 or (absf(score - best_score) <= 2.0 and foot.y > best_depth):
			best = enemy
			best_score = score
			best_depth = foot.y
	return best

func _point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.001: return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * amount)

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

func _render_discovered_cells() -> Dictionary:
	var cells: Dictionary = visual.get("discovered_cells", {})
	return state.discovered_cells if cells.is_empty() and not state.discovered_cells.is_empty() else cells

func _render_visible_cells() -> Dictionary:
	var cells: Dictionary = visual.get("visible_cells", {})
	return state.visible_cells if cells.is_empty() and not state.visible_cells.is_empty() else cells

func _camera_cell_bounds() -> Rect2i:
	var expanded := board_rect.grow(80.0)
	var corners := [expanded.position, Vector2(expanded.end.x, expanded.position.y), expanded.end, Vector2(expanded.position.x, expanded.end.y)]
	var minimum := _screen_to_world(corners[0])
	var maximum := minimum
	for corner in corners:
		var world := _screen_to_world(corner)
		minimum.x = minf(minimum.x, world.x)
		minimum.y = minf(minimum.y, world.y)
		maximum.x = maxf(maximum.x, world.x)
		maximum.y = maxf(maximum.y, world.y)
	var start := Vector2i(maxi(0, int(floor(minimum.x / state.VISIBILITY_CELL)) - 1), maxi(0, int(floor(minimum.y / state.VISIBILITY_CELL)) - 1))
	var finish := Vector2i(mini(int(ceil(state.world_size.x / state.VISIBILITY_CELL)), int(ceil(maximum.x / state.VISIBILITY_CELL)) + 2), mini(int(ceil(state.world_size.y / state.VISIBILITY_CELL)), int(ceil(maximum.y / state.VISIBILITY_CELL)) + 2))
	return Rect2i(start, Vector2i(maxi(0, finish.x - start.x), maxi(0, finish.y - start.y)))

func _world_point_on_camera(world: Vector2, margin_world: float = 80.0) -> bool:
	return board_rect.grow(maxf(48.0, margin_world * world_scale)).has_point(_world_to_screen(world))

func _world_rect_on_camera(world_rect: Rect2) -> bool:
	var points := [_world_to_screen(world_rect.position), _world_to_screen(Vector2(world_rect.end.x, world_rect.position.y)), _world_to_screen(world_rect.end), _world_to_screen(Vector2(world_rect.position.x, world_rect.end.y))]
	var screen_rect := Rect2(points[0], Vector2.ZERO)
	for point in points: screen_rect = screen_rect.expand(point)
	return screen_rect.intersects(board_rect.grow(72.0), true)

func _projection_origin() -> Vector2:
	var camera := _camera_world_position()
	if view_mode == "isometric":
		var projected_camera := Vector2((camera.x - camera.y) * 0.5, (camera.x + camera.y) * 0.25)
		var anchor := board_rect.get_center() + Vector2(0.0, board_rect.size.y * ISO_CAMERA_DROP)
		return anchor - projected_camera * world_scale
	return board_rect.get_center() - camera * world_scale

func _camera_world_position() -> Vector2:
	var camera := Vector2(visual.get("player_pos", state.player_pos))
	if view_mode == "top_down":
		var half_view := board_rect.size / (world_scale * 2.0)
		camera.x = clampf(camera.x, minf(half_view.x, state.world_size.x * 0.5), maxf(state.world_size.x - half_view.x, state.world_size.x * 0.5))
		camera.y = clampf(camera.y, minf(half_view.y, state.world_size.y * 0.5), maxf(state.world_size.y - half_view.y, state.world_size.y * 0.5))
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
