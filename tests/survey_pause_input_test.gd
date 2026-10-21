extends SceneTree

var checks := 0
var failures: Array = []
var traces: Array = []
var board
var viewport: SubViewport

func _init() -> void:
	call_deferred("run")

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)
		printerr("FAILED: ",why)

func send(event: InputEvent) -> void:
	viewport.push_input(event,true)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code; event.physical_keycode=code; event.pressed=down
	send(event)

func trigger(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis=JOY_AXIS_TRIGGER_RIGHT; event.axis_value=value
	send(event)

func pointer(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point; event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
	send(event)

func tap(point: Vector2) -> void:
	pointer(point,true); pointer(point,false)

func settle() -> void:
	await process_frame; await process_frame

func advance(seconds: float) -> void:
	for frame in range(int(ceil(seconds/0.016667))): board._process(0.016667)

func trace(label: String) -> void:
	var s = board.state
	var record := {"label":label,"mode":s.mode_id,"behavior":s.lab_variant,"experiment":s.survey_experiment.duplicate(true),"weapon":s.player_weapon_frame,"time":s.simulation_time,"tick":s._simulation_tick_index,"kind":s.player_action.get("kind"),"phase":s.player_action.get("committed_phase",-1),"id":s.player_action.get("combo_instance_id",-1),"elapsed":s.player_action.get("elapsed"),"junction":s.lab_junction(),"terminal":s.player_action.get("terminal_recovery_locked",false),"hold":s.player_action.get("continue_held",false),"streaming":board.streaming_action,"playing":board.playing,"notice":s.lab_notice,"message":s.message}
	traces.append(record)
	print(JSON.stringify(record))

func choose(prefix: String) -> void:
	for entry in board.controller.menu_entries(board):
		var control = entry.get("control")
		if control is Button and control.text.begins_with(prefix):
			var scroll = board.survey_overlay.get_child(0)
			scroll.ensure_control_visible(control)
			await settle()
			tap(control.get_global_rect().get_center())
			await settle()
			return
	check(false,"setup control found: "+prefix)

func start(behavior: String, scenario: String, rules: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://waystone-expedition.save"))
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,800)
	root.add_child(viewport)
	board=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(board); board.set_process(false)
	await settle()
	check(not board.state.run_active,"fresh isolated entry")
	await settle()
	tap(Rect2(board.progression_rects["combat_survey"]).get_center())
	await settle()
	if not board.survey_overlay.visible:
		tap(board.start_rect.get_center()); await settle()
	check(board.survey_overlay.get_meta("kind","")=="experiment_setup","main Survey setup shown")
	board.seed_input.text="42"
	for i in range({"A":0,"B":1,"C":2}[behavior]): await choose("Behavior")
	if scenario=="F1-P":
		for i in range(3): await choose("Encounter")
	if rules=="recovery": await choose("Resource rules")
	await choose("PLAY SELECTED SURVEY")
	advance(0.1)
	check(board.state.lab_variant==behavior and board.state.combat_rules==rules,"effective selection "+behavior+" "+rules)
	check(board.state.survey_experiment.get("scenario")==scenario,"effective scenario "+scenario)
	trace("start")

func attack(route: String, down: bool) -> void:
	match route:
		"F": key(KEY_F,down)
		"RT": trigger(1.0 if down else 0.0)
		"button": pointer(board.continue_button.get_global_rect().get_center(),down)
		"enemy": pointer(board._world_to_screen(board.state.enemies[0]["pos"]),down)
		"Enter": key(KEY_ENTER,down)
		"touch_button", "touch_enemy":
			var event := InputEventScreenTouch.new()
			event.index=15; event.pressed=down
			event.position=board.continue_button.get_global_rect().get_center() if route=="touch_button" else board._world_to_screen(board.state.enemies[0]["pos"])
			send(event)

func junction(route: String = "F") -> void:
	await start("C","F1-P","energy")
	attack(route,true); advance(0.05); attack(route,false); advance(1.5)
	check(board.state.lab_junction(),"setup junction via "+route)

func run() -> void:
	if not OS.get_user_data_dir().contains(".runtime"):
		printerr("Requires isolated .runtime data"); quit(2); return
	for behavior in ["A","B","C"]:
		for rules in ["energy","recovery"]:
			for scenario in ["F1-P","generated"]:
				for route in (["F","RT","button","enemy"] if scenario=="F1-P" and behavior!="A" else ["F","RT"]):
					await start(behavior,scenario,rules)
					var label: String=behavior+" "+rules+" "+scenario+" "+route
					attack(route,true); advance(0.05); attack(route,false)
					trace(label+" release")
					advance(1.5)
					trace(label+" after wait")
					if behavior=="A":
						check(not board.state.combat_lab and board.state.is_player_ready(),label+" Existing release completes recovery")
						attack(route,true); advance(0.05); attack(route,false)
						check(board.state.player_action.get("committed_phase",-1)==0 and board.state.player_action.get("combo_instance_id",0)==2,label+" Existing restarts cut 1")
					else:
						var id: int=board.state.player_action.get("combo_instance_id",-1)
						check(board.state.lab_junction(),label+" release freezes cut 1")
						var tick: int=board.state._simulation_tick_index
						advance(5.0)
						check(board.state._simulation_tick_index==tick,label+" five seconds deliberation frozen")
						attack(route,true); advance(0.05); attack(route,false); advance(1.5)
						trace(label+" second attack")
						check(board.state.lab_junction() and board.state.player_action.get("committed_phase",-1)==1 and board.state.player_action.get("combo_instance_id",-2)==id,label+" same action reaches cut 2")
						attack(route,true); advance(0.05); attack(route,false)
						trace(label+" third attack")
						check(board.state.player_action.get("committed_phase",-1)==2 and board.state.player_action.get("combo_instance_id",-2)==id,label+" same action reaches cut 3")
					viewport.queue_free(); await settle()
	# Sustained input is tested separately from quick taps. All phase progression
	# and time is driven by the normal board frame loop, never direct combat calls.
	for route in ["F","RT","button"]:
		await start("C","F1-P","energy")
		attack(route,true); advance(1.3)
		check(board.state.player_action.get("committed_phase",-1)==2 and not board.state.lab_junction(),route+" hold runs through cut 3")
		attack(route,false); advance(0.2)
		trace(route+" held chain")
		viewport.queue_free(); await settle()
	for route in ["touch_button","touch_enemy"]:
		await junction(route)
		var id: int=board.state.player_action.get("combo_instance_id",-1)
		attack(route,true); advance(0.05); attack(route,false); advance(1.5)
		check(board.state.lab_junction() and board.state.player_action.get("committed_phase",-1)==1 and board.state.player_action.get("combo_instance_id",-2)==id,route+" continues cut 2")
		trace(route+" cut 2")
		viewport.queue_free(); await settle()
	await junction()
	key(KEY_ENTER,true); advance(0.05); key(KEY_ENTER,false); advance(1.5)
	check(board.state.lab_junction() and board.state.player_action.get("committed_phase",-1)==1,"Enter remains a one-cut token")
	viewport.queue_free(); await settle()
	await junction()
	attack("F",true); advance(0.65)
	check(board.state.player_action.get("combo_instance_id",-1)==1 and board.state.player_action.get("committed_phase",-1)==2 and not board.state.lab_junction(),"F held from junction flows through remaining cuts")
	attack("F",false)
	check(not board.state.player_action.get("continue_held",true),"F release after renewed hold clears continuation")
	trace("F held from junction")
	viewport.queue_free(); await settle()
	# Trigger hysteresis uses the same routed axis events as the player's RT.
	await start("C","F1-P","energy")
	trigger(0.60); advance(0.1); trigger(0.30); advance(0.1)
	check(board.state.player_action.get("continue_held",false),"RT 0.30 retains hold")
	trigger(0.24); advance(1.5)
	check(board.state.lab_junction(),"RT 0.24 releases to junction")
	trigger(0.54); advance(0.1)
	check(board.state.lab_junction(),"RT below press threshold does not continue")
	trigger(0.56); advance(0.05); trigger(0.0); advance(1.5)
	check(board.state.lab_junction() and board.state.player_action.get("committed_phase",-1)==1,"RT fresh press advances one cut")
	viewport.queue_free(); await settle()
	for exit_key in [KEY_J,KEY_D,KEY_SHIFT]:
		await junction()
		var position: Vector2=board.state.player_pos
		key(exit_key,true)
		check(not board.state.lab_junction() and board.state.player_action.get("terminal_recovery_locked",false),"exit locks recovery "+str(exit_key))
		if exit_key!=KEY_J:
			check(board.state.player_action.has("lab_exit_request") and board.state.player_pos==position,"move/dodge queued behind debt "+str(exit_key))
		key(exit_key,false); advance(0.1)
		check(board.state.player_pos==position,"exit cannot move before recovery paid "+str(exit_key))
		advance(1.0)
		check(board.state.is_player_ready(),"exit finishes obligation "+str(exit_key))
		if exit_key!=KEY_J: check(board.state.player_pos.distance_to(position)>1,"queued exit executes "+str(exit_key))
		trace("exit "+str(exit_key))
		viewport.queue_free(); await settle()
	await junction()
	key(KEY_ESCAPE,true); key(KEY_ESCAPE,false); advance(0.1)
	check(board.suspended and board.state.is_player_ready(),"menu deliberately pays cut exit")
	await settle() # Native menu metrics settle through Container layout before hit testing.
	# The full menu now owns Resume; use its visible command rather than the HUD
	# shortcut covered by the modal.
	tap(board.next_page.get_parent().get_child(3).get_global_rect().get_center()); advance(0.1)
	check(not board.suspended and not board.state.lab_neutral_required,"Resume releases neutral gate")
	attack("F",true); advance(0.05); attack("F",false)
	check(board.state.player_action.get("combo_instance_id",-1)==2 and board.state.player_action.get("committed_phase",-1)==0,"fresh post-menu attack begins a new sequence")
	trace("menu resume fresh attack")
	viewport.queue_free(); await settle()
	var output := FileAccess.open("user://survey-pause-input.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"traces":traces},"\t"))
	print("SURVEY PAUSE INPUT: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
