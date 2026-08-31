extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _initialize() -> void:
	var board = load("res://scenes/main.tscn").instantiate()
	root.add_child(board)
	await process_frame
	board.state.start_run("rogue_acrobat", "combat_survey", 919191, "encounter")
	board.visual = board.state.snapshot(true)
	board._sync_setup_controls()

	# --- the Elementalist spellbook drawer ---------------------------------------------
	board.state.start_run("mage_elementalist", "combat_survey", 4242, "encounter", "energy")
	board.spellbook_open = true
	board.visual = board.state.snapshot(true)
	board._layout()
	# Chips are the same authored height as the action buttons beside them. The action row
	# used to absorb whatever space was left over, so adding a spell row squeezed the
	# buttons and the spells ended up larger than the skills.
	var bolt_rect: Rect2 = Rect2(board.spell_rects["lightning_bolt"])
	var action_rect: Rect2 = Rect2(board.buttons["advance"])
	assert(is_equal_approx(bolt_rect.size.y, action_rect.size.y))
	assert(board.spellbook_panel.size.x > 0.0)
	# The drawer takes real space: closing it moves everything above it down.
	var belt_open: float = Rect2(board.consumable_rects["healing"]).position.y
	var action_open: float = action_rect.position.y
	board.spellbook_open = false
	board._layout()
	assert(board.spellbook_panel.size.x <= 0.0)
	assert(board.spell_rects.is_empty())
	assert(Rect2(board.consumable_rects["healing"]).position.y > belt_open)
	# ...and the action row itself does not move, because it is anchored to the bottom.
	assert(is_equal_approx(Rect2(board.buttons["advance"]).position.y, action_open))
	board.spellbook_open = true
	board._layout()

	# Learning an element mid-run must reach the drawer. The rects are built in _layout(),
	# and _on_state_changed only queued a redraw -- so a spell that was bought and owned had
	# no rect to be drawn or tapped in, and its locked slot stayed on screen. The element
	# was unreachable for the rest of the run.
	assert(board.spell_rects.has("locked:element_fire"))
	assert(not board.spell_rects.has("fireball"))
	board.state._apply_character_stage("element_fire", "fireball")
	board._on_state_changed()
	assert(board.spell_rects.has("fireball"))
	assert(not board.spell_rects.has("locked:element_fire"))
	assert(board.spell_rects.has("locked:element_ice"))
	board.state.start_run("rogue_acrobat", "combat_survey", 919191, "encounter")
	board.visual = board.state.snapshot(true)
	board._layout()
	assert(board.spell_rects.is_empty())

	# --- the custom room picker -------------------------------------------------------
	# Built so a new enemy can be judged the moment it exists rather than waited for. The
	# Chanter sat unplayed from 0.2.33 to 0.2.39 because nothing ever drew it.
	#
	# The room is a list of slots, not a tally per kind. Counting made duplicates a number
	# to cycle through and removal an afterthought -- undoing one mis-tap cost three more
	# taps, and three-to-two was impossible.
	board.setup_mode = "combat_survey"
	board.setup_stage = "options"
	board.setup_dev_section = "custom"
	board._layout()
	assert(board.custom_open_rect.size.x > 0.0)
	assert(not board.custom_open_rect.intersects(Rect2(board.seed_input.position, board.seed_input.size)))
	assert(not board.custom_open_rect.intersects(board.start_rect))
	assert(board.dev_section_rects.has("survey") and board.dev_section_rects.has("custom"))
	assert(board.start_rect.end.y <= board.safe_layout_rect.end.y + 1.0)
	var options_class_rect: Rect2 = board._setup_class_rect("warrior")
	assert(options_class_rect.size.y > 0.0)
	for other in [board.dev_section_rects["survey"], board.survey_profile_rects["encounter"], board.combat_rule_rects["recovery"]]:
		assert(not options_class_rect.intersects(Rect2(other)))

	board.custom_room_open = true
	board.custom_page = "room"
	board._layout()
	board._sync_setup_controls()
	assert(not board.seed_input.visible)

	# Add opens the kind page; choosing appends.
	assert(board.custom_add_rect.size.x > 0.0)
	board._handle_custom_room_press(board.custom_add_rect.get_center())
	assert(board.custom_page == "kind")
	board._handle_custom_room_press(Rect2(board.custom_kind_rects["ox"]).get_center())
	assert(board.custom_page == "room")
	assert(String(board.custom_room_roster[0]) == "ox")
	assert(board.custom_room_roster.size() == 1)

	# Tapping a filled slot reopens the list and replaces that slot rather than appending.
	board._handle_custom_room_press(Rect2(board.custom_slot_rects[0]).get_center())
	assert(board.custom_page == "kind")
	assert(board.custom_editing_slot == 0)
	board._handle_custom_room_press(Rect2(board.custom_kind_rects["polearm"]).get_center())
	assert(board.custom_room_roster.size() == 1)
	assert(String(board.custom_room_roster[0]) == "polearm")

	# Remove is one visible tap, at any size of room.
	for kind in ["hound", "blade"]:
		board._handle_custom_room_press(board.custom_add_rect.get_center())
		board._handle_custom_room_press(Rect2(board.custom_kind_rects[kind]).get_center())
	assert(board.custom_room_roster.size() == 3)
	board._handle_custom_room_press(Rect2(board.custom_remove_rects[1]).get_center())
	assert(board.custom_room_roster.size() == 2)
	assert(String(board.custom_room_roster[0]) == "polearm" and String(board.custom_room_roster[1]) == "blade")

	# Duplicates are separate slots rather than a count.
	for _copy in range(2):
		board._handle_custom_room_press(board.custom_add_rect.get_center())
		board._handle_custom_room_press(Rect2(board.custom_kind_rects["hound"]).get_center())
	assert(board.custom_room_roster.size() == 4)

	# Six is the ceiling, and the add button disappears rather than failing silently.
	for _copy in range(2):
		board._handle_custom_room_press(board.custom_add_rect.get_center())
		board._handle_custom_room_press(Rect2(board.custom_kind_rects["knife"]).get_center())
	assert(board.custom_room_roster.size() == 6)
	assert(board.custom_add_rect.size.x <= 0.0)

	board._handle_custom_room_press(Rect2(board.custom_formation_rects["retinue"]).get_center())
	board._handle_custom_room_press(Rect2(board.custom_hp_rects[25]).get_center())
	# A level, not an XP total, and a stepper rather than four arbitrary presets.
	for _step in range(3): board._handle_custom_room_press(Rect2(board.custom_level_rects["up"]).get_center())
	assert(board.custom_room_level == 4)
	board._handle_custom_room_press(Rect2(board.custom_level_rects["down"]).get_center())
	assert(board.custom_room_level == 3)
	# It cannot step below a fresh character.
	for _step in range(6): board._handle_custom_room_press(Rect2(board.custom_level_rects["down"]).get_center())
	assert(board.custom_room_level == 1)
	for _step in range(3): board._handle_custom_room_press(Rect2(board.custom_level_rects["up"]).get_center())
	assert(board.custom_room_formation == "retinue")
	assert(absf(board.custom_room_hp - 0.25) < 0.01)
	# Level 4 is three upgrades: 6 + 10 + 14 by the cost curve.
	assert(RunStateScript.xp_for_character_level(4) == 30)
	assert(RunStateScript.xp_for_character_level(1) == 0)
	board._handle_custom_room_press(Rect2(board.custom_done_rect).get_center())
	assert(not board.custom_room_open)
	board._start_run()
	assert(board.state._custom_room_active())
	assert(String(board.state.survey_room_definition.get("formation", "")) == "retinue")
	assert(bool(board.state.survey_room_definition.get("custom_room", false)))
	assert(board.state.player_hp <= roundi(float(board.state.player_max_hp) * 0.3))
	assert(board.state.carried_xp == RunStateScript.xp_for_character_level(4))
	board.setup_stage = "root"
	board.setup_dev_section = "survey"
	board.custom_room_roster.clear()
	board.custom_room_formation = ""
	board.custom_room_hp = 1.0
	board.custom_room_level = 1

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
