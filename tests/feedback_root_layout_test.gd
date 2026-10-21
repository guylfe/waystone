extends SceneTree
# Real project root stretch and routed input. 390px is a virtual narrow model,
# below the native Windows minimum; this headless test does not create a window.
var board
var checks := 0
var failures: Array=[]
var records: Array=[]
func _init(): call_deferred("run")
func check(ok: bool, why: String):
	checks+=1
	if not ok: failures.append(why); printerr("FAILED: ",why)
func frames(n: int = 6):
	for i in n: await process_frame
func send(event: InputEvent):
	Input.parse_input_event(event.xformed_by(root.get_final_transform()) if event is InputEventMouseButton else event)
func joy(code: int):
	for down in [true,false]:
		var e:=InputEventJoypadButton.new(); e.device=0; e.button_index=code; e.pressed=down
		send(e); await frames(2)
	await frames()
func click(point: Vector2):
	for down in [true,false]:
		var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down
		e.position=point; e.global_position=point; send(e); await frames(2)
	await frames()
func reveal(control: Control):
	var parent=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames(3)
func click_control(control):
	check(control!=null,"routed native control exists")
	if control==null:return
	await reveal(control)
	await click(control.get_global_rect().get_center())
func find(prefix: String):
	if board.inspection_scroll.visible:
		for control in board.inspection_focus:
			if control is Button and control.text.begins_with(prefix):return control
	for entry in board.controller.menu_entries(board):
		var control=entry.get("control")
		if control is Button and control.text.begins_with(prefix):return control
	return null
func setup(dimensions: Vector2i):
	root.size=dimensions
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	board=load("res://scenes/main.tscn").instantiate(); root.add_child(board)
	await frames(12)
	# The menu point is cached before press/release; layout may change on press.
	await click(board.progression_rects.combat_survey.get_center())
	await click_control(find("Behavior")); await click_control(find("Behavior"))
	check(board.survey_choices.behavior=="C","C configured through actual native setup")
	await click_control(find("PLAY SELECTED SURVEY"))
	await frames(10); await joy(JOY_BUTTON_START)
	await click_control(find("End Survey"))
	check(board._display_safe_layout_rect().grow(1).encloses(board.survey_overlay.get_global_rect()),"End confirmation safe at "+str(dimensions))
	await click_control(find("END RUN"))
	await create_timer(2.5).timeout; await frames()
	var reached: bool=board.survey_overlay.visible and board.survey_overlay.get_meta("kind","")=="feedback"
	check(reached,"actual delayed feedback at "+str(dimensions))
	return reached
func clip(control: Control) -> Rect2:
	var result: Rect2=board._display_safe_layout_rect()
	var ancestor=control.get_parent()
	while ancestor!=null:
		if ancestor is Control and ancestor.clip_contents: result=result.intersection(ancestor.get_global_rect())
		ancestor=ancestor.get_parent()
	return result
func all_controls() -> Array:
	var result: Array=[]
	for control in board.survey_overlay.find_children("*","Control",true,false):
		if control.is_visible_in_tree() and (control is Label or control is BaseButton or control is TextEdit or control is TextureRect): result.append(control)
	return result
func audit(label: String, u: float = -1, expected_hints: int = -1):
	if u<0: u=load("res://scripts/presentation/menu_metrics.gd").unit(board)
	# Freeze board dispatch only during a geometry inventory so controller focus
	# does not fight explicit inspection scrolling. Native layout/child processing
	# and the real root transform continue; all input journeys run normally.
	var processing: bool=board.is_processing()
	board.set_process(false)
	var hints=board.survey_overlay.get_child(0).get_child(0).get_child(0)
	if expected_hints>=0: check(hints.visible==(expected_hints==1),label+" actual hints visibility")
	var safe: Rect2=board._display_safe_layout_rect()
	check(safe.grow(1).encloses(board.survey_overlay.get_global_rect()),label+" panel within safe width and height")
	var geometry: Array=[]
	for control in all_controls():
		var rect: Rect2=control.get_global_rect()
		var clipping: Rect2=clip(control)
		var name: String=str(control.get_meta("menu_id",control.text if control is Label or control is BaseButton else control.get_class()))
		check(rect.position.x>=clipping.position.x-1 and rect.end.x<=clipping.end.x+1,label+" horizontal safe/clip "+name)
		await reveal(control)
		rect=control.get_global_rect(); clipping=clip(control)
		check(clipping.grow(1).encloses(rect),label+" full ancestor visibility after scroll "+name)
		if control is BaseButton or control is TextEdit:
			check(control.size.y>=48*u-1,label+" hit height preserved "+name)
		if control is BaseButton or control is Label or control is TextEdit:
			check(control.get_theme_font_size("font_size")>=16*u-1,label+" body font preserved "+name)
		geometry.append({"id":name,"rect":str(rect),"clip":str(clipping)})
	records.append({"label":label,"root_size":str(root.size),"logical":str(board.size),"transform":str(root.get_final_transform()),"unit":u,"safe":str(safe),"panel":str(board.survey_overlay.get_global_rect()),"controller_active":board.controller.active,"hints_visible":hints.visible,"board_processing_during_geometry":false,"controls":geometry})
	board.set_process(processing)
func focus_id() -> String:
	var focused=root.gui_get_focus_owner()
	return load("res://scripts/presentation/menu_navigation.gd").id({"control":focused}) if focused!=null else ""
func reach(target: Control) -> bool:
	for i in range(65):
		var focused=root.gui_get_focus_owner()
		if focused==target:return true
		if focused is Control:
			var delta: Vector2=target.get_global_rect().get_center()-focused.get_global_rect().get_center()
			await joy(JOY_BUTTON_DPAD_DOWN if delta.y>1 else JOY_BUTTON_DPAD_UP if delta.y < -1 else JOY_BUTTON_DPAD_RIGHT if delta.x>0 else JOY_BUTTON_DPAD_LEFT)
		else: await joy(JOY_BUTTON_DPAD_DOWN)
	check(false,"sequential controller reach "+str(target.get_meta("menu_id",target.text)))
	return false
func answer_all():
	for question in board.survey_rating_buttons:
		for control in board.survey_rating_buttons[question]:
			await click_control(control)
			check(board.survey_feedback_ratings.get(question)==int(control.text),"routed rating value "+question+" "+control.text)
	for tag in board.survey_tag_buttons:
		await click_control(board.survey_tag_buttons[tag])
		check(board.survey_feedback_tags.has(tag),"routed tag value "+tag)
	board.survey_notes.text="Labelled QA notes fixture: root-transform retention."
	check(not board.survey_submit_button.disabled,"all answers enable Submit")
func finish(): board.queue_free(); await frames()
func output(label: String):
	var f=FileAccess.open("user://"+label+"-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"));f.close()
	print(label.to_upper()," ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	await setup(Vector2i(1280,800))
	await answer_all()
	var answers: Dictionary=board.survey_feedback_ratings.duplicate(true)
	var tags: Array=board.survey_feedback_tags.duplicate()
	var notes: String=board.survey_notes.text
	var panel_id: int=board.survey_overlay.get_instance_id()
	for dimensions in [Vector2i(1280,800),Vector2i(720,480),Vector2i(390,844),Vector2i(960,600),Vector2i(720,1280),Vector2i(2560,1440),Vector2i(1280,800)]:
		# Scroll focus to an existing lower control before each resize.
		await click_control(board.survey_tag_buttons["energy frustrating"])
		await click_control(board.survey_tag_buttons["energy frustrating"])
		var old_focus=focus_id()
		var old_control=root.gui_get_focus_owner()
		var old_dimensions:=root.size
		var old_scroll: int=board.survey_overlay.get_child(0).scroll_vertical
		root.size=dimensions; await frames(18)
		check(board.survey_overlay.get_instance_id()==panel_id,"resize retains native controls")
		check(focus_id()==old_focus and root.gui_get_focus_owner()==old_control,"resize retains exact control and semantic focus")
		var focused=root.gui_get_focus_owner()
		check(focused is Control and clip(focused).grow(1).encloses(focused.get_global_rect()),"resize preserves visible lower-control context")
		if old_dimensions==dimensions: check(board.survey_overlay.get_child(0).scroll_vertical==old_scroll,"unchanged size preserves exact scroll offset")
		records.append({"label":"resize retention","before_size":str(old_dimensions),"after_size":str(dimensions),"scroll_before":old_scroll,"scroll_after":board.survey_overlay.get_child(0).scroll_vertical,"focus_id":focus_id()})
		check(board.survey_feedback_ratings==answers and board.survey_feedback_tags==tags and board.survey_notes.text==notes,"resize retains answers tags notes")
		board.controller.active=true; await frames()
		await audit("root "+str(dimensions)+" hints on",-1,1)
		board.controller.active=false; await frames()
		await audit("root "+str(dimensions)+" hints off",-1,0)
		board.controller.active=true; await frames()
	# Repeat all questions with sequential native controller focus at the boundary.
	root.size=Vector2i(390,844); await frames(18)
	for question in board.survey_rating_buttons:
		for control in board.survey_rating_buttons[question]:
			if await reach(control):
				check(clip(control).grow(1).encloses(control.get_global_rect()),"focused rating fully visible "+question+control.text)
				await joy(JOY_BUTTON_A)
				check(board.survey_feedback_ratings.get(question)==int(control.text),"controller commits visible rating "+question+control.text)
	var submitted_answers: Dictionary=board.survey_feedback_ratings.duplicate(true)
	await click_control(board.survey_submit_button); await frames()
	check(board.state.trial_complete and board.survey_overlay.get_meta("kind","")=="report","native submission reaches report")
	var stored: Dictionary=board.state.survey_session.rooms.back()
	check(stored.ratings==submitted_answers and stored.tags==tags and stored.notes==notes,"submitted record preserves ratings tags and notes")
	await finish()
	# New root/scene at the narrow transform; feedback is built cold at this width.
	if await setup(Vector2i(390,844)):
		await answer_all()
		board.controller.active=true; await frames()
		await audit("cold narrow hints on",-1,1)
		board.controller.active=false; await frames(); await audit("cold narrow hints off",-1,0)
	await finish()
	output("feedback-root-layout")
