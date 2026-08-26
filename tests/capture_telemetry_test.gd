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
	# Clearing the array is not enough: the wall spatial index is what line-of-sight
	# actually queries, so without a rebuild these tests keep whatever geometry the
	# opening room happened to draw -- and a test's result then depends on which arena
	# the recipe deck produced, which is how changing the deck broke unrelated tests.
	state._build_wall_spatial_index()
	state.hazards.clear()
	state.projectiles.clear()
	# Several behaviours are seeded on enemy id -- which side a Bandit slips to, which
	# lane a Hound reserves, a Shield's temper. Without this, a test's outcome depends on
	# how many enemies the opening room happened to spawn, so changing the recipe deck
	# silently flips unrelated tests. The id restarts here so a test controls its own.
	state._next_enemy_id = 1
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
	# Distance buys out of it for BOTH animals. This used to assert that the Hound
	# punished commitment at any range -- but that direction was explicitly rejected
	# during E2 and the source records the reasoning at the Hound's charge gate:
	# tracking_end was matched to the Boar's 0.70 precisely because at 0.55 "a committed
	# player was caught even at 220", and "you can never be busy near a Hound" is a
	# constraint rather than a decision. The test was preserving the direction the design
	# threw out. Hound differentiation lives in damage, body width, speed and re-charge
	# cadence, all of which are visible before you commit.
	check(charge_outcome_while_committed("boar", 220.0, Vector2.LEFT) == "miss",
		"range must let a committed player survive the slower charge")
	check(charge_outcome_while_committed("hound", 220.0, Vector2.LEFT) == "miss",
		"range must buy out of the Hound's charge too -- E2 rejected the alternative")

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
	var pushable := ["hound", "knife", "bandit", "blade", "archer", "javelineer", "polearm", "boar"]
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

# --- Milestone E4: the roster earns its places ----------------------------------

func alerted(state: RunState, kind: String, offset: Vector2) -> Dictionary:
	var enemy := state._make_enemy(kind, state.player_pos + offset, 999, 5)
	enemy["awareness"] = "alerted"
	enemy["alert_remaining"] = 9.0
	enemy["revealed_to_player"] = true
	enemy["revealed_elapsed"] = 5.0
	enemy["facing"] = (state.player_pos - Vector2(enemy["pos"])).normalized()
	state.enemies.append(enemy)
	return enemy

# --- The Chanter ----------------------------------------------------------------

func test_a_chanter_has_no_attack_of_its_own() -> void:
	# It is worth reaching precisely because reaching it ends the problem. An enemy
	# that buffs AND fights would be a better version of every other enemy.
	check(CombatCatalogScript.melee_attack_plan("chanter").is_empty(), "the Chanter should carry no attack plan")

func test_a_chanter_puts_an_ally_between_itself_and_you() -> void:
	var state := survey_state()
	alerted(state, "brute", Vector2.UP * 170.0)
	var chanter := alerted(state, "chanter", Vector2.UP * 90.0)
	state._choose_enemy_action(chanter)
	check(String(Dictionary(chanter["action"])["kind"]) == "move", "a cornered Chanter should reposition, not stand and cast")

func test_a_chant_suits_the_allies_it_has() -> void:
	# You know it buffs. You do not know which buff, because you cannot see which
	# allies it has counted -- the same information shape as an enemy with two attacks.
	var heavy := survey_state()
	alerted(heavy, "brute", Vector2.UP * 150.0)
	var heavy_caster := alerted(heavy, "chanter", Vector2.UP * 400.0)
	check(heavy._choose_chant(heavy._chant_targets(heavy_caster)) == "bulwark", "heavy allies should be hardened")
	var fast := survey_state()
	alerted(fast, "hound", Vector2.UP * 150.0)
	var fast_caster := alerted(fast, "chanter", Vector2.UP * 400.0)
	check(fast._choose_chant(fast._chant_targets(fast_caster)) == "haste", "fast allies should be quickened")

func test_bulwark_lends_telegraph_armour_to_a_light_body() -> void:
	# The yellow chant is not a stat: it makes a Blade behave like a heavy for as long
	# as it lasts, which is a visible, killable reason the room got harder.
	var state := survey_state()
	var blade := alerted(state, "blade", Vector2.UP * 70.0)
	var chanter := alerted(state, "chanter", Vector2.UP * 300.0)
	state.player_action = state._action("wait", 3.0, Vector2.UP)
	state._choose_enemy_action(blade)
	check(String(Dictionary(blade["action"])["kind"]) == "melee", "the Blade should be attacking for this to mean anything")
	blade["action"]["elapsed"] = 0.06
	check(state._apply_posture_damage(blade, 99.0), "an unchanted Blade loses its wind-up to a posture break")
	state._choose_enemy_action(blade)
	blade["action"]["elapsed"] = 0.06
	state._resolve_chant(chanter, "bulwark")
	check(state._enemy_has_chant(blade, "bulwark"), "the chant should have landed")
	check(not state._apply_posture_damage(blade, 99.0), "a bulwarked Blade should hold its wind-up")

func test_ward_reduces_damage_without_granting_immunity() -> void:
	var state := survey_state()
	var blade := alerted(state, "blade", Vector2.UP * 70.0)
	var chanter := alerted(state, "chanter", Vector2.UP * 300.0)
	var plain := int(Dictionary(state._resolve_player_physical_values(blade, 20, 1.0, {}))["damage"])
	state._resolve_chant(chanter, "ward")
	var warded := int(Dictionary(state._resolve_player_physical_values(blade, 20, 1.0, {}))["damage"])
	check(warded < plain, "ward should reduce incoming damage")
	check(warded > 0, "ward must never make an enemy immune -- the answer is the caster, not surrender")

# --- The Javelineer -------------------------------------------------------------

func test_a_javelin_is_thrown_where_you_are_going() -> void:
	# Running in a straight line is what beats an Archer, so the second ranged enemy
	# has to punish exactly that, or both of them ask the same question.
	var state := survey_state()
	var javelineer := alerted(state, "javelineer", Vector2.UP * 420.0)
	state.player_action = state._action("move", 3.0, Vector2.RIGHT)
	state._spawn_javelin(javelineer)
	check(state.projectiles.size() == 1, "the throw should produce a projectile")
	if state.projectiles.is_empty(): return
	var javelin := Dictionary(state.projectiles[0])
	check(Vector2(javelin["vel"]).normalized().x > 0.15, "the javelin should lead a player moving right")

func test_a_javelin_trades_speed_for_width() -> void:
	# Easy to sidestep, and that is the design: while it is in the air one lane is
	# unavailable. It spends your choice of direction, not your health.
	var state := survey_state()
	var archer := alerted(state, "archer", Vector2.UP * 420.0)
	state._spawn_projectile(archer)
	var arrow := Dictionary(state.projectiles[0])
	state.projectiles.clear()
	var javelineer := alerted(state, "javelineer", Vector2.UP * 420.0)
	state.player_action = state._idle_action()
	state._spawn_javelin(javelineer)
	var javelin := Dictionary(state.projectiles[0])
	check(Vector2(javelin["vel"]).length() < Vector2(arrow["vel"]).length(), "a javelin should fly slower than an arrow")
	check(float(javelin["radius"]) > float(arrow["radius"]), "a javelin should cover more ground than an arrow")

# --- The Earth Caster -----------------------------------------------------------

func test_sundered_ground_costs_time_and_never_health() -> void:
	# The third currency. Fire and ice threaten damage; this one takes the only thing
	# frozen time makes expensive.
	var state := survey_state()
	var caster := alerted(state, "earth_caster", Vector2.UP * 380.0)
	var open_speed := state.current_move_speed()
	state._spawn_sundered_ground(state.player_pos, int(caster["id"]), state.current_layer)
	state.hazards[0]["triggered"] = true
	check(state.current_move_speed() < open_speed, "sundered ground should slow the player")
	var before: int = state.player_hp
	for _step in range(240): state._update_hazards(state.SIM_DT)
	check(state.player_hp == before, "sundered ground must never deal damage")

func test_sundered_ground_slows_enemies_too() -> void:
	# Symmetrical on purpose. One-sided it would read as arbitrary; shared, it becomes
	# terrain the player can use -- an Ox charging through broken earth is slowed by the
	# same rule.
	var state := survey_state()
	var hound := alerted(state, "hound", Vector2.UP * 120.0)
	var open_speed := state._enemy_move_speed(hound)
	state._spawn_sundered_ground(Vector2(hound["pos"]), 999, state.current_layer)
	state.hazards[0]["triggered"] = true
	check(state._enemy_move_speed(hound) < open_speed, "sundered ground should slow enemies as well")

func test_the_cut_lands_between_you_and_where_you_are_going() -> void:
	var state := survey_state()
	var caster := alerted(state, "earth_caster", Vector2.UP * 380.0)
	state.player_action = state._action("move", 3.0, Vector2.RIGHT)
	var target: Vector2 = state._sunder_target(caster)
	check(target.x > state.player_pos.x + 60.0, "ground you already stand on is ground you have already spent")

# --- The Duellist ---------------------------------------------------------------

func test_a_duellist_parries_a_swing_it_read() -> void:
	# The Bandit slips around you and counters; this one plants and takes your turn.
	# In frozen time that is the more expensive currency, because the rest of the room
	# gets to act inside it.
	var state := survey_state()
	var duellist := alerted(state, "duellist", Vector2.UP * 90.0)
	duellist["action"] = state._idle_action()
	state.player_facing = Vector2.UP
	state.player_action = state._action("combo", 2.0, Vector2.UP)
	state.player_action["startup"] = 0.30
	state.player_action["reach"] = 104.0
	state.player_action["elapsed"] = 0.10
	state._try_duellist_parry(duellist)
	check(String(Dictionary(duellist["action"])["kind"]) == "parry_stance", "it should take the stance during the wind-up")
	duellist["action"]["elapsed"] = 0.20
	check(state._enemy_parries_attack(duellist), "a swing into the stance should be parried")

func test_a_parry_can_be_baited_and_then_punished() -> void:
	# Spent whether or not it catches anything, so the counter-play is to draw it with
	# something cheap and attack into the gap. An enemy that always parries is a wall.
	var state := survey_state()
	var duellist := alerted(state, "duellist", Vector2.UP * 90.0)
	duellist["action"] = state._idle_action()
	state.player_facing = Vector2.UP
	state.player_action = state._action("combo", 2.0, Vector2.UP)
	state.player_action["startup"] = 0.30
	state.player_action["reach"] = 104.0
	state.player_action["elapsed"] = 0.10
	state._try_duellist_parry(duellist)
	duellist["action"] = state._idle_action()
	state._try_duellist_parry(duellist)
	check(String(Dictionary(duellist["action"])["kind"]) != "parry_stance", "the stance is on a cooldown and must not re-arm immediately")

func test_a_duellist_cannot_parry_what_comes_from_behind() -> void:
	var state := survey_state()
	var duellist := alerted(state, "duellist", Vector2.UP * 90.0)
	duellist["action"] = state._action("parry_stance", 0.72, Vector2.DOWN)
	duellist["action"]["parry_end"] = 0.42
	duellist["action"]["elapsed"] = 0.20
	duellist["facing"] = Vector2.UP
	check(not state._enemy_parries_attack(duellist), "getting behind a Duellist is the positional answer to it")

func test_the_duellists_two_attacks_open_in_different_places() -> void:
	# One poke, one swing. The poke commits fast and is punished on its recovery; the
	# swing announces itself and is punished before it lands. No single habit answers
	# both, which is what stops it being solved by repetition.
	var poke := plan_option("duellist", "rapier_thrust")
	var swing := plan_option("duellist", "diagonal_cut")
	check(not poke.is_empty() and not swing.is_empty(), "the Duellist should carry both attacks")
	if poke.is_empty() or swing.is_empty(): return
	check(float(poke["startup"]) < float(swing["startup"]), "the poke should commit faster than the swing")
	var poke_recovery := float(poke["duration"]) - float(poke["active_end"])
	var swing_recovery := float(swing["duration"]) - float(swing["active_end"])
	check(poke_recovery > swing_recovery, "the poke should be the one you punish afterwards")

# --- 0.2.34: what the 0.2.33 survey said was broken -----------------------------

func test_a_screens_opening_outlasts_the_commitment_that_bought_it() -> void:
	# A screen's guard is down for the whole of its own attack, and that attack is its
	# ONLY opening. Patience cut its swings from nine a room to three, which shrank the
	# NUMBER of openings without growing them -- the 0.2.33 tester tagged it unfair
	# twice. The window has to still be open when the player gets control back.
	var option := plan_option("shield", "diagonal_cut")
	check(not option.is_empty(), "the Shield should carry its cut")
	if option.is_empty(): return
	# 0.983s is the measured lockout of a combo strike, the commitment that draws it.
	check(float(option["duration"]) - 0.983 > 0.60, "the guard-down window must survive the player's combo lockout with room to reach it")

func test_a_light_body_cannot_act_inside_the_swing_that_hit_it() -> void:
	# "He recuperated before I was able to finish the combo" -- 0.2.33 room 6. A posture
	# break already guaranteed player_remaining + 0.72s; an ordinary flinch guaranteed
	# nothing, so a Blade's flat 0.48s expired mid-combo and it hit back from frames the
	# player could not answer from.
	var state := survey_state()
	var blade := alerted(state, "blade", Vector2.UP * 70.0)
	state.player_action = state._action("combo", 1.40, Vector2.UP)
	state.player_action["startup"] = 0.24
	state.player_action["elapsed"] = 0.30
	var remaining := state._player_commitment_remaining()
	state._choose_enemy_action(blade)
	var before := Dictionary(blade["action"]).duplicate(true)
	state._apply_enemy_hit_reaction(blade, 1.0, "alerted", before, Vector2.ZERO, {})
	check(String(Dictionary(blade["action"])["kind"]) == "hit_reaction", "the Blade should flinch")
	check(float(Dictionary(blade["action"])["duration"]) >= remaining - 0.05, "the flinch must cover the rest of the commitment that caused it")

func test_a_heavy_body_keeps_its_short_recovery() -> void:
	# Heavies answer with armour instead. Giving them the flinch floor as well would
	# make a committed heavy unpunishable, which is the opposite of the E2 intent.
	var state := survey_state()
	var ox := alerted(state, "ox", Vector2.RIGHT * 400.0)
	state.player_action = state._action("combo", 2.40, Vector2.UP)
	state.player_action["startup"] = 0.24
	state.player_action["elapsed"] = 0.30
	state._choose_enemy_action(ox)
	var before := Dictionary(ox["action"]).duplicate(true)
	before["elapsed"] = 0.10
	state._apply_enemy_hit_reaction(ox, 4.0, "alerted", before, Vector2.ZERO, {})
	if String(Dictionary(ox["action"])["kind"]) != "hit_reaction": return
	check(float(Dictionary(ox["action"])["duration"]) < 1.0, "a heavy should not inherit the flinch floor")

func test_the_spear_takes_its_short_cut_when_you_are_inside_the_point() -> void:
	# Weighted selection kept choosing the 205-unit thrust at 105 units (1.7 against
	# 1.0), and a thrust authored for 205 is trivially walked out of from half that.
	# It went 0 for 5 across the 0.2.33 run.
	var state := survey_state()
	var polearm := alerted(state, "polearm", Vector2.UP * 95.0)
	state.player_action = state._idle_action()
	state._choose_enemy_action(polearm)
	check(String(Dictionary(polearm["action"]).get("technique_id", "")) == "reverse_cut", "inside the point, the shaft cut is the answer")

func test_the_long_thrust_is_still_only_thrown_at_lateness() -> void:
	var state := survey_state()
	var polearm := alerted(state, "polearm", Vector2.UP * 205.0)
	state.player_action = state._idle_action()
	state._choose_enemy_action(polearm)
	check(String(Dictionary(polearm["action"])["kind"]) != "melee", "a free player at spear range should not draw the thrust")
	state.player_action = state._action("wait", 2.0, Vector2.UP)
	state._choose_enemy_action(polearm)
	check(String(Dictionary(polearm["action"]).get("technique_id", "")) == "thrust", "a committed player should")

func test_a_javelineer_faces_where_it_throws() -> void:
	# It used to compute the lead at RELEASE, so it faced the player through the whole
	# wind-up and then threw somewhere else -- no telegraph, and a shot that could not
	# be read.
	var state := survey_state()
	var javelineer := alerted(state, "javelineer", Vector2.UP * 400.0)
	state.player_action = state._action("move", 3.0, Vector2.RIGHT)
	state._choose_enemy_action(javelineer)
	check(String(Dictionary(javelineer["action"])["kind"]) == "hurl", "it should be winding up a throw")
	if String(Dictionary(javelineer["action"])["kind"]) != "hurl": return
	var line := Vector2(Dictionary(javelineer["action"])["direction"])
	check(Vector2(javelineer["facing"]).dot(line) > 0.999, "the thrower must face its own line")
	state._spawn_javelin(javelineer)
	check(not state.projectiles.is_empty(), "the throw should produce a javelin")
	if state.projectiles.is_empty(): return
	check(Vector2(Dictionary(state.projectiles[0])["vel"]).normalized().dot(line) > 0.999, "and release along it rather than re-aiming")

func test_the_duellists_poke_is_a_sword_not_a_spear() -> void:
	var poke := plan_option("duellist", "rapier_thrust")
	var spear := plan_option("polearm", "thrust")
	check(not poke.is_empty(), "the Duellist should carry a rapier thrust")
	if poke.is_empty() or spear.is_empty(): return
	check(float(poke["reach"]) < float(spear["reach"]) * 0.55, "a sword poke must not out-reach a polearm's shaft cut")

# --- Milestone G1: composition ---------------------------------------------------
#
# These encode the findings in docs/survey-archive-findings.md, taken from 297 rated
# rooms across 30 runs. The headline: the number of NON-MELEE enemies in a room is very
# nearly the whole story. 0/1/2 of them maps to 1.61/2.48/3.20 mean fun, the effect
# holds inside every version era and is largest in the most recent, all ten of the best
# rooms ever recorded contain one, and 87% of the worst rooms are pure melee.
#
# Two designs the archive killed, asserted against here so they are not quietly
# reintroduced: a demand/punish conflict score (193 of 200 rooms scored zero) and
# role-diversity scoring (role count and non-melee count are nearly the same variable).

func room_phase(room_number: int) -> String:
	return ["opening", "development", "contrast", "pressure", "climax", "respite"][(room_number - 1) % 6]

func composition_for(state: RunState, room_number: int, salt: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + salt * 131 + room_number
	var phase := room_phase(room_number)
	return state._survey_composition(rng, room_number, state._survey_threat_band(phase, rng), phase)

func test_every_room_carries_non_melee_pressure() -> void:
	# The guarantee. Enforced in the selector rather than trusted to the deck, so a
	# recipe added later cannot quietly reintroduce the rooms that measured 1.5 fun.
	var offenders := 0
	for salt in range(8):
		var state := survey_state()
		for room_number in range(1, 14):
			var recipe := composition_for(state, room_number, salt)
			if bool(recipe.get("melee_experiment", false)): continue
			if state._recipe_non_melee_count(recipe) == 0: offenders += 1
	check(offenders == 0, "%d non-experiment rooms were composed with no non-melee pressure" % offenders)

func test_melee_only_rooms_are_deliberate_and_rationed() -> void:
	# The exception exists to run an experiment, not to pad the deck. Every melee-only
	# room in the archive was built from the five oldest kinds and the Shield and
	# Duellist never once appeared in one -- so "melee-only rooms are irredeemable" and
	# "those five enemies are undifferentiated" are still indistinguishable.
	var state := survey_state()
	var experiment_rooms: Array[int] = []
	for room_number in range(1, 14):
		if state._survey_is_melee_experiment_room(room_number): experiment_rooms.append(room_number)
	check(experiment_rooms == [3, 7, 11], "experiments should fall on rooms 3, 7 and 11, got %s" % str(experiment_rooms))

func test_the_experiment_uses_the_differentiated_roster() -> void:
	# Testing melee differentiation with Boar and Hound would answer nothing: those are
	# the kinds the archive already condemned. The experiment has to field the enemies
	# E2, E3 and E4 actually changed.
	var differentiated := ["shield", "duellist", "ox", "polearm", "brute"]
	var state := survey_state()
	var checked := 0
	for recipe_value in state._survey_recipe_catalog():
		var recipe := Dictionary(recipe_value)
		if not bool(recipe.get("melee_experiment", false)): continue
		checked += 1
		var found := false
		for entry in Array(recipe["enemies"]):
			if String(Dictionary(entry).get("kind", "")) in differentiated: found = true
		check(found, "%s is a melee experiment built from none of the differentiated kinds" % String(recipe["id"]))
	check(checked >= 3, "there should be enough melee experiments to read a result, found %d" % checked)

func test_a_melee_experiment_really_is_melee_only() -> void:
	# If an experiment carried an archer it would measure nothing.
	var state := survey_state()
	for recipe_value in state._survey_recipe_catalog():
		var recipe := Dictionary(recipe_value)
		if not bool(recipe.get("melee_experiment", false)): continue
		check(state._recipe_non_melee_count(recipe) == 0,
			"%s is flagged as a melee experiment but carries non-melee pressure" % String(recipe["id"]))

func test_every_room_number_has_something_to_draw() -> void:
	# A tier-and-phase combination with no eligible recipe would fall back to the first
	# entry in the catalog regardless of fitness.
	var state := survey_state()
	for salt in range(4):
		for room_number in range(1, 14):
			var recipe := composition_for(state, room_number, salt)
			check(not String(recipe.get("id", "")).is_empty(), "room %d produced no recipe" % room_number)
			check(not Array(recipe.get("enemies", [])).is_empty(), "room %d produced an empty composition" % room_number)

func test_every_recipe_can_actually_be_drawn() -> void:
	# The Chanter and the Ox spent a whole version unplayed because chanted_line needed
	# tier 6 and a ten-room run reaches tier 5. A recipe that cannot be reached is a
	# recipe that cannot be evaluated, and this is how that stops being discovered by
	# accident. Climax is the trap: it falls on rooms 5 and 11, and 11 is always an
	# experiment, so a climax-only recipe above tier 3 is unreachable by construction.
	var state := survey_state()
	var reachable: Dictionary = {}
	for room_number in range(1, 14):
		var tier := 1 + int(floor(float(room_number - 1) * 0.5))
		var phase := room_phase(room_number)
		var wants_experiment := state._survey_is_melee_experiment_room(room_number)
		for recipe_value in state._survey_recipe_catalog():
			var recipe := Dictionary(recipe_value)
			if tier < int(recipe["min_tier"]) or not Array(recipe["phases"]).has(phase): continue
			if bool(recipe.get("melee_experiment", false)) != wants_experiment: continue
			reachable[String(recipe["id"])] = true
	for recipe_value in state._survey_recipe_catalog():
		var recipe_id := String(Dictionary(recipe_value)["id"])
		check(reachable.has(recipe_id), "%s can never be drawn in a 13-room run" % recipe_id)

func test_every_enemy_kind_can_reach_a_room() -> void:
	var state := survey_state()
	var placed: Dictionary = {}
	for recipe_value in state._survey_recipe_catalog():
		for entry in Array(Dictionary(recipe_value)["enemies"]):
			placed[String(Dictionary(entry).get("kind", ""))] = true
	for kind in ["archer", "javelineer", "chanter", "earth_caster", "ox", "duellist", "shield", "polearm", "brute", "knight"]:
		check(placed.has(kind), "%s is in the roster but no recipe fields it" % kind)

func test_the_hexer_is_gone() -> void:
	# Retired in G1. Its identity was a delayed danger zone, which under the elemental
	# framework is a delivery mechanism rather than an element -- and Fire and Ice both
	# already use it.
	# archetype() falls back to the Blade for unknown ids, so it is never empty -- ask
	# the table directly.
	check(not CombatCatalogScript.ARCHETYPES.has("hexer"), "the Hexer should no longer be in the catalog")
	var state := survey_state()
	for recipe_value in state._survey_recipe_catalog():
		for entry in Array(Dictionary(recipe_value)["enemies"]):
			check(String(Dictionary(entry).get("kind", "")) != "hexer", "a recipe still fields a Hexer")

func test_a_reeling_screen_cannot_hold_its_guard() -> void:
	# The 0.2.35 survey tagged two rooms unfair and the strike log named the cause: six
	# blocks landed while the Shield was in hit_reaction, at elapsed 0.40 through 1.79.
	# You hit it, it flinched, and it blocked the follow-up with a guard it could not be
	# holding. Its own attack was already excluded; being staggered was not.
	var state := survey_state()
	var shield := alerted(state, "shield", Vector2.UP * 70.0)
	shield["facing"] = (state.player_pos - Vector2(shield["pos"])).normalized()
	shield["action"] = state._idle_action()
	check(state._enemy_blocks_attack(shield), "an untouched Shield facing you should block")
	for reeling in ["hit_reaction", "stagger"]:
		shield["action"] = state._action(reeling, 0.8, Vector2.ZERO)
		check(not state._enemy_blocks_attack(shield), "a Shield in %s must not block" % reeling)
	shield["action"] = state._action("melee", 2.15, Vector2.UP)
	check(not state._enemy_blocks_attack(shield), "a Shield mid-swing must not block")

func test_the_archer_leaves_room_to_answer_it() -> void:
	# 0.2.30 was right that ~2.7s between shots is weather; 0.2.33 overcorrected to a
	# 0.46 wind-up, which lands inside a 0.983s strike lockout every time -- so the only
	# answer was to stop attacking. The wind-up has to survive contact with a commitment.
	var state := survey_state()
	var archer := alerted(state, "archer", Vector2.UP * 420.0)
	# Archers spawn with a small staggered cooldown (0.22 x id % 3) so a formation does
	# not volley in unison. Cleared here so the first decision is the shot under test.
	archer["shot_cooldown"] = 0.0
	state._choose_enemy_action(archer)
	var action: Dictionary = archer["action"]
	check(String(action["kind"]) == "shoot", "the archer should be drawing")
	if String(action["kind"]) != "shoot": return
	check(float(action["startup"]) >= 0.55, "the archer's wind-up should leave time to read it")
	check(float(action["startup"]) <= 0.68, "but it should stay faster than the 0.2.30 archer that read as weather")

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
	test_a_chanter_has_no_attack_of_its_own()
	test_a_chanter_puts_an_ally_between_itself_and_you()
	test_a_chant_suits_the_allies_it_has()
	test_bulwark_lends_telegraph_armour_to_a_light_body()
	test_ward_reduces_damage_without_granting_immunity()
	test_a_javelin_is_thrown_where_you_are_going()
	test_a_javelin_trades_speed_for_width()
	test_sundered_ground_costs_time_and_never_health()
	test_sundered_ground_slows_enemies_too()
	test_the_cut_lands_between_you_and_where_you_are_going()
	test_a_duellist_parries_a_swing_it_read()
	test_a_parry_can_be_baited_and_then_punished()
	test_a_duellist_cannot_parry_what_comes_from_behind()
	test_the_duellists_two_attacks_open_in_different_places()
	test_a_screens_opening_outlasts_the_commitment_that_bought_it()
	test_a_light_body_cannot_act_inside_the_swing_that_hit_it()
	test_a_heavy_body_keeps_its_short_recovery()
	test_the_spear_takes_its_short_cut_when_you_are_inside_the_point()
	test_the_long_thrust_is_still_only_thrown_at_lateness()
	test_a_javelineer_faces_where_it_throws()
	test_the_duellists_poke_is_a_sword_not_a_spear()
	test_every_room_carries_non_melee_pressure()
	test_melee_only_rooms_are_deliberate_and_rationed()
	test_the_experiment_uses_the_differentiated_roster()
	test_a_melee_experiment_really_is_melee_only()
	test_every_room_number_has_something_to_draw()
	test_every_recipe_can_actually_be_drawn()
	test_every_enemy_kind_can_reach_a_room()
	test_the_hexer_is_gone()
	test_a_reeling_screen_cannot_hold_its_guard()
	test_the_archer_leaves_room_to_answer_it()
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
