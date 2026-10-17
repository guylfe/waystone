class_name ExpeditionCatalog
extends RefCounted

const GENERATION_VERSION := 1
const EQUIPMENT := {
	"reinforced_jack":{"label":"Reinforced Jack", "slot":"torso", "stats":{"defense":2,"speed":-1}, "description":"+2 Defense, -1 Speed"},
	"trailcoat":{"label":"Trailcoat", "slot":"torso", "stats":{"health":15}, "description":"+15 maximum health"},
	"channeler_wrap":{"label":"Channeler Wrap", "slot":"torso", "stats":{"energy":15}, "description":"+15 maximum Energy"},
	"surefoot_boots":{"label":"Surefoot Boots", "slot":"legs", "stats":{}, "description":"35% less incoming displacement", "displacement_scale":0.65},
	"scout_boots":{"label":"Scout Boots", "slot":"legs", "stats":{"awareness":1,"stealth":1}, "description":"+1 Awareness and Stealth"},
	"runner_boots":{"label":"Runner Boots", "slot":"legs", "stats":{"speed":1}, "description":"+1 Speed"},
	"gripping_gloves":{"label":"Gripping Gloves", "slot":"hands", "stats":{"resolve":1}, "description":"+1 Resolve"},
	"fletcher_gloves":{"label":"Fletcher Gloves", "slot":"hands", "stats":{}, "description":"+12% physical-projectile range", "projectile_range_scale":1.12},
	"inscribed_gloves":{"label":"Inscribed Gloves", "slot":"hands", "stats":{"intelligence":1}, "description":"+1 Intelligence"},
}

static func merchant_stock(biome_index: int, loadout: String) -> Array:
	var bodies := ["reinforced_jack","trailcoat","channeler_wrap"]
	var boots := ["surefoot_boots","scout_boots","runner_boots"]
	var glove := "inscribed_gloves" if loadout=="mage_elementalist" else "fletcher_gloves" if loadout=="rogue_sharpshooter" else "gripping_gloves"
	return [{"id":bodies[biome_index],"price":40,"quantity":1}, {"id":boots[biome_index],"price":40,"quantity":1}, {"id":glove,"price":40,"quantity":1}, {"id":"trail_ration","price":12,"quantity":2}, {"id":"throwing_knife","price":12,"quantity":2}, {"id":"firebomb","price":18,"quantity":1}, {"id":"smoke_vial","price":14,"quantity":1}, {"id":"repulsion_pot","price":16,"quantity":1}]

const BIOMES := [
	{"id":"briarwild", "name":"Briarwild Foothills", "color":"71945e", "boss":"thornhart", "landmark":"The Bell in the Clearing", "vista":"The bell citadel crowns the mountain beyond wooded ravines and abandoned charcoal camps.", "core":["boar", "hound", "archer", "briarhook", "thornspitter"], "rotating":["knife", "bandit", "earth_caster"], "xp":[2,4,5,5,6,8], "optional_xp":[2,4], "boss_xp":18, "crowns":12, "optional_crowns":18, "boss_crowns":25},
	{"id":"cinderworks", "name":"Cinderworks", "color":"9c8062", "boss":"kilnmaster", "landmark":"The Forest Below", "vista":"Above-ground quarry terraces and ore lifts climb the mountainside. The foothill forest lies below the furnace smoke.", "core":["shield", "javelineer", "fire_caster", "kiln_guard", "slagthrower"], "rotating":["hound", "bandit", "chanter"], "xp":[6,8,8,8,9,9], "optional_xp":[6,8], "boss_xp":30, "crowns":16, "optional_crowns":24, "boss_crowns":40},
	{"id":"stormglass", "name":"Stormglass Summit", "color":"889da7", "boss":"bell_regent", "landmark":"Above the Smoke", "vista":"Broken bridges and windbreak terraces rise above the treeline. Foundry smoke lies below; the bell citadel is near.", "core":["polearm", "air_caster", "archer", "glasswing", "bellrunner"], "rotating":["shield", "chanter", "duellist"], "xp":[8,10,12,12,14,16], "optional_xp":[10,12], "boss_xp":0, "crowns":20, "optional_crowns":30, "boss_crowns":0},
]

# Tokens are roster positions, not arbitrary replacement permissions. a/b are the
# two selected rotating kinds. Each template owns its interaction and terrain.
const TEMPLATES := [
	[
		["hooked_road", [3,0], "Read the hook, then punish its exposed miss while the boar commits.", "ore_road"],
		["quill_camp", [4,2], "Use charcoal cover to approach a rooted fan without ignoring the archer.", "charcoal_camp"],
		["ravine_hunt", [1,0], "Separate a leaping flanker from a grounded charge at a ravine bend.", "ravine"],
		["hook_and_hound", [3,1], "Avoid being pulled into the hound's approach.", "wooded_slope"],
		["thorn_crossing", [4,1], "Cross a fan lane after its release while tracking a mobile threat.", "ore_road"],
		["split_clearing", [2,1,0], "Choose cover or a wide flank against arrows and two approaches.", "clearing"],
		["briar_pressure", [3,4,1], "Displace the engagement away from the rooted firing lane.", "ravine"],
		["camp_pincer", [3,1,2], "Trade cover access against a hook on the near approach.", "charcoal_camp"],
		["lost_kit", ["a","b"], "Choose whether two unfamiliar guards justify a side discovery.", "side_pocket"],
		["old_watch", ["a","b",0], "Use the outer trail to separate guards from a charging body.", "side_pocket"],
		["thorn_cache", ["a","b",4], "Reach a cache by isolating the rooted defender.", "side_pocket"],
		["hidden_hunt", ["a","b",1], "A mobile guard punishes retreat along the optional spur.", "side_pocket"],
	],
	[
		["hammer_gate", [3,0], "Wait out protected hammer commitment; exploit the vent beside the shield.", "retaining_wall"],
		["slag_quarry", [4,1], "Leave a marked impact without walking into the javelin lane.", "quarry"],
		["furnace_approach", [2,0], "Flank a shield to close on the furnace caster.", "furnace_court"],
		["vent_and_flame", [3,2], "Reserve a safe punish position outside the flame lane.", "furnace_court"],
		["lift_crossing", [2,1], "Use lift machinery as cover against intersecting fire.", "ore_lift"],
		["cooling_yard", [2,0,3], "Draw melee protection away from the caster before committing.", "quarry"],
		["hot_approach", [4,2,0], "Advance between delayed impacts without losing cover from flame.", "retaining_wall"],
		["forge_pressure", [3,2,1], "Choose a venting punish that does not cross either ranged lane.", "ore_lift"],
		["quarry_kit", ["a","b"], "Optional guards demand a fresh approach off the main road.", "side_pocket"],
		["lift_stores", ["a","b",0], "Separate support from a screening body.", "side_pocket"],
		["coolant_cache", ["a","b",3], "Use a protected hammer's recovery to reach the cache.", "side_pocket"],
		["slag_stores", ["a","b",4], "Leave a temporary hazard an open escape route.", "side_pocket"],
	],
	[
		["wing_bridge", [3,0], "Read the fly-through lane, then approach its landing past the polearm.", "ruined_bridge"],
		["first_gong", [4,2], "Stop a visible bellrunner or face its single budgeted reserve.", "bell_terrace"],
		["windbreak", [1,0], "Use the windbreak to approach displacement and reach together.", "windbreak"],
		["wing_and_wind", [3,1], "Choose a landing punish that survives an announced gust.", "exposed_terrace"],
		["high_crossfire", [2,1], "Cross intersecting shots and wind using separate cover routes.", "windbreak"],
		["glass_approach", [1,0,3], "A fly-through disrupts the obvious approach to a reach defender.", "ruined_bridge"],
		["bell_pressure", [4,1], "Decide whether to interrupt the gong or prepare for its finite reserve.", "bell_terrace"],
		["citadel_screen", [0,1,2], "Advance around reach while keeping wind and arrows in view.", "exposed_terrace"],
		["pilgrim_kit", ["a","b"], "Optional guards test the approaches learned below.", "side_pocket"],
		["bell_stores", ["a","b",0], "Separate guards from a reach anchor before claiming supplies.", "side_pocket"],
		["glass_cache", ["a","b",3], "Use the fly-through landing to break an optional formation.", "side_pocket"],
		["wind_cache", ["a","b",1], "Keep a retreat route clear of displacement.", "side_pocket"],
	],
]

static func biome(index: int) -> Dictionary:
	assert(index >= 0 and index < BIOMES.size())
	return BIOMES[index].duplicate(true)

static func select_content(index: int, rng: RandomNumberGenerator) -> Dictionary:
	var region := biome(index)
	var rotations: Array = region["rotating"].duplicate()
	rotations.remove_at(rng.randi_range(0, 2))
	var selected: Array = [0, 1]
	var candidates: Array = [2,3,4,5,6,7]
	while selected.size() < 6:
		var pick := rng.randi_range(0, candidates.size()-1)
		selected.append(candidates.pop_at(pick))
	# Keep pressure templates later than the simpler combinations.
	selected.sort()
	candidates = [8,9,10,11]
	for unused in range(2): selected.append(candidates.pop_at(rng.randi_range(0, candidates.size()-1)))
	var encounters: Array = []
	for template_index in selected:
		var row: Array = TEMPLATES[index][template_index]
		var kinds: Array = []
		for token in row[1]:
			kinds.append(rotations[0 if token == "a" else 1] if token is String else region["core"][token])
		encounters.append({"id":row[0], "kinds":kinds, "interaction":row[2], "terrain":row[3], "permitted_substitutions":{ "a":rotations[0], "b":rotations[1]} if int(template_index)>=8 else {}, "optional":int(template_index)>=8})
	return {"roster":Array(region["core"])+rotations, "encounters":encounters}
