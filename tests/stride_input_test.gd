extends "res://tests/commit_shot_input_test.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for projection in ["top_down","isometric"]:
		for distance in [4.0,8.0,16.0,34.0]:
			await setup("energy",projection,Vector2i(720,1280),"warrior")
			var s=board.state;s.world_pickups.clear();s.waystones.clear();s.transitions.clear()
			s.enemies[0].pos=s.player_pos+Vector2(450,450);s._update_exploration(true);board.visual=board._presentation_snapshot();board._layout()
			var origin=s.player_pos;var point=board._world_to_screen(origin+Vector2.RIGHT*distance)
			await tap(point);await ready()
			check(s.player_pos.x-origin.x>=34 and s.player_pos.x-origin.x<38,"routed nearby ground tap commits full stride "+projection+str(distance))
			check(is_equal_approx(s.simulation_time,16*s.SIM_DT),"tap decision interval independent of target distance")
			var end=s.simulation_time;await frames(10);check(s.simulation_time==end,"release does not queue an extra stride")
			# The locked current stride owns the cue, even if a hold aims the next stride elsewhere.
			s.begin_streamed_move(Vector2.RIGHT,4);board.visual=board._presentation_snapshot();board.held_direction=Vector2.DOWN
			board.touch_start=Vector2(100,100);board.touch_current=Vector2(700,700)
			var segment=board._movement_hint_segment()
			check(segment[0].is_equal_approx(board._world_to_screen(s.player_pos)) and segment[1].is_equal_approx(board._world_to_screen(s.player_pos+Vector2.RIGHT*34)),"movement cue shows committed stride instead of finger destination")
			await finish()
	print("STRIDE ROOT INPUT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
