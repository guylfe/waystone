extends SceneTree
const State = preload("res://scripts/core/run_state.gd")
const Generator = preload("res://scripts/core/expedition_generator.gd")
const Coordinator = preload("res://scripts/core/expedition_coordinator.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _init() -> void:
	for seed_value in range(100):
		for biome_index in range(3):
			var layout := Generator.generate(seed_value,biome_index)
			var errors := Generator.validate(layout)
			check(errors.is_empty(), "Seed %d biome %d: %s" % [seed_value,biome_index,errors])
	var state := State.new(false)
	state.start_run("warrior","expedition",123,"encounter","energy")
	check(state.enemies.size() > 16, "Generated populated biome")
	var count: int = state.enemies.size()
	state.player_pos = state.bonfire_pos
	check(not state.activate_waystone(), "Cannot use a locked Waystone")
	Coordinator.defeat_boss(state.expedition) # Lifecycle fixture, not a combat/playthrough claim.
	state.player_hp = 10
	state.potions = 0
	check(state.activate_waystone(), "Unlocked Waystone activates")
	check(state.player_hp == state.player_max_hp and state.potions==5, "Waystone restores pouch and HP")
	check(state.enemies.size()==count, "Waystone does not respawn/remove enemies")
	check(not state.activate_waystone(), "Waystone is single-use")
	check(state.save_run("user://expedition-test.save"), "Save succeeds")
	var loaded := State.new(false)
	check(loaded.load_run("user://expedition-test.save"), "Load succeeds")
	check(not loaded.activate_waystone(), "Used Waystone stays used after reload")
	loaded.player_pos = loaded.expedition_markers["exit"]
	check(loaded.request_expedition_departure(), "Departure warning")
	check(int(loaded.expedition["biome"])==0, "Warning does not depart")
	check(loaded.request_expedition_departure(true), "Confirmed departure")
	check(int(loaded.expedition["biome"])==1, "Next biome")
	check(loaded.expedition["departed"]==[0], "Route behind recorded closed")
	check(loaded.save_run("user://expedition-test.save"), "Atomic replacement save")
	check(state.load_run("user://expedition-test.save"), "Reload second biome")
	check(state.expedition["biome"]==1 and state.player_pos==loaded.player_pos, "Correct second-biome geography and position")
	for failure in failures: print("FAILED: ",failure)
	print("Expedition lifecycle: ", failures.size(), " failures; 100 seeds x three biomes.")
	quit(0 if failures.is_empty() else 1)
