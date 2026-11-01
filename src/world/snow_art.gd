extends RefCounted
## PLACEHOLDER art for Snow Mountain surfaces (Milestone 05 Stage C), painted in code at
## load time: presentation only, never saved, never a final asset. Each kind gets its own
## seamless 40 px texture (periodic value noise) instead of a recoloured grass tile, and
## snow/frozen-ground edges get ragged 8-neighbour transition overlays. Replace with the
## approved art batch (docs/lands/SNOW_MOUNTAIN_ASSET_REQUEST.md); the manifest keeps
## snow:art/* incomplete until then.
const VARIANTS := {"snow": 4, "ice": 3, "frozen": 3, "trail": 2, "cliff": 2, "cliff_face": 2, "floor": 1, "timber": 1}
## Overlay pairs: [upper kind drawn as ragged edges, lower kinds it spills onto].
const EDGES := [["frozen", ["ice", "trail"]], ["snow", ["ice", "frozen", "trail", "taiga", "floor"]]]

static func _hash(x: int, y: int, salt: int) -> int:
	var value := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return value ^ (value >> 16)

static func _noise(x: int, y: int, cell: int, period: int, salt: int) -> float:
	## Periodic value noise in 0..1: wraps every `period` cells, so tiles are seamless.
	var gx := x / cell
	var gy := y / cell
	var fx := float(x % cell) / cell
	var fy := float(y % cell) / cell
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_corner(gx, gy, period, salt), _corner(gx + 1, gy, period, salt), fx), lerpf(_corner(gx, gy + 1, period, salt), _corner(gx + 1, gy + 1, period, salt), fx), fy)

static func _corner(cx: int, cy: int, period: int, salt: int) -> float:
	return float(_hash(posmod(cx, period), posmod(cy, period), salt) % 1000) / 999.0

static func paint(kind: String, variant: int, px: int) -> Image:
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	## Variants share their kind's noise along the tile edges and differ only inside, so any
	## two variants placed side by side join without a seam.
	var shared := kind.hash() % 9973
	var salt := shared + variant * 131
	var cell := maxi(2, px / 8)
	var fine_cell := maxi(1, cell / 2)
	for y in px:
		for x in px:
			var edge := float(mini(mini(x, px - 1 - x), mini(y, px - 1 - y))) / (px * 0.3)
			var inner := smoothstep(0.0, 1.0, edge) if variant > 0 else 0.0
			var n := lerpf(_noise(x, y, cell, px / cell, shared), _noise(x, y, cell, px / cell, salt), inner)
			var fine := lerpf(_noise(x, y, fine_cell, px / fine_cell, shared + 7), _noise(x, y, fine_cell, px / fine_cell, salt + 7), inner)
			var speck := _hash(x, y, salt + 3) % 1000
			image.set_pixel(x, y, _color(kind, variant, x, y, px, n, fine, speck, salt))
	return image

static func _color(kind: String, variant: int, x: int, y: int, px: int, n: float, fine: float, speck: int, salt: int) -> Color:
	match kind:
		"snow":
			var base := Color(0.93, 0.95, 0.98).lerp(Color(0.79, 0.85, 0.93), clampf(n * 1.3 - 0.35, 0.0, 1.0))
			if variant == 3 and x > 4 and y > 4 and x < px - 5 and y < px - 5 and absf(sin((x + y * 0.5) * TAU / px * 2.0 + n * 2.0)) < 0.12: base = base.darkened(0.07) # Wind ripple.
			if speck < 12: return Color(1, 1, 1)
			if speck > 992: return base.darkened(0.12)
			return base.lerp(Color(0.86, 0.9, 0.96), fine * 0.25)
		"ice":
			var ice := Color(0.66, 0.86, 0.93).lerp(Color(0.42, 0.66, 0.82), clampf(n * 1.4 - 0.3, 0.0, 1.0))
			var interior := x > 3 and y > 3 and x < px - 4 and y < px - 4
			var crack := interior and variant > 0 and absf(float((x * 3 + y * 2 + salt) % px) - px * 0.5) < 0.6 and fine > 0.45
			if crack or speck < 8: return Color(0.93, 0.98, 1.0)
			return ice
		"frozen":
			var ground := Color(0.6, 0.62, 0.65).lerp(Color(0.47, 0.49, 0.53), n)
			if fine > 0.74: return Color(0.43, 0.44, 0.47).lerp(Color(0.7, 0.71, 0.73), clampf((fine - 0.74) * 6.0, 0.0, 1.0)) # Scree stone, lit top.
			if n < 0.3: return ground.lerp(Color(0.88, 0.91, 0.95), 0.6) # Frost in the hollows.
			if speck < 18: return Color(0.9, 0.93, 0.97)
			return ground
		"trail":
			var packed := Color(0.84, 0.83, 0.79).lerp(Color(0.74, 0.72, 0.68), n * 0.8)
			var print_x := posmod(x - (y / 10 % 2) * 5, 10)
			if print_x in [3, 4] and posmod(y, 10) in [2, 3, 4]: return packed.darkened(0.14) # Tramped prints.
			return packed if speck > 15 else Color(0.95, 0.95, 0.94)
		"cliff":
			var rock := Color(0.33, 0.37, 0.45).lerp(Color(0.24, 0.27, 0.34), n)
			if n > 0.62: return Color(0.9, 0.93, 0.97).lerp(Color(0.78, 0.84, 0.92), fine * 0.6) # Snow on the shelf.
			if fine < 0.12: return rock.darkened(0.25)
			return rock
		"cliff_face":
			var t := float(y) / px
			var face := Color(0.36, 0.4, 0.49).lerp(Color(0.17, 0.19, 0.25), t)
			if y < 4 + int(fine * 3): return Color(0.92, 0.95, 0.99) # Snow lip.
			if posmod(x + int(n * 6), 9) == 0: return face.darkened(0.35) # Vertical fissures.
			if y < 9 and posmod(x * 7, 11) == 0: return Color(0.78, 0.9, 0.98) # Icicles.
			return face.lerp(face.lightened(0.15), fine * 0.5)
		"floor":
			var plank := Color(0.56, 0.41, 0.27).lerp(Color(0.46, 0.33, 0.21), fine)
			if posmod(y, 8) == 0: return Color(0.28, 0.19, 0.12)
			if posmod(y, 8) == 4 and posmod(x + y, 13) == 0: return Color(0.22, 0.2, 0.2) # Nail.
			return plank
		"timber":
			var row := posmod(y, 10)
			if y < 5 + int(fine * 2): return Color(0.92, 0.95, 0.99) # Snow on the wall top.
			var log := Color(0.36, 0.24, 0.15).lerp(Color(0.22, 0.14, 0.09), absf(float(row) - 4.5) / 4.5)
			return log.darkened(0.3) if row == 0 else log
	return Color.MAGENTA

static func edge_pieces(upper: Image, px: int, salt: int) -> Array:
	## Eight alpha-shaped copies of `upper`: N, E, S, W bands and NE, SE, SW, NW corners
	## (bit order of map_view's overlay masks). Ragged, periodic-noise edges.
	var pieces: Array = []
	var corners := [Vector2(px, 0), Vector2(px, px), Vector2(0, px), Vector2(0, 0)]
	for bit in 8:
		var piece := Image.create(px, px, false, Image.FORMAT_RGBA8)
		for y in px:
			for x in px:
				var inside := false
				if bit < 4:
					var along: int = [x, y, x, y][bit]
					var depth: int = [y, px - 1 - x, px - 1 - y, x][bit]
					inside = depth < int(px * 0.16 + _noise(along, bit, maxi(2, px / 8), 8, salt + bit) * px * 0.16)
				else:
					var corner: Vector2 = corners[bit - 4]
					inside = Vector2(x + 0.5, y + 0.5).distance_to(corner) < px * 0.22 + float(_hash(x, y, salt) % 3)
				if inside:
					var color := upper.get_pixel(x, y)
					piece.set_pixel(x, y, color)
		pieces.append(piece)
	return pieces

static func overlay_atlas(pieces: Array, px: int) -> Image:
	## 16 x 16 cells indexed by the 8-neighbour mask (cell 0 empty), like build_assets.py.
	var atlas := Image.create(px * 16, px * 16, false, Image.FORMAT_RGBA8)
	var whole := Rect2i(0, 0, px, px)
	for mask in range(1, 256):
		var at := Vector2i(mask % 16, mask / 16) * px
		for bit in 8:
			if mask & (1 << bit):
				atlas.blend_rect(pieces[bit], whole, at)
	return atlas
