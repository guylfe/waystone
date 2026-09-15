extends Control

const RunStateScript = preload("res://scripts/core/run_state.gd")
const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const AbilityCatalogScript = preload("res://scripts/core/ability_catalog.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")
const PresentationFrameScript = preload("res://scripts/presentation/presentation_frame.gd")
const IsometricPoseScript = preload("res://scripts/presentation/isometric_pose.gd")
const BG := Color("0d151b")
const FLOOR := Color("17272d")
const WALL := Color("344148")
const PLAYER_COLOR := Color("39ddff")
# Energy pays for dodging and for casting, so the bar is deliberately neither green nor
# blue but the hue where the two fuse. Both ends stay green-of-cyan: PLAYER_COLOR above is
# bright cyan, and a bar that reached it would compete with the player's own marker.
const ENERGY_EMPTY_COLOR := Color("2fd08c")
const ENERGY_FULL_COLOR := Color("2bb8e0")
const BLADE_COLOR := Color("e46c63")
const ARCHER_COLOR := Color("c68be4")
const POLEARM_COLOR := Color("d08a48")
const HOUND_COLOR := Color("6f91b8")
const DODGE_COLOR := Color("58d2cf")
const CAMERA_WORLD_WIDTH := 1050.0
const CAMERA_WORLD_HEIGHT := 1000.0
const ISO_ZOOM := 1.38
const ISO_CAMERA_DROP := 0.075
const ISO_WALL_HEIGHT := 54.0
const ATTACK_INTENT_DELAY := 0.16
const TOUCH_MOVE_SLOP_MIN := 14.0
const TOUCH_MOVE_SLOP_SCALE := 0.014
const AUTOSAVE_DELAY := 2.0
const AUTOSAVE_QUIET_DELAY := 0.24
const MAP_LAYERS_PER_PAGE := 5
const MAX_SIM_TICKS_PER_FRAME := 4
const RENDER_QUERY_REUSE_DISTANCE := 220.0
const FLOOR_RENDER_CHUNK_CELLS := 8
const TEMPORAL_TINT_ALPHA := 0.13
const TEMPORAL_TINT_FADE_IN := 2.6
const TEMPORAL_TINT_FADE_OUT := 4.0
const AREA_TITLE_DURATION := 2.8
const MELEE_TAP_ANTICIPATION := 90.0
const MELEE_TAP_NEARBY_ALLOWANCE := 24.0
const MELEE_TAP_NEARBY_HALF_ANGLE := deg_to_rad(35.0)
const BOSS_LAB_ARENAS: Array[String] = ["open_ring", "central_cover", "broken_sightline", "split_approach", "scattered_cover", "wide_lane"]

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
var pointer_intent := ""
var hold_elapsed := 0.0
var hold_consumed := false
var wait_pointer_held := false
var inspected_enemy_id := -1
var held_movement := false
var held_movement_tracks_pointer := false
var held_direction := Vector2.ZERO
var queued_movement_after_attack := false
var queued_attack_exit_direction := Vector2.ZERO
var pointer_is_mouse := false
var attack_pointer_held := false
var attack_touch_is_original := false
var attack_button_pointer_held := false
var attack_key_held := false
var advance_pointer_held := false
var defense_pointer_held := false
var desktop_movement_keys: Dictionary = {}
var board_rect := Rect2()
var world_scale := 1.0
var board_area := Rect2()
var safe_layout_rect := Rect2()
var layout_safe_area_override := Rect2()
var iso_origin := Vector2.ZERO
var view_mode := "isometric"
var debug_hitboxes := false
var _occlusion_focus_bounds: Array[Rect2] = []
var selected_action := ""
var buttons: Dictionary = {}
var consumable_rects: Dictionary = {}
var interaction_rect := Rect2()
var attack_rect := Rect2()
var loadout_rects: Dictionary = {}
var upgrade_rects: Dictionary = {}
var reset_rect := Rect2()
var view_rect := Rect2()
var map_rect := Rect2()
var sheet_button_rect := Rect2()
var sheet_panel_rect := Rect2()
var sheet_close_rect := Rect2()
var sheet_art_rects: Dictionary = {}
var sheet_property_rects: Dictionary = {}
var sheet_upgrade_rects: Dictionary = {}
var sheet_equipment_rects: Dictionary = {}
var sheet_consumable_rects: Dictionary = {}
var sheet_repack_slot := -1
var sheet_detail_close_rect := Rect2()
var sheet_detail_confirm_rect := Rect2()
var sheet_skill_choice_rects: Dictionary = {}
var sheet_detail: Dictionary = {}
var map_mode_rect := Rect2()
var seed_copy_rect := Rect2()
var start_rect := Rect2()
var progression_rects: Dictionary = {}
var survey_profile_rects: Dictionary = {}
var combat_rule_rects: Dictionary = {}
var boss_choice_rects: Dictionary = {}
var boss_arena_rect := Rect2()
# The custom room picker. A full-screen overlay rather than another row in the setup
# panel, which is already carrying three mode chips, two profiles, two rule sets, a seed
# field and a start button -- twenty-one enemy chips would not fit beside them on a phone.
#
# There is no separate on/off switch: picking at least one enemy IS the switch, which is
# the same condition the simulation uses to decide whether a room is custom.
# Dev holds the two testing instruments. Survey draws its rooms; Custom is the same
# machinery with the roster and arrangement specified by hand.
# Two screens, not one. Everything used to be laid out at once -- three mode chips, a
# class list, a profile pair, a rules pair, a seed field and a start button -- and the
# class rects were computed by their own function anchored independently of _layout().
# Once the mode stack moved up to make room, the two overlapped in portrait and the class
# handler, which runs first, swallowed every tap meant for the rows beneath it. Splitting
# the screen removes the collision by construction rather than by arithmetic.
var setup_stage := "root"
var setup_back_rect := Rect2()
var setup_class_rects: Dictionary = {}
var setup_dev_section := "survey"
var dev_section_rects: Dictionary = {}
var custom_room_open := false
# The room is a list of slots, in order, not a tally per kind. Counting made duplicates
# a number to cycle through and removal an afterthought; a roster makes "three Hounds"
# three rows you can delete one at a time, and it keeps the order the player chose.
var custom_room_roster: Array[String] = []
var custom_page := "room"
var custom_editing_slot := -1
var custom_slot_rects: Dictionary = {}
var custom_remove_rects: Dictionary = {}
var custom_add_rect := Rect2()
# The spellbook row. A palette reached through the subclass slot would cost two taps per
# cast, which for a class whose whole loop is choosing between four questions is the
# difference between a spellbook and a chore. Frozen time is what makes the extra row
# affordable: no world time passes while you decide, so more buttons cost nothing in
# dexterity and the only real cost is screen space.
var spell_rects: Dictionary = {}
# The spellbook is a drawer, not a permanent row. Open, it takes real space and pushes the
# belt and everything above it up; closed, that space goes back. Persistent either way,
# because a caster picks a spell and then works from it -- a panel that closed itself after
# every cast would charge a tap for every spell in a fight.
var spellbook_open := true
var spellbook_panel := Rect2()
var spellbook_arrow_x := 0.0
var spellbook_arrow_y := 0.0
# Each element keeps the colour its enemy caster uses, so a spell you learned off something
# looks like the thing you learned it from.
const SPELL_COLORS := {
	"lightning_bolt": Color("d8ecf6"), "fireball": Color("ff9b4f"), "fire_breath": Color("ff7a3c"),
	"frost_lance": Color("9be7ff"), "cold_front": Color("8edcff"), "earth_wall": Color("6f9b6a"),
	"sunder": Color("87ac7d"), "gale": Color("d8ecf6"), "windstep": Color("bcd3e0"),
}
var custom_room_formation := ""
var custom_room_hp := 1.0
# A level, not an XP total. "XP 400" is a number from the wrong vocabulary -- the sheet
# and the upgrade screen both talk in levels, so the picker should too. A stepper rather
# than presets, because there was never a reason for exactly four choices.
var custom_room_level := 1
var custom_open_rect := Rect2()
var custom_panel_rect := Rect2()
var custom_kind_rects: Dictionary = {}
var custom_formation_rects: Dictionary = {}
var custom_hp_rects: Dictionary = {}
var custom_level_rects: Dictionary = {}
# The custom room used to sit behind a section chip that revealed a button that opened a
# panel you then had to back out of before you could press Start -- four screens to set up
# one room. It is a toggle on the options screen now, and the panel it opens can start the
# run itself.
var custom_room_repeat := false
var custom_repeat_rect := Rect2()
var custom_start_rect := Rect2()
var custom_clear_rect := Rect2()
var custom_done_rect := Rect2()
var archive_button_rect := Rect2()
var survey_end_rect := Rect2()
var map_open := false
var character_sheet_open := false
var map_view_layer := ""
var map_layer_page := 0
var map_layer_rects: Dictionary = {}
var map_layer_previous_rect := Rect2()
var map_layer_next_rect := Rect2()
var autosave_pending := false
# Real seconds, deliberately: this is the pause between the blow that clears a room and the
# screen that replaces it, and it must not be measured in world time -- world time is what
# the killing swing is still spending. The simulation runs normally throughout.
const ROOM_CLEAR_HOLD_SECONDS := 2.0
var room_clear_remaining := 0.0
var room_clear_latched := false
var autosave_elapsed := 0.0
var autosave_quiet_elapsed := 0.0
var autosave_deferred := false
var setup_loadout := "warrior"
var setup_mode := "expedition"
var setup_survey_profile := "encounter"
var setup_combat_rules := "energy"
var setup_boss_kind := "werewolf"
var setup_boss_arena := "open_ring"
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
var _floor_surface_colors: Dictionary = {}
var _ground_surface_landmarks: Array[Dictionary] = []
var temporal_tint_strength := 0.0
var _presented_area_id := -999999
var area_title_remaining := 0.0
var area_title_name := ""
var area_title_subtitle := ""
var survey_overlay: PanelContainer
var survey_notes: TextEdit
var survey_rating_buttons: Dictionary = {}
var survey_tag_buttons: Dictionary = {}
var survey_feedback_ratings: Dictionary = {}
var survey_feedback_tags: Array[String] = []
var survey_submit_button: Button
var survey_skip_button: Button
var survey_archived_run: Dictionary = {}
var survey_export_status := ""
var survey_export_status_label: Label

func _ready() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	if desktop_controls and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(Vector2i(720, 480))
	Input.emulate_mouse_from_touch = false
	state = RunStateScript.new(false)
	state.load_run()
	if state.run_active: state.prewarm_expedition_navigation()
	_create_seed_input()
	_create_survey_overlay()
	setup_loadout = state.loadout_id
	setup_mode = state.mode_id
	setup_survey_profile = state.survey_profile
	setup_combat_rules = state.combat_rules
	setup_boss_kind = state.boss_lab_boss_kind
	setup_boss_arena = state.boss_lab_arena_id
	map_view_layer = state.current_layer
	visual = _presentation_snapshot()
	_update_area_title(0.0)
	state.changed.connect(_on_state_changed)
	resized.connect(_layout)
	_layout()
	call_deferred("_layout")
	_sync_setup_controls()
	state.record_survey_view_mode(view_mode, false)

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
	# Not merely "no run yet": the field is a real node, so it paints over the picker and
	# over the root screen unless it is hidden for both.
	if seed_input != null: seed_input.visible = not state.run_active and setup_stage != "root" and not custom_room_open
	_sync_survey_overlay()

func _create_survey_overlay() -> void:
	survey_overlay = PanelContainer.new()
	survey_overlay.visible = false
	survey_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	survey_overlay.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.05, 0.985)
	style.border_color = Color("58d2cf")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	survey_overlay.add_theme_stylebox_override("panel", style)
	add_child(survey_overlay)

func _sync_survey_overlay() -> void:
	if survey_overlay == null: return
	if survey_overlay.visible and survey_overlay.get_meta("kind", "") in ["archive", "end_confirm"]: return
	if room_clear_remaining > 0.0:
		survey_overlay.visible = false
		return
	if state.is_measurement_mode() and state.survey_feedback_pending:
		if not survey_overlay.visible or survey_overlay.get_meta("kind", "") != "feedback": _build_survey_feedback_overlay()
		survey_overlay.visible = true
	elif state.is_measurement_mode() and state.trial_complete and state.run_active:
		if not survey_overlay.visible or survey_overlay.get_meta("kind", "") != "report": _build_survey_report_overlay()
		survey_overlay.visible = true
	else:
		survey_overlay.visible = false

func _clear_survey_overlay() -> void:
	for child in survey_overlay.get_children():
		survey_overlay.remove_child(child)
		child.queue_free()
	survey_rating_buttons.clear()
	survey_tag_buttons.clear()
	survey_notes = null
	survey_submit_button = null
	survey_skip_button = null

func _build_survey_feedback_overlay() -> void:
	_clear_survey_overlay()
	survey_overlay.set_meta("kind", "feedback")
	survey_feedback_ratings.clear()
	survey_feedback_tags.clear()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	survey_overlay.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 13)
	scroll.add_child(content)
	var title := Label.new()
	title.text = "%s ATTEMPT COMPLETE" % state.boss_lab_boss_kind.replace("_", " ").to_upper() if state.mode_id == "boss_lab" else "ROOM %d COMPLETE" % state.survey_room_number
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)
	var reproduction := Label.new()
	reproduction.text = "RUN SEED %d  •  ROOM SEED %d  •  %s" % [state.run_seed, state.survey_room_seed, String(state.survey_room_definition.get("arena", "arena")).replace("_", " ").to_upper()]
	reproduction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reproduction.add_theme_font_size_override("font_size", 15)
	content.add_child(reproduction)
	var prompt := Label.new()
	prompt.text = "Rate the encounter while it is fresh. 1 is low; 5 is high."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 18)
	content.add_child(prompt)
	var questions := {
		"difficulty": "Difficulty",
		"fun": "Fun",
		"fairness": "Fairness",
		"want_retry": "Desire to retry",
	} if state.mode_id == "boss_lab" else {
		"difficulty": "Difficulty",
		"fun": "Fun",
		"tactical_interest": "Tactical interest",
		"want_again": "Want a room like this again?",
	}
	for question_id in questions:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 58.0
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = String(questions[question_id])
		label.custom_minimum_size = Vector2(225, 58)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 19)
		row.add_child(label)
		var buttons: Array[Button] = []
		for rating in range(1, 6):
			var button := Button.new()
			button.text = str(rating)
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(54, 54)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 22)
			_apply_survey_toggle_style(button)
			button.pressed.connect(_survey_rating_pressed.bind(String(question_id), rating))
			row.add_child(button)
			buttons.append(button)
		survey_rating_buttons[String(question_id)] = buttons
		content.add_child(row)
	if state.mode_id != "boss_lab":
		var tag_label := Label.new()
		tag_label.text = "Tags — choose any that apply"
		tag_label.add_theme_font_size_override("font_size", 20)
		content.add_child(tag_label)
		var tag_grid := GridContainer.new()
		tag_grid.columns = 3
		tag_grid.add_theme_constant_override("h_separation", 7)
		tag_grid.add_theme_constant_override("v_separation", 7)
		for tag in ["tense", "satisfying", "too easy", "too hard", "fair", "unfair", "crowded", "empty", "clear", "confusing", "unclear contact", "good mix", "bad matchup", "repetitive", "surprising", "ranged pressure", "energy meaningful", "energy frustrating"]:
			var button := Button.new()
			button.text = String(tag).to_upper()
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(150, 50)
			button.add_theme_font_size_override("font_size", 15)
			_apply_survey_toggle_style(button)
			button.toggled.connect(_survey_tag_toggled.bind(String(tag)))
			tag_grid.add_child(button)
			survey_tag_buttons[String(tag)] = button
		content.add_child(tag_grid)
	var notes_label := Label.new()
	notes_label.text = "Optional notes"
	notes_label.add_theme_font_size_override("font_size", 20)
	content.add_child(notes_label)
	survey_notes = TextEdit.new()
	survey_notes.placeholder_text = "What made this attempt work or fail?" if state.mode_id == "boss_lab" else "What made this room work or fail?"
	survey_notes.custom_minimum_size = Vector2(0, 132)
	survey_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	survey_notes.virtual_keyboard_enabled = true
	survey_notes.add_theme_font_size_override("font_size", 19)
	survey_notes.gui_input.connect(_survey_notes_gui_input)
	survey_notes.focus_entered.connect(_survey_notes_focus_entered)
	content.add_child(survey_notes)
	survey_submit_button = Button.new()
	survey_submit_button.text = "ANSWER ALL FOUR RATINGS"
	survey_submit_button.disabled = true
	survey_submit_button.custom_minimum_size = Vector2(0, 64)
	survey_submit_button.add_theme_font_size_override("font_size", 20)
	survey_submit_button.pressed.connect(_submit_survey_feedback)
	content.add_child(survey_submit_button)
	survey_skip_button = Button.new()
	survey_skip_button.text = "SKIP — NOT ENOUGH INFORMATION"
	survey_skip_button.custom_minimum_size = Vector2(0, 58)
	survey_skip_button.add_theme_font_size_override("font_size", 18)
	survey_skip_button.pressed.connect(_skip_survey_feedback)
	content.add_child(survey_skip_button)

func _apply_survey_toggle_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("eaf6f8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("14252c")
	normal.border_color = Color("536a73")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("1b343d")
	hover.border_color = Color("78a4af")
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("176b79")
	pressed.border_color = Color("62eaff")
	pressed.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", pressed)

func _survey_notes_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		survey_notes.grab_focus()
		get_viewport().set_input_as_handled()
		call_deferred("_show_survey_notes_keyboard")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		survey_notes.grab_focus()

func _survey_notes_focus_entered() -> void:
	if not desktop_controls: call_deferred("_show_survey_notes_keyboard")

func _show_survey_notes_keyboard() -> void:
	if survey_notes == null or not is_instance_valid(survey_notes) or not survey_notes.is_inside_tree(): return
	survey_notes.grab_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(survey_notes.text, Rect2(survey_notes.global_position, survey_notes.size))

func _survey_rating_pressed(question_id: String, rating: int) -> void:
	survey_feedback_ratings[question_id] = rating
	var buttons: Array = survey_rating_buttons.get(question_id, [])
	for index in range(buttons.size()):
		var rating_button: Button = buttons[index]
		rating_button.set_pressed_no_signal(index + 1 == rating)
	if survey_submit_button != null:
		survey_submit_button.disabled = survey_feedback_ratings.size() < 4
		survey_submit_button.text = ("SUBMIT ATTEMPT" if state.mode_id == "boss_lab" else "SUBMIT ROOM & CONTINUE") if not survey_submit_button.disabled else "ANSWER ALL FOUR RATINGS"

func _survey_tag_toggled(enabled: bool, tag: String) -> void:
	if enabled and not survey_feedback_tags.has(tag): survey_feedback_tags.append(tag)
	elif not enabled: survey_feedback_tags.erase(tag)

func _submit_survey_feedback() -> void:
	if survey_feedback_ratings.size() < 4: return
	var notes := survey_notes.text if survey_notes != null else ""
	state.submit_survey_feedback(survey_feedback_ratings, survey_feedback_tags, notes)
	visual = _presentation_snapshot()
	_static_query_revision = -1
	_floor_cache_revision = -1
	_mark_autosave(true)
	_sync_survey_overlay()
	queue_redraw()

func _skip_survey_feedback() -> void:
	var notes := survey_notes.text if survey_notes != null else ""
	state.skip_survey_feedback(notes)
	visual = _presentation_snapshot()
	_static_query_revision = -1
	_floor_cache_revision = -1
	_mark_autosave(true)
	_sync_survey_overlay()
	queue_redraw()

func _build_survey_report_overlay() -> void:
	_clear_survey_overlay()
	survey_overlay.set_meta("kind", "report")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	survey_overlay.add_child(content)
	var title := Label.new()
	title.text = "BOSS LAB ATTEMPT SAVED" if state.mode_id == "boss_lab" else "COMBAT SURVEY SAVED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)
	var room_count := Array(state.survey_session.get("rooms", [])).size()
	var summary := Label.new()
	summary.text = "%d rooms  •  run seed %d  •  ended by %s\nThe UTF-8 report is archived inside Waystone." % [room_count, state.run_seed, state.survey_end_reason.replace("_", " ")]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 16)
	content.add_child(summary)
	if state.mode_id == "boss_lab":
		content.add_child(_survey_action_button("RETRY SAME SETUP", _retry_boss_lab))
		content.add_child(_survey_action_button("CHANGE SETUP", _change_boss_lab_setup))
		content.add_child(_survey_action_button("COPY REPORT", _copy_current_survey_report))
		content.add_child(_survey_action_button("LEAVE BOSS LAB", _leave_boss_lab))
	else:
		content.add_child(_survey_action_button("SAVE TXT TO DOWNLOADS", _save_current_survey_report))
		content.add_child(_survey_action_button("SHARE REPORT", _share_current_survey_report))
		content.add_child(_survey_action_button("COPY REPORT", _copy_current_survey_report))
		content.add_child(_survey_action_button("VIEW ARCHIVE", _build_survey_archive_overlay))
		content.add_child(_survey_action_button("RETURN TO SETUP", _return_from_survey_report))

func _survey_action_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(callback)
	return button

func _build_survey_end_confirmation() -> void:
	_clear_survey_overlay()
	survey_overlay.set_meta("kind", "end_confirm")
	survey_overlay.visible = true
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	survey_overlay.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = minf(620.0, maxf(360.0, survey_overlay.size.x - 48.0))
	content.add_theme_constant_override("separation", 18)
	center.add_child(content)
	var title := Label.new()
	title.text = "END THIS BOSS ATTEMPT?" if state.mode_id == "boss_lab" else "END THIS SURVEY RUN?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)
	var warning := Label.new()
	warning.text = "This ends the current attempt. You will still rate it, then Waystone will archive the report." if state.mode_id == "boss_lab" else "This ends the current room and the run. You will still rate this room, then Waystone will archive the complete report."
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", 19)
	content.add_child(warning)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	var cancel := _survey_action_button("CANCEL — KEEP PLAYING", _cancel_survey_end_confirmation)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(cancel)
	var confirm := _survey_action_button("END RUN", _confirm_survey_end_run)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.add_theme_color_override("font_color", Color("ffd9d5"))
	confirm.add_theme_color_override("font_hover_color", Color.WHITE)
	buttons.add_child(confirm)
	content.add_child(buttons)

func _cancel_survey_end_confirmation() -> void:
	survey_overlay.visible = false
	survey_overlay.set_meta("kind", "")
	queue_redraw()

func _confirm_survey_end_run() -> void:
	if not state.is_measurement_mode() or state.survey_feedback_pending or state.trial_complete: return
	state.end_survey_run()
	visual = _presentation_snapshot()
	_mark_autosave(true)
	survey_overlay.visible = false
	survey_overlay.set_meta("kind", "")
	_sync_survey_overlay()
	queue_redraw()

func _build_survey_archive_overlay() -> void:
	_clear_survey_overlay()
	survey_overlay.set_meta("kind", "archive")
	survey_overlay.visible = true
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	survey_overlay.add_child(content)
	var title := Label.new()
	title.text = "COMBAT SURVEY ARCHIVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)
	var archive := state.survey_archive()
	var runs: Array = archive.get("runs", [])
	var overview := Label.new()
	overview.text = "%d saved run%s" % [runs.size(), "" if runs.size() == 1 else "s"]
	overview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(overview)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for index in range(mini(12, runs.size())):
		var run := Dictionary(runs[index])
		var row := Button.new()
		row.text = "%02d. Seed %d  •  %d rooms  •  %s  •  %s" % [index + 1, int(run.get("run_seed", 0)), Array(run.get("rooms", [])).size(), String(run.get("loadout", "unknown")), String(run.get("ended_at", "unknown"))]
		row.add_theme_font_size_override("font_size", 14)
		row.custom_minimum_size = Vector2(0, 44)
		row.pressed.connect(_open_archived_survey.bind(index))
		list.add_child(row)
	if runs.is_empty():
		var empty := Label.new()
		empty.text = "No completed survey runs yet."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
	content.add_child(scroll)
	content.add_child(_survey_action_button("EXPORT ALL REPORTS", _export_all_survey_reports))
	survey_export_status_label = Label.new()
	survey_export_status_label.text = survey_export_status
	survey_export_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	survey_export_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	survey_export_status_label.add_theme_font_size_override("font_size", 15)
	survey_export_status_label.add_theme_color_override("font_color", Color("b9c8c5"))
	survey_export_status_label.visible = not survey_export_status.is_empty()
	content.add_child(survey_export_status_label)
	content.add_child(_survey_action_button("COPY LATEST", _copy_latest_survey_report))
	content.add_child(_survey_action_button("CLOSE", _close_survey_archive))

func _open_archived_survey(index: int) -> void:
	var runs: Array = state.survey_archive().get("runs", [])
	if index < 0 or index >= runs.size(): return
	survey_archived_run = Dictionary(runs[index]).duplicate(true)
	_clear_survey_overlay()
	survey_overlay.set_meta("kind", "archive")
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	survey_overlay.add_child(content)
	var title := Label.new()
	title.text = "ARCHIVED SURVEY — SEED %d" % int(survey_archived_run.get("run_seed", 0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	content.add_child(title)
	var summary := Label.new()
	summary.text = "%d rooms  •  %s  •  %s\n%s" % [Array(survey_archived_run.get("rooms", [])).size(), String(survey_archived_run.get("loadout", "unknown")), String(survey_archived_run.get("profile", "encounter")).capitalize(), String(survey_archived_run.get("ended_at", "unknown"))]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 16)
	content.add_child(summary)
	content.add_child(_survey_action_button("SAVE THIS TXT", _save_archived_survey_report))
	content.add_child(_survey_action_button("SHARE THIS REPORT", _share_archived_survey_report))
	content.add_child(_survey_action_button("COPY THIS REPORT", _copy_archived_survey_report))
	content.add_child(_survey_action_button("BACK TO ARCHIVE", _build_survey_archive_overlay))

func _archived_report_text() -> String:
	return String(survey_archived_run.get("report_text", ""))

func _archived_report_filename() -> String:
	var seed := int(survey_archived_run.get("run_seed", 0))
	var started := String(survey_archived_run.get("started_at", "unknown")).replace(":", "-").replace(" ", "_")
	return "Waystone_Combat_Survey_%d_%s.txt" % [seed, started]

func _save_archived_survey_report() -> void:
	_save_report_text(_archived_report_filename(), _archived_report_text())

func _copy_archived_survey_report() -> void:
	DisplayServer.clipboard_set(_archived_report_text())
	state.message = "Archived Combat Survey report copied."

func _share_archived_survey_report() -> void:
	_share_report_text(_archived_report_filename(), _archived_report_text())

func _close_survey_archive() -> void:
	if state.run_active and state.trial_complete: _build_survey_report_overlay()
	else:
		survey_overlay.visible = false
		survey_overlay.set_meta("kind", "")

func _return_from_survey_report() -> void:
	survey_overlay.visible = false
	_restart()

func _retry_boss_lab() -> void:
	if state.mode_id != "boss_lab": return
	survey_overlay.visible = false
	if not state.retry_boss_lab(): return
	setup_mode = "boss_lab"
	setup_loadout = state.loadout_id
	setup_boss_kind = state.boss_lab_boss_kind
	setup_boss_arena = state.boss_lab_arena_id
	setup_combat_rules = state.combat_rules
	seed_input.text = str(state.run_seed)
	_finish_run_start()

func _change_boss_lab_setup() -> void:
	if state.mode_id != "boss_lab": return
	survey_overlay.visible = false
	setup_mode = "boss_lab"
	setup_loadout = state.loadout_id
	setup_boss_kind = state.boss_lab_boss_kind
	setup_boss_arena = state.boss_lab_arena_id
	setup_combat_rules = state.combat_rules
	seed_input.text = str(state.run_seed)
	setup_stage = "options"
	_restart()
	_layout()

func _leave_boss_lab() -> void:
	survey_overlay.visible = false
	setup_stage = "root"
	_restart()
	_layout()

func _copy_current_survey_report() -> void:
	DisplayServer.clipboard_set(state.survey_report_text())
	state.message = "Combat Survey report copied."

func _copy_latest_survey_report() -> void:
	var runs: Array = state.survey_archive().get("runs", [])
	if runs.is_empty(): return
	DisplayServer.clipboard_set(String(Dictionary(runs[0]).get("report_text", "")))
	state.message = "Latest Combat Survey report copied."

func _save_current_survey_report() -> void:
	_save_report_text(state.survey_report_filename(), state.survey_report_text())

func _export_all_survey_reports() -> void:
	var text := state.survey_all_reports_text()
	if text.is_empty():
		_set_survey_export_status("Nothing exported: the Combat Survey archive is empty.", false)
		return
	_save_report_text("Waystone_Combat_Survey_ALL_%s.txt" % Time.get_date_string_from_system(), text)

func _share_current_survey_report() -> void:
	_share_report_text(state.survey_report_filename(), state.survey_report_text())

func _share_report_text(filename: String, text: String) -> void:
	if OS.has_feature("android") and Engine.has_singleton("AndroidRuntime"):
		var android_runtime = Engine.get_singleton("AndroidRuntime")
		var activity = android_runtime.getActivity()
		var Intent = JavaClassWrapper.wrap("android.content.Intent")
		var intent = Intent.Intent()
		intent.setAction(Intent.ACTION_SEND)
		intent.putExtra(Intent.EXTRA_SUBJECT, filename)
		intent.putExtra(Intent.EXTRA_TEXT, text)
		intent.setType("text/plain")
		activity.startActivity(Intent.createChooser(intent, "Share Waystone combat report"))
		state.message = "Android share sheet opened."
	else:
		DisplayServer.clipboard_set(text)
		state.message = "Report copied; paste it into the destination you want."

func _save_report_text(filename: String, text: String) -> bool:
	if OS.has_feature("android"):
		if not Engine.has_singleton("AndroidRuntime"):
			return _android_report_export_failed("Android's export bridge is unavailable.", text)
		var android_runtime = Engine.get_singleton("AndroidRuntime")
		var activity = android_runtime.getActivity()
		if activity == null or _android_call_failed("getting the app activity"):
			return _android_report_export_failed("Android could not access the app activity.", text)
		var BuildVersion = JavaClassWrapper.wrap("android.os.Build$VERSION")
		if int(BuildVersion.SDK_INT) < 29:
			return _android_report_export_failed("This Android version cannot export directly to Downloads.", text)
		var ContentValues = JavaClassWrapper.wrap("android.content.ContentValues")
		var Downloads = JavaClassWrapper.wrap("android.provider.MediaStore$Downloads")
		var values = ContentValues.ContentValues()
		values.put("_display_name", filename)
		values.put("mime_type", "text/plain")
		values.put("relative_path", "Download/Waystone")
		values.put("is_pending", 1)
		if _android_call_failed("preparing the Downloads entry"):
			return _android_report_export_failed("Android rejected the report metadata.", text)
		var resolver = activity.getContentResolver()
		var uri = resolver.insert(Downloads.EXTERNAL_CONTENT_URI, values)
		if uri == null or _android_call_failed("creating the Downloads entry"):
			return _android_report_export_failed("Android could not create the report in Downloads.", text)
		var stream = resolver.openOutputStream(uri, "w")
		if stream == null or _android_call_failed("opening the report file"):
			resolver.delete(uri, null, null)
			_android_call_failed("removing the incomplete report")
			return _android_report_export_failed("Android could not open the report file.", text)
		stream.write(text.to_utf8_buffer())
		stream.flush()
		stream.close()
		if _android_call_failed("writing the report"):
			resolver.delete(uri, null, null)
			_android_call_failed("removing the incomplete report")
			return _android_report_export_failed("Android could not finish writing the report.", text)
		var completed_values = ContentValues.ContentValues()
		completed_values.put("is_pending", 0)
		resolver.update(uri, completed_values, null, null)
		if _android_call_failed("publishing the report"):
			resolver.delete(uri, null, null)
			_android_call_failed("removing the unpublished report")
			return _android_report_export_failed("Android wrote the report but could not publish it to Downloads.", text)
		_set_survey_export_status("EXPORTED — Downloads/Waystone/%s" % filename, true)
		return true
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var path := downloads.path_join(filename)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_survey_export_status("Export failed: could not save %s" % filename, false)
		return false
	file.store_string(text)
	file.flush()
	_set_survey_export_status("EXPORTED — %s" % path, true)
	return true

func _android_call_failed(context: String) -> bool:
	var exception = JavaClassWrapper.get_exception()
	if exception == null: return false
	printerr("Android report export failed while %s: %s" % [context, exception])
	return true

func _android_report_export_failed(reason: String, text: String) -> bool:
	DisplayServer.clipboard_set(text)
	_set_survey_export_status("EXPORT FAILED — %s The complete report was copied to the clipboard." % reason, false)
	return false

func _set_survey_export_status(text: String, succeeded: bool) -> void:
	survey_export_status = text
	state.message = text
	if survey_export_status_label != null and is_instance_valid(survey_export_status_label):
		survey_export_status_label.text = text
		survey_export_status_label.visible = true
		survey_export_status_label.add_theme_color_override("font_color", Color("8de0ad") if succeeded else Color("ffb4a8"))
	queue_redraw()

func _layout() -> void:
	safe_layout_rect = _display_safe_layout_rect()
	var layout_size := safe_layout_rect.size
	var layout_origin := safe_layout_rect.position
	var portrait := layout_size.y >= layout_size.x
	board_area = Rect2(layout_origin, Vector2(layout_size.x, layout_size.y * 0.735)) if portrait else Rect2(layout_origin, Vector2(layout_size.x * 0.74, layout_size.y))
	_update_projection()
	buttons.clear()
	consumable_rects.clear()
	loadout_rects.clear()
	upgrade_rects.clear()
	progression_rects.clear()
	dev_section_rects.clear()
	survey_profile_rects.clear()
	combat_rule_rects.clear()
	boss_choice_rects.clear()
	spell_rects.clear()
	var names := ["defense", "skill", "rally", "advance", "adopted"]
	var belt_names := ["healing", "slot_0", "slot_1", "slot_2"]
	var loadouts := ["warrior"]
	if portrait:
		var gap := layout_size.x * 0.025
		var tab_height := clampf(layout_size.y * 0.038, 38.0, 58.0)
		# Laid out from the bottom up. The action row used to absorb whatever vertical space
		# was left over, so adding a spell row above it squeezed the buttons and the spells
		# ended up larger than the skills they sit beside. Both are now the same authored
		# height and the drawer is what moves everything else.
		var action_height := clampf(layout_size.y * 0.058, 46.0, 78.0)
		var action_top := safe_layout_rect.end.y - gap - action_height
		var action_width := (layout_size.x - gap * float(names.size() + 1)) / float(names.size())
		for i in range(names.size()):
			buttons[names[i]] = Rect2(layout_origin.x + gap + i * (action_width + gap), action_top, action_width, action_height)
		var cursor := action_top - gap * 0.55
		var spells := _spell_row()
		if spellbook_open and not spells.is_empty():
			var pad := gap * 0.4
			var panel_height := action_height + pad * 2.0
			spellbook_panel = Rect2(layout_origin.x + gap, cursor - panel_height, layout_size.x - gap * 2.0, panel_height)
			var chip_gap := gap * 0.55
			var chip_width := (spellbook_panel.size.x - pad * 2.0 - chip_gap * float(spells.size() - 1)) / float(spells.size())
			for i in range(spells.size()):
				spell_rects[spells[i]] = Rect2(spellbook_panel.position.x + pad + float(i) * (chip_width + chip_gap), spellbook_panel.position.y + pad, chip_width, action_height)
			# The arrow notches into the button the drawer belongs to, so the panel reads as
			# that slot opening rather than as five more unexplained controls.
			spellbook_arrow_x = Rect2(buttons["advance"]).get_center().x
			cursor = spellbook_panel.position.y - gap * 0.55
		else:
			spellbook_panel = Rect2()
		var belt_height := clampf(layout_size.y * 0.070, 46.0, 78.0)
		var belt_top := cursor - belt_height
		var belt_width := (layout_size.x - gap * float(belt_names.size() + 1)) / float(belt_names.size())
		for i in range(belt_names.size()): consumable_rects[belt_names[i]] = Rect2(layout_origin.x + gap + i * (belt_width + gap), belt_top, belt_width, belt_height)
		var wait_height := clampf(layout_size.y * 0.045, 44.0, 66.0)
		interaction_rect = Rect2(layout_origin.x + gap, belt_top - gap * 0.45 - wait_height, layout_size.x - gap * 2.0, wait_height)
		loadout_rects["warrior"] = Rect2(layout_origin.x + gap, interaction_rect.position.y - gap * 0.45 - tab_height, layout_size.x - gap * 2.0, tab_height)
		var upgrade_width := (layout_size.x - gap * 4.0) / 3.0
		for i in range(3): upgrade_rects[i] = Rect2(layout_origin.x + gap + i * (upgrade_width + gap), action_top, upgrade_width, action_height)
	else:
		var left := layout_origin.x + layout_size.x * 0.755
		var gap := layout_size.y * 0.025
		var tab_height := (layout_size.y * 0.22 - gap * 2.0)
		loadout_rects["warrior"] = Rect2(left, layout_origin.y + gap, safe_layout_rect.end.x - left - gap, tab_height)
		var wait_height := clampf(layout_size.y * 0.075, 44.0, 66.0)
		interaction_rect = Rect2(left, Rect2(loadout_rects["warrior"]).end.y + gap, safe_layout_rect.end.x - left - gap, wait_height)
		var belt_top := interaction_rect.end.y + gap
		var belt_height := clampf(layout_size.y * 0.075, 44.0, 64.0)
		var belt_width := (safe_layout_rect.end.x - left - gap * float(belt_names.size() + 1)) / float(belt_names.size())
		for i in range(belt_names.size()): consumable_rects[belt_names[i]] = Rect2(left + i * (belt_width + gap), belt_top, belt_width, belt_height)
		var action_top := belt_top + belt_height + gap
		var action_bottom := safe_layout_rect.end.y - gap
		var height := (action_bottom - action_top - gap * float(names.size() + 1)) / float(names.size())
		for i in range(names.size()):
			buttons[names[i]] = Rect2(left, action_top + gap + i * (height + gap), safe_layout_rect.end.x - left - gap, height)
		var spells := _spell_row()
		if spellbook_open and not spells.is_empty():
			# Sized to its contents rather than to the button it hangs off. Five chips inside
			# one button's height were unreadable, and the drawer is allowed to be taller
			# than its handle -- it just stays centred on it so the tether still reads.
			var anchor := Rect2(buttons["advance"])
			var pad := gap * 0.3
			var chip_gap := gap * 0.3
			var chip_height := clampf(layout_size.y * 0.075, 40.0, 62.0)
			var panel_width := minf(layout_size.x * 0.30, 260.0)
			var panel_height := chip_height * float(spells.size()) + chip_gap * float(spells.size() - 1) + pad * 2.0
			# The attack button lives in the board's bottom-right corner, which is exactly
			# where a drawer centred on the Spellbook slot wants to be. Lift the panel clear
			# rather than let a chip sit under a control the player is aiming for.
			# attack_rect is not built until further down this function, so its top edge is
			# derived here from the same board geometry rather than read stale from the
			# previous frame.
			var attack_size_here := clampf(minf(layout_size.x, layout_size.y) * 0.092, 66.0, 92.0)
			var panel_floor := minf(safe_layout_rect.end.y - gap, board_rect.end.y - attack_size_here - 48.0 - gap * 0.5)
			var panel_top := clampf(anchor.get_center().y - panel_height * 0.5, safe_layout_rect.position.y + gap, maxf(safe_layout_rect.position.y + gap, panel_floor - panel_height))
			spellbook_panel = Rect2(anchor.position.x - gap * 0.7 - panel_width, panel_top, panel_width, panel_height)
			for i in range(spells.size()):
				spell_rects[spells[i]] = Rect2(spellbook_panel.position.x + pad, spellbook_panel.position.y + pad + float(i) * (chip_height + chip_gap), panel_width - pad * 2.0, chip_height)
			spellbook_arrow_x = -1.0
			spellbook_arrow_y = anchor.get_center().y
		else:
			spellbook_panel = Rect2()
		var upgrade_height := (action_bottom - action_top - gap * 4.0) / 3.0
		for i in range(3): upgrade_rects[i] = Rect2(left, action_top + gap + i * (upgrade_height + gap), safe_layout_rect.end.x - left - gap, upgrade_height)
	var attack_size := clampf(minf(layout_size.x, layout_size.y) * 0.092, 66.0, 92.0)
	var attack_bottom_lift := 34.0 if portrait else 48.0
	attack_rect = Rect2(Vector2(board_rect.end.x - attack_size - 14.0, board_rect.end.y - attack_size - attack_bottom_lift), Vector2(attack_size, attack_size))
	var reset_size := Vector2(clampf(layout_size.x * 0.13, 68.0, 104.0), clampf(layout_size.y * 0.035, 36.0, 52.0))
	reset_rect = Rect2(board_rect.end - reset_size - Vector2(8.0, board_rect.size.y - reset_size.y - 8.0), reset_size)
	view_rect = Rect2(reset_rect.position - Vector2(reset_size.x + 8.0, 0.0), reset_size)
	map_rect = Rect2(view_rect.position - Vector2(reset_size.x + 8.0, 0.0), reset_size)
	sheet_button_rect = Rect2(map_rect.position - Vector2(reset_size.x + 8.0, 0.0), reset_size)
	survey_end_rect = Rect2(sheet_button_rect.position - Vector2(reset_size.x + 8.0, 0.0), reset_size)
	var sheet_size := Vector2(minf(layout_size.x - 30.0, 1080.0), minf(layout_size.y - 34.0, 790.0))
	sheet_panel_rect = Rect2(layout_origin + (layout_size - sheet_size) * 0.5, sheet_size)
	sheet_close_rect = Rect2(sheet_panel_rect.end - Vector2(102.0, sheet_panel_rect.size.y - 10.0), Vector2(92.0, 38.0))
	var setup_gap := clampf(minf(layout_size.x, layout_size.y) * 0.018, 8.0, 20.0)
	var setup_width := minf(layout_size.x * 0.76, 640.0) if portrait else minf(layout_size.x * 0.52, 620.0)
	var setup_left := layout_origin.x + (layout_size.x - setup_width) * 0.5
	setup_class_rects.clear()
	boss_arena_rect = Rect2()
	if setup_stage == "root" or custom_room_open:
		# Four buttons and nothing else. Any additional control on this screen is another
		# chance to overlap something.
		seed_input.visible = false
		setup_back_rect = Rect2()
		custom_open_rect = Rect2()
		start_rect = Rect2()
		var button_height := clampf(layout_size.y * 0.105, 64.0, 106.0)
		var stack_height := button_height * 4.0 + setup_gap * 3.0
		var stack_top := layout_origin.y + (layout_size.y - stack_height) * 0.5
		for index in range(4):
			var mode_id: String = ["expedition", "campaign_lab", "combat_survey", "boss_lab"][index]
			progression_rects[mode_id] = Rect2(setup_left, stack_top + float(index) * (button_height + setup_gap), setup_width, button_height)
	else:
		# _sync_setup_controls already decides this correctly; _layout used to overrule it
		# with an unconditional true, so any relayout during a run put the world-seed field
		# back on screen over whatever the canvas was drawing. It was noticed on the
		# character sheet, and 0.2.65 made it far more frequent by relaying out whenever the
		# spellbook's contents change.
		seed_input.visible = state == null or not state.run_active
		var row := layout_origin.y + 74.0
		setup_back_rect = Rect2(setup_left, layout_origin.y + 16.0, clampf(setup_width * 0.32, 96.0, 160.0), 44.0)
		var class_height := clampf(layout_size.y * 0.052, 44.0, 62.0)
		var choices := CombatCatalogScript.loadout_ids()
		for index in range(choices.size()):
			setup_class_rects[String(choices[index])] = Rect2(setup_left, row + float(index) * (class_height + 6.0), setup_width, class_height)
		row += float(choices.size()) * (class_height + 6.0) + 12.0
		var half := (setup_width - setup_gap) * 0.5
		var option_height := clampf(layout_size.y * 0.045, 40.0, 52.0)
		if setup_mode == "combat_survey":
			survey_profile_rects["encounter"] = Rect2(setup_left, row, half, option_height)
			survey_profile_rects["attrition"] = Rect2(setup_left + half + setup_gap, row, half, option_height)
			row += option_height + 8.0
		if setup_mode == "boss_lab":
			boss_choice_rects["werewolf"] = Rect2(setup_left, row, half, option_height)
			boss_choice_rects["warden"] = Rect2(setup_left + half + setup_gap, row, half, option_height)
			row += option_height + 8.0
			boss_arena_rect = Rect2(setup_left, row, setup_width, option_height)
			row += option_height + 8.0
		if setup_mode in ["combat_survey", "boss_lab"]:
			combat_rule_rects["recovery"] = Rect2(setup_left, row, half, option_height)
			combat_rule_rects["energy"] = Rect2(setup_left + half + setup_gap, row, half, option_height)
			row += option_height + 8.0
		# Before the seed field, never under it: seed_input is a real LineEdit node and
		# paints over anything the canvas draws beneath it.
		if setup_mode == "combat_survey":
			custom_open_rect = Rect2(setup_left, row, setup_width, option_height)
			row += option_height + 8.0
		else:
			custom_open_rect = Rect2()
		seed_input.position = Vector2(setup_left, row)
		seed_input.size = Vector2(setup_width, clampf(layout_size.y * 0.05, 44.0, 56.0))
		row += seed_input.size.y + 10.0
		start_rect = Rect2(setup_left, row, setup_width, clampf(minf(layout_size.y * 0.07, safe_layout_rect.end.y - row - 8.0), 44.0, 72.0))
	_layout_custom_room_panel()
	archive_button_rect = Rect2(Vector2(safe_layout_rect.end.x - 174.0, layout_origin.y + 18.0), Vector2(156.0, 44.0))
	if survey_overlay != null:
		var overlay_margin := Vector2(maxf(12.0, layout_size.x * 0.04), maxf(12.0, layout_size.y * 0.035))
		survey_overlay.position = layout_origin + overlay_margin
		survey_overlay.size = layout_size - overlay_margin * 2.0
	map_mode_rect = _map_action_rect(1)
	seed_copy_rect = _map_action_rect(2)
	queue_redraw()

func _display_safe_layout_rect() -> Rect2:
	var viewport_rect := Rect2(Vector2.ZERO, size)
	if layout_safe_area_override.size.x > 0.0 and layout_safe_area_override.size.y > 0.0:
		return layout_safe_area_override.intersection(viewport_rect)
	if not OS.has_feature("mobile") or DisplayServer.get_name() == "headless": return viewport_rect
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe_pixels := Rect2(DisplayServer.get_display_safe_area())
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or safe_pixels.size.x <= 0.0 or safe_pixels.size.y <= 0.0:
		return viewport_rect
	var viewport_per_screen := Vector2(size.x / screen_size.x, size.y / screen_size.y)
	var safe_rect := Rect2(safe_pixels.position * viewport_per_screen, safe_pixels.size * viewport_per_screen)
	var clipped := safe_rect.intersection(viewport_rect)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 else viewport_rect

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
	# Latched on the rising edge of either signal, then run down on its own clock. The
	# simulation may hand the room over in well under two seconds -- the banner is not
	# allowed to be cut short by that, because the whole point is that the beat is long
	# enough to see. The rating overlay waits behind it.
	var clearing := state != null and (state.room_clear_pending or (state.is_measurement_mode() and state.survey_feedback_pending))
	if clearing and not room_clear_latched:
		room_clear_latched = true
		room_clear_remaining = ROOM_CLEAR_HOLD_SECONDS
	elif not clearing:
		room_clear_latched = false
	if room_clear_remaining > 0.0:
		room_clear_remaining = maxf(0.0, room_clear_remaining - delta)
		needs_redraw = true
	_sync_survey_overlay()
	var finished_streamed_movement := false
	if _autosave_frame_is_quiet(): autosave_quiet_elapsed += delta
	else: autosave_quiet_elapsed = 0.0
	if autosave_pending:
		autosave_elapsed += delta
		if autosave_elapsed >= AUTOSAVE_DELAY and autosave_quiet_elapsed >= AUTOSAVE_QUIET_DELAY and not autosave_deferred:
			autosave_deferred = true
			call_deferred("_flush_autosave_if_quiet")
	if streaming_action:
		# Mobile Casting is still one committed action: keys only steer movement while
		# simulation time is already advancing, and releasing them simply stops the walk.
		if state.mobile_cast_is_active() and desktop_controls:
			state.set_mobile_cast_direction(_desktop_held_direction())
		if String(state.player_action.get("kind", "")) == "advance" and desktop_controls and not advance_pointer_held:
			var held_advance_direction := _desktop_held_direction()
			var advance_direction := Vector2(state.player_action.get("direction", state.player_facing))
			state.set_advance_hold(not held_advance_direction.is_zero_approx() and held_advance_direction.dot(advance_direction) > 0.80)
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
		if wait_pointer_held and pointer_down:
			# Holding chains one movement step at a time, each a discrete commitment,
			# exactly as held movement does. Deliberately unassisted: Wait is movement
			# without the repositioning and carries movement's risks too, so there is no
			# auto-break on danger. A guardrail here alone would make standing still
			# safer than repositioning, which inverts the risk relationship.
			if state.interaction_label() != "WAIT":
				# The button became REST or TAKE mid-chain. End the chain rather than
				# firing a context action the player never asked for.
				wait_pointer_held = false
			else:
				_begin_streamed_action(state.request_wait(-1.0, false), finished_streamed_movement)
		elif queued_movement_after_attack:
			queued_movement_after_attack = false
			_begin_streamed_move(queued_attack_exit_direction, state.MOVE_RANGE, finished_streamed_movement)
		elif held_movement and pointer_down:
			if pointer_is_mouse: _commit_mouse_primary(finished_streamed_movement)
			else: _begin_streamed_move(held_direction, state.MOVE_RANGE, finished_streamed_movement)
		elif desktop_controls:
			var keyboard_direction := _desktop_held_direction()
			if not keyboard_direction.is_zero_approx(): _begin_streamed_move(keyboard_direction, state.MOVE_RANGE, finished_streamed_movement)
	if finished_streamed_movement and not streaming_action: stream_accumulator = 0.0
	if pointer_down and pointer_intent == "" and not held_movement and inspected_enemy_id < 0 and board_rect.has_point(touch_start):
		hold_elapsed += delta
		# A hold only becomes an attack when it began on a plausibly attackable
		# enemy. Empty ground and clearly distant melee targets become continuous
		# movement instead of phantom attacks.
		if hold_elapsed >= ATTACK_INTENT_DELAY and selected_action == "" and touch_current.distance_to(touch_start) < _touch_move_threshold():
			var touched_enemy := _enemy_near(touch_start, 54.0)
			if not touched_enemy.is_empty() and _enemy_touch_should_attack(touched_enemy):
				var direction := Vector2(touched_enemy["pos"]) - state.player_pos
				if direction.length_squared() < 0.01: direction = state.player_facing
				var soft_target_id := int(touched_enemy.get("id", -1))
				# The hold threshold has been crossed and the finger is still down,
				# so this sequence begins with a genuinely live input.
				var began := state.begin_bow_draw(direction, soft_target_id) if state.player_uses_ranged_basic_attack() else state.request_combo(direction, false, true)
				if began:
					pointer_intent = "attack"
					attack_pointer_held = true
					attack_touch_is_original = true
					_begin_streamed_action(true)
			else:
				pointer_intent = "move"
				held_movement = true
				held_movement_tracks_pointer = true
				held_direction = _pointer_follow_direction(touch_current)
				if not held_direction.is_zero_approx(): _begin_streamed_move(held_direction)
	if _update_temporal_tint(delta): needs_redraw = true
	if _update_area_title(delta): needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _update_temporal_tint(delta: float) -> bool:
	var target := 1.0 if state != null and state.run_active and not playing else 0.0
	var previous := temporal_tint_strength
	var rate := TEMPORAL_TINT_FADE_IN if target > temporal_tint_strength else TEMPORAL_TINT_FADE_OUT
	temporal_tint_strength = move_toward(temporal_tint_strength, target, rate * maxf(0.0, delta))
	return not is_equal_approx(previous, temporal_tint_strength)

func _update_area_title(delta: float) -> bool:
	if state == null or not state.run_active:
		var had_title := area_title_remaining > 0.0
		area_title_remaining = 0.0
		_presented_area_id = -999999
		return had_title
	if state.current_area_id != _presented_area_id:
		_presented_area_id = state.current_area_id
		area_title_name = state.current_area_name()
		area_title_subtitle = ""
		for area_value in state.areas:
			var area := Dictionary(area_value)
			if int(area.get("id", -1)) != _presented_area_id: continue
			area_title_subtitle = String(area.get("arrival_text", ""))
			break
		area_title_remaining = AREA_TITLE_DURATION
		return true
	if area_title_remaining <= 0.0: return false
	area_title_remaining = maxf(0.0, area_title_remaining - maxf(0.0, delta))
	return true

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
	for key in ["dodge_cooldown", "block_cooldown", "endure_cooldown", "skill_cooldown", "main_ability_cooldown", "subclass_ability_cooldown", "weapon_sequence_cooldown", "stealth_remaining", "aimed_remaining", "strength_remaining"]:
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
	if survey_overlay != null and survey_overlay.visible: return
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
		# The overlay eats every press while it is up, so nothing behind it is reachable.
		# This has to come before the archive button, which sits in a corner the picker
		# covers -- otherwise a tap there opens the archive from underneath the panel.
		if custom_room_open:
			_handle_custom_room_press(position)
			return
		if archive_button_rect.has_point(position):
			_build_survey_archive_overlay()
			return
		if setup_stage == "root":
			# Four buttons, and nothing else can be hit. Choosing a path is the only
			# decision this screen offers.
			for mode in progression_rects:
				if Rect2(progression_rects[mode]).has_point(position):
					setup_mode = String(mode)
					if setup_mode not in ["combat_survey", "boss_lab"]: setup_combat_rules = "energy"
					setup_stage = "options"
					_layout()
					return
			return
		if setup_back_rect.has_point(position):
			setup_stage = "root"
			seed_input.release_focus()
			_layout()
			return
		for choice in CombatCatalogScript.loadout_ids():
			if _setup_class_rect(choice).has_point(position):
				setup_loadout = choice
				queue_redraw()
				return
		if custom_open_rect.has_point(position) and setup_mode == "combat_survey":
			custom_room_open = true
			custom_page = "room"
			custom_editing_slot = -1
			_layout()
			return
		if setup_mode == "combat_survey":
			for profile in survey_profile_rects:
				if Rect2(survey_profile_rects[profile]).has_point(position):
					setup_survey_profile = String(profile)
					queue_redraw()
					return
			for rule in combat_rule_rects:
				if Rect2(combat_rule_rects[rule]).has_point(position):
					setup_combat_rules = String(rule)
					queue_redraw()
					return
		elif setup_mode == "boss_lab":
			for boss_kind in boss_choice_rects:
				if Rect2(boss_choice_rects[boss_kind]).has_point(position):
					setup_boss_kind = String(boss_kind)
					queue_redraw()
					return
			if boss_arena_rect.has_point(position):
				var arena_index := BOSS_LAB_ARENAS.find(setup_boss_arena)
				setup_boss_arena = BOSS_LAB_ARENAS[(arena_index + 1) % BOSS_LAB_ARENAS.size()]
				queue_redraw()
				return
			for rule in combat_rule_rects:
				if Rect2(combat_rule_rects[rule]).has_point(position):
					setup_combat_rules = String(rule)
					queue_redraw()
					return
		if start_rect.has_point(position): _start_run()
		return
	if state.is_measurement_mode() and survey_end_rect.has_point(position) and not state.survey_feedback_pending and not state.trial_complete:
		_build_survey_end_confirmation()
		return
	if character_sheet_open:
		if not sheet_detail.is_empty():
			_handle_sheet_detail_press(position)
			return
		if sheet_close_rect.has_point(position):
			character_sheet_open = false
			queue_redraw()
			return
		for slot_id in sheet_consumable_rects:
			if not Rect2(sheet_consumable_rects[slot_id]).has_point(position): continue
			var slot := int(String(slot_id).trim_prefix("slot_"))
			if sheet_repack_slot < 0:
				sheet_repack_slot = slot
				queue_redraw()
				return
			if sheet_repack_slot == slot:
				sheet_repack_slot = -1
				queue_redraw()
				return
			var first_slot := sheet_repack_slot
			sheet_repack_slot = -1
			character_sheet_open = false
			_begin_streamed_action(state.request_repack(first_slot, slot, false))
			return
		for upgrade_id in sheet_upgrade_rects:
			if Rect2(sheet_upgrade_rects[upgrade_id]).has_point(position):
				_open_sheet_upgrade_confirmation(String(upgrade_id))
				queue_redraw()
				return
		for art_id in sheet_art_rects:
			if Rect2(sheet_art_rects[art_id]).has_point(position):
				state.equip_weapon_art(String(art_id))
				visual = _presentation_snapshot()
				queue_redraw()
				return
		for property_id in sheet_property_rects:
			if String(property_id).ends_with("_detail"): continue
			if Rect2(sheet_property_rects[property_id]).has_point(position):
				sheet_detail = Dictionary(sheet_property_rects[property_id + "_detail"])
				queue_redraw()
				return
		for slot_id in sheet_equipment_rects:
			if String(slot_id).ends_with("_detail"): continue
			if Rect2(sheet_equipment_rects[slot_id]).has_point(position):
				sheet_detail = Dictionary(sheet_equipment_rects[slot_id + "_detail"])
				queue_redraw()
				return
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
	if not map_open and sheet_button_rect.has_point(position):
		if not playing:
			_open_character_sheet()
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
	if state.uses_energy_rules() and attack_rect.has_point(position):
		_press_direct_attack(position, is_mouse)
		return
	if playing:
		if board_rect.has_point(position) and state.mobile_cast_is_active():
			pointer_down = true
			pointer_is_mouse = is_mouse
			pointer_intent = "cast_move"
			held_movement = true
			held_movement_tracks_pointer = true
			touch_start = position
			touch_current = position
			state.set_mobile_cast_direction(_pointer_follow_direction(position))
			queue_redraw()
		elif board_rect.has_point(position) and state.resume_combo_hold():
			pointer_down = true
			pointer_is_mouse = is_mouse
			attack_pointer_held = true
			attack_touch_is_original = false
			held_movement = false
			held_movement_tracks_pointer = false
			touch_start = position
			touch_current = position
			queue_redraw()
		return
	if state.player_hp <= 0:
		return
	pointer_down = true
	pointer_intent = ""
	pointer_is_mouse = is_mouse
	held_movement = false
	held_movement_tracks_pointer = false
	attack_pointer_held = false
	attack_touch_is_original = false
	queued_movement_after_attack = false
	hold_elapsed = 0.0
	hold_consumed = false
	inspected_enemy_id = -1
	touch_start = position
	touch_current = position
	if interaction_rect.has_point(position) and state.interaction_label() == "WAIT":
		pointer_intent = "wait"
		wait_pointer_held = true
		_begin_streamed_action(state.request_wait(-1.0, false))
		return
	if selected_action == "advance" and board_rect.has_point(position):
		if state.loadout_id == "rogue_sharpshooter": return
		var advance_direction := _screen_to_world(position) - state.player_pos
		if advance_direction.length_squared() < 0.01: advance_direction = state.player_facing
		selected_action = ""
		advance_pointer_held = state.loadout_id == "warrior"
		_begin_streamed_action(_request_subclass_direction(advance_direction))
		return
	if selected_action == "defense" and state.defense_id == "block" and board_rect.has_point(position):
		var guard_direction := _screen_to_world(position) - state.player_pos
		if guard_direction.length_squared() < 0.01: guard_direction = state.player_facing
		selected_action = ""
		defense_pointer_held = true
		_begin_streamed_action(state.request_block(guard_direction, false))
		return

func _press_direct_attack(position: Vector2, is_mouse: bool) -> void:
	selected_action = ""
	if playing:
		if state.resume_combo_hold():
			pointer_down = true
			pointer_is_mouse = is_mouse
			pointer_intent = "attack_button"
			attack_pointer_held = true
			attack_touch_is_original = false
			attack_button_pointer_held = true
			touch_start = position
			touch_current = position
			queue_redraw()
		return
	if state.player_hp <= 0: return
	pointer_down = true
	pointer_is_mouse = is_mouse
	pointer_intent = "attack_button"
	attack_pointer_held = true
	attack_touch_is_original = true
	attack_button_pointer_held = true
	held_movement = false
	held_movement_tracks_pointer = false
	queued_movement_after_attack = false
	hold_elapsed = 0.0
	hold_consumed = false
	inspected_enemy_id = -1
	touch_start = position
	touch_current = position
	if not state.request_direct_attack(state.player_facing, false, true):
		pointer_down = false
		attack_pointer_held = false
		attack_touch_is_original = false
		attack_button_pointer_held = false
		pointer_intent = ""
		queue_redraw()
		return
	_begin_streamed_action(true)

func _handle_sheet_detail_press(position: Vector2) -> void:
	var kind := String(sheet_detail.get("kind", ""))
	if kind == "track_choice":
		for option_id in sheet_skill_choice_rects:
			if Rect2(sheet_skill_choice_rects[option_id]).has_point(position):
				sheet_detail["selected"] = String(option_id)
				queue_redraw()
				return
	if sheet_detail_confirm_rect.has_point(position):
		var choice := String(sheet_detail.get("selected", "")) if kind == "track_choice" else String(sheet_detail.get("upgrade_id", ""))
		if not choice.is_empty() and state.choose_upgrade(choice):
			visual = _presentation_snapshot()
			_mark_autosave(true)
			sheet_detail.clear()
			queue_redraw()
		return
	if sheet_detail_close_rect.has_point(position):
		sheet_detail.clear()
		queue_redraw()

func _open_sheet_upgrade_confirmation(upgrade_id: String) -> void:
	var cost := state.next_upgrade_cost()
	if not state.available_level_up_options().has(upgrade_id): return
	var track := CombatCatalogScript.character_track(upgrade_id)
	var stage := state.next_track_stage(upgrade_id)
	if track.is_empty() or stage.is_empty(): return
	var choices: Array = stage.get("choices", [])
	sheet_detail = {
		"kind": "track_choice" if not choices.is_empty() else "upgrade",
		"track": String(track.get("label", "Track")),
		"track_description": String(track.get("description", "")),
		"stage": stage,
		"options": choices,
		"selected": "",
		"upgrade_id": upgrade_id,
		"cost": cost,
	}

func _pointer_dragged(position: Vector2) -> void:
	if not pointer_down:
		return
	touch_current = position
	if pointer_intent == "cast_move":
		state.set_mobile_cast_direction(_pointer_follow_direction(position))
		queue_redraw()
		return
	if attack_button_pointer_held:
		# The dedicated button is a deliberate facing-direction attack. Finger
		# drift never turns it into world movement or retargets a Bow draw.
		return
	if attack_pointer_held:
		if state.player_uses_ranged_basic_attack() and String(state.player_action.get("kind", "")) == "bow_draw":
			state.set_bow_aim(_screen_to_world(position) - state.player_pos)
			queue_redraw()
			return
		if attack_touch_is_original:
			# An uninterrupted original press always means "keep attacking," even if
			# the finger drifts into a directional swipe.
			return
		var attack_drag := position - touch_start
		var attack_threshold := _touch_move_threshold()
		if attack_drag.length() < attack_threshold or not board_rect.has_point(touch_start): return
		# A directional drag is an exit plan, never a latent attack continuation.
		attack_pointer_held = false
		attack_touch_is_original = false
		state.set_attack_hold(false)
		held_direction = _screen_delta_to_world_direction(attack_drag)
		held_movement = true
		held_movement_tracks_pointer = false
		queued_attack_exit_direction = held_direction
		queued_movement_after_attack = true
		queue_redraw()
		return
	if defense_pointer_held:
		state.set_block_direction(_screen_to_world(position) - state.player_pos)
		queue_redraw()
		return
	if advance_pointer_held:
		advance_pointer_held = false
		state.set_advance_hold(false)
		queue_redraw()
		return
	if held_movement and held_movement_tracks_pointer:
		var follow_direction := _pointer_follow_direction(position)
		if not follow_direction.is_zero_approx(): held_direction = follow_direction
		queue_redraw()
		return
	var drag := position - touch_start
	var threshold := _touch_move_threshold()
	if drag.length() < threshold or selected_action != "" or not board_rect.has_point(touch_start):
		return
	inspected_enemy_id = -1
	pointer_intent = "move"
	held_direction = _screen_delta_to_world_direction(drag)
	if not held_movement:
		held_movement = true
		held_movement_tracks_pointer = false
		if not playing:
			_begin_streamed_move(held_direction)

func _pointer_released(position: Vector2) -> void:
	if not pointer_down:
		return
	pointer_down = false
	pointer_is_mouse = false
	if pointer_intent == "cast_move":
		state.set_mobile_cast_direction(Vector2.ZERO)
		held_movement = false
		held_movement_tracks_pointer = false
		held_direction = Vector2.ZERO
		pointer_intent = ""
		queue_redraw()
		return
	if wait_pointer_held or pointer_intent == "wait":
		wait_pointer_held = false
		pointer_intent = ""
		queue_redraw()
		return
	if defense_pointer_held:
		defense_pointer_held = false
		wait_pointer_held = false
		state.set_block_hold(false)
		pointer_intent = ""
		queue_redraw()
		return
	if attack_pointer_held:
		var released_direct_button := attack_button_pointer_held
		attack_pointer_held = false
		attack_touch_is_original = false
		attack_button_pointer_held = false
		if String(state.player_action.get("kind", "")) == "bow_draw": state.release_bow_attack(state.player_facing if released_direct_button else _screen_to_world(position) - state.player_pos)
		else: state.set_attack_hold(false)
		pointer_intent = ""
		queue_redraw()
		return
	if hold_consumed:
		hold_consumed = false
		hold_elapsed = 0.0
		inspected_enemy_id = -1
		queue_redraw()
		return
	if held_movement:
		held_movement = false
		held_movement_tracks_pointer = false
		held_direction = Vector2.ZERO
		pointer_intent = ""
		return
	_handle_gesture(position)
	pointer_intent = ""

func _unhandled_key_input(event: InputEvent) -> void:
	if survey_overlay != null and survey_overlay.visible: return
	if desktop_controls and event.keycode == KEY_F:
		if event.pressed:
			if event.echo: return
			if String(state.player_action.get("kind", "")) == "bow_draw": return
			if playing:
				if state.resume_combo_hold():
					attack_key_held = true
					queue_redraw()
				return
			if not _can_repeat_primary_action(): return
			var attack_direction := _desktop_held_direction()
			if attack_direction.is_zero_approx(): attack_direction = state.player_facing
			# The attack key is down and stays down until its release event, so the
			# sequence begins live and continues for as long as the key is held.
			var began := state.request_direct_attack(attack_direction, false, true) if state.uses_energy_rules() else state.begin_bow_draw(attack_direction) if state.player_uses_ranged_basic_attack() else state.request_combo(attack_direction, false, true)
			if began:
				attack_key_held = true
				_begin_streamed_action(true)
		else:
			if attack_key_held:
				attack_key_held = false
				if String(state.player_action.get("kind", "")) == "bow_draw": state.release_bow_attack(state.player_facing)
				else: state.set_attack_hold(false)
				queue_redraw()
		return
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
		# The keyboard has to obey the same two screens as the touch path, or Enter starts
		# a run from a screen that never offered a class, a rule set or a room spec.
		if custom_room_open:
			if event.keycode == KEY_ESCAPE:
				custom_room_open = false
				_layout()
			return
		if setup_stage == "root":
			match event.keycode:
				KEY_TAB:
					var modes := ["expedition", "campaign_lab", "combat_survey", "boss_lab"]
					setup_mode = String(modes[(modes.find(setup_mode) + 1) % modes.size()])
					if setup_mode not in ["combat_survey", "boss_lab"]: setup_combat_rules = "energy"
				KEY_ENTER:
					setup_stage = "options"
					_layout()
				_: return
			queue_redraw()
			return
		match event.keycode:
			KEY_1: setup_loadout = "warrior"
			KEY_2: setup_loadout = "rogue_acrobat"
			KEY_3: setup_loadout = "rogue_sharpshooter"
			KEY_ESCAPE:
				setup_stage = "root"
				seed_input.release_focus()
				_layout()
			KEY_TAB:
				if setup_mode == "combat_survey":
					setup_dev_section = "custom" if setup_dev_section == "survey" else "survey"
					_layout()
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
	if event.keycode == KEY_ESCAPE and character_sheet_open:
		if not sheet_detail.is_empty(): sheet_detail.clear()
		else: character_sheet_open = false
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
			if state.learn_at_waystone():
				waystone_menu_open = false
				_open_character_sheet()
		elif event.keycode in [KEY_2, KEY_ENTER, KEY_C]: waystone_menu_open = false
		visual = _presentation_snapshot()
		queue_redraw()
		return
	if event.keycode == KEY_C:
		character_sheet_open = not character_sheet_open
		if character_sheet_open:
			_open_character_sheet()
		queue_redraw()
		return
	if character_sheet_open: return
	if event.keycode == KEY_V:
		_toggle_view()
		return
	match event.keycode:
		KEY_1, KEY_P: _handle_consumable("healing")
		KEY_2, KEY_SHIFT, KEY_B: _handle_button("defense")
		KEY_3, KEY_Q: _handle_button("skill")
		KEY_4: _handle_button("rally")
		KEY_5, KEY_E: _handle_button("advance")
		KEY_6: _handle_button("adopted")
		KEY_SPACE: _advance_or_wait()
		KEY_7: _handle_consumable("slot_0")
		KEY_8: _handle_consumable("slot_1")
		KEY_9: _handle_consumable("slot_2")
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
	if not state.run_active or not state.is_player_ready() or state.trial_complete or state.survey_feedback_pending: return false
	if waystone_menu_open or state.death_pending or character_sheet_open: return false
	return not (map_open and state.map_presentation == "full")

func _commit_mouse_primary(preserve_stream_time: bool = false) -> void:
	if not _can_repeat_primary_action() or not board_rect.has_point(touch_current): return
	var enemy := _enemy_near(touch_current, 54.0)
	if not enemy.is_empty() and _enemy_touch_should_attack(enemy):
		# Reached only while the mouse button is still down, so the input is live.
		_begin_streamed_action(_request_primary_attack(enemy, true), preserve_stream_time)
		return
	var target := Vector2(enemy["pos"]) if not enemy.is_empty() else _screen_to_world(touch_current)
	var delta := target - state.player_pos
	if delta.length() < 8.0: return
	_begin_streamed_move(delta, minf(delta.length(), state.MOVE_RANGE), preserve_stream_time)

# `held` must be supplied by the caller rather than assumed. The held-mouse repeat
# path arrives here with the button still down, while the tap path runs from inside
# _pointer_released and has no live input behind it at all.
func _request_primary_attack(enemy: Dictionary, held: bool = false) -> bool:
	var target := Vector2(enemy["pos"])
	if state.player_uses_ranged_basic_attack():
		return state.request_attack(target, false)
	var direction := target - state.player_pos
	if direction.length_squared() < 0.01: direction = state.player_facing
	return state.request_combo(direction, false, held)

func _enemy_touch_should_attack(tapped_enemy: Dictionary) -> bool:
	# This is deliberately an intent heuristic, not a second hit test. A player may
	# pre-swing, misjudge distance, or be baited by a moving foe; only a plainly
	# implausible melee attempt becomes movement.
	if state.player_uses_ranged_basic_attack(): return true
	var target_pos := Vector2(tapped_enemy["pos"])
	var touch_direction := state.player_pos.direction_to(target_pos)
	if touch_direction.length_squared() < 0.001: touch_direction = state.player_facing
	var definition := state.player_basic_attack_definition()
	var technique := AttackGeometryScript.technique(String(definition.get("technique", "diagonal_cut")))
	var nominal_reach := float(definition.get("reach", state.player_attack_reach)) + float(technique.get("radius", 0.0))
	var target_radius := float(tapped_enemy.get("radius", 24.0))
	if state.player_pos.distance_to(target_pos) <= nominal_reach + target_radius + MELEE_TAP_ANTICIPATION:
		return true
	var visible := _render_visible_cells()
	var nearby_cosine := cos(MELEE_TAP_NEARBY_HALF_ANGLE)
	for enemy_value in state.enemies:
		var enemy: Dictionary = enemy_value
		if int(enemy.get("hp", 0)) <= 0 or String(enemy.get("layer", state.current_layer)) != state.current_layer: continue
		if not state.enemy_visible_to_player(enemy): continue
		var enemy_pos := Vector2(enemy["pos"])
		if not state.is_visible(enemy_pos, visible): continue
		var offset := enemy_pos - state.player_pos
		if offset.length_squared() < 0.001: return true
		if touch_direction.dot(offset.normalized()) < nearby_cosine: continue
		var nearby_distance := nominal_reach + float(enemy.get("radius", 24.0)) + MELEE_TAP_NEARBY_ALLOWANCE
		if offset.length() <= nearby_distance: return true
	return false

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		desktop_movement_keys.clear()
		attack_key_held = false
		attack_pointer_held = false
		attack_button_pointer_held = false
		advance_pointer_held = false
		defense_pointer_held = false
		wait_pointer_held = false
		if state != null: state.set_attack_hold(false)
		if state != null: state.set_advance_hold(false)
		if state != null: state.set_block_hold(false)
		pointer_down = false
		held_movement = false
		held_movement_tracks_pointer = false
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
	for slot_id in consumable_rects:
		if Rect2(consumable_rects[slot_id]).has_point(end_position):
			_handle_consumable(String(slot_id))
			return
	# Tested before the action row, because the spellbook sits directly above it and an
	# overlap must not be swallowed by whichever dictionary happens to iterate first.
	if _handle_spell_press(end_position): return
	for name in buttons:
		if Rect2(buttons[name]).has_point(end_position):
			_handle_button(String(name))
			return
	if interaction_rect.has_point(end_position):
		_advance_or_wait()
		return
	if not board_rect.has_point(end_position): return
	if _try_pickup_press(end_position): return
	if _try_waystone_press(end_position): return
	if _try_transition_press(end_position): return
	var drag := end_position - touch_start
	var threshold := _touch_move_threshold()
	if drag.length() >= threshold:
		if selected_action in ["defense", "skill", "advance"] or selected_action.begins_with("consumable_"):
			var action := selected_action
			selected_action = ""
			var world_direction := _screen_delta_to_world_direction(drag)
			if action == "defense": _begin_streamed_action(state.request_defense(world_direction, false))
			elif action == "skill": _begin_streamed_action(state.request_skill(world_direction, false))
			elif action == "advance": _begin_streamed_action(_request_subclass_direction(world_direction))
			else: _begin_streamed_action(state.request_consumable(int(action.trim_prefix("consumable_")), world_direction, false))
		else:
			var enemy := _enemy_near(end_position, 62.0)
			if enemy.is_empty(): _begin_streamed_move(_screen_delta_to_world_direction(drag))
			elif _enemy_touch_should_attack(enemy): _begin_streamed_action(_request_primary_attack(enemy))
			else: _begin_streamed_move(_screen_delta_to_world_direction(drag))
		return
	var enemy := _enemy_near(end_position, 54.0)
	if not enemy.is_empty():
		if selected_action == "defense":
			# A selected Defense owns the next tap, including one that lands on an
			# enemy. Without this the tap fell through to the attack branch and
			# silently discarded the Dodge the player had already chosen -- and it
			# skipped the plausibility check too, so it would swing at a target well
			# out of reach. Tapping an enemy aims the Dodge at it, as dragging does.
			selected_action = ""
			_begin_streamed_action(state.request_defense(Vector2(enemy["pos"]) - state.player_pos, false))
		elif selected_action == "skill":
			selected_action = ""
			_begin_streamed_action(state.request_skill(Vector2(enemy["pos"]) - state.player_pos, false))
		elif selected_action == "advance" and state.loadout_id == "rogue_sharpshooter":
			selected_action = ""
			_begin_streamed_action(state.request_take_aim(int(enemy["id"]), false))
		elif selected_action == "" and not _enemy_touch_should_attack(enemy):
			var move_delta := Vector2(enemy["pos"]) - state.player_pos
			_begin_streamed_move(move_delta, minf(move_delta.length(), state.MOVE_RANGE))
		else: _begin_streamed_action(_request_primary_attack(enemy))
	elif selected_action == "defense":
		selected_action = ""
		var direction := _screen_to_world(end_position) - state.player_pos
		_begin_streamed_action(state.request_defense(direction, false))
	elif selected_action == "skill":
		selected_action = ""
		_begin_streamed_action(state.request_skill(_screen_to_world(end_position) - state.player_pos, false))
	elif selected_action == "advance":
		selected_action = ""
		_begin_streamed_action(_request_subclass_target(_screen_to_world(end_position)))
	elif selected_action.begins_with("consumable_"):
		var slot := int(selected_action.trim_prefix("consumable_"))
		selected_action = ""
		_begin_streamed_action(state.request_consumable(slot, _screen_to_world(end_position) - state.player_pos, false))
	else:
		var target := _screen_to_world(end_position)
		_begin_streamed_move(target - state.player_pos, minf(target.distance_to(state.player_pos), state.MOVE_RANGE))

func _touch_move_threshold() -> float:
	return maxf(TOUCH_MOVE_SLOP_MIN, minf(size.x, size.y) * TOUCH_MOVE_SLOP_SCALE)

func _pointer_follow_direction(screen_position: Vector2) -> Vector2:
	var direction := _screen_to_world(screen_position) - state.player_pos
	if direction.length_squared() < 0.01: return Vector2.ZERO
	return direction.normalized()

func _handle_button(name: String) -> void:
	match name:
		"potion": _begin_streamed_action(state.request_potion(false))
		"defense":
			if _defense_cooldown() <= 0.0001:
				if state.defense_id == "endure": _begin_streamed_action(state.request_endure(state.player_facing, false))
				else: selected_action = "" if selected_action == "defense" else "defense"
		"skill":
			if state.player_equipped_weapon_art != "" and state.skill_cooldown <= 0.0001 and not state.energy_actions_locked():
				selected_action = "" if selected_action == "skill" else "skill"
		"rally":
			selected_action = ""
			if state.loadout_id.begins_with("rogue_") and state.stealth_remaining > 0.0:
				# Free and instant: it stops a cost rather than starting an action, so
				# there is no streamed action to begin and no world time to spend.
				state.request_end_stealth()
				queue_redraw()
			elif state.loadout_id == "mage_elementalist":
				_begin_streamed_action(state.request_circle(false))
			elif state.rally_active:
				state.request_end_rally()
				queue_redraw()
			else:
				_begin_streamed_action(state.request_stealth(false) if state.loadout_id.begins_with("rogue_") else state.request_rally(false))
		"advance" when state.loadout_id == "mage_elementalist":
			# The button opens and closes the drawer; a chip inside it is what arms a cast.
			spellbook_open = not spellbook_open
			if not spellbook_open and selected_action == "advance": selected_action = ""
			_layout()
		"advance":
			var remaining := state.subclass_ability_cooldown if state.loadout_id.begins_with("rogue_") else state.advance_cooldown
			var energy_locked := state.loadout_id == "warrior" and state.energy_actions_locked()
			if remaining <= 0.0001 and not energy_locked:
				selected_action = "" if selected_action == "advance" else "advance"
		"adopted":
			selected_action = ""
	queue_redraw()

func _handle_consumable(slot_id: String) -> void:
	if slot_id == "healing":
		_begin_streamed_action(state.request_potion(false))
		queue_redraw()
		return
	var slot := int(slot_id.trim_prefix("slot_"))
	if state.has_pending_pickup():
		_begin_streamed_action(state.replace_pending_pickup(slot, false))
		queue_redraw()
		return
	if state.consumable_requires_direction(slot):
		selected_action = "" if selected_action == "consumable_%d" % slot else "consumable_%d" % slot
	else:
		selected_action = ""
		_begin_streamed_action(state.request_consumable(slot, state.player_facing, false))
	queue_redraw()

func _commit_direction(direction: Vector2) -> void:
	if selected_action == "defense":
		selected_action = ""
		_begin_streamed_action(state.request_defense(direction, false))
	elif selected_action == "skill":
		selected_action = ""
		_begin_streamed_action(state.request_skill(direction, false))
	elif selected_action == "advance":
		selected_action = ""
		_begin_streamed_action(_request_subclass_direction(direction))
	elif selected_action.begins_with("consumable_"):
		var slot := int(selected_action.trim_prefix("consumable_"))
		selected_action = ""
		_begin_streamed_action(state.request_consumable(slot, direction, false))
	else: _begin_streamed_move(direction)

func _request_subclass_direction(direction: Vector2) -> bool:
	return _request_subclass_target(state.player_pos + direction.normalized() * 340.0)

# A drag gives a heading and a tap gives a place. Both arrive here as a world point, and
# whether the point or only its direction survives is the spell's business rather than the
# input's -- an Earth Wall goes where you touched, a Fireball goes the way you pointed.
func _request_subclass_target(world_point: Vector2) -> bool:
	if state.loadout_id == "mage_elementalist":
		return state.request_spell(state.selected_spell, state.spell_target_for(state.selected_spell, world_point), false)
	var direction := world_point - state.player_pos
	if state.loadout_id == "rogue_acrobat": return state.request_vault(direction, false)
	if state.loadout_id == "rogue_sharpshooter":
		state.message = "Tap a visible enemy to Take Aim."
		return false
	return state.request_advance(direction, not _desktop_held_direction().is_zero_approx(), false)

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
	held_movement_tracks_pointer = false
	held_direction = Vector2.ZERO
	waystone_menu_open = false
	character_sheet_open = false
	_presented_area_id = -999999
	area_title_remaining = 0.0
	timeline.clear()
	visual = _presentation_snapshot()
	_sync_setup_controls()
	queue_redraw()

func _handle_custom_room_press(position: Vector2) -> void:
	if custom_page == "kind":
		for kind in custom_kind_rects:
			if not Rect2(custom_kind_rects[kind]).has_point(position): continue
			# Chosen from the add button appends; chosen from an existing row replaces it,
			# which is the whole reason tapping a filled slot reopens this page.
			if custom_editing_slot >= 0 and custom_editing_slot < custom_room_roster.size():
				custom_room_roster[custom_editing_slot] = String(kind)
			elif custom_room_roster.size() < 6:
				custom_room_roster.append(String(kind))
			custom_editing_slot = -1
			custom_page = "room"
			_layout()
			return
		if custom_done_rect.has_point(position) or not custom_panel_rect.has_point(position):
			# Backing out of the kind page cancels the edit rather than the room.
			custom_editing_slot = -1
			custom_page = "room"
			_layout()
		return
	for index in custom_remove_rects:
		if Rect2(custom_remove_rects[index]).has_point(position):
			custom_room_roster.remove_at(int(index))
			_layout()
			return
	for index in custom_slot_rects:
		if Rect2(custom_slot_rects[index]).has_point(position):
			custom_editing_slot = int(index)
			custom_page = "kind"
			_layout()
			return
	if custom_add_rect.has_point(position) and custom_room_roster.size() < 6:
		custom_editing_slot = -1
		custom_page = "kind"
		_layout()
		return
	for formation in custom_formation_rects:
		if Rect2(custom_formation_rects[formation]).has_point(position):
			custom_room_formation = String(formation)
			queue_redraw()
			return
	for percent in custom_hp_rects:
		if Rect2(custom_hp_rects[percent]).has_point(position):
			custom_room_hp = float(percent) / 100.0
			queue_redraw()
			return
	for direction in custom_level_rects:
		if Rect2(custom_level_rects[direction]).has_point(position):
			custom_room_level = clampi(custom_room_level + (1 if String(direction) == "up" else -1), 1, 15)
			queue_redraw()
			return
	if custom_repeat_rect.has_point(position):
		custom_room_repeat = not custom_room_repeat
		queue_redraw()
		return
	if custom_start_rect.has_point(position) and not custom_room_roster.is_empty():
		# Starting from here is the point of the rework: the room you just composed is the
		# room you want to play, and walking back out to press Start elsewhere was a step
		# that existed only because the panel was built as a sub-screen.
		custom_room_open = false
		_layout()
		_start_run()
		return
	if custom_clear_rect.size.x > 0.0 and custom_clear_rect.has_point(position):
		custom_room_roster.clear()
		custom_room_formation = ""
		_layout()
		return
	if custom_done_rect.has_point(position) or not custom_panel_rect.has_point(position):
		custom_room_open = false
		_layout()
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
	# Written before start_run, because the first room is generated inside it.
	var roster: Array[String] = []
	if _custom_section_active(): roster.assign(custom_room_roster)
	elif setup_mode == "boss_lab": roster.assign([setup_boss_kind])
	state.custom_room_kinds = roster
	state.custom_room_formation = custom_room_formation
	state.custom_room_hp_percent = custom_room_hp
	state.custom_room_xp = 0 if setup_mode == "boss_lab" else RunStateScript.xp_for_character_level(custom_room_level)
	state.custom_room_repeat = custom_room_repeat
	state.boss_lab_boss_kind = setup_boss_kind
	state.boss_lab_arena_id = setup_boss_arena
	state.boss_lab_variant_id = "solo_current"
	state.start_run(setup_loadout, setup_mode, chosen_seed, setup_survey_profile, setup_combat_rules)
	_finish_run_start()

func _finish_run_start() -> void:
	state.record_survey_view_mode(view_mode, false)
	state.prewarm_expedition_navigation()
	playing = false
	streaming_action = false
	stream_accumulator = 0.0
	map_open = false
	character_sheet_open = false
	waystone_menu_open = false
	selected_action = ""
	timeline.clear()
	visual = _presentation_snapshot()
	_presented_area_id = -999999
	_update_area_title(0.0)
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
	held_movement_tracks_pointer = false
	held_direction = Vector2.ZERO
	timeline.clear()
	visual = _presentation_snapshot()
	queue_redraw()

func _advance_or_wait() -> void:
	var interaction := state.interaction_label()
	if interaction == "WAIT": _begin_streamed_action(state.request_wait(-1.0, false))
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

func _try_pickup_press(position: Vector2) -> bool:
	var selected: Dictionary = {}
	for pickup_value in Array(visual.get("world_pickups", [])):
		var pickup: Dictionary = pickup_value
		if String(pickup.get("layer", state.current_layer)) != state.current_layer: continue
		if _world_to_screen(Vector2(pickup["pos"])).distance_to(position) <= maxf(34.0, 38.0 * world_scale): selected = pickup
	if selected.is_empty(): return false
	if state.player_pos.distance_to(Vector2(selected["pos"])) > 112.0:
		state.message = "Move closer to take the %s." % String(state.consumable_definition(String(selected.get("item_id", ""))).get("label", "item")).to_lower()
		visual = _presentation_snapshot()
		queue_redraw()
		return true
	_begin_streamed_action(state.request_collect_nearby_pickup(false))
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
	return Rect2(buttons["defense"]).merge(Rect2(buttons["skill"])) if option == "learn" else interaction_rect

func _handle_waystone_menu_press(position: Vector2) -> void:
	if _waystone_option_rect("learn").has_point(position):
		if state.learn_at_waystone():
			waystone_menu_open = false
			_open_character_sheet()
	elif _waystone_option_rect("continue").has_point(position):
		waystone_menu_open = false
	else: return
	visual = _presentation_snapshot()
	_mark_autosave(true)
	queue_redraw()

func _defense_cooldown() -> float:
	if state.defense_id == "block": return state.cooldown_remaining(state.COOLDOWN_BLOCK)
	if state.defense_id == "endure": return state.cooldown_remaining(state.COOLDOWN_ENDURE)
	return state.cooldown_remaining(state.COOLDOWN_DODGE)

func _on_state_changed() -> void:
	_mark_autosave()
	_sync_setup_controls()
	# Buying an element changes what the drawer holds, and the drawer's rects are built in
	# _layout(). Without this the row kept the geometry it had at run start, so a spell
	# learned mid-run had no rect to be drawn or tapped in and its locked slot stayed on
	# screen -- the element was bought, owned, and unreachable.
	if _spell_row() != _spell_row_keys(): _layout()
	queue_redraw()

func _spell_row_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in spell_rects: keys.append(String(key))
	return keys

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
	_draw_sheet_button()
	if state.is_measurement_mode(): _draw_survey_end_button()
	if map_open: _draw_map()
	if character_sheet_open: _draw_character_sheet()
	if state.death_pending: _draw_death_overlay()
	state.performance_metrics["draw_cpu_ms"] = float(Time.get_ticks_usec() - draw_start) / 1000.0

func _draw_world() -> void:
	draw_rect(board_rect, Color("05080a"))
	_draw_discovered_floor()
	_draw_grid()
	var discovered := _render_discovered_cells()
	var visible: Dictionary = _render_visible_cells()
	_prepare_occlusion_focus_bounds(visible)
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
			if String(feature.get("layer", state.current_layer)) == state.current_layer and _world_point_on_camera(feature_pos, float(feature.get("radius", 45.0)) * 2.5) and _terrain_feature_revealed(feature_pos, discovered): _draw_terrain_feature(feature)
	_draw_landmarks(visible, discovered)
	for sensed in Array(visual.get("sensed_enemies", [])):
		if String(sensed.get("layer", state.current_layer)) != state.current_layer: continue
		var sensed_pos := Vector2(sensed.get("pos", Vector2.ZERO))
		if not _world_point_on_camera(sensed_pos, 38.0): continue
		var sensed_screen := _world_to_screen(sensed_pos)
		draw_circle(sensed_screen, maxf(8.0, 13.0 * world_scale), Color(0.50, 0.74, 0.84, 0.12))
		draw_arc(sensed_screen, maxf(8.0, 13.0 * world_scale), 0.0, TAU, 16, Color(0.50, 0.74, 0.84, 0.48), maxf(1.5, 2.0 * world_scale))
	if view_mode == "top_down":
		for projectile in Array(visual.get("projectiles", [])):
			if _projectile_is_renderable(Dictionary(projectile), visible): _draw_projectile(Dictionary(projectile))
	for hazard in Array(visual.get("hazards", [])):
		if String(hazard.get("layer", state.current_layer)) != state.current_layer: continue
		if not _world_point_on_camera(Vector2(hazard["pos"]), float(hazard.get("radius", 100.0))): continue
		if state.is_visible(Vector2(hazard["pos"]), visible): _draw_hazard(hazard)
	# The Circle. Drawn on the ground as a ring with a faint fill, and brighter while the
	# player is standing in it, because "am I still on my ground" is the question the
	# ability exists to ask and it must be answerable at a glance.
	# All dynamic objects come from the same presentation frame. This keeps the Circle,
	# barriers and moving bodies on one simulation-time authority during streamed actions.
	var circle_left := float(visual.get("circle_remaining", 0.0))
	if circle_left > 0.0:
		var circle_centre := Vector2(visual.get("circle_pos", state.circle_pos))
		var circle_radius := float(visual.get("circle_radius", state.circle_radius()))
		var standing := Vector2(visual.get("player_pos", state.player_pos)).distance_to(circle_centre) <= circle_radius
		var fade := clampf(circle_left / 4.0, 0.35, 1.0)
		var ring := _world_ring(circle_centre, circle_radius, 40)
		draw_colored_polygon(ring, Color(0.18, 0.72, 0.62, (0.10 if standing else 0.05) * fade))
		draw_polyline(_closed_points(ring), Color(0.36, 0.88, 0.76, (0.95 if standing else 0.55) * fade), maxf(2.0, world_scale * (5.0 if standing else 3.0)))
		var inner_ring := _world_ring(circle_centre, circle_radius * 0.16, 20)
		draw_polyline(_closed_points(inner_ring), Color(0.42, 0.92, 0.80, 0.6 * fade), maxf(1.5, world_scale * 2.5))
		for spoke in range(6):
			var angle := TAU * float(spoke) / 6.0
			var a_in := _world_to_screen(circle_centre + Vector2.RIGHT.rotated(angle) * circle_radius * 0.82)
			var a_out := _world_to_screen(circle_centre + Vector2.RIGHT.rotated(angle) * circle_radius)
			draw_line(a_in, a_out, Color(0.36, 0.88, 0.76, 0.55 * fade), maxf(1.5, world_scale * 2.5))
	# The reach of an armed spell, drawn on the ground. A limit the player discovers by
	# casting into nothing is a limit they learn by being punished; a ring they can see is
	# one they can plan around, and it costs a circle.
	if selected_action == "advance" and state.loadout_id == "mage_elementalist" and state.selected_spell != "":
		var cast_reach := state.spell_reach(state.selected_spell)
		if cast_reach > 0.0:
			var reach_ring := _world_ring(Vector2(visual.get("player_pos", state.player_pos)), cast_reach, 44)
			draw_polyline(_closed_points(reach_ring), Color(0.36, 0.78, 0.92, 0.38), maxf(1.5, world_scale * 2.0))
	for segment in Array(visual.get("barriers", [])):
		if String(segment.get("layer", state.current_layer)) != state.current_layer: continue
		var centre := Vector2(segment["pos"])
		if not _world_point_on_camera(centre, float(segment.get("half_length", 30.0)) + 40.0): continue
		var axis := Vector2(segment.get("axis", Vector2.RIGHT)).normalized()
		var reach := float(segment.get("half_length", 28.0))
		var a := _world_to_screen(centre - axis * reach)
		var b := _world_to_screen(centre + axis * reach)
		var lowered := bool(segment.get("lowered", false))
		var integrity := clampf(float(segment.get("hp", 10.0)) / 10.0, 0.15, 1.0)
		# Since 0.2.72 a wall stops whichever side did not raise it, so the player walks
		# through their own. Drawn identically to an enemy's, that reads as clipping through
		# solid stone. Yours is drawn as a raised ward instead -- lit from within, its cap in
		# the Circle's own green -- so passing through it looks intended.
		var mine := int(segment.get("source_id", -1)) == 0
		var body_color := Color(0.30, 0.62, 0.52) if mine else Color(0.58, 0.44, 0.26)
		var cap_color := Color(0.52, 0.90, 0.76) if mine else Color(0.86, 0.72, 0.46)
		var base_color := Color(0.10, 0.20, 0.18, 0.80) if mine else Color(0.16, 0.12, 0.08, 0.85)
		# A lowered segment is drawn as a scar on the ground rather than removed: the gap
		# is information -- it is where an enemy is -- and hiding it would make the wall
		# read as randomly broken instead of as pressure you can see.
		var thickness := maxf(3.0, float(segment.get("thickness", 17.0)) * world_scale * (0.30 if lowered else 1.45))
		var rise := state.barrier_rise_fraction(segment)
		if lowered and rise > 0.02:
			# Mid-rise: drawn at its real height so far, and still passable. The player can
			# see it coming and decide, which is the whole point of it taking a beat.
			var partial := thickness * (0.30 + 0.70 * rise)
			var partial_lift := Vector2(0.0, -partial * 0.55 * rise)
			draw_line(a, b, base_color, partial * 1.1)
			draw_line(a + partial_lift, b + partial_lift, Color(body_color, 0.55 + 0.43 * rise), partial)
			draw_line(a + partial_lift * 1.7, b + partial_lift * 1.7, Color(cap_color, 0.5 + 0.45 * rise), maxf(2.0, partial * 0.34))
		elif lowered:
			# A ground scar, and drawn as rubble rather than as a thin version of the wall.
			# The gap is information -- it is where an enemy is -- and a faint copy of the
			# raised state reads as the wall being badly drawn instead of as a hole in it.
			draw_line(a, b, Color(0.34, 0.26, 0.17, 0.55), thickness)
			for notch in range(4):
				var t := (float(notch) + 0.5) / 4.0
				var p := a.lerp(b, t)
				draw_line(p + Vector2(-3.0, 0.0), p + Vector2(3.0, 0.0), Color(0.60, 0.47, 0.29, 0.5), maxf(1.0, thickness * 0.3))
		else:
			# Standing stone: a dark base, a lit body, and a bright cap along the top so it
			# reads as something with height rather than a line painted on the floor. It was
			# a single dark-brown line before, which against the floor was nearly nothing.
			var lift := Vector2(0.0, -thickness * 0.55)
			draw_line(a, b, base_color, thickness * 1.1)
			draw_line(a + lift, b + lift, Color(body_color, (0.72 if mine else 0.98) * integrity), thickness)
			draw_line(a + lift * 1.7, b + lift * 1.7, Color(cap_color, 0.95 * integrity), maxf(2.0, thickness * 0.34))
	if view_mode == "isometric":
		_draw_isometric_solids(visible, discovered)
	else:
		for enemy in Array(visual.get("enemies", [])):
			# `touch_revealed` draws a body the player has physically walked into even when
			# the fog says they cannot see it. Being stopped by nothing is worse than seeing
			# something you technically should not.
			if String(enemy.get("layer", state.current_layer)) == state.current_layer and _world_point_on_camera(Vector2(enemy["pos"]), float(enemy.get("radius", 30.0)) * 2.5) and (state.is_visible(Vector2(enemy["pos"]), visible) or bool(enemy.get("touch_revealed", false))): _draw_enemy(enemy)
		_draw_player()
	# Supplies deliberately render after solid world geometry in both views.
	# They are a readable interaction affordance, not scenery that foliage may hide.
	_draw_world_pickups(discovered)
	_draw_shortcut_gate_labels(discovered)
	for effect in Array(visual.get("effects", [])):
		if String(effect.get("layer", state.current_layer)) == state.current_layer and _world_point_on_camera(Vector2(effect["pos"]), 80.0) and state.is_visible(Vector2(effect["pos"]), visible): _draw_effect(effect)
	_draw_shadow_guidance()
	_draw_temporal_tint()
	_draw_isometric_focus_overlay(visible)
	_draw_player_damage_overlay()
	_draw_selected_action_hint()
	_draw_area_title()
	_draw_room_clear_banner()
	var label := "TIME FLOWING" if playing else "TIME FROZEN"
	if state.is_measurement_mode(): label += "  •  RUN %d" % state.run_seed
	var color := Color("f0b45a") if playing else DODGE_COLOR
	var font := maxi(14, int(minf(size.x, size.y) * 0.026))
	draw_string(ThemeDB.fallback_font, board_rect.position + Vector2(12, font + 10), label, HORIZONTAL_ALIGNMENT_LEFT, board_rect.size.x * 0.5, font, color)
	var current_xp := int(visual.get("carried_xp", state.carried_xp))
	var safe_xp := int(visual.get("secured_xp", state.secured_xp))
	var risk_xp := maxi(0, current_xp - safe_xp)
	var area_text := "%s  •  %d XP" % [state.current_area_name().to_upper(), current_xp]
	if state.mode_id == "combat_survey": area_text = "ROOM %d  •  SEED %d" % [state.survey_room_number, state.survey_room_seed]
	elif state.mode_id == "boss_lab": area_text = "%s  •  SEED %d" % [state.boss_lab_boss_kind.replace("_", " ").to_upper(), state.survey_room_seed]
	if state.mode_id == "campaign_lab":
		area_text = "%s  •  TIMELINE SECURE" % state.current_area_name().to_upper() if risk_xp == 0 else "%s  •  %d XP AT RISK" % [state.current_area_name().to_upper(), risk_xp]
	var area_width := minf(board_rect.size.x * 0.50, 360.0)
	var area_x := board_rect.position.x + (board_rect.size.x - area_width) * 0.5
	draw_string(ThemeDB.fallback_font, Vector2(area_x, board_rect.position.y + font + 10), area_text, HORIZONTAL_ALIGNMENT_CENTER, area_width, font, Color("9fb2b7"))
	_draw_player_health_bar(font)
	_draw_player_progress_bar(font)

func _draw_temporal_tint() -> void:
	if temporal_tint_strength <= 0.001: return
	draw_rect(board_rect, Color(0.06, 0.38, 0.66, TEMPORAL_TINT_ALPHA * temporal_tint_strength))

func _projectile_is_renderable(projectile: Dictionary, visible: Dictionary) -> bool:
	var position := Vector2(projectile.get("pos", Vector2.ZERO))
	return String(projectile.get("layer", state.current_layer)) == state.current_layer \
		and _world_point_on_camera(position, 45.0) \
		and state.is_visible(position, visible)

func _draw_projectile(projectile: Dictionary) -> void:
	var world_center := Vector2(projectile["pos"])
	var ground := _world_to_screen(world_center)
	var world_direction := Vector2(projectile.get("vel", Vector2.UP)).normalized()
	var direction := _screen_direction(world_direction)
	var kind := String(projectile.get("kind", "arrow"))
	var radius := maxf(4.0, float(projectile.get("radius", 8.0)) * world_scale)
	var default_elevation := 18.0 if kind == "firebolt" else 10.0
	var elevation := float(projectile.get("elevation", default_elevation)) * world_scale if view_mode == "isometric" else 0.0
	var center := ground + Vector2(0.0, -elevation)
	if view_mode == "isometric":
		var shadow_direction := _world_to_screen(world_center + world_direction * 14.0) - ground
		draw_line(ground - shadow_direction * 0.55, ground + shadow_direction * 0.55, Color(0.01, 0.02, 0.025, 0.58), maxf(2.0, radius * 0.62))
		draw_circle(ground, maxf(2.0, radius * 0.38), Color(0.01, 0.02, 0.025, 0.68))
		draw_line(ground, center, Color(0.62, 0.78, 0.83, 0.18), maxf(1.0, world_scale))
	if kind == "javelin":
		# Long and slow and obvious. The lane it occupies is the threat, so the shaft is
		# drawn at its real length rather than as a dart.
		var shaft := maxf(26.0, world_scale * 46.0)
		draw_line(center - direction * shaft * 0.62, center + direction * shaft * 0.38, Color("cbb27a"), maxf(3.0, world_scale * 7.0))
		var jav_tip := center + direction * shaft * 0.38
		var jav_side := direction.rotated(PI * 0.5)
		draw_colored_polygon(PackedVector2Array([jav_tip + direction * shaft * 0.16, jav_tip + jav_side * shaft * 0.10, jav_tip - jav_side * shaft * 0.10]), Color("f3e3b4"))
	elif kind == "frost_lance":
		# It fell through to the generic arrow and was drawn as a gold shaft with a fletched
		# tail -- the same silhouette and very nearly the same colour as an Archer's shot,
		# for a projectile whose whole identity is that it is the ONE ice attack you can
		# dodge. Ice pays for its own shape: a pale shard with a cold trail.
		var shard := maxf(18.0, world_scale * 30.0)
		var lance_side := direction.rotated(PI * 0.5)
		draw_line(center - direction * shard * 0.9, center, Color(0.55, 0.86, 1.0, 0.42), maxf(3.0, world_scale * 7.0))
		draw_colored_polygon(PackedVector2Array([
			center + direction * shard * 0.42,
			center + lance_side * shard * 0.16,
			center - direction * shard * 0.30,
			center - lance_side * shard * 0.16,
		]), Color("bdeaff"))
		draw_line(center - direction * shard * 0.30, center + direction * shard * 0.42, Color("f2fdff"), maxf(1.5, world_scale * 2.4))
	elif kind == "firebolt":
		draw_line(center - direction * 22.0 * world_scale, center, Color(0.94, 0.31, 0.10, 0.48), maxf(3.0, world_scale * 9.0))
		draw_circle(center, maxf(5.0, radius * 0.72), Color("f06b24"))
		draw_circle(center - direction * 2.0, maxf(2.0, world_scale * 4.0), Color("ffd36a"))
	else:
		draw_line(center - direction * 15.0, center + direction * 9.0, Color("f1ce72"), maxf(2.0, world_scale * 8.0))
		var tip := center + direction * 10.0
		var side := direction.rotated(PI * 0.5)
		draw_colored_polygon(PackedVector2Array([tip, center + direction * 4.0 + side * 3.5, center + direction * 4.0 - side * 3.5]), Color("fff1b8"))
	if bool(projectile["misdirected"]):
		# A turned shot can cross its original allegiance. The double broken ring is
		# intentionally unlike any element or faction colour: it means trajectory
		# ownership changed, regardless of who fired it.
		var cue_radius := maxf(8.0, radius * 1.75)
		draw_arc(center, cue_radius, -0.25 * PI, 0.65 * PI, 12, Color("f3ecff"), maxf(2.0, world_scale * 2.8))
		draw_arc(center, cue_radius, 0.75 * PI, 1.65 * PI, 12, Color("b57bea"), maxf(2.0, world_scale * 2.8))

# A chant is drawn on the enemy CARRYING it, not on the caster, because what the
# player needs to read is which bodies in front of them have changed.
#
# Colour and shape both carry the meaning, so the colour is never load-bearing:
#   haste   blue   ring      -- moves faster
#   bulwark yellow chevron   -- posture and telegraph armour
#   ward    red    diamond   -- incoming damage reduced
func _draw_chant_marks(pos: Vector2, radius: float, enemy: Dictionary) -> void:
	var chants: Dictionary = enemy.get("chants", {})
	if chants.is_empty(): return
	var slot := 0
	for chant in ["haste", "bulwark", "ward"]:
		var remaining := float(chants.get(chant, 0.0))
		if remaining <= 0.0: continue
		var mark := pos + Vector2(0.0, -radius * 1.62) + Vector2(float(slot) * radius * 0.52 - radius * 0.26, 0.0)
		var size := maxf(3.0, radius * 0.22)
		if chant == "haste":
			draw_arc(mark, size, 0.0, TAU, 14, Color("5fb8f0"), maxf(2.0, size * 0.42))
		elif chant == "bulwark":
			draw_polyline(PackedVector2Array([mark + Vector2(-size, size * 0.7), mark + Vector2(0.0, -size * 0.8), mark + Vector2(size, size * 0.7)]), Color("f2cf4a"), maxf(2.0, size * 0.42))
		else:
			draw_polyline(_closed_points(PackedVector2Array([mark + Vector2(0.0, -size), mark + Vector2(size, 0.0), mark + Vector2(0.0, size), mark + Vector2(-size, 0.0)])), Color("e06868"), maxf(2.0, size * 0.42))
		var duration_fraction := clampf(remaining / maxf(0.01, state.CHANT_DURATION), 0.0, 1.0)
		draw_arc(mark, size * 1.55, -PI * 0.5, -PI * 0.5 + TAU * duration_fraction, 14, Color(0.95, 0.95, 0.88, 0.82), maxf(1.0, size * 0.20))
		slot += 1

# Centred and brief. It reads as a beat in the fight rather than a screen, which is the
# point: the room is over, the swing that ended it is still landing behind this.
func _draw_room_clear_banner() -> void:
	if room_clear_remaining <= 0.0: return
	var fade := clampf(room_clear_remaining / ROOM_CLEAR_HOLD_SECONDS, 0.0, 1.0)
	var alpha := clampf(fade * 1.6, 0.0, 1.0)
	var font := maxi(22, int(minf(size.x, size.y) * 0.062))
	var centre := board_rect.get_center()
	var text := "ROOM CLEAR"
	var measured := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font)
	var plate := Rect2(centre - Vector2(measured.x * 0.5 + 26.0, float(font) * 0.86), Vector2(measured.x + 52.0, float(font) * 1.5))
	draw_rect(plate, Color(0.05, 0.09, 0.11, 0.72 * alpha))
	draw_rect(plate, Color(0.42, 0.89, 0.78, 0.85 * alpha), false, 2.0)
	draw_string(ThemeDB.fallback_font, centre + Vector2(-measured.x * 0.5, float(font) * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, measured.x, font, Color(0.85, 0.97, 0.93, alpha))

func _draw_isometric_focus_overlay(visible: Dictionary) -> void:
	if view_mode != "isometric": return
	var frozen_alpha := 0.10 + temporal_tint_strength * 0.12
	var player_world := Vector2(visual.get("player_pos", state.player_pos))
	var player_pos := _actor_visual_center(player_world, state.PLAYER_RADIUS)
	draw_arc(player_pos, _actor_body_radius(state.PLAYER_RADIUS) * 1.08, 0.0, TAU, 24, Color(0.78, 0.96, 1.0, frozen_alpha + 0.10), maxf(1.0, world_scale * 1.3))
	for enemy_value in Array(visual.get("enemies", [])):
		var enemy := Dictionary(enemy_value)
		var enemy_world := Vector2(enemy.get("pos", Vector2.ZERO))
		if String(enemy.get("layer", state.current_layer)) != state.current_layer or not state.is_visible(enemy_world, visible): continue
		var radius := float(enemy.get("radius", state.ENEMY_RADIUS))
		var body := _actor_visual_center(enemy_world, radius)
		draw_arc(body, _actor_body_radius(radius) * 1.08, 0.0, TAU, 24, Color(0.94, 0.92, 0.82, frozen_alpha), maxf(1.0, world_scale))

func _draw_area_title() -> void:
	if area_title_remaining <= 0.0 or area_title_name.is_empty(): return
	var elapsed := AREA_TITLE_DURATION - area_title_remaining
	var alpha := minf(clampf(elapsed / 0.24, 0.0, 1.0), clampf(area_title_remaining / 0.48, 0.0, 1.0))
	if alpha <= 0.001: return
	var panel_width := minf(board_rect.size.x * 0.72, 560.0)
	var panel_height := 76.0
	var panel := Rect2(
		board_rect.position + Vector2((board_rect.size.x - panel_width) * 0.5, board_rect.size.y * 0.18),
		Vector2(panel_width, panel_height)
	)
	draw_rect(panel, Color(0.025, 0.045, 0.045, 0.58 * alpha))
	draw_line(panel.position + Vector2(panel_width * 0.14, panel_height - 5.0), panel.position + Vector2(panel_width * 0.86, panel_height - 5.0), Color(0.45, 0.72, 0.58, 0.64 * alpha), 1.5)
	var title_font := maxi(20, int(minf(size.x, size.y) * 0.036))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(0.0, 32.0), area_title_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, panel_width, title_font, Color(0.88, 0.95, 0.86, alpha))
	if not area_title_subtitle.is_empty():
		var subtitle_font := maxi(12, int(minf(size.x, size.y) * 0.020))
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(0.0, 58.0), area_title_subtitle.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, panel_width, subtitle_font, Color(0.64, 0.77, 0.68, 0.92 * alpha))

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
	for projectile_value in Array(visual.get("projectiles", [])):
		var projectile := Dictionary(projectile_value)
		if not _projectile_is_renderable(projectile, visible): continue
		entries.append({"kind": "projectile", "projectile": projectile, "depth": _world_to_screen(Vector2(projectile["pos"])).y})
	for feature in _render_features():
		if String(feature.get("layer", state.current_layer)) != state.current_layer: continue
		var feature_pos := Vector2(feature["pos"])
		if not _world_point_on_camera(feature_pos, float(feature.get("radius", 45.0)) * 2.5): continue
		if not _terrain_feature_revealed(feature_pos, discovered): continue
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
			"feature":
				var feature := Dictionary(entry["feature"])
				_draw_terrain_feature(feature, _feature_occlusion_alpha(feature))
			"projectile": _draw_projectile(Dictionary(entry["projectile"]))
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
	for index in range(_occlusion_focus_bounds.size()):
		if bounds.intersects(_occlusion_focus_bounds[index], true): return 0.20 if index == 0 else 0.36
	return 1.0

func _prepare_occlusion_focus_bounds(visible: Dictionary) -> void:
	_occlusion_focus_bounds.clear()
	_occlusion_focus_bounds.append(_actor_screen_bounds(Vector2(visual.get("player_pos", state.player_pos)), state.PLAYER_RADIUS))
	var player_world := Vector2(visual.get("player_pos", state.player_pos))
	for enemy_value in Array(visual.get("enemies", [])):
		var enemy := Dictionary(enemy_value)
		var position := Vector2(enemy.get("pos", Vector2.ZERO))
		if String(enemy.get("layer", state.current_layer)) != state.current_layer or player_world.distance_to(position) > 760.0: continue
		if not state.is_visible(position, visible): continue
		_occlusion_focus_bounds.append(_actor_screen_bounds(position, float(enemy.get("radius", state.ENEMY_RADIUS))))
	for projectile_value in Array(visual.get("projectiles", [])):
		var projectile := Dictionary(projectile_value)
		if not _projectile_is_renderable(projectile, visible): continue
		var center := _world_to_screen(Vector2(projectile["pos"]))
		var radius := maxf(8.0, float(projectile.get("radius", 8.0)) * world_scale)
		_occlusion_focus_bounds.append(Rect2(center - Vector2.ONE * radius * 2.0, Vector2.ONE * radius * 4.0))

func _actor_screen_bounds(world_pos: Vector2, world_radius: float) -> Rect2:
	var foot := _world_to_screen(world_pos)
	var radius := maxf(8.0, world_radius * world_scale)
	return Rect2(foot + Vector2(-radius, -radius * 2.55), Vector2(radius * 2.0, radius * 2.85))

func _feature_occlusion_alpha(feature: Dictionary) -> float:
	if view_mode != "isometric" or String(feature.get("kind", "tree")) in ["brook", "old_road", "meadow", "flowers", "forest_pass", "stone_circle", "roots", "undergrowth", "ancient_ruin", "ruin_fragment"]: return 1.0
	var foot := _world_to_screen(Vector2(feature["pos"]))
	var radius := float(feature.get("radius", 44.0)) * world_scale
	var canopy_center := foot + Vector2(0.0, -radius * 1.33)
	var bounds := Rect2(canopy_center - Vector2.ONE * radius * 0.86, Vector2.ONE * radius * 1.72)
	bounds = bounds.expand(foot)
	for index in range(_occlusion_focus_bounds.size()):
		if bounds.intersects(_occlusion_focus_bounds[index], true): return 0.18 if index == 0 else 0.32
	return 1.0

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
	draw_set_transform(_projection_origin())
	for chunk_x in range(first_chunk.x, last_chunk.x + 1):
		for chunk_y in range(first_chunk.y, last_chunk.y + 1):
			for cell_value in Array(_floor_cells_by_chunk.get(Vector2i(chunk_x, chunk_y), [])):
				var cell := Vector2i(cell_value)
				if not bounds.has_point(cell): continue
				var surface_color: Color = _floor_surface_colors.get(cell, state.current_ground_color())
				var color := surface_color if visible.has(cell) else surface_color.darkened(0.72)
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
		_refresh_ground_surface_landmarks()
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
	_floor_surface_colors.clear()

func _cache_floor_cell(cell: Vector2i) -> void:
	if _floor_iso_geometry.has(cell): return
	var chunk := Vector2i(int(floor(float(cell.x) / FLOOR_RENDER_CHUNK_CELLS)), int(floor(float(cell.y) / FLOOR_RENDER_CHUNK_CELLS)))
	if not _floor_cells_by_chunk.has(chunk): _floor_cells_by_chunk[chunk] = []
	_floor_cells_by_chunk[chunk].append(cell)
	var top_left := Vector2(cell) * state.VISIBILITY_CELL
	var center := top_left + Vector2.ONE * state.VISIBILITY_CELL * 0.5
	_floor_surface_colors[cell] = _ground_surface_color_at(center, state.floor_surface_color_at(center))
	_floor_top_down_geometry[cell] = Rect2(top_left * world_scale, Vector2.ONE * state.VISIBILITY_CELL * world_scale + Vector2.ONE)
	_floor_iso_geometry[cell] = PackedVector2Array([
		_project_world_without_camera(top_left),
		_project_world_without_camera(top_left + Vector2(state.VISIBILITY_CELL, 0.0)),
		_project_world_without_camera(top_left + Vector2.ONE * state.VISIBILITY_CELL),
		_project_world_without_camera(top_left + Vector2(0.0, state.VISIBILITY_CELL)),
	])

func _refresh_ground_surface_landmarks() -> void:
	_ground_surface_landmarks.clear()
	for feature_value in state.terrain_features:
		var feature := Dictionary(feature_value)
		if String(feature.get("layer", state.current_layer)) != state.current_layer: continue
		if String(feature.get("kind", "")) in ["brook", "old_road"] and feature.has("from") and feature.has("to"):
			_ground_surface_landmarks.append(feature)

func _ground_surface_color_at(point: Vector2, base_color: Color) -> Color:
	var result := base_color
	for feature in _ground_surface_landmarks:
		var start := Vector2(feature["from"])
		var finish := Vector2(feature["to"])
		var closest := Geometry2D.get_closest_point_to_segment(point, start, finish)
		var distance := point.distance_to(closest)
		var width := float(feature.get("width", 24.0))
		var kind := String(feature["kind"])
		if kind == "brook":
			if distance > width * 0.5 + 38.0: continue
			var at_ford := false
			for ford_value in Array(feature.get("fords", [])):
				if point.distance_to(Vector2(ford_value)) <= maxf(118.0, width * 0.82):
					at_ford = true
					break
			if at_ford:
				result = Color("8fa27b") if distance <= width * 0.5 else Color("718565")
			elif distance <= width * 0.5:
				result = Color("347fa5")
			else:
				result = Color("607b61")
		elif kind == "old_road":
			if distance > width * 0.5 + 44.0: continue
			result = Color("67543b") if distance <= width * 0.5 else Color("806b49")
	return result

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
	draw_polyline(PackedVector2Array([base[0], base[1], base[2], base[3], base[0]]), Color(0.06, 0.10, 0.12, 0.90 * alpha), maxf(2.0, world_scale * 2.2))
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
	draw_polyline(PackedVector2Array([base[0], base[1], base[2], base[3], base[0]]), Color(0.10, 0.055, 0.025, 0.92 * alpha), maxf(2.0, world_scale * 2.2))
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

func _draw_terrain_feature(feature: Dictionary, alpha: float = 1.0) -> void:
	var world_pos := Vector2(feature["pos"])
	var foot := _world_to_screen(world_pos)
	var radius := float(feature.get("radius", 44.0)) * world_scale
	var kind := String(feature.get("kind", "tree"))
	if kind in ["brook", "old_road"]:
		# Long landmarks are baked into discovered floor cells so they remain
		# clipped to playable terrain and underneath every solid in either view.
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
	if kind == "forest_pass":
		# Two understated boundary stones make a discovered continuation legible
		# without advertising it across the rest of the locale or on the map.
		var world_direction := Vector2(feature.get("direction", Vector2.RIGHT)).normalized()
		var pass_forward := _screen_direction(world_direction)
		var pass_side := _screen_direction(world_direction.rotated(PI * 0.5))
		var stone_color := Color("697260")
		var stone_positions: Array[Vector2] = []
		for sign in [-1.0, 1.0]:
			var stone: Vector2 = foot + pass_side * sign * radius * 0.52
			stone_positions.append(stone)
			draw_circle(stone + Vector2(0.0, radius * 0.10), radius * 0.24, Color(0.02, 0.03, 0.02, 0.46))
			draw_rect(Rect2(stone - Vector2(radius * 0.12, radius * 0.30), Vector2(radius * 0.24, radius * 0.48)), stone_color)
			draw_arc(stone - Vector2(0.0, radius * 0.30), radius * 0.12, PI, TAU, 8, stone_color.lightened(0.16), maxf(1.0, radius * 0.05))
		var style := String(feature.get("style", "flowered_narrows"))
		if style == "flowered_narrows":
			for index in range(6):
				var flower_sign := -1.0 if index % 2 == 0 else 1.0
				var flower := foot + pass_side * flower_sign * radius * (0.68 + 0.05 * float(index % 3)) + pass_forward * radius * (float(index / 2) - 1.0) * 0.24
				draw_circle(flower, maxf(1.5, radius * 0.045), Color("ead782") if index % 3 else Color("d7b2d5"))
		elif style == "ford_stones":
			for index in range(5):
				var step_offset := (float(index) - 2.0) * radius * 0.25
				var step := foot + pass_forward * step_offset + pass_side * (radius * 0.08 if index % 2 == 0 else -radius * 0.08)
				draw_circle(step, radius * 0.12, Color("82938b"))
				draw_arc(step, radius * 0.12, 0.0, TAU, 10, Color("b5c0ae"), maxf(1.0, radius * 0.025))
		elif style == "broken_mileposts":
			draw_line(stone_positions[0] - Vector2(0.0, radius * 0.20), stone_positions[0] + pass_forward * radius * 0.30, Color("8b876f"), maxf(2.0, radius * 0.07))
			draw_circle(stone_positions[1] + pass_forward * radius * 0.20, radius * 0.11, Color("757668"))
		elif style == "elder_arch":
			var arch_left := stone_positions[0] - Vector2(0.0, radius * 0.30)
			var arch_right := stone_positions[1] - Vector2(0.0, radius * 0.30)
			draw_line(arch_left, foot - Vector2(0.0, radius * 0.58), Color("536044"), maxf(2.0, radius * 0.07))
			draw_line(foot - Vector2(0.0, radius * 0.58), arch_right, Color("536044"), maxf(2.0, radius * 0.07))
		elif style == "root_gap":
			for sign in [-1.0, 1.0]:
				var root_start: Vector2 = foot + pass_side * float(sign) * radius * 0.92
				draw_line(root_start, foot + pass_side * sign * radius * 0.28 + pass_forward * radius * 0.18, Color("4d4a31"), maxf(2.0, radius * 0.08))
				draw_line(root_start, foot + pass_side * sign * radius * 0.38 - pass_forward * radius * 0.22, Color("4d4a31"), maxf(2.0, radius * 0.06))
		elif style == "ruined_gate":
			for sign in [-1.0, 1.0]:
				var rubble_base: Vector2 = foot + pass_side * float(sign) * radius * 0.72
				for index in range(3):
					draw_circle(rubble_base + pass_forward * (float(index) - 1.0) * radius * 0.14, radius * (0.09 + 0.02 * float(index)), Color("77796d"))
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
	var trunk_color := Color(Color("394638") if not underground else Color("3e4138"), alpha)
	var canopy_color := Color(Color("294f31") if kind == "heart_tree" else Color("264b2d") if kind == "thicket" else Color("315e39") if not underground else Color("52614a"), alpha)
	if view_mode == "top_down":
		draw_circle(foot, radius * 0.88, Color(0.02, 0.04, 0.025, 0.62 * alpha))
		draw_circle(foot, radius * 0.72, canopy_color)
		draw_circle(foot, maxf(3.0, radius * 0.20), trunk_color)
		return
	var trunk_top := foot + Vector2(0.0, -radius * 1.25)
	draw_line(foot, trunk_top, trunk_color, maxf(3.0, radius * 0.24))
	draw_circle(trunk_top, radius * 0.82, Color(0.015, 0.03, 0.02, 0.72 * alpha))
	draw_circle(trunk_top + Vector2(0.0, -radius * 0.08), radius * 0.68, canopy_color)
	draw_arc(trunk_top, radius * 0.70, 0.0, TAU, 18, canopy_color.lightened(0.16), maxf(1.5, radius * 0.07))

func _terrain_feature_revealed(position: Vector2, discovered: Dictionary) -> bool:
	var center := Vector2i(int(floor(position.x / state.VISIBILITY_CELL)), int(floor(position.y / state.VISIBILITY_CELL)))
	for x in range(center.x - 2, center.x + 3):
		for y in range(center.y - 2, center.y + 3):
			if discovered.has(Vector2i(x, y)): return true
	return false

func _draw_player() -> void:
	var world_pos := Vector2(visual.get("player_pos", state.player_pos))
	var world_facing := Vector2(visual.get("player_facing", Vector2.UP)).normalized()
	var foot := _world_to_screen(world_pos)
	var action: Dictionary = visual.get("player_action", {})
	var pose_direction := Vector2(action.get("direction", world_facing)).normalized()
	var pose := IsometricPoseScript.sample(action, pose_direction, state.PLAYER_RADIUS) if view_mode == "isometric" else {"world_offset": Vector2.ZERO, "vertical_lift": 0.0, "body_scale": Vector2.ONE, "facing_twist": 0.0, "stride": 0.0}
	var pos := _actor_visual_center(world_pos, state.PLAYER_RADIUS) + _project_world_delta(Vector2(pose["world_offset"])) - Vector2(0.0, float(pose["vertical_lift"]) * world_scale)
	var facing := _screen_direction(world_facing).rotated(float(pose["facing_twist"]))
	var collision_radius := state.PLAYER_RADIUS * world_scale
	var radius := _actor_body_radius(state.PLAYER_RADIUS)
	_draw_actor_footprint(world_pos, state.PLAYER_RADIUS, Color("f5fbff"), true)
	if float(visual.get("strength_remaining", 0.0)) > 0.0:
		if view_mode == "isometric": _draw_projected_world_circle(world_pos, state.PLAYER_RADIUS * 1.65, Color(0.91, 0.32, 0.20, 0.16), Color("e85c3f"), maxf(2.0, collision_radius * 0.12))
		else:
			draw_circle(pos, collision_radius * 1.65, Color(0.91, 0.32, 0.20, 0.16))
			draw_arc(pos, collision_radius * 1.65, 0.0, TAU, 24, Color("e85c3f"), maxf(2.0, collision_radius * 0.12))
	if bool(visual.get("rally_active", state.rally_active)):
		if view_mode == "isometric": _draw_projected_world_circle(world_pos, state.PLAYER_RADIUS * 1.48, Color(0.92, 0.38, 0.20, 0.12), Color("e47754"), maxf(1.5, collision_radius * 0.08))
		else:
			draw_circle(pos, collision_radius * 1.48, Color(0.92, 0.38, 0.20, 0.12))
			draw_arc(pos, collision_radius * 1.48, 0.0, TAU, 24, Color("e47754"), maxf(1.5, collision_radius * 0.08))
	if float(visual.get("stealth_remaining", state.stealth_remaining)) > 0.0:
		draw_arc(pos, collision_radius * 1.34, 0.0, TAU, 24, Color("8cc6d7", 0.72), maxf(1.5, collision_radius * 0.07))
	if String(action.get("kind", "idle")) == "dodge":
		if view_mode == "isometric": _draw_projected_world_circle(world_pos - world_facing * state.PLAYER_RADIUS * 0.7, state.PLAYER_RADIUS * 1.25, Color(DODGE_COLOR, 0.16))
		else: draw_circle(pos - facing * collision_radius * 0.7, collision_radius * 1.25, Color(DODGE_COLOR, 0.16))
	_draw_actor(pos, foot, facing, radius, PLAYER_COLOR, Color("ffffff"), false, Vector2(pose["body_scale"]), float(pose["stride"]))
	if String(action.get("kind", "idle")) in ["attack", "sweep", "combo", "art_combo"]: _draw_weapon(world_pos, action, true, state.PLAYER_RADIUS)
	# Enemy casters got a wind-up pose in 0.2.66 and the player never had one, so casting
	# looked like standing still until the effect arrived -- which reads as the spell taking
	# forever to start rather than as a commitment being served. The player is the one actor
	# whose wind-up the player cannot infer from anything else on screen.
	elif String(action.get("kind", "idle")) in ["cast", "circle"]:
		var spell_colour := SPELL_COLORS.get(String(action.get("spell_id", "")), Color("6be3c6")) as Color
		_draw_spell_cast(pos, facing, collision_radius, action, spell_colour)
	elif String(action.get("kind", "idle")) == "twin_fang": _draw_twin_fang(world_pos, action)
	elif String(action.get("kind", "idle")) in ["bow_draw", "bow_release", "bow_art"]: _draw_bow(pos, facing, radius, action, world_pos)
	elif String(action.get("kind", "idle")) == "block": _draw_guard(pos, facing, radius, action)
	elif String(action.get("kind", "idle")) == "endure": _draw_endure(pos, radius, action)
	elif String(action.get("kind", "idle")) == "potion": draw_circle(pos + Vector2(radius * 0.7, -radius * 0.8), radius * 0.25, Color("e35f62"))
	elif String(action.get("kind", "idle")) == "advance":
		var drive := _screen_direction(Vector2(action.get("direction", world_facing))).normalized()
		draw_line(pos - drive * radius * 0.35, pos + drive * radius * 1.75, Color("aee7ff"), maxf(3.0, radius * 0.18))
		draw_circle(pos + drive * radius * 1.75, maxf(3.0, radius * 0.18), Color("e8c35d"))
	if String(action.get("kind", "idle")) in ["combo", "art_combo"]: _draw_combo_commitment(pos, radius, action)
	elif float(visual.get("weapon_sequence_cooldown", state.weapon_sequence_cooldown)) > 0.0001 and state.player_weapon_frame == "twin_knives":
		_draw_sequence_recovery(pos, radius, float(visual.get("weapon_sequence_cooldown", state.weapon_sequence_cooldown)))
	var phase := _phase(action)
	# radius x 4.4 clipped "FOLLOWING THROUGH" to "FOLLOWING THR". 0.2.66 widened the enemy
	# readout for exactly this and never checked the player's, which is its own draw site --
	# the same defect surviving on the side the player looks at most.
	if phase != "": draw_string(ThemeDB.fallback_font, pos + Vector2(-radius * 3.4, -radius * 2.05), phase, HORIZONTAL_ALIGNMENT_CENTER, radius * 6.8, maxi(9, int(radius * 0.55)), Color("d8f4f1"))
	_draw_warrior_status(pos, radius, action)
	var exhaustion := float(visual.get("player_exhaustion_remaining", state.player_exhaustion_remaining))
	if exhaustion > 0.0001:
		var lock_ratio := clampf(exhaustion / state.EXHAUSTION_DURATION, 0.0, 1.0)
		draw_arc(pos, radius * 1.65, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - lock_ratio), 28, Color("83d89a"), maxf(3.0, radius * 0.13))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-radius * 2.5, -radius * 2.75), "EXHAUSTED", HORIZONTAL_ALIGNMENT_CENTER, radius * 5.0, maxi(10, int(radius * 0.62)), Color("a7ebb6"))

func _draw_warrior_status(pos: Vector2, radius: float, action: Dictionary) -> void:
	if state.has_track_rank("vanguard", 1):
		var pip_count := 4 if state.has_track_rank("vanguard", 4) else 3
		var active_pips := int(visual.get("battle_flow_pips", state.battle_flow_pips))
		var spacing := maxf(11.0, radius * 0.64)
		var origin := pos + Vector2(-spacing * float(pip_count - 1) * 0.5, radius * 1.82)
		var pip_radius := maxf(4.2, radius * 0.18)
		for index in range(pip_count):
			var pip_pos := origin + Vector2(spacing * index, 0.0)
			draw_circle(pip_pos, pip_radius, Color("f2ca62") if index < active_pips else Color("28353b"))
			draw_arc(pip_pos, pip_radius, 0.0, TAU, 16, Color("fff0b0") if index < active_pips else Color("718087"), maxf(1.2, radius * 0.045))
		if active_pips > 0:
			var remaining := float(visual.get("battle_flow_remaining", state.battle_flow_remaining))
			var timer_width := spacing * float(pip_count - 1) + pip_radius * 2.0
			var timer := Rect2(Vector2(pos.x - timer_width * 0.5, origin.y + pip_radius + maxf(3.0, radius * 0.10)), Vector2(timer_width, maxf(3.0, radius * 0.11)))
			draw_rect(timer, Color("27343a"))
			draw_rect(Rect2(timer.position, Vector2(timer.size.x * clampf(remaining / state.BATTLE_FLOW_DECAY_SECONDS, 0.0, 1.0), timer.size.y)), Color("d7aa58"))
			draw_rect(timer, Color("ecd995"), false, 1.0)
	var guard_capacity := float(action.get("guard_capacity", 0.0))
	if guard_capacity <= 0.0: return
	var guard_remaining := clampf(float(action.get("guard_remaining", guard_capacity)), 0.0, guard_capacity)
	var width := maxf(48.0, radius * 2.8)
	var bar := Rect2(Vector2(pos.x - width * 0.5, pos.y + radius * 2.34), Vector2(width, maxf(4.0, radius * 0.16)))
	draw_rect(bar, Color("202b31"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * guard_remaining / guard_capacity, bar.size.y)), Color("8eb4c5"))
	draw_rect(bar, Color("d4e3e8"), false, 1.0)
	draw_string(ThemeDB.fallback_font, bar.position + Vector2(-width * 0.25, bar.size.y + maxi(8, int(radius * 0.43))), "POISE %.0f / %.0f" % [guard_remaining, guard_capacity], HORIZONTAL_ALIGNMENT_CENTER, width * 1.5, maxi(8, int(radius * 0.43)), Color("cfe0e7"))

func _draw_combo_commitment(pos: Vector2, radius: float, action: Dictionary) -> void:
	var active_index := int(action.get("phase_index", 0))
	var committed_index := int(action.get("committed_phase", 0))
	var holding := bool(action.get("continue_held", false))
	var spacing := maxf(8.0, radius * 0.48)
	var origin := pos + Vector2(-spacing, -radius * 2.85)
	var count := int(action.get("combo_length", Array(action.get("phases", [])).size()))
	if count <= 0: count = 3
	var total_width := spacing * float(count - 1)
	origin.x = pos.x - total_width * 0.5
	for index in range(count):
		var color := Color("465359")
		if index <= active_index: color = Color("f1e8d0")
		elif index <= committed_index or holding: color = Color("d7aa58")
		draw_circle(origin + Vector2(index * spacing, 0.0), maxf(2.8, radius * 0.12), color)

func _draw_sequence_recovery(pos: Vector2, radius: float, remaining: float) -> void:
	var count := 6
	var spacing := maxf(8.0, radius * 0.48)
	var total_width := spacing * float(count - 1)
	var origin := pos + Vector2(-total_width * 0.5, -radius * 2.85)
	var maximum := 0.55 if state.has_track_rank("knife", 5) else state.TWIN_KNIFE_SEQUENCE_RECOVERY
	var ready_ratio := 1.0 - clampf(remaining / maximum, 0.0, 1.0)
	var ready_count := floori(ready_ratio * float(count) + 0.001)
	for index in range(count):
		var color := Color("d7aa58") if index < ready_count else Color("465359")
		draw_circle(origin + Vector2(index * spacing, 0.0), maxf(2.8, radius * 0.12), color)

func _draw_twin_fang(world_pos: Vector2, action: Dictionary) -> void:
	for technique_id in ["knife_cut_in", "knife_cut_out"]:
		var blade_action := action.duplicate()
		blade_action["technique_id"] = technique_id
		blade_action["reach"] = float(action.get("reach", 104.0))
		_draw_weapon(world_pos, blade_action, true, state.PLAYER_RADIUS)

func _draw_enemy(enemy: Dictionary) -> void:
	var world_pos := Vector2(enemy["pos"])
	var world_radius := float(enemy["radius"])
	var action: Dictionary = enemy["action"]
	var reeling := String(action.get("kind", "idle")) in ["hit_reaction", "stagger"]
	var reaction_offset := _reaction_visual_offset(action, world_radius)
	var foot := _world_to_screen(world_pos)
	var world_facing := Vector2(enemy["facing"]).normalized()
	if reeling:
		var reaction_direction := Vector2(action.get("reaction_direction", Vector2.ZERO)).normalized()
		if reaction_direction.length_squared() > 0.001: world_facing = reaction_direction
	var pose_direction := Vector2(action.get("direction", world_facing)).normalized()
	var pose := IsometricPoseScript.sample(action, pose_direction, world_radius) if view_mode == "isometric" else {"world_offset": Vector2.ZERO, "vertical_lift": 0.0, "body_scale": Vector2.ONE, "facing_twist": 0.0, "stride": 0.0}
	var visual_world_pos := world_pos + reaction_offset
	var pos := _actor_visual_center(world_pos, world_radius) + _project_world_delta(Vector2(pose["world_offset"]) + reaction_offset) - Vector2(0.0, float(pose["vertical_lift"]) * world_scale)
	var facing := _screen_direction(world_facing).rotated(float(pose["facing_twist"]))
	var collision_radius := world_radius * world_scale
	var radius := _actor_body_radius(world_radius)
	var kind := String(enemy["kind"])
	var presentation := CombatCatalogScript.presentation(kind)
	var color := Color(String(presentation["color"]))
	if reeling: color = color.lerp(Color("d9e2e4"), 0.20)
	_draw_actor_footprint(world_pos, world_radius, color.lightened(0.28), false)
	if reeling: _draw_reaction_motion(pos, facing, radius, action, color)
	_draw_chant_marks(pos, radius, enemy)
	# A Bandit that still has its slip is dangerous to swing at; one that has spent it
	# is free. That distinction is the whole loop, so it cannot live only in the
	# simulation -- an enemy which reads your commitment without a tell is unfair
	# rather than difficult. Two ticks on the guard side, present only while ready.
	# A Duellist still holding its parry takes your turn if you swing at it; one that
	# has spent it is free to attack. That is the entire loop, and in 0.2.33 it was
	# invisible -- the Bandit got a ready-tell and this did not, so the cooldown that
	# was already there read as "it parries whenever it likes". A raised guard in front,
	# distinct from the Bandit's two side ticks.
	if kind == "duellist" and float(enemy.get("parry_cooldown", 0.0)) <= 0.0 and String(action["kind"]) not in ["hit_reaction", "stagger"]:
		var guard_side := facing.rotated(PI * 0.5)
		var guard := pos + facing * radius * 0.92
		draw_polyline(PackedVector2Array([
			guard - guard_side * radius * 0.42 - facing * radius * 0.18,
			guard,
			guard + guard_side * radius * 0.42 - facing * radius * 0.18,
		]), Color("bfe8ff"), maxf(2.0, radius * 0.10))
	if kind == "bandit" and float(enemy.get("dodge_cooldown", 0.0)) <= 0.0 and String(action["kind"]) not in ["hit_reaction", "stagger"]:
		var ready_angle := facing.angle()
		for offset in [-0.62, 0.62]:
			draw_arc(pos, radius * 1.34, ready_angle + offset - 0.16, ready_angle + offset + 0.16, 6, Color("e8e0a8"), maxf(2.0, radius * 0.10))
	_draw_actor(pos, foot, facing, radius, color, color.lightened(0.46), reeling, Vector2(pose["body_scale"]), float(pose["stride"]))
	_draw_enemy_conditions(pos, radius, enemy)
	_draw_enemy_identity(kind, pos, facing, radius, color)
	if int(enemy.get("id", -1)) == int(visual.get("aimed_enemy_id", -1)):
		draw_arc(pos, radius * 1.62, 0.0, TAU, 26, Color("f2d16b"), maxf(2.0, radius * 0.12))
	# The guard cannot be drawn while the sword is out. run_state's _enemy_blocks_attack
	# already drops the block for exactly these action kinds, so painting the arc
	# through an attack made the sprite contradict the rule -- the 0.2.30 survey read
	# the Shield as "too aggressive" partly because its opening was invisible.
	# Read from the simulation rather than copied. This list drifted once already: the
	# sim added hit_reaction and stagger in 0.2.38 and the renderer kept four states, so
	# a staggered Shield drew its guard back up while still resolving as open.
	if kind == "shield" and String(action["kind"]) not in state.SHIELD_OPEN_ACTION_KINDS:
		_draw_guard(pos, facing, radius, {"elapsed": 0.5, "startup": 0.0, "active_end": 1.0})
	if String(action["kind"]) in ["melee", "dodge_strike"]: _draw_weapon(world_pos, action, false, world_radius)
	elif String(action["kind"]) in ["hit_reaction", "stagger"]: _draw_interrupted_weapon(world_pos, action, false)
	elif String(action["kind"]) in ["claw_combo", "pounce_combo"]: _draw_claw_combo(world_pos, action, color)
	elif String(action["kind"]) == "shoot":
		# 0.2.56 renamed the Fire Caster's shot from "firebolt" to "fireball" and this test
		# kept naming the old label, so the caster fell through to _draw_bow and spent the
		# whole wind-up visibly drawing a bow it does not carry. Same root cause as the cone
		# drawn as a circle: the renderer keying on a name the simulation had moved on from.
		if String(action.get("label", "")) in ["firebolt", "fireball"]: _draw_spell_cast(pos, facing, radius, action, Color(String(AbilityCatalogScript.enemy_ability("fireball")["color"])))
		else: _draw_bow(pos, facing, radius, action, world_pos)
	elif String(action["kind"]) == "hurl":
		_draw_javelin_telegraph(action)
	elif String(action["kind"]) in ["charge", "pounce_combo"]: draw_line(pos, pos - facing * radius * 2.2, Color(color, 0.5), maxf(3.0, radius * 0.25))
	elif String(action["kind"]) == "evade": draw_line(pos, pos - _screen_direction(Vector2(action.get("direction", Vector2.ZERO))) * radius * 1.8, Color(color, 0.42), maxf(3.0, radius * 0.22))
	elif String(action["kind"]) == "slam":
		if view_mode == "isometric": _draw_projected_world_circle(world_pos, float(action.get("reach", 205.0)), Color.TRANSPARENT, Color(color, 0.45), maxf(3.0, collision_radius * 0.13))
		else: draw_arc(pos, float(action.get("reach", 205.0)) * world_scale, 0.0, TAU, 28, Color(color, 0.45), maxf(3.0, collision_radius * 0.13))
	elif String(action["kind"]) == "gale":
		var gale_color := Color(String(AbilityCatalogScript.enemy_ability("gale")["color"]))
		_draw_spell_cast(pos, facing, radius, action, gale_color)
		draw_circle(_world_to_screen(Vector2(action.get("target", enemy["pos"]))), 18.0, gale_color)
	# Earth, the lance, the breath and the chant all wound up with nothing drawn at all, so
	# four of the roster's abilities gave the player no tell to read -- in a game whose
	# entire defensive layer is reading a wind-up and choosing an answer. Each takes the
	# colour of the thing it is about to become.
	elif String(action["kind"]) in ["earth_wall", "sunder"]:
		_draw_spell_cast(pos, facing, radius, action, Color(String(AbilityCatalogScript.enemy_ability(String(action["kind"]))["color"])))
		if action.has("target"): draw_circle(_world_to_screen(Vector2(action["target"])), 14.0, Color(0.53, 0.67, 0.49, 0.75))
	elif String(action["kind"]) == "frost_lance": _draw_spell_cast(pos, facing, radius, action, Color(String(AbilityCatalogScript.enemy_ability("frost_lance")["color"])))
	elif String(action["kind"]) == "fire_breath": _draw_spell_cast(pos, facing, radius, action, Color(String(AbilityCatalogScript.enemy_ability("fire_breath")["color"])))
	elif String(action["kind"]) == "chant": _draw_spell_cast(pos, facing, radius, action, Color("e0c46a"))
	elif String(action["kind"]) == "cold_front": draw_circle(_world_to_screen(Vector2(action.get("target", enemy["pos"]))), 20.0, Color("8edcff"))
	var awareness := String(enemy.get("awareness", "idle"))
	if awareness in ["suspicious", "alerted"]:
		var marker := "?" if awareness == "suspicious" else "!"
		var marker_color := Color("e8c35d") if awareness == "suspicious" else Color("ef665c")
		draw_string(ThemeDB.fallback_font, pos + Vector2(-radius, -radius * 2.5), marker, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, maxi(16, int(radius * 0.8)), marker_color)
	_draw_windup(pos, radius, enemy, action)
	_draw_health(pos, radius, int(enemy["hp"]), int(enemy["max_hp"]), color)
	_draw_posture(pos, radius, float(enemy.get("posture", 1.0)), float(enemy.get("posture_max", 1.0)))
	var phase := _phase(action)
	# Width was radius x 4.4, which clipped "DRAWING BREATH" to "DRAWING BREAT". A telegraph
	# that cannot finish its own word is not a telegraph.
	if phase != "": draw_string(ThemeDB.fallback_font, pos + Vector2(-radius * 3.4, radius * 2.1), phase, HORIZONTAL_ALIGNMENT_CENTER, radius * 6.8, maxi(9, int(radius * 0.55)), Color("d8ddd8"))

# The hurl promises both a lane and a landing point at commitment. Its projectile will
# follow this exact line; neither marker chases the player during the wind-up.
func _draw_javelin_telegraph(action: Dictionary) -> void:
	if not action.has("launch") or not action.has("target"): return
	var startup := maxf(0.001, float(action.get("startup", 0.86)))
	if float(action.get("elapsed", 0.0)) >= startup: return
	var launch := Vector2(action["launch"])
	var target := Vector2(action["target"])
	var radius := float(action.get("projectile_radius", 22.0))
	var commitment := clampf(float(action.get("elapsed", 0.0)) / startup, 0.0, 1.0)
	var color := Color(String(AbilityCatalogScript.enemy_ability("hurl")["color"]))
	var lane := _project_world_capsule(launch, target, radius)
	draw_colored_polygon(lane, Color(color, lerpf(0.07, 0.16, commitment)))
	draw_polyline(_closed_points(lane), Color(color, lerpf(0.30, 0.72, commitment)), maxf(1.5, world_scale * 2.4))
	_draw_projected_world_circle(target, radius, Color(color, lerpf(0.08, 0.20, commitment)), Color(color, lerpf(0.48, 0.92, commitment)), maxf(2.0, world_scale * 3.0))

func _draw_enemy_conditions(pos: Vector2, radius: float, enemy: Dictionary) -> void:
	var conditions := Dictionary(enemy.get("conditions", {}))
	if float(conditions.get("burning", 0.0)) > 0.0:
		# Fire licks upward in three uneven arcs: active harm and a hot silhouette.
		for offset in [-0.55, 0.0, 0.55]:
			var flame_center := pos + Vector2(float(offset) * radius, -radius * (0.72 + 0.14 * absf(float(offset))))
			draw_arc(flame_center, radius * 0.38, PI * 1.05, PI * 1.95, 7, Color("ff7b35"), maxf(2.0, radius * 0.11))
	if float(conditions.get("frost", 0.0)) > 0.0:
		# Frost is a rigid crystalline cage around the lower body, visually opposite
		# to the rising, irregular burn marks.
		var frost_color := Color("9be7ff")
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var direction := Vector2.RIGHT.rotated(float(angle))
			var start := pos + direction * radius * 0.90
			var finish := pos + direction * radius * 1.34
			draw_line(start, finish, frost_color, maxf(2.0, radius * 0.10))
			draw_line(finish, finish + direction.rotated(0.62) * radius * 0.22, frost_color, maxf(1.0, radius * 0.07))
			draw_line(finish, finish + direction.rotated(-0.62) * radius * 0.22, frost_color, maxf(1.0, radius * 0.07))

func _draw_actor(pos: Vector2, foot: Vector2, facing: Vector2, radius: float, color: Color, marker_color: Color, reeling: bool = false, body_scale: Vector2 = Vector2.ONE, stride: float = 0.0) -> void:
	if view_mode == "isometric":
		draw_line(foot, pos + Vector2(0.0, radius * 0.45), Color(0.02, 0.03, 0.04, 0.66), maxf(1.5, radius * 0.16))
		var foot_side := facing.rotated(PI * 0.5)
		var stride_screen := clampf(stride * world_scale, -radius * 0.52, radius * 0.52)
		var left_foot := foot - foot_side * radius * 0.34 + facing * stride_screen
		var right_foot := foot + foot_side * radius * 0.34 - facing * stride_screen
		draw_circle(left_foot, maxf(2.2, radius * 0.18), Color(0.02, 0.03, 0.035, 0.88))
		draw_circle(right_foot, maxf(2.2, radius * 0.18), Color(0.02, 0.03, 0.035, 0.88))
		var outer := _ellipse_points(pos, Vector2(radius * body_scale.x, radius * body_scale.y), 24)
		var inner := _ellipse_points(pos, Vector2(radius * 0.84 * body_scale.x, radius * 0.84 * body_scale.y), 24)
		draw_colored_polygon(outer, Color(0.015, 0.025, 0.035, 0.94))
		draw_colored_polygon(inner, color)
		draw_polyline(_closed_points(outer), color.lightened(0.28), maxf(1.5, radius * 0.11))
	else:
		draw_circle(pos, radius, Color(0.015, 0.025, 0.035, 0.94))
		draw_circle(pos, radius * 0.84, color)
		draw_arc(pos, radius, 0.0, TAU, 24, color.lightened(0.28), maxf(1.5, radius * 0.11))
	if reeling:
		var side := facing.rotated(PI * 0.5)
		draw_line(pos - facing * radius * 0.48 - side * radius * 0.18, pos + facing * radius * 0.35 + side * radius * 0.12, Color("f3e6ca"), maxf(1.5, radius * 0.13))
	var marker := _actor_marker_points(pos, facing.rotated(0.28 if reeling else 0.0), radius * (0.78 if reeling else 1.0))
	draw_colored_polygon(marker, marker_color)
	draw_polyline(PackedVector2Array([marker[0], marker[1], marker[2], marker[0]]), Color(0.015, 0.025, 0.035, 0.94), maxf(1.0, radius * 0.09))

func _ellipse_points(center: Vector2, radii: Vector2, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points

func _reaction_visual_offset(action: Dictionary, world_radius: float) -> Vector2:
	var kind := String(action.get("kind", "idle"))
	if kind not in ["hit_reaction", "stagger"]: return Vector2.ZERO
	var direction := Vector2(action.get("reaction_direction", Vector2.ZERO)).normalized()
	if direction.length_squared() < 0.001: return Vector2.ZERO
	var duration := maxf(0.01, float(action.get("duration", 0.4)))
	var progress := clampf(float(action.get("elapsed", 0.0)) / duration, 0.0, 1.0)
	var strength := float(action.get("reaction_strength", 1.0))
	var launch := clampf(progress / 0.16, 0.0, 1.0)
	var settle := clampf((progress - 0.16) / 0.84, 0.0, 1.0)
	var amount := world_radius * (0.22 * launch - 0.10 * settle) * strength
	return direction * maxf(0.0, amount)

func _draw_reaction_motion(pos: Vector2, facing: Vector2, radius: float, action: Dictionary, color: Color) -> void:
	var strength := float(action.get("reaction_strength", 1.0))
	var trail := maxf(radius * 1.15, radius * strength * 1.35)
	var side := facing.rotated(PI * 0.5)
	var trail_color := Color(color, 0.32)
	draw_line(pos - facing * trail, pos - facing * radius * 0.35, trail_color, maxf(2.0, radius * 0.15))
	draw_line(pos - facing * trail * 0.72 + side * radius * 0.20, pos - facing * radius * 0.42 + side * radius * 0.08, Color(trail_color, 0.62), maxf(1.5, radius * 0.09))
	if String(action.get("reaction_source_kind", "")) == "charge":
		draw_line(pos - facing * trail * 1.18 - side * radius * 0.18, pos - facing * radius * 0.46 - side * radius * 0.06, Color("d7c59c", 0.45), maxf(1.5, radius * 0.10))

func _draw_enemy_identity(kind: String, pos: Vector2, facing: Vector2, radius: float, color: Color) -> void:
	var side := facing.rotated(PI * 0.5)
	if kind == "boar":
		draw_line(pos - side * radius * 0.70 + facing * radius * 0.55, pos - side * radius * 0.95 + facing * radius * 1.05, Color("f0dfb0"), maxf(2.0, radius * 0.10))
		draw_line(pos + side * radius * 0.70 + facing * radius * 0.55, pos + side * radius * 0.95 + facing * radius * 1.05, Color("f0dfb0"), maxf(2.0, radius * 0.10))
	elif kind in ["knife", "bandit"]:
		draw_line(pos + side * radius * 0.45, pos + side * radius * 0.75 + facing * radius * 1.05, Color("f3e5aa"), 2.0)
		if kind == "knife": draw_line(pos - side * radius * 0.45, pos - side * radius * 0.75 + facing * radius * 1.05, Color("f3e5aa"), 2.0)
	elif kind == "hound":
		draw_line(pos - facing * radius * 0.9, pos + facing * radius * 0.75, color.lightened(0.35), maxf(3.0, radius * 0.35))
	elif kind == "polearm":
		draw_line(pos - facing * radius * 0.8, pos + facing * radius * 1.9, Color("e7c590"), maxf(2.0, radius * 0.10))
	elif kind == "brute":
		draw_arc(pos, radius * 1.15, 0.0, TAU, 18, color.lightened(0.28), maxf(3.0, radius * 0.16))
	elif kind == "knight":
		draw_line(pos - facing * radius * 0.85 - side * radius * 0.45, pos + facing * radius * 1.55 + side * radius * 0.45, Color("d6d3c7"), maxf(4.0, radius * 0.16))
		draw_line(pos + facing * radius * 1.30 + side * radius * 0.18, pos + facing * radius * 1.58 + side * radius * 0.48, Color("d6d3c7"), maxf(3.0, radius * 0.11))
	elif kind in ["ice_caster", "fire_caster"]:
		var spell_color := Color("9be7ff") if kind == "ice_caster" else Color("ff9b4f")
		draw_line(pos + side * radius * 0.65, pos + side * radius * 0.65 + facing * radius * 1.45, spell_color.darkened(0.22), maxf(2.0, radius * 0.12))
		draw_circle(pos + side * radius * 0.65 + facing * radius * 1.45, radius * 0.22, spell_color)
	elif kind == "chanter":
		# An open book, held. Nothing about the Chanter is a weapon.
		var spine := pos + facing * radius * 0.55
		draw_polyline(PackedVector2Array([spine - side * radius * 0.62 - facing * radius * 0.10, spine - side * radius * 0.10 + facing * radius * 0.12, spine + side * radius * 0.42 - facing * radius * 0.10]), Color("efe0ff"), maxf(2.0, radius * 0.10))
		draw_line(spine - side * radius * 0.10 + facing * radius * 0.12, spine - side * radius * 0.10 - facing * radius * 0.30, Color("efe0ff"), maxf(1.5, radius * 0.07))
	elif kind == "javelineer":
		# Held overhand, angled back to throw.
		var shaft := pos + facing * radius * 0.35
		draw_line(shaft - side * radius * 0.75 - facing * radius * 0.55, shaft + side * radius * 0.55 + facing * radius * 0.70, Color("f0dfae"), maxf(2.0, radius * 0.11))
	elif kind == "earth_caster":
		# Staff first, ground second. The broken-line glyph alone did not say "caster" at
		# a glance, so it read as another melee body -- it needs to share the silhouette
		# its role-mates have before it says anything of its own.
		var earth_color := Color("bfe0a8")
		draw_line(pos + side * radius * 0.65, pos + side * radius * 0.65 + facing * radius * 1.45, earth_color.darkened(0.28), maxf(2.0, radius * 0.12))
		draw_colored_polygon(PackedVector2Array([
			pos + side * radius * 0.65 + facing * radius * 1.45 + Vector2(0.0, -radius * 0.26),
			pos + side * radius * 0.65 + facing * radius * 1.45 + Vector2(radius * 0.24, radius * 0.10),
			pos + side * radius * 0.65 + facing * radius * 1.45 + Vector2(-radius * 0.24, radius * 0.10),
		]), earth_color)
		var base := pos + facing * radius * 0.78
		draw_polyline(PackedVector2Array([base - side * radius * 0.70, base - side * radius * 0.20 - facing * radius * 0.22, base + side * radius * 0.16 + facing * radius * 0.08, base + side * radius * 0.66 - facing * radius * 0.18]), earth_color.darkened(0.15), maxf(1.5, radius * 0.09))
	elif kind == "duellist":
		# Narrow blade, presented forward.
		draw_line(pos + facing * radius * 0.30, pos + facing * radius * 1.30, Color("ffe9a8"), maxf(2.0, radius * 0.08))
		draw_line(pos + facing * radius * 0.30 - side * radius * 0.26, pos + facing * radius * 0.30 + side * radius * 0.26, Color("ffe9a8"), maxf(1.5, radius * 0.07))
	elif kind == "warden":
		draw_polyline(PackedVector2Array([pos - side * radius * 0.55 - facing * radius * 0.45, pos - side * radius * 0.25 - facing * radius * 0.85, pos - facing * radius * 0.5, pos + side * radius * 0.25 - facing * radius * 0.85, pos + side * radius * 0.55 - facing * radius * 0.45]), Color("f1c25e"), maxf(2.0, radius * 0.09))
	elif kind == "werewolf":
		draw_colored_polygon(PackedVector2Array([pos - side * radius * 0.62 - facing * radius * 0.35, pos - side * radius * 0.28 - facing * radius * 1.12, pos - facing * radius * 0.55]), color.lightened(0.25))
		draw_colored_polygon(PackedVector2Array([pos + side * radius * 0.62 - facing * radius * 0.35, pos + side * radius * 0.28 - facing * radius * 1.12, pos - facing * radius * 0.55]), color.lightened(0.25))
		for claw_side in [-1.0, 1.0]: draw_line(pos + side * radius * claw_side * 0.68, pos + side * radius * claw_side * 0.92 + facing * radius * 1.18, Color("ead9c8"), maxf(2.0, radius * 0.08))

func _draw_spell_cast(pos: Vector2, facing: Vector2, radius: float, action: Dictionary, color: Color) -> void:
	var progress := clampf(float(action.get("elapsed", 0.0)) / maxf(0.01, float(action.get("startup", 0.64))), 0.0, 1.0)
	var focus := pos + facing * radius * (1.1 + progress * 0.45)
	draw_line(pos, focus, Color(color, 0.42), maxf(2.0, radius * 0.12))
	draw_circle(focus, radius * (0.18 + progress * 0.26), Color(color, 0.32 + progress * 0.42))
	draw_arc(focus, radius * (0.36 + progress * 0.30), 0.0, TAU, 18, color, maxf(2.0, radius * 0.10))

func _draw_weapon(world_pos: Vector2, action: Dictionary, player_weapon: bool, actor_world_radius: float) -> void:
	var facing := Vector2(action.get("direction", Vector2.UP)).normalized()
	var sample: Dictionary = AttackGeometryScript.pose(action, world_pos, facing, state.walls)
	var technique := String(sample.get("technique_id", "diagonal_cut"))
	var active := bool(sample.get("active", false))
	if String(sample.get("shape", "")) == "sector":
		_draw_attack_sector(sample, action, player_weapon)
	if view_mode == "isometric":
		if String(sample.get("shape", "")) == "segment":
			var ground_body := _project_world_capsule(Vector2(sample["start"]), Vector2(sample["end"]), float(sample.get("radius", 5.0)))
			var shadow_alpha := 0.16 if active else 0.075
			var shadow_color := Color(0.98, 0.78, 0.34, shadow_alpha) if player_weapon and active else Color(0.015, 0.025, 0.03, shadow_alpha + 0.10)
			draw_colored_polygon(ground_body, shadow_color)
			if debug_hitboxes: draw_polyline(_closed_points(ground_body), Color("ff4fd8"), maxf(1.5, world_scale * 1.5))
		elif String(sample.get("shape", "")) == "circle":
			var ground_circle := _project_world_circle(Vector2(sample.get("center", sample["weapon_end"])), float(sample.get("head_radius", sample.get("radius", 16.0))))
			draw_colored_polygon(ground_circle, Color(0.015, 0.025, 0.03, 0.22 if active else 0.11))
			if debug_hitboxes: draw_polyline(_closed_points(ground_circle), Color("ff4fd8"), maxf(1.5, world_scale * 1.5))
	var visual_lift := Vector2(0.0, -IsometricPoseScript.weapon_lift(action, technique, actor_world_radius) * world_scale) if view_mode == "isometric" else Vector2.ZERO
	var weapon_start := _world_to_screen(Vector2(sample["weapon_start"])) + visual_lift
	var weapon_end := _world_to_screen(Vector2(sample["weapon_end"])) + visual_lift
	var screen_direction := (weapon_end - weapon_start).normalized()
	var side := screen_direction.rotated(PI * 0.5)
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
	if view_mode == "isometric" and visual_lift.length_squared() > 1.0:
		draw_line(_world_to_screen(Vector2(sample["weapon_start"])), weapon_start, Color(color, 0.22), maxf(1.0, width * 0.28))
	if technique == "staff_poke":
		# No spearhead. It is a stick, and the drawing should not promise a point that the
		# damage number does not deliver -- a caster's poke has to read as feeble on sight.
		var cap := maxf(3.0, world_scale * 4.0)
		draw_circle(weapon_end, cap, color)
	elif technique == "thrust":
		var tip := maxf(5.0, world_scale * 8.0)
		draw_colored_polygon(PackedVector2Array([weapon_end + screen_direction * tip, weapon_end - screen_direction * tip * 0.65 + side * tip * 0.55, weapon_end - screen_direction * tip * 0.65 - side * tip * 0.55]), color)
	elif technique == "forward_smash":
		var head_shape := _project_world_circle(Vector2(sample.get("center", sample["weapon_end"])), float(sample.get("head_radius", 30.0)))
		_offset_points(head_shape, visual_lift)
		draw_colored_polygon(head_shape, Color(color, 0.92))
		draw_polyline(_closed_points(head_shape), color.lightened(0.2), maxf(2.0, width * 0.5))
	elif technique in ["heavy_chop", "heavy_cleave"]:
		draw_line(weapon_end - screen_direction * maxf(12.0, world_scale * 20.0), weapon_end, color.lightened(0.16), width * 1.8)
	# No tip dot on a thrust. On a sword the weapon end sits near the body and the dot
	# reads as impact; on a 218-unit spear it is a disc floating in open space with
	# nothing to attach to, which is the "weird circle" the 0.2.32 Polearm showed.
	if active and String(sample.get("shape", "")) != "segment":
		draw_circle(weapon_end, maxf(2.0, width * 0.55), Color(color, 0.75))

func _draw_attack_sector(sample: Dictionary, action: Dictionary, player_weapon: bool) -> void:
	var effect_alpha := float(sample.get("effect_alpha", 0.0))
	var startup := maxf(0.001, float(action.get("startup", 0.35)))
	var elapsed := float(action.get("elapsed", 0.0))
	var telegraph := 0.0
	if not player_weapon and elapsed < startup:
		telegraph = clampf((elapsed / startup - 0.48) / 0.52, 0.0, 1.0)
	if effect_alpha <= 0.001 and telegraph <= 0.001 and not debug_hitboxes: return
	var origin := Vector2(sample["origin"])
	var direction := Vector2(sample.get("direction", Vector2.UP)).normalized()
	var start_angle := float(sample["start_angle"])
	var end_angle := float(sample["end_angle"])
	var inner := float(sample["inner_radius"])
	var outer := float(sample["outer_radius"])
	var steps := maxi(5, ceili(24.0 * absf(end_angle - start_angle) / TAU))
	var fill_color := Color("ffe09a") if player_weapon else Color("ef765f")
	var alpha := 0.24 * effect_alpha if player_weapon else maxf(0.10 * telegraph, 0.20 * effect_alpha)
	var outline_alpha := maxf(0.40 * effect_alpha, 0.28 * telegraph)
	var outer_line := PackedVector2Array()
	var inner_line := PackedVector2Array()
	for index in range(steps):
		var a0 := lerpf(start_angle, end_angle, float(index) / float(steps))
		var a1 := lerpf(start_angle, end_angle, float(index + 1) / float(steps))
		var p0 := origin + direction.rotated(a0) * inner
		var p1 := origin + direction.rotated(a0) * outer
		var p2 := origin + direction.rotated(a1) * outer
		var p3 := origin + direction.rotated(a1) * inner
		draw_colored_polygon(PackedVector2Array([_world_to_screen(p0), _world_to_screen(p1), _world_to_screen(p2), _world_to_screen(p3)]), Color(fill_color, alpha))
	for index in range(steps + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / float(steps))
		outer_line.append(_world_to_screen(origin + direction.rotated(angle) * outer))
		inner_line.append(_world_to_screen(origin + direction.rotated(angle) * inner))
	draw_polyline(outer_line, Color(fill_color.lightened(0.20), outline_alpha * 1.45), maxf(2.5, world_scale * 4.2))
	draw_polyline(inner_line, Color(fill_color, outline_alpha * 0.58), maxf(1.2, world_scale * 1.5))
	if telegraph > 0.001:
		draw_line(inner_line[0], outer_line[0], Color(fill_color, outline_alpha * 0.55), maxf(1.2, world_scale * 1.5))
		draw_line(inner_line[-1], outer_line[-1], Color(fill_color, outline_alpha * 0.55), maxf(1.2, world_scale * 1.5))
	if debug_hitboxes:
		var outline := outer_line.duplicate()
		for index in range(steps, -1, -1):
			var angle := lerpf(start_angle, end_angle, float(index) / float(steps))
			outline.append(_world_to_screen(origin + direction.rotated(angle) * inner))
		outline.append(outline[0])
		draw_polyline(outline, Color("ff4fd8"), maxf(2.0, world_scale * 1.8))

func _draw_interrupted_weapon(world_pos: Vector2, reaction: Dictionary, player_weapon: bool) -> void:
	var interrupted: Dictionary = Dictionary(reaction.get("interrupted_action", {}))
	if not interrupted.has("technique_id"): return
	var technique := String(interrupted.get("technique_id", "diagonal_cut"))
	var direction := Vector2(interrupted.get("direction", Vector2.UP)).normalized()
	var sample: Dictionary = AttackGeometryScript.pose(interrupted, world_pos, direction, state.walls)
	var visual_lift := Vector2(0.0, -IsometricPoseScript.weapon_lift(interrupted, technique, state.ENEMY_RADIUS) * world_scale) if view_mode == "isometric" else Vector2.ZERO
	var start := _world_to_screen(Vector2(sample["weapon_start"])) + visual_lift
	var finish := _world_to_screen(Vector2(sample["weapon_end"])) + visual_lift
	var reaction_direction := _screen_direction(Vector2(reaction.get("reaction_direction", Vector2.RIGHT))).normalized()
	var blade := finish - start
	var sign := signf(blade.cross(reaction_direction))
	if is_zero_approx(sign): sign = 1.0
	var progress := clampf(float(reaction.get("elapsed", 0.0)) / maxf(0.01, float(reaction.get("duration", 0.4))), 0.0, 1.0)
	var knocked_finish := start + blade.rotated(sign * lerpf(0.92, 0.38, progress)) * lerpf(0.82, 0.58, progress)
	var width := maxf(2.0, world_scale * 3.0)
	var color := Color("fff0c5") if player_weapon else Color("f0d2bc")
	draw_line(start, knocked_finish, Color(color, lerpf(0.96, 0.44, progress)), width)
	draw_line(start + (knocked_finish - start) * 0.20, knocked_finish, Color("c86b5b", lerpf(0.72, 0.20, progress)), maxf(1.5, width * 0.40))
	var side := (knocked_finish - start).normalized().rotated(PI * 0.5)
	draw_line(knocked_finish - side * width * 1.35, knocked_finish + side * width * 1.35, Color("fff6d2", 0.78), maxf(1.5, width * 0.44))

func _draw_claw_combo(world_pos: Vector2, action: Dictionary, color: Color) -> void:
	var elapsed := float(action.get("elapsed", 0.0))
	var first_start := float(action.get("first_start", 0.22))
	var first_end := float(action.get("first_end", 0.42))
	var second_start := float(action.get("second_start", 0.57))
	var second_end := float(action.get("second_end", 0.79))
	if String(action.get("kind", "")) == "pounce_combo" and elapsed < first_start:
		var center := _world_to_screen(world_pos)
		var facing := _screen_direction(Vector2(action.get("direction", Vector2.UP)))
		draw_line(center, center - facing * 92.0 * world_scale, Color(color, 0.46), maxf(4.0, world_scale * 8.0))
		return
	var second := elapsed >= second_start
	var sampled := action.duplicate(false)
	sampled["technique_id"] = "reverse_cut" if second else "quick_cut"
	sampled["startup"] = second_start if second else first_start
	sampled["active_end"] = second_end if second else first_end
	var sample := AttackGeometryScript.pose(sampled, world_pos, Vector2(action.get("direction", Vector2.UP)), state.walls)
	var claw_lift := Vector2(0.0, -IsometricPoseScript.weapon_lift(sampled, "quick_cut", 30.0) * world_scale) if view_mode == "isometric" else Vector2.ZERO
	var start := _world_to_screen(Vector2(sample["weapon_start"])) + claw_lift
	var finish := _world_to_screen(Vector2(sample["weapon_end"])) + claw_lift
	var direction := (finish - start).normalized()
	var side := direction.rotated(PI * 0.5)
	var claw_color := Color("f1d3bd")
	for offset in [-4.5, 0.0, 4.5]: draw_line(start + side * offset * world_scale, finish + side * offset * world_scale, claw_color, maxf(1.5, world_scale * 2.4))

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
	elif kind == "ice": color = Color("9be7ff")
	elif kind == "fire": color = Color("ff7b35")
	elif kind == "slam": color = Color("e15c54")
	elif kind in ["miss", "glance"]: color = Color("a9b1b2")
	elif kind == "recover": color = Color("d8ed78")
	elif kind == "anchor": color = Color("f0b45a")
	elif kind == "interrupt": color = Color("ffe2b5")
	elif kind == "posture_break": color = Color("ffb55d")
	elif kind == "strain": color = Color("d7a35e")
	elif kind == "full_draw": color = Color("fff2b4")
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
	elif kind == "interrupt":
		var direction := _screen_direction(Vector2(effect.get("direction", Vector2.RIGHT))).normalized()
		var side := direction.rotated(PI * 0.5)
		var strength := float(effect.get("strength", 1.0))
		for offset in [-1.0, 0.0, 1.0]:
			var start: Vector2 = center - direction * radius * 0.28 + side * offset * radius * 0.18
			var finish: Vector2 = center + direction * radius * (0.72 + strength * 0.18) + side * offset * radius * 0.32
			draw_line(start, finish, Color(color, alpha * (0.95 - absf(offset) * 0.24)), maxf(1.5, 4.0 * alpha))
	elif kind == "posture_break":
		for index in range(12):
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / 12.0)
			draw_line(center + direction * radius * 0.22, center + direction * radius * 1.35, Color(color, alpha), maxf(2.0, 6.0 * alpha))
		draw_circle(center, lerpf(24.0, 8.0, progress), Color(color, alpha * 0.32))
	elif kind == "lightning":
		# The bolt is instantaneous, so there is no projectile to watch and nothing was
		# drawn at all -- the strongest thing a caster does looked like nothing happening.
		# It is drawn as the line it actually is, jagged, fading over the effect's life.
		var from_point := _world_to_screen(Vector2(effect.get("origin", Vector2(effect["pos"]))))
		var to_point := center
		var bolt_alpha := 1.0 - progress
		var segments := 7
		var previous := from_point
		var perpendicular := (to_point - from_point).orthogonal().normalized()
		for step in range(1, segments + 1):
			var along := from_point.lerp(to_point, float(step) / float(segments))
			var jitter := 0.0 if step == segments else sin(float(step) * 2.7 + float(int(center.x)) * 0.13) * 9.0
			var point := along + perpendicular * jitter
			draw_line(previous, point, Color(0.85, 0.95, 1.0, 0.92 * bolt_alpha), maxf(2.0, world_scale * 4.0))
			draw_line(previous, point, Color(1.0, 1.0, 1.0, 0.6 * bolt_alpha), maxf(1.0, world_scale * 1.6))
			previous = point
		draw_circle(to_point, maxf(4.0, world_scale * 7.0 * (1.0 - progress * 0.5)), Color(0.9, 0.97, 1.0, 0.75 * bolt_alpha))
	elif kind == "strain":
		for index in range(4):
			var direction := Vector2.RIGHT.rotated(float(index) * 1.57 + progress * 1.2)
			draw_line(center + direction * radius * 0.25, center + direction * radius * 0.70, Color(color, alpha * 0.72), maxf(1.5, 3.0 * alpha))
	elif kind in ["recover", "anchor"]:
		for index in range(10):
			var direction := Vector2.RIGHT.rotated(TAU * float(index) / 10.0)
			draw_line(center + direction * radius * 0.35, center + direction * radius * 1.25, Color(color, alpha), maxf(2.0, 5.0 * alpha))
		var amount := int(effect.get("amount", 0))
		var label := "+%d XP RECLAIMED" % amount if kind == "recover" else "INTEGRATED" if amount == 0 else "+%d XP INTEGRATED" % amount
		draw_string(ThemeDB.fallback_font, center + Vector2(-100.0, -40.0 - progress * 35.0), label, HORIZONTAL_ALIGNMENT_CENTER, 200.0, maxi(14, int(18.0 * world_scale)), Color(color, alpha))
	draw_arc(center, radius, 0.0, TAU, 18, Color(color, alpha), maxf(2.0, 5.0 * alpha))

# The log line is one line, and draw_string simply stops when it runs out of room -- the
# room-intro message was arriving as "...physical actions and Dodge spe". A telegraph that
# cannot finish its own sentence is the same defect as a phase readout that cannot finish
# its own word, and the game says things here the player is meant to act on. Shrink to fit
# rather than truncate, down to a floor where it would stop being readable.
func _message_font_for(text: String, allowance: float, preferred: int) -> int:
	var chosen := preferred
	while chosen > 11 and ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > allowance:
		chosen -= 1
	return chosen

# Shrink a little, then wrap. The room-intro line explains the rules of the profile being
# played and was arriving as "...and it regenerates continuously - o": long enough that no
# readable single-line size fits it. A second line costs nothing here and the alternative is
# the game explaining itself halfway.
func _draw_log_line(text: String, baseline: Vector2, allowance: float, preferred: int) -> void:
	var chosen := _message_font_for(text, allowance, preferred)
	var fits := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x <= allowance
	if fits:
		draw_string(ThemeDB.fallback_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, allowance, chosen, Color("d9ded8"))
		return
	var lifted := baseline - Vector2(0.0, float(chosen) * 1.15)
	draw_multiline_string(ThemeDB.fallback_font, lifted, text, HORIZONTAL_ALIGNMENT_LEFT, allowance, chosen, 2, Color("d9ded8"))

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
	var width := minf(board_rect.size.x * 0.58, 400.0)
	var height := clampf(board_rect.size.y * 0.021, 19.0, 30.0)
	var bar := Rect2(Vector2(board_rect.get_center().x - width * 0.5, board_rect.position.y + header_font + 34.0), Vector2(width, height))
	var energy_height := clampf(height * 0.82, 16.0, 24.0)
	var energy_bar := Rect2(bar.position + Vector2(0.0, height + 7.0), Vector2(width, energy_height))
	# Health and Energy are one prominent combat-resource cluster. Posture and XP
	# are secondary systems and sit below a deliberate visual break.
	var primary_group := Rect2(bar.position, Vector2(width, height + 7.0 + energy_height))
	draw_rect(primary_group.grow(6.0), Color(0.025, 0.035, 0.04, 0.96))
	draw_line(primary_group.position + Vector2(8.0, -3.0), primary_group.position + Vector2(width - 8.0, -3.0), Color("d8ddd8"), 2.0)
	draw_rect(bar, Color("35191c"))
	var health_color := Color("c9474f") if ratio > 0.25 else Color("ed5b5b")
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), health_color)
	draw_rect(bar, Color("f0c8c8"), false, 2.0)
	var label_font := maxi(12, int(height * 0.72))
	draw_string(ThemeDB.fallback_font, bar.position + Vector2(0.0, height * 0.77), "HEALTH  %d / %d" % [hp, maximum], HORIZONTAL_ALIGNMENT_CENTER, width, label_font, Color("fff3f3"))
	var energy := float(visual.get("player_energy", state.player_energy))
	var energy_max := maxf(1.0, float(visual.get("player_max_energy", state.player_max_energy)))
	# The trough is a cool near-black rather than a dark green. Until 0.2.63 it was a dark
	# version of the fill's own hue, so fill and empty shared a hue family and the whole bar
	# read as one soft mass -- half the reason it was hard to find at a glance had nothing
	# to do with which colour the fill was.
	draw_rect(energy_bar, Color("10202a"))
	if state.uses_energy_rules():
		# One bar pays for swinging and for casting, so it should look like both. The
		# gradient runs green at the empty end into cyan at the full end: hue then tracks
		# fullness alongside length, a second channel agreeing with the first rather than a
		# decoration. It stops short of the player's own #39ddff -- the bar must not start
		# competing with the thing that represents you on the board.
		var energy_ratio := clampf(energy / energy_max, 0.0, 1.0)
		if energy_ratio > 0.0:
			var fill_rect := Rect2(energy_bar.position, Vector2(energy_bar.size.x * energy_ratio, energy_bar.size.y))
			# The gradient is positional across the bar's FULL width and then clipped to the
			# current level, so the colour at any point on the bar is fixed. Interpolating
			# across the drawn width instead would push cyan to the leading edge at every
			# level and the hue would stop meaning anything.
			var leading := ENERGY_EMPTY_COLOR.lerp(ENERGY_FULL_COLOR, energy_ratio)
			draw_polygon(PackedVector2Array([
				fill_rect.position, Vector2(fill_rect.end.x, fill_rect.position.y),
				fill_rect.end, Vector2(fill_rect.position.x, fill_rect.end.y),
			]), PackedColorArray([ENERGY_EMPTY_COLOR, leading, leading, ENERGY_EMPTY_COLOR]))
		var exhaustion := float(visual.get("player_exhaustion_remaining", state.player_exhaustion_remaining))
		draw_rect(energy_bar, Color("a8ead8"), false, 2.0)
		var energy_label := "EXHAUSTED  %d / %d" % [roundi(energy), roundi(energy_max)] if exhaustion > 0.0001 else "ENERGY  %d / %d" % [roundi(energy), roundi(energy_max)]
		draw_string(ThemeDB.fallback_font, energy_bar.position + Vector2(0.0, energy_height * 0.79), energy_label, HORIZONTAL_ALIGNMENT_CENTER, width, maxi(11, int(energy_height * 0.70)), Color("eafffa"))
	else:
		draw_rect(energy_bar, Color("243038"))
		draw_rect(energy_bar, Color("718087"), false, 2.0)
		draw_string(ThemeDB.fallback_font, energy_bar.position + Vector2(0.0, energy_height * 0.79), "RECOVERY RULES  •  ENERGY INACTIVE", HORIZONTAL_ALIGNMENT_CENTER, width, maxi(10, int(energy_height * 0.64)), Color("aeb9bd"))
	_draw_condition_meters(Rect2(energy_bar.position + Vector2(0.0, energy_bar.size.y + 5.0), Vector2(width, energy_bar.size.y * 0.62)))
	var posture := float(visual.get("player_posture", state.player_posture))
	var posture_max := maxf(1.0, float(visual.get("player_posture_max", state.player_posture_max)))
	var posture_height := clampf(height * 0.48, 9.0, 13.0)
	var posture_bar := Rect2(energy_bar.position + Vector2(0.0, energy_height + 13.0), Vector2(width, posture_height))
	draw_rect(posture_bar, Color("17212b"))
	draw_rect(Rect2(posture_bar.position, Vector2(posture_bar.size.x * clampf(posture / posture_max, 0.0, 1.0), posture_bar.size.y)), Color("6d9fc5"))
	draw_rect(posture_bar, Color("8798a1"), false, 1.0)
	draw_string(ThemeDB.fallback_font, posture_bar.position + Vector2(0.0, posture_height * 0.82), "POSTURE  %d / %d" % [roundi(posture), roundi(posture_max)], HORIZONTAL_ALIGNMENT_CENTER, width, maxi(8, int(posture_height * 0.72)), Color("edf3f5"))

func _draw_player_progress_bar(header_font: int) -> void:
	var carried := int(visual.get("carried_xp", state.carried_xp))
	var secured := mini(carried, int(visual.get("secured_xp", state.secured_xp))) if state.mode_id == "campaign_lab" else 0
	var risk := maxi(0, carried - secured)
	var target := maxi(1, maxi(state.next_upgrade_cost(), carried))
	var width := minf(board_rect.size.x * 0.58, 400.0)
	var health_height := clampf(board_rect.size.y * 0.021, 19.0, 30.0)
	var posture_height := clampf(health_height * 0.48, 9.0, 13.0)
	var energy_height := clampf(health_height * 0.82, 16.0, 24.0)
	var height := clampf(board_rect.size.y * 0.013, 12.0, 19.0)
	var bar := Rect2(Vector2(board_rect.get_center().x - width * 0.5, board_rect.position.y + header_font + 72.0 + health_height + energy_height + posture_height), Vector2(width, height))
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
	var world_center := Vector2(hazard["pos"])
	var elapsed := float(hazard["elapsed"])
	var trigger_at := float(hazard["trigger_at"])
	var progress := clampf(elapsed / trigger_at, 0.0, 1.0)
	var kind := String(hazard.get("kind", ""))
	# Cone rendering is geometry-driven so every active cone shares one projection path.
	if hazard.has("half_angle"):
		var direction := Vector2(hazard.get("direction", Vector2.UP)).normalized()
		var half_angle := float(hazard["half_angle"])
		var cone_fill := Color(0.30, 0.73, 0.94, 0.10 + progress * 0.06)
		var cone_edge := Color("a8e9ff")
		if kind in ["fire_breath", "player_fire"]:
			cone_fill = Color(0.94, 0.32, 0.10, 0.12 + progress * 0.10)
			cone_edge = Color("ff9b4f")
		var current_range := float(hazard["radius"]) * progress
		var cone := _project_world_sector(world_center, current_range, direction.angle() - half_angle, half_angle * 2.0, 18)
		if cone.size() >= 3:
			_draw_sector_fill(cone, current_range, half_angle * 2.0, cone_fill)
			draw_polyline(_closed_points(cone), cone_edge, maxf(2.0, world_scale * 5.0))
		# The full extent, faint, from the first frame. A cone that only shows how far it
		# has already reached tells you where it has been; the player needs to know where
		# it is going while there is still time to leave.
		var terminus := _project_world_sector(world_center, float(hazard["radius"]), direction.angle() - half_angle, half_angle * 2.0, 18)
		draw_polyline(_closed_points(terminus), Color(cone_edge, 0.24), maxf(1.0, world_scale * 2.0))
		return
	if kind == "sundered_ground":
		# Drawn as broken ground rather than as a threat zone: it deals no damage, and
		# painting it like fire would teach the player to avoid it for the wrong reason.
		var broken := _world_ring(world_center, float(hazard["radius"]), 26)
		draw_colored_polygon(broken, Color(0.42, 0.31, 0.19, 0.16))
		draw_polyline(_closed_points(broken), Color(0.78, 0.62, 0.40, 0.52), maxf(1.5, world_scale * 3.0))
		for spoke in range(7):
			var angle := TAU * float(spoke) / 7.0 + 0.4
			var inner := _world_to_screen(world_center + Vector2.RIGHT.rotated(angle) * float(hazard["radius"]) * 0.22)
			var outer := _world_to_screen(world_center + Vector2.RIGHT.rotated(angle) * float(hazard["radius"]) * 0.92)
			draw_line(inner, outer, Color(0.72, 0.56, 0.34, 0.42), maxf(1.5, world_scale * 2.4))
		return
	var fill_color := Color(0.55, 0.25, 0.70, 0.08 + progress * 0.12)
	var edge_color := Color("b57bea")
	if kind == "cold_front":
		fill_color = Color(0.28, 0.70, 0.92, 0.10 + progress * 0.18)
		edge_color = Color("9be7ff")
	elif kind in ["fire_breath", "player_fire"]:
		fill_color = Color(0.92, 0.25, 0.08, 0.10 + progress * 0.20)
		edge_color = Color("ff9b4f")
	elif kind == "gale":
		# Nearly no fill. A gale does no damage, so painting it like a damage zone would
		# read as one and teach the player to treat a shove as a wound.
		fill_color = Color(0.78, 0.86, 0.92, 0.04 + progress * 0.05)
		edge_color = Color("d8ecf6")
	var sector := _project_world_sector(world_center, float(hazard["radius"]), -PI * 0.5, TAU * maxf(0.002, progress), 32)
	if sector.size() >= 3: _draw_sector_fill(sector, float(hazard["radius"]), TAU * maxf(0.002, progress), fill_color)
	var ring := _world_ring(world_center, float(hazard["radius"]), 32)
	draw_polyline(_closed_points(ring), Color(edge_color, 0.34), maxf(1.5, world_scale * 3.0))
	if sector.size() >= 3: draw_polyline(_closed_points(sector), edge_color, maxf(2.0, world_scale * 6.0))

func _draw_world_pickups(discovered: Dictionary) -> void:
	for pickup_value in Array(visual.get("world_pickups", [])):
		var pickup: Dictionary = pickup_value
		var point := Vector2(pickup["pos"])
		# Pickups are physical discoveries.  Once their cell has been explored they
		# remain visible whenever the camera can see them, even after the player
		# moves beyond the current awareness radius.
		if String(pickup.get("layer", state.current_layer)) != state.current_layer or not _world_point_on_camera(point, 60.0) or not state.is_discovered(point, discovered): continue
		var center := _world_to_screen(point)
		var item_id := String(pickup.get("item_id", ""))
		var color := Color("db6463") if item_id == "rejuvenation" else Color(String(state.consumable_definition(item_id).get("color", "d7dddd")))
		# Supplies should be easy to recognize in foliage without becoming map pins
		# or revealing routes beyond the player's ordinary awareness.
		var radius := maxf(11.0, 22.0 * world_scale)
		var distance := state.player_pos.distance_to(point)
		draw_circle(center, radius * 2.15, Color(color, 0.10))
		draw_circle(center, radius * 1.50, Color(color, 0.20))
		draw_circle(center, radius, Color("17262b"))
		draw_arc(center, radius * 1.05, 0.0, TAU, 16, Color(color, 0.92), maxf(1.5, radius * 0.16))
		var diamond := PackedVector2Array([center + Vector2(0.0, -radius * 0.62), center + Vector2(radius * 0.62, 0.0), center + Vector2(0.0, radius * 0.62), center + Vector2(-radius * 0.62, 0.0)])
		draw_colored_polygon(diamond, color)
		draw_circle(center + Vector2(-radius * 0.15, -radius * 0.18), radius * 0.18, Color("fff3ce"))
		if distance <= 410.0:
			draw_string(ThemeDB.fallback_font, center + Vector2(-54.0, -radius * 2.00), "SUPPLY", HORIZONTAL_ALIGNMENT_CENTER, 108.0, maxi(9, int(12.0 * world_scale)), Color("fff3ce"))
		if distance <= 145.0:
			var label := "TAKE %s" % ("DRAUGHT" if item_id == "rejuvenation" else String(state.consumable_definition(item_id).get("short", item_id)).to_upper())
			draw_string(ThemeDB.fallback_font, center + Vector2(-58.0, radius * 2.28), label, HORIZONTAL_ALIGNMENT_CENTER, 116.0, maxi(8, int(11.0 * world_scale)), Color("f2e7c8"))

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

func _project_world_sector(center: Vector2, radius: float, start_angle: float, angle_span: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array([_world_to_screen(center)])
	var steps := maxi(2, int(ceil(float(segments) * absf(angle_span) / TAU)))
	for index in range(steps + 1):
		var angle := start_angle + angle_span * float(index) / float(steps)
		points.append(_world_to_screen(center + Vector2.RIGHT.rotated(angle) * radius))
	return points

func _draw_sector_fill(points: PackedVector2Array, world_radius: float, angle_span: float, color: Color) -> void:
	# Projected sectors become concave once a forming circle passes 180 degrees.
	# Explicit triangles stay stable at every arc size and produce an even fill.
	if points.size() < 3: return
	for index in range(1, points.size() - 1):
		draw_colored_polygon(PackedVector2Array([points[0], points[index], points[index + 1]]), color)

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

func _draw_bow(pos: Vector2, facing: Vector2, radius: float, action: Dictionary, world_pos: Vector2 = Vector2.INF) -> void:
	var side := facing.rotated(PI * 0.5)
	var draw_amount := float(action.get("draw_ratio", clampf(float(action["elapsed"]) / float(action.get("startup", 0.72)), 0.0, 1.0)))
	var center := pos + facing * radius * 0.72
	var draw_hand := center - facing * radius * (0.18 + draw_amount * 0.82)
	draw_line(pos - side * radius * 0.34, center + side * radius * 0.56, Color("d7c59c"), maxf(1.5, radius * 0.10))
	draw_line(pos + side * radius * 0.28, draw_hand, Color("d7c59c"), maxf(1.5, radius * 0.10))
	draw_arc(center, radius * 0.75, facing.angle() - 1.2, facing.angle() + 1.2, 12, Color("e9cf91"), 2.0)
	draw_line(center + side * radius * 0.7, draw_hand, Color("d8d2c3"), 1.5)
	draw_line(center - side * radius * 0.7, draw_hand, Color("d8d2c3"), 1.5)
	draw_line(draw_hand, center + facing * radius * (0.85 + draw_amount * 0.18), Color("fff1b8"), maxf(1.5, radius * 0.08))
	if view_mode == "isometric" and world_pos.is_finite():
		var world_direction := Vector2(action.get("direction", Vector2.UP)).normalized()
		var ground_start := _world_to_screen(world_pos + world_direction * 12.0)
		var ground_end := _world_to_screen(world_pos + world_direction * (30.0 + draw_amount * 26.0))
		draw_line(ground_start, ground_end, Color(0.01, 0.02, 0.025, 0.24), maxf(1.0, world_scale * 1.5))
	if String(action.get("kind", "")) == "bow_draw":
		var meter_radius := radius * 1.58
		var start_angle := -PI * 0.5
		draw_arc(pos, meter_radius, start_angle, start_angle + TAU, 36, Color("3c4649", 0.88), maxf(2.0, radius * 0.10))
		if draw_amount > 0.001:
			draw_arc(pos, meter_radius, start_angle, start_angle + TAU * minf(draw_amount, 0.999), 36, Color("e8c35d"), maxf(3.0, radius * 0.15))
		if draw_amount >= 0.995:
			var pulse := 0.80 + 0.20 * sin(float(action.get("elapsed", 0.0)) * 10.0)
			draw_arc(pos, meter_radius, 0.0, TAU, 36, Color(1.0, 0.96, 0.78, pulse), maxf(4.0, radius * 0.20))
			draw_circle(center + facing * radius * 0.92, maxf(3.0, radius * 0.16), Color("fff2b4"))

# Charges were the only attack rendering no telegraph at all: they carry no sector
# geometry, so _draw_attack_sector never sees them, and the wind-up during which the
# animal is crouched and tracking you was invisible. Every timing decision a charge
# is supposed to pose was untestable without this. Fills across the wind-up only and
# clears the instant the run begins -- a placeholder for the animation that should
# eventually carry it. Sits above the health bar and below the awareness marker so a
# Melee Press room with six of these stays readable.
# Wind-up bar. Melee attacks carry sector geometry and get their telegraph from
# _draw_attack_sector; everything else -- charges, arrows, casts, slams -- had no
# visible wind-up at all, so the decision each was meant to pose was invisible.
# Fills across the wind-up only and clears the instant the action commits. Sits
# between the health bar and the awareness marker so a crowded room stays readable.
# A placeholder for the animation that should eventually carry it.
func _draw_windup(pos: Vector2, radius: float, enemy: Dictionary, action: Dictionary) -> void:
	var kind := String(action.get("kind", ""))
	if kind in ["idle", "move", "evade", "melee", "stagger", "hit_reaction"]: return
	if not action.has("startup"): return
	var startup := maxf(0.001, float(action.get("startup", 0.30)))
	var elapsed := float(action.get("elapsed", 0.0))
	if elapsed < startup:
		var progress := clampf(elapsed / startup, 0.0, 1.0)
		var bar := Rect2(pos + Vector2(-radius * 1.15, -radius * 2.15), Vector2(radius * 2.3, maxf(4.0, radius * 0.24)))
		draw_rect(bar.grow(1.5), Color(0.04, 0.05, 0.06, 0.88))
		draw_rect(bar, Color("2a1a14"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color("f0a03c").lerp(Color("ff5a3c"), progress))
		return
	# The contact ring that used to be drawn during a charge is gone. It existed to
	# make an invisible 40-unit collar honest; with the collar removed in 0.2.26 it
	# only traced body plus player radius, and read as an artificial circle rather
	# than as mass.

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
	var ability := AbilityCatalogScript.enemy_ability_for_action(action)
	if not ability.is_empty():
		return String(ability["phase_before"]) if elapsed < float(action.get("startup", ability["startup"])) else String(ability["phase_after"])
	if kind == "attack":
		if elapsed < float(action["startup"]): return "WINDING UP"
		if elapsed < float(action["active_end"]): return "STRIKING"
		return "RECOVERING"
	if kind == "sweep":
		if elapsed < float(action["startup"]): return "DRAWING BACK"
		if elapsed < float(action["active_end"]): return "SWEEPING"
		return "RECOVERING"
	if kind == "bow_draw":
		var ratio := float(action.get("draw_ratio", 0.0))
		return "FULL DRAW" if ratio >= 0.995 else "DRAWING" if ratio >= 0.35 else "LOOSE DRAW"
	if kind in ["bow_release", "bow_art"]:
		return "RELEASING" if not bool(action.get("shot_spawned", false)) else "RECOVERING"
	if kind == "vault": return "VAULTING" if elapsed <= float(action.get("move_end", 0.34)) else "LANDING"
	if kind == "stealth": return "VANISHING"
	if kind == "take_aim": return "STUDYING"
	if kind == "twin_fang": return "TWIN FANG" if elapsed < float(action.get("active_end", 0.29)) else "RECOVERING"
	if kind in ["combo", "art_combo"]:
		if bool(action.get("terminal_recovery_locked", false)): return "RECOVERING"
		if elapsed < float(action.get("startup", 0.0)): return "WINDING UP"
		if elapsed > float(action.get("active_end", 0.0)): return "FOLLOWING THROUGH"
		return "COMBO %d" % (int(action.get("phase_index", 0)) + 1)
	if kind == "rally":
		return "RALLYING" if elapsed < float(action.get("effect_start", 0.18)) else "STANDING FIRM"
	if kind == "advance":
		if elapsed < float(action.get("move_start", 0.08)): return "BRACING"
		if elapsed < float(action.get("impact_end", 0.52)): return "ADVANCING"
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
	# Frost Lance and Fire Breath already had readouts further down this chain -- "CONDENSING"
	# / "LOOSED" and "DRAWING BREATH" / "BREATHING FIRE", which are better lines than the ones
	# 0.2.66 added. That version claimed all four of these abilities had no phase text; it was
	# right about Earth Wall and Sunder and wrong about the other two, and because the new
	# branches came first they shadowed the originals into unreachable code. Two authored
	# descriptions each, one of them dead.
	if kind == "chant": return "CHANTING" if elapsed < float(action.get("startup", 0.9)) else "RECOVERING"
	if kind == "charge":
		if elapsed < float(action.get("startup", 0.4)): return "CROUCHING"
		if elapsed < float(action.get("active_end", 0.8)): return "POUNCING" if String(action.get("label", "")) == "pounce" else "CHARGING"
		return "RECOVERING"
	if kind == "evade": return "DODGING"
	if kind == "dodge_strike":
		if elapsed <= float(action.get("dodge_end", 0.30)): return "DODGING IN"
		if elapsed < float(action.get("active_end", 0.62)): return "STRIKING"
		return "RECOVERING"
	if kind == "claw_combo":
		if elapsed < float(action.get("first_start", 0.22)): return "COILING"
		if elapsed < float(action.get("first_end", 0.42)): return "LEFT CLAW"
		if elapsed < float(action.get("second_start", 0.57)): return "TURNING"
		if elapsed < float(action.get("second_end", 0.79)): return "RIGHT CLAW"
		return "RECOVERING"
	if kind == "pounce_combo":
		if elapsed < float(action.get("startup", 0.34)): return "CROUCHING"
		if elapsed < float(action.get("pounce_end", 0.76)): return "POUNCING"
		if elapsed < float(action.get("first_end", 1.01)): return "LEFT CLAW"
		if elapsed < float(action.get("second_start", 1.13)): return "TURNING"
		if elapsed < float(action.get("second_end", 1.34)): return "RIGHT CLAW"
		return "RECOVERING"
	if kind == "slam": return "RAISING" if elapsed < float(action.get("startup", 1.0)) else "RECOVERING"
	if kind == "hit_reaction": return "REELING"
	if kind == "stagger": return "STAGGERED"
	if kind == "move": return "MOVING" if bool(action.get("moving", false)) else ""
	return ""

func _draw_hud() -> void:
	if waystone_menu_open: _draw_waystone_menu()
	else:
		for slot_id in consumable_rects: _draw_consumable(String(slot_id), Rect2(consumable_rects[slot_id]))
		for name in buttons: _draw_button(String(name), Rect2(buttons[name]))
		_draw_spell_row()
		_draw_button("wait", interaction_rect)
		if state.uses_energy_rules(): _draw_attack_button()
	var font := maxi(11, int(minf(size.x, size.y) * 0.022))
	var hp_text := "XP %d/%d  •  EXPEDITION" % [int(visual.get("carried_xp", state.carried_xp)), state.next_upgrade_cost()]
	if state.mode_id == "combat_survey":
		hp_text = "ROOM %d" % state.survey_room_number
	elif state.mode_id == "boss_lab":
		hp_text = "BOSS LAB"
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
		_draw_log_line(text, Vector2(board_rect.position.x + board_rect.size.x * 0.26, y), board_rect.size.x * 0.7, font)
	else:
		var left := board_rect.position.x + 10.0
		draw_string(ThemeDB.fallback_font, Vector2(left, board_rect.end.y - font * 1.75), hp_text, HORIZONTAL_ALIGNMENT_LEFT, board_rect.size.x - 20.0, font, Color("f0ddd7"))
		_draw_log_line(text, Vector2(left, board_rect.end.y - font * 0.40), board_rect.size.x - 20.0, maxi(10, font - 2))
	if held_movement and pointer_down:
		draw_line(touch_start, touch_current, Color(DODGE_COLOR, 0.55), 4.0)
		draw_circle(touch_current, 8.0, DODGE_COLOR)
	if state.has_pending_pickup():
		var prompt := "BELT FULL — TAP A SLOT TO REPLACE  •  CONTEXT TO LEAVE"
		draw_string(ThemeDB.fallback_font, Vector2(board_rect.position.x, board_rect.position.y + font * 2.7), prompt, HORIZONTAL_ALIGNMENT_CENTER, board_rect.size.x, font, Color("f0c66b"))

func _draw_attack_button() -> void:
	if attack_rect.size == Vector2.ZERO: return
	var center := attack_rect.get_center()
	var radius := attack_rect.size.x * 0.5
	var action_kind := String(state.player_action.get("kind", "idle"))
	var attacking := action_kind in ["attack", "combo", "bow_draw", "bow_release"]
	var terminal_recovery := action_kind == "combo" and bool(state.player_action.get("terminal_recovery_locked", false))
	var exhausted := state.energy_actions_locked()
	var available := state.basic_attack_is_available()
	var accent := Color("e88a55")
	var border := Color("a67558") if terminal_recovery else accent if available or attacking else Color("566268")
	draw_circle(center, radius, Color(0.045, 0.07, 0.08, 0.92))
	draw_arc(center, radius - 2.0, 0.0, TAU, 48, border, 4.0 if attacking or attack_button_pointer_held else 2.5)
	if attack_button_pointer_held:
		draw_circle(center, radius * 0.82, Color(accent, 0.18))
	var title := "ATTACK"
	var subtitle := "HOLD: COMBO"
	if exhausted:
		title = "EXHAUSTED"
		subtitle = "PHYSICAL LOCK"
	elif terminal_recovery:
		title = "RECOVERING"
		subtitle = "SEQUENCE ENDED"
	elif attacking:
		title = "ATTACKING"
		subtitle = "HOLD TO FLOW" if action_kind == "combo" else "RELEASE TO FIRE" if action_kind == "bow_draw" else "COMMITTED"
	elif not available:
		title = "BUSY"
		subtitle = "COMMITTED"
	var title_font := maxi(10, int(radius * 0.27))
	var text_color := Color("f4eee3") if available or attacking else Color("778388")
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius, -2.0), title, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, title_font, text_color)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius, radius * 0.31), subtitle, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, maxi(7, int(title_font * 0.55)), border)
	if desktop_controls:
		draw_string(ThemeDB.fallback_font, center + Vector2(-radius, radius * 0.63), "[F]", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, maxi(7, int(title_font * 0.52)), Color("8d989c"))

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

func _draw_sheet_button() -> void:
	draw_rect(sheet_button_rect, Color(0.06, 0.09, 0.11, 0.86))
	var level_ready := state.can_open_level_sheet()
	draw_rect(sheet_button_rect, Color("d7aa58") if level_ready else DODGE_COLOR if character_sheet_open else Color("718087"), false, 2.0 if level_ready else 1.5)
	var font := maxi(8, int(sheet_button_rect.size.y * 0.27))
	var label := "LEVEL UP [C]" if level_ready and desktop_controls else "LEVEL UP" if level_ready else "SHEET [C]" if desktop_controls else "SHEET"
	draw_string(ThemeDB.fallback_font, sheet_button_rect.position + Vector2(0.0, sheet_button_rect.size.y * 0.61), label, HORIZONTAL_ALIGNMENT_CENTER, sheet_button_rect.size.x, font, Color("d7dddd"))

func _open_character_sheet() -> void:
	sheet_repack_slot = -1
	character_sheet_open = true
	map_open = false
	selected_action = ""
	sheet_detail.clear()
	queue_redraw()

func _draw_view_button() -> void:
	draw_rect(view_rect, Color(0.06, 0.09, 0.11, 0.86))
	draw_rect(view_rect, DODGE_COLOR if view_mode == "isometric" else Color("718087"), false, 1.5)
	var font := maxi(8, int(view_rect.size.y * 0.27))
	var label := "TOP" if view_mode == "isometric" else "ISO"
	if desktop_controls: label += " [V]"
	draw_string(ThemeDB.fallback_font, view_rect.position + Vector2(0.0, view_rect.size.y * 0.61), label, HORIZONTAL_ALIGNMENT_CENTER, view_rect.size.x, font, Color("d7dddd"))

func _draw_character_sheet() -> void:
	sheet_art_rects.clear()
	sheet_property_rects.clear()
	sheet_upgrade_rects.clear()
	sheet_equipment_rects.clear()
	sheet_consumable_rects.clear()
	sheet_detail_close_rect = Rect2()
	sheet_detail_confirm_rect = Rect2()
	sheet_skill_choice_rects.clear()
	var panel := sheet_panel_rect
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.58))
	draw_rect(panel, Color(0.035, 0.06, 0.075, 0.985))
	draw_rect(panel, Color("58d2cf"), false, 2.0)
	var data := state.character_sheet_data()
	var margin := clampf(minf(panel.size.x, panel.size.y) * 0.025, 14.0, 28.0)
	var header_font := maxi(20, int(minf(panel.size.x, panel.size.y) * 0.036))
	var body_font := maxi(12, int(header_font * 0.56))
	var level_context := String(data.get("level_up_context", ""))
	var leveling := not level_context.is_empty()
	var character_name := String(data.get("name", "Wayfarer")).to_upper()
	var title := "%s · LEVEL UP" % character_name if leveling else character_name
	var level_source := "EXPEDITION" if level_context == "expedition" else "COMBAT SURVEY" if level_context == "survey" else "WAYSTONE"
	var subtitle := "%s  •  %d XP  •  SELECT A GOLD TRACK" % [level_source, int(data.get("level_up_xp", 0))] if leveling else "LEVEL %d  •  %d XP TO SPEND" % [state.character_level(), state.carried_xp]
	var title_width := panel.size.x - 2.0 * margin - 104.0
	var title_font := _sheet_fit_font_size(title, title_width, header_font, 12)
	var subtitle_font := _sheet_fit_font_size(subtitle, panel.size.x - 2.0 * margin, body_font, 8)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(margin, margin + title_font), title, HORIZONTAL_ALIGNMENT_LEFT, title_width, title_font, Color("f2e7c8") if leveling else Color("eef4ef"))
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(margin, margin + header_font * 1.62), subtitle, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 2.0 * margin, subtitle_font, Color("d7aa58"))
	_draw_map_action(sheet_close_rect, "CLOSE [ESC]" if desktop_controls else "CLOSE")
	var content_top := panel.position.y + margin + header_font * 2.02
	var content_bottom := panel.end.y - margin
	# Leveling preserves the ordinary Sheet's hierarchy. It only compresses the
	# overview and omits belt repacking so the same grouped track panels gain room.
	var summary_ratio := 0.185 if leveling else 0.31
	var summary_height := clampf((content_bottom - content_top) * summary_ratio, 142.0 if leveling else 176.0, 238.0)
	var summary := Rect2(Vector2(panel.position.x + margin, content_top), Vector2(panel.size.x - margin * 2.0, summary_height))
	_draw_sheet_summary(summary, data, body_font)
	var tracks_top := summary.end.y + margin * 0.48
	if not leveling:
		var belt_height := clampf(summary_height * 0.21, 38.0, 50.0)
		var belt := Rect2(Vector2(summary.position.x, summary.end.y + margin * 0.32), Vector2(summary.size.x, belt_height))
		_draw_sheet_consumables(belt, data, body_font)
		tracks_top = belt.end.y + margin * 0.45
	var tracks := Rect2(Vector2(summary.position.x, tracks_top), Vector2(summary.size.x, content_bottom - tracks_top))
	_draw_sheet_tracks(tracks, Array(data["tracks"]), body_font, Array(data.get("level_up_options", [])), int(data.get("level_up_cost", 0)))
	if not sheet_detail.is_empty(): _draw_sheet_detail(panel, margin, body_font)

func _draw_sheet_summary(rect: Rect2, data: Dictionary, font: int) -> void:
	var gap := maxf(8.0, rect.size.x * 0.022)
	var equipment_width := rect.size.x * 0.47
	var equipment_rect := Rect2(rect.position, Vector2(equipment_width, rect.size.y - 40.0))
	var stats_rect := Rect2(Vector2(equipment_rect.end.x + gap, rect.position.y), Vector2(rect.end.x - equipment_rect.end.x - gap, equipment_rect.size.y))
	_draw_sheet_equipment_cluster(equipment_rect, Dictionary(data["equipment"]), font)
	_draw_sheet_stats(stats_rect, Dictionary(data["attributes"]), font)
	var combat_rect := Rect2(Vector2(rect.position.x, rect.end.y - 34.0), Vector2(rect.size.x, 34.0))
	_draw_sheet_combat_summary(combat_rect, data, font)

func _draw_sheet_equipment_cluster(rect: Rect2, equipment: Dictionary, font: int) -> void:
	draw_rect(rect, Color("10191e"))
	draw_rect(rect, Color("45545a"), false, 1.25)
	var heading_font := _sheet_fit_font_size("EQUIPMENT", rect.size.x - 14.0, font, 7)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(7.0, heading_font * 1.30), "EQUIPMENT", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 14.0, heading_font, Color("d7aa58"))
	var inset := maxf(6.0, rect.size.x * 0.035)
	var slot_width := clampf(rect.size.x * 0.265, 42.0, 76.0)
	var slot_height := clampf((rect.size.y - font * 1.75 - 9.0) / 4.0, 17.0, 39.0)
	var left_x := rect.position.x + inset
	var right_x := rect.end.x - inset - slot_width
	var top := rect.position.y + font * 1.65
	var step := slot_height + maxf(2.0, (rect.size.y - font * 1.80 - slot_height * 4.0) / 3.0)
	var slots := [
		{"id": "head", "label": "HEAD", "side": 0, "row": 0}, {"id": "main_hand", "label": "WEAPON", "side": 1, "row": 0},
		{"id": "torso", "label": "BODY", "side": 0, "row": 1}, {"id": "off_hand", "label": "OFFHAND", "side": 1, "row": 1},
		{"id": "hands", "label": "HANDS", "side": 0, "row": 2}, {"id": "charm", "label": "CHARM", "side": 1, "row": 2},
		{"id": "legs", "label": "LEGS", "side": 0, "row": 3}, {"id": "backpack", "label": "PACK", "side": 1, "row": 3},
	]
	var avatar_center := Vector2(rect.get_center().x, top + (slot_height + step * 3.0) * 0.50)
	draw_circle(avatar_center + Vector2(0.0, -slot_height * 0.56), slot_height * 0.26, PLAYER_COLOR)
	draw_rect(Rect2(avatar_center - Vector2(slot_height * 0.22, slot_height * 0.23), Vector2(slot_height * 0.44, slot_height * 0.68)), Color("2799ae"))
	draw_line(avatar_center + Vector2(-slot_height * 0.45, slot_height * 0.06), avatar_center + Vector2(slot_height * 0.45, slot_height * 0.06), Color("b6e8ef"), maxf(2.0, slot_height * 0.10))
	for slot_value in slots:
		var slot: Dictionary = slot_value
		var slot_id := String(slot["id"])
		var item := String(equipment.get(slot_id, "Empty"))
		var x := left_x if int(slot["side"]) == 0 else right_x
		var slot_rect := Rect2(Vector2(x, top + float(slot["row"]) * step), Vector2(slot_width, slot_height))
		var equipped := item != "Empty"
		draw_rect(slot_rect, Color("193038") if equipped else Color("11191d"))
		draw_rect(slot_rect, Color("58d2cf") if equipped else Color("45545a"), false, 1.0)
		var item_label := _sheet_compact_item_label(item)
		if slot_height < 28.0:
			var slot_label_font := _sheet_fit_font_size(String(slot["label"]), slot_rect.size.x * 0.46, maxi(6, font - 4), 5)
			var item_font := _sheet_fit_font_size(item_label, slot_rect.size.x * 0.48, maxi(6, font - 4), 5)
			draw_string(ThemeDB.fallback_font, slot_rect.position + Vector2(3.0, slot_rect.size.y * 0.68), String(slot["label"]), HORIZONTAL_ALIGNMENT_LEFT, slot_rect.size.x * 0.46, slot_label_font, Color("a9bbc0"))
			draw_string(ThemeDB.fallback_font, slot_rect.position + Vector2(0.0, slot_rect.size.y * 0.68), item_label, HORIZONTAL_ALIGNMENT_RIGHT, slot_rect.size.x - 3.0, item_font, Color("e9efe9") if equipped else Color("657378"))
		else:
			var stacked_label_font := _sheet_fit_font_size(String(slot["label"]), slot_rect.size.x - 6.0, maxi(7, font - 3), 5)
			var stacked_item_font := _sheet_fit_font_size(item_label, slot_rect.size.x - 6.0, maxi(7, font - 3), 5)
			draw_string(ThemeDB.fallback_font, slot_rect.position + Vector2(3.0, stacked_label_font * 0.92), String(slot["label"]), HORIZONTAL_ALIGNMENT_LEFT, slot_rect.size.x - 6.0, stacked_label_font, Color("a9bbc0"))
			draw_string(ThemeDB.fallback_font, slot_rect.position + Vector2(3.0, slot_rect.size.y - 3.0), item_label, HORIZONTAL_ALIGNMENT_LEFT, slot_rect.size.x - 6.0, stacked_item_font, Color("e9efe9") if equipped else Color("657378"))
		sheet_equipment_rects[slot_id] = slot_rect
		sheet_equipment_rects[slot_id + "_detail"] = {"kind": "equipment", "slot": String(slot["label"]).capitalize(), "item": item}

func _draw_sheet_stats(rect: Rect2, attributes: Dictionary, font: int) -> void:
	draw_rect(rect, Color("10191e"))
	draw_rect(rect, Color("45545a"), false, 1.25)
	var heading_font := _sheet_fit_font_size("ATTRIBUTES", rect.size.x - 14.0, font, 7)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(7.0, heading_font * 1.30), "ATTRIBUTES", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 14.0, heading_font, Color("d7aa58"))
	var stats := [
		{"label": "HEALTH", "value": "%d/%d" % [state.player_hp, int(attributes.get("health", 0))]},
		{"label": "ENERGY", "value": "%d/%d" % [roundi(state.player_energy), int(attributes.get("energy", 0))]},
		{"label": "STRENGTH", "value": str(attributes.get("strength", 0))},
		{"label": "DEFENSE", "value": str(attributes.get("defense", 0))},
		{"label": "SPEED", "value": str(attributes.get("speed", 0))},
		{"label": "STEALTH", "value": str(attributes.get("stealth", 0))},
		{"label": "AWARENESS", "value": str(attributes.get("awareness", 0))},
		{"label": "RESOLVE", "value": str(attributes.get("resolve", 0))},
		{"label": "RESISTANCE", "value": str(attributes.get("resistance", 0))},
		{"label": "INTELLECT", "value": str(attributes.get("intelligence", 0))},
		{"label": "FAITH", "value": str(attributes.get("faith", 0))},
	]
	var column_width := (rect.size.x - 16.0) * 0.5
	var rows := int(ceil(float(stats.size()) / 2.0))
	var line_height := maxf(11.0, (rect.size.y - font * 1.8) / float(rows))
	for index in range(stats.size()):
		var stat: Dictionary = stats[index]
		var column := index % 2
		var row := index / 2
		var stat_rect := Rect2(rect.position + Vector2(8.0 + column * column_width, font * 1.52 + row * line_height), Vector2(column_width - 3.0, line_height))
		var stat_font := _sheet_fit_font_size(String(stat["label"]), stat_rect.size.x * 0.68, maxi(8, font - 2), 6)
		var value_font := _sheet_fit_font_size(String(stat["value"]), stat_rect.size.x * 0.28, maxi(8, font - 1), 6)
		draw_string(ThemeDB.fallback_font, stat_rect.position + Vector2(0.0, stat_font), String(stat["label"]), HORIZONTAL_ALIGNMENT_LEFT, stat_rect.size.x * 0.68, stat_font, Color("b9c6c6"))
		draw_string(ThemeDB.fallback_font, stat_rect.position + Vector2(0.0, value_font), String(stat["value"]), HORIZONTAL_ALIGNMENT_RIGHT, stat_rect.size.x, value_font, Color("58d2cf"))

func _draw_sheet_combat_summary(rect: Rect2, data: Dictionary, font: int) -> void:
	draw_rect(rect, Color("15272e"))
	draw_rect(rect, Color("58d2cf"), false, 1.25)
	var weapon_label := String(CombatCatalogScript.weapon_frame(String(data["weapon_frame"])).get("label", "Weapon"))
	var art_id := String(data.get("equipped_art", ""))
	var art_label := "LOCKED" if art_id == "" else String(CombatCatalogScript.weapon_art(art_id).get("label", art_id)).to_upper()
	var form_text := "DRAW › RELEASE" if String(data["weapon_frame"]) == "bow" else "FOUR COMPACT CUTS" if String(data["weapon_frame"]) == "knife" else "SIX ALTERNATING CUTS" if String(data["weapon_frame"]) == "twin_knives" else "CUT › RETURN › DRIVING CUT"
	var weapon_text := "%s  ·  %s" % [weapon_label.to_upper(), form_text]
	var weapon_font := _sheet_fit_font_size(weapon_text, rect.size.x * 0.58 - 8.0, font, 6)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(8.0, weapon_font * 1.22), weapon_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.58 - 8.0, weapon_font, Color("eef4ef"))
	var defense := String(data.get("defense", "dodge")).capitalize()
	var art_text := "ART: %s  ·  %s  ·  STA %d/%d" % [art_label, defense.to_upper(), roundi(float(data.get("current_energy", 0.0))), roundi(float(data.get("maximum_energy", 0.0)))]
	var art_font := _sheet_fit_font_size(art_text, rect.size.x * 0.40 - 8.0, font, 6)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(rect.size.x * 0.60, art_font * 1.22), art_text, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x * 0.40 - 8.0, art_font, Color("d7aa58"))
	if art_id != "" and Array(data["known_arts"]).size() > 1 and state.can_swap_weapon_art():
		sheet_art_rects[art_id] = rect

func _draw_sheet_consumables(rect: Rect2, data: Dictionary, font: int) -> void:
	draw_rect(rect, Color("10191e"))
	draw_rect(rect, Color("45545a"), false, 1.25)
	var healing := "REJUVENATION  %d/%d" % [int(data.get("healing_charges", 0)), int(data.get("healing_capacity", 0))]
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(7.0, font * 1.18), healing, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.34, font, Color("db8c8c"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(rect.size.x * 0.34, font * 1.18), "BELT — TAP TWO ITEMS TO REPACK", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.62, maxi(8, font - 1), Color("9fb2b7"))
	var slots: Array = data.get("consumable_slots", [])
	var gap := 6.0
	var slot_start := rect.position.x + rect.size.x * 0.36
	var slot_width := (rect.end.x - slot_start - gap * 4.0) / 3.0
	for index in range(3):
		var slot_rect := Rect2(Vector2(slot_start + gap + float(index) * (slot_width + gap), rect.position.y + font * 1.45), Vector2(slot_width, rect.size.y - font * 1.62))
		var stored := Dictionary(slots[index]) if index < slots.size() else {}
		var item_id := String(stored.get("id", ""))
		var definition := state.consumable_definition(item_id)
		var selected := sheet_repack_slot == index
		draw_rect(slot_rect, Color("3a3028") if selected else Color("17252a"))
		draw_rect(slot_rect, Color("f0c66b") if selected else Color(String(definition.get("color", "45545a"))), false, 2.0 if selected else 1.0)
		var label := "—" if item_id.is_empty() else String(definition.get("short", item_id)).to_upper()
		var count := "" if item_id.is_empty() else "×%d" % int(stored.get("count", 0))
		draw_string(ThemeDB.fallback_font, slot_rect.position + Vector2(3.0, font * 0.92), label, HORIZONTAL_ALIGNMENT_LEFT, slot_rect.size.x - 6.0, maxi(7, font - 2), Color("d7dddd") if not item_id.is_empty() else Color("657378"))
		draw_string(ThemeDB.fallback_font, slot_rect.position + Vector2(0.0, slot_rect.size.y - 3.0), count, HORIZONTAL_ALIGNMENT_RIGHT, slot_rect.size.x - 4.0, maxi(7, font - 2), Color("f2e7c8"))
		sheet_consumable_rects["slot_%d" % index] = slot_rect

func _draw_sheet_tracks(rect: Rect2, tracks: Array, font: int, level_up_options: Array = [], level_up_cost: int = 0) -> void:
	var leveling := not level_up_options.is_empty()
	var columns := 3
	var rows := int(ceil(float(tracks.size()) / float(columns)))
	var gap := maxf(7.0, rect.size.x * 0.018)
	var card_width := (rect.size.x - gap * float(columns - 1)) / float(columns)
	var card_height := (rect.size.y - gap * float(rows - 1)) / float(rows)
	for index in range(tracks.size()):
		var track: Dictionary = tracks[index]
		var track_id := String(track["id"])
		var column := index % columns
		var row := index / columns
		var card := Rect2(Vector2(rect.position.x + column * (card_width + gap), rect.position.y + row * (card_height + gap)), Vector2(card_width, card_height))
		var purchasable := level_up_options.has(track_id)
		draw_rect(card, Color("10191e"))
		draw_rect(card, Color("d7aa58") if purchasable else Color("45545a"), false, 2.0 if purchasable else 1.25)
		var header_height := maxf(25.0, font * 1.75)
		var header_rect := Rect2(card.position, Vector2(card.size.x, header_height))
		draw_rect(header_rect, Color("2a2a20") if purchasable else Color("152329"))
		draw_line(Vector2(header_rect.position.x, header_rect.end.y), header_rect.end, Color("d7aa58") if purchasable else Color("45545a"), 1.0)
		var track_label := String(track["label"]).to_upper()
		var rank_label := "RANK %d" % int(track["rank"])
		var track_font := _sheet_fit_font_size(track_label, header_rect.size.x * 0.66 - 7.0, font, 6)
		var rank_font := _sheet_fit_font_size(rank_label, header_rect.size.x * 0.31, maxi(9, font - 1), 6)
		draw_string(ThemeDB.fallback_font, header_rect.position + Vector2(7.0, track_font * 1.30), track_label, HORIZONTAL_ALIGNMENT_LEFT, header_rect.size.x * 0.66 - 7.0, track_font, Color("fff1c9") if purchasable else Color("d7aa58"))
		draw_string(ThemeDB.fallback_font, header_rect.position + Vector2(header_rect.size.x * 0.68, rank_font * 1.30), rank_label, HORIZONTAL_ALIGNMENT_RIGHT, header_rect.size.x * 0.32 - 7.0, rank_font, Color("9fb2b7"))
		var stages: Array = track.get("stages", [])
		if stages.is_empty():
			var empty_rect := Rect2(card.position + Vector2(6.0, header_height + 5.0), Vector2(card.size.x - 12.0, card.size.y - header_height - 11.0))
			draw_rect(empty_rect, Color("11181c"))
			draw_string(ThemeDB.fallback_font, empty_rect.position + Vector2(5.0, empty_rect.size.y * 0.47), "DISCIPLINE NOT YET FOUND", HORIZONTAL_ALIGNMENT_CENTER, empty_rect.size.x - 10.0, maxi(9, font - 1), Color("59666b"))
			continue
		var row_gap := 3.0
		var stage_height := (card.size.y - header_height - 7.0 - row_gap * float(stages.size() - 1)) / float(stages.size())
		for stage_index in range(stages.size()):
			var stage: Dictionary = stages[stage_index]
			var stage_rect := Rect2(Vector2(card.position.x + 5.0, header_rect.end.y + 3.0 + stage_index * (stage_height + row_gap)), Vector2(card.size.x - 10.0, stage_height))
			var completed := bool(stage.get("completed", false))
			var current := bool(stage.get("current", false))
			var actionable := purchasable and current
			draw_rect(stage_rect, Color("3b3020") if actionable else Color("173029") if completed else Color("17252a") if current else Color("11181c"))
			if actionable: draw_rect(stage_rect, Color("f0c66b"), false, 1.5)
			var choice_id := String(stage.get("choice", ""))
			var label := String(stage.get("label", "Stage"))
			if completed and not choice_id.is_empty():
				for option_value in Array(stage.get("choices", [])):
					var option := Dictionary(option_value)
					if String(option.get("id", "")) == choice_id:
						label = String(option.get("label", label))
						break
			var status := "DONE" if completed else "%d XP" % level_up_cost if actionable else "LEVEL %d" % int(stage.get("gate", 0))
			var status_font := _sheet_fit_font_size(status, stage_rect.size.x * 0.31 - 6.0, maxi(8, font - 2), 5)
			var label_width := stage_rect.size.x * 0.66 - 8.0
			var label_font := _sheet_fit_font_size(label.to_upper(), label_width, maxi(9, font - 1), 5)
			var text_y := stage_rect.position.y + (stage_rect.size.y + label_font * 0.70) * 0.5
			draw_string(ThemeDB.fallback_font, Vector2(stage_rect.position.x + 6.0, text_y), label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, label_width, label_font, Color("fff1c9") if actionable else Color("d8e1dc") if completed or current else Color("59666b"))
			draw_string(ThemeDB.fallback_font, Vector2(stage_rect.position.x + stage_rect.size.x * 0.68, stage_rect.position.y + (stage_rect.size.y + status_font * 0.70) * 0.5), status, HORIZONTAL_ALIGNMENT_RIGHT, stage_rect.size.x * 0.32 - 6.0, status_font, Color("58d2cf") if completed else Color("f0c66b") if actionable else Color("59666b"))
			if actionable: sheet_upgrade_rects[track_id] = stage_rect
			var detail_id := "%s_%d" % [track_id, stage_index]
			sheet_property_rects[detail_id] = stage_rect
			sheet_property_rects[detail_id + "_detail"] = {"kind": "stage", "track": String(track["label"]), "stage": stage.duplicate(true)}

func _draw_sheet_detail(panel: Rect2, margin: float, font: int) -> void:
	draw_rect(panel.grow(-2.0), Color(0.01, 0.02, 0.025, 0.76))
	var kind := String(sheet_detail.get("kind", ""))
	var box_height := clampf(panel.size.y * (0.48 if kind == "track_choice" else 0.38 if kind == "upgrade" else 0.34), 190.0, 360.0)
	var box_size := Vector2(minf(panel.size.x - margin * 2.0, 620.0), box_height)
	var box := Rect2(panel.get_center() - box_size * 0.5, box_size)
	draw_rect(box, Color("102128"))
	draw_rect(box, Color("58d2cf"), false, 2.0)
	if kind == "upgrade":
		_draw_sheet_upgrade_confirmation(box, font)
		return
	if kind == "track_choice":
		_draw_sheet_weapon_skill_choice(box, font)
		return
	sheet_detail_close_rect = Rect2(box.end - Vector2(84.0, box.size.y - 9.0), Vector2(75.0, 30.0))
	if kind == "stage":
		var stage: Dictionary = sheet_detail["stage"]
		var title := "%s · %s" % [String(sheet_detail["track"]).to_upper(), String(stage["label"]).to_upper()]
		var title_font := _sheet_fit_font_size(title, box.size.x - 118.0, font + 2, 7)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(14.0, 14.0 + title_font), title, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 118.0, title_font, Color("d7aa58"))
		var description_rect := Rect2(box.position + Vector2(14.0, 52.0), Vector2(box.size.x - 28.0, box.size.y - 105.0))
		_draw_sheet_wrapped_text(description_rect, String(stage["description"]), font, 7, Color("e5ece6"))
		var status := "COMPLETED" if bool(stage.get("completed", false)) else "AVAILABLE FROM LEVEL %d" % int(stage.get("gate", 0))
		var status_font := _sheet_fit_font_size(status, box.size.x - 28.0, font + 1, 7)
		draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 14.0, box.end.y - 18.0), status, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 28.0, status_font, Color("58d2cf") if bool(stage.get("completed", false)) else Color("718087"))
	else:
		var item := String(sheet_detail.get("item", "Empty"))
		var slot_title := String(sheet_detail.get("slot", "Equipment")).to_upper()
		var slot_font := _sheet_fit_font_size(slot_title, box.size.x - 118.0, font + 2, 7)
		var item_font := _sheet_fit_font_size(item.to_upper(), box.size.x - 28.0, font + 3, 7)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(14.0, 14.0 + slot_font), slot_title, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 118.0, slot_font, Color("d7aa58"))
		draw_string(ThemeDB.fallback_font, box.position + Vector2(14.0, 48.0 + item_font), item.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 28.0, item_font, Color("eef4ef") if item != "Empty" else Color("718087"))
		var item_text := "This slot is currently empty." if item == "Empty" else "Its properties will appear here as equipment enters the prototype."
		_draw_sheet_wrapped_text(Rect2(box.position + Vector2(14.0, 88.0), Vector2(box.size.x - 28.0, box.size.y - 104.0)), item_text, font, 7, Color("c4d0cc"))
	_draw_map_action(sheet_detail_close_rect, "BACK [ESC]" if desktop_controls else "BACK")

func _draw_sheet_upgrade_confirmation(box: Rect2, font: int) -> void:
	var stage: Dictionary = sheet_detail["stage"]
	var cost := int(sheet_detail.get("cost", 0))
	var xp := state.secured_xp if state.mode_id == "campaign_lab" else state.carried_xp
	var title := "%s · %s" % [String(sheet_detail["track"]).to_upper(), String(stage["label"]).to_upper()]
	var title_font := _sheet_fit_font_size(title, box.size.x - 32.0, font + 3, 7)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(16.0, 14.0 + title_font), title, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32.0, title_font, Color("d7aa58"))
	_draw_sheet_wrapped_text(Rect2(box.position + Vector2(16.0, 52.0), Vector2(box.size.x - 32.0, box.size.y - 158.0)), String(stage["description"]), font + 1, 7, Color("fff1c9"))
	var permanence := "THIS CHOICE IS PERMANENT FOR THE RUN."
	var permanence_font := _sheet_fit_font_size(permanence, box.size.x - 32.0, font, 6)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 16.0, box.end.y - 92.0), permanence, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32.0, permanence_font, Color("9fb2b7"))
	var cost_text := "COST  %d XP     REMAINING  %d XP" % [cost, maxi(0, xp - cost)]
	var cost_font := _sheet_fit_font_size(cost_text, box.size.x - 32.0, font, 6)
	draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 16.0, box.end.y - 70.0), cost_text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32.0, cost_font, Color("d7ddd5"))
	var button_size := Vector2(minf(156.0, (box.size.x - 48.0) * 0.42), 38.0)
	sheet_detail_close_rect = Rect2(box.end - Vector2(button_size.x * 2.0 + 28.0, button_size.y + 14.0), button_size)
	sheet_detail_confirm_rect = Rect2(box.end - Vector2(button_size.x + 14.0, button_size.y + 14.0), button_size)
	_draw_sheet_modal_button(sheet_detail_close_rect, "CANCEL", false, true)
	_draw_sheet_modal_button(sheet_detail_confirm_rect, "SPEND %d XP" % cost, true, true)

func _draw_sheet_weapon_skill_choice(box: Rect2, font: int) -> void:
	var stage: Dictionary = sheet_detail["stage"]
	var cost := int(sheet_detail.get("cost", 0))
	var selected := String(sheet_detail.get("selected", ""))
	var title := "%s · %s" % [String(sheet_detail["track"]).to_upper(), String(stage["label"]).to_upper()]
	var title_font := _sheet_fit_font_size(title, box.size.x - 32.0, font + 3, 7)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(16.0, 14.0 + title_font), title, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32.0, title_font, Color("d7aa58"))
	var instruction := "Choose one. This branch is permanent for the run."
	var instruction_font := _sheet_fit_font_size(instruction, box.size.x - 32.0, font, 7)
	draw_string(ThemeDB.fallback_font, box.position + Vector2(16.0, 44.0 + instruction_font), instruction, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 32.0, instruction_font, Color("e5ece6"))
	var options: Array = sheet_detail.get("options", [])
	var gap := 10.0
	var option_width := (box.size.x - 32.0 - gap) / maxf(1.0, float(options.size()))
	var option_height := clampf(box.size.y * 0.38, 78.0, 110.0)
	var options_y := box.position.y + 72.0
	for index in range(options.size()):
		var option_data := Dictionary(options[index])
		var option_id := String(option_data["id"])
		var encoded_option := "%s|%s" % [String(sheet_detail["upgrade_id"]), option_id]
		var choice_rect := Rect2(Vector2(box.position.x + 16.0 + float(index) * (option_width + gap), options_y), Vector2(option_width, option_height))
		var is_selected := selected == encoded_option
		draw_rect(choice_rect, Color("4a3520") if is_selected else Color("17252a"))
		draw_rect(choice_rect, Color("f0c66b") if is_selected else Color("58d2cf"), false, 2.0 if is_selected else 1.25)
		var option_label := String(option_data.get("label", "Choice")).to_upper()
		var option_font := _sheet_fit_font_size(option_label, choice_rect.size.x - 16.0, font + 1, 6)
		draw_string(ThemeDB.fallback_font, choice_rect.position + Vector2(8.0, 8.0 + option_font), option_label, HORIZONTAL_ALIGNMENT_LEFT, choice_rect.size.x - 16.0, option_font, Color("fff1c9") if is_selected else Color("e5ece6"))
		_draw_sheet_wrapped_text(Rect2(choice_rect.position + Vector2(8.0, 32.0), Vector2(choice_rect.size.x - 16.0, choice_rect.size.y - 38.0)), String(option_data.get("description", "")), maxi(9, font - 1), 6, Color("d7ddd5"))
		sheet_skill_choice_rects[encoded_option] = choice_rect
	var button_size := Vector2(minf(156.0, (box.size.x - 48.0) * 0.42), 38.0)
	sheet_detail_close_rect = Rect2(box.end - Vector2(button_size.x * 2.0 + 28.0, button_size.y + 14.0), button_size)
	sheet_detail_confirm_rect = Rect2(box.end - Vector2(button_size.x + 14.0, button_size.y + 14.0), button_size)
	_draw_sheet_modal_button(sheet_detail_close_rect, "CANCEL", false, true)
	_draw_sheet_modal_button(sheet_detail_confirm_rect, "SPEND %d XP" % cost, true, not selected.is_empty())

func _draw_sheet_modal_button(rect: Rect2, label: String, primary: bool, enabled: bool) -> void:
	var fill := Color("6b4e29") if primary and enabled else Color("17252a") if enabled else Color("11191d")
	var border := Color("f0c66b") if primary and enabled else Color("58d2cf") if enabled else Color("45545a")
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 1.8)
	var button_font := _sheet_fit_font_size(label, rect.size.x - 8.0, 12, 6)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, rect.size.y * 0.64), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, button_font, Color("fff1c9") if enabled else Color("657378"))

func _sheet_text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x

func _sheet_fit_font_size(text: String, width: float, preferred: int, minimum: int = 6) -> int:
	var result := maxi(minimum, preferred)
	while result > minimum and _sheet_text_width(text, result) > maxf(1.0, width):
		result -= 1
	return result

func _sheet_wrap_lines(text: String, width: float, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	for paragraph_value in text.split("\n", true):
		var paragraph := String(paragraph_value)
		var words := paragraph.split(" ", false)
		if words.is_empty():
			lines.append("")
			continue
		var current := ""
		for word_value in words:
			var word := String(word_value)
			var candidate := word if current.is_empty() else "%s %s" % [current, word]
			if current.is_empty() or _sheet_text_width(candidate, font_size) <= maxf(1.0, width):
				current = candidate
			else:
				lines.append(current)
				current = word
		if not current.is_empty():
			lines.append(current)
	return lines

func _sheet_text_layout(text: String, width: float, height: float, preferred: int, minimum: int = 6) -> Dictionary:
	var lower_bound := maxi(4, minimum)
	for font_size in range(maxi(lower_bound, preferred), lower_bound - 1, -1):
		var lines := _sheet_wrap_lines(text, width, font_size)
		var line_height := ceilf(ThemeDB.fallback_font.get_height(font_size) * 1.12)
		var widest := 0.0
		for line in lines:
			widest = maxf(widest, _sheet_text_width(line, font_size))
		if widest <= width + 0.01 and line_height * float(lines.size()) <= height + 0.01:
			return {"font_size": font_size, "line_height": line_height, "lines": lines, "width": widest, "height": line_height * float(lines.size()), "fits": true}
	var fallback_lines := _sheet_wrap_lines(text, width, lower_bound)
	var fallback_height := ceilf(ThemeDB.fallback_font.get_height(lower_bound) * 1.12)
	var fallback_width := 0.0
	for line in fallback_lines:
		fallback_width = maxf(fallback_width, _sheet_text_width(line, lower_bound))
	return {"font_size": lower_bound, "line_height": fallback_height, "lines": fallback_lines, "width": fallback_width, "height": fallback_height * float(fallback_lines.size()), "fits": fallback_width <= width + 0.01 and fallback_height * float(fallback_lines.size()) <= height + 0.01}

func _draw_sheet_wrapped_text(rect: Rect2, text: String, preferred: int, minimum: int, color: Color) -> Dictionary:
	var layout := _sheet_text_layout(text, rect.size.x, rect.size.y, preferred, minimum)
	var font_size := int(layout["font_size"])
	var line_height := float(layout["line_height"])
	var y := rect.position.y + ThemeDB.fallback_font.get_ascent(font_size)
	for line_value in Array(layout["lines"]):
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, y), String(line_value), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, font_size, color)
		y += line_height
	return layout

func _sheet_rank_pips(rank: int, maximum: int) -> String:
	var result := ""
	for pip in range(maximum): result += "●" if pip < rank else "○"
	return result

func _sheet_compact_item_label(item: String) -> String:
	if item == "Empty": return "—"
	if item == "Waystone Fragment": return "FRAGMENT"
	if item.length() > 9: return item.left(8).to_upper() + "."
	return item.to_upper()

func _sheet_compact_property_label(label: String) -> String:
	var compact := {"Clean Escape": "Escape", "Use Recovery": "Use rec.", "Break Punish": "Break", "Recovery Punish": "Punish", "Break Duration": "Break time"}
	return String(compact.get(label, label)).to_upper()

func _sheet_compact_art_label(label: String) -> String:
	var compact := {"SWEEPING CUT": "SWEEP", "DRAWING CUT": "DRAW"}
	return String(compact.get(label, label))

func _draw_sheet_heading(position: Vector2, width: float, label: String, font: int) -> void:
	draw_string(ThemeDB.fallback_font, position + Vector2(0.0, font), label, HORIZONTAL_ALIGNMENT_LEFT, width, font, Color("d7aa58"))
	draw_line(position + Vector2(0.0, font * 1.32), position + Vector2(width, font * 1.32), Color("45545a"), 1.0)

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
	# The picker replaces the screen rather than floating over it. Drawing the setup
	# controls afterwards left the start button and the archive button painted on top of
	# the panel, and the seed field -- a real node -- on top of everything.
	if custom_room_open:
		_draw_custom_room_panel()
		return
	var layout := safe_layout_rect if safe_layout_rect.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	var portrait := layout.size.y >= layout.size.x
	var title_font := maxi(28, int(minf(layout.size.x, layout.size.y) * 0.055))
	var body_font := maxi(14, int(title_font * 0.44))
	var heading_x := layout.position.x if portrait else layout.position.x + 24.0
	var heading_width := layout.size.x if portrait else minf(layout.size.x * 0.42, 520.0)
	# The title only belongs on the root screen. On the options screen everything above the
	# class list is spoken for by the back button, and a heading drawn at 0.16 of the height
	# would sit straight on top of it -- the same collision this restructure exists to end.
	if setup_stage == "root":
		draw_string(ThemeDB.fallback_font, Vector2(heading_x, layout.position.y + layout.size.y * (0.16 if portrait else 0.10)), "WAYSTONE", HORIZONTAL_ALIGNMENT_CENTER, heading_width, title_font, Color("f2e7c8"))
		draw_string(ThemeDB.fallback_font, Vector2(heading_x, layout.position.y + layout.size.y * (0.23 if portrait else 0.17)), "Choose a path", HORIZONTAL_ALIGNMENT_CENTER, heading_width, body_font, Color("9fb2b7"))
		if desktop_controls and portrait:
			draw_string(ThemeDB.fallback_font, Vector2(layout.position.x, layout.position.y + layout.size.y * 0.275), "1–3 character  •  Tab mode  •  Enter start  •  F11 fullscreen", HORIZONTAL_ALIGNMENT_CENTER, layout.size.x, maxi(10, int(body_font * 0.72)), Color("718087"))
	else:
		var heading := "EXPEDITION" if setup_mode == "expedition" else "CAMPAIGN" if setup_mode == "campaign_lab" else "BOSS LAB" if setup_mode == "boss_lab" else ("DEV · CUSTOM ROOM" if _custom_section_active() else "DEV · SURVEY ROOMS")
		draw_rect(setup_back_rect, Color("17272d"))
		draw_rect(setup_back_rect, Color("718087"), false, 2.0)
		draw_string(ThemeDB.fallback_font, setup_back_rect.position + Vector2(0, setup_back_rect.size.y * 0.66), "BACK", HORIZONTAL_ALIGNMENT_CENTER, setup_back_rect.size.x, 14, Color("d7dddd"))
		draw_string(ThemeDB.fallback_font, Vector2(setup_back_rect.end.x + 14.0, setup_back_rect.position.y + setup_back_rect.size.y * 0.68), heading, HORIZONTAL_ALIGNMENT_LEFT, layout.size.x, 16, Color("f2e7c8"))
	for choice in CombatCatalogScript.loadout_ids():
		var rect: Rect2 = _setup_class_rect(String(choice))
		var selected: bool = setup_loadout == String(choice)
		draw_rect(rect, Color("17272d"))
		draw_rect(rect, Color("58d2cf") if selected else Color("45545a"), false, 3.0 if selected else 1.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.58), CombatCatalogScript.loadout_name(String(choice)).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, body_font, Color("eef0e9"))
	for mode in progression_rects:
		var rect := Rect2(progression_rects[mode])
		var selected: bool = setup_mode == String(mode)
		draw_rect(rect, Color("17272d"))
		draw_rect(rect, Color("d7aa58") if selected else Color("45545a"), false, 3.0 if selected else 1.0)
		var label := "EXPEDITION" if String(mode) == "expedition" else "CAMPAIGN" if String(mode) == "campaign_lab" else "BOSS LAB" if String(mode) == "boss_lab" else "DEV"
		var subtitle := "PERMADEATH • EXIT LEVELS" if String(mode) == "expedition" else "RESPAWN • STONE LEVELS" if String(mode) == "campaign_lab" else "REPEATABLE BOSS TESTS" if String(mode) == "boss_lab" else "TESTING INSTRUMENTS"
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.40), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, body_font, Color("eef0e9"))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(5, rect.size.y * 0.70), subtitle, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 10, maxi(9, int(body_font * 0.62)), Color("9fb2b7"))
	if setup_mode == "combat_survey":
		for profile in survey_profile_rects:
			var rect := Rect2(survey_profile_rects[profile])
			var selected := setup_survey_profile == String(profile)
			draw_rect(rect, Color("17272d"))
			draw_rect(rect, Color("58d2cf") if selected else Color("45545a"), false, 2.0)
			var label := "ENCOUNTER" if String(profile) == "encounter" else "ATTRITION"
			var subtitle := "RESET BETWEEN ROOMS" if String(profile) == "encounter" else "RESOURCES CARRY"
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.43), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(12, int(body_font * 0.82)), Color("eef0e9"))
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.76), subtitle, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(8, int(body_font * 0.54)), Color("9fb2b7"))
	if setup_mode == "boss_lab":
		for boss_kind in boss_choice_rects:
			var rect := Rect2(boss_choice_rects[boss_kind])
			var selected := setup_boss_kind == String(boss_kind)
			draw_rect(rect, Color("17272d"))
			draw_rect(rect, Color("c9a3e6") if selected else Color("45545a"), false, 2.0)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.62), String(boss_kind).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(12, int(body_font * 0.82)), Color("eef0e9"))
		if boss_arena_rect.size.x > 0.0:
			draw_rect(boss_arena_rect, Color("17272d"))
			draw_rect(boss_arena_rect, Color("6f91b8"), false, 2.0)
			var arena_label := setup_boss_arena.replace("_", " ").to_upper()
			draw_string(ThemeDB.fallback_font, boss_arena_rect.position + Vector2(0, boss_arena_rect.size.y * 0.62), "ARENA · %s — TAP TO CHANGE" % arena_label, HORIZONTAL_ALIGNMENT_CENTER, boss_arena_rect.size.x, maxi(11, int(body_font * 0.72)), Color("eef0e9"))
	if setup_mode in ["combat_survey", "boss_lab"]:
		for rule in combat_rule_rects:
			var rect := Rect2(combat_rule_rects[rule])
			var selected := setup_combat_rules == String(rule)
			draw_rect(rect, Color("17272d"))
			draw_rect(rect, Color("d7aa58") if selected else Color("45545a"), false, 2.0)
			var label := "RECOVERY" if String(rule) == "recovery" else "ENERGY"
			var subtitle := "ABILITY COOLDOWNS • NO ENERGY" if String(rule) == "recovery" else "ACTION ENERGY • EXHAUSTION"
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.43), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(12, int(body_font * 0.82)), Color("eef0e9"))
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.76), subtitle, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(8, int(body_font * 0.50)), Color("9fb2b7"))
	if _custom_section_active():
		var picked := _custom_room_total()
		draw_rect(custom_open_rect, Color("17272d"))
		draw_rect(custom_open_rect, Color("c9a3e6") if picked > 0 else Color("45545a"), false, 2.0)
		var custom_label := "CUSTOM ROOM · OFF — TAP TO COMPOSE" if picked == 0 else "CUSTOM ROOM · ON — %d ENEMIES%s" % [picked, "" if custom_room_repeat else " · ONE ROOM"]
		draw_string(ThemeDB.fallback_font, custom_open_rect.position + Vector2(0, custom_open_rect.size.y * 0.66), custom_label, HORIZONTAL_ALIGNMENT_CENTER, custom_open_rect.size.x, 13, Color("eef0e9") if picked > 0 else Color("9fb2b7"))
	draw_rect(archive_button_rect, Color("10191e"))
	draw_rect(archive_button_rect, Color("718087"), false, 2.0)
	draw_string(ThemeDB.fallback_font, archive_button_rect.position + Vector2(0, archive_button_rect.size.y * 0.62), "SURVEY ARCHIVE", HORIZONTAL_ALIGNMENT_CENTER, archive_button_rect.size.x, 12, Color("d7dddd"))
	if setup_stage == "root": return
	draw_rect(start_rect, Color("24433f"))
	draw_rect(start_rect, Color("58d2cf"), false, 3.0)
	draw_string(ThemeDB.fallback_font, start_rect.position + Vector2(0, start_rect.size.y * 0.60), "START RUN", HORIZONTAL_ALIGNMENT_CENTER, start_rect.size.x, maxi(18, body_font), Color("f3f2e8"))
	if setup_seed_error != "":
		draw_string(ThemeDB.fallback_font, Vector2(start_rect.position.x, start_rect.end.y + 24.0), setup_seed_error, HORIZONTAL_ALIGNMENT_CENTER, start_rect.size.x, maxi(12, int(body_font * 0.8)), Color("e46c63"))

func _draw_survey_end_button() -> void:
	draw_rect(survey_end_rect, Color(0.10, 0.055, 0.055, 0.92))
	draw_rect(survey_end_rect, Color("d76a68"), false, 1.5)
	var label := "END ATTEMPT" if state.mode_id == "boss_lab" else "END RUN"
	draw_string(ThemeDB.fallback_font, survey_end_rect.position + Vector2(0, survey_end_rect.size.y * 0.61), label, HORIZONTAL_ALIGNMENT_CENTER, survey_end_rect.size.x, maxi(8, int(survey_end_rect.size.y * 0.26)), Color("f0d2cf"))

# Read from what _layout() produced. This used to compute its own geometry, which is how
# it came to overlap the rows beneath it -- two sources of truth for one screen.
func _setup_class_rect(choice: String) -> Rect2:
	return Rect2(setup_class_rects.get(choice, Rect2()))

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
		var surface_color := state.floor_surface_color_at(world_cell + Vector2.ONE * state.VISIBILITY_CELL * 0.5, viewed_layer)
		surface_color.a = 0.55 if overlay else 0.96
		draw_rect(Rect2(origin + world_cell * scale, Vector2.ONE * map_cell_size), surface_color)
	for feature_value in state.terrain_features:
		var feature: Dictionary = feature_value
		var feature_kind := String(feature.get("kind", "tree"))
		var feature_pos := Vector2(feature["pos"])
		if feature_kind in ["tree", "thicket", "undergrowth", "flowers"] or String(feature.get("layer", viewed_layer)) != viewed_layer or not _terrain_feature_revealed(feature_pos, map_cells): continue
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
	var layout := safe_layout_rect if safe_layout_rect.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	return board_rect.grow(-18.0) if state.map_presentation == "overlay" else layout.grow(-14.0)

func _map_close_rect() -> Rect2:
	var rect := _map_panel_rect()
	return Rect2(rect.position + Vector2(rect.size.x - 132.0, 12.0), Vector2(120.0, 46.0))

func _map_action_rect(row: int) -> Rect2:
	var layout := safe_layout_rect if safe_layout_rect.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	var rect := layout.grow(-14.0)
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
	var presentation := CombatCatalogScript.presentation(kind)
	var action_text := _phase(Dictionary(enemy["action"]))
	if action_text == "": action_text = "READY"
	var technique_id := String(Dictionary(enemy["action"]).get("technique_id", presentation["signature_technique"]))
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
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, height * 0.25), String(presentation["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width - 20, title_font, Color("eef0e9"))
	var line_one := "%s  |  %s  |  %s speed  |  %s reach" % [action_text.capitalize(), technique_text, String(presentation["speed"]), String(presentation["reach"])]
	var line_two := "%s  |  %s" % [stability, String(presentation["trait"])]
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, height * 0.56), line_one, HORIZONTAL_ALIGNMENT_LEFT, width - 20, body_font, Color("d8ddd8"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, height * 0.80), line_two, HORIZONTAL_ALIGNMENT_LEFT, width - 20, body_font, Color("d7aa58"))

func _draw_loadout_tab(choice: String, rect: Rect2) -> void:
	var selected := state.loadout_id == choice
	var colors := {"warrior": Color("58d2cf")}
	var color: Color = colors[choice]
	draw_rect(rect, Color("17272d") if selected else Color("10191e"))
	draw_rect(rect, color if selected else Color("45545a"), false, 3.0 if selected else 1.0)
	var font := maxi(9, int(minf(rect.size.x, rect.size.y) * 0.25))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, rect.size.y * 0.62), choice.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font, Color("eef0e9") if selected else Color("718087"))

# Known spells first, then a locked slot for every element still to come. A row holding
# one button does not read as a spellbook -- it reads as a single ability, which is why the
# spellbook appeared to be missing entirely at level 1. The framework already asks that
# future nodes stay visible so a build can be planned; this is that rule applied to the
# thing the player actually looks at.
const ELEMENT_SLOT_LABELS := {"element_fire": "FIRE", "element_ice": "ICE", "element_earth": "EARTH", "element_air": "AIR"}

func _spell_row() -> Array[String]:
	if state.loadout_id != "mage_elementalist": return []
	var row: Array[String] = []
	for spell_value in state.player_spells: row.append(String(spell_value))
	for stage_id in ["element_fire", "element_ice", "element_earth", "element_air"]:
		var learned := false
		for choice in Array(state.ELEMENT_STAGE_SPELLS[stage_id]):
			if state.knows_spell(String(choice)): learned = true
		if not learned: row.append("locked:%s" % stage_id)
	return row

func _draw_spell_row() -> void:
	if spell_rects.is_empty(): return
	if spellbook_panel.size.x > 1.0:
		draw_rect(spellbook_panel, Color("101c24"))
		draw_rect(spellbook_panel, Color("2f4a56"), false, 2.0)
		# A small triangle on the lower edge, notched into the button the drawer belongs
		# to. Without it the panel is five more controls appearing out of nowhere; with it,
		# it is that slot opening.
		if spellbook_arrow_x > 0.0:
			var tip := Vector2(spellbook_arrow_x, spellbook_panel.end.y + 11.0)
			draw_colored_polygon(PackedVector2Array([tip, Vector2(spellbook_arrow_x - 11.0, spellbook_panel.end.y - 1.0), Vector2(spellbook_arrow_x + 11.0, spellbook_panel.end.y - 1.0)]), Color("2bb8e0"))
			draw_colored_polygon(PackedVector2Array([tip + Vector2(0.0, -3.4), Vector2(spellbook_arrow_x - 7.6, spellbook_panel.end.y - 3.0), Vector2(spellbook_arrow_x + 7.6, spellbook_panel.end.y - 3.0)]), Color("101c24"))
		else:
			# Landscape opens sideways, so the notch is on the right edge pointing into the
			# button rather than on the bottom pointing down at it.
			var edge := spellbook_panel.end.x
			var mid := clampf(spellbook_arrow_y, spellbook_panel.position.y + 14.0, spellbook_panel.end.y - 14.0)
			draw_colored_polygon(PackedVector2Array([Vector2(edge + 11.0, mid), Vector2(edge - 1.0, mid - 11.0), Vector2(edge - 1.0, mid + 11.0)]), Color("2bb8e0"))
			draw_colored_polygon(PackedVector2Array([Vector2(edge + 7.6, mid), Vector2(edge - 3.0, mid - 7.6), Vector2(edge - 3.0, mid + 7.6)]), Color("101c24"))
	var castable := state.spell_is_available()
	for spell_value in spell_rects:
		var spell_id := String(spell_value)
		var rect := Rect2(spell_rects[spell_id])
		if spell_id.begins_with("locked:"):
			var stage_id := spell_id.trim_prefix("locked:")
			var gate := int(Dictionary(CombatCatalogScript.character_stage_by_id(stage_id)).get("gate", 0))
			draw_rect(rect, Color("101a20"))
			draw_rect(rect, Color("39474e"), false, 2.0)
			var slot_font := maxi(9, int(rect.size.y * 0.32))
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, rect.size.y * 0.46), String(ELEMENT_SLOT_LABELS.get(stage_id, "?")), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, slot_font, Color("5d6a71"))
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, rect.size.y * 0.86), "LV %d" % gate, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(8, int(slot_font * 0.78)), Color("46545b"))
			continue
		var chosen := spell_id == state.selected_spell
		var colour := SPELL_COLORS.get(spell_id, Color("c8d6de")) as Color
		draw_rect(rect, Color("16222a") if castable else Color("11191d"))
		draw_rect(rect, colour if castable else Color("465359"), false, 4.0 if chosen else 2.0)
		var label := state.spell_label(spell_id)
		var label_font := maxi(9, int(minf(rect.size.x / maxf(1.0, float(label.length())) * 1.7, rect.size.y * 0.36)))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, rect.size.y * 0.5 + float(label_font) * 0.34), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, label_font, colour if castable else Color("5d6a71"))
		# The cost, because Intelligence and the Circle both move it and a price that
		# changes silently is a price the player cannot plan around.
		var cost := "%d" % roundi(state.spell_energy_cost(spell_id))
		var cost_font := maxi(8, int(label_font * 0.72))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(5.0, float(cost_font) + 3.0), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, cost_font, Color(colour, 0.62))

func _handle_spell_press(position: Vector2) -> bool:
	for spell_value in spell_rects:
		var spell_id := String(spell_value)
		if not Rect2(spell_rects[spell_id]).has_point(position): continue
		if spell_id.begins_with("locked:"):
			state.message = "That element is learned from the casters that use it, at level %d." % int(Dictionary(CombatCatalogScript.character_stage_by_id(spell_id.trim_prefix("locked:"))).get("gate", 0))
			queue_redraw()
			return true
		state.select_spell(spell_id)
		# Selecting arms the subclass slot rather than casting, because every spell needs a
		# direction and the board is where directions come from.
		if state.spell_is_available(): selected_action = "advance"
		queue_redraw()
		return true
	return false

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
		subtitle = "DESPERATE" if state.defense_id == "dodge" and state.energy_actions_locked() else "FAST" if available and state.defense_id == "dodge" else "MEDIUM" if available else "COOLING"
	elif name == "skill":
		var art := CombatCatalogScript.weapon_art(state.player_equipped_weapon_art)
		title = String(art.get("label", "ART LOCKED")).to_upper()
		available = not art.is_empty() and state.skill_cooldown <= 0.0001 and not state.energy_actions_locked()
		var art_subtitles := {"prototype_sweeping_cut": "WIDE / MULTI", "prototype_drawing_cut": "NARROW / FORCEFUL", "knife_execution": "UNAWARE / FORCEFUL", "knife_twin_fang": "SIMULTANEOUS / BURST", "bow_piercing_shot": "LINE / PIERCING", "bow_fan_shot": "CONE / THREE ARROWS"}
		subtitle = "EXHAUSTED" if not art.is_empty() and state.energy_actions_locked() else String(art_subtitles.get(state.player_equipped_weapon_art, "WEAPON ART")) if available else "COOLING" if not art.is_empty() else "LEARN THROUGH XP"
	elif name == "rally":
		if state.loadout_id.begins_with("rogue_"):
			# Concealment is cancellable now, so while hidden the control is live and
			# says so. Greying out an active toggle claims the player has no choice,
			# when choosing when to stop paying is the whole point of a per-second drain.
			var stealth_state := state.stealth_status()
			title = "END STEALTH" if stealth_state == "active" else "STEALTH"
			available = stealth_state in ["available", "active"]
			subtitle = "CONCEAL" if stealth_state == "available" else "STEP OUT" if stealth_state == "active" else "NOTICED" if stealth_state == "noticed" else "COOLING" if stealth_state == "cooldown" else "LOCKED"
		elif state.loadout_id == "mage_elementalist":
			title = "CIRCLE"
			available = state.main_ability_cooldown <= 0.0001 and state.is_player_ready() and not state.energy_actions_locked()
			subtitle = "INSIDE" if state.player_is_inside_circle() else "GOOD GROUND" if available else "COOLING"
		else:
			var active := state.rally_active
			title = "END RALLY" if active else "RALLY"
			available = active or state.rally_is_available()
			subtitle = "STAND DOWN" if active else "BOLSTER" if available else "COOLING"
	elif name == "advance" and state.loadout_id == "mage_elementalist":
		title = "SPELLBOOK %s" % ("\u25be" if spellbook_open else "\u25b4")
		available = state.spell_is_available()
		subtitle = "OPEN" if spellbook_open else (state.spell_label(state.selected_spell).to_upper() if state.selected_spell != "" else "CLOSED")
	elif name == "advance":
		title = "VAULT" if state.loadout_id == "rogue_acrobat" else "TAKE AIM" if state.loadout_id == "rogue_sharpshooter" else "ADVANCE"
		available = (state.subclass_ability_cooldown if state.loadout_id.begins_with("rogue_") else state.advance_cooldown) <= 0.0001 and not (state.loadout_id == "warrior" and state.energy_actions_locked())
		subtitle = "EXHAUSTED" if state.loadout_id == "warrior" and state.energy_actions_locked() else ("EVADE / REPOSITION" if state.loadout_id == "rogue_acrobat" else "SELECT TARGET" if state.loadout_id == "rogue_sharpshooter" else "DRIVE FORWARD") if available else "COOLING"
	elif name == "adopted":
		title = "UNDISCOVERED"
		available = false
		subtitle = "LATE DISCIPLINE"
	elif name == "wait":
		title = state.interaction_label()
		subtitle = "REST AT WAYSTONE" if title == "REST" else "OPEN SHORTCUT" if title == "UNLOCK" else "USE PASSAGE" if title == "TRAVERSE" else "+0.5s"
		available = not state.trial_complete
	var color := Color("6ec4e8") if name == "defense" and state.defense_id == "block" else Color("ee6645") if name == "defense" and state.defense_id == "endure" else DODGE_COLOR if name == "defense" else Color("e8c35d") if name == "skill" else Color("e47754") if name == "rally" else Color("7ac6e8") if name == "advance" else Color("d7aa58") if name == "wait" else Color("718087")
	draw_rect(rect, Color("15232a") if available else Color("11191d"))
	draw_rect(rect, color if available else Color("465359"), false, 4.0 if selected_action == name else 2.0)
	var stealth_without_cooldown := name == "rally" and state.loadout_id.begins_with("rogue_") and state.stealth_status() != "cooldown"
	if not available and name in ["defense", "skill", "rally", "advance"] and not (name == "rally" and (state.rally_active or state.stealth_remaining > 0.0001)) and not stealth_without_cooldown:
		var energy_locked := state.energy_actions_locked() and (name == "skill" or (name == "advance" and state.loadout_id == "warrior"))
		var remaining := state.player_exhaustion_remaining if energy_locked else _defense_cooldown() if name == "defense" else state.skill_cooldown if name == "skill" else (state.main_ability_cooldown if state.loadout_id.begins_with("rogue_") else state.rally_cooldown) if name == "rally" else (state.subclass_ability_cooldown if state.loadout_id.begins_with("rogue_") else state.advance_cooldown)
		var defense_maximum := state.BLOCK_COOLDOWN if state.defense_id == "block" else state.ENDURE_COOLDOWN if state.defense_id == "endure" else state.DODGE_COOLDOWN
		# Cooldowns are derived from energy now, so a literal maximum here would be
		# wrong the moment an ability is repriced -- Sweeping Cut alone runs to 13.4s
		# against the 6.5 this used to assume, which would draw the bar full from the
		# first frame. Each cooldown records what it started at instead.
		var maximum: float = float(state.EXHAUSTION_DURATION if energy_locked else defense_maximum if name == "defense" else state.skill_cooldown_max if name == "skill" else (state.main_ability_cooldown_max if state.loadout_id.begins_with("rogue_") else state.rally_cooldown_max) if name == "rally" else (state.subclass_ability_cooldown_max if state.loadout_id.begins_with("rogue_") else state.advance_cooldown_max))
		var ready_ratio := 1.0 - clampf(remaining / maximum, 0.0, 1.0)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 5.0), Vector2(rect.size.x * ready_ratio, 5.0)), color)
	var title_font := maxi(12, int(minf(rect.size.x, rect.size.y) * 0.21))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.46), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, title_font, Color("f0ece0") if available else Color("68777c"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.72), subtitle, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(9, int(title_font * 0.6)), color if available else Color("59666b"))
	if desktop_controls:
		var shortcuts := {"defense": "[2 / B]", "skill": "[3 / Q]", "rally": "[4]", "advance": "[5 / E]", "adopted": "[6]", "wait": "[SPACE]"}
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.91), String(shortcuts[name]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(8, int(title_font * 0.48)), Color("718087"))

# Laid out against the whole safe area rather than the setup column, because the point of
# the overlay is the room the panel does not have.
# Two pages. The room page shows what has been chosen and lets it be edited; the kind
# page is a full screen of enemies, which is what it needs to be readable rather than
# twenty-one chips squeezed in beside the formation, health and XP rows.
func _layout_custom_room_panel() -> void:
	custom_kind_rects.clear()
	custom_formation_rects.clear()
	custom_hp_rects.clear()
	custom_level_rects.clear()
	custom_slot_rects.clear()
	custom_remove_rects.clear()
	custom_add_rect = Rect2()
	if not custom_room_open:
		custom_panel_rect = Rect2()
		return
	var inset := 16.0
	custom_panel_rect = Rect2(safe_layout_rect.position + Vector2(inset, inset), safe_layout_rect.size - Vector2(inset, inset) * 2.0)
	var pad := 12.0
	var left := custom_panel_rect.position.x + pad
	var width := custom_panel_rect.size.x - pad * 2.0
	var row_h := clampf(custom_panel_rect.size.y * 0.058, 38.0, 50.0)
	var y := custom_panel_rect.position.y + 58.0
	if custom_page == "kind":
		var kinds := _custom_room_kind_list()
		var columns := 2 if custom_panel_rect.size.x < 520.0 else 3
		var chip_w := (width - float(columns - 1) * 6.0) / float(columns)
		for index in range(kinds.size()):
			custom_kind_rects[String(kinds[index])] = Rect2(left + float(index % columns) * (chip_w + 6.0), y + float(index / columns) * (row_h + 6.0), chip_w, row_h)
		custom_done_rect = Rect2(left, custom_panel_rect.end.y - 60.0, width, 48.0)
		custom_clear_rect = Rect2()
		return
	# Room page: one row per chosen body, each with its own remove control, then the add
	# button, then the room's other settings.
	for index in range(custom_room_roster.size()):
		var slot := Rect2(left, y, width, row_h)
		custom_slot_rects[index] = Rect2(slot.position, Vector2(slot.size.x - 96.0, slot.size.y))
		custom_remove_rects[index] = Rect2(slot.end.x - 92.0, slot.position.y, 92.0, slot.size.y)
		y += row_h + 6.0
	if custom_room_roster.size() < 6:
		custom_add_rect = Rect2(left, y, width, row_h)
		y += row_h + 14.0
	else:
		y += 8.0
	var formations := _custom_room_formation_list()
	var fcols := 4
	var fw := (width - 18.0) / float(fcols)
	for index in range(formations.size()):
		custom_formation_rects[String(formations[index])] = Rect2(left + float(index % fcols) * (fw + 6.0), y + float(index / fcols) * (row_h + 6.0), fw, row_h)
	y += float(ceili(float(formations.size()) / float(fcols))) * (row_h + 6.0) + 14.0
	var qw := (width - 18.0) / 4.0
	for index in range(4):
		custom_hp_rects[[25, 50, 75, 100][index]] = Rect2(left + float(index) * (qw + 6.0), y, qw, row_h)
	y += row_h + 8.0
	var step_w := minf(qw, 96.0)
	custom_level_rects["down"] = Rect2(left, y, step_w, row_h)
	custom_level_rects["up"] = Rect2(left + width - step_w, y, step_w, row_h)
	var half := (width - 8.0) * 0.5
	custom_repeat_rect = Rect2(left, custom_panel_rect.end.y - 118.0, width, 46.0)
	custom_start_rect = Rect2(left, custom_panel_rect.end.y - 60.0, half, 48.0)
	custom_clear_rect = Rect2()
	custom_done_rect = Rect2(left + half + 8.0, custom_panel_rect.end.y - 60.0, half, 48.0)
# A custom room is on when one has been composed. There is no separate mode flag to fall
# out of step with the roster.
func _custom_section_active() -> bool:
	return setup_mode == "combat_survey" and not custom_room_roster.is_empty()

func _custom_room_kind_list() -> Array[String]:
	var kinds: Array[String] = []
	kinds.append(state.CUSTOM_RANDOM)
	kinds.append(state.CUSTOM_RANDOM_NEW)
	for kind in CombatCatalogScript.enemy_kinds():
		if String(kind) in ["warden", "werewolf"]: continue
		kinds.append(String(kind))
	return kinds

func _custom_room_formation_list() -> Array[String]:
	var ids: Array[String] = [""]
	for template in state._survey_formation_catalog(): ids.append(String(Dictionary(template)["id"]))
	return ids

func _custom_room_total() -> int:
	return custom_room_roster.size()
func _custom_room_label(kind: String) -> String:
	if kind == state.CUSTOM_RANDOM: return "RANDOM"
	if kind == state.CUSTOM_RANDOM_NEW: return "RANDOM NEW"
	return kind.replace("_", " ").to_upper()

func _draw_custom_room_panel() -> void:
	draw_rect(custom_panel_rect, Color(0.02, 0.05, 0.06, 0.97))
	draw_rect(custom_panel_rect, Color("c9a3e6"), false, 2.0)
	var picked := custom_room_roster.size()
	if custom_page == "kind":
		var title := "CHOOSE AN ENEMY" if custom_editing_slot < 0 else "REPLACE SLOT %d" % (custom_editing_slot + 1)
		draw_string(ThemeDB.fallback_font, custom_panel_rect.position + Vector2(14, 30), title, HORIZONTAL_ALIGNMENT_LEFT, custom_panel_rect.size.x - 28, 18, Color("eef0e9"))
		draw_string(ThemeDB.fallback_font, custom_panel_rect.position + Vector2(14, 48), "RANDOM RE-ROLLS EACH ROOM · RANDOM NEW PICKS ONE NOT YET USED", HORIZONTAL_ALIGNMENT_LEFT, custom_panel_rect.size.x - 28, 11, Color("9fb2b7"))
		for kind in custom_kind_rects:
			var rect := Rect2(custom_kind_rects[kind])
			draw_rect(rect, Color("142025"))
			draw_rect(rect, Color("3b494f"), false, 2.0)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.64), _custom_room_label(String(kind)), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color("eef0e9"))
		draw_rect(custom_done_rect, Color("17272d"))
		draw_rect(custom_done_rect, Color("718087"), false, 2.0)
		draw_string(ThemeDB.fallback_font, custom_done_rect.position + Vector2(0, custom_done_rect.size.y * 0.64), "BACK", HORIZONTAL_ALIGNMENT_CENTER, custom_done_rect.size.x, 14, Color("d7dddd"))
		return
	draw_string(ThemeDB.fallback_font, custom_panel_rect.position + Vector2(14, 30), "CUSTOM ROOM", HORIZONTAL_ALIGNMENT_LEFT, custom_panel_rect.size.x - 28, 18, Color("eef0e9"))
	draw_string(ThemeDB.fallback_font, custom_panel_rect.position + Vector2(-14, 30), "%d / 6" % picked, HORIZONTAL_ALIGNMENT_RIGHT, custom_panel_rect.size.x, 16, Color("c9a3e6") if picked > 0 else Color("8b9aa0"))
	draw_string(ThemeDB.fallback_font, custom_panel_rect.position + Vector2(14, 48), "TAP A NAME TO REPLACE IT · REMOVE TAKES IT OUT", HORIZONTAL_ALIGNMENT_LEFT, custom_panel_rect.size.x - 28, 11, Color("9fb2b7"))
	for index in custom_slot_rects:
		var rect := Rect2(custom_slot_rects[index])
		draw_rect(rect, Color("1d3038"))
		draw_rect(rect, Color("c9a3e6"), false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, rect.size.y * 0.64), "%d.  %s" % [int(index) + 1, _custom_room_label(String(custom_room_roster[int(index)]))], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 13, Color("eef0e9"))
		var remove := Rect2(custom_remove_rects[index])
		draw_rect(remove, Color("2a1a1c"))
		draw_rect(remove, Color("ee6645"), false, 2.0)
		draw_string(ThemeDB.fallback_font, remove.position + Vector2(0, remove.size.y * 0.64), "REMOVE", HORIZONTAL_ALIGNMENT_CENTER, remove.size.x, 12, Color("ee6645"))
	if custom_add_rect.size.x > 0.0:
		draw_rect(custom_add_rect, Color("142025"))
		draw_rect(custom_add_rect, Color("58d2cf"), false, 2.0)
		draw_string(ThemeDB.fallback_font, custom_add_rect.position + Vector2(0, custom_add_rect.size.y * 0.64), "+  ADD ENEMY", HORIZONTAL_ALIGNMENT_CENTER, custom_add_rect.size.x, 14, Color("58d2cf"))
	for formation in custom_formation_rects:
		var rect := Rect2(custom_formation_rects[formation])
		var selected := custom_room_formation == String(formation)
		draw_rect(rect, Color("1d3038") if selected else Color("142025"))
		draw_rect(rect, Color("58d2cf") if selected else Color("3b494f"), false, 2.0)
		var label := "ANY" if String(formation).is_empty() else String(formation).replace("_", " ").to_upper()
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.64), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, Color("eef0e9") if selected else Color("8b9aa0"))
	for percent in custom_hp_rects:
		var rect := Rect2(custom_hp_rects[percent])
		var selected := absf(custom_room_hp - float(percent) / 100.0) < 0.01
		draw_rect(rect, Color("1d3038") if selected else Color("142025"))
		draw_rect(rect, Color("ee6645") if selected else Color("3b494f"), false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.64), "HP %d%%" % int(percent), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color("eef0e9") if selected else Color("8b9aa0"))
	for direction in custom_level_rects:
		var rect := Rect2(custom_level_rects[direction])
		var at_end := custom_room_level <= 1 if String(direction) == "down" else custom_room_level >= 15
		draw_rect(rect, Color("142025"))
		draw_rect(rect, Color("3b494f") if at_end else Color("d7aa58"), false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.66), "−" if String(direction) == "down" else "+", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 20, Color("55636a") if at_end else Color("d7aa58"))
	if custom_level_rects.has("down"):
		var span := Rect2(Rect2(custom_level_rects["down"]).end.x, Rect2(custom_level_rects["down"]).position.y, Rect2(custom_level_rects["up"]).position.x - Rect2(custom_level_rects["down"]).end.x, Rect2(custom_level_rects["down"]).size.y)
		# The XP is shown small beneath the level, because the sheet spends XP and it is
		# useful to know how much a level actually bought.
		draw_string(ThemeDB.fallback_font, span.position + Vector2(0, span.size.y * 0.54), "LEVEL %d" % custom_room_level, HORIZONTAL_ALIGNMENT_CENTER, span.size.x, 15, Color("eef0e9"))
		draw_string(ThemeDB.fallback_font, span.position + Vector2(0, span.size.y * 0.88), "%d XP · %d UPGRADES" % [RunStateScript.xp_for_character_level(custom_room_level), custom_room_level - 1], HORIZONTAL_ALIGNMENT_CENTER, span.size.x, 10, Color("9fb2b7"))
	# Repeat, then start. The room you just composed is the room you want to play, so the
	# panel finishes the job rather than sending you back out to a Start button elsewhere.
	draw_rect(custom_repeat_rect, Color("17272d"))
	draw_rect(custom_repeat_rect, Color("c9a3e6") if custom_room_repeat else Color("45545a"), false, 2.0)
	draw_string(ThemeDB.fallback_font, custom_repeat_rect.position + Vector2(0, custom_repeat_rect.size.y * 0.42), "REPEAT · %s" % ("ON" if custom_room_repeat else "OFF"), HORIZONTAL_ALIGNMENT_CENTER, custom_repeat_rect.size.x, 14, Color("eef0e9") if custom_room_repeat else Color("9fb2b7"))
	draw_string(ThemeDB.fallback_font, custom_repeat_rect.position + Vector2(0, custom_repeat_rect.size.y * 0.80), "ROOM AFTER ROOM" if custom_room_repeat else "ONE ROOM, THEN THE END SCREEN", HORIZONTAL_ALIGNMENT_CENTER, custom_repeat_rect.size.x, 10, Color("9fb2b7"))
	var can_start := not custom_room_roster.is_empty()
	draw_rect(custom_start_rect, Color("17272d"))
	draw_rect(custom_start_rect, Color("6be3c6") if can_start else Color("45545a"), false, 2.0)
	draw_string(ThemeDB.fallback_font, custom_start_rect.position + Vector2(0, custom_start_rect.size.y * 0.64), "START", HORIZONTAL_ALIGNMENT_CENTER, custom_start_rect.size.x, 15, Color("eef0e9") if can_start else Color("5d6a71"))
	draw_rect(custom_done_rect, Color("24433f"))
	draw_rect(custom_done_rect, Color("58d2cf"), false, 2.0)
	draw_string(ThemeDB.fallback_font, custom_done_rect.position + Vector2(0, custom_done_rect.size.y * 0.64), "BACK", HORIZONTAL_ALIGNMENT_CENTER, custom_done_rect.size.x, 14, Color("eef0e9"))
# Burn and frost have to be visible or they are the Captain's x1.14 aura again -- an
# effect the player feels the consequences of and cannot see the cause of, which 0.2.33
# deleted for exactly that reason. Charge is drawn faint, the lit condition solid, so the
# meter reads as "building" then "burning" rather than as one ambiguous bar.
func _draw_condition_meters(area: Rect2) -> void:
	if area.size.y < 6.0: return
	var rows := [
		{"charge": state.player_condition_charge("burning"), "active": state.player_burn_fraction(), "color": Color("ee6645"), "label": "BURNING"},
		{"charge": state.player_condition_charge("frost"), "active": state.player_frost_fraction(), "color": Color("70bddd"), "label": "FROST"},
	]
	var visible_rows: Array = []
	for row in rows:
		if float(Dictionary(row)["charge"]) > 0.01 or float(Dictionary(row)["active"]) > 0.01: visible_rows.append(row)
	if visible_rows.is_empty(): return
	var height := area.size.y / float(visible_rows.size())
	for index in range(visible_rows.size()):
		var row := Dictionary(visible_rows[index])
		var rect := Rect2(area.position + Vector2(0.0, float(index) * height), Vector2(area.size.x, height - 2.0))
		var tint: Color = row["color"]
		draw_rect(rect, Color(tint.r * 0.16, tint.g * 0.16, tint.b * 0.16))
		var charge := float(row["charge"])
		if charge > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * charge, rect.size.y)), Color(tint.r, tint.g, tint.b, 0.34))
		var active := float(row["active"])
		if active > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * active, rect.size.y)), tint)
		draw_rect(rect, tint, false, 1.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, rect.size.y * 0.80), String(row["label"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(9, int(rect.size.y * 0.72)), Color("f4f7f7"))

func _draw_consumable(slot_id: String, rect: Rect2) -> void:
	var title := "REJUVENATE" if slot_id == "healing" else "—"
	var subtitle := "%d / %d" % [state.potions, state.healing_capacity()] if slot_id == "healing" else "EMPTY"
	var color := Color("db6463") if slot_id == "healing" else Color("718087")
	var available := (state.has_infinite_potions() or state.potions > 0) and state.player_hp < state.player_max_hp if slot_id == "healing" else false
	var selected := false
	if slot_id != "healing":
		var slot := int(slot_id.trim_prefix("slot_"))
		var stored := state.consumable_slot(slot)
		var item_id := String(stored.get("id", ""))
		if not item_id.is_empty():
			var definition := state.consumable_definition(item_id)
			title = String(definition.get("short", item_id)).to_upper()
			subtitle = "%d" % int(stored.get("count", 0))
			color = Color(String(definition.get("color", "d7dddd")))
			available = int(stored.get("count", 0)) > 0
		selected = selected_action == "consumable_%d" % slot
	draw_rect(rect, Color("3a3028") if state.has_pending_pickup() and slot_id != "healing" else Color("15232a") if available else Color("11191d"))
	draw_rect(rect, Color("f0c66b") if state.has_pending_pickup() and slot_id != "healing" else color if available else Color("465359"), false, 4.0 if selected else 2.0)
	var title_font := maxi(9, int(minf(rect.size.x, rect.size.y) * 0.21))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, rect.size.y * 0.43), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, title_font, Color("f0ece0") if available else Color("68777c"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, rect.size.y * 0.72), subtitle, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(8, int(title_font * 0.72)), color if available else Color("59666b"))
	if desktop_controls:
		var key_label := "[1 / P]" if slot_id == "healing" else "[%d]" % (7 + int(slot_id.trim_prefix("slot_")))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.91), key_label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(7, int(title_font * 0.55)), Color("718087"))

func _draw_waystone_menu() -> void:
	var definitions := {"learn": ["LEVEL UP", "OPEN CHARACTER SHEET"], "continue": ["CONTINUE", "RETURN TO THE WORLD"]}
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
		if not state.enemy_visible_to_player(enemy): continue
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

func _project_world_delta(world_delta: Vector2) -> Vector2:
	if view_mode == "isometric": return Vector2((world_delta.x - world_delta.y) * 0.5, (world_delta.x + world_delta.y) * 0.25) * world_scale
	return world_delta * world_scale

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
	state.record_survey_view_mode(view_mode, true)
	selected_action = ""
	pointer_down = false
	held_movement = false
	held_movement_tracks_pointer = false
	_update_projection()
	reset_rect.position = board_rect.end - reset_rect.size - Vector2(8.0, board_rect.size.y - reset_rect.size.y - 8.0)
	view_rect.position = reset_rect.position - Vector2(view_rect.size.x + 8.0, 0.0)
	map_rect.position = view_rect.position - Vector2(map_rect.size.x + 8.0, 0.0)
	queue_redraw()
