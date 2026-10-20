class_name CombatLabCatalog
extends RefCounted

const VERSION := 1
const FINISHER_BONUS := 10
const VARIANTS := {"A":"control", "B":"frozen_normal", "C":"commit", "G":"archer_seat", "E":"briar_boundary"}
const FIXTURES := ["F1", "F1-D", "F1-P", "F2", "F3", "F3-T", "F3-N", "F3-P", "F3-K", "F3-KP", "F0"]
const LOADOUTS := ["warrior", "rogue_sharpshooter", "rogue_acrobat", "mage_elementalist"]
const State = preload("res://scripts/core/run_state.gd")
const Combat = preload("res://scripts/core/combat_catalog.gd")
const Expedition = preload("res://scripts/core/expedition_combat.gd")
const Digest = preload("res://scripts/core/determinism_snapshot.gd")
const LAYER := "survey_arena"

static func create(variant: String = "C", fixture: String = "F1", loadout: String = "warrior", resources: String = "full", rules: String = "energy", scouting: bool = false) -> RunState:
	assert(VARIANTS.has(variant) and FIXTURES.has(fixture) and LOADOUTS.has(loadout))
	var state: RunState = State.new(false)
	state.combat_lab = true
	state.lab_variant = variant
	state.start_run(loadout, "expedition" if fixture == "F0" else "combat_survey", 42, "encounter", rules)
	configure(state,variant,fixture,resources,scouting)
	return state

static func configure(state: RunState, variant: String, fixture: String, resources: String, scouting: bool = false) -> void:
	if fixture == "F0" and state.mode_id == "combat_survey":
		# Recorded native first-biome geometry; no Expedition progression is enabled.
		state._install_layout(load("res://scripts/core/expedition_generator.gd").generate(42,0))
		state._respawn_enemies()
		state._apply_shortcut_world_state()
		state._update_exploration(true)
	if fixture != "F0":
		var player := Vector2(1000,800)
		var roster: Array = [["briarhook",101,Vector2(1170,800)]]
		var features: Array = []
		if fixture == "F1-D": roster[0][2] = Vector2(1400,800)
		if fixture == "F1-P":
			player = Vector2(1000,900)
			roster[0][2] = Vector2(1000,800)
		if fixture == "F2":
			player = Vector2(1250,900)
			roster = [["briarhook",501,Vector2(1505,810)],["hound",502,Vector2(1695,810)],["archer",503,Vector2(1810,1060) if variant == "G" else Vector2(1505,1000)]]
			for point in [Vector2(1340,670),Vector2(1870,1130),Vector2(1870,630)]: features.append(_feature("boulder",point,65))
			for point in [Vector2(1220,750),Vector2(1750,1280)]: features.append(_feature("tree",point,48))
		if fixture.begins_with("F3"):
			roster = [["knight",301,Vector2(1252,800) if fixture == "F3-T" else Vector2(1185,800)]]
			if fixture in ["F3-K","F3-KP"]: roster = [["kiln_guard",301,Vector2(1180,800)]]
			if fixture in ["F3-P","F3-KP"]:
				player = Vector2(1000,900)
				roster[0][2] = Vector2(1000,800)
		if scouting: player.x -= 340
		var templates: Array = []
		for actor in roster: templates.append({"kind":actor[0],"id":actor[1],"pos":actor[2],"layer":LAYER})
		var bounds := Rect2(0,0,3200,1800)
		state._install_layout({"world_size":bounds.size,"geometry_style":"organic","areas":[{"id":0,"name":fixture,"kind":"survey","rect":bounds,"center":bounds.get_center(),"layer":LAYER,"discovered":true}],"connections":[],"floor_shapes":[{"kind":"rect","rect":bounds,"part_id":0,"layer":LAYER}],"terrain_features":features,"layers":{LAYER:{"name":"Combat lab"}},"encounters":{0:templates},"base_walls":[],"bonfire_pos":Vector2.ZERO,"player_start":player,"shortcut_gate":Rect2(),"shortcut_unlock_pos":Vector2.ZERO,"shortcut_start_pos":Vector2.ZERO})
		state._respawn_enemies()
		state._refresh_loaded_region_content()
		state._apply_shortcut_world_state()
		state._build_enemy_spatial_index()
		state.player_facing = Vector2.UP if fixture in ["F1-P","F3-P","F3-KP"] else Vector2.RIGHT
		for enemy in state.enemies:
			enemy["facing"] = Vector2.RIGHT if scouting else Vector2(enemy["pos"]).direction_to(player)
			enemy["awareness"] = "idle" if scouting else "alerted"
			enemy["alert_remaining"] = 0.0 if scouting else 3.0
			enemy["last_known_player"] = player
			enemy["revealed_to_player"] = true
			for key in ["shot_cooldown","pounce_cooldown","parry_cooldown","dodge_cooldown","neutral_cooldown"]: enemy[key] = 0.0
		if not scouting:
			var enemy: Dictionary = state.enemies[0]
			if fixture in ["F1","F1-P","F3-K","F3-KP"]:
				# Construct a real catalog action while in range, without a world tick.
				if fixture.ends_with("P"):
					var saved_player := state.player_pos
					state.player_pos = Vector2(enemy["pos"])+Vector2(100,0)
					Expedition.choose(state,enemy)
					state.player_pos = saved_player
					enemy["action"]["elapsed"] = 0.85 if fixture == "F1-P" else 1.03
				else: Expedition.choose(state,enemy)
			if fixture in ["F3","F3-T","F3-P"]:
				var plan := state._plan_option("knight","thrust" if fixture == "F3-T" else "heavy_cleave")
				enemy["action"] = state._intent_melee_action(plan,Vector2.RIGHT if fixture == "F3-P" else Vector2.LEFT)
				enemy["facing"] = enemy["action"]["direction"]
				if fixture == "F3-P": enemy["action"]["elapsed"] = 1.67
		state.simulation_time = 0.0
		state._simulation_tick_index = 0
		state.rng.seed = 42
		state.survey_room_definition = {"fixture":fixture,"reinforcements":[]}
		state._update_exploration(true)
	if resources == "low":
		state.player_hp = roundi(state.player_max_hp*0.60)
		state.player_energy = state.player_max_energy*0.35
	if resources == "sweep" and state.loadout_id == "warrior":
		# Earn the actual level-two stage through the existing upgrade transaction.
		state.carried_xp = state.next_upgrade_cost()
		assert(state.choose_upgrade("swordsmanship|prototype_sweeping_cut"))
		assert(state.player_equipped_weapon_art == "prototype_sweeping_cut")
	if fixture != "F0": state._capture_survey_room_entry()
	state.lab_notice = "%s / %s / seed42 / %s" % [variant,fixture,resources]

static func _feature(kind: String, point: Vector2, radius: float) -> Dictionary:
	return {"kind":kind,"pos":point,"radius":radius,"blocks":true,"layer":LAYER,"part_id":0}

static func manifest(state: RunState, fixture: String, resources: String, scouting: bool = false) -> Dictionary:
	var actors: Array = []
	for enemy in state.enemies:
		actors.append({"id":enemy["id"],"kind":enemy["kind"],"pos":enemy["pos"],"hp":enemy["hp"],"posture":enemy["posture"],"attributes":enemy["attributes"],"properties":enemy["properties"],"facing":enemy["facing"],"action":enemy["action"].duplicate(true),"awareness":enemy["awareness"],"alert_remaining":enemy["alert_remaining"],"shot_cooldown":enemy["shot_cooldown"],"occupancy_scope":"current loaded geometry; distant F0 regions unassessed", "occupiable":state._can_occupy(enemy["pos"],float(enemy["radius"]),int(enemy["id"])),"los":state._has_line_of_sight(state.player_pos,enemy["pos"]),"visible":state.is_visible(enemy["pos"])})
	var result := {"catalog":VERSION,"baseline":"0fb5694fda7f6018b03f4aeed2a3c8533759ec52","variant":state.lab_variant,"fixture":fixture,"resources":resources,"scouting":scouting,"loadout":state.loadout_id,"rules":state.combat_rules,"seed":state.run_seed,"rng_state":str(state.rng.state),"tick":state._simulation_tick_index,"time":state.simulation_time,"player":state.player_pos,"hp":state.player_hp,"energy":state.player_energy,"level":state.character_level(),"ranks":state.track_ranks.duplicate(true),"equipped_art":state.player_equipped_weapon_art,"actors":actors,"walls":state.walls.duplicate(),"floor":state.floor_shapes.duplicate(true),"features":state.terrain_features.duplicate(true),"generated_sites":state.expedition_sites.duplicate(true),"initial_delay_override":"native generation / awareness / cooldowns" if fixture in ["generated","F0"] else "all five diagnostic enemy cooldown slots zero"}

	result["authoritative_entry"] = authoritative(state)
	result["entry_digest"] = decision_digest(state)
	result["player_attributes"] = state.player_attributes.duplicate(true)
	result["player_properties"] = state.player_properties.duplicate(true)
	result["player_resources"] = {"max_hp":state.player_max_hp,"max_energy":state.player_max_energy,"posture":state.player_posture,"posture_max":state.player_posture_max,"regen_delay":state.player_energy_regen_delay,"exhaustion":state.player_exhaustion_remaining}
	return result

# Complete action/actor dictionaries supplement the historical selected-field
# golden projection. Exclude only the adapter's live hold/pending/token state
# when comparing world consequences of equivalent semantic choices.
static func authoritative(state: RunState, semantic_input: bool = false) -> Dictionary:
	var action := state.player_action.duplicate(true)
	if semantic_input:
		for key in ["continue_held","lab_pending","lab_continue_token"]: action.erase(key)
	return {"baseline_projection":Digest.checkpoint(state),"tick":state._simulation_tick_index,"rng":str(state.rng.state),"action":action,"enemies":state.enemies.duplicate(true),"projectiles":state.projectiles.duplicate(true),"hazards":state.hazards.duplicate(true),"barriers":state.barriers.duplicate(true),"conditions":state.player_conditions.duplicate(true),"cooldowns":state.cooldowns.duplicate(true),"rally":state.rally_active,"flow":[state.battle_flow_pips,state.battle_flow_remaining],"energy":state.player_energy,"exhaustion":[state.player_overexertion_pending,state.player_exhaustion_remaining],"position":state.player_pos,"hp":state.player_hp,"posture":state.player_posture,"time":state.simulation_time}

static func digest(value: Variant) -> String:
	return canonical(value).sha256_text()

static func decision_digest(state: RunState) -> String:
	return digest({"world":authoritative(state),"variant":state.lab_variant,"enabled":state.combat_lab,"armed":state.lab_armed,"neutral_required":state.lab_neutral_required,"next_combo_id":state._next_combo_instance_id})

static func json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = json_safe(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(json_safe(item))
		return result
	if value is float and not is_finite(value): return str(value)
	return value

static func canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a,b): return var_to_str(a) < var_to_str(b))
		var parts: PackedStringArray = []
		for key in keys: parts.append(var_to_str(key)+":"+canonical(value[key]))
		return "{"+",".join(parts)+"}"
	if value is Array:
		var parts: PackedStringArray = []
		for item in value: parts.append(canonical(item))
		return "["+",".join(parts)+"]"
	return var_to_str(value)
