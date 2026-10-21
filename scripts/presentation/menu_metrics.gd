extends RefCounted
## UI sizes are expressed in client pixels, converted through the actual canvas
## transform. World/camera projection is never changed by menu layout.
static func unit(board: Control) -> float:
	var transform := board.get_viewport().get_final_transform()
	var density := 1.0
	if OS.has_feature("android") or OS.has_feature("ios"):
		density=maxf(1.0,float(DisplayServer.screen_get_dpi())/160.0)
	return density / maxf(0.1, minf(transform.x.length(),transform.y.length()))

static func rect(board: Control, width: float = 820.0) -> Rect2:
	var safe: Rect2 = board._display_safe_layout_rect()
	var u := unit(board)
	var extent := Vector2(minf(safe.size.x-24*u,width*u),maxf(48*u,safe.size.y-24*u))
	return Rect2(safe.get_center()-extent/2,extent)

static func apply(board: Control, node: Node) -> void:
	var u := unit(board)
	if node is Control:
		if not node.has_meta("menu_base_min"): node.set_meta("menu_base_min",node.custom_minimum_size)
		var base: Vector2 = node.get_meta("menu_base_min")
		node.custom_minimum_size = base*u
		if node is BaseButton or node is LineEdit or node is TextEdit:
			node.custom_minimum_size.y=maxf(48*u,node.custom_minimum_size.y)
		if node is Label or node is BaseButton or node is LineEdit or node is TextEdit:
			if not node.has_meta("menu_base_font"): node.set_meta("menu_base_font",node.get_theme_font_size("font_size"))
			var font: int = node.get_meta("menu_base_font")
			var desired := maxi(1,roundi(clampf(font,16,24)*u))
			if node.get_theme_font_size("font_size") != desired: node.add_theme_font_size_override("font_size",desired)
	for child in node.get_children(): apply(board,child)
