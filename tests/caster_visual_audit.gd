extends SceneTree

# A deliberate visual pass over every caster ability. Four renderer bugs shipped in three
# versions -- a cone drawn as a circle, a caster drawing a bow it does not carry, an
# invisible bolt, an invisible circle -- and every one of them was a case of the simulation
# moving and the drawing staying where it was. Headless tests cannot see a shape, so this
# renders each ability and the shapes get looked at.
#
# RENDER-DEPENDENT. It captures real frames and cannot run under --headless, so it is not
# in run-tests.ps1's default list. Run it against a real renderer and read the PNGs:
#
#     .tools\Godot_v4.7-stable_win64.exe --path . --script tests/caster_visual_audit.gd
#
# Then look at builds/audit-*.png. This is not a pass/fail instrument and cannot be one --
# no assertion can tell you a cone was drawn as a circle. Its whole value is that it puts
# every caster ability on screen in seven frames so a person can check them in a minute
# rather than discovering them one at a time in play.

var board

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1280))
	board = load("res://scenes/main.tscn").instantiate()
	root.add_child(board)
	await process_frame
	await process_frame
	await _enemy_hazards()
	await _caster_poses()
	await _player_staff()
	await _player_spells()
	quit(0)

func _reset(loadout: String):
	var s = board.state
	s.start_run(loadout, "combat_survey", 4242, "encounter", "energy")
	s.enemies.clear()
	s.hazards.clear()
	s.barriers.clear()
	s.projectiles.clear()
	s.effects.clear()
	s.circle_remaining = 0.0
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
	board.visual = board.state.snapshot(true)
	board._layout()
	board.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://builds/%s.png" % path)

func _enemy_hazards() -> void:
	var s = _reset("warrior")
	var caster = _put(s, "ice_caster", Vector2(-300, -30))
	s._spawn_cold_front(caster, s.player_pos + Vector2(-300, 90))
	var earth = _put(s, "earth_caster", Vector2(300, -30))
	s._spawn_sundered_ground(s.player_pos + Vector2(300, 90), int(earth["id"]), s.current_layer)
	var air = _put(s, "air_caster", Vector2(0, -300))
	s._spawn_gale(air, s.player_pos + Vector2(0, -180))
	s._spawn_frost_lance(caster, Vector2.RIGHT)
	s.projectiles[0]["pos"] = s.player_pos + Vector2(-120, 200)
	for h in s.hazards: h["elapsed"] = float(h["trigger_at"]) * 0.75
	await _shoot("audit-a-hazards")

func _caster_poses() -> void:
	var s = _reset("warrior")
	var pairs = [["fire_caster", Vector2(-280, -120)], ["ice_caster", Vector2(280, -120)], ["earth_caster", Vector2(-280, 140)], ["air_caster", Vector2(280, 140)], ["chanter", Vector2(0, -280)]]
	for pair in pairs:
		var e = _put(s, String(pair[0]), Vector2(pair[1]))
		s._choose_enemy_action(e)
		e["action"]["elapsed"] = float(e["action"].get("startup", 0.6)) * 0.7
	await _shoot("audit-b-poses")

func _player_staff() -> void:
	var s = _reset("mage_elementalist")
	_put(s, "blade", Vector2(140, -40), 35)
	s.player_equipped_weapon_art = "staff_whirlwind"
	s.request_skill(Vector2.RIGHT, false)
	s.player_action["elapsed"] = float(s.player_action["startup"]) + 0.06
	await _shoot("audit-c-whirlwind")
	s = _reset("mage_elementalist")
	_put(s, "blade", Vector2(180, -40), 35)
	s.player_equipped_weapon_art = "staff_leg_sweep"
	s.request_skill(Vector2.RIGHT, false)
	s.player_action["elapsed"] = float(s.player_action["startup"]) + 0.06
	await _shoot("audit-c-legsweep")
	s = _reset("mage_elementalist")
	_put(s, "blade", Vector2(140, -40), 35)
	s.request_combo(Vector2.RIGHT, false)
	var phases = Array(s.player_action["phases"])
	s.player_action["elapsed"] = float(Dictionary(phases[2])["startup"]) + 0.08
	s.player_action["phase_index"] = 2
	await _shoot("audit-c-combo-spin")

func _player_spells() -> void:
	var s = _reset("mage_elementalist")
	s._apply_character_stage("element_fire", "fire_breath")
	s._resolve_player_spell("fire_breath", s.player_pos + Vector2(260, 0), Vector2.RIGHT)
	s._apply_character_stage("element_air", "gale")
	s._resolve_player_spell("gale", s.player_pos + Vector2(-240, -40), Vector2.LEFT)
	for h in s.hazards: h["elapsed"] = float(h["trigger_at"]) * 0.8
	s._resolve_player_spell("fireball", s.player_pos + Vector2(0, -260), Vector2.UP)
	if not s.projectiles.is_empty(): s.projectiles[0]["pos"] = s.player_pos + Vector2(0, -180)
	await _shoot("audit-d-player-spells")
	s = _reset("mage_elementalist")
	s._raise_player_earth_wall(s.player_pos + Vector2(0, -190))
	s._spawn_sundered_ground(s.player_pos + Vector2(250, 60), 0, s.current_layer)
	s._resolve_player_spell("frost_lance", s.player_pos + Vector2(-250, 60), Vector2.LEFT)
	if not s.projectiles.is_empty(): s.projectiles[0]["pos"] = s.player_pos + Vector2(-150, 40)
	for h in s.hazards: h["elapsed"] = float(h["trigger_at"]) * 0.8
	await _shoot("audit-d-earth-ice")
