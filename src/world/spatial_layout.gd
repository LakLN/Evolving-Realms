extends RefCounted
## Spatial layout v1. Discrete heights, authored surfaces and directed connectors.
## Stored only in NEW terrain-v3 plans; no Run mutations or legacy plan changes.
const S = preload("res://src/world/surfaces.gd")
const Data = preload("res://src/data/json_data.gd")

static func validate(plan: Dictionary) -> String:
	if plan.get("version") != 1 or not Data.position(plan.get("origin")) or not Data.position(plan.get("size")): return "Unsupported spatial layout version or coordinates"
	var bounds := Rect2i(0,0,int(plan.size.x),int(plan.size.y))
	if bounds.size.x < 1 or bounds.size.y < 1 or bounds.size.x > 128 or bounds.size.y > 128: return "Spatial layout size outside 1..128"
	if not plan.get("zones") is Array or not plan.get("transitions") is Array: return "Spatial zones and transitions required"
	for zone in plan.zones:
		if not zone is Dictionary or not zone.get("rect") is Array or zone.rect.size()!=4 or not zone.rect.all(func(v: Variant)->bool:return Data.integer(v)): return "Invalid spatial rectangle"
		var r:=Rect2i(int(zone.rect[0]),int(zone.rect[1]),int(zone.rect[2]),int(zone.rect[3]))
		if r.size.x<1 or r.size.y<1 or not bounds.encloses(r) or not Data.integer(zone.get("height")) or zone.height<0 or zone.height>8 or not S.BY_NAME.has(zone.get("surface")) or not zone.get("style") is String: return "Spatial zone outside supported bounds"
	for edge in plan.transitions:
		if not edge is Dictionary or not edge.get("a") is Array or not edge.get("b") is Array or edge.a.size()!=2 or edge.b.size()!=2: return "Invalid spatial connector"
		if not (edge.a+edge.b).all(func(v: Variant)->bool:return Data.integer(v)) or not edge.get("one_way",false) is bool: return "Invalid spatial connector coordinates/direction"
		var a:=Vector2i(int(edge.a[0]),int(edge.a[1]))
		var b:=Vector2i(int(edge.b[0]),int(edge.b[1]))
		if not bounds.has_point(a) or not bounds.has_point(b) or absi(a.x-b.x)+absi(a.y-b.y)!=1: return "Spatial connector must join adjacent cells"
	return ""

static func local(plan: Dictionary, tile: Vector2i) -> Vector2i:
	return tile - Vector2i(int(plan.origin.x), int(plan.origin.y))

static func cell(plan: Dictionary, tile: Vector2i) -> Dictionary:
	var p := local(plan, tile)
	if not Rect2i(0, 0, int(plan.size.x), int(plan.size.y)).has_point(p): return {}
	var result := {"height": 0, "surface": S.SNOW, "style": "snow"}
	for zone in plan.zones:
		var r: Array = zone.rect
		if Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])).has_point(p):
			result = {"height": int(zone.height), "surface": S.BY_NAME[zone.surface], "style": zone.style}
	return result

static func connector(plan: Dictionary, from: Vector2i, to: Vector2i, drops: bool = true) -> bool:
	var a := local(plan, from)
	var b := local(plan, to)
	for edge in plan.transitions:
		var start := Vector2i(int(edge.a[0]), int(edge.a[1]))
		var end := Vector2i(int(edge.b[0]), int(edge.b[1]))
		if edge.get("one_way", false):
			if drops and a == start and b == end: return true
		elif (a == start and b == end) or (a == end and b == start): return true
	return false
