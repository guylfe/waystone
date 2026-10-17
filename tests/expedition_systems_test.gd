extends SceneTree
const State = preload("res://scripts/core/run_state.gd")
const Catalog = preload("res://scripts/core/expedition_catalog.gd")
const Combat = preload("res://scripts/core/combat_catalog.gd")
const Executor = preload("res://scripts/core/expedition_combat.gd")
const Economy = preload("res://scripts/core/expedition_economy.gd")
const Generator = preload("res://scripts/core/expedition_generator.gd")
const Coordinator = preload("res://scripts/core/expedition_coordinator.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func economy_fixture(loadout: String):
	var state := State.new(false)
	state.start_run(loadout,"expedition",42)
	state.player_pos = state.expedition_markers["merchant"]
	state._update_exploration(true)
	return state

func test_economy() -> void:
	for loadout in ["warrior","rogue_acrobat","rogue_sharpshooter","mage_elementalist"]:
		var state = economy_fixture(loadout)
		check(Economy.at_merchant(state),"Safe merchant for "+loadout)
		# Escaped groups outside simulation range retain their last awareness.
		# Their frozen alert flag must not impose a biome-wide merchant lock.
		var distant: Dictionary = state.enemies[0]
		distant["awareness"]="alerted"
		check(not state._enemy_is_streamed(distant),"Avoided group is outside active combat")
		check(Economy.at_merchant(state),"Escaped distant group does not lock safe merchant")
		var nearby := state._make_enemy("archer",state.player_pos+Vector2.RIGHT*700,99999)
		nearby["awareness"]="alerted"
		state._add_enemy_actor(nearby)
		check(not Economy.at_merchant(state),"Active alerted ranged threat still prevents trading")
		var nearby_id: int = nearby["id"]
		state._replace_enemy_actors(state.enemies.filter(func(actor): return actor["id"]!=nearby_id))
		state.expedition["crowns"] = 200 # Transaction fixture, not earned-run evidence.
		check(Economy.purchase(state,"trail_ration"),"First ration purchase")
		check(Economy.purchase(state,"trail_ration"),"Second ration purchase")
		check(not Economy.purchase(state,"trail_ration"),"Finite stock")
		check(state.expedition["crowns"]==176,"Exact finite charge")
		check(state.save_run("user://expedition-economy.save"),"Purchase save")
		var loaded := State.new(false)
		check(loaded.load_run("user://expedition-economy.save"),"Purchase reload")
		check(not Economy.purchase(loaded,"trail_ration"),"No stock regeneration on load")
		for id in ["trailcoat","reinforced_jack","channeler_wrap","trailcoat"]:
			state._add_pickup({"id":"gear_"+id,"item_id":id,"pos":state.player_pos,"layer":state.current_layer,"count":1})
			var health: int = state.player_hp
			check(Economy.equip(state,"gear_"+id),"Equip "+id)
			check(state.player_hp<=health,"No healing from gear swapping")
		check(state.world_pickups.any(func(p: Dictionary): return p["item_id"]=="reinforced_jack"),"Displaced gear remains")
		check(state.save_run("user://expedition-equipment.save"),"Equipped attributes save")
		check(loaded.load_run("user://expedition-equipment.save"),"Equipped attributes reload")
		check(loaded.expedition["equipment"]==state.expedition["equipment"] and loaded.player_attributes==state.player_attributes,"Gear identity and stat deltas persist without applying twice")
		check(loaded.player_hp==state.player_hp and loaded.player_max_hp==state.player_max_hp and is_equal_approx(loaded.player_energy,state.player_energy) and is_equal_approx(loaded.player_max_energy,state.player_max_energy),"Equipment reload neither heals nor duplicates capacity")
		state.consumable_slots[0] = {"id":"trail_ration","count":2}
		state.player_hp = state.player_max_hp
		check(not state.request_consumable(0,Vector2.ZERO,false),"Reject full-health ration")
		state.player_hp -= 20
		check(state.request_consumable(0,Vector2.ZERO),"Timed ration use")
		check(state.player_hp==state.player_max_hp-5,"Ration heals 15")
		check(state.consumable_slot(0)["count"]==1,"Ration consumed once")
		Coordinator.defeat_boss(state.expedition)
		state.player_pos = state.bonfire_pos
		state.potions = 0
		check(state.activate_waystone(),"Restore at stone")
		check(state.potions==5 and state.consumable_slot(0)["count"]==1,"Only original pouch refills")
		for discipline in ["trapper","sapper"]:
			var training = economy_fixture(loadout)
			Coordinator.defeat_boss(training.expedition)
			Coordinator.depart(training.expedition)
			training._install_layout(Generator.generate(42,1))
			training._respawn_enemies()
			training.player_pos = training.expedition_markers["merchant"]
			training._update_exploration(true)
			check(Economy.adopt(training,discipline),"Free two-rank "+discipline+" for "+loadout)
			check(training.track_total("adopted")==2 and training.expedition["crowns"]==25,"Writ not money")
			check(not Economy.adopt(training,discipline),"Choice permanent")
			check(training.request_adopted(training.player_pos+Vector2.RIGHT*100),"Discipline executes "+discipline)
			check(training.cooldown_remaining("adopted")>8.5,"Discipline cooldown")
			check(training.save_run("user://expedition-discipline.save"),"Discipline save")
			check(loaded.load_run("user://expedition-discipline.save"),"Discipline reload")
			check(loaded.track_total("adopted")==2 and loaded.expedition["discipline"]==discipline,"Discipline persisted")

func test_executors() -> void:
	for kind in Combat.EXPEDITION_KITS:
		var kit: Dictionary = Combat.EXPEDITION_KITS[kind]
		for attack_index in Array(kit["attacks"]).size():
			var state := State.new(false)
			state.start_run("warrior","combat_survey",42)
			state.walls.clear()
			state._build_wall_spatial_index()
			var enemy := state._make_enemy(kind,state.player_pos+Vector2.RIGHT*120,999)
			enemy["expedition_attack_index"] = attack_index
			enemy["gong_pos"] = enemy["pos"]
			enemy["awareness"] = "alerted"
			enemy["facing"] = Vector2.LEFT
			state._replace_enemy_actors([enemy])
			check(Executor.choose(state,enemy),"Registered executor "+kind)
			var action: Dictionary = enemy["action"]
			check(action["kind"]=="expedition_attack","Attack selected "+kind)
			check(action["duration"]>action["active_end"]+0.5,"Reachable recovery budget "+String(action["ability_id"]))
			for tick in range(360):
				var before := float(action["elapsed"])
				action["elapsed"] = before+State.SIM_DT
				Executor.tick(state,enemy,action,before,State.SIM_DT)
				state._update_projectiles(State.SIM_DT)
				state._update_hazards(State.SIM_DT)
			check(action["effect_done"],"Attack released "+String(action["ability_id"]))
			if action["shape"] in ["hook","sweep","drive","flight","cone"]: check(action["hit_done"],"Stationary target reached "+String(action["ability_id"]))

func open_combat():
	var state := State.new(false)
	state.start_run("warrior","combat_survey",42)
	state.player_pos=Vector2(1000,700)
	state.walls.clear()
	state.barriers.clear()
	state._build_wall_spatial_index()
	state._replace_enemy_actors([])
	return state

func test_signature_identities() -> void:
	for kind in ["briarhook","thornspitter","kiln_guard","slagthrower"]:
		var state = open_combat()
		var enemy: Dictionary = state._make_enemy(kind,Vector2(850,700),100,0)
		enemy["awareness"]="alerted"
		state._replace_enemy_actors([enemy])
		Executor.choose(state,enemy)
		var action: Dictionary = enemy["action"]
		var origin := Vector2(enemy["pos"])
		if kind=="kiln_guard":
			check(not state._apply_enemy_hit_reaction(enemy,4,"alerted",action),"Hammer startup is protected")
		action["elapsed"]=float(action["startup"])
		Executor.tick(state,enemy,action,0,float(action["startup"]))
		match kind:
			"briarhook":
				check(Vector2(enemy["pos"]).distance_to(origin)>40,"Hook advances into contact")
				check(state.player_gale_velocity.dot(Vector2.LEFT)>0,"Hook contact pulls toward the attacker")
			"thornspitter":
				check(enemy["pos"]==origin and state.projectiles.size()==3,"Thornspitter roots and releases exactly three quills")
				check(state.projectiles[0]["vel"]!=state.projectiles[1]["vel"],"Quills form a fan rather than stacked shots")
			"kiln_guard":
				action["elapsed"]=float(action["active_end"])+0.1
				check(state._apply_enemy_hit_reaction(enemy,4,"alerted",action),"Venting recovery is interruptible")
			"slagthrower":
				check(state.hazards.size()==1 and state.hazards[0]["trigger_at"]>=0.8,"Slag impact is announced before damage")
				for tick in range(480): state._update_hazards(State.SIM_DT)
				check(state.hazards.is_empty(),"Slag hazard expires instead of permanently blocking the route")
	var flight = open_combat()
	var wing: Dictionary = flight._make_enemy("glasswing",Vector2(500,700),32,0)
	var ally: Dictionary = flight._make_enemy("knife",Vector2(550,700),20,0)
	flight._replace_enemy_actors([wing,ally])
	flight.player_pos=Vector2(850,700)
	Executor.choose(flight,wing)
	var action: Dictionary = wing["action"]
	check(action.get("airborne",false) and action.get("ally_collision","")=="vault","Glasswing uses shared airborne collision policy")
	var motion: Dictionary = flight._move_charging_actor(wing,wing["pos"],Vector2(120,0),action)
	check(Vector2(motion["position"]).x>600,"Glasswing crosses allies")
	var alarm = open_combat()
	var runner: Dictionary = alarm._make_enemy("bellrunner",Vector2(850,700),26,0)
	runner["gong_pos"]=runner["pos"]
	runner["expedition_site"]=1
	var reserve: Dictionary = alarm._make_enemy("polearm",Vector2(700,800),38,0)
	reserve["reserve"]=true
	reserve["expedition_site"]=1
	alarm._replace_enemy_actors([runner,reserve])
	Executor.choose(alarm,runner)
	var gong: Dictionary = runner["action"]
	gong["elapsed"]=gong["startup"]
	Executor.tick(alarm,runner,gong,0,float(gong["startup"]))
	check(runner.get("gong_used",false) and not reserve["reserve"],"Gong activates its existing reserve")
	for cycle in range(5): Executor.choose(alarm,runner)
	check(alarm.enemies.size()==2 and runner["action"]["kind"]!="expedition_attack","Gong does not regenerate stock or summon endlessly")

func test_clocks() -> void:
	for speed in [5,15]:
		var state = economy_fixture("warrior")
		state.player_attributes["speed"] = speed
		state.player_action = state._action("hit_reaction",0.6,Vector2.ZERO)
		var start: float = state.simulation_time
		state._simulate_until_ready()
		check(absf(state.simulation_time-start-0.6)<0.02,"Reaction owns world clock")
		state._begin_sword_combo(Vector2.RIGHT,false,false)
		var phases: Array = state.player_action["phases"]
		check(is_equal_approx(state.player_commitment_world_remaining(),float(phases[0]["end"])/state._player_personal_tempo()),"Only committed phase counted")
	var state := State.new(false)
	state.start_run("warrior","combat_survey",42)
	var enemy := state._make_enemy("briarhook",state.player_pos+Vector2.RIGHT*100,38,0)
	var action := state._action("expedition_attack",2.0,Vector2.LEFT)
	action["startup"]=0.6
	action["active_end"]=0.8
	state.player_action=state._action("move",0.2,Vector2.LEFT)
	state._attach_charge_capture(action,0.0,"briar_hook")
	action["capture_record"]["response"]="move"
	action["capture_record"]["resolution"]="contact"
	state.player_action=state._action("hit_reaction",0.6,Vector2.ZERO)
	state._observe_capture(enemy,action,0.65)
	check(action["capture_record"]["walk_only"],"A failed walking attempt remains in the denominator after its forced reaction")
	action["capture_record"]["resolution"]=""
	state.player_action=state._action("combo",1.0,Vector2.RIGHT)
	state._observe_capture(enemy,action,0.9)
	check(action["capture_record"]["walk_only"],"A recovery punish does not retroactively change a defense")

func _init() -> void:
	test_economy()
	test_executors()
	test_signature_identities()
	test_clocks()
	for failure in failures: print("FAILED: ",failure)
	print("Expedition systems: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
