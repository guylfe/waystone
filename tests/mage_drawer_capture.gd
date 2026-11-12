extends "res://tests/readability_correction_capture.gd"
func run():
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	output=OS.get_environment("WAYSTONE_READABILITY_OUTPUT")
	if output.is_empty():output=ProjectSettings.globalize_path("user://mage-drawer")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_min_size(Vector2i(1,1))
	for dims in [Vector2i(390,844),Vector2i(720,600),Vector2i(1280,800)]:
		DisplayServer.window_set_size(dims)
		await setup("energy","isometric",dims,"mage_elementalist")
		await capture(str(dims)+"-closed")
		board.spellbook_open=true;board._layout();await frames()
		await capture(str(dims)+"-open")
		await tap(Rect2(board.spell_rects.values()[0]).get_center())
		await capture(str(dims)+"-selected")
		records.append({"chips":str(board.spell_rects),"selection":board.selected_action,"world_time":board.state.simulation_time,"energy_spent":board.state.energy_spent_total})
		await finish()
	FileAccess.open(output+"/records.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	quit(0 if failures.is_empty() else 1)
