extends "res://tests/phone_world_repair_test.gd"
func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	# Actual Expedition geometry and walls, seed 717. Only the shot is injected and
	# actors removed to isolate floor collision; this is not an earned playthrough.
	var start:=Vector2(650,3450)
	var finish:=Vector2(1400,2650)
	for step in [1.0,State.SIM_DT]:
		var s=State.new(false)
		s.start_run("warrior","expedition",717)
		s._replace_enemy_actors([])
		check(s._point_on_floor(start) and s._point_on_floor(finish),"generated endpoints on actual floor dt="+str(step))
		check(s._has_line_of_sight(start,finish),"generated crossing is not an interior-wall test dt="+str(step))
		var crosses_void:=false
		for i in range(1,100):
			if not s._point_on_floor(start.lerp(finish,float(i)/100)): crosses_void=true
		check(crosses_void,"generated segment leaves floor and re-enters dt="+str(step))
		s._add_projectile({"kind":"player_arrow","pos":start,"vel":finish-start,"radius":8.0,"damage":10,"source_id":0,"layer":s.current_layer,"misdirected":false,"max_range":2000})
		for i in range(ceili(1.0/step)): s._update_projectiles(step)
		check(s.projectiles.is_empty(),"actual generated concave gap blocks shot dt="+str(step))
		print("GENERATED_FLOOR_SHOT seed=717 start=",start," finish=",finish," dt=",step," survivors=",s.projectiles.size())
	print("GENERATED_FLOOR_SHOT checks=%d failures=%d" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
