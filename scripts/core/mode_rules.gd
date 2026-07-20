class_name ModeRules
extends RefCounted

const EXPEDITION := "expedition"
const CAMPAIGN_LAB := "campaign_lab"

const DEFINITIONS := {
	EXPEDITION: {
		"label": "Expedition",
		"death_policy": "end_run",
		"upgrade_policy": "area_exit",
		"waystone_available": false,
		"shadow_enabled": false,
		"geography_policy": "stable",
		"infinite_potions_for_testing": true,
	},
	CAMPAIGN_LAB: {
		"label": "Campaign Lab",
		"death_policy": "waystone",
		"upgrade_policy": "waystone",
		"waystone_available": true,
		"shadow_enabled": true,
		"geography_policy": "stable",
		"infinite_potions_for_testing": false,
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
