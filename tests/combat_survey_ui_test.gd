extends SceneTree

func _initialize() -> void:
	var board = load("res://scenes/main.tscn").instantiate()
	root.add_child(board)
	await process_frame
	board.state.start_run("rogue_acrobat", "combat_survey", 919191, "encounter")
	board.visual = board.state.snapshot(true)
	board._sync_setup_controls()

	# --- the custom room picker -------------------------------------------------------
	# Built so a new enemy can be judged the moment it exists rather than waited for. The
	# Chanter sat unplayed from 0.2.33 to 0.2.39 because nothing ever drew it, and its
	# first appearance was a room it died three seconds into.
	board.setup_mode = "combat_survey"
	board.setup_stage = "options"
	board.setup_dev_section = "custom"
	board._layout()
	# The root screen offers three buttons and nothing else. Every control that used to
	# share it with them is what made taps land on the wrong thing.
	var options_class_rect: Rect2 = board._setup_class_rect("warrior")
	assert(options_class_rect.size.y > 0.0)
	for other in [board.dev_section_rects["survey"], board.survey_profile_rects["encounter"], board.combat_rule_rects["recovery"]]:
		assert(not options_class_rect.intersects(Rect2(other)))
	# The first version of this button was laid out on top of the seed field, which is a
	# real LineEdit node and draws over anything the canvas paints beneath it -- so the
	# control existed, worked, and was invisible. Overlap is the assertion, not presence.
	assert(board.custom_open_rect.size.x > 0.0)
	assert(not board.custom_open_rect.intersects(Rect2(board.seed_input.position, board.seed_input.size)))
	assert(not board.custom_open_rect.intersects(board.start_rect))
	assert(board.dev_section_rects.has("survey") and board.dev_section_rects.has("custom"))
	# Two extra rows can push the start button off the bottom, which would make Dev
	# unstartable rather than merely ugly.
	assert(board.start_rect.end.y <= board.safe_layout_rect.end.y + 1.0)
	board.custom_room_open = true
	board._layout()
	board._sync_setup_controls()
	# The seed field is a node and paints over the canvas, so the picker is only actually
	# on top if the field is hidden while it is up.
	assert(not board.seed_input.visible)
	assert(board.custom_kind_rects.has("ox"))
	assert(board.custom_formation_rects.has("retinue"))
	var ox_rect: Rect2 = board.custom_kind_rects["ox"]
	for expected in [1, 2, 3, 0]:
		board._handle_custom_room_press(ox_rect.get_center())
		assert(int(board.custom_room_counts.get("ox", 0)) == expected)
	# A tap always changes something. The cap used to freeze every chip below three once
	# six bodies were picked, so a full room could not be emptied -- "chosen enemies can't
	# be de-selected by tapping them again".
	board.custom_room_counts.clear()
	for kind in ["ox", "polearm", "hound", "blade", "knife", "boar"]:
		board._handle_custom_room_press(Rect2(board.custom_kind_rects[kind]).get_center())
	assert(board._custom_room_total() == 6)
	board._handle_custom_room_press(Rect2(board.custom_kind_rects["ox"]).get_center())
	assert(not board.custom_room_counts.has("ox"))
	assert(board._custom_room_total() == 5)
	board.custom_room_counts.clear()
	# Six bodies is the ceiling: the largest formation seats six, and a seventh would
	# stand outside the arrangement under test.
	for kind in ["ox", "polearm", "hound", "blade", "knife", "boar", "bandit"]:
		if board.custom_kind_rects.has(kind):
			board._handle_custom_room_press(Rect2(board.custom_kind_rects[kind]).get_center())
	assert(board._custom_room_total() <= 6)
	board._handle_custom_room_press(Rect2(board.custom_formation_rects["retinue"]).get_center())
	board._handle_custom_room_press(Rect2(board.custom_hp_rects[25]).get_center())
	board._handle_custom_room_press(Rect2(board.custom_xp_rects[400]).get_center())
	assert(board.custom_room_formation == "retinue")
	assert(absf(board.custom_room_hp - 0.25) < 0.01)
	assert(board.custom_room_xp == 400)
	board._handle_custom_room_press(Rect2(board.custom_done_rect).get_center())
	assert(not board.custom_room_open)
	board._start_run()
	assert(board.state._custom_room_active())
	assert(String(board.state.survey_room_definition.get("formation", "")) == "retinue")
	assert(bool(board.state.survey_room_definition.get("custom_room", false)))
	assert(board.state.player_hp <= roundi(float(board.state.player_max_hp) * 0.3))
	assert(board.state.carried_xp >= 400)
	board.setup_stage = "root"
	board.setup_dev_section = "survey"
	board.custom_room_counts.clear()
	board.custom_room_formation = ""
	board.custom_room_hp = 1.0
	board.custom_room_xp = 0

	board.state.start_run("rogue_acrobat", "combat_survey", 919191, "encounter")
	board.visual = board.state.snapshot(true)
	board._sync_setup_controls()
	assert(board.state.survey_room_number == 1)
	assert(not board.survey_overlay.visible)
	for enemy in board.state.enemies: enemy["hp"] = 0
	board.state._remove_dead_enemies()
	board._sync_survey_overlay()
	assert(board.survey_overlay.visible)
	assert(board.survey_overlay.get_meta("kind", "") == "feedback")
	assert(board.survey_rating_buttons.size() == 4)
	assert(board.survey_skip_button != null)
	board._survey_rating_pressed("difficulty", 3)
	board._survey_rating_pressed("fun", 4)
	board._survey_rating_pressed("tactical_interest", 5)
	board._survey_rating_pressed("want_again", 4)
	assert(not board.survey_submit_button.disabled)
	assert(board.survey_notes.virtual_keyboard_enabled)
	assert(board.survey_notes.get_theme_font_size("font_size") >= 19)
	var selected_button: Button = board.survey_rating_buttons["want_again"][3]
	assert(selected_button.get_theme_color("font_pressed_color").get_luminance() > 0.9)
	board._submit_survey_feedback()
	assert(board.state.survey_room_number == 2)
	assert(not board.state.survey_feedback_pending)
	board._build_survey_end_confirmation()
	assert(board.survey_overlay.visible)
	assert(board.survey_overlay.get_meta("kind", "") == "end_confirm")
	assert(not board.state.survey_feedback_pending)
	board._cancel_survey_end_confirmation()
	assert(not board.survey_overlay.visible)
	board._build_survey_end_confirmation()
	board._confirm_survey_end_run()
	assert(board.state.survey_feedback_pending)
	assert(board.survey_overlay.get_meta("kind", "") == "feedback")
	board._skip_survey_feedback()
	assert(board.state.trial_complete)
	assert(bool(Dictionary(Array(board.state.survey_session["rooms"])[-1]).get("subjective_skipped", false)))
	board.survey_export_status = "EXPORTED — test report"
	board._build_survey_archive_overlay()
	assert(board.survey_export_status_label != null)
	assert(board.survey_export_status_label.visible)
	assert(board.survey_export_status_label.text == "EXPORTED — test report")
	print("COMBAT SURVEY setup and questionnaire UI: PASS")
	quit(0)
