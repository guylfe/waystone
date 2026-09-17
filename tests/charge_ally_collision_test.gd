extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func open_state() -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 290290, "encounter", "energy")
	state.walls.clear()
	state._build_wall_spatial_index()
	state.barriers.clear()
	state.player_pos = Vector2(1100.0, 700.0)
	state._replace_enemy_actors([])
	state._next_enemy_id = 1
	return state

func test_hound_vaults_allies_but_not_geometry() -> void:
	var state := open_state()
	var hound := state._make_enemy("hound", Vector2(500.0, 700.0), 30, 5)
	var knife := state._make_enemy("knife", Vector2(550.0, 700.0), 20, 5)
	state._replace_enemy_actors([hound, knife])
	var action := state._enemy_charge_action(hound, 1.58, 0.70, 1.08, 500.0, 14, Vector2.RIGHT)
	check(String(action.get("ally_collision", "")) == "vault" and bool(action.get("airborne", false)),
		"the Hound's authored charge profile must be an airborne ally vault")
	var motion := state._move_charging_actor(hound, Vector2(hound["pos"]), Vector2.RIGHT * 120.0, action)
	check(Vector2(motion["position"]).is_equal_approx(Vector2(620.0, 700.0)),
		"a Hound pounce must cross an allied body without losing travel")
	check(Array(action.get("vaulted_ally_ids", [])).has(int(knife["id"])),
		"the crossed ally must be recorded once on the action")
	check(state.survey_charge_traffic_events.size() == 1 and String(state.survey_charge_traffic_events[0].get("interaction", "")) == "vaulted",
		"Combat Survey must record a Hound vault")

	# Ignoring allies is not ignoring the world. The same profile must still stop at
	# a physical wall, rather than turning the Hound into a teleport.
	state.walls.assign([Rect2(590.0, 640.0, 20.0, 120.0)])
	state._build_wall_spatial_index()
	var blocked := state._move_charging_actor(hound, Vector2(hound["pos"]), Vector2.RIGHT * 80.0, action)
	check(Vector2(blocked["position"]).is_equal_approx(Vector2(hound["pos"])),
		"an airborne Hound must remain solid to walls")
	check(String(Dictionary(blocked["collision"]).get("cause", "")) == "wall",
		"a wall-stopped Hound must report the actual collision cause")

func test_hound_finishes_at_a_clear_landing() -> void:
	var state := open_state()
	var hound := state._make_enemy("hound", Vector2(500.0, 700.0), 30, 5)
	var knife := state._make_enemy("knife", Vector2(650.0, 700.0), 20, 5)
	state._replace_enemy_actors([hound, knife])
	var action := state._enemy_charge_action(hound, 1.58, 0.70, 1.08, 500.0, 14, Vector2.RIGHT)
	var approach := state._move_charging_actor(hound, Vector2(hound["pos"]), Vector2.RIGHT * 100.0, action)
	state._set_enemy_position(hound, Vector2(approach["position"]))
	var landing := state._move_charging_actor(hound, Vector2(hound["pos"]), Vector2.RIGHT * 30.0, action, true)
	check(Vector2(landing["position"]).is_equal_approx(Vector2(600.0, 700.0)),
		"a Hound whose endpoint is occupied must return to its last clear landing point")
	check(Vector2(landing["position"]).distance_to(Vector2(knife["pos"])) >= float(hound["radius"]) + float(knife["radius"]),
		"a completed Hound vault must not leave the two bodies overlapping")

func test_boar_parts_light_ranks_and_disrupts_them() -> void:
	var state := open_state()
	var boar := state._make_enemy("boar", Vector2(500.0, 700.0), 35, 5)
	var knife := state._make_enemy("knife", Vector2(566.0, 700.0), 20, 5)
	knife["action"] = state._action("melee", 1.0, Vector2.LEFT)
	state._replace_enemy_actors([boar, knife])
	var action := state._enemy_charge_action(boar, 1.95, 0.70, 1.50, 360.0, 25, Vector2.RIGHT)
	var knife_origin := Vector2(knife["pos"])
	var posture_before := float(knife["posture"])
	var motion := state._move_charging_actor(boar, Vector2(boar["pos"]), Vector2.RIGHT * 5.0, action)
	check(Vector2(motion["position"]).x > Vector2(boar["pos"]).x,
		"a Boar must continue after parting a light ally")
	check(not is_equal_approx(Vector2(knife["pos"]).y, knife_origin.y),
		"the light ally must be displaced laterally out of the charge lane")
	check(is_equal_approx(float(knife["posture"]), posture_before - 1.5),
		"the shove must inflict the authored posture damage and no hidden health damage")
	check(int(knife["hp"]) == 20 and String(Dictionary(knife["action"]).get("kind", "")) == "hit_reaction",
		"the shoved ally must keep its health but briefly lose its action")
	check(state.survey_charge_traffic_events.size() == 1 and String(state.survey_charge_traffic_events[0].get("interaction", "")) == "shoved",
		"Combat Survey must record a Boar shove")

func test_heavy_or_committed_allies_still_stop_a_boar() -> void:
	var state := open_state()
	var boar := state._make_enemy("boar", Vector2(500.0, 700.0), 35, 5)
	var shield := state._make_enemy("shield", Vector2(572.0, 700.0), 50, 5)
	state._replace_enemy_actors([boar, shield])
	var action := state._enemy_charge_action(boar, 1.95, 0.70, 1.50, 360.0, 25, Vector2.RIGHT)
	var blocked := state._move_charging_actor(boar, Vector2(boar["pos"]), Vector2.RIGHT * 5.0, action)
	check(Vector2(blocked["position"]).is_equal_approx(Vector2(boar["pos"])),
		"a heavy allied body must still stop a Boar")
	check(String(Dictionary(blocked["collision"]).get("cause", "")) == "ally_body",
		"the stop must be classified as an allied-body collision, not a generic obstacle")
	check(int(Dictionary(Dictionary(blocked["collision"]).get("blocker", {})).get("id", -1)) == int(shield["id"]),
		"the collision record must identify the body that stopped the charge")

	var light := state._make_enemy("hound", Vector2(570.0, 700.0), 30, 5)
	light["action"] = state._enemy_charge_action(light, 1.58, 0.70, 1.08, 500.0, 14, Vector2.LEFT)
	state._replace_enemy_actors([boar, light])
	var committed_block := state._move_charging_actor(boar, Vector2(boar["pos"]), Vector2.RIGHT * 5.0, action)
	check(Vector2(committed_block["position"]).is_equal_approx(Vector2(boar["pos"])),
		"another committed charger must remain solid even when its mass is light")

func test_ox_gore_profile_does_not_change_reset_collision() -> void:
	var state := open_state()
	var ox := state._make_enemy("ox", Vector2(500.0, 700.0), 96, 5)
	var knife := state._make_enemy("knife", Vector2(580.0, 700.0), 20, 5)
	state._replace_enemy_actors([ox, knife])
	var gore := state._enemy_charge_action(ox, 2.10, 0.82, 1.72, 620.0, 35, Vector2.RIGHT)
	check(String(gore.get("ally_collision", "")) == "gore",
		"the Ox's canonical forward gore must retain its existing ally-plough profile")
	var reset := state._enemy_charge_action(ox, 0.90, 0.18, 0.70, 260.0, 0, Vector2.RIGHT)
	reset["ally_collision"] = "block"
	var blocked := state._move_charging_actor(ox, Vector2(ox["pos"]), Vector2.RIGHT * 10.0, reset)
	check(Vector2(blocked["position"]).is_equal_approx(Vector2(ox["pos"])),
		"the Ox's reverse reset must remain body-blocked by an ally (got %s from %s)" % [blocked["position"], ox["pos"]])
	check(int(knife["hp"]) == 20,
		"the Ox's reverse reset must remain harmless to allies")

func _init() -> void:
	test_hound_vaults_allies_but_not_geometry()
	test_hound_finishes_at_a_clear_landing()
	test_boar_parts_light_ranks_and_disrupts_them()
	test_heavy_or_committed_allies_still_stop_a_boar()
	test_ox_gore_profile_does_not_change_reset_collision()
	if failures.is_empty():
		print("CHARGE ALLY COLLISION TESTS PASSED")
		quit(0)
		return
	for failure in failures: push_error("FAILED: %s" % failure)
	quit(1)
