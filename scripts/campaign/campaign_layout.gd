extends RefCounted
# Fixed landmarks; seeded clearing edges/dressing. Reviewed bridge geometry retained.
static func upper() -> Array:
	var rects:Array=[Rect2(250,650,650,650),Rect2(900,850,900,250),Rect2(1800,650,650,650),Rect2(250,0,350,850),Rect2(250,0,2200,350),Rect2(2100,0,350,850),Rect2(2100,1100,350,750),Rect2(250,1500,2200,350),Rect2(250,1100,350,750)]
	for p in [Vector2(730,760),Vector2(1830,760)]:
		var hole:=Rect2(p+Vector2(100,45),Vector2(70,120))
		var pieces:Array=[]
		for r:Rect2 in rects:
			if not r.intersects(hole): pieces.append(r);continue
			var cut:=r.intersection(hole)
			for piece in [Rect2(r.position,Vector2(r.size.x,cut.position.y-r.position.y)),Rect2(Vector2(r.position.x,cut.end.y),Vector2(r.size.x,r.end.y-cut.end.y)),Rect2(Vector2(r.position.x,cut.position.y),Vector2(cut.position.x-r.position.x,cut.size.y)),Rect2(Vector2(cut.end.x,cut.position.y),Vector2(r.end.x-cut.end.x,cut.size.y))]:
				if piece.size.x>0 and piece.size.y>0: pieces.append(piece)
		rects=pieces
	return rects
static func lower() -> Array:
	return [Rect2(550,200,350,1100),Rect2(550,850,1450,450),Rect2(1650,200,350,1100)]
static func generate(seed_value:int) -> Dictionary:
	var shapes:Array=[]
	var areas:Array=[]
	for layer in ["forest_surface","underpass"]:
		for r:Rect2 in (upper() if layer=="forest_surface" else lower()): shapes.append({"kind":"rect","rect":r,"layer":layer,"part_id":0 if layer=="forest_surface" else 1})
		areas.append({"id":0 if layer=="forest_surface" else 1,"name":"Forest and Sunken Ruin" if layer=="forest_surface" else "Sheltered Underpass","layer":layer,"center":Vector2(1250,950),"rect":Rect2(200,0,2300,1900),"palette":"forest_3"})
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var features:Array=[]
	var walls:Array=[Rect2(1930,690,85,110)]
	for i in 18:
		var p:=Vector2(rng.randf_range(650,1950),rng.randf_range(40,115))
		features.append({"kind":"tree","pos":p,"radius":45.0,"blocks":true,"layer":"forest_surface","part_id":0})
		walls.append(Rect2(p-Vector2.ONE*18.9,Vector2.ONE*37.8))
	var shortcuts:Array=[{"id":"bridge_gate","name":"Overlook gate","gate":Rect2(1080,850,80,250),"unlock_pos":Vector2(1240,980),"near_pos":Vector2(1000,980),"layer":"forest_surface","unlocked":false},{"id":"dawn_return","name":"Dawn return gate","gate":Rect2(250,1310,350,80),"unlock_pos":Vector2(430,1480),"near_pos":Vector2(430,1230),"layer":"forest_surface","unlocked":false}]
	var routes:Array=[{"id":0,"from":0,"to":0,"layer":"forest_surface","path":[Vector2(500,1000),Vector2(430,175),Vector2(2275,175),Vector2(2200,980)],"unlocked":true,"shortcut":false},{"id":1,"from":0,"to":0,"layer":"forest_surface","path":[Vector2(500,1000),Vector2(2200,980)],"unlocked":false,"shortcut":true,"shortcut_id":"bridge_gate"},{"id":2,"from":0,"to":0,"layer":"forest_surface","path":[Vector2(2200,980),Vector2(2275,1675),Vector2(430,1675),Vector2(430,1230)],"unlocked":false,"shortcut":true,"shortcut_id":"dawn_return"}]
	return {"world_size":Vector2(2800,2200),"geometry_style":"rooms","areas":areas,"connections":routes,"floor_shapes":shapes,"terrain_features":features,"layers":{"forest_surface":{"name":"Forest and Sunken Ruin"},"underpass":{"name":"Sheltered Underpass"}},"layer_walls":{"forest_surface":walls,"underpass":[Rect2(960,875,65,65),Rect2(960,1020,65,65),Rect2(1710,875,65,65),Rect2(1710,1020,65,65),Rect2(830,805,70,120),Rect2(1930,805,70,120)]},"encounters":{0:[{"kind":"blade","pos":Vector2(1850,980),"layer":"forest_surface"},{"kind":"archer","pos":Vector2(2200,950),"layer":"forest_surface"},{"kind":"hound","pos":Vector2(1550,175),"layer":"forest_surface"}],1:[{"kind":"hound","pos":Vector2(1250,980),"layer":"underpass"}]},"base_walls":walls,"bonfire_pos":Vector2(500,1000),"player_start":Vector2(500,1170),"waystones":[{"id":"dawn","name":"Dawn Waystone","pos":Vector2(500,1000),"layer":"forest_surface"}],"shortcuts":shortcuts,"shortcut_gate":Rect2(),"shortcut_unlock_pos":Vector2.ZERO,"shortcut_start_pos":Vector2.ZERO,"transitions":[{"id":"west_steps","from_layer":"forest_surface","to_layer":"underpass","from_pos":Vector2(730,760),"to_pos":Vector2(730,760)},{"id":"east_steps","from_layer":"underpass","to_layer":"forest_surface","from_pos":Vector2(1830,760),"to_pos":Vector2(1830,760)}]}
