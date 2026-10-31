extends "res://tests/phone_world_repair_test.gd"
const Generator=preload("res://scripts/core/expedition_generator.gd")
func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	view=SubViewport.new()
	view.size=Vector2i(720,1280)
	root.add_child(view)
	board=load("res://scenes/main.tscn").instantiate()
	view.add_child(board)
	await frames()
	board.set_process(false)
	for seed in [73,717,99117]:
		for biome in range(3):
			for projection in ["top_down","isometric"]:
				board.state.start_run("warrior","expedition",seed)
				if biome>0:
					board.state.expedition.biome=biome
					board.state._install_layout(Generator.generate(seed,biome))
					board.state._respawn_enemies()
				board.view_mode=projection
				var p: Dictionary=board.state.world_pickups[0]
				var id: String=p.id
				board.state.player_pos=p.pos
				board.state.current_area_id=22
				board.state._apply_shortcut_world_state()
				board.state._update_exploration(true)
				board.state.consumable_slots=board.state._empty_consumable_slots()
				await sync_board()
				await touch(board._world_to_screen(board.state.player_pos))
				var label: String="seed=%d biome=%d %s" % [seed,biome,projection]
				check(not has_pickup(id),"generated exploratory supply collects at exact position "+label)
				print("GENERATED_SUPPLY ",JSON.stringify({"seed":seed,"biome":biome,"projection":projection,"id":id,"pos":str(p.pos),"message":board.state.message}))
				board.state.player_pos=board.state.expedition_markers.merchant
				board.state.current_area_id=20 if biome==1 else 21
				board.state._apply_shortcut_world_state()
				board.state._update_exploration(true)
				await sync_board()
				check(board.state.interaction_label()=="TRADE","generated merchant context remains usable "+label)
				await touch(board._world_to_screen(board.state.player_pos))
				check(is_instance_valid(board.expedition_dialog) and board.expedition_dialog.visible,"generated merchant marker opens shop "+label)
				if is_instance_valid(board.expedition_dialog): board.expedition_dialog.hide()
	view.queue_free()
	await frames()
	print("GENERATED_SUPPLY_ROUTE checks=%d failures=%d" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
