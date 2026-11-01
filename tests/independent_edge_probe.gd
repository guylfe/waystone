extends SceneTree
const State=preload("res://scripts/core/run_state.gd")
const Boundary=preload("res://scripts/core/floor_boundary.gd")
var rows=[]
func _init(): call_deferred("run")
func report(id,ok,data={}):
	data.merge({"id":id,"passed":ok}); rows.append(data); print("EDGE ",JSON.stringify(data))
func shape(rect,layer="edge"):
	return {"kind":"rect","rect":rect,"layer":layer,"part_id":0}
func fresh(kind="rect",loadout="warrior"):
	var s=State.new(false); s.start_run(loadout,"expedition",42)
	s.current_layer="edge"; s.world_size=Vector2(2400,1700); s.player_pos=Vector2(900,800)
	s._replace_enemy_actors([]); s.walls.clear(); s.barriers.clear(); s.hazards.clear(); s.projectiles.clear(); s.world_pickups.clear(); s.waystones.clear(); s.terrain_features.clear()
	s.base_walls_by_layer={"edge":[]}; s.loaded_region_ids={0:true}; s.current_area_id=0
	var f=[]
	if kind=="circle": f=[{"kind":"circle","center":Vector2(900,800),"radius":200.0,"layer":"edge","part_id":0}]
	else: f=[shape(Rect2(750,650,300,550)),shape(Rect2(1150,650,300,550)),shape(Rect2(750,1000,700,200))]
	s.floor_shapes.assign(f); s._loaded_floor_shapes.assign(f)
	s.areas.assign([{"id":0,"layer":"edge","rect":Rect2(750,650,700,550),"center":Vector2(900,1000),"name":"Independent U","discovered":true}]); s.connections.clear()
	s._build_shape_spatial_index(); s._build_wall_spatial_index()
	return s
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for kind in ["rect","circle"]:
		var s=fresh(kind)
		var p=Vector2(1050.0-State.PLAYER_RADIUS*0.72,800) if kind=="rect" else Vector2(900+200-State.PLAYER_RADIUS*0.72,800)
		for delta in [Vector2(-4,0),Vector2(-4,-4),Vector2(0,4),Vector2(4,0)]:
			var result=s._move_actor(p,delta,State.PLAYER_RADIUS,0,true)
			var inward=delta.x<0
			report("tangent_"+kind+str(delta),result.x<p.x if inward else result.x<=p.x,{"kind":"direct movement kernel","origin":str(p),"delta":str(delta),"result":str(result)})
		# Normal committed move from exact tangent; setup is synthetic.
		s.player_pos=p; var accepted=s.request_move(Vector2.LEFT,32,true)
		report("tangent_normal_move_"+kind,accepted and s.player_pos.x<p.x,{"origin":str(p),"result":str(s.player_pos),"accepted":accepted,"sim_time":s.simulation_time})
	# Legacy diagonal near-edge overlap, both normal inward and outward controls.
	for direction in [Vector2(-1,-1),Vector2(1,1)]:
		var s=fresh("circle"); var p=Vector2(1030,930); s.player_pos=p
		var cardinal=s._actor_footprint_on_floor(p,24)
		var accepted=s.request_move(direction,32,true)
		report("legacy_normal_move"+str(direction),cardinal and accepted and (s.player_pos.distance_to(Vector2(900,800))<p.distance_to(Vector2(900,800)) if direction.x<0 else s.player_pos==p),{"cardinal_valid":cardinal,"origin":str(p),"result":str(s.player_pos)})
	for route in ["move","vault","windstep","gale","charge"]:
		for corridor in [false,true]:
			var s=fresh("rect","rogue_acrobat" if route=="vault" else "mage_elementalist" if route=="windstep" else "warrior")
			if corridor:
				s.floor_shapes.append(shape(Rect2(750,650,700,550))); s._loaded_floor_shapes.assign(s.floor_shapes);s._build_shape_spatial_index()
			s.player_pos=Vector2(1020,800);var origin=s.player_pos;var accepted=true;var mode="normal public action and fixed simulation ticks"
			if route=="move":accepted=s.request_move(Vector2.RIGHT,100,true)
			elif route=="vault":accepted=s.request_vault(Vector2.RIGHT,true)
			elif route=="windstep":s.player_spells.append("windstep");accepted=s.request_spell("windstep",Vector2(1400,800),true)
			elif route=="gale":s.player_gale_velocity=Vector2(1200,0);s._update_gale_drift(0.25);mode="direct drift consumer; synthetic impulse and dt"
			else:
				var e=s._make_enemy("boar",origin,100,0); e.id=999;e.layer="edge";s._replace_enemy_actors([e]);s.player_pos=Vector2(900,1100)
				var moved=s._move_charging_actor(e,origin,Vector2(300,0),{"ally_collision":"gore"},true);s.player_pos=moved.position;mode="direct charge consumer; synthetic large delta"
			report("route_"+route+"_corridor"+str(corridor),accepted and (s.player_pos.x>1050 if corridor else s.player_pos.x<1050),{"origin":str(origin),"result":str(s.player_pos),"accepted":accepted,"route_kind":mode,"corridor":corridor,"time":s.simulation_time})
	for corridor in [false,true]:
		var advanced=fresh();advanced.player_pos=Vector2(1020,800)
		if corridor:advanced.floor_shapes.append(shape(Rect2(750,650,700,550)));advanced._loaded_floor_shapes.assign(advanced.floor_shapes);advanced._build_shape_spatial_index()
		var target=advanced._make_enemy("blade",Vector2(1240,800),1000,0);target.layer="edge";target.action=advanced._action("wait",5,Vector2.ZERO);advanced._replace_enemy_actors([target])
		var accepted=advanced.request_advance(Vector2.RIGHT,false,true)
		report("normal_advance_corridor"+str(corridor),accepted and (advanced.player_pos.x>1050 if corridor else advanced.player_pos.x<1050),{"accepted":accepted,"result":str(advanced.player_pos),"time":advanced.simulation_time,"route_kind":"public action with synthetic target and fixed ticks"})
		for mode in ["windstep","gale"]:
			var state=fresh();state.player_pos=Vector2(900,1100)
			if corridor:state.floor_shapes.append(shape(Rect2(750,650,700,550)));state._loaded_floor_shapes.assign(state.floor_shapes);state._build_shape_spatial_index()
			var enemy=state._make_enemy("air_caster",Vector2(1020,800),1000,0);enemy.layer="edge";enemy.id=999
			if mode=="windstep":enemy.action=state._enemy_ability_action("windstep",Vector2.RIGHT);enemy.action.elapsed=0.26
			else:enemy.gale_velocity=Vector2(1200,0)
			state._replace_enemy_actors([enemy])
			if mode=="windstep":state._update_enemies(0.1)
			else:state._update_gale_drift(0.25)
			report("enemy_"+mode+"_corridor"+str(corridor),enemy.pos.x>1050 if corridor else enemy.pos.x<1050,{"result":str(enemy.pos),"route_kind":"direct enemy update; synthetic action or impulse and dt"})
	var s=fresh();var a=Vector2(900,800);var b=Vector2(1300,800)
	report("cache_initial_gap",s._floor_boundary_hit(a,b,4)!=INF)
	s.floor_shapes.append(shape(Rect2(750,650,700,550)));s._loaded_floor_shapes.assign(s.floor_shapes);s._build_shape_spatial_index()
	report("cache_map_rebuild_corridor",s._floor_boundary_hit(a,b,4)==INF)
	s.floor_shapes.append(shape(Rect2(750,650,300,550),"other"));s._build_shape_spatial_index();s.current_layer="other"
	report("cache_layer_gap",s._floor_boundary_hit(a,b,4)!=INF)
	s.current_layer="edge";report("cache_layer_return_corridor",s._floor_boundary_hit(a,b,4)==INF)
	# Real generated maps and save/load, avoiding synthetic layer migration assumptions.
	s=State.new(false);s.start_run("warrior","expedition",42);var p=s.player_pos
	var h=s._floor_boundary_hit(p,p+Vector2(20,0),4);s.save_run("user://edge-cache.save")
	var loaded=State.new(false);var loaded_ok=loaded.load_run("user://edge-cache.save")
	report("cache_reload",loaded_ok and loaded._floor_boundary_hit(p,p+Vector2(20,0),4)==h,{"loaded":loaded_ok})
	s.start_run("warrior","expedition",717)
	var control=State.new(false);control.start_run("warrior","expedition",717)
	p=s.player_pos
	report("cache_new_run",s._floor_boundary_hit(p,p+Vector2(250,0),4)==control._floor_boundary_hit(p,p+Vector2(250,0),4))
	FileAccess.open("res://.runtime/independent-edge-results.json",FileAccess.WRITE).store_string(JSON.stringify({"sha":"1660a840da567062b3f0211e463f2bbf7fc2e23c","rows":rows},"\t"))
	quit()

