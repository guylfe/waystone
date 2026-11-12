extends "res://tests/commit_shot_input_test.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for dims in [Vector2i(390,844),Vector2i(720,600),Vector2i(1280,800)]:
		await setup("energy","isometric",dims,"mage_elementalist")
		var primary=board.commit_shot_rect;var attack=board.attack_rect;var tactical=board.board_rect
		board.spellbook_open=true;board._layout();await frames()
		check(primary.is_equal_approx(board.commit_shot_rect) and attack.is_equal_approx(board.attack_rect) and tactical.is_equal_approx(board.board_rect),"drawer open preserves primary/camera "+str(dims))
		var hud=board._sync_commit_hud();var u=board.MenuMetrics.unit(board)
		check(primary.size.y/u>=48 and attack.size.y/u>=48,"Mage primary control minima")
		check(hud.log_paragraph.get_size().y<=hud.log.size.y and hud.idle_paragraph.get_size().y<=hud.idle.size.y,"guidance readable with drawer")
		for id in board.spell_rects:
			var rect=Rect2(board.spell_rects[id])
			check(not rect.intersects(attack) and not rect.intersects(primary) and not rect.intersects(tactical),"coexisting spell disjoint from final actions and battlefield "+str(id)+str(dims))
			check(board._display_safe_layout_rect().encloses(rect) and rect.size.y/u>=28,"chip retained inside safe area without shrinking")
			# Main-root center, corners, edges and right-half taps, where Attack overlapped.
			for fraction in [Vector2(.5,.5),Vector2(.01,.01),Vector2(.99,.01),Vector2(.01,.99),Vector2(.99,.99),Vector2(.5,.01),Vector2(.5,.99),Vector2(.01,.5),Vector2(.99,.5),Vector2(.75,.5)]:
				board.selected_action="";board.state.message=""
				var t=board.state.simulation_time;var energy=board.state.player_energy;var spent=board.state.energy_spent_total
				await tap(rect.position+rect.size*fraction)
				check(board.state.simulation_time==t and board.state.player_energy==energy and board.state.energy_spent_total==spent and board.state.player_action.kind=="idle","chip never attacks, advances time or spends Energy "+str(id)+str(fraction)+str(dims))
				if str(id).begins_with("locked:"):
					check(board.selected_action=="" and board.state.message.begins_with("That element is learned"),"locked chip existing refusal")
				else:check(board.selected_action=="advance" and board.state.selected_spell==id,"available chip arms spell")
		board.spellbook_open=false;board._layout();await frames()
		check(primary.is_equal_approx(board.commit_shot_rect) and attack.is_equal_approx(board.attack_rect) and tactical.is_equal_approx(board.board_rect),"drawer close preserves primary/camera "+str(dims)+str([primary,board.commit_shot_rect,attack,board.attack_rect,tactical,board.board_rect]))
		await finish()
	print("MAGE DRAWER ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
