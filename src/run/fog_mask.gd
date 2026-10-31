extends RefCounted
## Explored-tile persistence (Milestone 02 final). Run State `explored` keeps its place
## in the six-field contract, but entries may be either a legacy tile {"x","y"} or one
## chunk record {"chunk": {"x","y"}, "mask": base64 of 128 bytes (1024 bits, row-major
## 32x32)}. Saves write chunk records only, so save size and time grow with explored
## chunks instead of tiles. Readers accept both forms; legacy saves convert on their
## next save. Nothing else about fog/discovery changes.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Data = preload("res://src/data/json_data.gd")
const BYTES := 128
const MASK_LENGTH := 172 # Base64 length of 128 bytes.

static func is_chunk(entry: Variant) -> bool:
	return entry is Dictionary and entry.has("mask")

static func valid(entry: Variant) -> bool:
	if not is_chunk(entry):
		return Data.position(entry)
	if entry.size() != 2 or not Data.position(entry.get("chunk")) or not entry.mask is String or entry.mask.length() != MASK_LENGTH:
		return false
	var chunk: Dictionary = entry.chunk
	return absf(float(chunk.x)) * Terrain.CHUNK_SIZE <= Terrain.LIMIT + Terrain.CHUNK_SIZE and absf(float(chunk.y)) * Terrain.CHUNK_SIZE <= Terrain.LIMIT + Terrain.CHUNK_SIZE and Marshalls.base64_to_raw(entry.mask).size() == BYTES

static func valid_all(explored: Array) -> bool:
	## Fast path for saves: chunk records are few, legacy tiles are plain positions.
	for entry in explored:
		if not valid(entry):
			return false
	return true

static func decode(explored: Array) -> Dictionary:
	## {"tiles": {Vector2i: true}, "masks": {chunk Vector2i: PackedByteArray}}.
	var tiles := {}
	var masks := {}
	for entry in explored:
		if is_chunk(entry):
			var chunk := Vector2i(int(entry.chunk.x), int(entry.chunk.y))
			var bytes: PackedByteArray = Marshalls.base64_to_raw(entry.mask)
			var merged: PackedByteArray = masks.get(chunk, _empty())
			var origin := chunk * Terrain.CHUNK_SIZE
			for index in BYTES:
				merged[index] |= bytes[index]
				if bytes[index] == 0: continue
				for bit in 8:
					if bytes[index] & (1 << bit):
						var local := index * 8 + bit
						tiles[origin + Vector2i(local % Terrain.CHUNK_SIZE, local / Terrain.CHUNK_SIZE)] = true
			masks[chunk] = merged
		else:
			var tile := Vector2i(int(entry.x), int(entry.y))
			tiles[tile] = true
			mark(masks, tile)
	return {"tiles": tiles, "masks": masks}

static func mark(masks: Dictionary, tile: Vector2i) -> Vector2i:
	## Sets the tile's bit; returns its chunk.
	var chunk := Terrain.chunk_of(tile)
	if not masks.has(chunk):
		masks[chunk] = _empty()
	var local := Terrain.local_of(tile)
	var index := local.y * Terrain.CHUNK_SIZE + local.x
	var bytes: PackedByteArray = masks[chunk]
	bytes[index / 8] |= 1 << (index % 8)
	masks[chunk] = bytes
	return chunk

static func entry(chunk: Vector2i, bytes: PackedByteArray) -> Dictionary:
	return {"chunk": {"x": chunk.x, "y": chunk.y}, "mask": Marshalls.raw_to_base64(bytes)}

static func chunks(explored: Array) -> Dictionary:
	## Chunks holding at least one explored tile (both forms), without expanding bits.
	var result := {}
	for item in explored:
		if is_chunk(item):
			result[Vector2i(int(item.chunk.x), int(item.chunk.y))] = true
		elif Data.position(item):
			result[Terrain.chunk_of(Vector2i(int(item.x), int(item.y)))] = true
	return result

static func count(explored: Array) -> int:
	var total := 0
	for item in explored:
		if is_chunk(item):
			for value in Marshalls.base64_to_raw(item.mask):
				while value:
					total += value & 1
					value >>= 1
		else:
			total += 1
	return total

static func _empty() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(BYTES)
	return bytes
