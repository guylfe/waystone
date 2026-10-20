extends SceneTree

const State = preload("res://scripts/core/run_state.gd")
const Board = preload("res://scripts/presentation/survey_game_board.gd")
const Experiment = preload("res://scripts/core/survey_experiment.gd")
const Lab = preload("res://scripts/experiments/combat_lab_catalog.gd")
const Reports = preload("res://scripts/core/survey_report.gd")
const Migrations = preload("res://scripts/core/save_migrations.gd")
var failures: Array = []
var checks := 0
var evidence: Array = []
var capture := false

func _init() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	call_deferred("run")

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: failures.append(why); printerr("CHECK FAILED: ",why)

func options(behavior: String = "C", scenario: String = "generated") -> Dictionary:
	var config := Experiment.defaults()
	config["behavior"] = behavior
	config["scenario"] = scenario
	return config

func input(board, event: InputEvent) -> void:
	board.get_viewport().push_input(event,true)

func click(board, point: Vector2, touch: bool = false) -> void:
	for down in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = point; event.index = 17; event.pressed = down
			input(board,event)
		else:
			var event := InputEventMouseButton.new()
			event.position = point; event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down
			input(board,event)

func joy(board, button: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button; event.pressed = down
		input(board,event)

func sample(board, viewport, name: String) -> void:
	board.visual = board._presentation_snapshot()
	board.queue_redraw()
	await process_frame; await process_frame
	var record := {"name":name,"size":str(viewport.size),"mode":board.state.mode_id,"experiment":board.state.survey_experiment.duplicate(true),"panel_visible":board.lab_panel.visible,"overlay":str(board.survey_overlay.get_meta("kind","")),"world":str(board.board_rect),"enemy_count":board.state.enemies.size()}
	if board.lab_panel.visible:
		board._refresh_action_panel()
		await process_frame; await process_frame
		check(board.lab_panel.get_global_rect().end.y <= board.board_rect.position.y,"header before battlefield "+name)
		check(board.board_rect.size.y >= (250 if viewport.size.x == 390 else 200 if viewport.size == Vector2i(720,480) else 150),"world floor "+name)
		check(board.information_slot.get_global_rect().encloses(board.guidance.get_global_rect()),"guidance slot "+name)
		for line in [board.instruction,board.feedback]+board.enemy_lines:
			if line.visible: check(line.get_global_rect().end.y <= board.action_grid.get_global_rect().position.y,"live text above actions "+name+" "+line.text)
		for button in [board.continue_button,board.recover_button,board.commit_button,board.target_button]+board.utility_row.get_children():
			check(button.size.x >= 48 and button.size.y >= 48,"48 unit target "+name)
		record["readout"] = board.enemy_readout_model()
		record["title"] = board.status.text
		record["instruction"] = board.instruction.text
		record["feedback"] = board.feedback.text
	if capture:
		check(DisplayServer.get_name() != "headless","capture requires renderer")
		# Minimized background windows may withhold automatic frame callbacks.
		# Draw this real GPU viewport explicitly without restoring/activating a window.
		RenderingServer.force_draw(false)
		var path := "res://.runtime/survey-captures/"+name+".png"
		check(viewport.get_texture().get_image().save_png(path) == OK,"save rendered frame")
		record["image"] = path
	evidence.append(record)
	if board.survey_overlay.visible and board.survey_overlay.get_child_count() and board.survey_overlay.get_child(0) is ScrollContainer:
		var content: Control = board.survey_overlay.get_child(0).get_child(0)
		check(content.size.x <= board.survey_overlay.size.x+1,"native overlay content width "+name)

func finish(board) -> void:
	board.state.end_survey_run()
	board.room_clear_remaining = 0
	board._sync_survey_overlay()

func rate(board, note: String) -> void:
	for question in board.survey_rating_buttons:
		board._survey_rating_pressed(question,3)
	board.survey_notes.text = note
	board._survey_tag_toggled(true,"automation-test")
	board._submit_survey_feedback()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/survey-captures"))
	# This suite runs only with task-isolated APPDATA; every artificial answer is labelled.
	check(OS.get_user_data_dir().contains(".runtime") or OS.get_user_data_dir().contains("survey-userdata"),"isolated automation data")
	check(ProjectSettings.get_setting("application/config/name") == "Waystone Prototype","preserve normal archive/save namespace")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	var legacy := {"format_version":36,"run_seed":7,"rooms":[],"report_text":"LEGACY ARCHIVE SENTINEL","game_version":"0.3.3"}
	Reports._write_json(Reports.ARCHIVE_PATH,{"format_version":36,"runs":[legacy]})
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Board.new()
	board.size = viewport.size
	viewport.add_child(board)
	board.set_process(false)
	# Main scene class and actual custom-drawn root entry, then real setup overlay.
	var entry = load("res://scenes/main.tscn").instantiate()
	check(entry.get_script() == Board,"normal main scene owns integration")
	entry.free()
	board.state.abandon_run(); board.setup_stage="root"; board._layout()
	await process_frame; await process_frame
	click(board,Rect2(board.progression_rects["combat_survey"]).get_center(),true)
	check(board.setup_mode == "combat_survey" and board.setup_stage != "root","root Survey entry")
	board.seed_input.text="42"
	if not board.survey_overlay.visible: click(board,board.start_rect.get_center(),true)
	await process_frame; await process_frame
	check(board.survey_overlay.visible and board.survey_overlay.get_meta("kind") == "experiment_setup","actual Survey selection overlay")
	check(board.survey_choices["behavior"] == "A","existing behavior default")
	await sample(board,viewport,"setup-existing-1280")
	for dimensions in [Vector2i(960,600),Vector2i(720,480),Vector2i(720,1280),Vector2i(390,844)]:
		viewport.size=dimensions; board.size=dimensions; board._layout()
		await sample(board,viewport,"setup-%dx%d" % [dimensions.x,dimensions.y])
	viewport.size=Vector2i(1280,800); board.size=viewport.size; board._layout()
	# Controller can reach and activate the first native choice.
	board.controller.focus_index=0
	joy(board,JOY_BUTTON_A)
	await process_frame; await process_frame
	check(board.survey_choices["behavior"] == "B","controller changes behavior")
	# Two actual touch taps retain B->C and C->G (G auto-selects only F2).
	var entries: Array = board.controller.menu_entries(board)
	click(board,entries[0]["control"].get_global_rect().get_center(),true)
	await process_frame; await process_frame
	check(board.survey_choices["behavior"] == "C","touch selects Commit")
	board._confirm_experiment_setup()
	await process_frame; await process_frame
	check(board.state.mode_id == "combat_survey" and board.state.combat_lab,"generated experiment actual start")
	check(board.state.survey_room_definition.has("experiment"),"generated room provenance")
	check(not board.seed_input.visible,"seed field hidden in combat")
	board.state.lab_input_neutral(); board.overlay_release_gate=false
	await sample(board,viewport,"generated-commit-1280")
	finish(board)
	await sample(board,viewport,"feedback-generated-1280")
	for dimensions in [Vector2i(960,600),Vector2i(720,480),Vector2i(720,1280),Vector2i(390,844)]:
		viewport.size=dimensions; board.size=dimensions; board._layout()
		await sample(board,viewport,"feedback-%dx%d" % [dimensions.x,dimensions.y])
	viewport.size=Vector2i(1280,800); board.size=viewport.size; board._layout()
	rate(board,"AUTOMATED INTEGRATION TEST generated manual end")
	check(board.state.trial_complete,"manual end archived through ratings")
	check(board.state.survey_report_text().contains("AUTOMATED INTEGRATION TEST"),"actual report contains submitted note")
	check(board.state.survey_report_text().contains("sword-frozen-commit"),"text report retains provenance")
	if capture:
		board._copy_current_survey_report()
		await process_frame
		var copied := DisplayServer.clipboard_get().replace("\r\n","\n")
		var expected := board.state.survey_report_text().replace("\r\n","\n")
		evidence.append({"clipboard_expected_characters":expected.length(),"clipboard_copied_characters":copied.length(),"clipboard_equal":copied==expected})
		check(copied == expected,"real clipboard copy readback (Windows newline normalized)")
	var archive: Dictionary = board.state.survey_archive()
	check(archive["runs"].size() == 2 and archive["runs"][1]["report_text"] == "LEGACY ARCHIVE SENTINEL","old archive retained")
	board._build_survey_archive_overlay()
	board._open_archived_survey(0)
	check(board._archived_report_text().contains("AUTOMATED INTEGRATION TEST"),"actual archive view record")
	await sample(board,viewport,"archive-generated-1280")
	for dimensions in [Vector2i(960,600),Vector2i(720,480),Vector2i(720,1280),Vector2i(390,844)]:
		viewport.size=dimensions; board.size=dimensions; board._layout()
		await sample(board,viewport,"archive-%dx%d" % [dimensions.x,dimensions.y])
	viewport.size=Vector2i(1280,800); board.size=viewport.size; board._layout()
	# Exercise the real desktop export function, use a uniquely named test report.
	check(board._save_report_text("Waystone_AUTOMATED_Survey_Integration.txt",board.state.survey_all_reports_text()),"desktop report export")
	check(board.survey_export_status.begins_with("EXPORTED"),"export status verified")
	var export_path := board.survey_export_status.trim_prefix("EXPORTED — ")
	check(FileAccess.get_file_as_string(export_path).contains("LEGACY ARCHIVE SENTINEL"),"export contains historical record")
	check(FileAccess.get_file_as_string(export_path).contains("AUTOMATED INTEGRATION TEST"),"export contains real submission")
	evidence.append({"export_path":export_path,"export_hash":FileAccess.get_sha256(export_path)})
	# Custom roster above three; actual next-room policy and both resource axes.
	for rules in ["energy","recovery"]:
		board.survey_overlay.hide(); board.survey_overlay.set_meta("kind","")
		board.state.combat_lab=false
		board.state.custom_room_kinds.assign(["blade","hound","archer","knight","briarhook","kiln_guard","boar","shield"])
		board.state.custom_room_repeat=true
		board.state.start_run("warrior","combat_survey",42,"encounter",rules,false,options())
		board._load_survey_identity(); board._finish_run_start(); board._layout()
		board.state.lab_input_neutral()
		check(board.state.enemies.size() >= 8,"custom roster >3 "+rules)
		check(board.state.combat_rules == rules,"resource axis independent")
		board.visual=board._presentation_snapshot(); board._refresh_action_panel()
		for enemy in board.state.enemies: enemy["revealed_to_player"]=true
		for dimensions in [Vector2i(1280,800),Vector2i(960,600),Vector2i(720,480),Vector2i(720,1280),Vector2i(390,844)]:
			for projection in ["isometric","top_down"]:
				viewport.size=dimensions; board.size=dimensions; board.view_mode=projection; board._layout()
				await sample(board,viewport,"custom-%s-%dx%d-%s" % [rules,dimensions.x,dimensions.y,projection])
		# Diagnostic room-clear via the real resolver, no artificial ratings mixed into personal data.
		for enemy in board.state.enemies: enemy["hp"]=0
		board.state._remove_dead_enemies()
		if board.state.room_clear_pending: board.state._resolve_pending_room_clear()
		check(board.state.survey_feedback_pending,"custom victory feedback")
		board.room_clear_remaining=0; board._sync_survey_overlay()
		rate(board,"AUTOMATED INTEGRATION TEST custom victory / next")
		check(board.state.survey_room_number == 2 and not board.state.trial_complete,"custom repeat goes to real next room")
		check(board.state.survey_room_definition["experiment"]["scenario_id"] == "generated","next preserves provenance")
		check(board.state.lab_neutral_required,"next requires fresh neutral")
	# Crowding is a labelled renderer diagnostic, distinct from the untouched custom room.
	board.controller.active=false
	for index in range(board.state.enemies.size()):
		var enemy: Dictionary = board.state.enemies[index]
		enemy["pos"] = board.state.player_pos+Vector2.RIGHT.rotated(float(index)*TAU/board.state.enemies.size())*190
		enemy["revealed_to_player"]=true
		enemy["action"] = board.state._idle_action()
	board.state._build_enemy_spatial_index(); board.state._update_exploration(true)
	board.state.lab_notice="Diagnostic · eight repositioned actors"
	for dimensions in [Vector2i(720,480),Vector2i(390,844)]:
		for projection in ["isometric","top_down"]:
			viewport.size=dimensions; board.size=dimensions; board.view_mode=projection; board._layout()
			await sample(board,viewport,"crowded-diagnostic-%dx%d-%s" % [dimensions.x,dimensions.y,projection])
	board.detail_open=true; board.diagnostics.show(); board._sync_information()
	await sample(board,viewport,"crowded-all-enemies-details-390")
	for enemy in board.state.enemies:
		check(board.diagnostics.text.contains("#"+board._enemy_readout_tag(int(enemy["id"]))),"full details reach every visible actor")
	board._close_inspection()
	# Repeated real inspection taps, content drags, controller paging and resize.
	for repetition in range(3):
		board.overlay_release_gate=false
		board.inspection_release_required=false
		var before_world := Lab.digest(Lab.authoritative(board.state))
		click(board,board.details_button.get_global_rect().get_center(),true)
		await process_frame; await process_frame
		check(board.inspection_scroll.visible,"touch opens all-enemy inspection")
		var start: Vector2 = board.inspection_scroll.get_global_rect().get_center()
		var press := InputEventScreenTouch.new(); press.index=45; press.position=start; press.pressed=true
		input(board,press)
		var drag := InputEventScreenDrag.new(); drag.index=45; drag.position=start-Vector2(0,70); drag.relative=Vector2(0,-70)
		input(board,drag)
		var release := InputEventScreenTouch.new(); release.index=45; release.position=drag.position; release.pressed=false
		input(board,release)
		check(board.inspection_scroll.scroll_vertical > 0,"touch swipes full details")
		joy(board,JOY_BUTTON_START)
		await process_frame; await process_frame
		check(not board.inspection_scroll.visible,"controller closes inspection")
		viewport.size=Vector2i(720,480) if repetition%2 == 0 else Vector2i(390,844)
		board.size=viewport.size; board._layout()
		board._process(0)
		check(Lab.digest(Lab.authoritative(board.state)) == before_world,"inspection / resize never advances world")
		board._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(board.suspended and board.state.lab_neutral_required,"focus suspend / neutral gate")
		board.suspended=false; board.controller.paused=false
	# Named setup reaches actual report/retry, with no unrated scene restart.
	board.state.abandon_run(); board.survey_choices=options("C","F2")
	board.setup_mode="combat_survey"; board.setup_stage="options"
	board._build_experiment_setup(); board._confirm_experiment_setup()
	board.state.lab_input_neutral(); board._refresh_action_panel()
	await sample(board,viewport,"named-F2-ready")
	finish(board); rate(board,"AUTOMATED INTEGRATION TEST actual named retry")
	check(board.state.trial_complete,"named report reached")
	var old_entry: String = board.state.survey_room_definition["experiment"]["entry"]["entry_digest"]
	board._retry_survey_preset()
	check(board.state.survey_room_number == 1 and not board.state.trial_complete,"actual preset retry starts new rated attempt")
	check(board.state.survey_room_definition["experiment"]["entry"]["entry_digest"] == old_entry,"retry exact entry identity")
	# All named setups use the same factory; exact seeds/geometry are retained.
	for scenario in Lab.FIXTURES:
		var state := State.new(false)
		state.start_run("warrior","combat_survey",42,"encounter","energy",false,options("C",scenario))
		var control: RunState = Lab.create("C",scenario)
		check(state.player_pos == control.player_pos,"preset player position "+scenario)
		check(state.floor_shapes == control.floor_shapes,"preset geometry "+scenario)
		check(state.enemies.size() == control.enemies.size(),"preset enemy count "+scenario)
		check(Lab.digest(state.enemies) == Lab.digest(control.enemies),"preset complete actor state "+scenario)
		check(state.survey_room_definition["experiment"]["entry"]["entry_digest"] == Lab.decision_digest(state),"entry identity "+scenario)
		check(state.survey_room_seed == 42,"preset seed "+scenario)
		check(state.rng.state == control.rng.state,"preset RNG "+scenario)
		state.end_survey_run(); state.skip_survey_feedback("AUTOMATED INTEGRATION TEST preset "+scenario)
		check(state.trial_complete,"named ends as report "+scenario)
	var clean_preset := State.new(false)
	clean_preset.custom_room_kinds.assign(["knight"]); clean_preset.custom_room_xp=500; clean_preset.custom_room_hp_percent=0.25
	clean_preset.start_run("warrior","combat_survey",42,"encounter","energy",false,options("C","F2"))
	check(not clean_preset._custom_room_active() and clean_preset.character_level()==1 and clean_preset.player_hp==clean_preset.player_max_hp,"named replaces custom roster / build / HP")
	# Resume at a frozen junction and prepaid action with exact actor state/debt.
	for prepaid in [false,true]:
		var state := State.new(false)
		state.start_run("warrior","combat_survey",42,"encounter","energy",false,options("C","F1-P"))
		if prepaid: state.lab_toggle_commit(); state.lab_target(int(state.enemies[0]["id"]))
		else: state.request_combo(Vector2.UP,false)
		for tick in range(120):
			state._tick(state.SIM_DT)
			if state.lab_junction() or (prepaid and tick == 8): break
		check(state.save_run("user://integration-resume.save"),"experimental save")
		var restored := State.new(false)
		check(restored.load_run("user://integration-resume.save"),"experimental load")
		check(restored.player_action == state.player_action,"action/debt round trip")
		check(restored.player_energy == state.player_energy,"no resume refund")
		check(restored.enemies[0]["action"] == state.enemies[0]["action"],"enemy tell round trip")
		check(restored._simulation_tick_index == state._simulation_tick_index,"tick parity round trip")
		check(restored.lab_neutral_required,"resume needs neutral")
	# A diagnostic final kill must not discard prepaid cuts or the captured exit.
	for prepaid in [false,true]:
		var action_state := State.new(false)
		action_state.start_run("warrior","combat_survey",42,"encounter","energy",false,options("C","F1-P"))
		if prepaid: action_state.lab_toggle_commit(); action_state.lab_target(int(action_state.enemies[0]["id"]))
		else:
			action_state.request_combo(Vector2.UP,false)
			for tick in range(200):
				action_state._tick(action_state.SIM_DT)
				if action_state.lab_junction(): break
			check(action_state.request_move(Vector2.DOWN,action_state.MOVE_RANGE,false),"captured exit accepted")
		var before := action_state.player_pos
		var debt := action_state.player_commitment_world_remaining()
		var before_time := action_state.simulation_time
		for enemy in action_state.enemies: enemy["hp"]=0
		action_state._remove_dead_enemies()
		check(not action_state.survey_feedback_pending and action_state.room_clear_pending,"winning action still owes consequences")
		for tick in range(1000):
			action_state._tick(action_state.SIM_DT)
			if action_state.survey_feedback_pending: break
		check(action_state.survey_feedback_pending,"last consequence eventually reaches feedback")
		check(action_state.simulation_time-before_time+0.02 >= debt,"whole obligation served")
		if not prepaid: check(action_state.player_pos.distance_to(before)>1,"queued exit completed before feedback")
	# Actual incoming-hit death enters the same rated archive path.
	var dead := State.new(false)
	dead.start_run("warrior","combat_survey",42,"encounter","energy",false,options("C","F1-D"))
	dead._resolve_incoming_hit(-1,9999,"AUTOMATED lethal diagnostic",dead.player_pos+Vector2.RIGHT*60)
	check(dead.survey_feedback_pending and dead.survey_pending_record["outcome"]=="death","real death feedback path")
	dead.submit_survey_feedback({"difficulty":3,"fun":3,"tactical_interest":3,"want_again":3},["automation-test"],"AUTOMATED INTEGRATION TEST death")
	check(dead.trial_complete and dead.survey_report_text().contains("AUTOMATED INTEGRATION TEST death"),"death ratings archived")
	# Supported old saves migrate as control; unknown experimental contracts refuse whole.
	var state := State.new(false)
	state.start_run("rogue_acrobat","combat_survey",42)
	var old := state._build_save_payload(); old["save_version"]=38
	old.erase("survey_experiment")
	check(Migrations.normalize(old,State.SAVE_VERSION)["survey_experiment"].is_empty(),"v38 explicitly remains control")
	var invalid := state._build_save_payload(); invalid["survey_experiment"]={"version":999}
	check(not Migrations.validate_current(invalid,State.SAVE_VERSION).is_empty(),"unknown contract rejected")
	var invalid_file := FileAccess.open("user://unsupported-contract.save",FileAccess.WRITE)
	invalid_file.store_var(invalid,true); invalid_file.close()
	var prior_seed := state.run_seed
	check(not state.load_run("user://unsupported-contract.save") and state.run_seed==prior_seed,"unknown saved contract refused whole")
	for mode in ["expedition","campaign_lab","boss_lab"]:
		state.start_run("rogue_acrobat",mode,42,"encounter","energy",false,options())
		check(not state.combat_lab and state.survey_experiment.is_empty(),"non-Survey remains control "+mode)
	var report := {"checks":checks,"failures":failures,"evidence":evidence,"capture":capture,"user_data":OS.get_user_data_dir()}
	var file := FileAccess.open("res://.runtime/survey-integration-%s-results.json" % ("render" if capture else "headless"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	board.queue_free(); viewport.queue_free()
	print("SURVEY INTEGRATION ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
