class_name ExpeditionCombat
extends RefCounted

const Catalog = preload("res://scripts/core/combat_catalog.gd")
const Abilities = preload("res://scripts/core/ability_catalog.gd")
const Coordinator = preload("res://scripts/core/expedition_coordinator.gd")

# An executor, not another damage/defence engine: all contact, displacement,
# projectile allegiance, posture and deaths remain owned by RunState.
static func choose(state, enemy: Dictionary) -> bool:
	var kind := String(enemy["kind"])
	if not Catalog.EXPEDITION_KITS.has(kind): return false
	var kit: Dictionary = Catalog.EXPEDITION_KITS[kind]
	var position := Vector2(enemy["pos"])
	var target: Vector2 = state.player_pos
	var boss := bool(kit.get("boss", false))
	if boss and int(enemy["hp"]) <= int(enemy["max_hp"]) / 2 and int(enemy.get("boss_phase", 1)) < 2:
		enemy["boss_phase"] = 2
		enemy["action"] = state._action("phase_change", 1.1, Vector2.ZERO)
		enemy["action"]["label"] = "SECOND PHASE"
		if not state.expedition.is_empty(): Coordinator.record(state.expedition, "boss_phase", {"boss":kind,"phase":2})
		state._add_effect("strain", position)
		return true
	if kind == "bellrunner":
		if bool(enemy.get("gong_used", false)):
			# Once the finite alarm has served its purpose, defend the gong rather
			# than running forever into another encounter's population budget.
			enemy["action"] = state._enemy_move_action(enemy, Vector2(enemy.get("gong_pos",position)), 0.4) if position.distance_to(enemy.get("gong_pos",position))>60 else state._action("idle",0.4,Vector2.ZERO)
			return true
		target = Vector2(enemy.get("gong_pos", position))
	var distant := position.distance_to(target) > float(kit["engage"])
	var ranged_id := String(Array(kit["attacks"])[-1])
	var ranged_reach := float(Abilities.ENEMY_ABILITIES[ranged_id]["reach"])
	if not distant: enemy["expedition_approaching"] = false
	if (distant and (not boss or position.distance_to(target)>ranged_reach or bool(enemy.get("expedition_approaching",false)))) or not state._has_line_of_sight(position, target):
		enemy["action"] = state._enemy_move_action(enemy, target, 0.3)
		if boss:
			# A visible approach, not input prediction. After ranged pressure the
			# guardian closes until its melee vocabulary can matter again.
			enemy["action"]["speed_multiplier"] = float(kit["approach_speed"])/float(Catalog.enemy_fact(kind,"move_speed"))
			enemy["action"]["label"] = "CLOSING"
		return true
	var cycle := int(enemy.get("expedition_attack_index", 0))
	var attacks: Array = kit["attacks"]
	var ability_id := String(attacks[cycle % attacks.size()])
	if boss and distant:
		ability_id = ranged_id
		enemy["expedition_approaching"] = true
	enemy["expedition_attack_index"] = cycle + 1
	# The second-half drive is followed by a fresh, visible sweep commitment,
	# never an unannounced extension of a previously completed attack.
	var spec: Dictionary = Abilities.ENEMY_ABILITIES[ability_id]
	var direction := (target-position).normalized()
	if direction == Vector2.ZERO: direction = Vector2.DOWN
	var action: Dictionary = state._action("expedition_attack", float(spec["duration"]), direction)
	for key in spec: action[key] = spec[key]
	action["ability_id"] = ability_id
	action["label"] = ability_id
	action["target"] = target
	action["origin"] = position
	action["active_end"] = float(spec["startup"]) + (float(spec["travel"])/float(spec["speed"]) if spec.has("travel") else 0.22)
	if kind=="thornhart" and ability_id=="antler_drive" and int(enemy.get("boss_phase",1))==2:
		action["duration"] = float(action["active_end"])+0.55
	action["ally_collision"] = "vault" if String(spec["shape"]) == "flight" else "block"
	action["airborne"] = String(spec["shape"]) == "flight"
	# Contact capture ends with this commitment. Projectiles and delayed zones
	# can resolve later; do not falsely label them missed at cast completion.
	if String(spec["shape"]) in ["hook","sweep","drive","flight","cone"]:
		state._attach_charge_capture(action, 0.0, ability_id)
	enemy["facing"] = direction
	enemy["action"] = action
	if boss and not state.expedition.is_empty(): Coordinator.record(state.expedition, "boss_attack", {"boss":kind,"ability":ability_id,"at":state.simulation_time})
	return true

static func tick(state, enemy: Dictionary, action: Dictionary, previous: float, dt: float) -> void:
	var elapsed := float(action["elapsed"])
	var startup := float(action["startup"])
	var active_end := float(action["active_end"])
	var shape := String(action["shape"])
	var position := Vector2(enemy["pos"])
	if elapsed <= float(action.get("track_until", 0.0)):
		var offset: Vector2 = state.player_pos-position
		if offset.length_squared() > 0.01:
			action["direction"] = offset.normalized()
			enemy["facing"] = action["direction"]
	var direction := Vector2(action["direction"])
	if shape in ["hook", "sweep"] and previous < startup:
		var fraction := (minf(elapsed,startup)-previous)/startup
		var motion := direction*float(action.get("advance",0.0))*fraction
		state._set_enemy_position(enemy,state._move_actor(position,motion,float(enemy["radius"]),int(enemy["id"])))
	if shape in ["drive", "flight"] and elapsed >= startup and previous < active_end:
		var active_dt := maxf(0.0,minf(elapsed,active_end)-maxf(previous,startup))
		var motion: Dictionary = state._move_charging_actor(enemy,Vector2(enemy["pos"]),direction*float(action["speed"])*active_dt,action,elapsed>=active_end)
		state._set_enemy_position(enemy,Vector2(motion["position"]))
	state._observe_capture(enemy,action,elapsed)
	if elapsed >= startup and elapsed <= active_end and shape in ["hook","sweep","drive","flight","cone"]:
		var offset: Vector2 = state.player_pos-Vector2(enemy["pos"])
		var reach := float(enemy["radius"])+38.0 if shape in ["drive","flight"] else float(action["reach"])
		var inside: bool = offset.length() <= reach+state.PLAYER_RADIUS and (shape in ["drive","flight"] or state._within_arc(direction,offset,float(action.get("arc",1.0))*0.5))
		var record: Dictionary = action.get("capture_record",{})
		if not record.is_empty(): record["closest"] = minf(float(record["closest"]),offset.length()-reach-state.PLAYER_RADIUS)
		if inside and not bool(action["hit_done"]) and state._has_line_of_sight(Vector2(enemy["pos"]),state.player_pos):
			action["hit_done"] = true
			var evaded: bool = state._is_evasive()
			if not record.is_empty(): record["resolution"] = "evaded" if evaded else "contact"
			state._resolve_incoming_hit(int(enemy["id"]),int(action["damage"]),String(action["ability_id"]),-direction,Vector2.INF,float(action["posture"]))
			if shape == "hook" and not evaded: state._set_actor_impulse(0,-direction*sqrt(2.0*state.GALE_DECELERATION*float(action["pull"])))
	if elapsed < startup or bool(action["effect_done"]): return
	action["effect_done"] = true
	match shape:
		"fan":
			for index in int(action["count"]):
				var shot_direction := direction.rotated((index-(int(action["count"])-1)*0.5)*float(action["spread"]))
				state._add_projectile({"kind":"arrow","pos":Vector2(enemy["pos"])+shot_direction*(float(enemy["radius"])+12.0),"vel":shot_direction*float(action["speed"]),"radius":8.0,"damage":int(action["damage"]),"posture":float(action["posture"]),"source_id":int(enemy["id"]),"layer":state.current_layer,"travelled":0.0,"max_range":float(action["reach"])+200.0,"ability_id":action["ability_id"]})
		"zone":
			var count := int(action.get("count",1))
			var furnace_lanes := String(enemy["kind"]) == "kilnmaster" and int(enemy.get("boss_phase",1)) == 2
			if furnace_lanes: count = 2
			for index in count:
				var centre := Vector2(action["target"])+direction.orthogonal()*(index-(count-1)*0.5)*(420.0 if furnace_lanes else 250.0)
				_spawn_zone(state,enemy,action,centre,furnace_lanes)
		"wind":
			state._spawn_gale(enemy,Vector2(action["target"]))
			if int(enemy.get("boss_phase",1))==2:
				state.hazards[-1]["trigger_at"] = 1.2
				state.hazards[-1]["duration"] = 1.6
		"gong":
			enemy["gong_used"] = true
			var called := 0
			for other in state.enemies:
				if bool(other.get("reserve",false)) and int(other.get("expedition_site",-1))==int(enemy.get("expedition_site",-2)):
					other["reserve"] = false
					state._broadcast_enemy_alarm(other,state.player_pos)
					called += 1
			state._add_effect("slam",Vector2(enemy.get("gong_pos",enemy["pos"])))
			if not state.expedition.is_empty(): Coordinator.record(state.expedition,"gong",{"site":enemy.get("expedition_site",-1),"reserves":called})
	# Phase-two wind/volley is still two separately announced actions. A delayed
	# gust survives long enough to intersect the following volley, symmetrically.
	if String(enemy["kind"]) == "bell_regent" and int(enemy.get("boss_phase",1)) == 2 and shape == "wind":
		action["duration"] = startup+0.35

static func _spawn_zone(state, enemy: Dictionary, action: Dictionary, centre: Vector2, lane: bool = false) -> void:
	var existing := 0
	for hazard in state.hazards:
		if String(hazard["kind"])=="expedition_zone": existing += 1
	if existing >= 3 or not state._inside_world(centre,110.0) or state._point_in_wall(centre): return
	var hazard := {"kind":"expedition_zone","pos":centre,"origin":enemy["pos"],"radius":float(action["radius"]),"elapsed":0.0,"duration":float(action["delay"])+float(action["lifetime"]),"trigger_at":float(action["delay"]),"triggered":false,"damage":int(action["damage"]),"posture":float(action["posture"]),"source_id":int(enemy["id"]),"layer":state.current_layer,"ability_id":action["ability_id"]}
	if lane:
		# Parallel, announced lanes leave a 290-unit corridor through the middle.
		# Shorten to legal floor; never extend an invisible hazard through a cliff.
		hazard["radius"] = 65.0
		var direction := Vector2(action["direction"])
		for sign_value in [-1,1]:
			var endpoint := centre
			for step in range(1,11):
				var candidate: Vector2 = centre+direction*sign_value*step*50.0
				if not state._can_occupy(candidate,65.0,-1,true): break
				endpoint = candidate
			hazard["lane_start" if sign_value==-1 else "lane_end"] = endpoint
	state._add_hazard(hazard)
