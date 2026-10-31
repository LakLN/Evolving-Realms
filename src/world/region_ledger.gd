extends RefCounted
## World-scoped established regions (Milestone 02 H). The first time any Run loads a
## chunk, one immutable record pins the encounter revision it was established at, so
## later activations never change it. Unloading a chunk never forgets the record.
## Records are ordinary content instances (no migration); only established chunks
## are written, never the infinite world.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
const RECORD := {"content_id": "core:region_record", "version": 1}
const BASELINE_ID := "region:v1/baseline"
const LEDGER_VERSION := 1
var registry: RefCounted
var world_id := ""
var _revisions: Dictionary = {}
var last_error := ""

func configure(content: RefCounted, world: String) -> bool:
	registry = content
	world_id = world
	_revisions.clear()
	var pack := Pack.new()
	if not pack.install(registry, world_id, Pack.WORLD_PATH):
		return _fail(pack.last_error)
	last_error = ""
	return true

static func record_id(chunk: Vector2i) -> String:
	return "region:v1/%d/%d" % [chunk.x, chunk.y]

func established(chunk: Vector2i) -> int:
	## Revision the chunk was established at, -1 when never established (or on error).
	if _revisions.has(chunk):
		return _revisions[chunk]
	var record: Dictionary = registry.load_instance(world_id, record_id(chunk))
	if record.is_empty():
		if registry.last_error != "Content instance not found":
			_fail(registry.last_error)
		return -1
	var revision: Variant = record.get("metadata", {}).get("encounter_revision")
	if not Data.integer(revision) or revision < 0:
		_fail("Corrupt region record " + record_id(chunk))
		return -1
	_revisions[chunk] = int(revision)
	return int(revision)

func establish(chunk: Vector2i, revision: int) -> int:
	## Existing records always win; returns the pinned revision or -1 on failure.
	last_error = ""
	var known := established(chunk)
	if known >= 0 or not last_error.is_empty():
		return known
	var origin := chunk * Terrain.CHUNK_SIZE
	var record := {"instance_id": record_id(chunk), "content_id": RECORD.content_id, "version": RECORD.version,
		"position": {"x": origin.x, "y": origin.y}, "origin": "procedural",
		"metadata": {"ledger_version": LEDGER_VERSION, "encounter_revision": revision, "chunk": {"x": chunk.x, "y": chunk.y}}}
	if registry.create_instance(world_id, record).is_empty():
		# Another process may have established it first; its record is authoritative.
		var winner := established(chunk)
		if winner >= 0:
			last_error = ""
			return winner
		_fail(registry.last_error)
		return -1
	_revisions[chunk] = revision
	return revision

func seal_baseline(store: RefCounted) -> bool:
	## Once per World: chunks explored by any Run before the ledger existed were seen
	## at revision 0 (no encounter content existed), so pin them there. Every caller
	## that can raise the revision or establish chunks runs this first.
	var marker: Dictionary = registry.load_instance(world_id, BASELINE_ID)
	if not marker.is_empty():
		return true
	if registry.last_error != "Content instance not found":
		return _fail(registry.last_error)
	var chunks := {}
	for header in store.list_runs(world_id):
		var run: Dictionary = store.load_run(header.run_id)
		if run.is_empty():
			return _fail(store.last_error)
		var tiles: Array = run.state.get("explored", []).duplicate()
		tiles.append(run.state.get("character", {}).get("position", run.spawn.position))
		tiles.append(run.spawn.position)
		for tile in tiles:
			if not Data.position(tile):
				continue
			var center := Terrain.chunk_of(Vector2i(int(tile.x), int(tile.y)))
			for y in range(center.y - 1, center.y + 2):
				for x in range(center.x - 1, center.x + 2):
					chunks[Vector2i(x, y)] = true
	var ordered: Array = chunks.keys()
	ordered.sort()
	for chunk in ordered:
		if establish(chunk, 0) < 0:
			return false
	var record := {"instance_id": BASELINE_ID, "content_id": RECORD.content_id, "version": RECORD.version,
		"position": {"x": 0, "y": 0}, "origin": "procedural",
		"metadata": {"ledger_version": LEDGER_VERSION, "baseline": true, "sealed_chunks": ordered.size()}}
	if registry.create_instance(world_id, record).is_empty() and registry.load_instance(world_id, BASELINE_ID).is_empty():
		return _fail(registry.last_error)
	last_error = ""
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false
