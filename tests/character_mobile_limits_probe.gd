extends "res://tests/character_mobile_test.gd"
# Additional explicit tiny client models: report unsupported sizes; never shrink type.
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for dims in [Vector2i(720,360),Vector2i(720,340),Vector2i(720,320),Vector2i(390,500),Vector2i(280,480),Vector2i(240,400)]:
		await fixture("rogue_sharpshooter","campaign_lab",147,"recovery",dims)
		var supported:bool=board.character_menu.get_meta("layout_supported",false)
		print("LIMIT ",dims," variant ",board.character_menu.variant," supported ",supported)
		if supported:
			await audit("small geometry model "+str(dims));await categories()
			if button("category:previous")!=null:
				while not button("category:previous").disabled:await tap("category:previous")
				check(button("category:equipment")!=null,"explicit Previous category navigation")
		else:
			records.append({"unsupported_model":str(dims),"unit":board.character_menu.u,"variant":board.character_menu.variant,"minimum":str(board.character_menu.shell.get_combined_minimum_size()),"panel":str(board.character_menu.get_global_rect()),"board_processing":board.is_processing()})
		await finish()
	var f=FileAccess.open("user://character-mobile-limits.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"));f.close()
	print("CHARACTER LIMITS ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
