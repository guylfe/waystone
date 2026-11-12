extends "res://tests/commit_shot_input_test.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for route in ["touch","keyboard","pad"]:
		await setup("energy","isometric",Vector2i(390,844),"warrior")
		var s=board.state
		await select(route)
		check(board.selected_action=="commit_shot" and s.simulation_time==0,"melee selection freezes "+route)
		await confirm(route)
		check(s.player_action.get("full_combo_commit",false),"melee target commits full sequence "+route)
		await ready()
		check(s.terminal_combo_recoveries_total==1,"melee serves terminal recovery "+route)
		var t=s.simulation_time;await frames(20)
		check(s.simulation_time==t,"melee discrete commit cannot repeat "+route)
		await finish()
	print("DECISION ROOT INPUT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
