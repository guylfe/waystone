class_name CombatCatalog
extends RefCounted

# This is intentionally a data catalogue rather than a second combat simulator.
# RunState still owns timing, collision, and current prototype balancing.  The
# catalogue gives every actor the same vocabulary so future character tracks,
# equipment, and enemy variants can use one foundation.

const ATTRIBUTE_KEYS := ["health", "stamina", "strength", "defense", "speed", "stealth", "awareness", "resolve", "resistance", "intelligence", "faith"]

const ATTRIBUTE_DEFAULTS := {
	"health": 5,
	"stamina": 100,
	"strength": 5,
	"defense": 0,
	"speed": 5,
	"stealth": 0,
	"awareness": 5,
	"resolve": 5,
	"resistance": 5,
	"intelligence": 0,
	"faith": 0,
}

const PROPERTY_DEFAULTS := {
	"armor": 0,
	"resistances": {"physical": 0, "fire": 0, "ice": 0, "arcane": 0},
	"status_resistance": 0,
	"mass": 1.0,
	"posture_base": 5.0,
	"posture_recovery": 1.8,
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
	"knife": {"label": "Knife", "delivery": "melee", "basic_technique": "quick_cut", "art_ids": ["knife_execution", "knife_twin_fang"], "guard_profile": "light"},
	"sword": {"label": "Sword", "delivery": "melee", "basic_technique": "diagonal_cut", "art_ids": ["sword_thrust", "sword_riposte"]},
	"axe": {"label": "Hand Axe", "delivery": "melee", "basic_technique": "heavy_chop", "art_ids": ["axe_hook", "axe_splitter"]},
	"zweihander": {"label": "Zweihander", "delivery": "melee", "basic_technique": "heavy_cleave", "art_ids": ["zweihander_sweep", "zweihander_half_sword"]},
	"spear": {"label": "Spear", "delivery": "melee", "basic_technique": "thrust", "art_ids": ["spear_brace", "spear_lunge"]},
	"twin_knives": {"label": "Twin Knives", "delivery": "melee", "basic_technique": "quick_cut", "art_ids": ["knife_twin_fang"], "guard_profile": "dual"},
	"bow": {"label": "Bow", "delivery": "ranged", "basic_technique": "drawn_shot", "art_ids": ["bow_piercing_shot", "bow_fan_shot"], "guard_profile": "awkward"},
	"impact": {"label": "Impact Weapon", "delivery": "melee", "basic_technique": "forward_smash", "art_ids": ["impact_ground_smash", "impact_guard_break"]},
	"staff": {"label": "Staff", "delivery": "melee", "basic_technique": "staff_strike", "art_ids": ["staff_push_sweep", "staff_vault"]},
	"natural": {"label": "Natural Weapon", "delivery": "melee", "basic_technique": "bite", "art_ids": ["natural_pounce", "natural_flurry"]},
	"unarmed": {"label": "Unarmed", "delivery": "melee", "basic_technique": "quick_cut", "art_ids": ["unarmed_step_in", "unarmed_breaker"]},
}

const WEAPON_ARTS := {
	"knife_execution": {"label": "Execution", "frame": "knife", "style": "unaware", "gate": "first_rank"},
	"knife_twin_fang": {"label": "Twin Fang", "frame": "knife", "style": "pressure", "gate": "first_rank"},
	"bow_piercing_shot": {"label": "Piercing Shot", "frame": "bow", "style": "line", "gate": "first_rank"},
	"bow_fan_shot": {"label": "Fan Shot", "frame": "bow", "style": "space_control", "gate": "first_rank"},
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
	"warrior": {"name": "Warrior · Vanguard", "weapon_frame": "sword", "track_order": ["swordsmanship", "evasion", "steadfast", "warrior", "vanguard", "adopted"], "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "dodge", "attributes": {"health": 100, "strength": 5, "defense": 4, "speed": 5, "stealth": 1, "awareness": 5, "resolve": 7, "resistance": 6, "intelligence": 2, "faith": 2}, "properties": {"mass": 1.05}},
	"rogue_acrobat": {"name": "Rogue · Acrobat", "weapon_frame": "knife", "track_order": ["knife", "evasion", "finesse", "rogue", "acrobat", "adopted"], "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "dodge", "attributes": {"health": 80, "strength": 4, "defense": 2, "speed": 7, "stealth": 7, "awareness": 6, "resolve": 3, "resistance": 4, "intelligence": 4, "faith": 2}, "properties": {"mass": 0.82}},
	"rogue_sharpshooter": {"name": "Rogue · Sharpshooter", "weapon_frame": "bow", "track_order": ["bow", "evasion", "patient", "rogue", "sharpshooter", "adopted"], "weapon_arts": [], "equipped_weapon_art": "", "defense_id": "dodge", "attributes": {"health": 85, "strength": 4, "defense": 2, "speed": 6, "stealth": 7, "awareness": 8, "resolve": 4, "resistance": 4, "intelligence": 4, "faith": 2}, "properties": {"mass": 0.88}},
}

const CHARACTER_TRACK_ORDER := ["swordsmanship", "evasion", "steadfast", "warrior", "vanguard", "knife", "finesse", "rogue", "acrobat", "bow", "patient", "sharpshooter", "adopted"]

# Each stage is the next node in a compact track. A gate is a minimum character
# level, so an unchosen node remains available after its gate instead of
# disappearing forever. Choice stages spend one level and permanently record
# exactly one choice for that run.
const CHARACTER_TRACKS := {
	"swordsmanship": {
		"label": "Swordsmanship",
		"description": "A permanent Sword Art, precise combo control, and authored reach.",
		"stages": [
			{"id": "sword_art", "label": "Weapon Art", "gate": 2, "description": "Choose one Sword Art for this run.", "choices": [
				{"id": "prototype_sweeping_cut", "label": "Sweeping Cut", "description": "A broad multi-target cut with exceptional posture force."},
				{"id": "prototype_drawing_cut", "label": "Drawing Cut", "description": "A narrow, forceful cut that reaches through a precise opening."},
			]},
			{"id": "follow_the_opening", "label": "Follow the Opening", "gate": 4, "description": "A continued swing corrects toward a nearby enemy it would otherwise miss."},
			{"id": "edge_control", "label": "Edge Control", "gate": 6, "description": "Every sword hit deals exactly +1 damage and +0.5 posture damage."},
			{"id": "long_reach", "label": "Long Reach", "gate": 8, "description": "Your chosen Sword Art gains exactly +20 reach."},
			{"id": "flowing_steel", "label": "Flowing Steel", "gate": 10, "description": "Basic sword recovery and combo transitions become approximately 8% faster."},
		],
	},
	"evasion": {
		"label": "Evasion",
		"description": "Improve the basic Dodge, then commit to a distinct evasive form.",
		"stages": [
			{"id": "practised_footwork", "label": "Practised Footwork", "gate": 2, "description": "Basic Dodge recovery falls from 0.66 to 0.60 seconds and cooldown from 4.0 to 3.6."},
			{"id": "evasion_style", "label": "Evasive Form", "gate": 5, "description": "Permanently specialize your Dodge for this run.", "choices": [
				{"id": "sidestep", "label": "Sidestep", "description": "Cover the practised Dodge distance faster and regain control sooner."},
				{"id": "long_roll", "label": "Long Roll", "description": "Cover 231 units with a longer protected window and dependable recovery."},
			]},
			{"id": "evasion_mastery", "label": "Perfect Form", "gate": 9, "description": "A clean Sidestep primes Counterstep; a clean Long Roll restores 2 seconds of Dodge cooldown."},
		],
	},
	"steadfast": {
		"label": "Steadfast",
		"description": "Temperament: repeatedly choose between Toughness and Vigilance, up to four times.",
		"stages": [
			{"id": "steadfast_1", "label": "Temperament I", "gate": 2, "description": "Choose one permanent Steadfast package.", "choices": [
				{"id": "toughness", "label": "Toughness", "description": "+15 maximum health and +1 Resolve."},
				{"id": "vigilance", "label": "Vigilance", "description": "+10 maximum Stamina and +1 Awareness."},
			]},
			{"id": "steadfast_2", "label": "Temperament II", "gate": 2, "description": "Choose Toughness or Vigilance again.", "choices_ref": "steadfast_1"},
			{"id": "steadfast_3", "label": "Temperament III", "gate": 2, "description": "Choose Toughness or Vigilance again.", "choices_ref": "steadfast_1"},
			{"id": "steadfast_4", "label": "Temperament IV", "gate": 2, "description": "Choose Toughness or Vigilance again.", "choices_ref": "steadfast_1"},
		],
	},
	"warrior": {
		"label": "Warrior",
		"description": "Physical conditioning, sustained weapon pressure, and Rally.",
		"stages": [
			{"id": "warriors_physique", "label": "Warrior's Physique", "gate": 3, "description": "Gain exactly +20 maximum health and +1 Speed."},
			{"id": "building_force", "label": "Building Force", "gate": 5, "description": "Consecutive basic weapon hits gain +0, +1, then +2 damage before the sequence resets."},
			{"id": "rallying_cry", "label": "Rallying Cry", "gate": 7, "description": "Rally lasts 5.5 seconds, grants +1 damage, +2 posture damage, and stronger action poise."},
			{"id": "battle_rhythm", "label": "Battle Rhythm", "gate": 9, "description": "The first posture break during each Rally extends it by exactly 1 second."},
			{"id": "warpath", "label": "Warpath", "gate": 10, "description": "During Rally, Building Force holds at +2 and committed weapon attacks gain strong hyperarmor."},
		],
	},
	"vanguard": {
		"label": "Vanguard",
		"description": "Claim space with Advance, then turn posture breaks into renewed pressure.",
		"stages": [
			{"id": "driving_impact", "label": "Driving Impact", "gate": 4, "description": "Advance rises from 2 to 3 damage, 4 to 6 posture damage, and 32 to 40 push."},
			{"id": "maintain_momentum", "label": "Maintain Momentum", "gate": 5, "description": "Hold the original Advance input through impact to flow directly into your basic weapon sequence."},
			{"id": "vanguard_bearing", "label": "Vanguard Bearing", "gate": 7, "description": "Gain exactly +2 Resolve; committed melee weapon actions gain light hyperarmor."},
			{"id": "seize_the_line", "label": "Seize the Line", "gate": 9, "description": "Breaking any enemy's posture immediately refreshes Advance."},
		],
	},
	"knife": {
		"label": "Knife",
		"description": "Fast compact cuts, a permanent fighting style, and sustained pressure.",
		"stages": [
			{"id": "knife_art", "label": "Knife Art", "gate": 2, "description": "Permanently choose Execution or Twin Fang for this run.", "choices": [
				{"id": "knife_execution", "label": "Execution", "description": "Keep one knife and gain a short step-in cut whose damage is greatly multiplied against an unaware target."},
				{"id": "knife_twin_fang", "label": "Twin Fang", "description": "Equip twin knives, gain a six-cut sequence, and lunge with two simultaneous crossing hits."},
			]},
			{"id": "honed_edges", "label": "Honed Edges", "gate": 4, "description": "Every Knife contact deals exactly +1 health damage."},
			{"id": "light_hands", "label": "Light Hands", "gate": 6, "description": "Knife startup, continuation, and recovery resolve approximately 8% faster."},
			{"id": "relentless_cuts", "label": "Relentless Cuts", "gate": 8, "description": "Uninterrupted contacts build from +1 to +3 damage until the sequence ends or misses."},
			{"id": "ceaseless_cuts", "label": "Ceaseless Cuts", "gate": 10, "description": "Completing all six Twin-Knife cuts reduces sequence recovery from 1 second to 0.55 seconds."},
		],
	},
	"finesse": {
		"label": "Finesse",
		"description": "Temperament: repeatedly choose Fleetness or Subtlety, up to four times.",
		"stages": [
			{"id": "finesse_1", "label": "Temperament I", "gate": 2, "description": "Choose one permanent Finesse package.", "choices": [
				{"id": "fleetness", "label": "Fleetness", "description": "+10 maximum Stamina and +1 Speed."},
				{"id": "subtlety", "label": "Subtlety", "description": "+5 maximum Health and +1 Stealth."},
			]},
			{"id": "finesse_2", "label": "Temperament II", "gate": 2, "description": "Choose Fleetness or Subtlety again.", "choices_ref": "finesse_1"},
			{"id": "finesse_3", "label": "Temperament III", "gate": 2, "description": "Choose Fleetness or Subtlety again.", "choices_ref": "finesse_1"},
			{"id": "finesse_4", "label": "Temperament IV", "gate": 2, "description": "Choose Fleetness or Subtlety again.", "choices_ref": "finesse_1"},
		],
	},
	"rogue": {
		"label": "Rogue",
		"description": "Unaware damage, disciplined training, alarm control, and advanced concealment.",
		"stages": [
			{"id": "ambush", "label": "Ambush", "gate": 3, "description": "Your universal unaware multiplier rises from 1.5× to 2× with every weapon."},
			{"id": "rogue_training", "label": "Rogue's Training", "gate": 5, "description": "Permanently choose Shadow Training or Fleet Training.", "choices": [
				{"id": "shadow_training", "label": "Shadow Training", "description": "+1 Speed and +2 Stealth."},
				{"id": "fleet_training", "label": "Fleet Training", "description": "+2 Speed."},
			]},
			{"id": "clean_work", "label": "Clean Work", "gate": 7, "description": "An unaware victim cannot broadcast an alert until the current attack resolves."},
			{"id": "vanish", "label": "Vanish", "gate": 9, "description": "Stealth may be activated while Engaged; enemies search the last known location."},
			{"id": "ghost", "label": "Ghost", "gate": 10, "description": "A clean assassination after breaking Stealth restores full concealment when unwitnessed."},
		],
	},
	"acrobat": {
		"label": "Acrobat",
		"description": "Refine Vault and turn universal clean evasions into counter-pressure.",
		"stages": [
			{"id": "soft_landing", "label": "Soft Landing", "gate": 4, "description": "Vault landing recovery falls from 0.20 to 0.10 authored seconds."},
			{"id": "elastic_moment", "label": "Elastic Moment", "gate": 6, "description": "Every genuine i-frame window you possess gains approximately 0.06 seconds."},
			{"id": "turnabout", "label": "Turnabout", "gate": 8, "description": "A clean evade empowers the next basic attack within 4 seconds for +8 health and +3 posture damage."},
			{"id": "encore", "label": "Encore", "gate": 10, "description": "Vault cooldown falls from 8 to 4.8 personal-time seconds."},
		],
	},
	"bow": {
		"label": "Bow",
		"description": "Release-scaled shots, a permanent Art, and deliberate follow-up pressure.",
		"stages": [
			{"id": "bow_art", "label": "Bow Art", "gate": 2, "description": "Permanently choose Piercing Shot or Fan Shot for this run.", "choices": [
				{"id": "bow_piercing_shot", "label": "Piercing Shot", "description": "A slow, powerful line shot that passes through every crossed body."},
				{"id": "bow_fan_shot", "label": "Fan Shot", "description": "Release three independent arrows in a compact short-range cone."},
			]},
			{"id": "instinctive_release", "label": "Instinctive Release", "gate": 4, "description": "Loose shots rise from 4 to 6 damage and from roughly 250 to 300 maximum range."},
			{"id": "settled_draw", "label": "Settled Draw", "gate": 6, "description": "Full shots rise from 13 to 16 damage and from 2.5 to 3.25 posture damage."},
			{"id": "quick_nock", "label": "Quick Nock", "gate": 8, "description": "Post-release recovery and a buffered next draw become approximately 20% faster."},
			{"id": "following_arrow", "label": "Following Arrow", "gate": 10, "description": "A Full shot that hits permits one accelerated buffered follow-up draw."},
		],
	},
	"patient": {
		"label": "Patient",
		"description": "Temperament: repeatedly choose Observation or Composure, up to four times.",
		"stages": [
			{"id": "patient_1", "label": "Temperament I", "gate": 2, "description": "Choose one permanent Patient package.", "choices": [
				{"id": "observation", "label": "Observation", "description": "+10 maximum Stamina and +1 Awareness."},
				{"id": "composure", "label": "Composure", "description": "+5 maximum Health and +1 Resolve."},
			]},
			{"id": "patient_2", "label": "Temperament II", "gate": 2, "description": "Choose Observation or Composure again.", "choices_ref": "patient_1"},
			{"id": "patient_3", "label": "Temperament III", "gate": 2, "description": "Choose Observation or Composure again.", "choices_ref": "patient_1"},
			{"id": "patient_4", "label": "Temperament IV", "gate": 2, "description": "Choose Observation or Composure again.", "choices_ref": "patient_1"},
		],
	},
	"sharpshooter": {
		"label": "Sharpshooter",
		"description": "Perception, universal projectile range, and prepared physical attacks.",
		"stages": [
			{"id": "keen_eye", "label": "Keen Eye", "gate": 4, "description": "+2 Awareness and sense approximate enemy blobs beyond line of sight."},
			{"id": "far_sight", "label": "Far Sight", "gate": 6, "description": "+25% unobstructed sight distance and +15% maximum range for every aimed projectile."},
			{"id": "expose_weakness", "label": "Expose Weakness", "gate": 8, "description": "Take Aim grants +10 damage, ignores 6 Defense, and adds +3 posture damage."},
			{"id": "dead_to_rights", "label": "Dead to Rights", "gate": 10, "description": "First Aimed contact deals +50% final physical damage and double posture; a kill refreshes Take Aim."},
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

static func loadout_ids() -> Array[String]:
	return ["warrior", "rogue_acrobat", "rogue_sharpshooter"]

static func track_order_for_loadout(id: String) -> Array[String]:
	var profile := Dictionary(LOADOUT_PROFILES.get(id, LOADOUT_PROFILES["warrior"]))
	var result: Array[String] = []
	for value in Array(profile.get("track_order", LOADOUT_PROFILES["warrior"]["track_order"])):
		result.append(String(value))
	return result

static func loadout_name(id: String) -> String:
	return String(Dictionary(LOADOUT_PROFILES.get(id, LOADOUT_PROFILES["warrior"])).get("name", "Warrior · Vanguard"))

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
