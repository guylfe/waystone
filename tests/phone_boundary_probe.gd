extends "res://tests/phone_baseline_probe.gd"
# Authored-layout comparisons and synthetic U floor. No source fixes.
func synthetic_floor(shape: String = "curved"):
	await reset_fixture("top_down")
	var s=board.state
	s.world_size=Vector2(2400,1700); s.player_pos=Vector2(900,1000)
	s.world_pickups.clear(); s.waystones.clear(); s.walls.clear(); s.barriers.clear(); s.terrain_features.clear()
	s.base_walls_by_layer={s.current_layer:[]}; s._build_wall_spatial_index()
	var floor: Array=[]
	if shape=="curved":
		for center in [Vector2(900,800),Vector2(1300,800)]: floor.append({"kind":"circle","center":center,"radius":150.0,"layer":s.current_layer,"part_id":0})
		for x in [900,1300]: floor.append({"kind":"capsule","from":Vector2(x,800),"to":Vector2(x,1050),"radius":100.0,"layer":s.current_layer,"part_id":0})
		floor.append({"kind":"capsule","from":Vector2(900,1050),"to":Vector2(1300,1050),"radius":120.0,"layer":s.current_layer,"part_id":0})
	else:
		for rect in [Rect2(750,650,300,550),Rect2(1150,650,300,550),Rect2(750,1000,700,200)]: floor.append({"kind":"rect","rect":rect,"layer":s.current_layer,"part_id":0})
	s.floor_shapes.assign(floor); s._loaded_floor_shapes.assign(floor); s.loaded_region_ids={0:true}
	s.areas.assign([{"id":0,"layer":s.current_layer,"rect":Rect2(750,650,700,550),"center":Vector2(900,1000),"name":"Synthetic U","discovered":true}])
	s.connections.clear(); s.current_area_id=0; s._build_shape_spatial_index(); s._navigation_cache.clear(); s._build_navigation()
	await sync_fixture()
func shot(pos: Vector2, vel: Vector2, owner: int = 0, elevation: float = 0.0, radius: float = 4.0):
	board.state._add_projectile({"kind":"arrow","source_id":owner,"pos":pos,"vel":vel,"radius":radius,"damage":10,"elevation":elevation,"max_range":4000.0,"layer":board.state.current_layer})
func reserve_source():
	var source=board.state._make_enemy("archer",Vector2(1300,1100),35,0)
	source.id=999; source.reserve=true
	board.state._add_enemy_actor(source)
func advance_routed(beats: int) -> Dictionary:
	var trace: Array=[]
	var outside:=false
	for i in beats:
		await touch(board.interaction_rect.get_center())
		await create_timer(0.18).timeout; await frames(2)
		for p in board.state.projectiles:
			var on: bool=board.state._point_on_floor(p.pos)
			outside=outside or not on
			trace.append({"time":board.state.simulation_time,"pos":str(p.pos),"on_floor":on,"elevation":p.elevation,"travelled":p.travelled})
	return {"trace":trace,"outside_observed":outside,"survivors":board.state.projectiles.size(),"sim_time":board.state.simulation_time}
func routed_synthetic(shape: String, owner: int, elevation: float):
	await synthetic_floor(shape)
	if owner!=0: reserve_source()
	shot(Vector2(900,800),Vector2(600,0),owner,elevation)
	board.visual=board._presentation_snapshot(); await frames()
	var data=await advance_routed(7)
	data.merge({"fixture":"synthetic "+shape+" U, connected lower passage","input":"main scene touch WAIT and automatic frames","owner":owner,"source_faction":board.state._faction_of(owner),"initial_elevation":elevation,"start":str(Vector2(900,800)),"void_point":str(Vector2(1100,800)),"void_is_floor":board.state._point_on_floor(Vector2(1100,800)),"floor_shapes":board.state.floor_shapes.duplicate(true)})
	record("routed_concave_crossing",data)
func kernel_sweep(shape: String, kind: String, owner: int, radius: float, elevation: float, dt: float, enemy_beyond: bool = false):
	await synthetic_floor(shape)
	if kind=="corridor":
		board.state.floor_shapes.append({"kind":"capsule","from":Vector2(900,800),"to":Vector2(1300,800),"radius":40.0,"layer":board.state.current_layer,"part_id":0})
		board.state._build_shape_spatial_index()
	var start:=Vector2(900,800); var finish:=Vector2(1300,800)
	if kind=="outside_endpoint": finish=Vector2(1100,800)
	if kind=="radius_graze": start=Vector2(970,800); finish=Vector2(1025,800)
	if kind=="radius_graze_small": start=Vector2(1038,800); finish=Vector2(1048,800)
	if kind=="thin_notch":
		# A two-unit void is narrower than one 600-unit/s SIM_DT step.
		board.state.floor_shapes.assign([
			{"kind":"rect","rect":Rect2(750,650,300,550),"layer":board.state.current_layer,"part_id":0},
			{"kind":"rect","rect":Rect2(1052,650,400,550),"layer":board.state.current_layer,"part_id":0},
			{"kind":"rect","rect":Rect2(750,1000,702,200),"layer":board.state.current_layer,"part_id":0}])
		board.state._build_shape_spatial_index()
		start=Vector2(1049,800); finish=Vector2(1054,800)
	var enemy: Dictionary={}
	if enemy_beyond:
		enemy=board.state._make_enemy("blade",Vector2(1280,800),35,0)
		enemy.action=board.state._action("wait",5.0,Vector2.ZERO)
		board.state._replace_enemy_actors([enemy])
	shot(start,(finish-start)/dt,owner,elevation,radius)
	if kind=="barrier_low" or kind=="barrier_high":
		reserve_source()
		# Put a low barrier inside valid authored floor for a separate control.
		board.state.floor_shapes.append({"kind":"rect","rect":Rect2(750,650,700,500),"layer":board.state.current_layer,"part_id":0}); board.state._build_shape_spatial_index()
		board.state._add_barrier({"pos":Vector2(1100,800),"axis":Vector2.DOWN,"half_length":100.0,"thickness":20.0,"hp":100,"layer":board.state.current_layer,"source_id":999,"remaining":5.0,"lowered":false})
	var hp: int=enemy.get("hp",0)
	var center_before: bool=board.state._point_on_floor(start)
	var center_after: bool=board.state._point_on_floor(finish)
	# Direct kernel probes must refresh their own spatial cache; normal ticks do this.
	board.state._build_enemy_spatial_index()
	if enemy_beyond: require(board.state._nearby_enemies(start,500).has(enemy),"far-side target is registered in spatial query")
	board.state._update_projectiles(dt)
	record("kernel_sweep",{"fixture":"synthetic "+shape+" floor","kind":kind,"direct_kernel_supplement":true,"dt":dt,"speed":start.distance_to(finish)/dt,"start":str(start),"finish":str(finish),"center_before_floor":center_before,"center_after_floor":center_after,"owner":owner,"radius":radius,"elevation":elevation,"survivors":board.state.projectiles.size(),"enemy_hp_before":hp,"enemy_hp_after":enemy.get("hp",0)})
func authored_chord():
	await reset_fixture("top_down",false)
	var s=board.state
	var from:=Vector2.ZERO; var to:=Vector2.ZERO
	for y in range(1500,3800,40):
		var last_on:=Vector2.ZERO; var off_start:=Vector2.ZERO
		for x in range(350,4400,20):
			var p:=Vector2(x,y)
			if s._point_on_floor(p):
				if off_start!=Vector2.ZERO and last_on!=Vector2.ZERO and p.distance_to(last_on)>160 and p.distance_to(last_on)<1000:
					from=last_on-Vector2(40,0); to=p+Vector2(40,0); break
				last_on=p; off_start=Vector2.ZERO
			elif last_on!=Vector2.ZERO and off_start==Vector2.ZERO: off_start=p
		if from!=Vector2.ZERO: break
	require(from!=Vector2.ZERO,"authored seed42 concave chord located")
	if from==Vector2.ZERO:return
	# Preserve actual generated map geometry; remove combat only to isolate a shot.
	s._replace_enemy_actors([]); s.player_pos=from; s.world_pickups.clear(); s.waystones.clear()
	await sync_fixture()
	var a: bool=s._point_on_floor(from); var b: bool=s._point_on_floor(to)
	shot(from,Vector2(900,0)); board.visual=board._presentation_snapshot()
	var data=await advance_routed(12)
	data.merge({"seed":42,"biome":0,"fixture":"real generated floor, synthetic projectile and relocated player, enemies removed","start":str(from),"reentry":str(to),"start_is_floor":a,"reentry_is_floor":b})
	record("authored_floor_chord",data)
func actors():
	await synthetic_floor()
	board.state.player_pos=Vector2(900,800); await sync_fixture()
	var positions: Array=[]; var events: Array=[]
	for i in 6:
		var target: Vector2=board._world_to_screen(Vector2(1200,800))
		require(board.board_rect.has_point(target),"actor destination tap in battlefield")
		events.append({"point":str(target),"in_board":board.board_rect.has_point(target),"board":str(board.board_rect),"before_kind":board.state.player_action.kind})
		await touch(target); await create_timer(0.2).timeout; await frames()
		positions.append(str(board.state.player_pos))
	record("actor_routed_walk",{"fixture":"synthetic curved U","positions":positions,"events":events,"on_floor":board.state._point_on_floor(board.state.player_pos),"input":"touch destination across gap, automatic frames"})
	# Desktop route control tests movement independently of an off-camera touch.
	var start: Vector2=board.state.player_pos
	var e:=InputEventKey.new(); e.keycode=KEY_D; e.physical_keycode=KEY_D; e.pressed=true; Input.parse_input_event(e)
	await create_timer(1.0).timeout
	e.pressed=false; Input.parse_input_event(e); await create_timer(0.3).timeout; await frames()
	record("actor_keyboard_walk_control",{"origin":str(start),"result":str(board.state.player_pos),"on_floor":board.state._point_on_floor(board.state.player_pos),"kind":board.state.player_action.kind,"sim_time":board.state.simulation_time})
	for actor_id in [0,55]:
		for delta in [Vector2(400,0),Vector2(200,0),Vector2(0,220)]:
			var origin:=Vector2(900,800)
			if actor_id!=0: board.state.player_pos=Vector2(900,1100)
			var result: Vector2=board.state._move_actor(origin,delta,24.0,actor_id,true)
			record("actor_kernel_sweep",{"fixture":"synthetic curved U","direct_kernel_supplement":true,"actor_id":actor_id,"origin":str(origin),"delta":str(delta),"result":str(result),"endpoint_on_floor":board.state._point_on_floor(result)})
func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	await setup(Vector2i(720,1280))
	for shape in ["curved","rect"]:
		for owner in [0,999]:
			for elevation in [0.0,120.0]: await routed_synthetic(shape,owner,elevation)
	for kind in ["reentry","outside_endpoint","corridor","radius_graze","radius_graze_small","thin_notch","barrier_low","barrier_high"]:
		for dt in [State.SIM_DT,0.2]:
			await kernel_sweep("curved",kind,0,60.0 if kind=="radius_graze" else 0.5 if kind=="thin_notch" else 4.0,120.0 if kind=="barrier_high" else 0.0,dt,kind=="reentry")
	await authored_chord(); await actors(); await finish()
	FileAccess.open("res://.runtime/phone-boundary-results.json",FileAccess.WRITE).store_string(JSON.stringify({"baseline":"0e65cdfae5b662a9a8951a8ff082ff54c639a7e1","rows":rows,"harness_errors":errors},"\t"))
	print("BOUNDARY DONE ",rows.size()," records ",errors.size()," harness errors")
	quit(0 if errors.is_empty() else 2)
