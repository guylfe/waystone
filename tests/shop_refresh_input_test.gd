extends "res://tests/phone_baseline_probe.gd"
# Normal native shop intent. Extra crowns / player positioning are explicit fixtures.
var checks=0
func check(ok:bool,why:String):
	checks+=1;require(ok,why)
func pad(code:int,down:bool):
	var e=InputEventJoypadButton.new();e.button_index=code;e.pressed=down;e.device=0;send(e)
func tap_pad(code:int):
	pad(code,true);await frames(2);pad(code,false);await frames(6)
func choose_ration():
	for i in 60:
		var focus=board.expedition_dialog.gui_get_focus_owner()
		if focus is Button and focus.text.begins_with("Trail Ration"):return focus
		await tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(false,"routed pad reaches repeat-purchasable ration")
	return null
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	root.gui_embed_subwindows=true
	await setup(Vector2i(720,1280))
	for projection in ["top_down","isometric"]:
		await reset_fixture(projection);var s=board.state
		s.player_pos=s.expedition_markers.merchant;s.expedition.crowns=999;s.world_pickups.clear();await sync_fixture()
		await touch(board.interaction_rect.get_center())
		check(board.expedition_dialog.visible,"normal context opens exclusive shop")
		var original=await choose_ration()
		if original==null:continue
		var old=board.expedition_dialog;var old_id=old.get_instance_id();var old_ref=weakref(old);var stale=original.get_signal_connection_list("pressed")[-1].callable;var crowns=s.expedition.crowns;var time=s.simulation_time
		var row=Economy.stock(s).filter(func(x):return x.id=="trail_ration")[0]
		var point=original.get_global_rect().get_center()+Vector2(old.position)
		pad(JOY_BUTTON_A,true)
		await frames(3)
		var previous=old_ref.get_ref()
		check(board.expedition_dialog.get_instance_id()!=old_id and (previous==null or (not previous.visible and not previous.exclusive)),"old exclusive owner released before successor remains active")
		# Supplement: replay a signal already owned by the hidden, queued dialog.
		# Purchases above/below are routed; this only probes stale callback rejection.
		stale.call()
		pad(JOY_BUTTON_A,false);await frames()
		check(s.expedition.crowns==crowns-int(row.price) and s.world_pickups.size()==1,"routed purchase and stale callback debit/create exactly once")
		var first=s.expedition.duplicate(true);var goods=s.world_pickups.duplicate(true)
		var release=InputEventScreenTouch.new();release.index=1;release.pressed=false;release.position=point;send(release);await frames()
		check(s.expedition==first and s.world_pickups==goods,"stale physical release cannot buy successor row")
		await touch(board._world_to_screen(s.player_pos+Vector2(180,0)))
		check(s.simulation_time==time and s.player_pos==s.expedition_markers.merchant,"exclusive shop blocks world input")
		var again=await choose_ration();check(again!=null,"remaining stock stays deliberately purchasable")
		await tap_pad(JOY_BUTTON_A)
		check(s.expedition.crowns==crowns-2*int(row.price) and s.world_pickups.size()==2,"fresh confirm buys another unit when stock remains")
		var purchased=int(s.expedition.purchases.get("0:trail_ration",0));check(purchased==2,"finite stock records two deliberate units")
		await tap_pad(JOY_BUTTON_B);check(not board.expedition_dialog.visible,"Back closes refreshed shop")
		send(release);await frames();check(s.simulation_time==time,"Back/stale release cannot leak movement")
		var path="user://shop-refresh-"+projection+".save";check(s.save_run(path),"ready transaction saves")
		var loaded=State.new(false);check(loaded.load_run(path) and loaded.expedition==s.expedition and loaded.world_pickups==s.world_pickups,"payment, stock and goods persist")
		record("shop_refresh_"+projection,{"crowns_before":crowns,"crowns_after":s.expedition.crowns,"price":row.price,"purchases":purchased,"goods":s.world_pickups.duplicate(true),"time":s.simulation_time,"routes":["root touch context","pad navigate and confirm","negative stale callback supplement","stale touch release","world tap while exclusive","pad Back"]})
	await finish()
	FileAccess.open("user://shop-refresh-input-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":errors,"records":rows},"\t"))
	print("SHOP REFRESH ROOT ",checks," checks ",errors.size()," failures");quit(0 if errors.is_empty() else 1)
