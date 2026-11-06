extends Node2D
## Coordinated native pixel environment for spatial-layout v1, underneath actors,
## objects and fog. Geometry comes from the same plan used by collision/navigation.
var view: Node2D
var materials: Texture2D
var composed := {} # resource path -> Texture2D or null (missing)
var composition_manifest := {} # layout version/area -> validated layer specification
var artpass_manifest := {} # Opt-in Broken Relay v10 preview; never affects Windcut.
var artpass_v3 := "--artpass-v3" in OS.get_cmdline_user_args()
var artbase_v11 := "--broken-relay-v11-artbase" in (OS.get_cmdline_user_args() + OS.get_cmdline_args())
const ARTBASE_GROUND := "res://assets/game/snow/reference/v11_artbase/organic_ground_preview.png"
var architecture_v4 := "--broken-relay-v11-architecture-v4" in (OS.get_cmdline_user_args() + OS.get_cmdline_args())
const V11_FACADE := "res://assets/game/snow/reference/v11_architecture_v4/outpost_facade_480x240.png"
const V11_ROOF := "res://assets/game/snow/reference/v11_architecture_v4/outpost_roof_only_480x240.png"
## Roof mode: draws each area's roof layer above actors instead of its ground.
var roofs := false
const TerrainAtlas = preload("res://src/world/terrain_atlas.gd")
const COMPOSITION_MANIFEST := "res://assets/game/snow/reference/environment_manifest.json"
const ARTPASS_MANIFEST := "res://assets/game/snow/reference/artpass_v3_manifest.json"
const SNOW := Color("dce7e5")
const SHADOW := Color("bdcdd0")
const STONE := Color("64747e")
const WOOD := Color("756456")

func _material(rect: Rect2, index: int, tile: Vector2i) -> void:
	if materials == null: return
	var uv := Vector2((index%4)*160+posmod(tile.x,4)*40,(index/4)*160+posmod(tile.y,4)*40)
	# The path sample contains snow at its outer edge; sample only its earth core.
	if index == 1: uv = Vector2(180+posmod(tile.x,3)*30,20+posmod(tile.y,3)*30)
	draw_texture_rect_region(materials,rect,Rect2(uv,Vector2(40,40)))

func _load_composition_manifest() -> void:
	if not composition_manifest.is_empty(): return
	var file := FileAccess.open(COMPOSITION_MANIFEST, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1 or int(parsed.get("tile_px", 0)) < 1:
		composition_manifest = {"_loaded": true}
		push_warning("Environment composition manifest is missing or unsupported")
		return
	composition_manifest = {"_loaded": true, "tile_px": int(parsed.tile_px), "layout_id": str(parsed.get("layout_id", ""))}
	for entry in parsed.get("compositions", []):
		if not entry is Dictionary or not entry.get("size_tiles") is Array or entry.size_tiles.size() != 2: continue
		composition_manifest["%d/%s" % [int(entry.get("layout_version", 0)), str(entry.get("area", "default"))]] = entry

func _load_artpass_manifest() -> void:
	if not artpass_manifest.is_empty(): return
	var file := FileAccess.open(ARTPASS_MANIFEST, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not parsed is Dictionary or int(parsed.get("layout_version", 0)) != 10 or int(parsed.get("tile_px", 0)) != 40 or not parsed.get("patch_tiles") is Array or parsed.patch_tiles.size() != 2:
		artpass_manifest = {"_loaded": true}
		push_warning("Broken Relay Art Pass V3 manifest is missing or unsupported")
		return
	artpass_manifest = parsed

func _artpass_composition(land: Dictionary, patch: Dictionary, layer: String, px: int) -> Texture2D:
	if not artpass_v3 or patch.has("id"): return null # Default Broken Relay only; Windcut is unchanged.
	_load_artpass_manifest()
	if str(land.get("layout", {}).get("id", "")) != str(artpass_manifest.get("layout_id", "")) or int(land.get("layout", {}).get("version", 0)) != int(artpass_manifest.get("layout_version", -1)) or px != int(artpass_manifest.get("tile_px", -1)) or not artpass_manifest.has(layer):
		return null
	var key := "res://assets/game/" + str(artpass_manifest[layer])
	if not composed.has(key): composed[key] = load(key) if ResourceLoader.exists(key) else null
	var texture: Texture2D = composed[key]
	if texture == null: return null
	var expected := Vector2i(int(artpass_manifest.patch_tiles[0]), int(artpass_manifest.patch_tiles[1])) * px
	if texture.get_width() != expected.x or texture.get_height() != expected.y:
		push_warning("Art Pass V3 %s is %dx%d; expected %dx%d" % [key, texture.get_width(), texture.get_height(), expected.x, expected.y])
		return null
	return texture

func _composition(land: Dictionary, patch: Dictionary, layer: String, px: int) -> Texture2D:
	if artbase_v11 and layer == "ground" and not patch.has("id") and int(land.get("layout", {}).get("version", 0)) == 11 and px == 40:
		if not composed.has(ARTBASE_GROUND): composed[ARTBASE_GROUND] = load(ARTBASE_GROUND) if ResourceLoader.exists(ARTBASE_GROUND) else null
		var artbase: Texture2D = composed[ARTBASE_GROUND]
		if artbase != null and artbase.get_width() == 1920 and artbase.get_height() == 1600: return artbase
	var preview := _artpass_composition(land, patch, layer, px)
	if preview != null: return preview
	_load_composition_manifest()
	if str(land.get("layout", {}).get("id", "")) != str(composition_manifest.get("layout_id", "")) or px != int(composition_manifest.get("tile_px", -1)):
		return null
	var area := str(patch.get("id", "default"))
	var spec: Dictionary = composition_manifest.get("%d/%s" % [int(land.get("layout", {}).get("version", 0)), area], {})
	if spec.is_empty() or not spec.has(layer): return null
	var key := "res://assets/game/" + str(spec[layer])
	if not composed.has(key): composed[key] = load(key) if ResourceLoader.exists(key) else null
	var texture: Texture2D = composed[key]
	if texture == null: return null
	var expected := Vector2i(int(spec.size_tiles[0]), int(spec.size_tiles[1])) * px
	if texture.get_width() != expected.x or texture.get_height() != expected.y:
		push_warning("Environment composition %s is %dx%d; expected %dx%d" % [key, texture.get_width(), texture.get_height(), expected.x, expected.y])
		return null
	return texture

static func under_roof(land: Dictionary, tile: Vector2i) -> bool:
	## The hero is inside a composed building or tucked behind its roofline.
	if TerrainAtlas.patches(land).is_empty(): return false
	for shelter in land.get("geography", {}).get("shelters", []):
		var r: Dictionary = shelter.rect
		if Rect2i(int(r.x) - 1, int(r.y) - 2, int(r.w) + 2, int(r.h) + 1).has_point(tile): return true
	return false

func _draw() -> void:
	if view == null or view.session == null: return
	var terrain: RefCounted = view.session.terrain
	var land: Dictionary = terrain.land_at(view.session.position) if terrain.has_method("land_at") else {}
	if TerrainAtlas.patches(land).is_empty(): return
	if materials == null and ResourceLoader.exists("res://assets/game/snow/reference/materials.png"): materials=load("res://assets/game/snow/reference/materials.png")
	var px: int = view.px
	var artbase_active := artbase_v11 and int(land.get("layout", {}).get("version", 0)) == 11
	# A composed painting of exactly this layout version (and area) replaces the cell sketch.
	var sketch := false
	for patch in TerrainAtlas.patches(land):
		var texture := _composition(land, patch, "roof" if roofs else "ground", px)
		if texture != null:
			draw_texture(texture, view._point(Vector2i(int(patch.origin.x), int(patch.origin.y))) - Vector2.ONE * px / 2)
			if artbase_active and not roofs and not patch.has("id"): sketch = true
		elif not patch.has("id"): sketch = true
	if roofs:
		# v11 has no approved roof/rail sprites yet. Keep these occluders isolated
		# above actors so the architecture is correct without flattening a facade
		# into the roof layer. ASSET_GAPS.md marks this visible blockout as non-final.
		if int(land.get("layout", {}).get("version", 0)) == 11 and architecture_v4:
			var plan: Dictionary = land.spatial
			var origin := Vector2i(int(plan.origin.x), int(plan.origin.y))
			var at: Vector2 = view._point(origin + Vector2i(18, 11)) - Vector2.ONE * px / 2
			var roof: Texture2D = load(V11_ROOF) if ResourceLoader.exists(V11_ROOF) else null
			if roof != null and roof.get_size() == Vector2(480, 240): draw_texture(roof, at)
		elif int(land.get("layout", {}).get("version", 0)) == 11:
			var plan: Dictionary = land.spatial
			var origin := Vector2i(int(plan.origin.x), int(plan.origin.y))
			var roof: Vector2 = view._point(origin + Vector2i(18, 11)) - Vector2.ONE * px / 2
			draw_colored_polygon(PackedVector2Array([roof+Vector2(-8,18), roof+Vector2(px*6,-44), roof+Vector2(px*12+8,18), roof+Vector2(px*12+8,px*2), roof+Vector2(-8,px*2)]), Color("d9e5e2"))
			draw_polyline(PackedVector2Array([roof+Vector2(-8,18), roof+Vector2(px*6,-44), roof+Vector2(px*12+8,18)]), Color("68757a"), 4)
			# Only the near bridge rail belongs above actors; deck stays in ground.
			var rail_a: Vector2 = view._point(origin + Vector2i(20, 32)) + Vector2(-px/2, px/3)
			var rail_b: Vector2 = view._point(origin + Vector2i(30, 32)) + Vector2(px/2, px/3)
			draw_line(rail_a, rail_b, Color("51483f"), 6)
			for x in range(11): draw_line(rail_a+Vector2(x*px,0), rail_a+Vector2(x*px,13), Color("6d5b49"), 4)
		return
	if not sketch: return
	var plan: Dictionary = land.spatial
	var origin := Vector2i(int(plan.origin.x), int(plan.origin.y))
	var size := Vector2i(int(plan.size.x), int(plan.size.y))
	for y in size.y:
		for x in size.x:
			var tile := origin + Vector2i(x, y)
			var c: Dictionary = terrain.spatial_cell(tile)
			var at: Vector2 = view._point(tile) - Vector2.ONE * px / 2
			var rect := Rect2(at, Vector2.ONE * px)
			# The opaque artbase owns ordinary ground and water. Retain the existing
			# grounded cliff/stair/bridge and architecture drawing above it.
			if artbase_active and c.style not in ["cliff", "stairs", "ledge", "bridge", "floor", "timber"]: continue
			# The V4 facade replaces old timber wall cells; floor remains walkable and
			# visible through the transparent architecture canvas.
			if architecture_v4 and c.style == "timber": continue
			draw_rect(rect, SNOW)
			_material(rect,0,tile)
			# Snow is resting space. Suppress the sample's repetitive diagonal ridges.
			draw_rect(rect,Color(0.88,0.92,0.91,0.9))
			match c.style:
				"snow", "terrace", "grove":
					# Large calm snow fields, a few wind lines, no repeating gravel stamp.
					if (x * 17 + y * 11) % 13 == 0:
						draw_line(at + Vector2(8, 23), at + Vector2(21, 22), Color("cbdad9"), 1)
				"trail", "stairs", "ledge":
					_material(rect,1,tile)
					draw_rect(rect,Color(0.52,0.52,0.49,0.42))
					# Only the outside of the route has a snow fringe; no cell borders.
					for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
						if terrain.spatial_cell(tile+direction).get("style","") in ["trail","stairs","ledge","bridge","floor"]: continue
						for k in 10:
							var depth: int = 2+(x*7+y*11+k*3)%5
							var edge: Vector2 = at+Vector2(k*4,0 if direction.y<0 else px-depth) if direction.y!=0 else at+Vector2(0 if direction.x<0 else px-depth,k*4)
							draw_rect(Rect2(edge,Vector2(4,depth) if direction.y!=0 else Vector2(depth,4)),SNOW)
					if c.style == "stairs":
						for i in 4:
							draw_rect(Rect2(at + Vector2(0, i*10), Vector2(px, 3)), Color("6a7a7e"))
							draw_rect(Rect2(at + Vector2(0, i*10+3), Vector2(px, 2)), Color("edf2e8"))
					if c.style == "ledge":
						draw_rect(Rect2(at + Vector2(0, px-8), Vector2(px, 8)), STONE)
						draw_line(at + Vector2(10, px-6), at + Vector2(20, px-2), Color("e7e6ca"), 2)
						draw_line(at + Vector2(20, px-2), at + Vector2(30, px-6), Color("e7e6ca"), 2)
				"cliff":
					draw_rect(rect, Color("586b78"))
					_material(rect,2,tile)
					# A north-facing rim is mostly the snowy top, not a wall facing inward.
					if terrain.elevation(tile+Vector2i.DOWN)>terrain.elevation(tile+Vector2i.UP):
						draw_rect(Rect2(at+Vector2(0,14),Vector2(px,px-14)),SNOW)
					for i in 4:
						var shift: int = (y + i) % 2 * 11
						if materials==null: draw_line(at + Vector2(9+shift, 13+i*8), at + Vector2(12+shift, 20+i*8), Color("405463"), 2)
					if terrain.spatial_cell(tile+Vector2i.UP).get("style","") != "cliff":
						draw_rect(Rect2(at, Vector2(px, 6)), Color("f0f3e8"))
						draw_rect(Rect2(at + Vector2(0, 6), Vector2(px, 3)), SHADOW)
				"ravine":
					draw_rect(rect, Color("2c4659"))
					_material(rect,6,tile)
				"bridge":
					draw_rect(rect, Color("415361"))
					_material(rect,7,tile)
					if terrain.spatial_cell(tile+Vector2i.UP).get("style")!="bridge": draw_rect(Rect2(at,Vector2(px,4)),Color("b9b8a1"))
					if terrain.spatial_cell(tile+Vector2i.DOWN).get("style")!="bridge": draw_rect(Rect2(at+Vector2(0,px-4),Vector2(px,4)),Color("4c423c"))
				"floor":
					draw_rect(rect, Color("8a7964"))
					_material(rect,3,tile)
					draw_rect(rect,Color(0.16,0.19,0.19,0.28))
				"timber":
					draw_rect(rect, Color("4d4b46"))
					for i in 4: draw_rect(Rect2(at+Vector2(2,i*10+1),Vector2(px-4,7)),WOOD)
					_material(rect,5,tile)
					draw_rect(rect,Color(0.12,0.19,0.23,0.3))
					if terrain.spatial_cell(tile+Vector2i.UP).get("style","") != "timber":
						draw_rect(Rect2(at,Vector2(px,6)),Color("e4eae2"))
						draw_rect(Rect2(at+Vector2(0,6),Vector2(px,5)),Color("665b4d"))
	# A cutaway outpost: masonry footings, timber walls and a pitched snow roof on
	# the north section, with the reachable floor/doors clearly visible beneath it.
	if architecture_v4:
		var facade: Texture2D = load(V11_FACADE) if ResourceLoader.exists(V11_FACADE) else null
		var facade_at: Vector2 = view._point(origin + Vector2i(18, 11)) - Vector2.ONE * px / 2
		if facade != null and facade.get_size() == Vector2(480, 240): draw_texture(facade, facade_at)
	else:
		var roof: Vector2 = view._point(origin+Vector2i(18,10)) - Vector2.ONE*px/2
		var w := px*10.0
		draw_rect(Rect2(roof+Vector2(7,9),Vector2(w,px*2.6)),Color(0.1,0.18,0.22,0.22))
		for ry in 3:
			for rx in 10: _material(Rect2(roof+Vector2(rx*px,ry*px-34),Vector2(px,px)),4,origin+Vector2i(rx,ry))
		draw_rect(Rect2(roof+Vector2(-7,-36),Vector2(w+14,7)),Color("f0f2e8"))
		draw_rect(Rect2(roof+Vector2(-7,px*2),Vector2(w+14,6)),Color("c1cfcb"))
		draw_rect(Rect2(roof+Vector2(0,px*2),Vector2(w,7)),Color("514f46"))
	# Reuse the accepted snow-pine atlas at its real native scale, in authored banks.
	var texture: Texture2D = view.art.texture("snow/props.png")
	if texture != null:
		for zone in plan.zones:
			if zone.style not in ["grove","rock"]: continue
			var tile := origin+Vector2i(int(zone.rect[0]),int(zone.rect[1]))
			var feet: Vector2 = view._feet(tile)
			draw_texture_rect_region(texture,Rect2(feet-Vector2(48,84),Vector2(96,96)),Rect2(0 if zone.style=="grove" else 96,0,96,96))
