extends RefCounted
## Neutral one-handed light attacks. Distances use Campaign's planar simulation units.
## For evidence, projection assumptions and field semantics, see docs/campaign-player-reference.md.

const FPS := 30.0

# start, active end, same-hand continuation, free movement (all in 30 Hz ticks),
# planar reach, root advance near contact, root advance at continuation, root advance at free movement, then the tick of the sampled near-contact advance.
# Spatial columns are in Waystone units (100 per reference metre).
const ELDEN_RING := {
	"dagger": [
		[10, 12, 16, 22, 162.9, 116.2, 146.1, 153.4, 11],
		[8, 10, 14, 20, 150.6, 114.8, 145.5, 147.5, 9],
		[9, 11, 15, 23, 148.3, 71.8, 88.5, 99.5, 10],
		[8, 10, 15, 19, 137.3, 76.9, 108.6, 109.8, 9],
		[9, 11, 16, 25, 152.8, 70.0, 98.8, 110.4, 10],
		[14, 16, 32, 33, 134.0, 98.5, 133.0, 135.0, 15],
	],
	"straight_sword": [
		[13, 16, 21, 29, 211.0, 147.5, 150.8, 149.3, 15],
		[13, 15, 23, 28, 200.2, 90.4, 99.0, 98.1, 14],
		[13, 16, 20, 28, 208.0, 112.1, 119.8, 119.5, 14],
		[11, 14, 23, 28, 191.4, 79.8, 92.0, 93.1, 13],
		[18, 22, 44, 45, 220.2, 121.9, 129.2, 130.3, 20],
	],
	"greatsword": [
		[15, 18, 32, 42, 212.8, 143.0, 190.9, 201.3, 17],
		[15, 18, 32, 42, 217.9, 79.9, 132.9, 134.8, 17],
		[16, 19, 32, 43, 220.2, 56.7, 100.0, 122.1, 18],
		[22, 27, 46, 54, 224.6, 121.7, 105.2, 106.1, 24],
	],
}

# Measured opener centre-to-centre range against a stationary Hollow Soldier.
const DS1_RANGE := {"dagger": 240.0, "straight_sword": 325.0, "greatsword": 345.0}
const DS1_APS := {"dagger": 2.19, "straight_sword": 1.52}
const REFERENCE_TARGET_RADIUS := 28.0

static func profile(style: String, weapon: String) -> Dictionary:
	if not ELDEN_RING.has(weapon) or style not in ["slow", "fast"]:
		return {}
	var fast := style == "fast"
	var strikes: Array[Dictionary] = []
	var rows: Array = ELDEN_RING[weapon]
	for index in range(rows.size() if fast else 2):
		var row: Array = rows[index]
		if fast:
			strikes.append(_strike(row[0] / FPS, row[1] / FPS, row[2] / FPS, row[3] / FPS,
				row[4], row[5], row[6], row[7], row[8] / FPS))
		else:
			strikes.append(_dark_souls_strike(weapon, index, row))
	return {
		"move_speed": 401.2 if fast else 260.0, "step_distance": 34.0,
		"roll_distance": 331.6 if fast else 245.0,
		"roll_duration": (22.0 if fast else 33.0) / FPS,
		"roll_move_end": (22.0 if fast else 20.0) / FPS,
		"iframe_start": 0.0, "iframe_end": (13.0 if fast else 11.0) / FPS,
		"attacks": strikes,
	}

static func _dark_souls_strike(weapon: String, index: int, proxy: Array) -> Dictionary:
	# Keep the measured opener spacing. Separate blade and root with an explicitly
	# cross-game reach proxy. Hold both distances constant for the unmeasured return.
	var reach := float(ELDEN_RING[weapon][0][4])
	var advance := float(DS1_RANGE[weapon]) - REFERENCE_TARGET_RADIUS - reach
	if weapon == "greatsword":
		# KC's first-contact, reswing and movement ticks. Three active ticks are a proxy.
		var start_tick := 20.0 if index == 0 else 18.0
		return _strike(start_tick / FPS, (start_tick + 3.0) / FPS,
			(31.0 if index == 0 else 29.0) / FPS, (43.0 if index == 0 else 40.0) / FPS,
			reach, advance, advance, advance, start_tick / FPS)
	# The APS experiment timed repeated swings. Split that measured interval with
	# the homologous ER move's proportions where DS1 one-handed events are unknown.
	var interval := 1.0 / float(DS1_APS[weapon])
	var seconds_per_proxy_tick := interval / float(proxy[2])
	return _strike(float(proxy[0]) * seconds_per_proxy_tick, float(proxy[1]) * seconds_per_proxy_tick,
		interval, float(proxy[3]) * seconds_per_proxy_tick, reach, advance, advance, advance,
		float(proxy[0]) * seconds_per_proxy_tick)

static func _strike(start: float, active_end: float, chain: float, finish: float,
		reach: float, advance: float, travel_at_chain: float, travel_at_move: float, advance_at: float) -> Dictionary:
	return {
		"startup": start, "active_end": active_end, "chain_at": chain, "duration": finish,
		"reach": reach, "advance_distance": advance, "advance_at": advance_at,
		"travel_at_chain": travel_at_chain, "travel_at_move": travel_at_move,
	}
