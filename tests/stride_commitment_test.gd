extends SceneTree
const State=preload("res://scripts/core/run_state.gd")
var checks=0
var failures=[]
var records=[]
func check(ok:bool,why:String):
	checks+=1
	if not ok:failures.append(why);printerr("FAILED: ",why)
func fresh(loadout:String="warrior",legacy:bool=false):
	var s=State.new(false);s.start_run(loadout,"combat_survey",223344,"encounter","energy")
	s.combat_lab=legacy;s.lab_variant="A"
	s.enemies.clear();s.walls.clear();s.barriers.clear();s.hazards.clear();s.projectiles.clear();s.world_pickups.clear();s.waystones.clear();s.transitions.clear();s._build_wall_spatial_index()
	s.player_pos=Vector2(900,800);s.world_size=Vector2(2400,1700)
	s.floor_shapes.assign([{"kind":"rect","rect":Rect2(100,100,2200,1500),"layer":s.current_layer,"part_id":0}]);s._loaded_floor_shapes.assign(s.floor_shapes);s._build_shape_spatial_index();s._update_exploration(true)
	return s
func finish(s):
	for i in 2000:
		if s.is_player_ready():return
		s.advance_streamed_action_tick()
	check(false,"finite stride")
func normal_and_comparison():
	for loadout in ["warrior","rogue_acrobat","rogue_sharpshooter","mage_elementalist"]:
		var durations=[]
		for requested in [0.0,1.0,4.0,8.0,16.0,34.0,123.0]:
			var s=fresh(loadout);var origin=s.player_pos
			check(s.begin_streamed_move(Vector2.RIGHT,requested),"normal stride accepts nearby intent")
			check(s.player_action.distance==34 and s.player_action.move_origin==origin,"full fixed unit before execution")
			finish(s);durations.append(s.simulation_time)
			check(s.player_pos.x-origin.x>=34 and s.player_pos.x-origin.x<38,"full stride including tick boundary")
		check(durations.all(func(t):return is_equal_approx(t,durations[0])),"short taps cannot alter decision frequency "+loadout)
	var a=fresh();var b=fresh("warrior",true)
	for i in 20:a.request_move(Vector2.RIGHT,4);b.request_move(Vector2.RIGHT,4)
	records.append({"scenario":"20 short requests","normal_seconds":a.simulation_time,"legacy_seconds":b.simulation_time,"normal_decisions_per_world_second":20/a.simulation_time,"legacy_decisions_per_world_second":20/b.simulation_time,"normal_decisions_per_playback_second":25/a.simulation_time,"legacy_decisions_per_playback_second":25/b.simulation_time})
	check(a.simulation_time/b.simulation_time>7.9,"short-tap inspection cadence coarsens eightfold in fixture")
	var c=fresh();var d=fresh("warrior",true)
	for i in 8:c.request_move(Vector2.RIGHT);d.request_move(Vector2.RIGHT)
	check(c.player_pos==d.player_pos and is_equal_approx(c.simulation_time,d.simulation_time),"held full-stride travel unchanged against historical control")
func collision():
	for gap in [0.0,10.0,20.0]:
		var s=fresh();s.walls.assign([Rect2(930+gap,650,20,300)]);s._build_wall_spatial_index();var origin=s.player_pos
		s.request_move(Vector2.RIGHT,1)
		var travel=s.player_pos.distance_to(origin)
		check(travel<=gap+0.05,"solid obstacle clips committed stride")
		check(is_equal_approx(s.simulation_time,16*s.SIM_DT),"clipped/blocked attempt retains full stride clock")
		records.append({"scenario":"wall","clearance":gap,"travel":travel,"world_seconds":s.simulation_time})
	for width in [100.0,50.0]:
		var s=fresh();s.walls.assign([Rect2(940,100,20,700-width/2),Rect2(940,800+width/2,20,800-width/2)]);s._build_wall_spatial_index()
		for i in 4:s.request_move(Vector2.RIGHT,1)
		check(s.player_pos.x>1000 if width==100 else s.player_pos.x<940,"doorway footprint preserved "+str(width))
		records.append({"scenario":"doorway","width":width,"final_x":s.player_pos.x,"world_seconds":s.simulation_time})
	var edge=fresh();edge.floor_shapes.assign([{"kind":"rect","rect":Rect2(100,100,850,1500),"layer":edge.current_layer,"part_id":0}]);edge._loaded_floor_shapes.assign(edge.floor_shapes);edge._build_shape_spatial_index()
	edge.request_move(Vector2.RIGHT,4);check(edge._actor_footprint_on_floor(edge.player_pos,edge.PLAYER_RADIUS) and edge.player_pos.x<934,"floor edge retains existing footprint containment")
	records.append({"scenario":"floor edge","final_x":edge.player_pos.x,"world_seconds":edge.simulation_time})
func interaction():
	var s=fresh();s.consumable_slots.assign([{"id":"","count":0},{"id":"","count":0},{"id":"","count":0}])
	var target=s.player_pos+Vector2(120,0)
	s._add_pickup({"id":"stride-supply","pos":target,"item_id":"trail_ration","count":1,"layer":s.current_layer})
	check(not s.pickup_denial(s.pickup_by_id("stride-supply")).is_empty(),"supply starts outside collection range")
	s.request_move_to(target)
	check(s.player_pos.x<target.x and s.pickup_denial(s.pickup_by_id("stride-supply")).is_empty(),"full approach enters pickup range without overshooting supply")
	var pos=s.player_pos;check(s.request_collect_pickup("stride-supply"),"successful pickup after full approach")
	check(s.player_pos==pos,"collection never becomes an arbitrary short movement")
	var near=fresh();near.consumable_slots.assign([{"id":"","count":0},{"id":"","count":0},{"id":"","count":0}])
	near._add_pickup({"id":"near-supply","pos":near.player_pos+Vector2(4,0),"item_id":"trail_ration","count":1,"layer":near.current_layer})
	pos=near.player_pos;check(near.request_collect_pickup("near-supply") and near.player_pos==pos,"nearby supply is collected in place, without stride overshoot")
	var stone=fresh();stone.waystones.assign([{"id":77,"pos":stone.player_pos+Vector2(155,0),"layer":stone.current_layer}]);stone.request_move(Vector2.RIGHT,4)
	check(not stone.nearby_waystone().is_empty(),"full approach enters Waystone interaction radius")
func _init():
	normal_and_comparison();collision();interaction()
	FileAccess.open("user://stride-commitment-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("STRIDE COMMITMENT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
