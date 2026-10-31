extends "res://tests/phone_world_repair_test.gd"
const Economy=preload("res://scripts/core/expedition_economy.gd")
func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	view=SubViewport.new()
	view.size=Vector2i(720,1280)
	root.add_child(view)
	board=load("res://scenes/main.tscn").instantiate()
	view.add_child(board)
	await frames()
	board.set_process(false)
	for projection in ["isometric","top_down"]:
		board.state.start_run("warrior","expedition",717)
		board.state.player_pos=board.state.expedition_markers.merchant
		board.state.current_area_id=21
		board.state._apply_shortcut_world_state()
		board.view_mode=projection
		board.state.expedition.crowns=100
		check(Economy.purchase(board.state,"trail_ration"),"ordinary purchase fixture succeeds "+projection)
		var bought: Dictionary=board.state.world_pickups.back()
		var id: String=bought.id
		await sync_board()
		var marker: Vector2=board._world_to_screen(board.state.player_pos)
		print("MERCHANT_OVERLAP ",projection," goods_screen_gap=",marker.distance_to(board._world_to_screen(bought.pos))," pickup_hit_radius=",maxf(34.0,38.0*board.world_scale))
		await touch(marker)
		check(is_instance_valid(board.expedition_dialog) and board.expedition_dialog.visible,"exact merchant tap reopens shop beside purchased goods "+projection)
		check(has_pickup(id),"merchant tap preserves uncollected purchased goods "+projection)
		if is_instance_valid(board.expedition_dialog): board.expedition_dialog.hide()
		await sync_board()
		await touch(board._world_to_screen(bought.pos))
		check(not has_pickup(id),"exact goods tap still collects beside merchant "+projection)
	view.queue_free()
	await frames()
	print("MERCHANT_OVERLAP_INPUT checks=%d failures=%d" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
