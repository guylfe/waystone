extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const GameBoardScript = preload("res://scripts/presentation/game_board.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")

func _init() -> void:
	test_initial_sheet_and_gates()
	test_permanent_track_choices()
	test_rally_lifecycle_and_poise()
	test_resolve_is_the_natural_poise_authority()
	test_battle_flow_rules()
	test_advance_requires_and_staggers_a_target()
	test_power_through_and_unbreakable()
	test_authored_enemy_posture_reaches_hits()
	test_evasion_mastery_reward()
	test_fixed_damage_speed_and_resolve()
	test_bandit_awareness_and_secret_passage()
	test_character_sheet_copy_fits_compact_boxes()
	test_current_save_boundary()
	test_old_warrior_run_is_retired_by_overhaul()
	test_v21_major_framework_boundary()
	test_action_layout_separates_context()
	print("Warrior character, progression, action, save, and sheet tests passed.")
	quit()

func fresh_state() -> RunState:
	var state: RunState = RunStateScript.new()
	state.start_run("warrior", "expedition", 630063, "encounter", "recovery", true)
	state.enemies.clear()
	state.walls.clear()
	state.carried_xp = 999
	return state

func fresh_energy_state() -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "expedition", 630063, "encounter", "energy")
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
	assert(state.available_level_up_options().has("vanguard"))
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
	var state := fresh_energy_state()
	state.player_energy = 80.0
	assert(state.request_rally(false))
	advance_until(state, func() -> bool: return state.rally_active)
	assert(state.rally_cooldown == 0.0)
	advance_until(state, func() -> bool: return state.is_player_ready())
	assert(state.rally_active)
	assert(not state.rally_is_available())
	assert(not state.request_rally(false))
	var before_wait := state.player_energy
	assert(state.request_wait(0.50, false))
	advance_until(state, func() -> bool: return state.is_player_ready())
	assert(absf((before_wait - state.player_energy) - 4.0) < 0.15)
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(float(state.player_action.get("guard_capacity", 0.0)) == 5.0)
	var target := state._make_enemy("knife", state.player_pos + Vector2.RIGHT * 80.0, 30)
	target["awareness"] = "alerted"
	var resolved := state._resolve_player_physical_values(target, 10, 2.0, state.player_action)
	assert(int(resolved["damage"]) == 12)
	assert(is_equal_approx(float(resolved["posture"]), 2.4))
	advance_until(state, func() -> bool: return state.is_player_ready())
	assert(state.request_end_rally())
	assert(not state.rally_active)
	assert(state.survey_rally_cancels_total == 1)
	var enduring := fresh_energy_state()
	enduring.track_ranks["warrior"] = 2
	assert(is_equal_approx(enduring._rally_drain_rate(), 6.0))

func test_resolve_is_the_natural_poise_authority() -> void:
	var state := fresh_state()
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(is_equal_approx(float(state.player_action["guard_capacity"]), 3.0))
	state.player_action = state._idle_action()
	state.player_attributes["resolve"] = 5
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(is_equal_approx(float(state.player_action["guard_capacity"]), 2.0))
	state.player_action = state._idle_action()
	state.track_choices["warrior_method"] = "brace"
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 100.0, false))
	assert(is_equal_approx(float(state.player_action["guard_capacity"]), 4.0))
	var hp := state.player_hp
	state._resolve_incoming_hit(90, 10, "authored cut", Vector2.ZERO, Vector2.INF, 3.0)
	assert(String(state.player_action["kind"]) == "attack")
	assert(state.player_hp == hp - 6)
	assert(is_equal_approx(float(state.player_action["guard_remaining"]), 1.0))
	state._resolve_incoming_hit(90, 10, "authored cut", Vector2.ZERO, Vector2.INF, 2.0)
	assert(String(state.player_action["kind"]) == "hit_reaction")

func test_battle_flow_rules() -> void:
	var state := fresh_state()
	state.track_ranks["vanguard"] = 1
	assert(is_equal_approx(state.BATTLE_FLOW_DECAY_SECONDS, 15.0))
	state._register_battle_flow_contact()
	assert(state.battle_flow_pips == 1)
	assert(is_equal_approx(state.battle_flow_remaining, 15.0))
	assert(not state._battle_flow_sequence_complete({"kind":"combo", "phases":[{}, {}], "committed_phase":0}))
	assert(state._battle_flow_sequence_complete({"kind":"combo", "phases":[{}, {}], "committed_phase":1}))
	var action := {"kind":"attack"}
	state._stamp_battle_flow(action)
	assert(is_equal_approx(float(action["battle_flow_damage"]), 1.0 / 6.0))
	assert(is_equal_approx(float(action["battle_flow_posture"]), 1.0 / 12.0))
	state._register_battle_flow_contact()
	state._register_battle_flow_contact()
	state._register_battle_flow_contact()
	assert(state.battle_flow_pips == 3)
	state._break_battle_flow()
	assert(state.battle_flow_pips == 0)
	state.track_ranks["vanguard"] = 3
	state.battle_flow_pips = 3
	state._break_battle_flow()
	assert(state.battle_flow_pips == 2)
	var unshaken := fresh_state()
	unshaken.track_ranks["vanguard"] = 2
	unshaken.track_choices["flow_discipline"] = "unshaken"
	unshaken.battle_flow_pips = 2
	unshaken.battle_flow_remaining = unshaken.BATTLE_FLOW_DECAY_SECONDS
	unshaken._resolve_incoming_hit(89, 10, "ordinary hit", Vector2.ZERO, Vector2.INF, 1.0)
	assert(String(unshaken.player_action["kind"]) == "hit_reaction")
	assert(unshaken.battle_flow_pips == 2)
	state.track_ranks["vanguard"] = 4
	state.battle_flow_pips = 4
	action = {"kind":"combo"}
	state._stamp_battle_flow(action)
	assert(is_equal_approx(float(action["battle_flow_damage"]), 0.8))
	assert(is_equal_approx(float(action["battle_flow_posture"]), 0.4))
	state.track_choices["flow_discipline"] = "sword_dance"
	state.player_action = state._idle_action()
	assert(state.request_dodge(Vector2.RIGHT, false))
	assert(state.battle_flow_pips == 4)
	state.battle_flow_remaining = state.SIM_DT * 0.5
	state.advance_streamed_action_tick()
	assert(state.battle_flow_pips == 3)

func test_advance_requires_and_staggers_a_target() -> void:
	var state := fresh_state()
	assert(not state.request_advance(Vector2.RIGHT, false, false))
	state.track_ranks["vanguard"] = 1
	var enemy := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 105.0, 80)
	enemy["awareness"] = "alerted"
	enemy["posture"] = 99.0
	enemy["posture_max"] = 99.0
	state.enemies.append(enemy)
	state._invalidate_active_enemy_cache()
	assert(state.request_advance(Vector2.RIGHT.rotated(0.12), false, false))
	assert(int(state.player_action["damage_min"]) == 15)
	assert(is_equal_approx(float(state.player_action["posture_damage"]), 6.0))
	assert(is_equal_approx(float(state.player_action["push"]), 40.0))
	assert(Vector2(state.player_action["direction"]).dot(Vector2.RIGHT) > 0.999)
	state._resolve_advance_impact()
	assert(String(state.enemies[0]["action"]["kind"]) == "hit_reaction")
	assert(state.battle_flow_pips == 0)
	state.battle_flow_pips = 2
	state.battle_flow_remaining = 0.5
	state._register_battle_flow_contact(true)
	assert(state.battle_flow_pips == 2)
	assert(is_equal_approx(state.battle_flow_remaining, state.BATTLE_FLOW_DECAY_SECONDS))

func test_power_through_and_unbreakable() -> void:
	var state := fresh_state()
	state.track_ranks["warrior"] = 4
	state.player_action = state._action("attack", 1.0, Vector2.RIGHT)
	state._apply_action_poise(state.player_action)
	var hp := state.player_hp
	state._resolve_incoming_hit(91, 14, "direct cut", Vector2.ZERO, Vector2.INF, 1.0)
	assert(state.player_hp == hp - 8)
	assert(String(state.player_action["kind"]) == "attack")
	assert(state.survey_power_through_triggers_total == 1)
	var hazard := fresh_state()
	hazard.track_ranks["warrior"] = 4
	hazard.player_action = hazard._action("attack", 1.0, Vector2.RIGHT)
	hazard._apply_action_poise(hazard.player_action)
	hp = hazard.player_hp
	hazard._resolve_incoming_hit(92, 14, "burning ground", Vector2.ZERO, Vector2.INF, 1.0, "", false)
	assert(hazard.player_hp == hp - 10)
	var master := fresh_state()
	master.track_ranks["warrior"] = 5
	master.rally_active = true
	master.player_action = master._action("attack", 1.0, Vector2.RIGHT)
	master._apply_action_poise(master.player_action)
	master._resolve_incoming_hit(93, 14, "crushing blow", Vector2.ZERO, Vector2.INF, 100.0)
	assert(String(master.player_action["kind"]) == "attack")
	assert(is_equal_approx(master.player_posture, 0.0))
	assert(master.survey_unbreakable_suppressions_total == 1)

func test_authored_enemy_posture_reaches_hits() -> void:
	var state := fresh_state()
	var option := Dictionary(CombatCatalogScript.melee_attack_plan("blade")[0])
	var action := state._intent_melee_action(option, Vector2.LEFT)
	assert(is_equal_approx(float(action["posture"]), 3.0))
	var before := state.player_posture
	state._resolve_incoming_hit(94, int(action["damage"]), "blade", Vector2.ZERO, Vector2.INF, float(action["posture"]))
	assert(is_equal_approx(state.player_posture, before - 3.0))
	var archer := state._make_enemy("archer", state.player_pos + Vector2.UP * 200.0, 25)
	archer["facing"] = Vector2.DOWN
	state._spawn_projectile(archer)
	assert(is_equal_approx(float(state.projectiles[-1]["posture"]), 2.0))

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
	assert(int(definition["damage_min"]) == 10 and int(definition["damage_max"]) == 10)
	assert(is_equal_approx(state._player_personal_tempo(), 1.0))
	state.player_attributes["speed"] = 6
	assert(is_equal_approx(state._player_personal_tempo(), 1.03))
	state.player_attributes["resolve"] = 9
	state._refresh_player_posture_capacity(true)
	assert(is_equal_approx(state.player_posture_max, 14.0))
	state.player_action = state._idle_action()
	# Posture is authored beside damage as of 0.2.60 rather than derived from it, so this
	# passes the figure the Blade's plan carries instead of relying on a x1.5 conversion.
	state._resolve_incoming_hit(900, 14, "test", Vector2.ZERO, Vector2.INF, 3.0)
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
	state.start_run("warrior", "expedition", 630063, "encounter", "recovery", true) # Legacy secret passage, retained for old saves.
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
	assert(is_equal_approx(loaded.player_energy, state.player_energy))
	assert(is_equal_approx(loaded.player_max_energy, state.player_max_energy))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_old_warrior_run_is_retired_by_overhaul() -> void:
	var path := "user://warrior-v25-energy-migration.save"
	var state := fresh_state()
	state.track_choices["steadfast_1"] = "vigilance"
	state.track_ranks["steadfast"] = 1
	state.player_attributes["speed"] = int(state.player_attributes["speed"]) + 1
	state.player_attributes["awareness"] = int(state.player_attributes["awareness"]) + 1
	assert(state.save_run(path))
	var reader := FileAccess.open(path, FileAccess.READ)
	var payload: Dictionary = reader.get_var(true)
	reader.close()
	payload["save_version"] = 25
	payload.erase("player_energy")
	payload.erase("player_max_energy")
	payload.erase("player_overexertion_pending")
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(payload, true)
	writer.close()
	var loaded: RunState = RunStateScript.new(false)
	assert(loaded.load_run(path))
	assert(not loaded.run_active)
	assert(loaded.message.contains("Warrior and Vanguard overhaul requires a new run"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_v21_major_framework_boundary() -> void:
	var path := "user://warrior-v21-framework-test.save"
	var state := fresh_state()
	state.potions = 3
	assert(state.save_run(path))
	var reader := FileAccess.open(path, FileAccess.READ)
	var payload: Dictionary = reader.get_var(true)
	reader.close()
	payload["save_version"] = 21
	var writer := FileAccess.open(path, FileAccess.WRITE)
	writer.store_var(payload, true)
	writer.close()
	var loaded: RunState = RunStateScript.new(false)
	assert(loaded.load_run(path))
	assert(not loaded.run_active)
	assert(loaded.player_max_hp == 100 and loaded.healing_capacity() == 5)
	assert(loaded.message.contains("requires a new run"))
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
