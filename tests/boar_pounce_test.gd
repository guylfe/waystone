extends SceneTree
# Synthetic open arenas and simulated choice delays. Actual action selection and
# public wait/movement executor; no mutation of chosen action tuning parameters.
const State=preload("res://scripts/core/run_state.gd")
var checks=0
var failures=[]
var records=[]
func check(ok:bool,why:String):
	checks+=1
	if not ok:failures.append(why);printerr("FAILED: ",why)
func fresh(loadout:String="warrior",rules:String="energy",gap:float=220.0,kind:String="boar"):
	var s=State.new(false);s.start_run(loadout,"combat_survey",9090,"encounter",rules)
	s.player_pos=Vector2(1600,1500);s.world_size=Vector2(4400,3400)
	s.walls.clear();s.barriers.clear();s.hazards.clear();s.projectiles.clear();s._build_wall_spatial_index()
	s.floor_shapes.assign([{"kind":"rect","rect":Rect2(100,100,4200,3200),"layer":s.current_layer,"part_id":0}]);s._loaded_floor_shapes.assign(s.floor_shapes);s._build_shape_spatial_index()
	var e=s._make_enemy(kind,s.player_pos+Vector2(-gap,0),35)
	e.layer=s.current_layer;e.awareness="alerted";e.revealed_to_player=true;e.facing=Vector2.RIGHT;e.last_known_player=s.player_pos
	s._replace_enemy_actors([e]);s._update_exploration(true)
	return s
func chosen(s)->Dictionary:
	s._choose_enemy_action(s.enemies[0])
	return s.enemies[0].action
func motion(loadout:String,rules:String,direction:Vector2,delay:float,gap:float):
	var s=fresh(loadout,rules,gap);var e=s.enemies[0]
	# The first public wait causes ordinary AI to select its real action.
	s.request_wait(-1.0,false);s.advance_streamed_action_tick()
	check(e.action.kind=="charge","public wait selects Boar pounce")
	var action=e.action;var peak=0.0;var locked=Vector2.ZERO;var ticks=0;var hp=s.player_hp;var response=-1.0
	while ticks<600 and e.action==action and e.action.kind=="charge" and s.player_hp>0:
		if s.is_player_ready():
			if s.simulation_time<delay:s.request_wait(-1.0,false)
			else:
				if response<0:response=s.simulation_time
				s.request_move(direction,s.MOVE_RANGE,false)
		var previous=Vector2(e.pos);var elapsed=float(action.elapsed)
		s.advance_streamed_action_tick();ticks+=1
		var speed=Vector2(e.pos).distance_to(previous)/s.SIM_DT
		if elapsed>=float(action.startup) and elapsed<float(action.active_end):peak=maxf(peak,speed)
		if float(action.elapsed)>=float(action.tracking_end)+0.01 and locked==Vector2.ZERO:locked=action.direction
		if locked!=Vector2.ZERO and e.action==action:
			check(Vector2(action.direction).distance_to(locked)<0.0001,"bearing remains frozen after authored .45 lock")
			check(Vector2(e.facing).distance_to(Vector2(action.direction))<0.0001,"body/tell facing matches selected frozen bearing")
	check(ticks<600,"pounce remains finite")
	if direction==Vector2.RIGHT and delay==0 and gap==340:check(peak>s.player_move_speed,"launched Boar outruns standard loadout "+loadout+rules)
	records.append({"loadout":loadout,"rules":rules,"gap":gap,"choice":str(direction),"simulated_delay":delay,"first_movement_choice_at":response,"chosen_speed":action.speed,"tracking_end":action.tracking_end,"peak_actual_speed":peak,"player_move_speed":s.player_move_speed,"damage_received":hp-s.player_hp,"boar_final":str(e.pos),"player_final":str(s.player_pos),"world_time":s.simulation_time,"ticks":ticks})
func run():
	for gap in [84.0,88.0,220.0,378.0,379.0,600.0]:
		var s=fresh("warrior","energy",gap);var a=chosen(s)
		check((a.kind=="charge")== (gap>=88 and gap<=378),"existing engagement distance retained "+str(gap))
		if a.kind=="charge":
			check(a.speed==640.0 and is_equal_approx(a.tracking_end,0.45),"new selected tuning values")
			check(is_equal_approx(a.startup,0.70) and is_equal_approx(a.active_end,1.50) and is_equal_approx(a.duration,1.95) and a.damage==25 and a.contact_bonus==22 and is_equal_approx(s.enemies[0].pounce_cooldown,2.40),"other Boar timing/damage/contact/cooldown unchanged")
			records.append({"acquisition_gap":gap,"action":a.duplicate(true)})
	for kind in ["hound","ox"]:
		var s=fresh("warrior","energy",220,kind);var a=chosen(s)
		check(a.speed== (500.0 if kind=="hound" else 520.0),"other charger speed unchanged "+kind)
	for kind in ["knife","shield"]:
		var s=fresh();var a=chosen(s);var e=s.enemies[0];var origin=Vector2(e.pos)
		var ally=s._make_enemy(kind,origin+Vector2(100,0),50);ally.layer=s.current_layer;s._replace_enemy_actors([e,ally])
		var motion=s._move_charging_actor(e,origin,Vector2(90,0),a)
		check(Vector2(motion.position).x>origin.x if kind=="knife" else str(motion.collision.get("cause",""))=="ally_body","actual selected faster pounce preserves ally rule "+kind)
	var narrow=fresh();var narrow_action=chosen(narrow);var animal=narrow.enemies[0];var origin=Vector2(animal.pos)
	narrow.floor_shapes.assign([{"kind":"rect","rect":Rect2(origin-Vector2(100,60),Vector2(160,120)),"layer":narrow.current_layer,"part_id":0}]);narrow._loaded_floor_shapes.assign(narrow.floor_shapes);narrow._build_shape_spatial_index()
	var stopped=narrow._move_charging_actor(animal,origin,Vector2(150,0),narrow_action)
	check(Vector2(stopped.position).x<=origin.x+60-animal.radius*0.72,"fast selected pounce remains stopped by valid floor edge")
	for rules in ["energy","recovery"]:
		var dodge=fresh("warrior",rules);chosen(dodge);var hp=dodge.player_hp
		check(dodge.request_dodge(Vector2.DOWN,false),"normal Dodge control starts "+rules)
		while float(dodge.player_action.elapsed)<0.18:dodge.advance_streamed_action_tick()
		dodge._resolve_incoming_hit(int(dodge.enemies[0].id),25,"synthetic Boar contact",dodge.enemies[0].pos,dodge.player_pos,1)
		check(dodge.player_hp==hp,"shared Dodge evade window still answers physical contact "+rules)
		var block=fresh("warrior",rules);chosen(block);hp=block.player_hp
		check(block.request_block(Vector2.LEFT,false),"shared directional Block control starts "+rules)
		while float(block.player_action.elapsed)<0.20:block.advance_streamed_action_tick()
		block._resolve_incoming_hit(int(block.enemies[0].id),25,"synthetic Boar contact",Vector2(block.enemies[0].pos)-block.player_pos,block.player_pos,1)
		check(block.successful_blocks==1 and block.player_hp==hp,"ordinary guard owner blocks physical contact "+rules)
		var interrupt=fresh("warrior",rules);var a=chosen(interrupt);var boar=interrupt.enemies[0]
		check(interrupt._apply_enemy_hit_reaction(boar,2,"alerted",a.duplicate(true),boar.pos),"wind-up retains normal interruption "+rules)
		var armored=fresh("warrior",rules,340);a=chosen(armored);boar=armored.enemies[0]
		for i in 160:
			if float(a.elapsed)>=0.90:break
			if armored.is_player_ready():armored.request_wait(-1,false)
			armored.advance_streamed_action_tick()
		check(armored.enemy_hit_reaction_resistance(boar,a,2)=="Momentum armor" and armored.enemy_hit_reaction_resistance(boar,a,5)=="","existing momentum armor threshold retained "+rules)
	for loadout in ["warrior","rogue_acrobat","rogue_sharpshooter","mage_elementalist"]:
		for rules in ["energy","recovery"]:
			motion(loadout,rules,Vector2.RIGHT,0,100)
			for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
				for delay in [0.0,0.35,0.70]:motion(loadout,rules,direction,delay,100 if delay>0 else 340)
	FileAccess.open("user://boar-pounce-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("BOAR ACTUAL ACTION ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func _init():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	call_deferred("run")
