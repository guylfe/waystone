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
	for index in range(8):
		var facing := Vector2.UP.rotated(float(index) * TAU / 8.0)
		assert(IsometricPoseScript.direction_bucket(facing) >= 0 and IsometricPoseScript.direction_bucket(facing) < 8)
	print("ISOMETRIC POSE commitment, lift, motion, and direction buckets: PASS")
	quit(0)
