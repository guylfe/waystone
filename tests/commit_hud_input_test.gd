extends "res://tests/commit_shot_input_test.gd"
# Actual-root routed HUD regression. Ink uses real fonts; no GPU/device claim.
func ink(text:String,baseline:Vector2,font:int,width:float)->Rect2:
	var f=ThemeDB.fallback_font
	return Rect2(baseline-Vector2(0,f.get_ascent(font)),Vector2(minf(width,f.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font).x),f.get_height(font)))
func surface(label:String,explicit_unit:float=0.0):
	var h:Dictionary=board.CommitHudLayout.build(board,explicit_unit) if explicit_unit>0 else board._sync_commit_hud()
	var u:float=h.unit;var r:Rect2=h.commit
	var regions:Dictionary={"commit":r,"xp":h.xp,"log":h.log}
	if board.state.uses_energy_rules():regions.attack=h.attack
	if board.controller.active:regions.panel=h.targeting if board.controller.targeting_action!="" else h.idle
	for id in regions:
		check(board.board_rect.encloses(regions[id]),"HUD safe "+label+id)
		for other in regions:
			if str(id)<str(other):check(not Rect2(regions[id]).intersects(regions[other]),"regions disjoint "+label+id+"/"+other)
	check(r.size.x>=156*u-0.1 and r.size.y>=64*u-0.1,"readable target retained")
	var obstacles=board.buttons.duplicate();obstacles.merge(board.consumable_rects)
	for name in ["interaction_rect","sheet_button_rect","view_rect","map_rect","reset_rect","survey_end_rect"]:obstacles[name]=board.get(name)
	for name in obstacles:
		for id in regions:check(not Rect2(obstacles[name]).intersects(regions[id]),"fixed control clear "+label+name+"/"+id)
	var title=ink("COMMIT SHOT",r.position+Vector2((r.size.x-ThemeDB.fallback_font.get_string_size("COMMIT SHOT",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(17*u)).x)/2,25*u),roundi(17*u),r.size.x)
	var subtitle:String="FULL SHOT COMMITTED" if board.state.player_action.get("commit_shot",false) and board.state.player_action.kind in ["bow_draw","bow_release"] else "CHOOSE ENEMY" if board.selected_action=="commit_shot" else "+25% damage · LB+A" if board.controller.active else "+25% damage · [G]" if board.desktop_controls else "+25% full-shot damage"
	var sub=ink(subtitle,r.position+Vector2((r.size.x-ThemeDB.fallback_font.get_string_size(subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(12*u)).x)/2,49*u),roundi(12*u),r.size.x)
	check(r.encloses(title) and r.encloses(sub),"actual shaped title/subtitle stays in control")
	check(not title.intersects(sub),"title and subtitle ink separate")
	var xp_ink:Rect2=Rect2(h.xp.position,h.xp_paragraph.get_size())
	var log_ink:Rect2=Rect2(h.log.position,h.log_paragraph.get_size())
	check(h.xp.encloses(xp_ink) and h.log.encloses(log_ink),"complete XP/log paragraph allocated, no two-line cut")
	check(not xp_ink.intersects(sub) and not log_ink.intersects(sub),"actual shaped XP/log ink clears subtitle")
	if regions.has("panel"):
		var panel:Rect2=regions.panel
		if board.controller.targeting_action!="":
			var title_rect=Rect2(panel.position+Vector2(8,8)*u,h.title_paragraph.get_size())
			check(panel.encloses(title_rect),"target panel shaped title fits")
			var y:float=panel.position.y+16*u+h.title_paragraph.get_size().y+26*u
			for i in 3:
				var hint=Rect2(Vector2(panel.position.x+8*u+i*(h.hint_column+8*u),y),h.hint_paragraphs[i].get_size())
				check(panel.encloses(hint) and not hint.intersects(title_rect),"target hint wraps within panel")
		else:check(panel.encloses(Rect2(panel.position+Vector2(48,8)*u,h.idle_paragraph.get_size())),"idle pad text wraps within panel")
	if explicit_unit==0:
		check(board.commit_shot_rect==h.commit and board.attack_rect==h.attack,"drawing and actual input share allocation")
		if board.controller.targeting_action=="commit_shot" and not board.controller.locked_target(board).is_empty():
			var point:Vector2=target_point()
			var marker:=Rect2(point-Vector2.ONE*24*u,Vector2.ONE*48*u)
			for id in regions:check(not marker.intersects(regions[id]),"ordinary inert-target marker remains clear "+label+id)
	records.append({"label":label,"root":str(root.size),"transform":str(root.get_final_transform()),"logical":str(board.size),"unit":u,"explicit_density_model":explicit_unit>0,"rules":board.state.combat_rules,"projection":board.view_mode,"desktop":board.desktop_controls,"pad":board.controller.active,"regions":str(regions),"title_ink":str(title),"subtitle_ink":str(sub),"xp_ink":str(xp_ink),"log_ink":str(log_ink),"message":board.state.message,"log_lines":h.log_paragraph.get_line_count()})
func cancel(route:String):
	if route=="touch":await tap(board.commit_shot_rect.get_center())
	elif route=="keyboard":await keytap(KEY_G)
	else:await pad(JOY_BUTTON_B)
func hud_journey(route:String,rules:String,projection:String,dims:Vector2i,inset:bool=false):
	await setup(rules,projection,dims)
	board.desktop_controls=route!="touch"
	if inset:
		board.layout_safe_area_override=Rect2(board.size*0.025,board.size*0.95);board._layout();await frames(10)
	if route=="pad":await pad(JOY_BUTTON_RIGHT_STICK)
	var s=board.state;var time=s.simulation_time;var spent=s.energy_spent_total
	await surface(route+" idle")
	await select(route);await surface(route+" selected")
	check(s.message.begins_with("Commit Shot selected:"),"context entry keeps C1 selection hint")
	var armed_rect:Rect2=board.commit_shot_rect
	await cancel(route);await frames(60);await surface(route+" cancelled settled")
	check(board.selected_action=="" and board.controller.targeting_action=="" and s.message=="Commit Shot selection cancelled.","truthful settled cancellation "+route)
	check(s.simulation_time==time and s.energy_spent_total==spent and s.survey_shots_fired==0 and not board.playing,"cancel free frozen and no shot/queue")
	await select(route)
	if route=="touch":await tap(board._world_to_screen(s.player_pos+Vector2(130,40)))
	elif route=="keyboard":await keytap(KEY_ENTER)
	else:await pad(JOY_BUTTON_RIGHT_STICK);await pad(JOY_BUTTON_A)
	check(board.selected_action=="commit_shot" and not board.playing,"invalid target remains uncommitted")
	await surface(route+" refused")
	check(armed_rect==board.commit_shot_rect,"normal selection/refusal/cancel retain stable action target")
	if route=="pad":await pad(JOY_BUTTON_RIGHT_STICK)
	await confirm(route);check(s.player_action.get("commit_shot",false),"fresh confirmation after cancel succeeds")
	await surface(route+" committed");await ready()
	check(s.survey_shots_fired==1 and is_equal_approx(s.energy_spent_total-spent,s.energy_cost(18) if rules=="energy" else 0),"one shot/ordinary full debit after fresh confirm")
	await finish()
func exits():
	for kind in ["B-resize","Escape","G-hybrid","Start","focus","disconnect","keyboard-handover"]:
		await setup("energy","top_down",Vector2i(390,844));await select("pad")
		var s=board.state;var time=s.simulation_time;var spent=s.energy_spent_total
		if kind=="B-resize":root.size=Vector2i(840,720);await frames(18);await pad(JOY_BUTTON_B)
		elif kind=="Escape":await keytap(KEY_ESCAPE)
		elif kind=="G-hybrid":await keytap(KEY_G)
		elif kind=="Start":await pad(JOY_BUTTON_START)
		elif kind=="focus":board.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		elif kind=="disconnect":Input.joy_connection_changed.emit(0,false)
		else:
			# A fresh unrelated key switches input and discards the armed pad selection.
			await keytap(KEY_SHIFT)
		await frames(60)
		check(board.selected_action=="" and board.controller.targeting_action=="" and not s.message.begins_with("Commit Shot selected:"),"exit cancels guidance "+kind)
		check(s.simulation_time==time and s.energy_spent_total==spent and s.survey_shots_fired==0,"exit no time/cost/shot "+kind)
		records.append({"exit":kind,"message":s.message,"selection":board.selected_action,"targeting":board.controller.targeting_action})
		await finish()
func resize_states():
	await setup("recovery","isometric",Vector2i(390,844));board.desktop_controls=false
	await surface("resize idle portrait");await select("touch")
	root.size=Vector2i(840,720);await frames(18);await surface("resize selected wide")
	await tap(board._world_to_screen(board.state.player_pos+Vector2(130,40)))
	root.size=Vector2i(720,480);await frames(18);await surface("resize refused short")
	await cancel("touch");await frames(60)
	root.size=Vector2i(390,844);await frames(18);await surface("resize cancelled portrait")
	check(board.state.message=="Commit Shot selection cancelled." and board.state.simulation_time==0,"resize cancellation stays truthful/frozen")
	await select("touch");await confirm("touch")
	root.size=Vector2i(840,720);await frames(18);await surface("resize committed wide")
	await ready();check(board.state.survey_shots_fired==1 and board.state.energy_spent_total==0,"resize serves exactly one paid obligation under Recovery")
	await finish()
func other_targeting():
	await setup("energy","top_down",Vector2i(390,844))
	board.state.expedition.discipline="sapper";board.state.track_ranks.adopted=1 # labelled legal adopted-action fixture
	await joy(JOY_BUTTON_LEFT_SHOULDER,true);await pad(JOY_BUTTON_DPAD_UP);await joy(JOY_BUTTON_LEFT_SHOULDER,false)
	check(board.controller.targeting_action=="adopted","existing Sapper placement route retained")
	await surface("other Sharpshooter contextual placement")
	var h:Dictionary=board._sync_commit_hud()
	check(h.hint_keys[0]=="rs","other placement retains marker hint")
	await pad(JOY_BUTTON_B);check(board.controller.targeting_action=="" and board.state.simulation_time==0,"other targeting cancels freely")
	await finish()
func run():
	for dims in [Vector2i(390,844),Vector2i(720,480),Vector2i(840,720)]:
		for rules in ["energy","recovery"]:
			for projection in ["top_down","isometric"]:
				for route in ["touch","keyboard","pad"]:await hud_journey(route,rules,projection,dims)
	await hud_journey("pad","recovery","isometric",Vector2i(390,844),true)
	await exits();await resize_states();await other_targeting()
	# Explicit density formulas share the production allocator but do not spoof DPI.
	await setup("energy","isometric",Vector2i(780,1688));await select("pad")
	board.layout_safe_area_override=Rect2(board.size*0.025,board.size*0.95);board._layout();await frames(12)
	var t=root.get_final_transform()
	for density in [1.0,2.0,3.0]:await surface("analytical density "+str(density),density/minf(t.x.length(),t.y.length()))
	await finish()
	FileAccess.open("user://commit-hud-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"method":"actual-root normal processing routed events and independent ink/overlap checks; explicit density formulas separate; no GPU/native/phone"},"\t"))
	print("COMMIT HUD INPUT ",checks," checks / ",records.size()," records / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
