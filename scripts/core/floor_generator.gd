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
	{"palette": "forest_1", "ground_color": "82b86d", "density": 0.68, "landmark": "meadow", "grammar": "open_glades", "path_width": 390.0, "branching": 0.55},
	{"palette": "forest_2", "ground_color": "79ad68", "density": 0.76, "landmark": "brook", "grammar": "brook_crossings", "path_width": 360.0, "branching": 0.68},
	{"palette": "forest_3", "ground_color": "70a162", "density": 0.82, "landmark": "old_road", "grammar": "road_and_detours", "path_width": 370.0, "branching": 0.62},
	{"palette": "forest_4", "ground_color": "68965d", "density": 0.90, "landmark": "stone_circle", "grammar": "radial_grove", "path_width": 340.0, "branching": 0.82},
	{"palette": "forest_5", "ground_color": "608a57", "density": 0.98, "landmark": "roots", "grammar": "braided_roots", "path_width": 320.0, "branching": 0.92},
	{"palette": "forest_6", "ground_color": "587f52", "density": 1.04, "landmark": "ancient_ruin", "grammar": "ruin_courtyards", "path_width": 315.0, "branching": 0.74},
	{"palette": "forest_7", "ground_color": "50744d", "density": 1.10, "landmark": "heart_tree", "grammar": "boss_approach", "path_width": 380.0, "branching": 0.58},
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
	for area_value in areas:
		var area: Dictionary = area_value
		if not area.has("zones") or Array(area["zones"]).is_empty(): errors.append("area %s has no semantic zones" % area.get("id", "?"))
		for zone_value in Array(area.get("zones", [])):
			semantic_roles[String(Dictionary(zone_value).get("role", "unknown"))] = true
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
	return {
		"valid": errors.is_empty(), "errors": errors, "area_count": areas.size(),
		"connection_count": connections.size(), "floor_shape_count": shapes.size(),
		"semantic_role_count": semantic_roles.size(), "route_length": route_length,
	}

static func _generate_expedition(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layer := "expedition_surface"
	var centers: Array[Vector2] = []
	for index in range(7):
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
	var boss_position := Vector2.ZERO

	for index in range(7):
		var center := centers[index]
		var incoming := (center - centers[maxi(0, index - 1)]).normalized() if index > 0 else (centers[1] - center).normalized()
		var outgoing := (centers[mini(6, index + 1)] - center).normalized() if index < 6 else incoming
		var entry := centers[index - 1].lerp(center, 0.5) if index > 0 else center - incoming * 880.0
		var exit := center.lerp(centers[index + 1], 0.5) if index < 6 else center + outgoing * 880.0
		part_entries.append(entry)
		part_exits.append(exit)
		var profile: Dictionary = Dictionary(FOREST_PART_PROFILES[index]).duplicate(true)
		var grammar := _build_forest_grammar(index, center, entry, exit, rng)
		var main_path: Array = grammar["main_path"]
		part_main_paths.append(main_path)
		var path_width := float(profile["path_width"])
		_add_polyline(floor_shapes, main_path, path_width, layer, index, "main_path")
		for route_value in Array(grammar["side_routes"]):
			var route: Array = route_value
			_add_polyline(floor_shapes, route, SIDE_PATH_RADIUS + index * 4.0, layer, index, "side_path")
		for zone_value in Array(grammar["zones"]):
			var zone: Dictionary = zone_value
			_add_circle(floor_shapes, Vector2(zone["pos"]), float(zone["radius"]), layer, index, String(zone["role"]))
		_add_profile_landmarks(terrain_features, profile, grammar, layer, index, rng)
		var safe_segments := _routes_as_segments([main_path] + Array(grammar["side_routes"]))
		var safe_points: Array = [entry, exit]
		for zone_value in Array(grammar["zones"]): safe_points.append(Vector2(Dictionary(zone_value)["pos"]))
		_add_forest_features(terrain_features, layer_walls[layer], safe_points, layer, rng, index, float(profile["density"]), safe_segments)

		var bounds := _bounds_for_part(floor_shapes, index)
		var area := {
			"id": index, "progression_part": index + 1,
			"kind": "boss" if index == 6 else "start" if index == 0 else "locale",
			"name": FOREST_PART_NAMES[index], "center": center, "rect": bounds,
			"entry": entry, "exit": exit, "discovered": index == 0,
			"layer": layer, "area_theme": "friendly_forest", "locale_id": "friendly_forest",
			"profile": profile, "zones": Array(grammar["zones"]).duplicate(true),
			"landmarks": Array(grammar["landmarks"]).duplicate(true),
		}
		var sockets: Array = grammar["encounter_sockets"]
		var part_encounters := _expedition_encounters(index + 1, sockets, rng, layer, index)
		if index == 6:
			boss_position = Vector2(grammar["boss_pos"])
			part_encounters.append({"kind": "warden", "pos": boss_position, "area_id": index, "layer": layer, "role": "boss", "zone_role": "boss_arena"})
			area["boss_pos"] = boss_position
		encounters[index] = part_encounters
		areas.append(area)

	for index in range(6):
		var seam := Vector2(part_exits[index])
		var path := [Vector2(part_main_paths[index][-2]), seam, Vector2(part_main_paths[index + 1][1])]
		connections.append({
			"id": index, "from": index, "to": index + 1, "shortcut": false,
			"shortcut_id": "", "unlocked": true, "layer": layer, "path": path,
			"path_radius": MAIN_PATH_RADIUS, "connection_type": "forest_transition",
			"corridor": _path_bounds(path, MAIN_PATH_RADIUS),
		})
	_prune_blockers_near_mandatory_paths(terrain_features, layer_walls[layer], connections, layer)

	var route_recipe: Array[Dictionary] = []
	for index in range(7): route_recipe.append({"slot": index + 1, "locale_id": "friendly_forest", "profile": index + 1})
	var result := {
		"world_size": EXPEDITION_WORLD_SIZE, "geometry_style": "organic",
		"areas": areas, "connections": connections, "floor_shapes": floor_shapes,
		"terrain_features": terrain_features, "layer_walls": layer_walls,
		"walls": Array(layer_walls[layer]), "base_walls": Array(layer_walls[layer]),
		"encounters": encounters, "waystones": [], "shortcuts": [], "transitions": [],
		"route_recipe": route_recipe,
		"locale_catalog": {"friendly_forest": {"name": "Friendly Forest", "profiles": FOREST_PART_PROFILES.duplicate(true)}},
		"layers": {layer: {"name": "Friendly Forest Expedition", "ground_color": "79af65"}},
		"bonfire_pos": part_entries[0], "player_start": part_entries[0],
		"exit_pos": boss_position, "shortcut_gate": Rect2(),
		"shortcut_unlock_pos": Vector2.ZERO, "shortcut_start_pos": Vector2.ZERO,
	}
	result["validation"] = validate_layout(result)
	return result

static func _build_forest_grammar(index: int, center: Vector2, entry: Vector2, exit: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var forward := entry.direction_to(exit)
	var side := forward.rotated(PI * 0.5)
	var sign := -1.0 if (index + rng.randi()) % 2 == 0 else 1.0
	var main: Array = [entry]
	var side_routes: Array = []
	var zones: Array[Dictionary] = []
	var sockets: Array[Dictionary] = []
	var landmarks: Array[Dictionary] = []
	var boss_pos := center + forward * 260.0
	match index:
		0: # Broad, forgiving meadow glades.
			var a := entry.lerp(center, 0.55) + side * sign * 130.0
			var b := center + forward * 360.0 - side * sign * 110.0
			main += [a, center, b, exit]
			var meadow_a := center + side * sign * 620.0 - forward * 160.0
			var meadow_b := center + side * sign * 690.0 + forward * 440.0
			side_routes = [[a, meadow_a, meadow_b, b]]
			zones = [_zone(center, 560.0, "landmark"), _zone(meadow_a, 470.0, "optional_glade"), _zone(meadow_b, 410.0, "rejoining_glade")]
			landmarks = [{"kind": "meadow", "pos": center}]
		1: # A brook crosses the route; one branch follows its bank.
			var crossing := center - forward * 80.0
			var bank_a := crossing + side * sign * 700.0
			var bank_b := crossing - side * sign * 620.0 + forward * 330.0
			main += [entry.lerp(crossing, 0.48), crossing, crossing.lerp(exit, 0.50), exit]
			side_routes = [[main[1], bank_a, center + forward * 500.0 + side * sign * 520.0, main[3]], [crossing, bank_b, main[3]]]
			zones = [_zone(crossing, 440.0, "brook_crossing"), _zone(bank_a, 380.0, "bank_glade"), _zone(bank_b, 350.0, "optional_bank")]
			landmarks = [{"kind": "brook", "pos": crossing, "from": crossing - side * 920.0, "to": crossing + side * 920.0}]
		2: # A readable old road with an overgrown detour.
			var road_a := entry.lerp(exit, 0.33)
			var road_b := entry.lerp(exit, 0.68)
			main += [road_a, center, road_b, exit]
			var detour_a := road_a + side * sign * 610.0
			var detour_b := road_b + side * sign * 690.0
			side_routes = [[road_a, detour_a, detour_b, road_b]]
			zones = [_zone(center, 470.0, "road_landmark"), _zone(detour_a, 370.0, "overgrown_detour"), _zone(detour_b, 400.0, "roadside_glade")]
			landmarks = [{"kind": "old_road", "pos": center, "from": entry, "to": exit}]
		3: # A radial grove with several readable spokes.
			var hub := center + side * sign * 90.0
			main += [entry.lerp(hub, 0.52), hub, hub.lerp(exit, 0.52), exit]
			var north := hub + side * 690.0
			var south := hub - side * 650.0
			var outer := hub + forward * 420.0 + side * sign * 570.0
			side_routes = [[hub, north, outer, main[3]], [hub, south, main[1]]]
			zones = [_zone(hub, 540.0, "radial_hub"), _zone(north, 370.0, "elder_glade"), _zone(south, 350.0, "quiet_spoke"), _zone(outer, 390.0, "outer_spoke")]
			landmarks = [{"kind": "stone_circle", "pos": hub}]
		4: # Braided routes shaped by great roots.
			var split := entry.lerp(center, 0.56)
			var join := center.lerp(exit, 0.58)
			var upper := center + side * 470.0
			var lower := center - side * 470.0
			main += [split, upper if sign > 0 else lower, join, exit]
			side_routes = [[split, lower if sign > 0 else upper, join], [main[2], center + forward * 300.0 - side * sign * 690.0, join]]
			zones = [_zone(split, 370.0, "root_junction"), _zone(upper, 390.0, "upper_braid"), _zone(lower, 390.0, "lower_braid"), _zone(join, 430.0, "rejoining_roots")]
			landmarks = [{"kind": "roots", "pos": center}]
		5: # Ruined courts interrupt the forest rather than replacing it.
			var court_a := center - forward * 390.0 + side * sign * 170.0
			var court_b := center + forward * 390.0 - side * sign * 180.0
			main += [entry.lerp(court_a, 0.55), court_a, center, court_b, court_b.lerp(exit, 0.52), exit]
			var cloister := center + side * sign * 700.0
			side_routes = [[court_a, cloister, court_b]]
			zones = [_zone(court_a, 450.0, "ruin_court"), _zone(center, 500.0, "broken_hall"), _zone(court_b, 450.0, "ruin_exit"), _zone(cloister, 390.0, "side_cloister")]
			landmarks = [{"kind": "ancient_ruin", "pos": center}]
		_: # A broad ceremonial approach and boss perimeter.
			var approach := center - forward * 420.0
			var arena := center + forward * 260.0
			boss_pos = arena
			main += [entry.lerp(approach, 0.55), approach, center, arena, exit]
			var left := arena + side * 650.0
			var right := arena - side * 650.0
			side_routes = [[approach, left, arena], [approach, right, arena]]
			zones = [_zone(approach, 480.0, "boss_approach"), _zone(center, 520.0, "heart_tree"), _zone(arena, 720.0, "boss_arena"), _zone(left, 380.0, "arena_perimeter"), _zone(right, 380.0, "arena_perimeter")]
			landmarks = [{"kind": "heart_tree", "pos": center}]
	for zone in zones:
		var role := String(zone["role"])
		if role not in ["quiet_spoke", "landmark", "heart_tree"]: sockets.append({"pos": Vector2(zone["pos"]), "role": role, "radius": float(zone["radius"])})
	return {"main_path": main, "side_routes": side_routes, "zones": zones, "encounter_sockets": sockets, "landmarks": landmarks, "boss_pos": boss_pos}

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
		"layers": {surface: {"name": "Friendly Forest", "ground_color": "82b86d"}, depths: {"name": "Ruin Depths", "ground_color": "596653"}},
		"bonfire_pos": Vector2(1200, 4800), "player_start": Vector2(1200, 5000),
		"exit_pos": Vector2(1200, 1800), "shortcut_gate": return_gate,
		"shortcut_unlock_pos": Vector2(shortcuts[1]["unlock_pos"]), "shortcut_start_pos": Vector2(shortcuts[1]["near_pos"]),
	}
	result["validation"] = validate_layout(result)
	return result

static func _expedition_encounters(part: int, sockets: Array, rng: RandomNumberGenerator, layer: String, area_id: int) -> Array[Dictionary]:
	var pools := [
		["knife", "blade", "hound"], ["knife", "blade", "hound", "archer"],
		["blade", "hound", "archer", "polearm"], ["blade", "archer", "polearm", "hexer"],
		["hound", "polearm", "hexer", "brute"], ["polearm", "hexer", "brute", "captain"],
		["hexer", "brute", "captain", "polearm"],
	]
	var pool: Array = pools[part - 1]
	var result: Array[Dictionary] = []
	var target_count := 7 + part
	var offsets := [Vector2(-145, -100), Vector2(145, -90), Vector2(-125, 125), Vector2(135, 130)]
	for index in range(target_count):
		var socket_index := index % maxi(1, sockets.size())
		var socket: Dictionary = sockets[socket_index] if not sockets.is_empty() else {"pos": Vector2.ZERO, "role": "path"}
		var cycle := int(index / maxi(1, sockets.size()))
		var offset: Vector2 = Vector2(offsets[(index + cycle) % offsets.size()]).rotated(rng.randf_range(-0.28, 0.28)) * (1.0 + cycle * 0.30)
		result.append({
			"kind": String(pool[rng.randi_range(0, pool.size() - 1)]), "pos": Vector2(socket["pos"]) + offset,
			"area_id": area_id, "layer": layer, "cluster": socket_index, "zone_role": String(socket.get("role", "path")),
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
