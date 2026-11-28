extends "res://scripts/core/run_state.gd"
const Regions = preload("res://scripts/campaign/campaign_regions.gd")
const PlayerProfiles = preload("res://scripts/campaign/campaign_player_profiles.gd")
const EnemyProfiles = preload("res://scripts/campaign/campaign_enemy_profiles.gd")
const REGION_SAVE_VERSION := 2
const COMBAT_STYLES := ["default", "slow", "fast"]
const COMPARISON_WEAPONS := {
	"warrior": "greatsword",
	"rogue_acrobat": "dagger",
	"rogue_sharpshooter": "dagger",
	"mage_elementalist": "straight_sword",
}
const COMPARISON_TECHNIQUES := {
	"dagger": ["knife_cut_in", "knife_cut_out", "knife_rising_cut", "knife_falling_cut"],
	"straight_sword": ["opening_cut", "reverse_cut", "diagonal_cut"],
	"greatsword": ["heavy_chop", "heavy_cleave", "reverse_cut"],
}
# The matched Polearm and the same Windbreak seats retain comparable terrain.
const WINDBREAK_ROSTERS := {"slow": ["shield", "blade"], "fast": ["blade", "knife"]}
var combat_style := "default"
var _reference_enemies: Dictionary = {}
const SAVE_PATH := "user://waystone-regional-campaign.save"
var loading_demo := true
var restoring_demo := false
var route_released := false
var defeated_guardians: Dictionary = {}
var operated_crossings: Dictionary = {}
var lift_memory: Dictionary = {}
var regional_variant: Dictionary = {}
var set_pieces: Array = []
var crossings: Array = []
var lifts: Array = []
var protected_save := false
var _imported_enemies: Array = []
var _imported_pickups: Array = []
const RELAY := Vector2(1250,1150)

func _init(auto_start: bool = true) -> void:
	session_save_path = SAVE_PATH
	super._init(auto_start)

func _create_floor_boundary(shapes: Array) -> RefCounted:
	return FloorBoundaryScript.new(shapes, true)

func start_run(a:String,b:String,c:int=-1,d:String="encounter",e:String="energy",f:bool=false,g:Dictionary={}) -> void:
	if not COMBAT_STYLES.has(combat_style): combat_style = "default"
	_reference_enemies.clear()
	loading_demo=true
	route_released=false
	if not restoring_demo:
		defeated_guardians.clear()
		operated_crossings.clear()
		lift_memory.clear()
	super.start_run(a,b,c,d,e,f,g)
	loading_demo=false
	if not restoring_demo: _update_exploration(true)

func inspired_combat() -> bool:
	return combat_style == "slow" or combat_style == "fast"

func comparison_weapon() -> String:
	return String(COMPARISON_WEAPONS[loadout_id]) if inspired_combat() else player_weapon_frame

func _comparison_player_profile() -> Dictionary:
	return PlayerProfiles.profile(combat_style, comparison_weapon()) if inspired_combat() else {}

func _comparison_clock() -> float:
	# Match neutral reference seconds at the board's execution rate. A live
	# Frost condition still slows these actions through the shared personal clock.
	return EXECUTION_PLAYBACK_RATE * _tempo_from_attributes(player_attributes)

func current_move_speed() -> float:
	if not inspired_combat(): return super.current_move_speed()
	var speed := float(_comparison_player_profile()["move_speed"]) / _comparison_clock()
	return speed * (EXHAUSTED_MOVE_SCALE if player_is_exhausted() else 1.0) * _terrain_speed_scale(player_pos)

func committed_move_distance(requested: float = MOVE_RANGE) -> float:
	return float(_comparison_player_profile()["step_distance"]) if inspired_combat() else super.committed_move_distance(requested)

func begin_streamed_move(direction: Vector2, distance: float = MOVE_RANGE) -> bool:
	var began := super.begin_streamed_move(direction, distance)
	if began and inspired_combat(): player_action["reference_travel"] = true
	return began

func _reference_roll() -> Dictionary:
	if not inspired_combat(): return {}
	var profile := _comparison_player_profile()
	var clock := _comparison_clock()
	var duration := float(profile["roll_duration"]) * clock
	var evade_end := float(profile["iframe_end"]) * clock
	var move_end := float(profile["roll_move_end"]) * clock
	return {
		"duration": duration, "move_start": 0.0, "move_end": move_end,
		"evade_start": float(profile["iframe_start"]) * clock, "evade_end": evade_end,
		"vulnerable_recovery_start": evade_end,
		"speed": float(profile["roll_distance"]) / move_end,
		"dodge_style": combat_style, "reference_travel": true,
	}

func player_uses_ranged_basic_attack() -> bool:
	return not inspired_combat() and super.player_uses_ranged_basic_attack()

func commit_available() -> bool:
	return inspired_combat() or super.commit_available()

func full_combo_raw_cost() -> float:
	if not inspired_combat(): return super.full_combo_raw_cost()
	return Array(_comparison_player_profile()["attacks"]).size() * _basic_attack_energy_cost()

func request_attack(target: Vector2, simulate_immediately: bool = true) -> bool:
	if not inspired_combat(): return super.request_attack(target, simulate_immediately)
	return _begin_comparison_attack(target - player_pos, false, simulate_immediately)

func request_direct_attack(direction: Vector2, simulate_immediately: bool = true, held: bool = false) -> bool:
	if not inspired_combat(): return super.request_direct_attack(direction, simulate_immediately, held)
	if not _begin_comparison_attack(direction, false, simulate_immediately): return false
	direct_attack_uses_total += 1
	return true

func request_combo(direction: Vector2, simulate_immediately: bool = true, held: bool = false) -> bool:
	if not inspired_combat(): return super.request_combo(direction, simulate_immediately, held)
	# The inherited primary target input uses this entry point for a melee press.
	return _begin_comparison_attack(direction, false, simulate_immediately)

func request_commit_combo(target_id: int, simulate_immediately: bool = true) -> bool:
	if not inspired_combat(): return super.request_commit_combo(target_id, simulate_immediately)
	var target := _enemy_by_id(target_id)
	if target.is_empty() or int(target["hp"]) <= 0 or not _enemy_on_current_layer(target) or not enemy_visible_to_player(target) or not is_visible(Vector2(target["pos"])): return false
	return request_campaign_combo(Vector2(target["pos"]) - player_pos, simulate_immediately)

func request_campaign_combo(direction: Vector2, simulate_immediately: bool = true) -> bool:
	return inspired_combat() and _begin_comparison_attack(direction, true, simulate_immediately)

func _player_basic_attack_definition(direction: Vector2) -> Dictionary:
	if not inspired_combat(): return super._player_basic_attack_definition(direction)
	var definition := _comparison_strike(_comparison_player_profile()["attacks"][0], 0, 0.0)
	definition["duration"] = definition["end"]
	definition["step"] = 0
	return definition

func _comparison_strike(source: Dictionary, index: int, phase_start: float, continues: bool = false) -> Dictionary:
	var clock := _comparison_clock()
	var startup := float(source["startup"]) * clock
	var finish := phase_start + float(source["duration"]) * clock
	var next_swing := phase_start + float(source["chain_at"]) * clock
	var active_end := phase_start + float(source["active_end"]) * clock
	var contact_travel := float(source["advance_distance"])
	var contact_travel_time := phase_start + float(source["advance_at"]) * clock
	var root_motion := PackedVector2Array([
		Vector2(phase_start, 0.0),
		Vector2(contact_travel_time, contact_travel),
		Vector2(next_swing, float(source["travel_at_chain"])),
	])
	if not continues: root_motion.append(Vector2(finish, float(source["travel_at_move"])))
	var techniques: Array = COMPARISON_TECHNIQUES[comparison_weapon()]
	var damage := int(super._player_basic_attack_definition(player_facing)["damage_min"])
	return {
		"startup": phase_start + startup, "active_end": active_end,
		"end": finish, "link": next_swing if continues else active_end,
		"reach": float(source["reach"]), "advance_distance": contact_travel,
		"energy_cost": _basic_attack_energy_cost(), "damage_min": damage, "damage_max": damage,
		"posture": player_attack_posture if player_weapon_frame != "bow" else 1.0,
		"technique": techniques[index % techniques.size()],
		"pose_start": phase_start, "pose_end": next_swing if continues else finish,
		"root_motion": root_motion,
	}

func _begin_comparison_attack(direction: Vector2, full_combo: bool, simulate_immediately: bool) -> bool:
	if not _can_start_basic_attack(): return false
	var attacks: Array = _comparison_player_profile()["attacks"]
	var phases: Array[Dictionary] = []
	var phase_start := 0.0
	var cost := 0.0
	var count := attacks.size() if full_combo else 1
	for index in count:
		var phase := _comparison_strike(attacks[index], index, phase_start, index + 1 < count)
		phases.append(phase)
		cost += float(phase["energy_cost"])
		phase_start = float(phase["link"])
	if not _spend_energy(cost): return false
	_break_player_combo()
	player_facing = player_facing if direction.is_zero_approx() else direction.normalized()
	var first := phases[0]
	var last := phases[-1]
	player_action = _action("combo" if full_combo else "attack", float(last["end"]), player_facing)
	player_action.merge(first, true)
	player_action.merge({
		"technique_id": first["technique"], "posture_damage": first["posture"], "combo_step": 0,
		"reference_travel": true,
	}, true)
	if full_combo:
		player_action.merge({
			"phases": phases, "full_combo_commit": true, "commit_paid_cost": _last_energy_spend,
			"combo_length": phases.size(), "committed_phase": 0, "phase_index": -1,
			"combo_instance_id": _next_combo_instance_id,
		}, true)
		_next_combo_instance_id += 1
		_apply_counterstep_to_combo(player_action)
		player_action["startup"] = phases[0]["startup"]
		player_action["posture_damage"] = phases[0]["posture"]
	else:
		_apply_counterstep_to_action(player_action)
	_stamp_battle_flow(player_action)
	_apply_action_poise(player_action)
	_annotate_player_action("comparison_combo" if full_combo else "comparison_attack")
	player_action["weapon_frame"] = comparison_weapon()
	_emit_sound(player_pos, 350.0)
	_set_message("Combo committed." if full_combo else "Attack committed.")
	if simulate_immediately: _simulate_until_ready()
	else: _streamed_action_cpu_usec = 0
	return true

func _install_layout(layout:Dictionary) -> void:
	var regional := Regions.generate(run_seed)
	regional_variant = regional.regional_variant
	set_pieces = regional.set_pieces
	crossings = regional.crossings
	lifts = regional.lifts
	if inspired_combat():
		var seats: Array = regional.encounters[201]
		var roster: Array = WINDBREAK_ROSTERS[combat_style]
		for index in seats.size():
			seats[index]["kind"] = roster[index]
	super._install_layout(regional)

func _comparison_enemy_profile(kind: String) -> Dictionary:
	if not inspired_combat(): return {}
	if not _reference_enemies.has(kind):
		_reference_enemies[kind] = EnemyProfiles.profile(combat_style, kind)
	return _reference_enemies[kind]

func _enemy_base_move_speed(enemy: Dictionary) -> float:
	var profile := _comparison_enemy_profile(String(enemy["kind"]))
	if profile.is_empty(): return super._enemy_base_move_speed(enemy)
	return float(profile["move_speed"])

func _choose_enemy_action(enemy: Dictionary) -> void:
	var kind := String(enemy["kind"])
	var profile := _comparison_enemy_profile(kind)
	if profile.is_empty():
		super._choose_enemy_action(enemy)
		return
	var opener: Dictionary = profile["attacks"][0]
	var position := Vector2(enemy["pos"])
	var offset := player_pos - position
	var distance := offset.length()
	var direction := offset / distance if distance > 0.01 else Vector2.DOWN
	var strike_distance := float(opener["distance"])
	var can_see := _has_line_of_sight(position, player_pos)
	enemy["facing"] = direction
	var ward := _shield_ward(enemy) if kind == "shield" else {}
	var can_strike := kind != "shield" or _shield_wants_to_strike(enemy, can_see and distance <= SHIELD_GUARD_RADIUS, not ward.is_empty())
	if can_strike and can_see and distance <= strike_distance + STRIKE_COMMIT_BAND:
		_begin_comparison_enemy_attack(enemy, opener, direction, 0, Array(profile["chain_chances"]).size())
		_clear_melee_intent(enemy)
		if kind == "shield": enemy["patience"] = float(enemy.get("patience_max", 0.0))
		return
	var outward := -direction
	var target := player_pos + outward * strike_distance
	var flanking := false
	if not ward.is_empty():
		target = _shield_station(Vector2(ward["pos"]))
	elif kind == "knife" and combat_style == "fast":
		target = _knife_approach_target(enemy, strike_distance)
		flanking = not bool(enemy.get("knife_flank_abandoned", false))
	enemy["action"] = _enemy_move_action(enemy, target, 0.32 if flanking else 0.48)
	# A flank must reach its own bearing. Direct approaches stop at the
	# commitment radius, then check line of sight again before striking.
	if flanking:
		enemy["action"]["intent"] = "knife_flank"
	enemy["intended_strike_distance"] = strike_distance if ward.is_empty() and not flanking and can_see else 0.0

func _begin_comparison_enemy_attack(enemy: Dictionary, source: Dictionary, direction: Vector2, index: int, chain_count: int) -> void:
	var clock := EXECUTION_PLAYBACK_RATE * float(enemy.get("personal_tempo", 1.0))
	var option := source.duplicate()
	for field in ["startup", "active_end", "duration", "advance_end"]:
		option[field] = float(source[field]) * clock
	var action := _intent_melee_action(option, direction)
	action["reference_travel"] = true
	action["comparison_strike"] = index
	action["ability_id"] = "%s_%s_%d" % [combat_style, enemy["kind"], index + 1]
	if index < chain_count:
		action["reference_chain_at"] = float(source["chain_at"]) * clock
	enemy["facing"] = direction
	enemy["action"] = action

func _continue_enemy_melee(enemy: Dictionary, action: Dictionary) -> bool:
	if death_pending or int(enemy["hp"]) <= 0 or stealth_remaining > 0.0 or String(enemy["awareness"]) != "alerted": return false
	var profile := _comparison_enemy_profile(String(enemy["kind"]))
	var index := int(action["comparison_strike"])
	var followup: Dictionary = profile["attacks"][index + 1]
	var position := Vector2(enemy["pos"])
	var offset := player_pos - position
	var distance := offset.length()
	if distance > float(followup["distance"]) + STRIKE_COMMIT_BAND or not _has_line_of_sight(position, player_pos): return false
	if rng.randf() >= float(profile["chain_chances"][index]): return false
	_finalise_capture_record(enemy, action)
	_record_enemy_action_event(enemy, "completed", action)
	var direction := offset / distance if distance > 0.01 else Vector2(enemy["facing"])
	_begin_comparison_enemy_attack(enemy, followup, direction, index + 1, Array(profile["chain_chances"]).size())
	_record_enemy_action_event(enemy, "committed", enemy["action"])
	return true

func _respawn_enemies() -> void:
	var retired := {}
	for id in encounter_templates.keys():
		var group: Array = encounter_templates[id]
		if group.size() == 1 and defeated_guardians.has(group[0].kind):
			retired[id] = group
			encounter_templates.erase(id)
	super._respawn_enemies()
	encounter_templates.merge(retired)
	if restoring_demo:
		_imported_enemies = enemies.filter(func(actor: Dictionary) -> bool: return int(actor.id) >= 1000)
		_imported_pickups = world_pickups.duplicate(true)

func _remove_dead_enemies() -> void:
	var victories: Array[String] = []
	for enemy in enemies:
		var kind := String(enemy.kind)
		if int(enemy.hp) <= 0 and Regions.BOSS_IDS.has(kind) and not defeated_guardians.has(kind):
			defeated_guardians[kind] = true
			victories.append(kind)
	super._remove_dead_enemies()
	for kind in victories:
		match kind:
			"sluice_keeper": _set_message("Sluice Keeper defeated. Open the drain wheel to reveal the riverbed.")
			"bell_warden": _set_message("Bell Warden defeated. Release the counterweight to lower the bridge.")
			"hollow_keeper": _set_message("Campaign complete. The Hollow Keeper has fallen. The tower is yours to explore.")

func campaign_victory() -> bool:
	return defeated_guardians.has("hollow_keeper")

func floor_surface_color_at(point: Vector2, layer: String = "") -> Color:
	var target_layer := current_layer if layer.is_empty() else layer
	var buckets: Dictionary = _shape_buckets_by_layer.get(target_layer, {})
	for shape in Array(buckets.get(_spatial_cell_for_point(point), [])):
		if shape.has("regional_palette") and _shape_contains_point(shape, point):
			return Regions.PALETTES[shape.regional_palette]
	return super.floor_surface_color_at(point, layer)

func _update_exploration(force:bool=false) -> void:
	super._update_exploration(force)
	if restoring_demo or loading_demo: return
	for lift in lifts:
		var memo: Dictionary = lift_memory.get(lift.id, {})
		if current_layer == lift.from_layer and is_visible(lift.from_pos):
			memo["from_seen"] = true
		if current_layer == lift.to_layer and is_visible(lift.to_pos):
			memo["to_seen"] = true
		if not memo.is_empty(): lift_memory[lift.id] = memo
	if death_pending or not unanchored_shortcut() or nearby_waystone().is_empty(): return
	var secured:Dictionary=Dictionary(anchor_state.get("shortcut_states", {})).duplicate()
	for shortcut in shortcuts: secured[shortcut.id]=bool(shortcut.unlocked)
	for lift in lifts:
		var memo: Dictionary = lift_memory.get(lift.id, {})
		if bool(memo.get("open", false)): memo["secured"] = true
	anchor_state["shortcut_states"]=secured
	anchor_state["shortcut_unlocked"]=shortcut_unlocked
	_set_message("Waystone reached: opened shortcuts secured.")

func unanchored_shortcut() -> bool:
	for memo in lift_memory.values():
		if bool(memo.get("open", false)) and not bool(memo.get("secured", false)): return true
	return super.unanchored_shortcut()

func _near_crossing() -> Dictionary:
	for crossing in crossings:
		if crossing.layer == current_layer and not operated_crossings.has(crossing.id) and player_pos.distance_to(crossing.lever) <= 108.0:
			return crossing
	return {}

func _near_lift_control() -> Dictionary:
	for lift in lifts:
		if bool(lift.unlocked): continue
		if current_layer == lift.to_layer and player_pos.distance_to(lift.to_pos) <= 100.0:
			return lift
		if bool(lift.bilateral) and current_layer == lift.from_layer and player_pos.distance_to(lift.from_pos) <= 100.0:
			return lift
	return {}

func interaction_label() -> String:
	if not run_active or death_pending: return "WAIT"
	if not nearby_waystone().is_empty(): return "REST"
	var crossing := _near_crossing()
	if not crossing.is_empty():
		return String(crossing.action) if defeated_guardians.has(crossing.boss) else "SEALED"
	if not _near_lift_control().is_empty(): return "OPEN LIFT"
	if current_layer=="underpass" and player_pos.distance_to(RELAY)<150: return "RELEASED" if route_released else "RELEASE"
	var near:=_nearby_transition()
	if not near.is_empty():
		if near.transition.id in ["east_steps", "west_steps"]:
			return ("ASCEND " if current_layer=="underpass" else "DESCEND ")+("EAST" if near.transition.id=="east_steps" else "WEST")
		return "RIDE LIFT" if near.transition.has("bilateral") else "TAKE STAIRS"
	return super.interaction_label()

func request_context_action() -> bool:
	if not is_player_ready() or death_pending: return false
	var crossing := _near_crossing()
	if not crossing.is_empty() and interaction_label() != "REST":
		if not defeated_guardians.has(crossing.boss):
			_set_message("%s still controls this crossing." % CombatCatalogScript.presentation(crossing.boss).name)
			return false
		operated_crossings[crossing.id] = true
		_apply_shortcut_world_state()
		_update_exploration(true)
		_set_message("Channel drained. Walk the riverbed to the foundation stairs." if crossing.id == "sluice_drain" else "Bridge lowered. Walk across to the tower's upper gallery.")
		changed.emit()
		return true
	var lift := _near_lift_control()
	if not lift.is_empty() and interaction_label() != "REST":
		var memo: Dictionary = lift_memory.get(lift.id, {})
		var recognized := bool(memo.get("from_seen" if current_layer == lift.to_layer else "to_seen", false))
		memo["open"] = true
		lift_memory[lift.id] = memo
		_sync_lifts()
		_set_message("%s %s. Reach any Waystone to secure it." % [lift.name, "reconnected" if recognized else "discovered"])
		changed.emit()
		return true
	if interaction_label()=="RELEASED":
		_set_message("Relay already released. East stairs are open; use ASCEND East at the east landing.")
		changed.emit()
		return false
	if interaction_label()=="RELEASE" and is_player_ready():
		route_released=true
		_set_message("Ruin relay released. The east stairs now return to the forest. Open the Dawn path from its far side.")
		changed.emit()
		return true
	var label := interaction_label()
	if label.begins_with("ASCEND ") or label.begins_with("DESCEND ") or label in ["RIDE LIFT", "TAKE STAIRS"]: return use_transition()
	return super.request_context_action()

func _sync_lifts() -> void:
	for transition in transitions:
		if transition.has("bilateral"):
			transition["unlocked"] = bool(Dictionary(lift_memory.get(transition.id, {})).get("open", false))
	for lift in lifts:
		lift["unlocked"] = bool(Dictionary(lift_memory.get(lift.id, {})).get("open", false))

func use_transition() -> bool:
	var near:=_nearby_transition()
	if not near.is_empty() and near.transition.id=="east_steps" and current_layer=="underpass" and not route_released:
		_set_message("East stairs sealed. Release the relay in the underpass.")
		changed.emit()
		return false
	var used:=super.use_transition()
	if used:
		if near.transition.has("name"):
			var area_name := String(world_layers[current_layer].name)
			for area in areas:
				if int(area.id) == current_area_id: area_name = String(area.name)
			_set_message("%s reached via %s." % [area_name, near.transition.name])
		elif near.transition.id == "east_steps":
			_set_message("Ascended East: forest ruin reached. The relay keeps these stairs open." if current_layer == "forest_surface" else "Descended East: relay is "+("released." if route_released else "sealed. Release it below to reopen east ascent."))
	return used

func _build_save_payload() -> Dictionary:
	var payload:=super._build_save_payload()
	payload["player_spells"] = player_spells.duplicate()
	payload["selected_spell"] = selected_spell
	payload["demo_route_released"]=route_released
	var regional_version := REGION_SAVE_VERSION if inspired_combat() else 1
	payload["regional_campaign"] = {"version": regional_version, "combat_style": combat_style, "guardians": defeated_guardians.duplicate(),
		"crossings": operated_crossings.duplicate(), "lifts": lift_memory.duplicate(true), "tick": _simulation_tick_index}
	return payload

func load_run(path: String = "") -> bool:
	if path.is_empty(): path = session_save_path
	var payload: Dictionary = {}
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var value: Variant = file.get_var()
		if value is Dictionary: payload = value
	var regional_value: Variant = payload.get("regional_campaign", {})
	if not regional_value is Dictionary:
		protected_save = true
		return false
	var regional: Dictionary = regional_value
	if String(payload.get("mode_id", "")) != ModeRulesScript.CAMPAIGN_LAB or (path == SAVE_PATH and regional.is_empty()):
		protected_save = true
		return false
	if int(regional.get("version", 0)) > REGION_SAVE_VERSION:
		protected_save = true
		_set_message("This Campaign save needs a newer build.")
		return false
	var saved_style := String(regional.get("combat_style", "default"))
	if not COMBAT_STYLES.has(saved_style):
		protected_save = true
		_set_message("This Campaign save uses an unsupported combat style.")
		return false
	var previous_style := combat_style
	combat_style = saved_style
	defeated_guardians = Dictionary(regional.get("guardians", {})).duplicate()
	operated_crossings = Dictionary(regional.get("crossings", {})).duplicate()
	lift_memory = Dictionary(regional.get("lifts", {})).duplicate(true)
	restoring_demo=true
	loading_demo=true
	var ok:=super.load_run(path)
	if ok:
		_restore_learned_spells(payload)
		route_released=bool(payload.get("demo_route_released",false))
		if regional.is_empty():
			for enemy in _imported_enemies:
				_add_enemy_actor(enemy)
				_next_enemy_id = maxi(_next_enemy_id, int(enemy.id) + 1)
			for pickup in _imported_pickups:
				_add_pickup(pickup)
		else:
			_restore_regional_actor_phases(payload)
		# Migrate checkpoint identity only. Never recapture history or secure pending gates.
		if active_waystone_id in ["moss","ruin"]:
			active_waystone_id="dawn"
			bonfire_pos=Vector2(500,1000)
		if String(anchor_state.get("active_waystone_id","")) in ["moss","ruin"]:
			anchor_state["active_waystone_id"]="dawn"
			anchor_state["bonfire_pos"]=Vector2(500,1000)
			anchor_state["current_layer"]="forest_surface"
		_apply_shortcut_world_state()
	_imported_enemies.clear()
	_imported_pickups.clear()
	loading_demo=false
	restoring_demo=false
	protected_save = not ok and FileAccess.file_exists(path)
	if not ok: combat_style = previous_style
	return ok

func save_run(path: String = "") -> bool:
	if protected_save or (not death_pending and not is_player_ready()): return false
	return super.save_run(path)

func _restore_learned_spells(payload: Dictionary) -> void:
	# Additive save fields: pre-field saves recover only valid, owned recorded forks.
	# Never replay stage effects or purchases; rank, resources and XP are untouched.
	player_spells.assign(["lightning_bolt"] if loadout_id == "mage_elementalist" else [])
	selected_spell = ""
	if loadout_id != "mage_elementalist": return
	if payload.get("player_spells") is Array:
		for value in payload["player_spells"]:
			var spell_id := str(value)
			if not AbilityCatalogScript.spell(spell_id).is_empty() and not player_spells.has(spell_id): player_spells.append(spell_id)
	else:
		var stages: Array = CombatCatalogScript.character_track("elementalist").get("stages",[])
		for index in mini(track_total("elementalist"),stages.size()):
			var stage_id := str(stages[index].id)
			if not ELEMENT_STAGE_SPELLS.has(stage_id): continue
			var recorded: Array[String]=[]
			for entry in upgrades:
				var parts := str(entry).split(":")
				if parts.size()==3 and parts[0]=="elementalist" and parts[1]==stage_id and not recorded.has(parts[2]): recorded.append(parts[2])
			var choice := str(track_choices.get(stage_id,""))
			if choice.is_empty() and recorded.size()==1: choice=recorded[0]
			# Conflicting records or missing choices do not justify inventing a spell.
			if recorded.size()>1 or (recorded.size()==1 and choice!=recorded[0]): continue
			if Array(ELEMENT_STAGE_SPELLS[stage_id]).has(choice) and not player_spells.has(choice): player_spells.append(choice)
	var requested := str(payload.get("selected_spell",""))
	selected_spell = requested if player_spells.has(requested) else player_spells[0]

func _apply_loadout() -> void:
	player_spells.clear()
	selected_spell = ""
	super._apply_loadout()

func character_sheet_data() -> Dictionary:
	var data := super.character_sheet_data()
	data["known_spells"] = player_spells.duplicate()
	data["selected_spell"] = selected_spell
	return data

func _restore_regional_actor_phases(payload: Dictionary) -> void:
	var actions := {}
	for actor in Array(payload.get("enemies", [])):
		actions[int(actor.id)] = Dictionary(actor.action).duplicate(true)
	for enemy in enemies:
		if actions.has(int(enemy.id)): enemy.action = actions[int(enemy.id)]
	_simulation_tick_index = int(Dictionary(payload.regional_campaign).get("tick", roundi(simulation_time / SIM_DT)))

func _apply_shortcut_world_state() -> void:
	_refresh_loaded_region_content()
	walls.assign(base_walls)
	for shortcut in shortcuts:
		if shortcut.layer == current_layer and not bool(shortcut.unlocked): walls.append(shortcut.gate)
	for crossing in crossings:
		if crossing.layer == current_layer and not operated_crossings.has(crossing.id): walls.append(crossing.gate)
	for connection in connections:
		for shortcut in shortcuts:
			if String(connection.get("shortcut_id", "")) == shortcut.id: connection.unlocked = shortcut.unlocked
	shortcut_unlocked = shortcuts.any(func(item: Dictionary) -> bool: return bool(item.unlocked))
	_sync_lifts()
	_build_wall_spatial_index()
	_build_navigation()
	world_render_revision += 1

func return_after_death() -> bool:
	if death_pending:
		for memo in lift_memory.values():
			memo["open"] = bool(memo.get("secured", false))
	var returned:=super.return_after_death()
	if not returned or run_failed: return returned
	# Preserve the inherited offset where it has complete clearance. Moss needs
	# a nearer landing inside the existing northern strip; never change geography.
	if not _demo_return_clear(player_pos):
		for offset in [Vector2(0,90),Vector2(0,-90),Vector2(-90,0),Vector2(90,0),Vector2.ZERO]:
			var candidate:Vector2=bonfire_pos+offset
			if _demo_return_clear(candidate):
				player_pos=candidate
				player_facing=(bonfire_pos-player_pos).normalized()
				_update_exploration(true)
				changed.emit()
				break
	return returned

func _demo_return_clear(point:Vector2) -> bool:
	# Validate the full radius and an additional stride of breathing room.
	var clearance:=PLAYER_RADIUS+36.0
	if not _inside_world(point,clearance): return false
	for i in 16:
		if not _point_on_loaded_floor(point+Vector2.RIGHT.rotated(i*TAU/16)*clearance): return false
	for wall in walls:
		if _circle_intersects_rect(point,clearance,wall): return false
	return true

func unlock_shortcut() -> bool:
	if not super.unlock_shortcut(): return false
	_set_message("Path open for this life. Reach any Waystone to secure it." if unanchored_shortcut() else "Path open and secured at the Waystone.")
	changed.emit()
	return true
