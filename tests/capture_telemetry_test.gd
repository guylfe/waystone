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

# Charges were invisible to capture entirely: MELEE_ATTACK_PLANS covers eight
# kinds and neither Boar nor Hound is among them, so the two most common melee
# enemies left no records at all across three surveys. Their travel sits inside
# the damaging window rather than the wind-up, which is why Milestone C skipped
# them -- but the Boar's stationary 0.52s telegraph handed a walking player 135
# free units, so walking beat it from every launch distance.
func charge_record(kind: String, respond_at: float, gap: float) -> Dictionary:
	var state := survey_state()
	var enemy := state._make_enemy(kind, state.player_pos + Vector2.RIGHT * gap, 999, 5)
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	enemy["facing"] = Vector2.LEFT
	enemy["pounce_cooldown"] = 0.0
	state.enemies.assign([enemy])
	var responded := false
	var startup := -1.0
	for _step in range(1200):
		var action := Dictionary(Dictionary(state.enemies[0])["action"])
		if String(action.get("kind", "")) == "charge":
			if startup < 0.0: startup = float(action.get("startup", 0.4))
			if not responded and float(action.get("elapsed", 0.0)) >= startup * respond_at: responded = true
		if responded and state.is_player_ready():
			state.request_move(Vector2.LEFT, state.MOVE_RANGE, false)
		if not state.survey_attack_records.is_empty(): break
		state._tick(state.SIM_DT)
	return {} if state.survey_attack_records.is_empty() else Dictionary(state.survey_attack_records[0])

func test_charges_produce_capture_records() -> void:
	for kind in ["boar", "hound"]:
		var record := charge_record(kind, 0.0, 150.0)
		check(not record.is_empty(), "%s charges must leave a capture record" % kind)
		if record.is_empty(): continue
		check(float(record.get("authored_f", -1.0)) > 0.0, "%s must carry an authored walk-safe fraction" % kind)
		check(float(record.get("closest", 9999.0)) < 9000.0, "%s must measure a closest approach" % kind)

func charge_outcome(kind: String, respond_at: float, gap: float, axis: Vector2) -> String:
	var state := survey_state()
	var enemy := state._make_enemy(kind, state.player_pos + Vector2.RIGHT * gap, 999, 5)
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	enemy["facing"] = Vector2.LEFT
	enemy["pounce_cooldown"] = 0.0
	state.enemies.assign([enemy])
	var responded := false
	var startup := -1.0
	for _step in range(2000):
		var action := Dictionary(Dictionary(state.enemies[0])["action"])
		if String(action.get("kind", "")) == "charge":
			if startup < 0.0: startup = float(action.get("startup", 0.3))
			if not responded and float(action.get("elapsed", 0.0)) >= startup * respond_at: responded = true
		if responded and state.is_player_ready(): state.request_move(axis, state.MOVE_RANGE, false)
		if not state.survey_attack_records.is_empty(): break
		state._tick(state.SIM_DT)
	if state.survey_attack_records.is_empty(): return "none"
	return String(Dictionary(state.survey_attack_records[0]).get("resolution", "?"))

# A charge that starts and finishes inside one player commitment is not a decision,
# it is a dice roll on when it fired. A single strike locks control for 0.983s and a
# basic attack for 0.800s -- not the 0.44s between combo strikes, which is what the
# wind-ups were mistakenly sized against and what shipped a Boar that hit you
# mid-swing with nothing to be done about it.
func charge_outcome_while_committed(kind: String, gap: float, axis: Vector2) -> String:
	var state := survey_state()
	var enemy := state._make_enemy(kind, state.player_pos + Vector2.RIGHT * gap, 9999, 5)
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	enemy["facing"] = Vector2.LEFT
	enemy["pounce_cooldown"] = 0.0
	state.enemies.assign([enemy])
	var committed := false
	for _step in range(4000):
		var action := Dictionary(Dictionary(state.enemies[0])["action"])
		if String(action.get("kind", "")) == "charge" and not committed:
			# Commit the instant the charge does: the worst case, and the one that used
			# to resolve entirely before control came back.
			committed = true
			state.request_attack(state.player_pos + Vector2.RIGHT * 300.0, false)
		if committed and state.is_player_ready(): state.request_move(axis, state.MOVE_RANGE, false)
		if not state.survey_attack_records.is_empty(): break
		state._tick(state.SIM_DT)
	if state.survey_attack_records.is_empty(): return "none"
	return String(Dictionary(state.survey_attack_records[0]).get("resolution", "?"))

# The Ox asks a lateral question where every other attack asks a radial one: not
# "am I close enough" but "am I on its line". It commits from any distance with a
# clear line and runs until it hits the player, a wall, or its cap, so there is no
# safe range -- only a safe bearing. Its width is derived, not chosen: the aim locks
# at 0.765s and the charge arrives at 1.14s from the nearest interesting range,
# leaving 0.375s in which walking covers 97 units and a Dodge about 131. The contact
# radius sits between them at 115, which is what makes the evasive action the answer
# rather than an alternative to footwork.
func ox_outcome(gap: float, axis: Vector2, dodge: bool, respond_at: float) -> String:
	var state := survey_state()
	var enemy := state._make_enemy("ox", state.player_pos + Vector2.RIGHT * gap, 9999, 5)
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	enemy["facing"] = Vector2.LEFT
	enemy["pounce_cooldown"] = 0.0
	state.enemies.assign([enemy])
	var responded := false
	var startup := -1.0
	for _step in range(6000):
		var action := Dictionary(Dictionary(state.enemies[0])["action"])
		if String(action.get("kind", "")) == "charge":
			if startup < 0.0: startup = float(action.get("startup", 0.85))
			if not responded and float(action.get("elapsed", 0.0)) >= startup * respond_at: responded = true
		if responded and state.is_player_ready():
			if dodge: state.request_dodge(axis, false)
			else: state.request_move(axis, state.MOVE_RANGE, false)
		if not state.survey_attack_records.is_empty(): break
		state._tick(state.SIM_DT)
	if state.survey_attack_records.is_empty(): return "none"
	return String(Dictionary(state.survey_attack_records[0]).get("resolution", "?"))

func test_the_ox_cannot_be_outrun_only_evaded() -> void:
	# Retreating along the line fails at every timing: the run is longer than any
	# backpedal. Getting off the line is the only answer, and the Dodge is the one
	# that clears with margin.
	for respond_at in [0.0, 0.5, 1.0]:
		check(ox_outcome(150.0, Vector2.LEFT, false, respond_at) == "contact",
			"retreating along an Ox charge at %.1f must fail" % respond_at)
	check(ox_outcome(150.0, Vector2.UP, true, 0.0) == "miss",
		"an immediate Dodge off an Ox's line must clear it")
	check(ox_outcome(150.0, Vector2.UP, true, 0.5) == "contact",
		"a late Dodge off an Ox's line must not clear it")

func test_the_ox_commits_from_beyond_any_other_reach() -> void:
	# Line-based rather than distance-gated. A Boar cannot commit past about 380
	# units; the Ox must still be a threat well beyond that, which is what makes
	# bearing rather than spacing the question it asks.
	check(ox_outcome(500.0, Vector2.UP, false, 0.0) != "none",
		"the Ox must commit a charge from 500 units, where no other melee kind can")

func test_a_charge_always_offers_a_decision_to_a_free_player() -> void:
	# Answering the telegraph immediately must work at every range, on both axes.
	# Anything else means the wind-up is shorter than the player's commitment.
	for kind in ["boar", "hound"]:
		for gap in [90.0, 150.0, 220.0]:
			check(charge_outcome("%s" % kind, 0.0, gap, Vector2.LEFT) == "miss",
				"an immediate retreat from a %s charge at %.0f must escape" % [kind, gap])

func test_commitment_is_what_makes_you_late() -> void:
	# The capture principle applied to charges: it is your own action lockout that
	# converts a readable telegraph into a hit, not the telegraph being unreadable.
	check(charge_outcome_while_committed("boar", 150.0, Vector2.LEFT) == "contact",
		"committing to a strike inside a Boar's range must be punished")
	check(charge_outcome_while_committed("hound", 150.0, Vector2.LEFT) == "contact",
		"committing to a strike inside a Hound's range must be punished")
	# Distance still buys out of it -- against the Boar. The Hound is the animal you
	# cannot afford to be busy near at any range, which is its whole identity.
	check(charge_outcome_while_committed("boar", 220.0, Vector2.LEFT) == "miss",
		"range must let a committed player survive the slower charge")
	check(charge_outcome_while_committed("hound", 220.0, Vector2.LEFT) == "contact",
		"the Hound must punish commitment even at range")

func test_distance_restores_the_answer_to_a_charge() -> void:
	# Range is a real defence: the same charge from further out is escapable, and a
	# late answer still is not. Without this the charge would simply be unavoidable
	# rather than a question about spacing.
	check(charge_outcome("boar", 0.0, 220.0, Vector2.LEFT) == "miss",
		"an early retreat from a distant Boar charge must succeed")
	check(charge_outcome("boar", 0.0, 150.0, Vector2.UP) == "miss",
		"an early sidestep at mid range must succeed")
	check(charge_outcome("boar", 1.0, 150.0, Vector2.UP) == "contact",
		"a late sidestep at mid range must fail")

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

# --- Milestone E2: the anchor roles ---------------------------------------------
#
# The 0.2.30 survey recorded ten heavy attacks across Ox, Brute and Polearm and
# ZERO contacts, against six landed hits from nine Knife pokes. The heaviest bodies
# in the game were the safest things in it, because a long telegraph was a free
# cancel window and the armour meant to cover it only began once the weapon was
# already moving.

func armed_enemy(state: RunState, kind: String, offset: Vector2) -> Dictionary:
	var enemy := state._make_enemy(kind, state.player_pos + offset, 999, 5)
	enemy["awareness"] = "alerted"
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	state.enemies.append(enemy)
	return enemy

func test_a_heavy_telegraph_survives_posture_pressure() -> void:
	for kind in ["brute", "ox"]:
		var state := survey_state()
		var gap := Vector2.UP * 70.0 if kind == "brute" else Vector2.RIGHT * 400.0
		var enemy := armed_enemy(state, kind, gap)
		state._choose_enemy_action(enemy)
		var committed := String(Dictionary(enemy["action"]).get("kind", ""))
		check(committed in ["melee", "charge"], "%s should commit an attack from its own range, got %s" % [kind, committed])
		# Mid wind-up, before the damaging window opens.
		enemy["action"]["elapsed"] = 0.10
		var broke: bool = state._apply_posture_damage(enemy, 99.0)
		check(not broke, "%s should not lose its wind-up to a posture break" % kind)
		check(String(Dictionary(enemy["action"]).get("kind", "")) == committed, "%s should still be attacking after a posture break in its wind-up" % kind)

func test_a_heavy_telegraph_still_answers_to_a_real_blow() -> void:
	# Armour must not mean invulnerability: an attack with no opening can never be
	# answered if it repeats. Chip damage is refused, a heavy blow during startup is
	# not, which makes the counter a specific thing the player has to bring.
	var state := survey_state()
	var brute := armed_enemy(state, "brute", Vector2.UP * 70.0)
	state._choose_enemy_action(brute)
	brute["action"]["elapsed"] = 0.10
	var light: bool = state._apply_enemy_hit_reaction(brute, 1.0, "alerted", brute["action"], Vector2.ZERO, {})
	check(not light, "a light hit should not flinch a heavy out of its wind-up")
	var heavy: bool = state._apply_enemy_hit_reaction(brute, 4.0, "alerted", brute["action"], Vector2.ZERO, {})
	check(heavy, "a high-impact blow should still interrupt a heavy's wind-up")

func test_the_ox_reopens_its_own_charge_lane() -> void:
	# Standing inside its own minimum range, walking toward the player can never
	# restore the gap a gore needs. The 0.2.30 Ox landed four charges and then milled
	# about in strike range being hit.
	var state := survey_state()
	var ox := armed_enemy(state, "ox", Vector2.RIGHT * 90.0)
	state._choose_enemy_action(ox)
	var action: Dictionary = ox["action"]
	check(String(action.get("kind", "")) == "charge", "a crowded Ox should commit a movement charge, got %s" % String(action.get("kind", "")))
	check(String(action.get("label", "")) == "reset", "a crowded Ox should reset rather than gore")
	check(int(action.get("damage", -1)) == 0 and bool(action.get("hit_done", false)), "a disengage must carry no contact window")
	check(Vector2(action.get("direction", Vector2.ZERO)).dot(Vector2.RIGHT) > 0.9, "the Ox should reverse away from the player")
	# Bounded: this reopens a lane, it does not flee. The Hound's unbounded retreat
	# measured 495 units from the player.
	check(float(action.get("charge_cap", 0.0)) <= 260.0, "the disengage must stay a repositioning step")

func test_the_ox_still_gores_from_open_ground() -> void:
	var state := survey_state()
	var ox := armed_enemy(state, "ox", Vector2.RIGHT * 400.0)
	state._choose_enemy_action(ox)
	check(String(Dictionary(ox["action"]).get("label", "")) == "gore", "an Ox with room should still gore")

# --- The screen -----------------------------------------------------------------

func shield_room() -> Array:
	var state := survey_state()
	armed_enemy(state, "archer", Vector2.UP * 240.0)
	var shield := armed_enemy(state, "shield", Vector2.UP * 60.0)
	return [state, shield]

func test_a_screen_does_not_strike_a_free_player() -> void:
	# Proximity is a trigger the player can pull at will by stepping in and out, which
	# is how the 0.2.30 Shield got nine swings in a single room.
	var room := shield_room()
	var state: RunState = room[0]
	var shield: Dictionary = room[1]
	state._choose_enemy_action(shield)
	check(String(Dictionary(shield["action"]).get("kind", "")) != "melee", "a screen should not strike a player who is not committed to anything")

func test_a_screen_punishes_a_committed_player() -> void:
	var room := shield_room()
	var state: RunState = room[0]
	var shield: Dictionary = room[1]
	state.player_action = state._action("combo", 1.20, Vector2.UP)
	state._choose_enemy_action(shield)
	check(String(Dictionary(shield["action"]).get("kind", "")) == "melee", "a screen should punish a player who is late")

func test_a_screen_loses_composure_on_its_own() -> void:
	# It has to make mistakes the player can punish, and a standoff has to resolve.
	# An enemy that is always correct is annoying rather than difficult.
	var room := shield_room()
	var state: RunState = room[0]
	var shield: Dictionary = room[1]
	shield["patience"] = 0.0
	state._choose_enemy_action(shield)
	check(String(Dictionary(shield["action"]).get("kind", "")) == "melee", "a screen out of patience should swing at nothing")

func test_screen_tempers_differ_between_instances() -> void:
	var state := survey_state()
	var first := armed_enemy(state, "shield", Vector2.UP * 60.0)
	var second := armed_enemy(state, "shield", Vector2.DOWN * 130.0)
	check(float(first["patience_max"]) > 0.0, "a screen should carry a patience budget")
	check(not is_equal_approx(float(first["patience_max"]), float(second["patience_max"])), "two screens should not share a temper")

func test_a_ward_must_be_something_the_screen_can_stand_in_front_of() -> void:
	# Unbounded, the anchor averaged every matching ally on the layer -- on a generated
	# floor that picked a ward 11,754 units away and steered off the navigation grid.
	var state := survey_state()
	var shield := armed_enemy(state, "shield", Vector2.UP * 60.0)
	armed_enemy(state, "archer", Vector2.UP * 4000.0)
	var ward: Vector2 = state._ally_anchor(shield, ["ranged_pressure", "area_denial", "reach"])
	check(ward.is_equal_approx(state.player_pos), "a distant ally is not a ward")

# --- The deck -------------------------------------------------------------------

func test_late_phases_have_content_above_the_opening_tiers() -> void:
	# Coverage sampling cannot fix a deck with nothing left to deal. Respite and
	# opening both topped out at min_tier 3, so the 0.2.30 run exhausted them at room
	# 12 and repeated tier-1 melee rooms at tiers 6 and 7.
	var state := survey_state()
	for phase in ["respite", "opening"]:
		var late := 0
		for recipe_value in state._survey_recipe_catalog():
			var recipe := Dictionary(recipe_value)
			if int(recipe["min_tier"]) >= 4 and phase in Array(recipe["phases"]): late += 1
		check(late > 0, "%s has no recipe above the opening tiers" % phase)

# --- Milestone E3: mass, crowding and felt damage ------------------------------

func free_directions(state: RunState) -> int:
	var free := 0
	for degrees in range(0, 360, 15):
		var step := Vector2.RIGHT.rotated(deg_to_rad(float(degrees))) * state.MOVE_SPEED / 120.0
		if state._move_actor(state.player_pos, step, state.PLAYER_RADIUS, 0).distance_to(state.player_pos) > 0.0001: free += 1
	return free

func ringed_state(kind: String, count: int) -> RunState:
	var state := survey_state()
	for index in range(count):
		var bearing := Vector2.RIGHT.rotated(TAU * float(index) / float(count))
		var probe := state._make_enemy(kind, Vector2.ZERO, 1, 5)
		var enemy := state._make_enemy(kind, state.player_pos + bearing * (state.PLAYER_RADIUS + float(probe["radius"]) + 1.0), 999, 5)
		enemy["awareness"] = "alerted"
		state.enemies.append(enemy)
	state._build_enemy_spatial_index()
	return state

func test_the_player_parts_a_crowd_of_light_bodies() -> void:
	# A tight ring of five left 14 of 24 directions completely dead, which reads as
	# the controls failing rather than as pressure -- and it worsened as bodies grew.
	var state := ringed_state("knife", 5)
	check(free_directions(state) == 24, "light bodies should never take a movement direction away")

func test_heavy_bodies_still_stop_you() -> void:
	# The other half of the rule: if everything gave way, nothing would be a wall and
	# the anchor roles would have no way to charge you for going around them.
	var state := ringed_state("ox", 5)
	check(free_directions(state) < 24, "an Ox ring should still block movement")

func test_mass_decides_what_can_be_shoved() -> void:
	var state := survey_state()
	var pushable := ["hound", "knife", "bandit", "blade", "archer", "captain", "polearm", "boar"]
	var immovable := ["shield", "brute", "knight", "ox"]
	for kind in pushable:
		check(state._enemy_is_pushable(state._make_enemy(kind, state.player_pos, 1, 5)), "%s should be shoveable" % kind)
	for kind in immovable:
		check(not state._enemy_is_pushable(state._make_enemy(kind, state.player_pos, 1, 5)), "%s should be a wall" % kind)

func test_every_connecting_strike_is_felt() -> void:
	# The flat x5 curve left a cliff, not a gradient: at the survey's defense of 4 the
	# three authored-1 attacks cost 1 health while everything else cost 6 or more --
	# and those three belonged to the Knife and Bandit, the enemies that land most
	# often. The enemy you could not avoid did nothing.
	var expected := {1: 5, 2: 10, 3: 13}
	for authored in expected.keys():
		var state := survey_state()
		var defense: int = int(state.player_attributes.get("defense", 0)) + int(state.player_properties.get("armor", 0))
		check(defense == 4, "this expectation is authored against a physical defense of 4, got %d" % defense)
		var before: int = state.player_hp
		state._resolve_incoming_hit(1, int(authored), "probe", Vector2.LEFT, state.player_pos)
		var felt: int = before - state.player_hp
		check(felt == int(expected[authored]), "authored %d should cost %d health, cost %d" % [authored, int(expected[authored]), felt])

func test_no_attack_can_be_reduced_to_nothing() -> void:
	var state := survey_state()
	state.player_properties["armor"] = 999
	var before: int = state.player_hp
	state._resolve_incoming_hit(1, 1, "probe", Vector2.LEFT, state.player_pos)
	check(before - state.player_hp == state.MIN_FELT_DAMAGE, "armour must never turn a hit into nothing")

func _init() -> void:
	test_charges_produce_capture_records()
	test_a_heavy_telegraph_survives_posture_pressure()
	test_a_heavy_telegraph_still_answers_to_a_real_blow()
	test_the_ox_reopens_its_own_charge_lane()
	test_the_ox_still_gores_from_open_ground()
	test_a_screen_does_not_strike_a_free_player()
	test_a_screen_punishes_a_committed_player()
	test_a_screen_loses_composure_on_its_own()
	test_screen_tempers_differ_between_instances()
	test_a_ward_must_be_something_the_screen_can_stand_in_front_of()
	test_late_phases_have_content_above_the_opening_tiers()
	test_the_player_parts_a_crowd_of_light_bodies()
	test_heavy_bodies_still_stop_you()
	test_mass_decides_what_can_be_shoved()
	test_every_connecting_strike_is_felt()
	test_no_attack_can_be_reduced_to_nothing()
	test_the_ox_cannot_be_outrun_only_evaded()
	test_the_ox_commits_from_beyond_any_other_reach()
	test_a_charge_always_offers_a_decision_to_a_free_player()
	test_commitment_is_what_makes_you_late()
	test_distance_restores_the_answer_to_a_charge()
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
