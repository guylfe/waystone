class_name FloorGenerator
extends RefCounted

const EXPEDITION_WORLD_SIZE := Vector2(15600.0, 7000.0)
const CAMPAIGN_WORLD_SIZE := Vector2(6400.0, 5200.0)
const ROUTE_RADIUS := 360.0
const CLEARING_RADIUS := 470.0
const SHORTCUT_INTERACTION_OFFSET := 104.0

const FOREST_PART_NAMES := [
	"Sunlit Verge", "Brookwood", "Old Forest Road", "Elder Grove",
	"Rootlands", "Ancient Interior", "Forest Heart",
]

const FOREST_PART_PROFILES := [
	{"palette": "forest_1", "ground_color": "82b86d", "density": 0.72, "landmark": "meadow"},
	{"palette": "forest_2", "ground_color": "79ad68", "density": 0.78, "landmark": "brook"},
	{"palette": "forest_3", "ground_color": "70a162", "density": 0.84, "landmark": "old_road"},
	{"palette": "forest_4", "ground_color": "68965d", "density": 0.90, "landmark": "stone_circle"},
	{"palette": "forest_5", "ground_color": "608a57", "density": 0.98, "landmark": "roots"},
	{"palette": "forest_6", "ground_color": "587f52", "density": 1.06, "landmark": "ancient_ruin"},
	{"palette": "forest_7", "ground_color": "50744d", "density": 1.12, "landmark": "heart_tree"},
]

static func generate(seed_value: int, include_shortcut: bool = true) -> Dictionary:
	return _generate_campaign_loop(seed_value) if include_shortcut else _generate_expedition(seed_value)

static func _generate_expedition(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layer := "expedition_surface"
	var centers: Array[Vector2] = []
	var base_y := 3500.0
	for index in range(7):
		var wave := sin(float(index) * 1.27 + rng.randf_range(-0.22, 0.22)) * 720.0
		centers.append(Vector2(1300.0 + index * 2150.0, base_y + wave + rng.randf_range(-190.0, 190.0)))
	if rng.randi() % 2 == 0:
		for index in range(centers.size()): centers[index].y = EXPEDITION_WORLD_SIZE.y - centers[index].y

	var areas: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	var floor_shapes: Array[Dictionary] = []
	var terrain_features: Array[Dictionary] = []
	var layer_walls := {layer: []}
	var encounters: Dictionary = {}
	var boss_position := Vector2.ZERO
	var part_entries: Array[Vector2] = []
	var part_exits: Array[Vector2] = []
	var part_bends: Array[Vector2] = []

	for index in range(7):
		var center := centers[index]
		var incoming := (centers[index] - centers[maxi(0, index - 1)]).normalized() if index > 0 else (centers[1] - center).normalized()
		var outgoing := (centers[mini(6, index + 1)] - center).normalized() if index < 6 else incoming
		var entry := center - incoming * 780.0 if index == 0 else centers[index - 1].lerp(center, 0.5)
		var exit := center + outgoing * 780.0 if index == 6 else center.lerp(centers[index + 1], 0.5)
		part_entries.append(entry)
		part_exits.append(exit)
		var side := (entry.direction_to(exit)).rotated(PI * 0.5)
		var side_sign := -1.0 if (index + int(seed_value)) % 2 == 0 else 1.0
		var bend := center + side * side_sign * rng.randf_range(170.0, 360.0)
		part_bends.append(bend)
		_add_capsule(floor_shapes, entry, bend, ROUTE_RADIUS + index * 8.0, layer, index)
		_add_capsule(floor_shapes, bend, exit, ROUTE_RADIUS + index * 8.0, layer, index)
		_add_circle(floor_shapes, center, CLEARING_RADIUS + rng.randf_range(-45.0, 95.0), layer, index)
		_add_circle(floor_shapes, bend, 390.0 + rng.randf_range(-25.0, 90.0), layer, index)

		# Each progression part contains a genuine side route and several encounter
		# spaces. These are internal locales, not separate progression parts.
		var side_center := center - side * side_sign * rng.randf_range(610.0, 790.0)
		var far_side := bend + side * side_sign * rng.randf_range(590.0, 760.0)
		_add_circle(floor_shapes, side_center, 350.0 + rng.randf_range(0.0, 120.0), layer, index)
		_add_circle(floor_shapes, far_side, 330.0 + rng.randf_range(0.0, 115.0), layer, index)
		_add_capsule(floor_shapes, center, side_center, 255.0, layer, index)
		_add_capsule(floor_shapes, side_center, far_side, 245.0, layer, index)
		_add_capsule(floor_shapes, far_side, bend, 255.0, layer, index)

		var bounds := _bounds_for_part(floor_shapes, index)
		var profile: Dictionary = Dictionary(FOREST_PART_PROFILES[index]).duplicate(true)
		var area := {
			"id": index, "progression_part": index + 1,
			"kind": "boss" if index == 6 else "start" if index == 0 else "locale",
			"name": FOREST_PART_NAMES[index], "center": center, "rect": bounds,
			"entry": entry, "exit": exit, "discovered": index == 0,
			"layer": layer, "area_theme": "friendly_forest", "locale_id": "friendly_forest", "profile": profile,
		}
		var anchors := [bend, side_center, far_side]
		var part_encounters := _expedition_encounters(index + 1, anchors, rng, layer, index)
		if index == 6:
			boss_position = center + outgoing * 260.0
			part_encounters.append({"kind": "warden", "pos": boss_position, "area_id": index, "layer": layer, "role": "boss"})
			area["boss_pos"] = boss_position
		encounters[index] = part_encounters
		areas.append(area)
		var safe_segments := [[entry, bend], [bend, exit], [center, side_center], [side_center, far_side], [far_side, bend]]
		_add_forest_features(terrain_features, layer_walls[layer], [center, bend, side_center, far_side], [entry, exit] + anchors, layer, rng, index, float(profile["density"]), safe_segments)

	for index in range(6):
		var path := [part_bends[index], part_exits[index], part_bends[index + 1]]
		connections.append({
			"id": index, "from": index, "to": index + 1, "shortcut": false,
			"shortcut_id": "", "unlocked": true, "layer": layer, "path": path,
			"corridor": _path_bounds(path, ROUTE_RADIUS),
		})

	var start := part_entries[0]
	var route_recipe: Array[Dictionary] = []
	for index in range(7): route_recipe.append({"slot": index + 1, "locale_id": "friendly_forest", "profile": index + 1})
	return {
		"world_size": EXPEDITION_WORLD_SIZE, "geometry_style": "organic",
		"areas": areas, "connections": connections, "floor_shapes": floor_shapes,
		"terrain_features": terrain_features, "layer_walls": layer_walls,
		"walls": Array(layer_walls[layer]), "base_walls": Array(layer_walls[layer]),
		"encounters": encounters, "waystones": [], "shortcuts": [], "transitions": [],
		"route_recipe": route_recipe,
		"locale_catalog": {"friendly_forest": {"name": "Friendly Forest", "profiles": FOREST_PART_PROFILES.duplicate(true)}},
		"layers": {layer: {"name": "Friendly Forest Expedition", "ground_color": "79aF65"}},
		"bonfire_pos": start, "player_start": start,
		"exit_pos": boss_position, "shortcut_gate": Rect2(),
		"shortcut_unlock_pos": Vector2.ZERO, "shortcut_start_pos": Vector2.ZERO,
	}

static func _generate_campaign_loop(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var surface := "forest_surface"
	var depths := "ruin_depths"
	var definitions := [
		{"id": 0, "name": "Dawn Grove", "kind": "waystone", "center": Vector2(1200, 3800), "layer": surface},
		{"id": 1, "name": "Brook Path", "kind": "locale", "center": Vector2(2300, 3450), "layer": surface},
		{"id": 2, "name": "Moss Waystone", "kind": "waystone", "center": Vector2(3450, 3100), "layer": surface},
		{"id": 3, "name": "Sunken Ruin", "kind": "ruin", "center": Vector2(4700, 2500), "layer": surface},
		# The below-ground entrance and the ruin above intentionally share total coordinates.
		{"id": 4, "name": "Buried Hall", "kind": "depths", "center": Vector2(4700, 2500), "layer": depths},
		{"id": 5, "name": "Root Vault", "kind": "boss", "center": Vector2(3350, 2050), "layer": depths},
		{"id": 6, "name": "Old Lift", "kind": "depths", "center": Vector2(1200, 2200), "layer": depths},
		# The lift emerges directly beneath this grove in the same world coordinates.
		{"id": 7, "name": "Forgotten Grove", "kind": "hidden_grove", "center": Vector2(1200, 2200), "layer": surface},
	]
	var areas: Array[Dictionary] = []
	var floor_shapes: Array[Dictionary] = []
	var terrain_features: Array[Dictionary] = []
	var layer_walls := {surface: [], depths: []}
	var campaign_safe_segments := [
		[Vector2(1200, 3800), Vector2(1700, 3300)], [Vector2(1700, 3300), Vector2(2300, 3450)],
		[Vector2(2300, 3450), Vector2(2850, 2850)], [Vector2(2850, 2850), Vector2(3450, 3100)],
		[Vector2(3450, 3100), Vector2(3600, 1800)], [Vector2(3600, 1800), Vector2(4700, 1800)],
		[Vector2(4700, 1800), Vector2(4700, 2500)],
		[Vector2(4700, 2500), Vector2(4100, 1850)], [Vector2(4100, 1850), Vector2(3350, 2050)],
		[Vector2(3350, 2050), Vector2(2450, 2500)], [Vector2(2450, 2500), Vector2(1200, 2200)],
		[Vector2(4700, 2500), Vector2(4700, 3100)], [Vector2(4700, 3100), Vector2(3450, 3100)],
		[Vector2(1200, 2200), Vector2(300, 2200)], [Vector2(300, 2200), Vector2(300, 3800)],
		[Vector2(300, 3800), Vector2(1200, 3800)],
	]
	for value in definitions:
		var definition := Dictionary(value)
		var center := Vector2(definition["center"])
		var layer := String(definition["layer"])
		var radius := 590.0 if int(definition["id"]) in [0, 2, 5] else 510.0
		_add_circle(floor_shapes, center, radius, layer, int(definition["id"]))
		_add_circle(floor_shapes, center + Vector2(170, -130), radius * 0.72, layer, int(definition["id"]))
		var area := definition.duplicate(true)
		area["rect"] = Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		area["discovered"] = int(definition["id"]) == 0
		area["area_theme"] = "friendly_forest" if layer == surface else "forest_ruin"
		areas.append(area)
		_add_forest_features(terrain_features, layer_walls[layer], [center], [center], layer, rng, int(definition["id"]), 0.78 if layer == surface else 0.32, campaign_safe_segments)

	var connections: Array[Dictionary] = []
	_add_campaign_path(connections, floor_shapes, 0, 1, [Vector2(1200, 3800), Vector2(1700, 3300), Vector2(2300, 3450)], surface)
	_add_campaign_path(connections, floor_shapes, 1, 2, [Vector2(2300, 3450), Vector2(2850, 2850), Vector2(3450, 3100)], surface)
	# The outward route deliberately winds north. The later root gate cuts across
	# its long bend, making the unlocked return materially shorter.
	_add_campaign_path(connections, floor_shapes, 2, 3, [Vector2(3450, 3100), Vector2(3600, 1800), Vector2(4700, 1800), Vector2(4700, 2500)], surface)
	_add_campaign_path(connections, floor_shapes, 4, 5, [Vector2(4700, 2500), Vector2(4100, 1850), Vector2(3350, 2050)], depths)
	_add_campaign_path(connections, floor_shapes, 5, 6, [Vector2(3350, 2050), Vector2(2450, 2500), Vector2(1200, 2200)], depths)

	# A local surface return from beyond the Moss Waystone, and a much larger
	# layered return to Dawn Grove, are both opened only from their far sides.
	var local_path := [Vector2(4700, 2500), Vector2(4700, 3100), Vector2(3450, 3100)]
	var local_gate := Rect2(Vector2(4070, 2910), Vector2(100, 380))
	_add_shortcut_connection(connections, floor_shapes, 3, 2, local_path, surface, "moss_root_gate_v2", 120.0)
	var return_path := [Vector2(1200, 2200), Vector2(300, 2200), Vector2(300, 3800), Vector2(1200, 3800)]
	var return_gate := Rect2(Vector2(570, 3610), Vector2(100, 380))
	_add_shortcut_connection(connections, floor_shapes, 7, 0, return_path, surface, "dawn_ruin_return_v2", 120.0)

	var shortcuts := [
		{"id": "moss_root_gate_v2", "name": "Hidden Moss Path", "connection_id": connections.size() - 2, "gate": local_gate, "unlock_pos": Vector2(4280, 3100), "far_pos": Vector2(4280, 3100), "near_pos": Vector2(3920, 3100), "layer": surface, "unlocked": false, "presentation": "hidden_woodland_path", "interaction_radius": 170.0},
		{"id": "dawn_ruin_return_v2", "name": "Hidden Dawn Path", "connection_id": connections.size() - 1, "gate": return_gate, "unlock_pos": Vector2(420, 3800), "far_pos": Vector2(420, 3800), "near_pos": Vector2(780, 3800), "layer": surface, "unlocked": false, "presentation": "hidden_woodland_path", "interaction_radius": 170.0},
	]
	var transitions := [
		{"id": "ruin_stairs", "kind": "stairs_down", "from_layer": surface, "from_pos": Vector2(4700, 2500), "to_layer": depths, "to_pos": Vector2(4700, 2500), "unlocked": true},
		{"id": "old_lift", "kind": "ladder", "from_layer": depths, "from_pos": Vector2(1200, 2200), "to_layer": surface, "to_pos": Vector2(1200, 2200), "unlocked": true},
	]
	var encounters: Dictionary = {}
	for area in areas:
		var id := int(area["id"])
		if id in [0, 2, 7]: continue
		var center := Vector2(area["center"])
		var layer := String(area["layer"])
		encounters[id] = _campaign_encounter(id, center, layer, rng)
	if encounters.has(5):
		var campaign_boss_pos := Vector2(areas[5]["center"]) + Vector2(120, -40)
		areas[5]["boss_pos"] = campaign_boss_pos
		var boss_encounter: Array = encounters[5]
		boss_encounter.append({"kind": "warden", "pos": campaign_boss_pos, "area_id": 5, "layer": depths, "role": "boss"})
		encounters[5] = boss_encounter

	var waystones := [
		{"id": "dawn", "name": "Dawn Waystone", "pos": Vector2(1200, 3800), "layer": surface},
		{"id": "moss", "name": "Moss Waystone", "pos": Vector2(3450, 3100), "layer": surface},
	]
	return {
		"world_size": CAMPAIGN_WORLD_SIZE, "geometry_style": "organic",
		"areas": areas, "connections": connections, "floor_shapes": floor_shapes,
		"terrain_features": terrain_features, "layer_walls": layer_walls,
		"walls": Array(layer_walls[surface]), "base_walls": Array(layer_walls[surface]),
		"encounters": encounters, "waystones": waystones, "shortcuts": shortcuts,
		"transitions": transitions,
		"layers": {
			surface: {"name": "Friendly Forest", "ground_color": "82b86d"},
			depths: {"name": "Ruin Depths", "ground_color": "596653"},
		},
		"bonfire_pos": Vector2(1200, 3800), "player_start": Vector2(1200, 3980),
		"exit_pos": Vector2(1200, 2200), "shortcut_gate": return_gate,
		"shortcut_unlock_pos": Vector2(shortcuts[1]["unlock_pos"]),
		"shortcut_start_pos": Vector2(shortcuts[1]["near_pos"]),
	}

static func _expedition_encounters(part: int, anchors: Array, rng: RandomNumberGenerator, layer: String, area_id: int) -> Array[Dictionary]:
	var pools := [
		["knife", "blade", "hound"],
		["knife", "blade", "hound", "archer"],
		["blade", "hound", "archer", "polearm"],
		["blade", "archer", "polearm", "hexer"],
		["hound", "polearm", "hexer", "brute"],
		["polearm", "hexer", "brute", "captain"],
		["hexer", "brute", "captain", "polearm"],
	]
	var pool: Array = pools[part - 1]
	var result: Array[Dictionary] = []
	var offsets := [Vector2(-145, -105), Vector2(145, -95), Vector2(-125, 125), Vector2(135, 130), Vector2(0, -185)]
	for cluster in range(anchors.size()):
		var count := mini(5, 2 + int(floor(float(part + cluster) / 3.0)))
		for index in range(count):
			var kind := String(pool[rng.randi_range(0, pool.size() - 1)])
			result.append({"kind": kind, "pos": Vector2(anchors[cluster]) + offsets[index].rotated(rng.randf_range(-0.24, 0.24)), "area_id": area_id, "layer": layer, "cluster": cluster})
	return result

static func _campaign_encounter(area_id: int, center: Vector2, layer: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var rosters := {
		1: ["blade", "knife", "hound", "archer", "blade"],
		3: ["polearm", "archer", "hexer", "blade", "hound", "captain"],
		4: ["hound", "hexer", "polearm", "knife", "blade", "hexer"],
		5: ["brute", "hexer", "polearm", "captain", "blade", "hound"],
		6: ["brute", "polearm", "hound", "archer", "knife"],
	}
	var roster: Array = rosters.get(area_id, ["blade", "hound", "knife"])
	var offsets := [Vector2(-210, -120), Vector2(210, -110), Vector2(-190, 160), Vector2(190, 160), Vector2(0, -240), Vector2(0, 230)]
	var result: Array[Dictionary] = []
	for index in range(roster.size()):
		result.append({"kind": String(roster[index]), "pos": center + offsets[index].rotated(rng.randf_range(-0.18, 0.18)), "area_id": area_id, "layer": layer, "cluster": int(index / 3)})
	return result

static func _add_campaign_path(connections: Array[Dictionary], shapes: Array[Dictionary], from_id: int, to_id: int, path: Array, layer: String) -> void:
	for index in range(path.size() - 1): _add_capsule(shapes, Vector2(path[index]), Vector2(path[index + 1]), 300.0, layer, from_id)
	connections.append({"id": connections.size(), "from": from_id, "to": to_id, "shortcut": false, "shortcut_id": "", "unlocked": true, "layer": layer, "path": path, "corridor": _path_bounds(path, 300.0)})

static func _add_shortcut_connection(connections: Array[Dictionary], shapes: Array[Dictionary], from_id: int, to_id: int, path: Array, layer: String, shortcut_id: String, radius: float = 270.0) -> void:
	for index in range(path.size() - 1): _add_capsule(shapes, Vector2(path[index]), Vector2(path[index + 1]), radius, layer, from_id)
	connections.append({"id": connections.size(), "from": from_id, "to": to_id, "shortcut": true, "shortcut_id": shortcut_id, "unlocked": false, "layer": layer, "path": path, "corridor": _path_bounds(path, radius)})

static func _add_circle(shapes: Array[Dictionary], center: Vector2, radius: float, layer: String, part_id: int) -> void:
	shapes.append({"kind": "circle", "center": center, "radius": radius, "layer": layer, "part_id": part_id})

static func _add_capsule(shapes: Array[Dictionary], start: Vector2, finish: Vector2, radius: float, layer: String, part_id: int) -> void:
	shapes.append({"kind": "capsule", "from": start, "to": finish, "radius": radius, "layer": layer, "part_id": part_id})

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

static func _add_forest_features(features: Array[Dictionary], walls: Array, clearings: Array, safe_points: Array, layer: String, rng: RandomNumberGenerator, part_id: int, density: float, safe_segments: Array = []) -> void:
	for clearing_value in clearings:
		var clearing := Vector2(clearing_value)
		var count := maxi(5, int(round(8.0 * density)))
		var phase := rng.randf_range(0.0, TAU)
		for index in range(count):
			var direction := Vector2.RIGHT.rotated(phase + TAU * float(index) / float(count) + rng.randf_range(-0.12, 0.12))
			var position := clearing + direction * rng.randf_range(300.0, 440.0)
			var safe := false
			for safe_value in safe_points:
				if position.distance_to(Vector2(safe_value)) < 225.0: safe = true
			for segment_value in safe_segments:
				var segment: Array = segment_value
				if _distance_to_segment(position, Vector2(segment[0]), Vector2(segment[1])) < 180.0: safe = true
			if safe: continue
			var radius := rng.randf_range(34.0, 52.0)
			features.append({"kind": "tree", "pos": position, "radius": radius, "layer": layer, "part_id": part_id})
			walls.append(Rect2(position - Vector2.ONE * radius * 0.42, Vector2.ONE * radius * 0.84))

static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.001: return point.distance_to(start)
	var amount := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * amount)
