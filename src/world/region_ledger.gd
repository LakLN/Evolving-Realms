extends RefCounted
## World-scoped established regions (Milestone 02 H). The first time any Run loads a
## chunk, one immutable record pins the encounter revision it was established at, so
## later activations never change it. Unloading a chunk never forgets the record.
## Records are ordinary content instances (no migration); only established chunks
## are written, never the infinite world.
const Terrain = preload("res://src/world/terrain_v1.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
const FogMask = preload("res://src/run/fog_mask.gd")
const RECORD := {"content_id": "core:region_record", "version": 1}
const BASELINE_ID := "region:v1/baseline"
const LEDGER_VERSION := 2
## Content layers a region established by this code carries (Checkpoint I). Regions
## recorded earlier (ledger v1, baseline) have none and never gain these layers.
const LAYERS := ["locations-v1"]
const REVISED_KINDS := ["encounter", "location"]
var registry: RefCounted
var world_id := ""
## Current World distribution revision (encounters and locations; see current_revision).
var revision := 0
var _revisions: Dictionary = {}
var _layers: Dictionary = {}
var last_error := ""

func configure(content: RefCounted, world: String) -> bool:
	registry = content
	world_id = world
	_revisions.clear()
	var pack := Pack.new()
	if not pack.install(registry, world_id, Pack.WORLD_PATH):
		return _fail(pack.last_error)
	revision = current_revision(registry, world_id)
	last_error = ""
	return true

static func current_revision(content: RefCounted, world: String) -> int:
	## Highest activation revision stamped on active encounter/location definitions. The
	## provenance key keeps its Checkpoint H name `encounter_revision` for both kinds.
	var result := 0
	for header in content.list_definitions(world):
		if header.kind in REVISED_KINDS and header.status == "active":
			var definition: Dictionary = content.load_definition(world, header.content_id, int(header.version))
			var value: Variant = definition.get("provenance", {}).get("encounter_revision", 0)
			if Data.integer(value): result = maxi(result, int(value))
	return result

func layers(chunk: Vector2i) -> Array:
	## Content layers of an established chunk ([] for H/baseline records or unknown).
	if established(chunk) < 0:
		return []
	return _layers.get(chunk, [])

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
	var tags: Variant = record.metadata.get("layers", [])
	_layers[chunk] = tags if tags is Array else []
	return int(revision)

func establish(chunk: Vector2i, at_revision: int, with_layers: Array = LAYERS) -> int:
	## Existing records always win; returns the pinned revision or -1 on failure.
	last_error = ""
	var known := established(chunk)
	if known >= 0 or not last_error.is_empty():
		return known
	var origin := chunk * Terrain.CHUNK_SIZE
	var record := {"instance_id": record_id(chunk), "content_id": RECORD.content_id, "version": RECORD.version,
		"position": {"x": origin.x, "y": origin.y}, "origin": "procedural",
		"metadata": {"ledger_version": LEDGER_VERSION, "encounter_revision": at_revision, "layers": with_layers.duplicate(), "chunk": {"x": chunk.x, "y": chunk.y}}}
	if registry.create_instance(world_id, record).is_empty():
		# Another process may have established it first; its record is authoritative.
		var winner := established(chunk)
		if winner >= 0:
			last_error = ""
			return winner
		_fail(registry.last_error)
		return -1
	_revisions[chunk] = at_revision
	_layers[chunk] = with_layers.duplicate()
	return at_revision

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
		# Explored tiles only: every saved Run stores its initial sight, while a Run being
		# created right now has explored nothing yet and must not be sealed at revision 0.
		for center in FogMask.chunks(run.state.get("explored", [])): # Tiles or chunk masks.
			for y in range(center.y - 1, center.y + 2):
				for x in range(center.x - 1, center.x + 2):
					chunks[Vector2i(x, y)] = true
	var ordered: Array = chunks.keys()
	ordered.sort()
	for chunk in ordered:
		if establish(chunk, 0, []) < 0: # Pre-ledger exploration: no later layers.
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
