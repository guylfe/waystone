extends SceneTree
const Lab = preload("res://scripts/experiments/combat_lab_catalog.gd")
const Geometry = preload("res://scripts/core/attack_geometry.gd")
var summaries: Array = []

class Trace:
	extends RefCounted
	var state: RunState
	var inputs: Array = []
	var events: Array = []
	var samples: Array = []
	var fixture: String
	var variant: String
	var initial: Dictionary
	var start_hp: int
	var attack_time := 0.0
	var retreat_distance := 0.0
	var stalls := 0
	var last_event := ""
	var hits: Array = []
	var exit_damage := 0
	var first_damage_time := -1.0
	func _init(v: String, f: String, profile: String = "full", loadout: String = "warrior") -> void:
		state = Lab.create(v,f,loadout,profile)
		fixture = f
		variant = v
		initial = Lab.manifest(state,f,profile)
		start_hp = state.player_hp
		sample(true)
	func sample(force: bool = false) -> void:
		var actors: Array = []
		var event_key := str(state.player_hp)+":"+str(state.damage_dealt)
		for enemy in state.enemies:
			var action: Dictionary = enemy["action"]
			event_key += str([enemy["id"],enemy["hp"],action.get("kind"),action.get("started_at"),action.get("ability_id"),action.get("technique_id")])
			actors.append({"id":enemy["id"],"pos":enemy["pos"],"facing":enemy["facing"],"hp":enemy["hp"],"posture":enemy["posture"],"action":action.duplicate(true),"gap":state.player_pos.distance_to(enemy["pos"]),"los":state._has_line_of_sight(state.player_pos,enemy["pos"])})
		var changed := event_key != last_event
		if force or changed or state._simulation_tick_index % 12 == 0:
			var record := {"tick":state._simulation_tick_index,"time":state.simulation_time,"player":state.player_pos,"facing":state.player_facing,"hp":state.player_hp,"energy":state.player_energy,"posture":state.player_posture,"action":state.player_action.duplicate(true),"full":state.player_commitment_world_remaining(),"cut":state.player_control_world_remaining(),"actors":actors,"projectiles":state.projectiles.duplicate(true),"notice":state.lab_notice,"threats":state._threat_snapshot()}
			samples.append(record)
			if changed:
				events.append(record)
				last_event = event_key
	func submit(kind: String, direction: Vector2 = Vector2.ZERO, value: float = 1.0) -> bool:
		state.lab_input_neutral()
		var accepted := false
		var before := state.player_pos
		match kind:
			"move": accepted = state.request_move(direction,34,false)
			"dodge": accepted = state.request_dodge(direction,false)
			"wait": accepted = state.request_wait(value,false)
			"attack": accepted = state.request_combo(direction,false)
			"continue": accepted = state.lab_continue()
			"recover": accepted = state.lab_recover()
			"sweep": accepted = state.request_skill(direction,false)
			"commit": accepted = state.lab_toggle_commit() and state.lab_target(int(value))
			"draw": accepted = state.begin_bow_draw(direction,int(value))
			"release": accepted = state.release_bow_attack(direction)
			"spell": accepted = state.request_spell(state.selected_spell,state.player_pos+direction*250,false)
		inputs.append({"kind":kind,"direction":[direction.x,direction.y],"value":value,"accepted":accepted,"tick":state._simulation_tick_index,"visible_state":Lab.decision_digest(state)})
		if not accepted:
			sample(true)
			return false
		var guard := 0
		while guard < 1800:
			if kind == "draw" and float(state.player_action.get("elapsed",0.0)) >= 0.9: break
			var hp := state.player_hp
			var was_attack := String(state.player_action["kind"]) in ["combo","sweep","bow_draw","bow_release"]
			var was_exit := String(state.player_action["kind"]) == "combo" and bool(state.player_action.get("terminal_recovery_locked",false))
			if not state.advance_streamed_action_tick(): break
			if was_attack: attack_time += state.SIM_DT
			if was_exit: exit_damage += hp-state.player_hp
			if state.damage_dealt > 0 and first_damage_time < 0: first_damage_time = state.simulation_time
			var ids: Array = state.player_action.get("hit_ids",[])
			if String(state.player_action.get("kind","")) == "sweep":
				for id in ids:
					if not hits.has(id): hits.append(id)
			sample()
			guard += 1
		if kind == "move":
			if before.distance_to(state.player_pos) < 1: stalls += 1
			if direction.x < -0.5: retreat_distance += before.distance_to(state.player_pos)
		sample(true)
		return true
	func single(direction: Vector2) -> void:
		if submit("attack",direction) and state.lab_junction(): submit("recover")
	func nearest() -> Dictionary:
		var result: Dictionary = {}
		var distance := INF
		for enemy in state.enemies:
			var gap := state.player_pos.distance_to(enemy["pos"])
			if gap < distance:
				distance = gap
				result = enemy
		return result
	func approach(limit: int = 10, gap: float = 110.0) -> void:
		for _step in range(limit):
			var enemy := nearest()
			if enemy.is_empty() or state.player_hp <= 0 or state.player_pos.distance_to(enemy["pos"]) <= gap: return
			submit("move",state.player_pos.direction_to(enemy["pos"]))
	func sweep_targets() -> Array:
		var enemy := nearest()
		if enemy.is_empty(): return []
		var phases := state._sword_phases(false)
		var final: Dictionary = phases[-1]
		var facing := state.player_pos.direction_to(enemy["pos"])
		var action := {"technique_id":final["technique"],"reach":final["reach"],"elapsed":0.5,"startup":0.0,"active_end":1.0,"duration":1.5}
		var pose := Geometry.pose(action,state.player_pos,facing,state.walls)
		var ids: Array = []
		for target in state.enemies:
			if Geometry.hits_circle(pose,target["pos"],float(target["radius"])): ids.append(target["id"])
		return ids
	func finish(name: String, extra: Dictionary = {}) -> Dictionary:
		var result := {"name":name,"variant":variant,"fixture":fixture,"hp_lost":start_hp-state.player_hp,"damage":state.damage_dealt,"time":state.simulation_time,"attack_time":attack_time,"attack_dps":state.damage_dealt/maxf(attack_time,0.001),"encounter_dps":state.damage_dealt/maxf(state.simulation_time,0.001),"energy_spent":state.energy_spent_total,"energy":state.player_energy,"remaining_enemies":state.enemies.size(),"retreat_distance":retreat_distance,"stalls":stalls,"sweep_hit_ids":hits,"damage_during_exit":exit_damage,"first_damage_time":first_damage_time,"final_digest":Lab.digest(Lab.authoritative(state)),"dead":state.player_hp<=0,"clear":state.trial_complete,"input_count":inputs.size()}
		result.merge(extra)
		if result.has("boundary_limited"):
			result["boundary_limited"] = stalls > 0 and state.player_hp > 0 and (state.player_pos.x < 70 or state.player_pos.y < 70 or state.player_pos.x > state.world_size.x-70 or state.player_pos.y > state.world_size.y-70)
		var file := FileAccess.open("res://.runtime/policy-traces/"+name+"-"+variant+".json",FileAccess.WRITE)
		file.store_string(JSON.stringify(Lab.json_safe({"initial":initial,"inputs":inputs,"events":events,"samples":samples,"summary":result}),"\t"))
		return result

func opening(variant: String, fixture: String, policy: String) -> void:
	var trace := Trace.new(variant,fixture)
	match policy:
		"four_down", "four_left":
			for _step in range(4): trace.submit("move",Vector2.DOWN if policy == "four_down" else Vector2.LEFT)
			trace.approach(8)
		"side_dodge":
			trace.submit("dodge",Vector2.DOWN)
			trace.approach(8)
		"knight_lateral":
			for _step in range(7): trace.submit("move",Vector2.DOWN)
			trace.submit("wait",Vector2.ZERO,0.85)
			trace.approach(6,130)
	var enemy := trace.nearest()
	if not enemy.is_empty(): trace.single(trace.state.player_pos.direction_to(enemy["pos"]))
	var hp_at_ready := trace.state.player_hp
	var damage := trace.state.damage_dealt
	var defense := trace.submit("dodge",Vector2.DOWN)
	var clean := trace.start_hp == trace.state.player_hp and damage>0 and defense
	summaries.append(trace.finish(fixture+"-"+policy,{"useful_clean_punish_and_defense":clean,"hp_at_punish_ready":hp_at_ready,"subsequent_defense_accepted":defense}))

func mixed(variant: String, policy: String) -> void:
	var trace := Trace.new(variant,"F2","sweep" if policy in ["retreat_sweep","funnel"] else "full")
	if policy == "retreat_sweep":
		for _cycle in range(3):
			for _step in range(12):
				if trace.state.player_hp <= 0 or trace.state.simulation_time >= 30: break
				trace.submit("move",Vector2.LEFT)
			for _wait in range(8):
				if not trace.sweep_targets().is_empty(): break
				trace.submit("wait",Vector2.ZERO,-1)
			var enemy := trace.nearest()
			if not enemy.is_empty(): trace.submit("sweep",trace.state.player_pos.direction_to(enemy["pos"]))
			if trace.state.player_hp <= 0 or trace.state.trial_complete or trace.state.simulation_time >= 30 or trace.stalls>0: break
	elif policy == "escape":
		for _step in range(220):
			if trace.state.player_hp <= 0 or trace.state.simulation_time >= 30 or trace.stalls>0: break
			trace.submit("move",Vector2.LEFT)
	elif policy == "purposeful":
		for _step in range(4): trace.submit("move",Vector2.DOWN)
		trace.submit("wait",Vector2.ZERO,0.4)
		for _exchange in range(3):
			trace.approach(10)
			var enemy := trace.nearest()
			if enemy.is_empty() or trace.state.player_hp<=0: break
			trace.single(trace.state.player_pos.direction_to(enemy["pos"]))
			trace.submit("dodge",Vector2.DOWN)
	elif policy == "funnel":
		var earned := false
		var route: Array = []
		for _lap in range(6): route.append_array([Vector2(1500,1360),Vector2(2010,1320),Vector2(2010,1060),Vector2(1840,1000)])
		for waypoint in route:
			for _step in range(65):
				if trace.state.player_hp<=0 or trace.state.simulation_time>=30 or trace.state.player_pos.distance_to(waypoint)<34: break
				var archer := trace.state._enemy_by_id(503)
				if trace.sweep_targets().has(501) and trace.sweep_targets().has(502) and not archer.is_empty() and not trace.state._has_line_of_sight(trace.state.player_pos,archer["pos"]):
					trace.submit("sweep",trace.state.player_pos.direction_to(trace.nearest()["pos"]))
					earned = true
					break
				trace.submit("move",trace.state.player_pos.direction_to(waypoint))
			if earned or trace.state.player_hp<=0 or trace.state.simulation_time>=30: break
		if not earned: trace.inputs.append({"kind":"abandon_funnel","reason":"no qualifying two-melee sweep with blocked Archer LOS before route/budget ended"})
	summaries.append(trace.finish("F2-"+policy,{"boundary_limited":trace.stalls>0}))

func compatibility(variant: String, loadout: String) -> void:
	var trace := Trace.new(variant,"F1", "full",loadout)
	if loadout == "rogue_sharpshooter":
		for _step in range(5): trace.submit("move",Vector2.LEFT)
		trace.submit("draw",trace.state.player_pos.direction_to(trace.nearest()["pos"]),101)
		trace.submit("release",trace.state.player_pos.direction_to(trace.nearest()["pos"]))
	elif loadout == "rogue_acrobat":
		trace.submit("move",Vector2.DOWN)
		trace.submit("move",Vector2.DOWN)
		trace.approach(8,70)
		trace.single(trace.state.player_pos.direction_to(trace.nearest()["pos"]))
		trace.submit("dodge",Vector2.DOWN)
	else:
		trace.submit("spell",Vector2.RIGHT)
	summaries.append(trace.finish("compatibility-"+loadout))

func costly_commit(variant: String, full: bool) -> void:
	var trace := Trace.new(variant,"F3")
	trace.submit("move",Vector2.RIGHT)
	# The visible Knight cleave is already committed; one short cut can return
	# control before contact, whereas the irrevocable sequence overlaps it.
	var visible := trace.state.player_hp
	if full: trace.submit("commit",Vector2.ZERO,301)
	else:
		trace.single(trace.state.player_pos.direction_to(trace.nearest()["pos"]))
		trace.submit("dodge",Vector2.DOWN)
	summaries.append(trace.finish("F3-costly-"+("commit" if full else "cautious"),{"hp_before_choice":visible}))

func natural_approach(variant: String) -> void:
	var trace := Trace.new(variant,"F1-D")
	for _step in range(20):
		trace.submit("wait",Vector2.ZERO,0.10)
		if String(trace.state.enemies[0]["action"].get("kind")) == "expedition_attack": break
	var first := -1.0
	for event in trace.events:
		for enemy in event["actors"]:
			if enemy["action"].get("kind") == "expedition_attack":
				first = float(enemy["gap"])
				break
		if first >= 0: break
	summaries.append(trace.finish("F1-D-natural-approach",{"first_observed_hook_gap":first}))

func genuine_arrival(variant: String) -> void:
	var trace := Trace.new(variant,"F0")
	var arrival: Dictionary = {}
	for _step in range(42):
		var enemy := trace.state._enemy_by_id(10001)
		if enemy.is_empty() or trace.state.player_hp <= 0: break
		if trace.state.player_pos.distance_to(enemy["pos"]) <= 125:
			arrival = {"tick":trace.state._simulation_tick_index,"hp":trace.state.player_hp,"energy":trace.state.player_energy,"position":trace.state.player_pos,"site":trace.state.expedition_sites[0]}
			trace.single(trace.state.player_pos.direction_to(enemy["pos"]))
			trace.submit("dodge",Vector2.DOWN)
			break
		trace.submit("move",trace.state.player_pos.direction_to(enemy["pos"]))
	summaries.append(trace.finish("F0-native-entry",{"earned_arrival":arrival}))

func large_floor_escape(variant: String) -> void:
	var trace := Trace.new(variant,"F2")
	var state := trace.state
	var offset := Vector2(12800,0)
	# Diagnostic translation adds 12800 units of otherwise open floor to the west.
	# Native fixture remains selectable and is never silently moved.
	state.world_size.x += 12800
	state.player_pos += offset
	for enemy in state.enemies:
		for key in ["pos","spawn_pos","last_known_player"]: enemy[key] = Vector2(enemy[key])+offset
	for feature in state.terrain_features: feature["pos"] = Vector2(feature["pos"])+offset
	state.floor_shapes[0]["rect"] = Rect2(0,0,16000,1800)
	state.areas[0]["rect"] = Rect2(0,0,16000,1800)
	state.areas[0]["center"] = Vector2(8000,900)
	state._build_shape_spatial_index()
	state._refresh_loaded_region_content()
	state._apply_shortcut_world_state()
	state._build_enemy_spatial_index()
	state._update_exploration(true)
	trace.initial = Lab.manifest(state,"F2-large-floor-escape (+12800 translation)","full")
	trace.samples.clear()
	trace.events.clear()
	trace.sample(true)
	for _step in range(240):
		if state.player_hp<=0 or state.simulation_time>=30 or trace.stalls>0: break
		trace.submit("move",Vector2.LEFT)
	summaries.append(trace.finish("F2-large-floor-escape",{"boundary_limited":trace.stalls>0}))

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/policy-traces"))
	for variant in Lab.VARIANTS:
		for policy in ["four_down","four_left","immediate","side_dodge"]: opening(variant,"F1",policy)
		opening(variant,"F3","knight_lateral")
		opening(variant,"F3-T","four_down")
		opening(variant,"F1-P","diagnostic")
		opening(variant,"F3-P","diagnostic")
		for policy in ["retreat_sweep","purposeful","funnel","escape"]: mixed(variant,policy)
		for loadout in ["rogue_sharpshooter","rogue_acrobat","mage_elementalist"]: compatibility(variant,loadout)
		if variant in ["C","G","E"]:
			costly_commit(variant,true)
			costly_commit(variant,false)
		natural_approach(variant)
		genuine_arrival(variant)
		large_floor_escape(variant)
		print("POLICY completed ",variant)
	var file := FileAccess.open("res://.runtime/policy-summary.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(Lab.json_safe(summaries),"\t"))
	print("POLICY traces=",summaries.size()," (observations, not feel acceptance)")
	quit()
