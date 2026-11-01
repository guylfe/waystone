extends "res://tests/commit_shot_input_test.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for rules in ["energy","recovery"]:
		await setup(rules,"top_down")
		var s=board.state
		await key(KEY_F,true)
		var before={"kind":s.player_action.kind,"held":board.attack_key_held,"elapsed":s.player_action.elapsed}
		await key(KEY_F,false)
		var after={"kind":s.player_action.kind,"held":board.attack_key_held,"elapsed":s.player_action.elapsed}
		await create_timer(1.3).timeout;await frames()
		records.append({"rules":rules,"press":before,"release":after,"later_kind":s.player_action.kind,"shots":s.survey_shots_fired,"world_time":s.simulation_time})
		check(s.survey_shots_fired==1 and s.is_player_ready(),"ordinary F release fires and finishes "+rules)
		await finish()
	FileAccess.open("user://bow-release-input-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("BOW RELEASE INPUT ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
