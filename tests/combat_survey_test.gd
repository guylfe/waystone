extends SceneTree

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _init() -> void:
	var first = RunStateScript.new(false)
	first.start_run("warrior", "combat_survey", 424242, "encounter", "recovery")
	first.record_survey_view_mode("isometric", false)
	first.record_survey_view_mode("top_down", true)
	var second = RunStateScript.new(false)
	second.start_run("warrior", "combat_survey", 424242, "encounter", "stamina")
	assert(first.survey_room_seed == second.survey_room_seed)
	assert(first.survey_room_definition == second.survey_room_definition)
	var acrobat = RunStateScript.new(false)
	acrobat.start_run("rogue_acrobat", "combat_survey", 424242, "encounter")
	var sharpshooter = RunStateScript.new(false)
	sharpshooter.start_run("rogue_sharpshooter", "combat_survey", 424242, "encounter")
	assert(first.survey_room_definition == acrobat.survey_room_definition)
	assert(first.survey_room_definition == sharpshooter.survey_room_definition)
	assert(first.enemies.size() > 0 and first.enemies.size() <= 6)
	assert(first.current_layer == "survey_arena")
	assert(first.survey_room_number == 1)
	for enemy in first.enemies:
		var opening_offset: Vector2 = Vector2(enemy["pos"]) - first.player_pos
		assert(opening_offset.length() >= 359.9)
		assert(Vector2(enemy["facing"]).dot(opening_offset.normalized()) > 0.99)
		assert(String(enemy["awareness"]) == "idle")
	var first_seed: int = first.survey_room_seed
	first._annotate_player_action("test_ability")
	for enemy in first.enemies: enemy["hp"] = 0
	first._remove_dead_enemies()
	assert(first.survey_feedback_pending)
	assert(String(first.survey_pending_record["outcome"]) == "victory")
	assert(Array(first.survey_pending_record["view_modes"]) == ["isometric", "top_down"])
	assert(int(first.survey_pending_record["view_switches"]) == 1)
	assert(int(first.survey_pending_record["entry_hp"]) == first.player_max_hp)
	assert(int(first.survey_pending_record["entry_stamina"]) == int(first.player_max_stamina))
	assert(int(Dictionary(first.survey_pending_record["action_usage"]).get("test_ability", 0)) == 1)
	var ratings := {"difficulty": 3, "fun": 4, "tactical_interest": 4, "want_again": 4}
	first.submit_survey_feedback(ratings, ["fair", "good mix"], "Deterministic survey smoke test.")
	assert(not first.survey_feedback_pending)
	assert(first.survey_room_number == 2)
	assert(first.survey_room_seed != first_seed)
	assert(first.player_hp == first.player_max_hp)
	assert(is_equal_approx(first.player_stamina, first.player_max_stamina))
	assert(Array(first.survey_session["rooms"]).size() == 1)
	first.end_survey_run()
	assert(first.survey_feedback_pending)
	first.submit_survey_feedback(ratings, [], "Stopped after verifying room two.")
	assert(first.trial_complete)
	assert(Array(first.survey_session["rooms"]).size() == 2)
	var report := first.survey_report_text()
	assert("RUN SEED" not in report or "Run seed: 424242" in report)
	assert("ROOM 1" in report and "ROOM 2" in report)
	assert("Room seed:" in report and "Tags: fair, good mix" in report)
	assert("Want a room like this again: 4/5" in report)
	assert("Health:" in report and "Stamina:" in report and "Exhaustion lockouts:" in report and "Action usage:" in report)
	assert("Stamina depleted:" in report and "Stamina overdraw:" in report and "Strike diagnostics:" in report)
	assert("Report format: 8" in report and "Presentation version: 5" in report and "Combat rules: Recovery" in report)
	assert("Fairness:" not in report and "Stamina regeneration delay:" in report)
	assert("Pacing:" in report and "Recipe:" in report and "Roles:" in report)
	assert("Presentation version:" in report and "View: isometric + top_down" in report and "View switches: 1" in report)

	var director = RunStateScript.new(false)
	director.start_run("rogue_acrobat", "combat_survey", 7777333, "encounter")
	var previous_recipe := ""
	var previous_family := ""
	var expected_phases := ["opening", "development", "contrast", "pressure", "climax", "respite"]
	for room_index in range(12):
		var definition: Dictionary = director.survey_room_definition
		var recipe_id := String(definition["recipe_id"])
		var family := String(definition["recipe_family"])
		assert(String(definition["pacing_phase"]) == String(expected_phases[room_index % expected_phases.size()]))
		assert(not recipe_id.is_empty() and recipe_id != "unknown")
		assert(int(definition["composition_cost"]) > 0)
		assert(int(definition["ranged_pressure_count"]) <= 2)
		assert(Array(definition["enemy_roles"]).size() == director.enemies.size())
		if not previous_recipe.is_empty(): assert(recipe_id != previous_recipe)
		if not previous_family.is_empty(): assert(family != previous_family)
		for enemy in director.enemies:
			var offset: Vector2 = Vector2(enemy["pos"]) - director.player_pos
			assert(offset.length() >= 359.9)
			assert(Vector2(enemy["facing"]).dot(offset.normalized()) > 0.99)
			assert(String(enemy["awareness"]) == "idle")
		previous_recipe = recipe_id
		previous_family = family
		for enemy in director.enemies: enemy["hp"] = 0
		director._remove_dead_enemies()
		director.submit_survey_feedback(ratings, [], "Director regression room.")

	var attrition = RunStateScript.new(false)
	attrition.start_run("warrior", "combat_survey", 515151, "attrition")
	attrition.carried_xp = attrition.next_upgrade_cost()
	assert(attrition.level_up_context() == "survey")
	assert(attrition.can_open_level_sheet())
	assert(attrition.available_level_up_options().has("evasion"))
	var attrition_choice := "evasion"
	assert(attrition.choose_upgrade(attrition_choice))
	assert(attrition.upgrade_count == 1 and attrition.carried_xp == 0)
	var encounter = RunStateScript.new(false)
	encounter.start_run("warrior", "combat_survey", 616161, "encounter")
	encounter.carried_xp = encounter.next_upgrade_cost()
	assert(encounter.level_up_context() == "survey")
	assert(encounter.can_open_level_sheet())
	for enemy in encounter.enemies: enemy["hp"] = 0
	encounter._remove_dead_enemies()
	encounter.skip_survey_feedback("Too brief to judge.")
	var skipped := Dictionary(Array(encounter.survey_session["rooms"])[0])
	assert(bool(skipped["subjective_skipped"]))
	assert(Dictionary(skipped["ratings"]).is_empty())
	print("COMBAT SURVEY deterministic rooms, feedback, archive, and report: PASS")
	quit(0)
