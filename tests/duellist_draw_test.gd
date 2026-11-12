extends SceneTree
const State=preload("res://scripts/core/run_state.gd")
class Probe extends "res://scripts/presentation/game_board.gd":
	var actor_draws=0
	func _draw_actor(pos:Vector2,foot:Vector2,facing:Vector2,radius:float,color:Color,marker_color:Color,reeling:bool=false,body_scale:Vector2=Vector2.ONE,stride:float=0.0)->void:
		actor_draws+=1
		super._draw_actor(pos,foot,facing,radius,color,marker_color,reeling,body_scale,stride)
func _init():call_deferred("run")
func run():
	root.size=Vector2i(720,1280)
	var b=Probe.new();b.size=Vector2(720,1280);root.add_child(b)
	await process_frame
	b.set_process(false)
	b.state=State.new(false);b.state.start_run("warrior","combat_survey",42,"encounter","energy")
	var s=b.state;s.enemies.clear();s.walls.clear();s._build_wall_spatial_index()
	var e=s._make_enemy("duellist",s.player_pos+Vector2(100,0),45)
	e.layer=s.current_layer;e.awareness="alerted";e.revealed_to_player=true;e.parry_cooldown=0.0
	s._replace_enemy_actors([e]);s._update_exploration(true)
	b.visual=b._presentation_snapshot();b._layout();b.actor_draws=0;b.queue_redraw()
	await process_frame;await process_frame
	print("ACTOR DRAW DISPATCH ",b.actor_draws)
	var ok=b.actor_draws>=2
	b.queue_free();quit(0 if ok else 1)
