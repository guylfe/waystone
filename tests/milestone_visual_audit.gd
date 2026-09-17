extends SceneTree

# Milestones A through D have only ever been verified headless: combo continuation, post-hit
# hyperarmor, attack capture and the Wait rework, and Sweeping Cut. The caster equivalent of
# this pass found five defects in one sitting -- two abilities with no wind-up drawn at all,
# a cone drawn as a circle, a caster nocking a bow it does not carry -- so the odds that
# four milestones of player-facing mechanics are clean without ever having been looked at
# are not good.
#
# RENDER-DEPENDENT. It captures real frames and cannot run under --headless, so it is not in
# run-tests.ps1's default list. Run it against a real renderer and read the PNGs:
#
#     .tools\\Godot_v4.7-stable_win64.exe --path . --script tests/milestone_visual_audit.gd
#
# Then look at builds/milestone-*.png. Not a pass/fail instrument and cannot be one -- no
# assertion can tell you a telegraph is unreadable. Its value is that it puts every
# player-facing state on screen in a handful of frames so a person can check them quickly
# rather than meeting them one at a time in play.

var board

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	board = load("res://scenes/main.tscn").instantiate()
	root.add_child(board)
	await process_frame
	await process_frame
	await _a_combo_continuation()
	await _b_post_hit_protection()
	await _c_capture_and_wait()
	await _d_sweeping_cut()
	await _the_unplayed_ox()
	await _f_warrior_vanguard_status()
	await _g_hound_vault()
	quit(0)

func _fresh(loadout: String, rules: String = "energy"):
	# Each authored frame is independent. Do not let the board-level banner from a
	# preceding cleared setup obscure the next visual subject.
	board.room_clear_remaining = 0.0
	board.room_clear_latched = false
	var s = board.state
	s.start_run(loadout, "combat_survey", 4242, "encounter", rules)
	s.enemies.clear()
	s.hazards.clear()
	s.projectiles.clear()
	s.barriers.clear()
	s.effects.clear()
	return s

func _put(s, kind: String, offset: Vector2, hp: int = 40):
	var e = s._make_enemy(kind, s.player_pos + offset, hp)
	e["awareness"] = "alerted"
	e["revealed_to_player"] = true
	e["revealed_elapsed"] = 5.0
	s.enemies.append(e)
	s._invalidate_active_enemy_cache()
	s._build_enemy_spatial_index()
	return e

func _shoot(path: String):
	board.visual = board._presentation_snapshot()
	board._layout()
	board.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://builds/%s.png" % path)

# --- A: a combo that continues because the input is live ---------------------------------
func _a_combo_continuation() -> void:
	var s = _fresh("warrior")
	_put(s, "blade", Vector2(150, -40), 35)
	s.request_combo(Vector2.RIGHT, false, true)
	var phases = Array(s.player_action["phases"])
	# Mid-swing on the opening cut: the arc should be visible and the held state legible.
	s.player_action["elapsed"] = float(Dictionary(phases[0])["startup"]) + 0.04
	await _shoot("milestone-a-combo-first")
	# The link point, where a held input decides whether the sequence carries on.
	s.player_action["elapsed"] = float(Dictionary(phases[0])["link"])
	s.player_action["phase_index"] = 0
	await _shoot("milestone-a-combo-link")

# --- B: being hit without losing your answer ----------------------------------------------
func _b_post_hit_protection() -> void:
	var s = _fresh("warrior")
	var blade = _put(s, "blade", Vector2(120, 0), 35)
	s.request_combo(Vector2.RIGHT, false)
	s.player_action["elapsed"] = 0.30
	s._resolve_incoming_hit(int(blade["id"]), 14, "blade", Vector2.RIGHT, s.player_pos + Vector2(30, 0))
	await _shoot("milestone-b-hit-reaction")
	# The protected window: a second hit lands and must not take the answer away.
	s._resolve_incoming_hit(int(blade["id"]), 14, "blade", Vector2.RIGHT, s.player_pos + Vector2(30, 0))
	await _shoot("milestone-b-protected")

# --- C: the capture window, and Wait ------------------------------------------------------
func _c_capture_and_wait() -> void:
	var s = _fresh("warrior")
	var boar = _put(s, "boar", Vector2(0, -300), 35)
	s._choose_enemy_action(boar)
	# A charge mid-wind-up is the telegraph the whole capture system is built to be read.
	boar["action"]["elapsed"] = float(Dictionary(boar["action"]).get("startup", 0.5)) * 0.7
	await _shoot("milestone-c-charge-windup")
	var w = _fresh("warrior")
	_put(w, "blade", Vector2(200, -60), 35)
	w.request_wait()
	await _shoot("milestone-c-wait")

# --- D: Sweeping Cut ----------------------------------------------------------------------
func _d_sweeping_cut() -> void:
	var s = _fresh("warrior")
	s.player_equipped_weapon_art = "prototype_sweeping_cut"
	for offset in [Vector2(130, -30), Vector2(120, 60), Vector2(60, 120)]:
		_put(s, "blade", offset, 35)
	s.request_skill(Vector2.RIGHT, false)
	s.player_action["elapsed"] = float(s.player_action["startup"]) + 0.05
	await _shoot("milestone-d-sweeping-cut")
	var d = _fresh("warrior")
	d.player_equipped_weapon_art = "prototype_drawing_cut"
	_put(d, "blade", Vector2(160, 0), 35)
	d.request_skill(Vector2.RIGHT, false)
	d.player_action["elapsed"] = float(d.player_action["startup"]) + 0.05
	await _shoot("milestone-d-drawing-cut")

# --- and the one kind nobody has ever seen in play ----------------------------------------
func _the_unplayed_ox() -> void:
	var s = _fresh("warrior")
	var ox = _put(s, "ox", Vector2(0, -320), 96)
	s._choose_enemy_action(ox)
	ox["action"]["elapsed"] = float(Dictionary(ox["action"]).get("startup", 0.6)) * 0.8
	await _shoot("milestone-e-ox-windup")
	# And mid-charge, which is the thing that makes it an Ox.
	for i in range(40):
		s._update_enemies(s.SIM_DT, i % 2 == 0)
		if String(Dictionary(ox.get("action", {})).get("kind", "")) != "charge": continue
		if float(Dictionary(ox["action"]).get("elapsed", 0.0)) > float(Dictionary(ox["action"]).get("startup", 0.5)) + 0.10: break
	await _shoot("milestone-e-ox-charge")

# --- F: 0.2.85 Warrior/Vanguard combat state ---------------------------------------------
func _f_warrior_vanguard_status() -> void:
	var s = _fresh("warrior")
	s.track_ranks["warrior"] = 5
	s.track_ranks["vanguard"] = 4
	s.rally_active = true
	s.battle_flow_pips = 4
	s.battle_flow_remaining = s.BATTLE_FLOW_DECAY_SECONDS * 0.72
	_put(s, "blade", Vector2(125, 0), 40)
	s.request_attack(s.player_pos + Vector2.RIGHT * 100.0, false)
	s.player_action["elapsed"] = float(s.player_action.get("startup", 0.0)) + 0.04
	await _shoot("milestone-f-warrior-vanguard-status")

# --- G: 0.2.90 Hound ally vault ----------------------------------------------------------
func _g_hound_vault() -> void:
	var s = _fresh("warrior")
	var knife = _put(s, "knife", Vector2(0, -150), 20)
	var hound = _put(s, "hound", Vector2(0, -150), 30)
	hound["action"] = s._enemy_charge_action(hound, 1.58, 0.70, 1.08, 500.0, 14, Vector2.DOWN)
	hound["action"]["label"] = "pounce"
	hound["action"]["elapsed"] = 0.89
	# The coincident world positions are deliberate: the frame must make the Hound
	# read as passing above the Knife rather than as two bodies clipping together.
	knife["facing"] = Vector2.DOWN
	await _shoot("milestone-g-hound-vault")
