class_name SurveyReport
extends RefCounted

const ARCHIVE_PATH := "user://combat-survey-archive.json"
const CURRENT_PATH := "user://combat-survey-current.json"
const REPORT_DIRECTORY := "user://combat-survey-reports"
const FORMAT_VERSION := 7

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
	lines.append("Presentation version: %d" % int(session.get("presentation_version", 0)))
	lines.append("Profile: %s" % String(session.get("profile", "encounter")).capitalize())
	lines.append("Combat rules: %s" % String(session.get("combat_rules", "stamina")).capitalize())
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
		lines.append("Pacing: %s" % String(room.get("pacing_phase", "unknown")))
		lines.append("Recipe: %s [%s]" % [String(room.get("recipe_label", "Unknown")), String(room.get("recipe_id", "unknown"))])
		lines.append("Recipe family: %s" % String(room.get("recipe_family", "unknown")))
		lines.append("Composition cost: %d" % int(room.get("composition_cost", 0)))
		lines.append("Ranged pressure: %d" % int(room.get("ranged_pressure_count", 0)))
		lines.append("Arena: %s" % String(room.get("arena", "unknown")))
		lines.append("Formation: %s" % String(room.get("formation", "unknown")))
		lines.append("Enemies: %s" % ", ".join(PackedStringArray(room.get("enemy_labels", []))))
		lines.append("Roles: %s" % ", ".join(PackedStringArray(room.get("enemy_roles", []))))
		lines.append("Build: %s" % String(room.get("build_summary", "unknown")))
		lines.append("Health: %d/%d -> %d/%d" % [int(room.get("entry_hp", 0)), int(room.get("entry_max_hp", 0)), int(room.get("exit_hp", 0)), int(room.get("entry_max_hp", 0))])
		lines.append("Stamina: %d/%d -> %d/%d" % [roundi(float(room.get("entry_stamina", 0.0))), roundi(float(room.get("entry_max_stamina", 0.0))), roundi(float(room.get("exit_stamina", 0.0))), roundi(float(room.get("exit_max_stamina", room.get("entry_max_stamina", 0.0))))])
		lines.append("Stamina spent: %.1f" % float(room.get("stamina_spent", 0.0)))
		lines.append("Stamina depleted: %.1f" % float(room.get("stamina_depleted", room.get("stamina_spent", 0.0))))
		lines.append("Stamina overdraw: %.1f" % float(room.get("stamina_overdraw", 0.0)))
		lines.append("Stamina regenerated: %.1f" % float(room.get("stamina_regenerated", 0.0)))
		lines.append("Exhaustion lockouts: %d" % int(room.get("overexertions", 0)))
		lines.append("Exhausted time: %.2fs" % float(room.get("winded_time", 0.0)))
		lines.append("Damage received while exhausted: %d" % int(room.get("exhaustion_damage_received", 0)))
		lines.append("Exhaustion advanced by: movement %.2fs; Wait %.2fs; other %.2fs" % [float(room.get("exhaustion_move_time", 0.0)), float(room.get("exhaustion_wait_time", 0.0)), float(room.get("exhaustion_other_time", 0.0))])
		lines.append("Combo continuations prevented by exhaustion: %d" % int(room.get("stamina_blocked_continuations", 0)))
		lines.append("Potions: %d -> %d" % [int(room.get("entry_potions", 0)), int(room.get("exit_potions", 0))])
		lines.append("Combat time: %.2fs" % float(room.get("combat_time", 0.0)))
		lines.append("Damage dealt: %d" % int(room.get("damage_dealt", 0)))
		lines.append("Damage received: %d" % int(room.get("damage_received", 0)))
		lines.append("Hits received: %d" % int(room.get("hits_received", 0)))
		lines.append("Potions used: %d" % int(room.get("potions_used", 0)))
		lines.append("Perfect dodges: %d" % int(room.get("perfect_dodges", 0)))
		lines.append("Blocks: %d" % int(room.get("successful_blocks", 0)))
		lines.append("Endures: %d" % int(room.get("successful_endures", 0)))
		lines.append("Action usage: %s" % _action_usage_text(Dictionary(room.get("action_usage", {}))))
		var view_modes := PackedStringArray(room.get("view_modes", []))
		lines.append("View: %s" % (" + ".join(view_modes) if not view_modes.is_empty() else "unknown"))
		lines.append("View switches: %d" % int(room.get("view_switches", 0)))
		lines.append("Empty melee contacts: %d" % int(room.get("empty_melee_contacts", 0)))
		var diagnostics: Array = room.get("strike_diagnostics", [])
		lines.append("Strike diagnostics: %d" % diagnostics.size())
		for diagnostic_value in diagnostics:
			lines.append(_strike_diagnostic_text(Dictionary(diagnostic_value)))
		if String(room.get("outcome", "")) == "death": lines.append("Death source: %s" % String(room.get("death_source", "unknown")))
		var ratings := Dictionary(room.get("ratings", {}))
		if bool(room.get("subjective_skipped", false)):
			lines.append("Subjective ratings: skipped / not enough information")
		else:
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

static func _strike_diagnostic_text(value: Dictionary) -> String:
	var result := String(value.get("result", "miss")).to_upper()
	var nearest := String(value.get("closest_enemy", "none nearby"))
	var clearance := float(value.get("closest_clearance", -1.0))
	var clearance_text := "n/a" if clearance < -0.5 else "%+.1f" % clearance
	return "  STRIKE %d  t=%.2fs  %s phase %d [%s]  %s  nearest=%s  forward=%+.1f lateral=%+.1f center=%.1f edge=%.1f clearance=%s reach=%.1f  enemy_action=%s@%.2f  player=(%.1f,%.1f) enemy=(%.1f,%.1f) facing=(%.3f,%.3f) weapon=(%.1f,%.1f)->(%.1f,%.1f)" % [
		int(value.get("index", 0)), float(value.get("room_time", 0.0)), String(value.get("technique", value.get("technique_id", "Attack"))), int(value.get("phase", 1)), String(value.get("view", "unknown")), result, nearest,
		float(value.get("forward", 0.0)), float(value.get("lateral", 0.0)), float(value.get("center_distance", 0.0)), float(value.get("edge_distance", 0.0)), clearance_text, float(value.get("reach", 0.0)),
		String(value.get("enemy_action", "none")), float(value.get("enemy_action_elapsed", 0.0)), float(value.get("player_x", 0.0)), float(value.get("player_y", 0.0)), float(value.get("enemy_x", 0.0)), float(value.get("enemy_y", 0.0)),
		float(value.get("facing_x", 0.0)), float(value.get("facing_y", 0.0)), float(value.get("weapon_start_x", 0.0)), float(value.get("weapon_start_y", 0.0)), float(value.get("weapon_end_x", 0.0)), float(value.get("weapon_end_y", 0.0)),
	]

static func _action_usage_text(usage: Dictionary) -> String:
	if usage.is_empty(): return "none"
	var ids: Array = usage.keys()
	ids.sort()
	var parts: Array[String] = []
	for action_id in ids:
		parts.append("%s x%d" % [String(action_id).replace("_", " "), int(usage[action_id])])
	return ", ".join(parts)

static func _write_json(path: String, value: Variant) -> bool:
	return _write_text(path, JSON.stringify(value, "\t"))

static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	return true
