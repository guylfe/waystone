class_name CombatCatalog
extends RefCounted

# This is intentionally a data catalogue rather than a second combat simulator.
# RunState still owns timing, collision, and current prototype balancing.  The
# catalogue gives every actor the same vocabulary so future character tracks,
# equipment, and enemy variants can use one foundation.

const ATTRIBUTE_KEYS := ["health", "speed", "stealth", "awareness", "resolve", "intelligence", "faith"]

const ATTRIBUTE_DEFAULTS := {
	"health": 5,
	"speed": 5,
	"stealth": 0,
	"awareness": 5,
	"resolve": 5,
	"intelligence": 0,
	"faith": 0,
}

const PROPERTY_DEFAULTS := {
	"armor": 0,
	"resistances": {"physical": 0, "fire": 0, "ice": 0, "arcane": 0},
	"status_resistance": 0,
	"mass": 1.0,
	"collision_radius": 28.0,
	"vision_range": 520.0,
	"hearing_range": 260.0,
	"alertness_decay": 1.0,
	"healing_received": 1.0,
	"action_speed_multiplier": 1.0,
	"cooldown_multiplier": 1.0,
	"temporal_authority": 0,
	"offhand": "",
}

# These three values are shared martial learning. They are not Dark Souls-style
# coefficients and do not scale an arbitrary weapon from a generic Strength.
# A weapon frame maps its own tiers to its chosen attacks when progression is
# implemented later.
const MARTIAL_DEFAULTS := {
	"power": 0,
	"impact": 0,
	"handling": 0,
	"technique_capacity": 1,
}

const WEAPON_FRAMES := {
	"sword": {"label": "Sword", "delivery": "melee", "basic_technique": "diagonal_cut", "art_ids": ["sword_thrust", "sword_riposte"]},
	"axe": {"label": "Hand Axe", "delivery": "melee", "basic_technique": "heavy_chop", "art_ids": ["axe_hook", "axe_splitter"]},
	"zweihander": {"label": "Zweihander", "delivery": "melee", "basic_technique": "heavy_cleave", "art_ids": ["zweihander_sweep", "zweihander_half_sword"]},
	"spear": {"label": "Spear", "delivery": "melee", "basic_technique": "thrust", "art_ids": ["spear_brace", "spear_lunge"]},
	"twin_knives": {"label": "Twin Knives", "delivery": "melee", "basic_technique": "quick_cut", "art_ids": ["twin_flurry", "twin_evasive_counter"]},
	"bow": {"label": "Bow", "delivery": "ranged", "basic_technique": "drawn_shot", "art_ids": ["bow_drawn_shot", "bow_scatter_shot"]},
	"impact": {"label": "Impact Weapon", "delivery": "melee", "basic_technique": "forward_smash", "art_ids": ["impact_ground_smash", "impact_guard_break"]},
	"staff": {"label": "Staff", "delivery": "melee", "basic_technique": "staff_strike", "art_ids": ["staff_push_sweep", "staff_vault"]},
	"natural": {"label": "Natural Weapon", "delivery": "melee", "basic_technique": "bite", "art_ids": ["natural_pounce", "natural_flurry"]},
	"unarmed": {"label": "Unarmed", "delivery": "melee", "basic_technique": "quick_cut", "art_ids": ["unarmed_step_in", "unarmed_breaker"]},
}

const WEAPON_ARTS := {
	"sword_thrust": {"label": "Measured Thrust", "frame": "sword", "style": "reach", "gate": "martial_manual"},
	"sword_riposte": {"label": "Guarding Riposte", "frame": "sword", "style": "counter", "gate": "veteran_trainer"},
	"axe_hook": {"label": "Hooking Chop", "frame": "axe", "style": "displace", "gate": "hunter_cache"},
	"axe_splitter": {"label": "Splitter", "frame": "axe", "style": "impact", "gate": "elite_foe"},
	"zweihander_sweep": {"label": "Sweeping Cut", "frame": "zweihander", "style": "space_control", "gate": "warrior_manual"},
	"zweihander_half_sword": {"label": "Half-Sword Thrust", "frame": "zweihander", "style": "precision", "gate": "ruin_lesson"},
	"spear_brace": {"label": "Brace", "frame": "spear", "style": "counter", "gate": "watchpost"},
	"spear_lunge": {"label": "Long Lunge", "frame": "spear", "style": "reach", "gate": "elite_foe"},
	"twin_flurry": {"label": "Knife Flurry", "frame": "twin_knives", "style": "pressure", "gate": "thieves_mark"},
	"twin_evasive_counter": {"label": "Evasive Counter", "frame": "twin_knives", "style": "mobility", "gate": "duelist_trainer"},
	"bow_drawn_shot": {"label": "Drawn Shot", "frame": "bow", "style": "pressure", "gate": "ranger_cache"},
	"bow_scatter_shot": {"label": "Scatter Shot", "frame": "bow", "style": "space_control", "gate": "elite_foe"},
	"impact_ground_smash": {"label": "Ground Smash", "frame": "impact", "style": "impact", "gate": "quarry_lesson"},
	"impact_guard_break": {"label": "Guard Break", "frame": "impact", "style": "disrupt", "gate": "armory_manual"},
	"staff_push_sweep": {"label": "Push Sweep", "frame": "staff", "style": "space_control", "gate": "academy_lesson"},
	"staff_vault": {"label": "Vault", "frame": "staff", "style": "mobility", "gate": "wind_shrine"},
	"natural_pounce": {"label": "Pounce", "frame": "natural", "style": "engage", "gate": "natural"},
	"natural_flurry": {"label": "Claw Flurry", "frame": "natural", "style": "pressure", "gate": "natural"},
	"unarmed_step_in": {"label": "Step In", "frame": "unarmed", "style": "engage", "gate": "trainer"},
	"unarmed_breaker": {"label": "Breaker", "frame": "unarmed", "style": "impact", "gate": "trainer"},
	"prototype_sweeping_cut": {"label": "Sweeping Cut", "frame": "sword", "style": "space_control", "gate": "prototype"},
	"prototype_drawing_cut": {"label": "Drawing Cut", "frame": "sword", "style": "precision", "gate": "prototype"},
}

const LOADOUT_PROFILES := {
	"wayfarer": {"weapon_frame": "sword", "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "dodge", "attributes": {"health": 4, "speed": 7, "stealth": 3, "awareness": 6, "resolve": 3, "intelligence": 0, "faith": 0}, "properties": {"mass": 0.85}},
}

const WAYFARER_TRACK_ORDER := ["weaponry", "evasion", "vigilance", "fieldcraft", "openings"]

const WAYFARER_TRACKS := {
	"weaponry": {
		"label": "Weaponry",
		"description": "Shared martial learning, beginning with a chosen Weapon Skill.",
		"properties": [
			{"id": "weaponry_art", "label": "Weapon Skill", "description": "Choose one Sword Art as your first weapon lesson. The other can be learned and swapped at a later Waystone.", "max_rank": 1, "gate": 0, "choice": true},
			{"id": "weaponry_power", "label": "Power", "description": "Raises maximum weapon damage.", "max_rank": 3, "gate": 0},
			{"id": "weaponry_impact", "label": "Impact", "description": "Raises posture damage.", "max_rank": 3, "gate": 0},
			{"id": "weaponry_handling", "label": "Handling", "description": "Shortens weapon recovery.", "max_rank": 3, "gate": 1},
			{"id": "weaponry_technique", "label": "Technique", "description": "Improves Weapon Art readiness.", "max_rank": 3, "gate": 3},
		],
	},
	"evasion": {
		"label": "Evasion",
		"description": "Improves the equipped defensive action.",
		"properties": [
			{"id": "evasion_distance", "label": "Distance", "description": "Travel farther when dodging.", "max_rank": 3, "gate": 0},
			{"id": "evasion_recovery", "label": "Recovery", "description": "Recover sooner after dodging.", "max_rank": 3, "gate": 0},
			{"id": "evasion_cooldown", "label": "Readiness", "description": "Shortens defensive cooldowns.", "max_rank": 3, "gate": 2},
			{"id": "evasion_clean_escape", "label": "Clean Escape", "description": "A well-timed dodge briefly hides you.", "max_rank": 1, "gate": 5},
		],
	},
	"vigilance": {
		"label": "Vigilant",
		"description": "The Wayfarer's trainable temperament.",
		"properties": [
			{"id": "vigilance_health", "label": "Health", "description": "Raises maximum health.", "max_rank": 3, "gate": 0},
			{"id": "vigilance_speed", "label": "Speed", "description": "Raises movement speed.", "max_rank": 3, "gate": 0},
			{"id": "vigilance_awareness", "label": "Awareness", "description": "Extends perception range.", "max_rank": 3, "gate": 2},
			{"id": "vigilance_stealth", "label": "Stealth", "description": "Reduces enemy detection.", "max_rank": 3, "gate": 4},
		],
	},
	"fieldcraft": {
		"label": "Fieldcraft",
		"description": "Makes restorative supplies more dependable.",
		"properties": [
			{"id": "fieldcraft_capacity", "label": "Capacity", "description": "Carries one more restorative in Campaign.", "max_rank": 2, "gate": 0},
			{"id": "fieldcraft_restoration", "label": "Restoration", "description": "Potions restore more health.", "max_rank": 3, "gate": 0},
			{"id": "fieldcraft_recovery", "label": "Use Recovery", "description": "Recover sooner after drinking.", "max_rank": 3, "gate": 2},
			{"id": "fieldcraft_remedy", "label": "Remedy", "description": "Restoratives clear a minor ailment.", "max_rank": 1, "gate": 5},
		],
	},
	"openings": {
		"label": "Openings",
		"description": "Rewards reading an enemy's commitment.",
		"properties": [
			{"id": "openings_posture", "label": "Break Punish", "description": "Deal more posture damage to committed foes.", "max_rank": 3, "gate": 0},
			{"id": "openings_recovery", "label": "Recovery Punish", "description": "Deal more damage during enemy recovery.", "max_rank": 3, "gate": 0},
			{"id": "openings_break_duration", "label": "Break Duration", "description": "Posture breaks last longer.", "max_rank": 3, "gate": 2},
			{"id": "openings_composure", "label": "Composure", "description": "A punish slightly restores readiness.", "max_rank": 1, "gate": 5},
		],
	},
}

const ARCHETYPES := {
	"boar": {"weapon_frame": "natural", "weapon_arts": ["natural_pounce"], "equipped_weapon_art": "natural_pounce", "defense_id": "", "attributes": {"health": 6, "speed": 4, "stealth": 0, "awareness": 4, "resolve": 5, "intelligence": 0, "faith": 0}, "properties": {"mass": 1.25}},
	"hound": {"weapon_frame": "natural", "weapon_arts": ["natural_pounce"], "equipped_weapon_art": "natural_pounce", "defense_id": "evasive_recovery", "attributes": {"health": 5, "speed": 8, "stealth": 3, "awareness": 6, "resolve": 3, "intelligence": 0, "faith": 0}, "properties": {"mass": 0.75}},
	"bandit": {"weapon_frame": "twin_knives", "weapon_arts": ["twin_evasive_counter"], "equipped_weapon_art": "twin_evasive_counter", "defense_id": "dodge", "attributes": {"health": 4, "speed": 6, "stealth": 3, "awareness": 5, "resolve": 2, "intelligence": 0, "faith": 0}, "properties": {}},
	"knife": {"weapon_frame": "twin_knives", "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "", "attributes": {"health": 3, "speed": 6, "stealth": 2, "awareness": 4, "resolve": 2, "intelligence": 0, "faith": 0}, "properties": {}},
	"blade": {"weapon_frame": "sword", "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "", "attributes": {"health": 5, "speed": 4, "stealth": 0, "awareness": 5, "resolve": 5, "intelligence": 0, "faith": 0}, "properties": {}},
	"archer": {"weapon_frame": "bow", "weapon_arts": ["bow_drawn_shot"], "equipped_weapon_art": "bow_drawn_shot", "defense_id": "", "attributes": {"health": 4, "speed": 4, "stealth": 2, "awareness": 7, "resolve": 3, "intelligence": 0, "faith": 0}, "properties": {"vision_range": 620.0}},
	"shield": {"weapon_frame": "sword", "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "block", "attributes": {"health": 7, "speed": 2, "stealth": 0, "awareness": 4, "resolve": 7, "intelligence": 0, "faith": 0}, "properties": {"armor": 1, "mass": 1.35, "offhand": "shield"}},
	"polearm": {"weapon_frame": "spear", "weapon_arts": ["spear_lunge"], "equipped_weapon_art": "spear_lunge", "defense_id": "", "attributes": {"health": 7, "speed": 2, "stealth": 0, "awareness": 5, "resolve": 7, "intelligence": 0, "faith": 0}, "properties": {"mass": 1.15}},
	"hexer": {"weapon_frame": "staff", "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "", "attributes": {"health": 5, "speed": 3, "stealth": 0, "awareness": 7, "resolve": 3, "intelligence": 7, "faith": 0}, "properties": {"vision_range": 620.0}},
	"ice_caster": {"weapon_frame": "staff", "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "", "attributes": {"health": 5, "speed": 3, "stealth": 0, "awareness": 7, "resolve": 3, "intelligence": 8, "faith": 0}, "properties": {"resistances": {"ice": 2}, "vision_range": 620.0}},
	"fire_caster": {"weapon_frame": "staff", "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "", "attributes": {"health": 5, "speed": 4, "stealth": 0, "awareness": 7, "resolve": 3, "intelligence": 8, "faith": 0}, "properties": {"resistances": {"fire": 2}, "vision_range": 620.0}},
	"brute": {"weapon_frame": "impact", "weapon_arts": ["impact_ground_smash"], "equipped_weapon_art": "impact_ground_smash", "defense_id": "", "attributes": {"health": 9, "speed": 1, "stealth": 0, "awareness": 3, "resolve": 9, "intelligence": 0, "faith": 0}, "properties": {"mass": 1.65}},
	"knight": {"weapon_frame": "zweihander", "weapon_arts": ["zweihander_sweep", "zweihander_half_sword"], "equipped_weapon_art": "zweihander_sweep", "defense_id": "", "attributes": {"health": 10, "speed": 1, "stealth": 0, "awareness": 5, "resolve": 10, "intelligence": 0, "faith": 0}, "properties": {"armor": 2, "mass": 1.7}},
	"captain": {"weapon_frame": "sword", "weapon_arts": ["sword_thrust"], "equipped_weapon_art": "sword_thrust", "defense_id": "", "attributes": {"health": 7, "speed": 5, "stealth": 0, "awareness": 7, "resolve": 6, "intelligence": 0, "faith": 0}, "properties": {}},
	"warden": {"weapon_frame": "zweihander", "weapon_arts": ["zweihander_sweep"], "equipped_weapon_art": "zweihander_sweep", "defense_id": "", "attributes": {"health": 10, "speed": 2, "stealth": 0, "awareness": 7, "resolve": 10, "intelligence": 0, "faith": 0}, "properties": {"armor": 1, "mass": 1.6}},
	"werewolf": {"weapon_frame": "natural", "weapon_arts": ["natural_pounce", "natural_flurry"], "equipped_weapon_art": "natural_pounce", "defense_id": "evasive_recovery", "attributes": {"health": 10, "speed": 7, "stealth": 4, "awareness": 8, "resolve": 7, "intelligence": 0, "faith": 0}, "properties": {"mass": 1.45}},
}

static func weapon_frame(id: String) -> Dictionary:
	return Dictionary(WEAPON_FRAMES.get(id, WEAPON_FRAMES["unarmed"])).duplicate(true)

static func weapon_art(id: String) -> Dictionary:
	return Dictionary(WEAPON_ARTS.get(id, {})).duplicate(true)

static func wayfarer_track(id: String) -> Dictionary:
	return Dictionary(WAYFARER_TRACKS.get(id, {})).duplicate(true)

static func wayfarer_property(id: String) -> Dictionary:
	for track_id in WAYFARER_TRACK_ORDER:
		for property in Array(Dictionary(WAYFARER_TRACKS[track_id])["properties"]):
			if String(property["id"]) == id:
				var result := Dictionary(property).duplicate(true)
				result["track_id"] = track_id
				return result
	return {}

static func loadout_profile(id: String) -> Dictionary:
	return _profile_with_defaults(Dictionary(LOADOUT_PROFILES.get(id, LOADOUT_PROFILES["wayfarer"])))

static func archetype(id: String) -> Dictionary:
	return _profile_with_defaults(Dictionary(ARCHETYPES.get(id, ARCHETYPES["blade"])))

static func _profile_with_defaults(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	var attributes := ATTRIBUTE_DEFAULTS.duplicate(true)
	attributes.merge(Dictionary(result.get("attributes", {})), true)
	var properties := PROPERTY_DEFAULTS.duplicate(true)
	properties.merge(Dictionary(result.get("properties", {})), true)
	result["attributes"] = attributes
	result["properties"] = properties
	if not result.has("weapon_arts"): result["weapon_arts"] = []
	if not result.has("equipped_weapon_art"): result["equipped_weapon_art"] = ""
	if not result.has("defense_id"): result["defense_id"] = ""
	return result
