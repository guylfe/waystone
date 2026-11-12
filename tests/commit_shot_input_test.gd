extends SceneTree
# Main root, normal menus, transformed ScreenTouch, Key and synthetic Joypad events.
# Inert target/open geography and extra crowns/HP are isolated labelled fixtures.
var board
var checks=0
var failures=[]
var records=[]
func _init():call_deferred("run")
func check(ok:bool,why:String):
	checks+=1
	if not ok:failures.append(why);printerr("FAILED: ",why)
func frames(n:int=6):
	for i in n:await process_frame
func send(e:InputEvent):Input.parse_input_event(e.xformed_by(root.get_final_transform()))
func touch(p:Vector2,down:bool):
	var e=InputEventScreenTouch.new();e.position=p;e.index=31;e.pressed=down;send(e);await frames(2)
func tap(p:Vector2):await touch(p,true);await touch(p,false);await frames()
func key(code:int,down:bool):
	var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;send(e);await frames(2)
func keytap(code:int):await key(code,true);await key(code,false);await frames()
func joy(code:int,down:bool):
	var e=InputEventJoypadButton.new();e.button_index=code;e.pressed=down;e.device=0;send(e);await frames(2)
func pad(code:int):await joy(code,true);await joy(code,false);await frames()
func trigger(value:float):
	var e=InputEventJoypadMotion.new();e.axis=JOY_AXIS_TRIGGER_RIGHT;e.axis_value=value;e.device=0;send(e);await frames(2)
func ready():
	for i in 1200:
		if not board.playing and board.state.is_player_ready():return
		await frames(1)
	check(false,"normal automatic action processing returns ready")
func setup(rules:String,projection:String,dims:Vector2i=Vector2i(720,1280),loadout:String="rogue_sharpshooter"):
	root.size=dims
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	board=load("res://scenes/main.tscn").instantiate();root.add_child(board);await frames(16)
	var mode="expedition" if rules=="energy" else "boss_lab"
	await tap(board.progression_rects[mode].get_center());await tap(board._setup_class_rect(loadout).get_center())
	if board.combat_rule_rects.has(rules):await tap(board.combat_rule_rects[rules].get_center())
	board.seed_input.text="42";await tap(board.start_rect.get_center());await frames(14)
	check(board.state.run_active and board.state.loadout_id==loadout and board.state.combat_rules==rules,"routed actual main-root setup "+mode+loadout+rules)
	var s=board.state;board.view_mode=projection;s.player_pos=Vector2(900,800);s.world_size=Vector2(2400,1700)
	s.walls.clear();s.barriers.clear();s.hazards.clear();s.projectiles.clear();s.world_pickups.clear();s.waystones.clear();s.terrain_features.clear();s._build_wall_spatial_index()
	s.floor_shapes.assign([{"kind":"rect","rect":Rect2(100,100,2200,1500),"layer":s.current_layer,"part_id":0}]);s._loaded_floor_shapes.assign(s.floor_shapes);s._build_shape_spatial_index()
	var target=s._make_enemy("blade",s.player_pos+Vector2(0,-210),10000)
	target.layer=s.current_layer;target.awareness="alerted";target.revealed_to_player=true;target.facing=Vector2.DOWN;target.last_known_player=s.player_pos;target.action=s._action("wait",1000,Vector2.DOWN)
	target.properties.hit_reaction_policy="posture_only";target.posture=10000;target.posture_max=10000;s._replace_enemy_actors([target]);s._update_exploration(true)
	board.visual=board._presentation_snapshot();board._layout();await frames(12)
	check(board.board_rect.has_point(target_point()),"target lies inside normal battlefield")
func target_point()->Vector2:return board._world_to_screen(Vector2(board.state.enemies[0].pos))
func finish():board.queue_free();await frames(8)
func select(route:String):
	if route=="touch":await tap(board.commit_shot_rect.get_center())
	elif route=="keyboard":await keytap(KEY_G)
	else:
		await joy(JOY_BUTTON_LEFT_SHOULDER,true);await pad(JOY_BUTTON_A if board.state.player_weapon_frame=="bow" else JOY_BUTTON_LEFT_STICK);await joy(JOY_BUTTON_LEFT_SHOULDER,false);await frames()
func confirm(route:String):
	if route=="touch":await tap(target_point())
	elif route=="keyboard":
		await keytap(KEY_TAB);await keytap(KEY_ENTER)
	else:await pad(JOY_BUTTON_A)
func journey(route:String,rules:String,projection:String):
	await setup(rules,projection)
	var s=board.state;var pos=s.player_pos;var time=s.simulation_time;var spent=s.energy_spent_total
	var u=board.MenuMetrics.unit(board)
	check(board.commit_shot_rect.size.x>=48*u and board.commit_shot_rect.size.y>=48*u,"measured Commit Shot target minimum")
	check(board.board_rect.encloses(board.commit_shot_rect),"Commit Shot lies inside available battlefield")
	check(not board.commit_shot_rect.intersects(board.attack_rect),"separate action never overlaps ordinary Attack")
	await select(route)
	check(board.selected_action=="commit_shot","routed selection arms "+route)
	check(s.simulation_time==time and s.energy_spent_total==spent and s.player_pos==pos,"selection is free and stationary "+route)
	if route=="touch":
		await tap(board.commit_shot_rect.get_center());check(board.selected_action=="","second selection cancels")
		await select(route);await tap(board._world_to_screen(s.player_pos+Vector2(130,40)))
		check(s.simulation_time==time and s.energy_spent_total==spent and board.selected_action=="commit_shot","empty target neither moves nor shoots")
	elif route=="keyboard":
		await keytap(KEY_G);check(board.selected_action=="","keyboard toggles selection off");await select(route)
	else:
		await pad(JOY_BUTTON_B);check(board.selected_action=="" and board.controller.targeting_action=="","controller cancel is free");await select(route)
	await confirm(route)
	check(s.player_action.get("commit_shot",false) and s.player_action.kind=="bow_draw","routed enemy confirm commits once "+route)
	check(board.selected_action=="","selection consumed only on successful commitment")
	check(is_equal_approx(s.energy_spent_total-spent,s.energy_cost(18) if rules=="energy" else 0.0),"routed one full price up front "+route)
	check(s.survey_shots_fired==0,"press and release cannot fire early")
	# Unrelated map/Character requests and fresh ordinary attack edges cannot cancel
	# the prepaid shot, shorten its draw or queue another shot during commitment.
	await keytap(KEY_M);await keytap(KEY_C);await keytap(KEY_F)
	check(s.player_action.get("commit_shot",false) and s.survey_shots_fired==0,"map/Character request cannot cancel or shorten commitment")
	await ready()
	check(s.survey_shots_fired==1,"automatic full shot exactly once "+route)
	check(is_equal_approx(s.energy_spent_total-spent,s.energy_cost(18) if rules=="energy" else 0.0),"no release/recovery second debit")
	var end=s.simulation_time;await frames(30)
	check(s.simulation_time==end and s.survey_shots_fired==1,"fresh select/confirm required for another shot")
	records.append({"route":route,"rules":rules,"mode":s.mode_id,"projection":projection,"root":str(root.size),"transform":str(root.get_final_transform()),"logical":str(board.size),"unit":u,"rect":str(board.commit_shot_rect),"world_time":end-time,"shots":s.survey_shots_fired,"spent":s.energy_spent_total-spent,"fixture":"inert visible high-HP target, synthetic clear floor; Energy uses normal Expedition startup, Recovery uses normal Boss Lab startup (Expedition remains Energy-only)"})
	await finish()
func lifecycle(kind:String,rules:String):
	await setup(rules,"isometric")
	if kind=="disconnect":await pad(JOY_BUTTON_RIGHT_STICK)
	await select("touch");await confirm("touch")
	var s=board.state
	if kind=="menu":await pad(JOY_BUTTON_START)
	elif kind=="focus":board.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	else:Input.joy_connection_changed.emit(0,false)
	await ready();check(s.survey_shots_fired==1,"full paid obligation survives "+kind+rules)
	check(is_equal_approx(s.energy_spent_total,s.energy_cost(18) if rules=="energy" else 0.0),"lifecycle no discount or second debit "+kind)
	var time=s.simulation_time;await frames(24);check(s.simulation_time==time and s.survey_shots_fired==1,"lifecycle no queued attack "+kind)
	records.append({"lifecycle":kind,"rules":rules,"shots":s.survey_shots_fired,"time":time,"paused":board.controller.paused,"fixture":"synthetic app-focus/joy-disconnect notification; no host/device action"})
	await finish()
func ordinary_controls(rules:String):
	for route in ["keyboard","touch","pad"]:
		await setup(rules,"top_down")
		var s=board.state
		if route=="keyboard":await key(KEY_F,true)
		elif route=="touch":await touch(target_point(),true);await create_timer(0.20).timeout
		else:await trigger(1.0)
		check(s.player_action.kind=="bow_draw" and s.player_action.get("automatic_draw",false),"ordinary fixed draw begins "+route)
		if route=="keyboard":await key(KEY_F,false)
		elif route=="touch":await touch(target_point(),false)
		else:await trigger(0.0)
		check(s.player_action.kind=="bow_draw","release cannot fire early "+route)
		await ready()
		check(s.survey_shots_fired==1,"ordinary automatic release once "+route)
		check(s.simulation_time>0.45 and s.simulation_time<1.6,"bounded ordinary draw plus recovery "+route)
		await finish()
func manual_aim(rules:String):
	await setup(rules,"isometric")
	await select("touch");await confirm("touch")
	var s=board.state;var before=Vector2(s.player_action.aim_direction)
	var point=board._world_to_screen(s.player_pos)
	await touch(point,true)
	var drag=InputEventScreenDrag.new();drag.index=31;drag.position=board._world_to_screen(s.player_pos+Vector2(200,0));drag.relative=drag.position-point;send(drag);await frames(2)
	var angle=absf(before.angle_to(s.player_action.aim_direction))
	check(is_zero_approx(angle),"touch drag cannot steer committed Bow "+rules)
	await touch(drag.position,false)
	check(s.player_action.kind=="bow_draw" and s.survey_shots_fired==0,"aim finger release cannot trigger early shot")
	await ready();check(s.survey_shots_fired==1,"manually led commitment still completes one full shot")
	records.append({"manual_aim":rules,"turn_radians":angle,"shots":s.survey_shots_fired,"route":"new root ScreenTouch and one ScreenDrag during committed draw"})
	await finish()
func hybrid_target(rules:String):
	await setup(rules,"top_down")
	await select("pad");await keytap(KEY_ESCAPE)
	check(board.controller.targeting_action=="" and board.selected_action=="" and board.state.simulation_time==0,"keyboard Escape cancels pad selection without a stranded modal")
	await select("pad");await keytap(KEY_TAB);await keytap(KEY_ENTER)
	check(board.controller.targeting_action=="commit_shot" and board.state.simulation_time==0,"no-target hybrid confirm retains selection and does not spend")
	await keytap(KEY_TAB);await keytap(KEY_ENTER);await ready()
	check(board.state.survey_shots_fired==1 and board.controller.targeting_action=="","keyboard may confirm a pad-selected visible target exactly once")
	records.append({"hybrid_target":rules,"shots":board.state.survey_shots_fired,"routes":["LB+A","keyboard Escape","LB+A","Tab to no-target","Enter refuse","Tab to visible enemy","Enter commit"]})
	await finish()
func economy_input(rules:String):
	for amount in [0.0,1.0]:
		await setup(rules,"isometric")
		var s=board.state;s.player_energy=amount # Labelled resource fixture, ordinary input/action owners.
		var time=s.simulation_time;var spent=s.energy_spent_total
		await select("touch");check(s.simulation_time==time and s.energy_spent_total==spent,"low/zero resource selection remains free")
		await confirm("touch")
		var legal=rules=="recovery" or amount>0
		if legal:
			check(s.player_action.get("commit_shot",false),"ordinary allowed overdraw/inactive-resource route commits")
			await ready();check(s.survey_shots_fired==1,"low resource route still fires exactly one prepaid full shot")
			check(is_equal_approx(s.energy_spent_total-spent,s.energy_cost(18) if rules=="energy" else 0),"low resource route charges once through ordinary owner")
		else:
			check(s.simulation_time==time and s.energy_spent_total==spent and s.survey_shots_fired==0,"ordinary zero-energy physical lock refuses without time/spend")
			check(board.selected_action=="commit_shot" and s.message.contains("exhausted"),"zero-resource refusal retains selection with reason")
		records.append({"resource_fixture":amount,"rules":rules,"shots":s.survey_shots_fired,"spent":s.energy_spent_total-spent,"legal":legal,"world_time":s.simulation_time})
		await finish()
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	if OS.get_environment("WAYSTONE_CHECK_CASE")=="ordinary":
		await ordinary_controls("energy")
		print("ORDINARY DEBUG ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1);return
	for rules in ["energy","recovery"]:
		for projection in ["top_down","isometric"]:
			for route in ["touch","keyboard","pad"]:await journey(route,rules,projection)
		for kind in ["menu","focus","disconnect"]:await lifecycle(kind,rules)
		await ordinary_controls(rules)
		await manual_aim(rules)
		await hybrid_target(rules)
		await economy_input(rules)
	FileAccess.open("user://commit-shot-input-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("COMMIT SHOT ROOT INPUT ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
