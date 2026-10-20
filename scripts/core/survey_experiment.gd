class_name SurveyExperiment
extends RefCounted

const ID := "sword-frozen-commit"
const VERSION := 1
const ACCEPTED_SOURCE := "060cb8e0a47f1c54e542a9860f44ebda683b94de"
const BEHAVIORS := {
	"A":"Existing combat",
	"B":"Experimental · Paused Sword cuts",
	"C":"Experimental · Paused Sword + Commit",
	"G":"Comparison · Commit + shifted F2 Archer",
	"E":"Comparison · Commit + Briarhook approach boundary",
}
const SCENARIOS := {
	"generated":"Ordinary Survey / chosen custom roster",
	"F1":"Briarhook · authored opening tell",
	"F1-D":"Briarhook · natural approach",
	"F1-P":"Briarhook · injected flank recovery diagnostic",
	"F2":"Mixed camp · exact seats and cover",
	"F3":"Knight · authored cleave",
	"F3-T":"Knight · authored thrust",
	"F3-N":"Knight · natural selection",
	"F3-P":"Knight · injected recovery diagnostic",
	"F3-K":"Kiln Guard · authored protected tell",
	"F3-KP":"Kiln Guard · injected recovery diagnostic",
	"F0":"Expedition seed42 · generated first-biome snapshot",
}

static func defaults() -> Dictionary:
	return {"version":VERSION,"behavior":"A","scenario":"generated","arrival":"full","scouting":false}

static func validate(config: Dictionary) -> bool:
	return int(config.get("version",0)) == VERSION and BEHAVIORS.has(config.get("behavior")) and SCENARIOS.has(config.get("scenario")) and config.get("arrival") in ["full","low","sweep"] and config.get("scouting") is bool and (config["behavior"] != "G" or config["scenario"] == "F2") and (config["scenario"] != "F0" or not config["scouting"]) and (config["scenario"] != "generated" or (config["arrival"] == "full" and not config["scouting"]))

static func identity() -> Dictionary:
	if FileAccess.file_exists("res://build-identity.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://build-identity.json"))
		if parsed is Dictionary: return parsed
	return {"source":"unmanifested development tree","build":"development","version":"development"}

static func install(state) -> void:
	var config: Dictionary = state.survey_experiment
	if config["scenario"] != "generated":
		load("res://scripts/experiments/combat_lab_catalog.gd").configure(state,String(config["behavior"]),String(config["scenario"]),String(config["arrival"]),bool(config["scouting"]))
		state.survey_room_seed = 42
		state.survey_room_definition.merge({"room_number":1,"room_seed":42,"arena":String(config["scenario"]),"recipe_id":"combat_preset","recipe_label":SCENARIOS[config["scenario"]],"reinforcements":[]},true)
		var labels: Array[String] = []
		var roles: Array[String] = []
		var combat = load("res://scripts/core/combat_catalog.gd")
		for enemy in state.enemies:
			labels.append(String(combat.presentation(String(enemy["kind"]))["name"]))
			roles.append(combat.role(String(enemy["kind"])))
		state.survey_room_definition.merge({"enemy_labels":labels,"enemy_roles":roles,"exact_roster":true,"placement_policy":"accepted_preset","formation":String(config["scenario"]),"custom_room":false},true)
	state.survey_session["experiment"] = {"id":ID,"version":VERSION,"accepted_source":ACCEPTED_SOURCE,"config":config.duplicate(true),"behavior":BEHAVIORS[config["behavior"]],"scenario":SCENARIOS[config["scenario"]],"identity":identity(),"next_policy":"same preset retry from report; choose setup to change" if config["scenario"] != "generated" else "ordinary next room / custom repeat policy"}
	state.lab_notice = ""

static func record_entry(state) -> void:
	var lab = load("res://scripts/experiments/combat_lab_catalog.gd")
	var config: Dictionary = state.survey_experiment
	var scenario := String(config["scenario"])
	var provenance := "generated natural room" if scenario == "generated" else "natural setup" if scenario in ["F1-D","F3-N","F0"] or bool(config["scouting"]) else "injected recovery diagnostic" if scenario in ["F1-P","F3-P","F3-KP"] else "authored opening / exact setup"
	if state._custom_room_active(): provenance = "custom exact roster / authored entry resources"
	if config["arrival"] == "low": provenance += "; injected 60% HP / 35% Energy"
	if config["arrival"] == "sweep": provenance += "; earned level-two Swordsmanship transaction"
	var entry: Dictionary = lab.json_safe(lab.manifest(state,scenario,String(config["arrival"]),bool(config["scouting"])))
	# The immutable manifest is captured once per room, before any player input.
	state.survey_room_definition["experiment"] = {"id":ID,"version":VERSION,"scenario_id":scenario,"behavior_id":config["behavior"],"behavior":BEHAVIORS[config["behavior"]],"provenance":provenance,"identity":identity(),"profile":state.survey_profile,"resource_rules":state.combat_rules,"accepted_source":ACCEPTED_SOURCE,"entry":entry}
