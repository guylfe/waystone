extends "res://tests/commit_shot_input_test.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for dims in [Vector2i(390,844),Vector2i(720,480),Vector2i(840,720)]:
		for projection in ["top_down","isometric"]:
			await setup("energy",projection,dims)
			var rect=board.commit_shot_rect;var u=board.MenuMetrics.unit(board)
			check(rect.size.x>=48*u and rect.size.y>=48*u,"client-unit hit minimum "+str(dims))
			check(board.board_rect.encloses(rect) and board._display_safe_layout_rect().encloses(rect),"safe reachable new action "+str(dims))
			check(not rect.intersects(board.attack_rect),"new action remains separate from ordinary Attack "+str(dims))
			for label in ["COMMIT SHOT","CHOOSE ENEMY","FULL SHOT COMMITTED","+25% damage · [G]"]:
				var font=roundi((17 if label=="COMMIT SHOT" else 12)*u)
				var width=ThemeDB.fallback_font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font).x
				check(width<=rect.size.x-4*u,"actual shaped new action label fits "+label+str(dims))
			await tap(rect.get_center());check(board.selected_action=="commit_shot","new action selected by normal root touch "+str(dims))
			await tap(rect.get_center());check(board.selected_action=="" and board.state.simulation_time==0,"repeat selection cancels without time "+str(dims))
			records.append({"dims":str(dims),"projection":projection,"transform":str(root.get_final_transform()),"logical_board":str(board.size),"unit":u,"rect":str(rect),"board":str(board.board_rect),"model":"desktop actual-root transform; no Android DPI/native-pixel claim"})
			await finish()
	FileAccess.open("user://commit-shot-layout-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("COMMIT SHOT LAYOUT ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
