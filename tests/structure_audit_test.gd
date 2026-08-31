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
	for audience in [StateFieldSchemaScript.SNAPSHOT, StateFieldSchemaScript.PRESENTATION, StateFieldSchemaScript.SAVE]:
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

func test_every_survey_recipe_kind_is_registered() -> void:
	var state: RunState = RunStateScript.new(false)
	for recipe_value in state._survey_recipe_catalog():
		for entry_value in Array(Dictionary(recipe_value).get("enemies", [])):
			var kind := String(Dictionary(entry_value).get("kind", ""))
			check(CombatCatalogScript.has_archetype(kind), "survey recipe names unknown enemy %s" % kind)

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
	state._add_barrier({"pos":Vector2.ZERO, "axis":Vector2.RIGHT, "half_length":10.0, "thickness":2.0, "hp":1.0, "source_id":0, "layer":state.current_layer})
	var current = PresentationFrameScript.new()
	var following = PresentationFrameScript.new()
	current.capture(state)
	following.capture(state)
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
	test_actor_boundary_owns_identity_and_factions()
	test_dynamic_presentation_uses_stable_ids()
	if failures.is_empty():
		print("Structure audit tests passed.")
		quit(0)
	else:
		for failure in failures: print("FAILED: %s" % failure)
		print("Structure audit tests failed: %d" % failures.size())
		quit(1)
