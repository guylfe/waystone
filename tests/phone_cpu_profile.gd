extends SceneTree
const State = preload("res://scripts/core/run_state.gd")
const Frame = preload("res://scripts/presentation/presentation_frame.gd")
const Generator = preload("res://scripts/core/expedition_generator.gd")

func _init():
	if not OS.get_user_data_dir().contains(".runtime"): quit(2); return
	print("PROFILE desktop headless CPU only; generated seed=717; direct position/wall fixtures; no GPU/touch claim")
	for biome in range(3):
		for wall in ["none","enemy","player"]: measure(biome, wall)
	quit()
func stats(samples: Array) -> Dictionary:
	var values := samples.duplicate()
	values.sort()
	return {"n":values.size(),"p50_ms":values[values.size()/2],"p95_ms":values[mini(values.size()-1,int(values.size()*0.95))],"max_ms":values.back()}
func measure(biome: int, wall: String):
	var s = State.new(false)
	var begin := Time.get_ticks_usec()
	s.start_run("mage_elementalist","expedition",717)
	if biome>0:
		s.expedition.biome=biome
		s._install_layout(Generator.generate(717,biome))
		s._respawn_enemies()
	var generation_ms := (Time.get_ticks_usec()-begin)/1000.0
	s.player_pos=Vector2(s.areas[4].center)
	s.current_area_id=int(s.areas[4].id)
	s._apply_shortcut_world_state()
	s._update_exploration(true)
	s._build_enemy_spatial_index()
	s.player_hp=100000 # Keep the same populated action scenario alive for the bounded sample.
	begin=Time.get_ticks_usec()
	if wall=="enemy": s._raise_earth_wall(s.player_pos-Vector2(400,0),int(s.enemies[0].id))
	if wall=="player": s._raise_player_earth_wall(s.player_pos+Vector2(150,0))
	var raise_ms := (Time.get_ticks_usec()-begin)/1000.0
	var barriers: Array = s.barriers.duplicate(true)
	var nav_before: String = s._navigation_cache_key()
	begin=Time.get_ticks_usec()
	s._build_navigation()
	var nav_ms := (Time.get_ticks_usec()-begin)/1000.0
	var nav_hit: bool = s.performance_metrics.navigation_cache_hit
	var barrier_samples: Array=[]
	for i in 240:
		s.barriers.assign(barriers.duplicate(true))
		begin=Time.get_ticks_usec()
		s._update_barriers(State.SIM_DT)
		barrier_samples.append((Time.get_ticks_usec()-begin)/1000.0)
	var frames: Array=[]
	var captures: Array=[]
	var actions: Array=[]
	var presentation=Frame.new()
	for i in 24:
		# Refresh only the wall lifetime between actions; natural enemies retain their state.
		for segment in s.barriers: segment.remaining=20.0
		begin=Time.get_ticks_usec()
		if not s.request_move(Vector2.DOWN if i%2==0 else Vector2.UP,12,false): continue
		var action_begin:=Time.get_ticks_usec()
		while String(s.player_action.kind)!="idle" and s.player_hp>0:
			var tick_begin:=Time.get_ticks_usec()
			s.advance_streamed_action_tick()
			frames.append((Time.get_ticks_usec()-tick_begin)/1000.0)
			var capture_begin:=Time.get_ticks_usec()
			presentation.capture(s)
			captures.append((Time.get_ticks_usec()-capture_begin)/1000.0)
		actions.append((Time.get_ticks_usec()-action_begin)/1000.0)
	print("CPU ",JSON.stringify({"biome":biome,"wall":wall,"generation_ms":generation_ms,"raise_ms":raise_ms,"barrier_tick":stats(barrier_samples),"tick":stats(frames),"capture":stats(captures),"action":stats(actions),"cold_tick_ms":frames[0],"nav_call_ms":nav_ms,"nav_cache_hit":nav_hit,"nav_key_unchanged":nav_before==s._navigation_cache_key(),"active":s.performance_metrics.active_enemies,"resident":s.enemies.size(),"segments":barriers.size()}))
