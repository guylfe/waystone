extends SceneTree

const Board = preload("res://scripts/presentation/game_board.gd")
const State = preload("res://scripts/core/run_state.gd")
var failures: Array[String] = []

func check(value: bool, description: String) -> void:
	if not value: failures.append(description)

func fixture(loadout: String = "warrior"):
	var board = Board.new()
	board.state = State.new(false)
	board.state.start_run(loadout, "combat_survey", 4242, "encounter", "energy")
	board.state.walls.clear()
	board.state.enemies.clear()
	board.state.enemies.append(board.state._make_enemy("blade", board.state.player_pos + Vector2(800, 0), 30, 0))
	board.visual = board.state.snapshot(true)
	board.size = Vector2(1280, 800)
	board._create_seed_input()
	board._layout()
	board.controller.active = true
	board.controller.update(board, 0)
	return board

func axis(board, which: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = which
	event.axis_value = value
	board.controller.handle(board, event)

func button(board, which: int, down: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = which
	event.pressed = down
	board.controller.handle(board, event)

func tap(board, which: int) -> void:
	button(board, which)
	button(board, which, false)

func finish(board) -> void:
	for i in 300:
		if not board.playing: break
		board._process(0.05)
	check(not board.playing, "released action must eventually finish")

func test_move_and_aim() -> void:
	var board = fixture()
	var before: float = board.state.simulation_time
	axis(board, JOY_AXIS_LEFT_X, 0.18)
	board._process(0.05)
	check(board.state.simulation_time == before and not board.playing, "stick drift cannot spend simulation time")
	axis(board, JOY_AXIS_RIGHT_X, 0.9)
	board._process(0.05)
	check(board.state.simulation_time == before and not board.playing, "aiming alone must leave time frozen")
	check(board.controller.direction(board) == board.state.player_facing, "melee ignores ranged aiming stick")
	axis(board, JOY_AXIS_LEFT_X, -0.9)
	board._process(0.05)
	check(board.state.player_action["kind"] == "move", "left stick directly commits movement, not a touch gesture")
	check(Vector2(board.state.player_action["direction"]).dot(board._screen_delta_to_world_direction(Vector2.LEFT)) > 0.99, "movement is screen-relative")
	axis(board, JOY_AXIS_LEFT_X, 0)
	finish(board)
	before = board.state.simulation_time
	board._process(0.1)
	check(board.state.simulation_time == before, "releasing the stick stops after the committed step")
	board.free()

func test_attack_defense_and_bow() -> void:
	for loadout in ["warrior", "rogue_acrobat", "mage_elementalist", "rogue_sharpshooter"]:
		var board = fixture(loadout)
		axis(board, JOY_AXIS_RIGHT_Y, -0.8)
		axis(board, JOY_AXIS_TRIGGER_RIGHT, 0.9)
		check(board.playing, "%s RT directly starts its weapon" % loadout)
		var expected := "bow_draw" if loadout == "rogue_sharpshooter" else "combo"
		check(board.state.player_action["kind"] == expected, "%s uses shared weapon action" % loadout)
		axis(board, JOY_AXIS_TRIGGER_RIGHT, 0.1)
		check(not board.controller.attack_held, "RT release clears held continuation")
		if loadout == "rogue_sharpshooter": check(board.state.player_action["kind"] != "bow_draw", "bow release fires without a world tap")
		finish(board)
		board.free()
	var board = fixture()
	axis(board, JOY_AXIS_RIGHT_X, 1)
	axis(board, JOY_AXIS_LEFT_X, -1)
	tap(board, JOY_BUTTON_B)
	check(board.state.player_action["kind"] == "dodge", "B is defense, never an enemy attack")
	check(Vector2(board.state.player_action["direction"]).dot(board._screen_delta_to_world_direction(Vector2.LEFT)) > 0.99, "dodge prefers movement over aim")
	board.free()

func test_modal_safety() -> void:
	var board = fixture()
	axis(board, JOY_AXIS_LEFT_X, 1)
	board._process(0.01)
	tap(board, JOY_BUTTON_START)
	check(board.controller.paused, "Menu opens a safe controller menu")
	check(board.controller.menu_entries(board).is_empty(), "cannot save/quit in the middle of a commitment")
	finish(board)
	var before: float = board.state.simulation_time
	board._process(0.1)
	check(board.state.simulation_time == before, "pause prevents held movement chaining")
	tap(board, JOY_BUTTON_B)
	board._process(0.1)
	check(not board.playing, "held stick cannot move on menu dismissal")
	axis(board, JOY_AXIS_LEFT_X, 0)
	board._process(0.01)
	axis(board, JOY_AXIS_LEFT_X, 1)
	board._process(0.01)
	check(board.playing, "neutral then a fresh tilt resumes control")
	board.controller.disconnected(board, 0)
	check(board.controller.paused and not board.controller.attack_held, "disconnect drops holds and opens menu")
	board.free()

func test_palette_and_setup() -> void:
	var board = fixture("mage_elementalist")
	var before: float = board.state.simulation_time
	button(board, JOY_BUTTON_LEFT_SHOULDER)
	board.controller.update(board, 0)
	check(board.controller.spell_shortcuts(board).size() == board.state.player_spells.size(), "shortcuts list actual owned spells")
	check(board.controller.palette_open and board.spellbook_open and board.state.simulation_time == before, "LB reveals shortcuts without spending time")
	axis(board, JOY_AXIS_LEFT_X, 1)
	board._process(0.02)
	check(not board.playing, "holding LB suppresses movement while choosing")
	tap(board, JOY_BUTTON_A)
	check(board.state.player_action["kind"] == "cast", "LB+A casts Lightning directly, not a selection menu")
	button(board, JOY_BUTTON_LEFT_SHOULDER, false)
	check(not board.controller.palette_open and board.controller.neutral_required, "LB release restores labels and requires neutral before movement")
	board.free()
	board = fixture()
	board.state.run_active = false
	board.setup_stage = "root"
	board._layout()
	board.controller.update(board, 0)
	tap(board, JOY_BUTTON_A)
	check(board.setup_stage == "options", "A opens focused setup mode")
	board.controller.update(board, 0)
	var entries: Array = board.controller.menu_entries(board)
	check(entries.size() >= 6, "setup exposes all four characters and start/back")
	board.controller.focus_index = 3
	board.controller.focus_id = "" # Legacy explicit-index unit diagnostic; routed journeys own navigation acceptance.
	tap(board, JOY_BUTTON_A)
	check(board.setup_loadout == "mage_elementalist", "fourth character is reachable on controller")
	tap(board, JOY_BUTTON_B)
	check(board.setup_stage == "root", "B backs out of setup")
	board.free()

func test_buffer_and_device_isolation() -> void:
	var board = fixture()
	axis(board, JOY_AXIS_LEFT_X, 1)
	board._process(0.01)
	axis(board, JOY_AXIS_LEFT_X, 0)
	tap(board, JOY_BUTTON_B)
	check(board.controller.pending_button == JOY_BUTTON_B, "fresh defense near step boundary is buffered")
	for i in 10:
		board._process(0.02)
		if board.state.player_action["kind"] == "dodge": break
	check(board.state.player_action["kind"] == "dodge", "buffer starts defense at ready boundary")
	var event := InputEventJoypadButton.new()
	event.device = 2
	event.button_index = JOY_BUTTON_START
	event.pressed = true
	check(not board.controller.handle(board, event) and not board.controller.paused, "second controller cannot take over held intent")
	board.free()

func test_native_menu() -> void:
	var board = fixture()
	var panel := PanelContainer.new()
	root.add_child(panel)
	board.survey_overlay = panel
	var box := VBoxContainer.new()
	panel.add_child(box)
	var disabled := Button.new()
	disabled.disabled = true
	box.add_child(disabled)
	var toggle := CheckButton.new()
	box.add_child(toggle)
	board.controller.update(board, 0)
	check(board.controller.menu_entries(board).size() == 1, "native menus exclude disabled controls")
	tap(board, JOY_BUTTON_A)
	check(toggle.button_pressed, "controller activates native toggles")
	panel.free()
	board.free()

func test_directional_and_placed_targeting() -> void:
	var board = fixture("mage_elementalist")
	for view in ["isometric", "top_down"]:
		board.view_mode = view
		for degrees in [13, 29, 57, 143, 217]:
			var vector := Vector2.RIGHT.rotated(deg_to_rad(degrees))
			axis(board, JOY_AXIS_RIGHT_X, vector.x * 0.9)
			axis(board, JOY_AXIS_RIGHT_Y, vector.y * 0.9)
			var full: Vector2 = board.controller.ranged_direction(board)
			axis(board, JOY_AXIS_RIGHT_X, vector.x * 0.4)
			axis(board, JOY_AXIS_RIGHT_Y, vector.y * 0.4)
			check(full.dot(board.controller.ranged_direction(board)) > 0.9999, "direction ignores stick magnitude, with no eight-way snapping")
			check(full.dot(board._screen_delta_to_world_direction(vector)) > 0.9999, "arbitrary analog angle projects exactly")
	axis(board, JOY_AXIS_RIGHT_X, 0.6)
	axis(board, JOY_AXIS_RIGHT_Y, 0.6)
	board.controller.update(board, 0)
	var aimed: Vector2 = board.controller.ranged_direction(board)
	axis(board, JOY_AXIS_RIGHT_X, 0)
	axis(board, JOY_AXIS_RIGHT_Y, 0)
	board.controller.update(board, 0)
	check(board.controller.ranged_direction(board).is_equal_approx(aimed), "separate release events do not snap retained aim to an axis")
	board.state.player_spells.append("sunder")
	board.state.select_spell("sunder")
	var before: float = board.state.simulation_time
	var energy: float = board.state.player_energy
	tap(board, JOY_BUTTON_Y)
	check(board.controller.targeting_action == "sunder" and not board.playing, "placed spell opens frozen placement, not a cast")
	var initial: Vector2 = board.controller.target_point
	axis(board, JOY_AXIS_RIGHT_X, 0.7)
	board._process(0.25)
	check(board.controller.target_point.distance_to(initial) > 1, "stick smoothly translates ground marker")
	axis(board, JOY_AXIS_RIGHT_X, 0)
	initial = board.controller.target_point
	board._process(0.2)
	check(board.controller.target_point == initial, "released ground marker stays at chosen point")
	check(board.state.simulation_time == before and board.state.player_energy == energy, "ground placement spends neither time nor Energy")
	tap(board, JOY_BUTTON_B)
	check(board.controller.targeting_action == "" and not board.playing, "B cancels placement without dodging")
	board.controller.update(board, 0)
	tap(board, JOY_BUTTON_Y)
	axis(board, JOY_AXIS_RIGHT_X, 1)
	board._process(10)
	check(board.controller.target_point.distance_to(board.state.player_pos) <= board.state.spell_reach("sunder") + 0.01, "cursor respects authored placement range")
	axis(board, JOY_AXIS_RIGHT_X, 0)
	initial = board.controller.target_point
	tap(board, JOY_BUTTON_A)
	check(board.state.player_action["kind"] == "cast" and Vector2(board.state.player_action["target"]).is_equal_approx(initial), "A casts at exactly the previewed point")
	board.free()

func test_modifier_bindings_and_safety() -> void:
	var board = fixture("mage_elementalist")
	board.state.player_spells.append_array(["fireball", "cold_front", "sunder", "gale"])
	board.spellbook_open = false
	button(board, JOY_BUTTON_LEFT_SHOULDER)
	check(board.spellbook_open, "LB opens touch spell drawer")
	var expected := {"lightning_bolt": "a", "fireball": "b", "cold_front": "x", "sunder": "y", "gale": "rb"}
	for binding in board.controller.spell_shortcuts(board):
		check(binding["key"] == expected[binding["spell"]], "spell bindings retain elemental positions")
		check(board.controller.Prompts.spell_keys(board, board.controller, binding["spell"]) == [binding["key"]], "visible spell glyph matches dispatched shortcut")
	axis(board, JOY_AXIS_TRIGGER_RIGHT, 1)
	check(not board.playing and not board.controller.attack_held, "RT cannot start an attack during LB shortcuts")
	axis(board, JOY_AXIS_TRIGGER_RIGHT, 0)
	var before: float = board.state.simulation_time
	tap(board, JOY_BUTTON_X)
	check(board.controller.targeting_action == "cold_front" and board.state.potions == 5, "LB+X selects Ice placement, never drinks a potion")
	check(not board.spellbook_open, "placement restores pre-LB drawer state")
	board.controller.disconnected(board, 0)
	check(board.controller.targeting_action == "" and board.controller.paused and board.state.simulation_time == before, "disconnect cancels uncommitted targeting without spending time")
	board.free()
	for discipline in ["trapper", "sapper"]:
		board = fixture()
		board.state.expedition = {"discipline": discipline}
		button(board, JOY_BUTTON_LEFT_SHOULDER)
		tap(board, JOY_BUTTON_DPAD_UP)
		if discipline == "sapper": check(board.controller.targeting_action == "adopted", "Sapper uses exact frozen placement")
		else: check(board.state.player_action["kind"] == "adopted", "Trapper uses directional short-range placement")
		board.free()
	board = fixture()
	board.state.consumable_slots[2] = {"id": "throwing_knife", "count": 2}
	axis(board, JOY_AXIS_RIGHT_X, 1)
	check(not board.controller.show_ranged_guide(board), "melee HUD has no independent aim cursor")
	button(board, JOY_BUTTON_LEFT_SHOULDER)
	check(board.controller.show_ranged_guide(board), "throwable shortcuts reveal directional preview")
	tap(board, JOY_BUTTON_DPAD_RIGHT)
	check(board.state.player_action.get("item_id") == "throwing_knife" and board.state.player_action.get("slot") == 2, "LB+right uses item slot three directly")
	check(Vector2(board.state.player_action["direction"]).dot(board._screen_delta_to_world_direction(Vector2.RIGHT)) > 0.999, "throwing item uses directional ranged aim")
	check(board.state.consumable_slot(2)["count"] == 1, "shortcut consumes exactly one item")
	board.free()

func test_connected_prompts_and_guide() -> void:
	var board = fixture()
	board.controller.active = false
	board.controller.device = -1
	var before: float = board.state.simulation_time
	board.controller.connected(board, 9)
	check(board.controller.active and board.controller.device == 9, "connection displays controller UI without button input")
	check(board.controller.neutral_required, "connection requires neutral input before actions")
	check(board.state.simulation_time == before and not board.playing, "connection does not advance time")
	board.controller.update(board, 0)
	board.controller.paused = true
	var entries: Array = board.controller.menu_entries(board)
	for entry in entries:
		if entry.get("label") == "Controller guide": entry["activate"].call()
	check(board.controller.help_open and board.controller.modal(board), "illustrated guide is reachable from pause menu")
	board.controller.back(board)
	check(not board.controller.help_open and board.controller.paused, "guide back returns to menu, not live movement")
	board.controller.active = false
	board.controller.device = -1
	board.desktop_controls = false
	board.controller.connected(board, 9)
	check(not board.controller.active, "mobile connection preserves touch interface")
	board.free()
	for loadout in ["warrior", "rogue_acrobat", "rogue_sharpshooter", "mage_elementalist"]:
		board = fixture(loadout)
		var rows: Array = board.controller.Prompts.rows(board, board.controller)
		var extra: bool = loadout=="rogue_sharpshooter" and board.state.player_weapon_frame=="bow"
		check(rows.size() == (11 if extra else 10), "all ten primary prompts plus the separate eligible Commit Shot entry")
		if extra:check(rows[10]["label"].contains("Commit Shot") and rows[10]["detail"].contains("+25%"),"additional selection is named with its benefit")
		for row in rows:
			check(board.controller.Glyphs.KEYS.has(row["key"]), "each action references an authored button image")
		check(rows[3]["label"] == board.controller.quick_label(board), "ability prompt names actual class ability")
		check(rows[5]["detail"].contains("5 / 5"), "healing prompt reports remaining charges")
		if loadout == "rogue_sharpshooter": check(rows[0]["detail"].contains("release to fire"), "Bow explains release-to-fire")
		board.free()
	var glyphs = preload("res://scripts/presentation/controller_glyphs.gd")
	var regions: Array = []
	for key in glyphs.KEYS:
		var rect: Rect2 = glyphs.region(key)
		check(not regions.has(rect) and Rect2(0, 0, 320, 256).encloses(rect), "button images have unique valid atlas regions")
		regions.append(rect)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	test_move_and_aim()
	test_attack_defense_and_bow()
	test_modal_safety()
	test_palette_and_setup()
	test_buffer_and_device_isolation()
	test_native_menu()
	test_connected_prompts_and_guide()
	test_directional_and_placed_targeting()
	test_modifier_bindings_and_safety()
	for failure in failures: print("FAILED: ", failure)
	print("Controller input: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
