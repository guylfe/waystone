extends "res://tests/phone_boundary_probe.gd"
func audit(id,ok,data={}):data["passed"]=ok;record(id,data.duplicate(true))
func run():
	if not OS.get_user_data_dir().contains(".runtime"):quit(2);return
	await setup(Vector2i(720,1280))
	for mode in ["ordinary","piercing","firebomb","enemy"]:
		await synthetic_floor("rect");var s=board.state
		var near=s._make_enemy("blade",Vector2(1010,800),100,0);near.id=101
		var far=s._make_enemy("blade",Vector2(1280,800),100,0);far.id=102
		if mode=="enemy":
			near.pos=Vector2(900,1100);s.player_pos=Vector2(1280,800)
		else:s.player_pos=Vector2(900,1100)
		s._replace_enemy_actors([near,far]);s._build_enemy_spatial_index()
		shot(Vector2(900,800),Vector2(2000,0),101 if mode=="enemy" else 0)
		s.projectiles[0].kind="firebomb" if mode=="firebomb" else "arrow"
		s.projectiles[0].piercing=mode=="piercing"
		var hp=s.player_hp;s._update_projectiles(0.2)
		audit("ordered_"+mode,int(far.hp)==100 and s.projectiles.is_empty() and (int(near.hp)<100 if mode in ["ordinary","piercing"] else s.player_hp==hp if mode=="enemy" else s.hazards.size()==1 and Vector2(s.hazards[0].pos).x<1050),{"kernel_fixture":true,"near_hp":near.hp,"far_hp":far.hp,"player_before":hp,"player_after":s.player_hp,"survivors":s.projectiles.size(),"hazards":s.hazards})
	# Firebomb must also stop at the edge when there is no earlier body.
	await synthetic_floor("rect");var s=board.state;s.player_pos=Vector2(900,1100)
	shot(Vector2(900,800),Vector2(2000,0));s.projectiles[0].kind="firebomb";s._update_projectiles(0.2)
	audit("firebomb_edge",s.hazards.size()==1 and s._point_on_floor(s.hazards[0].pos) and Vector2(s.hazards[0].pos).x<1050,{"kernel_fixture":true,"hazards":s.hazards})
	# Native arc elevation policy (not just a constant high altitude fixture).
	for owner in [0,999]:
		await synthetic_floor("rect");s=board.state
		if owner!=0:reserve_source()
		shot(Vector2(900,800),Vector2(2000,0),owner)
		s.projectiles[0].elevation_profile="arc";s.projectiles[0].arc_span=1000;s.projectiles[0].elevation_peak=120;s.projectiles[0].travelled=100
		var end=s.projectiles[0].duplicate(true);end.travelled=500
		var height=s._projectile_elevation(end);s._update_projectiles(0.2)
		audit("arc_void_owner"+str(owner),height>State.PROJECTILE_GROUND_ELEVATION and s.projectiles.is_empty(),{"kernel_fixture":true,"intended_height":height,"owner":owner})
	await finish()
	FileAccess.open("res://.runtime/independent-contact-results.json",FileAccess.WRITE).store_string(JSON.stringify({"sha":"1660a840da567062b3f0211e463f2bbf7fc2e23c","rows":rows,"harness_errors":errors},"\t"));quit(0 if errors.is_empty() else 2)
