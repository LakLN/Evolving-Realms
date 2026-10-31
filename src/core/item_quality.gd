extends RefCounted
## Central item quality tiers from content/quality_tiers.json (ordered by rank).
## Quality is an item grade stored by tier ID (e.g. "uu_tu"); it is not drop
## rarity. Any item kind may carry it: definition payload.quality is the default,
## an individual instance's metadata.quality overrides it.
const Data = preload("res://src/data/json_data.gd")
const PATH := "res://content/quality_tiers.json"
const STYLES := ["plain", "platinum", "black_gold", "rainbow"]
var tiers: Array = []
var by_id: Dictionary = {}
var last_error := ""

func load_rules(path: String = PATH) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("rules_version") != 1 or not parsed.get("tiers") is Array or parsed.tiers.is_empty():
		return _fail("Quality tiers are missing or unsupported")
	var seen := {}
	var previous := 0
	for tier in parsed.tiers:
		if not tier is Dictionary or not tier.get("id") is String or not Data.identifier("q:" + tier.id) or seen.has(tier.id):
			return _fail("Quality tier needs a unique lowercase id")
		if not Data.integer(tier.get("rank")) or tier.rank <= previous or not tier.get("name") is String or tier.name.is_empty():
			return _fail("Quality tiers need increasing ranks and a name: " + str(tier.id))
		if not tier.get("color") is String or not tier.color.is_valid_html_color() or tier.get("style", "plain") not in STYLES:
			return _fail("Quality tier color/style invalid: " + str(tier.id))
		if not Data.integer(tier.get("stat_bonus_percent", 0)) or tier.get("stat_bonus_percent", 0) < -90 or tier.get("stat_bonus_percent", 0) > 10000:
			return _fail("Quality stat_bonus_percent must be -90..10000: " + str(tier.id))
		previous = int(tier.rank)
		seen[tier.id] = tier
	tiers = parsed.tiers
	by_id = seen
	last_error = ""
	return true

func has(tier_id: Variant) -> bool:
	return tier_id is String and by_id.has(tier_id)

func rank(tier_id: String) -> int:
	return int(by_id[tier_id].rank) if by_id.has(tier_id) else 0

func tier(tier_id: String) -> Dictionary:
	return by_id.get(tier_id, {})

func of(definition: Dictionary, instance_metadata: Dictionary = {}) -> String:
	## Instance quality overrides the definition default; "" when ungraded.
	var value: Variant = instance_metadata.get("quality", definition.get("payload", {}).get("quality", ""))
	return value if has(value) else ""

func bonus_percent(tier_id: String) -> int:
	return int(by_id.get(tier_id, {}).get("stat_bonus_percent", 0))

func color(tier_id: String, time_seconds: float = 0.0) -> Color:
	var entry: Dictionary = by_id.get(tier_id, {})
	if entry.is_empty():
		return Color("d0d0d0")
	if entry.get("style") == "rainbow":
		return Color.from_hsv(fmod(time_seconds * 0.25, 1.0), 0.65, 1.0)
	return Color(entry.color)

func _fail(message: String) -> bool:
	last_error = message
	return false
