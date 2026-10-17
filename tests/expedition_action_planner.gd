extends RefCounted
# A perfect-information, one-action search used only to establish mechanical
# solvability. It is NOT a human-fairness or reaction-time test. Trials run on
# isolated copies; the earned run receives only a public legal player request.
const State = preload("res://scripts/core/run_state.gd")
var probe = State.new(false)
var fields: Array[String] = []
var short_horizon := false
var recover_energy := false
var mage_boss_spacing := true
var defended_bell_volley := ""

func _init() -> void:
	for row in probe.get_property_list():
		if int(row["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE: fields.append(String(row["name"]))

func copy_from(state) -> void:
	for key in fields:
		var value = state.get(key)
		if value is RandomNumberGenerator:
			probe.rng.state = state.rng.state
		elif value is Dictionary:
			if key=="expedition":
				var progress: Dictionary = value.duplicate(false)
				progress["events"] = []
				probe.set(key,progress.duplicate(true))
			else: probe.set(key,value.duplicate(true))
		elif value is Array: probe.set(key,value.duplicate(true))
		elif not value is Object: probe.set(key,value)
	probe._invalidate_active_enemy_cache()
	probe._build_enemy_spatial_index()
	# The grid is immutable after construction; rebuilds replace the object.
	# Keeping a previous probe's grid with the new region metadata is invalid.
	probe.navigation = state.navigation

func apply(state, choice: Array, target: Dictionary) -> bool:
	var position := Vector2(target["pos"])
	var direction: Vector2 = state.player_pos.direction_to(position)
	match choice[0]:
		"move": return state.request_move(Vector2.RIGHT.rotated(float(choice[1])),State.MOVE_RANGE,false)
		"dodge": return state.request_dodge(Vector2.RIGHT.rotated(float(choice[1])),false)
		"vault": return state.request_vault(Vector2.RIGHT.rotated(float(choice[1])),false)
		"combo": return state.request_combo(direction,false,bool(choice[1]))
		"skill": return state.request_skill(direction,false)
		"spell": return state.request_spell(String(choice[1]),position,false)
		"circle": return state.request_circle(false)
		"bow": return state.begin_bow_draw(direction,int(target["id"]))
		"potion": return state.request_potion(false)
		"ration": return state.request_consumable(int(choice[1]),Vector2.ZERO,false)
		"adopted": return state.request_adopted(position,false)
		"advance": return state.request_advance(direction,false,false)
		_: return state.request_wait(float(choice[1]),false)

func choose(state, target: Dictionary) -> bool:
	# Use the readable two-tell response proved by the phase-two contract test.
	# Greedy forecasts can dodge the gust early, then have no defense when the
	# volley releases. Waiting here is a legal choice with a real time cost.
	if state.loadout_id=="rogue_acrobat" and String(target["kind"])=="bell_regent":
		var boss_action: Dictionary = target["action"]
		var ability := String(boss_action.get("ability_id",""))
		var sequence := "%s:%s" % [target["id"],target.get("expedition_attack_index",0)]
		if ability=="crosswind": return state.request_wait(0.05,false)
		if ability=="resonant_volley" and defended_bell_volley!=sequence:
			if float(boss_action["elapsed"])<0.45: return state.request_wait(0.05,false)
			var across: Vector2 = state.player_pos.direction_to(target["pos"]).orthogonal()
			if state.request_dodge(across,false):
				defended_bell_volley=sequence
				return true
	var budgets_defense: bool = state.loadout_id in ["rogue_acrobat","mage_elementalist"]
	var ranged_mage_boss: bool = mage_boss_spacing and state.loadout_id=="mage_elementalist" and int(target.get("expedition_site",-1))==9
	var acrobat_ranged_tell: bool = state.loadout_id=="rogue_acrobat" and int(target.get("expedition_site",-1))==9 and (String(target["action"].get("shape","")) in ["fan","wind"] or state.projectiles.any(func(shot): return (int(shot.get("source_id",0))!=0 or bool(shot.get("misdirected",false))) and Vector2(shot["pos"]).distance_to(state.player_pos)<650))
	# Groups require a longer retaliation horizon than a solo boss. In particular,
	# a safe-looking staff thrust can expose the Mage to a second actor's attack.
	var use_short_horizon: bool = short_horizon and (state.loadout_id!="mage_elementalist" or ranged_mage_boss) and not acrobat_ranged_tell
	var energy_cycles: bool = state.loadout_id=="rogue_acrobat" or ranged_mage_boss
	if energy_cycles and state.player_energy<22: recover_energy=true
	if not energy_cycles: recover_energy=false
	if state.player_energy>65: recover_energy=false
	var candidates: Array = [["wait",0.08],["wait",0.25],["potion"],["skill"]]
	if state.player_weapon_frame=="bow": candidates.append(["bow"])
	else: candidates.append_array([["combo",false],["combo",true]])
	if state.loadout_id=="mage_elementalist":
		for spell in state.player_spells: candidates.append(["spell",spell])
	if state.loadout_id=="warrior": candidates.append(["advance"])
	if state.expedition["discipline"]!="": candidates.append(["adopted"])
	for slot in range(3):
		if state.consumable_slot(slot)["id"]=="trail_ration": candidates.append(["ration",slot])
	for index in range(8):
		var angle: float = index*TAU/8
		candidates.append(["move",angle])
		# An endless desperate-Dodge loop keeps restarting exhaustion. This test
		# player budgets ordinary defenses instead of mistaking debt for free use.
		if index%2==0 and (state.loadout_id not in ["rogue_acrobat","mage_elementalist"] or state.player_energy>=State.DODGE_ENERGY_COST):
			candidates.append(["dodge",angle])
			if state.loadout_id=="rogue_acrobat" and state.player_energy>=State.VAULT_ENERGY+State.DODGE_ENERGY_COST: candidates.append(["vault",angle])
	if use_short_horizon and state.player_energy>=State.DODGE_ENERGY_COST:
		var toward: float = state.player_pos.direction_to(target["pos"]).angle()
		for offset in [0.0,PI/2,-PI/2,PI]: candidates.append(["dodge",toward+offset])
	var best: Array = ["wait",0.08]
	var best_score := -INF
	var initial_distance: float = state.player_pos.distance_to(target["pos"])
	var optimal := 350.0 if state.player_weapon_frame=="bow" else 65.0 if state.player_weapon_frame=="knife" else 95.0
	if state.loadout_id=="rogue_acrobat" and int(target.get("expedition_site",-1))==9: optimal=115.0
	if budgets_defense and recover_energy: optimal=300.0 if state.loadout_id=="mage_elementalist" else 190.0
	if ranged_mage_boss: optimal=250.0
	# A knife punish is not permission to stand at a fan's origin. Back out
	# during its visible tell and account for projectile flight before closing.
	if acrobat_ranged_tell: optimal=300.0
	for choice in candidates:
		# Lightning is the quick single-target tool. A fragile caster should not
		# hug a five-projectile fan's origin or spend every opening on a long AoE.
		if ranged_mage_boss and (choice[0] in ["combo","skill","circle","adopted"] or (choice[0]=="spell" and choice[1]!="lightning_bolt")): continue
		# Fragile characters need a short sequence of decisions, not a succession
		# of locally attractive overdrafts. Keep one ordinary Dodge in reserve;
		# recovery movement can still be dangerous and is forecast normally.
		if budgets_defense:
			if recover_energy and choice[0] in ["combo","skill","spell","adopted","vault"]: continue
			var cost := 0.0
			if choice[0]=="combo": cost=state._combo_energy_cost() if bool(choice[1]) else state._basic_attack_energy_cost()
			elif choice[0]=="skill": cost=State.EXECUTION_ENERGY if state.loadout_id=="rogue_acrobat" else 56.0
			elif choice[0]=="spell": cost=state.spell_energy_cost(String(choice[1]))
			elif choice[0]=="adopted": cost=26.0
			if cost>0 and state.player_energy<cost+State.DODGE_ENERGY_COST: continue
		copy_from(state)
		var copied_target: Dictionary = probe._enemy_by_id(int(target["id"]))
		if not apply(probe,choice,copied_target): continue
		for tick in range(600):
			if probe.player_action["kind"]=="bow_draw" and float(probe.player_action["elapsed"])>=0.90: probe.release_bow_attack()
			if probe.is_player_ready() or probe.death_pending: break
			probe.advance_streamed_action_tick()
		# Include projectile flight and delayed retaliation. Judging a bow at
		# release while counting melee damage at contact biases this test player.
		# These waits exist only in the isolated forecast, never the earned run.
		var forecast_duration := 1.25
		if use_short_horizon and choice[0] not in ["bow","spell","adopted"]: forecast_duration=0.20
		var forecast_end: float = maxf(probe.simulation_time,state.simulation_time+forecast_duration)
		while probe.simulation_time<forecast_end and not probe.death_pending:
			# Counterfactual stationary world time on the COPY. Context-sensitive
			# Wait may open a shop or pickup instead, and must not stall the probe.
			probe._tick(State.SIM_DT)
		var time: float = probe.simulation_time-state.simulation_time
		var health: float = probe.player_hp-state.player_hp
		var damage: float = probe.damage_dealt-state.damage_dealt
		var energy: float = probe.player_energy-state.player_energy
		var distance: float = probe.player_pos.distance_to(copied_target["pos"])
		var energy_weight := 0.65 if budgets_defense and state.player_energy<40 else 0.10
		var score := health*6.0+damage*2.0+energy*energy_weight-time*0.7+(absf(initial_distance-optimal)-absf(distance-optimal))*0.035
		if choice[0]=="potion": score-=35.0
		if choice[0]=="ration": score-=15.0
		if probe.death_pending: score-=10000
		if probe.player_exhaustion_remaining>0: score-=14.0
		# Do not prefer wasting time merely to make the same resource bar greener.
		if energy>0 and state.player_energy>65: score-=energy*0.1
		if score>best_score:
			best_score=score
			best=choice
	return apply(state,best,target)
