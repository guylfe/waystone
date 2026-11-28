extends RefCounted

const MAIN_SCENE := "res://scenes/main.tscn"
const CAMPAIGN_SCENE := "res://scenes/regional_campaign.tscn"
const REGIONAL := "regional_campaign"
const MODE_SELECT := "mode_select"
const REQUEST := &"waystone_scene_request"
const ENTRY_PATH := "user://waystone-session.cfg"
const Run = preload("res://scripts/core/run_state.gd")
const CampaignSave = preload("res://scripts/campaign/campaign_state.gd")
const CAMPAIGN_STYLES := CampaignSave.COMBAT_STYLES
const CAMPAIGN_SEED := 131137

static func campaign_entry(style: String) -> String:
	return REGIONAL if style == "default" else "%s:%s" % [REGIONAL, style]

static func campaign_style(entry: String) -> String:
	for style in CAMPAIGN_STYLES:
		if entry == campaign_entry(style): return style
	return ""

static func campaign_save_path(style: String) -> String:
	if style == "default": return CampaignSave.SAVE_PATH
	assert(style in CAMPAIGN_STYLES)
	return "user://waystone-regional-campaign-%s.save" % style

static func regular_save_path(mode: String) -> String:
	return "user://waystone-mode-%s.save" % mode

static func launch_entry() -> String:
	var file := ConfigFile.new()
	if file.load(ENTRY_PATH) != OK: return ""
	return String(file.get_value("session", "entry", ""))

static func remember_entry(entry: String) -> void:
	var file := ConfigFile.new()
	file.set_value("session", "entry", entry)
	var pending := ENTRY_PATH + ".pending"
	if file.save(pending) != OK or DirAccess.rename_absolute(pending, ENTRY_PATH) != OK:
		push_warning("Could not remember the last Waystone mode.")

static func request_scene(tree: SceneTree, scene: String, request: Dictionary) -> void:
	if tree.has_meta(REQUEST): return
	tree.set_meta(REQUEST, request)
	if tree.change_scene_to_file(scene) != OK:
		tree.remove_meta(REQUEST)
		push_error("Could not open Waystone scene %s." % scene)

static func take_request(tree: SceneTree) -> Dictionary:
	var request: Dictionary = tree.get_meta(REQUEST, {})
	if tree.has_meta(REQUEST): tree.remove_meta(REQUEST)
	return request

static func has_active_save(path: String, mode: String = "") -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var payload: Variant = file.get_var()
	if not payload is Dictionary: return false
	var saved_mode := Run.ModeRulesScript.normalize(String(payload.get("mode_id", payload.get("progression_mode", "auto"))))
	return bool(payload.get("run_active", true)) and (mode.is_empty() or saved_mode == mode)

static func regular_resume_path(mode: String) -> String:
	var path := regular_save_path(mode)
	if FileAccess.file_exists(path): return path
	if has_active_save(Run.LEGACY_SAVE_PATH, mode): return Run.LEGACY_SAVE_PATH
	return path
