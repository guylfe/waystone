extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
	call_deferred("_measure_isometric_crowd")

func _measure_isometric_crowd() -> void:
	var board = MainScene.instantiate()
	root.add_child(board)
	await process_frame
	board.state.start_run("warrior", "expedition", 717)
	board.state.enemies.clear()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		var enemy: Dictionary = board.state._make_enemy("blade", board.state.player_pos + Vector2.from_angle(angle) * (260.0 + float(index % 3) * 80.0), 7, board.state.current_area_id)
		enemy["layer"] = board.state.current_layer
		enemy["awareness"] = "alerted"
		enemy["alert_remaining"] = 10.0
		board.state.enemies.append(enemy)
	board.state._invalidate_active_enemy_cache()
	board.state.discovered_cells.clear()
	board.state.visible_cells.clear()
	var player_cell := Vector2i(board.state.player_pos / board.state.VISIBILITY_CELL)
	for x in range(player_cell.x - 24, player_cell.x + 25):
		for y in range(player_cell.y - 24, player_cell.y + 25):
			board.state.discovered_cells[Vector2i(x, y)] = true
			board.state.visible_cells[Vector2i(x, y)] = true
	board.state.discovery_revision += 1
	board.visual = board.state.snapshot(true)
	board._static_query_revision = -1
	board.queue_redraw()
	await process_frame
	var total_draw_ms := 0.0
	var maximum_draw_ms := 0.0
	for frame in range(90):
		board.queue_redraw()
		await process_frame
		var draw_ms := float(board.state.performance_metrics["draw_cpu_ms"])
		total_draw_ms += draw_ms
		maximum_draw_ms = maxf(maximum_draw_ms, draw_ms)
	print("RENDER ISO crowd=20 average_draw=%.2fms maximum_draw=%.2fms nearby_walls=%d nearby_features=%d" % [
		total_draw_ms / 90.0,
		maximum_draw_ms,
		board._render_walls().size(),
		board._render_features().size(),
	])
	board.queue_free()
	quit()
