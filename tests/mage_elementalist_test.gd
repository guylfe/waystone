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
	test_the_staff_arts_actually_commit()
	test_a_cone_hazard_tells_the_renderer_it_is_a_cone()
	test_a_player_cast_zone_hurts_enemies()
	test_a_spell_is_priced_once()
	test_world_time_advances_through_a_cast()
	test_a_wall_never_stands_up_without_warning()
	test_walking_into_an_unseen_body_reveals_it()
	test_a_wall_stops_the_side_that_did_not_raise_it()
	test_nothing_steps_off_the_floor()
	test_gale_shoves_with_momentum()
	test_a_repeating_zone_reports_one_number()
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

func test_the_staff_arts_actually_commit() -> void:
	# 0.2.62 authored both arts in the catalog and implemented neither, so choosing one
	# armed a button that did nothing and left time frozen. In a game where world time only
	# advances on commitment that is the worst possible failure mode: nothing at all tells
	# the player the commitment did not happen.
	for art in ["staff_whirlwind", "staff_leg_sweep"]:
		var state := fresh()
		state.player_equipped_weapon_art = String(art)
		check(state.request_skill(Vector2.RIGHT, false), "%s should commit" % art)
		check(String(state.player_action.get("technique_id", "")) == String(art), "%s should use its own geometry" % art)
		check(state.player_energy < state.player_max_energy, "%s should actually cost something" % art)
	# Sweep the Legs reaches further and breaks posture; Whirlwind covers the circle and
	# shoves. Neither is a better version of the other, which is the whole point of the fork.
	var sweep := fresh()
	sweep.player_equipped_weapon_art = "staff_leg_sweep"
	sweep.request_skill(Vector2.RIGHT, false)
	var whirl := fresh()
	whirl.player_equipped_weapon_art = "staff_whirlwind"
	whirl.request_skill(Vector2.RIGHT, false)
	check(float(sweep.player_action["reach"]) > float(whirl.player_action["reach"]), "the low sweep reaches further")
	check(float(sweep.player_action["posture_damage"]) > float(whirl.player_action["posture_damage"]), "and it is the one that takes them off their feet")
	check(float(whirl.player_action.get("staff_push", 0.0)) > 0.0, "Whirlwind is the one that moves bodies")
	check(float(sweep.player_action.get("staff_push", 0.0)) == 0.0, "the low sweep does not")
	# The shove is gated on the same PUSHABLE_MASS line as every other push in the game, so
	# a Shield, Brute, Knight or Ox stands in it. That is the art's honest limit.
	var state := fresh()
	var hound := state._make_enemy("hound", state.player_pos + Vector2.RIGHT * 90.0, 30)
	var ox := state._make_enemy("ox", state.player_pos + Vector2.LEFT * 90.0, 96)
	state.enemies.append(hound)
	state.enemies.append(ox)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	state._apply_whirlwind_push(hound, 104.0)
	state._apply_whirlwind_push(ox, 104.0)
	check(Vector2(hound["pos"]).distance_to(state.player_pos) > 150.0, "a light body is shoved out")
	check(is_equal_approx(Vector2(ox["pos"]).distance_to(state.player_pos), 90.0), "a heavy one is not")

func test_a_cone_hazard_tells_the_renderer_it_is_a_cone() -> void:
	# The renderer decides how to draw a hazard by whether it carries a half_angle. It used
	# to test the hazard's NAME, so when 0.2.56 replaced the Fire Caster's ring with a cone
	# the simulation resolved a cone while the renderer drew a 232-unit expanding disc --
	# and the prior cone branch no longer had a live producer.
	# Both halves were invisible to this suite, because a headless test cannot see a shape.
	# What it CAN pin is the contract the renderer keys on.
	var state := fresh()
	state.hazards.clear()
	state._spawn_fire_breath({"id": 1, "pos": state.player_pos, "layer": state.current_layer}, Vector2.UP)
	check(state.hazards.size() == 1, "fire breath should place a hazard")
	var cone: Dictionary = state.hazards[0]
	check(cone.has("half_angle"), "and it must declare itself a cone")
	check(float(cone["half_angle"]) < PI * 0.5, "with an angle narrow enough to have a direction worth dodging")
	check(cone.has("direction"), "and the direction it faces")
	# Cold Front is the counter-case: a front is a disc and must NOT be drawn as a wedge.
	state.hazards.clear()
	state._spawn_cold_front({"id": 1, "pos": state.player_pos, "layer": state.current_layer}, state.player_pos + Vector2.UP * 120.0)
	check(not Dictionary(state.hazards[0]).has("half_angle"), "a front is not a cone")

func test_a_player_cast_zone_hurts_enemies() -> void:
	# Every hazard resolved against the player and nobody else, because until 0.2.62 every
	# hazard belonged to an enemy. Fire Breath and Cold Front were therefore an expensive
	# light show with the right cone, the right meter and no target: half the class's spells
	# did nothing at all.
	for spell_id in ["fire_breath", "cold_front"]:
		var state := fresh()
		state.hazards.clear()
		var target := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 150.0, 35)
		state.enemies.append(target)
		state._invalidate_active_enemy_cache()
		state._build_enemy_spatial_index()
		var before := int(target["hp"])
		state._resolve_player_spell(String(spell_id), state.player_pos + Vector2.RIGHT * 200.0, Vector2.RIGHT)
		for tick in range(60): state._update_hazards(0.03)
		check(int(target["hp"]) < before, "the player's %s should hurt what stands in it" % spell_id)
		check(state.damage_dealt > 0, "and it should count as the player's damage")
	# An enemy's zone still resolves against the player alone. That asymmetry is deliberate:
	# a projectile hits whoever it hits because it can be redirected after commitment, but a
	# zone lands where its caster chose, and making enemy zones burn their own side is a
	# balance change to eight existing abilities rather than a bug fix.
	var enemy_state := fresh()
	enemy_state.hazards.clear()
	var caster := enemy_state._make_enemy("fire_caster", enemy_state.player_pos + Vector2.UP * 300.0, 40)
	var ally := enemy_state._make_enemy("blade", enemy_state.player_pos + Vector2.UP * 180.0, 35)
	enemy_state.enemies.append(caster)
	enemy_state.enemies.append(ally)
	enemy_state._invalidate_active_enemy_cache()
	enemy_state._build_enemy_spatial_index()
	var ally_before := int(ally["hp"])
	enemy_state._spawn_fire_breath(caster, Vector2.DOWN)
	for tick in range(60): enemy_state._update_hazards(0.03)
	check(int(ally["hp"]) == ally_before, "an enemy cone should not burn its own side")

func test_a_spell_is_priced_once() -> void:
	# Every other ability prices itself in Energy OR in cooldown, never both -- that is what
	# `0.0 if uses_energy_rules() else ...` says everywhere else in the file. Spells were
	# charged the Energy and then locked out for the cooldown as well, so one Frost Lance
	# bought a long silence afterwards for no stated reason.
	var energy_state := fresh()
	var before := energy_state.player_energy
	energy_state.request_spell("lightning_bolt", energy_state.player_pos + Vector2.UP * 300.0, false)
	check(energy_state.player_energy < before, "under Energy rules the spell costs Energy")
	check(energy_state.spell_cooldown <= 0.0001, "and nothing else")
	# Under Recovery there is no bar to spend, so the cooldown is the whole price.
	var recovery_state: RunState = RunStateScript.new()
	recovery_state.start_run("mage_elementalist", "combat_survey", 8811, "encounter", "recovery")
	recovery_state.enemies.clear()
	recovery_state.request_spell("lightning_bolt", recovery_state.player_pos + Vector2.UP * 300.0, false)
	check(recovery_state.spell_cooldown > 0.0, "under Recovery rules the cooldown is the price")

func test_world_time_advances_through_a_cast() -> void:
	# Frozen time means the world moves only while the player is committed -- and a wind-up
	# is commitment. Checked because a cast with no visible pose reads as time being paused
	# when it is not, which is a presentation problem rather than a simulation one.
	var state := fresh()
	var enemy := state._make_enemy("blade", state.player_pos + Vector2.RIGHT * 400.0, 35)
	enemy["action"] = state._melee_action(2.0, 1.0, 1.2, 100.0, 14, Vector2.LEFT)
	state.enemies.append(enemy)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	var started := state.simulation_time
	state.request_spell("lightning_bolt", state.player_pos + Vector2.UP * 300.0, true)
	check(state.simulation_time > started, "world time should advance across a cast")
	check(float(Dictionary(enemy["action"]).get("elapsed", 0.0)) > 0.5, "and the enemy should have been acting throughout it")

func test_a_wall_never_stands_up_without_warning() -> void:
	# The "invisible wall". A segment lowers while a pursuer is beside it -- drawn as a scar
	# and passable -- and used to stand back up on the very tick that enemy moved on. Since
	# committing to move is what advances world time, the player would look at flat ground,
	# commit, and arrive at a wall. Nothing was mis-drawn: the state they could see had
	# stopped being true by the time they got there.
	var state := fresh()
	var caster := state._make_enemy("earth_caster", state.player_pos + Vector2.UP * 420.0, 36)
	state.enemies.append(caster)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	state._raise_earth_wall(Vector2(caster["pos"]), int(caster["id"]))
	check(state.barriers.size() == state.EARTH_WALL_SEGMENTS, "the caster should raise a wall")
	var segment: Dictionary = state.barriers[0]
	var pursuer := state._make_enemy("hound", Vector2(segment["pos"]) + Vector2.RIGHT * 40.0, 30)
	state.enemies.append(pursuer)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	state._update_barriers(0.02)
	check(bool(segment["lowered"]), "a body beside a segment lowers it")
	# The pursuer moves on, with the player a short distance off.
	pursuer["pos"] = Vector2(segment["pos"]) + Vector2(700, 700)
	state.player_pos = Vector2(segment["pos"]) + Vector2(0, 120)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	state._update_barriers(0.02)
	check(bool(segment["lowered"]), "and it does not snap back up the moment they leave")
	check(not state._point_in_barrier(Vector2(segment["pos"]), state.PLAYER_RADIUS), "it is still passable while it rises")
	check(state.barrier_rise_fraction(segment) > 0.0, "and it is visibly rising while it does")
	var elapsed := 0.0
	while bool(segment["lowered"]) and elapsed < 3.0:
		state._update_barriers(0.02)
		elapsed += 0.02
	check(elapsed > 0.5 and elapsed < 1.2, "the rise takes a beat the player can act inside, took %.2fs" % elapsed)
	check(state._point_in_barrier(Vector2(segment["pos"]), state.PLAYER_RADIUS), "and then it is a wall again")
	# It also refuses to stand up against someone's back.
	state.barriers.clear()
	state._raise_earth_wall(Vector2(caster["pos"]), int(caster["id"]))
	var beside: Dictionary = state.barriers[0]
	beside["lowered"] = true
	state.player_pos = Vector2(beside["pos"]) + Vector2(0, 40)
	for tick in range(200): state._update_barriers(0.02)
	check(bool(beside["lowered"]), "a segment must not rise within a step of the player")

func test_walking_into_an_unseen_body_reveals_it() -> void:
	# The invisible wall, finally. Heavy bodies stop the player dead -- that is what
	# PUSHABLE_MASS is for -- and the renderer draws an enemy only where the player can see
	# one. An unseen Shield, Brute, Knight or Ox was therefore a solid object with nothing on
	# screen, in a spot that was open before it arrived and open again after it left. That is
	# the no-invisible-combat-math rule broken in its most literal form.
	var state := fresh()
	var ox := state._make_enemy("ox", state.player_pos + Vector2.RIGHT * 120.0, 96)
	ox["awareness"] = "idle"
	ox["revealed_to_player"] = false
	state.enemies.append(ox)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	check(not state._enemy_is_pushable(ox), "an Ox is heavy enough to stop the player")
	check(not state.is_visible(Vector2(ox["pos"]), {}), "and this one is not visible")
	check(not bool(ox.get("touch_revealed", false)), "nor yet known by touch")
	# Walk into it.
	for step in range(30): state.player_pos = state._move_actor(state.player_pos, Vector2.RIGHT * 8.0, state.PLAYER_RADIUS, 0)
	check(bool(ox.get("touch_revealed", false)), "walking into it should reveal it")
	check(state.survey_blind_collisions > 0, "and the room should record that it happened")
	# A body the player can already see is not counted -- the figure measures rooms hiding
	# solid objects in the player's path, not ordinary crowding.
	var seen := fresh()
	var shield := seen._make_enemy("shield", seen.player_pos + Vector2.RIGHT * 120.0, 50)
	shield["touch_revealed"] = true
	seen.enemies.append(shield)
	seen._invalidate_active_enemy_cache()
	seen._build_enemy_spatial_index()
	var before := seen.survey_blind_collisions
	for step in range(30): seen.player_pos = seen._move_actor(seen.player_pos, Vector2.RIGHT * 8.0, seen.PLAYER_RADIUS, 0)
	check(seen.survey_blind_collisions == before, "a body already known should not count again")

func test_a_wall_stops_the_side_that_did_not_raise_it() -> void:
	# The rule was written as "barriers block the player" when only enemies could raise one,
	# and never revisited when the Elementalist learned to. So the player's own wall stopped
	# the player and let enemies stroll through it -- the rule exactly inverted. Ownership
	# decides, not whether you happen to be the player.
	var state := fresh()
	var enemy := state._make_enemy("blade", state.player_pos + Vector2.UP * 300.0, 35)
	state.enemies.append(enemy)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	state._raise_player_earth_wall(state.player_pos + Vector2.UP * 150.0)
	var mine: Vector2 = Vector2(state.barriers[0]["pos"])
	check(not state._point_in_barrier(mine, state.PLAYER_RADIUS, 0), "my own wall must not stop me")
	check(state._point_in_barrier(mine, state.ENEMY_RADIUS, int(enemy["id"])), "and it must stop them")
	# An enemy's wall is the mirror: it cuts the player's retreat and its own side ignores it.
	state.barriers.clear()
	var caster := state._make_enemy("earth_caster", state.player_pos + Vector2.DOWN * 420.0, 36)
	state.enemies.append(caster)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	state._raise_earth_wall(Vector2(caster["pos"]), int(caster["id"]))
	var theirs: Vector2 = Vector2(state.barriers[0]["pos"])
	check(state._point_in_barrier(theirs, state.PLAYER_RADIUS, 0), "their wall must stop me")
	check(not state._point_in_barrier(theirs, state.ENEMY_RADIUS, int(caster["id"])), "and must not stop them")

func test_nothing_steps_off_the_floor() -> void:
	# An Air Caster threw itself off the edge of the map. Windstep wrote a position directly
	# and checked only `_inside_world` -- but the survey arena is a disc inside a much larger
	# world, so clearing the arena entirely still counts as inside it. Every direct write now
	# goes through one gate that asks about the floor, which is the boundary that matters,
	# rather than each ability inventing its own answer.
	var state := fresh()
	# Just outside the arena disc but comfortably inside the world rectangle -- the exact gap
	# `_inside_world` alone leaves open.
	var far := state.SURVEY_ARENA_CENTER + Vector2.RIGHT * (state.SURVEY_ARENA_RADIUS + 120.0)
	check(state._inside_world(far, state.ENEMY_RADIUS), "the point is inside the world")
	check(not state._actor_footprint_on_floor(far, state.ENEMY_RADIUS), "and off the arena floor")
	check(not state._teleport_allowed(far, state.ENEMY_RADIUS, 1), "so nothing may land there")
	check(state._teleport_allowed(state.player_pos + Vector2.RIGHT * 60.0, state.ENEMY_RADIUS, 1), "ordinary ground is still fine")
	# Windstep itself refuses it, rather than the gate merely existing.
	var air := state._make_enemy("air_caster", state.SURVEY_ARENA_CENTER + Vector2.RIGHT * (state.SURVEY_ARENA_RADIUS - 40.0), 32)
	state.enemies.append(air)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	air["action"] = state._action("windstep", 0.86, Vector2.RIGHT)
	air["action"]["startup"] = 0.26
	air["action"]["move_start"] = 0.26
	air["action"]["move_end"] = 0.58
	air["action"]["speed"] = 1250.0
	for tick in range(60): state._update_enemies(state.SIM_DT, tick % 2 == 0)
	check(state._actor_footprint_on_floor(Vector2(air["pos"]), state.ENEMY_RADIUS), "the caster should still be on the floor")

func test_gale_shoves_with_momentum() -> void:
	# A gust gives you a shove, not a new address. The push used to be a single position
	# write on the frame it landed -- nobody travelled, they were simply somewhere else,
	# which is a MOBA displacement rather than wind. Adding falloff changed how far they went
	# and not that they got there instantly.
	var state := fresh()
	var near := state._make_enemy("hound", state.player_pos + Vector2.RIGHT * 40.0, 30)
	var mid := state._make_enemy("hound", state.player_pos + Vector2.RIGHT * 130.0, 30)
	var edge := state._make_enemy("hound", state.player_pos + Vector2.RIGHT * 235.0, 30)
	var heavy := state._make_enemy("ox", state.player_pos + Vector2.DOWN * 90.0, 96)
	for body in [near, mid, edge, heavy]: state.enemies.append(body)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	var origins := {}
	for body in state.enemies: origins[int(body["id"])] = Vector2(body["pos"])
	state._resolve_gale(state.player_pos)
	# Nothing has moved yet. That is the whole point: the wind hands out velocity, and the
	# travel happens where the player can watch it.
	for body in state.enemies:
		check(Vector2(body["pos"]).distance_to(Vector2(origins[int(body["id"])])) < 0.01, "nothing should be displaced at the instant of impact")
	check(Vector2(near.get("gale_velocity", Vector2.ZERO)).length() > 0.0, "a light body should be carrying velocity")
	check(Vector2(heavy.get("gale_velocity", Vector2.ZERO)).length() == 0.0, "a heavy one should not")
	var elapsed := 0.0
	for tick in range(300):
		var moving := false
		for body in state.enemies:
			if body.has("gale_velocity"): moving = true
		if not moving: break
		state._update_gale_drift(state.SIM_DT)
		elapsed += state.SIM_DT
	check(elapsed > 0.15, "the travel should take real world time, took %.2fs" % elapsed)
	var near_moved := Vector2(near["pos"]).distance_to(Vector2(origins[int(near["id"])]))
	var mid_moved := Vector2(mid["pos"]).distance_to(Vector2(origins[int(mid["id"])]))
	var edge_moved := Vector2(edge["pos"]).distance_to(Vector2(origins[int(edge["id"])]))
	check(near_moved > mid_moved and mid_moved > edge_moved, "distance from the centre should decide how far you go (%.0f / %.0f / %.0f)" % [near_moved, mid_moved, edge_moved])
	check(Vector2(heavy["pos"]).distance_to(Vector2(origins[int(heavy["id"])])) < 0.01, "a heavy body stands in it")
	# Being thrown across a room is not something a body sleeps through.
	check(String(near.get("awareness", "idle")) == "alerted", "the wind should announce the caster")

func test_a_repeating_zone_reports_one_number() -> void:
	# Cold Front ticks four times per cast, and it used to put a separate figure over the
	# player for each one. Four small numbers that never add up to what the health bar does
	# read exactly like a hidden calculation, even though nothing was hidden -- reported as
	# "a huge -1 over my head but the damage is far higher".
	var state := fresh()
	state.hazards.clear()
	state.effects.clear()
	var caster := state._make_enemy("ice_caster", state.player_pos + Vector2.UP * 240.0, 40)
	state.enemies.append(caster)
	state._invalidate_active_enemy_cache()
	state._build_enemy_spatial_index()
	state._spawn_cold_front(caster, state.player_pos)
	var health_before := state.player_hp
	for tick in range(400):
		state._update_hazards(state.SIM_DT)
		state._update_effects(state.SIM_DT)
		if state.hazards.is_empty(): break
	var lost := health_before - state.player_hp
	check(lost > 0, "the front should have hurt at all")
	var reported := 0
	for effect in state.effects:
		if String(effect.get("kind", "")) == "hurt": reported = maxi(reported, int(effect.get("amount", 0)))
	# One figure, and it is the figure the health bar moved by.
	check(reported == lost, "the number shown (%d) should equal the health lost (%d)" % [reported, lost])
	# Frost is the payload, not the damage. A repeating zone is the one hazard where frozen
	# time works against the player -- leaving costs world time, and spending world time is
	# what advances the ticks -- so its per-tick damage is deliberately small.
	check(lost <= 8, "the front should cost little health across a whole cast, cost %d" % lost)
	check(float(state.player_condition_buildup.get("frost", 0.0)) > 0.0, "and it should still charge frost")
