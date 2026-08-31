extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const DeterminismSnapshotScript = preload("res://scripts/core/determinism_snapshot.gd")

# Filled from the 0.2.74 semantic baseline. These hashes describe gameplay
# state, not RunState's storage layout, so structural refactors should preserve
# them. A deliberate rules change must explain and update the affected component.
const EXPECTED := {
	"started": {
		"all": "e8cb3e6a59a567539dd7c4635a275454114e4443078dab90c354cf28fc8664dd",
		"enemies": "71f1ad79d6d6db7577f41311d6a9b7ec15d3d7acc7f448d18609131ae2ceed95",
		"player": "703cac084ce9d9ba78dd45fc0e215bdd1f06a1072b205d65f5630e3f2dd1b311",
		"run": "7cb9b3f199278f0d02f6962cb25c8215362aac218e75f143480243279589aa35",
		"world": "70b59a3d24fcd432bcc7e39db8bc226cef5febfa90cf8d9fbcdacc356067fbe2",
	},
	"after_move": {
		"all": "6f45e6718f7af35fae73ea029a389c51682cf030dfb47d0fdbe76980867e1296",
		"enemies": "b293a01ac16c284009390022daef1c6fff9181cf34ad3d6fa1e1858713b791a7",
		"player": "5f034020b40969da24e31c0a3b29a43e7f2967c7cff1772fa3e26cc1b2b0c9d1",
		"run": "2e15565515cf5e79d8df23f40e6fc8578aaf6c218c2f4ba42f48aaf862a339b5",
		"world": "70b59a3d24fcd432bcc7e39db8bc226cef5febfa90cf8d9fbcdacc356067fbe2",
	},
	"after_wait": {
		"all": "da0b05a46da5cf52cc9c1fe4c68b59e4db42d929de67d5247befd6537e848266",
		"enemies": "89dc7e43343203d77b05398c9bf67c2f1bb9dcd2abc8c68b3c32dabab696bae2",
		"player": "5f034020b40969da24e31c0a3b29a43e7f2967c7cff1772fa3e26cc1b2b0c9d1",
		"run": "4898a4f3bd11370193d827a941662c68deeb03eaa254b042e447cbb56f25ff04",
		"world": "70b59a3d24fcd432bcc7e39db8bc226cef5febfa90cf8d9fbcdacc356067fbe2",
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
	var actual := DeterminismSnapshotScript.checkpoint(state)
	var expected: Dictionary = EXPECTED.get(name, {})
	if expected.is_empty():
		print("GOLDEN %s = %s" % [name, var_to_str(actual)])
		failures.append("golden checkpoint %s has not been recorded" % name)
		return
	for component in ["player", "enemies", "world", "run", "all"]:
		check(String(actual.get(component, "")) == String(expected.get(component, "")), "%s.%s diverged: expected %s, got %s" % [name, component, expected.get(component, "missing"), actual.get(component, "missing")])

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
	if failures.is_empty():
		print("Golden run tests passed.")
		quit(0)
	else:
		for failure in failures: print("FAILED: %s" % failure)
		print("Golden run tests failed: %d" % failures.size())
		quit(1)
