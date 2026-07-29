extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const GameBoardScript = preload("res://scripts/presentation/game_board.gd")

func _init() -> void:
	test_initial_sheet_and_gates()
	test_permanent_track_choices()
	test_rally_lifecycle_and_poise()
	test_advance_momentum_chain()
	test_evasion_mastery_reward()
	test_fixed_damage_speed_and_resolve()
	test_bandit_awareness_and_secret_passage()
	test_character_sheet_copy_fits_compact_boxes()
	test_current_save_boundary()
	test_v19_potion_capacity_migration()
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
	assert(state.healing_capacity() == 5 and state.potions == 5)
	assert(not state.has_infinite_potions())
	var options := state.available_level_up_options()
	assert(options == ["swordsmanship", "evasion", "steadfast"])
	assert(state.choose_upgrade("steadfast|toughness"))
	assert(state.character_level() == 2)
	assert(state.available_level_up_options().has("warrior"))
	assert(not state.available_level_up_options().has("vanguard"))
	assert(state.choose_upgrade("evasion"))
	assert(state.character_level() == 3)
	assert(state.available_level_up_options().has("vanguard"))

func test_permanent_track_choices() -> void:
	var state := fresh_state()
	assert(state.choose_upgrade("swordsmanship|prototype_sweeping_cut"))
	assert(state.character_level() == 2)
	assert(state.track_choice("sword_art") == "prototype_sweeping_cut")
	assert(state.player_equipped_weapon_art == "prototype_sweeping_cut")
	assert(not state.choose_upgrade("swordsmanship|prototype_drawing_cut"))
	assert(state.choose_upgrade("evasion"))
	assert(state.character_level() == 3)
	assert(state.choose_upgrade("vanguard"))
	assert(state.track_total("vanguard") == 1)
	assert(not state.can_swap_weapon_art())

func test_rally_lifecycle_and_poise() -> void:
	var state := fresh_state()
	assert(state.request_rally(false))
	advance_until(state, func() -> bool: return state.rally_remaining > 0.0)
	assert(state.rally_cooldown == 0.0)
	advance_until(state, func() -> bool: return state.is_player_ready())
	assert(state.rally_remaining > 0.0)
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(float(state.player_action.get("guard_capacity", 0.0)) == 5.0)
	advance_until(state, func() -> bool: return state.is_player_ready())
	while state.rally_remaining > 0.0:
		assert(state.request_wait(0.50, false))
		advance_until(state, func() -> bool: return state.is_player_ready())
	assert(state.rally_cooldown > 0.0)

func test_advance_momentum_chain() -> void:
	var state := fresh_state()
	state.track_ranks["vanguard"] = 2
	assert(state.request_advance(Vector2.RIGHT, true, false))
	advance_until(state, func() -> bool: return String(state.player_action["kind"]) == "combo")
	assert(bool(state.player_action.get("continue_held", false)))
	assert(String(state.player_action.get("ability_id", "")) == "sword_combo")

func test_evasion_mastery_reward() -> void:
	var state := fresh_state()
	state.track_ranks["evasion"] = 3
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

func test_fixed_damage_speed_and_resolve() -> void:
	var state := fresh_state()
	var definition := state.player_basic_attack_definition()
	assert(int(definition["damage_min"]) == 2 and int(definition["damage_max"]) == 2)
	assert(is_equal_approx(state._player_personal_tempo(), 1.0))
	state.player_attributes["speed"] = 6
	assert(is_equal_approx(state._player_personal_tempo(), 1.03))
	state.player_attributes["resolve"] = 9
	state._refresh_player_posture_capacity(true)
	assert(is_equal_approx(state.player_posture_max, 14.0))
	state.player_action = state._idle_action()
	state._resolve_incoming_hit(900, 2, "test")
	assert(is_equal_approx(state.player_posture, 11.0))
	state.enemies.clear()
	state.player_posture_recovery_delay = 0.0
	state.player_action = state._idle_action()
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	var posture_before := state.player_posture
	state.advance_streamed_action_tick()
	assert(state.player_posture > posture_before)
	state.track_ranks["evasion"] = 1
	state.player_action = state._idle_action()
	state.dodge_cooldown = 0.0
	assert(state.request_dodge(Vector2.RIGHT, false))
	assert(is_equal_approx(state.dodge_cooldown, 3.6))

func test_bandit_awareness_and_secret_passage() -> void:
	var state := fresh_state()
	var bandit := state._make_enemy("bandit", state.player_pos + Vector2.RIGHT * 360.0, 5)
	assert(not state.enemy_visible_to_player(bandit))
	bandit["awareness"] = "alerted"
	state._update_bandit_concealment(bandit, 0.1)
	assert(not state.enemy_visible_to_player(bandit))
	state.player_attributes["awareness"] = 10
	state._update_bandit_concealment(bandit, 0.1)
	assert(state.enemy_visible_to_player(bandit))
	assert(not state.secret_passages.is_empty())
	var secret: Dictionary = state.secret_passages[0]
	state.player_attributes["awareness"] = 5
	state.current_area_id = int(secret["area_id"])
	state.player_pos = Vector2(secret["reveal_pos"])
	state._apply_shortcut_world_state()
	assert(not state._position_blocked_static(state.player_pos, state.PLAYER_RADIUS))
	assert(state._update_secret_passages())
	assert(bool(state.secret_passages[0]["revealed"]))
	assert(state.world_pickups.any(func(value: Dictionary) -> bool: return String(value.get("id", "")) == "secret_rejuvenation_old_road"))

func test_character_sheet_copy_fits_compact_boxes() -> void:
	var board = GameBoardScript.new()
	var state := fresh_state()
	board.state = state
	for track_value in Array(state.character_sheet_data()["tracks"]):
		var track := Dictionary(track_value)
		var track_label := String(track["label"]).to_upper()
		var track_font := board._sheet_fit_font_size(track_label, 100.0, 12, 6)
		assert(board._sheet_text_width(track_label, track_font) <= 100.01)
		for stage_value in Array(track.get("stages", [])):
			var stage := Dictionary(stage_value)
			var label := String(stage.get("label", "")).to_upper()
			var label_font := board._sheet_fit_font_size(label, 118.0, 11, 5)
			assert(board._sheet_text_width(label, label_font) <= 118.01)
			var detail_layout := board._sheet_text_layout(String(stage.get("description", "")), 360.0, 90.0, 12, 7)
			assert(bool(detail_layout["fits"]), "stage copy overflow: %s" % stage.get("id", ""))
			for choice_value in Array(stage.get("choices", [])):
				var choice := Dictionary(choice_value)
				var choice_layout := board._sheet_text_layout(String(choice.get("description", "")), 180.0, 68.0, 10, 6)
				assert(bool(choice_layout["fits"]), "choice copy overflow: %s" % choice.get("id", ""))
	board.free()

func test_current_save_boundary() -> void:
	var path := "user://warrior-current-save-test.save"
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

func test_v19_potion_capacity_migration() -> void:
	var path := "user://warrior-v19-potion-test.save"
	var state := fresh_state()
	state.potions = 3
	assert(state.save_run(path))
	var reader := FileAccess.open(path, FileAccess.READ)
	var payload: Dictionary = reader.get_var(true)
	reader.close()
	payload["save_version"] = 19
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(payload, true)
	writer.close()
	var loaded: RunState = RunStateScript.new(false)
	assert(loaded.load_run(path))
	assert(loaded.healing_capacity() == 5 and loaded.potions == 5)
	assert(loaded.message.contains("refunded as XP"))
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
	assert(board.interaction_rect.end.y < Rect2(board.consumable_rects["healing"]).position.y)
	for rect in board.buttons.values():
		assert(Rect2(Vector2.ZERO, board.size).encloses(Rect2(rect)))
	assert(Rect2(Vector2.ZERO, board.size).encloses(board.interaction_rect))
	board.free()
