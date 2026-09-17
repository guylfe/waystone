extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _init() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "expedition", 717)
	state.prewarm_expedition_navigation()
	var prewarm_ms := float(state.performance_metrics["navigation_prewarm_ms"])
	state.current_area_id = 1
	state.player_pos = Vector2(state.areas[1]["center"])
	state._apply_shortcut_world_state()
	state.current_area_id = 2
	state.player_pos = Vector2(state.areas[2]["center"])
	var refresh_start := Time.get_ticks_usec()
	state._refresh_loaded_region_content()
	var refresh_ms := float(Time.get_ticks_usec() - refresh_start) / 1000.0
	state.walls.assign(state.base_walls)
	var wall_start := Time.get_ticks_usec()
	state._build_wall_spatial_index()
	var wall_ms := float(Time.get_ticks_usec() - wall_start) / 1000.0
	var navigation_start := Time.get_ticks_usec()
	state._build_navigation()
	var navigation_ms := float(Time.get_ticks_usec() - navigation_start) / 1000.0
	assert(bool(state.performance_metrics["navigation_cache_hit"]))
	print("TRANSITION 2_TO_3 prewarm=%.2fms refresh=%.2fms walls=%.2fms navigation=%.2fms total=%.2fms loaded=%s nav=%s cache=%s" % [
		prewarm_ms,
		refresh_ms,
		wall_ms,
		navigation_ms,
		refresh_ms + wall_ms + navigation_ms,
		state.loaded_region_ids.keys(),
		state.navigation.region.size,
		state.performance_metrics["navigation_cache_hit"],
	])
	quit()
