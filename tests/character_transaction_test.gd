extends SceneTree
# Synthetic progression fixtures. These are routed transactions, not earned play.
const State = preload("res://scripts/core/run_state.gd")
var board
var view: SubViewport
var checks := 0
var failures: Array = []
var records: Array = []

func _init(): call_deferred("run")
func check(ok: bool, why: String):
	checks += 1
	if not ok: failures.append(why); printerr("FAILED: ", why)
func frames(count: int = 4):
	for i in count: await process_frame
func joy(code: int, down: bool):
	var event := InputEventJoypadButton.new()
	event.button_index=code; event.pressed=down; event.device=0
	view.push_input(event,true)
func tap(code: int):
	joy(code,true); await frames(2); joy(code,false); await frames()
func key(code: int):
	for down in [true,false]:
		var event := InputEventKey.new(); event.keycode=code; event.pressed=down
		view.push_input(event,true); await frames(2)
	await frames()
func id() -> String:
	var focused=view.gui_get_focus_owner()
	return str(focused.get_meta("menu_id","")) if focused!=null else ""
func seek(target: String, by_label: bool = false) -> bool:
	for i in range(80):
		var focused=view.gui_get_focus_owner()
		if (focused is BaseButton and focused.text.begins_with(target)) if by_label else id()==target: return true
		var entries: Array=board.controller.menu_entries(board)
		if by_label and not entries.is_empty() and str(entries[board.controller.focus_index].get("label","")).begins_with(target): return true
		var destination: Control
		for entry in board.controller.menu_entries(board):
			var control=entry.get("control")
			if control is BaseButton and ((control.text.begins_with(target)) if by_label else str(control.get_meta("menu_id",""))==target):
				destination=control; break
		if destination!=null and focused is Control:
			var delta: Vector2=destination.get_global_rect().get_center()-focused.get_global_rect().get_center()
			await tap(JOY_BUTTON_DPAD_DOWN if delta.y>1 else JOY_BUTTON_DPAD_UP if delta.y < -1 else JOY_BUTTON_DPAD_RIGHT if delta.x>0 else JOY_BUTTON_DPAD_LEFT)
		else: await tap(JOY_BUTTON_DPAD_DOWN)
	check(false,"sequential controller reach: "+target+" from "+id()+" context "+board.controller.context_id(board)+" paused "+str(board.controller.paused)+" overlay "+str(board.survey_overlay.visible))
	return false
func activate(target: String):
	if await seek(target): await tap(JOY_BUTTON_A)
func progression(state) -> Dictionary:
	return {"xp":state.carried_xp,"secured":state.secured_xp,"count":state.upgrade_count,"ranks":state.track_ranks.duplicate(true),"upgrade_ranks":state.upgrade_ranks.duplicate(true),"choices":state.track_choices.duplicate(true),"upgrades":state.upgrades.duplicate(true),"attributes":state.player_attributes.duplicate(true),"max_hp":state.player_max_hp,"max_energy":state.player_max_energy,"art":state.player_equipped_weapon_art,"arts":state.player_weapon_art_library.duplicate(),"spells":state.player_spells.duplicate()}
func fixture(mode: String, xp: int, experimental: bool = false):
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	view=SubViewport.new(); view.size=Vector2i(1280,800); root.add_child(view)
	board=load("res://scenes/main.tscn").instantiate(); view.add_child(board)
	await frames()
	# Labelled isolated state setup only; purchases below use native routed controls.
	var options: Dictionary={"version":1,"behavior":"C","scenario":"F2","arrival":"full","scouting":false} if experimental else {}
	board.state.start_run("warrior",mode,630063,"encounter","energy",true,options)
	if not experimental: board.state.enemies.clear(); board.state.walls.clear()
	board.state.carried_xp=xp; board.state.secured_xp=xp
	if mode=="campaign_lab": board.state.player_pos=board.state.waystones[0].pos
	board.visual=board._presentation_snapshot(); board._layout()
	await frames(8)
	check(board.state.level_up_context()==({"campaign_lab":"waystone","combat_survey":"survey"}.get(mode,mode)) if xp>=6 else board.state.level_up_context()=="","fixture context "+mode+" XP "+str(xp))
	await tap(JOY_BUTTON_START)
	if await seek("Character" if experimental else "Character & upgrades",true): await tap(JOY_BUTTON_A)
	check(board.character_sheet_open and board.character_menu.visible,"native Character entered from pause "+mode)
func finish():
	view.queue_free(); await frames()
func branch(mode: String, track: String, option: String):
	await fixture(mode,6)
	var state=board.state
	var before=progression(state)
	var stage: Dictionary=state.next_track_stage(track)
	var encoded=track+"|"+option
	state.save_run("user://branch-reference.save")
	var reference=State.new(false)
	check(reference.load_run("user://branch-reference.save") and reference.choose_upgrade(encoded),"legal original consumer reference "+mode+" "+encoded)
	await activate("stage:"+track+":0")
	check(board.sheet_detail.get("kind")=="track_choice","branch confirmation opened "+encoded)
	var confirm: Button
	for entry in board.controller.menu_entries(board):
		var control=entry.get("control")
		if control is Button and str(control.get_meta("menu_id",""))=="character:confirm": confirm=control
	# Disabled buttons are excluded from menu_entries; inspect the native tree too.
	for control in board.character_menu.find_children("*","Button",true,false):
		if str(control.get_meta("menu_id",""))=="character:confirm": confirm=control
	check(confirm!=null and confirm.disabled,"branch purchase disabled until a choice")
	await activate("choice:"+option)
	var selected=str(board.sheet_detail.get("selected",""))
	check(progression(state)==before,"selection alone has no progression mutation "+encoded)
	# Cancel via routed B and verify both memory and persisted progression.
	await tap(JOY_BUTTON_B)
	check(board.sheet_detail.is_empty() and board.character_sheet_open,"cancel returns to summary")
	check(progression(state)==before,"cancel has no mutation "+encoded)
	state.save_run()
	var cancelled=State.new(false)
	check(cancelled.load_run() and progression(cancelled)==before,"cancel persistence "+encoded)
	await activate("stage:"+track+":0"); await activate("choice:"+option)
	await activate("character:confirm")
	var after=progression(state)
	check(after==progression(reference),"native purchase matches all original progression effects "+mode+" "+encoded)
	check(state.carried_xp==0,"exact XP debit "+mode+" "+encoded)
	check(state.secured_xp==(0 if mode=="campaign_lab" else 6),"correct XP account "+mode+" "+encoded)
	check(state.upgrade_count==int(before.count)+1 and state.track_total(track)==1,"exactly one rank/count "+encoded)
	check(state.track_choices.get(stage.id)==option,"chosen branch stored under stage "+encoded)
	check(state.upgrades.size()==Array(before.upgrades).size()+1,"one upgrade history entry "+encoded)
	check(board.sheet_detail.is_empty() and board.character_sheet_open,"successful purchase returns to summary "+encoded)
	var loaded=State.new(false)
	check(loaded.load_run() and progression(loaded)==after,"native confirm autosave reload "+mode+" "+encoded)
	check(progression(loaded)==progression(reference),"persisted XP rank choice and effects match reference "+mode+" "+encoded)
	await tap(JOY_BUTTON_A)
	check(progression(state)==after,"fresh A cannot repeat purchase "+encoded)
	if not board.sheet_detail.is_empty(): await tap(JOY_BUTTON_B)
	await activate("stage:"+track+":0")
	check(board.sheet_detail.get("kind")=="stage","completed stage is inspection only "+encoded)
	check(progression(state)==after,"completed stage cannot repurchase "+encoded)
	# Consumer diagnostics complement routed UI rejection; never repair fixture state.
	check(not state.choose_upgrade(encoded) and progression(state)==after,"duplicate consumer rejection "+encoded)
	# Replenished XP on an isolated reload makes this a branch-duplicate check,
	# independent of the zero-XP rejection exercised by the routed screen above.
	var duplicate=State.new(false)
	check(duplicate.load_run(),"duplicate fixture reload")
	duplicate.carried_xp=999; duplicate.secured_xp=999
	var duplicate_before=progression(duplicate)
	check(not duplicate.choose_upgrade(encoded) and progression(duplicate)==duplicate_before,"old branch rejected even with sufficient XP "+encoded)
	records.append({"fixture":"synthetic progression","mode":mode,"track":track,"branch":option,"selected_by_native_control":selected,"before":before,"after":after,"saved":progression(loaded)})
	await tap(JOY_BUTTON_B); await tap(JOY_BUTTON_B)
	check(not board.character_sheet_open and board.controller.paused,"Character returns to invoking pause")
	await finish()
func ordinary(mode: String):
	await fixture(mode,6)
	var before=progression(board.state)
	await activate("stage:evasion:0")
	check(board.sheet_detail.get("kind")=="upgrade","ordinary nonbranch confirmation")
	await activate("character:confirm")
	check(board.state.carried_xp==0 and board.state.track_total("evasion")==1 and board.state.upgrade_count==1,"ordinary XP/rank exactly once "+mode)
	check(board.state.track_choices==before.choices,"ordinary purchase invents no branch")
	var loaded=State.new(false)
	check(loaded.load_run() and progression(loaded)==progression(board.state),"ordinary native autosave "+mode)
	await finish()
func ineligible(mode: String):
	await fixture(mode,0)
	var before=progression(board.state)
	await activate("stage:swordsmanship:0")
	check(board.sheet_detail.get("kind")=="stage","no XP makes branch inspection only "+mode)
	await tap(JOY_BUTTON_A)
	check(progression(board.state)==before,"ineligible routed A cannot buy "+mode)
	check(not board.state.choose_upgrade("swordsmanship|prototype_sweeping_cut") and progression(board.state)==before,"ineligible consumer rejection "+mode)
	await finish()
func gated_and_stale():
	await fixture("expedition",6)
	var before=progression(board.state)
	await activate("stage:vanguard:0")
	check(board.sheet_detail.get("kind")=="stage","level-gated track remains inspection despite sufficient XP")
	await tap(JOY_BUTTON_A)
	check(progression(board.state)==before and not board.state.choose_upgrade("vanguard"),"level gate rejects routed and consumer purchase")
	if not board.sheet_detail.is_empty(): await tap(JOY_BUTTON_B)
	await activate("stage:swordsmanship:0"); await activate("choice:prototype_sweeping_cut")
	# Explicit concurrent-eligibility fixture, not gameplay earnings.
	board.state.carried_xp=0; await frames()
	before=progression(board.state)
	await activate("character:confirm")
	check(progression(board.state)==before and board.sheet_detail.get("kind")=="track_choice","stale confirmation rechecks current eligibility without mutation")
	await finish()
func art_and_belt(experimental: bool = false):
	await fixture("combat_survey" if experimental else "expedition",0,experimental)
	# Legacy art library fixture exposes every migrated button; swaps remain forbidden.
	board.state.player_weapon_art_library.assign(["prototype_sweeping_cut","prototype_drawing_cut"])
	board.state.player_equipped_weapon_art="prototype_sweeping_cut"
	await frames(8)
	var art_count := 0
	for control in board.character_menu.find_children("*","Button",true,false):
		if str(control.get_meta("menu_id","")).begins_with("art:"):
			art_count+=1; check(control.disabled,"existing no-art-swap policy disables native art")
	check(art_count==2 and not board.state.equip_weapon_art("prototype_drawing_cut"),"art swap eligibility retained")
	check(board.state.player_equipped_weapon_art=="prototype_sweeping_cut","ineligible art leaves equipment intact")
	# Distinct labelled belt contents; native selection must pay the ordinary action.
	board.state.consumable_slots.assign([{"id":"trail_ration","count":1},{"id":"firebomb","count":2},{}])
	await frames(8)
	var slots: Array=board.state.consumable_slots.duplicate(true)
	var tick: int=board.state._simulation_tick_index
	await activate("belt:0")
	check(board.sheet_repack_slot==0 and board.state.consumable_slots==slots and board.state._simulation_tick_index==tick,"first belt selection costs nothing")
	await activate("belt:0")
	check(board.sheet_repack_slot==-1 and board.state.consumable_slots==slots and board.state._simulation_tick_index==tick,"same belt selection cancels without cost")
	board.state.save_run("user://repack-control.save")
	var reference=State.new(false); check(reference.load_run("user://repack-control.save"),"repack reference reload")
	check(reference.request_repack(0,1),"existing state repack transaction reference")
	await activate("belt:0"); await activate("belt:1")
	for i in range(120):
		if not board.streaming_action and board.state.is_player_ready(): break
		await frames(2)
	check(not board.character_sheet_open and not board.character_menu.visible,"paid repack closes native Character")
	check(board.state.consumable_slots==[slots[1],slots[0],slots[2]],"belt swaps exactly the two selected contents")
	check(board.state._simulation_tick_index==reference._simulation_tick_index and board.state._simulation_tick_index>tick,"repack pays same simulation time as original state transaction")
	var done: int=board.state._simulation_tick_index
	await frames(20)
	check(board.state._simulation_tick_index==done,"repack ends at frozen ready state without repeating")
	check(not board.controller.sheet_return_pause,"paid repack consumes its pause return context")
	check(not board.inspection_return,"paid repack consumes its Survey return context")
	# A subsequent independent Character opening must not inherit an old invoker.
	await key(KEY_C)
	check(board.character_sheet_open,"fresh keyboard Character opens after paid repack")
	await tap(JOY_BUTTON_B)
	check(not board.controller.paused,"subsequent independent Character does not inherit old pause invoker")
	check(not board.inspection_scroll.visible and not board.suspended,"subsequent independent Character does not inherit old Survey invoker")
	records.append({"fixture":"synthetic belt and legacy art library","experimental_survey":experimental,"tick_before":tick,"tick_after":done,"reference_tick":reference._simulation_tick_index,"slots":board.state.consumable_slots.duplicate(true),"stale_pause_return":board.controller.sheet_return_pause,"stale_inspection_return":board.inspection_return})
	await finish()
func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	for mode in ["expedition","combat_survey","campaign_lab"]:
		for pair in [["swordsmanship","prototype_sweeping_cut"],["swordsmanship","prototype_drawing_cut"],["steadfast","toughness"],["steadfast","vigilance"]]:
			await branch(mode,pair[0],pair[1])
		await ordinary(mode)
		await ineligible(mode)
	await gated_and_stale()
	await art_and_belt()
	await art_and_belt(true)
	var result={"fixture_policy":"synthetic isolated progression, belt and legacy art fixtures; not naturally earned play","checks":checks,"failures":failures,"records":records}
	var file=FileAccess.open("user://character-transaction-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print("Character transactions: ",checks," checks, ",failures.size()," failures. Results: ",OS.get_user_data_dir())
	quit(0 if failures.is_empty() else 1)
