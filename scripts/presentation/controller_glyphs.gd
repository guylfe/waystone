extends RefCounted
## Original vector button artwork; the same atlas serves HUD, menus and dialogs.
const ATLAS = preload("res://assets/controller/xbox-buttons.svg")
const KEYS := ["a", "b", "x", "y", "lb", "rb", "lt", "rt", "ls", "rs", "lsc", "rsc", "dpad", "up", "down", "lr", "view", "menu", "left", "right"]

static func region(key: String) -> Rect2:
	var index := KEYS.find(key)
	assert(index >= 0, "Unknown controller glyph: " + key)
	return Rect2((index % 5) * 64, (index / 5) * 64, 64, 64)

static func texture(key: String) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = ATLAS
	result.region = region(key)
	return result

static func draw(canvas: CanvasItem, key: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	canvas.draw_texture_rect_region(ATLAS, rect, region(key), tint)

static func text(canvas: CanvasItem, position: Vector2, value: String, width: float, font_size: int, color: Color) -> void:
	# Explicit ellipsis rather than silently clipping a spell or item name.
	var font := ThemeDB.fallback_font
	var shown := value
	while font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and shown.length() > 2:
		shown = shown.left(shown.length() - 2).strip_edges() + "…"
	canvas.draw_string(font, position, shown, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

static func hint(canvas: CanvasItem, position: Vector2, key: String, label: String, scale: float) -> void:
	draw(canvas, key, Rect2(position, Vector2.ONE * 30 * scale))
	text(canvas, position + Vector2(36, 21) * scale, label, 150 * scale, int(16 * scale), Color("e0edf2"))

static func toolbar(canvas: CanvasItem, rect: Rect2, key: String, label: String) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0: return
	canvas.draw_rect(rect, Color("101f28"))
	var side := rect.size.y * 0.75
	draw(canvas, key, Rect2(rect.position + Vector2(3, (rect.size.y - side) * 0.5), Vector2.ONE * side))
	text(canvas, rect.position + Vector2(side + 6, rect.size.y * 0.63), label, rect.size.x - side - 9, int(rect.size.y * 0.34), Color("e0edf2"))

class MenuHints extends HFlowContainer:
	var controller: RefCounted
	var back_label := "Back"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("h_separation", 10)
		add_theme_constant_override("v_separation", 4)
		var prompts := [["dpad", "Choose"], ["a", "Confirm"]]
		if back_label != "": prompts.append(["b", back_label])
		for pair in prompts:
			# Keep each glyph and its word together when narrow menus reflow.
			var prompt := HBoxContainer.new()
			prompt.add_theme_constant_override("separation", 10)
			add_child(prompt)
			var icon := TextureRect.new()
			icon.texture = load("res://scripts/presentation/controller_glyphs.gd").texture(pair[0])
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(48, 48)
			prompt.add_child(icon)
			var label := Label.new()
			label.text = pair[1]
			label.add_theme_font_size_override("font_size", 24)
			label.add_theme_color_override("font_color", Color("e0edf2"))
			prompt.add_child(label)
	func _process(_delta: float) -> void:
		visible = controller != null and controller.active
