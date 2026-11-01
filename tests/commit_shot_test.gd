extends SceneTree
# Synthetic isolated arenas/progression; shared public action executor, not earned play.
const State=preload("res://scripts/core/run_state.gd")
const Frame=preload("res://scripts/presentation/presentation_frame.gd")
const Boundary=preload("res://scripts/core/floor_boundary.gd")
var checks=0
var failures=[]
var records=[]
func check(ok:bool,why:String):
	checks+=1
	if not ok: failures.append(why);printerr("FAILED: ",why)
func fresh(rules:String="energy",rank:int=0,integrated:bool=false):
	var s=State.new(false);s.start_run("rogue_sharpshooter","combat_survey",101010,"encounter",rules,false,load("res://scripts/core/survey_experiment.gd").defaults() if integrated else {})
	s.walls.clear();s.barriers.clear();s.hazards.clear();s.projectiles.clear();s._build_wall_spatial_index()
	s.player_pos=Vector2(900,800);s.world_size=Vector2(2400,1700)
	s.floor_shapes.assign([{"kind":"rect","rect":Rect2(100,100,2200,1500),"layer":s.current_layer,"part_id":0}]);s._loaded_floor_shapes.assign(s.floor_shapes);s._build_shape_spatial_index()
	s.track_ranks["bow"]=rank
	var target=s._make_enemy("blade",s.player_pos+Vector2(300,0),10000)
	target.layer=s.current_layer;target.awareness="alerted";target.revealed_to_player=true;target.action=s._action("wait",1000,Vector2.LEFT)
	target.facing=Vector2.LEFT;target.last_known_player=s.player_pos
	target.properties.hit_reaction_policy="posture_only";target.posture=10000;target.posture_max=10000
	s._replace_enemy_actors([target]);s._update_exploration(true)
	return s
func target_id(s)->int:return int(s.enemies[0].id)
func ticks(s,until:String="ready"):
	for i in 4000:
		if (s.is_player_ready() if until=="ready" else str(s.player_action.kind)==until):return
		if not s.advance_streamed_action_tick():break
	check(false,"finite action completion "+until)
func ordinary(s,ratio:float)->Dictionary:
	check(s.begin_bow_draw(Vector2.RIGHT,target_id(s)),"ordinary draw remains available")
	for i in 500:
		if float(s.player_action.elapsed)>=ratio*0.90:break
		s.advance_streamed_action_tick()
	check(s.release_bow_attack(),"ordinary release remains available")
	return s.player_action.duplicate(true)
func run_case(rules:String,rank:int):
	var ordinary_state=fresh(rules,rank);var normal=ordinary(ordinary_state,1.0)
	var s=fresh(rules,rank);var start=s.simulation_time;var spent=s.energy_spent_total
	check(s.request_commit_shot(target_id(s),false),"commit starts "+rules+str(rank))
	check(s.player_action.kind=="bow_draw" and s.player_action.commit_shot,"shared draw is committed")
	check(is_equal_approx(s.simulation_time,start),"request does not secretly simulate")
	check(is_equal_approx(s.energy_spent_total-spent,s.energy_cost(18.0) if rules=="energy" else 0.0),"one ordinary full price up front")
	check(not s.release_bow_attack(Vector2.UP),"early release cannot cancel or aim-jump")
	check(Vector2(s.player_action.aim_direction).is_equal_approx(Vector2.RIGHT),"release cannot silently change committed aim")
	check(not s.request_commit_shot(target_id(s),false),"duplicate commitment rejected")
	var snapshot=s.snapshot();var frame=Frame.new();var captured=frame.capture(s)
	check(snapshot.player_action.commit_shot and captured.player_action.commit_shot,"snapshot and presentation retain new optional flag")
	snapshot.player_action.commit_shot=false;captured.player_action.commit_shot=false
	check(s.player_action.commit_shot,"copies cannot mutate source commitment")
	check(s.RuntimeSchemaScript.validate("action",s.player_action).is_empty(),"action schema remains valid")
	ticks(s,"bow_release");var release=s.player_action.duplicate(true)
	check(release.projectile_damage==roundi(float(normal.projectile_damage)*1.25),"exactly one rounded 25 percent damage construction")
	for key in ["projectile_posture","projectile_speed","projectile_range","duration","startup","full_draw","draw_ratio"]:
		check(release[key]==normal[key],"ordinary full property unchanged "+key+rules+str(rank))
	check(is_equal_approx(s.energy_spent_total-spent,s.energy_cost(18.0) if rules=="energy" else 0.0),"release does not debit again")
	ticks(s)
	check(s.survey_shots_fired==1,"one arrow after full draw/recovery")
	check(s.is_player_ready(),"recovery finishes")
	var end=s.simulation_time;s.advance_streamed_action_tick()
	check(s.simulation_time==end and s.survey_shots_fired==1,"ready state cannot queue extra shot")
	records.append({"rules":rules,"rank_fixture":rank,"ordinary_full":normal,"commit_release":release,"energy_spent":s.energy_spent_total-spent,"world_duration":s.simulation_time-start,"shots":s.survey_shots_fired})
func controls(rules:String):
	for fraction in [0.0,0.5,1.0]:
		var s=fresh(rules);var a=ordinary(s,fraction)
		check(not a.commit_shot,"ordinary quick/partial/full never gain bonus")
		check(a.projectile_damage<=13,"ordinary damage curve unchanged")
	for art in ["bow_piercing_shot","bow_fan_shot"]:
		var s=fresh(rules);s.player_equipped_weapon_art=art
		check(s.request_skill(Vector2.RIGHT,false),"learned art remains separate "+art)
		for i in 1000:
			if not s.projectiles.is_empty():break
			s.advance_streamed_action_tick()
		check(s.projectiles.size()==(1 if art=="bow_piercing_shot" else 3),"art retains authored projectile count")
		check(not s.player_action.get("commit_shot",false),"art does not inherit bonus")
		check(s.projectiles.all(func(p):return int(p.damage)==22 if art=="bow_piercing_shot" else int(p.damage)==6),"art projectile values unchanged")
	var aimed=fresh(rules);check(aimed.request_take_aim(target_id(aimed),false),"Take Aim is separate")
	ticks(aimed);check(aimed.aimed_enemy_id==target_id(aimed),"Take Aim preparation retained")
	check(aimed.request_commit_shot(target_id(aimed),false),"Commit Shot after Take Aim")
	ticks(aimed)
	var unprepared=fresh(rules);unprepared.request_commit_shot(target_id(unprepared),false);ticks(unprepared)
	records.append({"fixture":"Take Aim control","rules":rules,"aimed_damage":aimed.damage_dealt,"ordinary_commit_damage":unprepared.damage_dealt,"aimed_id_after":aimed.aimed_enemy_id,"aimed_remaining":aimed.aimed_remaining,"shots_hit":aimed.survey_shots_hit,"time":aimed.simulation_time})
	check(aimed.damage_dealt>unprepared.damage_dealt and aimed.aimed_enemy_id==-1,"Take Aim adds its existing bonus once and is consumed")
	var low=fresh(rules);low.player_energy=1
	check(low.request_commit_shot(target_id(low),false),"low energy follows permitted ordinary overdraw")
	ticks(low)
	check(low.survey_shots_fired==1,"upfront exhaustion does not erase paid shot")
	check(is_equal_approx(low.energy_spent_total,low.energy_cost(18)) if rules=="energy" else low.energy_spent_total==0,"low-energy debit exactly once")
	if rules=="energy":check(low.overexertion_count==1,"exhaustion after full shot exactly once")
	var zero=fresh(rules);zero.player_energy=0
	check(zero.request_commit_shot(target_id(zero),false)==(rules=="recovery"),"zero follows ordinary physical lock, no new hard insufficient-price gate")
	var lost=fresh(rules);check(lost.request_commit_shot(target_id(lost),false),"loss fixture commits")
	var aim=lost.player_action.aim_direction;lost._replace_enemy_actors([])
	ticks(lost,"bow_release");check(lost.player_action.direction.is_equal_approx(aim),"target loss retains last ordinary aim")
	ticks(lost);check(lost.survey_shots_fired==1,"target loss still pays full shot/recovery")
	var hit=fresh(rules);check(hit.request_commit_shot(target_id(hit),false),"interrupt fixture commits")
	hit._resolve_incoming_hit(-1,5,"synthetic interrupt",hit.player_pos+Vector2.LEFT*50,hit.player_pos,50.0)
	check(hit.player_action.kind in ["stagger","hit_reaction"],"ordinary incoming posture interruption applies, no hyperarmor")
	ticks(hit);check(hit.survey_shots_fired==0,"interrupted draw cannot shoot later")
	var dead=fresh(rules);dead.request_commit_shot(target_id(dead),false);dead._resolve_incoming_hit(-1,10000,"synthetic death",dead.player_pos,dead.player_pos,50)
	check(dead.player_hp<=0 and dead.survey_shots_fired==0,"death cancels through ordinary owner")
	var follow=fresh(rules,5);follow.bow_followup_ready=true
	check(follow.request_commit_shot(target_id(follow),false),"earned follow-up may begin committed draw")
	check(is_equal_approx(float(follow.player_action.elapsed),0.45) and not follow.bow_followup_ready and follow.bow_followup_consumed,"shared preload consumed once")
	ticks(follow);check(not follow.bow_followup_ready,"accelerated follow-up cannot re-earn another")
	var reward=fresh(rules,5);reward.request_commit_shot(target_id(reward),false);ticks(reward)
	check(reward.bow_followup_ready,"normal full-hit follow-up reward retained")
	var denied=fresh(rules);var cost=denied.energy_spent_total
	check(not denied.request_commit_shot(-1,false),"invalid target rejected")
	denied.enemies[0].layer="elsewhere";check(not denied.request_commit_shot(target_id(denied),false),"wrong layer rejected")
	check(denied.energy_spent_total==cost and denied.simulation_time==0,"invalid confirmation never spends or simulates")
	var persisted=fresh(rules,3);persisted.carried_xp=800;persisted.player_weapon_art_library.assign(["bow_fan_shot"]);persisted.player_equipped_weapon_art="bow_fan_shot"
	check(persisted.save_run("user://commit-progression.save"),"ready progression saved")
	var loaded=State.new(false);check(loaded.load_run("user://commit-progression.save"),"saved progression loads")
	check(loaded.track_ranks.bow==3 and loaded.player_equipped_weapon_art=="bow_fan_shot" and loaded.carried_xp==800,"loaded bow progression/art/balance retained")
	# Generated maps reconstruct on load; restore the labelled clear-lane test
	# geography before asking to target this artificial saved enemy position.
	loaded.walls.clear();loaded._build_wall_spatial_index();loaded._update_exploration(true)
	check(loaded.request_commit_shot(target_id(loaded),false),"loaded progression can use additional action")
	var resume=fresh(rules,5,true);resume.bow_followup_ready=true
	check(resume.request_commit_shot(target_id(resume),false),"prepaid accelerated save fixture commits")
	for i in 8:resume.advance_streamed_action_tick()
	check(resume.save_run("user://commit-paid.save"),"integrated Survey supports existing mid-obligation save policy")
	var restored=State.new(false);check(restored.load_run("user://commit-paid.save"),"paid obligation reloads")
	check(restored.player_action.commit_shot and restored.player_action.bow_followup_consumed and restored.bow_followup_consumed and not restored.bow_followup_ready,"paid/consumed flags survive resume")
	var paid=restored.energy_spent_total;ticks(restored)
	check(restored.survey_shots_fired==1 and restored.energy_spent_total==paid and not restored.bow_followup_ready,"resume cannot discount, duplicate debit or re-earn consumed preload")
	var earned=fresh(rules,5,true);earned.bow_followup_ready=true
	var semantic_before=load("res://scripts/core/determinism_snapshot.gd").checkpoint(earned)
	earned.bow_followup_ready=false
	var semantic_after=load("res://scripts/core/determinism_snapshot.gd").checkpoint(earned)
	check(semantic_before.player!=semantic_after.player,"active earned benefit participates in deterministic state")
	earned.bow_followup_ready=true
	check(earned.save_run("user://commit-earned.save"),"earned ready preload saves")
	var next=State.new(false);check(next.load_run("user://commit-earned.save") and next.bow_followup_ready,"earned ready preload survives reload")
	next.walls.clear();next._build_wall_spatial_index();next._update_exploration(true)
	check(next.request_commit_shot(target_id(next),false) and is_equal_approx(float(next.player_action.elapsed),0.45),"loaded earned preload reduces remaining draw once")
	var void_shot=fresh(rules)
	void_shot.floor_shapes.assign([{"kind":"rect","rect":Rect2(100,100,900,1500),"layer":void_shot.current_layer,"part_id":0},{"kind":"rect","rect":Rect2(1100,100,1200,1500),"layer":void_shot.current_layer,"part_id":1}])
	void_shot._loaded_floor_shapes.assign(void_shot.floor_shapes);void_shot._build_shape_spatial_index()
	check(void_shot.request_commit_shot(target_id(void_shot),false),"visible far-floor target may receive ordinary direction commitment")
	ticks(void_shot)
	check(void_shot.survey_shots_fired==1 and void_shot.enemies[0].hp==10000 and void_shot.projectiles.is_empty(),"committed full arrow stops at first void before far-side target")
func geometry():
	var b=Boundary.new([{"kind":"circle","center":Vector2(900,800),"radius":150.0}])
	var p=Vector2(1028.4,800);var r=21.6
	check(b.sweep(p,p+Vector2(-4,0),r)==INF,"valid tangent may depart inward")
	check(b.sweep(p,p+Vector2(4,0),r)==0,"tangent cannot escape outward")
	var later=b.sweep(p,Vector2(600,800),r)
	check(later>0 and later<1,"inward departure still stops at later opposite edge")
	var overlap=p+Vector2(1,0)
	check(b.sweep(overlap,overlap+Vector2(1,0),r,true)==0,"invalid overlap cannot deepen")
func _init():call_deferred("run")
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	geometry()
	for rules in ["energy","recovery"]:
		for rank in [0,2,3,4,5]:run_case(rules,rank)
		controls(rules)
	FileAccess.open("user://commit-shot-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("COMMIT SHOT CORE ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
