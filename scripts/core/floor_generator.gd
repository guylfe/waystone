class_name FloorGenerator
extends RefCounted

const WORLD_SIZE := Vector2(5000.0, 4400.0)
const CAMPAIGN_WORLD_SIZE := Vector2(7600.0, 6000.0)
const ROOM_SIZE := Vector2(760.0, 640.0)
const WALL_THICKNESS := 56.0
## Required routes deliberately use much more clearance than an actor needs.
## Room dressing must never turn navigation into a pixel-perfect squeeze.
const DOOR_WIDTH := 320.0
const CORRIDOR_WIDTH := 320.0
## Close enough to read as a door interaction, while remaining beyond the gate
## collision on the far side. The 115-unit interaction radius cannot reach this
## point from the near side of a closed gate.
const SHORTCUT_INTERACTION_OFFSET := 92.0

static func generate(seed_value: int, include_shortcut: bool = true) -> Dictionary:
	if include_shortcut:
		return _generate_friendly_forest(seed_value)
	return _generate_expedition(seed_value)

static func _generate_friendly_forest(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Broad clearings form a continuous forest route. The final two clearings are
	# a physically separate ruin-depths layer reached only through transitions.
	var centers := [
		Vector2(800, 4400), Vector2(800, 3400), Vector2(1800, 3400), Vector2(1800, 4400),
		Vector2(2800, 4400), Vector2(2800, 3400), Vector2(3800, 3400), Vector2(3800, 4400),
		Vector2(4800, 4400), Vector2(4800, 3400), Vector2(5800, 3400), Vector2(5800, 2400),
		Vector2(6800, 3400), Vector2(6800, 4400), Vector2(800, 5400),
	]
	var kinds := ["start", "grove", "combat", "combat", "waystone", "combat", "combat", "shortcut_far", "waystone", "combat", "ruin", "boss", "ruin_depths", "ruin_depths", "hidden_grove"]
	var names := ["Dawn Grove", "Brook Path", "Fern Clearing", "Old Orchard", "Moss Waystone", "Deer Trail", "Elder Copse", "Root Gate", "Twilight Waystone", "Standing Stones", "Sunken Ruin", "Forest Heart", "Buried Hall", "Root Vault", "Forgotten Grove"]
	var areas: Array[Dictionary] = []
	for index in range(centers.size()):
		var layer := "ruin_depths" if index in [12, 13] else "forest_surface"
		var size := Vector2(900 + rng.randi_range(-45, 90), 760 + rng.randi_range(-35, 70))
		areas.append({
			"id": index, "kind": kinds[index], "name": names[index], "center": centers[index],
			"rect": Rect2(centers[index] - size * 0.5, size), "discovered": index == 0,
			"layer": layer, "area_theme": "friendly_forest" if layer == "forest_surface" else "forest_ruin",
		})

	var edge_pairs := [[0,1],[1,2],[2,3],[3,4],[4,5],[5,6],[6,7],[7,8],[8,9],[9,10],[10,11],[12,13],[14,0],[7,4]]
	var connections: Array[Dictionary] = []
	for edge_index in range(edge_pairs.size()):
		var pair: Array = edge_pairs[edge_index]
		var from_id := int(pair[0])
		var to_id := int(pair[1])
		var shortcut_id := ""
		if pair == [7,4]: shortcut_id = "moss_root_gate"
		elif pair == [14,0]: shortcut_id = "ruin_return"
		connections.append({
			"id": edge_index, "from": from_id, "to": to_id, "shortcut": not shortcut_id.is_empty(),
			"shortcut_id": shortcut_id, "unlocked": shortcut_id.is_empty(),
			"layer": String(areas[from_id]["layer"]),
			"corridor": _corridor_between(Rect2(areas[from_id]["rect"]), Rect2(areas[to_id]["rect"])),
		})

	var openings: Dictionary = {}
	for area in areas: openings[int(area["id"])] = {"top": [], "bottom": [], "left": [], "right": []}
	for connection in connections:
		var a := int(connection["from"])
		var b := int(connection["to"])
		_register_opening(openings[a], Rect2(areas[a]["rect"]), Vector2(areas[b]["center"]))
		_register_opening(openings[b], Rect2(areas[b]["rect"]), Vector2(areas[a]["center"]))

	var base_walls: Array[Rect2] = []
	for area in areas:
		base_walls.append_array(_room_boundary(Rect2(area["rect"]), Dictionary(openings[int(area["id"])])))
	for connection in connections:
		base_walls.append_array(_corridor_walls(Rect2(connection["corridor"]), Vector2(areas[int(connection["from"])]["center"]), Vector2(areas[int(connection["to"])]["center"])))
	for area in areas:
		if int(area["id"]) in [0, 4, 8, 10, 12, 13, 14] or String(area["kind"]) == "boss": continue
		base_walls.append_array(_room_obstacles(Rect2(area["rect"]), int(area["id"]), rng))

	var shortcuts: Array[Dictionary] = []
	for connection in connections:
		if not bool(connection["shortcut"]): continue
		var corridor := Rect2(connection["corridor"])
		var from_center := Vector2(areas[int(connection["from"])]["center"])
		var to_center := Vector2(areas[int(connection["to"])]["center"])
		var gate := _gate_across(corridor, from_center, to_center)
		var far_id := int(connection["from"])
		var far_direction := (Vector2(areas[far_id]["center"]) - gate.get_center()).normalized()
		var near_direction := (Vector2(areas[int(connection["to"])]["center"]) - gate.get_center()).normalized()
		shortcuts.append({
			"id": String(connection["shortcut_id"]), "connection_id": int(connection["id"]), "gate": gate,
			"unlock_pos": gate.get_center() + far_direction * SHORTCUT_INTERACTION_OFFSET,
			"near_pos": gate.get_center() + near_direction * SHORTCUT_INTERACTION_OFFSET,
			"layer": String(connection["layer"]), "unlocked": false,
		})
	var walls := base_walls.duplicate()
	for shortcut in shortcuts: walls.append(Rect2(shortcut["gate"]))

	var encounters: Dictionary = {}
	for area_id in range(1, areas.size()):
		if area_id in [4, 8, 10, 14]: continue
		encounters[area_id] = _encounter_for(mini(area_id, 7), Vector2(areas[area_id]["center"]), seed_value + area_id * 17)
		for enemy in encounters[area_id]: enemy["layer"] = String(areas[area_id]["layer"])

	var waystones := [
		{"id": "dawn", "name": "Dawn Waystone", "pos": centers[0], "layer": "forest_surface"},
		{"id": "moss", "name": "Moss Waystone", "pos": centers[4], "layer": "forest_surface"},
		{"id": "twilight", "name": "Twilight Waystone", "pos": centers[8], "layer": "forest_surface"},
	]
	var transitions := [
		{"id": "ruin_stairs", "kind": "stairs_down", "from_layer": "forest_surface", "from_pos": centers[10] + Vector2(0, 150), "to_layer": "ruin_depths", "to_pos": centers[12] + Vector2(0, 150), "unlocked": true},
		{"id": "root_ladder", "kind": "ladder", "from_layer": "ruin_depths", "from_pos": centers[13] + Vector2(0, 150), "to_layer": "forest_surface", "to_pos": centers[14] + Vector2(0, -150), "unlocked": true},
	]
	return {
		"world_size": CAMPAIGN_WORLD_SIZE, "areas": areas, "connections": connections, "walls": walls,
		"base_walls": base_walls, "encounters": encounters, "waystones": waystones, "transitions": transitions,
		"shortcuts": shortcuts, "bonfire_pos": centers[0], "player_start": centers[0] + Vector2.DOWN * 170.0,
		"exit_pos": centers[11], "shortcut_gate": Rect2(shortcuts[0]["gate"]),
		"shortcut_unlock_pos": Vector2(shortcuts[0]["unlock_pos"]), "shortcut_start_pos": Vector2(shortcuts[0]["near_pos"]),
		"layers": {"forest_surface": {"name": "Friendly Forest", "ground_color": "8fbd72"}, "ruin_depths": {"name": "Ruin Depths", "ground_color": "596653"}},
	}

static func _gate_across(corridor: Rect2, a: Vector2, b: Vector2) -> Rect2:
	var center := corridor.get_center()
	if absf(a.x - b.x) > absf(a.y - b.y):
		return Rect2(center - Vector2(WALL_THICKNESS * 0.5, CORRIDOR_WIDTH * 0.5), Vector2(WALL_THICKNESS, CORRIDOR_WIDTH))
	return Rect2(center - Vector2(CORRIDOR_WIDTH * 0.5, WALL_THICKNESS * 0.5), Vector2(CORRIDOR_WIDTH, WALL_THICKNESS))

static func _generate_expedition(seed_value: int) -> Dictionary:
	var include_shortcut := false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var centers := [
		Vector2(700, 3400),
		Vector2(700, 2400),
		Vector2(1700, 2400),
		Vector2(1700, 3400),
		Vector2(2700, 3400),
		Vector2(2700, 2400),
		Vector2(3800, 2400),
		Vector2(1700, 1400),
	]
	var mirror_x := rng.randi() % 2 == 0
	var mirror_y := rng.randi() % 2 == 0
	for index in range(centers.size()):
		var point: Vector2 = centers[index]
		if mirror_x: point.x = WORLD_SIZE.x - point.x
		if mirror_y: point.y = WORLD_SIZE.y - point.y
		centers[index] = point

	var kinds := ["start", "combat", "combat", "midpoint", "combat", "combat", "boss", "optional"]
	var areas: Array[Dictionary] = []
	for index in range(centers.size()):
		var size_jitter := Vector2(rng.randi_range(-50, 50), rng.randi_range(-35, 35))
		var room_size := ROOM_SIZE + size_jitter
		areas.append({
			"id": index,
			"kind": kinds[index],
			"center": centers[index],
			"rect": Rect2(centers[index] - room_size * 0.5, room_size),
			"discovered": index == 0,
		})

	var edge_pairs := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [2, 7]]
	if include_shortcut: edge_pairs.append([3, 0])
	var connections: Array[Dictionary] = []
	for edge_index in range(edge_pairs.size()):
		var pair: Array = edge_pairs[edge_index]
		var from_id := int(pair[0])
		var to_id := int(pair[1])
		var shortcut := include_shortcut and edge_index == edge_pairs.size() - 1
		connections.append({
			"id": edge_index,
			"from": from_id,
			"to": to_id,
			"shortcut": shortcut,
			"unlocked": not shortcut,
			"corridor": _corridor_between(Rect2(areas[from_id]["rect"]), Rect2(areas[to_id]["rect"])),
		})

	var openings: Dictionary = {}
	for area in areas: openings[int(area["id"])] = {"top": [], "bottom": [], "left": [], "right": []}
	for connection in connections:
		var a := int(connection["from"])
		var b := int(connection["to"])
		_register_opening(openings[a], Rect2(areas[a]["rect"]), Vector2(areas[b]["center"]))
		_register_opening(openings[b], Rect2(areas[b]["rect"]), Vector2(areas[a]["center"]))

	var walls: Array[Rect2] = []
	for area in areas:
		walls.append_array(_room_boundary(Rect2(area["rect"]), Dictionary(openings[int(area["id"])])))
	for connection in connections:
		walls.append_array(_corridor_walls(Rect2(connection["corridor"]), Vector2(areas[int(connection["from"])]["center"]), Vector2(areas[int(connection["to"])]["center"])))
	for area in areas:
		if int(area["id"]) == 0 or String(area["kind"]) == "boss": continue
		walls.append_array(_room_obstacles(Rect2(area["rect"]), int(area["id"]), rng))

	var start_center := Vector2(areas[0]["center"])
	var far_center := Vector2(areas[3]["center"])
	var gate_center := Vector2.ZERO
	var gate_rect := Rect2()
	if include_shortcut:
		var shortcut: Dictionary = connections[-1]
		var shortcut_corridor := Rect2(shortcut["corridor"])
		gate_center = shortcut_corridor.get_center()
		if absf(far_center.x - start_center.x) > absf(far_center.y - start_center.y):
			gate_rect = Rect2(gate_center - Vector2(WALL_THICKNESS * 0.5, CORRIDOR_WIDTH * 0.5), Vector2(WALL_THICKNESS, CORRIDOR_WIDTH))
		else:
			gate_rect = Rect2(gate_center - Vector2(CORRIDOR_WIDTH * 0.5, WALL_THICKNESS * 0.5), Vector2(CORRIDOR_WIDTH, WALL_THICKNESS))
		walls.append(gate_rect)

	var encounter_templates: Dictionary = {}
	for area_id in range(1, areas.size()):
		encounter_templates[area_id] = _encounter_for(area_id, Vector2(areas[area_id]["center"]), seed_value)

	return {
		"world_size": WORLD_SIZE,
		"areas": areas,
		"connections": connections,
		"walls": walls,
		"base_walls": walls.slice(0, walls.size() - 1) if include_shortcut else walls.duplicate(),
		"encounters": encounter_templates,
		"bonfire_pos": Vector2(areas[0]["center"]),
		"player_start": Vector2(areas[0]["center"]) + (Vector2.DOWN if not mirror_y else Vector2.UP) * 170.0,
		"exit_pos": Vector2(areas[6]["center"]),
		"shortcut_gate": gate_rect,
		"shortcut_unlock_pos": gate_center.lerp(far_center, 0.56) if include_shortcut else Vector2.ZERO,
		"shortcut_start_pos": gate_center.lerp(start_center, 0.56) if include_shortcut else Vector2.ZERO,
		"waystones": [],
		"shortcuts": [],
		"transitions": [],
		"layers": {"expedition_surface": {"name": "Expedition", "ground_color": "314247"}},
	}

static func _corridor_between(a: Rect2, b: Rect2) -> Rect2:
	var ac := a.get_center()
	var bc := b.get_center()
	if absf(ac.x - bc.x) > absf(ac.y - bc.y):
		var left := minf(a.end.x if ac.x < bc.x else b.end.x, b.end.x if bc.x < ac.x else a.end.x)
		var right := maxf(a.position.x if ac.x > bc.x else b.position.x, b.position.x if bc.x > ac.x else a.position.x)
		return Rect2(left, ac.y - CORRIDOR_WIDTH * 0.5, maxf(1.0, right - left), CORRIDOR_WIDTH)
	var top := minf(a.end.y if ac.y < bc.y else b.end.y, b.end.y if bc.y < ac.y else a.end.y)
	var bottom := maxf(a.position.y if ac.y > bc.y else b.position.y, b.position.y if bc.y > ac.y else a.position.y)
	return Rect2(ac.x - CORRIDOR_WIDTH * 0.5, top, CORRIDOR_WIDTH, maxf(1.0, bottom - top))

static func _register_opening(openings: Dictionary, room: Rect2, other_center: Vector2) -> void:
	var offset := other_center - room.get_center()
	if absf(offset.x) > absf(offset.y):
		openings["right" if offset.x > 0 else "left"].append(room.get_center().y)
	else:
		openings["bottom" if offset.y > 0 else "top"].append(room.get_center().x)

static func _room_boundary(rect: Rect2, openings: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2] = []
	result.append_array(_horizontal_wall(rect.position.y, rect.position.x, rect.end.x, Array(openings["top"])))
	result.append_array(_horizontal_wall(rect.end.y - WALL_THICKNESS, rect.position.x, rect.end.x, Array(openings["bottom"])))
	result.append_array(_vertical_wall(rect.position.x, rect.position.y, rect.end.y, Array(openings["left"])))
	result.append_array(_vertical_wall(rect.end.x - WALL_THICKNESS, rect.position.y, rect.end.y, Array(openings["right"])))
	return result

static func _horizontal_wall(y: float, start: float, finish: float, openings: Array) -> Array[Rect2]:
	var cuts: Array[Vector2] = []
	for center in openings: cuts.append(Vector2(float(center) - DOOR_WIDTH * 0.5, float(center) + DOOR_WIDTH * 0.5))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var result: Array[Rect2] = []
	var cursor := start
	for cut in cuts:
		if cut.x > cursor: result.append(Rect2(cursor, y, cut.x - cursor, WALL_THICKNESS))
		cursor = maxf(cursor, cut.y)
	if cursor < finish: result.append(Rect2(cursor, y, finish - cursor, WALL_THICKNESS))
	return result

static func _vertical_wall(x: float, start: float, finish: float, openings: Array) -> Array[Rect2]:
	var cuts: Array[Vector2] = []
	for center in openings: cuts.append(Vector2(float(center) - DOOR_WIDTH * 0.5, float(center) + DOOR_WIDTH * 0.5))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var result: Array[Rect2] = []
	var cursor := start
	for cut in cuts:
		if cut.x > cursor: result.append(Rect2(x, cursor, WALL_THICKNESS, cut.x - cursor))
		cursor = maxf(cursor, cut.y)
	if cursor < finish: result.append(Rect2(x, cursor, WALL_THICKNESS, finish - cursor))
	return result

static func _corridor_walls(rect: Rect2, a: Vector2, b: Vector2) -> Array[Rect2]:
	if absf(a.x - b.x) > absf(a.y - b.y):
		return [Rect2(rect.position.x, rect.position.y - WALL_THICKNESS, rect.size.x, WALL_THICKNESS), Rect2(rect.position.x, rect.end.y, rect.size.x, WALL_THICKNESS)]
	return [Rect2(rect.position.x - WALL_THICKNESS, rect.position.y, WALL_THICKNESS, rect.size.y), Rect2(rect.end.x, rect.position.y, WALL_THICKNESS, rect.size.y)]

static func _room_obstacles(rect: Rect2, area_id: int, rng: RandomNumberGenerator) -> Array[Rect2]:
	var center := rect.get_center()
	# Openings are centered on each wall. Keeping the entire central cross clear
	# gives every pair of doors a generous, direct route through the room.
	# Small corner pillars still create cover without forming choke points.
	var corner_offsets := [
		Vector2(-260, -200),
		Vector2(260, -200),
		Vector2(-260, 200),
		Vector2(260, 200),
	]
	var first := (area_id + rng.randi_range(0, 3)) % corner_offsets.size()
	var second := (first + 2) % corner_offsets.size()
	var pillar_size := Vector2(68, 68)
	return [
		Rect2(center + corner_offsets[first] - pillar_size * 0.5, pillar_size),
		Rect2(center + corner_offsets[second] - pillar_size * 0.5, pillar_size),
	]

static func _encounter_for(area_id: int, center: Vector2, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + area_id * 104729
	var roster: Array[String]
	match area_id:
		1: roster = ["blade", "knife"]
		2: roster = ["hound", "archer", "blade"]
		3: roster = ["knife", "polearm", "archer"]
		4: roster = ["hexer", "captain", "blade"]
		5: roster = ["brute", "polearm", "hexer"]
		6: roster = ["warden"]
		_: roster = ["brute", "captain", "hound", "knife"]
	var offsets := [Vector2(-220, -130), Vector2(210, -120), Vector2(-170, 160), Vector2(180, 170)]
	if rng.randi() % 2 == 0: offsets.reverse()
	var result: Array[Dictionary] = []
	for index in range(roster.size()):
		var kind := roster[index]
		result.append({"kind": kind, "pos": center + offsets[index], "area_id": area_id})
	return result
