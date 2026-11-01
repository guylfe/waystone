extends "res://tests/commit_shot_test.gd"
const Semantic=preload("res://scripts/core/determinism_snapshot.gd")
const Schema=preload("res://scripts/core/state_field_schema.gd")
# Counterfactual real-arrow contacts, following the independent analyst's fixture.
func arrow()->Dictionary:
	var s=fresh("energy",5,true)
	check(s.request_commit_shot(target_id(s),false),"real source projectile commits")
	for i in 500:
		if s.projectiles.size():return s.projectiles[0].duplicate(true)
		s.advance_streamed_action_tick()
	check(false,"source arrow spawned");return {}
func set_flag(value:Dictionary,presence:String):
	value.erase("bow_followup_consumed")
	if presence!="absent":value.bow_followup_consumed=presence=="true"
func matrix():
	var original:=arrow()
	for global in [false,true]:
		var hashes:Dictionary={}
		for presence in ["absent","false","true"]:
			var s=fresh("energy",5,true);s.bow_followup_consumed=global;s.bow_followup_ready=false
			var p=original.duplicate(true);set_flag(p,presence)
			p.pos=s.enemies[0].pos-Vector2(12,0);p.vel=Vector2(820,0);p.travelled=0;p.max_range=700
			s._add_projectile(p)
			var effective:bool=p.get("bow_followup_consumed",global)
			var raw=s.projectiles.duplicate(true)
			var snap=Semantic.checkpoint(s);hashes[presence]=snap
			check(raw==s.projectiles,"projection does not alter saved/runtime arrow")
			check(s.save_run("user://ownership-matrix.save"),"matrix saves "+presence)
			var loaded=State.new(false);check(loaded.load_run("user://ownership-matrix.save"),"matrix reloads "+presence)
			check(loaded.bow_followup_consumed==global and loaded.projectiles==raw,"save preserves absence/explicit override "+presence)
			check(Semantic.checkpoint(loaded).world==snap.world,"same effective arrow checkpoint after reload")
			# Restore labelled custom geography; load reconstructs generated geography.
			loaded.walls.clear();loaded._build_wall_spatial_index();loaded.world_size=s.world_size
			loaded.floor_shapes.assign(s.floor_shapes);loaded._loaded_floor_shapes.assign(s.floor_shapes);loaded._build_shape_spatial_index()
			loaded._update_projectiles(0.025)
			check(loaded.survey_shots_hit==1 and loaded.bow_followup_ready==not effective,"real loaded contact uses exact fallback "+presence+str(global))
			records.append({"kind":"projectile","global":global,"presence":presence,"effective":effective,"checkpoint":snap,"hits":loaded.survey_shots_hit,"reward":loaded.bow_followup_ready,"fixture":"genuine full arrow, rank5, synthetic inert target/contact12 units/velocity820/range700/dt.025; old-format absent field retained"})
		var equivalent:String="true" if global else "false"
		var different:String="false" if global else "true"
		check(hashes.absent==hashes[equivalent],"equivalent fallback canonicalized "+str(global))
		check(hashes.absent.world!=hashes[different].world and hashes.absent.all!=hashes[different].all,"different reward changes world/all hash "+str(global))
	# Inactive ownership must not change historical non-full/enemy projectiles.
	for friendly in [false,true]:
		var hashes:Array=[]
		for presence in ["absent","false","true"]:
			var s=fresh("energy",5,true);s.bow_followup_consumed=true
			var p=original.duplicate(true);p.friendly=friendly;p.full_draw=not friendly;set_flag(p,presence);s._add_projectile(p)
			hashes.append(Semantic.checkpoint(s))
		check(hashes[0]==hashes[1] and hashes[1]==hashes[2],"irrelevant ownership omitted "+str(friendly))
func action_matrix():
	for kind in ["bow_draw","bow_release"]:
		for global in [false,true]:
			var hashes:Dictionary={}
			for presence in ["absent","false","true"]:
				var s=fresh("energy",5,true)
				if kind=="bow_release":ordinary(s,1.0)
				else:
					check(s.begin_bow_draw(Vector2.RIGHT,target_id(s)),"action matrix public draw")
					for i in 500:
						if s.player_action.elapsed>=0.90:break
						s.advance_streamed_action_tick()
				s.bow_followup_consumed=global;set_flag(s.player_action,presence)
				var raw=s.player_action.duplicate(true);var snap=Semantic.checkpoint(s);hashes[presence]=snap
				check(s.player_action==raw,"action projection leaves raw ownership")
				check(s.save_run("user://action-owner.save"),"active old/current action save")
				var loaded=State.new(false);check(loaded.load_run("user://action-owner.save"),"active action reload")
				check(loaded.player_action==raw and loaded.bow_followup_consumed==global,"action raw absence/override survives")
				check(Semantic.checkpoint(loaded).player==snap.player,"loaded effective action same hash")
				if kind=="bow_draw":check(loaded.release_bow_attack(),"old/current draw releases")
				for i in 500:
					if loaded.projectiles.size():break
					loaded.advance_streamed_action_tick()
				var effective:bool=raw.get("bow_followup_consumed",global)
				check(loaded.projectiles.size()==1 and loaded.projectiles[0].bow_followup_consumed==effective,"action fallback reaches constructed arrow")
				records.append({"kind":kind,"global":global,"presence":presence,"effective":effective,"checkpoint":snap})
			check(hashes.absent==hashes["true" if global else "false"],"equivalent action fallback canonicalized")
			check(hashes.absent.player!=hashes["false" if global else "true"].player,"action override changes future arrow hash")
	var old=fresh("energy",5,true);var payload=old._build_save_payload()
	payload.erase("bow_followup_ready");payload.erase("bow_followup_consumed");payload.player_action.erase("bow_followup_consumed")
	FileAccess.open("user://old-owner.save",FileAccess.WRITE).store_var(payload,true)
	var restored=State.new(false);check(restored.load_run("user://old-owner.save"),"old-format missing globals loads")
	check(not restored.bow_followup_ready and not restored.bow_followup_consumed,"old globals retain false defaults")
	check(Semantic.checkpoint(old).player==Semantic.checkpoint(restored).player,"genuinely equivalent historical player default")
func run():
	check(Schema.validate().is_empty(),"field schema valid")
	var descriptors=Schema.entity_descriptors("projectile",Schema.DETERMINISM)
	check(descriptors.any(func(d):return d.key=="bow_followup_consumed"),"projectile owns determinism descriptor")
	check(not Schema.project_entity({"bow_followup_consumed":true},"projectile",Schema.PRESENTATION).has("bow_followup_consumed"),"ownership adds no render fields")
	matrix();action_matrix()
	FileAccess.open("user://bow-ownership-checkpoint-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"\t"))
	print("BOW OWNERSHIP CHECKPOINT ",checks," checks / ",records.size()," records / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
