extends SceneTree
## Art import verification in the real engine (dev tool; never touches saves). Every PNG
## the merged art index names must import as a lossless, mipmap-free Texture2D with
## alpha and the indexed size; every character sheet must build all 20 SpriteFrames
## animations through src/world/art.gd with regions inside the texture.
## With --fragment=<json> (from `asset_check.py batch --emit`) the fragment's
## characters/objects/places are merged first, proving a batch integrates end to end.
##   .\scripts\godot.ps1 --headless --script res://tools/art/import_check.gd ['--' --fragment=res://...]
const Art = preload("res://src/world/art.gd")
const STATES := ["idle", "walk", "attack", "hit", "death"]
const DIRECTIONS := ["down", "left", "right", "up"]
var checks := 0
var failures := 0

func _initialize() -> void:
	var art: RefCounted = Art.new()
	if not check(art.ready(), "art index loads and builds the TileSet"):
		return _finish()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fragment="):
			_merge_fragment(art, arg.trim_prefix("--fragment="))
	var textures := {}
	var opaque := {} # ground atlases: cells are fully opaque by rule (ART_BIBLE 5)
	for group in ["objects", "places", "icons"]:
		for name in art.index.get(group, {}):
			var entry: Dictionary = art.index[group][name]
			textures[entry.texture] = entry.get("size", [])
	for name in art.index.characters:
		textures[art.index.characters[name].sheet] = []
	var p0: Variant = JSON.parse_string(FileAccess.get_file_as_string(Art.SNOW_P0_INDEX)) if FileAccess.file_exists(Art.SNOW_P0_INDEX) else {}
	for table in [art.index, art.snow_s1, p0 if p0 is Dictionary else {}]:
		for group in ["ground", "props", "decor"]:
			if table.get(group, {}).has("atlas"):
				textures[table[group].atlas] = []
				if group == "ground": opaque[table[group].atlas] = true
	for relative in textures:
		_check_texture(art, relative, textures[relative], opaque.has(relative))
	for name in art.index.characters:
		_check_frames(art, name)
	_finish()

func _merge_fragment(art: RefCounted, path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(parsed is Dictionary, "fragment parses: " + path):
		return
	for group in ["characters", "objects", "places"]:
		if not art.index.has(group): art.index[group] = {}
		art.index[group].merge(parsed.get(group, {}), true)
	print("Merged fragment %s: %s" % [path, str(parsed.keys())])

func _check_texture(art: RefCounted, relative: String, size: Array, may_be_opaque := false) -> void:
	var path: String = Art.ROOT + relative
	var texture: Texture2D = art.texture(relative)
	if not check(texture != null, "imports as Texture2D: " + relative):
		return
	if not size.is_empty():
		check(Vector2i(texture.get_size()) == Vector2i(int(size[0]), int(size[1])), "%s is %s as indexed (%s)" % [relative, str(size), str(texture.get_size())])
	var image := texture.get_image()
	check(image != null and (may_be_opaque or image.detect_alpha() != Image.ALPHA_NONE), "keeps an alpha channel: " + relative)
	var config := ConfigFile.new()
	if check(config.load(path + ".import") == OK, ".import exists: " + relative):
		check(int(config.get_value("params", "compress/mode", -1)) == 0, "lossless compression (compress/mode=0): " + relative)
		check(not bool(config.get_value("params", "mipmaps/generate", true)), "no mipmaps: " + relative)

func _check_frames(art: RefCounted, name: String) -> void:
	var frames: SpriteFrames = art.frames(name)
	if not check(frames != null, "SpriteFrames build: " + name):
		return
	var sheet: Vector2 = art.texture(art.index.characters[name].sheet).get_size()
	var missing: Array = []
	var outside := 0
	for state in STATES:
		for direction in DIRECTIONS:
			var anim: String = "%s_%s" % [state, direction]
			if not frames.has_animation(anim) or frames.get_frame_count(anim) == 0:
				missing.append(anim)
				continue
			for i in frames.get_frame_count(anim):
				var region: Rect2 = (frames.get_frame_texture(anim, i) as AtlasTexture).region
				if not Rect2(Vector2.ZERO, sheet).encloses(region):
					outside += 1
	check(missing.is_empty(), "%s has all 20 animations %s" % [name, "" if missing.is_empty() else str(missing)])
	check(outside == 0, "%s frame regions lie inside the sheet (%d outside)" % [name, outside])

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _finish() -> void:
	print("ART IMPORT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
