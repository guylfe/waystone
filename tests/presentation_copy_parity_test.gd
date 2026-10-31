extends SceneTree
const State = preload("res://scripts/core/run_state.gd")
const Frame = preload("res://scripts/presentation/presentation_frame.gd")
const Schema = preload("res://scripts/core/state_field_schema.gd")
var failures: Array[String]=[]
var checks:=0
func check(ok: bool,why: String):
	checks+=1
	if not ok: failures.append(why); printerr("FAILED: ",why)
func legacy_copy(source: Dictionary,entity: String) -> Dictionary:
	# Exact previous two-stage projection/copy, including unknown nested values.
	var projected:=Schema.project_entity(source,entity,Schema.PRESENTATION)
	return projected.duplicate(true)
func _init():
	var frame:=Frame.new()
	for entity in ["enemy","projectile","hazard","effect","pickup","barrier"]:
		var source: Dictionary={}
		for descriptor in Schema.entity_descriptors(entity,Schema.PRESENTATION):
			var key:=String(descriptor.key)
			source[key]=descriptor.get("default",0)
		# Values are deliberately heterogeneous to exercise the previous copy policy.
		for key in ["action","conditions","condition_buildup","chants","attributes"]:
			source[key]={"nested":[{"value":2}],"kind":"idle","elapsed":0.4}
		source["pos"]=Vector2(1,2)
		source["facing"]=Vector2.RIGHT
		source["vel"]=Vector2(4,5)
		source["axis"]=Vector2.DOWN
		source["direction"]=Vector2.LEFT
		var expected:=legacy_copy(source,entity)
		var actual: Dictionary={"stale":true}
		frame._copy_entity(source,actual,entity)
		check(actual==expected,entity+" exact projection parity")
		var frozen:=actual.duplicate(true)
		for value in source.values():
			if value is Dictionary: value["mutation"]=true
		check(actual==frozen,entity+" frame owns nested values")
		frame._copy_entity({},actual,entity)
		check(actual==legacy_copy({},entity),entity+" absent keys cleared and defaults preserved")
	var s=State.new(false)
	s.start_run("mage_elementalist","expedition",717)
	s._raise_player_earth_wall(s.player_pos+Vector2(150,0))
	var a:=Frame.new()
	var b:=Frame.new()
	a.capture(s)
	var frozen:=a.data.duplicate(true)
	s.barriers[0].hp=1
	s.barriers[0].remaining=2.0
	b.capture(s)
	check(a.data==frozen,"previous frame unchanged by state or following capture")
	check(a.data.barriers[0].hp!=b.data.barriers[0].hp,"wall damage appears in following frame")
	for weight in [0.0,0.25,0.5,1.0]:
		var blend:=Frame.new()
		var actual: Dictionary={}
		var reference: Dictionary={}
		for entity in ["enemy","projectile","hazard","effect","pickup","barrier"]:
			var current: Dictionary={"pos":Vector2(1,2),"remaining":5.0,"hp":8,"layer":"a","axis":Vector2.RIGHT,"conditions":{"burning":1.0}}
			var following: Dictionary={"pos":Vector2(3,5),"remaining":4.0,"hp":5,"layer":"a","axis":Vector2.DOWN,"conditions":{"burning":0.5}}
			for descriptor in Schema.entity_descriptors(entity,Schema.PRESENTATION):
				var key:=String(descriptor.key)
				if not current.has(key) and not following.has(key): continue
				var value: Variant=current.get(key,descriptor.get("default"))
				reference[key]=blend._blended_value(value,following.get(key,value),String(descriptor.get("interpolate","carry")),weight)
			blend._blend_entity(current,following,actual,entity,weight)
			check(actual==reference,entity+" blend parity weight="+str(weight))
			reference.clear()
	print("PRESENTATION_COPY_PARITY checks=%d failures=%d" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
