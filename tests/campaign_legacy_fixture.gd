extends SceneTree

# Run this external script against the frozen ab18683 checkout. It uses only
# features already present there and writes an isolated deterministic fixture.
const Campaign = preload("res://scripts/campaign/campaign_state.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not OS.get_user_data_dir().contains(".runtime"):
		quit(2)
		return
	var s := Campaign.new(false)
	s.start_run("mage_elementalist", "campaign_lab", 131137)
	s.upgrade_count = 12
	s.carried_xp = 1000
	s.secured_xp = 1000
	s.player_pos = Vector2(500, 1000)
	if not s.choose_upgrade("elementalist|fireball") or not s.select_spell("fireball"):
		quit(3)
		return
	s.shortcuts[0].unlocked = true
	s._update_exploration(true)
	s.player_pos = Vector2(430, 1480)
	s._update_exploration(true)
	if not s.unlock_shortcut():
		quit(4)
		return
	s.route_released = true
	s.enemies.front().hp = 0
	s._remove_dead_enemies()
	var ok := s.save_run(args[0])
	print("FROZEN CAMPAIGN FIXTURE ", ok)
	quit(0 if ok else 5)
