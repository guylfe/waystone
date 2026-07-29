class_name FloorGenerator
extends RefCounted

const EXPEDITION_WORLD_SIZE := Vector2(16200.0, 7600.0)
const CAMPAIGN_WORLD_SIZE := Vector2(9000.0, 6500.0)
const MAIN_PATH_RADIUS := 350.0
const SIDE_PATH_RADIUS := 255.0
const MIN_MANDATORY_RADIUS := 285.0

const FOREST_PART_NAMES := [
	"Sunlit Verge", "Brookwood", "Old Forest Road", "Elder Grove",
	"Rootbound Woods", "Forest Ruins", "Heartwood Approach",
]

const FOREST_PART_PROFILES := [
	{"palette": "forest_1", "ground_color": "82b86d", "clearing_color": "8fc579", "main_surface_color": "89bc75", "side_surface_color": "80ac6c", "density": 0.68, "landmark": "meadow", "grammar": "open_glades", "path_width": 310.0, "branching": 0.55},
	{"palette": "forest_2", "ground_color": "79ad68", "clearing_color": "83b873", "main_surface_color": "7fb16c", "side_surface_color": "719b61", "density": 0.76, "landmark": "brook", "grammar": "brook_crossings", "path_width": 285.0, "branching": 0.68},
	{"palette": "forest_3", "ground_color": "70a162", "clearing_color": "769f65", "main_surface_color": "7a9561", "side_surface_color": "688957", "density": 0.82, "landmark": "old_road", "grammar": "road_and_detours", "path_width": 300.0, "branching": 0.62},
	{"palette": "forest_4", "ground_color": "68965d", "density": 0.90, "landmark": "stone_circle", "grammar": "radial_grove", "path_width": 340.0, "branching": 0.82},
	{"palette": "forest_5", "ground_color": "608a57", "density": 0.98, "landmark": "roots", "grammar": "braided_roots", "path_width": 320.0, "branching": 0.92},
	{"palette": "forest_6", "ground_color": "587f52", "density": 1.04, "landmark": "ancient_ruin", "grammar": "ruin_courtyards", "path_width": 315.0, "branching": 0.74},
	{"palette": "forest_7", "ground_color": "50744d", "density": 1.10, "landmark": "heart_tree", "grammar": "boss_approach", "path_width": 380.0, "branching": 0.58},
]

const EXPEDITION_PACING := [
	{"phase": "orientation", "label": "A gentle edge of the old wood", "pressure": 0.28, "reward_budget": 1},
	{"phase": "pursuit", "label": "Water divides the paths ahead", "pressure": 0.40, "reward_budget": 1},
	{"phase": "skirmish", "label": "The road is no longer empty", "pressure": 0.52, "reward_budget": 1},
	{"phase": "uncertainty", "label": "Old power gathers between the trees", "pressure": 0.62, "reward_budget": 1},
	{"phase": "formation", "label": "The forest closes around an organized defense", "pressure": 0.74, "reward_budget": 1},
	{"phase": "siege", "label": "Stone and steel choke the approach", "pressure": 0.88, "reward_budget": 1},
	{"phase": "climax", "label": "The heart of the wood waits ahead", "pressure": 1.00, "reward_budget": 1},
]

const FOREST_REWARD_ROLES := [
	"forager_pocket", "reed_pocket", "lost_waystation", "quiet_spoke",
	"root_hollow", "collapsed_chamber", "perimeter_shrine",
]

const FOREST_THRESHOLD_STYLES := [
	"flowered_narrows", "ford_stones", "broken_mileposts", "elder_arch",
	"root_gap", "ruined_gate",
]

static func generate(seed_value: int, include_shortcut: bool = true) -> Dictionary:
	return _generate_campaign_loop(seed_value) if include_shortcut else _generate_expedition(seed_value)

static func validate_layout(layout: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var areas: Array = layout.get("areas", [])
	var connections: Array = layout.get("connections", [])
	var shapes: Array = layout.get("floor_shapes", [])
	if areas.is_empty(): errors.append("no areas")
	if shapes.is_empty(): errors.append("no floor geometry")
	var semantic_roles: Dictionary = {}
	var route_length := 0.0
	var local_branch_count := 0
	var local_reconnection_count := 0
	var optional_pocket_count := 0
	var reward_socket_count := 0
	var expedition_contract := layout.has("route_recipe")
	for area_value in areas:
		var area: Dictionary = area_value
		if not area.has("zones") or Array(area["zones"]).is_empty(): errors.append("area %s has no semantic zones" % area.get("id", "?"))
		for zone_value in Array(area.get("zones", [])):
			semantic_roles[String(Dictionary(zone_value).get("role", "unknown"))] = true
		if expedition_contract:
			if not area.has("route_graph"): errors.append("area %s has no route graph" % area.get("id", "?"))
			else:
				var local_graph: Dictionary = area["route_graph"]
				local_branch_count += int(local_graph.get("branch_count", 0))
				local_reconnection_count += int(local_graph.get("reconnection_count", 0))
				optional_pocket_count += int(local_graph.get("optional_pocket_count", 0))
				if int(local_graph.get("reconnection_count", 0)) < 1: errors.append("area %s has no branch reconnection" % area.get("id", "?"))
				if int(local_graph.get("optional_pocket_count", 0)) < 1: errors.append("area %s has no optional pocket" % area.get("id", "?"))
			if not area.has("encounter_sockets") or Array(area["encounter_sockets"]).is_empty(): errors.append("area %s has no encounter sockets" % area.get("id", "?"))
			if not area.has("reward_sockets") or Array(area["reward_sockets"]).is_empty(): errors.append("area %s has no reward sockets" % area.get("id", "?"))
			if not area.has("respite_sockets") or Array(area["respite_sockets"]).is_empty(): errors.append("area %s has no respite socket" % area.get("id", "?"))
			if not _layout_point_on_floor(layout, Vector2(area["entry"]), String(area["layer"])): errors.append("area %s entry is off-floor" % area.get("id", "?"))
			if not _layout_point_on_floor(layout, Vector2(area["exit"]), String(area["layer"])): errors.append("area %s exit is off-floor" % area.get("id", "?"))
			for socket_value in Array(area.get("reward_sockets", [])):
				var socket: Dictionary = socket_value
				reward_socket_count += 1
				if not _layout_point_on_floor(layout, Vector2(socket["pos"]), String(area["layer"])): errors.append("reward socket %s is off-floor" % socket.get("id", "?"))
	for connection_value in connections:
		var connection: Dictionary = connection_value
		var path: Array = connection.get("path", [])
		if path.size() < 2: errors.append("connection %s has no traversable path" % connection.get("id", "?"))
		for index in range(path.size() - 1): route_length += Vector2(path[index]).distance_to(Vector2(path[index + 1]))
		if not bool(connection.get("shortcut", false)) and float(connection.get("path_radius", 0.0)) < MIN_MANDATORY_RADIUS:
			errors.append("connection %s is below mandatory clearance" % connection.get("id", "?"))
	for stone_value in Array(layout.get("waystones", [])):
		var stone: Dictionary = stone_value
		if not _layout_point_on_floor(layout, Vector2(stone["pos"]), String(stone["layer"])): errors.append("waystone %s is off-floor" % stone.get("id", "?"))
	for transition_value in Array(layout.get("transitions", [])):
		var transition: Dictionary = transition_value
		if Vector2(transition["from_pos"]).distance_to(Vector2(transition["to_pos"])) > 0.01: errors.append("transition %s is not spatially faithful" % transition.get("id", "?"))
	if expedition_contract:
		var recipe: Array = layout.get("route_recipe", [])
		var run_graph: Dictionary = layout.get("run_graph", {})
		var run_nodes: Array = run_graph.get("nodes", [])
		var run_edges: Array = run_graph.get("edges", [])
		if recipe.size() != areas.size(): errors.append("route recipe does not match area count")
		if run_nodes.size() != areas.size(): errors.append("run graph does not match area count")
		if run_edges.size() < maxi(0, areas.size() - 1): errors.append("run graph does not connect progression slots")
		if not _run_graph_reaches_goal(run_graph): errors.append("run graph goal is unreachable")
	return {
		"valid": errors.is_empty(), "errors": errors, "area_count": areas.size(),
		"connection_count": connections.size(), "floor_shape_count": shapes.size(),
		"semantic_role_count": semantic_roles.size(), "route_length": route_length,
		"local_branch_count": local_branch_count,
		"local_reconnection_count": local_reconnection_count,
		"optional_pocket_count": optional_pocket_count,
		"reward_socket_count": reward_socket_count,
	}

static func _run_graph_reaches_goal(run_graph: Dictionary) -> bool:
	var start := int(run_graph.get("start", -1))
	var goal := int(run_graph.get("goal", -1))
	if start < 0 or goal < 0: return false
	var visited := {start: true}
	var frontier: Array[int] = [start]
	var edges: Array = run_graph.get("edges", [])
	while not frontier.is_empty():
		var node: int = frontier.pop_front()
		if node == goal: return true
		for edge_value in edges:
			var edge: Dictionary = edge_value
			if int(edge["from"]) != node: continue
			var next := int(edge["to"])
			if visited.has(next): continue
			visited[next] = true
			frontier.append(next)
	return false

static func _generate_expedition(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layer := "expedition_surface"
	var route_recipe := _expedition_route_recipe()
	var locale_catalog := _expedition_locale_catalog()
	var centers: Array[Vector2] = []
	for index in range(route_recipe.size()):
		var wave := sin(float(index) * 1.19 + rng.randf_range(-0.18, 0.18)) * 760.0
		centers.append(Vector2(1450.0 + index * 2200.0, 3800.0 + wave + rng.randf_range(-150.0, 150.0)))
	if rng.randi() % 2 == 0:
		for index in range(centers.size()): centers[index].y = EXPEDITION_WORLD_SIZE.y - centers[index].y

	var areas: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	var floor_shapes: Array[Dictionary] = []
	var terrain_features: Array[Dictionary] = []
	var layer_walls := {layer: []}
	var encounters: Dictionary = {}
	var part_entries: Array[Vector2] = []
	var part_exits: Array[Vector2] = []
	var part_main_paths: Array[Array] = []
	var secret_passages: Array[Dictionary] = []
	var boss_position := Vector2.ZERO

	for index in range(route_recipe.size()):
		var recipe_slot: Dictionary = route_recipe[index]
		var locale_id := String(recipe_slot["locale_id"])
		var locale_definition: Dictionary = locale_catalog[locale_id]
		var profile_index := int(recipe_slot["profile"]) - 1
		var center := centers[index]
		var incoming := (center - centers[maxi(0, index - 1)]).normalized() if index > 0 else (centers[1] - center).normalized()
		var outgoing := (centers[mini(centers.size() - 1, index + 1)] - center).normalized() if index < centers.size() - 1 else incoming
		var entry := centers[index - 1].lerp(center, 0.5) if index > 0 else center - incoming * 880.0
		var exit := center.lerp(centers[index + 1], 0.5) if index < centers.size() - 1 else center + outgoing * 880.0
		part_entries.append(entry)
		part_exits.append(exit)
		var profile: Dictionary = Dictionary(Array(locale_definition["profiles"])[profile_index]).duplicate(true)
		profile["pacing"] = Dictionary(recipe_slot["pacing"]).duplicate(true)
		var grammar := _build_locale_grammar(locale_id, profile_index, center, entry, exit, rng)
		var main_path: Array = grammar["main_path"]
		part_main_paths.append(main_path)
		var path_width := float(profile["path_width"])
		var route_graph := _build_route_graph(grammar, path_width)
		var sockets := _build_geography_sockets(profile_index, grammar, route_graph, entry, exit, Dictionary(recipe_slot["pacing"]))
		_add_polyline(floor_shapes, main_path, path_width, layer, index, "main_path")
		for route_index in range(Array(grammar["side_routes"]).size()):
			var route_value: Variant = Array(grammar["side_routes"])[route_index]
			var route: Array = route_value
			# Exploration routes should feel like genuine possibilities, not visibly
			# inferior stubs beside a highlighted critical path.
			_add_polyline(floor_shapes, route, maxf(SIDE_PATH_RADIUS + index * 4.0, path_width - 26.0), layer, index, "side_path")
		for zone_value in Array(grammar["zones"]):
			var zone: Dictionary = zone_value
			_add_circle(floor_shapes, Vector2(zone["pos"]), float(zone["radius"]), layer, index, String(zone["role"]))
		_add_profile_landmarks(terrain_features, profile, grammar, layer, index, rng)
		var continuation: Dictionary = {}
		if index < route_recipe.size() - 1:
			# This is not a marker or a signpost. It is a small physical threshold:
			# once found at the far edge of a locale, the player recognizes that the
			# woods continue beyond it.
			continuation = {
				"style": String(FOREST_THRESHOLD_STYLES[index]), "pos": exit,
				"direction": outgoing, "target_area_id": index + 1, "reveal_radius": 180.0,
			}
			terrain_features.append({
				"kind": "forest_pass", "style": continuation["style"], "pos": exit,
				"direction": outgoing, "radius": 92.0, "layer": layer, "part_id": index,
			})
		var safe_segments := _routes_as_segments([main_path] + Array(grammar["side_routes"]))
		var safe_points: Array = [entry, exit]
		for zone_value in Array(grammar["zones"]): safe_points.append(Vector2(Dictionary(zone_value)["pos"]))
		if index == 2:
			# Old Forest Road contains the first Awareness secret.  It is a real,
			# narrow woodland spur hidden behind blocking brush rather than an item
			# that simply appears on an already-open path.
			var middle_index := maxi(0, int((main_path.size() - 1) / 2))
			var segment_start := Vector2(main_path[middle_index])
			var segment_end := Vector2(main_path[mini(middle_index + 1, main_path.size() - 1)])
			var forward := segment_start.direction_to(segment_end)
			var side := forward.rotated(PI * 0.5)
			var first_pocket := segment_start.lerp(segment_end, 0.5) + side * 760.0
			var second_pocket := segment_start.lerp(segment_end, 0.5) - side * 760.0
			var pocket := first_pocket if first_pocket.x > 300.0 and first_pocket.y > 300.0 and first_pocket.x < EXPEDITION_WORLD_SIZE.x - 300.0 and first_pocket.y < EXPEDITION_WORLD_SIZE.y - 300.0 else second_pocket
			var passage_direction := segment_start.lerp(segment_end, 0.5).direction_to(pocket)
			var mouth := segment_start.lerp(segment_end, 0.5) + passage_direction * 230.0
			var gate_position := mouth + passage_direction * 92.0
			_add_capsule(floor_shapes, mouth, pocket, 124.0, layer, index, "secret_path")
			_add_circle(floor_shapes, pocket, 220.0, layer, index, "secret_pocket")
			safe_segments.append([mouth, pocket])
			safe_points.append(pocket)
			terrain_features.append({
				"kind": "thicket", "pos": gate_position, "radius": 252.0,
				"layer": layer, "part_id": index, "blocks": true,
				"secret_id": "old_road_rejuvenation", "secret_gate": true,
			})
			secret_passages.append({
				"id": "old_road_rejuvenation", "name": "Forager's Passage",
				"layer": layer, "area_id": index, "gate_pos": gate_position,
				"reveal_pos": mouth, "reward_pos": pocket,
				"concealment": 7, "awareness_radius": 240.0,
				"manual_radius": 58.0, "revealed": false,
				"reward": {"id": "secret_rejuvenation_old_road", "item_id": "rejuvenation", "count": 1, "pos": pocket, "layer": layer, "area_id": index, "zone_role": "secret_pocket"},
			})
		_add_forest_features(terrain_features, layer_walls[layer], safe_points, layer, rng, index, float(profile["density"]), safe_segments)
		if index < 3: _add_boundary_thickets(terrain_features, floor_shapes, layer, index, rng)

		var bounds := _bounds_for_part(floor_shapes, index)
		var area := {
			"id": index, "progression_part": index + 1,
			"kind": "boss" if index == route_recipe.size() - 1 else "start" if index == 0 else "locale",
			"name": FOREST_PART_NAMES[profile_index], "center": center, "rect": bounds,
			"entry": entry, "exit": exit, "discovered": index == 0,
			"layer": layer, "area_theme": locale_id, "locale_id": locale_id,
			"profile": profile, "zones": Array(grammar["zones"]).duplicate(true),
			"landmarks": Array(grammar["landmarks"]).duplicate(true),
			"route_graph": route_graph,
			"encounter_sockets": Array(sockets["encounters"]).duplicate(true),
			"reward_sockets": Array(sockets["rewards"]).duplicate(true),
			"respite_sockets": Array(sockets["respite"]).duplicate(true),
			"continuation": continuation,
			"pacing": Dictionary(recipe_slot["pacing"]).duplicate(true),
			"arrival_text": String(Dictionary(recipe_slot["pacing"])["label"]),
			"geography": {
				"grammar": String(profile["grammar"]),
				"branch_count": int(route_graph["branch_count"]),
				"reconnection_count": int(route_graph["reconnection_count"]),
				"optional_pocket_count": int(route_graph["optional_pocket_count"]),
			},
		}
		var part_encounters := _expedition_encounters(index + 1, Array(area["encounter_sockets"]), rng, layer, index)
		if index == route_recipe.size() - 1:
			boss_position = Vector2(grammar["boss_pos"])
			var boss_forward := entry.direction_to(exit)
			var boss_side := boss_forward.rotated(PI * 0.5)
			part_encounters.append({"kind": "werewolf", "pos": boss_position, "area_id": index, "layer": layer, "role": "boss", "zone_role": "boss_arena", "formation": "boss_pack", "pacing_pressure": 1.0})
			part_encounters.append({"kind": "hound", "pos": boss_position - boss_forward * 120.0 + boss_side * 145.0, "area_id": index, "layer": layer, "role": "boss_companion", "zone_role": "boss_arena", "formation": "boss_pack", "pacing_pressure": 1.0})
			part_encounters.append({"kind": "hound", "pos": boss_position - boss_forward * 120.0 - boss_side * 145.0, "area_id": index, "layer": layer, "role": "boss_companion", "zone_role": "boss_arena", "formation": "boss_pack", "pacing_pressure": 1.0})
			area["boss_pos"] = boss_position
		encounters[index] = part_encounters
		areas.append(area)

	for index in range(route_recipe.size() - 1):
		var seam := Vector2(part_exits[index])
		var path := [Vector2(part_main_paths[index][-2]), seam, Vector2(part_main_paths[index + 1][1])]
		connections.append({
			"id": index, "from": index, "to": index + 1, "shortcut": false,
			"shortcut_id": "", "unlocked": true, "layer": layer, "path": path,
			"path_radius": MAIN_PATH_RADIUS, "connection_type": "forest_transition",
			"corridor": _path_bounds(path, MAIN_PATH_RADIUS),
		})
	_prune_blockers_near_mandatory_paths(terrain_features, layer_walls[layer], connections, layer)

	var run_graph := _build_run_graph(areas, connections)
	var result := {
		"world_size": EXPEDITION_WORLD_SIZE, "geometry_style": "organic",
		"areas": areas, "connections": connections, "floor_shapes": floor_shapes,
		"terrain_features": terrain_features, "layer_walls": layer_walls,
		"walls": Array(layer_walls[layer]), "base_walls": Array(layer_walls[layer]),
		"encounters": encounters, "waystones": [], "shortcuts": [], "transitions": [],
		"pickups": _initial_consumable_pickups(areas, true),
		"secret_passages": secret_passages,
		"route_recipe": route_recipe,
		"run_graph": run_graph,
		"locale_catalog": locale_catalog,
		"layers": {layer: {"name": "Friendly Forest Expedition", "ground_color": "79af65"}},
		"bonfire_pos": part_entries[0], "player_start": part_entries[0],
		"exit_pos": boss_position, "shortcut_gate": Rect2(),
		"shortcut_unlock_pos": Vector2.ZERO, "shortcut_start_pos": Vector2.ZERO,
	}
	result["validation"] = validate_layout(result)
	return result

static func _expedition_route_recipe() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(FOREST_PART_PROFILES.size()):
		result.append({
			"slot": index + 1,
			"locale_id": "friendly_forest",
			"profile": index + 1,
			"pacing": Dictionary(EXPEDITION_PACING[index]).duplicate(true),
		})
	return result

static func _expedition_locale_catalog() -> Dictionary:
	return {
		"friendly_forest": {
			"name": "Friendly Forest",
			"generator": "forest",
			"profiles": FOREST_PART_PROFILES.duplicate(true),
			"socket_contract": ["encounter", "reward", "respite", "continuation"],
			"supports_progression_slots": [1, 2, 3, 4, 5, 6, 7],
		},
	}

static func _build_locale_grammar(locale_id: String, profile_index: int, center: Vector2, entry: Vector2, exit: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	match locale_id:
		"friendly_forest": return _build_forest_grammar(profile_index, center, entry, exit, rng)
		_: return _build_forest_grammar(profile_index, center, entry, exit, rng)

static func _build_run_graph(areas: Array[Dictionary], connections: Array[Dictionary]) -> Dictionary:
	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	for area in areas:
		nodes.append({
			"id": int(area["id"]), "locale_id": String(area["locale_id"]),
			"profile": int(area["progression_part"]), "entry": Vector2(area["entry"]),
			"exit": Vector2(area["exit"]), "pacing": Dictionary(area["pacing"]).duplicate(true),
			"branch_count": int(Dictionary(area["route_graph"])["branch_count"]),
			"reconnection_count": int(Dictionary(area["route_graph"])["reconnection_count"]),
		})
	for connection in connections:
		edges.append({
			"id": int(connection["id"]), "from": int(connection["from"]), "to": int(connection["to"]),
			"type": "forward_threshold", "seam": Vector2(Array(connection["path"])[1]),
		})
	return {
		"start": int(nodes[0]["id"]) if not nodes.is_empty() else -1,
		"goal": int(nodes[-1]["id"]) if not nodes.is_empty() else -1,
		"nodes": nodes, "edges": edges, "directed": true,
	}

static func _build_route_graph(grammar: Dictionary, path_width: float) -> Dictionary:
	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	var main_node_ids: Dictionary = {}
	var route_roles: Array = grammar.get("route_roles", [])
	var routes: Array = [Array(grammar["main_path"])] + Array(grammar["side_routes"])
	for route_index in range(routes.size()):
		var route: Array = routes[route_index]
		var route_role := "progression" if route_index == 0 else String(route_roles[route_index - 1]) if route_index - 1 < route_roles.size() else "alternate"
		var previous_id := -1
		for point_index in range(route.size()):
			var point := Vector2(route[point_index])
			var node_id := _route_graph_node(nodes, point)
			if route_index == 0: main_node_ids[node_id] = true
			if previous_id >= 0 and previous_id != node_id:
				edges.append({
					"id": edges.size(), "from": previous_id, "to": node_id,
					"route_id": route_index, "role": route_role,
					"mandatory": route_index == 0,
					"width": path_width if route_index == 0 else maxf(path_width - 26.0, SIDE_PATH_RADIUS),
				})
			previous_id = node_id
	var degrees: Dictionary = {}
	for edge in edges:
		degrees[int(edge["from"])] = int(degrees.get(int(edge["from"]), 0)) + 1
		degrees[int(edge["to"])] = int(degrees.get(int(edge["to"]), 0)) + 1
	for index in range(nodes.size()):
		nodes[index]["degree"] = int(degrees.get(index, 0))
		nodes[index]["role"] = "junction" if int(nodes[index]["degree"]) >= 3 else "path"
	for zone_value in Array(grammar["zones"]):
		var zone: Dictionary = zone_value
		var nearest_id := _nearest_route_node(nodes, Vector2(zone["pos"]))
		if nearest_id >= 0 and Vector2(nodes[nearest_id]["pos"]).distance_to(Vector2(zone["pos"])) <= maxf(80.0, float(zone["radius"]) * 0.35):
			nodes[nearest_id]["role"] = String(zone["role"])
	var reconnections := 0
	var optional_pockets := 0
	for route_index in range(1, routes.size()):
		var route: Array = routes[route_index]
		var first_id := _nearest_route_node(nodes, Vector2(route[0]))
		var last_id := _nearest_route_node(nodes, Vector2(route[-1]))
		var role := String(route_roles[route_index - 1]) if route_index - 1 < route_roles.size() else "alternate"
		if main_node_ids.has(first_id) and main_node_ids.has(last_id) and first_id != last_id:
			reconnections += 1
		if role == "reward_spur" or not main_node_ids.has(last_id):
			optional_pockets += 1
	var branch_count := 0
	for node in nodes:
		if int(node["degree"]) >= 3: branch_count += 1
	return {
		"entry_node": _nearest_route_node(nodes, Vector2(Array(grammar["main_path"])[0])),
		"exit_node": _nearest_route_node(nodes, Vector2(Array(grammar["main_path"])[-1])),
		"nodes": nodes, "edges": edges,
		"branch_count": branch_count, "reconnection_count": reconnections,
		"optional_pocket_count": optional_pockets,
	}

static func _route_graph_node(nodes: Array[Dictionary], point: Vector2) -> int:
	for index in range(nodes.size()):
		if Vector2(nodes[index]["pos"]).distance_to(point) < 1.0: return index
	nodes.append({"id": nodes.size(), "pos": point})
	return nodes.size() - 1

static func _nearest_route_node(nodes: Array[Dictionary], point: Vector2) -> int:
	var result := -1
	var best_distance := INF
	for index in range(nodes.size()):
		var distance := Vector2(nodes[index]["pos"]).distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			result = index
	return result

static func _build_geography_sockets(index: int, grammar: Dictionary, route_graph: Dictionary, entry: Vector2, exit: Vector2, pacing: Dictionary) -> Dictionary:
	var encounters: Array[Dictionary] = []
	var rewards: Array[Dictionary] = []
	var respite: Array[Dictionary] = []
	var reward_role := String(FOREST_REWARD_ROLES[index])
	var quiet_roles := ["landmark", "heart_tree", "quiet_spoke", reward_role]
	var forward := entry.direction_to(exit)
	var span := maxf(1.0, entry.distance_to(exit))
	for zone_value in Array(grammar["zones"]):
		var zone: Dictionary = zone_value
		var role := String(zone["role"])
		var progress := clampf((Vector2(zone["pos"]) - entry).dot(forward) / span, 0.0, 1.0)
		var socket := {
			"id": "%d_%s" % [index, role], "pos": Vector2(zone["pos"]),
			"role": role, "radius": float(zone["radius"]),
			"progress": progress, "pressure": float(pacing["pressure"]) * (0.72 + progress * 0.38),
			"formation": _formation_for_part(index + 1),
		}
		if role == reward_role:
			socket["optional"] = true
			socket["reward_budget"] = int(pacing["reward_budget"])
			rewards.append(socket)
		elif role not in quiet_roles:
			encounters.append(socket)
	if rewards.is_empty():
		var fallback_zone: Dictionary = Array(grammar["zones"])[-1]
		rewards.append({
			"id": "%d_fallback_reward" % index, "pos": Vector2(fallback_zone["pos"]),
			"role": String(fallback_zone["role"]), "radius": float(fallback_zone["radius"]),
			"optional": true, "reward_budget": int(pacing["reward_budget"]),
		})
	var main_path: Array = grammar["main_path"]
	var respite_pos := Vector2(main_path[0]).lerp(Vector2(main_path[1]), 0.42)
	respite.append({
		"id": "%d_arrival_respite" % index, "pos": respite_pos,
		"role": "arrival_respite", "radius": 230.0, "protected": true,
	})
	return {
		"encounters": encounters, "rewards": rewards, "respite": respite,
		"continuation": {"pos": exit, "role": "continuation", "protected": true},
		"route_graph": route_graph,
	}

static func _formation_for_part(part: int) -> String:
	var formations := [
		"loose_pack", "pursuit_pair", "knife_screen", "caster_arc",
		"crossfire", "guarded_line", "boss_court",
	]
	return String(formations[clampi(part - 1, 0, formations.size() - 1)])

static func _build_forest_grammar(index: int, center: Vector2, entry: Vector2, exit: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var forward := entry.direction_to(exit)
	var side := forward.rotated(PI * 0.5)
	var sign := -1.0 if (index + rng.randi()) % 2 == 0 else 1.0
	var main: Array = [entry]
	var side_routes: Array = []
	var route_roles: Array[String] = []
	var zones: Array[Dictionary] = []
	var sockets: Array[Dictionary] = []
	var landmarks: Array[Dictionary] = []
	var boss_pos := center + forward * 260.0
	match index:
		0: # Three separated meadow glades joined by readable worn paths.
			var a := entry.lerp(center, 0.55) + side * sign * 130.0
			var b := center + forward * 360.0 - side * sign * 110.0
			main += [a, center, b, exit]
			var meadow_a := center + side * sign * 980.0 - forward * 220.0
			var meadow_b := center + side * sign * 940.0 + forward * 520.0
			var forager_pocket := meadow_a + side * sign * 360.0 - forward * 170.0
			side_routes = [[a, meadow_a, meadow_b, b], [meadow_a, forager_pocket]]
			route_roles = ["alternate", "reward_spur"]
			zones = [_zone(center, 480.0, "landmark"), _zone(meadow_a, 390.0, "optional_glade"), _zone(meadow_b, 370.0, "rejoining_glade"), _zone(forager_pocket, 300.0, "forager_pocket")]
			landmarks = [{"kind": "meadow", "pos": center}]
		1: # A brook cuts across the forest with a direct and a lateral ford.
			var crossing := center - forward * 80.0
			var near_bank := crossing - forward * 300.0
			var far_bank := crossing + forward * 300.0
			var second_ford := crossing + side * sign * 720.0
			var second_near := second_ford - forward * 280.0
			var second_far := second_ford + forward * 280.0
			var reed_pocket := second_far + side * sign * 390.0 + forward * 90.0
			main += [entry.lerp(near_bank, 0.50), near_bank, crossing, far_bank, far_bank.lerp(exit, 0.55), exit]
			side_routes = [[near_bank, second_near, second_ford, second_far, far_bank], [far_bank, crossing - side * sign * 690.0 + forward * 300.0, main[5]], [second_far, reed_pocket]]
			route_roles = ["alternate", "alternate", "reward_spur"]
			zones = [_zone(crossing, 235.0, "brook_crossing"), _zone(second_ford, 220.0, "second_ford"), _zone(second_far, 330.0, "bank_glade"), _zone(side_routes[1][1], 320.0, "optional_bank"), _zone(reed_pocket, 290.0, "reed_pocket")]
			landmarks = [{"kind": "brook", "pos": crossing, "from": crossing - side * 1080.0, "to": crossing + side * 1080.0, "width": 145.0, "fords": [crossing, second_ford]}]
		2: # A readable old road with an overgrown detour.
			var road_a := entry.lerp(exit, 0.33)
			var road_b := entry.lerp(exit, 0.68)
			main += [road_a, center, road_b, exit]
			var detour_a := road_a + side * sign * 870.0
			var detour_b := road_b + side * sign * 900.0
			var lost_waystation := detour_a + side * sign * 350.0 - forward * 210.0
			side_routes = [[road_a, detour_a, detour_b, road_b], [detour_a, lost_waystation]]
			route_roles = ["alternate", "reward_spur"]
			zones = [_zone(center, 390.0, "road_landmark"), _zone(detour_a, 340.0, "overgrown_detour"), _zone(detour_b, 350.0, "roadside_glade"), _zone(lost_waystation, 300.0, "lost_waystation")]
			landmarks = [{"kind": "old_road", "pos": center, "from": entry, "to": exit, "width": 210.0}]
		3: # A radial grove with several readable spokes.
			var hub := center + side * sign * 90.0
			main += [entry.lerp(hub, 0.52), hub, hub.lerp(exit, 0.52), exit]
			var north := hub + side * 690.0
			var south := hub - side * 650.0
			var outer := hub + forward * 420.0 + side * sign * 570.0
			var elder_hollow := south - forward * 330.0 - side * sign * 120.0
			side_routes = [[hub, north, outer, main[3]], [hub, south, main[1]], [south, elder_hollow]]
			route_roles = ["alternate", "alternate", "reward_spur"]
			zones = [_zone(hub, 540.0, "radial_hub"), _zone(north, 370.0, "elder_glade"), _zone(south, 350.0, "south_spoke"), _zone(outer, 390.0, "outer_spoke"), _zone(elder_hollow, 310.0, "quiet_spoke")]
			landmarks = [{"kind": "stone_circle", "pos": hub}]
		4: # Braided routes shaped by great roots.
			var split := entry.lerp(center, 0.56)
			var join := center.lerp(exit, 0.58)
			var upper := center + side * 470.0
			var lower := center - side * 470.0
			main += [split, upper if sign > 0 else lower, join, exit]
			var root_hollow := center + forward * 300.0 - side * sign * 1040.0
			var outer_root := center + forward * 300.0 - side * sign * 690.0
			side_routes = [[split, lower if sign > 0 else upper, join], [main[2], outer_root, join], [outer_root, root_hollow]]
			route_roles = ["alternate", "alternate", "reward_spur"]
			zones = [_zone(split, 370.0, "root_junction"), _zone(upper, 390.0, "upper_braid"), _zone(lower, 390.0, "lower_braid"), _zone(join, 430.0, "rejoining_roots"), _zone(root_hollow, 310.0, "root_hollow")]
			landmarks = [{"kind": "roots", "pos": center}]
		5: # Ruined courts interrupt the forest rather than replacing it.
			var court_a := center - forward * 390.0 + side * sign * 170.0
			var court_b := center + forward * 390.0 - side * sign * 180.0
			main += [entry.lerp(court_a, 0.55), court_a, center, court_b, court_b.lerp(exit, 0.52), exit]
			var cloister := center + side * sign * 700.0
			var collapsed_chamber := cloister + side * sign * 390.0 - forward * 170.0
			side_routes = [[court_a, cloister, court_b], [cloister, collapsed_chamber]]
			route_roles = ["alternate", "reward_spur"]
			zones = [_zone(court_a, 450.0, "ruin_court"), _zone(center, 500.0, "broken_hall"), _zone(court_b, 450.0, "ruin_exit"), _zone(cloister, 390.0, "side_cloister"), _zone(collapsed_chamber, 315.0, "collapsed_chamber")]
			landmarks = [{"kind": "ancient_ruin", "pos": center}]
		_: # A broad ceremonial approach and boss perimeter.
			var approach := center - forward * 420.0
			var arena := center + forward * 260.0
			boss_pos = arena
			main += [entry.lerp(approach, 0.55), approach, center, arena, exit]
			var left := arena + side * 650.0
			var right := arena - side * 650.0
			var perimeter_shrine := left + side * 360.0 - forward * 150.0
			side_routes = [[approach, left, arena], [approach, right, arena], [left, perimeter_shrine]]
			route_roles = ["alternate", "alternate", "reward_spur"]
			zones = [_zone(approach, 480.0, "boss_approach"), _zone(center, 520.0, "heart_tree"), _zone(arena, 720.0, "boss_arena"), _zone(left, 380.0, "arena_perimeter"), _zone(right, 380.0, "arena_perimeter"), _zone(perimeter_shrine, 320.0, "perimeter_shrine")]
			landmarks = [{"kind": "heart_tree", "pos": center}]
	for zone in zones:
		var role := String(zone["role"])
		if role not in ["quiet_spoke", "landmark", "heart_tree"]: sockets.append({"pos": Vector2(zone["pos"]), "role": role, "radius": float(zone["radius"])})
	return {"main_path": main, "side_routes": side_routes, "route_roles": route_roles, "zones": zones, "encounter_sockets": sockets, "landmarks": landmarks, "boss_pos": boss_pos}

static func _generate_campaign_loop(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var surface := "forest_surface"
	var depths := "ruin_depths"
	var definitions := [
		{"id": 0, "name": "Dawn Grove", "kind": "waystone", "center": Vector2(1200, 4800), "layer": surface, "profile": 0},
		{"id": 1, "name": "Brook Path", "kind": "locale", "center": Vector2(2600, 4300), "layer": surface, "profile": 1},
		{"id": 2, "name": "Moss Waystone", "kind": "waystone", "center": Vector2(3900, 4700), "layer": surface, "profile": 2},
		{"id": 3, "name": "Elder Trail", "kind": "locale", "center": Vector2(5200, 3200), "layer": surface, "profile": 3},
		{"id": 4, "name": "Root Waystone", "kind": "waystone", "center": Vector2(6500, 3500), "layer": surface, "profile": 4},
		{"id": 5, "name": "Sunken Ruin", "kind": "ruin", "center": Vector2(7800, 2100), "layer": surface, "profile": 5},
		{"id": 6, "name": "Buried Hall", "kind": "depths", "center": Vector2(7800, 2100), "layer": depths, "profile": 5},
		{"id": 7, "name": "Root Vault", "kind": "boss", "center": Vector2(6200, 1750), "layer": depths, "profile": 6},
		{"id": 8, "name": "Old Lift", "kind": "depths", "center": Vector2(1200, 1800), "layer": depths, "profile": 5},
		{"id": 9, "name": "Forgotten Grove", "kind": "hidden_grove", "center": Vector2(1200, 1800), "layer": surface, "profile": 4},
	]
	var areas: Array[Dictionary] = []
	var floor_shapes: Array[Dictionary] = []
	var terrain_features: Array[Dictionary] = []
	var layer_walls := {surface: [], depths: []}
	var safe_routes: Array = [
		[Vector2(1200, 4800), Vector2(1750, 4100), Vector2(2600, 4300)],
		[Vector2(2600, 4300), Vector2(3250, 5000), Vector2(3900, 4700)],
		[Vector2(3900, 4700), Vector2(3600, 2700), Vector2(4700, 2300), Vector2(5200, 3200)],
		[Vector2(5200, 3200), Vector2(5850, 3900), Vector2(6500, 3500)],
		[Vector2(6500, 3500), Vector2(7050, 2600), Vector2(7800, 2100)],
		[Vector2(7800, 2100), Vector2(7100, 1350), Vector2(6200, 1750)],
		[Vector2(6200, 1750), Vector2(4650, 2400), Vector2(3000, 1450), Vector2(1200, 1800)],
	]
	var all_safe_segments := _routes_as_segments(safe_routes)
	for value in definitions:
		var definition := Dictionary(value)
		var id := int(definition["id"])
		var center := Vector2(definition["center"])
		var layer := String(definition["layer"])
		var profile_index := int(definition["profile"])
		var profile: Dictionary = Dictionary(FOREST_PART_PROFILES[profile_index]).duplicate(true)
		if layer == depths:
			profile["ground_color"] = "596653"
			profile["palette"] = "ruin_depths"
		var radius := 650.0 if id in [0, 2, 4, 7] else 560.0
		var offset := Vector2(rng.randf_range(140.0, 230.0), rng.randf_range(-180.0, 160.0))
		_add_circle(floor_shapes, center, radius, layer, id, "area_core")
		_add_circle(floor_shapes, center + offset, radius * 0.72, layer, id, "area_lobe")
		_add_circle(floor_shapes, center - offset.rotated(0.35), radius * 0.58, layer, id, "area_lobe")
		var zones := [_zone(center, radius, "waystone_sanctuary" if String(definition["kind"]) == "waystone" else "boss_arena" if String(definition["kind"]) == "boss" else "campaign_locale")]
		var area := definition.duplicate(true)
		area["rect"] = _bounds_for_part(floor_shapes, id)
		area["discovered"] = id == 0
		area["area_theme"] = "friendly_forest" if layer == surface else "forest_ruin"
		area["profile"] = profile
		area["zones"] = zones
		area["landmarks"] = [{"kind": profile["landmark"], "pos": center}]
		areas.append(area)
		_add_profile_landmarks(terrain_features, profile, {"landmarks": area["landmarks"]}, layer, id, rng)
		_add_forest_features(terrain_features, layer_walls[layer], [center], layer, rng, id, 0.76 if layer == surface else 0.28, all_safe_segments)

	var connections: Array[Dictionary] = []
	_add_campaign_path(connections, floor_shapes, 0, 1, safe_routes[0], surface)
	_add_campaign_path(connections, floor_shapes, 1, 2, safe_routes[1], surface)
	_add_campaign_path(connections, floor_shapes, 2, 3, safe_routes[2], surface)
	_add_campaign_path(connections, floor_shapes, 3, 4, safe_routes[3], surface)
	_add_campaign_path(connections, floor_shapes, 4, 5, safe_routes[4], surface)
	_add_campaign_path(connections, floor_shapes, 6, 7, safe_routes[5], depths)
	_add_campaign_path(connections, floor_shapes, 7, 8, safe_routes[6], depths)

	var local_path := [Vector2(5200, 3200), Vector2(5200, 4700), Vector2(3900, 4700)]
	var local_gate := Rect2(Vector2(4510, 4510), Vector2(120, 380))
	_add_shortcut_connection(connections, floor_shapes, 3, 2, local_path, surface, "moss_hidden_path_v3", 135.0)
	var return_path := [Vector2(1200, 1800), Vector2(300, 1800), Vector2(300, 4800), Vector2(1200, 4800)]
	var return_gate := Rect2(Vector2(640, 4610), Vector2(120, 380))
	_add_shortcut_connection(connections, floor_shapes, 9, 0, return_path, surface, "dawn_ruin_return_v3", 135.0)
	var shortcuts := [
		{"id": "moss_hidden_path_v3", "name": "Hidden Moss Path", "connection_id": connections.size() - 2, "gate": local_gate, "unlock_pos": Vector2(4780, 4700), "far_pos": Vector2(4780, 4700), "near_pos": Vector2(4320, 4700), "layer": surface, "unlocked": false, "presentation": "hidden_woodland_path", "interaction_radius": 175.0},
		{"id": "dawn_ruin_return_v3", "name": "Hidden Dawn Path", "connection_id": connections.size() - 1, "gate": return_gate, "unlock_pos": Vector2(500, 4800), "far_pos": Vector2(500, 4800), "near_pos": Vector2(900, 4800), "layer": surface, "unlocked": false, "presentation": "hidden_woodland_path", "interaction_radius": 175.0},
	]
	var transitions := [
		{"id": "ruin_stairs", "kind": "stairs_down", "from_layer": surface, "from_pos": Vector2(7800, 2100), "to_layer": depths, "to_pos": Vector2(7800, 2100), "unlocked": true},
		{"id": "old_lift", "kind": "ladder", "from_layer": depths, "from_pos": Vector2(1200, 1800), "to_layer": surface, "to_pos": Vector2(1200, 1800), "unlocked": true},
	]
	_prune_blockers_near_mandatory_paths(terrain_features, layer_walls[surface], connections, surface)
	_prune_blockers_near_mandatory_paths(terrain_features, layer_walls[depths], connections, depths)
	var encounters: Dictionary = {}
	for area in areas:
		var id := int(area["id"])
		if id in [0, 2, 4, 9]: continue
		encounters[id] = _campaign_encounter(id, Vector2(area["center"]), String(area["layer"]), rng)
	var campaign_boss_pos := Vector2(6320, 1710)
	areas[7]["boss_pos"] = campaign_boss_pos
	var boss_encounter: Array = encounters[7]
	boss_encounter.append({"kind": "warden", "pos": campaign_boss_pos, "area_id": 7, "layer": depths, "role": "boss", "zone_role": "boss_arena"})
	encounters[7] = boss_encounter
	var waystones := [
		{"id": "dawn", "name": "Dawn Waystone", "pos": Vector2(1200, 4800), "layer": surface},
		{"id": "moss", "name": "Moss Waystone", "pos": Vector2(3900, 4700), "layer": surface},
		{"id": "root", "name": "Root Waystone", "pos": Vector2(6500, 3500), "layer": surface},
	]
	var result := {
		"world_size": CAMPAIGN_WORLD_SIZE, "geometry_style": "organic",
		"areas": areas, "connections": connections, "floor_shapes": floor_shapes,
		"terrain_features": terrain_features, "layer_walls": layer_walls,
		"walls": Array(layer_walls[surface]), "base_walls": Array(layer_walls[surface]),
		"encounters": encounters, "waystones": waystones, "shortcuts": shortcuts,
		"transitions": transitions,
		"pickups": _initial_consumable_pickups(areas, false),
		"layers": {surface: {"name": "Friendly Forest", "ground_color": "82b86d"}, depths: {"name": "Ruin Depths", "ground_color": "596653"}},
		"bonfire_pos": Vector2(1200, 4800), "player_start": Vector2(1200, 5000),
		"exit_pos": Vector2(1200, 1800), "shortcut_gate": return_gate,
		"shortcut_unlock_pos": Vector2(shortcuts[1]["unlock_pos"]), "shortcut_start_pos": Vector2(shortcuts[1]["near_pos"]),
	}
	result["validation"] = validate_layout(result)
	return result

static func _initial_consumable_pickups(areas: Array[Dictionary], expedition: bool) -> Array[Dictionary]:
	# Supplies occupy explicit geography sockets. They remain optional discoveries
	# instead of being guaranteed on the forward route, while future loot families
	# can reuse the same sockets without knowing a locale's internal grammar.
	var cycle := ["rejuvenation", "firebomb", "throwing_knife", "smoke_vial", "rejuvenation", "firebomb", "throwing_knife"]
	var result: Array[Dictionary] = []
	for index in range(areas.size()):
		var area: Dictionary = areas[index]
		if not expedition and String(area.get("kind", "")) in ["waystone", "depths", "hidden_grove"]: continue
		var point := Vector2(area.get("center", Vector2.ZERO))
		var socket_id := ""
		var zone_role := "fallback"
		var reward_sockets: Array = area.get("reward_sockets", [])
		if not reward_sockets.is_empty():
			var socket: Dictionary = reward_sockets[0]
			point = Vector2(socket["pos"])
			socket_id = String(socket["id"])
			zone_role = String(socket["role"])
		else:
			var zones: Array = area.get("zones", [])
			for zone_value in zones:
				var zone: Dictionary = zone_value
				var role := String(zone.get("role", ""))
				if role.contains("optional") or role in ["elder_glade", "outer_spoke", "side_cloister", "bank_glade"]:
					point = Vector2(zone["pos"])
					zone_role = role
					break
		var item_id := String(cycle[index % cycle.size()])
		result.append({
			"id": "consumable_%s_%d" % ["expedition" if expedition else "campaign", index],
			"item_id": item_id, "count": 2 if item_id == "throwing_knife" else 1,
			"pos": point, "layer": String(area.get("layer", "expedition_surface")),
			"area_id": int(area.get("id", index)), "socket_id": socket_id,
			"zone_role": zone_role,
		})
	return result

static func _expedition_encounters(part: int, sockets: Array, rng: RandomNumberGenerator, layer: String, area_id: int) -> Array[Dictionary]:
	var rosters := {
		1: ["boar", "boar", "boar", "boar", "boar", "boar", "boar", "boar"],
		2: ["boar", "hound", "boar", "hound", "boar", "hound", "boar", "hound", "boar"],
		3: ["bandit", "hound", "bandit", "hound", "bandit", "hound", "bandit", "hound", "bandit", "hound"],
		4: ["ice_caster", "fire_caster", "ice_caster", "fire_caster", "ice_caster", "fire_caster", "ice_caster"],
		5: ["bandit", "archer", "bandit", "archer", "bandit", "archer", "bandit", "archer", "bandit", "archer", "bandit", "bandit"],
		6: ["knight", "archer", "archer", "archer", "knight", "archer", "archer", "archer", "knight", "archer", "archer", "archer", "archer"],
		7: ["knight", "knight", "archer", "archer", "archer", "archer", "archer", "ice_caster", "ice_caster", "fire_caster", "fire_caster"],
	}
	var roster: Array = rosters[part]
	var placement_sockets: Array = sockets
	if part == 7:
		placement_sockets = []
		for socket_value in sockets:
			var socket := Dictionary(socket_value)
			if String(socket.get("role", "")) != "boss_arena": placement_sockets.append(socket)
		if placement_sockets.is_empty(): placement_sockets = sockets
	placement_sockets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("progress", 0.5)) < float(b.get("progress", 0.5))
	)
	var result: Array[Dictionary] = []
	var offsets := [Vector2(-145, -100), Vector2(145, -90), Vector2(-125, 125), Vector2(135, 130)]
	for index in range(roster.size()):
		var kind := String(roster[index])
		# Fill geographic bands in progression order. This creates readable local
		# problems and actual relief between them instead of round-robin enemies
		# smeared evenly across the entire locale.
		var socket_index := mini(maxi(0, placement_sockets.size() - 1), int(floor(float(index) * float(maxi(1, placement_sockets.size())) / float(maxi(1, roster.size())))))
		var socket: Dictionary = placement_sockets[socket_index] if not placement_sockets.is_empty() else {"pos": Vector2.ZERO, "role": "path"}
		var local_index := 0
		for previous in range(index):
			var previous_socket := mini(maxi(0, placement_sockets.size() - 1), int(floor(float(previous) * float(maxi(1, placement_sockets.size())) / float(maxi(1, roster.size())))))
			if previous_socket == socket_index: local_index += 1
		var offset: Vector2 = Vector2(offsets[local_index % offsets.size()]).rotated(rng.randf_range(-0.28, 0.28)) * (1.0 + int(local_index / offsets.size()) * 0.24)
		# Casters need enough room that their circles and cones read as separate
		# problems rather than one indistinct stack of danger zones.
		if kind in ["ice_caster", "fire_caster", "hexer"]:
			offset *= 1.52 + int(local_index / offsets.size()) * 0.10
		result.append({
			"kind": kind, "pos": Vector2(socket["pos"]) + offset,
			"area_id": area_id, "layer": layer, "cluster": socket_index, "zone_role": String(socket.get("role", "path")),
			"formation": String(socket.get("formation", "loose_pack")),
			"pacing_pressure": float(socket.get("pressure", 0.5)),
		})
	return result

static func _campaign_encounter(area_id: int, center: Vector2, layer: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var rosters := {
		1: ["blade", "knife", "hound", "archer", "blade"],
		3: ["polearm", "archer", "hexer", "blade", "hound", "captain"],
		5: ["polearm", "archer", "hexer", "blade", "hound", "captain"],
		6: ["hound", "hexer", "polearm", "knife", "blade", "hexer"],
		7: ["brute", "hexer", "polearm", "captain", "blade", "hound"],
		8: ["brute", "polearm", "hound", "archer", "knife"],
	}
	var roster: Array = rosters.get(area_id, ["blade", "hound", "knife"])
	var offsets := [Vector2(-210, -120), Vector2(210, -110), Vector2(-190, 160), Vector2(190, 160), Vector2(0, -240), Vector2(0, 230)]
	var result: Array[Dictionary] = []
	for index in range(roster.size()):
		result.append({"kind": String(roster[index]), "pos": center + offsets[index].rotated(rng.randf_range(-0.18, 0.18)), "area_id": area_id, "layer": layer, "cluster": int(index / 3), "zone_role": "campaign_locale"})
	return result

static func _add_profile_landmarks(features: Array[Dictionary], profile: Dictionary, grammar: Dictionary, layer: String, part_id: int, rng: RandomNumberGenerator) -> void:
	for value in Array(grammar.get("landmarks", [])):
		var landmark: Dictionary = Dictionary(value).duplicate(true)
		landmark["layer"] = layer
		landmark["part_id"] = part_id
		landmark["radius"] = 56.0
		match String(landmark["kind"]):
			"meadow": landmark["radius"] = 120.0
			"brook": landmark["radius"] = 920.0
			"old_road": landmark["radius"] = 800.0
			"stone_circle": landmark["radius"] = 155.0
			"roots": landmark["radius"] = 180.0
			"ancient_ruin": landmark["radius"] = 220.0
			"heart_tree":
				landmark["radius"] = 92.0
				landmark["blocks"] = true
		features.append(landmark)
	# Small profile-specific traces make a locale readable between its main landmarks.
	var kind := "flowers" if String(profile["landmark"]) == "meadow" else "roots" if String(profile["landmark"]) == "roots" else "ruin_fragment" if String(profile["landmark"]) == "ancient_ruin" else "undergrowth"
	for index in range(3):
		var base := Vector2(Array(grammar.get("landmarks", [{"pos": Vector2.ZERO}]))[0].get("pos", Vector2.ZERO))
		features.append({"kind": kind, "pos": base + Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(180.0, 330.0), "radius": rng.randf_range(28.0, 48.0), "layer": layer, "part_id": part_id})

static func _add_boundary_thickets(features: Array[Dictionary], shapes: Array[Dictionary], layer: String, part_id: int, rng: RandomNumberGenerator) -> void:
	var candidates: Array[Vector2] = []
	for shape in shapes:
		if int(shape.get("part_id", -1)) != part_id or String(shape.get("layer", layer)) != layer: continue
		var radius := float(shape["radius"])
		if String(shape["kind"]) == "capsule":
			var start := Vector2(shape["from"])
			var finish := Vector2(shape["to"])
			var direction := start.direction_to(finish)
			var side := direction.rotated(PI * 0.5)
			var steps := maxi(2, int(ceil(start.distance_to(finish) / 175.0)))
			for step in range(steps + 1):
				var point := start.lerp(finish, float(step) / float(steps))
				candidates.append(point + side * (radius + rng.randf_range(28.0, 62.0)))
				candidates.append(point - side * (radius + rng.randf_range(28.0, 62.0)))
		else:
			var center := Vector2(shape["center"])
			var count := maxi(10, int(ceil(TAU * radius / 190.0)))
			var phase := rng.randf_range(0.0, TAU)
			for step in range(count): candidates.append(center + Vector2.RIGHT.rotated(phase + TAU * float(step) / float(count)) * (radius + rng.randf_range(26.0, 58.0)))
	for candidate in candidates:
		if candidate.x < 80.0 or candidate.y < 80.0 or _point_inside_part_shapes(candidate, shapes, part_id, layer): continue
		var crowded := false
		for existing in features:
			if int(existing.get("part_id", -1)) == part_id and bool(existing.get("boundary", false)) and Vector2(existing["pos"]).distance_to(candidate) < 105.0:
				crowded = true
				break
		if crowded: continue
		features.append({"kind": "thicket", "pos": candidate, "radius": rng.randf_range(44.0, 62.0), "layer": layer, "part_id": part_id, "boundary": true})

static func _point_inside_part_shapes(point: Vector2, shapes: Array[Dictionary], part_id: int, layer: String) -> bool:
	for shape in shapes:
		if int(shape.get("part_id", -1)) != part_id or String(shape.get("layer", layer)) != layer: continue
		var radius := float(shape["radius"])
		if String(shape["kind"]) == "circle" and point.distance_to(Vector2(shape["center"])) <= radius + 10.0: return true
		if String(shape["kind"]) == "capsule" and _distance_to_segment(point, Vector2(shape["from"]), Vector2(shape["to"])) <= radius + 10.0: return true
	return false

static func _add_campaign_path(connections: Array[Dictionary], shapes: Array[Dictionary], from_id: int, to_id: int, path: Array, layer: String) -> void:
	_add_polyline(shapes, path, 330.0, layer, from_id, "main_path")
	connections.append({"id": connections.size(), "from": from_id, "to": to_id, "shortcut": false, "shortcut_id": "", "unlocked": true, "layer": layer, "path": path, "path_radius": 330.0, "connection_type": "campaign_route", "corridor": _path_bounds(path, 330.0)})

static func _add_shortcut_connection(connections: Array[Dictionary], shapes: Array[Dictionary], from_id: int, to_id: int, path: Array, layer: String, shortcut_id: String, radius: float = 135.0) -> void:
	_add_polyline(shapes, path, radius, layer, from_id, "shortcut_path")
	connections.append({"id": connections.size(), "from": from_id, "to": to_id, "shortcut": true, "shortcut_id": shortcut_id, "unlocked": false, "layer": layer, "path": path, "path_radius": radius, "connection_type": "hidden_woodland_path", "corridor": _path_bounds(path, radius)})

static func _add_polyline(shapes: Array[Dictionary], path: Array, radius: float, layer: String, part_id: int, semantic: String) -> void:
	for index in range(path.size() - 1): _add_capsule(shapes, Vector2(path[index]), Vector2(path[index + 1]), radius, layer, part_id, semantic)

static func _add_circle(shapes: Array[Dictionary], center: Vector2, radius: float, layer: String, part_id: int, semantic: String = "clearing") -> void:
	shapes.append({"kind": "circle", "center": center, "radius": radius, "layer": layer, "part_id": part_id, "semantic": semantic})

static func _add_capsule(shapes: Array[Dictionary], start: Vector2, finish: Vector2, radius: float, layer: String, part_id: int, semantic: String = "path") -> void:
	shapes.append({"kind": "capsule", "from": start, "to": finish, "radius": radius, "layer": layer, "part_id": part_id, "semantic": semantic})

static func _zone(position: Vector2, radius: float, role: String) -> Dictionary:
	return {"pos": position, "radius": radius, "role": role}

static func _routes_as_segments(routes: Array) -> Array:
	var result: Array = []
	for route_value in routes:
		var route: Array = route_value
		for index in range(route.size() - 1): result.append([Vector2(route[index]), Vector2(route[index + 1])])
	return result

static func _bounds_for_part(shapes: Array[Dictionary], part_id: int) -> Rect2:
	var bounds := Rect2()
	var found := false
	for shape in shapes:
		if int(shape.get("part_id", -1)) != part_id: continue
		var shape_bounds := _shape_bounds(shape)
		bounds = shape_bounds if not found else bounds.merge(shape_bounds)
		found = true
	return bounds

static func _shape_bounds(shape: Dictionary) -> Rect2:
	var radius := float(shape["radius"])
	if String(shape["kind"]) == "circle": return Rect2(Vector2(shape["center"]) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	var start := Vector2(shape["from"])
	var finish := Vector2(shape["to"])
	return Rect2(start.min(finish) - Vector2.ONE * radius, (start.max(finish) - start.min(finish)) + Vector2.ONE * radius * 2.0)

static func _path_bounds(path: Array, radius: float) -> Rect2:
	var minimum := Vector2(path[0])
	var maximum := minimum
	for value in path:
		var point := Vector2(value)
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum - Vector2.ONE * radius, maximum - minimum + Vector2.ONE * radius * 2.0)

static func _add_forest_features(features: Array[Dictionary], walls: Array, safe_points: Array, layer: String, rng: RandomNumberGenerator, part_id: int, density: float, safe_segments: Array = []) -> void:
	for safe_value in safe_points:
		var clearing := Vector2(safe_value)
		var count := maxi(5, int(round(7.0 * density)))
		var phase := rng.randf_range(0.0, TAU)
		for index in range(count):
			var direction := Vector2.RIGHT.rotated(phase + TAU * float(index) / float(count) + rng.randf_range(-0.14, 0.14))
			var position := clearing + direction * rng.randf_range(330.0, 500.0)
			var safe := false
			for point_value in safe_points:
				if position.distance_to(Vector2(point_value)) < 235.0: safe = true
			for segment_value in safe_segments:
				var segment: Array = segment_value
				if _distance_to_segment(position, Vector2(segment[0]), Vector2(segment[1])) < 205.0: safe = true
			if safe: continue
			var radius := rng.randf_range(34.0, 54.0)
			var feature := {"kind": "tree", "pos": position, "radius": radius, "layer": layer, "part_id": part_id, "blocks": true}
			features.append(feature)
			walls.append(_feature_wall(feature))

static func _feature_wall(feature: Dictionary) -> Rect2:
	var radius := float(feature.get("radius", 40.0))
	return Rect2(Vector2(feature["pos"]) - Vector2.ONE * radius * 0.42, Vector2.ONE * radius * 0.84)

static func _prune_blockers_near_mandatory_paths(features: Array[Dictionary], walls: Array, connections: Array[Dictionary], layer: String) -> void:
	var mandatory_segments: Array = []
	for connection in connections:
		if bool(connection.get("shortcut", false)) or String(connection.get("layer", layer)) != layer: continue
		var path: Array = connection.get("path", [])
		for index in range(path.size() - 1): mandatory_segments.append([Vector2(path[index]), Vector2(path[index + 1])])
	for index in range(features.size() - 1, -1, -1):
		var feature: Dictionary = features[index]
		if String(feature.get("layer", layer)) != layer or not bool(feature.get("blocks", false)): continue
		var position := Vector2(feature["pos"])
		var unsafe := false
		for segment_value in mandatory_segments:
			var segment: Array = segment_value
			if _distance_to_segment(position, Vector2(segment[0]), Vector2(segment[1])) < 190.0:
				unsafe = true
				break
		if unsafe: features.remove_at(index)
	walls.clear()
	for feature in features:
		if String(feature.get("layer", layer)) == layer and bool(feature.get("blocks", false)): walls.append(_feature_wall(feature))

static func _layout_point_on_floor(layout: Dictionary, point: Vector2, layer: String) -> bool:
	for shape_value in Array(layout.get("floor_shapes", [])):
		var shape: Dictionary = shape_value
		if String(shape.get("layer", layer)) != layer: continue
		var radius := float(shape.get("radius", 0.0))
		if String(shape.get("kind", "circle")) == "circle" and point.distance_to(Vector2(shape["center"])) <= radius: return true
		if String(shape.get("kind", "")) == "capsule" and _distance_to_segment(point, Vector2(shape["from"]), Vector2(shape["to"])) <= radius: return true
	return false

static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.001: return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * amount)
