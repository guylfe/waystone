extends SceneTree
## Real renderer and routed input regression for the integrated archive boundary.
const Reports = preload("res://scripts/core/survey_report.gd")
const Experiment = preload("res://scripts/core/survey_experiment.gd")
const SIZES = [Vector2i(390,844),Vector2i(720,480),Vector2i(960,600),Vector2i(720,1280),Vector2i(1280,800)]
var board
var viewport: SubViewport
var checks := 0
var failures: Array = []
var evidence: Array = []
var baseline := false
var capture := false
var tag := ""

func _init(): call_deferred("run")
func check(ok: bool, reason: String):
	checks += 1
	if not ok: failures.append(tag+": "+reason); printerr(tag+": "+reason)
func settle():
	for i in range(6): await process_frame
func touch(p: Vector2):
	for down in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index=87; event.position=p; event.pressed=down
		viewport.push_input(event,true)
func joy(key: int):
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index=key; event.pressed=down
		viewport.push_input(event,true)
func swipe(amount: float):
	var start: Vector2 = board.survey_overlay.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.index=87; press.position=start; press.pressed=true; viewport.push_input(press,true)
	var drag := InputEventScreenDrag.new()
	drag.index=87; drag.position=start-Vector2(0,amount); drag.relative=Vector2(0,-amount)
	viewport.push_input(drag,true)
	press=InputEventScreenTouch.new(); press.index=87; press.position=drag.position; press.pressed=false
	viewport.push_input(press,true)
func buttons() -> Array:
	var result: Array=[]
	for entry in board.controller.menu_entries(board):
		if entry.get("control") is Button: result.append(entry["control"])
	return result
func find_button(text: String):
	for control in buttons():
		if control.text==text: return control
	return null
func rows() -> Array:
	return buttons().filter(func(c): return c.text.contains(". Seed "))
func effective_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect().intersection(Rect2(Vector2.ZERO,Vector2(viewport.size)))
	var parent=control.get_parent()
	while parent != null:
		if parent is Control and (parent.clip_contents or parent is ScrollContainer): rect=rect.intersection(parent.get_global_rect())
		parent=parent.get_parent()
	return rect
func fully_visible(control: Control) -> bool:
	var rect := effective_rect(control)
	return rect.size.x >= control.size.x-1 and rect.size.y >= control.size.y-1
func reveal_touch(control: Control):
	for attempt in range(16):
		if fully_visible(control): return
		var area: Rect2=board.survey_overlay.get_child(0).get_global_rect()
		var amount: float=clampf(control.get_global_rect().get_center().y-area.get_center().y,-area.size.y*0.6,area.size.y*0.6)
		swipe(amount); await settle()
	check(false,"touch could not reveal "+control.text)
func tap_button(control: Control):
	check(control!=null,"button exists")
	if control==null: return
	await reveal_touch(control)
	check(fully_visible(control),"touch uses fully clipped visible button "+control.text)
	touch(control.get_global_rect().get_center()); await settle()
func record(name: String):
	var controls: Array=[]
	for control in buttons():
		controls.append({"text":control.text,"rect":str(control.get_global_rect()),"effective":str(effective_rect(control)),"focused":control.has_focus()})
	var labels: Array=[]
	collect_labels(board.survey_overlay,labels)
	var item := {"name":"%s-%03d-%s"%[tag,evidence.size(),name],"viewport":str(viewport.size),"overlay":str(board.survey_overlay.get_global_rect()),"controls":controls,"labels":labels,"controller_hints":board.controller.active,"scroll":board.survey_overlay.get_child(0).scroll_vertical}
	if capture:
		RenderingServer.force_draw(false)
		var path: String="res://.runtime/archive-final-captures/"+item["name"]+".png"
		check(viewport.get_texture().get_image().save_png(path)==OK,"capture saved")
		item["image"]=path
	evidence.append(item)
func collect_labels(node: Node, result: Array):
	if node is Label and node.is_visible_in_tree():
		result.append({"text":node.text,"rect":str(node.get_global_rect()),"effective":str(effective_rect(node)),"lines":node.get_line_count()})
	for child in node.get_children(): collect_labels(child,result)
func layout_check():
	var safe: Rect2=board.safe_layout_rect
	var panel: Rect2=board.survey_overlay.get_global_rect()
	check(safe.grow(0.5).encloses(panel),"overlay inside safe viewport "+str(panel))
	var scroll: ScrollContainer=board.survey_overlay.get_child(0)
	check(scroll.size.y>0 and scroll.size.x>0,"positive scroll viewport")
	check(scroll.get_child(0).size.x<=scroll.size.x+0.5,"content inside scroll width")
	for child in scroll.get_child(0).get_children():
		if child is Label and child.visible:
			check(child.get_global_rect().position.x>=panel.position.x and child.get_global_rect().end.x<=panel.end.x,"label width within panel "+child.text)
			check(child.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING,"identity has no ellipsis")
			check(child.size.y>=child.get_line_count()*child.get_line_height()-1,"all shaped label lines allocated")
		if child is Container and child.get_script()==null and child.get_class() in ["HFlowContainer","HBoxContainer"] and child.visible:
			check(child.get_global_rect().end.x<=panel.end.x,"hints fit panel")
		if child.get_script()!=null and child.visible:
			check(child.get_global_rect().end.x<=panel.end.x,"hints fit panel")
func detail_check(expected: Dictionary):
	check(board.survey_archived_run==expected,"selected exact intended archive record")
	check(board._archived_report_text()==expected.get("report_text"),"unaltered stored report text")
	layout_check()
	for label in ["SAVE THIS TXT","SHARE THIS REPORT","COPY THIS REPORT","BACK TO ARCHIVE"]:
		check(find_button(label)!=null,"detail retains action "+label)
	await record("detail")
func open_list(hints: bool):
	board.controller.active=hints
	board._build_survey_report_overlay(); await settle()
	await tap_button(find_button("VIEW ARCHIVE"))
	check(board.survey_overlay.get_meta("kind")=="archive","saved report reaches archive")
	layout_check()
func run():
	baseline=OS.get_cmdline_user_args().has("--baseline")
	capture=OS.get_cmdline_user_args().has("--capture")
	if not OS.get_user_data_dir().contains(".runtime"):
		printerr("REFUSED: isolated .runtime storage required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/archive-final-captures"))
	Reports._write_json(Reports.ARCHIVE_PATH,{"format_version":37,"runs":[]})
	viewport=SubViewport.new(); viewport.size=SIZES[0]; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	board=load("res://scripts/presentation/survey_game_board.gd").new(); board.size=viewport.size; viewport.add_child(board); board.set_process(false)
	# Twelve genuine lifecycle archives; artificial notes remain in isolated storage.
	var options := Experiment.defaults()
	options["behavior"]="C"
	for index in range(12):
		board.state.start_run("rogue_sharpshooter","combat_survey",810000001+index,"attrition","energy",false,options)
		board.state.end_survey_run(); board.state.skip_survey_feedback("AUTOMATED ARCHIVE LAYOUT TEST %d"%index)
	var saved: Array=board.state.survey_archive().get("runs",[]).duplicate(true)
	check(saved.size()==12,"twelve real isolated completed records")
	board.room_clear_remaining=0
	for count in ([6] if baseline else [0,1,6,12]):
		var subset: Array=saved.slice(0,count)
		Reports._write_json(Reports.ARCHIVE_PATH,{"format_version":37,"runs":subset})
		var preserved := FileAccess.get_file_as_string(Reports.ARCHIVE_PATH)
		for dimensions in SIZES:
			for hints in ([true] if baseline else [false,true]):
				viewport.size=dimensions; board.size=dimensions; board._layout(); await settle()
				tag="%d-%dx%d-%s"%[count,dimensions.x,dimensions.y,"pad" if hints else "touch"]
				await open_list(hints)
				check(rows().size()==count,"expected row count")
				await record("list-first")
				if count==0:
					check(find_button("COPY LATEST")!=null,"empty archive retains actions")
				else:
					check(fully_visible(rows()[0]),"first row visibly allocated through every ancestor")
					for row in rows(): check(row.size.y>=48,"48-unit row target")
					if baseline:
						board.controller.focus_index=0; joy(JOY_BUTTON_A); await settle()
						await detail_check(subset[0])
						continue
					for index in ([0] if count==1 else [0,count-1]):
						await tap_button(rows()[index]); await detail_check(subset[index])
						await tap_button(find_button("BACK TO ARCHIVE"))
						check(rows().size()==count,"touch return restores archive list")
						# Navigate from the first row to the chosen row using actual D-pad events.
						board.controller.focus_index=0
						joy(JOY_BUTTON_DPAD_DOWN); await settle()
						joy(JOY_BUTTON_DPAD_UP); await settle()
						for step in range(index): joy(JOY_BUTTON_DPAD_DOWN); await settle()
						check(rows()[index].has_focus() and fully_visible(rows()[index]),"controller focus matches visible intended row")
						await record("focus-%d"%index)
						joy(JOY_BUTTON_A); await settle(); await detail_check(subset[index])
						# Reflow an open detail without rebuilding or changing the selected record.
						var next_size: Vector2i=SIZES[(SIZES.find(dimensions)+1)%SIZES.size()]
						viewport.size=next_size; board.size=next_size; board._layout(); await settle()
						layout_check(); check(board.survey_archived_run==subset[index],"resize preserves record")
						await record("detail-resized-%d"%index)
						viewport.size=dimensions; board.size=dimensions; board._layout(); await settle()
						board.controller.focus_index=0
						board.controller.focus_native(board.controller.menu_entries(board)); await settle()
						for step in range(3): joy(JOY_BUTTON_DPAD_DOWN); await settle()
						check(find_button("BACK TO ARCHIVE").has_focus() and fully_visible(find_button("BACK TO ARCHIVE")),"controller reaches visible Back to Archive")
						joy(JOY_BUTTON_A); await settle()
						check(rows().size()==count,"controller return restores archive list")
						board.controller.active=hints; await settle()
					await reveal_touch(find_button("CLOSE")); await record("list-bottom")
					await tap_button(find_button("CLOSE"))
					check(board.survey_overlay.get_meta("kind")=="report","close returns to saved report")
				check(FileAccess.get_file_as_string(Reports.ARCHIVE_PATH)==preserved,"UI leaves archive bytes unchanged")
	var result := {"checks":checks,"failures":failures,"evidence":evidence,"baseline":baseline,"capture":capture,"user_data":OS.get_user_data_dir()}
	var file:=FileAccess.open("res://.runtime/archive-layout-results.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print("SURVEY ARCHIVE LAYOUT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
