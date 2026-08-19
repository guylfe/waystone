extends SceneTree

# Capture telemetry — the instrument that says whether Milestone C worked.
#
# The design authors one number per attack: `f`, the fraction of the wind-up
# during which walking still saves you. Everything downstream assumes that
# number is honoured, and nothing so far has checked it against play. These
# records make the timing curve measurable rather than asserted: what the player
# did, when they did it as a fraction of startup, and how the attack resolved.
#
# It also answers the question left open when ordinary movement stopped earning
# clean-evade credit — whether Dodge and Vault still raise the event often enough
# for the Acrobat's Turnabout to be worth its rank.

const RunStateScript = preload("res://scripts/core/run_state.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func plan_option(kind: String, technique: String) -> Dictionary:
	for option_value in CombatCatalogScript.melee_attack_plan(kind):
		var option := Dictionary(option_value)
		if String(option["technique"]) == technique: return option
	return {}

func survey_state() -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run("warrior", "combat_survey", 4242, "encounter", "stamina")
	state.enemies.clear()
	state.walls.clear()
	return state

# Drives one attack against a scripted response and returns its record.
func record_for(technique: String, kind: String, response: String, respond_at: float) -> Dictionary:
	var state := survey_state()
	var option := plan_option(kind, technique)
	var enemy := state._make_enemy(kind, state.player_pos + Vector2.RIGHT * float(option["distance"]), 999, 5)
	# Facing and revealed state matter: an enemy that cannot perceive the player is
	# demoted to "suspicious", and _update_enemy_awareness then clears its action
	# every tick, so the attack under test is discarded before it ever runs.
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	enemy["dodge_cooldown"] = 9.0
	enemy["facing"] = Vector2.LEFT
	enemy["action"] = state._intent_melee_action(option, Vector2.LEFT)
	state.enemies.assign([enemy])
	var respond_after := float(option["startup"]) * respond_at
	var responded := response == "none"
	for _step in range(900):
		var action := Dictionary(Dictionary(state.enemies[0])["action"])
		if String(action.get("kind", "")) != "melee" and not state.survey_attack_records.is_empty(): break
		if not responded and float(action.get("elapsed", 0.0)) >= respond_after:
			responded = true
			if response == "move": state.request_move(Vector2.LEFT, state.MOVE_RANGE, false)
			elif response == "dodge": state.request_dodge(Vector2.LEFT, false)
		elif responded and response == "move" and state.is_player_ready():
			state.request_move(Vector2.LEFT, state.MOVE_RANGE, false)
		state._tick(state.SIM_DT)
	if state.survey_attack_records.is_empty(): return {}
	return Dictionary(state.survey_attack_records[0])

# Regression: an attack the player cuts down used to leave no record at all.
# _finalise_capture_record only ran when a melee action reached its own duration,
# and interruption replaces the action wholesale -- so the survey counted only
# attacks the player failed to pre-empt, the population most likely to have
# landed. The 0.2.18 survey reported 11 resolved attacks while its own strike log
# showed at least 20 melee commitments in the same rooms.
func test_interrupted_attacks_still_produce_a_record() -> void:
	var state := survey_state()
	var option := plan_option("blade", "diagonal_cut")
	var enemy := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * float(option["distance"]), 999, 5)
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	enemy["facing"] = Vector2.LEFT
	enemy["action"] = state._intent_melee_action(option, Vector2.LEFT)
	state.enemies.assign([enemy])
	# Let the wind-up start, then cut it down before its damaging window opens.
	for _step in range(6):
		state._tick(state.SIM_DT)
	var live := Dictionary(state.enemies[0])
	var action_before := Dictionary(live.get("action", {}))
	check(String(action_before.get("kind", "")) == "melee", "the attack must still be winding up when interrupted")
	check(float(action_before.get("elapsed", 9.0)) < float(action_before.get("startup", 0.0)),
		"the interruption must land before the damaging window")
	state._apply_enemy_hit_reaction(live, 1.0, "alerted", action_before)
	check(not state.survey_attack_records.is_empty(), "an interrupted attack must still leave a record")
	if state.survey_attack_records.is_empty(): return
	var record := Dictionary(state.survey_attack_records[0])
	check(String(record.get("resolution", "")) == "interrupted",
		"an interrupted attack must resolve as interrupted, got %s" % record.get("resolution", ""))
	check(float(record.get("interrupted_at_f", -1.0)) >= 0.0 and float(record.get("interrupted_at_f", 9.0)) < 1.0,
		"pre-emption must be recorded as a fraction of the wind-up below 1.0")
	var summary := state._survey_capture_summary()
	check(int(summary.get("interrupted", 0)) == 1, "the room summary must count the interruption")
	check(int(summary.get("pre_empted", 0)) == 1, "an attack cut down before its window must count as pre-empted")
	# It must not be mistaken for a walking escape: the response was a strike.
	check(int(summary.get("walk_only_attempts", 0)) == 0, "an interruption is not a walk-only attempt")

func test_every_attack_produces_a_record() -> void:
	var record := record_for("diagonal_cut", "blade", "none", 0.0)
	check(not record.is_empty(), "a resolved attack must leave a record")
	check(String(record.get("enemy", "")) == "blade", "the record must name the attacker")
	check(String(record.get("technique", "")) == "diagonal_cut", "the record must name the technique")
	check(float(record.get("authored_f", -1.0)) > 0.0, "the record must carry the authored walk-safe fraction")
	check(float(record.get("gap", -1.0)) > 0.0, "the record must capture the gap at commitment")

func test_resolution_distinguishes_outcomes() -> void:
	var stood := record_for("diagonal_cut", "blade", "none", 0.0)
	check(String(stood.get("resolution", "")) == "contact", "standing still must record contact, got %s" % stood.get("resolution", ""))
	var early := record_for("diagonal_cut", "blade", "move", 0.0)
	check(String(early.get("resolution", "")) == "miss", "an early walk must record a miss, got %s" % early.get("resolution", ""))
	var dodged := record_for("diagonal_cut", "blade", "dodge", 0.7)
	check(String(dodged.get("resolution", "")) in ["evaded", "miss"],
		"a late Dodge must record an evade or a miss, got %s" % dodged.get("resolution", ""))

func test_f_observed_tracks_when_the_player_responded() -> void:
	# The measurement that separates "walking is overpowered" from "the player read
	# the attack well". Responding later must produce a larger observed fraction.
	var early := record_for("diagonal_cut", "blade", "move", 0.1)
	var late := record_for("diagonal_cut", "blade", "move", 0.8)
	var early_f := float(early.get("f_observed", -1.0))
	var late_f := float(late.get("f_observed", -1.0))
	check(early_f >= 0.0 and late_f >= 0.0, "a committed response must yield an observed fraction")
	check(late_f > early_f, "responding later must raise f_observed, got %.2f then %.2f" % [early_f, late_f])
	check(String(early.get("response", "")) == "move", "the record must name the response taken")

func test_no_response_is_recorded_as_such() -> void:
	var record := record_for("diagonal_cut", "blade", "none", 0.0)
	check(float(record.get("f_observed", 0.0)) < 0.0,
		"a player who never commits must not be scored as an instant reaction")

func test_closest_approach_is_measured() -> void:
	# Tells you by how much an attack missed, which is what tunes `f`. A miss by
	# two units and a miss by ninety are different design problems.
	var contact := record_for("diagonal_cut", "blade", "none", 0.0)
	var escaped := record_for("diagonal_cut", "blade", "move", 0.0)
	check(float(contact.get("closest", 999.0)) <= 0.0, "a landed attack must record overlap")
	check(float(escaped.get("closest", -1.0)) > 0.0, "an escaped attack must record positive clearance")

func test_room_summary_reports_walk_only_escapes() -> void:
	var state := survey_state()
	var option := plan_option("blade", "diagonal_cut")
	for trial in range(3):
		var enemy := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * float(option["distance"]), 999, 5 + trial)
		enemy["awareness"] = "alerted"
		enemy["revealed_to_player"] = true
		enemy["revealed_elapsed"] = 5.0
		enemy["facing"] = Vector2.LEFT
		enemy["action"] = state._intent_melee_action(option, Vector2.LEFT)
		state.enemies.assign([enemy])
		for _step in range(400):
			if String(Dictionary(Dictionary(state.enemies[0])["action"]).get("kind", "")) != "melee": break
			if state.is_player_ready(): state.request_move(Vector2.LEFT, state.MOVE_RANGE, false)
			state._tick(state.SIM_DT)
	var summary := state._survey_capture_summary()
	check(int(summary.get("resolved", 0)) >= 1, "the summary must count resolved attacks, got %d" % int(summary.get("resolved", 0)))
	check(float(summary.get("walk_only_escape_rate", -1.0)) >= 0.0,
		"walking responses must produce a walk-only escape rate")
	check(Array(summary.get("attacks", [])).size() >= 1, "the summary must break down by attack")
	if not Array(summary.get("attacks", [])).is_empty():
		var row := Dictionary(Array(summary["attacks"])[0])
		check(float(row.get("authored_f", 0.0)) > 0.0, "each row must carry authored intent for comparison")

func test_clean_evade_sources_are_counted() -> void:
	# The Acrobat viability check. Ordinary movement no longer earns credit, so if
	# these stay at zero across real play the capstone has quietly died.
	var state := survey_state()
	check(state.clean_evade_dodge_total == 0 and state.clean_evade_vault_total == 0, "counters must start clean")
	state.request_dodge(Vector2.LEFT, false)
	for _step in range(14): state._tick(state.SIM_DT)
	state._resolve_incoming_hit(-1, 2, "blade", state.player_pos + Vector2.RIGHT * 60.0, state.player_pos)
	check(state.clean_evade_dodge_total == 1,
		"a hit crossing Dodge i-frames must count as a Dodge clean evade, got %d" % state.clean_evade_dodge_total)
	check(state.clean_evade_vault_total == 0, "a Dodge evade must not be attributed to Vault")

func _init() -> void:
	test_interrupted_attacks_still_produce_a_record()
	test_every_attack_produces_a_record()
	test_resolution_distinguishes_outcomes()
	test_f_observed_tracks_when_the_player_responded()
	test_no_response_is_recorded_as_such()
	test_closest_approach_is_measured()
	test_room_summary_reports_walk_only_escapes()
	test_clean_evade_sources_are_counted()
	if failures.is_empty():
		print("Capture telemetry tests passed.")
		quit(0)
		return
	for failure in failures:
		printerr("FAILED: %s" % failure)
	printerr("Capture telemetry tests failed: %d" % failures.size())
	quit(1)
