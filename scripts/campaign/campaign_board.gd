extends "res://scripts/presentation/game_board.gd"
# Renderer-only adaptation: all actions, collision, timing and input remain in 0.3.7.
const CampaignState = preload("res://scripts/campaign/campaign_state.gd")

const U := 100.0
const HEIGHT := 240.0
const Regions = preload("res://scripts/campaign/campaign_regions.gd")
var ink_only := false
var entry_request: Dictionary = {}
var world_ink: Control
var ink_properties: Array[String] = []
var obstacles: Array[Dictionary] = []
var stair_meshes: Array[MeshInstance3D] = []
var terrain_view: SubViewport
var camera3: Camera3D
var opening_view := true
var opening_camera := Vector2.ZERO
var lookout_camera := Vector2.ZERO
var lookout_weight := 0.0
var wheel_site := Vector2.ZERO
var crown_site := Vector2.ZERO
var freight_site := Vector2.ZERO
var upper_meshes: Array[MeshInstance3D] = []
var regional_meshes: Array[Dictionary] = []
var regional_fixtures: Dictionary = {}
var deck_rects := [Rect2(250,650,650,650), Rect2(900,850,900,250), Rect2(1800,650,650,650)]
var lower_rects := [Rect2(550,200,350,1100), Rect2(550,850,1450,350), Rect2(1650,200,350,1100)]

func _ready() -> void:
	if ink_only: return
	entry_request = ModeSession.take_request(get_tree())
	deck_rects = preload("res://scripts/campaign/campaign_layout.gd").upper()
	super._ready()
	if not state.run_active:
		ModeSession.remember_entry(ModeSession.MODE_SELECT)
		ModeSession.request_scene.call_deferred(get_tree(), ModeSession.MAIN_SCENE,
			{"entry": ModeSession.MODE_SELECT, "notice": "The Campaign save could not be opened. The file was preserved."})
		return
	if not entry_request.is_empty(): ModeSession.remember_entry(ModeSession.REGIONAL)
	_prepare_regional_view()
	_build_terrain()
	_sync_camera()
	world_ink=get_script().new()
	world_ink.ink_only=true
	world_ink.clip_contents=true
	world_ink.show_behind_parent=true
	world_ink.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(world_ink)
	world_ink.set_process(false)
	world_ink.set_process_input(false)
	world_ink.set_process_unhandled_input(false)
	for prop in get_property_list():
		if int(prop.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and prop.name not in ["ink_only","world_ink","ink_properties"]: ink_properties.append(prop.name)
	_sync_ink()

func _mode_select_enabled() -> bool:
	return true

func _can_abandon_from_menu() -> bool:
	return false

func _create_character_menu() -> PanelContainer:
	return preload("res://scripts/campaign/campaign_character_menu.gd").new()

func _can_preview_upgrade(upgrade_id: String) -> bool:
	return not state.next_track_stage(upgrade_id).is_empty()

func _initial_run_state() -> RunState:
	var run := CampaignState.new(false)
	if entry_request.has("loadout"):
		run.start_run(String(entry_request.loadout), "campaign_lab", int(entry_request.seed))
		if not run.save_run(): run.run_active = false
	elif not run.load_run() and entry_request.is_empty() and not run.protected_save:
		# Direct scene launch is used by local renderer fixtures.
		run.start_run("warrior", "campaign_lab", 131137)
	return run

func _prepare_regional_view() -> void:
	if state.simulation_time < 0.001:
		state.message = "Follow the river to Millrace or climb the ridge beyond the ruin to Bell Road. Either guardian opens a way into Hollow Tower."
	opening_view=state.simulation_time<0.001 and state.current_layer=="forest_surface" and state.player_pos.distance_to(Vector2(500,1170))<10
	for piece in state.set_pieces:
		if piece.kind == "wheel": wheel_site = Rect2(piece.rect).get_center()
		if piece.kind == "towers" and piece.layer == Regions.CORE: crown_site = Rect2(piece.rect).get_center()
	for lift in state.lifts:
		if lift.id == "freight_lift": freight_site = lift.from_pos
	visual=_presentation_snapshot()
	_layout()

func _box(r: Rect2, top: float, depth: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=Vector3(r.size.x/U,depth/U,r.size.y/U)
	node.mesh=mesh
	node.position=Vector3(r.get_center().x/U,(top-depth*0.5)/U,r.get_center().y/U)
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=1.0
	node.material_override=mat
	terrain_view.add_child(node)
	return node

func _build_terrain() -> void:
	terrain_view=SubViewport.new()
	terrain_view.own_world_3d=true
	terrain_view.transparent_bg = true
	terrain_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(terrain_view)
	camera3=Camera3D.new()
	camera3.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera3.keep_aspect=Camera3D.KEEP_HEIGHT
	terrain_view.add_child(camera3)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("1b2c30")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c4d9b3")
	env.environment.ambient_light_energy=0.58
	terrain_view.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-60,-25,0)
	sun.light_energy=0.96
	terrain_view.add_child(sun)
	# Every walkable top is generated from the same rectangles installed in simulation.
	for r: Rect2 in preload("res://scripts/campaign/campaign_layout.gd").lower(): _box(r,0,80,Color("536c52"))
	for r: Rect2 in preload("res://scripts/campaign/campaign_layout.gd").upper(): upper_meshes.append(_box(r,HEIGHT,85,Color("829275")))
	for x in [960,1710]:
		_obstacle(Rect2(x,875,65,65),0,HEIGHT-85,Color("52605e"),"underpass")
		_obstacle(Rect2(x,1020,65,65),0,HEIGHT-85,Color("52605e"),"underpass")
	_obstacle(Rect2(1930,690,85,110),HEIGHT,100,Color("a5ac91"),"forest_surface")
	for transition in state.transitions:
		if transition.id not in ["east_steps", "west_steps"]: continue
		var p:Vector2=transition.from_pos
		var opening:=_stair_opening(p)
		for i in range(12):
			var top:=HEIGHT*(12-i)/12.0
			stair_meshes.append(_box(Rect2(opening.position+Vector2(0,i*10),Vector2(opening.size.x,10)),top,top,Color("b8aa83") if i%2==0 else Color("d7c9a0")))
	for feature in state.terrain_features:
		if bool(feature.get("blocks",false)):
			var r:float=float(feature.radius)*0.42
			_obstacle(Rect2(Vector2(feature.pos)-Vector2.ONE*r,Vector2.ONE*r*2),HEIGHT,180,Color("49634d"),feature.layer)
	_build_regional_terrain()
	_update_crossing_meshes(0.0)

func _regional_box(layer: String, rect: Rect2, height: float, depth: float, color: Color) -> MeshInstance3D:
	var mesh := _box(rect, float(Regions.ELEVATIONS[layer]) + height, depth, color)
	regional_meshes.append({"mesh": mesh, "layer": layer, "rect": rect})
	return mesh

func _build_regional_terrain() -> void:
	var laid: Dictionary = {Regions.SURFACE: deck_rects.duplicate()}
	for shape in state.floor_shapes:
		if not shape.has("regional_palette"): continue
		var rect := Rect2(shape.rect)
		var tint: Color = Regions.PALETTES[shape.regional_palette]
		tint = tint.lightened(float(int(shape.part_id) % 4) * 0.032)
		if int(shape.part_id) == 210:
			rect.size.x = 130.0
		var pieces: Array = [rect]
		for earlier in Array(laid.get(shape.layer, [])):
			var cut: Array = []
			for piece in pieces: cut.append_array(_subtract_slab(piece, earlier))
			pieces = cut
		if not laid.has(shape.layer): laid[shape.layer] = []
		laid[shape.layer].append(rect)
		for piece in pieces:
			_regional_box(shape.layer, piece, -0.7, 76, tint)
		_dress_regional_floor(shape, rect)
	for layer in state.base_walls_by_layer:
		if layer == Regions.SURFACE or layer == "underpass": continue
		for wall in state.base_walls_by_layer[layer]:
			_obstacle(wall, Regions.ELEVATIONS[layer], 105, Color("54565b"), layer)
	for wall in Array(state.base_walls_by_layer[Regions.SURFACE]):
		if Rect2(wall).position.x >= 2500: _obstacle(wall, HEIGHT, 95, Color("655344"), Regions.SURFACE)
	for piece in state.set_pieces:
		_build_regional_landmark(piece)
	for crossing in state.crossings:
		var gate := Rect2(crossing.gate)
		if crossing.id == "bell_bridge":
			var deck := _regional_box(crossing.layer, Rect2(gate.position, Vector2(525, gate.size.y)), 2, 17, Color("a28563"))
			var open_height := deck.position.y
			regional_fixtures[crossing.id] = {"deck": deck, "hinge": gate.position.x / U, "half": 525.0 / (U * 2.0),
				"open_height": open_height, "progress": 1.0 if state.operated_crossings.has(crossing.id) else 0.0}
			for offset in [Vector2(-58, -25), Vector2(-58, gate.size.y + 5)]:
				_regional_box(crossing.layer, Rect2(gate.position + offset, Vector2(55, 55)), 380, 455, Color("77717b"))
		else:
			# The guard wall and the water surface move independently so the
			# exposed channel keeps the physical floor silhouette.
			var water: MeshInstance3D = regional_fixtures[crossing.id].water
			var gate_mesh := _regional_box(crossing.layer, gate, 150, 155, Color("685d50"))
			regional_fixtures[crossing.id].merge({"gate": gate_mesh, "water_top": water.position.y,
				"gate_top": gate_mesh.position.y, "progress": 1.0 if state.operated_crossings.has(crossing.id) else 0.0})
	for transition in state.transitions:
		if not transition.has("name"): continue
		for end in ["from", "to"]:
			var p := Vector2(transition[end + "_pos"])
			var layer := String(transition[end + "_layer"])
			var rim := Color("978167") if transition.has("bilateral") else Color("b8a98d")
			_regional_box(layer, Rect2(p - Vector2(58, 45), Vector2(116, 90)), 4, 12, rim)
			for offset in [Vector2(-65, -60), Vector2(65, -60)]:
				_regional_box(layer, Rect2(p + offset - Vector2.ONE * 12, Vector2.ONE * 24), 100, 112, rim.darkened(0.27))
	for stone in state.waystones:
		if stone.id == "dawn": continue
		var p := Vector2(stone.pos)
		_regional_box(stone.layer, Rect2(p - Vector2(47, 44), Vector2(94, 88)), 8, 28, Color("bd9c6a"))

func _subtract_slab(slab: Rect2, earlier: Rect2) -> Array:
	if not slab.intersects(earlier): return [slab]
	var cut := slab.intersection(earlier)
	var pieces: Array = [
		Rect2(slab.position, Vector2(slab.size.x, cut.position.y - slab.position.y)),
		Rect2(Vector2(slab.position.x, cut.end.y), Vector2(slab.size.x, slab.end.y - cut.end.y)),
		Rect2(Vector2(slab.position.x, cut.position.y), Vector2(cut.position.x - slab.position.x, cut.size.y)),
		Rect2(Vector2(cut.end.x, cut.position.y), Vector2(slab.end.x - cut.end.x, cut.size.y)),
	]
	return pieces.filter(func(p: Rect2) -> bool: return p.size.x > 0.05 and p.size.y > 0.05)

func _dress_regional_floor(shape: Dictionary, rect: Rect2) -> void:
	var style := String(shape.regional_palette)
	var tint: Color = Regions.PALETTES[style]
	var layer := String(shape.layer)
	if style in ["mill_interior", "gallery", "tower"]:
		# Inset floor joints orient the player where the camera cuts away walls.
		var inside := rect.grow(-35.0)
		for x in range(100, int(inside.size.x), 145):
			_regional_box(layer, Rect2(inside.position + Vector2(x, 0), Vector2(3, inside.size.y)), 0.25, 1.3, tint.darkened(0.24))
		if int(shape.part_id) in [103, 104, 207, 304] and rect.size.x > 570.0:
			var roof := Rect2(rect.position + Vector2(36, 15), Vector2(rect.size.x - 72, 120))
			_obstacle(roof, Regions.ELEVATIONS[layer] + 140.0, 24, tint.darkened(0.44), layer)
			obstacles.back()["decoration"] = true
			for x in range(36, int(rect.size.x) - 35, 215):
				_regional_box(layer, Rect2(rect.position + Vector2(x, 24), Vector2(20, 25)), 148, 151, tint.darkened(0.45))
	elif style in ["bell", "bell_shelter"]:
		var edge := Rect2(rect.position + Vector2(35, 16), Vector2(maxf(45.0, rect.size.x - 70.0), 8.0))
		_regional_box(layer, edge, 0.4, 2, Color("66727b"))
	elif style == "mill":
		for x in range(110, int(rect.size.x) - 35, 285):
			_regional_box(layer, Rect2(rect.position + Vector2(x, 28), Vector2(44, 17)), 0.4, 3, Color("666d50"))

func _build_regional_landmark(piece: Dictionary) -> void:
	var r := Rect2(piece.rect)
	var layer := String(piece.layer)
	match String(piece.kind):
		"river":
			var drain := r.position.x > 6900 and layer == Regions.SURFACE
			var water := _regional_box(layer, r, 3 if drain else -19, 7, Color("417a82"))
			if drain:
				regional_fixtures["sluice_drain"] = {"water": water}
			else:
				for i in range(90, int(r.size.x), 245):
					_regional_box(layer, Rect2(r.position + Vector2(i, r.size.y * 0.45), Vector2(80, 6)), -14, 2, Color("81a6a0"))
		"wheel":
			var pivot := r.get_center()
			var wheel := MeshInstance3D.new()
			var rim := TorusMesh.new()
			rim.inner_radius = 1.00
			rim.outer_radius = 1.28
			rim.rings = 24
			rim.ring_segments = 8
			wheel.mesh = rim
			wheel.rotation_degrees.x = 90.0
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("594537")
			wheel.material_override = material
			wheel.position = Vector3(pivot.x / U, (Regions.ELEVATIONS[layer] + 95.0) / U, pivot.y / U)
			terrain_view.add_child(wheel)
			regional_meshes.append({"mesh": wheel, "layer": layer, "rect": r})
			for i in 4:
				var spoke := _regional_box(layer, Rect2(pivot - Vector2(111, 8), Vector2(222, 16)), 101, 12, Color("b88d56"))
				spoke.rotation_degrees.z = i * 45.0
			for i in 8:
				var angle := TAU * float(i) / 8
				var pad := _regional_box(layer, Rect2(pivot + Vector2(cos(angle) * 112, -28) - Vector2(14, 10), Vector2(28, 20)), 114 + sin(angle) * 112, 16, Color("c19a63"))
				pad.rotation_degrees.z = rad_to_deg(angle)
		"mill":
			_regional_box(layer, r, 210, 225, Color("6c5948"))
			_regional_box(layer, r.grow(18), 227, 22, Color("9d6655"))
			for x in range(40, int(r.size.x), 93):
				_regional_box(layer, Rect2(r.position + Vector2(x, r.size.y - 5), Vector2(19, 16)), 176, 168, Color("c6a374"))
		"stairs":
			for i in 5:
				_regional_box(layer, Rect2(r.position + Vector2(0, i * 29), Vector2(r.size.x, 29)),
					5.0 - float(i), 9.0, Color("939087").darkened(float(i) * 0.035))
		"sluice", "bell", "towers":
			_regional_box(layer, r, 255, 290, Color("717079"))
			_regional_box(layer, r.grow(12), 272, 24, Color("a19aa1"))
			for x in [0.0, r.size.x - 38.0]:
				_regional_box(layer, Rect2(r.position + Vector2(x, 0), Vector2(38, 36)), 306, 38, Color("c7ad78"))
			if piece.kind == "bell":
				_regional_box(layer, Rect2(r.get_center() - Vector2.ONE * 35, Vector2.ONE * 70), 334, 64, Color("a78042"))

func _update_crossing_meshes(delta: float) -> void:
	for crossing in state.crossings:
		var fixture: Dictionary = regional_fixtures[crossing.id]
		var target := 1.0 if state.operated_crossings.has(crossing.id) else 0.0
		var progress := move_toward(float(fixture.progress), target, delta * 3.0)
		fixture.progress = progress
		if crossing.id == "bell_bridge":
			var deck: MeshInstance3D = fixture.deck
			var angle := deg_to_rad(lerpf(79.0, 0.0, progress))
			deck.rotation.z = angle
			deck.position.x = float(fixture.hinge) + cos(angle) * float(fixture.half)
			deck.position.y = float(fixture.open_height) + sin(angle) * float(fixture.half)
		else:
			var water: MeshInstance3D = fixture.water
			var gate: MeshInstance3D = fixture.gate
			water.position.y = float(fixture.water_top) - 1.12 * progress
			gate.position.y = float(fixture.gate_top) - 1.65 * progress

func _sync_camera() -> void:
	if camera3==null or board_rect.size.y<1: return
	terrain_view.size=Vector2i(board_rect.size)
	camera3.size=board_rect.size.y/(world_scale*sqrt(0.5)*U)
	var point:=_camera_world_position()
	var altitude := float(Regions.ELEVATIONS[state.current_layer])
	var target:=Vector3(point.x/U,altitude/U,point.y/U)
	camera3.position=target+Vector3(20,20*sqrt(2.0/3.0),20)
	camera3.look_at(target)
	camera3.v_offset=0
	camera3.position+=camera3.basis.y*board_rect.size.y*ISO_CAMERA_DROP/(world_scale*sqrt(0.5)*U)
	# Cutaway makes underpass actors/contact readable while retaining bridge supports.
	for mesh in upper_meshes: mesh.visible=state.current_layer=="forest_surface"
	var range_limit := lerpf(1650.0, 3050.0, lookout_weight)
	for entry in regional_meshes:
		var lower_vista: bool = (state.current_layer == Regions.RIDGE and entry.layer == Regions.SURFACE) or (state.current_layer == Regions.SURFACE and entry.layer == Regions.RIDGE and Rect2(entry.rect).position.x >= 7180)
		entry.mesh.visible = (entry.layer == state.current_layer or lower_vista) and Rect2(entry.rect).grow(range_limit).has_point(point)
	for obstacle in obstacles:
		var mesh:MeshInstance3D=obstacle.mesh
		mesh.visible=obstacle.layer==state.current_layer
		obstacle.cutaway=mesh.visible and _obstacle_overlaps_actor(obstacle)
		var material:StandardMaterial3D=mesh.material_override
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if obstacle.cutaway else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a=0.12 if obstacle.cutaway else 1.0

func _process(delta: float) -> void:
	if ink_only or not state.run_active: return
	# Refresh stationary touch intent as the player/camera moves, too.
	if pointer_down and held_movement and held_movement_tracks_pointer:
		var direction:=_pointer_follow_direction(touch_current)
		if not direction.is_zero_approx(): held_direction=direction
	super._process(delta)
	if state.current_layer == Regions.RIDGE or lookout_weight > 0.0 or _freight_sightline_open():
		_update_projection()
	_update_crossing_meshes(delta)
	_sync_camera()
	_sync_ink()

func _toggle_view() -> void:
	pass # The approved demo has a fixed angled camera.

func _draw_bridge_ink() -> void:
	if terrain_view==null or world_scale<=0 or not is_finite(world_scale): return
	var visible := _render_visible_cells()
	var discovered := _render_discovered_cells()
	draw_rect(board_rect, Color("1b2c30"))
	if state.current_layer == Regions.SURFACE: _draw_dawn_horizon()
	draw_texture_rect(terrain_view.get_texture(),board_rect,false)
	for transition in state.transitions:
		if transition.from_layer != state.current_layer and transition.to_layer != state.current_layer: continue
		var p:=Vector2(transition.from_pos if transition.from_layer == state.current_layer else transition.to_pos)
		if not _world_point_on_camera(p, 95.0): continue
		_draw_projected_world_circle(p,65,Color(0.8,0.7,0.3,0.25),Color("dfc983"),2)
		_draw_landmark_label(p, _stair_label(transition))
	_draw_demo_waystone()
	for shortcut in state.shortcuts:
		if shortcut.layer==state.current_layer and not shortcut.unlocked: _draw_shortcut_gate(shortcut)
	if state.current_layer=="underpass":
		_draw_projected_world_circle(state.RELAY,60,Color("c19b4c"),Color.WHITE,2)
		draw_string(ThemeDB.fallback_font,_world_to_screen(state.RELAY)+Vector2(-60,-40),"EAST STAIRS OPEN" if state.route_released else "RELAY / RELEASE EAST STAIRS",0,-1,16,Color.WHITE)
	if state.current_layer=="forest_surface":
		_draw_landmark_label(Vector2(2060, 850), "Forest ruin")
	_draw_regional_signs()
	_draw_obstacle_footprints()
	_draw_demo_recovery_landmarks(discovered)
	for hazard in Array(visual.get("hazards", [])):
		if String(hazard.get("layer", state.current_layer)) == state.current_layer and state.is_visible(hazard.pos, visible):
			_draw_hazard(hazard)
	_draw_field_magic()
	for enemy in Array(visual.get("enemies",[])):
		if String(enemy.get("layer", state.current_layer)) != state.current_layer: continue
		if _world_point_on_camera(enemy.pos, float(enemy.radius) * 2.5) and (state.is_visible(enemy.pos, visible) or bool(enemy.get("touch_revealed", false))):
			_draw_enemy(enemy)
	_draw_player()
	for projectile in Array(visual.get("projectiles",[])):
		if _projectile_is_renderable(projectile, visible): _draw_projectile(projectile)
	_draw_world_pickups(discovered)
	for effect in Array(visual.get("effects",[])):
		if String(effect.get("layer", state.current_layer)) == state.current_layer and state.is_visible(effect.pos, visible):
			_draw_effect(effect)
	_draw_player_damage_overlay()
	_draw_selected_action_hint()
	if held_movement and pointer_down:
		var hint:=_movement_hint_segment()
		draw_line(hint[0],hint[1],Color(DODGE_COLOR,0.55),4)
		draw_circle(hint[1],8,DODGE_COLOR)
	var location := String(state.world_layers[state.current_layer].name)
	for area in state.areas:
		if state.current_area_id == area.id and int(area.id) >= 100: location = String(area.name)
	_draw_landmark_label_at(board_rect.position + Vector2(12, board_rect.size.y - 12), location, false)
	if state.campaign_victory():
		_draw_landmark_label_at(Vector2(board_rect.get_center().x, board_rect.position.y + 218), "CAMPAIGN COMPLETE · HOLLOW KEEPER DEFEATED")

func _restart() -> void:
	_open_run_menu()

func _layout() -> void:
	super._layout()
	view_rect = Rect2()

func _try_transition_press(position: Vector2) -> bool:
	for crossing in state.crossings:
		if crossing.layer != state.current_layer or state.operated_crossings.has(crossing.id): continue
		if _world_to_screen(crossing.lever).distance_to(position) > 30.0: continue
		if state._near_crossing().get("id", "") == crossing.id:
			state.request_context_action()
		else:
			state.message = "Move closer to the %s control." % String(crossing.name).to_lower()
		_finish_passage_press()
		return true
	for lift in state.lifts:
		var from_side: bool = state.current_layer == lift.from_layer
		if (not from_side and state.current_layer != lift.to_layer) or bool(lift.unlocked): continue
		var marker := Vector2(lift.from_pos if from_side else lift.to_pos)
		if _world_to_screen(marker).distance_to(position) > 30.0: continue
		if state._near_lift_control().get("id", "") == lift.id:
			state.request_context_action()
		elif from_side and not bool(lift.bilateral):
			state.message = "Sealed from this side. Find the platform below the forest."
		else:
			state.message = "Move closer to the lift control."
		_finish_passage_press()
		return true
	return super._try_transition_press(position)

func _finish_passage_press() -> void:
	visual = _presentation_snapshot()
	_mark_autosave(true)
	queue_redraw()

func _draw_view_button() -> void:
	pass


# Drawing-only inherited canvas: no state construction, processing or input.
func _sync_ink() -> void:
	if world_ink==null: return
	for key in ink_properties: world_ink.set(key,get(key))
	world_ink.position=board_rect.position
	world_ink.size=board_rect.size
	world_ink.queue_redraw()

func _draw() -> void:
	if ink_only:
		draw_set_transform(-board_rect.position)
		_draw_bridge_ink()
		return
	if state == null or not state.run_active: return
	_sync_camera()
	_sync_ink()
	# Child draws the clipped world behind this canvas; UI paints above it.
	for r in [Rect2(0,0,size.x,board_rect.position.y),Rect2(0,board_rect.end.y,size.x,maxf(0,size.y-board_rect.end.y)),Rect2(0,board_rect.position.y,board_rect.position.x,board_rect.size.y),Rect2(board_rect.end.x,board_rect.position.y,maxf(0,size.x-board_rect.end.x),board_rect.size.y)]: draw_rect(r,BG)
	_draw_world_header()
	_draw_hud()
	if inspected_enemy_id>=0: _draw_inspection()
	_draw_reset_button()
	_draw_map_button()
	_draw_sheet_button()
	if map_open: _draw_map()
	if character_sheet_open: _draw_character_sheet()
	if state.death_pending: _draw_death_overlay()
	controller.draw_overlay(self)
	if state.death_pending: _draw_death_overlay()
	controller.draw_overlay(self)

func _stair_label(transition: Dictionary) -> String:
	if transition.has("name"):
		var label := String(transition.name)
		if transition.has("bilateral"):
			var secured: bool = bool(Dictionary(state.lift_memory.get(transition.id, {})).get("secured", false))
			label += " · secured" if secured else " · open this life" if bool(transition.unlocked) else " · sealed"
		return label
	return ("DESCEND " if state.current_layer=="forest_surface" else "ASCEND ")+("West" if transition.id=="west_steps" else "East / OPEN" if state.route_released else "East / SEALED")

func _draw_enemy_identity(kind: String, pos: Vector2, facing: Vector2, radius: float, color: Color, action: Dictionary = {}) -> void:
	match kind:
		"sluice_keeper":
			super._draw_enemy_identity("kilnmaster", pos, facing, radius, color, action)
			draw_arc(pos, radius * 0.72, 0.0, TAU, 16, Color("b6e2d3"), 3.0)
		"bell_warden":
			super._draw_enemy_identity("bell_regent", pos, facing, radius, color, action)
			draw_line(pos, pos + facing * radius * 1.7, Color("e9dbab"), 4.0)
		"hollow_keeper":
			var side := facing.orthogonal()
			var points := PackedVector2Array([pos - side * radius, pos + facing * radius * 1.35, pos + side * radius, pos - facing * radius * 0.65, pos - side * radius])
			draw_polyline(points, Color("e6d7ef"), 4.0)
		_: super._draw_enemy_identity(kind, pos, facing, radius, color, action)

func _draw_regional_signs() -> void:
	if state.current_layer == Regions.SURFACE:
		_draw_landmark_label(Vector2(2330, 1920), "River descent · Millrace")
		_draw_landmark_label(Vector2(2510, 2510), "Waterwheel")
	elif state.current_layer == Regions.RIDGE:
		_draw_landmark_label(Vector2(4070, 1450), "Millrace below · Freight Balcony east")
	for crossing in state.crossings:
		if crossing.layer != state.current_layer: continue
		var open: bool = state.operated_crossings.has(crossing.id)
		var ready: bool = state.defeated_guardians.has(crossing.boss)
		var status := " · open" if open else " · " + String(crossing.action).to_lower() if ready else " · guarded"
		_draw_landmark_label(crossing.lever, String(crossing.name) + status)
		if not open and _world_point_on_camera(crossing.lever, 80.0):
			var color := Color("f4d085") if ready else Color("c58378")
			_draw_projected_world_circle(crossing.lever, 30, Color(color, 0.25), color, 2)

func _draw_landmark_label(world: Vector2, label: String) -> void:
	if _world_point_on_camera(world, 80.0): _draw_landmark_label_at(_world_to_screen(world) + Vector2(0, -31), label)

func _draw_landmark_label_at(point: Vector2, label: String, centered := true) -> void:
	var font := ThemeDB.fallback_font
	var extent := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var start := point - Vector2(extent.x * 0.5 if centered else 0.0, 0)
	draw_rect(Rect2(start + Vector2(-5, -18), Vector2(extent.x + 10, 22)), Color("25312fdd"))
	draw_string(font, start, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f9e9bd"))

func _draw_dawn_horizon() -> void:
	var observer := Vector2(visual.get("player_pos", state.player_pos))
	if not Rect2(350, 620, 1580, 650).has_point(observer) or wheel_site == Vector2.ZERO: return
	# The long-range skyline looks east along the two regional branches.
	# Bearing and elevation angle are measured from the player's current position.
	var mill := _distant_landmark(observer, wheel_site, 110)
	var tower := _distant_landmark(observer, crown_site, 330)
	var haze := Color("9bada3")
	var dark := Color("687e7b")
	var mill_scale := clampf(2200.0 / observer.distance_to(wheel_site), 0.75, 1.55)
	var wheel_radius := 16.0 * mill_scale
	var center := mill + Vector2(-wheel_radius, -wheel_radius)
	draw_rect(Rect2(mill + Vector2(0, -27) * mill_scale, Vector2(60, 27) * mill_scale), dark)
	draw_colored_polygon(PackedVector2Array([mill + Vector2(-7, -26) * mill_scale, mill + Vector2(60, -26) * mill_scale,
		mill + Vector2(54, -38) * mill_scale, mill + Vector2(0, -38) * mill_scale]), haze)
	draw_arc(center, wheel_radius, 0, TAU, 24, haze, 3.0)
	for i in 4:
		var spoke := Vector2.from_angle(i * TAU / 8) * wheel_radius
		draw_line(center - spoke, center + spoke, haze, 1.5)
	draw_rect(Rect2(tower + Vector2(-31, -42), Vector2(62, 42)), dark)
	draw_rect(Rect2(tower + Vector2(-34, -49), Vector2(68, 9)), haze)
	for x in [-29.0, 17.0]:
		draw_rect(Rect2(tower + Vector2(x, -61), Vector2(12, 13)), Color("bda886"))

func _distant_landmark(observer: Vector2, landmark: Vector2, height: float) -> Vector2:
	var delta := landmark - observer
	var bearing := atan2(delta.y, delta.x)
	var rise := atan2(height, delta.length())
	var horizon := 0.33 if size.y > size.x else (0.235 if opening_view else 0.29)
	return board_rect.position + Vector2(
		board_rect.size.x * (0.235 - bearing * 0.21),
		board_rect.size.y * horizon - rise * 110.0)

func _obstacle(r:Rect2,base:float,height:float,color:Color,layer:String) -> void:
	var mesh:=_box(r,base+height,height,color)
	obstacles.append({"rect":r,"base":base,"height":height,"mesh":mesh,"layer":layer,"cutaway":false})

func _obstacle_overlaps_actor(obstacle:Dictionary) -> bool:
	var r:Rect2=obstacle.rect
	var bounds:=Rect2(_world_to_screen(r.position),Vector2.ZERO)
	for p in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:
		var screen:=_world_to_screen(p)
		bounds=bounds.expand(screen)
		bounds=bounds.expand(screen-Vector2(0,float(obstacle.height)*sqrt(1.5)*world_scale))
	var positions:Array=[visual.get("player_pos",state.player_pos)]
	for enemy in Array(visual.get("enemies",[])):
		if String(enemy.get("layer",state.current_layer))==state.current_layer: positions.append(enemy.pos)
	for p:Vector2 in positions:
		var foot:=_world_to_screen(p)
		var actor_rect:=Rect2(foot-Vector2(30,65)*world_scale,Vector2(60,80)*world_scale)
		if bounds.intersects(actor_rect): return true
	return false

func _draw_obstacle_footprints() -> void:
	for obstacle in obstacles:
		if obstacle.layer!=state.current_layer or bool(obstacle.get("decoration", false)): continue
		var r:Rect2=obstacle.rect
		var points:=PackedVector2Array()
		for p in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y),r.position]: points.append(_world_to_screen(p))
		draw_colored_polygon(points,Color(0.38,0.34,0.24,0.48))
		draw_polyline(points,Color("d9cda2"),2)
		draw_line(points[0],points[2],Color("d9cda2"),1)
		draw_line(points[1],points[3],Color("d9cda2"),1)

func _draw_hud() -> void:
	# Movement guidance is world ink and belongs to the clipped canvas.
	var moving:=held_movement
	held_movement=false
	super._draw_hud()
	held_movement=moving

func _stair_opening(endpoint:Vector2) -> Rect2:
	return Rect2(endpoint+Vector2(100,45),Vector2(70,120))

func _prepare_stairwells() -> void:
	# Subtract the same openings from physical floor and rendered slab rectangles.
	# Both trigger landings remain solid beside the shaft, within interaction range.
	for endpoint in [Vector2(730,760),Vector2(1830,760)]:
		var hole:=_stair_opening(endpoint)
		var pieces:Array=[]
		for r:Rect2 in deck_rects:
			if not r.intersects(hole): pieces.append(r);continue
			var cut:=r.intersection(hole)
			for piece in [Rect2(r.position,Vector2(r.size.x,cut.position.y-r.position.y)),Rect2(Vector2(r.position.x,cut.end.y),Vector2(r.size.x,r.end.y-cut.end.y)),Rect2(Vector2(r.position.x,cut.position.y),Vector2(cut.position.x-r.position.x,cut.size.y)),Rect2(Vector2(cut.end.x,cut.position.y),Vector2(r.end.x-cut.end.x,cut.size.y))]:
				if piece.size.x>0 and piece.size.y>0: pieces.append(piece)
		deck_rects=pieces

func _draw_world_header() -> void:
	# The battlefield footer owns location in both orientations. Keep time and
	# navigation above the shared resource bars.
	var font:=maxi(14,int(minf(size.x,size.y)*0.026))
	draw_string(ThemeDB.fallback_font,board_rect.position+Vector2(12,font+10),"TIME FLOWING" if playing else "TIME FROZEN",HORIZONTAL_ALIGNMENT_LEFT,board_rect.size.x*0.5,font,Color("f0b45a") if playing else DODGE_COLOR)
	var dy:=maxf(0,maxf(sheet_button_rect.end.y,map_rect.end.y)+14-(board_rect.position.y+font+34))
	draw_set_transform(Vector2(0,dy))
	_draw_player_health_bar(font)
	_draw_player_progress_bar(font)
	draw_set_transform(Vector2.ZERO)

func _update_projection() -> void:
	super._update_projection()
	lookout_weight = 0.0
	if state == null: return
	if not opening_view:
		_frame_freight_sightline()
		return
	# Fit the start, blocked near-side gate, bridge and existing ruin together.
	# All coordinates remain in the same world projection used by feet and taps.
	var points:Array[Vector2]=[Vector2(500,1170),Vector2(730,760)]
	for r in [Rect2(1080,850,80,250),Rect2(1930,690,85,110)]:
		for point in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]: points.append(point)
	var bounds:=Rect2(Vector2((points[0].x-points[0].y)*0.5,(points[0].x+points[0].y)*0.25),Vector2.ZERO)
	for point in points:
		var flat:=Vector2((point.x-point.y)*0.5,(point.x+point.y)*0.25)
		bounds=bounds.expand(flat)
		# Includes the existing ruin top and animated actor height.
		bounds=bounds.expand(flat-Vector2(0,125))
	bounds=bounds.grow(55)
	var available:=Rect2(board_rect.position+Vector2(40,190),board_rect.size-Vector2(80,230))
	if available.size.x<=0 or available.size.y<=0: return
	world_scale=minf(world_scale,minf(available.size.x/bounds.size.x,available.size.y/bounds.size.y))
	var anchor:=board_rect.get_center()+Vector2(0,board_rect.size.y*ISO_CAMERA_DROP)
	var projected_center:=bounds.get_center()-(available.get_center()-anchor)/world_scale
	opening_camera=Vector2(projected_center.x+projected_center.y*2,projected_center.y*2-projected_center.x)

func _freight_sightline_open() -> bool:
	return state.current_layer == Regions.SURFACE and bool(state.lift_memory.get("freight_lift", {}).get("open", false))

func _frame_freight_sightline() -> void:
	if wheel_site == Vector2.ZERO: return
	var observer := Vector2(visual.get("player_pos", state.player_pos))
	var view_point := freight_site
	if state.current_layer == Regions.RIDGE:
		view_point = Geometry2D.get_closest_point_to_segment(observer, Vector2(4050, 1445), Vector2(4710, 1570))
	elif not _freight_sightline_open():
		return
	lookout_weight = 1.0 - smoothstep(112.0, 405.0, observer.distance_to(view_point))
	if lookout_weight <= 0.0: return

	# Project real geometry at its layer height. Fit the observer, the wheel
	# below and the freight landing into a single uninterrupted camera view.
	var bounds := Rect2(_vista_point(observer, 0), Vector2.ZERO)
	bounds = bounds.expand(_vista_point(observer, 85))
	var lower_height: float = Regions.ELEVATIONS[Regions.SURFACE] - Regions.ELEVATIONS[state.current_layer]
	for offset in [Vector2(-155, -55), Vector2(155, 55)]:
		bounds = bounds.expand(_vista_point(wheel_site + offset, lower_height + 230))
		bounds = bounds.expand(_vista_point(wheel_site + offset, lower_height))
	for offset in [Vector2(-155, -85), Vector2(155, 85)]:
		bounds = bounds.expand(_vista_point(freight_site + offset, 80))
		bounds = bounds.expand(_vista_point(freight_site + offset, lower_height))
	var available := Rect2(board_rect.position + Vector2(34, 170), board_rect.size - Vector2(68, 215))
	if available.size.x <= 0 or available.size.y <= 0: return
	var fit := minf(available.size.x / bounds.size.x, available.size.y / bounds.size.y)
	var scale := minf(world_scale, fit)
	var anchor := board_rect.get_center() + Vector2(0, board_rect.size.y * ISO_CAMERA_DROP)
	var center := bounds.get_center() - (available.get_center() - anchor) / scale
	lookout_camera = Vector2(center.x + center.y * 2, center.y * 2 - center.x)
	world_scale = lerpf(world_scale, scale, lookout_weight)

func _vista_point(point: Vector2, height_delta: float) -> Vector2:
	return Vector2((point.x - point.y) * 0.5, (point.x + point.y) * 0.25 - height_delta * sqrt(1.5))

func _camera_world_position() -> Vector2:
	if opening_view: return opening_camera
	return super._camera_world_position().lerp(lookout_camera, lookout_weight)

func _finish_opening_view() -> void:
	if not opening_view: return
	opening_view=false
	_update_projection()
	_sync_camera()
	_sync_ink()
	queue_redraw()

func _begin_streamed_action(did_begin:bool,preserve_stream_time:bool=false) -> void:
	# The inherited caller has already converted the opening-view pointer into
	# its committed world direction/target. Reframe only after accepting it.
	super._begin_streamed_action(did_begin,preserve_stream_time)
	if did_begin: _finish_opening_view()

func _commit(did_commit:bool) -> void:
	super._commit(did_commit)
	if did_commit: _finish_opening_view()

func _demo_stone_visible(stone:Dictionary) -> bool:
	# This demo renders the whole physical terrain in view. Dawn stands on the
	# unobstructed surface clearing; discovery is still authoritative on the map.
	return stone.layer==state.current_layer and _world_point_on_camera(stone.pos,70)

func _draw_demo_waystone() -> void:
	for stone in state.waystones:
		if not _demo_stone_visible(stone): continue
		var point:=_world_to_screen(stone.pos)
		draw_circle(point,25*world_scale,Color("e89145"))
		draw_circle(point-Vector2(0,12*world_scale),13*world_scale,Color("f4d36b"))
		_draw_landmark_label_at(point - Vector2(0, 38 * world_scale), String(stone.name))
		if state.player_pos.distance_to(stone.pos)<=state.WAYSTONE_RANGE:
			draw_arc(point,38*world_scale,0,TAU,24,Color("f3d46a"),2)

func _movement_hint_segment() -> PackedVector2Array:
	# A live input guide, not a promised stride endpoint. The committed action
	# retains its original direction and full range until completion.
	var origin:=_world_to_screen(Vector2(visual.get("player_pos",state.player_pos)))
	var endpoint:=touch_current if held_movement_tracks_pointer else origin+_screen_direction(held_direction)*70
	return PackedVector2Array([origin,endpoint])

# Retain inherited non-Waystone cues without duplicating demo stones/stairs.
func _draw_demo_recovery_landmarks(discovered:Dictionary) -> void:
	for shortcut in state.shortcuts:
		if String(shortcut.get("layer", state.current_layer)) != state.current_layer or not (_shortcut_gate_is_discovered(shortcut, discovered) or state.is_discovered(Vector2(shortcut["unlock_pos"]),discovered)): continue
		if not _world_rect_on_camera(Rect2(shortcut["gate"]).grow(90.0)): continue
		if not bool(shortcut.get("unlocked", false)):
			var activation_world := Vector2(shortcut["unlock_pos"])
			var activation := _world_to_screen(activation_world)
			draw_circle(activation, maxf(7.0, 10.0 * world_scale), Color(0.96, 0.78, 0.29, 0.28))
			draw_arc(activation, maxf(9.0, 13.0 * world_scale), 0.0, TAU, 20, Color("f0c84b"), maxf(2.0, 2.5 * world_scale))
			var interaction_radius := float(shortcut.get("interaction_radius", 115.0))
			if state.player_pos.distance_to(activation_world) <= interaction_radius + 35.0:
				var font_size:=maxi(10,int(12*world_scale))
				var label := "OPEN " + String(shortcut.name).to_upper()
				var label_width:=maxf(140,ThemeDB.fallback_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+8)
				draw_string(ThemeDB.fallback_font,activation+Vector2(-label_width*0.5,-28),label,HORIZONTAL_ALIGNMENT_CENTER,label_width,font_size,Color("fff0a6"))
	if bool(state.lost_xp.get("active", false)) and String(state.lost_xp.get("layer",state.current_layer))==state.current_layer and state.is_discovered(Vector2(state.lost_xp["pos"]), discovered) and _world_point_on_camera(Vector2(state.lost_xp["pos"]),70.0):
		var mark := _world_to_screen(Vector2(state.lost_xp["pos"]))
		draw_circle(mark, 24.0 * world_scale, Color(0.78, 0.90, 0.42, 0.22))
		draw_arc(mark, 20.0 * world_scale, 0.0, TAU, 20, Color("d8ed78"), maxf(3.0, world_scale * 4.0))
		draw_string(ThemeDB.fallback_font, mark + Vector2(-32, -30), "%d XP" % int(state.lost_xp.get("amount", 0)), HORIZONTAL_ALIGNMENT_CENTER, 64, maxi(10, int(13 * world_scale)), Color("e9f4b1"))
