extends RefCounted
## Detached read model: never saves, purchases, emits on, or advances the live state.
static func copy_state(state):
	var result = state.get_script().new(false)
	for property in state.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var value = state.get(property.name)
		if value is Array or value is Dictionary: value = value.duplicate(true)
		elif value is RandomNumberGenerator:
			var generator := RandomNumberGenerator.new()
			generator.seed=value.seed; generator.state=value.state; value=generator
		elif value is Object: continue
		result.set(property.name,value)
	return result

static func fingerprint(state) -> String:
	return str([state._build_save_payload(),state.level_up_context(),state.available_level_up_options(),state.nearby_waystone(),state.is_player_ready(),state.trial_complete]).sha256_text()

static func description(state, stage: Dictionary) -> String:
	if state.uses_energy_rules():
		if stage.get("id","")=="practised_footwork":
			return "Basic Dodge: protected interval 0.24 → 0.30 simulation seconds; action remains 0.56. No long cooldown in Energy rules."
		if stage.get("id","")=="evasion_mastery":
			return "A clean Sidestep primes Counterstep. Long Roll's cooldown restoration has no long-cooldown benefit in Energy rules."
	return str(stage.get("description",""))

static func values(state) -> Dictionary:
	var result: Dictionary=state.player_attributes.duplicate(true)
	result.erase("health"); result.erase("energy")
	result["Maximum Health"]=state.player_max_hp
	result["Maximum Energy"]=state.player_max_energy
	result["Posture capacity"]=state.player_posture_max
	result["Physical poise"]=floorf(float(state.player_attributes.get("resolve",0))/2)+ (2 if state.track_choice("warrior_method")=="brace" else 0)
	result["Rally drain / simulation second"]=state._rally_drain_rate()
	result["Battle Flow maximum pips"]=state._battle_flow_max_pips() if state.has_track_rank("vanguard",1) else 0
	result["Full Flow damage bonus %"]=100*state._battle_flow_damage_per_pip()*state._battle_flow_max_pips() if state.has_track_rank("vanguard",1) else 0
	result["Full Flow posture bonus %"]=100*state._battle_flow_posture_per_pip()*state._battle_flow_max_pips() if state.has_track_rank("vanguard",1) else 0
	var attack: Dictionary=state.player_basic_attack_definition()
	for key in ["duration","reach","damage_min","posture"]:
		result["Basic attack "+key+ (" (simulation seconds)" if key=="duration" else "")]=attack.get(key,0)
	result["Weapon Art"]=state.player_equipped_weapon_art
	result["Known spells"]=str(state.player_spells)
	# Generate the actual defensive action on this detached copy, without ticking.
	state.player_action=state._idle_action(); state.trial_complete=false; state.dodge_cooldown=0
	if state.request_dodge(Vector2.RIGHT,false):
		result["Dodge cooldown (simulation seconds)"]=state.dodge_cooldown
		result["Dodge protected interval (simulation seconds)"]=float(state.player_action.get("evade_end",0))-float(state.player_action.get("evade_start",0))
		for key in ["duration","evade_start","evade_end","speed"]:
			result["Dodge "+key+ (" (simulation seconds)" if key!="speed" else "")]=state.player_action.get(key,0)
	return result

static func preview(state, track_id: String, stage: Dictionary, option: String="") -> Array[String]:
	var before=copy_state(state)
	var after=copy_state(state)
	after.track_ranks[track_id]=int(stage.get("rank",state.track_total(track_id)+1))
	if not option.is_empty(): after.track_choices[str(stage.id)]=option
	after._apply_character_stage(str(stage.id),option)
	var old:=values(before); var next:=values(after)
	var lines: Array[String]=[]
	for key in next:
		if old.get(key)!=next[key]: lines.append("%s: %s → %s" % [str(key).capitalize(),str(old.get(key)),str(next[key])])
	return lines
