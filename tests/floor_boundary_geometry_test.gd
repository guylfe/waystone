extends SceneTree
const Boundary=preload("res://scripts/core/floor_boundary.gd")
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,why: String):
	checks+=1
	if not ok: failures.append(why); printerr("FAILED: ",why)
func circle(center: Vector2,radius: float) -> Dictionary:
	return {"kind":"circle","center":center,"radius":radius}
func capsule(a: Vector2,b: Vector2,radius: float) -> Dictionary:
	return {"kind":"capsule","from":a,"to":b,"radius":radius}
func rect(r: Rect2) -> Dictionary: return {"kind":"rect","rect":r}
func _init():
	var floor=Boundary.new([circle(Vector2(300,300),200)])
	check(absf(floor.sweep(Vector2(300,300),Vector2(600,300),10)-190.0/300.0)<0.00001,"analytic circle exit with full disc radius")
	floor=Boundary.new([capsule(Vector2(300,300),Vector2(600,300),100)])
	check(absf(floor.sweep(Vector2(300,300),Vector2(900,300),8)-392.0/600.0)<0.00001,"analytic capsule cap exit")
	check(absf(floor.sweep(Vector2(400,300),Vector2(400,500),10)-0.45)<0.00001,"analytic capsule side exit")
	floor=Boundary.new([circle(Vector2(300,300),200),capsule(Vector2(300,300),Vector2(600,300),80)])
	check(floor.sweep(Vector2(300,300),Vector2(650,300),8)==INF,"circle to capsule connected passage has no internal seam")
	floor=Boundary.new([rect(Rect2(100,100,200,300)),rect(Rect2(300,200,300,100))])
	check(floor.sweep(Vector2(200,250),Vector2(500,250),20)==INF,"partially coincident rect seam is removed")
	check(floor.sweep(Vector2(200,150),Vector2(500,150),8)!=INF,"partial seam does not erase exposed rect side")
	floor=Boundary.new([rect(Rect2(100,100,200,300)),rect(Rect2(300.5,100,300,300))])
	check(absf(floor.sweep(Vector2(290,250),Vector2(330,250),0.1)-9.9/40.0)<0.00001,"sub-step half-unit gap cannot be skipped")
	check(floor.sweep(Vector2(300.25,250),Vector2(330,250),0.1)==0,"origin in void stops immediately")
	# Independent dense sampling checks deterministic random sweeps through a union.
	var shapes: Array=[circle(Vector2(300,300),200),circle(Vector2(650,300),200),capsule(Vector2(300,300),Vector2(650,300),60),rect(Rect2(200,450,550,100))]
	floor=Boundary.new(shapes)
	var rng:=RandomNumberGenerator.new()
	rng.seed=717
	for trial in 80:
		var start:=Vector2(rng.randf_range(150,800),rng.randf_range(120,520))
		var finish:=Vector2(rng.randf_range(100,900),rng.randf_range(80,600))
		if not floor.contains(start): continue
		var hit: float=floor.sweep(start,finish,4.0)
		var dense:=INF
		for step in 1001:
			var t:=float(step)/1000
			var point:=start.lerp(finish,t)
			var valid: bool=floor.contains(point)
			for i in 64:
				if not floor.contains(point+Vector2.from_angle(TAU*i/64.0)*4.0): valid=false; break
			if not valid: dense=t; break
		check((hit==INF and dense==INF) or (hit!=INF and dense!=INF and absf(hit-dense)<0.004),"analytic sweep agrees with dense perimeter oracle trial="+str(trial))
	print("FLOOR_GEOMETRY checks=%d failures=%d" % [checks,failures.size()])
	quit(1 if failures.size() else 0)
