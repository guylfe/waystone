extends "res://tests/commit_hud_input_test.gd"
func run():
	await setup("energy","isometric",Vector2i(780,1688));await select("pad")
	board.layout_safe_area_override=Rect2(board.size*0.025,board.size*0.95);board._layout();await frames(12)
	var t=root.get_final_transform();var dock_bottom=board.commit_dock_rect.end.y
	for density in [1.0,2.0,3.0]:
		var u=density/minf(t.x.length(),t.y.length())
		board.commit_dock_rect.size.y=board.CommitHudLayout.dock_height(u)
		board.commit_dock_rect.position.y=dock_bottom-board.commit_dock_rect.size.y
		board.board_rect.size.y=board.commit_dock_rect.position.y-board.board_rect.position.y
		await surface("analytical density "+str(density),u)
	await finish();print("DOCK DENSITY ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
