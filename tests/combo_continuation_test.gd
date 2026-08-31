extends SceneTree

# Milestone A — combo continuation follows live input.
#
# The grammar under test: continuation is *sampled* at each authored link point,
# never banked. While a qualifying input is still live the sequence flows into the
# next strike, so one sustained hold may produce one, two or all three Sword
# strikes by duration alone. An input that has ended, or was never held at all,
# must not continue anything.
#
# The defect this locks out: `request_combo()` used to seed that state `true`
# unconditionally, so a quick tap — which runs from inside pointer release and has
# no live input behind it — committed the entire sequence.

const RunStateScript = preload("res://scripts/core/run_state.gd")
const GameBoardScript = preload("res://scripts/presentation/game_board.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func fresh_state(loadout: String = "warrior", rules: String = "energy") -> RunState:
	# Always choose the combat rule profile explicitly. A RunState built without
	# setup defaults to Recovery, which would make these names lie.
	var state: RunState = RunStateScript.new(false)
	state.start_run(loadout, "combat_survey", 4242, "encounter", rules)
	state.enemies.clear()
	return state

func strikes_committed(state: RunState) -> int:
	return int(state.player_action.get("committed_phase", -1)) + 1

# Drives a combo to completion, optionally releasing the input once `elapsed`
# reaches `release_at`. Returns how many strikes the sequence actually committed.
func run_combo(state: RunState, held: bool, release_at: float) -> int:
	state.request_combo(Vector2.UP, false, held)
	var reached := strikes_committed(state)
	var pending := release_at
	while state.advance_streamed_action_tick():
		if pending >= 0.0 and float(state.player_action.get("elapsed", 0.0)) >= pending:
			state.set_attack_hold(false)
			pending = -1.0
		reached = maxi(reached, strikes_committed(state))
	return reached

func link_points(state: RunState) -> Array:
	var points := []
	for phase_value in Array(state.player_action.get("phases", [])):
		var phase := Dictionary(phase_value)
		points.append(float(phase.get("link", phase["active_end"])))
	return points

func test_tap_commits_exactly_one_strike() -> void:
	var state := fresh_state()
	check(run_combo(state, false, -1.0) == 1, "a tap with no live input must commit exactly one strike")

func test_sustained_hold_completes_the_sequence() -> void:
	var state := fresh_state()
	check(run_combo(state, true, -1.0) == 3, "a hold sustained past every link must complete all three Sword strikes")

func test_release_before_first_link_yields_one_strike() -> void:
	var state := fresh_state()
	state.request_combo(Vector2.UP, false, true)
	var first_link: float = link_points(state)[0]
	var run := fresh_state()
	check(run_combo(run, true, maxf(0.0, first_link - 0.05)) == 1, "releasing before the first link must stop after the opening strike")

func test_release_between_links_yields_two_strikes() -> void:
	var state := fresh_state()
	state.request_combo(Vector2.UP, false, true)
	var links := link_points(state)
	# Midway between the first and second link: the first continuation was live,
	# the second was not.
	var release_at: float = (float(links[0]) + float(links[1])) * 0.5
	var run := fresh_state()
	check(run_combo(run, true, release_at) == 2, "releasing between links must commit exactly the strikes the live window covered")

func test_hold_duration_is_monotonic() -> void:
	# The whole point of the grammar: longer holds buy more strikes, and never fewer.
	var probe := fresh_state()
	probe.request_combo(Vector2.UP, false, true)
	var total: float = float(probe.player_action.get("duration", 2.5))
	var previous := 0
	var step := 0.05
	var at := 0.0
	while at <= total:
		var state := fresh_state()
		var reached := run_combo(state, true, at)
		check(reached >= previous, "strike count fell from %d to %d when the hold lengthened to %.2fs" % [previous, reached, at])
		previous = maxi(previous, reached)
		at += step
	check(previous == 3, "the longest hold must still reach three strikes")

func test_knife_sequence_follows_the_same_rule() -> void:
	var tapped := fresh_state("rogue_acrobat")
	check(run_combo(tapped, false, -1.0) == 1, "a Knife tap must commit exactly one cut")
	var held := fresh_state("rogue_acrobat")
	check(run_combo(held, true, -1.0) == 4, "a sustained Knife hold must complete its four-cut sequence")

func test_retouch_resumes_after_release() -> void:
	var state := fresh_state()
	state.request_combo(Vector2.UP, false, false)
	var first_link: float = link_points(state)[0]
	while float(state.player_action.get("elapsed", 0.0)) < first_link - 0.08:
		if not state.advance_streamed_action_tick(): break
	check(state.resume_combo_hold(), "a renewed touch before the link must restore a live input")
	var reached := strikes_committed(state)
	while state.advance_streamed_action_tick():
		reached = maxi(reached, strikes_committed(state))
	check(reached >= 2, "a resumed input must continue the sequence, got %d strikes" % reached)

func test_input_after_terminal_lock_cannot_reopen() -> void:
	var state := fresh_state()
	state.request_combo(Vector2.UP, false, false)
	# Run past the first link with no live input; terminal recovery locks in.
	var first_link: float = link_points(state)[0]
	while float(state.player_action.get("elapsed", 0.0)) <= first_link + 0.05:
		if not state.advance_streamed_action_tick(): break
	check(bool(state.player_action.get("terminal_recovery_locked", false)), "terminal recovery must lock when no input is live at the link")
	check(not state.resume_combo_hold(), "input after terminal lock must not reopen the sequence")

func test_recovery_profile_shares_the_grammar() -> void:
	# Physical attack commitment is shared across profiles; only the resource
	# model differs. A tap must mean one strike under Recovery rules too.
	var tapped := fresh_state("warrior", "recovery")
	check(run_combo(tapped, false, -1.0) == 1, "a tap under Recovery rules must commit exactly one strike")
	var held := fresh_state("warrior", "recovery")
	check(run_combo(held, true, -1.0) == 3, "a sustained hold under Recovery rules must complete the sequence")

func test_board_quick_tap_commits_one_strike() -> void:
	# The actual regression. `_handle_gesture` runs from inside `_pointer_released`,
	# so the finger is already up and nothing will ever clear a seeded hold.
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.state.start_run("warrior", "combat_survey", 4242, "encounter", "energy")
	board.state.enemies.clear()
	var enemy: Dictionary = board.state._make_enemy("blade", board.state.player_pos + Vector2.RIGHT * 70.0, 7, 0)
	board.state.enemies.assign([enemy])
	board.visual = board.state.snapshot(true)
	board.size = Vector2(1280, 800)
	board._create_seed_input()
	board._layout()
	var enemy_point: Vector2 = board._world_to_screen(Vector2(enemy["pos"]))
	board._pointer_pressed(enemy_point)
	board._pointer_released(enemy_point)
	check(String(board.state.player_action.get("kind", "")) == "combo", "a tap on a reachable enemy must begin a combo")
	check(not bool(board.state.player_action.get("continue_held", true)), "a tap must not leave a live input behind it")
	var reached := 0
	while board.state.advance_streamed_action_tick():
		reached = maxi(reached, int(board.state.player_action.get("committed_phase", -1)) + 1)
	check(reached == 1, "a quick tap must commit exactly one strike, got %d" % reached)
	board.free()

func _init() -> void:
	test_tap_commits_exactly_one_strike()
	test_sustained_hold_completes_the_sequence()
	test_release_before_first_link_yields_one_strike()
	test_release_between_links_yields_two_strikes()
	test_hold_duration_is_monotonic()
	test_knife_sequence_follows_the_same_rule()
	test_retouch_resumes_after_release()
	test_input_after_terminal_lock_cannot_reopen()
	test_recovery_profile_shares_the_grammar()
	test_board_quick_tap_commits_one_strike()
	if failures.is_empty():
		print("Combo continuation tests passed.")
		quit(0)
		return
	for failure in failures:
		printerr("FAILED: %s" % failure)
	printerr("Combo continuation tests failed: %d" % failures.size())
	quit(1)
