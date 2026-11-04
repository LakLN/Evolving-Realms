extends RefCounted
## Frozen v1 algorithm. Integer value-noise, independent coordinate hash streams.
const CHUNK_SIZE := 32
const LIMIT := 1000000
const FOREST := 0
const BEACH := 1
const MEADOW := 2
const WATER := 3
const TREE := 4
const ROCK := 5
const BIOMES := ["forest", "beach", "meadow"]
var world_seed := 0
var last_error := ""

func configure(seed_value: int, generation_version: int) -> bool:
	if generation_version != 1 or seed_value < -2147483648 or seed_value > 2147483647:
		last_error = "Unsupported terrain generator or world seed"
		return false
	world_seed = seed_value
	last_error = ""
	return true

static func chunk_of(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(float(tile.x) / CHUNK_SIZE), floori(float(tile.y) / CHUNK_SIZE))

static func local_of(tile: Vector2i) -> Vector2i:
	return Vector2i(posmod(tile.x, CHUNK_SIZE), posmod(tile.y, CHUNK_SIZE))

static func in_bounds(tile: Vector2i) -> bool:
	return absi(tile.x) <= LIMIT and absi(tile.y) <= LIMIT

func coordinate_hash(x: int, y: int, stream: int) -> int:
	var value := (world_seed & 0xffffffff) ^ ((x * 73856093) & 0xffffffff) ^ ((y * 19349663) & 0xffffffff) ^ ((stream * 83492791) & 0xffffffff)
	value = ((value ^ (value >> 13)) * 1103515245 + 12345) & 0xffffffff
	return (value ^ (value >> 16)) & 0x7fffffff

func stream_seed(stream: int) -> int:
	## Seed/stream part of coordinate_hash. Hot placement loops XOR in the x/y parts and
	## inline the same mixing (see roll_rules) instead of one call per tile and rule.
	return (world_seed & 0xffffffff) ^ ((stream * 83492791) & 0xffffffff)

static func roll_rules(seeds: PackedInt64Array, chances: PackedInt32Array, x: int, y: int) -> PackedInt32Array:
	## Indexes of rules whose coordinate_hash(x, y, stream) % 10000 < chance, in order.
	## Exactly coordinate_hash's arithmetic; most tiles return an empty array.
	var xy := ((x * 73856093) & 0xffffffff) ^ ((y * 19349663) & 0xffffffff)
	var hits := PackedInt32Array()
	for i in seeds.size():
		var value: int = seeds[i] ^ xy
		value = ((value ^ (value >> 13)) * 1103515245 + 12345) & 0xffffffff
		if ((value ^ (value >> 16)) & 0x7fffffff) % 10000 < chances[i]:
			hits.append(i)
	return hits

func _noise(tile: Vector2i, scale: int, stream: int) -> int:
	var cell := Vector2i(floori(float(tile.x) / scale), floori(float(tile.y) / scale))
	var tx := int(posmod(tile.x, scale) * 1024 / scale)
	var ty := int(posmod(tile.y, scale) * 1024 / scale)
	tx = int(tx * tx * (3072 - 2 * tx) / 1048576)
	ty = int(ty * ty * (3072 - 2 * ty) / 1048576)
	var a := coordinate_hash(cell.x, cell.y, stream) % 1024
	var b := coordinate_hash(cell.x + 1, cell.y, stream) % 1024
	var c := coordinate_hash(cell.x, cell.y + 1, stream) % 1024
	var d := coordinate_hash(cell.x + 1, cell.y + 1, stream) % 1024
	var upper := a * (1024 - tx) + b * tx
	var lower := c * (1024 - tx) + d * tx
	return int((upper * (1024 - ty) + lower * ty) / 1048576)

func ground_at(tile: Vector2i) -> int:
	if not in_bounds(tile):
		return WATER
	var elevation := int((3 * _noise(tile, 96, 11) + _noise(tile, 32, 12)) / 4)
	if elevation < 340:
		return WATER
	if elevation < 425:
		return BEACH
	return FOREST if _noise(tile, 72, 21) >= 500 else MEADOW

func biome_at(tile: Vector2i) -> String:
	var ground := ground_at(tile)
	return "ocean" if ground == WATER else BIOMES[ground]

func tile_at(tile: Vector2i) -> int:
	var ground := ground_at(tile)
	if ground == WATER:
		return WATER
	var feature := coordinate_hash(tile.x, tile.y, 31) % 100
	if ground == FOREST and feature < 13:
		return TREE
	if feature >= 97:
		return ROCK
	return ground

func walkable(tile: Vector2i) -> bool:
	return tile_at(tile) in [FOREST, BEACH, MEADOW]

func opaque(tile: Vector2i) -> bool:
	return tile_at(tile) in [TREE, ROCK]

func generate_chunk(chunk: Vector2i) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(CHUNK_SIZE * CHUNK_SIZE)
	for y in CHUNK_SIZE:
		for x in CHUNK_SIZE:
			result[y * CHUNK_SIZE + x] = tile_at(chunk * CHUNK_SIZE + Vector2i(x, y))
	return result
