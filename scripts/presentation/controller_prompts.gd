extends RefCounted
## Presentation-only descriptions of existing actions. Never decides affordability.
const Glyphs = preload("res://scripts/presentation/controller_glyphs.gd")
const INK := Color("e7f1f5")
const SECONDARY := Color("adc8d4")

static func rows(board, controller) -> Array:
	var state = board.state
	var art: Dictionary = board.CombatCatalogScript.weapon_art(state.player_equipped_weapon_art)
	var item: Dictionary = state.consumable_slot(controller.utility_slot)
	var item_id := String(item.get("id", ""))
	var item_name := "Empty slot" if item_id == "" else String(state.consumable_definition(item_id).get("label", item_id.capitalize()))
	var quick_detail := "Press to use"
	if controller.quick_action == "adopted": quick_detail = "Aim, then press to use"
	elif state.loadout_id == "mage_elementalist": quick_detail = "Aim, then cast · %d Energy" % roundi(state.spell_energy_cost(state.selected_spell))
	elif state.loadout_id == "warrior": quick_detail = "Hold to advance"
	elif state.loadout_id == "rogue_sharpshooter": quick_detail = "Click right stick to select target"
	else: quick_detail = "Aim, then vault"
	var class_label := "Rally"
	var class_detail := "Press to start / stop"
	if state.loadout_id == "warrior":
		class_label = "End Rally" if state.rally_active else "Rally"
	elif state.loadout_id == "mage_elementalist":
		class_label = "Circle"
		class_detail = "Press to place"
	else:
		class_label = "End Stealth" if state.stealth_remaining > 0 else "Stealth"
		class_detail = state.stealth_status().capitalize()
	var quick_cooldown: float = state.cooldown_remaining("adopted") if controller.quick_action == "adopted" else state.spell_cooldown if state.loadout_id == "mage_elementalist" else state.advance_cooldown if state.loadout_id == "warrior" else state.subclass_ability_cooldown
	var defense_detail := "Move stick to choose direction"
	if state.defense_id == "block": defense_detail = "Hold to block · aim to face"
	elif state.defense_id == "endure": defense_detail = "Press to endure"
	return [
		{"key": "rt", "label": "Draw bow" if state.player_weapon_frame == "bow" else "Attack", "detail": "Hold to draw · release to fire" if state.player_weapon_frame == "bow" else "Hold to chain · release to stop"},
		{"key": "b", "label": String(state.defense_id).capitalize(), "detail": defense_detail, "cooldown": board._defense_cooldown()},
		{"key": "rb", "label": String(art.get("label", "Weapon art locked")), "detail": "Learn an art through upgrades" if art.is_empty() else "Press to use weapon art", "locked": art.is_empty(), "cooldown": state.skill_cooldown},
		{"key": "y", "label": controller.quick_label(board), "detail": quick_detail, "cooldown": quick_cooldown},
		{"key": "lb", "label": "Choose ability", "detail": "Select what the yellow Y button uses"},
		{"key": "x", "label": "Rejuvenation", "detail": "Unlimited charges" if state.has_infinite_potions() else "%d / 5 charges" % state.potions, "locked": not state.has_infinite_potions() and state.potions <= 0},
		{"key": "a", "label": state.interaction_label().capitalize(), "detail": "Press to interact" if state.interaction_label().to_lower() != "wait" else "Nothing nearby · press to wait"},
		{"key": "up", "label": class_label, "detail": class_detail, "cooldown": state.main_ability_cooldown},
		{"key": "lr", "label": item_name, "detail": "Select item · slot %d / 3 · %d left" % [controller.utility_slot + 1, int(item.get("count", 0))]},
		{"key": "down", "label": "Replace selected slot" if state.has_pending_pickup() else "Use selected item", "detail": "Take the nearby pickup" if state.has_pending_pickup() else "Aim, then press to use", "locked": item_id == "" and not state.has_pending_pickup()},
	]

static func draw_row(board, rect: Rect2, row: Dictionary, scale: float) -> void:
	var icon_size := minf(34 * scale, rect.size.y - 4 * scale)
	var muted := bool(row.get("locked", false))
	Glyphs.draw(board, row["key"], Rect2(rect.position + Vector2(0, (rect.size.y - icon_size) * 0.5), Vector2.ONE * icon_size), Color(0.7, 0.7, 0.7) if muted else Color.WHITE)
	var x := rect.position.x + 42 * scale
	var width := rect.end.x - x
	Glyphs.text(board, Vector2(x, rect.position.y + 19 * scale), row["label"], width, int(16 * scale), SECONDARY if muted else INK)
	var detail := String(row["detail"])
	if float(row.get("cooldown", 0)) > 0.01: detail = "Ready in %.1fs" % float(row["cooldown"])
	Glyphs.text(board, Vector2(x, rect.position.y + 35 * scale), detail, width, int(12 * scale), SECONDARY)

static func draw_hud(board, controller) -> void:
	var area := Rect2(board.interaction_rect)
	for rect in board.buttons.values(): area = area.merge(rect)
	for rect in board.consumable_rects.values(): area = area.merge(rect)
	var scale := minf(area.size.x / 294.0, area.size.y / 584.0)
	board.draw_rect(area, Color("101f28"))
	var left := area.position + Vector2(10, 8) * scale
	Glyphs.text(board, left + Vector2(0, 15) * scale, "Controller connected" if controller.device >= 0 else "Controller disconnected", area.size.x - 20 * scale, int(15 * scale), INK)
	Glyphs.hint(board, left + Vector2(0, 26) * scale, "ls", "Move", scale)
	Glyphs.hint(board, left + Vector2(135, 26) * scale, "rs", "Aim", scale)
	var row_y := left.y + 64 * scale
	for row in rows(board, controller):
		draw_row(board, Rect2(left.x, row_y, area.size.x - 20 * scale, 42 * scale), row, scale)
		row_y += 42 * scale
	board.draw_line(Vector2(left.x, row_y + 3 * scale), Vector2(area.end.x - 10 * scale, row_y + 3 * scale), Color("34515f"), scale)
	Glyphs.hint(board, Vector2(left.x, row_y + 10 * scale), "lsc", "Click: wait", scale)
	Glyphs.hint(board, Vector2(left.x + 135 * scale, row_y + 10 * scale), "rsc", "Click: target", scale)
	Glyphs.hint(board, Vector2(left.x, row_y + 44 * scale), "view", "Map", scale)
	Glyphs.hint(board, Vector2(left.x + 135 * scale, row_y + 44 * scale), "menu", "Menu / help", scale)

static func draw_help(board, controller) -> void:
	var scale := minf(board.size.x / 1280.0, board.size.y / 800.0)
	var box := Rect2(board.size * 0.5 - Vector2(500, 335) * scale, Vector2(1000, 670) * scale)
	board.draw_rect(Rect2(Vector2.ZERO, board.size), Color(0.02, 0.04, 0.06, 0.98))
	Glyphs.text(board, box.position + Vector2(24, 40) * scale, "Xbox-style controls", 950 * scale, int(28 * scale), INK)
	Glyphs.text(board, box.position + Vector2(24, 70) * scale, "Think for as long as you need. Aiming and choosing do not advance time.", 950 * scale, int(17 * scale), SECONDARY)
	var all_rows := rows(board, controller)
	all_rows.append_array([
		{"key": "ls", "label": "Move", "detail": "Tilt to move · release finishes the current step"},
		{"key": "rs", "label": "Aim", "detail": "Direction and ground-target distance; no time cost"},
		{"key": "lsc", "label": "Wait", "detail": "Click the left stick for one deliberate time step"},
		{"key": "rsc", "label": "Cycle target", "detail": "Click the right stick; manual aim clears the target"},
		{"key": "view", "label": "Map", "detail": "The overlapping-rectangles button"},
		{"key": "menu", "label": "Menu and upgrades", "detail": "The three-lines button; also save and quit"},
		{"key": "lt", "label": "Not assigned", "detail": "The left trigger has no gameplay action"},
		{"key": "dpad", "label": "Navigate menus", "detail": "D-pad or left stick; A confirms, B goes back"},
	])
	for i in all_rows.size():
		var column := 0 if i < 10 else 1
		var row_index := i if i < 10 else i - 10
		draw_row(board, Rect2(box.position + Vector2(24 + column * 490, 96 + row_index * 49) * scale, Vector2(460, 46) * scale), all_rows[i], scale)
	Glyphs.text(board, box.position + Vector2(514, 552) * scale, "Xbox / Share buttons are managed by the system.", 460 * scale, int(13 * scale), SECONDARY)
	Glyphs.text(board, box.position + Vector2(514, 575) * scale, "Free-text notes and exact seed entry use a keyboard.", 460 * scale, int(13 * scale), SECONDARY)
	Glyphs.hint(board, box.position + Vector2(24, 620) * scale, "b", "Back to menu", scale)
