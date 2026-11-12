extends SceneTree
const State=preload("res://scripts/core/run_state.gd")
const Board=preload("res://scripts/presentation/game_board.gd")
func board():
	var b=Board.new();b.state=State.new(false);b.state.start_run("warrior","combat_survey",3311,"encounter","energy")
	b.state.enemies.clear()
	var e=b.state._make_enemy("blade",b.state.player_pos+Vector2(300,0),999)
	e.layer=b.state.current_layer;e.action=b.state._action("wait",1000,Vector2.LEFT)
	b.state._replace_enemy_actors([e]);b.size=Vector2(1280,800)
	return b
func _init():
	var b=board();b._begin_streamed_action(b.state.request_wait(3,false))
	for i in 10:b._process(1.0/30.0)
	print("STREAM world seconds=",b.state.simulation_time," expected=5/12")
	var stream_ok=abs(b.state.simulation_time-5.0/12.0)<b.state.SIM_DT*1.1
	b.free()
	b=board();b._commit(b.state.request_wait(3,true))
	for i in 10:b._process(1.0/30.0)
	print("REPLAY index=",b.playback_index," remainder=",b.playback_accumulator," expected time=5/12")
	var replay_ok=abs(b.playback_index*b.state.FRAME_DT+b.playback_accumulator-5.0/12.0)<0.0001
	b.free();quit(0 if stream_ok and replay_ok else 1)
