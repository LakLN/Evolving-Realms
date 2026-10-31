extends SceneTree
## Headless developer tool. Gameplay never invokes it or starts Python/HTTP.
const Store = preload("res://src/data/game_store.gd")
const Pipeline = preload("res://src/content/authoring_pipeline.gd")
const Context = preload("res://src/content/authoring_context.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const ContentPack = preload("res://src/content/content_pack.gd")

func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.get_slice("=", 0).trim_prefix("--")] = arg.substr(arg.find("=") + 1)
	if args.get("command", "") == "pack-check": return finish(_pack_check(args), args) # Own throwaway database.
	if not args.has("database") or not str(args.database).is_absolute_path(): return finish({"error": "Explicit absolute --database is required"}, args)
	var store := Store.new()
	if not store.open(args.database): return finish({"error": store.last_error}, args)
	var tool := Pipeline.new(store)
	var world_id: String = args.get("world", "")
	var result := {}
	match args.get("command", ""):
		"init":
			var seed_value := int(args.get("seed", "1847"))
			result = store.create_world(args.get("name", "AI Field Laboratory"), seed_value, 1, Packs.blueprint(seed_value))
			if not result.is_empty():
				for path in Packs.ALL_PATHS:
					var packs := Packs.new()
					if not packs.install(store.content, result.world_id, path):
						result = {"error": packs.last_error}
						break
		"worlds": result = {"worlds": store.list_worlds()}
		"context": result = Context.retrieve(store, world_id, args.get("query", ""), Array(str(args.get("related", "")).split(",", false)), args.get("region", ""))
		"draft":
			var file := FileAccess.open(args.get("file", ""), FileAccess.READ)
			if file == null or file.get_length() > 350000: result = {"error": "Cannot read bounded response file"}
			else: result = tool.draft(world_id, JSON.parse_string(file.get_as_text()))
		"review": result = tool.review(world_id, args.get("proposal", ""))
		"confirm": result = tool.confirm(world_id, args.get("proposal", ""))
		"activate": result = tool.activate(world_id, args.get("proposal", ""))
		"reject": result = tool.reject(world_id, args.get("proposal", ""), args.get("reason", ""))
		"proposals": result = {"proposals": tool.summaries(world_id)}
		"registered": result = {"registered": tool.registered(world_id)}
		"pack-status", "pack-apply":
			var packs := ContentPack.new()
			var pack := packs.load_pack(args.get("pack", ""))
			if pack.is_empty(): result = {"error": packs.last_error}
			else:
				if args.has("create-world"):
					# A fresh World (random seed unless --seed): every region of it is new,
					# so encounters and places of the pack can appear from the first Run on.
					var seed_value := int(args.get("seed", str(randi() & 0x7fffffff)))
					var created: Dictionary = store.create_world(args["create-world"], seed_value, 1, Packs.blueprint(seed_value))
					if created.is_empty(): result = {"error": store.last_error}
					world_id = created.get("world_id", "")
				if not result.has("error") and store.load_world(world_id).is_empty(): result = {"error": "Unknown --world; pass a World ID or --create-world=<name>"}
				elif not result.has("error"):
					if args.command == "pack-status": result = {"pack": pack.manifest.pack_id, "world": world_id, "modules": packs.status(store, world_id, pack)}
					else: result = packs.apply(store, world_id, pack, Array(str(args.get("modules", "")).split(",", false)))
		_: result = {"error": "Unknown authoring command"}
	if result.is_empty(): result = {"error": tool.last_error if not tool.last_error.is_empty() else store.last_error}
	store.close()
	finish(result, args)

func _pack_check(args: Dictionary) -> Dictionary:
	var packs := ContentPack.new()
	var pack := packs.load_pack(args.get("pack", ""))
	return {"error": packs.last_error} if pack.is_empty() else packs.check(pack)

func finish(result: Dictionary, args: Dictionary) -> void:
	if args.has("output"):
		var file := FileAccess.open(args.output, FileAccess.WRITE)
		if file == null:
			printerr("Cannot write output file")
			quit(1)
			return
		file.store_string(JSON.stringify(result, "\t", true))
	print(JSON.stringify(result, "", true))
	quit(1 if result.has("error") else 0)
