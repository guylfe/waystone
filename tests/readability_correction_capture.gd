extends "res://tests/commit_shot_input_test.gd"
# Recheck instrument: run with a real Compatibility renderer and isolated .runtime
# user data. Captures are evidence for inspection, never automatic feel acceptance.
var output=""
func capture(label:String):
	board.queue_redraw();await frames(3);RenderingServer.force_draw(false)
	var im=root.get_texture().get_image()
	check(im!=null and im.get_width()>0,"GPU frame "+label)
	if im!=null:im.save_png(output+"/"+label+".png")
	records.append({"capture":label,"size":str(root.size),"unit":board.MenuMetrics.unit(board),"board":str(board.board_rect),"dock":str(board.commit_dock_rect),"commit":str(board.commit_shot_rect),"attack":str(board.attack_rect),"message":board.state.message})
func run():
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	output=OS.get_environment("WAYSTONE_READABILITY_OUTPUT")
	if output.is_empty():output=ProjectSettings.globalize_path("user://readability-corrected")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_min_size(Vector2i(1,1))
	for dims in [Vector2i(390,844),Vector2i(720,600),Vector2i(1280,800)]:
		DisplayServer.window_set_size(dims)
		for frame in ["sword","knife","twin_knives","staff","bow"]:
			var loadout="rogue_sharpshooter" if frame=="bow" else "mage_elementalist" if frame=="staff" else "rogue_acrobat" if frame in ["knife","twin_knives"] else "warrior"
			await setup("energy","isometric",dims,loadout)
			board.state.player_weapon_frame=frame;board.visual=board._presentation_snapshot();board._layout();board.desktop_controls=false
			var prefix=str(dims.x)+"x"+str(dims.y)+"-"+frame
			await capture(prefix+"-idle")
			await select("touch");await capture(prefix+"-armed")
			await tap(board.commit_shot_rect.get_center());await capture(prefix+"-cancelled")
			board.desktop_controls=true;await select("pad");await capture(prefix+"-pad")
			await pad(JOY_BUTTON_B);await select("touch");await confirm("touch");board.set_process(false)
			await capture(prefix+"-full-commit")
			await finish()
	DisplayServer.window_set_size(Vector2i(390,844));await setup("energy","isometric",Vector2i(390,844),"warrior")
	board.set_process(false)
	var s=board.state;var enemy=s._make_enemy("duellist",s.player_pos+Vector2(110,0),45)
	enemy.layer=s.current_layer;enemy.awareness="alerted";enemy.revealed_to_player=true;enemy.parry_cooldown=0.0
	s._replace_enemy_actors([enemy]);s._update_exploration(true)
	for cooldown in [0.0,2.0]:
		enemy.action=s._idle_action();enemy.parry_cooldown=cooldown;board.visual=board._presentation_snapshot();await capture("duellist-ready-"+str(cooldown))
	for option in s.CombatCatalogScript.melee_attack_plan("duellist"):
		enemy.action=s._intent_melee_action(option,Vector2.LEFT)
		for fraction in [0.0,0.05,0.5,0.95]:
			enemy.action.elapsed=float(option.active_end)+(float(option.duration)-float(option.active_end))*fraction if fraction>0 else 0.0
			board.visual=board._presentation_snapshot();await capture("duellist-"+str(option.technique)+"-"+str(fraction))
	board.inspected_enemy_id=int(enemy.id);await capture("duellist-inspection-warning")
	board.inspected_enemy_id=-1
	var ref_area=Rect2(Vector2.ZERO,Vector2(720,1558*0.735))
	var ref_scale=maxf(ref_area.size.x/1050.0,ref_area.size.y/1000.0)*1.38
	var ref_anchor=ref_area.get_center()+Vector2(0,ref_area.size.y*0.075)
	var previous_surfaces=[Vector2(158.7692,754.2838),Vector2(672.11,754.2838),Vector2(360,930)]
	for index in previous_surfaces.size():
		var projected=(previous_surfaces[index]-ref_anchor)/ref_scale
		enemy.pos=s.player_pos+Vector2(projected.x+2*projected.y,2*projected.y-projected.x)
		enemy.action=s._idle_action();enemy.parry_cooldown=0.0;s._update_exploration(true)
		board.visual=board._presentation_snapshot()
		await select("touch");await capture("old-surface-world-position-"+str(index))
		check(board.board_rect.has_point(target_point()) and not board.commit_dock_rect.has_point(target_point()),"review world position remains in battlefield")
		await tap(board.commit_shot_rect.get_center())
	FileAccess.open(output+"/records.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("CORRECTED CAPTURES ",checks," checks ",failures.size()," failures; renderer ",RenderingServer.get_video_adapter_name(),"; output ",output)
	quit(0 if failures.is_empty() else 1)
