extends RefCounted

const Dawn = preload("res://scripts/campaign/campaign_layout.gd")
const SURFACE := "forest_surface"
const RIDGE := "bell_road"
const SERVICE := "mill_service"
const FOUNDATIONS := "tower_foundations"
const CORE := "tower_core"
const BOSS_IDS := {"sluice_keeper": 1800, "bell_warden": 2800, "hollow_keeper": 3800}
const ELEVATIONS := {SURFACE: 240.0, "underpass": 0.0, RIDGE: 610.0, SERVICE: 0.0, FOUNDATIONS: 0.0, CORE: 240.0}
const PALETTES := {
	"mill": Color("87876b"), "mill_interior": Color("a29070"), "bell": Color("989da1"),
	"bell_shelter": Color("a4a08b"), "foundation": Color("626d64"), "gallery": Color("8e8d9c"),
	"tower": Color("797b8b"), "court": Color("a29386")
}

static func generate(seed_value: int) -> Dictionary:
	var world := Dawn.generate(seed_value)
	world.world_size = Vector2(9100, 4450)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 527583
	var mill_east := rng.randi_range(0, 1) == 0
	var ridge_north := rng.randi_range(0, 1) == 0
	world["regional_variant"] = {"mill_east_catwalk": mill_east, "bell_north_colonnade": ridge_north}
	world.layers[SURFACE].name = "Dawn / Millrace"
	world.layers[RIDGE] = {"name": "Bell Road / Gallery"}
	world.layers[SERVICE] = {"name": "Mill service works"}
	world.layers[FOUNDATIONS] = {"name": "Foundations"}
	world.layers[CORE] = {"name": "Hollow Tower"}
	world.merge({"set_pieces": [], "crossings": [], "lifts": [], "pickups": []})
	_build_millrace(world, rng, mill_east)
	_build_bell_road(world, rng, ridge_north)
	_build_tower(world)
	_connect_adjacent_places(world)
	return world

static func _connect_adjacent_places(w: Dictionary) -> void:
	# Keep the next floor resident even when a place's center is far from its
	# entrance. Authored bridge/drain/shortcut walls still decide traversability.
	var seen := {}
	var shapes: Array = w.floor_shapes
	for i in shapes.size():
		var a: Dictionary = shapes[i]
		for j in range(i + 1, shapes.size()):
			var b: Dictionary = shapes[j]
			if a.layer != b.layer or a.part_id == b.part_id or not Rect2(a.rect).intersects(b.rect): continue
			var key := Vector2i(mini(a.part_id, b.part_id), maxi(a.part_id, b.part_id))
			if seen.has(key): continue
			seen[key] = true
			w.connections.append({"id": w.connections.size(), "from": a.part_id, "to": b.part_id,
				"layer": a.layer, "path": [Rect2(a.rect).get_center(), Rect2(b.rect).get_center()],
				"unlocked": true, "shortcut": false})

static func _build_millrace(w: Dictionary, rng: RandomNumberGenerator, east_catwalk: bool) -> void:
	_place(w, 100, "River Descent", SURFACE, "mill", [Rect2(2100, 1800, 350, 560), Rect2(1870, 2190, 860, 440)])
	_place(w, 101, "Willow Ford", SURFACE, "mill", [Rect2(1900, 2510, 410, 600), Rect2(1830, 2990, 900, 500)])
	_place(w, 102, "Towpath", SURFACE, "mill", [Rect2(2530, 2250, 1240, 390), Rect2(3490, 2060, 740, 580)])
	_place(w, 103, "Wheelhouse", SURFACE, "mill_interior", [Rect2(2590, 3040, 1170, 620), Rect2(3550, 3160, 550, 310)])
	_place(w, 104, "Miller's Loft", SURFACE, "mill_interior", [Rect2(2630, 3500, 1040, 600)], true)
	_place(w, 105, "Loading Basin", SURFACE, "mill", [Rect2(4020, 2190, 1060, 1140)])
	_place(w, 106, "Basin Waystone", SURFACE, "mill", [Rect2(4340, 1560, 710, 800)])
	_place(w, 107, "Pump Court", SURFACE, "mill_interior", [Rect2(4940, 1770, 1350, 730)])
	_place(w, 108, "Sandbank", SURFACE, "mill", [Rect2(4940, 2910, 1350, 660)])
	_place(w, 109, "Sluice", SURFACE, "mill", [Rect2(6110, 1810, 1030, 1560)])
	_place(w, 110, "Drain Channel", SURFACE, "foundation", [Rect2(7000, 2110, 820, 410)])
	_place(w, 111, "Maintenance Walk", SURFACE, "mill_interior", [Rect2(4690, 1250, 290, 500)])
	_place(w, 112, "Silt Garden", SURFACE, "mill", [Rect2(5450, 3370, 850, 680)], true)
	var catwalk := Rect2(3650, 2550, 300, 680) if east_catwalk else Rect2(2860, 2550, 300, 590)
	_place(w, 113, "Mill Catwalk", SURFACE, "mill_interior", [catwalk])
	_place(w, 114, "Penstock Vault", SERVICE, "foundation", [Rect2(3960, 1250, 1030, 420), Rect2(3670, 1360, 470, 560)])
	_place(w, 115, "Wheelrace Tunnel", SERVICE, "foundation", [Rect2(2780, 1580, 1070, 405), Rect2(2040, 1500, 920, 370)])

	# The north bank is exposed to long sightlines. Machinery screens the south
	# bank, with openings wide enough for melee direction changes and recovery.
	_wall(w, SURFACE, Rect2(2930, 3080, 430, 130))
	_wall(w, SURFACE, Rect2(3180, 3400, 430, 105))
	_wall(w, SURFACE, Rect2(3780, 2180, 120, 190))
	_wall(w, SURFACE, Rect2(4370, 2570, 190, 290))
	_wall(w, SURFACE, Rect2(5500, 2020, 250, 150))
	_wall(w, SURFACE, Rect2(5900, 2180, 110, 180))
	_wall(w, SURFACE, Rect2(5530, 3180, 280, 130))
	_wall(w, SURFACE, Rect2(6110, 2520, 480, 350))
	_wall(w, SURFACE, Rect2(6760, 2540, 380, 310))
	_wall(w, SURFACE, Rect2(5620, 3700, 130, 190))
	_wall(w, SERVICE, Rect2(3180, 1580, 160, 145))
	_encounter(w, 100, [["hound", Vector2(2200, 2180)]])
	_encounter(w, 101, [[["boar", "hound"][rng.randi_range(0, 1)], Vector2(2160, 3040)], ["knife", Vector2(2440, 3260)]])
	_encounter(w, 102, [["archer", Vector2(3350, 2420)], ["shield", Vector2(2990, 2400)]])
	_encounter(w, 103, [["kiln_guard", Vector2(3450, 3280)], ["knife", Vector2(2990, 3320)]])
	_encounter(w, 104, [["bandit", Vector2(2930, 3820)], ["archer", Vector2(3370, 3910)]])
	_encounter(w, 105, [["javelineer", Vector2(4770, 2490)], ["blade", Vector2(4230, 2590)], ["hound", Vector2(4640, 3050)]])
	_encounter(w, 107, [["shield", Vector2(5280, 2060)], ["slagthrower", Vector2(5760, 1950)]])
	_encounter(w, 108, [["polearm", Vector2(5500, 3040)], ["hound", Vector2(6000, 3340)]])
	_encounter(w, 112, [["thornspitter", Vector2(6040, 3820)], ["briarhook", Vector2(5860, 3700)]])
	_encounter(w, 114, [["kiln_guard", Vector2(4220, 1460)], ["archer", Vector2(3780, 1780)]])
	_encounter(w, 115, [["hound", Vector2(2800, 1740)], ["knife", Vector2(2530, 1760)]])
	_boss(w, 109, "sluice_keeper", Vector2(6630, 2460))
	_stone(w, "basin", "Basin Waystone", Vector2(4520, 1900), SURFACE)
	_supply(w, 104, "loft_reserve", "rejuvenation", Vector2(3430, 3960), 2)
	_supply(w, 112, "silt_cache", "firebomb", Vector2(6090, 3940), 2)
	_transition(w, "penstock_steps", "Penstock stairs", SURFACE, Vector2(4820, 1345), SERVICE, Vector2(4820, 1345))
	_lift(w, "service_lift", "Dawn service lift", SURFACE, Vector2(2190, 1660), SERVICE, Vector2(2190, 1660))
	_set_piece(w, SURFACE, "river", Rect2(2280, 2650, 3810, 250))
	_set_piece(w, SURFACE, "river", Rect2(6980, 2110, 860, 410))
	_set_piece(w, SURFACE, "wheel", Rect2(2360, 2570, 270, 190))
	_set_piece(w, SURFACE, "mill", Rect2(2880, 2890, 490, 160))
	_set_piece(w, SURFACE, "sluice", Rect2(6710, 2590, 200, 185))
	_crossing(w, "sluice_drain", "Drain channel", "sluice_keeper", SURFACE, Rect2(7070, 2110, 95, 410), Vector2(6900, 2300), "DRAIN")
	_transition(w, "foundation_steps", "Foundation stairs", SURFACE, Vector2(7680, 2310), FOUNDATIONS, Vector2(7680, 2310))

static func _build_bell_road(w: Dictionary, rng: RandomNumberGenerator, north_colonnade: bool) -> void:
	_place(w, 200, "Ridge Stairs", RIDGE, "bell", [Rect2(2120, 310, 740, 500)])
	_place(w, 201, "Windbreak", RIDGE, "bell_shelter", [Rect2(2670, 370, 980, 490), Rect2(3200, 690, 390, 610)])
	_place(w, 202, "Lookout Terrace", RIDGE, "bell", [Rect2(3040, 1090, 1130, 510), Rect2(4020, 1310, 610, 265)])
	_place(w, 203, "Bell Market", RIDGE, "bell", [Rect2(3540, 430, 1320, 570)])
	_place(w, 204, "Pilgrim Cells", RIDGE, "bell_shelter", [Rect2(3830, 130, 880, 410)], true)
	_place(w, 205, "Freight Balcony", RIDGE, "bell", [Rect2(4470, 920, 570, 750)])
	_place(w, 206, "Carillon Waystone", RIDGE, "bell_shelter", [Rect2(4740, 470, 660, 550)])
	_place(w, 207, "Bell Foundry", RIDGE, "bell_shelter", [Rect2(5240, 290, 1190, 530)])
	_place(w, 208, "Parapet Walk", RIDGE, "bell", [Rect2(5230, 870, 1110, 460)])
	_place(w, 209, "Warden Court", RIDGE, "bell", [Rect2(6240, 520, 1090, 820)])
	_place(w, 210, "Bridge Approach", RIDGE, "gallery", [Rect2(7180, 820, 735, 340)])
	_place(w, 211, "Bellkeeper's Quarters", RIDGE, "bell_shelter", [Rect2(5440, 1150, 720, 615)], true)
	var colonnade := Rect2(5730, 700, 330, 280) if north_colonnade else Rect2(5470, 640, 350, 295)
	_place(w, 212, "Foundry Colonnade", RIDGE, "bell_shelter", [colonnade])
	_wall(w, RIDGE, Rect2(2990, 400, 150, 260))
	_wall(w, RIDGE, Rect2(3460, 1210, 280, 105))
	_wall(w, RIDGE, Rect2(3960, 585, 160, 205))
	_wall(w, RIDGE, Rect2(4350, 675, 180, 130))
	_wall(w, RIDGE, Rect2(5430, 330, 360, 100))
	_wall(w, RIDGE, Rect2(5970, 490, 175, 150))
	_wall(w, RIDGE, Rect2(5740, 1040, 130, 160))
	_wall(w, RIDGE, Rect2(6520, 700, 185, 145))
	_wall(w, RIDGE, Rect2(6810, 1060, 160, 140))
	_encounter(w, 200, [["polearm", Vector2(2650, 540)]])
	_encounter(w, 201, [["shield", Vector2(3260, 595)], ["knife", Vector2(3440, 745)]])
	_encounter(w, 202, [["javelineer", Vector2(3910, 1350)], ["glasswing", Vector2(3520, 1420)]])
	_encounter(w, 203, [["archer", Vector2(4550, 555)], ["polearm", Vector2(4320, 860)]])
	_encounter(w, 204, [["bandit", Vector2(4130, 300)], ["knife", Vector2(4480, 290)]])
	_encounter(w, 205, [["archer", Vector2(4780, 1210)], ["blade", Vector2(4750, 1060)]])
	_encounter(w, 207, [["kiln_guard", Vector2(5680, 575)], ["slagthrower", Vector2(6200, 730)]])
	_encounter(w, 208, [[["hound", "glasswing"][rng.randi_range(0, 1)], Vector2(5480, 1050)], ["polearm", Vector2(6050, 1040)]])
	_encounter(w, 211, [["duellist", Vector2(5920, 1550)], ["archer", Vector2(5680, 1540)]])
	_boss(w, 209, "bell_warden", Vector2(6900, 870))
	_stone(w, "carillon", "Carillon Waystone", Vector2(4990, 675), RIDGE)
	_supply(w, 204, "pilgrim_supply", "rejuvenation", Vector2(4540, 260), 2)
	_supply(w, 211, "bellkeeper_supply", "smoke_vial", Vector2(6040, 1610), 1)
	_transition(w, "ridge_stairs", "Ridge stairs", SURFACE, Vector2(2290, 530), RIDGE, Vector2(2290, 530))
	_lift(w, "freight_lift", "Freight lift", SURFACE, Vector2(4710, 1640), RIDGE, Vector2(4710, 1640), true)
	_set_piece(w, RIDGE, "bell", Rect2(4820, 368, 175, 125))
	_set_piece(w, RIDGE, "towers", Rect2(7200, 1180, 220, 140))
	_crossing(w, "bell_bridge", "Counterweight bridge", "bell_warden", RIDGE, Rect2(7300, 820, 100, 340), Vector2(7170, 980), "LOWER")

static func _build_tower(w: Dictionary) -> void:
	_place(w, 300, "Foundation Landing", FOUNDATIONS, "foundation", [Rect2(7410, 2050, 640, 550)])
	_place(w, 301, "Cistern", FOUNDATIONS, "foundation", [Rect2(7750, 2490, 880, 650)])
	_place(w, 302, "Foundation Ascent", FOUNDATIONS, "foundation", [Rect2(8180, 2100, 510, 470), Rect2(8070, 1760, 700, 480)])
	_place(w, 303, "Sump Store", FOUNDATIONS, "foundation", [Rect2(7410, 2820, 470, 650)], true)
	_place(w, 304, "Upper Gallery", RIDGE, "gallery", [Rect2(7760, 680, 740, 665)])
	_place(w, 305, "Broken Cloister", RIDGE, "gallery", [Rect2(8170, 1190, 650, 550), Rect2(8110, 1600, 685, 560)])
	_place(w, 306, "Archive Balcony", RIDGE, "gallery", [Rect2(7970, 275, 695, 525)], true)
	_place(w, 307, "Lantern Court", CORE, "court", [Rect2(7910, 1640, 870, 770)])
	_place(w, 308, "Choir Passage", CORE, "tower", [Rect2(7400, 1890, 660, 430), Rect2(6960, 1660, 580, 580)])
	_place(w, 309, "West Ambulatory", CORE, "tower", [Rect2(6990, 1140, 420, 660)])
	_place(w, 310, "Crown Approach", CORE, "tower", [Rect2(7160, 1060, 1130, 400), Rect2(8040, 1040, 510, 590)])
	_place(w, 311, "Hollow Crown", CORE, "tower", [Rect2(8080, 440, 800, 740)])
	_place(w, 312, "Reliquary", CORE, "court", [Rect2(7480, 640, 620, 550)], true)
	_place(w, 313, "Service Stair", CORE, "tower", [Rect2(8180, 1450, 300, 370)])
	_wall(w, FOUNDATIONS, Rect2(8020, 2650, 170, 230))
	_wall(w, FOUNDATIONS, Rect2(8460, 2330, 95, 180))
	_wall(w, RIDGE, Rect2(8020, 910, 200, 120))
	_wall(w, RIDGE, Rect2(8410, 1480, 110, 150))
	_wall(w, CORE, Rect2(7190, 1850, 115, 135))
	_wall(w, CORE, Rect2(7030, 1390, 150, 115))
	_wall(w, CORE, Rect2(7630, 1110, 150, 100))
	_wall(w, CORE, Rect2(8290, 680, 125, 130))
	_wall(w, CORE, Rect2(8580, 860, 125, 130))
	_encounter(w, 300, [["hound", Vector2(7920, 2320)]])
	_encounter(w, 301, [["briarhook", Vector2(8265, 2800)], ["thornspitter", Vector2(8470, 2930)]])
	_encounter(w, 302, [["shield", Vector2(8360, 2170)], ["javelineer", Vector2(8560, 1930)]])
	_encounter(w, 303, [["knife", Vector2(7650, 3080)]])
	_encounter(w, 304, [["archer", Vector2(8260, 1100)], ["polearm", Vector2(7980, 1180)]])
	_encounter(w, 305, [["glasswing", Vector2(8530, 1730)], ["shield", Vector2(8390, 1810)]])
	_encounter(w, 306, [["duellist", Vector2(8250, 532)]])
	_encounter(w, 308, [["chanter", Vector2(7250, 2120)], ["blade", Vector2(7380, 1780)]])
	_encounter(w, 309, [["polearm", Vector2(7290, 1400)], ["knife", Vector2(7200, 1260)]])
	_encounter(w, 312, [["shield", Vector2(7770, 960)], ["archer", Vector2(7820, 850)]])
	_boss(w, 311, "hollow_keeper", Vector2(8540, 690))
	_stone(w, "lantern", "Lantern Waystone", Vector2(8170, 1900), CORE)
	_supply(w, 303, "sump_cache", "firebomb", Vector2(7640, 3290), 2)
	_supply(w, 306, "archive_cache", "smoke_vial", Vector2(8520, 440), 1)
	_supply(w, 312, "crown_reserve", "rejuvenation", Vector2(7790, 800), 2)
	_transition(w, "cistern_ascent", "Cistern ascent", FOUNDATIONS, Vector2(8310, 1920), CORE, Vector2(8360, 2140))
	_transition(w, "gallery_descent", "Gallery descent", RIDGE, Vector2(8430, 2000), CORE, Vector2(8540, 1750))
	_set_piece(w, FOUNDATIONS, "river", Rect2(8070, 3130, 680, 380))
	_set_piece(w, CORE, "towers", Rect2(8560, 280, 265, 180))
	_set_piece(w, CORE, "stairs", Rect2(8235, 1535, 190, 145))
	w.shortcuts.append({"id": "tower_service", "name": "Service stair", "gate": Rect2(8180, 1580, 300, 75),
		"unlock_pos": Vector2(8320, 1470), "near_pos": Vector2(8320, 1750), "layer": CORE,
		"unlocked": false, "interaction_radius": 90.0})

static func _place(w: Dictionary, id: int, label: String, layer: String, palette: String, rects: Array, optional := false) -> void:
	var bounds: Rect2 = rects[0]
	for r: Rect2 in rects:
		w.floor_shapes.append({"kind": "rect", "rect": r, "layer": layer, "part_id": id, "regional_palette": palette})
		bounds = bounds.merge(r)
	w.areas.append({"id": id, "name": label, "layer": layer, "center": bounds.get_center(),
		"rect": bounds, "palette": "forest_3", "regional_palette": palette, "optional": optional})

static func _wall(w: Dictionary, layer: String, rect: Rect2) -> void:
	if not w.layer_walls.has(layer): w.layer_walls[layer] = []
	w.layer_walls[layer].append(rect)

static func _encounter(w: Dictionary, id: int, seats: Array) -> void:
	for area in w.areas:
		if area.id != id: continue
		var group: Array = []
		for i in seats.size():
			group.append({"kind": seats[i][0], "pos": seats[i][1], "layer": area.layer, "id": 10000 + id * 10 + i})
		w.encounters[id] = group
		return

static func _boss(w: Dictionary, area_id: int, kind: String, pos: Vector2) -> void:
	_encounter(w, area_id, [[kind, pos]])
	w.encounters[area_id][0].id = BOSS_IDS[kind]
	for area in w.areas:
		if area.id != area_id: continue
		area["kind"] = "boss"
		area["boss_pos"] = pos
		break

static func _stone(w: Dictionary, id: String, label: String, pos: Vector2, layer: String) -> void:
	w.waystones.append({"id": id, "name": label, "pos": pos, "layer": layer})

static func _supply(w: Dictionary, area_id: int, id: String, item_id: String, pos: Vector2, count: int) -> void:
	for area in w.areas:
		if area.id == area_id:
			w.pickups.append({"id": id, "item_id": item_id, "pos": pos, "count": count, "layer": area.layer, "guard_site": area_id})
			return

static func _transition(w: Dictionary, id: String, label: String, a: String, p: Vector2, b: String, q: Vector2) -> void:
	w.transitions.append({"id": id, "name": label, "from_layer": a, "from_pos": p, "to_layer": b, "to_pos": q})

static func _lift(w: Dictionary, id: String, label: String, a: String, p: Vector2, b: String, q: Vector2, bilateral := false) -> void:
	_transition(w, id, label, a, p, b, q)
	var lift: Dictionary = w.transitions.back()
	lift.merge({"unlocked": false, "bilateral": bilateral})
	w.lifts.append(lift)

static func _set_piece(w: Dictionary, layer: String, kind: String, rect: Rect2) -> void:
	w.set_pieces.append({"layer": layer, "kind": kind, "rect": rect})

static func _crossing(w: Dictionary, id: String, label: String, boss: String, layer: String, gate: Rect2, lever: Vector2, action: String) -> void:
	w.crossings.append({"id": id, "name": label, "boss": boss, "layer": layer, "gate": gate, "lever": lever, "action": action})
