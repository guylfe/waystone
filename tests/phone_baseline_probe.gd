extends SceneTree
# Independent 0e65cdf baseline observations. All state edits are labelled fixtures.
const State = preload("res://scripts/core/run_state.gd")
const Economy = preload("res://scripts/core/expedition_economy.gd")
var board
var rows: Array = []
var errors: Array = []
func _init(): call_deferred("run")
func frames(n: int = 8):
	for i in n: await process_frame
func record(id: String, data: Dictionary):
	data["id"]=id; rows.append(data); print("RECORD ",id)
func require(ok: bool, why: String):
	if not ok: errors.append(why); printerr("HARNESS ERROR: ",why)
func send(event: InputEvent): Input.parse_input_event(event.xformed_by(root.get_final_transform()))
func touch(pos: Vector2):
	for down in [true,false]:
		var e:=InputEventScreenTouch.new(); e.index=0; e.position=pos; e.pressed=down
		send(e); await frames(2)
	await frames()
func mouse(pos: Vector2):
	for down in [true,false]:
		var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.position=pos; e.global_position=pos; e.pressed=down
		send(e); await frames(2)
	await frames()
func swipe(pos: Vector2, delta: Vector2):
	var e:=InputEventScreenTouch.new(); e.index=0; e.position=pos; e.pressed=true; send(e); await frames(2)
	for i in 10:
		var d:=InputEventScreenDrag.new(); d.index=0; d.position=pos+delta*float(i+1)/10.0; d.relative=delta/10.0
		send(d); await frames(2)
	e.position=pos+delta; e.pressed=false; send(e); await frames()
func setup(dims: Vector2i):
	root.size=dims
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	board=load("res://scenes/main.tscn").instantiate(); root.add_child(board); await frames(14)
	await touch(board.progression_rects.expedition.get_center())
	board.seed_input.text="42"
	await touch(board.start_rect.get_center()); await frames(16)
	require(board.state.run_active and board.state.mode_id=="expedition","routed Expedition startup")
func finish(): board.queue_free(); await frames()
func controls() -> Array:
	var out: Array=[]
	for c in board.character_menu.find_children("*","Control",true,false):
		if c is Label or c is BaseButton:
			var clip: Rect2=board._display_safe_layout_rect()
			var a=c.get_parent()
			while a!=null:
				if a is Control and a.clip_contents: clip=clip.intersection(a.get_global_rect())
				a=a.get_parent()
			out.append({"text":c.text,"menu_id":c.get_meta("menu_id",""),"rect":str(c.get_global_rect()),"clip":str(clip),"full_visible":clip.grow(1).encloses(c.get_global_rect()),"intersection":str(clip.intersection(c.get_global_rect())),"disabled":c.disabled if c is BaseButton else false})
	return out
func character(dims: Vector2i, xp: int):
	await setup(dims)
	# Synthetic XP only; UI, input delivery and frame processing remain ordinary.
	board.state.carried_xp=xp
	await touch(board.sheet_button_rect.get_center())
	require(board.character_sheet_open,"routed Character toolbar opens")
	var menu=board.character_menu
	var before: int=menu.scroll.scroll_vertical
	record("character_open",{"dims":str(dims),"xp_fixture":xp,"logical":str(board.size),"unit":board.MenuMetrics.unit(board),"touch_emulates_mouse":Input.emulate_mouse_from_touch,"safe":str(board._display_safe_layout_rect()),"panel":str(menu.get_global_rect()),"scroll_rect":str(menu.scroll.get_global_rect()),"content_rect":str(menu.content.get_global_rect()),"scroll_max":menu.scroll.get_v_scroll_bar().max_value,"scroll_page":menu.scroll.get_v_scroll_bar().page,"controls":controls()})
	var start: Vector2=menu.scroll.get_global_rect().get_center()
	await swipe(start,Vector2(0,-minf(300,start.y-menu.scroll.global_position.y-20)))
	record("character_swipe",{"dims":str(dims),"xp_fixture":xp,"before":before,"after":menu.scroll.scroll_vertical,"detail":board.sheet_detail.duplicate(true)})
	# Routed desktop wheel is a control for content reachability, not phone evidence.
	for i in 28:
		var wheel:=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true; wheel.position=start; wheel.global_position=start; send(wheel); await frames(1)
	await frames()
	record("character_wheel_control",{"dims":str(dims),"xp_fixture":xp,"after":menu.scroll.scroll_vertical,"controls":controls()})
	# First visible equipment control: distinguish native touch from mouse delivery.
	menu.scroll.scroll_vertical=0; await frames()
	var first=menu.find_children("*","Button",true,false)[0]
	await touch(first.get_global_rect().get_center())
	record("character_equipment_touch",{"dims":str(dims),"xp_fixture":xp,"detail":board.sheet_detail.duplicate(true)})
	if board.sheet_detail.is_empty():
		await mouse(first.get_global_rect().get_center())
		record("character_equipment_mouse_control",{"dims":str(dims),"xp_fixture":xp,"detail":board.sheet_detail.duplicate(true)})
	await finish()
func reset_fixture(projection: String, clear_enemies: bool = true):
	board.state.start_run("warrior","expedition",42)
	if clear_enemies: board.state._replace_enemy_actors([])
	board.playing=false; board.streaming_action=false; board.view_mode=projection
	board.state.consumable_slots.assign([{},{},{}])
	board.visual=board._presentation_snapshot(); board._layout(); await frames()
func sync_fixture():
	board.state._update_exploration(true); board.visual=board._presentation_snapshot(); board._layout(); await frames()
func interaction_state() -> Dictionary:
	return {"player":str(board.state.player_pos),"ready":board.state.is_player_ready(),"layer":board.state.current_layer,"context":board.state.interaction_label(),"message":board.state.message,"pickups":board.state.world_pickups.duplicate(true),"visual_pickups":Array(board.visual.get("world_pickups",[])).duplicate(true),"pending":board.state.pending_pickup.duplicate(true),"belt":board.state.consumable_slots.duplicate(true),"safe":Economy.safe(board.state),"merchant_distance":board.state.player_pos.distance_to(board.state.expedition_markers.merchant),"sim_time":board.state.simulation_time,"playing":board.playing,"projectiles":board.state.projectiles.size(),"dialog":is_instance_valid(board.expedition_dialog) and board.expedition_dialog.visible}
func pickup(id: String, pos: Vector2, layer: String = "", guard: int = -1) -> Dictionary:
	return {"id":id,"item_id":"trail_ration","pos":pos,"layer":board.state.current_layer if layer=="" else layer,"count":1,"guard_site":guard}
func tap_pickup_case(id: String, target: Vector2, projection: String, context: bool = false):
	await sync_fixture()
	var before=interaction_state()
	var point: Vector2=board.interaction_rect.get_center() if context else board._world_to_screen(target)
	require(context or board.board_rect.has_point(point),"pickup tap inside battlefield "+id)
	await touch(point); await create_timer(0.8).timeout; await frames()
	var after=interaction_state()
	# A saved fixture/reload verifies item/belt persistence separately from touch.
	var save_path: String="user://independent-"+id+"-"+projection+".save"
	var saved: bool=board.state.save_run(save_path)
	var loaded=State.new(false); var reloaded: bool=loaded.load_run(save_path)
	var parity: bool=reloaded and loaded.world_pickups==board.state.world_pickups and loaded.consumable_slots==board.state.consumable_slots
	record(id,{"projection":projection,"input":"routed contextual TAKE" if context else "routed screen tap","tap_screen":str(point),"target_world":str(target),"world_scale":board.world_scale,"before":before,"after":after,"saved":saved,"reload_pickup_belt_parity":parity})
	if is_instance_valid(board.expedition_dialog): board.expedition_dialog.queue_free(); await frames()
func interactions():
	await setup(Vector2i(720,1280))
	for projection in ["top_down","isometric"]:
		for kind in ["generated_exploratory","generated_guarded_live","generated_guarded_cleared","generated_equipment_marker","generated_equipment_context","overlap_far_denial","selected_vs_collected","wrong_layer","full_belt","not_ready"]:
			await reset_fixture(projection,kind!="generated_guarded_live")
			var p: Vector2=board.state.player_pos
			var target: Vector2=p
			if kind.begins_with("generated_"):
				var id: String="b0_exploratory_ration" if kind=="generated_exploratory" else "b0_guarded_ration"
				if kind.begins_with("generated_equipment"):id="b0_guarded_equipment"
				for item in board.state.world_pickups:
					if item.id==id: target=item.pos
				board.state.player_pos=target
			else:
				board.state.world_pickups.clear()
				match kind:
					"overlap_far_denial":
						target=p+Vector2.RIGHT*100
						board.state._add_pickup(pickup("near_tapped",target))
						board.state._add_pickup(pickup("far_overlapping",p+Vector2.RIGHT*116))
					"selected_vs_collected":
						target=p+Vector2.RIGHT*80
						board.state._add_pickup(pickup("first_left",p+Vector2.LEFT*80))
						var other=pickup("second_tapped_right",target); other.item_id="firebomb"; board.state._add_pickup(other)
					"wrong_layer": board.state._add_pickup(pickup("other_layer",p,"other_surface"))
					"full_belt":
						board.state._add_pickup(pickup("full_test",p))
						board.state.consumable_slots.assign([{"id":"firebomb","count":2},{"id":"firebomb","count":2},{"id":"firebomb","count":2}])
					"not_ready":
						board.state._add_pickup(pickup("ready_test",p))
						board.state.player_action=board.state._action("wait",0.6,Vector2.ZERO)
			await tap_pickup_case(kind,target,projection,kind=="generated_equipment_context")
		for kind in ["merchant_safe_marker","merchant_safe_context","merchant_projectile_denied","merchant_enemy_denied","merchant_not_ready","merchant_distant"]:
			await reset_fixture(projection,false)
			board.state.player_pos=board.state.expedition_markers.merchant
			match kind:
				"merchant_projectile_denied": board.state._add_projectile({"pos":board.state.player_pos+Vector2(200,0),"vel":Vector2.RIGHT,"source_id":0,"radius":4.0,"damage":1,"kind":"arrow","layer":board.state.current_layer,"max_range":900.0})
				"merchant_enemy_denied":
					var enemy=board.state._make_enemy("archer",board.state.player_pos+Vector2(500,0),99999)
					board.state._add_enemy_actor(enemy)
				"merchant_not_ready": board.state.player_action=board.state._action("wait",0.6,Vector2.ZERO)
				"merchant_distant": board.state.player_pos+=Vector2.LEFT*160
			await sync_fixture()
			var before=interaction_state()
			var point: Vector2=board._world_to_screen(board.state.expedition_markers.merchant) if kind=="merchant_safe_marker" else board.interaction_rect.get_center()
			await touch(point); await create_timer(0.25).timeout; await frames()
			record(kind,{"projection":projection,"input":"routed screen tap marker" if kind=="merchant_safe_marker" else "routed screen tap contextual action","before":before,"after":interaction_state()})
			if is_instance_valid(board.expedition_dialog): board.expedition_dialog.queue_free(); await frames()
	await finish()
func run():
	if not OS.get_user_data_dir().contains(".runtime"): printerr("requires isolated runtime"); quit(2); return
	if not OS.get_cmdline_user_args().has("--interactions-only"):
		for dims in [Vector2i(390,844),Vector2i(720,1280),Vector2i(960,600)]:
			for xp in [0,6]: await character(dims,xp)
	await interactions()
	FileAccess.open("res://.runtime/phone-baseline-results.json",FileAccess.WRITE).store_string(JSON.stringify({"baseline":"0e65cdfae5b662a9a8951a8ff082ff54c639a7e1","rows":rows,"harness_errors":errors},"\t"))
	print("PROBE DONE ",rows.size()," records ",errors.size()," harness errors")
	quit(0 if errors.is_empty() else 2)
