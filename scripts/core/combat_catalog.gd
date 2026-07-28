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
	"warrior": {"weapon_frame": "sword", "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "dodge", "attributes": {"health": 20, "speed": 5, "stealth": 1, "awareness": 5, "resolve": 7, "intelligence": 0, "faith": 0}, "properties": {"mass": 1.05}},
}

const CHARACTER_TRACK_ORDER := ["swordsmanship", "evasion", "steadfast", "warrior", "vanguard", "adopted"]

# Each stage is the next node in a compact track. A gate is a minimum character
# level, so an unchosen node remains available after its gate instead of
# disappearing forever. Choice stages spend one level and permanently record
# exactly one choice for that run.
const CHARACTER_TRACKS := {
	"swordsmanship": {
		"label": "Swordsmanship",
		"description": "Sword fundamentals and one permanent expression of the weapon.",
		"stages": [
			{"id": "sword_art", "label": "Weapon Art", "gate": 2, "description": "Choose one Sword Art for this run.", "choices": [
				{"id": "prototype_sweeping_cut", "label": "Sweeping Cut", "description": "A broad multi-target cut with exceptional posture force."},
				{"id": "prototype_drawing_cut", "label": "Drawing Cut", "description": "A narrow, forceful cut that reaches through a precise opening."},
			]},
			{"id": "edge_control", "label": "Edge Control", "gate": 5, "description": "All sword attacks gain +1 maximum damage and +0.5 posture damage."},
			{"id": "art_refinement", "label": "Art Refinement", "gate": 8, "description": "Improve the reach, startup, and posture identity of your chosen Sword Art."},
			{"id": "flowing_steel", "label": "Flowing Steel", "gate": 10, "description": "Sword recovery is 12% shorter and combo transitions are 10% faster."},
		],
	},
	"evasion": {
		"label": "Evasion",
		"description": "Turn the basic dodge into a chosen evasive discipline.",
		"stages": [
			{"id": "practised_landing", "label": "Practised Landing", "gate": 2, "description": "Basic Dodge recovery falls from 0.66 to 0.60 seconds."},
			{"id": "evasion_style", "label": "Evasive Form", "gate": 4, "description": "Permanently specialize your Dodge for this run.", "choices": [
				{"id": "sidestep", "label": "Sidestep", "description": "The same travel in less time, with a 3.2-second cooldown."},
				{"id": "long_roll", "label": "Long Roll", "description": "A longer committed roll covering 217 units."},
			]},
			{"id": "evasion_refinement", "label": "Form Refinement", "gate": 7, "description": "Deepen the speed and readiness of your chosen form."},
			{"id": "evasion_mastery", "label": "Perfect Form", "gate": 10, "description": "A physically clean dodge produces a form-specific reward."},
		],
	},
	"steadfast": {
		"label": "Steadfast",
		"description": "Temperament: train complementary traits rather than every universal statistic.",
		"stages": [
			{"id": "steadfast_1", "label": "Temperament I", "gate": 3, "description": "Choose how hard experience changes you.", "choices": [
				{"id": "toughness", "label": "Toughness", "description": "+3 maximum health and +1 Resolve."},
				{"id": "readiness", "label": "Readiness", "description": "+1 Speed, +1 Awareness, +3.5% movement, and +35 sight range."},
			]},
			{"id": "steadfast_2", "label": "Temperament II", "gate": 6, "description": "Choose Toughness or Readiness again.", "choices_ref": "steadfast_1"},
			{"id": "steadfast_3", "label": "Temperament III", "gate": 9, "description": "Choose Toughness or Readiness again.", "choices_ref": "steadfast_1"},
			{"id": "steadfast_4", "label": "Temperament IV", "gate": 12, "description": "Choose Toughness or Readiness again.", "choices_ref": "steadfast_1"},
		],
	},
	"warrior": {
		"label": "Warrior",
		"description": "Rally through danger while every health point still matters.",
		"stages": [
			{"id": "battle_fervor", "label": "Battle Fervor", "gate": 2, "description": "Rally lasts 5 seconds; its post-effect cooldown falls to 10.5 seconds."},
			{"id": "rally_style", "label": "Rally Discipline", "gate": 5, "description": "Permanently choose the emphasis of Rally.", "choices": [
				{"id": "rally_fury", "label": "Fury", "description": "Rally grants +1 minimum/+1 maximum damage, +2 posture, and 4 action poise."},
				{"id": "rally_iron", "label": "Iron Resolve", "description": "Rally keeps its modest damage bonus but raises action poise from 4 to 7."},
			]},
			{"id": "deep_reserves", "label": "Deep Reserves", "gate": 8, "description": "Rally's post-effect cooldown falls to 9 seconds."},
			{"id": "rally_mastery", "label": "Rally Mastery", "gate": 11, "description": "Fury escalates consecutive hits; Iron Resolve carries one broken action through."},
		],
	},
	"vanguard": {
		"label": "Vanguard",
		"description": "Advance with an authored impact instead of attacking during a movement animation.",
		"stages": [
			{"id": "driving_impact", "label": "Driving Impact", "gate": 2, "description": "Advance posture rises from 3 to 4 and push rises from 36 to 48."},
			{"id": "advance_style", "label": "Advance Discipline", "gate": 3, "description": "Permanently choose how Advance claims space.", "choices": [
				{"id": "breakthrough", "label": "Breakthrough", "description": "Gain action poise and drive through light bodies."},
				{"id": "pursuit", "label": "Pursuit", "description": "Travel farther with a shorter cooldown, but no action poise."},
			]},
			{"id": "maintain_momentum", "label": "Maintain Momentum", "gate": 6, "description": "Hold the original Advance input through impact to flow directly into a full sword combo."},
			{"id": "advance_mastery", "label": "Advance Mastery", "gate": 9, "description": "Deepen Breakthrough or Pursuit according to the permanent choice already made."},
		],
	},
	"adopted": {
		"label": "Undiscovered",
		"description": "A late-run adopted discipline. It is deliberately unavailable in this prototype.",
		"stages": [],
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

static func character_track(id: String) -> Dictionary:
	return Dictionary(CHARACTER_TRACKS.get(id, {})).duplicate(true)

static func character_stage(track_id: String, rank: int) -> Dictionary:
	var stages: Array = Dictionary(CHARACTER_TRACKS.get(track_id, {})).get("stages", [])
	if rank < 0 or rank >= stages.size(): return {}
	var result := Dictionary(stages[rank]).duplicate(true)
	result["track_id"] = track_id
	result["rank"] = rank + 1
	if result.has("choices_ref"):
		for source_value in stages:
			var source := Dictionary(source_value)
			if String(source.get("id", "")) == String(result["choices_ref"]):
				result["choices"] = Array(source.get("choices", [])).duplicate(true)
				break
	return result

static func character_stage_by_id(id: String) -> Dictionary:
	for track_id in CHARACTER_TRACK_ORDER:
		var track := Dictionary(CHARACTER_TRACKS[track_id])
		for rank in range(Array(track.get("stages", [])).size()):
			var stage := character_stage(String(track_id), rank)
			if String(stage.get("id", "")) == id: return stage
	return {}

static func loadout_profile(id: String) -> Dictionary:
	return _profile_with_defaults(Dictionary(LOADOUT_PROFILES.get(id, LOADOUT_PROFILES["warrior"])))

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
