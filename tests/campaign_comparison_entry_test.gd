extends SceneTree
## Use an isolated data directory bearing a Campaign save written by 0.3.11.

const Session = preload("res://scripts/core/mode_session.gd")
const RECEIPT := "user://test-comparison-resume.json"

var board
var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var mobile_model := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		printerr("FAILED: ", description)

func frames(count: int = 4) -> void:
	for index in count: await process_frame

func capture(label: String, settle_frames: int = 4) -> void:
	if capture_dir.is_empty(): return
	await frames(settle_frames)
	RenderingServer.force_draw(false)
	var frame := root.get_texture().get_image()
	check(frame != null and frame.save_png(capture_dir.path_join(label + ".png")) == OK, "capture " + label)

func pointer(point: Vector2, touch: bool = false) -> void:
	for pressed in [true, false]:
		var event: InputEvent
		if touch:
			var finger := InputEventScreenTouch.new()
			finger.position = point
			finger.pressed = pressed
			event = finger
		else:
			var click := InputEventMouseButton.new()
			click.position = point
			click.global_position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			event = click
		root.push_input(event, true)
		await frames(1)
	await frames()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	root.push_input(event, true)
	await frames(1)

func keyboard(code: Key) -> void:
	await key(code, true)
	await key(code, false)
	await frames()

func joy(code: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = pressed
	root.push_input(event, true)
	await frames(1)

func gamepad(code: JoyButton) -> void:
	await joy(code, true)
	await joy(code, false)
	await frames()

func trigger(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	root.push_input(event, true)
	await frames(1)

func wait_scene(path: String) -> bool:
	for index in 30:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			board = current_scene
			root.min_size = Vector2i(360, 350)
			if mobile_model: board.desktop_controls = false
			await frames()
			return true
	check(false, "reached " + path)
	return false

func idle() -> bool:
	for index in 360:
		if not board.playing and board.state.is_player_ready(): return true
		await process_frame
	check(false, "%s action completes into an idle decision (%s at %.2f s, playing %s, streaming %s, frame delta %s, processing %s, tree paused %s)" % [
		board.state.combat_style, board.state.player_action.kind, board.state.simulation_time,
		board.playing, board.streaming_action, board.get_process_delta_time(), board.is_processing(), paused])
	return false

func save_and_choose(touch: bool) -> bool:
	await pointer(board.reset_rect.get_center(), touch)
	var entries: Array = board.controller.menu_entries(board)
	for index in entries.size():
		if entries[index].label != "Save and choose mode": continue
		var panel: Rect2 = board.controller._pause_box(board, entries.size())
		await pointer(board.controller._pause_row(panel, index).get_center(), touch)
		if not await wait_scene(Session.MAIN_SCENE): return false
		check(board.setup_stage == "root" and Session.launch_entry() == Session.MODE_SELECT, "save returns to the mode selector")
		return true
	check(false, "pause menu offers Save and choose mode")
	return false

func open_campaign(touch: bool) -> void:
	await pointer(Rect2(board.progression_rects[Session.REGIONAL]).get_center(), touch)
	check(board.setup_mode == Session.REGIONAL and board.setup_stage == "options", "regular mode selector opens Campaign setup")

func verify_geometry(dimensions: Vector2i) -> void:
	root.size = dimensions
	await frames()
	var style_rects: Dictionary = board.campaign_style_rects
	check(style_rects.keys() == Session.CAMPAIGN_STYLES, "three style choices at %s" % dimensions)
	var hitboxes: Array = style_rects.values() + board.setup_class_rects.values()
	hitboxes.append_array([board.setup_back_rect, board.seed_input.get_rect(), board.start_rect, board.setup_resume_rect])
	var scale := root.get_final_transform().y.length()
	for index in hitboxes.size():
		var box: Rect2 = hitboxes[index]
		if not box.has_area(): continue
		check(board.safe_layout_rect.encloses(box), "control is inside the safe area at %s: %s" % [dimensions, box])
		check(box.size.y * scale >= 43.0, "control is at least 44 pixels high at %s: %s" % [dimensions, box])
		for other in range(index + 1, hitboxes.size()):
			check(not box.intersects(hitboxes[other]), "control hitboxes do not overlap at %s" % dimensions)

func journey() -> void:
	var legacy_hash := FileAccess.get_sha256(Session.campaign_save_path("default"))
	check(not legacy_hash.is_empty(), "0.3.11 regional save exists")
	if not await wait_scene(Session.MAIN_SCENE): return
	if mobile_model:
		await open_campaign(true)
	else:
		await keyboard(KEY_DOWN)
		await keyboard(KEY_ENTER)
	check(board.setup_mode == Session.REGIONAL and board.campaign_style == "default", "Campaign opens with Default Waystone")
	check(board.setup_resume_text == "Resume Campaign", "0.3.11 save is discoverable as Default Waystone")
	if not mobile_model:
		await keyboard(KEY_RIGHT)
		await keyboard(KEY_ENTER)
		check(board.campaign_style == "slow", "keyboard arrows and Enter select Slow")
		await keyboard(KEY_LEFT)
		await keyboard(KEY_ENTER)
		check(board.campaign_style == "default", "keyboard can return to Default Waystone")
	for dimensions in [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(800, 360)]:
		await verify_geometry(dimensions)
		await capture("campaign-setup-%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(390, 844) if mobile_model else Vector2i(1280, 800)
	await frames()
	await pointer(Rect2(board.campaign_style_rects["slow"]).get_center(), mobile_model)
	check(board.campaign_style == "slow" and board.setup_resume_text.is_empty(), "Slow has its own initially empty slot")
	await pointer(board._setup_class_rect("rogue_sharpshooter").get_center(), mobile_model)
	check(board._setup_class_label("rogue_sharpshooter").ends_with("Dagger"), "selected build advertises its comparison weapon")
	await capture("campaign-setup-slow")
	await pointer(board.start_rect.get_center(), mobile_model)
	if not await wait_scene(Session.CAMPAIGN_SCENE): return
	check(board.state.combat_style == "slow" and board.state.comparison_weapon() == "dagger", "real Slow Campaign starts the selected build")
	check(board.state.session_save_path == Session.campaign_save_path("slow") and board.state.run_seed == Session.CAMPAIGN_SEED, "Slow uses its slot and the shared seed")
	check(board.state.waystones.size() == 4 and board.terrain_view.own_world_3d, "comparison uses the regular isometric four-region world")
	check(FileAccess.get_sha256(Session.campaign_save_path("default")) == legacy_hash, "starting Slow preserves 0.3.11 save bytes")
	check(board._ordinary_attack_text().title == "ATTACK" and board._commit_action_name() == "Combo", "comparison Sharpshooter gets melee commands")
	await capture("slow-campaign")
	if not capture_dir.is_empty():
		await pointer(board._world_to_screen(board.state.player_pos + Vector2(100, 70)), mobile_model)
		if not await idle(): return
	var start: float = board.state.simulation_time
	if mobile_model: await pointer(board.attack_rect.get_center(), true)
	else: await keyboard(KEY_F)
	check(board.state.player_action.kind == "attack", "Attack input starts one committed cut")
	if not capture_dir.is_empty():
		await capture("slow-attack-windup", 0)
		for index in 60:
			if board._phase(board.visual.player_action) == "STRIKING":
				await capture("slow-attack-contact", 0)
				break
			await frames(1)
		for index in 60:
			if board._phase(board.visual.player_action) == "RECOVERING":
				await capture("slow-attack-recovery", 0)
				break
			await frames(1)
	if not await idle(): return
	check(board.state.simulation_time > start, "the cut advances world time")
	var frozen: float = board.state.simulation_time
	await frames()
	check(is_equal_approx(board.state.simulation_time, frozen), "world stays frozen after release and recovery")
	if mobile_model: await pointer(board.commit_shot_rect.get_center(), true)
	else: await keyboard(KEY_G)
	check(bool(board.state.player_action.get("full_combo_commit", false)), "Combo starts the sequence at the current facing without requiring an enemy")
	if not await idle(): return
	if not await save_and_choose(mobile_model): return
	var slow_hash := FileAccess.get_sha256(Session.campaign_save_path("slow"))
	await open_campaign(mobile_model)
	await gamepad(JOY_BUTTON_DPAD_RIGHT)
	await gamepad(JOY_BUTTON_DPAD_RIGHT)
	await gamepad(JOY_BUTTON_A)
	check(board.campaign_style == "fast", "controller focuses and selects Fast")
	await gamepad(JOY_BUTTON_B)
	check(board.setup_stage == "root", "controller Back returns to paths")
	await open_campaign(mobile_model)
	check(board.campaign_style == "fast", "returning to Campaign retains the last menu selection")
	await capture("campaign-setup-fast")
	await pointer(board.start_rect.get_center(), mobile_model)
	if not await wait_scene(Session.CAMPAIGN_SCENE): return
	check(board.state.combat_style == "fast" and board.state.run_seed == Session.CAMPAIGN_SEED, "Fast uses the same seed and its own style")
	await trigger(1.0)
	await trigger(0.0)
	check(board.state.player_action.kind == "attack", "controller trigger reaches Fast Attack")
	if not await idle(): return
	await joy(JOY_BUTTON_LEFT_SHOULDER, true)
	await gamepad(JOY_BUTTON_LEFT_STICK)
	await joy(JOY_BUTTON_LEFT_SHOULDER, false)
	check(bool(board.state.player_action.get("full_combo_commit", false)), "controller LB and left-stick click reaches Fast Combo")
	if not await idle(): return
	if not await save_and_choose(mobile_model): return
	var fast_hash := FileAccess.get_sha256(Session.campaign_save_path("fast"))
	await open_campaign(mobile_model)
	await pointer(Rect2(board.campaign_style_rects["slow"]).get_center(), mobile_model)
	await pointer(board.setup_resume_rect.get_center(), mobile_model)
	if not await wait_scene(Session.CAMPAIGN_SCENE): return
	check(board.state.combat_style == "slow" and board.state.loadout_id == "rogue_sharpshooter", "Resume Slow restores style and build")
	check(FileAccess.get_sha256(Session.campaign_save_path("slow")) == slow_hash, "resuming Slow preserves its file")
	await keyboard(KEY_R)
	check(board.controller.paused, "keyboard opens the regular Campaign run menu")
	await keyboard(KEY_ESCAPE)
	check(not board.controller.paused and not board.playing, "Back resumes the frozen run")
	if not await save_and_choose(mobile_model): return
	slow_hash = FileAccess.get_sha256(Session.campaign_save_path("slow"))
	await open_campaign(mobile_model)
	await pointer(Rect2(board.campaign_style_rects["fast"]).get_center(), mobile_model)
	await pointer(board.start_rect.get_center(), mobile_model)
	check(board.survey_overlay.visible and board.survey_overlay.get_meta("kind") == "replace_campaign", "New Fast requires replacement confirmation")
	await keyboard(KEY_ESCAPE)
	check(not board.survey_overlay.visible, "Back cancels Fast replacement")
	check(FileAccess.get_sha256(Session.campaign_save_path("fast")) == fast_hash, "cancel preserves Fast")
	board.seed_input.text = "135721"
	await pointer(board.start_rect.get_center(), mobile_model)
	var replace: Button
	for button in board.survey_overlay.find_children("*", "Button", true, false):
		if button.text == "REPLACE AND START CAMPAIGN": replace = button
	check(is_instance_valid(replace), "replacement offers an explicit start")
	if not is_instance_valid(replace): return
	check(board.safe_layout_rect.encloses(replace.get_global_rect()), "replacement action stays within the safe area")
	await capture("campaign-replace-fast")
	await pointer(replace.get_global_rect().get_center(), mobile_model)
	if not await wait_scene(Session.CAMPAIGN_SCENE): return
	check(board.state.combat_style == "fast" and board.state.run_seed == 135721, "replacement restarts Fast with the requested seed")
	check(FileAccess.get_sha256(Session.campaign_save_path("slow")) == slow_hash, "replacing Fast preserves Slow")
	check(FileAccess.get_sha256(Session.campaign_save_path("default")) == legacy_hash, "replacing Fast preserves the 0.3.11 save")
	check(Session.launch_entry() == Session.campaign_entry("fast"), "relaunch remembers Fast")
	var receipt := FileAccess.open(RECEIPT, FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"legacy_hash": legacy_hash}))

func relaunch() -> void:
	if not await wait_scene(Session.CAMPAIGN_SCENE): return
	check(board.state.combat_style == "fast" and board.state.run_seed == 135721, "fresh process resumes Fast in the regular Campaign")
	if not await save_and_choose(mobile_model): return
	await open_campaign(mobile_model)
	await pointer(board.setup_resume_rect.get_center(), mobile_model)
	if not await wait_scene(Session.CAMPAIGN_SCENE): return
	check(board.state.combat_style == "default" and board.state.loadout_id == "mage_elementalist", "legacy Campaign resumes with Default Waystone and its previous character")
	check(is_equal_approx(board.state.player_pos.x, 430.0) and is_equal_approx(board.state.player_pos.y, 1480.0), "legacy Campaign restores its previous position")
	check(board.state.knows_spell("fireball"), "legacy Campaign restores its learned spell")
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECEIPT))
	check(FileAccess.get_sha256(Session.campaign_save_path("default")) == receipt.legacy_hash, "resuming the legacy Campaign leaves its bytes intact")

func run() -> void:
	var data := OS.get_user_data_dir().replace("\\", "/")
	if not data.contains("/.runtime/campaign-verification/"):
		push_error("Use disposable Campaign verification data.")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	mobile_model = args.has("portrait")
	if args.has("capture"):
		capture_dir = args[args.find("capture") + 1]
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.min_size = Vector2i(360, 350)
	root.size = Vector2i(390, 844) if mobile_model else Vector2i(1280, 800)
	root.content_scale_size = Vector2i(720, 1280)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if change_scene_to_file(Session.MAIN_SCENE) != OK:
		quit(2)
		return
	if args.has("relaunch"): await relaunch()
	else: await journey()
	print("CAMPAIGN COMPARISON ENTRY ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
