class_name RunState
extends RefCounted

const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")

signal changed
signal message_changed(text: String)

const WORLD_SIZE := Vector2(1600.0, 2200.0)
const SIM_DT := 1.0 / 120.0
const FRAME_DT := 1.0 / 60.0
const PLAYER_RADIUS := 30.0
const ENEMY_RADIUS := 28.0
const PLAYER_MAX_HP := 10
const MOVE_SPEED := 320.0
const MOVE_RANGE := 34.0
const DODGE_SPEED := 560.0
const DODGE_COOLDOWN := 4.0
const BLOCK_COOLDOWN := 3.5
const ENDURE_COOLDOWN := 4.5
const SWEEP_COOLDOWN := 4.2
const ROOM_COUNT := 7
const NAV_CELL := 50.0

var player_pos := Vector2(800.0, 1900.0)
var player_facing := Vector2.UP
var player_hp := PLAYER_MAX_HP
var player_max_hp := PLAYER_MAX_HP
var player_move_speed := MOVE_SPEED
var player_attack_duration := 1.20
var player_attack_startup := 0.38
var player_attack_active_end := 0.68
var player_damage_min := 2
var player_damage_max := 3
var player_attack_technique := "diagonal_cut"
var player_attack_reach := 136.0
var player_attack_posture := 2.0
var loadout_id := "duelist"
var defense_id := "dodge"
var player_action := _idle_action()
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var walls: Array[Rect2] = []
var dodge_cooldown := 0.0
var block_cooldown := 0.0
var endure_cooldown := 0.0
var skill_cooldown := 0.0
var strength_remaining := 0.0
var potions := 1
var wave := 1
var wave_clear := false
var trial_complete := false
var run_seed := 739391
var upgrades: Array[String] = []
var upgrade_choices: Array[String] = []
var upgrade_pending := false
var rooms_cleared := 0
var enemies_defeated := 0
var damage_dealt := 0
var hazards: Array[Dictionary] = []
var simulation_time := 0.0
var perfect_dodges := 0
var counter_hits := 0
var successful_blocks := 0
var successful_endures := 0
var effects: Array[Dictionary] = []
var message := "Time is frozen. Choose an action."
var last_timeline: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var _next_enemy_id := 1
var navigation := AStarGrid2D.new()

func _init() -> void:
	rng.seed = run_seed
	_apply_loadout()
	player_hp = player_max_hp
	build_expedition_room()

func build_laboratory() -> void:
	build_expedition_room()

func build_expedition_room() -> void:
	rng.seed = run_seed + wave * 104729
	walls = _room_walls(wave)
	_build_navigation()
	hazards.clear()
	_next_enemy_id = 1
	_spawn_wave(wave)

func _room_walls(number: int) -> Array[Rect2]:
	match number % 5:
		1: return [Rect2(260.0, 720.0, 150.0, 500.0), Rect2(1190.0, 720.0, 150.0, 500.0), Rect2(650.0, 1320.0, 300.0, 120.0)]
		2: return [Rect2(180.0, 560.0, 430.0, 120.0), Rect2(990.0, 1110.0, 430.0, 120.0), Rect2(690.0, 790.0, 220.0, 270.0)]
		3: return [Rect2(665.0, 420.0, 270.0, 300.0), Rect2(665.0, 1130.0, 270.0, 300.0), Rect2(230.0, 900.0, 260.0, 110.0), Rect2(1110.0, 900.0, 260.0, 110.0)]
		4: return [Rect2(190.0, 840.0, 340.0, 120.0), Rect2(1070.0, 840.0, 340.0, 120.0), Rect2(700.0, 360.0, 200.0, 260.0), Rect2(700.0, 1270.0, 200.0, 260.0)]
		_: return [Rect2(330.0, 560.0, 160.0, 380.0), Rect2(1110.0, 560.0, 160.0, 380.0), Rect2(650.0, 1050.0, 300.0, 120.0), Rect2(310.0, 1370.0, 300.0, 110.0), Rect2(990.0, 1370.0, 300.0, 110.0)]

func _spawn_wave(number: int) -> void:
	enemies.clear()
	projectiles.clear()
	if number >= ROOM_COUNT:
		enemies.append(_make_enemy("warden", _find_spawn(Vector2(800.0, 300.0)), 26))
		return
	var budget := 3 + number * 2
	var maximum := 2 + int(ceil(float(number) * 0.55))
	var pool: Array[String] = ["blade", "knife"]
	if number >= 2: pool.append_array(["archer", "hound"])
	if number >= 4: pool.append_array(["polearm", "hexer"])
	if number >= 5: pool.append_array(["brute", "captain"])
	var costs := {"knife": 1, "blade": 2, "hound": 2, "archer": 2, "polearm": 4, "hexer": 4, "brute": 5, "captain": 5}
	var positions := [Vector2(800, 1600), Vector2(450, 1450), Vector2(1150, 1450), Vector2(330, 1120), Vector2(1270, 1120), Vector2(800, 930), Vector2(420, 720), Vector2(1180, 720)]
	var remaining := budget
	var count := 0
	var required_by_depth := {1: ["blade"], 2: ["hound"], 3: ["archer", "blade"], 4: ["hexer"], 5: ["captain"], 6: ["brute", "hexer"]}
	for required_kind in Array(required_by_depth.get(number, [])):
		var required := String(required_kind)
		enemies.append(_make_enemy(required, _find_spawn(positions[(count + number) % positions.size()]), _enemy_base_hp(required)))
		remaining -= int(costs[required])
		count += 1
	while remaining > 0 and count < maximum:
		var affordable: Array[String] = []
		for candidate in pool:
			if int(costs[candidate]) <= remaining: affordable.append(candidate)
		if affordable.is_empty(): break
		var kind := affordable[rng.randi_range(0, affordable.size() - 1)]
		enemies.append(_make_enemy(kind, _find_spawn(positions[(count + number) % positions.size()]), _enemy_base_hp(kind)))
		remaining -= int(costs[kind])
		count += 1
	if enemies.is_empty(): enemies.append(_make_enemy("blade", _find_spawn(Vector2(500, 260)), 7))

func _enemy_base_hp(kind: String) -> int:
	return {"knife": 4, "blade": 7, "hound": 6, "archer": 5, "shield": 10, "polearm": 12, "hexer": 7, "brute": 16, "captain": 12, "warden": 26}.get(kind, 7)

func _find_spawn(preferred: Vector2) -> Vector2:
	var candidates := [preferred, preferred + Vector2(130, 0), preferred + Vector2(-130, 0), preferred + Vector2(0, 150), Vector2(800, 260), Vector2(260, 520), Vector2(1340, 520)]
	for candidate in candidates:
		var blocked := false
		for wall in walls:
			if _circle_intersects_rect(candidate, 48.0, wall): blocked = true
		if not blocked and candidate.distance_to(player_pos) > 250.0: return candidate
	return Vector2(800, 180)

func _make_enemy(kind: String, position: Vector2, hp: int) -> Dictionary:
	var posture_max := _enemy_posture_max(kind)
	var enemy := {
		"id": _next_enemy_id,
		"kind": kind,
		"pos": position,
		"facing": Vector2.DOWN,
		"hp": hp,
		"max_hp": hp,
		"radius": 52.0 if kind == "warden" else 46.0 if kind == "brute" else 42.0 if kind == "polearm" else 25.0 if kind == "hound" else 22.0 if kind == "knife" else ENEMY_RADIUS,
		"posture": posture_max,
		"posture_max": posture_max,
		"posture_recovery_delay": 0.0,
		"action": _idle_action(),
	}
	_next_enemy_id += 1
	return enemy

func _enemy_posture_max(kind: String) -> float:
	return {"knife": 2.0, "hound": 3.0, "archer": 3.0, "hexer": 3.0, "blade": 5.0, "captain": 6.0, "shield": 8.0, "polearm": 8.0, "brute": 14.0, "warden": 18.0}.get(kind, 5.0)

func select_loadout(choice: String) -> bool:
	if not ["duelist", "guardian", "reaver"].has(choice):
		return false
	loadout_id = choice
	restart()
	return true

func _apply_loadout() -> void:
	match loadout_id:
		"guardian":
			defense_id = "block"
			player_max_hp = 14
			player_move_speed = 285.0
			player_attack_duration = 1.40
			player_attack_startup = 0.48
			player_attack_active_end = 0.82
			player_damage_min = 2
			player_damage_max = 4
			player_attack_technique = "heavy_chop"
			player_attack_reach = 142.0
			player_attack_posture = 3.5
		"reaver":
			defense_id = "endure"
			player_max_hp = 11
			player_move_speed = 305.0
			player_attack_duration = 1.50
			player_attack_startup = 0.55
			player_attack_active_end = 0.90
			player_damage_min = 3
			player_damage_max = 4
			player_attack_technique = "broad_sweep"
			player_attack_reach = 150.0
			player_attack_posture = 3.0
		_:
			defense_id = "dodge"
			player_max_hp = 9
			player_move_speed = 340.0
			player_attack_duration = 1.05
			player_attack_startup = 0.32
			player_attack_active_end = 0.58
			player_damage_min = 2
			player_damage_max = 3
			player_attack_technique = "diagonal_cut"
			player_attack_reach = 136.0
			player_attack_posture = 2.0

func _idle_action() -> Dictionary:
	return {
		"kind": "idle",
		"elapsed": 0.0,
		"duration": 0.0,
		"direction": Vector2.ZERO,
		"hit_done": false,
		"hit_ids": [],
		"effect_done": false,
		"perfect_triggered": false,
	}

func is_player_ready() -> bool:
	return String(player_action["kind"]) == "idle" and player_hp > 0

func request_move(direction: Vector2, distance: float = MOVE_RANGE) -> bool:
	if not is_player_ready() or wave_clear or trial_complete or direction.length_squared() < 0.01:
		return false
	var travel := clampf(distance, 4.0, MOVE_RANGE)
	var normalized := direction.normalized()
	player_facing = normalized
	player_action = _action("move", travel / player_move_speed, normalized)
	player_action["distance"] = travel
	player_action["speed"] = player_move_speed
	_set_message("You commit to a step.")
	_simulate_until_ready()
	return true

func request_move_to(target: Vector2) -> bool:
	var delta := target - player_pos
	return request_move(delta, minf(delta.length(), MOVE_RANGE))

func request_attack(target: Vector2) -> bool:
	if not is_player_ready() or wave_clear or trial_complete:
		return false
	var direction := target - player_pos
	if direction.length_squared() < 0.01:
		direction = player_facing
	player_facing = direction.normalized()
	player_action = _melee_action(player_attack_duration, player_attack_startup, player_attack_active_end, player_attack_reach, player_damage_max, player_facing, player_attack_technique, "attack")
	player_action["damage_min"] = player_damage_min
	player_action["damage_max"] = player_damage_max
	player_action["posture_damage"] = player_attack_posture
	_set_message("You commit to the %s." % AttackGeometryScript.label(player_attack_technique).to_lower())
	_simulate_until_ready()
	return true

func request_skill(direction: Vector2) -> bool:
	if loadout_id != "duelist": return false
	return request_sweeping_cut(direction)

func request_sweeping_cut(direction: Vector2) -> bool:
	if not is_player_ready() or wave_clear or trial_complete or upgrade_pending or skill_cooldown > 0.0001 or direction.length_squared() < 0.01:
		return false
	player_facing = direction.normalized()
	player_action = _melee_action(1.32, 0.44, 0.84, 158.0, 3, player_facing, "broad_sweep", "sweep")
	player_action["posture_damage"] = 5.0
	player_action["damage_min"] = 2
	player_action["damage_max"] = 3
	skill_cooldown = maxf(2.0, SWEEP_COOLDOWN - upgrades.count("relentless"))
	_set_message("You commit to a broad, posture-breaking cut.")
	_simulate_until_ready()
	return true

func request_dodge(direction: Vector2) -> bool:
	if not is_player_ready() or wave_clear or trial_complete or dodge_cooldown > 0.0001 or direction.length_squared() < 0.01:
		return false
	player_facing = direction.normalized()
	player_action = _action("dodge", 0.66, player_facing)
	player_action["speed"] = DODGE_SPEED
	dodge_cooldown = DODGE_COOLDOWN
	_set_message("You commit to a dodge.")
	_simulate_until_ready()
	return true

func request_block(direction: Vector2) -> bool:
	if not is_player_ready() or wave_clear or trial_complete or block_cooldown > 0.0001 or direction.length_squared() < 0.01:
		return false
	player_facing = direction.normalized()
	player_action = _action("block", 1.10, player_facing)
	player_action["startup"] = 0.16
	player_action["active_end"] = 0.78
	block_cooldown = BLOCK_COOLDOWN
	_set_message("You commit to a directional guard.")
	_simulate_until_ready()
	return true

func request_endure(direction: Vector2) -> bool:
	if not is_player_ready() or wave_clear or trial_complete or endure_cooldown > 0.0001:
		return false
	if direction.length_squared() > 0.01:
		player_facing = direction.normalized()
	player_action = _action("endure", 1.05, player_facing)
	player_action["startup"] = 0.14
	player_action["active_end"] = 0.72
	endure_cooldown = ENDURE_COOLDOWN
	_set_message("You brace to turn pain into strength.")
	_simulate_until_ready()
	return true

func request_defense(direction: Vector2) -> bool:
	match defense_id:
		"block": return request_block(direction)
		"endure": return request_endure(direction)
		_: return request_dodge(direction)

func request_potion() -> bool:
	if not is_player_ready() or potions <= 0 or player_hp >= player_max_hp:
		return false
	potions -= 1
	player_action = _action("potion", 0.72, Vector2.ZERO)
	_set_message("You uncork the last restorative.")
	_simulate_until_ready()
	return true

func request_wait(duration: float = 0.50) -> bool:
	if not is_player_ready() or wave_clear or trial_complete:
		return false
	player_action = _action("wait", clampf(duration, 0.1, 1.0), Vector2.ZERO)
	_set_message("You deliberately surrender time.")
	_simulate_until_ready()
	return true

func advance_wave() -> bool:
	if not is_player_ready() or not wave_clear or trial_complete or upgrade_pending:
		return false
	if wave >= ROOM_COUNT:
		trial_complete = true
		_set_message("Expedition complete. The Warden is defeated.")
		changed.emit()
		return true
	wave += 1
	wave_clear = false
	player_hp = mini(player_max_hp, player_hp + 2)
	potions = 1
	player_pos = Vector2(800.0, 1900.0)
	player_facing = Vector2.UP
	build_expedition_room()
	_set_message("Room %d begins." % wave)
	changed.emit()
	return true

func choose_upgrade(choice: String) -> bool:
	if not upgrade_pending or not upgrade_choices.has(choice): return false
	upgrades.append(choice)
	match choice:
		"keen_edge": player_damage_max += 1
		"vitality":
			player_max_hp += 2
			player_hp += 2
		"quick_hands":
			player_attack_duration = maxf(player_attack_active_end + 0.16, player_attack_duration - 0.12)
		"long_blade": pass
		"relentless": pass
		"restoration": player_hp = mini(player_max_hp, player_hp + 5)
	upgrade_pending = false
	upgrade_choices.clear()
	_set_message("Upgrade gained: %s. Enter the next room." % upgrade_name(choice))
	changed.emit()
	return true

func upgrade_name(id: String) -> String:
	return {"keen_edge": "Keen Edge", "vitality": "Vitality", "quick_hands": "Quick Hands", "long_blade": "Long Blade", "relentless": "Relentless", "restoration": "Restoration"}.get(id, id.capitalize())

func upgrade_description(id: String) -> String:
	return {"keen_edge": "+1 maximum damage", "vitality": "+2 maximum health", "quick_hands": "Shorter attack recovery", "long_blade": "+22 attack reach", "relentless": "Sweep cools faster", "restoration": "Recover 5 health"}.get(id, "")

func _roll_upgrade_choices() -> void:
	var pool: Array[String] = ["keen_edge", "vitality", "quick_hands", "long_blade", "restoration"]
	if loadout_id == "duelist": pool.append("relentless")
	for index in range(pool.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = temporary
	upgrade_choices.assign(pool.slice(0, 3))
	upgrade_pending = true

func _action(kind: String, duration: float, direction: Vector2) -> Dictionary:
	var result := _idle_action()
	result["kind"] = kind
	result["duration"] = duration
	result["direction"] = direction
	return result

func _simulate_until_ready() -> void:
	last_timeline.clear()
	last_timeline.append(snapshot())
	var frame_accumulator := 0.0
	var guard := 0
	while String(player_action["kind"]) != "idle" and player_hp > 0 and guard < 1000:
		_tick(SIM_DT)
		frame_accumulator += SIM_DT
		if frame_accumulator + 0.00001 >= FRAME_DT:
			last_timeline.append(snapshot())
			frame_accumulator = 0.0
		guard += 1
	if last_timeline.is_empty() or float(last_timeline[-1]["time"]) != simulation_time:
		last_timeline.append(snapshot())
	changed.emit()

func _tick(dt: float) -> void:
	simulation_time += dt
	dodge_cooldown = maxf(0.0, dodge_cooldown - dt)
	block_cooldown = maxf(0.0, block_cooldown - dt)
	endure_cooldown = maxf(0.0, endure_cooldown - dt)
	skill_cooldown = maxf(0.0, skill_cooldown - dt)
	strength_remaining = maxf(0.0, strength_remaining - dt)
	_update_effects(dt)
	_update_player(dt)
	_update_enemies(dt)
	_update_projectiles(dt)
	_update_hazards(dt)
	_remove_dead_enemies()

func _update_player(dt: float) -> void:
	var kind := String(player_action["kind"])
	if kind == "idle":
		return
	player_action["elapsed"] = float(player_action["elapsed"]) + dt
	var elapsed := float(player_action["elapsed"])
	match kind:
		"move":
			player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, PLAYER_RADIUS, 0)
		"dodge":
			if elapsed >= 0.08 and elapsed <= 0.38:
				player_pos = _move_actor(player_pos, Vector2(player_action["direction"]) * float(player_action["speed"]) * dt, PLAYER_RADIUS, 0)
		"attack":
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				_resolve_player_attack_tick(elapsed)
		"sweep":
			if elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"]):
				_resolve_player_attack_tick(elapsed)
		"potion":
			if elapsed >= 0.28 and not bool(player_action["effect_done"]):
				player_action["effect_done"] = true
				player_hp = mini(player_max_hp, player_hp + 5)
				_set_message("Warmth returns to your limbs.")
	if elapsed + 0.00001 >= float(player_action["duration"]):
		if kind in ["attack", "sweep"] and Array(player_action["hit_ids"]).is_empty():
			_set_message("Your cut finds only air.")
		elif kind == "block" and not bool(player_action["effect_done"]):
			_set_message("You lower the guard without contact.")
		elif kind == "endure" and not bool(player_action["effect_done"]):
			_set_message("The Endure window passes without a hit.")
		player_action = _idle_action()

func _resolve_player_attack_tick(elapsed: float) -> void:
	var is_sweep := String(player_action["kind"]) == "sweep"
	var sampled_action := player_action.duplicate()
	if upgrades.has("long_blade"): sampled_action["reach"] = float(sampled_action["reach"]) + 22.0
	var sample: Dictionary = AttackGeometryScript.pose(sampled_action, player_pos, player_facing, walls)
	if not bool(sample.get("multi", false)) and bool(player_action.get("hit_done", false)): return
	var hit_ids: Array = player_action["hit_ids"]
	var contacts: Array[Dictionary] = []
	for enemy in enemies:
		var enemy_id := int(enemy["id"])
		if hit_ids.has(enemy_id): continue
		if AttackGeometryScript.hits_circle(sample, Vector2(enemy["pos"]), float(enemy["radius"])):
			contacts.append({"enemy": enemy, "order": AttackGeometryScript.contact_order(sample, Vector2(enemy["pos"])), "point": AttackGeometryScript.contact_point(sample, Vector2(enemy["pos"]))})
	contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["order"]) < float(b["order"]))
	if not bool(sample.get("multi", false)) and contacts.size() > 1: contacts.resize(1)
	if not bool(sample.get("multi", false)) and not contacts.is_empty(): player_action["hit_done"] = true
	for contact in contacts:
		var enemy: Dictionary = contact["enemy"]
		hit_ids.append(int(enemy["id"]))
		var hit_point := Vector2(contact["point"])
		if _enemy_blocks_attack(enemy):
			_apply_posture_damage(enemy, 2.0 if is_sweep else 0.5)
			_add_effect("block", hit_point)
			_set_message("The shield catches your weapon.")
		else:
			var bonus := 2 if strength_remaining > 0.0 else 0
			var damage_min := int(player_action.get("damage_min", player_damage_min))
			var damage_max := int(player_action.get("damage_max", player_damage_max))
			var dealt := rng.randi_range(damage_min + bonus, damage_max + bonus)
			enemy["hp"] = int(enemy["hp"]) - dealt
			damage_dealt += dealt
			_apply_posture_damage(enemy, float(player_action.get("posture_damage", 2.0)))
			_add_effect("hit", hit_point, dealt)
			_set_message("The %s connects." % AttackGeometryScript.label(String(player_action.get("technique_id", "diagonal_cut"))).to_lower())
	player_action["hit_ids"] = hit_ids

func _enemy_blocks_attack(enemy: Dictionary) -> bool:
	if String(enemy["kind"]) != "shield": return false
	var incoming := player_pos - Vector2(enemy["pos"])
	return _within_arc(Vector2(enemy["facing"]), incoming, deg_to_rad(72.0))

func _apply_posture_damage(enemy: Dictionary, amount: float) -> void:
	if amount <= 0.0 or int(enemy["hp"]) <= 0: return
	enemy["posture"] = maxf(0.0, float(enemy.get("posture", 1.0)) - amount)
	enemy["posture_recovery_delay"] = 1.15
	if float(enemy["posture"]) <= 0.0001:
		_break_posture(enemy)

func _break_posture(enemy: Dictionary) -> void:
	var action: Dictionary = enemy["action"]
	var kind := String(enemy["kind"])
	var action_kind := String(action.get("kind", "idle"))
	var elapsed := float(action.get("elapsed", 0.0))
	var active_started := action.has("startup") and elapsed >= float(action.get("startup", 999.0))
	if kind in ["brute", "warden"] and active_started and action_kind in ["melee", "slam", "charge"]:
		enemy["posture"] = 0.25
		_add_effect("strain", Vector2(enemy["pos"]))
		_set_message("The heavy enemy holds its grounded attack.")
		return
	var stagger_duration := 0.52 if kind in ["knife", "hound"] else 0.66 if kind in ["archer", "hexer"] else 0.78
	enemy["action"] = _action("stagger", stagger_duration, Vector2.ZERO)
	enemy["posture"] = 0.0
	enemy["posture_recovery_delay"] = stagger_duration
	_add_effect("posture_break", Vector2(enemy["pos"]))
	_set_message("The %s loses its footing." % kind)

func _update_enemies(dt: float) -> void:
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if int(enemy["hp"]) <= 0:
			continue
		enemy["posture_recovery_delay"] = maxf(0.0, float(enemy.get("posture_recovery_delay", 0.0)) - dt)
		if float(enemy["posture_recovery_delay"]) <= 0.0 and String(Dictionary(enemy["action"])["kind"]) == "idle":
			enemy["posture"] = minf(float(enemy["posture_max"]), float(enemy["posture"]) + dt * 1.8)
		var action: Dictionary = enemy["action"]
		if String(action["kind"]) == "idle":
			_choose_enemy_action(enemy)
			action = enemy["action"]
		action["elapsed"] = float(action["elapsed"]) + dt
		var kind := String(action["kind"])
		var elapsed := float(action["elapsed"])
		if kind == "move":
			var speed := _enemy_move_speed(enemy)
			enemy["pos"] = _move_actor(Vector2(enemy["pos"]), Vector2(action["direction"]) * speed * dt, float(enemy["radius"]), int(enemy["id"]))
		elif kind == "melee" and elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]) and not bool(action["hit_done"]):
			_resolve_enemy_melee_tick(enemy, elapsed)
		elif kind == "charge" and elapsed >= float(action["startup"]) and elapsed <= float(action["active_end"]):
			var charge_origin := Vector2(enemy["pos"])
			enemy["pos"] = _move_actor(charge_origin, Vector2(action["direction"]) * float(action.get("speed", 340.0)) * dt, float(enemy["radius"]), int(enemy["id"]))
			if Vector2(enemy["pos"]).is_equal_approx(charge_origin):
				enemy["action"] = _action("stagger", 0.62, Vector2.ZERO)
				enemy["posture"] = maxf(0.0, float(enemy["posture"]) - 1.0)
				_add_effect("posture_break", charge_origin)
				_set_message("The %s crashes into an obstacle." % String(enemy["kind"]))
				enemies[index] = enemy
				continue
			if not bool(action["hit_done"]) and Vector2(enemy["pos"]).distance_to(player_pos) <= float(enemy["radius"]) + PLAYER_RADIUS + 8.0:
				action["hit_done"] = true
				_resolve_incoming_hit(int(enemy["id"]), int(action.get("damage", 2)), String(enemy["kind"]))
		elif kind == "slam" and elapsed >= float(action["startup"]) and not bool(action["hit_done"]):
			action["hit_done"] = true
			_add_effect("slam", Vector2(enemy["pos"]))
			if Vector2(enemy["pos"]).distance_to(player_pos) <= float(action.get("reach", 205.0)):
				_resolve_incoming_hit(int(enemy["id"]), int(action.get("damage", 4)), String(enemy["kind"]))
		elif kind == "shoot" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_projectile(enemy)
		elif kind == "hex" and elapsed >= float(action["startup"]) and not bool(action["effect_done"]):
			action["effect_done"] = true
			_spawn_hex(enemy, Vector2(action["target"]))
		if elapsed + 0.00001 >= float(action["duration"]):
			if kind == "stagger": enemy["posture"] = float(enemy["posture_max"])
			enemy["action"] = _idle_action()
		enemies[index] = enemy

func _choose_enemy_action(enemy: Dictionary) -> void:
	var offset := player_pos - Vector2(enemy["pos"])
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.01 else Vector2.DOWN
	enemy["facing"] = direction
	var enemy_kind := String(enemy["kind"])
	if enemy_kind == "blade":
		if distance <= 125.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(1.45, 0.52, 0.82, 128.0, 2, direction, "diagonal_cut")
		else:
			enemy["action"] = _action("move", 0.48, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "knife":
		if distance <= 92.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(0.88, 0.28, 0.46, 92.0, 1, direction, "quick_cut")
		else:
			enemy["action"] = _action("move", 0.32, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "polearm":
		if distance <= 218.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _melee_action(2.25, 0.90, 1.35, 218.0, 3, direction, "thrust")
		else:
			enemy["action"] = _action("move", 0.70, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "shield":
		if distance <= 120.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(1.65, 0.62, 0.92, 122.0, 2, direction)
		else: enemy["action"] = _action("move", 0.58, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "hound":
		if distance <= 330.0 and distance >= 82.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _charge_action(1.28, 0.42, 0.78, 405.0, 2, direction)
		elif distance < 82.0: enemy["action"] = _melee_action(0.95, 0.28, 0.48, 88.0, 1, direction, "bite")
		else: enemy["action"] = _action("move", 0.38, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "brute":
		if distance <= 155.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(2.55, 1.02, 1.52, 158.0, 4, direction, "forward_smash")
		else: enemy["action"] = _action("move", 0.78, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "captain":
		if distance <= 138.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos): enemy["action"] = _melee_action(1.22, 0.42, 0.70, 140.0, 2, direction, "thrust")
		else: enemy["action"] = _action("move", 0.44, _navigation_direction(enemy, player_pos))
	elif enemy_kind == "hexer":
		if distance <= 620.0 and distance >= 150.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("hex", 1.85, direction)
			enemy["action"]["startup"] = 0.68
			enemy["action"]["target"] = player_pos + player_facing * 24.0
		else:
			var target := Vector2(enemy["pos"]) + direction.rotated(PI * 0.5 if int(enemy["id"]) % 2 == 0 else -PI * 0.5) * 220.0 if distance < 500.0 else player_pos
			enemy["action"] = _action("move", 0.52, _navigation_direction(enemy, target))
	elif enemy_kind == "warden":
		if distance <= 215.0:
			if rng.randf() < 0.46:
				enemy["action"] = _action("slam", 2.45, direction)
				enemy["action"]["startup"] = 1.02
				enemy["action"]["active_end"] = 1.22
				enemy["action"]["reach"] = 215.0
				enemy["action"]["damage"] = 4
			else: enemy["action"] = _melee_action(2.15, 0.76, 1.30, 205.0, 4, direction, "heavy_cleave")
		elif distance <= 520.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _charge_action(1.80, 0.62, 1.05, 300.0, 4, direction)
		else: enemy["action"] = _action("move", 0.72, _navigation_direction(enemy, player_pos))
	else:
		if distance <= 690.0 and distance >= 230.0 and _has_line_of_sight(Vector2(enemy["pos"]), player_pos):
			enemy["action"] = _action("shoot", 1.75, direction)
			enemy["action"]["startup"] = 0.72
		else:
			var move_target := player_pos if distance > 520.0 else Vector2(enemy["pos"]) - direction * 240.0
			var move_direction := _navigation_direction(enemy, move_target)
			enemy["facing"] = direction
			enemy["action"] = _action("move", 0.56, move_direction)

func _enemy_move_speed(enemy: Dictionary) -> float:
	var kind := String(enemy["kind"])
	var speed: float = float({"knife": 230.0, "blade": 175.0, "polearm": 95.0, "archer": 135.0, "shield": 120.0, "hound": 245.0, "brute": 82.0, "hexer": 125.0, "captain": 180.0, "warden": 105.0}.get(kind, 135.0))
	if kind != "captain" and _captain_alive(): speed *= 1.14
	return speed

func _captain_alive() -> bool:
	for enemy in enemies:
		if String(enemy["kind"]) == "captain" and int(enemy["hp"]) > 0: return true
	return false

func _charge_action(duration: float, startup: float, active_end: float, speed: float, damage: int, direction: Vector2) -> Dictionary:
	var result := _action("charge", duration, direction)
	result["startup"] = startup
	result["active_end"] = active_end
	result["speed"] = speed
	result["damage"] = damage
	return result

func _resolve_enemy_melee_tick(enemy: Dictionary, elapsed: float) -> void:
	var action: Dictionary = enemy["action"]
	var sample: Dictionary = AttackGeometryScript.pose(action, Vector2(enemy["pos"]), Vector2(enemy["facing"]), walls)
	if AttackGeometryScript.hits_circle(sample, player_pos, PLAYER_RADIUS):
		enemy["action"]["hit_done"] = true
		var contact := AttackGeometryScript.contact_point(sample, player_pos)
		_resolve_incoming_hit(int(enemy["id"]), int(action["damage"]), String(enemy["kind"]), Vector2.ZERO, contact)

func _melee_action(duration: float, startup: float, active_end: float, reach: float, damage: int, direction: Vector2, technique_id: String = "diagonal_cut", action_kind: String = "melee") -> Dictionary:
	var result := _action(action_kind, duration, direction)
	result["startup"] = startup
	result["active_end"] = active_end
	result["reach"] = reach
	result["damage"] = damage
	result["technique_id"] = technique_id
	return result

func _spawn_projectile(enemy: Dictionary) -> void:
	var direction: Vector2 = Vector2(enemy["facing"]).normalized()
	projectiles.append({
		"pos": Vector2(enemy["pos"]) + direction * 42.0,
		"vel": direction * 470.0,
		"radius": 9.0,
		"damage": 2,
		"source_id": int(enemy["id"]),
	})

func _spawn_hex(enemy: Dictionary, target: Vector2) -> void:
	hazards.append({"kind": "hex", "pos": target, "radius": 100.0, "elapsed": 0.0, "trigger_at": 0.82, "duration": 1.12, "damage": 2, "source_id": int(enemy["id"]), "triggered": false})
	_set_message("A hex gathers beneath you.")

func _update_hazards(dt: float) -> void:
	var survivors: Array[Dictionary] = []
	for hazard in hazards:
		hazard["elapsed"] = float(hazard["elapsed"]) + dt
		if not bool(hazard["triggered"]) and float(hazard["elapsed"]) >= float(hazard["trigger_at"]):
			hazard["triggered"] = true
			_add_effect("hex", Vector2(hazard["pos"]))
			if player_pos.distance_to(Vector2(hazard["pos"])) <= float(hazard["radius"]):
				_resolve_incoming_hit(int(hazard["source_id"]), int(hazard["damage"]), "hex", Vector2(hazard["pos"]) - player_pos)
		if float(hazard["elapsed"]) < float(hazard["duration"]): survivors.append(hazard)
	hazards = survivors

func _update_projectiles(dt: float) -> void:
	var survivors: Array[Dictionary] = []
	for projectile in projectiles:
		var start: Vector2 = projectile["pos"]
		var finish := start + Vector2(projectile["vel"]) * dt
		projectile["pos"] = finish
		if not _inside_world(finish, float(projectile["radius"])) or _point_in_wall(finish):
			continue
		if _segment_distance_to_point(start, finish, player_pos) <= PLAYER_RADIUS + float(projectile["radius"]):
			_resolve_incoming_hit(int(projectile["source_id"]), int(projectile["damage"]), "arrow", -Vector2(projectile["vel"]).normalized())
			continue
		survivors.append(projectile)
	projectiles = survivors

func _resolve_incoming_hit(source_id: int, damage: int, source_name: String, incoming_from: Vector2 = Vector2.ZERO, contact_position: Vector2 = Vector2.INF) -> void:
	var impact := player_pos if not contact_position.is_finite() else contact_position
	if _is_perfect_dodge():
		perfect_dodges += 1
		if not bool(player_action["perfect_triggered"]):
			player_action["perfect_triggered"] = true
			_counter_source(source_id)
		_add_effect("perfect", impact)
		_set_message("Perfect dodge.")
		return
	if _is_blocking(source_id, incoming_from):
		successful_blocks += 1
		player_action["effect_done"] = true
		var chip_damage := 1 if damage >= 3 else 0
		player_hp = maxi(0, player_hp - chip_damage)
		_add_effect("block", impact, chip_damage)
		if chip_damage > 0:
			_set_message("The heavy blow crashes through part of your guard.")
		else:
			_set_message("Your guard catches the %s." % source_name)
		return
	if _is_enduring():
		successful_endures += 1
		player_action["effect_done"] = true
		var endured_damage := maxi(1, int(ceil(float(damage) * 0.70)))
		player_hp = maxi(0, player_hp - endured_damage)
		strength_remaining = maxf(strength_remaining, 5.0)
		_add_effect("endure", impact, endured_damage)
		_set_message("You take the hit and gain Strength for 5 seconds.")
		if player_hp <= 0:
			player_action = _idle_action()
			_set_message("You have fallen. Use Reset to try again.")
		return
	if _is_evasive():
		_add_effect("evade", impact)
		_set_message("The %s misses your evasive movement." % source_name)
		return
	player_hp = maxi(0, player_hp - damage)
	_add_effect("hurt", impact, damage)
	_set_message("The %s hits during your commitment." % source_name)
	if player_hp <= 0:
		player_action = _idle_action()
		_set_message("You have fallen. Use Reset to begin a new expedition.")

func _counter_source(source_id: int) -> void:
	for enemy in enemies:
		if int(enemy["id"]) == source_id and Vector2(enemy["pos"]).distance_to(player_pos) <= 155.0:
			enemy["hp"] = int(enemy["hp"]) - 2
			_add_effect("hit", Vector2(enemy["pos"]), 2)
			counter_hits += 1
			return

func _is_evasive() -> bool:
	if String(player_action["kind"]) != "dodge":
		return false
	var elapsed := float(player_action["elapsed"])
	return elapsed >= 0.08 and elapsed <= 0.38

func _is_perfect_dodge() -> bool:
	if String(player_action["kind"]) != "dodge":
		return false
	var elapsed := float(player_action["elapsed"])
	return elapsed >= 0.18 and elapsed <= 0.26

func _is_blocking(source_id: int, incoming_from: Vector2 = Vector2.ZERO) -> bool:
	if String(player_action["kind"]) != "block":
		return false
	var elapsed := float(player_action["elapsed"])
	if elapsed < float(player_action["startup"]) or elapsed > float(player_action["active_end"]):
		return false
	if incoming_from.length_squared() > 0.01:
		return _within_arc(player_facing, incoming_from, deg_to_rad(65.0))
	for enemy in enemies:
		if int(enemy["id"]) == source_id:
			var incoming := Vector2(enemy["pos"]) - player_pos
			return _within_arc(player_facing, incoming, deg_to_rad(65.0))
	return false

func _is_enduring() -> bool:
	if String(player_action["kind"]) != "endure":
		return false
	var elapsed := float(player_action["elapsed"])
	return elapsed >= float(player_action["startup"]) and elapsed <= float(player_action["active_end"])

func _update_effects(dt: float) -> void:
	var active: Array[Dictionary] = []
	for effect in effects:
		effect["elapsed"] = float(effect["elapsed"]) + dt
		if float(effect["elapsed"]) < float(effect["duration"]):
			active.append(effect)
	effects = active

func _add_effect(kind: String, position: Vector2, amount: int = 0) -> void:
	var duration := 0.62 if kind in ["hit", "hurt", "endure"] else 0.42
	effects.append({"kind": kind, "pos": position, "elapsed": 0.0, "duration": duration, "amount": amount})

func _remove_dead_enemies() -> void:
	var had_enemies := not enemies.is_empty()
	var living: Array[Dictionary] = []
	for enemy in enemies:
		if int(enemy["hp"]) > 0:
			living.append(enemy)
		else:
			enemies_defeated += 1
			_set_message("The %s falls." % String(enemy["kind"]))
	enemies = living
	if had_enemies and enemies.is_empty() and player_hp > 0:
		wave_clear = true
		projectiles.clear()
		hazards.clear()
		rooms_cleared = maxi(rooms_cleared, wave)
		if wave >= ROOM_COUNT:
			_set_message("The Warden falls. Tap COMPLETE.")
		else:
			_roll_upgrade_choices()
			_set_message("Room %d clear. Choose an upgrade." % wave)

func _build_navigation() -> void:
	var columns := int(ceil(WORLD_SIZE.x / NAV_CELL))
	var rows := int(ceil(WORLD_SIZE.y / NAV_CELL))
	navigation = AStarGrid2D.new()
	navigation.region = Rect2i(0, 0, columns, rows)
	navigation.cell_size = Vector2(NAV_CELL, NAV_CELL)
	navigation.offset = Vector2(NAV_CELL * 0.5, NAV_CELL * 0.5)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for x in range(columns):
		for y in range(rows):
			var cell := Vector2i(x, y)
			var center := navigation.get_point_position(cell)
			var solid := false
			for wall in walls:
				if _circle_intersects_rect(center, 34.0, wall):
					solid = true
					break
			navigation.set_point_solid(cell, solid)

func _navigation_direction(enemy: Dictionary, target: Vector2) -> Vector2:
	var origin := Vector2(enemy["pos"])
	var direct := (target - origin).normalized()
	if navigation.region.size == Vector2i.ZERO: return direct
	var from_cell := _nearest_open_cell(_world_to_nav(origin))
	var target_cell := _nearest_open_cell(_world_to_nav(target))
	var path := navigation.get_id_path(from_cell, target_cell, true)
	var desired := direct
	if path.size() >= 2: desired = (navigation.get_point_position(path[1]) - origin).normalized()
	elif path.size() == 1: desired = direct
	return _local_avoidance_direction(enemy, desired)

func _world_to_nav(position: Vector2) -> Vector2i:
	var cell := Vector2i(int(floor(position.x / NAV_CELL)), int(floor(position.y / NAV_CELL)))
	return Vector2i(clampi(cell.x, navigation.region.position.x, navigation.region.end.x - 1), clampi(cell.y, navigation.region.position.y, navigation.region.end.y - 1))

func _nearest_open_cell(origin: Vector2i) -> Vector2i:
	if navigation.is_in_boundsv(origin) and not navigation.is_point_solid(origin): return origin
	for radius in range(1, 6):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				var candidate := Vector2i(x, y)
				if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate): return candidate
	return Vector2i.ZERO

func _local_avoidance_direction(enemy: Dictionary, desired: Vector2) -> Vector2:
	if desired.length_squared() < 0.001: return Vector2.ZERO
	var origin := Vector2(enemy["pos"])
	var radius := float(enemy["radius"])
	var actor_id := int(enemy["id"])
	for angle in [0.0, 0.55, -0.55, 1.05, -1.05, 1.55, -1.55]:
		var candidate := desired.rotated(float(angle)).normalized()
		if not _position_blocked(origin + candidate * 42.0, radius, actor_id): return candidate
	return Vector2.ZERO

func _move_actor(origin: Vector2, delta: Vector2, radius: float, actor_id: int) -> Vector2:
	var result := origin
	var candidate := Vector2(origin.x + delta.x, origin.y)
	if not _position_blocked(candidate, radius, actor_id):
		result.x = candidate.x
	candidate = Vector2(result.x, origin.y + delta.y)
	if not _position_blocked(candidate, radius, actor_id):
		result.y = candidate.y
	return result

func _position_blocked(position: Vector2, radius: float, actor_id: int) -> bool:
	if not _inside_world(position, radius):
		return true
	for wall in walls:
		if _circle_intersects_rect(position, radius, wall):
			return true
	if actor_id == 0:
		for enemy in enemies:
			if int(enemy["hp"]) > 0 and position.distance_to(Vector2(enemy["pos"])) < radius + float(enemy["radius"]):
				return true
	else:
		if position.distance_to(player_pos) < radius + PLAYER_RADIUS:
			return true
		for enemy in enemies:
			if int(enemy["id"]) != actor_id and int(enemy["hp"]) > 0 and position.distance_to(Vector2(enemy["pos"])) < radius + float(enemy["radius"]):
				return true
	return false

func _inside_world(position: Vector2, radius: float) -> bool:
	return position.x >= radius and position.y >= radius and position.x <= WORLD_SIZE.x - radius and position.y <= WORLD_SIZE.y - radius

func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(nearest) < radius * radius

func _point_in_wall(point: Vector2) -> bool:
	for wall in walls:
		if wall.has_point(point):
			return true
	return false

func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var distance := from.distance_to(to)
	var steps := maxi(1, int(ceil(distance / 12.0)))
	for index in range(1, steps):
		if _point_in_wall(from.lerp(to, float(index) / float(steps))):
			return false
	return true

func _within_arc(facing: Vector2, offset: Vector2, half_angle: float) -> bool:
	if offset.length_squared() < 0.01:
		return true
	return absf(facing.normalized().angle_to(offset.normalized())) <= half_angle

func _segment_distance_to_point(a: Vector2, b: Vector2, point: Vector2) -> float:
	var segment := b - a
	if segment.length_squared() < 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(a + segment * t)

func snapshot() -> Dictionary:
	return {
		"time": simulation_time,
		"player_pos": player_pos,
		"player_facing": player_facing,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"loadout_id": loadout_id,
		"defense_id": defense_id,
		"player_action": player_action.duplicate(true),
		"enemies": enemies.duplicate(true),
		"walls": walls.duplicate(),
		"projectiles": projectiles.duplicate(true),
		"hazards": hazards.duplicate(true),
		"effects": effects.duplicate(true),
		"dodge_cooldown": dodge_cooldown,
		"block_cooldown": block_cooldown,
		"endure_cooldown": endure_cooldown,
		"skill_cooldown": skill_cooldown,
		"strength_remaining": strength_remaining,
		"potions": potions,
		"wave": wave,
		"wave_clear": wave_clear,
		"trial_complete": trial_complete,
		"run_seed": run_seed,
		"upgrade_pending": upgrade_pending,
		"upgrade_choices": upgrade_choices.duplicate(),
		"upgrades": upgrades.duplicate(),
		"rooms_cleared": rooms_cleared,
		"enemies_defeated": enemies_defeated,
		"damage_dealt": damage_dealt,
		"message": message,
	}

func save_run(path: String = "user://waystone-expedition.save") -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	var payload := snapshot()
	payload["save_version"] = 4
	payload["player_move_speed"] = player_move_speed
	payload["player_attack_duration"] = player_attack_duration
	payload["player_attack_startup"] = player_attack_startup
	payload["player_attack_active_end"] = player_attack_active_end
	payload["player_damage_min"] = player_damage_min
	payload["player_damage_max"] = player_damage_max
	payload["player_facing"] = player_facing
	payload["perfect_dodges"] = perfect_dodges
	payload["counter_hits"] = counter_hits
	payload["successful_blocks"] = successful_blocks
	payload["successful_endures"] = successful_endures
	payload["rng_state"] = rng.state
	file.store_var(payload, true)
	return true

func load_run(path: String = "user://waystone-expedition.save") -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var value: Variant = file.get_var(true)
	if not value is Dictionary: return false
	var payload: Dictionary = value
	var save_version := int(payload.get("save_version", 0))
	if not [1, 2, 3, 4].has(save_version): return false
	loadout_id = String(payload.get("loadout_id", "duelist"))
	_apply_loadout()
	player_pos = Vector2(payload.get("player_pos", Vector2(800, 1900)))
	player_facing = Vector2(payload.get("player_facing", Vector2.UP))
	player_hp = int(payload.get("player_hp", player_max_hp))
	player_max_hp = int(payload.get("player_max_hp", player_max_hp))
	player_move_speed = float(payload.get("player_move_speed", player_move_speed))
	player_attack_duration = float(payload.get("player_attack_duration", player_attack_duration))
	player_attack_startup = float(payload.get("player_attack_startup", player_attack_startup))
	player_attack_active_end = float(payload.get("player_attack_active_end", player_attack_active_end))
	player_damage_min = int(payload.get("player_damage_min", player_damage_min))
	player_damage_max = int(payload.get("player_damage_max", player_damage_max))
	player_action = Dictionary(payload.get("player_action", _idle_action())).duplicate(true)
	if String(player_action.get("kind", "idle")) == "lunge" or (save_version < 4 and String(player_action.get("kind", "idle")) in ["attack", "sweep", "melee"]): player_action = _idle_action()
	enemies.assign(Array(payload.get("enemies", [])))
	walls.assign(Array(payload.get("walls", [])))
	projectiles.assign(Array(payload.get("projectiles", [])))
	hazards.assign(Array(payload.get("hazards", [])))
	effects.assign(Array(payload.get("effects", [])))
	if save_version < 3:
		var room_scale := Vector2(WORLD_SIZE.x / 1000.0, WORLD_SIZE.y / 1400.0)
		player_pos *= room_scale
		walls = _room_walls(int(payload.get("wave", wave)))
		projectiles.clear()
		hazards.clear()
		effects.clear()
		player_action = _idle_action()
		for enemy in enemies:
			enemy["pos"] = Vector2(enemy["pos"]) * room_scale
			enemy["action"] = _idle_action()
	var shield_free: Array[Dictionary] = []
	for enemy in enemies:
		if String(enemy.get("kind", "")) != "shield": shield_free.append(enemy)
	enemies = shield_free
	dodge_cooldown = float(payload.get("dodge_cooldown", 0.0))
	block_cooldown = float(payload.get("block_cooldown", 0.0))
	endure_cooldown = float(payload.get("endure_cooldown", 0.0))
	skill_cooldown = float(payload.get("skill_cooldown", payload.get("lunge_cooldown", 0.0)))
	strength_remaining = float(payload.get("strength_remaining", 0.0))
	potions = int(payload.get("potions", 1))
	wave = int(payload.get("wave", 1))
	wave_clear = bool(payload.get("wave_clear", false))
	trial_complete = bool(payload.get("trial_complete", false))
	run_seed = int(payload.get("run_seed", run_seed))
	upgrade_pending = bool(payload.get("upgrade_pending", false))
	upgrade_choices.assign(Array(payload.get("upgrade_choices", [])))
	upgrades.assign(Array(payload.get("upgrades", [])))
	rooms_cleared = int(payload.get("rooms_cleared", 0))
	enemies_defeated = int(payload.get("enemies_defeated", 0))
	damage_dealt = int(payload.get("damage_dealt", 0))
	perfect_dodges = int(payload.get("perfect_dodges", 0))
	counter_hits = int(payload.get("counter_hits", 0))
	successful_blocks = int(payload.get("successful_blocks", 0))
	successful_endures = int(payload.get("successful_endures", 0))
	simulation_time = float(payload.get("time", 0.0))
	message = String(payload.get("message", message))
	rng.state = int(payload.get("rng_state", rng.state))
	_next_enemy_id = 1
	for enemy in enemies:
		if save_version < 4 and String(Dictionary(enemy.get("action", {})).get("kind", "idle")) == "melee": enemy["action"] = _idle_action()
		_next_enemy_id = maxi(_next_enemy_id, int(enemy["id"]) + 1)
		if not enemy.has("posture_max"):
			enemy["posture_max"] = _enemy_posture_max(String(enemy["kind"]))
			enemy["posture"] = float(enemy["posture_max"])
			enemy["posture_recovery_delay"] = 0.0
	_build_navigation()
	last_timeline.clear()
	return true

func restart() -> void:
	_apply_loadout()
	player_pos = Vector2(800.0, 1900.0)
	player_facing = Vector2.UP
	player_hp = player_max_hp
	player_action = _idle_action()
	dodge_cooldown = 0.0
	block_cooldown = 0.0
	endure_cooldown = 0.0
	skill_cooldown = 0.0
	strength_remaining = 0.0
	potions = 1
	wave = 1
	wave_clear = false
	trial_complete = false
	upgrade_pending = false
	upgrade_choices.clear()
	upgrades.clear()
	rooms_cleared = 0
	enemies_defeated = 0
	damage_dealt = 0
	simulation_time = 0.0
	perfect_dodges = 0
	counter_hits = 0
	successful_blocks = 0
	successful_endures = 0
	effects.clear()
	hazards.clear()
	rng.seed = run_seed
	message = "Time is frozen. Choose an action."
	last_timeline.clear()
	build_expedition_room()
	changed.emit()
	message_changed.emit(message)

func _set_message(text: String) -> void:
	message = text
	message_changed.emit(message)
