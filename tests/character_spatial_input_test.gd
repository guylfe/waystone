extends "res://tests/character_mobile_test.gd"
# Engineer regression using the designer's exact root/XP/directional expectations.
# All focus movement is routed key/pad input; no focus-index, grab or scroll writes.
var directions:Array=[]
func focused()->String:
	var c=root.gui_get_focus_owner()
	return str(c.get_meta("menu_id","")) if c!=null else ""
func move(code:int,keyboard:bool=false):
	for down in [true,false]:
		var e:InputEvent
		if keyboard:
			e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
		else:
			e=InputEventJoypadButton.new();e.device=0;e.button_index=code;e.pressed=down
		send(e);await frames(2)
	await frames(6)
func seek(id:String)->bool:
	# Native Tab visits enabled commands without activating them. It establishes
	# each test start through real input independently of the directional algorithm.
	for i in board.controller.menu_entries(board).size()+2:
		if focused()==id:return true
		await move(KEY_TAB,true)
	check(false,"routed reachability "+id);return false
func expect_move(from:String,code:int,to:String,label:String,keyboard:bool=false):
	if not await seek(from):return
	var before:Rect2=root.gui_get_focus_owner().get_global_rect()
	await move(code,keyboard)
	var c=root.gui_get_focus_owner()
	directions.append({"case":label,"from":from,"expected":to,"actual":focused(),"keyboard":keyboard,"root":str(root.size),"transform":str(root.get_final_transform()),"before_rect":str(before),"after_rect":str(c.get_global_rect()) if c!=null else "none"})
	check(focused()==to,label+" "+from+" -> "+focused()+" expected "+to)
	check(c!=null and effective(c).size.distance_to(c.size)<1,"visible focus "+label)
func reach_all(label:String):
	var ids:Array=[]
	for entry in board.controller.menu_entries(board):ids.append(board.controller.Navigation.id(entry))
	# From the header use only D-pad: sweep each row horizontally, then Down.
	# The Tab fixture above never serves as proof of directional reach/scrolling.
	await seek("character:back")
	var visited:Array=[]
	for row in 20:
		for i in 8:
			var before:=focused();await move(JOY_BUTTON_DPAD_LEFT)
			if before==focused():break
		for i in 8:
			var c=root.gui_get_focus_owner()
			if not visited.has(focused()):visited.append(focused())
			check(c!=null and effective(c).size.distance_to(c.size)<1,"D-pad focus visible "+label+focused())
			var before:=focused();await move(JOY_BUTTON_DPAD_RIGHT)
			if before==focused():break
		for i in 8:
			var before:=focused();await move(JOY_BUTTON_DPAD_LEFT)
			if before==focused():break
		var before:=focused();await move(JOY_BUTTON_DPAD_DOWN)
		if before==focused():break
	for id in ids:check(visited.has(id),"D-pad reaches every enabled command "+label+id)
	check(board.state._simulation_tick_index==0,"navigation stays frozen "+label)
	records.append({"reachability":label,"enabled":ids,"visited":visited,"variant":board.character_menu.variant})
func wide(xp:int):
	await fixture("warrior","expedition",xp,"energy",Vector2i(840,720))
	await audit("designer boundary XP"+str(xp))
	await expect_move("track:swordsmanship",JOY_BUTTON_DPAD_DOWN,"track:steadfast","designer track Down XP"+str(xp))
	await expect_move("track:steadfast",JOY_BUTTON_DPAD_UP,"track:swordsmanship","reverse track Up")
	for keyboard in [false,true]:
		await expect_move("category:equipment",KEY_DOWN if keyboard else JOY_BUTTON_DPAD_DOWN,"category:combat","designer category Down",keyboard)
		await expect_move("category:combat",KEY_UP if keyboard else JOY_BUTTON_DPAD_UP,"category:equipment","reverse category Up",keyboard)
	await expect_move("category:equipment",JOY_BUTTON_DPAD_RIGHT,"category:attributes","category Right")
	await expect_move("category:attributes",JOY_BUTTON_DPAD_LEFT,"category:equipment","category Left")
	await expect_move("category:attributes",JOY_BUTTON_DPAD_DOWN,"category:belt","right category column")
	await expect_move("category:equipment",JOY_BUTTON_DPAD_LEFT,"category:equipment","left clamp")
	await expect_move("category:belt",JOY_BUTTON_DPAD_DOWN,"category:belt","bottom clamp")
	await expect_move("character:back",JOY_BUTTON_DPAD_UP,"character:back","header clamp")
	if xp>0:
		await expect_move("track:swordsmanship",JOY_BUTTON_DPAD_RIGHT,"upgrade:swordsmanship","designer adjacent Upgrade")
		await expect_move("upgrade:swordsmanship",JOY_BUTTON_DPAD_LEFT,"track:swordsmanship","Upgrade reverse")
		await expect_move("upgrade:swordsmanship",JOY_BUTTON_DPAD_DOWN,"upgrade:steadfast","Upgrade vertical lane")
		# Disabled control is an explicit isolated eligibility/UI fixture.
		button("upgrade:steadfast").disabled=true
		await expect_move("upgrade:swordsmanship",JOY_BUTTON_DPAD_DOWN,"track:steadfast","missing enabled Upgrade falls to same track")
		button("upgrade:steadfast").disabled=false
	await reach_all("wide XP"+str(xp))
	# Transition between independently authored track/category grids must be vertical.
	var order:Array=board.state.character_track_order()
	var last_left:String=str(order[(order.size()-1)/2*2])
	await expect_move("track:"+last_left,JOY_BUTTON_DPAD_DOWN,"category:equipment","track grid to category grid")
	await finish()
func compact(dims:Vector2i):
	await fixture("warrior","expedition",147,"energy",dims)
	await audit("compact "+str(dims));await reach_all(str(dims))
	if button("category:tracks")!=null:
		await seek("category:tracks");await move(JOY_BUTTON_A)
		check(board.sheet_detail.get("kind")=="tracks","routed compact tracks activation")
		await expect_move("track:swordsmanship",JOY_BUTTON_DPAD_DOWN,"track:evasion","single-column track rows")
		await expect_move("track:evasion",JOY_BUTTON_DPAD_UP,"track:swordsmanship","single-column reverse")
		await reach_all("compact detail")
		await move(JOY_BUTTON_B);await frames(18)
		check(board.sheet_detail.is_empty() and focused()=="category:tracks","semantic Back restores invoker")
	if board.character_menu.variant==2:
		await seek("category:next");await move(JOY_BUTTON_A);await frames(18)
		check(board.character_menu.page==1,"routed page advance")
		await reach_all("second page")
		await seek("category:previous");await move(JOY_BUTTON_A);await frames(18)
		check(board.character_menu.page==0,"routed previous page")
	await finish()
func run():
	await wide(0);await wide(147)
	await compact(Vector2i(390,844));await compact(Vector2i(720,480));await compact(Vector2i(280,480))
	var f=FileAccess.open("user://character-spatial-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"directions":directions,"records":records,"method":"normal root, unchanged geometry, routed synthetic key/pad; labelled XP/disabled fixtures"},"\t"));f.close()
	print("CHARACTER SPATIAL ",checks," checks / ",directions.size()," directions / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
