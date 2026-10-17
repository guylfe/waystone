extends SceneTree
# Acceptance driver. After start_run this file writes no HP, Energy, XP, actor
# positions, enemy actions, inventory, or outcome flags. Only public player
# requests advance the world. Knowledge of the authored route is not combat AI.
const State = preload("res://scripts/core/run_state.gd")
const Economy = preload("res://scripts/core/expedition_economy.gd")
var failures: Array[String] = []
var planner = preload("res://tests/expedition_action_planner.gd").new()
var use_planner := false
var navigation: Array[Vector2] = []
var navigation_target := Vector2.INF
var last_move_origin := Vector2.INF
var stationary_moves := 0
var combat_target_id := -1

func clear_step(state, origin: Vector2, target: Vector2, ignore_bodies: bool = true) -> bool:
	# Endpoint-only tests can jump across a thin retaining wall in the planner
	# even though the real, ticked movement correctly stops at that wall.
	var pieces := maxi(1,ceili(origin.distance_to(target)/8.0))
	for piece in range(1,pieces+1):
		if not state._can_occupy(origin.lerp(target,float(piece)/pieces),State.PLAYER_RADIUS,0,ignore_bodies): return false
	return true

func plan_path(state, target: Vector2) -> void:
	navigation.clear()
	navigation_target = target
	var spacing := 52.0
	var origin: Vector2 = state.player_pos
	var start := Vector2i.ZERO
	var open: Array[Vector2i] = [start]
	var cost := {start:0.0}
	var came := {}
	var closed := {}
	for iteration in range(1600):
		if open.is_empty(): return
		var best := 0
		for index in range(1,open.size()):
			if float(cost[open[index]])+(origin+Vector2(open[index])*spacing).distance_to(target)<float(cost[open[best]])+(origin+Vector2(open[best])*spacing).distance_to(target): best=index
		var cell: Vector2i = open.pop_at(best)
		var point := origin+Vector2(cell)*spacing
		if point.distance_to(target)<70:
			while cell!=start:
				navigation.push_front(origin+Vector2(cell)*spacing)
				cell=came[cell]
			return
		closed[cell]=true
		for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
			var next: Vector2i = cell+offset
			if closed.has(next): continue
			var destination := origin+Vector2(next)*spacing
			if not clear_step(state,point,destination): continue
			var score := float(cost[cell])+point.distance_to(destination)
			if score>=float(cost.get(next,INF)): continue
			cost[next]=score
			came[next]=cell
			if not open.has(next): open.append(next)

func move(state, target: Vector2) -> bool:
	stationary_moves = stationary_moves+1 if state.player_pos.distance_to(last_move_origin)<2 else 0
	last_move_origin=state.player_pos
	if stationary_moves>=3:
		plan_path(state,target)
		stationary_moves=0
	if target.distance_to(navigation_target)>100: navigation.clear()
	while not navigation.is_empty() and state.player_pos.distance_to(navigation[0])<18: navigation.pop_front()
	if not navigation.is_empty(): target=navigation[0]
	var direction: Vector2 = state.player_pos.direction_to(target)
	if navigation.is_empty() and not clear_step(state,state.player_pos,state.player_pos+direction*State.MOVE_RANGE):
		plan_path(state,target)
		if not navigation.is_empty():
			target=navigation[0]
			direction=state.player_pos.direction_to(target)
	for angle in [0.0,0.45,-0.45,0.9,-0.9,1.3,-1.3,1.57,-1.57,2.0,-2.0,2.5,-2.5,PI]:
		var candidate := direction.rotated(angle)
		if clear_step(state,state.player_pos,state.player_pos+candidate*State.MOVE_RANGE,false):
			return state.request_move(candidate,minf(State.MOVE_RANGE,state.player_pos.distance_to(target)),false)
	return state.request_wait(0.08,false)

func upgrade(state) -> void:
	while state.can_open_level_sheet():
		var options: Array = state.available_level_up_options()
		var selected := String(options[0])
		var priorities := ["swordsmanship","staff","knife","bow","evasion","steadfast","finesse","measured","patient","adopted"]
		if state.loadout_id=="mage_elementalist": priorities = ["mage","elementalist","measured","evasion","staff","adopted"]
		for preferred in priorities:
			if options.has(preferred):
				selected = preferred
				break
		var stage: Dictionary = state.next_track_stage(selected)
		var choices: Array = stage.get("choices",[])
		if not choices.is_empty(): selected += "|"+String(choices[0]["id"])
		if not state.choose_upgrade(selected): break

func collect(state) -> void:
	var pickup: Dictionary = state.nearby_pickup()
	if pickup.is_empty(): return
	if Economy.Catalog.EQUIPMENT.has(pickup["item_id"]):
		var slot := String(Economy.Catalog.EQUIPMENT[pickup["item_id"]]["slot"])
		if String(state.expedition["equipment"].get(slot,""))=="": Economy.equip(state,String(pickup["id"]))
	else:
		state.request_collect_nearby_pickup(false)
		if state.has_pending_pickup(): state.replace_pending_pickup(0,false)

func shop(state, discipline: String) -> void:
	if not Economy.at_merchant(state): return
	if state.expedition["biome"]==1 and state.expedition["discipline"]=="": Economy.adopt(state,discipline)
	var priorities := ["trail_ration","gripping_gloves","trailcoat","runner_boots"]
	if state.loadout_id=="mage_elementalist": priorities = ["trail_ration","inscribed_gloves","channeler_wrap","trailcoat","runner_boots"]
	if state.loadout_id=="rogue_sharpshooter": priorities = ["trail_ration","fletcher_gloves","trailcoat","runner_boots"]
	for id in priorities:
		if Economy.Catalog.EQUIPMENT.has(id) and state.expedition["equipment"].has(Economy.Catalog.EQUIPMENT[id]["slot"]): continue
		if id=="trail_ration":
			var quantity := 0
			for slot in range(3):
				if state.consumable_slot(slot)["id"]==id: quantity+=int(state.consumable_slot(slot)["count"])
			if quantity>=2: continue
		if Economy.purchase(state,id):
			collect(state)
			return

func combat(state, enemy: Dictionary) -> bool:
	var position := Vector2(enemy["pos"])
	var distance: float = state.player_pos.distance_to(position)
	var direction: Vector2 = state.player_pos.direction_to(position)
	var soonest := 999.0
	var close_count := 0
	# Only visible tells/projectiles are consulted; no future attack selection.
	for other in state.enemies:
		if not state.is_visible(other["pos"]) or bool(other.get("reserve",false)): continue
		var action: Dictionary = other["action"]
		if state.player_pos.distance_to(other["pos"])<190: close_count+=1
		var kind := String(action["kind"])
		if kind not in ["melee","charge","expedition_attack","dodge_strike"]: continue
		if String(action.get("shape","")) in ["fan","zone","wind","gong"]: continue
		var until: float = (float(action.get("startup",0.5))-float(action["elapsed"]))/state._enemy_personal_tempo(other)
		var reach := float(action.get("reach",250.0))+80.0
		if kind=="charge" or String(action.get("shape","")) in ["drive","flight"]:
			if float(action["elapsed"])>float(action.get("active_end",0)): continue
			reach += 350
			until = maxf(0,until)+maxf(0,state.player_pos.distance_to(other["pos"])-float(other["radius"])-State.PLAYER_RADIUS)/maxf(1,float(action.get("speed",500)))
		if state.player_pos.distance_to(other["pos"])<reach and until>0: soonest=minf(soonest,until)
	for shot in state.projectiles:
		if int(shot.get("source_id",0))==0 or not state.is_visible(shot["pos"]): continue
		var delta: Vector2 = state.player_pos-Vector2(shot["pos"])
		var velocity := Vector2(shot["vel"])
		if velocity.normalized().dot(delta.normalized())>0.96: soonest=minf(soonest,delta.length()/maxf(1.0,velocity.length()))
	if soonest<0.24:
		if state.loadout_id=="rogue_acrobat" and state.player_energy>=33 and state.request_vault(direction,false): return true
		for sign_value in [1,-1]:
			var evade: Vector2 = (direction.orthogonal()*sign_value+direction*0.6).normalized()
			if state._can_occupy(state.player_pos+evade*150,State.PLAYER_RADIUS,0) and state.request_dodge(evade,false): return true
	if soonest<0.55: return state.request_wait(0.04,false)
	for hazard in state.hazards:
		if int(hazard.get("source_id",0))==0: continue
		var center := Vector2(hazard["pos"])
		if state.player_pos.distance_to(center)<float(hazard.get("radius",140))+90:
			return move(state,state.player_pos+center.direction_to(state.player_pos)*100)
	if state.player_hp<=state.player_max_hp-25 and soonest>0.85 and state.potions>0:
		return state.request_potion(false)
	if state.player_hp<=state.player_max_hp-15 and soonest>0.8:
		for slot in range(3):
			if state.consumable_slot(slot)["id"]=="trail_ration" and state.request_consumable(slot,Vector2.ZERO,false): return true
	if state.player_energy<28: return move(state,state.player_pos-direction*34)
	if state.player_energy>60 and state.cooldown_remaining("adopted")<=0 and state.expedition["discipline"]!="":
		if state.request_adopted(position,false): return true
	if state.loadout_id=="warrior" and distance>120 and distance<270 and state.advance_cooldown<=0:
		if state.request_advance(direction,false,false): return true
	if close_count>=2 and state.player_energy>60 and state.request_skill(direction,false): return true
	if state.loadout_id=="mage_elementalist" and distance>150 and distance<500 and state.player_energy>65 and soonest>0.85:
		if state.request_spell("lightning_bolt",position,false): return true
	if state.player_equipped_weapon_art=="knife_execution" and distance<160 and state.player_energy>60 and soonest>0.9:
		if state.request_skill(direction,false): return true
	if state.player_weapon_frame=="bow" and distance<580 and soonest>0.9:
		return state.begin_bow_draw(direction,int(enemy["id"]))
	if distance<(78.0 if state.player_weapon_frame in ["knife","twin_knives"] else 105.0):
		if state.request_combo(direction,false,int(enemy.get("expedition_site",-1))!=9): return true
	return move(state,position)

func play(loadout: String, seed_value: int, discipline: String) -> void:
	var attempt_id := str(int(Time.get_unix_time_from_system()))
	var state := State.new(false)
	state.start_run(loadout,"expedition",seed_value)
	var biome := -1
	var route: Array = []
	var checkpoint := 0
	var actions := 0
	var progress_at := 0
	for tick in range(240000):
		if state.death_pending or state.trial_complete: break
		if state.player_action["kind"]=="bow_draw" and float(state.player_action["elapsed"])>=0.90: state.release_bow_attack()
		if not use_planner and state.player_action["kind"]=="combo":
			for other in state.enemies:
				if not state.is_visible(other["pos"]) or state.player_pos.distance_to(other["pos"])>340: continue
				var hostile: Dictionary = other["action"]
				if hostile["kind"] not in ["melee","charge","dodge_strike","expedition_attack"]: continue
				var until: float = (float(hostile.get("startup",0))-float(hostile["elapsed"]))/state._enemy_personal_tempo(other)
				if until>0 and until<0.6: state.set_attack_hold(false)
		if state.is_player_ready():
			actions += 1
			if biome!=int(state.expedition["biome"]):
				biome = int(state.expedition["biome"])
				navigation.clear()
				navigation_target=Vector2.INF
				route = [{"pos":Vector2(650,3450),"site":-1},{"pos":Vector2(450,2300),"site":-1}]
				for site in range(6):
					route.append({"pos":state.expedition_sites[site]["pos"],"site":site})
					if site==2: route.append({"pos":state.expedition_markers["landmark"],"site":-1})
				route.append({"pos":state.expedition_markers["preparation"],"site":-1})
				route.append({"pos":Vector2(11900,2200),"site":9})
				route.append({"pos":state.bonfire_pos,"site":-1})
				route.append({"pos":state.expedition_markers["exit"],"site":-1})
				checkpoint = 0
				print(loadout," enters biome ",biome," HP ",state.player_hp," level ",state.character_level())
			upgrade(state)
			var enemy: Dictionary = {}
			var nearest := 650.0
			for other in state.enemies:
				if bool(other.get("reserve",false)) or not state.is_visible(other["pos"]): continue
				var distance: float = state.player_pos.distance_to(other["pos"])
				if distance<nearest:
					nearest=distance
					enemy=other
			# Finish a chosen visible foe instead of repeatedly changing targets
			# as a group circles. This is player policy, not an awareness mutation.
			var focused: Dictionary = state._enemy_by_id(combat_target_id)
			if not focused.is_empty() and state.is_visible(focused["pos"]) and state.player_pos.distance_to(focused["pos"])<450:
				enemy=focused
				nearest=state.player_pos.distance_to(focused["pos"])
			combat_target_id=int(enemy.get("id",-1))
			if not enemy.is_empty():
				# A one-action optimizer can prefer never alerting a durable boss:
				# standing safely forever scores above the first costly engagement.
				# Initiate with an ordinary legal attack; do not edit its awareness.
				if use_planner and state.loadout_id=="rogue_acrobat" and int(enemy.get("expedition_site",-1))==9 and String(enemy.get("awareness","idle"))!="alerted" and state.player_energy>35:
					var direction: Vector2 = state.player_pos.direction_to(enemy["pos"])
					if nearest<=110:
						if state.player_equipped_weapon_art!="knife_execution" or not state.request_skill(direction,false): state.request_combo(direction,false,true)
					else: move(state,enemy["pos"])
				elif use_planner: planner.choose(state,enemy)
				else: combat(state,enemy)
			else:
				collect(state)
				# Spend finite discovered food safely before entering the next fight.
				# This is an ordinary timed use, not an acceptance-test heal.
				if state.is_player_ready() and state.player_hp<=state.player_max_hp-15:
					for slot in range(3):
						if state.consumable_slot(slot)["id"]=="trail_ration" and state.request_consumable(slot,Vector2.ZERO,false): break
				if state.is_player_ready(): shop(state,discipline)
				if state.is_player_ready():
					if state.player_pos.distance_to(state.bonfire_pos)<100: state.activate_waystone()
					var point: Vector2 = route[checkpoint]["pos"]
					if state.player_pos.distance_to(point)<80 and (int(route[checkpoint]["site"])<0 or state._area_is_clear(int(route[checkpoint]["site"]))):
						print(loadout," checkpoint ",checkpoint," HP ",state.player_hp," potions ",state.potions," level ",state.character_level())
						checkpoint+=1
						progress_at=actions
						if checkpoint>=route.size():
							state.request_expedition_departure()
							state.request_expedition_departure(true)
						else: move(state,route[checkpoint]["pos"])
					else: move(state,point)
			if state.is_player_ready() and not state.trial_complete: state.request_wait(0.05,false)
			if actions-progress_at>4000:
				print("STALLED at ",state.player_pos," checkpoint ",checkpoint)
				state.save_run("res://.runtime/stalled-%s.save" % loadout)
				break
			if actions%50==0: print("PROGRESS ",loadout," ",state.player_pos," target ",enemy.get("pos",Vector2.ZERO)," HP ",state.player_hp," E ",state.player_energy," enemy HP ",enemy.get("hp",0))
		state.advance_streamed_action_tick()
	var summary := "%s seed %d: victory=%s biome=%d checkpoint=%d HP=%d level=%d actions=%d time=%.1f" % [loadout,seed_value,state.expedition["victory"],biome,checkpoint,state.player_hp,state.character_level(),actions,state.simulation_time]
	print(summary)
	print("Potions ",state.potions," used ",state.potions_used_total," remaining enemies ",state.enemies.size()," damage dealt ",state.damage_dealt)
	if not bool(state.expedition["victory"]): failures.append(summary)
	var evidence := FileAccess.open("res://.runtime/playthrough-%s-%s.json" % [loadout,attempt_id],FileAccess.WRITE)
	evidence.store_string(JSON.stringify({"summary":summary,"actions":state.survey_action_counts,"events":state.expedition["events"]},"\t"))

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	use_planner = args.has("search")
	planner.short_horizon = args.has("short")
	var loadouts: Array = ["warrior","rogue_acrobat","rogue_sharpshooter","mage_elementalist"] if args.is_empty() else [args[0]]
	for index in loadouts.size(): play(loadouts[index],int(args[2]) if args.size()>2 else 42,args[1] if args.size()>1 else ("trapper" if index%2==0 else "sapper"))
	for failure in failures: print("FAILED: ",failure)
	quit(0 if failures.is_empty() else 1)
