extends SceneTree

const State = preload("res://scripts/campaign/campaign_state.gd")
const Regions = preload("res://scripts/campaign/campaign_regions.gd")
const STEP := 40.0
var checks := 0
var failures: Array[String] = []
var travel: Array[Dictionary] = []
var s: State
var grid_cache: Dictionary = {}

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
	return ok

func fresh(seed_value: int = 131137, actor: String = "warrior") -> void:
	s = State.new(false)
	s.start_run(actor, "campaign_lab", seed_value)
	grid_cache.clear()

func place(p: Vector2, layer: String) -> void:
	s.current_layer = layer
	s.player_pos = p
	s.current_area_id = s._area_id_at_position(p, layer)
	s._load_current_layer_discovery()
	s._apply_shortcut_world_state()
	s._update_exploration(true)

func clear_at(p: Vector2, layer: String, walls: Array, radius: float) -> bool:
	for direction in [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		if not s._point_on_floor_for_layer(p + direction * radius * 0.72, layer): return false
	for wall in walls:
		if s._circle_intersects_rect(p, radius, wall): return false
	return true

func path(a: Vector2, b: Vector2, layer: String, walls: Array) -> PackedVector2Array:
	var key := [layer, hash(walls)]
	var graph: AStarGrid2D = grid_cache.get(key)
	if graph == null:
		var region := Rect2i()
		for shape in s.floor_shapes:
			if shape.layer != layer: continue
			var bounds := Rect2(shape.rect)
			var rect := Rect2i(Vector2i((bounds.position / STEP).floor()), Vector2i((bounds.size / STEP).ceil()) + Vector2i.ONE)
			region = rect if region.size == Vector2i.ZERO else region.merge(rect)
		graph = AStarGrid2D.new()
		graph.region = region
		graph.cell_size = Vector2.ONE * STEP
		graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		graph.update()
		for x in range(region.position.x, region.end.x):
			for y in range(region.position.y, region.end.y):
				var cell := Vector2i(x, y)
				var p := graph.get_point_position(cell)
				graph.set_point_solid(cell, not clear_at(p, layer, walls, s.PLAYER_RADIUS + 6)
					or s._floor_boundaries[layer].sweep(p, p, s.PLAYER_RADIUS * 0.72 + 6) != INF)
		grid_cache[key] = graph
	var start := nearest_cell(graph, a, layer, walls)
	var finish := nearest_cell(graph, b, layer, walls)
	if start.x < 0 or finish.x < 0: return PackedVector2Array()
	var route := graph.get_point_path(start, finish)
	if route.is_empty(): return route
	route.insert(0, a)
	route.append(b)
	return route

func nearest_cell(graph: AStarGrid2D, p: Vector2, layer: String, walls: Array) -> Vector2i:
	var home := Vector2i((p / STEP).round())
	var best := Vector2i(-1, -1)
	var distance := INF
	for x in range(-1, 2):
		for y in range(-1, 2):
			var cell := home + Vector2i(x, y)
			if not graph.is_in_boundsv(cell) or graph.is_point_solid(cell): continue
			var at := graph.get_point_position(cell)
			if p.distance_to(at) >= distance or not segment_clear(p, at, layer, walls): continue
			best = cell
			distance = p.distance_to(at)
	return best

func segment_clear(a: Vector2, b: Vector2, layer: String, walls: Array) -> bool:
	if s._floor_boundaries[layer].sweep(a, b, s.PLAYER_RADIUS * 0.72 + 3) != INF: return false
	var samples := maxi(1, ceili(a.distance_to(b) / 14.0))
	for i in range(samples + 1):
		if not clear_at(a.lerp(b, float(i) / samples), layer, walls, s.PLAYER_RADIUS + 2): return false
	return true

func walk(destination: Vector2, label: String) -> bool:
	var layer := s.current_layer
	var walls := s.walls.duplicate()
	var route := path(s.player_pos, destination, layer, walls)
	if not check(not route.is_empty(), "path exists " + label): return false
	var begin := s.simulation_time
	var length := 0.0
	var stride_count := 0
	var index := 0
	while index < route.size() - 1:
		var next := index + 1
		for best in range(next + 1, route.size()):
			if not segment_clear(s.player_pos, route[best], layer, walls): break
			next = best
		var target := route[next]
		while s.player_pos.distance_to(target) > 18.0:
			var old := s.player_pos
			if not s.request_move(old.direction_to(target)) or old.distance_to(s.player_pos) < 1.0:
				return check(false, "legal stride " + label + " " + str(old) + " -> " + str(target))
			length += old.distance_to(s.player_pos)
			stride_count += 1
			if stride_count > 900: return check(false, "bounded strides " + label)
		index = next
	travel.append({"leg": label, "distance_units": snappedf(length, 0.1), "simulation_seconds": snappedf(s.simulation_time - begin, 0.001), "strides": stride_count})
	return check(s.player_pos.distance_to(destination) <= 18.0, "arrive " + label)

func use(destination: Vector2, label: String, layer: String) -> bool:
	if not walk(destination, label): return false
	return check(s.request_context_action() and s.current_layer == layer, "context traversal " + label + " / " + s.message)

func kill_fixture(id: String) -> void:
	var layer := s.current_layer
	var template: Dictionary
	for seats in s.encounter_templates.values():
		if seats.size() == 1 and seats[0].kind == id:
			template = seats[0]
			break
	var guardian := s._make_enemy(id, template.pos, 1)
	guardian.id = Regions.BOSS_IDS[id]
	guardian.layer = layer
	s._add_enemy_actor(guardian)
	guardian.hp = 0
	s._remove_dead_enemies()
	check(s.defeated_guardians.has(id), "shared death processing " + id)

func guarded_crossing(guardian: String, control: Vector2, far_side: Vector2) -> void:
	if not walk(control, guardian + " lever"): return
	check(s.interaction_label() == "SEALED" and not s.request_context_action(), "guard controls lever " + guardian)
	check(path(s.player_pos, far_side, s.current_layer, s.walls).is_empty(), "physical crossing closed " + guardian)
	kill_fixture(guardian)
	check(path(s.player_pos, far_side, s.current_layer, s.walls).is_empty(), "defeat leaves lever under player control " + guardian)
	check(s.request_context_action(), "operate crossing " + guardian)

func reach_mill() -> void:
	walk(Vector2(2250, 2140), "Dawn to River Descent")
	walk(Vector2(4520, 1900), "River Descent to Basin")

func reach_bell() -> void:
	use(Vector2(2290, 530), "Dawn to Ridge Stairs", Regions.RIDGE)
	walk(Vector2(4990, 675), "Ridge Stairs to Carillon")

func mill_entry() -> void:
	guarded_crossing("sluice_keeper", Vector2(6900, 2300), Vector2(7680, 2310))
	use(Vector2(7680, 2310), "Walk drained channel", Regions.FOUNDATIONS)
	use(Vector2(8310, 1920), "Cistern ascent to Lantern Court", Regions.CORE)

func bell_entry() -> void:
	guarded_crossing("bell_warden", Vector2(7170, 980), Vector2(7800, 980))
	walk(Vector2(7800, 980), "Walk lowered bridge")
	use(Vector2(8430, 2000), "Gallery descent to Lantern Court", Regions.CORE)

func finale(label: String) -> void:
	walk(Vector2(8170, 1900), label + " Lantern")
	check(s.activate_waystone(), "Lantern checkpoint")
	s._replace_enemy_actors([])
	walk(Vector2(8380, 1050), label + " long Crown approach")
	kill_fixture("hollow_keeper")
	check(s.campaign_victory(), "victory " + label)
	walk(Vector2(8320, 1470), label + " stair far side")
	check(s.unlock_shortcut() and s.unanchored_shortcut(), "service stair open pending")
	walk(Vector2(8170, 1900), label + " stair return")
	check(not s.unanchored_shortcut(), "service stair secured by arrival")
	check(s.save_run("user://regional-" + label + ".save"), "write ending")
	var reopened := State.new(false)
	check(reopened.load_run("user://regional-" + label + ".save"), "read ending")
	check(reopened.campaign_victory() and reopened.active_waystone_id == "lantern", "victory and checkpoint survive reload")
	reopened._begin_death()
	check(reopened.return_after_death(), "death after victory")
	for enemy in reopened.enemies:
		check(not reopened.defeated_guardians.has(enemy.kind), "defeated guardian stays gone")
	check(reopened.shortcuts.back().unlocked, "tower shortcut stays secured")

func route_orders() -> void:
	fresh()
	s._replace_enemy_actors([])
	reach_mill()
	mill_entry()
	check(not s.defeated_guardians.has("bell_warden"), "Mill-only entry")
	finale("mill-first")
	fresh(131138)
	s._replace_enemy_actors([])
	reach_bell()
	bell_entry()
	check(not s.defeated_guardians.has("sluice_keeper"), "Bell-only entry")
	finale("bell-first")

func lift_persistence() -> void:
	fresh()
	s._replace_enemy_actors([])
	reach_mill()
	walk(Vector2(4710, 1640), "Basin to freight landing")
	check(s.request_context_action() and s.unanchored_shortcut(), "freight lift operates before either boss")
	use(Vector2(4710, 1640), "Freight ascends", Regions.RIDGE)
	check(s.save_run("user://regional-pending-lift.save"), "save pending")
	var reopened := State.new(false)
	check(reopened.load_run("user://regional-pending-lift.save") and reopened.unanchored_shortcut(), "reload keeps pending lift")
	reopened._begin_death()
	check(reopened.return_after_death() and not reopened.lift_memory.freight_lift.open, "death shuts pending freight lift")
	use(Vector2(4710, 1640), "Freight descends", Regions.SURFACE)
	walk(Vector2(4520, 1900), "Basin secures freight")
	check(not s.unanchored_shortcut() and s.lift_memory.freight_lift.secured, "arrival secures freight")
	use(Vector2(4820, 1345), "Penstock stairs", Regions.SERVICE)
	walk(Vector2(2190, 1660), "Wheelrace Tunnel to far-side service lift")
	check(s.request_context_action() and s.unanchored_shortcut(), "open Dawn service lift from below")
	use(Vector2(2190, 1660), "Dawn service lift ascends", Regions.SURFACE)
	check(s.request_context_action() and s.current_layer == Regions.SERVICE, "Dawn service lift descends")
	check(s.request_context_action() and s.current_layer == Regions.SURFACE, "Dawn service lift returns surface")
	walk(Vector2(4520, 1900), "Secure service lift at Basin")
	s._begin_death()
	check(s.return_after_death() and s.lift_memory.service_lift.open and s.lift_memory.freight_lift.open, "both secured lifts survive death")

func return_route_measurements() -> void:
	fresh()
	s._replace_enemy_actors([])
	place(Vector2(2190, 1660), Regions.SERVICE)
	use(Vector2(4820, 1345), "Dawn lift closed: wheelrace backtrack", Regions.SURFACE)
	walk(Vector2(2190, 1660), "Dawn lift closed: outside backtrack")
	place(Vector2(2190, 1660), Regions.SERVICE)
	check(s.request_context_action(), "far-side lift release for return model")
	use(Vector2(2190, 1660), "Dawn lift opened: direct return", Regions.SURFACE)
	place(Vector2(8170, 1900), Regions.CORE)
	walk(Vector2(8380, 1050), "Lantern to Crown with service stair locked")
	walk(Vector2(8320, 1470), "Crown side stair handle")
	check(s.unlock_shortcut(), "service stair unlock for return model")
	walk(Vector2(8170, 1900), "Crown side stair to Lantern after unlock")
	walk(Vector2(8380, 1050), "Lantern to Crown with service stair open")

func geometry() -> void:
	var variants: Dictionary = {}
	for seed_value in [131137, 131138, 131139, 131140, 131141, 131142, 131143, 131144]:
		fresh(seed_value)
		variants[str(s.regional_variant)] = true
		for t in s.transitions:
			for side in ["from", "to"]:
				var layer := String(t[side + "_layer"])
				check(clear_at(t[side + "_pos"], layer, s.base_walls_by_layer[layer], s.PLAYER_RADIUS + 8), "transition landing " + t.id + " " + side)
		for actor in s.enemies:
			check(clear_at(actor.pos, actor.layer, s.base_walls_by_layer[actor.layer], actor.radius), "actor standing room " + actor.kind + " " + str(actor.pos))
		for item in s.world_pickups:
			check(clear_at(item.pos, item.layer, s.base_walls_by_layer[item.layer], s.PLAYER_RADIUS), "item reachable " + item.id)
	check(variants.size() >= 3, "multiple route variants observed")

func legacy_import() -> void:
	var fixture := OS.get_environment("WAYSTONE_REGIONAL_LEGACY_SAVE")
	if fixture.is_empty(): return
	var bytes := FileAccess.get_file_as_bytes(fixture)
	var file := FileAccess.open(fixture, FileAccess.READ)
	var payload: Dictionary = file.get_var(true)
	file.close()
	fresh()
	check(s.load_run(fixture), "ab18683 save loads")
	check(s.loadout_id == "mage_elementalist" and s.knows_spell("fireball") and s.selected_spell == "fireball", "legacy paid spell and selection survive")
	check(s.carried_xp == payload.carried_xp and s.secured_xp == payload.secured_xp and s.upgrade_count == payload.upgrade_count, "legacy XP and progression survive")
	check(s.current_layer == payload.current_layer and s.player_pos == payload.player_pos and s.route_released, "legacy position and relay survive")
	check(s.shortcuts[0].unlocked and s.anchor_state.shortcut_states.bridge_gate, "legacy secured gate stays open")
	check(s.shortcuts[1].unlocked and not s.anchor_state.shortcut_states.dawn_return and s.unanchored_shortcut(), "legacy pending gate remains pending")
	check(s.enemies.filter(func(enemy: Dictionary) -> bool: return int(enemy.id) < 1000).size() == payload.enemies.size(), "legacy defeated ordinary actor stays absent until rest")
	check(s.enemies.any(func(enemy: Dictionary) -> bool: return enemy.kind == "hollow_keeper") and s.world_pickups.size() >= 7, "new actors and supplies imported")
	check(FileAccess.get_file_as_bytes(fixture) == bytes, "original file bytes preserved")
	s._begin_death()
	check(s.return_after_death() and s.shortcuts[0].unlocked and not s.shortcuts[1].unlocked, "migrated secured and pending differ after death")

func exterior_circuit(first: String) -> void:
	fresh(131141 if first == "mill" else 131142)
	s._replace_enemy_actors([])
	if first == "mill":
		reach_mill()
		guarded_crossing("sluice_keeper", Vector2(6900, 2300), Vector2(7680, 2310))
	else:
		reach_bell()
		guarded_crossing("bell_warden", Vector2(7170, 980), Vector2(7800, 980))
	walk(Vector2(4710, 1640), first + "-first to freight lift")
	check(s.request_context_action(), first + "-first commission freight")
	if first == "mill":
		check(s.request_context_action() and s.current_layer == Regions.RIDGE, "freight route to second guardian")
		bell_entry()
		use(Vector2(8360, 2140), "switch to tower foundations", Regions.FOUNDATIONS)
		use(Vector2(7680, 2310), "foundations descend to river circuit", Regions.SURFACE)
		walk(Vector2(6900, 2300), "return along open riverbed")
	else:
		check(s.request_context_action() and s.current_layer == Regions.SURFACE, "freight route to second guardian")
		mill_entry()
		use(Vector2(8540, 1750), "switch to tower gallery", Regions.RIDGE)
		walk(Vector2(7170, 980), "return along lowered bridge")
	check(s.defeated_guardians.has("sluice_keeper") and s.defeated_guardians.has("bell_warden"), "both guardian victories recorded " + first)
	check(s.operated_crossings.has("sluice_drain") and s.operated_crossings.has("bell_bridge"), "both permanent crossings open " + first)
	check(s.save_run("user://regional-circuit-" + first + ".save"), "save exterior circuit " + first)
	var reopened := State.new(false)
	check(reopened.load_run("user://regional-circuit-" + first + ".save"), "load exterior circuit " + first)
	check(reopened.operated_crossings == s.operated_crossings and reopened.defeated_guardians == s.defeated_guardians, "both crossings and guardians remain persisted " + first)

func reward_flow() -> void:
	fresh()
	var cache := s.pickup_by_id("silt_cache")
	place(cache.pos, cache.layer)
	check(s.interaction_label() != "TAKE" and not s.request_collect_pickup(cache.id), "guarded cache refuses an early pickup")
	for enemy in s.enemies:
		if int(enemy.area_id) == int(cache.guard_site): enemy.hp = 0
	s._remove_dead_enemies()
	check(s.interaction_label() == "TAKE" and s.request_context_action(), "take cache through displayed context action")
	check(s.consumable_slot(0).id == "firebomb" and s.consumable_slot(0).count == 2, "actual belt receives both bombs")
	check(s.pickup_by_id(cache.id).is_empty(), "claimed cache removed")
	var path_name := "user://regional-claimed-cache.save"
	check(s.save_run(path_name), "save claimed cache")
	var reopened := State.new(false)
	check(reopened.load_run(path_name) and reopened.pickup_by_id(cache.id).is_empty(), "cache stays removed on reload")
	reopened._begin_death()
	check(reopened.return_after_death() and reopened.pickup_by_id(cache.id).is_empty(), "cache stays removed after death")
	print("REGIONAL CACHE ", checks, " checks / ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	if OS.get_cmdline_user_args().has("cache"):
		reward_flow()
		return
	geometry()
	route_orders()
	lift_persistence()
	legacy_import()
	exterior_circuit("mill")
	exterior_circuit("bell")
	return_route_measurements()
	var layout := Regions.generate(131137)
	var sites: Array = []
	for place_data in layout.areas:
		var kinds: Array = []
		for seat in Array(layout.encounters.get(place_data.id, [])): kinds.append(seat.kind)
		sites.append({"name": place_data.name, "layer": place_data.layer, "id": place_data.id,
			"optional": bool(place_data.get("optional", false)), "actors": kinds})
	var report := {"checks": checks, "failures": failures, "travel": travel, "seed": 131137, "places": sites}
	if FileAccess.file_exists("res://build-identity.json"):
		report["runtime"] = JSON.parse_string(FileAccess.get_file_as_string("res://build-identity.json"))
	var file := FileAccess.open("user://regional-route-evidence.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "	"))
	file.close()
	print("CAMPAIGN REGIONS ", checks, " checks, ", failures.size(), " failures; ", travel.size(), " walked legs")
	quit(0 if failures.is_empty() else 1)
