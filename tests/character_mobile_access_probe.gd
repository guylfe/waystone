extends SceneTree
# Discovery adaptation of the retained 2026-11-01 specialist probe. Gesture/root/fixture routines retained.
# Legacy wheel comparison omitted; it is not mobile access evidence.
# Diagnostic only: immutable product source; normal main scene/root; synthetic XP.
var board
var records: Array=[]
func _init(): call_deferred("run")
func frames(n: int=8):
	for i in n: await process_frame
func send(e: InputEvent):
	Input.parse_input_event(e.xformed_by(root.get_final_transform()))
func touch(p: Vector2, down: bool):
	var e:=InputEventScreenTouch.new(); e.index=71; e.position=p; e.pressed=down; send(e)
	await frames(2)
func tap(p: Vector2):
	await touch(p,true); await touch(p,false); await frames()
func click(p: Vector2):
	for down in [true,false]:
		var e:=InputEventMouseButton.new(); e.position=p; e.global_position=p
		e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down; send(e); await frames(2)
	await frames()
func swipe(p: Vector2):
	await touch(p,true)
	for i in range(1,7):
		var e:=InputEventScreenDrag.new(); e.index=71; e.position=p-Vector2(0,i*28)
		e.relative=Vector2(0,-28); send(e); await frames(2)
	await touch(p-Vector2(0,168),false); await frames(12)
func effective(c: Control)->Rect2:
	var r:=c.get_global_rect(); var a=c.get_parent()
	while a!=null:
		if a is Control and a.clip_contents: r=r.intersection(a.get_global_rect())
		a=a.get_parent()
	return r.intersection(Rect2(Vector2.ZERO,board.size))
func control(id: String):
	for c in board.character_menu.find_children("*","Button",true,false):
		if str(c.get_meta("menu_id",""))==id:return c
	return null
func first_equipment():
	for c in board.character_menu.find_children("*","Button",true,false):
		if str(c.get_meta("menu_id","")).begins_with("equipment:"):return c
	return null
func inventory()->Dictionary:
	var buttons: Array=[]
	for c in board.character_menu.find_children("*","Button",true,false):
		buttons.append({"id":c.get_meta("menu_id",""),"text":c.text,"rect":str(c.get_global_rect()),"effective":str(effective(c))})
	return {"panel":str(board.character_menu.get_global_rect()),"scroll":str(board.character_menu.scroll.get_global_rect()) if is_instance_valid(board.character_menu.scroll) else "no opening scroll","content_min":str(board.character_menu.content.get_combined_minimum_size()),"scroll_offset":board.character_menu.scroll.scroll_vertical if is_instance_valid(board.character_menu.scroll) else 0,"buttons":buttons}
func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	for dims in [Vector2i(390,844),Vector2i(720,480),Vector2i(840,720)]:
		root.size=dims
		board=load("res://scenes/main.tscn").instantiate(); root.add_child(board); await frames(16)
		board.state.start_run("warrior","expedition",630063,"encounter","energy",true)
		board.state.enemies.clear(); board.state.carried_xp=147
		board.visual=board._presentation_snapshot(); board._layout(); await frames()
		var record: Dictionary={"client_model":str(dims),"root_transform":str(root.get_final_transform()),"logical_board":str(board.size),"emulate_mouse":Input.emulate_mouse_from_touch,"touchscreen_available":DisplayServer.is_touchscreen_available(),"tick_before":board.state._simulation_tick_index}
		await tap(board.sheet_button_rect.get_center())
		record["touch_hud_open"]=board.character_sheet_open
		if not board.character_sheet_open:
			await click(board.sheet_button_rect.get_center())
		record["initial"]=inventory()
		await tap(control("category:equipment").get_global_rect().get_center())
		record["equipment_list"]=inventory()
		var trace: Array=[]
		for c in board.character_menu.find_children("*","Control",true,false):
			c.gui_input.connect(func(e):
				if e is InputEventScreenTouch or e is InputEventScreenDrag: trace.append({"class":c.get_class(),"id":c.get_meta("menu_id",""),"event":e.get_class()}))
		var first=first_equipment()
		await tap(first.get_global_rect().get_center())
		record["touch_equipment_detail"]=board.sheet_detail.duplicate(true)
		if not board.sheet_detail.is_empty():
			var back=control("character:back")
			await tap(back.get_global_rect().get_center())
		record["tap_trace"]=trace.duplicate(true); trace.clear()
		for c in board.character_menu.find_children("*","Control",true,false):
			c.gui_input.connect(func(e):
				if e is InputEventScreenTouch or e is InputEventScreenDrag: trace.append({"class":c.get_class(),"id":c.get_meta("menu_id",""),"event":e.get_class()}))
		var start: Vector2=board.character_menu.scroll.get_global_rect().get_center()
		record["offset_before_swipe"]=board.character_menu.scroll.scroll_vertical
		await swipe(start)
		record["offset_after_swipe"]=board.character_menu.scroll.scroll_vertical
		record["detail_after_swipe"]=board.sheet_detail.duplicate(true)
		record["native_touch_trace"]=trace.duplicate(true)
		for c in board.character_menu.find_children("*","Label",true,false):
			if c.text=="EQUIPMENT":
				await swipe(c.get_global_rect().get_center()); break
		record["offset_after_label_swipe"]=board.character_menu.scroll.scroll_vertical
		record["tick_after"]=board.state._simulation_tick_index
		records.append(record)
		board.queue_free(); await frames()
	var f=FileAccess.open("user://character-mobile-access.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(records,"\t")); f.close()
	print("CHARACTER MOBILE ACCESS RECORDS ",records.size()," OUTPUT ",ProjectSettings.globalize_path("user://character-mobile-access.json"))
	quit()
