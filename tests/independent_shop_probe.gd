extends "res://tests/phone_baseline_probe.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	root.gui_embed_subwindows=true
	await setup(Vector2i(720,1280));await reset_fixture("isometric")
	var s=board.state;s.player_pos=s.expedition_markers.merchant;s.expedition.crowns=100;s.world_pickups.clear();await sync_fixture()
	await touch(board.interaction_rect.get_center())
	require(board.expedition_dialog.visible,"context opens shop")
	var button=null
	for c in board.expedition_dialog.find_children("*","Button",true,false):
		if c.text.begins_with("Reinforced Jack"):button=c
	require(button!=null,"finite stock button found")
	var point=button.get_global_rect().get_center()+Vector2(board.expedition_dialog.position)
	await touch(point)
	print("SHOP_RECEIPT ",JSON.stringify({"crowns":s.expedition.crowns,"purchases":s.expedition.purchases,"goods":s.world_pickups,"visible":board.expedition_dialog.visible,"point":str(point),"time":s.simulation_time}))
	await finish();quit(0 if errors.is_empty() else 2)
