extends "res://tests/campaign_regions_test.gd"
# The earned run receives only public player requests. The inherited grid guides
# navigation and the combat planner forecasts actions on its own isolated copy.
const Planner = preload("res://tests/expedition_action_planner.gd")
var planner := Planner.new()
var decisions := {}
var visited := {}
var engaged := {}
var defeated := {}
var stops: Array[Dictionary] = []
var events: Array[Dictionary] = []
var route_replans := 0
var deaths := 0
var retries := 0
var started := 0
var route_recoveries := 0
var current_roster := {}
var seen_ids := {}

func inc(kind: String) -> void:
	decisions[kind] = int(decisions.get(kind, 0)) + 1

func journal(label: String) -> void:
	var entry := {"event": label, "at": str(s.player_pos), "layer": s.current_layer,
		"hp": s.player_hp, "energy": s.player_energy, "potions": s.potions,
		"simulation_seconds": s.simulation_time, "elapsed_seconds": (Time.get_ticks_msec() - started) / 1000.0,
		"decisions": decisions.duplicate()}
	events.append(entry)
	print("LIVE ROUTE ", JSON.stringify(entry))

func observe() -> void:
	var area := s.current_area_id
	if area >= 0: visited[area] = true
	var living := {}
	for enemy in s.enemies:
		var id := int(enemy.id)
		if not seen_ids.has(id): seen_ids[id] = {"site": int(enemy.get("area_id", -1)), "kind": String(enemy.kind)}
		living[id] = true
		if enemy.layer == s.current_layer and enemy.awareness == "alerted" and Vector2(enemy.pos).distance_to(s.player_pos) < 850:
			engaged[id] = seen_ids[id]
	for id in current_roster:
		if not living.has(id): defeated[id] = seen_ids[id]
	current_roster = living

func settle() -> bool:
	for tick in 900:
		observe()
		if s.death_pending:
			deaths += 1
			journal("death")
			return false
		if s.is_player_ready(): return true
		if s.player_action.kind == "bow_draw" and float(s.player_action.elapsed) >= 0.9:
			if s.release_bow_attack(): inc("bow release")
		s.advance_streamed_action_tick()
	return false

func threat() -> Dictionary:
	var target := {}
	var nearest := 530.0
	for enemy in s.enemies:
		if enemy.layer != s.current_layer or enemy.awareness != "alerted" or int(enemy.hp) <= 0: continue
		var distance := s.player_pos.distance_to(Vector2(enemy.pos))
		if distance >= nearest: continue
		target = enemy
		nearest = distance
	return target

func fight_step(target: Dictionary) -> bool:
	if s.player_hp <= 57 and s.potions > 0 and s.request_potion(false):
		inc("potion")
	elif planner.choose(s, target):
		inc("combat " + str(s.player_action.kind))
	else:
		if not s.request_move(Vector2(target.pos).direction_to(s.player_pos).orthogonal(), s.MOVE_RANGE, false): return false
		inc("combat fallback move")
	return settle()

func walk_live(destination: Vector2, label: String, radius := 22.0) -> bool:
	journal("start " + label)
	var route := PackedVector2Array()
	var stalled := 0
	var last_target := Vector2.INF
	var combat_steps := 0
	var recent := {}
	var recoveries_at_start := route_recoveries
	for step in 360:
		observe()
		if route_recoveries - recoveries_at_start > 12: return blocked(label, "navigation recovery limit")
		if step > 0 and step % 40 == 0: journal("continuing " + label + " after " + str(step) + " decisions")
		if s.player_pos.distance_to(destination) <= radius:
			journal("arrive " + label)
			return true
		if s.player_hp <= 58 and s.potions > 0 and s.request_potion(false):
			inc("travel potion")
			if not settle(): return blocked(label, "could not survive travel recovery")
			continue
		var target := threat()
		# Move between objectives while there is a lane. Answer a nearby body
		# across the travel direction only after it actually halts movement.
		if not target.is_empty() and (stalled > 0 or s.current_layer == Regions.CORE):
			var before := s.player_pos
			if not fight_step(target): return blocked(label, "combat request or survival", target)
			if before.distance_to(s.player_pos) > 4.0: route.clear()
			combat_steps += 1
			if combat_steps > 270: return blocked(label, "combat decision limit", target)
			continue
		var walls := s.walls.duplicate()
		var cell := Vector2i((s.player_pos / 8.0).round())
		recent[cell] = int(recent.get(cell, 0)) + 1
		if recent[cell] > 2:
			if not recover_from_edge(destination, recent): return blocked(label, "repeated navigation position " + str(cell))
			route.clear()
			continue
		if route.is_empty():
			route = path(s.player_pos, destination, s.current_layer, walls)
			if route.size() < 2:
				if not recover_from_edge(destination): return blocked(label, "no navigation path to " + str(destination))
				continue
			route.remove_at(0)
			route_replans += 1
		while route.size() > 1 and s.player_pos.distance_to(route[0]) <= 23.0:
			route.remove_at(0)
		var index := 0
		for i in range(route.size()):
			if not segment_clear(s.player_pos, route[i], s.current_layer, walls): break
			index = i
		var next := route[index]
		var old := s.player_pos
		if last_target != next: stalled = 0
		last_target = next
		if not s.request_move(old.direction_to(next), s.MOVE_RANGE, false):
			return blocked(label, "move request rejected toward " + str(next))
		inc("travel move")
		if not settle(): return blocked(label, "movement action failed")
		if s.player_pos.distance_to(next) < 18.0:
			for i in index + 1: route.remove_at(0)
		if old.distance_to(s.player_pos) < 2.0 or (s.player_pos.distance_to(next) > 23.0 and old.distance_to(next) <= s.player_pos.distance_to(next) + 1.0):
			stalled += 1
			route.clear()
			if threat().is_empty() and not recover_from_edge(destination): return blocked(label, "cannot recover stride toward " + str(next))
			if stalled > 3: return blocked(label, "terrain or body stalls toward " + str(next))
		else:
			stalled = 0
	return blocked(label, "total decision limit")

func recover_from_edge(destination: Vector2, recent: Dictionary = {}) -> bool:
	# Combat can finish nearer a boundary than the conservative grid margin.
	# Forecast one legal inward stride and rejoin the existing navigation grid.
	var origin := s.player_pos
	var heading := origin.direction_to(destination)
	var best: Vector2 = Vector2.ZERO
	var best_distance := INF
	for i in 12:
		var direction := heading.rotated(i * TAU / 12)
		planner.copy_from(s)
		if not planner.probe.request_move(direction): continue
		var next: Vector2 = planner.probe.player_pos
		if next.distance_to(origin) < 12: continue
		var route := path(next, destination, s.current_layer, s.walls)
		if route.size() < 2: continue
		var score := 120.0 * float(recent.get(Vector2i((next / 8.0).round()), 0))
		for j in range(1, route.size()):
			score += route[j - 1].distance_to(route[j])
		if score < best_distance:
			best = direction
			best_distance = score
	if best.is_zero_approx() or not s.request_move(best, s.MOVE_RANGE, false): return false
	inc("travel edge recovery")
	route_recoveries += 1
	return settle()

func blocked(label: String, reason: String, target: Dictionary = {}) -> bool:
	var detail := {"leg": label, "reason": reason, "position": str(s.player_pos),
		"layer": s.current_layer, "message": s.message, "hp": s.player_hp, "target": target.get("kind", ""),
		"target_hp": target.get("hp", -1), "target_pos": str(target.get("pos", Vector2.ZERO))}
	stops.append(detail)
	print("LIVE ROUTE BLOCKED ", JSON.stringify(detail))
	return false

func context(point: Vector2, label: String, expected: String, radius := 50.0) -> bool:
	if not walk_live(point, label, radius): return false
	var actual := s.interaction_label()
	if actual != expected or not s.request_context_action(): return blocked(label, "expected " + expected + ", got " + actual)
	inc("context " + actual)
	journal("used " + label)
	return settle()

func guardian(id: String, approach: Vector2) -> bool:
	if not walk_live(approach, "approach " + id, 45.0): return false
	for i in 280:
		if s.defeated_guardians.has(id):
			journal("defeated " + id)
			return true
		var boss := s._enemy_by_id(Regions.BOSS_IDS[id])
		var target := threat()
		if target.is_empty(): target = boss
		if target.is_empty() or not fight_step(target): return blocked(id, "guardian combat stopped", target)
	return blocked(id, "guardian decision limit", s._enemy_by_id(Regions.BOSS_IDS[id]))

func journey() -> bool:
	if not context(Vector2(2290, 530), "ridge stairs", "TAKE STAIRS"): return false
	if not walk_live(Vector2(2830, 760), "Windbreak west approach"): return false
	if not walk_live(Vector2(3190, 760), "pass south of the Windbreak buttress"): return false
	if not walk_live(Vector2(3680, 910), "Bell Market south lane"): return false
	if not walk_live(Vector2(4540, 910), "clear the Market buttress"): return false
	if not context(Vector2(4990, 675), "Carillon Waystone", "REST", 80.0): return false
	if not walk_live(Vector2(4050, 1450), "optional Bell lookout detour", 35.0): return false
	if not context(Vector2(4710, 1640), "freight platform commission", "OPEN LIFT", 30.0): return false
	if not context(Vector2(4710, 1640), "ride to Millrace", "RIDE LIFT", 30.0): return false
	if s.current_layer != Regions.SURFACE: return blocked("freight lift", "wrong lower layer")
	if not context(Vector2(4520, 1900), "Basin secures earned freight lift", "REST", 65.0): return false
	if not context(Vector2(4710, 1640), "earned freight lift used on return", "RIDE LIFT", 30.0): return false
	if s.current_layer != Regions.RIDGE or not s.lift_memory.freight_lift.secured: return blocked("freight lift", "wrong upper layer or unsecured return")
	if not context(Vector2(4990, 675), "return to Carillon", "REST", 80.0): return false
	if not guardian("bell_warden", Vector2(6810, 640)): return false
	if not context(Vector2(7170, 980), "counterweight bridge", "LOWER", 40.0): return false
	if not context(Vector2(8430, 2000), "gallery descent", "TAKE STAIRS", 40.0): return false
	if not context(Vector2(8170, 1900), "Lantern checkpoint", "REST", 60.0): return false
	for attempt in 3:
		if tower_attempt(): return true
		if not s.death_pending or attempt == 2: return false
		if not s.return_after_death(): return false
		retries += 1
		inc("context return at Waystone")
		journal("normal Lantern retry")
	return false

func tower_attempt() -> bool:
	if not bool(s.anchor_state.get("shortcut_states", {}).get("tower_service", false)):
		if not context(Vector2(8320, 1470), "far side of tower service stair", "UNLOCK", 26.0): return false
		if not walk_live(Vector2(8320, 1750), "earned stair used on return", 30.0): return false
		if not context(Vector2(8170, 1900), "Lantern secures stair", "REST", 60.0): return false
	if not walk_live(Vector2(8320, 1470), "secured stair used toward crown", 30.0): return false
	if not guardian("hollow_keeper", Vector2(8420, 983)): return false
	return s.campaign_victory()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	started = Time.get_ticks_msec()
	fresh(131137, args[1] if args.size() > 1 else "warrior")
	planner.short_horizon = true
	var roster := s.enemies.size()
	var sites := {}
	for area in s.areas: sites[int(area.id)] = String(area.name)
	journal("Dawn start with " + str(roster) + " populated actors")
	var won := journey()
	observe()
	var contacted := {}
	for record in engaged.values(): contacted[int(record.site)] = sites.get(int(record.site), "Dawn")
	var bypassed := {}
	for site in s.encounter_templates:
		if not contacted.has(int(site)): bypassed[int(site)] = sites.get(int(site), "Dawn")
	var result := {"victory": won, "seed": s.run_seed, "loadout": s.loadout_id, "initial_actors": roster,
		"decisions": decisions, "stops": stops, "deaths": deaths, "retries": retries, "navigation_plans": route_replans, "edge_recoveries": route_recoveries,
		"encountered_sites": contacted, "bypassed_or_unvisited_sites": bypassed, "visited_areas": visited.keys(),
		"engaged_actors": engaged, "defeated_actors_observed": defeated, "kills": s.enemies_defeated,
		"policy": "Authored waypoint route using committed strides; heal on low HP; answer movement blockers, tower encounters and guardians with the existing copy-based combat planner. Rest normally and secure/ride the freight lift before the tower.", "events": events,
		"guardians": s.defeated_guardians, "shortcut_unanchored": s.unanchored_shortcut(),
		"simulation_seconds": s.simulation_time, "elapsed_seconds": (Time.get_ticks_msec() - started) / 1000.0}
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("LIVE ROUTE RESULT victory=", won, " stops=", stops, " decisions=", decisions, " elapsed=", result.elapsed_seconds)
	quit(0 if won else 1)
