extends "res://tests/feedback_root_layout_test.gd"
# Explicit density/unit geometry models after an actual delayed feedback entry.
# Board gameplay processing is then stopped; these are not Android/device runs.
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	await setup(Vector2i(1280,800)); await answer_all()
	board.controller.active=true; await frames()
	board.set_process(false)
	for model in [[390,844,1.0],[780,1688,2.0],[1170,2532,3.0],[720,480,1.5],[960,600,2.0],[2560,1440,2.0],[390,844,2.0],[720,1280,2.0],[960,600,3.0]]:
		root.size=Vector2i(model[0],model[1]); await frames(12)
		var transform:=root.get_final_transform()
		var u: float=float(model[2])/minf(transform.x.length(),transform.y.length())
		board._reflow_survey_menu(u); await frames(12)
		await audit("explicit density "+str(model),u,1)
	# A cutout/safe-area model uses the same actual root transform and bounded area.
	root.size=Vector2i(390,844); await frames(12)
	board.layout_safe_area_override=Rect2(board.size*0.04,board.size*0.92)
	board._layout()
	var transform:=root.get_final_transform()
	var u: float=1.0/minf(transform.x.length(),transform.y.length())
	board._reflow_survey_menu(u); await frames(12)
	await audit("explicit safe-area inset",u,1)
	await finish()
	# Shared feedback owner: separately labelled Boss Lab fixture checks its other
	# four authored questions, after a fresh scene and the real outcome delay.
	root.size=Vector2i(390,844)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	board=load("res://scenes/main.tscn").instantiate(); root.add_child(board); await frames()
	board.state.start_run("warrior","boss_lab",717171,"encounter","energy")
	board.state.end_survey_run(); await create_timer(2.5).timeout; await frames(12)
	check(board.survey_overlay.get_meta("kind","")=="feedback" and board.survey_rating_buttons.has("fairness"),"fresh Boss Lab feedback fixture")
	await answer_all(); board.controller.active=true; await frames()
	await audit("Boss Lab cold narrow shared feedback",-1,1)
	await finish()
	output("menu-density-layout")
