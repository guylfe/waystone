extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const DeterminismSnapshotScript = preload("res://scripts/core/determinism_snapshot.gd")

# Filled from the 0.2.74 semantic baseline. These hashes describe gameplay
# state, not RunState's storage layout, so structural refactors should preserve
# them. A deliberate rules change must explain and update the affected component.
const EXPECTED := {
	"started": {
		"all": "05fe7a86ff19d31a886e8a6c3d91e9aee358498d5f255bd7e500539adce068e2",
		"enemies": "06fed0c7f2d8ff64358aa2aec4a4675b07981b2c247baf509862f4ecd9b4cdfc",
		"player": "2571802cd4ea5e337bc742b1110038d769be27f120156676e5901a5bc7e0b4ff",
		"run": "7cb9b3f199278f0d02f6962cb25c8215362aac218e75f143480243279589aa35",
		"world": "70b59a3d24fcd432bcc7e39db8bc226cef5febfa90cf8d9fbcdacc356067fbe2",
	},
	"after_move": {
		"all": "1dfb1d6a94fca69576c5dd26ef692dfb1c6a48d42ff513e2345fb6cc486d726b",
		"enemies": "c7d3d03680378fbdd07da96b7b4e9b6c1753925a075911cd893144d85a5811f8",
		"player": "797dfcca98ab89d75741e3e433736d88c2eb8f69a43fbf956734e07c82b844b4",
		"run": "2e15565515cf5e79d8df23f40e6fc8578aaf6c218c2f4ba42f48aaf862a339b5",
		"world": "70b59a3d24fcd432bcc7e39db8bc226cef5febfa90cf8d9fbcdacc356067fbe2",
	},
	"after_wait": {
		"all": "cad378bc526942b05b4a50d53738f40eb5ebb30667cfb6763fcee29f402c914d",
		"enemies": "f2f205aaf66562e89a0c68ca5eed1e9e8af4353761f5c04baa1df22a070c1b90",
		"player": "797dfcca98ab89d75741e3e433736d88c2eb8f69a43fbf956734e07c82b844b4",
		"run": "4898a4f3bd11370193d827a941662c68deeb03eaa254b042e447cbb56f25ff04",
		"world": "70b59a3d24fcd432bcc7e39db8bc226cef5febfa90cf8d9fbcdacc356067fbe2",
	},
}

const ELEMENTALIST_EXPECTED := {
	"elementalist_spellbook": {
		"all": "02e495c76a9a182bfc13f0dfffa0d77a5d00c6d1f48ea7320a69265be81b2d71",
		"enemies": "8990a1322f78608ec7dc54f667e0e096bb7ca9d3a8e8fa4788ed8abb695f4ac7",
		"player": "7a5eff22dc4b9bf048b116cf8a27fcff9a054d8272600067c472b436360acd3a",
		"run": "15b7cda574869ce8caf33f87e765f7b4cfff33c52654d931ee140c864a9a5c95",
		"world": "84ce6caa5c76031155d68f343c82f05e9019bbb5891a477815d42677f3f99312",
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
	state.enemies.append(javelineer)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
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
