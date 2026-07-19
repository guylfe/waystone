extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")
const FloorGeneratorScript = preload("res://scripts/core/floor_generator.gd")

func _init() -> void:
	test_large_seven_part_forest_expedition()
	test_boss_marker_uses_actual_spawn()
	test_organic_route_reachability()
	test_mandatory_paths_keep_generous_clearance()
	test_layered_campaign_loop()
	test_shortcuts_are_binding_topology()
	test_legacy_shortcut_state_is_not_imported()
	test_layer_discovery_is_independent()
	print("Large-world expedition and layered campaign tests passed.")
	quit(0)

func test_large_seven_part_forest_expedition() -> void:
	for seed in [11, 1784339476686, 739391]:
		var layout: Dictionary = FloorGeneratorScript.generate(seed, false)
		var areas: Array = layout["areas"]
		assert(areas.size() == 7)
		assert(Array(layout["connections"]).size() == 6)
		assert(Array(layout["waystones"]).is_empty())
		assert(Array(layout["shortcuts"]).is_empty())
		assert(String(layout["geometry_style"]) == "organic")
		assert(Array(layout["route_recipe"]).size() == 7)
		assert(Dictionary(layout["locale_catalog"]).has("friendly_forest"))
		var previous_enemy_count := 0
		var total_enemies := 0
		var palette_ids: Dictionary = {}
		for index in range(7):
			var area: Dictionary = areas[index]
			assert(int(area["progression_part"]) == index + 1)
			assert(Rect2(area["rect"]).size.x > 1500.0)
			assert(Rect2(area["rect"]).size.y > 1400.0)
			assert(String(area["locale_id"]) == "friendly_forest")
			palette_ids[String(Dictionary(area["profile"])["palette"])] = true
			var count := Array(Dictionary(layout["encounters"])[index]).size()
			assert(count >= previous_enemy_count)
			previous_enemy_count = count
			total_enemies += count
		assert(total_enemies >= 70)
		assert(palette_ids.size() == 7)
		assert(Array(layout["floor_shapes"]).size() >= 49)

func test_boss_marker_uses_actual_spawn() -> void:
	for campaign in [false, true]:
		var layout: Dictionary = FloorGeneratorScript.generate(424242, campaign)
		var boss_area: Dictionary = {}
		for area in Array(layout["areas"]):
			if String(area.get("kind", "")) == "boss": boss_area = area
		assert(not boss_area.is_empty() and boss_area.has("boss_pos"))
		var matching_bosses := 0
		for template in Array(Dictionary(layout["encounters"])[int(boss_area["id"])]):
			if String(template["kind"]) == "warden":
				matching_bosses += 1
				assert(Vector2(template["pos"]).distance_to(Vector2(boss_area["boss_pos"])) < 0.01)
		assert(matching_bosses == 1)

func test_organic_route_reachability() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "expedition", 717)
	assert(state.world_size.x > 15000.0)
	for area_index in range(state.areas.size() - 1):
		state.current_area_id = area_index
		state.player_pos = Vector2(state.areas[area_index]["center"])
		state._apply_shortcut_world_state()
		var previous_cell := state._nearest_open_cell(state._world_to_nav(state.player_pos))
		var destination := state._nearest_open_cell(state._world_to_nav(Vector2(state.areas[area_index + 1]["center"])))
		var path := state.navigation.get_id_path(previous_cell, destination, true)
		assert(not path.is_empty() and Vector2i(path[path.size() - 1]) == destination)
	# A bounding-box corner is not automatically floor; the footprint is the
	# union of clearings and broad paths, not a hidden rectangular room.
	var first_rect := Rect2(state.areas[0]["rect"])
	assert(not state._point_on_floor(first_rect.position + Vector2(10, 10)))
	assert(state._timeline_enemies().size() < state.enemies.size())

func test_mandatory_paths_keep_generous_clearance() -> void:
	const CLEARANCE := 74.0
	for seed in range(1, 21):
		for campaign in [false, true]:
			var layout: Dictionary = FloorGeneratorScript.generate(seed * 7919, campaign)
			for connection in Array(layout["connections"]):
				if bool(connection["shortcut"]): continue
				var path: Array = connection["path"]
				var walls: Array = Dictionary(layout["layer_walls"]).get(String(connection["layer"]), [])
				for segment_index in range(path.size() - 1):
					var start := Vector2(path[segment_index])
					var finish := Vector2(path[segment_index + 1])
					for step in range(maxi(1, int(ceil(start.distance_to(finish) / 24.0))) + 1):
						var point := start.lerp(finish, float(step) / float(maxi(1, int(ceil(start.distance_to(finish) / 24.0)))))
						for wall in walls:
							assert(not _circle_intersects_rect(point, CLEARANCE, Rect2(wall)), "clearance seed=%d campaign=%s connection=%d point=%s wall=%s" % [seed, campaign, int(connection["id"]), point, wall])

func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(nearest) < radius * radius

func test_layered_campaign_loop() -> void:
	var layout: Dictionary = FloorGeneratorScript.generate(99117, true)
	assert(Dictionary(layout["layers"]).size() == 2)
	assert(Array(layout["waystones"]).size() == 2)
	assert(Array(layout["shortcuts"]).size() == 2)
	assert(Array(layout["transitions"]).size() == 2)
	for transition in Array(layout["transitions"]):
		assert(Vector2(transition["from_pos"]).distance_to(Vector2(transition["to_pos"])) < 0.01)
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "campaign_lab", 99117)
	var stairs: Dictionary = state.transitions[0]
	state.player_pos = Vector2(stairs["from_pos"])
	assert(state.use_transition())
	assert(state.current_layer == String(stairs["to_layer"]))
	assert(state.player_pos.distance_to(Vector2(stairs["to_pos"])) < 0.01)
	var lift: Dictionary = state.transitions[1]
	state.player_pos = Vector2(lift["from_pos"])
	assert(state.use_transition())
	assert(state.current_layer == String(lift["to_layer"]))
	assert(state.player_pos.distance_to(Vector2(lift["to_pos"])) < 0.01)
	state.player_pos = Vector2(state.shortcuts[1]["unlock_pos"])
	assert(state.unlock_shortcut())
	assert(bool(state.shortcuts[1]["unlocked"]))

func test_shortcuts_are_binding_topology() -> void:
	for seed in [99117, 1784339476686, 424242]:
		for shortcut_index in range(2):
			var state: RunState = RunStateScript.new(false)
			state.start_run("duelist", "campaign_lab", seed)
			var shortcut: Dictionary = state.shortcuts[shortcut_index]
			state.current_layer = String(shortcut.get("layer", state.current_layer))
			state.current_area_id = state._area_id_at_position(Vector2(shortcut["far_pos"]), state.current_layer)
			state.player_pos = Vector2(shortcut["far_pos"])
			state._apply_shortcut_world_state()
			var gate := Rect2(shortcut["gate"])
			assert(state.walls.has(gate))
			assert(maxf(gate.size.x, gate.size.y) >= 380.0)
			assert(minf(gate.size.x, gate.size.y) >= 100.0)
			var locked_length := _navigation_path_length(state, Vector2(shortcut["far_pos"]), Vector2(shortcut["near_pos"]))
			state.player_pos = Vector2(shortcut["unlock_pos"])
			assert(state.unlock_shortcut())
			assert(not state.walls.has(gate))
			var unlocked_length := _navigation_path_length(state, Vector2(shortcut["far_pos"]), Vector2(shortcut["near_pos"]))
			assert(is_finite(unlocked_length))
			if shortcut_index == 0:
				# The locked local gate still has the long outward route as an
				# alternative; opening it must produce a material distance saving.
				assert(is_finite(locked_length))
				assert(locked_length > unlocked_length + 1400.0)
			else:
				# Forgotten Grove is a distinct surface pocket until its far-side
				# root gate is deliberately opened.
				assert(not is_finite(locked_length), "return shortcut remained traversable while locked: locked=%s unlocked=%s gate=%s" % [locked_length, unlocked_length, gate])

func _navigation_path_length(state: RunState, start: Vector2, finish: Vector2) -> float:
	var start_cell := state._nearest_open_cell(state._world_to_nav(start))
	var finish_cell := state._nearest_open_cell(state._world_to_nav(finish))
	var path := state.navigation.get_id_path(start_cell, finish_cell, true)
	if path.is_empty() or Vector2i(path[path.size() - 1]) != finish_cell: return INF
	var length := 0.0
	for index in range(path.size() - 1):
		length += state.navigation.get_point_position(path[index]).distance_to(state.navigation.get_point_position(path[index + 1]))
	return length

func test_legacy_shortcut_state_is_not_imported() -> void:
	var path := "user://legacy-shortcut-migration-test.save"
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "campaign_lab", 99117)
	state.shortcuts[0]["unlocked"] = true
	state.shortcut_unlocked = true
	assert(state.save_run(path))
	var read_file := FileAccess.open(path, FileAccess.READ)
	var payload: Dictionary = read_file.get_var(true)
	read_file.close()
	payload["save_version"] = 10
	var write_file := FileAccess.open(path, FileAccess.WRITE)
	write_file.store_var(payload, true)
	write_file.close()
	var migrated: RunState = RunStateScript.new(false)
	assert(migrated.load_run(path))
	assert(not migrated.shortcut_unlocked)
	for shortcut in migrated.shortcuts: assert(not bool(shortcut["unlocked"]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_layer_discovery_is_independent() -> void:
	var state: RunState = RunStateScript.new(false)
	state.start_run("duelist", "campaign_lab", 8080)
	var shared_position := Vector2(state.transitions[0]["from_pos"])
	state.player_pos = shared_position
	state._update_exploration(true)
	var surface_count := state.discovered_cells.size()
	assert(surface_count > 0)
	assert(state.use_transition())
	# Identical total coordinates on another layer begin with their own memory.
	assert(state.discovered_cells.size() < surface_count)
	state.player_pos = Vector2(state.transitions[0]["to_pos"])
	assert(state.use_transition())
	assert(state.discovered_cells.size() == surface_count)
