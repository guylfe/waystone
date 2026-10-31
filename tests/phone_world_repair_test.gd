extends SceneTree
# Synthetic fixtures through the ordinary main-scene input route. No personal save.
const State = preload("res://scripts/core/run_state.gd")
var failures: Array[String] = []
var checks := 0
var board
var view: SubViewport

func _init(): call_deferred("run")
func check(ok: bool, why: String):
	checks += 1
	print("PASS: " if ok else "FAILED: ", why)
	if not ok: failures.append(why)
func frames(n := 2):
	for i in n: await process_frame
func touch(point: Vector2):
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = 0
		event.pressed = down
		view.push_input(event, true)
	await frames()
func sync_board():
	board.playing = false
	board.streaming_action = false
	board.pointer_down = false
	board.state.player_action = board.state._idle_action()
	board.state._update_exploration(true)
	board.visual = board._presentation_snapshot()
	board._layout()
	await frames()
func pickup(id: String, pos: Vector2, item := "trail_ration") -> Dictionary:
	return {"id":id, "pos":pos, "item_id":item, "count":1, "layer":board.state.current_layer, "guard_site":-1}
func has_pickup(id: String) -> bool:
	return board.state.world_pickups.any(func(p): return p.id == id)
func test_input():
	view = SubViewport.new()
	view.size = Vector2i(720, 1280)
	root.add_child(view)
	board = load("res://scenes/main.tscn").instantiate()
	view.add_child(board)
	await frames()
	board.set_process(false) # Fixtures retain exact pending action; ordinary GUI routing remains on.
	board.state.start_run("warrior", "expedition", 717)
	board.state._replace_enemy_actors([])
	board.state.player_pos = Vector2(5200, 2200)
	board.state.current_area_id = 20
	board.state._refresh_loaded_region_content()
	board.state.consumable_slots = board.state._empty_consumable_slots()
	for projection in ["top_down", "isometric"]:
		board.view_mode = projection
		board.state.world_pickups.assign([pickup("first",board.state.player_pos+Vector2(-65,0)),pickup("selected",board.state.player_pos+Vector2(65,0),"firebomb")])
		await sync_board()
		await touch(board._world_to_screen(board.state.world_pickups[1].pos))
		check(has_pickup("first") and not has_pickup("selected"), projection+" tap collects selected ID, not first nearby")
		board.state.pending_pickup.clear()
		board.state.consumable_slots = board.state._empty_consumable_slots()
	# Compressed isometric depth lets two tap targets overlap although only one is in world reach.
	board.view_mode = "isometric"
	board.state.world_pickups.assign([pickup("near",board.state.player_pos+Vector2(20,20)),pickup("far",board.state.player_pos+Vector2(95,95))])
	await sync_board()
	var near_screen: Vector2 = board._world_to_screen(board.state.world_pickups[0].pos)
	var far_screen: Vector2 = board._world_to_screen(board.state.world_pickups[1].pos)
	print("OVERLAP screen_gap=",near_screen.distance_to(far_screen)," hit_radius=",maxf(34,38*board.world_scale)," far_world=",Vector2(95,95).length())
	await touch(near_screen)
	check(not has_pickup("near") and has_pickup("far"), "exact near marker wins overlapping far marker")
	board.state.world_pickups.assign([pickup("undiscovered",board.state.player_pos+Vector2(65,65)),pickup("visible",board.state.player_pos+Vector2(20,20))])
	await sync_board()
	board.visual.discovered_cells={board.state._visibility_cell(board.state.world_pickups[1].pos):true}
	await touch(board._world_to_screen(board.state.world_pickups[0].pos))
	check(not has_pickup("visible") and has_pickup("undiscovered"),"undiscovered marker cannot steal a visible marker's touch area")
	# Displayed positions may be stale; the tapped ID must be revalidated live.
	board.state.world_pickups.assign([pickup("stale",board.state.player_pos)])
	await sync_board()
	board.state.world_pickups[0].pos += Vector2(300,0)
	await touch(board._world_to_screen(board.state.player_pos))
	check(has_pickup("stale"), "stale snapshot cannot bypass live distance")
	check(board.state.message.contains("closer"), "stale snapshot explains live distance denial")
	board.state.world_pickups.assign([pickup("guarded",board.state.player_pos)])
	board.state.world_pickups[0].guard_site = 6
	var guard = board.state._make_enemy("blade", board.state.player_pos+Vector2(400,0),99,6)
	guard.layer = board.state.current_layer
	board.state._replace_enemy_actors([guard])
	await sync_board()
	await touch(board._world_to_screen(board.state.player_pos))
	check(has_pickup("guarded") and board.state.message.contains("guard"), "guarded supply denies with guard reason")
	board.state._replace_enemy_actors([])
	board.state.world_pickups.clear()
	board.state.player_pos = board.state.expedition_markers.merchant
	board.state.current_area_id = 21
	board.state._refresh_loaded_region_content()
	await sync_board()
	await touch(board._world_to_screen(board.state.player_pos))
	check(is_instance_valid(board.expedition_dialog) and board.expedition_dialog.visible, "merchant marker tap opens ordinary shop")
	if is_instance_valid(board.expedition_dialog): board.expedition_dialog.hide()
	var threat = board.state._make_enemy("blade",board.state.player_pos+Vector2(300,0),100,21)
	threat.layer = board.state.current_layer
	board.state._replace_enemy_actors([threat])
	await sync_board()
	await touch(board._world_to_screen(board.state.player_pos))
	check(board.state.message.contains("enem"), "near merchant explains threat rather than distance")
	view.queue_free()
	await frames()

func fixture(shapes: Array) -> State:
	var s = State.new(false)
	s.start_run("warrior", "expedition", 717)
	s.world_size = Vector2(2000, 1200)
	s.current_layer = "fixture"
	s.floor_shapes.assign(shapes)
	s.walls.clear()
	s.loaded_region_ids = {0:true}
	s._loaded_floor_shapes.assign(shapes)
	s._build_shape_spatial_index()
	s._build_wall_spatial_index()
	s._replace_enemy_actors([])
	s.player_pos = Vector2(180, 500)
	return s
func rect_shape(rect: Rect2) -> Dictionary:
	return {"kind":"rect", "rect":rect, "layer":"fixture", "part_id":0}
func u_shapes() -> Array:
	return [rect_shape(Rect2(100,100,200,500)),rect_shape(Rect2(500,100,200,500)),rect_shape(Rect2(100,500,600,100))]
func shot(s, pos: Vector2, vel: Vector2, source := 0, high := false):
	s._add_projectile({"pos":pos,"vel":vel,"radius":8.0,"damage":10,"posture":0.0,"source_id":source,"friendly":source==0,"layer":"fixture","kind":"javelin" if high else "player_arrow","travelled":100.0 if high else 0.0,"max_range":10000.0,"elevation_profile":"arc" if high else "flat","arc_span":1000.0,"elevation_peak":100.0,"misdirected":false})
func target(s, pos: Vector2, id: int) -> Dictionary:
	var e = s._make_enemy("blade",pos,100,id)
	e.layer = "fixture"
	return e
func test_floor():
	for source in [0, 101]:
		for high in [false,true]:
			var s = fixture(u_shapes())
			shot(s,Vector2(200,200),Vector2(400,0),source,high)
			s._update_projectiles(1.0)
			check(s.projectiles.is_empty(),"swept concave exit/reentry blocked source=%d high=%s" % [source, high])
	var s = fixture(u_shapes())
	shot(s,Vector2(291,200),Vector2(900,0))
	s._update_projectiles(State.SIM_DT)
	check(s.projectiles.is_empty(),"normal tick blocks radius before center leaves floor")
	s = fixture(u_shapes())
	var before = target(s,Vector2(260,200),102)
	var beyond = target(s,Vector2(600,200),103)
	s._replace_enemy_actors([before,beyond])
	shot(s,Vector2(200,200),Vector2(400,0))
	s._update_projectiles(1.0)
	check(int(before.hp)<100 and int(beyond.hp)==100,"first actor before floor edge hits; actor beyond stays untouched")
	s = fixture(u_shapes())
	beyond = target(s,Vector2(600,200),103)
	s._replace_enemy_actors([beyond])
	shot(s,Vector2(200,200),Vector2(400,0))
	s._update_projectiles(1.0)
	check(int(beyond.hp)==100,"floor edge resolves before actor beyond reentry")
	for actor_id in [0, 101]:
		s = fixture(u_shapes())
		var finish: Vector2 = s._move_actor(Vector2(200,200),Vector2(400,0),24,actor_id,true)
		check(finish.x < 300,"actor swept floor blocking actor=%d" % actor_id)
	s = fixture(u_shapes())
	check(s._move_vault_actor(Vector2(200,200),Vector2(400,0)).x < 300,"vault cannot cross void")
	s = fixture(u_shapes())
	shot(s,Vector2(200,550),Vector2(400,0))
	s._update_projectiles(1.0)
	check(s.projectiles.size()==1,"connected rect seams stay traversable")
	s = fixture([{"kind":"circle","center":Vector2(300,400),"radius":250.0,"part_id":0,"layer":"fixture"},{"kind":"circle","center":Vector2(700,400),"radius":250.0,"part_id":0,"layer":"fixture"}])
	shot(s,Vector2(300,200),Vector2(400,0))
	s._update_projectiles(1.0)
	check(s.projectiles.is_empty(),"curved concave boundary blocks exit/reentry")

func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	await test_input()
	test_floor()
	print("PHONE_WORLD_REPAIR checks=%d failures=%d" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
