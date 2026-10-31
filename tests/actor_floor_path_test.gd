extends "res://tests/phone_world_repair_test.gd"
func path_on_floor(s, start: Vector2, finish: Vector2) -> bool:
	for i in range(101):
		if not s._point_on_floor(start.lerp(finish,float(i)/100)): return false
	return true
func run():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	var start:=Vector2(250,550)
	var delta:=Vector2(300,-200)
	for actor_id in [0,101]:
		var s=fixture(u_shapes())
		var finish: Vector2=s._move_actor(start,delta,24,actor_id,true)
		check(path_on_floor(s,start,finish),"displayed straight actor displacement never cuts concave void actor="+str(actor_id))
	var s=fixture(u_shapes())
	check(path_on_floor(s,start,s._move_vault_actor(start,delta)),"displayed straight vault displacement never cuts concave void")
	print("ACTOR_FLOOR_PATH checks=%d failures=%d" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
