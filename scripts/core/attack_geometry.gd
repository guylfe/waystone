class_name AttackGeometry
extends RefCounted

const TECHNIQUES := {
	# Ordinary cuts are intentionally compact. Multi-target contact still comes
	# from every body the blade physically crosses; it is no longer granted by a
	# near-semicircular default swing.
	"opening_cut": {"motion": "arc", "start_angle": -0.48, "end_angle": 0.32, "radius": 8.0, "multi": false, "label": "Opening cut"},
	"quick_cut": {"motion": "arc", "start_angle": -0.38, "end_angle": 0.38, "radius": 7.0, "multi": false, "label": "Short cut"},
	"knife_cut_in": {"motion": "arc", "start_angle": -0.44, "end_angle": 0.24, "radius": 5.0, "multi": false, "label": "Inward cut"},
	"knife_cut_out": {"motion": "arc", "start_angle": 0.42, "end_angle": -0.26, "radius": 5.0, "multi": false, "label": "Outward cut"},
	"knife_rising_cut": {"motion": "arc", "start_angle": -0.26, "end_angle": 0.46, "radius": 5.0, "multi": false, "label": "Rising cut"},
	"knife_falling_cut": {"motion": "arc", "start_angle": 0.28, "end_angle": -0.48, "radius": 5.0, "multi": false, "label": "Falling cut"},
	"reverse_cut": {"motion": "arc", "start_angle": 0.45, "end_angle": -0.42, "radius": 9.0, "multi": false, "label": "Returning cut"},
	"turning_slash": {"motion": "arc", "start_angle": -0.92, "end_angle": 0.92, "radius": 11.0, "multi": true, "label": "Turning slash"},
	"diagonal_cut": {"motion": "arc", "start_angle": -0.68, "end_angle": 0.52, "radius": 9.0, "multi": false, "label": "Diagonal cut"},
	"broad_sweep": {"motion": "arc", "start_angle": -1.396, "end_angle": 1.396, "radius": 14.0, "multi": true, "label": "Broad sweep"},
	"heavy_cleave": {"motion": "arc", "start_angle": -1.658, "end_angle": 1.658, "radius": 18.0, "multi": true, "label": "Heavy cleave"},
	"heavy_chop": {"motion": "arc", "start_angle": -0.48, "end_angle": 0.18, "radius": 18.0, "multi": false, "label": "Heavy chop"},
	"thrust": {"motion": "thrust", "radius": 10.0, "multi": false, "label": "Thrust"},
	"driving_cut": {"motion": "thrust", "radius": 8.0, "multi": false, "label": "Driving cut"},
	"bite": {"motion": "bite", "radius": 24.0, "multi": false, "label": "Bite"},
	"forward_smash": {"motion": "smash", "radius": 58.0, "multi": true, "label": "Heavy smash"},
}

static func technique(id: String) -> Dictionary:
	return Dictionary(TECHNIQUES.get(id, TECHNIQUES["diagonal_cut"]))

static func label(id: String) -> String:
	return String(technique(id).get("label", "Attack"))

static func pose(action: Dictionary, origin: Vector2, facing: Vector2, walls: Array[Rect2] = []) -> Dictionary:
	var id := String(action.get("technique_id", "diagonal_cut"))
	var definition := technique(id)
	var motion := String(definition["motion"])
	var elapsed := float(action.get("elapsed", 0.0))
	var startup := maxf(0.001, float(action.get("startup", 0.35)))
	var active_end := maxf(startup + 0.001, float(action.get("active_end", startup + 0.25)))
	var duration := maxf(active_end + 0.001, float(action.get("duration", active_end + 0.3)))
	var active := elapsed >= startup and elapsed <= active_end
	var active_progress := clampf((elapsed - startup) / (active_end - startup), 0.0, 1.0)
	var windup_progress := clampf(elapsed / startup, 0.0, 1.0)
	var recovery_progress := clampf((elapsed - active_end) / (duration - active_end), 0.0, 1.0)
	var direction := facing.normalized() if facing.length_squared() > 0.001 else Vector2.UP
	var reach := float(action.get("reach", 128.0))
	var thickness := float(definition["radius"])
	var result := {"technique_id": id, "motion": motion, "active": active, "multi": bool(definition["multi"]), "radius": thickness, "origin": origin}

	if motion == "arc":
		var start_angle := float(definition["start_angle"])
		var end_angle := float(definition["end_angle"])
		var angle := start_angle - 0.28 * (1.0 - windup_progress)
		if active: angle = lerpf(start_angle, end_angle, active_progress)
		elif elapsed > active_end: angle = lerpf(end_angle, end_angle + 0.16, recovery_progress)
		var blade_direction := direction.rotated(angle)
		var blade_start := origin + blade_direction * 24.0
		var blade_end := origin + blade_direction * reach
		blade_end = _clip_segment_to_walls(blade_start, blade_end, walls)
		result.merge({"shape": "segment", "start": blade_start, "end": blade_end, "weapon_start": blade_start, "weapon_end": blade_end, "order_origin": blade_start})
	elif motion == "thrust":
		var extension := lerpf(0.24, 0.42, windup_progress)
		if active: extension = lerpf(0.42, 1.0, active_progress)
		elif elapsed > active_end: extension = lerpf(1.0, 0.46, recovery_progress)
		var spear_start := origin + direction * 22.0
		var spear_end := origin + direction * reach * extension
		spear_end = _clip_segment_to_walls(spear_start, spear_end, walls)
		result.merge({"shape": "segment", "start": spear_start, "end": spear_end, "weapon_start": origin - direction * 25.0, "weapon_end": spear_end, "order_origin": spear_start})
	elif motion == "bite":
		var bite_extension := lerpf(0.45, 0.62, windup_progress)
		if active: bite_extension = lerpf(0.62, 1.0, active_progress)
		elif elapsed > active_end: bite_extension = lerpf(1.0, 0.5, recovery_progress)
		var bite_center := origin + direction * reach * bite_extension
		var clipped_bite := _clip_segment_to_walls(origin, bite_center, walls)
		if clipped_bite.distance_to(bite_center) > 0.01: bite_center = clipped_bite - direction * thickness
		result.merge({"shape": "circle", "center": bite_center, "weapon_start": origin + direction * 18.0, "weapon_end": bite_center, "order_origin": origin, "head_radius": thickness})
	else:
		var smash_extension := lerpf(0.28, 0.40, windup_progress)
		if active: smash_extension = lerpf(0.40, 0.76, active_progress)
		elif elapsed > active_end: smash_extension = lerpf(0.76, 0.46, recovery_progress)
		var smash_center := origin + direction * reach * smash_extension
		var clipped_smash := _clip_segment_to_walls(origin, smash_center, walls)
		if clipped_smash.distance_to(smash_center) > 0.01: smash_center = clipped_smash - direction * thickness
		result.merge({"shape": "circle", "center": smash_center, "weapon_start": origin + direction * 20.0, "weapon_end": smash_center, "order_origin": origin, "head_radius": thickness * 0.55})
	return result

static func hits_circle(sample: Dictionary, center: Vector2, target_radius: float) -> bool:
	if not bool(sample.get("active", false)): return false
	return clearance_to_circle(sample, center, target_radius) <= 0.0

static func clearance_to_circle(sample: Dictionary, center: Vector2, target_radius: float) -> float:
	# Signed world-space distance between the sampled attack and a target body.
	# Negative values are overlap. Survey diagnostics use the same calculation as
	# combat so a reported near miss cannot disagree with the actual hit test.
	if String(sample.get("shape", "")) == "circle":
		return Vector2(sample["center"]).distance_to(center) - float(sample["radius"]) - target_radius
	return _segment_distance_to_point(Vector2(sample["start"]), Vector2(sample["end"]), center) - float(sample["radius"]) - target_radius

static func contact_point(sample: Dictionary, center: Vector2) -> Vector2:
	if String(sample.get("shape", "")) == "circle":
		var attack_center := Vector2(sample["center"])
		var direction := (center - attack_center).normalized()
		return attack_center + direction * minf(float(sample["radius"]), attack_center.distance_to(center))
	return _closest_point_on_segment(Vector2(sample["start"]), Vector2(sample["end"]), center)

static func contact_order(sample: Dictionary, center: Vector2) -> float:
	return Vector2(sample.get("order_origin", sample.get("origin", Vector2.ZERO))).distance_squared_to(contact_point(sample, center))

static func _clip_segment_to_walls(start: Vector2, finish: Vector2, walls: Array[Rect2]) -> Vector2:
	var clipped := finish
	var best_distance := start.distance_squared_to(finish)
	for wall in walls:
		var hit: Variant = _segment_rect_intersection(start, finish, wall)
		if hit != null:
			var point := Vector2(hit)
			var distance := start.distance_squared_to(point)
			if distance < best_distance:
				best_distance = distance
				clipped = point
	return clipped

static func _segment_rect_intersection(start: Vector2, finish: Vector2, rect: Rect2) -> Variant:
	if rect.has_point(start): return start
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var best: Variant = null
	var best_distance := INF
	for index in range(4):
		var hit: Variant = _segment_intersection(start, finish, corners[index], corners[(index + 1) % 4])
		if hit != null:
			var distance := start.distance_squared_to(Vector2(hit))
			if distance < best_distance:
				best_distance = distance
				best = hit
	return best

static func _segment_intersection(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Variant:
	var r := b - a
	var s := d - c
	var denominator := r.cross(s)
	if absf(denominator) < 0.00001: return null
	var offset := c - a
	var t := offset.cross(s) / denominator
	var u := offset.cross(r) / denominator
	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0: return null
	return a + r * t

static func _closest_point_on_segment(a: Vector2, b: Vector2, point: Vector2) -> Vector2:
	var segment := b - a
	if segment.length_squared() < 0.0001: return a
	var amount := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return a + segment * amount

static func _segment_distance_to_point(a: Vector2, b: Vector2, point: Vector2) -> float:
	return point.distance_to(_closest_point_on_segment(a, b, point))
