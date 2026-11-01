extends SceneTree
var board
var view: SubViewport
var checks := 0
var failures: Array=[]
var records: Array=[]
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	checks+=1
	if not ok: failures.append(why); printerr("FAILED: ",why)
func frames(count: int = 4):
	for i in count: await process_frame
func joy(code: int, down: bool = true):
	var event := InputEventJoypadButton.new(); event.button_index=code; event.pressed=down
	event.device=0
	view.push_input(event,true)
func tap(code: int):
	joy(code); await frames(2); joy(code,false); await frames()
func axis(code: int, value: float):
	var event := InputEventJoypadMotion.new(); event.axis=code; event.axis_value=value
	event.device=0
	view.push_input(event,true)
	await frames()
func click(point: Vector2):
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.position=point; event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		view.push_input(event,true)
	await frames()
func focus_text() -> String:
	var owner=view.gui_get_focus_owner()
	return owner.text if owner is BaseButton else ""
func effective(control: Control) -> Rect2:
	var result := Rect2(Vector2.ZERO,Vector2(view.size))
	var parent=control.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents: result=result.intersection(parent.get_global_rect())
		parent=parent.get_parent()
	return result.intersection(control.get_global_rect())
func seek(prefix: String) -> bool:
	for i in range(90):
		var text := focus_text()
		if text.begins_with(prefix): return true
		var target: Control
		if board.inspection_scroll.visible:
			for control in board.inspection_focus:
				if control.text.begins_with(prefix): target=control; break
		else:
			for entry in board.controller.menu_entries(board):
				var control = entry.get("control")
				if control is BaseButton and control.text.begins_with(prefix): target=control; break
		var focused=view.gui_get_focus_owner()
		if target!=null and focused is Control:
			var delta: Vector2=target.get_global_rect().get_center()-focused.get_global_rect().get_center()
			await tap(JOY_BUTTON_DPAD_DOWN if delta.y>1 else JOY_BUTTON_DPAD_UP if delta.y < -1 else JOY_BUTTON_DPAD_RIGHT if delta.x>0 else JOY_BUTTON_DPAD_LEFT)
		else: await tap(JOY_BUTTON_DPAD_DOWN)
	check(false,"reachable via sequential Down: "+prefix+" from "+focus_text())
	return false
func record(label: String):
	records.append({"label":label,"tick":board.state._simulation_tick_index,"focus":focus_text(),"inspection_held":board.inspection_held.duplicate(),"controller_held":board.controller.held.duplicate(),"release_required":board.inspection_release_required,"neutral_required":board.controller.neutral_required,"suspended":board.suspended,"detail":board.sheet_detail.duplicate(true),"menu_visible":board.inspection_scroll.visible,"viewport":str(view.size)})
func start(behavior: String, rules: String, scenario: String = "F2"):
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	view=SubViewport.new(); view.size=Vector2i(1280,800); root.add_child(view)
	board=load("res://scenes/main.tscn").instantiate(); view.add_child(board)
	await frames()
	await click(board.progression_rects["combat_survey"].get_center())
	await tap(JOY_BUTTON_DPAD_DOWN) # Activate the controller in the actual setup.
	await tap(JOY_BUTTON_DPAD_UP)
	await seek("Behavior")
	for i in (1 if behavior=="B" else 2): await tap(JOY_BUTTON_DPAD_RIGHT)
	check(board.survey_choices.behavior==behavior,"actual behavior "+behavior)
	await seek("Encounter")
	if scenario=="F2":
		for i in 4: await tap(JOY_BUTTON_DPAD_RIGHT)
	check(board.survey_choices.scenario==scenario,"actual scenario "+scenario)
	await seek("Resource rules")
	if rules=="recovery": await tap(JOY_BUTTON_DPAD_RIGHT)
	check(board.setup_combat_rules==rules,"actual resource "+rules)
	await tap(JOY_BUTTON_DPAD_RIGHT); await tap(JOY_BUTTON_DPAD_LEFT)
	check(board.setup_combat_rules==rules and focus_text().begins_with("Resource rules"),"Left/Right changes row value in both directions")
	for dimensions in [Vector2i(720,480),Vector2i(390,844),Vector2i(1280,800)]:
		view.size=dimensions; await frames(8)
		var control=view.gui_get_focus_owner()
		var rect: Rect2=control.get_global_rect()
		check(board.survey_overlay.get_global_rect().encloses(rect),"focused field visible after resize "+str(dimensions))
		check(effective(control).size.distance_to(rect.size)<1,"focused field clears every clipping ancestor "+str(dimensions))
		var value: String=board.setup_combat_rules
		await tap(JOY_BUTTON_DPAD_RIGHT)
		check(focus_text().begins_with("Resource rules"),"value edit retains semantic field")
		await tap(JOY_BUTTON_DPAD_LEFT)
		check(board.setup_combat_rules==value,"resize preserves choices")
	await seek("PLAY SELECTED SURVEY"); await tap(JOY_BUTTON_A)
	await frames(10)
	check(board.state.run_active and board.state.combat_lab,"main setup starts selected Survey")
func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	for behavior in ["B","C"]:
		for rules in ["energy","recovery"]:
			await start(behavior,rules)
			await tap(JOY_BUTTON_START)
			check(board.inspection_scroll.visible,"fresh Start opens Survey menu")
			await seek("Character"); await tap(JOY_BUTTON_A)
			check(board.character_sheet_open,"Character opens through real menu A")
			await seek("Belt"); await tap(JOY_BUTTON_A)
			await seek("Slot 1"); await tap(JOY_BUTTON_B)
			if board.character_menu.variant>0: await seek("Tracks & upgrades")
			else: await seek("Swordsmanship")
			await tap(JOY_BUTTON_A)
			if board.sheet_detail.get("kind")=="tracks":
				await seek("Swordsmanship"); await tap(JOY_BUTTON_A)
			await seek("Weapon Art")
			var invoker: String = board.controller.focus_id
			await tap(JOY_BUTTON_A)
			check(not board.sheet_detail.is_empty(),"stage A opens its detail")
			await tap(JOY_BUTTON_B)
			check(board.sheet_detail.get("kind")=="track" and board.controller.focus_id==invoker,"detail Back restores stage invoker")
			while not board.sheet_detail.is_empty(): await tap(JOY_BUTTON_B)
			await tap(JOY_BUTTON_B)
			check(not board.character_sheet_open and not board.character_menu.visible and board.inspection_scroll.visible and focus_text().begins_with("Character"),"Character Back restores invoking menu control and hides closed panel")
			await tap(JOY_BUTTON_B); await frames(12)
			record(behavior+" "+rules+" Character return")
			check(board.inspection_held.is_empty() and not board.controller.held.values().has(true) and not board.inspection_release_required,"all actual button releases clear every owner")
			check(not board.suspended,"top-level Back safely resumes")
			await tap(JOY_BUTTON_START)
			check(board.inspection_scroll.visible,"fresh Start works after Character return")
			await seek("Map"); await tap(JOY_BUTTON_A)
			check(board.map_open,"Map opened through menu")
			await tap(JOY_BUTTON_B)
			check(not board.map_open and board.inspection_scroll.visible,"Map Back restores menu")
			await tap(JOY_BUTTON_B)
			# A held trigger and stick must not become a fresh attack/move on return.
			await tap(JOY_BUTTON_START); await seek("Character"); await tap(JOY_BUTTON_A)
			await axis(JOY_AXIS_TRIGGER_RIGHT,1.0); await axis(JOY_AXIS_RIGHT_X,1.0)
			await tap(JOY_BUTTON_B); await tap(JOY_BUTTON_B); await frames(12)
			check(board.state._simulation_tick_index==0,"held controls across return never auto-act")
			check(board.inspection_release_required,"real neutral gate retained while trigger/stick held")
			await axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
			check(board.inspection_release_required,"remaining held stick keeps return gate")
			await axis(JOY_AXIS_RIGHT_X,0.0); await frames(12)
			check(not board.inspection_release_required,"actual neutral clears return gate")
			await axis(JOY_AXIS_TRIGGER_RIGHT,1.0); await axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
			check(board.state._simulation_tick_index>0,"fresh RT works after full release/repress")
			record(behavior+" "+rules+" fresh RT")
			view.queue_free(); await frames()
	for behavior in ["B","C"]:
		for rules in ["energy","recovery"]:
			await start(behavior,rules,"generated")
			await tap(JOY_BUTTON_START); await seek("Character"); await tap(JOY_BUTTON_A)
			await tap(JOY_BUTTON_B); await tap(JOY_BUTTON_B); await frames(10)
			check(board.inspection_held.is_empty() and not board.controller.held.values().has(true) and not board.inspection_release_required,"ordinary "+behavior+" "+rules+" actual releases clear owners")
			await axis(JOY_AXIS_TRIGGER_RIGHT,1.0); await axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
			check(board.state._simulation_tick_index>0,"ordinary fresh RT works after Character return")
			record("ordinary "+behavior+" "+rules)
			view.queue_free(); await frames()
	await start("C","energy")
	await tap(JOY_BUTTON_START); await seek("Character"); await tap(JOY_BUTTON_A)
	var press := InputEventKey.new(); press.keycode=KEY_F; press.pressed=true; view.push_input(press,true)
	var contact := InputEventScreenTouch.new(); contact.index=321; contact.pressed=true
	contact.position=board.character_menu.get_global_rect().position+Vector2(20,20); view.push_input(contact,true)
	await tap(JOY_BUTTON_B); await tap(JOY_BUTTON_B); await frames(10)
	check(board.state._simulation_tick_index==0 and board.inspection_release_required,"held key and touch across contexts preserve real neutral gate")
	press.pressed=false; view.push_input(press,true); await frames()
	check(board.inspection_release_required,"touch alone still blocks neutral after key release")
	contact.pressed=false; view.push_input(contact,true); await frames(10)
	check(not board.inspection_release_required and board.observed_contacts.is_empty(),"actual touch release clears final contact")
	board._notification(NOTIFICATION_APPLICATION_FOCUS_OUT); await frames()
	check(board.suspended,"focus-loss owner safely suspends")
	# Explicit connection-cancellation diagnostic, separate from physical hardware.
	await tap(JOY_BUTTON_START); await axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	board.controller.disconnected(board,0); await frames()
	check(board.inspection_axes.is_empty() and not board.controller.held.values().has(true),"disconnect cancellation clears captured controller owners")
	view.queue_free(); await frames()
	# Actual delayed feedback, spatial rating rows and the archive Back stack.
	await start("C","energy")
	await tap(JOY_BUTTON_START); await seek("End Survey"); await tap(JOY_BUTTON_A)
	check(board.survey_overlay.get_meta("kind","")=="end_confirm","normal end-confirm context")
	await tap(JOY_BUTTON_B)
	check(board.inspection_scroll.visible and focus_text().begins_with("End Survey"),"cancel end restores invoking control")
	await tap(JOY_BUTTON_A); await seek("END RUN"); await tap(JOY_BUTTON_A)
	await create_timer(2.4).timeout
	check(board.survey_overlay.get_meta("kind","")=="feedback","feedback reached after actual outcome delay")
	await tap(JOY_BUTTON_DPAD_UP) # At first field, no long-form wrap.
	await tap(JOY_BUTTON_DPAD_RIGHT); await tap(JOY_BUTTON_A)
	check(board.survey_feedback_ratings.get("difficulty")==2,"Right follows the visible rating neighbor")
	await tap(JOY_BUTTON_DPAD_DOWN); await tap(JOY_BUTTON_A)
	check(board.survey_feedback_ratings.get("fun")==2,"Down retains the rating column in the next question")
	await tap(JOY_BUTTON_DPAD_DOWN); await tap(JOY_BUTTON_A)
	await tap(JOY_BUTTON_DPAD_DOWN); await tap(JOY_BUTTON_A)
	await seek("SUBMIT"); await tap(JOY_BUTTON_A)
	check(board.state.trial_complete,"normal feedback submission creates report")
	await seek("VIEW ARCHIVE"); await tap(JOY_BUTTON_A)
	check(focus_text().begins_with("01."),"new archive context starts on latest record")
	var payload: String=FileAccess.get_file_as_string("user://combat-survey-archive.json")
	var selected: String=board.controller.focus_id
	await tap(JOY_BUTTON_A); await tap(JOY_BUTTON_B)
	check(board.survey_archived_run.is_empty() and board.controller.focus_id==selected,"archive detail Back restores exact list record")
	await tap(JOY_BUTTON_B)
	check(board.survey_overlay.get_meta("kind","")=="report" and focus_text()=="VIEW ARCHIVE","archive list Back restores report invoker")
	check(FileAccess.get_file_as_string("user://combat-survey-archive.json")==payload,"archive viewing preserves stored report bytes")
	record("feedback/grid/archive journey")
	view.queue_free(); await frames()
	var output=FileAccess.open("res://.runtime/menu-journey-results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("MENU JOURNEY ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
