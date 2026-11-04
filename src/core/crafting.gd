extends RefCounted
## Crafting v1: data recipes turn held materials into items. Pure planning on an
## inventory copy; the session commits the result as one ordinary action. Recipes
## never run code: inputs and one output, both pinned item content.
const Data = preload("res://src/data/json_data.gd")
const Inventory = preload("res://src/core/inventory.gd")
const CATEGORIES := ["weapon", "armor", "trinket", "remedy", "food", "tool", "material"]

static func validate(definition: Dictionary) -> String:
	var payload: Dictionary = definition.get("payload", {})
	if payload.get("category") not in CATEGORIES:
		return "Recipe category must be one of " + ", ".join(CATEGORIES)
	if not payload.get("inputs") is Array or payload.inputs.is_empty() or payload.inputs.size() > 6:
		return "Recipe needs 1..6 inputs"
	for item in payload.inputs + [payload.get("output")]:
		if not item is Dictionary or not Data.identifier(item.get("content_id")) or not Data.integer(item.get("version")) or not Data.integer(item.get("quantity")) or item.quantity < 1 or item.quantity > 100:
			return "Recipe items need content_id, version and quantity 1..100"
	return ""

static func missing(recipe: Dictionary, inventory: Dictionary) -> Array:
	## [{content_id, need, have}] for inputs the inventory cannot cover.
	var result: Array = []
	for item in recipe.payload.inputs:
		var have := int(inventory.get(item.content_id, {}).get("quantity", 0))
		if have < int(item.quantity):
			result.append({"content_id": item.content_id, "version": int(item.version), "need": int(item.quantity), "have": have})
	return result

static func plan(registry: RefCounted, world_id: String, inventory: Dictionary, recipe: Dictionary, identity_key: String) -> Dictionary:
	## {inventory, received, display_received} or {error}. Nothing is mutated.
	if not missing(recipe, inventory).is_empty():
		return {"error": "Missing materials for " + str(recipe.name)}
	var tool := Inventory.new()
	var next := inventory
	for item in recipe.payload.inputs:
		if int(next.get(item.content_id, {}).get("version", item.version)) != int(item.version):
			return {"error": "Held %s is a different version than the recipe needs" % item.content_id}
		var removal := tool.remove(next, item.content_id, int(item.quantity))
		if removal.is_empty():
			return {"error": tool.last_error}
		next = removal.inventory
	var output: Dictionary = recipe.payload.output
	var drop := {"content_id": output.content_id, "version": int(output.version), "quantity": int(output.quantity)}
	if output.has("quality"):
		drop.quality = output.quality
	var award := tool.award(registry, world_id, next, [drop], identity_key)
	if award.is_empty():
		return {"error": tool.last_error}
	return {"inventory": award.inventory, "received": award.received, "display_received": award.display_received}
