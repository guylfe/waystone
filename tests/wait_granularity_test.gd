extends SceneTree

# The Wait rework, shipped with attack capture.
#
# Wait had the walking defect in miniature: at a hardcoded 0.5s it was about four
# movement steps long, so a player who wanted to pass a little time was better off
# pacing back and forth. Two steps cost 0.26s and yield position; one Wait cost
# 0.5s and yielded nothing. The action built for spending time was the worst way
# to spend it.
#
# It is deliberately unassisted. Wait is movement without the repositioning and
# takes movement's rules exactly, including its risks: no auto-break, no event
# guardrails. A guardrail on Wait alone would make standing still safer than
# repositioning, which inverts the risk relationship -- and standing still is the
# more dangerous choice now that attacks advance.

const RunStateScript = preload("res://scripts/core/run_state.gd")
const GameBoardScript = preload("res://scripts/presentation/game_board.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func fresh_state(loadout: String = "warrior") -> RunState:
	var state: RunState = RunStateScript.new(false)
	state.start_run(loadout, "combat_survey", 4242, "encounter", "energy")
	state.enemies.clear()
	state.walls.clear()
	return state

func test_wait_unit_is_derived_from_a_movement_step() -> void:
	for loadout in ["warrior", "rogue_acrobat", "rogue_sharpshooter"]:
		var state := fresh_state(loadout)
		var expected := state.MOVE_RANGE / state.player_move_speed
		check(is_equal_approx(state.wait_unit_duration(), expected),
			"%s wait unit %.4f should equal MOVE_RANGE / speed %.4f" % [loadout, state.wait_unit_duration(), expected])
		# A fixed constant would silently drift finer or coarser than movement as
		# speeds are retuned; this is the property that prevents that.
		check(state.wait_unit_duration() < 0.5,
			"%s wait unit must be far below the old hardcoded 0.5s" % loadout)

func test_unset_request_resolves_to_one_unit() -> void:
	var state := fresh_state()
	var unit := state.wait_unit_duration()
	check(state.request_wait(-1.0, false), "an unset Wait must be accepted")
	check(is_equal_approx(float(state.player_action["duration"]), unit),
		"an unset Wait must resolve to one unit, got %.4f" % float(state.player_action["duration"]))

func test_wait_and_move_share_granularity() -> void:
	# The whole point: waiting in place is never coarser than pacing in place.
	var waited := fresh_state()
	waited.request_wait(-1.0, false)
	while waited.advance_streamed_action_tick(): pass
	var wait_time := waited.simulation_time

	var moved := fresh_state()
	moved.request_move(Vector2.UP, moved.MOVE_RANGE, false)
	while moved.advance_streamed_action_tick(): pass
	var move_time := moved.simulation_time

	check(absf(wait_time - move_time) < 0.01,
		"one Wait unit (%.3fs) and one movement step (%.3fs) must advance the same world time" % [wait_time, move_time])

func test_held_wait_chains_units() -> void:
	var state := fresh_state()
	var unit := state.wait_unit_duration()
	var units := 5
	for _i in range(units):
		check(state.request_wait(-1.0, false), "each held repeat must commit another unit")
		while state.advance_streamed_action_tick(): pass
	check(absf(state.simulation_time - unit * float(units)) < 0.02,
		"%d chained units should advance %.3fs, advanced %.3fs" % [units, unit * float(units), state.simulation_time])
	# Each unit is a discrete commitment, so time freezes between them.
	check(state.is_player_ready(), "a completed unit must return to a frozen decision point")

func test_held_wait_has_no_event_guardrails() -> void:
	# An enemy winding up a reaching attack mid-chain must not end the chain for
	# the player. Judging when to release under pressure is the skill Wait tests.
	var state := fresh_state()
	var enemy := state._make_enemy("knight", state.player_pos + Vector2.RIGHT * 240.0, 999, 4)
	enemy["awareness"] = "alerted"
	state.enemies.assign([enemy])
	var committed := 0
	for _i in range(6):
		if not state.request_wait(-1.0, false): break
		committed += 1
		while state.advance_streamed_action_tick(): pass
	check(committed == 6, "a committing enemy must not break a wait chain, got %d of 6 units" % committed)

func test_being_hit_ends_the_chain_through_the_shared_path() -> void:
	# Not a Wait-specific rule: a hit reaction replaces the current action like any
	# other interruption, and nothing suppresses that either.
	var state := fresh_state()
	state.request_wait(-1.0, false)
	state._resolve_incoming_hit(-1, 2, "blade", state.player_pos + Vector2.RIGHT * 60.0, state.player_pos)
	check(String(state.player_action.get("kind", "")) == "hit_reaction",
		"being hit mid-wait must replace the action through the ordinary interruption path")

func test_hold_does_not_repeat_a_context_action() -> void:
	# The button becomes REST, TAKE and shortcut interactions. The press is already
	# guarded; the hole was the repeat, which never re-checked the label.
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.state.start_run("warrior", "combat_survey", 919191, "encounter", "energy")
	board.state.enemies.clear()
	board.visual = board.state.snapshot(true)
	board.size = Vector2(1280, 800)
	board._create_seed_input()
	board._layout()
	board._pointer_pressed(board.interaction_rect.get_center())
	check(board.wait_pointer_held, "pressing the button while the label is WAIT must begin a chain")
	check(String(board.state.interaction_label()) == "WAIT", "setup expects the label to start as WAIT")
	for _frame in range(6): board._process(0.05)
	check(board.state.direct_attack_uses_total == 0, "holding Wait must not fire unrelated actions")
	board.free()

func _init() -> void:
	test_wait_unit_is_derived_from_a_movement_step()
	test_unset_request_resolves_to_one_unit()
	test_wait_and_move_share_granularity()
	test_held_wait_chains_units()
	test_held_wait_has_no_event_guardrails()
	test_being_hit_ends_the_chain_through_the_shared_path()
	test_hold_does_not_repeat_a_context_action()
	if failures.is_empty():
		print("Wait granularity tests passed.")
		quit(0)
		return
	for failure in failures:
		printerr("FAILED: %s" % failure)
	printerr("Wait granularity tests failed: %d" % failures.size())
	quit(1)
