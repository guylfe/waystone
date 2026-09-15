extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const DeterminismSnapshotScript = preload("res://scripts/core/determinism_snapshot.gd")

# Filled from the 0.2.85 semantic baseline. These hashes describe gameplay
# state, not RunState's storage layout, so structural refactors should preserve
# them. A deliberate rules change must explain and update the affected component.
const EXPECTED := {
	"started": {
		# 0.2.93 deliberately changes the opening encounter deck and gives Shields a
		# stable ward ID. The generated enemy component therefore has a new baseline.
		"all": "9c4e334e3208a79ed7ecac18aa65ed07c3186fe760b98677ee13577b2ce5f662",
		"enemies": "e617cc055e02c62119770e724424b3adac26c3941964ba88062e7e0f8dfc0f54",
		"player": "9d12c4220ec5ba713708f7f838d96b59c6580f46863f1d491debc8eea7d0eaf4",
		"run": "7cb9b3f199278f0d02f6962cb25c8215362aac218e75f143480243279589aa35",
		"world": "70b59a3d24fcd432bcc7e39db8bc226cef5febfa90cf8d9fbcdacc356067fbe2",
	},
	"after_move": {
		"all": "be874aeab0ff4b2bf96b11d70f9e16f5c915e18acc1aa09a5e2e6f2aab41a16a",
		"enemies": "f0b46e88e79219700b282c352b1da1898f426c87ce949cff77a7fde4194b518a",
		"player": "98ab9c5c784663340dc019ef833defbcc9c43e2a64f4053b3bb25c7125653973",
		"run": "2e15565515cf5e79d8df23f40e6fc8578aaf6c218c2f4ba42f48aaf862a339b5",
		"world": "70b59a3d24fcd432bcc7e39db8bc226cef5febfa90cf8d9fbcdacc356067fbe2",
	},
	"after_wait": {
		"all": "33539e6113939bf4bbafed701a8298fab2c8b80a3788dcd2d0a5e507d10847e0",
		"enemies": "5e3e99323444caf3a825ac0d5fc638e54dc107802e3ea25e05515f06f146a28d",
		"player": "98ab9c5c784663340dc019ef833defbcc9c43e2a64f4053b3bb25c7125653973",
		"run": "4898a4f3bd11370193d827a941662c68deeb03eaa254b042e447cbb56f25ff04",
		"world": "70b59a3d24fcd432bcc7e39db8bc226cef5febfa90cf8d9fbcdacc356067fbe2",
	},
}

const ELEMENTALIST_EXPECTED := {
	"elementalist_spellbook": {
		# 0.2.84 deliberately changes the player component: the same authored Earth Wall
		# leaves a different Energy remainder under the new Intelligence soft-cap curve.
		# 0.2.88 deliberately changes the enemy and world components: the Javelineer now
		# carries its committed intercept on the hurl action and its real arc on the shot.
		# 0.2.93 adds the stable ward relationship to deterministic enemy state.
		"all": "bef4473dadca421a7b9490c0e587234e321a849bfb45ec6b388720bf7d2616e6",
		"enemies": "44e3a75bdd335f80cf685027a8b06d102684c9ffcb9a9e23b4a1245d5f091330",
		"player": "c486c4ec20c8d39e6049393c39bf889c607cdd9e35f15d346918663c08bbdbc0",
		"run": "15b7cda574869ce8caf33f87e765f7b4cfff33c52654d931ee140c864a9a5c95",
		"world": "87c4ad94448ce5a5eab26e9e7bc331bf00bf7d0f39fe808084491c1558deb395",
	},
}

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func advance_until_ready(state: RunState, limit: int = 1200) -> void:
	for _tick in range(limit):
		if state.is_player_ready(): return
		state.advance_streamed_action_tick()
	check(false, "the scripted action did not return to readiness")

func record(name: String, state: RunState) -> void:
	record_against(EXPECTED, name, state)

func record_against(expected_table: Dictionary, name: String, state: RunState) -> void:
	var actual := DeterminismSnapshotScript.checkpoint(state)
	var expected: Dictionary = expected_table.get(name, {})
	if expected.is_empty():
		print("GOLDEN %s = %s" % [name, var_to_str(actual)])
		failures.append("golden checkpoint %s has not been recorded" % name)
		return
	for component in ["player", "enemies", "world", "run", "all"]:
		check(String(actual.get(component, "")) == String(expected.get(component, "")), "%s.%s diverged: expected %s, got %s" % [name, component, expected.get(component, "missing"), actual.get(component, "missing")])

func elementalist_state() -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run("mage_elementalist", "combat_survey", 515151, "encounter", "energy")
	state.walls.clear()
	state.barriers.clear()
	state.hazards.clear()
	state.projectiles.clear()
	state.enemies.clear()
	state.player_spells.assign(["lightning_bolt", "fire_breath", "cold_front", "earth_wall", "gale"])
	state.player_max_energy = 1000.0
	state.player_energy = 1000.0
	var target := state._make_enemy("blade", state.player_pos + Vector2.UP * 105.0, 1)
	target["awareness"] = "alerted"
	state.enemies = [target]
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	check(state.request_spell("fire_breath", Vector2(target["pos"])), "Elementalist golden must cast fire")
	state.player_energy = 1000.0
	check(state.request_spell("cold_front", Vector2(target["pos"])), "Elementalist golden must cast frost")
	state.player_energy = 1000.0
	check(state.request_spell("gale", state.player_pos + Vector2.RIGHT * 200.0), "Elementalist golden must cast Gale")
	# Keep the condition-bearing target in the projection without letting it tear
	# down the wall during the wall cast's committed recovery.
	target["pos"] = state.player_pos + Vector2.UP * 700.0
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	state.player_energy = 1000.0
	check(state.request_spell("earth_wall", state.player_pos + Vector2.RIGHT * 180.0), "Elementalist golden must raise a wall")
	var javelineer := state._make_enemy("javelineer", state.player_pos + Vector2.RIGHT * 300.0, 2)
	javelineer["awareness"] = "alerted"
	javelineer["facing"] = Vector2.LEFT
	state.enemies.append(javelineer)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	var intercept := state._javelin_intercept(javelineer)
	check(not intercept.is_empty(), "Elementalist golden must find a legal javelin intercept")
	javelineer["action"] = state._enemy_ability_action("hurl", Vector2(intercept.get("direction", Vector2.LEFT)))
	javelineer["action"].merge(intercept, true)
	state._spawn_javelin(javelineer)
	state._resolve_gale(Vector2(state.projectiles[0]["pos"]))
	check(state.barriers.size() == state.EARTH_WALL_SEGMENTS, "Elementalist golden must retain its wall")
	check(not state.projectiles.is_empty() and String(state.projectiles[0].get("elevation_profile", "")) == "flat", "Elementalist golden must ground an elevated javelin")
	return state

func test_projection_families_change_their_component() -> void:
	var state := elementalist_state()
	var baseline := DeterminismSnapshotScript.checkpoint(state)
	state.player_conditions["burning"] = 1.0
	check(String(DeterminismSnapshotScript.checkpoint(state)["player"]) != String(baseline["player"]), "player conditions must affect determinism")
	state.player_conditions.clear()
	state.player_condition_buildup["frost"] = 2.0
	check(String(DeterminismSnapshotScript.checkpoint(state)["player"]) != String(baseline["player"]), "player buildup must affect determinism")
	state.player_condition_buildup.clear()
	state.player_gale_velocity = Vector2.RIGHT * 12.0
	check(String(DeterminismSnapshotScript.checkpoint(state)["player"]) != String(baseline["player"]), "player Gale velocity must affect determinism")
	state.player_gale_velocity = Vector2.ZERO
	var enemy := Dictionary(state.enemies[0])
	enemy["chants"] = {"ward": 1.0}
	check(String(DeterminismSnapshotScript.checkpoint(state)["enemies"]) != String(baseline["enemies"]), "enemy chants must affect determinism")
	enemy["chants"] = {}
	enemy["condition_buildup"] = {"frost": 1.0}
	check(String(DeterminismSnapshotScript.checkpoint(state)["enemies"]) != String(baseline["enemies"]), "enemy buildup must affect determinism")

func _init() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 424242, "encounter", "recovery")
	record("started", state)
	check(state.request_move(Vector2.RIGHT, false), "the golden move must start")
	advance_until_ready(state)
	record("after_move", state)
	check(state.request_wait(0.5, false), "the golden wait must start")
	advance_until_ready(state)
	record("after_wait", state)
	var elementalist := elementalist_state()
	record_against(ELEMENTALIST_EXPECTED, "elementalist_spellbook", elementalist)
	test_projection_families_change_their_component()
	if failures.is_empty():
		print("Golden run tests passed.")
		quit(0)
	else:
		for failure in failures: print("FAILED: %s" % failure)
		print("Golden run tests failed: %d" % failures.size())
		quit(1)
