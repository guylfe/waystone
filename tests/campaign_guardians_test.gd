extends SceneTree

const State = preload("res://scripts/campaign/campaign_state.gd")
const Regions = preload("res://scripts/campaign/campaign_regions.gd")
const Planner = preload("res://tests/expedition_action_planner.gd")
const Executor = preload("res://scripts/core/expedition_combat.gd")
const GUARDIANS := {
	"sluice_keeper": {"layer": Regions.SURFACE, "start": Vector2(6260, 2260)},
	"bell_warden": {"layer": Regions.RIDGE, "start": Vector2(6810, 640)},
	"hollow_keeper": {"layer": Regions.CORE, "start": Vector2(8420, 983)},
}
var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func encounter(id: String, loadout: String) -> State:
	var s := State.new(false)
	s.start_run(loadout, "campaign_lab", 131137)
	s.current_layer = GUARDIANS[id].layer
	s.player_pos = GUARDIANS[id].start
	s.current_area_id = s._area_id_at_position(s.player_pos, s.current_layer)
	s._load_current_layer_discovery()
	s._apply_shortcut_world_state()
	s._update_exploration(true)
	var boss := s._enemy_by_id(Regions.BOSS_IDS[id])
	s._replace_enemy_actors([boss])
	boss.awareness = "alerted"
	boss.alert_remaining = 100.0
	boss.revealed_to_player = true
	return s

func fight(id: String, loadout: String) -> void:
	var s := encounter(id, loadout)
	var planner := Planner.new()
	planner.short_horizon = true
	var seen := {}
	var decisions := 0
	var boss := s._enemy_by_id(Regions.BOSS_IDS[id])
	# The planner only forecasts public actions. Active clocks, stats and health
	# in the earned fight remain entirely owned by the Campaign state.
	while not s.death_pending and not s.defeated_guardians.has(id) and decisions < 260 and s.simulation_time < 120:
		if s.is_player_ready():
			if not planner.choose(s, boss):
				# The forecast state does not model Campaign-only context labels.
				# Leave the lever's interaction radius if it rejected a Wait.
				var retreat := Vector2(boss.pos).direction_to(s.player_pos)
				if not s.request_move(retreat.rotated(PI * 0.5), s.MOVE_RANGE, false): break
			decisions += 1
		if s.player_action.kind == "bow_draw" and float(s.player_action.elapsed) >= 0.9:
			s.release_bow_attack()
		var attack := String(boss.action.get("ability_id", ""))
		if not attack.is_empty(): seen[attack] = true
		s.advance_streamed_action_tick()
	var won := s.defeated_guardians.has(id)
	print("GUARDIAN ", id, "/", loadout, " won=", won, " decisions=", decisions, " simulation=", snappedf(s.simulation_time, 0.01),
		" hp=", s.player_hp, " boss_hp=", boss.hp, " phase=", boss.get("boss_phase", 1), " tells=", seen.keys())
	if not won: failures.append(id + "/" + loadout)

func wall_response() -> void:
	var s := encounter("bell_warden", "warrior")
	var boss := s._enemy_by_id(Regions.BOSS_IDS.bell_warden)
	# Pick the authored rush toward the side of the buttress, then move clear
	# after aim lock. The wall collision must consume the visible full recovery.
	s._set_enemy_position(boss, Vector2(6860, 850))
	s.player_pos = Vector2(6640, 890)
	s._update_exploration(true)
	Executor.choose(s, boss)
	var rush: Dictionary = boss.action
	while float(rush.get("elapsed", 0.0)) < 0.34 and s.simulation_time < 1.0:
		if s.is_player_ready(): s.request_wait(0.05, false)
		s.advance_streamed_action_tick()
	while not s.is_player_ready(): s.advance_streamed_action_tick()
	s.request_dodge(Vector2.DOWN, false)
	while float(rush.get("elapsed", 0.0)) < 1.42 and s.simulation_time < 1.8:
		if s.is_player_ready(): s.request_wait(0.05, false)
		s.advance_streamed_action_tick()
	var crashed := String(rush.get("ability_id", "")) == "buttress_rush" and float(rush.get("duration", 0.0)) > 2.35
	print("WARDEN BUTTRESS ", crashed, " active_end=", rush.get("active_end"), " duration=", rush.get("duration"), " hp=", s.player_hp)
	if not crashed: failures.append("wall collision must extend Warden recovery")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 1 and args[0] == "wall":
		wall_response()
	elif args.size() == 2:
		fight(args[0], args[1])
	else:
		for id in GUARDIANS:
			fight(id, "warrior")
		wall_response()
	print("REGIONAL GUARDIANS ", failures.size(), " failures ", failures)
	quit(0 if failures.is_empty() else 1)
