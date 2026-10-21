extends RefCounted
## Context-local semantic focus and geometric neighbors. No gameplay state.
static func id(entry: Dictionary) -> String:
	if entry.has("id"): return str(entry.id)
	if entry.has("control"): return str(entry.control.get_meta("menu_id",entry.control.text if entry.control is BaseButton else entry.control.name))
	return str(entry.get("label",entry.get("rect",Rect2())))

static func rect(entry: Dictionary) -> Rect2:
	return entry.control.get_global_rect() if entry.has("control") else entry.get("rect",Rect2())

static func neighbor(entries: Array, index: int, direction: Vector2) -> int:
	if entries.is_empty(): return 0
	if not entries[index].has("control") and not entries[index].has("rect"):
		return clampi(index+int(direction.y),0,entries.size()-1)
	var center := rect(entries[index]).get_center()
	var result := index
	var score := INF
	for i in entries.size():
		if i == index: continue
		var delta := rect(entries[i]).get_center()-center
		var forward := delta.dot(direction)
		if forward <= 1: continue
		var side := absf(delta.cross(direction))
		var candidate := forward + side*3.0
		if candidate < score: score=candidate; result=i
	return result
