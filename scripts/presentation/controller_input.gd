extends RefCounted
const Navigation = preload("res://scripts/presentation/menu_navigation.gd")
const Glyphs = preload("res://scripts/presentation/controller_glyphs.gd")
const Prompts = preload("res://scripts/presentation/controller_prompts.gd")
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
var targeting_action := ""
var target_point := Vector2.ZERO
var palette_previous_spellbook := true
var utility_slot := 0
var aim := Vector2.ZERO
var target_id := -1
var focus_index := 0
var last_context := ""
var navigation_direction := 0
var navigation_remaining := 0.0
var pending_button := -1
var pending_seconds := 0.0
var abandon_confirm := false
var help_open := false
var focus_memory: Dictionary = {}
var focus_id := ""
var editing_text := false
var sheet_return_pause := false
var navigation_vector := Vector2.ZERO

func sync_context(board) -> void:
	if is_instance_valid(board.character_menu): board.character_menu.sync(board)
	var context := context_id(board)
	var entries := menu_entries(board)
	if context != last_context:
		if last_context != "": focus_memory[last_context] = focus_id
		if last_context != "" and (modal(board) or last_context != "combat"): release_actions(board)
		last_context = context
		focus_id = str(focus_memory.get(context,""))
		focus_index = 0
		navigation_vector = Vector2.ZERO
		navigation_remaining = 0
		editing_text = false
	for i in entries.size():
		if Navigation.id(entries[i]) == focus_id: focus_index=i; break
	focus_index = clampi(focus_index,0,maxi(0,entries.size()-1))
	if not entries.is_empty(): focus_id = Navigation.id(entries[focus_index])

func step_menu(board, direction: Vector2) -> void:
	if board.character_sheet_open: board.character_menu.touch_navigation=false
	sync_context(board)
	var entries := menu_entries(board)
	if entries.is_empty(): return
	var control = entries[focus_index].get("control")
	if direction.x != 0 and is_instance_valid(control) and control.has_meta("menu_change"):
		control.get_meta("menu_change").call(int(direction.x))
	elif board.character_sheet_open and direction.y!=0:
		# Authored order guarantees access through variable-width wrapped track rows.
		focus_index=clampi(focus_index+int(direction.y),0,entries.size()-1)
	else: focus_index=Navigation.neighbor(entries,focus_index,direction)
	focus_id=Navigation.id(menu_entries(board)[focus_index])
	focus_native(menu_entries(board))

func menu_key(board, event: InputEvent) -> bool:
	if not event is InputEventKey or not modal(board): return false
	if not event.pressed: return false
	var owner = board.get_viewport().gui_get_focus_owner()
	if (owner is LineEdit or owner is TextEdit) and editing_text:
		if event.keycode == KEY_ESCAPE: editing_text=false; return true
		return false
	if event.echo: return event.keycode in [KEY_ENTER,KEY_ESCAPE]
	if event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		step_menu(board,{KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN,KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT}[event.keycode])
	elif event.keycode in [KEY_ENTER,KEY_KP_ENTER]: menu_button(board,JOY_BUTTON_A)
	elif event.keycode == KEY_ESCAPE: back(board)
	else: return false
	return true

func connected(board, connected_device: int) -> void:
	if not board.desktop_controls or board.state == null: return
	if active and device >= 0: return
	release_actions(board)
	active = true
	device = connected_device
	axes.clear()
	held.clear()
	for axis_id in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_RIGHT]:
		axes[axis_id] = Input.get_joy_axis(device, axis_id)
	for button_id in range(JOY_BUTTON_MAX): held[button_id] = Input.is_joy_button_pressed(device, button_id)
	held["trigger"] = float(axes[JOY_AXIS_TRIGGER_RIGHT]) > TRIGGER_PRESS
	board.queue_redraw()

func stick(x: int, y: int) -> Vector2:
	var value := Vector2(float(axes.get(x, 0.0)), float(axes.get(y, 0.0)))
	return value.limit_length() if value.length() > DEADZONE else Vector2.ZERO

func move_direction(board) -> Vector2:
	if not active or neutral_required or palette_open or modal(board): return Vector2.ZERO
	return board._screen_delta_to_world_direction(stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y))

func direction(board, movement_first: bool = false) -> Vector2:
	# Melee, defense and locomotion never inherit the ranged aiming stick/lock.
	if not movement_first and board.state.player_weapon_frame == "bow": return ranged_direction(board)
	var movement: Vector2 = board._screen_delta_to_world_direction(stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y))
	return movement if not movement.is_zero_approx() else board.state.player_facing

func ranged_direction(board) -> Vector2:
	var target := locked_target(board)
	if not target.is_empty(): return board.state.player_pos.direction_to(Vector2(target["pos"]))
	var pointing := stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if not pointing.is_zero_approx(): return board._screen_delta_to_world_direction(pointing)
	var movement: Vector2 = board._screen_delta_to_world_direction(stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y))
	if not movement.is_zero_approx(): return movement
	if not aim.is_zero_approx(): return aim
	return board.state.player_facing

func has_ranged_aim(board) -> bool:
	return board.state.player_weapon_frame == "bow" or board.state.loadout_id == "mage_elementalist"

func show_ranged_guide(board) -> bool:
	if has_ranged_aim(board): return true
	# A melee character still needs a directional preview when choosing a throw.
	if palette_open:
		for slot in 3:
			var item: Dictionary = board.state.consumable_slot(slot)
			if int(item.get("count", 0)) > 0 and board.state.consumable_requires_direction(slot): return true
	return false

func spell_shortcuts(board) -> Array:
	# Stable element positions: learning a spell does not rebind the others.
	var result: Array = []
	var groups := [["lightning_bolt"]]
	for stage in ["element_fire", "element_ice", "element_earth", "element_air"]:
		groups.append(Array(board.state.ELEMENT_STAGE_SPELLS[stage]))
	var keys := ["a", "b", "x", "y", "rb"]
	var buttons := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER]
	for i in groups.size():
		for spell in groups[i]:
			if board.state.knows_spell(spell): result.append({"spell": spell, "key": keys[i], "button": buttons[i]})
	return result

func set_palette(board, open: bool) -> void:
	if open and board.state.combat_lab: board.state.lab_armed = false
	if open == palette_open: return
	if open: palette_previous_spellbook = board.spellbook_open
	release_actions(board)
	palette_open = open
	board.spellbook_open = true if open else palette_previous_spellbook
	# The modifier deliberately stays held while a fresh shortcut is pressed.
	if open: neutral_required = false
	board._layout()

func palette_button(board, button: int) -> void:
	if board.playing or not board.state.is_player_ready(): return
	if board.state.loadout_id == "mage_elementalist":
		for shortcut in spell_shortcuts(board):
			if shortcut["button"] == button:
				board.state.select_spell(shortcut["spell"])
				use_spell(board, shortcut["spell"])
				return
	elif button == JOY_BUTTON_Y: use_quick_action(board)
	if button == JOY_BUTTON_DPAD_UP: use_adopted(board)
	var slots := [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]
	if button in slots:
		utility_slot = slots.find(button)
		use_item(board)

func use_item(board) -> void:
	if board.state.has_pending_pickup(): board._begin_streamed_action(board.state.replace_pending_pickup(utility_slot, false))
	else:
		var targeted: bool = board.state.consumable_requires_direction(utility_slot)
		board._begin_streamed_action(board.state.request_consumable(utility_slot, ranged_direction(board) if targeted else direction(board, true), false))

func use_spell(board, spell: String) -> void:
	if board.state.spell_is_placed(spell):
		begin_targeting(board, spell)
		return
	var spec: Dictionary = board.state.AbilityCatalogScript.spell(spell)
	var facing := direction(board, true) if spec.get("resolver") == "movement" else ranged_direction(board)
	board._begin_streamed_action(board.state.request_spell(spell, board.state.player_pos + facing * 340.0, false))

func use_adopted(board) -> void:
	var discipline := String(board.state.expedition.get("discipline", ""))
	if discipline == "sapper": begin_targeting(board, "adopted")
	elif discipline == "trapper": board._begin_streamed_action(board.state.request_adopted(board.state.player_pos + direction(board, true) * 65.0, false))

func targeting_range(board) -> float:
	if targeting_action == "adopted": return float(board.state.AbilityCatalogScript.ADOPTED_DISCIPLINES["sapper"]["range"])
	return board.state.spell_reach(targeting_action)

func begin_targeting(board, action: String) -> void:
	if board.playing or not board.state.is_player_ready(): return
	var facing := ranged_direction(board)
	if palette_open: set_palette(board, false)
	release_actions(board)
	targeting_action = action
	target_point = board.state.player_pos + facing * minf(180.0, targeting_range(board))

func finish_targeting(board, confirm: bool) -> void:
	var action := targeting_action
	targeting_action = ""
	release_actions(board)
	if not confirm: return
	if action == "adopted": board._begin_streamed_action(board.state.request_adopted(target_point, false))
	else: board._begin_streamed_action(board.state.request_spell(action, board.state.spell_target_for(action, target_point), false))

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
			if board.state.combat_lab and board.state.lab_armed and board.state.lab_target_refusal(int(enemy["id"])) != "": continue
			candidates.append(enemy)
	candidates.sort_custom(func(a, b): return board.state.player_pos.distance_squared_to(a["pos"]) < board.state.player_pos.distance_squared_to(b["pos"]))
	var index := -1
	for i in candidates.size():
		if int(candidates[i]["id"]) == target_id: index = i
	target_id = int(candidates[index + 1]["id"]) if index + 1 < candidates.size() else -1

func modal(board) -> bool:
	return help_open or paused or targeting_action != "" or not board.state.run_active or board.character_sheet_open or board.waystone_menu_open or board.map_open or board.state.death_pending or board.state.trial_complete or board.state.survey_feedback_pending or native_panel(board) != null

func native_panel(board) -> Node:
	if is_instance_valid(board.expedition_dialog) and board.expedition_dialog.visible: return board.expedition_dialog
	if is_instance_valid(board.survey_overlay) and board.survey_overlay.visible: return board.survey_overlay
	if board.character_sheet_open and is_instance_valid(board.character_menu) and board.character_menu.visible: return board.character_menu
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
	if board.state.combat_lab:
		board.state.lab_suspend()
		target_id = -1
	if palette_open: set_palette(board, false)
	targeting_action = ""
	release_actions(board)
	axes.clear()
	held.clear()
	if board.has_method("_cancel_disconnected_inspection"): board._cancel_disconnected_inspection()
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
		if board.character_sheet_open and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y] and stick(JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y).is_zero_approx() and absf(event.axis_value)>=0.55:
			board.character_menu.touch_navigation=false
		axes[event.axis] = event.axis_value
		if event.axis == JOY_AXIS_TRIGGER_LEFT and board.state.combat_lab:
			var was_down := bool(held.get("lab_lt",false))
			var down: bool = event.axis_value > (TRIGGER_RELEASE if was_down else TRIGGER_PRESS)
			held["lab_lt"] = down
			if down and not was_down and not neutral_required and not modal(board): board.state.lab_toggle_commit()
		elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
			var was_down := bool(held.get("trigger", false))
			var down: bool = event.axis_value > (TRIGGER_RELEASE if was_down else TRIGGER_PRESS)
			held["trigger"] = down
			if down != was_down: attack(board, down)
		elif event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			var pointing := stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
			if not pointing.is_zero_approx() and targeting_action == "" and not modal(board):
				target_id = -1
		board.queue_redraw()
		return true
	if event.pressed == bool(held.get(event.button_index, false)): return true
	held[event.button_index] = event.pressed
	if not event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER and palette_open: set_palette(board, false)
		if event.button_index == JOY_BUTTON_B: board.state.set_block_hold(false)
		if event.button_index == JOY_BUTTON_Y: board.state.set_advance_hold(false)
		return true
	if targeting_action != "":
		if event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B]: finish_targeting(board, event.button_index == JOY_BUTTON_A)
		elif event.button_index == JOY_BUTTON_START:
			finish_targeting(board, false)
			paused = true
		return true
	# Menus accept fresh edges, never the attack trigger. Closing a menu requires
	# neutral controls before combat can resume, even if the stick stayed tilted.
	if modal(board):
		menu_button(board, event.button_index)
		board.queue_redraw()
		return true
	if event.button_index == JOY_BUTTON_START:
		if board.state.combat_lab: board.state.lab_suspend()
		if palette_open: set_palette(board, false)
		release_actions(board)
		paused = true
	elif event.button_index == JOY_BUTTON_BACK:
		if not board.playing:
			if palette_open: set_palette(board, false)
			release_actions(board)
			board.map_open = true
			board.state.map_presentation = "full"
			board.map_view_layer = board.state.current_layer
	elif event.button_index == JOY_BUTTON_LEFT_SHOULDER:
		if not neutral_required: set_palette(board, true)
	elif palette_open: palette_button(board, event.button_index)
	elif board.state.lab_junction() and not neutral_required:
		if event.button_index == JOY_BUTTON_B: board._begin_streamed_action(board.state.request_dodge(direction(board,true),false))
		elif event.button_index == JOY_BUTTON_LEFT_STICK: board._begin_streamed_action(board.state.lab_recover())
	elif event.button_index == JOY_BUTTON_RIGHT_STICK and (has_ranged_aim(board) or (board.state.combat_lab and board.state.lab_armed)): cycle_target(board)
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
			JOY_BUTTON_DPAD_DOWN: use_item(board)
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
	if neutral_required or palette_open or modal(board): return
	if board.state.combat_lab and board.state.lab_neutral_required: return
	if board.state.lab_junction():
		attack_held = board.state.lab_continue(true)
		board._begin_streamed_action(attack_held)
		return
	if board.state.combat_lab and board.state.lab_armed:
		if target_id < 0:
			board.state.lab_notice = "Commit refused: RS selects a visible target; RT confirms."
		else: board._begin_streamed_action(board.state.lab_target(target_id,true))
		return
	if board.playing:
		attack_held = board.state.resume_combo_hold() or String(board.state.player_action.get("kind", "")) == "move"
		return
	if not board._can_repeat_primary_action(): return
	attack_held = true
	board._begin_streamed_action(board.state.request_direct_attack(direction(board), false, true))
	if not board.playing: attack_held = false

func use_quick_action(board) -> void:
	var facing := direction(board)
	var target := locked_target(board)
	if board.state.loadout_id == "mage_elementalist": use_spell(board, board.state.selected_spell)
	elif board.state.loadout_id == "rogue_sharpshooter":
		if target.is_empty():
			board.state.message = "Press RS to select a visible enemy for Take Aim."
			board.visual = board._presentation_snapshot()
		else: board._begin_streamed_action(board.state.request_take_aim(target_id, false))
	elif board.state.loadout_id == "rogue_acrobat": board._begin_streamed_action(board.state.request_vault(facing, false))
	else: board._begin_streamed_action(board.state.request_advance(facing, true, false))

func update(board, delta: float) -> void:
	if not active: return
	if board.state.combat_lab:
		if axes.values().all(func(v): return absf(float(v)) <= DEADZONE) and not Input.is_anything_pressed() and not held.values().has(true): board.state.lab_input_neutral()
		if board.state.lab_neutral_required:
			attack_held = false
			pending_button = -1
		if board.state.lab_junction() and not neutral_required:
			var move := move_direction(board)
			if not move.is_zero_approx(): board._begin_streamed_action(board.state.request_move(move,board.state.MOVE_RANGE,false))
	# Sample both axes together once per frame, rather than retaining the transient
	# half-updated heading from the two separate axis-release events.
	var pointing := stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	if not pointing.is_zero_approx() and targeting_action == "" and not modal(board):
		aim = board._screen_delta_to_world_direction(pointing)
	pending_seconds = maxf(0.0, pending_seconds - delta)
	sync_context(board)
	if neutral_required and not Input.is_anything_pressed() and axes.values().all(func(v): return absf(float(v)) <= DEADZONE) and not held.values().has(true): neutral_required = false
	if targeting_action != "":
		if board.state.death_pending or board.state.trial_complete:
			finish_targeting(board, false)
			return
		var stick_input := stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
		# Full analog direction, proportional cursor speed; release holds its location.
		var speed := clampf((stick_input.length() - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
		target_point += board._screen_delta_to_world_direction(stick_input) * speed * 320.0 * delta
		target_point = board.state.player_pos + (target_point - board.state.player_pos).limit_length(targeting_range(board))
		return
	if modal(board):
		if board.character_sheet_open and board.character_menu.touch_navigation: return
		var entries := menu_entries(board)
		focus_index = clampi(focus_index, 0, maxi(0, entries.size() - 1))
		var nav := stick(JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y)
		var dpad := Vector2(int(bool(held.get(JOY_BUTTON_DPAD_RIGHT,false)))-int(bool(held.get(JOY_BUTTON_DPAD_LEFT,false))),int(bool(held.get(JOY_BUTTON_DPAD_DOWN,false)))-int(bool(held.get(JOY_BUTTON_DPAD_UP,false))))
		if not dpad.is_zero_approx(): nav=dpad
		var direction := Vector2.ZERO
		var threshold := 0.40 if not navigation_vector.is_zero_approx() else 0.55
		if nav.length() >= threshold: direction=Vector2(0,signf(nav.y)) if absf(nav.y) >= absf(nav.x) else Vector2(signf(nav.x),0)
		if direction.is_zero_approx(): navigation_vector=Vector2.ZERO
		else:
			navigation_remaining -= delta
			if direction != navigation_vector or navigation_remaining <= 0:
				step_menu(board,direction)
				navigation_remaining=0.32 if direction != navigation_vector else 0.14
				navigation_vector=direction
		focus_native(entries)
		return
	if String(board.state.player_action.get("kind", "")) == "bow_draw" and attack_held: board.state.set_bow_aim(direction(board))
	if String(board.state.player_action.get("kind", "")) == "block" and bool(held.get(JOY_BUTTON_B, false)): board.state.set_block_direction(direction(board, true))
	if String(board.state.player_action.get("kind", "")) == "advance": board.state.set_advance_hold(bool(held.get(JOY_BUTTON_Y, false)))

func context_id(board) -> String:
	if help_open: return "help"
	var panel := native_panel(board)
	if panel != null:
		return "native:"+str(panel.get_meta("menu_context",panel.get_meta("kind",panel.name)))
	if paused: return "pause:%s" % abandon_confirm
	if targeting_action != "": return "targeting"
	if not board.state.run_active: return "setup:%s:%s:%s" % [board.setup_stage, board.custom_room_open, board.custom_page]
	if board.character_sheet_open: return "sheet:%s:%s" % [String(board.sheet_detail.get("kind", "summary")),String(board.sheet_detail.get("track",""))]
	if board.map_open: return "map"
	if board.waystone_menu_open: return "waystone"
	if board.state.death_pending or board.state.trial_complete: return "outcome"
	return "combat"

func menu_button(board, button: int) -> void:
	if board.character_sheet_open: board.character_menu.touch_navigation=false
	sync_context(board)
	if button in [JOY_BUTTON_B,JOY_BUTTON_START,JOY_BUTTON_BACK]:
		if editing_text: editing_text=false
		else: back(board)
		return
	if help_open: return
	var directions := {JOY_BUTTON_DPAD_UP:Vector2.UP,JOY_BUTTON_DPAD_DOWN:Vector2.DOWN,JOY_BUTTON_DPAD_LEFT:Vector2.LEFT,JOY_BUTTON_DPAD_RIGHT:Vector2.RIGHT}
	if directions.has(button):
		step_menu(board,directions[button])
		navigation_vector=directions[button]; navigation_remaining=0.32
	elif button == JOY_BUTTON_A:
		var entries := menu_entries(board)
		if entries.is_empty(): return
		release_actions(board)
		var control = entries[focus_index].get("control")
		editing_text=control is LineEdit or control is TextEdit
		entries[focus_index]["activate"].call()
		sync_context(board)
	focus_native(menu_entries(board))

func back(board) -> void:
	release_actions(board)
	if help_open: help_open = false
	elif is_instance_valid(board.expedition_dialog) and board.expedition_dialog.visible: board.expedition_dialog.hide()
	elif is_instance_valid(board.survey_overlay) and board.survey_overlay.visible:
		var kind: String = board.survey_overlay.get_meta("kind", "")
		if kind == "archive":
			if not board.survey_archived_run.is_empty(): board._build_survey_archive_overlay()
			else: board._close_survey_archive()
		elif kind == "end_confirm":
			board.survey_overlay.hide()
			if board.has_method("_return_inspection_view"): board._return_inspection_view()
		elif kind == "experiment_setup": board._close_experiment_setup()
		# Ratings and outcomes must be deliberately submitted, not silently skipped.
	elif paused:
		if abandon_confirm: abandon_confirm = false
		else: paused = false
	elif board.character_sheet_open:
		if not board.sheet_detail.is_empty(): board.character_menu.back_view()
		else:
			board.character_sheet_open = false
			if sheet_return_pause: paused=true; sheet_return_pause=false
			elif board.has_method("_return_inspection_view"): board._return_inspection_view()
	elif board.map_open:
		board.map_open = false
		if board.has_method("_return_inspection_view"): board._return_inspection_view()
	elif board.waystone_menu_open: board.waystone_menu_open = false
	elif not board.state.run_active:
		if board.custom_room_open:
			if board.custom_page == "kind": board.custom_page = "room"
			else: board.custom_room_open = false
		else: board.setup_stage = "root"
		board._layout()
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
		entries.append({"label": "Character & upgrades", "activate": func(): sheet_return_pause=true; paused = false; board._open_character_sheet()})
		entries.append({"label": "Controller guide", "activate": func(): help_open = true})
		entries.append({"label": "Change view", "activate": func(): board._toggle_view()})
		if board.state.is_measurement_mode(): entries.append({"label": "End test / report", "activate": func(): paused = false; board._build_survey_end_confirmation()})
		entries.append({"label": "Save and quit", "activate": func(): board.state.save_run(); board.get_tree().quit()})
		entries.append({"label": "Abandon run…", "activate": func(): abandon_confirm = true})
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
	for entry in entries:
		if entry.get("rect") == rect: return
	var id := ""
	for collection in ["progression_rects","custom_slot_rects","custom_remove_rects","custom_formation_rects","custom_hp_rects","custom_level_rects","custom_kind_rects","survey_profile_rects","combat_rule_rects","boss_choice_rects","map_layer_rects"]:
		for key in board.get(collection):
			if board.get(collection)[key] is Rect2 and board.get(collection)[key]==rect: id=collection+":"+str(key); break
	for command in ["start_rect","setup_back_rect","archive_button_rect","custom_open_rect","custom_done_rect","custom_start_rect","custom_add_rect","custom_repeat_rect","custom_clear_rect","boss_arena_rect","seed_copy_rect","map_layer_previous_rect","map_layer_next_rect"]:
		if board.get(command)==rect: id=command; break
	entries.append({"id":id if id!="" else str(rect),"rect": rect, "activate": func(): board._pointer_pressed(rect.get_center())})

func collect_buttons(node: Node, entries: Array) -> void:
	if (node is LineEdit or node is TextEdit) and node.is_visible_in_tree():
		if not node.has_meta("menu_edit_bound"):
			node.set_meta("menu_edit_bound",true)
			node.focus_entered.connect(func(): focus_id=Navigation.id({"control":node}))
			node.tooltip_text="Optional text · use a keyboard to edit; Escape returns to navigation."
			node.gui_input.connect(func(event):
				if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed: editing_text=true)
		entries.append({"control":node,"activate":func(): node.grab_focus()})
	if node is BaseButton and node.is_visible_in_tree() and not node.disabled and not node.get_meta("menu_skip",false):
		if not node.has_meta("menu_bound"):
			node.set_meta("menu_bound",true)
			node.focus_entered.connect(func(): focus_id=Navigation.id({"control":node}))
		entries.append({"control": node, "activate": func():
			if node.toggle_mode: node.button_pressed = not node.button_pressed
			node.pressed.emit()})
	for child in node.get_children(): collect_buttons(child, entries)

func focus_native(entries: Array) -> void:
	if entries.is_empty(): return
	var control = entries[clampi(focus_index, 0, entries.size() - 1)].get("control")
	if is_instance_valid(control):
		control.grab_focus()
		var parent = control.get_parent()
		while parent != null:
			if parent is ScrollContainer: parent.call_deferred("ensure_control_visible",control)
			parent = parent.get_parent()

func quick_label(board) -> String:
	if board.state.loadout_id == "mage_elementalist": return board.state.spell_label(board.state.selected_spell)
	return {"warrior": "Advance", "rogue_acrobat": "Vault", "rogue_sharpshooter": "Take Aim"}.get(board.state.loadout_id, "Subclass")

func draw_hud(board) -> void:
	Prompts.draw_hud(board, self)

func draw_overlay(board) -> void:
	if not active: return
	if help_open:
		Prompts.draw_help(board, self)
		return
	if targeting_action != "":
		var screen: Vector2 = board._world_to_screen(target_point)
		board.draw_arc(screen, 12, 0, TAU, 24, Color("66e0ff"), 2)
		board.draw_line(screen - Vector2(17, 0), screen + Vector2(17, 0), Color("66e0ff"), 1)
		board.draw_line(screen - Vector2(0, 17), screen + Vector2(0, 17), Color("66e0ff"), 1)
		var scale := minf(board.size.x / 1280.0, board.size.y / 800.0)
		var bar := Rect2(Vector2(board.board_rect.position.x + 8 * scale, board.board_rect.end.y - 180 * scale), Vector2(680, 70) * scale)
		board.draw_rect(bar, Color("101c24"))
		var label: String = "Concussion flask" if targeting_action == "adopted" else board.state.spell_label(targeting_action)
		Glyphs.text(board, bar.position + Vector2(10, 22) * scale, "%s · TIME STOPPED" % label, 640 * scale, int(17 * scale), Color.WHITE)
		Glyphs.hint(board, bar.position + Vector2(10, 32) * scale, "rs", "Place marker", scale)
		Glyphs.hint(board, bar.position + Vector2(245, 32) * scale, "a", "Use here", scale)
		Glyphs.hint(board, bar.position + Vector2(440, 32) * scale, "b", "Cancel", scale)
		return
	if modal(board):
		if board.character_sheet_open and board.character_menu.touch_navigation: return
		var entries := menu_entries(board)
		var scale := minf(board.size.x / 1280.0, board.size.y / 800.0)
		if paused:
			var box := Rect2(board.size * 0.5 - Vector2(240, 220) * scale, Vector2(480, 440) * scale)
			board.draw_rect(Rect2(Vector2.ZERO, board.size), Color(0.02, 0.04, 0.06, 0.88))
			board.draw_rect(box, Color("152831"))
			var heading := "Finishing current action…" if paused and board.playing else "Controller menu" if paused else "Choose ability"
			board.draw_string(ThemeDB.fallback_font, box.position + Vector2(22, 36) * scale, heading, HORIZONTAL_ALIGNMENT_LEFT, 436 * scale, int(22 * scale), Color("ffffff"))
			for i in entries.size():
				var row := Rect2(box.position + Vector2(16, 56 + i * 42) * scale, Vector2(448, 38) * scale)
				if i == focus_index: board.draw_rect(row, Color("28515d"))
				if i == focus_index: Glyphs.draw(board, "a", Rect2(row.position + Vector2(6, 3) * scale, Vector2.ONE * 32 * scale))
				Glyphs.text(board, row.position + Vector2(46, 26) * scale, entries[i]["label"], 394 * scale, int(18 * scale), Color("d5e4e9"))
			Glyphs.hint(board, box.position + Vector2(22, 380) * scale, "dpad", "Choose", scale)
			Glyphs.hint(board, box.position + Vector2(170, 380) * scale, "a", "Confirm", scale)
			Glyphs.hint(board, box.position + Vector2(318, 380) * scale, "b", "Back", scale)
		elif not entries.is_empty() and entries[clampi(focus_index, 0, entries.size()-1)].has("rect"):
			board.draw_rect(Rect2(entries[clampi(focus_index, 0, entries.size()-1)]["rect"]).grow(3), Color("66e0ff"), false, 3)
		if native_panel(board) == null:
			board.draw_rect(Rect2(0, board.size.y - 40 * scale, board.size.x, 40 * scale), Color("101c24"))
			Glyphs.hint(board, Vector2(16 * scale, board.size.y - 35 * scale), "dpad", "Choose", scale)
			Glyphs.hint(board, Vector2(174 * scale, board.size.y - 35 * scale), "a", "Confirm", scale)
			Glyphs.hint(board, Vector2(332 * scale, board.size.y - 35 * scale), "b", "Back", scale)
	elif board.state.run_active and show_ranged_guide(board):
		var origin: Vector2 = board._world_to_screen(board.state.player_pos)
		# A fixed-length directional guide, never a distance selected by stick tilt.
		var tip: Vector2 = board._world_to_screen(board.state.player_pos + ranged_direction(board) * 110)
		board.draw_line(origin, tip, Color(0.4, 0.88, 1.0, 0.7), 2)
		var target := locked_target(board)
		if not target.is_empty(): board.draw_arc(board._world_to_screen(target["pos"]), 14, 0, TAU, 24, Color("66e0ff"), 2)
