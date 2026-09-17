class_name ModeRules
extends RefCounted

const EXPEDITION := "expedition"
const CAMPAIGN_LAB := "campaign_lab"
const COMBAT_SURVEY := "combat_survey"
const BOSS_LAB := "boss_lab"

const DEFINITIONS := {
	EXPEDITION: {
		"label": "Expedition",
		"death_policy": "end_run",
		"upgrade_policy": "safe_sheet",
		"waystone_available": false,
		"shadow_enabled": false,
		"geography_policy": "stable",
		"infinite_potions_for_testing": false,
		"measurement_enabled": false,
	},
	CAMPAIGN_LAB: {
		"label": "Campaign Lab",
		"death_policy": "waystone",
		"upgrade_policy": "waystone_sheet",
		"waystone_available": true,
		"shadow_enabled": true,
		"geography_policy": "stable",
		"infinite_potions_for_testing": false,
		"measurement_enabled": false,
	},
	COMBAT_SURVEY: {
		"label": "Combat Survey",
		"death_policy": "survey_end",
		"upgrade_policy": "safe_sheet",
		"waystone_available": false,
		"shadow_enabled": false,
		"geography_policy": "room_sequence",
		"infinite_potions_for_testing": false,
		"measurement_enabled": true,
	},
	BOSS_LAB: {
		"label": "Boss Lab",
		"death_policy": "survey_end",
		"upgrade_policy": "safe_sheet",
		"waystone_available": false,
		"shadow_enabled": false,
		"geography_policy": "room_sequence",
		"infinite_potions_for_testing": false,
		"measurement_enabled": true,
	},
}

static func normalize(value: String) -> String:
	if value == "auto": return EXPEDITION
	if value == "bonfire" or value == "waystone": return CAMPAIGN_LAB
	return value if DEFINITIONS.has(value) else EXPEDITION

static func definition(value: String) -> Dictionary:
	return Dictionary(DEFINITIONS[normalize(value)]).duplicate(true)

static func label(value: String) -> String:
	return String(DEFINITIONS[normalize(value)]["label"])

static func measurement_enabled(value: String) -> bool:
	return bool(DEFINITIONS[normalize(value)].get("measurement_enabled", false))
