extends SceneTree

const Update = preload("res://scripts/core/release_update.gd")
const Run = preload("res://scripts/core/run_state.gd")
const Session = preload("res://scripts/core/mode_session.gd")
const Survey = preload("res://scripts/core/survey_experiment.gd")
const Campaign = preload("res://scripts/campaign/campaign_state.gd")
const OFFER := "v99.0.0"
const PAYLOAD := "Waystone release verification fixture."
var handoffs: Array[String] = []
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAILED: ", detail)

func key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event, true)

func tap(position: Vector2, touch: bool) -> void:
	for down in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = position
			event.pressed = down
			root.push_input(event, true)
		else:
			var event := InputEventMouseButton.new()
			event.position = position
			event.global_position = position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			root.push_input(event, true)

func _release(tag: String, platform: String) -> Dictionary:
	var name: String = Update.ASSETS[platform]
	return {"tag_name": tag, "draft": false, "prerelease": false, "assets": [
		{"name": name, "state": "uploaded", "size": 42, "digest": "sha256:" + PAYLOAD.sha256_text(),
			"browser_download_url": Update.RELEASES + "download/%s/%s" % [tag, name]},
	]}

func _policy_cases() -> void:
	for offered in ["v0.3.10", "v0.10.0", "v1.0.0"]:
		check(Update.eligible_asset(_release(offered, "Windows"), "0.3.9", "Windows").get("tag") == offered, "numeric boundary " + offered)
	for offered in ["v0.3.9", "v0.3.8", "v0.2.95", "v0.3.10-alpha", "0.3.10", "v00.3.10", "v0.3.10\n"]:
		check(Update.eligible_asset(_release(offered, "Android"), "0.3.9", "Android").is_empty(), "ignored tag " + offered.strip_edges())
	var release := _release(OFFER, "Android")
	check(Update.eligible_asset(release, "0.3.9", "Windows").is_empty(), "Android asset ignored on Windows")
	for flag in ["draft", "prerelease"]:
		release[flag] = true
		check(Update.eligible_asset(release, "0.3.9", "Android").is_empty(), "ignored " + flag)
		release[flag] = false
	release.assets[0].browser_download_url = "https://example.invalid/Waystone-Android.apk"
	check(Update.eligible_asset(release, "0.3.9", "Android").is_empty(), "invalid asset origin ignored")
	release = _release(OFFER, "Android")
	for size in [0, 1.5, Update.MAX_ASSET_SIZE + 1]:
		release.assets[0].size = size
		check(Update.eligible_asset(release, "0.3.9", "Android").is_empty(), "invalid asset size ignored")
	release = _release(OFFER, "Android")
	for digest in [null, "sha1:" + PAYLOAD.sha256_text(), "sha256:broken"]:
		release.assets[0].digest = digest
		check(Update.eligible_asset(release, "0.3.9", "Android").is_empty(), "invalid digest ignored")
	release = _release(OFFER, "Android")
	release.assets[0].state = "starter"
	check(Update.eligible_asset(release, "0.3.9", "Android").is_empty(), "unfinished upload ignored")
	release.assets = []
	check(Update.eligible_asset(release, "0.3.9", "Android").is_empty(), "no installer ignored")
	check(Update.eligible_asset(null, "0.3.9", "Android").is_empty(), "invalid release ignored")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not OS.get_user_data_dir().replace("\\", "/").contains("/.runtime/release-update-") or args.size() != 4 or args[0] != "--update-loopback":
		printerr("Requires isolated release-update runner.")
		quit(2)
		return
	var scenario := args[1]
	var platform := args[2]
	var service := root.get_node("ReleaseUpdate") as Update
	service.set_test_feed(args[3], platform, func(path: String): handoffs.append(FileAccess.get_file_as_string(path)))
	root.size = Vector2i(390, 844) if platform == "Android" else Vector2i(1280, 800)
	if scenario in ["resumed", "survey"]:
		var run := Run.new(false)
		var mode := "combat_survey" if scenario == "survey" else "expedition"
		var experiment := {"version": Survey.VERSION, "behavior": "C", "scenario": "F1-P", "arrival": "full", "scouting": false} if scenario == "survey" else {}
		run.start_run("warrior", mode, 42, "encounter", "energy", false, experiment)
		run.session_save_path = Session.regular_save_path(mode)
		check(run.save_run(), "fixture saved through supported format")
		Session.remember_entry(mode)
	elif scenario == "campaign":
		var run := Campaign.new(false)
		run.start_run("warrior", "campaign_lab", 131137)
		check(run.save_run(), "Campaign fixture saved through its own format")
		Session.remember_entry(Session.REGIONAL)
	change_scene_to_file(Session.MAIN_SCENE)
	await scene_changed
	if scenario == "campaign" and (current_scene == null or current_scene.scene_file_path != Session.CAMPAIGN_SCENE):
		await scene_changed
	await process_frame
	var board = current_scene
	check(board.scene_file_path == Session.CAMPAIGN_SCENE if scenario == "campaign" else board.persistent_session,
		"normal application scene entered")
	check(service._started, "normal launch started exactly one request")
	check(not board.controller.paused and handoffs.is_empty(), "startup does not pause or start an installer")
	var failed_download := scenario in ["bad-digest", "short", "foreign-redirect"]
	var expected := scenario in ["fresh", "resumed", "survey", "campaign"] or failed_download
	if expected: check(service.tag.is_empty() and service.get_child_count() == 1, "normal scene ready with request pending")
	if scenario == "resumed":
		check(board.state.run_active, "normal launch reopened saved Expedition")
		var tick: int = board.state._simulation_tick_index
		key(KEY_W)
		await process_frame
		await process_frame
		check(board.playing and board.state._simulation_tick_index > tick, "gameplay input works with pending request")
		# Hold the real commitment at this frame until the delayed reply lands.
		board.set_process(false)
	var focus := root.gui_get_focus_owner()
	var deadline := Time.get_ticks_msec() + 6500
	while service.get_child_count() > 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	check(service.get_child_count() == 0, "background request finished within bound")
	check(service.tag == (OFFER if expected else ""), "eligible release outcome")
	check(root.gui_get_focus_owner() == focus and not board.controller.paused and handoffs.is_empty(), "reply does not steal input, pause, or install")
	if scenario == "fresh":
		_policy_cases()
		await _fresh(board, service)
	elif scenario == "resumed":
		await _resume(board, service, true)
	elif scenario == "survey":
		await _survey(board, service)
	elif scenario == "campaign":
		await _campaign(board, service)
	elif failed_download:
		var entries: Array = board.release_notice.setup_entries()
		tap(Rect2(entries[0].rect).get_center(), false)
		await _wait_download(service)
		check(not service.status.is_empty() and service.phase == Update.Phase.OFFER and service.tag == OFFER,
			"failed verification leaves play and retry available")
		check(handoffs.is_empty() and not FileAccess.file_exists(service._partial), "invalid bytes are never installed or kept")
		tap(Rect2(entries[1].rect).get_center(), false)
		check(service.tag.is_empty(), "Later still works after failure")
	else:
		check(board.release_notice.setup_entries().is_empty(), "no notice actions for ignored response")
	await process_frame
	service.check_on_launch()
	check(service.get_child_count() == 0, "second scene entry never makes a second request")
	print("Release update ", scenario, " / ", platform, ": ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func _fresh(board, service: Update) -> void:
	for extent in [Vector2i(390, 844), Vector2i(720, 480), Vector2i(1280, 800)]:
		root.size = extent
		await process_frame
		var entries: Array = board.release_notice.setup_entries()
		check(entries.size() == 2, "setup actions at " + str(extent))
		for row in entries:
			check(board.safe_layout_rect.encloses(row.rect), "setup action safe at " + str(extent))
			for card in board.progression_rects.values():
				check(not Rect2(card).intersects(row.rect), "setup action clears mode card")
	var actions: Array = board.release_notice.setup_entries()
	if actions.size() != 2: return
	tap(Rect2(actions[0].rect).get_center(), false)
	check(service.phase == Update.Phase.DOWNLOADING, "setup Update now starts download")
	await _wait_download(service)
	check(handoffs == [PAYLOAD] and service.tag.is_empty(), "verified asset reaches platform handoff")
	tap(Rect2(board.progression_rects.expedition).get_center(), false)
	tap(board.start_rect.get_center(), false)
	check(board.state.run_active, "setup still enters ordinary game after a fixture handoff")

func _resume(board, service: Update, touch: bool) -> void:
	check(board.playing and not board.release_notice.toast.visible, "late result stays out of a committed action")
	board.set_process(true)
	var deadline := Time.get_ticks_msec() + 2000
	while board.playing and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	check(board.release_notice.toast.visible, "passive notice appears at the next safe moment")
	tap(board.reset_rect.get_center(), touch)
	check(board.controller.paused, "normal pointer input opens Run menu")
	_tap_run_row(board, "update_now", touch)
	_tap_run_row(board, "Resume", touch)
	await _wait_download(service)
	check(service.phase == Update.Phase.READY and handoffs.is_empty() and not board.controller.paused,
		"finished download does not interrupt resumed play")
	service.install(func() -> bool: return false)
	check(handoffs.is_empty() and service.phase == Update.Phase.READY, "failed save blocks handoff")
	board.state.player_hp -= 1
	tap(board.reset_rect.get_center(), touch)
	_tap_run_row(board, "update_now", touch)
	var saved := Run.new(false)
	check(saved.load_run(board.state.session_save_path) and saved.player_hp == board.state.player_hp,
		"update saves the current run before handoff")
	check(handoffs == [PAYLOAD] and service.tag.is_empty(), "Run menu hands off only verified bytes")

func _wait_download(service: Update) -> void:
	var end := Time.get_ticks_msec() + 3000
	while service.phase == Update.Phase.DOWNLOADING and Time.get_ticks_msec() < end:
		await process_frame
	await process_frame

func _campaign(board, service: Update) -> void:
	check(board.scene_file_path == Session.CAMPAIGN_SCENE and board.state.run_active, "normal launch reopens Campaign")
	tap(board.reset_rect.get_center(), false)
	check(board.controller.paused, "Campaign uses the shared Run menu")
	board.state.player_hp -= 1
	_tap_run_row(board, "update_now", false)
	await _wait_download(service)
	var saved := Campaign.new(false)
	check(saved.load_run() and saved.player_hp == board.state.player_hp,
		"Campaign saves the current run in its own slot before handoff")
	check(handoffs == [PAYLOAD] and service.tag.is_empty(), "Campaign hands off verified bytes")

func _tap_run_row(board, id: String, touch: bool) -> void:
	var entries: Array = board.controller.menu_entries(board)
	for index in entries.size():
		if entries[index].get("id", entries[index].label) == id:
			tap(board.controller._pause_row(board.controller._pause_box(board, entries.size()), index).get_center(), touch)
			return
	check(false, "reachable Run menu row " + id)

func _survey(board, service: Update) -> void:
	key(KEY_ESCAPE)
	await process_frame
	check(board.suspended and board.inspection_scroll.visible, "resumed Survey opens its normal menu")
	for label in ["Update now · " + OFFER, "Later"]:
		var button: Button = null
		for control in board.selector_panel.get_children():
			if control.text == label: button = control
		check(button != null and board.inspection_focus.has(button), "Survey action reachable in existing focus order")
		if button == null: continue
		board.inspection_scroll.ensure_control_visible(button)
		await process_frame
		tap(button.get_global_rect().get_center(), true)
		if label != "Later": await create_timer(0.15).timeout
	check(handoffs.is_empty() and service.tag.is_empty() and not FileAccess.file_exists(service._partial),
		"Survey Later cancels an in-flight download")
