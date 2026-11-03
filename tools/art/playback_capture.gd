extends SceneTree
## Rendered playback proof for one character sheet (dev tool; never touches saves).
## Plays all 20 animations through src/world/art.gd SpriteFrames on AnimatedSprite2D
## over snow ground, records which frames each animation actually showed, checks that
## looping walks advance and one-shot states reach their last frame, and writes four
## time samples side by side to .tools/art/playback_<name>.png for human review.
##   Godot --path . --script res://tools/art/playback_capture.gd -- --character=rime_hare
const Art = preload("res://src/world/art.gd")
const STATES := ["idle", "walk", "attack", "hit", "death"]
const DIRECTIONS := ["down", "left", "right", "up"]
const SCALE := 2.0
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _run() -> void:
	var name := "rime_hare"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--character="): name = arg.trim_prefix("--character=")
	var art: RefCounted = Art.new()
	var frames: SpriteFrames = art.frames(name) if art.ready() else null
	if not check(frames != null, "SpriteFrames build for " + name):
		return _finish(name)
	var spec: Dictionary = art.index.characters[name]
	var cell := Vector2(spec.frame[0], spec.frame[1]) * SCALE
	var ground := ColorRect.new()
	ground.color = Color("e9ecf3")
	ground.size = Vector2(cell.x * STATES.size() + 20, cell.y * DIRECTIONS.size() + 20)
	root.add_child(ground)
	var sprites := {}
	var seen := {}
	for row in DIRECTIONS.size():
		for col in STATES.size():
			var anim: String = "%s_%s" % [STATES[col], DIRECTIONS[row]]
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.centered = false
			sprite.scale = Vector2(SCALE, SCALE)
			sprite.position = Vector2(10 + col * cell.x, 10 + row * cell.y)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			root.add_child(sprite)
			check(frames.has_animation(anim), "%s has %s" % [name, anim])
			sprite.play(anim)
			sprites[anim] = sprite
			seen[anim] = {}
	var shots: Array = []
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1600:
		await process_frame
		for anim in sprites:
			seen[anim][sprites[anim].frame] = true
		var elapsed := Time.get_ticks_msec() - start
		if shots.size() < 4 and elapsed >= 120 + shots.size() * 110:
			await RenderingServer.frame_post_draw
			shots.append(root.get_texture().get_image().get_region(Rect2i(Vector2i.ZERO, Vector2i(ground.size))))
	for anim in sprites:
		var count: int = frames.get_frame_count(anim)
		var shown: Array = seen[anim].keys()
		print("PLAYBACK %s: %d frames, shown %s" % [anim, count, str(shown)])
		if count > 1:
			check(shown.size() == count, "%s played every frame (%d/%d)" % [anim, shown.size(), count])
	if check(shots.size() == 4, "captured four time samples"):
		var size: Vector2i = shots[0].get_size()
		var strip := Image.create(size.x * 4 + 30, size.y, false, Image.FORMAT_RGBA8)
		strip.fill(Color("282830"))
		for i in 4:
			strip.blit_rect(shots[i], Rect2i(Vector2i.ZERO, size), Vector2i(i * (size.x + 10), 0))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tools/art"))
		check(strip.save_png("res://.tools/art/playback_%s.png" % name) == OK, "wrote .tools/art/playback_%s.png" % name)
	_finish(name)

func _finish(name: String) -> void:
	print("PLAYBACK %s: %d checks, %d failures" % [name, checks, failures])
	quit(0 if failures == 0 else 1)
