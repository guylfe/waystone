extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const AbilityCatalogScript = preload("res://scripts/core/ability_catalog.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func open_state() -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "boss_lab", 295295, "encounter", "energy")
	state.walls.clear()
	state._build_wall_spatial_index()
	state.barriers.clear()
	state.player_pos = Vector2(850.0, 700.0)
	state.player_action = state._idle_action()
	state._replace_enemy_actors([])
	state._next_enemy_id = 1
	return state

func put_wolf(state: RunState, position: Vector2) -> Dictionary:
	var wolf := state._make_enemy("werewolf", position, 210, 5)
	wolf["layer"] = state.current_layer
	wolf["awareness"] = "alerted"
	wolf["alert_remaining"] = 20.0
	state._replace_enemy_actors([wolf])
	return wolf

func test_authored_world_timing_and_phase_one_loop() -> void:
	var state := open_state()
	var wolf := put_wolf(state, state.player_pos + Vector2.LEFT * 130.0)
	var tempo := state._enemy_personal_tempo(wolf)
	var rake := state._werewolf_attack_action(wolf, "double_rake", Vector2.RIGHT)
	check(is_equal_approx(float(rake["first_start"]) / tempo, 0.46) and is_equal_approx(float(rake["second_end"]) / tempo, 1.00),
		"Double Rake must preserve its authored world-time contacts")
	check(int(rake["damage"]) == 12 and float(rake["posture"]) == 3.0 and float(rake["reach"]) == 148.0,
		"Double Rake must carry its promised damage, posture, and reach")
	wolf["action"] = rake
	wolf["action"]["elapsed"] = float(rake["duration"]) - 0.01
	state._update_enemies(0.03, false)
	check(bool(wolf["boss_stalk_available"]), "a completed Werewolf attack must permit one visible stalk")
	var missed_events := state.survey_enemy_action_events.filter(func(event: Dictionary) -> bool: return String(event.get("event", "")) == "missed")
	check(missed_events.size() == 1, "a Double Rake with no contacts must report one missed boss action")
	state._choose_enemy_action(wolf)
	check(String(Dictionary(wolf["action"]).get("intent", "")) == "werewolf_stalk" and not bool(wolf["boss_stalk_available"]),
		"the inter-attack stalk must be explicit, finite, and consumed once")
	check(float(Dictionary(wolf["action"])["duration"]) / tempo <= 0.501,
		"the Werewolf stalk must last at most 0.50 world seconds")

	state = open_state()
	state.player_pos = Vector2(1200.0, 700.0)
	wolf = put_wolf(state, Vector2(500.0, 700.0))
	state._choose_enemy_action(wolf)
	check(String(Dictionary(wolf["action"])["kind"]) == "move",
		"an unreachable leap must use ordinary navigation instead of spending an attack")

	state = open_state()
	wolf = put_wolf(state, state.player_pos + Vector2.LEFT * 130.0)
	wolf["conditions"]["frost"] = state.FROST_FULL_DURATION
	var frozen_rake := state._werewolf_attack_action(wolf, "double_rake", Vector2.RIGHT)
	var frozen_world_startup := float(frozen_rake["first_start"]) / state._enemy_personal_tempo(wolf)
	check(frozen_world_startup > 0.52,
		"Frost must lengthen the Werewolf's world-time commitment rather than being cancelled at creation")

func test_leap_lands_once_and_uses_shared_collision() -> void:
	var state := open_state()
	# Verify the authored impact independently of the Warrior loadout's ordinary
	# physical mitigation; armour behaviour is covered by the shared hit tests.
	state.player_attributes["defense"] = 0
	state.player_properties["armor"] = 0
	state.player_pos = Vector2(650.0, 700.0)
	var wolf := put_wolf(state, Vector2(500.0, 700.0))
	var leap := state._werewolf_attack_action(wolf, "hunting_leap", Vector2.RIGHT)
	wolf["action"] = leap
	leap["elapsed"] = float(leap["startup"])
	var before_hp := state.player_hp
	state._resolve_werewolf_leap_tick(wolf, float(leap["startup"]) - 0.01, float(leap["startup"]), 0.12 * state._enemy_personal_tempo(wolf))
	check(bool(leap["landed"]) and bool(leap["pounce_hit"]), "Hunting Leap must land when its one impact reaches the player")
	check(before_hp - state.player_hp == 20, "Hunting Leap must deal exactly one 20-damage impact")
	var after_impact := state.player_hp
	state._resolve_werewolf_leap_tick(wolf, float(leap["elapsed"]), float(leap["elapsed"]) + 0.2, 0.2 * state._enemy_personal_tempo(wolf))
	check(state.player_hp == after_impact, "a landed leap must never damage the player a second time")

	state = open_state()
	wolf = put_wolf(state, Vector2(500.0, 700.0))
	var hound := state._make_enemy("hound", Vector2(600.0, 700.0), 32, 5)
	hound["layer"] = state.current_layer
	state._replace_enemy_actors([wolf, hound])
	leap = state._werewolf_attack_action(wolf, "hunting_leap", Vector2.RIGHT)
	var motion := state._move_charging_actor(wolf, Vector2(wolf["pos"]), Vector2.RIGHT * 120.0, leap)
	check(Vector2(motion["position"]).x > 500.0 and Array(leap.get("vaulted_ally_ids", [])).has(int(hound["id"])),
		"Werewolf leaps must vault friendly Hounds through the shared charge authority")

func test_bounding_rake_crash_and_followup_contract() -> void:
	var state := open_state()
	state.player_pos = Vector2(1000.0, 700.0)
	var wolf := put_wolf(state, Vector2(500.0, 700.0))
	state.walls.assign([Rect2(Vector2(545.0, 620.0), Vector2(40.0, 160.0))])
	state._build_wall_spatial_index()
	var bound := state._werewolf_attack_action(wolf, "bounding_rake", Vector2.RIGHT)
	wolf["action"] = bound
	bound["elapsed"] = float(bound["startup"])
	state._resolve_werewolf_leap_tick(wolf, float(bound["startup"]) - 0.01, float(bound["startup"]), 0.10 * state._enemy_personal_tempo(wolf))
	check(bool(bound["crashed"]) and bool(bound["claw_cancelled"]),
		"solid terrain must cancel Bounding Rake's declared claw rather than repairing the landing")
	check(is_equal_approx((float(bound["duration"]) - float(bound["pounce_end"])) / state._enemy_personal_tempo(wolf), 1.10),
		"a Bounding Rake terrain collision must create the 1.10-world-second crash opening")

	state = open_state()
	state.player_pos = Vector2(1000.0, 1000.0)
	wolf = put_wolf(state, Vector2(500.0, 700.0))
	state.walls.assign([Rect2(Vector2(540.0, 680.0), Vector2(40.0, 180.0))])
	state._build_wall_spatial_index()
	bound = state._werewolf_attack_action(wolf, "bounding_rake", Vector2(1.0, 1.0).normalized())
	wolf["action"] = bound
	bound["elapsed"] = float(bound["startup"])
	state._resolve_werewolf_leap_tick(wolf, float(bound["startup"]) - 0.01, float(bound["startup"]), 0.10 * state._enemy_personal_tempo(wolf))
	check(bool(bound["crashed"]),
		"a diagonal leap must crash when its committed line meets terrain instead of sliding along the wall")

	state = open_state()
	wolf = put_wolf(state, Vector2(500.0, 700.0))
	bound = state._werewolf_attack_action(wolf, "bounding_rake", Vector2.RIGHT)
	wolf["action"] = bound
	state._finish_werewolf_leap(wolf, bound, float(bound["startup"]) + 0.30)
	check(is_equal_approx((float(bound["followup_start"]) - float(bound["pounce_end"])) / state._enemy_personal_tempo(wolf), 0.36),
		"Bounding Rake's claw must be scheduled from the actual landing, not its nominal timeline")
	check(is_equal_approx((float(bound["followup_end"]) - float(bound["followup_start"])) / state._enemy_personal_tempo(wolf), 0.16),
		"Bounding Rake must expose one declared 0.16-world-second claw contact")

func test_posture_break_latches_only_through_committed_contact() -> void:
	var state := open_state()
	var wolf := put_wolf(state, Vector2(500.0, 700.0))
	var leap := state._werewolf_attack_action(wolf, "hunting_leap", Vector2.RIGHT)
	wolf["action"] = leap
	leap["elapsed"] = float(leap["startup"]) + 0.05
	check(not state._apply_posture_damage(wolf, 99.0, Vector2(wolf["pos"]), "player", "test"),
		"an airborne posture break must latch rather than interrupt flight")
	check(bool(wolf["boss_posture_break_pending"]) and String(Dictionary(wolf["action"])["kind"]) == "pounce_combo",
		"the latched break must preserve the current leap until landing")
	state._finish_werewolf_leap(wolf, leap, float(leap["elapsed"]) + 0.10)
	check(not bool(wolf["boss_posture_break_pending"]) and String(Dictionary(wolf["action"])["kind"]) == "stagger",
		"the first landing after a latched break must release one real posture opening")

	state = open_state()
	wolf = put_wolf(state, Vector2(500.0, 700.0))
	var rake := state._werewolf_attack_action(wolf, "double_rake", Vector2.RIGHT)
	wolf["action"] = rake
	rake["elapsed"] = float(rake["second_end"]) + 0.05
	check(state._apply_posture_damage(wolf, 99.0, Vector2(wolf["pos"]), "player", "test") and String(Dictionary(wolf["action"])["kind"]) == "stagger",
		"a grounded recovery posture break must interrupt immediately")

func test_phase_transition_waits_and_retry_resets() -> void:
	var state := open_state()
	var wolf := put_wolf(state, Vector2(500.0, 700.0))
	wolf["hp"] = 115
	wolf["action"] = state._werewolf_attack_action(wolf, "double_rake", Vector2.RIGHT)
	state._queue_werewolf_phase(wolf)
	check(bool(wolf["boss_phase_pending"]) and String(Dictionary(wolf["action"])["kind"]) == "claw_combo",
		"the 55-percent phase threshold must queue without erasing a current action")
	wolf["action"] = state._idle_action()
	check(state._begin_werewolf_phase_change(wolf) and String(Dictionary(wolf["action"])["kind"]) == "phase_change",
		"an idle queued boss must begin the explicit non-damaging posture change")
	wolf["action"]["elapsed"] = float(Dictionary(wolf["action"])["duration"]) - 0.01
	state._update_enemies(0.03, false)
	check(int(wolf["boss_phase"]) == 2 and not bool(wolf["boss_phase_pending"]),
		"the completed posture change must enter phase two exactly once")

	state.boss_lab_initial_setup = {"boss_kind":"werewolf", "boss_variant":"solo_current", "arena":"open_ring", "loadout_id":"warrior", "combat_rules":"energy", "run_seed":295295}
	check(state.retry_boss_lab(), "Boss Lab must retain exact Werewolf retry")
	check(state.enemies.size() == 1 and int(state.enemies[0].get("boss_phase", 0)) == 1 and int(state.enemies[0].get("boss_attack_index", -1)) == 0,
		"retry must reconstruct phase and deterministic repertoire state from the initial setup")

func _init() -> void:
	check(AbilityCatalogScript.validate_catalog().is_empty(), "Werewolf ability definitions must satisfy the canonical catalog")
	test_authored_world_timing_and_phase_one_loop()
	test_leap_lands_once_and_uses_shared_collision()
	test_bounding_rake_crash_and_followup_contract()
	test_posture_break_latches_only_through_committed_contact()
	test_phase_transition_waits_and_retry_resets()
	if failures.is_empty():
		print("WEREWOLF BOSS TESTS PASSED")
		quit(0)
		return
	for failure in failures: push_error("FAILED: %s" % failure)
	quit(1)
