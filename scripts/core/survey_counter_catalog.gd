class_name SurveyCounterCatalog
extends RefCounted

# One declaration owns baseline capture, room differencing, scope and report shape.
# Report prose may group these values, but no counter needs plumbing in several places.
const DESCRIPTORS := [
	{"key":"damage_dealt", "source":"damage_dealt", "policy":"delta", "format":"integer"},
	{"key":"stray_projectile_hits", "source":"survey_stray_projectile_hits", "policy":"delta", "format":"integer"},
	{"key":"javelins_grounded", "source":"survey_javelins_grounded", "policy":"delta", "format":"integer"},
	{"key":"barriers_raised", "source":"survey_barriers_raised", "policy":"delta", "format":"integer"},
	{"key":"barrier_blocks", "source":"survey_barrier_blocks", "policy":"delta", "format":"integer"},
	{"key":"blind_collisions", "source":"survey_blind_collisions", "policy":"delta", "format":"integer"},
	{"key":"burn_damage", "source":"survey_burn_damage_total", "policy":"delta", "format":"integer"},
	{"key":"frost_amplified_hits", "source":"survey_frost_amplified_hits", "policy":"delta", "format":"integer"},
	{"key":"damage_received", "source":"damage_received_total", "policy":"delta", "format":"integer"},
	{"key":"hits_received", "source":"hits_received_total", "policy":"delta", "format":"integer"},
	{"key":"protected_damage", "source":"protected_damage_total", "policy":"delta", "format":"integer"},
	{"key":"interruptions_prevented", "source":"interruptions_prevented_total", "policy":"delta", "format":"integer"},
	{"key":"clean_evade_dodge", "source":"clean_evade_dodge_total", "policy":"delta", "format":"integer"},
	{"key":"clean_evade_vault", "source":"clean_evade_vault_total", "policy":"delta", "format":"integer"},
	{"key":"turnabout_primed", "source":"turnabout_primed_total", "policy":"delta", "format":"integer"},
	{"key":"turnabout_consumed", "source":"turnabout_consumed_total", "policy":"delta", "format":"integer"},
	{"key":"potions_used", "source":"potions_used_total", "policy":"delta", "format":"integer"},
	{"key":"perfect_dodges", "source":"perfect_dodges", "policy":"delta", "format":"integer"},
	{"key":"successful_blocks", "source":"successful_blocks", "policy":"delta", "format":"integer"},
	{"key":"successful_endures", "source":"successful_endures", "policy":"delta", "format":"integer"},
	{"key":"action_usage", "source":"survey_action_counts", "baseline_key":"action_counts", "policy":"dictionary_delta", "format":"counts"},
	{"key":"spell_usage", "source":"survey_spell_counts", "baseline_key":"spell_counts", "policy":"dictionary_delta", "format":"counts"},
	{"key":"view_switches", "source":"survey_view_switches", "policy":"delta", "format":"integer"},
	{"key":"empty_melee_contacts", "source":"survey_empty_melee_contacts", "policy":"delta", "format":"integer"},
	{"key":"engagement_samples", "source":"survey_engagement_samples", "policy":"delta", "format":"integer"},
	{"key":"engagement_alerted_sum", "source":"survey_engagement_alerted_sum", "policy":"delta", "format":"integer"},
	{"key":"engagement_multi_samples", "source":"survey_engagement_multi_samples", "policy":"delta", "format":"integer"},
	{"key":"crowding_samples", "source":"survey_crowding_samples", "policy":"delta", "format":"integer"},
	{"key":"crowding_nearest_sum", "source":"survey_crowding_nearest_sum", "policy":"delta", "format":"decimal"},
	{"key":"crowding_close_samples", "source":"survey_crowding_close_samples", "policy":"delta", "format":"integer"},
	{"key":"misdirected_ally_hits", "source":"survey_misdirected_ally_hits", "policy":"delta", "format":"integer"},
	{"key":"interruption_events", "source":"survey_interruption_events", "baseline_key":"interruption_event_count", "policy":"array_slice", "format":"records"},
	{"key":"isolated_kills", "source":"survey_isolated_kills", "policy":"delta", "format":"integer"},
	{"key":"engaged_kills", "source":"survey_engaged_kills", "policy":"delta", "format":"integer"},
	{"key":"energy_spent", "source":"energy_spent_total", "policy":"delta", "format":"decimal"},
	{"key":"energy_depleted", "source":"energy_depleted_total", "policy":"delta", "format":"decimal"},
	{"key":"energy_overdraw", "source":"energy_overdraw_total", "policy":"delta", "format":"decimal"},
	{"key":"energy_regenerated", "source":"energy_regenerated_total", "policy":"delta", "format":"decimal"},
	{"key":"energy_regen_delay_time", "source":"energy_regen_delay_time_total", "policy":"delta", "format":"seconds"},
	{"key":"energy_regen_active_time", "source":"energy_regen_active_time_total", "policy":"delta", "format":"seconds"},
	{"key":"overexertions", "source":"overexertion_count", "policy":"delta", "format":"integer"},
	{"key":"winded_time", "source":"winded_time_total", "policy":"delta", "format":"seconds"},
	{"key":"energy_blocked_continuations", "source":"energy_blocked_continuations", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_damage_received", "source":"exhaustion_damage_received_total", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_move_time", "source":"exhaustion_move_time_total", "policy":"delta", "format":"seconds"},
	{"key":"exhaustion_wait_time", "source":"exhaustion_wait_time_total", "policy":"delta", "format":"seconds"},
	{"key":"exhaustion_other_time", "source":"exhaustion_other_time_total", "policy":"delta", "format":"seconds"},
	{"key":"exhausted_dodges", "source":"exhausted_dodge_total", "policy":"delta", "format":"integer"},
	{"key":"exhausted_dodge_max_chain", "source":"exhausted_dodge_room_max_chain", "policy":"room", "format":"integer"},
	{"key":"exhaustion_start_samples", "source":"exhaustion_start_samples", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_start_alerted_sum", "source":"exhaustion_start_alerted_sum", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_start_clear", "source":"exhaustion_start_clear", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_start_pending", "source":"exhaustion_start_pending", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_start_reacting_sum", "source":"exhaustion_start_reacting_sum", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_end_samples", "source":"exhaustion_end_samples", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_end_alerted_sum", "source":"exhaustion_end_alerted_sum", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_end_clear", "source":"exhaustion_end_clear", "policy":"delta", "format":"integer"},
	{"key":"exhaustion_start_soonest_sum", "source":"exhaustion_start_soonest_sum", "policy":"delta", "format":"decimal"},
	{"key":"exhaustion_start_nearest_sum", "source":"exhaustion_start_nearest_sum", "policy":"delta", "format":"decimal"},
	{"key":"energy_starved_time_total", "source":"energy_starved_time_total", "policy":"delta", "format":"seconds"},
	{"key":"energy_combo_starved_time_total", "source":"energy_combo_starved_time_total", "policy":"delta", "format":"seconds"},
	{"key":"exhaustion_threatened_time_total", "source":"exhaustion_threatened_time_total", "policy":"delta", "format":"seconds"},
	{"key":"terminal_combo_recoveries", "source":"terminal_combo_recoveries_total", "policy":"delta", "format":"integer"},
	{"key":"stealth_entries", "source":"survey_stealth_entries_total", "policy":"delta", "format":"integer"},
	{"key":"stealth_cancels", "source":"survey_stealth_cancels_total", "policy":"delta", "format":"integer"},
	{"key":"stealth_quick_reentries", "source":"survey_stealth_quick_reentries_total", "policy":"delta", "format":"integer"},
	{"key":"stealth_hidden_time", "source":"survey_stealth_hidden_time_total", "policy":"delta", "format":"seconds"},
	{"key":"stealth_energy_paid", "source":"survey_stealth_energy_paid_total", "policy":"delta", "format":"decimal"},
	{"key":"terminal_combo_recovery_time", "source":"terminal_combo_recovery_time_total", "policy":"delta", "format":"seconds"},
	{"key":"direct_attack_uses", "source":"direct_attack_uses_total", "policy":"delta", "format":"integer"},
	{"key":"dodge_style_uses", "source":"dodge_style_uses_total", "policy":"dictionary_delta", "format":"counts"},
	{"key":"dodge_vulnerable_time", "source":"dodge_vulnerable_time_total", "policy":"delta", "format":"seconds"},
	{"key":"dodge_recovery_damage", "source":"dodge_recovery_damage_total", "policy":"delta", "format":"integer"},
	{"key":"shots_fired", "source":"survey_shots_fired", "policy":"room", "format":"integer"},
	{"key":"shots_hit", "source":"survey_shots_hit", "policy":"room", "format":"integer"},
	{"key":"shots_blocked", "source":"survey_shots_blocked", "policy":"room", "format":"integer"},
	{"key":"reach_times", "source":"survey_reach_times", "policy":"room", "format":"records"},
	{"key":"strike_diagnostics", "source":"survey_strike_diagnostics", "baseline_key":"strike_diagnostic_count", "policy":"array_slice", "format":"records"},
]

static func capture(state: Object) -> Dictionary:
	var result := {}
	for descriptor in DESCRIPTORS:
		var definition := Dictionary(descriptor)
		if String(definition["policy"]) == "room": continue
		var key := String(definition.get("baseline_key", definition["key"]))
		var value: Variant = state.get(String(definition["source"]))
		if String(definition["policy"]) == "array_slice": value = Array(value).size()
		elif value is Dictionary or value is Array: value = value.duplicate(true)
		result[key] = value
	return result

static func room_values(state: Object, baseline: Dictionary) -> Dictionary:
	var result := {}
	for descriptor in DESCRIPTORS:
		var definition := Dictionary(descriptor)
		var key := String(definition["key"])
		var source := String(definition["source"])
		var policy := String(definition["policy"])
		var current: Variant = state.get(source)
		var baseline_key := String(definition.get("baseline_key", key))
		match policy:
			"delta": result[key] = current - baseline.get(baseline_key, current)
			"dictionary_delta": result[key] = _dictionary_delta(Dictionary(current), Dictionary(baseline.get(baseline_key, {})))
			"array_slice": result[key] = Array(current).slice(int(baseline.get(baseline_key, 0))).duplicate(true)
			"room": result[key] = current.duplicate(true) if current is Array or current is Dictionary else current
	return result

static func _dictionary_delta(current: Dictionary, baseline: Dictionary) -> Dictionary:
	var result := {}
	for key in current:
		var difference := int(current[key]) - int(baseline.get(key, 0))
		if difference > 0: result[key] = difference
	return result

static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var keys := {}
	for descriptor in DESCRIPTORS:
		var definition := Dictionary(descriptor)
		for required in ["key", "source", "policy", "format"]:
			if not definition.has(required): errors.append("Survey counter descriptor is missing %s" % required)
		var key := String(definition.get("key", ""))
		if keys.has(key): errors.append("Duplicate survey counter: %s" % key)
		keys[key] = true
		if String(definition.get("policy", "")) not in ["delta", "dictionary_delta", "array_slice", "room"]:
			errors.append("Unknown survey counter policy for %s" % key)
	return errors
