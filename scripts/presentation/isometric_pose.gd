class_name IsometricPose
extends RefCounted

# This is presentation data only.  Combat continues to resolve from the
# authoritative world-space action and AttackGeometry pose.
const VERSION := 2

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

	if kind in ["attack", "sweep", "melee", "combo", "art_combo", "twin_fang", "dodge_strike", "claw_combo"]:
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
	elif kind == "move":
		# World-space interpolation already communicates ordinary locomotion.
		# Keep the placeholder body steady so repeated short movement pulses do
		# not read as bobbing or squash-and-stretch.
		commitment = progress
	elif kind == "pounce_combo":
		var leap_start := float(action.get("startup", 0.0))
		var leap_end := float(action.get("pounce_end", action.get("flight_end", duration)))
		if elapsed < leap_start:
			var coil := clampf(elapsed / maxf(0.001, leap_start), 0.0, 1.0)
			commitment = coil
			offset = -direction * world_radius * 0.12 * coil
			lift = -world_radius * 0.12 * coil
			width_scale = 1.0 + coil * (0.22 if String(action.get("ability_id", "")) == "bounding_rake" else 0.10)
			height_scale = 1.0 - coil * 0.18
		elif not bool(action.get("landed", false)) or elapsed <= leap_end:
			var flight := clampf((elapsed - leap_start) / maxf(0.001, leap_end - leap_start), 0.0, 1.0)
			commitment = 1.0
			offset = direction * world_radius * 0.20
			lift = world_radius * (0.48 + 0.72 * sin(flight * PI))
			width_scale = 0.92
			height_scale = 1.10
		else:
			var recovery := clampf((elapsed - leap_end) / maxf(0.001, duration - leap_end), 0.0, 1.0)
			commitment = 1.0 - recovery
			lift = world_radius * 0.08 * (1.0 - recovery)
			height_scale = 1.0 - 0.12 * (1.0 - recovery)
	elif kind in ["charge", "advance", "dodge", "evade", "vault"]:
		var motion := sin(progress * PI)
		commitment = motion
		offset = direction * world_radius * (0.12 + motion * 0.12)
		lift = world_radius * motion * (0.18 if kind in ["dodge", "evade", "vault"] else 0.07)
		# A Hound passing through an allied body is a leap, not intangible clipping.
		# The simulation authors the airborne flag on its charge profile; presentation
		# merely makes the active travel legible and never changes the collision point.
		if kind == "charge" and bool(action.get("airborne", false)) and elapsed >= float(action.get("startup", 0.0)) and elapsed <= float(action.get("active_end", duration)):
			var flight := clampf((elapsed - float(action.get("startup", 0.0))) / maxf(0.001, float(action.get("active_end", duration)) - float(action.get("startup", 0.0))), 0.0, 1.0)
			lift += world_radius * 0.95 * sin(flight * PI)
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
	elif kind == "phase_change":
		var shift := sin(progress * PI)
		commitment = shift
		lift = -world_radius * 0.10 * shift
		width_scale = 1.0 + 0.24 * shift
		height_scale = 1.0 - 0.16 * shift
		twist = 0.16 * sin(progress * TAU)
	elif kind in ["hit_reaction", "stagger"]:
		commitment = 1.0 - progress
		twist = 0.30 * (1.0 - progress)
		width_scale = 1.06
		height_scale = 0.94
	elif kind == "winded":
		commitment = 1.0
		offset = -direction * world_radius * 0.05
		lift = -world_radius * 0.10
		width_scale = 1.08
		height_scale = 0.84
		twist = -0.08

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
