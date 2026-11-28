extends RefCounted
## Selected infantry phrases on the four-region Campaign path.
## AI ranges, animation evidence and Waystone adaptations are documented in
## docs/campaign-enemy-reference.md. Style never scales the entire enemy clock.

const Catalog = preload("res://scripts/core/combat_catalog.gd")
const UNITS_PER_REFERENCE_UNIT := 100.0
const EVENT_HZ := 30.0

# Each window gives first active tick, end of activity, earliest continuation,
# and free recovery in 30 Hz notation. Only the Fast startup ticks are measured.
# Travel and reach are independent Waystone estimates in reference metres.
const SLOW := {
	"blade": {
		"chain_chances": [0.80, 0.5625],
		"attacks": [
			{"technique": "diagonal_cut", "gap": 2.2, "window": [25, 31, 39, 60], "reach": 1.73, "travel": 0.67},
			{"technique": "reverse_cut", "gap": 2.2, "window": [18, 23, 30, 49], "reach": 1.63, "travel": 0.50},
			{"technique": "diagonal_cut", "gap": 2.2, "window": [23, 29, 54, 54], "reach": 1.80, "travel": 0.57},
		],
	},
	"knife": {
		"chain_chances": [],
		"attacks": [
			{"technique": "quick_cut", "gap": 2.0, "window": [18, 22, 43, 43], "reach": 1.33, "travel": 0.55},
		],
	},
	"shield": {
		"chain_chances": [],
		"attacks": [
			{"technique": "rapier_thrust", "gap": 4.1, "window": [35, 42, 73, 73], "reach": 1.97, "travel": 2.00},
		],
	},
	"polearm": {
		"chain_chances": [0.70, 3.0 / 7.0],
		"attacks": [
			{"technique": "thrust", "gap": 2.8, "window": [24, 30, 39, 61], "reach": 2.55, "travel": 0.33},
			{"technique": "thrust", "gap": 2.8, "window": [18, 23, 32, 50], "reach": 2.43, "travel": 0.27},
			{"technique": "thrust", "gap": 2.8, "window": [22, 28, 57, 57], "reach": 2.55, "travel": 0.45},
		],
	},
}

const FAST := {
	"blade": {
		"chain_chances": [1.0],
		"attacks": [
			{"technique": "diagonal_cut", "gap": 2.5, "window": [22, 27, 32, 47], "reach": 1.75, "travel": 0.87},
			{"technique": "reverse_cut", "gap": 2.5, "window": [30, 35, 51, 51], "reach": 1.88, "travel": 0.73},
		],
	},
	"knife": {
		"chain_chances": [],
		"attacks": [
			{"technique": "quick_cut", "gap": 2.5, "window": [12, 17, 35, 35], "reach": 1.40, "travel": 1.00},
		],
	},
	"shield": {
		"chain_chances": [1.0, 1.0],
		"attacks": [
			{"technique": "diagonal_cut", "gap": 2.5, "window": [24, 29, 34, 51], "reach": 1.87, "travel": 0.70},
			{"technique": "reverse_cut", "gap": 2.5, "window": [17, 22, 27, 46], "reach": 1.77, "travel": 0.63},
			{"technique": "diagonal_cut", "gap": 3.0, "window": [30, 36, 58, 58], "reach": 2.08, "travel": 0.80},
		],
	},
	"polearm": {
		"chain_chances": [],
		"attacks": [
			{"technique": "thrust", "gap": 3.2, "window": [18, 24, 44, 44], "reach": 2.75, "travel": 0.53},
		],
	},
}


static func profile(style: String, kind: String) -> Dictionary:
	var roster: Dictionary = {"slow": SLOW, "fast": FAST}.get(style, {})
	if not roster.has(kind):
		return {}
	var phrase: Dictionary = roster[kind]
	var attacks: Array[Dictionary] = []
	var base: Dictionary = Catalog.melee_attack_plan(kind)[0]
	for move: Dictionary in phrase.attacks:
		var option := base.duplicate()
		var window: Array = move.window
		option.merge({
			"technique": move.technique,
			"distance": float(move.gap) * UNITS_PER_REFERENCE_UNIT,
			"startup": float(window[0]) / EVENT_HZ,
			"active_end": float(window[1]) / EVENT_HZ,
			"chain_at": float(window[2]) / EVENT_HZ,
			"duration": float(window[3]) / EVENT_HZ,
			"reach": float(move.reach) * UNITS_PER_REFERENCE_UNIT,
			"advance_distance": float(move.travel) * UNITS_PER_REFERENCE_UNIT,
			"advance_end": float(window[0]) / EVENT_HZ,
		}, true)
		attacks.append(option)
	return {
		"attacks": attacks,
		"chain_chances": phrase.chain_chances.duplicate(),
		"move_speed": float(Catalog.enemy_fact(kind, "move_speed")),
	}
