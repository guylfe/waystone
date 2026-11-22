extends Control
## The notice leaves gameplay input alone. Actions live in setup and the Run menu.

const Update = preload("res://scripts/core/release_update.gd")
const Metrics = preload("res://scripts/presentation/menu_metrics.gd")
var service: Update
var board: Control
var _toast_left := 6.0
var toast := Label.new()

func _ready() -> void:
	board = get_parent()
	service = get_node("/root/ReleaseUpdate")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 15
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var background := StyleBoxFlat.new()
	background.bg_color = Color("19343b")
	toast.add_theme_stylebox_override("normal", background)
	add_child(toast)
	service.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_toast_left = 6.0
	toast.hide()
	set_process(not service.tag.is_empty())
	board.queue_redraw()

func _process(delta: float) -> void:
	var can_show: bool = (
		board.state.run_active and not board.playing and not board.pointer_down
		and not board.controller.modal(board) and not board._run_comment_open()
		and not board.update_menu_covers_play()
	)
	toast.visible = can_show
	if not can_show: return
	_toast_left -= delta
	var safe: Rect2 = board._display_safe_layout_rect()
	var unit := minf(Metrics.unit(board), safe.size.x / 390.0)
	var extent := Vector2(318.0, 36.0) * unit
	toast.text = "%s available · Open Menu" % service.tag
	toast.add_theme_font_size_override("font_size", roundi(16.0 * unit))
	toast.size = extent
	toast.position = Vector2(board.board_rect.get_center().x - extent.x * 0.5, safe.position.y + 100.0 * unit)
	if _toast_left <= 0.0:
		toast.hide()
		set_process(false)

func setup_entries() -> Array:
	if service.tag.is_empty() or board.setup_stage != "root" or board.custom_room_open or board.controller.paused or board.survey_overlay.visible: return []
	var safe: Rect2 = board.safe_layout_rect
	var unit := minf(Metrics.unit(board), safe.size.x / 390.0)
	var width := minf(safe.size.x - 20.0 * unit, 450.0 * unit)
	var bottom := safe.end.y - (36.0 if not board.setup_notice.is_empty() else 12.0) * unit
	var top := bottom - 48.0 * unit
	for card in board.progression_rects.values():
		top = maxf(top, card.end.y + 6.0 * unit)
	if bottom - top < 30.0 * unit: return []
	var height := bottom - top
	var start := Vector2(safe.get_center().x - width * 0.5, top)
	var open := Rect2(start + Vector2(width * 0.40, 0), Vector2(width * 0.36, height))
	var dismiss := Rect2(start + Vector2(width * 0.78, 0), Vector2(width * 0.22, height))
	return [
		{"id": "open_release", "rect": open, "label": "View on GitHub", "activate": service.open_release},
		{"id": "dismiss_release", "rect": dismiss, "label": "Dismiss", "activate": service.dismiss},
	]

func draw_setup() -> void:
	var entries := setup_entries()
	if entries.is_empty(): return
	var open: Rect2 = entries[0].rect
	var origin := open.position - Vector2(open.size.x / 0.36 * 0.40, 0)
	var font := maxi(10, mini(roundi(open.size.y * 0.34), roundi(open.size.x / 8.6)))
	var title_width := open.position.x - origin.x - 4.0
	board.draw_string(ThemeDB.fallback_font, origin + Vector2(0, open.size.y * 0.62), "%s available" % service.tag, HORIZONTAL_ALIGNMENT_CENTER, title_width, font, Color("f2e7c8"))
	for entry in entries:
		var rect: Rect2 = entry.rect
		board.draw_rect(rect, Color("24433f"))
		board.draw_rect(rect, Color("58d2cf"), false, 1.0)
		board.draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, rect.size.y * 0.62), entry.label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font, Color.WHITE)

func run_entries() -> Array:
	if service.tag.is_empty(): return []
	return [
		{"id": "open_release", "label": "View %s on GitHub" % service.tag, "activate": service.open_release},
		{"id": "dismiss_release", "label": "Dismiss update notice", "activate": service.dismiss},
	]
