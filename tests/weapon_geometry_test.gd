extends SceneTree

# Does the weapon you see match the weapon that hits you?
#
# Milestones A through D were verified headless only, which establishes simulation
# behaviour and says nothing about visual truth -- see CLAUDE.md's Verification note.
# The half of that gap which is actually measurable is this one: attack_geometry
# authors a *sector* for collision and draws a *blade line* for presentation, and
# nothing has ever checked that the second stays inside the first.
#
# The pose code is explicit that the two are different things:
#
#     "The blade pose remains expressive, but it is presentation only. At impact
#      collision uses the entire sector below rather than this instantaneous line."
#
# So the sector is deliberately WIDER than the drawn blade, and this file does not
# assert the converse. What it asserts is the direction that would feel like a lie:
# every part of the blade you are shown, during the window in which contact resolves,
# must actually connect.
#
# Wind-up and recovery are excluded on purpose. The blade legitimately swings up to
# 0.24 rad behind the sector's start during wind-up and 0.12 rad past its end during
# recovery -- but `active` is false there, so nothing resolves and nothing is claimed.

const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")

# The drawn blade starts at a hardcoded 24 units for every technique, while authored
# inner_radius runs from 20 (knife) to 34 (heavy cleave). On the heavy techniques that
# leaves a stretch of blade near the grip that cannot hit. It is left alone rather than
# fixed: a target 24-34 units from the attacker's origin is inside the attacker's own
# body -- the player's radius alone is 30 -- so the region is unreachable in play. The
# bound is pinned here so it cannot silently grow.
const BLADE_DRAWN_FROM := 24.0
const MAX_DEAD_HILT := 10.0

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func arc_action(id: String, reach: float) -> Dictionary:
	return {"technique_id": id, "elapsed": 0.0, "startup": 0.30, "active_end": 0.55, "duration": 1.00, "reach": reach}

func arc_techniques() -> Array[String]:
	var result: Array[String] = []
	for id in AttackGeometryScript.TECHNIQUES.keys():
		if String(Dictionary(AttackGeometryScript.TECHNIQUES[id])["motion"]) == "arc": result.append(String(id))
	return result

# --- the blade never leaves the footprint that resolves the hit ------------------

func test_the_drawn_blade_stays_inside_the_resolving_sector() -> void:
	for id in arc_techniques():
		var action := arc_action(id, 120.0)
		for step in range(9):
			action["elapsed"] = 0.30 + (0.55 - 0.30) * float(step) / 8.0
			var sample := AttackGeometryScript.pose(action, Vector2.ZERO, Vector2.RIGHT, [])
			var origin := Vector2(sample["origin"])
			var direction := Vector2(sample["direction"]).normalized()
			var blade := (Vector2(sample["weapon_end"]) - origin)
			if blade.length_squared() < 0.001: continue
			var angle := direction.angle_to(blade.normalized())
			check(angle >= float(sample["start_angle"]) - 0.0001,
				"%s draws its blade %.3f rad before the sector it hits with" % [id, float(sample["start_angle"]) - angle])
			check(angle <= float(sample["end_angle"]) + 0.0001,
				"%s draws its blade %.3f rad past the sector it hits with" % [id, angle - float(sample["end_angle"])])

func test_the_blade_never_reaches_further_than_the_attack_does() -> void:
	# The failure this guards against is the one that reads as a lie: a weapon drawn
	# past the ground it can actually cover.
	for id in arc_techniques():
		var action := arc_action(id, 120.0)
		for step in range(9):
			action["elapsed"] = 0.30 + (0.55 - 0.30) * float(step) / 8.0
			var sample := AttackGeometryScript.pose(action, Vector2.ZERO, Vector2.RIGHT, [])
			var overshoot := Vector2(sample["weapon_end"]).distance_to(Vector2(sample["origin"])) - float(sample["outer_radius"])
			check(overshoot <= 0.0001, "%s draws %.1f units beyond its own reach" % [id, overshoot])

func test_every_drawn_point_past_the_hilt_actually_connects() -> void:
	# The property a player would name: if the game shows me the blade there, a body
	# there is hit. Sampled against a small target so the test measures the geometry
	# rather than the generosity of a large hitbox.
	for id in arc_techniques():
		var action := arc_action(id, 120.0)
		action["elapsed"] = 0.42
		var sample := AttackGeometryScript.pose(action, Vector2.ZERO, Vector2.RIGHT, [])
		var origin := Vector2(sample["origin"])
		var blade_start := Vector2(sample["weapon_start"])
		var blade_end := Vector2(sample["weapon_end"])
		var inner := float(sample["inner_radius"])
		for step in range(21):
			var point := blade_start.lerp(blade_end, float(step) / 20.0)
			# Skip the documented hilt stretch; it is pinned by its own test below.
			if point.distance_to(origin) < inner: continue
			check(AttackGeometryScript.hits_circle(sample, point, 6.0),
				"%s draws blade at %.0f units from origin but a body there is not hit" % [id, point.distance_to(origin)])

func test_the_dead_hilt_stays_within_its_documented_bound() -> void:
	# Not a defect -- a target this close is inside the attacker's own body -- but it is
	# a discrepancy, and an undocumented discrepancy is how a real one gets in later.
	for id in arc_techniques():
		var definition := Dictionary(AttackGeometryScript.TECHNIQUES[id])
		var dead := float(definition.get("inner_radius", 24.0)) - BLADE_DRAWN_FROM
		check(dead <= MAX_DEAD_HILT,
			"%s draws %.1f units of blade that cannot hit -- past the %.0f-unit bound this file pins" % [id, dead, MAX_DEAD_HILT])

# --- thrusts: the shaft is drawn behind the grip, the point is what hits ---------

func test_a_thrust_hits_along_the_shaft_it_draws() -> void:
	# A thrust draws the whole weapon, including the length behind the hand, while
	# collision is the forward segment only. That is correct and expected -- what must
	# hold is that the part in FRONT of the grip connects along its whole length.
	for id in ["thrust", "rapier_thrust"]:
		var action := {"technique_id": id, "elapsed": 0.42, "startup": 0.30, "active_end": 0.55, "duration": 1.00, "reach": 160.0}
		var sample := AttackGeometryScript.pose(action, Vector2.ZERO, Vector2.RIGHT, [])
		check(String(sample["shape"]) == "segment", "%s should resolve as a segment" % id)
		var tip := Vector2(sample["end"])
		var base := Vector2(sample["start"])
		for step in range(11):
			var point := base.lerp(tip, float(step) / 10.0)
			check(AttackGeometryScript.hits_circle(sample, point, 4.0), "%s should connect along its own shaft" % id)
		check(Vector2(sample["weapon_end"]).is_equal_approx(tip), "%s should draw its point where the point hits" % id)

# --- the enemy roster, at its own authored reaches -------------------------------

func test_the_whole_roster_agrees_at_its_authored_reach() -> void:
	# The techniques above are checked at a synthetic 120 units. Reach is authored per
	# enemy and changes the sector, so every real plan entry is checked at its own.
	for kind in ["blade", "knife", "bandit", "shield", "brute", "knight", "polearm", "duellist", "boar", "hound", "werewolf", "warden"]:
		for option_value in CombatCatalogScript.melee_attack_plan(kind):
			var option := Dictionary(option_value)
			var id := String(option["technique"])
			var definition := Dictionary(AttackGeometryScript.TECHNIQUES.get(id, {}))
			if definition.is_empty():
				failures.append("%s plans a technique the geometry has never heard of: %s" % [kind, id])
				continue
			if String(definition["motion"]) != "arc": continue
			var action := option.duplicate(true)
			action["technique_id"] = id
			action["elapsed"] = float(option["startup"]) + (float(option["active_end"]) - float(option["startup"])) * 0.5
			var sample := AttackGeometryScript.pose(action, Vector2.ZERO, Vector2.RIGHT, [])
			var origin := Vector2(sample["origin"])
			var blade := Vector2(sample["weapon_end"]) - origin
			var angle := Vector2(sample["direction"]).normalized().angle_to(blade.normalized())
			check(angle >= float(sample["start_angle"]) - 0.0001 and angle <= float(sample["end_angle"]) + 0.0001,
				"%s's %s draws outside the sector it hits with" % [kind, id])
			check(blade.length() - float(sample["outer_radius"]) <= 0.0001,
				"%s's %s draws beyond its authored reach" % [kind, id])

func _init() -> void:
	test_the_drawn_blade_stays_inside_the_resolving_sector()
	test_the_blade_never_reaches_further_than_the_attack_does()
	test_every_drawn_point_past_the_hilt_actually_connects()
	test_the_dead_hilt_stays_within_its_documented_bound()
	test_a_thrust_hits_along_the_shaft_it_draws()
	test_the_whole_roster_agrees_at_its_authored_reach()
	if failures.is_empty():
		print("Weapon geometry tests passed.")
		quit(0)
		return
	for failure in failures:
		printerr("FAILED: %s" % failure)
	printerr("Weapon geometry tests failed: %d" % failures.size())
	quit(1)
