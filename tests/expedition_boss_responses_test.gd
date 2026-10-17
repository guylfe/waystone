extends SceneTree
const State = preload("res://scripts/core/run_state.gd")
const Combat = preload("res://scripts/core/combat_catalog.gd")
const Executor = preload("res://scripts/core/expedition_combat.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func probe(kind: String, attack: int, response: String, response_at: float = 0.45, loadout: String = "warrior") -> Dictionary:
	var state := State.new(false)
	state.start_run(loadout,"combat_survey",42)
	state.walls.clear()
	state._build_wall_spatial_index()
	state.player_pos = Vector2(850,700)
	var enemy := state._make_enemy(kind,state.player_pos+Vector2.RIGHT*float(Combat.EXPEDITION_KITS[kind]["engage"]),int(Combat.enemy_fact(kind,"base_hp")),0)
	enemy["expedition_attack_index"] = attack
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["alert_remaining"] = 100.0
	enemy["facing"] = Vector2.LEFT
	state._replace_enemy_actors([enemy])
	Executor.choose(state,enemy)
	var action: Dictionary = enemy["action"]
	var start_hp := state.player_hp
	var dodged := false
	for tick in range(400):
		if enemy["action"] != action: break
		if state.is_player_ready():
			if response in ["dodge","punish"] and not dodged and state.simulation_time>=response_at:
				dodged = state.request_defense(Vector2.UP,false)
			elif response=="punish" and dodged:
				var direction: Vector2 = state.player_pos.direction_to(enemy["pos"])
				# These bosses have large bodies; all tested melee footprints can
				# contact them at 130, so do not waste the opening walking to centre.
				if state.player_pos.distance_to(enemy["pos"])>130: state.request_move(direction,State.MOVE_RANGE,false)
				else: state.request_combo(direction,false,false)
			elif response=="retreat": state.request_move(Vector2.LEFT,State.MOVE_RANGE,false)
			elif response=="orbit": state.request_move((state.player_pos-Vector2(enemy["pos"])).orthogonal(),State.MOVE_RANGE,false)
			else: state.request_wait(0.05,false)
		state._tick(State.SIM_DT)
	return {"damage":start_hp-state.player_hp,"dealt":state.damage_dealt,"dodged":dodged,"records":state.survey_attack_records,"position":state.player_pos}

func test_phase_hazards() -> void:
	var state := State.new(false)
	state.start_run("warrior","expedition",42)
	state.player_pos=Vector2(11900,2200)
	state._update_exploration(true)
	var enemy := state._make_enemy("kilnmaster",state.player_pos+Vector2.RIGHT*240,360,9)
	state._replace_enemy_actors([enemy])
	enemy["boss_phase"]=2
	enemy["hp"]=180
	enemy["expedition_attack_index"]=2
	Executor.choose(state,enemy)
	var action: Dictionary = enemy["action"]
	action["elapsed"]=action["startup"]
	Executor.tick(state,enemy,action,0,float(action["startup"]))
	check(state.hazards.size()==2,"Phase-two furnace authors two lanes")
	for hazard in state.hazards:
		check(hazard.has("lane_start") and hazard.has("lane_end") and hazard["trigger_at"]>=0.8,"Furnace lanes visibly announce before damage")
		for distance in [-150,-100,-50,0,50,100,150]:
			var escape: Vector2 = state.player_pos+Vector2.RIGHT*float(distance)
			check(state._can_occupy(escape,State.PLAYER_RADIUS,0,true),"Central furnace escape remains legal floor")
			check(Geometry2D.get_closest_point_to_segment(escape,hazard["lane_start"],hazard["lane_end"]).distance_to(escape)>float(hazard["radius"])+State.PLAYER_RADIUS,"Central furnace escape stays outside both lanes")
	Executor._spawn_zone(state,enemy,action,state.player_pos+Vector2(0,300))
	Executor._spawn_zone(state,enemy,action,state.player_pos+Vector2(0,-300))
	check(state.hazards.size()==3,"Concurrent expedition ground hazards are capped")
	state.hazards.clear()
	state.projectiles.clear()
	var centre := state.player_pos+Vector2(0,150)
	for source in [0,int(enemy["id"])]:
		state._add_projectile({"kind":"arrow","pos":centre+Vector2(50,0),"vel":Vector2(0,400),"radius":5.0,"damage":10,"source_id":source,"layer":state.current_layer,"travelled":0.0,"max_range":1000.0})
	state._resolve_gale(centre)
	check(state.projectiles[0]["vel"]==state.projectiles[1]["vel"],"Wind deflects player and enemy projectiles symmetrically")
	check(Vector2(state.projectiles[0]["vel"])!=Vector2(0,400),"Symmetry is not a no-op")

func test_control_and_phase(kind: String) -> void:
	var state := State.new(false)
	state.start_run("warrior","combat_survey",42)
	state.walls.clear()
	state._build_wall_spatial_index()
	var enemy := state._make_enemy(kind,state.player_pos+Vector2.RIGHT*100,int(Combat.enemy_fact(kind,"base_hp")),0)
	state._replace_enemy_actors([enemy])
	enemy["awareness"]="alerted"
	Executor.choose(state,enemy)
	var commitment: Dictionary = enemy["action"]
	check(not state._apply_enemy_hit_reaction(enemy,4.0,"alerted",commitment,state.player_pos),kind+" ordinary damage does not cancel commitment")
	check(state._apply_posture_damage(enemy,100,state.player_pos,"player","test"),kind+" accumulated posture can break")
	var duration := float(enemy["action"]["duration"])
	state._apply_posture_damage(enemy,100,state.player_pos,"player","test")
	check(enemy["action"]["kind"]=="stagger" and enemy["action"]["duration"]==duration,kind+" break window cannot be refreshed forever")
	enemy["hp"]=int(enemy["max_hp"])/2
	enemy["action"]=state._idle_action()
	Executor.choose(state,enemy)
	check(enemy["boss_phase"]==2 and enemy["action"]["kind"]=="phase_change",kind+" half-health transition is announced")
	enemy["action"]=state._idle_action()
	Executor.choose(state,enemy)
	check(enemy["action"]["kind"]=="expedition_attack",kind+" phase transition occurs once")

func test_wind_volley_response() -> void:
	# Exercise the actual phase-two sequence, not a lone projectile. No healing,
	# invulnerability override or edited action clocks are used after setup.
	for loadout in ["warrior","rogue_acrobat","rogue_sharpshooter","mage_elementalist"]:
		for distance in [100.0,290.0]:
			var successes := 0
			for timing in [0.45,0.50,0.55]:
				var state := State.new(false)
				state.start_run(loadout,"combat_survey",42)
				state.walls.clear()
				state._build_wall_spatial_index()
				state.player_pos=Vector2(700,700)
				var enemy := state._make_enemy("bell_regent",state.player_pos+Vector2.RIGHT*distance,460,0)
				enemy["hp"]=230
				enemy["boss_phase"]=2
				enemy["expedition_attack_index"]=2
				enemy["awareness"]="alerted"
				enemy["alert_remaining"]=100.0
				enemy["facing"]=Vector2.LEFT
				state._replace_enemy_actors([enemy])
				Executor.choose(state,enemy)
				var initial_hp := state.player_hp
				var seen_volley := false
				var dodged := false
				for tick in range(500):
					var action: Dictionary = enemy["action"]
					var is_volley: bool = String(action.get("ability_id",""))=="resonant_volley"
					if seen_volley and not is_volley: break
					seen_volley=seen_volley or is_volley
					if state.is_player_ready():
						if is_volley and not dodged and float(action["elapsed"])>=timing:
							dodged=state.request_defense(Vector2.UP,false)
						else: state.request_wait(0.05,false)
					state.advance_streamed_action_tick()
				if seen_volley and dodged and state.player_hp==initial_hp: successes+=1
			print("Bell wind/volley ",loadout," distance ",distance," successful timings ",successes)
			check(successes>=2,"Phase-two wind/volley has a reliable Dodge answer for %s at %s" % [loadout,distance])

func test_sustained_response(kind: String, response: String) -> void:
	var state := State.new(false)
	state.start_run("warrior","combat_survey",42)
	state.walls.clear()
	state._build_wall_spatial_index()
	state.player_pos=Vector2(700,650)
	var enemy := state._make_enemy(kind,Vector2(1150,650),int(Combat.enemy_fact(kind,"base_hp")),0)
	enemy["awareness"]="alerted"
	enemy["alert_remaining"]=100.0
	enemy["revealed_to_player"]=true
	state._replace_enemy_actors([enemy])
	var start_hp := state.player_hp
	for tick in range(3600):
		if state.death_pending: break
		if state.is_player_ready():
			var away: Vector2 = Vector2(enemy["pos"]).direction_to(state.player_pos)
			state.request_move(away.orthogonal() if response=="orbit" else away,State.MOVE_RANGE,false)
		state.advance_streamed_action_tick()
	check(state.player_hp<start_hp,kind+" does not permit sustained "+response+" as a universal defense")
	print(kind," sustained ",response," damage ",start_hp-state.player_hp)

func _init() -> void:
	test_phase_hazards()
	test_wind_volley_response()
	for entry in [["thornhart",1],["kilnmaster",0],["bell_regent",1]]:
		var kind := String(entry[0])
		test_control_and_phase(kind)
		for response in ["retreat","orbit"]: test_sustained_response(kind,response)
		for response in ["none","retreat","orbit"]:
			var result := probe(kind,int(entry[1]),response)
			print(kind," ",response," ",result)
			check(int(result["damage"])>0,kind+" signature defeats "+response)
		var successes := 0
		for timing in [0.35,0.40,0.45,0.50]:
			var result := probe(kind,int(entry[1]),"dodge",timing)
			print(kind," dodge at ",timing," damage ",result["damage"])
			if bool(result["dodged"]) and int(result["damage"])==0: successes += 1
		check(successes>=3,kind+" signature has a broad reliable dodge timing window")
		var punish := probe(kind,int(entry[1]),"punish",0.4)
		check(punish["dealt"]>0 and punish["damage"]==0,kind+" recovery can be reached and punished after a successful defense")
		for loadout in ["rogue_acrobat","rogue_sharpshooter","mage_elementalist"]:
			check(probe(kind,int(entry[1]),"retreat",0.45,loadout)["damage"]>0,kind+" catches early walking by "+loadout)
			check(probe(kind,int(entry[1]),"dodge",0.4,loadout)["damage"]==0,kind+" allows Dodge for "+loadout)
			if loadout!="rogue_sharpshooter":
				var opening := probe(kind,int(entry[1]),"punish",0.4,loadout)
				check(opening["dealt"]>0 and opening["damage"]==0,kind+" offers a reachable melee punish for "+loadout)
	# These cast/charge commitments have spatial answers; defense is not a tax
	# imposed on every move in a boss's vocabulary.
	for entry in [["thornhart",2],["kilnmaster",1],["bell_regent",3]]:
		check(probe(entry[0],entry[1],"orbit")["damage"]==0,String(entry[0])+" has an ordinary walking answer")
	for failure in failures: print("FAILED: ",failure)
	quit(0 if failures.is_empty() else 1)
