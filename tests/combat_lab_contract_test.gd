extends SceneTree
const Lab = preload("res://scripts/experiments/combat_lab_catalog.gd")
const Digest = preload("res://scripts/core/determinism_snapshot.gd")
const Frame = preload("res://scripts/presentation/presentation_frame.gd")
const Schema = preload("res://scripts/core/runtime_schema.gd")
var failures: Array[String] = []
var checks := 0
var measurements: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func empty(variant: String = "C", rules: String = "energy") -> RunState:
	var state := Lab.create(variant,"F1-D","warrior","full",rules)
	state._replace_enemy_actors([state._make_enemy("briarhook",Vector2(2900,1500),38)])
	state.room_clear_pending = false
	return state

func drain(state: RunState) -> void:
	var guard := 0
	while state.advance_streamed_action_tick() and guard < 2000: guard += 1
	check(guard < 2000,"stream terminates")

func hash_world(state: RunState, semantic: bool = false) -> String:
	return Lab.digest(Lab.authoritative(state,semantic))

func sequence(cuts: int, held: bool, mode: String, tempo: String, populated: bool) -> Dictionary:
	var state := Lab.create("B","F2") if populated else empty("B")
	if tempo == "speed": state.player_attributes["speed"] = 15
	if tempo == "frost": state.player_conditions["frost"] = 6.0
	check(state.request_combo(Vector2.RIGHT,false,held),"normal opener accepted")
	var trace: Array = []
	var max_phase := 0
	var sequence_id := int(state.player_action["combo_instance_id"])
	var guard := 0
	while String(state.player_action["kind"]) != "idle" and state.player_hp > 0 and guard < 1200:
		if state.lab_tick_blocked(state.SIM_DT):
			var before := hash_world(state)
			for _pause in range(37):
				state._tick(state.SIM_DT)
			check(hash_world(state) == before,"thinking cannot tick world")
			if int(state.player_action["committed_phase"])+1 < cuts: state.lab_continue(false)
			else: state.lab_recover()
		if held and int(state.player_action.get("committed_phase",0))+1 >= cuts: state.set_attack_hold(false)
		if mode == "direct": state._tick(state.SIM_DT)
		else: state.advance_streamed_action_tick()
		if String(state.player_action["kind"]) == "combo":
			max_phase = maxi(max_phase,int(state.player_action["committed_phase"]))
			check(int(state.player_action["combo_instance_id"]) == sequence_id,"sequence identity retained")
		trace.append(hash_world(state,true))
		guard += 1
	return {"trace":trace,"final":hash_world(state,true),"ticks":state._simulation_tick_index,"time":state.simulation_time,"energy":state.player_energy,"cuts":max_phase+1}

func test_parity() -> void:
	for populated in [false,true]:
		for tempo in ["base","speed","frost"]:
			for cuts in [1,2,3]:
				var tap := sequence(cuts,false,"stream",tempo,populated)
				var hold := sequence(cuts,true,"stream",tempo,populated)
				var direct := sequence(cuts,false,"direct",tempo,populated)
				check(tap["trace"] == hold["trace"],"tap/hold world trace parity %s %s %s" % [populated,tempo,cuts])
				check(tap["trace"] == direct["trace"],"direct/stream parity %s %s %s" % [populated,tempo,cuts])
				measurements.append({"parity":[populated,tempo,cuts],"tap":tap["final"],"hold":hold["final"],"direct":direct["final"],"ticks":tap["ticks"],"time":tap["time"],"energy":tap["energy"]})
	# The synchronous loop must return at each unresolved decision and later finish.
	var sync := empty("B")
	sync.request_combo(Vector2.RIGHT,true)
	check(sync.lab_junction() and not sync.is_player_ready(),"synchronous stops pending without becoming ready")
	check(is_equal_approx(sync.simulation_time,76.0/120.0),"first pre-tick stop quantized to 76 ticks")
	sync.request_combo(Vector2.RIGHT,true)
	check(sync.lab_junction() and int(sync.player_action["committed_phase"]) == 1,"sync resumes one token to second junction")
	sync.lab_recover()
	sync._simulate_until_ready()
	check(sync.is_player_ready(),"sync serves recovery")
	var stream := empty("B")
	stream.request_combo(Vector2.RIGHT,false)
	drain(stream)
	stream.lab_continue()
	drain(stream)
	stream.lab_recover()
	drain(stream)
	check(hash_world(sync,true) == hash_world(stream,true),"sync/stream full authoritative result parity")

func test_freeze_and_tokens() -> void:
	var state := Lab.create("C","F2")
	state.player_conditions["burning"] = 4.0
	state.player_conditions["frost"] = 4.0
	state.rally_active = true
	state.battle_flow_pips = 2
	state.battle_flow_remaining = 10.0
	state.begin_cooldown("dodge",2.0)
	state._spawn_player_fire(state.player_pos+Vector2(400,400))
	state.request_combo(Vector2.RIGHT,false)
	drain(state)
	check(state.lab_junction(),"populated timer fixture reaches junction")
	state._spawn_projectile(state.enemies[2])
	check(not state.projectiles.is_empty(),"freeze probe includes an in-flight projectile")
	var frozen := hash_world(state)
	for _frame in range(300): state._tick(state.SIM_DT)
	check(frozen == hash_world(state),"junction freezes conditions hazards resources AI RNG cooldowns")
	var frame = Frame.new()
	check(frame.capture(state)["player_action"]["lab_pending"],"stream frame carries pending fact")
	check(state.snapshot()["player_action"]["lab_pending"],"snapshot carries pending fact")
	check(Schema.validate("action",state.player_action).is_empty(),"pending schema valid")
	check(not Schema.validate("action",{"kind":"idle","elapsed":0.0,"duration":0.0,"lab_pending":true}).is_empty(),"schema rejects impossible pending")
	state.lab_continue(false)
	state.set_attack_hold(false)
	state.advance_streamed_action_tick()
	check(int(state.player_action.get("committed_phase",0)) == 1,"release preserves accepted one-cut token")
	var early := empty()
	early.request_combo(Vector2.RIGHT,false)
	early.resume_combo_hold()
	early.set_attack_hold(false)
	drain(early)
	check(early.lab_junction() and int(early.player_action["committed_phase"]) == 0,"early released tap cannot bank future cut")

func test_exit_debt() -> void:
	for entry in [["move",1],["dodge",1],["move",2],["dodge",2]]:
		var queued: String = entry[0]
		var state := empty()
		state.request_combo(Vector2.RIGHT,false)
		drain(state)
		if int(entry[1]) == 2:
			state.lab_continue()
			drain(state)
		var pos := state.player_pos
		var energy := state.player_energy
		var exit_time := state.player_control_world_remaining()
		var began_at := state.simulation_time
		check(state.request_move(Vector2.DOWN,34,false) if queued == "move" else state.request_dodge(Vector2.DOWN,false),"queued exit accepted")
		check(not state.resume_combo_hold(),"closed recovery cannot reopen")
		check(not state.request_move(Vector2.UP,34,false),"cannot overwrite accepted exit")
		while String(state.player_action["kind"]) == "combo":
			check(state.player_pos == pos and state.player_energy == energy,"no early motion or new-action charge during debt")
			state.advance_streamed_action_tick()
		check(state.simulation_time-began_at+0.00001 >= exit_time,"full exit time served before queued action")
		check(String(state.player_action["kind"]) == queued,"exact captured exit starts")
		check(Vector2(state.player_action["direction"]) == Vector2.DOWN,"captured direction retained")
		measurements.append({"debt":queued,"junction":entry[1],"owed":exit_time,"served":state.simulation_time-began_at})
	var interrupted := empty()
	interrupted.request_combo(Vector2.RIGHT,false)
	drain(interrupted)
	interrupted.request_dodge(Vector2.DOWN,false)
	interrupted._resolve_incoming_hit(-1,14,"blade",interrupted.player_pos+Vector2.RIGHT*60,interrupted.player_pos+Vector2.RIGHT*30)
	drain(interrupted)
	check(interrupted.is_player_ready() and not interrupted.player_action.has("lab_exit_request"),"forced hit clears queued exit; no deferred Dodge")

func dummy(rules: String = "energy") -> RunState:
	var state := Lab.create("C","F1-P","warrior","full",rules)
	var enemy: Dictionary = state.enemies[0]
	enemy["hp"] = 1000
	enemy["max_hp"] = 1000
	enemy["posture"] = 1000.0
	enemy["posture_max"] = 1000.0
	enemy["action"] = state._action("hit_reaction",100.0,Vector2.ZERO)
	return state

func start_commit(state: RunState) -> bool:
	state.lab_input_neutral()
	return state.lab_toggle_commit() and state.lab_target(int(state.enemies[0]["id"]))

func test_commit() -> void:
	for rules in ["energy","recovery"]:
		var state := dummy(rules)
		var facing := state.player_facing
		var decision := Lab.decision_digest(state)
		check(state.lab_toggle_commit(),"arm ready sword")
		check(Lab.decision_digest(state) != decision,"arming changes complete decision digest")
		var before := hash_world(state)
		check(not state.lab_target(-1),"invalid Commit target refused")
		check(before == hash_world(state) and state.lab_armed and state.player_facing == facing,"invalid target preserves world and arm")
		for _frame in range(80): state._tick(state.SIM_DT)
		check(before == hash_world(state),"arming freezes world")
		state.player_energy = 35.999
		if rules == "energy":
			check(not state.lab_target(101) and state.lab_armed,"full-cost threshold refuses 35.999")
		state.player_energy = 36.0
		check(state.lab_target(101),"exact full-cost Commit accepted")
		check(not state.lab_armed and bool(state.player_action["lab_prepaid"]),"arm consumed and prepaid marked")
		var paid_digest := hash_world(state)
		state.player_action["lab_prepaid"] = false
		check(hash_world(state) != paid_digest,"paid mode changes authoritative fingerprint")
		state.player_action["lab_prepaid"] = true
		var cost := state.energy_spent_total
		var full := state.player_commitment_world_remaining()
		var cut := state.player_control_world_remaining()
		check(full > cut+1.0,"full horizon differs from current cut")
		check(not state.request_dodge(Vector2.LEFT,false) and not state.request_move(Vector2.LEFT,34,false),"Commit cannot voluntarily cancel")
		state.set_attack_hold(false)
		check(bool(state.player_action["continue_held"]),"release cannot shorten Commit")
		drain(state)
		check(state.is_player_ready(),"Commit finishes all recovery")
		check(state.energy_spent_total == cost,"prepaid cuts never double charge")
		check(1000-int(state.enemies[0]["hp"]) == (50 if rules == "energy" else 45),"Commit actual damage matches authored finisher payoff")
		check(state.lab_neutral_required and not state.request_combo(Vector2.RIGHT,false,true),"held next sequence refused until neutral")
		check(state.overexertion_count == (1 if rules == "energy" else 0),"exhaustion settles once")
		measurements.append({"commit":rules,"cost":cost,"damage":1000-int(state.enemies[0]["hp"]),"full":full,"cut":cut,"time":state.simulation_time,"exhaustions":state.overexertion_count})
	var rally := dummy()
	rally.rally_active = true
	rally.player_energy = 36.0
	check(start_commit(rally),"Rally uses modified actual phase costs")
	drain(rally)
	check(rally.is_player_ready() and rally.overexertion_count <= 1,"Rally loss cannot abort paid cuts; exhaustion once")
	var interrupted := dummy()
	check(start_commit(interrupted),"interruption setup")
	var paid := interrupted.energy_spent_total
	interrupted.player_action["poise_remaining"] = 0.0
	interrupted._resolve_incoming_hit(-1,30,"blade",interrupted.player_pos+Vector2.RIGHT*60,interrupted.player_pos+Vector2.RIGHT*30)
	drain(interrupted)
	check(interrupted.energy_spent_total == paid and not interrupted.lab_armed,"forced hit no refund or rearm")
	check(not bool(interrupted.player_action.get("lab_prepaid",false)),"legitimate hit replacement ends Commit")
	var killed := Lab.create("C","F1-P")
	killed.enemies[0]["hp"] = 5
	check(start_commit(killed),"last kill setup")
	var ticks := 0
	while killed.advance_streamed_action_tick():
		if killed.enemies.is_empty() and String(killed.player_action["kind"]) == "combo": check(not killed.trial_complete,"last kill cannot hand over early")
		ticks+=1
		if ticks>1000: break
	check(killed.trial_complete and killed.simulation_time >= 2.46,"last kill waits through full Commit")
	var miss := dummy()
	check(start_commit(miss),"moving target setup")
	var launch_pos := miss.player_pos
	miss._set_enemy_position(miss.enemies[0],Vector2(2600,800))
	drain(miss)
	check(miss.damage_dealt == 0 and miss.player_pos == launch_pos and miss.simulation_time >= 2.46 and miss.energy_spent_total == 36.0,"target leaving range cannot cancel chase home or refund Commit")
	var poise := dummy()
	poise.request_combo(Vector2.UP,false)
	poise._resolve_incoming_hit(-1,1,"blade",poise.player_pos+Vector2.RIGHT*60,poise.player_pos+Vector2.RIGHT*30,0.5)
	var guard := float(poise.player_action.get("guard_remaining",0.0))
	var id := int(poise.player_action.get("combo_instance_id",-1))
	drain(poise)
	check(poise.lab_junction(),"poise test reaches normal junction")
	poise.lab_continue()
	poise.advance_streamed_action_tick()
	check(float(poise.player_action.get("guard_remaining",0.0)) == guard and int(poise.player_action.get("combo_instance_id",-2)) == id,"continuation preserves spent same-sequence poise")
	var sleep := dummy()
	check(start_commit(sleep),"sleep replacement setup")
	var sleep_cost := sleep.energy_spent_total
	sleep.apply_player_condition_buildup("sleep",1000.0)
	check(String(sleep.player_action["kind"]) == "sleep" and sleep.lab_neutral_required,"actual sleep condition replaces Commit and requires neutral")
	drain(sleep)
	check(sleep.energy_spent_total == sleep_cost and not sleep.lab_armed,"sleep replacement cannot refund or resume")
	var target := dummy()
	target.lab_toggle_commit()
	var enemy: Dictionary = target.enemies[0]
	for invalid in ["dead","layer","friendly","far"]:
		var saved := enemy.duplicate(true)
		match invalid:
			"dead": enemy["hp"] = 0
			"layer": enemy["layer"] = "other"
			"friendly": enemy["faction"] = "player"
			"far": enemy["pos"] = Vector2(2900,1500)
		var world := hash_world(target)
		check(not target.lab_target(101) and target.lab_armed and hash_world(target) == world,"invalid %s target preserves transaction" % invalid)
		enemy.clear()
		enemy.merge(saved)

func test_control_budgets() -> void:
	var state := dummy()
	check(start_commit(state),"control budget setup")
	for _tick in range(40): state.advance_streamed_action_tick()
	var enemy: Dictionary = state.enemies[0]
	var full := state.player_commitment_world_remaining()
	var cut := state.player_control_world_remaining()
	check(is_equal_approx(state._player_commitment_remaining(),cut),"Shield/Polearm private helper retains current visible strike horizon")
	enemy["action"] = state._idle_action()
	state._apply_enemy_hit_reaction(enemy,1.8,"alerted",enemy["action"].duplicate(true))
	var flinch := float(enemy["action"]["duration"])
	check(flinch >= cut-0.0001 and flinch < full,"ordinary flinch uses cut budget")
	enemy["posture"] = 0.0
	enemy["action"] = state._idle_action()
	state._apply_actor_posture_damage(enemy,2.0,enemy["pos"],"player","test")
	var stagger := float(enemy["action"]["duration"])
	check(stagger >= cut+0.72-0.0001 and stagger < full+0.72,"posture floor uses current cut plus .72")
	measurements.append({"budgets":{"full":full,"cut":cut,"flinch":flinch,"stagger":stagger}})
	var guard := Lab.create("C","F3-K")
	var kiln: Dictionary = guard.enemies[0]
	check(not guard._apply_enemy_hit_reaction(kiln,1.8,"alerted",kiln["action"].duplicate(true)),"Kiln protected startup holds")
	kiln["action"]["elapsed"] = 1.03
	check(guard._apply_enemy_hit_reaction(kiln,1.8,"alerted",kiln["action"].duplicate(true)),"Kiln recovery can flinch")

func test_suspend_fixtures() -> void:
	for pending in [false,true]:
		var state := empty()
		state.request_combo(Vector2.RIGHT,false)
		if pending: drain(state)
		state.lab_suspend()
		check(state.is_player_ready() and state.lab_neutral_required,"suspend pays normal debt and requires neutral")
	var commit := dummy()
	start_commit(commit)
	commit.lab_suspend()
	check(commit.is_player_ready() and commit.simulation_time >= 2.46,"suspend finishes running Commit")
	check(not commit.save_run("user://must-not-exist.save") and not commit.load_run(),"lab bypasses normal save/load")
	var manifests: Array = []
	for variant in Lab.VARIANTS:
		for fixture in Lab.FIXTURES:
			var state := Lab.create(variant,fixture)
			var record := Lab.manifest(state,fixture,"full")
			check(state._simulation_tick_index == 0 and state.simulation_time == 0.0,"fixture frozen entry")
			for enemy in record["actors"]:
				if fixture != "F0" or int(enemy["id"])/100 == 100: check(enemy["occupiable"],"fixture actor legal occupancy %s %s %s" % [variant,fixture,enemy["id"]])
			manifests.append(record)
	var c := Lab.create("C","F2")
	var e := Lab.create("E","F2")
	check(hash_world(c) == hash_world(e),"E initial world identical to C")
	var g := Lab.create("G","F2")
	check(Vector2(g.enemies[2]["pos"]) == Vector2(1810,1060),"G exact Archer seat")
	check(g._has_line_of_sight(g.player_pos,g.enemies[2]["pos"]),"G seat initial LOS")
	var low := Lab.create("C","F1","warrior","low")
	check(low.player_hp == 60 and low.player_energy == 35.0,"declared low arrival")
	var sweep := Lab.create("C","F2","warrior","sweep")
	check(sweep.character_level() == 2 and sweep.has_track_rank("swordsmanship",1) and sweep.player_equipped_weapon_art == "prototype_sweeping_cut","legal level-two sweeping cut")
	var file := FileAccess.open("res://.runtime/fixture-manifests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(Lab.json_safe(manifests),"\t"))

func _init() -> void:
	test_parity()
	test_freeze_and_tokens()
	test_exit_debt()
	test_commit()
	test_control_budgets()
	test_suspend_fixtures()
	var file := FileAccess.open("res://.runtime/lab-contract-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(Lab.json_safe({"checks":checks,"failures":failures,"measurements":measurements}),"\t"))
	for failure in failures: print("FAILED: ",failure)
	print("LAB CONTRACT checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
