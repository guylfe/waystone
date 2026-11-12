extends SceneTree
const State=preload("res://scripts/core/run_state.gd")
const Board=preload("res://scripts/presentation/game_board.gd")
const Readout=preload("res://scripts/presentation/enemy_combat_readout.gd")
const Frame=preload("res://scripts/presentation/presentation_frame.gd")
var checks=0
var failures=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAILED: ",label)
func _init():
	var s=State.new(false);s.start_run("warrior","combat_survey",42,"encounter","energy")
	var e=s._make_enemy("duellist",s.player_pos+Vector2(110,0),45);e.layer=s.current_layer;e.awareness="alerted";e.revealed_to_player=true
	e.parry_cooldown=0.0;e.action=s._idle_action()
	check(Readout.duellist(e).parry=="PARRY AVAILABLE","ready parry available")
	e.parry_cooldown=2.0
	check(Readout.duellist(e).parry=="PARRY RECHARGING","spent parry unavailable")
	s._replace_enemy_actors([e]);s._update_exploration(true)
	var presented=s._enemy_presentation(e)
	check(presented.parry_cooldown==2.0,"presentation carries actual cooldown instead of defaulting ready")
	var frame=Frame.new();var copy=frame.capture(s)
	check(copy.enemies[0].parry_cooldown==2.0,"pooled presentation retains cooldown")
	for option in s.CombatCatalogScript.melee_attack_plan("duellist"):
		e.action=s._intent_melee_action(option,Vector2.LEFT)
		for cooldown in [0.0,2.0]:
			e.parry_cooldown=cooldown
			var original=e.duplicate(true)
			check(Readout.duellist(e).parry=="PARRY LOCKED","committed attack cannot start parry even with cooldown ready")
			check(Readout.duellist(e).tell.begins_with("THRUST" if option.technique=="rapier_thrust" else "CUT"),"authored committed branch is named")
			check(e==original,"guidance cannot mutate intent/action/RNG")
		var end=float(e.action.active_end);var duration=float(e.action.duration)
		for fraction in [0.05,0.5,0.95]:
			e.action.elapsed=end+(duration-end)*fraction
			var text=Readout.duellist(e)
			check(text.tell.contains("RECOVERY"),"recovery phase remains factual")
			check(text.tell.contains("EARLY") if fraction<0.1 else text.tell.contains("ENDING") if fraction>0.9 else not text.tell.contains("ENDING"),"recovery progression communicated")
			check(text.warning.contains("does not guarantee a safe full combo"),"recovery never advertised as guaranteed punish")
	e.action=s._action("parry_stance",0.72,Vector2.LEFT);e.action.parry_end=0.42;e.action.elapsed=0.1
	check(Readout.duellist(e).parry=="PARRY ACTIVE","active front parry distinct from cooldown")
	e.action.elapsed=0.6;check(Readout.duellist(e).parry=="PARRY LOCKED","spent stance recovery not shown as active")
	var b=Board.new();b.state=s
	for weapon in ["sword","knife","twin_knives","staff","bow"]:
		s.player_weapon_frame=weapon;s.player_action=s._idle_action();s.run_active=true;s.loadout_id="rogue_sharpshooter" if weapon=="bow" else "warrior"
		var label=b._ordinary_attack_text();check(label.subtitle=="HOLD: REPEAT","normal idle promises repeat, not combo links "+weapon)
		check(label.title=="AUTO SHOT" if weapon=="bow" else label.title=="ATTACK","automatic shot identified")
		b._select_commit_shot();var cost=s.energy_spent_total;var time=s.simulation_time
		check(s.message.contains(b._commit_action_name().to_upper()),"touch instruction names actual control")
		b._commit_direction(Vector2.RIGHT);check(s.message.contains(b._commit_action_name()),"directional refusal names actual action")
		check(not b._confirm_commit_shot(-1) and s.message.contains(b._commit_action_name()),"invalid target names actual action")
		b._cancel_commit_shot_selection();check(s.message==b._commit_action_name()+" selection cancelled." and s.simulation_time==time and s.energy_spent_total==cost,"truthful cancellation is free")
	s.combat_lab=true;s.lab_variant="A";check(b._ordinary_attack_text().subtitle=="HOLD: COMBO","explicit historical grammar copy retained")
	b.free();print("COMBAT READOUT ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
