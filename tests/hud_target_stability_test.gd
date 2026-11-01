extends "res://tests/feedback_target_input_test.gd"
# Initial idle origin, including the exact independently reported upper edge.
func stable_edges():
	for rules in ["energy","recovery"]:
		for projection in ["top_down","isometric"]:
			await setup(rules,projection,Vector2i(390,844));board.desktop_controls=false
			var origin:Rect2=board.commit_shot_rect;var attack:Rect2=board.attack_rect
			var point=Vector2(origin.get_center().x,origin.position.y+5)
			await tap(point)
			check(board.selected_action=="commit_shot","initial upper-edge tap selects")
			check(board.commit_shot_rect==origin and board.attack_rect==attack,"initial idle origin retained after selection")
			await tap(point);await frames(60)
			check(board.selected_action=="" and board.state.message=="Commit Shot selection cancelled.","same advertised upper-edge tap cancels")
			check(board.commit_shot_rect==origin and board.attack_rect==attack,"initial idle origin retained after settled cancel")
			check(board.state.simulation_time==0 and board.state.energy_spent_total==0 and board.state.survey_shots_fired==0,"upper-edge repeat free/frozen/no shot")
			await select("touch");await confirm("touch")
			check(board.commit_shot_rect==origin and board.attack_rect==attack,"initial idle origin retained through paid commit")
			await ready();check(board.state.survey_shots_fired==1,"one fresh full shot after repeated upper edge")
			records.append({"edge_case":rules+projection,"idle_origin":str(origin),"attack_origin":str(attack),"point":str(point),"final_commit":str(board.commit_shot_rect),"final_attack":str(board.attack_rect)})
			await finish()
func run():
	if DisplayServer.get_name()!="headless" or not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	await stable_edges()
	for route in ["touch","keyboard","pad"]:
		for rules in ["energy","recovery"]:await feedback(route,rules)
	await playback();await density_targets()
	FileAccess.open("user://hud-stability-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("HUD TARGET STABILITY ",checks," checks / ",records.size()," records / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
