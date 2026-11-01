extends SceneTree
# Real project root and routed ScreenTouch/Drag. Explicit synthetic progression and geometry models.
const State=preload("res://scripts/core/run_state.gd")
var board
var checks:=0
var failures:Array=[]
var records:Array=[]
func _init(): call_deferred("run")
func frames(n:int=10):
	for i in n: await process_frame
func check(ok:bool, why:String):
	checks+=1
	if not ok: failures.append(why); printerr("FAILED: ",why)
func send(e:InputEvent): Input.parse_input_event(e.xformed_by(root.get_final_transform()))
func contact(p:Vector2,down:bool,index:int=71):
	var e:=InputEventScreenTouch.new(); e.position=p;e.pressed=down;e.index=index;send(e);await frames(2)
func tap_point(p:Vector2):
	await contact(p,true);await contact(p,false);await frames()
func button(id:String):
	for c in board.character_menu.find_children("*","Button",true,false):
		if str(c.get_meta("menu_id",""))==id:return c
	return null
func effective(c:Control)->Rect2:
	var r:=c.get_global_rect();var a=c.get_parent()
	while a!=null:
		if a is Control and a.clip_contents:r=r.intersection(a.get_global_rect())
		a=a.get_parent()
	return r.intersection(board._display_safe_layout_rect())
func swipe(p:Vector2,delta:Vector2=Vector2(0,-180)):
	await contact(p,true)
	for i in range(1,7):
		var e:=InputEventScreenDrag.new(); e.index=71;e.position=p+delta*i/6.0;e.relative=delta/6.0;send(e);await frames(2)
	await contact(p+delta,false);await frames()
func reachable(id:String)->bool:
	for i in 35:
		var c=button(id)
		if c==null:check(false,"missing control "+id);return false
		if effective(c).size.distance_to(c.size)<1:return true
		if not is_instance_valid(board.character_menu.scroll):break
		var r:Rect2=board.character_menu.scroll.get_global_rect()
		var down:bool=c.get_global_rect().get_center().y<r.get_center().y
		await swipe(r.get_center(),Vector2(0,140 if down else -140)*board.character_menu.u)
	check(false,"touch reach "+id);return false
func tap(id:String):
	if await reachable(id):await tap_point(button(id).get_global_rect().get_center())
func text()->String:
	var result:PackedStringArray=[]
	for c in board.character_menu.find_children("*","Control",true,false):
		if c is Label or c is BaseButton:result.append(c.text)
	return "\n".join(result)
func fixture(loadout:String="warrior",mode:String="expedition",xp:int=147,rules:String="energy",dims:Vector2i=Vector2i(390,844),density:float=1.0,inset:bool=false):
	root.size=dims
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	board=load("res://scenes/main.tscn").instantiate();root.add_child(board);await frames(16)
	board.state.start_run(loadout,mode,630063,"encounter",rules,mode!="expedition")
	board.state.enemies.clear();board.state.carried_xp=xp;board.state.secured_xp=100
	if mode=="campaign_lab":board.state.player_pos=board.state.waystones[0].pos
	board.character_menu.density_model=density
	if inset:board.layout_safe_area_override=Rect2(board.size*0.025,board.size*0.95)
	board.visual=board._presentation_snapshot();board._layout();await frames()
	await tap_point(board.sheet_button_rect.get_center());await frames(18)
	check(board.character_sheet_open and board.character_menu.visible,"touch HUD entry "+loadout+str(dims))
func finish():board.queue_free();await frames()
func audit(label:String):
	var m=board.character_menu
	var row={"case":label,"root":str(root.size),"transform":str(root.get_final_transform()),"logical_board":str(board.size),"unit":m.u,"safe":str(board._display_safe_layout_rect()),"panel":str(m.get_global_rect()),"minimum":str(m.shell.get_combined_minimum_size()),"variant":m.variant,"buttons":[],"tick":board.state._simulation_tick_index}
	check(m.get_meta("layout_supported",false),"measured fit "+label)
	check(not is_instance_valid(m.scroll),"opening has no scroll owner "+label)
	check(board._display_safe_layout_rect().encloses(m.get_global_rect()),"panel inside safe rect "+label)
	for c in m.find_children("*","Control",true,false):
		if not c.is_visible_in_tree():continue
		if c is Label or c is Button:
			check(c.get_theme_font_size("font_size")>=17*m.u-1,"body font preserved "+label)
			var padding:=Vector2.ZERO
			if c is Button:padding=c.get_theme_stylebox("normal").get_minimum_size()
			var paragraph:=TextParagraph.new()
			paragraph.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
			paragraph.width=maxf(1,c.size.x-padding.x)
			paragraph.add_string(c.text,c.get_theme_font("font"),c.get_theme_font_size("font_size"))
			check(paragraph.get_size().y+padding.y<=c.size.y+1,"shaped wrapped glyph height "+label+" "+str(c.get_meta("menu_id",c.text)))
			check(effective(c).size.distance_to(c.size)<1,"full visible wrapped control "+label+" "+str(c.get_meta("menu_id",c.text)))
		if c is Button:
			check(c.size.y>=48*m.u-1 and c.size.x>=48*m.u-1,"minimum hit area "+label+str(c.get_meta("menu_id","")))
			row.buttons.append({"id":c.get_meta("menu_id",""),"text":c.text,"rect":str(c.get_global_rect()),"effective":str(effective(c)),"min":str(c.get_combined_minimum_size())})
	check(text().contains("Spendable") and text().contains("Cost"),"XP visible "+label)
	check(button("category:tracks")!=null or button("track:"+str(board.state.character_track_order()[0]))!=null,"upgrade route visible "+label)
	records.append(row)
func categories():
	var tick:int=board.state._simulation_tick_index
	for category in ["equipment","attributes","combat","belt"]:
		for i in 4:
			if button("category:"+category)!=null:break
			await tap("category:next")
		await tap("category:"+category)
		check(board.sheet_detail.get("kind")==category+"_list","category route "+category)
		var data:Dictionary=board.state.character_sheet_data()
		if category=="equipment":
			for slot in data.equipment:
				await tap("equipment:"+str(slot));check(text().contains(str(data.equipment[slot])),"equipment name parity "+str(slot));await tap("character:back")
		elif category=="attributes":
			for key in data.attributes:check(text().contains(str(key).capitalize()+" · "+str(data.attributes[key])),"attribute parity "+str(key))
		elif category=="combat":check(text().contains("Defense ·") and text().contains("ART ·"),"combat detail retained")
		else:
			check(button("belt:2")!=null,"all utility slots retained")
			check(button("belt:0").disabled==not str(data.level_up_context).is_empty(),"repack restriction visible")
		await tap("character:back")
		check(board.sheet_detail.is_empty(),"category Back returns overview")
	check(board.state._simulation_tick_index==tick,"inspection spends no simulation time")
func overview():
	while not board.sheet_detail.is_empty():await tap("character:back")
func track(id:String):
	await overview()
	if button("track:"+id)==null:await tap("category:tracks")
	await tap("track:"+id)
func progression(state)->Dictionary:
	return {"xp":state.carried_xp,"secured":state.secured_xp,"count":state.upgrade_count,"ranks":state.track_ranks.duplicate(true),"choices":state.track_choices.duplicate(true),"upgrades":state.upgrades.duplicate(true),"attrs":state.player_attributes.duplicate(true),"hp":state.player_max_hp,"energy":state.player_max_energy,"art":state.player_equipped_weapon_art,"arts":state.player_weapon_art_library.duplicate(),"spells":state.player_spells.duplicate()}
func purchase(loadout:String,mode:String,rules:String):
	await fixture(loadout,mode,147,rules,Vector2i(720,480))
	var id:String=board.state.available_level_up_options()[0]
	await track(id);await tap("upgrade:"+id)
	var before:=progression(board.state)
	var value:Dictionary=board.sheet_detail.duplicate(true)
	var choice:=id
	if value.kind=="track_choice":
		check(button("character:confirm").disabled,"branch initially disabled "+loadout)
		choice=id+"|"+str(value.options[-1].id)
		await tap("choice:"+str(value.options[-1].id))
	check(progression(board.state)==before,"choice costs nothing "+loadout)
	check(text().contains("REMAINING "+str(int(board.state.character_sheet_data().level_up_xp)-int(value.cost))+" XP"),"truthful projected carried remainder")
	check(effective(button("character:confirm")).size.distance_to(button("character:confirm").size)<1,"fixed Spend clears clipping")
	await tap("character:cancel")
	check(board.sheet_detail.get("kind")=="track" and board.sheet_detail.get("track_id")==id and progression(board.state)==before,"cancel exact track and no debit")
	await tap("upgrade:"+id)
	if value.kind=="track_choice":await tap("choice:"+str(value.options[-1].id))
	board.state.save_run("user://mobile-reference.save")
	var reference=State.new(false);check(reference.load_run("user://mobile-reference.save") and reference.choose_upgrade(choice),"original consumer reference")
	# Resize/fold during Spend: the old contact cannot activate the rebuilt control.
	var p:Vector2=button("character:confirm").get_global_rect().get_center()
	await contact(p,true);root.size=Vector2i(390,844);await frames(18)
	await contact(button("character:confirm").get_global_rect().get_center(),false);await frames()
	check(progression(board.state)==before,"fold press canceled "+loadout+mode+rules)
	# A second contact invalidates both transaction taps regardless of release order.
	p=button("character:confirm").get_global_rect().get_center()
	await contact(p,true);await contact(p,true,72);await contact(p,false,72);await contact(p,false);await frames()
	check(progression(board.state)==before,"multi-contact cannot Spend")
	# Drag starting at Spend must never spend even when release lands inside it.
	await swipe(p,Vector2(0,-20)*board.character_menu.u)
	check(progression(board.state)==before,"Spend drag cannot purchase")
	await tap("character:confirm")
	var after:=progression(board.state)
	check(after==progression(reference),"routed purchase exactly matches owner "+loadout+mode+rules)
	check(board.sheet_detail.get("kind")=="track" and board.sheet_detail.get("track_id")==id,"purchase returns to exact track")
	var release:=InputEventScreenTouch.new();release.index=71;release.position=p;release.pressed=false;send(release);await frames()
	check(progression(board.state)==after,"duplicate release no second purchase")
	var loaded=State.new(false);check(loaded.load_run() and progression(loaded)==after,"critical autosave reload parity "+loadout+mode+rules)
	check(board.state._simulation_tick_index==0,"purchase and navigation frozen")
	await tap("stage:"+id+":0")
	check(board.sheet_detail.get("kind")=="stage" and text().contains("COMPLETED"),"completed stage inspectable")
	for option in value.get("options",[]):check(text().contains(str(option.label)) and text().contains(str(option.description)),"retained branch history text")
	records.append({"purchase":loadout+mode+rules,"choice":choice,"before":before,"after":after})
	await finish()
func adopted(discipline:String):
	await fixture()
	board.state.expedition.biome=1;board.state.expedition.completed=[0];board.state.expedition.departed=[0];board.state.expedition.writ=true
	board.state._install_layout(board.state.ExpeditionGeneratorScript.generate(board.state.run_seed,1));board.state.enemies.clear()
	board.state.player_pos=Vector2(board.state.expedition_markers.merchant)
	check(board.state.ExpeditionEconomyScript.adopt(board.state,discipline),"legal adopted fixture")
	board.state.upgrade_count=7;await frames(18)
	await overview();await audit("adopted "+discipline)
	check(board.state.character_level()==8 and board.state.available_level_up_options().has("adopted"),"next-level nine eligibility "+discipline)
	await track("adopted")
	check(text().contains(discipline.capitalize()) and text().contains(discipline.capitalize()+" III") and not text().contains("Discipline not yet found"),"adopted empty catalog actual name and next stage")
	var before:=progression(board.state)
	await tap("upgrade:adopted");await tap("character:confirm")
	check(board.state.track_total("adopted")==3 and board.state.upgrade_count==8 and board.state.carried_xp==int(before.xp)-34,"adopted mastery exact once "+discipline)
	var saved=State.new(false);check(saved.load_run() and saved.track_total("adopted")==3,"adopted mastery saved")
	await finish()
func swipes_and_return():
	await fixture("warrior","expedition",0,"energy",Vector2i(720,480))
	await tap("category:equipment")
	var m=board.character_menu
	var first=button("equipment:"+str(board.state.equipment_slots.keys()[0]))
	await swipe(first.get_global_rect().get_center(),Vector2(0,-100)*m.u)
	check(m.scroll.scroll_vertical>0 and board.sheet_detail.kind=="equipment_list","button-start swipe moves without tap")
	var saved:int=m.scroll.scroll_vertical
	await tap("equipment:"+str(board.state.equipment_slots.keys()[-1]));await tap("character:back")
	check(m.scroll.scroll_vertical>=saved,"return restores equipment scroll")
	# Scroll to start using gestures, then begin over the heading label.
	for i in 5:await swipe(m.scroll.get_global_rect().get_center(),Vector2(0,130)*m.u)
	var label=m.content.get_child(0)
	await swipe(label.get_global_rect().get_center(),Vector2(0,-100)*m.u)
	check(m.scroll.scroll_vertical>0 and board.sheet_detail.kind=="equipment_list","label-start swipe moves without activation")
	var before:int=m.scroll.scroll_vertical
	var blank:Vector2=m.scroll.get_global_rect().position+Vector2(m.scroll.size.x-24*m.u,m.scroll.size.y*0.8)
	await swipe(blank,Vector2(0,-70)*m.u)
	check(m.scroll.scroll_vertical>before,"blank-space swipe moves")
	await tap("equipment:"+str(board.state.equipment_slots.keys()[-1]));await tap("character:back")
	var offset:int=m.scroll.scroll_vertical
	root.size=Vector2i(390,844);await frames(18);root.size=Vector2i(720,480);await frames(18)
	check(m.scroll.scroll_vertical==offset,"detail scroll retained across resize roundtrip")
	await overview();await tap("category:belt")
	board.state.consumable_slots.assign([{"id":"trail_ration","count":1},{"id":"firebomb","count":2},{}]);await frames(18)
	var slots:Array=board.state.consumable_slots.duplicate(true)
	await tap("belt:0");check(board.sheet_repack_slot==0,"touch first belt selected")
	await tap("belt:0");check(board.sheet_repack_slot==-1,"touch same belt deselects")
	await tap("belt:0");await tap("belt:1")
	for i in 150:
		if not board.streaming_action and board.state.is_player_ready():break
		await frames(2)
	check(not board.character_sheet_open and board.state.consumable_slots==[slots[1],slots[0],slots[2]],"touch paid repack exactly one swap closes")
	check(board.state._simulation_tick_index>0 and not board.controller.sheet_return_pause and not board.inspection_return,"paid repack consumes return contexts")
	var tick:int=board.state._simulation_tick_index;await frames(20);check(board.state._simulation_tick_index==tick,"repack ends frozen")
	await finish()
func cancellation():
	await fixture()
	await tap("category:equipment")
	var id:String="equipment:"+str(board.state.equipment_slots.keys()[0])
	var p:Vector2=button(id).get_global_rect().get_center()
	await contact(p,true);board._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);await frames();await contact(p,false);await frames()
	check(board.sheet_detail.kind=="equipment_list","focus loss cancels captured tap")
	# A data rebuild while held requires a fresh contact.
	await contact(p,true);board.state.carried_xp+=1;await frames(18);await contact(p,false);await frames()
	check(board.sheet_detail.kind=="equipment_list","data rebuild cancels captured tap")
	await tap(id);check(board.sheet_detail.kind=="equipment","fresh tap after cancellation")
	await contact(button("character:back").get_global_rect().get_center(),true)
	# Back through keyboard while touch remains held; the old release cannot close the next context.
	var e:=InputEventKey.new();e.keycode=KEY_ESCAPE;e.pressed=true;send(e);e=InputEventKey.new();e.keycode=KEY_ESCAPE;e.pressed=false;send(e);await frames(18)
	await contact(p,false);await frames()
	check(board.sheet_detail.kind=="equipment_list" and board.state._simulation_tick_index==0,"old contact across Back cannot act or leak")
	await finish()
func joy_axis(axis:int,value:float):
	var e:=InputEventJoypadMotion.new();e.axis=axis;e.axis_value=value;e.device=0;Input.parse_input_event(e);await frames()
func mixed_input():
	await fixture("warrior","expedition",0,"energy",Vector2i(720,480))
	await joy_axis(JOY_AXIS_TRIGGER_RIGHT,1.0);await joy_axis(JOY_AXIS_LEFT_X,1.0)
	await tap("category:equipment")
	var m=board.character_menu
	await swipe(m.scroll.get_global_rect().get_center(),Vector2(0,-100)*m.u)
	var offset:int=m.scroll.scroll_vertical;await frames(25)
	check(offset>0 and m.scroll.scroll_vertical==offset and root.gui_get_focus_owner()==null,"touch swipe stable while controller held")
	await tap("character:back");await tap("character:back");await frames(20)
	check(not board.character_sheet_open and board.state._simulation_tick_index==0,"touch close with held controller frozen")
	await joy_axis(JOY_AXIS_LEFT_X,0.9);await frames(20)
	check(board.state._simulation_tick_index==0,"held stick jitter cannot resume gameplay")
	await joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.0);await joy_axis(JOY_AXIS_LEFT_X,0.0);await frames(20)
	await joy_axis(JOY_AXIS_TRIGGER_RIGHT,1.0);await joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.0);await frames(35)
	check(board.state._simulation_tick_index>0,"fresh controller repress after actual neutral works")
	await finish()
func variants():
	for loadout in ["warrior","rogue_acrobat","rogue_sharpshooter","mage_elementalist"]:
		await fixture(loadout)
		# Progressed ranks and all authored future/completed stage text remain inspectable.
		board.state.upgrade_count=8
		for id in board.state.character_track_order():
			if id!="adopted":board.state.track_ranks[id]=1
		await frames(18);await audit("progressed "+loadout)
		var data:Dictionary=board.state.character_sheet_data()
		for value in data.tracks:
			await track(str(value.id))
			check(text().contains(str(value.description)),"full track description "+str(value.id))
			for i in value.stages.size():
				var stage:Dictionary=value.stages[i]
				if stage.get("current",false) and Array(data.level_up_options).has(value.id):continue
				await tap("stage:"+str(value.id)+":"+str(i))
				check(text().contains(str(stage.label)) and text().contains(str(stage.description)),"authored stage text "+str(stage.id))
				await tap("character:back")
		await finish()
	await fixture("warrior","campaign_lab")
	board.state.secured_xp=0;await frames(18);await audit("insufficient secured, carried147")
	check(text().contains("Insufficient XP") and text().contains("Spendable secured XP · 0") and text().contains("Carried XP · 147"),"separate accounts and insufficient reason")
	board.state.secured_xp=100;board.state.player_pos+=Vector2(2000,2000);await frames(18)
	check(text().contains("Reach a Waystone"),"closed location reason")
	await finish()
	await fixture()
	for id in board.state.character_track_order():
		var stages:Array=board.state.CombatCatalogScript.character_track(str(id)).get("stages",[])
		board.state.track_ranks[id]=stages.size()
	await frames(18);await audit("no eligible next stage")
	check(text().contains("No eligible next stage"),"no valid stage truthful")
	board.state.trial_complete=true;await frames(18);check(text().contains("Run complete"),"closed run reason")
	await finish()
	await fixture()
	board.state.player_action={"kind":"attack","remaining":1.0,"duration":1.0};await frames(18)
	check(text().contains("Not ready") and board.state.level_up_context().is_empty(),"not-ready reason")
	await finish()
	await fixture("warrior","expedition",0)
	board.state.player_weapon_frame="twin_knives";board.state.player_weapon_art_library.assign(["prototype_sweeping_cut","sword_thrust"]);board.state.player_equipped_weapon_art="prototype_sweeping_cut";await frames(18)
	await tap("category:combat")
	check(text().contains("SIX ALTERNATING CUTS") and button("art:prototype_sweeping_cut").disabled and button("art:sword_thrust").disabled,"legacy frame and two prohibited art swaps")
	await finish()
func output():
	var f=FileAccess.open("user://character-mobile-results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"));f.close()
	print("CHARACTER MOBILE ",checks," checks ",failures.size()," failures ",OS.get_user_data_dir());quit(0 if failures.is_empty() else 1)
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	var args:=OS.get_cmdline_user_args()
	if args.has("--focused"):
		await adopted("trapper");await adopted("sapper");await swipes_and_return();await cancellation();await mixed_input();await variants();await mixed_input();output();return
	for loadout in ["warrior","rogue_acrobat","rogue_sharpshooter","mage_elementalist"]:
		for dims in [Vector2i(390,844),Vector2i(720,480),Vector2i(840,720)]:
			for xp in [0,147]:
				print("COLD ",loadout," ",dims," ",xp)
				await fixture(loadout,"expedition",xp,"energy",dims);await audit(loadout+str(dims)+" xp"+str(xp));await categories();await finish()
		for mode in ["campaign_lab","combat_survey","expedition"]:
			for rules in ["energy","recovery"]:await purchase(loadout,mode,rules)
	for model in [[780,1688,2.0],[1170,2532,3.0],[1440,960,2.0],[2520,2160,3.0],[390,600,1.0]]:
		await fixture("mage_elementalist","campaign_lab",147,"recovery",Vector2i(model[0],model[1]),model[2]);await audit("density model "+str(model));await categories();await finish()
	await fixture("rogue_sharpshooter","campaign_lab",147,"energy",Vector2i(390,844),1,true);await audit("safe-area inset model");await categories();await finish()
	await adopted("trapper");await adopted("sapper")
	await variants()
	await swipes_and_return();await cancellation();await mixed_input()
	output()
