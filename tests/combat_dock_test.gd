extends "res://tests/commit_shot_input_test.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for dims in [Vector2i(390,844),Vector2i(720,480),Vector2i(720,600),Vector2i(1280,800)]:
		for projection in ["top_down","isometric"]:
			await setup("energy",projection,dims,"warrior")
			var s=board.state;var u=board.MenuMetrics.unit(board);var hud=board._sync_commit_hud()
			for region in [hud.commit,hud.attack,hud.idle,hud.targeting,hud.xp,hud.log]:
				check(board.commit_dock_rect.encloses(region) and not board.board_rect.intersects(region),"control/guidance surface outside tactical drawing area "+str(dims)+projection)
			check(board.board_rect.size.y/u>=200,"useful tactical height retained")
			check(hud.commit.size.y/u>=48 and hud.attack.size.y/u>=48,"action minimum retained")
			var commit=board.commit_shot_rect;var attack=board.attack_rect;var tactical=board.board_rect
			await select("touch");await tap(commit.get_center())
			check(board.selected_action=="" and s.simulation_time==0,"dock cancellation has its own unambiguous surface")
			await select("touch");await tap(board._world_to_screen(s.player_pos+Vector2(130,40)))
			check(board.selected_action=="commit_shot" and board.commit_shot_rect==commit and board.attack_rect==attack and board.board_rect==tactical,"refusal and selection never move controls/camera")
			await tap(commit.get_center());await select("pad")
			check(board.commit_shot_rect==commit and board.attack_rect==attack and board.board_rect==tactical,"controller guidance reserves same stable dock")
			await pad(JOY_BUTTON_B)
			if dims==Vector2i(390,844) and projection=="isometric":
				# Preserve the review's obstructed WORLD positions, not a newly invented
				# enemy outside the resized camera at a dock coordinate.
				var ref_area=Rect2(Vector2.ZERO,Vector2(720,1558*0.735))
				var ref_scale=maxf(ref_area.size.x/1050.0,ref_area.size.y/1000.0)*1.38
				var anchor=ref_area.get_center()+Vector2(0,ref_area.size.y*0.075)
				for old_point in [Vector2(158.7692,754.2838),Vector2(672.11,754.2838),Vector2(360,930)]:
					var projected=(old_point-anchor)/ref_scale
					var world=s.player_pos+Vector2(projected.x+projected.y*2,projected.y*2-projected.x)
					s.enemies[0].pos=world;s._update_exploration(true);board.visual=board._presentation_snapshot()
					var point=target_point()
					check(board.board_rect.has_point(point) and not board.commit_dock_rect.has_point(point),"previously obscured enemy remains in tactical viewport")
					var hp=s.enemies[0].hp;await select("touch")
					check(s.enemies[0].pos==world and s.enemies[0].hp==hp,"fixture enemy not moved, killed or culled to clear control")
					await tap(point);board.set_process(false)
					check(s.player_action.get("full_combo_commit",false),"actual body tap confirms instead of cancelling")
					s.player_action=s._idle_action();s.player_energy=s.player_max_energy;board.playing=false;board.streaming_action=false;board.set_process(true)
			await finish()
	await setup("energy","isometric",Vector2i(390,844),"mage_elementalist")
	var primary=board.commit_shot_rect;var attack=board.attack_rect;var tactical=board.board_rect
	board.spellbook_open=true;board._layout();await frames(4)
	check(board.commit_shot_rect==primary and board.attack_rect==attack and board.board_rect==tactical,"Mage drawer does not move primary controls or camera under a contact")
	await finish()
	print("COMBAT DOCK ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
