extends SceneTree
const State = preload("res://scripts/core/run_state.gd")
const Frame = preload("res://scripts/presentation/presentation_frame.gd")
func stats(samples: Array) -> Dictionary:
	samples.sort()
	return {"n":samples.size(),"p50_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*0.95)],"max_ms":samples.back()}
func _init():
	for wall in ["none","enemy","player"]:
		var s=State.new(false)
		s.start_run("mage_elementalist","expedition",717)
		s.player_pos=Vector2(s.areas[4].center)
		s.current_area_id=int(s.areas[4].id)
		s._apply_shortcut_world_state()
		s._update_exploration(true)
		if wall=="enemy": s._raise_earth_wall(s.player_pos-Vector2(400,0),int(s.enemies[0].id))
		if wall=="player": s._raise_player_earth_wall(s.player_pos+Vector2(150,0))
		var a=Frame.new()
		var b=Frame.new()
		var blend=Frame.new()
		var begin:=Time.get_ticks_usec()
		a.capture(s)
		var cold_capture: float=(Time.get_ticks_usec()-begin)/1000.0
		b.capture(s)
		begin=Time.get_ticks_usec()
		blend.blend(a,b,0.5)
		var cold_blend: float=(Time.get_ticks_usec()-begin)/1000.0
		for i in 20:
			a.capture(s)
			blend.blend(a,b,0.5)
		var capture_samples: Array=[]
		var blend_samples: Array=[]
		for i in 200:
			begin=Time.get_ticks_usec()
			a.capture(s)
			capture_samples.append((Time.get_ticks_usec()-begin)/1000.0)
			begin=Time.get_ticks_usec()
			blend.blend(a,b,0.5)
			blend_samples.append((Time.get_ticks_usec()-begin)/1000.0)
		print("PRESENTATION_CPU ",JSON.stringify({"wall":wall,"cold_capture_ms":cold_capture,"cold_blend_ms":cold_blend,"capture":stats(capture_samples),"blend":stats(blend_samples),"capture_hash":hash(a.data),"blend_hash":hash(blend.data),"enemies":a.data.enemies.size(),"barriers":s.barriers.size()}))
	quit()
