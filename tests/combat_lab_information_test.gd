extends "res://tests/combat_lab_touch_battlefield_test.gd"

# Same test runs on 495ddd and the repair. Check shaped Label bounds after the
# container has settled, not authored minima. No clipping/ellipsis/line limits.
var panels: Array = []
var path_steps: Array = []

func raw_key(viewport, board, code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=down
		await send(viewport,board,event,"raw key %d"%code,false)

func live(board, viewport, name: String, projection: String, provenance: String = "ordinary F2 state/API path") -> void:
	await settle(board)
	# Refresh changes text in place; wait again for the deferred Container sort.
	for _frame in range(4): await process_frame
	contained(board,viewport,name)
	var labels: Array = [board.status,board.instruction,board.feedback]+board.enemy_lines
	var rows: Array = []
	var visible: Array = []
	var actions: Rect2 = board.action_grid.get_global_rect()
	var slot: Rect2 = board.information_slot.get_global_rect()
	for label in labels:
		if label.text.is_empty() or not label.is_visible_in_tree(): continue
		var rect: Rect2 = label.get_global_rect()
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		check(font_size==(20 if label==board.status else 15 if label==board.instruction else 14),name+": original readable type size")
		var shaped_height := 0.0
		for i in range(label.get_line_count()): shaped_height += label.get_line_height(i)
		shaped_height += maxi(0,label.get_line_count()-1)*label.get_theme_constant("line_spacing")
		rows.append({"text":label.text,"rect":rect,"line_count":label.get_line_count(),"visible_lines":label.get_visible_line_count(),"font_size":font_size,"font_height":font.get_height(font_size),"shaped_height":shaped_height,"minimum":label.get_combined_minimum_size()})
		check(rect.size.y+0.1 >= shaped_height,name+": full shaped glyph height: "+label.text)
		check(label.get_visible_line_count()==label.get_line_count(),name+": every shaped line visible: "+label.text)
		check(label.visible_characters==-1 and label.max_lines_visible==-1 and label.lines_skipped==0 and label.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING,name+": no text suppression")
		check(not label.clip_text and not label.clip_contents,name+": no label clipping")
		if label != board.status: check(slot.grow(0.1).encloses(rect),name+": text fits information allocation: "+label.text)
		else: check(label.get_parent().get_global_rect().grow(0.1).encloses(rect),name+": title fits allocation")
		check(rect.end.y<=actions.position.y,name+": all immediate text above actions: "+label.text)
		for other: Rect2 in visible: check(not rect.intersects(other),name+": sibling text clear")
		visible.append(rect)
		# Single line means the font can independently prove full horizontal fit.
		if label.get_line_count()==1: check(font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=rect.size.x+0.1,name+": full glyph width")
	check(board.enemy_readout_model().size()==3,name+": all three living visible enemies listed")
	for line in board.enemy_lines: check(not line.text.is_empty() and line.is_visible_in_tree(),name+": enemy fact is immediately visible")
	var action: Dictionary = board.state.player_action
	var words: String = (board.status.text+" "+board.instruction.text+" "+board.feedback.text).to_lower()
	var queue: Dictionary = action.get("lab_exit_request",{})
	if board.state.lab_armed:
		for fact in ["armed","3 cuts","no refund","interruptible"]: check(words.contains(fact),name+": armed fact retained: "+fact)
		check(words.contains("energy") if board.state.uses_energy_rules() else words.contains("recovery rules"),name+": actual resource policy live")
		var target: Dictionary = board.state._enemy_by_id(board.controller.target_id)
		if not target.is_empty() and board.state.lab_target_refusal(board.controller.target_id)=="":
			check(words.contains("#"+board._enemy_readout_tag(board.controller.target_id)) or words.contains(String(board.CombatCatalogScript.presentation(String(target["kind"]))["name"]).to_lower()),name+": selected target retained beside refusal")
	if not queue.is_empty():
		for fact in [String(queue["kind"]),"debt","exit","locked"]: check(words.contains(fact),name+": queue fact retained: "+fact)
		check(words.contains("inactive") or words.contains("not active"),name+": queue has no early activation promise")
		check(words.contains(board._direction_read(queue["direction"]).to_lower()),name+": captured projected direction retained")
	elif board.state.lab_junction():
		check(words.contains("facing") and (words.contains("debt") or words.contains("recovery owed")),name+": facing and junction debt retained")
	elif String(action.get("kind",""))=="combo" and not bool(action.get("terminal_recovery_locked",false)):
		check(words.contains("%.2f"%board.state.player_commitment_world_remaining()),name+": actual remaining obligation live")
		check(words.contains("whole") and words.contains("locked") if bool(action.get("lab_prepaid",false)) else words.contains("cut + exit") and words.contains("optional"),name+": paid versus optional obligation distinct")
	if board.state.lab_notice.begins_with("Commit refused") or board.state.lab_notice.begins_with("Need "):
		check(board.feedback.is_visible_in_tree() and (board.feedback.text.to_lower().contains("refused") or board.feedback.text.begins_with("Need ")),name+": actual refusal remains immediately visible")
	if board.state.lab_notice.begins_with("Interrupted"):
		check(board.feedback.text.contains("Interrupted"),name+": interruption retained")
		if board.state.lab_notice.contains("No refund"): check(board.feedback.text.contains("No refund"),name+": no refund retained")
		if board.state.lab_notice.contains("cleared"): check(board.feedback.text.contains("cleared"),name+": cancelled queue retained")
	if board.state.lab_neutral_required and board.state.is_player_ready(): check(words.contains("release controls"),name+": explicit neutral gate live")
	if viewport.size==Vector2i(720,480): check(board.board_rect.size.y>=200,name+": landscape floor")
	if viewport.size==Vector2i(390,844): check(board.board_rect.size.y>=250,name+": portrait floor")
	var path := ""
	if capture:
		await RenderingServer.frame_post_draw
		path="res://.runtime/information-captures/%dx%d-%s-%s-%s.png"%[viewport.size.x,viewport.size.y,projection,board.variant,name]
		check(viewport.get_texture().get_image().save_png(path)==OK,"capture saved")
	panels.append({"name":name,"variant":board.variant,"arrival":board.arrival,"viewport":viewport.size,"projection":projection,"provenance":provenance,"rows":rows,"slot":slot,"actions":actions,"world":board.board_rect,"panel":board.action_panel_state(),"notice":board.state.lab_notice,"state_digest":Lab.digest(Lab.authoritative(board.state)),"image":path})

func tick_until(board, predicate: Callable, label: String, max_ticks: int = 600) -> void:
	var start: float = board.state.simulation_time
	for _tick in range(max_ticks):
		if predicate.call(): break
		board.state._tick(board.state.SIM_DT)
	check(predicate.call(),"reachable "+label)
	path_steps.append({"path":label,"start":start,"end":board.state.simulation_time,"action":board.state.player_action.duplicate(true),"notice":board.state.lab_notice})

func fresh(board, resources: String = "full") -> void:
	board.arrival=resources
	stopped(board,"F2")

func approach(board) -> void:
	# A request is a native short committed step (34 units), even if a longer
	# distance was requested. Repeat legal steps, never teleport the actor.
	var steps := 0
	while board.state.lab_target_refusal(501)!="" and steps<5:
		check(board.state.request_move(Vector2.RIGHT,34,true),"ordinary approach step accepted")
		check(board.state.is_player_ready(),"approach step ends ready")
		steps+=1
	board.state.lab_input_neutral()
	check(board.state.lab_target_refusal(501)=="","ordinary approach reaches legal Commit target")
	path_steps.append({"path":"ordinary 34-unit right steps","steps":steps,"time":board.state.simulation_time,"pos":board.state.player_pos,"target_refusal":board.state.lab_target_refusal(501)})

func run() -> void:
	if capture: DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.runtime/information-captures"))
	for dims in [Vector2i(720,480),Vector2i(390,844),Vector2i(1280,800),Vector2i(960,600),Vector2i(720,1280)]:
		for projection in ["top_down","isometric"]:
			var viewport := SubViewport.new()
			viewport.size=dims; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var board=Board.new()
			board.size=Vector2(dims); viewport.add_child(board); board.set_process(false)
			await process_frame
			board.view_mode=projection
			fresh(board)
			await live(board,viewport,"ready",projection)
			await raw_key(viewport,board,KEY_K)
			await live(board,viewport,"armed-no-target",projection,"raw K press/release")
			await raw_key(viewport,board,KEY_ENTER)
			check(board.state.lab_armed and board.state.lab_notice.begins_with("Commit refused"),"raw no-target refusal retained")
			await live(board,viewport,"raw-refusal",projection,"raw K then Enter press/release, no selected target")
			check(not board.state.lab_target(501),"actual range refusal")
			await live(board,viewport,"range-refusal",projection)
			# Retained refusal plus a newly accepted normal attack changes in place.
			fresh(board)
			check(not board.state.lab_recover(),"Recover refused while ready")
			check(board.state.request_combo(Vector2.UP,false),"normal cut accepted")
			await live(board,viewport,"normal-retained-refusal",projection)
			await tick_until(board,func(): return board._phase(board.state.player_action)=="FOLLOWING THROUGH","normal follow through with retained refusal")
			await live(board,viewport,"normal-follow-through-retained-refusal",projection)
			fresh(board)
			check(board.state.request_combo(Vector2.UP,false),"normal startup accepted")
			await live(board,viewport,"normal-startup",projection)
			await tick_until(board,func(): return board._phase(board.state.player_action).begins_with("COMBO"),"normal active")
			await live(board,viewport,"normal-active",projection)
			await tick_until(board,func(): return board._phase(board.state.player_action)=="FOLLOWING THROUGH","normal follow through")
			await live(board,viewport,"normal-follow-through",projection)
			await tick_until(board,func(): return board.state.lab_junction(),"junction one")
			await live(board,viewport,"junction-one",projection)
			check(board.state.lab_continue(),"Continue accepts")
			await tick_until(board,func(): return board.state.lab_junction(),"junction two")
			await live(board,viewport,"junction-two",projection)
			check(board.state.lab_recover(),"Recover accepts")
			await live(board,viewport,"recover",projection)
			for queued in ["move","dodge"]:
				fresh(board); junction(board)
				check(board.state.lab_junction(),"F2 junction reached for queue")
				check(board.state.lab_recover(queued,Vector2.RIGHT),"captured "+queued)
				await live(board,viewport,"queue-"+queued,projection)
				check(board.instruction.text.contains("Debt") and board.instruction.text.contains("Exit"),"debt and captured direction live")
				board._lab_attack(true)
				await live(board,viewport,"queue-duplicate-"+queued,projection,"ordinary queue then attempted Attack refusal; unchanged captured request")
				check(board.state.lab_notice.begins_with("Already queued"),"duplicate queued feedback actually generated")
				board.state._resolve_incoming_hit(-1,30,"blade",board.state.player_pos+Vector2.RIGHT*60,board.state.player_pos+Vector2.RIGHT*30)
				check(board.state.lab_notice.contains("cleared"),"actual incoming resolver clears queued action")
				await live(board,viewport,"interrupted-"+queued,projection,"diagnostic incoming hit through actual resolver; no enemy pose edits")
			fresh(board); approach(board)
			check(board.state.lab_toggle_commit(),"Commit arms after approach")
			board.controller.target_id=501
			await live(board,viewport,"armed-target",projection)
			check(board.state.lab_target(501),"Commit legally starts after approach")
			await live(board,viewport,"commit-startup",projection)
			await tick_until(board,func(): return board._phase(board.state.player_action).begins_with("COMBO"),"Commit active")
			await live(board,viewport,"commit-active",projection)
			# Physical interruption uses the shared resolver, not a fabricated action.
			board.state._resolve_incoming_hit(-1,30,"blade",board.state.player_pos+Vector2.RIGHT*60,board.state.player_pos+Vector2.RIGHT*30)
			check(board.state.lab_notice.begins_with("Interrupted"),"Commit interrupted")
			await live(board,viewport,"commit-interrupted",projection,"diagnostic incoming hit through actual resolver")
			await tick_until(board,func(): return board.state.is_player_ready(),"interruption completes")
			check(board.state.lab_neutral_required,"Commit interruption requires neutral")
			await live(board,viewport,"neutral-retained-interruption",projection)
			board.state.lab_input_neutral()
			await live(board,viewport,"ready-retained-interruption",projection)
			fresh(board,"low"); approach(board)
			# Diagnostic threshold fixture: natural low arrival plus walking can
			# regenerate above the cost. Set cost-1, then use the real refusal path.
			board.state.player_energy=board.state.lab_commit_cost()-1
			board.state.lab_toggle_commit(); board.controller.target_id=501
			var before: String = Lab.digest(Lab.authoritative(board.state))
			check(not board.state.lab_target(501) and board.state.lab_notice.begins_with("Need "),"actual cost-minus-one resource refusal")
			check(before==Lab.digest(Lab.authoritative(board.state)),"resource refusal preserves world")
			await live(board,viewport,"resource-refusal",projection,"diagnostic cost-minus-one Energy; ordinary approach and real lab_target refusal")
			# Changing the event while a valid target remains selected must retain
			# both target attribution and the actual refusal, rather than the prompt.
			await live(board,viewport,"armed-target-retained-refusal",projection)
			if dims in [Vector2i(720,480),Vector2i(390,844)]:
				for comparison in ["A","B","G","E"]:
					board.variant=comparison; fresh(board)
					await live(board,viewport,"comparison-ready",projection)
					board.state.lab_toggle_commit()
					await live(board,viewport,"comparison-arm",projection)
			board.queue_free(); viewport.queue_free(); await process_frame
	var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"panels":panels,"paths":path_steps,"gui_trace":gui_trace}
	FileAccess.open("res://.runtime/information-results.json",FileAccess.WRITE).store_string(JSON.stringify(Lab.json_safe(report),"\t"))
	for failure in failures: print("FAILED: ",failure)
	print("INFORMATION checks=",checks," panels=",panels.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
