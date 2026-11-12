extends SceneTree
const State=preload("res://scripts/core/run_state.gd")
const Board=preload("res://scripts/presentation/game_board.gd")
const Pad=preload("res://scripts/presentation/controller_input.gd")
var failures=[]
var checks=0
var records=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures.append(label);printerr("FAILED: ",label)
func fresh(frame:String="sword",rules:String="energy"):
	var s=State.new(false)
	s.start_run("rogue_sharpshooter" if frame=="bow" else "rogue_acrobat" if frame in ["knife","twin_knives"] else "mage_elementalist" if frame=="staff" else "warrior","combat_survey",112233,"encounter",rules)
	s.player_weapon_frame=frame
	s.enemies.clear();s.walls.clear();s.barriers.clear();s.hazards.clear();s.projectiles.clear();s._build_wall_spatial_index()
	s.player_pos=Vector2(900,800);s.world_size=Vector2(2400,1700)
	s.floor_shapes.assign([{"kind":"rect","rect":Rect2(100,100,2200,1500),"layer":s.current_layer,"part_id":0}]);s._loaded_floor_shapes.assign(s.floor_shapes);s._build_shape_spatial_index()
	var target=s._make_enemy("blade",Vector2(1200,800),10000)
	target.layer=s.current_layer;target.awareness="alerted";target.revealed_to_player=true;target.action=s._action("wait",1000,Vector2.LEFT)
	target.posture=10000;target.posture_max=10000
	s._replace_enemy_actors([target]);s._update_exploration(true)
	return s
func finish(s)->int:
	var reached=0
	for i in 2000:
		reached=maxi(reached,int(s.player_action.get("committed_phase",-1))+1)
		if s.is_player_ready():return reached
		s.advance_streamed_action_tick()
	check(false,"finite commitment");return reached
func melee():
	for frame in ["sword","knife","twin_knives","staff"]:
		for rules in ["energy","recovery"]:
			var s=fresh(frame,rules);s.request_combo(Vector2.RIGHT,false,true)
			s.set_attack_hold(true);check(not s.resume_combo_hold(),"live continuation unavailable "+frame)
			check(finish(s)==1,"held ordinary attack is one complete cut "+frame+rules)
			var single_time=s.simulation_time
			var c=fresh(frame,rules);var spent=c.energy_spent_total
			check(c.request_commit_combo(int(c.enemies[0].id),false),"explicit full combo starts "+frame)
			var cost=c.energy_cost(c.full_combo_raw_cost()) if rules=="energy" else 0.0
			check(is_equal_approx(c.energy_spent_total-spent,cost),"full sequence prepaid "+frame)
			check(c.player_control_world_remaining()>single_time,"full recovery owed from initial commit "+frame)
			c.set_attack_hold(false)
			var count=c.player_action.phases.size()
			check(c.save_run("user://decision-commit.save"),"save full commitment")
			var loaded=State.new(false);check(loaded.load_run("user://decision-commit.save"),"load full commitment")
			check(loaded.is_player_ready(),"ordinary Survey retains ready-on-load policy")
			check(finish(c)==count,"release preserves every prepaid cut "+frame)
			check(is_equal_approx(c.energy_spent_total-spent,cost),"no link debit "+frame)
			check(is_equal_approx(c.energy_spent_total,loaded.energy_spent_total),"save retains prepayment "+frame)
			records.append({"frame":frame,"rules":rules,"single":single_time,"combo":c.simulation_time,"cuts":count,"cost":cost})
			var low=fresh(frame,rules);low.player_energy=1
			check(low.request_commit_combo(int(low.enemies[0].id),false),"permitted full-cost overdraw "+frame)
			check(finish(low)==count,"overdraw cannot truncate prepaid combo "+frame)
func bow():
	for strong in [false,true]:
		for rules in ["energy","recovery"]:
			var a=fresh("bow",rules);var b=fresh("bow",rules)
			for s in [a,b]:
				check(s.request_commit_shot(int(s.enemies[0].id),false) if strong else s.begin_bow_draw(Vector2.RIGHT,int(s.enemies[0].id)),"bow commits")
			var before=b.player_action.aim_direction
			for i in 20:b.set_bow_aim(Vector2.DOWN)
			check(b.player_action.aim_direction==before,"execution input grants no turn")
			check(not b.release_bow_attack(Vector2.UP),"release cannot shorten draw")
			var spent=b.energy_spent_total
			check(b.save_run("user://decision-bow.save"),"save automatic draw")
			var loaded=State.new(false);check(loaded.load_run("user://decision-bow.save"),"load automatic draw")
			finish(a);finish(b);finish(loaded)
			check(a.survey_shots_fired==1 and b.survey_shots_fired==1 and loaded.survey_shots_fired==0,"one arrow; ordinary ready-on-load does not replay")
			check(a.projectiles==b.projectiles,"input and save do not change projectile")
			check(is_equal_approx(spent,b.energy_spent_total),"release never repays")
			records.append({"strong":strong,"rules":rules,"time":a.simulation_time,"spent":spent})
func input_routes():
	var b=Board.new();b.state=fresh();b.desktop_controls=true
	b._select_commit_shot("keyboard")
	check(b.selected_action=="commit_shot","keyboard selects full combo while frozen")
	var t=b.state.simulation_time
	b._cancel_commit_shot_selection();check(b.state.simulation_time==t and b.selected_action=="","cancel remains free")
	b._select_commit_shot("pointer")
	check(b._confirm_commit_shot(int(b.state.enemies[0].id)),"pointer target confirms authored combo")
	check(not b.attack_key_held and not b.attack_pointer_held and not b.controller.attack_held,"full commit owns no repeats")
	b.free()
	var p=Board.new();p.state=fresh("staff");p.controller.palette_button(p,JOY_BUTTON_LEFT_STICK)
	check(p.selected_action=="commit_shot" and p.controller.targeting_action=="commit_shot","pad LB+LS routes full Staff commit")
	p.free()
func movement():
	for distance in [4.0,8.0,16.0,34.0]:
		var s=fresh();s.enemies.clear();var start=s.player_pos;s.request_move(Vector2.UP,distance)
		records.append({"movement_requested":distance,"travel":s.player_pos.distance_to(start),"world_time":s.simulation_time,"wall_time_125":s.simulation_time/1.25})
func _init():
	melee();bow();input_routes();movement()
	check(State.SIM_DT==1.0/120.0 and State.EXECUTION_PLAYBACK_RATE==1.25,"unchanged simulation with universal playback")
	FileAccess.open("user://decision-commit-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("DECISION COMMIT ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
