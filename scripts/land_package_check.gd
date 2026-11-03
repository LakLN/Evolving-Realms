extends SceneTree
const Package = preload("res://src/content/land_package.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if not args.is_empty() else "res://content/land_packages/snow_mountain/manifest.json"
	var report := Package.inspect(Package.read_manifest(path))
	print(JSON.stringify(report, "  "))
	# Draft manifests may be valid while deliberately not ready. --ready is a CI gate.
	quit(0 if report.valid and (not "--ready" in args or report.ready) else 1)
