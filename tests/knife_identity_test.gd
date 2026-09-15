extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func open_state() -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 294294, "encounter", "energy")
	state.walls.clear()
	state._build_wall_spatial_index()
	state.barriers.clear()
	state.player_pos = Vector2(850.0, 700.0)
	state.player_facing = Vector2.UP
	state.player_action = state._idle_action()
	state._replace_enemy_actors([])
	state._next_enemy_id = 1
	return state

func put_knife(state: RunState, position: Vector2) -> Dictionary:
	var knife := state._make_enemy("knife", position, 20, 5)
	knife["layer"] = state.current_layer
	knife["awareness"] = "alerted"
	knife["alert_remaining"] = 8.0
	state._replace_enemy_actors([knife])
	return knife

func test_flank_side_is_stable_and_announced() -> void:
	var state := open_state()
	var knife := put_knife(state, Vector2(450.0, 700.0))
	state._choose_enemy_action(knife)
	var first: Dictionary = knife["action"]
	var side := int(knife["knife_flank_side"])
	var bearing := Vector2(knife["knife_flank_bearing"])
	var first_target := Vector2(first["target"])
	check(String(first.get("kind", "")) == "move" and String(first.get("intent", "")) == "knife_flank",
		"a distant Knife must visibly enter flank preparation")
	check(String(first.get("label", "")) == "flank_preparation" and int(first.get("lane_side", 0)) == side,
		"the movement action must expose its promised flank side to presentation")
	check(side != 0 and bearing.length_squared() > 0.99,
		"flank preparation must hold a real side and world bearing")

	var player_step := Vector2(24.0, 18.0)
	state.player_pos += player_step
	knife["action"] = state._idle_action()
	state._choose_enemy_action(knife)
	var second: Dictionary = knife["action"]
	check(int(knife["knife_flank_side"]) == side and Vector2(knife["knife_flank_bearing"]).is_equal_approx(bearing),
		"minor target movement must not make a Knife swap or rotate its chosen side")
	check(Vector2(second["target"]).distance_to(first_target + player_step) < 0.01,
		"the held flank lane must translate with minor target movement")

func test_major_displacement_and_blocked_lanes_fall_back_to_motion() -> void:
	var state := open_state()
	var knife := put_knife(state, Vector2(450.0, 700.0))
	state._choose_enemy_action(knife)
	state.player_pos += Vector2(0.0, state.KNIFE_FLANK_MAJOR_DISPLACEMENT + 20.0)
	knife["action"] = state._idle_action()
	state._choose_enemy_action(knife)
	var displaced: Dictionary = knife["action"]
	check(bool(knife["knife_flank_abandoned"]) and String(displaced.get("intent", "")) == "knife_direct",
		"major target displacement must invalidate the old lane and resume direct pursuit")
	check(Vector2(displaced.get("target", Vector2.INF)).is_equal_approx(state.player_pos),
		"the invalidated flank must pursue the player rather than stand still")

	state = open_state()
	knife = put_knife(state, Vector2(450.0, 700.0))
	var distance := float(Dictionary(Array(CombatCatalogScript.melee_attack_plan("knife"))[0])["distance"])
	state.walls.assign([
		Rect2(state.player_pos + Vector2.LEFT * distance - Vector2(34.0, 34.0), Vector2(68.0, 68.0)),
		Rect2(state.player_pos + Vector2.RIGHT * distance - Vector2(34.0, 34.0), Vector2(68.0, 68.0)),
	])
	state._build_wall_spatial_index()
	state._choose_enemy_action(knife)
	var blocked: Dictionary = knife["action"]
	check(bool(knife["knife_flank_abandoned"]) and String(blocked.get("kind", "")) == "move",
		"two blocked side lanes must produce direct movement, never an idle wait")
	check(Vector2(blocked.get("direction", Vector2.ZERO)).length_squared() > 0.01,
		"a lone Knife with blocked flank lanes must remain active")

func test_flank_attempt_has_a_world_time_budget() -> void:
	var state := open_state()
	var knife := put_knife(state, Vector2(450.0, 700.0))
	state._choose_enemy_action(knife)
	knife["knife_flank_elapsed"] = state.KNIFE_FLANK_ATTEMPT_SECONDS - 0.01
	state._update_enemies(0.02, false)
	check(bool(knife["knife_flank_abandoned"]),
		"flank preparation must expire after roughly one world second")
	check(String(Dictionary(knife["action"]).get("kind", "")) == "idle",
		"the expired flank step must finish so the next decision can pursue directly")
	state._choose_enemy_action(knife)
	check(String(Dictionary(knife["action"]).get("intent", "")) == "knife_direct",
		"an expired flank attempt must immediately become direct pursuit")

func test_quick_cut_contract_is_unchanged() -> void:
	var state := open_state()
	var knife := put_knife(state, state.player_pos + Vector2.LEFT * 105.0)
	var plan: Dictionary = Dictionary(Array(CombatCatalogScript.melee_attack_plan("knife"))[0])
	state._choose_enemy_action(knife)
	var action: Dictionary = knife["action"]
	check(String(action.get("kind", "")) == "melee" and String(action.get("technique_id", "")) == "quick_cut",
		"a Knife at normal range must still use the existing quick cut")
	check(is_equal_approx(float(action.get("startup", -1.0)), float(plan["startup"])) and is_equal_approx(float(action.get("duration", -1.0)), float(plan["duration"])),
		"flank preparation must not change quick-cut startup or recovery")
	check(not bool(action.get("invulnerable", false)),
		"the Knife's approach and cut must not introduce free invulnerability")

func _init() -> void:
	test_flank_side_is_stable_and_announced()
	test_major_displacement_and_blocked_lanes_fall_back_to_motion()
	test_flank_attempt_has_a_world_time_budget()
	test_quick_cut_contract_is_unchanged()
	if failures.is_empty():
		print("KNIFE IDENTITY TESTS PASSED")
		quit(0)
		return
	for failure in failures: push_error("FAILED: %s" % failure)
	quit(1)
