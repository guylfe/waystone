extends SceneTree
# Explicit synthetic XP/art/stage fixtures; no naturally earned progression claim.
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
func text() -> String:
	var lines: Array[String]=[]
	for control in board.character_menu.find_children("*","Control",true,false):
		if control is Label or control is BaseButton: lines.append(control.text)
	return "\n".join(lines).to_upper()
func command(id: String):
	for control in board.character_menu.find_children("*","Button",true,false):
		if str(control.get_meta("menu_id",""))==id: return control
	return null
func click(control):
	check(control!=null,"native control exists")
	if control==null:return
	board.character_menu.scroll.ensure_control_visible(control); await frames()
	var point: Vector2=control.get_global_rect().get_center()
	for down in [true,false]:
		var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down
		e.position=point; e.global_position=point
		Input.parse_input_event(e.xformed_by(root.get_final_transform())); await frames(2)
	await frames()
func back():
	for down in [true,false]:
		var e:=InputEventJoypadButton.new(); e.device=0; e.button_index=JOY_BUTTON_B; e.pressed=down
		Input.parse_input_event(e); await frames(2)
	await frames()
func fixture(mode: String, loadout: String = "warrior"):
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	board=load("res://scenes/main.tscn").instantiate(); root.add_child(board)
	await frames()
	board.state.start_run(loadout,mode,630063,"encounter","energy",true)
	board.state.enemies.clear(); board.state.walls.clear()
	board.state.carried_xp=147; board.state.secured_xp=100
	if mode=="campaign_lab": board.state.player_pos=board.state.waystones[0].pos
	board.visual=board._presentation_snapshot(); board._layout()
	board._open_character_sheet(); await frames(12)
func finish(): board.queue_free(); await frames()
func balance_case(mode: String):
	await fixture(mode)
	var context: String=board.state.character_sheet_data().level_up_context
	var amount:=100 if mode=="campaign_lab" else 147
	var source: String="SECURED" if mode=="campaign_lab" else "CARRIED"
	var header=text()
	check(header.contains("LEVEL UP") and header.contains("WAYSTONE" if context=="waystone" else "COMBAT SURVEY" if context=="survey" else "EXPEDITION"),"actual level-up source "+mode)
	check(header.contains("SPENDABLE "+source+" XP · "+str(amount)),"actual spendable balance "+mode)
	check(header.contains("ART · LOCKED"),"initial art explicitly locked")
	check(header.contains("DISCIPLINE NOT YET FOUND"),"empty adopted track explanation")
	check(command("stage:swordsmanship:0").text.to_upper().contains("AVAILABLE"),"purchasable stage status")
	if mode=="campaign_lab": check(header.contains("CARRIED XP · 147"),"carried XP separately labelled at Waystone")
	await click(command("stage:swordsmanship:0"))
	var detail=text()
	check(detail.contains("REMAINING "+str(amount-6)+" XP"),"projected remainder "+mode)
	check(detail.contains("SPENDABLE "+source+" XP · "+str(amount)),"confirmation uses correct balance "+mode)
	await click(command("choice:prototype_sweeping_cut")); await click(command("character:confirm"))
	check(board.state.track_total("swordsmanship")==1 and board.state.carried_xp==141 and board.state.secured_xp==(94 if mode=="campaign_lab" else 100),"unchanged native purchase accounts "+mode)
	var after=text()
	check(after.contains("ART · EQUIPPED · SWEEPING CUT"),"equipped art summary")
	check(command("art:prototype_sweeping_cut").disabled and command("art:prototype_sweeping_cut").text.to_upper().contains("EQUIPPED"),"equipped marker and art swap prohibition")
	check(command("stage:swordsmanship:0").text.to_upper().contains("COMPLETED"),"completed overview status")
	await click(command("stage:swordsmanship:0"))
	check(text().contains("COMPLETED"),"completed status in stage detail")
	await back(); await click(command("stage:evasion:1"))
	check(text().contains("AVAILABLE FROM LEVEL 5"),"future-stage detail availability")
	records.append({"fixture":"synthetic XP secured100 carried147","mode":mode,"context":context,"summary_before":header,"detail_before":detail,"summary_after":after,"stage_detail":text(),"xp_after":board.state.carried_xp,"secured_after":board.state.secured_xp})
	await finish()
func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	root.size=Vector2i(1280,800)
	for mode in ["campaign_lab","combat_survey","expedition"]: await balance_case(mode)
	for pair in [["warrior","CUT › RETURN › DRIVING CUT"],["rogue_acrobat","FOUR COMPACT CUTS"],["rogue_sharpshooter","DRAW › RELEASE"],["mage_elementalist","STAFF THRUST"]]:
		await fixture("expedition",pair[0])
		check(text().contains(pair[1]),"authored weapon form "+pair[0])
		records.append({"fixture":"synthetic loadout summary","loadout":pair[0],"text":text()})
		await finish()
	await fixture("expedition")
	board.state.player_weapon_art_library.assign(["prototype_sweeping_cut","sword_thrust"])
	board.state.player_equipped_weapon_art="prototype_sweeping_cut"
	board.state.player_weapon_frame="twin_knives" # Labelled legacy form inspection.
	await frames(12)
	check(command("art:prototype_sweeping_cut").text.to_upper().contains("EQUIPPED") and command("art:sword_thrust").text.to_upper().contains("NOT EQUIPPED"),"legacy library distinguishes equipped and other known art")
	check(command("art:prototype_sweeping_cut").disabled and command("art:sword_thrust").disabled,"all legacy library swapping stays prohibited")
	check(text().contains("SIX ALTERNATING CUTS"),"authored twin-knife form")
	records.append({"fixture":"synthetic two-art legacy library and twin-knife form","text":text()})
	await finish()
	var f=FileAccess.open("user://character-information-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"));f.close()
	print("CHARACTER INFORMATION ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
