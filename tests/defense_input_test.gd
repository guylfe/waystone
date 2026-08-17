extends SceneTree

# A selected Defense must own the next tap.
#
# Reported from the 0.2.15 survey: "I tried to dodge into my enemy and it tried
# to strike him instead even though he was very far away, and then the next click
# was a dodge." Tapping an enemy with Dodge already selected fell through to the
# attack branch, which both discarded the chosen Defense and skipped the
# plausibility check that normally stops a swing at an out-of-reach target.
#
# This matters more than an ordinary input slip: it silently spends the decision
# the player made at the frozen decision point, which is the one thing the whole
# combat model promises to honour.

const RunStateScript = preload("res://scripts/core/run_state.gd")
const GameBoardScript = preload("res://scripts/presentation/game_board.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func board_with_enemy(distance: float):
	var board = GameBoardScript.new()
	board.state = RunStateScript.new(false)
	board.state.start_run("warrior", "combat_survey", 4242, "encounter", "stamina")
	board.state.enemies.clear()
	board.state.walls.clear()
	var enemy: Dictionary = board.state._make_enemy("blade", board.state.player_pos + Vector2.RIGHT * distance, 30, 0)
	board.state.enemies.assign([enemy])
	board.visual = board.state.snapshot(true)
	board.size = Vector2(1280, 800)
	board._create_seed_input()
	board._layout()
	return board

func tap(board, world_point: Vector2) -> void:
	var screen: Vector2 = board._world_to_screen(world_point)
	board._pointer_pressed(screen)
	board._pointer_released(screen)

func test_tapping_an_enemy_with_dodge_selected_dodges() -> void:
	var board = board_with_enemy(90.0)
	board.selected_action = "defense"
	tap(board, Vector2(board.state.enemies[0]["pos"]))
	check(String(board.state.player_action.get("kind", "")) == "dodge",
		"a tap on an enemy with Defense selected must Dodge, got %s" % board.state.player_action.get("kind", ""))
	check(board.selected_action == "", "the selection must be consumed")
	board.free()

func test_it_holds_for_a_distant_enemy_too() -> void:
	# The reported case: the enemy was far away, and the tap still became an attack.
	var board = board_with_enemy(300.0)
	board.selected_action = "defense"
	tap(board, Vector2(board.state.enemies[0]["pos"]))
	check(String(board.state.player_action.get("kind", "")) == "dodge",
		"distance must not turn a chosen Dodge into a swing, got %s" % board.state.player_action.get("kind", ""))
	board.free()

func test_the_dodge_aims_at_the_tapped_enemy() -> void:
	# Tapping aims the Dodge the same way dragging does, rather than picking a
	# default direction the player did not choose.
	var board = board_with_enemy(90.0)
	board.selected_action = "defense"
	var enemy_pos := Vector2(board.state.enemies[0]["pos"])
	var expected: Vector2 = (enemy_pos - Vector2(board.state.player_pos)).normalized()
	tap(board, enemy_pos)
	var actual := Vector2(board.state.player_action.get("direction", Vector2.ZERO)).normalized()
	check(actual.dot(expected) > 0.9, "the Dodge must travel toward the tapped enemy")
	board.free()

func test_an_unselected_tap_still_attacks() -> void:
	# The fix must not swallow ordinary attacks: with nothing selected, tapping a
	# reachable enemy still commits a strike.
	var board = board_with_enemy(90.0)
	board.selected_action = ""
	tap(board, Vector2(board.state.enemies[0]["pos"]))
	check(String(board.state.player_action.get("kind", "")) == "combo",
		"an ordinary enemy tap must still attack, got %s" % board.state.player_action.get("kind", ""))
	board.free()

func test_other_selected_actions_are_unaffected() -> void:
	var board = board_with_enemy(90.0)
	board.selected_action = "skill"
	tap(board, Vector2(board.state.enemies[0]["pos"]))
	check(String(board.state.player_action.get("kind", "")) != "combo",
		"a selected skill must not become an ordinary attack either")
	board.free()

func _init() -> void:
	test_tapping_an_enemy_with_dodge_selected_dodges()
	test_it_holds_for_a_distant_enemy_too()
	test_the_dodge_aims_at_the_tapped_enemy()
	test_an_unselected_tap_still_attacks()
	test_other_selected_actions_are_unaffected()
	if failures.is_empty():
		print("Defense input tests passed.")
		quit(0)
		return
	for failure in failures:
		printerr("FAILED: %s" % failure)
	printerr("Defense input tests failed: %d" % failures.size())
	quit(1)
