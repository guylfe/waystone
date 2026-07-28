extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const GameBoardScript = preload("res://scripts/presentation/game_board.gd")

func _init() -> void:
	test_initial_sheet_and_gates()
	test_permanent_track_choices()
	test_rally_lifecycle_and_poise()
	test_advance_momentum_chain()
	test_evasion_mastery_reward()
	test_v19_save_boundary()
	test_action_layout_separates_context()
	print("Warrior character, progression, action, save, and sheet tests passed.")
	quit()

func fresh_state() -> RunState:
	var state: RunState = RunStateScript.new()
	state.start_run("warrior", "expedition", 630063)
	state.enemies.clear()
	state.walls.clear()
	state.carried_xp = 999
	return state

func advance_until(state: RunState, condition: Callable, limit: int = 2000) -> void:
	var ticks := 0
	while not condition.call() and ticks < limit:
		state.advance_streamed_action_tick()
		ticks += 1
	assert(ticks < limit)

func test_initial_sheet_and_gates() -> void:
	var state := fresh_state()
	var sheet := state.character_sheet_data()
	assert(String(sheet["name"]) == "Warrior · Vanguard")
	var tracks: Array = sheet["tracks"]
	assert(tracks.size() == 6)
	assert(String(Dictionary(tracks[0])["id"]) == "swordsmanship")
	assert(String(Dictionary(tracks[5])["id"]) == "adopted")
	assert(state.character_level() == 1)
	assert(state.next_upgrade_cost() == 6)
	var options := state.available_level_up_options()
	assert(options == ["swordsmanship", "evasion", "warrior", "vanguard"])

func test_permanent_track_choices() -> void:
	var state := fresh_state()
	assert(state.choose_upgrade("swordsmanship|prototype_sweeping_cut"))
	assert(state.character_level() == 2)
	assert(state.track_choice("sword_art") == "prototype_sweeping_cut")
	assert(state.player_equipped_weapon_art == "prototype_sweeping_cut")
	assert(not state.choose_upgrade("swordsmanship|prototype_drawing_cut"))
	assert(state.choose_upgrade("vanguard"))
	assert(state.character_level() == 3)
	assert(state.choose_upgrade("vanguard|breakthrough"))
	assert(state.track_choice("advance_style") == "breakthrough")
	assert(not state.can_swap_weapon_art())

func test_rally_lifecycle_and_poise() -> void:
	var state := fresh_state()
	assert(state.request_rally(false))
	advance_until(state, func() -> bool: return state.rally_remaining > 0.0)
	assert(state.rally_cooldown == 0.0)
	advance_until(state, func() -> bool: return state.is_player_ready())
	assert(state.rally_remaining > 0.0)
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(float(state.player_action.get("guard_capacity", 0.0)) == 4.0)
	advance_until(state, func() -> bool: return state.is_player_ready())
	while state.rally_remaining > 0.0:
		assert(state.request_wait(0.50, false))
		advance_until(state, func() -> bool: return state.is_player_ready())
	assert(state.rally_cooldown > 0.0)

func test_advance_momentum_chain() -> void:
	var state := fresh_state()
	state.track_ranks["vanguard"] = 3
	state.track_choices["advance_style"] = "pursuit"
	assert(state.request_advance(Vector2.RIGHT, true, false))
	advance_until(state, func() -> bool: return String(state.player_action["kind"]) == "combo")
	assert(bool(state.player_action.get("continue_held", false)))
	assert(String(state.player_action.get("ability_id", "")) == "sword_combo")

func test_evasion_mastery_reward() -> void:
	var state := fresh_state()
	state.track_ranks["evasion"] = 4
	state.track_choices["evasion_style"] = "sidestep"
	assert(state.request_dodge(Vector2.RIGHT, false))
	advance_until(state, func() -> bool: return float(state.player_action["elapsed"]) >= 0.10)
	var hp := state.player_hp
	state._resolve_incoming_hit(99, 2, "test strike", state.player_pos - Vector2.RIGHT, state.player_pos)
	assert(state.player_hp == hp)
	assert(state.counterstep_remaining > 0.0)
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false) == false)
	advance_until(state, func() -> bool: return state.is_player_ready())
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(float(state.player_action["startup"]) < 0.30)
	assert(state.counterstep_remaining == 0.0)

func test_v19_save_boundary() -> void:
	var path := "user://warrior-v19-test.save"
	var state := fresh_state()
	assert(state.choose_upgrade("evasion"))
	assert(state.request_dodge(Vector2.RIGHT, false))
	assert(state.save_run(path))
	var loaded: RunState = RunStateScript.new()
	assert(loaded.load_run(path))
	assert(loaded.loadout_id == "warrior")
	assert(int(loaded.track_ranks["evasion"]) == 1)
	assert(String(loaded.player_action["kind"]) == "idle")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_action_layout_separates_context() -> void:
	var board = GameBoardScript.new()
	board.state = fresh_state()
	board.visual = board.state.snapshot()
	board.desktop_controls = true
	board.size = Vector2(1280, 800)
	board._create_seed_input()
	board._layout()
	assert(board.buttons.keys() == ["defense", "skill", "rally", "advance", "adopted"])
	assert(not board.buttons.has("wait"))
	assert(board.interaction_rect.size.x > 0.0 and board.interaction_rect.size.y > 0.0)
	for rect in board.buttons.values():
		assert(Rect2(Vector2.ZERO, board.size).encloses(Rect2(rect)))
	assert(Rect2(Vector2.ZERO, board.size).encloses(board.interaction_rect))
	board.free()
