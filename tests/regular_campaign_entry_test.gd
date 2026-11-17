extends SceneTree
## Runs against source or packaged resources. All input enters the real root viewport.

var board
var touch := false
var output := ""
var checks := 0
var failures: Array[String] = []
var old_mode := "expedition"
var session
var campaign_save := "user://waystone-regional-campaign.save"
var legacy_save := "user://waystone-expedition.save"
var archive := "user://combat-survey-archive.json"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: return
	failures.append(label)
	print("FAILED: ", label)

func frames(count: int = 5) -> void:
	for i in count: await process_frame

func capture(label: String) -> void:
	if output.is_empty(): return
	RenderingServer.force_draw(false)
	var frame := root.get_texture().get_image()
	check(frame != null and frame.save_png(output.path_join(label + ".png")) == OK, "capture " + label)

func tap(point: Vector2) -> void:
	for pressed in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = point
			event.pressed = pressed
			root.push_input(event, true)
		else:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
		await frames(1)

func choose(mode: String) -> void:
	check(board.progression_rects.has(mode), "main menu offers " + mode)
	if board.progression_rects.has(mode):
		await tap(Rect2(board.progression_rects[mode]).get_center())
	await frames()

func ready_scene(expected: String) -> bool:
	for i in 25:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == expected:
			board = current_scene
			if touch:
				board.desktop_controls = false
				root.min_size = Vector2i(360, 480)
				root.size = Vector2i(390, 844)
				board.queue_redraw()
			await frames()
			return true
	check(false, "scene reached: " + expected)
	return false

func mode_select() -> bool:
	if board.state.mode_id == "combat_survey" and board._lab_ui_active():
		var compare := find_button(board.utility_row, "Survey menu\nStart / Esc")
		check(is_instance_valid(compare), "Survey inspection is reachable by pointer")
		if not is_instance_valid(compare): return false
		await tap(compare.get_global_rect().get_center())
		await frames()
		var button := find_button(board.selector_panel, "Save and choose mode")
		check(is_instance_valid(button) and button.is_visible_in_tree(), "Survey inspection offers mode return")
		if not is_instance_valid(button): return false
		await tap(button.get_global_rect().get_center())
	else:
		await tap(board.reset_rect.get_center())
		check(board.controller.paused, "toolbar opens run menu")
		await capture("campaign-run-menu" if board.scene_file_path.ends_with("regional_campaign.tscn") else "regular-run-menu")
		var entries: Array = board.controller.menu_entries(board)
		var row := -1
		for index in entries.size():
			if entries[index].label == "Save and choose mode": row = index
		check(row >= 0, "run menu offers save and mode return")
		if row < 0: return false
		await tap(board.controller._pause_row(board.controller._pause_box(board, entries.size()), row).get_center())
	if not await ready_scene("res://scenes/main.tscn"): return false
	check(not board.state.run_active and board.setup_stage == "root", "returned to mode selector")
	return not board.state.run_active

func find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var result := find_button(child, label)
		if result != null: return result
	return null

func resume(mode: String) -> bool:
	await choose(mode)
	if mode == "combat_survey":
		var button := find_button(board.survey_overlay, "RESUME SAVED SURVEY")
		check(is_instance_valid(button), "Survey setup offers resume")
		if not is_instance_valid(button): return false
		await tap(button.get_global_rect().get_center())
	else:
		check(board.setup_resume_rect.has_area(), "options show resume for " + mode)
		if not board.setup_resume_rect.has_area(): return false
		await tap(board.setup_resume_rect.get_center())
	return await ready_scene("res://scenes/regional_campaign.tscn" if mode == "regional_campaign" else "res://scenes/main.tscn")

func journey() -> void:
	var original := FileAccess.get_sha256(legacy_save)
	var archive_hash := FileAccess.get_sha256(archive) if FileAccess.file_exists(archive) else ""
	if not await ready_scene("res://scenes/main.tscn"): return
	check(not original.is_empty(), "prior executable wrote a real save")
	check(board.state.run_active and board.state.mode_id == old_mode and board.state.run_seed == 17031, "normal launch resumes the prior save")
	check(session.launch_entry() == old_mode, "upgraded run becomes the next launch entry")
	if not board.state.run_active: return
	var old_time: float = board.state.simulation_time
	if not await mode_select(): return
	await capture("mode-select")
	var regular_slot: String = session.regular_save_path(old_mode)
	var regular_hash := FileAccess.get_sha256(regular_slot)
	check(not regular_hash.is_empty(), "mode return parks prior run in its regular slot")
	await choose("regional_campaign")
	await tap(board._setup_class_rect("mage_elementalist").get_center())
	check(board.setup_loadout == "mage_elementalist" and board.start_rect.has_area(), "Campaign uses regular character setup")
	await capture("campaign-setup")
	await tap(board.start_rect.get_center())
	if not await ready_scene("res://scenes/regional_campaign.tscn"): return
	check(board.state.run_active and board.state.loadout_id == "mage_elementalist", "new Campaign starts selected Mage")
	check(board.state.session_save_path == campaign_save and board.state.waystones.size() == 4, "four Waystones and regional slot")
	check(board.terrain_view != null and board.terrain_view.own_world_3d and board.state.enemies.size() > 40, "real regional scene and enemies")
	await capture("dawn-campaign")
	var initial: Vector2 = board.state.player_pos
	var goal: Vector2 = board._world_to_screen(initial + Vector2(160, 0))
	check(board.board_rect.has_point(goal), "ground input target on the battlefield")
	await tap(goal)
	for i in 120:
		if not board.playing and board.state.simulation_time > 0: break
		await process_frame
	check(board.state.player_pos.distance_to(initial) > 8 and board.state.simulation_time > 0, "routed ground input commits real movement")
	await tap(board.sheet_button_rect.get_center())
	await frames()
	check(board.character_sheet_open and board.character_menu.visible, "Campaign opens Character by toolbar")
	await capture("campaign-character")
	var back := find_button(board.character_menu, "BACK")
	if is_instance_valid(back): await tap(back.get_global_rect().get_center())
	check(not board.character_sheet_open, "Character Back returns to Campaign")
	var saved_position: Vector2 = board.state.player_pos
	var saved_seed: int = board.state.run_seed
	if not await mode_select(): return
	var campaign_hash := FileAccess.get_sha256(campaign_save)
	check(not campaign_hash.is_empty(), "Campaign slot written")
	check(FileAccess.get_sha256(regular_slot) == regular_hash, "Campaign leaves regular slot byte-identical")
	if not await resume(old_mode): return
	check(board.state.run_active and board.state.mode_id == old_mode and board.state.run_seed == 17031 and is_equal_approx(board.state.simulation_time, old_time), "prior regular mode resumes at original seed and time")
	if not await mode_select(): return
	await choose("regional_campaign")
	await tap(board.start_rect.get_center())
	check(board.survey_overlay.visible and board.survey_overlay.get_meta("kind") == "replace_campaign", "replacing Campaign requires confirmation")
	var keep := find_button(board.survey_overlay, "KEEP SAVED CAMPAIGN")
	if is_instance_valid(keep): await tap(keep.get_global_rect().get_center())
	check(FileAccess.get_sha256(campaign_save) == campaign_hash, "cancelling new Campaign preserves the file")
	await tap(board.setup_resume_rect.get_center())
	if not await ready_scene("res://scenes/regional_campaign.tscn"): return
	check(board.state.loadout_id == "mage_elementalist" and board.state.player_pos.is_equal_approx(saved_position) and board.state.run_seed == saved_seed, "Campaign resumes character, position and seed")
	check(FileAccess.get_sha256(campaign_save) == campaign_hash, "resuming does not rewrite Campaign")
	check(FileAccess.get_sha256(legacy_save) == original, "previous-version shared slot is byte-identical")
	if not archive_hash.is_empty():
		check(FileAccess.get_sha256(archive) == archive_hash, "Survey archive is byte-identical")
	var receipt := FileAccess.open("user://test-campaign-resume.json", FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"seed": saved_seed, "position": [saved_position.x, saved_position.y]}))

func relaunch() -> void:
	if not await ready_scene("res://scenes/regional_campaign.tscn"): return
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://test-campaign-resume.json"))
	check(board.state.loadout_id == "mage_elementalist" and board.state.run_seed == int(receipt.seed), "fresh process resumes Campaign")
	var position := Vector2(float(receipt.position[0]), float(receipt.position[1]))
	check(board.state.player_pos.is_equal_approx(position), "fresh process restores Campaign position")

func run() -> void:
	var user_dir := OS.get_user_data_dir().replace("\\", "/")
	print("DISPOSABLE USER DATA ", user_dir)
	if not user_dir.contains("/.runtime/campaign-verification/"):
		push_error("Use disposable Campaign verification data.")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	touch = args.has("portrait")
	old_mode = "combat_survey" if args.has("survey") else "expedition"
	if args.size() > 1 and args[0] == "capture": output = args[1]
	if not output.is_empty():
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.min_size = Vector2i(360, 480)
	root.size = Vector2i(390, 844) if touch else Vector2i(1280, 800)
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	session = load("res://scripts/core/mode_session.gd")
	if change_scene_to_file("res://scenes/main.tscn") != OK:
		quit(2)
		return
	if args.has("relaunch"): await relaunch()
	else: await journey()
	print("REGULAR CAMPAIGN ENTRY ", checks, " checks ", failures.size(), " failures ", failures)
	quit(0 if failures.is_empty() else 1)
