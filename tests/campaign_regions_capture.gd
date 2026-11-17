extends SceneTree

const Regions = preload("res://scripts/campaign/campaign_regions.gd")
const Executor = preload("res://scripts/core/expedition_combat.gd")
var board
var output := ""
var failures: Array[String] = []
var frames: Array[Dictionary] = []

func _init() -> void:
	call_deferred("run")

func frame(label: String, point: Vector2, layer: String, wide := false) -> void:
	board.opening_view = wide
	board.state.current_layer = layer
	board.state.player_pos = point
	board.state.current_area_id = board.state._area_id_at_position(point, layer)
	board.state._load_current_layer_discovery()
	board.state._apply_shortcut_world_state()
	board.state._update_exploration(true)
	board.visual = board._presentation_snapshot()
	board._layout()
	board._update_crossing_meshes(1.0)
	board._sync_camera()
	board.queue_redraw()
	for i in 7: await process_frame
	RenderingServer.force_draw(false)
	var mirror: Vector2 = board.camera3.unproject_position(Vector3(point.x / 100.0, float(Regions.ELEVATIONS[layer]) / 100.0, point.y / 100.0)) + board.board_rect.position
	var projection_error: float = board._world_to_screen(point).distance_to(mirror)
	if projection_error > 1.6: failures.append(label + " world-to-terrain projection")
	var file := output.path_join(label + ".png")
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(file) != OK: failures.append(label + " capture")
	frames.append({"file": label + ".png", "client": str(DisplayServer.window_get_size()),
		"location": board.state.current_area_name(), "layer": layer, "projection_error": projection_error,
		"dawn_mill": str(board._distant_landmark(point, board.wheel_site, 110)),
		"dawn_tower": str(board._distant_landmark(point, board.crown_site, 330)),
		"wheel": str(board.camera3.unproject_position(Vector3(board.wheel_site.x / 100.0, 3.35, board.wheel_site.y / 100.0)) + board.board_rect.position),
		"lower_freight": str(board.camera3.unproject_position(Vector3(board.freight_site.x / 100.0, 2.4, board.freight_site.y / 100.0)) + board.board_rect.position),
		"lookout_weight": board.lookout_weight})

func defeat(kind: String) -> void:
	var actor: Dictionary = board.state._enemy_by_id(Regions.BOSS_IDS[kind])
	actor.hp = 0
	board.state._remove_dead_enemies()

func operate(kind: String) -> void:
	defeat(kind)
	if not board.state.request_context_action(): failures.append("operate crossing for " + kind)

func tap_world(world: Vector2) -> void:
	var point: Vector2 = board._world_to_screen(world)
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 29
		touch.position = point
		touch.pressed = down
		Input.parse_input_event(touch.xformed_by(root.get_final_transform()))
		await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_min_size(Vector2i.ONE)
	output = ProjectSettings.globalize_path(OS.get_cmdline_user_args()[0])
	var data_root := OS.get_environment("APPDATA").replace("\\", "/").simplify_path()
	var actual_data := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	if not data_root.contains("/.runtime/") or not actual_data.begins_with(data_root + "/"):
		push_error("Capture refused: user data was not isolated: " + actual_data)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(actual_data)
	print("CAPTURE USER DATA ", actual_data)
	for dims in [Vector2i(390, 844), Vector2i(1280, 800)]:
		DisplayServer.window_set_size(dims)
		board = load("res://scenes/regional_campaign.tscn").instantiate()
		root.add_child(board)
		board.set_process(false)
		board.state.start_run("warrior", "campaign_lab", 131137)
		var prefix := str(dims.x) + "x" + str(dims.y) + "-"
		await frame(prefix + "dawn", Vector2(500, 1170), Regions.SURFACE, true)
		await frame(prefix + "dawn-bridge-west", Vector2(500, 1170), Regions.SURFACE)
		await frame(prefix + "dawn-bridge-approach", Vector2(715, 1055), Regions.SURFACE)
		await frame(prefix + "river-wheel", Vector2(2460, 2460), Regions.SURFACE)
		await frame(prefix + "bell-lookout", Vector2(4050, 1445), Regions.RIDGE)
		await frame(prefix + "freight-vista", Vector2(4710, 1570), Regions.RIDGE)
		await tap_world(Vector2(4710, 1640))
		if not bool(Dictionary(board.state.lift_memory.get("freight_lift", {})).get("open", false)):
			failures.append(prefix + " routed lift opening")
		await tap_world(Vector2(4710, 1640))
		if board.state.current_layer != Regions.SURFACE: failures.append(prefix + " routed lift riding")
		await frame(prefix + "reopened-lower-freight", Vector2(4710, 1640), Regions.SURFACE)
		await frame(prefix + "sluice-guarded", Vector2(6900, 2300), Regions.SURFACE)
		operate("sluice_keeper")
		await frame(prefix + "sluice-drained", Vector2(7030, 2300), Regions.SURFACE)
		await frame(prefix + "bridge-raised", Vector2(7170, 980), Regions.RIDGE)
		operate("bell_warden")
		await frame(prefix + "bridge-lowered", Vector2(7410, 970), Regions.RIDGE)
		await frame(prefix + "cistern", Vector2(8280, 2640), Regions.FOUNDATIONS)
		await frame(prefix + "gallery", Vector2(8240, 1130), Regions.RIDGE)
		await frame(prefix + "lantern", Vector2(8170, 1900), Regions.CORE)
		await frame(prefix + "crown", Vector2(8410, 960), Regions.CORE)
		var boss: Dictionary = board.state._enemy_by_id(Regions.BOSS_IDS.hollow_keeper)
		boss.expedition_attack_index = 1
		Executor.choose(board.state, boss)
		await frame(prefix + "hollow-mark", Vector2(8410, 960), Regions.CORE)
		defeat("hollow_keeper")
		await frame(prefix + "victory", Vector2(8410, 960), Regions.CORE)
		board.queue_free()
		await process_frame
	var log := FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	log.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "frames": frames, "failures": failures}, "\t"))
	log.close()
	print("CAMPAIGN REGIONS RENDER ", frames.size(), " frames / ", failures)
	quit(0 if failures.is_empty() else 1)
