extends "res://tests/commit_hud_input_test.gd"
# Normal root, routed inputs, actual cached draw paragraphs and target samples.
# Fixtures/density formulas are analytical; no GPU or Android execution.
func drawn(stage:String):
	var text:String=board._hud_log_text()
	var h:Dictionary=board._sync_commit_hud()
	var expected=board.CommitHudLayout.paragraph(board.state.message,h.log.size.x,h.font)
	check(text==board.state.message,"current drawn message "+stage)
	check(board.commit_hud_key.contains(board.state.message),"cache consumes current message "+stage)
	check(h.log_paragraph.get_line_count()==expected.get_line_count(),"draw paragraph lines "+stage)
	var glyphs:Array=[]
	for i in mini(h.log_paragraph.get_line_count(),expected.get_line_count()):
		var actual=TextServerManager.get_primary_interface().shaped_text_get_glyphs(h.log_paragraph.get_line_rid(i))
		var oracle=TextServerManager.get_primary_interface().shaped_text_get_glyphs(expected.get_line_rid(i))
		check(actual==oracle,"actual cached draw glyphs "+stage+str(i));glyphs.append(hash(actual))
	check(h.log.encloses(Rect2(h.log.position,h.log_paragraph.get_size())),"whole drawn log fits "+stage)
	records.append({"stage":stage,"message":board.state.message,"draw_text":text,"snapshot":board.visual.get("message",""),"glyph_hashes":glyphs,"log":str(h.log),"time":board.state.simulation_time,"spent":board.state.energy_spent_total})
func feedback(route:String,rules:String):
	await setup(rules,"top_down",Vector2i(390,844));board.desktop_controls=route!="touch"
	var s=board.state;var snapshot:Dictionary=board.visual.duplicate(true)
	await select(route);await frames(60);drawn(route+rules+" selected60")
	check(board.visual==snapshot,"free feedback does not mutate frozen snapshot")
	if route=="touch":await tap(board._world_to_screen(s.player_pos+Vector2(130,40)))
	elif route=="keyboard":await keytap(KEY_ENTER)
	else:await pad(JOY_BUTTON_RIGHT_STICK);await pad(JOY_BUTTON_A)
	await frames(60);drawn(route+rules+" refusal60")
	check(board.selected_action=="commit_shot" and not board.playing,"routed invalid target refused")
	var r:Rect2=board.commit_shot_rect
	await cancel(route);await frames(60);drawn(route+rules+" cancelled60")
	check(s.message=="Commit Shot selection cancelled." and s.simulation_time==0 and s.energy_spent_total==0 and s.survey_shots_fired==0,"settled cancellation free/frozen/no shot")
	check(board.visual==snapshot,"refusal/cancel preserve historical snapshot")
	root.size=Vector2i(840,720);await frames(18);drawn(route+rules+" resized cancelled")
	root.size=Vector2i(390,844);await frames(18);await select(route);drawn(route+rules+" fresh selection")
	check(board.commit_shot_rect==r,"free transitions/resize retain target")
	await confirm(route)
	check(s.player_action.get("commit_shot",false),"routed commitment accepted")
	check(board._hud_log_text()==String(board.visual.message),"streamed draw uses displayed frame message")
	await ready();drawn(route+rules+" completed")
	check(s.survey_shots_fired==1 and is_equal_approx(s.energy_spent_total,s.energy_cost(18) if rules=="energy" else 0),"exactly one ordinary full price/shot")
	await finish()
func playback():
	await setup("energy","top_down",Vector2i(390,844))
	var s=board.state
	# Real precomputation produces displayed frames before the final state.
	check(s.request_wait(0.8),"precomputed ordinary wait")
	board._commit(true)
	var frozen=board.timeline.duplicate(true)
	var displayed:String=board.visual.message
	s.message="Synthetic later live state: must not leak into playback."
	check(board.playing and board._hud_log_text()==displayed and board._hud_log_text()!=s.message,"precomputed future message never shown")
	board._sync_commit_hud();check(board.timeline==frozen,"draw cache does not mutate playback history")
	await frames(3)
	check(board.playing and board._hud_log_text()==String(board.visual.message),"interpolated playback owns displayed message")
	await ready();drawn("precomputed settled live message")
	# Real streamed action: future/live sentinel must not replace a captured frame.
	check(s.request_wait(0.5,false),"streamed ordinary wait")
	board._begin_streamed_action(true);var captured=board.visual.duplicate(true)
	s.message="Synthetic uncaptured state: must not leak into streamed frame."
	check(board._hud_log_text()==String(captured.message),"streamed consumer keeps captured message")
	board._sync_commit_hud();check(board.visual==captured,"consumer never edits stream frame")
	await ready();await finish()
func target_samples(label:String,h:Dictionary,point:Vector2):
	var u:float=h.unit;var regions:Array=[h.commit,h.attack,h.xp,h.log,h.targeting if board.controller.targeting_action!="" else h.idle]
	var selected:bool=board.selected_action=="commit_shot"
	var radius:float=24*u if selected else 14.0 # Actual selected / ordinary pad arc.
	for index in regions.size():
		var covered=0
		for i in 32:
			if Rect2(regions[index]).has_point(point+Vector2.RIGHT.rotated(TAU*i/32)*radius):covered+=1
		var cross=0
		for p in ([point,point-Vector2(17,0),point+Vector2(17,0),point-Vector2(0,17),point+Vector2(0,17)] if selected else [point]):
			if Rect2(regions[index]).has_point(p):cross+=1
		check(covered==0 and cross==0,"actual ring/crosshair clear "+label+str(index))
		records.append({"target":label,"unit":u,"region":str(regions[index]),"center":str(point),"radius":radius,"ring_covered":covered,"crosshair_covered":cross})
func density_targets():
	for projection in ["isometric","top_down"]:
		for rules in ["energy","recovery"]:
			await setup(rules,projection,Vector2i(780,1688));await pad(JOY_BUTTON_RIGHT_STICK)
			board.layout_safe_area_override=Rect2(board.size*0.025,board.size*0.95);board._layout();await frames(12)
			var t=root.get_final_transform()
			for stage in ["idle","selected","refused","cancelled","committed"]:
				if stage=="selected":await select("pad")
				elif stage=="refused":await pad(JOY_BUTTON_RIGHT_STICK);await pad(JOY_BUTTON_A)
				elif stage=="cancelled":await pad(JOY_BUTTON_B);await frames(60)
				elif stage=="committed":await select("pad");await confirm("pad")
				for density in [1.0,2.0,3.0]:
					var u=density/minf(t.x.length(),t.y.length())
					var label="explicit density "+str(density)+projection+rules+stage
					await surface(label,u)
					var h:Dictionary=board.CommitHudLayout.build(board,u)
					for offset in [Vector2.ZERO,Vector2(-65,0),Vector2(65,0),Vector2(0,-65),Vector2(0,65)]:
						if board.selected_action!="commit_shot" and offset!=Vector2.ZERO:continue
						# Adjacent ordinary geometry around the original 210-above fixture.
						target_samples(label+str(offset),h,board._world_to_screen(Vector2(board.state.enemies[0].pos)+offset))
			await ready();check(board.state.survey_shots_fired==1,"density states preserve one commitment")
			await finish()
func run():
	if DisplayServer.get_name()!="headless" or not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for route in ["touch","keyboard","pad"]:
		for rules in ["energy","recovery"]:await feedback(route,rules)
	await playback();await density_targets()
	FileAccess.open("user://feedback-target-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("FEEDBACK TARGET INPUT ",checks," checks / ",records.size()," records / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
