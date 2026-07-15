class_name FloorGenerator
extends RefCounted

const WORLD_SIZE := Vector2(5000.0, 4400.0)
const ROOM_SIZE := Vector2(760.0, 640.0)
const WALL_THICKNESS := 56.0
const DOOR_WIDTH := 180.0
const CORRIDOR_WIDTH := 180.0

static func generate(seed_value: int) -> Dictionary:
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

	var edge_pairs := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [2, 7], [3, 0]]
	var connections: Array[Dictionary] = []
	for edge_index in range(edge_pairs.size()):
		var pair: Array = edge_pairs[edge_index]
		var from_id := int(pair[0])
		var to_id := int(pair[1])
		var shortcut := edge_index == edge_pairs.size() - 1
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

	var shortcut: Dictionary = connections[-1]
	var shortcut_corridor := Rect2(shortcut["corridor"])
	var start_center := Vector2(areas[0]["center"])
	var far_center := Vector2(areas[3]["center"])
	var gate_center := shortcut_corridor.get_center()
	var gate_rect: Rect2
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
		"base_walls": walls.slice(0, walls.size() - 1),
		"encounters": encounter_templates,
		"bonfire_pos": Vector2(areas[0]["center"]),
		"player_start": Vector2(areas[0]["center"]) + (Vector2.DOWN if not mirror_y else Vector2.UP) * 170.0,
		"exit_pos": Vector2(areas[6]["center"]),
		"shortcut_gate": gate_rect,
		"shortcut_unlock_pos": gate_center.lerp(far_center, 0.56),
		"shortcut_start_pos": gate_center.lerp(start_center, 0.56),
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
	var result: Array[Rect2] = []
	match (area_id + rng.randi_range(0, 2)) % 4:
		0: result = [Rect2(center - Vector2(75, 180), Vector2(150, 150)), Rect2(center - Vector2(75, -30), Vector2(150, 150))]
		1: result = [Rect2(center - Vector2(250, 60), Vector2(170, 120)), Rect2(center + Vector2(80, -60), Vector2(170, 120))]
		2: result = [Rect2(center - Vector2(65, 210), Vector2(130, 140)), Rect2(center - Vector2(65, -70), Vector2(130, 140))]
		_: result = [Rect2(center - Vector2(250, 55), Vector2(145, 110)), Rect2(center + Vector2(105, -55), Vector2(145, 110))]
	return result

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
