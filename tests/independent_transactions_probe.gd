extends "res://tests/phone_baseline_probe.gd"
func audit(id,ok,data={}):
	data["passed"]=ok;record(id,data.duplicate(true))
func close_dialog():
	if is_instance_valid(board.expedition_dialog):board.expedition_dialog.hide();await frames()
func button_like(prefix):
	for c in board.expedition_dialog.find_children("*","Button",true,false):
		if c.text.begins_with(prefix):return c
	return null
func dialog_touch(button):
	if button==null:require(false,"dialog button found");return
	var local_point=button.get_global_rect().get_center()
	var parent=button.get_parent()
	while parent!=null and parent!=board.expedition_dialog:
		if parent is ScrollContainer:require(parent.get_global_rect().has_point(local_point),"dialog touch inside visible scroll area")
		parent=parent.get_parent()
	var p=local_point+Vector2(board.expedition_dialog.position)
	await touch(p)
func ready():
	await create_timer(0.7).timeout;await frames()
func parity(id):
	var s=board.state;var path="user://transactions-"+id+".save";var saved=s.save_run(path);var l=State.new(false);var loaded=l.load_run(path)
	audit("persistence_"+id,saved and loaded and s.world_pickups==l.world_pickups and s.expedition==l.expedition and s.consumable_slots==l.consumable_slots and s.player_attributes==l.player_attributes and s.player_hp==l.player_hp,{"saved":saved,"loaded":loaded})
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	root.gui_embed_subwindows=true
	await setup(Vector2i(720,1280))
	for projection in ["top_down","isometric"]:
		await reset_fixture(projection);var s=board.state
		s.world_pickups.clear();var p=s.player_pos
		s._add_pickup({"id":"first_gear","item_id":"scout_boots","count":1,"pos":p,"layer":s.current_layer})
		await sync_fixture();var time=s.simulation_time;await touch(board._world_to_screen(p));await frames()
		audit("equipment_comparison_"+projection,is_instance_valid(board.expedition_dialog) and board.expedition_dialog.visible)
		var equip=button_like("Equip");require(equip!=null,"Equip exists")
		await dialog_touch(equip)
		audit("equipment_touch_commit_"+projection,s.pickup_by_id("first_gear").is_empty() and s.expedition.equipment.get("legs","")=="scout_boots",{"equipment":s.expedition.equipment,"remaining":s.pickup_by_id("first_gear"),"dialog_visible":board.expedition_dialog.visible})
		# Reuse of consumed pickup ID must not apply its attributes again.
		var attributes=s.player_attributes.duplicate(true);var again=Economy.equip(s,"first_gear")
		audit("equipment_once_"+projection,not again and s.player_attributes==attributes and s.simulation_time==time)
		await close_dialog()
		s._add_pickup({"id":"second_gear","item_id":"runner_boots","count":1,"pos":p,"layer":s.current_layer})
		# Catalog-selected compatible second item; no fabricated item definition.
		var replacement=""
		for id in s.ExpeditionCatalogScript.EQUIPMENT:
			if s.ExpeditionCatalogScript.EQUIPMENT[id].slot=="legs" and id!="scout_boots":replacement=id;break
		if replacement!="":
			s.pickup_by_id("second_gear").item_id=replacement
			await sync_fixture();await touch(board._world_to_screen(p));await dialog_touch(button_like("Equip"));await close_dialog()
			audit("equipment_displaced_"+projection,s.expedition.equipment.get("legs","")==replacement and s.world_pickups.any(func(x):return x.item_id=="scout_boots"),{"replacement":replacement,"ground":s.world_pickups})
		else:require(false,"second boots catalog entry exists")
		parity("equipment_"+projection)
		await reset_fixture(projection);s=board.state
		s.player_pos=s.expedition_markers.merchant;s.world_pickups.clear();s.expedition.crowns=100;await sync_fixture()
		await touch(board._world_to_screen(s.player_pos));var stock_before=Economy.stock(s);var row=stock_before.filter(func(x):return x.id=="reinforced_jack")[0]
		var before=int(s.expedition.crowns);await dialog_touch(button_like("Reinforced Jack"));await frames()
		var goods=s.world_pickups.filter(func(x):return x.id.begins_with("purchase_"))
		audit("purchase_touch_once_"+projection,int(s.expedition.crowns)==before-int(row.price) and goods.size()==1 and int(s.expedition.purchases.get("0:reinforced_jack",0))==1,{"crowns_before":before,"crowns_after":s.expedition.crowns,"goods":goods,"purchases":s.expedition.purchases})
		await close_dialog();await sync_fixture();await touch(board._world_to_screen(s.player_pos))
		audit("reopen_preserves_"+projection,int(s.expedition.crowns)==before-int(row.price) and s.world_pickups==goods)
		await close_dialog();await sync_fixture()
		if goods.size()==1:
			await touch(board._world_to_screen(goods[0].pos));await dialog_touch(button_like("Equip"));await close_dialog();await ready()
			audit("goods_collect_"+projection,s.pickup_by_id(goods[0].id).is_empty() and s.expedition.equipment.get("torso","")=="reinforced_jack")
		parity("purchase_"+projection)
		# Direct transaction controls use real stock: exhaust, then reject without writes.
		while Economy.purchase(s,"trail_ration"):pass
		var frozen=s.expedition.duplicate(true);var ground=s.world_pickups.duplicate(true)
		audit("stock_exhaustion_"+projection,not Economy.purchase(s,"trail_ration") and s.expedition==frozen and s.world_pickups==ground)
		s.expedition.crowns=0;frozen=s.expedition.duplicate(true);ground=s.world_pickups.duplicate(true)
		var other=Economy.stock(s).filter(func(x):return int(x.quantity)>0 and int(x.price)>0)
		audit("insufficient_money_"+projection,other.size()>0 and not Economy.purchase(s,other[0].id) and s.expedition==frozen and s.world_pickups==ground)
		await reset_fixture(projection);s=board.state;s.world_pickups.clear();p=s.player_pos
		s.consumable_slots.assign([{"id":"trail_ration","count":3},{"id":"trail_ration","count":3},{"id":"trail_ration","count":3}]);s._add_pickup({"id":"replace_me","item_id":"firebomb","count":2,"pos":p,"layer":s.current_layer})
		await sync_fixture();await touch(board._world_to_screen(p));var pending=s.pending_pickup.duplicate(true)
		audit("full_pending_"+projection,pending.get("id","")=="replace_me" and s.message.contains("Belt full"))
		await touch(board.consumable_rects.slot_0.get_center());await ready()
		var success=s.pending_pickup.is_empty();var once=s.consumable_slots.duplicate(true)
		audit("replacement_once_displaced_"+projection,success and not s.replace_pending_pickup(0,true) and s.consumable_slots==once and s.pickup_by_id("replace_me").is_empty() and s.world_pickups.filter(func(x):return x.item_id=="trail_ration" and x.count==3).size()==1)
		parity("replacement_"+projection)
	await finish()
	FileAccess.open("res://.runtime/independent-transactions-results.json",FileAccess.WRITE).store_string(JSON.stringify({"sha":"1660a840da567062b3f0211e463f2bbf7fc2e23c","rows":rows,"harness_errors":errors},"\t"))
	quit(0 if errors.is_empty() else 2)


