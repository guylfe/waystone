extends "res://scripts/core/run_state.gd"
const Regions = preload("res://scripts/campaign/campaign_regions.gd")
const REGION_SAVE_VERSION := 1
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
	loading_demo=true
	route_released=false
	if not restoring_demo:
		defeated_guardians.clear()
		operated_crossings.clear()
		lift_memory.clear()
	super.start_run(a,b,c,d,e,f,g)
	loading_demo=false
	if not restoring_demo: _update_exploration(true)

func _install_layout(layout:Dictionary) -> void:
	var regional := Regions.generate(run_seed)
	regional_variant = regional.regional_variant
	set_pieces = regional.set_pieces
	crossings = regional.crossings
	lifts = regional.lifts
	super._install_layout(regional)

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
	payload["regional_campaign"] = {"version": REGION_SAVE_VERSION, "guardians": defeated_guardians.duplicate(),
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
