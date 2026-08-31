extends SceneTree

# Mage · Elementalist. The first class built on the shared caster systems, and the
# falsification target for the claim those systems were built on: that an element earns
# its identity by taxing a different currency, and that the spellbook is the bestiary.

const RunStateScript = preload("res://scripts/core/run_state.gd")
const CombatCatalogScript = preload("res://scripts/core/combat_catalog.gd")
const AttackGeometryScript = preload("res://scripts/core/attack_geometry.gd")

var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	if not condition: failures.append(description)

func fresh() -> RunState:
	var state: RunState = RunStateScript.new()
	state.start_run("mage_elementalist", "combat_survey", 8811, "encounter", "energy")
	state.carried_xp = 9999
	state.walls.clear()
	state.barriers.clear()
	state.enemies.clear()
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	return state

func _init() -> void:
	test_the_sheet_and_its_gates()
	test_the_bolt_is_what_you_start_with()
	test_intelligence_prices_spells_and_therefore_cooldowns()
	test_the_circle_is_ground_you_have_to_hold()
	test_every_element_is_a_permanent_fork()
	test_the_staff_is_reach_and_ground_not_damage()
	test_steadier_cast_holds_against_a_light_hit()
	if failures.is_empty():
		print("MAGE ELEMENTALIST sheet, spells, circle and staff: PASS")
		# quit() requests a quit, it does not return -- so the explicit return is what stops
		# execution running on to quit(1) below and reporting failure while printing PASS.
		# That is the exact shape of the bug run-tests.ps1 was taught to catch in 0.2.35,
		# and it caught this one.
		quit(0)
		return
	for failure in failures: print("FAILED: %s" % failure)
	quit(1)

func test_the_sheet_and_its_gates() -> void:
	var state := fresh()
	check(String(state.character_sheet_data()["name"]) == "Mage · Elementalist", "the sheet should name the class")
	check(state.character_track_order() == ["staff", "evasion", "measured", "mage", "elementalist", "adopted"], "five tracks plus the late one")
	# Weapon, Defense and Temperament at 2; Main Class at 3; Subclass at 4. The cadence is
	# shared with every other class, and only the content is authored per track.
	check(state.available_level_up_options() == ["staff", "evasion", "measured"], "level 2 offers weapon, defense and temperament")
	# Weapon tracks must contain exactly five ranks or cross-category proficiency transfer,
	# which grants `highest existing - 1`, has nothing consistent to subtract from.
	check(Array(CombatCatalogScript.character_track("staff")["stages"]).size() == 5, "every weapon track has exactly five ranks")
	# Defense is reused rather than authored fresh. The argument against a mana bar is that
	# casting competes with dodging, so the caster has to actually be dodging.
	check(String(state.defense_id) == "dodge", "the Mage dodges like everyone else")

func test_the_bolt_is_what_you_start_with() -> void:
	var state := fresh()
	# A character starts with a complete loop. A one-of-two at level 1 is not a choice --
	# there is no play behind it to choose on -- so the bolt is given rather than picked,
	# and the forks begin at the first element.
	check(state.player_spells == ["lightning_bolt"], "the Elementalist opens holding the bolt and nothing else")
	check(state.knows_spell("lightning_bolt"), "and it is castable immediately")
	# It is deliberately the only ability in the game with no enemy behind it: raw force
	# before it has been shaped into an element, which is why it carries no condition.
	check(not state.CONDITION_BUILDUP_BY_SOURCE.has("lightning_bolt"), "the bolt kindles and freezes nothing")
	# An instant line rather than a travelling shot, so it shares geometry with neither
	# Fire ability and cannot be evaded mid-flight, because there is no flight.
	var target := state._make_enemy("blade", state.player_pos + Vector2.UP * 220.0, 35)
	state.enemies = [target]
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	var before := int(target["hp"])
	state.projectiles.clear()
	state.request_spell("lightning_bolt", state.player_pos + Vector2.UP * 400.0)
	check(state.projectiles.is_empty(), "the bolt should spawn no projectile")
	check(int(target["hp"]) < before, "the bolt should have struck the first thing in the line")

func test_intelligence_prices_spells_and_therefore_cooldowns() -> void:
	var state := fresh()
	var base := state.spell_energy_cost("lightning_bolt")
	var base_cooldown := state._cooldown_for(base)
	state._apply_character_stage("learned", "")
	var learned := state.spell_energy_cost("lightning_bolt")
	check(learned < base, "Intelligence should reduce what a spell costs")
	# The whole elegance of the choice: a cooldown is `spend / pool x 24`, so cutting the
	# cost cuts the cooldown by the same proportion. One stat, one effect, and it means the
	# same thing under Energy rules and Recovery rules without a second rule for either.
	check(state._cooldown_for(learned) < base_cooldown, "and therefore what it costs in time")
	# It must not discount swinging a stick. A stat that cheapens physical actions is a
	# stat every class wants, and then it is not the caster's stat at all.
	var physical := state.energy_cost(30.0)
	state.player_attributes["intelligence"] = 20
	check(is_equal_approx(state.energy_cost(30.0), physical), "Intelligence should not touch physical costs")

func test_the_circle_is_ground_you_have_to_hold() -> void:
	var state := fresh()
	var outside := state.spell_energy_cost("lightning_bolt")
	check(state.request_circle(), "the Circle should be castable")
	check(state.circle_remaining > 0.0, "and it should leave something on the ground")
	check(state.player_is_inside_circle(), "standing where you drew it")
	check(state.spell_energy_cost("lightning_bolt") < outside, "inside it, casting is cheaper")
	# 168 is exactly how far a Sidestep travels, and a Long Roll covers 231. From the
	# centre one evasion keeps the ground and the other gives it up, so the Evasion track's
	# permanent fork acquires a second meaning for a caster.
	check(is_equal_approx(state.circle_radius(), 168.0), "the Circle is a Sidestep across")
	state.player_pos = state.circle_pos + Vector2.RIGHT * 240.0
	check(not state.player_is_inside_circle(), "a Long Roll's distance puts you outside it")
	check(is_equal_approx(state.spell_energy_cost("lightning_bolt"), outside), "and the discount goes with it")
	# Wide Circle exists precisely to buy that back, which is why it is a specific
	# threshold rather than "bigger".
	state.track_choices["circle_mastery"] = "wide_circle"
	check(state.circle_radius() > 231.0, "Wide Circle should cover a Long Roll")

func test_every_element_is_a_permanent_fork() -> void:
	var state := fresh()
	for stage_id in ["element_fire", "element_ice", "element_earth", "element_air"]:
		var stage := CombatCatalogScript.character_stage("elementalist", ["element_fire", "element_ice", "element_earth", "element_air"].find(stage_id))
		check(Array(stage.get("choices", [])).size() == 2, "%s should offer both of its enemy abilities" % stage_id)
	# Learning is additive and ordered, and never longer than the row that displays it.
	state._apply_character_stage("element_fire", "fire_breath")
	state._apply_character_stage("element_ice", "cold_front")
	state._apply_character_stage("element_earth", "sunder")
	state._apply_character_stage("element_air", "windstep")
	check(state.player_spells.size() == 5, "the bolt plus one per element")
	check(state.knows_spell("fire_breath") and not state.knows_spell("fireball"), "the refused half stays refused")
	# ...but it still exists, because the enemy that taught it is still using it. That is
	# what "the spellbook is the bestiary" has to mean in the code and not only in prose.
	check(state.CONDITION_BUILDUP_BY_SOURCE.has("fireball"), "the half you did not take is still something the room can do to you")
	# Each spell resolves through the same spawner its enemy version calls.
	var state_two := fresh()
	state_two._apply_character_stage("element_earth", "earth_wall")
	state_two.barriers.clear()
	state_two.request_spell("earth_wall", state_two.player_pos + Vector2.UP * 200.0)
	check(state_two.barriers.size() == state_two.EARTH_WALL_SEGMENTS, "the player's wall is the caster's wall")

func test_the_staff_is_reach_and_ground_not_damage() -> void:
	var state := fresh()
	check(state.player_weapon_frame == "staff", "the Elementalist carries a staff")
	check(state.request_combo(Vector2.RIGHT, false), "and can actually use it")
	var phases := Array(state.player_action["phases"])
	check(phases.size() == 3, "thrust, sweep, overhead spin")
	# The reward for finishing is the ground the last hit covers, not a bigger number --
	# which is why the finisher is the multi-target technique and not the strongest one.
	check(String(Dictionary(phases[2])["technique"]) == "staff_spin", "the combo ends in the spin")
	check(bool(AttackGeometryScript.technique("staff_spin")["multi"]), "and the spin catches more than one body")
	check(int(Dictionary(phases[2])["damage_max"]) <= int(Dictionary(phases[0])["damage_max"]), "the finisher does not out-damage the opener")
	# Long Guard buys reach, because reach is the staff's whole case.
	var reach_before := float(Dictionary(phases[0])["reach"])
	state.track_ranks["staff"] = 2
	state.player_action = state._idle_action()
	state.request_combo(Vector2.RIGHT, false)
	check(float(Dictionary(Array(state.player_action["phases"])[0])["reach"]) > reach_before, "Long Guard should extend the staff")
	# The two Arts are a real fork: a full circle that buys room, and a long low sweep that
	# buys a beat. Neither is a better version of the other.
	var stage := CombatCatalogScript.character_stage("staff", 0)
	var art_ids: Array[String] = []
	for choice in Array(stage["choices"]): art_ids.append(String(Dictionary(choice)["id"]))
	check(art_ids == ["staff_whirlwind", "staff_leg_sweep"], "Whirlwind or Sweep the Legs")
	# Vault is an Acrobat ability. The staff frame used to name a second one, which would
	# have given a staff-carrying Acrobat two of them.
	check(not art_ids.has("staff_vault"), "the staff must not carry a second Vault")

func test_steadier_cast_holds_against_a_light_hit() -> void:
	var state := fresh()
	state.request_spell("lightning_bolt", state.player_pos + Vector2.UP * 300.0, false)
	check(String(state.player_action["kind"]) == "cast", "the cast should be in progress")
	state._resolve_incoming_hit(1, 10, "knife", Vector2.LEFT, state.player_pos)
	check(String(state.player_action["kind"]) != "cast", "without the node, a hit takes the spell")
	# A caster's real vulnerability is not that a hit hurts, it is that a hit erases what
	# they were doing. That is why this is the Mage track's first node.
	var steady := fresh()
	steady.track_ranks["mage"] = 1
	steady.request_spell("lightning_bolt", steady.player_pos + Vector2.UP * 300.0, false)
	steady._resolve_incoming_hit(1, 10, "knife", Vector2.LEFT, steady.player_pos)
	check(String(steady.player_action["kind"]) == "cast", "Steadier Cast should hold the working through a light hit")
	# It holds against a light blow only. A cleave still takes it, or the node would make
	# the frailest class in the game the hardest one to interrupt.
	steady._resolve_incoming_hit(1, 28, "knight", Vector2.LEFT, steady.player_pos, 6.0)
	check(String(steady.player_action["kind"]) != "cast", "a heavy blow should still break the working")
