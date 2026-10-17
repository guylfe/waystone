extends RefCounted
## Native gamepad intent adapter. Owns no combat rules and never synthesizes mouse
## events. Custom-drawn menus share their existing activation handlers; combat goes
## directly through the same RunState requests used by the other input adapters.

class WindowRelay extends Node:
	var board: Control
	func _input(event: InputEvent) -> void:
		board._controller_event(event)

const DEADZONE := 0.24
const TRIGGER_PRESS := 0.55
const TRIGGER_RELEASE := 0.25
var active := false
var device := -1
var axes: Dictionary = {}
var held: Dictionary = {}
var neutral_required := false
var attack_held := false
var paused := false
var palette_open := false
var quick_action := "subclass"
var utility_slot := 0
var aim := Vector2.ZERO
var aim_distance := 340.0
var target_id := -1
var focus_index := 0
var last_context := ""
var navigation_direction := 0
var navigation_remaining := 0.0
var pending_button := -1
var pending_seconds := 0.0
var abandon_confirm := false

func stick(x: int, y: int) -> Vector2:
	var value := Vector2(float(axes.get(x, 0.0)), float(axes.get(y, 0.0)))
	return value.limit_length() if value.length() > DEADZONE else Vector2.ZERO

func move_direction(board) -> Vector2:
	if not active or neutral_required or modal(board): return Vector2.ZERO
	return board._screen_delta_to_world_direction(stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y))

func direction(board, movement_first: bool = false) -> Vector2:
	var movement := move_direction(board)
	if movement_first and not movement.is_zero_approx(): return movement
	var target := locked_target(board)
	if not target.is_empty(): return board.state.player_pos.direction_to(Vector2(target["pos"]))
	if not aim.is_zero_approx(): return aim
	if not movement.is_zero_approx(): return movement
	return board.state.player_facing

func locked_target(board) -> Dictionary:
	if target_id < 0: return {}
	for enemy in board.state.enemies:
		if int(enemy.get("id", -1)) == target_id and String(enemy["layer"]) == board.state.current_layer and int(enemy.get("hp", 0)) > 0 and board.state.enemy_visible_to_player(enemy) and board.state.is_visible(Vector2(enemy["pos"])):
			return enemy
	target_id = -1
	return {}

func cycle_target(board) -> void:
	var candidates: Array = []
	for enemy in board.state.enemies:
		if String(enemy["layer"]) == board.state.current_layer and int(enemy.get("hp", 0)) > 0 and board.state.enemy_visible_to_player(enemy) and board.state.is_visible(Vector2(enemy["pos"])):
			candidates.append(enemy)
	candidates.sort_custom(func(a, b): return board.state.player_pos.distance_squared_to(a["pos"]) < board.state.player_pos.distance_squared_to(b["pos"]))
	var index := -1
	for i in candidates.size():
		if int(candidates[i]["id"]) == target_id: index = i
	target_id = int(candidates[index + 1]["id"]) if index + 1 < candidates.size() else -1

func modal(board) -> bool:
	return paused or palette_open or not board.state.run_active or board.character_sheet_open or board.waystone_menu_open or board.map_open or board.state.death_pending or board.state.trial_complete or board.state.survey_feedback_pending or native_panel(board) != null

func native_panel(board) -> Node:
	if is_instance_valid(board.expedition_dialog) and board.expedition_dialog.visible: return board.expedition_dialog
	if is_instance_valid(board.survey_overlay) and board.survey_overlay.visible: return board.survey_overlay
	return null

func release_actions(board) -> void:
	attack_held = false
	pending_button = -1
	neutral_required = true
	if board.state == null: return
	board.state.set_attack_hold(false)
	board.state.set_block_hold(false)
	board.state.set_advance_hold(false)
	if String(board.state.player_action.get("kind", "")) == "bow_draw": board.state.release_bow_attack(direction(board))
	board.desktop_movement_keys.clear()
	board.held_movement = false
	board.pointer_down = false
	board.attack_pointer_held = false
	board.attack_key_held = false
	board.wait_pointer_held = false
	board.queued_movement_after_attack = false
	board.selected_action = ""

func disconnected(board, disconnected_device: int) -> void:
	if disconnected_device != device: return
	release_actions(board)
	axes.clear()
	held.clear()
	device = -1
	paused = board.state.run_active
	board.queue_redraw()

func handle(board, event: InputEvent) -> bool:
	if not board.desktop_controls: return false
	if not (event is InputEventJoypadMotion or event is InputEventJoypadButton): return false
	if device >= 0 and event.device != device: return false
	if not active:
		if event is InputEventJoypadMotion and absf(event.axis_value) <= DEADZONE: return false
		if event is InputEventJoypadButton and not event.pressed: return false
		release_actions(board)
		neutral_required = false
		active = true
		board.selected_action = ""
		if board.map_open: board.state.map_presentation = "full"
	device = event.device
	if event is InputEventJoypadMotion:
		axes[event.axis] = event.axis_value
		if event.axis == JOY_AXIS_TRIGGER_RIGHT:
			var was_down := bool(held.get("trigger", false))
			var down: bool = event.axis_value > (TRIGGER_RELEASE if was_down else TRIGGER_PRESS)
			held["trigger"] = down
			if down != was_down: attack(board, down)
		elif event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			var pointing := stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
			if not pointing.is_zero_approx():
				aim = board._screen_delta_to_world_direction(pointing)
				aim_distance = lerpf(90.0, 600.0, clampf((pointing.length() - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0))
				target_id = -1
		board.queue_redraw()
		return true
	if event.pressed == bool(held.get(event.button_index, false)): return true
	held[event.button_index] = event.pressed
	if not event.pressed:
		if event.button_index == JOY_BUTTON_B: board.state.set_block_hold(false)
		if event.button_index == JOY_BUTTON_Y: board.state.set_advance_hold(false)
		return true
	# Menus accept fresh edges, never the attack trigger. Closing a menu requires
	# neutral controls before combat can resume, even if the stick stayed tilted.
	if modal(board):
		menu_button(board, event.button_index)
		board.queue_redraw()
		return true
	if event.button_index == JOY_BUTTON_START:
		release_actions(board)
		paused = true
	elif event.button_index == JOY_BUTTON_BACK:
		if not board.playing:
			release_actions(board)
			board.map_open = true
			board.state.map_presentation = "full"
			board.map_view_layer = board.state.current_layer
	elif event.button_index == JOY_BUTTON_LEFT_SHOULDER:
		if not board.playing:
			release_actions(board)
			palette_open = true
	elif event.button_index == JOY_BUTTON_RIGHT_STICK: cycle_target(board)
	elif not neutral_required:
		if board.playing and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			pending_button = event.button_index
			pending_seconds = 0.22
		elif board._can_repeat_primary_action(): perform_button(board, event.button_index)
	board.queue_redraw()
	return true

func perform_button(board, button: int) -> void:
	var facing := direction(board)
	match button:
			JOY_BUTTON_A: board._advance_or_wait()
			JOY_BUTTON_B:
				board._begin_streamed_action(board.state.request_defense(direction(board, true), false))
				board.state.set_block_hold(bool(held.get(JOY_BUTTON_B, false)))
			JOY_BUTTON_X: board._begin_streamed_action(board.state.request_potion(false))
			JOY_BUTTON_Y: use_quick_action(board)
			JOY_BUTTON_RIGHT_SHOULDER: board._begin_streamed_action(board.state.request_skill(facing, false))
			JOY_BUTTON_DPAD_UP: board._handle_button("rally")
			JOY_BUTTON_DPAD_LEFT: utility_slot = posmod(utility_slot - 1, 3)
			JOY_BUTTON_DPAD_RIGHT: utility_slot = posmod(utility_slot + 1, 3)
			JOY_BUTTON_DPAD_DOWN:
				if board.state.has_pending_pickup(): board._begin_streamed_action(board.state.replace_pending_pickup(utility_slot, false))
				else: board._begin_streamed_action(board.state.request_consumable(utility_slot, facing, false))
			JOY_BUTTON_LEFT_STICK: board._begin_streamed_action(board.state.request_wait(-1.0, false))

func consume_buffer(board) -> bool:
	if pending_button < 0 or pending_seconds <= 0.0: return false
	var button := pending_button
	pending_button = -1
	perform_button(board, button)
	return true

func attack(board, down: bool) -> void:
	if not down:
		if attack_held:
			board.state.set_attack_hold(false)
			if String(board.state.player_action.get("kind", "")) == "bow_draw": board.state.release_bow_attack(direction(board))
		attack_held = false
		return
	if neutral_required or modal(board): return
	if board.playing:
		attack_held = board.state.resume_combo_hold() or String(board.state.player_action.get("kind", "")) == "move"
		return
	if not board._can_repeat_primary_action(): return
	attack_held = true
	board._begin_streamed_action(board.state.request_direct_attack(direction(board), false, true))
	if not board.playing: attack_held = false

func use_quick_action(board) -> void:
	var facing := direction(board)
	var point: Vector2 = board.state.player_pos + facing * aim_distance
	var target := locked_target(board)
	if not target.is_empty(): point = target["pos"]
	if quick_action == "adopted": board._begin_streamed_action(board.state.request_adopted(point, false))
	elif board.state.loadout_id == "mage_elementalist":
		board._begin_streamed_action(board.state.request_spell(board.state.selected_spell, board.state.spell_target_for(board.state.selected_spell, point), false))
	elif board.state.loadout_id == "rogue_sharpshooter":
		if target.is_empty():
			board.state.message = "Press RS to select a visible enemy for Take Aim."
			board.visual = board._presentation_snapshot()
		else: board._begin_streamed_action(board.state.request_take_aim(target_id, false))
	elif board.state.loadout_id == "rogue_acrobat": board._begin_streamed_action(board.state.request_vault(facing, false))
	else: board._begin_streamed_action(board.state.request_advance(facing, true, false))

func update(board, delta: float) -> void:
	if not active: return
	pending_seconds = maxf(0.0, pending_seconds - delta)
	var context := context_id(board)
	if context != last_context:
		if last_context != "" and (modal(board) or last_context != "combat"): release_actions(board)
		last_context = context
		focus_index = 0
		navigation_direction = 0
		navigation_remaining = 0.0
	if neutral_required and stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y).is_zero_approx() and not held.values().has(true): neutral_required = false
	if modal(board):
		var entries := menu_entries(board)
		focus_index = clampi(focus_index, 0, maxi(0, entries.size() - 1))
		var nav := stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
		var step := 0
		if nav.length() >= 0.55: step = int(signf(nav.y if absf(nav.y) >= absf(nav.x) else nav.x))
		if step == 0: navigation_direction = 0
		else:
			navigation_remaining -= delta
			if step != navigation_direction or navigation_remaining <= 0.0:
				focus_index = posmod(focus_index + step, maxi(1, entries.size()))
				navigation_remaining = 0.32 if step != navigation_direction else 0.14
				navigation_direction = step
		focus_native(entries)
		return
	if String(board.state.player_action.get("kind", "")) == "bow_draw" and attack_held: board.state.set_bow_aim(direction(board))
	if String(board.state.player_action.get("kind", "")) == "block" and bool(held.get(JOY_BUTTON_B, false)): board.state.set_block_direction(direction(board))
	if String(board.state.player_action.get("kind", "")) == "advance": board.state.set_advance_hold(bool(held.get(JOY_BUTTON_Y, false)))

func context_id(board) -> String:
	var panel := native_panel(board)
	if panel != null: return "native:%d" % panel.get_instance_id()
	if paused: return "pause:%s" % abandon_confirm
	if palette_open: return "palette"
	if not board.state.run_active: return "setup:%s:%s:%s" % [board.setup_stage, board.custom_room_open, board.custom_page]
	if board.character_sheet_open: return "sheet:%s" % String(board.sheet_detail.get("kind", "summary"))
	if board.map_open: return "map"
	if board.waystone_menu_open: return "waystone"
	if board.state.death_pending or board.state.trial_complete: return "outcome"
	return "combat"

func menu_button(board, button: int) -> void:
	if button in [JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK]:
		back(board)
		return
	var entries := menu_entries(board)
	if entries.is_empty(): return
	focus_index = clampi(focus_index, 0, entries.size() - 1)
	if button in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT]: focus_index = posmod(focus_index - 1, entries.size())
	elif button in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]: focus_index = posmod(focus_index + 1, entries.size())
	elif button == JOY_BUTTON_A:
		release_actions(board)
		entries[focus_index]["activate"].call()
	focus_native(menu_entries(board))

func back(board) -> void:
	release_actions(board)
	if is_instance_valid(board.expedition_dialog) and board.expedition_dialog.visible: board.expedition_dialog.hide()
	elif is_instance_valid(board.survey_overlay) and board.survey_overlay.visible:
		var kind: String = board.survey_overlay.get_meta("kind", "")
		if kind == "archive": board._close_survey_archive()
		elif kind == "end_confirm": board.survey_overlay.hide()
		# Ratings and outcomes must be deliberately submitted, not silently skipped.
	elif palette_open: palette_open = false
	elif paused:
		if abandon_confirm: abandon_confirm = false
		else: paused = false
	elif board.character_sheet_open:
		if not board.sheet_detail.is_empty(): board.sheet_detail.clear()
		else: board.character_sheet_open = false
	elif board.map_open: board.map_open = false
	elif board.waystone_menu_open: board.waystone_menu_open = false
	elif not board.state.run_active:
		if board.custom_room_open:
			if board.custom_page == "kind": board.custom_page = "room"
			else: board.custom_room_open = false
		else: board.setup_stage = "root"
		board._layout()

func menu_entries(board) -> Array:
	var entries: Array = []
	var panel := native_panel(board)
	if panel != null:
		collect_buttons(panel, entries)
		return entries
	if paused:
		if board.playing: return []
		if abandon_confirm:
			entries.append({"label": "Keep playing", "activate": func(): abandon_confirm = false; paused = false})
			entries.append({"label": "Abandon this run (permanent)", "activate": func(): abandon_confirm = false; paused = false; board._restart()})
			return entries
		entries.append({"label": "Resume", "activate": func(): paused = false})
		entries.append({"label": "Character & upgrades", "activate": func(): paused = false; board._open_character_sheet()})
		entries.append({"label": "Change view", "activate": func(): board._toggle_view()})
		if board.state.is_measurement_mode(): entries.append({"label": "End test / report", "activate": func(): paused = false; board._build_survey_end_confirmation()})
		entries.append({"label": "Save and quit", "activate": func(): board.state.save_run(); board.get_tree().quit()})
		entries.append({"label": "Abandon run…", "activate": func(): abandon_confirm = true})
	elif palette_open:
		if board.state.loadout_id == "mage_elementalist":
			for spell in board.state.player_spells:
				entries.append({"label": "%s · %d Energy" % [board.state.spell_label(spell), roundi(board.state.spell_energy_cost(spell))], "activate": func(): board.state.select_spell(spell); quick_action = "subclass"; palette_open = false})
		else: entries.append({"label": "Subclass ability", "activate": func(): quick_action = "subclass"; palette_open = false})
		if not board.state.expedition.is_empty() and board.state.expedition["discipline"] != "":
			entries.append({"label": String(board.state.expedition["discipline"]).capitalize(), "activate": func(): quick_action = "adopted"; palette_open = false})
	elif not board.state.run_active:
		if board.custom_room_open:
			if board.custom_page == "kind": add_rects(board, entries, board.custom_kind_rects)
			else:
				for rects in [board.custom_slot_rects, board.custom_remove_rects, board.custom_formation_rects, board.custom_hp_rects, board.custom_level_rects]: add_rects(board, entries, rects)
				for rect in [board.custom_add_rect, board.custom_repeat_rect, board.custom_clear_rect, board.custom_start_rect]: add_rect(board, entries, rect)
			add_rect(board, entries, board.custom_done_rect)
		elif board.setup_stage == "root":
			add_rects(board, entries, board.progression_rects)
			add_rect(board, entries, board.archive_button_rect)
		else:
			for choice in board.CombatCatalogScript.loadout_ids(): add_rect(board, entries, board._setup_class_rect(choice))
			if board.setup_mode == "combat_survey":
				add_rects(board, entries, board.survey_profile_rects)
				add_rects(board, entries, board.combat_rule_rects)
				add_rect(board, entries, board.custom_open_rect)
			elif board.setup_mode == "boss_lab":
				add_rects(board, entries, board.boss_choice_rects)
				add_rects(board, entries, board.combat_rule_rects)
				add_rect(board, entries, board.boss_arena_rect)
			add_rect(board, entries, board.start_rect)
			add_rect(board, entries, board.setup_back_rect)
	elif board.character_sheet_open:
		if not board.sheet_detail.is_empty():
			if board.sheet_detail.get("kind") == "track_choice": add_rects(board, entries, board.sheet_skill_choice_rects)
			if board.sheet_detail.get("kind") in ["track_choice", "upgrade"]: add_rect(board, entries, board.sheet_detail_confirm_rect)
			add_rect(board, entries, board.sheet_detail_close_rect)
		else:
			for rects in [board.sheet_upgrade_rects, board.sheet_art_rects, board.sheet_consumable_rects, board.sheet_equipment_rects, board.sheet_property_rects]: add_rects(board, entries, rects)
			add_rect(board, entries, board.sheet_close_rect)
	elif board.map_open:
		add_rects(board, entries, board.map_layer_rects)
		for rect in [board.map_layer_previous_rect, board.map_layer_next_rect, board.seed_copy_rect, board._map_close_rect()]: add_rect(board, entries, rect)
		if not board.state.expedition.is_empty(): add_rect(board, entries, board._map_action_rect(3))
	elif board.waystone_menu_open:
		add_rect(board, entries, board._waystone_option_rect("learn"))
		add_rect(board, entries, board._waystone_option_rect("continue"))
	elif board.state.death_pending:
		entries.append({"label": "Return to setup", "activate": func(): board.state.return_after_death(); board.visual = board._presentation_snapshot(); board._sync_setup_controls()})
	elif board.state.trial_complete: entries.append({"label": "Return to setup", "activate": func(): board._restart()})
	return entries

func add_rects(board, entries: Array, rects: Dictionary) -> void:
	for key in rects:
		if rects[key] is Rect2: add_rect(board, entries, rects[key])

func add_rect(board, entries: Array, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0: return
	entries.append({"rect": rect, "activate": func(): board._pointer_pressed(rect.get_center())})

func collect_buttons(node: Node, entries: Array) -> void:
	if node is BaseButton and node.is_visible_in_tree() and not node.disabled:
		entries.append({"control": node, "activate": func():
			if node.toggle_mode: node.button_pressed = not node.button_pressed
			node.pressed.emit()})
	for child in node.get_children(): collect_buttons(child, entries)

func focus_native(entries: Array) -> void:
	if entries.is_empty(): return
	var control = entries[clampi(focus_index, 0, entries.size() - 1)].get("control")
	if is_instance_valid(control) and not control.has_focus():
		control.grab_focus()
		var parent = control.get_parent()
		while parent != null:
			if parent is ScrollContainer: parent.ensure_control_visible(control)
			parent = parent.get_parent()

func quick_label(board) -> String:
	if quick_action == "adopted": return "Adopted discipline"
	if board.state.loadout_id == "mage_elementalist": return board.state.spell_label(board.state.selected_spell)
	return {"warrior": "Advance", "rogue_acrobat": "Vault", "rogue_sharpshooter": "Take Aim"}.get(board.state.loadout_id, "Subclass")

func draw_hud(board) -> void:
	# Reuse the reserved action rail, not the playfield. Resources retain their
	# existing independent HUD. Labels change with the active class and item.
	var area := Rect2(board.interaction_rect)
	for rect in board.buttons.values(): area = area.merge(rect)
	for rect in board.consumable_rects.values(): area = area.merge(rect)
	board.draw_rect(area, Color("101c24"))
	var labels: Array[String] = ["RT  Attack (hold / release)", "B  %s" % String(board.state.defense_id).capitalize(), "RB  Weapon art", "Y  %s" % quick_label(board), "LB  Choose ability", "X  Rejuvenation · %d" % board.state.potions, "A  %s" % board.state.interaction_label().capitalize(), "D-pad up  Class ability", "D-pad left/right  Item %d" % (utility_slot + 1), "D-pad down  Use / replace", "LS click  Wait · RS click  Target", "View  Map · Menu  Character"]
	var art: Dictionary = board.CombatCatalogScript.weapon_art(board.state.player_equipped_weapon_art)
	labels[2] = "RB  %s" % String(art.get("label", "Art locked"))
	var class_label: String = ("End Rally" if board.state.rally_active else "Rally") if board.state.loadout_id == "warrior" else "Circle" if board.state.loadout_id == "mage_elementalist" else "End Stealth" if board.state.stealth_remaining > 0 else "Stealth"
	labels[7] = "D-pad up  %s" % class_label
	if board.state.loadout_id == "mage_elementalist" and quick_action != "adopted": labels[3] += " · %d E" % roundi(board.state.spell_energy_cost(board.state.selected_spell))
	var quick_cooldown: float = board.state.cooldown_remaining("adopted") if quick_action == "adopted" else board.state.spell_cooldown if board.state.loadout_id == "mage_elementalist" else board.state.advance_cooldown if board.state.loadout_id == "warrior" else board.state.subclass_ability_cooldown
	var cooldowns := {1: board._defense_cooldown(), 2: board.state.skill_cooldown, 3: quick_cooldown, 7: board.state.main_ability_cooldown}
	for row in cooldowns:
		if float(cooldowns[row]) > 0.01: labels[row] += " · %.1fs" % float(cooldowns[row])
	var slot: Dictionary = board.state.consumable_slot(utility_slot)
	var item_id := String(slot.get("id", ""))
	labels[8] = "D-pad left/right: %s x%d" % [item_id.replace("_", " ").capitalize() if item_id != "" else "Empty", int(slot.get("count", 0))]
	var font := clampi(int(minf(area.size.y / 19.0, area.size.x / 20.0)), 10, 28)
	for i in labels.size():
		var fitted := mini(font, int((area.size.x - 16.0) / maxf(1.0, ThemeDB.fallback_font.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font).x) * font))
		board.draw_string(ThemeDB.fallback_font, area.position + Vector2(8, (i + 1) * area.size.y / 13.0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 16.0, fitted, Color("d5e4e9"))

func draw_overlay(board) -> void:
	if not active: return
	if modal(board):
		var entries := menu_entries(board)
		var scale := minf(board.size.x / 1280.0, board.size.y / 800.0)
		if paused or palette_open:
			var box := Rect2(board.size * 0.5 - Vector2(240, 220) * scale, Vector2(480, 440) * scale)
			board.draw_rect(Rect2(Vector2.ZERO, board.size), Color(0.02, 0.04, 0.06, 0.88))
			board.draw_rect(box, Color("152831"))
			board.draw_string(ThemeDB.fallback_font, box.position + Vector2(22, 36) * scale, "FINISHING CURRENT ACTION…" if paused and board.playing else "CONTROLLER MENU" if paused else "CHOOSE Y ABILITY", HORIZONTAL_ALIGNMENT_LEFT, 436 * scale, int(22 * scale), Color("ffffff"))
			for i in entries.size():
				var row := Rect2(box.position + Vector2(16, 56 + i * 42) * scale, Vector2(448, 38) * scale)
				if i == focus_index: board.draw_rect(row, Color("28515d"))
				board.draw_string(ThemeDB.fallback_font, row.position + Vector2(10, 26) * scale, entries[i]["label"], HORIZONTAL_ALIGNMENT_LEFT, 428 * scale, int(18 * scale), Color("d5e4e9"))
			board.draw_string(ThemeDB.fallback_font, box.position + Vector2(22, 390) * scale, "LS move · RS aim · RT attack · B defend", HORIZONTAL_ALIGNMENT_LEFT, 436 * scale, int(16 * scale), Color("89b8c8"))
		elif not entries.is_empty() and entries[clampi(focus_index, 0, entries.size()-1)].has("rect"):
			board.draw_rect(Rect2(entries[clampi(focus_index, 0, entries.size()-1)]["rect"]).grow(3), Color("66e0ff"), false, 3)
		if native_panel(board) == null:
			board.draw_rect(Rect2(0, board.size.y - 40 * scale, board.size.x, 40 * scale), Color("101c24"))
			board.draw_string(ThemeDB.fallback_font, Vector2(16 * scale, board.size.y - 14 * scale), "D-pad / LS: choose    A: confirm    B: back", HORIZONTAL_ALIGNMENT_LEFT, board.size.x - 32, int(16 * scale), Color("a9d8e8"))
	elif board.state.run_active:
		var origin: Vector2 = board._world_to_screen(board.state.player_pos)
		board.draw_line(origin, board._world_to_screen(board.state.player_pos + direction(board) * 70), Color(0.4, 0.88, 1.0, 0.7), 2)
		var point: Vector2 = board.state.player_pos + direction(board) * aim_distance
		var target := locked_target(board)
		if not target.is_empty(): point = target["pos"]
		var screen: Vector2 = board._world_to_screen(point)
		if board.board_rect.has_point(screen):
			board.draw_arc(screen, 12, 0, TAU, 24, Color("66e0ff"), 2)
			board.draw_line(screen - Vector2(17, 0), screen + Vector2(17, 0), Color("66e0ff"), 1)
			board.draw_line(screen - Vector2(0, 17), screen + Vector2(0, 17), Color("66e0ff"), 1)
