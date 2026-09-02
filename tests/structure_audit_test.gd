extends SceneTree

const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")
const AbilityCatalogScript = preload("res://scripts/core/ability_catalog.gd")
const SurveyCounterCatalogScript = preload("res://scripts/core/survey_counter_catalog.gd")
const StateFieldSchemaScript = preload("res://scripts/core/state_field_schema.gd")
const SaveMigrationsScript = preload("res://scripts/core/save_migrations.gd")
const RuntimeSchemaScript = preload("res://scripts/core/runtime_schema.gd")
const PresentationFrameScript = preload("res://scripts/presentation/presentation_frame.gd")
const RunStateScript = preload("res://scripts/core/run_state.gd")

const IMPLEMENTED_ENEMY_AI := [
	"air_caster", "archer", "bandit", "blade", "boar", "brute", "chanter",
	"duellist", "earth_caster", "fire_caster", "hound", "ice_caster",
	"javelineer", "knife", "knight", "ox", "polearm", "shield", "warden",
	"werewolf",
]

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func test_enemy_catalog_is_complete() -> void:
	for error in CombatCatalogScript.validate_catalog(): failures.append(String(error))
	var registered_ai: Array[String] = []
	for kind in CombatCatalogScript.enemy_kinds():
		var profile := CombatCatalogScript.archetype(kind)
		var ai_id := String(profile.get("ai_id", ""))
		registered_ai.append(ai_id)
		check(ai_id in IMPLEMENTED_ENEMY_AI, "%s names unimplemented AI %s" % [kind, ai_id])
	registered_ai.sort()
	var expected := IMPLEMENTED_ENEMY_AI.duplicate()
	expected.sort()
	check(registered_ai == expected, "the archetype-to-AI registration differs from the implemented branch set")
	for error in AbilityCatalogScript.validate_catalog(): failures.append(String(error))
	for error in SurveyCounterCatalogScript.validate(): failures.append(String(error))
	for error in StateFieldSchemaScript.validate(): failures.append(String(error))
	for error in RuntimeSchemaScript.validate_registry(): failures.append(String(error))
	var state: RunState = RunStateScript.new(false)
	for audience in [StateFieldSchemaScript.SNAPSHOT, StateFieldSchemaScript.PRESENTATION, StateFieldSchemaScript.SAVE, StateFieldSchemaScript.DETERMINISM]:
		var captured := StateFieldSchemaScript.capture(state, audience)
		for descriptor in StateFieldSchemaScript.descriptors_for(audience):
			check(captured.has(String(descriptor["key"])), "%s field %s was not captured" % [audience, descriptor["key"]])
	var current_payload := state._build_save_payload()
	for error in SaveMigrationsScript.validate_current(current_payload, state.SAVE_VERSION): failures.append(String(error))
	var legacy_payload := current_payload.duplicate(true)
	legacy_payload["save_version"] = 33
	legacy_payload.erase("cooldowns")
	var migrated := SaveMigrationsScript.normalize(legacy_payload, state.SAVE_VERSION)
	check(int(migrated.get("save_version", -1)) == state.SAVE_VERSION, "v33 save did not migrate sequentially to current")
	check(migrated.has("cooldowns"), "v33 save migration did not construct cooldown slots")
	for hostile_kind in ["hurl", "sunder", "slam"]:
		check(hostile_kind in AbilityCatalogScript.ENEMY_ATTACK_ACTION_KINDS, "%s is missing from hostile-action telemetry" % hostile_kind)
	for retired_kind in ["hex", "ice_hex", "ice_cone", "fire_circle"]:
		check(not AbilityCatalogScript.ACTION_EXECUTORS.has(retired_kind) and not AbilityCatalogScript.HAZARD_EXECUTORS.has(retired_kind), "retired ability %s is still registered" % retired_kind)

func test_every_survey_recipe_kind_is_registered() -> void:
	var state: RunState = RunStateScript.new(false)
	for recipe_value in state._survey_recipe_catalog():
		for entry_value in Array(Dictionary(recipe_value).get("enemies", [])):
			var kind := String(Dictionary(entry_value).get("kind", ""))
			check(CombatCatalogScript.has_archetype(kind), "survey recipe names unknown enemy %s" % kind)

func test_catalog_vision_is_the_perception_authority() -> void:
	var state: RunState = RunStateScript.new(false)
	state.walls.clear()
	state._build_wall_spatial_index()
	state.player_attributes["stealth"] = 0
	var chanter := state._make_enemy("chanter", state.player_pos + Vector2.UP * 570.0, 30)
	chanter["facing"] = Vector2.DOWN
	check(is_equal_approx(state._enemy_vision_range(chanter), 620.0), "Chanter did not receive its authored 620 vision")
	check(state._enemy_has_eyes_on_player(chanter), "Chanter still behaves as if its vision were the 520 fallback")
	for kind in CombatCatalogScript.enemy_kinds():
		var enemy := state._make_enemy(kind, state.player_pos + Vector2.UP * 200.0, 30)
		var authored := float(Dictionary(CombatCatalogScript.archetype(kind)["properties"]).get("vision_range", state.SIGHT_RANGE))
		check(is_equal_approx(state._enemy_vision_range(enemy), authored), "%s perception drifted from the catalog" % kind)

func test_actor_boundary_owns_identity_and_factions() -> void:
	var state: RunState = RunStateScript.new(false)
	var enemy := state._make_enemy("blade", Vector2(100.0, 100.0), 30)
	for error in RuntimeSchemaScript.validate("actor", enemy): failures.append(String(error))
	for error in RuntimeSchemaScript.validate("action", Dictionary(enemy["action"])): failures.append(String(error))
	state._add_enemy_actor(enemy)
	check(String(state.actor_view(0).get("faction", "")) == "player", "player actor view lost its faction")
	check(String(state.actor_view(enemy).get("faction", "")) == "enemy", "enemy actor view lost its faction")
	check(state._opposes(0, enemy), "player and enemy should oppose one another")
	check(not state._opposes(enemy, enemy), "an actor should not oppose its own faction")
	var before := int(enemy["hp"])
	state._change_actor_hp(enemy, -4)
	check(int(enemy["hp"]) == before - 4, "shared actor HP mutation changed the damage result")

func test_dynamic_presentation_uses_stable_ids() -> void:
	var state: RunState = RunStateScript.new(false)
	state.enemies.clear()
	var enemy := state._make_enemy("chanter", state.player_pos + Vector2.UP * 100.0, 30)
	enemy["conditions"] = {"burning": 2.0, "frost": 1.0}
	enemy["condition_buildup"] = {"frost": 3.0}
	enemy["chants"] = {"haste": 2.5}
	enemy["chant_source_id"] = int(enemy["id"])
	enemy["action"] = state._action("hit_reaction", 0.5, Vector2.ZERO)
	enemy["action"]["interrupted_action"] = {"kind":"chant", "label":"haste"}
	state.enemies = [enemy]
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	state.player_conditions = {"burning": 1.0}
	state.player_condition_buildup = {"frost": 2.0}
	state.player_exhaustion_remaining = 0.5
	state.aimed_enemy_id = int(enemy["id"])
	state.visible_cells = {Vector2i(1, 1):true}
	state.discovered_cells = {Vector2i(1, 1):true}
	state.visibility_revision += 1
	state.discovery_revision += 1
	state._add_barrier({"pos":Vector2.ZERO, "axis":Vector2.RIGHT, "half_length":10.0, "thickness":2.0, "hp":1.0, "source_id":0, "layer":state.current_layer})
	state._add_projectile({"kind":"arrow", "pos":state.player_pos, "vel":Vector2.RIGHT, "radius":4.0, "damage":1, "source_id":int(enemy["id"]), "friendly":false, "layer":state.current_layer, "elevation":12.0, "elevation_profile":"arc", "misdirected":true})
	var current = PresentationFrameScript.new()
	var following = PresentationFrameScript.new()
	current.capture(state)
	following.capture(state)
	var captured_enemy := Dictionary(Array(current.data["enemies"])[0])
	check(Dictionary(captured_enemy.get("conditions", {})).has("burning"), "streamed enemy lost conditions")
	check(Dictionary(captured_enemy.get("chants", {})).has("haste"), "streamed enemy lost chant identity")
	check(String(Dictionary(Dictionary(captured_enemy["action"]).get("interrupted_action", {})).get("kind", "")) == "chant", "streamed enemy lost nested interrupted action")
	check(Dictionary(current.data.get("player_conditions", {})).has("burning") and is_equal_approx(float(current.data.get("player_exhaustion_remaining", 0.0)), 0.5), "streamed top-level combat state is incomplete")
	var carried_projectile := Dictionary(Array(current.data["projectiles"])[0])
	check(bool(carried_projectile.get("misdirected", false)) and is_equal_approx(float(carried_projectile.get("elevation", 0.0)), 12.0), "world schema did not carry misdirection and elevation")
	state.visible_cells.clear()
	check(not Dictionary(current.data["visible_cells"]).is_empty(), "presentation frame aliases the live visibility dictionary")
	current.data["projectiles"] = [
		{"presentation_id":1, "pos":Vector2.ZERO},
		{"presentation_id":2, "pos":Vector2(100.0, 0.0)},
	]
	following.data["projectiles"] = [
		{"presentation_id":2, "pos":Vector2(200.0, 0.0)},
		{"presentation_id":3, "pos":Vector2(300.0, 0.0)},
	]
	var blended = PresentationFrameScript.new()
	var visual := blended.blend(current, following, 0.75)
	var projectiles: Array = visual["projectiles"]
	check(projectiles.size() == 2, "presentation blend did not add/remove entities by stable ID")
	check(int(Dictionary(projectiles[0]).get("presentation_id", -1)) == 2, "presentation blend paired a projectile by array index")
	check(Vector2(Dictionary(projectiles[0])["pos"]).is_equal_approx(Vector2(175.0, 0.0)), "stable projectile did not interpolate with its own ID")
	check(Array(visual.get("barriers", [])).size() == 1, "barriers are absent from the streamed presentation frame")

func _init() -> void:
	test_enemy_catalog_is_complete()
	test_every_survey_recipe_kind_is_registered()
	test_catalog_vision_is_the_perception_authority()
	test_actor_boundary_owns_identity_and_factions()
	test_dynamic_presentation_uses_stable_ids()
	if failures.is_empty():
		print("Structure audit tests passed.")
		quit(0)
	else:
		for failure in failures: print("FAILED: %s" % failure)
		print("Structure audit tests failed: %d" % failures.size())
		quit(1)
