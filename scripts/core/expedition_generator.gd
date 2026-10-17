class_name ExpeditionGenerator
extends RefCounted

const Catalog = preload("res://scripts/core/expedition_catalog.gd")
const Combat = preload("res://scripts/core/combat_catalog.gd")
const LAYER := "expedition_surface"
const WORLD_SIZE := Vector2(13700, 4600)
const SITE_RADIUS := 570.0
const PATH_RADIUS := 240.0

static func generate(seed_value: int, biome_index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 104729 * (biome_index + 1)
	var region := Catalog.biome(biome_index)
	var content := Catalog.select_content(biome_index, rng)
	var shapes: Array = []
	var areas: Array = []
	var connections: Array = []
	var encounters: Dictionary = {}
	var features: Array = []
	var pickups: Array = []
	var sites: Array = []
	var start := Vector2(450, 2300)
	var previous := start
	_circle(shapes, start, 360, -1)
	for index in range(6):
		var center := Vector2(1400 + 1450 * index + (650 if index >= 3 else 0), 2200 + (250 if index % 2 == 0 else -250) + rng.randf_range(-100,100))
		var encounter: Dictionary = content["encounters"][index].duplicate(true)
		encounter.merge({"site":index, "pos":center, "xp":region["xp"][index], "crowns":region["crowns"], "pacing":["introduction","introduction","combination","development","pressure","peak"][index]})
		sites.append(encounter)
		_site(shapes, areas, features, encounter, biome_index)
		_connect(shapes, connections, previous, center, index)
		# A parallel approach reconnects before the next site. Encounters can be
		# avoided; neither a floor seam nor a clear flag locks ordinary travel.
		var flank := center + Vector2(0, 740 if index % 2 == 0 else -740)
		_path(shapes, previous, flank, 190, index)
		_path(shapes, flank, center + Vector2(600,0), 190, index)
		previous = center
		encounters[index] = _actors(encounter, biome_index)
	var quiet := Vector2(5200,2200)
	_circle(shapes, quiet, 400, 20)
	_path(shapes, Vector2(sites[2]["pos"]), quiet, PATH_RADIUS, 20)
	_path(shapes, quiet, Vector2(sites[3]["pos"]), PATH_RADIUS, 20)
	areas.append(_area(20, quiet, 400, String(region["landmark"]), "respite", String(region["vista"])))
	var prep := Vector2(10600,2200)
	_circle(shapes, prep, 390, 21)
	_connect(shapes, connections, previous, prep, 21, 5)
	areas.append(_area(21, prep, 390, "Preparation Terrace", "respite", "Prepare before the ascent's guardian. This is not a checkpoint."))
	for optional in range(2):
		var anchor := Vector2(sites[1 + optional * 3]["pos"])
		var center := anchor + Vector2(180, 1370 if optional == 0 else -1370)
		var encounter: Dictionary = content["encounters"][6+optional].duplicate(true)
		encounter.merge({"site":6+optional, "pos":center, "xp":region["optional_xp"][optional], "crowns":region["optional_crowns"], "pacing":"optional"})
		sites.append(encounter)
		_site(shapes, areas, features, encounter, biome_index)
		_connect(shapes, connections, anchor, center, 6+optional, 1+optional*3)
		encounters[6+optional] = _actors(encounter, biome_index)
	# One exploratory ration, one guarded ration. Both have stable IDs and are
	# removed from saved world state on collection; no regeneration at Waystones.
	var pocket := Vector2(650,3450)
	_path(shapes, start, pocket, 180, 22)
	_circle(shapes, pocket, 250, 22)
	areas.append(_area(22,pocket,250,"Trail Supplies","discovery","A finite ration cache, away from the guarded road."))
	pickups.append(_pickup(biome_index, "exploratory_ration", pocket, "trail_ration", -1))
	pickups.append(_pickup(biome_index, "guarded_ration", Vector2(sites[6]["pos"])+Vector2(220,0), "trail_ration", 6))
	var cache_items := ["scout_boots","gripping_gloves","channeler_wrap"]
	pickups.append(_pickup(biome_index, "guarded_equipment", Vector2(sites[7]["pos"])+Vector2(220,0), cache_items[biome_index], 7))
	# Visible prototypes of regional landmarks: a charcoal camp, ore machinery,
	# and a ruined bell tower. These never turn safe spaces into obstacle traps.
	features.append({"kind":["charcoal_kiln","ore_lift","bell_spire"][biome_index],"pos":quiet+Vector2(0,-220),"radius":90.0,"layer":LAYER,"part_id":20,"blocks":false})
	var boss_pos := Vector2(11900,2200)
	_circle(shapes, boss_pos, 820, 9)
	_connect(shapes, connections, prep, boss_pos, 9, 21)
	areas.append(_area(9, boss_pos, 820, String(region["boss"]).capitalize(), "boss", "A solo guardian. Read its commitments and use its recovery."))
	encounters[9] = [{"kind":region["boss"], "pos":boss_pos, "layer":LAYER, "area_id":9, "expedition_site":9, "expedition_xp":region["boss_xp"], "id":(biome_index+1)*10000+901}]
	var stone_pos := Vector2(12850,2200)
	var exit_pos := Vector2(13250,2200)
	_path(shapes, boss_pos, exit_pos, 220, 23)
	_circle(shapes, stone_pos, 300, 23)
	areas.append(_area(23,stone_pos,300,"The Last Step","respite","The route beyond closes behind you. Use the Waystone now or leave it behind."))
	var shop_pos := quiet if biome_index == 1 else prep
	return {"world_size":WORLD_SIZE, "geometry_style":"organic", "areas":areas, "connections":connections, "floor_shapes":shapes, "terrain_features":features, "pickups":pickups, "waystones":[{"id":"ascent_%d" % biome_index, "pos":stone_pos, "layer":LAYER}], "shortcuts":[], "transitions":[], "secret_passages":[], "layers":{LAYER:{"name":region["name"], "ground_color":region["color"]}}, "encounters":encounters, "layer_walls":{LAYER:[]}, "base_walls":[], "bonfire_pos":stone_pos, "player_start":start, "shortcut_gate":Rect2(), "shortcut_unlock_pos":Vector2.ZERO, "shortcut_start_pos":Vector2.ZERO, "expedition_sites":sites, "expedition_roster":content["roster"], "expedition_markers":{"merchant":shop_pos, "landmark":quiet, "preparation":prep, "exit":exit_pos}, "biome":biome_index, "generation":Catalog.GENERATION_VERSION}

static func _actors(site: Dictionary, biome_index: int) -> Array:
	var result: Array = []
	var kinds: Array = site["kinds"].duplicate()
	var has_bell := kinds.has("bellrunner")
	if has_bell: kinds.append("polearm")
	for index in range(kinds.size()):
		var point := Vector2(site["pos"]) + Vector2((index % 2)*190-95, (index/2)*190-90)
		var xp := int(site["xp"]) / kinds.size() + (1 if index < int(site["xp"]) % kinds.size() else 0)
		result.append({"kind":kinds[index], "pos":point, "layer":LAYER, "area_id":site["site"], "expedition_site":site["site"], "expedition_xp":xp, "id":(biome_index+1)*10000+int(site["site"])*100+index+1, "reserve":has_bell and index==kinds.size()-1, "gong_pos":Vector2(site["pos"])+Vector2(260,-200)})
	return result

static func _site(shapes: Array, areas: Array, features: Array, site: Dictionary, biome_index: int) -> void:
	var center := Vector2(site["pos"])
	var terrain := String(site["terrain"])
	if terrain in ["ore_road","ravine","retaining_wall","ore_lift","ruined_bridge"]:
		_path(shapes,center-Vector2(300,0),center+Vector2(300,0),280,int(site["site"]))
	else: _circle(shapes, center, SITE_RADIUS, int(site["site"]))
	areas.append(_area(int(site["site"]), center, SITE_RADIUS, String(site["id"]).capitalize(), String(site["pacing"]), String(site["interaction"])))
	# Different cover arrangements change approach angles while preserving a
	# wide central route. The parallel outdoor bypass remains available.
	var offsets: Array = [Vector2(-280,190),Vector2(280,190)]
	if terrain in ["charcoal_camp","furnace_court","windbreak"]: offsets = [Vector2(-260,-230),Vector2(270,230),Vector2(270,-270)]
	elif terrain in ["quarry","exposed_terrace","clearing"]: offsets = [Vector2(-300,270),Vector2(300,-270)]
	var cover_kind := "boulder" if biome_index==0 else "foundry_block" if biome_index==1 else "windbreak_stone"
	for offset in offsets:
		features.append({"kind":cover_kind,"pos":center+Vector2(offset),"radius":65.0,"layer":LAYER,"part_id":site["site"],"blocks":true})
	if biome_index==0 and terrain not in ["ore_road","ravine"]:
		for offset in [Vector2(-380,-150),Vector2(150,380)]:
			features.append({"kind":"tree","pos":center+offset,"radius":48.0,"layer":LAYER,"part_id":site["site"],"blocks":true})
	if terrain in ["charcoal_camp","ore_lift","bell_terrace"]:
		features.append({"kind":{"charcoal_camp":"charcoal_kiln","ore_lift":"ore_lift","bell_terrace":"bell_spire"}[terrain],"pos":center+Vector2(-300,0),"radius":50.0,"layer":LAYER,"part_id":site["site"],"blocks":false})

static func _area(id: int, point: Vector2, radius: float, title: String, pacing: String, arrival: String) -> Dictionary:
	return {"id":id, "name":title, "kind":"boss" if pacing=="boss" else "locale", "center":point, "rect":Rect2(point-Vector2.ONE*radius, Vector2.ONE*radius*2), "entry":point-Vector2(radius,0), "exit":point+Vector2(radius,0), "layer":LAYER, "discovered":false, "zones":[{"pos":point,"radius":radius,"role":pacing}], "arrival_text":arrival, "area_theme":pacing}

static func _circle(shapes: Array, center: Vector2, radius: float, part: int) -> void:
	shapes.append({"kind":"circle", "center":center, "radius":radius, "layer":LAYER, "part_id":part, "semantic":"clearing"})

static func _path(shapes: Array, start: Vector2, finish: Vector2, radius: float, part: int) -> void:
	shapes.append({"kind":"capsule", "from":start, "to":finish, "radius":radius, "layer":LAYER, "part_id":part, "semantic":"path"})

static func _connect(shapes: Array, connections: Array, start: Vector2, finish: Vector2, part: int, from_part: int = -999) -> void:
	_path(shapes,start,finish,PATH_RADIUS,part)
	connections.append({"id":connections.size(), "from":part-1 if from_part == -999 else from_part, "to":part, "path":[start,finish], "path_radius":PATH_RADIUS, "layer":LAYER, "shortcut":false, "unlocked":true, "corridor":Rect2(start,finish-start).abs().grow(PATH_RADIUS)})

static func _pickup(biome_index: int, id: String, point: Vector2, item: String, guard_site: int) -> Dictionary:
	return {"id":"b%d_%s" % [biome_index,id], "item_id":item, "pos":point, "layer":LAYER, "count":1, "area_id":guard_site, "guard_site":guard_site}

static func validate(layout: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	var kinds: Dictionary = {}
	var ids: Dictionary = {}
	var main_xp := 0
	var optional_xp := 0
	var main_crowns := 0
	var actors_all: Array = []
	for site in layout["expedition_sites"]:
		if seen.has(site["id"]): errors.append("Repeated template")
		seen[site["id"]] = true
		var actors: Array = layout["encounters"][site["site"]]
		if actors.size()<2 or actors.size()>4: errors.append("Population outside 2-4")
		var ranged := 0
		var site_xp := 0
		for actor in actors:
			actors_all.append(actor)
			site_xp += int(actor["expedition_xp"])
			kinds[actor["kind"]] = true
			if actor["kind"] in ["archer","javelineer","thornspitter","slagthrower","fire_caster","air_caster","earth_caster"]: ranged+=1
			if ids.has(actor["id"]): errors.append("Repeated entity ID")
			ids[actor["id"]] = true
			var radius := float(Combat.enemy_fact(String(actor["kind"]),"radius"))
			if not legal_disc(layout, actor["pos"],radius): errors.append("Actor footprint illegally placed")
		if site_xp != int(site["xp"]): errors.append("Encounter XP budget mismatch")
		if bool(site["optional"]): optional_xp += site_xp
		else:
			main_xp += site_xp
			main_crowns += int(site["crowns"])
		if ranged>2: errors.append("Too many ranged-pressure actors")
	for kind in layout["expedition_roster"]:
		if not kinds.has(kind): errors.append("Missing roster kind %s" % kind)
	if seen.size()!=8: errors.append("Need eight unique encounter sites")
	if layout["expedition_roster"].size()!=7: errors.append("Need seven selected roster types")
	var biome_index := int(layout["biome"])
	if main_xp!=[30,48,72][biome_index] or optional_xp!=[6,14,22][biome_index]: errors.append("Wrong XP milestones")
	if main_crowns!=[72,96,120][biome_index]: errors.append("Wrong economy budget")
	for i in range(actors_all.size()):
		for j in range(i):
			var a: Dictionary = actors_all[i]
			var b: Dictionary = actors_all[j]
			if Vector2(a["pos"]).distance_to(b["pos"])<float(Combat.enemy_fact(a["kind"],"radius"))+float(Combat.enemy_fact(b["kind"],"radius")): errors.append("Overlapping actors")
	for connection in layout["connections"]:
		var path: Array = connection["path"]
		if not route_exists(layout,path[0],path[1]): errors.append("Disconnected player-width route")
	for marker in ["merchant","landmark","preparation"]:
		var point := Vector2(layout["expedition_markers"][marker])
		for actor in actors_all:
			if point.distance_to(actor["pos"])<750: errors.append("Unsafe respite placement")
		if not legal_disc(layout,point,100): errors.append("Blocked respite")
	var rations := 0
	for pickup in layout["pickups"]:
		if pickup["item_id"]=="trail_ration": rations+=int(pickup["count"])
		if not legal_disc(layout,pickup["pos"],20): errors.append("Illegal discovery placement")
	if rations!=2: errors.append("Finite ration budget mismatch")
	return errors

static func legal_disc(layout: Dictionary, point: Vector2, radius: float) -> bool:
	var contained := false
	for shape in layout["floor_shapes"]:
		var nearest: Vector2 = shape["center"] if shape["kind"]=="circle" else Geometry2D.get_closest_point_to_segment(point,shape["from"],shape["to"])
		if point.distance_to(nearest)+radius<=float(shape["radius"]):
			contained = true
			break
	if not contained:
		if not on_floor(layout,point): return false
		for index in range(12):
			if not on_floor(layout,point+Vector2.RIGHT.rotated(index*TAU/12)*radius): return false
	for feature in layout["terrain_features"]:
		if not bool(feature.get("blocks",false)): continue
		var half := float(feature["radius"])*0.42
		var box := Rect2(Vector2(feature["pos"])-Vector2.ONE*half,Vector2.ONE*half*2)
		var nearest := point.clamp(box.position,box.end)
		if point.distance_to(nearest)<radius: return false
	return true

static func route_exists(layout: Dictionary, start: Vector2, finish: Vector2) -> bool:
	# A cover block may interrupt the centreline without disconnecting a route.
	# Search neighbouring lanes, validating the entire connecting swept segment.
	var side := start.direction_to(finish).orthogonal()
	var reachable: Array[Vector2] = [start]
	var steps := ceili(start.distance_to(finish)/100.0)
	for step in range(1,steps+1):
		var next: Array[Vector2] = []
		for lane in ([0] if step==steps else [-2,-1,0,1,2]):
			var point: Vector2 = start.lerp(finish,float(step)/steps)+side*float(lane)*70.0
			if not legal_disc(layout,point,30): continue
			for previous in reachable:
				var open := true
				for sample in range(1,6):
					if not legal_disc(layout,previous.lerp(point,sample/5.0),30):
						open = false
						break
				if open:
					next.append(point)
					break
		reachable = next
		if reachable.is_empty(): return false
	return true

static func on_floor(layout: Dictionary, point: Vector2) -> bool:
	for shape in layout["floor_shapes"]:
		var nearest: Vector2 = shape["center"] if shape["kind"]=="circle" else Geometry2D.get_closest_point_to_segment(point,shape["from"],shape["to"])
		if point.distance_to(nearest)<=float(shape["radius"]): return true
	return false
