extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _init() -> void:
	_measure("expedition", 717)
	_measure("campaign_lab", 99117)
	_measure_crowds()
	_measure_save_payload()
	quit()

func _measure(mode: String, seed: int) -> void:
	var state = RunStateScript.new(false)
	var generation_start := Time.get_ticks_usec()
	state.start_run("wayfarer", mode, seed)
	var generation_ms := float(Time.get_ticks_usec() - generation_start) / 1000.0
	state._build_enemy_spatial_index()
	var action_total := 0.0
	var completed := 0
	for index in range(12):
		var direction := Vector2.RIGHT if index % 2 == 0 else Vector2.LEFT
		if state.request_move(direction, 12.0):
			action_total += float(state.performance_metrics["last_action_ms"])
			completed += 1
	assert(completed == 12)
	assert(int(state.performance_metrics["active_enemies"]) < int(state.performance_metrics["resident_enemies"]))
	# Standalone ascent maps stream intersecting geographic bounds, not a
	# three-node legacy room graph. Both modes must still exclude distant areas.
	assert(state.loaded_region_ids.size() < state.areas.size())
	print("PERF %s generation=%.2fms average_action=%.2fms active=%d resident=%d regions=%d/%d shapes=%d/%d nav=%s" % [mode, generation_ms, action_total / float(completed), int(state.performance_metrics["active_enemies"]), int(state.performance_metrics["resident_enemies"]), state.loaded_region_ids.size(), state.areas.size(), state._loaded_floor_shapes.size(), state.floor_shapes.size(), state.navigation.region.size])

func _measure_crowds() -> void:
	for crowd_size in [10, 30, 50]:
		var state = RunStateScript.new(false)
		state.start_run("wayfarer", "expedition", 717)
		state.enemies.clear()
		for index in range(crowd_size):
			var angle := TAU * float(index) / float(crowd_size)
			var ring := 260.0 + float(index % 4) * 90.0
			var enemy: Dictionary = state._make_enemy("blade", state.player_pos + Vector2.from_angle(angle) * ring, 7, state.current_area_id)
			enemy["layer"] = state.current_layer
			enemy["awareness"] = "alerted"
			enemy["alert_remaining"] = 10.0
			state.enemies.append(enemy)
		state._build_enemy_spatial_index()
		var move_start := Time.get_ticks_usec()
		assert(state.request_move(Vector2.RIGHT, 12.0))
		var move_ms := float(Time.get_ticks_usec() - move_start) / 1000.0
		var strike_start := Time.get_ticks_usec()
		assert(state.request_attack(state.player_pos + Vector2.RIGHT * 120.0))
		var strike_ms := float(Time.get_ticks_usec() - strike_start) / 1000.0
		print("CROWD %d move=%.2fms strike=%.2fms sim=%.2fms snapshots=%.2fms frames=%d" % [crowd_size, move_ms, strike_ms, float(state.performance_metrics["simulation_ms"]), float(state.performance_metrics["snapshot_ms"]), state.last_timeline.size()])
		_measure_streamed_crowd(crowd_size)

func _measure_streamed_crowd(crowd_size: int) -> void:
	var state = RunStateScript.new(false)
	state.start_run("wayfarer", "expedition", 717)
	state.enemies.clear()
	for index in range(crowd_size):
		var angle := TAU * float(index) / float(crowd_size)
		var ring := 260.0 + float(index % 4) * 90.0
		var enemy: Dictionary = state._make_enemy("blade", state.player_pos + Vector2.from_angle(angle) * ring, 7, state.current_area_id)
		enemy["layer"] = state.current_layer
		enemy["awareness"] = "alerted"
		enemy["alert_remaining"] = 10.0
		state.enemies.append(enemy)
	state._invalidate_active_enemy_cache()
	assert(state.request_attack(state.player_pos + Vector2.RIGHT * 120.0, false))
	var maximum_frame_ms := 0.0
	var total_frame_ms := 0.0
	var frame_count := 0
	while String(state.player_action["kind"]) != "idle" and state.player_hp > 0:
		var frame_start := Time.get_ticks_usec()
		state.advance_streamed_action_tick()
		if String(state.player_action["kind"]) != "idle": state.advance_streamed_action_tick()
		var frame_ms := float(Time.get_ticks_usec() - frame_start) / 1000.0
		maximum_frame_ms = maxf(maximum_frame_ms, frame_ms)
		total_frame_ms += frame_ms
		frame_count += 1
	assert(frame_count > 0)
	print("STREAM %d average_frame=%.2fms maximum_frame=%.2fms frames=%d" % [crowd_size, total_frame_ms / float(frame_count), maximum_frame_ms, frame_count])

func _measure_save_payload() -> void:
	var state = RunStateScript.new(false)
	state.start_run("wayfarer", "campaign_lab", 99117)
	var full_bytes := var_to_bytes(state.snapshot()).size()
	var compact_bytes := var_to_bytes(state._build_save_payload()).size()
	var path := "user://waystone-performance.save"
	assert(state.save_run(path))
	print("SAVE full=%d compact=%d reduction=%.1f%% payload=%.2fms write=%.2fms total=%.2fms" % [full_bytes, compact_bytes, (1.0 - float(compact_bytes) / float(full_bytes)) * 100.0, float(state.performance_metrics["last_save_payload_ms"]), float(state.performance_metrics["last_save_write_ms"]), float(state.performance_metrics["last_save_ms"])])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
