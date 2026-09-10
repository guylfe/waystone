class_name SurveyReport
extends RefCounted

const ARCHIVE_PATH := "user://combat-survey-archive.json"
const CURRENT_PATH := "user://combat-survey-current.json"
const REPORT_DIRECTORY := "user://combat-survey-reports"
const FORMAT_VERSION := 31

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
	lines.append("Combat rules: %s" % String(session.get("combat_rules", "energy")).capitalize())
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
		if bool(room.get("custom_room", false)):
			# Tagged rather than filed separately: a conditional estimate does not care how
			# a room came to exist, but these are picked on a hunch and carry a hand-set
			# health, so both confounders are recorded where an analysis can filter on them.
			lines.append("Custom room: yes (entry HP %d%%)" % roundi(100.0 * float(room.get("entry_hp_percent", 1.0))))
		lines.append("Arena: %s" % String(room.get("arena", "unknown")))
		lines.append("Formation: %s" % String(room.get("formation", "unknown")))
		lines.append("Enemies: %s" % ", ".join(PackedStringArray(room.get("enemy_labels", []))))
		lines.append("Roles: %s" % ", ".join(PackedStringArray(room.get("enemy_roles", []))))
		lines.append("Build: %s" % String(room.get("build_summary", "unknown")))
		lines.append("Health: %d/%d -> %d/%d" % [int(room.get("entry_hp", 0)), int(room.get("entry_max_hp", 0)), int(room.get("exit_hp", 0)), int(room.get("entry_max_hp", 0))])
		lines.append("Energy: %d/%d -> %d/%d" % [roundi(float(room.get("entry_energy", 0.0))), roundi(float(room.get("entry_max_energy", 0.0))), roundi(float(room.get("exit_energy", 0.0))), roundi(float(room.get("exit_max_energy", room.get("entry_max_energy", 0.0))))])
		lines.append("Energy spent: %.1f" % float(room.get("energy_spent", 0.0)))
		lines.append("Energy depleted: %.1f" % float(room.get("energy_depleted", room.get("energy_spent", 0.0))))
		lines.append("Energy overdraw: %.1f" % float(room.get("energy_overdraw", 0.0)))
		lines.append("Energy regenerated: %.1f" % float(room.get("energy_regenerated", 0.0)))
		lines.append("Energy regeneration delay: %.2fs" % float(room.get("energy_regen_delay_time", 0.0)))
		lines.append("Active Energy regeneration: %.2fs" % float(room.get("energy_regen_active_time", 0.0)))
		lines.append("Exhaustion lockouts: %d" % int(room.get("overexertions", 0)))
		lines.append("Exhausted time: %.2fs (%.2fs of it with an enemy alerted)" % [
			float(room.get("winded_time", 0.0)), float(room.get("exhaustion_threatened_time_total", 0.0))])
		lines.append("Damage received while exhausted and slowed: %d" % int(room.get("exhaustion_damage_received", 0)))
		lines.append("Desperate Dodges: %d (longest chain %d)" % [int(room.get("exhausted_dodges", 0)), int(room.get("exhausted_dodge_max_chain", 0))])
		var starts := int(room.get("exhaustion_start_samples", 0))
		if starts > 0:
			var pending := int(room.get("exhaustion_start_pending", 0))
			var soonest_text := "n/a" if pending <= 0 else ("%.2fs" % (float(room.get("exhaustion_start_soonest_sum", 0.0)) / float(pending)))
			lines.append("Threat when exhaustion began: mean %.1f alerted (%.1f of them staggered or reacting), mean nearest %.0f; %d of %d with nothing alerted; %d with an attack already committed (soonest %s)" % [
				float(room.get("exhaustion_start_alerted_sum", 0)) / float(starts),
				float(room.get("exhaustion_start_reacting_sum", 0)) / float(starts),
				float(room.get("exhaustion_start_nearest_sum", 0.0)) / float(starts),
				int(room.get("exhaustion_start_clear", 0)), starts, pending, soonest_text])
		var ends := int(room.get("exhaustion_end_samples", 0))
		if ends > 0:
			lines.append("Threat when exhaustion ended: mean %.1f alerted; %d of %d with nothing alerted" % [
				float(room.get("exhaustion_end_alerted_sum", 0)) / float(ends),
				int(room.get("exhaustion_end_clear", 0)), ends])
		lines.append("Unable to afford: a basic attack %.2fs; a full combo %.2fs" % [
			float(room.get("energy_starved_time_total", 0.0)), float(room.get("energy_combo_starved_time_total", 0.0))])
		lines.append("Exhaustion advanced by: movement %.2fs; Wait %.2fs; other %.2fs" % [float(room.get("exhaustion_move_time", 0.0)), float(room.get("exhaustion_wait_time", 0.0)), float(room.get("exhaustion_other_time", 0.0))])
		lines.append("Combo continuations prevented by exhaustion: %d" % int(room.get("energy_blocked_continuations", 0)))
		lines.append("Terminal combo recoveries: %d" % int(room.get("terminal_combo_recoveries", 0)))
		lines.append("Terminal combo recovery time: %.2fs" % float(room.get("terminal_combo_recovery_time", 0.0)))
		lines.append("Direct attack button/key uses: %d" % int(room.get("direct_attack_uses", 0)))
		lines.append("Dodge forms used: %s" % _action_usage_text(Dictionary(room.get("dodge_style_uses", {}))))
		# Only for runs that actually hid. With no Energy-mode cooldown, how fast
		# concealment is re-entered is the whole question about whether hide-execute-hide
		# has eaten the class -- and it was previously unmeasurable.
		if int(room.get("burn_damage", 0)) > 0 or int(room.get("frost_amplified_hits", 0)) > 0:
			lines.append("Elements: %d burn damage; %d hits amplified by frost" % [int(room.get("burn_damage", 0)), int(room.get("frost_amplified_hits", 0))])
		if int(room.get("stray_projectile_hits", 0)) > 0:
			# Friendly fire only happens when something changed after the shot was
			# committed, so this counts whether that ever actually occurs in play.
			lines.append("Shots that struck their own side: %d" % int(room.get("stray_projectile_hits", 0)))
		if int(room.get("javelins_grounded", 0)) > 0:
			# Reported because the whole point of Gale is that it changes where things end up.
			# If this stays at zero in rooms fielding an Air Caster beside a Javelineer, the
			# interaction exists in the code and not in the game.
			lines.append("Javelins torn out of the air: %d" % int(room.get("javelins_grounded", 0)))
		if int(room.get("barriers_raised", 0)) > 0 or int(room.get("barrier_blocks", 0)) > 0:
			# Raised versus actually walked into. A wall reported as invisible while this counts
			# collisions is a rendering fault; collisions of zero means whatever stopped the
			# player was terrain, not a barrier.
			lines.append("Walls raised: %d; times the player was stopped by one: %d" % [int(room.get("barriers_raised", 0)), int(room.get("barrier_blocks", 0))])
		if int(room.get("blind_collisions", 0)) > 0:
			lines.append("Stopped by a body the player could not see: %d" % int(room.get("blind_collisions", 0)))
		if int(room.get("stealth_entries", 0)) > 0:
			lines.append("Stealth: %d entries (%d cancelled, %d re-entered within 3s); %.2fs hidden; %.0f energy paid" % [
				int(room.get("stealth_entries", 0)), int(room.get("stealth_cancels", 0)),
				int(room.get("stealth_quick_reentries", 0)), float(room.get("stealth_hidden_time", 0.0)),
				float(room.get("stealth_energy_paid", 0.0))])
		if int(room.get("rally_activations", 0)) > 0:
			lines.append("Rally: %d activations (%d cancelled); %.2fs active; %.1f energy paid (%.1f saved); +%d damage and +%.1f posture dealt" % [
				int(room.get("rally_activations", 0)), int(room.get("rally_cancels", 0)),
				float(room.get("rally_uptime", 0.0)), float(room.get("rally_energy_paid", 0.0)),
				float(room.get("rally_energy_saved", 0.0)), int(room.get("rally_bonus_damage", 0)),
				float(room.get("rally_bonus_posture", 0.0))])
		if int(room.get("poise_holds", 0)) > 0 or int(room.get("power_through_triggers", 0)) > 0 or int(room.get("unbreakable_suppressions", 0)) > 0:
			lines.append("Warrior holds: poise %d; Power Through %d (%d damage prevented); Unbreakable %d" % [
				int(room.get("poise_holds", 0)), int(room.get("power_through_triggers", 0)),
				int(room.get("power_through_damage_prevented", 0)), int(room.get("unbreakable_suppressions", 0))])
		lines.append("Vulnerable Dodge recovery: %.2fs; damage received: %d" % [float(room.get("dodge_vulnerable_time", 0.0)), int(room.get("dodge_recovery_damage", 0))])
		lines.append("Potions: %d -> %d" % [int(room.get("entry_potions", 0)), int(room.get("exit_potions", 0))])
		lines.append("Combat time: %.2fs" % float(room.get("combat_time", 0.0)))
		lines.append("Damage dealt: %d" % int(room.get("damage_dealt", 0)))
		lines.append("Damage received: %d" % int(room.get("damage_received", 0)))
		lines.append("Hits received: %d" % int(room.get("hits_received", 0)))
		lines.append("Interruptions prevented: %d; damage taken under post-hit protection: %d" % [int(room.get("interruptions_prevented", 0)), int(room.get("protected_damage", 0))])
		lines.append("Clean evades: %d by Dodge, %d by Vault; Turnabout primed %d, consumed %d" % [
			int(room.get("clean_evade_dodge", 0)), int(room.get("clean_evade_vault", 0)),
			int(room.get("turnabout_primed", 0)), int(room.get("turnabout_consumed", 0))])
		var capture := Dictionary(room.get("capture", {}))
		if int(capture.get("resolved", 0)) > 0:
			var escape_rate := float(capture.get("walk_only_escape_rate", -1.0))
			var escape_text := "n/a" if escape_rate < 0.0 else ("%.0f%% (%d of %d)" % [escape_rate * 100.0, int(capture.get("walk_only_escapes", 0)), int(capture.get("walk_only_attempts", 0))])
			lines.append("Hostile attacks resolved: %d; walk-only escape rate: %s" % [int(capture.get("resolved", 0)), escape_text])
			lines.append("Attacks interrupted before resolving: %d (%d cut down before the damaging window)" % [int(capture.get("interrupted", 0)), int(capture.get("pre_empted", 0))])
			lines.append("Capture per attack (authored f versus observed, mean closest approach):")
			for row_value in Array(capture.get("attacks", [])):
				var row := Dictionary(row_value)
				var observed := float(row.get("observed_f", -1.0))
				var observed_text := "no response" if observed < 0.0 else ("%.2f" % observed)
				# An interrupted attack has no damaging window, so it contributes no
				# closest approach. Reporting one would be inventing a measurement.
				var closest_text := "n/a" if int(row.get("closest_samples", 0)) <= 0 else ("%.1f" % float(row.get("closest", 0.0)))
				lines.append("  %s x%d — contact %d, evaded %d, missed %d, interrupted %d; f authored %.2f, observed %s; closest %s" % [
					String(row.get("attack", "?")), int(row.get("n", 0)),
					int(row.get("contact", 0)), int(row.get("evaded", 0)), int(row.get("miss", 0)), int(row.get("interrupted", 0)),
					float(row.get("authored_f", 0.0)), observed_text, closest_text])
		lines.append("Potions used: %d" % int(room.get("potions_used", 0)))
		lines.append("Perfect dodges: %d" % int(room.get("perfect_dodges", 0)))
		lines.append("Blocks: %d" % int(room.get("successful_blocks", 0)))
		lines.append("Endures: %d" % int(room.get("successful_endures", 0)))
		lines.append("Action usage: %s" % _action_usage_text(Dictionary(room.get("action_usage", {}))))
		lines.append("Spell usage: %s" % _action_usage_text(Dictionary(room.get("spell_usage", {}))))
		var crowding_samples := int(room.get("crowding_samples", 0))
		if crowding_samples > 0:
			lines.append("Enemy spacing: mean nearest ally %.1f; %.0f%% of combat inside comfort distance" % [
				float(room.get("crowding_nearest_sum", 0.0)) / float(crowding_samples),
				100.0 * float(room.get("crowding_close_samples", 0)) / float(crowding_samples),
			])
		lines.append("Misdirected same-side hits: %d" % int(room.get("misdirected_ally_hits", 0)))
		var charge_traffic: Array = room.get("charge_traffic_events", [])
		if not charge_traffic.is_empty():
			var vaults := 0
			var shoves := 0
			var ally_crashes := 0
			var geometry_crashes := 0
			for event_value in charge_traffic:
				var interaction := String(Dictionary(event_value).get("interaction", ""))
				if interaction == "vaulted": vaults += 1
				elif interaction == "shoved": shoves += 1
				elif String(Dictionary(event_value).get("cause", "")) == "ally_body": ally_crashes += 1
				elif interaction == "crashed": geometry_crashes += 1
			lines.append("Charge traffic: %d allies vaulted; %d shoved; %d ally-body crashes; %d geometry crashes" % [vaults, shoves, ally_crashes, geometry_crashes])
			for event_value in charge_traffic:
				var event := Dictionary(event_value)
				var charger := "%s#%d" % [String(event.get("charger_kind", "enemy")), int(event.get("charger_id", -1))]
				var interaction := String(event.get("interaction", "event"))
				if event.has("ally_id"):
					lines.append("  %s %s %s#%d (mass %.2f)" % [charger, interaction, String(event.get("ally_kind", "enemy")), int(event.get("ally_id", -1)), float(event.get("ally_mass", 0.0))])
				else:
					lines.append("  %s %s: %s" % [charger, interaction, String(event.get("cause", "unknown")).replace("_", " ")])
		var interruption_events: Array = room.get("interruption_events", [])
		if not interruption_events.is_empty():
			lines.append("Hostile commitments interrupted: %d" % interruption_events.size())
			for event_value in interruption_events:
				var event := Dictionary(event_value)
				lines.append("  %s %s by %s using %s" % [String(event.get("enemy_kind", "enemy")), String(event.get("interrupted_action", "action")), String(event.get("interrupter", "unknown")), String(event.get("tool", "unknown"))])
		var view_modes := PackedStringArray(room.get("view_modes", []))
		lines.append("View: %s" % (" + ".join(view_modes) if not view_modes.is_empty() else "unknown"))
		lines.append("View switches: %d" % int(room.get("view_switches", 0)))
		lines.append("Empty melee contacts: %d" % int(room.get("empty_melee_contacts", 0)))
		# Which arrangements built the room, so the archive can compare formations the
		# way it compared non-melee counts -- and how long each ranged body lasted before
		# the player was standing on top of it, which is the difference between a threat
		# and a speed bump.
		var reach_entries := Array(room.get("reach_times", []))
		if not reach_entries.is_empty():
			var reach_text: Array[String] = []
			for entry_value in reach_entries:
				var entry := Dictionary(entry_value)
				reach_text.append("%s %.1fs" % [String(entry.get("kind", "?")).replace("_", " "), float(entry.get("at", 0.0))])
			lines.append("Time to reach ranged: %s" % ", ".join(reach_text))
		else:
			lines.append("Time to reach ranged: none reached")
		# A bow run used to produce no attack record of any kind, because the strike log is
		# a melee sector and a projectile has none.
		if int(room.get("shots_fired", 0)) > 0:
			lines.append("Shots: %d fired, %d hit, %d stopped by a guard" % [int(room.get("shots_fired", 0)), int(room.get("shots_hit", 0)), int(room.get("shots_blocked", 0))])
		# Is this a room, or a queue of duels? Four separate 0.2.37 notes said the enemies
		# were fought one at a time; nothing in the report could confirm it.
		var engagement_samples := int(room.get("engagement_samples", 0))
		if engagement_samples > 0:
			var mean_engaged := float(room.get("engagement_alerted_sum", 0)) / float(engagement_samples)
			var multi_share := 100.0 * float(room.get("engagement_multi_samples", 0)) / float(engagement_samples)
			lines.append("Enemies engaged at once: mean %.2f; %.0f%% of combat with two or more" % [mean_engaged, multi_share])
		var isolated := int(room.get("isolated_kills", 0))
		var engaged := int(room.get("engaged_kills", 0))
		if isolated + engaged > 0:
			lines.append("Kills made alone: %d of %d" % [isolated, isolated + engaged])
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
	var raw_result := String(value.get("result", "miss"))
	var result := "TRUE MISS" if raw_result == "miss" else raw_result.to_upper()
	var nearest := String(value.get("closest_enemy", "none nearby"))
	var targets := PackedStringArray(value.get("targets", []))
	var target_text := ",".join(targets) if not targets.is_empty() else "none"
	var clearance := float(value.get("closest_clearance", -1.0))
	var clearance_text := "n/a" if nearest == "none nearby" else "%+.1f" % clearance
	var shape := String(value.get("shape", "unknown"))
	var dimensions := "inner=%.1f outer=%.1f arc=%.1fdeg" % [float(value.get("inner_radius", 0.0)), float(value.get("outer_radius", 0.0)), float(value.get("arc_degrees", 0.0))] if shape == "sector" else "length=%.1f radius=%.1f" % [float(value.get("footprint_length", 0.0)), float(value.get("footprint_radius", 0.0))]
	return "  STRIKE %d  t=%.2fs  %s phase %d [%s]  %s targets=%s  footprint=%s(%s) nearest=%s  forward=%+.1f lateral=%+.1f center=%.1f edge=%.1f clearance=%s overlap=%s occluded=%s collision_failure=%s  enemy_action=%s@%.2f  player=(%.1f,%.1f) enemy=(%.1f,%.1f) facing=(%.3f,%.3f) weapon=(%.1f,%.1f)->(%.1f,%.1f)" % [
		int(value.get("index", 0)), float(value.get("room_time", 0.0)), String(value.get("technique", value.get("technique_id", "Attack"))), int(value.get("phase", 1)), String(value.get("view", "unknown")), result, target_text, shape, dimensions, nearest,
		float(value.get("forward", 0.0)), float(value.get("lateral", 0.0)), float(value.get("center_distance", 0.0)), float(value.get("edge_distance", 0.0)), clearance_text, str(bool(value.get("geometry_overlap", false))), str(bool(value.get("occluded", false))), str(bool(value.get("visual_overlap_collision_failure", false))),
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
