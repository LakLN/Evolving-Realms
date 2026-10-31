extends RefCounted
## Small code-native placeholder atlas; no imported art or runtime network access.
const SIZE := 32
const UNSEEN := 6
const REMEMBERED := 7

static func make_tileset() -> TileSet:
	var image := Image.create(SIZE * 8, SIZE, false, Image.FORMAT_RGBA8)
	var colors := [Color("345d40"), Color("c5b480"), Color("74874c"), Color("28546c"), Color("345d40"), Color("74874c"), Color("101820"), Color(0.02, 0.03, 0.05, 0.72)]
	for tile in 8:
		for y in SIZE:
			for x in SIZE:
				var color: Color = colors[tile]
				if tile < 6:
					if (x * 13 + y * 7) % 29 == 0:
						color = color.lightened(0.09)
					if x == 0 or y == 0:
						color = color.darkened(0.07)
				if tile == 3 and y % 11 == 4 and x % 16 > 4:
					color = Color("426e82")
				if tile == 4:
					if x in range(14, 19) and y in range(19, 29):
						color = Color("68563d")
					if Vector2(x - 16, y - 12).length_squared() < 110:
						color = Color("193b2f") if x < 16 else Color("24503a")
				if tile == 5 and Vector2((x - 16) * 0.85, y - 18).length_squared() < 100:
					color = Color("777f80") if x + y < 32 else Color("4a555c")
				image.set_pixel(tile * SIZE + x, y, color)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = Vector2i(SIZE, SIZE)
	var result := TileSet.new()
	result.tile_size = Vector2i(SIZE, SIZE)
	result.add_source(atlas, 0)
	for tile in 8:
		atlas.create_tile(Vector2i(tile, 0))
	return result
