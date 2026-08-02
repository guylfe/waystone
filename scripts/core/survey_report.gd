class_name SurveyReport
extends RefCounted

const ARCHIVE_PATH := "user://combat-survey-archive.json"
const CURRENT_PATH := "user://combat-survey-current.json"
const REPORT_DIRECTORY := "user://combat-survey-reports"
const FORMAT_VERSION := 1

static func save_current(session: Dictionary) -> bool:
	return _write_json(CURRENT_PATH, session)

static func clear_current() -> void:
	if FileAccess.file_exists(CURRENT_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(CURRENT_PATH))

static func archive_session(session: Dictionary) -> Dictionary:
	var archive := load_archive()
	var runs: Array = archive.get("runs", [])
	var stored := session.duplicate(true)
	stored["report_text"] = build_text(session)
	runs.push_front(stored)
	if runs.size() > 100: runs.resize(100)
	archive = {"format_version": FORMAT_VERSION, "runs": runs}
	_write_json(ARCHIVE_PATH, archive)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIRECTORY))
	var internal_path := "%s/%s" % [REPORT_DIRECTORY, report_filename(session)]
	_write_text(internal_path, String(stored["report_text"]))
	clear_current()
	return stored

static func load_archive() -> Dictionary:
	if not FileAccess.file_exists(ARCHIVE_PATH): return {"format_version": FORMAT_VERSION, "runs": []}
	var file := FileAccess.open(ARCHIVE_PATH, FileAccess.READ)
	if file == null: return {"format_version": FORMAT_VERSION, "runs": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {"format_version": FORMAT_VERSION, "runs": []}

static func report_filename(session: Dictionary) -> String:
	var seed := int(session.get("run_seed", 0))
	var started := String(session.get("started_at", "unknown")).replace(":", "-").replace(" ", "_")
	return "Waystone_Combat_Survey_%d_%s.txt" % [seed, started]

static func build_text(session: Dictionary) -> String:
	var rooms: Array = session.get("rooms", [])
	var lines: Array[String] = []
	lines.append("WAYSTONE COMBAT SURVEY")
	lines.append("======================")
	lines.append("Report format: %d" % FORMAT_VERSION)
	lines.append("Game version: %s" % String(session.get("game_version", "unknown")))
	lines.append("Run seed: %d" % int(session.get("run_seed", 0)))
	lines.append("Generator version: %d" % int(session.get("generator_version", 1)))
	lines.append("Profile: %s" % String(session.get("profile", "encounter")).capitalize())
	lines.append("Character: %s" % String(session.get("loadout", "unknown")))
	lines.append("Started: %s" % String(session.get("started_at", "unknown")))
	lines.append("Ended: %s" % String(session.get("ended_at", "unknown")))
	lines.append("End reason: %s" % String(session.get("end_reason", "unknown")))
	lines.append("Rooms reported: %d" % rooms.size())
	lines.append("")
	for room_value in rooms:
		var room := Dictionary(room_value)
		lines.append("ROOM %d" % int(room.get("room_number", 0)))
		lines.append("-------")
		lines.append("Room seed: %d" % int(room.get("room_seed", 0)))
		lines.append("Outcome: %s" % String(room.get("outcome", "unknown")))
		lines.append("Threat tier: %d (%s)" % [int(room.get("threat_tier", 0)), String(room.get("threat_band", "conventional"))])
		lines.append("Arena: %s" % String(room.get("arena", "unknown")))
		lines.append("Formation: %s" % String(room.get("formation", "unknown")))
		lines.append("Enemies: %s" % ", ".join(PackedStringArray(room.get("enemy_labels", []))))
		lines.append("Build: %s" % String(room.get("build_summary", "unknown")))
		lines.append("Combat time: %.2fs" % float(room.get("combat_time", 0.0)))
		lines.append("Damage dealt: %d" % int(room.get("damage_dealt", 0)))
		lines.append("Damage received: %d" % int(room.get("damage_received", 0)))
		lines.append("Hits received: %d" % int(room.get("hits_received", 0)))
		lines.append("Potions used: %d" % int(room.get("potions_used", 0)))
		lines.append("Perfect dodges: %d" % int(room.get("perfect_dodges", 0)))
		lines.append("Blocks: %d" % int(room.get("successful_blocks", 0)))
		lines.append("Endures: %d" % int(room.get("successful_endures", 0)))
		var ratings := Dictionary(room.get("ratings", {}))
		lines.append("Difficulty: %s" % _rating_text(ratings.get("difficulty", 0)))
		lines.append("Fun: %s" % _rating_text(ratings.get("fun", 0)))
		lines.append("Fairness: %s" % _rating_text(ratings.get("fairness", 0)))
		lines.append("Tactical interest: %s" % _rating_text(ratings.get("tactical_interest", 0)))
		lines.append("Want a room like this again: %s" % _rating_text(ratings.get("want_again", ratings.get("expedition_fit", 0))))
		var tags := PackedStringArray(room.get("tags", []))
		lines.append("Tags: %s" % (", ".join(tags) if not tags.is_empty() else "none"))
		var notes := String(room.get("notes", "")).strip_edges()
		lines.append("Notes: %s" % (notes if notes != "" else "none"))
		lines.append("")
	return "\n".join(lines)

static func all_reports_text() -> String:
	var archive := load_archive()
	var sections: Array[String] = []
	for run_value in Array(archive.get("runs", [])):
		var run := Dictionary(run_value)
		sections.append(String(run.get("report_text", build_text(run))))
	return "\n\n\n".join(sections)

static func _rating_text(value: Variant) -> String:
	var rating := int(value)
	return "%d/5" % rating if rating > 0 else "not rated"

static func _write_json(path: String, value: Variant) -> bool:
	return _write_text(path, JSON.stringify(value, "\t"))

static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	return true
