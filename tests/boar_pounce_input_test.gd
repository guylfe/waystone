extends "res://tests/commit_shot_input_test.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	for loadout in ["warrior","rogue_acrobat","rogue_sharpshooter","mage_elementalist"]:
		for rules in ["energy","recovery"]:
			await setup(rules,"isometric",Vector2i(720,1280),loadout)
			var s=board.state;var e=s._make_enemy("boar",s.player_pos+Vector2(0,-220),35)
			e.layer=s.current_layer;e.awareness="alerted";e.revealed_to_player=true;e.facing=Vector2.DOWN;e.last_known_player=s.player_pos
			s._replace_enemy_actors([e]);s._update_exploration(true);board.visual=board._presentation_snapshot();await frames()
			await tap(board.interaction_rect.get_center());await ready()
			check(e.action.kind=="charge" and e.action.label=="pounce","normal root WAIT selects real pounce "+loadout+rules)
			check(e.action.speed==640 and is_equal_approx(e.action.tracking_end,0.45),"root action uses authored tune")
			var time=s.simulation_time;await frames(25)
			check(s.simulation_time==time,"deliberation does not advance pounce")
			var start=board._world_to_screen(s.player_pos);var end=board._world_to_screen(s.player_pos+Vector2(160,0))
			await touch(start,true)
			var drag=InputEventScreenDrag.new();drag.index=31;drag.position=end;drag.relative=end-start;send(drag)
			await create_timer(0.72).timeout;await frames()
			await touch(end,false);await ready()
			check(s.simulation_time>time and s.player_pos.x>900,"routed sustained movement advances chosen pounce and player")
			var stopped=s.simulation_time;var pos=s.player_pos;await frames(25)
			check(s.simulation_time==stopped and s.player_pos==pos,"release finishes one step then freezes")
			var action=e.action.duplicate(true)
			records.append({"loadout":loadout,"rules":rules,"root":str(root.size),"input":"normal main-root WAIT and ScreenTouch/Drag/release with automatic frames","player_speed":s.player_move_speed,"enemy_action":action,"player_pos":str(pos),"world_time":stopped,"fixture":"open floor and actual selected Boar at gap220; standard player loadout"})
			await finish()
	FileAccess.open("user://boar-pounce-input-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("BOAR ROOT INPUT ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
