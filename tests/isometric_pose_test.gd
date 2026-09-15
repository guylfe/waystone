extends SceneTree

const IsometricPoseScript = preload("res://scripts/presentation/isometric_pose.gd")

func _init() -> void:
	var direction := Vector2(0.6, -0.8).normalized()
	var startup := {"kind": "attack", "elapsed": 0.10, "duration": 1.0, "startup": 0.30, "active_end": 0.55}
	var active := startup.duplicate()
	active["elapsed"] = 0.48
	var recovery := startup.duplicate()
	recovery["elapsed"] = 0.88
	var startup_pose := IsometricPoseScript.sample(startup, direction, 30.0)
	var active_pose := IsometricPoseScript.sample(active, direction, 30.0)
	var recovery_pose := IsometricPoseScript.sample(recovery, direction, 30.0)
	assert(Vector2(active_pose["world_offset"]).dot(direction) > Vector2(startup_pose["world_offset"]).dot(direction))
	assert(float(active_pose["commitment"]) > float(startup_pose["commitment"]))
	assert(float(recovery_pose["commitment"]) < float(active_pose["commitment"]))
	assert(IsometricPoseScript.weapon_lift(active, "diagonal_cut", 30.0) < IsometricPoseScript.weapon_lift(startup, "diagonal_cut", 30.0))
	var move := IsometricPoseScript.sample({"kind": "move", "elapsed": 0.5, "duration": 1.0}, direction, 30.0)
	assert(Vector2(move["world_offset"]).is_zero_approx())
	assert(is_zero_approx(float(move["vertical_lift"])))
	assert(Vector2(move["body_scale"]).is_equal_approx(Vector2.ONE))
	assert(is_zero_approx(float(move["stride"])))
	var vault := IsometricPoseScript.sample({"kind": "vault", "elapsed": 0.25, "duration": 0.54}, direction, 30.0)
	assert(float(vault["vertical_lift"]) > 0.0)
	assert(absf(float(vault["stride"])) > 0.0)
	var grounded_charge := IsometricPoseScript.sample({"kind": "charge", "elapsed": 0.89, "duration": 1.58, "startup": 0.70, "active_end": 1.08}, direction, 25.0)
	var airborne_charge := IsometricPoseScript.sample({"kind": "charge", "elapsed": 0.89, "duration": 1.58, "startup": 0.70, "active_end": 1.08, "airborne": true}, direction, 25.0)
	assert(float(airborne_charge["vertical_lift"]) > float(grounded_charge["vertical_lift"]))
	var hunting_coil := IsometricPoseScript.sample({"kind":"pounce_combo", "ability_id":"hunting_leap", "elapsed":0.30, "duration":2.12, "startup":0.52, "pounce_end":1.22, "landed":false}, direction, 62.0)
	var bounding_coil := IsometricPoseScript.sample({"kind":"pounce_combo", "ability_id":"bounding_rake", "elapsed":0.30, "duration":2.44, "startup":0.68, "pounce_end":1.28, "landed":false}, direction, 62.0)
	var leap_flight := IsometricPoseScript.sample({"kind":"pounce_combo", "ability_id":"hunting_leap", "elapsed":0.80, "duration":2.12, "startup":0.52, "pounce_end":1.22, "landed":false}, direction, 62.0)
	var phase_change := IsometricPoseScript.sample({"kind":"phase_change", "elapsed":0.50, "duration":1.0}, direction, 62.0)
	assert(float(bounding_coil["body_scale"].x) > float(hunting_coil["body_scale"].x))
	assert(float(leap_flight["vertical_lift"]) > 30.0)
	assert(float(phase_change["body_scale"].x) > 1.1 and float(phase_change["body_scale"].y) < 1.0)
	for index in range(8):
		var facing := Vector2.UP.rotated(float(index) * TAU / 8.0)
		assert(IsometricPoseScript.direction_bucket(facing) >= 0 and IsometricPoseScript.direction_bucket(facing) < 8)
	print("ISOMETRIC POSE commitment, lift, motion, and direction buckets: PASS")
	quit(0)
