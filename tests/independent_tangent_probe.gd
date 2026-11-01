extends SceneTree
const State=preload("res://scripts/core/run_state.gd")
var rows=[]
func _init():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for kind in ["rect","circle"]:
		for inset in [-0.01,0.0,0.0001,0.001,0.01,1.0]:
			var s=State.new(false);s.start_run("warrior","expedition",42)
			s._replace_enemy_actors([]);s.walls.clear();s.world_pickups.clear();s.waystones.clear();s.terrain_features.clear();s.current_layer="tangent";s.world_size=Vector2(2400,1700)
			var f=[{"kind":"rect","rect":Rect2(750,650,300,550),"layer":"tangent","part_id":0}] if kind=="rect" else [{"kind":"circle","center":Vector2(900,800),"radius":200.0,"layer":"tangent","part_id":0}]
			s.floor_shapes.assign(f);s._loaded_floor_shapes.assign(f);s.loaded_region_ids={0:true};s.base_walls_by_layer={"tangent":[]};s._build_shape_spatial_index();s._build_wall_spatial_index()
			var p=Vector2((1050 if kind=="rect" else 1100)-State.PLAYER_RADIUS*0.72-inset,800)
			s.player_pos=p
			var valid=s._actor_footprint_on_floor(p,State.PLAYER_RADIUS)
			var direct=s._move_actor(p,Vector2(-4,0),State.PLAYER_RADIUS,0,true)
			var accepted=s.request_move(Vector2.LEFT,32,true)
			var row={"kind":kind,"inset":inset,"origin":str(p),"cardinal_valid":valid,"direct":str(direct),"accepted":accepted,"result":str(s.player_pos),"time":s.simulation_time,"moves_inward":s.player_pos.x<p.x}
			rows.append(row);print("TANGENT ",JSON.stringify(row))
	FileAccess.open("res://.runtime/independent-tangent-results.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"));quit()
