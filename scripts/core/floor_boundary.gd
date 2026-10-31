extends RefCounted
# Exact line/arc boundary of a union of authored rectangles, circles and capsules.
# Internal seams are removed before swept-disc queries. No timestep ray marching.
const EPS := 0.0001
const CELL := 256.0
var shapes: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var buckets: Dictionary = {}

func _init(source: Array = []):
	shapes.assign(source)
	var raw: Array[Dictionary] = []
	for shape in shapes: _primitives(shape, raw)
	for edge in raw:
		var cuts: Array[float] = [0.0, 1.0]
		for other in raw:
			if edge == other or not Rect2(edge.bounds).grow(EPS).intersects(Rect2(other.bounds).grow(EPS)): continue
			for point in _intersections(edge, other):
				var amount := _parameter(edge, point)
				if amount > EPS and amount < 1.0-EPS: cuts.append(amount)
		cuts.sort()
		for i in range(cuts.size()-1):
			if cuts[i+1]-cuts[i] < EPS: continue
			var midpoint := _point(edge,(cuts[i]+cuts[i+1])*0.5)
			var normal := (midpoint-Vector2(edge.center)).normalized() if edge.kind=="arc" else Vector2(edge.normal)
			# A union seam has floor on its outward side too. It cannot stop travel.
			if contains(midpoint+normal*0.001): continue
			var part := edge.duplicate()
			if edge.kind=="arc":
				part.angle=float(edge.angle)+float(edge.span)*cuts[i]
				part.span=float(edge.span)*(cuts[i+1]-cuts[i])
			else:
				part.a=_point(edge,cuts[i])
				part.b=_point(edge,cuts[i+1])
			var id := edges.size()
			edges.append(part)
			for cell in _cells(part.bounds):
				if not buckets.has(cell): buckets[cell]=[]
				buckets[cell].append(id)

func contains(point: Vector2) -> bool:
	for shape in shapes:
		if shape.kind=="rect":
			if Rect2(shape.rect).has_point(point): return true
		elif shape.kind=="circle":
			if point.distance_squared_to(shape.center)<=float(shape.radius)*float(shape.radius): return true
		elif _distance(point,shape.from,shape.to)<=float(shape.radius): return true
	return false

# First fraction where any part of the disc touches the exposed floor boundary.
# INF means the entire sweep stays on floor; a center already in void returns zero.
func sweep(start: Vector2, finish: Vector2, radius: float, recover_inward: bool = false) -> float:
	if not contains(start): return 0.0
	var result := INF
	var seen := {}
	var bounds := Rect2(start.min(finish), (finish-start).abs()).grow(radius+0.001)
	for cell in _cells(bounds):
		for id in Array(buckets.get(cell,[])):
			if seen.has(id): continue
			seen[id]=true
			var edge := edges[int(id)]
			# Older saves use cardinal footprint probes. At a curved edge their
			# accepted footprint may overlap this stricter disc boundary slightly.
			# A short inward recovery may reduce that overlap; it cannot create one.
			# The caller separately sweeps the center, so this never crosses void.
			if recover_inward and start.distance_squared_to(finish) <= radius*radius*0.25:
				var normal := (start-Vector2(edge.center)).normalized() if edge.kind=="arc" else Vector2(edge.normal)
				var distance := _arc_distance(edge,start) if edge.kind=="arc" else _distance(start,edge.a,edge.b)
				if distance<radius-EPS and (finish-start).dot(normal)<-EPS: continue
			if edge.kind=="line":
				result=minf(result,segment_hit(start,finish,edge.a,edge.b,radius))
			else:
				var center := Vector2(edge.center)
				var r := float(edge.radius)
				if _arc_distance(edge,start)<maxf(0.0,radius-EPS): return 0.0
				for expanded in [r+radius,maxf(0.0,r-radius)]:
					for t in _circle_roots(start,finish,center,expanded):
						var point := start.lerp(finish,t)
						if _parameter(edge,point)>=-EPS and _parameter(edge,point)<=1.0+EPS: result=minf(result,t)
				for end in [_point(edge,0.0),_point(edge,1.0)]: result=minf(result,circle_hit(start,finish,end,radius))
	return result

static func circle_hit(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> float:
	if start.distance_squared_to(center)<radius*radius-EPS: return 0.0
	var roots := _circle_roots(start,finish,center,radius)
	return roots[0] if not roots.is_empty() else INF

static func segment_hit(start: Vector2, finish: Vector2, a: Vector2, b: Vector2, radius: float) -> float:
	if _distance(start,a,b)<maxf(0.0,radius-EPS): return 0.0
	var result := minf(circle_hit(start,finish,a,radius),circle_hit(start,finish,b,radius))
	var axis := (b-a).normalized()
	if axis.is_zero_approx(): return result
	var normal := axis.orthogonal()
	var velocity := finish-start
	var across := velocity.dot(normal)
	if absf(across)<=EPS: return result
	for side in [-1.0,1.0]:
		var t: float = (radius*side-(start-a).dot(normal))/across
		if t<0.0 or t>1.0: continue
		var along := (start.lerp(finish,t)-a).dot(axis)
		if along>=0.0 and along<=a.distance_to(b): result=minf(result,t)
	return result

static func _circle_roots(a: Vector2, b: Vector2, center: Vector2, radius: float) -> Array[float]:
	var d := b-a
	var offset := a-center
	var aa := d.length_squared()
	if aa<EPS*EPS: return []
	var bb := 2.0*offset.dot(d)
	var cc := offset.length_squared()-radius*radius
	var disc := bb*bb-4.0*aa*cc
	if disc<0.0: return []
	var result: Array[float]=[]
	for root in [(-bb-sqrt(disc))/(2.0*aa),(-bb+sqrt(disc))/(2.0*aa)]:
		if root>=0.0 and root<=1.0: result.append(root)
	return result

static func _distance(p: Vector2,a: Vector2,b: Vector2) -> float:
	var delta := b-a
	return p.distance_to(a+delta*clampf((p-a).dot(delta)/delta.length_squared(),0,1)) if delta.length_squared()>EPS else p.distance_to(a)

func _arc_distance(edge: Dictionary, point: Vector2) -> float:
	var t := _parameter(edge,point)
	if t>=0 and t<=1: return absf(point.distance_to(edge.center)-float(edge.radius))
	return minf(point.distance_to(_point(edge,0)),point.distance_to(_point(edge,1)))

func _point(edge: Dictionary,t: float) -> Vector2:
	return Vector2(edge.center)+Vector2.from_angle(float(edge.angle)+float(edge.span)*t)*float(edge.radius) if edge.kind=="arc" else Vector2(edge.a).lerp(edge.b,t)
func _parameter(edge: Dictionary,p: Vector2) -> float:
	if edge.kind=="line":
		var delta := Vector2(edge.b)-Vector2(edge.a)
		return (p-Vector2(edge.a)).dot(delta)/maxf(EPS,delta.length_squared())
	var angle := fposmod((p-Vector2(edge.center)).angle()-float(edge.angle),TAU)
	if angle>TAU-EPS: angle=0.0
	return angle/maxf(EPS,float(edge.span))

func _intersections(a: Dictionary,b: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2]=[]
	if a.kind=="line" and b.kind=="line":
		var point: Variant=Geometry2D.segment_intersects_segment(a.a,a.b,b.a,b.b)
		if point!=null: points.append(point)
		# Collinear partial seams still need splitting at each other's endpoints.
		for end in [b.a,b.b]:
			if _distance(end,a.a,a.b)<EPS: points.append(end)
	elif a.kind=="line" or b.kind=="line":
		var line := a if a.kind=="line" else b
		var arc := b if a.kind=="line" else a
		for t in _circle_roots(line.a,line.b,arc.center,arc.radius): points.append(Vector2(line.a).lerp(line.b,t))
	else:
		var offset := Vector2(b.center)-Vector2(a.center)
		var d := offset.length()
		var ra := float(a.radius)
		var rb := float(b.radius)
		if d<EPS:
			if absf(ra-rb)<EPS: points.assign([_point(b,0),_point(b,1)])
		elif d<=ra+rb+EPS and d>=absf(ra-rb)-EPS:
			var along := (ra*ra-rb*rb+d*d)/(2*d)
			var height := sqrt(maxf(0,ra*ra-along*along))
			var base := Vector2(a.center)+offset*(along/d)
			points.assign([base+offset.orthogonal()*(height/d),base-offset.orthogonal()*(height/d)])
	var valid: Array[Vector2]=[]
	for p in points:
		if _parameter(a,p)>=-EPS and _parameter(a,p)<=1+EPS and _parameter(b,p)>=-EPS and _parameter(b,p)<=1+EPS: valid.append(p)
	return valid

func _line(a: Vector2,b: Vector2,normal: Vector2,output: Array[Dictionary]):
	output.append({"kind":"line","a":a,"b":b,"normal":normal,"bounds":Rect2(a.min(b),(b-a).abs()).grow(EPS)})
func _arc(center: Vector2,radius: float,angle: float,span: float,output: Array[Dictionary]):
	output.append({"kind":"arc","center":center,"radius":radius,"angle":angle,"span":span,"bounds":Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2)})
func _primitives(s: Dictionary,output: Array[Dictionary]):
	if s.kind=="rect":
		var r := Rect2(s.rect)
		_line(r.position,Vector2(r.end.x,r.position.y),Vector2.UP,output)
		_line(Vector2(r.end.x,r.position.y),r.end,Vector2.RIGHT,output)
		_line(r.end,Vector2(r.position.x,r.end.y),Vector2.DOWN,output)
		_line(Vector2(r.position.x,r.end.y),r.position,Vector2.LEFT,output)
	elif s.kind=="circle": _arc(s.center,s.radius,0,TAU,output)
	else:
		var a := Vector2(s.from)
		var b := Vector2(s.to)
		var radius := float(s.radius)
		if a.distance_squared_to(b)<EPS:
			_arc(a,radius,0,TAU,output)
			return
		var axis := (b-a).normalized()
		var normal := axis.rotated(PI*0.5)
		_line(a+normal*radius,b+normal*radius,normal,output)
		_line(a-normal*radius,b-normal*radius,-normal,output)
		_arc(a,radius,axis.angle()+PI*0.5,PI,output)
		_arc(b,radius,axis.angle()-PI*0.5,PI,output)
func _cells(rect: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	for x in range(int(floor(rect.position.x/CELL)),int(floor(rect.end.x/CELL))+1):
		for y in range(int(floor(rect.position.y/CELL)),int(floor(rect.end.y/CELL))+1): result.append(Vector2i(x,y))
	return result
