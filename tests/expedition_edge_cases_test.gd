extends SceneTree
# Deliberately constructed state fixtures, not earned combat victories.
const State = preload("res://scripts/core/run_state.gd")
const Coordinator = preload("res://scripts/core/expedition_coordinator.gd")
const Economy = preload("res://scripts/core/expedition_economy.gd")
const Generator = preload("res://scripts/core/expedition_generator.gd")
const Executor = preload("res://scripts/core/expedition_combat.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func write_fixture(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_var(payload,true)
	file.close()

func test_lifecycle() -> void:
	var state := State.new(false)
	state.start_run("warrior","expedition",73,"encounter","recovery")
	check(state.combat_rules=="energy","New expeditions use Energy")
	for biome in range(3):
		check(state.expedition["biome"]==biome,"Correct biome order")
		var ids := {}
		for enemy in state.enemies:
			check(not ids.has(enemy["id"]),"Stable actor IDs unique")
			ids[enemy["id"]]=true
		state.player_pos = state.expedition_markers["exit"]
		check(not state.request_expedition_departure(true),"Cannot bypass boss outcome")
		Coordinator.defeat_boss(state.expedition)
		var crowns := int(state.expedition["crowns"])
		check(not Coordinator.defeat_boss(state.expedition) and crowns==state.expedition["crowns"],"Boss reward once")
		state.potions=0
		state.player_hp=15
		state.request_expedition_departure()
		check(state.save_run("user://expedition-edge.save"),"Save at departure warning")
		var loaded := State.new(false)
		check(loaded.load_run("user://expedition-edge.save"),"Reload departure warning")
		check(not loaded.expedition_departure_pending,"Reload does not silently confirm departure")
		loaded.request_expedition_departure(true)
		check(loaded.expedition["biome"]==biome and not loaded.trial_complete,"Confirmation must be renewed after reload")
		loaded.request_expedition_departure(true)
		state=loaded
		check(state.potions==0 and state.player_hp==15,"Skipping stone grants no restoration")
		check(not state.expedition["used_waystones"].has(biome),"Unused stone stays unused behind closed route")
		check(Coordinator.validate(state.expedition).is_empty(),"Valid journey state")
	check(state.trial_complete and state.expedition["victory"],"Final explicit exit wins")
	state.save_run("user://expedition-edge.save")
	var final_state := State.new(false)
	check(final_state.load_run("user://expedition-edge.save") and final_state.trial_complete,"Victory persists")
	state.start_run("warrior","expedition",73)
	Coordinator.defeat_boss(state.expedition)
	state.player_pos=state.bonfire_pos
	state.death_pending=true
	state.player_hp=0
	check(not state.activate_waystone(),"Waystone cannot resurrect")
	state.save_run("user://expedition-edge.save")
	check(final_state.load_run("user://expedition-edge.save") and final_state.death_pending and final_state.player_hp==0,"Permadeath persists")

func test_storage() -> void:
	var state := State.new(false)
	state.start_run("mage_elementalist","expedition",42,"encounter","recovery",true)
	var legacy := state._build_save_payload()
	legacy["save_version"]=37
	legacy.erase("expedition")
	write_fixture("user://expedition-legacy.save",legacy)
	var loaded := State.new(false)
	check(loaded.load_run("user://expedition-legacy.save"),"Legacy schema 37 loads")
	check(loaded.expedition.is_empty() and loaded.combat_rules=="recovery" and loaded.player_pos==state.player_pos,"Legacy geography and profile retained")
	legacy.erase("cooldowns")
	check(State.SaveMigrationsScript.normalize(legacy,State.SAVE_VERSION).is_empty(),"Malformed legacy cooldowns reject before migration writes")
	state.start_run("warrior","expedition",42)
	state.player_pos=state.expedition_markers["merchant"]
	state._update_exploration(true)
	state.expedition["crowns"]=12
	check(Economy.purchase(state,"trail_ration"),"Exact affordability succeeds")
	check(not Economy.purchase(state,"trail_ration"),"Insufficient funds do not change stock")
	check(state.save_run("user://expedition-atomic.save"),"Atomic base save")
	write_fixture("user://expedition-atomic.save.pending",{"incomplete":true})
	check(loaded.load_run("user://expedition-atomic.save"),"Interrupted pending write leaves published save readable")
	check(loaded.expedition["crowns"]==0 and loaded.expedition["purchases"]["0:trail_ration"]==1,"Currency and stock commit together")
	check(loaded.world_pickups.any(func(p): return String(p["id"]).begins_with("purchase_")),"Purchased item persists even with full belt")
	var corrupted := loaded.expedition.duplicate(true)
	corrupted["purchases"]["0:trail_ration"]=3
	check(not Coordinator.validate(corrupted).is_empty(),"Reject impossible stock record")
	corrupted=loaded.expedition.duplicate(true)
	corrupted["rewarded_encounters"]=["0:0","0:0"]
	check(not Coordinator.validate(corrupted).is_empty(),"Reject duplicate encounter reward")
	state._add_pickup({"id":"guarded_gear","item_id":"trailcoat","pos":state.player_pos,"layer":state.current_layer,"guard_site":6})
	check(not Economy.equip(state,"guarded_gear"),"Equipment API enforces guarded rewards")

func test_boss_resume() -> void:
	for biome in range(3):
		var state := State.new(false)
		state.start_run("warrior","expedition",42)
		state.expedition["biome"]=biome
		state.expedition["completed"]=range(biome)
		state.expedition["departed"]=range(biome)
		state.expedition["writ"]=biome>0
		state._install_layout(Generator.generate(42,biome))
		state._respawn_enemies()
		state.player_pos=Vector2(11750,2200)
		state._update_exploration(true)
		var boss: Dictionary = state._enemy_by_id((biome+1)*10000+901)
		boss["awareness"]="alerted"
		boss["boss_phase"]=2
		boss["expedition_attack_index"]=2
		Executor.choose(state,boss)
		state.request_wait(State.SIM_DT*13)
		check(state.save_run("user://expedition-boss-resume.save"),"Suspend during a boss commitment")
		var loaded := State.new(false)
		check(loaded.load_run("user://expedition-boss-resume.save"),"Resume boss commitment")
		var resumed: Dictionary = loaded._enemy_by_id(int(boss["id"]))
		check(loaded._simulation_tick_index==state._simulation_tick_index,"Resume preserves alternating simulation clock phase")
		check(resumed["action"]==boss["action"] and resumed["boss_phase"]==2,"Stable boss ID, phase and full action persist")
		for step in range(12):
			state.request_move(Vector2.DOWN if step<6 else Vector2.UP)
			loaded.request_move(Vector2.DOWN if step<6 else Vector2.UP)
			check(state.player_hp==loaded.player_hp and is_equal_approx(state.player_energy,loaded.player_energy),"Resume preserves resource outcome")
			check(boss["pos"]==resumed["pos"] and boss["action"]==resumed["action"],"Subsequent public actions preserve boss timing")
			check(state.hazards==loaded.hazards and state.projectiles==loaded.projectiles,"Delayed hazards and projectiles resume identically")
		state.player_exhaustion_remaining=1.3
		state.player_energy_regen_delay=0.8
		state.save_run("user://expedition-boss-resume.save")
		loaded.load_run("user://expedition-boss-resume.save")
		check(is_equal_approx(loaded.player_exhaustion_remaining,1.3) and is_equal_approx(loaded.player_energy_regen_delay,0.8),"Reload cannot clear exhaustion or regeneration delay")
		loaded.request_move(Vector2.DOWN,State.MOVE_RANGE,false)
		check(not loaded.save_run("user://expedition-boss-resume.save"),"Save refuses an unfinished player commitment")

func test_disciplines() -> void:
	for discipline in ["trapper","sapper"]:
		var state := State.new(false)
		state.start_run("warrior","expedition",42)
		Coordinator.defeat_boss(state.expedition)
		Coordinator.depart(state.expedition)
		state._install_layout(Generator.generate(42,1))
		state._respawn_enemies()
		state.player_pos=state.expedition_markers["merchant"]
		state._update_exploration(true)
		check(Economy.adopt(state,discipline),"Adopt discipline fixture")
		state.track_ranks["adopted"]=3
		state._replace_enemy_actors([])
		state.player_pos+=Vector2(0,200)
		if discipline=="trapper":
			check(state.request_adopted(state.player_pos+Vector2.RIGHT*100),"First rank-three snare")
			for second in range(10): state.request_wait(1.0)
			check(state.request_adopted(state.player_pos+Vector2.LEFT*100),"Second rank-three snare")
			check(state.hazards.filter(func(h): return h["kind"]=="snare").size()==2,"Rank three allows two active snares")
			var victim := state._make_enemy("boar",state.player_pos+Vector2.LEFT*65,100,0)
			state._replace_enemy_actors([victim])
			var before := float(victim["posture"])
			state._update_hazards(State.SIM_DT)
			check(victim["conditions"].get("snared",0)>1.9 and float(victim["posture"])==before-3,"Snare applies slow and posture")
		else:
			var victim := state._make_enemy("boar",state.player_pos+Vector2.RIGHT*110,100,0)
			state._replace_enemy_actors([victim])
			state.request_adopted(victim["pos"])
			check(int(victim["hp"])<100 and Vector2(victim["gale_velocity"]).length()>0,"Sapper damages and displaces")
			var hp := int(victim["hp"])
			state._concussion_burst(victim["pos"],140,0,0,120)
			check(victim["hp"]==hp,"Repulsion burst does no damage")

func _init() -> void:
	test_lifecycle()
	test_storage()
	test_boss_resume()
	test_disciplines()
	for failure in failures: print("FAILED: ",failure)
	print("Expedition edge cases: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
