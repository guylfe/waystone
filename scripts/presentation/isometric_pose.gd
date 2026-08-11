class_name IsometricPose
extends RefCounted

# This is presentation data only.  Combat continues to resolve from the
# authoritative world-space action and AttackGeometry pose.
const VERSION := 1

static func sample(action: Dictionary, facing: Vector2, world_radius: float) -> Dictionary:
	var direction := facing.normalized()
	if direction.length_squared() < 0.001: direction = Vector2.UP
	var kind := String(action.get("kind", "idle"))
	var elapsed := float(action.get("elapsed", 0.0))
	var duration := maxf(0.001, float(action.get("duration", 1.0)))
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var startup := clampf(float(action.get("startup", duration * 0.30)) / duration, 0.01, 0.90)
	var active_end := clampf(float(action.get("active_end", duration * 0.60)) / duration, startup, 0.98)
	var offset := Vector2.ZERO
	var lift := 0.0
	var width_scale := 1.0
	var height_scale := 1.0
	var twist := 0.0
	var stride := 0.0
	var commitment := 0.0

	if kind in ["attack", "sweep", "melee", "combo", "art_combo", "twin_fang", "dodge_strike", "claw_combo", "pounce_combo"]:
		var phase := _commitment_curve(progress, startup, active_end)
		commitment = phase
		offset = direction * world_radius * lerpf(-0.13, 0.24, phase)
		lift = world_radius * (0.05 + 0.08 * sin(PI * phase))
		width_scale = lerpf(1.06, 0.92, phase)
		height_scale = lerpf(0.96, 1.08, phase)
		twist = lerpf(-0.24, 0.20, phase)
	elif kind in ["bow_draw", "bow_art", "shoot", "take_aim"]:
		var draw := float(action.get("draw_ratio", clampf(progress / maxf(startup, 0.05), 0.0, 1.0)))
		commitment = draw
		offset = -direction * world_radius * (0.05 + draw * 0.10)
		width_scale = 1.0 + draw * 0.08
		height_scale = 1.0 - draw * 0.05
		twist = -0.10 * draw
	elif kind == "bow_release":
		commitment = 1.0 - progress
		offset = direction * world_radius * 0.16 * (1.0 - progress)
		width_scale = 0.94
		height_scale = 1.06
	elif kind in ["move", "charge", "advance", "dodge", "evade", "vault"]:
		var motion := sin(progress * PI)
		commitment = motion
		offset = direction * world_radius * (0.12 + motion * 0.12)
		lift = world_radius * motion * (0.18 if kind in ["dodge", "evade", "vault"] else 0.07)
		width_scale = 1.0 + motion * 0.10
		height_scale = 1.0 - motion * 0.10
		stride = sin(progress * TAU) * world_radius * 0.30
	elif kind in ["block", "endure", "rally"]:
		var brace := sin(clampf(progress, 0.0, 1.0) * PI)
		commitment = brace
		offset = -direction * world_radius * 0.04
		lift = -world_radius * 0.08 * brace
		width_scale = 1.0 + brace * 0.12
		height_scale = 1.0 - brace * 0.12
	elif kind in ["hit_reaction", "stagger"]:
		commitment = 1.0 - progress
		twist = 0.30 * (1.0 - progress)
		width_scale = 1.06
		height_scale = 0.94

	return {
		"world_offset": offset,
		"vertical_lift": lift,
		"body_scale": Vector2(width_scale, height_scale),
		"facing_twist": twist,
		"stride": stride,
		"commitment": commitment,
	}

static func weapon_lift(action: Dictionary, technique_id: String, world_radius: float) -> float:
	var elapsed := float(action.get("elapsed", 0.0))
	var duration := maxf(0.001, float(action.get("duration", 1.0)))
	var startup := float(action.get("startup", duration * 0.30))
	var active_end := float(action.get("active_end", duration * 0.60))
	var base := world_radius * (0.16 if technique_id in ["bite", "forward_smash"] else 0.28)
	if elapsed < startup:
		return base * lerpf(1.0, 0.35, clampf(elapsed / maxf(0.001, startup), 0.0, 1.0))
	if elapsed <= active_end: return base * 0.16
	return base * lerpf(0.16, 0.72, clampf((elapsed - active_end) / maxf(0.001, duration - active_end), 0.0, 1.0))

static func direction_bucket(facing: Vector2) -> int:
	var direction := facing.normalized()
	if direction.length_squared() < 0.001: return 0
	return posmod(roundi((direction.angle() + PI * 0.5) / (TAU / 8.0)), 8)

static func _commitment_curve(progress: float, startup: float, active_end: float) -> float:
	if progress < startup:
		return lerpf(0.0, 0.28, clampf(progress / maxf(0.001, startup), 0.0, 1.0))
	if progress <= active_end:
		return lerpf(0.28, 1.0, clampf((progress - startup) / maxf(0.001, active_end - startup), 0.0, 1.0))
	return lerpf(1.0, 0.50, clampf((progress - active_end) / maxf(0.001, 1.0 - active_end), 0.0, 1.0))
