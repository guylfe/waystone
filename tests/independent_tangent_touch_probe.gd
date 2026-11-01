extends "res://tests/phone_boundary_probe.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	await setup(Vector2i(720,1280))
	for projection in ["top_down","isometric"]:
		await synthetic_floor("curved");board.view_mode=projection
		var s=board.state;var p=Vector2(1050-State.PLAYER_RADIUS*0.72,800);s.player_pos=p;await sync_fixture()
		var valid=s._actor_footprint_on_floor(p,State.PLAYER_RADIUS)
		var target=board._world_to_screen(p+Vector2(-80,0));require(board.board_rect.has_point(target),"inward touch inside battlefield")
		await touch(target);await create_timer(0.5).timeout;await frames()
		record("tangent_inward_touch",{"projection":projection,"origin":str(p),"cardinal_valid":valid,"result":str(s.player_pos),"time":s.simulation_time,"message":s.message,"input":"root transformed ScreenTouch with automatic main-scene process","moves_inward":s.player_pos.x<p.x})
	await finish();FileAccess.open("res://.runtime/independent-tangent-touch-results.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"harness_errors":errors},"\t"));quit(0 if errors.is_empty() else 2)
