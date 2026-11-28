extends SceneTree

const Campaign = preload("res://scripts/campaign/campaign_state.gd")
const Profiles = preload("res://scripts/campaign/campaign_player_profiles.gd")
const EnemyProfiles = preload("res://scripts/campaign/campaign_enemy_profiles.gd")
const Regions = preload("res://scripts/campaign/campaign_regions.gd")
const Session = preload("res://scripts/core/mode_session.gd")
const SEED := 131137
const LOADOUTS := ["warrior", "rogue_acrobat", "rogue_sharpshooter", "mage_elementalist"]
const STYLES := ["slow", "fast"]
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: return
	failures.append(label)
	printerr("FAILED: ", label)

func fresh(style: String, loadout: String = "warrior") -> Campaign:
	var state := Campaign.new(false)
	state.combat_style = style
	state.start_run(loadout, "campaign_lab", SEED)
	return state

func clear_dawn(style: String, loadout: String) -> Campaign:
	var state := fresh(style, loadout)
	state._replace_enemy_actors([])
	state.waystones.clear()
	state.player_pos = Vector2(520, 995)
	state._update_exploration(true)
	return state

func visible_target(state: Campaign, offset: Vector2) -> Dictionary:
	var enemy := state._make_enemy("blade", state.player_pos + offset, 10000)
	enemy.layer = state.current_layer
	enemy.facing = -offset.normalized()
	enemy.awareness = "alerted"
	enemy.revealed_to_player = true
	enemy.alert_remaining = 30.0
	enemy.last_known_player = state.player_pos
	enemy.action = state._action("wait", 1000.0, enemy.facing)
	enemy.properties.hit_reaction_policy = "posture_only"
	enemy.posture = 10000.0
	enemy.posture_max = 10000.0
	state._replace_enemy_actors([enemy])
	state._update_exploration(true)
	return enemy

func finish(state: Campaign) -> void:
	for index in 1000:
		if not state.advance_streamed_action_tick(): break
	check(state.is_player_ready(), "commit reaches a free decision")

func real_time(state: Campaign, start: float) -> float:
	return (state.simulation_time - start) / Campaign.EXECUTION_PLAYBACK_RATE

func near_time(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) <= Campaign.SIM_DT / Campaign.EXECUTION_PLAYBACK_RATE + 0.0001,
		"%s (observed %.4f, expected %.4f)" % [label, actual, expected])

func player_actions(style: String, loadout: String) -> void:
	var state := clear_dawn(style, loadout)
	var weapon := state.comparison_weapon()
	var stats := Profiles.profile(style, weapon)
	var label := "%s/%s/%s" % [style, loadout, weapon]
	check(not stats.is_empty(), label + " has a research row")
	if stats.is_empty(): return
	check(not state.player_uses_ranged_basic_attack() and state.commit_available(), label + " uses melee Attack and Combo")
	var origin := state.player_pos
	check(state.begin_streamed_move(Vector2.RIGHT, 5.0), label + " accepts stride")
	finish(state)
	near_time(real_time(state, 0.0), float(stats.step_distance) / float(stats.move_speed), label + " stride seconds")
	check(absf(state.player_pos.distance_to(origin) - float(stats.step_distance)) < 0.03, label + " exact clear stride reach")
	var idle_time := state.simulation_time
	check(not state.advance_streamed_action_tick() and state.simulation_time == idle_time, label + " ready world freezes")

	origin = state.player_pos
	var roll_start := state.simulation_time
	check(state.request_defense(Vector2.RIGHT, false), label + " accepts defense")
	check(state.player_action.kind == "dodge", label + " defense uses the roll")
	var roll := state.player_action
	var clock := Campaign.EXECUTION_PLAYBACK_RATE * state._tempo_from_attributes(state.player_attributes)
	check(is_equal_approx(float(roll.evade_start) / clock, float(stats.iframe_start)), label + " i-frame opens from research")
	check(is_equal_approx(float(roll.evade_end) / clock, float(stats.iframe_end)), label + " i-frame closes from research")
	roll.elapsed = float(roll.evade_start)
	check(state._is_evasive(), label + " i-frame start includes the boundary")
	roll.elapsed = float(roll.evade_end)
	check(not state._is_evasive(), label + " i-frame end excludes the boundary")
	roll.elapsed = 0.0
	finish(state)
	var roll_time := real_time(state, roll_start)
	near_time(roll_time, float(stats.roll_duration), label + " roll duration")
	check(absf(state.player_pos.distance_to(origin) - float(stats.roll_distance)) < 0.03, label + " exact clear roll reach")

	state = clear_dawn(style, loadout)
	var attacks: Array = stats.attacks
	var opener: Dictionary = attacks[0]
	origin = state.player_pos
	check(state.request_direct_attack(Vector2.RIGHT, false, true), label + " accepts held Attack")
	state.set_attack_hold(true)
	var single := state.player_action
	check(single.kind == "attack" and not single.has("phases"), label + " held Attack authorizes one swing")
	check(is_equal_approx(float(single.startup) / clock, float(opener.startup)), label + " startup enters live action")
	check(is_equal_approx(float(single.active_end) / clock, float(opener.active_end)), label + " active end enters live action")
	check(is_equal_approx(float(single.reach), float(opener.reach)), label + " reach enters live geometry")
	var travel: PackedVector2Array = single["root_motion"]
	check(is_equal_approx(travel[1].x / clock, float(opener.advance_at))
		and is_equal_approx(travel[1].y, float(opener.advance_distance)), label + " exact contact displacement landmark")
	finish(state)
	var swing_time := real_time(state, 0.0)
	near_time(swing_time, float(opener.duration), label + " Attack serves source recovery")
	check(absf(state.player_pos.distance_to(origin) - float(opener.travel_at_move)) < 0.05, label + " exact clear attack travel through recovery")
	check(not state.advance_streamed_action_tick(), label + " held Attack stops advancing state after one strike")

	state = clear_dawn(style, loadout)
	var target := visible_target(state, Vector2(maxf(65.0, float(opener.reach) * 0.65), 0))
	check(state.request_commit_combo(int(target.id), false), label + " separate Combo accepts the visible target")
	var combo := state.player_action
	var order := []
	var starts := []
	var contacts := 0
	var previous_hp := int(target.hp)
	var cost := state.energy_spent_total
	for index in 1000:
		if not state.advance_streamed_action_tick(): break
		if int(combo.get("phase_index", -1)) >= order.size():
			order.append(int(combo.phase_index))
			starts.append(real_time(state, 0.0))
		if int(target.hp) < previous_hp: contacts += 1
		previous_hp = int(target.hp)
	var expected_time := 0.0
	for index in attacks.size():
		if index < starts.size() and index > 0:
			near_time(float(starts[index]), expected_time, label + " chain link " + str(index))
		expected_time += float(attacks[index].duration if index == attacks.size() - 1 else attacks[index].chain_at)
	var combo_time := real_time(state, 0.0)
	check(order.size() == attacks.size() and attacks.size() > 1, label + " live clock traverses all committed strikes")
	check(contacts == attacks.size(), label + " shared geometry lands once per swing")
	check(state.energy_spent_total == cost and is_equal_approx(cost, state.energy_cost(state.full_combo_raw_cost())), label + " full cost paid once")
	near_time(combo_time, expected_time, label + " Combo pays final recovery")
	check(state.is_player_ready() and not state.advance_streamed_action_tick(), label + " Combo stops at next decision")
	var phases: Array = combo["phases"]
	for index in range(phases.size() - 1):
		var landmarks: PackedVector2Array = phases[index]["root_motion"]
		check(is_equal_approx(landmarks[-1].x, float(phases[index + 1]["pose_start"]))
			and is_equal_approx(landmarks[-1].y, float(attacks[index].travel_at_chain)),
			label + " chained root travel ends at the reference link")
	print("PLAYER ", label, " move=", stats.move_speed, " roll=", snappedf(roll_time, 0.001),
		" attack=", snappedf(swing_time, 0.001), " combo=", snappedf(combo_time, 0.001),
		" strikes=", order.size(), " contacts=", contacts, " paid=", cost)

func ridge(style: String) -> void:
	var state := fresh(style)
	state.player_pos = Vector2(2290, 530)
	state.current_area_id = state._area_id_at_position(state.player_pos, state.current_layer)
	state._update_exploration(true)
	check(state.use_transition() and state.current_layer == Regions.RIDGE, style + " enters shared Ridge Stairs")
	var polearm := state._enemy_by_id(12000)
	check(not polearm.is_empty() and polearm.kind == "polearm" and polearm.spawn_pos == Vector2(2650, 540),
		style + " retains the same Ridge Stairs opponent")
	if polearm.is_empty(): return
	var first: Dictionary
	var decisions := 0
	var approach_decisions := 0
	var previous_distance := state.player_pos.distance_to(Vector2(polearm.pos))
	for index in 1800:
		if state.is_player_ready():
			if not first.is_empty(): break
			var distance := state.player_pos.distance_to(Vector2(polearm.pos))
			if distance > 100.0:
				state.request_move(state.player_pos.direction_to(Vector2(polearm.pos)), Campaign.MOVE_RANGE, false)
				approach_decisions += 1
			else:
				state.request_wait(0.32, false)
			decisions += 1
		if not state.advance_streamed_action_tick(): break
		if first.is_empty() and polearm.action.kind == "melee": first = polearm.action
	check(state.player_pos.distance_to(Vector2(polearm.pos)) < previous_distance, style + " closes through real movement")
	check(not first.is_empty() and decisions > 0, style + " complete approach reaches the first telegraph")
	if first.is_empty():
		print("RIDGE APPROACH ", style, " player=", state.player_pos, " position=", polearm.pos,
			" awareness=", polearm.awareness, " action=", polearm.action.kind, " context=", state.interaction_label())
		return
	if style != "default":
		var reference: Dictionary = EnemyProfiles.profile(style, "polearm")["attacks"][0]
		var clock := Campaign.EXECUTION_PLAYBACK_RATE * float(polearm.personal_tempo)
		var presage := float(first.startup) / clock
		near_time(presage, float(reference.startup), style + " Polearm consumes reference startup")
		check(is_equal_approx(float(first.advance_distance), float(reference.advance_distance)), style + " Polearm consumes reference advance")
		check(first.has("reference_travel"), style + " uses reference collision travel")
	else:
		check(not first.has("reference_travel"), style + " Polearm uses the stock action")
	var frozen := float(first.elapsed)
	var time := state.simulation_time
	check(not state.advance_streamed_action_tick() and float(first.elapsed) == frozen and state.simulation_time == time,
		style + " freezes live enemy telegraph between decisions")
	print("RIDGE ", style, " decisions=", decisions, " steps=", approach_decisions,
		" gap=", snappedf(state.player_pos.distance_to(Vector2(polearm.pos)), 0.1),
		" tell=", first.get("ability_id", "?"), " startup_sim=", first.startup)
	var path := "user://comparison-ridge-%s.save" % style
	var resumed := Campaign.new(false)
	check(state.save_run(path) and resumed.load_run(path), style + " saves and reloads during the frozen enemy tell")
	var restored := resumed._enemy_by_id(int(polearm.id))
	check(not restored.is_empty() and restored.action == first and resumed.rng.state == state.rng.state,
		style + " preserves the enemy commitment and follow-up random state")

func wall_contact() -> void:
	var state := clear_dawn("fast", "warrior")
	var wall := Rect2(590, 905, 40, 195)
	state.walls.append(wall)
	state._build_wall_spatial_index()
	var target := visible_target(state, Vector2(190, 0))
	check(state.request_direct_attack(Vector2.RIGHT, false), "Fast swing begins toward a solid wall")
	finish(state)
	check(state.player_pos.x < wall.position.x and int(target.hp) == int(target.max_hp),
		"weapon contact and root travel respect the blocking wall")
	check(state.request_defense(Vector2.RIGHT, false), "Fast roll begins toward a solid wall")
	finish(state)
	check(state.player_pos.x < wall.position.x, "Fast roll cannot cross the blocking wall")

func enemy_chains_and_spacing() -> void:
	for retreat in [false, true]:
		var state := clear_dawn("fast", "warrior")
		state.player_pos = Vector2(555, 1020)
		var enemy := visible_target(state, Vector2(100, 0))
		enemy.action = state._idle_action()
		var profile := EnemyProfiles.profile("fast", "blade")
		var source: Dictionary = profile["attacks"][0]
		check(state.request_wait(0.08, false), "blade opens during a normal Wait")
		state.advance_streamed_action_tick()
		var opener: Dictionary = enemy.action
		check(opener.get("comparison_strike", -1) == 0, "Fast Blade commits research opener")
		if not opener.has("reference_chain_at"): continue
		finish(state)
		if retreat:
			check(state.request_defense(Vector2.LEFT, false), "retreat commits a physical roll")
			finish(state)
		var observed_followup: Dictionary
		for index in 1500:
			if state.is_player_ready() and not state.request_wait(0.08, false): break
			if not state.advance_streamed_action_tick(): break
			if int(Dictionary(enemy.action).get("comparison_strike", -1)) == 1: observed_followup = enemy.action
			if not observed_followup.is_empty() or float(opener.elapsed) >= float(opener.duration): break
		if retreat:
			check(observed_followup.is_empty(), "Fast Blade loses its follow-up after leaving range")
			check(not opener.has("reference_chain_at"), "spacing failure is evaluated only once")
		else:
			check(not observed_followup.is_empty(), "Fast Blade launches a fresh follow-up in range")
			if not observed_followup.is_empty():
				near_time(float(opener.elapsed) / (Campaign.EXECUTION_PLAYBACK_RATE * float(enemy.personal_tempo)),
					float(source.chain_at), "Blade follow-up starts at the authored window")
				check(float(observed_followup.elapsed) == 0.0 and not bool(observed_followup.hit_done),
					"Blade follow-up has a new visible startup and hit state")
				check(state.damage_received_total > 0, "Blade opener deals damage through normal contact")
		print("FAST BLADE retreat=", retreat, " follow_up=", not observed_followup.is_empty(),
			" gap=", snappedf(state.player_pos.distance_to(Vector2(enemy.pos)), 0.1),
			" damage=", state.damage_received_total)

func frames(count: int) -> void:
	for index in count: await process_frame

func attack_event(board: Control, route: String, pressed: bool) -> void:
	var event: InputEvent
	if route == "keyboard":
		var key := InputEventKey.new()
		key.keycode = KEY_F
		key.physical_keycode = KEY_F
		key.pressed = pressed
		event = key
	elif route == "controller":
		var trigger := InputEventJoypadMotion.new()
		trigger.axis = JOY_AXIS_TRIGGER_RIGHT
		trigger.axis_value = 1.0 if pressed else 0.0
		event = trigger
	elif route == "mouse":
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = board.attack_rect.get_center()
		click.global_position = click.position
		click.pressed = pressed
		event = click
	else:
		var finger := InputEventScreenTouch.new()
		finger.index = 17
		finger.position = board.attack_rect.get_center()
		finger.pressed = pressed
		event = finger
	root.push_input(event, true)

func held_inputs() -> void:
	root.size = Vector2i(1280, 800)
	for style in STYLES:
		for route in ["keyboard", "mouse", "touch", "controller"]:
			set_meta(Session.REQUEST, {"entry": Session.campaign_entry(style), "loadout": "rogue_sharpshooter", "seed": SEED})
			var board := load("res://scenes/regional_campaign.tscn").instantiate() as Control
			root.add_child(board)
			await frames(8)
			var state: Campaign = board.state
			state._replace_enemy_actors([])
			var label := "%s %s" % [style, route]
			board.desktop_controls = route != "touch"
			board._layout()
			await frames(4)
			var cost := state.energy_cost(float(state.player_basic_attack_definition().energy_cost))
			attack_event(board, route, true)
			await frames(4)
			check(state.player_action.kind == "attack", label + " starts one Attack through root input")
			# Keep the same input held long beyond one action's recovery.
			await frames(180)
			var actual := state.energy_spent_total
			check(is_equal_approx(actual, cost) and state.is_player_ready(), label + " a held input buys exactly one strike")
			attack_event(board, route, false)
			await frames(6)
			attack_event(board, route, true)
			await frames(4)
			check(state.player_action.kind == "attack" and is_equal_approx(state.energy_spent_total, actual + cost),
				label + " a new press after release buys another strike")
			attack_event(board, route, false)
			await frames(140)
			board.queue_free()
			await frames(4)

func save_styles() -> void:
	var default_state := fresh("default")
	for style in ["default", "slow", "fast"]:
		var state := fresh(style, "rogue_sharpshooter")
		var name := "user://comparison-probe-%s.save" % style
		check(state.save_run(name), style + " saves in disposable fixture")
		var resumed := Campaign.new(false)
		resumed.combat_style = "slow" if style != "slow" else "fast"
		check(resumed.load_run(name) and resumed.combat_style == style, style + " restores recorded style")
		check(resumed.run_seed == state.run_seed and resumed.player_pos.is_equal_approx(state.player_pos), style + " restores Campaign seed and player position")
		check(resumed.encounter_templates == state.encounter_templates, style + " rebuilds same respawn roster")
		var seats: Array = state.encounter_templates[201]
		var expected: Array = {"default": ["shield", "knife"], "slow": ["shield", "blade"], "fast": ["blade", "knife"]}[style]
		for index in seats.size():
			check(seats[index]["kind"] == expected[index] and seats[index]["pos"] == default_state.encounter_templates[201][index]["pos"]
				and seats[index]["id"] == default_state.encounter_templates[201][index]["id"], style + " Windbreak seat preserves ID and location")
		check(resumed.floor_shapes == default_state.floor_shapes and resumed.transitions == default_state.transitions,
			style + " comparison uses the same floor and crossings")
	var legacy := default_state._build_save_payload()
	legacy.regional_campaign.erase("combat_style")
	var path := "user://comparison-probe-v1.save"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(legacy)
	file.close()
	var resumed := Campaign.new(false)
	resumed.combat_style = "fast"
	check(resumed.load_run(path) and resumed.combat_style == "default", "v1 Campaign without style loads as Default")
	check(resumed.encounter_templates == default_state.encounter_templates, "legacy roster preserved")

func run() -> void:
	var user_dir := OS.get_user_data_dir().replace("\\", "/")
	if not user_dir.contains("/.runtime/campaign-verification/"):
		printerr("Run the probe with disposable Campaign verification data.")
		quit(2)
		return
	for style in STYLES:
		for loadout in LOADOUTS:
			player_actions(style, loadout)
	for style in ["default", "slow", "fast"]:
		ridge(style)
	enemy_chains_and_spacing()
	wall_contact()
	save_styles()
	if OS.get_cmdline_user_args().has("input"): await held_inputs()
	print("CAMPAIGN COMPARISON ", checks, " checks ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
